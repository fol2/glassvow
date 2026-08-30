#!/usr/bin/env python3
"""Brace-first natural-capacity screen for issue #421 Ward spend v3."""

from __future__ import annotations

import copy
import json
import os
import re
import sqlite3
import subprocess
import tempfile
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import post_v38_knob_identity as ledger
import post_3a234bae_ward_spend_identity_v3 as direct
import research as core


PROTOCOL = core.ROOT / "protocols/post-3a234bae-ward-spend-capacity-v1.json"
SUMMARY = core.ROOT / "summaries/post-3a234bae-ward-spend-capacity-v1.json"
SOURCE = core.ROOT / "ward-spend-finisher-v3-capacity-source"
PROBE = SOURCE / "tools/research_421_ward_spend_capacity_probe.gd"
CARD_ID = "research421WardSpendFinisher"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(label)


def git(path: Path, *args: str) -> str:
    return subprocess.run(
        ["git", *args], cwd=path, check=True, text=True, capture_output=True,
    ).stdout.strip()


def seconds_left(deadline: float) -> int:
    remaining = int(deadline - time.monotonic())
    if remaining < 1:
        raise TimeoutError("Ward-spend capacity reached its wall-time cap")
    return remaining


def research_card() -> dict[str, Any]:
    special = {"kind": "special", "id": "research421WardSpend"}
    return {
        "type": "attack", "rarity": "common", "cost": 1,
        "target": "enemy", "vfx": "slash",
        "effects": [{"kind": "dmg", "n": 5}, special],
        "up": {
            "effects": [
                {"kind": "dmg", "n": 7},
                copy.deepcopy(special),
            ],
            "text": "Research projection.",
        },
        "name": "Research projection", "text": "Research projection.",
    }


def content_projection(protocol: dict[str, Any]) -> tuple[str, Path]:
    source = SOURCE / "content/full-content.json"
    require(
        "current-main content identity",
        core.file_sha(source) == protocol["immutableInputs"]["contentSha256"],
    )
    raw = json.loads(source.read_text())
    require("research card unexpectedly exists", CARD_ID not in raw["cards"])
    require("research card unexpectedly pooled",
            CARD_ID not in raw["cardPools"]["common"])
    raw["cards"][CARD_ID] = research_card()
    raw["cardPools"]["common"].append(CARD_ID)
    return core.cache_json(raw)


def source_identity(protocol: dict[str, Any]) -> dict[str, Any]:
    immutable = protocol["immutableInputs"]
    repository = Path(immutable["repositoryPath"])
    return {
        "repositoryRefs": {
            ref: git(repository, "rev-parse", ref)
            for ref in immutable["repositoryRefs"]
        },
        "sourceHead": git(SOURCE, "rev-parse", "HEAD"),
        "sourceStatus": subprocess.run(
            ["git", "status", "--porcelain=v1"], cwd=SOURCE, check=True,
            text=True, capture_output=True,
        ).stdout.splitlines(),
        "classCacheSha256": core.file_sha(
            SOURCE / ".godot/global_script_class_cache.cfg"),
        "sourceSha256": {
            name: core.file_sha(SOURCE / name)
            for name in immutable["sourceSha256"]
        },
        "mechanismDiffSha256": core.sha(subprocess.run(
            ["git", "diff", "--", "domain/rules/combat.gd",
             "domain/state/player_combatant.gd"],
            cwd=SOURCE, check=True, capture_output=True,
        ).stdout),
        "runnerSha256": core.file_sha(Path(__file__)),
        "taskCapsuleSha256": core.file_sha(
            core.ROOT / immutable["taskCapsulePath"]),
        "directProtocolSha256": core.file_sha(
            core.ROOT / immutable["directProtocolPath"]),
        "directSummarySha256": core.file_sha(
            core.ROOT / immutable["directSummaryPath"]),
        "directRunnerSha256": core.file_sha(
            core.ROOT / immutable["directRunnerPath"]),
    }


def identity_faults(protocol: dict[str, Any]) -> list[str]:
    cohort = protocol["cohort"]
    identities = [int(cohort["policyRoot"])] + [
        int(seed) for seed in cohort["simulationSeeds"]
    ]
    faults: list[str] = []
    if len(identities) != len(set(identities)):
        faults.append("capacity identities are not unique")
    if any(3000 <= value <= 5399 for value in identities):
        faults.append("protected identity entered capacity cohort")
    hits: list[str] = []
    for path in (core.ROOT / "protocols").glob("*.json"):
        if path.resolve() == PROTOCOL.resolve():
            continue
        text = path.read_text()
        for value in identities:
            if re.search(rf"(?<!\d){value}(?!\d)", text):
                hits.append(f"{path.name}:{value}")
    if hits:
        faults.append("capacity identity appears in predecessor protocol: "
                      + ", ".join(hits))
    with sqlite3.connect(f"file:{core.LEDGER}?mode=ro", uri=True) as db:
        ledger_seeds = {
            int(row[0]) for row in db.execute(
                "SELECT DISTINCT json_extract(payload_json, '$.seed') "
                "FROM records WHERE kind='observation' "
                "AND json_type(payload_json, '$.seed')='integer'"
            )
        }
        ledger_roots = {
            int(row[0]) for row in db.execute(
                "SELECT DISTINCT json_extract(payload_json, '$.policyRoot') "
                "FROM records WHERE kind='observation' "
                "AND json_type(payload_json, '$.policyRoot')='integer'"
            )
        }
    if int(cohort["policyRoot"]) in ledger_roots:
        faults.append("capacity policy root appears in ledger")
    overlap = sorted(set(int(seed) for seed in cohort["simulationSeeds"]) & ledger_seeds)
    if overlap:
        faults.append(f"capacity simulation seed appears in ledger: {overlap}")
    return faults


def parse_preflight(godot: str, deadline: float) -> tuple[list[str], str]:
    env = {**os.environ, "GODOT": godot}
    result = subprocess.run(
        [str(SOURCE / "tools/check_scripts.sh"),
         "tools/balance_sim.gd",
         "tools/research_421_ward_spend_capacity_probe.gd"],
        cwd=SOURCE, env=env, text=True, capture_output=True,
        timeout=seconds_left(deadline),
    )
    transcript = (result.stdout + result.stderr)[-8000:]
    faults = (
        []
        if result.returncode == 0 and "scripts OK (2 checked)" in result.stdout
        else ["capacity GDScript mechanical parse preflight"]
    )
    return faults, transcript


def settings(producer: str) -> dict[str, str]:
    return {
        "schemaVersion": "ward-spend-capacity-v1",
        "producer": producer,
    }


def rows(
    protocol: dict[str, Any], producer: str, include_off: bool,
) -> list[dict[str, Any]]:
    cohort = protocol["cohort"]
    arms = ["off", producer] if include_off else [producer]
    return [
        {
            "id": f"capacity-{arm}-{policy_index}-{seed}",
            "aspect": cohort["aspect"],
            "vow": cohort["vow"],
            "seed": seed,
            "policyRoot": cohort["policyRoot"],
            "policyIndex": policy_index,
            "research421": settings(arm),
        }
        for arm in arms
        for policy_index in range(cohort["policyCount"])
        for seed in cohort["simulationSeeds"]
    ]


def run_probe(
    protocol: dict[str, Any],
    protocol_sha: str,
    content: Path,
    producer: str,
    include_off: bool,
    godot: str,
    deadline: float,
) -> tuple[dict[str, Any], str, str]:
    planned = rows(protocol, producer, include_off)
    plan = {
        "schemaVersion": 1,
        "protocolSha256": protocol_sha,
        "stage": f"{producer}-capacity",
        "content": str(content),
        "rows": planned,
    }
    plan_sha, plan_path = core.cache_json(plan)
    core.WORK.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(
        dir=core.WORK, prefix=f"ward-spend-capacity-{producer}-"
    ) as tmp:
        output_path = Path(tmp) / "output.json"
        result = subprocess.run(
            [godot, "--headless", "--path", str(SOURCE), "-s", str(PROBE), "--",
             f"--plan={plan_path}", f"--out={output_path}"],
            text=True, capture_output=True, timeout=seconds_left(deadline),
        )
        if result.returncode != 0 or not output_path.is_file():
            raise RuntimeError(
                f"{producer} capacity probe failed ({result.returncode})\n"
                f"{result.stdout[-2000:]}\n{result.stderr[-4000:]}"
            )
        output = json.loads(output_path.read_text())
    require(f"{producer} output plan identity",
            output.get("planSha256") == plan_sha)
    require(f"{producer} output probe identity",
            output.get("probeSha256") == core.file_sha(PROBE))
    require(f"{producer} output row count",
            len(output.get("rows", [])) == len(planned))
    output_sha, _ = core.cache_json(output)
    return output, plan_sha, output_sha


def normalised(row: dict[str, Any]) -> dict[str, Any]:
    result = copy.deepcopy(row)
    result.pop("id", None)
    probe = result.get("packageEvents", {})
    result["packageEvents"] = {
        key: value for key, value in probe.items()
        if not str(key).startswith("wardSpend")
    }
    return result


def count(probe: dict[str, Any], key: str) -> int:
    return int(probe.get(key, 0))


def capacity_metrics(
    protocol: dict[str, Any],
    producer: str,
    off_rows: list[dict[str, Any]],
    enabled_rows: list[dict[str, Any]],
) -> tuple[dict[str, Any], list[str], list[int]]:
    cohort = protocol["cohort"]
    seeds = [int(seed) for seed in cohort["simulationSeeds"]]
    minimum_rows = int(protocol["gates"]["minimumRowsPerRobustPolicy"])
    faults: list[str] = []
    producer_rows: dict[int, int] = {}
    consumer_rows: dict[int, int] = {}
    payable_rows: dict[int, dict[int, int]] = {4: {}, 8: {}}
    viable_rows: dict[int, dict[int, int]] = {4: {}, 8: {}}
    total = {
        "producerEvents": 0,
        "consumerPlays": 0,
        "payable4Events": 0,
        "payable8Events": 0,
    }
    for index, (off, enabled) in enumerate(zip(off_rows, enabled_rows)):
        policy_index = index // len(seeds)
        seed = seeds[index % len(seeds)]
        label = f"{producer}-{policy_index}-{seed}"
        off_probe = off.get("packageEvents", {})
        enabled_probe = enabled.get("packageEvents", {})
        if normalised(off) != normalised(enabled):
            faults.append(f"{label}:off-enabled-path-or-rng-mismatch")
        for arm, probe in (("off", off_probe), ("enabled", enabled_probe)):
            played = count(probe, f"{CARD_ID}Played")
            opportunities = count(probe, "wardSpendOpportunityEvents")
            if opportunities != played:
                faults.append(f"{label}:{arm}-consumer-opportunity-cardinality")
            if any(count(probe, key) != 0 for key in (
                "wardSpendSpendEvents",
                "wardSpendPayoffRequestedEvents",
                "wardSpendPayoffRealisedEvents",
            )):
                faults.append(f"{label}:{arm}-capacity-executed-payoff")
        if any(count(off_probe, key) != 0 for key in (
            "wardSpendProducerEvents",
            "wardSpendCreditSetEvents",
            "wardSpendPayable4Events",
            "wardSpendPayable8Events",
        )):
            faults.append(f"{label}:off-produced-credit-or-payability")
        producer_events = count(enabled_probe, "wardSpendProducerEvents")
        credit_events = count(enabled_probe, "wardSpendCreditSetEvents")
        if producer_events != credit_events:
            faults.append(f"{label}:producer-credit-cardinality")
        payable4 = count(enabled_probe, "wardSpendPayable4Events")
        payable8 = count(enabled_probe, "wardSpendPayable8Events")
        opportunities = count(enabled_probe, "wardSpendOpportunityEvents")
        if not (0 <= payable8 <= payable4 <= opportunities):
            faults.append(f"{label}:payability-order")
        played = count(enabled_probe, f"{CARD_ID}Played")
        total["producerEvents"] += producer_events
        total["consumerPlays"] += played
        total["payable4Events"] += payable4
        total["payable8Events"] += payable8
        if producer_events > 0:
            producer_rows[policy_index] = producer_rows.get(policy_index, 0) + 1
        if played > 0:
            consumer_rows[policy_index] = consumer_rows.get(policy_index, 0) + 1
        for spend, events in ((4, payable4), (8, payable8)):
            if events > 0:
                payable_rows[spend][policy_index] = (
                    payable_rows[spend].get(policy_index, 0) + 1
                )
                if enabled.get("outcome") not in ("stall", "error"):
                    viable_rows[spend][policy_index] = (
                        viable_rows[spend].get(policy_index, 0) + 1
                    )

    def robust(rows_by_policy: dict[int, int]) -> list[int]:
        return sorted(
            policy for policy, active_rows in rows_by_policy.items()
            if active_rows >= minimum_rows
        )

    producer_robust = robust(producer_rows)
    consumer_robust = robust(consumer_rows)
    spend_metrics: dict[str, Any] = {}
    feasible: list[int] = []
    for spend in (4, 8):
        payable_robust = robust(payable_rows[spend])
        viable_robust = robust(viable_rows[spend])
        inactive = sorted(
            policy for policy in range(cohort["policyCount"])
            if payable_rows[spend].get(policy, 0) == 0
        )
        passed = (
            not faults
            and len(producer_robust) >= protocol["gates"]["minimumProducerPolicies"]
            and len(consumer_robust) >= protocol["gates"]["minimumConsumerPolicies"]
            and len(payable_robust) >= protocol["gates"]["minimumPayablePolicies"]
            and len(inactive) >= protocol["gates"]["minimumExactInactivePolicies"]
            and len(viable_robust) >= protocol["gates"]["minimumViablePolicies"]
        )
        if passed:
            feasible.append(spend)
        spend_metrics[str(spend)] = {
            "robustPayablePolicies": payable_robust,
            "robustPayablePolicyCount": len(payable_robust),
            "exactInactivePolicies": inactive,
            "exactInactivePolicyCount": len(inactive),
            "robustViablePolicies": viable_robust,
            "robustViablePolicyCount": len(viable_robust),
            "passed": passed,
        }
    metrics = {
        **total,
        "robustProducerPolicies": producer_robust,
        "robustProducerPolicyCount": len(producer_robust),
        "robustConsumerPolicies": consumer_robust,
        "robustConsumerPolicyCount": len(consumer_robust),
        "spendLevels": spend_metrics,
        "feasibleSpendLevels": feasible,
        "identityFaultRows": len(faults),
    }
    return metrics, sorted(set(faults)), feasible


def append_observations(
    protocol_sha: str,
    observations: list[dict[str, Any]],
    protocol: dict[str, Any],
) -> int:
    prefix = f"{protocol_sha}:ward-spend-capacity:"
    db = core.open_ledger()
    existing = db.execute(
        "SELECT COUNT(*) FROM records WHERE identity LIKE ?", (prefix + "%",)
    ).fetchone()[0]
    require("capacity ledger identities already exist", existing == 0)
    created = datetime.now(timezone.utc).isoformat(timespec="seconds")
    try:
        db.execute("BEGIN IMMEDIATE")
        for item in observations:
            payload = {
                "schemaVersion": 1,
                "issue": 421,
                "protocolSha256": protocol_sha,
                "stage": "ward-spend-natural-capacity",
                "arm": item["arm"],
                "producer": item["producer"],
                "policyRoot": protocol["cohort"]["policyRoot"],
                "policyIndex": item["policyIndex"],
                "seed": item["seed"],
                "row": item["row"],
            }
            payload_json = core.canonical(payload)
            identity = (
                f"{prefix}{item['arm']}:{item['policyIndex']}:{item['seed']}"
            )
            db.execute(
                "INSERT INTO records(kind, identity, payload_sha256, payload_json, created_utc) "
                "VALUES (?, ?, ?, ?, ?)",
                ("observation", identity, core.sha(payload_json.encode()),
                 payload_json, created),
            )
        db.commit()
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()
    return len(observations)


def observation_items(
    protocol: dict[str, Any],
    arm: str,
    producer: str,
    observed: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    seeds = protocol["cohort"]["simulationSeeds"]
    return [
        {
            "arm": arm,
            "producer": producer,
            "policyIndex": index // len(seeds),
            "seed": seeds[index % len(seeds)],
            "row": row,
        }
        for index, row in enumerate(observed)
    ]


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite Ward-spend capacity summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    immutable = protocol["immutableInputs"]
    actual_source = source_identity(protocol)
    expected_source = {key: immutable[key] for key in actual_source}
    source_faults = [] if actual_source == expected_source else [
        "immutable source or generated class-cache identity drift"
    ]
    ledger_before = ledger.ledger_identity()
    require("ledger freeze drift", ledger_before == protocol["ledgerFreeze"])
    engine_preflight_faults, engine = direct.engine_faults(protocol)
    source_faults.extend(engine_preflight_faults)
    source_faults.extend(identity_faults(protocol))
    content_sha, content_path = content_projection(protocol)
    if content_sha != protocol["contentProjectionSha256"]:
        source_faults.append("capacity content projection identity drift")

    started = time.monotonic()
    deadline = started + protocol["budget"]["maximumWallTimeSeconds"]
    godot = engine["path"]
    parse_transcript = ""
    godot_processes = 0
    if not source_faults:
        godot_processes += 2
        parse_faults, parse_transcript = parse_preflight(godot, deadline)
        source_faults.extend(parse_faults)

    outputs: dict[str, str] = {}
    stage_results: dict[str, Any] = {}
    observations: list[dict[str, Any]] = []
    execution_error = ""
    selected_producer = ""
    feasible_spends: list[int] = []
    if not source_faults:
        try:
            godot_processes += 1
            brace_output, brace_plan_sha, brace_output_sha = run_probe(
                protocol, protocol_sha, content_path, "brace", True,
                godot, deadline,
            )
            outputs["bracePlanSha256"] = brace_plan_sha
            outputs["braceOutputSha256"] = brace_output_sha
            per_arm = (
                protocol["cohort"]["policyCount"]
                * len(protocol["cohort"]["simulationSeeds"])
            )
            off_rows = brace_output["rows"][:per_arm]
            brace_rows = brace_output["rows"][per_arm:]
            brace_metrics, brace_faults, brace_feasible = capacity_metrics(
                protocol, "brace", off_rows, brace_rows,
            )
            stage_results["brace"] = {
                "metrics": brace_metrics,
                "faults": brace_faults,
                "feasibleSpendLevels": brace_feasible,
            }
            observations.extend(observation_items(
                protocol, "off", "off", off_rows))
            observations.extend(observation_items(
                protocol, "brace", "brace", brace_rows))
            if brace_faults:
                feasible_spends = []
            elif brace_feasible:
                selected_producer = "brace"
                feasible_spends = brace_feasible
            else:
                godot_processes += 1
                bulwark_output, bulwark_plan_sha, bulwark_output_sha = run_probe(
                    protocol, protocol_sha, content_path, "bulwark", False,
                    godot, deadline,
                )
                outputs["bulwarkPlanSha256"] = bulwark_plan_sha
                outputs["bulwarkOutputSha256"] = bulwark_output_sha
                bulwark_rows = bulwark_output["rows"]
                bulwark_metrics, bulwark_faults, bulwark_feasible = capacity_metrics(
                    protocol, "bulwark", off_rows, bulwark_rows,
                )
                stage_results["bulwark"] = {
                    "metrics": bulwark_metrics,
                    "faults": bulwark_faults,
                    "feasibleSpendLevels": bulwark_feasible,
                }
                observations.extend(observation_items(
                    protocol, "bulwark", "bulwark", bulwark_rows))
                if not bulwark_faults and bulwark_feasible:
                    selected_producer = "bulwark"
                    feasible_spends = bulwark_feasible
        except (OSError, subprocess.SubprocessError, TimeoutError, RuntimeError) as error:
            execution_error = str(error)

    appended = 0
    ledger_error = ""
    if not source_faults and not execution_error:
        try:
            appended = append_observations(protocol_sha, observations, protocol)
        except Exception as error:
            ledger_error = str(error)
    ledger_after = ledger.ledger_identity()
    post_source = source_identity(protocol)
    post_source_fault = post_source != actual_source
    elapsed = time.monotonic() - started
    ledger_ok = (
        not ledger_error
        and appended == len(observations)
        and ledger_after["records"] == ledger_before["records"] + appended
        and ledger_after["lastSequence"] == ledger_before["lastSequence"] + appended
        and ledger_after["protectedSeedRows"] == ledger_before["protectedSeedRows"]
        and ledger_after["sqliteIntegrity"] == "ok"
    )
    if execution_error or ledger_error or elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        outcome = "inconclusive"
        boundary = 3
        decision = "record-ward-spend-capacity-inconclusive-at-cap"
    elif source_faults or post_source_fault or not ledger_ok:
        outcome = "futility"
        boundary = 2
        decision = "close-ward-spend-v3-family-at-capacity-integrity-gate"
    elif selected_producer:
        outcome = "success"
        boundary = 1
        decision = (
            f"admit-ward-spend-{selected_producer}-levels-to-smallest-crn-panel-v3"
        )
    else:
        outcome = "futility"
        boundary = 2
        decision = "close-ward-spend-v3-family-at-natural-capacity"
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "outcomeClass": outcome,
        "decisionBoundary": boundary,
        "decision": decision,
        "authority": protocol["decisionRules"][outcome + "Authority"],
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "engineIdentity": engine,
        "sourceIdentity": actual_source,
        "sourceIdentityAfterExecution": post_source,
        "sourceFaults": source_faults,
        "postExecutionSourceIdentityFault": post_source_fault,
        "contentProjectionSha256": content_sha,
        "parseTranscript": parse_transcript,
        "stageResults": stage_results,
        "selectedProducer": selected_producer,
        "feasibleSpendLevels": feasible_spends,
        "executionError": execution_error,
        "ledgerAppendError": ledger_error,
        "outputs": outputs,
        "observedRows": len(observations),
        "newLedgerRows": ledger_after["records"] - ledger_before["records"],
        "GodotProcesses": godot_processes,
        "wallTimeSeconds": elapsed,
        "maximumModelContextTokensDuringExecutionAndDecision": 0,
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "protectedSeedRows": ledger_after["protectedSeedRows"],
        "immutableQuarantinedObservationCount": 82,
        "quarantinedObservationsUsedForDecision": 0,
        "claimBoundary": protocol["claimBoundary"],
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "outcomeClass": outcome,
        "decision": decision,
        "selectedProducer": selected_producer,
        "feasibleSpendLevels": feasible_spends,
        "rows": len(observations),
        "ledgerRows": summary["newLedgerRows"],
        "GodotProcesses": godot_processes,
        "wallTimeSeconds": round(elapsed, 3),
    }, sort_keys=True))


if __name__ == "__main__":
    main()
