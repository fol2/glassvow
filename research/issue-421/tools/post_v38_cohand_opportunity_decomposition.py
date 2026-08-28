#!/usr/bin/env python3
"""Zero-row exact co-hand opportunity decomposition for issue #421."""

from __future__ import annotations

import json
import time
from pathlib import Path
from typing import Any, Callable

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-cohand-opportunity-decomposition-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-cohand-opportunity-decomposition-v1.json"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Co-hand opportunity decomposition mismatch: {label}")


def grouped(row: dict[str, Any], field: str) -> dict[int, list[dict[str, Any]]]:
    by_fight: dict[int, list[dict[str, Any]]] = {}
    for event in row["trajectory"][field]:
        by_fight.setdefault(int(event["fight"]), []).append(event)
    return {fight: sorted(events, key=lambda event: int(event["event"]))
            for fight, events in by_fight.items()}


def co_occurs(row: dict[str, Any], field: str, left: str, right: str) -> bool:
    for events in grouped(row, field).values():
        ids = {str(event["id"]) for event in events}
        if left in ids and right in ids:
            return True
    return False


def ordered(row: dict[str, Any], first: str, second: str) -> bool:
    for plays in grouped(row, "plays").values():
        first_event = next(
            (int(play["event"]) for play in plays if play["id"] == first), None,
        )
        if first_event is not None and any(
            play["id"] == second and int(play["event"]) > first_event
            for play in plays
        ):
            return True
    return False


def simultaneous_cohand(row: dict[str, Any], left: str, right: str) -> bool:
    trace = row["trajectory"]
    fights = {int(event["fight"]) for field in ("turns", "draws", "plays", "kindles")
              for event in trace[field]}
    for fight in sorted(fights):
        events = []
        for field, kind in (("turns", "turn"), ("draws", "draw"),
                            ("plays", "play"), ("kindles", "kindle")):
            events.extend((int(event["event"]), kind, event)
                          for event in trace[field] if int(event["fight"]) == fight)
        events.sort(key=lambda item: item[0])
        hand: dict[int, str] = {}
        for _, kind, event in events:
            if kind == "turn":
                hand.clear()
            elif kind == "draw":
                hand[int(event["uid"])] = str(event["id"])
            else:
                hand.pop(int(event["uid"]), None)
            ids = set(hand.values())
            if left in ids and right in ids:
                return True
    return False


def robust_set(
    rows: dict[tuple[int, int], dict[str, Any]], protocol: dict[str, Any],
    predicate: Callable[[dict[str, Any]], bool],
) -> set[int]:
    cohort = protocol["cohort"]
    return {
        policy_index for policy_index in range(cohort["policyCount"])
        if sum(predicate(rows[(policy_index, seed)])
               for seed in cohort["simulationSeeds"])
        >= cohort["minimumRowsPerRobustPolicy"]
    }


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the co-hand opportunity summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    immutable = protocol["immutableInputs"]
    require("runner SHA", core.file_sha(Path(__file__)) == immutable["runnerSha256"])
    for path, expected in immutable["fileSha256"].items():
        require(path, core.file_sha(core.ROOT / path) == expected)
    ledger_before = identity.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
    plan_path = core.CACHE / f"{protocol['trace']['planSha256']}.json"
    output_path = core.CACHE / f"{protocol['trace']['outputSha256']}.json"
    require("plan SHA", core.file_sha(plan_path) == protocol["trace"]["planSha256"])
    require("output SHA", core.file_sha(output_path) == protocol["trace"]["outputSha256"])
    plan = json.loads(plan_path.read_text())
    output = json.loads(output_path.read_text())
    require("output plan identity", output["planSha256"] == protocol["trace"]["planSha256"])
    require("plan rows", len(plan["rows"]) == protocol["cohort"]["rows"])
    require("output rows", len(output["rows"]) == protocol["cohort"]["rows"])
    rows: dict[tuple[int, int], dict[str, Any]] = {}
    for spec, row in zip(plan["rows"], output["rows"]):
        require("arm", spec.get("arm") == "cohand-telemetry-explicit-null")
        require("capture", spec.get("captureTrace") is True)
        require("explicit null", spec.get("explicitNull") is True)
        key = (int(spec["policyIndex"]), int(spec["seed"]))
        require(f"unique row {key}", key not in rows)
        require(f"seed {key}", int(row["seed"]) == key[1])
        rows[key] = row
    require("complete rectangle", len(rows) == protocol["cohort"]["rows"])

    draw_row = lambda row: co_occurs(row, "draws", "defend", "guardedStrike")
    cohand_row = lambda row: simultaneous_cohand(row, "defend", "guardedStrike")
    co_play_row = lambda row: co_occurs(row, "plays", "defend", "guardedStrike")
    natural_order_row = lambda row: ordered(row, "defend", "guardedStrike")
    draw_policies = robust_set(rows, protocol, draw_row)
    cohand_policies = robust_set(rows, protocol, cohand_row)
    co_play_policies = robust_set(rows, protocol, co_play_row)
    natural_order_policies = robust_set(rows, protocol, natural_order_row)
    require("co-hand subset of same-fight draw", cohand_policies <= draw_policies)
    require("natural order subset of co-play", natural_order_policies <= co_play_policies)
    prior = json.loads((core.ROOT / protocol["priorDecomposition"]["path"]).read_text())
    require("prior draw count", len(draw_policies) == prior["counts"]["drawOpportunityPolicies"])
    require("prior co-play count", len(co_play_policies) == prior["counts"]["coPlayPolicies"])
    require("prior natural-order count", len(natural_order_policies) ==
            prior["counts"]["naturalOrderPolicies"])
    fault_rows = sum(
        row.get("outcome") in ("stall", "error") or bool(row.get("error"))
        for row in rows.values()
    )
    counts = {
        "drawOpportunityPolicies": len(draw_policies),
        "simultaneousCohandPolicies": len(cohand_policies),
        "coPlayPolicies": len(co_play_policies),
        "naturalOrderPolicies": len(natural_order_policies),
        "drawButNotCohandPolicies": len(draw_policies - cohand_policies),
        "cohandButNotCoPlayPolicies": len(cohand_policies - co_play_policies),
        "coPlayWithoutCohandPolicies": len(co_play_policies - cohand_policies),
        "coPlayButNotNaturalOrderPolicies": len(co_play_policies - natural_order_policies),
        "baselineFaultRows": fault_rows,
    }
    gates = protocol["gates"]
    gate_results = {
        "drawOpportunity": counts["drawOpportunityPolicies"] >=
        gates["minimumDrawOpportunityPolicies"],
        "simultaneousCohand": counts["simultaneousCohandPolicies"] >=
        gates["minimumSimultaneousCohandPolicies"],
        "coPlay": counts["coPlayPolicies"] >= gates["minimumCoPlayPolicies"],
        "naturalOrder": counts["naturalOrderPolicies"] >=
        gates["minimumNaturalOrderPolicies"],
        "reliability": fault_rows <= gates["maximumBaselineFaultRows"],
    }
    if not gate_results["drawOpportunity"]:
        failure_class = "hand-deck-cycle-substrate-bottleneck"
    elif not gate_results["simultaneousCohand"]:
        failure_class = "turn-level-cohand-opportunity-bottleneck"
    elif not gate_results["coPlay"]:
        failure_class = "legality-or-play-selection-unresolved"
    elif not gate_results["naturalOrder"]:
        failure_class = "policy-action-order-bottleneck"
    elif not gate_results["reliability"]:
        failure_class = "reliability"
    else:
        failure_class = "none"
    elapsed = time.monotonic() - started
    if elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        boundary = 3
        outcome_class = "inconclusive"
        decision = "record-cohand-opportunity-decomposition-inconclusive-at-cap"
    elif all(gate_results.values()):
        boundary = 1
        outcome_class = "success"
        decision = "freeze-natural-afterimage-route-capacity-after-cohand"
    else:
        boundary = 2
        outcome_class = "futility"
        decision = "close-natural-afterimage-route-at-exact-cohand-boundary"
    ledger_after = identity.ledger_identity()
    require("zero-row ledger identity", ledger_after == ledger_before)
    summary = {
        "schemaVersion": 1, "issue": 421, "decisionBoundary": boundary,
        "decision": decision, "outcomeClass": outcome_class,
        "failureClass": failure_class, "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)), "counts": counts,
        "gateResults": gate_results,
        "policySets": {
            "drawOpportunity": sorted(draw_policies),
            "simultaneousCohand": sorted(cohand_policies),
            "coPlay": sorted(co_play_policies),
            "naturalOrder": sorted(natural_order_policies),
            "drawButNotCohand": sorted(draw_policies - cohand_policies),
            "cohandButNotCoPlay": sorted(cohand_policies - co_play_policies),
            "coPlayWithoutCohand": sorted(co_play_policies - cohand_policies),
            "coPlayButNotNaturalOrder": sorted(co_play_policies - natural_order_policies),
        },
        "newSimulatorObservationRows": 0,
        "cachedObservationRowsRead": len(rows), "newLedgerRows": 0,
        "ledgerBefore": ledger_before, "ledgerAfter": ledger_after,
        "protectedSeedRows": ledger_after["protectedSeedRows"],
        "maximumModelContextTokens": 0, "wallTimeSeconds": elapsed,
        "factorDisposition": protocol["factorDisposition"],
        "authority": protocol["decisionRules"][f"{outcome_class}Authority"],
    }
    SUMMARY.parent.mkdir(parents=True, exist_ok=True)
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": "PASS", "decision": decision, "decisionBoundary": boundary,
        "failureClass": failure_class, "newSimulatorObservationRows": 0,
        "summarySha256": core.file_sha(SUMMARY),
    }))


if __name__ == "__main__":
    main()
