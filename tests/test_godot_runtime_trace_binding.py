#!/usr/bin/env python3
"""Focused syscall-derived-event and anonymous-pipe binding regressions."""
from __future__ import annotations

import hashlib
import importlib.util
import json
import os
import tempfile
import types
import unittest
from pathlib import Path
from unittest import mock

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
        cls.profile = json.loads(PROFILE.read_text(encoding="utf-8"))
        cls.contract = cls.profile["accessGrammar"]["internalPipe"]

    def accounting_fixture(self, raw_events: list[str]) -> tuple[dict, dict]:
        root_tid = raw_events[0].split("\t")[2] if raw_events else "100"
        null_identity = os.stat("/dev/null")
        preamble = [
            f"POLICY\t2\t{root_tid}\t1\t1\t1",
            f"INITIAL_FD\t3\t{root_tid}\t0\t0\t{null_identity.st_dev}\t"
            f"{null_identity.st_ino}\t2f6465762f6e756c6c",
            f"INITIAL_FD\t4\t{root_tid}\t1\t1\t1\t11\t706970653a5b31315d",
            f"INITIAL_FD\t5\t{root_tid}\t2\t1\t1\t12\t706970653a5b31325d",
        ]
        shifted = []
        for raw in raw_events:
            fields = raw.split("\t")
            fields[1] = str(int(fields[1]) + 4)
            shifted.append("\t".join(fields))
        raw_events = preamble + shifted
        start = "\t".join(["START", "1", "100", CHALLENGE, *(["1"] * 20)])
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
        trace["end"]["resumedExits"] = sum(
            event.get("resumed") == 1 for event in trace["events"])
        tasks = {event["tid"] for event in trace["events"]}
        tasks.update(event["childTid"] for event in trace["events"]
                     if event["type"] == "LINEAGE")
        trace["end"]["taskCount"] = len(tasks)
        order = ["hardTaskCapacity", "maxAddressSpaceBytes", "maxInitialStackBytes",
                 "maxSingleReadBytes", "maxCapturedBytes", "maxSyscalls",
                 "maxPathEvents", "maxReadEvents", "maxWriteEvents", "maxMmapEvents",
                 "maxOpenFds", "maxSemanticReadBytes", "maxTraceBytes", "maxOpenEvents",
                 "maxCloseEvents", "maxSocketEvents", "maxBindEvents", "maxExecve",
                 "maxDupEvents", "validLineageEvents"]
        caps = {key: 64 for key in order}
        caps.update(tracerStartLimitOrder=order, maxTasks=16, maxEvents=64,
                    maxOpenFds=8,
                    maxObservedPaths=8, maxPathBytes=4096,
                    maxAdmissionPolicyBytes=64, maxAdmissionFileRules=64,
                    maxAdmissionPathRules=64)
        trace["limits"] = [caps[key] for key in order]
        return trace, caps

    def test_initial_descriptors_bind_live_null_and_three_distinct_objects(self) -> None:
        trace, caps = self.accounting_fixture(self.opened_fd_events())
        self.verifier.validate_trace_accounting(trace, caps, 1, 0)
        trace["events"][1]["inode"] += 1
        with self.assertRaisesRegex(
                self.verifier.VerificationFailure, "initial descriptor boundary"):
            self.verifier.validate_trace_accounting(trace, caps, 1, 0)
        trace, caps = self.accounting_fixture(self.opened_fd_events())
        trace["events"][1]["device"] = trace["events"][2]["device"]
        trace["events"][1]["inode"] = trace["events"][2]["inode"]
        with self.assertRaisesRegex(
                self.verifier.VerificationFailure, "initial descriptor boundary"):
            self.verifier.validate_trace_accounting(trace, caps, 1, 0)

    def test_zero_extended_anonymous_mmap_fd_does_not_require_mmap_event(self) -> None:
        self.assertEqual(-1, self.verifier._TRACE.decode_syscall_fd(0xFFFFFFFF))
        self.assertEqual(-1, self.verifier._TRACE.decode_syscall_fd(0xFFFFFFFFFFFFFFFF))
        self.assertEqual(-100, self.verifier._TRACE.decode_syscall_fd(0xFFFFFF9C))
        self.assertEqual(-100, self.verifier._TRACE.decode_syscall_fd(0xFFFFFFFFFFFFFF9C))
        self.assertEqual(3, self.verifier._TRACE.decode_syscall_fd(3))
        entered = (
            "SYSCALL_E\t2\t1001\t9\tmmap\t0\t8192\t3\t34\t4294967295\t0")
        exited = "SYSCALL_X\t3\t1001\t9\tmmap\t4096\t0\t0"
        trace, caps = self.accounting_fixture([entered, exited])
        self.verifier.validate_trace_accounting(trace, caps, 1, 0)
        entered64 = (
            "SYSCALL_E\t2\t1001\t9\tmmap\t0\t8192\t3\t34\t"
            "18446744073709551615\t0")
        trace, caps = self.accounting_fixture([entered64, exited])
        self.verifier.validate_trace_accounting(trace, caps, 1, 0)

    def test_missing_or_inserted_derived_event_fails_closed(self) -> None:
        entered = "SYSCALL_E\t2\t1001\t257\topenat\t18446744073709551516\t0\t0\t0\t0\t0"
        path = "PATH\t3\t1001\topenat\t2f746d702f78\t2f746d702f78"
        exited = "SYSCALL_X\t4\t1001\t257\topenat\t5\t0\t0"
        path_exit = "PATH_X\t5\t1001\topenat\t5\t2f746d702f78"
        opened = "OPEN\t6\t1001\t5\t0\tI\t1\t2\t2f746d702f78"
        trace, caps = self.accounting_fixture([entered, path, exited, path_exit, opened])
        self.verifier.validate_trace_accounting(trace, caps, 1, 0)
        trace, caps = self.accounting_fixture([entered, path, exited, path_exit])
        with self.assertRaisesRegex(self.verifier.VerificationFailure, "missing|unmatched"):
            self.verifier.validate_trace_accounting(trace, caps, 1, 0)
        trace, caps = self.accounting_fixture([opened.replace("\t6\t", "\t2\t", 1)])
        with self.assertRaisesRegex(self.verifier.VerificationFailure, "extra"):
            self.verifier.validate_trace_accounting(trace, caps, 1, 0)

    def test_no_follow_navigation_path_binds_to_canonical_dirfd_parent(self) -> None:
        with tempfile.TemporaryDirectory(prefix="godot-trace-dirfd-") as temporary:
            parent = Path(temporary).resolve()
            child = parent / "child"
            child.mkdir()
            leaf = child / "leaf"
            leaf.write_bytes(b"leaf")
            child_hex = str(child).encode().hex()
            for supplied, resolved in (
                    (".", child), ("./", child), ("..", parent), ("../", parent),
                    ("leaf", leaf), ("leaf/", leaf)):
                with self.subTest(supplied=supplied):
                    supplied_hex = supplied.encode().hex()
                    resolved_hex = str(resolved).encode().hex()
                    events = [
                        "SYSCALL_E\t2\t100\t257\topenat\t18446744073709551516\t0\t0\t0\t0\t0",
                        f"PATH\t3\t100\topenat\t{child_hex}\t{child_hex}",
                        "SYSCALL_X\t4\t100\t257\topenat\t5\t0\t0",
                        f"PATH_X\t5\t100\topenat\t5\t{child_hex}",
                        f"OPEN\t6\t100\t5\t0\tI\t1\t21\t{child_hex}",
                        "SYSCALL_E\t7\t100\t257\topenat\t5\t0\t2818048\t0\t0\t0",
                        f"PATH\t8\t100\topenat\t{supplied_hex}\t{resolved_hex}",
                        "SYSCALL_X\t9\t100\t257\topenat\t6\t0\t0",
                        f"PATH_X\t10\t100\topenat\t6\t{resolved_hex}",
                        f"OPEN\t11\t100\t6\t2818048\tI\t1\t20\t{resolved_hex}",
                    ]
                    trace, caps = self.accounting_fixture(events)
                    self.verifier.validate_trace_accounting(
                        trace, caps, 1, 0, initial_cwd=str(parent))
                    trace["events"][10]["path"] = (
                        f"{child}/./leaf" if supplied.rstrip("/") == "leaf"
                        else f"{child}/{supplied}")
                    with self.assertRaisesRegex(
                            self.verifier.VerificationFailure,
                            "supplied/resolved path differs"):
                        self.verifier.validate_trace_accounting(
                            trace, caps, 1, 0, initial_cwd=str(parent))

    @staticmethod
    def opened_fd_events() -> list[str]:
        path = "2f746d702f78"
        return [
            "SYSCALL_E\t2\t100\t257\topenat\t18446744073709551516\t0\t0\t0\t0\t0",
            f"PATH\t3\t100\topenat\t{path}\t{path}",
            "SYSCALL_X\t4\t100\t257\topenat\t5\t0\t0",
            f"PATH_X\t5\t100\topenat\t5\t{path}",
            f"OPEN\t6\t100\t5\t0\tI\t1\t2\t{path}",
        ]

    def test_fcntl_duplicate_and_close_on_exec_state_are_descriptor_bound(self) -> None:
        path = "2f746d702f78"
        events = self.opened_fd_events() + [
            "SYSCALL_E\t7\t100\t72\tfcntl\t5\t0\t10\t0\t0\t0",
            "SYSCALL_X\t8\t100\t72\tfcntl\t10\t0\t0",
            f"DUP\t9\t100\tfcntl\t5\t10\t0\tI\t1\t2\t{path}",
            "SYSCALL_E\t10\t100\t72\tfcntl\t10\t2\t1\t0\t0\t0",
            "SYSCALL_X\t11\t100\t72\tfcntl\t0\t0\t0",
            "SYSCALL_E\t12\t100\t72\tfcntl\t10\t1\t0\t0\t0\t0",
            "SYSCALL_X\t13\t100\t72\tfcntl\t1\t0\t0",
        ]
        trace, caps = self.accounting_fixture(events)
        self.verifier.validate_trace_accounting(trace, caps, 1, 0)
        events[7] = events[7].replace("\t10\t0\tI", "\t9\t0\tI")
        trace, caps = self.accounting_fixture(events)
        with self.assertRaisesRegex(self.verifier.VerificationFailure, "descriptor"):
            self.verifier.validate_trace_accounting(trace, caps, 1, 0)

    def test_clone_files_child_close_removes_the_parent_descriptor(self) -> None:
        path = "2f746d702f78"
        shared = self.opened_fd_events() + [
            "SYSCALL_E\t7\t100\t435\tclone3\t0\t8\t0\t0\t0\t0",
            "LINEAGE\t8\t100\t200\tclone_thread\t66560",
            "SYSCALL_X\t9\t100\t435\tclone3\t200\t0\t0",
            "SYSCALL_X\t10\t200\t435\tclone3\t0\t0\t1",
            "SYSCALL_E\t11\t200\t3\tclose\t5\t0\t0\t0\t0\t0",
            "SYSCALL_X\t12\t200\t3\tclose\t0\t0\t0",
            f"CLOSE\t13\t200\t5\tI\t1\t2\t{path}",
        ]
        trace, caps = self.accounting_fixture(shared)
        self.verifier.validate_trace_accounting(trace, caps, 1, 0)
        reused = shared + [
            "SYSCALL_E\t14\t100\t72\tfcntl\t5\t1\t0\t0\t0\t0",
            "SYSCALL_X\t15\t100\t72\tfcntl\t0\t0\t0",
        ]
        trace, caps = self.accounting_fixture(reused)
        with self.assertRaisesRegex(self.verifier.VerificationFailure, "unknown fd"):
            self.verifier.validate_trace_accounting(trace, caps, 1, 0)

    def test_clone_process_child_may_enter_a_fresh_syscall_before_parent_exit(self) -> None:
        events = [
            "SYSCALL_E\t2\t100\t435\tclone3\t0\t8\t0\t0\t0\t0",
            "LINEAGE\t3\t100\t200\tclone_process\t16640",
            "SYSCALL_E\t4\t200\t14\trt_sigprocmask\t0\t0\t0\t0\t0\t0",
            "SYSCALL_X\t5\t200\t14\trt_sigprocmask\t0\t0\t0",
            "SYSCALL_X\t6\t100\t435\tclone3\t200\t0\t0",
        ]
        trace, caps = self.accounting_fixture(events)
        self.verifier.validate_trace_accounting(trace, caps, 1, 0)

    def test_clone_thread_child_may_enter_a_fresh_syscall_after_parent_exit(self) -> None:
        events = [
            "SYSCALL_E\t2\t100\t435\tclone3\t0\t8\t0\t0\t0\t0",
            "LINEAGE\t3\t100\t200\tclone_thread\t65536",
            "SYSCALL_X\t4\t100\t435\tclone3\t200\t0\t0",
            "SYSCALL_E\t5\t200\t334\trseq\t0\t0\t0\t0\t0\t0",
            "SYSCALL_X\t6\t200\t334\trseq\t0\t0\t0",
        ]
        trace, caps = self.accounting_fixture(events)
        self.verifier.validate_trace_accounting(trace, caps, 1, 0)

    def pipe_events(self) -> tuple[list[dict], bytes]:
        payload = b"/fresh/home/Desktop\n"
        identity = {"classification": "I", "device": 1, "inode": 42, "path": "pipe:[42]"}
        interpreter = str(Path("/bin/sh").resolve())
        events = [
            {"type": "PIPE", "sequence": 1, "tid": 100, "readerFd": 3, "writerFd": 4,
             "device": 1, "inode": 42, "path": "pipe:[42]"},
            {"type": "LINEAGE", "sequence": 2, "tid": 100, "childTid": 200,
             "kind": "clone_process"},
            {"type": "SYSCALL_E", "sequence": 3, "tid": 200, "name": "dup2",
             "arguments": [4, 1, 0, 0, 0, 0]},
            {"type": "SYSCALL_X", "sequence": 4, "tid": 200, "name": "dup2", "returned": 1},
            {"type": "EXEC", "sequence": 5, "tid": 200, "path": interpreter,
             "_requestedPath": "/bin/sh"},
            {"type": "LINEAGE", "sequence": 6, "tid": 200, "childTid": 300,
             "kind": "vfork_process"},
            {"type": "EXEC", "sequence": 7, "tid": 300, "path": interpreter,
             "_requestedPath": "/usr/bin/xdg-user-dir"},
            {**identity, "type": "WRITE", "sequence": 8, "tid": 300, "fd": 1,
             "returned": len(payload), "sidecarOffset": 0},
            {**identity, "type": "READ", "sequence": 9, "tid": 100, "fd": 3,
             "returned": len(payload), "sidecarOffset": len(payload)},
            {**identity, "type": "CLOSE", "sequence": 10, "tid": 100, "fd": 4},
            {**identity, "type": "CLOSE", "sequence": 11, "tid": 100, "fd": 3},
        ]
        return events, payload

    def test_pipe_identity_topology_and_stream_separation(self) -> None:
        events, payload = self.pipe_events()
        self.verifier._validate_internal_pipe(events, payload * 2, payload, self.contract)
        outer = {"type": "WRITE", "fd": 1, "path": "pipe:[43]", "returned": 5,
                 "sidecarOffset": len(payload) * 2}
        self.assertEqual(b"outer", self.verifier._stream_bytes(events + [outer], 1, payload * 2 + b"outer"))
        events[0]["path"] = "pipe:[43]"
        with self.assertRaisesRegex(self.verifier.VerificationFailure, "internal pipe evidence differs"):
            self.verifier._validate_internal_pipe(events, payload * 2, payload, self.contract)
        events[0]["path"] = "pipe:[42]"; events[1]["childTid"] = 201
        with self.assertRaisesRegex(self.verifier.VerificationFailure, "internal pipe evidence differs"):
            self.verifier._validate_internal_pipe(events, payload * 2, payload, self.contract)
        events[1]["childTid"] = 200; events[2]["arguments"][0] = 5
        with self.assertRaisesRegex(self.verifier.VerificationFailure, "internal pipe evidence differs"):
            self.verifier._validate_internal_pipe(events, payload * 2, payload, self.contract)

    def test_writer_dup2_without_shell_is_process_lineage_mismatch(self) -> None:
        events, payload = self.pipe_events()
        for event in events:
            if event.get("name") == "dup2":
                event["tid"] = 300
        with self.assertRaisesRegex(
                self.verifier.VerificationFailure, "internal pipe evidence differs"):
            self.verifier._validate_internal_pipe(
                events, payload * 2, payload, self.contract)

    def test_outer_stdout_pipe_close_is_not_undeclared_internal_pipe(self) -> None:
        events, payload = self.pipe_events()
        events.append({
            "type": "CLOSE", "sequence": 12, "tid": 100, "fd": 1,
            "classification": "I", "device": 2, "inode": 99, "path": "pipe:[99]",
        })
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
            contract = self.profile["kernelAdmission"]
            tracer["kernelAdmission"] = {
                "schema": contract["schema"], "landlockAbi": 6,
                "minimumAbi": contract["minimumAbi"],
                "handledAccessFs": contract["handledAccessFs"],
                "writeSubtrees": len(contract["writeSubtrees"]),
                "namedWriteFiles": len(contract["namedWriteFiles"]),
                "policySchema": contract["policySchema"],
                "fileRuleCapacity": self.profile["caps"]["maxAdmissionFileRules"],
                "pathRuleCapacity": self.profile["caps"]["maxAdmissionPathRules"],
                "policyByteCapacity": contract["policyByteCapacity"],
                "descriptorSanitisation": True,
                "noNewPrivileges": True,
            }
            self.verifier._TRACE.validate_tracer_identity(
                tracer, root, paths["binarySha256"], contract)
            tracer["binarySha256"] = "0" * 64
            with self.assertRaisesRegex(
                self.verifier.VerificationFailure, "binarySha256 differs"):
                self.verifier._TRACE.validate_tracer_identity(
                    tracer, root, paths["binarySha256"], contract)

    def test_case_members_are_bounded_before_parse_or_receipt_capture(self) -> None:
        with tempfile.TemporaryDirectory(prefix="godot-case-cap-") as temporary:
            case = Path(temporary) / "G00"; case.mkdir()
            for name in ("statement.json", "trace.tsv", "sidecar.bin", "stdout.bin",
                         "admission-policy.tsv"):
                (case / name).write_bytes(b"{}" if name == "statement.json" else b"")
            members, _ = self.verifier._preflight_case_members(
                case, self.profile["caps"])
            self.assertEqual(5, len(members))
            statement = case / "statement.json"
            statement.write_bytes(b"replacement")
            self.assertEqual(b"{}", members["statement.json"])
            statement.write_bytes(b"x" * (self.profile["caps"]["maxStatementBytes"] + 1))
            with self.assertRaisesRegex(self.verifier.VerificationFailure, "exceeds its cap"):
                self.verifier._preflight_case_members(case, self.profile["caps"])
            capture = self.verifier._capture_record(
                statement, self.profile["caps"]["maxStatementBytes"])
            self.assertFalse(capture["bounded"]); self.assertNotIn("sha256", capture)
            statement.write_bytes(b"{}")
            sidecar = case / "sidecar.bin"; sidecar.unlink()
            sidecar.symlink_to(statement)
            with self.assertRaisesRegex(self.verifier.VerificationFailure, "regular and non-symlink"):
                self.verifier._preflight_case_members(case, self.profile["caps"])

    def test_challenge_read_is_bounded_and_rejects_symlinks(self) -> None:
        with tempfile.TemporaryDirectory(prefix="godot-challenge-cap-") as temporary:
            root = Path(temporary); challenge = root / "challenge.txt"
            challenge.write_bytes(b"a" * (self.profile["caps"]["maxChallengeBytes"] + 1))
            with self.assertRaisesRegex(self.verifier.VerificationFailure, "exceeds its cap"):
                self.verifier._read_challenge(
                    challenge, self.profile["caps"]["maxChallengeBytes"])
            target = root / "target.txt"; target.write_text(CHALLENGE + "\n", encoding="ascii")
            challenge.unlink(); challenge.symlink_to(target)
            with self.assertRaises(self.verifier.VerificationFailure):
                self.verifier._read_challenge(
                    challenge, self.profile["caps"]["maxChallengeBytes"])
        complete_body = VERIFY.read_text(encoding="utf-8").split(
            "def _complete", 1)[1].split("def _identity_summary", 1)[0]
        self.assertNotIn("_read_challenge(", complete_body)

    def test_output_records_are_bound_to_exact_live_and_case_paths(self) -> None:
        statement = {
            "roots": {"HOME": "/fresh/home", "OUTPUT": "/fresh/output"},
            "streams": {},
            "outputs": {
                "observation": {"present": False, "path": "/fresh/output/observation.json", "file": "observation.json"},
                "homeLog": {"present": False, "path": "/fresh/home/.local/share/godot/app_userdata/Glassvow/logs/godot.log", "file": "home-godot.log"},
                "sentry": {"present": False, "path": "/fresh/home/.local/share/godot/app_userdata/Glassvow/sentry.dat", "file": "home-sentry.dat"},
            },
        }
        self.assertEqual({}, self.verifier._output_records(statement, Path("/case")))
        statement["outputs"]["observation"]["file"] = "../outside"
        with self.assertRaisesRegex(self.verifier.VerificationFailure, "binding differs"):
            self.verifier._output_records(statement, Path("/case"))

    def test_diagnostic_reason_cannot_hide_an_invalid_object_boundary(self) -> None:
        args = types.SimpleNamespace(
            case_id="G15", case_dir=Path("/case"), packet_manifest=Path("/packet/manifest.json"),
            request_index="0")
        roots = {"GODOT": "/godot", "PRODUCT": "/product", "PACKET": "/packet",
                 "HOME": "/home", "OUTPUT": "/output"}
        statement = {
            "schema": self.verifier.STATEMENT_SCHEMA, "caseId": "G15",
            "challenge": CHALLENGE, "clock": "CLOCK_MONOTONIC_RAW", "roots": roots,
            "roles": [], "runtimeIdentities": [],
            "executable": {"path": "/godot", "sha256": "g"},
            "argv": [], "environment": [],
            "tracer": {"returncode": 40},
        }
        profile = {
            "runtime": {"godotSha256": "g"},
            "invocation": {"godotArgvTemplate": [], "environment": []},
            "roles": {"generatedGodotCache": {"paths": []}},
            "caps": {"maxSemanticFiles": 1, "maxIdentityDependencies": 1,
                     "maxPlatformObservations": 1, "maxFileIdentities": 3,
                     "maxGodotBytes": 1},
        }
        packet = {"roles": {"externalScript": {"path": "oracle.gd"},
                             "corpus": {"path": "corpus.json"}}}
        trace = {"challenge": CHALLENGE, "events": [],
                 "end": {"rootExit": 1, "dropped": 0, "violation": ""}}
        no_op = mock.Mock()
        object_failure = self.verifier.VerificationFailure(
            "UNDECLARED_INPUT_PATH", "injected successful object")
        with mock.patch.multiple(
                self.verifier, _authority=no_op, _admission_policy=no_op,
                _trusted_setup=no_op,
                _packet_members=no_op, _roles=mock.Mock(return_value={}),
                _records=mock.Mock(return_value={}), _live=no_op,
                _identity_set=mock.Mock(return_value={}),
                _output_records=mock.Mock(return_value={}), _exec=no_op,
                _lineage=no_op, _network=no_op, _timing=no_op,
                _objects=mock.Mock(side_effect=object_failure),
                _outputs=mock.Mock(side_effect=self.verifier.VerificationFailure(
                    "OUTPUT_WRITE_DENIED", "expected diagnostic"))):
            with self.assertRaisesRegex(
                    self.verifier.VerificationFailure, "UNDECLARED_INPUT_PATH"):
                self.verifier._complete(
                    args, profile, {}, packet, statement, trace, b"",
                    CHALLENGE, {}, {})
            self.verifier._outputs.assert_not_called()


if __name__ == "__main__":
    unittest.main()
