#!/usr/bin/env python3
"""Deterministically consolidate the bounded residual action-trace audit."""

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
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(65_536), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_json(path: Path, maximum_bytes: int | None = None) -> dict[str, Any]:
    if maximum_bytes is not None and path.stat().st_size > maximum_bytes:
        raise ValueError(f"{path} exceeds {maximum_bytes} bytes")
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"{path} must contain one JSON object")
    return value


def expected_cells(protocol: dict[str, Any]) -> list[str]:
    design = protocol["design"]
    return [
        f"{seam}:{operator}"
        for seam in design["seamLevels"]
        for operator in design["operatorLevels"]
    ]


def validate_report(
    report: dict[str, Any],
    hypothesis: str,
    protocol_sha256: str,
    source_head: str,
    cells: list[str],
) -> None:
    if report.get("hypothesis") != hypothesis:
        raise ValueError(f"expected hypothesis {hypothesis}")
    if report.get("protocolSha256") != protocol_sha256:
        raise ValueError(f"{hypothesis} protocol identity mismatch")
    if report.get("sourceHead") != source_head:
        raise ValueError(f"{hypothesis} source identity mismatch")
    if report.get("verdict") not in {"COMPLETE", "INCONCLUSIVE"}:
        raise ValueError(f"{hypothesis} has invalid verdict")
    findings = report.get("cells")
    if not isinstance(findings, dict) or sorted(findings) != sorted(cells):
        raise ValueError(f"{hypothesis} must cover the exact design matrix")
    for cell_id in cells:
        finding = findings[cell_id]
        if not isinstance(finding, dict):
            raise ValueError(f"{hypothesis} {cell_id} must be an object")
        if not isinstance(finding.get("reason"), str) or not finding["reason"].strip():
            raise ValueError(f"{hypothesis} {cell_id} requires a reason")
        evidence = finding.get("evidence")
        if not isinstance(evidence, list) or not evidence or not all(
            isinstance(item, str) and item.strip() for item in evidence
        ):
            raise ValueError(f"{hypothesis} {cell_id} requires cited evidence")


def decide(
    protocol: dict[str, Any],
    protocol_sha256: str,
    runner_sha256: str,
    source: dict[str, Any],
    closure: dict[str, Any],
    policy: dict[str, Any],
) -> dict[str, Any]:
    cells = expected_cells(protocol)
    source_head = protocol["sourceIdentity"]["head"]
    validate_report(source, "H1_SOURCE_SEAM_FEASIBILITY", protocol_sha256, source_head, cells)
    validate_report(closure, "H2_IMMUTABLE_CLOSURE_ALIAS", protocol_sha256, source_head, cells)
    validate_report(policy, "H3_POLICY_OBSERVABILITY", protocol_sha256, source_head, cells)

    reports = [source, closure, policy]
    if any(report["verdict"] == "INCONCLUSIVE" for report in reports):
        outcome = "INCONCLUSIVE"
        decision = "INCONCLUSIVE_RECORD_AT_PREREGISTERED_CAP"
        selected = None
        assessments: list[dict[str, Any]] = []
    else:
        seam_rank = protocol["ranking"]["seamRank"]
        operator_rank = protocol["ranking"]["operatorRank"]
        assessments = []
        for cell_id in cells:
            source_finding = source["cells"][cell_id]
            closure_finding = closure["cells"][cell_id]
            policy_finding = policy["cells"][cell_id]
            gates = {
                "sourceSupported": source_finding.get("sourceSupported") is True,
                "aliasFree": closure_finding.get("aliasFree") is True,
                "policyExpressible": policy_finding.get("policyExpressible") is True,
                "mediatorObservable": policy_finding.get("mediatorObservable") is True,
                "newSelectorRequired": policy_finding.get("newSelectorRequired") is False,
            }
            seam, operator = cell_id.split(":", 1)
            assessments.append(
                {
                    "cellId": cell_id,
                    "eligible": all(gates.values()),
                    "gates": gates,
                    "rankKey": [seam_rank[seam], operator_rank[operator], cell_id],
                }
            )
        eligible = sorted(
            (item for item in assessments if item["eligible"]),
            key=lambda item: item["rankKey"],
        )
        if eligible:
            outcome = "SUCCESS"
            decision = "SUCCESS_FREEZE_ONE_ABSTRACT_ACTION_TRACE_CONTRACT"
            selected = eligible[0]["cellId"]
        else:
            outcome = "FUTILITY"
            decision = "FUTILITY_CLOSE_RESIDUAL_ACTION_TRACE_GRAMMAR"
            selected = None

    return {
        "schemaVersion": 1,
        "issue": 421,
        "sourceHead": source_head,
        "protocolSha256": protocol_sha256,
        "runnerSha256": runner_sha256,
        "reportSha256": {
            source["hypothesis"]: source["reportSha256"],
            closure["hypothesis"]: closure["reportSha256"],
            policy["hypothesis"]: policy["reportSha256"],
        },
        "outcome": outcome,
        "decision": decision,
        "selectedAbstractCell": selected,
        "assessments": assessments,
        "newSimulatorRows": 0,
        "ledgerReads": 0,
        "ledgerWrites": 0,
        "protectedSeedRows": 0,
        "candidateCount": 0,
        "claimBoundary": protocol["claimBoundary"],
    }


def self_test() -> None:
    protocol = {
        "sourceIdentity": {"head": "abc"},
        "design": {"seamLevels": ["S1"], "operatorLevels": ["O1"]},
        "ranking": {"seamRank": {"S1": 0}, "operatorRank": {"O1": 0}},
        "claimBoundary": "abstract only",
    }
    base = {
        "protocolSha256": "p",
        "sourceHead": "abc",
        "verdict": "COMPLETE",
        "reportSha256": "r",
        "cells": {"S1:O1": {"reason": "test", "evidence": ["x:1"]}},
    }
    source = {**base, "hypothesis": "H1_SOURCE_SEAM_FEASIBILITY"}
    source["cells"]["S1:O1"]["sourceSupported"] = True
    closure = json.loads(json.dumps({**base, "hypothesis": "H2_IMMUTABLE_CLOSURE_ALIAS"}))
    closure["cells"]["S1:O1"]["aliasFree"] = True
    policy = json.loads(json.dumps({**base, "hypothesis": "H3_POLICY_OBSERVABILITY"}))
    policy["cells"]["S1:O1"].update(
        {"policyExpressible": True, "mediatorObservable": True, "newSelectorRequired": False}
    )
    result = decide(protocol, "p", "q", source, closure, policy)
    assert result["outcome"] == "SUCCESS"
    closure["cells"]["S1:O1"]["aliasFree"] = False
    result = decide(protocol, "p", "q", source, closure, policy)
    assert result["outcome"] == "FUTILITY"
    closure["verdict"] = "INCONCLUSIVE"
    result = decide(protocol, "p", "q", source, closure, policy)
    assert result["outcome"] == "INCONCLUSIVE"
    print("PASS (3 checks)")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--protocol", type=Path)
    parser.add_argument("--source-report", type=Path)
    parser.add_argument("--closure-report", type=Path)
    parser.add_argument("--policy-report", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return 0
    required = [args.protocol, args.source_report, args.closure_report, args.policy_report, args.output]
    if any(path is None for path in required):
        parser.error("normal execution requires protocol, three reports, and output")
    protocol = load_json(args.protocol)
    protocol_sha256 = sha256_path(args.protocol)
    reports = [
        load_json(args.source_report, MAX_REPORT_BYTES),
        load_json(args.closure_report, MAX_REPORT_BYTES),
        load_json(args.policy_report, MAX_REPORT_BYTES),
    ]
    for report, path in zip(reports, [args.source_report, args.closure_report, args.policy_report]):
        declared = report.get("reportSha256")
        unsigned = dict(report)
        unsigned.pop("reportSha256", None)
        actual = hashlib.sha256(canonical_bytes(unsigned)).hexdigest()
        if declared != actual:
            raise ValueError(f"{path} canonical report identity mismatch")
    result = decide(
        protocol,
        protocol_sha256,
        sha256_path(Path(__file__)),
        reports[0],
        reports[1],
        reports[2],
    )
    args.output.write_bytes(canonical_bytes(result))
    print(f"{result['outcome']} {result['decision']}")
    return {"SUCCESS": 0, "FUTILITY": 2, "INCONCLUSIVE": 3}[result["outcome"]]


if __name__ == "__main__":
    raise SystemExit(main())
