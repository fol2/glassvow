#!/usr/bin/env python3
"""Zero-row current-main mechanism-source delta audit for issue #421."""

from __future__ import annotations

import argparse
import hashlib
import json
import sqlite3
import subprocess
import time
from pathlib import Path
from typing import Any


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def file_sha256(path: Path) -> str:
    return sha256(path.read_bytes())


def git(repo: Path, *args: str) -> bytes:
    return subprocess.run(
        ["git", "-C", str(repo), *args],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    ).stdout


def git_text(repo: Path, *args: str) -> str:
    return git(repo, *args).decode().strip()


def ledger_state(path: Path) -> dict[str, Any]:
    with sqlite3.connect(f"file:{path}?mode=ro", uri=True) as db:
        integrity = str(db.execute("PRAGMA integrity_check").fetchone()[0])
        records, first_sequence, last_sequence = db.execute(
            "SELECT COUNT(*), MIN(seq), MAX(seq) FROM records"
        ).fetchone()
    return {
        "sha256": file_sha256(path),
        "records": int(records),
        "firstSequence": int(first_sequence),
        "lastSequence": int(last_sequence),
        "sqliteIntegrity": integrity,
    }


def classify_path(path: str, protocol: dict[str, Any]) -> str:
    scope = protocol["pathClassification"]
    if any(path.startswith(prefix) for prefix in scope["mechanismPrefixes"]):
        return "pre-admission-mechanism"
    if any(path.startswith(prefix) for prefix in scope["mapOnlyPrefixes"]):
        return "map-only"
    return "unclassified"


def self_check(protocol: dict[str, Any]) -> None:
    assert classify_path("domain/rules/combat.gd", protocol) == "pre-admission-mechanism"
    assert classify_path("presentation/map/world_map_screen.gd", protocol) == "map-only"
    assert classify_path("README.md", protocol) == "unclassified"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--protocol", type=Path, required=True)
    parser.add_argument("--ledger", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    started = time.monotonic()
    protocol = json.loads(args.protocol.read_text())
    self_check(protocol)
    faults: list[str] = []

    runner_hash = file_sha256(Path(__file__))
    protocol_hash = file_sha256(args.protocol)
    if runner_hash != protocol["immutableInputs"]["runnerSha256"]:
        faults.append("runner identity changed")

    expected_head = protocol["currentMain"]
    expected_parent = protocol["sourceAuditBaseline"]
    actual_head = git_text(args.repo, "rev-parse", "HEAD")
    actual_parent = git_text(args.repo, "rev-parse", f"{expected_head}^")
    origin_main = git_text(args.repo, "rev-parse", "refs/remotes/origin/main")
    status = git_text(args.repo, "status", "--porcelain")
    title = git_text(args.repo, "show", "-s", "--format=%s", expected_head)
    if actual_head != expected_head:
        faults.append("source worktree head changed")
    if actual_parent != expected_parent:
        faults.append("current-main parent changed")
    if origin_main != expected_head:
        faults.append("origin/main changed")
    if status:
        faults.append("source worktree is not clean")
    if title != protocol["expectedCommitTitle"]:
        faults.append("current-main commit title changed")

    instruction_hashes: dict[str, str] = {}
    for relative, expected in protocol["immutableInputs"]["instructionSha256"].items():
        actual = file_sha256(args.repo / relative)
        instruction_hashes[relative] = actual
        if actual != expected:
            faults.append(f"instruction identity changed: {relative}")

    source_hashes: dict[str, dict[str, str]] = {}
    for relative, expected in protocol["immutableInputs"]["mechanismSourceSha256"].items():
        baseline = sha256(git(args.repo, "show", f"{expected_parent}:{relative}"))
        current = file_sha256(args.repo / relative)
        source_hashes[relative] = {"baseline": baseline, "currentMain": current}
        if baseline != expected or current != expected:
            faults.append(f"mechanism source identity changed: {relative}")

    evidence_hashes: dict[str, str] = {}
    for evidence in protocol["immutableInputs"]["evidenceObjects"]:
        spec = f"{evidence['commit']}:{evidence['path']}"
        actual = sha256(git(args.repo, "show", spec))
        evidence_hashes[evidence["path"]] = actual
        if actual != evidence["sha256"]:
            faults.append(f"evidence identity changed: {evidence['path']}")

    for commit in protocol["immutableInputs"]["archiveHeadsPreserved"]:
        if git_text(args.repo, "cat-file", "-t", commit) != "commit":
            faults.append(f"archive head is not a commit: {commit}")

    delta_lines = git_text(
        args.repo, "diff", "--name-status", expected_parent, expected_head
    ).splitlines()
    changed: list[dict[str, str]] = []
    for line in delta_lines:
        parts = line.split("\t")
        if len(parts) != 2:
            faults.append(f"unsupported name-status row: {line}")
            continue
        change, relative = parts
        changed.append({
            "change": change,
            "path": relative,
            "classification": classify_path(relative, protocol),
        })

    expected_paths = protocol["expectedChangedPaths"]
    actual_paths = [row["path"] for row in changed]
    if actual_paths != expected_paths:
        faults.append("current-main changed-path identity differs from the frozen delta")

    mechanism_changes = [
        row["path"] for row in changed
        if row["classification"] == "pre-admission-mechanism"
    ]
    unclassified_changes = [
        row["path"] for row in changed
        if row["classification"] == "unclassified"
    ]

    ledger_before = ledger_state(args.ledger)
    if ledger_before != protocol["ledgerFreeze"]:
        faults.append("append-only ledger identity changed before audit")

    if faults:
        outcome = "inconclusive"
        decision = "record-current-main-delta-identity-inconclusive"
        human_authority_required = False
    elif mechanism_changes or unclassified_changes:
        outcome = "inconclusive"
        decision = "require-separate-semantic-source-delta-audit"
        human_authority_required = False
    else:
        outcome = "futility"
        decision = "record-no-current-main-mechanism-delta-and-raise-owner-family-selection"
        human_authority_required = True

    ledger_after = ledger_state(args.ledger)
    if ledger_after != ledger_before:
        faults.append("append-only ledger changed during zero-row audit")
        outcome = "inconclusive"
        decision = "record-current-main-delta-ledger-inconclusive"
        human_authority_required = False

    elapsed = time.monotonic() - started
    if elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        faults.append("wall-time cap exceeded")
        outcome = "inconclusive"
        decision = "record-current-main-delta-cap-inconclusive"
        human_authority_required = False

    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "authority": protocol["authority"],
        "outcomeClass": outcome,
        "decision": decision,
        "humanAuthorityRequired": human_authority_required,
        "claimBoundary": protocol["claimBoundary"],
        "protocolSha256": protocol_hash,
        "runnerSha256": runner_hash,
        "sourceAuditBaseline": expected_parent,
        "currentMain": expected_head,
        "originMain": origin_main,
        "currentMainCommitTitle": title,
        "sourceStatus": status.splitlines(),
        "changedPaths": changed,
        "mechanismChanges": mechanism_changes,
        "unclassifiedChanges": unclassified_changes,
        "mechanismSourceSha256": source_hashes,
        "instructionSha256": instruction_hashes,
        "evidenceSha256": evidence_hashes,
        "faults": faults,
        "GodotProcesses": 0,
        "newSimulatorObservationRows": 0,
        "newLedgerRows": 0,
        "protectedSeedRows": 0,
        "supportMetricsInspected": 0,
        "maximumModelContextTokensDuringExecutionAndDecision": 0,
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "humanAuthorityPackage": protocol["humanAuthorityPackage"] if human_authority_required else None,
        "wallTimeSeconds": elapsed,
    }
    args.output.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "decision": decision,
        "outcomeClass": outcome,
        "changedPaths": len(changed),
        "mechanismChanges": len(mechanism_changes),
        "faults": len(faults),
        "wallTimeSeconds": elapsed,
    }, sort_keys=True))
    return 0 if not faults else 2


if __name__ == "__main__":
    raise SystemExit(main())
