#!/usr/bin/env python3
"""One-look direct identity preflight for #421 private Ember overflow."""

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


PROTOCOL = core.ROOT / "protocols/post-d486-private-overflow-identity-v1.json"
SUMMARY = core.ROOT / "summaries/post-d486-private-overflow-identity-v1.json"
BASELINE = core.ROOT / "post-d486-private-overflow-v1-baseline"
CANDIDATE = core.ROOT / "post-d486-private-overflow-v1-source"
PROBE = "res://tools/research_421_ember_overflow_probe.gd"
OVERFLOW_EVENT = "research421EmberOverflow"


direct.BASELINE = BASELINE
direct.CANDIDATE = CANDIDATE
direct.PROBE = PROBE


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(label)


def git(path: Path, *args: str) -> str:
    return subprocess.run(
        ["git", *args], cwd=path, check=True, text=True, capture_output=True,
    ).stdout.strip()


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
        "candidatePrototypeDiffSha256": core.sha(subprocess.run(
            ["git", "diff", "--", "domain/rules/combat.gd",
             "domain/state/player_combatant.gd"],
            cwd=CANDIDATE, check=True, capture_output=True,
        ).stdout),
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
    player = (CANDIDATE / "domain/state/player_combatant.gd").read_text()
    baseline = (
        (BASELINE / "domain/rules/combat.gd").read_text()
        + (BASELINE / "domain/state/player_combatant.gd").read_text()
    )
    projection = player.split("func to_dict()", 1)[1]
    research_lines = "\n".join(
        line for line in combat.splitlines() if "research421" in line.lower()
    )
    checks = (
        ("baseline research marker absent", "research421" not in baseline.lower()),
        ("producer knob cardinality", combat.count("_research421_overflow_producer") == 3),
        ("consumer knob cardinality", combat.count("_research421_overflow_consumer") == 4),
        ("configuration interface cardinality",
         combat.count("configure_research421_ember_overflow") == 1),
        ("private mediator declaration cardinality",
         player.count("research421_ember_overflow") == 1),
        ("private mediator omitted from projection",
         "research421_ember_overflow" not in projection),
        ("telemetry surface cardinality",
         combat.count('"t": &"research421EmberOverflow"') == 6),
        ("lifecycle helper cardinality",
         combat.count("_expire_research421_overflow") == 4),
        ("no random call", "rand" not in research_lines.lower()),
        ("no combat-state surface", "research421" not in
         (CANDIDATE / "domain/state/combat_state.gd").read_text().lower()),
        ("no save surface", "research421" not in
         (CANDIDATE / "domain/state/run_state.gd").read_text().lower()),
        ("no event-type surface", "research421" not in
         (CANDIDATE / "domain/events/event_types.gd").read_text().lower()),
        ("no policy surface", "research421" not in
         (CANDIDATE / "tools/balance_policy.gd").read_text().lower()),
    )
    return [label for label, passed in checks if not passed]


def rows_by_id(output: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {str(row["id"]): row for row in output["rows"]}


def overflow_events(row: dict[str, Any]) -> list[dict[str, Any]]:
    return [
        event for event in row["queue"]
        if event.get("t") == OVERFLOW_EVENT
    ]


def normalise(row: dict[str, Any], damage_delta: int = 0) -> dict[str, Any]:
    result = copy.deepcopy(row)
    for key in (
        "id", "factorAvailable", "configured", "producer", "consumer",
        "researchMark", "baselineEvents", "overflowEvents",
    ):
        result.pop(key, None)
    result["queue"] = [
        event for event in result["queue"]
        if event.get("t") != OVERFLOW_EVENT
    ]
    for action in result["actions"]:
        action.pop("markAfter", None)
    if damage_delta == 0:
        return result

    heavy_actions = [
        action for action in result["actions"]
        if action.get("kind") == "play" and action.get("card") == "heavyBlow"
    ]
    require("damage normaliser Heavy Blow cardinality", len(heavy_actions) == 1)
    preview = heavy_actions[0]["preview"]
    preview["hits"][0]["dmg"] -= damage_delta
    preview["total"] -= damage_delta
    preview["loss"] -= damage_delta

    hits = [
        event for event in result["queue"]
        if event.get("t") == "hitEnemy" and event.get("idx") == 0
    ]
    require("damage normaliser hit cardinality", len(hits) == 1)
    hits[0]["amount"] -= damage_delta
    hits[0]["hpAfter"] += damage_delta
    result["state"]["enemies"][0]["hp"] += damage_delta
    result["runStats"]["dmgDealt"] -= damage_delta
    return result


def check_event_chain(
    label: str, row: dict[str, Any], expected: dict[str, Any], faults: list[str]
) -> None:
    def check(name: str, condition: bool) -> None:
        if not condition:
            faults.append(f"{label}: {name}")

    events = overflow_events(row)
    check("ordered event chain",
          [event.get("stage") for event in events] == expected["stages"])
    check("action mediator states",
          [action.get("markAfter") for action in row["actions"]]
          == expected["actionMarks"])
    check("final mediator clear", row.get("researchMark") == 0)

    producers = [event for event in events if event.get("stage") == "producer"]
    if expected.get("producer") is None:
        check("producer absent", not producers)
    else:
        producer = expected["producer"]
        check("producer cardinality", len(producers) == 1)
        if producers:
            check("producer attribution", all(
                producers[0].get(key) == value for key, value in producer.items()
            ))
    mediators = [event for event in events if event.get("stage") == "mediator-set"]
    check("mediator cardinality", len(mediators) == int(expected.get("producer") is not None))
    if mediators:
        check("mediator is one bit", mediators[0].get("mark") == 1)

    consumers = [event for event in events if event.get("stage") == "consumer"]
    payoffs = [event for event in events if event.get("stage") == "payoff"]
    consumed = [event for event in events if event.get("stage") == "mediator-consumed"]
    payoff = int(expected.get("damageDelta", 0))
    check("consumer cardinality", len(consumers) == int(payoff > 0))
    check("mediator-consumed cardinality", len(consumed) == int(payoff > 0))
    check("payoff cardinality", len(payoffs) == int(payoff > 0))
    if payoff > 0 and consumers and consumed and payoffs:
        check("exact consumer", consumers[0].get("id") == "heavyBlow")
        check("mediator consumed", consumed[0].get("mark") == 0)
        check("fixed payoff", payoffs[0].get("operation") == "incremental-damage"
              and payoffs[0].get("n") == payoff)

    expiries = [event for event in events if event.get("stage") == "expiry"]
    expiry = expected.get("expiry")
    check("expiry cardinality", len(expiries) == int(expiry is not None))
    if expiry is not None and expiries:
        check("expiry boundary", expiries[0].get("reason") == expiry
              and expiries[0].get("mark") == 1)


def check_damage_delta(
    label: str, treated: dict[str, Any], control: dict[str, Any], delta: int,
    faults: list[str],
) -> None:
    def check(name: str, condition: bool) -> None:
        if not condition:
            faults.append(f"{label}: {name}")

    treated_heavy = next(
        action for action in treated["actions"]
        if action.get("kind") == "play" and action.get("card") == "heavyBlow"
    )
    control_heavy = next(
        action for action in control["actions"]
        if action.get("kind") == "play" and action.get("card") == "heavyBlow"
    )
    tp = treated_heavy["preview"]
    cp = control_heavy["preview"]
    check("preview hit delta", tp["hits"][0]["dmg"] - cp["hits"][0]["dmg"] == delta)
    check("preview total delta", tp["total"] - cp["total"] == delta)
    check("preview loss delta", tp["loss"] - cp["loss"] == delta)

    treated_hits = [event for event in treated["baselineEvents"]
                    if event.get("t") == "hitEnemy" and event.get("idx") == 0]
    control_hits = [event for event in control["baselineEvents"]
                    if event.get("t") == "hitEnemy" and event.get("idx") == 0]
    check("one-hit attribution", len(treated_hits) == len(control_hits) == 1)
    if len(treated_hits) == len(control_hits) == 1:
        check("realised damage delta",
              treated_hits[0]["amount"] - control_hits[0]["amount"] == delta)
        check("target HP event delta",
              control_hits[0]["hpAfter"] - treated_hits[0]["hpAfter"] == delta)
    check("state target HP delta",
          control["state"]["enemies"][0]["hp"]
          - treated["state"]["enemies"][0]["hp"] == delta)
    check("damage statistic delta",
          treated["runStats"]["dmgDealt"] - control["runStats"]["dmgDealt"] == delta)


def direct_faults(
    protocol: dict[str, Any], baseline: dict[str, Any], candidate: dict[str, Any]
) -> list[str]:
    faults: list[str] = []
    base = rows_by_id(baseline)
    cand = rows_by_id(candidate)

    for scenario in protocol["directScenarios"]:
        name = scenario["id"]
        anchor = base[f"baseline-{name}"]
        omitted = cand[f"omitted-{name}"]
        off = cand[f"off-{name}"]
        ab = cand[f"ab-{name}"]
        for arm, row in (("baseline", anchor), ("omitted", omitted),
                         ("off", off), ("AB", ab)):
            if row.get("error"):
                faults.append(f"{name}: {arm} row error {row['error']}")
        if anchor.get("factorAvailable") is not False:
            faults.append(f"{name}: current-main unexpectedly exposes interface")
        if any(row.get("factorAvailable") is not True for row in (omitted, off, ab)):
            faults.append(f"{name}: candidate interface unavailable")
        if normalise(anchor) != normalise(omitted):
            faults.append(f"{name}: current-main versus omitted null")
        if normalise(anchor) != normalise(off):
            faults.append(f"{name}: current-main versus explicit-off null")
        if normalise(omitted) != normalise(off):
            faults.append(f"{name}: omitted versus explicit-off alias")

        expected = scenario["expected"]
        check_event_chain(name, ab, expected, faults)
        delta = int(expected.get("damageDelta", 0))
        if delta > 0:
            check_damage_delta(name, ab, off, delta, faults)
        if normalise(ab, delta) != normalise(off):
            faults.append(f"{name}: intended-mediator isolation")
        if ab.get("rngBefore") != off.get("rngBefore") \
                or ab.get("rngAfter") != off.get("rngAfter"):
            faults.append(f"{name}: RNG identity")

    name = protocol["componentControlScenario"]
    off = cand[f"off-{name}"]
    a = cand[f"a-{name}"]
    b = cand[f"b-{name}"]
    component_expected = {
        "stages": ["producer", "mediator-set", "expiry"],
        "producer": protocol["componentProducer"],
        "actionMarks": [1, 1, 0],
        "damageDelta": 0,
        "expiry": "end-turn",
    }
    check_event_chain("producer-only-A", a, component_expected, faults)
    if normalise(a) != normalise(off):
        faults.append("producer-only-A: non-telemetry path change")
    if overflow_events(b):
        faults.append("consumer-only-B: event without mediator")
    if normalise(b) != normalise(off):
        faults.append("consumer-only-B: non-null without mediator")
    ab = cand[f"ab-{name}"]
    if overflow_events(a)[:2] != overflow_events(ab)[:2]:
        faults.append("A versus AB: producer or mediator drift")
    return faults


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite private-overflow identity summary")
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
    component = next(
        row for row in scenarios if row["id"] == protocol["componentControlScenario"]
    )
    candidate_rows += direct.arm_rows([component], "a")
    candidate_rows += direct.arm_rows([component], "b")
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
            faults.extend(direct_faults(protocol, baseline, candidate))
        except (OSError, subprocess.SubprocessError, TimeoutError, RuntimeError) as error:
            execution_error = str(error)

    ledger_after = identity.ledger_identity()
    if ledger_after != ledger_before:
        faults.append("append-only ledger changed")
    elapsed = time.monotonic() - started
    if execution_error or elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        outcome = "inconclusive"
        decision = "record-private-overflow-identity-inconclusive-at-cap"
        boundary = 3
    elif faults:
        outcome = "futility"
        decision = "close-private-overflow-heavy-blow-representation"
        boundary = 2
    else:
        outcome = "success"
        decision = "freeze-private-overflow-heavy-blow-for-natural-capacity"
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
        "archiveHeadsPreserved": {
            "843e899": immutable["repositoryRefs"][
                "refs/remotes/origin/research/issue-421-post-reshuffle-frontier-evidence"
            ],
            "d486289": immutable["repositoryRefs"][
                "refs/remotes/origin/research/issue-421-post-843e899-family-ladder-evidence"
            ],
        },
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
