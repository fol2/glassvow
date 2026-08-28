#!/usr/bin/env python3
"""Pristine-current-main null-harness identity preflight for issue #421."""

from __future__ import annotations

import json
import subprocess
import tempfile
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-pristine-null-harness-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-pristine-null-harness-v1.json"
PRISTINE = core.ROOT / "null-harness-source"
INSTRUMENTED = core.ROOT / "null-harness-instrumented-source"
PROBE = "res://tools/research_421_null_harness_probe.gd"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Null-harness preflight mismatch: {label}")


def run_probe(
    source: Path, plan: dict[str, Any], godot: str, timeout: int,
) -> tuple[dict[str, Any], str, str]:
    plan_sha, plan_path = core.cache_json(plan)
    with tempfile.TemporaryDirectory(prefix="issue-421-null-harness-") as tmp:
        output_path = Path(tmp) / "output.json"
        result = subprocess.run(
            [godot, "--headless", "-s", PROBE, "--",
             f"--plan={plan_path}", f"--out={output_path}"],
            cwd=source, text=True, capture_output=True, timeout=timeout,
        )
        if result.returncode or not output_path.is_file():
            raise RuntimeError(
                f"probe failed ({result.returncode})\n"
                f"{result.stdout[-2000:]}\n{result.stderr[-4000:]}"
            )
        output = json.loads(output_path.read_text())
    output_sha, _ = core.cache_json(output)
    return output, plan_sha, output_sha


def invalid_configuration_fails(
    protocol_sha: str, content: str, row: dict[str, Any], godot: str, timeout: int,
) -> tuple[bool, str]:
    invalid_row = dict(row)
    invalid_row["research421"] = {"notARegisteredNull": 1}
    plan = {
        "schemaVersion": 1,
        "protocolSha256": protocol_sha,
        "arm": "invalid-configuration",
        "content": content,
        "rows": [invalid_row],
    }
    plan_sha, plan_path = core.cache_json(plan)
    with tempfile.TemporaryDirectory(prefix="issue-421-null-invalid-") as tmp:
        output_path = Path(tmp) / "output.json"
        result = subprocess.run(
            [godot, "--headless", "-s", PROBE, "--",
             f"--plan={plan_path}", f"--out={output_path}"],
            cwd=INSTRUMENTED, text=True, capture_output=True, timeout=timeout,
        )
        output_created = output_path.exists()
    failed = (
        result.returncode != 0
        and not output_created
        and "research421 accepts only the explicit null schemaVersion=1"
        in result.stderr
    )
    return failed, plan_sha


def without_trajectory(row: dict[str, Any]) -> dict[str, Any]:
    result = dict(row)
    result.pop("trajectory", None)
    return result


def trace_schema_faults(rows: list[dict[str, Any]]) -> list[str]:
    faults: list[str] = []
    expected = {"capture", "nodes", "plays", "cardRewards", "bossRelics"}
    entry_keys = {
        "nodes": {"act", "index", "id", "row", "type", "combatKind"},
        "plays": {"fight", "event", "id", "uid"},
        "cardRewards": {"offered", "chosen", "accepted"},
        "bossRelics": {"offered", "chosen"},
    }
    for index, row in enumerate(rows):
        trace = row.get("trajectory")
        if not isinstance(trace, dict) or set(trace) != expected or trace["capture"] is not True:
            faults.append(f"row-{index}:trajectory")
            continue
        if not trace["nodes"]:
            faults.append(f"row-{index}:empty-nodes")
        for field, keys in entry_keys.items():
            values = trace[field]
            if not isinstance(values, list):
                faults.append(f"row-{index}:{field}-not-list")
                continue
            for event_index, event in enumerate(values):
                if not isinstance(event, dict) or set(event) != keys:
                    faults.append(f"row-{index}:{field}-{event_index}-schema")
                elif field == "plays" and int(event["uid"]) < 0:
                    faults.append(f"row-{index}:plays-{event_index}-uid")
    return faults


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the null-harness summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    immutable = protocol["immutableInputs"]
    require("runner SHA", core.file_sha(Path(__file__)) == immutable["runnerSha256"])
    for source in (PRISTINE, INSTRUMENTED):
        head = subprocess.run(
            ["git", "rev-parse", "HEAD"], cwd=source, check=True,
            text=True, capture_output=True,
        ).stdout.strip()
        require(f"{source.name} source commit", head == immutable["sourceCommit"])
    for path, expected in immutable["pristineSha256"].items():
        require(f"pristine {path}", core.file_sha(PRISTINE / path) == expected)
    for path, expected in immutable["instrumentedSha256"].items():
        require(f"instrumented {path}", core.file_sha(INSTRUMENTED / path) == expected)
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
    ledger_before = identity.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])

    cohort = protocol["cohort"]
    rows = [
        {
            "aspect": cohort["aspect"], "vow": cohort["vow"],
            "seed": seed, "policyRoot": cohort["policyRoot"],
            "policyIndex": policy_index,
        }
        for policy_index in range(cohort["policyCount"])
        for seed in cohort["simulationSeeds"]
    ]
    per_arm = cohort["policyCount"] * len(cohort["simulationSeeds"])
    require("cohort rectangle", len(rows) == per_arm)
    started = time.monotonic()
    cap = protocol["budget"]["maximumWallTimeSeconds"]
    invalid_error = ""
    try:
        invalid_ok, invalid_plan_sha = invalid_configuration_fails(
            protocol_sha, str(content_path), rows[0], godot, cap,
        )
    except (RuntimeError, subprocess.TimeoutExpired, OSError) as error:
        invalid_ok = False
        invalid_plan_sha = ""
        invalid_error = str(error)
    if invalid_error:
        boundary = 3
        outcome_class = "inconclusive"
        decision = "record-null-harness-inconclusive-on-unavailable-configuration-check"
        outputs = {"executionError": invalid_error}
        observed_rows = 0
        identity_counts = {}
        schema_faults = []
    elif not invalid_ok:
        boundary = 2
        outcome_class = "futility"
        decision = "close-null-harness-on-fail-open-configuration"
        outputs: dict[str, str] = {}
        observed_rows = 0
        identity_counts: dict[str, int] = {}
        schema_faults: list[str] = []
    else:
        pristine_plan = {
            "schemaVersion": 1, "protocolSha256": protocol_sha,
            "arm": "pristine", "content": str(content_path), "rows": rows,
        }
        instrumented_rows: list[dict[str, Any]] = []
        for arm, capture, explicit in (
            ("capture-off", False, False),
            ("capture-on-omitted-null", True, False),
            ("capture-on-explicit-null", True, True),
        ):
            for row in rows:
                spec = dict(row)
                spec["arm"] = arm
                if capture:
                    spec["captureTrace"] = True
                if explicit:
                    spec["explicitNull"] = True
                instrumented_rows.append(spec)
        instrumented_plan = {
            "schemaVersion": 1, "protocolSha256": protocol_sha,
            "arm": "instrumented-fixed-three-arm-plan",
            "content": str(content_path), "rows": instrumented_rows,
        }
        outputs = {}
        observed_rows = 0
        try:
            pristine_output, pristine_plan_sha, pristine_output_sha = run_probe(
                PRISTINE, pristine_plan, godot,
                max(1, int(cap - (time.monotonic() - started))),
            )
            outputs.update({
                "pristinePlanSha256": pristine_plan_sha,
                "pristineOutputSha256": pristine_output_sha,
            })
            observed_rows = len(pristine_output.get("rows", []))
            instrumented_output, instrumented_plan_sha, instrumented_output_sha = run_probe(
                INSTRUMENTED, instrumented_plan, godot,
                max(1, int(cap - (time.monotonic() - started))),
            )
            outputs.update({
                "instrumentedPlanSha256": instrumented_plan_sha,
                "instrumentedOutputSha256": instrumented_output_sha,
            })
            observed_rows += len(instrumented_output.get("rows", []))
            baseline = pristine_output["rows"]
            all_instrumented = instrumented_output["rows"]
            require("pristine row count", len(baseline) == per_arm)
            require("instrumented row count", len(all_instrumented) == per_arm * 3)
            capture_off = all_instrumented[:per_arm]
            omitted_trace = all_instrumented[per_arm:per_arm * 2]
            explicit_trace = all_instrumented[per_arm * 2:]
            identity_counts = {
                "pristineVersusCaptureOffMismatchRows": sum(
                    left != right for left, right in zip(baseline, capture_off)
                ),
                "captureOffVersusCaptureOnMismatchRows": sum(
                    left != without_trajectory(right)
                    for left, right in zip(capture_off, omitted_trace)
                ),
                "omittedVersusExplicitNullTraceMismatchRows": sum(
                    left != right for left, right in zip(omitted_trace, explicit_trace)
                ),
                "rngMismatchRows": sum(
                    not (baseline[i]["rng"] == capture_off[i]["rng"] ==
                         omitted_trace[i]["rng"] == explicit_trace[i]["rng"])
                    for i in range(per_arm)
                ),
                "policyMismatchRows": sum(
                    not (baseline[i]["policy"] == capture_off[i]["policy"] ==
                         omitted_trace[i]["policy"] == explicit_trace[i]["policy"])
                    for i in range(per_arm)
                ),
            }
            schema_faults = trace_schema_faults(omitted_trace + explicit_trace)
            elapsed = time.monotonic() - started
            if elapsed > cap:
                boundary = 3
                outcome_class = "inconclusive"
                decision = "record-null-harness-inconclusive-at-wall-time-cap"
            elif all(value == 0 for value in identity_counts.values()) and not schema_faults:
                boundary = 1
                outcome_class = "success"
                decision = "freeze-pristine-current-main-null-harness"
            else:
                boundary = 2
                outcome_class = "futility"
                decision = "close-pristine-current-main-null-harness-on-identity-failure"
        except (RuntimeError, subprocess.TimeoutExpired, KeyError, TypeError, ValueError) as error:
            boundary = 3
            outcome_class = "inconclusive"
            decision = "record-null-harness-inconclusive-on-unavailable-execution"
            outputs["executionError"] = str(error)
            identity_counts = {}
            schema_faults = []

    elapsed = time.monotonic() - started
    ledger_after = identity.ledger_identity()
    require("zero-ledger identity", ledger_after == ledger_before)
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "decisionBoundary": boundary,
        "decision": decision,
        "outcomeClass": outcome_class,
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "sourceCommit": immutable["sourceCommit"],
        "godotVersion": version,
        "invalidConfigurationFailedClosed": invalid_ok,
        "invalidPlanSha256": invalid_plan_sha,
        "identity": identity_counts,
        "traceSchemaFaults": schema_faults,
        "cacheObjects": outputs,
        "rowsPerArm": per_arm,
        "newSimulatorObservationRows": observed_rows,
        "newLedgerRows": 0,
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "protectedSeedRows": ledger_after["protectedSeedRows"],
        "maximumModelContextTokens": 0,
        "wallTimeSeconds": elapsed,
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
