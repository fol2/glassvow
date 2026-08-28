#!/usr/bin/env python3
"""Preregistered Hearth payoff by acquisition-priority CRN block for #421."""

from __future__ import annotations

import json
import math
import statistics
import subprocess
import tempfile
import time
from pathlib import Path
from typing import Any

import post_v38_cohand_opportunity_decomposition as cohand
import post_v38_competing_structural_options as structural
import post_v38_hearth_payoff_identity as payoff_identity
import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-hearth-blocked-crn-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-hearth-blocked-crn-v1.json"
SOURCE = core.ROOT / "hearth-priority-identity-source"
GODOT = core.ROOT / "toolchains/godot-4.7.1/godot"
PROBE = "res://tools/research_421_hearth_payoff_probe.gd"
CELLS = ("H1Q0", "H0Q0", "H1Q1", "H0Q1")
ENDPOINTS = (
    "quality", "win", "hpFraction", "procFights", "ownedFights",
    "terminalEmbersAtProc", "duration",
)


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Hearth blocked CRN mismatch: {label}")


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
        "pilotSha256": core.file_sha(SOURCE / "tools/balance_pilot.gd"),
        "policySha256": core.file_sha(SOURCE / "tools/balance_policy.gd"),
        "probeSha256": core.file_sha(
            SOURCE / "tools/research_421_hearth_payoff_probe.gd"),
        "probeUidSha256": core.file_sha(
            SOURCE / "tools/research_421_hearth_payoff_probe.gd.uid"),
        "researchCoreSha256": core.file_sha(core.ROOT / "research.py"),
        "identityHelperSha256": core.file_sha(
            core.ROOT / "post_v38_knob_identity.py"),
        "payoffIdentityHelperSha256": core.file_sha(
            core.ROOT / "post_v38_hearth_payoff_identity.py"),
        "structuralHelperSha256": core.file_sha(
            core.ROOT / "post_v38_competing_structural_options.py"),
        "cohandHelperSha256": core.file_sha(
            core.ROOT / "post_v38_cohand_opportunity_decomposition.py"),
        "runnerSha256": core.file_sha(Path(__file__)),
    }


def remaining(deadline: float) -> int:
    seconds = int(deadline - time.monotonic())
    if seconds < 1:
        raise TimeoutError("Hearth blocked CRN exceeded its wall-time ceiling")
    return seconds


def run_probe(plan: dict[str, Any], deadline: float) -> tuple[dict[str, Any], str, str]:
    plan_sha, plan_path = core.cache_json(plan)
    core.WORK.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=core.WORK, prefix="hearth-blocked-crn-") as tmp:
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


def row_specs(protocol: dict[str, Any]) -> list[dict[str, Any]]:
    cohort = protocol["cohort"]
    return [
        {"aspect": cohort["aspect"], "vow": cohort["vow"], "seed": seed,
         "policyRoot": cohort["policyRoot"], "policyIndex": policy_index}
        for policy_index in range(cohort["policyCount"])
        for seed in cohort["simulationSeeds"]
    ]


def plan_for(
    protocol: dict[str, Any], protocol_sha: str, cell: str,
) -> dict[str, Any]:
    definition = protocol["designMatrix"][cell]
    return {
        "schemaVersion": 1,
        "protocolSha256": protocol_sha,
        "mode": "whole-runs",
        "payoffLevel": definition["probePayoffLevel"],
        "priority": definition["priority"],
        "capture": True,
        "content": str(SOURCE / "content/full-content.json"),
        "rows": row_specs(protocol),
    }


def indexed_rows(
    specs: list[dict[str, Any]], rows: list[dict[str, Any]],
    protocol: dict[str, Any], label: str,
) -> dict[tuple[int, int], dict[str, Any]]:
    require(f"{label} row count", len(specs) == len(rows)
            == protocol["cohort"]["rowsPerCell"])
    found: dict[tuple[int, int], dict[str, Any]] = {}
    for spec, row in zip(specs, rows):
        key = (int(spec["policyIndex"]), int(spec["seed"]))
        require(f"{label} unique {key}", key not in found)
        require(f"{label} seed {key}", int(row["seed"]) == key[1])
        require(f"{label} aspect {key}", row["aspect"] == protocol["cohort"]["aspect"])
        require(f"{label} vow {key}", int(row["vow"]) == protocol["cohort"]["vow"])
        found[key] = row
    return found


def load_anchor(protocol: dict[str, Any]) -> tuple[dict[tuple[int, int], dict[str, Any]], dict[str, str]]:
    frozen = protocol["sharedAnchorCell"]
    plan_path = core.CACHE / f"{frozen['planSha256']}.json"
    output_path = core.CACHE / f"{frozen['outputSha256']}.json"
    require("anchor plan SHA", core.file_sha(plan_path) == frozen["planSha256"])
    require("anchor output SHA", core.file_sha(output_path) == frozen["outputSha256"])
    plan = json.loads(plan_path.read_text())
    output = json.loads(output_path.read_text())
    require("anchor output plan", output["planSha256"] == frozen["planSha256"])
    require("anchor probe", output["probeSha256"] == frozen["probeSha256"])
    require("anchor payoff alias", output["payoffLevel"] == "omitted")
    require("anchor capture", plan["capture"] is True)
    require("anchor priority alias", "priority" not in plan)
    require("anchor rows", plan["rows"] == row_specs(protocol))
    return indexed_rows(plan["rows"], output["rows"], protocol, "H1Q0"), {
        "planSha256": frozen["planSha256"],
        "outputSha256": frozen["outputSha256"],
        "rows": len(output["rows"]),
        "reused": True,
    }


def metric(row: dict[str, Any], endpoint: str) -> float:
    hearth = row["trajectory"]["hearthFights"]
    if endpoint == "quality":
        require("positive max HP", int(row["maxHp"]) > 0)
        return float(row["outcome"] == "win") + float(row["hp"]) / float(row["maxHp"])
    if endpoint == "win":
        return float(row["outcome"] == "win")
    if endpoint == "hpFraction":
        require("positive max HP", int(row["maxHp"]) > 0)
        return float(row["hp"]) / float(row["maxHp"])
    if endpoint == "procFights":
        return float(sum(bool(event["proc"]) for event in hearth))
    if endpoint == "ownedFights":
        return float(sum(bool(event["owned"]) for event in hearth))
    if endpoint == "terminalEmbersAtProc":
        return float(sum(int(event["terminalEmbers"]) for event in hearth
                         if event["proc"]))
    if endpoint == "duration":
        require("duration fights", bool(row["fights"]))
        return statistics.fmean(float(fight["turns"]) for fight in row["fights"])
    raise KeyError(endpoint)


def policy_contrast_values(
    rows: dict[str, dict[tuple[int, int], dict[str, Any]]],
    protocol: dict[str, Any], weights: dict[str, int], endpoint: str,
) -> list[float]:
    cohort = protocol["cohort"]
    values: list[float] = []
    for policy_index in range(cohort["policyCount"]):
        seed_values = [
            sum(weight * metric(rows[cell][(policy_index, seed)], endpoint)
                for cell, weight in weights.items())
            for seed in cohort["simulationSeeds"]
        ]
        values.append(statistics.fmean(seed_values))
    return values


def fit_effects(
    rows: dict[str, dict[tuple[int, int], dict[str, Any]]],
    protocol: dict[str, Any],
) -> tuple[dict[str, Any], dict[str, dict[str, list[float]]]]:
    effects: dict[str, Any] = {}
    raw: dict[str, dict[str, list[float]]] = {}
    seed = int(protocol["estimators"]["bootstrapSeed"])
    for contrast_index, (name, weights) in enumerate(protocol["contrasts"].items()):
        effects[name] = {}
        raw[name] = {}
        for endpoint_index, endpoint in enumerate(ENDPOINTS):
            values = policy_contrast_values(rows, protocol, weights, endpoint)
            raw[name][endpoint] = values
            effects[name][endpoint] = core.interval(
                values, 1.0, seed + 10 * contrast_index + endpoint_index)
    return effects, raw


def route_sets(
    rows: dict[tuple[int, int], dict[str, Any]], protocol: dict[str, Any],
) -> dict[str, set[int]]:
    return {
        "scoreline": structural.robust_set(
            rows, protocol,
            lambda row: bool(structural.ordered_pairs(
                row, {"chisel"}, {"executioner"})),
        ),
        "afterimage": structural.robust_set(
            rows, protocol,
            lambda row: cohand.simultaneous_cohand(
                row, "defend", "guardedStrike"),
        ),
    }


def separated(value: dict[str, Any], gates: dict[str, Any]) -> bool:
    return (
        value["candidateOnlyPolicies"] >= gates["minimumCandidateOnlyPolicies"]
        and value["anchorOnlyPolicies"] >= gates["minimumAnchorOnlyPolicies"]
        and value["jaccard"] <= gates["maximumAnchorJaccard"]
    )


def analyse(
    rows: dict[str, dict[tuple[int, int], dict[str, Any]]],
    protocol: dict[str, Any],
) -> dict[str, Any]:
    cohort = protocol["cohort"]
    gates = protocol["gates"]
    for cell in CELLS:
        faults = payoff_identity.trace_schema_faults(list(rows[cell].values()))
        require(f"{cell} trace schema", not faults)
    anchor = rows["H1Q0"]
    policy_mismatches = 0
    for cell in CELLS[1:]:
        for key, row in rows[cell].items():
            policy_mismatches += row["policy"] != anchor[key]["policy"]
    require("policy identity", policy_mismatches == 0)

    effects, raw = fit_effects(rows, protocol)
    candidate = {
        policy for policy in range(cohort["policyCount"])
        if sum(metric(rows["H1Q1"][(policy, seed)], "procFights") > 0
               for seed in cohort["simulationSeeds"])
        >= cohort["minimumRowsPerRobustPolicy"]
    }
    inactive = {
        policy for policy in range(cohort["policyCount"])
        if not any(metric(rows["H1Q1"][(policy, seed)], "procFights") > 0
                   for seed in cohort["simulationSeeds"])
    }
    viable = {
        policy for policy in candidate
        if any(rows["H1Q1"][(policy, seed)]["outcome"] == "win"
               and metric(rows["H1Q1"][(policy, seed)], "procFights") > 0
               for seed in cohort["simulationSeeds"])
    }
    payoff_values = raw["payoffAtPriorityOn"]["quality"]
    positive = {index for index, value in enumerate(payoff_values) if value > 0}
    zero = {index for index, value in enumerate(payoff_values) if value == 0}
    negative = {index for index, value in enumerate(payoff_values) if value < 0}

    observed_routes = {
        "priorityOff": route_sets(rows["H1Q0"], protocol),
        "priorityOn": route_sets(rows["H1Q1"], protocol),
    }
    frozen_routes = {name: set(values)
                     for name, values in protocol["sharedRouteAnchors"].items()}
    require("Scoreline frozen anchor", observed_routes["priorityOff"]["scoreline"]
            == frozen_routes["scoreline"])
    require("Afterimage frozen anchor", observed_routes["priorityOff"]["afterimage"]
            == frozen_routes["afterimage"])
    separation: dict[str, Any] = {}
    interference: dict[str, Any] = {}
    for route in ("scoreline", "afterimage"):
        frozen = structural.separation(candidate, frozen_routes[route])
        priority_on = structural.separation(
            candidate, observed_routes["priorityOn"][route])
        frozen_pass = separated(frozen, gates)
        priority_on_pass = separated(priority_on, gates)
        separation[route] = {
            "frozenAnchor": frozen,
            "priorityOnAnchor": priority_on,
            "frozenPass": frozen_pass,
            "priorityOnPass": priority_on_pass,
        }
        interference[route] = {
            "anchorSymmetricDifferencePolicies": len(
                frozen_routes[route] ^ observed_routes["priorityOn"][route]),
            "decisionChanged": frozen_pass != priority_on_pass,
        }

    faults = sum(
        row.get("outcome") in ("stall", "error") or bool(row.get("error"))
        for cell in CELLS for row in rows[cell].values()
    )
    win_rate = statistics.fmean(
        metric(row, "win") for row in rows["H1Q1"].values())
    checks = {
        "activeSupport": len(candidate) >= gates["minimumActivePolicies"],
        "inactiveSupport": len(inactive) >= gates["minimumInactivePolicies"],
        "viableSupport": len(viable) >= gates["minimumViablePolicies"],
        "positivePayoffWitnesses": len(positive) >= gates["minimumPositivePayoffPolicies"],
        "zeroPayoffWitnesses": len(zero) >= gates["minimumZeroPayoffPolicies"],
        "payoffEffect": effects["payoffAtPriorityOn"]["quality"]["p025"] > 0,
        "priorityActivation": effects["priorityAtCurrentPayoff"]["procFights"]["p025"] > 0,
        "payoffByPriorityInteraction": effects["payoffByPriorityInteraction"]["quality"]["p025"] > 0,
        "scorelineSeparation": all(
            value for key, value in separation["scoreline"].items()
            if key.endswith("Pass")),
        "afterimageSeparation": all(
            value for key, value in separation["afterimage"].items()
            if key.endswith("Pass")),
        "noCrossPackageDecisionChange": not any(
            value["decisionChanged"] for value in interference.values()),
        "duration": effects["priorityAtCurrentPayoff"]["duration"]["p975"]
        <= gates["maximumDurationIncreaseTurnsPerFight"],
        "reliability": faults == 0,
        "vow5": win_rate <= gates["maximumVow5WinRate"],
    }
    fixed_failure = (
        len(candidate) < gates["minimumActivePolicies"]
        or len(inactive) < gates["minimumInactivePolicies"]
        or len(viable) < gates["minimumViablePolicies"]
        or len(positive) < gates["minimumPositivePayoffPolicies"]
        or len(zero) < gates["minimumZeroPayoffPolicies"]
        or not checks["scorelineSeparation"]
        or not checks["afterimageSeparation"]
        or not checks["noCrossPackageDecisionChange"]
        or faults != 0 or not checks["vow5"]
        or effects["payoffAtPriorityOn"]["quality"]["p975"] <= 0
        or effects["priorityAtCurrentPayoff"]["procFights"]["p975"] <= 0
        or effects["payoffByPriorityInteraction"]["quality"]["p975"] <= 0
        or effects["priorityAtCurrentPayoff"]["duration"]["p025"]
        > gates["maximumDurationIncreaseTurnsPerFight"]
    )
    return {
        "effects": effects,
        "checks": checks,
        "fixedFailure": fixed_failure,
        "counts": {
            "activePolicies": len(candidate),
            "inactivePolicies": len(inactive),
            "ambiguousPolicies": cohort["policyCount"] - len(candidate) - len(inactive),
            "viablePolicies": len(viable),
            "positivePayoffPolicies": len(positive),
            "zeroPayoffPolicies": len(zero),
            "negativePayoffPolicies": len(negative),
            "faultRows": faults,
            "candidateVow5WinRate": win_rate,
            "policyIdentityMismatchRows": policy_mismatches,
        },
        "policySets": {
            "active": sorted(candidate), "inactive": sorted(inactive),
            "viable": sorted(viable), "positivePayoff": sorted(positive),
            "zeroPayoff": sorted(zero), "negativePayoff": sorted(negative),
            "scorelinePriorityOff": sorted(observed_routes["priorityOff"]["scoreline"]),
            "scorelinePriorityOn": sorted(observed_routes["priorityOn"]["scoreline"]),
            "afterimagePriorityOff": sorted(observed_routes["priorityOff"]["afterimage"]),
            "afterimagePriorityOn": sorted(observed_routes["priorityOn"]["afterimage"]),
        },
        "separation": separation,
        "interference": interference,
    }


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the Hearth blocked CRN summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    source = source_identity()
    ledger_before = identity.ledger_identity()
    started = time.monotonic()
    deadline = started + float(protocol["budget"]["maximumWallTimeSeconds"])
    manifests: dict[str, Any] = {}
    analysis: dict[str, Any] = {}
    execution_error = ""
    rows_observed = 0
    try:
        for key, expected in protocol["immutableInputs"].items():
            require(f"immutable {key}", source.get(key) == expected)
        for relative, expected in protocol["frozenEvidence"].items():
            require(relative, core.file_sha(core.ROOT / relative) == expected)
        require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
        require("design cells", set(protocol["designMatrix"]) == set(CELLS))
        require("new cells", protocol["newCells"] == list(CELLS[1:]))
        rows: dict[str, dict[tuple[int, int], dict[str, Any]]] = {}
        rows["H1Q0"], manifests["H1Q0"] = load_anchor(protocol)
        for cell in protocol["newCells"]:
            plan = plan_for(protocol, protocol_sha, cell)
            output, plan_sha, output_sha = run_probe(plan, deadline)
            require(f"{cell} output plan", output["planSha256"] == plan_sha)
            require(f"{cell} output probe", output["probeSha256"] == source["probeSha256"])
            require(f"{cell} payoff", output["payoffLevel"]
                    == protocol["designMatrix"][cell]["probePayoffLevel"])
            rows[cell] = indexed_rows(
                plan["rows"], output["rows"], protocol, cell)
            manifests[cell] = {
                "planSha256": plan_sha, "outputSha256": output_sha,
                "rows": len(output["rows"]), "reused": False,
            }
            rows_observed += len(output["rows"])
        require("new row ceiling", rows_observed
                == protocol["budget"]["maximumNewSimulatorObservationRows"])
        require("Godot process ceiling", len(protocol["newCells"])
                == protocol["budget"]["maximumGodotProcesses"])
        analysis = analyse(rows, protocol)
    except (KeyError, RuntimeError, subprocess.TimeoutExpired, TimeoutError,
            TypeError, ValueError) as error:
        execution_error = str(error)

    elapsed = time.monotonic() - started
    ledger_after = identity.ledger_identity()
    if (execution_error or elapsed > protocol["budget"]["maximumWallTimeSeconds"]
            or rows_observed != protocol["budget"]["maximumNewSimulatorObservationRows"]
            or ledger_after != ledger_before):
        boundary, outcome = 3, "inconclusive"
        decision = "record-hearth-blocked-crn-inconclusive-at-cap"
    elif all(analysis["checks"].values()):
        boundary, outcome = 1, "success"
        decision = "freeze-hearth-package-for-independent-heldout-confirmation"
    elif analysis["fixedFailure"]:
        boundary, outcome = 2, "futility"
        decision = "close-hearth-scalar-family-and-continue-structural-narrowing"
    else:
        boundary, outcome = 3, "inconclusive"
        decision = "record-hearth-blocked-crn-inconclusive-at-cap"

    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "decisionBoundary": boundary,
        "decision": decision,
        "outcomeClass": outcome,
        "protocolSha256": protocol_sha,
        "sourceIdentity": source,
        "designMatrix": protocol["designMatrix"],
        "analysis": analysis,
        "execution": {
            "cells": manifests,
            "newSimulatorObservationRows": rows_observed,
            "newLedgerRows": ledger_after["records"] - ledger_before["records"],
            "protectedSeedRows": ledger_after["protectedSeedRows"],
            "maximumModelContextTokens": 0,
            "wallTimeSeconds": elapsed,
            "executionError": execution_error,
        },
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "additionalJointCells": 0,
        "authority": protocol["decisionRules"][f"{outcome}Authority"],
    }
    SUMMARY.parent.mkdir(parents=True, exist_ok=True)
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": "PASS",
        "decision": decision,
        "decisionBoundary": boundary,
        "newSimulatorObservationRows": rows_observed,
        "summarySha256": core.file_sha(SUMMARY),
    }))


if __name__ == "__main__":
    main()
