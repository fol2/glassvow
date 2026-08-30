#!/usr/bin/env python3
"""Consolidate the final bounded autonomous mechanism-closure envelope."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any


MAX_REPORT_BYTES = 65_536


def canonical_bytes(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()


def sha256_path(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_report(path: Path) -> dict[str, Any]:
    if path.stat().st_size > MAX_REPORT_BYTES:
        raise ValueError(f"{path} exceeds {MAX_REPORT_BYTES} bytes")
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"{path} must contain one JSON object")
    declared = value.get("reportSha256")
    unsigned = dict(value)
    unsigned.pop("reportSha256", None)
    actual = hashlib.sha256(canonical_bytes(unsigned)).hexdigest()
    if declared != actual:
        raise ValueError(f"{path} canonical report identity mismatch")
    return value


def validate_common(
    report: dict[str, Any], hypothesis: str, protocol_sha256: str, source_head: str
) -> None:
    if report.get("hypothesis") != hypothesis:
        raise ValueError(f"expected hypothesis {hypothesis}")
    if report.get("protocolSha256") != protocol_sha256:
        raise ValueError(f"{hypothesis} protocol identity mismatch")
    if report.get("sourceHead") != source_head:
        raise ValueError(f"{hypothesis} source identity mismatch")
    if report.get("verdict") not in {"COMPLETE", "INCONCLUSIVE"}:
        raise ValueError(f"{hypothesis} invalid verdict")


def decide(
    protocol: dict[str, Any],
    protocol_sha256: str,
    runner_sha256: str,
    closure: dict[str, Any],
    method: dict[str, Any],
    authority: dict[str, Any],
) -> dict[str, Any]:
    source_head = protocol["sourceIdentity"]["head"]
    validate_common(closure, "H1_AUTONOMOUS_CLASS_CLOSURE", protocol_sha256, source_head)
    validate_common(method, "H2_POLICY_METHOD_DECISION_VALUE", protocol_sha256, source_head)
    validate_common(authority, "H3_AUTHORITY_BOUNDARY", protocol_sha256, source_head)

    class_ids = protocol["classPartition"]
    if sorted(closure.get("classes", {})) != sorted(class_ids):
        raise ValueError("H1 must cover the exact class partition")
    for class_id in class_ids:
        finding = closure["classes"][class_id]
        if finding.get("disposition") not in {
            "CLOSED",
            "UNAVAILABLE_AT_CAP",
            "OUTSIDE_AUTONOMOUS_AUTHORITY",
            "ELIGIBLE",
        }:
            raise ValueError(f"invalid disposition for {class_id}")
        if not isinstance(finding.get("autonomouslyEligible"), bool):
            raise ValueError(f"missing eligibility for {class_id}")
        if not finding.get("evidence") or not finding.get("reason"):
            raise ValueError(f"missing cited finding for {class_id}")

    reports = [closure, method, authority]
    incomplete = any(report["verdict"] == "INCONCLUSIVE" for report in reports)
    incomplete = incomplete or closure.get("partitionComplete") is not True
    eligible = sorted(
        (
            class_id
            for class_id in class_ids
            if closure["classes"][class_id]["autonomouslyEligible"] is True
        ),
        key=lambda class_id: [protocol["classRank"][class_id], class_id],
    )
    method_authorised = all(
        [
            method.get("policyBottleneckIdentified") is True,
            method.get("openDecisionTargetExists") is True,
            method.get("measuredDecisionValue") is True,
            method.get("optimizerAuthorised") is True,
        ]
    )

    if incomplete:
        outcome = "INCONCLUSIVE"
        decision = "INCONCLUSIVE_RECORD_AT_PREREGISTERED_CAP"
        selected_class = None
    elif eligible:
        outcome = "SUCCESS"
        decision = "SUCCESS_FREEZE_ONE_DISTINCT_AUTONOMOUS_CLASS"
        selected_class = eligible[0]
    elif method_authorised:
        outcome = "SUCCESS"
        decision = "SUCCESS_FREEZE_ONE_POLICY_METHOD_GATE"
        selected_class = "POLICY_METHOD"
    elif all(
        [
            authority.get("unavailableGateRequiresEscalation") is True,
            authority.get("routineCheckpointProhibited") is True,
            authority.get("successorTicketProhibited") is True,
            authority.get("productAndProtectedStateMustRemainSafe") is True,
        ]
    ):
        outcome = "UNAVAILABLE"
        decision = "ESCALATE_ONE_HUMAN_AUTHORITY_PACKAGE"
        selected_class = None
    else:
        outcome = "INCONCLUSIVE"
        decision = "INCONCLUSIVE_AUTHORITY_MAPPING_AT_CAP"
        selected_class = None

    return {
        "schemaVersion": 1,
        "issue": 421,
        "sourceHead": source_head,
        "protocolSha256": protocol_sha256,
        "runnerSha256": runner_sha256,
        "reportSha256": {
            report["hypothesis"]: report["reportSha256"] for report in reports
        },
        "outcome": outcome,
        "decision": decision,
        "selectedAutonomousClass": selected_class,
        "eligibleAutonomousClasses": eligible,
        "policyMethodAuthorised": method_authorised,
        "classDispositions": {
            class_id: closure["classes"][class_id]["disposition"] for class_id in class_ids
        },
        "newSimulatorRows": 0,
        "GodotProcesses": 0,
        "ledgerReads": 0,
        "ledgerWrites": 0,
        "protectedSeedRows": 0,
        "productMutations": 0,
        "claimBoundary": protocol["claimBoundary"],
    }


def self_test() -> None:
    classes = ["C1"]
    protocol = {
        "sourceIdentity": {"head": "abc"},
        "classPartition": classes,
        "classRank": {"C1": 0},
        "claimBoundary": "test",
    }
    common = {
        "protocolSha256": "p",
        "sourceHead": "abc",
        "verdict": "COMPLETE",
        "reportSha256": "r",
    }
    closure = {
        **common,
        "hypothesis": "H1_AUTONOMOUS_CLASS_CLOSURE",
        "partitionComplete": True,
        "classes": {
            "C1": {
                "disposition": "CLOSED",
                "autonomouslyEligible": False,
                "reason": "test",
                "evidence": ["x:1"],
            }
        },
    }
    method = {
        **common,
        "hypothesis": "H2_POLICY_METHOD_DECISION_VALUE",
        "policyBottleneckIdentified": True,
        "openDecisionTargetExists": False,
        "measuredDecisionValue": False,
        "optimizerAuthorised": False,
    }
    authority = {
        **common,
        "hypothesis": "H3_AUTHORITY_BOUNDARY",
        "unavailableGateRequiresEscalation": True,
        "routineCheckpointProhibited": True,
        "successorTicketProhibited": True,
        "productAndProtectedStateMustRemainSafe": True,
    }
    result = decide(protocol, "p", "q", closure, method, authority)
    assert result["outcome"] == "UNAVAILABLE"
    closure["classes"]["C1"].update(
        {"disposition": "ELIGIBLE", "autonomouslyEligible": True}
    )
    result = decide(protocol, "p", "q", closure, method, authority)
    assert result["outcome"] == "SUCCESS"
    closure["verdict"] = "INCONCLUSIVE"
    result = decide(protocol, "p", "q", closure, method, authority)
    assert result["outcome"] == "INCONCLUSIVE"
    print("PASS (3 checks)")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--protocol", type=Path)
    parser.add_argument("--closure-report", type=Path)
    parser.add_argument("--method-report", type=Path)
    parser.add_argument("--authority-report", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return 0
    if any(
        path is None
        for path in [
            args.protocol,
            args.closure_report,
            args.method_report,
            args.authority_report,
            args.output,
        ]
    ):
        parser.error("normal execution requires protocol, three reports, and output")
    protocol = json.loads(args.protocol.read_text(encoding="utf-8"))
    result = decide(
        protocol,
        sha256_path(args.protocol),
        sha256_path(Path(__file__)),
        load_report(args.closure_report),
        load_report(args.method_report),
        load_report(args.authority_report),
    )
    args.output.write_bytes(canonical_bytes(result))
    print(f"{result['outcome']} {result['decision']}")
    return {"SUCCESS": 0, "UNAVAILABLE": 4, "INCONCLUSIVE": 3}[result["outcome"]]


if __name__ == "__main__":
    raise SystemExit(main())
