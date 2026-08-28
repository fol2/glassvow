#!/usr/bin/env python3
"""Zero-row capacity test for the one justified two-stage Dusk setup grammar."""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path
from typing import Any

import post_v38_action_grammar_inventory as previous
import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-power-cycle-capacity-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-power-cycle-capacity-v1.json"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Power-cycle capacity mismatch: {label}")


def activated_pairs(row: dict[str, Any], powers: set[str],
                    cycles: set[str], cards: dict[str, Any]) -> set[tuple[str, str]]:
    found: set[tuple[str, str]] = set()
    for plays in previous.ordered_plays(row).values():
        for power_index, power in enumerate(plays):
            if power["id"] not in powers:
                continue
            for cycle_index, cycle in enumerate(plays):
                if cycle["id"] not in cycles or cycle_index == power_index:
                    continue
                setup_end = max(power_index, cycle_index)
                if any(cards.get(later["id"], {}).get("type") == "attack"
                       for later in plays[setup_end + 1:]):
                    found.add((str(power["id"]), str(cycle["id"])))
    return found


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the Power-cycle capacity summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    require("runner SHA", core.file_sha(Path(__file__)) ==
            protocol["immutableInputs"]["runnerSha256"])
    require("source commit", subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=core.SOURCE, check=True,
        text=True, capture_output=True,
    ).stdout.strip() == protocol["immutableInputs"]["sourceCommit"])
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
    require("baseline plan SHA", baseline_output["planSha256"] ==
            protocol["baseline"]["planSha256"])
    require("trace plan SHA", trace_output["planSha256"] ==
            protocol["traceEvidence"]["planSha256"])

    candidate = protocol["candidate"]
    require("Power source freeze",
            previous.source_producers(content, "power-temper") == candidate["powerCards"])
    require("cycle source freeze",
            previous.source_producers(content, "cycle-temper") == candidate["cycleCards"])
    require("source classes disjoint",
            not set(candidate["powerCards"]) & set(candidate["cycleCards"]))

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
                previous.canonical_without(row) == previous.canonical_without(baseline_rows[key]))

    powers = set(candidate["powerCards"])
    cycles = set(candidate["cycleCards"])
    cards = content["cards"]

    def active(row: dict[str, Any]) -> bool:
        return bool(activated_pairs(row, powers, cycles, cards))

    active_policies = previous.policy_set(rows, protocol, active)
    inactive_policies = {
        policy_index for policy_index in range(cohort["policyCount"])
        if not any(active(rows[(policy_index, seed)]) for seed in cohort["simulationSeeds"])
    }
    ambiguous_policies = (set(range(cohort["policyCount"]))
                          - active_policies - inactive_policies)

    def offered(row: dict[str, Any], card_ids: set[str]) -> bool:
        return any(int(row["packageEvents"].get(f"{card_id}Offered", 0)) > 0
                   for card_id in card_ids)

    def acquired(row: dict[str, Any], card_ids: set[str]) -> bool:
        return bool(card_ids & set(map(str, row.get("deckIds", []))))

    offered_policies = {
        policy_index for policy_index in range(cohort["policyCount"])
        if any(offered(rows[(policy_index, seed)], powers)
               and offered(rows[(policy_index, seed)], cycles)
               for seed in cohort["simulationSeeds"])
    }
    acquired_policies = {
        policy_index for policy_index in range(cohort["policyCount"])
        if any(acquired(rows[(policy_index, seed)], powers)
               and acquired(rows[(policy_index, seed)], cycles)
               for seed in cohort["simulationSeeds"])
    }
    viable_active_policies = {
        policy_index for policy_index in active_policies
        if any(active(rows[(policy_index, seed)])
               and rows[(policy_index, seed)].get("outcome") == "win"
               for seed in cohort["simulationSeeds"])
    }
    pairs = sorted({pair for row in rows.values()
                    for pair in activated_pairs(row, powers, cycles, cards)})
    activated_powers = sorted({pair[0] for pair in pairs})
    activated_cycles = sorted({pair[1] for pair in pairs})
    scoreline = previous.policy_set(rows, protocol, previous.scoreline_route)
    require("Scoreline anchor", len(scoreline) == protocol["scorelineAnchor"]["activePolicies"])
    candidate_only = active_policies - scoreline
    scoreline_only = scoreline - active_policies
    cross = active_policies & scoreline
    union = active_policies | scoreline
    baseline_faults = sum(
        row.get("outcome") in ("stall", "error") or bool(row.get("error"))
        for row in rows.values())
    counts = {
        "activePolicies": len(active_policies),
        "inactivePolicies": len(inactive_policies),
        "ambiguousPolicies": len(ambiguous_policies),
        "offeredPolicies": len(offered_policies),
        "acquiredPolicies": len(acquired_policies),
        "viableActivePolicies": len(viable_active_policies),
        "distinctActivatedPowerCards": len(activated_powers),
        "distinctActivatedCycleCards": len(activated_cycles),
        "distinctActivatedPairs": len(pairs),
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
        "active": counts["activePolicies"] >= gates["minimumActivePolicies"],
        "inactive": counts["inactivePolicies"] >= gates["minimumInactivePolicies"],
        "reachable": counts["offeredPolicies"] >= gates["minimumOfferedPolicies"]
        and counts["acquiredPolicies"] >= gates["minimumAcquiredPolicies"],
        "viable": counts["viableActivePolicies"] >= gates["minimumViableActivePolicies"],
        "sourceBreadth": counts["distinctActivatedPowerCards"] >=
        gates["minimumDistinctActivatedPowerCards"]
        and counts["distinctActivatedCycleCards"] >=
        gates["minimumDistinctActivatedCycleCards"]
        and counts["distinctActivatedPairs"] >= gates["minimumDistinctActivatedPairs"],
        "scorelineSeparation": separation["candidateOnlyPolicies"] >=
        gates["minimumCandidateOnlyPolicies"]
        and separation["scorelineOnlyPolicies"] >= gates["minimumScorelineOnlyPolicies"]
        and separation["jaccard"] <= gates["maximumScorelineJaccard"],
        "reliability": baseline_faults <= gates["maximumBaselineFaultRows"],
    }
    elapsed = time.monotonic() - started
    if elapsed > float(protocol["budget"]["maximumWallTimeSeconds"]):
        boundary, decision = 3, "record-power-cycle-capacity-inconclusive-at-cap"
    elif all(gate_results.values()):
        boundary, decision = 1, "freeze-power-cycle-temper-for-identity-preflight"
    else:
        boundary, decision = 2, "close-power-cycle-two-stage-grammar"
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
        "activatedPowerCards": activated_powers,
        "activatedCycleCards": activated_cycles,
        "activatedPairs": [list(pair) for pair in pairs],
        "policySets": {
            "active": sorted(active_policies),
            "inactive": sorted(inactive_policies),
            "ambiguous": sorted(ambiguous_policies),
            "candidateOnly": sorted(candidate_only),
            "scorelineOnly": sorted(scoreline_only),
            "viableActive": sorted(viable_active_policies),
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
