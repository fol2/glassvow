#!/usr/bin/env python3
"""Measure and replay Glassvow's clean-export real-combat budget evidence."""
from __future__ import annotations
import argparse
import hashlib
import json
import math
import os
import statistics
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any
SHAPES = {
    "desktop-landscape": [1458, 820], "pad-landscape": [1180, 820],
    "pad-portrait": [820, 1180], "phone-portrait": [390, 844],
    "phone-landscape": [844, 390],
}
REPORT_KEYS = {"schema", "provenance", "request", "method", "samples", "summary"}
SAMPLE_KEYS = {"observed_frame_ms", "render_cpu_ms", "frame_setup_cpu_ms",
               "render_cpu_plus_setup_ms", "render_gpu_ms",
               "renderer_allocated_bytes"}
SUMMARY_KEYS = {"sample_count", "observed_frame_median_ms",
                "observed_frame_p95_ms", "render_cpu_plus_setup_p95_ms",
                "render_gpu_available", "render_gpu_p95_ms",
                "renderer_allocated_peak_mib"}
class EvidenceError(RuntimeError):
    pass
def die(message: str) -> None:
    raise EvidenceError(message)
def number(value: Any, where: str, *, positive: bool = False) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        die(f"{where}: expected number")
    out = float(value)
    if not math.isfinite(out) or out < 0 or (positive and out <= 0):
        die(f"{where}: expected finite {'positive' if positive else 'non-negative'} number")
    return out
def percentile(values: list[float], q: float) -> float:
    ordered = sorted(values)
    return ordered[min(len(ordered) - 1, int(len(ordered) * q))]
def close(actual: Any, expected: float, where: str) -> None:
    if not math.isclose(number(actual, where), expected, rel_tol=1e-9, abs_tol=1e-6):
        die(f"{where}: summary does not match raw samples")
def exact_keys(value: Any, keys: set[str], where: str) -> dict[str, Any]:
    if not isinstance(value, dict) or set(value) != keys:
        die(f"{where}: expected exact object keys")
    return value
def integer(value: Any, where: str, *, minimum: int = 0) -> int:
    if type(value) is not int or value < minimum:
        die(f"{where}: expected integer >= {minimum}")
    return value
def hex_string(value: Any, length: int, where: str) -> str:
    if not isinstance(value, str) or len(value) != length \
            or any(char not in "0123456789abcdef" for char in value):
        die(f"{where}: expected lowercase hex")
    return value
def validate_plan(data: Any) -> dict[str, Any]:
    keys = {"schema", "commit", "fight", "kind", "seed", "act", "mode",
            "shapes", "languages", "repeats", "budgets", "app_sha256",
            "pck_sha256"}
    plan = exact_keys(data, keys, "plan")
    if integer(plan["schema"], "plan.schema") != 1:
        die("plan.schema: expected 1")
    hex_string(plan["commit"], 40, "plan.commit")
    hex_string(plan["app_sha256"], 64, "plan.app_sha256")
    hex_string(plan["pck_sha256"], 64, "plan.pck_sha256")
    if not isinstance(plan["fight"], list) or not plan["fight"] \
            or any(not isinstance(enemy, str) or not enemy for enemy in plan["fight"]):
        die("plan.fight: expected non-empty enemy IDs")
    if plan["kind"] not in ("normal", "elite", "boss"):
        die("plan.kind: invalid")
    integer(plan["seed"], "plan.seed")
    if integer(plan["act"], "plan.act") not in range(3):
        die("plan.act: invalid")
    if plan["mode"] != "full":
        die("plan.mode: invalid")
    for field, allowed in (("shapes", set(SHAPES)),
                           ("languages", {"en", "zh-Hant"})):
        values = plan[field]
        if not isinstance(values, list) or not values \
                or any(not isinstance(value, str) for value in values) \
                or len(values) != len(set(values)) \
                or any(value not in allowed for value in values):
            die(f"plan.{field}: invalid or duplicate matrix values")
    repeats = integer(plan["repeats"], "plan.repeats", minimum=1)
    complete = plan["fight"] == ["sporeling"] * 3 \
        and plan["kind"] == "normal" and plan["act"] == 0 \
        and set(plan["shapes"]) == set(SHAPES) \
        and set(plan["languages"]) == {"en", "zh-Hant"} and repeats >= 5
    if not complete:
        die("plan: release evidence requires five shapes, both languages and five repeats")
    if plan["budgets"] is not None:
        budgets = exact_keys(plan["budgets"],
            {"renderer_mib", "footprint_mib", "frame_p95_ms"}, "plan.budgets")
        for key, value in budgets.items():
            number(value, f"plan.budgets.{key}", positive=True)
    return plan
def validate_report(data: Any, expected: dict[str, Any]) -> dict[str, float]:
    report = exact_keys(data, REPORT_KEYS, "report")
    if type(report["schema"]) is not int or report["schema"] != 1:
        die("report.schema: expected integer 1")
    provenance = exact_keys(report["provenance"], {"claimed_commit", "godot", "os",
        "architecture", "renderer", "release", "rendering_method"}, "provenance")
    if provenance["claimed_commit"] != expected["commit"] or provenance["architecture"] != "arm64":
        die("provenance: wrong commit or non-native architecture")
    if not str(provenance["godot"]).startswith("4.7.1") or provenance["os"] != "macOS" \
            or provenance["release"] is not True \
            or provenance["rendering_method"] != "mobile":
        die("provenance: wrong Godot or OS")
    request = exact_keys(report["request"],
        {"fight", "kind", "seed", "act", "shape", "window", "language", "mode"},
        "request")
    if type(request["seed"]) is not int or type(request["act"]) is not int \
            or not all(isinstance(request[key], str) for key in
                       ("kind", "shape", "language", "mode")) \
            or not isinstance(request["fight"], list) \
            or not isinstance(request["window"], list) \
            or len(request["window"]) != 2 \
            or any(type(value) is not int for value in request["window"]):
        die("request: wrong field type")
    wanted = {key: expected[key] for key in request}
    if request != wanted:
        die(f"request: expected {wanted}, got {request}")
    method = exact_keys(report["method"], {
        "warmup_seconds", "warmup_frames_min", "sample_seconds",
        "sample_frames_min", "measured_viewports", "viewport_pixels"}, "method")
    wanted_method = (6.0, 300, 10.0, 600)
    actual_method = (method["warmup_seconds"], method["warmup_frames_min"],
                     method["sample_seconds"], method["sample_frames_min"])
    if actual_method != wanted_method:
        die(f"method: expected {wanted_method}, got {actual_method}")
    min_frames = integer(method["sample_frames_min"], "sample_frames_min", minimum=1)
    if integer(method["measured_viewports"], "measured_viewports", minimum=1) \
            < len(expected["fight"]) + 2:
        die("method: too few measured viewports for root plus every actor")
    if integer(method["viewport_pixels"], "viewport_pixels", minimum=1) \
            < expected["window"][0] * expected["window"][1]:
        die("method: viewport pixels omit the root viewport")
    samples = exact_keys(report["samples"], SAMPLE_KEYS, "samples")
    parsed: dict[str, list[float]] = {}
    lengths: set[int] = set()
    for key in sorted(SAMPLE_KEYS):
        raw = samples[key]
        if not isinstance(raw, list):
            die(f"samples.{key}: expected array")
        parsed[key] = [number(v, f"samples.{key}[{i}]",
            positive=(key in ("observed_frame_ms", "renderer_allocated_bytes")))
            for i, v in enumerate(raw)]
        lengths.add(len(raw))
    if len(lengths) != 1 or next(iter(lengths), 0) < min_frames:
        die("samples: unequal or insufficient array lengths")
    count = next(iter(lengths))
    if sum(parsed["observed_frame_ms"]) + 1e-6 \
            < number(method["sample_seconds"], "sample_seconds", positive=True) * 1000:
        die("samples: observed interval is shorter than the declared window")
    for index, (cpu, setup, total) in enumerate(zip(
            parsed["render_cpu_ms"], parsed["frame_setup_cpu_ms"],
            parsed["render_cpu_plus_setup_ms"])):
        if not math.isclose(cpu + setup, total, rel_tol=1e-9, abs_tol=1e-6):
            die(f"samples.render_cpu_plus_setup_ms[{index}]: derived value differs")
    summary = exact_keys(report["summary"], SUMMARY_KEYS, "summary")
    if type(summary["sample_count"]) is not int or summary["sample_count"] != count:
        die("summary.sample_count: wrong integer count")
    close(summary["observed_frame_median_ms"], percentile(parsed["observed_frame_ms"], .50), "frame median")
    close(summary["observed_frame_p95_ms"], percentile(parsed["observed_frame_ms"], .95), "frame p95")
    close(summary["render_cpu_plus_setup_p95_ms"],
        percentile(parsed["render_cpu_plus_setup_ms"], .95), "CPU p95")
    close(summary["render_gpu_p95_ms"], percentile(parsed["render_gpu_ms"], .95), "GPU p95")
    if type(summary["render_gpu_available"]) is not bool \
            or summary["render_gpu_available"] != (max(parsed["render_gpu_ms"]) > 0):
        die("summary.render_gpu_available: wrong boolean")
    close(summary["renderer_allocated_peak_mib"],
          max(parsed["renderer_allocated_bytes"]) / 1048576,
          "renderer_allocated_peak_mib")
    return {key: float(summary[key]) for key in (
        "observed_frame_p95_ms", "render_cpu_plus_setup_p95_ms",
        "renderer_allocated_peak_mib")}
def validate_footprint(data: Any, pid: int) -> float:
    if not isinstance(data, dict) or data.get("unit") != "byte" \
            or type(data.get("bytes per unit")) is not int \
            or data.get("bytes per unit") != 1 \
            or type(data.get("samples")) is not list \
            or len(data["samples"]) < 8:
        die("footprint: wrong unit or missing sample series")
    peaks: list[float] = []
    starts: list[float] = []
    for i, sample in enumerate(data["samples"]):
        if not isinstance(sample, dict) or sample.get("errors") != []:
            die(f"footprint.samples[{i}]: errors or malformed sample")
        start = sample.get("start_time")
        if not isinstance(start, dict):
            die(f"footprint.samples[{i}]: missing start timestamp")
        starts.append(number(start.get("mach_continuous_time_ns"),
                             f"footprint[{i}].start", positive=True))
        processes = sample.get("processes")
        if not isinstance(processes, list) or len(processes) != 1 \
                or not isinstance(processes[0], dict) \
                or processes[0].get("pid") != pid:
            die(f"footprint.samples[{i}]: wrong process")
        process = processes[0]
        if process.get("translated") is not False:
            die(f"footprint.samples[{i}]: process is translated")
        number(process.get("footprint"), f"footprint[{i}].footprint")
        auxiliary = process.get("auxiliary")
        if not isinstance(auxiliary, dict):
            die(f"footprint.samples[{i}].auxiliary: missing")
        current = number(auxiliary.get("phys_footprint"),
                         f"footprint[{i}].phys_footprint", positive=True)
        peak = number(auxiliary.get("phys_footprint_peak"),
                      f"footprint[{i}].phys_footprint_peak", positive=True)
        if peak < current or (peaks and peak < peaks[-1]):
            die(f"footprint[{i}]: physical peak is below current or regressed")
        peaks.append(peak)
    if max(starts) - min(starts) < 16_000_000_000:
        die("footprint: samples do not cover the full warm-up and sample window")
    return max(peaks) / 1048576
def validate_logs(stdout: str, stderr: str, expected: dict[str, Any],
                  summary: dict[str, Any]) -> int:
    if "ERROR:" in stderr or "SCRIPT ERROR:" in stderr or "BENCH_ERROR " in stdout:
        die("process log contains an error")
    allowed = ("absent — act 0 skyband uses the procedural draw",
               "absent — act 0 region uses the procedural draw")
    for line in stderr.splitlines():
        if line.startswith("WARNING:") and not any(token in line for token in allowed):
            die(f"unexpected warning: {line}")
    ready_lines = [line.removeprefix("BENCH_READY ") for line in stdout.splitlines()
                   if line.startswith("BENCH_READY ")]
    result_lines = [line.removeprefix("BENCH_RESULT ") for line in stdout.splitlines()
                    if line.startswith("BENCH_RESULT ")]
    if len(ready_lines) != 1 or len(result_lines) != 1:
        die("stdout: expected exactly one BENCH_READY and BENCH_RESULT")
    try:
        ready = json.loads(ready_lines[0])
        result = json.loads(result_lines[0])
    except json.JSONDecodeError as exc:
        raise EvidenceError("stdout: malformed BENCH line") from exc
    if not isinstance(ready, dict) or not isinstance(result, dict):
        die("stdout: BENCH lines must be objects")
    if type(ready.get("pid")) is not int or ready.get("shape") != expected["shape"] \
            or ready.get("window") != expected["window"] \
            or ready.get("language") != expected["language"] \
            or ready.get("actors") != len(expected["fight"]) + 1:
        die("stdout: BENCH_READY does not match the request")
    if result != summary:
        die("stdout: BENCH_RESULT does not match report summary")
    return int(ready["pid"])
def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()
def expected(plan: dict[str, Any], shape: str, language: str) -> dict[str, Any]:
    return {
        "commit": plan["commit"], "fight": plan["fight"], "kind": plan["kind"],
        "seed": plan["seed"], "act": plan["act"], "shape": shape,
        "window": SHAPES[shape], "language": language, "mode": plan["mode"],
    }
def profile(home: Path, language: str) -> None:
    directory = home / "Library/Application Support/Godot/app_userdata/Glassvow"
    directory.mkdir(parents=True)
    (directory / "settings.cfg").write_text(
        f'[locale]\nlanguage="{language}"\n[display]\nfullscreen=false\nvsync=false\n',
        encoding="utf-8")
def environment_receipts(app: Path, executable: Path, out: Path) -> None:
    env = out / "environment"
    env.mkdir()
    (env / "app.json").write_text(json.dumps({
        "executable_sha256": sha256(executable),
        "pck_sha256": sha256(app / "Contents/Resources/Glassvow.pck"),
    }, sort_keys=True, indent=2) + "\n", encoding="utf-8")
def aggregate(plan: dict[str, Any], rows: list[dict[str, Any]]) -> dict[str, Any]:
    fields = ["observed_frame_p95_ms", "render_cpu_plus_setup_p95_ms",
              "renderer_allocated_peak_mib", "process_physical_footprint_peak_mib"]
    spread = {}
    for field in fields:
        values = [float(row[field]) for row in rows]
        spread[field] = {"min": min(values), "median": statistics.median(values),
                         "max": max(values), "range": max(values) - min(values)}
    conditions = {}
    for shape in plan["shapes"]:
        for language in plan["languages"]:
            group = [row for row in rows if row["stem"].startswith(
                     f"{shape}--{language}--")]
            conditions[f"{shape}--{language}"] = {
                field: {"min": min(values := [float(row[field]) for row in group]),
                        "median": statistics.median(values), "max": max(values),
                        "range": max(values) - min(values)} for field in fields}
    budgets = plan["budgets"]
    misses: list[str] = []
    if budgets is not None:
        for row in rows:
            for field, budget in [
                ("renderer_allocated_peak_mib", budgets["renderer_mib"]),
                ("process_physical_footprint_peak_mib", budgets["footprint_mib"]),
                ("observed_frame_p95_ms", budgets["frame_p95_ms"])]:
                if row[field] > budget:
                    misses.append(f"{row['stem']} {field} {row[field]:.6f} > {budget:.6f}")
    return {"schema": 1, "plan": plan, "rows": rows, "spread": spread,
            "conditions": conditions,
            "status": "unscored" if budgets is None else ("miss" if misses else "pass"),
            "misses": misses}
def read_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise EvidenceError(f"{path}: unreadable JSON") from exc
def replay(root: Path) -> dict[str, Any]:
    plan = validate_plan(read_json(root / "plan.json"))
    app = exact_keys(read_json(root / "environment/app.json"),
                     {"executable_sha256", "pck_sha256"}, "environment.app")
    if app["executable_sha256"] != plan["app_sha256"]:
        die("environment.app: executable hash differs from plan")
    if app["pck_sha256"] != plan["pck_sha256"]:
        die("environment.app: PCK hash differs from plan")
    rows: list[dict[str, Any]] = []
    expected_files: set[str] = set()
    raw = root / "raw"
    for shape in plan["shapes"]:
        if shape not in SHAPES:
            die("plan: unknown shape")
        for language in plan["languages"]:
            if language not in ("en", "zh-Hant"):
                die("plan: unknown language")
            for repeat in range(plan["repeats"]):
                name = f"{shape}--{language}--r{repeat + 1}"
                names = {suffix: raw / f"{name}.{suffix}" for suffix in
                         ("report.json", "footprint.json", "stdout", "stderr",
                          "footprint.stdout", "footprint.stderr", "status.json")}
                expected_files.update(path.name for path in names.values())
                exp = expected(plan, shape, language)
                report = read_json(names["report.json"])
                metrics = validate_report(report, exp)
                try:
                    stdout = names["stdout"].read_text(encoding="utf-8")
                    stderr = names["stderr"].read_text(encoding="utf-8")
                except OSError as exc:
                    raise EvidenceError(f"{name}: unreadable process log") from exc
                pid = validate_logs(stdout, stderr, exp, report["summary"])
                status = exact_keys(read_json(names["status.json"]), {
                    "process_returncode", "footprint_returncode", "launcher_pid"},
                    f"{name}.status")
                if any(type(status[key]) is not int for key in status) \
                        or status["process_returncode"] != 0 \
                        or status["footprint_returncode"] != 0 \
                        or status["launcher_pid"] != pid:
                    die(f"{name}.status: process did not complete natively and cleanly")
                footprint = validate_footprint(read_json(names["footprint.json"]), pid)
                rows.append({"stem": name, "pid": pid, **metrics,
                             "process_physical_footprint_peak_mib": footprint})
    actual_files = {path.name for path in raw.iterdir() if path.is_file()}
    if actual_files != expected_files:
        die(f"raw matrix differs (missing={sorted(expected_files-actual_files)}, "
            f"extra={sorted(actual_files-expected_files)})")
    return aggregate(plan, rows)
def run_measure(args: argparse.Namespace) -> int:
    root = Path(args.out).resolve()
    if root.exists():
        die("output directory already exists")
    app = Path(args.app).resolve()
    executable = app / "Contents" / "MacOS" / app.stem
    if not executable.is_file() or app.suffix != ".app":
        die("--app must name an extracted macOS .app")
    if subprocess.run(["lipo", "-archs", str(executable)], text=True,
            capture_output=True, check=False).stdout.split() != ["x86_64", "arm64"]:
        die("app is not the expected universal x86_64 arm64 export")
    budget_values = (args.renderer_mib, args.footprint_mib, args.frame_p95_ms)
    if any(v is not None for v in budget_values) and not all(v is not None for v in budget_values):
        die("provide all three budgets or none")
    plan = {
        "schema": 1, "commit": args.commit.lower(), "fight": ["sporeling"] * 3,
        "kind": "normal", "seed": 717, "act": 0, "mode": "full",
        "shapes": list(SHAPES), "languages": ["en", "zh-Hant"], "repeats": 5,
        "budgets": None if args.renderer_mib is None else {
            "renderer_mib": args.renderer_mib, "footprint_mib": args.footprint_mib,
            "frame_p95_ms": args.frame_p95_ms},
        "app_sha256": sha256(executable),
        "pck_sha256": sha256(app / "Contents/Resources/Glassvow.pck"),
    }
    validate_plan(plan)
    root.mkdir(parents=True)
    (root / "raw").mkdir()
    (root / "plan.json").write_text(json.dumps(plan, sort_keys=True, indent=2) + "\n")
    environment_receipts(app, executable, root)
    raw = root / "raw"
    for shape in plan["shapes"]:
        if shape not in SHAPES:
            die(f"unknown shape {shape}")
        for language in plan["languages"]:
            for repeat in range(plan["repeats"]):
                name = f"{shape}--{language}--r{repeat + 1}"
                with tempfile.TemporaryDirectory(prefix=f"glassvow-{name}-") as temp:
                    home = Path(temp) / "home"
                    profile(home, language)
                    report = raw / f"{name}.report.json"
                    width, height = SHAPES[shape]
                    command = ["/usr/bin/arch", "-arm64", str(executable),
                        "--disable-vsync", "--position", "-4000,-4000", "--",
                        "--fight=sporeling,sporeling,sporeling", "--kind=normal",
                        "--seed=717", "--act=0", f"--shape={shape}", f"--vp={width}x{height}",
                        f"--perf-language={language}", f"--perf-commit={plan['commit']}",
                        f"--perf-out={report}", "--perf-mode=full"]
                    env = dict(os.environ, HOME=str(home))
                    process = subprocess.Popen(command, stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE, text=True, env=env)
                    footprint_path = raw / f"{name}.footprint.json"
                    footprint = subprocess.run(["/usr/bin/footprint", "-j",
                        str(footprint_path), "--sample", "0.25",
                        "--sample-duration", "20", "-p", str(process.pid)],
                        text=True, capture_output=True, check=False)
                    try:
                        stdout, stderr = process.communicate(timeout=45)
                    except subprocess.TimeoutExpired as exc:
                        process.kill()
                        process.communicate()
                        raise EvidenceError(f"{name}: app timed out") from exc
                (raw / f"{name}.stdout").write_text(stdout, encoding="utf-8")
                (raw / f"{name}.stderr").write_text(stderr, encoding="utf-8")
                (raw / f"{name}.footprint.stdout").write_text(
                    footprint.stdout, encoding="utf-8")
                (raw / f"{name}.footprint.stderr").write_text(
                    footprint.stderr, encoding="utf-8")
                (raw / f"{name}.status.json").write_text(json.dumps({
                    "process_returncode": process.returncode,
                    "footprint_returncode": footprint.returncode,
                    "launcher_pid": process.pid}, sort_keys=True) + "\n", encoding="utf-8")
                if process.returncode != 0 or footprint.returncode != 0:
                    die(f"{name}: process={process.returncode} footprint={footprint.returncode}")
                print(f"measured {name}")
    summary = replay(root)
    (root / "summary.json").write_text(json.dumps(summary, sort_keys=True, indent=2) + "\n")
    print(json.dumps({"status": summary["status"], "spread": summary["spread"]}, sort_keys=True))
    return 1 if summary["status"] == "miss" else 0
def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    sub = result.add_subparsers(dest="command", required=True)
    measure = sub.add_parser("measure")
    measure.add_argument("--app", required=True)
    measure.add_argument("--commit", required=True)
    measure.add_argument("--out", required=True)
    measure.add_argument("--renderer-mib", type=float)
    measure.add_argument("--footprint-mib", type=float)
    measure.add_argument("--frame-p95-ms", type=float)
    verify = sub.add_parser("verify")
    verify.add_argument("evidence")
    return result
def main() -> int:
    try:
        args = parser().parse_args()
        if args.command == "measure":
            return run_measure(args)
        root = Path(args.evidence).resolve()
        summary = replay(root)
        stored = read_json(root / "summary.json")
        if summary != stored:
            die("summary.json is not the canonical replay result")
        print(json.dumps({"status": summary["status"], "rows": len(summary["rows"])}, sort_keys=True))
        return 1 if summary["status"] == "miss" else 0
    except (EvidenceError, OSError, subprocess.SubprocessError) as exc:
        print(f"performance evidence: {exc}", file=sys.stderr)
        return 2

if __name__ == "__main__":
    raise SystemExit(main())
