#!/usr/bin/env python3
"""Rebuild and record the uncertainty-aware #492 Tier-1 racing decisions."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

from balance_f0 import (
    by_seed,
    evaluation_from_registry,
    load_control_rows,
    load_landscape_rows,
)
from balance_f0_tier1 import bootstrap_breadth
from balance_seed_contract import file_sha256, load_contract

GRIDS = ("duskblade:v0", "duskblade:v5", "ashwarden:v0", "ashwarden:v5")
C1 = ("c1a", "c1b")
PREVIOUS_LAYER = {"layer2": "layer1", "layer3": "layer2"}
FINAL_RACING_LAYER = "layer3"


def _changed_packages(row: dict[str, Any]) -> list[str]:
    return sorted(key for key, value in row.get("values", {}).items() if value != "s009")


def _mechanisms_fire(row: dict[str, Any]) -> bool:
    diagnostics = row.get("packageDiagnostics", {})
    changed = _changed_packages(row)
    return bool(changed) and all(any(bool(grid.get("mechanismFired"))
                                     for grid in diagnostics.get(package, {}).values())
                                 for package in changed)


def _paired_dominates(left_id: str, right_id: str,
                      pairwise: dict[str, dict[str, Any]]) -> bool:
    intervals = pairwise.get(f"{left_id}:{right_id}", {})
    if not all(key in intervals for key in C1):
        return False
    weak = all(float(intervals[key]["p975"]) <= 0.0 for key in C1)
    strict = any(float(intervals[key]["p975"]) < 0.0 for key in C1)
    return weak and strict


def pairwise_c1(layer_dir: Path, rows: list[dict[str, Any]], n_boot: int,
                seed: int, response_contract: dict[str, Any]) -> dict[str, dict[str, Any]]:
    """Rebuild ordered candidate-to-candidate CRN intervals from raw shards."""
    axes = load_contract()["frozenLandscape"]
    raw: dict[str, tuple[dict[int, list[dict[str, Any]]],
                         dict[int, list[dict[str, Any]]]]] = {}
    for row in rows:
        candidate_id = str(row["id"])
        root = layer_dir / candidate_id
        controls = load_control_rows(sorted((root / "controls").glob("shard-*.json")))
        landscape = load_landscape_rows(sorted((root / "landscape").glob("shard-*.ndjson")))
        if landscape:
            raw[candidate_id] = (by_seed(controls), by_seed(landscape))
    result: dict[str, dict[str, Any]] = {}
    ids = sorted(str(row["id"]) for row in rows if str(row["id"]) in raw)
    if ids:
        control_seeds = set(raw[ids[0]][0])
        landscape_seeds = set(raw[ids[0]][1])
        if any(set(raw[candidate_id][0]) != control_seeds
               or set(raw[candidate_id][1]) != landscape_seeds for candidate_id in ids[1:]):
            raise ValueError("candidate-to-candidate CRN seed rectangles drifted")
    by_id = {str(row["id"]): row for row in rows}
    offset = 0
    for left in ids:
        for right in ids:
            if left == right:
                continue
            offset += 1
            report = bootstrap_breadth(
                raw[left][0], raw[left][1], raw[right][0], raw[right][1], axes,
                response_contract,
                by_id[left]["cells"], n_boot, seed + offset,
                baseline_cells=by_id[right]["cells"])
            result[f"{left}:{right}"] = report["vsBaseline"]["c1"]
    return result


def _strengthened_cells(candidate: dict[str, Any], baseline: dict[str, Any],
                        config: dict[str, Any], aspect: str) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    allowed_lean = set(config["nonDominant"][aspect])
    allowed_thick = set(config["thickness"])
    base_cells = baseline.get("cells", {})
    for name, cell in candidate.get("cells", {}).items():
        parts = str(name).split(":")
        if len(parts) != 4 or parts[0] != aspect or parts[2] not in allowed_lean \
                or parts[3] not in allowed_thick:
            continue
        base = base_cells.get(name, {})
        delta = float(cell.get("winRate", 0.0)) - float(base.get("winRate", 0.0))
        if int(cell.get("policies", 0)) >= int(config["cellMinimumPolicies"]) \
                and int(cell.get("runs", 0)) >= int(config["cellMinimumRuns"]) \
                and delta + 1e-12 >= float(config["cellMinimumWinRateDelta"]):
            result.append({"cell": name, "policies": int(cell["policies"]),
                           "runs": int(cell["runs"]), "winRate": float(cell["winRate"]),
                           "baselineWinRate": float(base.get("winRate", 0.0)),
                           "delta": delta})
    return sorted(result, key=lambda row: (-row["delta"], row["cell"]))


def strong_breadth(candidate: dict[str, Any], baseline: dict[str, Any],
                   config: dict[str, Any]) -> dict[str, Any]:
    """Apply the frozen Layer-1 half of the #492 finalist admission bar."""
    proxies = candidate.get("validProxies", {})
    primary = [grid for grid in GRIDS if int(proxies.get(grid, {}).get("within10", 0))
               >= int(config["primaryWithin10"])
               and int(proxies.get(grid, {}).get("viable", 0)) >= int(config["primaryViable"])]
    remaining_clear = all(int(proxies.get(grid, {}).get("within10", 0))
                          >= int(config["remainingWithin10"])
                          and int(proxies.get(grid, {}).get("viable", 0))
                          >= int(config["remainingViable"]) for grid in GRIDS)
    paired = _paired_breadth(candidate)
    no_regression = all(grid in paired and float(paired[grid]["p025"])
                        <= float(config["credibleRegressionLowerBoundMax"]) for grid in GRIDS)
    strengthened = {aspect: _strengthened_cells(candidate, baseline, config, aspect)
                    for aspect in ("duskblade", "ashwarden")}
    clear = len(primary) >= int(config["primaryGridCount"]) and remaining_clear \
        and no_regression and all(strengthened.values())
    return {"clear": clear, "primaryGrids": primary, "remainingGridFloor": remaining_clear,
            "noCredibleBreadthRegression": no_regression,
            "strengthenedNonDominantCells": strengthened}


def _paired_c1(row: dict[str, Any]) -> dict[str, Any]:
    return ((row.get("bootstrap") or {}).get("vsBaseline") or {}).get("c1") or {}


def _paired_breadth(row: dict[str, Any]) -> dict[str, Any]:
    return ((row.get("bootstrap") or {}).get("vsBaseline") or {}).get("breadth") or {}


def _hard_stop(row: dict[str, Any], baseline: dict[str, Any]) -> str:
    if row.get("status") != "complete" or row.get("earlyStop"):
        return str(row.get("earlyStop") or "incomplete")
    if int(row.get("controlErrors", 0)) or int(row.get("landscapeErrors", 0)):
        return "simulator-error"
    if int(row.get("controlStalls", 0)) > int(baseline.get("controlStalls", 0)) \
            or int(row.get("landscapeStalls", 0)) > int(baseline.get("landscapeStalls", 0)):
        return "stalls-beyond-baseline"
    if not bool(row.get("guardrails", {}).get("clear")):
        return "hard-guardrail-failed"
    if not _mechanisms_fire(row):
        return "mechanism-not-fired"
    paired = _paired_c1(row)
    if not all(key in paired for key in C1):
        return "missing-paired-c1"
    if any(float(paired[key]["p025"]) > 0.0 for key in C1):
        return "credible-c1-regression"
    if not any(float(row.get(f"validC1{key[-1]}", 99.0))
               < float(baseline.get(f"validC1{key[-1]}", 99.0)) for key in C1):
        return "no-point-c1-improvement"
    return ""


def _evidence(row: dict[str, Any]) -> dict[str, Any]:
    return {key: row.get(key) for key in (
        "status", "earlyStop", "validC1a", "validC1b", "validBreadthSum",
        "validProxies", "bootstrap", "guardrails", "controlStalls", "controlErrors",
        "landscapeStalls", "landscapeErrors", "fileSha256", "semanticSha256",
        "observationsSha256", "controlRowCount", "landscapeRowCount", "commit",
        "godotVersion", "hostFingerprint")}


def decide_layer(summary: dict[str, Any], protocol: dict[str, Any],
                 evaluation: str, previous: dict[str, Any] | None = None,
                 pairwise: dict[str, dict[str, Any]] | None = None) -> dict[str, Any]:
    """Return deterministic decisions without collapsing C1a/C1b to a score."""
    config = protocol["evaluations"][evaluation]
    baseline_id = str(protocol["baseline"])
    by_id = {str(row["id"]): row for row in summary["candidates"]}
    if len(by_id) != len(summary["candidates"]):
        raise ValueError(f"{evaluation} contains duplicate candidate ids")
    if baseline_id not in by_id or by_id[baseline_id].get("status") != "complete":
        raise ValueError(f"{evaluation} has no complete {baseline_id}")
    baseline = by_id[baseline_id]
    if evaluation == "layer1":
        expected = list(protocol["racingSet"])
    else:
        prior_name = PREVIOUS_LAYER.get(evaluation)
        if prior_name is None:
            raise ValueError(f"{evaluation} is not a racing layer")
        if previous is None or previous.get("evaluation") != prior_name:
            raise ValueError(f"{evaluation} requires the exact prior-layer decisions")
        expected = list(previous.get("promoted", []))
    actual = [candidate_id for candidate_id in protocol["racingSet"] if candidate_id in by_id]
    if set(by_id) != {baseline_id, *expected} or actual != expected:
        raise ValueError(f"{evaluation} does not contain the exact candidate set")
    eligible: list[dict[str, Any]] = []
    decisions: list[dict[str, Any]] = [{"id": baseline_id, "decision": "baseline",
                                        "reason": "paired-incumbent",
                                        "evidence": _evidence(baseline)}]
    stopped: dict[str, str] = {}
    strong_by_id: dict[str, dict[str, Any]] = {}
    for candidate_id in expected:
        row = by_id[candidate_id]
        reason = _hard_stop(row, baseline)
        if not reason and evaluation == FINAL_RACING_LAYER:
            strong_by_id[candidate_id] = strong_breadth(
                row, baseline, protocol["finalistBar"]["layer1"])
            if not strong_by_id[candidate_id]["clear"]:
                reason = "strong-breadth-not-clear"
        if reason:
            stopped[candidate_id] = reason
        else:
            eligible.append(row)
    paired = pairwise or {}
    if len(eligible) > 1 and not paired:
        raise ValueError("paired candidate-to-candidate C1 intervals are required")
    for left in eligible:
        for right in eligible:
            if left["id"] == right["id"]:
                continue
            intervals = paired.get(f"{left['id']}:{right['id']}") or {}
            if any(set((intervals.get(key) or {})) != {"p025", "p50", "p975"}
                   for key in C1):
                raise ValueError("paired candidate-to-candidate C1 intervals are incomplete")
    for row in list(eligible):
        if any(_paired_dominates(str(other["id"]), str(row["id"]), paired)
               for other in eligible if other["id"] != row["id"]):
            stopped[str(row["id"])] = "paired-confidence-dominated"
    survivors = {str(row["id"]) for row in eligible if str(row["id"]) not in stopped}
    ordered = [candidate_id for candidate_id in protocol["racingSet"]
               if candidate_id in survivors]
    promoted = set(ordered[:int(config["maxPromotions"])])
    for candidate_id in expected:
        row = by_id[candidate_id]
        reason = stopped.get(candidate_id)
        if reason:
            decision = "stop"
        elif candidate_id in promoted:
            decision, reason = "promote", "paired-pareto-non-dominated"
        else:
            decision, reason = "stop", "bounded-promotion-cap"
        record = {"id": candidate_id, "decision": decision, "reason": reason,
                  "changedPackages": _changed_packages(row), "evidence": _evidence(row)}
        if evaluation == FINAL_RACING_LAYER:
            record["strongBreadth"] = strong_by_id.get(
                candidate_id, strong_breadth(row, baseline, protocol["finalistBar"]["layer1"]))
        decisions.append(record)
    return {"issue": int(protocol["issue"]), "evaluation": evaluation,
            "decisions": decisions,
            "promoted": [candidate_id for candidate_id in protocol["racingSet"]
                         if candidate_id in promoted],
            "stopped": [row["id"] for row in decisions if row["decision"] == "stop"]}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--summary", required=True)
    parser.add_argument("--protocol", default="docs/balance/492-tier1-racing-protocol-v1.json")
    parser.add_argument("--evaluation", required=True)
    parser.add_argument("--layer-dir", required=True)
    parser.add_argument("--candidates", required=True)
    parser.add_argument("--previous-decisions", default="")
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    paths = {name: Path(getattr(args, name)) for name in
             ("summary", "protocol", "layer_dir", "candidates")}
    summary = json.loads(paths["summary"].read_text(encoding="utf-8"))
    protocol = json.loads(paths["protocol"].read_text(encoding="utf-8"))
    axes = load_contract()["frozenLandscape"]
    expected_protocol = evaluation_from_registry(protocol, args.evaluation, axes)
    if summary.get("protocol") != expected_protocol:
        raise ValueError("summary evaluation does not match the frozen protocol")
    from balance_f1_evidence import reanalyse_layer
    rebuilt = reanalyse_layer(
        summary, paths["layer_dir"], int(protocol["evaluations"][args.evaluation]["bootstrap"]),
        axes, paths["candidates"])
    previous = None
    if args.previous_decisions:
        previous_path = Path(args.previous_decisions)
        previous = json.loads(previous_path.read_text(encoding="utf-8"))
        paths["previous_decisions"] = previous_path
    if args.evaluation == "layer1" and previous is not None:
        raise ValueError("layer1 does not accept prior-layer decisions")
    if previous is not None:
        inputs = previous.get("inputs") or {}
        promoted_rows = [str(row["id"]) for row in previous.get("decisions", [])
                         if row.get("decision") == "promote"]
        if int(previous.get("issue", 0)) != int(protocol["issue"]) \
                or promoted_rows != previous.get("promoted") \
                or inputs.get("protocolSha256") != file_sha256(paths["protocol"]) \
                or inputs.get("candidateManifestSha256") != file_sha256(
                    paths["candidates"] / "manifest.json"):
            raise ValueError("prior-layer decision receipt is missing or stale")
    response_contract = json.loads((Path(protocol["responseContract"])).read_text())
    pairwise = pairwise_c1(
        paths["layer_dir"], rebuilt["candidates"],
        int(protocol["evaluations"][args.evaluation]["bootstrap"]),
        int(protocol["evaluations"][args.evaluation]["bootstrapSeed"]),
        response_contract)
    raw_hashes: dict[str, str] = {}
    for row in rebuilt["candidates"]:
        observation = paths["layer_dir"] / str(row["id"]) / "observations.jsonl"
        if not observation.is_file() or file_sha256(observation) != row["observationsSha256"]:
            raise ValueError(f"raw observation digest is missing or stale for {row['id']}")
        raw_hashes[str(row["id"])] = file_sha256(observation)
    report = decide_layer(rebuilt, protocol, args.evaluation, previous, pairwise)
    report["pairedCandidateIntervals"] = pairwise
    report["inputs"] = {"summarySha256": file_sha256(paths["summary"]),
                        "protocolSha256": file_sha256(paths["protocol"]),
                        "toolSha256": file_sha256(Path(__file__)),
                        "candidateManifestSha256": file_sha256(paths["candidates"] / "manifest.json"),
                        "observationSha256ByCandidate": raw_hashes}
    if "previous_decisions" in paths:
        report["inputs"]["previousDecisionsSha256"] = file_sha256(
            paths["previous_decisions"])
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"evaluation": args.evaluation, "promoted": report["promoted"],
                      "out": str(out)}, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (KeyError, OSError, TypeError, ValueError) as exc:
        print(f"balance_tier1_racing: {exc}", file=sys.stderr)
        raise SystemExit(2) from exc
