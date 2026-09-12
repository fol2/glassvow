#!/usr/bin/env python3
"""Deterministically recover pathname operations from a Godot G0 strace set."""
from __future__ import annotations

import argparse
import ast
import errno
import hashlib
import json
import posixpath
import re
from collections import defaultdict
from collections.abc import Iterable, Mapping, Sequence
from pathlib import Path
from typing import Any


PATH_OPERATIONS = {
    "access", "chdir", "execve", "faccessat2", "lstat", "mkdir",
    "newfstatat", "openat", "readlink", "readlinkat", "stat", "statx",
}
AT_OPERATIONS = {"faccessat2", "newfstatat", "openat", "readlinkat", "statx"}
OPEN_FLAG_VALUES = {
    "O_RDONLY": 0,
    "O_WRONLY": 0x0001,
    "O_RDWR": 0x0002,
    "O_CREAT": 0x0040,
    "O_EXCL": 0x0080,
    "O_NOCTTY": 0x0100,
    "O_TRUNC": 0x0200,
    "O_APPEND": 0x0400,
    "O_NONBLOCK": 0x0800,
    "O_DSYNC": 0x1000,
    "FASYNC": 0x2000,
    "O_DIRECT": 0x4000,
    "O_LARGEFILE": 0x8000,
    "O_DIRECTORY": 0x10000,
    "O_NOFOLLOW": 0x20000,
    "O_CLOEXEC": 0x80000,
    "O_PATH": 0x200000,
    "O_TMPFILE": 0x410000,
}
ERROR_NUMBERS = {
    name: -number for number, name in errno.errorcode.items()
}
LINE = re.compile(
    r"^[0-9]+(?:\.[0-9]+)? ([A-Za-z0-9_]+)\((.*)\)\s+= (.*?) <[0-9.]+>$")
QUOTED = re.compile(r'"(?:[^"\\]|\\.)*"')


class TraceSummaryError(RuntimeError):
    """Raised when a frozen trace cannot be summarised without guessing."""


def _split_arguments(value: str) -> list[str]:
    result: list[str] = []
    start = 0
    quote = False
    escaped = False
    depth = 0
    for index, character in enumerate(value):
        if quote:
            if escaped:
                escaped = False
            elif character == "\\":
                escaped = True
            elif character == '"':
                quote = False
            continue
        if character == '"':
            quote = True
        elif character in "([{":
            depth += 1
        elif character in ")]}" and depth:
            depth -= 1
        elif character == "," and depth == 0:
            result.append(value[start:index].strip())
            start = index + 1
    if quote or depth:
        raise TraceSummaryError("unterminated strace argument list")
    result.append(value[start:].strip())
    return result


def _quoted_value(value: str) -> str | None:
    match = QUOTED.search(value)
    if match is None:
        return None
    decoded = ast.literal_eval(match.group(0))
    if not isinstance(decoded, str) or "\0" in decoded:
        raise TraceSummaryError("invalid pathname string")
    return decoded


def _return_value(value: str) -> int:
    error = re.match(r"-1 ([A-Z][A-Z0-9_]+)(?: |$)", value)
    if error:
        try:
            return ERROR_NUMBERS[error.group(1)]
        except KeyError as exc:
            raise TraceSummaryError(f"unknown strace errno {error.group(1)}") from exc
    returned = re.match(r"-?[0-9]+", value)
    if returned is None:
        raise TraceSummaryError(f"unsupported strace return {value}")
    return int(returned.group(0))


def _open_flags(value: str) -> int:
    if re.fullmatch(r"0[0-7]*|[1-9][0-9]*", value):
        return int(value, 8 if value.startswith("0") and value != "0" else 10)
    result = 0
    for token in value.split("|"):
        try:
            result |= OPEN_FLAG_VALUES[token]
        except KeyError as exc:
            raise TraceSummaryError(f"unknown Linux open flag {token}") from exc
    return result


def _mode(value: str) -> int:
    if not re.fullmatch(r"0[0-7]+|[1-9][0-9]*|0", value):
        raise TraceSummaryError(f"unsupported mkdir mode {value}")
    return int(value, 8 if value.startswith("0") and value != "0" else 10)


def _has_flag(value: str, flag: str) -> bool:
    return flag in value.split("|")


def _descriptor_base(value: str, working_directory: str) -> str | None:
    annotated = re.search(r"<([^>]+)>", value)
    if annotated:
        return annotated.group(1).split("<", 1)[0]
    if value.startswith("AT_FDCWD"):
        return working_directory
    return None


def _absolute_path(path: str, base: str | None) -> str:
    if path.startswith("/"):
        return posixpath.normpath(path)
    if base is None:
        raise TraceSummaryError(f"relative pathname has no observed base: {path}")
    return posixpath.normpath(posixpath.join(base, path)) if path else posixpath.normpath(base)


def _parse_path_call(line: str, working_directory: str) -> dict[str, Any] | None:
    match = LINE.match(line)
    if match is None:
        return None
    operation, raw_arguments, raw_return = match.groups()
    if operation not in PATH_OPERATIONS:
        return None
    arguments = _split_arguments(raw_arguments)
    path_index = 1 if operation in AT_OPERATIONS else 0
    if len(arguments) <= path_index:
        raise TraceSummaryError(f"missing pathname argument for {operation}")
    supplied = _quoted_value(arguments[path_index])
    if supplied is None:
        raise TraceSummaryError(f"uncaptured pathname argument for {operation}")
    base = _descriptor_base(arguments[0], working_directory) \
        if operation in AT_OPERATIONS else working_directory
    requested = _absolute_path(supplied, base)
    parameter: int | None = None
    follow_final = operation not in {
        "lstat", "mkdir", "readlink", "readlinkat",
    }
    if operation == "openat":
        if len(arguments) < 3:
            raise TraceSummaryError("openat flags unavailable")
        parameter = _open_flags(arguments[2])
        follow_final = not _has_flag(arguments[2], "O_NOFOLLOW")
    elif operation == "mkdir":
        if len(arguments) < 2:
            raise TraceSummaryError("mkdir mode unavailable")
        parameter = _mode(arguments[1])
    elif operation in {"faccessat2", "newfstatat"}:
        if len(arguments) < 4:
            raise TraceSummaryError(f"{operation} flags unavailable")
        follow_final = not _has_flag(arguments[3], "AT_SYMLINK_NOFOLLOW")
    elif operation == "statx":
        if len(arguments) < 3:
            raise TraceSummaryError("statx flags unavailable")
        follow_final = not _has_flag(arguments[2], "AT_SYMLINK_NOFOLLOW")
    returned = _return_value(raw_return)
    opened_target = None
    if operation == "openat" and returned >= 0 and follow_final:
        descriptor_target = re.search(r"^-?[0-9]+<([^>]+)>", raw_return)
        if descriptor_target and descriptor_target.group(1).startswith("/"):
            opened_target = posixpath.normpath(
                descriptor_target.group(1).split("<", 1)[0])
    target_index = 2 if operation == "readlinkat" else 1
    target = (_quoted_value(arguments[target_index])
              if operation in {"readlink", "readlinkat"}
              and returned >= 0 and len(arguments) > target_index else None)
    return {
        "operation": operation,
        "requested": requested,
        "parameter": parameter,
        "returned": returned,
        "linkTarget": target,
        "openedTarget": opened_target,
        "followFinal": follow_final,
    }


def _link_map(calls: Iterable[Mapping[str, Any]]) -> dict[str, str]:
    links: dict[str, str] = {}
    for call in calls:
        target = call.get("linkTarget") or call.get("openedTarget")
        if not isinstance(target, str):
            continue
        requested = str(call["requested"])
        if requested.startswith(("/proc/self/", "/proc/thread-self/")):
            continue
        resolved = target if target.startswith("/") else posixpath.join(
            posixpath.dirname(requested), target)
        resolved = posixpath.normpath(resolved)
        if requested == resolved:
            continue
        existing = links.setdefault(requested, resolved)
        if existing != resolved:
            raise TraceSummaryError(f"symlink target changed within G0: {requested}")
    return links


def _resolve_links(
        path: str, links: Mapping[str, str], *, follow_final: bool) -> str:
    result = path
    for _ in range(len(links) + 1):
        match = next((source for source in sorted(links, key=len, reverse=True)
                      if (follow_final and result == source)
                      or result.startswith(source + "/")), None)
        if match is None:
            return result
        result = posixpath.normpath(links[match] + result[len(match):])
    raise TraceSummaryError(f"symlink cycle in G0 path closure: {path}")


def _normalise(path: str, roots: Mapping[str, str]) -> str:
    for label, root in sorted(roots.items(), key=lambda item: len(item[1]), reverse=True):
        if path == root or path.startswith(root.rstrip("/") + "/"):
            return "${" + label + "}" + path[len(root):]
    return path


def path_observation_closure(
        traces: Mapping[str, Sequence[str]], *, roots: Mapping[str, str],
        initial_working_directory: str) -> tuple[
            list[dict[str, Any]], list[dict[str, str]]]:
    """Return canonical path-operation and symlink closures for all tracees."""
    calls: list[dict[str, Any]] = []
    for name in sorted(traces):
        working_directory = initial_working_directory
        for line in traces[name]:
            call = _parse_path_call(line, working_directory)
            if call is None:
                continue
            calls.append(call)
            if call["operation"] == "chdir" and call["returned"] == 0:
                working_directory = str(call["requested"])
    links = _link_map(calls)
    grouped: dict[tuple[str, str, int | None], dict[str, Any]] = defaultdict(
        lambda: {"returns": set(), "count": 0})
    for call in calls:
        requested = str(call["requested"])
        observed_target = call.get("openedTarget")
        if requested.startswith(("/proc/self/", "/proc/thread-self/")) \
                and not isinstance(observed_target, str):
            candidate = call.get("linkTarget")
            if isinstance(candidate, str) and candidate.startswith("/"):
                observed_target = candidate
        resolved = (posixpath.normpath(observed_target)
                    if isinstance(observed_target, str) else
                    _resolve_links(
                        requested, links,
                        follow_final=bool(call["followFinal"])))
        logical = _normalise(resolved, roots)
        key = (str(call["operation"]), logical, call["parameter"])
        grouped[key]["returns"].add(call["returned"])
        grouped[key]["count"] += 1
    records = [{
        "operation": operation,
        "path": path,
        "parameter": parameter,
        "returns": sorted(values["returns"]),
        "count": values["count"],
    } for (operation, path, parameter), values in sorted(
        grouped.items(), key=lambda item: (
            item[0][0], item[0][1], -1 if item[0][2] is None else item[0][2]))]
    symlinks = [{
        "path": _normalise(path, roots),
        "target": _normalise(target, roots),
    } for path, target in sorted(_link_map(
        call for call in calls
        if isinstance(call.get("linkTarget"), str)
        and not str(call["requested"]).startswith(
            ("/proc/self/", "/proc/thread-self/"))).items())]
    return records, symlinks


def path_operation_closure(
        traces: Mapping[str, Sequence[str]], *, roots: Mapping[str, str],
        initial_working_directory: str) -> list[dict[str, Any]]:
    """Return the canonical operation/path/parameter closure for all tracees."""
    return path_observation_closure(
        traces, roots=roots,
        initial_working_directory=initial_working_directory)[0]


def trace_capture(trace_directory: Path) -> tuple[dict[str, list[str]], list[dict[str, Any]]]:
    traces: dict[str, list[str]] = {}
    members: list[dict[str, Any]] = []
    for path in sorted(trace_directory.glob("trace.*")):
        data = path.read_bytes()
        traces[path.name] = data.decode("utf-8", errors="strict").splitlines()
        members.append({
            "name": path.name, "size": len(data),
            "sha256": hashlib.sha256(data).hexdigest(),
        })
    if not traces:
        raise TraceSummaryError("G0 trace set is empty")
    return traces, members


def canonical_sha256(value: Any) -> str:
    data = json.dumps(value, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(data).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--trace-directory", type=Path, required=True)
    parser.add_argument("--working-directory", required=True)
    parser.add_argument("--root", action="append", default=[])
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    roots: dict[str, str] = {}
    for item in args.root:
        label, separator, value = item.partition("=")
        if not separator or not label.isascii() or not label.isupper() \
                or not value.startswith("/") or label in roots:
            raise TraceSummaryError(f"invalid root mapping: {item}")
        roots[label] = posixpath.normpath(value)
    traces, members = trace_capture(args.trace_directory)
    records, symlinks = path_observation_closure(
        traces, roots=roots,
        initial_working_directory=posixpath.normpath(args.working_directory))
    payload = {
        "schema": "glassvow.godot-runtime-provenance.g0-path-operations/v1",
        "source": {
            "initialWorkingDirectory": posixpath.normpath(args.working_directory),
            "roots": dict(sorted(roots.items())),
        },
        "traceMembers": members,
        "traceSetCanonicalSha256": canonical_sha256(members),
        "records": records,
        "recordsCanonicalSha256": canonical_sha256(records),
        "symlinkTargets": symlinks,
        "symlinkTargetsCanonicalSha256": canonical_sha256(symlinks),
        "eventCount": sum(record["count"] for record in records),
        "recordCount": len(records),
        "uniqueOperationPathPairs": len({
            (record["operation"], record["path"]) for record in records}),
        "symlinkCount": len(symlinks),
    }
    args.output.write_text(
        json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
