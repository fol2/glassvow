#!/usr/bin/env python3
"""Independent verifier for the frozen actual-Godot provenance profile."""
from __future__ import annotations
import argparse, hashlib, importlib.util, json, os, posixpath, re, secrets, stat, subprocess, sys, tempfile
from pathlib import Path
from typing import Any, Mapping, Sequence

_HELPER_PATH = Path(__file__).with_name("godot_runtime_trace_verify.py")
OBSERVER_ROOT = Path(__file__).resolve().parents[2]
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
G0_PATH_OPERATION_SCHEMA = "glassvow.godot-runtime-provenance.g0-path-operations/v1"
PACKET_SCHEMA = "glassvow.godot-runtime-packet/v1"
STATEMENT_SCHEMA = "glassvow.godot-runtime-provenance.statement/v1"
RECEIPT_SCHEMA = "glassvow.godot-runtime-provenance.receipt/v1"
CAMPAIGN_SCHEMA = "glassvow.godot-runtime-provenance.campaign-receipt/v1"
PRODUCT_STAGE_SCHEMA = "glassvow.godot-runtime-product-stage/v1"
CONFIGURATION_MANIFEST_PATH = Path(__file__).with_name(
    "godot_runtime_configuration_manifest.json")
CONFIGURATION_ROOT = Path(__file__).with_name("godot_runtime_configuration")
# Bound to the independently reviewed profile before any qualification case.
FROZEN_PROFILE_SHA256 = "96a6588e18cb6af9f20c6ea0b2c39e4aa300172ce7e3ece2169702407564d6c2"
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
_HARD_FILE_CAPS = {
    "maxStatementBytes": 4 * 1024 * 1024,
    "maxCaseReceiptBytes": 4 * 1024 * 1024,
    "maxChallengeBytes": 65,
    "maxProfileBytes": 1024 * 1024,
    "maxG0ManifestBytes": 4 * 1024 * 1024,
    "maxPacketManifestBytes": 64 * 1024,
    "maxTraceBytes": 64 * 1024 * 1024,
    "maxCapturedBytes": 32 * 1024 * 1024,
    "maxStdoutBytes": 4096,
    "maxStderrBytes": 4096,
    "maxObservationBytes": 64 * 1024,
    "maxHomeOutputBytes": 4096,
    "maxAdmissionPolicyBytes": 384 * 1024,
}
_CASE_MEMBER_LIMITS = {
    "statement.json": "maxStatementBytes", "trace.tsv": "maxTraceBytes",
    "sidecar.bin": "maxCapturedBytes", "stdout.bin": "maxStdoutBytes",
    "stderr.bin": "maxStderrBytes", "observation.json": "maxObservationBytes",
    "home-godot.log": "maxHomeOutputBytes", "home-sentry.dat": "maxHomeOutputBytes",
    "admission-policy.tsv": "maxAdmissionPolicyBytes",
    "receipt.json": "maxCaseReceiptBytes", "receipt-replay.json": "maxCaseReceiptBytes",
}
_SENTRY_OUTPUT = re.compile(
    rb'\[main\]\n\ninstallation_id="[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-'
    rb'[89ab][0-9a-f]{3}-[0-9a-f]{12}"\n')


def _sha(data: bytes) -> str: return hashlib.sha256(data).hexdigest()


def _valid_sentry_output(data: bytes, contract: Mapping[str, Any]) -> bool:
    return contract.get("format") == "sentry-ini-installation-uuid-v4-lowercase" and \
        len(data) == contract.get("size") and _SENTRY_OUTPUT.fullmatch(data) is not None


def _file_sha(path: Path) -> str:
    digest = hashlib.sha256()
    try:
        with path.open("rb") as handle:
            for block in iter(lambda: handle.read(1024 * 1024), b""): digest.update(block)
    except OSError as error: fail("PROVENANCE_INCOMPLETE", f"cannot hash {path}: {error}")
    return digest.hexdigest()


def _checked(command: Sequence[str], *, environment: Mapping[str, str] | None = None,
             timeout: float = 120) -> bytes:
    try:
        result = subprocess.run(
            list(command), check=False, capture_output=True,
            env=None if environment is None else dict(environment), timeout=timeout)
    except (OSError, subprocess.SubprocessError) as error:
        fail("PROVENANCE_INCOMPLETE", f"trusted command unavailable: {error}")
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).decode(errors="replace").strip()
        fail("PROVENANCE_INCOMPLETE", f"trusted command failed: {detail}")
    return result.stdout


def _canonical(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()


def _limit(caps: Mapping[str, Any], name: str) -> int:
    hard = _HARD_FILE_CAPS[name]
    value = caps.get(name)
    return value if isinstance(value, int) and 0 < value <= hard else hard


def _bounded_bytes(
        path: Path, maximum: int, reason: str = "PROVENANCE_INCOMPLETE") -> bytes:
    flags = os.O_RDONLY | getattr(os, "O_CLOEXEC", 0) | \
        getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_NONBLOCK", 0)
    try: descriptor = os.open(path, flags)
    except OSError as error: fail(reason, f"cannot open bounded {path.name}: {error}")
    try:
        before = os.fstat(descriptor)
        if not stat.S_ISREG(before.st_mode) or before.st_size > maximum:
            fail(reason, f"{path.name} is non-regular or exceeds its cap")
        blocks: list[bytes] = []; count = 0
        while True:
            block = os.read(descriptor, min(1024 * 1024, maximum + 1 - count))
            if not block: break
            blocks.append(block); count += len(block)
            if count > maximum: fail(reason, f"{path.name} exceeds its cap")
        after = os.fstat(descriptor)
        if (before.st_dev, before.st_ino, before.st_size) != \
                (after.st_dev, after.st_ino, after.st_size) or count != after.st_size:
            fail(reason, f"{path.name} changed during bounded read")
        return b"".join(blocks)
    finally:
        os.close(descriptor)


def _json_bytes(data: bytes, path: Path, reason: str = "PROVENANCE_INCOMPLETE") -> dict[str, Any]:
    try: value = json.loads(data.decode("utf-8"))
    except (UnicodeError, json.JSONDecodeError) as error:
        fail(reason, f"cannot read {path.name}: {error}")
    if not isinstance(value, dict): fail(reason, f"{path.name} is not an object")
    return value


def _preflight_case_members(
        case_dir: Path, caps: Mapping[str, Any]) -> tuple[dict[str, bytes], int]:
    members: dict[str, bytes] = {}; total = 0
    maximum_members = caps.get("maxCaseMembers")
    if not isinstance(maximum_members, int) or not 1 <= maximum_members <= len(_CASE_MEMBER_LIMITS):
        fail("PROVENANCE_INCOMPLETE", "invalid case member cap")
    try:
        root = case_dir.lstat()
        if not stat.S_ISDIR(root.st_mode) or stat.S_ISLNK(root.st_mode):
            fail("PROVENANCE_INCOMPLETE", "case root must be a direct non-symlink directory")
        with os.scandir(case_dir) as entries:
            for entry in entries:
                if len(members) >= maximum_members or entry.name not in _CASE_MEMBER_LIMITS:
                    fail("PROVENANCE_INCOMPLETE", "case member grammar or count differs")
                metadata = entry.stat(follow_symlinks=False)
                if not stat.S_ISREG(metadata.st_mode):
                    fail("PROVENANCE_INCOMPLETE", "case member must be regular and non-symlink")
                maximum = _limit(caps, _CASE_MEMBER_LIMITS[entry.name])
                if metadata.st_size > maximum:
                    fail("PROVENANCE_INCOMPLETE", f"{entry.name} exceeds its cap")
                data = _bounded_bytes(Path(entry.path), maximum)
                total += len(data)
                if total > caps.get("maxCasePacketBytes", 0):
                    fail("PROVENANCE_INCOMPLETE", "case cap exceeded")
                members[entry.name] = data
    except OSError as error:
        fail("PROVENANCE_INCOMPLETE", f"case directory unavailable: {error}")
    if not {"statement.json", "trace.tsv", "sidecar.bin", "stdout.bin",
            "admission-policy.tsv"}.issubset(members):
        fail("PROVENANCE_INCOMPLETE", "case core member set differs")
    return members, total


def _expand(template: str, roots: Mapping[str, str]) -> str:
    result = template
    for key, value in roots.items(): result = result.replace("${" + key + "}", value)
    if "${" in result: fail("PROVENANCE_INCOMPLETE", f"unresolved template {template}")
    return result


_PATH_OPERATIONS = {
    "access", "chdir", "execve", "faccessat2", "lstat", "mkdir",
    "newfstatat", "openat", "readlink", "readlinkat", "stat", "statx",
}


def _value_sha(value: Any) -> str:
    return _sha(json.dumps(value, sort_keys=True, separators=(",", ":")).encode())


def _validate_g0_path_operation_closure(
        profile: Mapping[str, Any], manifest: Mapping[str, Any]) -> dict[str, Any]:
    closure = manifest.get("pathOperationClosure")
    binding = profile.get("g0", {}).get("pathOperationClosure")
    fields = {"schema", "source", "traceMembers", "traceSetCanonicalSha256",
              "records", "recordsCanonicalSha256", "eventCount", "recordCount",
              "uniqueOperationPathPairs", "symlinkTargets",
              "symlinkTargetsCanonicalSha256", "symlinkCount"}
    if not isinstance(closure, dict) or set(closure) != fields or \
            closure.get("schema") != G0_PATH_OPERATION_SCHEMA or \
            not isinstance(binding, dict):
        fail("MANIFEST_MISMATCH", "G0 path-operation closure schema differs")
    source = closure.get("source")
    manifest_source = manifest.get("source", {})
    source_fields = {"run", "artifactId", "artifactSha256", "observerHead",
                     "initialWorkingDirectory", "roots"}
    if not isinstance(source, dict) or set(source) != source_fields or any(
            source.get(key) != manifest_source.get(key)
            for key in ("run", "artifactId", "artifactSha256", "observerHead")):
        fail("MANIFEST_MISMATCH", "G0 path-operation source differs")
    roots, working = source.get("roots"), source.get("initialWorkingDirectory")
    if not isinstance(roots, dict) or set(roots) != {
            "GODOT", "PRODUCT", "PACKET", "HOME", "OUTPUT"} or any(
                not isinstance(path, str) or not path.startswith("/")
                or posixpath.normpath(path) != path for path in roots.values()) or \
            not isinstance(working, str) or not working.startswith("/") \
            or posixpath.normpath(working) != working:
        fail("MANIFEST_MISMATCH", "G0 path-operation root binding differs")
    members = closure.get("traceMembers")
    if not isinstance(members, list) or not members or members != sorted(
            members, key=lambda item: item.get("name", "")):
        fail("MANIFEST_MISMATCH", "G0 trace-member order differs")
    seen_members: set[str] = set()
    for member in members:
        valid = isinstance(member, dict) and set(member) == {"name", "size", "sha256"}
        name = member.get("name") if valid else None
        if not valid or not isinstance(name, str) or not re.fullmatch(r"trace\.[0-9]+", name) \
                or name in seen_members or not isinstance(member.get("size"), int) \
                or member["size"] <= 0 or not re.fullmatch(
                    r"[0-9a-f]{64}", str(member.get("sha256", ""))):
            fail("MANIFEST_MISMATCH", "G0 trace-member binding differs")
        seen_members.add(name)
    if _value_sha(members) != closure.get("traceSetCanonicalSha256"):
        fail("MANIFEST_MISMATCH", "G0 trace-set digest differs")
    records = closure.get("records")
    if not isinstance(records, list) or not records:
        fail("MANIFEST_MISMATCH", "G0 path-operation records are missing")
    triples: set[tuple[str, str, int | None]] = set()
    closure_operations: dict[str, set[str]] = {}
    identities = {str(item["path"]): item
                  for group in ("semanticReadSet", "runtimeIdentitySet",
                                "platformObservationSet")
                  for item in manifest.get(group, [])}
    for item in records:
        if not isinstance(item, dict) or set(item) != {
                "operation", "path", "parameter", "returns", "count"}:
            fail("MANIFEST_MISMATCH", "G0 path-operation record fields differ")
        operation, path, parameter = item["operation"], item["path"], item["parameter"]
        returns, count = item["returns"], item["count"]
        logical = isinstance(path, str) and (
            path.startswith("/") and posixpath.normpath(path) == path
            or re.fullmatch(r"\$\{(?:GODOT|PRODUCT|PACKET|HOME|OUTPUT)\}(?:/.*)?", path)
            is not None)
        parameter_ok = (operation in {"openat", "mkdir"}
                        and isinstance(parameter, int) and parameter >= 0) or \
            (operation not in {"openat", "mkdir"} and parameter is None)
        if operation not in _PATH_OPERATIONS or not logical or not parameter_ok \
                or not isinstance(returns, list) or not returns \
                or returns != sorted(set(returns)) \
                or any(not isinstance(value, int) for value in returns) \
                or not isinstance(count, int) or count <= 0 \
                or (operation, path, parameter) in triples:
            fail("MANIFEST_MISMATCH", "G0 path-operation record differs")
        triples.add((operation, path, parameter))
        if path in identities:
            closure_operations.setdefault(path, set()).add(operation)
    ordered = sorted(records, key=lambda item: (
        item["operation"], item["path"],
        -1 if item["parameter"] is None else item["parameter"]))
    if ordered != records or _value_sha(records) != closure.get("recordsCanonicalSha256") \
            or closure.get("eventCount") != sum(item["count"] for item in records) \
            or closure.get("recordCount") != len(records) \
            or closure.get("uniqueOperationPathPairs") != len({
                (item["operation"], item["path"]) for item in records}):
        fail("MANIFEST_MISMATCH", "G0 path-operation accounting differs")
    symlinks = closure.get("symlinkTargets")
    if not isinstance(symlinks, list) or symlinks != sorted(
            symlinks, key=lambda item: item.get("path", "")):
        fail("MANIFEST_MISMATCH", "G0 symlink-target order differs")
    link_paths: set[str] = set()
    for link in symlinks:
        path, target = (link.get("path"), link.get("target")) \
            if isinstance(link, dict) else (None, None)
        valid_path = lambda value: isinstance(value, str) and (
            value.startswith("/") and posixpath.normpath(value) == value
            or re.fullmatch(
                r"\$\{(?:GODOT|PRODUCT|PACKET|HOME|OUTPUT)\}(?:/.*)?", value)
            is not None)
        if not isinstance(link, dict) or set(link) != {"path", "target"} \
                or not valid_path(path) or not valid_path(target) or path == target \
                or path in link_paths:
            fail("MANIFEST_MISMATCH", "G0 symlink-target record differs")
        link_paths.add(path)
    observed_links = {item["path"] for item in records
                      if item["operation"] in {"readlink", "readlinkat"}
                      and any(value >= 0 for value in item["returns"])}
    observed_links.discard("${GODOT}")
    if link_paths != observed_links or closure.get("symlinkCount") != len(symlinks) \
            or _value_sha(symlinks) != closure.get("symlinkTargetsCanonicalSha256"):
        fail("MANIFEST_MISMATCH", "G0 symlink-target accounting differs")
    for path, identity in identities.items():
        if set(identity.get("operations", [])) & _PATH_OPERATIONS != \
                closure_operations.get(path, set()):
            fail("MANIFEST_MISMATCH", f"G0 identity operations differ: {path}")
    expected = {
        "schema": closure["schema"],
        "traceSetCanonicalSha256": closure["traceSetCanonicalSha256"],
        "recordsCanonicalSha256": closure["recordsCanonicalSha256"],
        "traceFiles": len(members),
        "traceBytes": sum(member["size"] for member in members),
        "eventCount": closure["eventCount"],
        "recordCount": closure["recordCount"],
        "uniqueOperationPathPairs": closure["uniqueOperationPathPairs"],
        "symlinkTargetsCanonicalSha256": closure["symlinkTargetsCanonicalSha256"],
        "symlinkCount": closure["symlinkCount"],
    }
    if binding != expected:
        fail("PROFILE_MISMATCH", "G0 path-operation profile binding differs")
    return closure


def _build_admission_policy(
        profile: Mapping[str, Any], manifest: Mapping[str, Any],
        roots: Mapping[str, str], working_directory: Path) -> tuple[bytes, dict[str, int]]:
    closure = _validate_g0_path_operation_closure(profile, manifest)
    translations = profile["accessGrammar"]["paths"].get("pathResultPolicy", {})
    mkdir_translation = translations.get("existingHomeAncestorMkdir", {})
    if mkdir_translation != {
            "operation": "mkdir", "parameter": 509, "returned": -17}:
        fail("PROFILE_MISMATCH", "HOME-ancestor mkdir translation differs")
    files: dict[str, set[str]] = {}
    paths: set[tuple[str, str, int | None]] = set()

    def canonical_path(value: str) -> str:
        if not value.startswith("/") or "\0" in value:
            fail("PROVENANCE_INCOMPLETE", "invalid admission pathname rule")
        return posixpath.normpath(value)

    def add_path(operation: str, path: str, parameter: int | None = None) -> None:
        if operation not in _PATH_OPERATIONS or not path.startswith("/") or "\0" in path:
            fail("PROVENANCE_INCOMPLETE", "invalid admission pathname rule")
        paths.add((canonical_path(path), operation, parameter))

    for section in ("semanticReadSet", "runtimeIdentitySet", "platformObservationSet"):
        for record in manifest[section]:
            path = canonical_path(_expand(str(record["path"]), roots))
            files.setdefault(path, set()).add("R")

    for record in closure["records"]:
        add_path(
            str(record["operation"]), _expand(str(record["path"]), roots),
            record["parameter"])

    for template in profile["kernelAdmission"]["executeLeaves"]:
        path = canonical_path(_expand(template, roots))
        if path not in files:
            fail("PROVENANCE_INCOMPLETE", f"execute leaf is not frozen: {path}")
        files[path].add("X")
    for template in profile["kernelAdmission"]["kernelInterpreterLeaves"]:
        path = canonical_path(_expand(template, roots))
        if path not in files:
            fail("PROVENANCE_INCOMPLETE", f"kernel interpreter is not frozen: {path}")
        files[path].add("X")

    for root in roots.values():
        candidate = Path(root).parent
        while str(candidate) != candidate.parent.as_posix():
            add_path("readlink", str(candidate)); candidate = candidate.parent
        add_path("readlink", str(candidate))
    home_ancestor = Path(roots["HOME"]).parent
    while home_ancestor != home_ancestor.parent:
        add_path(
            mkdir_translation["operation"], str(home_ancestor),
            mkdir_translation["parameter"])
        home_ancestor = home_ancestor.parent

    if len(files) > profile["caps"]["maxAdmissionFileRules"] or \
            len(paths) > profile["caps"]["maxAdmissionPathRules"]:
        fail("PROVENANCE_INCOMPLETE", "admission policy rule cap exceeded")
    lines = [
        f"F\t{''.join(sorted(rights))}\t{path.encode().hex()}"
        for path, rights in files.items()
    ] + [
        f"P\t{operation}\t{'-' if parameter is None else parameter}\t{path.encode().hex()}"
        for path, operation, parameter in paths
    ]
    lines.sort()
    data = ("GODOTACCESSv1\n" + "\n".join(lines) + "\n").encode("ascii")
    if len(data) > profile["caps"]["maxAdmissionPolicyBytes"]:
        fail("PROVENANCE_INCOMPLETE", "admission policy byte cap exceeded")
    return data, {"fileRules": len(files), "pathRules": len(paths)}


def _packet_members(
        packet: Path, manifest_path: Path,
        profile: Mapping[str, Any]) -> dict[str, Path]:
    if Path(os.path.abspath(manifest_path.parent)) != Path(os.path.abspath(packet)) or \
            manifest_path.name != "manifest.json":
        fail("PROVENANCE_INCOMPLETE", "packet manifest path differs")
    caps = profile["caps"]
    members: dict[str, Path] = {}
    total = 0
    try:
        root = packet.lstat()
        if not stat.S_ISDIR(root.st_mode) or stat.S_ISLNK(root.st_mode):
            fail("PROVENANCE_INCOMPLETE", "packet root must be a direct non-symlink directory")
        with os.scandir(packet) as entries:
            for entry in entries:
                if len(members) >= caps["maxPacketMembers"]:
                    fail("PROVENANCE_INCOMPLETE", "packet member cap exceeded")
                metadata = entry.stat(follow_symlinks=False)
                if not stat.S_ISREG(metadata.st_mode):
                    fail("PROVENANCE_INCOMPLETE", "packet member must be regular and non-symlink")
                total += metadata.st_size
                if total > caps["maxPacketBytes"]:
                    fail("PROVENANCE_INCOMPLETE", "packet byte cap exceeded")
                members[entry.name] = Path(entry.path)
    except OSError as error:
        fail("PROVENANCE_INCOMPLETE", f"packet directory unavailable: {error}")
    if len(members) != 3 or "manifest.json" not in members:
        fail("PROVENANCE_INCOMPLETE", "packet must contain exactly three direct members")
    try:
        manifest_size = members["manifest.json"].stat().st_size
    except OSError as error:
        fail("PROVENANCE_INCOMPLETE", f"packet manifest unavailable: {error}")
    if manifest_size > caps["maxPacketManifestBytes"]:
        fail("PROVENANCE_INCOMPLETE", "packet manifest cap exceeded")
    return members


def _load_sources(
        profile_path: Path, g0_path: Path, packet_path: Path,
        cache: dict[str, bytes] | None = None) -> tuple[dict, dict, dict]:
    source_bytes = cache if cache is not None else {}
    if "profile" not in source_bytes:
        source_bytes["profile"] = _bounded_bytes(
            profile_path, _HARD_FILE_CAPS["maxProfileBytes"], "PROFILE_MISMATCH")
    if _sha(source_bytes["profile"]) != FROZEN_PROFILE_SHA256:
        fail("PROFILE_MISMATCH", "profile bytes differ")
    profile = _json_bytes(source_bytes["profile"], profile_path, "PROFILE_MISMATCH")
    if profile.get("schema") != PROFILE_SCHEMA: fail("PROFILE_MISMATCH", "profile schema differs")
    if "g0Manifest" not in source_bytes:
        source_bytes["g0Manifest"] = _bounded_bytes(
            g0_path, _limit(profile["caps"], "maxG0ManifestBytes"), "MANIFEST_MISMATCH")
    g0 = _json_bytes(source_bytes["g0Manifest"], g0_path, "MANIFEST_MISMATCH")
    if g0.get("schema") != G0_SCHEMA or _sha(source_bytes["g0Manifest"]) != \
            profile.get("g0", {}).get("manifest", {}).get("sha256"):
        fail("MANIFEST_MISMATCH", "G0 manifest bytes differ")
    _validate_g0_path_operation_closure(profile, g0)
    members = _packet_members(packet_path.parent, packet_path, profile)
    if "packetManifest" not in source_bytes:
        source_bytes["packetManifest"] = _bounded_bytes(
            members["manifest.json"], _limit(profile["caps"], "maxPacketManifestBytes"))
    packet = _json_bytes(source_bytes["packetManifest"], packet_path)
    if packet.get("schema") != PACKET_SCHEMA or set(packet) != {"schema", "productSha", "packetRoot", "authorityIssue", "authorityComment", "requestIndices", "roles"}:
        fail("PACKET_MANIFEST_MISMATCH", "packet schema or fields differ")
    roles = packet.get("roles")
    role_names = {record.get("path") for record in roles.values()} \
        if isinstance(roles, dict) and all(isinstance(record, dict) for record in roles.values()) else set()
    if set(members) != {"manifest.json", *role_names}:
        fail("PROVENANCE_INCOMPLETE", "packet direct member set differs")
    return profile, g0, packet

def _absolute(value: Any, label: str) -> str:
    if not isinstance(value, str) or not value.startswith("/") or ".." in Path(value).parts:
        fail("PROVENANCE_INCOMPLETE", f"invalid {label}")
    return value


def _live(
        record: Mapping[str, Any], reason: str, maximum: int,
        no_symlink: bool = False) -> bytes:
    path = Path(_absolute(record.get("path"), "identity path"))
    expected_size = record.get("size")
    if not isinstance(expected_size, int) or not 0 <= expected_size <= maximum:
        fail(reason, f"identity size exceeds cap for {path}")
    descriptor = -1
    try:
        logical_before = path.lstat()
        if no_symlink and stat.S_ISLNK(logical_before.st_mode):
            fail(reason, f"symlink role {path}")
        target = path if no_symlink else path.resolve(strict=True)
        descriptor = os.open(
            target, os.O_RDONLY | getattr(os, "O_CLOEXEC", 0) |
            getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_NONBLOCK", 0))
        before = os.fstat(descriptor)
        if not stat.S_ISREG(before.st_mode) or \
                (before.st_size, before.st_dev, before.st_ino) != \
                (expected_size, record.get("device"), record.get("inode")):
            fail(reason, f"current identity differs for {path}")
        blocks: list[bytes] = []; count = 0
        while True:
            block = os.read(descriptor, min(1024 * 1024, maximum + 1 - count))
            if not block: break
            blocks.append(block); count += len(block)
            if count > maximum: fail(reason, f"identity exceeds cap for {path}")
        after = os.fstat(descriptor)
        logical_after = path.lstat()
        if (before.st_dev, before.st_ino, before.st_size) != \
                (after.st_dev, after.st_ino, after.st_size) or \
                (logical_before.st_dev, logical_before.st_ino, logical_before.st_size,
                 logical_before.st_mode) != \
                (logical_after.st_dev, logical_after.st_ino, logical_after.st_size,
                 logical_after.st_mode) or \
                (not no_symlink and path.resolve(strict=True) != target) or count != expected_size:
            fail(reason, f"identity changed during bounded read for {path}")
    except OSError as error: fail(reason, f"identity unavailable {path}: {error}")
    finally:
        if descriptor >= 0: os.close(descriptor)
    data = b"".join(blocks)
    if _sha(data) != record.get("sha256"):
        fail(reason, f"current identity differs for {path}")
    return data


def _platform_live(
        record: Mapping[str, Any], roots: Mapping[str, str],
        maximum: int) -> tuple[str, dict[str, Any], bytes]:
    path = Path(_expand(str(record.get("path")), roots))
    descriptor = -1
    try:
        descriptor = os.open(
            path, os.O_RDONLY | getattr(os, "O_CLOEXEC", 0) |
            getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_NONBLOCK", 0))
        before = os.fstat(descriptor)
        if not stat.S_ISREG(before.st_mode) or before.st_size > maximum:
            fail("UNDECLARED_INPUT_PATH", f"platform object is not regular: {path}")
        blocks: list[bytes] = []; count = 0
        while True:
            block = os.read(descriptor, min(4096, maximum + 1 - count))
            if not block: break
            blocks.append(block); count += len(block)
            if count > maximum:
                fail("UNDECLARED_INPUT_PATH", f"platform object exceeds cap: {path}")
        after = os.fstat(descriptor)
    except OSError as error:
        fail("UNDECLARED_INPUT_PATH", f"platform object unavailable {path}: {error}")
    finally:
        if descriptor >= 0: os.close(descriptor)
    if (before.st_dev, before.st_ino, before.st_mode, before.st_size) != \
            (after.st_dev, after.st_ino, after.st_mode, after.st_size):
        fail("UNDECLARED_INPUT_PATH", f"platform object changed during read: {path}")
    data = b"".join(blocks)
    normalisation = record.get("contentNormalisation")
    if normalisation is None:
        if before.st_size != record.get("size") or _sha(data) != record.get("sha256"):
            fail("UNDECLARED_INPUT_PATH", f"platform object bytes differ: {path}")
    elif normalisation == "udev-initialisation-usec-decimal-v1":
        member_cap = record.get("maximumBytes")
        if not isinstance(member_cap, int) or not 1 <= member_cap <= maximum or \
                before.st_size > member_cap or len(data) != before.st_size:
            fail("UNDECLARED_INPUT_PATH", f"variable platform cap differs: {path}")
        normalised, replacements = re.subn(
            rb"(?m)^I:(?:0|[1-9][0-9]*)\n", b"I:<decimal>\n", data)
        if replacements != 1 or _sha(normalised) != record.get("normalisedSha256"):
            fail("UNDECLARED_INPUT_PATH", f"variable platform grammar differs: {path}")
    else:
        fail("UNDECLARED_INPUT_PATH", f"unknown platform normalisation: {path}")
    current = {
        **record, "path": str(path), "size": before.st_size,
        "sha256": _sha(data), "device": before.st_dev, "inode": before.st_ino,
    }
    return str(path), current, data


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


def _authority(
        statement: Mapping[str, Any], packet: Mapping[str, Any],
        profile: Mapping[str, Any], args: argparse.Namespace,
        source_bytes: Mapping[str, bytes]) -> None:
    for name in ("observer_sha", "product_sha", "packet_sha"):
        value = getattr(args, name)
        if len(value) != 40 or any(char not in "0123456789abcdef" for char in value):
            fail("PROVENANCE_INCOMPLETE", f"invalid {name}")
    exact = {"observerSha": args.observer_sha, "productSha": args.product_sha, "packetSha": args.packet_sha,
             "packetRoot": args.packet_root, "authorityIssue": args.authority_issue,
             "authorityComment": args.authority_comment, "requestIndex": args.request_index,
             "workingDirectory": str(OBSERVER_ROOT),
             "profileSha256": _sha(source_bytes["profile"]),
             "g0ManifestSha256": _sha(source_bytes["g0Manifest"]),
             "packetManifestSha256": _sha(source_bytes["packetManifest"])}
    if any(statement.get(key) != value for key, value in exact.items()):
        fail("PROVENANCE_INCOMPLETE", "statement differs from independent workflow inputs")
    expected_case_root = args.expected_runtime_root.resolve() / args.case_id
    expected_roots = {
        "GODOT": str(args.expected_godot.resolve()),
        "PRODUCT": str(args.expected_product_mount.resolve()),
        "PACKET": str(args.expected_packet_mount.resolve()),
        "HOME": str((expected_case_root / "home").resolve()),
        "OUTPUT": str((expected_case_root / "output").resolve()),
    }
    if statement.get("roots") != expected_roots:
        fail("PROVENANCE_INCOMPLETE", "statement roots differ from trusted workflow paths")
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


def _environment(entries: Sequence[str]) -> dict[str, str]:
    result: dict[str, str] = {}
    for entry in entries:
        if "=" not in entry or not entry.split("=", 1)[0] or entry.split("=", 1)[0] in result:
            fail("ENVIRONMENT_MISMATCH", "environment name or uniqueness differs")
        name, value = entry.split("=", 1); result[name] = value
    return result


def _exec(trace: Mapping[str, Any], sidecar: bytes, profile: Mapping[str, Any], roots: Mapping[str, str],
          runtime: Mapping[str, Mapping[str, Any]], argv: list[str], environment: list[str]) -> None:
    events = [event for event in trace["events"] if event["type"] == "EXEC"]
    values = {**roots, "EXTERNAL_SCRIPT": Path(argv[5]).name, "CORPUS": Path(argv[8]).name,
              "INDEX": argv[10], "WORKING_DIRECTORY": str(OBSERVER_ROOT)}
    expected = [("/usr/bin/env", "/usr/bin/env",
                 [_expand(item, values) for item in profile["invocation"]["launcherArgvTemplate"]],
                 [_expand(item, values) for item in profile["invocation"]["launcherEnvironment"]])]
    expected += [(roots["GODOT"], roots["GODOT"], argv, environment)]
    expected += [(item["requestedPath"], item["effectivePath"], item["argv"],
                  [_expand(value, values) for value in item["environment"]])
                 for item in profile["invocation"]["permittedDescendantExecs"]]
    if len(events) != len(expected): fail("PROCESS_LINEAGE_MISMATCH", "exec count differs")
    for event, (requested, effective, wanted_argv, wanted_env) in zip(events, expected):
        if _nul(sidecar, event["argvOffset"], event["argvLength"], "argv") != wanted_argv:
            fail("ARGV_MISMATCH", f"exec argv differs for {requested}")
        if _environment(_nul(sidecar, event["envOffset"], event["envLength"], "environment")) != \
                _environment(wanted_env):
            fail("ENVIRONMENT_MISMATCH", f"exec environment differs for {requested}")
        identity = runtime.get(effective)
        if identity is None or (identity.get("device"), identity.get("inode")) != (event["device"], event["inode"]) or \
                event["path"] != str(Path(effective).resolve()) or event.get("_requestedPath") != requested:
            fail("RUNTIME_DEPENDENCY_MISMATCH", f"exec identity differs for {requested}")


def _lineage(trace: Mapping[str, Any], profile: Mapping[str, Any], diagnostic: bool) -> None:
    events, end, caps = trace["events"], trace["end"], profile["caps"]
    pipe_contract, graph = profile["accessGrammar"]["internalPipe"], profile["processGraph"]
    lines = [e for e in events if e["type"] == "LINEAGE"]; exits = [e for e in events if e["type"] == "EXIT"]
    execs = [e for e in events if e["type"] == "EXEC"]
    signals = [e for e in events if e["type"] == "SIGNAL"]
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
    if len(execs) != 4: fail("PROCESS_LINEAGE_MISMATCH", "exec topology differs")
    root, shell, xdg = execs[0]["tid"], execs[2]["tid"], execs[3]["tid"]
    process = [line for line in lines if line["tid"] == root and line["childTid"] == shell
               and line["kind"] == graph["rootToShellKind"] and line["cloneFlags"] == graph["rootToShellFlags"]]
    vfork = [line for line in lines if line["tid"] == shell and line["childTid"] == xdg
             and line["kind"] == graph["shellToXdgKind"] and line["cloneFlags"] == graph["shellToXdgFlags"]]
    threads = [line for line in lines if line["tid"] == root and line["kind"] == graph["rootThreadKind"]
               and line["cloneFlags"] == graph["rootThreadFlags"]]
    if execs[1]["tid"] != root or len({root, shell, xdg}) != 3 or any(
            event["tgid"] != event["tid"] for event in execs) or len(process) != 1 or len(vfork) != 1 or \
            len(threads) != graph["rootThreadCount"] or set(map(id, process + vfork + threads)) != set(map(id, lines)):
        fail("PROCESS_LINEAGE_MISMATCH", "parent/child process graph differs")
    signal_contract = graph["signalGrammar"]
    expected_signals = []
    for parent, child in ((shell, xdg), (root, shell)):
        child_exits = [event for event in exits if event["tid"] == child]
        deliveries = [event for event in signals if event["tid"] == parent
                      and event["signal"] == signal_contract["number"]]
        if len(child_exits) != 1 or len(deliveries) != 1 or \
                child_exits[0]["sequence"] >= deliveries[0]["sequence"]:
            fail("PROCESS_LINEAGE_MISMATCH", "SIGCHLD process ordering differs")
        expected_signals.extend(deliveries)
    if len(signals) != caps["validSignalEvents"] or len(signals) != signal_contract["count"] or \
            set(map(id, signals)) != set(map(id, expected_signals)):
        fail("PROCESS_LINEAGE_MISMATCH", "signal delivery grammar differs")
    pipe_entries = [event for event in events
                    if event["type"] == "SYSCALL_E" and event["name"] == "pipe2"]
    if names.count("pipe2") != pipe_contract["pipe2Count"] or \
            any(len(event.get("arguments", [])) < 2 or
                event["arguments"][1] != pipe_contract["pipe2Flags"]
                for event in pipe_entries) or \
            names.count("dup2") != pipe_contract["dup2Count"]:
        fail("PROCESS_LINEAGE_MISMATCH", "internal pipe syscall shape differs")
    duplicates = [event for event in events if event["type"] == "DUP"]
    internal = _internal_pipe_paths(events)
    producer = [item for item in duplicates if item["operation"] == "dup2" and item["targetFd"] == 1
                and item["path"] in internal]
    redirect = [item for item in duplicates if item["operation"] == "dup2" and item["targetFd"] == 2
                and item["path"] == "/dev/null"]
    restore = [item for item in duplicates if item["operation"] == "dup2" and item["sourceFd"] == 10
               and item["targetFd"] == 2 and _pipe_path(item["path"]) and item["path"] not in internal]
    saved = [item for item in duplicates if item["operation"] == "fcntl" and item["tid"] == shell
             and item["sourceFd"] == 2 and item["targetFd"] == 10]
    xdg_saved = [item for item in duplicates if item["operation"] == "fcntl" and item["tid"] == xdg
                 and item["sourceFd"] == 3 and item["targetFd"] == 10
                 and item["path"] == "/usr/bin/xdg-user-dir"]
    if len(duplicates) != profile["accessGrammar"]["descriptorGrammar"]["successfulDuplicates"] or \
            any(item["closeOnExec"] != 0 for item in duplicates) or any(len(group) != 1 for group in
            (producer, redirect, restore, saved, xdg_saved)) or saved[0]["path"] != restore[0]["path"] or \
            not producer[0]["sequence"] < execs[2]["sequence"] or \
            not saved[0]["sequence"] < redirect[0]["sequence"] < vfork[0]["sequence"] < restore[0]["sequence"] or \
            not execs[3]["sequence"] < xdg_saved[0]["sequence"]:
        fail("PROCESS_LINEAGE_MISMATCH", "descriptor/redirect topology differs")


def _output_records(statement: Mapping[str, Any], case_dir: Path) -> dict[str, Mapping[str, Any]]:
    streams, outputs = statement.get("streams"), statement.get("outputs")
    if not isinstance(streams, dict) or not isinstance(outputs, dict): fail("PROVENANCE_INCOMPLETE", "outputs missing")
    roots = statement.get("roots")
    if not isinstance(roots, dict): fail("PROVENANCE_INCOMPLETE", "output roots missing")
    expected = {
        "observation": (str(Path(str(roots.get("OUTPUT"))) / "observation.json"), "observation.json"),
        "homeLog": (str(Path(str(roots.get("HOME"))) / ".local/share/godot/app_userdata/Glassvow/logs/godot.log"), "home-godot.log"),
        "sentry": (str(Path(str(roots.get("HOME"))) / ".local/share/godot/app_userdata/Glassvow/sentry.dat"), "home-sentry.dat"),
    }
    result: dict[str, Mapping[str, Any]] = {}
    for name in ("observation", "homeLog", "sentry"):
        record = outputs.get(name)
        if not isinstance(record, dict): fail("PROVENANCE_INCOMPLETE", f"{name} missing")
        if (record.get("path"), record.get("file")) != expected[name]:
            fail("PROVENANCE_INCOMPLETE", f"{name} output binding differs")
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


def _validate_stable_output_policy(
        statement: Mapping[str, Any], streams: Mapping[str, Any],
        outputs: Mapping[str, Any], profile: Mapping[str, Any]) -> None:
    ingress = profile.get("packetIngress", {})
    qualification, research = ingress.get("qualification", {}), ingress.get("research", {})
    authority = (statement.get("authorityIssue"), statement.get("authorityComment"))
    if authority == (qualification.get("authorityIssue"), qualification.get("authorityComment")):
        for name in ("stdout", "stderr"):
            expected, actual = profile["roles"][name]["qualificationBaseline"], streams.get(name, {})
            if any(actual.get(key) != expected[key] for key in ("size", "sha256")):
                fail("OUTPUT_NOT_CURRENT", f"stable {name} differs from G0 baseline")
        expected = profile["roles"]["output"]["qualificationBaseline"]["homeLog"]
        actual = outputs.get("homeLog", {})
        if not actual.get("present") or any(
                actual.get(key) != expected[key] for key in ("size", "sha256")):
            fail("OUTPUT_NOT_CURRENT", "stable homeLog differs from G0 baseline")
        return
    if authority == (research.get("authorityIssue"), research.get("authorityComment")):
        expected = {
            "mode": "bounded-current-raw-channel",
            "channels": ["stdout", "stderr", "homeLog"],
            "interpretation": "none",
            "downstreamOwner": "unchanged A1-v2 diagnostic validator",
        }
        if research.get("outputPolicy") != expected:
            fail("PROVENANCE_INCOMPLETE", "research output policy differs")
        if not outputs.get("homeLog", {}).get("present"):
            fail("OUTPUT_NOT_CURRENT", "current homeLog missing")
        return
    fail("PACKET_MANIFEST_MISMATCH", "output authority differs")


def _outputs(statement: Mapping[str, Any], trace: Mapping[str, Any], sidecar: bytes, case_dir: Path,
             challenge: str, profile: Mapping[str, Any],
             case_members: Mapping[str, bytes]) -> None:
    case_id, streams, outputs = statement["caseId"], statement.get("streams", {}), statement.get("outputs", {})
    stderr = streams.get("stderr")
    if not isinstance(stderr, dict) or "stderr.bin" not in case_members:
        fail("STDERR_CAPTURE_MISSING", "stderr capture missing")
    stderr_data = case_members["stderr.bin"]
    if len(stderr_data) != stderr.get("size") or _sha(stderr_data) != stderr.get("sha256"):
        fail("STDERR_CAPTURE_MISMATCH", "stderr bytes differ")
    if stderr.get("challenge") != challenge: fail("STDERR_INVOCATION_MISMATCH", "stderr challenge differs")
    if _stream_bytes(trace["events"], 2, sidecar) != stderr_data:
        fail("STDERR_CAPTURE_MISMATCH", "stderr captured writes differ")
    stdout = streams.get("stdout")
    if not isinstance(stdout, dict) or "stdout.bin" not in case_members: fail("OUTPUT_NOT_CURRENT", "stdout missing")
    stdout_data = case_members["stdout.bin"]
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
        fail("OUTPUT_WRITE_DENIED", "genuine diagnostic observation denial")
    if not observation.get("present") or observation.get("challenge") != challenge:
        fail("OUTPUT_NOT_CURRENT", "current observation missing or challenge differs")
    _validate_stable_output_policy(statement, streams, outputs, profile)
    output_baselines = profile["roles"]["output"]["qualificationBaseline"]
    sentry = outputs.get("sentry", {})
    sentry_data = case_members.get("home-sentry.dat")
    if not sentry.get("present") or sentry_data is None or \
            not _valid_sentry_output(sentry_data, output_baselines["sentry"]):
        fail("OUTPUT_NOT_CURRENT", "Sentry output grammar differs from G0 contract")
    if statement.get("authorityIssue") == profile["packetIngress"]["qualification"]["authorityIssue"]:
        expected = output_baselines["observation"]
        if any(observation.get(key) != expected[key] for key in ("size", "sha256")):
            fail("OUTPUT_NOT_CURRENT", "qualification observation differs from G0 baseline")
    for path, record in _output_records(statement, case_dir).items():
        file_path = case_dir / record["file"]
        reason = "STDERR_CAPTURE_MISMATCH" if file_path.name == "stderr.bin" else "OUTPUT_NOT_CURRENT"
        cap_name = "maxObservationBytes" if path.endswith("/observation.json") else "maxHomeOutputBytes"
        data = case_members.get(record["file"])
        if data is None: fail(reason, f"output copy unavailable: {record['file']}")
        if len(data) != record.get("size") or _sha(data) != record.get("sha256"): fail(reason, "output copy differs")
        live_path = Path(path); live_data = _bounded_bytes(
            live_path, _limit(profile["caps"], cap_name), reason)
        live = live_path.stat()
        if (len(live_data), _sha(live_data), live.st_dev, live.st_ino) != \
                (record.get("size"), record.get("sha256"), record.get("device"), record.get("inode")):
            fail(reason, f"current output identity differs for {path}")
        if record.get("challenge") != challenge or _written(trace["events"], path, sidecar, len(data)) != data:
            fail(reason, f"current output differs for {path}")
        if not any(e["type"] == "CLOSE" and e["path"] == path and
                   e["device"] == live.st_dev and e["inode"] == live.st_ino for e in trace["events"]):
            fail("OUTPUT_NOT_CURRENT", f"close missing for {path}")
        if len(data) > profile["caps"][cap_name]:
            fail("PROVENANCE_INCOMPLETE", f"output cap exceeded for {path}")


def _runtime_mappings(trace: Mapping[str, Any], roots: Mapping[str, str],
                      profile: Mapping[str, Any]) -> None:
    contract = profile["accessGrammar"]["mappings"]["runtimeIdentity"]
    mappings = []
    for event in trace["events"]:
        if event["type"] != "MMAP": continue
        path = event["path"]
        if path == roots["PRODUCT"] or path.startswith(roots["PRODUCT"] + "/"):
            path = "${PRODUCT}" + path[len(roots["PRODUCT"]):]
        mappings.append({key: value for key, value in (
            ("path", path), ("offset", event["offset"]), ("length", event["length"]),
            ("protection", event["protection"]), ("flags", event["flags"]))})
        if event["protection"] not in contract["protectionValues"] or \
                event["flags"] not in contract["flagValues"] or \
                event["flags"] & 1 and event["protection"] & 2:
            fail("RUNTIME_DEPENDENCY_MISMATCH", "unsafe runtime mapping mode")
        if event["flags"] & 1 and path not in contract["sharedReadOnlyPaths"]:
            fail("RUNTIME_DEPENDENCY_MISMATCH", "undeclared shared runtime mapping")
    mappings.sort(key=lambda item: (
        item["path"], item["offset"], item["length"], item["protection"], item["flags"]))
    if len(mappings) != contract["count"] or \
            _sha(_canonical(mappings)) != contract["canonicalMultisetSha256"]:
        fail("RUNTIME_DEPENDENCY_MISMATCH", "runtime mapping multiset differs from G0")


def _platform_access_witnesses(
        events: Sequence[Mapping[str, Any]],
        platform: Mapping[str, Mapping[str, Any]]) -> None:
    for path, record in platform.items():
        identity = (record.get("device"), record.get("inode"))
        opened = any(event.get("type") == "OPEN" and event.get("path") == path and
                     (event.get("device"), event.get("inode")) == identity
                     for event in events)
        closed = any(event.get("type") == "CLOSE" and event.get("path") == path and
                     (event.get("device"), event.get("inode")) == identity
                     for event in events)
        read_witness = any(event.get("type") == "SYSCALL_X" and
                           event.get("name") in {"read", "pread64"} and
                           event.get("returned", -1) >= 0 and event.get("_fdPath") == path
                           for event in events)
        if not opened or not closed or not read_witness:
            fail("UNDECLARED_INPUT_PATH", f"platform access witness missing {path}")


def _objects(trace: Mapping[str, Any], roles: Mapping[str, Mapping[str, Any]], runtime: Mapping[str, Mapping[str, Any]],
             platform: Mapping[str, Mapping[str, Any]], outputs: Mapping[str, Mapping[str, Any]],
             consumed_bytes: Mapping[str, bytes], sidecar: bytes, roots: Mapping[str, str],
             profile: Mapping[str, Any], g0: Mapping[str, Any]) -> None:
    objects: dict[str, Mapping[str, Any]] = {**roles, **platform, **outputs}
    for logical, record in runtime.items():
        resolved = str(Path(logical).resolve())
        if resolved in objects and objects[resolved] != record:
            fail("RUNTIME_DEPENDENCY_MISMATCH", f"ambiguous resolved identity {resolved}")
        objects[resolved] = record
    known = set(objects)
    grammar = profile["accessGrammar"]["paths"]
    reject_semantic_mappings([e for e in trace["events"] if e["type"] == "MMAP"], set(roles))
    _runtime_mappings(trace, roots, profile)
    pipe_contract = profile["accessGrammar"]["internalPipe"]
    expected_pipe_bytes = _expand(pipe_contract["payloadTemplate"], roots).encode()
    internal_pipes = _validate_internal_pipe(
        trace["events"], sidecar, expected_pipe_bytes, pipe_contract)
    directory_operations: dict[str, set[str]] = {}
    for record in grammar["successfulDirectoryOperations"]:
        for path in record["paths"]:
            directory_operations.setdefault(_expand(path, roots), set()).update(record["operations"])
    dynamic_directories: dict[str, set[str]] = {}
    for record in grammar["successfulDynamicDirectoryOperations"]:
        for path in record["paths"]:
            dynamic_directories.setdefault(_expand(path, roots), set()).update(record["operations"])
    successful_probes: dict[str, set[str]] = {}
    for record in grammar["successfulProbeOperations"]:
        for path in record["paths"]:
            successful_probes.setdefault(_expand(path, roots), set()).update(record["operations"])
    directory_aliases = {
        record["path"]: record["target"] for record in grammar["successfulDirectoryAliases"]}
    symlink_targets = {
        _expand(record["path"], roots): _expand(record["target"], roots)
        for record in g0["pathOperationClosure"]["symlinkTargets"]}
    if any(symlink_targets.get(path) != target
           for path, target in directory_aliases.items()):
        fail("MANIFEST_MISMATCH", "legacy directory aliases differ from G0 closure")
    named_operations = {
        record["path"]: record for record in grammar["successfulNamedPathOperations"]}
    working_directory_operations = set(grammar["successfulWorkingDirectoryOperations"])
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
        if path in dynamic_directories:
            if event["type"] != "PATH_X" or event.get("operation") not in dynamic_directories[path]:
                fail("UNDECLARED_INPUT_PATH", f"dynamic directory operation differs {path}")
            continue
        if path == str(OBSERVER_ROOT):
            if event["type"] != "PATH_X" or event.get("operation") not in working_directory_operations:
                fail("UNDECLARED_INPUT_PATH", "working-directory operation differs")
            continue
        if path in successful_probes:
            if event["type"] != "PATH_X" or event.get("operation") not in successful_probes[path]:
                fail("UNDECLARED_INPUT_PATH", f"successful probe operation differs {path}")
            try: Path(path).lstat()
            except OSError as error: fail("UNDECLARED_INPUT_PATH", f"successful probe unavailable: {error}")
            continue
        if path in symlink_targets:
            target = symlink_targets[path]
            try:
                logical, current = Path(path).lstat(), Path(path).stat()
                resolved = str(Path(path).resolve(strict=True))
            except OSError as error:
                fail("UNDECLARED_INPUT_PATH", f"symlink target unavailable: {error}")
            if not stat.S_ISLNK(logical.st_mode) or resolved != target:
                fail("UNDECLARED_INPUT_PATH", f"symlink target differs {path}")
            if event["type"] == "PATH_X":
                continue
            if event["type"] not in {"OPEN", "CLOSE"} or \
                    (event.get("device"), event.get("inode")) != \
                    (logical.st_dev, logical.st_ino) or \
                    event["type"] == "OPEN" and not event.get("flags", 0) & 0x20000:
                fail("UNDECLARED_INPUT_PATH", f"no-follow symlink identity differs {path}")
            continue
        if path in directory_operations:
            if event["type"] == "PATH_X" and event.get("operation") not in directory_operations[path] or \
                    event["type"] not in {"PATH_X", "OPEN", "CLOSE"}:
                fail("UNDECLARED_INPUT_PATH", f"directory operation differs {path}")
            try: current = Path(path).stat()
            except OSError as error: fail("UNDECLARED_INPUT_PATH", f"directory unavailable: {error}")
            if not stat.S_ISDIR(current.st_mode) or event["type"] != "PATH_X" and \
                    (event.get("device"), event.get("inode")) != (current.st_dev, current.st_ino):
                fail("UNDECLARED_INPUT_PATH", f"directory identity differs {path}")
            continue
        if path == "/dev/null":
            try: current = Path(path).stat()
            except OSError as error: fail("UNDECLARED_INPUT_PATH", f"named path unavailable: {error}")
            if event["type"] != "PATH_X" and (event.get("device"), event.get("inode")) != (current.st_dev, current.st_ino):
                fail("UNDECLARED_INPUT_PATH", f"named path identity differs {path}")
            if path == "/dev/null" and event["type"] == "OPEN" and event["flags"] != 0o1101:
                fail("OUTPUT_WRITE_DENIED", "unexpected /dev/null open mode")
            continue
        if path in named_operations:
            record = named_operations[path]
            try: current = Path(path).stat()
            except OSError as error:
                fail("UNDECLARED_INPUT_PATH", f"named path unavailable: {error}")
            if event["type"] != "PATH_X" or event.get("operation") not in record["operations"] or \
                    record.get("fileType") != "character-device" or not stat.S_ISCHR(current.st_mode) or \
                    (os.major(current.st_rdev), os.minor(current.st_rdev)) != \
                    (record.get("major"), record.get("minor")):
                fail("UNDECLARED_INPUT_PATH", f"named path operation differs {path}")
            continue
        if path not in known:
            reason = "UNDECLARED_CACHE_ACCESS" if isinstance(path, str) and path.startswith(roots["HOME"] + "/") else "UNDECLARED_INPUT_PATH"
            fail(reason, f"unknown successful object {path}")
        record = objects[path]
        if event["type"] == "PATH_X":
            operations = {"openat"} if path in outputs else set(record.get("operations", []))
            if event.get("operation") not in operations:
                fail("UNDECLARED_INPUT_PATH", f"object operation differs {path}")
            continue
        expected_class = "S" if path in roles else "W" if path in outputs else "I"
        if event.get("classification") != expected_class:
            fail("UNDECLARED_INPUT_PATH", f"object classification differs {path}")
        if (event.get("device"), event.get("inode")) != \
                (record.get("device"), record.get("inode")):
            fail("RUNTIME_DEPENDENCY_MISMATCH", f"device/inode differs for {path}")
    reads = [e for e in trace["events"] if e["type"] == "READ"]
    for path, data in consumed_bytes.items():
        validate_complete_role_reads([e for e in reads if e["path"] == path], data, sidecar)
    _platform_access_witnesses(trace["events"], platform)
    actual_directories: dict[str, list[int]] = {}
    for event in trace["events"]:
        if event.get("type") == "SYSCALL_X" and event.get("name") == "getdents64":
            actual_directories.setdefault(event.get("_fdPath"), []).append(event["returned"])
    expected_directories = {_expand(item["path"], roots): item["returns"]
                            for item in grammar["directoryEnumerations"]}
    if actual_directories != expected_directories or sum(map(len, actual_directories.values())) != profile["caps"]["validGetdents64Events"] or \
            sum(sum(values) for values in actual_directories.values()) != profile["caps"]["validGetdents64Bytes"]:
        fail("UNDECLARED_INPUT_PATH", "directory enumeration differs from frozen G0 grammar")


def _network(trace: Mapping[str, Any], profile: Mapping[str, Any]) -> None:
    sockets = [e for e in trace["events"] if e["type"] == "SOCKET"]
    binds = [e for e in trace["events"] if e["type"] == "BIND"]
    network = profile["accessGrammar"]["network"]
    if len(sockets) != profile["caps"]["allowedNetlinkSockets"] or len(binds) != profile["caps"]["allowedNetlinkBinds"] or \
            any((e["family"], e["socketType"], e["protocol"]) !=
                (network["family"], network["socketType"], network["protocol"]) or e["fd"] < 0 for e in sockets) or \
            any((e["family"], e["pid"], e["groups"], e["addressLength"], e["returned"]) !=
                (network["family"], network["bindPid"], network["bindGroups"], network["bindAddressLength"], 0)
                for e in binds) or \
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


def _checkout_identity(path: Path) -> tuple[str, bool]:
    try:
        head = subprocess.run(
            ["git", "-C", str(path), "rev-parse", "HEAD"], check=True,
            capture_output=True, text=True, timeout=5).stdout.strip()
        clean = subprocess.run(
            ["git", "-C", str(path), "diff", "--quiet", "HEAD", "--"],
            check=False, timeout=5).returncode == 0
    except (OSError, subprocess.SubprocessError) as error:
        fail("PROVENANCE_INCOMPLETE", f"checkout identity unavailable: {error}")
    return head, clean


def _configuration_capture(profile: Mapping[str, Any]) -> tuple[dict[str, Any], bytes]:
    binding = profile.get("g0", {}).get("configurationCapture", {})
    expected_path = str(CONFIGURATION_MANIFEST_PATH.relative_to(OBSERVER_ROOT))
    data = _bounded_bytes(CONFIGURATION_MANIFEST_PATH, 65536)
    if binding.get("path") != expected_path or binding.get("sha256") != _sha(data) or \
            binding.get("fixtureRoot") != str(CONFIGURATION_ROOT.relative_to(OBSERVER_ROOT)) or \
            binding.get("roleCount") != 3:
        fail("PROVENANCE_INCOMPLETE", "configuration capture binding differs")
    manifest = _json_bytes(data, CONFIGURATION_MANIFEST_PATH)
    if set(manifest) != {"schema", "source", "capture", "roles", "stagingRule"} or \
            manifest.get("schema") != "glassvow.godot-runtime-configuration-capture/v1":
        fail("PROVENANCE_INCOMPLETE", "configuration capture schema differs")
    roles = manifest.get("roles")
    required = {"extension_list.cfg", "global_script_class_cache.cfg", "uid_cache.bin"}
    if not isinstance(roles, dict) or set(roles) != required:
        fail("PROVENANCE_INCOMPLETE", "configuration capture roles differ")
    try: fixture_members = {entry.name: entry for entry in os.scandir(CONFIGURATION_ROOT)}
    except OSError as error: fail("PROVENANCE_INCOMPLETE", f"configuration fixture unavailable: {error}")
    if set(fixture_members) != required:
        fail("PROVENANCE_INCOMPLETE", "configuration fixture inventory differs")
    for name, record in roles.items():
        entry = fixture_members[name]
        metadata = entry.stat(follow_symlinks=False)
        if not stat.S_ISREG(metadata.st_mode) or entry.is_symlink() or \
                metadata.st_size != record.get("size") or \
                _file_sha(Path(entry.path)) != record.get("sha256"):
            fail("PROVENANCE_INCOMPLETE", f"configuration fixture differs: {name}")
    return manifest, data


def verify_product_stage(
        product_source: Path, product_sha: str, stage: Path,
        profile: Mapping[str, Any]) -> dict[str, Any]:
    source_head, source_clean = _checkout_identity(product_source)
    if source_head != product_sha or not source_clean:
        fail("PROVENANCE_INCOMPLETE", "product source differs before staging")
    manifest, manifest_bytes = _configuration_capture(profile)
    source = manifest.get("source")
    source_sha = source.get("productSha") if isinstance(source, dict) else None
    if not isinstance(source_sha, str) or len(source_sha) != 40 or \
            any(character not in "0123456789abcdef" for character in source_sha):
        fail("PROVENANCE_INCOMPLETE", "configuration capture source differs")
    if (stage / ".git").exists() or (stage / ".git").is_symlink():
        fail("PROVENANCE_INCOMPLETE", "product stage contains Git administration")
    common = _checked([
        "git", "-C", str(product_source), "rev-parse",
        "--path-format=absolute", "--git-common-dir",
    ]).decode().strip()
    tree_sha = _checked([
        "git", "--git-dir", common, "rev-parse", f"{product_sha}^{{tree}}",
    ]).decode().strip()
    inventory = _checked([
        "git", "--git-dir", common, "ls-tree", "-r", "-z", product_sha,
    ])
    inventory_records = [record for record in inventory.split(b"\0") if record]
    if any(record.split(b"\t", 1)[1].startswith(b".godot/")
           for record in inventory_records):
        fail("PROVENANCE_INCOMPLETE", "product commit contains generated configuration")
    sized_inventory = _checked([
        "git", "--git-dir", common, "ls-tree", "-r", "-l", "-z", product_sha,
    ])
    project_bytes = 0
    for record in (item for item in sized_inventory.split(b"\0") if item):
        try:
            metadata, _ = record.split(b"\t", 1)
            size = metadata.split()[-1]
            project_bytes += int(size)
        except (IndexError, ValueError):
            fail("PROVENANCE_INCOMPLETE", "product tree contains an unsupported member")
    if len(inventory_records) > profile["caps"]["maxProjectFiles"] or \
            project_bytes > profile["caps"]["maxProjectBytes"]:
        fail("PROVENANCE_INCOMPLETE", "product stage exceeds its frozen cap")
    with tempfile.TemporaryDirectory(prefix="glassvow-product-stage-verify-") as temporary:
        index = Path(temporary) / "index"
        environment = dict(os.environ)
        environment.update({"GIT_INDEX_FILE": str(index), "GIT_WORK_TREE": str(stage)})
        repository = ["git", "--git-dir", common, "--work-tree", str(stage)]
        _checked([*repository, "read-tree", product_sha],
                 environment=environment)
        _checked([*repository, "update-index", "--refresh"],
                 environment=environment)
        _checked([*repository, "diff-index", "--quiet", product_sha, "--"],
                 environment=environment)
        untracked = _checked(
            [*repository, "ls-files", "--others", "-z", "--"],
            environment=environment).split(b"\0")
    actual_untracked = {item.decode() for item in untracked if item}
    expected_untracked = {f".godot/{name}" for name in manifest["roles"]}
    if actual_untracked != expected_untracked:
        fail("PROVENANCE_INCOMPLETE", "product stage additive inventory differs")
    generated = stage / ".godot"
    try: members = {entry.name: entry for entry in os.scandir(generated)}
    except OSError as error: fail("PROVENANCE_INCOMPLETE", f"staged configuration unavailable: {error}")
    if set(members) != set(manifest["roles"]):
        fail("PROVENANCE_INCOMPLETE", "staged configuration inventory differs")
    for name, record in manifest["roles"].items():
        entry = members[name]
        metadata = entry.stat(follow_symlinks=False)
        if not stat.S_ISREG(metadata.st_mode) or entry.is_symlink() or \
                metadata.st_size != record.get("size") or \
                _file_sha(Path(entry.path)) != record.get("sha256"):
            fail("PROVENANCE_INCOMPLETE", f"staged configuration differs: {name}")
    return {
        "schema": PRODUCT_STAGE_SCHEMA,
        "productSha": product_sha,
        "productTreeSha": tree_sha,
        "trackedMembers": len(inventory_records),
        "trackedBytes": project_bytes,
        "trackedInventorySha256": _sha(inventory),
        "configurationManifestSha256": _sha(manifest_bytes),
        "configurationRoles": {
            name: {"size": manifest["roles"][name]["size"],
                   "sha256": manifest["roles"][name]["sha256"]}
            for name in sorted(manifest["roles"])
        },
        "stage": str(stage.resolve()),
        "verifierSha256": _file_sha(Path(__file__)),
    }


def _stage(args: argparse.Namespace) -> int:
    profile_bytes = _bounded_bytes(args.profile, _HARD_FILE_CAPS["maxProfileBytes"])
    if _sha(profile_bytes) != FROZEN_PROFILE_SHA256:
        fail("PROVENANCE_INCOMPLETE", "profile is not the frozen candidate")
    profile = _json_bytes(profile_bytes, args.profile)
    result = verify_product_stage(
        args.product_source.resolve(), args.product_sha,
        args.product_stage.resolve(), profile)
    result["receiptSha256"] = _sha(_canonical(result))
    _exclusive(args.output, _canonical(result))
    print(json.dumps(result, sort_keys=True))
    return 0


def _trusted_setup(statement: Mapping[str, Any], roots: Mapping[str, str], case_dir: Path,
                   args: argparse.Namespace, profile: Mapping[str, Any]) -> None:
    mounts = statement.get("mounts")
    if not isinstance(mounts, dict) or set(mounts) != {"product", "packet"}:
        fail("PROVENANCE_INCOMPLETE", "mount evidence differs")
    expected_sources = {
        "product": str(args.expected_product_stage.resolve()),
        "packet": str(args.expected_packet_source.resolve()),
    }
    for name, root in (("product", "PRODUCT"), ("packet", "PACKET")):
        record = mounts[name]
        options = record.get("options", "") if isinstance(record, dict) else ""
        option_list = options.split(",") if isinstance(options, str) else options
        if not isinstance(record, dict) or record.get("target") != roots[root] or not record.get("writeRejected") or \
                not isinstance(option_list, list) or "ro" not in option_list or \
                record.get("source") != expected_sources[name]:
            fail("PROVENANCE_INCOMPLETE", f"{name} read-only mount differs")
        try: read_only = bool(os.statvfs(roots[root]).f_flag & os.ST_RDONLY)
        except OSError as error: fail("PROVENANCE_INCOMPLETE", f"cannot inspect {name} mount: {error}")
        if not read_only: fail("PROVENANCE_INCOMPLETE", f"{name} live mount is writable")
    stage_receipt_bytes = _bounded_bytes(args.expected_product_stage_receipt, 1024 * 1024)
    stage_receipt = _json_bytes(stage_receipt_bytes, args.expected_product_stage_receipt)
    claimed = stage_receipt.pop("receiptSha256", None)
    source_stage = verify_product_stage(
        args.expected_product_source.resolve(), args.product_sha,
        args.expected_product_stage.resolve(), profile)
    mounted_stage = verify_product_stage(
        args.expected_product_source.resolve(), args.product_sha,
        Path(roots["PRODUCT"]), profile)
    comparable_mount = dict(mounted_stage)
    comparable_mount["stage"] = source_stage["stage"]
    if mounts["product"].get("stageReceiptFileSha256") != _sha(stage_receipt_bytes) or \
            claimed != _sha(_canonical(stage_receipt)) or \
            stage_receipt != source_stage or comparable_mount != source_stage:
        fail("PROVENANCE_INCOMPLETE", "product stage receipt differs")
    for name in ("HOME", "OUTPUT"):
        path = Path(roots[name])
        try: metadata = path.lstat()
        except OSError as error: fail("PROVENANCE_INCOMPLETE", f"fresh {name} root unavailable: {error}")
        if not stat.S_ISDIR(metadata.st_mode) or path.is_symlink() or metadata.st_uid != os.getuid():
            fail("PROVENANCE_INCOMPLETE", f"fresh {name} root ownership differs")
    observer_head, observer_clean = _checkout_identity(OBSERVER_ROOT)
    product_head, product_clean = _checkout_identity(args.expected_product_source.resolve())
    if observer_head != args.observer_sha or not observer_clean:
        fail("PROVENANCE_INCOMPLETE", "observer checkout does not match its bound commit")
    if product_head != args.product_sha or not product_clean:
        fail("PROVENANCE_INCOMPLETE", "product checkout does not match its bound commit")
    tracer = statement.get("tracer")
    _TRACE.validate_tracer_identity(
        tracer, Path(__file__).parent,
        case_dir.parent.parent / "workspace/godot-runtime-tracer",
        profile["kernelAdmission"])


def _admission_policy(
        statement: Mapping[str, Any], g0: Mapping[str, Any],
        roots: Mapping[str, str], profile: Mapping[str, Any],
        case_members: Mapping[str, bytes],
        trace: Mapping[str, Any]) -> tuple[bytes, dict[str, int]]:
    actual = case_members.get("admission-policy.tsv")
    if actual is None:
        fail("PROVENANCE_INCOMPLETE", "admission policy is missing")
    expected, counts = _build_admission_policy(
        profile, g0, roots, OBSERVER_ROOT)
    record = statement.get("admissionPolicy")
    wanted = {
        "schema": profile["kernelAdmission"]["policySchema"],
        "file": "admission-policy.tsv", "size": len(expected),
        "sha256": _sha(expected), **counts,
    }
    policy_events = [event for event in trace.get("events", [])
                     if event.get("type") == "POLICY"]
    traced = ({"byteCount": len(expected), **counts}
              if len(policy_events) == 1 else None)
    if actual != expected or record != wanted or traced is None or any(
            policy_events[0].get(key) != value for key, value in traced.items()):
        fail("PROVENANCE_INCOMPLETE", "admission policy differs")
    path_rules: set[tuple[str, str, int | None]] = set()
    for line in expected.decode("ascii").splitlines()[1:]:
        fields = line.split("\t")
        if fields[0] != "P":
            continue
        try:
            parameter = None if fields[2] == "-" else int(fields[2])
            path = bytes.fromhex(fields[3]).decode("utf-8")
        except (IndexError, ValueError, UnicodeDecodeError):
            fail("PROVENANCE_INCOMPLETE", "admission path rule is malformed")
        path_rules.add((fields[1], path, parameter))

    result_policy = profile["accessGrammar"]["paths"].get("pathResultPolicy")
    if not isinstance(result_policy, dict) or set(result_policy) != {
            "closureRule", "rootAncestorReadlink", "existingHomeAncestorMkdir",
            "diagnosticOutputDenial"} or not isinstance(
                result_policy.get("closureRule"), str):
        fail("PROFILE_MISMATCH", "path-result policy shape differs")
    readlink_translation = result_policy.get("rootAncestorReadlink")
    mkdir_translation = result_policy.get("existingHomeAncestorMkdir")
    diagnostic = result_policy.get("diagnosticOutputDenial")
    if readlink_translation != {
            "operation": "readlink", "parameter": None, "returned": -22} or \
            mkdir_translation != {
                "operation": "mkdir", "parameter": 509, "returned": -17} or \
            diagnostic != {
                "caseIds": ["G15", "G16", "G17", "G18"],
                "operation": "openat", "path": "${OUTPUT}/observation.json",
                "parameter": 577, "returned": -13}:
        fail("PROFILE_MISMATCH", "path-result translations differ")

    allowed_results: dict[tuple[str, str, int | None], set[int]] = {}
    for record in g0["pathOperationClosure"]["records"]:
        key = (record["operation"], _expand(record["path"], roots),
               record["parameter"])
        allowed_results.setdefault(key, set()).update(record["returns"])
    for root in roots.values():
        candidate = Path(root).parent
        while str(candidate) != candidate.parent.as_posix():
            allowed_results.setdefault(
                ("readlink", str(candidate), None), set()).add(-22)
            candidate = candidate.parent
        allowed_results.setdefault(
            ("readlink", str(candidate), None), set()).add(-22)
    home_ancestor = Path(roots["HOME"]).parent
    while home_ancestor != home_ancestor.parent:
        allowed_results.setdefault(
            ("mkdir", str(home_ancestor), 509), set()).add(-17)
        home_ancestor = home_ancestor.parent

    diagnostic_key = (
        diagnostic["operation"], _expand(diagnostic["path"], roots),
        diagnostic["parameter"])
    for event in trace.get("events", []):
        if event.get("type") != "PATH_X":
            continue
        arguments = event.get("_arguments")
        operation = event.get("operation")
        if not isinstance(arguments, list) or operation not in _PATH_OPERATIONS:
            fail("PROVENANCE_INCOMPLETE", "traced admission arguments are missing")
        parameter = arguments[2] if operation == "openat" else \
            arguments[1] if operation == "mkdir" else None
        key = (operation, event.get("path"), parameter)
        if key not in path_rules:
            fail("PROVENANCE_INCOMPLETE", "traced pathname was not admitted")
        returned = event.get("returned")
        expected_results = allowed_results.get(key, set())
        admitted_result = returned in expected_results or (
            operation == "openat" and isinstance(returned, int)
            and returned >= 0 and any(value >= 0 for value in expected_results))
        if key == diagnostic_key and statement.get("caseId") in diagnostic["caseIds"] \
                and returned == diagnostic["returned"]:
            admitted_result = True
        if not admitted_result:
            fail("PROVENANCE_INCOMPLETE", "traced pathname result differs")
    return expected, counts


def _complete(args: argparse.Namespace, profile: dict, g0: dict, packet: dict, statement: dict,
              trace: dict, sidecar: bytes, challenge: str,
              case_members: Mapping[str, bytes], source_bytes: Mapping[str, bytes]) -> None:
    if statement.get("schema") != STATEMENT_SCHEMA or statement.get("caseId") != args.case_id:
        fail("PROVENANCE_INCOMPLETE", "statement schema/case differs")
    if statement.get("challenge") != challenge or trace["challenge"] != challenge or statement.get("clock") != "CLOCK_MONOTONIC_RAW":
        fail("INVOCATION_CHALLENGE_MISMATCH", "fresh challenge differs")
    _authority(statement, packet, profile, args, source_bytes)
    roots = statement.get("roots")
    if not isinstance(roots, dict) or set(roots) != {"GODOT", "PRODUCT", "PACKET", "HOME", "OUTPUT"}:
        fail("PROVENANCE_INCOMPLETE", "root set differs")
    roots = {key: _absolute(value, key) for key, value in roots.items()}
    if len(set(roots.values())) != len(roots) or any(
            left.startswith(right.rstrip("/") + "/") or right.startswith(left.rstrip("/") + "/")
            for index, left in enumerate(roots.values()) for right in list(roots.values())[index + 1:]):
        fail("PROVENANCE_INCOMPLETE", "roots overlap")
    _admission_policy(statement, g0, roots, profile, case_members, trace)
    _trusted_setup(statement, roots, args.case_dir, args, profile)
    _packet_members(Path(roots["PACKET"]), args.packet_manifest, profile)
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
        role_bytes[path] = _live(
            actual, reason, profile["caps"]["maxSingleReadBytes"], True)
    executable = statement.get("executable", {})
    if executable.get("path") != roots["GODOT"] or executable.get("sha256") != profile["runtime"]["godotSha256"]:
        fail("GODOT_EXECUTABLE_MISMATCH", "Godot differs")
    _live(
        executable, "GODOT_EXECUTABLE_MISMATCH",
        profile["caps"]["maxGodotBytes"])
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
        _live(
            runtime[path], "RUNTIME_DEPENDENCY_MISMATCH",
            profile["caps"]["maxGodotBytes"])
    platform: dict[str, Mapping[str, Any]] = {}
    platform_bytes: dict[str, bytes] = {}
    for expected in expected_platform.values():
        path, current, data = _platform_live(
            expected, roots, profile["caps"]["maxPlatformObservationBytes"])
        platform[path], platform_bytes[path] = current, data
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
    if (diagnostic and (statement["tracer"]["returncode"] != 40 or trace["end"]["rootExit"] == 0)) or \
            (not diagnostic and (statement["tracer"]["returncode"] != 0 or trace["end"]["rootExit"] != 0)):
        fail("PROVENANCE_INCOMPLETE", "tracer/root exit contract differs")
    _objects(
        trace, roles, runtime, platform, output_records,
        {**role_bytes, **platform_bytes}, sidecar, roots, profile, g0)
    if trace["end"]["dropped"] or trace["end"]["violation"] not in {"", "-"}:
        fail("PROVENANCE_INCOMPLETE", f"tracer violation {trace['end']['violation']}")
    _outputs(
        statement, trace, sidecar, args.case_dir, challenge, profile,
        case_members)


def _identity_summary(value: Any) -> dict[str, Any]:
    records = value if isinstance(value, list) else []
    return {
        "count": len(records),
        "declaredBytes": sum(item.get("size", 0) for item in records
                             if isinstance(item, dict) and isinstance(item.get("size"), int)),
        "canonicalSha256": _sha(_canonical(records)),
    }


def _capture_record(path: Path, maximum: int) -> dict[str, Any]:
    try: metadata = path.lstat()
    except OSError: return {"file": path.name, "present": False}
    record: dict[str, Any] = {
        "file": path.name, "present": True, "size": metadata.st_size}
    if stat.S_ISLNK(metadata.st_mode) or not stat.S_ISREG(metadata.st_mode) \
            or metadata.st_size > maximum:
        return record | {"bounded": False}
    try: data = _bounded_bytes(path, maximum)
    except VerificationFailure: return record | {"bounded": False}
    return record | {"size": len(data), "sha256": _sha(data)}


def _capture_bytes(filename: str, data: bytes | None) -> dict[str, Any]:
    if data is None: return {"file": filename, "present": False}
    return {"file": filename, "present": True, "size": len(data), "sha256": _sha(data)}


def _receipt_details(statement: Mapping[str, Any], trace: Mapping[str, Any] | None,
                     sidecar: bytes, case_dir: Path,
                     profile: Mapping[str, Any] | None = None,
                     case_members: Mapping[str, bytes] | None = None) -> dict[str, Any]:
    events = trace.get("events", []) if isinstance(trace, dict) else []
    semantic = []
    for event in events:
        if event.get("type") != "READ" or event.get("classification") != "S": continue
        offset, count = event.get("sidecarOffset"), event.get("returned")
        captured = sidecar[offset:offset + count] if isinstance(offset, int) and isinstance(count, int) else b""
        semantic.append({key: event.get(key) for key in (
            "sequence", "tid", "operation", "fd", "offset", "requested", "returned",
            "device", "inode", "path") } | {
                "capturedComplete": isinstance(count, int) and len(captured) == count,
                "capturedSha256": _sha(captured),
            })
    mappings = [{key: event.get(key) for key in (
        "sequence", "tid", "address", "length", "protection", "flags", "fd",
        "offset", "classification", "device", "inode", "path")}
        for event in events if event.get("type") == "MMAP"]
    topology = [event for event in events
                if event.get("type") in {"EXEC", "LINEAGE", "SIGNAL", "EXIT"}]
    caps = profile.get("caps", {}) if isinstance(profile, Mapping) else {}
    cached = case_members if isinstance(case_members, Mapping) else {}
    captures = {name: (_capture_bytes(filename, cached[filename])
                       if filename in cached else
                       _capture_record(case_dir / filename, _limit(caps, cap_name)))
                for name, (filename, cap_name) in {
                    "stdout": ("stdout.bin", "maxStdoutBytes"),
                    "stderr": ("stderr.bin", "maxStderrBytes"),
                    "observation": ("observation.json", "maxObservationBytes"),
                    "homeLog": ("home-godot.log", "maxHomeOutputBytes"),
                    "sentry": ("home-sentry.dat", "maxHomeOutputBytes"),
                }.items()}
    end = trace.get("end", {}) if isinstance(trace, dict) else {}
    return {
        "invocation": {
            "argv": statement.get("argv"), "environment": statement.get("environment"),
            "workingDirectory": statement.get("workingDirectory"),
            "executable": statement.get("executable"),
        },
        "semanticSupply": _identity_summary(statement.get("roles")),
        "semanticConsumption": {
            "readEvents": len(semantic),
            "returnedBytes": sum(item.get("returned", 0) for item in semantic),
            "uniquePaths": len({item.get("path") for item in semantic}),
            "canonicalSha256": _sha(_canonical(semantic)),
        },
        "runtimeEvidence": {
            "identities": _identity_summary(statement.get("runtimeIdentities")),
            "mappingEvents": len(mappings),
            "mappedBytes": sum(item.get("length", 0) for item in mappings),
            "canonicalMappingSha256": _sha(_canonical(mappings)),
        },
        "processEvidence": {
            "taskCount": end.get("taskCount"),
            "lineageEvents": end.get("lineageEvents"),
            "execEvents": end.get("execEvents"),
            "signalEvents": sum(item.get("type") == "SIGNAL" for item in topology),
            "canonicalSha256": _sha(_canonical(topology)),
        },
        "streamOutputEvidence": {
            "declaredSha256": _sha(_canonical({
                "streams": statement.get("streams"), "outputs": statement.get("outputs")})),
            "captures": captures,
        },
        "timing": {
            "clock": statement.get("clock"), "external": statement.get("timing"),
            "traceStartNs": trace.get("startNs") if isinstance(trace, dict) else None,
            "traceFinishNs": end.get("finishNs"),
        },
        "eventEnvelope": {
            "eventCount": len(events), "firstSequence": events[0].get("sequence") if events else None,
            "lastSequence": events[-1].get("sequence") if events else None,
            "dropped": end.get("dropped"), "violation": end.get("violation"),
            "endSequence": end.get("sequence"),
        },
    }


def verify_case(
        args: argparse.Namespace, *,
        frozen_case_members: Mapping[str, bytes] | None = None,
        frozen_challenge_bytes: bytes | None = None,
        frozen_source_bytes: Mapping[str, bytes] | None = None) -> dict[str, Any]:
    statement_path = args.case_dir / "statement.json"
    statement: dict[str, Any] = {}; trace_path = args.case_dir / "trace.tsv"; sidecar_path = args.case_dir / "sidecar.bin"
    trace: dict[str, Any] | None = None; trace_bytes = b""; sidecar = b""
    profile: dict[str, Any] = {}; g0: dict[str, Any] = {}; packet: dict[str, Any] = {}
    source_bytes = dict(frozen_source_bytes) if frozen_source_bytes is not None else {}
    case_members = dict(frozen_case_members) if frozen_case_members is not None else {}
    challenge_bytes = frozen_challenge_bytes or b""
    challenge_value: str | None = None; trusted_inputs_ready = False
    try:
        profile, g0, packet = _load_sources(
            args.profile, args.g0_manifest, args.packet_manifest, source_bytes)
        matrix = {case["id"]: (case["expectedVerdict"], case["expectedReason"])
                  for case in profile["cases"]}
        if args.case_id not in CASE_RESULTS or matrix.get(args.case_id) != CASE_RESULTS[args.case_id]:
            fail("PROVENANCE_INCOMPLETE", "matrix differs")
        if frozen_challenge_bytes is None:
            challenge_bytes = _bounded_bytes(
                args.challenge, _limit(profile["caps"], "maxChallengeBytes"),
                "INVOCATION_CHALLENGE_MISMATCH")
        elif len(challenge_bytes) > _limit(profile["caps"], "maxChallengeBytes"):
            fail("INVOCATION_CHALLENGE_MISMATCH", "challenge exceeds its cap")
        challenge_value = _decode_challenge(challenge_bytes)
        trusted_inputs_ready = True
        if frozen_case_members is None:
            case_members, _ = _preflight_case_members(args.case_dir, profile["caps"])
        statement = json.loads(case_members["statement.json"].decode("utf-8"))
        if not isinstance(statement, dict):
            fail("PROVENANCE_INCOMPLETE", "statement.json is not an object")
        trace_bytes, sidecar = case_members["trace.tsv"], case_members["sidecar.bin"]
        for name, data, record in (("trace", trace_bytes, statement.get("trace")),
                                   ("sidecar", sidecar, statement.get("sidecar"))):
            if not isinstance(record, dict) or record.get("file") != f"{name}.{'tsv' if name == 'trace' else 'bin'}" or \
                    record.get("size") != len(data) or record.get("sha256") != _sha(data):
                fail("PROVENANCE_INCOMPLETE", f"{name} binding differs")
        trace = parse_trace_lines(trace_bytes.decode().splitlines(), profile["caps"]["maxEvents"])
        _early_unknown_reads(statement, trace)
        validate_trace_accounting(
            trace, profile["caps"], len(trace_bytes), len(sidecar),
            str(OBSERVER_ROOT))
        validate_syscall_grammar(trace, profile["accessGrammar"]["allowedSyscalls"])
        _complete(
            args, profile, g0, packet, statement, trace, sidecar,
            challenge_value, case_members, source_bytes)
        outcome = ("PASS", "ADMITTED")
    except (OSError, UnicodeError, IndexError, KeyError, TypeError, ValueError):
        outcome = ("INCONCLUSIVE", "PROVENANCE_INCOMPLETE")
    except VerificationFailure as error:
        if not trusted_inputs_ready or error.reason == "PROVENANCE_INCOMPLETE":
            outcome = ("INCONCLUSIVE", "PROVENANCE_INCOMPLETE")
        else:
            outcome = ("REJECT", error.reason)
    tracer_value = statement.get("tracer", {})
    tracer = tracer_value if isinstance(tracer_value, dict) else {}
    caps = profile.get("caps", {}) if isinstance(profile, dict) else {}
    source_records = {
        "profile": (_capture_bytes(args.profile.name, source_bytes["profile"])
                    if "profile" in source_bytes else
                    _capture_record(args.profile, _limit(caps, "maxProfileBytes"))),
        "g0Manifest": (_capture_bytes(args.g0_manifest.name, source_bytes["g0Manifest"])
                       if "g0Manifest" in source_bytes else
                       _capture_record(args.g0_manifest, _limit(caps, "maxG0ManifestBytes"))),
        "packetManifest": (_capture_bytes(
            args.packet_manifest.name, source_bytes["packetManifest"])
            if "packetManifest" in source_bytes else
            _capture_record(args.packet_manifest, _limit(caps, "maxPacketManifestBytes"))),
        "challenge": (_capture_bytes(args.challenge.name, challenge_bytes)
                      if challenge_bytes else
                      _capture_record(args.challenge, _limit(caps, "maxChallengeBytes"))),
    }
    receipt = {
        "schema": RECEIPT_SCHEMA, "caseId": args.case_id,
        "challenge": challenge_value, "verdict": outcome[0], "reason": outcome[1],
        "authority": {
            "observerSha": args.observer_sha, "productSha": args.product_sha,
            "packetSha": args.packet_sha, "packetRoot": args.packet_root,
            "authorityIssue": args.authority_issue, "authorityComment": args.authority_comment,
            "requestIndex": args.request_index, "workingDirectory": str(OBSERVER_ROOT),
            "godot": str(args.expected_godot.resolve()),
            "productSource": str(args.expected_product_source.resolve()),
            "productStage": str(args.expected_product_stage.resolve()),
            "productStageReceipt": str(args.expected_product_stage_receipt.resolve()),
            "packetSource": str(args.expected_packet_source.resolve()),
            "productMount": str(args.expected_product_mount.resolve()),
            "packetMount": str(args.expected_packet_mount.resolve()),
            "runtimeRoot": str(args.expected_runtime_root.resolve()),
        },
        "profileSha256": source_records["profile"].get("sha256"),
        "g0ManifestSha256": source_records["g0Manifest"].get("sha256"),
        "packetManifestSha256": source_records["packetManifest"].get("sha256"),
        "sourceEvidence": source_records,
        "statement": (_capture_bytes("statement.json", case_members["statement.json"])
                      if "statement.json" in case_members else
                      _capture_record(statement_path, _limit(caps, "maxStatementBytes"))),
        "trace": (_capture_bytes("trace.tsv", case_members["trace.tsv"])
                  if "trace.tsv" in case_members else
                  _capture_record(trace_path, _limit(caps, "maxTraceBytes"))),
        "sidecar": (_capture_bytes("sidecar.bin", case_members["sidecar.bin"])
                    if "sidecar.bin" in case_members else
                    _capture_record(sidecar_path, _limit(caps, "maxCapturedBytes"))),
        "verifierSha256": _file_sha(Path(__file__)), "traceVerifierSha256": _file_sha(_HELPER_PATH),
        "tracerIdentitySha256": _sha(_canonical(tracer)), "ioHeaderSha256": tracer.get("ioHeaderSha256"),
        **_receipt_details(
            statement, trace, sidecar, args.case_dir, profile, case_members),
    }
    receipt["receiptSha256"] = _sha(_canonical(receipt)); return receipt


def _decode_challenge(data: bytes) -> str:
    try: value = data.decode("ascii").rstrip("\n")
    except UnicodeError as error: fail("INVOCATION_CHALLENGE_MISMATCH", str(error))
    if len(value) != 64 or any(char not in "0123456789abcdef" for char in value): fail("INVOCATION_CHALLENGE_MISMATCH", "bad challenge")
    return value


def _read_challenge(path: Path, maximum: int) -> str:
    return _decode_challenge(_bounded_bytes(
        path, maximum, "INVOCATION_CHALLENGE_MISMATCH"))


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
    source_bytes: dict[str, bytes] = {}
    profile, _, _ = _load_sources(
        args.profile, args.g0_manifest, args.packet_manifest, source_bytes)
    expected_cases = {case["id"] for case in profile["cases"]}
    try:
        for directory in (args.campaign_dir, args.challenges_dir):
            metadata = directory.lstat()
            if not stat.S_ISDIR(metadata.st_mode) or stat.S_ISLNK(metadata.st_mode):
                fail("PROVENANCE_INCOMPLETE", "campaign root must be a direct non-symlink directory")
        case_entries = []
        with os.scandir(args.campaign_dir) as entries:
            for entry in entries:
                if len(case_entries) >= len(expected_cases):
                    fail("PROVENANCE_INCOMPLETE", "campaign case count exceeds cap")
                case_entries.append(entry)
        raw_challenges = []
        with os.scandir(args.challenges_dir) as entries:
            for entry in entries:
                if len(raw_challenges) >= len(expected_cases):
                    fail("PROVENANCE_INCOMPLETE", "campaign challenge count exceeds cap")
                raw_challenges.append(entry)
    except OSError as error:
        fail("PROVENANCE_INCOMPLETE", f"campaign directory unavailable: {error}")
    challenge_entries = {entry.name: Path(entry.path) for entry in raw_challenges}
    if len(case_entries) != len(expected_cases) or \
            {entry.name for entry in case_entries} != expected_cases or \
            any(not entry.is_dir(follow_symlinks=False) for entry in case_entries) or \
            len(challenge_entries) != len(expected_cases) or \
            set(challenge_entries) != {f"{case_id}.txt" for case_id in expected_cases} or \
            any(not entry.is_file(follow_symlinks=False) for entry in raw_challenges):
        fail("PROVENANCE_INCOMPLETE", "campaign case or challenge set differs")
    total = 0; frozen_cases: dict[str, dict[str, bytes]] = {}
    frozen_challenges: dict[str, bytes] = {}
    for case_id in sorted(expected_cases):
        frozen_cases[case_id], case_total = _preflight_case_members(
            args.campaign_dir / case_id, profile["caps"])
        challenge = challenge_entries[f"{case_id}.txt"]
        frozen_challenges[case_id] = _bounded_bytes(
            challenge, _limit(profile["caps"], "maxChallengeBytes"))
        total += case_total + len(frozen_challenges[case_id])
        if total > profile["caps"]["maxCampaignBytes"]:
            fail("PROVENANCE_INCOMPLETE", "campaign cap exceeded")
    receipts = []
    for case in profile["cases"]:
        current = argparse.Namespace(**vars(args)); current.case_id = case["id"]; current.case_dir = args.campaign_dir / case["id"]
        current.challenge = args.challenges_dir / f"{case['id']}.txt"
        receipts.append(verify_case(
            current, frozen_case_members=frozen_cases[case["id"]],
            frozen_challenge_bytes=frozen_challenges[case["id"]],
            frozen_source_bytes=source_bytes))
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
    for option in ("expected-godot", "expected-product-source", "expected-product-stage",
                   "expected-product-stage-receipt", "expected-packet-source",
                   "expected-product-mount", "expected-packet-mount", "expected-runtime-root"):
        common.add_argument("--" + option, dest=option.replace("-", "_"), type=Path, required=True)
    common.add_argument("--request-index", required=True)
    common.add_argument("--authority-issue", type=int, required=True); common.add_argument("--authority-comment", type=int, required=True)
    case = commands.add_parser("case", parents=[common]); case.add_argument("--case-id", choices=CASE_RESULTS)
    case.add_argument("--case-dir", type=Path, required=True); case.add_argument("--challenge", type=Path, required=True); case.set_defaults(function=_case)
    campaign = commands.add_parser("campaign", parents=[common]); campaign.add_argument("--campaign-dir", type=Path, required=True)
    campaign.add_argument("--challenges-dir", type=Path, required=True); campaign.set_defaults(function=_campaign)
    stage = commands.add_parser("stage")
    stage.add_argument("--profile", type=Path, required=True)
    stage.add_argument("--product-source", type=Path, required=True)
    stage.add_argument("--product-sha", required=True)
    stage.add_argument("--product-stage", type=Path, required=True)
    stage.add_argument("--output", type=Path, required=True)
    stage.set_defaults(function=_stage)
    args = parser.parse_args(argv)
    try: return args.function(args)
    except (VerificationFailure, OSError, KeyError, ValueError) as error: print(str(error), file=sys.stderr); return 2


if __name__ == "__main__": raise SystemExit(main())
