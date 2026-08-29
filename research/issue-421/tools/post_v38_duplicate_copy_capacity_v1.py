#!/usr/bin/env python3
"""Zero-row same-ID, different-CardInst duplicate-copy capacity audit."""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path
from typing import Any, Callable

import post_v38_competing_structural_options as options
import post_v38_knob_identity as ledger
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-duplicate-copy-capacity-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-duplicate-copy-capacity-v1.json"
SOURCE = core.ROOT / "target-switch-observation-v1-source"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Duplicate-copy capacity mismatch: {label}")


def reward_cards(content: dict[str, Any]) -> list[str]:
    result = {
        str(card_id)
        for pool in content["cardPools"].values()
        for card_id in pool
    }
    result.update(
        str(unlock).removeprefix("card:")
        for deed in content["deeds"].values()
        for unlock in deed.get("unlocks", [])
        if str(unlock).startswith("card:")
    )
    return sorted(result)


def duplicate_copy_events(
    row: dict[str, Any], cards: dict[str, Any], reward_ids: set[str],
) -> tuple[list[dict[str, Any]], list[dict[str, Any]], list[dict[str, Any]]]:
    """Return the first duplicate-copy use and every co-draw exposure per turn."""
    trace = row["trajectory"]
    qualifying: list[dict[str, Any]] = []
    exposures: list[dict[str, Any]] = []
    faults: list[dict[str, Any]] = []
    fight_ids = {
        int(event["fight"])
        for field in ("turns", "plays", "draws")
        for event in trace[field]
    }
    for fight in sorted(fight_ids):
        events: list[tuple[int, int, dict[str, Any]]] = []
        events.extend(
            (int(event["event"]), 0, event)
            for event in trace["turns"] if int(event["fight"]) == fight
        )
        events.extend(
            (int(event["event"]), 1, event)
            for event in trace["draws"] if int(event["fight"]) == fight
        )
        events.extend(
            (int(event["event"]), 2, event)
            for event in trace["plays"] if int(event["fight"]) == fight
        )
        orders = [order for order, _, _ in events]
        require(f"unique event order in fight {fight}", len(orders) == len(set(orders)))
        turns: list[dict[str, Any]] = []
        current: dict[str, Any] | None = None
        for order, kind, event in sorted(events, key=lambda item: (item[0], item[1])):
            if kind == 0:
                current = {"turnEvent": order, "draws": [], "plays": []}
                turns.append(current)
            elif current is not None:
                current["draws" if kind == 1 else "plays"].append(event)

        for turn in turns:
            drawn: dict[str, dict[int, int]] = {}
            for event in turn["draws"]:
                card_id = str(event["id"])
                if card_id not in cards:
                    faults.append({
                        "fight": fight,
                        "event": int(event["event"]),
                        "fault": "unknown-drawn-card",
                        "id": card_id,
                    })
                    continue
                if card_id not in reward_ids:
                    continue
                uid = int(event["uid"])
                drawn.setdefault(card_id, {}).setdefault(uid, int(event["event"]))
            exposed_ids = sorted(card_id for card_id, uids in drawn.items() if len(uids) >= 2)
            exposures.extend({
                "fight": fight,
                "turnEvent": int(turn["turnEvent"]),
                "card": card_id,
                "drawUids": sorted(drawn[card_id]),
            } for card_id in exposed_ids)

            first_play: dict[str, dict[str, Any]] = {}
            candidates: list[dict[str, Any]] = []
            for event in sorted(turn["plays"], key=lambda item: int(item["event"])):
                card_id = str(event["id"])
                if card_id not in cards:
                    faults.append({
                        "fight": fight,
                        "event": int(event["event"]),
                        "fault": "unknown-played-card",
                        "id": card_id,
                    })
                    continue
                if card_id not in reward_ids:
                    continue
                uid = int(event["uid"])
                prior = first_play.get(card_id)
                if prior is None:
                    first_play[card_id] = event
                    continue
                if int(prior["uid"]) == uid:
                    continue
                if uid not in drawn.get(card_id, {}) or int(prior["uid"]) not in drawn.get(card_id, {}):
                    faults.append({
                        "fight": fight,
                        "event": int(event["event"]),
                        "fault": "duplicate-play-without-two-turn-draws",
                        "id": card_id,
                    })
                    continue
                candidates.append({
                    "fight": fight,
                    "turnEvent": int(turn["turnEvent"]),
                    "card": card_id,
                    "producerEvent": int(prior["event"]),
                    "producerUid": int(prior["uid"]),
                    "consumerEvent": int(event["event"]),
                    "consumerUid": uid,
                    "interveningPlays": sum(
                        int(prior["event"]) < int(other["event"]) < int(event["event"])
                        for other in turn["plays"]
                    ),
                })
            if candidates:
                qualifying.append(min(candidates, key=lambda item: item["consumerEvent"]))
    return qualifying, exposures, faults


def robust_keys(keys: set[tuple[int, int]], protocol: dict[str, Any]) -> set[int]:
    cohort = protocol["cohort"]
    return {
        policy for policy in range(cohort["policyCount"])
        if sum((policy, seed) in keys for seed in cohort["simulationSeeds"])
        >= cohort["minimumRowsPerRobustPolicy"]
    }


def exact_inactive_keys(keys: set[tuple[int, int]], protocol: dict[str, Any]) -> set[int]:
    cohort = protocol["cohort"]
    return {
        policy for policy in range(cohort["policyCount"])
        if not any((policy, seed) in keys for seed in cohort["simulationSeeds"])
    }


def robust_set(
    rows: dict[tuple[int, int], dict[str, Any]],
    protocol: dict[str, Any],
    predicate: Callable[[dict[str, Any]], bool],
) -> set[int]:
    return options.robust_set(rows, protocol, predicate)


def self_check() -> None:
    cards = {
        "copy": {"type": "attack", "target": "enemy", "rarity": "common"},
        "other": {"type": "skill", "target": "self", "rarity": "uncommon"},
    }
    row = {
        "trajectory": {
            "turns": [{"fight": 0, "event": 1}, {"fight": 0, "event": 20}],
            "draws": [
                {"fight": 0, "event": 2, "id": "copy", "uid": 4},
                {"fight": 0, "event": 3, "id": "copy", "uid": 5},
                {"fight": 0, "event": 21, "id": "copy", "uid": 6},
                {"fight": 0, "event": 22, "id": "copy", "uid": 7},
                {"fight": 0, "event": 24, "id": "copy", "uid": 8},
            ],
            "plays": [
                {"fight": 0, "event": 4, "id": "copy", "uid": 4},
                {"fight": 0, "event": 5, "id": "other", "uid": 8},
                {"fight": 0, "event": 6, "id": "copy", "uid": 5},
                {"fight": 0, "event": 23, "id": "copy", "uid": 6},
            ],
        },
    }
    qualifying, exposures, faults = duplicate_copy_events(row, cards, {"copy", "other"})
    require("self-check faults", not faults)
    require("self-check exposures", len(exposures) == 2)
    require("self-check qualifying", len(qualifying) == 1)
    require("self-check different uid", qualifying[0]["producerUid"] != qualifying[0]["consumerUid"])
    require("self-check intervening play", qualifying[0]["interveningPlays"] == 1)


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the duplicate-copy capacity summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    immutable = protocol["immutableInputs"]
    require("runner SHA", core.file_sha(Path(__file__)) == immutable["runnerSha256"])
    self_check()
    require(
        "task capsule SHA",
        core.file_sha(core.ROOT / immutable["taskCapsulePath"])
        == immutable["taskCapsuleSha256"],
    )
    for path, expected in immutable["researchFileSha256"].items():
        require(f"research file {path}", core.file_sha(core.ROOT / path) == expected)

    repository = Path(immutable["repositoryPath"])
    for ref, expected in immutable["repositoryRefs"].items():
        actual = subprocess.run(
            ["git", "rev-parse", ref], cwd=repository, check=True,
            text=True, capture_output=True,
        ).stdout.strip()
        require(f"repository ref {ref}", actual == expected)
    for path, expected in immutable["sourceSha256"].items():
        blob = subprocess.run(
            ["git", "show", f"{immutable['sourceHead']}:{path}"], cwd=repository,
            check=True, capture_output=True,
        ).stdout
        require(f"source {path}", core.sha(blob) == expected)

    observation_head = subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=SOURCE, check=True,
        text=True, capture_output=True,
    ).stdout.strip()
    require("observation source head", observation_head == immutable["observationSourceHead"])
    for path, expected in immutable["observationSourceSha256"].items():
        require(f"observation source {path}", core.file_sha(SOURCE / path) == expected)
    patch = subprocess.run(
        ["git", "diff", "--cached", "--binary"], cwd=SOURCE,
        check=True, capture_output=True,
    ).stdout
    require("observation patch SHA", core.sha(patch) == immutable["sourcePatchSha256"])

    ledger_before = ledger.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
    trace = protocol["trace"]
    plan_path = core.CACHE / f"{trace['planSha256']}.json"
    output_path = core.CACHE / f"{trace['outputSha256']}.json"
    content_path = core.CACHE / f"{trace['contentSha256']}.json"
    require("plan SHA", core.file_sha(plan_path) == trace["planSha256"])
    require("output SHA", core.file_sha(output_path) == trace["outputSha256"])
    require("content SHA", core.file_sha(content_path) == trace["contentSha256"])
    plan = json.loads(plan_path.read_text())
    output = json.loads(output_path.read_text())
    content = json.loads(content_path.read_text())
    require("plan arm", plan["arm"] == "target-death-trace-explicit-null")
    require("plan protocol identity", plan["protocolSha256"] == trace["identityProtocolSha256"])
    require("output plan identity", output["planSha256"] == trace["planSha256"])

    cohort = protocol["cohort"]
    require("plan rows", len(plan["rows"]) == cohort["rows"])
    require("output rows", len(output["rows"]) == cohort["rows"])
    require(
        "cached-row ceiling",
        len(output["rows"]) <= protocol["budget"]["maximumCachedObservationRowsRead"],
    )
    rows: dict[tuple[int, int], dict[str, Any]] = {}
    policy_snapshots: dict[int, set[str]] = {}
    for spec, row in zip(plan["rows"], output["rows"]):
        require("trace arm", spec.get("arm") == "cohand-telemetry-explicit-null")
        require("trace capture", spec.get("captureTrace") is True)
        require("trace explicit null", spec.get("explicitNull") is True)
        key = (int(spec["policyIndex"]), int(spec["seed"]))
        require(f"unique row {key}", key not in rows)
        require(f"seed {key}", int(row["seed"]) == key[1])
        rows[key] = row
        policy_snapshots.setdefault(key[0], set()).add(core.canonical(row["policy"]))
    require("complete rectangle", len(rows) == cohort["rows"])
    require(
        "one policy snapshot per identity",
        len(policy_snapshots) == cohort["policyCount"]
        and all(len(snapshots) == 1 for snapshots in policy_snapshots.values()),
    )

    rewards = reward_cards(content)
    require("source reward set", rewards == protocol["rewardCards"])
    row_events: dict[tuple[int, int], list[dict[str, Any]]] = {}
    row_exposures: dict[tuple[int, int], list[dict[str, Any]]] = {}
    semantic_faults: list[dict[str, Any]] = []
    for key, row in rows.items():
        events, exposures, faults = duplicate_copy_events(row, content["cards"], set(rewards))
        row_events[key] = events
        row_exposures[key] = exposures
        semantic_faults.extend(
            {"policyIndex": key[0], "seed": key[1], **fault} for fault in faults
        )

    qualifying = {key for key, events in row_events.items() if events}
    exposed = {key for key, events in row_exposures.items() if events}
    active = robust_keys(qualifying, protocol)
    exposure_active = robust_keys(exposed, protocol)
    inactive = exact_inactive_keys(qualifying, protocol)
    ambiguous = set(range(cohort["policyCount"])) - active - inactive
    exposure_only = exposure_active - active
    viable = {
        policy for policy in active
        if any((policy, seed) in qualifying and rows[(policy, seed)].get("outcome") == "win"
               for seed in cohort["simulationSeeds"])
    }
    all_events = [event for events in row_events.values() for event in events]
    repeated_cards = {str(event["card"]) for event in all_events}
    repeated_types = {content["cards"][card_id]["type"] for card_id in repeated_cards}
    repeated_targets = {content["cards"][card_id]["target"] for card_id in repeated_cards}
    repeated_rarities = {content["cards"][card_id]["rarity"] for card_id in repeated_cards}
    adjacency = sum(event["interveningPlays"] == 0 for event in all_events)
    non_adjacency = len(all_events) - adjacency

    scoreline = robust_set(
        rows, protocol,
        lambda row: bool(options.ordered_pairs(row, {"chisel"}, {"executioner"})),
    )
    afterimage = robust_set(
        rows, protocol,
        lambda row: options.cohand.simultaneous_cohand(row, "defend", "guardedStrike"),
    )
    require("Scoreline anchor", scoreline == set(protocol["anchors"]["scoreline"]["policies"]))
    require("Afterimage anchor", afterimage == set(protocol["anchors"]["afterimage"]["policies"]))
    separations = {
        "scoreline": options.separation(active, scoreline),
        "afterimage": options.separation(active, afterimage),
    }
    gates = protocol["gates"]

    def separated(result: dict[str, Any]) -> bool:
        return (
            result["candidateOnlyPolicies"] >= gates["minimumCandidateOnlyPolicies"]
            and result["anchorOnlyPolicies"] >= gates["minimumAnchorOnlyPolicies"]
            and result["jaccard"] <= gates["maximumAnchorJaccard"]
        )

    fault_rows = sum(
        row.get("outcome") in ("stall", "error") or bool(row.get("error"))
        for row in rows.values()
    )
    checks = {
        "activeSupport": len(active) >= gates["minimumActivePolicies"],
        "inactiveSupport": len(inactive) >= gates["minimumExactInactivePolicies"],
        "viableSupport": len(viable) >= gates["minimumViablePolicies"],
        "exposureSupport": len(exposure_active) >= gates["minimumExposureActivePolicies"],
        "exposureOnlySupport": len(exposure_only) >= gates["minimumExposureOnlyPolicies"],
        "cardBreadth": len(repeated_cards) >= gates["minimumDistinctRepeatedCards"],
        "typeBreadth": len(repeated_types) >= gates["minimumDistinctTypes"],
        "targetBreadth": len(repeated_targets) >= gates["minimumDistinctTargets"],
        "rarityBreadth": len(repeated_rarities) >= gates["minimumDistinctRarities"],
        "adjacencyBreadth": adjacency >= gates["minimumAdjacentTurns"],
        "nonAdjacencyBreadth": non_adjacency >= gates["minimumNonAdjacentTurns"],
        "scorelineSeparation": separated(separations["scoreline"]),
        "afterimageSeparation": separated(separations["afterimage"]),
        "semanticValidity": len(semantic_faults) <= gates["maximumSemanticFaults"],
        "reliability": fault_rows <= gates["maximumBaselineFaultRows"],
    }
    elapsed = time.monotonic() - started
    if elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        outcome_class = "inconclusive"
        boundary = 3
        decision = "record-duplicate-copy-capacity-inconclusive-at-cap"
    elif all(checks.values()):
        outcome_class = "success"
        boundary = 1
        decision = "freeze-duplicate-copy-echo-for-identity-preflight"
    else:
        outcome_class = "futility"
        boundary = 2
        decision = "close-duplicate-copy-echo-at-zero-row-capacity"
    ledger_after = ledger.ledger_identity()
    require("zero-row ledger identity", ledger_after == ledger_before)
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "outcomeClass": outcome_class,
        "decisionBoundary": boundary,
        "decision": decision,
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "checks": checks,
        "counts": {
            "activePolicies": len(active),
            "exactInactivePolicies": len(inactive),
            "ambiguousPolicies": len(ambiguous),
            "viablePolicies": len(viable),
            "exposureActivePolicies": len(exposure_active),
            "exposureOnlyPolicies": len(exposure_only),
            "qualifyingRows": len(qualifying),
            "exposedRows": len(exposed),
            "qualifyingTurns": len(all_events),
            "exposureTurns": sum(len(events) for events in row_exposures.values()),
            "distinctRepeatedCards": len(repeated_cards),
            "distinctTypes": len(repeated_types),
            "distinctTargets": len(repeated_targets),
            "distinctRarities": len(repeated_rarities),
            "adjacentTurns": adjacency,
            "nonAdjacentTurns": non_adjacency,
        },
        "policySets": {
            "active": sorted(active),
            "exactInactive": sorted(inactive),
            "ambiguous": sorted(ambiguous),
            "viable": sorted(viable),
            "exposureActive": sorted(exposure_active),
            "exposureOnly": sorted(exposure_only),
        },
        "sourceBreadth": {
            "repeatedCards": sorted(repeated_cards),
            "types": sorted(repeated_types),
            "targets": sorted(repeated_targets),
            "rarities": sorted(repeated_rarities),
        },
        "separation": separations,
        "semanticFaults": semantic_faults,
        "baselineFaultRows": fault_rows,
        "cachedObservationRowsRead": len(rows),
        "newSimulatorObservationRows": 0,
        "newLedgerRows": 0,
        "protectedSeedRows": ledger_after["protectedSeedRows"],
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "maximumModelContextTokens": 0,
        "wallTimeSeconds": round(elapsed, 6),
        "claimBoundary": protocol["claimBoundary"],
        "authority": protocol["decisionRules"][f"{outcome_class}Authority"],
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": outcome_class.upper(),
        "decision": decision,
        "counts": summary["counts"],
        "newSimulatorObservationRows": 0,
    }))


if __name__ == "__main__":
    main()
