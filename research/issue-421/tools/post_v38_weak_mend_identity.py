#!/usr/bin/env python3
"""Exact-null and direct-mediator identity preflight for weak-mend persistence."""

from __future__ import annotations

import json
import subprocess
import tempfile
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-weak-mend-identity-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-weak-mend-identity-v1.json"
SOURCE = core.ROOT / "weak-mend-identity-source"
GODOT = core.ROOT / "toolchains/godot-4.7.1/godot"
PROBE = "res://tools/research_421_weak_mend_probe.gd"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Weak-mend identity mismatch: {label}")


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
        "probeSha256": core.file_sha(SOURCE / "tools/research_421_weak_mend_probe.gd"),
        "probeUidSha256": core.file_sha(
            SOURCE / "tools/research_421_weak_mend_probe.gd.uid"
        ),
        "researchCoreSha256": core.file_sha(core.ROOT / "research.py"),
        "identityHelperSha256": core.file_sha(
            core.ROOT / "post_v38_knob_identity.py"
        ),
        "runnerSha256": core.file_sha(Path(__file__)),
    }


def build_content(level: int | None) -> dict[str, Any]:
    content = json.loads((SOURCE / "content/full-content.json").read_text())
    relic = content["relics"]["emberHeart"]
    require("pristine content omits weakMend", "weakMend" not in relic)
    if level is None:
        return content
    if type(level) is not int or level not in (0, 1):
        raise ValueError("emberHeartWeakMend accepts only integer levels 0 or 1")
    relic["weakMend"] = level
    return content


def invalid_level_checks() -> int:
    rejected = 0
    for level in (-1, 2):
        try:
            build_content(level)
        except ValueError:
            rejected += 1
    return rejected


def remaining(deadline: float) -> int:
    seconds = int(deadline - time.monotonic())
    if seconds < 1:
        raise TimeoutError("weak-mend preflight exceeded its wall-time ceiling")
    return seconds


def run_probe(
    plan: dict[str, Any], deadline: float,
) -> tuple[dict[str, Any], str, str]:
    plan_sha, plan_path = core.cache_json(plan)
    core.WORK.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=core.WORK, prefix="weak-mend-identity-") as tmp:
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
    enemies = [
        {"idx": 0, "hp": 10, "maxHp": 10, "statuses": {"weak": 2}},
        {"idx": 1, "hp": 8, "maxHp": 8, "statuses": {}},
        {"idx": 2, "hp": 0, "maxHp": 12, "statuses": {"weak": 4}},
        {"idx": 3, "hp": 6, "maxHp": 6, "statuses": {"weak": 1}},
    ]
    return [
        {"id": "eligible", "aspect": 0, "emberHeart": True,
         "playerHp": 10, "playerMaxHp": 20, "heal": 3,
         "postCombat": False, "enemies": enemies},
        {"id": "no-relic-ash", "aspect": 1, "emberHeart": False,
         "playerHp": 10, "playerMaxHp": 20, "heal": 3,
         "postCombat": False, "enemies": enemies},
        {"id": "no-effective-heal", "aspect": 0, "emberHeart": True,
         "playerHp": 20, "playerMaxHp": 20, "heal": 3,
         "postCombat": False, "enemies": enemies},
        {"id": "post-combat", "aspect": 0, "emberHeart": True,
         "playerHp": 10, "playerMaxHp": 20, "heal": 3,
         "postCombat": True, "enemies": enemies},
    ]


def controls_plan(protocol_sha: str, content: Path) -> dict[str, Any]:
    return {
        "schemaVersion": 1,
        "protocolSha256": protocol_sha,
        "mode": "focused-controls",
        "content": str(content),
        "controls": control_specs(),
    }


def whole_plan(protocol: dict[str, Any], protocol_sha: str, content: Path) -> dict[str, Any]:
    cohort = protocol["cohort"]
    rows = [
        {"aspect": cohort["aspect"], "vow": cohort["vow"], "seed": seed,
         "policyRoot": cohort["policyRoot"], "policyIndex": policy_index}
        for policy_index in range(cohort["policyCount"])
        for seed in cohort["simulationSeeds"]
    ]
    require("whole-run rectangle", len(rows) == cohort["rowsPerNullArm"])
    return {
        "schemaVersion": 1,
        "protocolSha256": protocol_sha,
        "mode": "whole-runs",
        "content": str(content),
        "rows": rows,
    }


def by_id(output: dict[str, Any]) -> dict[str, dict[str, Any]]:
    rows = output.get("rows", [])
    return {str(row["id"]): row for row in rows}


def expected_control(enabled: bool, identifier: str) -> dict[str, Any]:
    enemies = [
        {"idx": 0, "hp": 10, "statuses": {"weak": 3 if enabled else 2}},
        {"idx": 1, "hp": 8, "statuses": {}},
        {"idx": 2, "hp": 0, "statuses": {"weak": 4}},
        {"idx": 3, "hp": 6, "statuses": {"weak": 2 if enabled else 1}},
    ]
    row: dict[str, Any] = {
        "id": identifier, "healed": 3, "combatPlayerHp": 13,
        "runPlayerHp": 10, "enemies": enemies,
        "queue": [{"t": "heal", "who": "player", "n": 3}],
        "rngBefore": 0, "rngAfter": 0,
    }
    if enabled:
        row["queue"].extend([
            {"t": "status", "who": 0, "id": "weak", "n": 1},
            {"t": "status", "who": 3, "id": "weak", "n": 1},
        ])
    if identifier == "no-effective-heal":
        row.update({"healed": 0, "combatPlayerHp": 20, "runPlayerHp": 20,
                    "queue": []})
        for index, weak in ((0, 2), (3, 1)):
            row["enemies"][index]["statuses"]["weak"] = weak
    elif identifier == "post-combat":
        row.update({"combatPlayerHp": 10, "runPlayerHp": 13, "queue": []})
        for index, weak in ((0, 2), (3, 1)):
            row["enemies"][index]["statuses"]["weak"] = weak
    return row


def assess_controls(
    omitted: dict[str, Any], zero: dict[str, Any], enabled: dict[str, Any],
) -> tuple[list[str], dict[str, int]]:
    faults: list[str] = []
    arms = {"omitted": by_id(omitted), "zero": by_id(zero), "enabled": by_id(enabled)}
    expected_ids = [row["id"] for row in control_specs()]
    for arm, rows in arms.items():
        if sorted(rows) != sorted(expected_ids):
            faults.append(f"{arm}:control-identities")
    if faults:
        return faults, {"omittedZeroMismatchControls": len(expected_ids),
                        "enabledNonMediatorMismatchControls": len(expected_ids)}
    for identifier in expected_ids:
        if arms["omitted"][identifier] != expected_control(False, identifier):
            faults.append(f"omitted:{identifier}")
        if arms["zero"][identifier] != expected_control(False, identifier):
            faults.append(f"zero:{identifier}")
        enabled_effect = identifier == "eligible"
        if arms["enabled"][identifier] != expected_control(enabled_effect, identifier):
            faults.append(f"enabled:{identifier}")
    counts = {
        "omittedZeroMismatchControls": sum(
            arms["omitted"][identifier] != arms["zero"][identifier]
            for identifier in expected_ids
        ),
        "enabledNonMediatorMismatchControls": sum(
            arms["enabled"][identifier] != arms["zero"][identifier]
            for identifier in expected_ids if identifier != "eligible"
        ),
        "eligibleWeakExtensions": 2 if not faults else 0,
        "eligibleUntouchedNonWeak": 1 if not faults else 0,
        "eligibleUntouchedDeadWeak": 1 if not faults else 0,
    }
    return faults, counts


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the weak-mend identity summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    source = source_identity()
    for key, expected in protocol["immutableInputs"].items():
        require(f"immutable {key}", source.get(key) == expected)
    for path, expected in protocol["frozenEvidence"].items():
        require(path, core.file_sha(core.ROOT / path) == expected)
    require("invalid levels rejected", invalid_level_checks() == 2)

    zero_sha, zero_path = core.cache_json(build_content(0))
    enabled_sha, enabled_path = core.cache_json(build_content(1))
    require("explicit-zero content", zero_sha == protocol["contentLevels"]["zeroSha256"])
    require("enabled content", enabled_sha == protocol["contentLevels"]["enabledSha256"])
    omitted_path = SOURCE / "content/full-content.json"
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
    cache_objects: dict[str, Any] = {
        "explicitZeroContentSha256": zero_sha,
        "enabledContentSha256": enabled_sha,
    }
    controls_observed = 0
    whole_rows_observed = 0
    control_faults: list[str] = []
    control_counts: dict[str, int] = {}
    identity_counts: dict[str, int] = {}
    execution_error = ""

    try:
        control_outputs: dict[str, dict[str, Any]] = {}
        for arm, path in (("omitted", omitted_path), ("zero", zero_path),
                          ("enabled", enabled_path)):
            output, plan_sha, output_sha = run_probe(
                controls_plan(protocol_sha, path), deadline)
            control_outputs[arm] = output
            cache_objects[f"{arm}ControlsPlanSha256"] = plan_sha
            cache_objects[f"{arm}ControlsOutputSha256"] = output_sha
            controls_observed += len(output.get("rows", []))
        control_faults, control_counts = assess_controls(
            control_outputs["omitted"], control_outputs["zero"],
            control_outputs["enabled"])

        if not control_faults:
            whole_outputs: dict[str, dict[str, Any]] = {}
            for arm, path in (("omitted", omitted_path), ("zero", zero_path)):
                output, plan_sha, output_sha = run_probe(
                    whole_plan(protocol, protocol_sha, path), deadline)
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
                    left != right for left, right in zip(anchor_rows, omitted_rows)
                ),
                "zeroAnchorMismatchRows": sum(
                    left != right for left, right in zip(anchor_rows, zero_rows)
                ),
                "omittedZeroMismatchRows": sum(
                    left != right for left, right in zip(omitted_rows, zero_rows)
                ),
                "rngMismatchRows": sum(
                    anchor["rng"] != omitted["rng"] or anchor["rng"] != zero["rng"]
                    for anchor, omitted, zero in zip(anchor_rows, omitted_rows, zero_rows)
                ),
                "policyMismatchRows": sum(
                    anchor["policy"] != omitted["policy"]
                    or anchor["policy"] != zero["policy"]
                    for anchor, omitted, zero in zip(anchor_rows, omitted_rows, zero_rows)
                ),
                "trajectoryMismatchRows": sum(
                    anchor["trajectory"] != omitted["trajectory"]
                    or anchor["trajectory"] != zero["trajectory"]
                    for anchor, omitted, zero in zip(anchor_rows, omitted_rows, zero_rows)
                ),
            }
    except (KeyError, RuntimeError, subprocess.TimeoutExpired, TimeoutError,
            TypeError, ValueError) as error:
        execution_error = str(error)

    elapsed = time.monotonic() - started
    ledger_after = identity.ledger_identity()
    ledger_exact = ledger_after == ledger_before
    complete_controls = controls_observed == protocol["budget"]["controlledSurfaceExecutions"]
    complete_whole = whole_rows_observed == protocol["budget"]["wholeRunNullRows"]
    identity_exact = bool(identity_counts) and all(
        value == 0 for value in identity_counts.values())
    if execution_error or elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        boundary = 3
        outcome_class = "inconclusive"
        decision = "record-weak-mend-identity-inconclusive-at-cap"
    elif (control_faults or not complete_controls or not complete_whole
          or not identity_exact or not ledger_exact):
        boundary = 2
        outcome_class = "futility"
        decision = "close-weak-mend-persistence-on-identity-failure"
    else:
        boundary = 1
        outcome_class = "success"
        decision = "freeze-weak-mend-persistence-for-mechanism-blocked-crn"

    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "decisionBoundary": boundary,
        "decision": decision,
        "outcomeClass": outcome_class,
        "protocolSha256": protocol_sha,
        "runnerSha256": source["runnerSha256"],
        "sourceCommit": source["sourceCommit"],
        "godotVersion": source["godotVersion"],
        "controls": control_counts,
        "controlFaults": control_faults,
        "identity": identity_counts,
        "cacheObjects": cache_objects,
        "controlledSurfaceExecutions": controls_observed,
        "wholeRunNullRows": whole_rows_observed,
        "newScientificSimulatorObservationRows": 0,
        "newLedgerRows": 0,
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "protectedSeedRows": ledger_after["protectedSeedRows"],
        "wallTimeSeconds": elapsed,
        "maximumModelContextTokens": 0,
        "executionError": execution_error,
        "factorDisposition": protocol["factorDisposition"],
        "authority": protocol["decisionRules"][f"{outcome_class}Authority"],
    }
    SUMMARY.parent.mkdir(parents=True, exist_ok=True)
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": "PASS",
        "decision": decision,
        "decisionBoundary": boundary,
        "controlledSurfaceExecutions": controls_observed,
        "wholeRunNullRows": whole_rows_observed,
        "newScientificSimulatorObservationRows": 0,
        "summarySha256": core.file_sha(SUMMARY),
    }))


if __name__ == "__main__":
    main()
