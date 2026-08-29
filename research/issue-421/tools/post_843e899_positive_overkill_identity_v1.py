#!/usr/bin/env python3
"""One-look direct identity preflight for #421 positive-overkill Facet salvage."""

from __future__ import annotations

import copy
import json
import subprocess
import time
from pathlib import Path
from typing import Any

import post_843e899_terminal_hit_precision_identity_v1 as direct
import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-843e899-positive-overkill-identity-v1.json"
SUMMARY = core.ROOT / "summaries/post-843e899-positive-overkill-identity-v1.json"
BASELINE = core.ROOT / "positive-overkill-v1-baseline-source"
CANDIDATE = core.ROOT / "positive-overkill-v1-source"
PROBE = "res://tools/research_421_positive_overkill_probe.gd"


direct.BASELINE = BASELINE
direct.CANDIDATE = CANDIDATE
direct.PROBE = PROBE
direct.PRECISION_EVENT = "research421PositiveOverkill"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(label)


def static_faults() -> list[str]:
    source = (CANDIDATE / "domain/rules/combat.gd").read_text()
    baseline = (BASELINE / "domain/rules/combat.gd").read_text()
    checks = (
        ("baseline research marker absent", "research421PositiveOverkill" not in baseline),
        ("producer knob cardinality", source.count("_research421_excess_producer") == 4),
        ("consumer knob cardinality", source.count("_research421_excess_consumer") == 4),
        ("configuration interface cardinality",
         source.count("configure_research421_positive_overkill") == 1),
        ("mediator key cardinality",
         source.count("research421PositiveOverkillIntrinsic") == 2),
        ("telemetry surface cardinality",
         source.count('"t": &"research421PositiveOverkill"') == 5),
        ("no random call", "rand" not in "\n".join(
            line for line in source.splitlines() if "research421" in line.lower()
        ).lower()),
        ("no persistent state field", "research421" not in
         (CANDIDATE / "domain/state/combat_state.gd").read_text().lower()),
        ("no save surface", "research421" not in
         (CANDIDATE / "domain/state/run_state.gd").read_text().lower()),
        ("no event-type surface", "research421" not in
         (CANDIDATE / "domain/events/event_types.gd").read_text().lower()),
        ("no policy surface", "research421" not in
         (CANDIDATE / "tools/balance_policy.gd").read_text().lower()),
    )
    return [label for label, passed in checks if not passed]


def source_identity(protocol: dict[str, Any]) -> dict[str, Any]:
    result = direct.source_identity(protocol)
    result["runnerSha256"] = core.file_sha(Path(__file__))
    return result


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

    events = direct.precision_events(treated)
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
    check("producer targets", [event.get("idx") for event in producers] == expected["targets"])
    check("producer amounts", [event.get("amount") for event in producers] == expected["amounts"])
    check("producer block", [event.get("blocked") for event in producers] == expected["blocked"])
    check("producer overkill", [event.get("overkill") for event in producers]
          == expected["overkill"])
    check("producer terminal fields", all(
        event.get("hpAfter") == 0 and event.get("killingBlow") is True
        and int(event.get("overkill", 0)) > 0 for event in producers
    ))
    check("mediator cardinality", len(mediators) == marks)
    check("mediator targets", [event.get("idx") for event in mediators] == expected["targets"])
    check("mediator intrinsic unit", all(event.get("intrinsic") == 1 for event in mediators))

    consumers = [event for event in events if event.get("stage") == "consumer"]
    payoffs = [event for event in events if event.get("stage") == "payoff"]
    expiries = [event for event in events if event.get("stage") == "expiry"]
    check("consumer cardinality", len(consumers) == int(consumer))
    check("payoff cardinality", len(payoffs) == int(consumer))
    if consumer:
        check("consumer aggregate", len(consumers) == 1
              and consumers[0].get("eligibleMarks") == marks)
        check("fixed payoff", len(payoffs) == 1
              and payoffs[0].get("requested") == 1
              and payoffs[0].get("realised") == realised)
    check("expiry cardinality", len(expiries) == 1)
    if expiries:
        check("expiry contract", expiries[0].get("eligibleMarks") == marks
              and expiries[0].get("reason") == expected["expiry"])

    precision_ember_indexes: set[int] = set()
    if consumer and len(consumers) == 1 and len(payoffs) == 1:
        queue = treated["queue"]
        consumer_index = next(
            i for i, event in enumerate(queue)
            if event.get("t") == direct.PRECISION_EVENT and event.get("stage") == "consumer"
        )
        payoff_index = next(
            i for i, event in enumerate(queue)
            if event.get("t") == direct.PRECISION_EVENT and event.get("stage") == "payoff"
        )
        between = [
            i for i in range(consumer_index + 1, payoff_index)
            if queue[i].get("t") != direct.PRECISION_EVENT
        ]
        check("realised payoff event cardinality", len(between) == int(realised != 0))
        if realised != 0 and between:
            event = queue[between[0]]
            check("realised payoff event",
                  event.get("t") == "ember" and event.get("n") == realised)
            precision_ember_indexes.add(between[0])

    stripped_queue = [
        copy.deepcopy(event) for index, event in enumerate(treated["queue"])
        if event.get("t") != direct.PRECISION_EVENT and index not in precision_ember_indexes
    ]
    check("queue isolation", stripped_queue == control["queue"])
    treated_core = direct.normalise_metadata(treated)
    control_core = direct.normalise_metadata(control)
    for value in (treated_core, control_core):
        for key in ("queue", "baselineEvents", "precisionEvents", "emberEvents"):
            value.pop(key, None)
    treated_core["state"]["embers"] -= realised
    check("state and path isolation", treated_core == control_core)
    check("pending mediator cleared",
          treated.get("pendingChipsActive") is False and treated.get("pendingChips") == {})
    check("RNG identity", treated.get("rngBefore") == control.get("rngBefore")
          and treated.get("rngAfter") == control.get("rngAfter"))


direct.compare_treatment = compare_treatment


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite positive-overkill identity summary")
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
    baseline_rows = direct.arm_rows(scenarios, "baseline")
    candidate_rows = (
        direct.arm_rows(scenarios, "omitted")
        + direct.arm_rows(scenarios, "off")
        + direct.arm_rows(scenarios, "ab")
    )
    component = next(row for row in scenarios
                     if row["id"] == protocol["componentControlScenario"])
    candidate_rows += direct.arm_rows([component], "a") + direct.arm_rows([component], "b")
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
            baseline, plans["baseline"], outputs["baseline"] = direct.run_probe(
                BASELINE, baseline_rows, "current-main-baseline", protocol_sha,
                immutable["godotBinaryPath"], deadline,
            )
            candidate, plans["candidate"], outputs["candidate"] = direct.run_probe(
                CANDIDATE, candidate_rows, "instrumented-fixed-matrix", protocol_sha,
                immutable["godotBinaryPath"], deadline,
            )
            completed_rows = len(baseline["rows"]) + len(candidate["rows"])
            faults.extend(direct.direct_faults(protocol, baseline, candidate))
        except (OSError, subprocess.SubprocessError, RuntimeError, TimeoutError) as error:
            execution_error = str(error)

    ledger_after = identity.ledger_identity()
    if ledger_after != ledger_before:
        faults.append("append-only ledger changed")
    elapsed = time.monotonic() - started
    if execution_error or elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        outcome = "inconclusive"
        decision = "record-positive-overkill-identity-inconclusive-at-cap"
        boundary = 3
    elif faults:
        outcome = "futility"
        decision = "close-positive-overkill-and-terminal-hit-class"
        boundary = 2
    else:
        outcome = "success"
        decision = "freeze-positive-overkill-facet-salvage-for-natural-capacity"
        boundary = 1

    summary: dict[str, Any] = {
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
        "GodotProcesses": len(outputs),
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
        "outcomeClass": outcome, "decision": decision, "faults": len(faults),
        "rows": completed_rows, "wallTimeSeconds": round(elapsed, 3),
    }, sort_keys=True))


if __name__ == "__main__":
    main()
