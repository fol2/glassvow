#!/usr/bin/env python3
"""Preregistered source, whole-run and direct identity gate for issue #421."""

from __future__ import annotations

import argparse
import copy
import json
import os
import re
import sqlite3
import subprocess
import tempfile
import time
from collections import Counter
from pathlib import Path
from typing import Any

import research as core


PROTOCOL = core.ROOT / "protocols/post-1127ed7e-target-acts-last-identity-v2.json"
SUMMARY = core.ROOT / "summaries/post-1127ed7e-target-acts-last-identity-v2.json"
BASELINE = core.ROOT / "current-main-delta-v1"
CANDIDATE = core.ROOT / "target-acts-last-identity-source-v1"
PROBE = CANDIDATE / "tools/research_421_target_acts_last_identity_probe_v1.gd"
PRODUCT_FILES = (
    "domain/rules/combat.gd",
    "domain/events/event_types.gd",
    "presentation/combat/combat_screen.gd",
)
CHECK_FILES = (*PRODUCT_FILES, "tools/research_421_target_acts_last_identity_probe_v1.gd")
CARD_ID = "research421TargetActsLast"
EVENT_ID = "research421TargetActsLast"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(label)


def git(path: Path, *args: str) -> str:
    return subprocess.run(
        ["git", *args], cwd=path, check=True, text=True, capture_output=True,
    ).stdout.strip()


def file_status(path: Path) -> list[str]:
    return subprocess.run(
        ["git", "status", "--porcelain=v1"], cwd=path, check=True,
        text=True, capture_output=True,
    ).stdout.splitlines()


def research_card() -> dict[str, Any]:
    return {
        "type": "skill", "rarity": "special", "cost": 1,
        "target": "enemy", "vfx": "ward",
        "effects": [{"kind": "special", "id": CARD_ID}],
        "name": "Last Light", "text": "Research projection.",
    }


def projected_content(
    write: bool, cache_writes: list[int] | None = None,
) -> tuple[str, Path | None]:
    raw = json.loads((BASELINE / "content/full-content.json").read_text())
    require("research card already exists in current-main content", CARD_ID not in raw["cards"])
    raw["cards"][CARD_ID] = research_card()
    data = (core.canonical(raw) + "\n").encode()
    digest = core.sha(data)
    if not write:
        return digest, None
    path = core.CACHE / f"{digest}.json"
    existed = path.exists()
    actual, path = core.cache_bytes(data, "json")
    if cache_writes is not None and not existed:
        cache_writes[0] += 1
    require("content projection hash", actual == digest)
    return digest, path


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
        "hardwareModel": sysctl[0], "cpu": sysctl[1],
        "logicalCpu": int(sysctl[2]), "memoryBytes": int(sysctl[3]),
    }


def engine_identity(protocol: dict[str, Any]) -> tuple[dict[str, Any], list[str]]:
    expected = protocol["engineIdentity"]
    binary = Path(expected["path"])
    actual = {
        "path": str(binary),
        "version": subprocess.run(
            [str(binary), "--version"], check=True, text=True, capture_output=True,
        ).stdout.strip(),
        "binarySha256": core.file_sha(binary),
        "host": selected_host(),
    }
    faults: list[str] = []
    match = re.fullmatch(r"(\d+)\.(\d+)\.(\d+)\.stable(?:\..+)?", actual["version"])
    if match is None or tuple(map(int, match.groups())) < (4, 7, 2):
        faults.append("selected engine is not stable Godot >= 4.7.2")
    for key, expected_value in expected.items():
        if actual.get(key) != expected_value:
            faults.append(f"engine identity drift: {key}")
    return actual, faults


def source_identity(protocol: dict[str, Any]) -> dict[str, Any]:
    immutable = protocol["immutableInputs"]
    diff = subprocess.run(
        ["git", "diff", "--binary", "--", *CHECK_FILES], cwd=CANDIDATE,
        check=True, capture_output=True,
    ).stdout
    return {
        "baselineHead": git(BASELINE, "rev-parse", "HEAD"),
        "candidateHead": git(CANDIDATE, "rev-parse", "HEAD"),
        "baselineStatus": file_status(BASELINE),
        "candidateStatus": file_status(CANDIDATE),
        "changedFiles": sorted(git(CANDIDATE, "diff", "--name-only").splitlines()),
        "baselineSha256": {
            name: core.file_sha(BASELINE / name) for name in immutable["baselineSha256"]
        },
        "candidateSha256": {
            name: core.file_sha(CANDIDATE / name) for name in immutable["candidateSha256"]
        },
        "prototypeDiffSha256": core.sha(diff),
        "runnerSha256": core.file_sha(Path(__file__)),
        "protocolSha256": core.file_sha(PROTOCOL),
        "taskCapsuleSha256": core.file_sha(core.ROOT / immutable["taskCapsulePath"]),
        "evidenceSha256": {
            name: core.file_sha(core.ROOT / name)
            for name in immutable["evidenceSha256"]
        },
    }


def static_faults(protocol: dict[str, Any], actual: dict[str, Any]) -> list[str]:
    immutable = protocol["immutableInputs"]
    faults: list[str] = []
    expected = {
        "baselineHead": immutable["sourceHead"],
        "candidateHead": immutable["sourceHead"],
        "baselineStatus": [],
        "candidateStatus": immutable["candidateStatus"],
        "changedFiles": sorted(CHECK_FILES),
        "baselineSha256": immutable["baselineSha256"],
        "candidateSha256": immutable["candidateSha256"],
        "prototypeDiffSha256": immutable["prototypeDiffSha256"],
        "runnerSha256": immutable["runnerSha256"],
        "taskCapsuleSha256": immutable["taskCapsuleSha256"],
        "evidenceSha256": immutable["evidenceSha256"],
    }
    for key, value in expected.items():
        if actual.get(key) != value:
            faults.append(f"source identity drift: {key}")
    combat = (CANDIDATE / PRODUCT_FILES[0]).read_text()
    event_types = (CANDIDATE / PRODUCT_FILES[1]).read_text()
    presentation = (CANDIDATE / PRODUCT_FILES[2]).read_text()
    diff_text = subprocess.run(
        ["git", "diff", "--", *PRODUCT_FILES], cwd=CANDIDATE,
        check=True, text=True, capture_output=True,
    ).stdout
    checks = (
        ("one default-false switch",
         combat.count("_research421_target_acts_last_enabled: bool = false") == 1),
        ("one configuration interface",
         combat.count("configure_research421_target_acts_last") == 1),
        ("one research special dispatch",
         combat.count('"research421TargetActsLast":') == 1),
        ("fight-local flag carrier",
         "RESEARCH421_TARGET_ACTS_LAST_FLAG" in combat),
        ("local phase array", "enemy_phase_order" in combat),
        ("enemy array is not reassigned", "cb.enemies =" not in diff_text),
        ("one event constant",
         event_types.count("RESEARCH421_TARGET_ACTS_LAST") == 1),
        ("one presentation branch",
         presentation.count("EventTypes.RESEARCH421_TARGET_ACTS_LAST:") == 1),
        ("no run-state field", "research421" not in
         (CANDIDATE / "domain/state/run_state.gd").read_text().lower()),
        ("no combat-state field", "research421" not in
         (CANDIDATE / "domain/state/combat_state.gd").read_text().lower()),
        ("no policy change", "research421" not in
         (CANDIDATE / "tools/balance_policy.gd").read_text().lower()),
        ("no simulator change", "research421" not in
         (CANDIDATE / "tools/balance_sim.gd").read_text().lower()),
        ("separate factors absent", "scoreline" not in diff_text.lower()
         and "afterimage" not in diff_text.lower()),
        ("no research RNG", not any(
            "rng" in line.lower() for line in diff_text.splitlines()
            if line.startswith("+") and "research421" in line.lower()
        )),
    )
    faults.extend(label for label, passed in checks if not passed)
    return faults


def all_seeds(protocol: dict[str, Any]) -> list[int]:
    return [int(row["seed"]) for row in protocol["wholeRunRows"]] + [
        int(row["seed"]) for row in protocol["directScenarios"]
    ]


def budget_faults(protocol: dict[str, Any]) -> list[str]:
    budget = protocol["budget"]
    direct = len(protocol["directScenarios"])
    whole = len(protocol["wholeRunRows"])
    planned_godot = len(CHECK_FILES) + 4
    checks = (
        ("direct scenario cap", direct <= int(budget["maximumDirectScenarios"])),
        ("direct execution plan", direct * 2
         == int(budget["plannedDirectControlledExecutions"])),
        ("whole-run row cap", whole <= int(budget["maximumWholeRunNullRowsPerArm"])),
        ("whole-run row plan", whole == int(budget["plannedWholeRunRowsPerArm"])),
        ("whole-run output plan", whole * 2 == int(budget["plannedWholeRunOutputRows"])),
        ("simulator execution plan", whole * 4
         == int(budget["plannedSimulatorExecutionsIncludingEstimatorChecks"])
         <= int(budget["maximumSimulatorObservationRows"])),
        ("Godot process plan", planned_godot
         == int(budget["expectedGodotProcessesWithoutCorrection"])
         <= int(budget["maximumGodotProcesses"])),
        ("cache write plan", 1 + 4 * 2 <= int(budget["maximumCacheObjectWrites"])),
        ("one ledger read ceiling", int(budget["maximumLedgerReadOnlyTransactions"]) == 1),
        ("zero ledger writes", int(budget["maximumLedgerWrites"]) == 0),
        ("zero protected rows", int(budget["maximumProtectedSeedRows"]) == 0),
        ("positive wall cap", float(budget["maximumWallTimeSeconds"]) > 0.0),
        ("zero decision context", int(
            budget["maximumModelContextTokensDuringExecutionAndDecision"]) == 0),
        ("exhausted correction cap", int(budget["mechanicalCorrectionCap"]) == 1
         and protocol["correction"]["cap"] == {
             "permitted": 1, "used": 1, "remaining": 0,
         }),
        ("zero candidates", int(budget["candidateCount"]) == 0),
        ("zero optimiser runs", int(budget["MLRLOptimiserRuns"]) == 0),
    )
    return [label for label, passed in checks if not passed]


def ledger_and_seed_faults(protocol: dict[str, Any]) -> tuple[dict[str, Any], list[str]]:
    seeds = all_seeds(protocol)
    faults: list[str] = []
    if len(seeds) != len(set(seeds)):
        faults.append("frozen identities are not unique")
    if any(3000 <= seed <= 5399 for seed in seeds):
        faults.append("protected identity entered the gate")
    hits: list[str] = []
    predecessor = protocol["correction"]["preCorrectionProtocol"]
    predecessor_path = (core.ROOT / predecessor["path"]).resolve()
    if core.file_sha(predecessor_path) != predecessor["sha256"]:
        faults.append("bound pre-correction protocol drift")
    allowed_protocols = {PROTOCOL.resolve(), predecessor_path}
    for path in (core.ROOT / "protocols").glob("*.json"):
        if path.resolve() in allowed_protocols:
            continue
        text = path.read_text()
        for seed in seeds:
            if re.search(rf"(?<!\d){seed}(?!\d)", text):
                hits.append(f"{path.name}:{seed}")
    if hits:
        faults.append("identity appears in predecessor protocol: " + ", ".join(hits))
    before_sha = core.file_sha(core.LEDGER)
    with sqlite3.connect(f"file:{core.LEDGER}?mode=ro", uri=True) as db:
        db.execute("PRAGMA query_only=ON")
        records, first, last = db.execute(
            "SELECT COUNT(*), MIN(seq), MAX(seq) FROM records"
        ).fetchone()
        protected = db.execute(
            "SELECT COUNT(*) FROM records WHERE kind='observation' "
            "AND CAST(json_extract(payload_json, '$.seed') AS INTEGER) "
            "BETWEEN 3000 AND 5399"
        ).fetchone()[0]
        used = {
            int(row[0]) for row in db.execute(
                "SELECT DISTINCT json_extract(payload_json, '$.seed') FROM records "
                "WHERE kind='observation' "
                "AND json_type(payload_json, '$.seed')='integer'"
            )
        }
        integrity = db.execute("PRAGMA integrity_check").fetchone()[0]
    overlap = sorted(set(seeds) & used)
    if overlap:
        faults.append(f"identity appears in ledger: {overlap}")
    actual = {
        "sha256": before_sha, "records": records, "firstSequence": first,
        "lastSequence": last, "protectedSeedRows": protected,
        "sqliteIntegrity": integrity,
    }
    if actual != protocol["ledgerFreeze"]:
        faults.append("ledger freeze drift")
    return actual, faults


def seconds_left(deadline: float) -> int:
    remaining = int(deadline - time.monotonic())
    if remaining < 1:
        raise TimeoutError("identity gate reached its wall-time cap")
    return remaining


def parse_preflight(godot: str, deadline: float) -> tuple[list[str], str, int]:
    result = subprocess.run(
        [str(CANDIDATE / "tools/check_scripts.sh"), *CHECK_FILES],
        cwd=CANDIDATE, env={**os.environ, "GODOT": godot}, text=True,
        capture_output=True, timeout=seconds_left(deadline),
    )
    transcript = (result.stdout + result.stderr)[-12000:]
    faults = [] if result.returncode == 0 \
        and f"scripts OK ({len(CHECK_FILES)} checked)" in result.stdout \
        else ["candidate GDScript parse preflight"]
    return faults, transcript, len(CHECK_FILES)


def run_probe(
    source: Path, plan: dict[str, Any], content: Path, godot: str,
    deadline: float, process_count: list[int], cache_writes: list[int],
) -> tuple[dict[str, Any], str, str]:
    payload = copy.deepcopy(plan)
    payload["content"] = str(content)
    expected_plan_sha = core.sha((core.canonical(payload) + "\n").encode())
    plan_existed = (core.CACHE / f"{expected_plan_sha}.json").exists()
    plan_sha, plan_path = core.cache_json(payload)
    if not plan_existed:
        cache_writes[0] += 1
    core.WORK.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=core.WORK, prefix="target-last-identity-") as tmp:
        output_path = Path(tmp) / "output.json"
        process_count[0] += 1
        result = subprocess.run(
            [godot, "--headless", "--path", str(source), "-s", str(PROBE), "--",
             f"--plan={plan_path}", f"--out={output_path}"],
            text=True, capture_output=True, timeout=seconds_left(deadline),
        )
        if result.returncode != 0 or not output_path.is_file():
            raise RuntimeError(
                f"probe failed ({result.returncode})\n"
                f"{result.stdout[-3000:]}\n{result.stderr[-5000:]}"
            )
        output = json.loads(output_path.read_text())
    require("probe plan identity", output.get("planSha256") == plan_sha)
    require("probe source identity", output.get("probeSha256") == core.file_sha(PROBE))
    require("probe row array", isinstance(output.get("rows"), list))
    expected_output_sha = core.sha((core.canonical(output) + "\n").encode())
    output_existed = (core.CACHE / f"{expected_output_sha}.json").exists()
    output_sha, _ = core.cache_json(output)
    if not output_existed:
        cache_writes[0] += 1
    return output, plan_sha, output_sha


def rows_by_id(output: dict[str, Any]) -> dict[str, dict[str, Any]]:
    rows = output["rows"]
    result = {str(row["id"]): row for row in rows}
    require("unique output row IDs", len(result) == len(rows))
    return result


def check_whole(
    protocol: dict[str, Any], baseline: dict[str, Any], candidate: dict[str, Any],
) -> dict[str, Any]:
    left, right = rows_by_id(baseline), rows_by_id(candidate)
    expected = {str(row["id"]) for row in protocol["wholeRunRows"]}
    require("whole-run IDs", set(left) == expected and set(right) == expected)
    digests: dict[str, str] = {}
    outcomes: Counter[str] = Counter()
    for row_id in sorted(expected):
        require(f"whole-run exact row {row_id}", left[row_id] == right[row_id])
        row = left[row_id]
        require(f"whole-run reliability {row_id}", not row.get("error")
                and row.get("outcome") != "error")
        trajectory = row.get("trajectory")
        require(f"whole-run trajectory {row_id}", isinstance(trajectory, dict)
                and isinstance(trajectory.get("nodes"), list)
                and isinstance(trajectory.get("combats"), list)
                and all(isinstance(combat.get("events"), list)
                        for combat in trajectory["combats"]))
        digests[row_id] = core.sha((core.canonical(row) + "\n").encode())
        outcomes[str(row["outcome"])] += 1
    return {
        "identities": len(expected), "armRows": len(expected) * 2,
        "simulatorExecutionsIncludingEstimatorChecks": len(expected) * 4,
        "completeMismatchRows": 0, "pathMismatchRows": 0,
        "eventSequenceMismatchRows": 0, "rngMismatchRows": 0,
        "resultMismatchRows": 0, "rowSha256": digests,
        "outcomes": dict(sorted(outcomes.items())),
    }


def marker_steps(row: dict[str, Any]) -> list[list[int]]:
    return [list(step.get("markersAfter", [])) for step in row["steps"]]


def strip_direct(row: dict[str, Any]) -> dict[str, Any]:
    value = copy.deepcopy(row)
    for key in ("enabled", "factorAvailable", "markers", "researchEvents"):
        value.pop(key, None)
    value["queue"] = [event for event in value["queue"] if event.get("t") != EVENT_ID]
    for step in value["steps"]:
        step.pop("markersAfter", None)
        step["events"] = [event for event in step["events"] if event.get("t") != EVENT_ID]
    return value


def action_sequence(row: dict[str, Any]) -> list[tuple[int, str]]:
    return [
        (int(event["idx"]), str(event["move"])) for event in row["ordinaryEvents"]
        if event.get("t") == "enemyAct"
    ]


def action_blocks(
    row: dict[str, Any], player_damage_adjust: int = 0,
) -> dict[tuple[int, str], list[dict[str, Any]]]:
    blocks: dict[tuple[int, str], list[dict[str, Any]]] = {}
    current: tuple[int, str] | None = None
    for source in row["ordinaryEvents"]:
        event = copy.deepcopy(source)
        if event.get("t") == "enemyAct":
            current = (int(event["idx"]), str(event["move"]))
            require("unique enemy action block", current not in blocks)
            blocks[current] = []
            continue
        if event.get("t") == "intent":
            current = None
            continue
        if current is None:
            continue
        if event.get("t") == "hitPlayer" and player_damage_adjust:
            event["amount"] = int(event["amount"]) + player_damage_adjust
            event["hpAfter"] = int(event["hpAfter"]) - player_damage_adjust
        blocks[current].append(event)
    return blocks


def event_multiset(row: dict[str, Any], hp_adjust: int = 0) -> Counter[str]:
    events = copy.deepcopy(row["ordinaryEvents"])
    for event in events:
        if event.get("t") == "hitPlayer" and hp_adjust:
            event["amount"] = int(event["amount"]) + hp_adjust
            event["hpAfter"] = int(event["hpAfter"]) - hp_adjust
    return Counter(core.canonical(event) for event in events)


def check_consumption_event(row: dict[str, Any], expected: dict[str, Any]) -> None:
    require("one target-last consumption event", len(row["researchEvents"]) == 1)
    event = row["researchEvents"][0]
    require("exact target-last consumption event", event == {
        "t": EVENT_ID,
        "targetIdx": expected["targetIdx"],
        "beforeLivingPosition": expected["beforeLivingPosition"],
        "afterLivingPosition": expected["afterLivingPosition"],
        "moved": expected["moved"],
    })


def check_direct(
    protocol: dict[str, Any], off_output: dict[str, Any], on_output: dict[str, Any],
) -> dict[str, Any]:
    off, on = rows_by_id(off_output), rows_by_id(on_output)
    expected_ids = {str(row["id"]) for row in protocol["directScenarios"]}
    require("direct IDs", set(off) == expected_ids and set(on) == expected_ids)
    positive: dict[str, Any] = {}
    null_rows: list[str] = []
    for scenario in protocol["directScenarios"]:
        row_id = str(scenario["id"])
        control, treated = off[row_id], on[row_id]
        require(f"direct off reliability {row_id}", control.get("error") == "")
        require(f"direct on reliability {row_id}", treated.get("error") == "")
        require(f"direct initial RNG {row_id}", control["rngBefore"] == treated["rngBefore"])
        require(f"direct off event isolation {row_id}", control["researchEvents"] == [])
        require(f"direct off marker isolation {row_id}", control["markers"] == []
                and all(markers == [] for markers in marker_steps(control)))
        kind = str(scenario["expected"]["kind"])
        if kind in {"ash-reject", "dead-target", "replay", "target-death", "combat-end"}:
            require(f"direct null core {row_id}", strip_direct(control) == strip_direct(treated))
            require(f"direct null RNG {row_id}", control["rngAfter"] == treated["rngAfter"])
            require(f"direct null events {row_id}", treated["researchEvents"] == [])
            require(f"direct marker steps {row_id}", marker_steps(treated)
                    == scenario["expected"]["markersAfterSteps"])
            require(f"direct final markers {row_id}", treated["markers"]
                    == scenario["expected"]["finalMarkers"])
            null_rows.append(row_id)
            continue
        expected = scenario["expected"]
        check_consumption_event(treated, expected)
        require(f"direct marker consumption {row_id}", marker_steps(treated)
                == expected["markersAfterSteps"] and treated["markers"] == [])
        require(f"direct RNG identity {row_id}", control["rngAfter"] == treated["rngAfter"])
        if kind == "already-last":
            require(f"already-last ordinary path {row_id}",
                    strip_direct(control) == strip_direct(treated))
            require(f"already-last sequence {row_id}",
                    action_sequence(control) == action_sequence(treated))
            null_rows.append(row_id)
            continue
        require(f"positive kind {row_id}", kind == "positive")
        off_sequence = action_sequence(control)
        on_sequence = action_sequence(treated)
        require(f"positive baseline order {row_id}", off_sequence
                == [tuple(item) for item in expected["baselineActionSequence"]])
        require(f"positive treated order {row_id}", on_sequence
                == [tuple(item) for item in expected["treatedActionSequence"]])
        require(f"positive action multiset {row_id}", Counter(off_sequence) == Counter(on_sequence))
        delta = int(expected["playerDamageDelta"])
        require(f"positive HP mediator {row_id}",
                int(treated["state"]["player"]["hp"])
                - int(control["state"]["player"]["hp"]) == delta)
        require(f"positive hpLost mediator {row_id}",
                int(control["hpLost"]) - int(treated["hpLost"]) == delta)
        require(f"positive damage-stat mediator {row_id}",
                int(control["runStats"]["dmgTaken"])
                - int(treated["runStats"]["dmgTaken"]) == delta)
        normalised_state = copy.deepcopy(treated["state"])
        normalised_state["player"]["hp"] -= delta
        require(f"positive state isolation {row_id}", normalised_state == control["state"])
        normalised_stats = copy.deepcopy(treated["runStats"])
        normalised_stats["dmgTaken"] += delta
        require(f"positive stats isolation {row_id}", normalised_stats == control["runStats"])
        require(f"positive history isolation {row_id}", treated["lastMoves"] == control["lastMoves"])
        require(f"positive internal action order {row_id}",
                action_blocks(treated, delta) == action_blocks(control))
        require(f"positive event multiset {row_id}",
                event_multiset(treated, delta) == event_multiset(control))
        positive[row_id] = {
            "baselineActionSequence": off_sequence,
            "treatedActionSequence": on_sequence,
            "playerDamageDelta": delta,
            "rngAfter": treated["rngAfter"],
            "laterMove": on_sequence[0][1],
        }
    return {
        "scenarios": len(expected_ids), "armRows": len(expected_ids) * 2,
        "positive": positive, "identitySafeNullRows": sorted(null_rows),
        "rngMismatchRows": 0, "unintendedMediatorRows": 0,
    }


def write_once(path: Path, value: dict[str, Any]) -> None:
    data = (json.dumps(value, indent=2, sort_keys=True) + "\n").encode()
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL
    descriptor = os.open(path, flags, 0o644)
    with os.fdopen(descriptor, "wb") as file:
        file.write(data)


def self_test() -> None:
    digest, path = projected_content(False)
    require("self-test projected content digest", len(digest) == 64 and path is None)
    sample = {
        "id": "x", "enabled": True, "factorAvailable": True,
        "markers": [0], "researchEvents": [{"t": EVENT_ID}],
        "queue": [{"t": EVENT_ID}, {"t": "play"}],
        "steps": [{"markersAfter": [0], "events": [{"t": EVENT_ID}, {"t": "play"}]}],
    }
    stripped = strip_direct(sample)
    require("self-test research event stripping", stripped["queue"] == [{"t": "play"}]
            and stripped["steps"] == [{"events": [{"t": "play"}]}])
    require("self-test action multiset",
            Counter([(0, "surge"), (1, "shock")])
            == Counter([(1, "shock"), (0, "surge")]))
    action_row = {"ordinaryEvents": [
        {"t": "enemyAct", "idx": 1, "move": "shock"},
        {"t": "hitPlayer", "amount": 8, "hpAfter": 92},
        {"t": "enemyAct", "idx": 0, "move": "surge"},
        {"t": "status", "idx": 1, "id": "str", "n": 2},
        {"t": "intent", "idx": 0, "move": "surge"},
    ]}
    require("self-test ordered action block normalisation",
            action_blocks(action_row, 2) == {
                (1, "shock"): [{"t": "hitPlayer", "amount": 10, "hpAfter": 90}],
                (0, "surge"): [{"t": "status", "idx": 1, "id": "str", "n": 2}],
            })
    protocol = json.loads(PROTOCOL.read_text())
    require("self-test frozen budget", budget_faults(protocol) == [])
    with tempfile.TemporaryDirectory() as tmp:
        target = Path(tmp) / "once.json"
        write_once(target, {"ok": True})
        try:
            write_once(target, {"ok": False})
        except FileExistsError:
            pass
        else:
            raise RuntimeError("self-test no-overwrite failed")
    print("PASS (6 checks)")


def _main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite target-acts-last identity summary")
    try:
        protocol, protocol_sha = core.load_protocol(PROTOCOL)
    except (OSError, TypeError, ValueError, json.JSONDecodeError) as error:
        summary = {
            "schemaVersion": 1, "issue": 421, "outcome": "INCONCLUSIVE",
            "decision": "RECORD_TARGET_ACTS_LAST_IDENTITY_INCONCLUSIVE_AT_CAP",
            "decisionBoundary": 3, "protocolPath": str(PROTOCOL),
            "validityFaults": [f"protocol load failed: {error}"],
            "identityFaults": [], "executionError": str(error),
            "execution": {"GodotProcesses": 0, "simulatorExecutions": 0,
                          "directControlledExecutions": 0,
                          "ledgerReadOnlyTransactions": 0},
        }
        write_once(SUMMARY, summary)
        print(core.canonical({"outcome": "INCONCLUSIVE", "faults": 1}))
        raise SystemExit(2)
    started = time.monotonic()
    deadline = started + float(protocol["budget"]["maximumWallTimeSeconds"])
    engine: dict[str, Any] = {}
    source: dict[str, Any] = {}
    source_after: dict[str, Any] = {}
    ledger: dict[str, Any] = {}
    ledger_after_sha = ""
    ledger_read_transactions = 0
    content_sha = ""
    content_path: Path | None = None
    validity_faults: list[str] = []
    identity_faults: list[str] = []
    parse_transcript = ""
    process_count = [0]
    cache_writes = [0]
    simulator_executions = 0
    whole_output_rows = 0
    direct_executions = 0
    whole: dict[str, Any] = {}
    direct: dict[str, Any] = {}
    manifests: dict[str, Any] = {}
    execution_error = ""
    timed_out = False
    try:
        engine, engine_faults = engine_identity(protocol)
        validity_faults.extend(engine_faults)
        source = source_identity(protocol)
        validity_faults.extend(static_faults(protocol, source))
        validity_faults.extend(budget_faults(protocol))
        if not validity_faults:
            ledger, seed_faults = ledger_and_seed_faults(protocol)
            ledger_read_transactions = 1
            validity_faults.extend(seed_faults)
        if not validity_faults:
            content_sha, content_path = projected_content(True, cache_writes)
            if content_sha != protocol["immutableInputs"]["projectedContentSha256"]:
                validity_faults.append("projected content identity drift")
    except (KeyError, OSError, RuntimeError, sqlite3.Error,
            subprocess.SubprocessError, TypeError, ValueError) as error:
        execution_error = str(error)
        validity_faults.append(f"validity preflight failed: {error}")
    if not validity_faults and content_path is not None:
        try:
            parse_faults, parse_transcript, parsed = parse_preflight(
                engine["path"], deadline)
            process_count[0] += parsed
            identity_faults.extend(parse_faults)
            if not identity_faults:
                whole_plan = {
                    "schemaVersion": 1, "protocolSha256": protocol_sha,
                    "mode": "whole-run", "rows": protocol["wholeRunRows"],
                }
                baseline_output, plan_sha, output_sha = run_probe(
                    BASELINE, whole_plan, BASELINE / "content/full-content.json",
                    engine["path"], deadline, process_count, cache_writes)
                manifests["wholeBaseline"] = {
                    "planSha256": plan_sha, "outputSha256": output_sha,
                }
                whole_output_rows += len(baseline_output["rows"])
                simulator_executions += len(baseline_output["rows"]) * 2
                candidate_output, plan_sha, output_sha = run_probe(
                    CANDIDATE, whole_plan, CANDIDATE / "content/full-content.json",
                    engine["path"], deadline, process_count, cache_writes)
                manifests["wholeCandidateNull"] = {
                    "planSha256": plan_sha, "outputSha256": output_sha,
                }
                whole_output_rows += len(candidate_output["rows"])
                simulator_executions += len(candidate_output["rows"]) * 2
                try:
                    whole = check_whole(protocol, baseline_output, candidate_output)
                except RuntimeError as error:
                    identity_faults.append(str(error))
                if identity_faults:
                    raise RuntimeError("whole-run identity evidence failed")
                direct_base = {
                    "schemaVersion": 1, "protocolSha256": protocol_sha,
                    "mode": "direct", "rows": protocol["directScenarios"],
                }
                off_plan = {**direct_base, "enabled": False}
                off_output, plan_sha, output_sha = run_probe(
                    CANDIDATE, off_plan, content_path, engine["path"],
                    deadline, process_count, cache_writes)
                manifests["directOff"] = {
                    "planSha256": plan_sha, "outputSha256": output_sha,
                }
                direct_executions += len(off_output["rows"])
                on_plan = {**direct_base, "enabled": True}
                on_output, plan_sha, output_sha = run_probe(
                    CANDIDATE, on_plan, content_path, engine["path"],
                    deadline, process_count, cache_writes)
                manifests["directOn"] = {
                    "planSha256": plan_sha, "outputSha256": output_sha,
                }
                direct_executions += len(on_output["rows"])
                try:
                    direct = check_direct(protocol, off_output, on_output)
                except RuntimeError as error:
                    identity_faults.append(str(error))
        except (subprocess.TimeoutExpired, TimeoutError) as error:
            timed_out = True
            execution_error = str(error)
        except (KeyError, OSError, RuntimeError, TypeError, ValueError) as error:
            execution_error = str(error)
            if not identity_faults:
                validity_faults.append(execution_error)
    elapsed = time.monotonic() - started
    budget = protocol["budget"]
    if process_count[0] > int(budget["maximumGodotProcesses"]):
        validity_faults.append("Godot process cap exceeded")
    if simulator_executions > int(budget["maximumSimulatorObservationRows"]):
        validity_faults.append("simulator row cap exceeded")
    if direct_executions > int(budget["maximumDirectScenarios"]) * 2:
        validity_faults.append("direct controlled-execution cap exceeded")
    if whole_output_rows > int(budget["maximumWholeRunNullRowsPerArm"]) * 2:
        validity_faults.append("whole-run output-row cap exceeded")
    if cache_writes[0] > int(budget["maximumCacheObjectWrites"]):
        validity_faults.append("cache write cap exceeded")
    if ledger_read_transactions > int(budget["maximumLedgerReadOnlyTransactions"]):
        validity_faults.append("ledger read-only transaction cap exceeded")
    if elapsed > float(budget["maximumWallTimeSeconds"]):
        timed_out = True
    try:
        if ledger:
            ledger_after_sha = core.file_sha(core.LEDGER)
            if ledger_after_sha != ledger["sha256"]:
                validity_faults.append("append-only ledger changed")
        if source:
            source_after = source_identity(protocol)
            if source_after != source:
                validity_faults.append("source identity changed during execution")
    except (KeyError, OSError, RuntimeError, subprocess.SubprocessError,
            TypeError, ValueError) as error:
        validity_faults.append(f"validity postflight failed: {error}")
    if timed_out or validity_faults:
        outcome = "INCONCLUSIVE"
        decision = "RECORD_TARGET_ACTS_LAST_IDENTITY_INCONCLUSIVE_AT_CAP"
        boundary = 3
    elif identity_faults:
        outcome = "FUTILITY"
        decision = "CLOSE_TARGET_ACTS_LAST_REPRESENTATION_AT_IDENTITY_GATE"
        boundary = 2
    else:
        outcome = "SUCCESS"
        decision = "AUTHORISE_TARGET_ACTS_LAST_NATURAL_CAPACITY_PREREGISTRATION"
        boundary = 1
    summary = {
        "schemaVersion": 1, "issue": 421, "outcome": outcome,
        "decision": decision, "decisionBoundary": boundary,
        "claimBoundary": protocol["claimBoundary"],
        "authority": protocol["decision"][outcome.lower()],
        "protocolSha256": protocol_sha, "runnerSha256": core.file_sha(Path(__file__)),
        "engineIdentity": engine, "sourceIdentity": source,
        "sourceIdentityAfterExecution": source_after,
        "projectedContentSha256": content_sha,
        "validityFaults": validity_faults, "identityFaults": identity_faults,
        "executionError": execution_error,
        "parseTranscript": parse_transcript, "wholeRunNull": whole,
        "directIdentity": direct, "manifests": manifests,
        "execution": {
            "GodotProcesses": process_count[0],
            "wholeRunOutputRows": whole_output_rows,
            "simulatorExecutionsIncludingEstimatorChecks": simulator_executions,
            "directControlledExecutions": direct_executions,
            "cacheObjectWrites": cache_writes[0],
            "newLedgerRows": 0 if ledger_after_sha == ledger.get("sha256") else None,
            "ledgerReadOnlyTransactions": ledger_read_transactions,
            "protectedSeedRows": ledger.get("protectedSeedRows", 0),
            "maximumModelContextTokensDuringExecutionAndDecision": 0,
            "wallTimeSeconds": elapsed,
        },
        "ledgerBefore": ledger, "ledgerAfterSha256": ledger_after_sha,
        "archiveHeadsPreserved": protocol["immutableEvidence"]["archiveHeads"],
        "quarantinedObservationsUsedForDecision": 0,
    }
    write_once(SUMMARY, summary)
    print(core.canonical({
        "outcome": outcome, "decision": decision,
        "faults": len(validity_faults) + len(identity_faults),
        "GodotProcesses": process_count[0],
        "simulatorExecutions": simulator_executions,
        "directControlledExecutions": direct_executions,
        "wallTimeSeconds": round(elapsed, 3),
    }))
    if outcome != "SUCCESS":
        raise SystemExit(2)


def main() -> None:
    try:
        _main()
    except SystemExit:
        raise
    except Exception as error:
        if SUMMARY.exists():
            raise
        summary = {
            "schemaVersion": 1, "issue": 421, "outcome": "INCONCLUSIVE",
            "decision": "RECORD_TARGET_ACTS_LAST_IDENTITY_INCONCLUSIVE_AT_CAP",
            "decisionBoundary": 3, "protocolPath": str(PROTOCOL),
            "validityFaults": [f"unhandled validity fault: {error}"],
            "identityFaults": [], "executionError": str(error),
            "execution": {"GodotProcesses": 0, "simulatorExecutions": 0,
                          "directControlledExecutions": 0,
                          "ledgerReadOnlyTransactions": 0},
        }
        write_once(SUMMARY, summary)
        print(core.canonical({"outcome": "INCONCLUSIVE", "faults": 1}))
        raise SystemExit(2) from error


if __name__ == "__main__":
    main()
