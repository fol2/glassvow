#!/usr/bin/env python3
"""Zero-row direct-kill relay attribution audit for issue #421."""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path
from typing import Any, Callable

import post_v38_competing_structural_options as options
import post_v38_knob_identity as ledger
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-kill-relay-attribution-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-kill-relay-attribution-v1.json"
SOURCE = core.ROOT / "target-switch-observation-v1-source"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Kill-relay attribution mismatch: {label}")


def classified_turns(
    row: dict[str, Any], cards: dict[str, Any],
) -> list[dict[str, Any]]:
    """Classify the first two single-target Attacks in each multi-enemy turn."""
    trace = row["trajectory"]
    fights = row["fights"]
    found: list[dict[str, Any]] = []
    fight_ids = {
        int(event["fight"])
        for field in ("turns", "plays", "dies")
        for event in trace[field]
    }
    for fight in sorted(fight_ids):
        require(f"fight index {fight}", 0 <= fight < len(fights))
        if len(fights[fight]["enemies"]) < 2:
            continue
        events: list[tuple[int, int, dict[str, Any]]] = []
        events.extend(
            (int(event["event"]), 0, event)
            for event in trace["turns"] if int(event["fight"]) == fight
        )
        events.extend(
            (int(event["event"]), 1, event)
            for event in trace["plays"] if int(event["fight"]) == fight
        )
        events.extend(
            (int(event["event"]), 2, event)
            for event in trace["dies"] if int(event["fight"]) == fight
        )
        orders = [order for order, _, _ in events]
        require(f"unique event order in fight {fight}", len(orders) == len(set(orders)))
        turns: list[dict[str, Any]] = []
        current: dict[str, Any] | None = None
        for order, kind, event in sorted(events, key=lambda item: (item[0], item[1])):
            if kind == 0:
                current = {"turnEvent": order, "plays": [], "dies": []}
                turns.append(current)
            elif current is not None:
                current["plays" if kind == 1 else "dies"].append(event)
        for turn in turns:
            plays = sorted(turn["plays"], key=lambda event: int(event["event"]))
            dies = sorted(turn["dies"], key=lambda event: int(event["event"]))
            single: list[dict[str, Any]] = []
            for play in plays:
                card_id = str(play["id"])
                require(f"known card {card_id}", card_id in cards)
                card = cards[card_id]
                if card.get("type") != "attack" or card.get("target") != "enemy":
                    continue
                target = play.get("targetIdx")
                require(
                    f"single-target index in fight {fight}",
                    isinstance(target, int) and not isinstance(target, bool)
                    and 0 <= target < len(fights[fight]["enemies"]),
                )
                single.append(play)
            if len(single) < 2:
                continue
            first, second = single[:2]
            first_order = int(first["event"])
            second_order = int(second["event"])
            first_target = int(first["targetIdx"])
            second_target = int(second["targetIdx"])
            first_deaths = [
                int(event["event"]) for event in dies
                if int(event["idx"]) == first_target
                and first_order < int(event["event"]) < second_order
            ]
            if not first_deaths:
                continue
            death_order = first_deaths[0]
            if first_target == second_target:
                classification = "invalid-dead-target-reuse"
            else:
                intervening_plays = [
                    play for play in plays
                    if first_order < int(play["event"]) < second_order
                ]
                next_play_after_death = next(
                    (play for play in plays if int(play["event"]) > death_order), None,
                )
                if intervening_plays or next_play_after_death is not second:
                    classification = "intervening-play-alias"
                else:
                    next_play_after_second = next(
                        (play for play in plays if int(play["event"]) > second_order), None,
                    )
                    resolution_end = (
                        int(next_play_after_second["event"])
                        if next_play_after_second is not None else 1 << 60
                    )
                    consumer_died = any(
                        int(event["idx"]) == second_target
                        and second_order < int(event["event"]) < resolution_end
                        for event in dies
                    )
                    classification = (
                        "consumer-died-on-resolution" if consumer_died
                        else "payoff-eligible-direct-kill-relay"
                    )
            found.append({
                "fight": fight,
                "turnEvent": int(turn["turnEvent"]),
                "firstEvent": first_order,
                "deathEvent": death_order,
                "secondEvent": second_order,
                "firstCard": str(first["id"]),
                "secondCard": str(second["id"]),
                "firstTargetIdx": first_target,
                "secondTargetIdx": second_target,
                "classification": classification,
            })
    return found


def robust_keys(
    qualifying: set[tuple[int, int]], protocol: dict[str, Any],
) -> set[int]:
    cohort = protocol["cohort"]
    return {
        policy for policy in range(cohort["policyCount"])
        if sum((policy, seed) in qualifying for seed in cohort["simulationSeeds"])
        >= cohort["minimumRowsPerRobustPolicy"]
    }


def exact_inactive_keys(
    qualifying: set[tuple[int, int]], protocol: dict[str, Any],
) -> set[int]:
    cohort = protocol["cohort"]
    return {
        policy for policy in range(cohort["policyCount"])
        if not any((policy, seed) in qualifying for seed in cohort["simulationSeeds"])
    }


def robust_set(
    rows: dict[tuple[int, int], dict[str, Any]],
    protocol: dict[str, Any],
    predicate: Callable[[dict[str, Any]], bool],
) -> set[int]:
    return options.robust_set(rows, protocol, predicate)


def self_check() -> None:
    cards = {
        "a": {"type": "attack", "target": "enemy"},
        "b": {"type": "attack", "target": "enemy"},
        "skill": {"type": "skill", "target": "self"},
    }
    row = {
        "fights": [{"enemies": ["x", "y", "z"]}],
        "trajectory": {
            "turns": [
                {"fight": 0, "event": 1},
                {"fight": 0, "event": 10},
                {"fight": 0, "event": 20},
            ],
            "plays": [
                {"fight": 0, "event": 2, "id": "a", "targetIdx": 0},
                {"fight": 0, "event": 4, "id": "b", "targetIdx": 1},
                {"fight": 0, "event": 11, "id": "a", "targetIdx": 0},
                {"fight": 0, "event": 13, "id": "skill", "targetIdx": None},
                {"fight": 0, "event": 14, "id": "b", "targetIdx": 1},
                {"fight": 0, "event": 21, "id": "a", "targetIdx": 0},
                {"fight": 0, "event": 23, "id": "b", "targetIdx": 2},
            ],
            "dies": [
                {"fight": 0, "event": 3, "idx": 0},
                {"fight": 0, "event": 12, "idx": 0},
                {"fight": 0, "event": 22, "idx": 0},
                {"fight": 0, "event": 24, "idx": 2},
            ],
        },
    }
    turns = classified_turns(row, cards)
    require("three broad death turns", len(turns) == 3)
    require(
        "payoff-eligible direct relay",
        turns[0]["classification"] == "payoff-eligible-direct-kill-relay",
    )
    require(
        "intervening play alias",
        turns[1]["classification"] == "intervening-play-alias",
    )
    require(
        "consumer death exclusion",
        turns[2]["classification"] == "consumer-died-on-resolution",
    )


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the kill-relay attribution summary")
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
    require("output plan identity", output["planSha256"] == trace["planSha256"])
    require("plan arm", plan["arm"] == "target-death-trace-explicit-null")
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

    cards = content["cards"]
    authored_damage = [
        int(effect["n"])
        for card in cards.values() if card.get("type") == "attack"
        for effect in card.get("effects", [])
        if effect.get("kind") == "dmg" and isinstance(effect.get("n"), int)
        and int(effect["n"]) > 0
    ]
    require(
        "minimum authored damage quantum",
        min(authored_damage) == protocol["mechanismContract"]["payoffDamage"],
    )
    row_turns = {key: classified_turns(row, cards) for key, row in rows.items()}
    broad_keys = {key for key, turns in row_turns.items() if turns}
    attributable_keys = {
        key for key, turns in row_turns.items()
        if any(turn["classification"] in {
            "payoff-eligible-direct-kill-relay", "consumer-died-on-resolution"
        } for turn in turns)
    }
    eligible_keys = {
        key for key, turns in row_turns.items()
        if any(turn["classification"] == "payoff-eligible-direct-kill-relay"
               for turn in turns)
    }
    semantic_faults = [
        {"policyIndex": key[0], "seed": key[1], **turn}
        for key, turns in row_turns.items() for turn in turns
        if turn["classification"] == "invalid-dead-target-reuse"
    ]
    all_turns = [turn for turns in row_turns.values() for turn in turns]
    eligible_turns = [
        turn for turn in all_turns
        if turn["classification"] == "payoff-eligible-direct-kill-relay"
    ]
    require(
        "broad forced-death discovery count",
        len(all_turns) == protocol["anchors"]["forcedDeathDiscovery"]["turns"],
    )

    active = robust_keys(eligible_keys, protocol)
    inactive = exact_inactive_keys(eligible_keys, protocol)
    ambiguous = set(range(cohort["policyCount"])) - active - inactive
    broad_active = robust_keys(broad_keys, protocol)
    attributable_active = robust_keys(attributable_keys, protocol)
    viable = {
        policy for policy in active
        if any((policy, seed) in eligible_keys
               and rows[(policy, seed)].get("outcome") == "win"
               for seed in cohort["simulationSeeds"])
    }

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
    reaper_summary = json.loads(
        (core.ROOT / protocol["anchors"]["reaperBell"]["summaryPath"]).read_text()
    )
    reaper = set(reaper_summary["policySets"]["potentialActive"])
    require("Reaper Bell decision", reaper_summary["decision"] ==
            protocol["anchors"]["reaperBell"]["decision"])
    require("Reaper Bell policies", reaper == set(protocol["anchors"]["reaperBell"]["policies"]))
    target_summary = json.loads(
        (core.ROOT / protocol["anchors"]["targetTransfer"]["summaryPath"]).read_text()
    )
    target_transfer = set(target_summary["policySets"]["active"])
    require("target-transfer decision", target_summary["decision"] ==
            protocol["anchors"]["targetTransfer"]["decision"])
    require("target-transfer policies", target_transfer ==
            set(protocol["anchors"]["targetTransfer"]["policies"]))

    first_cards = {turn["firstCard"] for turn in eligible_turns}
    second_cards = {turn["secondCard"] for turn in eligible_turns}
    card_pairs = {(turn["firstCard"], turn["secondCard"]) for turn in eligible_turns}
    transitions = {
        (turn["firstTargetIdx"], turn["secondTargetIdx"]) for turn in eligible_turns
    }
    separations = {
        "scoreline": options.separation(active, scoreline),
        "afterimage": options.separation(active, afterimage),
        "reaperBell": options.separation(active, reaper),
        "targetTransfer": options.separation(active, target_transfer),
    }
    fault_rows = sum(
        row.get("outcome") in ("stall", "error") or bool(row.get("error"))
        for row in rows.values()
    )
    gates = protocol["gates"]

    def separated_two_sided(result: dict[str, Any]) -> bool:
        return (
            result["candidateOnlyPolicies"] >= gates["minimumCandidateOnlyPolicies"]
            and result["anchorOnlyPolicies"] >= gates["minimumAnchorOnlyPolicies"]
            and result["jaccard"] <= gates["maximumAnchorJaccard"]
        )

    def separated_one_sided(result: dict[str, Any], maximum: float) -> bool:
        return (
            result["candidateOnlyPolicies"] >= gates["minimumCandidateOnlyPolicies"]
            and result["jaccard"] <= maximum
        )

    checks = {
        "activeSupport": len(active) >= gates["minimumActivePolicies"],
        "inactiveSupport": len(inactive) >= gates["minimumExactInactivePolicies"],
        "viableSupport": len(viable) >= gates["minimumViablePolicies"],
        "firstCardBreadth": len(first_cards) >= gates["minimumDistinctFirstCards"],
        "secondCardBreadth": len(second_cards) >= gates["minimumDistinctSecondCards"],
        "cardPairBreadth": len(card_pairs) >= gates["minimumDistinctCardPairs"],
        "targetTransitionBreadth": len(transitions) >=
            gates["minimumDistinctTargetTransitions"],
        "scorelineSeparation": separated_two_sided(separations["scoreline"]),
        "afterimageSeparation": separated_two_sided(separations["afterimage"]),
        "reaperBellSeparation": separated_one_sided(
            separations["reaperBell"], gates["maximumReaperBellJaccard"]
        ),
        "targetTransferSeparation": separated_one_sided(
            separations["targetTransfer"], gates["maximumTargetTransferJaccard"]
        ),
        "semanticValidity": not semantic_faults,
        "reliability": fault_rows <= gates["maximumBaselineFaultRows"],
    }
    elapsed = time.monotonic() - started
    if elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        outcome_class = "inconclusive"
        boundary = 3
        decision = "record-kill-relay-attribution-inconclusive-at-cap"
    elif all(checks.values()):
        outcome_class = "success"
        boundary = 1
        decision = "freeze-direct-kill-relay-for-identity-preflight"
    else:
        outcome_class = "futility"
        boundary = 2
        decision = "close-direct-kill-relay-at-attribution-boundary"
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
            "broadForcedDeathPolicies": len(broad_active),
            "attributableDirectKillPolicies": len(attributable_active),
            "broadForcedDeathRows": len(broad_keys),
            "attributableDirectKillRows": len(attributable_keys),
            "payoffEligibleRows": len(eligible_keys),
            "broadForcedDeathTurns": len(all_turns),
            "payoffEligibleTurns": len(eligible_turns),
            "interveningPlayAliasTurns": sum(
                turn["classification"] == "intervening-play-alias" for turn in all_turns
            ),
            "consumerDiedOnResolutionTurns": sum(
                turn["classification"] == "consumer-died-on-resolution"
                for turn in all_turns
            ),
            "semanticFaultPairs": len(semantic_faults),
            "distinctFirstCards": len(first_cards),
            "distinctSecondCards": len(second_cards),
            "distinctCardPairs": len(card_pairs),
            "distinctTargetTransitions": len(transitions),
            "baselineFaultRows": fault_rows,
        },
        "sourceBreadth": {
            "payoffDamage": protocol["mechanismContract"]["payoffDamage"],
            "observedFirstCards": sorted(first_cards),
            "observedSecondCards": sorted(second_cards),
            "observedCardPairs": sorted([list(pair) for pair in card_pairs]),
            "observedTargetTransitions": sorted([list(pair) for pair in transitions]),
        },
        "separation": separations,
        "policySets": {
            "active": sorted(active),
            "exactInactive": sorted(inactive),
            "ambiguous": sorted(ambiguous),
            "viable": sorted(viable),
            "broadForcedDeath": sorted(broad_active),
            "attributableDirectKill": sorted(attributable_active),
        },
        "semanticFaults": semantic_faults,
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
        "activePolicies": len(active),
        "exactInactivePolicies": len(inactive),
        "viablePolicies": len(viable),
        "newSimulatorObservationRows": 0,
    }))


if __name__ == "__main__":
    main()
