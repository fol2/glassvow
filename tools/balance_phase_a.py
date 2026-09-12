#!/usr/bin/env python3
"""Phase A gate for #421: 4-arm controls + #204 holdout. Landscape is the exam.

Usage (repo root):
  python3 tools/balance_phase_a.py
  python3 tools/balance_phase_a.py --controls-json PATH --holdout-vow0 PATH --holdout-vow5 PATH
"""
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
EXIT_GO, EXIT_ERR, EXIT_NOGO, EXIT_VETO = 0, 1, 2, 3
V0_BAND, V5_BAND, GAP_CAP, ARM2_GO, DROP_PP = (0.80, 0.97), (0.55, 0.85), 0.20, 0.50, 6.0
ASPECTS, VOWS, CELLS = ("duskblade", "ashwarden"), (0, 5), (
    ("duskblade", 0), ("duskblade", 5), ("ashwarden", 0), ("ashwarden", 5),
)
LABEL = {("duskblade", 0): "Dusk V0", ("duskblade", 5): "Dusk V5",
         ("ashwarden", 0): "Ash V0", ("ashwarden", 5): "Ash V5"}


def pct(rate: float) -> str:
    return f"{rate * 100:.1f}%"


def pp(delta: float) -> str:
    return f"{delta * 100:+.1f}"


def git_head() -> str:
    out = subprocess.run(["git", "rev-parse", "HEAD"], cwd=REPO, capture_output=True, text=True)
    return out.stdout.strip() if out.returncode == 0 else "unknown"


def file_sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_json(path: Path):
    return json.loads(path.read_text())


def cell_from(wins: int, runs: int, stalls: int = 0, errors: int = 0) -> dict:
    return {"wins": wins, "runs": runs, "winRate": (wins / runs if runs else 0.0),
            "stalls": stalls, "errors": errors}


def manifest_of(blob) -> dict:
    return blob.get("manifest", {}) if isinstance(blob, dict) else {}


def aggregate_controls(blob) -> tuple[list[dict], dict]:
    """Accept sweep raw {manifest, runs}, aggregated list, or {controls: [...]}."""
    if isinstance(blob, list):
        return blob, {}
    if isinstance(blob, dict) and isinstance(blob.get("controls"), list) and "runs" not in blob:
        return blob["controls"], manifest_of(blob)
    rows = blob["runs"] if isinstance(blob, dict) else blob
    if rows and "arm" in rows[0] and "wins" in rows[0]:
        return rows, manifest_of(blob)
    buckets: dict[tuple, dict] = defaultdict(lambda: {"wins": 0, "runs": 0, "stalls": 0, "errors": 0})
    for row in rows:
        key = (int(row["arm"]), str(row["aspect"]), int(row["vow"]))
        b = buckets[key]
        b["runs"] += 1
        outcome = str(row.get("outcome", ""))
        if outcome == "win":
            b["wins"] += 1
        elif outcome == "stall":
            b["stalls"] += 1
        elif outcome == "error":
            b["errors"] += 1
    cells = []
    for arm in (1, 2, 3, 4):
        for aspect, vow in CELLS:
            b = buckets[(arm, aspect, vow)]
            cells.append({"arm": arm, "aspect": aspect, "vow": vow, **cell_from(**b)})
    return cells, manifest_of(blob)


def holdout_from_report(blob: dict, vow: int) -> dict:
    if "holdout" in blob and str(vow) in blob["holdout"]:
        return {a: dict(blob["holdout"][str(vow)][a]) for a in ASPECTS}
    summary = blob["summary"]
    return {a: cell_from(int(summary[a]["wins"]), int(summary[a]["runs"]),
                         int(summary[a].get("stalls", 0)), int(summary[a].get("errors", 0)))
            for a in ASPECTS}


def load_baseline(path: Path) -> dict:
    blob = load_json(path)
    if isinstance(blob, list):
        return {"controls": blob, "holdout": None, "contentSha256": None, "commit": None, "godot": None}
    controls, _m = aggregate_controls(blob)
    holdout = blob.get("holdout")
    if holdout is not None:
        holdout = {int(v): holdout[v] for v in holdout}
    return {"controls": controls, "holdout": holdout,
            "contentSha256": blob.get("contentSha256"),
            "commit": blob.get("commit"), "godot": blob.get("godot")}


def arm_map(cells: list[dict], arm: int) -> dict[tuple[str, int], dict]:
    return {(c["aspect"], int(c["vow"])): c for c in cells if int(c["arm"]) == arm}


def run_godot(godot: str, script: str, flags: list[str], log_path: Path) -> int:
    cmd = [godot, "--headless", "-s", script, "--", *flags]
    log_path.parent.mkdir(parents=True, exist_ok=True)
    with log_path.open("w") as log:
        log.write(" ".join(cmd) + "\n")
        proc = subprocess.run(cmd, cwd=REPO, stdout=log, stderr=subprocess.STDOUT)
    return proc.returncode


def verdict(arm2: dict, holdout: dict) -> tuple[str, int, list[str]]:
    reasons: list[str] = []
    for vow, band in ((0, V0_BAND), (5, V5_BAND)):
        rates = []
        for aspect in ASPECTS:
            rate = holdout[vow][aspect]["winRate"]
            rates.append(rate)
            if not (band[0] <= rate <= band[1]):
                reasons.append(f"holdout {LABEL[(aspect, vow)]} {pct(rate)} outside {band[0]*100:.0f}–{band[1]*100:.0f}")
        gap = abs(rates[1] - rates[0])
        if gap > GAP_CAP:
            reasons.append(f"|Ash−Dusk| V{vow} {pct(gap)} > {GAP_CAP*100:.0f} pp")
    ash5 = holdout[5]["ashwarden"]["winRate"]
    if ash5 > 0.85:
        reasons.append(f"V5 Ash holdout {pct(ash5)} >85%")
    if reasons:
        return "VETO", EXIT_VETO, reasons
    high = [f"{LABEL[k]} {pct(arm2[k]['winRate'])}" for k in CELLS if arm2[k]["winRate"] >= ARM2_GO]
    if high:
        return "NO-GO", EXIT_NOGO, [f"arm 2 ≥50%: {', '.join(high)}"]
    return "GO", EXIT_GO, ["all four arm-2 cells <50% and #204 bands hold"]


def table(arm2: dict, holdout: dict, baseline: dict) -> str:
    b2 = arm_map(baseline["controls"], 2) if baseline.get("controls") else {}
    bh = baseline.get("holdout") or {}
    lines = ["### Arm 2 (random build / competent play, 4000–4199, n=200)",
             "",
             "| Grid | Wins / runs | Rate | vs H1 | Signal |",
             "|---|---:|---:|---:|---|"]
    for key in CELLS:
        c = arm2[key]
        base = b2.get(key)
        delta = (c["winRate"] - base["winRate"]) if base else None
        sig = "—" if delta is None else ("drop" if delta <= -DROP_PP / 100 else (
            "up" if delta >= DROP_PP / 100 else "noise"))
        vs = "—" if delta is None else f"{pp(delta)} pp"
        lines.append(f"| {LABEL[key]} | {c['wins']} / {c['runs']} | **{pct(c['winRate'])}** | {vs} | {sig} |")
    lines += ["",
              "A move counts only at **≥6 pp**. n=200 Wilson width is ~±5 pp.",
              "",
              "### #204 holdout (5000–5199, `--mix=none`, n=200)",
              "",
              "| Cell | Wins / runs | Rate | vs H1 | Band |",
              "|---|---:|---:|---:|---|"]
    for key in CELLS:
        c = holdout[key[1]][key[0]]
        band = V0_BAND if key[1] == 0 else V5_BAND
        gate = "PASS" if band[0] <= c["winRate"] <= band[1] else "FAIL"
        base = (bh.get(key[1]) or {}).get(key[0])
        vs = "—" if not base else f"{pp(c['winRate'] - base['winRate'])} pp"
        lines.append(
            f"| {LABEL[key]} | {c['wins']} / {c['runs']} | **{pct(c['winRate'])}** | {vs} | "
            f"{band[0]*100:.0f}–{band[1]*100:.0f} **{gate}** |")
    v0 = holdout[0]["ashwarden"]["winRate"] - holdout[0]["duskblade"]["winRate"]
    v5 = holdout[5]["ashwarden"]["winRate"] - holdout[5]["duskblade"]["winRate"]
    lines += ["", f"|Ash−Dusk| V0 **{pp(v0)} pp**, V5 **{pp(v5)} pp** (cap 20)."]
    return "\n".join(lines)


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--baseline", type=Path, default=REPO / "docs/balance/data/421/phase-a-baseline.json")
    p.add_argument("--out-dir", type=Path, default=Path("/tmp/glassvow-phase-a"))
    p.add_argument("--jobs", type=int, default=2)
    p.add_argument("--godot", default="godot")
    p.add_argument("--controls-json", type=Path, help="skip controls; reuse sweep raw or aggregated JSON")
    p.add_argument("--holdout-vow0", type=Path, help="skip Vow-0 holdout; reuse Metrics.report JSON")
    p.add_argument("--holdout-vow5", type=Path, help="skip Vow-5 holdout; reuse Metrics.report JSON")
    p.add_argument("--seeds", type=int, default=200)
    p.add_argument("--seed0-controls", type=int, default=4000)
    p.add_argument("--seed0-holdout", type=int, default=5000)
    return p.parse_args()


def main() -> int:
    opts = parse_args()
    out_dir: Path = opts.out_dir
    out_dir.mkdir(parents=True, exist_ok=True)
    baseline = load_baseline(opts.baseline) if opts.baseline.exists() else {"controls": [], "holdout": None}

    controls_path = opts.controls_json or (out_dir / "controls.json")
    holdout_paths = {0: opts.holdout_vow0 or (out_dir / "holdout-vow0.json"),
                     5: opts.holdout_vow5 or (out_dir / "holdout-vow5.json")}

    jobs = []
    if opts.controls_json is None:
        jobs.append(("controls", ["res://tools/balance_sweep.gd",
                                  f"--mode=controls", f"--seeds={opts.seeds}",
                                  f"--seed0={opts.seed0_controls}", f"--out={controls_path}"],
                     out_dir / "controls.log"))
    for vow in VOWS:
        if (opts.holdout_vow0 if vow == 0 else opts.holdout_vow5) is None:
            jobs.append((f"holdout-v{vow}",
                         ["res://tools/balance_sim.gd", f"--vow={vow}", f"--runs={opts.seeds}",
                          f"--seed0={opts.seed0_holdout}", "--aspect=all", "--mix=none",
                          f"--out={holdout_paths[vow]}"],
                         out_dir / f"holdout-vow{vow}.log"))

    if jobs:
        holdout_jobs = [j for j in jobs if j[0].startswith("holdout")]
        other = [j for j in jobs if not j[0].startswith("holdout")]
        workers = max(1, min(opts.jobs, max(len(holdout_jobs), 1)))

        def _run(job):
            name, flags, log = job
            code = run_godot(opts.godot, flags[0], flags[1:], log)
            return name, code, log

        failed = []
        if holdout_jobs:
            with ThreadPoolExecutor(max_workers=workers) as pool:
                for name, code, log in pool.map(_run, holdout_jobs):
                    if code != 0:
                        failed.append((name, code, log))
        for job in other:
            name, code, log = _run(job)
            if code != 0:
                failed.append((name, code, log))
        if failed:
            for name, code, log in failed:
                print(f"balance_phase_a: {name} exited {code}; see {log}", file=sys.stderr)
            return EXIT_ERR

    controls, ctrl_man = aggregate_controls(load_json(controls_path))
    holdout = {vow: holdout_from_report(load_json(holdout_paths[vow]), vow) for vow in VOWS}
    hold_men = [manifest_of(load_json(holdout_paths[vow])) for vow in VOWS]
    shas = [m.get("contentSha256") for m in [ctrl_man, *hold_men] if m.get("contentSha256")]
    if shas and any(s != shas[0] for s in shas):
        print("balance_phase_a: contentSha256 mismatch across jobs: " + ", ".join(shas), file=sys.stderr)
        return EXIT_ERR
    sha = shas[0] if shas else file_sha256(REPO / "content/full-content.json")
    godot_ver = next((m.get("godot") for m in [ctrl_man, *hold_men] if m.get("godot")), "unknown")
    commit = next((m.get("commit") for m in [ctrl_man, *hold_men] if m.get("commit")), git_head())
    arm2 = arm_map(controls, 2)
    name, code, reasons = verdict(arm2, holdout)

    deltas = {"arm2": {}, "holdout": {}}
    b2 = arm_map(baseline["controls"], 2) if baseline.get("controls") else {}
    for key in CELLS:
        if key in b2:
            deltas["arm2"][f"{key[0]}:v{key[1]}"] = arm2[key]["winRate"] - b2[key]["winRate"]
    if baseline.get("holdout"):
        for aspect, vow in CELLS:
            base = baseline["holdout"][vow][aspect]
            deltas["holdout"][f"{aspect}:v{vow}"] = holdout[vow][aspect]["winRate"] - base["winRate"]

    report = {
        "contentSha256": sha, "godot": godot_ver, "commit": commit, "verdict": name,
        "reasons": reasons, "controls": controls, "holdout": {str(v): holdout[v] for v in VOWS},
        "deltas": deltas, "baseline": {
            "path": str(opts.baseline), "contentSha256": baseline.get("contentSha256"),
            "commit": baseline.get("commit"),
        },
    }
    out_json = out_dir / "phase-a.json"
    out_json.write_text(json.dumps(report, indent=2) + "\n")
    print(f"# Phase A — **{name}**")
    print()
    print(f"Content SHA `{sha}`. Commit `{commit[:12]}`. Godot `{godot_ver}` (pin 4.7.1).")
    print()
    print(table(arm2, holdout, baseline))
    print()
    print(f"**Verdict: {name}** — " + "; ".join(reasons) + ".")
    print()
    print(f"Wrote `{out_json}`.")
    if name != "GO":
        print("Do not start a landscape.")
    return code


if __name__ == "__main__":
    sys.exit(main())
