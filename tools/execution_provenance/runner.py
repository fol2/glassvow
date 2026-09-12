#!/usr/bin/env python3
"""Build and supervise one bounded Linux execution-provenance invocation."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any, Sequence


SOURCE_ROOT = Path(__file__).resolve().parent
TRACER_SOURCE = SOURCE_ROOT / "ptrace_tracer.c"
WORKLOAD_SOURCE = SOURCE_ROOT / "inert_workload.c"
CAPSULE_SCHEMA = "glassvow.execution-provenance.capsule/v1"
STATEMENT_SCHEMA = "glassvow.execution-provenance.statement/v1"


class RunnerError(RuntimeError):
    """The trusted builder or supervisor could not complete."""


def canonical_bytes(value: Any) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":")).encode("utf-8")


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(128 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def read_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise RunnerError(f"JSON object required: {path}")
    return value


def write_json(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(canonical_bytes(value) + b"\n")


def checked(command: Sequence[str], *, timeout: int = 30) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        list(command), check=False, capture_output=True, text=True, timeout=timeout)
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip()
        raise RunnerError(f"command failed ({result.returncode}): {command[0]}: {detail}")
    return result


def compile_components(workspace: Path) -> dict[str, Any]:
    compiler = shutil.which("cc")
    if compiler is None:
        raise RunnerError("C compiler is unavailable")
    build = workspace / "build"
    build.mkdir(parents=True, exist_ok=False)
    tracer = build / "trace-supervisor"
    workload = build / "expected-executable"
    common = ["-std=c17", "-O2", "-Wall", "-Wextra", "-Werror"]
    commands = [
        [compiler, *common, "-static", "-Wl,--build-id=none",
         str(TRACER_SOURCE), "-o", str(tracer)],
        [compiler, *common, "-nostdlib", "-static", "-no-pie",
         "-ffreestanding", "-fno-pie", "-fno-stack-protector",
         "-fno-asynchronous-unwind-tables", "-Wl,--build-id=none",
         "-Wl,-z,noexecstack", str(WORKLOAD_SOURCE), "-o", str(workload)],
    ]
    for command in commands:
        checked(command)
    return {
        "compiler": compiler,
        "compilerVersion": checked([compiler, "--version"]).stdout.splitlines()[0],
        "commands": commands,
        "tracer": str(tracer.resolve()),
        "tracerSha256": sha256_file(tracer),
        "workload": str(workload.resolve()),
        "workloadSha256": sha256_file(workload),
    }


def build_capsule(protocol_path: Path, workspace: Path) -> dict[str, Any]:
    protocol = read_json(protocol_path)
    build = compile_components(workspace)
    staging = workspace / "capsule-staging"
    staging.mkdir()
    (staging / "requests").mkdir()
    shutil.copyfile(protocol_path, staging / "protocol.json")
    (staging / "opaque-role.bin").write_bytes(bytes(range(32)))
    shutil.copyfile(Path(build["workload"]), staging / "expected-executable")
    for case in protocol["cases"]:
        token = str(case["requestToken"])
        (staging / "requests" / f"{case['id']}.txt").write_text(
            token + "\n", encoding="utf-8")
    members = []
    for path in sorted(staging.rglob("*")):
        if not path.is_file():
            continue
        mode = 0o555 if path.name == "expected-executable" else 0o444
        os.chmod(path, mode)
        members.append({
            "path": path.relative_to(staging).as_posix(),
            "bytes": path.stat().st_size,
            "sha256": sha256_file(path),
            "mode": f"{mode:04o}",
        })
    payload = {"schema": CAPSULE_SCHEMA, "members": members}
    root = sha256_bytes(canonical_bytes(payload))
    write_json(staging / "manifest.json", {**payload, "root": root})
    os.chmod(staging / "manifest.json", 0o444)
    os.chmod(staging / "requests", 0o555)
    capsules = workspace / "capsules"
    capsules.mkdir()
    destination = capsules / f"sha256-{root}"
    staging.rename(destination)
    os.chmod(destination, 0o555)
    record = {
        "protocolSha256": sha256_file(protocol_path),
        "capsuleRoot": root,
        "capsule": str(destination.resolve()),
        "memberCount": len(members),
        "memberBytes": sum(member["bytes"] for member in members),
        "build": build,
        "source": {
            "supervisorSha256": sha256_file(TRACER_SOURCE),
            "workloadSha256": sha256_file(WORKLOAD_SOURCE),
        },
    }
    write_json(workspace / "build.json", record)
    return record


def _mount_read_only(source: Path, target: Path) -> dict[str, Any]:
    target.mkdir(parents=True, exist_ok=False)
    checked(["sudo", "-n", "mount", "--bind", str(source), str(target)])
    checked(["sudo", "-n", "mount", "-o", "remount,bind,ro", str(target)])
    options = checked([
        "findmnt", "--noheadings", "--output", "OPTIONS", "--target", str(target),
    ]).stdout.strip()
    if "ro" not in options.split(","):
        raise RunnerError("runtime capsule mount is not read-only")
    try:
        (target / ".write-probe").write_bytes(b"must fail")
    except OSError:
        write_rejected = True
    else:
        write_rejected = False
        raise RunnerError("runtime capsule accepted a write")
    return {"source": str(source), "target": str(target),
            "options": options, "writeRejected": write_rejected}


def run_invocation(
        protocol_path: Path, workspace: Path, capsule_source: Path,
        input_path: Path, executable: Path, request: str, challenge_path: Path,
        packet: Path, extra: str) -> dict[str, Any]:
    protocol = read_json(protocol_path)
    challenge = read_json(challenge_path)
    build = read_json(workspace / "build.json")
    packet.mkdir(parents=True, exist_ok=False)
    runtime = packet / "runtime-capsule"
    mount = _mount_read_only(capsule_source, runtime)
    output = packet / "subject.bin"
    trace = packet / "trace.tsv"
    command = [
        build["build"]["tracer"], "--input", str(input_path),
        "--output", str(output), "--trace", str(trace),
        "--exec", str(executable), request,
        "--challenge", challenge["challenge"],
    ]
    if extra:
        command.extend(["--extra", extra])
    try:
        result = subprocess.run(
            command, check=False, capture_output=True,
            timeout=protocol["caps"]["supervisorKillWallNs"] / 1_000_000_000)
    except subprocess.TimeoutExpired as error:
        raise RunnerError("supervisor kill wall cap exceeded") from error
    (packet / "stdout.bin").write_bytes(result.stdout)
    (packet / "stderr.bin").write_bytes(result.stderr)
    executable_evidence = packet / "executed-executable.bin"
    shutil.copyfile(executable, executable_evidence)
    os.chmod(executable_evidence, 0o444)
    if not output.exists():
        output.write_bytes(b"")
    if not trace.is_file():
        raise RunnerError("supervisor did not produce a raw trace")
    end = trace.read_text(encoding="utf-8").splitlines()[-1].split("\t")
    if len(end) != 8 or end[0] != "END":
        raise RunnerError("raw trace footer is unavailable")
    timing = {
        "clock": protocol["clock"]["name"],
        "startedNs": int(end[2]), "finishedNs": int(end[3]),
        "durationNs": int(end[4]),
    }
    executable_stat = executable.stat()
    executable_binding = {
        "path": str(executable),
        "device": executable_stat.st_dev,
        "inode": executable_stat.st_ino,
        "sha256": sha256_file(executable),
        "evidenceSha256": sha256_file(executable_evidence),
    }
    bindings = {
        "protocolSha256": sha256_file(protocol_path),
        "capsuleRoot": build["capsuleRoot"],
        "case": challenge["case"], "challenge": challenge["challenge"],
        "command": command,
        "traceSha256": sha256_file(trace),
        "subjectSha256": sha256_file(output),
        "stdoutSha256": sha256_bytes(result.stdout),
        "stderrSha256": sha256_bytes(result.stderr),
        "externalTiming": timing,
        "runtimeMount": mount,
        "actualExecutable": executable_binding,
    }
    statement = {
        "schema": STATEMENT_SCHEMA, **bindings,
        "invocation": sha256_bytes(canonical_bytes(bindings)),
        "actualInput": str(input_path),
        "actualRequest": request, "returncode": result.returncode,
        "runtimeMount": mount,
        "tracerSha256": build["build"]["tracerSha256"],
    }
    write_json(packet / "statement.json", statement)
    write_json(packet / "mount.json", mount)
    return statement


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    build_parser = subparsers.add_parser("build")
    build_parser.add_argument("--protocol", type=Path, required=True)
    build_parser.add_argument("--workspace", type=Path, required=True)
    run_parser = subparsers.add_parser("run")
    for name in ("protocol", "workspace", "capsule-source", "input",
                 "executable", "challenge", "packet"):
        run_parser.add_argument(f"--{name}", type=Path, required=True)
    run_parser.add_argument("--request", required=True)
    run_parser.add_argument("--extra", default="")
    args = parser.parse_args(argv)
    try:
        if args.command == "build":
            build_capsule(args.protocol.resolve(), args.workspace.resolve())
        else:
            run_invocation(
                args.protocol.resolve(), args.workspace.resolve(),
                args.capsule_source.resolve(), args.input.resolve(),
                args.executable.resolve(), args.request,
                args.challenge.resolve(), args.packet.resolve(), args.extra)
    except (OSError, ValueError, json.JSONDecodeError,
            subprocess.SubprocessError, RunnerError) as error:
        print(f"execution provenance runner failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
