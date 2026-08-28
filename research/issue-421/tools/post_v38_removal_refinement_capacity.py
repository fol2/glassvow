#!/usr/bin/env python3
"""Zero-row capacity screen for a Duskblade card-removal trigger."""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path
from typing import Any

import post_v38_action_grammar_inventory as trace
import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-removal-refinement-capacity-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-removal-refinement-capacity-v1.json"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Removal-refinement capacity mismatch: {label}")


def main_blob(path: str) -> bytes:
    return subprocess.run(
        ["git", "show", f"HEAD:{path}"], cwd=core.SOURCE,
        check=True, capture_output=True,
    ).stdout


def separation(candidate: set[int], anchor: set[int]) -> dict[str, Any]:
    candidate_only = candidate - anchor
    anchor_only = anchor - candidate
    cross = candidate & anchor
    union = candidate | anchor
    return {
        "candidateOnlyPolicies": len(candidate_only),
        "anchorOnlyPolicies": len(anchor_only),
        "crossActivePolicies": len(cross),
        "jaccard": len(cross) / len(union) if union else 1.0,
        "candidateOnly": sorted(candidate_only),
        "anchorOnly": sorted(anchor_only),
    }


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the removal-refinement summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    require("runner SHA", core.file_sha(Path(__file__)) ==
            protocol["immutableInputs"]["runnerSha256"])
    require("source commit", subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=core.SOURCE, check=True,
        text=True, capture_output=True,
    ).stdout.strip() == protocol["immutableInputs"]["sourceCommit"])
    for source_path, expected_sha in protocol["immutableInputs"]["sourceSha256"].items():
        require(f"{source_path} SHA", core.sha(main_blob(source_path)) == expected_sha)

    source_contract = json.loads(
        main_blob("docs/balance/490-f0-response-contract-v1.json")
    )
    require("existing removalEconomy contract",
            source_contract["packageDiagnostics"]["packages"]["removalEconomy"] ==
            protocol["sourcePackage"])
    policy_text = main_blob("tools/balance_policy.gd").decode()
    pilot_text = main_blob("tools/balance_pilot.gd").decode()
    simulator_text = main_blob("tools/balance_sim.gd").decode()
    for fragment in protocol["sourceAssertions"]["balancePolicy"]:
        require(f"policy source {fragment}", fragment in policy_text)
    for fragment in protocol["sourceAssertions"]["balancePilot"]:
        require(f"pilot source {fragment}", fragment in pilot_text)
    for route in protocol["routes"]:
        for event in (route["exposureEvent"], route["useEvent"]):
            require(f"simulator event {event}", f'"{event}"' in simulator_text)
    for name, spec in protocol["priorEvidence"].items():
        path = core.ROOT / spec["path"]
        require(f"{name} SHA", core.file_sha(path) == spec["sha256"])
        require(f"{name} decision", json.loads(path.read_text())["decision"] ==
                spec["decision"])

    ledger_before = identity.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
    baseline_path = core.CACHE / f"{protocol['baseline']['outputSha256']}.json"
    trace_path = core.CACHE / f"{protocol['traceEvidence']['outputSha256']}.json"
    content_path = core.CACHE / f"{protocol['baseline']['contentSha256']}.json"
    require("baseline output SHA", core.file_sha(baseline_path) ==
            protocol["baseline"]["outputSha256"])
    require("trace output SHA", core.file_sha(trace_path) ==
            protocol["traceEvidence"]["outputSha256"])
    require("content SHA", core.file_sha(content_path) ==
            protocol["baseline"]["contentSha256"])
    baseline_output = json.loads(baseline_path.read_text())
    trace_output = json.loads(trace_path.read_text())
    require("current-main content SHA",
            core.sha(main_blob("content/full-content.json")) ==
            protocol["baseline"]["contentSha256"])
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
    require("cached-row ceiling",
            len(baseline_rows) + len(rows) <=
            protocol["budget"]["maximumCachedObservationRowsRead"])
    for key, row in rows.items():
        require("trace-current frozen identity",
                trace.canonical_without(row) == trace.canonical_without(baseline_rows[key]))

    def event_count(row: dict[str, Any], event: str) -> int:
        value = row.get("packageEvents", {}).get(event, 0)
        require(f"nonnegative integer event {event}",
                isinstance(value, int) and value >= 0)
        return value

    def exposed(row: dict[str, Any]) -> bool:
        return any(event_count(row, route["exposureEvent"]) > 0
                   for route in protocol["routes"])

    def active(row: dict[str, Any]) -> bool:
        return any(event_count(row, route["useEvent"]) > 0
                   for route in protocol["routes"])

    for row in rows.values():
        for route in protocol["routes"]:
            require(f"{route['id']} use implies exposure",
                    event_count(row, route["useEvent"]) == 0 or
                    event_count(row, route["exposureEvent"]) > 0)

    opportunity_policies = trace.policy_set(rows, protocol, exposed)
    active_policies = trace.policy_set(rows, protocol, active)
    inactive_policies = {
        policy_index for policy_index in range(cohort["policyCount"])
        if not any(active(rows[(policy_index, seed)])
                   for seed in cohort["simulationSeeds"])
    }
    ambiguous_policies = (set(range(cohort["policyCount"]))
                          - active_policies - inactive_policies)
    viable_active_policies = {
        policy_index for policy_index in active_policies
        if any(active(rows[(policy_index, seed)]) and
               rows[(policy_index, seed)].get("outcome") == "win"
               for seed in cohort["simulationSeeds"])
    }
    route_diagnostics = []
    for route in protocol["routes"]:
        route_exposed = lambda row, event=route["exposureEvent"]: event_count(row, event) > 0
        route_active = lambda row, event=route["useEvent"]: event_count(row, event) > 0
        robust_exposure = trace.policy_set(rows, protocol, route_exposed)
        robust_active = trace.policy_set(rows, protocol, route_active)
        route_diagnostics.append({
            "id": route["id"],
            "exposureEvent": route["exposureEvent"],
            "useEvent": route["useEvent"],
            "robustExposurePolicies": len(robust_exposure),
            "robustActivePolicies": len(robust_active),
            "exposureRows": sum(route_exposed(row) for row in rows.values()),
            "activeRows": sum(route_active(row) for row in rows.values()),
            "robustExposurePolicySet": sorted(robust_exposure),
            "robustActivePolicySet": sorted(robust_active),
        })
    observed_routes = [route["id"] for route in route_diagnostics
                       if route["robustActivePolicies"] >=
                       protocol["gates"]["minimumRobustPoliciesPerObservedRoute"]]

    def afterimage_route(row: dict[str, Any]) -> bool:
        return int(row.get("packageEvents", {}).get("afterimageGuardDamage", 0)) > 0

    scoreline = trace.policy_set(rows, protocol, trace.scoreline_route)
    afterimage = trace.policy_set(rows, protocol, afterimage_route)
    require("Scoreline anchor", sorted(scoreline) ==
            protocol["sharedAnchors"]["scoreline"]["policies"])
    require("Afterimage anchor", sorted(afterimage) ==
            protocol["sharedAnchors"]["afterimage"]["policies"])
    scoreline_sep = separation(active_policies, scoreline)
    afterimage_sep = separation(active_policies, afterimage)
    baseline_faults = sum(
        row.get("outcome") in ("stall", "error") or bool(row.get("error"))
        for row in rows.values()
    )
    counts = {
        "robustOpportunityPolicies": len(opportunity_policies),
        "robustActivePolicies": len(active_policies),
        "exactInactivePolicies": len(inactive_policies),
        "ambiguousPolicies": len(ambiguous_policies),
        "viableRobustActivePolicies": len(viable_active_policies),
        "opportunityRows": sum(exposed(row) for row in rows.values()),
        "activeRows": sum(active(row) for row in rows.values()),
        "observedTriggerRoutes": len(observed_routes),
        "baselineFaultRows": baseline_faults,
    }
    gates = protocol["gates"]

    def separated(result: dict[str, Any]) -> bool:
        return (result["candidateOnlyPolicies"] >= gates["minimumCandidateOnlyPolicies"]
                and result["anchorOnlyPolicies"] >= gates["minimumAnchorOnlyPolicies"]
                and result["jaccard"] <= gates["maximumAnchorJaccard"])

    gate_results = {
        "opportunityCapacity": counts["robustOpportunityPolicies"] >=
        gates["minimumRobustOpportunityPolicies"],
        "activeCapacity": counts["robustActivePolicies"] >=
        gates["minimumRobustActivePolicies"],
        "inactiveCapacity": counts["exactInactivePolicies"] >=
        gates["minimumExactInactivePolicies"],
        "viability": counts["viableRobustActivePolicies"] >=
        gates["minimumViableRobustActivePolicies"],
        "routeBreadth": counts["observedTriggerRoutes"] >=
        gates["minimumObservedTriggerRoutes"],
        "scorelineSeparation": separated(scoreline_sep),
        "afterimageSeparation": separated(afterimage_sep),
        "reliability": baseline_faults <= gates["maximumBaselineFaultRows"],
    }
    elapsed = time.monotonic() - started
    if elapsed > float(protocol["budget"]["maximumWallTimeSeconds"]):
        boundary = 3
        decision = "record-removal-refinement-capacity-inconclusive-at-cap"
        selected = None
    elif all(gate_results.values()):
        boundary = 1
        decision = "freeze-removal-refinement-trigger-for-identity-preflight"
        selected = protocol["candidate"]["id"]
    else:
        boundary = 2
        decision = "close-removal-refinement-trigger-family"
        selected = None
    ledger_after = identity.ledger_identity()
    require("zero-row ledger identity", ledger_after == ledger_before)
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "decisionBoundary": boundary,
        "decision": decision,
        "selectedCandidate": selected,
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "counts": counts,
        "gateResults": gate_results,
        "passes": all(gate_results.values()),
        "routeDiagnostics": route_diagnostics,
        "observedTriggerRoutes": observed_routes,
        "separation": {"scoreline": scoreline_sep, "afterimage": afterimage_sep},
        "policySets": {
            "robustOpportunity": sorted(opportunity_policies),
            "robustActive": sorted(active_policies),
            "exactInactive": sorted(inactive_policies),
            "ambiguous": sorted(ambiguous_policies),
            "viableRobustActive": sorted(viable_active_policies),
        },
        "sharedAnchors": {"scoreline": sorted(scoreline), "afterimage": sorted(afterimage)},
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
        "selectedCandidate": selected,
        "summarySha256": core.file_sha(SUMMARY),
        "newSimulatorObservationRows": 0,
    }))


if __name__ == "__main__":
    main()
