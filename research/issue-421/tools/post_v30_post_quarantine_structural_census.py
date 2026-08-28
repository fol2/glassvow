#!/usr/bin/env python3
"""Zero-row census of structural families after private-token quarantine."""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v30-post-quarantine-structural-census-v1.json"
SUMMARY = core.ROOT / "summaries/post-v30-post-quarantine-structural-census-v1.json"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Post-quarantine structural census mismatch: {label}")


def main_blob(path: str) -> bytes:
    return subprocess.run(
        ["git", "show", f"HEAD:{path}"], cwd=core.SOURCE,
        check=True, capture_output=True,
    ).stdout


def authored_ids(cards: dict[str, Any], kind: str) -> set[str]:
    found: set[str] = set()
    for card in cards.values():
        blocks = [card.get("effects", []), card.get("up", {}).get("effects", [])]
        for effects in blocks:
            for effect in effects:
                if effect.get("kind") == kind and effect.get("id") is not None:
                    found.add(str(effect["id"]))
    return found


def eligible(candidate: dict[str, Any]) -> bool:
    gates = candidate["attributes"]
    return (
        candidate["priorClosureAliases"] == []
        and gates["privateMediator"]
        and gates["naturalCausalCost"]
        and gates["combatLocal"]
        and gates["duskIsolated"]
        and gates["deterministic"]
        and gates["noRng"]
        and gates["noSaveState"]
        and gates["gameplayHookCount"] <= 2
        and gates["currentCarrierCount"] == 0
    )


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite structural census summary")
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
    blobs = {path: main_blob(path) for path in immutable["sourceSha256"]}
    for path, expected_sha in immutable["sourceSha256"].items():
        require(f"{path} SHA", core.sha(blobs[path]) == expected_sha)
    content = json.loads(blobs["content/full-content.json"])
    cards = content["cards"]
    require("new card IDs absent", not set(protocol["selectedDesign"]["cardIds"]) &
            set(cards))
    require("new status ID absent", protocol["selectedDesign"]["statusId"] not in
            authored_ids(cards, "status"))
    require("new special IDs absent", not set(protocol["selectedDesign"]["specialIds"]) &
            authored_ids(cards, "special"))
    combat = blobs["domain/rules/combat.gd"].decode()
    for label, text in protocol["sourceAssertions"].items():
        require(label, text in combat)
    for name, spec in protocol["priorEvidence"].items():
        path = core.ROOT / spec["path"]
        require(f"{name} SHA", core.file_sha(path) == spec["sha256"])
        require(f"{name} decision", json.loads(path.read_text())["decision"] ==
                spec["decision"])

    assessments = [
        {
            "id": candidate["id"], "eligible": eligible(candidate),
            "priorClosureAliases": candidate["priorClosureAliases"],
            "attributes": candidate["attributes"],
        }
        for candidate in protocol["candidates"]
    ]
    selected = [row["id"] for row in assessments if row["eligible"]]
    require("frozen selected set", selected == protocol["selectedDesigns"])
    ledger_before = identity.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
    elapsed = time.monotonic() - started
    if elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        boundary, decision = 3, "record-post-quarantine-census-inconclusive-at-cap"
    elif len(selected) == 1:
        boundary, decision = 1, "freeze-private-status-liability-design"
    else:
        boundary, decision = 2, "close-post-quarantine-structural-grammar"
    ledger_after = identity.ledger_identity()
    require("zero-row ledger identity", ledger_after == ledger_before)
    authority = protocol["decisionRules"][
        "successAuthority" if boundary == 1 else
        ("futilityAuthority" if boundary == 2 else "inconclusiveAuthority")]
    summary = {
        "schemaVersion": 1, "issue": 421, "decisionBoundary": boundary,
        "decision": decision, "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "assessments": assessments, "selectedDesigns": selected,
        "selectedDesign": protocol["selectedDesign"] if selected else None,
        "traceFilesRead": 0, "cacheFilesRead": 0, "supportRowsInspected": 0,
        "GodotProcesses": 0, "newSimulatorObservationRows": 0,
        "newLedgerRows": 0, "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "protectedSeedRows": ledger_after["protectedSeedRows"],
        "maximumModelContextTokens": 0, "wallTimeSeconds": elapsed,
        "authority": authority,
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": "PASS", "decisionBoundary": boundary, "decision": decision,
        "selectedDesigns": selected, "newSimulatorObservationRows": 0,
        "summarySha256": core.file_sha(SUMMARY),
    }))


if __name__ == "__main__":
    main()
