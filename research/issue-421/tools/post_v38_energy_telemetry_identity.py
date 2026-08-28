#!/usr/bin/env python3
"""Energy-event telemetry identity preflight for issue #421."""

from __future__ import annotations

import json
import subprocess
import tempfile
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-energy-telemetry-identity-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-energy-telemetry-identity-v1.json"
SOURCE = core.ROOT / "energy-telemetry-source"
PROBE = "res://tools/research_421_null_harness_probe.gd"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Energy telemetry identity mismatch: {label}")


def run_probe(
    plan: dict[str, Any], godot: str, timeout: int,
) -> tuple[dict[str, Any], str, str]:
    plan_sha, plan_path = core.cache_json(plan)
    with tempfile.TemporaryDirectory(prefix="issue-421-energy-identity-") as tmp:
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


def without_energy_events(row: dict[str, Any]) -> dict[str, Any]:
    result = dict(row)
    trace = dict(result["trajectory"])
    trace.pop("energies")
    result["trajectory"] = trace
    return result


def trace_schema_faults(rows: list[dict[str, Any]]) -> list[str]:
    faults: list[str] = []
    expected_trace = {
        "capture", "nodes", "turns", "energies", "draws", "plays", "kindles",
        "cardRewards", "bossRelics",
    }
    for row_index, row in enumerate(rows):
        trace = row.get("trajectory")
        if not isinstance(trace, dict) or set(trace) != expected_trace:
            faults.append(f"row-{row_index}:trajectory")
            continue
        energies = trace["energies"]
        if not isinstance(energies, list) or not energies:
            faults.append(f"row-{row_index}:energies")
            continue
        by_fight: dict[int, list[dict[str, Any]]] = {}
        previous = (-1, -1)
        for event_index, event in enumerate(energies):
            if not isinstance(event, dict) or set(event) != {"fight", "event", "n"}:
                faults.append(f"row-{row_index}:energy-{event_index}-schema")
                continue
            current = (int(event["fight"]), int(event["event"]))
            if current <= previous or current[0] < 0 or current[1] < 0 or int(event["n"]) < 0:
                faults.append(f"row-{row_index}:energy-{event_index}-value")
            previous = current
            by_fight.setdefault(current[0], []).append(event)
        turns_by_fight: dict[int, list[int]] = {}
        for event in trace["turns"]:
            turns_by_fight.setdefault(int(event["fight"]), []).append(int(event["event"]))
        for fight, turn_events in turns_by_fight.items():
            energy_events = [int(event["event"]) for event in by_fight.get(fight, [])]
            for turn_index, turn_event in enumerate(turn_events):
                next_turn = (turn_events[turn_index + 1]
                             if turn_index + 1 < len(turn_events) else None)
                if not any(event > turn_event and (next_turn is None or event < next_turn)
                           for event in energy_events):
                    faults.append(f"row-{row_index}:fight-{fight}-turn-{turn_index}-energy")
        energy_keys = {(int(event["fight"]), int(event["event"])) for event in energies}
        for play_index, play in enumerate(trace["plays"]):
            if (int(play["fight"]), int(play["event"]) + 1) not in energy_keys:
                faults.append(f"row-{row_index}:play-{play_index}-energy")
    return faults


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the energy telemetry summary")
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
    anchor_rows = json.loads(anchor_path.read_text())["rows"]
    cohort = protocol["cohort"]
    specs = [
        {
            "aspect": cohort["aspect"], "vow": cohort["vow"], "seed": seed,
            "policyRoot": cohort["policyRoot"], "policyIndex": policy_index,
            "arm": "energy-telemetry-explicit-null", "captureTrace": True,
            "explicitNull": True,
        }
        for policy_index in range(cohort["policyCount"])
        for seed in cohort["simulationSeeds"]
    ]
    require("cohort rectangle", len(specs) == cohort["rows"] == len(anchor_rows))
    ledger_before = identity.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
    plan = {
        "schemaVersion": 1, "protocolSha256": protocol_sha,
        "arm": "energy-telemetry-explicit-null", "content": str(content_path),
        "rows": specs,
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
            "anchorWithoutEnergyEventsMismatchRows": sum(
                left != without_energy_events(right)
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
            decision = "record-energy-telemetry-identity-inconclusive-at-cap"
        elif all(value == 0 for value in identity_counts.values()) and not faults:
            boundary = 1
            outcome_class = "success"
            decision = "freeze-energy-event-telemetry"
        else:
            boundary = 2
            outcome_class = "futility"
            decision = "close-energy-event-telemetry-on-identity-failure"
    except (RuntimeError, subprocess.TimeoutExpired, KeyError, TypeError, ValueError) as error:
        boundary = 3
        outcome_class = "inconclusive"
        decision = "record-energy-telemetry-identity-inconclusive-on-unavailable-execution"
        cache_objects["executionError"] = str(error)
    elapsed = time.monotonic() - started
    ledger_after = identity.ledger_identity()
    require("zero-row ledger identity", ledger_after == ledger_before)
    summary = {
        "schemaVersion": 1, "issue": 421, "decisionBoundary": boundary,
        "decision": decision, "outcomeClass": outcome_class,
        "protocolSha256": protocol_sha, "runnerSha256": core.file_sha(Path(__file__)),
        "sourceCommit": head, "godotVersion": version,
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
