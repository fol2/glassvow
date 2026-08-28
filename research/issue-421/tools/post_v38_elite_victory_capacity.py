#!/usr/bin/env python3
"""Zero-row capacity screen for a Duskblade elite-victory trigger."""

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


PROTOCOL = core.ROOT / "protocols/post-v38-elite-victory-capacity-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-elite-victory-capacity-v1.json"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Elite-victory capacity mismatch: {label}")


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the elite-victory summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    require("runner SHA", core.file_sha(Path(__file__)) ==
            protocol["immutableInputs"]["runnerSha256"])
    require("capacity helper SHA", core.file_sha(Path(capacity.__file__)) ==
            protocol["immutableInputs"]["capacityHelperSha256"])
    require("source commit", subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=core.SOURCE, check=True,
        text=True, capture_output=True,
    ).stdout.strip() == protocol["immutableInputs"]["sourceCommit"])
    for source_path, expected_sha in protocol["immutableInputs"]["sourceSha256"].items():
        require(f"{source_path} SHA",
                core.sha(capacity.main_blob(source_path)) == expected_sha)
    for source_path, fragments in protocol["sourceAssertions"].items():
        source_text = capacity.main_blob(source_path).decode()
        for fragment in fragments:
            require(f"{source_path} source {fragment}", fragment in source_text)
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
            core.sha(capacity.main_blob("content/full-content.json")) ==
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
    require("cached-row ceiling", len(baseline_rows) + len(rows) <=
            protocol["budget"]["maximumCachedObservationRowsRead"])
    for key, row in rows.items():
        require("trace-current frozen identity",
                trace.canonical_without(row) == trace.canonical_without(baseline_rows[key]))
        for node in row["trajectory"]["nodes"]:
            require("complete node telemetry",
                    set(node) == {"act", "index", "id", "row", "type", "combatKind"}
                    and int(node["act"]) >= 0 and int(node["index"]) >= 0
                    and int(node["row"]) >= 0)

    def entered_elite(row: dict[str, Any]) -> bool:
        return any(node["type"] == "elite" and node["combatKind"] == "elite"
                   for node in row["trajectory"]["nodes"])

    def won_elite(row: dict[str, Any]) -> bool:
        return any(fight.get("kind") == "elite" and fight.get("result") == "win"
                   for fight in row["fights"])

    for row in rows.values():
        require("elite victory implies entered elite", not won_elite(row) or entered_elite(row))
    opportunity_policies = trace.policy_set(rows, protocol, entered_elite)
    active_policies = trace.policy_set(rows, protocol, won_elite)
    inactive_policies = {
        policy_index for policy_index in range(cohort["policyCount"])
        if not any(won_elite(rows[(policy_index, seed)])
                   for seed in cohort["simulationSeeds"])
    }
    ambiguous_policies = (set(range(cohort["policyCount"]))
                          - active_policies - inactive_policies)
    viable_active_policies = {
        policy_index for policy_index in active_policies
        if any(won_elite(rows[(policy_index, seed)]) and
               rows[(policy_index, seed)].get("outcome") == "win"
               for seed in cohort["simulationSeeds"])
    }
    observed_acts = sorted({
        int(fight["act"]) for row in rows.values() for fight in row["fights"]
        if fight.get("kind") == "elite" and fight.get("result") == "win"
    })

    def afterimage_route(row: dict[str, Any]) -> bool:
        return int(row.get("packageEvents", {}).get("afterimageGuardDamage", 0)) > 0

    scoreline = trace.policy_set(rows, protocol, trace.scoreline_route)
    afterimage = trace.policy_set(rows, protocol, afterimage_route)
    require("Scoreline anchor", sorted(scoreline) ==
            protocol["sharedAnchors"]["scoreline"]["policies"])
    require("Afterimage anchor", sorted(afterimage) ==
            protocol["sharedAnchors"]["afterimage"]["policies"])
    scoreline_sep = capacity.separation(active_policies, scoreline)
    afterimage_sep = capacity.separation(active_policies, afterimage)
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
        "opportunityRows": sum(entered_elite(row) for row in rows.values()),
        "activeRows": sum(won_elite(row) for row in rows.values()),
        "observedEliteActs": observed_acts,
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
        "scorelineSeparation": separated(scoreline_sep),
        "afterimageSeparation": separated(afterimage_sep),
        "reliability": baseline_faults <= gates["maximumBaselineFaultRows"],
    }
    elapsed = time.monotonic() - started
    if elapsed > float(protocol["budget"]["maximumWallTimeSeconds"]):
        boundary = 3
        decision = "record-elite-victory-capacity-inconclusive-at-cap"
        selected = None
    elif all(gate_results.values()):
        boundary = 1
        decision = "freeze-elite-victory-trigger-for-identity-preflight"
        selected = protocol["candidate"]["id"]
    else:
        boundary = 2
        decision = "close-elite-victory-trigger-family"
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
