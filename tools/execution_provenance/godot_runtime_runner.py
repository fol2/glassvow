#!/usr/bin/env python3
"""Prepare and supervise one bounded actual-Godot provenance invocation."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import posixpath
import re
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
G0_PATH_OPERATION_SCHEMA = \
    "glassvow.godot-runtime-provenance.g0-path-operations/v1"
PATH_OPERATIONS = {
    "access", "chdir", "execve", "faccessat2", "lstat", "mkdir",
    "newfstatat", "openat", "readlink", "readlinkat", "stat", "statx",
}


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


def read_json_bytes(data: bytes) -> dict[str, Any]:
    value = json.loads(data.decode("utf-8"))
    if not isinstance(value, dict):
        raise RunnerError("JSON object required from tracer self-test")
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


def validate_path_operation_closure(
        profile: Mapping[str, Any], manifest: Mapping[str, Any]) -> dict[str, Any]:
    closure = manifest.get("pathOperationClosure")
    binding = profile.get("g0", {}).get("pathOperationClosure")
    if not isinstance(closure, dict) or not isinstance(binding, dict):
        raise RunnerError("frozen G0 path-operation closure is missing")
    if set(closure) != {
            "schema", "source", "traceMembers", "traceSetCanonicalSha256",
            "records", "recordsCanonicalSha256", "eventCount", "recordCount",
            "uniqueOperationPathPairs", "symlinkTargets",
            "symlinkTargetsCanonicalSha256", "symlinkCount"} or closure.get("schema") != \
            G0_PATH_OPERATION_SCHEMA:
        raise RunnerError("frozen G0 path-operation closure schema mismatch")
    source = closure.get("source")
    expected_source = manifest.get("source", {})
    if not isinstance(source, dict) or set(source) != {
            "run", "artifactId", "artifactSha256", "observerHead",
            "initialWorkingDirectory", "roots"} or any(
                source.get(key) != expected_source.get(key)
                for key in ("run", "artifactId", "artifactSha256", "observerHead")):
        raise RunnerError("frozen G0 path-operation source mismatch")
    roots = source.get("roots")
    if not isinstance(roots, dict) or set(roots) != {
            "GODOT", "PRODUCT", "PACKET", "HOME", "OUTPUT"} or any(
                not isinstance(value, str) or not value.startswith("/")
                or posixpath.normpath(value) != value for value in roots.values()):
        raise RunnerError("frozen G0 path-operation roots mismatch")
    working = source.get("initialWorkingDirectory")
    if not isinstance(working, str) or not working.startswith("/") \
            or posixpath.normpath(working) != working:
        raise RunnerError("frozen G0 working directory mismatch")

    members = closure.get("traceMembers")
    if not isinstance(members, list) or not members or members != sorted(
            members, key=lambda item: item.get("name", "")):
        raise RunnerError("frozen G0 trace member order mismatch")
    names: set[str] = set()
    for member in members:
        if not isinstance(member, dict) or set(member) != {"name", "size", "sha256"} \
                or not re.fullmatch(r"trace\.[0-9]+", str(member.get("name", ""))) \
                or member["name"] in names or not isinstance(member.get("size"), int) \
                or member["size"] <= 0 or not re.fullmatch(
                    r"[0-9a-f]{64}", str(member.get("sha256", ""))):
            raise RunnerError("frozen G0 trace member mismatch")
        names.add(member["name"])
    if sha256_bytes(canonical_bytes(members)) != closure["traceSetCanonicalSha256"]:
        raise RunnerError("frozen G0 trace-set hash mismatch")

    records = closure.get("records")
    if not isinstance(records, list) or not records:
        raise RunnerError("frozen G0 path-operation records are missing")
    triples: set[tuple[str, str, int | None]] = set()
    identity_operations: dict[str, set[str]] = {}
    identity_paths = {
        str(record["path"]): record
        for section in ("semanticReadSet", "runtimeIdentitySet", "platformObservationSet")
        for record in manifest.get(section, [])
    }
    for record in records:
        if not isinstance(record, dict) or set(record) != {
                "operation", "path", "parameter", "returns", "count"}:
            raise RunnerError("frozen G0 path-operation record schema mismatch")
        operation, path = record.get("operation"), record.get("path")
        parameter, returns, count = (
            record.get("parameter"), record.get("returns"), record.get("count"))
        logical = isinstance(path, str) and (
            path.startswith("/") and posixpath.normpath(path) == path
            or re.fullmatch(r"\$\{(?:GODOT|PRODUCT|PACKET|HOME|OUTPUT)\}(?:/.*)?", path)
            is not None)
        parameter_valid = (
            operation in {"openat", "mkdir"}
            and isinstance(parameter, int) and parameter >= 0
            or operation not in {"openat", "mkdir"} and parameter is None)
        if operation not in PATH_OPERATIONS or not logical or not parameter_valid \
                or not isinstance(returns, list) or not returns \
                or returns != sorted(set(returns)) \
                or any(not isinstance(value, int) for value in returns) \
                or not isinstance(count, int) or count <= 0:
            raise RunnerError("frozen G0 path-operation record mismatch")
        triple = (operation, path, parameter)
        if triple in triples:
            raise RunnerError("duplicate frozen G0 path-operation record")
        triples.add(triple)
        if path in identity_paths:
            identity_operations.setdefault(path, set()).add(operation)
    expected_records = sorted(records, key=lambda item: (
        item["operation"], item["path"],
        -1 if item["parameter"] is None else item["parameter"]))
    if records != expected_records or \
            sha256_bytes(canonical_bytes(records)) != closure["recordsCanonicalSha256"]:
        raise RunnerError("frozen G0 path-operation record hash mismatch")
    if closure.get("eventCount") != sum(record["count"] for record in records) \
            or closure.get("recordCount") != len(records) \
            or closure.get("uniqueOperationPathPairs") != len({
                (record["operation"], record["path"]) for record in records}):
        raise RunnerError("frozen G0 path-operation accounting mismatch")
    symlinks = closure.get("symlinkTargets")
    if not isinstance(symlinks, list) or symlinks != sorted(
            symlinks, key=lambda item: item.get("path", "")):
        raise RunnerError("frozen G0 symlink-target order mismatch")
    link_paths: set[str] = set()
    for record in symlinks:
        path, target = (record.get("path"), record.get("target")) \
            if isinstance(record, dict) else (None, None)
        valid_path = lambda value: isinstance(value, str) and (
            value.startswith("/") and posixpath.normpath(value) == value
            or re.fullmatch(
                r"\$\{(?:GODOT|PRODUCT|PACKET|HOME|OUTPUT)\}(?:/.*)?", value)
            is not None)
        if not isinstance(record, dict) or set(record) != {"path", "target"} \
                or not valid_path(path) or not valid_path(target) or path == target \
                or path in link_paths:
            raise RunnerError("frozen G0 symlink-target record mismatch")
        link_paths.add(path)
    observed_links = {
        record["path"] for record in records
        if record["operation"] in {"readlink", "readlinkat"}
        and any(value >= 0 for value in record["returns"])}
    observed_links.discard("${GODOT}")
    if link_paths != observed_links or closure.get("symlinkCount") != len(symlinks) \
            or sha256_bytes(canonical_bytes(symlinks)) != \
            closure.get("symlinkTargetsCanonicalSha256"):
        raise RunnerError("frozen G0 symlink-target accounting mismatch")
    for path, record in identity_paths.items():
        recorded = set(record.get("operations", [])) & PATH_OPERATIONS
        if recorded != identity_operations.get(path, set()):
            raise RunnerError(f"G0 identity path operations differ: {path}")
    expected_binding = {
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
    if binding != expected_binding:
        raise RunnerError("frozen G0 path-operation profile binding mismatch")
    return closure


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
    validate_path_operation_closure(profile, manifest)
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


def materialise_product_stage(
        product_source: Path, product_sha: str, destination: Path,
        configuration_root: Path, configuration_manifest_path: Path,
        profile: Mapping[str, Any]) -> dict[str, Any]:
    if destination.exists():
        raise RunnerError("product stage must be a fresh path")
    manifest = read_json(configuration_manifest_path)
    capture = profile.get("g0", {}).get("configurationCapture", {})
    if capture.get("sha256") != sha256_file(configuration_manifest_path) or \
            capture.get("roleCount") != 3:
        raise RunnerError("configuration capture profile binding differs")
    source = manifest.get("source")
    source_sha = source.get("productSha") if isinstance(source, dict) else None
    if manifest.get("schema") != "glassvow.godot-runtime-configuration-capture/v1" or \
            not isinstance(source_sha, str) or len(source_sha) != 40 or \
            any(character not in "0123456789abcdef" for character in source_sha):
        raise RunnerError("configuration capture schema differs")
    roles = manifest.get("roles")
    required = {
        "extension_list.cfg", "global_script_class_cache.cfg", "uid_cache.bin"}
    if not isinstance(roles, dict) or set(roles) != required:
        raise RunnerError("configuration role set differs")
    try:
        members = {entry.name: entry for entry in os.scandir(configuration_root)}
    except OSError as error:
        raise RunnerError("configuration fixture root is unavailable") from error
    if set(members) != required:
        raise RunnerError("configuration fixture inventory differs")
    for name, binding in roles.items():
        entry = members[name]
        metadata = entry.stat(follow_symlinks=False)
        if not stat.S_ISREG(metadata.st_mode) or entry.is_symlink() or \
                not isinstance(binding, dict) or metadata.st_size != binding.get("size") or \
                sha256_file(Path(entry.path)) != binding.get("sha256"):
            raise RunnerError(f"configuration fixture differs: {name}")
    common = checked([
        "git", "-C", str(product_source.resolve()), "rev-parse",
        "--path-format=absolute", "--git-common-dir",
    ]).stdout.decode().strip()
    tree_sha = checked([
        "git", "--git-dir", common, "rev-parse", f"{product_sha}^{{tree}}",
    ]).stdout.decode().strip()
    tree_inventory = checked([
        "git", "--git-dir", common, "ls-tree", "-r", "-z", product_sha,
    ], timeout=60).stdout
    if any(path.startswith(b".godot/") for path in (
            record.split(b"\t", 1)[1] for record in tree_inventory.split(b"\0") if record)):
        raise RunnerError("product commit already contains generated configuration")
    tracked_count = tree_inventory.count(b"\0")
    sized_inventory = checked([
        "git", "--git-dir", common, "ls-tree", "-r", "-l", "-z", product_sha,
    ], timeout=60).stdout
    try:
        tracked_bytes = sum(int(record.split(b"\t", 1)[0].split()[-1])
                            for record in sized_inventory.split(b"\0") if record)
    except (IndexError, ValueError) as error:
        raise RunnerError("product tree contains an unsupported member") from error
    if tracked_count > profile["caps"]["maxProjectFiles"] or \
            tracked_bytes > profile["caps"]["maxProjectBytes"]:
        raise RunnerError("product stage cap exceeded")
    destination.mkdir(parents=True)
    index_path = destination.parent / f".{destination.name}.index"
    environment = dict(os.environ)
    environment["GIT_INDEX_FILE"] = str(index_path)
    try:
        checked(["git", "--git-dir", common, "read-tree", product_sha],
                environment=environment)
        checked([
            "git", "--git-dir", common, "checkout-index", "--all", "--force",
            f"--prefix={destination.resolve()}{os.sep}",
        ], timeout=120, environment=environment)
    finally:
        try: index_path.unlink()
        except FileNotFoundError: pass
    generated = destination / ".godot"
    if generated.exists():
        raise RunnerError("product stage generated directory is not fresh")
    generated.mkdir(mode=0o755)
    for name in sorted(required):
        source, target = configuration_root / name, generated / name
        with source.open("rb") as reader, target.open("xb") as writer:
            shutil.copyfileobj(reader, writer)
        os.chmod(target, 0o444)
    os.chmod(generated, 0o555)
    return {
        "schema": "glassvow.godot-runtime-product-stage/v1",
        "productSha": product_sha,
        "productTreeSha": tree_sha,
        "trackedMembers": tracked_count,
        "trackedBytes": tracked_bytes,
        "trackedInventorySha256": sha256_bytes(tree_inventory),
        "configurationManifestSha256": sha256_file(configuration_manifest_path),
        "configurationRoles": {
            name: {"size": roles[name]["size"], "sha256": roles[name]["sha256"]}
            for name in sorted(required)
        },
        "stage": str(destination.resolve()),
    }


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
    probe = read_json_bytes(checked([str(binary), "--self-test"]).stdout)
    expected_probe = {
        "schema": "glassvow.godot-runtime-kernel-admission/v1",
        "minimumAbi": 3, "handledAccessFs": 32759,
        "policySchema": "GODOTACCESSv1",
        "fileRuleCapacity": 192, "pathRuleCapacity": 2304,
        "policyByteCapacity": 393216,
        "writeSubtrees": 2, "namedWriteFiles": 1,
        "descriptorSanitisation": True,
        "noNewPrivileges": True,
    }
    if probe.get("landlockAbi", 0) < 3 or any(
            probe.get(key) != value for key, value in expected_probe.items()):
        raise RunnerError("kernel admission self-test differs")
    return {
        "compiler": compiler,
        "compilerVersion": checked([compiler, "--version"]).stdout.decode().splitlines()[0],
        "command": command,
        "binary": str(binary.resolve()),
        "binarySha256": sha256_file(binary),
        "sourceSha256": sha256_file(TRACER_SOURCE),
        "ioSourceSha256": sha256_file(TRACER_IO_SOURCE),
        "ioHeaderSha256": sha256_file(TRACER_IO_HEADER),
        "kernelAdmission": probe,
    }


def _expand_path(template: str, roots: Mapping[str, str]) -> str:
    return _substitute(template, roots)


def build_admission_policy(
        profile: Mapping[str, Any], manifest: Mapping[str, Any],
        roots: Mapping[str, str], working_directory: Path) -> tuple[bytes, dict[str, int]]:
    closure = validate_path_operation_closure(profile, manifest)
    translations = profile["accessGrammar"]["paths"].get("pathResultPolicy", {})
    mkdir_translation = translations.get("existingHomeAncestorMkdir", {})
    if mkdir_translation != {
            "operation": "mkdir", "parameter": 509, "returned": -17}:
        raise RunnerError("HOME-ancestor mkdir translation differs")
    hwcaps_grammar = profile["accessGrammar"]["paths"].get(
        "hwcapsProbeGrammar")
    if not isinstance(hwcaps_grammar, Mapping) or set(hwcaps_grammar) != {
            "schema", "loader", "levels", "identityClass", "fileIdentity",
            "rule"} or hwcaps_grammar.get("schema") != \
            "glassvow.godot-runtime-provenance.hwcaps-probe-grammar/v1" or \
            hwcaps_grammar.get("loader") != \
            "glibc-ld.so-x86-64-hwcaps-subdirs" or \
            hwcaps_grammar.get("levels") != [
                "x86-64-v4", "x86-64-v3", "x86-64-v2"] or \
            hwcaps_grammar.get("identityClass") != \
            "identity-only-runtime-probe" or \
            hwcaps_grammar.get("fileIdentity") != \
            "none-unless-present-in-g0-identity-sets" or \
            not isinstance(hwcaps_grammar.get("rule"), str) or \
            not hwcaps_grammar["rule"]:
        raise RunnerError("HWCAP probe grammar differs")
    files: dict[str, set[str]] = {}
    paths: set[tuple[str, str, int | None]] = set()

    def expand(value: str) -> str:
        return _expand_path(value, roots)

    def canonical_path(value: str) -> str:
        if not value.startswith("/") or "\0" in value:
            raise RunnerError("invalid admission pathname rule")
        return posixpath.normpath(value)

    def canonical_identity(value: str) -> str:
        return str(Path(canonical_path(value)).resolve(strict=False))

    def add_path(operation: str, path: str, parameter: int | None = None) -> None:
        if operation not in PATH_OPERATIONS or not path.startswith("/") or "\0" in path:
            raise RunnerError("invalid admission pathname rule")
        effective = canonical_identity(path) if operation == "execve" \
            else canonical_path(path)
        paths.add((effective, operation, parameter))

    for section in ("semanticReadSet", "runtimeIdentitySet", "platformObservationSet"):
        for record in manifest[section]:
            path = canonical_identity(expand(str(record["path"])))
            if section == "platformObservationSet" and not Path(path).is_file():
                continue
            files.setdefault(path, set()).add("R")

    for record in closure["records"]:
        operation = str(record["operation"])
        logical_path = str(record["path"])
        parameter = record["parameter"]
        add_path(operation, expand(logical_path), parameter)
        match = re.search(
            r"/glibc-hwcaps/(x86-64-v\d+)(?:/|$)", logical_path)
        if match is None:
            continue
        if match.group(1) not in hwcaps_grammar["levels"]:
            raise RunnerError("G0 HWCAP probe level is not frozen")
        for level in hwcaps_grammar["levels"]:
            sibling = (
                logical_path[:match.start(1)] + level
                + logical_path[match.end(1):])
            add_path(operation, expand(sibling), parameter)

    for template in profile["kernelAdmission"]["executeLeaves"]:
        path = canonical_identity(expand(template))
        if path not in files:
            raise RunnerError(f"execute leaf is not a frozen file identity: {path}")
        files[path].add("X")
    for template in profile["kernelAdmission"]["kernelInterpreterLeaves"]:
        path = canonical_identity(expand(template))
        if path not in files:
            raise RunnerError(f"kernel interpreter is not a frozen file identity: {path}")
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
        raise RunnerError("admission policy rule cap exceeded")
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
        raise RunnerError("admission policy byte cap exceeded")
    return data, {"fileRules": len(files), "pathRules": len(paths)}


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
    policy_bytes, policy_counts = build_admission_policy(
        profile, g0_manifest, roots, OBSERVER_ROOT)
    policy_path = case_dir / "admission-policy.tsv"
    with policy_path.open("xb") as policy_file:
        policy_file.write(policy_bytes)
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
        "--policy", str(policy_path),
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
        raise RunnerError(
            "tracer did not produce complete evidence files "
            f"(returncode={result.returncode})")
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
        "admissionPolicy": {
            "schema": profile["kernelAdmission"]["policySchema"],
            "file": policy_path.name, "size": len(policy_bytes),
            "sha256": sha256_bytes(policy_bytes), **policy_counts,
        },
        "tracer": {
            "sourceSha256": build["tracer"]["sourceSha256"],
            "ioSourceSha256": build["tracer"]["ioSourceSha256"],
            "ioHeaderSha256": build["tracer"]["ioHeaderSha256"],
            "binarySha256": build["tracer"]["binarySha256"],
            "kernelAdmission": build["tracer"]["kernelAdmission"],
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
