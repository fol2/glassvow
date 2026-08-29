#!/usr/bin/env python3
"""Exact-null RESHUFFLE trace identity preflight for issue #421."""

from __future__ import annotations

import copy
import json
import subprocess
import tempfile
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as ledger
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-reshuffle-trace-identity-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-reshuffle-trace-identity-v1.json"
SOURCE = core.ROOT / "reshuffle-observation-v1-source"
PROBE = "res://tools/research_421_null_harness_probe.gd"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Reshuffle trace identity mismatch: {label}")


def run_probe(
    plan: dict[str, Any], godot: str, timeout: int,
) -> tuple[dict[str, Any], str, str]:
    plan_sha, plan_path = core.cache_json(plan)
    with tempfile.TemporaryDirectory(prefix="issue-421-reshuffle-trace-") as tmp:
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


def without_reshuffles(row: dict[str, Any]) -> dict[str, Any]:
    result = copy.deepcopy(row)
    result["trajectory"].pop("reshuffles")
    return result


def trace_faults(
    rows: list[dict[str, Any]], anchor_trace_keys: set[str],
) -> list[str]:
    faults: list[str] = []
    for row_index, row in enumerate(rows):
        trace = row.get("trajectory")
        if not isinstance(trace, dict) or set(trace) != anchor_trace_keys | {"reshuffles"}:
            faults.append(f"row-{row_index}:trajectory")
            continue
        fights = row.get("fights", [])
        draw_orders = {
            (event["fight"], event["event"])
            for event in trace["draws"]
            if isinstance(event, dict) and "fight" in event and "event" in event
        }
        last_event: dict[int, int] = {}
        for event_index, event in enumerate(trace["reshuffles"]):
            if not isinstance(event, dict) or set(event) != {"fight", "event", "n"}:
                faults.append(f"row-{row_index}:reshuffle-{event_index}-schema")
                continue
            fight, order, count = event["fight"], event["event"], event["n"]
            if (not isinstance(fight, int) or isinstance(fight, bool)
                    or not isinstance(order, int) or isinstance(order, bool)
                    or not isinstance(count, int) or isinstance(count, bool)
                    or fight < 0 or fight >= len(fights) or order < 0 or count <= 0):
                faults.append(f"row-{row_index}:reshuffle-{event_index}-value")
                continue
            if order <= last_event.get(fight, -1):
                faults.append(f"row-{row_index}:reshuffle-{event_index}-order")
            last_event[fight] = order
            if (fight, order + 1) not in draw_orders:
                faults.append(f"row-{row_index}:reshuffle-{event_index}-next-draw")
    return faults


def self_check() -> None:
    anchor = {"fights": [{}], "trajectory": {"draws": [
        {"fight": 0, "event": 3, "id": "x", "uid": 1},
    ]}}
    observed = copy.deepcopy(anchor)
    observed["trajectory"]["reshuffles"] = [{"fight": 0, "event": 2, "n": 4}]
    require("strip self-check", without_reshuffles(observed) == anchor)
    require("schema self-check", not trace_faults(
        [observed], set(anchor["trajectory"])
    ))


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the reshuffle trace summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    immutable = protocol["immutableInputs"]
    require("runner SHA", core.file_sha(Path(__file__)) == immutable["runnerSha256"])
    self_check()
    require(
        "task capsule SHA",
        core.file_sha(core.ROOT / immutable["taskCapsulePath"])
        == immutable["taskCapsuleSha256"],
    )
    for path, expected in immutable["researchFileSha256"].items():
        require(f"research file {path}", core.file_sha(core.ROOT / path) == expected)

    repository = Path(immutable["repositoryPath"])
    for ref, expected in immutable["repositoryRefs"].items():
        actual = subprocess.run(
            ["git", "rev-parse", ref], cwd=repository, check=True,
            text=True, capture_output=True,
        ).stdout.strip()
        require(f"repository ref {ref}", actual == expected)
    head = subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=SOURCE, check=True,
        text=True, capture_output=True,
    ).stdout.strip()
    require("source head", head == immutable["sourceHead"])
    for path, expected in immutable["sourceSha256"].items():
        require(f"source {path}", core.file_sha(SOURCE / path) == expected)
    patch = subprocess.run(
        ["git", "diff", "--cached", "--binary"], cwd=SOURCE,
        check=True, capture_output=True,
    ).stdout
    require("source patch SHA", core.sha(patch) == immutable["sourcePatchSha256"])

    godot = immutable["godotBinaryPath"]
    require("Godot binary SHA", core.file_sha(Path(godot)) == immutable["godotBinarySha256"])
    version = subprocess.run(
        [godot, "--version"], check=True, text=True, capture_output=True,
    ).stdout.strip()
    require("Godot version", version == immutable["godotVersion"])

    anchor_plan_path = core.CACHE / f"{immutable['anchorPlanSha256']}.json"
    anchor_output_path = core.CACHE / f"{immutable['anchorOutputSha256']}.json"
    content_path = core.CACHE / f"{immutable['contentSha256']}.json"
    require("anchor plan SHA", core.file_sha(anchor_plan_path) == immutable["anchorPlanSha256"])
    require("anchor output SHA", core.file_sha(anchor_output_path) == immutable["anchorOutputSha256"])
    require("content SHA", core.file_sha(content_path) == immutable["contentSha256"])
    anchor_plan = json.loads(anchor_plan_path.read_text())
    anchor_output = json.loads(anchor_output_path.read_text())
    cohort = protocol["cohort"]
    require("anchor plan rectangle", len(anchor_plan["rows"]) == cohort["rows"])
    require("anchor output rectangle", len(anchor_output["rows"]) == cohort["rows"])
    require("anchor output identity", anchor_output["planSha256"] == immutable["anchorPlanSha256"])
    require("anchor plan arm", anchor_plan["arm"] == "target-death-trace-explicit-null")
    for spec in anchor_plan["rows"]:
        require("anchor row arm", spec.get("arm") == "cohand-telemetry-explicit-null")
        require("anchor capture", spec.get("captureTrace") is True)
        require("anchor explicit null", spec.get("explicitNull") is True)

    ledger_before = ledger.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
    plan = {
        "schemaVersion": 1,
        "protocolSha256": protocol_sha,
        "arm": "reshuffle-trace-explicit-null",
        "content": str(content_path),
        "rows": copy.deepcopy(anchor_plan["rows"]),
    }
    started = time.monotonic()
    cap = protocol["budget"]["maximumWallTimeSeconds"]
    cache_objects: dict[str, str] = {}
    observed_rows = 0
    identity: dict[str, int] = {}
    faults: list[str] = []
    telemetry: dict[str, int] = {}
    checks: dict[str, bool] = {}
    try:
        output, plan_sha, output_sha = run_probe(plan, godot, cap)
        cache_objects = {"planSha256": plan_sha, "outputSha256": output_sha}
        observed = output["rows"]
        observed_rows = len(observed)
        require("observed rectangle", observed_rows == cohort["rows"])
        anchor_rows = anchor_output["rows"]
        identity = {
            "strippedRowMismatchRows": sum(
                left != without_reshuffles(right)
                for left, right in zip(anchor_rows, observed)
            ),
            "rngMismatchRows": sum(
                left["rng"] != right["rng"] for left, right in zip(anchor_rows, observed)
            ),
            "policyMismatchRows": sum(
                left["policy"] != right["policy"] for left, right in zip(anchor_rows, observed)
            ),
            "seedMismatchRows": sum(
                left["seed"] != right["seed"] for left, right in zip(anchor_rows, observed)
            ),
        }
        anchor_trace_keys = set(anchor_rows[0]["trajectory"])
        require("one anchor trace schema", all(
            set(row["trajectory"]) == anchor_trace_keys for row in anchor_rows
        ))
        faults = trace_faults(observed, anchor_trace_keys)
        telemetry = {
            "reshuffleEvents": sum(
                len(row["trajectory"]["reshuffles"]) for row in observed
            ),
            "rowsWithReshuffle": sum(
                bool(row["trajectory"]["reshuffles"]) for row in observed
            ),
            "distinctPositiveCounts": len({
                event["n"] for row in observed
                for event in row["trajectory"]["reshuffles"]
            }),
        }
        gates = protocol["gates"]
        checks = {
            "identity": all(value == 0 for value in identity.values()),
            "schema": not faults,
            "reshuffleCoverage": telemetry["reshuffleEvents"] >= gates["minimumReshuffleEvents"],
            "rowCoverage": telemetry["rowsWithReshuffle"] >= gates["minimumRowsWithReshuffle"],
            "countBreadth": telemetry["distinctPositiveCounts"] >= gates["minimumDistinctPositiveCounts"],
        }
        elapsed = time.monotonic() - started
        if elapsed > cap:
            outcome_class, boundary = "inconclusive", 3
            decision = "record-reshuffle-trace-identity-inconclusive-at-cap"
        elif all(checks.values()):
            outcome_class, boundary = "success", 1
            decision = "freeze-reshuffle-trace-for-capacity"
        else:
            outcome_class, boundary = "futility", 2
            decision = "close-reshuffle-trace-on-identity-or-coverage-failure"
    except (RuntimeError, subprocess.TimeoutExpired, KeyError, TypeError, ValueError) as error:
        outcome_class, boundary = "inconclusive", 3
        decision = "record-reshuffle-trace-identity-inconclusive-on-unavailable-execution"
        cache_objects["executionError"] = str(error)
    elapsed = time.monotonic() - started
    ledger_after = ledger.ledger_identity()
    require("zero-row ledger identity", ledger_after == ledger_before)
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "outcomeClass": outcome_class,
        "decisionBoundary": boundary,
        "decision": decision,
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "sourceHead": head,
        "sourcePatchSha256": immutable["sourcePatchSha256"],
        "godotVersion": version,
        "identity": identity,
        "traceSchemaFaults": faults,
        "telemetryCounts": telemetry,
        "checks": checks,
        "cacheObjects": cache_objects,
        "rowsPerArm": cohort["rows"],
        "newSimulatorObservationRows": observed_rows,
        "newLedgerRows": 0,
        "protectedSeedRows": ledger_after["protectedSeedRows"],
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "maximumModelContextTokens": 0,
        "wallTimeSeconds": round(elapsed, 6),
        "claimBoundary": protocol["claimBoundary"],
        "authority": protocol["decisionRules"][f"{outcome_class}Authority"],
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": outcome_class.upper(),
        "decision": decision,
        "newSimulatorObservationRows": observed_rows,
        "identityMismatchRows": identity.get("strippedRowMismatchRows"),
        "reshuffleEvents": telemetry.get("reshuffleEvents"),
        "traceSchemaFaults": len(faults),
    }))


if __name__ == "__main__":
    main()
