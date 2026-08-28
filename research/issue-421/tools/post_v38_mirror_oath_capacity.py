#!/usr/bin/env python3
"""Zero-row capacity screen for the minimal Mirror Oath commitment primitive."""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path
from typing import Any

import post_v38_action_grammar_inventory as trace
import post_v38_knob_identity as identity
import post_v38_novaflare_capacity as capacity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-mirror-oath-capacity-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-mirror-oath-capacity-v1.json"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Mirror Oath capacity mismatch: {label}")


def main_blob(path: str) -> bytes:
    return subprocess.run(
        ["git", "show", f"HEAD:{path}"], cwd=core.SOURCE,
        check=True, capture_output=True,
    ).stdout


def carrier_score(policy: dict[str, Any]) -> float:
    return (float(policy["card"]["rarity"]["uncommon"]) - 1.0
            + float(policy["card"]["power"]))


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the Mirror Oath capacity summary")
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
    content = json.loads(blobs["content/full-content.json"])
    pilot_text = blobs["tools/balance_pilot.gd"].decode()
    combat_text = blobs["domain/rules/combat.gd"].decode()
    require("candidate is new", protocol["candidate"]["cardId"] not in content["cards"])
    require("candidate absent from pools", all(
        protocol["candidate"]["cardId"] not in pool
        for pool in content["cardPools"].values()))
    modal_power_ids = sorted(
        card_id for card_id, card in content["cards"].items()
        if card.get("type") == "power" and card.get("rarity") == "uncommon"
        and int(card.get("cost", -1)) == 1
    )
    require("modal Power carrier source", len(modal_power_ids) ==
            protocol["candidate"]["sourceShape"]["matchingCurrentCards"]
            and modal_power_ids == sorted(
                protocol["candidate"]["sourceShape"]["matchingIds"]))
    require("card Power score", 'score += _w("card", "power")' in pilot_text)
    require("normal reward threshold", "return score >= card_decline_threshold" in pilot_text)
    require("no candidate-specific policy key", "mirrorOath" not in pilot_text)
    require("current source has no Afterimage", "afterimage" not in combat_text)
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
    expected = cohort["policyCount"] * len(cohort["simulationSeeds"])
    require("baseline rectangle", len(baseline_rows) == expected)
    require("trace rectangle", len(rows) == expected)
    for key, row in rows.items():
        require("trace-current frozen identity",
                trace.canonical_without(row) == trace.canonical_without(baseline_rows[key]))
    policies: dict[int, dict[str, Any]] = {}
    for policy_index in range(cohort["policyCount"]):
        snapshots = {core.canonical(rows[(policy_index, seed)]["policy"])
                     for seed in cohort["simulationSeeds"]}
        require(f"policy {policy_index} identity", len(snapshots) == 1)
        policies[policy_index] = rows[(policy_index, cohort["simulationSeeds"][0])]["policy"]

    selector = {
        policy_index for policy_index, policy in policies.items()
        if carrier_score(policy) >= float(policy["cardDecline"])
    }
    nonselector = set(policies) - selector

    def reward_opportunity(row: dict[str, Any]) -> bool:
        return bool(row.get("trajectory", {}).get("cardRewards", []))

    def afterimage_row(row: dict[str, Any]) -> bool:
        return int(row.get("packageEvents", {}).get("afterimageGuardDamage", 0)) > 0

    def scoreline_row(row: dict[str, Any]) -> bool:
        return trace.scoreline_route(row)

    reward_opportunity_policies = capacity.robust_policies(rows, protocol, reward_opportunity)
    afterimage_substrate = capacity.robust_policies(rows, protocol, afterimage_row)
    scoreline = capacity.robust_policies(rows, protocol, scoreline_row)
    afterimage_zero = {
        policy_index for policy_index in range(cohort["policyCount"])
        if not any(afterimage_row(rows[(policy_index, seed)])
                   for seed in cohort["simulationSeeds"])
    }
    candidate_active = selector & reward_opportunity_policies & afterimage_substrate
    exact_inactive = nonselector | afterimage_zero
    ambiguous = set(policies) - candidate_active - exact_inactive
    narrowed_out = afterimage_substrate - candidate_active
    viable = {
        policy_index for policy_index in candidate_active
        if any(afterimage_row(rows[(policy_index, seed)])
               and rows[(policy_index, seed)].get("outcome") == "win"
               for seed in cohort["simulationSeeds"])
    }
    require("Scoreline anchor", sorted(scoreline) ==
            protocol["sharedAnchors"]["scoreline"]["policies"])
    require("Afterimage substrate anchor", sorted(afterimage_substrate) ==
            protocol["sharedAnchors"]["afterimageSubstrate"]["policies"])
    scoreline_separation = capacity.separation(candidate_active, scoreline)
    baseline_faults = sum(
        row.get("outcome") in ("stall", "error") or bool(row.get("error"))
        for row in rows.values()
    )
    counts = {
        "carrierSelectorPolicies": len(selector),
        "carrierNonselectorPolicies": len(nonselector),
        "robustRewardOpportunityPolicies": len(reward_opportunity_policies),
        "afterimageSubstratePolicies": len(afterimage_substrate),
        "afterimageZeroPolicies": len(afterimage_zero),
        "candidatePotentialActivePolicies": len(candidate_active),
        "exactInactivePolicies": len(exact_inactive),
        "ambiguousPolicies": len(ambiguous),
        "afterimageSubstrateNarrowedOutPolicies": len(narrowed_out),
        "viablePotentialActivePolicies": len(viable),
        "baselineFaultRows": baseline_faults,
    }
    gates = protocol["gates"]
    gate_results = {
        "carrierSupport": counts["carrierSelectorPolicies"] >=
            gates["minimumCarrierSelectorPolicies"],
        "carrierInactivity": counts["carrierNonselectorPolicies"] >=
            gates["minimumCarrierNonselectorPolicies"],
        "rewardOpportunity": counts["robustRewardOpportunityPolicies"] >=
            gates["minimumRobustRewardOpportunityPolicies"],
        "substrateSupport": counts["afterimageSubstratePolicies"] >=
            gates["minimumAfterimageSubstratePolicies"],
        "candidateSupport": counts["candidatePotentialActivePolicies"] >=
            gates["minimumCandidatePotentialActivePolicies"],
        "inactivity": counts["exactInactivePolicies"] >=
            gates["minimumExactInactivePolicies"],
        "measuredNarrowing": counts["afterimageSubstrateNarrowedOutPolicies"] >=
            gates["minimumSubstrateNarrowedOutPolicies"],
        "viability": counts["viablePotentialActivePolicies"] >=
            gates["minimumViablePotentialActivePolicies"],
        "scorelineSeparation": (
            scoreline_separation["candidateOnlyPolicies"] >=
            gates["minimumCandidateOnlyPolicies"]
            and scoreline_separation["anchorOnlyPolicies"] >=
            gates["minimumAnchorOnlyPolicies"]
            and scoreline_separation["jaccard"] <= gates["maximumScorelineJaccard"]),
        "reliability": baseline_faults <= gates["maximumBaselineFaultRows"],
    }
    elapsed = time.monotonic() - started
    if elapsed > float(protocol["budget"]["maximumWallTimeSeconds"]):
        boundary, decision = 3, "record-mirror-oath-capacity-inconclusive-at-cap"
    elif all(gate_results.values()):
        boundary, decision = 1, "authorise-mirror-oath-two-knob-identity-preflight"
    else:
        boundary, decision = 2, "close-power-gated-afterimage-commitment-family"
    ledger_after = identity.ledger_identity()
    require("zero-row ledger identity", ledger_after == ledger_before)
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "decisionBoundary": boundary,
        "decision": decision,
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "candidate": protocol["candidate"],
        "carrierSelectorFormula": protocol["carrierSelectorFormula"],
        "counts": counts,
        "scorelineSeparation": scoreline_separation,
        "gateResults": gate_results,
        "policySets": {
            "carrierSelector": sorted(selector),
            "carrierNonselector": sorted(nonselector),
            "robustRewardOpportunity": sorted(reward_opportunity_policies),
            "afterimageSubstrate": sorted(afterimage_substrate),
            "afterimageZero": sorted(afterimage_zero),
            "candidatePotentialActive": sorted(candidate_active),
            "exactInactive": sorted(exact_inactive),
            "ambiguous": sorted(ambiguous),
            "afterimageSubstrateNarrowedOut": sorted(narrowed_out),
            "viablePotentialActive": sorted(viable),
            "scoreline": sorted(scoreline),
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
