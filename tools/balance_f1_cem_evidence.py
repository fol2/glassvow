#!/usr/bin/env python3
"""Development mini-CEM seed and comparison evidence for #458."""
from __future__ import annotations

import json
import random
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

from balance_f1_f2 import GRIDS
from balance_f0 import lean_and_thick, load_landscape_rows
from balance_seed_contract import CONTRACT_REL, REPO, file_sha256, load_contract


def _tool_hashes() -> dict[str, str]:
    tools_dir = Path(__file__).parent
    names = (Path(__file__).name, "balance_f0.py", "balance_seed_contract.py")
    return {name: file_sha256(tools_dir / name) for name in names}


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
    contract = load_contract()
    axes = contract["frozenLandscape"]

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
    packet = {
        "issue": 458, "policyRoot": int(contract["development"]["f1PolicyRoot"]),
        "candidates": candidate_ids,
        "commonPolicies": {
            grid: [int(row["policyIndex"]) for row in common[grid]] for grid in GRIDS
        },
        "inputs": {
            "manifestSha256ByCandidate": {
                candidate_id: file_sha256(layer_dir / candidate_id / "manifest.json")
                for candidate_id in candidate_ids
            },
            "observationsSha256ByCandidate": {
                candidate_id: file_sha256(layer_dir / candidate_id / "observations.jsonl")
                for candidate_id in candidate_ids
            },
            "seedRegistrySha256": file_sha256(REPO / CONTRACT_REL),
            "toolSha256ByModule": _tool_hashes(),
        },
    }
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


def vow5_ceiling(grids: dict[str, Any]) -> dict[str, Any]:
    """Apply the development-only upper-ceiling check to both Vow-5 grids."""
    rows = {
        grid: {"bestCeiling": float(grids[grid]["bestCeiling"]),
               "clear": float(grids[grid]["bestCeiling"]) <= 0.90 + 1e-12}
        for grid in ("duskblade:v5", "ashwarden:v5")
    }
    return {"grids": rows, "clear": all(row["clear"] for row in rows.values())}


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
    return {"islands": len(islands), "grids": grids,
            "vow5Ceiling": vow5_ceiling(grids),
            "_raw": islands}


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
    seed_hashes = {
        candidate_id: file_sha256(seeds_dir / f"{candidate_id}-seeds.json")
        for candidate_id in candidate_ids
    }
    for candidate_id, report in reports.items():
        if any(str(row["manifest"].get("seedPacketSha256")) != seed_hashes[candidate_id]
               for row in report["_raw"]):
            raise ValueError(f"mini-CEM seed packet drift for {candidate_id}")
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
                           "vow5Ceiling": report["vow5Ceiling"],
                           "pairedVsC000": paired})
    raw_hashes = {
        candidate_id: {path.name: file_sha256(path)
                       for path in sorted((cem_dir / candidate_id).glob("island-*.ndjson"))}
        for candidate_id in candidate_ids
    }
    return {"issue": 458, "method": "paired holdout-seed block bootstrap",
            "candidates": candidates, "inputs": {
                "rawSha256ByCandidate": raw_hashes,
                "commonSeedPacketSha256": file_sha256(seeds_dir / "common.json"),
                "seedPacketSha256ByCandidate": seed_hashes,
                "layerAnalysisSha256ByCandidate": {
                    candidate_id: file_sha256(
                        seeds_dir / f"{candidate_id}-layer-analysis.json")
                    for candidate_id in candidate_ids
                },
                "cemManifestSha256": file_sha256(cem_dir / "manifest.json"),
                "seedRegistrySha256": file_sha256(REPO / CONTRACT_REL),
                "toolSha256ByModule": _tool_hashes(),
            }}
