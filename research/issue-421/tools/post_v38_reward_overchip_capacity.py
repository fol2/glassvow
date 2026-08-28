#!/usr/bin/env python3
"""Zero-row upper-capacity screen for reward-Attack Facet overchip."""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path
from typing import Any

import post_v38_action_grammar_inventory as trace
import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-reward-overchip-capacity-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-reward-overchip-capacity-v1.json"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Reward overchip capacity mismatch: {label}")


def main_blob(path: str) -> bytes:
    return subprocess.run(
        ["git", "show", f"HEAD:{path}"], cwd=core.SOURCE,
        check=True, capture_output=True,
    ).stdout


def source_cards(content: dict[str, Any]) -> list[str]:
    pool = trace.reward_pool(content)
    return sorted(
        card_id for card_id, card in content["cards"].items()
        if card_id in pool and card.get("type") == "attack" and int(card.get("chip", 0)) > 0
    )


def qualifying_cards(row: dict[str, Any], card_ids: set[str]) -> set[str]:
    found = set()
    fights = row.get("fights", [])
    for fight_index, plays in trace.ordered_plays(row).items():
        if fight_index >= len(fights) or int(fights[fight_index].get("shatters", 0)) <= 0:
            continue
        found.update(str(play["id"]) for play in plays if play["id"] in card_ids)
    return found


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the reward overchip capacity summary")
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
    combat_text = combat_blob.decode()
    require("Attack chip source",
            'per = 1 + _ji(d.get("chip", 0)) + _sget(p.statuses, "beacon")' in
            combat_text)
    require("Facet accumulation source", "e.chips += n" in combat_text)
    require("overflow threshold source",
            "while e.chips >= e.facet_max and e.hp > 0:" in combat_text)
    require("overflow carry source", "e.chips -= e.facet_max" in combat_text)
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
    require("source-card freeze", source_cards(content) == candidate["cards"])
    for card_id, definition in candidate["definitions"].items():
        require(f"{card_id} definition", content["cards"][card_id] == definition)
    require("starter control definition", content["cards"]["chisel"] ==
            protocol["starterControl"]["definition"])
    require("starter control is outside reward pool", "chisel" not in trace.reward_pool(content))

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

    card_ids = set(candidate["cards"])

    def potential_active(row: dict[str, Any]) -> bool:
        return bool(qualifying_cards(row, card_ids))

    def starter_active(row: dict[str, Any]) -> bool:
        return bool(qualifying_cards(row, {"chisel"}))

    active_policies = trace.policy_set(rows, protocol, potential_active)
    inactive_policies = {
        policy_index for policy_index in range(cohort["policyCount"])
        if not any(potential_active(rows[(policy_index, seed)])
                   for seed in cohort["simulationSeeds"])
    }
    ambiguous_policies = (set(range(cohort["policyCount"]))
                          - active_policies - inactive_policies)
    offered_policies = {
        policy_index for policy_index in range(cohort["policyCount"])
        if any(any(int(rows[(policy_index, seed)]["packageEvents"]
                           .get(f"{card_id}Offered", 0)) > 0 for card_id in card_ids)
               for seed in cohort["simulationSeeds"])
    }
    acquired_policies = {
        policy_index for policy_index in range(cohort["policyCount"])
        if any(bool(card_ids & set(map(str, rows[(policy_index, seed)]
                                       .get("deckIds", []))))
               for seed in cohort["simulationSeeds"])
    }
    viable_active_policies = {
        policy_index for policy_index in active_policies
        if any(potential_active(rows[(policy_index, seed)])
               and rows[(policy_index, seed)].get("outcome") == "win"
               for seed in cohort["simulationSeeds"])
    }
    starter_policies = trace.policy_set(rows, protocol, starter_active)
    activated_cards = sorted({card_id for row in rows.values()
                              for card_id in qualifying_cards(row, card_ids)})
    scoreline = trace.policy_set(rows, protocol, trace.scoreline_route)
    require("Scoreline anchor", len(scoreline) == protocol["scorelineAnchor"]["activePolicies"])
    candidate_only = active_policies - scoreline
    scoreline_only = scoreline - active_policies
    cross = active_policies & scoreline
    union = active_policies | scoreline
    baseline_faults = sum(
        row.get("outcome") in ("stall", "error") or bool(row.get("error"))
        for row in rows.values())
    counts = {
        "potentialActivePolicies": len(active_policies),
        "exactInactivePolicies": len(inactive_policies),
        "ambiguousPolicies": len(ambiguous_policies),
        "offeredPolicies": len(offered_policies),
        "acquiredPolicies": len(acquired_policies),
        "viablePotentialActivePolicies": len(viable_active_policies),
        "distinctQualifyingCards": len(activated_cards),
        "starterControlPolicies": len(starter_policies),
        "baselineFaultRows": baseline_faults,
    }
    separation = {
        "candidateOnlyPolicies": len(candidate_only),
        "scorelineOnlyPolicies": len(scoreline_only),
        "crossActivePolicies": len(cross),
        "jaccard": len(cross) / len(union) if union else 1.0,
        "starterScorelineJaccard": (len(starter_policies & scoreline) /
                                     len(starter_policies | scoreline)
                                     if starter_policies | scoreline else 1.0),
    }
    gates = protocol["gates"]
    gate_results = {
        "potentialActive": counts["potentialActivePolicies"] >=
        gates["minimumPotentialActivePolicies"],
        "inactive": counts["exactInactivePolicies"] >= gates["minimumInactivePolicies"],
        "reachable": counts["offeredPolicies"] >= gates["minimumOfferedPolicies"]
        and counts["acquiredPolicies"] >= gates["minimumAcquiredPolicies"],
        "viable": counts["viablePotentialActivePolicies"] >=
        gates["minimumViablePotentialActivePolicies"],
        "sourceBreadth": counts["distinctQualifyingCards"] >=
        gates["minimumDistinctQualifyingCards"],
        "scorelineSeparation": separation["candidateOnlyPolicies"] >=
        gates["minimumCandidateOnlyPolicies"]
        and separation["scorelineOnlyPolicies"] >= gates["minimumScorelineOnlyPolicies"]
        and separation["jaccard"] <= gates["maximumScorelineJaccard"],
        "reliability": baseline_faults <= gates["maximumBaselineFaultRows"],
    }
    elapsed = time.monotonic() - started
    if elapsed > float(protocol["budget"]["maximumWallTimeSeconds"]):
        boundary, decision = 3, "record-reward-overchip-capacity-inconclusive-at-cap"
    elif all(gate_results.values()):
        boundary, decision = 1, "authorise-reward-overchip-exact-telemetry-preflight"
    else:
        boundary, decision = 2, "close-reward-overchip-mediator-family"
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
        "separation": separation,
        "gateResults": gate_results,
        "qualifyingCards": activated_cards,
        "policySets": {
            "potentialActive": sorted(active_policies),
            "inactive": sorted(inactive_policies),
            "ambiguous": sorted(ambiguous_policies),
            "candidateOnly": sorted(candidate_only),
            "scorelineOnly": sorted(scoreline_only),
            "viablePotentialActive": sorted(viable_active_policies),
            "starterControl": sorted(starter_policies),
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
