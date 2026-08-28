#!/usr/bin/env python3
"""Zero-row terminal audit of the private-debt identity attempt."""

from __future__ import annotations

import json
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v30-private-debt-identity-audit-v1.json"
SUMMARY = core.ROOT / "summaries/post-v30-private-debt-identity-audit-v1.json"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Private-debt identity audit mismatch: {label}")


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite private-debt identity audit summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    immutable = protocol["immutableInputs"]
    require("runner SHA", core.file_sha(Path(__file__)) == immutable["runnerSha256"])
    require("identity protocol SHA", core.file_sha(
        core.ROOT / protocol["identityAttempt"]["protocolPath"]) ==
        protocol["identityAttempt"]["protocolSha256"])
    require("identity runner SHA", core.file_sha(
        core.ROOT / protocol["identityAttempt"]["runnerPath"]) ==
        protocol["identityAttempt"]["runnerSha256"])
    require("identity summary absent", not (
        core.ROOT / protocol["identityAttempt"]["summaryPath"]).exists())

    card_path = core.ROOT / protocol["sourceEvidence"]["cardInstPath"]
    probe_path = core.ROOT / protocol["sourceEvidence"]["probePath"]
    require("CardInst SHA", core.file_sha(card_path) ==
            protocol["sourceEvidence"]["cardInstSha256"])
    require("probe SHA", core.file_sha(probe_path) ==
            protocol["sourceEvidence"]["probeSha256"])
    card_text = card_path.read_text()
    probe_text = probe_path.read_text()
    require("actual CardInst field", "var up: bool = false" in card_text)
    require("absent CardInst upgraded field", "var upgraded:" not in card_text)
    require("probe invalid accesses", probe_text.count(".upgraded") ==
            protocol["sourceEvidence"]["invalidAccessCount"])

    plan_path = core.CACHE / f"{protocol['executionArtifacts']['planSha256']}.json"
    output_path = core.CACHE / f"{protocol['executionArtifacts']['outputSha256']}.json"
    require("plan object SHA", core.file_sha(plan_path) ==
            protocol["executionArtifacts"]["planSha256"])
    require("output object SHA", core.file_sha(output_path) ==
            protocol["executionArtifacts"]["outputSha256"])
    plan = json.loads(plan_path.read_text())
    output = json.loads(output_path.read_text())
    require("output plan identity", output["planSha256"] ==
            protocol["executionArtifacts"]["planSha256"])
    require("probe identity", output["probeSha256"] ==
            protocol["sourceEvidence"]["probeSha256"])
    require("direct mode", plan["mode"] == "direct")
    require("attempted rows", len(plan["rows"]) ==
            protocol["executionArtifacts"]["attemptedDirectRows"])
    rows: list[dict[str, Any]] = output["rows"]
    require("output rows", len(rows) == len(plan["rows"]))
    empty_rows = sum(not row for row in rows)
    nonempty = [row for row in rows if row]
    require("empty rows", empty_rows ==
            protocol["executionArtifacts"]["emptyRows"])
    require("only penalty controls returned", sorted(row["id"] for row in nonempty) ==
            protocol["executionArtifacts"]["returnedRowIds"])
    require("capacity summary absent", not (
        core.ROOT / protocol["capacityHardStop"]["summaryPath"]).exists())

    ledger_before = identity.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
    elapsed = time.monotonic() - started
    require("wall-time cap", elapsed <= protocol["budget"]["maximumWallTimeSeconds"])
    ledger_after = identity.ledger_identity()
    require("zero-row ledger identity", ledger_after == ledger_before)
    summary = {
        "schemaVersion": 1, "issue": 421, "decisionBoundary": 3,
        "decision": "quarantine-private-debt-at-identity-schema-cap",
        "outcomeClass": "inconclusive",
        "reason": protocol["finding"],
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "identityAttempt": protocol["identityAttempt"],
        "sourceEvidence": protocol["sourceEvidence"],
        "executionArtifacts": protocol["executionArtifacts"],
        "GodotProcesses": 1,
        "directExecutionsAttempted": len(rows),
        "directRowsReturned": len(nonempty),
        "directRowsEmpty": empty_rows,
        "newSimulatorObservationRows": 0,
        "wholeRunIdentityRows": 0,
        "enabledWholeRunRows": 0,
        "causalRows": 0,
        "supportRowsInspected": 0,
        "capacityCacheFilesRead": 0,
        "newLedgerRows": 0,
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "protectedSeedRows": ledger_after["protectedSeedRows"],
        "maximumModelContextTokens": 0,
        "wallTimeSeconds": elapsed,
        "authority": protocol["decisionRules"]["inconclusiveAuthority"],
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": "PASS", "decisionBoundary": 3,
        "decision": summary["decision"], "newSimulatorObservationRows": 0,
        "summarySha256": core.file_sha(SUMMARY),
    }))


if __name__ == "__main__":
    main()
