#!/usr/bin/env python3
"""Zero-row completeness gate for the post-fallback mechanism boundary."""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v30-mechanism-requirement-boundary-v1.json"
SUMMARY = core.ROOT / "summaries/post-v30-mechanism-requirement-boundary-v1.json"
UNSPECIFIED = "UNSPECIFIED_BY_SSOT"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"mechanism-requirement boundary mismatch: {label}")


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite a completed mechanism-requirement audit")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    error = ""
    source_files_read = 0
    evidence_files_read = 0
    assessments: dict[str, dict[str, Any]] = {}
    eligible: list[str] = []
    human_authority: list[str] = []
    ledger_before: dict[str, Any] = {}
    ledger_after: dict[str, Any] = {}

    try:
        immutable = protocol["immutableInputs"]
        require("runner SHA", core.file_sha(Path(__file__)) == immutable["runnerSha256"])
        require(
            "task capsule SHA",
            core.file_sha(core.ROOT / "task-capsule.json")
            == immutable["taskCapsuleSha256"],
        )

        source = Path(immutable["sourceRoot"])
        head = subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=source, text=True,
        ).strip()
        status = subprocess.check_output(
            ["git", "status", "--porcelain"], cwd=source, text=True,
        ).strip()
        require("source commit", head == immutable["sourceCommit"])
        require("source worktree clean", status == "")
        for relative, expected in immutable["sourceSha256"].items():
            path = source / relative
            require(f"source exists {relative}", path.is_file())
            require(f"source SHA {relative}", core.file_sha(path) == expected)
            text = path.read_text()
            for anchor in immutable["sourceAnchors"].get(relative, []):
                require(f"source anchor {relative}: {anchor}", anchor in text)
            source_files_read += 1
        require(
            "source-file cap",
            source_files_read <= protocol["budget"]["maximumSourceFilesRead"],
        )

        for name, packet in protocol["immutableEvidence"].items():
            path = core.ROOT / packet["path"]
            require(f"evidence SHA {name}", core.file_sha(path) == packet["sha256"])
            row = json.loads(path.read_text())
            require(f"evidence decision {name}", row["decision"] == packet["decision"])
            evidence_files_read += 1
        require(
            "evidence-file cap",
            evidence_files_read <= protocol["budget"]["maximumEvidenceFilesRead"],
        )

        required = protocol["requiredMechanismFields"]
        require("required fields unique", len(required) == len(set(required)))
        classes = protocol["mechanismClasses"]
        ids = [str(row["id"]) for row in classes]
        require("class order", ids == protocol["expectedClassOrder"])
        require("class IDs unique", len(ids) == len(set(ids)))

        for row in classes:
            mechanism = row["mechanism"]
            require(f"mechanism field set {row['id']}", set(mechanism) == set(required))
            missing = [field for field in required if mechanism[field] == UNSPECIFIED]
            attrs = row["attributes"]
            failures: list[str] = []
            for field in protocol["requiredEligibilityAttributes"]:
                if not attrs[field]:
                    failures.append(field)
            if missing:
                failures.append("mechanism-semantics-incomplete")
            if attrs["requiresHumanAuthority"]:
                failures.append("human-authority-required")
            is_eligible = not failures
            if is_eligible:
                eligible.append(str(row["id"]))
            is_human = (
                attrs["materiallyDistinct"]
                and attrs["broadTaskAuthority"]
                and attrs["sourceCarrierAvailable"]
                and attrs["requiresHumanAuthority"]
                and bool(missing)
            )
            if is_human:
                human_authority.append(str(row["id"]))
            assessments[str(row["id"])] = {
                "eligible": is_eligible,
                "humanAuthorityClass": is_human,
                "lifecycleClass": row["lifecycleClass"],
                "missingMechanismFields": missing,
                "failedEligibility": failures,
            }

        require("at most one eligible class", len(eligible) <= 1)
        ledger_before = identity.ledger_identity()
        require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
        ledger_after = identity.ledger_identity()
        require("zero-row ledger identity", ledger_after == ledger_before)
    except (
        FileNotFoundError,
        json.JSONDecodeError,
        KeyError,
        TypeError,
        ValueError,
        RuntimeError,
        subprocess.CalledProcessError,
    ) as caught:
        error = str(caught)

    elapsed = time.monotonic() - started
    if elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        error = "mechanism-requirement audit exceeded wall-time cap"

    human_lifecycles = {
        assessments[name]["lifecycleClass"] for name in human_authority
    }
    if error:
        boundary = 3
        decision = "record-post-fallback-mechanism-boundary-inconclusive"
        outcome = "inconclusive"
        authority_key = "inconclusiveAuthority"
    elif len(eligible) == 1:
        boundary = 1
        decision = "freeze-one-source-complete-post-fallback-mechanism"
        outcome = "success"
        authority_key = "successAuthority"
    elif not eligible and len(human_authority) >= 2 and len(human_lifecycles) >= 2:
        boundary = 2
        decision = "record-post-fallback-mechanism-authority-gate-unavailable"
        outcome = "unavailable"
        authority_key = "futilityAuthority"
    else:
        boundary = 3
        decision = "record-post-fallback-mechanism-boundary-inconclusive"
        outcome = "inconclusive"
        authority_key = "inconclusiveAuthority"

    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "decisionBoundary": boundary,
        "decision": decision,
        "outcomeClass": outcome,
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "sourceCommit": protocol["immutableInputs"]["sourceCommit"],
        "sourceFilesRead": source_files_read,
        "evidenceFilesRead": evidence_files_read,
        "assessments": assessments,
        "eligibleAutonomousClasses": eligible,
        "humanAuthorityClasses": human_authority,
        "humanAuthorityLifecycleClasses": sorted(human_lifecycles),
        "executionError": error,
        "claimBoundary": protocol["claimBoundary"],
        "factorDisposition": protocol["factorDisposition"],
        "newSimulatorObservationRows": 0,
        "newSupportRows": 0,
        "newCausalRows": 0,
        "newLedgerRows": 0,
        "cacheFilesRead": 0,
        "GodotProcesses": 0,
        "protectedSeedRows": ledger_after.get(
            "protectedSeedRows", ledger_before.get("protectedSeedRows", 0),
        ),
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
        "summarySha256": core.file_sha(SUMMARY),
    }))


if __name__ == "__main__":
    main()
