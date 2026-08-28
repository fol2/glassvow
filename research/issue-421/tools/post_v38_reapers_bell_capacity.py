#!/usr/bin/env python3
"""Zero-row upper-capacity screen for Reaper's Bell's non-final-death chain."""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path
from typing import Any

import post_v38_action_grammar_inventory as trace
import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-reapers-bell-capacity-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-reapers-bell-capacity-v1.json"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Reaper's Bell capacity mismatch: {label}")


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
        raise RuntimeError("refusing to overwrite the Reaper's Bell capacity summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    require("runner SHA", core.file_sha(Path(__file__)) ==
            protocol["immutableInputs"]["runnerSha256"])
    require("source commit", subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=core.SOURCE, check=True,
        text=True, capture_output=True,
    ).stdout.strip() == protocol["immutableInputs"]["sourceCommit"])
    combat_blob = main_blob("domain/rules/combat.gd")
    require("current-main combat SHA", core.sha(combat_blob) ==
            protocol["immutableInputs"]["combatRulesSha256"])
    pilot_blob = main_blob("tools/balance_pilot.gd")
    require("current-main pilot SHA", core.sha(pilot_blob) ==
            protocol["immutableInputs"]["balancePilotSha256"])
    combat_text = combat_blob.decode()
    require("non-final-death trigger", 'if run.has_relic("reapersBell"):' in combat_text)
    require("energy payoff", "cb.player.energy += 1" in combat_text)
    require("draw payoff", "draw_cards(run, cb, 1)" in combat_text)
    require("other-enemy guard", "for o: EnemyCombatant in cb.enemies:" in combat_text
            and "if o.hp > 0:" in combat_text)
    require("Dusk relic bonus source",
            '"shatterersCrown", "prismCharm", "executionersSeal"' in
            pilot_blob.decode())
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
    content = json.loads(content_path.read_text())
    require("current-main content SHA",
            core.sha(main_blob("content/full-content.json")) ==
            protocol["baseline"]["contentSha256"])
    require("baseline plan SHA", baseline_output["planSha256"] ==
            protocol["baseline"]["planSha256"])
    require("trace plan SHA", trace_output["planSha256"] ==
            protocol["traceEvidence"]["planSha256"])
    candidate = protocol["candidate"]
    relic_id = candidate["relicId"]
    require("relic definition", content["relics"][relic_id] == candidate["definition"])
    require("uncommon pool membership", relic_id in content["relicPools"]["uncommon"])
    require("pool gate", content["poolGate"]["relics"][relic_id] ==
            candidate["poolGate"])

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
    expected = cohort["policyCount"] * len(cohort["simulationSeeds"])
    require("baseline rectangle", len(baseline_rows) == expected)
    require("trace rectangle", len(rows) == expected)
    for key, row in rows.items():
        require("trace-current frozen identity",
                trace.canonical_without(row) == trace.canonical_without(baseline_rows[key]))

    def owns(row: dict[str, Any]) -> bool:
        return relic_id in set(map(str, row.get("relics", [])))

    def chain_capable(row: dict[str, Any]) -> bool:
        return any(len(fight.get("enemies", [])) >= 2 for fight in row.get("fights", []))

    def potential_active(row: dict[str, Any]) -> bool:
        return owns(row) and chain_capable(row)

    def afterimage_route(row: dict[str, Any]) -> bool:
        return int(row.get("packageEvents", {}).get("afterimageGuardDamage", 0)) > 0

    owner_policies = trace.policy_set(rows, protocol, owns)
    chain_capable_policies = trace.policy_set(rows, protocol, chain_capable)
    active_policies = trace.policy_set(rows, protocol, potential_active)
    inactive_policies = {
        policy_index for policy_index in range(cohort["policyCount"])
        if not any(potential_active(rows[(policy_index, seed)])
                   for seed in cohort["simulationSeeds"])
    }
    ambiguous_policies = (set(range(cohort["policyCount"]))
                          - active_policies - inactive_policies)
    acquired_policies = {
        policy_index for policy_index in range(cohort["policyCount"])
        if any(owns(rows[(policy_index, seed)]) for seed in cohort["simulationSeeds"])
    }
    viable_active_policies = {
        policy_index for policy_index in active_policies
        if any(potential_active(rows[(policy_index, seed)])
               and rows[(policy_index, seed)].get("outcome") == "win"
               for seed in cohort["simulationSeeds"])
    }
    scoreline = trace.policy_set(rows, protocol, trace.scoreline_route)
    afterimage = trace.policy_set(rows, protocol, afterimage_route)
    require("Scoreline anchor", sorted(scoreline) ==
            protocol["sharedAnchors"]["scoreline"]["policies"])
    require("Afterimage anchor", sorted(afterimage) ==
            protocol["sharedAnchors"]["afterimage"]["policies"])
    scoreline_separation = separation(active_policies, scoreline)
    afterimage_separation = separation(active_policies, afterimage)
    baseline_faults = sum(
        row.get("outcome") in ("stall", "error") or bool(row.get("error"))
        for row in rows.values()
    )
    all_enemy_counts = [len(fight.get("enemies", [])) for row in rows.values()
                        for fight in row.get("fights", [])]
    counts = {
        "robustOwnerPolicies": len(owner_policies),
        "anyAcquiredPolicies": len(acquired_policies),
        "chainCapablePolicies": len(chain_capable_policies),
        "potentialActivePolicies": len(active_policies),
        "exactInactivePolicies": len(inactive_policies),
        "ambiguousPolicies": len(ambiguous_policies),
        "viablePotentialActivePolicies": len(viable_active_policies),
        "ownerRows": sum(owns(row) for row in rows.values()),
        "potentialActiveRows": sum(potential_active(row) for row in rows.values()),
        "maximumEnemiesInFight": max(all_enemy_counts, default=0),
        "baselineFaultRows": baseline_faults,
    }
    gates = protocol["gates"]

    def separated(result: dict[str, Any]) -> bool:
        return (result["candidateOnlyPolicies"] >= gates["minimumCandidateOnlyPolicies"]
                and result["anchorOnlyPolicies"] >= gates["minimumAnchorOnlyPolicies"]
                and result["jaccard"] <= gates["maximumAnchorJaccard"])

    gate_results = {
        "ownerReachability": counts["robustOwnerPolicies"] >=
        gates["minimumRobustOwnerPolicies"]
        and counts["anyAcquiredPolicies"] >= gates["minimumAnyAcquiredPolicies"],
        "chainCapacity": counts["chainCapablePolicies"] >=
        gates["minimumChainCapablePolicies"],
        "potentialActive": counts["potentialActivePolicies"] >=
        gates["minimumPotentialActivePolicies"],
        "inactive": counts["exactInactivePolicies"] >= gates["minimumInactivePolicies"],
        "viable": counts["viablePotentialActivePolicies"] >=
        gates["minimumViablePotentialActivePolicies"],
        "scorelineSeparation": separated(scoreline_separation),
        "afterimageSeparation": separated(afterimage_separation),
        "reliability": baseline_faults <= gates["maximumBaselineFaultRows"],
    }
    elapsed = time.monotonic() - started
    if elapsed > float(protocol["budget"]["maximumWallTimeSeconds"]):
        boundary, decision = 3, "record-reapers-bell-capacity-inconclusive-at-cap"
    elif all(gate_results.values()):
        boundary, decision = 1, "authorise-reapers-bell-exact-telemetry-preflight"
    else:
        boundary, decision = 2, "close-reapers-bell-death-chain-family"
    ledger_after = identity.ledger_identity()
    require("zero-row ledger identity", ledger_after == ledger_before)
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "decisionBoundary": boundary,
        "decision": decision,
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "candidate": candidate,
        "counts": counts,
        "separation": {
            "scoreline": scoreline_separation,
            "afterimage": afterimage_separation,
        },
        "gateResults": gate_results,
        "policySets": {
            "robustOwner": sorted(owner_policies),
            "chainCapable": sorted(chain_capable_policies),
            "potentialActive": sorted(active_policies),
            "inactive": sorted(inactive_policies),
            "ambiguous": sorted(ambiguous_policies),
            "viablePotentialActive": sorted(viable_active_policies),
            "scoreline": sorted(scoreline),
            "afterimage": sorted(afterimage),
        },
        "traceIdentity": {"rows": len(rows), "pathRngResultExact": True},
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
        "summarySha256": core.file_sha(SUMMARY),
        "newSimulatorObservationRows": 0,
    }))


if __name__ == "__main__":
    main()
