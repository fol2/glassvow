#!/usr/bin/env python3
"""Frozen direct identity gate for the post-b7b5099 Ward-spend family."""

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


PROTOCOL = core.ROOT / "protocols/post-b7b5099-ward-spend-identity-v1.json"
SUMMARY = core.ROOT / "summaries/post-b7b5099-ward-spend-identity-v1.json"
BASELINE = core.ROOT / "ward-spend-finisher-v1-baseline"
CANDIDATE = core.ROOT / "ward-spend-finisher-v1-source"
PROBE = CANDIDATE / "tools/research_421_ward_spend_probe.gd"
RESEARCH_EVENT = "research421WardSpend"
CARD_ID = "research421WardSpendFinisher"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(label)


def git(path: Path, *args: str) -> str:
    return subprocess.run(
        ["git", *args], cwd=path, check=True, text=True, capture_output=True,
    ).stdout.strip()


def git_status(path: Path) -> list[str]:
    return subprocess.run(
        ["git", "status", "--porcelain=v1"], cwd=path, check=True,
        text=True, capture_output=True,
    ).stdout.splitlines()


def seconds_left(deadline: float) -> int:
    remaining = int(deadline - time.monotonic())
    if remaining < 1:
        raise TimeoutError("Ward-spend direct gate reached its wall-time cap")
    return remaining


def research_card(with_special: bool) -> dict[str, Any]:
    effects = [{"kind": "dmg", "n": 5}]
    upgraded = [{"kind": "dmg", "n": 7}]
    if with_special:
        special = {"kind": "special", "id": "research421WardSpend"}
        effects.append(special)
        upgraded.append(copy.deepcopy(special))
    return {
        "type": "attack", "rarity": "common", "cost": 1,
        "target": "enemy", "vfx": "slash", "effects": effects,
        "up": {"effects": upgraded, "text": "Research projection."},
        "name": "Research projection", "text": "Research projection.",
    }


def content_projections(protocol: dict[str, Any]) -> dict[str, tuple[str, Path]]:
    source = BASELINE / "content/full-content.json"
    require("current-main content identity",
            core.file_sha(source) == protocol["immutableInputs"]["contentSha256"])
    raw = json.loads(source.read_text())
    require("research card unexpectedly exists", CARD_ID not in raw["cards"])
    baseline = copy.deepcopy(raw)
    candidate = copy.deepcopy(raw)
    baseline["cards"][CARD_ID] = research_card(False)
    candidate["cards"][CARD_ID] = research_card(True)
    return {
        "baseline": core.cache_json(baseline),
        "candidate": core.cache_json(candidate),
    }


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
        "baselineStatus": git_status(BASELINE),
        "candidateStatus": git_status(CANDIDATE),
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
        "taskCapsuleSha256": core.file_sha(
            core.ROOT / immutable["taskCapsulePath"]),
        "predecessorSha256": {
            name: core.file_sha(core.ROOT / name)
            for name in immutable["predecessorSha256"]
        },
    }


def static_faults() -> list[str]:
    baseline_combat = (BASELINE / "domain/rules/combat.gd").read_text()
    candidate_combat = (CANDIDATE / "domain/rules/combat.gd").read_text()
    player = (CANDIDATE / "domain/state/player_combatant.gd").read_text()
    changed = subprocess.run(
        ["git", "diff", "--name-only"], cwd=CANDIDATE, check=True,
        text=True, capture_output=True,
    ).stdout.splitlines()
    research_lines = "\n".join(
        line for line in candidate_combat.splitlines()
        if "research421" in line.lower()
    ).lower()
    checks = (
        ("baseline research marker absent", "research421WardSpend" not in baseline_combat),
        ("configuration interface cardinality",
         candidate_combat.count("configure_research421_ward_spend") == 1),
        ("producer hook cardinality",
         candidate_combat.count("_record_research421_ward_producer(") == 2),
        ("consumer hook cardinality",
         candidate_combat.count("_apply_research421_ward_spend(") == 2),
        ("research field cardinality", player.count("research421_ward_spend") == 1),
        ("research field omitted from projection",
         "research421_ward_spend" not in player.split("func to_dict", 1)[1]),
        ("only two tracked prototype files", changed == [
            "domain/rules/combat.gd", "domain/state/player_combatant.gd"]),
        ("no random call", "rand" not in research_lines),
        ("no save surface", "research421" not in
         (CANDIDATE / "domain/state/run_state.gd").read_text().lower()),
        ("no global combat projection", "research421" not in
         (CANDIDATE / "domain/state/combat_state.gd").read_text().lower()),
        ("no policy control", "research421" not in
         (CANDIDATE / "tools/balance_policy.gd").read_text().lower()),
    )
    return [label for label, passed in checks if not passed]


def arm_rows(scenarios: list[dict[str, Any]], arm: str) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for scenario in scenarios:
        row = copy.deepcopy(scenario["row"])
        row.update({
            "id": f"{arm}-{scenario['id']}",
            "spend": scenario["spend"],
            "numerator": scenario["numerator"],
        })
        if arm not in ("baseline", "omitted"):
            row["producerConfig"] = (
                scenario["producer"] if arm in ("a", "ab") else ""
            )
            row["consumerConfig"] = arm in ("b", "ab")
        rows.append(row)
    return rows


def run_probe(
    source: Path,
    rows: list[dict[str, Any]],
    arm: str,
    protocol_sha: str,
    content: Path,
    godot: str,
    deadline: float,
) -> tuple[dict[str, Any], str, str]:
    plan = {
        "schemaVersion": 1, "protocolSha256": protocol_sha,
        "arm": arm, "content": str(content), "rows": rows,
    }
    plan_sha, plan_path = core.cache_json(plan)
    core.WORK.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=core.WORK, prefix="ward-spend-identity-") as tmp:
        output_path = Path(tmp) / "output.json"
        result = subprocess.run(
            [godot, "--headless", "--path", str(source), "-s", str(PROBE), "--",
             f"--plan={plan_path}", f"--out={output_path}"],
            text=True, capture_output=True, timeout=seconds_left(deadline),
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


def null_core(row: dict[str, Any]) -> dict[str, Any]:
    result = copy.deepcopy(row)
    for key in (
        "id", "configured", "factorAvailable", "producerConfig", "consumerConfig",
        "mark", "researchEvents",
    ):
        result.pop(key, None)
    result["queue"] = [
        event for event in result["queue"] if event.get("t") != RESEARCH_EVENT
    ]
    return result


def without_previews(row: dict[str, Any]) -> dict[str, Any]:
    result = null_core(row)
    result.pop("baselineEvents", None)
    for action in result["actions"]:
        action.pop("preview", None)
    return result


def research_events(row: dict[str, Any]) -> list[dict[str, Any]]:
    return [event for event in row["queue"] if event.get("t") == RESEARCH_EVENT]


def check_ab(
    scenario: dict[str, Any], treated: dict[str, Any], control: dict[str, Any],
    faults: list[str],
) -> None:
    label = scenario["id"]
    expected = scenario["expected"]

    def check(name: str, condition: bool) -> None:
        if not condition:
            faults.append(f"{label}: {name}")

    events = research_events(treated)
    check("ordered research stages",
          [event.get("stage") for event in events] == expected["stages"])
    check("producer realised credits", [
        event.get("realised") for event in events if event.get("stage") == "producer"
    ] == expected["producerCredits"])
    check("credit-set values", [
        event.get("credit") for event in events if event.get("stage") == "credit-set"
    ] == expected["producerCredits"])
    check("opportunity eligibility", [
        event.get("eligible") for event in events if event.get("stage") == "opportunity"
    ] == expected["opportunityEligible"])
    check("final mediator", treated.get("mark") == expected["markAfter"])

    if not expected["payoff"]:
        check("null path and result isolation", null_core(treated) == null_core(control))
        return

    spend = int(scenario["spend"])
    requested = int(expected["requested"])
    realised = int(expected["realised"])
    blocked = int(expected["blocked"])
    spend_events = [event for event in events if event.get("stage") == "spend"]
    requested_events = [
        event for event in events if event.get("stage") == "payoff-requested"
    ]
    realised_events = [
        event for event in events if event.get("stage") == "payoff-realised"
    ]
    check("single exact spend", len(spend_events) == 1
          and spend_events[0].get("n") == spend
          and spend_events[0].get("wardBefore") - spend
          == spend_events[0].get("wardAfter"))
    check("single requested payoff", len(requested_events) == 1
          and requested_events[0].get("n") == requested)
    check("single realised payoff", len(realised_events) == 1
          and realised_events[0].get("requested") == requested
          and realised_events[0].get("realised") == realised)

    queue = treated["queue"]
    requested_index = next((
        i for i, event in enumerate(queue)
        if event.get("t") == RESEARCH_EVENT
        and event.get("stage") == "payoff-requested"
    ), -1)
    realised_index = next((
        i for i, event in enumerate(queue)
        if event.get("t") == RESEARCH_EVENT
        and event.get("stage") == "payoff-realised"
    ), -1)
    between = [
        (i, queue[i]) for i in range(requested_index + 1, realised_index)
        if queue[i].get("t") != RESEARCH_EVENT
    ] if requested_index >= 0 and realised_index > requested_index else []
    check("single separate payoff operation", len(between) == 1)
    if len(between) != 1:
        return
    payoff_index, payoff_event = between[0]
    check("separate payoff event", payoff_event.get("t") == "hitEnemy"
          and payoff_event.get("amount") == realised
          and payoff_event.get("blocked") == blocked
          and payoff_event.get("dead") is False)

    action_index = int(expected["payoffActionIndex"])
    treated_preview = treated["actions"][action_index].get("preview")
    control_preview = control["actions"][action_index].get("preview")
    check("preview dictionaries", isinstance(treated_preview, dict)
          and isinstance(control_preview, dict))
    if isinstance(treated_preview, dict) and isinstance(control_preview, dict):
        check("truthful requested preview",
              treated_preview["hits"] == control_preview["hits"]
              + [{"dmg": requested, "times": 1}]
              and treated_preview["total"] - control_preview["total"] == requested)
        check("truthful realised preview",
              treated_preview["loss"] - control_preview["loss"] == realised)
        check("preview chip isolation", treated_preview["chips"] == control_preview["chips"])

    treated_core = without_previews(treated)
    control_core = without_previews(control)
    treated_core["queue"] = [
        event for i, event in enumerate(treated_core["queue"])
        if i != payoff_index - sum(
            1 for prior in queue[:payoff_index] if prior.get("t") == RESEARCH_EVENT
        )
    ]
    treated_core["state"]["player"]["block"] += spend
    treated_enemy = treated_core["state"]["enemies"][0]
    treated_enemy["block"] += blocked
    treated_enemy["hp"] += realised
    treated_core["runStats"]["dmgDealt"] -= realised
    check("bounded state and path isolation", treated_core == control_core)


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
        treated = cand[f"ab-{name}"]
        for arm, row in (
            ("baseline", anchor), ("omitted", omitted),
            ("off", off), ("ab", treated),
        ):
            if row.get("error"):
                faults.append(f"{name}: {arm} row error {row['error']}")
        if null_core(anchor) != null_core(omitted):
            faults.append(f"{name}: current-main versus omitted null")
        if null_core(anchor) != null_core(off):
            faults.append(f"{name}: current-main versus explicit-off null")
        if null_core(omitted) != null_core(off):
            faults.append(f"{name}: omitted versus explicit-off alias")
        check_ab(scenario, treated, off, faults)

    component = protocol["componentControlScenario"]
    off = cand[f"off-{component}"]
    a = cand[f"a-{component}"]
    b = cand[f"b-{component}"]
    ab = cand[f"ab-{component}"]
    if [event.get("stage") for event in research_events(a)] != [
        "producer", "credit-set", "opportunity"]:
        faults.append("producer-only A: ordered mediator chain")
    if a.get("mark") != {"source": "brace", "credit": 8, "turn": 1}:
        faults.append("producer-only A: realised credit")
    if null_core(a) != null_core(off):
        faults.append("producer-only A: non-telemetry drift")
    if [event.get("stage") for event in research_events(b)] != ["opportunity"]:
        faults.append("consumer-only B: opportunity cardinality")
    if b.get("mark") != {} or null_core(b) != null_core(off):
        faults.append("consumer-only B: non-null without producer")
    if research_events(a)[:2] != research_events(ab)[:2]:
        faults.append("A versus AB: producer or mediator drift")
    return faults


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite Ward-spend identity summary")
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
    component = next(
        scenario for scenario in scenarios
        if scenario["id"] == protocol["componentControlScenario"]
    )
    candidate_rows += arm_rows([component], "a") + arm_rows([component], "b")
    require("direct observation cap drift",
            len(baseline_rows) + len(candidate_rows)
            == protocol["budget"]["directControlledObservations"])
    projections = content_projections(protocol)
    require("content projection identity", {
        key: value[0] for key, value in projections.items()
    } == protocol["contentProjectionSha256"])

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
                BASELINE, baseline_rows, "current-main-base-surface", protocol_sha,
                projections["baseline"][1], immutable["godotBinaryPath"], deadline,
            )
            candidate, plans["candidate"], outputs["candidate"] = run_probe(
                CANDIDATE, candidate_rows, "instrumented-fixed-matrix", protocol_sha,
                projections["candidate"][1], immutable["godotBinaryPath"], deadline,
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
        decision = "record-ward-spend-identity-inconclusive-at-cap"
        boundary = 3
    elif faults:
        outcome = "futility"
        decision = "close-ward-spend-family-at-source-direct-gate"
        boundary = 2
    else:
        outcome = "success"
        decision = "authorise-brace-first-natural-capacity-screen"
        boundary = 1
    summary = {
        "schemaVersion": 1, "issue": 421, "outcomeClass": outcome,
        "decision": decision, "decisionBoundary": boundary,
        "claimBoundary": protocol["claimBoundary"],
        "authority": protocol["decisionRules"][outcome + "Authority"],
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "sourceIdentity": actual_source,
        "contentProjectionSha256": {
            key: value[0] for key, value in projections.items()
        },
        "sourceGateFaults": source_gate_faults, "directFaults": faults,
        "executionError": execution_error, "planSha256": plans,
        "outputSha256": outputs,
        "GodotProcesses": 0 if source_gate_faults else len(outputs),
        "directControlledObservations": completed_rows,
        "newSimulatorObservationRows": 0,
        "newLedgerRows": ledger_after["records"] - ledger_before["records"],
        "protectedSeedRows": ledger_after["protectedSeedRows"],
        "ledgerBefore": ledger_before, "ledgerAfter": ledger_after,
        "wallTimeSeconds": elapsed,
        "maximumModelContextTokensDuringExecutionAndDecision": 0,
        "archiveHeadPreserved": immutable["repositoryRefs"][
            "refs/remotes/origin/research/issue-421-post-810264c-private-causal-coverage-evidence"
        ],
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "outcomeClass": outcome, "decision": decision,
        "faults": len(faults), "rows": completed_rows,
        "wallTimeSeconds": round(elapsed, 3),
    }, sort_keys=True))


if __name__ == "__main__":
    main()
