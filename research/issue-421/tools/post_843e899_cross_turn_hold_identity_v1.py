#!/usr/bin/env python3
"""One-look direct identity preflight for #421 one-turn held Attack lifecycle."""

from __future__ import annotations

import copy
import json
import subprocess
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-843e899-cross-turn-hold-identity-v1.json"
SUMMARY = core.ROOT / "summaries/post-843e899-cross-turn-hold-identity-v1.json"
BASELINE = core.ROOT / "cross-turn-hold-v1-baseline-source"
CANDIDATE = core.ROOT / "cross-turn-hold-v1-source"
PROBE = "res://tools/research_421_cross_turn_hold_probe.gd"
MARKER = "RESEARCH421_CROSS_TURN_HOLD_ROW "
EVENT = "research421CrossTurnHold"
CORE_SCENARIOS = (
    "valid-play", "cap-play", "ash-null", "no-attack-null",
    "same-id-other-uid", "kindle-held", "next-end-expiry",
    "defeat-expiry", "victory-expiry",
)


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
        raise TimeoutError("cross-turn hold identity reached its wall-time cap")
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
            ["git", "diff", "--", "domain/rules/combat.gd",
             "domain/state/combat_state.gd"],
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
    candidate_combat = (CANDIDATE / "domain/rules/combat.gd").read_text()
    candidate_state = (CANDIDATE / "domain/state/combat_state.gd").read_text()
    baseline_combat = (BASELINE / "domain/rules/combat.gd").read_text()
    baseline_state = (BASELINE / "domain/state/combat_state.gd").read_text()
    diff = subprocess.run(
        ["git", "diff", "-U0", "--", "domain/rules/combat.gd",
         "domain/state/combat_state.gd"],
        cwd=CANDIDATE, check=True, text=True, capture_output=True,
    ).stdout
    added = "\n".join(line[1:] for line in diff.splitlines()
                      if line.startswith("+") and not line.startswith("+++"))
    changed = git(CANDIDATE, "diff", "--name-only").splitlines()
    checks = (
        ("baseline combat marker absent", "research421" not in baseline_combat.lower()),
        ("baseline state marker absent", "research421" not in baseline_state.lower()),
        ("research diff surface", changed == [
            "domain/rules/combat.gd", "domain/state/combat_state.gd",
        ]),
        ("producer knob cardinality", candidate_combat.count(
            "_research421_hold_producer") == 3),
        ("consumer knob cardinality", candidate_combat.count(
            "_research421_hold_consumer") == 3),
        ("configuration interface cardinality", candidate_combat.count(
            "configure_research421_cross_turn_hold") == 1),
        ("mediator field cardinality", candidate_state.count(
            "research421_cross_turn_hold") == 1),
        ("telemetry type cardinality", candidate_combat.count(
            '"research421CrossTurnHold"') == 1),
        ("mediator omitted from combat projection", "research421" not in
         candidate_state.split("func to_dict()", 1)[1].lower()),
        ("no run persistence surface", "research421" not in
         (CANDIDATE / "domain/state/run_state.gd").read_text().lower()),
        ("no event-type surface", "research421" not in
         (CANDIDATE / "domain/events/event_types.gd").read_text().lower()),
        ("no policy surface", "research421" not in
         (CANDIDATE / "tools/balance_policy.gd").read_text().lower()),
        ("probe byte identity", core.file_sha(BASELINE / PROBE.removeprefix("res://"))
         == core.file_sha(CANDIDATE / PROBE.removeprefix("res://"))),
        ("probe UID identity", core.file_sha(BASELINE / (PROBE.removeprefix("res://") + ".uid"))
         == core.file_sha(CANDIDATE / (PROBE.removeprefix("res://") + ".uid"))),
        ("no random call", "rand" not in added.lower()),
        ("Scoreline absent", "scoreline" not in added.lower()),
        ("Afterimage absent", "afterimage" not in added.lower()),
    )
    return [label for label, passed in checks if not passed]


def run_probe(
    source: Path, source_label: str, protocol_sha: str, godot: str, deadline: float,
) -> tuple[list[dict[str, Any]], str, dict[str, str]]:
    result = subprocess.run(
        [godot, "--headless", "--path", str(source), "-s", PROBE, "--",
         f"--source={source_label}"],
        cwd=source, text=True, capture_output=True, timeout=seconds_left(deadline),
    )
    fatal = tuple(needle for needle in ("SCRIPT ERROR", "Parse Error", "ERROR:")
                  if needle in result.stderr or needle in result.stdout)
    if result.returncode != 0 or fatal:
        raise RuntimeError(
            f"{source_label} probe failed ({result.returncode}; {fatal})\n"
            f"{result.stdout[-3000:]}\n{result.stderr[-5000:]}"
        )
    rows = [json.loads(line.removeprefix(MARKER))
            for line in result.stdout.splitlines() if line.startswith(MARKER)]
    output = {
        "schemaVersion": 1,
        "protocolSha256": protocol_sha,
        "source": source_label,
        "rows": rows,
    }
    output_sha, _ = core.cache_json(output)
    return rows, output_sha, {
        "stdoutSha256": core.sha(result.stdout.encode()),
        "stderrSha256": core.sha(result.stderr.encode()),
    }


def keyed(rows: list[dict[str, Any]]) -> dict[tuple[str, str], dict[str, Any]]:
    return {(str(row["arm"]), str(row["scenario"])): row for row in rows}


def research_events(value: dict[str, Any], key: str = "events") -> list[dict[str, Any]]:
    return [event for event in value.get(key, []) if event.get("t") == EVENT]


def stages(value: dict[str, Any], key: str = "events") -> list[str]:
    return [str(event.get("stage", "")) for event in research_events(value, key)]


def null_projection(row: dict[str, Any]) -> dict[str, Any]:
    result = copy.deepcopy(row)
    result.pop("source", None)
    result.pop("arm", None)
    return result


def strip_research(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [copy.deepcopy(event) for event in events if event.get("t") != EVENT]


def component_projection(row: dict[str, Any], realised: int) -> dict[str, Any]:
    result = null_projection(row)
    result["events"] = strip_research(result["events"])
    result["afterEnd"]["events"] = strip_research(result["afterEnd"]["events"])
    if realised:
        events = row["events"]
        consume_index = next(i for i, event in enumerate(events)
                             if event.get("t") == EVENT
                             and event.get("stage") == "mediator-consume")
        payoff_index = next(i for i, event in enumerate(events)
                            if event.get("t") == EVENT
                            and event.get("stage") == "payoff")
        candidates = [copy.deepcopy(event) for event in events[consume_index + 1:payoff_index]
                      if event.get("t") != EVENT]
        if candidates != [{"t": "ember", "n": realised,
                            "total": row["combat"]["embers"]}]:
            raise RuntimeError("AB payoff event is not the sole intervening Ember")
        removed = False
        normalised: list[dict[str, Any]] = []
        for event in result["events"]:
            if not removed and event == candidates[0]:
                removed = True
                continue
            normalised.append(event)
        result["events"] = normalised
        result["combat"]["embers"] -= realised
    return result


def non_zone_after_end(row: dict[str, Any]) -> dict[str, Any]:
    result = copy.deepcopy(row["afterEnd"]["combat"])
    for key in ("hand", "draw", "discard", "exhaust"):
        result.pop(key, None)
    return result


def direct_faults(
    protocol: dict[str, Any], baseline_rows: list[dict[str, Any]],
    candidate_rows: list[dict[str, Any]],
) -> tuple[list[str], dict[str, Any]]:
    faults: list[str] = []

    def check(label: str, condition: bool) -> None:
        if not condition:
            faults.append(label)

    base = keyed(baseline_rows)
    cand = keyed(candidate_rows)
    check("baseline row cardinality", len(base) == 9)
    check("candidate row cardinality", len(cand) == 48)
    expected_candidate_keys = {
        (arm, scenario) for arm in ("omitted", "off", "a", "b", "ab")
        for scenario in CORE_SCENARIOS
    } | {("ab", f"injected-{name}") for name in (
        "stale-play", "missing-at-turn-start", "malformed-at-turn-start",
    )}
    check("candidate fixed matrix", set(cand) == expected_candidate_keys)
    check("baseline fixed matrix", set(base) == {
        ("baseline", scenario) for scenario in CORE_SCENARIOS
    })
    if faults:
        return faults, {}

    for scenario in CORE_SCENARIOS:
        baseline = base[("baseline", scenario)]
        omitted = cand[("omitted", scenario)]
        off = cand[("off", scenario)]
        b_only = cand[("b", scenario)]
        check(f"{scenario}: current-main versus omitted identity",
              null_projection(baseline) == null_projection(omitted))
        check(f"{scenario}: current-main versus explicit-off identity",
              null_projection(baseline) == null_projection(off))
        check(f"{scenario}: omitted versus explicit-off identity",
              null_projection(omitted) == null_projection(off))
        check(f"{scenario}: B-only exact null",
              null_projection(b_only) == null_projection(off))
        check(f"{scenario}: null telemetry absent", all(
            not research_events(row) and not research_events(row["afterEnd"])
            and row["mediator"] == {} and row["afterEnd"]["mediator"] == {}
            for row in (baseline, omitted, off, b_only)
        ))
        check(f"{scenario}: runtime projection excludes mediator", all(
            row["snapshotHasMediator"] is False
            for row in (baseline, omitted, off, b_only)
        ))

    for scenario in ("ash-null", "no-attack-null"):
        off = cand[("off", scenario)]
        for arm in ("a", "ab"):
            check(f"{scenario}: {arm.upper()} mechanistic null",
                  null_projection(cand[(arm, scenario)]) == null_projection(off))

    for scenario in CORE_SCENARIOS:
        states = {cand[(arm, scenario)]["rngState"]
                  for arm in ("omitted", "off", "a", "b", "ab")}
        states.add(base[("baseline", scenario)]["rngState"])
        before = {cand[(arm, scenario)]["beforeRngState"]
                  for arm in ("omitted", "off", "a", "b", "ab")}
        before.add(base[("baseline", scenario)]["beforeRngState"])
        check(f"{scenario}: frozen RNG identity", len(states) == 1 and len(before) == 1)

    active = tuple(scenario for scenario in CORE_SCENARIOS
                   if scenario not in ("ash-null", "no-attack-null"))
    for scenario in active:
        off = cand[("off", scenario)]
        a_only = cand[("a", scenario)]
        ab = cand[("ab", scenario)]
        expected_uid = a_only["firstAttackUid"]
        after_events = research_events(a_only["afterEnd"])
        check(f"{scenario}: producer-carry stage order",
              [event.get("stage") for event in after_events]
              == ["producer", "mediator-set", "carry"])
        check(f"{scenario}: exact first Attack UID", len(after_events) == 3
              and all(event.get("uid") == expected_uid for event in after_events)
              and after_events[0].get("handIndex") == 1)
        check(f"{scenario}: one mediator record",
              a_only["afterEnd"]["mediator"] == {
                  "uid": expected_uid, "cardId": "strike", "createdTurn": 1,
              })
        check(f"{scenario}: one-draw natural cost",
              after_events[2].get("drawReplacement") == 1
              and after_events[2].get("drawCount") == 4
              and sum(event.get("t") == "draw"
                      for event in a_only["afterEnd"]["events"]) == 4
              and sum(event.get("t") == "draw"
                      for event in off["afterEnd"]["events"]) == 5)
        a_discard = next(event for event in a_only["afterEnd"]["events"]
                         if event.get("t") == "discardHand")
        off_discard = next(event for event in off["afterEnd"]["events"]
                           if event.get("t") == "discardHand")
        check(f"{scenario}: retained UID excluded from discard",
              expected_uid not in a_discard["uids"] and expected_uid in off_discard["uids"])
        check(f"{scenario}: non-zone state isolation",
              non_zone_after_end(a_only) == non_zone_after_end(off))
        check(f"{scenario}: non-zone event isolation",
              [event for event in strip_research(a_only["afterEnd"]["events"])
               if event.get("t") not in ("discardHand", "draw")]
              == [event for event in off["afterEnd"]["events"]
                  if event.get("t") not in ("discardHand", "draw")])
        check(f"{scenario}: A and AB producer identity",
              research_events(a_only["afterEnd"]) == research_events(ab["afterEnd"])
              and a_only["afterEnd"]["combat"] == ab["afterEnd"]["combat"]
              and a_only["afterEnd"]["rngState"] == ab["afterEnd"]["rngState"])

    for scenario, realised in (("valid-play", 1), ("cap-play", 0)):
        a_only = cand[("a", scenario)]
        ab = cand[("ab", scenario)]
        check(f"{scenario}: A-only lifecycle",
              stages(a_only) == ["producer", "mediator-set", "carry", "expiry"]
              and research_events(a_only)[-1].get("reason") == "consumer-disabled")
        check(f"{scenario}: AB lifecycle",
              stages(ab) == ["producer", "mediator-set", "carry", "consumer",
                             "mediator-consume", "payoff"])
        payoff = research_events(ab)[-1]
        check(f"{scenario}: fixed payoff", payoff.get("requested") == 1
              and payoff.get("realised") == realised)
        queue = ab["events"]
        play_index = next(i for i, event in enumerate(queue) if event.get("t") == "play")
        energy_index = next(i for i, event in enumerate(queue[play_index + 1:], play_index + 1)
                            if event.get("t") == "energy")
        consumer_index = next(i for i, event in enumerate(queue)
                              if event.get("t") == EVENT
                              and event.get("stage") == "consumer")
        hit_index = next(i for i, event in enumerate(queue) if event.get("t") == "hitEnemy")
        check(f"{scenario}: consumer placement",
              play_index < energy_index < consumer_index < hit_index)
        try:
            isolated = component_projection(ab, realised)
        except RuntimeError as error:
            faults.append(f"{scenario}: {error}")
        else:
            check(f"{scenario}: AB adds only consumer payoff",
                  isolated == component_projection(a_only, 0))
        check(f"{scenario}: mediator consumed", ab["mediator"] == {})

    same_uid = cand[("ab", "same-id-other-uid")]
    check("same-ID/different-UID cannot consume",
          same_uid["actionUid"] != same_uid["firstAttackUid"]
          and stages(same_uid) == ["producer", "mediator-set", "carry"]
          and same_uid["mediator"].get("uid") == same_uid["firstAttackUid"])
    expiry = {
        "kindle-held": "kindle",
        "next-end-expiry": "next-end-turn",
        "defeat-expiry": "defeat",
        "victory-expiry": "victory",
    }
    for scenario, reason in expiry.items():
        row = cand[("ab", scenario)]
        events = research_events(row)
        check(f"{scenario}: exact expiry", stages(row)
              == ["producer", "mediator-set", "carry", "expiry"]
              and events[-1].get("reason") == reason and row["mediator"] == {})
    check("next-end expiry cannot immediately re-hold",
          stages(cand[("ab", "next-end-expiry")]).count("producer") == 1)

    injected = {
        "injected-stale-play": "stale-turn",
        "injected-missing-at-turn-start": "stale-or-missing-at-turn-start",
        "injected-malformed-at-turn-start": "stale-or-missing-at-turn-start",
    }
    for scenario, reason in injected.items():
        row = cand[("ab", scenario)]
        events = research_events(row)
        check(f"{scenario}: fail-closed expiry", len(events) == 1
              and events[0].get("stage") == "expiry"
              and events[0].get("reason") == reason
              and row["mediator"] == {})
        check(f"{scenario}: no payoff", not any(
            event.get("stage") in ("consumer", "mediator-consume", "payoff")
            for event in events
        ))
        check(f"{scenario}: runtime projection excludes mediator",
              row["snapshotHasMediator"] is False)

    counts = {
        "baselineRows": len(baseline_rows),
        "candidateRows": len(candidate_rows),
        "nullIdentityComparisons": len(CORE_SCENARIOS) * 4,
        "rngIdentityScenarios": len(CORE_SCENARIOS),
        "activeLifecycleScenarios": len(active),
        "injectedFailClosedScenarios": len(injected),
    }
    return faults, counts


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite cross-turn hold identity summary")
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
    process_streams: dict[str, dict[str, str]] = {}
    execution_error = ""
    direct: list[str] = []
    counts: dict[str, Any] = {}
    completed_rows = 0
    if not source_gate_faults:
        try:
            baseline, outputs["baseline"], process_streams["baseline"] = run_probe(
                BASELINE, "baseline", protocol_sha, immutable["godotBinaryPath"], deadline,
            )
            candidate, outputs["candidate"], process_streams["candidate"] = run_probe(
                CANDIDATE, "candidate", protocol_sha, immutable["godotBinaryPath"], deadline,
            )
            completed_rows = len(baseline) + len(candidate)
            require("direct observation cap drift",
                    completed_rows == protocol["budget"]["directControlledObservations"])
            direct, counts = direct_faults(protocol, baseline, candidate)
        except (OSError, subprocess.SubprocessError, TimeoutError, RuntimeError,
                StopIteration, KeyError, TypeError, ValueError) as error:
            execution_error = str(error)

    ledger_after = identity.ledger_identity()
    if ledger_after != ledger_before:
        direct.append("append-only ledger changed")
    elapsed = time.monotonic() - started
    if execution_error or elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        outcome = "inconclusive"
        decision = "record-cross-turn-hold-identity-inconclusive-at-cap"
        boundary = 3
    elif source_gate_faults or direct:
        outcome = "futility"
        decision = "close-cross-turn-hold-representation-and-advance-to-intent-history"
        boundary = 2
    else:
        outcome = "success"
        decision = "freeze-cross-turn-hold-representation-for-natural-capacity"
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
        "directFaults": direct,
        "executionError": execution_error,
        "counts": counts,
        "outputSha256": outputs,
        "processStreams": process_streams,
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
        "outcomeClass": outcome,
        "decision": decision,
        "faults": len(source_gate_faults) + len(direct),
        "rows": completed_rows,
        "counts": counts,
        "wallTimeSeconds": round(elapsed, 3),
    }, sort_keys=True))


if __name__ == "__main__":
    main()
