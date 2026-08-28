#!/usr/bin/env python3
"""Zero-row current-main Dusk package-order topology audit for issue #421."""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path
from typing import Any

import post_v38_action_grammar_inventory as grammar
import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-current-main-order-topology-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-current-main-order-topology-v1.json"
SOURCE = core.ROOT / "null-harness-instrumented-source"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Order-topology audit mismatch: {label}")


def ordered(row: dict[str, Any], first: str, second: str) -> bool:
    for plays in grammar.ordered_plays(row).values():
        first_event = next(
            (int(play["event"]) for play in plays if play["id"] == first), None,
        )
        if first_event is not None and any(
            play["id"] == second and int(play["event"]) > first_event
            for play in plays
        ):
            return True
    return False


def co_play(row: dict[str, Any], left: str, right: str) -> bool:
    for plays in grammar.ordered_plays(row).values():
        ids = {str(play["id"]) for play in plays}
        if left in ids and right in ids:
            return True
    return False


def exact_inactive(
    rows: dict[tuple[int, int], dict[str, Any]], protocol: dict[str, Any],
    predicate: Any,
) -> set[int]:
    cohort = protocol["cohort"]
    return {
        policy_index for policy_index in range(cohort["policyCount"])
        if not any(predicate(rows[(policy_index, seed)])
                   for seed in cohort["simulationSeeds"])
    }


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the order-topology summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    immutable = protocol["immutableInputs"]
    require("runner SHA", core.file_sha(Path(__file__)) == immutable["runnerSha256"])
    for path, expected in immutable["helperSha256"].items():
        require(path, core.file_sha(core.ROOT / path) == expected)
    for path, expected in immutable["fileSha256"].items():
        require(path, core.file_sha(core.ROOT / path) == expected)
    head = subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=SOURCE, check=True,
        text=True, capture_output=True,
    ).stdout.strip()
    require("source commit", head == immutable["sourceCommit"])
    for path, expected in immutable["sourceSha256"].items():
        require(path, core.file_sha(SOURCE / path) == expected)

    ledger_before = identity.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
    plan_path = core.CACHE / f"{protocol['trace']['planSha256']}.json"
    output_path = core.CACHE / f"{protocol['trace']['outputSha256']}.json"
    require("trace plan SHA", core.file_sha(plan_path) == protocol["trace"]["planSha256"])
    require("trace output SHA", core.file_sha(output_path) == protocol["trace"]["outputSha256"])
    plan = json.loads(plan_path.read_text())
    output = json.loads(output_path.read_text())
    require("output plan identity", output["planSha256"] == protocol["trace"]["planSha256"])
    require("output probe identity", output["probeSha256"] == protocol["trace"]["probeSha256"])
    require("plan row count", len(plan["rows"]) == protocol["trace"]["planRows"])
    require("output row count", len(output["rows"]) == protocol["trace"]["planRows"])

    cohort = protocol["cohort"]
    per_arm = cohort["policyCount"] * len(cohort["simulationSeeds"])
    start = protocol["trace"]["explicitNullStartIndex"]
    specs = plan["rows"][start:start + per_arm]
    values = output["rows"][start:start + per_arm]
    require("explicit-null rectangle", len(specs) == per_arm and len(values) == per_arm)
    rows: dict[tuple[int, int], dict[str, Any]] = {}
    for spec, row in zip(specs, values):
        require("explicit-null arm", spec.get("arm") == "capture-on-explicit-null")
        require("trace enabled", spec.get("captureTrace") is True)
        require("null explicit", spec.get("explicitNull") is True)
        key = (int(spec["policyIndex"]), int(spec["seed"]))
        require(f"unique row {key}", key not in rows)
        require(f"row seed {key}", int(row["seed"]) == key[1])
        require(f"row aspect {key}", row["aspect"] == cohort["aspect"])
        require(f"row vow {key}", int(row["vow"]) == cohort["vow"])
        rows[key] = row
    require("complete rectangle", len(rows) == per_arm)

    afterimage_order = lambda row: ordered(row, "defend", "guardedStrike")
    reverse_order = lambda row: ordered(row, "guardedStrike", "defend")
    opportunity = lambda row: co_play(row, "defend", "guardedStrike")
    scoreline_order = lambda row: ordered(row, "chisel", "executioner")
    afterimage_active = grammar.policy_set(rows, protocol, afterimage_order)
    afterimage_inactive = exact_inactive(rows, protocol, afterimage_order)
    opportunity_active = grammar.policy_set(rows, protocol, opportunity)
    reverse_active = grammar.policy_set(rows, protocol, reverse_order)
    scoreline_active = grammar.policy_set(rows, protocol, scoreline_order)
    ambiguous = (set(range(cohort["policyCount"]))
                 - afterimage_active - afterimage_inactive)
    viable = {
        policy_index for policy_index in afterimage_active
        if any(afterimage_order(rows[(policy_index, seed)])
               and rows[(policy_index, seed)]["outcome"] == "win"
               for seed in cohort["simulationSeeds"])
    }
    candidate_only = afterimage_active - scoreline_active
    scoreline_only = scoreline_active - afterimage_active
    cross = afterimage_active & scoreline_active
    union = afterimage_active | scoreline_active
    jaccard = len(cross) / len(union) if union else 1.0
    fault_rows = sum(
        row.get("outcome") in ("stall", "error") or bool(row.get("error"))
        for row in rows.values()
    )
    counts = {
        "opportunityPolicies": len(opportunity_active),
        "naturalOrderActivePolicies": len(afterimage_active),
        "exactInactivePolicies": len(afterimage_inactive),
        "ambiguousPolicies": len(ambiguous),
        "viableNaturalOrderPolicies": len(viable),
        "reverseOrderPolicies": len(reverse_active),
        "opportunityNarrowedOutPolicies": len(opportunity_active - afterimage_active),
        "scorelineActivePolicies": len(scoreline_active),
        "candidateOnlyPolicies": len(candidate_only),
        "scorelineOnlyPolicies": len(scoreline_only),
        "crossActivePolicies": len(cross),
        "baselineFaultRows": fault_rows,
    }
    gates = protocol["gates"]
    gate_results = {
        "opportunity": counts["opportunityPolicies"] >= gates["minimumOpportunityPolicies"],
        "active": counts["naturalOrderActivePolicies"] >= gates["minimumActivePolicies"],
        "inactive": counts["exactInactivePolicies"] >= gates["minimumInactivePolicies"],
        "viable": counts["viableNaturalOrderPolicies"] >= gates["minimumViablePolicies"],
        "twoSidedSeparation": (
            counts["candidateOnlyPolicies"] >= gates["minimumCandidateOnlyPolicies"]
            and counts["scorelineOnlyPolicies"] >= gates["minimumScorelineOnlyPolicies"]
            and jaccard <= gates["maximumScorelineJaccard"]
        ),
        "reliability": fault_rows <= gates["maximumBaselineFaultRows"],
    }
    if not gate_results["opportunity"]:
        failure_class = "substrate-opportunity-bottleneck"
    elif not gate_results["active"] or not gate_results["viable"]:
        failure_class = "policy-action-order-bottleneck"
    elif not gate_results["inactive"] or not gate_results["twoSidedSeparation"]:
        failure_class = "nonseparating-order-topology"
    elif not gate_results["reliability"]:
        failure_class = "reliability"
    else:
        failure_class = "none"
    elapsed = time.monotonic() - started
    if elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        boundary = 3
        outcome_class = "inconclusive"
        decision = "record-current-main-order-topology-inconclusive-at-cap"
    elif all(gate_results.values()):
        boundary = 1
        outcome_class = "success"
        decision = "freeze-natural-order-topology-capacity"
    else:
        boundary = 2
        outcome_class = "futility"
        decision = "close-natural-order-topology-freeze-repertoire-bottleneck"
    ledger_after = identity.ledger_identity()
    require("zero-row ledger identity", ledger_after == ledger_before)
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "decisionBoundary": boundary,
        "decision": decision,
        "outcomeClass": outcome_class,
        "failureClass": failure_class,
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "sourceCommit": immutable["sourceCommit"],
        "counts": counts,
        "separation": {"jaccard": jaccard},
        "gateResults": gate_results,
        "policySets": {
            "opportunity": sorted(opportunity_active),
            "naturalOrderActive": sorted(afterimage_active),
            "exactInactive": sorted(afterimage_inactive),
            "ambiguous": sorted(ambiguous),
            "viableNaturalOrder": sorted(viable),
            "reverseOrder": sorted(reverse_active),
            "candidateOnly": sorted(candidate_only),
            "scorelineOnly": sorted(scoreline_only),
        },
        "newSimulatorObservationRows": 0,
        "cachedObservationRowsRead": per_arm,
        "newLedgerRows": 0,
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "protectedSeedRows": ledger_after["protectedSeedRows"],
        "maximumModelContextTokens": 0,
        "wallTimeSeconds": elapsed,
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
