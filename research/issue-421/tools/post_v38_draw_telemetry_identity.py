#!/usr/bin/env python3
"""Fight-scoped draw telemetry identity preflight for issue #421."""

from __future__ import annotations

import json
import subprocess
import tempfile
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-draw-telemetry-identity-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-draw-telemetry-identity-v1.json"
SOURCE = core.ROOT / "draw-telemetry-source"
PROBE = "res://tools/research_421_null_harness_probe.gd"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Draw-telemetry identity mismatch: {label}")


def run_probe(
    plan: dict[str, Any], godot: str, timeout: int,
) -> tuple[dict[str, Any], str, str]:
    plan_sha, plan_path = core.cache_json(plan)
    with tempfile.TemporaryDirectory(prefix="issue-421-draw-identity-") as tmp:
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


def without_draws(row: dict[str, Any]) -> dict[str, Any]:
    result = dict(row)
    trace = dict(result["trajectory"])
    trace.pop("draws")
    result["trajectory"] = trace
    return result


def draw_schema_faults(rows: list[dict[str, Any]]) -> list[str]:
    faults: list[str] = []
    expected_trace = {"capture", "nodes", "draws", "plays", "cardRewards", "bossRelics"}
    expected_draw = {"fight", "event", "id", "uid"}
    for row_index, row in enumerate(rows):
        trace = row.get("trajectory")
        if not isinstance(trace, dict) or set(trace) != expected_trace:
            faults.append(f"row-{row_index}:trajectory")
            continue
        draws = trace["draws"]
        if not isinstance(draws, list) or not draws:
            faults.append(f"row-{row_index}:draws")
            continue
        for draw_index, draw in enumerate(draws):
            if not isinstance(draw, dict) or set(draw) != expected_draw:
                faults.append(f"row-{row_index}:draw-{draw_index}-schema")
            elif (int(draw["fight"]) < 0 or int(draw["event"]) < 0
                  or not isinstance(draw["id"], str) or not draw["id"]
                  or int(draw["uid"]) < 0):
                faults.append(f"row-{row_index}:draw-{draw_index}-value")
    return faults


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the draw-telemetry identity summary")
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
                "arm": "draw-telemetry-explicit-null", "captureTrace": True,
                "explicitNull": True,
            })
    require("cohort rectangle", len(rows) == cohort["rows"])
    anchor_rows = anchor_output["rows"][cohort["anchorStart"]:cohort["anchorStop"]]
    require("anchor rectangle", len(anchor_rows) == len(rows))
    ledger_before = identity.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
    plan = {
        "schemaVersion": 1, "protocolSha256": protocol_sha,
        "arm": "draw-telemetry-explicit-null", "content": str(content_path),
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
            "anchorWithoutDrawsMismatchRows": sum(
                left != without_draws(right)
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
        faults = draw_schema_faults(observed)
        elapsed = time.monotonic() - started
        if elapsed > cap:
            boundary = 3
            outcome_class = "inconclusive"
            decision = "record-draw-telemetry-identity-inconclusive-at-cap"
        elif all(value == 0 for value in identity_counts.values()) and not faults:
            boundary = 1
            outcome_class = "success"
            decision = "freeze-fight-scoped-draw-telemetry"
        else:
            boundary = 2
            outcome_class = "futility"
            decision = "close-fight-scoped-draw-telemetry-on-identity-failure"
    except (RuntimeError, subprocess.TimeoutExpired, KeyError, TypeError, ValueError) as error:
        boundary = 3
        outcome_class = "inconclusive"
        decision = "record-draw-telemetry-identity-inconclusive-on-unavailable-execution"
        cache_objects["executionError"] = str(error)
    elapsed = time.monotonic() - started
    ledger_after = identity.ledger_identity()
    require("zero-row ledger identity", ledger_after == ledger_before)
    summary = {
        "schemaVersion": 1, "issue": 421, "decisionBoundary": boundary,
        "decision": decision, "outcomeClass": outcome_class,
        "protocolSha256": protocol_sha, "runnerSha256": core.file_sha(Path(__file__)),
        "sourceCommit": immutable["sourceCommit"], "godotVersion": version,
        "identity": identity_counts, "drawSchemaFaults": faults,
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
