#!/usr/bin/env python3
"""First scientific direct identity look after the v1 provenance-schema stop."""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path
from typing import Any

import post_d486_private_overflow_identity_v1 as v1
import post_843e899_terminal_hit_precision_identity_v1 as direct
import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-d486-private-overflow-identity-v2.json"
PARENT = core.ROOT / "protocols/post-d486-private-overflow-identity-v1.json"
SUMMARY = core.ROOT / "summaries/post-d486-private-overflow-identity-v2.json"


def git_status(path: Path) -> list[str]:
    return subprocess.run(
        ["git", "status", "--porcelain=v1"], cwd=path, check=True,
        text=True, capture_output=True,
    ).stdout.splitlines()


def source_identity(parent: dict[str, Any], protocol: dict[str, Any]) -> dict[str, Any]:
    parent_immutable = parent["immutableInputs"]
    immutable = protocol["immutableInputs"]
    repository = Path(parent_immutable["repositoryPath"])
    godot = Path(parent_immutable["godotBinaryPath"])
    return {
        "repositoryRefs": {
            ref: v1.git(repository, "rev-parse", ref)
            for ref in parent_immutable["repositoryRefs"]
        },
        "baselineHead": v1.git(v1.BASELINE, "rev-parse", "HEAD"),
        "candidateHead": v1.git(v1.CANDIDATE, "rev-parse", "HEAD"),
        "baselineStatus": git_status(v1.BASELINE),
        "candidateStatus": git_status(v1.CANDIDATE),
        "baselineSha256": {
            name: core.file_sha(v1.BASELINE / name)
            for name in parent_immutable["baselineSha256"]
        },
        "candidateSha256": {
            name: core.file_sha(v1.CANDIDATE / name)
            for name in parent_immutable["candidateSha256"]
        },
        "candidatePrototypeDiffSha256": core.sha(subprocess.run(
            ["git", "diff", "--", "domain/rules/combat.gd",
             "domain/state/player_combatant.gd"],
            cwd=v1.CANDIDATE, check=True, capture_output=True,
        ).stdout),
        "godotVersion": subprocess.run(
            [str(godot), "--version"], check=True, text=True, capture_output=True,
        ).stdout.strip(),
        "godotBinarySha256": core.file_sha(godot),
        "runnerSha256": core.file_sha(Path(__file__)),
        "taskCapsuleSha256": core.file_sha(
            core.ROOT / parent_immutable["taskCapsulePath"]),
        "predecessorSha256": {
            name: core.file_sha(core.ROOT / name)
            for name in immutable["predecessorSha256"]
        },
    }


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite private-overflow identity v2 summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    parent, parent_sha = core.load_protocol(PARENT)
    v1.require("parent protocol identity", parent_sha == protocol["parentProtocolSha256"])
    preflight_path = core.ROOT / protocol["mechanicalPreflight"]["summaryPath"]
    v1.require("mechanical preflight unavailable", preflight_path.is_file())
    preflight = json.loads(preflight_path.read_text())
    v1.require("mechanical preflight not green",
               preflight.get("decision") == "authorise-first-scientific-v2-look"
               and preflight.get("protocolSha256") == protocol_sha
               and preflight.get("runnerSha256")
               == protocol["immutableInputs"]["preflightRunnerSha256"])

    immutable = protocol["immutableInputs"]
    actual_source = source_identity(parent, protocol)
    v1.require("immutable source identity drift", actual_source == {
        key: immutable[key] for key in actual_source
    })
    ledger_before = identity.ledger_identity()
    v1.require("ledger freeze drift", ledger_before == parent["ledgerFreeze"])
    source_gate_faults = v1.static_faults()

    scenarios = parent["directScenarios"]
    baseline_rows = direct.arm_rows(scenarios, "baseline")
    candidate_rows = (
        direct.arm_rows(scenarios, "omitted")
        + direct.arm_rows(scenarios, "off")
        + direct.arm_rows(scenarios, "ab")
    )
    component = next(
        row for row in scenarios if row["id"] == parent["componentControlScenario"]
    )
    candidate_rows += direct.arm_rows([component], "a")
    candidate_rows += direct.arm_rows([component], "b")
    v1.require("direct observation cap drift",
               len(baseline_rows) + len(candidate_rows)
               == protocol["budget"]["directControlledObservations"])

    started = time.monotonic()
    deadline = started + protocol["budget"]["maximumWallTimeSeconds"]
    outputs: dict[str, str] = {}
    plans: dict[str, str] = {}
    execution_error = ""
    faults = list(source_gate_faults)
    completed_rows = 0
    if not source_gate_faults:
        try:
            baseline, plans["baseline"], outputs["baseline"] = direct.run_probe(
                v1.BASELINE, baseline_rows, "current-main-baseline-v2", protocol_sha,
                parent["immutableInputs"]["godotBinaryPath"], deadline,
            )
            candidate, plans["candidate"], outputs["candidate"] = direct.run_probe(
                v1.CANDIDATE, candidate_rows, "instrumented-fixed-matrix-v2", protocol_sha,
                parent["immutableInputs"]["godotBinaryPath"], deadline,
            )
            completed_rows = len(baseline["rows"]) + len(candidate["rows"])
            faults.extend(v1.direct_faults(parent, baseline, candidate))
        except (OSError, subprocess.SubprocessError, TimeoutError, RuntimeError) as error:
            execution_error = str(error)

    ledger_after = identity.ledger_identity()
    if ledger_after != ledger_before:
        faults.append("append-only ledger changed")
    elapsed = time.monotonic() - started
    if execution_error or elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        outcome = "inconclusive"
        decision = "record-private-overflow-identity-v2-inconclusive-at-cap"
        boundary = 3
    elif faults:
        outcome = "futility"
        decision = "close-private-overflow-heavy-blow-representation"
        boundary = 2
    else:
        outcome = "success"
        decision = "freeze-private-overflow-heavy-blow-for-natural-capacity"
        boundary = 1

    summary: dict[str, Any] = {
        "schemaVersion": 2,
        "issue": 421,
        "outcomeClass": outcome,
        "decision": decision,
        "decisionBoundary": boundary,
        "claimBoundary": protocol["claimBoundary"],
        "authority": protocol["decisionRules"][outcome + "Authority"],
        "protocolSha256": protocol_sha,
        "parentProtocolSha256": parent_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "mechanicalPreflightSha256": core.file_sha(preflight_path),
        "sourceIdentity": actual_source,
        "sourceGateFaults": source_gate_faults,
        "directFaults": faults,
        "executionError": execution_error,
        "planSha256": plans,
        "outputSha256": outputs,
        "GodotProcesses": len(outputs),
        "directControlledObservations": completed_rows,
        "newSimulatorObservationRows": 0,
        "newLedgerRows": ledger_after["records"] - ledger_before["records"],
        "protectedSeedRows": ledger_after["protectedSeedRows"],
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "wallTimeSeconds": elapsed,
        "maximumModelContextTokensDuringExecutionAndDecision": 0,
        "archiveHeadsPreserved": {
            "843e899": parent["immutableInputs"]["repositoryRefs"][
                "refs/remotes/origin/research/issue-421-post-reshuffle-frontier-evidence"
            ],
            "d486289": parent["immutableInputs"]["repositoryRefs"][
                "refs/remotes/origin/research/issue-421-post-843e899-family-ladder-evidence"
            ],
        },
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "outcomeClass": outcome,
        "decision": decision,
        "faults": len(faults),
        "rows": completed_rows,
        "wallTimeSeconds": round(elapsed, 3),
    }, sort_keys=True))


if __name__ == "__main__":
    main()
