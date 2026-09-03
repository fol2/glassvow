#!/usr/bin/env python3
"""Focused contract tests for the bounded Godot runtime profile."""
from __future__ import annotations

import hashlib
import importlib.util
import json
import os
import tempfile
import types
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PROFILE_PATH = ROOT / "tools/execution_provenance/godot_runtime_profile.json"
VERIFIER_PATH = ROOT / "tools/execution_provenance/godot_runtime_verify.py"
RUNNER_PATH = ROOT / "tools/execution_provenance/godot_runtime_runner.py"
CAMPAIGN_PATH = ROOT / "tools/execution_provenance/godot_runtime_campaign.py"

INERT_HASHES = {
    "tools/execution_provenance/protocol.json":
        "07f19e5d6d9872727258f247d94f4189f2e6fee2b3fb9899182cf3e6df519d2b",
    "tools/execution_provenance/runner.py":
        "1ee6db283b346b438207d24cb0d8ba6af90a2589213fbc272a3824aa8f098a8f",
    "tools/execution_provenance/preflight.py":
        "d17128487413bab6dd172a7b9af48586bc6af16e58c55a1a5aebad02742d1287",
    "tools/execution_provenance/ptrace_tracer.c":
        "5afb6f4bff67aa47945c938467dadef6b72ab1cd32a9dca1f6a32121e170e9f8",
    "tools/execution_provenance/verify.py":
        "cb3dbea1d4eb4f67bc143818a489092fbb1993d38c22130da9a354dc02ae09a6",
    "tools/execution_provenance/campaign.py":
        "cfb7bd3cab98b2337bab805b9e09941b8890d6ff1904dfbce57b211b3b10ca7c",
    "tools/execution_provenance/inert_workload.c":
        "13fe5632cde6e4c5feea69b7b45c85322ec3f96aa328df76df18ec08f87394a1",
    "tests/test_execution_provenance.py":
        "2b594e18166d3743a8c10bdb0b1f4d724d69b42464a6b0348ffa552970bdc999",
}

G0_SYSCALLS = {
    "access", "arch_prctl", "bind", "brk", "chdir", "clock_nanosleep",
    "clone3", "close", "dup2", "execve", "exit", "exit_group",
    "faccessat2", "fadvise64", "fcntl", "fstat", "fstatfs", "futex",
    "getcwd", "getdents64", "getegid", "geteuid", "getgid", "getpid",
    "getppid", "getrandom", "getresgid", "getresuid", "getsockname",
    "getsockopt", "getuid", "lseek", "lstat", "madvise", "mkdir",
    "mmap", "mprotect", "munmap", "newfstatat", "openat", "pipe2",
    "poll", "prctl", "pread64", "prlimit64", "read", "readlink",
    "readlinkat", "rseq", "rt_sigaction", "rt_sigprocmask",
    "rt_sigreturn", "set_robust_list", "set_tid_address", "setsockopt",
    "socket", "stat", "statx", "vfork", "wait4", "write",
}

EXPECTED_CASES = {
    "G00": ("PASS", "ADMITTED"),
    "G01": ("REJECT", "GODOT_EXECUTABLE_MISMATCH"),
    "G02": ("REJECT", "RUNTIME_DEPENDENCY_MISMATCH"),
    "G03": ("REJECT", "ARGV_MISMATCH"),
    "G04": ("REJECT", "ENVIRONMENT_MISMATCH"),
    "G05": ("REJECT", "PROJECT_SEMANTIC_BYTES_MISMATCH"),
    "G06": ("REJECT", "GENERATED_CACHE_BYTES_MISMATCH"),
    "G07": ("REJECT", "EXTERNAL_SCRIPT_PATH_MISMATCH"),
    "G08": ("REJECT", "EXTERNAL_SCRIPT_BYTES_MISMATCH"),
    "G09": ("REJECT", "CORPUS_PATH_MISMATCH"),
    "G10": ("REJECT", "CORPUS_BYTES_MISMATCH"),
    "G11": ("REJECT", "REQUEST_INDEX_MISMATCH"),
    "G12": ("REJECT", "UNDECLARED_INPUT_PATH"),
    "G13": ("REJECT", "UNDECLARED_CACHE_ACCESS"),
    "G14": ("REJECT", "FORBIDDEN_NETWORK_FAMILY"),
    "G15": ("REJECT", "OUTPUT_WRITE_DENIED"),
    "G16": ("REJECT", "STDERR_CAPTURE_MISSING"),
    "G17": ("REJECT", "STDERR_CAPTURE_MISMATCH"),
    "G18": ("REJECT", "STDERR_INVOCATION_MISMATCH"),
    "G19": ("REJECT", "OUTPUT_NOT_CURRENT"),
    "G20": ("REJECT", "INVOCATION_CHALLENGE_MISMATCH"),
    "G21": ("REJECT", "PROCESS_LINEAGE_MISMATCH"),
    "G22": ("REJECT", "EXTERNAL_TIMING_MISMATCH"),
    "G23": ("REJECT", "EXTERNAL_WALL_CAP_EXCEEDED"),
    "G24": ("INCONCLUSIVE", "PROVENANCE_INCOMPLETE"),
    "G25": ("REJECT", "SEMANTIC_MAPPING_DENIED"),
}

TRACE_CHALLENGE = "a" * 64


def strict_trace_envelope(events: list[str]) -> list[str]:
    start = "\t".join([
        "START", "1", "100", TRACE_CHALLENGE, *(["1"] * 17),
    ])
    end = "\t".join([
        "END", str(len(events) + 2), "100", "200", "100",
        *(["0"] * 18), "0", "-", TRACE_CHALLENGE,
    ])
    return ["GODOTTRACEv1", start, *events, end]


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class GodotRuntimeProfileContractTests(unittest.TestCase):
    def setUp(self) -> None:
        self.profile = json.loads(PROFILE_PATH.read_text(encoding="utf-8"))

    def test_inert_profile_sources_remain_byte_identical(self) -> None:
        for relative, expected in INERT_HASHES.items():
            self.assertEqual(expected, sha256(ROOT / relative), relative)

    def test_profile_is_bound_to_actual_g0_measurement(self) -> None:
        self.assertEqual(
            "glassvow.godot-runtime-provenance.profile/v1",
            self.profile["schema"],
        )
        self.assertEqual(535, self.profile["authority"]["issue"])
        self.assertEqual(5524343289, self.profile["authority"]["comment"])
        self.assertEqual(
            "5c5f2d325725b0a04e060c1ffe0b40a76f2e0928",
            self.profile["authority"]["g0ProductSha"],
        )
        self.assertEqual(
            "fb6c497c45ad5c283176e7d25c2bc861aae17033",
            self.profile["authority"]["profileFreezeMainSha"],
        )
        self.assertEqual(33747777071, self.profile["authority"]["g0Run"])
        self.assertEqual(
            "8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e",
            self.profile["runtime"]["godotSha256"],
        )
        self.assertEqual(
            "4.7.2.stable.official.ed1daf0bf",
            self.profile["runtime"]["godotVersion"],
        )

    def test_syscall_grammar_is_exactly_the_measured_set(self) -> None:
        self.assertEqual(
            G0_SYSCALLS,
            set(self.profile["accessGrammar"]["allowedSyscalls"]),
        )
        self.assertEqual(61, len(self.profile["accessGrammar"]["allowedSyscalls"]))
        self.assertEqual("default-deny", self.profile["accessGrammar"]["unknown"])

    def test_attack_matrix_has_one_reason_per_new_trust_boundary(self) -> None:
        actual = {
            case["id"]: (case["expectedVerdict"], case["expectedReason"])
            for case in self.profile["cases"]
        }
        self.assertEqual(EXPECTED_CASES, actual)
        self.assertEqual(len(actual), len(self.profile["cases"]))

    def test_caps_cover_g0_without_becoming_unbounded(self) -> None:
        caps = self.profile["caps"]
        self.assertEqual(26, caps["caseCount"])
        self.assertEqual(10, caps["validTasks"])
        self.assertEqual(3, caps["validProcesses"])
        self.assertEqual(7, caps["validThreads"])
        self.assertEqual(4, caps["maxExecve"])
        self.assertEqual(8, caps["maxClone3"])
        self.assertEqual(1, caps["maxVfork"])
        self.assertGreaterEqual(caps["maxSyscalls"], 9019)
        self.assertLessEqual(caps["maxSyscalls"], 16384)
        self.assertGreaterEqual(caps["maxSemanticReadBytes"], 13476426)
        self.assertLessEqual(caps["maxSemanticReadBytes"], 16777216)
        self.assertEqual(0, caps["permittedDroppedEvents"])
        self.assertEqual(0, caps["permittedExternalNetwork"])
        self.assertEqual(65536, caps["maxEvents"])
        self.assertEqual(2048, caps["maxCloseEvents"])
        self.assertEqual(2, caps["maxSocketEvents"])
        self.assertEqual(2, caps["maxBindEvents"])
        self.assertEqual(8, caps["maxQualificationAttempts"])
        self.assertEqual(120, caps["maxHostedMinutes"])
        self.assertEqual(15, caps["maxMinutesPerQualificationAttempt"])
        self.assertEqual(
            caps["maxHostedMinutes"],
            caps["maxQualificationAttempts"]
            * caps["maxMinutesPerQualificationAttempt"],
        )
        self.assertEqual([
            "hardTaskCapacity", "maxSingleReadBytes", "maxCapturedBytes",
            "maxSyscalls", "maxPathEvents", "maxReadEvents",
            "maxWriteEvents", "maxMmapEvents", "maxOpenFds",
            "maxSemanticReadBytes", "maxTraceBytes", "maxOpenEvents",
            "maxCloseEvents", "maxSocketEvents", "maxBindEvents",
            "maxExecve", "validLineageEvents",
        ], caps["tracerStartLimitOrder"])

    def test_verifier_source_has_no_producer_dependency(self) -> None:
        source = VERIFIER_PATH.read_text(encoding="utf-8")
        forbidden = (
            "godot_runtime_runner", "godot_runtime_campaign",
            "godot_runtime_ptrace_tracer", "p9_v5_runtime_oracle",
            "diagnostic_validator", "execution_provenance.runner",
        )
        for token in forbidden:
            self.assertNotIn(token, source)


class GodotRuntimeVerifierParserTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        spec = importlib.util.spec_from_file_location(
            "godot_runtime_verify", VERIFIER_PATH)
        assert spec and spec.loader
        cls.verifier = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.verifier)

    def test_sequence_gap_fails_closed(self) -> None:
        lines = strict_trace_envelope([
            "SYSCALL_E\t3\t1001\t0\tread\t0\t0\t0\t0\t0\t0",
        ])
        with self.assertRaisesRegex(self.verifier.VerificationFailure, "sequence"):
            self.verifier.parse_trace_lines(lines, max_events=16)

    def test_legacy_trace_envelopes_fail_closed(self) -> None:
        with self.assertRaisesRegex(
                self.verifier.VerificationFailure, "PROVENANCE_INCOMPLETE"):
            self.verifier.parse_trace_lines([
                "GODOTTRACEv1", "START\t100",
                "EXIT\t1\t1001\t0", "END\t1\t100\t200\t100\t0\t1\t-",
            ], max_events=16)

    def test_semantic_mapping_case_is_a_rejection(self) -> None:
        self.assertEqual(
            ("REJECT", "SEMANTIC_MAPPING_DENIED"),
            self.verifier.CASE_RESULTS["G25"],
        )

    def test_unknown_syscall_fails_closed(self) -> None:
        lines = strict_trace_envelope([
            "SYSCALL_E\t2\t1001\t999\tio_uring_setup\t0\t0\t0\t0\t0\t0",
        ])
        trace = self.verifier.parse_trace_lines(lines, max_events=16)
        with self.assertRaisesRegex(
                self.verifier.VerificationFailure, "UNSUPPORTED_SYSCALL"):
            self.verifier.validate_syscall_grammar(trace, G0_SYSCALLS)

    def test_semantic_read_sidecar_is_byte_compared(self) -> None:
        expected = b"complete semantic bytes"
        event = {
            "offset": 0,
            "returned": len(expected),
            "sidecarOffset": 0,
            "sidecarLength": len(expected),
        }
        self.verifier.validate_complete_role_reads([event], expected, expected)
        with self.assertRaisesRegex(
                self.verifier.VerificationFailure, "SEMANTIC_BYTES_MISMATCH"):
            self.verifier.validate_complete_role_reads(
                [event], expected, b"wrong" + expected[5:])

    def test_semantic_mapping_is_never_accepted_as_read_evidence(self) -> None:
        with self.assertRaisesRegex(
                self.verifier.VerificationFailure, "SEMANTIC_MAPPING_DENIED"):
            self.verifier.reject_semantic_mappings([
                {"path": "${PACKET}/corpus.json", "fd": 7},
            ], {"${PACKET}/corpus.json"})

    def test_fresh_qualification_packet_sha_is_not_the_historical_g0_sha(self) -> None:
        profile = json.loads(PROFILE_PATH.read_text(encoding="utf-8"))
        baseline = profile["packetIngress"]["qualification"]["baselineRoles"]
        packet = {
            "roles": {
                name: {"path": "oracle.gd" if name == "externalScript" else "corpus.json",
                       **record}
                for name, record in baseline.items()
            }
        }
        g0 = {"semanticReadSet": [
            {"path": f"${{PRODUCT}}/role-{index}", "size": 1, "sha256": "a" * 64}
            for index in range(28)
        ]}
        args = types.SimpleNamespace(
            authority_issue=535, authority_comment=5524343289,
            packet_sha="f" * 40)
        roles = self.verifier._roles(
            g0, packet, {"PRODUCT": "/product", "PACKET": "/packet"},
            profile, args)
        self.assertEqual(30, len(roles))


class GodotRuntimeRunnerContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        spec = importlib.util.spec_from_file_location(
            "godot_runtime_runner", RUNNER_PATH)
        assert spec and spec.loader
        cls.runner = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.runner)
        cls.profile = json.loads(PROFILE_PATH.read_text(encoding="utf-8"))

    def test_packet_manifest_binds_regular_role_bytes(self) -> None:
        with tempfile.TemporaryDirectory(prefix="godot-packet-") as temporary:
            packet = Path(temporary) / "packet"
            packet.mkdir()
            script = packet / "oracle.gd"
            corpus = packet / "corpus.json"
            script.write_bytes(b"extends SceneTree\n")
            corpus.write_bytes(b"{}\n")
            manifest = {
                "schema": "glassvow.godot-runtime-packet/v1",
                "productSha": "a" * 40,
                "packetRoot": "research_packets/frozen",
                "authorityIssue": 421,
                "authorityComment": 1,
                "requestIndices": ["0"],
                "roles": {
                    "externalScript": {
                        "path": script.name,
                        "size": script.stat().st_size,
                        "sha256": sha256(script),
                    },
                    "corpus": {
                        "path": corpus.name,
                        "size": corpus.stat().st_size,
                        "sha256": sha256(corpus),
                    },
                },
            }
            (packet / "manifest.json").write_text(
                json.dumps(manifest), encoding="utf-8")
            result = self.runner.validate_packet_manifest(
                packet, manifest, self.profile, product_sha="a" * 40,
                packet_root="research_packets/frozen", authority_issue=421,
                authority_comment=1)
            self.assertEqual(script.resolve(), result["externalScript"])
            self.assertEqual(corpus.resolve(), result["corpus"])

    def test_packet_manifest_rejects_symlink_role(self) -> None:
        with tempfile.TemporaryDirectory(prefix="godot-packet-") as temporary:
            packet = Path(temporary) / "packet"
            packet.mkdir()
            outside = Path(temporary) / "outside.gd"
            outside.write_bytes(b"extends SceneTree\n")
            os.symlink(outside, packet / "oracle.gd")
            corpus = packet / "corpus.json"
            corpus.write_bytes(b"{}\n")
            manifest = {
                "schema": "glassvow.godot-runtime-packet/v1",
                "productSha": "a" * 40,
                "packetRoot": "research_packets/frozen",
                "authorityIssue": 535,
                "authorityComment": 5524343289,
                "requestIndices": ["0"],
                "roles": {
                    "externalScript": {
                        "path": "oracle.gd", "size": outside.stat().st_size,
                        "sha256": sha256(outside),
                    },
                    "corpus": {
                        "path": corpus.name, "size": corpus.stat().st_size,
                        "sha256": sha256(corpus),
                    },
                },
            }
            with self.assertRaisesRegex(
                    self.runner.RunnerError, "regular non-symlink"):
                self.runner.validate_packet_manifest(
                    packet, manifest, self.profile, product_sha="a" * 40,
                    packet_root="research_packets/frozen", authority_issue=535,
                    authority_comment=5524343289)

    def test_qualification_packet_cannot_replace_the_measured_m09_bytes(self) -> None:
        with tempfile.TemporaryDirectory(prefix="godot-packet-") as temporary:
            packet = Path(temporary)
            script = packet / "oracle.gd"
            corpus = packet / "corpus.json"
            script.write_bytes(b"extends SceneTree\n")
            corpus.write_bytes(b"{}\n")
            manifest = {
                "schema": "glassvow.godot-runtime-packet/v1",
                "productSha": "a" * 40,
                "packetRoot": "research_packets/frozen",
                "authorityIssue": 535,
                "authorityComment": 5524343289,
                "requestIndices": ["0"],
                "roles": {
                    "externalScript": {
                        "path": script.name, "size": script.stat().st_size,
                        "sha256": sha256(script),
                    },
                    "corpus": {
                        "path": corpus.name, "size": corpus.stat().st_size,
                        "sha256": sha256(corpus),
                    },
                },
            }
            (packet / "manifest.json").write_text(
                json.dumps(manifest), encoding="utf-8")
            with self.assertRaisesRegex(
                    self.runner.RunnerError, "differs from G0"):
                self.runner.validate_packet_manifest(
                    packet, manifest, self.profile, product_sha="a" * 40,
                    packet_root="research_packets/frozen", authority_issue=535,
                    authority_comment=5524343289)

    def test_canonical_invocation_contains_only_frozen_environment(self) -> None:
        roots = {
            "GODOT": "/runtime/godot",
            "HOME": "/fresh/home",
            "PRODUCT": "/mount/product",
            "PACKET": "/mount/packet",
            "OUTPUT": "/fresh/output",
        }
        command, environment = self.runner.canonical_invocation(
            self.profile, roots, "oracle.gd", "corpus.json", "0")
        self.assertEqual("/usr/bin/env", command[0])
        self.assertEqual("/runtime/godot", command[5])
        self.assertEqual(
            ["HOME=/fresh/home", "PATH=/usr/bin:/bin", "LANG=C.UTF-8"],
            environment,
        )
        self.assertNotIn("PYTHONPATH", "\n".join(command + environment))

    def test_runner_cannot_add_an_arbitrary_identity_path(self) -> None:
        self.assertNotIn(
            '"--identity-path"', RUNNER_PATH.read_text(encoding="utf-8"))

    def test_runtime_identity_preserves_the_frozen_logical_symlink_path(self) -> None:
        with tempfile.TemporaryDirectory(prefix="godot-identity-") as temporary:
            root = Path(temporary)
            target = root / "target"
            logical = root / "logical"
            target.write_bytes(b"runtime")
            logical.symlink_to(target)
            record = self.runner._identity(logical, logical_path=str(logical))
            self.assertEqual(str(logical), record["path"])
            self.assertEqual(sha256(target), record["sha256"])

    def test_capture_caps_reject_oversized_output_before_copying(self) -> None:
        with tempfile.TemporaryDirectory(prefix="godot-caps-") as temporary:
            root = Path(temporary)
            files = [root / name for name in (
                "observation.json", "godot.log", "sentry.dat", "trace.tsv",
                "sidecar.bin")]
            for path in files:
                path.write_bytes(b"")
            with self.assertRaisesRegex(
                    self.runner.RunnerError, "stdout capture cap"):
                self.runner.enforce_capture_caps(
                    self.profile,
                    b"x" * (self.profile["caps"]["maxStdoutBytes"] + 1),
                    b"", *files)


class GodotRuntimeCampaignContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        spec = importlib.util.spec_from_file_location(
            "godot_runtime_campaign", CAMPAIGN_PATH)
        assert spec and spec.loader
        cls.campaign = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.campaign)

    def test_campaign_covers_the_complete_frozen_matrix_once(self) -> None:
        self.assertEqual(
            [f"G{index:02d}" for index in range(26)],
            self.campaign.CASE_IDS,
        )
        self.assertEqual(
            {"G15", "G16", "G17", "G18"},
            self.campaign.DIAGNOSTIC_CASES,
        )

    def test_packet_commit_is_bound_outside_its_manifest(self) -> None:
        with tempfile.TemporaryDirectory(prefix="godot-packet-") as temporary:
            root = Path(temporary)
            (root / "oracle.gd").write_text("extends SceneTree\n", encoding="utf-8")
            (root / "corpus.json").write_text("{}\n", encoding="utf-8")
            manifest = {
                "schema": "glassvow.godot-runtime-packet/v1",
                "productSha": "a" * 40,
                "packetRoot": "research_packets/frozen",
                "authorityIssue": 535,
                "authorityComment": 5524343289,
                "requestIndices": ["0"],
                "roles": {
                    "externalScript": {
                        "path": "oracle.gd", "size": 18,
                        "sha256": sha256(root / "oracle.gd"),
                    },
                    "corpus": {
                        "path": "corpus.json", "size": 3,
                        "sha256": sha256(root / "corpus.json"),
                    },
                },
            }
            self.assertNotIn("packetSha", manifest)

    def test_io_path_attack_targets_only_the_declared_semantic_read(self) -> None:
        corpus = Path("/packet/corpus.json")
        fields = [
            "IO", "1", "123", "read", "7", "0", "3", "3", "S",
            "1", "2", "0", str(corpus).encode("utf-8").hex(),
        ]
        wrong = fields.copy()
        self.assertFalse(self.campaign._mutate_io_path(
            wrong, Path("/packet/undeclared.json"), "S",
            original=Path("/packet/other.json")))
        self.assertTrue(self.campaign._mutate_io_path(
            fields, Path("/packet/undeclared.json"), "S", original=corpus))
        self.assertEqual(
            "/packet/undeclared.json",
            bytes.fromhex(fields[12]).decode("utf-8"),
        )

    def test_campaign_byte_cap_excludes_read_only_input_mounts(self) -> None:
        with tempfile.TemporaryDirectory(prefix="godot-campaign-") as temporary:
            output = Path(temporary)
            mounts = output / "input-mounts"
            (mounts / "product").mkdir(parents=True)
            (output / "cases").mkdir()
            (mounts / "product/source.bin").write_bytes(b"input" * 100)
            (output / "cases/receipt.json").write_bytes(b"evidence")
            self.assertEqual(
                len(b"evidence"),
                self.campaign.campaign_evidence_bytes(output, mounts),
            )

    def test_g19_replay_packet_removes_current_semantic_read_evidence(self) -> None:
        with tempfile.TemporaryDirectory(prefix="godot-g19-") as temporary:
            case = Path(temporary)
            sidecar = b"a\0b\0SEMOK"
            (case / "sidecar.bin").write_bytes(sidecar)
            semantic = "/packet/corpus.json".encode().hex()
            pipe = "pipe:[1]".encode().hex()
            trace = [
                "GODOTTRACEv1",
                "START\t1\t100\t" + "a" * 64,
                "EXEC\t2\t100\t100\t0\t2\t2\t2\t1\t2\t2f62696e2f7368",
                "SYSCALL_E\t3\t100\t0\tread\t7\t0\t3\t0\t0\t0",
                "SYSCALL_X\t4\t100\t0\tread\t3\t0\t0",
                f"IO\t5\t100\tread\t7\t0\t3\t3\tS\t1\t2\t4\t{semantic}",
                f"IO\t6\t100\twrite\t1\t-1\t2\t2\tU\t0\t0\t7\t{pipe}",
                "END\t7\t100\t200\t100\t1\t1\t0\t2\t2\t0\t9\t0\t1\t1\t0\t0\t0\t0\t0\t1\t3\t0\t0\t-\t" + "a" * 64,
            ]
            (case / "trace.tsv").write_text(
                "\n".join(trace) + "\n", encoding="utf-8")
            statement = {
                "trace": {"size": 0, "sha256": ""},
                "sidecar": {"size": len(sidecar), "sha256": ""},
            }
            self.campaign._strip_current_semantic_reads(case, statement)
            rebuilt = (case / "trace.tsv").read_text(encoding="utf-8").splitlines()
            self.assertFalse(any(line.startswith("IO\t") and "\tread\t" in line
                                 for line in rebuilt))
            self.assertEqual(b"a\0b\0OK", (case / "sidecar.bin").read_bytes())
            self.assertEqual("0", rebuilt[4].split("\t")[5])
            self.assertEqual("0", rebuilt[4].split("\t")[6])
            self.assertEqual("5", rebuilt[5].split("\t")[1])
            end = rebuilt[-1].split("\t")
            self.assertEqual("6", end[1])
            self.assertEqual("6", end[11])
            self.assertEqual("0", end[13])
            self.assertEqual("0", end[21])


if __name__ == "__main__":
    unittest.main()
