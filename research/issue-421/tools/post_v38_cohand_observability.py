#!/usr/bin/env python3
"""Zero-row exact co-hand observability audit for issue #421."""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-cohand-observability-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-cohand-observability-v1.json"
SOURCE = core.ROOT / "draw-telemetry-source"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Co-hand observability audit mismatch: {label}")


def add_card_to_hand_effects(content: dict[str, Any]) -> list[str]:
    found: list[str] = []
    for card_id, card in content["cards"].items():
        blocks = [("base", card.get("effects", []))]
        up = card.get("up", {})
        if isinstance(up, dict):
            blocks.append(("up", up.get("effects", [])))
        for level, effects in blocks:
            if not isinstance(effects, list):
                continue
            for effect in effects:
                if (isinstance(effect, dict) and effect.get("kind") == "addCard"
                        and effect.get("where", "discard") == "hand"):
                    found.append(f"{card_id}:{level}:{effect.get('id', '')}")
    return sorted(found)


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the co-hand observability summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    immutable = protocol["immutableInputs"]
    require("runner SHA", core.file_sha(Path(__file__)) == immutable["runnerSha256"])
    for path, expected in immutable["fileSha256"].items():
        require(path, core.file_sha(core.ROOT / path) == expected)
    head = subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=SOURCE, check=True,
        text=True, capture_output=True,
    ).stdout.strip()
    require("source commit", head == immutable["sourceCommit"])
    for path, expected in immutable["sourceSha256"].items():
        require(f"source {path}", core.file_sha(SOURCE / path) == expected)
        source_text = (SOURCE / path).read_text()
        for fragment in protocol["sourceAssertions"].get(path, []):
            require(f"{path} contains {fragment}", fragment in source_text)
    content = json.loads((SOURCE / "content/full-content.json").read_text())
    hand_additions = add_card_to_hand_effects(content)
    require("no content addCard-to-hand effects", hand_additions == [])
    ledger_before = identity.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])

    criteria = protocol["eligibilityCriteria"]
    assessments = []
    for surface in protocol["surfaces"]:
        gates = {
            "directDiscriminator": surface["directDiscriminator"] is True,
            "existingDeterministicEvents": surface["existingDeterministicEvents"] is True,
            "singleExistingHook": surface["hookCount"] <= criteria["maximumHookCount"],
            "containerLimit": surface["containerCount"] <= criteria["maximumContainerCount"],
            "scalarFieldLimit": max(surface["fieldCounts"]) <=
            criteria["maximumFieldsPerContainer"],
            "fixedScalarSchema": surface["fixedScalarSchema"] is True,
            "completeMutationCensus": surface["completeMutationCensus"] is True,
            "preservesFrozenTrace": surface["preservesFrozenTrace"] is True,
            "identityAnchorAvailable": surface["identityAnchorAvailable"] is True,
            "unclosed": surface["priorClosureAliases"] == [],
        }
        assessments.append({
            "id": surface["id"], "gateResults": gates,
            "eligible": all(gates.values()), "surface": surface,
        })
    eligible = [row for row in assessments if row["eligible"]]
    require("at most one eligible surface", len(eligible) <= 1)
    elapsed = time.monotonic() - started
    if elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        boundary = 3
        outcome_class = "inconclusive"
        decision = "record-cohand-observability-inconclusive-at-cap"
        selected = None
    elif len(eligible) == 1:
        boundary = 1
        outcome_class = "success"
        decision = "freeze-turn-and-kindle-events-for-cohand-identity-preflight"
        selected = eligible[0]["id"]
    else:
        boundary = 2
        outcome_class = "futility"
        decision = "close-exact-cohand-observability-surfaces"
        selected = None
    ledger_after = identity.ledger_identity()
    require("zero-row ledger identity", ledger_after == ledger_before)
    summary = {
        "schemaVersion": 1, "issue": 421, "decisionBoundary": boundary,
        "decision": decision, "outcomeClass": outcome_class,
        "selectedSurface": selected, "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "contentAddCardToHandEffects": hand_additions,
        "assessments": assessments, "newSimulatorObservationRows": 0,
        "newLedgerRows": 0, "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "protectedSeedRows": ledger_after["protectedSeedRows"],
        "maximumModelContextTokens": 0, "wallTimeSeconds": elapsed,
        "factorDisposition": protocol["factorDisposition"],
        "authority": protocol["decisionRules"][f"{outcome_class}Authority"],
    }
    SUMMARY.parent.mkdir(parents=True, exist_ok=True)
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": "PASS", "decision": decision, "decisionBoundary": boundary,
        "selectedSurface": selected, "newSimulatorObservationRows": 0,
        "summarySha256": core.file_sha(SUMMARY),
    }))


if __name__ == "__main__":
    main()
