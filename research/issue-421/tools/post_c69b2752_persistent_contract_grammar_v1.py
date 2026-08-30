#!/usr/bin/env python3
"""Consolidate the frozen #421 persistent-contract background audit."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any


ISSUE_ROOT = Path(__file__).resolve().parents[1]


def _canonical(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _load(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"{path}: expected object")
    return value


def _report_faults(protocol: dict[str, Any], reports: list[dict[str, Any]]) -> list[str]:
    expected = protocol["backgroundAudit"]
    candidates = set(protocol["candidates"])
    faults: list[str] = []
    if len(reports) != len(expected):
        return ["report-count"]
    for report, audit in zip(reports, expected):
        name = audit["hypothesis"]
        if report.get("hypothesis") != name:
            faults.append(f"{name}:hypothesis")
        if report.get("protocolSha256") != protocol["identity"]["protocolSha256"]:
            faults.append(f"{name}:protocol")
        if report.get("sourceHead") != protocol["sourceIdentity"]["head"]:
            faults.append(f"{name}:source")
        if report.get("verdict") != "COMPLETE":
            faults.append(f"{name}:verdict")
        rows = report.get("candidates")
        if not isinstance(rows, dict) or set(rows) != candidates:
            faults.append(f"{name}:candidate-set")
    return faults


def _decide(protocol: dict[str, Any], reports: list[dict[str, Any]]) -> dict[str, Any]:
    faults = _report_faults(protocol, reports)
    base = {
        "schemaVersion": 1,
        "issue": 421,
        "protocolSha256": protocol["identity"]["protocolSha256"],
        "sourceHead": protocol["sourceIdentity"]["head"],
        "faults": faults,
        "GodotProcesses": 0,
        "simulatorRows": 0,
        "ledgerReads": 0,
        "ledgerWrites": 0,
        "protectedSeedRows": 0,
        "productMutations": 0,
    }
    if faults:
        return base | {
            "outcome": "INCONCLUSIVE",
            "decision": "record-persistent-grammar-inconclusive-at-cap",
            "selectedCandidate": None,
            "eligibleCandidates": [],
        }

    by_hypothesis = {report["hypothesis"]: report for report in reports}
    eligible: list[str] = []
    assessments: dict[str, Any] = {}
    for candidate_id, candidate in protocol["candidates"].items():
        source = by_hypothesis["H1_CURRENT_MAIN_COMPATIBILITY"]["candidates"][candidate_id]
        alias = by_hypothesis["H2_ALIAS_AND_CLOSURE"]["candidates"][candidate_id]
        decision = by_hypothesis["H3_DECISION_VALUE_AND_POLICY_EXPOSURE"]["candidates"][candidate_id]
        gates = {
            "sourceReachable": source.get("sourceReachable") is True,
            "contractComplete": source.get("contractComplete") is True,
            "nonBreaking": source.get("breakingBoundary") is False,
            "closedEvidencePreserved": alias.get("allClosuresPreserved") is True,
            "notClosedAlias": alias.get("notClosedAlias") is True,
            "evidenceBacked": decision.get("evidenceBacked") is True,
            "policyExposureTestable": decision.get("policyExposureTestable") is True,
            "capacityEstimandAvailable": decision.get("preRowCapacityEstimandAvailable") is True,
            "productSemanticsComplete": decision.get("productSemanticsComplete") is True,
        }
        assessments[candidate_id] = {"rank": candidate["rank"], "gates": gates}
        if all(gates.values()):
            eligible.append(candidate_id)
    eligible.sort(key=lambda item: (protocol["candidates"][item]["rank"], item))
    selected = eligible[0] if eligible else None
    return base | {
        "outcome": "SUCCESS" if selected else "FUTILITY",
        "decision": (
            "freeze-one-persistent-contract-for-separate-preregistration"
            if selected
            else "close-frozen-persistent-contract-grammar-at-zero-row-boundary"
        ),
        "selectedCandidate": selected,
        "eligibleCandidates": eligible,
        "assessments": assessments,
    }


def _self_test() -> None:
    protocol = {
        "identity": {"protocolSha256": "p"},
        "sourceIdentity": {"head": "s"},
        "backgroundAudit": [
            {"hypothesis": "H1_CURRENT_MAIN_COMPATIBILITY"},
            {"hypothesis": "H2_ALIAS_AND_CLOSURE"},
            {"hypothesis": "H3_DECISION_VALUE_AND_POLICY_EXPOSURE"},
        ],
        "candidates": {"late": {"rank": 2}, "early": {"rank": 1}},
    }
    common = {"protocolSha256": "p", "sourceHead": "s", "verdict": "COMPLETE"}
    h1 = common | {"hypothesis": "H1_CURRENT_MAIN_COMPATIBILITY", "candidates": {
        key: {"sourceReachable": True, "contractComplete": True, "breakingBoundary": False}
        for key in protocol["candidates"]}}
    h2 = common | {"hypothesis": "H2_ALIAS_AND_CLOSURE", "candidates": {
        key: {"allClosuresPreserved": True, "notClosedAlias": True}
        for key in protocol["candidates"]}}
    h3 = common | {"hypothesis": "H3_DECISION_VALUE_AND_POLICY_EXPOSURE", "candidates": {
        key: {"evidenceBacked": True, "policyExposureTestable": True,
              "preRowCapacityEstimandAvailable": True, "productSemanticsComplete": True}
        for key in protocol["candidates"]}}
    assert _decide(protocol, [h1, h2, h3])["selectedCandidate"] == "early"
    h2["candidates"]["early"]["notClosedAlias"] = False
    h2["candidates"]["late"]["notClosedAlias"] = False
    assert _decide(protocol, [h1, h2, h3])["outcome"] == "FUTILITY"
    assert _decide(protocol, [h1, h2])["outcome"] == "INCONCLUSIVE"
    print("PASS (3 checks)")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--protocol", type=Path)
    parser.add_argument("--out", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        _self_test()
        return 0
    protocol_path = args.protocol or ISSUE_ROOT / "protocols/post-c69b2752-persistent-contract-grammar-v1.json"
    protocol = _load(protocol_path)
    protocol.setdefault("identity", {})["protocolSha256"] = _sha256(protocol_path)
    if _sha256(Path(__file__)) != protocol["runner"]["sha256"]:
        raise ValueError("runner SHA-256 mismatch")
    reports = [_load(ISSUE_ROOT / row["reportPath"]) for row in protocol["backgroundAudit"]]
    result = _decide(protocol, reports)
    text = _canonical(result) + "\n"
    if args.out:
        args.out.write_text(text, encoding="utf-8")
    else:
        print(text, end="")
    return 0 if result["outcome"] == "SUCCESS" else (3 if result["outcome"] == "FUTILITY" else 4)


if __name__ == "__main__":
    raise SystemExit(main())
