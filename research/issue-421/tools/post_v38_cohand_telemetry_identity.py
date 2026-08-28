#!/usr/bin/env python3
"""TURN/KINDLE telemetry identity preflight for issue #421."""

from __future__ import annotations

import json
import subprocess
import tempfile
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-cohand-telemetry-identity-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-cohand-telemetry-identity-v1.json"
SOURCE = core.ROOT / "cohand-telemetry-source"
PROBE = "res://tools/research_421_null_harness_probe.gd"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Co-hand telemetry identity mismatch: {label}")


def run_probe(
    plan: dict[str, Any], godot: str, timeout: int,
) -> tuple[dict[str, Any], str, str]:
    plan_sha, plan_path = core.cache_json(plan)
    with tempfile.TemporaryDirectory(prefix="issue-421-cohand-identity-") as tmp:
        output_path = Path(tmp) / "output.json"
        result = subprocess.run(
            [godot, "--headless", "-s", PROBE, "--",
             f"--plan={plan_path}", f"--out={output_path}"],
            cwd=SOURCE, text=True, capture_output=True, timeout=timeout,
        )
        if result.returncode or not output_path.is_file():
            raise RuntimeError(
                f"probe failed ({result.returncode})\n"
                f"{result.stdout[-2000:]}\n{result.stderr[-4000:]}"
            )
        output = json.loads(output_path.read_text())
    output_sha, _ = core.cache_json(output)
    return output, plan_sha, output_sha


def without_cohand_events(row: dict[str, Any]) -> dict[str, Any]:
    result = dict(row)
    trace = dict(result["trajectory"])
    trace.pop("turns")
    trace.pop("kindles")
    result["trajectory"] = trace
    return result


def trace_schema_faults(rows: list[dict[str, Any]]) -> list[str]:
    faults: list[str] = []
    expected_trace = {
        "capture", "nodes", "turns", "draws", "plays", "kindles",
        "cardRewards", "bossRelics",
    }
    for row_index, row in enumerate(rows):
        trace = row.get("trajectory")
        if not isinstance(trace, dict) or set(trace) != expected_trace:
            faults.append(f"row-{row_index}:trajectory")
            continue
        turns = trace["turns"]
        kindles = trace["kindles"]
        if not isinstance(turns, list) or not turns:
            faults.append(f"row-{row_index}:turns")
            continue
        turn_numbers: dict[int, list[int]] = {}
        for event_index, event in enumerate(turns):
            if not isinstance(event, dict) or set(event) != {"fight", "event", "n"}:
                faults.append(f"row-{row_index}:turn-{event_index}-schema")
                continue
            fight = int(event["fight"])
            number = int(event["n"])
            if fight < 0 or int(event["event"]) < 0 or number < 1:
                faults.append(f"row-{row_index}:turn-{event_index}-value")
            turn_numbers.setdefault(fight, []).append(number)
        for fight, numbers in turn_numbers.items():
            if numbers != list(range(1, len(numbers) + 1)):
                faults.append(f"row-{row_index}:fight-{fight}-turn-sequence")
        if not isinstance(kindles, list):
            faults.append(f"row-{row_index}:kindles")
            continue
        for event_index, event in enumerate(kindles):
            if not isinstance(event, dict) or set(event) != {"fight", "event", "id", "uid"}:
                faults.append(f"row-{row_index}:kindle-{event_index}-schema")
            elif (int(event["fight"]) < 0 or int(event["event"]) < 0
                  or not isinstance(event["id"], str) or not event["id"]
                  or int(event["uid"]) < 0):
                faults.append(f"row-{row_index}:kindle-{event_index}-value")
        drawn = {(int(event["fight"]), int(event["uid"]))
                 for event in trace["draws"]}
        for field in ("plays", "kindles"):
            for event_index, event in enumerate(trace[field]):
                if (int(event["fight"]), int(event["uid"])) not in drawn:
                    faults.append(f"row-{row_index}:{field}-{event_index}-not-drawn")
    return faults


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the co-hand telemetry summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    immutable = protocol["immutableInputs"]
    require("runner SHA", core.file_sha(Path(__file__)) == immutable["runnerSha256"])
    head = subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=SOURCE, check=True,
        text=True, capture_output=True,
    ).stdout.strip()
    require("source commit", head == immutable["sourceCommit"])
    for path, expected in immutable["sourceSha256"].items():
        require(f"source {path}", core.file_sha(SOURCE / path) == expected)
    for path, expected in immutable["fileSha256"].items():
        require(path, core.file_sha(core.ROOT / path) == expected)
    godot = immutable["godotBinaryPath"]
    require("Godot binary SHA", core.file_sha(Path(godot)) == immutable["godotBinarySha256"])
    version = subprocess.run(
        [godot, "--version"], check=True, text=True, capture_output=True,
    ).stdout.strip()
    require("Godot version", version == immutable["godotVersion"])
    content_path = core.CACHE / f"{immutable['contentSha256']}.json"
    require("content SHA", core.file_sha(content_path) == immutable["contentSha256"])
    anchor_path = core.CACHE / f"{immutable['anchorOutputSha256']}.json"
    require("anchor output SHA", core.file_sha(anchor_path) == immutable["anchorOutputSha256"])
    anchor_output = json.loads(anchor_path.read_text())
    cohort = protocol["cohort"]
    rows = []
    for policy_index in range(cohort["policyCount"]):
        for seed in cohort["simulationSeeds"]:
            rows.append({
                "aspect": cohort["aspect"], "vow": cohort["vow"], "seed": seed,
                "policyRoot": cohort["policyRoot"], "policyIndex": policy_index,
                "arm": "cohand-telemetry-explicit-null", "captureTrace": True,
                "explicitNull": True,
            })
    require("cohort rectangle", len(rows) == cohort["rows"])
    anchor_rows = anchor_output["rows"]
    require("anchor rectangle", len(anchor_rows) == len(rows))
    ledger_before = identity.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
    plan = {
        "schemaVersion": 1, "protocolSha256": protocol_sha,
        "arm": "cohand-telemetry-explicit-null", "content": str(content_path),
        "rows": rows,
    }
    started = time.monotonic()
    cap = protocol["budget"]["maximumWallTimeSeconds"]
    cache_objects: dict[str, str] = {}
    observed_rows = 0
    faults: list[str] = []
    identity_counts: dict[str, int] = {}
    try:
        output, plan_sha, output_sha = run_probe(plan, godot, cap)
        cache_objects = {"planSha256": plan_sha, "outputSha256": output_sha}
        observed = output["rows"]
        observed_rows = len(observed)
        require("observed rectangle", observed_rows == len(anchor_rows))
        identity_counts = {
            "anchorWithoutCohandEventsMismatchRows": sum(
                left != without_cohand_events(right)
                for left, right in zip(anchor_rows, observed)
            ),
            "rngMismatchRows": sum(
                left["rng"] != right["rng"] for left, right in zip(anchor_rows, observed)
            ),
            "policyMismatchRows": sum(
                left["policy"] != right["policy"]
                for left, right in zip(anchor_rows, observed)
            ),
        }
        faults = trace_schema_faults(observed)
        elapsed = time.monotonic() - started
        if elapsed > cap:
            boundary = 3
            outcome_class = "inconclusive"
            decision = "record-cohand-telemetry-identity-inconclusive-at-cap"
        elif all(value == 0 for value in identity_counts.values()) and not faults:
            boundary = 1
            outcome_class = "success"
            decision = "freeze-turn-and-kindle-telemetry"
        else:
            boundary = 2
            outcome_class = "futility"
            decision = "close-turn-and-kindle-telemetry-on-identity-failure"
    except (RuntimeError, subprocess.TimeoutExpired, KeyError, TypeError, ValueError) as error:
        boundary = 3
        outcome_class = "inconclusive"
        decision = "record-cohand-telemetry-identity-inconclusive-on-unavailable-execution"
        cache_objects["executionError"] = str(error)
    elapsed = time.monotonic() - started
    ledger_after = identity.ledger_identity()
    require("zero-row ledger identity", ledger_after == ledger_before)
    summary = {
        "schemaVersion": 1, "issue": 421, "decisionBoundary": boundary,
        "decision": decision, "outcomeClass": outcome_class,
        "protocolSha256": protocol_sha, "runnerSha256": core.file_sha(Path(__file__)),
        "sourceCommit": immutable["sourceCommit"], "godotVersion": version,
        "identity": identity_counts, "traceSchemaFaults": faults,
        "cacheObjects": cache_objects, "rowsPerArm": cohort["rows"],
        "newSimulatorObservationRows": observed_rows, "newLedgerRows": 0,
        "ledgerBefore": ledger_before, "ledgerAfter": ledger_after,
        "protectedSeedRows": ledger_after["protectedSeedRows"],
        "maximumModelContextTokens": 0, "wallTimeSeconds": elapsed,
        "factorDisposition": protocol["factorDisposition"],
        "authority": protocol["decisionRules"][f"{outcome_class}Authority"],
    }
    SUMMARY.parent.mkdir(parents=True, exist_ok=True)
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": "PASS", "decision": decision, "decisionBoundary": boundary,
        "newSimulatorObservationRows": observed_rows,
        "summarySha256": core.file_sha(SUMMARY),
    }))


if __name__ == "__main__":
    main()
