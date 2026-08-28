#!/usr/bin/env python3
"""Fresh preregistered qualified-runtime Hearth Gate 2 for issue #421."""

from __future__ import annotations

import copy
import json
import random
import sqlite3
import statistics
import subprocess
import sys
import tempfile
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import Any

import research as core


PROTOCOL = core.ROOT / "protocols/post-v30-hearth-qualified-crn-gate2-v1.json"
SUMMARY = core.ROOT / "summaries/post-v30-hearth-qualified-crn-gate2-v1.json"
SOURCE = core.ROOT / "hearth-observation-resolution-source"
GODOT = Path("/Applications/Godot.app/Contents/MacOS/Godot")
PROBE = "res://tools/research_421_hearth_gate2_probe.gd"
CELLS = ("H0Q0", "H1Q0", "H0Q1", "H1Q1")
CONTRASTS = (
    "payoffAtPriorityOff", "payoffAtPriorityOn",
    "priorityAtPayoffOff", "priorityAtPayoffOn", "interaction",
)
METRICS = ("activation", "duration", "quality")


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Hearth Gate 2 mismatch: {label}")


def ledger_identity() -> dict[str, Any]:
    with sqlite3.connect(f"file:{core.LEDGER}?mode=ro", uri=True) as db:
        records, first, last = db.execute(
            "SELECT COUNT(*), MIN(seq), MAX(seq) FROM records"
        ).fetchone()
        protected = db.execute(
            "SELECT COUNT(*) FROM records WHERE kind = 'observation' "
            "AND CAST(json_extract(payload_json, '$.seed') AS INTEGER) "
            "BETWEEN 3000 AND 5399"
        ).fetchone()[0]
        integrity = db.execute("PRAGMA integrity_check").fetchone()[0]
    return {
        "sha256": core.file_sha(core.LEDGER), "records": records,
        "firstSequence": first, "lastSequence": last,
        "protectedSeedRows": protected, "sqliteIntegrity": integrity,
    }


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
        "balancePilotSha256": core.file_sha(SOURCE / "tools/balance_pilot.gd"),
        "balanceSimSha256": core.file_sha(SOURCE / "tools/balance_sim.gd"),
        "policySha256": core.file_sha(SOURCE / "tools/balance_policy.gd"),
        "probeSha256": core.file_sha(
            SOURCE / "tools/research_421_hearth_gate2_probe.gd"),
        "probeUidSha256": core.file_sha(
            SOURCE / "tools/research_421_hearth_gate2_probe.gd.uid"),
        "runnerSha256": core.file_sha(Path(__file__)),
        "gate0Sha256": core.file_sha(
            core.ROOT / "summaries/post-v30-hearth-observation-resolution-gate0-v1.json"),
        "gate1ProtocolSha256": core.file_sha(
            core.ROOT / "protocols/post-v30-hearth-observation-resolution-gate1-v1.json"),
        "gate1SummarySha256": core.file_sha(
            core.ROOT / "summaries/post-v30-hearth-observation-resolution-gate1-v1.json"),
        "taskCapsuleSha256": core.file_sha(core.ROOT / "task-capsule.json"),
    }


def remaining(deadline: float) -> int:
    seconds = int(deadline - time.monotonic())
    if seconds < 1:
        raise TimeoutError("Hearth Gate 2 exceeded its wall-time ceiling")
    return seconds


def run_probe(
    plan: dict[str, Any], deadline: float,
) -> tuple[dict[str, Any], str, str]:
    plan_sha, plan_path = core.cache_json(plan)
    core.WORK.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=core.WORK, prefix="hearth-gate2-") as tmp:
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
    require("plan identity", output.get("planSha256") == plan_sha)
    output_sha, _ = core.cache_json(output)
    return output, plan_sha, output_sha


def run_many(
    plans: dict[str, dict[str, Any]], deadline: float,
) -> dict[str, tuple[dict[str, Any], str, str]]:
    results: dict[str, tuple[dict[str, Any], str, str]] = {}
    with ThreadPoolExecutor(max_workers=len(plans)) as pool:
        futures = {pool.submit(run_probe, plan, deadline): name
                   for name, plan in plans.items()}
        for future in as_completed(futures):
            results[futures[future]] = future.result()
    return results


def control_rows(protocol: dict[str, Any]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for state in protocol["controls"]["payoffStates"]:
        for payoff in (0, 3):
            rows.append({
                **{key: value for key, value in state.items()
                   if key not in ("id", "expected")},
                "id": f"{state['id']}-H{payoff}", "kind": "payoff",
                "payoff": payoff, "expected": state["expected"][str(payoff)],
            })
    for state in protocol["controls"]["priorityStates"]:
        for enabled, suffix in ((False, "off"), (True, "on")):
            rows.append({
                **{key: value for key, value in state.items()
                   if key not in ("id", "expected")},
                "id": f"{state['id']}-{suffix}", "kind": "priority",
                "enabled": enabled, "expected": state["expected"][suffix],
            })
    return rows


def control_plan(protocol: dict[str, Any], protocol_sha: str) -> dict[str, Any]:
    return {
        "schemaVersion": 1, "protocolSha256": protocol_sha,
        "mode": "controls", "content": str(SOURCE / "content/full-content.json"),
        "rows": [
            {key: value for key, value in row.items() if key != "expected"}
            for row in control_rows(protocol)
        ],
    }


def identities(protocol: dict[str, Any], phase: str) -> list[tuple[int, int]]:
    cohort = protocol["cohort"]
    full = [(policy, seed) for policy in cohort["policyIndices"]
            for seed in cohort["simulationSeeds"]]
    sentinel = {(policy, seed) for policy in protocol["sentinel"]["policyIndices"]
                for seed in protocol["sentinel"]["simulationSeeds"]}
    return sorted(sentinel if phase == "sentinel" else set(full) - sentinel)


def whole_plan(
    protocol: dict[str, Any], protocol_sha: str, arm: str, phase: str,
) -> dict[str, Any]:
    cohort = protocol["cohort"]
    plan: dict[str, Any] = {
        "schemaVersion": 1, "protocolSha256": protocol_sha,
        "mode": "whole-runs", "phase": phase, "arm": arm,
        "content": str(SOURCE / "content/full-content.json"),
        "rows": [
            {"policyRoot": cohort["policyRoot"], "policyIndex": policy,
             "seed": seed, "aspect": cohort["aspect"], "vow": cohort["vow"]}
            for policy, seed in identities(protocol, phase)
        ],
    }
    if arm != "omitted":
        plan["settings"] = protocol["designMatrix"][arm]
    return plan


def indexed(rows: list[dict[str, Any]]) -> dict[tuple[int, int], dict[str, Any]]:
    result: dict[tuple[int, int], dict[str, Any]] = {}
    for row in rows:
        key = (int(row["policyIndex"]), int(row["seed"]))
        require(f"unique row identity {key}", key not in result)
        result[key] = row
    return result


def relic_procs(queue: list[dict[str, Any]]) -> list[str]:
    return [str(event.get("id", "")) for event in queue
            if str(event.get("t", "")) == "relicProc"]


def check_controls(output: dict[str, Any], protocol: dict[str, Any]) -> dict[str, Any]:
    rows = output.get("rows")
    require("control row array", isinstance(rows, list))
    specs = {row["id"]: row for row in control_rows(protocol)}
    observed = {row["id"]: row for row in rows}
    require("control identities", set(observed) == set(specs))
    payoff_rows = 0
    priority_rows = 0
    for row_id, spec in specs.items():
        row = observed[row_id]
        expected = spec["expected"]
        require(f"control kind {row_id}", row["kind"] == spec["kind"])
        if spec["kind"] == "priority":
            priority_rows += 1
            require(f"priority selected {row_id}",
                    row["selected"] == expected["selected"])
            require(f"priority RNG before {row_id}",
                    row["rngBefore"] == spec["rngSeed"])
            require(f"priority RNG after {row_id}",
                    row["rngAfter"] == expected["rngAfter"])
            require(f"priority offered {row_id}", row["offered"] == spec["offered"])
            require(f"priority ban {row_id}", row["banned"] == spec["banned"])
            continue
        payoff_rows += 1
        events = row["trace"]["hearthBranchEvents"]
        require(f"payoff one payload {row_id}", len(events) == 1)
        event = events[0]
        require(f"payoff branch {row_id}",
                event["branchExecuted"] is expected["branchExecuted"])
        require(f"payoff proc {row_id}",
                event["procExecuted"] is expected["branchExecuted"])
        for key in ("hpBefore", "requestedHealInput", "actualHeal", "hpAfter",
                    "event", "procQueueEvent"):
            require(f"payoff {key} {row_id}", event[key] == expected[key])
        require(f"payoff queue match {row_id}",
                event["procQueueMatched"] is expected["branchExecuted"])
        require(f"payoff terminal HP {row_id}", row["hp"] == expected["terminalHp"])
        require(f"payoff procs {row_id}",
                relic_procs(row["queue"]) == expected["relicProcIds"])
        require(f"payoff RNG {row_id}", row["rngBefore"] == row["rngAfter"] == 0)
    for pair in (state["id"] for state in protocol["controls"]["priorityStates"]):
        off = copy.deepcopy(observed[f"{pair}-off"])
        on = copy.deepcopy(observed[f"{pair}-on"])
        for value in (off, on):
            value.pop("id")
            value.pop("enabled")
            value.pop("selected")
        require(f"priority intended mediator {pair}", off == on)
    return {
        "rows": len(rows), "payoffRows": payoff_rows,
        "priorityRows": priority_rows, "mismatches": 0,
    }


def check_event(event: dict[str, Any], fight: int, payoff: int) -> None:
    require("event schema", set(event) == {
        "fight", "event", "crownOwned", "embers", "branchExecuted",
        "procExecuted", "procQueueEvent", "procQueueMatched", "hpBefore",
        "requestedHealInput", "actualHeal", "hpAfter", "payloadEmitted",
    })
    require("event fight", event["fight"] == fight)
    require("event queue identity", isinstance(event["event"], int)
            and event["event"] >= 0)
    require("event Crown type", isinstance(event["crownOwned"], bool))
    require("event Ember type", isinstance(event["embers"], int)
            and event["embers"] >= 0)
    branch = event["crownOwned"] and event["embers"] > 0
    require("event branch predicate", event["branchExecuted"] is branch)
    require("event proc", event["procExecuted"] is branch)
    require("event payload", event["payloadEmitted"] is True)
    require("event requested input", event["requestedHealInput"]
            == (event["embers"] * payoff if branch else 0))
    require("event actual heal", isinstance(event["actualHeal"], int)
            and event["actualHeal"] >= 0)
    require("event disabled payoff", payoff != 0 or event["actualHeal"] == 0)
    require("event HP transition", event["hpAfter"] - event["hpBefore"]
            == event["actualHeal"])
    require("event proc queue", event["procQueueMatched"] is branch)
    require("event proc queue identity", event["procQueueEvent"] == event["event"]
            if branch else event["procQueueEvent"] == -1)


def validate_output(
    output: dict[str, Any], protocol: dict[str, Any], arm: str, phase: str,
) -> tuple[dict[tuple[int, int], dict[str, Any]], dict[str, Any]]:
    rows = output.get("rows")
    require(f"{arm} {phase} row array", isinstance(rows, list))
    expected = set(identities(protocol, phase))
    found = indexed(rows)
    require(f"{arm} {phase} identities", set(found) == expected)
    payoff = 3 if arm in ("omitted", "H1Q0", "H1Q1") else 0
    positive = 0
    emitted = 0
    route_rows = {"scoreline": 0, "afterimage": 0}
    for key, row in found.items():
        require(f"{arm} reliability {key}", row.get("outcome") in ("win", "loss")
                and not row.get("error"))
        require(f"{arm} aspect {key}", row["aspect"] == protocol["cohort"]["aspect"])
        require(f"{arm} vow {key}", row["vow"] == protocol["cohort"]["vow"])
        trace = row.get("researchTrace")
        require(f"{arm} trace schema {key}", isinstance(trace, dict) and set(trace) == {
            "captureHearth", "pathCapture", "hearthBranchEvents", "nodePath", "fightPath",
        })
        require(f"{arm} capture flags {key}", trace["captureHearth"] is True
                and trace["pathCapture"] is True)
        require(f"{arm} fight path count {key}",
                len(trace["fightPath"]) == len(row["fights"]))
        wins = [index for index, fight in enumerate(row["fights"])
                if fight["result"] == "win"]
        events = trace["hearthBranchEvents"]
        require(f"{arm} payload count {key}", len(events) == len(wins))
        require(f"{arm} unique payloads {key}",
                len({(event["fight"], event["event"]) for event in events}) == len(events))
        for event, fight in zip(events, wins):
            check_event(event, fight, payoff)
            positive += bool(event["branchExecuted"])
        emitted += len(events)
        for fight_index, fight_path in enumerate(trace["fightPath"]):
            require(f"{arm} fight trace schema {key}/{fight_index}",
                    set(fight_path) == {"fight", "result", "queueSha256", "rngAfter",
                                        "scorelineRoute", "afterimageRoute"})
            require(f"{arm} fight trace identity {key}/{fight_index}",
                    fight_path["fight"] == fight_index
                    and fight_path["result"] == row["fights"][fight_index]["result"])
            require(f"{arm} queue digest {key}/{fight_index}",
                    isinstance(fight_path["queueSha256"], str)
                    and len(fight_path["queueSha256"]) == 64)
            require(f"{arm} route types {key}/{fight_index}",
                    isinstance(fight_path["scorelineRoute"], bool)
                    and isinstance(fight_path["afterimageRoute"], bool))
            route_rows["scoreline"] += bool(fight_path["scorelineRoute"])
            route_rows["afterimage"] += bool(fight_path["afterimageRoute"])
    return found, {
        "rows": len(rows), "payloads": emitted, "positiveBranchEvents": positive,
        "reliabilityFaultRows": 0, "routeFightCounts": route_rows,
    }


def positive_keys(rows: dict[tuple[int, int], dict[str, Any]]) -> set[tuple[int, ...]]:
    return {
        (policy, seed, int(event["fight"]), int(event["event"]), int(event["embers"]))
        for (policy, seed), row in rows.items()
        for event in row["researchTrace"]["hearthBranchEvents"]
        if event["branchExecuted"]
    }


def check_sentinel(
    protocol: dict[str, Any], outputs: dict[str, dict[str, Any]],
) -> tuple[dict[str, dict[tuple[int, int], dict[str, Any]]], dict[str, Any]]:
    indexed_cells: dict[str, dict[tuple[int, int], dict[str, Any]]] = {}
    validations: dict[str, Any] = {}
    omitted, validations["omitted"] = validate_output(
        outputs["omitted"], protocol, "omitted", "sentinel")
    for cell in CELLS:
        indexed_cells[cell], validations[cell] = validate_output(
            outputs[cell], protocol, cell, "sentinel")
    require("omitted explicit-current identity", omitted == indexed_cells["H1Q0"])
    identities_set = set(indexed_cells["H1Q0"])
    for key in identities_set:
        policies = [indexed_cells[cell][key]["policy"] for cell in CELLS]
        require(f"sentinel policy identity {key}", all(value == policies[0]
                                                         for value in policies[1:]))
    h1 = positive_keys(indexed_cells["H1Q1"])
    h0 = positive_keys(indexed_cells["H0Q1"])
    require("sentinel enabled branch support", bool(h1))
    require("sentinel disabled branch support", bool(h0))
    require("sentinel shared disabled proc witness", bool(h1 & h0))
    return indexed_cells, {
        "decision": "green", "validations": validations,
        "nullIdentityRows": len(omitted), "nullMismatchRows": 0,
        "policyMismatchRows": 0,
        "sharedDisabledProcWitnesses": len(h1 & h0),
        "causalEndpointsInspected": 0,
    }


def combine(
    first: dict[tuple[int, int], dict[str, Any]],
    second: dict[tuple[int, int], dict[str, Any]],
) -> dict[tuple[int, int], dict[str, Any]]:
    require("sentinel/remainder disjoint", not set(first) & set(second))
    return {**first, **second}


def metric(row: dict[str, Any], name: str) -> float:
    if name == "activation":
        return float(sum(event["branchExecuted"]
                         for event in row["researchTrace"]["hearthBranchEvents"]))
    if name == "duration":
        fights = row["fights"]
        return (sum(float(fight["turns"]) for fight in fights) / len(fights)
                if fights else 0.0)
    if name == "quality":
        return (1.0 + float(row["hp"]) / max(1.0, float(row["maxHp"]))
                if row["outcome"] == "win" else 0.0)
    raise ValueError(f"unknown metric {name}")


def policy_means(
    cells: dict[str, dict[tuple[int, int], dict[str, Any]]], name: str,
) -> dict[str, dict[int, float]]:
    result: dict[str, dict[int, float]] = {}
    for cell, rows in cells.items():
        by_policy: dict[int, list[float]] = {}
        for (policy, _seed), row in rows.items():
            by_policy.setdefault(policy, []).append(metric(row, name))
        result[cell] = {policy: statistics.fmean(values)
                        for policy, values in by_policy.items()}
    return result


def contrast_values(
    means: dict[str, dict[int, float]], policies: list[int],
) -> dict[str, list[float]]:
    return {
        "payoffAtPriorityOff": [means["H1Q0"][p] - means["H0Q0"][p]
                                for p in policies],
        "payoffAtPriorityOn": [means["H1Q1"][p] - means["H0Q1"][p]
                               for p in policies],
        "priorityAtPayoffOff": [means["H0Q1"][p] - means["H0Q0"][p]
                                for p in policies],
        "priorityAtPayoffOn": [means["H1Q1"][p] - means["H1Q0"][p]
                               for p in policies],
        "interaction": [
            (means["H1Q1"][p] - means["H0Q1"][p])
            - (means["H1Q0"][p] - means["H0Q0"][p]) for p in policies
        ],
    }


def interval(values: list[float], resamples: int, seed: int) -> dict[str, float | int]:
    require("non-empty interval", bool(values))
    rng = random.Random(seed)
    boot = [statistics.fmean(rng.choice(values) for _ in values)
            for _ in range(resamples)]
    return {
        "policies": len(values), "point": statistics.fmean(values),
        "p025": core.percentile(boot, 0.025),
        "p975": core.percentile(boot, 0.975),
    }


def estimates(
    cells: dict[str, dict[tuple[int, int], dict[str, Any]]],
    protocol: dict[str, Any], selected: list[int] | None = None,
    seed_offset: int = 0,
) -> tuple[dict[str, Any], dict[str, dict[int, float]]]:
    policies = selected or protocol["cohort"]["policyIndices"]
    result: dict[str, Any] = {}
    quality_means: dict[str, dict[int, float]] = {}
    for metric_index, name in enumerate(METRICS):
        means = policy_means(cells, name)
        if name == "quality":
            quality_means = means
        values = contrast_values(means, policies)
        result[name] = {
            contrast: interval(
                values[contrast], protocol["estimator"]["bootstrapResamples"],
                protocol["estimator"]["bootstrapSeedBase"] + seed_offset
                + metric_index * 10 + contrast_index,
            )
            for contrast_index, contrast in enumerate(CONTRASTS)
        }
    return result, quality_means


def robust_route(
    rows: dict[tuple[int, int], dict[str, Any]], route: str,
    minimum_seeds: int,
) -> set[int]:
    hits: dict[int, int] = {}
    key = f"{route}Route"
    for (policy, _seed), row in rows.items():
        if any(fight[key] for fight in row["researchTrace"]["fightPath"]):
            hits[policy] = hits.get(policy, 0) + 1
    return {policy for policy, count in hits.items() if count >= minimum_seeds}


def separation(candidate: set[int], anchor: set[int]) -> dict[str, Any]:
    union = candidate | anchor
    return {
        "candidateOnly": len(candidate - anchor), "anchorOnly": len(anchor - candidate),
        "crossActive": len(candidate & anchor),
        "jaccard": len(candidate & anchor) / len(union) if union else 1.0,
    }


def effect_boundary(est: dict[str, Any], gates: dict[str, Any]) -> str:
    quality = est["quality"]
    if (quality["payoffAtPriorityOn"]["p025"] > gates["minimumPayoffLowerBound"]
            and quality["interaction"]["p025"] > gates["minimumInteractionLowerBound"]
            and quality["priorityAtPayoffOn"]["p025"]
            >= -gates["priorityQualityNonInferiorityMargin"]):
        return "success"
    if (quality["payoffAtPriorityOn"]["p975"] <= 0.0
            or quality["interaction"]["p975"] <= 0.0
            or quality["priorityAtPayoffOn"]["p975"]
            < -gates["priorityQualityNonInferiorityMargin"]):
        return "futility"
    return "inconclusive"


def analyse(
    cells: dict[str, dict[tuple[int, int], dict[str, Any]]],
    protocol: dict[str, Any],
) -> dict[str, Any]:
    gates = protocol["decisionRules"]["gates"]
    all_estimates, quality_means = estimates(cells, protocol)
    policies = protocol["cohort"]["policyIndices"]
    seeds = protocol["cohort"]["simulationSeeds"]
    robust = gates["robustMinimumSeeds"]
    branch_hits = {
        policy: sum(metric(cells["H1Q1"][(policy, seed)], "activation") > 0
                    for seed in seeds) for policy in policies
    }
    active = {policy for policy, count in branch_hits.items() if count >= robust}
    inactive = {policy for policy, count in branch_hits.items() if count == 0}
    viable = {
        policy for policy in active
        if sum(cells["H1Q1"][(policy, seed)]["outcome"] == "win" for seed in seeds)
        >= gates["viableMinimumWinningSeeds"]
    }
    quality_values = contrast_values(quality_means, policies)
    activation_means = policy_means(cells, "activation")
    activation_values = contrast_values(activation_means, policies)
    support = {
        "activePolicies": len(active), "inactivePolicies": len(inactive),
        "viableActivePolicies": len(viable),
        "positivePayoffPolicies": sum(value > 0 for value in quality_values["payoffAtPriorityOn"]),
        "exactZeroPayoffPolicies": sum(value == 0 for value in quality_values["payoffAtPriorityOn"]),
        "priorityActivationGainPolicies": sum(
            value > 0 for value in activation_values["priorityAtPayoffOff"]),
        "sets": {"active": sorted(active), "inactive": sorted(inactive),
                 "viable": sorted(viable)},
    }
    anchors: dict[str, Any] = {}
    changed: set[int] = set()
    separations: dict[str, Any] = {}
    for route in ("scoreline", "afterimage"):
        q0 = robust_route(cells["H1Q0"], route, robust)
        q1 = robust_route(cells["H1Q1"], route, robust)
        changed |= q0 ^ q1
        union = q0 | q1
        anchors[route] = {
            "priorityOff": sorted(q0), "priorityOn": sorted(q1),
            "changedPolicies": sorted(q0 ^ q1),
            "jaccard": len(q0 & q1) / len(union) if union else 1.0,
        }
        separations[route] = separation(active, q1)
    stable = sorted(set(policies) - changed)
    stable_estimates: dict[str, Any] = {}
    stable_boundary = "insufficient-stable-support"
    if len(stable) >= gates["minimumStableInterferencePolicies"]:
        stable_estimates, _ = estimates(cells, protocol, stable, 100)
        stable_boundary = effect_boundary(stable_estimates, gates)
    full_boundary = effect_boundary(all_estimates, gates)
    interference_decision_value = (
        len(stable) < gates["minimumStableInterferencePolicies"]
        or stable_boundary != full_boundary
    )
    support_clear = (
        support["activePolicies"] >= gates["minimumActivePolicies"]
        and support["inactivePolicies"] >= gates["minimumInactivePolicies"]
        and support["viableActivePolicies"] >= gates["minimumViableActivePolicies"]
        and support["positivePayoffPolicies"] >= gates["minimumPositivePayoffPolicies"]
        and support["exactZeroPayoffPolicies"] >= gates["minimumExactZeroPayoffPolicies"]
        and support["priorityActivationGainPolicies"]
        >= gates["minimumPriorityActivationGainPolicies"]
    )
    separation_clear = all(
        result["candidateOnly"] >= gates["minimumCandidateOnlyPolicies"]
        and result["anchorOnly"] >= gates["minimumAnchorOnlyPolicies"]
        and result["jaccard"] <= gates["maximumAnchorJaccard"]
        for result in separations.values()
    )
    win_rates = {
        cell: sum(row["outcome"] == "win" for row in rows.values()) / len(rows)
        for cell, rows in cells.items()
    }
    vow_ceiling_clear = max(win_rates.values()) <= gates["maximumVow5WinRate"]
    duration = all_estimates["duration"]["priorityAtPayoffOn"]
    duration_clear = duration["p975"] <= gates["maximumTurnsPerFightIncrease"]
    duration_futile = duration["p025"] > gates["maximumTurnsPerFightIncrease"]
    success = (support_clear and separation_clear and vow_ceiling_clear
               and duration_clear and full_boundary == "success"
               and not interference_decision_value)
    futile = (not support_clear or not separation_clear or not vow_ceiling_clear
              or duration_futile or full_boundary == "futility")
    if interference_decision_value:
        boundary = 3
        decision = "quarantine-hearth-inconclusive-cross-package-interference"
    elif success:
        boundary = 1
        decision = "freeze-one-hearth-candidate-for-independent-heldout-confirmation"
    elif futile:
        boundary = 2
        decision = "close-hearth-scalar-family-and-continue-next-structural-mechanism"
    else:
        boundary = 3
        decision = "quarantine-hearth-inconclusive-at-preregistered-cap"
    return {
        "decisionBoundary": boundary, "decision": decision,
        "estimands": all_estimates, "support": support,
        "separateFixedInterferenceStrata": {
            "anchors": anchors, "separation": separations,
            "stablePolicies": stable, "stableEstimands": stable_estimates,
            "fullEffectBoundary": full_boundary,
            "stableEffectBoundary": stable_boundary,
            "measuredDecisionValue": interference_decision_value,
            "additionalJointCellsExecuted": 0,
        },
        "guardrails": {
            "supportClear": support_clear, "separationClear": separation_clear,
            "Vow5WinRates": win_rates, "Vow5CeilingClear": vow_ceiling_clear,
            "durationClear": duration_clear, "durationDecisivelyFutile": duration_futile,
            "reliabilityFaultRows": 0,
        },
        "candidate": protocol["candidate"] if boundary == 1 else None,
    }


def manifest_entry(result: tuple[dict[str, Any], str, str]) -> dict[str, str]:
    return {"planSha256": result[1], "outputSha256": result[2]}


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite Hearth Gate 2 summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    source = source_identity()
    for key, expected in protocol["immutableInputs"].items():
        require(f"immutable {key}", source.get(key) == expected)
    ledger_before = ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
    started = time.monotonic()
    deadline = started + float(protocol["budget"]["maximumWallTimeSeconds"])
    manifests: dict[str, Any] = {}
    controls: dict[str, Any] = {}
    sentinel: dict[str, Any] = {}
    analysis: dict[str, Any] = {}
    observed_rows = 0
    processes = 0
    stage = "controls"
    failure = ""
    decision = "quarantine-hearth-gate2-control-identity-failure"
    boundary = 3
    causal_endpoints = 0
    try:
        control_result = run_probe(control_plan(protocol, protocol_sha), deadline)
        processes += 1
        manifests["controls"] = manifest_entry(control_result)
        controls = check_controls(control_result[0], protocol)

        stage = "sentinel"
        sentinel_plans = {
            arm: whole_plan(protocol, protocol_sha, arm, "sentinel")
            for arm in ("omitted", *CELLS)
        }
        sentinel_results = run_many(sentinel_plans, deadline)
        processes += len(sentinel_results)
        for arm, result in sentinel_results.items():
            manifests[f"sentinel-{arm}"] = manifest_entry(result)
            observed_rows += len(result[0]["rows"])
        sentinel_cells, sentinel = check_sentinel(
            protocol, {arm: result[0] for arm, result in sentinel_results.items()})
        require("sentinel observation rows",
                observed_rows == protocol["budget"]["sentinelWholeRunObservationRows"])

        stage = "full-rectangle"
        remainder_plans = {
            cell: whole_plan(protocol, protocol_sha, cell, "remainder") for cell in CELLS
        }
        remainder_results = run_many(remainder_plans, deadline)
        processes += len(remainder_results)
        full_cells: dict[str, dict[tuple[int, int], dict[str, Any]]] = {}
        full_validation: dict[str, Any] = {}
        for cell, result in remainder_results.items():
            manifests[f"remainder-{cell}"] = manifest_entry(result)
            observed_rows += len(result[0]["rows"])
            remainder_rows, full_validation[cell] = validate_output(
                result[0], protocol, cell, "remainder")
            full_cells[cell] = combine(sentinel_cells[cell], remainder_rows)
            require(f"full cell row count {cell}",
                    len(full_cells[cell]) == protocol["budget"]["rowsPerCell"])
        sentinel["fullValidation"] = full_validation
        causal_endpoints = protocol["budget"]["causalWholeRunRows"]
        analysis = analyse(full_cells, protocol)
        boundary = int(analysis["decisionBoundary"])
        decision = str(analysis["decision"])
    except (KeyError, RuntimeError, subprocess.TimeoutExpired, TimeoutError,
            TypeError, ValueError) as error:
        failure = str(error)
        if stage == "sentinel":
            decision = "quarantine-hearth-gate2-sentinel-failure"
        elif stage == "full-rectangle":
            decision = "quarantine-hearth-gate2-second-observation-ambiguity"

    elapsed = time.monotonic() - started
    ledger_after = ledger_identity()
    if elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        failure = failure or "wall-time ceiling"
        boundary = 3
        decision = "quarantine-hearth-inconclusive-at-preregistered-cap"
    if observed_rows > protocol["budget"]["maximumWholeRunObservationRows"]:
        failure = failure or "row ceiling"
    if processes > protocol["budget"]["maximumGodotProcesses"]:
        failure = failure or "Godot process ceiling"
    if ledger_after != ledger_before:
        failure = failure or "ledger identity drift"
    summary = {
        "schemaVersion": 1, "issue": 421,
        "decisionBoundary": boundary, "decision": decision, "failure": failure,
        "protocolSha256": protocol_sha, "sourceIdentity": source,
        "controlledKnobIdentity": controls, "sentinel": sentinel,
        "analysis": analysis,
        "execution": {
            "manifests": manifests, "wholeRunObservationRows": observed_rows,
            "causalWholeRunRows": causal_endpoints,
            "controlledExecutions": controls.get("rows", 0),
            "GodotProcesses": processes,
            "newLedgerRows": ledger_after["records"] - ledger_before["records"],
            "protectedSeedRows": ledger_after["protectedSeedRows"],
            "causalEndpointsInspected": causal_endpoints,
            "bootstrapEstimands": (
                len(METRICS) * len(CONTRASTS) if analysis else 0),
            "maximumModelContextTokens": 0, "wallTimeSeconds": elapsed,
        },
        "ledgerBefore": ledger_before, "ledgerAfter": ledger_after,
        "authority": protocol["decisionRules"]["authorities"][str(boundary)],
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": "FAIL" if failure else "PASS", "decision": decision,
        "summarySha256": core.file_sha(SUMMARY),
    }))
    if failure:
        sys.exit(2)


if __name__ == "__main__":
    main()
