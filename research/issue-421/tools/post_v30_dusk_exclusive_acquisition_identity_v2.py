#!/usr/bin/env python3
"""Zero-new-row ChoiceScreen identity v2 over immutable v1 artefacts."""

from __future__ import annotations

import json
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v30-dusk-exclusive-acquisition-identity-v2.json"
SUMMARY = core.ROOT / "summaries/post-v30-dusk-exclusive-acquisition-identity-v2.json"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"ChoiceScreen identity v2 mismatch: {label}")


def cache_object(digest: str) -> dict[str, Any]:
    path = core.CACHE / f"{digest}.json"
    require(f"cache object {digest} exists", path.is_file())
    require(f"cache object {digest} identity", core.file_sha(path) == digest)
    value = json.loads(path.read_text())
    require(f"cache object {digest} JSON type", isinstance(value, dict))
    return value


def verify_file(spec: dict[str, str]) -> dict[str, Any]:
    path = core.ROOT / spec["path"]
    require(f"{spec['path']} exists", path.is_file())
    require(f"{spec['path']} identity", core.file_sha(path) == spec["sha256"])
    return json.loads(path.read_text())


def expected_whole_specs(v1: dict[str, Any]) -> list[dict[str, Any]]:
    cohort = v1["identityCohort"]
    return [
        {
            "mode": "whole",
            "aspect": cohort["aspect"],
            "vow": cohort["vow"],
            "seed": seed,
            "policyRoot": cohort["policyRoot"],
            "policyIndex": policy_index,
        }
        for policy_index in range(cohort["policyCount"])
        for seed in cohort["simulationSeeds"]
    ]


def verify_plan(
    label: str, plan: dict[str, Any], expected_rows: list[dict[str, Any]],
    protocol: dict[str, Any],
) -> None:
    require(f"{label} keys", set(plan) == {
        "schemaVersion", "protocolSha256", "content", "rows",
    })
    require(f"{label} schema", plan["schemaVersion"] == 1)
    require(f"{label} v1 protocol", plan["protocolSha256"] ==
            protocol["v1Evidence"]["protocolSha256"])
    require(f"{label} content path", plan["content"] ==
            protocol["planContract"]["contentPath"])
    require(f"{label} rows", plan["rows"] == expected_rows)


def verify_output(
    label: str, output: dict[str, Any], expected: dict[str, Any],
    row_fields: set[str],
) -> None:
    require(f"{label} keys", set(output) == {
        "schemaVersion", "planSha256", "probeSha256", "contentIdentity", "rows",
    })
    require(f"{label} schema", output["schemaVersion"] == 1)
    require(f"{label} plan identity", output["planSha256"] == expected["planSha256"])
    require(f"{label} probe provenance", output["probeSha256"] ==
            expected["probeSha256"])
    require(f"{label} content/provenance identity", output["contentIdentity"] ==
            expected["contentIdentity"])
    require(f"{label} cardinality", len(output["rows"]) == expected["rows"])
    require(f"{label} row schema", all(
        isinstance(row, dict) and set(row) == row_fields for row in output["rows"]
    ))


def verify_preflight(protocol: dict[str, Any]) -> tuple[dict[str, Any], dict[str, Any]]:
    require("runner identity", core.file_sha(Path(__file__)) ==
            protocol["immutableInputs"]["runnerSha256"])
    v1 = verify_file(protocol["v1Evidence"]["protocol"])
    v1_summary = verify_file(protocol["v1Evidence"]["summary"])
    verify_file(protocol["v1Evidence"]["designProtocol"])
    verify_file(protocol["v1Evidence"]["designSummary"])
    require("v1 runner identity", core.file_sha(
        core.ROOT / protocol["v1Evidence"]["runner"]["path"],
    ) == protocol["v1Evidence"]["runner"]["sha256"])
    require("v1 source identity", v1["immutableInputs"]["prototypeSourceCommit"] ==
            protocol["immutableInputs"]["sourceCommit"] == v1_summary["sourceCommit"])
    require("v1 qualified Godot identity", v1["immutableInputs"]["godotVersion"] ==
            protocol["immutableInputs"]["qualifiedGodotVersion"] ==
            v1_summary["godotVersion"])
    require("v1 qualified Godot binary", v1["immutableInputs"]["godotBinarySha256"] ==
            protocol["immutableInputs"]["qualifiedGodotBinarySha256"])
    require("v1 terminal row count", v1_summary["newIdentityObservationRows"] == 774)
    require("v1 direct controls", v1_summary["directControls"]["status"] == "PASS")
    require("v1 zero enabled whole run", v1_summary["enabledWholeRunRows"] == 0)
    require("v1 zero causal rows", v1_summary["newCausalRows"] == 0)
    require("v1 comparator classification", v1_summary["executionError"] ==
            "Dusk acquisition identity mismatch: content identity across probes")

    objects = {
        name: cache_object(spec["sha256"])
        for name, spec in protocol["cacheObjects"].items()
    }
    require("cache object count", len(objects) ==
            protocol["budget"]["maximumImmutableCacheObjectsRead"])
    require("v1 cache index", v1_summary["cacheObjects"] == {
        spec["summaryKey"]: spec["sha256"]
        for spec in protocol["cacheObjects"].values()
    })

    base_specs = expected_whole_specs(v1)
    per_arm = protocol["cardinalityPreflight"]["rowsPerArm"]
    cohort = v1["identityCohort"]
    require("frozen cohort contract", {
        "policyRoot": cohort["policyRoot"],
        "policyCount": cohort["policyCount"],
        "simulationSeeds": cohort["simulationSeeds"],
        "aspect": cohort["aspect"],
        "vow": cohort["vow"],
    } == {key: protocol["planContract"][key] for key in (
        "policyRoot", "policyCount", "simulationSeeds", "aspect", "vow",
    )})
    require("frozen whole cohort cardinality", len(base_specs) == per_arm)
    explicit_specs = [dict(row, acquisition="off") for row in base_specs]
    direct_specs = [dict(case, mode="direct") for case in v1["directCases"]]
    invalid_spec = dict(v1["directCases"][0], mode="direct", acquisition="invalid")
    verify_plan("baseline plan", objects["baselinePlan"], base_specs, protocol)
    verify_plan("prototype plan", objects["prototypePlan"],
                base_specs + explicit_specs, protocol)
    verify_plan("direct plan", objects["directPlan"], direct_specs, protocol)
    verify_plan("invalid plan", objects["invalidPlan"], [invalid_spec], protocol)

    row_groups = protocol["comparisonContract"]["rowFieldsByEstimand"]
    row_fields = {field for fields in row_groups.values() for field in fields}
    require("canonical row field partition", len(row_fields) == sum(
        len(fields) for fields in row_groups.values()
    ))
    require("canonical row fields", sorted(row_fields) ==
            sorted(protocol["comparisonContract"]["canonicalRowFields"]))
    for name in ("baselineOutput", "prototypeOutput"):
        verify_output(name, objects[name], protocol["outputContract"][name], row_fields)
    direct = objects["directOutput"]
    direct_expected = protocol["outputContract"]["directOutput"]
    require("direct output plan identity", direct["planSha256"] ==
            direct_expected["planSha256"])
    require("direct output probe provenance", direct["probeSha256"] ==
            direct_expected["probeSha256"])
    require("direct output content/provenance identity", direct["contentIdentity"] ==
            direct_expected["contentIdentity"])
    require("direct output cardinality", len(direct["rows"]) == direct_expected["rows"])

    baseline_rows = objects["baselineOutput"]["rows"]
    prototype_rows = objects["prototypeOutput"]["rows"]
    for label, rows, specs in (
        ("baseline", baseline_rows, base_specs),
        ("prototype omitted", prototype_rows[:per_arm], base_specs),
        ("prototype explicit off", prototype_rows[per_arm:], explicit_specs),
    ):
        require(f"{label} identity order", all(
            row["aspect"] == spec["aspect"]
            and row["seed"] == spec["seed"]
            and row["vow"] == spec["vow"]
            for row, spec in zip(rows, specs)
        ))

    semantic_fields = protocol["comparisonContract"]["semanticContentFields"]
    semantic_identities = [
        {field: objects[name]["contentIdentity"][field] for field in semantic_fields}
        for name in ("baselineOutput", "prototypeOutput", "directOutput")
    ]
    require("semantic content identity", len({core.canonical(value)
                                                for value in semantic_identities}) == 1)
    require("semantic content anchor", semantic_identities[0] ==
            protocol["comparisonContract"]["semanticContentAnchor"])
    return objects, {
        "status": "PASS",
        "cacheObjectsVerified": len(objects),
        "baselineRows": len(baseline_rows),
        "prototypeOmittedRows": per_arm,
        "prototypeExplicitOffRows": per_arm,
        "directRows": len(direct["rows"]),
        "rowSchemaFields": len(row_fields),
        "semanticContentIdentityExact": True,
        "perArmProvenanceExact": True,
        "cohortOrderExact": True,
    }


def compare_rows(
    left: list[dict[str, Any]], right: list[dict[str, Any]],
    groups: dict[str, list[str]],
) -> dict[str, Any]:
    return {
        "rows": len(left),
        "completeRowMismatchRows": sum(a != b for a, b in zip(left, right)),
        "mismatchRowsByEstimand": {
            name: sum(any(a[field] != b[field] for field in fields)
                      for a, b in zip(left, right))
            for name, fields in groups.items()
        },
        "mismatchRowsByField": {
            field: sum(a[field] != b[field] for a, b in zip(left, right))
            for field in sorted({field for fields in groups.values() for field in fields})
        },
    }


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite completed ChoiceScreen identity v2")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    ledger_before: dict[str, Any] = {}
    ledger_after: dict[str, Any] = {}
    preflight: dict[str, Any] = {"status": "UNRESOLVED"}
    comparisons: dict[str, Any] = {}
    error = ""
    try:
        ledger_before = identity.ledger_identity()
        require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
        objects, preflight = verify_preflight(protocol)
        per_arm = protocol["cardinalityPreflight"]["rowsPerArm"]
        baseline = objects["baselineOutput"]["rows"]
        prototype = objects["prototypeOutput"]["rows"]
        groups = protocol["comparisonContract"]["rowFieldsByEstimand"]
        comparisons = {
            "pristineVersusOmitted": compare_rows(
                baseline, prototype[:per_arm], groups,
            ),
            "omittedVersusExplicitOff": compare_rows(
                prototype[:per_arm], prototype[per_arm:], groups,
            ),
        }
        ledger_after = identity.ledger_identity()
        require("zero-row ledger identity", ledger_after == ledger_before)
    except (FileNotFoundError, json.JSONDecodeError, KeyError, TypeError,
            ValueError, RuntimeError) as caught:
        error = str(caught)

    elapsed = time.monotonic() - started
    if not error and elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        error = "ChoiceScreen identity v2 exceeded its wall-time ceiling"
    if error:
        boundary, outcome = 3, "inconclusive"
        decision = "close-choice-screen-identity-v2-unresolved"
    elif all(
        result["completeRowMismatchRows"] == 0
        and all(value == 0 for value in result["mismatchRowsByEstimand"].values())
        and all(value == 0 for value in result["mismatchRowsByField"].values())
        for result in comparisons.values()
    ):
        boundary, outcome = 1, "success"
        decision = "freeze-choice-screen-identity-v2"
    else:
        boundary, outcome = 2, "futility"
        decision = "close-choice-screen-contract-on-genuine-identity-mismatch"

    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "decisionBoundary": boundary,
        "decision": decision,
        "outcomeClass": outcome,
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "preflight": preflight,
        "comparisons": comparisons,
        "executionError": error,
        "reusedV1IdentityObservationRows": 768 if preflight["status"] == "PASS" else 0,
        "newIdentityObservationRows": 0,
        "enabledWholeRunRows": 0,
        "newCapacityRows": 0,
        "newSupportRows": 0,
        "newCausalRows": 0,
        "newLedgerRows": 0,
        "GodotProcesses": 0,
        "protectedSeedRows": ledger_after.get(
            "protectedSeedRows", ledger_before.get("protectedSeedRows", 0),
        ),
        "maximumModelContextTokens": 0,
        "wallTimeSeconds": elapsed,
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "authority": protocol["decisionRules"][f"{outcome}Authority"],
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": "PASS",
        "decisionBoundary": boundary,
        "decision": decision,
        "newIdentityObservationRows": 0,
        "summarySha256": core.file_sha(SUMMARY),
    }))


if __name__ == "__main__":
    main()
