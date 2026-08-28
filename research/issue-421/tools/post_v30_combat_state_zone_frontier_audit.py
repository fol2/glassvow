#!/usr/bin/env python3
"""Zero-row exhaustive audit of current combat state and card-zone grammar."""

from __future__ import annotations

import json
import re
import subprocess
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v30-combat-state-zone-frontier-audit-v1.json"
SUMMARY = core.ROOT / "summaries/post-v30-combat-state-zone-frontier-audit-v1.json"
STATE_FILES = {
    "combat": "domain/state/combat_state.gd",
    "player": "domain/state/player_combatant.gd",
    "enemy": "domain/state/enemy_combatant.gd",
    "card": "domain/state/card_inst.gd",
}


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Combat-state/zone frontier mismatch: {label}")


def main_blob(path: str) -> bytes:
    return subprocess.run(
        ["git", "show", f"HEAD:{path}"], cwd=core.SOURCE,
        check=True, capture_output=True,
    ).stdout


def fields(blob: bytes) -> list[str]:
    return re.findall(r"^var\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?::|=)", blob.decode(),
                      flags=re.MULTILINE)


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite combat-state/zone frontier summary")
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

    inventory = {
        name: fields(blobs[path])
        for name, path in STATE_FILES.items()
    }
    require("exact state inventory", inventory == protocol["stateInventory"])

    seen = {name: [] for name in STATE_FILES}
    for surface in protocol["stateSurfaceCoverage"]:
        for name, members in surface["fields"].items():
            require(f"known state owner {name}", name in inventory)
            for member in members:
                require(f"known field {name}.{member}", member in inventory[name])
                seen[name].append(member)
    for name, expected in inventory.items():
        require(f"one-to-one coverage {name}", sorted(seen[name]) == sorted(expected))
        require(f"no duplicate coverage {name}", len(seen[name]) == len(set(seen[name])))

    uncovered = [
        surface["id"] for surface in protocol["stateSurfaceCoverage"]
        if surface["disposition"] == "uncovered"
    ]
    require("frozen uncovered set", uncovered == protocol["uncoveredStateSurfaces"])

    evidence_results: dict[str, dict[str, Any]] = {}
    for name, spec in protocol["priorEvidence"].items():
        path = core.ROOT / spec["path"]
        require(f"{name} SHA", core.file_sha(path) == spec["sha256"])
        decision = json.loads(path.read_text())["decision"]
        require(f"{name} decision", decision == spec["decision"])
        evidence_results[name] = {"sha256": spec["sha256"], "decision": decision}

    ledger_before = identity.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
    elapsed = time.monotonic() - started
    if elapsed > float(protocol["budget"]["maximumWallTimeSeconds"]):
        boundary = 3
        decision = "record-combat-state-zone-frontier-inconclusive-at-cap"
    elif len(uncovered) == 1:
        boundary = 1
        decision = "freeze-one-uncovered-combat-state-zone-surface"
    else:
        boundary = 2
        decision = "close-existing-combat-state-zone-grammar"
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
        "stateInventory": inventory,
        "stateFieldCount": sum(len(value) for value in inventory.values()),
        "stateSurfaceCoverage": protocol["stateSurfaceCoverage"],
        "uncoveredStateSurfaces": uncovered,
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
        "stateFieldCount": summary["stateFieldCount"],
        "uncoveredStateSurfaces": uncovered,
        "summarySha256": core.file_sha(SUMMARY),
        "newSimulatorObservationRows": 0,
    }))


if __name__ == "__main__":
    main()
