#!/usr/bin/env python3
"""Validate and consolidate the frozen #421 enemy-action reports once."""

from __future__ import annotations

import argparse
import hashlib
import json
import tempfile
import time
from pathlib import Path
from typing import Any


PROTOCOL_SHA = "b2af1f5f035925d11407524a96064f50e0cd6e7eea44179680a1937810baa488"
TRANSFORMS = [
    "CANCEL_NEXT_ACTION",
    "DEFER_SAME_ACTION_ONE_ROUND",
    "TARGET_ACTS_LAST_THIS_PHASE",
    "REDIRECT_ATTACK_TO_OTHER_ENEMY",
]
INPUTS = {
    "H1_SOURCE_FEASIBILITY": {
        "protocol": PROTOCOL_SHA,
        "projection": "3a904647359e2dd4654b9242577a24f1b1c66e84a8dbcafa806bc122ebdb547d",
    },
    "H2_CLOSURE_ADVERSARY": {
        "protocol": PROTOCOL_SHA,
        "privateCausalCoverage": "c5ae1f503bf8d6ce677473ec8aeb965b720390ce10e68115226f99f9d94def76",
        "contractClosureEnvelope": "3d0c3f87a04345cc3d10169895dc95c5e4347b12d11fdcce650e1c1f881c949f",
        "nextFrontierClosureMap": "58324e9f4ac1b0ec420445cad83e0247a10b8084776b0fc8010a323b73d27535",
    },
    "H3_POLICY_COMMERCIAL": {
        "protocol": PROTOCOL_SHA,
        "projection": "3a904647359e2dd4654b9242577a24f1b1c66e84a8dbcafa806bc122ebdb547d",
        "factorSource": "fd275e4610100562050fce4c59889caae644e93020e03e0e1b85c0c4147fff3d",
        "issueBody": "bac41ba7e3e77fce0ee8e8c5a72c0af07d2084ba86eba91ad80d3428e0e63a3d",
    },
}
FIELDS = {
    "H1_SOURCE_FEASIBILITY": {
        "transformId", "mechanicallyFeasible", "exactNullFeasible",
        "rngIdentityFeasible", "requiredGameplayHookCount",
        "requiredNewStateFieldCount", "requiredNewEventTypeCount",
        "existingSameTransition", "exactEvidence",
    },
    "H2_CLOSURE_ADVERSARY": {
        "transformId", "newSemanticEdge", "completeTwelveFields",
        "closureAliases", "hardContractViolations", "exactEvidence",
    },
    "H3_POLICY_COMMERCIAL": {
        "transformId", "ordinaryPolicyTargetExposable",
        "commercialLegibilityFeasible", "saveInternalIdSafe",
        "actionMultisetPreserved", "playerDamageTargetPreserved",
        "requiredPresentationHookCount", "hardGuardrailViolations",
        "exactEvidence",
    },
}
PRESERVATION = {
    "CANCEL_NEXT_ACTION": (False, True),
    "DEFER_SAME_ACTION_ONE_ROUND": ("conditional-until-combat-end", True),
    "TARGET_ACTS_LAST_THIS_PHASE": (True, True),
    "REDIRECT_ATTACK_TO_OTHER_ENEMY": (True, False),
}


class InvalidReport(ValueError):
    pass


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise InvalidReport(message)


def exact_keys(value: dict[str, Any], expected: set[str], locator: str) -> None:
    require(set(value) == expected, f"{locator} keys")


def string_list(value: Any, locator: str, *, non_empty: bool = False) -> None:
    require(isinstance(value, list), f"{locator} array")
    require(all(isinstance(item, str) and item.strip() for item in value), f"{locator} strings")
    require(not non_empty or bool(value), f"{locator} non-empty")


def boolean(value: Any, locator: str) -> None:
    require(type(value) is bool, f"{locator} boolean")


def count(value: Any, locator: str) -> None:
    require(type(value) is int and value >= 0, f"{locator} non-negative integer")


def validate_report(report: Any, report_id: str) -> dict[str, dict[str, Any]]:
    require(isinstance(report, dict), f"{report_id} object")
    exact_keys(
        report,
        {"schemaVersion", "reportId", "inputSha256", "transforms", "prohibitedActionsObserved"},
        report_id,
    )
    require(report["schemaVersion"] == 1, f"{report_id} schema")
    require(report["reportId"] == report_id, f"{report_id} identity")
    require(report["inputSha256"] == INPUTS[report_id], f"{report_id} input hashes")
    require(report["prohibitedActionsObserved"] == [], f"{report_id} prohibited action")
    transforms = report["transforms"]
    require(isinstance(transforms, list) and len(transforms) == 4, f"{report_id} transform count")
    require([row.get("transformId") for row in transforms if isinstance(row, dict)] == TRANSFORMS,
            f"{report_id} transform order")
    rows: dict[str, dict[str, Any]] = {}
    for row in transforms:
        transform_id = row["transformId"]
        exact_keys(row, FIELDS[report_id], f"{report_id}/{transform_id}")
        string_list(row["exactEvidence"], f"{report_id}/{transform_id}/exactEvidence", non_empty=True)
        if report_id == "H1_SOURCE_FEASIBILITY":
            for field in ("mechanicallyFeasible", "exactNullFeasible", "rngIdentityFeasible", "existingSameTransition"):
                boolean(row[field], f"{report_id}/{transform_id}/{field}")
            for field in ("requiredGameplayHookCount", "requiredNewStateFieldCount", "requiredNewEventTypeCount"):
                count(row[field], f"{report_id}/{transform_id}/{field}")
        elif report_id == "H2_CLOSURE_ADVERSARY":
            for field in ("newSemanticEdge", "completeTwelveFields"):
                boolean(row[field], f"{report_id}/{transform_id}/{field}")
            for field in ("closureAliases", "hardContractViolations"):
                string_list(row[field], f"{report_id}/{transform_id}/{field}")
        else:
            for field in ("ordinaryPolicyTargetExposable", "commercialLegibilityFeasible", "saveInternalIdSafe", "playerDamageTargetPreserved"):
                boolean(row[field], f"{report_id}/{transform_id}/{field}")
            expected_multiset, expected_target = PRESERVATION[transform_id]
            require(type(row["actionMultisetPreserved"]) is bool or
                    row["actionMultisetPreserved"] == "conditional-until-combat-end",
                    f"{report_id}/{transform_id}/actionMultisetPreserved type")
            require(row["actionMultisetPreserved"] == expected_multiset,
                    f"{report_id}/{transform_id}/actionMultisetPreserved")
            require(row["playerDamageTargetPreserved"] == expected_target,
                    f"{report_id}/{transform_id}/playerDamageTargetPreserved")
            count(row["requiredPresentationHookCount"], f"{report_id}/{transform_id}/requiredPresentationHookCount")
            string_list(row["hardGuardrailViolations"], f"{report_id}/{transform_id}/hardGuardrailViolations")
        rows[transform_id] = row
    return rows


def eligibility(h1: dict[str, Any], h2: dict[str, Any], h3: dict[str, Any]) -> tuple[bool, list[str]]:
    failures: list[str] = []
    checks = {
        "mechanically feasible": h1["mechanicallyFeasible"],
        "exact null feasible": h1["exactNullFeasible"],
        "RNG identity feasible": h1["rngIdentityFeasible"],
        "no existing same transition": not h1["existingSameTransition"],
        "new semantic edge": h2["newSemanticEdge"],
        "complete twelve fields": h2["completeTwelveFields"],
        "no closure alias": not h2["closureAliases"],
        "no hard contract violation": not h2["hardContractViolations"],
        "ordinary policy target exposure": h3["ordinaryPolicyTargetExposable"],
        "commercial legibility feasible": h3["commercialLegibilityFeasible"],
        "save/internal-ID safe": h3["saveInternalIdSafe"],
        "no hard guardrail violation": not h3["hardGuardrailViolations"],
    }
    failures.extend(label for label, passed in checks.items() if not passed)
    return not failures, failures


def rank_key(transform_id: str, h1: dict[str, Any], h3: dict[str, Any]) -> tuple[Any, ...]:
    multiset_rank = {True: 0, "conditional-until-combat-end": 1, False: 2}
    return (
        multiset_rank[h3["actionMultisetPreserved"]],
        0 if h3["playerDamageTargetPreserved"] else 1,
        h1["requiredNewStateFieldCount"],
        h1["requiredGameplayHookCount"],
        h1["requiredNewEventTypeCount"] + h3["requiredPresentationHookCount"],
        transform_id,
    )


def consolidate(protocol: dict[str, Any], reports: dict[str, dict[str, Any]], report_hashes: dict[str, str]) -> dict[str, Any]:
    require(protocol.get("schemaVersion") == 1, "protocol schema")
    require([row.get("id") for row in protocol.get("finiteTransformPartition", [])] == TRANSFORMS,
            "protocol transform order")
    rows = {report_id: validate_report(report, report_id) for report_id, report in reports.items()}
    assessments: list[dict[str, Any]] = []
    for transform_id in TRANSFORMS:
        h1 = rows["H1_SOURCE_FEASIBILITY"][transform_id]
        h2 = rows["H2_CLOSURE_ADVERSARY"][transform_id]
        h3 = rows["H3_POLICY_COMMERCIAL"][transform_id]
        eligible, failures = eligibility(h1, h2, h3)
        assessments.append({
            "transformId": transform_id,
            "eligible": eligible,
            "eligibilityFailures": failures,
            "rankKey": list(rank_key(transform_id, h1, h3)),
        })
    eligible = sorted((row for row in assessments if row["eligible"]), key=lambda row: tuple(row["rankKey"]))
    selected = eligible[0]["transformId"] if eligible else None
    if selected:
        outcome, boundary, decision = "SUCCESS", 1, "FREEZE_ONE_ABSTRACT_TRANSFORM_FOR_ZERO_ROW_GATE"
    else:
        outcome, boundary, decision = "FUTILITY", 2, "CLOSE_ENEMY_ACTION_TRANSFORM_PARTITION"
    selected_contract = None
    if selected:
        selected_contract = {
            "common": protocol["commonTwelveFieldContract"],
            "transform": next(row for row in protocol["finiteTransformPartition"] if row["id"] == selected),
        }
    return {
        "schemaVersion": 1,
        "issue": 421,
        "outcome": outcome,
        "decisionBoundary": boundary,
        "decision": decision,
        "selectedTransformId": selected,
        "selectedAbstractContract": selected_contract,
        "eligibleTransformIds": [row["transformId"] for row in eligible],
        "assessments": assessments,
        "protocolSha256": PROTOCOL_SHA,
        "reportSha256": report_hashes,
        "candidateCount": 0,
        "newSimulatorRows": 0,
        "GodotProcesses": 0,
        "cacheReads": 0,
        "cacheWrites": 0,
        "ledgerReads": 0,
        "ledgerWrites": 0,
        "protectedSeedRows": 0,
        "claimBoundary": protocol["claimBoundary"],
    }


def canonical(value: dict[str, Any]) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n").encode()


def write_once(path: Path, data: bytes) -> None:
    require(not path.exists(), "refusing to overwrite consolidation")
    with path.open("xb") as handle:
        handle.write(data)


def sample_reports() -> dict[str, dict[str, Any]]:
    reports: dict[str, dict[str, Any]] = {}
    for report_id in INPUTS:
        transforms: list[dict[str, Any]] = []
        for index, transform_id in enumerate(TRANSFORMS):
            if report_id == "H1_SOURCE_FEASIBILITY":
                row = {"transformId": transform_id, "mechanicallyFeasible": True, "exactNullFeasible": True,
                       "rngIdentityFeasible": True, "requiredGameplayHookCount": index + 1,
                       "requiredNewStateFieldCount": 1, "requiredNewEventTypeCount": 0,
                       "existingSameTransition": False, "exactEvidence": ["projection"]}
            elif report_id == "H2_CLOSURE_ADVERSARY":
                row = {"transformId": transform_id, "newSemanticEdge": True, "completeTwelveFields": True,
                       "closureAliases": [], "hardContractViolations": [], "exactEvidence": ["closure"]}
            else:
                multiset, target = PRESERVATION[transform_id]
                row = {"transformId": transform_id, "ordinaryPolicyTargetExposable": True,
                       "commercialLegibilityFeasible": True, "saveInternalIdSafe": True,
                       "actionMultisetPreserved": multiset, "playerDamageTargetPreserved": target,
                       "requiredPresentationHookCount": 1, "hardGuardrailViolations": [],
                       "exactEvidence": ["projection"]}
            transforms.append(row)
        reports[report_id] = {"schemaVersion": 1, "reportId": report_id,
                              "inputSha256": INPUTS[report_id], "transforms": transforms,
                              "prohibitedActionsObserved": []}
    return reports


def self_test() -> None:
    protocol = {
        "schemaVersion": 1,
        "finiteTransformPartition": [{"id": value} for value in TRANSFORMS],
        "commonTwelveFieldContract": {},
        "claimBoundary": "bounded",
    }
    reports = sample_reports()
    result = consolidate(protocol, reports, {report_id: "0" * 64 for report_id in reports})
    assert result["outcome"] == "SUCCESS"
    assert result["selectedTransformId"] == "TARGET_ACTS_LAST_THIS_PHASE"
    invalid = json.loads(json.dumps(reports["H1_SOURCE_FEASIBILITY"]))
    invalid["unexpected"] = True
    try:
        validate_report(invalid, "H1_SOURCE_FEASIBILITY")
        raise AssertionError("extra report field accepted")
    except InvalidReport:
        pass
    invalid_h3 = json.loads(json.dumps(reports["H3_POLICY_COMMERCIAL"]))
    invalid_h3["transforms"][0]["actionMultisetPreserved"] = 0
    try:
        validate_report(invalid_h3, "H3_POLICY_COMMERCIAL")
        raise AssertionError("integer preservation flag accepted")
    except InvalidReport:
        pass
    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory) / "result.json"
        write_once(path, canonical(result))
        try:
            write_once(path, canonical(result))
            raise AssertionError("overwrite accepted")
        except InvalidReport:
            pass
    print("PASS (5 checks)")


def main() -> None:
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--self-test", action="store_true")
    mode.add_argument("--consolidate", action="store_true")
    parser.add_argument("--protocol", type=Path)
    parser.add_argument("--h1", type=Path)
    parser.add_argument("--h2", type=Path)
    parser.add_argument("--h3", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return
    require(all((args.protocol, args.h1, args.h2, args.h3, args.output)), "all consolidation paths required")
    started = time.monotonic()
    protocol_bytes = args.protocol.read_bytes()
    require(sha256(protocol_bytes) == PROTOCOL_SHA, "protocol hash")
    report_paths = {
        "H1_SOURCE_FEASIBILITY": args.h1,
        "H2_CLOSURE_ADVERSARY": args.h2,
        "H3_POLICY_COMMERCIAL": args.h3,
    }
    report_bytes = {report_id: path.read_bytes() for report_id, path in report_paths.items()}
    reports = {report_id: json.loads(data) for report_id, data in report_bytes.items()}
    result = consolidate(json.loads(protocol_bytes), reports,
                         {report_id: sha256(data) for report_id, data in report_bytes.items()})
    result["runnerSha256"] = sha256(Path(__file__).read_bytes())
    result["wallTimeSeconds"] = round(time.monotonic() - started, 6)
    write_once(args.output, canonical(result))
    print(json.dumps({"status": result["outcome"], "decision": result["decision"],
                      "selectedTransformId": result["selectedTransformId"],
                      "outputSha256": sha256(args.output.read_bytes())}, sort_keys=True))


if __name__ == "__main__":
    main()
