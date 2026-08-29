#!/usr/bin/env python3
"""Engine-correct source, null and direct gate for issue #421 Ward spend v2."""

from __future__ import annotations

import copy
import json
import os
import re
import sqlite3
import subprocess
import tempfile
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-fb3deac5-ward-spend-identity-v2.json"
SUMMARY = core.ROOT / "summaries/post-fb3deac5-ward-spend-identity-v2.json"
BASELINE = core.ROOT / "ward-spend-finisher-v1-baseline"
CANDIDATE = core.ROOT / "ward-spend-finisher-v2-source"
PROBE = CANDIDATE / "tools/research_421_ward_spend_probe_v2.gd"
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
        raise TimeoutError("Ward-spend v2 direct gate reached its wall-time cap")
    return remaining


def selected_host() -> dict[str, Any]:
    sysctl = subprocess.run(
        ["sysctl", "-n", "hw.model", "machdep.cpu.brand_string",
         "hw.logicalcpu", "hw.memsize"],
        check=True, text=True, capture_output=True,
    ).stdout.splitlines()
    require("host sysctl cardinality", len(sysctl) == 4)
    return {
        "kernel": subprocess.run(
            ["uname", "-srm"], check=True, text=True, capture_output=True,
        ).stdout.strip(),
        "osVersion": subprocess.run(
            ["sw_vers", "-productVersion"], check=True, text=True,
            capture_output=True,
        ).stdout.strip(),
        "hardwareModel": sysctl[0],
        "cpu": sysctl[1],
        "logicalCpu": int(sysctl[2]),
        "memoryBytes": int(sysctl[3]),
    }


def engine_faults(protocol: dict[str, Any]) -> tuple[list[str], dict[str, Any]]:
    expected = protocol["engineIdentity"]
    binary = Path(expected["path"])
    actual: dict[str, Any] = {
        "path": str(binary),
        "version": subprocess.run(
            [str(binary), "--version"], check=True, text=True,
            capture_output=True,
        ).stdout.strip(),
        "binarySha256": core.file_sha(binary),
        "hostFingerprint": selected_host(),
    }
    actual["hostFingerprintCanonicalJsonWithLfSha256"] = core.sha(
        (core.canonical(actual["hostFingerprint"]) + "\n").encode()
    )
    faults: list[str] = []
    match = re.fullmatch(r"(\d+)\.(\d+)\.(\d+)\.stable(?:\..+)?", actual["version"])
    if match is None or tuple(map(int, match.groups())) < (4, 7, 2):
        faults.append("selected engine is not stable Godot >= 4.7.2")
    for key, value in actual.items():
        if value != expected[key]:
            faults.append(f"engine identity drift: {key}")
    return faults, actual


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
    return {
        "repositoryRefs": {
            ref: git(repository, "rev-parse", ref)
            for ref in immutable["repositoryRefs"]
        },
        "archiveCommitTypes": {
            commit: git(repository, "cat-file", "-t", commit)
            for commit in immutable["archiveCommits"]
        },
        "preCorrectionIsAncestor": subprocess.run(
            ["git", "merge-base", "--is-ancestor",
             immutable["archiveCommits"][0], immutable["archiveCommits"][1]],
            cwd=repository,
        ).returncode == 0,
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
        "runnerSha256": core.file_sha(Path(__file__)),
        "taskCapsuleSha256": core.file_sha(
            core.ROOT / immutable["taskCapsulePath"]),
    }


def static_faults() -> list[str]:
    baseline_combat = (BASELINE / "domain/rules/combat.gd").read_text()
    candidate_combat = (CANDIDATE / "domain/rules/combat.gd").read_text()
    player = (CANDIDATE / "domain/state/player_combatant.gd").read_text()
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
        ("separate preview field cardinality",
         candidate_combat.count('result["research421WardPayoff"]') == 1),
        ("Attack-only preview blood basis", "attack_loss > 0" in candidate_combat),
        ("separate non-Attack execution",
         "hit_enemy(run, cb, target, requested, false)" in candidate_combat),
        ("research field cardinality", player.count("research421_ward_spend") == 1),
        ("research field omitted from projection",
         "research421_ward_spend" not in player.split("func to_dict", 1)[1]),
        ("no random call", "rand" not in research_lines),
        ("no save surface", "research421" not in
         (CANDIDATE / "domain/state/run_state.gd").read_text().lower()),
        ("no global combat projection", "research421" not in
         (CANDIDATE / "domain/state/combat_state.gd").read_text().lower()),
        ("no policy control", "research421" not in
         (CANDIDATE / "tools/balance_policy.gd").read_text().lower()),
    )
    return [label for label, passed in checks if not passed]


def seed_faults(protocol: dict[str, Any]) -> list[str]:
    seeds = [int(scenario["row"]["seed"]) for scenario in protocol["directScenarios"]]
    faults: list[str] = []
    if len(seeds) != len(set(seeds)):
        faults.append("fresh direct identities are not unique")
    if any(3000 <= seed <= 5399 for seed in seeds):
        faults.append("protected seed entered direct identities")
    protocol_hits: list[str] = []
    for path in (core.ROOT / "protocols").glob("*.json"):
        if path.resolve() == PROTOCOL.resolve():
            continue
        text = path.read_text()
        for seed in seeds:
            if re.search(rf"(?<!\d){seed}(?!\d)", text):
                protocol_hits.append(f"{path.name}:{seed}")
    if protocol_hits:
        faults.append("fresh direct identity appears in predecessor protocol: "
                      + ", ".join(protocol_hits))
    with sqlite3.connect(f"file:{core.LEDGER}?mode=ro", uri=True) as db:
        ledger = {
            int(row[0]) for row in db.execute(
                "SELECT DISTINCT json_extract(payload_json, '$.seed') "
                "FROM records WHERE kind='observation' "
                "AND json_type(payload_json, '$.seed')='integer'"
            )
        }
    overlap = sorted(set(seeds) & ledger)
    if overlap:
        faults.append(f"fresh direct identity appears in ledger: {overlap}")
    return faults


def parse_preflight(godot: str, deadline: float) -> tuple[list[str], str]:
    env = {**os.environ, "GODOT": godot}
    result = subprocess.run(
        [str(CANDIDATE / "tools/check_scripts.sh"),
         "domain/rules/combat.gd", "domain/state/player_combatant.gd",
         "tools/research_421_ward_spend_probe_v2.gd"],
        cwd=CANDIDATE, env=env, text=True, capture_output=True,
        timeout=seconds_left(deadline),
    )
    transcript = (result.stdout + result.stderr)[-8000:]
    faults = [] if result.returncode == 0 and "scripts OK (3 checked)" in result.stdout \
        else ["candidate GDScript mechanical parse preflight"]
    return faults, transcript


def arm_rows(scenarios: list[dict[str, Any]], arm: str) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for scenario in scenarios:
        row = copy.deepcopy(scenario["row"])
        row["id"] = f"{arm}-{scenario['id']}"
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
    counter: list[int],
    configuration: dict[str, Any] | None = None,
) -> tuple[dict[str, Any], str, str]:
    plan: dict[str, Any] = {
        "schemaVersion": 2, "protocolSha256": protocol_sha,
        "arm": arm, "content": str(content), "rows": rows,
    }
    if configuration is not None:
        plan["configuration"] = configuration
    plan_sha, plan_path = core.cache_json(plan)
    core.WORK.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=core.WORK, prefix="ward-spend-v2-") as tmp:
        output_path = Path(tmp) / "output.json"
        counter[0] += 1
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
    require(f"{arm} output probe identity",
            output.get("probeSha256") == core.file_sha(PROBE))
    require(f"{arm} output row count", len(output.get("rows", [])) == len(rows))
    output_sha, _ = core.cache_json(output)
    return output, plan_sha, output_sha


def by_id(output: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {str(row["id"]): row for row in output["rows"]}


def null_core(row: dict[str, Any]) -> dict[str, Any]:
    result = copy.deepcopy(row)
    for key in (
        "id", "configured", "factorAvailable", "mark", "researchEvents",
    ):
        result.pop(key, None)
    result["queue"] = [
        event for event in result["queue"] if event.get("t") != RESEARCH_EVENT
    ]
    return result


def without_previews(row: dict[str, Any]) -> dict[str, Any]:
    result = null_core(row)
    for action in result["actions"]:
        action.pop("preview", None)
    return result


def research_events(row: dict[str, Any]) -> list[dict[str, Any]]:
    return list(row["researchEvents"])


def normalise_enabled_core(
    row: dict[str, Any], payoff_full_index: int, spend: int,
    realised: int, blocked: int,
) -> dict[str, Any]:
    result = without_previews(row)
    full_queue = row["queue"]
    ordinary_index = sum(
        1 for event in full_queue[:payoff_full_index]
        if event.get("t") != RESEARCH_EVENT
    )
    result["queue"].pop(ordinary_index)
    result["ordinaryEvents"].pop(ordinary_index)
    for events in (result["queue"], result["ordinaryEvents"]):
        for event in events[ordinary_index:]:
            if event.get("t") == "hitEnemy" and event.get("idx") == 0:
                event["hpAfter"] = int(event["hpAfter"]) + realised
    result["state"]["player"]["block"] += spend
    result["state"]["enemies"][0]["block"] += blocked
    result["state"]["enemies"][0]["hp"] += realised
    result["runStats"]["dmgDealt"] -= realised
    return result


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
        check("ordinary preview hits isolated",
              treated_preview.get("hits") == control_preview.get("hits"))
        check("separate preview payload",
              treated_preview.get("research421WardPayoff") == {
                  "requested": requested, "blocked": blocked, "realised": realised,
              })
        check("truthful requested preview",
              treated_preview.get("total", 0) - control_preview.get("total", 0)
              == requested)
        check("truthful realised preview",
              treated_preview.get("loss", 0) - control_preview.get("loss", 0)
              == realised)
        check("preview chip isolation",
              treated_preview.get("chips") == control_preview.get("chips"))

    treated_core = normalise_enabled_core(
        treated, payoff_index, spend, realised, blocked)
    control_core = without_previews(control)
    check("bounded causal state and path isolation", treated_core == control_core)


def direct_faults(
    protocol: dict[str, Any], outputs: dict[str, dict[str, Any]],
) -> list[str]:
    faults: list[str] = []
    base = by_id(outputs["baseline"])
    omitted = by_id(outputs["omitted"])
    off = by_id(outputs["off"])
    ab: dict[str, dict[str, Any]] = {}
    for key, output in outputs.items():
        if key.startswith("ab-"):
            ab.update(by_id(output))
    for scenario in protocol["directScenarios"]:
        name = scenario["id"]
        anchor = base[f"baseline-{name}"]
        omitted_row = omitted[f"omitted-{name}"]
        off_row = off[f"off-{name}"]
        treated = ab[f"ab-{name}"]
        for arm, row in (
            ("baseline", anchor), ("omitted", omitted_row),
            ("off", off_row), ("ab", treated),
        ):
            if row.get("error"):
                faults.append(f"{name}: {arm} row error {row['error']}")
        if null_core(anchor) != null_core(omitted_row):
            faults.append(f"{name}: current-main versus omitted null")
        if null_core(anchor) != null_core(off_row):
            faults.append(f"{name}: current-main versus explicit-off null")
        if null_core(omitted_row) != null_core(off_row):
            faults.append(f"{name}: omitted versus explicit-off alias")
        check_ab(scenario, treated, off_row, faults)

    component = protocol["componentControlScenario"]
    control = off[f"off-{component}"]
    a = by_id(outputs["a"])[f"a-{component}"]
    b = by_id(outputs["b"])[f"b-{component}"]
    treated = ab[f"ab-{component}"]
    if [event.get("stage") for event in research_events(a)] != [
        "producer", "credit-set", "opportunity"]:
        faults.append("producer-only A: ordered mediator chain")
    if a.get("mark") != {"source": "brace", "credit": 8, "turn": 1}:
        faults.append("producer-only A: realised credit")
    if null_core(a) != null_core(control):
        faults.append("producer-only A: non-telemetry drift")
    if [event.get("stage") for event in research_events(b)] != ["opportunity"]:
        faults.append("consumer-only B: opportunity cardinality")
    if b.get("mark") != {} or null_core(b) != null_core(control):
        faults.append("consumer-only B: non-null without producer")
    if research_events(a)[:2] != research_events(treated)[:2]:
        faults.append("A versus AB: producer or mediator drift")
    return faults


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite Ward-spend v2 identity summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    immutable = protocol["immutableInputs"]
    engine_preflight_faults, engine = engine_faults(protocol)
    actual_source = source_identity(protocol)
    require("immutable source identity drift", actual_source == {
        key: immutable[key] for key in actual_source
    })
    ledger_before = identity.ledger_identity()
    require("ledger freeze drift", ledger_before == protocol["ledgerFreeze"])
    source_gate_faults = engine_preflight_faults + static_faults() + seed_faults(protocol)
    started = time.monotonic()
    deadline = started + protocol["budget"]["maximumWallTimeSeconds"]
    parse_transcript = ""
    godot_processes = [0]
    if not source_gate_faults:
        parse_faults, parse_transcript = parse_preflight(engine["path"], deadline)
        godot_processes[0] += 3
        source_gate_faults.extend(parse_faults)

    outputs: dict[str, dict[str, Any]] = {}
    output_shas: dict[str, str] = {}
    plan_shas: dict[str, str] = {}
    projection_shas: dict[str, str] = {}
    execution_error = ""
    faults = list(source_gate_faults)
    completed_rows = 0
    if not source_gate_faults:
        try:
            projections = content_projections(protocol)
            projection_shas = {key: value[0] for key, value in projections.items()}
            require("content projection identity",
                    projection_shas == protocol["contentProjectionSha256"])
            scenarios = protocol["directScenarios"]
            calls: list[tuple[str, Path, list[dict[str, Any]], Path,
                              dict[str, Any] | None]] = [
                ("baseline", BASELINE, arm_rows(scenarios, "baseline"),
                 projections["baseline"][1], None),
                ("omitted", CANDIDATE, arm_rows(scenarios, "omitted"),
                 projections["candidate"][1], None),
                ("off", CANDIDATE, arm_rows(scenarios, "off"),
                 projections["candidate"][1], {
                     "producer": "", "consumer": False, "spend": 4, "numerator": 1,
                 }),
            ]
            component = next(
                scenario for scenario in scenarios
                if scenario["id"] == protocol["componentControlScenario"]
            )
            calls.extend([
                ("a", CANDIDATE, arm_rows([component], "a"),
                 projections["candidate"][1], {
                     "producer": "brace", "consumer": False,
                     "spend": component["spend"], "numerator": component["numerator"],
                 }),
                ("b", CANDIDATE, arm_rows([component], "b"),
                 projections["candidate"][1], {
                     "producer": "", "consumer": True,
                     "spend": component["spend"], "numerator": component["numerator"],
                 }),
            ])
            for spend, numerator in ((4, 1), (4, 2), (8, 1), (8, 2)):
                selected = [
                    scenario for scenario in scenarios
                    if scenario["spend"] == spend and scenario["numerator"] == numerator
                ]
                calls.append((
                    f"ab-{spend}-{numerator}", CANDIDATE,
                    arm_rows(selected, "ab"), projections["candidate"][1], {
                        "producer": "brace", "consumer": True,
                        "spend": spend, "numerator": numerator,
                    },
                ))
            require("Godot direct-process cardinality", len(calls) == 9)
            for arm, source, rows, content, configuration in calls:
                output, plan_sha, output_sha = run_probe(
                    source, rows, arm, protocol_sha, content, engine["path"],
                    deadline, godot_processes, configuration,
                )
                outputs[arm] = output
                plan_shas[arm] = plan_sha
                output_shas[arm] = output_sha
                completed_rows += len(output["rows"])
            require("direct observation cardinality",
                    completed_rows == protocol["budget"]["directControlledObservations"])
            faults.extend(direct_faults(protocol, outputs))
        except (OSError, subprocess.SubprocessError, TimeoutError, RuntimeError) as error:
            execution_error = str(error)

    ledger_after = identity.ledger_identity()
    if ledger_after != ledger_before:
        faults.append("append-only ledger changed")
    elapsed = time.monotonic() - started
    if execution_error or elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        outcome = "inconclusive"
        decision = "record-ward-spend-v2-identity-inconclusive-at-cap"
        boundary = 3
    elif faults:
        outcome = "futility"
        decision = "close-ward-spend-v2-representation-at-source-direct-gate"
        boundary = 2
    else:
        outcome = "success"
        decision = "authorise-brace-first-natural-capacity-screen-v2"
        boundary = 1
    summary = {
        "schemaVersion": 2, "issue": 421, "outcomeClass": outcome,
        "decision": decision, "decisionBoundary": boundary,
        "claimBoundary": protocol["claimBoundary"],
        "authority": protocol["decisionRules"][outcome + "Authority"],
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "engineIdentity": engine, "sourceIdentity": actual_source,
        "contentProjectionSha256": projection_shas,
        "sourceGateFaults": source_gate_faults, "directFaults": faults,
        "executionError": execution_error, "parseTranscript": parse_transcript,
        "planSha256": plan_shas, "outputSha256": output_shas,
        "GodotProcesses": godot_processes[0],
        "directControlledObservations": completed_rows,
        "newSimulatorObservationRows": 0,
        "newLedgerRows": ledger_after["records"] - ledger_before["records"],
        "protectedSeedRows": ledger_after["protectedSeedRows"],
        "ledgerBefore": ledger_before, "ledgerAfter": ledger_after,
        "wallTimeSeconds": elapsed,
        "maximumModelContextTokensDuringExecutionAndDecision": 0,
        "immutableQuarantinedObservationCount": 82,
        "quarantinedObservationsUsedForDecision": 0,
        "archiveHeadsPreserved": immutable["archiveCommits"],
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "outcomeClass": outcome, "decision": decision,
        "faults": len(faults), "rows": completed_rows,
        "GodotProcesses": godot_processes[0],
        "wallTimeSeconds": round(elapsed, 3),
    }, sort_keys=True))


if __name__ == "__main__":
    main()
