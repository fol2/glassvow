#!/usr/bin/env python3
"""Zero-row upper-capacity screen for the existing Executioner's Seal cadence."""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path
from typing import Any

import post_v38_action_grammar_inventory as trace
import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-executioners-seal-capacity-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-executioners-seal-capacity-v1.json"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Executioner's Seal capacity mismatch: {label}")


def main_blob(path: str) -> bytes:
    return subprocess.run(
        ["git", "show", f"HEAD:{path}"], cwd=core.SOURCE,
        check=True, capture_output=True,
    ).stdout


def attack_counts(row: dict[str, Any], cards: dict[str, Any]) -> dict[int, int]:
    return {
        fight: sum(cards.get(play["id"], {}).get("type") == "attack" for play in plays)
        for fight, plays in trace.ordered_plays(row).items()
    }


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the Executioner's Seal capacity summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    require("runner SHA", core.file_sha(Path(__file__)) ==
            protocol["immutableInputs"]["runnerSha256"])
    require("source commit", subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=core.SOURCE, check=True,
        text=True, capture_output=True,
    ).stdout.strip() == protocol["immutableInputs"]["sourceCommit"])
    combat_blob = main_blob("domain/rules/combat.gd")
    pilot_blob = main_blob("tools/balance_pilot.gd")
    require("current-main combat SHA", core.sha(combat_blob) ==
            protocol["immutableInputs"]["combatRulesSha256"])
    require("current-main pilot SHA", core.sha(pilot_blob) ==
            protocol["immutableInputs"]["balancePilotSha256"])
    combat_text = combat_blob.decode()
    pilot_text = pilot_blob.decode()
    require("tenth-Attack source trigger",
            'run.has_relic("executionersSeal") and cb.counters_attacks % 10 == 0' in
            combat_text)
    require("source doubles only seal multiplier", "seal_mult = 2" in combat_text)
    require("Dusk score source",
            '"shatterersCrown", "prismCharm", "executionersSeal"' in pilot_text)

    prior_spec = protocol["priorEvidence"]["duskSourceScreen"]
    prior_path = core.ROOT / prior_spec["path"]
    require("prior source screen SHA", core.file_sha(prior_path) == prior_spec["sha256"])
    prior = json.loads(prior_path.read_text())
    require("prior source screen decision", prior["decision"] == prior_spec["decision"])
    require("Dusk bonus relic freeze", prior["candidate"]["duskBonusRelics"] ==
            protocol["sourceFilter"]["duskBonusRelics"])

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
    require("baseline plan SHA", baseline_output["planSha256"] ==
            protocol["baseline"]["planSha256"])
    require("trace plan SHA", trace_output["planSha256"] ==
            protocol["traceEvidence"]["planSha256"])
    candidate = protocol["candidate"]
    require("relic definition", content["relics"][candidate["relicId"]] ==
            candidate["definition"])
    require("uncommon pool membership", candidate["relicId"] in
            content["relicPools"]["uncommon"])
    remaining = [relic for relic in protocol["sourceFilter"]["duskBonusRelics"]
                 if relic not in protocol["sourceFilter"]["closedRelics"]]
    require("unique remaining Dusk relic", remaining == [candidate["relicId"]])

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

    cards = content["cards"]

    def owns(row: dict[str, Any]) -> bool:
        return candidate["relicId"] in set(map(str, row.get("relics", [])))

    def attack_capable(row: dict[str, Any]) -> bool:
        return any(count >= candidate["attackCadence"]
                   for count in attack_counts(row, cards).values())

    def potential_active(row: dict[str, Any]) -> bool:
        return owns(row) and attack_capable(row)

    owner_policies = trace.policy_set(rows, protocol, owns)
    attack_capable_policies = trace.policy_set(rows, protocol, attack_capable)
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
    require("Scoreline anchor", len(scoreline) == protocol["scorelineAnchor"]["activePolicies"])
    candidate_only = active_policies - scoreline
    scoreline_only = scoreline - active_policies
    cross = active_policies & scoreline
    union = active_policies | scoreline
    all_attack_counts = [count for row in rows.values()
                         for count in attack_counts(row, cards).values()]
    baseline_faults = sum(
        row.get("outcome") in ("stall", "error") or bool(row.get("error"))
        for row in rows.values())
    counts = {
        "robustOwnerPolicies": len(owner_policies),
        "anyAcquiredPolicies": len(acquired_policies),
        "attackCapablePolicies": len(attack_capable_policies),
        "potentialActivePolicies": len(active_policies),
        "exactInactivePolicies": len(inactive_policies),
        "ambiguousPolicies": len(ambiguous_policies),
        "viablePotentialActivePolicies": len(viable_active_policies),
        "maximumAttacksInFight": max(all_attack_counts, default=0),
        "baselineFaultRows": baseline_faults,
    }
    separation = {
        "candidateOnlyPolicies": len(candidate_only),
        "scorelineOnlyPolicies": len(scoreline_only),
        "crossActivePolicies": len(cross),
        "jaccard": len(cross) / len(union) if union else 1.0,
    }
    gates = protocol["gates"]
    gate_results = {
        "ownerReachability": counts["robustOwnerPolicies"] >=
        gates["minimumRobustOwnerPolicies"]
        and counts["anyAcquiredPolicies"] >= gates["minimumAnyAcquiredPolicies"],
        "attackCapacity": counts["attackCapablePolicies"] >=
        gates["minimumAttackCapablePolicies"],
        "potentialActive": counts["potentialActivePolicies"] >=
        gates["minimumPotentialActivePolicies"],
        "inactive": counts["exactInactivePolicies"] >= gates["minimumInactivePolicies"],
        "viable": counts["viablePotentialActivePolicies"] >=
        gates["minimumViablePotentialActivePolicies"],
        "scorelineSeparation": separation["candidateOnlyPolicies"] >=
        gates["minimumCandidateOnlyPolicies"]
        and separation["scorelineOnlyPolicies"] >= gates["minimumScorelineOnlyPolicies"]
        and separation["jaccard"] <= gates["maximumScorelineJaccard"],
        "reliability": baseline_faults <= gates["maximumBaselineFaultRows"],
    }
    elapsed = time.monotonic() - started
    if elapsed > float(protocol["budget"]["maximumWallTimeSeconds"]):
        boundary, decision = 3, "record-executioners-seal-capacity-inconclusive-at-cap"
    elif all(gate_results.values()):
        boundary, decision = 1, "authorise-executioners-seal-exact-telemetry-preflight"
    else:
        boundary, decision = 2, "close-executioners-seal-cadence-family"
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
        "sourceFilter": protocol["sourceFilter"],
        "counts": counts,
        "separation": separation,
        "gateResults": gate_results,
        "policySets": {
            "robustOwner": sorted(owner_policies),
            "attackCapable": sorted(attack_capable_policies),
            "potentialActive": sorted(active_policies),
            "inactive": sorted(inactive_policies),
            "ambiguous": sorted(ambiguous_policies),
            "candidateOnly": sorted(candidate_only),
            "scorelineOnly": sorted(scoreline_only),
            "viablePotentialActive": sorted(viable_active_policies),
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
