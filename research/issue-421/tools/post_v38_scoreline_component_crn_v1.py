#!/usr/bin/env python3
"""Three-arm component CRN panel for the issue #421 Scoreline commitment."""

from __future__ import annotations

import json
import sqlite3
import statistics
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import post_v38_fight_local_identity as v1
import post_v38_knob_identity as ledger
import post_v38_scoreline_component_identity_v1 as component
import post_v38_scoreline_commitment_identity_v1 as commitment
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-scoreline-component-crn-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-scoreline-component-crn-v1.json"
SOURCE = component.CANDIDATE
PROBE = component.CANDIDATE_PROBE
CELLS = ("base", "assignment-only", "full")
ENDPOINTS = (
    "quality", "win", "hpFraction", "duration", "payoffEvents",
    "producerEvents", "executionerPlayed", "chiselPlayed",
)
CONTRASTS = {
    "fullVsBase": {"full": 1, "base": -1},
    "assignmentVsBase": {"assignment-only": 1, "base": -1},
    "payoffAtAssignment": {"full": 1, "assignment-only": -1},
}


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(label)


def rows(protocol: dict[str, Any]) -> list[dict[str, Any]]:
    cohort = protocol["cohort"]
    encoded = {
        "base": component.settings("off", "none"),
        "assignment-only": component.settings("off", "scoreline-oath"),
        "full": component.settings("faultline-bonus-6", "scoreline-oath"),
    }
    return [
        {
            "id": f"scoreline-component-crn-{cell}-{policy_index}-{seed}",
            "mode": "whole-run",
            "aspect": cohort["aspect"],
            "vow": cohort["vow"],
            "seed": seed,
            "policyRoot": cohort["policyRoot"],
            "policyIndex": policy_index,
            "research421": encoded[cell],
        }
        for cell in CELLS
        for policy_index in range(cohort["policyCount"])
        for seed in cohort["simulationSeeds"]
    ]


def _n(row: dict[str, Any], key: str) -> int:
    return int(row.get("packageEvents", {}).get(key, 0))


def metric(row: dict[str, Any], endpoint: str) -> float:
    if endpoint == "quality":
        require("positive max HP", int(row["maxHp"]) > 0)
        return float(row["outcome"] == "win") + float(row["hp"]) / float(row["maxHp"])
    if endpoint == "win":
        return float(row["outcome"] == "win")
    if endpoint == "hpFraction":
        require("positive max HP", int(row["maxHp"]) > 0)
        return float(row["hp"]) / float(row["maxHp"])
    if endpoint == "duration":
        require("duration fights", bool(row["fights"]))
        return statistics.fmean(float(fight["turns"]) for fight in row["fights"])
    if endpoint == "payoffEvents":
        return float(_n(row, "scorelinePayoffEvents"))
    if endpoint == "producerEvents":
        return float(_n(row, "scorelineProducerEvents"))
    if endpoint == "executionerPlayed":
        return float(_n(row, "executionerPlayed"))
    if endpoint == "chiselPlayed":
        return float(_n(row, "chiselPlayed"))
    raise KeyError(endpoint)


def indexed(
    observed: list[dict[str, Any]], protocol: dict[str, Any]
) -> dict[str, dict[tuple[int, int], dict[str, Any]]]:
    cohort = protocol["cohort"]
    seeds = cohort["simulationSeeds"]
    per_cell = cohort["policyCount"] * len(seeds)
    require("complete rectangle", len(observed) == per_cell * len(CELLS))
    result: dict[str, dict[tuple[int, int], dict[str, Any]]] = {}
    for cell_index, cell in enumerate(CELLS):
        found: dict[tuple[int, int], dict[str, Any]] = {}
        cell_rows = observed[cell_index * per_cell:(cell_index + 1) * per_cell]
        for index, row in enumerate(cell_rows):
            policy_index = index // len(seeds)
            seed = seeds[index % len(seeds)]
            key = (policy_index, seed)
            require(f"{cell} id {key}", row["id"] ==
                    f"scoreline-component-crn-{cell}-{policy_index}-{seed}")
            require(f"{cell} seed {key}", int(row["seed"]) == seed)
            require(f"{cell} aspect {key}", row["aspect"] == cohort["aspect"])
            require(f"{cell} vow {key}", int(row["vow"]) == cohort["vow"])
            found[key] = row
        result[cell] = found
    return result


def policy_values(
    rows_by_cell: dict[str, dict[tuple[int, int], dict[str, Any]]],
    protocol: dict[str, Any],
    weights: dict[str, int],
    endpoint: str,
) -> list[float]:
    cohort = protocol["cohort"]
    return [
        statistics.fmean(
            sum(weight * metric(rows_by_cell[cell][(policy_index, seed)], endpoint)
                for cell, weight in weights.items())
            for seed in cohort["simulationSeeds"]
        )
        for policy_index in range(cohort["policyCount"])
    ]


def fit_effects(
    rows_by_cell: dict[str, dict[tuple[int, int], dict[str, Any]]],
    protocol: dict[str, Any],
) -> tuple[dict[str, Any], dict[str, dict[str, list[float]]]]:
    effects: dict[str, Any] = {}
    raw: dict[str, dict[str, list[float]]] = {}
    seed = int(protocol["estimators"]["bootstrapSeed"])
    for contrast_index, (name, weights) in enumerate(CONTRASTS.items()):
        effects[name] = {}
        raw[name] = {}
        for endpoint_index, endpoint in enumerate(ENDPOINTS):
            values = policy_values(rows_by_cell, protocol, weights, endpoint)
            raw[name][endpoint] = values
            effects[name][endpoint] = core.interval(
                values, 1.0, seed + 10 * contrast_index + endpoint_index
            )
    return effects, raw


def analyse(
    rows_by_cell: dict[str, dict[tuple[int, int], dict[str, Any]]],
    protocol: dict[str, Any],
) -> tuple[dict[str, Any], list[str]]:
    cohort = protocol["cohort"]
    gates = protocol["gates"]
    faults: list[str] = []
    policy_mismatches = 0
    fault_rows = 0
    for policy_index in range(cohort["policyCount"]):
        for seed in cohort["simulationSeeds"]:
            key = (policy_index, seed)
            base = rows_by_cell["base"][key]
            assignment = rows_by_cell["assignment-only"][key]
            full = rows_by_cell["full"][key]
            if not (base["policy"] == assignment["policy"] == full["policy"]):
                policy_mismatches += 1
            if commitment.OATH in base.get("relics", []):
                faults.append(f"{policy_index}-{seed}:base-oath")
            if not commitment_present(assignment) or not commitment_present(full):
                faults.append(f"{policy_index}-{seed}:oath-retention")
            for cell, row in (("base", base), ("assignment", assignment)):
                if any(str(name).startswith("scoreline") and int(value) != 0
                       for name, value in row.get("packageEvents", {}).items()):
                    faults.append(f"{policy_index}-{seed}:{cell}-scoreline-event")
            for cell, row in (("base", base), ("assignment", assignment), ("full", full)):
                if any(str(name).startswith("afterimage") and int(value) != 0
                       for name, value in row.get("packageEvents", {}).items()):
                    faults.append(f"{policy_index}-{seed}:{cell}-afterimage-event")
                if row.get("outcome") in ("stall", "error") or bool(row.get("error")):
                    fault_rows += 1
            producer = _n(full, "scorelineProducerEvents")
            mediator_set = _n(full, "scorelineMediatorSetEvents")
            consumer = _n(full, "scorelineConsumerEvents")
            mediator_consume = _n(full, "scorelineMediatorConsumeEvents")
            payoff = _n(full, "scorelinePayoffEvents")
            requested = _n(full, "scorelinePayoffRequested")
            realised = _n(full, "scorelinePayoffRealised")
            if producer != mediator_set:
                faults.append(f"{policy_index}-{seed}:producer-set")
            if not (consumer == mediator_consume == payoff):
                faults.append(f"{policy_index}-{seed}:consumer-payoff")
            if requested != payoff * 6 or realised < 0 or realised > requested:
                faults.append(f"{policy_index}-{seed}:payoff-value")
            if payoff > 0 and (_n(full, "chiselPlayed") <= 0 or
                               _n(full, "executionerPlayed") <= 0):
                faults.append(f"{policy_index}-{seed}:payoff-without-card-path")

    effects, raw = fit_effects(rows_by_cell, protocol)
    active = {
        policy for policy in range(cohort["policyCount"])
        if sum(_n(rows_by_cell["full"][(policy, seed)], "scorelinePayoffEvents") > 0
               for seed in cohort["simulationSeeds"])
        >= cohort["minimumRowsPerActivePolicy"]
    }
    inactive = {
        policy for policy in range(cohort["policyCount"])
        if not any(_n(rows_by_cell["full"][(policy, seed)], "scorelinePayoffEvents") > 0
                   for seed in cohort["simulationSeeds"])
    }
    viable = {
        policy for policy in active
        if any(rows_by_cell["full"][(policy, seed)]["outcome"] == "win" and
               _n(rows_by_cell["full"][(policy, seed)], "scorelinePayoffEvents") > 0
               for seed in cohort["simulationSeeds"])
    }
    payoff_quality = raw["payoffAtAssignment"]["quality"]
    positive = {index for index, value in enumerate(payoff_quality) if value > 0}
    zero = {index for index, value in enumerate(payoff_quality) if value == 0}
    negative = {index for index, value in enumerate(payoff_quality) if value < 0}
    positive_viable = positive & viable
    non_positive = zero | negative
    full_rows = list(rows_by_cell["full"].values())
    win_rate = statistics.fmean(metric(row, "win") for row in full_rows)

    checks = {
        "telemetryAndIsolation": not faults,
        "policyIdentity": policy_mismatches == 0,
        "reliability": fault_rows == 0,
        "activeSupport": len(active) >= gates["minimumActivePolicies"],
        "viableSupport": len(viable) >= gates["minimumViablePolicies"],
        "positiveViableWitnesses": len(positive_viable) >= gates["minimumPositiveViablePolicies"],
        "nonPositiveWitnesses": len(non_positive) >= gates["minimumNonPositivePolicies"],
        "packageTotalEffect": effects["fullVsBase"]["quality"]["p025"] > 0,
        "scorelinePayoffEffect": effects["payoffAtAssignment"]["quality"]["p025"] > 0,
        "scorelineActivationEffect": effects["payoffAtAssignment"]["payoffEvents"]["p025"] > 0,
        "totalDuration": effects["fullVsBase"]["duration"]["p975"] <=
        gates["maximumDurationIncreaseTurnsPerFight"],
        "payoffDuration": effects["payoffAtAssignment"]["duration"]["p975"] <=
        gates["maximumDurationIncreaseTurnsPerFight"],
        "vow5": win_rate <= gates["maximumVow5WinRate"],
    }
    fixed_failure = (
        bool(faults) or policy_mismatches != 0 or fault_rows != 0
        or len(active) < gates["minimumActivePolicies"]
        or len(viable) < gates["minimumViablePolicies"]
        or len(positive_viable) < gates["minimumPositiveViablePolicies"]
        or len(non_positive) < gates["minimumNonPositivePolicies"]
        or win_rate > gates["maximumVow5WinRate"]
        or effects["fullVsBase"]["quality"]["p975"] <= 0
        or effects["payoffAtAssignment"]["quality"]["p975"] <= 0
        or effects["payoffAtAssignment"]["payoffEvents"]["p975"] <= 0
        or effects["fullVsBase"]["duration"]["p025"] >
        gates["maximumDurationIncreaseTurnsPerFight"]
        or effects["payoffAtAssignment"]["duration"]["p025"] >
        gates["maximumDurationIncreaseTurnsPerFight"]
    )
    return {
        "effects": effects,
        "checks": checks,
        "fixedFailure": fixed_failure,
        "counts": {
            "activePolicies": len(active),
            "inactivePolicies": len(inactive),
            "viablePolicies": len(viable),
            "positivePayoffPolicies": len(positive),
            "zeroPayoffPolicies": len(zero),
            "negativePayoffPolicies": len(negative),
            "positiveViablePolicies": len(positive_viable),
            "nonPositivePolicies": len(non_positive),
            "faultRows": fault_rows,
            "policyIdentityMismatchRows": policy_mismatches,
            "fullVow5WinRate": win_rate,
        },
        "policySets": {
            "active": sorted(active),
            "inactive": sorted(inactive),
            "viable": sorted(viable),
            "positivePayoff": sorted(positive),
            "zeroPayoff": sorted(zero),
            "negativePayoff": sorted(negative),
            "positiveViable": sorted(positive_viable),
            "nonPositive": sorted(non_positive),
        },
    }, sorted(set(faults))


def commitment_present(row: dict[str, Any]) -> bool:
    return row.get("relics", []).count(commitment.OATH) == 1


def append_observations(
    protocol_sha: str,
    observed: list[dict[str, Any]],
    protocol: dict[str, Any],
) -> int:
    cohort = protocol["cohort"]
    per_cell = cohort["policyCount"] * len(cohort["simulationSeeds"])
    db = core.open_ledger()
    prefix = f"{protocol_sha}:scoreline-component-crn:"
    existing = db.execute(
        "SELECT COUNT(*) FROM records WHERE identity LIKE ?", (prefix + "%",)
    ).fetchone()[0]
    require("CRN ledger identities already exist", existing == 0)
    created = datetime.now(timezone.utc).isoformat(timespec="seconds")
    try:
        db.execute("BEGIN IMMEDIATE")
        for index, row in enumerate(observed):
            cell_index = index // per_cell
            within = index % per_cell
            policy_index = within // len(cohort["simulationSeeds"])
            seed = cohort["simulationSeeds"][within % len(cohort["simulationSeeds"])]
            cell = CELLS[cell_index]
            payload = {
                "schemaVersion": 1,
                "issue": 421,
                "protocolSha256": protocol_sha,
                "stage": "scoreline-component-crn",
                "cell": cell,
                "policyRoot": cohort["policyRoot"],
                "policyIndex": policy_index,
                "seed": seed,
                "row": row,
            }
            payload_json = core.canonical(payload)
            db.execute(
                "INSERT INTO records(kind, identity, payload_sha256, payload_json, created_utc) "
                "VALUES (?, ?, ?, ?, ?)",
                ("observation", f"{prefix}{cell}:{policy_index}:{seed}",
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
        raise RuntimeError("refusing to overwrite the Scoreline component CRN summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    immutable = protocol["immutableInputs"]
    require("runner SHA drift", core.file_sha(Path(__file__)) == immutable["runnerSha256"])
    require("identity protocol drift", core.file_sha(component.PROTOCOL) ==
            immutable["identityProtocolSha256"])
    require("identity summary drift", core.file_sha(component.SUMMARY) ==
            immutable["identitySummarySha256"])
    identity_summary = json.loads(component.SUMMARY.read_text())
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
    require("source head drift", head == immutable["sourceHead"])
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
        "arm": "scoreline-component-three-arm-crn-fixed-plan",
        "content": str(content_path),
        "rows": planned,
    }
    started = time.monotonic()
    cap = protocol["budget"]["maximumWallTimeSeconds"]
    execution_error = ""
    output: dict[str, Any] = {}
    plan_sha = ""
    output_sha = ""
    analysis: dict[str, Any] = {}
    faults: list[str] = []
    ledger_error = ""
    appended = 0
    try:
        output, plan_sha, output_sha = v1.run_probe(SOURCE, PROBE, plan, godot, cap)
        observed = output.get("rows", [])
        require("complete output", len(observed) == len(planned))
        rows_by_cell = indexed(observed, protocol)
        analysis, faults = analyse(rows_by_cell, protocol)
        appended = append_observations(protocol_sha, observed, protocol)
    except (KeyError, RuntimeError, sqlite3.Error, subprocess.TimeoutExpired, OSError,
            TypeError, ValueError) as error:
        execution_error = str(error)
        observed = output.get("rows", [])

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

    if execution_error or ledger_error or elapsed > cap or not ledger_ok:
        outcome_class = "inconclusive"
        boundary = 3
        decision = "record-scoreline-component-crn-inconclusive-at-cap"
    elif all(analysis["checks"].values()):
        outcome_class = "success"
        boundary = 1
        decision = "freeze-scoreline-commitment-for-independent-heldout"
    elif analysis["fixedFailure"]:
        outcome_class = "futility"
        boundary = 2
        decision = "close-scoreline-commitment-after-component-crn"
    else:
        outcome_class = "inconclusive"
        boundary = 3
        decision = "record-scoreline-component-crn-inconclusive-at-cap"

    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "protocolSha256": protocol_sha,
        "outcomeClass": outcome_class,
        "decisionBoundary": boundary,
        "decision": decision,
        "analysis": analysis,
        "faults": sorted(set(faults)),
        "elapsedSeconds": round(elapsed, 6),
        "observedRows": len(observed),
        "newLedgerRows": ledger_after["records"] - ledger_before["records"],
        "ledgerAppendError": ledger_error,
        "executionError": execution_error,
        "outputs": {"planSha256": plan_sha, "outputSha256": output_sha},
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "claimBoundary": "Discovery component effects only; no held-out, RandomBuild, aspect-separation, package-admission, detector, product or P9 claim.",
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
