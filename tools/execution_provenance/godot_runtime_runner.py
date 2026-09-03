#!/usr/bin/env python3
"""Prepare and supervise one bounded actual-Godot provenance invocation."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import stat
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Mapping, Sequence


SOURCE_ROOT = Path(__file__).resolve().parent
OBSERVER_ROOT = SOURCE_ROOT.parents[1]
PROFILE_PATH = SOURCE_ROOT / "godot_runtime_profile.json"
G0_MANIFEST_PATH = SOURCE_ROOT / "godot_runtime_g0_manifest.json"
TRACER_SOURCE = SOURCE_ROOT / "godot_runtime_ptrace_tracer.c"
TRACER_IO_SOURCE = SOURCE_ROOT / "godot_runtime_ptrace_io.c"
TRACER_IO_HEADER = SOURCE_ROOT / "godot_runtime_ptrace_io.h"
PACKET_SCHEMA = "glassvow.godot-runtime-packet/v1"
STATEMENT_SCHEMA = "glassvow.godot-runtime-provenance.statement/v1"


class RunnerError(RuntimeError):
    """The trusted Godot profile supervisor could not complete."""


def canonical_bytes(value: Any) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":")).encode("utf-8")


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def read_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise RunnerError(f"JSON object required: {path}")
    return value


def write_json(path: Path, value: Mapping[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(canonical_bytes(value) + b"\n")


def checked(
        command: Sequence[str], *, timeout: float = 30,
        environment: Mapping[str, str] | None = None,
        cwd: Path | None = None) -> subprocess.CompletedProcess[bytes]:
    result = subprocess.run(
        list(command), check=False, capture_output=True, timeout=timeout,
        env=None if environment is None else dict(environment), cwd=cwd)
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).decode("utf-8", errors="replace")
        raise RunnerError(
            f"command failed ({result.returncode}): {command[0]}: {detail.strip()}")
    return result


def validate_frozen_sources(
        profile_path: Path = PROFILE_PATH,
        manifest_path: Path = G0_MANIFEST_PATH) -> tuple[dict[str, Any], dict[str, Any]]:
    profile = read_json(profile_path)
    manifest = read_json(manifest_path)
    expected_manifest = profile.get("g0", {}).get("manifest", {}).get("sha256")
    if sha256_file(manifest_path) != expected_manifest:
        raise RunnerError("frozen G0 manifest hash mismatch")
    if manifest.get("schema") != \
            "glassvow.godot-runtime-provenance.g0-manifest/v1":
        raise RunnerError("frozen G0 manifest schema mismatch")
    cases = profile.get("cases")
    if not isinstance(cases, list) or len(cases) != profile["caps"]["caseCount"]:
        raise RunnerError("frozen case count mismatch")
    return profile, manifest


def _safe_role_path(packet: Path, raw: object, suffix: str) -> Path:
    if not isinstance(raw, str) or not raw or raw != Path(raw).name:
        raise RunnerError("packet role must be one direct relative filename")
    if not raw.endswith(suffix):
        raise RunnerError(f"packet role must end in {suffix}")
    path = packet / raw
    try:
        metadata = path.lstat()
    except OSError as error:
        raise RunnerError("packet role is unavailable") from error
    if stat.S_ISLNK(metadata.st_mode) or not stat.S_ISREG(metadata.st_mode):
        raise RunnerError("packet role must be a regular non-symlink file")
    return path


def preflight_packet_members(
        packet: Path, profile: Mapping[str, Any]) -> dict[str, Path]:
    caps = profile["caps"]
    members: dict[str, Path] = {}
    total = 0
    try:
        with os.scandir(packet) as entries:
            for entry in entries:
                if len(members) >= caps["maxPacketMembers"]:
                    raise RunnerError("packet member cap exceeded")
                metadata = entry.stat(follow_symlinks=False)
                if not stat.S_ISREG(metadata.st_mode):
                    raise RunnerError("packet member must be a regular non-symlink file")
                total += metadata.st_size
                if total > caps["maxPacketBytes"]:
                    raise RunnerError("packet byte cap exceeded")
                members[entry.name] = Path(entry.path)
    except OSError as error:
        raise RunnerError("packet directory is unavailable") from error
    if len(members) != 3 or "manifest.json" not in members:
        raise RunnerError("packet must contain exactly three direct members")
    if members["manifest.json"].stat().st_size > caps["maxPacketManifestBytes"]:
        raise RunnerError("packet manifest cap exceeded")
    return members


def read_packet_manifest(packet: Path, profile: Mapping[str, Any]) -> dict[str, Any]:
    members = preflight_packet_members(packet, profile)
    return read_json(members["manifest.json"])


def validate_packet_manifest(
        packet: Path, manifest: Mapping[str, Any], profile: Mapping[str, Any], *,
        product_sha: str, packet_root: str, authority_issue: int,
        authority_comment: int) -> dict[str, Path]:
    members = preflight_packet_members(packet, profile)
    if set(manifest) != {
            "schema", "productSha", "packetRoot", "authorityIssue",
            "authorityComment", "requestIndices", "roles"}:
        raise RunnerError("packet manifest field set mismatch")
    expected = {
        "schema": PACKET_SCHEMA,
        "productSha": product_sha,
        "packetRoot": packet_root,
        "authorityIssue": authority_issue,
        "authorityComment": authority_comment,
    }
    for key, value in expected.items():
        if manifest.get(key) != value:
            raise RunnerError(f"packet manifest {key} mismatch")
    request_indices = manifest.get("requestIndices")
    caps = profile["caps"]
    if not isinstance(request_indices, list) or not request_indices \
            or len(request_indices) > caps["maxPacketRequests"] \
            or any(
                not isinstance(value, str) or not value.isascii() or not value.isdecimal()
                or str(int(value)) != value or int(value) > caps["maxRequestIndex"]
                for value in request_indices) or len(set(request_indices)) != len(request_indices):
        raise RunnerError("packet request indices differ")
    roles = manifest.get("roles")
    if not isinstance(roles, dict) or set(roles) != {"externalScript", "corpus"}:
        raise RunnerError("packet role set mismatch")
    suffixes = {"externalScript": ".gd", "corpus": ".json"}
    resolved: dict[str, Path] = {}
    total = 0
    for role, suffix in suffixes.items():
        binding = roles.get(role)
        if not isinstance(binding, dict) or set(binding) != {"path", "size", "sha256"}:
            raise RunnerError(f"packet {role} binding mismatch")
        path = _safe_role_path(packet, binding["path"], suffix)
        size = path.stat().st_size
        total += size
        if size != binding["size"] or sha256_file(path) != binding["sha256"]:
            raise RunnerError(f"packet {role} bytes mismatch")
        resolved[role] = path.resolve()
    qualification = profile["packetIngress"]["qualification"]
    if authority_issue == qualification["authorityIssue"]:
        if authority_comment != qualification["authorityComment"]:
            raise RunnerError("qualification packet authority mismatch")
        if request_indices != [profile["roles"]["requestIndex"]["baseline"]]:
            raise RunnerError("qualification packet request index differs")
        for role, expected in qualification["baselineRoles"].items():
            binding = roles[role]
            if any(binding.get(key) != expected[key] for key in ("size", "sha256")):
                raise RunnerError(f"qualification packet {role} differs from G0")
    if set(members) != {
            "manifest.json", resolved["externalScript"].name,
            resolved["corpus"].name}:
        raise RunnerError("packet contains an undeclared member")
    return resolved


def _substitute(template: str, values: Mapping[str, str]) -> str:
    result = template
    for key, value in values.items():
        result = result.replace("${" + key + "}", value)
    if "${" in result:
        raise RunnerError(f"unresolved invocation template: {result}")
    return result


def canonical_invocation(
        profile: Mapping[str, Any], roots: Mapping[str, str],
        external_script: str, corpus: str, index: str) -> tuple[list[str], list[str]]:
    if not index.isascii() or not index.isdecimal():
        raise RunnerError("request index must be a base-10 integer string")
    values = dict(roots)
    values.update({
        "EXTERNAL_SCRIPT": external_script,
        "CORPUS": corpus,
        "INDEX": index,
    })
    command = [
        _substitute(str(item), values)
        for item in profile["invocation"]["launcherArgvTemplate"]
    ]
    environment = [
        _substitute(str(item), values)
        for item in profile["invocation"]["environment"]
    ]
    return command, environment


def validate_product_semantics(
        product: Path, manifest: Mapping[str, Any]) -> list[dict[str, Any]]:
    verified: list[dict[str, Any]] = []
    for record in manifest["semanticReadSet"]:
        raw = str(record["path"])
        if not raw.startswith("${PRODUCT}/"):
            continue
        relative = raw.removeprefix("${PRODUCT}/")
        path = product / relative
        if path.is_symlink() or not path.is_file():
            raise RunnerError(f"product semantic role unavailable: {relative}")
        if path.stat().st_size != record["size"] or \
                sha256_file(path) != record["sha256"]:
            raise RunnerError(f"product semantic role mismatch: {relative}")
        verified.append(dict(record))
    if len(verified) != 28:
        raise RunnerError("product semantic role count mismatch")
    return verified


def generate_godot_configuration(
        godot: Path, product: Path, workspace: Path,
        profile: Mapping[str, Any], manifest: Mapping[str, Any]) -> dict[str, Any]:
    if sha256_file(godot) != profile["runtime"]["godotSha256"]:
        raise RunnerError("Godot executable hash mismatch")
    home = workspace / "configuration-home"
    home.mkdir(parents=True, exist_ok=False)
    result = checked(
        [str(godot), "--headless", "--editor", "--path", str(product),
         "--quit"],
        timeout=profile["caps"]["supervisorKillWallNs"] / 1_000_000_000,
        environment={"HOME": str(home), "PATH": "/usr/bin:/bin", "LANG": "C.UTF-8"},
    )
    verified = validate_product_semantics(product, manifest)
    record = {
        "generatorSha256": sha256_file(godot),
        "product": str(product.resolve()),
        "stdoutSha256": sha256_bytes(result.stdout),
        "stderrSha256": sha256_bytes(result.stderr),
        "semanticRoles": verified,
    }
    write_json(workspace / "generated-configuration.json", record)
    return record


def compile_tracer(workspace: Path) -> dict[str, Any]:
    compiler = shutil.which("cc")
    if compiler is None:
        raise RunnerError("C compiler is unavailable")
    binary = workspace / "godot-runtime-tracer"
    command = [
        compiler, "-std=c17", "-O2", "-Wall", "-Wextra", "-Werror",
        "-static", "-Wl,--build-id=none", str(TRACER_SOURCE),
        str(TRACER_IO_SOURCE), "-o", str(binary),
    ]
    checked(command)
    os.chmod(binary, 0o555)
    checked([str(binary), "--self-test"])
    return {
        "compiler": compiler,
        "compilerVersion": checked([compiler, "--version"]).stdout.decode().splitlines()[0],
        "command": command,
        "binary": str(binary.resolve()),
        "binarySha256": sha256_file(binary),
        "sourceSha256": sha256_file(TRACER_SOURCE),
        "ioSourceSha256": sha256_file(TRACER_IO_SOURCE),
        "ioHeaderSha256": sha256_file(TRACER_IO_HEADER),
    }


def _expand_path(template: str, roots: Mapping[str, str]) -> str:
    return _substitute(template, roots)


def _identity(path: Path, *, logical_path: str | None = None) -> dict[str, Any]:
    metadata = path.stat()
    if not path.is_file():
        raise RunnerError(f"regular file identity required: {path}")
    return {
        "path": logical_path or str(path.resolve()),
        "size": metadata.st_size,
        "sha256": sha256_file(path),
        "device": metadata.st_dev,
        "inode": metadata.st_ino,
    }


def _read_challenge(path: Path) -> str:
    value = path.read_text(encoding="ascii").rstrip("\n")
    if len(value) != 64 or any(character not in "0123456789abcdef" for character in value):
        raise RunnerError("challenge must be 256-bit lowercase hexadecimal")
    return value


def _trace_boundaries(path: Path, challenge: str) -> tuple[int, int]:
    lines = path.read_text(encoding="utf-8").splitlines()
    if len(lines) < 3 or lines[0] != "GODOTTRACEv1":
        raise RunnerError("raw trace envelope is unavailable")
    start = lines[1].split("\t")
    end = lines[-1].split("\t")
    if start[0] != "START" or end[0] != "END" \
            or len(start) < 4 or len(end) < 6 \
            or start[3] != challenge or end[-1] != challenge:
        raise RunnerError("raw trace challenge binding is unavailable")
    return int(start[2]), int(end[3])


def _copy_output(
        source: Path, destination: Path, challenge: str) -> dict[str, Any]:
    record: dict[str, Any] = {
        "path": str(source), "file": destination.name,
        "present": source.is_file(), "challenge": challenge,
    }
    if not record["present"]:
        return record
    identity = _identity(source)
    shutil.copyfile(source, destination)
    record.update({key: value for key, value in identity.items() if key != "path"})
    return record


def enforce_capture_caps(
        profile: Mapping[str, Any], stdout: bytes, stderr: bytes,
        observation: Path, home_log: Path, sentry: Path,
        trace: Path, sidecar: Path) -> None:
    caps = profile["caps"]
    checks = (
        (len(stdout), caps["maxStdoutBytes"], "stdout"),
        (len(stderr), caps["maxStderrBytes"], "stderr"),
        (trace.stat().st_size, caps["maxTraceBytes"], "trace"),
        (sidecar.stat().st_size, caps["maxCapturedBytes"], "sidecar"),
    )
    for actual, limit, label in checks:
        if actual > limit:
            raise RunnerError(f"{label} capture cap exceeded")
    for path, limit, label in (
            (observation, caps["maxObservationBytes"], "observation"),
            (home_log, caps["maxHomeOutputBytes"], "Godot log"),
            (sentry, caps["maxHomeOutputBytes"], "Sentry output")):
        if path.is_symlink() or (path.exists() and not path.is_file()):
            raise RunnerError(f"{label} is not a regular output")
        if path.is_file() and path.stat().st_size > limit:
            raise RunnerError(f"{label} capture cap exceeded")


def build_command(args: argparse.Namespace) -> dict[str, Any]:
    workspace = args.workspace.resolve()
    workspace.mkdir(parents=True, exist_ok=False)
    profile, _ = validate_frozen_sources(
        args.profile.resolve(), args.g0_manifest.resolve())
    result = {
        "schema": "glassvow.godot-runtime-provenance.build/v1",
        "profileSha256": sha256_file(args.profile),
        "g0ManifestSha256": sha256_file(args.g0_manifest),
        "tracer": compile_tracer(workspace),
        "caps": profile["caps"],
    }
    write_json(workspace / "build.json", result)
    return result


def run_case(args: argparse.Namespace) -> dict[str, Any]:
    profile, g0_manifest = validate_frozen_sources(
        args.profile.resolve(), args.g0_manifest.resolve())
    packet = args.packet.resolve()
    if args.packet_manifest.resolve() != packet / "manifest.json":
        raise RunnerError("packet manifest path differs")
    packet_manifest = read_packet_manifest(packet, profile)
    roles = validate_packet_manifest(
        packet, packet_manifest, profile,
        product_sha=args.product_sha, packet_root=args.packet_root,
        authority_issue=args.authority_issue,
        authority_comment=args.authority_comment)
    if args.index not in packet_manifest["requestIndices"]:
        raise RunnerError("request index is not declared by the packet")
    validate_product_semantics(args.product.resolve(), g0_manifest)
    case_dir = args.case_dir.resolve()
    case_dir.mkdir(parents=True, exist_ok=False)
    home = args.home.resolve()
    output = args.output.resolve()
    home.mkdir(parents=True, exist_ok=False)
    output.mkdir(parents=True, exist_ok=False)
    if args.deny_observation:
        os.chmod(output, 0o555)
    challenge = _read_challenge(args.challenge.resolve())
    roots = {
        "GODOT": str(args.godot.resolve()),
        "PRODUCT": str(args.product.resolve()),
        "PACKET": str(args.packet.resolve()),
        "HOME": str(home),
        "OUTPUT": str(output),
    }
    godot_argv = [
        _substitute(str(item), roots | {
            "EXTERNAL_SCRIPT": roles["externalScript"].name,
            "CORPUS": roles["corpus"].name,
            "INDEX": args.index,
        }) for item in profile["invocation"]["godotArgvTemplate"]
    ]
    environment = [_substitute(str(item), roots) for item in profile["invocation"]["environment"]]
    build = read_json(args.workspace.resolve() / "build.json")
    trace_path = case_dir / "trace.tsv"
    sidecar_path = case_dir / "sidecar.bin"
    tracer_command = [
        build["tracer"]["binary"],
        "--challenge", challenge,
        "--trace", str(trace_path),
        "--sidecar", str(sidecar_path),
        "--product-root", roots["PRODUCT"],
        "--packet-root", roots["PACKET"],
        "--home-root", roots["HOME"],
        "--output-root", roots["OUTPUT"],
        "--godot", roots["GODOT"],
        "--script", str(roles["externalScript"]),
        "--corpus", str(roles["corpus"]),
        "--index", args.index,
    ]
    working_directory = OBSERVER_ROOT.resolve()
    start_ns = time.clock_gettime_ns(time.CLOCK_MONOTONIC_RAW)
    try:
        result = subprocess.run(
            tracer_command, check=False, capture_output=True,
            cwd=working_directory,
            timeout=profile["caps"]["supervisorKillWallNs"] / 1_000_000_000)
    except subprocess.TimeoutExpired as error:
        raise RunnerError("supervisor kill wall cap exceeded") from error
    if args.post_reap_delay_ns:
        time.sleep(args.post_reap_delay_ns / 1_000_000_000)
    finish_ns = time.clock_gettime_ns(time.CLOCK_MONOTONIC_RAW)
    (case_dir / "stdout.bin").write_bytes(result.stdout)
    (case_dir / "stderr.bin").write_bytes(result.stderr)
    if not trace_path.is_file() or not sidecar_path.is_file():
        raise RunnerError("tracer did not produce complete evidence files")
    observation = output / "observation.json"
    home_log = home / ".local/share/godot/app_userdata/Glassvow/logs/godot.log"
    sentry = home / ".local/share/godot/app_userdata/Glassvow/sentry.dat"
    enforce_capture_caps(
        profile, result.stdout, result.stderr, observation, home_log, sentry,
        trace_path, sidecar_path)
    tracer_start, tracer_finish = _trace_boundaries(trace_path, challenge)
    runtime_records = []
    for expected in g0_manifest["runtimeIdentitySet"]:
        logical_path = _expand_path(str(expected["path"]), roots)
        runtime_records.append(_identity(
            Path(logical_path), logical_path=logical_path))
    semantic_records = []
    for expected in g0_manifest["semanticReadSet"]:
        template = str(expected["path"])
        if template.startswith("${PACKET}/"):
            continue
        logical_path = _expand_path(template, roots)
        semantic_records.append(_identity(
            Path(logical_path), logical_path=logical_path))
    for role_name, path in roles.items():
        semantic_records.append({"role": role_name, **_identity(path)})
    output_records = {
        "observation": _copy_output(
            observation, case_dir / "observation.json", challenge),
        "homeLog": _copy_output(
            home_log, case_dir / "home-godot.log", challenge),
        "sentry": _copy_output(
            sentry, case_dir / "home-sentry.dat", challenge),
    }
    streams = {}
    for name in ("stdout", "stderr"):
        path = case_dir / f"{name}.bin"
        streams[name] = {
            "file": path.name, "size": path.stat().st_size,
            "sha256": sha256_file(path), "challenge": challenge,
        }
    mounts = read_json(args.mounts.resolve())
    statement = {
        "schema": STATEMENT_SCHEMA, "caseId": args.case_id,
        "requestIndex": args.index,
        "challenge": challenge, "observerSha": args.observer_sha,
        "productSha": args.product_sha, "packetSha": args.packet_sha,
        "packetRoot": args.packet_root, "authorityIssue": args.authority_issue,
        "authorityComment": args.authority_comment,
        "profileSha256": sha256_file(args.profile),
        "g0ManifestSha256": sha256_file(args.g0_manifest),
        "packetManifestSha256": sha256_file(args.packet_manifest),
        "clock": "CLOCK_MONOTONIC_RAW", "roots": roots,
        "workingDirectory": str(working_directory),
        "argv": godot_argv, "environment": environment,
        "executable": _identity(args.godot.resolve()),
        "runtimeIdentities": runtime_records, "roles": semantic_records,
        "timing": {
            "supervisorStartNs": start_ns, "supervisorFinishNs": finish_ns,
            "tracerStartNs": tracer_start, "tracerFinishNs": tracer_finish,
        },
        "streams": streams, "outputs": output_records, "mounts": mounts,
        "tracer": {
            "sourceSha256": build["tracer"]["sourceSha256"],
            "ioSourceSha256": build["tracer"]["ioSourceSha256"],
            "ioHeaderSha256": build["tracer"]["ioHeaderSha256"],
            "binarySha256": build["tracer"]["binarySha256"],
            "returncode": result.returncode,
        },
        "trace": {
            "file": trace_path.name, "size": trace_path.stat().st_size,
            "sha256": sha256_file(trace_path),
        },
        "sidecar": {
            "file": sidecar_path.name, "size": sidecar_path.stat().st_size,
            "sha256": sha256_file(sidecar_path),
        },
    }
    write_json(case_dir / "statement.json", statement)
    return statement


def validate_command(args: argparse.Namespace) -> dict[str, Any]:
    profile, g0_manifest = validate_frozen_sources(
        args.profile.resolve(), args.g0_manifest.resolve())
    packet_manifest = read_packet_manifest(args.packet.resolve(), profile)
    roles = validate_packet_manifest(
        args.packet.resolve(), packet_manifest, profile,
        product_sha=args.product_sha, packet_root=args.packet_root,
        authority_issue=args.authority_issue,
        authority_comment=args.authority_comment)
    if args.index not in packet_manifest["requestIndices"]:
        raise RunnerError("request index is not declared by the packet")
    product_roles = validate_product_semantics(args.product.resolve(), g0_manifest)
    roots = {
        "GODOT": str(args.godot.resolve()),
        "HOME": str(args.home.resolve()),
        "PRODUCT": str(args.product.resolve()),
        "PACKET": str(args.packet.resolve()),
        "OUTPUT": str(args.output.resolve()),
    }
    command, environment = canonical_invocation(
        profile, roots, roles["externalScript"].name,
        roles["corpus"].name, args.index)
    return {
        "profileSha256": sha256_file(args.profile),
        "g0ManifestSha256": sha256_file(args.g0_manifest),
        "packetManifestSha256": sha256_file(args.packet / "manifest.json"),
        "productSha": args.product_sha,
        "packetSha": args.packet_sha,
        "packetRoot": args.packet_root,
        "roles": {name: str(path) for name, path in roles.items()},
        "productRoleCount": len(product_roles),
        "command": command,
        "environment": environment,
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="operation", required=True)
    build = subparsers.add_parser("build")
    build.add_argument("--profile", type=Path, default=PROFILE_PATH)
    build.add_argument("--g0-manifest", type=Path, default=G0_MANIFEST_PATH)
    build.add_argument("--workspace", type=Path, required=True)
    validate = subparsers.add_parser("validate")
    validate.add_argument("--profile", type=Path, default=PROFILE_PATH)
    validate.add_argument("--g0-manifest", type=Path, default=G0_MANIFEST_PATH)
    for name in ("product", "packet", "godot", "home", "output"):
        validate.add_argument(f"--{name}", type=Path, required=True)
    validate.add_argument("--product-sha", required=True)
    validate.add_argument("--packet-sha", required=True)
    validate.add_argument("--packet-root", required=True)
    validate.add_argument("--authority-issue", type=int, required=True)
    validate.add_argument("--authority-comment", type=int, required=True)
    validate.add_argument("--index", default="0")
    validate.add_argument("--receipt", type=Path, required=True)
    run = subparsers.add_parser("run")
    run.add_argument("--profile", type=Path, default=PROFILE_PATH)
    run.add_argument("--g0-manifest", type=Path, default=G0_MANIFEST_PATH)
    for name in ("workspace", "product", "packet", "packet-manifest", "godot",
                 "challenge", "case-dir", "home", "output", "mounts"):
        run.add_argument(f"--{name}", type=Path, required=True)
    for name in ("observer-sha", "product-sha", "packet-sha", "packet-root"):
        run.add_argument(f"--{name}", required=True)
    run.add_argument("--authority-issue", type=int, required=True)
    run.add_argument("--authority-comment", type=int, required=True)
    run.add_argument("--case-id", required=True)
    run.add_argument("--index", default="0")
    run.add_argument("--deny-observation", action="store_true")
    run.add_argument("--post-reap-delay-ns", type=int, default=0)
    args = parser.parse_args(argv)
    try:
        if args.operation == "build":
            build_command(args)
        elif args.operation == "run":
            run_case(args)
        else:
            result = validate_command(args)
            write_json(args.receipt, result)
    except (OSError, ValueError, json.JSONDecodeError,
            subprocess.SubprocessError, RunnerError) as error:
        print(f"Godot runtime provenance runner failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
