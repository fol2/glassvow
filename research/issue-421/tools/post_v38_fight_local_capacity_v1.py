#!/usr/bin/env python3
"""Natural-exposure capacity screen for issue #421 fight-local v2."""

from __future__ import annotations

import json
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import post_v38_fight_local_identity as v1
import post_v38_fight_local_identity_v2 as v2
import post_v38_knob_identity as ledger
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-fight-local-capacity-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-fight-local-capacity-v1.json"
SOURCE = v2.CANDIDATE
PROBE = v2.CANDIDATE_PROBE
ARMS = ("off", "scoreline", "afterimage")


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(label)


def rows(protocol: dict[str, Any]) -> list[dict[str, Any]]:
    cohort = protocol["cohort"]
    encoded = {
        "off": v2.settings(0, 0),
        "scoreline": v2.settings(6, 0),
        "afterimage": v2.settings(0, 5),
    }
    return [
        {
            "id": f"capacity-{arm}-{policy_index}-{seed}",
            "mode": "whole-run",
            "aspect": cohort["aspect"],
            "vow": cohort["vow"],
            "seed": seed,
            "policyRoot": cohort["policyRoot"],
            "policyIndex": policy_index,
            "research421": encoded[arm],
        }
        for arm in ARMS
        for policy_index in range(cohort["policyCount"])
        for seed in cohort["simulationSeeds"]
    ]


def block_metrics(
    block: str,
    off_rows: list[dict[str, Any]],
    enabled_rows: list[dict[str, Any]],
    seeds: list[int],
    support_floor: int,
) -> tuple[dict[str, Any], list[str]]:
    prefix = "scoreline" if block == "scoreline" else "afterimage"
    opposite = "afterimage" if block == "scoreline" else "scoreline"
    faults: list[str] = []
    active_by_policy: dict[int, set[int]] = {}
    active_rows = 0
    payoff_events = 0
    producer_events = 0
    consumer_events = 0
    additional_stall_or_error = 0
    policy_mismatches = 0
    for index, (off, enabled) in enumerate(zip(off_rows, enabled_rows)):
        policy_index = index // len(seeds)
        seed = seeds[index % len(seeds)]
        probe = enabled.get("packageEvents", {})
        if any(str(key).startswith(opposite) and int(value) != 0
               for key, value in probe.items()):
            faults.append(f"{block}-{policy_index}-{seed}:opposite-factor-event")
        producer = int(probe.get(f"{prefix}ProducerEvents", 0))
        mediator_set = int(probe.get(f"{prefix}MediatorSetEvents", 0))
        consumer = int(probe.get(f"{prefix}ConsumerEvents", 0))
        mediator_consume = int(probe.get(f"{prefix}MediatorConsumeEvents", 0))
        payoff = int(probe.get(f"{prefix}PayoffEvents", 0))
        requested = int(probe.get(f"{prefix}PayoffRequested", 0))
        realised = int(probe.get(f"{prefix}PayoffRealised", 0))
        producer_events += producer
        consumer_events += consumer
        payoff_events += payoff
        if producer != mediator_set:
            faults.append(f"{block}-{policy_index}-{seed}:producer-set")
        if not (consumer == mediator_consume == payoff):
            faults.append(f"{block}-{policy_index}-{seed}:consumer-payoff")
        if block == "scoreline":
            if requested != payoff * 6 or realised < 0 or realised > requested:
                faults.append(f"{block}-{policy_index}-{seed}:payoff-value")
        else:
            producer_ward = int(probe.get("afterimageProducerWard", 0))
            stored_ward = int(probe.get("afterimageStoredWard", 0))
            if not (0 <= stored_ward <= producer * 5 and stored_ward <= producer_ward):
                faults.append(f"{block}-{policy_index}-{seed}:stored-value")
            if not (0 <= requested <= payoff * 5 and realised == requested):
                faults.append(f"{block}-{policy_index}-{seed}:payoff-value")
        if payoff > 0:
            active_rows += 1
            active_by_policy.setdefault(policy_index, set()).add(seed)
        if enabled.get("outcome") in ("stall", "error") \
                and enabled.get("outcome") != off.get("outcome"):
            additional_stall_or_error += 1
        if enabled.get("policy") != off.get("policy"):
            policy_mismatches += 1
    robust = sorted(
        policy for policy, active_seeds in active_by_policy.items()
        if active_seeds == set(seeds)
    )
    passed = (
        not faults
        and len(robust) >= support_floor
        and active_rows >= support_floor * len(seeds)
        and payoff_events >= support_floor * len(seeds)
        and additional_stall_or_error == 0
        and policy_mismatches == 0
    )
    metrics = {
        "producerEvents": producer_events,
        "consumerEvents": consumer_events,
        "payoffEvents": payoff_events,
        "activeRows": active_rows,
        "activePolicies": sorted(active_by_policy),
        "robustActivePolicies": robust,
        "robustActivePolicyCount": len(robust),
        "additionalStallOrErrorRows": additional_stall_or_error,
        "policyIdentityMismatchRows": policy_mismatches,
        "supportFloor": support_floor,
        "passed": passed,
    }
    if len(robust) < support_floor:
        faults.append(f"{block}:robust-support-floor")
    if active_rows < support_floor * len(seeds):
        faults.append(f"{block}:active-row-floor")
    if payoff_events < support_floor * len(seeds):
        faults.append(f"{block}:payoff-event-floor")
    if additional_stall_or_error:
        faults.append(f"{block}:additional-stall-or-error")
    if policy_mismatches:
        faults.append(f"{block}:policy-identity")
    return metrics, sorted(set(faults))


def append_observations(
    protocol_sha: str,
    observed: list[dict[str, Any]],
    protocol: dict[str, Any],
) -> int:
    cohort = protocol["cohort"]
    per_arm = cohort["policyCount"] * len(cohort["simulationSeeds"])
    db = core.open_ledger()
    prefix = f"{protocol_sha}:fight-local-capacity:"
    existing = db.execute(
        "SELECT COUNT(*) FROM records WHERE identity LIKE ?", (prefix + "%",)
    ).fetchone()[0]
    require("capacity ledger identities already exist", existing == 0)
    created = datetime.now(timezone.utc).isoformat(timespec="seconds")
    try:
        db.execute("BEGIN IMMEDIATE")
        for index, row in enumerate(observed):
            arm_index = index // per_arm
            within = index % per_arm
            policy_index = within // len(cohort["simulationSeeds"])
            seed = cohort["simulationSeeds"][within % len(cohort["simulationSeeds"])]
            arm = ARMS[arm_index]
            payload = {
                "schemaVersion": 1,
                "issue": 421,
                "protocolSha256": protocol_sha,
                "stage": "fight-local-capacity",
                "arm": arm,
                "policyRoot": cohort["policyRoot"],
                "policyIndex": policy_index,
                "seed": seed,
                "row": row,
            }
            payload_json = core.canonical(payload)
            db.execute(
                "INSERT INTO records(kind, identity, payload_sha256, payload_json, created_utc) "
                "VALUES (?, ?, ?, ?, ?)",
                ("observation", f"{prefix}{arm}:{policy_index}:{seed}",
                 core.sha(payload_json.encode()), payload_json, created),
            )
        db.commit()
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()
    return len(observed)


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the fight-local capacity summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    immutable = protocol["immutableInputs"]
    require("runner SHA drift", core.file_sha(Path(__file__)) == immutable["runnerSha256"])
    require("task capsule drift", core.file_sha(core.ROOT / immutable["taskCapsulePath"]) ==
            immutable["taskCapsuleSha256"])
    require("v2 protocol drift", core.file_sha(v2.PROTOCOL) == immutable["v2ProtocolSha256"])
    require("v2 summary drift", core.file_sha(v2.SUMMARY) == immutable["v2SummarySha256"])
    require("v2 runner drift", core.file_sha(Path(v2.__file__)) == immutable["v2RunnerSha256"])
    repository = Path(immutable["repositoryPath"])
    for ref, expected in immutable["repositoryRefs"].items():
        actual = subprocess.run(
            ["git", "rev-parse", ref], cwd=repository, check=True,
            text=True, capture_output=True,
        ).stdout.strip()
        require(f"repository ref drift: {ref}", actual == expected)
    head = subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=SOURCE, check=True,
        text=True, capture_output=True,
    ).stdout.strip()
    require("source commit drift", head == immutable["sourceCommit"])
    for name, expected in immutable["sourceSha256"].items():
        require(f"source {name} drift", core.file_sha(SOURCE / name) == expected)
    godot = immutable["godotBinaryPath"]
    require("Godot binary drift", core.file_sha(Path(godot)) == immutable["godotBinarySha256"])
    version = subprocess.run(
        [godot, "--version"], check=True, text=True, capture_output=True,
    ).stdout.strip()
    require("Godot version drift", version == immutable["godotVersion"])
    content_path = core.CACHE / f"{immutable['contentSha256']}.json"
    require("content drift", core.file_sha(content_path) == immutable["contentSha256"])
    ledger_before = ledger.ledger_identity()
    require("ledger freeze drift", ledger_before == protocol["ledgerFreeze"])

    planned = rows(protocol)
    require("row budget", len(planned) == protocol["budget"]["maximumSimulatorRows"])
    plan = {
        "schemaVersion": 1,
        "protocolSha256": protocol_sha,
        "arm": "mechanism-blocked-capacity-fixed-plan",
        "content": str(content_path),
        "rows": planned,
    }
    started = time.monotonic()
    cap = protocol["budget"]["maximumWallTimeSeconds"]
    execution_error = ""
    output: dict[str, Any] = {}
    plan_sha = ""
    output_sha = ""
    try:
        output, plan_sha, output_sha = v1.run_probe(SOURCE, PROBE, plan, godot, cap)
    except (RuntimeError, subprocess.TimeoutExpired, OSError) as error:
        execution_error = str(error)
    elapsed = time.monotonic() - started
    observed = output.get("rows", [])
    block_results: dict[str, Any] = {}
    all_faults: list[str] = []
    ledger_error = ""
    appended = 0
    if not execution_error and len(observed) == len(planned):
        per_arm = len(observed) // len(ARMS)
        off_rows = observed[:per_arm]
        scoreline_rows = observed[per_arm:per_arm * 2]
        afterimage_rows = observed[per_arm * 2:]
        for block, enabled in (("scoreline", scoreline_rows),
                               ("afterimage", afterimage_rows)):
            metrics, faults = block_metrics(
                block, off_rows, enabled, protocol["cohort"]["simulationSeeds"],
                protocol["supportFloor"]["robustActivePolicies"],
            )
            block_results[block] = {
                "metrics": metrics,
                "faults": faults,
                "decision": "admit-to-causal-panel" if metrics["passed"]
                else "close-at-capacity",
            }
            all_faults.extend(faults)
        try:
            appended = append_observations(protocol_sha, observed, protocol)
        except Exception as error:
            ledger_error = str(error)
    elif not execution_error:
        execution_error = f"incomplete output: {len(observed)} of {len(planned)} rows"

    ledger_after = ledger.ledger_identity()
    elapsed = time.monotonic() - started
    ledger_ok = (
        not ledger_error
        and appended == protocol["budget"]["maximumNewLedgerRows"]
        and ledger_after["records"] == ledger_before["records"] + appended
        and ledger_after["lastSequence"] == ledger_before["lastSequence"] + appended
        and ledger_after["protectedSeedRows"] == ledger_before["protectedSeedRows"]
        and ledger_after["sqliteIntegrity"] == "ok"
    )
    if not ledger_ok and not execution_error:
        all_faults.append("ledger-append-contract")
    passed_blocks = [
        block for block, result in block_results.items()
        if result["metrics"]["passed"]
    ]
    if execution_error or ledger_error or elapsed > cap:
        outcome_class = "inconclusive"
        boundary = 3
        decision = "record-fight-local-capacity-inconclusive-at-cap"
    elif len(passed_blocks) == 2 and ledger_ok:
        outcome_class = "success"
        boundary = 1
        decision = "admit-both-blocks-to-separate-crn-panels"
    elif len(passed_blocks) == 1 and ledger_ok:
        outcome_class = "mixed"
        boundary = 1
        decision = "admit-one-block-and-close-one-at-capacity"
    else:
        outcome_class = "futility"
        boundary = 2
        decision = "close-fight-local-v2-at-capacity"
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "protocolSha256": protocol_sha,
        "outcomeClass": outcome_class,
        "decisionBoundary": boundary,
        "decision": decision,
        "passedBlocks": passed_blocks,
        "blockResults": block_results,
        "faults": sorted(set(all_faults)),
        "elapsedSeconds": round(elapsed, 6),
        "observedRows": len(observed),
        "newLedgerRows": ledger_after["records"] - ledger_before["records"],
        "ledgerAppendError": ledger_error,
        "executionError": execution_error,
        "outputs": {
            "planSha256": plan_sha,
            "outputSha256": output_sha,
        },
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "claimBoundary": "Capacity and natural activation only; no causal endpoint, candidate, detector, product or P9 claim.",
    }
    SUMMARY.write_text(core.canonical(summary) + "\n")
    print(json.dumps({
        "status": outcome_class.upper(),
        "decision": decision,
        "passedBlocks": passed_blocks,
        "rows": len(observed),
        "ledgerRows": summary["newLedgerRows"],
    }, sort_keys=True))


if __name__ == "__main__":
    main()
