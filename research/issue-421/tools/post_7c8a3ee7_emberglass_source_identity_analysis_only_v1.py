#!/usr/bin/env python3
"""Analyse the immutable #421 Emberglass v2 probe outputs without new rows."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import sys
import time
from pathlib import Path
from typing import Any


ISSUE_ROOT = Path(__file__).resolve().parents[1]
V1_RUNNER = Path(__file__).with_name(
    "post_7c8a3ee7_emberglass_source_identity_v1.py"
)
SPEC = importlib.util.spec_from_file_location("emberglass_source_identity_v1", V1_RUNNER)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"cannot load frozen v1 runner: {V1_RUNNER}")
V1 = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(V1)


def _canonical(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _load_object(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"{path}: expected object")
    return value


def _canonical_sha256(value: Any) -> str:
    return hashlib.sha256(_canonical(value).encode("utf-8")).hexdigest()


def _preflight(protocol: dict[str, Any], protocol_path: Path) -> list[str]:
    faults: list[str] = []

    def expect(name: str, actual: Any, expected: Any) -> None:
        if actual != expected:
            faults.append(f"{name}: expected {expected!r}, got {actual!r}")

    expect("protocol-state", protocol.get("state"), "FROZEN_BEFORE_ANALYSIS")
    expect("protocol-path", str(protocol_path), protocol["protocolPath"])
    expect("runner", _sha256(Path(__file__)), protocol["runner"]["sha256"])
    expect("v1-runner", _sha256(V1_RUNNER), protocol["v1Runner"]["sha256"])

    authority = protocol["authority"]
    expect(
        "authority-comment",
        _sha256(ISSUE_ROOT / authority["commentPath"]),
        authority["commentBodySha256"],
    )

    v1_protocol_path = ISSUE_ROOT / protocol["v1Protocol"]["path"]
    expect("v1-protocol", _sha256(v1_protocol_path), protocol["v1Protocol"]["sha256"])
    v1_protocol = _load_object(v1_protocol_path)
    for key, expected in protocol["inheritedSectionSha256"].items():
        expect(f"v1-section:{key}", _canonical_sha256(v1_protocol[key]), expected)

    for name, item in protocol["immutableInputs"].items():
        expect(f"input:{name}", _sha256(ISSUE_ROOT / item["path"]), item["sha256"])
    return faults


def _decision(gates: list[dict[str, Any]], faults: list[str]) -> tuple[str, str, int]:
    if faults:
        return "INCONCLUSIVE", "record-analysis-inconclusive-at-cap", 2
    if all(bool(gate.get("passed")) for gate in gates):
        return (
            "SUCCESS",
            "freeze-emberglass-source-identity-for-separate-shadow-capacity-preregistration",
            0,
        )
    return "FUTILITY", "close-exact-emberglass-one-carry-contract-without-repair", 1


def _self_test() -> None:
    assert _decision([{"passed": True}], []) == (
        "SUCCESS",
        "freeze-emberglass-source-identity-for-separate-shadow-capacity-preregistration",
        0,
    )
    assert _decision([{"passed": False}], [])[0] == "FUTILITY"
    assert _decision([], ["fault"])[0] == "INCONCLUSIVE"
    print("PASS (3 checks)")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--protocol", type=Path)
    parser.add_argument("--out", type=Path)
    args = parser.parse_args()
    if args.self_test:
        _self_test()
        return 0
    if args.protocol is None or args.out is None:
        parser.error("--protocol and --out are required")
    if args.out.exists():
        raise FileExistsError("single analysis output already exists")

    protocol = _load_object(args.protocol)
    protocol_sha = _sha256(args.protocol)
    base = {
        "schemaVersion": 1,
        "issue": 421,
        "protocolSha256": protocol_sha,
        "sourceHead": protocol["sourceHead"],
        "newGodotProcesses": 0,
        "newControlledScenarioExecutions": 0,
        "reusedDirectControlledExecutions": 40,
        "simulatorRows": 0,
        "ledgerReads": 0,
        "ledgerWrites": 0,
        "protectedSeedRows": 0,
        "productMutations": 0,
    }
    try:
        faults = _preflight(protocol, args.protocol)
    except Exception as exc:
        faults = [f"preflight-exception:{type(exc).__name__}:{exc}"]
    if faults:
        outcome, decision, status = _decision([], faults)
        args.out.write_text(
            json.dumps(base | {
                "outcome": outcome,
                "decision": decision,
                "faults": faults,
                "gates": [],
                "analysisExecutions": 0,
            }, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
        return status

    inputs = protocol["immutableInputs"]
    baseline_path = ISSUE_ROOT / inputs["baselineOutput"]["path"]
    candidate_path = ISSUE_ROOT / inputs["candidateOutput"]["path"]
    v1_protocol = _load_object(ISSUE_ROOT / protocol["v1Protocol"]["path"])
    before_hashes = (_sha256(baseline_path), _sha256(candidate_path))
    started = time.monotonic()
    try:
        baseline = V1._load(baseline_path)
        candidate = V1._load(candidate_path)
        gates = V1._analyse(v1_protocol, baseline, candidate)
        faults = []
    except Exception as exc:
        gates = []
        faults = [f"analysis-exception:{type(exc).__name__}:{exc}"]
    elapsed = time.monotonic() - started
    if elapsed > float(protocol["ceilings"]["maximumAnalysisSeconds"]):
        faults.append(f"analysis-wall-time-cap:{elapsed:.6f}")
    if before_hashes != (_sha256(baseline_path), _sha256(candidate_path)):
        faults.append("immutable-output-hash-changed")

    outcome, decision, status = _decision(gates, faults)
    result = base | {
        "outcome": outcome,
        "decision": decision,
        "faults": faults,
        "gates": gates,
        "analysisExecutions": 1,
        "analysisFunction": "original-v1-_analyse",
        "analysisWallTimeSeconds": round(elapsed, 6),
        "inputHashesAfterAnalysis": {
            "baselineOutput": _sha256(baseline_path),
            "candidateOutput": _sha256(candidate_path),
        },
        "decisionRules": protocol["decisionRules"],
        "claimBoundary": protocol["claimBoundary"],
    }
    args.out.write_text(
        json.dumps(result, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    return status


if __name__ == "__main__":
    sys.exit(main())
