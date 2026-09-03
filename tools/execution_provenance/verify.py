#!/usr/bin/env python3
"""Independent policy verifier for bounded execution-provenance packets."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import secrets
import subprocess
import sys
from pathlib import Path
from typing import Any, Sequence


PROTOCOL_SCHEMA = "glassvow.execution-provenance.protocol/v1"
CAPSULE_SCHEMA = "glassvow.execution-provenance.capsule/v1"
CHALLENGE_SCHEMA = "glassvow.execution-provenance.challenge/v1"
CASE_SCHEMA = "glassvow.execution-provenance.case-verdict/v1"
CAMPAIGN_SCHEMA = "glassvow.execution-provenance.campaign-receipt/v1"
RUNTIME_CAPSULE_ATTESTATION_SCHEMA = \
    "glassvow.execution-provenance.runtime-capsule-attestation/v1"
EXPECTED_CASES = ["V00"] + [f"N{index:02d}" for index in range(1, 11)]
EXPECTED_OUTCOMES = {
    "V00": ("PASS", "ADMITTED"),
    "N01": ("REJECT", "POST_FREEZE_CORPUS_REPLACEMENT"),
    "N02": ("REJECT", "SAME_NAME_DIFFERENT_BYTES"),
    "N03": ("REJECT", "EXECUTED_SCRIPT_MISMATCH"),
    "N04": ("REJECT", "REQUEST_SUBSTITUTION"),
    "N05": ("REJECT", "INVOCATION_CHALLENGE_MISMATCH"),
    "N06": ("REJECT", "CACHE_WITHOUT_CURRENT_CONSUMPTION"),
    "N07": ("REJECT", "EXTERNAL_TIMING_MISSING_OR_REPLACED"),
    "N08": ("REJECT", "EXTERNAL_WALL_CAP_EXCEEDED"),
    "N09": ("REJECT", "UNDECLARED_INPUT_PATH"),
    "N10": ("INCONCLUSIVE", "PROVENANCE_INCOMPLETE"),
}
EXPECTED_CAPS = {
    "caseCount": 11, "attemptsPerCase": 1, "mechanicalCorrections": 1,
    "maxProcesses": 4, "maxEvents": 128, "maxTraceBytes": 262144,
    "maxStdoutBytes": 4096, "maxStderrBytes": 4096,
    "maxOutputBytes": 4096, "maxInputRoleBytes": 65536,
    "maxCapsuleMembers": 16, "maxCapsuleBytes": 2097152,
    "maxCasePacketBytes": 1048576, "maxCampaignBytes": 16777216,
    "maxPathBytes": 4096, "judgementWallNs": 200000000,
    "supervisorKillWallNs": 5000000000,
    "timingAttackMinimumNs": 500000000,
    "permittedDroppedEvents": 0, "permittedNetworkSyscalls": 0,
    "validProcessCount": 2, "requiredConsumedBytes": 32,
}


class VerificationError(RuntimeError):
    """The supplied packet cannot support a policy decision."""


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


def read_json(path: Path, cap: int = 1024 * 1024) -> dict[str, Any]:
    if not path.is_file() or path.stat().st_size > cap:
        raise VerificationError(f"missing or oversized JSON: {path}")
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise VerificationError(f"invalid JSON: {path}") from error
    if not isinstance(value, dict):
        raise VerificationError(f"JSON object required: {path}")
    return value


def validate_protocol(protocol: dict[str, Any]) -> None:
    if protocol.get("schema") != PROTOCOL_SCHEMA:
        raise VerificationError("protocol schema is unsupported")
    caps = protocol.get("caps")
    cases = protocol.get("cases")
    if not isinstance(caps, dict) or not isinstance(cases, list):
        raise VerificationError("protocol caps or cases are missing")
    if caps != EXPECTED_CAPS:
        raise VerificationError("numeric caps drifted from the frozen values")
    ids = [case.get("id") for case in cases if isinstance(case, dict)]
    if ids != EXPECTED_CASES:
        raise VerificationError("case order or identity drifted")
    for case in cases:
        expected = EXPECTED_OUTCOMES[case["id"]]
        if (case.get("expectedVerdict"), case.get("expectedReason")) != expected:
            raise VerificationError(f"expected outcome drifted: {case['id']}")
        token = case.get("requestToken")
        if not isinstance(token, str) or not token or len(token.encode()) > 128:
            raise VerificationError(f"request token is invalid: {case['id']}")
    numeric_minimums = {
        "maxProcesses": 2, "maxEvents": 1, "maxTraceBytes": 1,
        "maxStdoutBytes": 1, "maxStderrBytes": 1, "maxOutputBytes": 1,
        "maxInputRoleBytes": 32, "maxCapsuleMembers": 4,
        "maxCapsuleBytes": 1, "maxCasePacketBytes": 1,
        "maxCampaignBytes": 1, "maxPathBytes": 1,
        "judgementWallNs": 1, "supervisorKillWallNs": 1,
        "timingAttackMinimumNs": 1, "requiredConsumedBytes": 32,
    }
    for name, minimum in numeric_minimums.items():
        value = caps.get(name)
        if not isinstance(value, int) or isinstance(value, bool) or value < minimum:
            raise VerificationError(f"numeric cap is invalid: {name}")
    if caps["judgementWallNs"] >= caps["timingAttackMinimumNs"]:
        raise VerificationError("timing attack does not exceed judgement cap")
    if caps["timingAttackMinimumNs"] >= caps["supervisorKillWallNs"]:
        raise VerificationError("supervisor kill cap is not greater than attack delay")
    if caps.get("permittedDroppedEvents") != 0 \
            or caps.get("permittedNetworkSyscalls") != 0:
        raise VerificationError("zero-loss and zero-network policies drifted")
    capsule = protocol.get("capsule", {})
    if capsule.get("dataFileMode") != "0444" \
            or capsule.get("executableFileMode") != "0555" \
            or capsule.get("directoryMode") != "0555":
        raise VerificationError("capsule permission freeze drifted")
    if protocol.get("clock", {}).get("name") != "CLOCK_MONOTONIC_RAW" \
            or protocol.get("authority", {}).get("selectedVenue") \
            != "github-hosted-ubuntu-24.04" \
            or protocol.get("authority", {}).get("selectedBackend") \
            != "purpose-built-ptrace-synchronous-stop-v1":
        raise VerificationError("venue, backend or clock authority drifted")


def policy_verdict(
        protocol: dict[str, Any], case: dict[str, Any],
        observation: dict[str, Any]) -> dict[str, str]:
    """Apply one common fail-closed policy; the case only declares expectation."""
    del case
    if not observation.get("provenance_complete"):
        return {"verdict": "INCONCLUSIVE", "reason": "PROVENANCE_INCOMPLETE"}
    violation = observation.get("trace_violation")
    if violation:
        return {"verdict": "REJECT", "reason": str(violation)}
    if not observation.get("challenge_matches"):
        return {"verdict": "REJECT", "reason": "INVOCATION_CHALLENGE_MISMATCH"}
    if not observation.get("runtime_capsule_matches"):
        return {"verdict": "REJECT", "reason": "POST_FREEZE_CORPUS_REPLACEMENT"}
    if not observation.get("input_path_matches"):
        return {"verdict": "REJECT", "reason": "SAME_NAME_DIFFERENT_BYTES"}
    if not observation.get("input_bytes_match"):
        return {"verdict": "REJECT", "reason": "POST_FREEZE_CORPUS_REPLACEMENT"}
    if not observation.get("executable_matches"):
        return {"verdict": "REJECT", "reason": "EXECUTED_SCRIPT_MISMATCH"}
    if not observation.get("request_matches"):
        return {"verdict": "REJECT", "reason": "REQUEST_SUBSTITUTION"}
    if not observation.get("timing_present_and_matches"):
        return {
            "verdict": "REJECT",
            "reason": "EXTERNAL_TIMING_MISSING_OR_REPLACED",
        }
    if not observation.get("current_consumption_complete") \
            or not observation.get("subject_is_current_output"):
        return {"verdict": "REJECT", "reason": "CACHE_WITHOUT_CURRENT_CONSUMPTION"}
    if not observation.get("output_matches"):
        return {"verdict": "REJECT", "reason": "OUTPUT_MISMATCH"}
    duration = observation.get("external_duration_ns")
    if not isinstance(duration, int) or duration > protocol["caps"]["judgementWallNs"]:
        return {"verdict": "REJECT", "reason": "EXTERNAL_WALL_CAP_EXCEEDED"}
    return {"verdict": "PASS", "reason": "ADMITTED"}


def issue_challenge(protocol_path: Path, case_id: str, output: Path) -> None:
    protocol = read_json(protocol_path)
    validate_protocol(protocol)
    if case_id not in EXPECTED_CASES:
        raise VerificationError("unknown challenge case")
    body = {
        "schema": CHALLENGE_SCHEMA,
        "protocolSha256": sha256_file(protocol_path),
        "case": case_id,
        "nonce": secrets.token_hex(32),
    }
    body["challenge"] = sha256_bytes(canonical_bytes(body))
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(canonical_bytes(body) + b"\n")
    os.chmod(output, 0o600)


def _integer(value: str, label: str, minimum: int = 0) -> int:
    try:
        result = int(value, 10)
    except ValueError as error:
        raise VerificationError(f"non-integer {label}") from error
    if result < minimum:
        raise VerificationError(f"negative {label}")
    return result


def _text(value: str, label: str) -> str:
    try:
        return bytes.fromhex(value).decode("utf-8")
    except (ValueError, UnicodeDecodeError) as error:
        raise VerificationError(f"invalid hex text: {label}") from error


def _bytes(value: str, label: str) -> bytes:
    try:
        return bytes.fromhex(value)
    except ValueError as error:
        raise VerificationError(f"invalid hex bytes: {label}") from error


def parse_trace(path: Path, caps: dict[str, Any]) -> dict[str, Any]:
    if not path.is_file() or path.stat().st_size > caps["maxTraceBytes"]:
        raise VerificationError("trace is missing or exceeds its cap")
    lines = path.read_text(encoding="utf-8").splitlines()
    if len(lines) < 5 or lines[0] != "TRACEv1":
        raise VerificationError("trace header is invalid")
    start = lines[1].split("\t")
    supplied = lines[2].split("\t")
    end = lines[-1].split("\t")
    if len(start) != 2 or start[0] != "START" \
            or len(supplied) != 5 or supplied[0] != "INPUT" \
            or len(end) != 8 or end[0] != "END":
        raise VerificationError("trace envelope is malformed")
    events: list[dict[str, Any]] = []
    for wanted, line in enumerate(lines[3:-1], 1):
        fields = line.split("\t")
        tag = fields[0]
        if tag == "COMMAND" and len(fields) == 6:
            event = {"type": "command", "sequence": _integer(fields[1], "sequence", 1),
                     "challenge": _text(fields[2], "challenge"),
                     "executable": _text(fields[3], "executable"),
                     "request": _text(fields[4], "request"),
                     "extra": _text(fields[5], "extra")}
        elif tag == "EXEC" and len(fields) == 6:
            event = {"type": "exec", "sequence": _integer(fields[1], "sequence", 1),
                     "pid": _integer(fields[2], "pid", 1),
                     "device": _integer(fields[3], "device"),
                     "inode": _integer(fields[4], "inode"),
                     "path": _text(fields[5], "executable path")}
        elif tag == "FORK" and len(fields) == 5:
            event = {"type": "fork", "sequence": _integer(fields[1], "sequence", 1),
                     "pid": _integer(fields[2], "parent", 1),
                     "child": _integer(fields[3], "child", 1), "kind": fields[4]}
        elif tag == "READ" and len(fields) == 12:
            event = {"type": "read", "sequence": _integer(fields[1], "sequence", 1),
                     "pid": _integer(fields[2], "pid", 1), "operation": fields[3],
                     "fd": _integer(fields[4], "fd"), "offset": _integer(fields[5], "offset"),
                     "requested": _integer(fields[6], "requested"),
                     "returned": _integer(fields[7], "returned"),
                     "device": _integer(fields[8], "device"),
                     "inode": _integer(fields[9], "inode"),
                     "path": _text(fields[10], "input path"),
                     "bytes": _bytes(fields[11], "read bytes")}
        elif tag == "WRITE" and len(fields) == 7:
            event = {"type": "write", "sequence": _integer(fields[1], "sequence", 1),
                     "pid": _integer(fields[2], "pid", 1), "fd": _integer(fields[3], "fd"),
                     "requested": _integer(fields[4], "requested"),
                     "returned": _integer(fields[5], "returned"),
                     "bytes": _bytes(fields[6], "write bytes")}
        elif tag == "EXIT" and len(fields) == 4:
            event = {"type": "exit", "sequence": _integer(fields[1], "sequence", 1),
                     "pid": _integer(fields[2], "pid", 1),
                     "code": _integer(fields[3], "exit code")}
        elif tag == "VIOLATION" and len(fields) == 4:
            event = {"type": "violation", "sequence": _integer(fields[1], "sequence", 1),
                     "pid": _integer(fields[2], "pid", 1), "reason": fields[3]}
        else:
            raise VerificationError(f"unknown trace record: {tag}")
        if event["sequence"] != wanted:
            raise VerificationError("trace sequence is not contiguous")
        events.append(event)
    started = _integer(start[1], "start")
    finished = _integer(end[3], "finish")
    result = {
        "started_ns": started, "finished_ns": finished,
        "duration_ns": _integer(end[4], "duration"),
        "dropped": _integer(end[5], "dropped"),
        "root_exit": _integer(end[6], "root exit"),
        "violation": None if end[7] == "-" else end[7],
        "input": {"device": _integer(supplied[1], "device"),
                  "inode": _integer(supplied[2], "inode"),
                  "size": _integer(supplied[3], "size"),
                  "path": _text(supplied[4], "supplied path")},
        "events": events,
    }
    if _integer(end[1], "event count") != len(events) \
            or _integer(end[2], "footer start") != started \
            or finished < started or result["duration_ns"] != finished - started:
        raise VerificationError("trace accounting or timing is inconsistent")
    if len(events) > caps["maxEvents"]:
        raise VerificationError("event cap exceeded")
    return result


def _capsule(capsule: Path, protocol: dict[str, Any]) -> dict[str, Any]:
    manifest = read_json(capsule / "manifest.json")
    payload = {"schema": manifest.get("schema"), "members": manifest.get("members")}
    root = sha256_bytes(canonical_bytes(payload))
    if manifest.get("schema") != CAPSULE_SCHEMA \
            or manifest.get("root") != root or capsule.name != f"sha256-{root}":
        raise VerificationError("canonical capsule root is invalid")
    members = manifest.get("members")
    if not isinstance(members, list) or len(members) > protocol["caps"]["maxCapsuleMembers"]:
        raise VerificationError("capsule member cap exceeded")
    total = 0
    seen: set[str] = set()
    for member in members:
        relative = member.get("path") if isinstance(member, dict) else None
        if not isinstance(relative, str) or relative.startswith("/") or ".." in Path(relative).parts:
            raise VerificationError("capsule member path is unsafe")
        if relative in seen:
            raise VerificationError("capsule member path is duplicated")
        seen.add(relative)
        path = capsule / relative
        if not path.is_file() or path.is_symlink() or sha256_file(path) != member.get("sha256"):
            raise VerificationError(f"capsule member binding failed: {relative}")
        if member.get("bytes") != path.stat().st_size:
            raise VerificationError(f"capsule member size drifted: {relative}")
        wanted_mode = "0555" if relative == "expected-executable" else "0444"
        if member.get("mode") != wanted_mode \
                or f"{path.stat().st_mode & 0o777:04o}" != wanted_mode:
            raise VerificationError(f"capsule member mode drifted: {relative}")
        total += path.stat().st_size
    wanted = {"protocol.json", "opaque-role.bin", "expected-executable"} \
        | {f"requests/{case_id}.txt" for case_id in EXPECTED_CASES}
    if seen != wanted:
        raise VerificationError("capsule role membership drifted")
    if total > protocol["caps"]["maxCapsuleBytes"] \
            or f"{capsule.stat().st_mode & 0o777:04o}" != "0555" \
            or f"{(capsule / 'requests').stat().st_mode & 0o777:04o}" != "0555" \
            or f"{(capsule / 'manifest.json').stat().st_mode & 0o777:04o}" != "0444":
        raise VerificationError("capsule byte cap exceeded")
    return {"root": root, "manifest": manifest}


def _read_capped(path: Path, cap: int) -> bytes:
    if not path.is_file() or path.stat().st_size > cap:
        raise VerificationError(f"artifact missing or oversized: {path.name}")
    return path.read_bytes()


def _lineage(trace: dict[str, Any], cap: int) -> tuple[bool, list[int]]:
    commands = [event for event in trace["events"] if event["type"] == "command"]
    executions = [event for event in trace["events"] if event["type"] == "exec"]
    if len(commands) != 1 or len(executions) != 1:
        return False, []
    pids = {executions[0]["pid"]}
    valid = True
    for event in trace["events"]:
        if event["type"] == "fork":
            if event["pid"] not in pids or event["child"] in pids:
                valid = False
            pids.add(event["child"])
    exits = [event for event in trace["events"] if event["type"] == "exit"]
    valid &= {event["pid"] for event in exits} == pids
    valid &= len(exits) == len(pids) and len(pids) <= cap
    valid &= all(event.get("pid") in pids for event in trace["events"]
                 if "pid" in event)
    valid &= all(event["kind"] in {"fork", "vfork", "clone"}
                 for event in trace["events"] if event["type"] == "fork")
    return valid, sorted(pids)


def _covered_reads(trace: dict[str, Any]) -> tuple[bool, bytes]:
    reads = sorted(
        (event for event in trace["events"] if event["type"] == "read"),
        key=lambda event: event["offset"])
    cursor = 0
    consumed = bytearray()
    operations: set[str] = set()
    supplied = trace["input"]
    for event in reads:
        operations.add(event["operation"])
        if event["fd"] != 3 or event["offset"] != cursor \
                or event["returned"] != len(event["bytes"]) \
                or event["device"] != supplied["device"] \
                or event["inode"] != supplied["inode"] \
                or event["path"] != supplied["path"]:
            return False, bytes(consumed)
        consumed.extend(event["bytes"])
        cursor += event["returned"]
    return operations == {"read", "pread64"}, bytes(consumed)


def _observed_capsule(root: Path, protocol: dict[str, Any]) -> dict[str, Any]:
    if not root.is_dir() or root.is_symlink():
        raise VerificationError("observed capsule root is unavailable or unsafe")
    members: list[dict[str, Any]] = []
    directories: dict[str, str] = {}
    manifest: dict[str, Any] | None = None
    for path in sorted(root.rglob("*")):
        relative = path.relative_to(root).as_posix()
        if path.is_symlink():
            raise VerificationError(f"observed capsule symlink is forbidden: {relative}")
        if path.is_dir():
            directories[relative] = f"{path.stat().st_mode & 0o777:04o}"
        elif path.is_file():
            if relative == "manifest.json":
                manifest = read_json(path)
            else:
                members.append({
                    "path": relative,
                    "bytes": path.stat().st_size,
                    "sha256": sha256_file(path),
                    "mode": f"{path.stat().st_mode & 0o777:04o}",
                })
        else:
            raise VerificationError(f"observed capsule member is not regular: {relative}")
    if manifest is None:
        raise VerificationError("observed capsule manifest is missing")
    if len(members) > protocol["caps"]["maxCapsuleMembers"] \
            or sum(member["bytes"] for member in members) \
            > protocol["caps"]["maxCapsuleBytes"]:
        raise VerificationError("observed capsule exceeds a frozen cap")
    payload = {"schema": CAPSULE_SCHEMA, "members": members}
    return {
        "actualRoot": sha256_bytes(canonical_bytes(payload)),
        "members": members,
        "manifest": manifest,
        "manifestSha256": sha256_file(root / "manifest.json"),
        "rootMode": f"{root.stat().st_mode & 0o777:04o}",
        "directoryModes": directories,
    }


def _safe_evidence_path(root: Path, relative: str) -> Path:
    path = Path(relative)
    if path.is_absolute() or not path.parts or ".." in path.parts:
        raise VerificationError("runtime capsule evidence path is unsafe")
    candidate = root / path
    try:
        resolved = candidate.resolve(strict=True)
    except OSError as error:
        raise VerificationError("runtime capsule evidence is unavailable") from error
    if not candidate.is_relative_to(root) or resolved != candidate:
        raise VerificationError("runtime capsule evidence escaped its campaign")
    return candidate


def attest_runtime_capsule(
        protocol_path: Path, capsule: Path, supplied: Path,
        packet: Path) -> dict[str, Any]:
    protocol = read_json(protocol_path)
    validate_protocol(protocol)
    canonical = _capsule(capsule, protocol)
    runtime = packet / "runtime-capsule"
    mount = read_json(packet / "mount.json")
    supplied_observation = _observed_capsule(supplied, protocol)
    runtime_observation = _observed_capsule(runtime, protocol)
    result = subprocess.run(
        ["findmnt", "--json", "--output", "SOURCE,TARGET,OPTIONS",
         "--target", str(runtime)],
        check=False, capture_output=True, text=True)
    if result.returncode != 0:
        raise VerificationError("runtime capsule mount is not OS-observable")
    try:
        filesystems = json.loads(result.stdout).get("filesystems", [])
    except (AttributeError, json.JSONDecodeError) as error:
        raise VerificationError("runtime capsule mount record is malformed") from error
    if len(filesystems) != 1 or not isinstance(filesystems[0], dict):
        raise VerificationError("runtime capsule mount is not uniquely identified")
    observed_mount = filesystems[0]
    options = str(observed_mount.get("options", ""))
    try:
        (runtime / ".independent-write-probe").write_bytes(b"must fail")
    except OSError:
        write_rejected = True
    else:
        write_rejected = False
        (runtime / ".independent-write-probe").unlink(missing_ok=True)
    source_stat = supplied.stat()
    runtime_stat = runtime.stat()
    source_input_stat = (supplied / "opaque-role.bin").stat()
    runtime_input_stat = (runtime / "opaque-role.bin").stat()
    mount_bound = mount == {
        "source": str(supplied), "target": str(runtime),
        "options": options, "writeRejected": True,
    } and observed_mount.get("target") == str(runtime) \
        and "ro" in options.split(",") and write_rejected \
        and (source_stat.st_dev, source_stat.st_ino) \
        == (runtime_stat.st_dev, runtime_stat.st_ino)
    if not mount_bound:
        raise VerificationError("runtime capsule mount binding is incomplete")
    expected_directories = {"requests": "0555"}
    expected_observation = {
        "actualRoot": canonical["root"],
        "members": canonical["manifest"]["members"],
        "manifest": canonical["manifest"],
        "manifestSha256": sha256_file(capsule / "manifest.json"),
        "rootMode": "0555",
        "directoryModes": expected_directories,
    }
    supplied_relative = supplied.relative_to(packet.parents[1]).as_posix()
    record = {
        "schema": RUNTIME_CAPSULE_ATTESTATION_SCHEMA,
        "protocolSha256": sha256_file(protocol_path),
        "frozenCapsuleRoot": canonical["root"],
        "suppliedEvidence": supplied_relative,
        "runtimeTarget": str(runtime),
        "runtimeInput": {
            "path": str(runtime / "opaque-role.bin"),
            "device": runtime_input_stat.st_dev,
            "inode": runtime_input_stat.st_ino,
            "bytes": runtime_input_stat.st_size,
            "sameSourceObject": (
                source_input_stat.st_dev, source_input_stat.st_ino)
            == (runtime_input_stat.st_dev, runtime_input_stat.st_ino),
        },
        "mountBound": mount_bound,
        "matchesFrozenRoot": supplied.name == capsule.name
        and supplied_observation == expected_observation
        and runtime_observation == expected_observation,
        "suppliedObservation": supplied_observation,
        "runtimeObservation": runtime_observation,
        "osMount": observed_mount,
        "writeRejectedByVerifier": write_rejected,
        "evidence": {
            "traceSha256": sha256_file(packet / "trace.tsv"),
            "mountSha256": sha256_file(packet / "mount.json"),
            "executedExecutableSha256": sha256_file(
                packet / "executed-executable.bin"),
            "verifierSha256": sha256_file(Path(__file__)),
        },
    }
    record["attestationSha256"] = sha256_bytes(canonical_bytes(record))
    return record


def _runtime_attestation(
        protocol_path: Path, capsule: Path, packet: Path) -> dict[str, Any]:
    protocol = read_json(protocol_path)
    record = read_json(packet / "runtime-capsule-attestation.json")
    supplied_digest = record.pop("attestationSha256", None)
    if supplied_digest != sha256_bytes(canonical_bytes(record)):
        raise VerificationError("runtime capsule attestation digest is invalid")
    record["attestationSha256"] = supplied_digest
    canonical = _capsule(capsule, protocol)
    if record.get("schema") != RUNTIME_CAPSULE_ATTESTATION_SCHEMA \
            or record.get("protocolSha256") != sha256_file(protocol_path) \
            or record.get("frozenCapsuleRoot") != canonical["root"] \
            or record.get("mountBound") is not True \
            or record.get("writeRejectedByVerifier") is not True \
            or not isinstance(record.get("runtimeTarget"), str) \
            or not isinstance(record.get("runtimeInput"), dict) \
            or record["runtimeInput"].get("sameSourceObject") is not True:
        raise VerificationError("runtime capsule attestation authority is invalid")
    relative = record.get("suppliedEvidence")
    if not isinstance(relative, str):
        raise VerificationError("runtime capsule evidence path is missing")
    supplied = _safe_evidence_path(packet.parents[1], relative)
    supplied_observation = _observed_capsule(supplied, protocol)
    if supplied_observation != record.get("suppliedObservation") \
            or record.get("runtimeObservation") != supplied_observation:
        raise VerificationError("persisted runtime capsule evidence drifted")
    expected_observation = {
        "actualRoot": canonical["root"],
        "members": canonical["manifest"]["members"],
        "manifest": canonical["manifest"],
        "manifestSha256": sha256_file(capsule / "manifest.json"),
        "rootMode": "0555",
        "directoryModes": {"requests": "0555"},
    }
    expected_match = supplied.name == capsule.name \
        and supplied_observation == expected_observation
    if record.get("matchesFrozenRoot") is not expected_match:
        raise VerificationError("runtime capsule root decision drifted")
    runtime_input = record["runtimeInput"]
    runtime_target = record["runtimeTarget"]
    mount = read_json(packet / "mount.json")
    os_mount = record.get("osMount")
    if not isinstance(os_mount, dict) \
            or not Path(runtime_target).is_absolute() \
            or len(runtime_target.encode("utf-8")) > protocol["caps"]["maxPathBytes"] \
            or mount.get("target") != runtime_target \
            or mount.get("options") != os_mount.get("options") \
            or os_mount.get("target") != runtime_target \
            or mount.get("writeRejected") is not True \
            or "ro" not in str(mount.get("options", "")).split(",") \
            or runtime_input.get("path") \
            != str(Path(runtime_target) / "opaque-role.bin") \
            or not isinstance(runtime_input.get("device"), int) \
            or isinstance(runtime_input.get("device"), bool) \
            or not isinstance(runtime_input.get("inode"), int) \
            or isinstance(runtime_input.get("inode"), bool) \
            or not isinstance(runtime_input.get("bytes"), int) \
            or isinstance(runtime_input.get("bytes"), bool) \
            or runtime_input.get("bytes") < 0 \
            or runtime_input.get("bytes") > protocol["caps"]["maxInputRoleBytes"]:
        raise VerificationError("runtime capsule mount evidence is malformed")
    evidence = record.get("evidence")
    expected_evidence = {
        "traceSha256": sha256_file(packet / "trace.tsv"),
        "mountSha256": sha256_file(packet / "mount.json"),
        "executedExecutableSha256": sha256_file(
            packet / "executed-executable.bin"),
        "verifierSha256": sha256_file(Path(__file__)),
    }
    if evidence != expected_evidence:
        raise VerificationError("runtime capsule attestation evidence drifted")
    return record


def _statement_integrity(statement: dict[str, Any], packet: Path) -> bool:
    names = ("trace.tsv", "subject.bin", "stdout.bin", "stderr.bin")
    keys = ("traceSha256", "subjectSha256", "stdoutSha256", "stderrSha256")
    if any(statement.get(key) != sha256_file(packet / name)
           for name, key in zip(names, keys)):
        return False
    executable = statement.get("actualExecutable")
    if not isinstance(executable, dict) \
            or not isinstance(executable.get("path"), str) \
            or not isinstance(executable.get("device"), int) \
            or isinstance(executable.get("device"), bool) \
            or not isinstance(executable.get("inode"), int) \
            or isinstance(executable.get("inode"), bool) \
            or executable.get("sha256") \
            != sha256_file(packet / "executed-executable.bin") \
            or executable.get("evidenceSha256") \
            != sha256_file(packet / "executed-executable.bin") \
            or statement.get("runtimeMount") != read_json(packet / "mount.json"):
        return False
    binding_names = (
        "protocolSha256", "capsuleRoot", "case", "challenge", "command",
        "traceSha256", "subjectSha256", "stdoutSha256", "stderrSha256",
        "externalTiming", "runtimeMount", "actualExecutable",
    )
    bindings = {name: statement.get(name) for name in binding_names}
    return statement.get("invocation") == sha256_bytes(canonical_bytes(bindings))


def verify_case(
        protocol_path: Path, capsule: Path, challenge_path: Path,
        packet: Path) -> dict[str, Any]:
    protocol = read_json(protocol_path)
    validate_protocol(protocol)
    case_id = packet.name
    cases = {case["id"]: case for case in protocol["cases"]}
    if case_id not in cases:
        raise VerificationError("packet directory is not a frozen case")
    if sum(path.stat().st_size for path in packet.rglob("*") if path.is_file()) \
            > protocol["caps"]["maxCasePacketBytes"]:
        raise VerificationError("case packet byte cap exceeded")
    capsule_record = _capsule(capsule, protocol)
    challenge = read_json(challenge_path)
    if challenge.get("schema") != CHALLENGE_SCHEMA \
            or challenge.get("case") != case_id \
            or challenge.get("protocolSha256") != sha256_file(protocol_path):
        raise VerificationError("challenge binding is invalid")
    challenge_body = dict(challenge)
    supplied_challenge = challenge_body.pop("challenge", None)
    if supplied_challenge != sha256_bytes(canonical_bytes(challenge_body)):
        raise VerificationError("challenge digest is invalid")
    statement = read_json(packet / "statement.json")
    runtime_attestation = _runtime_attestation(protocol_path, capsule, packet)
    trace = parse_trace(packet / "trace.tsv", protocol["caps"])
    subject = _read_capped(packet / "subject.bin", protocol["caps"]["maxOutputBytes"])
    stdout = _read_capped(packet / "stdout.bin", protocol["caps"]["maxStdoutBytes"])
    stderr = _read_capped(packet / "stderr.bin", protocol["caps"]["maxStderrBytes"])
    executable_snapshot = _read_capped(
        packet / "executed-executable.bin", protocol["caps"]["maxCapsuleBytes"])
    commands = [event for event in trace["events"] if event["type"] == "command"]
    executions = [event for event in trace["events"] if event["type"] == "exec"]
    command = commands[0] if len(commands) == 1 else {}
    execution = executions[0] if len(executions) == 1 else {}
    lineage_valid, lineage = _lineage(trace, protocol["caps"]["maxProcesses"])
    reads_complete, consumed = _covered_reads(trace)
    writes = [event for event in trace["events"] if event["type"] == "write"]
    written_subject = b"".join(event["bytes"] for event in writes if event["fd"] == 4)
    written_stdout = b"".join(event["bytes"] for event in writes if event["fd"] == 1)
    written_stderr = b"".join(event["bytes"] for event in writes if event["fd"] == 2)
    writes_valid = all(event["returned"] == len(event["bytes"])
                       and event["returned"] <= event["requested"]
                       and event["fd"] in {1, 2, 4} for event in writes)
    expected_input = (capsule / "opaque-role.bin").read_bytes()
    expected_exec = capsule / "expected-executable"
    expected_request = (capsule / "requests" / f"{case_id}.txt").read_text(
        encoding="utf-8").rstrip("\n")
    executable_binding = statement.get("actualExecutable")
    if not isinstance(executable_binding, dict):
        executable_binding = {}
    executable_snapshot_sha = sha256_bytes(executable_snapshot)
    executable_identity_complete = bool(execution) \
        and execution.get("path") == executable_binding.get("path") \
        and execution.get("device") == executable_binding.get("device") \
        and execution.get("inode") == executable_binding.get("inode") \
        and executable_binding.get("sha256") == executable_snapshot_sha \
        and executable_binding.get("evidenceSha256") == executable_snapshot_sha
    runtime_input_identity = runtime_attestation.get("runtimeInput")
    if not isinstance(runtime_input_identity, dict):
        runtime_input_identity = {}
    runtime_input = str(runtime_input_identity.get("path", "/missing"))
    input_identity_matches = trace["input"] == {
        "device": runtime_input_identity.get("device"),
        "inode": runtime_input_identity.get("inode"),
        "size": runtime_input_identity.get("bytes"),
        "path": runtime_input,
    }
    timing = statement.get("externalTiming")
    timing_matches = timing == {
        "clock": protocol["clock"]["name"],
        "startedNs": trace["started_ns"],
        "finishedNs": trace["finished_ns"],
        "durationNs": trace["duration_ns"],
    }
    violations = [event["reason"] for event in trace["events"]
                  if event["type"] == "violation"]
    violation_matches = (not violations and trace["violation"] is None) \
        or violations == [trace["violation"]]
    statement_authority = statement.get("schema") \
        == "glassvow.execution-provenance.statement/v1" \
        and statement.get("protocolSha256") == sha256_file(protocol_path) \
        and statement.get("capsuleRoot") == capsule_record["root"]
    paths = [trace["input"]["path"], str(command.get("executable", "")),
             str(command.get("extra", "")), str(execution.get("path", ""))]
    provenance_complete = lineage_valid and violation_matches and writes_valid \
        and statement_authority and executable_identity_complete \
        and all(len(path.encode("utf-8")) <= protocol["caps"]["maxPathBytes"]
                for path in paths) \
        and runtime_attestation.get("mountBound") is True \
        and _statement_integrity(statement, packet) \
        and trace["dropped"] == protocol["caps"]["permittedDroppedEvents"]
    runtime_capsule_matches = runtime_attestation.get("matchesFrozenRoot") is True
    observation = {
        "provenance_complete": provenance_complete,
        "trace_violation": trace["violation"],
        "challenge_matches": command.get("challenge") == challenge["challenge"]
        and statement.get("challenge") == challenge["challenge"]
        and statement.get("case") == challenge["case"],
        "runtime_capsule_matches": runtime_capsule_matches,
        "input_path_matches": input_identity_matches,
        "input_bytes_match": trace["input"]["size"] == len(expected_input)
        and (consumed == expected_input
             or (not consumed and runtime_capsule_matches and input_identity_matches)),
        "executable_matches": executable_snapshot_sha == sha256_file(expected_exec),
        "request_matches": command.get("request") == expected_request,
        "timing_present_and_matches": timing_matches,
        "current_consumption_complete": reads_complete
        and len(consumed) == protocol["caps"]["requiredConsumedBytes"],
        "subject_is_current_output": written_subject == subject
        and written_stdout == stdout and written_stderr == stderr,
        "output_matches": subject == expected_input,
        "external_duration_ns": trace["duration_ns"],
        "child_claim_ns": 1 if stdout == b"CHILD_ELAPSED_NS=1\n" else None,
    }
    decision = policy_verdict(protocol, cases[case_id], observation)
    witnesses = {
        "V00": trace["root_exit"] == 0
        and all(event["code"] == 0 for event in trace["events"]
                if event["type"] == "exit")
        and len(lineage) == protocol["caps"]["validProcessCount"]
        and runtime_capsule_matches,
        "N01": trace["input"]["path"] == runtime_input
        and not runtime_capsule_matches,
        "N02": Path(trace["input"]["path"]).name == "opaque-role.bin"
        and not input_identity_matches and consumed != expected_input,
        "N03": executable_snapshot_sha != sha256_file(expected_exec),
        "N04": command.get("request") != expected_request,
        "N05": command.get("challenge") != challenge["challenge"],
        "N06": not reads_complete and subject == expected_input and written_subject != subject,
        "N07": not timing_matches,
        "N08": observation["child_claim_ns"] == 1
        and trace["duration_ns"] >= protocol["caps"]["timingAttackMinimumNs"],
        "N09": trace["violation"] == "UNDECLARED_INPUT_PATH"
        and bool(command.get("extra")),
        "N10": trace["dropped"] == 1 and trace["violation"] == "PROVENANCE_INCOMPLETE",
    }
    witness_complete = witnesses[case_id]
    files = {}
    for name in (
            "trace.tsv", "subject.bin", "stdout.bin", "stderr.bin",
            "statement.json", "mount.json", "executed-executable.bin",
            "runtime-capsule-attestation.json"):
        path = packet / name
        files[name] = {"bytes": path.stat().st_size, "sha256": sha256_file(path)}
    result = {
        "schema": CASE_SCHEMA,
        "case": case_id,
        "protocolSha256": sha256_file(protocol_path),
        "capsuleRoot": capsule_record["root"],
        "challenge": challenge["challenge"],
        "verdict": decision["verdict"],
        "reason": decision["reason"],
        "expectedVerdict": cases[case_id]["expectedVerdict"],
        "expectedReason": cases[case_id]["expectedReason"],
        "matchesExpectation": witness_complete
        and decision["verdict"] == cases[case_id]["expectedVerdict"]
        and decision["reason"] == cases[case_id]["expectedReason"],
        "controlWitnessComplete": witness_complete,
        "observation": {**observation, "lineage": lineage,
                        "consumedBytes": len(consumed),
                        "actualInputPath": trace["input"]["path"],
                        "actualInputSha256": sha256_bytes(consumed),
                        "actualExecutablePath": str(execution.get("path", "")),
                        "actualExecutableSha256": executable_snapshot_sha,
                        "runtimeCapsuleRoot": runtime_attestation.get(
                            "runtimeObservation", {}).get("actualRoot")},
        "artifacts": files,
    }
    result["caseIdentity"] = sha256_bytes(canonical_bytes(result))
    return result


def verify_campaign(
        protocol_path: Path, capsule: Path, results: Path) -> dict[str, Any]:
    protocol = read_json(protocol_path)
    validate_protocol(protocol)
    capsule_record = _capsule(capsule, protocol)
    cases = []
    for case_id in EXPECTED_CASES:
        primary = (results / case_id / "verdict.json").read_bytes()
        replay = (results / case_id / "verdict-replay.json").read_bytes()
        recomputed = canonical_bytes(verify_case(
            protocol_path, capsule, results.parent / "challenges" / f"{case_id}.json",
            results / case_id)) + b"\n"
        if primary != replay or primary != recomputed:
            raise VerificationError(f"verification replay drifted: {case_id}")
        verdict = json.loads(primary)
        cases.append({"case": case_id, "verdict": verdict["verdict"],
                      "reason": verdict["reason"],
                      "matchesExpectation": verdict["matchesExpectation"],
                      "challenge": verdict["challenge"],
                      "caseIdentity": verdict["caseIdentity"],
                      "receiptSha256": sha256_bytes(primary)})
    if len({case["challenge"] for case in cases}) != len(cases):
        raise VerificationError("verifier challenges are not unique")
    total = sum(path.stat().st_size for path in results.parent.rglob("*") if path.is_file())
    if total > protocol["caps"]["maxCampaignBytes"]:
        raise VerificationError("campaign byte cap exceeded")
    passed = all(case["matchesExpectation"] for case in cases)
    source_dir = Path(__file__).resolve().parent
    sources = {path.name: sha256_file(path) for path in sorted(source_dir.iterdir())
               if path.is_file() and path.suffix in {".py", ".c", ".json"}}
    git_head = subprocess.run(
        ["git", "rev-parse", "HEAD"], check=True, capture_output=True,
        text=True, cwd=source_dir).stdout.strip()
    server = os.environ.get("GITHUB_SERVER_URL")
    repository = os.environ.get("GITHUB_REPOSITORY")
    run_id = os.environ.get("GITHUB_RUN_ID")
    run_url = f"{server}/{repository}/actions/runs/{run_id}" \
        if server and repository and run_id else None
    build = read_json(results.parent / "workspace" / "build.json")
    binaries = build.get("build", {})
    built_supervisor = results.parent / "workspace" / "build" / "trace-supervisor"
    built_workload = results.parent / "workspace" / "build" / "expected-executable"
    executable_identities = {
        "supervisorSha256": sha256_file(built_supervisor),
        "workloadSha256": sha256_file(built_workload),
        "compiler": binaries.get("compiler"),
        "compilerVersion": binaries.get("compilerVersion"),
        "commands": binaries.get("commands"),
    }
    if executable_identities["supervisorSha256"] != binaries.get("tracerSha256") \
            or executable_identities["workloadSha256"] != binaries.get("workloadSha256") \
            or build.get("capsuleRoot") != capsule_record["root"]:
        raise VerificationError("compiled execution identity drifted")
    return {
        "schema": CAMPAIGN_SCHEMA,
        "campaign": protocol["campaign"],
        "verdict": "PASS" if passed else "FAIL",
        "reason": "ALL_FROZEN_CASES_MATCH" if passed else "CASE_EXPECTATION_MISMATCH",
        "gitHead": git_head,
        "protocolSha256": sha256_file(protocol_path),
        "capsuleRoot": capsule_record["root"],
        "selectedVenue": protocol["authority"]["selectedVenue"],
        "selectedBackend": protocol["authority"]["selectedBackend"],
        "environment": {
            "imageOS": os.environ.get("ImageOS"),
            "imageVersion": os.environ.get("ImageVersion"),
            "runnerOS": os.environ.get("RUNNER_OS"),
            "runnerArch": os.environ.get("RUNNER_ARCH"),
            "kernel": os.uname().release,
            "workflowRun": run_url,
            "workflowAttempt": os.environ.get("GITHUB_RUN_ATTEMPT"),
        },
        "deterministicVerificationReplay": True,
        "mechanicalCorrectionsUsed": 1,
        "caseCount": len(cases),
        "cases": cases,
        "campaignBytes": total,
        "sourceSha256": sources,
        "build": executable_identities,
        "verifierSha256": sha256_file(Path(__file__)),
        "excludedClaims": protocol["trustMap"]["excludedClaims"],
    }


def write_json(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(canonical_bytes(value) + b"\n")


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    challenge_parser = subparsers.add_parser("challenge")
    challenge_parser.add_argument("--protocol", type=Path, required=True)
    challenge_parser.add_argument("--case", required=True)
    challenge_parser.add_argument("--output", type=Path, required=True)
    mount_parser = subparsers.add_parser("mount")
    mount_parser.add_argument("--protocol", type=Path, required=True)
    mount_parser.add_argument("--capsule", type=Path, required=True)
    mount_parser.add_argument("--supplied", type=Path, required=True)
    mount_parser.add_argument("--packet", type=Path, required=True)
    mount_parser.add_argument("--output", type=Path, required=True)
    case_parser = subparsers.add_parser("case")
    case_parser.add_argument("--protocol", type=Path, required=True)
    case_parser.add_argument("--capsule", type=Path, required=True)
    case_parser.add_argument("--challenge", type=Path, required=True)
    case_parser.add_argument("--packet", type=Path, required=True)
    case_parser.add_argument("--output", type=Path, required=True)
    campaign_parser = subparsers.add_parser("campaign")
    campaign_parser.add_argument("--protocol", type=Path, required=True)
    campaign_parser.add_argument("--capsule", type=Path, required=True)
    campaign_parser.add_argument("--results", type=Path, required=True)
    campaign_parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        if args.command == "challenge":
            issue_challenge(args.protocol.resolve(), args.case, args.output.resolve())
        elif args.command == "mount":
            write_json(args.output.resolve(), attest_runtime_capsule(
                args.protocol.resolve(), args.capsule.resolve(),
                args.supplied.resolve(), args.packet.resolve()))
        elif args.command == "case":
            write_json(args.output.resolve(), verify_case(
                args.protocol.resolve(), args.capsule.resolve(),
                args.challenge.resolve(), args.packet.resolve()))
        else:
            write_json(args.output.resolve(), verify_campaign(
                args.protocol.resolve(), args.capsule.resolve(), args.results.resolve()))
    except (OSError, ValueError, subprocess.SubprocessError, VerificationError) as error:
        print(f"execution provenance verification failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
