#!/usr/bin/env python3
"""Zero-row source audit for per-card Shatter target topology."""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v30-shatter-card-topology-audit-v1.json"
SUMMARY = core.ROOT / "summaries/post-v30-shatter-card-topology-audit-v1.json"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Shatter card-topology mismatch: {label}")


def main_blob(path: str) -> bytes:
    return subprocess.run(
        ["git", "show", f"HEAD:{path}"], cwd=core.SOURCE,
        check=True, capture_output=True,
    ).stdout


def source_inventory(content: dict[str, Any]) -> dict[str, Any]:
    carriers: list[dict[str, Any]] = []
    for card_id, card in content["cards"].items():
        if card.get("target") != "allEnemies":
            continue
        effects = card.get("effects", [])
        if not any(effect.get("kind") in {"dmg", "chip"} for effect in effects):
            continue
        carriers.append({
            "id": card_id,
            "name": card["name"],
            "type": card["type"],
            "rarity": card["rarity"],
            "effectKinds": [effect["kind"] for effect in effects],
        })
    formations = [
        formation
        for act in content["encounters"]
        for tier_formations in act.values()
        for formation in tier_formations
    ]
    return {
        "multiTargetShatterCapableCards": carriers,
        "carrierCount": len(carriers),
        "formations": len(formations),
        "multiEnemyFormations": sum(len(row) > 1 for row in formations),
        "singleEnemyFormations": sum(len(row) == 1 for row in formations),
        "maximumEnemies": max(map(len, formations)),
    }


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite Shatter card-topology summary")
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

    partition = protocol["cardShatterTopologyPartition"]
    require("partition order", [row["id"] for row in partition] == [
        "no-shatter-event",
        "one-event-one-target",
        "multiple-events-one-target",
        "multiple-events-multiple-targets",
    ])
    for row in partition:
        require(f"{row['id']} evidence", all(
            name in evidence_results for name in row["closureEvidence"]
        ))
    selected = [row["id"] for row in partition if row["disposition"] == "uncovered"]
    require("selected topology identity", selected == [protocol["selectedRepresentation"]["id"]])

    ledger_before = identity.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
    elapsed = time.monotonic() - started
    if elapsed > float(protocol["budget"]["maximumWallTimeSeconds"]):
        boundary, decision = 3, "record-shatter-card-topology-inconclusive-at-cap"
    elif len(selected) == 1:
        boundary, decision = 1, "freeze-multi-enemy-card-shatter-for-capacity-preregistration"
    else:
        boundary, decision = 2, "close-shatter-card-topology-frontier"
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
        "cardShatterTopologyPartition": partition,
        "selectedRepresentation": protocol["selectedRepresentation"] if boundary == 1 else None,
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
        "selectedRepresentation": selected[0] if boundary == 1 else None,
        "summarySha256": core.file_sha(SUMMARY),
        "newSimulatorObservationRows": 0,
    }))


if __name__ == "__main__":
    main()
