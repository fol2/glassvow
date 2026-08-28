#!/usr/bin/env python3
"""Zero-row policy/acquisition-capacity screen for deed-unlocked Novaflare."""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path
from typing import Any, Callable

import post_v38_action_grammar_inventory as trace
import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-novaflare-capacity-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-novaflare-capacity-v1.json"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Novaflare capacity mismatch: {label}")


def main_blob(path: str) -> bytes:
    return subprocess.run(
        ["git", "show", f"HEAD:{path}"], cwd=core.SOURCE,
        check=True, capture_output=True,
    ).stdout


def robust_policies(
    rows: dict[tuple[int, int], dict[str, Any]],
    protocol: dict[str, Any],
    predicate: Callable[[dict[str, Any]], bool],
) -> set[int]:
    cohort = protocol["cohort"]
    return {
        policy_index for policy_index in range(cohort["policyCount"])
        if sum(predicate(rows[(policy_index, seed)])
               for seed in cohort["simulationSeeds"])
        >= cohort["minimumRowsPerRobustPolicy"]
    }


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


def candidate_score(policy: dict[str, Any]) -> float:
    return (float(policy["card"]["rarity"]["rare"]) - 2.0
            + float(policy["special"]["doubleBlock"]))


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the Novaflare capacity summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    require("runner SHA", core.file_sha(Path(__file__)) ==
            protocol["immutableInputs"]["runnerSha256"])
    require("source commit", subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=core.SOURCE, check=True,
        text=True, capture_output=True,
    ).stdout.strip() == protocol["immutableInputs"]["sourceCommit"])

    blobs = {
        path: main_blob(path) for path in protocol["immutableInputs"]["sourceSha256"]
    }
    for path, expected_sha in protocol["immutableInputs"]["sourceSha256"].items():
        require(f"{path} SHA", core.sha(blobs[path]) == expected_sha)
    pilot_text = blobs["tools/balance_pilot.gd"].decode()
    rewards_text = blobs["domain/rules/rewards.gd"].decode()
    combat_text = blobs["domain/rules/combat.gd"].decode()
    sim_text = blobs["tools/balance_sim.gd"].decode()
    require("reward score base",
            'var score: float = float(str(rarity.get(str(d.get("rarity", "starter")), 0)))'
            in pilot_text and '- float(str(d.get("cost", 0)))' in pilot_text)
    require("Novaflare special score alias",
            '"doubleBlock", "flawless", "emberNova":\n\t\t\treturn _w("special", "doubleBlock")'
            in pilot_text)
    require("no Novaflare aspect bonus", "novaflare" not in pilot_text)
    require("reward acceptance", "return score >= card_decline_threshold" in pilot_text)
    require("reward acquisition calls acceptance",
            "if Pilot.accepts_card_reward(score):" in sim_text)
    require("event acquisition bypass is explicit",
            '"card":\n\t\t\tfor pending_card: Variant' in sim_text)
    require("shop acquisition path is explicit", "Pilot.choose_shop(stock" in sim_text)
    require("unlock appends matching card tier",
            'if unlock.begins_with("card:"):' in rewards_text
            and 'content.cards[id].get("rarity") == tier' in rewards_text)
    require("Ember reserve payoff", '_ji(fx["n"]) * cb.embers' in combat_text)
    require("Flare interference", "gain_embers(run, cb, -cost)" in combat_text)

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
    require("current-main content SHA", core.sha(blobs["content/full-content.json"]) ==
            protocol["baseline"]["contentSha256"])
    require("baseline plan SHA", baseline_output["planSha256"] ==
            protocol["baseline"]["planSha256"])
    require("trace plan SHA", trace_output["planSha256"] ==
            protocol["traceEvidence"]["planSha256"])

    candidate = protocol["candidate"]
    require("Novaflare definition",
            content["cards"][candidate["cardId"]] == candidate["definition"])
    require("Emberdance competing unlock definition",
            content["cards"]["emberdance"] == candidate["competingUnlockDefinition"])
    require("spendthrift unlock definition",
            content["deeds"]["spendthrift"]["unlocks"] ==
            candidate["spendthriftUnlocks"])
    for tier in content["cardPools"].values():
        require("Novaflare absent without unlock", candidate["cardId"] not in tier)

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

    policies: dict[int, dict[str, Any]] = {}
    for policy_index in range(cohort["policyCount"]):
        snapshots = {
            core.canonical(rows[(policy_index, seed)]["policy"])
            for seed in cohort["simulationSeeds"]
        }
        require(f"policy {policy_index} identity", len(snapshots) == 1)
        policies[policy_index] = rows[(policy_index, cohort["simulationSeeds"][0])]["policy"]

    selector = {
        policy_index for policy_index, policy in policies.items()
        if candidate_score(policy) >= float(policy["cardDecline"])
    }
    selector_inactive = set(policies) - selector

    def reward_opportunity(row: dict[str, Any]) -> bool:
        return bool(row.get("trajectory", {}).get("cardRewards", []))

    def combat_opportunity(row: dict[str, Any]) -> bool:
        return bool(row.get("fights", []))

    def other_acquisition_opportunity(row: dict[str, Any]) -> bool:
        return any(node.get("type") in ("event", "shop")
                   for node in row.get("trajectory", {}).get("nodes", []))

    reward_opportunity_policies = robust_policies(rows, protocol, reward_opportunity)
    combat_opportunity_policies = robust_policies(rows, protocol, combat_opportunity)
    other_acquisition_opportunity_policies = robust_policies(
        rows, protocol, other_acquisition_opportunity)
    potential_active = selector & reward_opportunity_policies & combat_opportunity_policies
    ambiguous = selector - potential_active
    viable = {
        policy_index for policy_index in potential_active
        if any(rows[(policy_index, seed)].get("outcome") == "win"
               and reward_opportunity(rows[(policy_index, seed)])
               and combat_opportunity(rows[(policy_index, seed)])
               for seed in cohort["simulationSeeds"])
    }

    def afterimage_route(row: dict[str, Any]) -> bool:
        return int(row.get("packageEvents", {}).get("afterimageGuardDamage", 0)) > 0

    scoreline = trace.policy_set(rows, protocol, trace.scoreline_route)
    afterimage = trace.policy_set(rows, protocol, afterimage_route)
    require("Scoreline anchor", sorted(scoreline) ==
            protocol["sharedAnchors"]["scoreline"]["policies"])
    require("Afterimage anchor", sorted(afterimage) ==
            protocol["sharedAnchors"]["afterimage"]["policies"])
    separations = {
        "scoreline": separation(potential_active, scoreline),
        "afterimage": separation(potential_active, afterimage),
    }
    baseline_faults = sum(
        row.get("outcome") in ("stall", "error") or bool(row.get("error"))
        for row in rows.values()
    )
    counts = {
        "rewardSelectorPolicies": len(selector),
        "selectorInactivePolicies": len(selector_inactive),
        "robustRewardOpportunityPolicies": len(reward_opportunity_policies),
        "robustCombatOpportunityPolicies": len(combat_opportunity_policies),
        "robustOtherAcquisitionOpportunityPolicies":
            len(other_acquisition_opportunity_policies),
        "potentialActivePolicies": len(potential_active),
        "ambiguousSelectorPolicies": len(ambiguous),
        "viablePotentialActivePolicies": len(viable),
        "baselineFaultRows": baseline_faults,
    }
    gates = protocol["gates"]

    def separated(result: dict[str, Any]) -> bool:
        return (result["candidateOnlyPolicies"] >= gates["minimumCandidateOnlyPolicies"]
                and result["anchorOnlyPolicies"] >= gates["minimumAnchorOnlyPolicies"]
                and result["jaccard"] <= gates["maximumAnchorJaccard"])

    gate_results = {
        "selectorSupport": counts["rewardSelectorPolicies"] >=
            gates["minimumRewardSelectorPolicies"],
        "selectorInactivity": counts["selectorInactivePolicies"] >=
            gates["minimumSelectorInactivePolicies"],
        "rewardOpportunity": counts["robustRewardOpportunityPolicies"] >=
            gates["minimumRobustRewardOpportunityPolicies"],
        "combatOpportunity": counts["robustCombatOpportunityPolicies"] >=
            gates["minimumRobustCombatOpportunityPolicies"],
        "potentialActive": counts["potentialActivePolicies"] >=
            gates["minimumPotentialActivePolicies"],
        "viability": counts["viablePotentialActivePolicies"] >=
            gates["minimumViablePotentialActivePolicies"],
        "scorelineSeparation": separated(separations["scoreline"]),
        "afterimageSeparation": separated(separations["afterimage"]),
        "reliability": baseline_faults <= gates["maximumBaselineFaultRows"],
    }
    elapsed = time.monotonic() - started
    if elapsed > float(protocol["budget"]["maximumWallTimeSeconds"]):
        boundary, decision = 3, "record-novaflare-capacity-inconclusive-at-cap"
    elif all(gate_results.values()):
        boundary, decision = 1, "authorise-novaflare-unlock-telemetry-identity-preflight"
    else:
        boundary, decision = 2, "close-novaflare-reward-selector-route"
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
        "selectorFormula": protocol["selectorFormula"],
        "counts": counts,
        "separation": separations,
        "gateResults": gate_results,
        "policySets": {
            "rewardSelector": sorted(selector),
            "selectorInactive": sorted(selector_inactive),
            "robustRewardOpportunity": sorted(reward_opportunity_policies),
            "robustCombatOpportunity": sorted(combat_opportunity_policies),
            "robustOtherAcquisitionOpportunity":
                sorted(other_acquisition_opportunity_policies),
            "potentialActive": sorted(potential_active),
            "ambiguousSelector": sorted(ambiguous),
            "viablePotentialActive": sorted(viable),
            "scoreline": sorted(scoreline),
            "afterimage": sorted(afterimage),
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
        "summarySha256": core.file_sha(SUMMARY),
        "newSimulatorObservationRows": 0,
    }))


if __name__ == "__main__":
    main()
