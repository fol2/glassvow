#!/usr/bin/env python3
"""Zero-row source audit for the enemy-Ward Attack transition frontier."""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v30-enemy-ward-transition-audit-v1.json"
SUMMARY = core.ROOT / "summaries/post-v30-enemy-ward-transition-audit-v1.json"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Enemy-Ward transition mismatch: {label}")


def main_blob(path: str) -> bytes:
    return subprocess.run(
        ["git", "show", f"HEAD:{path}"], cwd=core.SOURCE,
        check=True, capture_output=True,
    ).stdout


def classify(pre_block: int, damage: int) -> str:
    blocked = min(pre_block, damage)
    remaining = pre_block - blocked
    loss = damage - blocked
    if pre_block == 0:
        return "blood-without-ward" if loss > 0 else "no-ward-no-blood"
    if remaining > 0:
        return "ward-retained-no-blood"
    return "ward-break-with-blood" if loss > 0 else "ward-break-without-blood"


def block_inventory(content: dict[str, Any]) -> dict[str, Any]:
    rows = [
        {
            "enemy": enemy_id,
            "move": move_id,
            "block": move["block"],
            "intent": move.get("intent"),
        }
        for enemy_id, enemy in content["enemies"].items()
        for move_id, move in enemy.get("moves", {}).items()
        if move.get("block", 0) > 0
    ]
    capable = {row["enemy"] for row in rows}
    formations = [
        {"tier": tier, "enemies": formation}
        for act in content["encounters"]
        for tier, tier_formations in act.items()
        for formation in tier_formations
    ]
    reachable = [
        row for row in formations if any(enemy in capable for enemy in row["enemies"])
    ]
    by_tier = {
        tier: sum(row["tier"] == tier for row in reachable)
        for tier in sorted({row["tier"] for row in formations})
    }
    return {
        "positiveBlockMoves": len(rows),
        "blockCapableEnemies": len(capable),
        "blockValues": sorted({row["block"] for row in rows}),
        "formations": len(formations),
        "blockCapableFormations": len(reachable),
        "blockFreeFormations": len(formations) - len(reachable),
        "blockCapableFormationsByTier": by_tier,
        "allBlockCapableEnemiesReachable": {
            enemy for row in reachable for enemy in row["enemies"] if enemy in capable
        } == capable,
    }


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the enemy-Ward transition summary")
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

    inventory = block_inventory(json.loads(source_text["content/full-content.json"]))
    require("natural route identity", inventory == protocol["naturalRouteIdentity"])

    evidence_results: dict[str, dict[str, Any]] = {}
    for name, spec in protocol["priorEvidence"].items():
        path = core.ROOT / spec["path"]
        require(f"{name} SHA", core.file_sha(path) == spec["sha256"])
        decision = json.loads(path.read_text())["decision"]
        require(f"{name} decision", decision == spec["decision"])
        evidence_results[name] = {"sha256": spec["sha256"], "decision": decision}

    partition = protocol["attackOutcomePartition"]
    expected_ids = [
        "blood-without-ward",
        "ward-break-with-blood",
        "ward-break-without-blood",
        "ward-retained-no-blood",
        "no-ward-no-blood",
    ]
    require("partition order", [row["id"] for row in partition] == expected_ids)
    for row in partition:
        require(f"{row['id']} evidence", all(
            name in evidence_results for name in row["closureEvidence"]
        ))
    witnesses = {
        classify(pre_block, damage)
        for pre_block in range(4)
        for damage in range(5)
    }
    require("partition exhaustive", witnesses == set(expected_ids))
    selected = [row["id"] for row in partition if row["disposition"] == "uncovered"]
    require("selected primitive identity", selected == [protocol["selectedPrimitive"]["id"]])

    ledger_before = identity.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
    elapsed = time.monotonic() - started
    if elapsed > float(protocol["budget"]["maximumWallTimeSeconds"]):
        boundary, decision = 3, "record-enemy-ward-transition-audit-inconclusive-at-cap"
    elif len(selected) == 1:
        boundary, decision = 1, "freeze-ward-break-without-blood-for-identity-preflight"
    else:
        boundary, decision = 2, "close-enemy-ward-transition-frontier"
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
        "attackOutcomePartition": partition,
        "selectedPrimitive": protocol["selectedPrimitive"] if boundary == 1 else None,
        "naturalRouteIdentity": inventory,
        "evidenceResults": evidence_results,
        "sourceIdentity": {
            "commit": immutable["sourceCommit"],
            "sha256": immutable["sourceSha256"],
            "taskCapsuleSha256": immutable["taskCapsuleSha256"],
        },
        "traceFilesRead": 0,
        "cacheFilesRead": 0,
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
        "selectedPrimitive": selected[0] if boundary == 1 else None,
        "summarySha256": core.file_sha(SUMMARY),
        "newSimulatorObservationRows": 0,
    }))


if __name__ == "__main__":
    main()
