#!/usr/bin/env python3
"""Zero-row source audit for the enemy Cracked/Dimmed status lattice."""

from __future__ import annotations

import json
import re
import subprocess
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v30-enemy-status-lattice-audit-v1.json"
SUMMARY = core.ROOT / "summaries/post-v30-enemy-status-lattice-audit-v1.json"
STATUSES = ("vulnerable", "weak")


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Enemy-status lattice mismatch: {label}")


def main_blob(path: str) -> bytes:
    return subprocess.run(
        ["git", "show", f"HEAD:{path}"], cwd=core.SOURCE,
        check=True, capture_output=True,
    ).stdout


def enemy_statuses(effects: list[dict[str, Any]]) -> list[str]:
    return sorted({
        str(effect.get("id")) for effect in effects
        if effect.get("kind") == "status"
        and effect.get("who") in ("target", "allEnemies")
        and effect.get("id") in STATUSES
    })


def producer_lattice(content: dict[str, Any]) -> dict[str, list[str]]:
    cells = {"neither": [], "cracked-only": [], "dimmed-only": [], "both": []}
    for card_id, card in content["cards"].items():
        base = enemy_statuses(card.get("effects", []))
        upgraded = enemy_statuses(card.get("up", {}).get("effects", card.get("effects", [])))
        require(f"{card_id} status class stable across upgrade", base == upgraded)
        key = {
            (): "neither",
            ("vulnerable",): "cracked-only",
            ("weak",): "dimmed-only",
            ("vulnerable", "weak"): "both",
        }[tuple(base)]
        cells[key].append(card_id)
    return {key: sorted(value) for key, value in cells.items()}


def status_reads(combat: str) -> list[dict[str, str]]:
    function = ""
    rows: list[dict[str, str]] = []
    for raw in combat.splitlines():
        stripped = raw.strip()
        match = re.match(r"(?:static )?func ([a-zA-Z0-9_]+)\(", stripped)
        if match:
            function = match.group(1)
        for status in STATUSES:
            if f'"{status}"' not in stripped:
                continue
            if "statuses" not in stripped:
                continue
            subject = "enemy" if any(
                token in stripped for token in
                ("attacker.statuses", "e.statuses", "target.statuses")
            ) else "player"
            rows.append({
                "function": function,
                "status": status,
                "subject": subject,
                "expression": stripped,
            })
    return rows


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite enemy-status lattice summary")
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

    blobs: dict[str, str] = {}
    for path, expected_sha in immutable["sourceSha256"].items():
        blob = main_blob(path)
        require(f"{path} SHA", core.sha(blob) == expected_sha)
        blobs[path] = blob.decode()

    content = json.loads(blobs["content/full-content.json"])
    lattice = producer_lattice(content)
    require("complete producer lattice", lattice == protocol["producerLattice"])

    reads = status_reads(blobs["domain/rules/combat.gd"])
    require("complete status-read inventory", reads == protocol["statusReadInventory"])
    joint = [row for row in reads if '"vulnerable"' in row["expression"]
             and '"weak"' in row["expression"]]
    require("no joint enemy-status consumer", joint == [])

    evidence_results: dict[str, dict[str, Any]] = {}
    for name, spec in protocol["priorEvidence"].items():
        path = core.ROOT / spec["path"]
        require(f"{name} SHA", core.file_sha(path) == spec["sha256"])
        decision = json.loads(path.read_text())["decision"]
        require(f"{name} decision", decision == spec["decision"])
        evidence_results[name] = {"sha256": spec["sha256"], "decision": decision}

    require("both producer is Shatterhymn", lattice["both"] == ["warCry"])
    for spec in [protocol["dimmedProtocol"], *protocol["crackedProtocols"]]:
        require(f"{spec['path']} SHA",
                core.file_sha(core.ROOT / spec["path"]) == spec["sha256"])
    require("Shatterhymn is in closed Dimmed class",
            "warCry" in json.loads((core.ROOT / protocol["dimmedProtocol"]["path"]).read_text())
            ["sourceClasses"]["dimmedProducers"])
    require("Shatterhymn is in closed Cracked classes", all(
        "warCry" in json.loads((core.ROOT / spec["path"]).read_text())
        ["candidate"]["producers"]
        for spec in protocol["crackedProtocols"]
    ))

    ledger_before = identity.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
    elapsed = time.monotonic() - started
    boundary = 3 if elapsed > float(protocol["budget"]["maximumWallTimeSeconds"]) else 2
    decision = (
        "record-enemy-status-lattice-audit-inconclusive-at-cap" if boundary == 3
        else "close-cracked-dimmed-conjunction-as-closed-alias"
    )
    ledger_after = identity.ledger_identity()
    require("zero-row ledger identity", ledger_after == ledger_before)
    authority_key = "inconclusiveAuthority" if boundary == 3 else "futilityAuthority"
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "decisionBoundary": boundary,
        "decision": decision,
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "producerLattice": lattice,
        "statusReadInventory": reads,
        "jointEnemyStatusConsumers": joint,
        "aliasStructure": protocol["aliasStructure"],
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
        "summarySha256": core.file_sha(SUMMARY),
        "newSimulatorObservationRows": 0,
    }))


if __name__ == "__main__":
    main()
