#!/usr/bin/env python3
"""Zero-row semantic audit of the post-scalar representation decision."""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v30-post-scalar-structural-direction-audit-v1.json"
SUMMARY = core.ROOT / "summaries/post-v30-post-scalar-structural-direction-audit-v1.json"
SOURCE = core.ROOT / "post-scalar-structural-v1-source"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Post-scalar direction audit mismatch: {label}")


def git(*args: str) -> str:
    return subprocess.run(
        ["git", *args], cwd=SOURCE, check=True, text=True, capture_output=True,
    ).stdout.strip()


def keys(value: Any) -> set[str]:
    if isinstance(value, dict):
        out = set(map(str, value))
        for child in value.values():
            out |= keys(child)
        return out
    if isinstance(value, list):
        out: set[str] = set()
        for child in value:
            out |= keys(child)
        return out
    return set()


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite post-scalar direction audit")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    error = ""
    findings: dict[str, Any] = {}
    ledger_before: dict[str, Any] = {}
    ledger_after: dict[str, Any] = {}
    try:
        immutable = protocol["immutableInputs"]
        require("runner", core.file_sha(Path(__file__)) == immutable["runnerSha256"])
        require("task capsule", core.file_sha(core.ROOT / "task-capsule.json") ==
                immutable["taskCapsuleSha256"])
        require("source commit", git("rev-parse", "HEAD") == immutable["sourceCommit"])
        require("source status", git("status", "--porcelain") == "")
        for relative, expected in immutable["sourceSha256"].items():
            require(f"source {relative}", core.file_sha(SOURCE / relative) == expected)
        for relative, expected in immutable["evidenceSha256"].items():
            require(f"evidence {relative}", core.file_sha(core.ROOT / relative) == expected)
        ledger_before = identity.ledger_identity()
        require("ledger freeze", ledger_before == protocol["ledgerFreeze"])

        content = json.loads((SOURCE / "content/full-content.json").read_text())
        v1 = json.loads((core.ROOT /
                         "protocols/post-v30-post-scalar-structural-direction-v1.json").read_text())
        executioner = content["cards"]["executioner"]
        guarded = content["cards"]["guardedStrike"]
        require("executioner exact", executioner == protocol["exactCurrentCards"]["executioner"])
        require("guardedStrike exact", guarded == protocol["exactCurrentCards"]["guardedStrike"])
        executioner_keys = keys(executioner)
        guarded_keys = keys(guarded)
        missing_scoreline = set(protocol["requiredScorelineMediatorFields"]).isdisjoint(
            executioner_keys)
        missing_afterimage = set(protocol["requiredAfterimageMediatorFields"]).isdisjoint(
            guarded_keys)
        v1_after = v1["factorDefinitions"]["afterimagePayoff"]["level"]
        oath = next(option for option in v1["options"]
                    if option["id"] == "dual-additive-relic-oath")
        underdefined_oath = all(token not in oath["definition"] for token in
                                protocol["requiredExactMechanismTokens"])
        require("v1 factor assertion", v1_after == protocol["v1AfterimageAssertion"])
        require("current Scoreline mediator absent", missing_scoreline)
        require("current Afterimage mediator absent", missing_afterimage)
        require("Oath exact mechanism absent", underdefined_oath)
        findings = {
            "classification": "semantic-precondition-mismatch",
            "currentExecutionerKeys": sorted(executioner_keys),
            "currentGuardedStrikeKeys": sorted(guarded_keys),
            "scorelineMediatorFieldsAbsent": missing_scoreline,
            "afterimageMediatorFieldsAbsent": missing_afterimage,
            "v1AfterimageAssertion": v1_after,
            "oathMechanismUnderdefined": underdefined_oath,
            "scientificDecisionReached": false,
        }
        ledger_after = identity.ledger_identity()
        require("zero-row ledger identity", ledger_after == ledger_before)
    except (FileNotFoundError, json.JSONDecodeError, KeyError, StopIteration,
            TypeError, ValueError, RuntimeError, subprocess.CalledProcessError) as caught:
        error = str(caught)

    elapsed = time.monotonic() - started
    if elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        error = "post-scalar direction audit exceeded wall-time cap"
    if error:
        decision = "record-post-scalar-direction-audit-inconclusive"
    else:
        decision = "quarantine-dual-oath-selection-before-design"
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "decisionBoundary": 3,
        "decision": decision,
        "outcomeClass": "inconclusive",
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "findings": findings,
        "executionError": error,
        "newSimulatorObservationRows": 0,
        "newSupportRows": 0,
        "newCausalRows": 0,
        "newLedgerRows": 0,
        "GodotProcesses": 0,
        "protectedSeedRows": ledger_after.get(
            "protectedSeedRows", ledger_before.get("protectedSeedRows", 0),
        ),
        "maximumModelContextTokens": 0,
        "wallTimeSeconds": elapsed,
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "authority": protocol["decisionRules"]["inconclusiveAuthority"],
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": "PASS", "decisionBoundary": 3, "decision": decision,
        "summarySha256": core.file_sha(SUMMARY),
    }))


if __name__ == "__main__":
    main()
