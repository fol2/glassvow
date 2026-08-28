#!/usr/bin/env python3
"""Zero-row source audit for unused discrete combat transitions."""

from __future__ import annotations

import json
import re
import subprocess
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v30-unused-discrete-transition-audit-v1.json"
SUMMARY = core.ROOT / "summaries/post-v30-unused-discrete-transition-audit-v1.json"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Unused transition mismatch: {label}")


def main_blob(path: str) -> bytes:
    return subprocess.run(
        ["git", "show", f"HEAD:{path}"], cwd=core.SOURCE,
        check=True, capture_output=True,
    ).stdout


def source_inventory(event_source: str, content: dict[str, Any]) -> dict[str, Any]:
    events = [
        {"constant": constant, "value": value}
        for constant, value in re.findall(
            r'^const ([A-Z_]+): StringName = &"([^"]+)"', event_source, re.MULTILINE
        )
    ]
    draw_cards: list[str] = []
    damage_cards: list[str] = []
    damaging_specials = {
        "leech", "execute", "momentum", "phantom", "devour", "shatterEcho", "emberNova"
    }
    for card_id, card in content["cards"].items():
        effects = card.get("effects", [])
        if any(effect.get("kind") == "draw" for effect in effects):
            draw_cards.append(card_id)
        if any(
            effect.get("kind") == "dmg" or
            (effect.get("kind") == "special" and effect.get("id") in damaging_specials)
            for effect in effects
        ):
            damage_cards.append(card_id)
    return {
        "eventTypes": events,
        "eventTypeCount": len(events),
        "authoredCards": len(content["cards"]),
        "drawCards": sorted(draw_cards),
        "drawCardCount": len(draw_cards),
        "damageCards": sorted(damage_cards),
        "damageCardCount": len(damage_cards),
    }


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite unused-transition summary")
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

    inventory = source_inventory(
        source_text["domain/events/event_types.gd"],
        json.loads(source_text["content/full-content.json"]),
    )
    require("source inventory", inventory == protocol["naturalRouteIdentity"])

    evidence_results: dict[str, dict[str, Any]] = {}
    for name, spec in protocol["priorEvidence"].items():
        path = core.ROOT / spec["path"]
        require(f"{name} SHA", core.file_sha(path) == spec["sha256"])
        decision = json.loads(path.read_text())["decision"]
        require(f"{name} decision", decision == spec["decision"])
        evidence_results[name] = {"sha256": spec["sha256"], "decision": decision}

    coverage = protocol["eventSurfaceCoverage"]
    covered = [event for group in coverage for event in group["events"]]
    expected_events = [row["constant"] for row in inventory["eventTypes"]]
    require("event coverage unique", len(covered) == len(set(covered)))
    require("event coverage complete", sorted(covered) == sorted(expected_events))
    for group in coverage:
        require(f"{group['id']} evidence", all(
            name in evidence_results for name in group["closureEvidence"]
        ))

    selected = [row["id"] for row in protocol["selectedRepresentations"]]
    require("selected representation order", selected == [
        "exact-lethal-terminal-hit",
        "positive-overkill-terminal-hit",
        "draw-pile-reshuffle",
    ])

    ledger_before = identity.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
    elapsed = time.monotonic() - started
    if elapsed > float(protocol["budget"]["maximumWallTimeSeconds"]):
        boundary, decision = 3, "record-unused-discrete-transition-audit-inconclusive-at-cap"
    elif selected:
        boundary, decision = 1, "freeze-terminal-hit-and-reshuffle-for-shared-observation-identity"
    else:
        boundary, decision = 2, "close-unused-discrete-transition-frontier"
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
        "eventSurfaceCoverage": coverage,
        "selectedRepresentations": protocol["selectedRepresentations"] if boundary == 1 else [],
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
        "selectedRepresentations": selected if boundary == 1 else [],
        "summarySha256": core.file_sha(SUMMARY),
        "newSimulatorObservationRows": 0,
    }))


if __name__ == "__main__":
    main()
