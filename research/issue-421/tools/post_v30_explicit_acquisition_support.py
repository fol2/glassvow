#!/usr/bin/env python3
"""Fixed-cohort run-level support screen for explicit Dusk acquisition."""

from __future__ import annotations

import json
import statistics
import subprocess
import tempfile
import time
from pathlib import Path
from typing import Any, Callable

import post_v30_explicit_acquisition_identity as identity_engine
import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v30-explicit-acquisition-support-v1.json"
SUMMARY = core.ROOT / "summaries/post-v30-explicit-acquisition-support-v1.json"
SOURCE = core.ROOT / "dusk-explicit-acquisition-support-v1-source"
IDENTITY_SOURCE = core.ROOT / "dusk-explicit-acquisition-identity-v2-source"
BASELINE_PLAN_SHA = "d33926aec9e22a14f1709120a261c52571e9a94b78c98d90d2a19b9d136c61d3"
BASELINE_OUTPUT_SHA = "1be7272596391fd1f7b296af480bc366ae8b6a2af50c71c3dc508fc6ae3b458f"
PROBE = "res://tools/research_421_explicit_dusk_acquisition_support_probe.gd"
GODOT = Path("/Applications/Godot.app/Contents/MacOS/Godot")
DRIVERS = (
    "tools/balance_sim.gd", "tools/balance_sweep.gd", "tools/balance_cem.gd",
    "tools/balance_pilot.gd", "tools/balance_policy.gd", "tools/balance_catalogue.gd",
)


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Explicit acquisition support mismatch: {label}")


def remaining(deadline: float) -> int:
    seconds = int(deadline - time.monotonic())
    if seconds < 1:
        raise TimeoutError("explicit acquisition support exceeded wall-time ceiling")
    return seconds


def git(*args: str) -> str:
    return subprocess.run(
        ["git", *args], cwd=SOURCE, check=True, text=True, capture_output=True,
    ).stdout.strip()


def cache(digest: str) -> dict[str, Any]:
    path = core.CACHE / f"{digest}.json"
    require(f"cache {digest}", path.is_file() and core.file_sha(path) == digest)
    value = json.loads(path.read_text())
    require(f"cache {digest} type", isinstance(value, dict))
    return value


def driver_sha() -> str:
    text = "".join(f"{path}\n{(SOURCE / path).read_text()}" for path in DRIVERS)
    return core.sha(text.encode())


def specs(
    protocol: dict[str, Any], first: int, count: int, acquisition: str,
) -> list[dict[str, Any]]:
    cohort = protocol["cohort"]
    return [
        {
            "aspect": cohort["aspect"],
            "vow": cohort["vow"],
            "seed": seed,
            "policyRoot": cohort["policyRoot"],
            "policyIndex": policy_index,
            "acquisition": acquisition,
        }
        for policy_index in range(first, first + count)
        for seed in cohort["simulationSeeds"]
    ]


def cache_rows(
    protocol: dict[str, Any], protocol_sha: str,
) -> tuple[dict[tuple[int, int], dict[str, Any]], dict[str, Any], dict[str, Any]]:
    plan = cache(BASELINE_PLAN_SHA)
    output = cache(BASELINE_OUTPUT_SHA)
    expected = identity_engine.whole_specs(protocol, 0, protocol["cohort"]["policyCount"])
    require("baseline plan", plan["rows"] == expected)
    require("baseline output plan", output["planSha256"] == BASELINE_PLAN_SHA)
    require("baseline provenance", output["contentIdentity"] ==
            protocol["outputProvenance"]["baselineContentIdentity"])
    fields = set(protocol["comparisonContract"]["canonicalRowFields"])
    require("baseline schema", len(output["rows"]) == protocol["cohort"]["rows"]
            and all(set(row) == fields for row in output["rows"]))
    rows = {
        (int(spec["policyIndex"]), int(spec["seed"])): row
        for spec, row in zip(plan["rows"], output["rows"])
    }
    require("baseline identities", len(rows) == protocol["cohort"]["rows"])
    sentinel_count = protocol["staging"]["sentinelPolicyCount"]
    plans = {
        "sentinel": {
            "schemaVersion": 1,
            "protocolSha256": protocol_sha,
            "content": protocol["contentPath"],
            "rows": specs(protocol, 0, sentinel_count, "executioner")
            + specs(protocol, 0, sentinel_count, "guardedStrike"),
        },
        "remainder": {
            "schemaVersion": 1,
            "protocolSha256": protocol_sha,
            "content": protocol["contentPath"],
            "rows": specs(
                protocol, sentinel_count,
                protocol["cohort"]["policyCount"] - sentinel_count, "executioner",
            ) + specs(
                protocol, sentinel_count,
                protocol["cohort"]["policyCount"] - sentinel_count, "guardedStrike",
            ),
        },
    }
    require("sentinel cardinality", len(plans["sentinel"]["rows"]) ==
            protocol["staging"]["expectedRows"]["sentinel"])
    require("remainder cardinality", len(plans["remainder"]["rows"]) ==
            protocol["staging"]["expectedRows"]["remainder"])
    return rows, output, plans


def robust(
    rows: dict[tuple[int, int], dict[str, Any]], protocol: dict[str, Any],
    predicate: Callable[[dict[str, Any]], bool],
) -> set[int]:
    cohort = protocol["cohort"]
    return {
        policy for policy in range(cohort["policyCount"])
        if sum(predicate(rows[(policy, seed)]) for seed in cohort["simulationSeeds"])
        >= cohort["minimumRowsPerRobustPolicy"]
    }


def inactive(
    rows: dict[tuple[int, int], dict[str, Any]], protocol: dict[str, Any],
    predicate: Callable[[dict[str, Any]], bool],
) -> set[int]:
    return {
        policy for policy in range(protocol["cohort"]["policyCount"])
        if not any(predicate(rows[(policy, seed)])
                   for seed in protocol["cohort"]["simulationSeeds"])
    }


def expressed(row: dict[str, Any], producer: str, consumer: str) -> bool:
    events = row["packageEvents"]
    return int(events.get(f"{producer}Played", 0)) > 0 \
        and int(events.get(f"{consumer}Played", 0)) > 0


def drawn(row: dict[str, Any], consumer: str) -> bool:
    return int(row["packageEvents"].get(f"{consumer}Drawn", 0)) > 0


def fault(row: dict[str, Any]) -> bool:
    return row.get("outcome") in ("stall", "error") or bool(str(row.get("error", "")))


def duration(row: dict[str, Any]) -> float:
    fights = row["fights"]
    require("non-empty fights", bool(fights))
    return statistics.fmean(float(fight["turns"]) for fight in fights)


def support(
    rows: dict[tuple[int, int], dict[str, Any]], protocol: dict[str, Any],
    producer: str, consumer: str,
) -> dict[str, Any]:
    active = robust(rows, protocol, lambda row: expressed(row, producer, consumer))
    exact_inactive = inactive(
        rows, protocol, lambda row: expressed(row, producer, consumer),
    )
    robust_drawn = robust(rows, protocol, lambda row: drawn(row, consumer))
    viable = {
        policy for policy in active
        if any(expressed(rows[(policy, seed)], producer, consumer)
               and rows[(policy, seed)]["outcome"] == "win"
               for seed in protocol["cohort"]["simulationSeeds"])
    }
    return {
        "active": active,
        "inactive": exact_inactive,
        "drawn": robust_drawn,
        "viable": viable,
        "counts": {
            "robustCoPlayPolicies": len(active),
            "exactInactivePolicies": len(exact_inactive),
            "ambiguousPolicies": protocol["cohort"]["policyCount"]
            - len(active) - len(exact_inactive),
            "robustConsumerDrawPolicies": len(robust_drawn),
            "viableCoPlayPolicies": len(viable),
        },
    }


def separation(left: set[int], right: set[int]) -> dict[str, Any]:
    union = left | right
    return {
        "scorelineOnlyPolicies": len(left - right),
        "afterimageOnlyPolicies": len(right - left),
        "crossActivePolicies": len(left & right),
        "jaccard": len(left & right) / len(union) if union else 1.0,
    }


def paired_interval(
    baseline: dict[tuple[int, int], dict[str, Any]],
    candidate: dict[tuple[int, int], dict[str, Any]],
    protocol: dict[str, Any], metric: Callable[[dict[str, Any]], float], seed: int,
) -> dict[str, Any]:
    values = [
        statistics.fmean(
            metric(candidate[(policy, sim_seed)]) - metric(baseline[(policy, sim_seed)])
            for sim_seed in protocol["cohort"]["simulationSeeds"]
        )
        for policy in range(protocol["cohort"]["policyCount"])
    ]
    return core.interval(values, 1.0, seed)


def verify_output(
    label: str, output: dict[str, Any], plan_sha: str, rows: int,
    protocol: dict[str, Any],
) -> None:
    require(f"{label} keys", set(output) == {
        "schemaVersion", "planSha256", "probeSha256", "contentIdentity", "rows",
    })
    require(f"{label} plan", output["planSha256"] == plan_sha)
    require(f"{label} probe", output["probeSha256"] ==
            protocol["outputProvenance"]["supportProbeSha256"])
    require(f"{label} provenance", output["contentIdentity"] ==
            protocol["outputProvenance"]["supportContentIdentity"])
    fields = set(protocol["comparisonContract"]["canonicalRowFields"])
    require(f"{label} schema", len(output["rows"]) == rows
            and all(set(row) == fields for row in output["rows"]))
    require(f"{label} nested schema", all(
        isinstance(row["packageEvents"], dict)
        and isinstance(row["policy"], dict)
        and isinstance(row["fights"], list) and row["fights"]
        and all(isinstance(fight, dict) and "turns" in fight for fight in row["fights"])
        for row in output["rows"]
    ))


def run(plan: dict[str, Any], deadline: float) -> tuple[dict[str, Any], str, str]:
    plan_sha, plan_path = core.cache_json(plan)
    core.WORK.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=core.WORK, prefix="explicit-support-") as tmp:
        output_path = Path(tmp) / "output.json"
        result = subprocess.run(
            [str(GODOT), "--headless", "-s", PROBE, "--",
             f"--plan={plan_path}", f"--out={output_path}"],
            cwd=SOURCE, text=True, capture_output=True, timeout=remaining(deadline),
        )
        if result.returncode or not output_path.is_file():
            raise OSError(
                f"support probe failed ({result.returncode})\n"
                f"{result.stdout[-2000:]}\n{result.stderr[-4000:]}"
            )
        output = json.loads(output_path.read_text())
    output_sha, _ = core.cache_json(output)
    return output, plan_sha, output_sha


def preflight(
    protocol: dict[str, Any], protocol_sha: str,
) -> tuple[dict[tuple[int, int], dict[str, Any]], dict[str, Any]]:
    immutable = protocol["immutableInputs"]
    require("runner identity", core.file_sha(Path(__file__)) == immutable["runnerSha256"])
    require("source commit", git("rev-parse", "HEAD") == immutable["sourceCommit"])
    status = subprocess.run(
        ["git", "status", "--porcelain"], cwd=SOURCE, check=True,
        text=True, capture_output=True,
    ).stdout.splitlines()
    require("source status", status == immutable["sourceStatus"])
    require("tracked diff", core.sha(subprocess.run(
        ["git", "diff", "--no-ext-diff"], cwd=SOURCE, check=True,
        capture_output=True,
    ).stdout) == immutable["trackedDiffSha256"])
    require("Godot version", subprocess.run(
        [str(GODOT), "--version"], check=True, text=True, capture_output=True,
    ).stdout.strip() == immutable["godotVersion"])
    require("Godot binary", core.file_sha(GODOT) == immutable["godotBinarySha256"])
    require("task capsule", core.file_sha(core.ROOT / "task-capsule.json") ==
            immutable["taskCapsuleSha256"])
    for relative, expected in immutable["sourceSha256"].items():
        require(f"source {relative}", core.file_sha(SOURCE / relative) == expected)
    for relative, expected in immutable["evidenceSha256"].items():
        require(f"evidence {relative}", core.file_sha(core.ROOT / relative) == expected)
    require("driver identity", driver_sha() == immutable["driverSha256"])
    for relative in protocol["sourceEquivalence"]["identitySourcePaths"]:
        require(f"identity-source equivalence {relative}",
                (SOURCE / relative).read_bytes() == (IDENTITY_SOURCE / relative).read_bytes())
    probe = (SOURCE / protocol["probeContract"]["path"]).read_text()
    for anchor in protocol["probeContract"]["cardinalityAnchors"]:
        require(f"probe cardinality {anchor}", probe.count(anchor) == 1)
    for anchor in protocol["probeContract"]["equalityAnchors"]:
        require(f"probe equality {anchor}", anchor in probe)
    baseline, _, plans = cache_rows(protocol, protocol_sha)
    anchors = {
        name: support(baseline, protocol, spec["producer"], spec["consumer"])["active"]
        for name, spec in protocol["packages"].items()
    }
    require("baseline Scoreline anchor", sorted(anchors["scoreline"]) ==
            protocol["baselineAnchors"]["scorelinePolicies"])
    require("baseline Afterimage anchor", sorted(anchors["afterimage"]) ==
            protocol["baselineAnchors"]["afterimagePolicies"])
    return baseline, plans


def map_rows(
    specs_: list[dict[str, Any]], rows: list[dict[str, Any]],
    baseline: dict[tuple[int, int], dict[str, Any]],
) -> dict[str, dict[tuple[int, int], dict[str, Any]]]:
    out = {"executioner": {}, "guardedStrike": {}}
    for spec, row in zip(specs_, rows):
        key = (int(spec["policyIndex"]), int(spec["seed"]))
        acquisition = str(spec["acquisition"])
        require(f"unique {acquisition} {key}", key not in out[acquisition])
        require(f"identity {acquisition} {key}",
                row["aspect"] == spec["aspect"] and row["seed"] == spec["seed"]
                and row["vow"] == spec["vow"])
        require(f"policy {acquisition} {key}", row["policy"] == baseline[key]["policy"])
        out[acquisition][key] = row
    return out


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite explicit acquisition support")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    deadline = started + float(protocol["budget"]["maximumWallTimeSeconds"])
    ledger_before: dict[str, Any] = {}
    ledger_after: dict[str, Any] = {}
    execution_error = ""
    unavailable = False
    hard_sentinel_fault = False
    new_rows = 0
    godot_processes = 0
    cache_objects: dict[str, str] = {}
    analysis: dict[str, Any] = {}
    baseline: dict[tuple[int, int], dict[str, Any]] = {}
    plans: dict[str, Any] = {}
    observed: dict[str, dict[tuple[int, int], dict[str, Any]]] = {
        "executioner": {}, "guardedStrike": {},
    }
    try:
        ledger_before = identity.ledger_identity()
        require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
        baseline, plans = preflight(protocol, protocol_sha)
    except (FileNotFoundError, json.JSONDecodeError, KeyError, TypeError,
            ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        execution_error, unavailable = str(error), True

    if not execution_error:
        try:
            sentinel_output, plan_sha, output_sha = run(plans["sentinel"], deadline)
            godot_processes += 1
            verify_output(
                "sentinel", sentinel_output, plan_sha,
                protocol["staging"]["expectedRows"]["sentinel"], protocol,
            )
            cache_objects.update({
                "sentinelPlanSha256": plan_sha,
                "sentinelOutputSha256": output_sha,
            })
            new_rows += len(sentinel_output["rows"])
            observed = map_rows(
                plans["sentinel"]["rows"], sentinel_output["rows"], baseline,
            )
            hard_sentinel_fault = any(
                fault(row) for arm in observed.values() for row in arm.values()
            )
            if not hard_sentinel_fault:
                remainder_output, plan_sha, output_sha = run(
                    plans["remainder"], deadline,
                )
                godot_processes += 1
                verify_output(
                    "remainder", remainder_output, plan_sha,
                    protocol["staging"]["expectedRows"]["remainder"], protocol,
                )
                cache_objects.update({
                    "remainderPlanSha256": plan_sha,
                    "remainderOutputSha256": output_sha,
                })
                new_rows += len(remainder_output["rows"])
                rest = map_rows(
                    plans["remainder"]["rows"], remainder_output["rows"], baseline,
                )
                for arm in observed:
                    observed[arm].update(rest[arm])
                require("complete enabled rectangles", all(
                    len(rows) == protocol["cohort"]["rows"]
                    for rows in observed.values()
                ))
        except (OSError, subprocess.TimeoutExpired) as error:
            execution_error, unavailable = str(error), True
        except (FileNotFoundError, json.JSONDecodeError, KeyError, TypeError,
                ValueError, RuntimeError) as error:
            execution_error, unavailable = str(error), True

    if not execution_error and not hard_sentinel_fault:
        score_spec = protocol["packages"]["scoreline"]
        after_spec = protocol["packages"]["afterimage"]
        score = support(
            observed["executioner"], protocol,
            score_spec["producer"], score_spec["consumer"],
        )
        after = support(
            observed["guardedStrike"], protocol,
            after_spec["producer"], after_spec["consumer"],
        )
        baseline_score = support(
            baseline, protocol, score_spec["producer"], score_spec["consumer"],
        )["active"]
        baseline_after = support(
            baseline, protocol, after_spec["producer"], after_spec["consumer"],
        )["active"]
        score_in_after = support(
            observed["guardedStrike"], protocol,
            score_spec["producer"], score_spec["consumer"],
        )["active"]
        after_in_score = support(
            observed["executioner"], protocol,
            after_spec["producer"], after_spec["consumer"],
        )["active"]
        sep = separation(score["active"], after["active"])
        guardrails = {}
        for offset, (arm, rows) in enumerate(observed.items()):
            guardrails[arm] = {
                "winMovement": paired_interval(
                    baseline, rows, protocol,
                    lambda row: float(row["outcome"] == "win"), 423100 + offset,
                ),
                "durationMovement": paired_interval(
                    baseline, rows, protocol, duration, 423110 + offset,
                ),
                "faultRows": sum(fault(row) for row in rows.values()),
                "winRate": sum(row["outcome"] == "win" for row in rows.values())
                / len(rows),
            }
        gates = protocol["gates"]
        fixed = {
            "scorelineSupport": score["counts"]["robustCoPlayPolicies"] >=
            gates["minimumRobustCoPlayPolicies"],
            "scorelineInactivity": score["counts"]["exactInactivePolicies"] >=
            gates["minimumExactInactivePolicies"],
            "scorelineDraw": score["counts"]["robustConsumerDrawPolicies"] >=
            gates["minimumRobustConsumerDrawPolicies"],
            "scorelineViability": score["counts"]["viableCoPlayPolicies"] >=
            gates["minimumViableCoPlayPolicies"],
            "afterimageSupport": after["counts"]["robustCoPlayPolicies"] >=
            gates["minimumRobustCoPlayPolicies"],
            "afterimageInactivity": after["counts"]["exactInactivePolicies"] >=
            gates["minimumExactInactivePolicies"],
            "afterimageDraw": after["counts"]["robustConsumerDrawPolicies"] >=
            gates["minimumRobustConsumerDrawPolicies"],
            "afterimageViability": after["counts"]["viableCoPlayPolicies"] >=
            gates["minimumViableCoPlayPolicies"],
            "scorelineGain": len(score["active"] - baseline_score) >=
            gates["minimumIntendedAnchorGainPolicies"],
            "afterimageGain": len(after["active"] - baseline_after) >=
            gates["minimumIntendedAnchorGainPolicies"],
            "functionalSeparation": (
                sep["scorelineOnlyPolicies"] >= gates["minimumExclusivePolicies"]
                and sep["afterimageOnlyPolicies"] >= gates["minimumExclusivePolicies"]
                and sep["jaccard"] <= gates["maximumIntendedJaccard"]
            ),
            "scorelineCrossInterference": len(score_in_after ^ baseline_score) <=
            gates["maximumCrossPackageAnchorFlips"],
            "afterimageCrossInterference": len(after_in_score ^ baseline_after) <=
            gates["maximumCrossPackageAnchorFlips"],
            "reliability": all(value["faultRows"] == 0
                               for value in guardrails.values()),
            "vow5Ceiling": all(value["winRate"] <= gates["maximumVow5WinRate"]
                               for value in guardrails.values()),
        }
        movement_state = {}
        for arm, values in guardrails.items():
            win = values["winMovement"]
            dur = values["durationMovement"]
            movement_state[arm] = {
                "winPass": win["p025"] >= -gates["maximumAbsoluteWinMovement"]
                and win["p975"] <= gates["maximumAbsoluteWinMovement"],
                "winFail": abs(win["point"]) > gates["maximumAbsoluteWinMovement"],
                "durationPass": dur["p975"] <= gates["maximumDurationMovement"],
                "durationFail": dur["p025"] > gates["maximumDurationMovement"],
            }
        analysis = {
            "scoreline": {**score["counts"], "policies": {
                "active": sorted(score["active"]),
                "inactive": sorted(score["inactive"]),
                "drawn": sorted(score["drawn"]),
                "viable": sorted(score["viable"]),
            }},
            "afterimage": {**after["counts"], "policies": {
                "active": sorted(after["active"]),
                "inactive": sorted(after["inactive"]),
                "drawn": sorted(after["drawn"]),
                "viable": sorted(after["viable"]),
            }},
            "functionalSeparation": sep,
            "intendedAnchorGains": {
                "scoreline": len(score["active"] - baseline_score),
                "afterimage": len(after["active"] - baseline_after),
            },
            "crossPackageInterference": {
                "scorelineFlipsUnderGuardedStrike": len(score_in_after ^ baseline_score),
                "afterimageFlipsUnderExecutioner": len(after_in_score ^ baseline_after),
            },
            "guardrails": guardrails,
            "movementDecision": movement_state,
            "fixedGates": fixed,
        }

    try:
        ledger_after = identity.ledger_identity()
        require("zero-row ledger identity", ledger_after == ledger_before)
    except (RuntimeError, OSError) as error:
        execution_error, unavailable = str(error), True
    elapsed = time.monotonic() - started
    budget = protocol["budget"]
    if elapsed > budget["maximumWallTimeSeconds"]:
        execution_error, unavailable = "explicit acquisition support exceeded wall-time cap", True
    if new_rows > budget["maximumNewSupportObservationRows"]:
        execution_error, unavailable = "explicit acquisition support exceeded row cap", True
    if godot_processes > budget["maximumGodotProcesses"]:
        execution_error, unavailable = "explicit acquisition support exceeded process cap", True

    if execution_error and unavailable:
        boundary, outcome = 3, "inconclusive"
        decision = "record-explicit-acquisition-support-inconclusive"
    elif hard_sentinel_fault:
        boundary, outcome = 2, "futility"
        decision = "close-explicit-acquisition-on-reliability-failure"
    elif not all(analysis["fixedGates"].values()) or any(
        state["winFail"] or state["durationFail"]
        for state in analysis["movementDecision"].values()
    ):
        boundary, outcome = 2, "futility"
        decision = "close-explicit-acquisition-at-support-cap"
    elif not all(
        state["winPass"] and state["durationPass"]
        for state in analysis["movementDecision"].values()
    ):
        boundary, outcome = 3, "inconclusive"
        decision = "record-explicit-acquisition-support-inconclusive"
    else:
        boundary, outcome = 1, "success"
        decision = "freeze-explicit-acquisition-for-exact-mechanism-trace"
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "decisionBoundary": boundary,
        "decision": decision,
        "outcomeClass": outcome,
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "claimClass": "run-level co-play support; not exact mechanism activation",
        "analysis": analysis,
        "hardSentinelFault": hard_sentinel_fault,
        "cacheObjects": cache_objects,
        "executionError": execution_error,
        "newSupportObservationRows": new_rows,
        "newCausalRows": 0,
        "newLedgerRows": 0,
        "GodotProcesses": godot_processes,
        "protectedSeedRows": ledger_after.get(
            "protectedSeedRows", ledger_before.get("protectedSeedRows", 0),
        ),
        "maximumModelContextTokens": 0,
        "wallTimeSeconds": elapsed,
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "authority": protocol["decisionRules"][f"{outcome}Authority"],
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": "PASS",
        "decisionBoundary": boundary,
        "decision": decision,
        "newSupportObservationRows": new_rows,
        "summarySha256": core.file_sha(SUMMARY),
    }))


if __name__ == "__main__":
    main()
