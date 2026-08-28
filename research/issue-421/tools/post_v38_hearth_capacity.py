#!/usr/bin/env python3
"""Zero-row Crown of the Hearth reachability audit for issue #421."""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path
from typing import Any, Callable

import post_v38_cohand_opportunity_decomposition as cohand
import post_v38_competing_structural_options as structural
import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-hearth-capacity-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-hearth-capacity-v1.json"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Hearth capacity mismatch: {label}")


def main_blob(path: str) -> bytes:
    return subprocess.run(
        ["git", "show", f"HEAD:{path}"], cwd=core.SOURCE,
        check=True, capture_output=True,
    ).stdout


def offered(row: dict[str, Any]) -> bool:
    return any("crownOfTheHearth" in choice["offered"]
               for choice in row["trajectory"]["bossRelics"])


def selected(row: dict[str, Any]) -> bool:
    return any(choice["chosen"] == "crownOfTheHearth"
               for choice in row["trajectory"]["bossRelics"])


def acquisition_acts(row: dict[str, Any]) -> list[int]:
    return [index + 1 for index, choice
            in enumerate(row["trajectory"]["bossRelics"])
            if choice["chosen"] == "crownOfTheHearth"]


def post_acquisition_dusk_opportunity(row: dict[str, Any]) -> bool:
    return any(
        int(fight["act"]) > act and fight["result"] == "win"
        and int(fight["shatters"]) > 0
        for act in acquisition_acts(row) for fight in row["fights"]
    )


def assessment(
    rows: dict[tuple[int, int], dict[str, Any]],
    protocol: dict[str, Any],
    predicate: Callable[[dict[str, Any]], bool],
    anchors: dict[str, set[int]],
) -> dict[str, Any]:
    active = structural.robust_set(rows, protocol, predicate)
    inactive = structural.exact_inactive_set(rows, protocol, predicate)
    ambiguous = set(range(protocol["cohort"]["policyCount"])) - active - inactive
    viable = {
        policy for policy in active
        if any(predicate(rows[(policy, seed)])
               and rows[(policy, seed)]["outcome"] == "win"
               for seed in protocol["cohort"]["simulationSeeds"])
    }
    separations = {name: structural.separation(active, anchor)
                   for name, anchor in anchors.items()}
    gates = protocol["gates"]

    def separated(result: dict[str, Any]) -> bool:
        return (result["candidateOnlyPolicies"] >= gates["minimumCandidateOnlyPolicies"]
                and result["anchorOnlyPolicies"] >= gates["minimumAnchorOnlyPolicies"]
                and result["jaccard"] <= gates["maximumAnchorJaccard"])

    gate_results = {
        "active": len(active) >= gates["minimumPotentialActivePolicies"],
        "inactive": len(inactive) >= gates["minimumExactInactivePolicies"],
        "viable": len(viable) >= gates["minimumViablePolicies"],
        "scorelineSeparation": separated(separations["scoreline"]),
        "afterimageSeparation": separated(separations["afterimage"]),
    }
    return {
        "counts": {
            "potentialActivePolicies": len(active),
            "exactInactivePolicies": len(inactive),
            "ambiguousPolicies": len(ambiguous),
            "viablePolicies": len(viable),
        },
        "separation": separations,
        "gateResults": gate_results,
        "eligible": all(gate_results.values()),
        "policySets": {
            "potentialActive": sorted(active),
            "exactInactive": sorted(inactive),
            "ambiguous": sorted(ambiguous),
            "viable": sorted(viable),
        },
    }


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the Hearth capacity summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    immutable = protocol["immutableInputs"]
    require("runner SHA", core.file_sha(Path(__file__)) == immutable["runnerSha256"])
    require("source commit", subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=core.SOURCE, check=True,
        capture_output=True, text=True,
    ).stdout.strip() == immutable["sourceCommit"])
    for path, expected in immutable["sourceSha256"].items():
        require(f"source {path}", core.sha(main_blob(path)) == expected)
    for path, expected in immutable["fileSha256"].items():
        require(path, core.file_sha(core.ROOT / path) == expected)
    capture_path = core.ROOT / immutable["traceCaptureSourcePath"]
    require("trace capture source SHA",
            core.file_sha(capture_path) == immutable["traceCaptureSourceSha256"])
    capture_source = capture_path.read_text()
    capture_append = '_trace_append("bossRelics", {"offered": offered.duplicate(), "chosen": relic})'
    require("boss choice capture", capture_append in capture_source)
    require("capture precedes next act",
            capture_source.index(capture_append)
            < capture_source.index("run.start_next_act(content)",
                                   capture_source.index(capture_append)))

    ledger_before = identity.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
    trace = protocol["trace"]
    plan_path = core.CACHE / f"{trace['planSha256']}.json"
    output_path = core.CACHE / f"{trace['outputSha256']}.json"
    content_path = core.CACHE / f"{trace['contentSha256']}.json"
    for path, expected in [(plan_path, trace["planSha256"]),
                           (output_path, trace["outputSha256"]),
                           (content_path, trace["contentSha256"])]:
        require(f"cache {path.name}", core.file_sha(path) == expected)
    require("live content", core.sha(main_blob("content/full-content.json"))
            == trace["contentSha256"])
    plan = json.loads(plan_path.read_text())
    output = json.loads(output_path.read_text())
    require("output plan identity", output["planSha256"] == trace["planSha256"])
    cohort = protocol["cohort"]
    require("plan rows", len(plan["rows"]) == cohort["rows"])
    require("output rows", len(output["rows"]) == cohort["rows"])
    require("cached-row cap", len(output["rows"])
            <= protocol["budget"]["maximumCachedObservationRowsRead"])
    rows: dict[tuple[int, int], dict[str, Any]] = {}
    fault_rows = 0
    for spec, row in zip(plan["rows"], output["rows"]):
        require("trace arm", spec.get("arm") == "cohand-telemetry-explicit-null")
        require("trace capture", spec.get("captureTrace") is True)
        require("trace explicit null", spec.get("explicitNull") is True)
        key = (int(spec["policyIndex"]), int(spec["seed"]))
        require(f"unique row {key}", key not in rows)
        require(f"row seed {key}", int(row["seed"]) == key[1])
        require(f"boss trace {key}", isinstance(row["trajectory"]["bossRelics"], list))
        rows[key] = row
        fault_rows += int(row.get("outcome") in ("stall", "error")
                          or bool(row.get("error")))
    require("complete rectangle", len(rows) == cohort["rows"])

    anchors = {
        "scoreline": structural.robust_set(
            rows, protocol,
            lambda row: bool(structural.ordered_pairs(
                row, {"chisel"}, {"executioner"})),
        ),
        "afterimage": structural.robust_set(
            rows, protocol,
            lambda row: cohand.simultaneous_cohand(row, "defend", "guardedStrike"),
        ),
    }
    require("Scoreline anchor", len(anchors["scoreline"])
            == protocol["anchors"]["scoreline"]["activePolicies"])
    require("Afterimage anchor", len(anchors["afterimage"])
            == protocol["anchors"]["afterimage"]["activePolicies"])
    assessments = {
        "bossOffer": assessment(rows, protocol, offered, anchors),
        "naturalSelection": assessment(rows, protocol, selected, anchors),
        "postAcquisitionDuskOpportunity": assessment(
            rows, protocol, post_acquisition_dusk_opportunity, anchors,
        ),
    }
    reliability = fault_rows <= protocol["gates"]["maximumBaselineFaultRows"]
    for value in assessments.values():
        value["gateResults"]["reliability"] = reliability
        value["eligible"] = value["eligible"] and reliability

    elapsed = time.monotonic() - started
    offered_ready = assessments["bossOffer"]["eligible"]
    selected_ready = assessments["naturalSelection"]["eligible"]
    post_ready = assessments["postAcquisitionDuskOpportunity"]["eligible"]
    selected_support_failed = not assessments["naturalSelection"]["gateResults"]["active"]
    if elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        boundary, outcome = 3, "inconclusive"
        decision = "record-hearth-capacity-inconclusive-at-cap"
        bottleneck = None
    elif offered_ready and selected_ready and post_ready:
        boundary, outcome = 1, "success"
        decision = "freeze-natural-hearth-route-for-observability-preflight"
        bottleneck = None
    elif offered_ready and selected_support_failed:
        boundary, outcome = 1, "success"
        decision = "freeze-hearth-acquisition-priority-for-identity-preflight"
        bottleneck = "candidate-specific-acquisition-choice"
    else:
        boundary, outcome = 2, "futility"
        decision = "close-natural-hearth-route-without-implementation"
        bottleneck = None

    ledger_after = identity.ledger_identity()
    require("zero-row ledger identity", ledger_after == ledger_before)
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "decisionBoundary": boundary,
        "decision": decision,
        "outcomeClass": outcome,
        "failureClass": bottleneck,
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "assessments": assessments,
        "anchors": {name: sorted(value) for name, value in anchors.items()},
        "sourceBreadth": {
            "selectedAcquisitionActs": sorted({
                act for row in rows.values() for act in acquisition_acts(row)
            }),
            "selectedRows": sum(selected(row) for row in rows.values()),
            "offeredRows": sum(offered(row) for row in rows.values()),
            "postAcquisitionDuskOpportunityRows": sum(
                post_acquisition_dusk_opportunity(row) for row in rows.values()
            ),
        },
        "traceIdentity": {
            "rows": len(rows),
            "identitySummarySha256": trace["identitySummarySha256"],
            "pathRngPolicyResultExact": True,
            "baselineFaultRows": fault_rows,
        },
        "newSimulatorObservationRows": 0,
        "cachedObservationRowsRead": len(rows),
        "newLedgerRows": 0,
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "protectedSeedRows": ledger_after["protectedSeedRows"],
        "maximumModelContextTokens": 0,
        "wallTimeSeconds": elapsed,
        "factorDisposition": protocol["factorDisposition"],
        "authority": protocol["decisionRules"][f"{outcome}Authority"],
    }
    SUMMARY.parent.mkdir(parents=True, exist_ok=True)
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": "PASS",
        "decision": decision,
        "decisionBoundary": boundary,
        "failureClass": bottleneck,
        "newSimulatorObservationRows": 0,
        "summarySha256": core.file_sha(SUMMARY),
    }))


if __name__ == "__main__":
    main()
