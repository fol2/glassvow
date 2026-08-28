#!/usr/bin/env python3
"""Zero-new-row repertoire-capacity audit for private combat debt."""

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


PROTOCOL = core.ROOT / "protocols/post-v30-private-debt-capacity-v1.json"
SUMMARY = core.ROOT / "summaries/post-v30-private-debt-capacity-v1.json"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Private-debt capacity mismatch: {label}")


def main_blob(path: str) -> bytes:
    return subprocess.run(
        ["git", "show", f"HEAD:{path}"], cwd=core.SOURCE,
        check=True, capture_output=True,
    ).stdout


def producer_score(policy: dict[str, Any]) -> float:
    return float(policy["card"]["rarity"]["common"]) - 1.0 + 8.0


def consumer_score(policy: dict[str, Any]) -> float:
    return (float(policy["card"]["rarity"]["uncommon"]) - 1.0
            + 6.0 * float(policy["card"]["blockHeal"]))


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite private-debt capacity summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    immutable = protocol["immutableInputs"]
    require("runner SHA", core.file_sha(Path(__file__)) == immutable["runnerSha256"])
    require("task capsule SHA", core.file_sha(core.ROOT / "task-capsule.json") ==
            immutable["taskCapsuleSha256"])
    require("source commit", subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=core.SOURCE, check=True,
        text=True, capture_output=True,
    ).stdout.strip() == immutable["sourceCommit"])
    blobs = {path: main_blob(path) for path in immutable["sourceSha256"]}
    for path, expected_sha in immutable["sourceSha256"].items():
        require(f"{path} SHA", core.sha(blobs[path]) == expected_sha)
    content = json.loads(blobs["content/full-content.json"])
    candidate_ids = set(protocol["candidate"]["cardIds"])
    require("candidate IDs absent", not candidate_ids & set(content["cards"]))
    require("candidate pools absent", all(
        not candidate_ids & set(pool) for pool in content["cardPools"].values()))
    pilot = blobs["tools/balance_pilot.gd"].decode()
    for label, text in protocol["sourceAssertions"].items():
        require(label, text in pilot)
    require("mediator effects unscored",
            '"addCard"' not in pilot and '"removeCardFromHand"' not in pilot)

    for name, spec in protocol["priorEvidence"].items():
        path = core.ROOT / spec["path"]
        require(f"{name} SHA", core.file_sha(path) == spec["sha256"])
        require(f"{name} decision", json.loads(path.read_text())["decision"] ==
                spec["decision"])
    identity_summary = json.loads(
        (core.ROOT / protocol["identityGate"]["path"]).read_text())
    require("identity protocol", identity_summary["protocolSha256"] ==
            protocol["identityGate"]["protocolSha256"])
    require("identity decision", identity_summary["decision"] ==
            protocol["identityGate"]["decision"])
    require("identity exact", identity_summary["outcomeClass"] == "success"
            and not identity_summary["failure"]
            and identity_summary["enabledWholeRunRows"] == 0
            and identity_summary["causalRows"] == 0)

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
                trace.canonical_without(row) ==
                trace.canonical_without(baseline_rows[key]))

    policies: dict[int, dict[str, Any]] = {}
    for policy_index in range(cohort["policyCount"]):
        snapshots = {core.canonical(rows[(policy_index, seed)]["policy"])
                     for seed in cohort["simulationSeeds"]}
        require(f"policy {policy_index} identity", len(snapshots) == 1)
        policies[policy_index] = rows[
            (policy_index, cohort["simulationSeeds"][0])]["policy"]

    producer_selectors = {
        index for index, policy in policies.items()
        if producer_score(policy) >= float(policy["cardDecline"])
    }
    consumer_selectors = {
        index for index, policy in policies.items()
        if consumer_score(policy) >= float(policy["cardDecline"])
    }
    joint_selectors = producer_selectors & consumer_selectors
    joint_nonselectors = set(policies) - joint_selectors

    def two_rewards(row: dict[str, Any]) -> bool:
        return len(row.get("trajectory", {}).get("cardRewards", [])) >= 2

    def scoreline_row(row: dict[str, Any]) -> bool:
        return trace.scoreline_route(row)

    def afterimage_row(row: dict[str, Any]) -> bool:
        return int(row.get("packageEvents", {}).get("afterimageGuardDamage", 0)) > 0

    robust_opportunity = capacity.robust_policies(rows, protocol, two_rewards)
    zero_opportunity = {
        index for index in policies
        if not any(two_rewards(rows[(index, seed)])
                   for seed in cohort["simulationSeeds"])
    }
    candidate_active = joint_selectors & robust_opportunity
    exact_inactive = joint_nonselectors | zero_opportunity
    ambiguous = set(policies) - candidate_active - exact_inactive
    viable = {
        index for index in candidate_active
        if any(two_rewards(rows[(index, seed)])
               and rows[(index, seed)].get("outcome") == "win"
               for seed in cohort["simulationSeeds"])
    }
    scoreline = capacity.robust_policies(rows, protocol, scoreline_row)
    afterimage = capacity.robust_policies(rows, protocol, afterimage_row)
    anchors = protocol["sharedAnchors"]
    require("Scoreline anchor", sorted(scoreline) == anchors["scorelinePolicies"])
    require("Afterimage anchor", sorted(afterimage) == anchors["afterimagePolicies"])
    scoreline_separation = capacity.separation(candidate_active, scoreline)
    afterimage_separation = capacity.separation(candidate_active, afterimage)
    baseline_faults = sum(
        row.get("outcome") in ("stall", "error") or bool(row.get("error"))
        for row in rows.values())

    counts = {
        "producerSelectorPolicies": len(producer_selectors),
        "consumerSelectorPolicies": len(consumer_selectors),
        "jointSelectorPolicies": len(joint_selectors),
        "jointNonselectorPolicies": len(joint_nonselectors),
        "robustTwoRewardOpportunityPolicies": len(robust_opportunity),
        "zeroTwoRewardOpportunityPolicies": len(zero_opportunity),
        "candidatePotentialActivePolicies": len(candidate_active),
        "exactInactivePolicies": len(exact_inactive),
        "ambiguousPolicies": len(ambiguous),
        "viablePotentialActivePolicies": len(viable),
        "baselineFaultRows": baseline_faults,
    }
    gates = protocol["gates"]
    gate_results = {
        "producerSupport": counts["producerSelectorPolicies"] >=
            gates["minimumProducerSelectorPolicies"],
        "consumerSupport": counts["consumerSelectorPolicies"] >=
            gates["minimumConsumerSelectorPolicies"],
        "jointSupport": counts["jointSelectorPolicies"] >=
            gates["minimumJointSelectorPolicies"],
        "jointInactivity": counts["jointNonselectorPolicies"] >=
            gates["minimumJointNonselectorPolicies"],
        "rewardOpportunity": counts["robustTwoRewardOpportunityPolicies"] >=
            gates["minimumRobustTwoRewardOpportunityPolicies"],
        "candidateSupport": counts["candidatePotentialActivePolicies"] >=
            gates["minimumCandidatePotentialActivePolicies"],
        "exactInactivity": counts["exactInactivePolicies"] >=
            gates["minimumExactInactivePolicies"],
        "viability": counts["viablePotentialActivePolicies"] >=
            gates["minimumViablePotentialActivePolicies"],
        "scorelineSeparation": (
            scoreline_separation["candidateOnlyPolicies"] >=
            gates["minimumCandidateOnlyPolicies"]
            and scoreline_separation["anchorOnlyPolicies"] >=
            gates["minimumAnchorOnlyPolicies"]
            and scoreline_separation["jaccard"] <= gates["maximumAnchorJaccard"]),
        "afterimageSeparation": (
            afterimage_separation["candidateOnlyPolicies"] >=
            gates["minimumCandidateOnlyPolicies"]
            and afterimage_separation["anchorOnlyPolicies"] >=
            gates["minimumAnchorOnlyPolicies"]
            and afterimage_separation["jaccard"] <= gates["maximumAnchorJaccard"]),
        "reliability": baseline_faults <= gates["maximumBaselineFaultRows"],
    }
    elapsed = time.monotonic() - started
    if elapsed > float(protocol["budget"]["maximumWallTimeSeconds"]):
        boundary, decision = 3, "record-private-debt-capacity-inconclusive-at-cap"
    elif all(gate_results.values()):
        boundary, decision = 1, "authorise-private-debt-factor-identity-preflight"
    else:
        boundary, decision = 2, "close-private-debt-design-at-capacity"
    ledger_after = identity.ledger_identity()
    require("zero-row ledger identity", ledger_after == ledger_before)
    authority = protocol["decisionRules"][
        "successAuthority" if boundary == 1 else
        ("futilityAuthority" if boundary == 2 else "inconclusiveAuthority")]
    summary = {
        "schemaVersion": 1, "issue": 421, "decisionBoundary": boundary,
        "decision": decision, "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "candidate": protocol["candidate"],
        "carrierScoreFormula": protocol["carrierScoreFormula"],
        "counts": counts, "gateResults": gate_results,
        "scorelineSeparation": scoreline_separation,
        "afterimageSeparation": afterimage_separation,
        "policySets": {
            "producerSelectors": sorted(producer_selectors),
            "consumerSelectors": sorted(consumer_selectors),
            "jointSelectors": sorted(joint_selectors),
            "jointNonselectors": sorted(joint_nonselectors),
            "robustTwoRewardOpportunity": sorted(robust_opportunity),
            "zeroTwoRewardOpportunity": sorted(zero_opportunity),
            "candidatePotentialActive": sorted(candidate_active),
            "exactInactive": sorted(exact_inactive),
            "ambiguous": sorted(ambiguous),
            "viablePotentialActive": sorted(viable),
            "scoreline": sorted(scoreline), "afterimage": sorted(afterimage),
        },
        "cacheRowsRead": len(baseline_rows) + len(rows),
        "supportRowsInspected": len(rows),
        "newSimulatorObservationRows": 0, "newLedgerRows": 0,
        "ledgerBefore": ledger_before, "ledgerAfter": ledger_after,
        "protectedSeedRows": ledger_after["protectedSeedRows"],
        "maximumModelContextTokens": 0, "wallTimeSeconds": elapsed,
        "authority": authority,
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": "PASS", "decisionBoundary": boundary, "decision": decision,
        "newSimulatorObservationRows": 0, "summarySha256": core.file_sha(SUMMARY),
    }))


if __name__ == "__main__":
    main()
