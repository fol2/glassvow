#!/usr/bin/env python3
"""Audit whether the frozen V33-V38 studies identify individual causal levers."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from itertools import combinations
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parent
PROTOCOL = ROOT / "protocols/post-v38-identification-v1.json"
LEVERS = ("mediatorPayoff", "acquisitionPriority", "wardSetupPriority", "faultlineRarity")


def file_sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def changed_levers(left: dict[str, Any], right: dict[str, Any]) -> list[str]:
    return [name for name in LEVERS if left[name] != right[name]]


def same_cohorts(left: dict[str, Any], right: dict[str, Any]) -> bool:
    return left["seedBases"] == right["seedBases"] and left["researchCohorts"] == right["researchCohorts"]


def self_check() -> None:
    base = {name: 0 for name in LEVERS}
    one_change = {**base, "mediatorPayoff": 1}
    two_changes = {**one_change, "faultlineRarity": 1}
    assert changed_levers(base, one_change) == ["mediatorPayoff"]
    assert len(changed_levers(base, two_changes)) == 2
    cohorts = {"seedBases": {"control": 10}, "researchCohorts": {"control": "10-19"}}
    assert same_cohorts(cohorts, dict(cohorts))
    assert not same_cohorts(cohorts, {**cohorts, "seedBases": {"control": 20}})


def audit() -> dict[str, Any]:
    contract = json.loads(PROTOCOL.read_text())
    if file_sha(ROOT / "ledger/research.sqlite") != contract["immutableInputs"]["ledgerSha256AtV38Freeze"]:
        raise RuntimeError("V38 ledger freeze has drifted")
    for relative, expected in contract["immutableInputs"]["files"].items():
        actual = file_sha(ROOT / relative)
        if actual != expected:
            raise RuntimeError(f"immutable input drift: {relative} expected {expected} got {actual}")
    head = subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=ROOT / "source", check=True,
        capture_output=True, text=True,
    ).stdout.strip()
    if head != contract["immutableInputs"]["sourceCommit"]:
        raise RuntimeError(f"source commit drift: expected {contract['immutableInputs']['sourceCommit']} got {head}")

    matrix = {row["study"]: row for row in contract["designMatrix"]}
    studies: dict[str, dict[str, Any]] = {}
    for name, (protocol_file, summary_file) in contract["studyFiles"].items():
        study_protocol = json.loads((ROOT / protocol_file).read_text())
        summary = json.loads((ROOT / summary_file).read_text())
        if summary["protocolSha256"] != file_sha(ROOT / protocol_file):
            raise RuntimeError(f"summary/protocol mismatch: {name}")
        if summary["decision"] != "reject" or summary["boundedNegative"]["protectedSeedsUsed"]:
            raise RuntimeError(f"unexpected frozen decision state: {name}")
        studies[name] = study_protocol

    pairs: list[dict[str, Any]] = []
    exact_zero_local_effects: set[str] = set()
    for left_name, right_name in combinations(matrix, 2):
        differences = changed_levers(matrix[left_name], matrix[right_name])
        if len(differences) != 1:
            continue
        left, right = studies[left_name], studies[right_name]
        common = same_cohorts(left, right)
        reuse = right.get("candidate", {}).get("provenance", {}).get("localGateReuse")
        path_invariant_local = bool(reuse)
        if path_invariant_local:
            exact_zero_local_effects.add(differences[0])
        pairs.append({
            "left": left_name,
            "right": right_name,
            "changedLever": differences[0],
            "commonPoliciesAndSeeds": common,
            "exactPathInvariantLocalZero": path_invariant_local,
            "betweenLevelOutcomeIdentified": common,
        })

    identified_between_level = sorted({pair["changedLever"] for pair in pairs if pair["betweenLevelOutcomeIdentified"]})
    return {
        "schemaVersion": 1,
        "protocolSha256": file_sha(PROTOCOL),
        "decision": "identified" if identified_between_level else "inconclusive",
        "reason": (
            "No one-lever pair used common policies and simulation seeds. Path invariance proves only that "
            "acquisition priority and rarity have zero effect on fixed-deck local combat; it cannot identify "
            "their whole-run effects. V33-V38 therefore remain combination-level bounded negatives."
        ),
        "oneLeverPairs": pairs,
        "identifiedBetweenLevelLevers": identified_between_level,
        "exactZeroFixedDeckLocalEffects": sorted(exact_zero_local_effects),
        "newSimulatorRows": 0,
        "protectedSeedsUsed": False,
        "nextExperimentRequirement": "One preregistered common-random-number identification design; no candidate may be selected from this audit.",
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-check", action="store_true")
    args = parser.parse_args()
    if args.self_check:
        self_check()
    print(json.dumps(audit(), indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
