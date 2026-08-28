#!/usr/bin/env python3
"""Mechanism-blocked CRN identification for Glassvow issue #421."""

from __future__ import annotations

import argparse
import itertools
import json
import math
import statistics
import subprocess
import time
from pathlib import Path
from typing import Any, Callable

import post_v38_factorial as variants_v1
import post_v38_knob_identity as identity_v1
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-blocked-crn-v2.json"
MANIFEST = core.ROOT / "execution/post-v38-blocked-crn-v2.json"
SUMMARY = core.ROOT / "summaries/post-v38-blocked-crn-v2.json"
LIVE_CONTENT_SHA = "a0d608a5142d2e3aab799cdf33d3163922b402c2aaf2a895e46e096399b56cf1"
MEDIATORS = {"scorelineIntensity", "afterimageIntensity"}
Endpoint = Callable[[str, str], dict[Any, float]]


def source_identity() -> dict[str, Any]:
    return {
        "sourceCommit": subprocess.run(
            ["git", "rev-parse", "HEAD"], cwd=core.SOURCE, check=True,
            text=True, capture_output=True,
        ).stdout.strip(),
        "godotVersion": subprocess.run(
            ["godot", "--version"], check=True, text=True, capture_output=True,
        ).stdout.strip(),
        "liveContentSha256": core.file_sha(core.CACHE / f"{LIVE_CONTENT_SHA}.json"),
        "baseResearchContentSha256": core.file_sha(
            core.CACHE / f"{variants_v1.BASE_CONTENT_SHA}.json"
        ),
        "combatRulesSha256": core.file_sha(core.SOURCE / "domain/rules/combat.gd"),
        "pilotSha256": core.file_sha(core.SOURCE / "tools/balance_pilot.gd"),
        "balanceSimSha256": core.file_sha(core.SOURCE / "tools/balance_sim.gd"),
        "probeSha256": core.file_sha(core.SOURCE / "tools/research_421_probe.gd"),
        "researchCoreSha256": core.file_sha(core.ROOT / "research.py"),
        "variantBuilderSha256": core.file_sha(core.ROOT / "post_v38_factorial.py"),
        "runnerSha256": core.file_sha(Path(__file__)),
    }


def verify_entry(protocol: dict[str, Any], protocol_sha: str) -> dict[str, Any]:
    actual = source_identity()
    for key, expected in protocol["immutableInputs"].items():
        if actual.get(key) != expected:
            raise RuntimeError(
                f"immutable input drift: {key} expected {expected} got {actual.get(key)}"
            )
    identity_path = core.ROOT / protocol["entryGate"]["identitySummary"]
    if core.file_sha(identity_path) != protocol["entryGate"]["identitySummarySha256"]:
        raise RuntimeError("knob identity summary drifted")
    identity = json.loads(identity_path.read_text())
    if identity.get("decision") != "knobs-identity-safe" \
            or identity.get("protocolSha256") \
            != protocol["entryGate"]["identityProtocolSha256"]:
        raise RuntimeError("knob identity gate is not green")
    for aspect, expected in protocol["entryGate"]["frozenPathCrosscheck"].items():
        observed = identity["identityCases"][f"null-{aspect}-sampled"]
        for key, value in expected.items():
            if observed.get(key) != value:
                raise RuntimeError(f"{aspect} frozen null path drifted at {key}")
    if not MANIFEST.is_file():
        raise RuntimeError("execution manifest is missing")
    manifest = json.loads(MANIFEST.read_text())
    required = {
        "protocolSha256": protocol_sha,
        "runnerSha256": actual["runnerSha256"],
        "probeSha256": actual["probeSha256"],
        "identitySummarySha256": core.file_sha(identity_path),
        "ledgerSha256BeforeFirstObservation": protocol["ledgerFreeze"]["sha256"],
        "ledgerRecordsBeforeFirstObservation": protocol["ledgerFreeze"]["records"],
        "maximumSimulatorObservationRows": protocol["budget"][
            "maximumNewSimulatorObservationRows"
        ],
        "maximumWallTimeSeconds": protocol["budget"]["maximumWallTimeSeconds"],
        "maximumModelContextTokensDuringExecutionAndDecision": 0,
    }
    for key, expected in required.items():
        if manifest.get(key) != expected:
            raise RuntimeError(f"execution manifest drifted at {key}")
    ledger = identity_v1.ledger_identity()
    if ledger != protocol["ledgerFreeze"]:
        with core.open_ledger() as db:
            if core.existing_record(db, protocol_sha) is None:
                raise RuntimeError("ledger changed before the first blocked observation")
    variants = variants_v1.prepare_variants()
    observed_variants = {key: row["sha256"] for key, row in variants.items()}
    if observed_variants != protocol["contentVariants"]:
        raise RuntimeError("content variant identities drifted")
    return {**actual, "executionManifestSha256": core.file_sha(MANIFEST)}


def cell_key(cell: dict[str, Any]) -> str:
    return str(cell["id"])


def find_cell(cells: list[dict[str, Any]], **levels: Any) -> str:
    found = [cell_key(cell) for cell in cells
             if all(cell[key] == value for key, value in levels.items())]
    if len(found) != 1:
        raise ValueError(f"expected one cell for {levels}, found {found}")
    return found[0]


def cohort_rows(protocol: dict[str, Any], cell: dict[str, Any] | None) -> list[dict[str, Any]]:
    cohort = protocol["cohorts"]
    label = "live-baseline" if cell is None else cell_key(cell)
    research = protocol["baseline"]["researchSettings"] if cell is None else {
        "wardSetupPriority": cell["W"],
        "acquisitionPriority": cell["Q"],
    }
    random_first = int(cohort["randomBuildSeeds"]["first"])
    random_last = int(cohort["randomBuildSeeds"]["last"])
    rows = [{
        "id": f"blocked-random-{label}-{aspect}-v{vow}-{seed}",
        "stage": "post-v38-blocked-crn",
        "mode": "whole-run",
        "arm": "random",
        "aspect": aspect,
        "vow": vow,
        "seed": seed,
        "randomBuild": True,
        "randomPlay": False,
        "research421": research,
    } for aspect in ("duskblade", "ashwarden") for vow in (0, 5)
        for seed in range(random_first, random_last + 1)]
    policy = cohort["policyIdentity"]
    policy_seeds = cohort["policySimulationSeeds"]
    rows.extend({
        "id": f"blocked-policy-{label}-{index}-{seed}",
        "stage": "post-v38-blocked-crn",
        "mode": "whole-run",
        "arm": "policy",
        "aspect": "duskblade",
        "vow": 5,
        "seed": seed,
        "policyRoot": int(policy["root"]),
        "policyIndex": index,
        "research421": research,
    } for index in range(int(policy["firstIndex"]), int(policy["lastIndex"]) + 1)
        for seed in range(int(policy_seeds["first"]), int(policy_seeds["last"]) + 1))
    expected = int(protocol["budget"]["candidateRowsPerCell"])
    if len(rows) != expected:
        raise ValueError(f"{label} has {len(rows)} rows, expected {expected}")
    if any(3000 <= int(row["seed"]) <= 5399 for row in rows):
        raise ValueError("protected seed entered the blocked cohort")
    return rows


def plan_for(protocol_sha: str, content: str, rows: list[dict[str, Any]]) -> dict[str, Any]:
    return {
        "schemaVersion": 1,
        "mode": "whole-run",
        "protocolSha256": protocol_sha,
        "content": content,
        "rows": rows,
    }


def validate_rectangle(protocol: dict[str, Any], rows: list[dict[str, Any]]) -> None:
    expected = int(protocol["budget"]["candidateRowsPerCell"])
    if len(rows) != expected or len({row["id"] for row in rows}) != expected:
        raise ValueError("incomplete or duplicate cell rectangle")
    random_rows = [row for row in rows if row["arm"] == "random"]
    policy_rows = [row for row in rows if row["arm"] == "policy"]
    random_expected = {
        (aspect, vow, seed)
        for aspect in ("duskblade", "ashwarden") for vow in (0, 5)
        for seed in range(
            int(protocol["cohorts"]["randomBuildSeeds"]["first"]),
            int(protocol["cohorts"]["randomBuildSeeds"]["last"]) + 1,
        )
    }
    policy_expected = {
        (index, seed)
        for index in range(
            int(protocol["cohorts"]["policyIdentity"]["firstIndex"]),
            int(protocol["cohorts"]["policyIdentity"]["lastIndex"]) + 1,
        )
        for seed in range(
            int(protocol["cohorts"]["policySimulationSeeds"]["first"]),
            int(protocol["cohorts"]["policySimulationSeeds"]["last"]) + 1,
        )
    }
    if {(row["aspect"], int(row["vow"]), int(row["seed"]))
            for row in random_rows} != random_expected:
        raise ValueError("RandomBuild CRN rectangle drifted")
    if {(int(row["policyIndex"]), int(row["seed"]))
            for row in policy_rows} != policy_expected:
        raise ValueError("policy CRN rectangle drifted")


def split_rows(rows: list[dict[str, Any]]) -> tuple[
        dict[tuple[str, int, int], dict[str, Any]],
        dict[tuple[int, int], dict[str, Any]]]:
    random_rows = {
        (str(row["aspect"]), int(row["vow"]), int(row["seed"])): row
        for row in rows if row["arm"] == "random"
    }
    policy_rows = {
        (int(row["policyIndex"]), int(row["seed"])): row
        for row in rows if row["arm"] == "policy"
    }
    return random_rows, policy_rows


def is_fault(row: dict[str, Any]) -> bool:
    return row.get("outcome") in ("stall", "error") \
        or not str(row.get("error", "")).strip() == ""


def route_counts(row: dict[str, Any], route: str) -> tuple[int, int]:
    events = row.get("packageEvents") or {}
    return (
        int(events.get(f"{route}Applied", 0)),
        int(events.get(f"{route}Consumed", 0)),
    )


def mean_turns(row: dict[str, Any]) -> float | None:
    fights = row.get("fights") or []
    if not fights:
        return None
    return statistics.fmean(float(fight["turns"]) for fight in fights)


def endpoint_reader(
    cell_rows: dict[str, list[dict[str, Any]]]
) -> Endpoint:
    cache: dict[tuple[str, str], dict[Any, float]] = {}

    def read(cell: str, endpoint: str) -> dict[Any, float]:
        key = (cell, endpoint)
        if key in cache:
            return cache[key]
        random_rows, policy_rows = split_rows(cell_rows[cell])
        if endpoint.startswith("randomWin:"):
            _, aspect, vow_text = endpoint.split(":")
            vow = int(vow_text.removeprefix("v"))
            result = {
                seed: float(row["outcome"] == "win")
                for (found_aspect, found_vow, seed), row in random_rows.items()
                if (found_aspect, found_vow) == (aspect, vow)
            }
        elif endpoint == "policyWin":
            result = {
                index: statistics.fmean(
                    float(row["outcome"] == "win")
                    for (found, _), row in policy_rows.items() if found == index
                )
                for index in sorted({index for index, _ in policy_rows})
            }
        elif endpoint in MEDIATORS:
            route = endpoint.removesuffix("Intensity")
            result = {
                index: math.log1p(statistics.fmean(
                    min(route_counts(row, route))
                    for (found, _), row in policy_rows.items() if found == index
                ))
                for index in sorted({index for index, _ in policy_rows})
            }
        else:
            raise ValueError(f"unknown endpoint {endpoint}")
        cache[key] = result
        return result

    return read


def signed_interval(values: list[float], scale: float, resamples: int) -> dict[str, float]:
    if resamples != 5000:
        raise ValueError("the frozen estimator requires exactly 5000 resamples")
    if scale > 0:
        return core.interval(values, scale, 421)
    point = statistics.fmean(values)
    if point == 0 and all(value == 0 for value in values):
        return {"point": 0.0, "p025": 0.0, "p975": 0.0, "scale": 0.0}
    infinite = math.inf if point > 0 else -math.inf
    return {"point": infinite, "p025": infinite, "p975": infinite, "scale": 0.0}


def linear_effect(
    groups: dict[str, list[str]], coefficients: dict[str, float], endpoint: str,
    read: Endpoint, resamples: int,
) -> dict[str, Any]:
    if set(groups) != set(coefficients):
        raise ValueError("contrast groups and coefficients differ")
    group_values: dict[str, dict[Any, float]] = {}
    units: set[Any] | None = None
    for name, cells in groups.items():
        if not cells:
            raise ValueError(f"empty contrast group {name}")
        observed = [read(cell, endpoint) for cell in cells]
        keys = set(observed[0])
        if any(set(values) != keys for values in observed):
            raise ValueError(f"unmatched cells inside contrast group {name}")
        if units is not None and keys != units:
            raise ValueError("unmatched CRN identities across contrast groups")
        units = keys
        group_values[name] = {
            unit: statistics.fmean(values[unit] for values in observed)
            for unit in keys
        }
    assert units is not None
    contrasts = [
        sum(coefficients[name] * group_values[name][unit] for name in groups)
        for unit in sorted(units)
    ]
    raw = signed_interval(contrasts, 1.0, resamples)
    result: dict[str, Any] = {
        "raw": raw,
        "crnUnits": len(contrasts),
        "groups": {name: sorted(cells) for name, cells in groups.items()},
        "coefficients": coefficients,
    }
    if endpoint in MEDIATORS:
        scale = math.sqrt(statistics.fmean(
            statistics.pvariance(list(values.values()))
            for values in group_values.values()
        ))
        result["standardised"] = signed_interval(contrasts, scale, resamples)
    return result


def all_endpoints(protocol: dict[str, Any]) -> list[str]:
    return list(protocol["estimands"]["fittedEndpoints"])


def fit_contrast(
    groups: dict[str, list[str]], coefficients: dict[str, float], read: Endpoint,
    protocol: dict[str, Any],
) -> dict[str, Any]:
    return {
        endpoint: linear_effect(
            groups, coefficients, endpoint, read,
            int(protocol["budget"]["bootstrapResamples"]),
        )
        for endpoint in all_endpoints(protocol)
    }


def mechanism_blocks(
    protocol: dict[str, Any], read: Endpoint,
) -> dict[str, Any]:
    cells = protocol["initialDesignMatrix"]
    score = [cell for cell in cells if "scoreline" in cell["blocks"]]
    after = [cell for cell in cells if "afterimage" in cell["blocks"]]
    ids = lambda rows, **levels: sorted(
        cell_key(cell) for cell in rows
        if all(cell[key] == value for key, value in levels.items())
    )
    score_specs = {
        "scorelinePayoff": ({"low": ids(score, S="low"), "high": ids(score, S="high")},
                             {"low": -1.0, "high": 1.0}),
        "acquisitionPriority": ({"low": ids(score, Q=2), "high": ids(score, Q=4)},
                                {"low": -1.0, "high": 1.0}),
        "faultlineRarity": ({"low": ids(score, R="uncommon"),
                             "high": ids(score, R="rare")},
                            {"low": -1.0, "high": 1.0}),
        "scorelinePayoff_x_acquisitionPriority": ({
            "00": ids(score, S="low", Q=2), "10": ids(score, S="high", Q=2),
            "01": ids(score, S="low", Q=4), "11": ids(score, S="high", Q=4)},
            {"00": 1.0, "10": -1.0, "01": -1.0, "11": 1.0}),
        "scorelinePayoff_x_faultlineRarity": ({
            "00": ids(score, S="low", R="uncommon"),
            "10": ids(score, S="high", R="uncommon"),
            "01": ids(score, S="low", R="rare"),
            "11": ids(score, S="high", R="rare")},
            {"00": 1.0, "10": -1.0, "01": -1.0, "11": 1.0}),
        "acquisitionPriority_x_faultlineRarity": ({
            "00": ids(score, Q=2, R="uncommon"), "10": ids(score, Q=4, R="uncommon"),
            "01": ids(score, Q=2, R="rare"), "11": ids(score, Q=4, R="rare")},
            {"00": 1.0, "10": -1.0, "01": -1.0, "11": 1.0}),
    }
    after_specs = {
        "afterimagePayoff": ({"low": ids(after, A="low"), "high": ids(after, A="high")},
                              {"low": -1.0, "high": 1.0}),
        "acquisitionPriority": ({"low": ids(after, Q=2), "high": ids(after, Q=4)},
                                {"low": -1.0, "high": 1.0}),
        "wardSetupPriority_0_to_1": ({"low": ids(after, W=0), "high": ids(after, W=1)},
                                     {"low": -1.0, "high": 1.0}),
        "wardSetupPriority_1_to_2": ({"low": ids(after, W=1), "high": ids(after, W=2)},
                                     {"low": -1.0, "high": 1.0}),
        "afterimagePayoff_x_acquisitionPriority": ({
            "00": ids(after, A="low", Q=2), "10": ids(after, A="high", Q=2),
            "01": ids(after, A="low", Q=4), "11": ids(after, A="high", Q=4)},
            {"00": 1.0, "10": -1.0, "01": -1.0, "11": 1.0}),
        "afterimagePayoff_x_wardSetupPriority_0_to_1": ({
            "00": ids(after, A="low", W=0), "10": ids(after, A="high", W=0),
            "01": ids(after, A="low", W=1), "11": ids(after, A="high", W=1)},
            {"00": 1.0, "10": -1.0, "01": -1.0, "11": 1.0}),
        "afterimagePayoff_x_wardSetupPriority_1_to_2": ({
            "00": ids(after, A="low", W=1), "10": ids(after, A="high", W=1),
            "01": ids(after, A="low", W=2), "11": ids(after, A="high", W=2)},
            {"00": 1.0, "10": -1.0, "01": -1.0, "11": 1.0}),
        "acquisitionPriority_x_wardSetupPriority_0_to_1": ({
            "00": ids(after, Q=2, W=0), "10": ids(after, Q=4, W=0),
            "01": ids(after, Q=2, W=1), "11": ids(after, Q=4, W=1)},
            {"00": 1.0, "10": -1.0, "01": -1.0, "11": 1.0}),
        "acquisitionPriority_x_wardSetupPriority_1_to_2": ({
            "00": ids(after, Q=2, W=1), "10": ids(after, Q=4, W=1),
            "01": ids(after, Q=2, W=2), "11": ids(after, Q=4, W=2)},
            {"00": 1.0, "10": -1.0, "01": -1.0, "11": 1.0}),
    }
    return {
        "scoreline": {name: fit_contrast(groups, coefficients, read, protocol)
                      for name, (groups, coefficients) in score_specs.items()},
        "afterimage": {name: fit_contrast(groups, coefficients, read, protocol)
                       for name, (groups, coefficients) in after_specs.items()},
    }


def interference_quad(cells: list[dict[str, Any]], q: int, rarity: str,
                      ward: int) -> dict[str, list[str]]:
    return {
        "00": [find_cell(cells, S="low", A="low", Q=q, R=rarity, W=ward)],
        "10": [find_cell(cells, S="high", A="low", Q=q, R=rarity, W=ward)],
        "01": [find_cell(cells, S="low", A="high", Q=q, R=rarity, W=ward)],
        "11": [find_cell(cells, S="high", A="high", Q=q, R=rarity, W=ward)],
    }


def trigger_from_effect(name: str, effects: dict[str, Any], reasons: list[str]) -> None:
    for endpoint, result in effects.items():
        estimate = result["standardised"] if endpoint in MEDIATORS else result["raw"]
        threshold = 0.25 if endpoint in MEDIATORS else 0.10
        excludes_zero = estimate["p025"] > 0 or estimate["p975"] < 0
        if excludes_zero and abs(estimate["point"]) >= threshold:
            reasons.append(f"{name}:{endpoint}")


def initial_interference(
    protocol: dict[str, Any], read: Endpoint,
    baseline: list[dict[str, Any]], cell_rows: dict[str, list[dict[str, Any]]],
) -> tuple[dict[str, Any], list[str]]:
    cells = protocol["initialDesignMatrix"]
    coefficients = {"00": 1.0, "10": -1.0, "01": -1.0, "11": 1.0}
    fitted: dict[str, Any] = {}
    reasons: list[str] = []
    for q in (2, 4):
        effects = fit_contrast(
            interference_quad(cells, q, "uncommon", 2), coefficients, read, protocol
        )
        fitted[f"Q-{q}"] = effects
        trigger_from_effect(f"Q-{q}", effects, reasons)
    triple_groups: dict[str, list[str]] = {}
    triple_coefficients: dict[str, float] = {}
    for q, multiplier in ((2, -1.0), (4, 1.0)):
        for corner, group in interference_quad(cells, q, "uncommon", 2).items():
            name = f"Q-{q}:{corner}"
            triple_groups[name] = group
            triple_coefficients[name] = multiplier * coefficients[corner]
    triple = fit_contrast(triple_groups, triple_coefficients, read, protocol)
    fitted["scorelinePayoff_x_afterimagePayoff_x_acquisitionPriority"] = triple
    trigger_from_effect("SxAxQ", triple, reasons)
    baseline_random, baseline_policy = split_rows(baseline)
    added_faults: dict[str, int] = {}
    for q in (2, 4):
        joint = find_cell(cells, S="high", A="high", Q=q, R="uncommon", W=2)
        random_rows, policy_rows = split_rows(cell_rows[joint])
        count = sum(is_fault(row) and not is_fault(baseline_random[key])
                    for key, row in random_rows.items())
        count += sum(is_fault(row) and not is_fault(baseline_policy[key])
                     for key, row in policy_rows.items())
        added_faults[f"Q-{q}"] = count
        if count:
            reasons.append(f"Q-{q}:added-faults")
    fitted["jointHighAddedFaults"] = added_faults
    return fitted, sorted(reasons)


def expanded_interference(
    protocol: dict[str, Any], read: Endpoint,
) -> dict[str, Any]:
    cells = [*protocol["initialDesignMatrix"], *protocol["optionalExpansionMatrix"]]
    coefficients = {"00": 1.0, "10": -1.0, "01": -1.0, "11": 1.0}
    contexts = [("uncommon", ward) for ward in (0, 1, 2)] + [("rare", 2)]
    return {
        f"Q-{q}:R-{rarity}:W-{ward}": fit_contrast(
            interference_quad(cells, q, rarity, ward), coefficients, read, protocol
        )
        for q in (2, 4) for rarity, ward in contexts
    }


def candidate_gate(
    protocol: dict[str, Any], candidate: list[dict[str, Any]],
    baseline: list[dict[str, Any]],
) -> dict[str, Any]:
    candidate_random, candidate_policy = split_rows(candidate)
    baseline_random, baseline_policy = split_rows(baseline)
    if set(candidate_random) != set(baseline_random) \
            or set(candidate_policy) != set(baseline_policy):
        raise ValueError("candidate and live baseline rectangles differ")
    active: dict[str, set[int]] = {}
    consumed: dict[str, set[int]] = {}
    indices = sorted({index for index, _ in candidate_policy})
    for route in ("scoreline", "afterimage"):
        active[route] = {
            index for index in indices if any(
                min(route_counts(row, route)) > 0
                for (found, _), row in candidate_policy.items() if found == index
            )
        }
        consumed[route] = {
            index for index in indices if any(
                route_counts(row, route)[1] > 0
                for (found, _), row in candidate_policy.items() if found == index
            )
        }
    exclusive = {
        "scoreline": active["scoreline"] - active["afterimage"],
        "afterimage": active["afterimage"] - active["scoreline"],
    }
    random_grids: dict[str, Any] = {}
    random_clear = True
    for aspect, vow in itertools.product(("duskblade", "ashwarden"), (0, 5)):
        keys = sorted(key for key in candidate_random if key[:2] == (aspect, vow))
        deltas = [
            float(candidate_random[key]["outcome"] == "win")
            - float(baseline_random[key]["outcome"] == "win") for key in keys
        ]
        movement = signed_interval(
            deltas, 1.0, int(protocol["budget"]["bootstrapResamples"])
        )
        rate = statistics.fmean(
            candidate_random[key]["outcome"] == "win" for key in keys
        )
        added_faults = sum(
            is_fault(candidate_random[key]) and not is_fault(baseline_random[key])
            for key in keys
        )
        clear = rate < 0.50 and abs(movement["point"]) <= 0.10 and added_faults == 0
        random_clear = random_clear and clear
        random_grids[f"{aspect}:v{vow}"] = {
            "winRate": rate,
            "candidateMinusLive": movement,
            "addedFaults": added_faults,
            "clear": clear,
        }
    policy_faults = sum(is_fault(row) for row in candidate_policy.values())
    added_policy_faults = sum(
        is_fault(row) and not is_fault(baseline_policy[key])
        for key, row in candidate_policy.items()
    )
    duration_values: list[float] = []
    duration_missing = 0
    for key, row in candidate_policy.items():
        candidate_turns = mean_turns(row)
        baseline_turns = mean_turns(baseline_policy[key])
        if candidate_turns is None or baseline_turns is None:
            duration_missing += 1
        else:
            duration_values.append(candidate_turns - baseline_turns)
    duration = None if duration_missing else signed_interval(
        duration_values, 1.0, int(protocol["budget"]["bootstrapResamples"])
    )
    sensitivity = {
        route: {"active": len(active[route]), "inactive": len(indices) - len(active[route])}
        for route in active
    }
    sensitivity_clear = all(
        counts["active"] >= 16 and counts["inactive"] >= 16
        for counts in sensitivity.values()
    )
    exclusive_counts = {route: len(values) for route, values in exclusive.items()}
    separation_clear = all(count >= 4 for count in exclusive_counts.values())
    consumption_counts = {route: len(values) for route, values in consumed.items()}
    reachability_clear = all(count >= 8 for count in consumption_counts.values())
    reliability_clear = policy_faults == 0 and added_policy_faults == 0
    vow5_rate = statistics.fmean(row["outcome"] == "win"
                                 for row in candidate_policy.values())
    vow5_clear = vow5_rate <= 0.90
    duration_clear = duration is not None and duration["p975"] <= 0.25
    non_duration = {
        "policySensitivity": sensitivity_clear,
        "functionalSeparation": separation_clear,
        "reachability": reachability_clear,
        "randomBuild": random_clear,
        "reliability": reliability_clear,
        "vow5": vow5_clear,
    }
    feasible = all(non_duration.values()) and duration_clear
    duration_uncertain = all(non_duration.values()) and not duration_clear \
        and (duration is None or duration["p025"] <= 0.25)
    return {
        "policySensitivity": sensitivity,
        "exclusivePolicyIdentities": {route: sorted(values)
                                      for route, values in exclusive.items()},
        "exclusiveCounts": exclusive_counts,
        "consumptionPolicyCounts": consumption_counts,
        "randomBuild": random_grids,
        "policyFaults": policy_faults,
        "addedPolicyFaults": added_policy_faults,
        "vow5WinRate": vow5_rate,
        "durationCandidateMinusLive": duration,
        "durationMissingPairs": duration_missing,
        "gates": {**non_duration, "duration": duration_clear},
        "feasible": feasible,
        "uncertainOnly": duration_uncertain,
    }


def selection_key(cell: dict[str, Any]) -> tuple[Any, ...]:
    return (
        ("low", "high").index(cell["S"]),
        ("low", "high").index(cell["A"]),
        (2, 4).index(cell["Q"]),
        ("uncommon", "rare").index(cell["R"]),
        (0, 1, 2).index(cell["W"]),
        cell_key(cell),
    )


def protocol_observation_count(db: Any, protocol_sha: str) -> int:
    return int(db.execute(
        "SELECT COUNT(*) FROM records WHERE kind = 'observation' AND identity LIKE ?",
        (f"{protocol_sha}:%",),
    ).fetchone()[0])


def enforce_wall_cap(protocol: dict[str, Any], started: float) -> None:
    if time.monotonic() - started > float(protocol["budget"]["maximumWallTimeSeconds"]):
        raise TimeoutError("blocked CRN wall-time cap reached")


def run_cells(
    db: Any, protocol: dict[str, Any], protocol_sha: str,
    variants: dict[str, dict[str, Any]], cells: list[dict[str, Any]],
    outputs: dict[str, list[dict[str, Any]]], started: float,
) -> None:
    for index, cell in enumerate(cells, 1):
        enforce_wall_cap(protocol, started)
        identity = variants_v1._variant_id(cell["S"], cell["A"], cell["R"])
        rows = cohort_rows(protocol, cell)
        output = core.run_plan(
            db, protocol_sha,
            plan_for(protocol_sha, variants[identity]["path"], rows),
        )
        validate_rectangle(protocol, output["rows"])
        outputs[cell_key(cell)] = output["rows"]
        observed = protocol_observation_count(db, protocol_sha)
        if observed > int(protocol["budget"]["maximumNewSimulatorObservationRows"]):
            raise RuntimeError("simulator observation cap exceeded")
        print(json.dumps({"stage": "blocked-crn", "cell": index,
                          "of": len(cells), "id": cell_key(cell),
                          "protocolObservationRows": observed}), flush=True)


def execute() -> None:
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    identity = verify_entry(protocol, protocol_sha)
    started = time.monotonic()
    variants = variants_v1.prepare_variants()
    db = core.open_ledger()
    core.record(db, "protocol", protocol_sha, protocol)
    core.record(db, "source-identity", core.sha(core.canonical(identity).encode()), identity)
    baseline_plan = plan_for(
        protocol_sha,
        str(core.CACHE / f"{LIVE_CONTENT_SHA}.json"),
        cohort_rows(protocol, None),
    )
    baseline_output = core.run_plan(db, protocol_sha, baseline_plan)
    baseline = baseline_output["rows"]
    validate_rectangle(protocol, baseline)
    outputs: dict[str, list[dict[str, Any]]] = {}
    run_cells(
        db, protocol, protocol_sha, variants,
        protocol["initialDesignMatrix"], outputs, started,
    )
    initial_expected = int(protocol["budget"]["initialObservationRows"])
    if protocol_observation_count(db, protocol_sha) != initial_expected:
        raise RuntimeError("initial observation rectangle does not match its frozen budget")
    read = endpoint_reader(outputs)
    blocks = mechanism_blocks(protocol, read)
    interference, trigger_reasons = initial_interference(
        protocol, read, baseline, outputs
    )
    enforce_wall_cap(protocol, started)
    expansion_triggered = bool(trigger_reasons)
    if expansion_triggered:
        run_cells(
            db, protocol, protocol_sha, variants,
            protocol["optionalExpansionMatrix"], outputs, started,
        )
    expected_rows = int(protocol["budget"][
        "maximumNewSimulatorObservationRows" if expansion_triggered
        else "initialObservationRows"
    ])
    observed_rows = protocol_observation_count(db, protocol_sha)
    if observed_rows != expected_rows:
        raise RuntimeError("final observation rectangle does not match its frozen budget")
    all_cells = [*protocol["initialDesignMatrix"]]
    if expansion_triggered:
        all_cells.extend(protocol["optionalExpansionMatrix"])
    gates = {
        cell_key(cell): candidate_gate(protocol, outputs[cell_key(cell)], baseline)
        for cell in all_cells
    }
    enforce_wall_cap(protocol, started)
    feasible = sorted(
        (cell for cell in all_cells if gates[cell_key(cell)]["feasible"]),
        key=selection_key,
    )
    selected = feasible[0] if feasible else None
    if selected is not None:
        decision = "freeze-one-for-held-out-confirmation"
        boundary = 1
    elif any(result["uncertainOnly"] for result in gates.values()):
        decision = "inconclusive-at-preregistered-cap"
        boundary = 3
    else:
        decision = "close-scalar-family-continue-structurally"
        boundary = 2
    analysis = {
        "schemaVersion": 2,
        "protocolSha256": protocol_sha,
        "runnerSha256": identity["runnerSha256"],
        "mechanismBlocks": blocks,
        "initialCrossPackageInterference": interference,
        "expansionTriggered": expansion_triggered,
        "expansionReasons": trigger_reasons,
        "expandedCrossPackageInterference": expanded_interference(protocol, read)
        if expansion_triggered else None,
        "candidateGates": gates,
    }
    analysis_sha, _ = core.cache_json(analysis)
    core.record(db, "analysis", f"post-v38-blocked-crn:analysis:{protocol_sha}", {
        **analysis, "analysisSha256": analysis_sha,
    })
    selected_packet = None if selected is None else {
        "cell": selected,
        "contentSha256": variants[
            variants_v1._variant_id(selected["S"], selected["A"], selected["R"])
        ]["sha256"],
        "research421": {
            "acquisitionPriority": selected["Q"],
            "wardSetupPriority": selected["W"],
        },
    }
    summary = {
        "schemaVersion": 2,
        "decisionBoundary": boundary,
        "decision": decision,
        "protocolSha256": protocol_sha,
        "runnerSha256": identity["runnerSha256"],
        "executionManifestSha256": identity["executionManifestSha256"],
        "analysisSha256": analysis_sha,
        "expansionTriggered": expansion_triggered,
        "expansionReasons": trigger_reasons,
        "initialUniqueCells": len(protocol["initialDesignMatrix"]),
        "optionalCellsObserved": len(protocol["optionalExpansionMatrix"])
        if expansion_triggered else 0,
        "newSimulatorObservationRows": observed_rows,
        "protectedSeedRows": 0,
        "feasibleCellsInFrozenOrder": [cell_key(cell) for cell in feasible],
        "selectedCandidate": selected_packet,
        "wallTimeSeconds": time.monotonic() - started,
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    summary_sha, _ = core.cache_json(summary)
    core.record(db, "analysis", f"post-v38-blocked-crn:summary:{protocol_sha}", {
        **summary, "summarySha256": summary_sha,
    })
    print(core.canonical({**summary, "summarySha256": summary_sha}))


def record_inconclusive(error: Exception) -> None:
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    with core.open_ledger() as db:
        observations = protocol_observation_count(db, protocol_sha)
    summary = {
        "schemaVersion": 2,
        "decisionBoundary": 3,
        "decision": "inconclusive-at-preregistered-cap",
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "newSimulatorObservationRows": observations,
        "protectedSeedRows": 0,
        "faultType": type(error).__name__,
        "fault": str(error),
        "authority": "Do not rerun or extend this protocol.",
    }
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite an existing blocked CRN summary") from error
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical(summary))


def validate_design() -> None:
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    identity = verify_entry(protocol, protocol_sha)
    initial = protocol["initialDesignMatrix"]
    optional = protocol["optionalExpansionMatrix"]
    if len(initial) != 20 or len(optional) != 12:
        raise AssertionError("design cell ceilings drifted")
    ids = [cell_key(cell) for cell in [*initial, *optional]]
    if len(set(ids)) != 32:
        raise AssertionError("design contains a physical duplicate")
    if len([cell for cell in initial if "scoreline" in cell["blocks"]]) != 8:
        raise AssertionError("Scoreline block is not 2 x 2 x 2")
    if len([cell for cell in initial if "afterimage" in cell["blocks"]]) != 12:
        raise AssertionError("Afterimage block is not 2 x 2 x 3")
    for q in (2, 4):
        interference_quad(initial, q, "uncommon", 2)
    baseline = cohort_rows(protocol, None)
    validate_rectangle(protocol, [{**row, "policyIndex": row.get("policyIndex", -1)}
                                  for row in baseline])
    if len(initial) * len(baseline) + len(baseline) \
            != int(protocol["budget"]["initialObservationRows"]):
        raise AssertionError("initial row arithmetic drifted")
    if len(optional) * len(baseline) \
            != int(protocol["budget"]["optionalExpansionObservationRows"]):
        raise AssertionError("optional row arithmetic drifted")
    design = {cell_key(cell): cell for cell in initial}

    def synthetic_read(cell_id: str, _endpoint: str) -> dict[int, float]:
        cell = design[cell_id]
        level = float(cell["S"] == "high") + 2.0 * float(cell["A"] == "high") \
            + float(cell["Q"] == 4) + float(cell["R"] == "rare") + float(cell["W"])
        return {unit: level + unit / 10.0 for unit in range(4)}

    fitted = mechanism_blocks(protocol, synthetic_read)
    if not math.isclose(
        fitted["scoreline"]["scorelinePayoff"]["policyWin"]["raw"]["point"],
        1.0, rel_tol=0.0, abs_tol=1e-12,
    ):
        raise AssertionError("Scoreline main-effect estimator self-check failed")
    if not math.isclose(
        fitted["afterimage"]["wardSetupPriority_0_to_1"]["policyWin"]["raw"][
            "point"],
        1.0, rel_tol=0.0, abs_tol=1e-12,
    ):
        raise AssertionError("adjacent Ward estimator self-check failed")
    candidate_rows = [{**row, "policyIndex": row.get("policyIndex", -1),
                       "outcome": "loss", "error": "", "fights": [{"turns": 1}],
                       "packageEvents": {}}
                      for row in cohort_rows(protocol, initial[0])]
    live_rows = [{**row, "policyIndex": row.get("policyIndex", -1),
                  "outcome": "loss", "error": "", "fights": [{"turns": 1}],
                  "packageEvents": {}}
                 for row in cohort_rows(protocol, None)]
    for row in candidate_rows:
        if row["arm"] != "policy":
            continue
        index = int(row["policyIndex"])
        if index < 32:
            row["packageEvents"].update({"scorelineApplied": 1, "scorelineConsumed": 1})
        if 16 <= index < 48:
            row["packageEvents"].update({"afterimageApplied": 1, "afterimageConsumed": 1})
    if not candidate_gate(protocol, candidate_rows, live_rows)["feasible"]:
        raise AssertionError("candidate-gate positive self-check failed")
    print(core.canonical({"status": "PASS", "protocolSha256": protocol_sha,
                          "runnerSha256": identity["runnerSha256"],
                          "initialCells": 20, "optionalCells": 12,
                          "initialRows": 10752, "maximumRows": 16896}))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate", "execute"))
    args = parser.parse_args()
    if args.command == "validate":
        validate_design()
    else:
        try:
            execute()
        except Exception as error:
            record_inconclusive(error)
            raise


if __name__ == "__main__":
    main()
