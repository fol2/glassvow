#!/usr/bin/env python3
"""Zero-row inventory for source-defined one-bit Duskblade setup grammars."""

from __future__ import annotations

import copy
import json
import subprocess
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-action-grammar-inventory-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-action-grammar-inventory-v1.json"
META = ("id", "stage", "arm", "trajectory")


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Action grammar inventory mismatch: {label}")


def canonical_without(row: dict[str, Any]) -> str:
    value = copy.deepcopy(row)
    for key in META:
        value.pop(key, None)
    return core.canonical(value)


def reward_pool(content: dict[str, Any]) -> set[str]:
    pools = content["cardPools"]
    return set(map(str, pools["common"] + pools["uncommon"] + pools["rare"]))


def source_producers(content: dict[str, Any], grammar: str) -> list[str]:
    pool = reward_pool(content)
    found = []
    for card_id, card in content["cards"].items():
        if card_id not in pool:
            continue
        effects = card.get("effects", [])
        if grammar == "power-temper" and card.get("type") == "power":
            found.append(card_id)
        elif grammar == "energy-temper" and any(
                effect.get("kind") == "energy" and int(effect.get("n", 0)) > 0
                for effect in effects):
            found.append(card_id)
        elif grammar == "cycle-temper" and card.get("type") == "skill" and any(
                effect.get("kind") == "draw" and int(effect.get("n", 0)) > 0
                for effect in effects):
            found.append(card_id)
    return sorted(found)


def ordered_plays(row: dict[str, Any]) -> dict[int, list[dict[str, Any]]]:
    by_fight: dict[int, list[dict[str, Any]]] = {}
    for play in row["trajectory"]["plays"]:
        by_fight.setdefault(int(play["fight"]), []).append(play)
    return {fight: sorted(plays, key=lambda play: int(play["event"]))
            for fight, plays in by_fight.items()}


def activated_producers(row: dict[str, Any], producers: set[str],
                        cards: dict[str, Any]) -> set[str]:
    activated = set()
    for plays in ordered_plays(row).values():
        for index, play in enumerate(plays):
            if play["id"] not in producers:
                continue
            if any(cards.get(later["id"], {}).get("type") == "attack"
                   for later in plays[index + 1:]):
                activated.add(str(play["id"]))
    return activated


def scoreline_route(row: dict[str, Any]) -> bool:
    for plays in ordered_plays(row).values():
        first_chisel = next((int(play["event"]) for play in plays
                             if play["id"] == "chisel"), None)
        if first_chisel is not None and any(
                play["id"] == "executioner" and int(play["event"]) > first_chisel
                for play in plays):
            return True
    return False


def policy_set(rows: dict[tuple[int, int], dict[str, Any]], protocol: dict[str, Any],
               predicate: Any) -> set[int]:
    cohort = protocol["cohort"]
    return {
        policy_index for policy_index in range(cohort["policyCount"])
        if sum(predicate(rows[(policy_index, seed)])
               for seed in cohort["simulationSeeds"]) >=
        cohort["minimumRowsPerRobustPolicy"]
    }


def analyse_candidate(candidate: dict[str, Any], rows: dict[tuple[int, int], dict[str, Any]],
                      content: dict[str, Any], scoreline: set[int],
                      protocol: dict[str, Any]) -> dict[str, Any]:
    producers = set(candidate["producerCards"])
    cards = content["cards"]

    def active(row: dict[str, Any]) -> bool:
        return bool(activated_producers(row, producers, cards))

    active_policies = policy_set(rows, protocol, active)
    inactive_policies = {
        policy_index for policy_index in range(protocol["cohort"]["policyCount"])
        if not any(active(rows[(policy_index, seed)])
                   for seed in protocol["cohort"]["simulationSeeds"])
    }
    ambiguous_policies = (set(range(protocol["cohort"]["policyCount"]))
                          - active_policies - inactive_policies)
    offered_policies = {
        policy_index for policy_index in range(protocol["cohort"]["policyCount"])
        if any(any(int(rows[(policy_index, seed)]["packageEvents"]
                           .get(f"{card_id}Offered", 0)) > 0 for card_id in producers)
               for seed in protocol["cohort"]["simulationSeeds"])
    }
    acquired_policies = {
        policy_index for policy_index in range(protocol["cohort"]["policyCount"])
        if any(bool(producers & set(map(str, rows[(policy_index, seed)]
                                        .get("deckIds", []))))
               for seed in protocol["cohort"]["simulationSeeds"])
    }
    viable_active_policies = {
        policy_index for policy_index in active_policies
        if any(active(rows[(policy_index, seed)])
               and rows[(policy_index, seed)].get("outcome") == "win"
               for seed in protocol["cohort"]["simulationSeeds"])
    }
    activated_cards = sorted({
        card_id for row in rows.values()
        for card_id in activated_producers(row, producers, cards)
    })
    candidate_only = active_policies - scoreline
    scoreline_only = scoreline - active_policies
    cross = active_policies & scoreline
    union = active_policies | scoreline
    separation = {
        "candidateOnlyPolicies": len(candidate_only),
        "scorelineOnlyPolicies": len(scoreline_only),
        "crossActivePolicies": len(cross),
        "jaccard": len(cross) / len(union) if union else 1.0,
    }
    counts = {
        "activePolicies": len(active_policies),
        "inactivePolicies": len(inactive_policies),
        "ambiguousPolicies": len(ambiguous_policies),
        "offeredPolicies": len(offered_policies),
        "acquiredPolicies": len(acquired_policies),
        "viableActivePolicies": len(viable_active_policies),
        "distinctActivatedProducerCards": len(activated_cards),
        "baselineFaultRows": sum(
            row.get("outcome") in ("stall", "error") or bool(row.get("error"))
            for row in rows.values()),
    }
    gates = protocol["gates"]
    gate_results = {
        "active": counts["activePolicies"] >= gates["minimumActivePolicies"],
        "inactive": counts["inactivePolicies"] >= gates["minimumInactivePolicies"],
        "reachable": counts["offeredPolicies"] >= gates["minimumOfferedPolicies"]
        and counts["acquiredPolicies"] >= gates["minimumAcquiredPolicies"],
        "viable": counts["viableActivePolicies"] >= gates["minimumViableActivePolicies"],
        "sourceBreadth": counts["distinctActivatedProducerCards"] >=
        gates["minimumDistinctActivatedProducerCards"],
        "scorelineSeparation": separation["candidateOnlyPolicies"] >=
        gates["minimumCandidateOnlyPolicies"]
        and separation["scorelineOnlyPolicies"] >= gates["minimumScorelineOnlyPolicies"]
        and separation["jaccard"] <= gates["maximumScorelineJaccard"],
        "reliability": counts["baselineFaultRows"] <= gates["maximumBaselineFaultRows"],
    }
    return {
        "id": candidate["id"],
        "producerCards": candidate["producerCards"],
        "activatedProducerCards": activated_cards,
        "counts": counts,
        "separation": separation,
        "gateResults": gate_results,
        "status": "pass" if all(gate_results.values()) else "fail",
        "policySets": {
            "active": sorted(active_policies),
            "inactive": sorted(inactive_policies),
            "ambiguous": sorted(ambiguous_policies),
            "candidateOnly": sorted(candidate_only),
            "scorelineOnly": sorted(scoreline_only),
            "viableActive": sorted(viable_active_policies),
        },
    }


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the action grammar inventory")
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

    cohort = protocol["cohort"]
    baseline_rows = {
        (int(row["policyIndex"]), int(row["seed"])): row
        for row in baseline_output["rows"] if row.get("arm") == "policy"
        and row.get("aspect") == cohort["aspect"] and int(row.get("vow", -1)) == cohort["vow"]
    }
    current_rows = {
        (int(row["policyIndex"]), int(row["seed"])): row
        for row in trace_output["rows"] if row.get("arm") == "current"
        and row.get("aspect") == cohort["aspect"] and int(row.get("vow", -1)) == cohort["vow"]
    }
    expected = cohort["policyCount"] * len(cohort["simulationSeeds"])
    require("baseline rectangle", len(baseline_rows) == expected)
    require("current trace rectangle", len(current_rows) == expected)
    for key, row in current_rows.items():
        require("trace-current frozen identity",
                canonical_without(row) == canonical_without(baseline_rows[key]))
        for play in row["trajectory"]["plays"]:
            require("complete play telemetry", set(play) == {"fight", "event", "id", "uid"})

    for candidate in protocol["candidates"]:
        require(f"{candidate['id']} source producer freeze",
                source_producers(content, candidate["id"]) == candidate["producerCards"])
    scoreline = policy_set(current_rows, protocol, scoreline_route)
    require("Scoreline anchor count", len(scoreline) == protocol["scorelineAnchor"]["activePolicies"])
    assessments = [analyse_candidate(candidate, current_rows, content, scoreline, protocol)
                   for candidate in protocol["candidates"]]
    by_id = {assessment["id"]: assessment for assessment in assessments}
    selected = next((by_id[candidate_id] for candidate_id in protocol["selectionOrder"]
                     if by_id[candidate_id]["status"] == "pass"), None)
    elapsed = time.monotonic() - started
    if elapsed > float(protocol["budget"]["maximumWallTimeSeconds"]):
        boundary, decision = 3, "record-action-grammar-inventory-inconclusive-at-cap"
        selected = None
    elif selected is not None:
        boundary, decision = 1, f"freeze-{selected['id']}-for-identity-preflight"
    else:
        boundary, decision = 2, "close-one-bit-setup-action-grammar"
    ledger_after = identity.ledger_identity()
    require("zero-row ledger identity", ledger_after == ledger_before)
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "decisionBoundary": boundary,
        "decision": decision,
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "traceIdentity": {
            "baselineRows": len(baseline_rows),
            "currentTraceRows": len(current_rows),
            "pathRngResultExact": True,
            "scorelineActivePolicies": sorted(scoreline),
        },
        "assessments": assessments,
        "selectedCandidate": selected,
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
        "selectedCandidate": None if selected is None else selected["id"],
        "summarySha256": core.file_sha(SUMMARY),
        "newSimulatorObservationRows": 0,
    }))


if __name__ == "__main__":
    main()
