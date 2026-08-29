#!/usr/bin/env python3
"""Zero-row scoped RESHUFFLE observability eligibility audit for issue #421."""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as ledger
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-reshuffle-observability-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-reshuffle-observability-v1.json"
TARGET_SOURCE = core.ROOT / "target-switch-observation-v1-source"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Reshuffle observability mismatch: {label}")


def context_counts(
    specs: list[dict[str, Any]], rows: list[dict[str, Any]], policy_count: int,
) -> dict[str, Any]:
    policies: set[int] = set()
    viable: set[int] = set()
    snapshots: dict[int, set[str]] = {}
    totals = {"turns": 0, "draws": 0, "plays": 0}
    faults = 0
    for spec, row in zip(specs, rows):
        policy = int(spec["policyIndex"])
        policies.add(policy)
        snapshots.setdefault(policy, set()).add(core.canonical(row["policy"]))
        if row.get("outcome") == "win":
            viable.add(policy)
        if row.get("outcome") in ("stall", "error") or bool(row.get("error")):
            faults += 1
        for field in totals:
            totals[field] += len(row["trajectory"][field])
    return {
        "policies": len(policies),
        "viablePolicies": len(viable),
        "policySnapshotFaults": sum(len(values) != 1 for values in snapshots.values())
        + (policy_count - len(snapshots)),
        "baselineFaultRows": faults,
        **totals,
    }


def self_check() -> None:
    specs = [{"policyIndex": 0}, {"policyIndex": 1}]
    rows = [
        {"policy": {"x": 1}, "outcome": "win", "error": "",
         "trajectory": {"turns": [1], "draws": [1, 2], "plays": [1]}},
        {"policy": {"x": 2}, "outcome": "loss", "error": "",
         "trajectory": {"turns": [1, 2], "draws": [1], "plays": [1, 2]}},
    ]
    counts = context_counts(specs, rows, 2)
    require("self-check policies", counts["policies"] == 2)
    require("self-check viable", counts["viablePolicies"] == 1)
    require("self-check events", counts["turns"] == 3 and counts["draws"] == 3
            and counts["plays"] == 3)
    require("self-check faults", counts["policySnapshotFaults"] == 0)


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the reshuffle observability summary")
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
    source_text: dict[str, str] = {}
    for path, expected in immutable["sourceSha256"].items():
        blob = subprocess.run(
            ["git", "show", f"{immutable['sourceHead']}:{path}"], cwd=repository,
            check=True, capture_output=True,
        ).stdout
        require(f"source {path}", core.sha(blob) == expected)
        source_text[path] = blob.decode()
    for assertion in protocol["sourceAssertions"]:
        require(
            f"source assertion {assertion['id']}",
            assertion["contains"] in source_text[assertion["path"]],
        )

    target_head = subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=TARGET_SOURCE, check=True,
        text=True, capture_output=True,
    ).stdout.strip()
    require("target observation source head", target_head == immutable["targetObservationHead"])
    for path, expected in immutable["targetObservationSha256"].items():
        require(f"target observation {path}", core.file_sha(TARGET_SOURCE / path) == expected)
    patch = subprocess.run(
        ["git", "diff", "--cached", "--binary"], cwd=TARGET_SOURCE,
        check=True, capture_output=True,
    ).stdout
    require("target observation patch SHA", core.sha(patch) == immutable["targetObservationPatchSha256"])
    target_sim = (TARGET_SOURCE / "tools/balance_sim.gd").read_text()

    old_summary = json.loads(
        (core.ROOT / protocol["priorQuarantine"]["summaryPath"]).read_text()
    )
    ledger_before = ledger.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
    trace = protocol["trace"]
    plan_path = core.CACHE / f"{trace['planSha256']}.json"
    output_path = core.CACHE / f"{trace['outputSha256']}.json"
    require("plan SHA", core.file_sha(plan_path) == trace["planSha256"])
    require("output SHA", core.file_sha(output_path) == trace["outputSha256"])
    plan = json.loads(plan_path.read_text())
    output = json.loads(output_path.read_text())
    require("plan arm", plan["arm"] == "target-death-trace-explicit-null")
    require("plan protocol identity", plan["protocolSha256"] == trace["identityProtocolSha256"])
    require("output plan identity", output["planSha256"] == trace["planSha256"])
    require("row identity", len(plan["rows"]) == len(output["rows"]) == protocol["cohort"]["rows"])
    counts = context_counts(
        plan["rows"], output["rows"], protocol["cohort"]["policyCount"],
    )
    gates = protocol["gates"]
    checks = {
        "stableEventIdentity": (
            'const RESHUFFLE: StringName = &"reshuffle"'
            in source_text["domain/events/event_types.gd"]
        ),
        "exactZoneBoundary": (
            "if cb.draw.is_empty():" in source_text["domain/rules/combat.gd"]
            and "if cb.discard.is_empty():" in source_text["domain/rules/combat.gd"]
            and "cb.draw = cb.discard" in source_text["domain/rules/combat.gd"]
            and "cb.discard = []" in source_text["domain/rules/combat.gd"]
        ),
        "seededShufflePrecedesEvent": (
            source_text["domain/rules/combat.gd"].index("_shuffle_cards(run.rng, cb.draw)")
            < source_text["domain/rules/combat.gd"].index(
                'cb.queue.append({"t": EventTypes.RESHUFFLE, "n": count})'
            )
        ),
        "positiveCountPayload": (
            "var count: int = cb.discard.size()" in source_text["domain/rules/combat.gd"]
            and 'cb.queue.append({"t": EventTypes.RESHUFFLE, "n": count})'
            in source_text["domain/rules/combat.gd"]
        ),
        "observationCurrentlyAbsent": (
            '"reshuffles"' not in target_sim and 'kind == "reshuffle"' not in target_sim
        ),
        "minimalExistingQueueProjection": (
            'for event_v: Variant in game.cb.queue:' in target_sim
            and 'var event_index: int = 0' in target_sim
            and 'event_index += 1' in target_sim
        ),
        "priorAuditRemainsInconclusive": (
            old_summary["outcomeClass"] == "inconclusive"
            and old_summary["decision"] == "record-unused-discrete-transition-audit-inconclusive-at-cap"
            and old_summary["selectedRepresentations"] == []
        ),
        "singleSelectedSurface": protocol["selectedSurface"] == {
            "event": "RESHUFFLE", "fields": ["fight", "event", "n"]
        },
        "completePolicies": counts["policies"] == protocol["cohort"]["policyCount"],
        "policyIdentity": counts["policySnapshotFaults"] == 0,
        "viableContext": counts["viablePolicies"] >= gates["minimumViablePolicies"],
        "turnContext": counts["turns"] >= gates["minimumTurnEvents"],
        "drawContext": counts["draws"] >= gates["minimumDrawEvents"],
        "playContext": counts["plays"] >= gates["minimumPlayEvents"],
        "reliability": counts["baselineFaultRows"] <= gates["maximumBaselineFaultRows"],
    }
    elapsed = time.monotonic() - started
    if elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        outcome_class = "inconclusive"
        boundary = 3
        decision = "record-reshuffle-observability-inconclusive-at-cap"
    elif all(checks.values()):
        outcome_class = "success"
        boundary = 1
        decision = "freeze-reshuffle-trace-surface-for-identity"
    else:
        outcome_class = "futility"
        boundary = 2
        decision = "close-reshuffle-observation-surface"
    ledger_after = ledger.ledger_identity()
    require("zero-row ledger identity", ledger_after == ledger_before)
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "outcomeClass": outcome_class,
        "decisionBoundary": boundary,
        "decision": decision,
        "selectedSurface": protocol["selectedSurface"] if outcome_class == "success" else None,
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "checks": checks,
        "context": counts,
        "priorQuarantine": protocol["priorQuarantine"],
        "cachedObservationRowsRead": len(output["rows"]),
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
        "selectedSurface": summary["selectedSurface"],
        "newSimulatorObservationRows": 0,
    }))


if __name__ == "__main__":
    main()
