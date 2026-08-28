#!/usr/bin/env python3
"""Preregistered Gate 1 branch-observation identity witness for issue #421."""

from __future__ import annotations

import copy
import json
import sqlite3
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import Any

import research as core


PROTOCOL = core.ROOT / "protocols/post-v30-hearth-observation-resolution-gate1-v1.json"
SUMMARY = core.ROOT / "summaries/post-v30-hearth-observation-resolution-gate1-v1.json"
SOURCE = core.ROOT / "hearth-observation-resolution-source"
GODOT = Path("/Applications/Godot.app/Contents/MacOS/Godot")
PROBE = "res://tools/research_421_hearth_observation_probe.gd"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Hearth observation Gate 1 mismatch: {label}")


def ledger_identity() -> dict[str, Any]:
    with sqlite3.connect(f"file:{core.LEDGER}?mode=ro", uri=True) as db:
        records, first, last = db.execute(
            "SELECT COUNT(*), MIN(seq), MAX(seq) FROM records"
        ).fetchone()
        protected = db.execute(
            "SELECT COUNT(*) FROM records WHERE kind = 'observation' "
            "AND CAST(json_extract(payload_json, '$.seed') AS INTEGER) "
            "BETWEEN 3000 AND 5399"
        ).fetchone()[0]
        integrity = db.execute("PRAGMA integrity_check").fetchone()[0]
    return {
        "sha256": core.file_sha(core.LEDGER),
        "records": records,
        "firstSequence": first,
        "lastSequence": last,
        "protectedSeedRows": protected,
        "sqliteIntegrity": integrity,
    }


def source_identity() -> dict[str, Any]:
    return {
        "sourceCommit": subprocess.run(
            ["git", "rev-parse", "HEAD"], cwd=SOURCE, check=True,
            text=True, capture_output=True,
        ).stdout.strip(),
        "godotVersion": subprocess.run(
            [str(GODOT), "--version"], check=True, text=True,
            capture_output=True,
        ).stdout.strip(),
        "godotBinarySha256": core.file_sha(GODOT),
        "contentSha256": core.file_sha(SOURCE / "content/full-content.json"),
        "combatRulesSha256": core.file_sha(SOURCE / "domain/rules/combat.gd"),
        "balanceSimSha256": core.file_sha(SOURCE / "tools/balance_sim.gd"),
        "policySha256": core.file_sha(SOURCE / "tools/balance_policy.gd"),
        "probeSha256": core.file_sha(
            SOURCE / "tools/research_421_hearth_observation_probe.gd"),
        "probeUidSha256": core.file_sha(
            SOURCE / "tools/research_421_hearth_observation_probe.gd.uid"),
        "runnerSha256": core.file_sha(Path(__file__)),
        "gate0Sha256": core.file_sha(
            core.ROOT / "summaries/post-v30-hearth-observation-resolution-gate0-v1.json"),
        "taskCapsuleSha256": core.file_sha(core.ROOT / "task-capsule.json"),
    }


def remaining(deadline: float) -> int:
    seconds = int(deadline - time.monotonic())
    if seconds < 1:
        raise TimeoutError("Hearth observation Gate 1 exceeded its wall-time ceiling")
    return seconds


def run_probe(
    plan: dict[str, Any], deadline: float,
) -> tuple[dict[str, Any], str, str]:
    plan_sha, plan_path = core.cache_json(plan)
    core.WORK.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(
        dir=core.WORK, prefix="hearth-observation-gate1-"
    ) as tmp:
        output_path = Path(tmp) / "output.json"
        result = subprocess.run(
            [str(GODOT), "--headless", "-s", PROBE, "--",
             f"--plan={plan_path}", f"--out={output_path}"],
            cwd=SOURCE, text=True, capture_output=True,
            timeout=remaining(deadline),
        )
        if result.returncode or not output_path.is_file():
            raise RuntimeError(
                f"probe failed ({result.returncode})\n"
                f"{result.stdout[-2000:]}\n{result.stderr[-4000:]}"
            )
        output = json.loads(output_path.read_text())
    require("plan identity", output.get("planSha256") == plan_sha)
    output_sha, _ = core.cache_json(output)
    return output, plan_sha, output_sha


def controlled_plan(protocol: dict[str, Any], protocol_sha: str) -> dict[str, Any]:
    rows: list[dict[str, Any]] = []
    for state in protocol["controlledStates"]:
        for capture in (False, True):
            rows.append({**state, "capture": capture})
    return {
        "schemaVersion": 1,
        "protocolSha256": protocol_sha,
        "mode": "controlled",
        "content": str(SOURCE / "content/full-content.json"),
        "rows": rows,
    }


def whole_specs(protocol: dict[str, Any]) -> list[dict[str, Any]]:
    cohort = protocol["identityCohort"]
    return [
        {
            "policyRoot": cohort["policyRoot"],
            "policyIndex": policy,
            "seed": seed,
            "aspect": cohort["aspect"],
            "vow": cohort["vow"],
        }
        for policy in cohort["policyIndices"]
        for seed in cohort["simulationSeeds"]
    ]


def whole_plan(
    protocol: dict[str, Any], protocol_sha: str, capture: bool,
) -> dict[str, Any]:
    return {
        "schemaVersion": 1,
        "protocolSha256": protocol_sha,
        "mode": "whole-runs",
        "capture": capture,
        "content": str(SOURCE / "content/full-content.json"),
        "rows": whole_specs(protocol),
    }


def expected_event(state: dict[str, Any]) -> dict[str, Any]:
    owned = "crownOfTheHearth" in state["relics"]
    embers = int(state["embers"])
    branch = owned and embers > 0
    requested = embers * 3 if branch else 0
    actual = min(requested, int(state["maxHp"]) - int(state["hp"])) if branch else 0
    return {
        "fight": state["fight"],
        "event": 0,
        "crownOwned": owned,
        "embers": embers,
        "branchExecuted": branch,
        "procExecuted": branch,
        "procQueueEvent": 0 if branch else -1,
        "procQueueMatched": branch,
        "hpBefore": state["hp"],
        "requestedHealInput": requested,
        "actualHeal": actual,
        "hpAfter": int(state["hp"]) + actual,
        "payloadEmitted": True,
    }


def expected_control(state: dict[str, Any], capture: bool) -> dict[str, Any]:
    event = expected_event(state)
    queue = []
    if event["branchExecuted"]:
        queue.append({"t": "relicProc", "id": "crownOfTheHearth"})
    queue.append({"t": "victory", "perfect": False})
    return {
        "state": state["state"],
        "capture": capture,
        "fight": state["fight"],
        "hp": event["hpAfter"],
        "maxHp": state["maxHp"],
        "relics": state["relics"],
        "embers": state["embers"],
        "result": "win",
        "over": True,
        "queue": queue,
        "rngBefore": 0,
        "rngAfter": 0,
        "trace": {
            "captureHearth": capture,
            "hearthBranchEvents": [event] if capture else [],
        },
    }


def check_controls(
    output: dict[str, Any], protocol: dict[str, Any],
) -> dict[str, int]:
    rows = output.get("rows")
    require("controlled row array", isinstance(rows, list))
    expected = [
        expected_control(state, capture)
        for state in protocol["controlledStates"]
        for capture in (False, True)
    ]
    require("controlled row count", len(rows) == len(expected))
    mismatches = sum(row != wanted for row, wanted in zip(rows, expected))
    require("controlled exact mapping", mismatches == 0)
    emitted = sum(
        len(row["trace"]["hearthBranchEvents"]) for row in rows
        if row["capture"] is True
    )
    require("controlled event correspondence", emitted == len(protocol["controlledStates"]))
    return {"rows": len(rows), "mismatches": mismatches, "events": emitted}


def indexed(rows: list[dict[str, Any]]) -> dict[tuple[int, int], dict[str, Any]]:
    result: dict[tuple[int, int], dict[str, Any]] = {}
    for row in rows:
        key = (int(row["policyIndex"]), int(row["seed"]))
        require(f"unique whole-run identity {key}", key not in result)
        result[key] = row
    return result


def without_capture(row: dict[str, Any]) -> dict[str, Any]:
    result = copy.deepcopy(row)
    trace = result["researchTrace"]
    trace.pop("captureHearth", None)
    trace.pop("hearthBranchEvents", None)
    return result


def check_event(event: dict[str, Any], expected_fight: int) -> None:
    require("event schema", set(event) == {
        "fight", "event", "crownOwned", "embers", "branchExecuted",
        "procExecuted", "procQueueEvent", "procQueueMatched", "hpBefore",
        "requestedHealInput", "actualHeal", "hpAfter", "payloadEmitted",
    })
    require("event fight identity", event["fight"] == expected_fight)
    require("event identity type", isinstance(event["event"], int) and event["event"] >= 0)
    require("owned type", isinstance(event["crownOwned"], bool))
    require("Ember type", isinstance(event["embers"], int) and event["embers"] >= 0)
    branch = event["crownOwned"] and event["embers"] > 0
    require("branch predicate", event["branchExecuted"] is branch)
    require("proc execution", event["procExecuted"] is branch)
    require("payload emission", event["payloadEmitted"] is True)
    require("requested heal", event["requestedHealInput"] == (event["embers"] * 3 if branch else 0))
    require("actual heal type", isinstance(event["actualHeal"], int) and event["actualHeal"] >= 0)
    require("HP transition", event["hpAfter"] - event["hpBefore"] == event["actualHeal"])
    require("proc queue correspondence", event["procQueueMatched"] is branch)
    require("proc queue identity", event["procQueueEvent"] == event["event"] if branch
            else event["procQueueEvent"] == -1)


def check_whole_runs(
    off_output: dict[str, Any], on_output: dict[str, Any], protocol: dict[str, Any],
) -> dict[str, Any]:
    off_rows = off_output.get("rows")
    on_rows = on_output.get("rows")
    require("capture-off row array", isinstance(off_rows, list))
    require("capture-on row array", isinstance(on_rows, list))
    expected_count = len(whole_specs(protocol))
    require("capture-off row count", len(off_rows) == expected_count)
    require("capture-on row count", len(on_rows) == expected_count)
    off = indexed(off_rows)
    on = indexed(on_rows)
    require("whole-run cohort identity", set(off) == set(on))
    core_mismatches = 0
    rng_mismatches = 0
    policy_mismatches = 0
    path_mismatches = 0
    result_mismatches = 0
    reliability_faults = 0
    emitted = 0
    positive = 0
    for key in sorted(off):
        off_row = off[key]
        on_row = on[key]
        core_mismatches += without_capture(off_row) != without_capture(on_row)
        rng_mismatches += off_row["rng"] != on_row["rng"]
        policy_mismatches += off_row["policy"] != on_row["policy"]
        result_mismatches += (
            off_row["outcome"] != on_row["outcome"]
            or off_row["hp"] != on_row["hp"]
            or off_row["maxHp"] != on_row["maxHp"]
        )
        path_mismatches += (
            off_row["researchTrace"]["nodePath"] != on_row["researchTrace"]["nodePath"]
            or off_row["researchTrace"]["fightPath"] != on_row["researchTrace"]["fightPath"]
        )
        require(f"capture-off events {key}",
                off_row["researchTrace"]["hearthBranchEvents"] == [])
        events = on_row["researchTrace"]["hearthBranchEvents"]
        wins = [index for index, fight in enumerate(on_row["fights"])
                if fight["result"] == "win"]
        require(f"event count {key}", len(events) == len(wins))
        require(f"unique event identities {key}",
                len({(event["fight"], event["event"]) for event in events}) == len(events))
        for event, fight_index in zip(events, wins):
            check_event(event, fight_index)
            positive += bool(event["branchExecuted"])
        emitted += len(events)
        reliability_faults += sum(
            row.get("outcome") in ("error", "stall") or bool(row.get("error"))
            for row in (off_row, on_row)
        )
    require("whole-run core identity", core_mismatches == 0)
    require("whole-run RNG identity", rng_mismatches == 0)
    require("whole-run policy identity", policy_mismatches == 0)
    require("whole-run path identity", path_mismatches == 0)
    require("whole-run result identity", result_mismatches == 0)
    require("whole-run reliability", reliability_faults == 0)
    return {
        "identities": expected_count,
        "coreMismatchRows": core_mismatches,
        "rngMismatchRows": rng_mismatches,
        "policyMismatchRows": policy_mismatches,
        "pathMismatchRows": path_mismatches,
        "resultMismatchRows": result_mismatches,
        "reliabilityFaultRows": reliability_faults,
        "captureOnEvents": emitted,
        "positiveBranchEvents": positive,
    }


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite Hearth observation Gate 1 summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    source = source_identity()
    for key, expected in protocol["immutableInputs"].items():
        require(f"immutable {key}", source.get(key) == expected)
    ledger_before = ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
    started = time.monotonic()
    deadline = started + float(protocol["budget"]["maximumWallTimeSeconds"])
    manifests: dict[str, Any] = {}
    controls: dict[str, Any] = {}
    identity: dict[str, Any] = {}
    observed_rows = 0
    process_count = 0
    failure = ""
    try:
        control_output, plan_sha, output_sha = run_probe(
            controlled_plan(protocol, protocol_sha), deadline)
        process_count += 1
        controls = check_controls(control_output, protocol)
        manifests["controlled"] = {"planSha256": plan_sha, "outputSha256": output_sha}
        off_output, plan_sha, output_sha = run_probe(
            whole_plan(protocol, protocol_sha, False), deadline)
        process_count += 1
        observed_rows += len(off_output["rows"])
        manifests["captureOff"] = {"planSha256": plan_sha, "outputSha256": output_sha}
        on_output, plan_sha, output_sha = run_probe(
            whole_plan(protocol, protocol_sha, True), deadline)
        process_count += 1
        observed_rows += len(on_output["rows"])
        manifests["captureOn"] = {"planSha256": plan_sha, "outputSha256": output_sha}
        identity = check_whole_runs(off_output, on_output, protocol)
        require("observation row cap", observed_rows
                == protocol["budget"]["maximumWholeRunIdentityObservationRows"])
        require("Godot process cap", process_count
                == protocol["budget"]["maximumGodotProcesses"])
    except (KeyError, RuntimeError, subprocess.TimeoutExpired, TimeoutError,
            TypeError, ValueError) as error:
        failure = str(error)

    elapsed = time.monotonic() - started
    ledger_after = ledger_identity()
    if elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        failure = failure or "wall-time ceiling"
    if ledger_after != ledger_before:
        failure = failure or "ledger identity drift"
    success = not failure
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "decisionBoundary": 1 if success else 2,
        "decision": (
            "gate1-identity-green-authorise-gate2-preregistration"
            if success else "quarantine-hearth-gate1-identity-failure"
        ),
        "failure": failure,
        "protocolSha256": protocol_sha,
        "sourceIdentity": source,
        "controlled": controls,
        "wholeRunIdentity": identity,
        "execution": {
            "manifests": manifests,
            "wholeRunIdentityObservationRows": observed_rows,
            "controlledExecutions": controls.get("rows", 0),
            "GodotProcesses": process_count,
            "newLedgerRows": ledger_after["records"] - ledger_before["records"],
            "protectedSeedRows": ledger_after["protectedSeedRows"],
            "causalRows": 0,
            "causalEndpointsInspected": 0,
            "causalFits": 0,
            "maximumModelContextTokens": 0,
            "wallTimeSeconds": elapsed,
        },
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "authority": (
            protocol["decisionRules"]["successAuthority"]
            if success else protocol["decisionRules"]["failureAuthority"]
        ),
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": "PASS" if success else "FAIL",
        "decision": summary["decision"],
        "summarySha256": core.file_sha(SUMMARY),
    }))
    if not success:
        sys.exit(2)


if __name__ == "__main__":
    main()
