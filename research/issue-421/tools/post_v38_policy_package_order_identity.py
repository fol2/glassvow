#!/usr/bin/env python3
"""Zero-ledger identity preflight for policy-selective package ordering."""

from __future__ import annotations

import copy
import json
import os
import subprocess
import tempfile
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-policy-package-order-identity-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-policy-package-order-identity-v1.json"
DEFAULT_GODOT = (
    core.ROOT
    / "toolchains/godot-4.7.1/Godot.app/Contents/MacOS/Godot"
)
GODOT = Path(os.environ.get("GODOT_471", DEFAULT_GODOT)).resolve()


def source_identity() -> dict[str, Any]:
    if not GODOT.is_file():
        raise RuntimeError(f"exact Godot binary is absent: {GODOT}")
    return {
        "sourceCommit": subprocess.run(
            ["git", "rev-parse", "HEAD"], cwd=core.SOURCE, check=True,
            text=True, capture_output=True,
        ).stdout.strip(),
        "godotVersion": subprocess.run(
            [str(GODOT), "--version"], check=True, text=True, capture_output=True,
        ).stdout.strip(),
        "godotBinarySha256": core.file_sha(GODOT),
        "contentSha256": core.file_sha(
            core.CACHE / "e475482c76a405814dba4638860bb799f610a220fcde5d931c78d1a447e18f48.json"
        ),
        "combatRulesSha256": core.file_sha(core.SOURCE / "domain/rules/combat.gd"),
        "balancePolicySha256": core.file_sha(core.SOURCE / "tools/balance_policy.gd"),
        "pilotSha256": core.file_sha(core.SOURCE / "tools/balance_pilot.gd"),
        "balanceSimSha256": core.file_sha(core.SOURCE / "tools/balance_sim.gd"),
        "probeSha256": core.file_sha(core.SOURCE / "tools/research_421_probe.gd"),
        "runnerSha256": core.file_sha(Path(__file__)),
    }


def verify_inputs(protocol: dict[str, Any]) -> tuple[dict[str, Any], dict[str, Any]]:
    source = source_identity()
    ledger = identity.ledger_identity()
    for key, expected in protocol["immutableInputs"].items():
        if source.get(key) != expected:
            raise RuntimeError(
                f"immutable input drift: {key} expected {expected} got {source.get(key)}"
            )
    for key, expected in protocol["ledgerFreeze"].items():
        if ledger.get(key) != expected:
            raise RuntimeError(
                f"ledger drift: {key} expected {expected} got {ledger.get(key)}"
            )
    return source, ledger


def run_probe(plan: dict[str, Any], timeout: int) -> tuple[dict[str, Any], str, str]:
    plan_sha, plan_path = core.cache_json(plan)
    with tempfile.TemporaryDirectory(prefix="issue-421-policy-order-") as tmp:
        out = Path(tmp) / "output.json"
        result = subprocess.run(
            [str(GODOT), "--headless", "-s", "res://tools/research_421_probe.gd", "--",
             f"--plan={plan_path}", f"--out={out}"],
            cwd=core.SOURCE, text=True, capture_output=True, timeout=timeout,
        )
        if result.returncode or not out.is_file():
            raise RuntimeError(
                f"probe failed ({result.returncode})\n"
                f"{result.stdout[-2000:]}\n{result.stderr[-4000:]}"
            )
        output = json.loads(out.read_text())
    output_sha, _ = core.cache_json(output)
    return output, plan_sha, output_sha


def normalise_legacy_row(row: dict[str, Any]) -> dict[str, Any]:
    normalised = copy.deepcopy(row)
    settings = normalised.get("research421")
    if isinstance(settings, dict):
        if settings.pop("policyPackageOrder", None) != 0.0:
            raise RuntimeError("legacy replay did not expose the new knob at exact null")
    for key in (
        "preferenceGroup", "preferenceKey", "preferenceMedian",
        "preferenceValue", "policyEligible",
    ):
        normalised.pop(key, None)
    return normalised


def surface_policy(case: dict[str, Any], value: float) -> dict[str, Any]:
    policy = copy.deepcopy(case["surfacePolicy"])
    group = case["preferenceGroup"]
    nested = policy.setdefault(group, {})
    nested[case["preferenceKey"]] = value
    return policy


def invalid_configuration_fails_closed(
    protocol_sha: str,
    content: str,
    research: dict[str, int],
    label: str,
    expected_error: str,
    timeout: int,
) -> str:
    plan = {
        "schemaVersion": 1,
        "protocolSha256": protocol_sha,
        "content": content,
        "rows": [{
            "id": label,
            "mode": "package-order-surface",
            "pairIndex": 0,
            "seed": 345300,
            "research421": research,
        }],
    }
    plan_sha, plan_path = core.cache_json(plan)
    with tempfile.TemporaryDirectory(prefix="issue-421-policy-order-invalid-") as tmp:
        out = Path(tmp) / "output.json"
        result = subprocess.run(
            [str(GODOT), "--headless", "-s", "res://tools/research_421_probe.gd", "--",
             f"--plan={plan_path}", f"--out={out}"],
            cwd=core.SOURCE, text=True, capture_output=True, timeout=timeout,
        )
    if result.returncode == 0 or expected_error not in result.stderr:
        raise RuntimeError(f"{label} did not fail closed")
    return plan_sha


def main() -> None:
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    source, ledger_before = verify_inputs(protocol)
    started = time.monotonic()
    timeout = protocol["budget"]["maximumWallTimeSeconds"]
    content = str(core.CACHE / f"{protocol['immutableInputs']['contentSha256']}.json")

    anchor = protocol["engineAndLegacyAnchor"]
    frozen_output = json.loads(
        (core.CACHE / f"{anchor['frozenOutputSha256']}.json").read_text()
    )
    pre_change_471 = json.loads(
        (core.CACHE / f"{anchor['preChange471OutputSha256']}.json").read_text()
    )
    identity.require_equal(
        "pre-change 4.7.1 versus frozen 4.7.2 rows",
        pre_change_471["rows"], frozen_output["rows"],
    )
    legacy_plan = json.loads(
        (core.CACHE / f"{anchor['planSha256']}.json").read_text()
    )
    legacy_output, legacy_plan_sha, legacy_output_sha = run_probe(legacy_plan, timeout)
    if legacy_plan_sha != anchor["planSha256"]:
        raise RuntimeError("legacy replay plan identity drifted")
    if len(legacy_output["rows"]) != protocol["budget"]["legacyReplayRows"]:
        raise RuntimeError("legacy replay row count drifted")
    for index, (current, frozen) in enumerate(
        zip(legacy_output["rows"], frozen_output["rows"], strict=True)
    ):
        identity.require_equal(
            f"normalised legacy row {index}", normalise_legacy_row(current), frozen
        )

    defaults = protocol["factorDefinition"]["nullSettings"]
    rows: list[dict[str, Any]] = []
    for case in protocol["surfaceCases"]:
        for preference_level in ("below", "at"):
            preference_value = case["preferenceLevels"][preference_level]
            for mediator_present in (False, True):
                for factor_level in (0, 1):
                    settings = copy.deepcopy(defaults)
                    settings["policyPackageOrder"] = factor_level
                    rows.append({
                        "id": (
                            f"pair-{case['pairIndex']}-{preference_level}-"
                            f"present-{int(mediator_present)}-order-{factor_level}"
                        ),
                        "mode": "package-order-surface",
                        "pairIndex": case["pairIndex"],
                        "mediatorPresent": mediator_present,
                        "seed": case["seed"],
                        "policy": surface_policy(case, preference_value),
                        "research421": settings,
                    })
    if len(rows) != protocol["budget"]["newSurfaceRowsMaximum"]:
        raise RuntimeError("policy-selective surface plan missed its frozen row ceiling")
    plan = {
        "schemaVersion": 1,
        "protocolSha256": protocol_sha,
        "content": content,
        "rows": rows,
    }
    output, plan_sha, output_sha = run_probe(plan, timeout)
    observed = output["rows"]
    surface_results: dict[str, Any] = {}
    cursor = 0
    for case in protocol["surfaceCases"]:
        by_cell: dict[tuple[str, bool, int], dict[str, Any]] = {}
        for preference_level in ("below", "at"):
            for mediator_present in (False, True):
                for factor_level in (0, 1):
                    row = observed[cursor]
                    cursor += 1
                    by_cell[(preference_level, mediator_present, factor_level)] = row
                    for key in ("producer", "consumer", "mediator", "preferenceGroup",
                                "preferenceKey", "preferenceMedian"):
                        if row[key] != case[key]:
                            raise RuntimeError(
                                f"pair {case['pairIndex']} {key} drifted from preregistration"
                            )
                    expected_value = case["preferenceLevels"][preference_level]
                    if row["preferenceValue"] != expected_value:
                        raise RuntimeError(
                            f"pair {case['pairIndex']} preference value drifted"
                        )
                    expected_eligible = preference_level == "at"
                    if row["policyEligible"] is not expected_eligible:
                        raise RuntimeError(
                            f"pair {case['pairIndex']} eligibility boundary drifted"
                        )
                    if row["producerEstablishesMediator"] is not True:
                        raise RuntimeError(
                            f"pair {case['pairIndex']} producer missed its mediator"
                        )
                    if set(row["combatScores"]) != {
                        case["producer"], case["consumer"], "strike"
                    }:
                        raise RuntimeError(f"pair {case['pairIndex']} legal hand drifted")
                    if row["rngBeforeChoice"] != row["rngAfterChoice"]:
                        raise RuntimeError(f"pair {case['pairIndex']} choice consumed RNG")
        for preference_level in ("below", "at"):
            for mediator_present in (False, True):
                off = by_cell[(preference_level, mediator_present, 0)]
                on = by_cell[(preference_level, mediator_present, 1)]
                for key in (
                    "policy", "combatScores", "rngBeforeChoice", "rngAfterChoice",
                    "preferenceValue", "policyEligible",
                ):
                    identity.require_equal(
                        f"pair {case['pairIndex']} {preference_level} "
                        f"presence {mediator_present} {key}", off[key], on[key],
                    )
                off_settings = copy.deepcopy(off["research421"])
                on_settings = copy.deepcopy(on["research421"])
                off_settings.pop("policyPackageOrder")
                on_settings.pop("policyPackageOrder")
                identity.require_equal(
                    f"pair {case['pairIndex']} non-target research settings",
                    off_settings, on_settings,
                )
                if preference_level == "below" or mediator_present:
                    identity.require_equal(
                        f"pair {case['pairIndex']} ineligible negative control",
                        off["firstChoice"], on["firstChoice"],
                    )
                elif on["firstChoice"] != case["producer"]:
                    raise RuntimeError(
                        f"pair {case['pairIndex']} eligible cell did not choose producer"
                    )
        surface_results[str(case["pairIndex"])] = {
            "producer": case["producer"],
            "consumer": case["consumer"],
            "mediator": case["mediator"],
            "preference": (
                f"{case['preferenceGroup']}.{case['preferenceKey']}"
            ),
            "median": case["preferenceMedian"],
            "belowAbsentOffChoice": by_cell[("below", False, 0)]["firstChoice"],
            "belowAbsentOnChoice": by_cell[("below", False, 1)]["firstChoice"],
            "atAbsentOffChoice": by_cell[("at", False, 0)]["firstChoice"],
            "atAbsentOnChoice": by_cell[("at", False, 1)]["firstChoice"],
            "atPresentOffChoice": by_cell[("at", True, 0)]["firstChoice"],
            "atPresentOnChoice": by_cell[("at", True, 1)]["firstChoice"],
            "policyScoresEligibilityAndRngExactWithinContrasts": True,
        }

    invalid_level_sha = invalid_configuration_fails_closed(
        protocol_sha, content, {"policyPackageOrder": 2},
        "invalid-policy-package-order-level", "unregistered level", timeout,
    )
    invalid_alias_sha = invalid_configuration_fails_closed(
        protocol_sha, content, {"packageOrder": 1, "policyPackageOrder": 1},
        "invalid-package-order-alias", "cannot both be enabled", timeout,
    )
    elapsed = time.monotonic() - started
    if elapsed > timeout:
        raise RuntimeError("preflight exceeded the frozen wall-time ceiling")
    ledger_after = identity.ledger_identity()
    identity.require_equal("append-only ledger", ledger_before, ledger_after)
    summary = {
        "schemaVersion": 1,
        "decision": "policy-package-order-identity-safe",
        "protocolSha256": protocol_sha,
        "runnerSha256": source["runnerSha256"],
        "godotVersion": source["godotVersion"],
        "engineAndLegacyAnchor": {
            "preChange471OutputSha256": anchor["preChange471OutputSha256"],
            "preChange471RowsCanonicalSha256": anchor[
                "preChange471RowsCanonicalSha256"
            ],
            "frozenOutputSha256": anchor["frozenOutputSha256"],
            "currentReplayPlanSha256": legacy_plan_sha,
            "currentReplayOutputSha256": legacy_output_sha,
            "normalisedRowsExact": True,
        },
        "planSha256": plan_sha,
        "outputSha256": output_sha,
        "surfaceResults": surface_results,
        "invalidLevelPlanSha256": invalid_level_sha,
        "invalidAliasPlanSha256": invalid_alias_sha,
        "unregisteredLevelFailedClosed": True,
        "aliasFailedClosed": True,
        "wallTimeSeconds": elapsed,
        "newLedgerObservationRows": 0,
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical(summary))


if __name__ == "__main__":
    main()
