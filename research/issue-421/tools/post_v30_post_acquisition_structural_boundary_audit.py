#!/usr/bin/env python3
"""Zero-row representation-boundary audit after the bounded acquisition fallback."""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v30-post-acquisition-structural-boundary-v1.json"
SUMMARY = core.ROOT / "summaries/post-v30-post-acquisition-structural-boundary-v1.json"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"post-acquisition structural-boundary mismatch: {label}")


def sha(path: Path) -> str:
    return core.file_sha(path)


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite a completed structural-boundary audit")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    require("runner SHA", sha(Path(__file__)) == protocol["immutableInputs"]["runnerSha256"])
    require(
        "task capsule SHA",
        sha(core.ROOT / "task-capsule.json")
        == protocol["immutableInputs"]["taskCapsuleSha256"],
    )

    source = Path(protocol["immutableInputs"]["sourceRoot"])
    head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=source, text=True).strip()
    require("source commit", head == protocol["immutableInputs"]["sourceCommit"])
    source_files: dict[str, str] = {}
    for relative, expected in protocol["immutableInputs"]["sourceSha256"].items():
        path = source / relative
        require(f"source exists {relative}", path.is_file())
        require(f"source SHA {relative}", sha(path) == expected)
        source_files[relative] = path.read_text()
    require("source file cap", len(source_files) <= protocol["budget"]["maximumSourceFilesRead"])

    evidence: dict[str, dict[str, Any]] = {}
    for name, packet in protocol["immutableEvidence"].items():
        path = core.ROOT / packet["path"]
        require(f"evidence SHA {name}", sha(path) == packet["sha256"])
        row = json.loads(path.read_text())
        require(f"evidence decision {name}", row["decision"] == packet["decision"])
        evidence[name] = row
    require("evidence file cap", len(evidence) <= protocol["budget"]["maximumEvidenceFilesRead"])

    partition = protocol["representationPartition"]
    ids = [str(row["id"]) for row in partition]
    require("partition IDs unique", len(ids) == len(set(ids)))
    require("partition exact", ids == protocol["expectedPartitionOrder"])
    require("one lifetime cell per class", all(row["lifetime"] in protocol["lifetimes"] for row in partition))
    require("every class has evidence", all(row["evidence"] for row in partition))

    eligible: list[str] = []
    human_authority: list[str] = []
    rejected: dict[str, list[str]] = {}
    for row in partition:
        faults: list[str] = []
        if not row["materiallyDistinct"]:
            faults.append("closed-alias")
        if row["immutableDisposition"] != "unclosed":
            faults.append(str(row["immutableDisposition"]))
        if not row["productSemanticsFrozen"]:
            faults.append("product-semantics-not-frozen")
        if row["requiresHumanAuthority"]:
            faults.append("human-authority-required")
            human_authority.append(str(row["id"]))
        if not row["deterministic"] or not row["noRng"]:
            faults.append("determinism")
        if row["methodClass"] and not row["methodAuthorised"]:
            faults.append("method-not-authorised")
        if faults:
            rejected[str(row["id"])] = faults
        else:
            eligible.append(str(row["id"]))

    require("at most one autonomous class", len(eligible) <= 1)
    ledger_before = identity.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
    ledger_after = identity.ledger_identity()
    require("zero-row ledger identity", ledger_after == ledger_before)
    elapsed = time.monotonic() - started
    require("wall-time cap", elapsed <= protocol["budget"]["maximumWallTimeSeconds"])

    if len(eligible) == 1:
        boundary = 1
        decision = "freeze-one-post-acquisition-structural-class"
        authority_key = "successAuthority"
    elif not eligible and human_authority:
        boundary = 2
        decision = "record-post-acquisition-structural-gate-unavailable"
        authority_key = "futilityAuthority"
    else:
        boundary = 3
        decision = "record-post-acquisition-structural-boundary-inconclusive"
        authority_key = "inconclusiveAuthority"

    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "decisionBoundary": boundary,
        "decision": decision,
        "protocolSha256": protocol_sha,
        "runnerSha256": sha(Path(__file__)),
        "sourceCommit": head,
        "sourceFilesRead": len(source_files),
        "evidenceFilesRead": len(evidence),
        "representationPartition": partition,
        "eligibleAutonomousClasses": eligible,
        "humanAuthorityClasses": human_authority,
        "rejectedClasses": rejected,
        "claimBoundary": protocol["claimBoundary"],
        "factorDisposition": protocol["factorDisposition"],
        "newSimulatorObservationRows": 0,
        "newLedgerRows": 0,
        "supportRowsInspected": 0,
        "cacheFilesRead": 0,
        "godotProcesses": 0,
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
        "eligibleAutonomousClasses": eligible,
        "humanAuthorityClasses": human_authority,
        "newSimulatorObservationRows": 0,
        "summarySha256": sha(SUMMARY),
    }))


if __name__ == "__main__":
    main()
