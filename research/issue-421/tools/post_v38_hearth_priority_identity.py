#!/usr/bin/env python3
"""Exact-null and direct-choice identity preflight for Hearth acquisition priority."""

from __future__ import annotations

import json
import subprocess
import tempfile
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-hearth-priority-identity-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-hearth-priority-identity-v1.json"
SOURCE = core.ROOT / "hearth-priority-identity-source"
GODOT = core.ROOT / "toolchains/godot-4.7.1/godot"
PROBE = "res://tools/research_421_hearth_priority_probe.gd"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Hearth priority identity mismatch: {label}")


def source_identity() -> dict[str, Any]:
    patch = subprocess.run(
        ["git", "diff", "--", "tools/balance_pilot.gd", "tools/balance_sim.gd",
         "tools/research_421_hearth_priority_probe.gd",
         "tools/research_421_hearth_priority_probe.gd.uid"],
        cwd=SOURCE, check=True, capture_output=True,
    ).stdout
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
        "balanceSimSha256": core.file_sha(SOURCE / "tools/balance_sim.gd"),
        "pilotSha256": core.file_sha(SOURCE / "tools/balance_pilot.gd"),
        "policySha256": core.file_sha(SOURCE / "tools/balance_policy.gd"),
        "probeSha256": core.file_sha(
            SOURCE / "tools/research_421_hearth_priority_probe.gd"),
        "probeUidSha256": core.file_sha(
            SOURCE / "tools/research_421_hearth_priority_probe.gd.uid"),
        "prototypePatchSha256": core.sha(patch),
        "researchCoreSha256": core.file_sha(core.ROOT / "research.py"),
        "identityHelperSha256": core.file_sha(core.ROOT / "post_v38_knob_identity.py"),
        "runnerSha256": core.file_sha(Path(__file__)),
    }


def remaining(deadline: float) -> int:
    seconds = int(deadline - time.monotonic())
    if seconds < 1:
        raise TimeoutError("Hearth priority preflight exceeded its wall-time ceiling")
    return seconds


def run_probe(plan: dict[str, Any], deadline: float) -> tuple[dict[str, Any], str, str]:
    plan_sha, plan_path = core.cache_json(plan)
    core.WORK.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=core.WORK, prefix="hearth-priority-identity-") as tmp:
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
        {"id": "eligible", "policyRoot": 551, "policyIndex": 0,
         "aspect": 0, "seed": 11, "randomBuild": False, "banned": [],
         "offered": ["crownOfTheHearth", "crownOfCinders", "crownOfTithes"]},
        {"id": "crown-absent", "policyRoot": 551, "policyIndex": 0,
         "aspect": 0, "seed": 12, "randomBuild": False, "banned": [],
         "offered": ["crownOfCinders", "crownOfTithes", "shatterersCrown"]},
        {"id": "crown-banned", "policyRoot": 551, "policyIndex": 0,
         "aspect": 0, "seed": 13, "randomBuild": False,
         "banned": ["crownOfTheHearth"],
         "offered": ["crownOfTheHearth", "hollowCrown"]},
        {"id": "already-selected", "policyRoot": 551, "policyIndex": 0,
         "aspect": 0, "seed": 14, "randomBuild": False, "banned": [],
         "offered": ["crownOfTheHearth", "hollowCrown"]},
        {"id": "random-rng", "policyRoot": 551, "policyIndex": 0,
         "aspect": 0, "seed": 1, "randomBuild": True, "banned": [],
         "offered": ["crownOfTheHearth", "hollowCrown", "crownOfCinders"]},
    ]


def controls_plan(protocol_sha: str, priority: bool | None) -> dict[str, Any]:
    plan: dict[str, Any] = {
        "schemaVersion": 1,
        "protocolSha256": protocol_sha,
        "mode": "focused-controls",
        "content": str(SOURCE / "content/full-content.json"),
        "controls": control_specs(),
    }
    if priority is not None:
        plan["priority"] = priority
    return plan


def whole_plan(
    protocol: dict[str, Any], protocol_sha: str, priority: bool | None,
) -> dict[str, Any]:
    cohort = protocol["cohort"]
    rows = [
        {"aspect": cohort["aspect"], "vow": cohort["vow"], "seed": seed,
         "policyRoot": cohort["policyRoot"], "policyIndex": policy_index}
        for policy_index in range(cohort["policyCount"])
        for seed in cohort["simulationSeeds"]
    ]
    require("whole-run rectangle", len(rows) == cohort["rowsPerNullArm"])
    plan: dict[str, Any] = {
        "schemaVersion": 1,
        "protocolSha256": protocol_sha,
        "mode": "whole-runs",
        "content": str(SOURCE / "content/full-content.json"),
        "rows": rows,
    }
    if priority is not None:
        plan["priority"] = priority
    return plan


def keyed(output: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {str(row["id"]): row for row in output.get("rows", [])}


def expected_control(identifier: str, enabled: bool) -> dict[str, Any]:
    expected = {
        "eligible": {
            "offered": ["crownOfTheHearth", "crownOfCinders", "crownOfTithes"],
            "chosen": "crownOfTheHearth" if enabled else "crownOfTithes",
            "rngBefore": 11, "rngAfter": 11,
        },
        "crown-absent": {
            "offered": ["crownOfCinders", "crownOfTithes", "shatterersCrown"],
            "chosen": "crownOfTithes", "rngBefore": 12, "rngAfter": 12,
        },
        "crown-banned": {
            "offered": ["crownOfTheHearth", "hollowCrown"],
            "chosen": "hollowCrown", "rngBefore": 13, "rngAfter": 13,
        },
        "already-selected": {
            "offered": ["crownOfTheHearth", "hollowCrown"],
            "chosen": "crownOfTheHearth", "rngBefore": 14, "rngAfter": 14,
        },
        "random-rng": {
            "offered": ["crownOfTheHearth", "hollowCrown", "crownOfCinders"],
            "chosen": "crownOfTheHearth" if enabled else "hollowCrown",
            "rngBefore": 1, "rngAfter": 1831565814,
        },
    }[identifier]
    return {"id": identifier, **expected}


def assess_controls(
    omitted: dict[str, Any], zero: dict[str, Any], enabled: dict[str, Any],
) -> tuple[list[str], dict[str, int]]:
    faults: list[str] = []
    arms = {"omitted": keyed(omitted), "zero": keyed(zero), "enabled": keyed(enabled)}
    expected_ids = [spec["id"] for spec in control_specs()]
    for arm, rows in arms.items():
        if sorted(rows) != sorted(expected_ids):
            faults.append(f"{arm}:control-identities")
    if faults:
        return faults, {"omittedZeroMismatchControls": len(expected_ids),
                        "enabledNonMediatorMismatchControls": len(expected_ids)}
    for identifier in expected_ids:
        if arms["omitted"][identifier] != expected_control(identifier, False):
            faults.append(f"omitted:{identifier}")
        if arms["zero"][identifier] != expected_control(identifier, False):
            faults.append(f"zero:{identifier}")
        if arms["enabled"][identifier] != expected_control(identifier, True):
            faults.append(f"enabled:{identifier}")
    counts = {
        "omittedZeroMismatchControls": sum(
            arms["omitted"][identifier] != arms["zero"][identifier]
            for identifier in expected_ids),
        "enabledChangedChoiceControls": sum(
            arms["enabled"][identifier]["chosen"] != arms["zero"][identifier]["chosen"]
            for identifier in expected_ids),
        "enabledChangedOfferControls": sum(
            arms["enabled"][identifier]["offered"] != arms["zero"][identifier]["offered"]
            for identifier in expected_ids),
        "enabledRngMismatchControls": sum(
            arms["enabled"][identifier]["rngAfter"] != arms["zero"][identifier]["rngAfter"]
            for identifier in expected_ids),
        "eligibleChoiceChanges": int(
            arms["enabled"]["eligible"]["chosen"] != arms["zero"]["eligible"]["chosen"]),
        "randomChoiceChanges": int(
            arms["enabled"]["random-rng"]["chosen"] != arms["zero"]["random-rng"]["chosen"]),
    }
    return faults, counts


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the Hearth priority identity summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    source = source_identity()
    for key, expected in protocol["immutableInputs"].items():
        require(f"immutable {key}", source.get(key) == expected)
    for path, expected in protocol["frozenEvidence"].items():
        require(path, core.file_sha(core.ROOT / path) == expected)
    anchor_path = core.CACHE / f"{protocol['frozenPath']['outputSha256']}.json"
    require("frozen path cache", core.file_sha(anchor_path)
            == protocol["frozenPath"]["outputSha256"])
    anchor_output = json.loads(anchor_path.read_text())
    anchor_rows = anchor_output["rows"]
    require("frozen path plan", anchor_output["planSha256"]
            == protocol["frozenPath"]["planSha256"])
    require("frozen path rows", len(anchor_rows) == protocol["cohort"]["rowsPerNullArm"])

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
    execution_error = ""
    try:
        control_outputs: dict[str, dict[str, Any]] = {}
        for arm, priority in (("omitted", None), ("zero", False), ("enabled", True)):
            output, plan_sha, output_sha = run_probe(
                controls_plan(protocol_sha, priority), deadline)
            control_outputs[arm] = output
            cache_objects[f"{arm}ControlsPlanSha256"] = plan_sha
            cache_objects[f"{arm}ControlsOutputSha256"] = output_sha
            controls_observed += len(output.get("rows", []))
        control_faults, control_counts = assess_controls(
            control_outputs["omitted"], control_outputs["zero"],
            control_outputs["enabled"])

        if not control_faults:
            whole_outputs: dict[str, dict[str, Any]] = {}
            for arm, priority in (("omitted", None), ("zero", False)):
                output, plan_sha, output_sha = run_probe(
                    whole_plan(protocol, protocol_sha, priority), deadline)
                whole_outputs[arm] = output
                cache_objects[f"{arm}WholePlanSha256"] = plan_sha
                cache_objects[f"{arm}WholeOutputSha256"] = output_sha
                whole_rows_observed += len(output.get("rows", []))
            omitted_rows = whole_outputs["omitted"].get("rows", [])
            zero_rows = whole_outputs["zero"].get("rows", [])
            expected = protocol["cohort"]["rowsPerNullArm"]
            require("omitted whole rectangle", len(omitted_rows) == expected)
            require("zero whole rectangle", len(zero_rows) == expected)
            identity_counts = {
                "omittedAnchorMismatchRows": sum(
                    left != right for left, right in zip(anchor_rows, omitted_rows)),
                "zeroAnchorMismatchRows": sum(
                    left != right for left, right in zip(anchor_rows, zero_rows)),
                "omittedZeroMismatchRows": sum(
                    left != right for left, right in zip(omitted_rows, zero_rows)),
                "rngMismatchRows": sum(
                    anchor["rng"] != omitted["rng"] or anchor["rng"] != zero["rng"]
                    for anchor, omitted, zero in zip(anchor_rows, omitted_rows, zero_rows)),
                "policyMismatchRows": sum(
                    anchor["policy"] != omitted["policy"]
                    or anchor["policy"] != zero["policy"]
                    for anchor, omitted, zero in zip(anchor_rows, omitted_rows, zero_rows)),
                "trajectoryMismatchRows": sum(
                    anchor["trajectory"] != omitted["trajectory"]
                    or anchor["trajectory"] != zero["trajectory"]
                    for anchor, omitted, zero in zip(anchor_rows, omitted_rows, zero_rows)),
            }
    except (KeyError, RuntimeError, subprocess.TimeoutExpired, TimeoutError,
            TypeError, ValueError) as error:
        execution_error = str(error)

    elapsed = time.monotonic() - started
    ledger_after = identity.ledger_identity()
    complete_controls = controls_observed == protocol["budget"]["controlledSurfaceExecutions"]
    complete_whole = whole_rows_observed == protocol["budget"]["wholeRunNullRows"]
    identity_exact = bool(identity_counts) and all(value == 0 for value in identity_counts.values())
    controls_exact = (not control_faults
                      and control_counts.get("enabledChangedChoiceControls") == 2
                      and control_counts.get("enabledChangedOfferControls") == 0
                      and control_counts.get("enabledRngMismatchControls") == 0)
    if execution_error or elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        boundary, outcome = 3, "inconclusive"
        decision = "record-hearth-priority-identity-inconclusive-at-cap"
    elif (not complete_controls or not complete_whole or not controls_exact
          or not identity_exact or ledger_after != ledger_before):
        boundary, outcome = 2, "futility"
        decision = "close-hearth-acquisition-priority-on-identity-failure"
    else:
        boundary, outcome = 1, "success"
        decision = "freeze-hearth-acquisition-priority-for-blocked-crn-design"

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
        "executionError": execution_error,
        "cacheObjects": cache_objects,
        "controlledSurfaceExecutions": controls_observed,
        "wholeRunNullRows": whole_rows_observed,
        "enabledWholeRunRows": 0,
        "newSimulatorObservationRows": whole_rows_observed,
        "newLedgerRows": 0,
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "protectedSeedRows": ledger_after["protectedSeedRows"],
        "maximumModelContextTokens": 0,
        "wallTimeSeconds": elapsed,
        "factorDisposition": protocol["factorDisposition"],
        "authority": protocol["decisionRules"][f"{outcome}Authority"],
    }
    SUMMARY.parent.mkdir(parents=True, exist_ok=True)
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": "PASS",
        "decision": decision,
        "decisionBoundary": boundary,
        "controlledSurfaceExecutions": controls_observed,
        "wholeRunNullRows": whole_rows_observed,
        "summarySha256": core.file_sha(SUMMARY),
    }))


if __name__ == "__main__":
    main()
