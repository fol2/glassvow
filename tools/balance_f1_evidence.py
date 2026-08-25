#!/usr/bin/env python3
"""Decision ledger and mini-CEM evidence preparation for #458."""
from __future__ import annotations

import argparse
import copy
import json
import random
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

from balance_f1_f2 import GRIDS, racing_decisions
from balance_f0 import (
    BOOT_SEED,
    aggregate_cells,
    aggregate_controls,
    by_seed,
    deficits,
    grid_proxies,
    lean_and_thick,
    load_control_rows,
    load_landscape_rows,
    seed_block_bootstrap,
)
from balance_seed_contract import file_sha256, load_contract


def decision_record(summary: dict[str, Any], decisions: list[dict[str, str]],
                    evaluation: str) -> dict[str, Any]:
    """Bind every decision to exactly the evidence available at that layer."""
    by_id = {row["id"]: row for row in summary["candidates"]}
    recorded: list[dict[str, Any]] = []
    for decision in decisions:
        row = by_id[decision["id"]]
        recorded.append({
            **decision,
            "evidence": {
                "status": row.get("status"), "earlyStop": row.get("earlyStop"),
                "deficits": row.get("deficits", {}), "proxies": row.get("proxies", {}),
                "bootstrap": row.get("bootstrap", {}),
                "controlStalls": row.get("controlStalls", 0),
                "controlErrors": row.get("controlErrors", 0),
                "landscapeStalls": row.get("landscapeStalls", 0),
                "landscapeErrors": row.get("landscapeErrors", 0),
            },
        })
    return {
        "issue": 458, "evaluation": evaluation, "decisions": recorded,
        "promoted": [row["id"] for row in recorded if row["decision"] == "promote"],
        "stopped": [row["id"] for row in recorded if row["decision"] == "stop"],
    }


def reanalyse_layer(summary: dict[str, Any], layer_dir: Path,
                    n_boot: int, axes: dict[str, Any]) -> dict[str, Any]:
    """Rebuild point and paired bootstrap evidence from immutable raw shards."""
    rebuilt = copy.deepcopy(summary)
    baseline_control_paths = sorted((layer_dir / "c000" / "controls").glob("shard-*.json"))
    baseline_land_paths = sorted((layer_dir / "c000" / "landscape").glob("shard-*.ndjson"))
    if not baseline_control_paths or not baseline_land_paths:
        raise ValueError("raw layer has no complete c000 incumbent")
    baseline_control = by_seed(load_control_rows(baseline_control_paths))
    baseline_land = by_seed(load_landscape_rows(baseline_land_paths))
    for row in rebuilt["candidates"]:
        candidate_id = str(row["id"])
        control_paths = sorted((layer_dir / candidate_id / "controls").glob("shard-*.json"))
        land_paths = sorted((layer_dir / candidate_id / "landscape").glob("shard-*.ndjson"))
        if not control_paths or not land_paths:
            continue
        control_rows = load_control_rows(control_paths)
        land_rows = load_landscape_rows(land_paths)
        proxies = grid_proxies(aggregate_controls(control_rows), aggregate_cells(land_rows, axes))
        row["proxies"] = proxies
        row["deficits"] = deficits(proxies)
        row["bootstrap"] = seed_block_bootstrap(
            by_seed(control_rows), by_seed(land_rows),
            None if candidate_id == "c000" else baseline_control,
            None if candidate_id == "c000" else baseline_land,
            axes, n_boot, BOOT_SEED,
        )
    return rebuilt


def select_cem_policies(rows: list[dict[str, Any]], count: int) -> list[dict[str, Any]]:
    """Take one strong representative per cell, then fill by observed strength."""
    cells: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in rows:
        cells[str(row["cell"])].append(row)
    for values in cells.values():
        values.sort(key=lambda row: (-float(row["wins"]) / max(1, int(row["runs"])),
                                     int(row["policyIndex"])))
    cell_order = sorted(cells, key=lambda cell: (
        -float(cells[cell][0]["wins"]) / max(1, int(cells[cell][0]["runs"])), cell))
    selected = [cells[cell][0] for cell in cell_order[:count]]
    chosen = {int(row["policyIndex"]) for row in selected}
    remaining = sorted((row for values in cells.values() for row in values
                        if int(row["policyIndex"]) not in chosen),
                       key=lambda row: (-float(row["wins"]) / max(1, int(row["runs"])),
                                        int(row["policyIndex"])))
    selected.extend(remaining[:max(0, count - len(selected))])
    return selected


def _policy_evidence(rows: list[dict[str, Any]], axes: dict[str, Any]) -> dict[str, list[dict[str, Any]]]:
    buckets: dict[tuple[str, int], dict[str, Any]] = defaultdict(
        lambda: {"wins": 0, "runs": 0, "cells": defaultdict(int)})
    for row in rows:
        grid = f"{row['aspect']}:v{int(row['vow'])}"
        key = (grid, int(row["policyIndex"]))
        bucket = buckets[key]
        bucket["runs"] += 1
        bucket["wins"] += str(row.get("outcome")) == "win"
        bucket["cells"][":".join(lean_and_thick(row, axes))] += 1
    result: dict[str, list[dict[str, Any]]] = {grid: [] for grid in GRIDS}
    for (grid, policy), bucket in buckets.items():
        cell = sorted(bucket["cells"], key=lambda value: (-bucket["cells"][value], value))[0]
        result[grid].append({"policyIndex": policy, "cell": cell,
                             "wins": bucket["wins"], "runs": bucket["runs"]})
    return result


def prepare_cem_seeds(layer_dir: Path, candidate_ids: list[str], out: Path) -> dict[str, Any]:
    """Use common development policy indices with candidate-specific start-cell identities."""
    axes = load_contract()["frozenLandscape"]

    def evidence(candidate_id: str) -> dict[str, list[dict[str, Any]]]:
        paths = sorted((layer_dir / candidate_id / "landscape").glob("shard-*.ndjson"))
        if not paths:
            raise ValueError(f"missing F1 landscape shards for {candidate_id}")
        return _policy_evidence(load_landscape_rows(paths), axes)

    all_evidence = {candidate_id: evidence(candidate_id) for candidate_id in candidate_ids}
    common = {grid: select_cem_policies(all_evidence["c000"][grid], 6) for grid in GRIDS}
    out.mkdir(parents=True, exist_ok=False)
    for candidate_id in candidate_ids:
        rows_by_grid = all_evidence[candidate_id]
        seeds: dict[str, list[dict[str, Any]]] = {}
        for grid in GRIDS:
            by_policy = {int(row["policyIndex"]): row for row in rows_by_grid[grid]}
            seeds[grid] = [{"cell": by_policy[int(item["policyIndex"])]["cell"],
                            "policyIndex": int(item["policyIndex"]),
                            "layerWins": by_policy[int(item["policyIndex"])]["wins"],
                            "layerRuns": by_policy[int(item["policyIndex"])]["runs"]}
                           for item in common[grid]]
        (out / f"{candidate_id}-seeds.json").write_text(
            json.dumps(seeds, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        manifest = json.loads((layer_dir / candidate_id / "manifest.json").read_text())
        analysis = {"deckCuts": axes["deckCuts"], "medians": axes["medians"], "verdicts": {}}
        for grid, proxy in manifest["proxies"].items():
            analysis["verdicts"][grid] = {
                "topRate": proxy["topRate"],
                "viabilityFloor": (proxy["topRate"] + proxy["arm2Rate"]) / 2,
            }
        (out / f"{candidate_id}-layer-analysis.json").write_text(
            json.dumps(analysis, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    packet = {"issue": 458, "policyRoot": 1454, "candidates": candidate_ids,
              "commonPolicies": {grid: [int(row["policyIndex"]) for row in common[grid]]
                                 for grid in GRIDS}}
    (out / "common.json").write_text(json.dumps(packet, indent=2, sort_keys=True) + "\n",
                                      encoding="utf-8")
    return packet


def _interval(values: list[float]) -> dict[str, float]:
    ordered = sorted(values)
    if not ordered:
        raise ValueError("cannot summarise an empty interval")

    def quantile(fraction: float) -> float:
        return ordered[round(fraction * (len(ordered) - 1))]

    return {"p025": quantile(0.025), "p50": quantile(0.5),
            "p975": quantile(0.975)}


def _read_cem_island(path: Path, axes: dict[str, Any]) -> dict[str, Any]:
    manifest: dict[str, Any] | None = None
    final: dict[str, Any] | None = None
    holdout: list[dict[str, Any]] = []
    generations: list[dict[str, Any]] = []
    with path.open(encoding="utf-8") as handle:
        for line in handle:
            row = json.loads(line)
            if row.get("t") == "manifest":
                manifest = row
            elif row.get("t") == "gen":
                generations.append(row)
            elif row.get("t") == "holdout":
                holdout.append(row)
            elif row.get("t") == "final":
                final = row
    if manifest is None or final is None:
        raise ValueError(f"incomplete mini-CEM island {path}")
    expected = int(final["holdoutRuns"])
    if len(holdout) != expected or int(final["holdoutWins"]) != sum(
            str(row.get("outcome")) == "win" for row in holdout):
        raise ValueError(f"mini-CEM holdout count drift in {path}")
    cells = Counter(":".join(lean_and_thick(row, axes)) for row in holdout)
    end_cell = sorted(cells, key=lambda cell: (-cells[cell], cell))[0]
    return {
        "path": path, "manifest": manifest, "final": final,
        "holdout": holdout, "generations": generations,
        "endCell": end_cell, "endCounts": dict(sorted(cells.items())),
    }


def mini_cem_report(candidate_dir: Path, analysis_path: Path,
                    axes: dict[str, Any]) -> dict[str, Any]:
    """Summarise all 24 development islands without acceptance semantics."""
    analysis = json.loads(analysis_path.read_text(encoding="utf-8"))
    islands = [_read_cem_island(path, axes)
               for path in sorted(candidate_dir.glob("island-*.ndjson"))]
    if len(islands) != 24:
        raise ValueError(f"{candidate_dir} has {len(islands)} mini-CEM islands, expected 24")
    grids: dict[str, Any] = {}
    for grid in GRIDS:
        current = sorted((row for row in islands if str(row["final"]["grid"]) == grid),
                         key=lambda row: int(row["final"]["island"]))
        if len(current) != 6:
            raise ValueError(f"{candidate_dir} grid {grid} has {len(current)} islands")
        verdict = analysis["verdicts"][grid]
        floor, top = float(verdict["viabilityFloor"]), float(verdict["topRate"])
        best = max(float(row["final"]["holdoutCeiling"]) for row in current)
        stayed = [row for row in current
                  if row["endCell"] == str(row["final"]["startCell"])
                  and float(row["final"]["holdoutCeiling"]) + 1e-12 >= floor]
        close = [row for row in stayed
                 if float(row["final"]["holdoutCeiling"]) + 1e-12 >= best - 0.15]
        cell_ceilings: dict[str, float] = {}
        for row in current:
            cell = str(row["endCell"])
            cell_ceilings[cell] = max(cell_ceilings.get(cell, -1.0),
                                      float(row["final"]["holdoutCeiling"]))
        ceilings = sorted(cell_ceilings.values(), reverse=True)
        c4 = len(ceilings) >= 2 and ceilings[0] - ceilings[1] < 0.15 - 1e-12
        grids[grid] = {
            "layerProxyTopRate": top, "viabilityFloor": floor,
            "bestCeiling": best,
            "medianCeiling": _interval(
                [float(row["final"]["holdoutCeiling"]) for row in current])["p50"],
            "stayedViable": len(stayed), "closeToBest": len(close),
            "developmentC3": len(stayed) >= 4 and len(close) >= 3,
            "developmentC4": c4,
            "cellCeilings": dict(sorted(cell_ceilings.items())),
            "islands": [{
                "island": int(row["final"]["island"]),
                "policyIndex": int(row["final"]["policyIndex"]),
                "startCell": str(row["final"]["startCell"]),
                "endCell": row["endCell"], "endCounts": row["endCounts"],
                "holdoutWins": int(row["final"]["holdoutWins"]),
                "holdoutRuns": int(row["final"]["holdoutRuns"]),
                "holdoutCeiling": float(row["final"]["holdoutCeiling"]),
                "generations": int(row["final"]["gens"]),
                "stop": str(row["final"]["stop"]),
            } for row in current],
        }
    return {"islands": len(islands), "grids": grids, "_raw": islands}


def _paired_cem_grid(candidate: list[dict[str, Any]], baseline: list[dict[str, Any]],
                     n_boot: int, rng: random.Random) -> dict[str, Any]:
    def outcomes(rows: list[dict[str, Any]]) -> dict[tuple[int, int], float]:
        result: dict[tuple[int, int], float] = {}
        for island in rows:
            island_id = int(island["final"]["island"])
            for row in island["holdout"]:
                result[(island_id, int(row["seed"]))] = float(str(row.get("outcome")) == "win")
        return result

    current, incumbent = outcomes(candidate), outcomes(baseline)
    if set(current) != set(incumbent):
        raise ValueError("candidate and c000 mini-CEM holdouts are not paired")
    island_ids = sorted({key[0] for key in current})
    seed_ids = sorted({key[1] for key in current})
    if len(island_ids) != 6:
        raise ValueError("paired mini-CEM grid must contain six islands")

    def delta(draw: list[int]) -> float:
        return sum(current[(island, seed)] - incumbent[(island, seed)]
                   for island in island_ids for seed in draw) / (len(island_ids) * len(draw))

    point = delta(seed_ids)
    samples = [delta([rng.choice(seed_ids) for _ in seed_ids]) for _ in range(n_boot)]
    return {"winRateDelta": point, "interval": _interval(samples),
            "pHigher": sum(value > 0 for value in samples) / n_boot,
            "holdoutSeeds": [seed_ids[0], seed_ids[-1]], "seedBlocks": len(seed_ids),
            "islands": len(island_ids), "bootstrap": n_boot}


def mini_cem_comparison(cem_dir: Path, candidate_ids: list[str], seeds_dir: Path,
                        n_boot: int) -> dict[str, Any]:
    """Report candidate-specific CEM shape and paired holdout uncertainty."""
    if "c000" not in candidate_ids:
        raise ValueError("mini-CEM comparison requires c000")
    axes = load_contract()["frozenLandscape"]
    reports = {
        candidate_id: mini_cem_report(
            cem_dir / candidate_id, seeds_dir / f"{candidate_id}-layer-analysis.json", axes)
        for candidate_id in candidate_ids
    }
    baseline = reports["c000"]["_raw"]
    candidates: list[dict[str, Any]] = []
    for offset, candidate_id in enumerate(candidate_ids):
        report = reports[candidate_id]
        paired: dict[str, Any] = {}
        for grid_index, grid in enumerate(GRIDS):
            current = [row for row in report["_raw"] if str(row["final"]["grid"]) == grid]
            incumbent = [row for row in baseline if str(row["final"]["grid"]) == grid]
            paired[grid] = _paired_cem_grid(
                current, incumbent, n_boot,
                random.Random(458 + offset * 101 + grid_index),
            )
        candidates.append({"id": candidate_id, "grids": report["grids"],
                           "pairedVsC000": paired})
    raw_hashes = {
        candidate_id: {path.name: file_sha256(path)
                       for path in sorted((cem_dir / candidate_id).glob("island-*.ndjson"))}
        for candidate_id in candidate_ids
    }
    return {"issue": 458, "method": "paired holdout-seed block bootstrap",
            "candidates": candidates, "inputs": {
                "rawSha256ByCandidate": raw_hashes,
                "seedPacketSha256": file_sha256(seeds_dir / "common.json"),
                "toolSha256": file_sha256(Path(__file__)),
            }}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    decide = sub.add_parser("decide")
    decide.add_argument("--summary", required=True)
    decide.add_argument("--protocol", default="docs/balance/458-f1-f2-protocol-v1.json")
    decide.add_argument("--evaluation", required=True)
    decide.add_argument("--layer-dir", required=True,
                        help="raw evaluator directory used to reconstruct paired evidence")
    decide.add_argument("--out", required=True)
    cem = sub.add_parser("cem-seeds")
    cem.add_argument("--layer-dir", required=True)
    cem.add_argument("--candidates", required=True)
    cem.add_argument("--out", required=True)
    compare = sub.add_parser("cem-compare")
    compare.add_argument("--cem-dir", required=True)
    compare.add_argument("--seeds-dir", required=True)
    compare.add_argument("--candidates", required=True)
    compare.add_argument("--boot", type=int, default=4000)
    compare.add_argument("--out", required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.command == "cem-seeds":
        packet = prepare_cem_seeds(Path(args.layer_dir), args.candidates.split(","), Path(args.out))
        print(json.dumps(packet, sort_keys=True))
        return 0
    if args.command == "cem-compare":
        report = mini_cem_comparison(
            Path(args.cem_dir), args.candidates.split(","), Path(args.seeds_dir), args.boot)
        out = Path(args.out)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        print(json.dumps({"candidates": [row["id"] for row in report["candidates"]],
                          "out": str(out)}, sort_keys=True))
        return 0
    summary_path, protocol_path = Path(args.summary), Path(args.protocol)
    summary = json.loads(summary_path.read_text(encoding="utf-8"))
    protocol = json.loads(protocol_path.read_text(encoding="utf-8"))
    layer = protocol["evaluations"][args.evaluation]
    summary = reanalyse_layer(
        summary, Path(args.layer_dir), int(layer["bootstrap"]),
        load_contract()["frozenLandscape"],
    )
    decisions = racing_decisions(summary["candidates"], int(layer["maxPromotions"]))
    record = decision_record(summary, decisions, args.evaluation)
    record["inputs"] = {"summarySha256": file_sha256(summary_path),
                        "protocolSha256": file_sha256(protocol_path),
                        "toolSha256": file_sha256(Path(__file__)),
                        "observationSha256ByCandidate": {
                            str(row["id"]): str(row.get("observationsSha256", ""))
                            for row in summary["candidates"]
                        }}
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(record, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
                   encoding="utf-8")
    print(json.dumps({"evaluation": args.evaluation, "promoted": record["promoted"],
                      "stopped": len(record["stopped"]), "out": str(out)}, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (KeyError, OSError, TypeError, ValueError, RuntimeError) as exc:
        print(f"balance_f1_evidence: {exc}", file=sys.stderr)
        raise SystemExit(2) from exc
