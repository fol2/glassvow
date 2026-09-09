#!/usr/bin/env python3
"""Preregistered common-random-number factorial for issue #421."""

from __future__ import annotations

import argparse
import copy
import itertools
import json
import statistics
import subprocess
from pathlib import Path
from typing import Any

import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-factorial-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-factorial-v1.json"
BASE_CONTENT_SHA = "e475482c76a405814dba4638860bb799f610a220fcde5d931c78d1a447e18f48"
LIVE_CONTENT_SHA = "a0d608a5142d2e3aab799cdf33d3163922b402c2aaf2a895e46e096399b56cf1"
SCORE_LEVELS = ("low", "high")
AFTER_LEVELS = ("low", "high")
SETUP_LEVELS = (0, 1, 2)
ACQUISITION_LEVELS = (2, 4)
RARITY_LEVELS = ("uncommon", "rare")
PACKAGE_SPECS = {
    "dusk-scoreline": {
        "aspect": "duskblade", "producer": "chisel", "consumer": "executioner",
        "cardMetric": "shatter", "requiresAspectSeparation": True,
    },
    "dusk-afterimage-guard": {
        "aspect": "duskblade", "producer": "defend", "consumer": "guardedStrike",
        "cardMetric": "status:afterimage", "cardMetricDirection": -1,
        "requiresAspectSeparation": True,
    },
}


def _variant_id(score: str, after: str, rarity: str) -> str:
    return f"score-{score}__after-{after}__rarity-{rarity}"


def _set_payoffs(content: dict[str, Any], score: str, after: str, rarity: str) -> None:
    faultline = content["cards"]["executioner"]
    normal = faultline["effects"][0]
    upgraded = faultline["up"]["effects"][0]
    faultline["rarity"] = rarity
    if score == "high":
        normal["scorelineBonus"], upgraded["scorelineBonus"] = 12, 15
        faultline["text"] = (
            "Deal @8@ damage. Cracked enemies take 6 more. Duskblade: consume Scoreline "
            "to deal @12@ more and complete the enemy's remaining Facets."
        )
        faultline["up"]["text"] = (
            "Deal @11@ damage. Cracked enemies take 8 more. Duskblade: consume Scoreline "
            "to deal @15@ more and complete the enemy's remaining Facets."
        )
    else:
        normal.pop("scorelineBonus", None)
        upgraded.pop("scorelineBonus", None)
        faultline["text"] = (
            "Deal @8@ damage. Cracked enemies take 6 more. Duskblade: consume Scoreline "
            "to complete the enemy's remaining Facets."
        )
        faultline["up"]["text"] = (
            "Deal @11@ damage. Cracked enemies take 8 more. Duskblade: consume Scoreline "
            "to complete the enemy's remaining Facets."
        )
    edge = content["cards"]["guardedStrike"]
    reflection = 2 if after == "low" else 3
    edge["effects"][0]["reflection"] = reflection
    edge["up"]["effects"][0]["reflection"] = reflection
    word = "twice" if reflection == 2 else "three times"
    edge["text"] = (
        f"Deal @5@ damage. Gain #4# Ward. Duskblade: consume Afterimage to deal damage "
        f"equal to {word} your current Ward."
    )
    edge["up"]["text"] = (
        f"Deal @7@ damage. Gain #6# Ward. Duskblade: consume Afterimage to deal damage "
        f"equal to {word} your current Ward."
    )


def prepare_variants() -> dict[str, dict[str, Any]]:
    base_path = core.CACHE / f"{BASE_CONTENT_SHA}.json"
    if core.file_sha(base_path) != BASE_CONTENT_SHA:
        raise RuntimeError("missing or corrupt frozen V38 content")
    base = json.loads(base_path.read_text())
    variants: dict[str, dict[str, Any]] = {}
    for score, after, rarity in itertools.product(
            SCORE_LEVELS, AFTER_LEVELS, RARITY_LEVELS):
        content = copy.deepcopy(base)
        _set_payoffs(content, score, after, rarity)
        digest, path = core.cache_json(content)
        identity = _variant_id(score, after, rarity)
        variants[identity] = {
            "sha256": digest, "path": str(path),
            "scorelinePayoff": score, "afterimagePayoff": after, "rarity": rarity,
        }
    if len({row["sha256"] for row in variants.values()}) != 8:
        raise AssertionError("factorial content variants are not unique")
    return variants


def _source_identity() -> dict[str, Any]:
    return {
        "sourceCommit": subprocess.run(
            ["git", "rev-parse", "HEAD"], cwd=core.SOURCE, check=True,
            text=True, capture_output=True,
        ).stdout.strip(),
        "godotVersion": subprocess.run(
            ["godot", "--version"], check=True, text=True, capture_output=True,
        ).stdout.strip(),
        "combatRulesSha256": core.file_sha(core.SOURCE / "domain/rules/combat.gd"),
        "pilotSha256": core.file_sha(core.SOURCE / "tools/balance_pilot.gd"),
        "probeSha256": core.file_sha(core.SOURCE / "tools/research_421_probe.gd"),
        "balanceSimSha256": core.file_sha(core.SOURCE / "tools/balance_sim.gd"),
        "runnerSha256": core.file_sha(Path(__file__)),
    }


def verify(protocol: dict[str, Any], variants: dict[str, dict[str, Any]]) -> dict[str, Any]:
    actual = _source_identity()
    for key, expected in protocol["immutableInputs"].items():
        if key in actual and actual[key] != expected:
            raise RuntimeError(f"immutable input drift: {key} expected {expected} got {actual[key]}")
    actual_variants = {key: row["sha256"] for key, row in variants.items()}
    if actual_variants != protocol["contentVariants"]:
        raise RuntimeError("factorial content identities drifted")
    return actual


def _local_rows(protocol: dict[str, Any], split: str, package: str, level: str,
                setup: int) -> list[dict[str, Any]]:
    first = int(protocol["seedBases"][f"local{split.title()}"])
    root = int(protocol["seedBases"][f"localPolicyRoot{split.title()}"])
    pairs = int(protocol["budget"]["localPairsPerSplit"])
    spec = PACKAGE_SPECS[package]
    base = ["strike"] * 8 if package == "dusk-afterimage-guard" \
        else ["strike"] * 4 + ["brace"] * 4
    rows: list[dict[str, Any]] = []
    cell = f"{package}:{level}:setup-{setup}"
    for offset, seed in enumerate(range(first, first + pairs)):
        for aspect in ("duskblade", "ashwarden"):
            for arm in core.ARMS:
                producer = spec["producer"] if arm in ("A", "AB") else "brace"
                consumer = spec["consumer"] if arm in ("B", "AB") else "strike"
                rows.append({
                    "id": f"factorial-local-{split}-{cell}-{aspect}-{arm}-{seed}",
                    "stage": "post-v38-factorial-local", "package": package,
                    "edge": package, "arm": arm, "split": split, "context": cell,
                    "aspect": aspect, "seed": seed, "vow": 0,
                    "response": "combatUtility", "mode": "pilot", "maxTurns": 20,
                    "policyRoot": root, "policyIndex": offset,
                    "research421": {"wardSetupPriority": setup, "acquisitionPriority": 2},
                    "deck": [*base, producer, consumer], "enemies": ["gravewarden"],
                    "unlocks": ["aspect2"],
                })
    return rows


def _local_plan(protocol_sha: str, content: str, rows: list[dict[str, Any]]) -> dict[str, Any]:
    return {"schemaVersion": 1, "protocolSha256": protocol_sha,
            "content": content, "rows": rows}


def run_local(db: Any, protocol: dict[str, Any], protocol_sha: str,
              variants: dict[str, dict[str, Any]], split: str) -> dict[str, Any]:
    cells: dict[str, dict[str, Any]] = {}
    for level in SCORE_LEVELS:
        identity = _variant_id(level, "low", "uncommon")
        rows = _local_rows(protocol, split, "dusk-scoreline", level, 0)
        output = core.run_plan(db, protocol_sha, _local_plan(
            protocol_sha, variants[identity]["path"], rows))
        cells[f"dusk-scoreline:{level}:setup-0"] = {
            "package": "dusk-scoreline", "level": level, "setup": 0,
            "rows": output["rows"],
        }
    for level, setup in itertools.product(AFTER_LEVELS, SETUP_LEVELS):
        identity = _variant_id("low", level, "uncommon")
        rows = _local_rows(protocol, split, "dusk-afterimage-guard", level, setup)
        output = core.run_plan(db, protocol_sha, _local_plan(
            protocol_sha, variants[identity]["path"], rows))
        cells[f"dusk-afterimage-guard:{level}:setup-{setup}"] = {
            "package": "dusk-afterimage-guard", "level": level, "setup": setup,
            "rows": output["rows"],
        }
    analysis: dict[str, Any] = {"schemaVersion": 1, "stage": "post-v38-factorial-local",
                                "split": split, "cells": {}}
    for cell, row in cells.items():
        package = row["package"]
        result = core.analyse_finalist_panel(
            row["rows"], split, {"candidate": {"packages": {
                package: PACKAGE_SPECS[package],
            }}})
        analysis["cells"][cell] = result["packages"][package]
    analysis["eligible"] = sorted(
        cell for cell, result in analysis["cells"].items() if result["clear"])
    analysis["decision"] = "continue" if any(
        cell.startswith("dusk-scoreline:") for cell in analysis["eligible"]) and any(
        cell.startswith("dusk-afterimage-guard:") for cell in analysis["eligible"]
    ) else "bounded-negative"
    return analysis


def _cell_id(cell: tuple[str, str, int, int, str]) -> str:
    score, after, setup, acquisition, rarity = cell
    return f"score-{score}__after-{after}__setup-{setup}__acq-{acquisition}__rarity-{rarity}"


def _factor_rows(protocol: dict[str, Any], split: str,
                 cell: tuple[str, str, int, int, str]) -> list[dict[str, Any]]:
    score, after, setup, acquisition, rarity = cell
    cell_name = _cell_id(cell)
    config = {"wardSetupPriority": setup, "acquisitionPriority": acquisition}
    random_first = int(protocol["seedBases"][f"factorRandom{split.title()}"])
    random_count = int(protocol["budget"]["factorRandomSeedsPerSplit"])
    rows = [{
        "id": f"factorial-random-{split}-{cell_name}-{aspect}-v{vow}-{seed}",
        "stage": "post-v38-factorial-random", "context": cell_name,
        "mode": "whole-run", "arm": "2", "aspect": aspect, "vow": vow,
        "seed": seed, "randomBuild": True, "randomPlay": False,
        "research421": config,
    } for aspect in ("duskblade", "ashwarden") for vow in (0, 5)
        for seed in range(random_first, random_first + random_count)]
    root = int(protocol["seedBases"][f"factorPolicyRoot{split.title()}"])
    screen_first = int(protocol["seedBases"][f"factorPolicySeed{split.title()}"])
    policies = int(protocol["budget"]["factorPoliciesPerSplit"])
    seeds = int(protocol["budget"]["factorPolicySeedsPerSplit"])
    rows.extend({
        "id": f"factorial-policy-{split}-{cell_name}-{policy}-{seed}",
        "stage": "post-v38-factorial-policy", "context": cell_name,
        "mode": "whole-run", "arm": "policy", "aspect": "duskblade", "vow": 5,
        "seed": seed, "policyRoot": root, "policyIndex": policy,
        "research421": config,
    } for policy in range(policies) for seed in range(screen_first, screen_first + seeds))
    return rows


def _live_rows(protocol: dict[str, Any], split: str, setup: int,
               acquisition: int) -> list[dict[str, Any]]:
    first = int(protocol["seedBases"][f"factorRandom{split.title()}"])
    count = int(protocol["budget"]["factorRandomSeedsPerSplit"])
    return [{
        "id": f"factorial-live-{split}-setup-{setup}-acq-{acquisition}-{aspect}-v{vow}-{seed}",
        "stage": "post-v38-factorial-live", "mode": "whole-run", "arm": "2",
        "aspect": aspect, "vow": vow, "seed": seed,
        "randomBuild": True, "randomPlay": False,
        "research421": {"wardSetupPriority": setup,
                        "acquisitionPriority": acquisition},
    } for aspect in ("duskblade", "ashwarden") for vow in (0, 5)
        for seed in range(first, first + count)]


def _fault(row: dict[str, Any]) -> bool:
    return row.get("outcome") in ("stall", "error") or bool(str(row.get("error", "")))


def _active(row: dict[str, Any], route: str) -> bool:
    events = row.get("packageEvents") or {}
    if route == "scoreline":
        return int(events.get("scorelineApplied", 0)) > 0 \
            and int(events.get("scorelineConsumed", 0)) > 0
    return int(events.get("afterimageApplied", 0)) > 0 \
        and int(events.get("afterimageConsumed", 0)) > 0


def analyse_factor_cell(candidate: list[dict[str, Any]], live: list[dict[str, Any]],
                        split: str, boot: int, policy_count: int) -> dict[str, Any]:
    candidate_random = [row for row in candidate if row["arm"] == "2"]
    screen = [row for row in candidate if row["arm"] == "policy"]
    c_by = {(row["aspect"], int(row["vow"]), int(row["seed"])): row
            for row in candidate_random}
    l_by = {(row["aspect"], int(row["vow"]), int(row["seed"])): row for row in live}
    if set(c_by) != set(l_by):
        raise ValueError("candidate/live random rectangles differ")
    grids: dict[str, Any] = {}
    random_clear = True
    for offset, (aspect, vow) in enumerate(itertools.product(
            ("duskblade", "ashwarden"), (0, 5))):
        keys = sorted(key for key in c_by if key[:2] == (aspect, vow))
        movement = core.interval([
            int(c_by[key]["outcome"] == "win") - int(l_by[key]["outcome"] == "win")
            for key in keys
        ], 1.0, boot + offset)
        rate = statistics.fmean(c_by[key]["outcome"] == "win" for key in keys)
        added_faults = sum(_fault(c_by[key]) and not _fault(l_by[key]) for key in keys)
        clear = rate < 0.5 and abs(movement["point"]) <= 0.10 and added_faults == 0
        random_clear = random_clear and clear
        grids[f"{aspect}:v{vow}"] = {
            "randomBuildWinRate": rate, "candidateMinusLive": movement,
            "addedFaults": added_faults, "clear": clear,
        }
    active_sets = {
        route: {int(row["policyIndex"]) for row in screen if _active(row, route)}
        for route in ("scoreline", "afterimage")
    }
    exclusive = {
        "scoreline": sorted(active_sets["scoreline"] - active_sets["afterimage"]),
        "afterimage": sorted(active_sets["afterimage"] - active_sets["scoreline"]),
    }
    witnesses = {route: len(values) for route, values in active_sets.items()}
    inactive = {route: policy_count - count for route, count in witnesses.items()}
    screen_faults = sum(_fault(row) for row in screen)
    screen_rate = statistics.fmean(row["outcome"] == "win" for row in screen)
    policy_clear = all(witnesses[route] >= 8 and inactive[route] >= 8
                       for route in witnesses) \
        and all(len(exclusive[route]) >= 2 for route in exclusive) \
        and screen_faults == 0 and screen_rate <= 0.90
    return {
        "randomBuild": {"grids": grids, "clear": random_clear},
        "policyPanel": {"activePolicyWitnesses": witnesses,
                        "inactivePolicyWitnesses": inactive,
                        "exclusivePolicyWitnesses": exclusive,
                        "faults": screen_faults, "vow5WinRate": screen_rate,
                        "clear": policy_clear},
        "clear": random_clear and policy_clear,
    }


def _factor_cells() -> list[tuple[str, str, int, int, str]]:
    return list(itertools.product(
        SCORE_LEVELS, AFTER_LEVELS, SETUP_LEVELS, ACQUISITION_LEVELS, RARITY_LEVELS))


def _endpoint(rows: list[dict[str, Any]], name: str) -> dict[tuple[Any, ...], float]:
    if name.startswith("policy"):
        selected = [row for row in rows if row["arm"] == "policy"]
        key = lambda row: (int(row["policyIndex"]), int(row["seed"]))
        if name == "policyScorelineActivation":
            return {key(row): float(_active(row, "scoreline")) for row in selected}
        if name == "policyAfterimageActivation":
            return {key(row): float(_active(row, "afterimage")) for row in selected}
        return {key(row): float(row["outcome"] == "win") for row in selected}
    selected = [row for row in rows if row["arm"] == "2"]
    values = {(row["aspect"], int(row["vow"]), int(row["seed"])): row
              for row in selected}
    if name == "randomFault":
        return {key: float(_fault(row)) for key, row in values.items()}
    return {key: float(row["outcome"] == "win") for key, row in values.items()}


def factor_effects(raw: dict[tuple[str, str, int, int, str], list[dict[str, Any]]],
                   split: str) -> dict[str, Any]:
    contrasts = (
        ("scorelinePayoff", 0, "low", "high"),
        ("afterimagePayoff", 1, "low", "high"),
        ("wardSetupPriority:0-to-1", 2, 0, 1),
        ("wardSetupPriority:1-to-2", 2, 1, 2),
        ("acquisitionPriority", 3, 2, 4),
        ("faultlineRarity", 4, "uncommon", "rare"),
    )
    endpoints = ("policyScorelineActivation", "policyAfterimageActivation",
                 "policyWin", "randomWin", "randomFault")
    out: dict[str, Any] = {}
    for contrast_index, (name, position, low, high) in enumerate(contrasts):
        pairs = []
        for low_cell in raw:
            if low_cell[position] != low:
                continue
            high_cell = list(low_cell)
            high_cell[position] = high
            high_tuple = tuple(high_cell)
            if high_tuple in raw:
                pairs.append((low_cell, high_tuple))
        effects: dict[str, Any] = {}
        for endpoint_index, endpoint in enumerate(endpoints):
            by_unit: dict[tuple[Any, ...], list[float]] = {}
            for low_cell, high_cell in pairs:
                low_values = _endpoint(raw[low_cell], endpoint)
                high_values = _endpoint(raw[high_cell], endpoint)
                if set(low_values) != set(high_values):
                    raise ValueError(f"unmatched CRN rectangle for {name}/{endpoint}")
                for unit in low_values:
                    by_unit.setdefault(unit, []).append(high_values[unit] - low_values[unit])
            clustered = [statistics.fmean(values) for values in by_unit.values()]
            estimate = core.interval(
                clustered, 1.0,
                43800 + contrast_index * 20 + endpoint_index
                + (0 if split == "discovery" else 200),
            )
            identified = estimate["p025"] > 0 or estimate["p975"] < 0
            effects[endpoint] = {
                "averageMarginalEffect": estimate, "crnUnits": len(clustered),
                "matchedContexts": len(pairs), "identified": identified,
                "direction": ("positive" if estimate["point"] > 0 else
                              ("negative" if estimate["point"] < 0 else "zero")),
            }
        out[name] = effects
    return out


def run_factor(db: Any, protocol: dict[str, Any], protocol_sha: str,
               variants: dict[str, dict[str, Any]], split: str) -> dict[str, Any]:
    live_outputs: dict[tuple[int, int], list[dict[str, Any]]] = {}
    live_path = str(core.CACHE / f"{LIVE_CONTENT_SHA}.json")
    for setup, acquisition in itertools.product(SETUP_LEVELS, ACQUISITION_LEVELS):
        plan = {"schemaVersion": 1, "mode": "whole-run", "protocolSha256": protocol_sha,
                "content": live_path,
                "rows": _live_rows(protocol, split, setup, acquisition)}
        live_outputs[(setup, acquisition)] = core.run_plan(db, protocol_sha, plan)["rows"]
    cells: dict[str, Any] = {}
    raw: dict[tuple[str, str, int, int, str], list[dict[str, Any]]] = {}
    for index, cell in enumerate(_factor_cells()):
        score, after, setup, acquisition, rarity = cell
        variant = variants[_variant_id(score, after, rarity)]
        plan = {"schemaVersion": 1, "mode": "whole-run", "protocolSha256": protocol_sha,
                "content": variant["path"], "rows": _factor_rows(protocol, split, cell)}
        rows = core.run_plan(db, protocol_sha, plan)["rows"]
        raw[cell] = rows
        cells[_cell_id(cell)] = analyse_factor_cell(
            rows, live_outputs[(setup, acquisition)], split, 43100 + index * 10,
            int(protocol["budget"]["factorPoliciesPerSplit"]),
        )
        print(json.dumps({"stage": "factor", "split": split, "cell": index + 1,
                          "of": len(_factor_cells())}), flush=True)
    return {"schemaVersion": 1, "stage": "post-v38-factorial", "split": split,
            "cells": cells, "causalEffects": factor_effects(raw, split),
            "passing": sorted(
                cell for cell, result in cells.items() if result["clear"])}


def _store(db: Any, protocol_sha: str, name: str, value: dict[str, Any]) -> str:
    value["runnerSha256"] = core.file_sha(Path(__file__))
    digest, _ = core.cache_json(value)
    core.record(db, "analysis", f"post-v38-factorial:{name}:{protocol_sha}",
                {**value, "analysisSha256": digest})
    return digest


def execute() -> None:
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    variants = prepare_variants()
    identity = verify(protocol, variants)
    db = core.open_ledger()
    if core.existing_record(db, protocol_sha) is None:
        count = int(db.execute("SELECT COUNT(*) FROM records").fetchone()[0])
        if count != int(protocol["immutableInputs"]["ledgerRecordsAtFreeze"]) \
                or core.file_sha(core.LEDGER) != protocol["immutableInputs"]["ledgerSha256AtFreeze"]:
            raise RuntimeError("ledger changed after protocol freeze and before first execution")
    core.record(db, "protocol", protocol_sha, protocol)
    core.record(db, "source-identity", core.sha(core.canonical(identity).encode()), identity)
    local = {split: run_local(db, protocol, protocol_sha, variants, split)
             for split in ("discovery", "validation")}
    local_shas = {split: _store(db, protocol_sha, f"local:{split}", result)
                  for split, result in local.items()}
    eligible = sorted(set(local["discovery"]["eligible"]) & set(local["validation"]["eligible"]))
    score_levels = {cell.split(":")[1] for cell in eligible
                    if cell.startswith("dusk-scoreline:")}
    after_cells = {(cell.split(":")[1], int(cell.rsplit("-", 1)[1])) for cell in eligible
                   if cell.startswith("dusk-afterimage-guard:")}
    if not score_levels or not after_cells:
        summary = {"schemaVersion": 1, "protocolSha256": protocol_sha,
                   "localAnalysisSha256": local_shas, "eligibleLocalCells": eligible,
                   "decision": "scalar-family-bounded-negative"}
    else:
        factor = {split: run_factor(db, protocol, protocol_sha, variants, split)
                  for split in ("discovery", "validation")}
        factor_shas = {split: _store(db, protocol_sha, f"factor:{split}", result)
                       for split, result in factor.items()}
        joint = []
        for cell in _factor_cells():
            score, after, setup, _acquisition, _rarity = cell
            name = _cell_id(cell)
            if score in score_levels and (after, setup) in after_cells \
                    and name in factor["discovery"]["passing"] \
                    and name in factor["validation"]["passing"]:
                joint.append(cell)
        selected = None if not joint else _cell_id(sorted(joint, key=lambda cell: (
            SCORE_LEVELS.index(cell[0]), AFTER_LEVELS.index(cell[1]), cell[2], cell[3],
            RARITY_LEVELS.index(cell[4]),
        ))[0])
        summary = {"schemaVersion": 1, "protocolSha256": protocol_sha,
                   "localAnalysisSha256": local_shas, "factorAnalysisSha256": factor_shas,
                   "eligibleLocalCells": eligible,
                   "jointPassingCells": [_cell_id(cell) for cell in joint],
                   "selectedMinimum": selected,
                   "decision": "select-for-independent-validation" if selected \
                       else "scalar-family-bounded-negative"}
    summary["runnerSha256"] = core.file_sha(Path(__file__))
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    summary_sha = _store(db, protocol_sha, "summary", summary)
    print(json.dumps({"summary": str(SUMMARY), "summarySha256": summary_sha,
                      "decision": summary["decision"]}, sort_keys=True))


def self_check() -> None:
    variants = prepare_variants()
    assert len(variants) == 8
    low = json.loads(Path(variants[_variant_id("low", "low", "uncommon")]["path"]).read_text())
    high = json.loads(Path(variants[_variant_id("high", "high", "rare")]["path"]).read_text())
    assert "scorelineBonus" not in low["cards"]["executioner"]["effects"][0]
    assert low["cards"]["guardedStrike"]["effects"][0]["reflection"] == 2
    assert high["cards"]["executioner"]["effects"][0]["scorelineBonus"] == 12
    assert high["cards"]["guardedStrike"]["effects"][0]["reflection"] == 3
    assert len(_factor_cells()) == 48
    raw = {}
    for cell in _factor_cells():
        score = cell[0]
        raw[cell] = [{"arm": "policy", "policyIndex": 0, "seed": 1,
                      "outcome": "win", "packageEvents": {
                          "scorelineApplied": int(score == "high"),
                          "scorelineConsumed": int(score == "high"),
                      }},
                     {"arm": "2", "aspect": "duskblade", "vow": 5, "seed": 2,
                      "outcome": "loss", "error": ""}]
    effects = factor_effects(raw, "discovery")
    assert effects["scorelinePayoff"]["policyScorelineActivation"][
        "averageMarginalEffect"]["point"] == 1.0
    print("PASS post_v38_factorial.py self-check")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("prepare", "self-check", "execute"))
    args = parser.parse_args()
    if args.command == "prepare":
        print(json.dumps({key: row["sha256"] for key, row in prepare_variants().items()},
                         indent=2, sort_keys=True))
    elif args.command == "self-check":
        self_check()
    else:
        execute()


if __name__ == "__main__":
    main()
