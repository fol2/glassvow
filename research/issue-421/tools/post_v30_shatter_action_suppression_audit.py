#!/usr/bin/env python3
"""Zero-row source audit for Shatter-triggered enemy-action suppression."""

from __future__ import annotations

from collections import Counter
import json
import subprocess
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v30-shatter-action-suppression-audit-v1.json"
SUMMARY = core.ROOT / "summaries/post-v30-shatter-action-suppression-audit-v1.json"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Shatter action-suppression mismatch: {label}")


def main_blob(path: str) -> bytes:
    return subprocess.run(
        ["git", "show", f"HEAD:{path}"], cwd=core.SOURCE,
        check=True, capture_output=True,
    ).stdout


def source_inventory(content: dict[str, Any]) -> dict[str, Any]:
    signatures: Counter[str] = Counter()
    damaging_labels: Counter[str] = Counter()
    non_damaging_labels: Counter[str] = Counter()
    damaging_only: list[str] = []
    mixed: list[str] = []
    damaging_capable: set[str] = set()
    move_count = 0
    damaging_count = 0
    for enemy_id, enemy in content["enemies"].items():
        moves = list(enemy.get("moves", {}).values())
        move_count += len(moves)
        has_damaging = any("dmg" in move for move in moves)
        has_non_damaging = any("dmg" not in move for move in moves)
        if has_damaging:
            damaging_capable.add(enemy_id)
            (mixed if has_non_damaging else damaging_only).append(enemy_id)
        for move in moves:
            damaging = "dmg" in move
            damaging_count += int(damaging)
            label = str(move.get("intent", ""))
            (damaging_labels if damaging else non_damaging_labels)[label] += 1
            keys = sorted(key for key in move if key not in {"intent", "name"})
            signatures[("damaging:" if damaging else "non-damaging:") + "+".join(keys)] += 1
    formations = [
        formation
        for act in content["encounters"]
        for tier_formations in act.values()
        for formation in tier_formations
    ]
    return {
        "enemies": len(content["enemies"]),
        "moveDefinitions": move_count,
        "damagingMoveDefinitions": damaging_count,
        "nonDamagingMoveDefinitions": move_count - damaging_count,
        "damagingIntentLabels": dict(sorted(damaging_labels.items())),
        "nonDamagingIntentLabels": dict(sorted(non_damaging_labels.items())),
        "effectSignatures": dict(sorted(signatures.items())),
        "enemiesWithDamagingMove": len(damaging_capable),
        "enemiesWithOnlyDamagingMoves": sorted(damaging_only),
        "enemiesWithMixedMoves": sorted(mixed),
        "formations": len(formations),
        "formationsWithDamagingCapableEnemy": sum(
            any(enemy_id in damaging_capable for enemy_id in formation)
            for formation in formations
        ),
        "maximumEnemies": max(map(len, formations)),
    }


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite Shatter action-suppression summary")
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

    source_text: dict[str, str] = {}
    for path, expected_sha in immutable["sourceSha256"].items():
        blob = main_blob(path)
        require(f"{path} SHA", core.sha(blob) == expected_sha)
        source_text[path] = blob.decode()
    for assertion in protocol["sourceAssertions"]:
        require(assertion["id"], assertion["contains"] in source_text[assertion["path"]])

    inventory = source_inventory(json.loads(source_text["content/full-content.json"]))
    require("source inventory", inventory == protocol["naturalRouteIdentity"])

    evidence_results: dict[str, dict[str, Any]] = {}
    for name, spec in protocol["priorEvidence"].items():
        path = core.ROOT / spec["path"]
        require(f"{name} SHA", core.file_sha(path) == spec["sha256"])
        decision = json.loads(path.read_text())["decision"]
        require(f"{name} decision", decision == spec["decision"])
        evidence_results[name] = {"sha256": spec["sha256"], "decision": decision}

    partition = protocol["actionSuppressionPartition"]
    require("partition order", [row["id"] for row in partition] == [
        "no-enemy-phase-stagger-consumption",
        "additional-shatter-while-already-staggered",
        "player-phase-stagger-reader",
        "enemy-phase-non-damaging-intent-skip",
        "enemy-phase-damaging-intent-skip",
        "post-skip-status-ticks",
    ])
    for row in partition:
        require(f"{row['id']} evidence", all(
            name in evidence_results for name in row["closureEvidence"]
        ))
    selected = [row["id"] for row in partition if row["disposition"] == "uncovered"]
    require("selected relation identity", selected == [protocol["selectedRelation"]["id"]])

    ledger_before = identity.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
    elapsed = time.monotonic() - started
    if elapsed > float(protocol["budget"]["maximumWallTimeSeconds"]):
        boundary, decision = 3, "record-shatter-action-suppression-inconclusive-at-cap"
    elif len(selected) == 1:
        boundary, decision = 1, "freeze-damaging-intent-shatter-suppression-for-capacity-preregistration"
    else:
        boundary, decision = 2, "close-shatter-action-suppression-frontier"
    ledger_after = identity.ledger_identity()
    require("zero-row ledger identity", ledger_after == ledger_before)
    authority_key = {1: "successAuthority", 2: "futilityAuthority",
                     3: "inconclusiveAuthority"}[boundary]
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "decisionBoundary": boundary,
        "decision": decision,
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "frontierScope": protocol["frontierScope"],
        "actionSuppressionPartition": partition,
        "selectedRelation": protocol["selectedRelation"] if boundary == 1 else None,
        "naturalRouteIdentity": inventory,
        "evidenceResults": evidence_results,
        "sourceIdentity": {
            "commit": immutable["sourceCommit"],
            "sha256": immutable["sourceSha256"],
            "taskCapsuleSha256": immutable["taskCapsuleSha256"],
        },
        "traceFilesRead": 0,
        "cacheFilesRead": 0,
        "supportMetricsInspected": 0,
        "newSimulatorObservationRows": 0,
        "newLedgerRows": 0,
        "protectedSeedRows": ledger_after["protectedSeedRows"],
        "maximumModelContextTokens": 0,
        "wallTimeSeconds": elapsed,
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "authority": protocol["decisionRules"][authority_key],
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": "PASS",
        "decisionBoundary": boundary,
        "decision": decision,
        "selectedRelation": selected[0] if boundary == 1 else None,
        "summarySha256": core.file_sha(SUMMARY),
        "newSimulatorObservationRows": 0,
    }))


if __name__ == "__main__":
    main()
