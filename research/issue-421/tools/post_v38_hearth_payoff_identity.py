#!/usr/bin/env python3
"""Exact-null, direct-payoff and Hearth telemetry identity preflight for #421."""

from __future__ import annotations

import json
import subprocess
import tempfile
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-hearth-payoff-identity-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-hearth-payoff-identity-v1.json"
SOURCE = core.ROOT / "hearth-priority-identity-source"
GODOT = core.ROOT / "toolchains/godot-4.7.1/godot"
PROBE = "res://tools/research_421_hearth_payoff_probe.gd"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Hearth payoff identity mismatch: {label}")


def source_identity() -> dict[str, Any]:
    return {
        "sourceCommit": subprocess.run(
            ["git", "rev-parse", "HEAD"], cwd=SOURCE, check=True,
            text=True, capture_output=True,
        ).stdout.strip(),
        "godotVersion": subprocess.run(
            [str(GODOT), "--version"], check=True, text=True, capture_output=True,
        ).stdout.strip(),
        "godotBinarySha256": core.file_sha(GODOT),
        "contentSha256": core.file_sha(SOURCE / "content/full-content.json"),
        "combatRulesSha256": core.file_sha(SOURCE / "domain/rules/combat.gd"),
        "balanceSimSha256": core.file_sha(SOURCE / "tools/balance_sim.gd"),
        "pilotSha256": core.file_sha(SOURCE / "tools/balance_pilot.gd"),
        "policySha256": core.file_sha(SOURCE / "tools/balance_policy.gd"),
        "probeSha256": core.file_sha(
            SOURCE / "tools/research_421_hearth_payoff_probe.gd"),
        "probeUidSha256": core.file_sha(
            SOURCE / "tools/research_421_hearth_payoff_probe.gd.uid"),
        "researchCoreSha256": core.file_sha(core.ROOT / "research.py"),
        "identityHelperSha256": core.file_sha(core.ROOT / "post_v38_knob_identity.py"),
        "runnerSha256": core.file_sha(Path(__file__)),
    }


def remaining(deadline: float) -> int:
    seconds = int(deadline - time.monotonic())
    if seconds < 1:
        raise TimeoutError("Hearth payoff preflight exceeded its wall-time ceiling")
    return seconds


def run_probe(plan: dict[str, Any], deadline: float) -> tuple[dict[str, Any], str, str]:
    plan_sha, plan_path = core.cache_json(plan)
    core.WORK.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=core.WORK, prefix="hearth-payoff-identity-") as tmp:
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
    output_sha, _ = core.cache_json(output)
    return output, plan_sha, output_sha


def control_specs() -> list[dict[str, Any]]:
    return [
        {"id": "eligible", "playerHp": 60, "playerMaxHp": 100,
         "embers": 2, "relics": ["crownOfTheHearth"]},
        {"id": "limited-headroom", "playerHp": 97, "playerMaxHp": 100,
         "embers": 2, "relics": ["crownOfTheHearth"]},
        {"id": "sun-blossom", "playerHp": 60, "playerMaxHp": 100,
         "embers": 2, "relics": ["crownOfTheHearth", "sunBlossom"]},
        {"id": "crown-absent", "playerHp": 60, "playerMaxHp": 100,
         "embers": 2, "relics": []},
        {"id": "zero-embers", "playerHp": 60, "playerMaxHp": 100,
         "embers": 0, "relics": ["crownOfTheHearth"]},
        {"id": "full-hp", "playerHp": 100, "playerMaxHp": 100,
         "embers": 2, "relics": ["crownOfTheHearth"]},
    ]


def controls_plan(protocol_sha: str, payoff_level: str) -> dict[str, Any]:
    return {
        "schemaVersion": 1,
        "protocolSha256": protocol_sha,
        "mode": "focused-controls",
        "payoffLevel": payoff_level,
        "content": str(SOURCE / "content/full-content.json"),
        "controls": control_specs(),
    }


def whole_plan(
    protocol: dict[str, Any], protocol_sha: str,
    payoff_level: str, capture: bool,
) -> dict[str, Any]:
    cohort = protocol["cohort"]
    rows = [
        {"aspect": cohort["aspect"], "vow": cohort["vow"], "seed": seed,
         "policyRoot": cohort["policyRoot"], "policyIndex": policy_index}
        for policy_index in range(cohort["policyCount"])
        for seed in cohort["simulationSeeds"]
    ]
    require("whole-run rectangle", len(rows) == cohort["rowsPerArm"])
    return {
        "schemaVersion": 1,
        "protocolSha256": protocol_sha,
        "mode": "whole-runs",
        "payoffLevel": payoff_level,
        "capture": capture,
        "content": str(SOURCE / "content/full-content.json"),
        "rows": rows,
    }


def keyed(output: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {str(row["id"]): row for row in output.get("rows", [])}


def expected_control(spec: dict[str, Any], payoff_level: str) -> dict[str, Any]:
    current_deltas = {
        "eligible": 6,
        "limited-headroom": 3,
        "sun-blossom": 9,
        "crown-absent": 0,
        "zero-embers": 0,
        "full-hp": 0,
    }
    delta = 0 if payoff_level == "zero" else current_deltas[str(spec["id"])]
    proc = "crownOfTheHearth" in spec["relics"] and spec["embers"] > 0
    queue: list[dict[str, Any]] = []
    if proc:
        queue.append({"t": "relicProc", "id": "crownOfTheHearth"})
    queue.append({"t": "victory", "perfect": False})
    return {
        "id": spec["id"],
        "runHpBefore": spec["playerHp"],
        "runHpAfter": spec["playerHp"] + delta,
        "runHpDelta": delta,
        "combatPlayerHp": spec["playerHp"],
        "terminalEmbers": spec["embers"],
        "queue": queue,
        "result": "win",
        "over": True,
        "relics": spec["relics"],
        "rngBefore": 0,
        "rngAfter": 0,
    }


def without_hp(row: dict[str, Any]) -> dict[str, Any]:
    result = dict(row)
    result.pop("runHpAfter")
    result.pop("runHpDelta")
    return result


def assess_controls(outputs: dict[str, dict[str, Any]]) -> tuple[list[str], dict[str, int]]:
    faults: list[str] = []
    arms = {name: keyed(output) for name, output in outputs.items()}
    specs = control_specs()
    expected_ids = [str(spec["id"]) for spec in specs]
    for arm, rows in arms.items():
        if sorted(rows) != sorted(expected_ids):
            faults.append(f"{arm}:control-identities")
    if faults:
        return faults, {
            "omittedThreeMismatchControls": len(expected_ids),
            "disabledNonMediatorMismatchControls": len(expected_ids),
            "disabledExpectedHpMismatchControls": len(expected_ids),
        }
    for spec in specs:
        identifier = str(spec["id"])
        if arms["omitted"][identifier] != expected_control(spec, "omitted"):
            faults.append(f"omitted:{identifier}")
        if arms["three"][identifier] != expected_control(spec, "three"):
            faults.append(f"three:{identifier}")
        if arms["zero"][identifier] != expected_control(spec, "zero"):
            faults.append(f"zero:{identifier}")
    return faults, {
        "omittedThreeMismatchControls": sum(
            arms["omitted"][identifier] != arms["three"][identifier]
            for identifier in expected_ids),
        "disabledNonMediatorMismatchControls": sum(
            without_hp(arms["zero"][identifier])
            != without_hp(arms["three"][identifier])
            for identifier in expected_ids),
        "disabledExpectedHpMismatchControls": sum(
            arms["zero"][str(spec["id"])]["runHpDelta"]
            != expected_control(spec, "zero")["runHpDelta"]
            for spec in specs),
        "currentExpectedHpMismatchControls": sum(
            arms["three"][str(spec["id"])]["runHpDelta"]
            != expected_control(spec, "three")["runHpDelta"]
            for spec in specs),
        "crownProcMismatchControls": sum(
            arms["zero"][identifier]["queue"] != arms["three"][identifier]["queue"]
            for identifier in expected_ids),
    }


def without_trajectory(row: dict[str, Any]) -> dict[str, Any]:
    result = dict(row)
    result.pop("trajectory")
    return result


def without_hearth_trace(row: dict[str, Any]) -> dict[str, Any]:
    result = dict(row)
    trace = dict(result["trajectory"])
    trace.pop("hearthFights")
    result["trajectory"] = trace
    return result


def trace_schema_faults(rows: list[dict[str, Any]]) -> list[str]:
    faults: list[str] = []
    expected_trace = {
        "capture", "nodes", "turns", "draws", "plays", "kindles",
        "cardRewards", "bossRelics", "hearthFights",
    }
    for row_index, row in enumerate(rows):
        trace = row.get("trajectory")
        if not isinstance(trace, dict) or set(trace) != expected_trace:
            faults.append(f"row-{row_index}:trajectory")
            continue
        hearth = trace["hearthFights"]
        fights = row.get("fights")
        if not isinstance(hearth, list) or not isinstance(fights, list) \
                or len(hearth) != len(fights):
            faults.append(f"row-{row_index}:fight-count")
            continue
        for fight_index, event in enumerate(hearth):
            if not isinstance(event, dict) \
                    or set(event) != {"fight", "owned", "terminalEmbers", "proc"}:
                faults.append(f"row-{row_index}:fight-{fight_index}-schema")
                continue
            if (event["fight"] != fight_index
                    or not isinstance(event["owned"], bool)
                    or not isinstance(event["terminalEmbers"], int)
                    or event["terminalEmbers"] < 0
                    or not isinstance(event["proc"], bool)):
                faults.append(f"row-{row_index}:fight-{fight_index}-value")
                continue
            expected_proc = (event["owned"] and event["terminalEmbers"] > 0
                             and fights[fight_index]["result"] == "win")
            if event["proc"] != expected_proc:
                faults.append(f"row-{row_index}:fight-{fight_index}-proc")
    return faults


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the Hearth payoff identity summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    source = source_identity()
    for key, expected in protocol["immutableInputs"].items():
        require(f"immutable {key}", source.get(key) == expected)
    for relative, expected in protocol["frozenEvidence"].items():
        require(relative, core.file_sha(core.ROOT / relative) == expected)
    require("focused-control preregistration",
            control_specs() == protocol["focusedControls"])
    require("focused-control budget",
            len(control_specs()) * 3
            == protocol["budget"]["controlledSurfaceExecutions"])
    require("whole-run budget",
            protocol["cohort"]["rowsPerArm"] * 3
            == protocol["budget"]["wholeRunIdentityRows"])
    anchor_path = core.CACHE / f"{protocol['frozenPath']['outputSha256']}.json"
    require("frozen path cache", core.file_sha(anchor_path)
            == protocol["frozenPath"]["outputSha256"])
    anchor_output = json.loads(anchor_path.read_text())
    require("frozen path plan", anchor_output["planSha256"]
            == protocol["frozenPath"]["planSha256"])
    anchor_rows = anchor_output["rows"]
    require("frozen path rows", len(anchor_rows) == protocol["cohort"]["rowsPerArm"])

    ledger_before = identity.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
    started = time.monotonic()
    deadline = started + protocol["budget"]["maximumWallTimeSeconds"]
    cache_objects: dict[str, str] = {}
    controls_observed = 0
    whole_rows_observed = 0
    control_faults: list[str] = []
    control_counts: dict[str, int] = {}
    identity_counts: dict[str, int] = {}
    schema_faults: list[str] = []
    execution_error = ""
    try:
        control_outputs: dict[str, dict[str, Any]] = {}
        for arm in ("omitted", "three", "zero"):
            output, plan_sha, output_sha = run_probe(
                controls_plan(protocol_sha, arm), deadline)
            control_outputs[arm] = output
            cache_objects[f"{arm}ControlsPlanSha256"] = plan_sha
            cache_objects[f"{arm}ControlsOutputSha256"] = output_sha
            controls_observed += len(output.get("rows", []))
        control_faults, control_counts = assess_controls(control_outputs)

        if not control_faults:
            whole_specs = (
                ("omittedCaptureOff", "omitted", False),
                ("omittedCaptureOn", "omitted", True),
                ("threeCaptureOn", "three", True),
            )
            whole_outputs: dict[str, dict[str, Any]] = {}
            for arm, payoff, capture in whole_specs:
                output, plan_sha, output_sha = run_probe(
                    whole_plan(protocol, protocol_sha, payoff, capture), deadline)
                whole_outputs[arm] = output
                cache_objects[f"{arm}PlanSha256"] = plan_sha
                cache_objects[f"{arm}OutputSha256"] = output_sha
                whole_rows_observed += len(output.get("rows", []))
            capture_off = whole_outputs["omittedCaptureOff"].get("rows", [])
            capture_on = whole_outputs["omittedCaptureOn"].get("rows", [])
            explicit = whole_outputs["threeCaptureOn"].get("rows", [])
            expected = protocol["cohort"]["rowsPerArm"]
            require("capture-off rectangle", len(capture_off) == expected)
            require("capture-on rectangle", len(capture_on) == expected)
            require("explicit-three rectangle", len(explicit) == expected)
            require("capture-off schema", all(
                row.get("trajectory") == {"capture": False} for row in capture_off))
            identity_counts = {
                "captureOffAnchorCoreMismatchRows": sum(
                    without_trajectory(left) != without_trajectory(right)
                    for left, right in zip(anchor_rows, capture_off)),
                "captureOnWithoutHearthAnchorMismatchRows": sum(
                    left != without_hearth_trace(right)
                    for left, right in zip(anchor_rows, capture_on)),
                "captureOffOnCoreMismatchRows": sum(
                    without_trajectory(left) != without_trajectory(right)
                    for left, right in zip(capture_off, capture_on)),
                "explicitThreeOmittedMismatchRows": sum(
                    left != right for left, right in zip(capture_on, explicit)),
                "rngMismatchRows": sum(
                    anchor["rng"] != off["rng"] or anchor["rng"] != on["rng"]
                    or anchor["rng"] != three["rng"]
                    for anchor, off, on, three
                    in zip(anchor_rows, capture_off, capture_on, explicit)),
                "policyMismatchRows": sum(
                    anchor["policy"] != off["policy"]
                    or anchor["policy"] != on["policy"]
                    or anchor["policy"] != three["policy"]
                    for anchor, off, on, three
                    in zip(anchor_rows, capture_off, capture_on, explicit)),
                "priorTrajectoryMismatchRows": sum(
                    anchor["trajectory"]
                    != without_hearth_trace(on)["trajectory"]
                    for anchor, on in zip(anchor_rows, capture_on)),
            }
            schema_faults = trace_schema_faults(capture_on)
            schema_faults.extend(
                f"three:{fault}" for fault in trace_schema_faults(explicit))
    except (KeyError, RuntimeError, subprocess.TimeoutExpired, TimeoutError,
            TypeError, ValueError) as error:
        execution_error = str(error)

    elapsed = time.monotonic() - started
    ledger_after = identity.ledger_identity()
    complete_controls = controls_observed == protocol["budget"]["controlledSurfaceExecutions"]
    complete_whole = whole_rows_observed == protocol["budget"]["wholeRunIdentityRows"]
    controls_exact = bool(control_counts) and all(
        value == 0 for value in control_counts.values()) and not control_faults
    identity_exact = bool(identity_counts) and all(
        value == 0 for value in identity_counts.values())
    if execution_error or elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        boundary, outcome = 3, "inconclusive"
        decision = "record-hearth-payoff-identity-inconclusive-at-cap"
    elif (not complete_controls or not complete_whole or not controls_exact
          or not identity_exact or schema_faults or ledger_after != ledger_before):
        boundary, outcome = 2, "futility"
        decision = "close-hearth-payoff-route-on-identity-failure"
    else:
        boundary, outcome = 1, "success"
        decision = "freeze-hearth-payoff-and-harvest-telemetry-for-blocked-crn-design"

    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "decisionBoundary": boundary,
        "decision": decision,
        "outcomeClass": outcome,
        "protocolSha256": protocol_sha,
        "runnerSha256": source["runnerSha256"],
        "sourceIdentity": source,
        "godotVersion": source["godotVersion"],
        "controls": control_counts,
        "controlFaults": control_faults,
        "identity": identity_counts,
        "traceSchemaFaults": schema_faults,
        "executionError": execution_error,
        "cacheObjects": cache_objects,
        "controlledSurfaceExecutions": controls_observed,
        "wholeRunIdentityRows": whole_rows_observed,
        "disabledWholeRunRows": 0,
        "newSimulatorObservationRows": whole_rows_observed,
        "newLedgerRows": 0,
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "protectedSeedRows": ledger_after["protectedSeedRows"],
        "maximumModelContextTokens": 0,
        "wallTimeSeconds": elapsed,
        "factorDisposition": protocol["factorDisposition"],
        "mechanisticInteractions": protocol["mechanisticInteractions"],
        "authority": protocol["decisionRules"][f"{outcome}Authority"],
    }
    SUMMARY.parent.mkdir(parents=True, exist_ok=True)
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": "PASS",
        "decision": decision,
        "decisionBoundary": boundary,
        "controlledSurfaceExecutions": controls_observed,
        "wholeRunIdentityRows": whole_rows_observed,
        "summarySha256": core.file_sha(SUMMARY),
    }))


if __name__ == "__main__":
    main()
