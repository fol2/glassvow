#!/usr/bin/env python3
"""Deterministic composer, zero-row preflight and one-shot Phase A for #421 EP4."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import subprocess
import sys
import time
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
EP4 = Path(__file__).resolve().parents[1]
ASPECTS = ("duskblade", "ashwarden")
VOWS = (0, 5)
CELLS = tuple((aspect, vow) for aspect in ASPECTS for vow in VOWS)
EXIT_GO, EXIT_ERROR, EXIT_NO_GO, EXIT_VETO = 0, 1, 2, 3
MISSING = {"$missing": True}


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, value) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def git(*args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(["git", *args], cwd=REPO, check=check, capture_output=True, text=True)


def pointer_get(root, pointer: str):
    value = root
    for part in pointer.strip("/").split("/") if pointer != "/" else []:
        if isinstance(value, list):
            value = value[int(part)]
        else:
            if part not in value:
                return MISSING
            value = value[part]
    return value


def pointer_set(root, pointer: str, expected, value) -> None:
    parts = pointer.strip("/").split("/")
    parent = root
    for part in parts[:-1]:
        parent = parent[int(part)] if isinstance(parent, list) else parent[part]
    leaf = parts[-1]
    actual = parent[int(leaf)] if isinstance(parent, list) else parent.get(leaf, MISSING)
    if actual != expected:
        raise ValueError(f"{pointer}: expected {expected!r}, found {actual!r}")
    if isinstance(parent, list):
        parent[int(leaf)] = value
    else:
        parent[leaf] = value


def diff_paths(left, right, pointer: str = "") -> set[str]:
    if type(left) is not type(right):
        return {pointer or "/"}
    if isinstance(left, dict):
        changed: set[str] = set()
        for key in set(left) | set(right):
            child = f"{pointer}/{key}"
            if key not in left or key not in right:
                changed.add(child)
            else:
                changed |= diff_paths(left[key], right[key], child)
        return changed
    if isinstance(left, list):
        if len(left) != len(right):
            return {pointer or "/"}
        changed: set[str] = set()
        for index, (a, b) in enumerate(zip(left, right)):
            changed |= diff_paths(a, b, f"{pointer}/{index}")
        return changed
    return set() if left == right else {pointer or "/"}


def compose(protocol: dict) -> tuple[dict, dict]:
    spec = protocol["composition"]
    base_path = REPO / spec["basePath"]
    if sha256_file(base_path) != spec["baseFileSha256"]:
        raise ValueError("current-main content hash does not match the freeze")
    base = load_json(base_path)
    packages = spec["packages"]
    touched: set[str] = set()
    for package in packages:
        candidate_path = REPO / package["inputPath"]
        if sha256_file(candidate_path) != package["inputFileSha256"]:
            raise ValueError(f"{package['id']}: input file hash mismatch")
        candidate = load_json(candidate_path)
        expected_paths = {row["pointer"] for row in package["mutations"]}
        actual_paths = diff_paths(base, candidate)
        if actual_paths != expected_paths:
            raise ValueError(
                f"{package['id']}: candidate delta mismatch; "
                f"expected {sorted(expected_paths)}, found {sorted(actual_paths)}"
            )
        overlap = touched & expected_paths
        if overlap:
            raise ValueError(f"package mutation conflict: {sorted(overlap)}")
        touched |= expected_paths

    def apply(order: list[dict]) -> dict:
        result = json.loads(json.dumps(base))
        for package in order:
            candidate = load_json(REPO / package["inputPath"])
            for row in package["mutations"]:
                after = pointer_get(candidate, row["pointer"])
                if after != row["after"]:
                    raise ValueError(f"{package['id']} {row['pointer']}: frozen after-value mismatch")
                pointer_set(result, row["pointer"], row["before"], after)
        return result

    forward = apply(packages)
    reverse = apply(list(reversed(packages)))
    if forward != reverse:
        raise ValueError("composition order is not commutative")
    rendered = (json.dumps(forward, ensure_ascii=False, indent=2) + "\n").encode()
    return forward, {
        "baseFileSha256": sha256_file(base_path),
        "compositeFileSha256": sha256_bytes(rendered),
        "compositionOrder": [package["id"] for package in packages],
        "reverseOrderIdentity": True,
        "touchedPointers": sorted(touched),
    }


def compose_command(protocol_path: Path, output: Path) -> int:
    protocol = load_json(protocol_path)
    content, result = compose(protocol)
    write_json(output, content)
    if sha256_file(output) != result["compositeFileSha256"]:
        raise ValueError("composite write changed the frozen bytes")
    frozen = protocol["composition"].get("compositeFileSha256", "")
    if frozen not in ("", "TBD") and frozen != result["compositeFileSha256"]:
        raise ValueError("composite hash does not match the preregistration")
    print(json.dumps(result, sort_keys=True))
    return 0


def archive_blob_sha(commit: str, path: str) -> str:
    proc = subprocess.run(
        ["git", "show", f"{commit}:{path}"], cwd=REPO, check=True, capture_output=True
    )
    return sha256_bytes(proc.stdout)


def preflight(protocol_path: Path, output: Path) -> int:
    protocol = load_json(protocol_path)
    faults: list[str] = []

    def require(ok: bool, message: str) -> None:
        if not ok:
            faults.append(message)

    source = protocol["source"]
    base = source["originMain"]
    require(git("cat-file", "-e", f"{base}^{{commit}}", check=False).returncode == 0,
            "frozen origin/main commit is unavailable")
    require(git("merge-base", "--is-ancestor", base, "HEAD", check=False).returncode == 0,
            "research HEAD is not descended from frozen origin/main")
    require(sha256_file(REPO / "content/full-content.json") == source["fullContentFileSha256"],
            "current-main full-content.json changed")
    require(git("diff", "--quiet", base, "--", "content/full-content.json", check=False).returncode == 0,
            "product content was mutated in the research branch")
    for path, expected in source["instructionFileSha256"].items():
        require(sha256_file(REPO / path) == expected, f"instruction drift: {path}")

    for archive in protocol["archiveEvidence"]:
        commit = archive["commit"]
        for path, expected in archive["files"].items():
            try:
                actual = archive_blob_sha(commit, path)
            except subprocess.CalledProcessError:
                actual = "unavailable"
            require(actual == expected, f"archive drift: {archive['issue']}:{path}")

    try:
        _content, composition = compose(protocol)
        require(composition["compositeFileSha256"] == protocol["composition"]["compositeFileSha256"],
                "composite hash differs from freeze")
        composite_path = REPO / protocol["composition"]["outputPath"]
        require(composite_path.is_file(), "frozen composite file is missing")
        if composite_path.is_file():
            require(sha256_file(composite_path) == composition["compositeFileSha256"],
                    "frozen composite file bytes differ")
    except (KeyError, OSError, ValueError, json.JSONDecodeError) as exc:
        composition = {}
        faults.append(f"composition: {exc}")

    identity = protocol["identity"]
    for path, expected in identity["fileSha256"].items():
        require(sha256_file(REPO / path) == expected, f"driver or identity drift: {path}")
    godot_path = Path(identity["godotBinary"])
    require(godot_path.is_file() and sha256_file(godot_path) == identity["godotBinarySha256"],
            "Godot binary hash mismatch")
    version = subprocess.run([str(godot_path), "--version"], check=False,
                             capture_output=True, text=True).stdout.strip()
    require(version == identity["godotVersion"], "Godot version mismatch")

    phase = protocol["phaseA"]
    expected_rows = 4 * 2 * 2 * phase["controls"]["seedCount"] + 2 * 2 * phase["holdout"]["seedCount"]
    require(expected_rows == phase["maximumRuns"] == 4000, "Phase A row ceiling is not exactly 4,000")
    require(phase["controls"]["seeds"] == [4000, 4199], "control seed identities drifted")
    require(phase["holdout"]["seeds"] == [5000, 5199], "holdout seed identities drifted")

    checks: list[dict] = []
    for command in (
        ["tools/check_scripts.sh", "tools/balance_sim.gd",
         "research/issue-421-ep4/tools/activation_readout.gd",
         "research/issue-421-ep4/tools/test_activation_readout.gd"],
        [str(godot_path), "--headless", "-s",
         "res://research/issue-421-ep4/tools/test_activation_readout.gd", "--",
         f"--content={(REPO / protocol['composition']['outputPath']).resolve()}"],
    ):
        proc = subprocess.run(command, cwd=REPO, capture_output=True, text=True)
        checks.append({"command": command, "exitCode": proc.returncode,
                       "stdout": proc.stdout.strip(), "stderr": proc.stderr.strip()})
        require(proc.returncode == 0, f"zero-row check failed: {' '.join(command)}")

    result = {
        "schemaVersion": 1,
        "issue": 421,
        "experiment": "EP4",
        "status": "PASS" if not faults else "VETO",
        "generatedAtUtc": utc_now(),
        "protocolSha256": sha256_file(protocol_path),
        "gitHead": git("rev-parse", "HEAD").stdout.strip(),
        "composition": composition,
        "checks": checks,
        "faults": faults,
        "simulationRows": 0,
    }
    write_json(output, result)
    print(json.dumps({"status": result["status"], "simulationRows": 0,
                      "faults": faults}, sort_keys=True))
    return 0 if not faults else EXIT_VETO


def run_job(godot: str, script: str, flags: list[str], log_path: Path,
            timeout_seconds: int) -> dict:
    command = [godot, "--headless", "-s", script, "--", *flags]
    started = time.monotonic()
    try:
        proc = subprocess.run(command, cwd=REPO, capture_output=True, text=True,
                              timeout=timeout_seconds)
        code = proc.returncode
        stdout, stderr = proc.stdout, proc.stderr
        timeout = False
    except subprocess.TimeoutExpired as exc:
        code = 124
        stdout = exc.stdout.decode() if isinstance(exc.stdout, bytes) else (exc.stdout or "")
        stderr = exc.stderr.decode() if isinstance(exc.stderr, bytes) else (exc.stderr or "")
        timeout = True
    log_path.write_text(
        "COMMAND " + json.dumps(command) + "\n" + stdout + "\nSTDERR\n" + stderr,
        encoding="utf-8",
    )
    return {"command": command, "exitCode": code, "timedOut": timeout,
            "wallSeconds": round(time.monotonic() - started, 3), "log": str(log_path)}


def rate(rows: list[dict]) -> float:
    return sum(row.get("outcome") == "win" for row in rows) / len(rows) if rows else 0.0


def cp_lower_95(successes: int, total: int) -> float:
    """Two-sided 95% Clopper-Pearson lower bound, stdlib-only."""
    if successes <= 0 or total <= 0:
        return 0.0
    if successes == total:
        return (0.025) ** (1.0 / total)

    def upper_tail(probability: float) -> float:
        return sum(math.comb(total, i) * probability ** i * (1.0 - probability) ** (total - i)
                   for i in range(successes, total + 1))

    low, high = 0.0, successes / total
    for _ in range(70):
        middle = (low + high) / 2.0
        if upper_tail(middle) < 0.025:
            low = middle
        else:
            high = middle
    return high


def jaccard(left: set[int], right: set[int]) -> float:
    union = left | right
    return len(left & right) / len(union) if union else 1.0


def analyse(protocol: dict, controls_blob: dict, holdout_blobs: dict[int, dict],
            jobs: dict, started_at: str, wall_seconds: float) -> tuple[dict, int]:
    hard: list[str] = []
    scientific: list[str] = []
    controls = controls_blob.get("runs", [])
    holdout_rows = {vow: holdout_blobs[vow].get("runs", []) for vow in VOWS}
    all_rows = controls + holdout_rows[0] + holdout_rows[5]
    phase = protocol["phaseA"]
    expected_sha = protocol["composition"]["compositeFileSha256"]
    expected_head = git("rev-parse", "HEAD").stdout.strip()
    expected_driver = protocol["identity"]["balanceDriverSha256"]
    manifests = [controls_blob.get("manifest", {})] + [holdout_blobs[vow].get("manifest", {}) for vow in VOWS]
    for index, manifest in enumerate(manifests):
        if manifest.get("contentSha256") != expected_sha:
            hard.append(f"job {index} content identity mismatch")
        if manifest.get("commit") != expected_head:
            hard.append(f"job {index} source commit mismatch")
        if manifest.get("godot") != protocol["identity"]["godotVersion"]:
            hard.append(f"job {index} Godot identity mismatch")
        if manifest.get("driverSha256") != expected_driver:
            hard.append(f"job {index} balance driver identity mismatch")
        if manifest.get("stage") != "exam":
            hard.append(f"job {index} seed-contract stage mismatch")
    if len(controls) != 3200 or any(len(holdout_rows[vow]) != 400 for vow in VOWS):
        hard.append("Phase A row identities/counts differ from 3,200 controls + 800 holdout")
    if len(all_rows) > phase["maximumRuns"]:
        hard.append("Phase A exceeded the 4,000-run ceiling")

    grouped: dict[tuple[int, str, int], list[dict]] = defaultdict(list)
    for row in controls:
        grouped[(int(row.get("arm", -1)), str(row.get("aspect", "")),
                 int(row.get("vow", -1)))].append(row)
    control_cells: dict[str, dict] = {}
    for arm in (1, 2, 3, 4):
        for aspect, vow in CELLS:
            rows = grouped[(arm, aspect, vow)]
            key = f"arm{arm}:{aspect}:v{vow}"
            control_cells[key] = {"runs": len(rows), "wins": sum(r.get("outcome") == "win" for r in rows),
                                  "winRate": rate(rows)}
            if len(rows) != 200:
                hard.append(f"{key} has {len(rows)} rows, expected 200")

    for aspect, vow in CELLS:
        planned = control_cells[f"arm1:{aspect}:v{vow}"]["winRate"]
        random_build = control_cells[f"arm2:{aspect}:v{vow}"]["winRate"]
        if random_build >= phase["verdictRules"]["arm2MaximumExclusive"]:
            scientific.append(f"arm2 {aspect} V{vow} is {random_build:.3f}, not <0.500")
        if planned <= random_build:
            scientific.append(f"Planned {aspect} V{vow} is not above RandomBuild ({planned:.3f} <= {random_build:.3f})")

    reachability: dict[str, dict] = {}
    destinations = {
        "duskblade": ("directShatterActivations", "wardMirrorEdgeActivations"),
        "ashwarden": ("handSizePayoffActivations", "ashPoisonCatalystActivations"),
    }
    for aspect, vow in CELLS:
        rows = grouped[(1, aspect, vow)]
        first_name, second_name = destinations[aspect]
        sets = {
            first_name: {int(row["seed"]) for row in rows
                         if int(row.get("packageEvents", {}).get(first_name, 0)) > 0},
            second_name: {int(row["seed"]) for row in rows
                          if int(row.get("packageEvents", {}).get(second_name, 0)) > 0},
        }
        cell: dict = {"runs": len(rows), "destinations": {}}
        for name, seeds in sets.items():
            probability = len(seeds) / len(rows) if rows else 0.0
            lower = cp_lower_95(len(seeds), len(rows))
            passed = probability >= phase["verdictRules"]["reachabilityProbabilityMinimum"] and lower > 0.0
            cell["destinations"][name] = {
                "activatedRuns": len(seeds), "probability": probability,
                "clopperPearsonLower95": lower, "pass": passed,
            }
            if not passed:
                scientific.append(f"{aspect} V{vow} {name} is not reachable at the frozen 5% floor")
        separation = jaccard(sets[first_name], sets[second_name])
        cell["activationSetJaccard"] = separation
        cell["separationPass"] = separation <= phase["verdictRules"]["activationSetJaccardMaximum"]
        if not cell["separationPass"]:
            scientific.append(f"{aspect} V{vow} destination Jaccard {separation:.3f} exceeds 0.500")
        reachability[f"{aspect}:v{vow}"] = cell

    holdout: dict[str, dict] = {}
    for vow in VOWS:
        rates: dict[str, float] = {}
        for aspect in ASPECTS:
            rows = [row for row in holdout_rows[vow] if row.get("aspect") == aspect]
            key = f"{aspect}:v{vow}"
            holdout[key] = {"runs": len(rows), "wins": sum(r.get("outcome") == "win" for r in rows),
                            "winRate": rate(rows)}
            rates[aspect] = holdout[key]["winRate"]
            if len(rows) != 200:
                hard.append(f"holdout {key} has {len(rows)} rows, expected 200")
        lead = rates["ashwarden"] - rates["duskblade"]
        holdout[f"ashLead:v{vow}"] = lead
        if not (0.0 <= lead <= phase["verdictRules"]["ashLeadMaximum"]):
            hard.append(f"Ash lead V{vow} {lead:.3f} is outside [0, 0.20]")
        if vow == 5:
            for aspect, value in rates.items():
                if value > phase["verdictRules"]["vow5CeilingInclusive"]:
                    hard.append(f"{aspect} V5 {value:.3f} exceeds the 0.90 ceiling")

    bad_outcomes = [row for row in all_rows if row.get("outcome") in ("stall", "error")]
    if bad_outcomes:
        hard.append(f"{len(bad_outcomes)} simulator stall/error outcomes")
    ash_shatters = sum(int(fight.get("shatters", 0)) for row in all_rows
                       if row.get("aspect") == "ashwarden" for fight in row.get("fights", []))
    dusk_smolder = sum(int(row.get("packageEvents", {}).get("enemySmolderApplications", 0))
                       for row in all_rows if row.get("aspect") == "duskblade")
    if ash_shatters:
        hard.append(f"H10 failed: {ash_shatters} Ash shatters")
    if dusk_smolder:
        hard.append(f"H11 failed: {dusk_smolder} Dusk enemy Smolder applications")

    verdict = "VETO" if hard else ("NO-GO" if scientific else "GO")
    code = EXIT_VETO if hard else (EXIT_NO_GO if scientific else EXIT_GO)
    result = {
        "schemaVersion": 1,
        "issue": 421,
        "experiment": "EP4",
        "verdict": verdict,
        "startedAtUtc": started_at,
        "finishedAtUtc": utc_now(),
        "wallSeconds": round(wall_seconds, 3),
        "simulationRows": len(all_rows),
        "maximumRuns": phase["maximumRuns"],
        "sourceHead": expected_head,
        "contentSha256": expected_sha,
        "jobs": jobs,
        "gates": {
            "hard": {"pass": not hard, "reasons": hard},
            "scientific": {"pass": not scientific, "reasons": scientific},
            "identity": {"H10AshShatters": ash_shatters,
                         "H11DuskEnemySmolderApplications": dusk_smolder,
                         "pass": ash_shatters == 0 and dusk_smolder == 0},
        },
        "controls": control_cells,
        "holdout": holdout,
        "destinations": reachability,
        "nextAction": ("Exactly one full P9 landscape is authorised on this source/content SHA; "
                       "this result is not a P9 claim." if verdict == "GO" else
                       "STOP: no parameter rescue, second composite, landscape, new family or successor issue."),
    }
    return result, code


def phase_a(protocol_path: Path, preflight_path: Path, out_dir: Path) -> int:
    protocol = load_json(protocol_path)
    preflight_result = load_json(preflight_path)
    if preflight_result.get("status") != "PASS" or preflight_result.get("simulationRows") != 0:
        raise ValueError("a passing zero-row preflight is required")
    if preflight_result.get("protocolSha256") != sha256_file(protocol_path):
        raise ValueError("preflight/protocol identity mismatch")
    marker = out_dir / "phase-a-started-v1.json"
    if marker.exists():
        raise ValueError("Phase A has already started; rerun is forbidden")
    if git("status", "--porcelain", "--untracked-files=no").stdout.strip():
        raise ValueError("tracked worktree changes exist at Phase A boundary")
    out_dir.mkdir(parents=True, exist_ok=True)
    started_at = utc_now()
    write_json(marker, {"schemaVersion": 1, "startedAtUtc": started_at,
                        "protocolSha256": sha256_file(protocol_path),
                        "sourceHead": git("rev-parse", "HEAD").stdout.strip(),
                        "maximumRuns": 4000, "rerunPermitted": False})
    content = str((REPO / protocol["composition"]["outputPath"]).resolve())
    godot = protocol["identity"]["godotBinary"]
    controls_path = out_dir / "controls.json"
    holdout_paths = {vow: out_dir / f"holdout-vow{vow}.json" for vow in VOWS}
    common = [f"--content={content}", "--stage=exam"]
    jobs: dict[str, dict] = {}
    started = time.monotonic()

    def holdout_job(vow: int) -> tuple[str, dict]:
        name = f"holdout-v{vow}"
        result = run_job(godot, "res://tools/balance_sim.gd", [
            f"--vow={vow}", "--runs=200", "--seed0=5000", "--aspect=all", "--mix=none",
            f"--out={holdout_paths[vow]}", *common,
        ], out_dir / f"{name}.log", 900)
        return name, result

    with ThreadPoolExecutor(max_workers=2) as pool:
        for name, result in pool.map(holdout_job, VOWS):
            jobs[name] = result
    elapsed = time.monotonic() - started
    controls_timeout = max(1, min(1800, int(protocol["budgets"]["wallSeconds"] - elapsed)))
    jobs["controls"] = run_job(godot, "res://tools/balance_sweep.gd", [
        "--mode=controls", "--seeds=200", "--seed0=4000", "--arms=1,2,3,4",
        f"--out={controls_path}", *common,
    ], out_dir / "controls.log", controls_timeout)
    wall = time.monotonic() - started

    failed = [name for name, job in jobs.items() if job["exitCode"] != 0]
    result_path = out_dir / "phase-a-result-v1.json"
    if failed or wall > protocol["budgets"]["wallSeconds"]:
        reasons = [f"job failed: {name}" for name in failed]
        if wall > protocol["budgets"]["wallSeconds"]:
            reasons.append("Phase A exceeded the frozen wall-time ceiling")
        result = {
            "schemaVersion": 1, "issue": 421, "experiment": "EP4", "verdict": "VETO",
            "startedAtUtc": started_at, "finishedAtUtc": utc_now(),
            "wallSeconds": round(wall, 3), "simulationRows": "not claimable",
            "jobs": jobs, "gates": {"hard": {"pass": False, "reasons": reasons}},
            "nextAction": "STOP: no rerun or landscape.",
        }
        write_json(result_path, result)
        print(json.dumps({"verdict": "VETO", "reasons": reasons}, sort_keys=True))
        return EXIT_VETO
    try:
        result, code = analyse(protocol, load_json(controls_path),
                               {vow: load_json(holdout_paths[vow]) for vow in VOWS},
                               jobs, started_at, wall)
    except (KeyError, TypeError, ValueError, json.JSONDecodeError) as exc:
        result = {
            "schemaVersion": 1, "issue": 421, "experiment": "EP4", "verdict": "VETO",
            "startedAtUtc": started_at, "finishedAtUtc": utc_now(),
            "wallSeconds": round(wall, 3), "simulationRows": "not claimable",
            "jobs": jobs, "gates": {"hard": {"pass": False, "reasons": [f"analysis fault: {exc}"]}},
            "nextAction": "STOP: no rerun or landscape.",
        }
        code = EXIT_VETO
    write_json(result_path, result)
    print(json.dumps({"verdict": result["verdict"], "simulationRows": result["simulationRows"],
                      "result": str(result_path)}, sort_keys=True))
    return code


def self_test() -> int:
    assert round(cp_lower_95(10, 200), 6) == 0.024234
    assert jaccard({1, 2}, {2, 3}) == 1 / 3
    assert diff_paths({"a": [1]}, {"a": [2]}) == {"/a/0"}
    print("PASS (3 EP4 driver checks)")
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    for name in ("compose", "preflight", "phase-a"):
        command = sub.add_parser(name)
        command.add_argument("--protocol", type=Path, required=True)
        if name == "compose":
            command.add_argument("--out", type=Path, required=True)
        elif name == "preflight":
            command.add_argument("--out", type=Path, required=True)
        else:
            command.add_argument("--preflight", type=Path, required=True)
            command.add_argument("--out-dir", type=Path, required=True)
    sub.add_parser("self-test")
    return parser.parse_args()


def main() -> int:
    opts = parse_args()
    try:
        if opts.command == "compose":
            return compose_command(opts.protocol, opts.out)
        if opts.command == "preflight":
            return preflight(opts.protocol, opts.out)
        if opts.command == "phase-a":
            return phase_a(opts.protocol, opts.preflight, opts.out_dir)
        return self_test()
    except (KeyError, OSError, ValueError, subprocess.CalledProcessError, json.JSONDecodeError) as exc:
        print(f"ep4: {exc}", file=sys.stderr)
        return EXIT_ERROR


if __name__ == "__main__":
    sys.exit(main())
