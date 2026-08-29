#!/usr/bin/env python3
"""Existing-policy natural capacity check for #421 exact-lethal Facet salvage."""

from __future__ import annotations

import copy
import json
import subprocess
import tempfile
import time
from collections import Counter
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-843e899-terminal-hit-precision-capacity-v1.json"
SUMMARY = core.ROOT / "summaries/post-843e899-terminal-hit-precision-capacity-v1.json"
BASELINE = core.ROOT / "terminal-hit-precision-capacity-v1-baseline-source"
CANDIDATE = core.ROOT / "terminal-hit-precision-capacity-v1-source"
PROBE = "res://tools/research_421_terminal_hit_precision_capacity_probe.gd"
PREFIX = "terminalHitPrecision"


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
        raise TimeoutError("terminal-hit precision capacity reached its wall-time cap")
    return remaining


def source_identity(protocol: dict[str, Any]) -> dict[str, Any]:
    immutable = protocol["immutableInputs"]
    repository = Path(immutable["repositoryPath"])
    godot = Path(immutable["godotBinaryPath"])
    return {
        "repositoryRefs": {
            ref: git(repository, "rev-parse", ref)
            for ref in immutable["repositoryRefs"]
        },
        "baselineHead": git(BASELINE, "rev-parse", "HEAD"),
        "candidateHead": git(CANDIDATE, "rev-parse", "HEAD"),
        "baselineStatus": git(BASELINE, "status", "--porcelain=v1").splitlines(),
        "candidateStatus": git(CANDIDATE, "status", "--porcelain=v1").splitlines(),
        "baselineSha256": {
            name: core.file_sha(BASELINE / name)
            for name in immutable["baselineSha256"]
        },
        "candidateSha256": {
            name: core.file_sha(CANDIDATE / name)
            for name in immutable["candidateSha256"]
        },
        "candidateDiffSha256": {
            name: core.sha(subprocess.run(
                ["git", "diff", "--", name], cwd=CANDIDATE,
                check=True, capture_output=True,
            ).stdout)
            for name in immutable["candidateDiffSha256"]
        },
        "godotVersion": subprocess.run(
            [str(godot), "--version"], check=True, text=True, capture_output=True,
        ).stdout.strip(),
        "godotBinarySha256": core.file_sha(godot),
        "runnerSha256": core.file_sha(Path(__file__)),
        "taskCapsuleSha256": core.file_sha(core.ROOT / immutable["taskCapsulePath"]),
        "predecessorSha256": {
            name: core.file_sha(core.ROOT / name)
            for name in immutable["predecessorSha256"]
        },
    }


def static_faults() -> list[str]:
    combat = (CANDIDATE / "domain/rules/combat.gd").read_text()
    sim = (CANDIDATE / "tools/balance_sim.gd").read_text()
    baseline_sim = (BASELINE / "tools/balance_sim.gd").read_text()
    checks = (
        ("baseline telemetry absent", PREFIX not in baseline_sim),
        ("producer knob cardinality", combat.count("_research421_precision_producer") == 4),
        ("consumer knob cardinality", combat.count("_research421_precision_consumer") == 4),
        ("configuration interface cardinality",
         combat.count("configure_research421_terminal_hit_precision") == 1),
        ("mediator key cardinality", combat.count("research421ExactLethalIntrinsic") == 2),
        ("direct telemetry cardinality", combat.count("research421TerminalHitPrecision") == 5),
        ("capacity telemetry branch cardinality",
         sim.count('kind == "research421TerminalHitPrecision"') == 1),
        ("eligible-card counter cardinality",
         sim.count('"terminalHitPrecisionEligibleCards"') == 1),
        ("no policy implementation", "research421" not in
         (CANDIDATE / "tools/balance_policy.gd").read_text().lower()),
        ("no persistent combat field", "research421" not in
         (CANDIDATE / "domain/state/combat_state.gd").read_text().lower()),
        ("no persistent run field", "research421" not in
         (CANDIDATE / "domain/state/run_state.gd").read_text().lower()),
    )
    return [label for label, passed in checks if not passed]


def cohort_rows(protocol: dict[str, Any], instrumented: bool) -> list[dict[str, Any]]:
    cohort = protocol["cohort"]
    rows: list[dict[str, Any]] = []
    for policy_index in range(cohort["policyCount"]):
        for seed in cohort["simulationSeeds"]:
            row = {
                "policyRoot": cohort["policyRoot"],
                "policyIndex": policy_index,
                "seed": seed,
                "aspect": cohort["aspect"],
                "vow": cohort["vow"],
            }
            if instrumented:
                row["producer"] = True
                row["consumer"] = False
            rows.append(row)
    return rows


def run_probe(
    source: Path,
    rows: list[dict[str, Any]],
    arm: str,
    protocol_sha: str,
    godot: str,
    deadline: float,
) -> tuple[dict[str, Any], str, str]:
    plan = {
        "schemaVersion": 1,
        "protocolSha256": protocol_sha,
        "arm": arm,
        "content": str(source / "content/full-content.json"),
        "rows": rows,
    }
    plan_sha, plan_path = core.cache_json(plan)
    core.WORK.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(
        dir=core.WORK, prefix="terminal-hit-precision-capacity-"
    ) as tmp:
        output_path = Path(tmp) / "output.json"
        result = subprocess.run(
            [godot, "--headless", "-s", PROBE, "--",
             f"--plan={plan_path}", f"--out={output_path}"],
            cwd=source, text=True, capture_output=True,
            timeout=seconds_left(deadline),
        )
        if result.returncode != 0 or not output_path.is_file():
            raise RuntimeError(
                f"{arm} probe failed ({result.returncode})\n"
                f"{result.stdout[-2000:]}\n{result.stderr[-4000:]}"
            )
        output = json.loads(output_path.read_text())
    require(f"{arm} plan identity", output.get("planSha256") == plan_sha)
    require(f"{arm} row count", len(output.get("rows", [])) == len(rows))
    output_sha, _ = core.cache_json(output)
    return output, plan_sha, output_sha


def research_metrics(row: dict[str, Any]) -> dict[str, int]:
    return {
        key: int(value) for key, value in row.get("packageEvents", {}).items()
        if key.startswith(PREFIX)
    }


def normalise(row: dict[str, Any]) -> dict[str, Any]:
    result = copy.deepcopy(row)
    for key in list(result):
        if key.startswith("research421"):
            result.pop(key)
    result["packageEvents"] = {
        key: value for key, value in result.get("packageEvents", {}).items()
        if not key.startswith(PREFIX)
    }
    return result


def analyse(
    protocol: dict[str, Any], baseline: dict[str, Any], candidate: dict[str, Any]
) -> tuple[dict[str, Any], list[str]]:
    faults: list[str] = []
    base_rows = baseline["rows"]
    candidate_rows = candidate["rows"]
    policy_rows: dict[int, list[dict[str, Any]]] = {
        index: [] for index in range(protocol["cohort"]["policyCount"])
    }
    card_counts: Counter[str] = Counter()
    total = Counter()
    for index, (base, observed) in enumerate(zip(base_rows, candidate_rows, strict=True)):
        policy = int(observed.get("research421PolicyIndex", -1))
        if policy != index // len(protocol["cohort"]["simulationSeeds"]):
            faults.append(f"row {index}: policy order")
        if observed.get("research421FactorAvailable") is not True \
                or observed.get("research421Configured") is not True \
                or observed.get("research421Producer") is not True \
                or observed.get("research421Consumer") is not False:
            faults.append(f"row {index}: A-only factor identity")
        if normalise(base) != normalise(observed):
            faults.append(f"row {index}: current-main path/result/RNG identity")

        metrics = research_metrics(observed)
        producer = metrics.get(f"{PREFIX}Producer", 0)
        mediator = metrics.get(f"{PREFIX}MediatorSet", 0)
        expiry = metrics.get(f"{PREFIX}Expiry", 0)
        eligible_cards = metrics.get(f"{PREFIX}EligibleCards", 0)
        eligible_marks = metrics.get(f"{PREFIX}EligibleMarks", 0)
        final_cards = metrics.get(f"{PREFIX}ExpiryCombatOver", 0)
        final_marks = metrics.get(f"{PREFIX}FinalMarks", 0)
        if producer != mediator:
            faults.append(f"row {index}: producer/mediator cardinality")
        if expiry != eligible_cards + final_cards:
            faults.append(f"row {index}: expiry partition")
        if producer != eligible_marks + final_marks:
            faults.append(f"row {index}: mark partition")
        if eligible_cards > eligible_marks:
            faults.append(f"row {index}: eligible card/mark ordering")
        for forbidden in ("Consumer", "Payoff", "Requested", "Realised", "ExpiryConsumed"):
            if metrics.get(f"{PREFIX}{forbidden}", 0) != 0:
                faults.append(f"row {index}: A-only emitted {forbidden}")
        for key, value in metrics.items():
            if value < 0:
                faults.append(f"row {index}: negative telemetry {key}")
            if key.startswith(f"{PREFIX}EligibleCard_"):
                card_counts[key.removeprefix(f"{PREFIX}EligibleCard_")] += value
        total.update(metrics)
        policy_rows[policy].append({
            "seed": observed["seed"],
            "producer": producer,
            "eligibleCards": eligible_cards,
            "outcome": observed.get("outcome"),
            "error": observed.get("error", ""),
        })

    minimum = protocol["cohort"]["minimumRowsPerRobustPolicy"]
    exposure_active: list[int] = []
    active: list[int] = []
    inactive: list[int] = []
    ambiguous: list[int] = []
    viable: list[int] = []
    for policy, rows in policy_rows.items():
        exposure_rows = sum(row["producer"] > 0 for row in rows)
        eligible_rows = sum(row["eligibleCards"] > 0 for row in rows)
        if exposure_rows >= minimum:
            exposure_active.append(policy)
        if eligible_rows >= minimum:
            active.append(policy)
            if any(row["eligibleCards"] > 0 and row["outcome"] == "win" for row in rows):
                viable.append(policy)
        elif eligible_rows == 0:
            inactive.append(policy)
        else:
            ambiguous.append(policy)

    baseline_fault_rows = sum(
        row.get("outcome") in ("stall", "error") or bool(row.get("error"))
        for row in base_rows
    )
    counts = {
        "exposureActivePolicies": len(exposure_active),
        "activePolicies": len(active),
        "exactInactivePolicies": len(inactive),
        "ambiguousPolicies": len(ambiguous),
        "viablePolicies": len(viable),
        "distinctEligibleCards": len(card_counts),
        "baselineFaultRows": baseline_fault_rows,
        "producerMarks": total.get(f"{PREFIX}Producer", 0),
        "eligibleCards": total.get(f"{PREFIX}EligibleCards", 0),
        "eligibleMarks": total.get(f"{PREFIX}EligibleMarks", 0),
        "finalCards": total.get(f"{PREFIX}ExpiryCombatOver", 0),
        "multiMarkCards": total.get(f"{PREFIX}MultiMarkCards", 0),
    }
    gates = protocol["gates"]
    checks = {
        "exactIdentity": not any("identity" in fault for fault in faults),
        "semanticAttribution": not any("identity" not in fault for fault in faults),
        "activeSupport": counts["activePolicies"] >= gates["minimumActivePolicies"],
        "inactiveSupport": counts["exactInactivePolicies"] >= gates["minimumExactInactivePolicies"],
        "viableSupport": counts["viablePolicies"] >= gates["minimumViablePolicies"],
        "exposureSupport": counts["exposureActivePolicies"] >= gates["minimumExposureActivePolicies"],
        "cardBreadth": counts["distinctEligibleCards"] >= gates["minimumDistinctEligibleCards"],
        "baselineReliability": baseline_fault_rows <= gates["maximumBaselineFaultRows"],
    }
    return {
        "counts": counts,
        "checks": checks,
        "policySets": {
            "exposureActive": exposure_active,
            "active": active,
            "exactInactive": inactive,
            "ambiguous": ambiguous,
            "viable": viable,
        },
        "eligibleCardCounts": dict(sorted(card_counts.items())),
        "telemetryTotals": dict(sorted(total.items())),
    }, faults


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite terminal-hit precision capacity summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    immutable = protocol["immutableInputs"]
    actual_source = source_identity(protocol)
    require("immutable source identity drift", actual_source == {
        key: immutable[key] for key in actual_source
    })
    ledger_before = identity.ledger_identity()
    require("ledger freeze drift", ledger_before == protocol["ledgerFreeze"])
    source_gate_faults = static_faults()
    baseline_rows = cohort_rows(protocol, False)
    candidate_rows = cohort_rows(protocol, True)
    require("row budget drift", len(baseline_rows) + len(candidate_rows)
            == protocol["budget"]["newScientificSimulatorObservationRows"])

    started = time.monotonic()
    deadline = started + protocol["budget"]["maximumWallTimeSeconds"]
    plans: dict[str, str] = {}
    outputs: dict[str, str] = {}
    execution_error = ""
    analysis: dict[str, Any] = {}
    faults = list(source_gate_faults)
    completed_rows = 0
    if not source_gate_faults:
        try:
            baseline, plans["baseline"], outputs["baseline"] = run_probe(
                BASELINE, baseline_rows, "current-main", protocol_sha,
                immutable["godotBinaryPath"], deadline,
            )
            candidate, plans["producerOnly"], outputs["producerOnly"] = run_probe(
                CANDIDATE, candidate_rows, "producer-only-A", protocol_sha,
                immutable["godotBinaryPath"], deadline,
            )
            completed_rows = len(baseline["rows"]) + len(candidate["rows"])
            analysis, analysis_faults = analyse(protocol, baseline, candidate)
            faults.extend(analysis_faults)
        except (OSError, subprocess.SubprocessError, TimeoutError, RuntimeError) as error:
            execution_error = str(error)

    ledger_after = identity.ledger_identity()
    if ledger_after != ledger_before:
        faults.append("append-only ledger changed")
    elapsed = time.monotonic() - started
    checks_pass = bool(analysis) and all(analysis["checks"].values())
    if execution_error or elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        outcome = "inconclusive"
        decision = "record-terminal-hit-precision-capacity-inconclusive-at-cap"
        boundary = 3
    elif faults or not checks_pass:
        outcome = "futility"
        decision = "close-exact-lethal-precision-and-advance-to-positive-overkill"
        boundary = 2
    else:
        outcome = "success"
        decision = "freeze-terminal-hit-facet-salvage-for-crn-first-look"
        boundary = 1

    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "outcomeClass": outcome,
        "decision": decision,
        "decisionBoundary": boundary,
        "claimBoundary": protocol["claimBoundary"],
        "authority": protocol["decisionRules"][outcome + "Authority"],
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "sourceIdentity": actual_source,
        "sourceGateFaults": source_gate_faults,
        "faults": faults,
        "executionError": execution_error,
        "analysis": analysis,
        "planSha256": plans,
        "outputSha256": outputs,
        "GodotProcesses": len(outputs),
        "observedRows": completed_rows,
        "newSimulatorObservationRows": completed_rows,
        "newLedgerRows": ledger_after["records"] - ledger_before["records"],
        "protectedSeedRows": ledger_after["protectedSeedRows"],
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "wallTimeSeconds": elapsed,
        "maximumModelContextTokensDuringExecutionAndDecision": 0,
        "archiveHeadPreserved": immutable["repositoryRefs"][
            "refs/remotes/origin/research/issue-421-post-reshuffle-frontier-evidence"
        ],
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "outcomeClass": outcome,
        "decision": decision,
        "faults": len(faults),
        "checks": analysis.get("checks", {}),
        "counts": analysis.get("counts", {}),
        "rows": completed_rows,
        "wallTimeSeconds": round(elapsed, 3),
    }, sort_keys=True))


if __name__ == "__main__":
    main()
