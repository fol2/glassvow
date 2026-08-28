#!/usr/bin/env python3
"""Independent local and whole-run confirmation of issue #421 package order."""

from __future__ import annotations

import argparse
import json
import sqlite3
import subprocess
import time
from pathlib import Path
from typing import Any

import post_v38_exact_complementarity as exact
import post_v38_heldout_confirmation as whole
import post_v38_knob_identity as identity
import post_v38_package_order_discovery as discovery
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-package-order-heldout-v1.json"
MANIFEST = core.ROOT / "execution/post-v38-package-order-heldout-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-package-order-heldout-v1.json"


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
        "discoveryRunnerSha256": core.file_sha(
            core.ROOT / "post_v38_package_order_discovery.py"
        ),
        "localAnalysisRunnerSha256": core.file_sha(
            core.ROOT / "post_v38_exact_complementarity.py"
        ),
        "wholeRunAnalysisRunnerSha256": core.file_sha(
            core.ROOT / "post_v38_heldout_confirmation.py"
        ),
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
    for name, gate in protocol["entryGates"].items():
        path = core.ROOT / gate["path"]
        if not path.is_file() or core.file_sha(path) != gate["sha256"]:
            raise RuntimeError(f"entry gate drifted: {name}")
        loaded = json.loads(path.read_text())
        if loaded.get("decision") != gate["decision"]:
            raise RuntimeError(f"entry gate decision drifted: {name}")
    for arm, spec in protocol["wholeRunArms"].items():
        content_sha = spec["contentSha256"]
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
        "discoveryAuditSha256": protocol["entryGates"]["discoveryAudit"]["sha256"],
        "ledgerSha256BeforeFirstObservation": protocol["ledgerFreeze"]["sha256"],
        "ledgerRecordsBeforeFirstObservation": protocol["ledgerFreeze"]["records"],
        "localSimulatorObservationRows": protocol["budget"][
            "localSimulatorObservationRows"
        ],
        "wholeRunSimulatorObservationRows": protocol["budget"][
            "wholeRunSimulatorObservationRows"
        ],
        "maximumSimulatorObservationRows": protocol["budget"][
            "maximumNewSimulatorObservationRows"
        ],
        "maximumWallTimeSeconds": protocol["budget"]["maximumWallTimeSeconds"],
        "maximumModelContextTokensDuringExecutionAndDecision": 0,
    }
    for key, expected in required.items():
        if manifest.get(key) != expected:
            raise RuntimeError(f"execution manifest drifted at {key}")
    ledger = identity.ledger_identity()
    if ledger != protocol["ledgerFreeze"]:
        with core.open_ledger() as db:
            if core.existing_record(db, protocol_sha) is None:
                raise RuntimeError("ledger changed before the first held-out row")
    return {**actual, "executionManifestSha256": core.file_sha(MANIFEST)}


def local_panel_rows(
    protocol: dict[str, Any], package: str, order: int
) -> list[dict[str, Any]]:
    rows = discovery.panel_rows(protocol, package, order, core.ARMS)
    for row in rows:
        row["id"] = row["id"].replace("package-order-discovery", "package-order-heldout")
        row["stage"] = "post-v38-package-order-heldout-local"
        row["split"] = "heldout"
        row["context"] = row["context"].replace("fixed-substrate", "heldout-substrate")
    return rows


def local_rows(protocol: dict[str, Any]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for package in sorted(protocol["packages"]):
        rows.extend(local_panel_rows(protocol, package, 1))
    rows.extend(local_panel_rows(protocol, discovery.AFTERIMAGE, 0))
    expected = int(protocol["budget"]["localSimulatorObservationRows"])
    if len(rows) != expected or len({row["id"] for row in rows}) != expected:
        raise ValueError("held-out local rectangle is incomplete or duplicated")
    return rows


def local_cells(rows: list[dict[str, Any]], package: str, order: int) \
        -> list[dict[str, Any]]:
    marker = f"package-order-{order}"
    return [row for row in rows if row["package"] == package and marker in row["context"]]


def analyse_local(protocol: dict[str, Any], rows: list[dict[str, Any]]) -> dict[str, Any]:
    packages = {
        package: exact.package_result(
            protocol, package, local_cells(rows, package, 1)
        ) for package in sorted(protocol["packages"])
    }
    after_off = exact.package_result(
        protocol, discovery.AFTERIMAGE,
        local_cells(rows, discovery.AFTERIMAGE, 0),
    )
    gain = discovery.structural_gain(
        protocol, discovery.AFTERIMAGE,
        local_cells(rows, discovery.AFTERIMAGE, 0),
        local_cells(rows, discovery.AFTERIMAGE, 1),
    )
    admitted = {name for name, result in packages.items() if result["clear"]}
    required = set(protocol["admissionSet"]["requiredDuskPackages"])
    ash = set(protocol["admissionSet"]["supplementalAshPackages"])
    enough = required <= admitted and len(admitted & ash) >= int(
        protocol["admissionSet"]["minimumSupplementalAshPackages"]
    )
    if enough and gain["p025"] > 0:
        boundary, decision = 1, "continue-to-whole-run-heldout"
    else:
        required_failure = any(packages[name]["decisiveFailure"] for name in required)
        ash_failures = sum(packages[name]["decisiveFailure"] for name in ash)
        too_many_ash_failures = ash_failures > len(ash) \
            - int(protocol["admissionSet"]["minimumSupplementalAshPackages"])
        if required_failure or too_many_ash_failures or gain["p975"] <= 0:
            boundary, decision = 2, "reject-structural-candidate-close-package-order"
        else:
            boundary, decision = 3, "inconclusive-at-preregistered-local-cap"
    return {
        "decisionBoundary": boundary,
        "decision": decision,
        "packagesAtOrderOn": packages,
        "afterimageAtOrderOff": after_off,
        "afterimageStructuralGain": gain,
    }


def whole_rows(protocol: dict[str, Any], arm: str) -> list[dict[str, Any]]:
    settings = protocol["wholeRunArms"][arm]["research421"]
    random_seeds = protocol["cohorts"]["randomBuildSeeds"]
    rows = [{
        "id": f"package-order-heldout-random-{arm}-{aspect}-v{vow}-{seed}",
        "stage": "post-v38-package-order-heldout-whole",
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
        "id": f"package-order-heldout-policy-{arm}-{aspect}-{index}-{seed}",
        "stage": "post-v38-package-order-heldout-whole",
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
    expected = int(protocol["budget"]["wholeRunRowsPerArm"])
    if len(rows) != expected or len({row["id"] for row in rows}) != expected:
        raise ValueError(f"{arm} whole-run rectangle is incomplete or duplicated")
    if any(3000 <= int(row["seed"]) <= 5399 for row in rows):
        raise ValueError("protected seed entered whole-run held-out")
    return rows


def plan_for(protocol: dict[str, Any], protocol_sha: str, content_sha: str,
             rows: list[dict[str, Any]]) -> dict[str, Any]:
    return {
        "schemaVersion": 1,
        "protocolSha256": protocol_sha,
        "content": str(core.CACHE / f"{content_sha}.json"),
        "rows": rows,
    }


def excluded_policy_hashes(protocol: dict[str, Any]) -> set[str]:
    hashes: set[str] = set()
    with sqlite3.connect(f"file:{core.LEDGER}?mode=ro", uri=True) as db:
        for cohort in protocol["excludedWholeRunPolicyCohorts"]:
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
                raise RuntimeError("excluded policy cohort is incomplete")
            hashes.update(found)
    return hashes


def policy_identity_audit(
    protocol: dict[str, Any], policy_arms: dict[str, dict[Any, dict[str, Any]]],
    excluded: set[str],
) -> dict[str, Any]:
    keys = [set(rows) for rows in policy_arms.values()]
    if any(found != keys[0] for found in keys[1:]):
        raise ValueError("whole-run policy arms do not share one rectangle")
    by_index: dict[int, set[str]] = {}
    for rows in policy_arms.values():
        for (_, index, _), row in rows.items():
            by_index.setdefault(index, set()).add(
                core.sha(core.canonical(row["policy"]).encode())
            )
    expected = int(protocol["cohorts"]["policyIdentity"]["count"])
    heldout = {next(iter(values)) for values in by_index.values() if len(values) == 1}
    overlap = heldout & excluded
    clear = len(by_index) == expected and len(heldout) == expected \
        and all(len(values) == 1 for values in by_index.values()) and not overlap
    return {
        "policyIdentities": len(by_index),
        "uniqueHeldOutSnapshots": len(heldout),
        "excludedSnapshots": len(excluded),
        "excludedOverlapCount": len(overlap),
        "oneSnapshotPerIdentityAcrossAllArmsAspectsAndSeeds": all(
            len(values) == 1 for values in by_index.values()
        ),
        "clear": clear,
    }


def activation_sets(
    protocol: dict[str, Any], policy_rows: dict[Any, dict[str, Any]],
) -> dict[str, set[int]]:
    found: dict[str, set[int]] = {}
    for name, spec in protocol["packages"].items():
        aspect = str(spec["aspect"])
        found[name] = {
            index for index in range(
                int(protocol["cohorts"]["policyIdentity"]["firstIndex"]),
                int(protocol["cohorts"]["policyIdentity"]["lastIndex"]) + 1,
            ) if any(
                core._package_activation(row, spec) > 0
                for (row_aspect, row_index, _), row in policy_rows.items()
                if (row_aspect, row_index) == (aspect, index)
            )
        }
    return found


def analyse_whole(
    protocol: dict[str, Any], arms: dict[str, list[dict[str, Any]]],
    excluded: set[str],
) -> dict[str, Any]:
    split: dict[str, tuple[dict[Any, dict[str, Any]], dict[Any, dict[str, Any]]]] = {}
    for arm, rows in arms.items():
        whole.validate_rectangle(protocol, rows)
        split[arm] = whole.split_rows(rows)
    identities = policy_identity_audit(
        protocol, {arm: values[1] for arm, values in split.items()}, excluded
    )
    candidate_random, candidate_policy = split["structuralCandidate"]
    null_random, null_policy = split["structuralNull"]
    live_random, live_policy = split["liveBaseline"]
    packages = whole.package_gate(protocol, candidate_policy)
    live_safety = whole.safety_gate(
        protocol, candidate_random, candidate_policy, live_random, live_policy
    )
    null_safety = whole.safety_gate(
        protocol, candidate_random, candidate_policy, null_random, null_policy
    )
    candidate_active = activation_sets(protocol, candidate_policy)
    null_active = activation_sets(protocol, null_policy)
    impact = {
        name: {
            "candidateActive": len(candidate_active[name]),
            "nullActive": len(null_active[name]),
            "gainedPolicies": len(candidate_active[name] - null_active[name]),
            "lostPolicies": len(null_active[name] - candidate_active[name]),
        } for name in sorted(protocol["packages"])
    }
    fixed_clear = identities["clear"] and packages["clear"] \
        and live_safety["randomBuildClear"] and live_safety["policyFixedClear"] \
        and null_safety["randomBuildClear"] and null_safety["policyFixedClear"]
    duration_clear = live_safety["durationClear"] and null_safety["durationClear"]
    if fixed_clear and duration_clear:
        boundary, decision = 1, "admit-structural-package-set-for-detector-construction"
    elif not fixed_clear:
        boundary, decision = 2, "reject-structural-candidate-close-package-order"
    else:
        limit = float(protocol["gates"]["durationUpperBound"])
        decisively_slow = any(
            result["durationCandidateMinusLive"] is not None
            and result["durationCandidateMinusLive"]["p025"] > limit
            for safety in (live_safety, null_safety)
            for result in safety["policy"].values()
        )
        boundary = 2 if decisively_slow else 3
        decision = "reject-structural-candidate-close-package-order" \
            if decisively_slow else "inconclusive-at-preregistered-whole-run-cap"
    return {
        "decisionBoundary": boundary,
        "decision": decision,
        "policyIdentityAudit": identities,
        "strategyPackageActivation": packages,
        "structuralActivationImpact": impact,
        "candidateVersusLiveGuardrails": live_safety,
        "candidateVersusStructuralNullGuardrails": null_safety,
    }


def enforce_caps(protocol: dict[str, Any], protocol_sha: str, db: Any,
                 started: float) -> int:
    observed = protocol_observation_count(db, protocol_sha)
    if observed > int(protocol["budget"]["maximumNewSimulatorObservationRows"]):
        raise RuntimeError("held-out observation cap exceeded")
    if time.monotonic() - started > float(protocol["budget"]["maximumWallTimeSeconds"]):
        raise TimeoutError("held-out wall-time cap reached")
    return observed


def finish(
    protocol: dict[str, Any], protocol_sha: str, source: dict[str, Any],
    db: Any, started: float, local: dict[str, Any], whole_run: dict[str, Any] | None,
    observations: int,
) -> None:
    boundary = local["decisionBoundary"] if whole_run is None \
        else whole_run["decisionBoundary"]
    decision = local["decision"] if whole_run is None else whole_run["decision"]
    result = {
        "schemaVersion": 1,
        "decisionBoundary": boundary,
        "decision": decision,
        "protocolSha256": protocol_sha,
        "runnerSha256": source["runnerSha256"],
        "newSimulatorObservationRows": observations,
        "protectedSeedRows": 0,
        "localHeldout": local,
        "wholeRunHeldout": whole_run,
    }
    analysis_sha, _ = core.cache_json(result)
    core.record(db, "analysis", f"post-v38-package-order-heldout:analysis:{protocol_sha}", {
        **result, "analysisSha256": analysis_sha,
    })
    summary = {
        "schemaVersion": 1,
        "decisionBoundary": boundary,
        "decision": decision,
        "protocolSha256": protocol_sha,
        "runnerSha256": source["runnerSha256"],
        "executionManifestSha256": source["executionManifestSha256"],
        "analysisSha256": analysis_sha,
        "structuralCandidate": protocol["structuralCandidate"],
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
    core.record(db, "analysis", f"post-v38-package-order-heldout:summary:{protocol_sha}", {
        **summary, "summarySha256": summary_sha,
    })
    print(core.canonical({**summary, "summarySha256": summary_sha}))


def execute() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to rerun completed package-order held-out")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    source = verify_entry(protocol, protocol_sha)
    started = time.monotonic()
    db = core.open_ledger()
    core.record(db, "protocol", protocol_sha, protocol)
    core.record(db, "source-identity", core.sha(core.canonical(source).encode()), source)
    candidate_content = protocol["structuralCandidate"]["contentSha256"]
    local_output = core.run_plan(
        db, protocol_sha,
        plan_for(protocol, protocol_sha, candidate_content, local_rows(protocol)),
    )["rows"]
    observations = enforce_caps(protocol, protocol_sha, db, started)
    if observations != int(protocol["budget"]["localSimulatorObservationRows"]):
        raise RuntimeError("local held-out row boundary drifted")
    local = analyse_local(protocol, local_output)
    if local["decisionBoundary"] != 1:
        finish(protocol, protocol_sha, source, db, started, local, None, observations)
        return
    excluded = excluded_policy_hashes(protocol)
    arms: dict[str, list[dict[str, Any]]] = {}
    for arm in ("structuralCandidate", "structuralNull", "liveBaseline"):
        spec = protocol["wholeRunArms"][arm]
        arms[arm] = core.run_plan(
            db, protocol_sha,
            plan_for(protocol, protocol_sha, spec["contentSha256"], whole_rows(protocol, arm)),
        )["rows"]
        observations = enforce_caps(protocol, protocol_sha, db, started)
    if observations != int(protocol["budget"]["maximumNewSimulatorObservationRows"]):
        raise RuntimeError("whole-run held-out row boundary drifted")
    whole_run = analyse_whole(protocol, arms, excluded)
    finish(protocol, protocol_sha, source, db, started, local, whole_run, observations)


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
    source = verify_entry(protocol, protocol_sha)
    planned = local_rows(protocol)
    synthetic: list[dict[str, Any]] = []
    for row in planned:
        item = {**row, "outcome": "win", "turns": 1, "error": "", "cards": {}}
        target = str(protocol["packages"][row["package"]]["aspect"])
        if "package-order-1" in row["context"] and row["arm"] == "AB" \
                and row["aspect"] == target:
            item["cards"] = exact.synthetic_cards(
                str(row["package"]), protocol["packages"][row["package"]]
            )
        synthetic.append(item)
    local = analyse_local(protocol, synthetic)
    if local["decision"] != "continue-to-whole-run-heldout":
        raise AssertionError("positive local held-out decision self-check failed")
    whole_counts = {
        arm: len(whole_rows(protocol, arm)) for arm in protocol["wholeRunArms"]
    }
    if set(whole_counts.values()) != {int(protocol["budget"]["wholeRunRowsPerArm"])}:
        raise AssertionError("whole-run held-out row self-check failed")
    print(core.canonical({
        "status": "PASS",
        "protocolSha256": protocol_sha,
        "runnerSha256": source["runnerSha256"],
        "localRows": len(planned),
        "wholeRunRows": sum(whole_counts.values()),
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
