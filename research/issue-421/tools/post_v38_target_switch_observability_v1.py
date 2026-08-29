#!/usr/bin/env python3
"""Zero-row target-switch observability audit for issue #421."""

from __future__ import annotations

import json
import re
import subprocess
import time
from pathlib import Path
from typing import Any, Callable

import post_v38_competing_structural_options as options
import post_v38_fanout_capacity_v1 as fanout
import post_v38_knob_identity as ledger
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-target-switch-observability-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-target-switch-observability-v1.json"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Target-switch observability mismatch: {label}")


def first_single_target_pairs(
    row: dict[str, Any], cards: dict[str, Any]
) -> list[tuple[str, str]]:
    pairs: list[tuple[str, str]] = []
    for plays in fanout.multi_enemy_turns(row, cards):
        singles = [card_id for card_id, target in plays if target == "enemy"]
        if len(singles) >= 2:
            pairs.append((singles[0], singles[1]))
    return pairs


def self_check() -> None:
    cards = {
        "first": {"type": "attack", "target": "enemy"},
        "second": {"type": "attack", "target": "enemy"},
        "sweep": {"type": "attack", "target": "allEnemies"},
        "skill": {"type": "skill", "target": "self"},
    }
    row = {
        "fights": [{"enemies": ["a", "b"]}, {"enemies": ["a"]}],
        "trajectory": {
            "turns": [
                {"fight": 0, "event": 1},
                {"fight": 0, "event": 10},
                {"fight": 1, "event": 1},
            ],
            "plays": [
                {"fight": 0, "event": 2, "id": "first"},
                {"fight": 0, "event": 3, "id": "skill"},
                {"fight": 0, "event": 4, "id": "sweep"},
                {"fight": 0, "event": 5, "id": "second"},
                {"fight": 0, "event": 11, "id": "second"},
                {"fight": 1, "event": 2, "id": "first"},
                {"fight": 1, "event": 3, "id": "second"},
            ],
        },
    }
    require("pair self-check", first_single_target_pairs(row, cards) ==
            [("first", "second")])


def robust_set(
    rows: dict[tuple[int, int], dict[str, Any]],
    protocol: dict[str, Any],
    predicate: Callable[[dict[str, Any]], bool],
) -> set[int]:
    return options.robust_set(rows, protocol, predicate)


def assess_surface(
    surface: dict[str, Any], available_events: set[str], gates: dict[str, Any]
) -> dict[str, Any]:
    checks = {
        "existingDeterministicEvents": set(surface["eventInputs"]) <= available_events,
        "observationOnly": surface["observationOnly"] is True,
        "noNewGameplayHook": surface["newGameplayHookCount"] == 0,
        "existingBranchLimit": surface["existingEventBranchCount"] <=
        gates["maximumExistingEventBranches"],
        "containerLimit": len(surface["containers"]) <= gates["maximumTraceContainers"],
        "scalarSchemaLimit": max(
            (len(fields) for fields in surface["containers"].values()), default=0
        ) <= gates["maximumScalarFieldsPerContainer"],
        "fixedScalarSchema": surface["fixedScalarSchema"] is True,
        "targetIdentity": surface["targetIdentity"] is True,
        "forcedSwitchDisambiguation": surface["forcedSwitchDisambiguation"] is True,
        "identityAnchor": surface["identityAnchorAvailable"] is True,
    }
    return {"id": surface["id"], "eligible": all(checks.values()),
            "checks": checks, "surface": surface}


def git_blob(repository: Path, ref: str, path: str) -> bytes:
    return subprocess.run(
        ["git", "show", f"{ref}:{path}"], cwd=repository, check=True,
        capture_output=True,
    ).stdout


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the target-switch observability summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    immutable = protocol["immutableInputs"]
    require("runner SHA", core.file_sha(Path(__file__)) == immutable["runnerSha256"])
    self_check()
    require("task capsule SHA", core.file_sha(core.ROOT / immutable["taskCapsulePath"]) ==
            immutable["taskCapsuleSha256"])
    for path, expected in immutable["researchFileSha256"].items():
        require(f"research file {path}", core.file_sha(core.ROOT / path) == expected)

    repository = Path(immutable["repositoryPath"])
    for ref, expected in immutable["repositoryRefs"].items():
        actual = subprocess.run(
            ["git", "rev-parse", ref], cwd=repository, check=True,
            text=True, capture_output=True,
        ).stdout.strip()
        require(f"repository ref {ref}", actual == expected)
    source: dict[str, str] = {}
    for path, expected in immutable["sourceSha256"].items():
        blob = git_blob(repository, immutable["sourceHead"], path)
        require(f"source {path}", core.sha(blob) == expected)
        source[path] = blob.decode()

    trace_source = Path(immutable["traceSourcePath"])
    head = subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=trace_source, check=True,
        text=True, capture_output=True,
    ).stdout.strip()
    require("trace source head", head == immutable["traceSourceHead"])
    for path, expected in immutable["traceSourceSha256"].items():
        require(f"trace source {path}", core.file_sha(trace_source / path) == expected)

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
    cohort = protocol["cohort"]
    require("plan rows", len(plan["rows"]) == cohort["rows"])
    require("output rows", len(output["rows"]) == cohort["rows"])
    require("cached-row ceiling", len(output["rows"]) <=
            protocol["budget"]["maximumCachedObservationRowsRead"])

    rows: dict[tuple[int, int], dict[str, Any]] = {}
    policy_snapshots: dict[int, set[str]] = {}
    trace_target_fields = 0
    trace_death_containers = 0
    for spec, row in zip(plan["rows"], output["rows"]):
        require("trace arm", spec.get("arm") == "cohand-telemetry-explicit-null")
        require("trace capture", spec.get("captureTrace") is True)
        require("trace explicit null", spec.get("explicitNull") is True)
        key = (int(spec["policyIndex"]), int(spec["seed"]))
        require(f"unique row {key}", key not in rows)
        require(f"seed {key}", int(row["seed"]) == key[1])
        rows[key] = row
        policy_snapshots.setdefault(key[0], set()).add(core.canonical(row["policy"]))
        trace_target_fields += sum("targetIdx" in event
                                   for event in row["trajectory"]["plays"])
        trace_death_containers += int("dies" in row["trajectory"])
    require("complete rectangle", len(rows) == cohort["rows"])
    require("one policy snapshot per identity",
            len(policy_snapshots) == cohort["policyCount"] and
            all(len(snapshots) == 1 for snapshots in policy_snapshots.values()))

    combat = source["domain/rules/combat.gd"]
    pilot = source["tools/balance_pilot.gd"]
    trace_sim = (trace_source / "tools/balance_sim.gd").read_text()
    trace_probe = (trace_source / "tools/research_421_null_harness_probe.gd").read_text()
    target_function = re.search(
        r"static func _target\(.*?(?=\nstatic func _incoming\()", pilot, re.DOTALL
    )
    source_census = {
        "playTargetIdxEmitSites": combat.count('"targetIdx": target_idx'),
        "dieIdxEmitSites": combat.count(
            'queue.append({"t": EventTypes.DIE, "idx": e.idx})'
        ),
        "tracePlayAppendSites": trace_sim.count('_trace_append("plays"'),
        "traceTargetIdxFields": trace_sim.count('"targetIdx"'),
        "traceDieContainers": trace_sim.count('_trace_append("dies"'),
        "cachedTargetIdxFields": trace_target_fields,
        "cachedDeathContainers": trace_death_containers,
        "targetSelectorFound": target_function is not None,
        "targetSelectorRandomTokens": 0 if target_function is None else len(
            re.findall(r"\b(?:rng|random|Rng)\b", target_function.group(0))
        ),
        "probeDeterministicModeSites": trace_probe.count(
            "false, false, {}, null, false, research, trace"
        ),
    }
    available_events: set[str] = set()
    if source_census["playTargetIdxEmitSites"] == 1:
        available_events.add("PLAY.targetIdx")
    if source_census["dieIdxEmitSites"] == 1:
        available_events.add("DIE.idx")
    surfaces = [assess_surface(surface, available_events, protocol["surfaceGates"])
                for surface in protocol["observationSurfaces"]]
    eligible_surfaces = [surface for surface in surfaces if surface["eligible"]]
    selected_surface = (eligible_surfaces[0]["id"]
                        if len(eligible_surfaces) == 1 else None)

    cards = content["cards"]
    predicate = lambda row: bool(first_single_target_pairs(row, cards))
    active = robust_set(rows, protocol, predicate)
    viable = {
        policy for policy in active
        if any(predicate(rows[(policy, seed)]) and
               rows[(policy, seed)].get("outcome") == "win"
               for seed in cohort["simulationSeeds"])
    }
    all_pairs = [pair for row in rows.values()
                 for pair in first_single_target_pairs(row, cards)]
    first_cards = {pair[0] for pair in all_pairs}
    second_cards = {pair[1] for pair in all_pairs}
    exact_pairs = set(all_pairs)
    scoreline = robust_set(
        rows, protocol,
        lambda row: bool(options.ordered_pairs(row, {"chisel"}, {"executioner"})),
    )
    afterimage = robust_set(
        rows, protocol,
        lambda row: options.cohand.simultaneous_cohand(row, "defend", "guardedStrike"),
    )
    require("Scoreline anchor", len(scoreline) ==
            protocol["anchors"]["scoreline"]["activePolicies"])
    require("Afterimage anchor", len(afterimage) ==
            protocol["anchors"]["afterimage"]["activePolicies"])
    fault_rows = sum(
        row.get("outcome") in ("stall", "error") or bool(row.get("error"))
        for row in rows.values()
    )
    gates = protocol["contextGates"]
    checks = {
        "sourcePlayTarget": source_census["playTargetIdxEmitSites"] == 1,
        "sourceDeathIdentity": source_census["dieIdxEmitSites"] == 1,
        "frozenTraceOmission": (
            source_census["tracePlayAppendSites"] == 1
            and source_census["traceTargetIdxFields"] == 0
            and source_census["traceDieContainers"] == 0
            and source_census["cachedTargetIdxFields"] == 0
            and source_census["cachedDeathContainers"] == 0
        ),
        "deterministicTargetSelector": (
            source_census["targetSelectorFound"]
            and source_census["targetSelectorRandomTokens"] == 0
            and source_census["probeDeterministicModeSites"] == 1
        ),
        "uniqueObservationSurface": selected_surface ==
        protocol["selectionRule"]["requiredSurfaceId"],
        "activeContext": len(active) >= gates["minimumActivePolicies"],
        "viableContext": len(viable) >= gates["minimumViablePolicies"],
        "firstCardBreadth": len(first_cards) >= gates["minimumDistinctFirstCards"],
        "secondCardBreadth": len(second_cards) >= gates["minimumDistinctSecondCards"],
        "pairBreadth": len(exact_pairs) >= gates["minimumDistinctPairs"],
        "reliability": fault_rows <= gates["maximumBaselineFaultRows"],
        "closedFamilyEventUnit": (
            all(cards[card_id].get("type") == "attack" and
                cards[card_id].get("target") == "enemy"
                for pair in exact_pairs for card_id in pair)
            and len(first_cards) >= gates["minimumDistinctFirstCards"]
            and len(second_cards) >= gates["minimumDistinctSecondCards"]
        ),
    }
    elapsed = time.monotonic() - started
    if elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        outcome_class = "inconclusive"
        boundary = 3
        decision = "record-target-switch-observability-inconclusive-at-cap"
    elif all(checks.values()):
        outcome_class = "success"
        boundary = 1
        decision = "freeze-target-and-death-trace-identity-preflight"
    else:
        outcome_class = "futility"
        boundary = 2
        decision = "close-target-switch-observability-at-zero-row-gate"
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
        "sourceCensus": source_census,
        "surfaceAssessments": surfaces,
        "selectedSurface": selected_surface,
        "counts": {
            "activeContextPolicies": len(active),
            "viableContextPolicies": len(viable),
            "qualifyingRows": sum(predicate(row) for row in rows.values()),
            "qualifyingTurns": len(all_pairs),
            "distinctFirstCards": len(first_cards),
            "distinctSecondCards": len(second_cards),
            "distinctPairs": len(exact_pairs),
            "baselineFaultRows": fault_rows,
        },
        "sourceBreadth": {
            "firstCards": sorted(first_cards),
            "secondCards": sorted(second_cards),
        },
        "separationAnchors": {
            "scoreline": options.separation(active, scoreline),
            "afterimage": options.separation(active, afterimage),
        },
        "policySets": {
            "activeContext": sorted(active),
            "viableContext": sorted(viable),
        },
        "cachedObservationRowsRead": len(rows),
        "newSimulatorObservationRows": 0,
        "newLedgerRows": 0,
        "protectedSeedRows": ledger_after["protectedSeedRows"],
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "elapsedSeconds": round(elapsed, 6),
        "claimBoundary": protocol["claimBoundary"],
        "authority": protocol["decisionRules"][f"{outcome_class}Authority"],
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": outcome_class.upper(),
        "decision": decision,
        "selectedSurface": selected_surface,
        "activeContextPolicies": len(active),
        "newSimulatorObservationRows": 0,
    }))


if __name__ == "__main__":
    main()
