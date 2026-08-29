#!/usr/bin/env python3
"""Natural-capacity screen for the issue #421 Scoreline commitment."""

from __future__ import annotations

import json
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import post_v38_fight_local_identity as v1
import post_v38_knob_identity as ledger
import post_v38_scoreline_commitment_identity_v1 as commitment
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-scoreline-commitment-capacity-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-scoreline-commitment-capacity-v1.json"
SOURCE = commitment.CANDIDATE
PROBE = commitment.CANDIDATE_PROBE
ARMS = ("no-oath", "scoreline-oath")


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(label)


def rows(protocol: dict[str, Any]) -> list[dict[str, Any]]:
    cohort = protocol["cohort"]
    encoded = {
        "no-oath": commitment.settings("faultline-bonus-6", "none"),
        "scoreline-oath": commitment.settings("faultline-bonus-6", "scoreline-oath"),
    }
    return [
        {
            "id": f"scoreline-commitment-capacity-{arm}-{policy_index}-{seed}",
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


def _n(row: dict[str, Any], key: str) -> int:
    return int(row.get("packageEvents", {}).get(key, 0))


def metrics(
    control_rows: list[dict[str, Any]],
    enabled_rows: list[dict[str, Any]],
    seeds: list[int],
    protocol: dict[str, Any],
) -> tuple[dict[str, Any], list[str]]:
    faults: list[str] = []
    active_by_policy: dict[int, set[int]] = {}
    active_rows = 0
    payoff_events = 0
    producer_events = 0
    consumer_events = 0
    executioner_offered_rows = 0
    executioner_drawn_rows = 0
    executioner_played_rows = 0
    executioner_offers = 0
    executioner_draws = 0
    executioner_plays = 0
    chisel_played_rows = 0
    chisel_plays = 0
    additional_stall_or_error = 0
    policy_mismatches = 0
    for index, (control, enabled) in enumerate(zip(control_rows, enabled_rows)):
        policy_index = index // len(seeds)
        seed = seeds[index % len(seeds)]
        label = f"{policy_index}-{seed}"
        if any(str(key).startswith("scoreline") and int(value) != 0
               for key, value in control.get("packageEvents", {}).items()):
            faults.append(f"{label}:no-oath-scoreline-event")
        if any(str(key).startswith("afterimage") and int(value) != 0
               for row in (control, enabled)
               for key, value in row.get("packageEvents", {}).items()):
            faults.append(f"{label}:afterimage-event")
        if commitment.OATH in control.get("relics", []):
            faults.append(f"{label}:no-oath-control-leak")
        if enabled.get("relics", []).count(commitment.OATH) != 1:
            faults.append(f"{label}:enabled-oath-retention")

        producer = _n(enabled, "scorelineProducerEvents")
        mediator_set = _n(enabled, "scorelineMediatorSetEvents")
        consumer = _n(enabled, "scorelineConsumerEvents")
        mediator_consume = _n(enabled, "scorelineMediatorConsumeEvents")
        payoff = _n(enabled, "scorelinePayoffEvents")
        requested = _n(enabled, "scorelinePayoffRequested")
        realised = _n(enabled, "scorelinePayoffRealised")
        producer_events += producer
        consumer_events += consumer
        payoff_events += payoff
        if producer != mediator_set:
            faults.append(f"{label}:producer-set")
        if not (consumer == mediator_consume == payoff):
            faults.append(f"{label}:consumer-payoff")
        if requested != payoff * 6 or realised < 0 or realised > requested:
            faults.append(f"{label}:payoff-value")
        if payoff > 0:
            active_rows += 1
            active_by_policy.setdefault(policy_index, set()).add(seed)
            if _n(enabled, "executionerPlayed") <= 0 or _n(enabled, "chiselPlayed") <= 0:
                faults.append(f"{label}:payoff-without-card-path")

        offered = _n(enabled, "executionerOffered")
        drawn = _n(enabled, "executionerDrawn")
        played = _n(enabled, "executionerPlayed")
        executioner_offers += offered
        executioner_draws += drawn
        executioner_plays += played
        executioner_offered_rows += int(offered > 0)
        executioner_drawn_rows += int(drawn > 0)
        executioner_played_rows += int(played > 0)
        chisel_played = _n(enabled, "chiselPlayed")
        chisel_plays += chisel_played
        chisel_played_rows += int(chisel_played > 0)

        if enabled.get("outcome") in ("stall", "error") \
                and enabled.get("outcome") != control.get("outcome"):
            additional_stall_or_error += 1
        if enabled.get("policy") != control.get("policy"):
            policy_mismatches += 1

    robust = sorted(
        policy for policy, active_seeds in active_by_policy.items()
        if active_seeds == set(seeds)
    )
    floor = protocol["supportFloor"]
    passed = (
        not faults
        and len(robust) >= floor["robustActivePolicies"]
        and active_rows >= floor["activeRows"]
        and payoff_events >= floor["payoffEvents"]
        and additional_stall_or_error == 0
        and policy_mismatches == 0
    )
    result = {
        "producerEvents": producer_events,
        "consumerEvents": consumer_events,
        "payoffEvents": payoff_events,
        "activeRows": active_rows,
        "activePolicies": sorted(active_by_policy),
        "robustActivePolicies": robust,
        "robustActivePolicyCount": len(robust),
        "executionerOfferedRows": executioner_offered_rows,
        "executionerOffers": executioner_offers,
        "executionerDrawnRows": executioner_drawn_rows,
        "executionerDraws": executioner_draws,
        "executionerPlayedRows": executioner_played_rows,
        "executionerPlays": executioner_plays,
        "chiselPlayedRows": chisel_played_rows,
        "chiselPlays": chisel_plays,
        "additionalStallOrErrorRows": additional_stall_or_error,
        "policyIdentityMismatchRows": policy_mismatches,
        "passed": passed,
    }
    if len(robust) < floor["robustActivePolicies"]:
        faults.append("robust-support-floor")
    if active_rows < floor["activeRows"]:
        faults.append("active-row-floor")
    if payoff_events < floor["payoffEvents"]:
        faults.append("payoff-event-floor")
    if additional_stall_or_error:
        faults.append("additional-stall-or-error")
    if policy_mismatches:
        faults.append("policy-identity")
    return result, sorted(set(faults))


def append_observations(
    protocol_sha: str,
    observed: list[dict[str, Any]],
    protocol: dict[str, Any],
) -> int:
    cohort = protocol["cohort"]
    per_arm = cohort["policyCount"] * len(cohort["simulationSeeds"])
    db = core.open_ledger()
    prefix = f"{protocol_sha}:scoreline-commitment-capacity:"
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
                "stage": "scoreline-commitment-capacity",
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
        raise RuntimeError("refusing to overwrite the Scoreline commitment capacity summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    immutable = protocol["immutableInputs"]
    require("runner SHA drift", core.file_sha(Path(__file__)) == immutable["runnerSha256"])
    require("identity protocol drift", core.file_sha(commitment.PROTOCOL) ==
            immutable["identityProtocolSha256"])
    require("identity summary drift", core.file_sha(commitment.SUMMARY) ==
            immutable["identitySummarySha256"])
    identity_summary = json.loads(commitment.SUMMARY.read_text())
    require("identity gate not passed", identity_summary.get("outcomeClass") == "success")
    require("task capsule drift", core.file_sha(core.ROOT / immutable["taskCapsulePath"]) ==
            immutable["taskCapsuleSha256"])

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
        "arm": "scoreline-commitment-capacity-fixed-plan",
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
    observed = output.get("rows", [])
    result: dict[str, Any] = {}
    faults: list[str] = []
    ledger_error = ""
    appended = 0
    if not execution_error and len(observed) == len(planned):
        per_arm = len(observed) // len(ARMS)
        result, faults = metrics(
            observed[:per_arm], observed[per_arm:],
            protocol["cohort"]["simulationSeeds"], protocol,
        )
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
        faults.append("ledger-append-contract")

    if execution_error or ledger_error or elapsed > cap:
        outcome_class = "inconclusive"
        boundary = 3
        decision = "record-scoreline-commitment-capacity-inconclusive-at-cap"
    elif result.get("passed") and ledger_ok:
        outcome_class = "success"
        boundary = 1
        decision = "admit-scoreline-commitment-to-smallest-crn-panel"
    else:
        outcome_class = "futility"
        boundary = 2
        decision = "close-scoreline-commitment-at-capacity"

    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "protocolSha256": protocol_sha,
        "outcomeClass": outcome_class,
        "decisionBoundary": boundary,
        "decision": decision,
        "metrics": result,
        "faults": sorted(set(faults)),
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
        "claimBoundary": "Natural activation capacity only; no causal endpoint, candidate, detector, product or P9 claim.",
    }
    SUMMARY.write_text(core.canonical(summary) + "\n")
    print(json.dumps({
        "status": outcome_class.upper(),
        "decision": decision,
        "rows": len(observed),
        "ledgerRows": summary["newLedgerRows"],
    }, sort_keys=True))


if __name__ == "__main__":
    main()
