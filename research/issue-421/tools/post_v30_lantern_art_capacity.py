#!/usr/bin/env python3
"""Preregistered CRN Lantern-Art capacity block for issue #421."""

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
from pathlib import Path
from typing import Any, Callable

import research as core


PROTOCOL = core.ROOT / "protocols/post-v30-lantern-art-capacity-v1.json"
SUMMARY = core.ROOT / "summaries/post-v30-lantern-art-capacity-v1.json"
SOURCE = core.ROOT / "lantern-art-identity-source"
GODOT = Path("/Applications/Godot.app/Contents/MacOS/Godot")
PROBE = "res://tools/research_421_lantern_art_identity_probe.gd"
TRACE_KEYS = {
    "capture", "nodes", "plays", "cardRewards", "bossRelics", "arts",
    "beaconAttacks", "beaconChips",
}


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Lantern-Art capacity mismatch: {label}")


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
        "sha256": core.file_sha(core.LEDGER),
        "records": records,
        "firstSequence": first,
        "lastSequence": last,
        "protectedSeedRows": protected,
        "sqliteIntegrity": integrity,
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
        "balanceSimSha256": core.file_sha(SOURCE / "tools/balance_sim.gd"),
        "policySha256": core.file_sha(SOURCE / "tools/balance_policy.gd"),
        "probeSha256": core.file_sha(
            SOURCE / "tools/research_421_lantern_art_identity_probe.gd"),
        "probeUidSha256": core.file_sha(
            SOURCE / "tools/research_421_lantern_art_identity_probe.gd.uid"),
        "runnerSha256": core.file_sha(Path(__file__)),
        "artIdentityProtocolSha256": core.file_sha(
            core.ROOT / "protocols/post-v30-lantern-art-identity-v1.json"),
        "artIdentitySummarySha256": core.file_sha(
            core.ROOT / "summaries/post-v30-lantern-art-identity-v1.json"),
        "taskCapsuleSha256": core.file_sha(core.ROOT / "task-capsule.json"),
    }


def remaining(deadline: float) -> int:
    seconds = int(deadline - time.monotonic())
    if seconds < 1:
        raise TimeoutError("Lantern-Art capacity exceeded its wall-time ceiling")
    return seconds


def run_probe(
    plan: dict[str, Any], deadline: float,
) -> tuple[dict[str, Any], str, str]:
    plan_sha, plan_path = core.cache_json(plan)
    core.WORK.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(
        dir=core.WORK, prefix="lantern-art-capacity-"
    ) as tmp:
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


def plan(
    protocol: dict[str, Any], protocol_sha: str, identity: bool,
) -> dict[str, Any]:
    cohort = protocol["cohort"]
    policies = cohort["policyIndices"][:protocol["traceIdentity"]["policyCount"]] \
        if identity else cohort["policyIndices"]
    seeds = cohort["simulationSeeds"][:1] if identity else cohort["simulationSeeds"]
    arms = ("omitted", "explicit-flare") if identity else ("explicit-flare", "beacon")
    rows: list[dict[str, Any]] = []
    for policy_index in policies:
        for seed in seeds:
            for arm in arms:
                rows.append({
                    "id": f"p{policy_index}-s{seed}-{arm}",
                    "arm": arm,
                    "policyRoot": cohort["policyRoot"],
                    "policyIndex": policy_index,
                    "seed": seed,
                    "aspect": cohort["aspect"],
                    "vow": cohort["vow"],
                })
    return {
        "schemaVersion": 1,
        "protocolSha256": protocol_sha,
        "mode": "whole-runs",
        "content": str(SOURCE / "content/full-content.json"),
        "rows": rows,
    }


def comparable(row: dict[str, Any]) -> dict[str, Any]:
    value = copy.deepcopy(row)
    value.pop("id")
    value.pop("arm")
    return value


def trace_schema(row: dict[str, Any]) -> bool:
    trace = row.get("trajectory")
    return isinstance(trace, dict) and set(trace) == TRACE_KEYS \
        and trace.get("capture") is True \
        and all(isinstance(trace[key], list) for key in TRACE_KEYS - {"capture"})


def check_trace_identity(
    output: dict[str, Any], protocol: dict[str, Any],
) -> dict[str, Any]:
    rows = output.get("rows")
    expected = int(protocol["traceIdentity"]["observationRows"])
    require("trace identity rows", isinstance(rows, list) and len(rows) == expected)
    indexed: dict[str, dict[tuple[int, int], dict[str, Any]]] = {
        "omitted": {}, "explicit-flare": {},
    }
    schema_faults = 0
    false_beacon_rows = 0
    for row in rows:
        arm = str(row.get("arm", ""))
        require(f"trace identity arm {arm}", arm in indexed)
        key = int(row["policyIndex"]), int(row["seed"])
        require(f"unique trace identity {arm} {key}", key not in indexed[arm])
        indexed[arm][key] = row
        schema_faults += not trace_schema(row)
        trace = row.get("trajectory", {})
        false_beacon_rows += bool(trace.get("beaconAttacks")) \
            or bool(trace.get("beaconChips")) \
            or any(art.get("id") != "flare" for art in trace.get("arts", []))
    require("paired trace identities", set(indexed["omitted"]) == set(indexed["explicit-flare"]))
    mismatches = sum(
        comparable(indexed["omitted"][key])
        != comparable(indexed["explicit-flare"][key])
        for key in indexed["omitted"]
    )
    require("trace schema", schema_faults == 0)
    require("trace false Beacon", false_beacon_rows == 0)
    require("trace complete null identity", mismatches == 0)
    return {
        "identities": len(indexed["omitted"]),
        "observationRows": len(rows),
        "completeMismatchRows": mismatches,
        "schemaFaultRows": schema_faults,
        "falseBeaconRows": false_beacon_rows,
    }


def index_capacity(
    output: dict[str, Any], protocol: dict[str, Any],
) -> dict[str, dict[tuple[int, int], dict[str, Any]]]:
    rows = output.get("rows")
    expected = int(protocol["budget"]["capacityObservationRows"])
    require("capacity rows", isinstance(rows, list) and len(rows) == expected)
    indexed: dict[str, dict[tuple[int, int], dict[str, Any]]] = {
        "explicit-flare": {}, "beacon": {},
    }
    for row in rows:
        arm = str(row.get("arm", ""))
        require(f"capacity arm {arm}", arm in indexed)
        key = int(row["policyIndex"]), int(row["seed"])
        require(f"unique capacity row {arm} {key}", key not in indexed[arm])
        require(f"capacity trace schema {arm} {key}", trace_schema(row))
        indexed[arm][key] = row
    require("capacity CRN rectangle", set(indexed["explicit-flare"]) == set(indexed["beacon"]))
    require("capacity identity count", len(indexed["beacon"])
            == int(protocol["cohort"]["policyCount"])
            * len(protocol["cohort"]["simulationSeeds"]))
    return indexed


def ordered_pair(row: dict[str, Any], producer: str, consumer: str) -> bool:
    by_fight: dict[int, list[dict[str, Any]]] = {}
    for play in row["trajectory"]["plays"]:
        by_fight.setdefault(int(play["fight"]), []).append(play)
    return any(
        any(left["id"] == producer and right["id"] == consumer
            and int(left["event"]) < int(right["event"])
            for left in plays for right in plays)
        for plays in by_fight.values()
    )


def robust_set(
    rows: dict[tuple[int, int], dict[str, Any]], protocol: dict[str, Any],
    predicate: Callable[[dict[str, Any]], bool],
) -> set[int]:
    minimum = int(protocol["cohort"]["minimumRowsPerRobustPolicy"])
    hits: dict[int, int] = {}
    for (policy, _seed), row in rows.items():
        if predicate(row):
            hits[policy] = hits.get(policy, 0) + 1
    return {policy for policy, count in hits.items() if count >= minimum}


def exact_inactive_set(
    rows: dict[tuple[int, int], dict[str, Any]], protocol: dict[str, Any],
    predicate: Callable[[dict[str, Any]], bool],
) -> set[int]:
    active = {policy for (policy, _seed), row in rows.items() if predicate(row)}
    return set(protocol["cohort"]["policyIndices"]) - active


def separation(candidate: set[int], anchor: set[int]) -> dict[str, Any]:
    union = candidate | anchor
    return {
        "candidateOnlyPolicies": len(candidate - anchor),
        "anchorOnlyPolicies": len(anchor - candidate),
        "crossActivePolicies": len(candidate & anchor),
        "jaccard": len(candidate & anchor) / len(union) if union else 1.0,
    }


def interval(
    values: list[float], resamples: int, seed: int,
) -> dict[str, float]:
    require("interval values", bool(values))
    rng = random.Random(seed)
    boot = [statistics.fmean(rng.choice(values) for _ in values)
            for _ in range(resamples)]
    return {
        "policies": len(values),
        "point": statistics.fmean(values),
        "p025": core.percentile(boot, 0.025),
        "p975": core.percentile(boot, 0.975),
    }


def total_shatters(row: dict[str, Any]) -> float:
    return float(sum(int(fight.get("shatters", 0)) for fight in row["fights"]))


def duration(row: dict[str, Any]) -> float:
    fights = row["fights"]
    return statistics.fmean(float(fight["turns"]) for fight in fights) if fights else 0.0


def analyse(
    cells: dict[str, dict[tuple[int, int], dict[str, Any]]],
    protocol: dict[str, Any],
) -> dict[str, Any]:
    baseline = cells["explicit-flare"]
    beacon = cells["beacon"]
    keys = sorted(beacon)
    policy_same = all(beacon[key]["policy"] == baseline[key]["policy"] for key in keys)
    require("capacity policy identity", policy_same)
    flare_trace_faults = sum(
        bool(row["trajectory"]["beaconAttacks"])
        or bool(row["trajectory"]["beaconChips"])
        or any(art["id"] != "flare" for art in row["trajectory"]["arts"])
        for row in baseline.values()
    )
    beacon_trace_faults = sum(
        any(art["id"] != "beacon" for art in row["trajectory"]["arts"])
        for row in beacon.values()
    )
    require("Flare trace isolation", flare_trace_faults == 0)
    require("Beacon trace isolation", beacon_trace_faults == 0)

    mediator = lambda row: bool(row["trajectory"]["beaconChips"])
    mediator_active = robust_set(beacon, protocol, mediator)
    mediator_inactive = exact_inactive_set(beacon, protocol, mediator)
    attack_ids = sorted({event["id"] for row in beacon.values()
                         for event in row["trajectory"]["beaconChips"]})

    deltas: dict[int, dict[str, list[float]]] = {
        policy: {name: [] for name in ("shatters", "duration", "win")}
        for policy in protocol["cohort"]["policyIndices"]
    }
    positive_seed_counts: dict[int, int] = {policy: 0 for policy in deltas}
    for policy, seed in keys:
        left, right = baseline[(policy, seed)], beacon[(policy, seed)]
        shatter_delta = total_shatters(right) - total_shatters(left)
        deltas[policy]["shatters"].append(shatter_delta)
        deltas[policy]["duration"].append(duration(right) - duration(left))
        deltas[policy]["win"].append(
            float(right["outcome"] == "win") - float(left["outcome"] == "win"))
        positive_seed_counts[policy] += shatter_delta > 0
    minimum = int(protocol["cohort"]["minimumRowsPerRobustPolicy"])
    positive = {
        policy for policy, values in deltas.items()
        if positive_seed_counts[policy] >= minimum
        and statistics.fmean(values["shatters"]) > 0
    }
    inactive = {
        policy for policy, values in deltas.items()
        if all(value == 0 for value in values["shatters"])
    }
    viable = {
        policy for policy in positive
        if any(beacon[(policy, seed)]["outcome"] == "win"
               and mediator(beacon[(policy, seed)])
               for seed in protocol["cohort"]["simulationSeeds"])
    }

    anchor_defs = protocol["anchors"]
    anchors: dict[str, dict[str, set[int]]] = {}
    for name, definition in anchor_defs.items():
        producer, consumer = definition["producer"], definition["consumer"]
        predicate = lambda row, p=producer, c=consumer: ordered_pair(row, p, c)
        anchors[name] = {
            "baseline": robust_set(baseline, protocol, predicate),
            "beacon": robust_set(beacon, protocol, predicate),
        }
    separations = {
        name: separation(positive, values["baseline"])
        for name, values in anchors.items()
    }
    interference = {
        name: {
            "baselinePolicies": sorted(values["baseline"]),
            "beaconPolicies": sorted(values["beacon"]),
            "activationFlipPolicies": sorted(values["baseline"] ^ values["beacon"]),
            "activationFlipCount": len(values["baseline"] ^ values["beacon"]),
            "jaccard": separation(values["baseline"], values["beacon"])["jaccard"],
        }
        for name, values in anchors.items()
    }

    estimates = {
        metric: interval(
            [statistics.fmean(values[metric]) for values in deltas.values()],
            int(protocol["estimator"]["bootstrapResamples"]),
            int(protocol["estimator"]["bootstrapSeedBase"]) + index,
        )
        for index, metric in enumerate(("shatters", "duration", "win"))
    }
    baseline_faults = {
        key for key, row in baseline.items()
        if row["outcome"] in ("stall", "error") or bool(row.get("error"))
    }
    beacon_faults = {
        key for key, row in beacon.items()
        if row["outcome"] in ("stall", "error") or bool(row.get("error"))
    }
    added_faults = beacon_faults - baseline_faults
    candidate_win_rate = sum(row["outcome"] == "win" for row in beacon.values()) / len(beacon)
    gates = protocol["gates"]

    def separated(value: dict[str, Any]) -> bool:
        return value["candidateOnlyPolicies"] >= gates["minimumCandidateOnlyPolicies"] \
            and value["anchorOnlyPolicies"] >= gates["minimumAnchorOnlyPolicies"] \
            and value["jaccard"] <= gates["maximumAnchorJaccard"]

    gate_results = {
        "mediatorActive": len(mediator_active) >= gates["minimumMediatorActivePolicies"],
        "mediatorInactive": len(mediator_inactive) >= gates["minimumMediatorInactivePolicies"],
        "mediatorBreadth": len(attack_ids) >= gates["minimumBeaconAttackIds"],
        "positivePolicies": len(positive) >= gates["minimumPositivePolicies"],
        "inactivePolicies": len(inactive) >= gates["minimumExactInactivePolicies"],
        "viablePolicies": len(viable) >= gates["minimumViablePolicies"],
        "scorelineSeparation": separated(separations["scoreline"]),
        "afterimageSeparation": separated(separations["afterimage"]),
        "scorelineInterference": interference["scoreline"]["activationFlipCount"]
            <= gates["maximumAnchorActivationFlipPolicies"],
        "afterimageInterference": interference["afterimage"]["activationFlipCount"]
            <= gates["maximumAnchorActivationFlipPolicies"],
        "effect": estimates["shatters"]["p025"] > gates["minimumShatterEffectLowerBound"],
        "duration": estimates["duration"]["p975"] <= gates["maximumDurationIncrease"],
        "globalWinMovement": estimates["win"]["p025"] >= -gates["maximumGlobalWinMovement"]
            and estimates["win"]["p975"] <= gates["maximumGlobalWinMovement"],
        "vow5Ceiling": candidate_win_rate <= gates["maximumVow5WinRate"],
        "baselineReliability": len(baseline_faults) <= gates["maximumBaselineFaultRows"],
        "zeroAddedFaults": not added_faults,
        "traceIsolation": flare_trace_faults == 0 and beacon_trace_faults == 0,
        "policyIdentity": policy_same,
    }
    fixed_names = {
        "mediatorActive", "mediatorInactive", "mediatorBreadth", "positivePolicies",
        "inactivePolicies", "viablePolicies", "scorelineSeparation",
        "afterimageSeparation", "scorelineInterference", "afterimageInterference",
        "vow5Ceiling", "baselineReliability", "zeroAddedFaults", "traceIsolation",
        "policyIdentity",
    }
    fixed_failure = any(not gate_results[name] for name in fixed_names) \
        or estimates["shatters"]["p975"] <= gates["minimumShatterEffectLowerBound"] \
        or estimates["duration"]["p025"] > gates["maximumDurationIncrease"] \
        or abs(estimates["win"]["point"]) > gates["maximumGlobalWinMovement"]
    success = all(gate_results.values())
    policy_universe = set(protocol["cohort"]["policyIndices"])
    return {
        "gateResults": gate_results,
        "success": success,
        "fixedFailure": fixed_failure,
        "counts": {
            "mediatorActivePolicies": len(mediator_active),
            "mediatorInactivePolicies": len(mediator_inactive),
            "positivePolicies": len(positive),
            "exactInactivePolicies": len(inactive),
            "viablePolicies": len(viable),
            "ambiguousPolicies": len(policy_universe - positive - inactive),
            "baselineFaultRows": len(baseline_faults),
            "beaconFaultRows": len(beacon_faults),
            "addedFaultRows": len(added_faults),
            "beaconArtUses": sum(len(row["trajectory"]["arts"]) for row in beacon.values()),
            "beaconAttackEvents": sum(len(row["trajectory"]["beaconAttacks"])
                                      for row in beacon.values()),
            "beaconChipEvents": sum(len(row["trajectory"]["beaconChips"])
                                    for row in beacon.values()),
        },
        "policySets": {
            "mediatorActive": sorted(mediator_active),
            "mediatorInactive": sorted(mediator_inactive),
            "positive": sorted(positive),
            "exactInactive": sorted(inactive),
            "viable": sorted(viable),
        },
        "beaconAttackIds": attack_ids,
        "separation": separations,
        "interference": interference,
        "estimates": estimates,
        "candidateWinRate": candidate_win_rate,
        "baselineFaultIdentities": sorted([list(key) for key in baseline_faults]),
        "beaconFaultIdentities": sorted([list(key) for key in beacon_faults]),
        "addedFaultIdentities": sorted([list(key) for key in added_faults]),
    }


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite Lantern-Art capacity summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    source = source_identity()
    for key, expected in protocol["immutableInputs"].items():
        require(f"immutable {key}", source.get(key) == expected)
    ledger_before = ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
    started = time.monotonic()
    deadline = started + float(protocol["budget"]["maximumWallTimeSeconds"])
    manifests: dict[str, Any] = {}
    trace_identity: dict[str, Any] = {}
    analysis: dict[str, Any] = {}
    process_count = 0
    observation_rows = 0
    failure = ""
    outcome_class = "success"
    try:
        output, plan_sha, output_sha = run_probe(
            plan(protocol, protocol_sha, True), deadline)
        process_count += 1
        trace_identity = check_trace_identity(output, protocol)
        observation_rows += len(output["rows"])
        manifests["traceIdentity"] = {
            "planSha256": plan_sha, "outputSha256": output_sha,
        }

        output, plan_sha, output_sha = run_probe(
            plan(protocol, protocol_sha, False), deadline)
        process_count += 1
        observation_rows += len(output["rows"])
        analysis = analyse(index_capacity(output, protocol), protocol)
        manifests["capacity"] = {
            "planSha256": plan_sha, "outputSha256": output_sha,
        }
        require("total row cap", observation_rows
                == protocol["budget"]["maximumNewSimulatorObservationRows"])
        require("process cap", process_count == protocol["budget"]["maximumGodotProcesses"])
        if analysis["success"]:
            outcome_class = "success"
        elif analysis["fixedFailure"]:
            outcome_class = "futility"
        else:
            outcome_class = "inconclusive"
    except (subprocess.TimeoutExpired, TimeoutError) as error:
        failure = str(error)
        outcome_class = "inconclusive"
    except (KeyError, RuntimeError, TypeError, ValueError) as error:
        failure = str(error)
        outcome_class = "futility"

    elapsed = time.monotonic() - started
    ledger_after = ledger_identity()
    if elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        failure = failure or "wall-time ceiling"
        outcome_class = "inconclusive"
    if ledger_after != ledger_before:
        failure = failure or "ledger identity drift"
        outcome_class = "inconclusive"
    decision = {
        "success": "freeze-beacon-art-for-independent-heldout-confirmation",
        "futility": "close-lantern-art-family-at-cap",
        "inconclusive": "record-lantern-art-capacity-inconclusive-at-cap",
    }[outcome_class]
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "decisionBoundary": {"success": 1, "futility": 2, "inconclusive": 3}[
            outcome_class],
        "decision": decision,
        "outcomeClass": outcome_class,
        "failure": failure,
        "protocolSha256": protocol_sha,
        "sourceIdentity": source,
        "traceIdentity": trace_identity,
        "analysis": analysis,
        "execution": {
            "manifests": manifests,
            "GodotProcesses": process_count,
            "newSimulatorObservationRows": observation_rows,
            "causalObservationRows": protocol["budget"]["capacityObservationRows"]
                if analysis else 0,
            "newLedgerRows": ledger_after["records"] - ledger_before["records"],
            "protectedSeedRows": ledger_after["protectedSeedRows"],
            "maximumModelContextTokens": 0,
            "wallTimeSeconds": elapsed,
        },
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "authority": protocol["decisionRules"][f"{outcome_class}Authority"],
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": "PASS" if not failure else "FAIL",
        "decision": decision,
        "decisionBoundary": summary["decisionBoundary"],
        "summarySha256": core.file_sha(SUMMARY),
    }))
    if failure:
        sys.exit(2)


if __name__ == "__main__":
    main()
