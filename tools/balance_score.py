#!/usr/bin/env python3
"""Grade signed #203/#204 bands from balance_sim JSON reports.

Usage:
  python3 tools/balance_score.py vow0.json vow5.json [--ablation ID=path ...]
  python3 tools/balance_score.py --csv-dir DIR --csv-prefix NAME vow0.json vow5.json [...]
"""
from __future__ import annotations

import argparse
import csv
import json
import math
from collections import defaultdict
from pathlib import Path

Z = 1.959963984540054
V0_BAND = (0.80, 0.97)
V5_BAND = (0.55, 0.85)
GAP_CAP = 0.20
BOSS_BAND = (5.5, 10.5)
ABLATION_NONBOSS = 0.12
ABLATION_BOSS = 0.15
BOSS_RELICS = {"hollowCrown"}


def wilson(wins: int, n: int) -> tuple[float, float]:
    if n == 0:
        return 0.0, 0.0
    p = wins / n
    z2 = Z * Z
    den = 1.0 + z2 / n
    centre = (p + z2 / (2.0 * n)) / den
    margin = Z * math.sqrt((p * (1.0 - p) + z2 / (4.0 * n)) / n) / den
    return centre - margin, centre + margin


def paired_ci(values: list[float]) -> tuple[float, float, float]:
    n = len(values)
    mean = sum(values) / n if n else 0.0
    if n > 1:
        var = sum((v - mean) ** 2 for v in values) / (n - 1)
        margin = Z * math.sqrt(var / n)
    else:
        margin = 1.0
    return mean, mean - margin, mean + margin


def load_report(path: Path) -> dict:
    return json.loads(path.read_text())


def cell(report: dict, aspect: str) -> dict:
    s = report["summary"][aspect]
    wins = int(s["wins"])
    n = int(s["runs"])
    stalls = int(s["stalls"])
    errors = int(s["errors"])
    return {
        "runs": n, "wins": wins, "rate": float(s["winRate"]),
        "stalls": stalls, "errors": errors,
        "losses": n - wins - stalls - errors, "wilson": s["wilson95"],
    }


def paired_gap(rows: list[dict]) -> dict:
    by_seed: dict[int, dict[str, float]] = {}
    for row in rows:
        by_seed.setdefault(int(row["seed"]), {})[row["aspect"]] = (
            1.0 if row["outcome"] == "win" else 0.0
        )
    values = [
        pair["ashwarden"] - pair["duskblade"]
        for pair in by_seed.values()
        if "ashwarden" in pair and "duskblade" in pair
    ]
    mean, lo, hi = paired_ci(values)
    return {
        "n": len(values), "mean": mean, "lower": lo, "upper": hi,
        "neg": sum(1 for v in values if v < 0),
        "zero": sum(1 for v in values if v == 0),
        "pos": sum(1 for v in values if v > 0),
    }


def percentile(sorted_vals: list[int], p: float) -> int:
    if not sorted_vals:
        return 0
    idx = int(round((len(sorted_vals) - 1) * p))
    return sorted_vals[max(0, min(idx, len(sorted_vals) - 1))]


def boss_turns(rows: list[dict]) -> dict[tuple[str, int], dict]:
    buckets: dict[tuple[str, int], list[int]] = defaultdict(list)
    for row in rows:
        for fight in row.get("fights", []):
            if fight.get("kind") == "boss":
                buckets[(row["aspect"], int(fight["act"]))].append(int(fight["turns"]))
    out = {}
    for key, turns in buckets.items():
        ordered = sorted(turns)
        n = len(ordered)
        in_win = sum(1 for t in ordered if 6 <= t <= 10)
        out[key] = {
            "n": n, "mean": sum(ordered) / n if n else 0.0,
            "p25": percentile(ordered, 0.25), "p50": percentile(ordered, 0.50),
            "p75": percentile(ordered, 0.75),
            "min": ordered[0] if ordered else 0, "max": ordered[-1] if ordered else 0,
            "in_6_10": in_win, "share_in_6_10": in_win / n if n else 0.0,
        }
    return out


def ablation_delta(control: list[dict], banned: list[dict], aspect: str) -> dict:
    ctrl = {int(r["seed"]): 1.0 if r["outcome"] == "win" else 0.0
            for r in control if r["aspect"] == aspect}
    ban = {int(r["seed"]): 1.0 if r["outcome"] == "win" else 0.0
           for r in banned if r["aspect"] == aspect}
    seeds = sorted(set(ctrl) & set(ban))
    diffs = [ban[s] - ctrl[s] for s in seeds]
    mean, lo, hi = paired_ci(diffs)
    return {
        "n": len(seeds), "delta": mean, "lower": lo, "upper": hi,
        "ctrl": int(sum(ctrl[s] for s in seeds)),
        "ban": int(sum(ban[s] for s in seeds)),
    }


def print_report(v0: dict, v5: dict, ablations: list[tuple[str, dict]]) -> list[str]:
    fails: list[str] = []
    for vow, report, band in ((0, v0, V0_BAND), (5, v5, V5_BAND)):
        seeds = report["manifest"]["seeds"]
        print(f"\n## Vow {vow}  seeds {seeds['first']}–{seeds['last']}  n={seeds['count']}  "
              f"pilot={report['manifest']['pilot']}")
        print(f"{'aspect':<12} {'wins/n':>10} {'rate':>8} {'wilson95':>24} {'stalls':>7} gate")
        for aspect in ("duskblade", "ashwarden"):
            c = cell(report, aspect)
            gate = "PASS" if band[0] <= c["rate"] <= band[1] else "FAIL"
            if gate != "PASS":
                fails.append(f"vow{vow} {aspect} {c['rate']:.1%} outside {band}")
            if c["stalls"] or c["errors"]:
                fails.append(f"vow{vow} {aspect} stalls={c['stalls']} errors={c['errors']}")
            w = c["wilson"]
            print(f"{aspect:<12} {c['wins']:>4}/{c['runs']:<4} {c['rate']:>7.1%} "
                  f"[{w['lower']:.3%}, {w['upper']:.3%}] {c['stalls']:>7} {gate}")
        gap = paired_gap(report["runs"])
        gate = "PASS" if abs(gap["mean"]) <= GAP_CAP else "FAIL"
        if gate != "PASS":
            fails.append(f"vow{vow} |Ash-Dusk| {abs(gap['mean']):.1%} > 20pp")
        print(f"  gap Ash−Dusk {gap['mean']:+.2%}  95% [{gap['lower']:+.2%}, {gap['upper']:+.2%}]  {gate}")
        turns = boss_turns(report["runs"])
        for aspect in ("duskblade", "ashwarden"):
            for act in (1, 2, 3):
                b = turns[(aspect, act)]
                gate = "PASS" if BOSS_BAND[0] <= b["mean"] <= BOSS_BAND[1] else "FAIL"
                if gate != "PASS":
                    fails.append(f"vow{vow} {aspect} act{act} mean {b['mean']:.3f}")
                print(f"    {aspect} act{act}: n={b['n']:3d} mean={b['mean']:7.3f}  {gate}")
    if ablations:
        print("\n## Ablation (Vow 0, matched, point-estimate)")
        for item, banned in ablations:
            cap = ABLATION_BOSS if item in BOSS_RELICS else ABLATION_NONBOSS
            for aspect in ("duskblade", "ashwarden"):
                d = ablation_delta(v0["runs"], banned["runs"], aspect)
                gate = "PASS" if abs(d["delta"]) <= cap else "FAIL"
                if gate != "PASS":
                    fails.append(f"ablation {item} {aspect} {d['delta']:+.1%}")
                print(f"{item:<16} {aspect:<10} {d['delta']*100:+7.2f} "
                      f"[{d['lower']*100:+6.2f}, {d['upper']*100:+6.2f}] {cap*100:5.0f}pp {gate}")
    print("\n## Joint hypothesis")
    print("FAIL" if fails else "PASS — four signed bands; stalls=0; errors=0")
    for f in fails:
        print(" -", f)
    return fails


def _mean(rows: list[dict], key: str) -> str:
    if not rows:
        return ""
    return f"{sum(float(r[key]) for r in rows) / len(rows):.3f}"


def write_csvs(v0: dict, v5: dict, ablations: list[tuple[str, dict]],
               out_dir: Path, prefix: str) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    with (out_dir / f"{prefix}-cells.csv").open("w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["vow", "aspect", "runs", "wins", "losses", "stalls", "errors",
                    "win_rate", "wilson95_lower", "wilson95_upper",
                    "seeds_first", "seeds_last", "pilot"])
        for report in (v0, v5):
            seeds = report["manifest"]["seeds"]
            for aspect in ("duskblade", "ashwarden"):
                c = cell(report, aspect)
                w.writerow([report["manifest"]["vow"], aspect, c["runs"], c["wins"],
                            c["losses"], c["stalls"], c["errors"], f"{c['rate']:.6f}",
                            f"{c['wilson']['lower']:.6f}", f"{c['wilson']['upper']:.6f}",
                            seeds["first"], seeds["last"], report["manifest"]["pilot"]])
    with (out_dir / f"{prefix}-boss-turns.csv").open("w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["vow", "aspect", "act", "n", "mean", "p25", "p50", "p75",
                    "min", "max", "in_6_10", "share_in_6_10"])
        for report in (v0, v5):
            turns = boss_turns(report["runs"])
            for aspect in ("duskblade", "ashwarden"):
                for act in (1, 2, 3):
                    b = turns[(aspect, act)]
                    w.writerow([report["manifest"]["vow"], aspect, act, b["n"],
                                f"{b['mean']:.6f}", b["p25"], b["p50"], b["p75"],
                                b["min"], b["max"], b["in_6_10"],
                                f"{b['share_in_6_10']:.6f}"])
    with (out_dir / f"{prefix}-runs.csv").open("w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["vow", "aspect", "seed", "outcome", "hp", "maxHp", "gold",
                    "goldEarned", "deck", "nFights"])
        for report in (v0, v5):
            for row in report["runs"]:
                w.writerow([row["vow"], row["aspect"], row["seed"], row["outcome"],
                            row["hp"], row["maxHp"], row["gold"], row["goldEarned"],
                            row["deck"], len(row.get("fights", []))])
    with (out_dir / f"{prefix}-economy.csv").open("w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["vow", "aspect", "slice", "n", "gold_earned_mean", "end_gold_mean",
                    "deck_mean", "hp_mean", "max_hp_mean"])
        for report in (v0, v5):
            vow = report["manifest"]["vow"]
            by_aspect: dict[str, list[dict]] = defaultdict(list)
            for row in report["runs"]:
                by_aspect[row["aspect"]].append(row)
            for aspect, rows in by_aspect.items():
                for slice_name, subset in (
                    ("all", rows),
                    ("win", [r for r in rows if r["outcome"] == "win"]),
                    ("loss", [r for r in rows if r["outcome"] == "loss"]),
                ):
                    w.writerow([vow, aspect, slice_name, len(subset),
                                _mean(subset, "goldEarned"), _mean(subset, "gold"),
                                _mean(subset, "deck"), _mean(subset, "hp"),
                                _mean(subset, "maxHp")])
                for act in (1, 2, 3):
                    econ = [e for r in rows for e in r.get("economy", []) if int(e["act"]) == act]
                    w.writerow([vow, aspect, f"boss_act{act}", len(econ), "",
                                _mean(econ, "gold"), _mean(econ, "deck"),
                                _mean(econ, "hp"), _mean(econ, "maxHp")])
    if ablations:
        with (out_dir / f"{prefix}-ablation-n200.csv").open("w", newline="") as fh:
            w = csv.writer(fh)
            w.writerow(["item", "aspect", "control_wins", "control_n", "control_rate",
                        "ablation_wins", "ablation_n", "ablation_rate", "delta",
                        "paired95_lower", "paired95_upper", "half_width",
                        "seeds_first", "seeds_last"])
            seeds = v0["manifest"]["seeds"]
            for item, banned in ablations:
                for aspect in ("duskblade", "ashwarden", "combined"):
                    if aspect == "combined":
                        d_d = ablation_delta(v0["runs"], banned["runs"], "duskblade")
                        d_a = ablation_delta(v0["runs"], banned["runs"], "ashwarden")
                        n = d_d["n"] + d_a["n"]
                        ctrl = d_d["ctrl"] + d_a["ctrl"]
                        ban = d_d["ban"] + d_a["ban"]
                        ctrl_map = {}
                        ban_map = {}
                        for r in v0["runs"]:
                            ctrl_map[(r["aspect"], int(r["seed"]))] = 1.0 if r["outcome"] == "win" else 0.0
                        for r in banned["runs"]:
                            ban_map[(r["aspect"], int(r["seed"]))] = 1.0 if r["outcome"] == "win" else 0.0
                        diffs = [ban_map[k] - ctrl_map[k] for k in sorted(set(ctrl_map) & set(ban_map))]
                        mean, lo, hi = paired_ci(diffs)
                    else:
                        d = ablation_delta(v0["runs"], banned["runs"], aspect)
                        n, ctrl, ban, mean, lo, hi = d["n"], d["ctrl"], d["ban"], d["delta"], d["lower"], d["upper"]
                    w.writerow([item, aspect, ctrl, n, f"{ctrl / n:.6f}", ban, n,
                                f"{ban / n:.6f}", f"{mean:.6f}", f"{lo:.6f}", f"{hi:.6f}",
                                f"{(hi - lo) / 2:.6f}", seeds["first"], seeds["last"]])


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("vow0")
    parser.add_argument("vow5")
    parser.add_argument("--ablation", action="append", default=[], metavar="ID=PATH")
    parser.add_argument("--csv-dir")
    parser.add_argument("--csv-prefix", default="holdout")
    args = parser.parse_args()
    v0 = load_report(Path(args.vow0))
    v5 = load_report(Path(args.vow5))
    ablations = []
    for spec in args.ablation:
        item, path = spec.split("=", 1)
        ablations.append((item, load_report(Path(path))))
    fails = print_report(v0, v5, ablations)
    if args.csv_dir:
        write_csvs(v0, v5, ablations, Path(args.csv_dir), args.csv_prefix)
    return 1 if fails else 0


if __name__ == "__main__":
    raise SystemExit(main())
