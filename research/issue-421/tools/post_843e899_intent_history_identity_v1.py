#!/usr/bin/env python3
"""One-look direct identity preflight for #421 intent-history lifecycle."""

from __future__ import annotations

import copy
import json
import subprocess
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-843e899-intent-history-identity-v1.json"
SUMMARY = core.ROOT / "summaries/post-843e899-intent-history-identity-v1.json"
BASELINE = core.ROOT / "intent-history-v1-baseline-source"
CANDIDATE = core.ROOT / "intent-history-v1-source"
PROBE = core.ROOT / "research_421_intent_history_probe_v1.gd"
MARKER = "RESEARCH421_INTENT_HISTORY_ROW "
EVENT = "research421IntentHistory"
CORE_SCENARIOS = (
    "repeat-play", "repeat-cap", "ash-repeat", "first-intent",
    "changed-intent", "two-back-return", "skill-then-attack",
    "wrong-then-right", "same-move-other-enemy", "unanswered-next-ai",
    "staggered-history", "target-death-other-route", "victory-expiry",
    "defeat-expiry", "final-responding-attack", "nonfinal-target-kill",
    "multi-enemy-independent", "exhaust-settlement",
)
INJECTED = (
    "stale-play", "missing-play", "malformed-play", "move-mismatch-play",
    "malformed-before-ai",
)
NULL_SCENARIOS = ("ash-repeat", "first-intent", "changed-intent", "two-back-return")
REPEAT_COUNTS = {
    scenario: (2 if scenario == "multi-enemy-independent" else 1)
    for scenario in CORE_SCENARIOS if scenario not in NULL_SCENARIOS
}
CONSUMED_COUNTS = {
    "repeat-play": 1, "repeat-cap": 1, "skill-then-attack": 1,
    "wrong-then-right": 1, "final-responding-attack": 1,
    "nonfinal-target-kill": 1, "multi-enemy-independent": 2,
    "exhaust-settlement": 1,
}


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
        raise TimeoutError("intent-history identity reached its wall-time cap")
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
        "candidateResearchDiffSha256": core.sha(subprocess.run(
            ["git", "diff", "--", "domain/rules/combat.gd"], cwd=CANDIDATE,
            check=True, capture_output=True,
        ).stdout),
        "probeSha256": core.file_sha(PROBE),
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
    candidate = (CANDIDATE / "domain/rules/combat.gd").read_text()
    baseline = (BASELINE / "domain/rules/combat.gd").read_text()
    diff = subprocess.run(
        ["git", "diff", "-U0", "--", "domain/rules/combat.gd"],
        cwd=CANDIDATE, check=True, text=True, capture_output=True,
    ).stdout
    added = "\n".join(line[1:] for line in diff.splitlines()
                      if line.startswith("+") and not line.startswith("+++"))
    play = candidate.split("func play_card(", 1)[1].split("func exhaust_card(", 1)[0]
    compute = candidate.split("func _compute_intents(", 1)[1].split(
        "func _start_player_turn(", 1)[0]
    projection_sources = (
        CANDIDATE / "domain/state/enemy_combatant.gd",
        CANDIDATE / "domain/state/combat_state.gd",
        CANDIDATE / "domain/state/run_state.gd",
        CANDIDATE / "domain/events/event_types.gd",
        CANDIDATE / "tools/balance_policy.gd",
        CANDIDATE / "tools/balance_pilot.gd",
    )
    checks = (
        ("baseline interface absent", "research421" not in baseline.lower()),
        ("sole gameplay source surface",
         git(CANDIDATE, "diff", "--name-only").splitlines()
         == ["domain/rules/combat.gd"]),
        ("clean research diff", not git(CANDIDATE, "diff", "--check")),
        ("configuration interface cardinality",
         candidate.count("configure_research421_intent_history") == 1),
        ("producer knob cardinality",
         candidate.count("_research421_intent_producer") == 4),
        ("consumer knob cardinality",
         candidate.count("_research421_intent_consumer") == 4),
        ("mediator key declaration cardinality",
         candidate.count('const _RESEARCH421_INTENT_KEY: String =') == 1),
        ("telemetry type cardinality",
         candidate.count('"research421IntentHistory"') == 1),
        ("single AI call", candidate.count("EnemyAi.decide(") == 1),
        ("all compute callers preserved",
         candidate.count("_compute_intents(") == baseline.count("_compute_intents(")),
        ("expiry precedes AI",
         compute.index("_research421_expire_intent")
         < compute.index("EnemyAi.decide(")),
        ("AI boundary proves key absence before AI",
         compute.index('"ai-boundary"') < compute.index("EnemyAi.decide(")),
        ("producer follows canonical intent",
         compute.index("EventTypes.INTENT") < compute.index('"producer"')
         < compute.index("e.flags[_RESEARCH421_INTENT_KEY]")),
        ("consumer after target and before authored effects",
         play.index("target = cb.enemies[ti]")
         < play.index("_research421_consume_intent")
         < play.index("cb.pending_chips_active = true")),
        ("payoff after ordinary card settlement",
         play.index("cb.queue.append({\"t\": EventTypes.TO_DISCARD")
         < play.index("if not research_intent_consumed.is_empty()")
         < play.rindex("return true")),
        ("target-death expiry hook",
         "func _on_enemy_death" in candidate
         and "_research421_expire_intent(cb, e, \"target-death\")" in candidate),
        ("victory expiry hook",
         "_research421_expire_all_intents(cb, \"victory\")" in candidate),
        ("defeat expiry hook",
         "_research421_expire_all_intents(cb, \"defeat\")" in candidate),
        ("no projected or policy surface",
         all("research421" not in path.read_text().lower()
             for path in projection_sources)),
        ("no RNG call", "rand" not in added.lower()),
        ("Scoreline absent", "scoreline" not in added.lower()),
        ("Afterimage absent", "afterimage" not in added.lower()),
    )
    return [label for label, passed in checks if not passed]


def run_probe(
    source: Path, source_label: str, protocol_sha: str, godot: str, deadline: float,
) -> tuple[list[dict[str, Any]], str, dict[str, str]]:
    result = subprocess.run(
        [godot, "--headless", "--path", str(source), "-s", str(PROBE), "--",
         f"--source={source_label}"],
        cwd=source, text=True, capture_output=True, timeout=seconds_left(deadline),
    )
    fatal = tuple(needle for needle in ("SCRIPT ERROR", "Parse Error")
                  if needle in result.stderr or needle in result.stdout)
    if result.returncode != 0 or fatal:
        raise RuntimeError(
            f"{source_label} probe failed ({result.returncode}; {fatal})\n"
            f"{result.stdout[-3000:]}\n{result.stderr[-5000:]}"
        )
    rows = [json.loads(line.removeprefix(MARKER))
            for line in result.stdout.splitlines() if line.startswith(MARKER)]
    output_sha, _ = core.cache_json({
        "schemaVersion": 1, "protocolSha256": protocol_sha,
        "source": source_label, "rows": rows,
    })
    return rows, output_sha, {
        "stdoutSha256": core.sha(result.stdout.encode()),
        "stderrSha256": core.sha(result.stderr.encode()),
    }


def keyed(rows: list[dict[str, Any]]) -> dict[tuple[str, str], dict[str, Any]]:
    return {(str(row["arm"]), str(row["scenario"])): row for row in rows}


def research_events(row: dict[str, Any], key: str = "events") -> list[dict[str, Any]]:
    return [event for event in row.get(key, []) if event.get("t") == EVENT]


def strip_research(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [copy.deepcopy(event) for event in events if event.get("t") != EVENT]


def normalised(row: dict[str, Any], remove_payoff: bool = False) -> dict[str, Any]:
    result = copy.deepcopy(row)
    result.pop("source", None)
    result.pop("arm", None)
    skip: set[int] = set()
    realised = 0
    if remove_payoff:
        raw_events = row.get("events", [])
        for index, event in enumerate(raw_events):
            if event.get("t") != EVENT or event.get("stage") != "payoff":
                continue
            delta = int(event.get("realised", 0))
            realised += delta
            if delta:
                require("payoff Ember adjacency", index > 0
                        and raw_events[index - 1].get("t") == "ember"
                        and int(raw_events[index - 1].get("n", 0)) == delta)
                skip.add(index - 1)
        result["events"] = [copy.deepcopy(event) for index, event in enumerate(raw_events)
                            if index not in skip and event.get("t") != EVENT]
        result["combat"]["embers"] -= realised
    else:
        result["events"] = strip_research(result.get("events", []))
    for key in ("initialEvents", "eventsBeforeAction"):
        if key in result:
            result[key] = strip_research(result[key])
    result["enemyFlags"] = result.pop("enemyFlagsWithoutMediator")
    for key in (
        "mediatorsBeforeAction", "mediatorsAfterFirst", "mediators",
        "enemyFlagsBeforeActionWithoutMediator",
    ):
        result.pop(key, None)
    return result


def direct_faults(
    baseline_rows: list[dict[str, Any]], candidate_rows: list[dict[str, Any]],
) -> tuple[list[str], dict[str, Any]]:
    faults: list[str] = []

    def check(label: str, condition: bool) -> None:
        if not condition:
            faults.append(label)

    base = keyed(baseline_rows)
    cand = keyed(candidate_rows)
    expected_candidate = {
        (arm, scenario) for arm in ("omitted", "off", "a", "b", "ab")
        for scenario in CORE_SCENARIOS
    } | {("ab", f"injected-{scenario}") for scenario in INJECTED}
    check("baseline fixed matrix", set(base) == {
        ("baseline", scenario) for scenario in CORE_SCENARIOS
    })
    check("candidate fixed matrix", set(cand) == expected_candidate)
    if faults:
        return faults, {}

    for scenario in CORE_SCENARIOS:
        rows = [base[("baseline", scenario)]] + [cand[(arm, scenario)]
                for arm in ("omitted", "off", "a", "b", "ab")]
        baseline = rows[0]
        omitted, off, a_only, b_only, ab = rows[1:]
        check(f"{scenario}: current-main versus omitted identity",
              normalised(baseline) == normalised(omitted))
        check(f"{scenario}: current-main versus off identity",
              normalised(baseline) == normalised(off))
        check(f"{scenario}: B-only exact null",
              normalised(b_only) == normalised(off))
        check(f"{scenario}: A changes mediator only",
              normalised(a_only) == normalised(off))
        try:
            ab_component = normalised(ab, True)
        except RuntimeError as error:
            faults.append(f"{scenario}: {error}")
        else:
            check(f"{scenario}: AB changes fixed payoff only",
                  ab_component == normalised(a_only))
        check(f"{scenario}: omitted/off telemetry absent", all(
            not research_events(row, "initialEvents") and not research_events(row)
            for row in (baseline, omitted, off)
        ))
        check(f"{scenario}: B has no mediator or payoff",
              not b_only["mediatorsBeforeAction"] and not b_only["mediators"]
              and all(event.get("stage") == "ai-boundary"
                      for event in research_events(b_only, "initialEvents")
                      + research_events(b_only)))
        check(f"{scenario}: runtime projection excludes mediator",
              all(row["projectionHasMediator"] is False for row in rows))
        for arm, row in (("A", a_only), ("B", b_only), ("AB", ab)):
            boundaries = research_events(row, "initialEvents") + [
                event for event in research_events(row)
                if event.get("stage") == "ai-boundary"
            ]
            check(f"{scenario}: {arm} AI boundaries observed", bool(boundaries))
            check(f"{scenario}: {arm} key absent before every AI", all(
                event.get("researchKeyPresent") is False for event in boundaries
            ))
        check(f"{scenario}: frozen RNG identity", all(
            len({row[key] for row in rows}) == 1
            for key in ("rngBeforeCompute", "rngAfterCompute", "rngState")
        ))

        expected = REPEAT_COUNTS.get(scenario, 0)
        for arm, row in (("A", a_only), ("AB", ab)):
            current = research_events(row)
            producers = [event for event in current if event.get("stage") == "producer"]
            sets = [event for event in current if event.get("stage") == "mediator-set"]
            check(f"{scenario}: {arm} producer cardinality",
                  len(producers) == expected and len(sets) == expected
                  and len(row["mediatorsBeforeAction"]) == expected)
            for event in producers:
                index = row["events"].index(event)
                previous = row["events"][index - 1] if index else {}
                check(f"{scenario}: {arm} producer after exact INTENT",
                      previous.get("t") == "intent"
                      and previous.get("idx") == event.get("idx")
                      and previous.get("move") == event.get("move"))
            check(f"{scenario}: {arm} exact mediator shape", all(
                set(item["value"]) == {"move", "createdTurn"}
                and item["value"]["createdTurn"] == row["combatBeforeAction"]["turn"]
                for item in row["mediatorsBeforeAction"]
            ))
        check(f"{scenario}: A and AB producer identity",
              a_only["mediatorsBeforeAction"] == ab["mediatorsBeforeAction"]
              and a_only["combatBeforeAction"] == ab["combatBeforeAction"]
              and a_only["enemyFlagsBeforeActionWithoutMediator"]
              == ab["enemyFlagsBeforeActionWithoutMediator"]
              and strip_research(a_only["eventsBeforeAction"])
              == strip_research(ab["eventsBeforeAction"]))

    for scenario in NULL_SCENARIOS:
        for arm in ("a", "ab"):
            row = cand[(arm, scenario)]
            check(f"{scenario}: {arm.upper()} exact null",
                  not row["mediatorsBeforeAction"]
                  and not any(event.get("stage") in (
                      "producer", "mediator-set", "consumer", "mediator-consume", "payoff"
                  ) for event in research_events(row)))

    realised_by_scenario = {
        "repeat-play": [1], "repeat-cap": [0], "skill-then-attack": [1],
        "wrong-then-right": [1], "final-responding-attack": [],
        "nonfinal-target-kill": [1], "multi-enemy-independent": [1, 1],
        "exhaust-settlement": [1],
    }
    for scenario, count in CONSUMED_COUNTS.items():
        a_only = cand[("a", scenario)]
        ab = cand[("ab", scenario)]
        a_events = research_events(a_only)
        ab_events = research_events(ab)
        check(f"{scenario}: A consumer-disabled cardinality",
              sum(event.get("stage") == "expiry"
                  and event.get("reason") == "consumer-disabled"
                  for event in a_events) == count)
        consumers = [event for event in ab_events if event.get("stage") == "consumer"]
        consumes = [event for event in ab_events
                    if event.get("stage") == "mediator-consume"]
        payoffs = [event for event in ab_events if event.get("stage") == "payoff"]
        check(f"{scenario}: AB consume cardinality",
              len(consumers) == count and len(consumes) == count)
        check(f"{scenario}: AB payoff values",
              [event.get("realised") for event in payoffs]
              == realised_by_scenario[scenario]
              and all(event.get("requested") == 1 for event in payoffs))
        for consumer in consumers:
            queue = ab["events"]
            consumer_index = queue.index(consumer)
            uid = consumer.get("uid")
            play_indices = [index for index, event in enumerate(queue[:consumer_index])
                            if event.get("t") == "play" and event.get("uid") == uid]
            check(f"{scenario}: consumer has exact prior PLAY", bool(play_indices))
            if not play_indices:
                continue
            play_index = play_indices[-1]
            check(f"{scenario}: consumer after ENERGY", any(
                event.get("t") == "energy"
                for event in queue[play_index + 1:consumer_index]
            ))
            hit_indices = [index for index, event in enumerate(queue[consumer_index + 1:],
                                                                consumer_index + 1)
                           if event.get("t") == "hitEnemy"]
            check(f"{scenario}: consumer before authored hit", bool(hit_indices))
            settlement_indices = [index for index, event in enumerate(queue)
                                  if event.get("t") in ("toDiscard", "exhaust")
                                  and event.get("uid") == uid]
            check(f"{scenario}: exact card settlement observed",
                  bool(settlement_indices) and settlement_indices[-1] > consumer_index)
            matching_payoff = [event for event in payoffs if event.get("uid") == uid]
            if matching_payoff and settlement_indices:
                check(f"{scenario}: payoff after complete settlement",
                      queue.index(matching_payoff[0]) > settlement_indices[-1])
        check(f"{scenario}: mediator consumed",
              not ab["mediators"] and not a_only["mediators"])

    final = cand[("ab", "final-responding-attack")]
    check("final response has no payoff and exact expiry",
          not any(event.get("stage") == "payoff" for event in research_events(final))
          and sum(event.get("stage") == "expiry"
                  and event.get("reason") == "combat-over-after-consume"
                  for event in research_events(final)) == 1)
    check("Skill leaves exact mediator before Attack",
          len(cand[("ab", "skill-then-attack")]["mediatorsAfterFirst"]) == 1)
    check("wrong target leaves exact mediator before right target",
          len(cand[("ab", "wrong-then-right")]["mediatorsAfterFirst"]) == 1)
    other = cand[("ab", "same-move-other-enemy")]
    check("same move on other enemy cannot consume",
          len(other["mediators"]) == 1 and other["mediators"][0]["idx"] == 0
          and not any(event.get("stage") in ("consumer", "payoff")
                      for event in research_events(other)))

    expiries = {
        "unanswered-next-ai": "unanswered-window",
        "staggered-history": "unanswered-window",
        "target-death-other-route": "target-death",
        "victory-expiry": "victory",
        "defeat-expiry": "defeat",
    }
    for scenario, reason in expiries.items():
        for arm in ("a", "ab"):
            row = cand[(arm, scenario)]
            check(f"{scenario}: {arm.upper()} exact expiry", any(
                event.get("stage") == "expiry" and event.get("reason") == reason
                for event in research_events(row)
            ) and not row["mediators"])
    for scenario in ("unanswered-next-ai", "staggered-history"):
        history = cand[("ab", scenario)]["enemyHistory"][0]
        check(f"{scenario}: current move entered history",
              history["lastMoves"][-1] == "bite" and history["move"] == "howl")
    check("Stagger interference preserved", any(
        event.get("t") == "staggered"
        for event in cand[("ab", "staggered-history")]["events"]
    ))
    check("ordinary enemy action interference preserved", any(
        event.get("t") == "enemyAct"
        for event in cand[("ab", "unanswered-next-ai")]["events"]
    ))
    multi_payoffs = [event for event in research_events(
        cand[("ab", "multi-enemy-independent")]) if event.get("stage") == "payoff"]
    check("independent enemy cardinality", sorted(event.get("idx") for event in multi_payoffs)
          == [0, 1])

    injected_expectations = {
        "injected-stale-play": "stale-turn",
        "injected-malformed-play": "malformed",
        "injected-move-mismatch-play": "move-mismatch",
    }
    for scenario, reason in injected_expectations.items():
        row = cand[("ab", scenario)]
        events = research_events(row)
        check(f"{scenario}: exact fail-closed expiry",
              sum(event.get("stage") == "expiry" and event.get("reason") == reason
                  for event in events) == 1
              and not any(event.get("stage") in ("consumer", "payoff")
                          for event in events)
              and not row["mediators"])
    missing = cand[("ab", "injected-missing-play")]
    check("injected missing is exact null",
          not research_events(missing) and not missing["mediators"])
    malformed_ai = cand[("ab", "injected-malformed-before-ai")]
    malformed_events = research_events(malformed_ai)
    check("malformed key erased before AI",
          any(event.get("stage") == "expiry"
              and event.get("reason") == "unanswered-window"
              for event in malformed_events)
          and any(event.get("stage") == "ai-boundary"
                  and event.get("researchKeyPresent") is False
                  for event in malformed_events)
          and not any(event.get("stage") in ("consumer", "payoff")
                      for event in malformed_events))
    check("all injected projections exclude mediator", all(
        cand[("ab", f"injected-{scenario}")]["projectionHasMediator"] is False
        for scenario in INJECTED
    ))

    counts = {
        "baselineRows": len(baseline_rows),
        "candidateRows": len(candidate_rows),
        "nullIdentityScenarios": len(CORE_SCENARIOS),
        "repeatScenarios": len(REPEAT_COUNTS),
        "consumerScenarios": len(CONSUMED_COUNTS),
        "injectedFailClosedScenarios": len(INJECTED),
    }
    return faults, counts


def self_check() -> None:
    row = {
        "source": "candidate", "arm": "ab", "enemyFlags": [],
        "enemyFlagsWithoutMediator": [], "mediatorsBeforeAction": [],
        "mediatorsAfterFirst": [], "mediators": [],
        "enemyFlagsBeforeActionWithoutMediator": [], "combat": {"embers": 1},
        "initialEvents": [], "eventsBeforeAction": [],
        "events": [
            {"t": EVENT, "stage": "mediator-consume"},
            {"t": "ember", "n": 1, "total": 1},
            {"t": EVENT, "stage": "payoff", "realised": 1},
        ],
    }
    result = normalised(row, True)
    require("self-check payoff removal", result["events"] == []
            and result["combat"]["embers"] == 0)


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite intent-history identity summary")
    self_check()
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    immutable = protocol["immutableInputs"]
    actual_source = source_identity(protocol)
    require("immutable source identity drift", actual_source == {
        key: immutable[key] for key in actual_source
    })
    ledger_before = identity.ledger_identity()
    require("ledger freeze drift", ledger_before == protocol["ledgerFreeze"])
    source_gate_faults = static_faults()

    started = time.monotonic()
    deadline = started + protocol["budget"]["maximumWallTimeSeconds"]
    outputs: dict[str, str] = {}
    streams: dict[str, dict[str, str]] = {}
    execution_error = ""
    direct: list[str] = []
    counts: dict[str, Any] = {}
    completed_rows = 0
    if not source_gate_faults:
        try:
            baseline, outputs["baseline"], streams["baseline"] = run_probe(
                BASELINE, "baseline", protocol_sha, immutable["godotBinaryPath"], deadline,
            )
            candidate, outputs["candidate"], streams["candidate"] = run_probe(
                CANDIDATE, "candidate", protocol_sha, immutable["godotBinaryPath"], deadline,
            )
            completed_rows = len(baseline) + len(candidate)
            require("direct observation cap drift",
                    completed_rows == protocol["budget"]["directControlledObservations"])
            direct, counts = direct_faults(baseline, candidate)
        except (OSError, subprocess.SubprocessError, TimeoutError, RuntimeError,
                StopIteration, KeyError, IndexError, TypeError, ValueError) as error:
            execution_error = str(error)

    ledger_after = identity.ledger_identity()
    if ledger_after != ledger_before:
        direct.append("append-only ledger changed")
    elapsed = time.monotonic() - started
    if execution_error or elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        outcome, decision, boundary = (
            "inconclusive", "record-intent-history-identity-inconclusive-at-cap", 3,
        )
    elif source_gate_faults or direct:
        outcome, decision, boundary = (
            "futility", "close-intent-history-and-advance-to-private-state", 2,
        )
    else:
        outcome, decision, boundary = (
            "success", "freeze-intent-history-for-natural-capacity", 1,
        )

    summary = {
        "schemaVersion": 1, "issue": 421, "outcomeClass": outcome,
        "decision": decision, "decisionBoundary": boundary,
        "claimBoundary": protocol["claimBoundary"],
        "authority": protocol["decisionRules"][outcome + "Authority"],
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "sourceIdentity": actual_source,
        "sourceGateFaults": source_gate_faults,
        "directFaults": direct, "executionError": execution_error,
        "counts": counts, "outputSha256": outputs, "processStreams": streams,
        "GodotProcesses": len(outputs),
        "directControlledObservations": completed_rows,
        "newSimulatorObservationRows": 0,
        "newLedgerRows": ledger_after["records"] - ledger_before["records"],
        "protectedSeedRows": ledger_after["protectedSeedRows"],
        "ledgerBefore": ledger_before, "ledgerAfter": ledger_after,
        "wallTimeSeconds": elapsed,
        "maximumModelContextTokensDuringExecutionAndDecision": 0,
        "archiveHeadPreserved": immutable["repositoryRefs"][
            "refs/remotes/origin/research/issue-421-post-reshuffle-frontier-evidence"
        ],
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "outcomeClass": outcome, "decision": decision,
        "faults": len(source_gate_faults) + len(direct),
        "rows": completed_rows, "counts": counts,
        "wallTimeSeconds": round(elapsed, 3),
    }, sort_keys=True))


if __name__ == "__main__":
    main()
