#!/usr/bin/env python3
"""Current-main CRN whole-run admission of the exact #525 ward package."""

from __future__ import annotations

import argparse
import json
import sqlite3
import statistics
import subprocess
import tempfile
import time
from pathlib import Path
from typing import Any

import post_v38_blocked_crn as blocked
import post_v38_heldout_confirmation as whole
import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-ward-whole-run-discovery-v1.json"
MANIFEST = core.ROOT / "execution/post-v38-ward-whole-run-discovery-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-ward-whole-run-discovery-v1.json"
GODOT = core.ROOT / "toolchains/godot-4.7.1/godot"


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
        "combatRulesSha256": core.file_sha(core.SOURCE / "domain/rules/combat.gd"),
        "balancePolicySha256": core.file_sha(core.SOURCE / "tools/balance_policy.gd"),
        "pilotSha256": core.file_sha(core.SOURCE / "tools/balance_pilot.gd"),
        "balanceSimSha256": core.file_sha(core.SOURCE / "tools/balance_sim.gd"),
        "probeSha256": core.file_sha(core.SOURCE / "tools/research_421_probe.gd"),
        "researchCoreSha256": core.file_sha(core.ROOT / "research.py"),
        "wholeRunAnalysisRunnerSha256": core.file_sha(
            core.ROOT / "post_v38_heldout_confirmation.py"
        ),
        "blockedAnalysisRunnerSha256": core.file_sha(
            core.ROOT / "post_v38_blocked_crn.py"
        ),
        "runnerSha256": core.file_sha(Path(__file__)),
    }


def git_blob(commit: str, path: str) -> bytes:
    return subprocess.run(
        ["git", "show", f"{commit}:{path}"], cwd=core.SOURCE, check=True,
        capture_output=True,
    ).stdout


def verify_immutable_science(protocol: dict[str, Any]) -> None:
    evidence = protocol["immutableScientificEvidence"]
    issue525 = evidence["issue525"]
    blobs: dict[str, bytes] = {}
    for name, spec in issue525["blobs"].items():
        blob = git_blob(issue525["commit"], spec["path"])
        if core.sha(blob) != spec["sha256"]:
            raise RuntimeError(f"immutable #525 blob drifted: {name}")
        blobs[name] = blob
    validation = json.loads(blobs["level2Validation"])
    matches = [
        row for row in validation["results"]
        if row.get("id") == issue525["candidateId"]
    ]
    if len(matches) != 1 or matches[0].get("admittedAtProbePanelGate") is not True:
        raise RuntimeError("exact #525 ward candidate is not probe/panel admitted")
    result = matches[0]
    if any(
        panel.get("packagePass") is not True or panel.get("panelPass") is not True
        for panel in result["panels"].values()
    ) or any(edge.get("pass") is not True for edge in result["edges"].values()):
        raise RuntimeError("exact #525 ward package or edge evidence drifted")

    for name in ("scorelineComplementarity", "engineIdentity"):
        spec = evidence[name]
        path = core.ROOT / spec["path"]
        if not path.is_file() or core.file_sha(path) != spec["sha256"]:
            raise RuntimeError(f"immutable entry evidence drifted: {name}")
        payload = json.loads(path.read_text())
        if payload.get("decision") != spec["decision"]:
            raise RuntimeError(f"immutable entry decision drifted: {name}")
    scoreline = json.loads(
        (core.ROOT / evidence["scorelineComplementarity"]["path"]).read_text()
    )
    if "dusk-scoreline" not in scoreline.get("clearPackages", {}):
        raise RuntimeError("Scoreline complementarity is not admitted evidence")
    engine = json.loads((core.ROOT / evidence["engineIdentity"]["path"]).read_text())
    if engine.get("engineAndLegacyAnchor", {}).get("normalisedRowsExact") is not True:
        raise RuntimeError("exact 4.7.1 legacy replay is not exact")


def verify_candidate(protocol: dict[str, Any]) -> str:
    candidate = protocol["candidate"]
    path = Path(candidate["sourcePath"])
    if not path.is_file() or core.file_sha(path) != candidate["contentSha256"]:
        raise RuntimeError("exact ward candidate source is missing or corrupt")
    content = json.loads(path.read_text())
    card = content.get("cards", {}).get("mirrorEdge")
    if card != candidate["mirrorEdgeDefinition"]:
        raise RuntimeError("mirrorEdge definition drifted from preregistration")
    if "mirrorEdge" not in content.get("cardPools", {}).get("common", []):
        raise RuntimeError("mirrorEdge is absent from the common reward pool")
    digest, cached = core.cache_bytes(path.read_bytes(), "json")
    if digest != candidate["contentSha256"] or core.file_sha(cached) != digest:
        raise RuntimeError("candidate content-addressed cache failed")
    live = core.CACHE / f"{protocol['baseline']['contentSha256']}.json"
    if not live.is_file() or core.file_sha(live) != protocol["baseline"]["contentSha256"]:
        raise RuntimeError("current-main baseline cache is missing or corrupt")
    return str(cached)


def zero_row_content_check(protocol: dict[str, Any], protocol_sha: str) -> None:
    for arm, content_sha in (
        ("baseline", protocol["baseline"]["contentSha256"]),
        ("candidate", protocol["candidate"]["contentSha256"]),
    ):
        plan = {
            "schemaVersion": 1,
            "protocolSha256": protocol_sha,
            "content": str(core.CACHE / f"{content_sha}.json"),
            "rows": [],
        }
        _, plan_path = core.cache_json(plan)
        with tempfile.TemporaryDirectory(prefix=f"issue-421-ward-{arm}-") as tmp:
            output = Path(tmp) / "output.json"
            result = subprocess.run(
                [str(GODOT), "--headless", "-s",
                 "res://tools/research_421_probe.gd", "--",
                 f"--plan={plan_path}", f"--out={output}"],
                cwd=core.SOURCE, text=True, capture_output=True, timeout=180,
            )
            if result.returncode or not output.is_file():
                raise RuntimeError(
                    f"zero-row {arm} content check failed ({result.returncode})\n"
                    f"{result.stdout[-2000:]}\n{result.stderr[-4000:]}"
                )
            payload = json.loads(output.read_text())
            if payload.get("rows") != []:
                raise RuntimeError(f"zero-row {arm} check produced observations")


def protocol_observation_count(db: Any, protocol_sha: str) -> int:
    return int(db.execute(
        "SELECT COUNT(*) FROM records WHERE kind = 'observation' AND identity LIKE ?",
        (f"{protocol_sha}:%",),
    ).fetchone()[0])


def verify_unused_identities(protocol: dict[str, Any]) -> None:
    root = int(protocol["cohorts"]["policyIdentity"]["root"])
    first = int(protocol["cohorts"]["randomBuildSeeds"]["first"])
    last = int(protocol["cohorts"]["policySimulationSeeds"]["last"])
    with sqlite3.connect(f"file:{core.LEDGER}?mode=ro", uri=True) as db:
        root_rows = int(db.execute(
            "SELECT COUNT(*) FROM records WHERE kind = 'observation' "
            "AND json_extract(payload_json, '$.policyRoot') = ?", (root,),
        ).fetchone()[0])
        seed_rows = int(db.execute(
            "SELECT COUNT(*) FROM records WHERE kind = 'observation' "
            "AND CAST(json_extract(payload_json, '$.seed') AS INTEGER) BETWEEN ? AND ?",
            (first, last),
        ).fetchone()[0])
    if root_rows or seed_rows:
        raise RuntimeError("preregistered policy root or simulation seed was already used")


def verify_entry(protocol: dict[str, Any], protocol_sha: str,
                 run_zero_row_check: bool) -> dict[str, Any]:
    actual = source_identity()
    for key, expected in protocol["immutableInputs"].items():
        if actual.get(key) != expected:
            raise RuntimeError(
                f"immutable input drift: {key} expected {expected} got {actual.get(key)}"
            )
    verify_immutable_science(protocol)
    candidate_cache = verify_candidate(protocol)
    ledger = identity.ledger_identity()
    if ledger != protocol["ledgerFreeze"]:
        raise RuntimeError("ledger drifted before the first ward discovery row")
    verify_unused_identities(protocol)
    if not MANIFEST.is_file():
        raise RuntimeError("execution manifest is missing")
    manifest = json.loads(MANIFEST.read_text())
    required = {
        "protocolSha256": protocol_sha,
        "runnerSha256": actual["runnerSha256"],
        "godotBinarySha256": actual["godotBinarySha256"],
        "candidateContentSha256": protocol["candidate"]["contentSha256"],
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
    if run_zero_row_check:
        zero_row_content_check(protocol, protocol_sha)
    return {
        **actual,
        "candidateCachePath": candidate_cache,
        "executionManifestSha256": core.file_sha(MANIFEST),
    }


def cohort_rows(protocol: dict[str, Any], arm: str) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    random_seeds = protocol["cohorts"]["randomBuildSeeds"]
    for aspect in ("duskblade", "ashwarden"):
        for vow in (0, 5):
            for seed in range(int(random_seeds["first"]), int(random_seeds["last"]) + 1):
                rows.append({
                    "id": f"ward-discovery-random-{arm}-{aspect}-v{vow}-{seed}",
                    "stage": "post-v38-ward-whole-run-discovery",
                    "arm": "random",
                    "mode": "whole-run",
                    "aspect": aspect,
                    "vow": vow,
                    "seed": seed,
                    "randomBuild": True,
                    "randomPlay": False,
                    "research421": {},
                })
    policy = protocol["cohorts"]["policyIdentity"]
    policy_seeds = protocol["cohorts"]["policySimulationSeeds"]
    for aspect in ("duskblade", "ashwarden"):
        for index in range(int(policy["firstIndex"]), int(policy["lastIndex"]) + 1):
            for seed in range(
                int(policy_seeds["first"]), int(policy_seeds["last"]) + 1
            ):
                rows.append({
                    "id": f"ward-discovery-policy-{arm}-{aspect}-{index}-{seed}",
                    "stage": "post-v38-ward-whole-run-discovery",
                    "arm": "policy",
                    "mode": "whole-run",
                    "aspect": aspect,
                    "vow": 5,
                    "seed": seed,
                    "policyRoot": int(policy["root"]),
                    "policyIndex": index,
                    "research421": {},
                })
    expected = int(protocol["budget"]["rowsPerContentArm"])
    if len(rows) != expected or len({row["id"] for row in rows}) != expected:
        raise ValueError(f"{arm} CRN rectangle is incomplete or duplicated")
    if any(3000 <= int(row["seed"]) <= 5399 for row in rows):
        raise ValueError("protected seed entered ward discovery")
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


def run_plan(db: Any, protocol_sha: str, plan: dict[str, Any], timeout: int) \
        -> dict[str, Any]:
    plan_sha, plan_path = core.cache_json(plan)
    core.record(db, "plan", plan_sha, plan)
    run_identity = f"probe-471:{plan_sha}"
    prior = core.existing_record(db, run_identity)
    if prior is not None:
        output_path = core.CACHE / f"{prior['outputSha256']}.json"
        if not output_path.is_file() or core.file_sha(output_path) != prior["outputSha256"]:
            raise RuntimeError(f"missing or corrupt cached output {prior['outputSha256']}")
        output = json.loads(output_path.read_text())
    else:
        with tempfile.TemporaryDirectory(prefix="issue-421-ward-run-") as tmp:
            raw_path = Path(tmp) / "output.json"
            result = subprocess.run(
                [str(GODOT), "--headless", "-s",
                 "res://tools/research_421_probe.gd", "--",
                 f"--plan={plan_path}", f"--out={raw_path}"],
                cwd=core.SOURCE, text=True, capture_output=True, timeout=timeout,
            )
            if result.returncode or not raw_path.is_file():
                raise RuntimeError(
                    f"probe failed ({result.returncode})\n"
                    f"{result.stdout[-2000:]}\n{result.stderr[-4000:]}"
                )
            output = json.loads(raw_path.read_text())
        output_sha, _ = core.cache_json(output)
        core.record(db, "probe-run", run_identity, {
            "planSha256": plan_sha,
            "outputSha256": output_sha,
            "protocolSha256": protocol_sha,
            "probeSha256": core.file_sha(core.SOURCE / "tools/research_421_probe.gd"),
            "godotBinarySha256": core.file_sha(GODOT),
            "rowCount": len(output["rows"]),
        })
    for row in output["rows"]:
        core.record(db, "observation", f"{protocol_sha}:{plan_sha}:{row['id']}", row)
    return output


def prior_policy_hashes(protocol: dict[str, Any]) -> set[str]:
    hashes: set[str] = set()
    with sqlite3.connect(f"file:{core.LEDGER}?mode=ro", uri=True) as db:
        for cohort in protocol["excludedPolicyCohorts"]:
            rows = db.execute(
                "SELECT payload_json FROM records WHERE kind = 'observation' "
                "AND identity LIKE ? AND json_extract(payload_json, '$.policyRoot') = ?",
                (f"{cohort['protocolSha256']}:%", int(cohort["root"])),
            ).fetchall()
            found = {
                core.sha(core.canonical(json.loads(payload)["policy"]).encode())
                for (payload,) in rows
            }
            if len(found) != int(cohort["count"]):
                raise RuntimeError(f"excluded policy cohort root {cohort['root']} is incomplete")
            hashes.update(found)
    return hashes


def policy_identity_audit(
    protocol: dict[str, Any], candidate: dict[Any, dict[str, Any]],
    baseline: dict[Any, dict[str, Any]], excluded: set[str],
) -> dict[str, Any]:
    if set(candidate) != set(baseline):
        raise ValueError("candidate and baseline policy rectangles differ")
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
    snapshots = {next(iter(values)) for values in by_index.values() if len(values) == 1}
    overlap = snapshots & excluded
    return {
        "policyIdentities": len(by_index),
        "uniqueSnapshots": len(snapshots),
        "oneSnapshotPerIdentityAcrossArmsAspectsAndSeeds": exact,
        "excludedSnapshots": len(excluded),
        "excludedOverlapCount": len(overlap),
        "clear": exact and len(snapshots) == expected and not overlap,
    }


def scoreline_active(row: dict[str, Any]) -> bool:
    deck = set(map(str, row.get("deckIds", [])))
    events = row.get("packageEvents") or {}
    return {"chisel", "executioner"}.issubset(deck) \
        and int(events.get("scorelineApplied", 0)) > 0 \
        and int(events.get("scorelineConsumed", 0)) > 0


def ward_active(row: dict[str, Any], producer: str) -> bool:
    deck = set(map(str, row.get("deckIds", [])))
    events = row.get("packageEvents") or {}
    return {producer, "fortify"}.issubset(deck) \
        and int(events.get(f"{producer}Played", 0)) > 0 \
        and int(events.get("fortifyPlayed", 0)) > 0 \
        and int(events.get("wardDoubledByFortify", 0)) > 0


def support_sets(protocol: dict[str, Any], rows: dict[Any, dict[str, Any]]) \
        -> dict[str, set[int]]:
    indices = range(
        int(protocol["cohorts"]["policyIdentity"]["firstIndex"]),
        int(protocol["cohorts"]["policyIdentity"]["lastIndex"]) + 1,
    )
    by_index = {
        index: [row for (aspect, found, _), row in rows.items()
                if aspect == "duskblade" and found == index]
        for index in indices
    }
    found: dict[str, set[int]] = {
        "scorelineActive": set(),
        "scorelineReachable": set(),
        "scorelineConsumed": set(),
        "braceActive": set(),
        "braceReachable": set(),
        "mirrorEdgeActive": set(),
        "mirrorEdgeReachable": set(),
        "wardActive": set(),
        "wardReachable": set(),
        "wardConsumed": set(),
        "mirrorEdgeOffered": set(),
    }
    for index, policy_rows in by_index.items():
        for row in policy_rows:
            deck = set(map(str, row.get("deckIds", [])))
            events = row.get("packageEvents") or {}
            if {"chisel", "executioner"}.issubset(deck):
                found["scorelineReachable"].add(index)
                if int(events.get("scorelineConsumed", 0)) > 0:
                    found["scorelineConsumed"].add(index)
            if scoreline_active(row):
                found["scorelineActive"].add(index)
            for producer in ("brace", "mirrorEdge"):
                if {producer, "fortify"}.issubset(deck):
                    found[f"{producer}Reachable"].add(index)
                    found["wardReachable"].add(index)
                if ward_active(row, producer):
                    found[f"{producer}Active"].add(index)
                    found["wardActive"].add(index)
                    found["wardConsumed"].add(index)
            if int(events.get("mirrorEdgeOffered", 0)) > 0:
                found["mirrorEdgeOffered"].add(index)
    return found


def package_gate(protocol: dict[str, Any], candidate: dict[Any, dict[str, Any]]) \
        -> tuple[dict[str, Any], dict[str, set[int]]]:
    sets = support_sets(protocol, candidate)
    count = int(protocol["cohorts"]["policyIdentity"]["count"])
    sensitivity = int(protocol["gates"]["minimumActiveAndInactivePolicies"])
    reachability = int(protocol["gates"]["minimumReachablePolicies"])
    exclusive = int(protocol["gates"]["minimumExclusivePolicies"])
    edge_reachability = int(protocol["gates"]["minimumWardEdgeReachablePolicies"])

    def package(name: str, active_key: str, reachable_key: str,
                consumed_key: str) -> dict[str, Any]:
        active = len(sets[active_key])
        return {
            "active": active,
            "inactive": count - active,
            "finalPairReachable": len(sets[reachable_key]),
            "consumerReachedWithFinalPair": len(sets[consumed_key]),
            "sensitivityClear": active >= sensitivity and count - active >= sensitivity,
            "reachabilityClear": len(sets[reachable_key]) >= reachability
            and len(sets[consumed_key]) >= reachability,
            "name": name,
        }

    scoreline = package(
        "dusk-scoreline", "scorelineActive", "scorelineReachable", "scorelineConsumed"
    )
    ward = package(
        "dusk-ward-mirror-edge", "wardActive", "wardReachable", "wardConsumed"
    )
    edge_results = {
        producer: {
            "active": len(sets[f"{producer}Active"]),
            "finalPairReachable": len(sets[f"{producer}Reachable"]),
            "clear": len(sets[f"{producer}Active"]) >= edge_reachability
            and len(sets[f"{producer}Reachable"]) >= edge_reachability,
        } for producer in ("brace", "mirrorEdge")
    }
    separation = {
        "scorelineOnly": len(sets["scorelineActive"] - sets["wardActive"]),
        "wardOnly": len(sets["wardActive"] - sets["scorelineActive"]),
        "crossActive": len(sets["scorelineActive"] & sets["wardActive"]),
    }
    separation["clear"] = separation["scorelineOnly"] >= exclusive \
        and separation["wardOnly"] >= exclusive
    clear = scoreline["sensitivityClear"] and scoreline["reachabilityClear"] \
        and ward["sensitivityClear"] and ward["reachabilityClear"] \
        and all(result["clear"] for result in edge_results.values()) \
        and separation["clear"]
    return ({
        "packages": {"dusk-scoreline": scoreline, "dusk-ward-mirror-edge": ward},
        "wardEdges": edge_results,
        "functionalSeparation": separation,
        "mirrorEdgeOfferedPolicies": len(sets["mirrorEdgeOffered"]),
        "clear": clear,
    }, sets)


def activation_impact(protocol: dict[str, Any], candidate: dict[str, set[int]],
                      baseline: dict[str, set[int]]) -> dict[str, Any]:
    indices = range(
        int(protocol["cohorts"]["policyIdentity"]["firstIndex"]),
        int(protocol["cohorts"]["policyIdentity"]["lastIndex"]) + 1,
    )
    result: dict[str, Any] = {}
    for name, key in (("scorelineAnchor", "scorelineActive"),
                      ("wardPackage", "wardActive")):
        deltas = [float(index in candidate[key]) - float(index in baseline[key])
                  for index in indices]
        result[name] = {
            "candidateActive": len(candidate[key]),
            "baselineActive": len(baseline[key]),
            "gainedPolicies": len(candidate[key] - baseline[key]),
            "lostPolicies": len(baseline[key] - candidate[key]),
            "candidateMinusBaseline": blocked.signed_interval(
                deltas, 1.0, int(protocol["budget"]["bootstrapResamples"])
            ),
        }
    threshold = float(protocol["gates"]["maximumAbsoluteScorelineAnchorMovement"])
    anchor = result["scorelineAnchor"]["candidateMinusBaseline"]
    result["scorelineAnchor"]["clear"] = abs(anchor["point"]) <= threshold
    result["scorelineAnchor"]["decisiveFailure"] = anchor["p025"] > threshold \
        or anchor["p975"] < -threshold
    return result


def analyse(protocol: dict[str, Any], candidate_rows: list[dict[str, Any]],
            baseline_rows: list[dict[str, Any]], excluded: set[str]) -> dict[str, Any]:
    whole.validate_rectangle(protocol, candidate_rows)
    whole.validate_rectangle(protocol, baseline_rows)
    candidate_random, candidate_policy = whole.split_rows(candidate_rows)
    baseline_random, baseline_policy = whole.split_rows(baseline_rows)
    policies = policy_identity_audit(
        protocol, candidate_policy, baseline_policy, excluded
    )
    packages, candidate_sets = package_gate(protocol, candidate_policy)
    baseline_sets = support_sets(protocol, baseline_policy)
    impact = activation_impact(protocol, candidate_sets, baseline_sets)
    safety = whole.safety_gate(
        protocol, candidate_random, candidate_policy, baseline_random, baseline_policy
    )

    fixed_success = policies["clear"] and packages["clear"] \
        and impact["scorelineAnchor"]["clear"] \
        and safety["randomBuildClear"] and safety["policyFixedClear"]
    if fixed_success and safety["durationClear"]:
        boundary, decision = 1, "freeze-exact-ward-candidate-for-heldout-confirmation"
    else:
        hard_candidate_failure = not packages["clear"] or not safety["policyFixedClear"]
        movement_limit = float(protocol["gates"]["maximumAbsoluteRandomBuildMovement"])
        hard_random_failure = any(
            result["winRate"] >= float(protocol["gates"]["randomBuildWinCeiling"])
            or result["addedFaults"] > 0
            or result["candidateMinusLive"]["p025"] > movement_limit
            or result["candidateMinusLive"]["p975"] < -movement_limit
            for result in safety["randomBuild"].values()
        )
        duration_limit = float(protocol["gates"]["durationUpperBound"])
        decisively_slow = any(
            result["durationCandidateMinusLive"] is not None
            and result["durationCandidateMinusLive"]["p025"] > duration_limit
            for result in safety["policy"].values()
        )
        if hard_candidate_failure or hard_random_failure \
                or impact["scorelineAnchor"]["decisiveFailure"] or decisively_slow:
            boundary, decision = 2, "reject-exact-ward-candidate-close-tested-direction"
        else:
            boundary, decision = 3, "inconclusive-at-preregistered-cap"
    return {
        "schemaVersion": 1,
        "decisionBoundary": boundary,
        "decision": decision,
        "policyIdentityAudit": policies,
        "strategyPackageActivation": packages,
        "activationImpact": impact,
        "guardrails": safety,
    }


def synthetic_rows(protocol: dict[str, Any], arm: str) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for spec in cohort_rows(protocol, arm):
        row = {
            **spec,
            "outcome": "loss",
            "error": "",
            "fights": [{"turns": 1}],
            "deckIds": [],
            "packageEvents": {},
        }
        if spec["arm"] == "policy":
            index = int(spec["policyIndex"])
            row["policy"] = {"syntheticPolicyIndex": index}
            if index < 32:
                row["deckIds"].extend(["chisel", "executioner"])
                row["packageEvents"].update({
                    "scorelineApplied": 1, "scorelineConsumed": 1,
                })
            if arm == "candidate" and 16 <= index < 48:
                producer = "brace" if index < 32 else "mirrorEdge"
                row["deckIds"].extend([producer, "fortify"])
                row["packageEvents"].update({
                    f"{producer}Played": 1,
                    "fortifyPlayed": 1,
                    "wardDoubledByFortify": 1,
                    "mirrorEdgeOffered": 1 if producer == "mirrorEdge" else 0,
                })
            elif arm == "baseline" and 16 <= index < 32:
                row["deckIds"].extend(["brace", "fortify"])
                row["packageEvents"].update({
                    "bracePlayed": 1, "fortifyPlayed": 1,
                    "wardDoubledByFortify": 1,
                })
        rows.append(row)
    return rows


def validate_design() -> None:
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    source = verify_entry(protocol, protocol_sha, True)
    baseline = cohort_rows(protocol, "baseline")
    candidate = cohort_rows(protocol, "candidate")
    whole.validate_rectangle(protocol, baseline)
    whole.validate_rectangle(protocol, candidate)
    if len(baseline) + len(candidate) \
            != int(protocol["budget"]["maximumNewSimulatorObservationRows"]):
        raise AssertionError("ward discovery row arithmetic drifted")
    synthetic_baseline = synthetic_rows(protocol, "baseline")
    synthetic_candidate = synthetic_rows(protocol, "candidate")
    positive = analyse(protocol, synthetic_candidate, synthetic_baseline, set())
    if positive["decisionBoundary"] != 1:
        raise AssertionError("positive ward decision self-check failed")
    for row in synthetic_candidate:
        if row.get("arm") == "policy" and int(row.get("policyIndex", -1)) >= 32:
            row["deckIds"] = [card for card in row["deckIds"] if card != "mirrorEdge"]
            row["packageEvents"].pop("mirrorEdgePlayed", None)
            row["packageEvents"].pop("wardDoubledByFortify", None)
    negative = analyse(protocol, synthetic_candidate, synthetic_baseline, set())
    if negative["decisionBoundary"] != 2:
        raise AssertionError("negative ward decision self-check failed")
    print(core.canonical({
        "status": "PASS",
        "protocolSha256": protocol_sha,
        "runnerSha256": source["runnerSha256"],
        "rowsPerContentArm": len(candidate),
        "maximumRows": len(candidate) + len(baseline),
        "zeroRowContentChecks": 2,
    }))


def finish(protocol: dict[str, Any], protocol_sha: str, source: dict[str, Any],
           db: Any, started: float, result: dict[str, Any], observations: int) -> None:
    analysis = {
        **result,
        "protocolSha256": protocol_sha,
        "runnerSha256": source["runnerSha256"],
        "newSimulatorObservationRows": observations,
        "protectedSeedRows": 0,
    }
    analysis_sha, _ = core.cache_json(analysis)
    core.record(db, "analysis", f"post-v38-ward-discovery:analysis:{protocol_sha}", {
        **analysis, "analysisSha256": analysis_sha,
    })
    boundary = int(result["decisionBoundary"])
    summary = {
        "schemaVersion": 1,
        "decisionBoundary": boundary,
        "decision": result["decision"],
        "protocolSha256": protocol_sha,
        "runnerSha256": source["runnerSha256"],
        "executionManifestSha256": source["executionManifestSha256"],
        "analysisSha256": analysis_sha,
        "candidate": protocol["candidate"],
        "newSimulatorObservationRows": observations,
        "protectedSeedRows": 0,
        "wallTimeSeconds": time.monotonic() - started,
        "authority": protocol["decisionRules"][
            "successAuthority" if boundary == 1
            else "futilityAuthority" if boundary == 2
            else "inconclusiveAuthority"
        ],
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    summary_sha, _ = core.cache_json(summary)
    core.record(db, "analysis", f"post-v38-ward-discovery:summary:{protocol_sha}", {
        **summary, "summarySha256": summary_sha,
    })
    print(core.canonical({**summary, "summarySha256": summary_sha}))


def execute() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to rerun completed ward discovery")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    source = verify_entry(protocol, protocol_sha, False)
    started = time.monotonic()
    db = core.open_ledger()
    core.record(db, "protocol", protocol_sha, protocol)
    core.record(db, "source-identity", core.sha(core.canonical(source).encode()), source)
    excluded = prior_policy_hashes(protocol)
    outputs: dict[str, list[dict[str, Any]]] = {}
    timeout = int(protocol["budget"]["maximumWallTimeSeconds"])
    for arm in ("baseline", "candidate"):
        content_sha = protocol[arm]["contentSha256"]
        output = run_plan(
            db, protocol_sha,
            plan_for(protocol_sha, content_sha, cohort_rows(protocol, arm)),
            timeout,
        )
        whole.validate_rectangle(protocol, output["rows"])
        outputs[arm] = output["rows"]
        observed = protocol_observation_count(db, protocol_sha)
        if observed > int(protocol["budget"]["maximumNewSimulatorObservationRows"]):
            raise RuntimeError("ward discovery observation cap exceeded")
        if time.monotonic() - started > timeout:
            raise TimeoutError("ward discovery wall-time cap reached")
        print(core.canonical({"stage": "ward-discovery", "arm": arm,
                              "protocolObservationRows": observed}), flush=True)
    observed = protocol_observation_count(db, protocol_sha)
    if observed != int(protocol["budget"]["maximumNewSimulatorObservationRows"]):
        raise RuntimeError("ward discovery final rectangle missed its frozen budget")
    result = analyse(protocol, outputs["candidate"], outputs["baseline"], excluded)
    finish(protocol, protocol_sha, source, db, started, result, observed)


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
        "authority": "Do not rerun, extend or repair this protocol.",
    }
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite an existing ward summary") from error
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical(summary))


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
