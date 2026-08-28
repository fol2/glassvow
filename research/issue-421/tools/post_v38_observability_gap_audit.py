#!/usr/bin/env python3
"""Zero-row audit of remaining source-defined observability gaps."""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path
from typing import Any

import post_v38_action_grammar_inventory as trace
import post_v38_knob_identity as identity
import post_v38_removal_refinement_capacity as capacity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-observability-gap-audit-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-observability-gap-audit-v1.json"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Observability-gap audit mismatch: {label}")


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the observability-gap summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    require("runner SHA", core.file_sha(Path(__file__)) ==
            protocol["immutableInputs"]["runnerSha256"])
    for helper_path, expected_sha in protocol["immutableInputs"]["helperSha256"].items():
        require(f"{helper_path} SHA", core.file_sha(core.ROOT / helper_path) == expected_sha)
    require("source commit", subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=core.SOURCE, check=True,
        text=True, capture_output=True,
    ).stdout.strip() == protocol["immutableInputs"]["sourceCommit"])
    for source_path, expected_sha in protocol["immutableInputs"]["sourceSha256"].items():
        require(f"{source_path} SHA",
                core.sha(capacity.main_blob(source_path)) == expected_sha)
    for surface in protocol["surfaces"]:
        for source_path, fragments in surface["sourceAssertions"].items():
            source_text = capacity.main_blob(source_path).decode()
            for fragment in fragments:
                require(f"{surface['id']} source {fragment}", fragment in source_text)
        for alias in surface["priorClosureAliases"]:
            require(f"{surface['id']} closure evidence {alias}",
                    alias in protocol["priorEvidence"])
    for source_path, fragments in protocol["catalogueSourceAssertions"].items():
        source_text = capacity.main_blob(source_path).decode()
        for fragment in fragments:
            require(f"catalogue source {fragment}", fragment in source_text)
    for name, spec in protocol["priorEvidence"].items():
        path = core.ROOT / spec["path"]
        require(f"{name} SHA", core.file_sha(path) == spec["sha256"])
        require(f"{name} decision", json.loads(path.read_text())["decision"] ==
                spec["decision"])

    ledger_before = identity.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
    baseline_path = core.CACHE / f"{protocol['baseline']['outputSha256']}.json"
    trace_path = core.CACHE / f"{protocol['traceEvidence']['outputSha256']}.json"
    require("baseline output SHA", core.file_sha(baseline_path) ==
            protocol["baseline"]["outputSha256"])
    require("trace output SHA", core.file_sha(trace_path) ==
            protocol["traceEvidence"]["outputSha256"])
    baseline_output = json.loads(baseline_path.read_text())
    trace_output = json.loads(trace_path.read_text())
    require("baseline plan SHA", baseline_output["planSha256"] ==
            protocol["baseline"]["planSha256"])
    require("trace plan SHA", trace_output["planSha256"] ==
            protocol["traceEvidence"]["planSha256"])
    cohort = protocol["cohort"]
    baseline_rows = {
        (int(row["policyIndex"]), int(row["seed"])): row
        for row in baseline_output["rows"] if row.get("arm") == "policy"
        and row.get("aspect") == cohort["aspect"] and int(row.get("vow", -1)) == cohort["vow"]
    }
    rows = {
        (int(row["policyIndex"]), int(row["seed"])): row
        for row in trace_output["rows"] if row.get("arm") == "current"
        and row.get("aspect") == cohort["aspect"] and int(row.get("vow", -1)) == cohort["vow"]
    }
    expected_rows = cohort["policyCount"] * len(cohort["simulationSeeds"])
    require("baseline rectangle", len(baseline_rows) == expected_rows)
    require("trace rectangle", len(rows) == expected_rows)
    require("cached-row ceiling", len(baseline_rows) + len(rows) <=
            protocol["budget"]["maximumCachedObservationRowsRead"])
    row_keys: set[str] = set()
    trajectory_keys: set[str] = set()
    package_keys: set[str] = set()
    for key, row in rows.items():
        require("trace-current frozen identity",
                trace.canonical_without(row) == trace.canonical_without(baseline_rows[key]))
        row_keys.update(map(str, row.keys()))
        trajectory_keys.update(map(str, row.get("trajectory", {}).keys()))
        package_keys.update(map(str, row.get("packageEvents", {}).keys()))

    gates = protocol["eligibilityGates"]
    observed_keys = {
        "row": row_keys,
        "trajectory": trajectory_keys,
        "packageEvents": package_keys,
    }
    surface_ids = [str(surface["id"]) for surface in protocol["surfaces"]]
    require("unique surface IDs", len(surface_ids) == len(set(surface_ids)))
    assessments = []
    for surface in protocol["surfaces"]:
        observation = surface["requiredObservation"]
        container = str(observation["container"])
        require(f"{surface['id']} observation container", container in observed_keys)
        observed = str(observation["key"]) in observed_keys[container]
        completion_path_count = len(surface["completionPaths"])
        direct_policy_control_count = len(surface["directPolicyControls"])
        telemetry_field_count = len(surface["telemetryFields"])
        deterministic_hook_count = len(surface["deterministicHooks"])
        prior_closure_alias = bool(surface["priorClosureAliases"])
        gate_results = {
            "unclosed": not prior_closure_alias,
            "observabilityGap": not observed,
            "sourcePathBreadth": completion_path_count >=
            gates["minimumCompletionPaths"],
            "directPolicyControl": direct_policy_control_count >=
            gates["minimumDirectPolicyControls"],
            "minimalTelemetry": telemetry_field_count <=
            gates["maximumTelemetryFields"],
            "singleHook": deterministic_hook_count <=
            gates["maximumDeterministicHooks"],
        }
        assessments.append({
            "surface": surface,
            "traceObserved": observed,
            "derivedCounts": {
                "completionPaths": completion_path_count,
                "directPolicyControls": direct_policy_control_count,
                "telemetryFields": telemetry_field_count,
                "deterministicHooks": deterministic_hook_count,
            },
            "gateResults": gate_results,
            "eligible": all(gate_results.values()),
        })
    eligible = [result for result in assessments if result["eligible"]]
    eligible.sort(key=lambda result: (
        result["derivedCounts"]["telemetryFields"],
        result["derivedCounts"]["deterministicHooks"],
        result["surface"]["id"],
    ))
    require("expected eligible surfaces",
            [result["surface"]["id"] for result in eligible] ==
            protocol["expectedEligibleSurfaces"])
    selected = eligible[0]["surface"]["id"] if eligible else None
    unresolved_policy_controlled = sum(
        not result["surface"]["priorClosureAliases"]
        and result["derivedCounts"]["directPolicyControls"] >=
        gates["minimumDirectPolicyControls"]
        for result in assessments
    )
    trace_observed_unclosed = sum(
        result["traceObserved"] and not result["surface"]["priorClosureAliases"]
        for result in assessments
    )
    method_rule = protocol["additionalMethodDecisionValue"]
    optimiser_authorised = (
        not eligible
        and unresolved_policy_controlled >= method_rule["minimumUnresolvedSurfaces"]
        and trace_observed_unclosed >= method_rule["minimumTraceObservedSurfaces"]
    )
    elapsed = time.monotonic() - started
    if elapsed > float(protocol["budget"]["maximumWallTimeSeconds"]):
        boundary = 3
        decision = "record-observability-gap-audit-inconclusive-at-cap"
        selected = None
    elif selected is not None:
        boundary = 1
        decision = f"freeze-{selected}-for-identity-safe-telemetry"
    else:
        boundary = 2
        decision = "close-current-missing-telemetry-surface-catalogue"
    require("no optimiser authority", not optimiser_authorised)
    ledger_after = identity.ledger_identity()
    require("zero-row ledger identity", ledger_after == ledger_before)
    summary: dict[str, Any] = {
        "schemaVersion": 1,
        "issue": 421,
        "decisionBoundary": boundary,
        "decision": decision,
        "selectedSurface": selected,
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "assessments": assessments,
        "eligibleSurfaces": [result["surface"]["id"] for result in eligible],
        "traceSchema": {
            "rowKeys": sorted(row_keys),
            "trajectoryKeys": sorted(trajectory_keys),
            "packageEventKeyCount": len(package_keys),
            "catalogueSurfacesFullyObserved": sorted(
                result["surface"]["id"] for result in assessments
                if result["traceObserved"]
            ),
        },
        "additionalMethodDecisionValue": {
            "unresolvedPolicyControlledSurfaces": unresolved_policy_controlled,
            "traceObservedUnclosedSurfaces": trace_observed_unclosed,
            "optimiserOrMlRlAuthorised": optimiser_authorised,
            "reason": ("A deterministic minimal telemetry surface is eligible; "
                       "no fitted method is needed or authorised." if selected else
                       "The preregistered numeric method gate did not pass."),
        },
        "traceIdentity": {"rows": len(rows), "pathRngPolicyResultExact": True},
        "newSimulatorObservationRows": 0,
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "newLedgerRows": 0,
        "protectedSeedRows": ledger_after["protectedSeedRows"],
        "maximumModelContextTokens": 0,
        "wallTimeSeconds": elapsed,
        "authority": protocol["decisionRules"][
            "successAuthority" if boundary == 1 else (
                "futilityAuthority" if boundary == 2 else "inconclusiveAuthority")],
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": "PASS",
        "decision": decision,
        "decisionBoundary": boundary,
        "selectedSurface": selected,
        "optimiserOrMlRlAuthorised": optimiser_authorised,
        "summarySha256": core.file_sha(SUMMARY),
        "newSimulatorObservationRows": 0,
    }))


if __name__ == "__main__":
    main()
