#!/usr/bin/env python3
"""Measure the bounded Linux ptrace capability before protocol freeze."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import platform
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any, Sequence


SCHEMA = "glassvow.execution-provenance.b0-preflight/v1"
TRACE_SCHEMA = "TRACEv1"
SOURCE_ROOT = Path(__file__).resolve().parent
TRACER_SOURCE = SOURCE_ROOT / "ptrace_tracer.c"
WORKLOAD_SOURCE = SOURCE_ROOT / "inert_workload.c"
EXPECTED_INPUT = bytes(range(32))
MAX_TRACE_BYTES = 256 * 1024
MAX_STDIO_BYTES = 16 * 1024


class PreflightError(RuntimeError):
    """A measured capability condition was absent or ambiguous."""


def _integer(value: str, label: str, *, minimum: int = 0) -> int:
    try:
        result = int(value, 10)
    except ValueError as error:
        raise PreflightError(f"{label} is not an integer") from error
    if result < minimum:
        raise PreflightError(f"{label} is below {minimum}")
    return result


def _hex_bytes(value: str, label: str) -> bytes:
    if len(value) % 2 != 0:
        raise PreflightError(f"{label} has an odd-length hex encoding")
    try:
        return bytes.fromhex(value)
    except ValueError as error:
        raise PreflightError(f"{label} is not hexadecimal") from error


def _hex_text(value: str, label: str) -> str:
    try:
        return _hex_bytes(value, label).decode("utf-8")
    except UnicodeDecodeError as error:
        raise PreflightError(f"{label} is not UTF-8") from error


def parse_trace_lines(lines: Sequence[str]) -> dict[str, Any]:
    clean = [line.rstrip("\n") for line in lines]
    if len(clean) < 4 or clean[0] != TRACE_SCHEMA:
        raise PreflightError("trace header is missing or unsupported")
    if any(not line for line in clean):
        raise PreflightError("trace contains an empty record")
    start_fields = clean[1].split("\t")
    input_fields = clean[2].split("\t")
    end_fields = clean[-1].split("\t")
    if len(start_fields) != 2 or start_fields[0] != "START":
        raise PreflightError("START record is malformed")
    if len(input_fields) != 5 or input_fields[0] != "INPUT":
        raise PreflightError("INPUT record is malformed")
    if len(end_fields) != 8 or end_fields[0] != "END":
        raise PreflightError("END record is malformed")

    started_ns = _integer(start_fields[1], "START timestamp")
    supplied = {
        "device": _integer(input_fields[1], "input device"),
        "inode": _integer(input_fields[2], "input inode"),
        "size": _integer(input_fields[3], "input size"),
        "path": _hex_text(input_fields[4], "input path"),
    }
    events: list[dict[str, Any]] = []
    for expected_sequence, line in enumerate(clean[3:-1], start=1):
        fields = line.split("\t")
        tag = fields[0]
        if tag == "EXEC" and len(fields) == 6:
            event = {
                "type": "exec", "sequence": _integer(fields[1], "sequence", minimum=1),
                "pid": _integer(fields[2], "exec pid", minimum=1),
                "device": _integer(fields[3], "executable device"),
                "inode": _integer(fields[4], "executable inode"),
                "path": _hex_text(fields[5], "executable path"),
            }
        elif tag == "FORK" and len(fields) == 5:
            if fields[4] not in {"fork", "vfork", "clone"}:
                raise PreflightError("fork kind is unsupported")
            event = {
                "type": "fork", "sequence": _integer(fields[1], "sequence", minimum=1),
                "pid": _integer(fields[2], "parent pid", minimum=1),
                "child": _integer(fields[3], "child pid", minimum=1),
                "kind": fields[4],
            }
        elif tag == "READ" and len(fields) == 12:
            if fields[3] not in {"read", "pread64"}:
                raise PreflightError("read operation is unsupported")
            event = {
                "type": "read", "sequence": _integer(fields[1], "sequence", minimum=1),
                "pid": _integer(fields[2], "read pid", minimum=1),
                "operation": fields[3],
                "fd": _integer(fields[4], "read fd"),
                "offset": _integer(fields[5], "read offset"),
                "requested": _integer(fields[6], "requested bytes"),
                "returned": _integer(fields[7], "returned bytes"),
                "device": _integer(fields[8], "actual input device"),
                "inode": _integer(fields[9], "actual input inode"),
                "path": _hex_text(fields[10], "actual input path"),
                "bytes": _hex_bytes(fields[11], "actual read bytes"),
            }
        elif tag == "EXIT" and len(fields) == 4:
            event = {
                "type": "exit", "sequence": _integer(fields[1], "sequence", minimum=1),
                "pid": _integer(fields[2], "exit pid", minimum=1),
                "code": _integer(fields[3], "exit code"),
            }
        elif tag == "VIOLATION" and len(fields) == 4:
            if not fields[3] or fields[3] == "-":
                raise PreflightError("violation reason is missing")
            event = {
                "type": "violation",
                "sequence": _integer(fields[1], "sequence", minimum=1),
                "pid": _integer(fields[2], "violation pid", minimum=1),
                "reason": fields[3],
            }
        else:
            raise PreflightError(f"unknown or malformed trace record: {tag}")
        if event["sequence"] != expected_sequence:
            raise PreflightError("trace sequence is not contiguous")
        events.append(event)

    event_count = _integer(end_fields[1], "event count")
    footer_start = _integer(end_fields[2], "footer start")
    finished_ns = _integer(end_fields[3], "finish timestamp")
    duration_ns = _integer(end_fields[4], "duration")
    dropped_events = _integer(end_fields[5], "dropped events")
    root_exit = _integer(end_fields[6], "root exit code")
    violation = None if end_fields[7] == "-" else end_fields[7]
    if event_count != len(events):
        raise PreflightError("event count does not match the trace")
    if footer_start != started_ns or finished_ns < started_ns:
        raise PreflightError("external timing endpoints do not bind")
    if duration_ns != finished_ns - started_ns:
        raise PreflightError("external timing duration is inconsistent")
    return {
        "schema": TRACE_SCHEMA,
        "started_ns": started_ns,
        "finished_ns": finished_ns,
        "duration_ns": duration_ns,
        "dropped_events": dropped_events,
        "root_exit": root_exit,
        "violation": violation,
        "supplied_input": supplied,
        "events": events,
    }


def parse_trace(path: Path) -> dict[str, Any]:
    if not path.is_file():
        raise PreflightError(f"trace is missing: {path}")
    if path.stat().st_size > MAX_TRACE_BYTES:
        raise PreflightError("trace byte cap exceeded")
    return parse_trace_lines(path.read_text(encoding="utf-8").splitlines())


def validate_valid_trace(
        trace: dict[str, Any], *, expected_bytes: bytes,
        expected_device: int, expected_inode: int) -> dict[str, Any]:
    if trace["dropped_events"] != 0:
        raise PreflightError("valid trace reports dropped events")
    if trace["violation"] is not None or trace["root_exit"] != 0:
        raise PreflightError("valid trace did not terminate cleanly")
    supplied = trace["supplied_input"]
    if supplied["device"] != expected_device or supplied["inode"] != expected_inode:
        raise PreflightError("supplied input object identity drifted")
    if supplied["size"] != len(expected_bytes):
        raise PreflightError("supplied input size drifted")

    executions = [event for event in trace["events"] if event["type"] == "exec"]
    if len(executions) != 1:
        raise PreflightError("valid trace requires one root executable")
    root = executions[0]["pid"]
    lineage = {root}
    for event in trace["events"]:
        if event["type"] == "fork":
            if event["pid"] not in lineage or event["child"] in lineage:
                raise PreflightError("process lineage is not a tree")
            lineage.add(event["child"])
    if len(lineage) < 2:
        raise PreflightError("descendant tracing was not exercised")

    exits = [event for event in trace["events"] if event["type"] == "exit"]
    if {event["pid"] for event in exits} != lineage or len(exits) != len(lineage):
        raise PreflightError("process lineage does not have complete terminal exits")
    if any(event["code"] != 0 for event in exits):
        raise PreflightError("a valid-case process exited non-zero")

    reads = [event for event in trace["events"] if event["type"] == "read"]
    if {event["operation"] for event in reads} != {"read", "pread64"}:
        raise PreflightError("valid trace must exercise read and pread64")
    reads.sort(key=lambda event: event["offset"])
    cursor = 0
    consumed = bytearray()
    for event in reads:
        if event["pid"] not in lineage or event["fd"] != 3:
            raise PreflightError("read is outside the traced input lineage")
        if event["device"] != expected_device or event["inode"] != expected_inode:
            raise PreflightError("actual input object identity drifted")
        if event["path"] != supplied["path"]:
            raise PreflightError("actual input path drifted")
        if event["offset"] != cursor or event["returned"] != len(event["bytes"]):
            raise PreflightError("actual read coverage is incomplete")
        consumed.extend(event["bytes"])
        cursor += event["returned"]
    if bytes(consumed) != expected_bytes:
        raise PreflightError("actual read bytes do not match the bound input")
    return {
        "lineage": sorted(lineage),
        "consumed_bytes": len(consumed),
        "dropped_events": trace["dropped_events"],
        "external_duration_ns": trace["duration_ns"],
        "executable_path": executions[0]["path"],
    }


def validate_rejection_trace(trace: dict[str, Any], expected_reason: str) -> None:
    if trace["dropped_events"] != 0:
        raise PreflightError("negative probe has ambiguous event loss")
    reasons = [event["reason"] for event in trace["events"]
               if event["type"] == "violation"]
    if reasons != [expected_reason] or trace["violation"] != expected_reason:
        raise PreflightError("negative probe rejected for the wrong reason")
    if trace["root_exit"] == 0:
        raise PreflightError("negative probe root unexpectedly exited zero")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(128 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _command(command: Sequence[str], *, timeout: int = 30) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        list(command), check=False, capture_output=True, text=True,
        timeout=timeout)
    if len(result.stdout.encode("utf-8")) > MAX_STDIO_BYTES \
            or len(result.stderr.encode("utf-8")) > MAX_STDIO_BYTES:
        raise PreflightError(f"command stdio cap exceeded: {command[0]}")
    return result


def _checked(command: Sequence[str], *, timeout: int = 30) -> subprocess.CompletedProcess[str]:
    result = _command(command, timeout=timeout)
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip()
        raise PreflightError(
            f"command failed ({result.returncode}): {' '.join(command)}: {detail}")
    return result


def _environment() -> dict[str, Any]:
    os_release = Path("/etc/os-release")
    yama = Path("/proc/sys/kernel/yama/ptrace_scope")
    return {
        "platform": platform.system(),
        "architecture": platform.machine(),
        "kernel_release": platform.release(),
        "kernel_version": platform.version(),
        "os_release": os_release.read_text(encoding="utf-8") if os_release.is_file() else None,
        "uid": os.getuid() if hasattr(os, "getuid") else None,
        "gid": os.getgid() if hasattr(os, "getgid") else None,
        "ptrace_scope": yama.read_text(encoding="utf-8").strip() if yama.is_file() else None,
        "github_actions": os.environ.get("GITHUB_ACTIONS"),
        "github_run_id": os.environ.get("GITHUB_RUN_ID"),
        "github_run_attempt": os.environ.get("GITHUB_RUN_ATTEMPT"),
        "github_sha": os.environ.get("GITHUB_SHA"),
        "runner_name": os.environ.get("RUNNER_NAME"),
        "runner_os": os.environ.get("RUNNER_OS"),
        "runner_arch": os.environ.get("RUNNER_ARCH"),
        "image_os": os.environ.get("ImageOS"),
        "image_version": os.environ.get("ImageVersion"),
    }


def _compile(build: Path) -> dict[str, Any]:
    compiler = shutil.which("cc")
    if compiler is None:
        raise PreflightError("C compiler is unavailable")
    tracer = build / "ptrace-tracer"
    workload = build / "inert-workload"
    common = ["-std=c17", "-O2", "-Wall", "-Wextra", "-Werror"]
    tracer_command = [
        compiler, *common, "-static", "-Wl,--build-id=none",
        str(TRACER_SOURCE), "-o", str(tracer),
    ]
    workload_command = [
        compiler, *common, "-nostdlib", "-static", "-no-pie",
        "-ffreestanding", "-fno-pie", "-fno-stack-protector",
        "-fno-asynchronous-unwind-tables", "-Wl,--build-id=none",
        "-Wl,-z,noexecstack", str(WORKLOAD_SOURCE), "-o", str(workload),
    ]
    _checked(tracer_command)
    _checked(workload_command)
    return {
        "compiler": compiler,
        "compiler_version": _checked([compiler, "--version"]).stdout.splitlines()[0],
        "tracer": tracer,
        "workload": workload,
        "commands": [tracer_command, workload_command],
    }


def _probe(
        tracer: Path, workload: Path, input_path: Path, output_dir: Path,
        mode: str) -> dict[str, Any]:
    trace_path = output_dir / f"{mode}.trace"
    result_path = output_dir / f"{mode}.output"
    command = [
        str(tracer), "--input", str(input_path), "--output", str(result_path),
        "--trace", str(trace_path), "--exec", str(workload), mode,
    ]
    result = _command(command, timeout=15)
    trace = parse_trace(trace_path)
    return {
        "mode": mode,
        "command": command,
        "returncode": result.returncode,
        "stdout": result.stdout,
        "stderr": result.stderr,
        "trace_path": trace_path,
        "output_path": result_path,
        "trace": trace,
    }


def _copy_evidence(source: Path, destination: Path) -> dict[str, Any]:
    shutil.copy2(source, destination)
    return {
        "path": destination.name,
        "bytes": destination.stat().st_size,
        "sha256": sha256_file(destination),
    }


def run_preflight(output: Path) -> dict[str, Any]:
    environment = _environment()
    if environment["platform"] != "Linux" or environment["architecture"] != "x86_64":
        raise PreflightError("B0 requires a Linux x86_64 venue")
    if environment["github_actions"] != "true":
        raise PreflightError("B0 first venue must be an actual GitHub-hosted job")
    if not environment["image_os"] or not environment["image_version"]:
        raise PreflightError("GitHub runner image identity is unavailable")
    if _checked(["sudo", "-n", "true"]).returncode != 0:
        raise PreflightError("passwordless sudo is unavailable")

    evidence_dir = output.parent / "b0"
    evidence_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="glassvow-provenance-b0-") as temporary:
        root = Path(temporary)
        build = root / "build"
        staging = root / "staging-capsule"
        mounted = root / "capsule-read-only"
        cases = root / "cases"
        for directory in (build, staging, mounted, cases):
            directory.mkdir()
        compiled = _compile(build)
        supplied = staging / "opaque-role.bin"
        supplied.write_bytes(EXPECTED_INPUT)
        mounted_active = False
        try:
            _checked(["sudo", "-n", "mount", "--bind", str(staging), str(mounted)])
            mounted_active = True
            _checked([
                "sudo", "-n", "mount", "-o", "remount,bind,ro", str(mounted)])
            mount_options = _checked([
                "findmnt", "--noheadings", "--output", "OPTIONS", "--target",
                str(mounted)]).stdout.strip()
            if "ro" not in mount_options.split(","):
                raise PreflightError("capsule bind mount is not read-only")
            try:
                (mounted / "opaque-role.bin").write_bytes(b"replacement")
            except OSError:
                pass
            else:
                raise PreflightError("read-only capsule accepted a write")

            input_path = mounted / "opaque-role.bin"
            input_identity = input_path.stat()
            valid = _probe(
                compiled["tracer"], compiled["workload"], input_path, cases, "valid")
            if valid["returncode"] != 0:
                raise PreflightError(
                    f"valid ptrace probe exited {valid['returncode']}: {valid['stderr'].strip()}")
            valid_result = validate_valid_trace(
                valid["trace"], expected_bytes=EXPECTED_INPUT,
                expected_device=input_identity.st_dev,
                expected_inode=input_identity.st_ino)
            if valid["output_path"].read_bytes() != EXPECTED_INPUT:
                raise PreflightError("valid probe output does not match consumed bytes")

            negatives: list[dict[str, Any]] = []
            for mode, reason in (
                    ("mmap-input", "UNSUPPORTED_MMAP_INPUT"),
                    ("clone-untraced", "UNTRACEABLE_CLONE_FLAG")):
                probe = _probe(
                    compiled["tracer"], compiled["workload"], input_path, cases, mode)
                if probe["returncode"] == 0:
                    raise PreflightError(f"negative ptrace probe passed: {mode}")
                validate_rejection_trace(probe["trace"], reason)
                negatives.append({
                    "mode": mode, "expected_reason": reason,
                    "observed_reason": probe["trace"]["violation"],
                    "returncode": probe["returncode"],
                    "external_duration_ns": probe["trace"]["duration_ns"],
                })

            artifacts: dict[str, Any] = {}
            for source in (
                    compiled["tracer"], compiled["workload"],
                    valid["trace_path"], valid["output_path"],
                    cases / "mmap-input.trace", cases / "mmap-input.output",
                    cases / "clone-untraced.trace", cases / "clone-untraced.output"):
                artifacts[source.name] = _copy_evidence(source, evidence_dir / source.name)
            return {
                "schema": SCHEMA,
                "verdict": "PASS",
                "selected_venue": "github-hosted-ubuntu-24.04",
                "selected_backend": "purpose-built-ptrace-synchronous-stop-v1",
                "environment": environment,
                "read_only_mount": {"options": mount_options, "write_rejected": True},
                "source": {
                    "git_head": _checked(["git", "rev-parse", "HEAD"]).stdout.strip(),
                    "tracer_sha256": sha256_file(TRACER_SOURCE),
                    "workload_sha256": sha256_file(WORKLOAD_SOURCE),
                },
                "build": {
                    "compiler": compiled["compiler"],
                    "compiler_version": compiled["compiler_version"],
                    "commands": compiled["commands"],
                    "tracer_sha256": sha256_file(compiled["tracer"]),
                    "workload_sha256": sha256_file(compiled["workload"]),
                },
                "valid_probe": valid_result,
                "negative_probes": negatives,
                "event_accounting": {
                    "method": "synchronous-ptrace-stops-with-contiguous-sequence",
                    "dropped_events": 0,
                },
                "artifacts": artifacts,
            }
        finally:
            if mounted_active:
                subprocess.run(
                    ["sudo", "-n", "umount", str(mounted)], check=False,
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def _write_json(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n"
    path.write_text(payload, encoding="utf-8")


def _self_test() -> None:
    malformed = [
        TRACE_SCHEMA, "START\t1", "INPUT\t1\t1\t1\t2f78",
        "EXIT\t2\t10\t0", "END\t1\t1\t2\t1\t0\t0\t-",
    ]
    try:
        parse_trace_lines(malformed)
    except PreflightError as error:
        if "sequence" not in str(error):
            raise
    else:
        raise PreflightError("self-test sequence gap unexpectedly passed")


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args(argv)
    if args.self_test:
        _self_test()
        print("execution provenance preflight self-test OK")
        return 0
    if args.output is None:
        parser.error("--output is required unless --self-test is used")
    try:
        receipt = run_preflight(args.output.resolve())
    except (OSError, subprocess.SubprocessError, PreflightError) as error:
        receipt = {
            "schema": SCHEMA,
            "verdict": "INCONCLUSIVE",
            "reason": str(error),
            "environment": _environment(),
        }
        _write_json(args.output.resolve(), receipt)
        print(f"execution provenance B0 INCONCLUSIVE: {error}", file=sys.stderr)
        return 1
    _write_json(args.output.resolve(), receipt)
    print(f"execution provenance B0 PASS: {args.output.resolve()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
