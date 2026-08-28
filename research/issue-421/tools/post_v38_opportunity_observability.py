#!/usr/bin/env python3
"""Zero-row co-play opportunity observability audit for issue #421."""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-opportunity-observability-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-opportunity-observability-v1.json"
SOURCE = core.ROOT / "null-harness-instrumented-source"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Opportunity-observability audit mismatch: {label}")


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the opportunity-observability summary")
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
        source_path = SOURCE / path
        require(f"source {path}", core.file_sha(source_path) == expected)
        text = source_path.read_text()
        for fragment in protocol["sourceAssertions"].get(path, []):
            require(f"{path} contains {fragment}", fragment in text)
    topology = json.loads(
        (core.ROOT / protocol["evidence"]["topologySummary"]["path"]).read_text()
    )
    for dotted, expected in protocol["evidence"]["topologySummary"]["assertions"].items():
        value: Any = topology
        for key in dotted.split("."):
            value = value[key]
        require(f"topology {dotted}", value == expected)
    ledger_before = identity.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])

    criteria = protocol["eligibilityCriteria"]
    assessments = []
    for surface in protocol["surfaces"]:
        gates = {
            "directDiscriminator": surface["directDiscriminator"] is True,
            "existingDeterministicEvent": surface["existingDeterministicEvent"] is True,
            "singleHook": surface["hookCount"] <= criteria["maximumHookCount"],
            "minimalFields": len(surface["fields"]) <= criteria["maximumFieldCount"],
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
        decision = "record-opportunity-observability-inconclusive-at-cap"
        selected = None
    elif len(eligible) == 1:
        boundary = 1
        outcome_class = "success"
        decision = "freeze-fight-scoped-draw-telemetry-identity-preflight"
        selected = eligible[0]["id"]
    else:
        boundary = 2
        outcome_class = "futility"
        decision = "close-observed-opportunity-decomposition-surfaces"
        selected = None
    ledger_after = identity.ledger_identity()
    require("zero-row ledger identity", ledger_after == ledger_before)
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "decisionBoundary": boundary,
        "decision": decision,
        "outcomeClass": outcome_class,
        "selectedSurface": selected,
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "assessments": assessments,
        "newSimulatorObservationRows": 0,
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
        "selectedSurface": selected, "newSimulatorObservationRows": 0,
        "summarySha256": core.file_sha(SUMMARY),
    }))


if __name__ == "__main__":
    main()
