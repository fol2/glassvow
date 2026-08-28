#!/usr/bin/env python3
"""Zero-row minimum-change design audit for one new Dusk mediator."""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v30-minimum-new-mediator-design-audit-v1.json"
SUMMARY = core.ROOT / "summaries/post-v30-minimum-new-mediator-design-audit-v1.json"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Minimum-new-mediator design mismatch: {label}")


def main_blob(path: str) -> bytes:
    return subprocess.run(
        ["git", "show", f"HEAD:{path}"], cwd=core.SOURCE,
        check=True, capture_output=True,
    ).stdout


def candidate_effects(
    cards: dict[str, Any], kinds: list[str]
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for card_id, card in cards.items():
        for upgrade, effects in (
            (False, card.get("effects", [])),
            (True, card.get("up", {}).get("effects", card.get("effects", []))),
        ):
            for effect in effects:
                if effect.get("kind") in kinds or effect.get("aspect") is not None:
                    rows.append({"cardId": card_id, "upgraded": upgrade,
                                 "effect": effect})
    return rows


def eligible(design: dict[str, Any]) -> bool:
    gates = design["attributes"]
    return (
        design["priorClosureAliases"] == []
        and gates["reusesExistingAddCardHandler"]
        and gates["privatePackageMediator"]
        and gates["duskOnlyMechanism"]
        and gates["deterministicProducerPlacement"]
        and gates["deterministicConsumer"]
        and gates["naturalMediatorCost"]
        and gates["noRng"]
        and gates["noSaveState"]
        and gates["gameplayHookCount"] <= 1
        and gates["currentCarrierCount"] == 0
    )


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite minimum-new-mediator summary")
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

    blobs: dict[str, bytes] = {}
    for path, expected_sha in immutable["sourceSha256"].items():
        blob = main_blob(path)
        require(f"{path} SHA", core.sha(blob) == expected_sha)
        blobs[path] = blob
    content = json.loads(blobs["content/full-content.json"])
    require("no current authored candidate-effect carrier",
            candidate_effects(content["cards"], protocol["candidateEffectKinds"]) ==
            protocol["currentCandidateEffectCarriers"])
    for card_id, expected in protocol["sourceCardAnchors"].items():
        require(f"source card anchor {card_id}", content["cards"][card_id] == expected)

    combat = blobs["domain/rules/combat.gd"].decode()
    for label, text in protocol["sourceAssertions"].items():
        require(label, text in combat)
    require("producer removal precedes effects",
            combat.index(protocol["sourceAssertions"]["producer leaves hand"]) <
            combat.index(protocol["sourceAssertions"]["effect loop"]) <
            combat.index(protocol["sourceAssertions"]["addCard handler"]))

    evidence_results: dict[str, dict[str, Any]] = {}
    for name, spec in protocol["priorEvidence"].items():
        path = core.ROOT / spec["path"]
        require(f"{name} SHA", core.file_sha(path) == spec["sha256"])
        decision = json.loads(path.read_text())["decision"]
        require(f"{name} decision", decision == spec["decision"])
        evidence_results[name] = {"sha256": spec["sha256"], "decision": decision}

    assessments = [
        {"id": design["id"], "eligible": eligible(design),
         "attributes": design["attributes"],
         "priorClosureAliases": design["priorClosureAliases"]}
        for design in protocol["designs"]
    ]
    selected = [row["id"] for row in assessments if row["eligible"]]
    require("frozen selected set", selected == protocol["selectedDesigns"])

    ledger_before = identity.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
    elapsed = time.monotonic() - started
    if elapsed > float(protocol["budget"]["maximumWallTimeSeconds"]):
        boundary = 3
        decision = "record-minimum-new-mediator-design-inconclusive-at-cap"
    elif len(selected) == 1:
        boundary = 1
        decision = "freeze-private-combat-debt-conversion-design"
    else:
        boundary = 2
        decision = "close-minimum-new-mediator-design-grammar"
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
        "currentCandidateEffectCarriers": protocol["currentCandidateEffectCarriers"],
        "assessments": assessments,
        "selectedDesigns": selected,
        "selectedDesign": protocol["selectedDesign"] if selected else None,
        "evidenceResults": evidence_results,
        "sourceIdentity": {
            "commit": immutable["sourceCommit"],
            "sha256": immutable["sourceSha256"],
            "taskCapsuleSha256": immutable["taskCapsuleSha256"],
        },
        "traceFilesRead": 0,
        "cacheFilesRead": 0,
        "supportMetricsInspected": 0,
        "GodotProcesses": 0,
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
        "selectedDesigns": selected,
        "summarySha256": core.file_sha(SUMMARY),
        "newSimulatorObservationRows": 0,
    }))


if __name__ == "__main__":
    main()
