#!/usr/bin/env python3
"""Run the frozen #421 Emberglass Memory direct source/identity gate."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import subprocess
import sys
import time
from pathlib import Path
from typing import Any


ISSUE_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[3]
RELIC_ID = "researchEmberglassMemory"
CARRIER_KEY = "relic.emberglassMemory"
RESEARCH_EVENT = "research421EmberglassMemory"


def _canonical(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _load(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"{path}: expected object")
    return value


def _git(root: Path, *args: str) -> str:
    return subprocess.run(
        ["git", *args], cwd=root, check=True, capture_output=True, text=True
    ).stdout.rstrip()


def _row_map(output: dict[str, Any]) -> dict[str, dict[str, Any]]:
    rows = output.get("rows")
    if not isinstance(rows, list):
        raise ValueError("probe output rows must be an array")
    mapped = {str(row.get("id", "")): row for row in rows if isinstance(row, dict)}
    if len(mapped) != len(rows):
        raise ValueError("probe output row IDs must be unique non-empty strings")
    return mapped


def _snapshots(row: dict[str, Any]) -> list[dict[str, Any]]:
    if "uninterrupted" in row:
        lanes = [row["uninterrupted"], row["resumed"]]
        return [lane[key] for lane in lanes for key in (
            "afterCharge", "afterConsume", "afterSecondStart"
        )]
    return [row["before"], row["after"]]


def _events(snapshot: dict[str, Any]) -> list[dict[str, Any]]:
    combat = snapshot.get("combat")
    return [] if combat is None else combat["events"]


def _carrier(snapshot: dict[str, Any], default: Any = object()) -> Any:
    return snapshot["run"]["questScratch"].get(CARRIER_KEY, default)


def _research_events(snapshot: dict[str, Any]) -> list[dict[str, Any]]:
    return [event for event in _events(snapshot) if event.get("t") == RESEARCH_EVENT]


def _candidate_proc_count(snapshot: dict[str, Any]) -> int:
    return sum(
        event.get("t") == "relicProc" and event.get("id") == RELIC_ID
        for event in _events(snapshot)
    )


def _strip_availability(row: dict[str, Any]) -> dict[str, Any]:
    cleaned = copy.deepcopy(row)
    cleaned.pop("factorAvailable", None)
    return cleaned


def _normalise_snapshot(snapshot: dict[str, Any]) -> dict[str, Any]:
    cleaned = copy.deepcopy(snapshot)
    cleaned["run"]["questScratch"].pop(CARRIER_KEY, None)
    combat = cleaned.get("combat")
    if combat is None:
        return cleaned
    events = combat["events"]
    remove: set[int] = set()
    realised = 0
    for index, event in enumerate(events):
        if event.get("t") != RESEARCH_EVENT:
            continue
        remove.add(index)
        stage = event.get("stage")
        if stage in {"charge", "consume"}:
            if index < 1 or events[index - 1] != {"t": "relicProc", "id": RELIC_ID}:
                raise ValueError(f"invalid {stage} event adjacency")
            remove.add(index - 1)
        if stage == "consume":
            delta = int(event.get("realised", -1))
            if delta < 0:
                raise ValueError("negative realised Ember delta")
            realised += delta
            if delta > 0:
                expected = {"t": "ember", "n": delta, "total": event.get("total")}
                if index < 2 or events[index - 2] != expected:
                    raise ValueError("invalid consume Ember event adjacency")
                remove.add(index - 2)
    combat["events"] = [event for index, event in enumerate(events) if index not in remove]
    combat["projection"]["embers"] -= realised
    return cleaned


def _normalise_row(row: dict[str, Any]) -> dict[str, Any]:
    cleaned = _strip_availability(row)
    if "uninterrupted" in cleaned:
        for lane_name in ("uninterrupted", "resumed"):
            for key in ("afterCharge", "afterConsume", "afterSecondStart"):
                cleaned[lane_name][key] = _normalise_snapshot(cleaned[lane_name][key])
    else:
        cleaned["before"] = _normalise_snapshot(cleaned["before"])
        cleaned["after"] = _normalise_snapshot(cleaned["after"])
    return cleaned


def _pattern(snapshot: dict[str, Any], stage: str, expected: dict[str, Any]) -> bool:
    events = _events(snapshot)
    matches = [(index, event) for index, event in enumerate(events)
               if event.get("t") == RESEARCH_EVENT]
    if len(matches) != 1:
        return False
    index, event = matches[0]
    if event != {"t": RESEARCH_EVENT, "stage": stage} | expected:
        return False
    if stage in {"charge", "consume"}:
        if index < 1 or events[index - 1] != {"t": "relicProc", "id": RELIC_ID}:
            return False
    if stage == "consume" and int(event["realised"]) > 0:
        delta = int(event["realised"])
        if index < 2 or events[index - 2] != {
            "t": "ember", "n": delta, "total": event["total"]
        }:
            return False
    return True


def _run_probe(
    godot: Path,
    root: Path,
    plan_path: Path,
    output_path: Path,
    stdout_path: Path,
    stderr_path: Path,
    timeout_seconds: int,
) -> tuple[int, float]:
    started = time.monotonic()
    completed = subprocess.run(
        [
            str(godot), "--headless", "--path", str(root),
            "-s", "res://tools/research_421_emberglass_direct_probe.gd", "--",
            f"--plan={plan_path}", f"--out={output_path}",
        ],
        cwd=root,
        capture_output=True,
        text=True,
        timeout=timeout_seconds,
        check=False,
    )
    stdout_path.write_text(completed.stdout, encoding="utf-8")
    stderr_path.write_text(completed.stderr, encoding="utf-8")
    return completed.returncode, time.monotonic() - started


def _preflight(
    protocol: dict[str, Any],
    baseline_root: Path,
    candidate_root: Path,
    godot: Path,
) -> list[str]:
    faults: list[str] = []

    def expect(name: str, actual: Any, expected: Any) -> None:
        if actual != expected:
            faults.append(f"{name}: expected {expected!r}, got {actual!r}")

    source = protocol["sourceIdentity"]
    expect("protocol-state", protocol.get("state"), "FROZEN_BEFORE_EXECUTION")
    expect("runner", _sha256(Path(__file__)), protocol["runner"]["sha256"])
    expect("godot", _sha256(godot.resolve()), source["godotBinarySha256"])
    expect("baseline-head", _git(baseline_root, "rev-parse", "HEAD"), source["head"])
    expect("candidate-head", _git(candidate_root, "rev-parse", "HEAD"), source["head"])
    expect(
        "baseline-status",
        _git(baseline_root, "status", "--porcelain=v1", "--untracked-files=all").splitlines(),
        source["baselineStatus"],
    )
    expect(
        "candidate-status",
        _git(candidate_root, "status", "--porcelain=v1", "--untracked-files=all").splitlines(),
        source["candidateStatus"],
    )
    for relative, expected in source["baselineFiles"].items():
        expect(f"baseline:{relative}", _sha256(baseline_root / relative), expected)
    for relative, expected in source["candidateFiles"].items():
        expect(f"candidate:{relative}", _sha256(candidate_root / relative), expected)
    for relative, expected in protocol["immutableInputs"].items():
        expect(f"immutable:{relative}", _sha256(ISSUE_ROOT / relative), expected)
    for relative, expected in protocol["reproductionArtefacts"].items():
        expect(f"artefact:{relative}", _sha256(REPO_ROOT / relative), expected)
    return faults


def _analyse(
    protocol: dict[str, Any],
    baseline: dict[str, Any],
    candidate: dict[str, Any],
) -> list[dict[str, Any]]:
    base = _row_map(baseline)
    test = _row_map(candidate)
    expected_ids = [row["id"] for row in protocol["design"]["rows"]]
    gates: list[dict[str, Any]] = []

    def gate(name: str, passed: bool) -> None:
        gates.append({"name": name, "passed": bool(passed)})

    gate("complete-fixed-row-set", list(base) == expected_ids and list(test) == expected_ids)
    gate("factor-availability", all(
        base[row_id].get("factorAvailable") is False
        and test[row_id].get("factorAvailable") is True
        for row_id in expected_ids
    ))
    gate("plan-and-probe-identity", baseline.get("planSha256") == candidate.get("planSha256")
         and baseline.get("probeSha256") == candidate.get("probeSha256")
         == protocol["sourceIdentity"]["probeSha256"])
    gate("save-envelope-and-neighbour-preservation", all(
        snapshot["run"].get("v") == 2
        and snapshot["run"]["questScratch"].get("neighbour") == {"kept": 7}
        for row_id in expected_ids for snapshot in _snapshots(base[row_id]) + _snapshots(test[row_id])
    ))
    gate("baseline-has-no-candidate-events", all(
        not _research_events(snapshot) and _candidate_proc_count(snapshot) == 0
        for row_id in expected_ids for snapshot in _snapshots(base[row_id])
    ))

    exact_ids = protocol["design"]["exactNullRows"]
    gate("omitted-off-boundary-exact", all(
        _canonical(_strip_availability(base[row_id]))
        == _canonical(_strip_availability(test[row_id]))
        for row_id in exact_ids
    ))

    invalid_expected = {
        "invalid-negative-start": -1,
        "invalid-high-start": 2,
        "invalid-string-start": "1",
        "invalid-null-start": None,
    }
    invalid_ok = True
    for row_id, original in invalid_expected.items():
        invalid_ok &= _carrier(base[row_id]["after"]) == original
        invalid_ok &= _carrier(test[row_id]["after"]) == 0
        invalid_ok &= not _research_events(test[row_id]["after"])
        invalid_ok &= _candidate_proc_count(test[row_id]["after"]) == 0
        invalid_ok &= _canonical(_normalise_row(base[row_id])) == _canonical(
            _normalise_row(test[row_id]))
    gate("invalid-carrier-canonicalisation-only", invalid_ok)

    positive = test["producer-positive-win"]["after"]
    positive_events = _events(positive)
    positive_research_index = next((i for i, event in enumerate(positive_events)
                                    if event.get("t") == RESEARCH_EVENT), -1)
    hearth_index = next((i for i, event in enumerate(positive_events)
                         if event == {"t": "relicProc", "id": "crownOfTheHearth"}), -1)
    gate("charge-positive-after-canonical-consumers", _carrier(positive) == 1
         and _pattern(positive, "charge", {"terminal": 3, "stored": 1})
         and hearth_index >= 0 and hearth_index < positive_research_index
         and positive_research_index + 1 < len(positive_events)
         and positive_events[positive_research_index + 1].get("t") == "victory")

    zero = test["producer-zero-win"]["after"]
    gate("charge-zero-clears-without-proc", _carrier(zero) == 0
         and not _research_events(zero) and _candidate_proc_count(zero) == 0)

    loss = test["producer-loss"]["after"]
    loss_events = _events(loss)
    loss_index = next((i for i, event in enumerate(loss_events)
                       if event.get("t") == RESEARCH_EVENT), -1)
    gate("loss-clears-without-payoff", _carrier(loss) == 0
         and _pattern(loss, "loss-clear", {"stored": 0})
         and _candidate_proc_count(loss) == 0
         and loss_index + 1 < len(loss_events)
         and loss_events[loss_index + 1].get("t") == "defeat")

    ordinary_base = base["consumer-ordinary-start"]["after"]
    ordinary = test["consumer-ordinary-start"]["after"]
    gate("consume-ordinary-exact-unit", _carrier(ordinary) == 0
         and ordinary_base["combat"]["projection"]["embers"] == 0
         and ordinary["combat"]["projection"]["embers"] == 1
         and ordinary["combat"]["emberCap"] == 9
         and _pattern(ordinary, "consume", {
             "stored": 1, "realised": 1, "total": 1, "cap": 9,
         }))

    crown_base = base["consumer-crown-order-start"]["after"]
    crown = test["consumer-crown-order-start"]["after"]
    gate("consume-after-cap-and-start-ember-effects", _carrier(crown) == 0
         and crown_base["combat"]["projection"]["embers"] == 4
         and crown["combat"]["projection"]["embers"] == 5
         and crown["combat"]["emberCap"] == 12
         and _pattern(crown, "consume", {
             "stored": 1, "realised": 1, "total": 5, "cap": 12,
         }))

    saturated_base = base["consumer-saturated-manual-start"]["after"]
    saturated = test["consumer-saturated-manual-start"]["after"]
    gate("consume-saturated-cap-clears-once", _carrier(saturated) == 0
         and saturated_base["combat"]["projection"]["embers"] == 9
         and saturated["combat"]["projection"]["embers"] == 9
         and _pattern(saturated, "consume", {
             "stored": 1, "realised": 0, "total": 9, "cap": 9,
         }))

    composition_base = base["save-resume-composition"]
    composition = test["save-resume-composition"]
    composition_ok = (
        _canonical(composition_base["uninterrupted"])
        == _canonical(composition_base["resumed"])
        and _canonical(composition["uninterrupted"]) == _canonical(composition["resumed"])
    )
    for lane in ("uninterrupted", "resumed"):
        charged = composition[lane]["afterCharge"]
        consumed = composition[lane]["afterConsume"]
        second = composition[lane]["afterSecondStart"]
        composition_ok &= _carrier(charged) == 1
        composition_ok &= _pattern(charged, "charge", {"terminal": 3, "stored": 1})
        composition_ok &= _carrier(consumed) == 0
        composition_ok &= _pattern(consumed, "consume", {
            "stored": 1, "realised": 1, "total": 1, "cap": 9,
        })
        composition_ok &= _carrier(second) == 0
        composition_ok &= not _research_events(second)
        composition_ok &= _candidate_proc_count(second) == 0
    gate("save-resume-and-once-only-composition", composition_ok)

    non_exact_ids = [row_id for row_id in expected_ids if row_id not in exact_ids]
    gate("whitelist-exhausts-all-enabled-differences", all(
        _canonical(_normalise_row(base[row_id])) == _canonical(_normalise_row(test[row_id]))
        for row_id in non_exact_ids
    ))
    gate("rng-identity-all-contrasts", all(
        [snapshot["rng"] for snapshot in _snapshots(base[row_id])]
        == [snapshot["rng"] for snapshot in _snapshots(test[row_id])]
        for row_id in expected_ids
    ))
    return gates


def _self_test() -> None:
    base_snapshot = {
        "run": {"v": 2, "questScratch": {CARRIER_KEY: 1, "neighbour": {"kept": 7}}},
        "combat": {"projection": {"embers": 0}, "emberCap": 9, "events": []},
        "rng": 4,
    }
    consume = copy.deepcopy(base_snapshot)
    consume["run"]["questScratch"][CARRIER_KEY] = 0
    consume["combat"]["projection"]["embers"] = 1
    consume["combat"]["events"] = [
        {"t": "ember", "n": 1, "total": 1},
        {"t": "relicProc", "id": RELIC_ID},
        {"t": RESEARCH_EVENT, "stage": "consume", "stored": 1,
         "realised": 1, "total": 1, "cap": 9},
    ]
    assert _canonical(_normalise_snapshot(base_snapshot)) == _canonical(
        _normalise_snapshot(consume))
    assert _pattern(consume, "consume", {
        "stored": 1, "realised": 1, "total": 1, "cap": 9,
    })
    charge = copy.deepcopy(base_snapshot)
    charge["combat"]["events"] = [
        {"t": "relicProc", "id": RELIC_ID},
        {"t": RESEARCH_EVENT, "stage": "charge", "terminal": 3, "stored": 1},
    ]
    assert _normalise_snapshot(charge)["combat"]["events"] == []
    assert _strip_availability({"id": "x", "factorAvailable": True}) == {"id": "x"}
    print("PASS (4 checks)")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--protocol", type=Path)
    parser.add_argument("--baseline-root", type=Path)
    parser.add_argument("--candidate-root", type=Path)
    parser.add_argument("--godot", type=Path)
    parser.add_argument("--evidence-dir", type=Path)
    parser.add_argument("--out", type=Path)
    args = parser.parse_args()
    if args.self_test:
        _self_test()
        return 0
    required = (args.protocol, args.baseline_root, args.candidate_root,
                args.godot, args.evidence_dir, args.out)
    if any(value is None for value in required):
        parser.error("all execution arguments are required")

    protocol = _load(args.protocol)
    protocol_sha = _sha256(args.protocol)
    base_summary = {
        "schemaVersion": 1,
        "issue": 421,
        "protocolSha256": protocol_sha,
        "sourceHead": protocol["sourceIdentity"]["head"],
        "GodotProcesses": 0,
        "controlledScenarioExecutions": 0,
        "simulatorRows": 0,
        "ledgerReads": 0,
        "ledgerWrites": 0,
        "protectedSeedRows": 0,
        "productMutations": 0,
    }
    try:
        faults = _preflight(
            protocol, args.baseline_root, args.candidate_root, args.godot
        )
    except Exception as exc:  # A frozen input was unavailable.
        faults = [f"preflight-exception:{type(exc).__name__}:{exc}"]
    if faults:
        result = base_summary | {
            "outcome": "INCONCLUSIVE",
            "decision": "record-source-identity-inconclusive-at-cap",
            "faults": faults,
            "gates": [],
        }
        args.out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        return 2

    planned = [args.evidence_dir / name for name in (
        "plan.json", "baseline.json", "candidate.json", "baseline.stdout.txt",
        "baseline.stderr.txt", "candidate.stdout.txt", "candidate.stderr.txt",
    )]
    if args.out.exists() or any(path.exists() for path in planned):
        raise FileExistsError("single-look output already exists")
    args.evidence_dir.mkdir(parents=True, exist_ok=True)
    plan = {
        "schemaVersion": 1,
        "protocolSha256": protocol_sha,
        "rows": protocol["design"]["rows"],
    }
    plan_path, baseline_path, candidate_path = planned[:3]
    plan_path.write_text(_canonical(plan) + "\n", encoding="utf-8")
    timeout = int(protocol["executionCeilings"]["maximumSecondsPerGodotProcess"])
    try:
        base_rc, base_seconds = _run_probe(
            args.godot, args.baseline_root, plan_path, baseline_path,
            planned[3], planned[4], timeout,
        )
        test_rc, test_seconds = _run_probe(
            args.godot, args.candidate_root, plan_path, candidate_path,
            planned[5], planned[6], timeout,
        )
    except subprocess.TimeoutExpired as exc:
        result = base_summary | {
            "outcome": "INCONCLUSIVE",
            "decision": "record-source-identity-inconclusive-at-cap",
            "faults": [f"timeout:{exc.cmd}"],
            "gates": [],
            "GodotProcesses": 2,
        }
        args.out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        return 2

    base_summary["GodotProcesses"] = 2
    base_summary["controlledScenarioExecutions"] = len(plan["rows"]) * 2
    process_faults = []
    if base_rc != 0 or not baseline_path.exists():
        process_faults.append(f"baseline-process:{base_rc}")
    if test_rc != 0 or not candidate_path.exists():
        process_faults.append(f"candidate-process:{test_rc}")
    if process_faults:
        result = base_summary | {
            "outcome": "INCONCLUSIVE",
            "decision": "record-source-identity-inconclusive-at-cap",
            "faults": process_faults,
            "gates": [],
            "wallTimeSeconds": round(base_seconds + test_seconds, 6),
        }
        args.out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        return 2

    try:
        baseline = _load(baseline_path)
        candidate = _load(candidate_path)
        gates = _analyse(protocol, baseline, candidate)
        analysis_faults: list[str] = []
    except Exception as exc:
        gates = []
        analysis_faults = [f"analysis-exception:{type(exc).__name__}:{exc}"]
    elapsed = base_seconds + test_seconds
    if elapsed > int(protocol["executionCeilings"]["maximumTotalWallTimeSeconds"]):
        analysis_faults.append(f"wall-time-cap:{elapsed:.6f}")
    if analysis_faults:
        outcome = "INCONCLUSIVE"
        decision = "record-source-identity-inconclusive-at-cap"
    elif all(gate["passed"] for gate in gates):
        outcome = "SUCCESS"
        decision = "freeze-emberglass-source-identity-for-separate-shadow-capacity-preregistration"
    else:
        outcome = "FUTILITY"
        decision = "close-exact-emberglass-one-carry-contract-without-repair"
    result = base_summary | {
        "outcome": outcome,
        "decision": decision,
        "faults": analysis_faults,
        "gates": gates,
        "wallTimeSeconds": round(elapsed, 6),
        "evidence": {
            path.name: _sha256(path) for path in planned
        },
        "claimBoundary": protocol["claimBoundary"],
    }
    args.out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return 0 if outcome == "SUCCESS" else 1 if outcome == "FUTILITY" else 2


if __name__ == "__main__":
    sys.exit(main())
