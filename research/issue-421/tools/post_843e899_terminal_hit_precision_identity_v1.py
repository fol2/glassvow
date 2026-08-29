#!/usr/bin/env python3
"""One-look direct identity preflight for #421 exact-lethal Facet salvage."""

from __future__ import annotations

import copy
import json
import subprocess
import tempfile
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-843e899-terminal-hit-precision-identity-v1.json"
SUMMARY = core.ROOT / "summaries/post-843e899-terminal-hit-precision-identity-v1.json"
BASELINE = core.ROOT / "terminal-hit-precision-v1-baseline-source"
CANDIDATE = core.ROOT / "terminal-hit-precision-v1-source"
PROBE = "res://tools/research_421_terminal_hit_precision_probe.gd"
PRECISION_EVENT = "research421TerminalHitPrecision"


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
        raise TimeoutError("terminal-hit precision preflight reached its wall-time cap")
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
        "candidateCombatDiffSha256": core.sha(
            subprocess.run(
                ["git", "diff", "--", "domain/rules/combat.gd"],
                cwd=CANDIDATE, check=True, capture_output=True,
            ).stdout
        ),
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
    source = (CANDIDATE / "domain/rules/combat.gd").read_text()
    baseline = (BASELINE / "domain/rules/combat.gd").read_text()
    checks = (
        ("baseline research marker absent", "research421TerminalHitPrecision" not in baseline),
        ("producer knob cardinality", source.count("_research421_precision_producer") == 4),
        ("consumer knob cardinality", source.count("_research421_precision_consumer") == 4),
        ("configuration interface cardinality",
         source.count("configure_research421_terminal_hit_precision") == 1),
        ("mediator key cardinality",
         source.count("research421ExactLethalIntrinsic") == 2),
        ("telemetry surface cardinality",
         source.count("research421TerminalHitPrecision") == 5),
        ("no random call", "rand" not in "\n".join(
            line for line in source.splitlines() if "research421" in line.lower()
        ).lower()),
        ("no persistent state field",
         "research421" not in (CANDIDATE / "domain/state/combat_state.gd").read_text().lower()),
        ("no save surface",
         "research421" not in (CANDIDATE / "domain/state/run_state.gd").read_text().lower()),
        ("no event-type surface",
         "research421" not in (CANDIDATE / "domain/events/event_types.gd").read_text().lower()),
        ("no policy surface",
         "research421" not in (CANDIDATE / "tools/balance_policy.gd").read_text().lower()),
    )
    return [label for label, passed in checks if not passed]


def arm_rows(scenarios: list[dict[str, Any]], arm: str) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for scenario in scenarios:
        row = copy.deepcopy(scenario["row"])
        row["id"] = f"{arm}-{scenario['id']}"
        if arm != "baseline" and arm != "omitted":
            row["producer"] = arm in ("a", "ab")
            row["consumer"] = arm in ("b", "ab")
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
        dir=core.WORK, prefix="terminal-hit-precision-identity-"
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
    require(f"{arm} output plan identity", output.get("planSha256") == plan_sha)
    require(f"{arm} output row count", len(output.get("rows", [])) == len(rows))
    output_sha, _ = core.cache_json(output)
    return output, plan_sha, output_sha


def by_id(output: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {str(row["id"]): row for row in output["rows"]}


def normalise_metadata(row: dict[str, Any]) -> dict[str, Any]:
    result = copy.deepcopy(row)
    for key in ("id", "factorAvailable", "configured", "producer", "consumer"):
        result.pop(key, None)
    return result


def precision_events(row: dict[str, Any]) -> list[dict[str, Any]]:
    return [event for event in row["queue"] if event.get("t") == PRECISION_EVENT]


def compare_treatment(
    label: str,
    treated: dict[str, Any],
    control: dict[str, Any],
    expected: dict[str, Any],
    faults: list[str],
) -> None:
    def check(name: str, condition: bool) -> None:
        if not condition:
            faults.append(f"{label}: {name}")

    events = precision_events(treated)
    marks = int(expected["marks"])
    consumer = bool(expected["consumer"])
    realised = int(expected["realised"])
    expected_stages: list[str] = []
    for _ in range(marks):
        expected_stages.extend(("producer", "mediator-set"))
    if consumer:
        expected_stages.extend(("consumer", "payoff"))
    expected_stages.append("expiry")
    check("ordered research chain",
          [event.get("stage") for event in events] == expected_stages)

    producers = [event for event in events if event.get("stage") == "producer"]
    mediators = [event for event in events if event.get("stage") == "mediator-set"]
    check("producer targets",
          [event.get("idx") for event in producers] == expected["targets"])
    check("producer amounts",
          [event.get("amount") for event in producers] == expected["amounts"])
    check("producer block",
          [event.get("blocked") for event in producers] == expected["blocked"])
    check("producer exact-lethal fields", all(
        event.get("hpAfter") == 0 and event.get("killingBlow") is True
        and event.get("overkill") == 0 for event in producers
    ))
    check("mediator cardinality", len(mediators) == marks)
    check("mediator targets",
          [event.get("idx") for event in mediators] == expected["targets"])
    check("mediator intrinsic unit",
          all(event.get("intrinsic") == 1 for event in mediators))

    consumers = [event for event in events if event.get("stage") == "consumer"]
    payoffs = [event for event in events if event.get("stage") == "payoff"]
    expiries = [event for event in events if event.get("stage") == "expiry"]
    check("consumer cardinality", len(consumers) == int(consumer))
    check("payoff cardinality", len(payoffs) == int(consumer))
    if consumer:
        check("consumer aggregate", consumers[0].get("eligibleMarks") == marks)
        check("fixed payoff",
              payoffs[0].get("requested") == 1 and payoffs[0].get("realised") == realised)
    check("expiry cardinality", len(expiries) == 1)
    if expiries:
        check("expiry contract", expiries[0].get("eligibleMarks") == marks
              and expiries[0].get("reason") == expected["expiry"])

    precision_ember_indexes: set[int] = set()
    if consumer and len(consumers) == 1 and len(payoffs) == 1:
        queue = treated["queue"]
        consumer_index = next(
            i for i, event in enumerate(queue)
            if event.get("t") == PRECISION_EVENT and event.get("stage") == "consumer"
        )
        payoff_index = next(
            i for i, event in enumerate(queue)
            if event.get("t") == PRECISION_EVENT and event.get("stage") == "payoff"
        )
        between = [
            i for i in range(consumer_index + 1, payoff_index)
            if queue[i].get("t") != PRECISION_EVENT
        ]
        check("realised payoff event cardinality", len(between) == int(realised != 0))
        if realised != 0 and between:
            event = queue[between[0]]
            check("realised payoff event",
                  event.get("t") == "ember" and event.get("n") == realised)
            precision_ember_indexes.add(between[0])

    stripped_queue = [
        copy.deepcopy(event) for index, event in enumerate(treated["queue"])
        if event.get("t") != PRECISION_EVENT and index not in precision_ember_indexes
    ]
    check("queue isolation", stripped_queue == control["queue"])

    treated_core = normalise_metadata(treated)
    control_core = normalise_metadata(control)
    for value in (treated_core, control_core):
        for key in ("queue", "baselineEvents", "precisionEvents", "emberEvents"):
            value.pop(key, None)
    treated_core["state"]["embers"] -= realised
    check("state and path isolation", treated_core == control_core)
    check("pending mediator cleared",
          treated.get("pendingChipsActive") is False and treated.get("pendingChips") == {})
    check("RNG identity",
          treated.get("rngBefore") == control.get("rngBefore")
          and treated.get("rngAfter") == control.get("rngAfter"))


def direct_faults(
    protocol: dict[str, Any], baseline: dict[str, Any], candidate: dict[str, Any]
) -> list[str]:
    faults: list[str] = []
    base = by_id(baseline)
    cand = by_id(candidate)

    for scenario in protocol["directScenarios"]:
        name = scenario["id"]
        anchor = base[f"baseline-{name}"]
        omitted = cand[f"omitted-{name}"]
        off = cand[f"off-{name}"]
        ab = cand[f"ab-{name}"]
        for label, row in (("baseline", anchor), ("omitted", omitted), ("off", off),
                           ("ab", ab)):
            if row.get("error"):
                faults.append(f"{name}: {label} row error {row['error']}")
        if normalise_metadata(anchor) != normalise_metadata(omitted):
            faults.append(f"{name}: current-main versus omitted null")
        if normalise_metadata(anchor) != normalise_metadata(off):
            faults.append(f"{name}: current-main versus explicit-off null")
        if normalise_metadata(omitted) != normalise_metadata(off):
            faults.append(f"{name}: omitted versus explicit-off alias")
        expected = scenario["expectedPrecision"]
        if expected is None:
            if precision_events(ab):
                faults.append(f"{name}: unexpected research event")
            if normalise_metadata(ab) != normalise_metadata(off):
                faults.append(f"{name}: enabled null isolation")
        else:
            compare_treatment(name, ab, off, expected, faults)

    name = protocol["componentControlScenario"]
    off = cand[f"off-{name}"]
    a = cand[f"a-{name}"]
    b = cand[f"b-{name}"]
    expected = next(
        row["expectedPrecision"] for row in protocol["directScenarios"]
        if row["id"] == name
    )
    producer_only = copy.deepcopy(expected)
    producer_only["consumer"] = False
    producer_only["realised"] = 0
    producer_only["expiry"] = "consumer-disabled"
    compare_treatment("producer-only-A", a, off, producer_only, faults)
    if precision_events(b):
        faults.append("consumer-only-B: unexpected research event")
    if normalise_metadata(b) != normalise_metadata(off):
        faults.append("consumer-only-B: non-null without mediator")
    ab = cand[f"ab-{name}"]
    if precision_events(a)[:2] != precision_events(ab)[:2]:
        faults.append("A versus AB: producer or mediator drift")
    return faults


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite terminal-hit precision identity summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    immutable = protocol["immutableInputs"]
    actual_source = source_identity(protocol)
    require("immutable source identity drift", actual_source == {
        key: immutable[key] for key in actual_source
    })
    ledger_before = identity.ledger_identity()
    require("ledger freeze drift", ledger_before == protocol["ledgerFreeze"])
    source_gate_faults = static_faults()

    scenarios = protocol["directScenarios"]
    baseline_rows = arm_rows(scenarios, "baseline")
    candidate_rows = (
        arm_rows(scenarios, "omitted")
        + arm_rows(scenarios, "off")
        + arm_rows(scenarios, "ab")
    )
    component = next(row for row in scenarios
                     if row["id"] == protocol["componentControlScenario"])
    candidate_rows += arm_rows([component], "a") + arm_rows([component], "b")
    require("direct observation cap drift",
            len(baseline_rows) + len(candidate_rows)
            == protocol["budget"]["directControlledObservations"])

    started = time.monotonic()
    deadline = started + protocol["budget"]["maximumWallTimeSeconds"]
    outputs: dict[str, str] = {}
    plans: dict[str, str] = {}
    execution_error = ""
    faults = list(source_gate_faults)
    completed_rows = 0
    if not source_gate_faults:
        try:
            baseline, plans["baseline"], outputs["baseline"] = run_probe(
                BASELINE, baseline_rows, "current-main-baseline", protocol_sha,
                immutable["godotBinaryPath"], deadline,
            )
            candidate, plans["candidate"], outputs["candidate"] = run_probe(
                CANDIDATE, candidate_rows, "instrumented-fixed-matrix", protocol_sha,
                immutable["godotBinaryPath"], deadline,
            )
            completed_rows = len(baseline["rows"]) + len(candidate["rows"])
            faults.extend(direct_faults(protocol, baseline, candidate))
        except (OSError, subprocess.SubprocessError, TimeoutError, RuntimeError) as error:
            execution_error = str(error)

    ledger_after = identity.ledger_identity()
    if ledger_after != ledger_before:
        faults.append("append-only ledger changed")
    elapsed = time.monotonic() - started
    if execution_error or elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        outcome = "inconclusive"
        decision = "record-terminal-hit-precision-identity-inconclusive-at-cap"
        boundary = 3
    elif faults:
        outcome = "futility"
        decision = "close-exact-lethal-precision-and-advance-to-positive-overkill"
        boundary = 2
    else:
        outcome = "success"
        decision = "freeze-terminal-hit-facet-salvage-for-natural-capacity"
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
        "directFaults": faults,
        "executionError": execution_error,
        "planSha256": plans,
        "outputSha256": outputs,
        "GodotProcesses": 0 if source_gate_faults else len(outputs),
        "directControlledObservations": completed_rows,
        "newSimulatorObservationRows": 0,
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
        "rows": completed_rows,
        "wallTimeSeconds": round(elapsed, 3),
    }, sort_keys=True))


if __name__ == "__main__":
    main()
