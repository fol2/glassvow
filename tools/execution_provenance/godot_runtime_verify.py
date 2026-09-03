#!/usr/bin/env python3
"""Independent verifier for the frozen actual-Godot provenance profile."""
from __future__ import annotations
import argparse, fnmatch, hashlib, importlib.util, json, os, secrets, stat, sys
from pathlib import Path
from typing import Any, Mapping, Sequence

_HELPER_PATH = Path(__file__).with_name("godot_runtime_trace_verify.py")
_SPEC = importlib.util.spec_from_file_location("_godot_runtime_trace_verify", _HELPER_PATH)
if _SPEC is None or _SPEC.loader is None: raise RuntimeError("independent trace verifier unavailable")
_TRACE = importlib.util.module_from_spec(_SPEC); _SPEC.loader.exec_module(_TRACE)
VerificationFailure, parse_trace_lines = _TRACE.VerificationFailure, _TRACE.parse_trace_lines
validate_syscall_grammar, validate_complete_role_reads = _TRACE.validate_syscall_grammar, _TRACE.validate_complete_role_reads
reject_semantic_mappings, fail, integer = _TRACE.reject_semantic_mappings, _TRACE.fail, _TRACE.integer
validate_trace_accounting = _TRACE.validate_trace_accounting
_pipe_path, _internal_pipe_paths = _TRACE.pipe_path, _TRACE.internal_pipe_paths
_validate_internal_pipe = _TRACE.validate_internal_pipe
_validate_request_indices = _TRACE.validate_request_indices
PROFILE_SCHEMA = "glassvow.godot-runtime-provenance.profile/v1"
G0_SCHEMA = "glassvow.godot-runtime-provenance.g0-manifest/v1"
PACKET_SCHEMA = "glassvow.godot-runtime-packet/v1"
STATEMENT_SCHEMA = "glassvow.godot-runtime-provenance.statement/v1"
RECEIPT_SCHEMA = "glassvow.godot-runtime-provenance.receipt/v1"
CAMPAIGN_SCHEMA = "glassvow.godot-runtime-provenance.campaign-receipt/v1"
# Rebound once after exact-profile review and before any qualification case.
FROZEN_PROFILE_SHA256 = "PROFILE_SHA256_TO_BE_FROZEN"
_REASONS = (
    "ADMITTED GODOT_EXECUTABLE_MISMATCH RUNTIME_DEPENDENCY_MISMATCH ARGV_MISMATCH "
    "ENVIRONMENT_MISMATCH PROJECT_SEMANTIC_BYTES_MISMATCH GENERATED_CACHE_BYTES_MISMATCH "
    "EXTERNAL_SCRIPT_PATH_MISMATCH EXTERNAL_SCRIPT_BYTES_MISMATCH CORPUS_PATH_MISMATCH "
    "CORPUS_BYTES_MISMATCH REQUEST_INDEX_MISMATCH UNDECLARED_INPUT_PATH UNDECLARED_CACHE_ACCESS "
    "FORBIDDEN_NETWORK_FAMILY OUTPUT_WRITE_DENIED STDERR_CAPTURE_MISSING STDERR_CAPTURE_MISMATCH "
    "STDERR_INVOCATION_MISMATCH OUTPUT_NOT_CURRENT INVOCATION_CHALLENGE_MISMATCH "
    "PROCESS_LINEAGE_MISMATCH EXTERNAL_TIMING_MISMATCH EXTERNAL_WALL_CAP_EXCEEDED "
    "PROVENANCE_INCOMPLETE SEMANTIC_MAPPING_DENIED").split()
CASE_RESULTS = {f"G{i:02d}": ("PASS" if i == 0 else "INCONCLUSIVE" if i == 24 else "REJECT", reason)
                for i, reason in enumerate(_REASONS)}


def _sha(data: bytes) -> str: return hashlib.sha256(data).hexdigest()


def _file_sha(path: Path) -> str:
    digest = hashlib.sha256()
    try:
        with path.open("rb") as handle:
            for block in iter(lambda: handle.read(1024 * 1024), b""): digest.update(block)
    except OSError as error: fail("PROVENANCE_INCOMPLETE", f"cannot hash {path}: {error}")
    return digest.hexdigest()


def _canonical(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()


def _json(path: Path) -> dict[str, Any]:
    try: value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        fail("PROVENANCE_INCOMPLETE", f"cannot read {path.name}: {error}")
    if not isinstance(value, dict): fail("PROVENANCE_INCOMPLETE", f"{path.name} is not an object")
    return value


def _expand(template: str, roots: Mapping[str, str]) -> str:
    result = template
    for key, value in roots.items(): result = result.replace("${" + key + "}", value)
    if "${" in result: fail("PROVENANCE_INCOMPLETE", f"unresolved template {template}")
    return result


def _load_sources(profile_path: Path, g0_path: Path, packet_path: Path) -> tuple[dict, dict, dict]:
    if _file_sha(profile_path) != FROZEN_PROFILE_SHA256: fail("PROFILE_MISMATCH", "profile bytes differ")
    profile, g0, packet = _json(profile_path), _json(g0_path), _json(packet_path)
    if profile.get("schema") != PROFILE_SCHEMA: fail("PROFILE_MISMATCH", "profile schema differs")
    if g0.get("schema") != G0_SCHEMA or _file_sha(g0_path) != profile.get("g0", {}).get("manifest", {}).get("sha256"):
        fail("MANIFEST_MISMATCH", "G0 manifest bytes differ")
    if packet.get("schema") != PACKET_SCHEMA or set(packet) != {"schema", "productSha", "packetRoot", "authorityIssue", "authorityComment", "requestIndices", "roles"}:
        fail("PACKET_MANIFEST_MISMATCH", "packet schema or fields differ")
    return profile, g0, packet

def _absolute(value: Any, label: str) -> str:
    if not isinstance(value, str) or not value.startswith("/") or ".." in Path(value).parts:
        fail("PROVENANCE_INCOMPLETE", f"invalid {label}")
    return value


def _live(record: Mapping[str, Any], reason: str, no_symlink: bool = False) -> bytes:
    path = Path(_absolute(record.get("path"), "identity path"))
    try:
        metadata = path.lstat()
        if no_symlink and stat.S_ISLNK(metadata.st_mode): fail(reason, f"symlink role {path}")
        current, data = path.stat(), path.read_bytes()
        if not stat.S_ISREG(current.st_mode): fail(reason, f"non-regular role {path}")
    except OSError as error: fail(reason, f"identity unavailable {path}: {error}")
    if (current.st_size, _sha(data), current.st_dev, current.st_ino) != \
            (record.get("size"), record.get("sha256"), record.get("device"), record.get("inode")):
        fail(reason, f"current identity differs for {path}")
    return data


def _frozen_live(record: Mapping[str, Any], roots: Mapping[str, str], reason: str) -> dict[str, Any]:
    path = Path(_expand(str(record.get("path")), roots))
    try: current, data = path.stat(), path.read_bytes()
    except OSError as error: fail(reason, f"frozen object unavailable {path}: {error}")
    if current.st_size != record.get("size") or _sha(data) != record.get("sha256"):
        fail(reason, f"frozen object bytes differ {path}")
    return {**record, "path": str(path), "device": current.st_dev, "inode": current.st_ino}


def _records(value: Any, label: str) -> dict[str, Mapping[str, Any]]:
    if not isinstance(value, list): fail("PROVENANCE_INCOMPLETE", f"{label} is not a list")
    result: dict[str, Mapping[str, Any]] = {}
    for record in value:
        if not isinstance(record, dict) or not isinstance(record.get("path"), str) or record["path"] in result:
            fail("PROVENANCE_INCOMPLETE", f"invalid {label} record")
        result[record["path"]] = record
    return result


def _roles(g0: Mapping[str, Any], packet: Mapping[str, Any], roots: Mapping[str, str],
           profile: Mapping[str, Any], args: argparse.Namespace) -> dict[str, dict]:
    result: dict[str, dict] = {}
    for raw in g0.get("semanticReadSet", []):
        if str(raw.get("path", "")).startswith("${PRODUCT}/"):
            record = dict(raw); record["path"] = _expand(record["path"], roots); result[record["path"]] = record
    bindings = packet.get("roles")
    if not isinstance(bindings, dict) or set(bindings) != {"externalScript", "corpus"}:
        fail("PACKET_MANIFEST_MISMATCH", "packet roles differ")
    for name, suffix in (("externalScript", ".gd"), ("corpus", ".json")):
        raw = bindings[name]
        if not isinstance(raw, dict) or set(raw) != {"path", "size", "sha256"} or \
                not isinstance(raw["path"], str) or raw["path"] != Path(raw["path"]).name or not raw["path"].endswith(suffix):
            fail("PACKET_MANIFEST_MISMATCH", f"invalid {name} binding")
        record = dict(raw); record["path"] = str(Path(roots["PACKET"]) / raw["path"]); result[record["path"]] = record
    qualification = profile.get("packetIngress", {}).get("qualification", {})
    if args.authority_issue == qualification.get("authorityIssue"):
        if args.authority_comment != qualification.get("authorityComment"):
            fail("PACKET_MANIFEST_MISMATCH", "qualification authority differs")
        baseline = qualification.get("baselineRoles")
        if not isinstance(baseline, dict) or any(
                bindings[name].get(key) != baseline.get(name, {}).get(key)
                for name in ("externalScript", "corpus") for key in ("size", "sha256")):
            fail("PACKET_MANIFEST_MISMATCH", "qualification role bytes differ")
    if len(result) != 30: fail("PROVENANCE_INCOMPLETE", "semantic role count differs")
    return result


def _identity_set(g0: Mapping[str, Any], roots: Mapping[str, str], key: str) -> dict[str, dict]:
    result: dict[str, dict] = {}
    for raw in g0.get(key, []):
        record = dict(raw); record["path"] = _expand(record["path"], roots); result[record["path"]] = record
    return result


def _authority(statement: Mapping[str, Any], packet: Mapping[str, Any], profile: Mapping[str, Any],
               args: argparse.Namespace) -> None:
    for name in ("observer_sha", "product_sha", "packet_sha"):
        value = getattr(args, name)
        if len(value) != 40 or any(char not in "0123456789abcdef" for char in value):
            fail("PROVENANCE_INCOMPLETE", f"invalid {name}")
    exact = {"observerSha": args.observer_sha, "productSha": args.product_sha, "packetSha": args.packet_sha,
             "packetRoot": args.packet_root, "authorityIssue": args.authority_issue,
             "authorityComment": args.authority_comment, "requestIndex": args.request_index,
             "profileSha256": _file_sha(args.profile),
             "g0ManifestSha256": _file_sha(args.g0_manifest),
             "packetManifestSha256": _file_sha(args.packet_manifest)}
    if any(statement.get(key) != value for key, value in exact.items()):
        fail("PROVENANCE_INCOMPLETE", "statement differs from independent workflow inputs")
    expected = {"productSha": args.product_sha, "packetRoot": args.packet_root,
                "authorityIssue": args.authority_issue, "authorityComment": args.authority_comment}
    if any(packet.get(key) != value for key, value in expected.items()):
        fail("PACKET_MANIFEST_MISMATCH", "packet authority or product binding differs")
    indices = packet.get("requestIndices")
    caps = profile["caps"]
    _validate_request_indices(indices, caps, args.request_index)
    if args.authority_issue == 535 and indices != [profile["roles"]["requestIndex"]["baseline"]]:
        fail("REQUEST_INDEX_MISMATCH", "qualification request index differs")


def _early_unknown_reads(statement: Mapping[str, Any], trace: Mapping[str, Any]) -> None:
    roots = statement.get("roots", {})
    if not isinstance(roots, dict): return
    roles = {record.get("path") for record in statement.get("roles", []) if isinstance(record, dict)}
    outputs = {record.get("path") for record in statement.get("outputs", {}).values()
               if isinstance(record, dict) and record.get("present")}
    for event in trace["events"]:
        if event["type"] != "READ" or not isinstance(event.get("path"), str): continue
        path = event["path"]
        if isinstance(roots.get("HOME"), str) and path.startswith(roots["HOME"] + "/") and path not in outputs:
            fail("UNDECLARED_CACHE_ACCESS", f"unknown cache read {path}")
        if any(isinstance(roots.get(key), str) and path.startswith(roots[key] + "/")
               for key in ("PRODUCT", "PACKET")) and path not in roles:
            fail("UNDECLARED_INPUT_PATH", f"unknown semantic read {path}")


def _nul(sidecar: bytes, offset: int, length: int, label: str) -> list[str]:
    raw = sidecar[offset:offset + length]
    if len(raw) != length or (raw and not raw.endswith(b"\0")): fail("PROVENANCE_INCOMPLETE", f"invalid {label}")
    try: return [item.decode() for item in raw.split(b"\0")[:-1]] if raw else []
    except UnicodeError: fail("PROVENANCE_INCOMPLETE", f"non-UTF-8 {label}")


def _exec(trace: Mapping[str, Any], sidecar: bytes, profile: Mapping[str, Any], roots: Mapping[str, str],
          runtime: Mapping[str, Mapping[str, Any]], argv: list[str], environment: list[str]) -> None:
    events = [event for event in trace["events"] if event["type"] == "EXEC"]
    values = {**roots, "EXTERNAL_SCRIPT": Path(argv[5]).name, "CORPUS": Path(argv[8]).name, "INDEX": argv[10]}
    expected = [("/usr/bin/env", [_expand(item, values) for item in profile["invocation"]["launcherArgvTemplate"]], [])]
    expected += [(roots["GODOT"], argv, environment)]
    expected += [(item["path"], item["argv"], environment) for item in profile["invocation"]["permittedDescendantExecs"]]
    if len(events) != len(expected): fail("PROCESS_LINEAGE_MISMATCH", "exec count differs")
    for event, (path, wanted_argv, wanted_env) in zip(events, expected):
        if _nul(sidecar, event["argvOffset"], event["argvLength"], "argv") != wanted_argv:
            fail("ARGV_MISMATCH", f"exec argv differs for {path}")
        if _nul(sidecar, event["envOffset"], event["envLength"], "environment") != wanted_env:
            fail("ENVIRONMENT_MISMATCH", f"exec environment differs for {path}")
        identity = runtime.get(path)
        if identity is None or (identity.get("device"), identity.get("inode")) != (event["device"], event["inode"]) or \
                event["path"] != str(Path(path).resolve()):
            fail("RUNTIME_DEPENDENCY_MISMATCH", f"exec identity differs for {path}")


def _lineage(trace: Mapping[str, Any], profile: Mapping[str, Any], diagnostic: bool) -> None:
    events, end, caps = trace["events"], trace["end"], profile["caps"]
    pipe_contract = profile["accessGrammar"]["internalPipe"]
    lines = [e for e in events if e["type"] == "LINEAGE"]; exits = [e for e in events if e["type"] == "EXIT"]
    tasks = {e["tid"] for e in events} | {e["childTid"] for e in lines}; kinds = [e["kind"] for e in lines]
    names = [e["name"] for e in events if e["type"] == "SYSCALL_E"]
    children = {e["childTid"] for e in lines}; roots = tasks - children
    exit_by_tid = {e["tid"]: e["status"] for e in exits}
    exit_valid = len(roots) == 1 and (list(roots)[0] in exit_by_tid) and \
        exit_by_tid[list(roots)[0]] == end["rootExit"] and all(
            status == 0 for tid, status in exit_by_tid.items() if tid not in roots)
    if not diagnostic: exit_valid = exit_valid and end["rootExit"] == 0
    if end["taskCount"] != caps["validTasks"] or len(tasks) != caps["validTasks"] or \
            len(lines) != caps["validLineageEvents"] or len(exits) != caps["validTasks"] or \
            len(exit_by_tid) != len(exits) or not exit_valid or kinds.count("clone_thread") != caps["validThreads"] or \
            sum(k.endswith("process") for k in kinds) + 1 != caps["validProcesses"] or \
            names.count("clone3") != caps["maxClone3"] or names.count("vfork") != caps["maxVfork"]:
        fail("PROCESS_LINEAGE_MISMATCH", "exact process/thread lineage differs")
    if names.count("pipe2") != pipe_contract["pipe2Count"] or \
            names.count("dup2") != pipe_contract["dup2Count"]:
        fail("PROCESS_LINEAGE_MISMATCH", "internal pipe syscall shape differs")


def _output_records(statement: Mapping[str, Any], case_dir: Path) -> dict[str, Mapping[str, Any]]:
    streams, outputs = statement.get("streams"), statement.get("outputs")
    if not isinstance(streams, dict) or not isinstance(outputs, dict): fail("PROVENANCE_INCOMPLETE", "outputs missing")
    result: dict[str, Mapping[str, Any]] = {}
    for name in ("observation", "homeLog", "sentry"):
        record = outputs.get(name)
        if not isinstance(record, dict): fail("PROVENANCE_INCOMPLETE", f"{name} missing")
        if record.get("present"): result[_absolute(record.get("path"), name)] = record
    return result


def _stream_bytes(events: Sequence[Mapping[str, Any]], fd: int, sidecar: bytes) -> bytes:
    result = bytearray()
    internal = _internal_pipe_paths(events)
    for event in events:
        if event["type"] == "WRITE" and event.get("fd") == fd and event.get("path") not in internal:
            count, offset = event["returned"], event["sidecarOffset"]
            data = sidecar[offset:offset + count]
            if len(data) != count: fail("PROVENANCE_INCOMPLETE", "stream sidecar range differs")
            result.extend(data)
    return bytes(result)


def _written(events: Sequence[Mapping[str, Any]], path: str, sidecar: bytes, size: int) -> bytes:
    output, covered = bytearray(size), bytearray(size)
    for event in events:
        if event["type"] != "WRITE" or event.get("path") != path: continue
        start, count = event["offset"], event["returned"]
        data = sidecar[event["sidecarOffset"]:event["sidecarOffset"] + count]
        if start < 0 or start + count > size or len(data) != count: fail("PROVENANCE_INCOMPLETE", "write range invalid")
        output[start:start + count] = data; covered[start:start + count] = b"\1" * count
    if any(byte == 0 for byte in covered): fail("OUTPUT_NOT_CURRENT", f"writes do not cover {path}")
    return bytes(output)


def _outputs(statement: Mapping[str, Any], trace: Mapping[str, Any], sidecar: bytes, case_dir: Path,
             challenge: str, profile: Mapping[str, Any]) -> None:
    case_id, streams, outputs = statement["caseId"], statement.get("streams", {}), statement.get("outputs", {})
    stderr = streams.get("stderr")
    if not isinstance(stderr, dict) or not (case_dir / "stderr.bin").is_file():
        fail("STDERR_CAPTURE_MISSING", "stderr capture missing")
    stderr_data = (case_dir / "stderr.bin").read_bytes()
    if len(stderr_data) != stderr.get("size") or _sha(stderr_data) != stderr.get("sha256"):
        fail("STDERR_CAPTURE_MISMATCH", "stderr bytes differ")
    if stderr.get("challenge") != challenge: fail("STDERR_INVOCATION_MISMATCH", "stderr challenge differs")
    if _stream_bytes(trace["events"], 2, sidecar) != stderr_data:
        fail("STDERR_CAPTURE_MISMATCH", "stderr captured writes differ")
    stdout = streams.get("stdout")
    if not isinstance(stdout, dict) or not (case_dir / "stdout.bin").is_file(): fail("OUTPUT_NOT_CURRENT", "stdout missing")
    stdout_data = (case_dir / "stdout.bin").read_bytes()
    if len(stdout_data) != stdout.get("size") or _sha(stdout_data) != stdout.get("sha256") or \
            stdout.get("challenge") != challenge or _stream_bytes(trace["events"], 1, sidecar) != stdout_data:
        fail("OUTPUT_NOT_CURRENT", "stdout differs")
    observation = outputs.get("observation", {})
    if case_id in {"G15", "G16", "G17", "G18"}:
        path = str(Path(statement["roots"]["OUTPUT"]) / "observation.json")
        denied = any(e["type"] == "PATH_X" and e["path"] == path and e["operation"] == "openat" and
                     e["returned"] == -13 for e in trace["events"])
        if not stderr_data or observation.get("present") or not denied:
            fail("OUTPUT_WRITE_DENIED", "observation open was not genuinely denied")
        return
    if observation.get("challenge") != challenge: fail("OUTPUT_NOT_CURRENT", "observation challenge differs")
    for path, record in _output_records(statement, case_dir).items():
        file_path = case_dir / record["file"]
        reason = "STDERR_CAPTURE_MISMATCH" if file_path.name == "stderr.bin" else "OUTPUT_NOT_CURRENT"
        try: data = file_path.read_bytes()
        except OSError as error: fail(reason, f"output copy unavailable: {error}")
        if len(data) != record.get("size") or _sha(data) != record.get("sha256"): fail(reason, "output copy differs")
        live_path = Path(path); live = live_path.stat()
        _live(record, reason)
        if record.get("challenge") != challenge or _written(trace["events"], path, sidecar, len(data)) != data:
            fail(reason, f"current output differs for {path}")
        if not any(e["type"] == "CLOSE" and e["path"] == path and
                   e["device"] == live.st_dev and e["inode"] == live.st_ino for e in trace["events"]):
            fail("OUTPUT_NOT_CURRENT", f"close missing for {path}")
        maximum = profile["caps"]["maxObservationBytes" if path.endswith("/observation.json") else "maxHomeOutputBytes"]
        if len(data) > maximum: fail("PROVENANCE_INCOMPLETE", f"output cap exceeded for {path}")
    if len((case_dir / "stdout.bin").read_bytes()) > profile["caps"]["maxStdoutBytes"] or \
            len(stderr_data) > profile["caps"]["maxStderrBytes"]: fail("PROVENANCE_INCOMPLETE", "stream cap exceeded")


def _objects(trace: Mapping[str, Any], roles: Mapping[str, Mapping[str, Any]], runtime: Mapping[str, Mapping[str, Any]],
             platform: Mapping[str, Mapping[str, Any]], outputs: Mapping[str, Mapping[str, Any]],
             role_bytes: Mapping[str, bytes], sidecar: bytes, roots: Mapping[str, str], profile: Mapping[str, Any]) -> None:
    objects: dict[str, Mapping[str, Any]] = {**roles, **platform, **outputs}
    for logical, record in runtime.items():
        resolved = str(Path(logical).resolve())
        if resolved in objects and objects[resolved] != record:
            fail("RUNTIME_DEPENDENCY_MISMATCH", f"ambiguous resolved identity {resolved}")
        objects[resolved] = record
    known = set(objects)
    grammar = profile["accessGrammar"]["paths"]
    reject_semantic_mappings([e for e in trace["events"] if e["type"] == "MMAP"], set(roles))
    pipe_contract = profile["accessGrammar"]["internalPipe"]
    expected_pipe_bytes = _expand(pipe_contract["payloadTemplate"], roots).encode()
    internal_pipes = _validate_internal_pipe(
        trace["events"], sidecar, expected_pipe_bytes, pipe_contract)
    for event in trace["events"]:
        if event["type"] not in {"OPEN", "CLOSE", "READ", "WRITE", "MMAP", "PATH_X"}: continue
        path = event.get("path")
        if not isinstance(path, str) or len(path.encode()) > profile["caps"]["maxPathBytes"]:
            fail("PROVENANCE_INCOMPLETE", "invalid observed path")
        if event["type"] == "PATH_X" and event.get("returned", -1) < 0: continue
        if event["type"] == "WRITE" and event.get("fd") in {1, 2} and path not in internal_pipes:
            if not _pipe_path(path) or event["classification"] != "I":
                fail("OUTPUT_NOT_CURRENT", "stream object grammar differs")
            continue
        if path in internal_pipes or (event["type"] == "CLOSE" and _pipe_path(path)):
            if event.get("classification") != "I":
                fail("PROCESS_LINEAGE_MISMATCH", "pipe classification differs")
            continue
        is_directory = isinstance(path, str) and any(item.startswith(path.rstrip("/") + "/") for item in known)
        named = any(fnmatch.fnmatch(path, pattern) for pattern in grammar["declaredDevicePaths"] + grammar["declaredProcPaths"])
        if path == "/dev/null" or is_directory or named:
            try: current = Path(path).stat()
            except OSError as error: fail("UNDECLARED_INPUT_PATH", f"named path unavailable: {error}")
            if event["type"] != "PATH_X" and (event.get("device"), event.get("inode")) != (current.st_dev, current.st_ino):
                fail("UNDECLARED_INPUT_PATH", f"named path identity differs {path}")
            if path == "/dev/null" and event["type"] == "OPEN" and event["flags"] & 0o3103 != 1:
                fail("OUTPUT_WRITE_DENIED", "unexpected /dev/null open mode")
            continue
        if path not in known:
            reason = "UNDECLARED_CACHE_ACCESS" if isinstance(path, str) and path.startswith(roots["HOME"] + "/") else "UNDECLARED_INPUT_PATH"
            fail(reason, f"unknown successful object {path}")
        record = objects[path]
        expected_class = "S" if path in roles else "W" if path in outputs else "I"
        if event["type"] != "PATH_X" and event.get("classification") != expected_class:
            fail("UNDECLARED_INPUT_PATH", f"object classification differs {path}")
        if event["type"] != "PATH_X" and (event.get("device"), event.get("inode")) != \
                (record.get("device"), record.get("inode")):
            fail("RUNTIME_DEPENDENCY_MISMATCH", f"device/inode differs for {path}")
        if event["type"] == "MMAP" and (event["offset"] + event["length"] > record["size"] or
                event["flags"] & 3 != 2 or (event["protection"] & 2 and event["flags"] & 1)):
            fail("RUNTIME_DEPENDENCY_MISMATCH", f"unsafe mapping for {path}")
    reads = [e for e in trace["events"] if e["type"] == "READ"]
    for path, data in role_bytes.items():
        validate_complete_role_reads([e for e in reads if e["path"] == path], data, sidecar)


def _network(trace: Mapping[str, Any], profile: Mapping[str, Any]) -> None:
    sockets = [e for e in trace["events"] if e["type"] == "SOCKET"]
    binds = [e for e in trace["events"] if e["type"] == "BIND"]
    if len(sockets) != profile["caps"]["allowedNetlinkSockets"] or len(binds) != profile["caps"]["allowedNetlinkBinds"] or \
            any(e["family"] != 16 or e["protocol"] != 15 or e["fd"] < 0 for e in sockets) or \
            any(e["family"] != 16 or e["returned"] != 0 for e in binds) or \
            sorted(e["fd"] for e in binds) != sorted(e["fd"] for e in sockets):
        fail("FORBIDDEN_NETWORK_FAMILY", "network differs from exact KOBJECT netlink use")


def _timing(statement: Mapping[str, Any], trace: Mapping[str, Any], profile: Mapping[str, Any]) -> None:
    timing, caps, case_id = statement.get("timing", {}), profile["caps"], statement["caseId"]
    required = ("supervisorStartNs", "supervisorFinishNs", "tracerStartNs", "tracerFinishNs")
    if not isinstance(timing, dict) or any(key not in timing for key in required):
        fail("EXTERNAL_TIMING_MISMATCH", "external timing missing")
    start, finish = integer(timing["supervisorStartNs"], "supervisor start"), integer(timing["supervisorFinishNs"], "supervisor finish")
    if timing["tracerStartNs"] != trace["startNs"] or timing["tracerFinishNs"] != trace["end"]["finishNs"] or \
            not start <= trace["startNs"] <= trace["end"]["finishNs"] <= finish:
        fail("EXTERNAL_TIMING_MISMATCH", "external interval does not enclose tracer")
    elapsed = finish - start
    if elapsed > caps["supervisorKillWallNs"]: fail("EXTERNAL_WALL_CAP_EXCEEDED", "kill cap exceeded")
    if case_id == "G23":
        if elapsed < caps["timingAttackMinimumNs"]: fail("EXTERNAL_TIMING_MISMATCH", "G23 delay absent")
        fail("EXTERNAL_WALL_CAP_EXCEEDED", "judgement cap exceeded")
    if elapsed > caps["judgementWallNs"]: fail("EXTERNAL_WALL_CAP_EXCEEDED", "judgement cap exceeded")


def _trusted_setup(statement: Mapping[str, Any], roots: Mapping[str, str], case_dir: Path) -> None:
    mounts = statement.get("mounts")
    if not isinstance(mounts, dict) or set(mounts) != {"product", "packet"}:
        fail("PROVENANCE_INCOMPLETE", "mount evidence differs")
    for name, root in (("product", "PRODUCT"), ("packet", "PACKET")):
        record = mounts[name]
        options = record.get("options", "") if isinstance(record, dict) else ""
        option_list = options.split(",") if isinstance(options, str) else options
        if not isinstance(record, dict) or record.get("target") != roots[root] or not record.get("writeRejected") or \
                not isinstance(option_list, list) or "ro" not in option_list or \
                not isinstance(record.get("source"), str):
            fail("PROVENANCE_INCOMPLETE", f"{name} read-only mount differs")
        try: read_only = bool(os.statvfs(roots[root]).f_flag & os.ST_RDONLY)
        except OSError as error: fail("PROVENANCE_INCOMPLETE", f"cannot inspect {name} mount: {error}")
        if not read_only: fail("PROVENANCE_INCOMPLETE", f"{name} live mount is writable")
    tracer = statement.get("tracer")
    _TRACE.validate_tracer_identity(
        tracer, Path(__file__).parent, case_dir.parent.parent / "workspace/godot-runtime-tracer")


def _complete(args: argparse.Namespace, profile: dict, g0: dict, packet: dict, statement: dict,
              trace: dict, sidecar: bytes) -> None:
    challenge = _read_challenge(args.challenge)
    if statement.get("schema") != STATEMENT_SCHEMA or statement.get("caseId") != args.case_id:
        fail("PROVENANCE_INCOMPLETE", "statement schema/case differs")
    if statement.get("challenge") != challenge or trace["challenge"] != challenge or statement.get("clock") != "CLOCK_MONOTONIC_RAW":
        fail("INVOCATION_CHALLENGE_MISMATCH", "fresh challenge differs")
    _authority(statement, packet, profile, args)
    roots = statement.get("roots")
    if not isinstance(roots, dict) or set(roots) != {"GODOT", "PRODUCT", "PACKET", "HOME", "OUTPUT"}:
        fail("PROVENANCE_INCOMPLETE", "root set differs")
    roots = {key: _absolute(value, key) for key, value in roots.items()}
    if len(set(roots.values())) != len(roots) or any(
            left.startswith(right.rstrip("/") + "/") or right.startswith(left.rstrip("/") + "/")
            for index, left in enumerate(roots.values()) for right in list(roots.values())[index + 1:]):
        fail("PROVENANCE_INCOMPLETE", "roots overlap")
    _trusted_setup(statement, roots, args.case_dir)
    members = [p for p in Path(roots["PACKET"]).iterdir() if p.is_file() or p.is_symlink()]
    if len(members) > profile["caps"]["maxPacketMembers"] or sum(p.stat().st_size for p in members) > profile["caps"]["maxPacketBytes"]:
        fail("PROVENANCE_INCOMPLETE", "packet cap exceeded")
    expected_roles, roles = _roles(g0, packet, roots, profile, args), _records(statement.get("roles"), "roles")
    if set(roles) != set(expected_roles):
        expected_script = next(path for path in expected_roles if path.startswith(roots["PACKET"] + "/") and path.endswith(".gd"))
        actual_packet = {path for path in roles if path.startswith(roots["PACKET"] + "/")}
        if expected_script not in actual_packet: fail("EXTERNAL_SCRIPT_PATH_MISMATCH", "external script path differs")
        expected_corpus = next(path for path in expected_roles if path.startswith(roots["PACKET"] + "/") and path.endswith(".json"))
        if expected_corpus not in actual_packet: fail("CORPUS_PATH_MISMATCH", "corpus path differs")
        fail("UNDECLARED_INPUT_PATH", "semantic paths differ")
    generated = {_expand(path, roots) for path in profile["roles"]["generatedGodotCache"]["paths"]}
    role_bytes: dict[str, bytes] = {}
    for path, expected in expected_roles.items():
        actual = roles[path]; reason = "GENERATED_CACHE_BYTES_MISMATCH" if path in generated else "PROJECT_SEMANTIC_BYTES_MISMATCH"
        if path.startswith(roots["PACKET"] + "/"): reason = "EXTERNAL_SCRIPT_BYTES_MISMATCH" if path.endswith(".gd") else "CORPUS_BYTES_MISMATCH"
        if any(actual.get(key) != expected.get(key) for key in ("path", "size", "sha256")): fail(reason, f"role differs {path}")
        role_bytes[path] = _live(actual, reason, True)
    executable = statement.get("executable", {})
    if executable.get("path") != roots["GODOT"] or executable.get("sha256") != profile["runtime"]["godotSha256"]:
        fail("GODOT_EXECUTABLE_MISMATCH", "Godot differs")
    _live(executable, "GODOT_EXECUTABLE_MISMATCH")
    expected_runtime = _identity_set(g0, roots, "runtimeIdentitySet")
    expected_platform = _identity_set(g0, roots, "platformObservationSet")
    if len(expected_roles) > profile["caps"]["maxSemanticFiles"] or \
            len(expected_runtime) > profile["caps"]["maxIdentityDependencies"] or \
            len(expected_platform) > profile["caps"]["maxPlatformObservations"] or \
            len(expected_roles) + len(expected_runtime) + len(expected_platform) > profile["caps"]["maxFileIdentities"]:
        fail("PROVENANCE_INCOMPLETE", "frozen identity cap exceeded")
    runtime = _records(statement.get("runtimeIdentities"), "runtime")
    if set(runtime) != set(expected_runtime): fail("RUNTIME_DEPENDENCY_MISMATCH", "runtime set differs")
    for path, expected in expected_runtime.items():
        if any(runtime[path].get(key) != expected.get(key) for key in ("path", "size", "sha256")): fail("RUNTIME_DEPENDENCY_MISMATCH", path)
        _live(runtime[path], "RUNTIME_DEPENDENCY_MISMATCH")
    platform = {path: _frozen_live(expected, roots, "UNDECLARED_CACHE_ACCESS")
                for path, expected in expected_platform.items()}
    values = {**roots, "EXTERNAL_SCRIPT": packet["roles"]["externalScript"]["path"],
              "CORPUS": packet["roles"]["corpus"]["path"], "INDEX": args.request_index}
    argv = [_expand(item, values) for item in profile["invocation"]["godotArgvTemplate"]]
    environment = [_expand(item, values) for item in profile["invocation"]["environment"]]
    if statement.get("argv") != argv:
        supplied = statement.get("argv")
        if isinstance(supplied, list) and "--index" in supplied and supplied[supplied.index("--index") + 1] != values["INDEX"]:
            fail("REQUEST_INDEX_MISMATCH", "index differs")
        fail("ARGV_MISMATCH", "Godot argv differs")
    if statement.get("environment") != environment: fail("ENVIRONMENT_MISMATCH", "environment differs")
    output_records = _output_records(statement, args.case_dir)
    diagnostic = statement["caseId"] in {"G15", "G16", "G17", "G18"}
    _exec(trace, sidecar, profile, roots, runtime, argv, environment); _lineage(trace, profile, diagnostic)
    _network(trace, profile); _timing(statement, trace, profile)
    read_paths = {event["path"] for event in trace["events"] if event["type"] == "READ"}
    if statement["caseId"] == "G19" and any(path not in read_paths for path in roles):
        fail("OUTPUT_NOT_CURRENT", "output replay lacks current semantic consumption")
    _outputs(statement, trace, sidecar, args.case_dir, challenge, profile)
    if (diagnostic and (statement["tracer"]["returncode"] != 40 or trace["end"]["rootExit"] == 0)) or \
            (not diagnostic and (statement["tracer"]["returncode"] != 0 or trace["end"]["rootExit"] != 0)):
        fail("PROVENANCE_INCOMPLETE", "tracer/root exit contract differs")
    _objects(trace, roles, runtime, platform, output_records, role_bytes, sidecar, roots, profile)
    if trace["end"]["dropped"] or trace["end"]["violation"] not in {"", "-"}:
        fail("PROVENANCE_INCOMPLETE", f"tracer violation {trace['end']['violation']}")


def verify_case(args: argparse.Namespace) -> dict[str, Any]:
    profile, g0, packet = _load_sources(args.profile, args.g0_manifest, args.packet_manifest)
    matrix = {case["id"]: (case["expectedVerdict"], case["expectedReason"]) for case in profile["cases"]}
    if args.case_id not in CASE_RESULTS or matrix.get(args.case_id) != CASE_RESULTS[args.case_id]: fail("PROVENANCE_INCOMPLETE", "matrix differs")
    statement = _json(args.case_dir / "statement.json"); trace_path = args.case_dir / "trace.tsv"; sidecar_path = args.case_dir / "sidecar.bin"
    case_size = sum(path.stat().st_size for path in args.case_dir.rglob("*") if path.is_file())
    try:
        if case_size > profile["caps"]["maxCasePacketBytes"]: fail("PROVENANCE_INCOMPLETE", "case cap exceeded")
        trace_bytes, sidecar = trace_path.read_bytes(), sidecar_path.read_bytes()
        for name, data, record in (("trace", trace_bytes, statement.get("trace")),
                                   ("sidecar", sidecar, statement.get("sidecar"))):
            if not isinstance(record, dict) or record.get("file") != f"{name}.{'tsv' if name == 'trace' else 'bin'}" or \
                    record.get("size") != len(data) or record.get("sha256") != _sha(data):
                fail("PROVENANCE_INCOMPLETE", f"{name} binding differs")
        trace = parse_trace_lines(trace_bytes.decode().splitlines(), profile["caps"]["maxEvents"])
        _early_unknown_reads(statement, trace)
        validate_trace_accounting(trace, profile["caps"], len(trace_bytes), len(sidecar))
        validate_syscall_grammar(trace, profile["accessGrammar"]["allowedSyscalls"])
        _complete(args, profile, g0, packet, statement, trace, sidecar); outcome = ("PASS", "ADMITTED")
    except (OSError, UnicodeError): outcome = ("INCONCLUSIVE", "PROVENANCE_INCOMPLETE")
    except VerificationFailure as error: outcome = ("INCONCLUSIVE" if error.reason == "PROVENANCE_INCOMPLETE" else "REJECT", error.reason)
    tracer = statement.get("tracer", {})
    receipt = {"schema": RECEIPT_SCHEMA, "caseId": args.case_id, "challenge": _read_challenge(args.challenge),
               "verdict": outcome[0], "reason": outcome[1], "profileSha256": _file_sha(args.profile),
               "g0ManifestSha256": _file_sha(args.g0_manifest), "packetManifestSha256": _file_sha(args.packet_manifest),
               "verifierSha256": _file_sha(Path(__file__)), "traceVerifierSha256": _file_sha(_HELPER_PATH),
               "tracerIdentitySha256": _sha(_canonical(tracer)), "ioHeaderSha256": tracer.get("ioHeaderSha256")}
    receipt["receiptSha256"] = _sha(_canonical(receipt)); return receipt


def _read_challenge(path: Path) -> str:
    try: value = path.read_text(encoding="ascii").rstrip("\n")
    except (OSError, UnicodeError) as error: fail("INVOCATION_CHALLENGE_MISMATCH", str(error))
    if len(value) != 64 or any(char not in "0123456789abcdef" for char in value): fail("INVOCATION_CHALLENGE_MISMATCH", "bad challenge")
    return value


def _exclusive(path: Path, data: bytes) -> None:
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try: os.write(fd, data)
    finally: os.close(fd)


def _challenge(args: argparse.Namespace) -> int:
    value = secrets.token_hex(32); _exclusive(args.output, (value + "\n").encode()); print(value); return 0


def _case(args: argparse.Namespace) -> int:
    if args.case_id is None: args.case_id = args.case_dir.name
    if args.case_id not in CASE_RESULTS: fail("PROVENANCE_INCOMPLETE", "unknown case directory")
    receipt = verify_case(args); _exclusive(args.receipt_out, _canonical(receipt)); print(json.dumps(receipt, sort_keys=True))
    return 0 if (receipt["verdict"], receipt["reason"]) == CASE_RESULTS[args.case_id] else 1


def _campaign(args: argparse.Namespace) -> int:
    profile, _, _ = _load_sources(args.profile, args.g0_manifest, args.packet_manifest)
    total = sum(path.stat().st_size for path in args.campaign_dir.rglob("*") if path.is_file())
    if total > profile["caps"]["maxCampaignBytes"]: fail("PROVENANCE_INCOMPLETE", "campaign cap exceeded")
    receipts = []
    for case in profile["cases"]:
        current = argparse.Namespace(**vars(args)); current.case_id = case["id"]; current.case_dir = args.campaign_dir / case["id"]
        current.challenge = args.challenges_dir / f"{case['id']}.txt"; receipts.append(verify_case(current))
    passed = all((item["verdict"], item["reason"]) == CASE_RESULTS[item["caseId"]] for item in receipts)
    result = {"schema": CAMPAIGN_SCHEMA, "verdict": "PASS" if passed else "FAIL", "receipts": receipts}
    result["receiptSha256"] = _sha(_canonical(result)); _exclusive(args.receipt_out, _canonical(result)); print(json.dumps(result, sort_keys=True))
    return 0 if passed else 1


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__); commands = parser.add_subparsers(dest="command", required=True)
    challenge = commands.add_parser("challenge"); challenge.add_argument("--output", type=Path, required=True); challenge.set_defaults(function=_challenge)
    common = argparse.ArgumentParser(add_help=False)
    for option, destination in (("profile", "profile"), ("g0-manifest", "g0_manifest"), ("packet-manifest", "packet_manifest"), ("receipt-out", "receipt_out")):
        common.add_argument("--" + option, dest=destination, type=Path, required=True)
    for option in ("observer-sha", "product-sha", "packet-sha", "packet-root"):
        common.add_argument("--" + option, dest=option.replace("-", "_"), required=True)
    common.add_argument("--request-index", required=True)
    common.add_argument("--authority-issue", type=int, required=True); common.add_argument("--authority-comment", type=int, required=True)
    case = commands.add_parser("case", parents=[common]); case.add_argument("--case-id", choices=CASE_RESULTS)
    case.add_argument("--case-dir", type=Path, required=True); case.add_argument("--challenge", type=Path, required=True); case.set_defaults(function=_case)
    campaign = commands.add_parser("campaign", parents=[common]); campaign.add_argument("--campaign-dir", type=Path, required=True)
    campaign.add_argument("--challenges-dir", type=Path, required=True); campaign.set_defaults(function=_campaign)
    args = parser.parse_args(argv)
    try: return args.function(args)
    except (VerificationFailure, OSError, KeyError, ValueError) as error: print(str(error), file=sys.stderr); return 2


if __name__ == "__main__": raise SystemExit(main())
