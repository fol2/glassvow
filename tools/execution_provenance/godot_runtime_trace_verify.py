#!/usr/bin/env python3
"""Strict, producer-independent GODOTTRACEv1 decoding and byte checks."""
from __future__ import annotations

import hashlib
import os
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence


class VerificationFailure(Exception):
    def __init__(self, reason: str, detail: str) -> None:
        super().__init__(reason, detail)
        self.reason, self.detail = reason, detail

    def __str__(self) -> str:
        return f"{self.reason}: {self.detail}"


def fail(reason: str, detail: str) -> None:
    raise VerificationFailure(reason, detail)


def integer(value: Any, label: str, minimum: int = 0) -> int:
    if isinstance(value, bool):
        fail("PROVENANCE_INCOMPLETE", f"{label} is not an integer")
    try:
        parsed = int(value)
    except (TypeError, ValueError):
        fail("PROVENANCE_INCOMPLETE", f"{label} is not an integer")
    if str(parsed) != str(value) or parsed < minimum:
        fail("PROVENANCE_INCOMPLETE", f"invalid {label}")
    return parsed


def validate_tracer_identity(
        tracer: Any, source_root: Path, binary: Path) -> None:
    paths = {
        "sourceSha256": source_root / "godot_runtime_ptrace_tracer.c",
        "ioSourceSha256": source_root / "godot_runtime_ptrace_io.c",
        "ioHeaderSha256": source_root / "godot_runtime_ptrace_io.h",
        "binarySha256": binary,
    }
    if not isinstance(tracer, dict) or tracer.get("returncode") not in {0, 40}:
        fail("PROVENANCE_INCOMPLETE", "tracer identity or result differs")
    for key, path in paths.items():
        try:
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
        except OSError as error:
            fail("PROVENANCE_INCOMPLETE", f"tracer identity unavailable: {error}")
        if tracer.get(key) != digest:
            fail("PROVENANCE_INCOMPLETE", f"tracer {key} differs")


def signed(value: Any, label: str) -> int:
    try:
        parsed = int(value)
    except (TypeError, ValueError):
        fail("PROVENANCE_INCOMPLETE", f"{label} is not an integer")
    if str(parsed) != str(value):
        fail("PROVENANCE_INCOMPLETE", f"invalid {label}")
    return parsed


def unhex(value: str, label: str) -> str:
    try:
        return bytes.fromhex(value).decode("utf-8")
    except (ValueError, UnicodeError):
        fail("PROVENANCE_INCOMPLETE", f"invalid {label} hex")


def _event(parts: Sequence[str]) -> dict[str, Any]:
    kind, sequence, tid, fields = parts[0], integer(parts[1], "sequence", 1), \
        integer(parts[2], "tid", 1), parts[3:]
    event: dict[str, Any] = {"type": kind, "sequence": sequence, "tid": tid}
    if kind == "SYSCALL_E" and len(fields) == 8:
        event.update(number=integer(fields[0], "syscall number"), name=fields[1],
                     arguments=[integer(item, "syscall argument") for item in fields[2:]])
    elif kind == "SYSCALL_X" and len(fields) == 5:
        event.update(number=integer(fields[0], "syscall number"), name=fields[1],
                     returned=signed(fields[2], "syscall return"),
                     isError=integer(fields[3], "syscall error"),
                     resumed=integer(fields[4], "resumed syscall"))
    elif kind == "EXEC" and len(fields) == 8:
        event.update(tgid=integer(fields[0], "tgid", 1), argvOffset=integer(fields[1], "argv offset"),
                     argvLength=integer(fields[2], "argv length"), envOffset=integer(fields[3], "env offset"),
                     envLength=integer(fields[4], "env length"), device=integer(fields[5], "exec device"),
                     inode=integer(fields[6], "exec inode"), path=unhex(fields[7], "exec path"))
    elif kind == "PATH" and len(fields) == 3:
        event.update(operation=fields[0], supplied=unhex(fields[1], "supplied path"),
                     path=unhex(fields[2], "resolved path"))
    elif kind == "PATH_X" and len(fields) == 3:
        event.update(operation=fields[0], returned=signed(fields[1], "path return"),
                     path=unhex(fields[2], "path result"))
    elif kind == "IO" and len(fields) == 10 and fields[0] in {"read", "pread64", "write"}:
        event.update(operation=fields[0], fd=signed(fields[1], "IO fd"), offset=signed(fields[2], "IO offset"),
                     requested=integer(fields[3], "IO request"), returned=integer(fields[4], "IO return"),
                     classification=fields[5], device=integer(fields[6], "IO device"),
                     inode=integer(fields[7], "IO inode"), sidecarOffset=integer(fields[8], "IO sidecar offset"),
                     sidecarLength=integer(fields[4], "IO sidecar length"), path=unhex(fields[9], "IO path"))
        event["type"] = "WRITE" if fields[0] == "write" else "READ"
        if event["fd"] == 1: event["stream"] = "stdout"
        if event["fd"] == 2: event["stream"] = "stderr"
    elif kind == "OPEN" and len(fields) == 6:
        event.update(fd=signed(fields[0], "open fd"), flags=integer(fields[1], "open flags"),
                     classification=fields[2], device=integer(fields[3], "open device"),
                     inode=integer(fields[4], "open inode"), path=unhex(fields[5], "open path"))
    elif kind == "CLOSE" and len(fields) == 5:
        event.update(fd=integer(fields[0], "close fd"), classification=fields[1],
                     device=integer(fields[2], "close device"), inode=integer(fields[3], "close inode"),
                     path=unhex(fields[4], "close path"))
    elif kind == "MMAP" and len(fields) == 10:
        event.update(address=signed(fields[0], "mapping address"), length=integer(fields[1], "mapping length"),
                     protection=integer(fields[2], "mapping protection"), flags=integer(fields[3], "mapping flags"),
                     fd=signed(fields[4], "mapping fd"), offset=integer(fields[5], "mapping offset"),
                     classification=fields[6], device=integer(fields[7], "mapping device"),
                     inode=integer(fields[8], "mapping inode"), path=unhex(fields[9], "mapping path"))
    elif kind == "SOCKET" and len(fields) == 4:
        event.update(fd=signed(fields[0], "socket fd"), family=integer(fields[1], "socket family"),
                     socketType=integer(fields[2], "socket type"), protocol=integer(fields[3], "socket protocol"))
    elif kind == "BIND" and len(fields) == 6:
        event.update(fd=integer(fields[0], "bind fd"), family=integer(fields[1], "bind family"),
                     pid=integer(fields[2], "bind pid"), groups=integer(fields[3], "bind groups"),
                     addressLength=integer(fields[4], "bind address length"),
                     returned=signed(fields[5], "bind return"))
    elif kind == "PIPE" and len(fields) == 5:
        event.update(readerFd=integer(fields[0], "pipe reader fd"),
                     writerFd=integer(fields[1], "pipe writer fd"),
                     device=integer(fields[2], "pipe device"),
                     inode=integer(fields[3], "pipe inode"),
                     path=unhex(fields[4], "pipe path"))
    elif kind == "DUP" and len(fields) == 8 and fields[0] in {"dup2", "fcntl"}:
        event.update(operation=fields[0], sourceFd=integer(fields[1], "duplicate source fd"),
                     targetFd=integer(fields[2], "duplicate target fd"),
                     closeOnExec=integer(fields[3], "duplicate close-on-exec"),
                     classification=fields[4], device=integer(fields[5], "duplicate device"),
                     inode=integer(fields[6], "duplicate inode"), path=unhex(fields[7], "duplicate path"))
    elif kind == "LINEAGE" and len(fields) == 3:
        event.update(childTid=integer(fields[0], "child tid", 1), kind=fields[1],
                     cloneFlags=integer(fields[2], "clone flags"))
    elif kind == "SIGNAL" and len(fields) == 1:
        event["signal"] = integer(fields[0], "signal")
    elif kind == "EXIT" and len(fields) == 1:
        event["status"] = signed(fields[0], "exit status")
    elif kind == "VIOLATION" and len(fields) == 1:
        event["reason"] = fields[0]
    else:
        fail("PROVENANCE_INCOMPLETE", f"unknown or malformed {kind} event")
    return event


def parse_trace_lines(lines: Sequence[str], max_events: int) -> dict[str, Any]:
    if not lines or lines[0] != "GODOTTRACEv1" or len(lines) < 3:
        fail("PROVENANCE_INCOMPLETE", "missing GODOTTRACEv1 envelope")
    start = lines[1].split("\t")
    if len(start) != 24 or start[0] != "START":
        fail("PROVENANCE_INCOMPLETE", "malformed START")
    sequence = integer(start[1], "START sequence", 1)
    if sequence != 1:
        fail("PROVENANCE_INCOMPLETE", "START sequence must be one")
    challenge = start[3]
    if len(challenge) != 64 or any(char not in "0123456789abcdef" for char in challenge):
        fail("INVOCATION_CHALLENGE_MISMATCH", "START challenge is invalid")
    trace: dict[str, Any] = {
        "startNs": integer(start[2], "START time"), "challenge": challenge,
        "limits": [integer(value, "START limit") for value in start[4:]], "events": [],
    }
    expected = 2
    for raw in lines[2:-1]:
        if not raw or raw != raw.strip("\r\n") or len(trace["events"]) >= max_events:
            fail("PROVENANCE_INCOMPLETE", "invalid trace line or event cap exceeded")
        event = _event(raw.split("\t"))
        if event["sequence"] != expected:
            fail("PROVENANCE_INCOMPLETE", f"sequence gap at {expected}")
        trace["events"].append(event)
        expected += 1
    end = lines[-1].split("\t")
    if len(end) != 26 or end[0] != "END" or integer(end[1], "END sequence") != expected:
        fail("PROVENANCE_INCOMPLETE", "malformed END or sequence mismatch")
    labels = ("stops", "taskCount", "lineageEvents", "entries", "exits", "resumedExits",
              "capturedBytes", "pathEvents", "readEvents", "writeEvents", "mmapEvents",
              "openEvents", "closeEvents", "socketEvents", "bindEvents", "execEvents",
              "semanticReadBytes", "dropped")
    end_record = {"sequence": expected, "startNs": integer(end[2], "END start"),
                  "finishNs": integer(end[3], "END finish"), "elapsedNs": integer(end[4], "END elapsed"),
                  **{key: integer(value, f"END {key}") for key, value in zip(labels, end[5:23])},
                  "rootExit": signed(end[23], "root exit"), "violation": end[24], "challenge": end[25]}
    if end_record["startNs"] != trace["startNs"] or end_record["finishNs"] < trace["startNs"] \
            or end_record["elapsedNs"] != end_record["finishNs"] - trace["startNs"]:
        fail("EXTERNAL_TIMING_MISMATCH", "tracer interval does not reconcile")
    if end_record["challenge"] != challenge:
        fail("INVOCATION_CHALLENGE_MISMATCH", "START and END challenges differ")
    trace["end"] = end_record
    return trace


def validate_syscall_grammar(trace: Mapping[str, Any], allowed: Iterable[str]) -> None:
    permitted = set(allowed)
    for event in trace.get("events", []):
        if event.get("type") == "SYSCALL_E" and event.get("name") not in permitted:
            fail("UNSUPPORTED_SYSCALL", str(event.get("name")))


def validate_trace_accounting(trace: Mapping[str, Any], caps: Mapping[str, int],
                              trace_size: int, sidecar_size: int,
                              initial_cwd: str | None = None) -> None:
    end, events = trace["end"], trace["events"]
    order = caps.get("tracerStartLimitOrder")
    if not isinstance(order, list) or trace["limits"] != [caps.get(key) for key in order]:
        fail("PROVENANCE_INCOMPLETE", "START limits differ from frozen caps/order")
    maxima = {"taskCount": "maxTasks", "entries": "maxSyscalls", "pathEvents": "maxPathEvents",
              "readEvents": "maxReadEvents", "writeEvents": "maxWriteEvents", "mmapEvents": "maxMmapEvents",
              "openEvents": "maxOpenEvents", "closeEvents": "maxCloseEvents", "socketEvents": "maxSocketEvents",
              "bindEvents": "maxBindEvents", "execEvents": "maxExecve", "capturedBytes": "maxCapturedBytes"}
    if any(end.get(field, caps[cap] + 1) > caps[cap] for field, cap in maxima.items()) or \
            len(events) > caps["maxEvents"] or trace_size > caps["maxTraceBytes"] or \
            sidecar_size != end["capturedBytes"] or sidecar_size > caps["maxCapturedBytes"]:
        fail("PROVENANCE_INCOMPLETE", "trace, sidecar or event cap differs")
    counts = {"entries": "SYSCALL_E", "exits": "SYSCALL_X", "pathEvents": "PATH",
              "openEvents": "OPEN", "closeEvents": "CLOSE", "readEvents": "READ", "writeEvents": "WRITE",
              "mmapEvents": "MMAP", "socketEvents": "SOCKET", "bindEvents": "BIND", "execEvents": "EXEC",
              "lineageEvents": "LINEAGE"}
    if any(end[field] != sum(event["type"] == kind for event in events) for field, kind in counts.items()):
        fail("PROVENANCE_INCOMPLETE", "END accounting differs")
    resumed = sum(event["type"] == "SYSCALL_X" and event["resumed"] == 1 for event in events)
    semantic = sum(event["returned"] for event in events
                   if event["type"] == "READ" and event["classification"] == "S")
    io_events = [event for event in events if event["type"] in {"READ", "WRITE"}]
    if end["resumedExits"] != resumed or end["semanticReadBytes"] != semantic or \
            semantic > caps["maxSemanticReadBytes"] or any(
                event["returned"] > event["requested"] or event["returned"] > caps["maxSingleReadBytes"]
                for event in io_events):
        fail("PROVENANCE_INCOMPLETE", "IO or resumed accounting differs")
    observed = {event[key] for event in events for key in ("path", "supplied")
                if isinstance(event.get(key), str)}
    if len(observed) > caps["maxObservedPaths"] or any(
            len(path.encode()) > caps["maxPathBytes"] for path in observed):
        fail("PROVENANCE_INCOMPLETE", "observed path cap exceeded")
    ranges = [(event["sidecarOffset"], event["sidecarLength"]) for event in io_events]
    ranges += [(event[key], event[length]) for event in events if event["type"] == "EXEC"
               for key, length in (("argvOffset", "argvLength"), ("envOffset", "envLength"))]
    cursor = 0
    for offset, length in sorted(item for item in ranges if item[1]):
        if offset != cursor or length < 0: fail("PROVENANCE_INCOMPLETE", "sidecar range differs")
        cursor += length
    if cursor != sidecar_size: fail("PROVENANCE_INCOMPLETE", "sidecar coverage differs")
    active: dict[int, dict[str, Any]] = {}; known: set[int] = set(); children: set[int] = set()
    pending: list[tuple[str, dict[str, Any]]] = []; fds: dict[int, dict[int, dict[str, Any]]] = {}
    cwds: dict[int, list[str]] = {}; executables: dict[int, str] = {}
    path_calls = {"access", "chdir", "execve", "lstat", "mkdir", "readlink", "stat",
                  "faccessat2", "newfstatat", "openat", "readlinkat", "statx"}
    at_calls = {"faccessat2", "newfstatat", "openat", "readlinkat", "statx"}

    def signed_fd(value: int) -> int: return value - 2 ** 64 if value >= 2 ** 63 else value

    def fd_entry(tid: int, fd: int) -> dict[str, Any]:
        entry = fds.get(tid, {}).get(fd)
        if entry is None: fail("PROVENANCE_INCOMPLETE", f"unknown fd {fd} for task {tid}")
        return entry

    def bind_object(event: Mapping[str, Any], entry: dict[str, Any]) -> bool:
        identity = entry["object"]
        fields = ("classification", "device", "inode", "path")
        if "path" not in identity: identity.update({key: event.get(key) for key in fields})
        return all(event.get(key) == identity.get(key) for key in fields)

    def resolved_path(event: Mapping[str, Any], call: Mapping[str, Any]) -> str:
        supplied, tid = event.get("supplied"), event["tid"]
        if not isinstance(supplied, str) or "\0" in supplied: fail("PROVENANCE_INCOMPLETE", "invalid supplied path")
        if supplied in {"/proc/self/exe", "/proc/thread-self/exe"}:
            result = executables.get(tid)
            if result is None: fail("PROVENANCE_INCOMPLETE", "exec path unavailable")
            return result
        for prefix in ("/proc/self/fd/", "/proc/thread-self/fd/"):
            if supplied.startswith(prefix) and supplied[len(prefix):].isdigit():
                path = fd_entry(tid, int(supplied[len(prefix):]))["object"].get("path")
                if not isinstance(path, str): fail("PROVENANCE_INCOMPLETE", "descriptor path unavailable")
                return path
        if supplied.startswith("/"): combined = supplied
        else:
            dirfd = signed_fd(call["arguments"][0]) if call["name"] in at_calls else -100
            base = cwds[tid][0] if dirfd == -100 else fd_entry(tid, dirfd)["object"].get("path")
            if not isinstance(base, str) or not base.startswith("/"):
                fail("PROVENANCE_INCOMPLETE", "relative path base unavailable")
            combined = os.path.join(base, supplied)
        return os.path.realpath(combined)

    def require_derived(event: dict[str, Any], expected: tuple[str, dict[str, Any]]) -> None:
        kind, call = expected; args, returned, name = call["arguments"], call["returned"], call["name"]
        if event["type"] != kind or event["tid"] != call["tid"]:
            fail("PROVENANCE_INCOMPLETE", f"missing or displaced {kind} event")
        valid = True
        if kind == "PATH_X":
            valid = event.get("operation") == name and event.get("returned") == returned \
                and event.get("path") == call["path"]
            event["_arguments"], event["_supplied"] = args, call.get("supplied")
        elif kind in {"READ", "WRITE"}:
            valid = event.get("operation") == name and event.get("fd") == args[0] \
                and event.get("requested") == args[2] and event.get("returned") == returned \
                and (name != "pread64" or event.get("offset") == args[3]) \
                and bind_object(event, fd_entry(event["tid"], int(args[0])))
        elif kind == "OPEN":
            valid = event.get("fd") == returned and event.get("flags") == args[2] \
                and event.get("path") == call["path"] and returned not in fds[event["tid"]]
            if valid: fds[event["tid"]][returned] = {"object": {key: event.get(key) for key in
                ("classification", "device", "inode", "path")}, "cloexec": bool(args[2] & 0x80000)}
        elif kind in {"CLOSE", "MMAP"}:
            fd = int(args[0] if kind == "CLOSE" else args[4]); entry = fd_entry(event["tid"], fd)
            valid = bind_object(event, entry) and (event.get("fd") == fd)
            if kind == "CLOSE": valid = valid and event.get("fd") == args[0]
            else: valid = valid and (event.get("address"), event.get("length"), event.get("protection"),
                event.get("flags"), event.get("offset")) == (returned, args[1], args[2], args[3], args[5])
            if valid and kind == "CLOSE": del fds[event["tid"]][fd]
        elif kind == "SOCKET":
            valid = (event.get("fd"), event.get("family"), event.get("socketType"),
                     event.get("protocol")) == (returned, args[0], args[1], args[2])
            if valid and returned >= 0: fds[event["tid"]][returned] = {"object": {},
                "cloexec": bool(args[1] & 0x80000), "socket": (args[0], args[1], args[2])}
        elif kind == "BIND":
            entry = fd_entry(event["tid"], int(args[0]))
            valid = event.get("fd") == args[0] and event.get("returned") == returned \
                and entry.get("socket", (None,))[0] == event.get("family")
        elif kind == "PIPE":
            valid = returned == 0 and event.get("readerFd") != event.get("writerFd") \
                and pipe_path(event.get("path")) and event.get("path") == f"pipe:[{event.get('inode')}]"
            if valid:
                obj = {key: event.get(key) for key in ("classification", "device", "inode", "path")}
                obj["classification"] = "I"
                for fd in (event["readerFd"], event["writerFd"]):
                    if fd in fds[event["tid"]]: valid = False
                    fds[event["tid"]][fd] = {"object": obj, "cloexec": bool(args[1] & 0x80000)}
        elif kind == "DUP":
            source, target = int(args[0]), int(returned); entry = fd_entry(event["tid"], source)
            valid = event.get("operation") == name and event.get("sourceFd") == source and event.get("targetFd") == target \
                and event.get("closeOnExec") == 0 and bind_object(event, entry)
            if name == "dup2": valid = valid and target == args[1]
            else: valid = valid and target >= args[2] and target not in fds[event["tid"]]
            if valid: fds[event["tid"]][target] = {"object": entry["object"], "cloexec": False}
        if not valid: fail("PROVENANCE_INCOMPLETE", f"{kind} does not bind its syscall/descriptor")

    for event in events:
        if pending: require_derived(event, pending.pop(0)); continue
        event_type, tid = event["type"], event["tid"]
        if not known:
            known.add(tid); fds[tid] = {fd: {"object": {"token": f"initial-{fd}"}, "cloexec": False}
                                      for fd in (0, 1, 2)}
            cwds[tid] = [initial_cwd or "/"]
        elif tid not in known: fail("PROVENANCE_INCOMPLETE", "task event precedes observed lineage")
        if event_type == "SYSCALL_E":
            if tid in active: fail("PROVENANCE_INCOMPLETE", "nested syscall entry")
            active[tid] = {**event, "path": None, "supplied": None, "exec": False,
                           "lineage": None, "resumedChild": False}
        elif event_type == "SYSCALL_X":
            call = active.pop(tid, None)
            if call is None or (call["number"], call["name"]) != (event["number"], event["name"]) or \
                    event["isError"] not in {0, 1} or event["resumed"] not in {0, 1} or \
                    event["resumed"] != int(call["resumedChild"]) or bool(event["isError"]) != (event["returned"] < 0):
                fail("PROVENANCE_INCOMPLETE", "syscall entry/exit differs")
            call["returned"] = event["returned"]; name, returned, args = call["name"], call["returned"], call["arguments"]
            if name in path_calls and call["path"] is None: fail("PROVENANCE_INCOMPLETE", f"missing {name} path")
            if name == "execve" and call["exec"] != (returned >= 0): fail("PROVENANCE_INCOMPLETE", "EXEC does not bind execve")
            if not call["resumedChild"] and name in {"clone3", "vfork"}:
                if (returned >= 0) != (call["lineage"] is not None) or call["lineage"] not in {None, returned}:
                    fail("PROVENANCE_INCOMPLETE", "LINEAGE does not bind creation")
            fd_arg = int(args[0])
            if name in {"read", "pread64", "write", "close", "dup2", "fstat", "fstatfs", "fcntl",
                        "lseek", "fadvise64", "getdents64", "getsockname", "getsockopt", "setsockopt", "bind"}:
                fd_entry(tid, fd_arg)
            if name == "fcntl":
                command = args[1]
                if command not in {0, 1, 2} or command == 0 and args[2] != 10 or \
                        command == 2 and args[2] not in {0, 1}: fail("PROVENANCE_INCOMPLETE", "fcntl grammar differs")
                if command == 0 and returned < args[2]:
                    fail("PROVENANCE_INCOMPLETE", "F_DUPFD result differs")
                if command == 1 and returned != int(fd_entry(tid, fd_arg)["cloexec"]):
                    fail("PROVENANCE_INCOMPLETE", "F_GETFD differs")
                if command == 2:
                    if returned != 0: fail("PROVENANCE_INCOMPLETE", "F_SETFD differs")
                    fd_entry(tid, fd_arg)["cloexec"] = bool(args[2])
            if name == "getdents64":
                if args[2] != caps["directoryReadBufferBytes"] or not 0 <= returned <= args[2]:
                    fail("PROVENANCE_INCOMPLETE", "getdents64 grammar differs")
                event["_fdPath"] = fd_entry(tid, fd_arg)["object"].get("path")
            if name == "chdir" and returned == 0: cwds[tid][0] = call["path"]
            if call["path"] is not None: pending.append(("PATH_X", call))
            if name in {"read", "pread64", "write"} and returned > 0: pending.append(("WRITE" if name == "write" else "READ", call))
            elif name == "openat" and returned >= 0: pending.append(("OPEN", call))
            elif name == "close" and returned == 0: pending.append(("CLOSE", call))
            elif name == "mmap" and returned >= 0 and signed_fd(args[4]) >= 0: pending.append(("MMAP", call))
            elif name == "socket": pending.append(("SOCKET", call))
            elif name == "bind": pending.append(("BIND", call))
            elif name == "pipe2" and returned == 0: pending.append(("PIPE", call))
            elif returned >= 0 and (name == "dup2" or name == "fcntl" and args[1] == 0): pending.append(("DUP", call))
        elif event_type == "PATH":
            call = active.get(tid)
            if call is None or call["path"] is not None or call["name"] != event["operation"] or \
                    initial_cwd is not None and resolved_path(event, call) != event["path"]:
                fail("PROVENANCE_INCOMPLETE", "supplied/resolved path differs")
            call["path"], call["supplied"] = event["path"], event["supplied"]
        elif event_type == "EXEC":
            call = active.get(tid)
            if call is None or call["name"] != "execve" or call["exec"]: fail("PROVENANCE_INCOMPLETE", "EXEC differs")
            call["exec"] = True; event["_requestedPath"] = call["supplied"]
            executables[tid] = event["path"]
            fds[tid] = {fd: entry for fd, entry in fds[tid].items() if not entry["cloexec"]}
        elif event_type == "LINEAGE":
            call = active.get(tid); child = event["childTid"]
            if call is None or call["name"] not in {"clone3", "vfork"} or call["lineage"] is not None or \
                    child in known or child in children or event["kind"] not in {"clone_thread", "clone_process", "vfork_process"} or \
                    call["name"] == "vfork" and (event["kind"] != "vfork_process" or event["cloneFlags"] != 0) or \
                    call["name"] == "clone3" and (event["kind"] == "vfork_process" or
                        (event["kind"] == "clone_thread") != bool(event["cloneFlags"] & 0x10000)):
                fail("PROVENANCE_INCOMPLETE", "LINEAGE is not within unique creation")
            call["lineage"] = child; children.add(child); known.add(child)
            fds[child] = fds[tid] if event["cloneFlags"] & 0x400 else {fd: dict(entry) for fd, entry in fds[tid].items()}
            cwds[child] = cwds[tid] if event["cloneFlags"] & 0x200 else list(cwds[tid])
            if tid in executables: executables[child] = executables[tid]
            active[child] = {**call, "tid": child, "path": None, "supplied": None, "exec": False,
                             "lineage": None, "resumedChild": True}
        elif event_type == "EXIT":
            call = active.get(tid)
            if call is not None and call["name"] in {"exit", "exit_group"}: active.pop(tid)
        elif event_type in {"PATH_X", "READ", "WRITE", "OPEN", "CLOSE", "MMAP", "SOCKET", "BIND", "PIPE", "DUP"}:
            fail("PROVENANCE_INCOMPLETE", f"extra {event_type} event")
        if any(len(table) > caps["maxOpenFds"] for table in fds.values()):
            fail("PROVENANCE_INCOMPLETE", "open descriptor cap exceeded")
    if active or pending or sum(event["type"] == "DUP" for event in events) > caps["maxDupEvents"]:
        fail("PROVENANCE_INCOMPLETE", "unmatched syscall, derived event or duplicate cap")


def pipe_path(path: Any) -> bool:
    return isinstance(path, str) and path.startswith("pipe:[") and path.endswith("]") \
        and path[6:-1].isdigit()


def internal_pipe_paths(events: Sequence[Mapping[str, Any]]) -> set[str]:
    return {event["path"] for event in events
            if event.get("type") == "PIPE" and pipe_path(event.get("path"))}


def validate_internal_pipe(events: Sequence[Mapping[str, Any]], sidecar: bytes,
                           expected: bytes, contract: Mapping[str, Any]) -> set[str]:
    pipes = [event for event in events if event.get("type") == "PIPE"]
    internal = internal_pipe_paths(events)
    if len(pipes) != contract["count"] or len(internal) != contract["count"]:
        fail("PROCESS_LINEAGE_MISMATCH", "internal pipe count differs")
    for pipe in pipes:
        path = pipe["path"]
        related = [event for event in events if event.get("path") == path]
        reads = [event for event in related if event["type"] == "READ"]
        writes = [event for event in related if event["type"] == "WRITE"]
        closes = [event for event in related if event["type"] == "CLOSE"]
        producer_execs = [event for event in events if event.get("type") == "EXEC"
                          and event.get("_requestedPath") == "/usr/bin/xdg-user-dir"
                          and event.get("path") == str(Path("/bin/sh").resolve())]
        dup2_exits = [event for event in events if event.get("type") == "SYSCALL_X"
                      and event.get("tid") == (writes[0].get("tid") if writes else None)
                      and event.get("name") == "dup2" and event.get("returned") == contract["producerFd"]]
        dup2_entries = [event for event in events if event.get("type") == "SYSCALL_E"
                        and event.get("tid") == (writes[0].get("tid") if writes else None)
                        and event.get("name") == "dup2"
                        and event.get("arguments", [])[:2] == [pipe["writerFd"], contract["producerFd"]]]
        parents = {event["childTid"]: event["tid"] for event in events
                   if event.get("type") == "LINEAGE"}
        ancestor = writes[0].get("tid") if len(writes) == 1 else None
        ancestry: set[int] = set()
        while ancestor in parents and ancestor not in ancestry:
            ancestor = parents[ancestor]; ancestry.add(ancestor)
        identities = {(event.get("device"), event.get("inode")) for event in reads + writes + closes}
        identity = (pipe.get("device"), pipe.get("inode"))
        if pipe.get("readerFd") != contract["consumerFd"] or \
                pipe.get("writerFd") not in contract["closedFds"] or \
                path != f"pipe:[{pipe.get('inode')}]" or len(reads) != 1 or len(writes) != 1 or \
                len(closes) != 2 or identities != {identity} or \
                reads[0].get("fd") != contract["consumerFd"] or \
                writes[0].get("fd") != contract["producerFd"] or \
                reads[0].get("tid") != pipe.get("tid") or \
                len(producer_execs) != 1 or writes[0].get("tid") != producer_execs[0].get("tid") or \
                pipe.get("tid") not in ancestry or \
                producer_execs[0].get("sequence", 0) >= writes[0].get("sequence", 0) or \
                len(dup2_entries) != 1 or len(dup2_exits) != 1 or \
                not dup2_entries[0]["sequence"] < dup2_exits[0]["sequence"] < writes[0]["sequence"] or \
                sorted(event.get("fd") for event in closes) != contract["closedFds"] or \
                any(event.get("tid") != pipe.get("tid") for event in closes) or \
                any(event.get("classification") != "I" for event in reads + writes + closes) or any(
                    sidecar[event["sidecarOffset"]:event["sidecarOffset"] + event["returned"]] != expected
                    for event in reads + writes):
            fail("PROCESS_LINEAGE_MISMATCH", "internal pipe evidence differs")
    if any(event.get("type") == "CLOSE" and pipe_path(event.get("path"))
           and event.get("path") not in internal for event in events):
        fail("PROCESS_LINEAGE_MISMATCH", "undeclared pipe close")
    return internal


def validate_request_indices(indices: Any, caps: Mapping[str, int], requested: str) -> None:
    if not isinstance(indices, list) or not indices or len(indices) > caps["maxPacketRequests"] or any(
            not isinstance(value, str) or not value.isascii() or not value.isdecimal()
            or str(int(value)) != value or int(value) > caps["maxRequestIndex"] for value in indices) or \
            len(set(indices)) != len(indices) or requested not in indices:
        fail("REQUEST_INDEX_MISMATCH", "packet request index contract differs")


def validate_failed_paths(events: Sequence[Mapping[str, Any]], known: set[str],
                          role_paths: set[str], roots: Mapping[str, str],
                          grammar: Mapping[str, Any]) -> None:
    def expand(template: str) -> str:
        result = template
        for key, value in roots.items(): result = result.replace("${" + key + "}", value)
        return result

    exact = {(operation, record.get("returned"), expand(path))
             for record in grammar.get("exact", []) if isinstance(record, dict)
             for operation in record.get("operations", []) for path in record.get("paths", [])}
    suffixes = grammar.get("roleSuffixOperations", {})
    cache_dirs = {expand(path) for path in grammar.get("fontCacheDirectories", [])}
    cache_names = set(grammar.get("fontCacheBasenames", []))
    readlink_directories = {
        expand(path) for path in grammar.get("readlinkKnownDirectories", [])}
    for event in events:
        if event.get("type") != "PATH_X" or event.get("returned", 0) >= 0: continue
        operation, returned, path = event.get("operation"), event.get("returned"), event.get("path")
        arguments = event.get("_arguments", [])
        admitted = (operation, returned, path) in exact
        if operation == "readlink" and returned == grammar.get("readlinkKnownReturn"):
            root_ancestor = any(
                isinstance(root, str) and path != root
                and root.startswith(path.rstrip("/") + "/")
                for root in roots.values())
            admitted = admitted or path in known or path in readlink_directories or root_ancestor
        if returned == -2:
            admitted = admitted or any(path == role + suffix and operation in operations
                                       for role in role_paths for suffix, operations in suffixes.items())
            admitted = admitted or Path(path).parent.as_posix() in cache_dirs \
                and Path(path).name in cache_names and operation == "openat"
        if operation == "mkdir" and returned == -17:
            home = roots.get("HOME", ""); admitted = bool(home) and path == home \
                and len(arguments) > 1 and arguments[1] == grammar.get("mkdirMode")
        if admitted and operation == "openat":
            flags = arguments[2] if len(arguments) > 2 else None
            if path == f"{roots.get('OUTPUT')}/observation.json": admitted = flags == grammar.get("deniedOutputOpenFlags")
            elif path in {"/dev/input/event0", "/dev/input/event1"}: admitted = flags == grammar.get("deviceOpenFlags")
            else: admitted = flags in grammar.get("readOnlyOpenFlags", [])
        if not admitted:
            reason = "UNDECLARED_CACHE_ACCESS" if path.startswith(roots.get("HOME", "") + "/") else "UNDECLARED_INPUT_PATH"
            fail(reason, f"unfrozen failed path {operation} {returned} {path}")


def validate_complete_role_reads(events: Sequence[Mapping[str, Any]], expected: bytes, sidecar: bytes) -> None:
    covered = bytearray(len(expected))
    for event in events:
        offset, count = integer(event.get("offset"), "read offset"), integer(event.get("returned"), "read length")
        side_offset = integer(event.get("sidecarOffset"), "sidecar offset")
        if count != integer(event.get("sidecarLength"), "sidecar length") or offset + count > len(expected):
            fail("PROVENANCE_INCOMPLETE", "semantic read range is invalid")
        actual = sidecar[side_offset:side_offset + count]
        if len(actual) != count or actual != expected[offset:offset + count]:
            fail("SEMANTIC_BYTES_MISMATCH", "captured read bytes differ from role")
        covered[offset:offset + count] = b"\1" * count
    if any(byte == 0 for byte in covered):
        fail("CURRENT_CONSUMPTION_MISSING", "semantic role lacks complete current reads")


def reject_semantic_mappings(mappings: Sequence[Mapping[str, Any]], semantic_paths: set[str]) -> None:
    for mapping in mappings:
        if mapping.get("path") in semantic_paths:
            fail("SEMANTIC_MAPPING_DENIED", str(mapping.get("path")))
