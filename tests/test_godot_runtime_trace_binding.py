#!/usr/bin/env python3
"""Focused syscall-derived-event and anonymous-pipe binding regressions."""
from __future__ import annotations

import hashlib
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VERIFY = ROOT / "tools/execution_provenance/godot_runtime_verify.py"
PROFILE = ROOT / "tools/execution_provenance/godot_runtime_profile.json"
CHALLENGE = "a" * 64


def load_verifier():
    spec = importlib.util.spec_from_file_location("godot_runtime_verify_binding", VERIFY)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class TraceBindingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.verifier = load_verifier()
        cls.contract = json.loads(PROFILE.read_text(encoding="utf-8"))["accessGrammar"]["internalPipe"]

    def accounting_fixture(self, raw_events: list[str]) -> tuple[dict, dict]:
        start = "\t".join(["START", "1", "100", CHALLENGE, *(["1"] * 17)])
        end = "\t".join(["END", str(len(raw_events) + 2), "100", "200", "100",
                          *(["0"] * 18), "0", "-", CHALLENGE])
        trace = self.verifier.parse_trace_lines(["GODOTTRACEv1", start, *raw_events, end], 32)
        kinds = [event["type"] for event in trace["events"]]
        for field, kind in {"entries": "SYSCALL_E", "exits": "SYSCALL_X",
                            "pathEvents": "PATH", "openEvents": "OPEN",
                            "closeEvents": "CLOSE", "readEvents": "READ",
                            "writeEvents": "WRITE", "mmapEvents": "MMAP",
                            "socketEvents": "SOCKET", "bindEvents": "BIND",
                            "execEvents": "EXEC", "lineageEvents": "LINEAGE"}.items():
            trace["end"][field] = kinds.count(kind)
        trace["end"]["taskCount"] = 1
        order = ["hardTaskCapacity", "maxSingleReadBytes", "maxCapturedBytes", "maxSyscalls",
                 "maxPathEvents", "maxReadEvents", "maxWriteEvents", "maxMmapEvents",
                 "maxOpenFds", "maxSemanticReadBytes", "maxTraceBytes", "maxOpenEvents",
                 "maxCloseEvents", "maxSocketEvents", "maxBindEvents", "maxExecve",
                 "validLineageEvents"]
        caps = {key: 1 for key in order}
        caps.update(tracerStartLimitOrder=order, maxTasks=1, maxEvents=32,
                    maxObservedPaths=8, maxPathBytes=4096)
        return trace, caps

    def test_missing_or_inserted_derived_event_fails_closed(self) -> None:
        entered = "SYSCALL_E\t2\t1001\t257\topenat\t0\t0\t0\t0\t0\t0"
        exited = "SYSCALL_X\t3\t1001\t257\topenat\t5\t0\t0"
        opened = "OPEN\t4\t1001\t5\t0\tI\t1\t2\t2f746d702f78"
        trace, caps = self.accounting_fixture([entered, exited, opened])
        self.verifier.validate_trace_accounting(trace, caps, 1, 0)
        trace, caps = self.accounting_fixture([entered, exited])
        with self.assertRaisesRegex(self.verifier.VerificationFailure, "missing|unmatched"):
            self.verifier.validate_trace_accounting(trace, caps, 1, 0)
        trace, caps = self.accounting_fixture([opened.replace("\t4\t", "\t2\t", 1)])
        with self.assertRaisesRegex(self.verifier.VerificationFailure, "extra"):
            self.verifier.validate_trace_accounting(trace, caps, 1, 0)

    def pipe_events(self) -> tuple[list[dict], bytes]:
        payload = b"/fresh/home/Desktop\n"
        identity = {"classification": "I", "device": 1, "inode": 42, "path": "pipe:[42]"}
        events = [
            {"type": "PIPE", "sequence": 1, "tid": 100, "readerFd": 3, "writerFd": 4,
             "device": 1, "inode": 42, "path": "pipe:[42]"},
            {"type": "SYSCALL_E", "sequence": 2, "tid": 200, "name": "dup2",
             "arguments": [4, 1, 0, 0, 0, 0]},
            {"type": "SYSCALL_X", "sequence": 3, "tid": 200, "name": "dup2", "returned": 1},
            {"type": "EXEC", "sequence": 4, "tid": 200, "path": "/usr/bin/xdg-user-dir"},
            {**identity, "type": "WRITE", "sequence": 5, "tid": 200, "fd": 1,
             "returned": len(payload), "sidecarOffset": 0},
            {**identity, "type": "READ", "sequence": 6, "tid": 100, "fd": 3,
             "returned": len(payload), "sidecarOffset": len(payload)},
            {**identity, "type": "CLOSE", "sequence": 7, "tid": 100, "fd": 4},
            {**identity, "type": "CLOSE", "sequence": 8, "tid": 100, "fd": 3},
        ]
        return events, payload

    def test_pipe_identity_topology_and_stream_separation(self) -> None:
        events, payload = self.pipe_events()
        self.verifier._validate_internal_pipe(events, payload * 2, payload, self.contract)
        outer = {"type": "WRITE", "fd": 1, "path": "pipe:[43]", "returned": 5,
                 "sidecarOffset": len(payload) * 2}
        self.assertEqual(b"outer", self.verifier._stream_bytes(events + [outer], 1, payload * 2 + b"outer"))
        events[0]["path"] = "pipe:[43]"
        with self.assertRaisesRegex(self.verifier.VerificationFailure, "PROCESS_LINEAGE_MISMATCH"):
            self.verifier._validate_internal_pipe(events, payload * 2, payload, self.contract)
        events[0]["path"] = "pipe:[42]"; events[1]["arguments"][0] = 5
        with self.assertRaisesRegex(self.verifier.VerificationFailure, "PROCESS_LINEAGE_MISMATCH"):
            self.verifier._validate_internal_pipe(events, payload * 2, payload, self.contract)

    def test_tracer_identity_is_recomputed_from_live_sources_and_binary(self) -> None:
        with tempfile.TemporaryDirectory(prefix="godot-tracer-identity-") as temporary:
            root = Path(temporary)
            paths = {
                "sourceSha256": root / "godot_runtime_ptrace_tracer.c",
                "ioSourceSha256": root / "godot_runtime_ptrace_io.c",
                "ioHeaderSha256": root / "godot_runtime_ptrace_io.h",
                "binarySha256": root / "godot-runtime-tracer",
            }
            for index, path in enumerate(paths.values()):
                path.write_bytes(f"trusted-{index}".encode())
            tracer = {key: hashlib.sha256(path.read_bytes()).hexdigest()
                      for key, path in paths.items()}
            tracer["returncode"] = 0
            self.verifier._TRACE.validate_tracer_identity(
                tracer, root, paths["binarySha256"])
            tracer["binarySha256"] = "0" * 64
            with self.assertRaisesRegex(
                    self.verifier.VerificationFailure, "binarySha256 differs"):
                self.verifier._TRACE.validate_tracer_identity(
                    tracer, root, paths["binarySha256"])


if __name__ == "__main__":
    unittest.main()
