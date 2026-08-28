#!/usr/bin/env python3
"""Independent whole-run confirmation of the one frozen issue #421 candidate."""

from __future__ import annotations

import argparse
import itertools
import json
import statistics
import subprocess
import time
from pathlib import Path
from typing import Any

import post_v38_blocked_crn as blocked
import post_v38_knob_identity as identity_v1
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-heldout-confirmation-v1.json"
MANIFEST = core.ROOT / "execution/post-v38-heldout-confirmation-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-heldout-confirmation-v1.json"


def source_identity() -> dict[str, Any]:
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
        "balanceSimSha256": core.file_sha(core.SOURCE / "tools/balance_sim.gd"),
        "probeSha256": core.file_sha(core.SOURCE / "tools/research_421_probe.gd"),
        "researchCoreSha256": core.file_sha(core.ROOT / "research.py"),
        "blockedRunnerSha256": core.file_sha(core.ROOT / "post_v38_blocked_crn.py"),
        "runnerSha256": core.file_sha(Path(__file__)),
    }


def protocol_observation_count(db: Any, protocol_sha: str) -> int:
    return int(db.execute(
        "SELECT COUNT(*) FROM records WHERE kind = 'observation' AND identity LIKE ?",
        (f"{protocol_sha}:%",),
    ).fetchone()[0])


def verify_entry(protocol: dict[str, Any], protocol_sha: str) -> dict[str, Any]:
    actual = source_identity()
    for key, expected in protocol["immutableInputs"].items():
        if actual.get(key) != expected:
            raise RuntimeError(
                f"immutable input drift: {key} expected {expected} got {actual.get(key)}"
            )
    for name, packet in protocol["entryGate"]["firstLookEvidence"].items():
        path = core.ROOT / packet["path"]
        if core.file_sha(path) != packet["sha256"]:
            raise RuntimeError(f"first-look {name} drifted")
    first_look = json.loads((
        core.ROOT / protocol["entryGate"]["firstLookEvidence"]["summary"]["path"]
    ).read_text())
    if first_look.get("decision") != "freeze-one-for-held-out-confirmation" \
            or first_look.get("selectedCandidate") != protocol["candidate"]:
        raise RuntimeError("first-look candidate freeze is not exact")
    for arm in ("candidate", "baseline"):
        content_sha = protocol[arm]["contentSha256"]
        path = core.CACHE / f"{content_sha}.json"
        if not path.is_file() or core.file_sha(path) != content_sha:
            raise RuntimeError(f"{arm} content cache is missing or corrupt")
    if not MANIFEST.is_file():
        raise RuntimeError("execution manifest is missing")
    manifest = json.loads(MANIFEST.read_text())
    required = {
        "protocolSha256": protocol_sha,
        "runnerSha256": actual["runnerSha256"],
        "probeSha256": actual["probeSha256"],
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
                raise RuntimeError("ledger changed before the first held-out observation")
    return {**actual, "executionManifestSha256": core.file_sha(MANIFEST)}


def cohort_rows(protocol: dict[str, Any], arm: str) -> list[dict[str, Any]]:
    settings = protocol[arm]["research421" if arm == "candidate" else "researchSettings"]
    random_seeds = protocol["cohorts"]["randomBuildSeeds"]
    rows = [{
        "id": f"heldout-random-{arm}-{aspect}-v{vow}-{seed}",
        "stage": "post-v38-heldout-confirmation",
        "arm": "random",
        "mode": "whole-run",
        "aspect": aspect,
        "vow": vow,
        "seed": seed,
        "randomBuild": True,
        "randomPlay": False,
        "research421": settings,
    } for aspect in ("duskblade", "ashwarden") for vow in (0, 5)
        for seed in range(int(random_seeds["first"]), int(random_seeds["last"]) + 1)]
    policy = protocol["cohorts"]["policyIdentity"]
    policy_seeds = protocol["cohorts"]["policySimulationSeeds"]
    rows.extend({
        "id": f"heldout-policy-{arm}-{aspect}-{index}-{seed}",
        "stage": "post-v38-heldout-confirmation",
        "arm": "policy",
        "mode": "whole-run",
        "aspect": aspect,
        "vow": 5,
        "seed": seed,
        "policyRoot": int(policy["root"]),
        "policyIndex": index,
        "research421": settings,
    } for aspect in ("duskblade", "ashwarden")
        for index in range(int(policy["firstIndex"]), int(policy["lastIndex"]) + 1)
        for seed in range(int(policy_seeds["first"]), int(policy_seeds["last"]) + 1))
    expected = int(protocol["budget"]["rowsPerContentArm"])
    if len(rows) != expected or len({row["id"] for row in rows}) != expected:
        raise ValueError(f"{arm} held-out rectangle is incomplete or duplicated")
    if any(3000 <= int(row["seed"]) <= 5399 for row in rows):
        raise ValueError("protected seed entered the held-out cohort")
    return rows


def plan_for(protocol_sha: str, content_sha: str,
             rows: list[dict[str, Any]]) -> dict[str, Any]:
    return {
        "schemaVersion": 1,
        "mode": "whole-run",
        "protocolSha256": protocol_sha,
        "content": str(core.CACHE / f"{content_sha}.json"),
        "rows": rows,
    }


def split_rows(rows: list[dict[str, Any]]) -> tuple[
        dict[tuple[str, int, int], dict[str, Any]],
        dict[tuple[str, int, int], dict[str, Any]]]:
    return (
        {(str(row["aspect"]), int(row["vow"]), int(row["seed"])): row
         for row in rows if row["arm"] == "random"},
        {(str(row["aspect"]), int(row["policyIndex"]), int(row["seed"])): row
         for row in rows if row["arm"] == "policy"},
    )


def validate_rectangle(protocol: dict[str, Any], rows: list[dict[str, Any]]) -> None:
    random_rows, policy_rows = split_rows(rows)
    random_seeds = protocol["cohorts"]["randomBuildSeeds"]
    expected_random = {
        (aspect, vow, seed)
        for aspect in ("duskblade", "ashwarden") for vow in (0, 5)
        for seed in range(int(random_seeds["first"]), int(random_seeds["last"]) + 1)
    }
    policy = protocol["cohorts"]["policyIdentity"]
    policy_seeds = protocol["cohorts"]["policySimulationSeeds"]
    expected_policy = {
        (aspect, index, seed)
        for aspect in ("duskblade", "ashwarden")
        for index in range(int(policy["firstIndex"]), int(policy["lastIndex"]) + 1)
        for seed in range(int(policy_seeds["first"]), int(policy_seeds["last"]) + 1)
    }
    if set(random_rows) != expected_random or set(policy_rows) != expected_policy:
        raise ValueError("held-out output rectangle drifted")


def first_look_policy_hashes(db: Any, protocol: dict[str, Any]) -> set[str]:
    first_look_sha = protocol["entryGate"]["firstLookProtocolSha256"]
    rows = db.execute(
        "SELECT payload_json FROM records WHERE kind = 'observation' "
        "AND identity LIKE ? AND json_extract(payload_json, '$.policyRoot') = 545",
        (f"{first_look_sha}:%",),
    ).fetchall()
    hashes = {
        core.sha(core.canonical(json.loads(payload)["policy"]).encode())
        for (payload,) in rows
    }
    if len(hashes) != int(protocol["entryGate"]["firstLookPolicyIdentities"]):
        raise RuntimeError("first-look policy snapshot set is incomplete")
    return hashes


def policy_identity_audit(
    protocol: dict[str, Any], candidate: dict[tuple[str, int, int], dict[str, Any]],
    baseline: dict[tuple[str, int, int], dict[str, Any]], first_look: set[str],
) -> dict[str, Any]:
    if set(candidate) != set(baseline):
        raise ValueError("candidate and live policy rectangles differ")
    by_index: dict[int, set[str]] = {}
    for rows in (candidate, baseline):
        for (_, index, _), row in rows.items():
            policy = row.get("policy")
            if not isinstance(policy, dict):
                raise ValueError("policy snapshot is missing")
            by_index.setdefault(index, set()).add(
                core.sha(core.canonical(policy).encode())
            )
    expected = int(protocol["cohorts"]["policyIdentity"]["count"])
    exact = len(by_index) == expected and all(len(values) == 1 for values in by_index.values())
    held_out = {next(iter(values)) for values in by_index.values()}
    unique = len(held_out) == expected
    overlap = sorted(held_out & first_look)
    return {
        "policyIdentities": len(by_index),
        "oneSnapshotPerIdentityAcrossArmsAspectsAndSeeds": exact,
        "uniqueHeldOutSnapshots": len(held_out),
        "firstLookSnapshots": len(first_look),
        "firstLookOverlapCount": len(overlap),
        "clear": exact and unique and not overlap,
    }


def package_gate(
    protocol: dict[str, Any], policy_rows: dict[tuple[str, int, int], dict[str, Any]],
) -> dict[str, Any]:
    packages = protocol["packages"]
    indices = range(
        int(protocol["cohorts"]["policyIdentity"]["firstIndex"]),
        int(protocol["cohorts"]["policyIdentity"]["lastIndex"]) + 1,
    )
    active: dict[str, set[int]] = {}
    reachable: dict[str, set[int]] = {}
    consumed: dict[str, set[int]] = {}
    for name, spec in packages.items():
        aspect = str(spec["aspect"])
        producer, consumer = str(spec["producer"]), str(spec["consumer"])
        relevant = {
            index: [row for (found_aspect, found_index, _), row in policy_rows.items()
                    if (found_aspect, found_index) == (aspect, index)]
            for index in indices
        }
        active[name] = {
            index for index, rows in relevant.items()
            if any(core._package_activation(row, spec) > 0 for row in rows)
        }
        reachable[name] = {
            index for index, rows in relevant.items()
            if any({producer, consumer}.issubset(set(map(str, row.get("deckIds", []))))
                   for row in rows)
        }
        consumed[name] = {
            index for index, rows in relevant.items()
            if any(int((row.get("packageEvents") or {}).get(spec["consumedMetric"], 0)) > 0
                   and {producer, consumer}.issubset(set(map(str, row.get("deckIds", []))))
                   for row in rows)
        }
    package_results: dict[str, Any] = {}
    separation: dict[str, Any] = {}
    sensitivity_minimum = int(protocol["gates"]["minimumActiveAndInactivePolicies"])
    reachability_minimum = int(protocol["gates"]["minimumReachablePolicies"])
    separation_minimum = int(protocol["gates"]["minimumExclusivePolicies"])
    count = int(protocol["cohorts"]["policyIdentity"]["count"])
    for name in packages:
        active_count = len(active[name])
        package_results[name] = {
            "active": active_count,
            "inactive": count - active_count,
            "finalPairReachable": len(reachable[name]),
            "consumerReachedWithFinalPair": len(consumed[name]),
            "sensitivityClear": active_count >= sensitivity_minimum
            and count - active_count >= sensitivity_minimum,
            "reachabilityClear": len(reachable[name]) >= reachability_minimum
            and len(consumed[name]) >= reachability_minimum,
        }
    for aspect in ("duskblade", "ashwarden"):
        names = sorted(name for name, spec in packages.items() if spec["aspect"] == aspect)
        if len(names) != 2:
            raise ValueError(f"{aspect} must have exactly two registered packages")
        first, second = names
        separation[aspect] = {
            f"{first}Only": len(active[first] - active[second]),
            f"{second}Only": len(active[second] - active[first]),
        }
        separation[aspect]["clear"] = all(
            value >= separation_minimum
            for key, value in separation[aspect].items() if key.endswith("Only")
        )
    return {
        "packages": package_results,
        "functionalSeparation": separation,
        "clear": all(result["sensitivityClear"] and result["reachabilityClear"]
                     for result in package_results.values())
        and all(result["clear"] for result in separation.values()),
    }


def safety_gate(
    protocol: dict[str, Any], candidate_random: dict[Any, dict[str, Any]],
    candidate_policy: dict[Any, dict[str, Any]], baseline_random: dict[Any, dict[str, Any]],
    baseline_policy: dict[Any, dict[str, Any]],
) -> dict[str, Any]:
    if set(candidate_random) != set(baseline_random) \
            or set(candidate_policy) != set(baseline_policy):
        raise ValueError("candidate and live CRN rectangles differ")
    random_results: dict[str, Any] = {}
    for aspect, vow in itertools.product(("duskblade", "ashwarden"), (0, 5)):
        keys = sorted(key for key in candidate_random if key[:2] == (aspect, vow))
        deltas = [
            float(candidate_random[key]["outcome"] == "win")
            - float(baseline_random[key]["outcome"] == "win") for key in keys
        ]
        movement = blocked.signed_interval(
            deltas, 1.0, int(protocol["budget"]["bootstrapResamples"])
        )
        rate = statistics.fmean(candidate_random[key]["outcome"] == "win" for key in keys)
        added_faults = sum(
            blocked.is_fault(candidate_random[key])
            and not blocked.is_fault(baseline_random[key]) for key in keys
        )
        random_results[f"{aspect}:v{vow}"] = {
            "winRate": rate,
            "candidateMinusLive": movement,
            "addedFaults": added_faults,
            "clear": rate < float(protocol["gates"]["randomBuildWinCeiling"])
            and abs(movement["point"]) <= float(
                protocol["gates"]["maximumAbsoluteRandomBuildMovement"]
            ) and added_faults == 0,
        }
    policy_results: dict[str, Any] = {}
    for aspect in ("duskblade", "ashwarden"):
        keys = sorted(key for key in candidate_policy if key[0] == aspect)
        faults = sum(blocked.is_fault(candidate_policy[key]) for key in keys)
        added_faults = sum(
            blocked.is_fault(candidate_policy[key])
            and not blocked.is_fault(baseline_policy[key]) for key in keys
        )
        duration_values: list[float] = []
        missing = 0
        for key in keys:
            candidate_turns = blocked.mean_turns(candidate_policy[key])
            baseline_turns = blocked.mean_turns(baseline_policy[key])
            if candidate_turns is None or baseline_turns is None:
                missing += 1
            else:
                duration_values.append(candidate_turns - baseline_turns)
        duration = None if missing else blocked.signed_interval(
            duration_values, 1.0, int(protocol["budget"]["bootstrapResamples"])
        )
        win_rate = statistics.fmean(candidate_policy[key]["outcome"] == "win" for key in keys)
        policy_results[aspect] = {
            "winRate": win_rate,
            "faults": faults,
            "addedFaults": added_faults,
            "durationCandidateMinusLive": duration,
            "durationMissingPairs": missing,
            "fixedClear": faults == 0 and added_faults == 0
            and win_rate <= float(protocol["gates"]["vow5PolicyWinCeiling"]),
            "durationClear": duration is not None
            and duration["p975"] <= float(protocol["gates"]["durationUpperBound"]),
        }
    return {
        "randomBuild": random_results,
        "policy": policy_results,
        "randomBuildClear": all(result["clear"] for result in random_results.values()),
        "policyFixedClear": all(result["fixedClear"] for result in policy_results.values()),
        "durationClear": all(result["durationClear"] for result in policy_results.values()),
    }


def analyse(protocol: dict[str, Any], candidate_rows: list[dict[str, Any]],
            baseline_rows: list[dict[str, Any]], first_look: set[str]) -> dict[str, Any]:
    validate_rectangle(protocol, candidate_rows)
    validate_rectangle(protocol, baseline_rows)
    candidate_random, candidate_policy = split_rows(candidate_rows)
    baseline_random, baseline_policy = split_rows(baseline_rows)
    identities = policy_identity_audit(
        protocol, candidate_policy, baseline_policy, first_look
    )
    packages = package_gate(protocol, candidate_policy)
    safety = safety_gate(
        protocol, candidate_random, candidate_policy, baseline_random, baseline_policy
    )
    fixed_clear = identities["clear"] and packages["clear"] \
        and safety["randomBuildClear"] and safety["policyFixedClear"]
    if fixed_clear and safety["durationClear"]:
        decision = "confirm-one-frozen-candidate"
        boundary = 1
    elif not fixed_clear:
        decision = "reject-candidate-close-scalar-family-continue-structurally"
        boundary = 2
    else:
        duration_limit = float(protocol["gates"]["durationUpperBound"])
        decisively_slow = any(
            result["durationCandidateMinusLive"] is not None
            and result["durationCandidateMinusLive"]["p025"] > duration_limit
            for result in safety["policy"].values()
        )
        decision = (
            "reject-candidate-close-scalar-family-continue-structurally"
            if decisively_slow else "inconclusive-at-preregistered-cap"
        )
        boundary = 2 if decisively_slow else 3
    return {
        "schemaVersion": 1,
        "decisionBoundary": boundary,
        "decision": decision,
        "policyIdentityAudit": identities,
        "strategyPackageActivation": packages,
        "guardrails": safety,
    }


def enforce_wall_cap(protocol: dict[str, Any], started: float) -> None:
    if time.monotonic() - started > float(protocol["budget"]["maximumWallTimeSeconds"]):
        raise TimeoutError("held-out wall-time cap reached")


def execute() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to rerun a completed held-out protocol")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    identity = verify_entry(protocol, protocol_sha)
    started = time.monotonic()
    db = core.open_ledger()
    core.record(db, "protocol", protocol_sha, protocol)
    core.record(db, "source-identity", core.sha(core.canonical(identity).encode()), identity)
    first_look = first_look_policy_hashes(db, protocol)
    outputs: dict[str, list[dict[str, Any]]] = {}
    for arm in ("baseline", "candidate"):
        output = core.run_plan(
            db, protocol_sha,
            plan_for(protocol_sha, protocol[arm]["contentSha256"], cohort_rows(protocol, arm)),
        )
        validate_rectangle(protocol, output["rows"])
        outputs[arm] = output["rows"]
        observed = protocol_observation_count(db, protocol_sha)
        if observed > int(protocol["budget"]["maximumNewSimulatorObservationRows"]):
            raise RuntimeError("held-out simulator observation cap exceeded")
        enforce_wall_cap(protocol, started)
        print(core.canonical({"stage": "held-out", "arm": arm,
                              "protocolObservationRows": observed}), flush=True)
    observed = protocol_observation_count(db, protocol_sha)
    if observed != int(protocol["budget"]["maximumNewSimulatorObservationRows"]):
        raise RuntimeError("held-out final rectangle does not match its frozen budget")
    result = analyse(protocol, outputs["candidate"], outputs["baseline"], first_look)
    enforce_wall_cap(protocol, started)
    analysis = {
        **result,
        "protocolSha256": protocol_sha,
        "runnerSha256": identity["runnerSha256"],
        "newSimulatorObservationRows": observed,
        "protectedSeedRows": 0,
    }
    analysis_sha, _ = core.cache_json(analysis)
    core.record(db, "analysis", f"post-v38-heldout:analysis:{protocol_sha}", {
        **analysis, "analysisSha256": analysis_sha,
    })
    summary = {
        "schemaVersion": 1,
        "decisionBoundary": result["decisionBoundary"],
        "decision": result["decision"],
        "protocolSha256": protocol_sha,
        "runnerSha256": identity["runnerSha256"],
        "executionManifestSha256": identity["executionManifestSha256"],
        "analysisSha256": analysis_sha,
        "candidate": protocol["candidate"],
        "newSimulatorObservationRows": observed,
        "protectedSeedRows": 0,
        "wallTimeSeconds": time.monotonic() - started,
        "authority": protocol["decisionRules"][
            "successAuthority" if result["decisionBoundary"] == 1
            else "futilityAuthority" if result["decisionBoundary"] == 2
            else "inconclusiveAuthority"
        ],
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    summary_sha, _ = core.cache_json(summary)
    core.record(db, "analysis", f"post-v38-heldout:summary:{protocol_sha}", {
        **summary, "summarySha256": summary_sha,
    })
    print(core.canonical({**summary, "summarySha256": summary_sha}))


def record_inconclusive(error: Exception) -> None:
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    with core.open_ledger() as db:
        observations = protocol_observation_count(db, protocol_sha)
    summary = {
        "schemaVersion": 1,
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
        raise RuntimeError("refusing to overwrite an existing held-out summary") from error
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical(summary))


def validate_design() -> None:
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    identity = verify_entry(protocol, protocol_sha)
    baseline = cohort_rows(protocol, "baseline")
    candidate = cohort_rows(protocol, "candidate")
    validate_rectangle(protocol, baseline)
    validate_rectangle(protocol, candidate)
    if len(baseline) + len(candidate) \
            != int(protocol["budget"]["maximumNewSimulatorObservationRows"]):
        raise AssertionError("held-out row arithmetic drifted")
    synthetic_baseline: list[dict[str, Any]] = []
    synthetic_candidate: list[dict[str, Any]] = []
    for source, target in ((baseline, synthetic_baseline), (candidate, synthetic_candidate)):
        for row in source:
            item = {**row, "outcome": "loss", "error": "", "fights": [{"turns": 1}],
                    "deckIds": [], "packageEvents": {}}
            if row["arm"] == "policy":
                item["policy"] = {"heldOutIndex": int(row["policyIndex"])}
            target.append(item)
    for row in synthetic_candidate:
        if row["arm"] != "policy":
            continue
        index = int(row["policyIndex"])
        aspect = str(row["aspect"])
        names = sorted(name for name, spec in protocol["packages"].items()
                       if spec["aspect"] == aspect)
        for offset, name in enumerate(names):
            if offset * 32 <= index < offset * 32 + 64:
                spec = protocol["packages"][name]
                row["deckIds"].extend([spec["producer"], spec["consumer"]])
                row["packageEvents"].update({
                    spec["appliedMetric"]: 1, spec["consumedMetric"]: 1,
                })
    synthetic = analyse(protocol, synthetic_candidate, synthetic_baseline, set())
    if synthetic["decision"] != "confirm-one-frozen-candidate":
        raise AssertionError("held-out positive decision self-check failed")
    with core.open_ledger() as db:
        first_look = first_look_policy_hashes(db, protocol)
    print(core.canonical({
        "status": "PASS",
        "protocolSha256": protocol_sha,
        "runnerSha256": identity["runnerSha256"],
        "rowsPerContentArm": len(candidate),
        "maximumRows": len(candidate) + len(baseline),
        "firstLookPolicySnapshots": len(first_look),
    }))


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
