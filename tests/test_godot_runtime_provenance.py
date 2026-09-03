#!/usr/bin/env python3
"""Focused contract tests for the bounded Godot runtime profile."""
from __future__ import annotations

import hashlib
import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile
import types
import unittest
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
PROFILE_PATH = ROOT / "tools/execution_provenance/godot_runtime_profile.json"
G0_MANIFEST_PATH = ROOT / "tools/execution_provenance/godot_runtime_g0_manifest.json"
CONFIGURATION_MANIFEST_PATH = ROOT / "tools/execution_provenance/godot_runtime_configuration_manifest.json"
CONFIGURATION_ROOT = ROOT / "tools/execution_provenance/godot_runtime_configuration"
VERIFIER_PATH = ROOT / "tools/execution_provenance/godot_runtime_verify.py"
RUNNER_PATH = ROOT / "tools/execution_provenance/godot_runtime_runner.py"
CAMPAIGN_PATH = ROOT / "tools/execution_provenance/godot_runtime_campaign.py"
TRACER_PATH = ROOT / "tools/execution_provenance/godot_runtime_ptrace_tracer.c"
G0_TRACE_SUMMARISER_PATH = (
    ROOT / "tools/execution_provenance/godot_runtime_g0_trace.py")

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
        "START", "1", "100", TRACE_CHALLENGE, *(["1"] * 20),
    ])
    end = "\t".join([
        "END", str(len(events) + 2), "100", "200", "100",
        *(["0"] * 18), "0", "-", TRACE_CHALLENGE,
    ])
    return ["GODOTTRACEv1", start, *events, end]


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class GodotRuntimeG0TraceSummariserTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        spec = importlib.util.spec_from_file_location(
            "godot_runtime_g0_trace", G0_TRACE_SUMMARISER_PATH)
        assert spec and spec.loader
        cls.summariser = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.summariser)

    def test_direct_and_symlinked_path_operations_survive_summary(self) -> None:
        lines = [
            '1.000 access("/etc/fonts/conf.d/a.conf", R_OK) = 0 <0.000001>',
            '1.001 readlink("/etc/fonts/conf.d/a.conf", '
            '"../conf.avail/a.conf", 4095) = 20 <0.000001>',
            '1.002 newfstatat(AT_FDCWD</work>, '
            '"/etc/fonts/conf.d/a.conf", {st_mode=S_IFREG|0644}, 0) = 0 <0.000001>',
            '1.003 openat(AT_FDCWD</work>, "/etc/fonts/conf.d/a.conf", '
            'O_RDONLY|O_CLOEXEC) = 3</etc/fonts/conf.avail/a.conf> <0.000001>',
            '1.004 mkdir("/work", 0775)  = -1 EEXIST (File exists) <0.000001>',
            '1.005 openat(AT_FDCWD</work>, "/lib/libexample.so.1", '
            'O_RDONLY|O_CLOEXEC) = 4</usr/lib/libexample.so.1.2> <0.000001>',
            '1.006 openat(AT_FDCWD</work>, "/sys/class/input/mice", '
            'O_RDONLY|O_NOFOLLOW|O_CLOEXEC|O_PATH) = '
            '5</sys/class/input/mice> <0.000001>',
        ]
        records = self.summariser.path_operation_closure(
            {"trace.1": lines}, roots={}, initial_working_directory="/work")
        _, symlinks = self.summariser.path_observation_closure(
            {"trace.1": lines}, roots={}, initial_working_directory="/work")
        actual = {
            (record["operation"], record["path"], record["parameter"]):
                (record["returns"], record["count"])
            for record in records
        }
        target = "/etc/fonts/conf.avail/a.conf"
        self.assertEqual(([0], 1), actual[("access", target, None)])
        self.assertEqual(
            ([20], 1), actual[("readlink", "/etc/fonts/conf.d/a.conf", None)])
        self.assertEqual(([0], 1), actual[("newfstatat", target, None)])
        self.assertEqual(([3], 1), actual[("openat", target, 524288)])
        self.assertEqual(([-17], 1), actual[("mkdir", "/work", 509)])
        self.assertEqual(
            ([4], 1), actual[("openat", "/usr/lib/libexample.so.1.2", 524288)])
        self.assertEqual(
            ([5], 1), actual[("openat", "/sys/class/input/mice", 2752512)])
        self.assertEqual([{
            "path": "/etc/fonts/conf.d/a.conf",
            "target": "/etc/fonts/conf.avail/a.conf",
        }], symlinks)


class GodotRuntimeProfileContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        spec = importlib.util.spec_from_file_location(
            "godot_runtime_profile_verify", VERIFIER_PATH)
        assert spec and spec.loader
        cls.verifier = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.verifier)

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
        self.assertEqual(sha256(PROFILE_PATH), self.verifier.FROZEN_PROFILE_SHA256)
        self.assertEqual(535, self.profile["authority"]["issue"])
        self.assertEqual(5530338723, self.profile["authority"]["comment"])
        self.assertEqual(
            "5c5f2d325725b0a04e060c1ffe0b40a76f2e0928",
            self.profile["authority"]["g0ProductSha"],
        )
        self.assertEqual(
            "fb6c497c45ad5c283176e7d25c2bc861aae17033",
            self.profile["authority"]["profileFreezeMainSha"],
        )
        self.assertEqual(33762926632, self.profile["authority"]["g0Run"])
        self.assertEqual(
            "5c3a5ccdb120c18a5a52ecdacf95972d88322f5f",
            self.profile["authority"]["g0ObserverHead"],
        )
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

    def test_corrected_g0_artifact_is_the_only_profile_measurement_authority(self) -> None:
        manifest_bytes = G0_MANIFEST_PATH.read_bytes()
        manifest = json.loads(manifest_bytes)
        self.assertEqual(
            self.profile["g0"]["manifest"]["sha256"],
            hashlib.sha256(manifest_bytes).hexdigest(),
        )
        self.assertEqual(33762926632, manifest["source"]["run"])
        self.assertEqual(9896305893, manifest["source"]["artifactId"])
        self.assertEqual(
            "6fe2a93c98907e2d40c21db6666ab5fede769098a9233fc8bb887bf66ca806de",
            manifest["source"]["artifactSha256"],
        )
        self.assertEqual((30, 126, 13), (
            len(manifest["semanticReadSet"]), len(manifest["runtimeIdentitySet"]),
            len(manifest["platformObservationSet"]),
        ))
        self.assertEqual(
            self.profile["runtime"]["identitySet"]["canonicalSha256"],
            self.verifier._sha(self.verifier._canonical(manifest["runtimeIdentitySet"])),
        )
        dynamic = {record["path"] for record in manifest["platformObservationSet"]
                   if "contentNormalisation" in record}
        self.assertEqual({
            "/run/udev/data/c13:0", "/run/udev/data/c13:32",
            "/run/udev/data/c13:64", "/run/udev/data/c13:65",
        }, dynamic)

    def test_g0_manifest_preserves_direct_path_operations(self) -> None:
        manifest = json.loads(G0_MANIFEST_PATH.read_text(encoding="utf-8"))
        records = {
            record["path"]: record
            for section in ("semanticReadSet", "runtimeIdentitySet",
                            "platformObservationSet")
            for record in manifest[section]
        }
        self.assertTrue(
            {"access", "newfstatat", "openat", "read", "close"}
            <= set(records["/etc/fonts/fonts.conf"]["operations"]),
        )
        closure = manifest["pathOperationClosure"]
        self.assertEqual(4097, closure["eventCount"])
        self.assertEqual(782, closure["recordCount"])
        self.assertEqual(760, closure["uniqueOperationPathPairs"])
        self.assertEqual(57, closure["symlinkCount"])
        self.assertEqual(
            closure["recordsCanonicalSha256"],
            self.profile["g0"]["pathOperationClosure"][
                "recordsCanonicalSha256"],
        )

    def test_every_successful_closure_path_survives_post_admission_projection(self) -> None:
        manifest = json.loads(G0_MANIFEST_PATH.read_text(encoding="utf-8"))
        closure = manifest["pathOperationClosure"]
        roots = closure["source"]["roots"]
        grammar = self.profile["accessGrammar"]["paths"]

        def expand(value: str) -> str:
            for name, root in roots.items():
                value = value.replace("${" + name + "}", root)
            return value

        def operations(records: list[dict]) -> dict[str, set[str]]:
            result: dict[str, set[str]] = {}
            for record in records:
                for path in record["paths"]:
                    result.setdefault(expand(path), set()).update(
                        record["operations"])
            return result

        dynamic = operations(grammar["successfulDynamicDirectoryOperations"])
        probes = operations(grammar["successfulProbeOperations"])
        directories = operations(grammar["successfulDirectoryOperations"])
        working = set(grammar["successfulWorkingDirectoryOperations"])
        working_directory = closure["source"]["initialWorkingDirectory"]
        symlinks = {expand(record["path"])
                    for record in closure["symlinkTargets"]}
        named = {record["path"]: set(record["operations"])
                 for record in grammar["successfulNamedPathOperations"]}
        known = {
            expand(record["path"]): set(record.get("operations", []))
            for section in (
                "semanticReadSet", "runtimeIdentitySet", "platformObservationSet")
            for record in manifest[section]
        }
        output_paths = {
            expand(grammar["pathResultPolicy"]["diagnosticOutputDenial"]["path"]),
            *(expand(record["path"])
              for record in manifest["baselineOutputs"][:2]),
        }

        gaps = []
        successful_statx = set()
        for record in closure["records"]:
            if not any(value >= 0 for value in record["returns"]):
                continue
            operation, path = record["operation"], expand(record["path"])
            if operation == "statx":
                successful_statx.add((operation, path))
            if path in dynamic:
                admitted = operation in dynamic[path]
            elif path == working_directory:
                admitted = operation in working
            elif path in probes:
                admitted = operation in probes[path]
            elif path in symlinks or path == "/dev/null":
                admitted = True
            elif path in directories:
                admitted = operation in directories[path]
            elif path in named:
                admitted = operation in named[path]
            elif path in known:
                admitted = operation in known[path]
            else:
                admitted = path in output_paths and operation == "openat"
            if not admitted:
                gaps.append((operation, path, record["parameter"], record["returns"]))
        self.assertEqual([], gaps)
        declared_statx = {
            (operation, path)
            for path, allowed in directories.items()
            for operation in allowed
            if operation == "statx"
        }
        self.assertEqual({("statx", "/")}, successful_statx)
        self.assertEqual(successful_statx, declared_statx)

    def test_fresh_g0_configuration_capture_is_the_only_fixture_byte_authority(self) -> None:
        capture = json.loads(CONFIGURATION_MANIFEST_PATH.read_text(encoding="utf-8"))
        binding = self.profile["g0"]["configurationCapture"]
        self.assertEqual(
            binding["sha256"], hashlib.sha256(CONFIGURATION_MANIFEST_PATH.read_bytes()).hexdigest())
        self.assertEqual(33768343626, capture["source"]["run"])
        self.assertEqual(9898578469, capture["source"]["artifactId"])
        self.assertEqual(
            "28835d178a13fdee58a5cdc7bd0a98e8688e1e6f0a86d5d470972ea9b858c44d",
            capture["source"]["artifactSha256"],
        )
        self.assertEqual(3, binding["roleCount"])
        self.assertEqual(set(capture["roles"]), {
            "extension_list.cfg", "global_script_class_cache.cfg", "uid_cache.bin"})
        g0 = json.loads(G0_MANIFEST_PATH.read_text(encoding="utf-8"))
        g0_roles = {
            Path(record["path"]).name: record
            for record in g0["semanticReadSet"] if "/.godot/" in record["path"]
        }
        for name, record in capture["roles"].items():
            fixture = CONFIGURATION_ROOT / name
            self.assertTrue(fixture.is_file() and not fixture.is_symlink())
            self.assertEqual(record["size"], fixture.stat().st_size)
            self.assertEqual(record["sha256"], sha256(fixture))
            self.assertEqual(
                (record["size"], record["sha256"]),
                (g0_roles[name]["size"], g0_roles[name]["sha256"]),
            )
            self.assertEqual(record["size"], sum(
                value for value in record["runtimeReadReturns"] if value > 0))

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
        self.assertEqual(1207959552, caps["maxAddressSpaceBytes"])
        self.assertEqual(16777216, caps["maxInitialStackBytes"])
        self.assertEqual(5, caps["maxDupEvents"])
        self.assertEqual(65536, caps["maxPacketManifestBytes"])
        self.assertEqual(2, caps["validSignalEvents"])
        self.assertEqual(8, caps["maxQualificationAttempts"])
        self.assertEqual(120, caps["maxHostedMinutes"])
        self.assertEqual(15, caps["maxMinutesPerQualificationAttempt"])
        self.assertEqual(1024, caps["maxCampaignMembers"])
        self.assertEqual(
            caps["maxHostedMinutes"],
            caps["maxQualificationAttempts"]
            * caps["maxMinutesPerQualificationAttempt"],
        )
        self.assertEqual([
            "hardTaskCapacity", "maxAddressSpaceBytes", "maxInitialStackBytes",
            "maxSingleReadBytes", "maxCapturedBytes",
            "maxSyscalls", "maxPathEvents", "maxReadEvents",
            "maxWriteEvents", "maxMmapEvents", "maxOpenFds",
            "maxSemanticReadBytes", "maxTraceBytes", "maxOpenEvents",
            "maxCloseEvents", "maxSocketEvents", "maxBindEvents",
            "maxExecve", "maxDupEvents", "validLineageEvents",
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

    def test_profile_separates_requested_xdg_script_from_effective_interpreter(self) -> None:
        self.assertEqual([], self.profile["invocation"]["launcherEnvironment"])
        xdg = self.profile["invocation"]["permittedDescendantExecs"][1]
        self.assertEqual("/usr/bin/xdg-user-dir", xdg["requestedPath"])
        self.assertEqual("/bin/sh", xdg["effectivePath"])
        self.assertEqual(["/bin/sh", "/usr/bin/xdg-user-dir", "DESKTOP"], xdg["argv"])

    def test_profile_binds_every_measured_baseline_side_effect(self) -> None:
        roles = self.profile["roles"]
        self.assertEqual(309, roles["stdout"]["qualificationBaseline"]["size"])
        self.assertEqual(0, roles["stderr"]["qualificationBaseline"]["size"])
        self.assertEqual(
            {"observation", "homeLog", "sentry"},
            set(roles["output"]["qualificationBaseline"]),
        )
        sentry = roles["output"]["qualificationBaseline"]["sentry"]
        self.assertTrue(self.verifier._valid_sentry_output(
            b'[main]\n\ninstallation_id="5df99ee6-04bf-46fa-ac33-b60bab3b4468"\n',
            sentry,
        ))
        self.assertFalse(self.verifier._valid_sentry_output(
            b'[main]\n\ninstallation_id="5df99ee6-04bf-36fa-ac33-b60bab3b4468"\n',
            sentry,
        ))

    def test_kernel_admission_contract_closes_read_exec_and_inherited_fd_boundaries(self) -> None:
        admission = self.profile["kernelAdmission"]
        self.assertEqual("GODOTACCESSv1", admission["policySchema"])
        self.assertEqual(32759, admission["handledAccessFs"])
        self.assertEqual(
            ["/usr/bin/env", "${GODOT}", "/bin/sh", "/usr/bin/xdg-user-dir"],
            admission["executeLeaves"],
        )
        self.assertEqual(
            ["/usr/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2"],
            admission["kernelInterpreterLeaves"],
        )
        capture = self.profile["g0"]["kernelInterpreterCapture"]
        self.assertEqual(33778025696, capture["run"])
        self.assertEqual(9902474984, capture["artifactId"])
        self.assertEqual(
            "cd4df4f3c7b83673d61189bf2eaebd33ca4f2853ab9772b8a25e025ef99b1e81",
            capture["sha256"],
        )
        manifest = json.loads(G0_MANIFEST_PATH.read_text(encoding="utf-8"))
        loader = [record for record in manifest["runtimeIdentitySet"]
                  if record["path"] == capture["canonicalPath"]]
        self.assertEqual([{
            "operations": ["kernel-interpreter"],
            "path": capture["canonicalPath"],
            "sha256": capture["sha256"],
            "size": capture["size"],
        }], loader)
        self.assertEqual({0, 1, 2}, {
            admission["initialDescriptors"][name]["fd"]
            for name in ("stdin", "stdout", "stderr")
        })
        grammar = self.profile["accessGrammar"]
        self.assertEqual(
            {
                "caseIds": ["G15", "G16", "G17", "G18"],
                "operation": "openat",
                "path": "${OUTPUT}/observation.json",
                "parameter": 577,
                "returned": -13,
            },
            grammar["paths"]["pathResultPolicy"]["diagnosticOutputDenial"],
        )
        self.assertEqual(524288, grammar["internalPipe"]["pipe2Flags"])
        self.assertEqual(11, self.profile["caps"]["maxCaseMembers"])

    def test_path_result_policy_replaces_the_historical_projection(self) -> None:
        paths = self.profile["accessGrammar"]["paths"]
        self.assertNotIn("historicalFailedPathGrammar", paths)
        self.assertNotIn("failedPathGrammar", paths)
        self.assertEqual(
            {"operation": "readlink", "parameter": None, "returned": -22},
            paths["pathResultPolicy"]["rootAncestorReadlink"],
        )
        self.assertEqual(
            {"operation": "mkdir", "parameter": 509, "returned": -17},
            paths["pathResultPolicy"]["existingHomeAncestorMkdir"],
        )

    def test_research_output_policy_transports_current_diagnostic_bytes_without_g0_substitution(self) -> None:
        streams = {
            "stdout": {"size": 17, "sha256": "1" * 64},
            "stderr": {"size": 29, "sha256": "2" * 64},
        }
        outputs = {
            "homeLog": {"present": True, "size": 41, "sha256": "3" * 64},
            "sentry": {"present": True},
        }
        research = self.profile["packetIngress"]["research"]
        statement = {
            "authorityIssue": research["authorityIssue"],
            "authorityComment": research["authorityComment"],
        }
        self.verifier._validate_stable_output_policy(
            statement, streams, outputs, self.profile)

        qualification = self.profile["packetIngress"]["qualification"]
        statement.update({
            "authorityIssue": qualification["authorityIssue"],
            "authorityComment": qualification["authorityComment"],
        })
        with self.assertRaisesRegex(
                self.verifier.VerificationFailure, "stable stdout differs"):
            self.verifier._validate_stable_output_policy(
                statement, streams, outputs, self.profile)

    def test_research_output_policy_is_exact_and_fail_closed(self) -> None:
        research = self.profile["packetIngress"]["research"]
        self.assertEqual({
            "mode": "bounded-current-raw-channel",
            "channels": ["stdout", "stderr", "homeLog"],
            "interpretation": "none",
            "downstreamOwner": "unchanged A1-v2 diagnostic validator",
        }, research["outputPolicy"])
        profile = json.loads(json.dumps(self.profile))
        profile["packetIngress"]["research"]["outputPolicy"]["interpretation"] = "verifier"
        with self.assertRaisesRegex(
                self.verifier.VerificationFailure, "research output policy differs"):
            self.verifier._validate_stable_output_policy(
                {
                    "authorityIssue": research["authorityIssue"],
                    "authorityComment": research["authorityComment"],
                },
                {"stdout": {}, "stderr": {}},
                {"homeLog": {"present": True}},
                profile,
            )

    def test_address_space_limit_is_inherited_before_tracee_exec(self) -> None:
        g0 = self.profile["g0"]
        expected = (
            g0["syscallAccountedAddressSpaceOvercountBytes"]
            + g0["godotElfPtLoadPageBytes"]
            + g0["smallElfAndInterpreterAllowanceBytes"]
            + g0["initialStackReservation"]["processes"]
            * g0["initialStackReservation"]["bytesEach"]
            + g0["vdsoVvarReservation"]["processes"]
            * g0["vdsoVvarReservation"]["bytesEach"]
        )
        self.assertEqual(expected, g0["conservativeAddressSpaceContractBytes"])
        self.assertEqual(
            self.profile["caps"]["maxAddressSpaceBytes"] - expected,
            g0["addressSpaceCapHeadroomBytes"],
        )
        tracer = (ROOT / "tools/execution_provenance/godot_runtime_ptrace_tracer.c").read_text(
            encoding="utf-8")
        io_source = (ROOT / "tools/execution_provenance/godot_runtime_ptrace_io.c").read_text(
            encoding="utf-8")
        self.assertIn("MAX_ADDRESS_SPACE (1152ULL * 1024ULL * 1024ULL)", tracer)
        self.assertIn("MAX_INITIAL_STACK (16ULL * 1024ULL * 1024ULL)", tracer)
        self.assertLess(tracer.index("gv_limit_address_space(MAX_ADDRESS_SPACE)"),
                        tracer.index('execve("/usr/bin/env"'))
        self.assertLess(tracer.index("gv_limit_initial_stack(MAX_INITIAL_STACK)"),
                        tracer.index('execve("/usr/bin/env"'))
        self.assertIn("setrlimit(resource, &limit)", io_source)
        self.assertIn("limit_resource(RLIMIT_AS, bytes)", io_source)
        self.assertIn("limit_resource(RLIMIT_STACK, bytes)", io_source)

    def test_dynamic_directory_grammar_is_operation_specific(self) -> None:
        records = self.profile["accessGrammar"]["paths"][
            "successfulDynamicDirectoryOperations"]
        actual = {(operation, path) for record in records
                  for operation in record["operations"] for path in record["paths"]}
        self.assertEqual({
            ("chdir", "${PRODUCT}"),
            ("chdir", "${HOME}/.local/share/godot/app_userdata/Glassvow"),
            ("mkdir", "${HOME}/.local"),
            ("mkdir", "${HOME}/.local/share"),
            ("mkdir", "${HOME}/.local/share/godot"),
            ("mkdir", "${HOME}/.local/share/godot/app_userdata"),
            ("mkdir", "${HOME}/.local/share/godot/app_userdata/Glassvow"),
            ("mkdir", "${HOME}/.local/share/godot/app_userdata/Glassvow/logs"),
            ("newfstatat", "${PRODUCT}/addons/sentry/bin/linux/x86_64"),
            ("readlinkat", "/sys/bus/hid"),
            ("readlinkat", "/sys/bus/serio"),
            ("readlinkat", "/sys/bus/vmbus"),
            ("readlinkat", "/sys/bus/acpi"),
        }, actual)
        self.assertNotIn(("openat", "/sys/bus/hid"), actual)
        self.assertNotIn(("readlinkat", "/sys/bus/pci"), actual)
        self.assertEqual(
            {"chdir", "mkdir"},
            {operation for operation, path in actual
             if path == "${HOME}/.local/share/godot/app_userdata/Glassvow"},
        )
        verifier = VERIFIER_PATH.read_text(encoding="utf-8")
        tracer = (ROOT / "tools/execution_provenance/godot_runtime_ptrace_tracer.c").read_text(
            encoding="utf-8")
        self.assertNotIn('any(item.startswith(path.rstrip("/") + "/") for item in known)', verifier)
        self.assertIn("gv_path_within(task->resolved, home_root)", tracer)
        self.assertIn("gv_path_within(task->resolved, output_root)", tracer)

    def test_successful_system_path_grammar_is_exact_and_alias_bound(self) -> None:
        paths = self.profile["accessGrammar"]["paths"]
        directory_pairs = {(operation, path) for record in paths["successfulDirectoryOperations"]
                           for operation in record["operations"] for path in record["paths"]}
        self.assertEqual(37, len({path for _, path in directory_pairs}))
        self.assertIn(("openat", "/sys/dev/char"), directory_pairs)
        self.assertIn(("readlinkat", "/sys/devices/virtual/input/mice"), directory_pairs)
        self.assertNotIn(("mkdir", "/sys/devices"), directory_pairs)
        aliases = {record["path"]: record["target"]
                   for record in paths["successfulDirectoryAliases"]}
        self.assertEqual(9, len(aliases))
        self.assertEqual(
            "/sys/devices/0006:045E:0621.0001/input/input1/event1",
            aliases["/sys/dev/char/13:65"],
        )
        probes = {(operation, path) for record in paths["successfulProbeOperations"]
                  for operation in record["operations"] for path in record["paths"]}
        self.assertEqual(14, len(probes))
        self.assertEqual(
            {"chdir", "newfstatat"},
            set(paths["successfulWorkingDirectoryOperations"]),
        )
        named = {record["path"]: record for record in paths["successfulNamedPathOperations"]}
        self.assertEqual({"/dev/input/event0", "/dev/input/event1"}, set(named))
        self.assertEqual(
            ("character-device", 13, 64, ["stat"]),
            tuple(named["/dev/input/event0"][key]
                  for key in ("fileType", "major", "minor", "operations")),
        )
        self.assertNotIn("declaredProcPaths", paths)

    def test_clone3_vfork_is_preserved_as_a_clone_process(self) -> None:
        tracer = (ROOT / "tools/execution_provenance/godot_runtime_ptrace_tracer.c").read_text(
            encoding="utf-8")
        runner = RUNNER_PATH.read_text(encoding="utf-8")
        self.assertIn("parent->number == SYS_clone3", tracer)
        self.assertIn("parent->clone_flags & CLONE_VFORK", tracer)
        self.assertIn('!strcmp(kind, "clone_process") && flags == process.clone_flags', tracer)
        self.assertIn('checked([str(binary), "--self-test"])', runner)


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

    def test_platform_normalisation_preserves_complete_raw_bytes(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "c13:0"
            first = b"I:3296751\nE:ID_INPUT=1\nE:ID_INPUT_MOUSE=1\nE:ID_SERIAL=noserial\nV:1\n"
            normalised = b"I:<decimal>\nE:ID_INPUT=1\nE:ID_INPUT_MOUSE=1\nE:ID_SERIAL=noserial\nV:1\n"
            path.write_bytes(first)
            contract = {
                "path": str(path), "operations": ["read"],
                "contentNormalisation": "udev-initialisation-usec-decimal-v1",
                "maximumBytes": 512,
                "normalisedSha256": hashlib.sha256(normalised).hexdigest(),
            }
            logical, current, raw = self.verifier._platform_live(contract, {}, 4096)
            self.assertEqual(str(path), logical)
            self.assertEqual(first, raw)
            self.assertEqual(hashlib.sha256(first).hexdigest(), current["sha256"])
            path.write_bytes(first.replace(b"I:3296751", b"I:03296751"))
            with self.assertRaisesRegex(
                    self.verifier.VerificationFailure, "platform grammar differs"):
                self.verifier._platform_live(contract, {}, 4096)

    def test_bounded_reader_rejects_oversized_symlink_and_fifo_sources(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            oversized = root / "oversized.json"
            oversized.write_bytes(b"12345")
            target = root / "target.json"
            target.write_bytes(b"{}")
            symlink = root / "symlink.json"
            symlink.symlink_to(target)
            fifo = root / "fifo.json"
            os.mkfifo(fifo)
            for path, maximum in ((oversized, 4), (symlink, 16), (fifo, 16)):
                with self.subTest(path=path.name), self.assertRaises(
                        self.verifier.VerificationFailure):
                    self.verifier._bounded_bytes(path, maximum)

    def test_runtime_alias_is_bounded_but_semantic_alias_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            target = root / "runtime.bin"
            target.write_bytes(b"runtime")
            alias = root / "alias.bin"
            alias.symlink_to(target)
            metadata = target.stat()
            record = {
                "path": str(alias), "size": metadata.st_size,
                "sha256": sha256(target), "device": metadata.st_dev,
                "inode": metadata.st_ino,
            }
            self.assertEqual(
                b"runtime", self.verifier._live(
                    record, "RUNTIME_DEPENDENCY_MISMATCH", 16))
            with self.assertRaisesRegex(
                    self.verifier.VerificationFailure, "symlink role"):
                self.verifier._live(
                    record, "PROJECT_SEMANTIC_BYTES_MISMATCH", 16, True)
            with self.assertRaisesRegex(
                    self.verifier.VerificationFailure, "size exceeds cap"):
                self.verifier._live(
                    record, "RUNTIME_DEPENDENCY_MISMATCH", 4)

    def test_empty_platform_object_requires_current_zero_read_lifecycle(self) -> None:
        path = "/run/udev/data/c13:63"
        platform = {path: {"device": 13, "inode": 63}}
        events = [
            {"type": "OPEN", "path": path, "device": 13, "inode": 63},
            {"type": "SYSCALL_X", "name": "read", "returned": 0,
             "_fdPath": path},
            {"type": "CLOSE", "path": path, "device": 13, "inode": 63},
        ]
        self.verifier._platform_access_witnesses(events, platform)
        with self.assertRaisesRegex(
                self.verifier.VerificationFailure, "access witness missing"):
            self.verifier._platform_access_witnesses(
                [event for event in events if event["type"] != "SYSCALL_X"],
                platform,
            )

    def test_frozen_source_cache_reuses_the_exact_parsed_bytes(self) -> None:
        original = self.verifier.FROZEN_PROFILE_SHA256
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            profile = root / "profile.json"
            g0 = root / "g0.json"
            profile.write_bytes(PROFILE_PATH.read_bytes())
            g0.write_bytes((ROOT / "tools/execution_provenance/godot_runtime_g0_manifest.json").read_bytes())
            packet = root / "packet"
            packet.mkdir()
            (packet / "oracle.gd").write_bytes(b"extends SceneTree\n")
            (packet / "corpus.json").write_bytes(b"{}\n")
            manifest = packet / "manifest.json"
            manifest.write_text(json.dumps({
                "schema": "glassvow.godot-runtime-packet/v1",
                "productSha": "a" * 40,
                "packetRoot": "research_packets/frozen",
                "authorityIssue": 535,
                "authorityComment": 5530338723,
                "requestIndices": ["0"],
                "roles": {
                    "externalScript": {"path": "oracle.gd"},
                    "corpus": {"path": "corpus.json"},
                },
            }), encoding="utf-8")
            cache: dict[str, bytes] = {}
            try:
                self.verifier.FROZEN_PROFILE_SHA256 = sha256(profile)
                first = self.verifier._load_sources(profile, g0, manifest, cache)
                profile.unlink()
                g0.unlink()
                manifest.write_text("{}", encoding="utf-8")
                second = self.verifier._load_sources(profile, g0, manifest, cache)
                self.assertEqual(first, second)
                self.assertEqual(
                    {"profile", "g0Manifest", "packetManifest"}, set(cache))
            finally:
                self.verifier.FROZEN_PROFILE_SHA256 = original

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
            authority_issue=535, authority_comment=5530338723,
            packet_sha="f" * 40)
        roles = self.verifier._roles(
            g0, packet, {"PRODUCT": "/product", "PACKET": "/packet"},
            profile, args)
        self.assertEqual(30, len(roles))

    def test_environment_is_an_exact_unique_map_not_an_unmeasured_order(self) -> None:
        expected = ["HOME=/fresh", "PATH=/usr/bin:/bin", "LANG=C.UTF-8", "PWD=/observer"]
        self.assertEqual(
            self.verifier._environment(expected),
            self.verifier._environment(list(reversed(expected))),
        )
        with self.assertRaisesRegex(self.verifier.VerificationFailure, "ENVIRONMENT_MISMATCH"):
            self.verifier._environment(expected + ["HOME=/other"])

    def test_path_result_policy_binds_operation_path_arguments_and_return(self) -> None:
        profile = json.loads(PROFILE_PATH.read_text(encoding="utf-8"))
        manifest = json.loads(G0_MANIFEST_PATH.read_text(encoding="utf-8"))
        roots = {
            "GODOT": "/home/runner/work/_temp/godot/godot",
            "PRODUCT": "/tmp/frozen/product",
            "PACKET": "/tmp/frozen/packet",
            "HOME": "/tmp/runtime/G00/home",
            "OUTPUT": "/tmp/runtime/G00/output",
        }
        policy, counts = self.verifier._build_admission_policy(
            profile, manifest, roots, ROOT)
        statement = {
            "caseId": "G00",
            "admissionPolicy": {
                "schema": profile["kernelAdmission"]["policySchema"],
                "file": "admission-policy.tsv",
                "size": len(policy),
                "sha256": hashlib.sha256(policy).hexdigest(),
                **counts,
            },
        }
        policy_event = {
            "type": "POLICY", "byteCount": len(policy), **counts}

        def verify(event: dict, case_id: str = "G00") -> None:
            statement["caseId"] = case_id
            self.verifier._admission_policy(
                statement, manifest, roots, profile,
                {"admission-policy.tsv": policy},
                {"events": [policy_event, event]},
            )

        output = f'{roots["OUTPUT"]}/observation.json'
        verify({
            "type": "PATH_X", "operation": "openat", "returned": 91,
            "path": output, "_arguments": [-100, 0, 577, 0, 0, 0],
        })
        verify({
            "type": "PATH_X", "operation": "openat", "returned": 91,
            "path": "/sys/devices/0006:045E:0621.0001",
            "_arguments": [-100, 0, 2621696, 0, 0, 0],
        })
        verify({
            "type": "PATH_X", "operation": "mkdir", "returned": -17,
            "path": "/tmp/runtime/G00", "_arguments": [0, 509, 0, 0, 0, 0],
        })
        verify({
            "type": "PATH_X", "operation": "readlink", "returned": -22,
            "path": "/tmp/frozen", "_arguments": [0, 0, 0, 0, 0, 0],
        })
        verify({
            "type": "PATH_X", "operation": "openat", "returned": -13,
            "path": output, "_arguments": [-100, 0, 577, 0, 0, 0],
        }, "G15")
        for changed in (
                {"type": "PATH_X", "operation": "openat", "returned": 91,
                 "path": output, "_arguments": [-100, 0, 1, 0, 0, 0]},
                {"type": "PATH_X", "operation": "openat", "returned": -2,
                 "path": output, "_arguments": [-100, 0, 577, 0, 0, 0]},
                {"type": "PATH_X", "operation": "mkdir", "returned": -17,
                 "path": "/tmp/runtime/G00", "_arguments": [0, 508, 0, 0, 0, 0]},
                {"type": "PATH_X", "operation": "readlink", "returned": -2,
                 "path": "/tmp/frozen", "_arguments": [0, 0, 0, 0, 0, 0]}):
            with self.assertRaises(self.verifier.VerificationFailure):
                verify(changed)

    def test_network_contract_binds_socket_and_sockaddr_tuple(self) -> None:
        profile = json.loads(PROFILE_PATH.read_text(encoding="utf-8"))
        sockets = [{"type": "SOCKET", "fd": fd, "family": 16,
                    "socketType": 526339, "protocol": 15} for fd in (5, 6)]
        binds = [{"type": "BIND", "fd": fd, "family": 16, "pid": 0,
                  "groups": 2, "addressLength": 12, "returned": 0} for fd in (5, 6)]
        self.verifier._network({"events": sockets + binds}, profile)
        binds[0]["groups"] = 1
        with self.assertRaisesRegex(self.verifier.VerificationFailure, "FORBIDDEN_NETWORK_FAMILY"):
            self.verifier._network({"events": sockets + binds}, profile)

    def test_checkout_identity_binds_head_and_tracked_cleanliness(self) -> None:
        with tempfile.TemporaryDirectory(prefix="godot-checkout-") as temporary:
            repository = Path(temporary) / "repository"
            subprocess.run(["git", "init", "-q", str(repository)], check=True)
            tracked = repository / "tracked.txt"
            tracked.write_text("frozen\n", encoding="utf-8")
            subprocess.run(["git", "-C", str(repository), "add", "tracked.txt"], check=True)
            subprocess.run([
                "git", "-C", str(repository), "-c", "user.name=Glassvow test",
                "-c", "user.email=glassvow@example.invalid", "commit", "-qm", "freeze",
            ], check=True)
            expected = subprocess.check_output(
                ["git", "-C", str(repository), "rev-parse", "HEAD"], text=True).strip()
            self.assertEqual((expected, True), self.verifier._checkout_identity(repository))
            tracked.write_text("changed\n", encoding="utf-8")
            self.assertEqual((expected, False), self.verifier._checkout_identity(repository))

    def _measured_lineage_fixture(self) -> tuple[dict, dict]:
        profile = json.loads(PROFILE_PATH.read_text(encoding="utf-8"))
        graph = profile["processGraph"]
        root, shell, xdg = 100, 200, 300
        threads = list(range(101, 108))
        events: list[dict] = [
            {"type": "EXEC", "sequence": 1, "tid": root, "tgid": root},
            {"type": "EXEC", "sequence": 2, "tid": root, "tgid": root},
            {"type": "PIPE", "sequence": 10, "tid": root, "path": "pipe:[111]"},
            {"type": "DUP", "sequence": 20, "tid": root, "operation": "dup2",
             "sourceFd": 4, "targetFd": 1, "path": "pipe:[111]", "closeOnExec": 0},
            {"type": "LINEAGE", "sequence": 29, "tid": root, "childTid": shell,
             "kind": graph["rootToShellKind"], "cloneFlags": graph["rootToShellFlags"]},
            {"type": "EXEC", "sequence": 30, "tid": shell, "tgid": shell},
            {"type": "DUP", "sequence": 40, "tid": shell, "operation": "fcntl",
             "sourceFd": 2, "targetFd": 10, "path": "pipe:[900]", "closeOnExec": 0},
            {"type": "DUP", "sequence": 41, "tid": shell, "operation": "dup2",
             "sourceFd": 5, "targetFd": 2, "path": "/dev/null", "closeOnExec": 0},
            {"type": "LINEAGE", "sequence": 44, "tid": shell, "childTid": xdg,
             "kind": graph["shellToXdgKind"], "cloneFlags": graph["shellToXdgFlags"]},
            {"type": "DUP", "sequence": 45, "tid": shell, "operation": "dup2",
             "sourceFd": 10, "targetFd": 2, "path": "pipe:[900]", "closeOnExec": 0},
            {"type": "EXEC", "sequence": 50, "tid": xdg, "tgid": xdg},
            {"type": "DUP", "sequence": 51, "tid": xdg, "operation": "fcntl",
             "sourceFd": 3, "targetFd": 10, "path": "/usr/bin/xdg-user-dir",
             "closeOnExec": 0},
            {"type": "EXIT", "sequence": 60, "tid": xdg, "status": 0},
            {"type": "SIGNAL", "sequence": 61, "tid": shell, "signal": 17},
            {"type": "EXIT", "sequence": 62, "tid": shell, "status": 0},
            {"type": "SIGNAL", "sequence": 63, "tid": root, "signal": 17},
        ]
        events.extend({
            "type": "LINEAGE", "sequence": 3 + index, "tid": root,
            "childTid": tid, "kind": graph["rootThreadKind"],
            "cloneFlags": graph["rootThreadFlags"],
        } for index, tid in enumerate(threads))
        events.extend({"type": "EXIT", "sequence": 70 + index,
                       "tid": tid, "status": 0}
                      for index, tid in enumerate(threads))
        events.append({"type": "EXIT", "sequence": 80, "tid": root, "status": 0})
        events.extend({"type": "SYSCALL_E", "sequence": 90 + index,
                       "tid": root, "name": "clone3"}
                      for index in range(8))
        events.extend((
            {"type": "SYSCALL_E", "sequence": 98, "tid": shell, "name": "vfork"},
            {"type": "SYSCALL_E", "sequence": 99, "tid": root, "name": "pipe2",
             "arguments": [3, profile["accessGrammar"]["internalPipe"]["pipe2Flags"],
                           0, 0, 0, 0]},
        ))
        events.extend({"type": "SYSCALL_E", "sequence": 100 + index,
                       "tid": shell, "name": "dup2"}
                      for index in range(3))
        return {"events": events, "end": {"taskCount": 10, "rootExit": 0}}, profile

    def test_process_signal_grammar_requires_each_sigchld_after_its_child_exit(self) -> None:
        trace, profile = self._measured_lineage_fixture()
        self.verifier._lineage(trace, profile, diagnostic=False)
        signals = [event for event in trace["events"] if event["type"] == "SIGNAL"]
        signals[0]["sequence"] = 59
        with self.assertRaisesRegex(
                self.verifier.VerificationFailure, "SIGCHLD process ordering"):
            self.verifier._lineage(trace, profile, diagnostic=False)

    def test_process_lineage_requires_exact_pipe_flags(self) -> None:
        trace, profile = self._measured_lineage_fixture()
        pipe = next(event for event in trace["events"]
                    if event.get("name") == "pipe2")
        self.verifier._lineage(trace, profile, diagnostic=False)
        pipe["arguments"][1] = 0
        with self.assertRaisesRegex(
                self.verifier.VerificationFailure, "internal pipe syscall shape"):
            self.verifier._lineage(trace, profile, diagnostic=False)

    def test_runtime_mapping_contract_is_exact_but_allows_measured_shared_and_eof_span(self) -> None:
        roots = {"PRODUCT": "/product"}
        events = [
            {"type": "MMAP", "path": "/runtime/cache", "offset": 0, "length": 27028,
             "protection": 1, "flags": 1},
            {"type": "MMAP", "path": "/product/lib.so", "offset": 0, "length": 5000,
             "protection": 1, "flags": 2050},
        ]
        normal = [
            {"path": "${PRODUCT}/lib.so", "offset": 0, "length": 5000,
             "protection": 1, "flags": 2050},
            {"path": "/runtime/cache", "offset": 0, "length": 27028,
             "protection": 1, "flags": 1},
        ]
        contract = {
            "count": 2, "canonicalMultisetSha256": self.verifier._sha(
                self.verifier._canonical(normal)),
            "protectionValues": [1, 3, 5], "flagValues": [1, 2, 2050, 2066],
            "sharedReadOnlyPaths": ["/runtime/cache"],
        }
        profile = {"accessGrammar": {"mappings": {"runtimeIdentity": contract}}}
        self.verifier._runtime_mappings({"events": events}, roots, profile)
        events[1]["length"] += 1
        with self.assertRaisesRegex(self.verifier.VerificationFailure, "multiset"):
            self.verifier._runtime_mappings({"events": events}, roots, profile)

    def test_receipt_semantic_digest_binds_the_captured_sidecar_bytes(self) -> None:
        with tempfile.TemporaryDirectory(prefix="godot-receipt-") as temporary:
            case = Path(temporary)
            statement = {"roles": [{"path": "/packet/corpus.json", "size": 3}]}
            trace = {
                "events": [{
                    "type": "READ", "classification": "S", "sequence": 1,
                    "tid": 100, "operation": "read", "fd": 7, "offset": 0,
                    "requested": 3, "returned": 3, "device": 1, "inode": 2,
                    "path": "/packet/corpus.json", "sidecarOffset": 0,
                }],
                "end": {},
            }
            first = self.verifier._receipt_details(statement, trace, b"abc", case)
            second = self.verifier._receipt_details(statement, trace, b"abd", case)
            self.assertNotEqual(
                first["semanticConsumption"]["canonicalSha256"],
                second["semanticConsumption"]["canonicalSha256"],
            )

    def _incomplete_case_args(self, root: Path, case_dir: Path) -> types.SimpleNamespace:
        challenge = root / "challenge.txt"
        challenge.write_text(TRACE_CHALLENGE + "\n", encoding="ascii")
        packet_manifest = root / "manifest.json"
        packet_manifest.write_text(json.dumps({
            "schema": "glassvow.godot-runtime-packet/v1", "productSha": "a" * 40,
            "packetRoot": "research_packets/frozen", "authorityIssue": 535,
            "authorityComment": 5530338723, "requestIndices": ["0"], "roles": {},
        }), encoding="utf-8")
        return types.SimpleNamespace(
            profile=PROFILE_PATH, g0_manifest=ROOT / "tools/execution_provenance/godot_runtime_g0_manifest.json",
            packet_manifest=packet_manifest, case_id="G24", case_dir=case_dir, challenge=challenge,
            observer_sha="c" * 40, product_sha="a" * 40, packet_sha="b" * 40,
            packet_root="research_packets/frozen", authority_issue=535,
            authority_comment=5530338723, request_index="0",
            expected_godot=root / "godot", expected_product_source=root / "product-source",
            expected_product_stage=root / "product-stage",
            expected_product_stage_receipt=root / "product-stage-receipt.json",
            expected_packet_source=root / "packet-source", expected_product_mount=root / "product",
            expected_packet_mount=root / "packet", expected_runtime_root=root / "runtime")

    def test_missing_malformed_statement_and_trace_return_inconclusive_receipts(self) -> None:
        self.verifier.FROZEN_PROFILE_SHA256 = sha256(PROFILE_PATH)
        with tempfile.TemporaryDirectory(prefix="godot-incomplete-") as temporary:
            root = Path(temporary)
            for name in ("missing", "bad-statement", "bad-trace"):
                case = root / name; case.mkdir()
                args = self._incomplete_case_args(root, case)
                if name == "bad-statement":
                    (case / "statement.json").write_text("{", encoding="utf-8")
                elif name == "bad-trace":
                    sidecar = b""; (case / "sidecar.bin").write_bytes(sidecar)
                    trace = ("\n".join(strict_trace_envelope([
                        "UNKNOWN\t2\t100",
                    ])) + "\n").encode()
                    (case / "trace.tsv").write_bytes(trace)
                    (case / "statement.json").write_text(json.dumps({
                        "trace": {"file": "trace.tsv", "size": len(trace),
                                  "sha256": hashlib.sha256(trace).hexdigest()},
                        "sidecar": {"file": "sidecar.bin", "size": 0,
                                    "sha256": hashlib.sha256(sidecar).hexdigest()},
                    }), encoding="utf-8")
                receipt = self.verifier.verify_case(args)
                self.assertEqual(("INCONCLUSIVE", "PROVENANCE_INCOMPLETE"),
                                 (receipt["verdict"], receipt["reason"]))
                self.assertEqual(64, len(receipt["receiptSha256"]))

    def test_missing_challenge_or_malformed_frozen_source_still_returns_receipt(self) -> None:
        original_profile_hash = self.verifier.FROZEN_PROFILE_SHA256
        with tempfile.TemporaryDirectory(prefix="godot-source-incomplete-") as temporary:
            root = Path(temporary)
            try:
                cases: list[tuple[str, types.SimpleNamespace]] = []

                def arguments(label: str) -> types.SimpleNamespace:
                    base = root / label
                    case = base / "case"
                    case.mkdir(parents=True)
                    return self._incomplete_case_args(base, case)

                missing_args = arguments("missing-challenge")
                missing_args.challenge.unlink()
                self.verifier.FROZEN_PROFILE_SHA256 = sha256(PROFILE_PATH)
                cases.append(("challenge", missing_args))

                packet_args = arguments("bad-packet")
                packet_args.packet_manifest.write_text("{", encoding="utf-8")
                cases.append(("packetManifest", packet_args))

                g0_args = arguments("bad-g0")
                g0_args.g0_manifest = root / "bad-g0.json"
                g0_args.g0_manifest.write_text("{", encoding="utf-8")
                cases.append(("g0Manifest", g0_args))

                profile_args = arguments("bad-profile")
                profile_args.profile = root / "bad-profile.json"
                profile_args.profile.write_text("{", encoding="utf-8")

                for source, args in cases:
                    self.verifier.FROZEN_PROFILE_SHA256 = sha256(PROFILE_PATH)
                    receipt = self.verifier.verify_case(args)
                    self.assertEqual(
                        ("INCONCLUSIVE", "PROVENANCE_INCOMPLETE"),
                        (receipt["verdict"], receipt["reason"]), source)
                    self.assertEqual(64, len(receipt["receiptSha256"]))
                    self.assertIn(source, receipt["sourceEvidence"])

                self.verifier.FROZEN_PROFILE_SHA256 = sha256(profile_args.profile)
                receipt = self.verifier.verify_case(profile_args)
                self.assertEqual(
                    ("INCONCLUSIVE", "PROVENANCE_INCOMPLETE"),
                    (receipt["verdict"], receipt["reason"]))
                self.assertTrue(receipt["sourceEvidence"]["profile"]["present"])
            finally:
                self.verifier.FROZEN_PROFILE_SHA256 = original_profile_hash


@unittest.skipUnless(sys.platform.startswith("linux"), "Landlock is Linux-only")
class GodotRuntimeKernelAdmissionTests(unittest.TestCase):
    def test_no_follow_path_and_fd_identity_preserve_the_final_symlink(self) -> None:
        compiler = shutil.which("cc")
        if compiler is None:
            self.skipTest("C compiler unavailable")
        source_root = ROOT / "tools/execution_provenance"
        harness_source = r'''
#define _GNU_SOURCE
#include "godot_runtime_ptrace_io.h"
#include <fcntl.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>
int main(int argc, char **argv) {
    if (argc != 3) return 2;
    char followed[4096], nofollow[4096];
    if (!gv_resolve_path(getpid(), AT_FDCWD, argv[1], true,
                         followed, sizeof(followed))) return 3;
    if (!gv_resolve_path(getpid(), AT_FDCWD, argv[1], false,
                         nofollow, sizeof(nofollow))) return 4;
    if (strcmp(followed, argv[2]) || strcmp(nofollow, argv[1])) return 5;
    int descriptor = open(argv[1], O_PATH | O_NOFOLLOW | O_CLOEXEC);
    if (descriptor < 0) return 6;
    struct gv_object_identity object;
    struct stat link;
    if (!gv_fd_identity(getpid(), descriptor, &object)
            || lstat(argv[1], &link) != 0) return 7;
    close(descriptor);
    if (strcmp(object.path, argv[1]) || object.device != link.st_dev
            || object.inode != link.st_ino) return 8;
    if (!gv_existing_directory(argv[2]) || gv_existing_directory(argv[1])) return 9;
    return 0;
}
'''
        with tempfile.TemporaryDirectory(prefix="godot-nofollow-test-") as temporary:
            root = Path(temporary)
            target, alias = root / "target", root / "alias"
            target.mkdir()
            alias.symlink_to(target, target_is_directory=True)
            source = root / "nofollow.c"
            binary = root / "nofollow"
            source.write_text(harness_source, encoding="utf-8")
            compiled = subprocess.run([
                compiler, "-std=c17", "-O2", "-Wall", "-Wextra", "-Werror",
                "-I", str(source_root), str(source),
                str(source_root / "godot_runtime_ptrace_io.c"), "-o", str(binary),
            ], check=False, capture_output=True, text=True)
            self.assertEqual(0, compiled.returncode, compiled.stderr)
            result = subprocess.run([
                str(binary), str(alias), str(target.resolve()),
            ], check=False, capture_output=True, text=True)
            self.assertEqual(0, result.returncode, result.stderr or result.stdout)

    def test_missing_path_with_repeated_separators_is_canonicalised(self) -> None:
        compiler = shutil.which("cc")
        if compiler is None:
            self.skipTest("C compiler unavailable")
        source_root = ROOT / "tools/execution_provenance"
        harness_source = r'''
#define _GNU_SOURCE
#include "godot_runtime_ptrace_io.h"
#include <fcntl.h>
#include <string.h>
#include <unistd.h>
int main(int argc, char **argv) {
    if (argc != 3) return 2;
    char followed[4096], nofollow[4096];
    if (!gv_resolve_path(getpid(), AT_FDCWD, argv[1], true,
                         followed, sizeof(followed))) return 3;
    if (!gv_resolve_path(getpid(), AT_FDCWD, argv[1], false,
                         nofollow, sizeof(nofollow))) return 4;
    if (strcmp(followed, argv[2]) || strcmp(nofollow, argv[2])) return 5;
    return 0;
}
'''
        with tempfile.TemporaryDirectory(prefix="godot-path-test-") as temporary:
            root = Path(temporary).resolve()
            unresolved = f"{root}//.cache/fontconfig//cache-9"
            expected = root / ".cache/fontconfig/cache-9"
            source = root / "path.c"
            binary = root / "path"
            source.write_text(harness_source, encoding="utf-8")
            compiled = subprocess.run([
                compiler, "-std=c17", "-O2", "-Wall", "-Wextra", "-Werror",
                "-I", str(source_root), str(source),
                str(source_root / "godot_runtime_ptrace_io.c"), "-o", str(binary),
            ], check=False, capture_output=True, text=True)
            self.assertEqual(0, compiled.returncode, compiled.stderr)
            result = subprocess.run([
                str(binary), unresolved, str(expected),
            ], check=False, capture_output=True, text=True)
            self.assertEqual(0, result.returncode, result.stderr or result.stdout)

    def test_exact_reads_execs_descriptors_and_writes_are_kernel_enforced(self) -> None:
        compiler = shutil.which("cc")
        if compiler is None:
            self.skipTest("C compiler unavailable")
        source_root = ROOT / "tools/execution_provenance"
        harness_source = r'''
#define _GNU_SOURCE
#include "godot_runtime_ptrace_io.h"
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/prctl.h>
#include <sys/wait.h>
#include <unistd.h>

static int write_new(const char *directory, const char *name) {
    char path[4096];
    if (snprintf(path, sizeof(path), "%s/%s", directory, name) >= (int)sizeof(path)) return 30;
    int fd = open(path, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, 0600);
    if (fd < 0) return 31;
    int result = write(fd, "allowed", 7) == 7 ? 0 : 32;
    close(fd); return result;
}

static int exec_result(const char *path, int expected) {
    pid_t child = fork();
    if (child < 0) return 40;
    if (child == 0) {
        execl(path, path, NULL);
        _exit(errno == EACCES || errno == EPERM ? 90 : 91);
    }
    int status;
    if (waitpid(child, &status, 0) != child || !WIFEXITED(status)
            || WEXITSTATUS(status) != expected) return 41;
    return 0;
}

int main(int argc, char **argv) {
    if (argc < 10) return 9;
    int abi = gv_landlock_abi();
    if (abi < 3) { fprintf(stderr, "Landlock ABI %d is below 3\n", abi); return 10; }
    struct gv_admission_policy policy;
    if (!gv_load_admission_policy(argv[1], 393216, &policy)) return 11;
    int inherited = atoi(argv[8]);
    if (!gv_sanitise_descriptors()) return 12;
    char stdin_byte;
    if (read(STDIN_FILENO, &stdin_byte, 1) != 0) return 13;
    errno = 0;
    if (fcntl(inherited, F_GETFD) != -1 || errno != EBADF) return 14;
    if (!gv_restrict_access(argv[2], argv[3], &policy)) return 15;
    if (prctl(PR_GET_NO_NEW_PRIVS, 0, 0, 0, 0) != 1) return 12;
    int allowed = open(argv[4], O_RDONLY | O_CLOEXEC);
    char bytes[7];
    if (allowed < 0 || read(allowed, bytes, sizeof(bytes)) != sizeof(bytes)
            || memcmp(bytes, "allowed", sizeof(bytes))) return 15;
    close(allowed);
    errno = 0;
    int secret = open(argv[5], O_RDONLY | O_CLOEXEC);
    if (secret >= 0 || (errno != EACCES && errno != EPERM)) return 16;
    if (exec_result(argv[6], 0) || exec_result(argv[7], 90)) return 17;
    for (int index = 9; index < argc; index += 1) {
        errno = 0;
        int fd = open(argv[index], O_WRONLY | O_TRUNC | O_CLOEXEC);
        if (fd >= 0) { close(fd); return 18; }
        if (errno != EACCES && errno != EPERM) return 19;
    }
    if (write_new(argv[2], "home-write") != 0) return 20;
    if (write_new(argv[3], "output-write") != 0) return 21;
    int sink = open("/dev/null", O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0666);
    if (sink < 0 || write(sink, "sink", 4) != 4) return 22;
    close(sink); gv_free_admission_policy(&policy); return 0;
}
'''
        with tempfile.TemporaryDirectory(prefix="godot-landlock-test-") as temporary:
            root = Path(temporary)
            home, output = root / "home", root / "output"
            home.mkdir(); output.mkdir()
            allowed_read, secret_read = root / "allowed-read", root / "secret-read"
            allowed_read.write_bytes(b"allowed"); secret_read.write_bytes(b"secret!")
            assembly = root / "probe.S"
            assembly.write_text(
                ".global _start\n_start:\nmov $60, %rax\nxor %rdi, %rdi\nsyscall\n",
                encoding="ascii")
            allowed_exec, secret_exec = root / "allowed-exec", root / "secret-exec"
            probe_result = subprocess.run([
                compiler, "-nostdlib", "-static", "-Wl,--build-id=none",
                str(assembly), "-o", str(allowed_exec),
            ], check=False, capture_output=True, text=True)
            self.assertEqual(0, probe_result.returncode, probe_result.stderr)
            shutil.copyfile(allowed_exec, secret_exec)
            allowed_exec.chmod(0o555); secret_exec.chmod(0o555)
            policy = root / "policy.tsv"
            rules = [
                f"F\tR\t{str(allowed_read.resolve()).encode().hex()}",
                f"F\tRX\t{str(allowed_exec.resolve()).encode().hex()}",
                f"P\topenat\t0\t{str(allowed_read.resolve()).encode().hex()}",
            ]
            policy.write_text("GODOTACCESSv1\n" + "\n".join(sorted(rules)) + "\n",
                              encoding="ascii")
            protected = [root / name for name in (
                "verifier.py", "build.json", "trace.tsv", "prior-receipt.json")]
            for path in protected:
                path.write_bytes((path.name + "-original").encode())
            harness = root / "admission_harness.c"
            binary = root / "admission_harness"
            harness.write_text(harness_source, encoding="utf-8")
            compile_result = subprocess.run([
                compiler, "-std=c17", "-O2", "-Wall", "-Wextra", "-Werror",
                "-I", str(source_root), str(harness),
                str(source_root / "godot_runtime_ptrace_io.c"), "-o", str(binary),
            ], check=False, capture_output=True, text=True)
            self.assertEqual(0, compile_result.returncode, compile_result.stderr)
            inherited = os.open(secret_read, os.O_RDONLY)
            try:
                with secret_read.open("rb") as standard_input:
                    result = subprocess.run([
                        str(binary), str(policy), str(home), str(output),
                        str(allowed_read), str(secret_read), str(allowed_exec),
                        str(secret_exec), str(inherited),
                        str(policy), *(str(path) for path in protected),
                    ], check=False, capture_output=True, text=True,
                        stdin=standard_input, pass_fds=(inherited,))
            finally:
                os.close(inherited)
            self.assertEqual(0, result.returncode, result.stderr or result.stdout)
            self.assertTrue(policy.read_bytes().startswith(b"GODOTACCESSv1\n"))
            for path in protected:
                self.assertEqual((path.name + "-original").encode(), path.read_bytes())
            self.assertEqual(b"allowed", (home / "home-write").read_bytes())
            self.assertEqual(b"allowed", (output / "output-write").read_bytes())

    def test_dynamic_exec_requires_the_exact_kernel_interpreter_leaf(self) -> None:
        compiler, readelf, ldd = (shutil.which(name) for name in ("cc", "readelf", "ldd"))
        if compiler is None or readelf is None or ldd is None:
            self.skipTest("dynamic-linker test tools unavailable")
        source_root = ROOT / "tools/execution_provenance"
        harness_source = r'''
#define _GNU_SOURCE
#include "godot_runtime_ptrace_io.h"
#include <errno.h>
#include <unistd.h>
int main(int argc, char **argv) {
    if (argc != 5) return 2;
    struct gv_admission_policy policy;
    if (!gv_load_admission_policy(argv[1], 393216, &policy)) return 3;
    if (!gv_sanitise_descriptors()) return 4;
    if (!gv_restrict_access(argv[2], argv[3], &policy)) return 5;
    execl(argv[4], argv[4], NULL);
    return errno == EACCES || errno == EPERM ? 90 : 91;
}
'''
        with tempfile.TemporaryDirectory(prefix="godot-dynamic-landlock-") as temporary:
            root = Path(temporary)
            home, output = root / "home", root / "output"
            home.mkdir(); output.mkdir()
            probe_source = root / "dynamic-probe.c"
            probe_source.write_text("int main(void) { return 0; }\n", encoding="ascii")
            probe = root / "dynamic-probe"
            subprocess.run([compiler, str(probe_source), "-o", str(probe)], check=True)
            elf = subprocess.run(
                [readelf, "-l", str(probe)], check=True,
                capture_output=True, text=True).stdout
            interpreter_lines = [line for line in elf.splitlines()
                                 if "Requesting program interpreter:" in line]
            self.assertEqual(1, len(interpreter_lines))
            requested = interpreter_lines[0].split(
                "Requesting program interpreter:", 1)[1].strip().rstrip("]")
            interpreter = Path(requested).resolve(strict=True)
            dependencies = set()
            linked = subprocess.run(
                [ldd, str(probe)], check=True, capture_output=True, text=True).stdout
            for line in linked.splitlines():
                for token in line.replace("=>", " ").split():
                    candidate = token.split("(", 1)[0]
                    if candidate.startswith("/") and Path(candidate).exists():
                        dependencies.add(Path(candidate).resolve(strict=True))
            dependencies.discard(interpreter)
            cache = Path("/etc/ld.so.cache")
            if cache.is_file():
                dependencies.add(cache.resolve(strict=True))

            harness = root / "dynamic-exec-harness.c"
            harness.write_text(harness_source, encoding="utf-8")
            binary = root / "dynamic-exec-harness"
            compile_result = subprocess.run([
                compiler, "-std=c17", "-O2", "-Wall", "-Wextra", "-Werror",
                "-I", str(source_root), str(harness),
                str(source_root / "godot_runtime_ptrace_io.c"), "-o", str(binary),
            ], check=False, capture_output=True, text=True)
            self.assertEqual(0, compile_result.returncode, compile_result.stderr)

            def write_policy(path: Path, include_interpreter: bool) -> None:
                rights = {str(probe.resolve()): "RX"}
                rights.update({str(item): "R" for item in dependencies})
                if include_interpreter:
                    rights[str(interpreter)] = "RX"
                lines = [f"F\t{value}\t{key.encode().hex()}"
                         for key, value in rights.items()]
                lines.append(f"P\texecve\t-\t{str(probe.resolve()).encode().hex()}")
                path.write_text(
                    "GODOTACCESSv1\n" + "\n".join(sorted(lines)) + "\n",
                    encoding="ascii")

            complete, missing = root / "complete.tsv", root / "missing-loader.tsv"
            write_policy(complete, True); write_policy(missing, False)
            admitted = subprocess.run([
                str(binary), str(complete), str(home), str(output), str(probe),
            ], check=False, capture_output=True, text=True)
            self.assertEqual(0, admitted.returncode, admitted.stderr or admitted.stdout)
            denied = subprocess.run([
                str(binary), str(missing), str(home), str(output), str(probe),
            ], check=False, capture_output=True, text=True)
            self.assertEqual(90, denied.returncode, denied.stderr or denied.stdout)

    def test_policy_parser_rejects_broad_alias_duplicate_and_nul_rules(self) -> None:
        compiler = shutil.which("cc")
        if compiler is None:
            self.skipTest("C compiler unavailable")
        source_root = ROOT / "tools/execution_provenance"
        parser_source = r'''
#include "godot_runtime_ptrace_io.h"
int main(int argc, char **argv) {
    if (argc != 2) return 2;
    struct gv_admission_policy policy;
    if (!gv_load_admission_policy(argv[1], 393216, &policy)) return 1;
    gv_free_admission_policy(&policy); return 0;
}
'''
        with tempfile.TemporaryDirectory(prefix="godot-policy-parser-") as temporary:
            root = Path(temporary)
            leaf = root / "leaf"; leaf.write_bytes(b"leaf")
            alias = root / "alias"; alias.symlink_to(leaf)
            harness = root / "parser.c"; harness.write_text(parser_source, encoding="utf-8")
            binary = root / "parser"
            compile_result = subprocess.run([
                compiler, "-std=c17", "-O2", "-Wall", "-Wextra", "-Werror",
                "-I", str(source_root), str(harness),
                str(source_root / "godot_runtime_ptrace_io.c"), "-o", str(binary),
            ], check=False, capture_output=True, text=True)
            self.assertEqual(0, compile_result.returncode, compile_result.stderr)

            def payload(file_rules: list[tuple[str, str]]) -> bytes:
                lines = [f"F\t{rights}\t{path.encode().hex()}"
                         for rights, path in file_rules]
                lines.append(f"P\topenat\t0\t{str(leaf).encode().hex()}")
                return ("GODOTACCESSv1\n" + "\n".join(sorted(lines)) + "\n").encode()

            valid = root / "valid.tsv"; valid.write_bytes(payload([("R", str(leaf))]))
            self.assertEqual(0, subprocess.run([str(binary), str(valid)]).returncode)
            invalid_payloads = {
                "broad": payload([("R", "/")]),
                "alias": payload([("R", str(alias))]),
                "dot": payload([("R", f"{root}/missing/../leaf")]),
                "duplicate": payload([("R", str(leaf)), ("RX", str(leaf))]),
                "nul": payload([("R", str(leaf))]).replace(b"GODOTACCESSv1\n", b"GODOTACCESSv1\0\n"),
            }
            for name, data in invalid_payloads.items():
                candidate = root / f"{name}.tsv"; candidate.write_bytes(data)
                self.assertNotEqual(
                    0, subprocess.run([str(binary), str(candidate)]).returncode,
                    name)


class GodotRuntimeRunnerContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        spec = importlib.util.spec_from_file_location(
            "godot_runtime_runner", RUNNER_PATH)
        assert spec and spec.loader
        cls.runner = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.runner)
        verify_spec = importlib.util.spec_from_file_location(
            "godot_runtime_verify_stage", VERIFIER_PATH)
        assert verify_spec and verify_spec.loader
        cls.verifier = importlib.util.module_from_spec(verify_spec)
        verify_spec.loader.exec_module(cls.verifier)
        cls.profile = json.loads(PROFILE_PATH.read_text(encoding="utf-8"))

    def test_complete_hosted_policy_fits_the_frozen_caps_and_both_builders_agree(self) -> None:
        manifest = json.loads(G0_MANIFEST_PATH.read_text(encoding="utf-8"))
        runtime = "/home/runner/work/glassvow/glassvow/artifacts/godot-runtime/qualification/runtime/G00"
        mounts = "/tmp/glassvow-godot-runtime-input-abcdefgh"
        roots = {
            "GODOT": "/home/runner/work/_temp/godot/godot",
            "PRODUCT": f"{mounts}/product",
            "PACKET": f"{mounts}/packet",
            "HOME": f"{runtime}/home",
            "OUTPUT": f"{runtime}/output",
        }
        working = Path("/home/runner/work/glassvow/glassvow")
        produced, produced_counts = self.runner.build_admission_policy(
            self.profile, manifest, roots, working)
        verified, verified_counts = self.verifier._build_admission_policy(
            self.profile, manifest, roots, working)
        self.assertEqual(produced, verified)
        self.assertEqual({"fileRules": 169, "pathRules": 799}, produced_counts)
        self.assertEqual(produced_counts, verified_counts)
        self.assertLessEqual(len(produced), self.profile["caps"]["maxAdmissionPolicyBytes"])
        self.assertEqual(393216, self.profile["caps"]["maxAdmissionPolicyBytes"])

        def expand(template: str) -> str:
            result = template
            for name, value in roots.items():
                result = result.replace("${" + name + "}", value)
            self.assertNotIn("${", result)
            return os.path.normpath(result)

        expected_file_rights: dict[str, set[str]] = {}
        for section in ("semanticReadSet", "runtimeIdentitySet", "platformObservationSet"):
            for record in manifest[section]:
                path = str(Path(expand(record["path"])).resolve(strict=False))
                expected_file_rights.setdefault(path, set()).add("R")
        for collection in ("executeLeaves", "kernelInterpreterLeaves"):
            for template in self.profile["kernelAdmission"][collection]:
                path = str(Path(expand(template)).resolve(strict=False))
                expected_file_rights.setdefault(path, set()).add("X")
        expected_file_rules = {
            f"F\t{''.join(sorted(rights))}\t{path.encode().hex()}"
            for path, rights in expected_file_rights.items()
        }
        actual_file_rules = {
            line for line in produced.decode("ascii").splitlines()
            if line.startswith("F\t")
        }
        self.assertEqual(expected_file_rules, actual_file_rules)
        self.assertEqual(len(expected_file_rules), produced_counts["fileRules"])

        expected_path_rules = {
            "\t".join((
                "P", record["operation"],
                "-" if record["parameter"] is None else str(record["parameter"]),
                (str(Path(expand(record["path"])).resolve(strict=False))
                 if record["operation"] == "execve"
                 else expand(record["path"])).encode().hex(),
            ))
            for record in manifest["pathOperationClosure"]["records"]
        }
        for root in roots.values():
            candidate = Path(root).parent
            while str(candidate) != candidate.parent.as_posix():
                expected_path_rules.add(
                    f"P\treadlink\t-\t{str(candidate).encode().hex()}")
                candidate = candidate.parent
            expected_path_rules.add(
                f"P\treadlink\t-\t{str(candidate).encode().hex()}")
        home_ancestor = Path(roots["HOME"]).parent
        mkdir_mode = self.profile["accessGrammar"]["paths"][
            "pathResultPolicy"]["existingHomeAncestorMkdir"]["parameter"]
        while home_ancestor != home_ancestor.parent:
            expected_path_rules.add(
                f"P\tmkdir\t{mkdir_mode}\t{str(home_ancestor).encode().hex()}")
            home_ancestor = home_ancestor.parent
        actual_path_rules = {
            line for line in produced.decode("ascii").splitlines()
            if line.startswith("P\t")
        }
        self.assertEqual(expected_path_rules, actual_path_rules)
        font_path = "/etc/fonts/fonts.conf".encode().hex()
        self.assertIn(f"P\taccess\t-\t{font_path}", actual_path_rules)
        self.assertIn(f"P\tnewfstatat\t-\t{font_path}", actual_path_rules)
        self.assertIn(f"P\topenat\t524288\t{font_path}", actual_path_rules)
        self.assertEqual(
            {f"P\topenat\t524288\t{font_path}"},
            {line for line in actual_path_rules
             if line.startswith("P\topenat\t") and line.endswith(font_path)},
        )

    def test_file_and_execve_identity_resolve_the_same_symlink_target(self) -> None:
        manifest = json.loads(G0_MANIFEST_PATH.read_text(encoding="utf-8"))
        profile = json.loads(PROFILE_PATH.read_text(encoding="utf-8"))
        with tempfile.TemporaryDirectory(prefix="godot-policy-symlink-") as temporary:
            root = Path(temporary)
            target, alias = root / "dash", root / "sh"
            target.write_bytes(b"measured shell\n")
            target.chmod(0o755)
            alias.symlink_to(target.name)
            godot_target, godot_alias = root / "godot-bin", root / "godot"
            godot_target.write_bytes(b"measured Godot\n")
            godot_target.chmod(0o755)
            godot_alias.symlink_to(godot_target.name)

            shell = next(
                record for record in manifest["runtimeIdentitySet"]
                if record["path"] == "/bin/sh")
            shell["path"] = str(alias)
            shell["size"] = target.stat().st_size
            shell["sha256"] = sha256(target)
            closure = manifest["pathOperationClosure"]
            shell_exec = next(
                record for record in closure["records"]
                if record["operation"] == "execve" and record["path"] == "/bin/sh")
            shell_exec["path"] = str(alias)
            closure["records"].sort(key=lambda record: (
                record["operation"], record["path"],
                -1 if record["parameter"] is None else record["parameter"]))
            closure["recordsCanonicalSha256"] = self.runner.sha256_bytes(
                self.runner.canonical_bytes(closure["records"]))
            profile["g0"]["pathOperationClosure"][
                "recordsCanonicalSha256"] = closure["recordsCanonicalSha256"]
            profile["kernelAdmission"]["executeLeaves"] = [
                str(alias) if value == "/bin/sh" else value
                for value in profile["kernelAdmission"]["executeLeaves"]
            ]
            roots = {
                "GODOT": str(godot_alias),
                "PRODUCT": str(root / "product"),
                "PACKET": str(root / "packet"),
                "HOME": str(root / "home"),
                "OUTPUT": str(root / "output"),
            }
            produced, counts = self.runner.build_admission_policy(
                profile, manifest, roots, root / "observer")
            verified, verified_counts = self.verifier._build_admission_policy(
                profile, manifest, roots, root / "observer")

            lines = set(produced.decode("ascii").splitlines())
            resolved_hex = str(target.resolve()).encode().hex()
            alias_hex = str(alias).encode().hex()
            self.assertIn(f"F\tRX\t{resolved_hex}", lines)
            self.assertNotIn(f"F\tRX\t{alias_hex}", lines)
            self.assertIn(f"P\texecve\t-\t{resolved_hex}", lines)
            self.assertNotIn(f"P\texecve\t-\t{alias_hex}", lines)
            godot_target_hex = str(godot_target.resolve()).encode().hex()
            godot_alias_hex = str(godot_alias).encode().hex()
            self.assertIn(f"P\texecve\t-\t{godot_target_hex}", lines)
            self.assertNotIn(f"P\texecve\t-\t{godot_alias_hex}", lines)
            self.assertIn(f"P\treadlink\t-\t{godot_alias_hex}", lines)
            self.assertNotIn(f"P\treadlink\t-\t{godot_target_hex}", lines)
            self.assertEqual(produced, verified)
            self.assertEqual(counts, verified_counts)
            statement = {
                "caseId": "G00",
                "admissionPolicy": {
                    "schema": profile["kernelAdmission"]["policySchema"],
                    "file": "admission-policy.tsv",
                    "size": len(produced),
                    "sha256": hashlib.sha256(produced).hexdigest(),
                    **counts,
                },
            }
            self.verifier._admission_policy(
                statement, manifest, roots, profile,
                {"admission-policy.tsv": produced},
                {"events": [
                    {"type": "POLICY", "byteCount": len(produced), **counts},
                    {"type": "PATH_X", "operation": "execve", "returned": 0,
                     "path": str(target.resolve()), "_arguments": [0] * 6},
                ]},
            )

    def test_frozen_closure_rejects_deleted_and_speculative_path_atoms(self) -> None:
        source_manifest = json.loads(G0_MANIFEST_PATH.read_text(encoding="utf-8"))

        def identity(manifest: dict, path: str) -> dict:
            matches = [
                record
                for section in ("semanticReadSet", "runtimeIdentitySet",
                                "platformObservationSet")
                for record in manifest[section]
                if record["path"] == path
            ]
            self.assertEqual(1, len(matches))
            return matches[0]

        def refresh(manifest: dict) -> None:
            closure = manifest["pathOperationClosure"]
            closure["records"].sort(key=lambda record: (
                record["operation"], record["path"],
                -1 if record["parameter"] is None else record["parameter"]))
            closure["recordsCanonicalSha256"] = self.runner.sha256_bytes(
                self.runner.canonical_bytes(closure["records"]))
            closure["eventCount"] = sum(
                record["count"] for record in closure["records"])
            closure["recordCount"] = len(closure["records"])
            closure["uniqueOperationPathPairs"] = len({
                (record["operation"], record["path"])
                for record in closure["records"]})

        deleted = json.loads(json.dumps(source_manifest))
        deleted["pathOperationClosure"]["records"] = [
            record for record in deleted["pathOperationClosure"]["records"]
            if not (record["operation"] == "access"
                    and record["path"] == "/etc/fonts/fonts.conf")
        ]
        deleted_identity = identity(deleted, "/etc/fonts/fonts.conf")
        deleted_identity["operations"].remove("access")
        refresh(deleted)

        speculative = json.loads(json.dumps(source_manifest))
        speculative["pathOperationClosure"]["records"].append({
            "operation": "statx", "path": "/etc/fonts/fonts.conf",
            "parameter": None, "returns": [-2], "count": 1,
        })
        speculative_identity = identity(speculative, "/etc/fonts/fonts.conf")
        speculative_identity["operations"] = sorted(
            {*speculative_identity["operations"], "statx"})
        refresh(speculative)

        for label, manifest in (("deleted", deleted), ("speculative", speculative)):
            with self.subTest(label=label, implementation="runner"):
                with self.assertRaisesRegex(
                        self.runner.RunnerError, "profile binding mismatch"):
                    self.runner.validate_path_operation_closure(
                        self.profile, manifest)
            with self.subTest(label=label, implementation="verifier"):
                with self.assertRaisesRegex(
                        self.verifier.VerificationFailure, "PROFILE_MISMATCH"):
                    self.verifier._validate_g0_path_operation_closure(
                        self.profile, manifest)

    def test_identity_path_operations_must_equal_the_frozen_closure(self) -> None:
        manifest = json.loads(G0_MANIFEST_PATH.read_text(encoding="utf-8"))
        font = next(
            record for record in manifest["runtimeIdentitySet"]
            if record["path"] == "/etc/fonts/fonts.conf")
        font["operations"].remove("access")
        with self.assertRaisesRegex(
                self.runner.RunnerError, "identity path operations differ"):
            self.runner.validate_path_operation_closure(self.profile, manifest)
        with self.assertRaisesRegex(
                self.verifier.VerificationFailure, "identity operations differ"):
            self.verifier._validate_g0_path_operation_closure(
                self.profile, manifest)

    def test_kernel_interpreter_is_rx_without_becoming_a_fifth_execve(self) -> None:
        manifest = json.loads(G0_MANIFEST_PATH.read_text(encoding="utf-8"))
        root = "/tmp/glassvow-kernel-interpreter-contract"
        roots = {
            "GODOT": f"{root}/godot", "PRODUCT": f"{root}/product",
            "PACKET": f"{root}/packet", "HOME": f"{root}/home",
            "OUTPUT": f"{root}/output",
        }
        policy, counts = self.runner.build_admission_policy(
            self.profile, manifest, roots, Path(root) / "observer")
        verified, verified_counts = self.verifier._build_admission_policy(
            self.profile, manifest, roots, Path(root) / "observer")
        loader = str(Path(
            self.profile["kernelAdmission"]["kernelInterpreterLeaves"][0]
        ).resolve(strict=False)).encode().hex()
        lines = set(policy.decode("ascii").splitlines())
        self.assertIn(f"F\tRX\t{loader}", lines)
        self.assertNotIn(f"P\texecve\t-\t{loader}", lines)
        self.assertEqual(policy, verified)
        self.assertEqual(counts, verified_counts)

    def test_tracer_skips_zero_extended_anonymous_mmap_descriptor(self) -> None:
        source = TRACER_PATH.read_text(encoding="utf-8")
        self.assertIn("static int decode_syscall_fd(uint64_t raw)", source)
        self.assertIn("decode_syscall_fd(UINT32_MAX) == -1", source)
        self.assertIn("decode_syscall_fd(3) == 3", source)
        self.assertIn("decode_syscall_fd(task->args[4]) >= 0", source)
        self.assertNotIn("(int64_t)task->args[4] >= 0", source)

    def test_product_stage_contains_exact_commit_plus_only_frozen_configuration_roles(self) -> None:
        with tempfile.TemporaryDirectory(prefix="godot-product-stage-") as temporary:
            root = Path(temporary)
            source, stage = root / "source", root / "stage"
            source.mkdir()
            subprocess.run(["git", "init", "-q"], cwd=source, check=True)
            (source / "project.godot").write_text("[application]\n", encoding="utf-8")
            (source / "tracked.txt").write_text("tracked\n", encoding="utf-8")
            (source / "AGENTS.md").write_text("contract\n", encoding="utf-8")
            (source / "CLAUDE.md").symlink_to("AGENTS.md")
            subprocess.run(["git", "add", "."], cwd=source, check=True)
            subprocess.run([
                "git", "-c", "user.name=Test", "-c", "user.email=test@example.invalid",
                "commit", "-qm", "fixture",
            ], cwd=source, check=True)
            product_sha = subprocess.run(
                ["git", "rev-parse", "HEAD"], cwd=source, check=True,
                capture_output=True, text=True).stdout.strip()
            (source / "untracked-secret").write_text("must not enter\n", encoding="utf-8")

            fixtures = root / "fixtures"
            fixtures.mkdir()
            roles = {}
            for name, data in {
                    "extension_list.cfg": b"extension\n",
                    "global_script_class_cache.cfg": b"classes\n",
                    "uid_cache.bin": b"\x00uid\xff",
            }.items():
                path = fixtures / name
                path.write_bytes(data)
                roles[name] = {"size": len(data), "sha256": sha256(path)}
            manifest = root / "configuration.json"
            historical_product_sha = "1" * 40
            manifest_value = {
                "schema": "glassvow.godot-runtime-configuration-capture/v1",
                "source": {"productSha": historical_product_sha},
                "capture": {"kind": "test-fixture"},
                "roles": roles,
                "stagingRule": "exact commit plus only the three captured roles",
            }
            manifest.write_text(json.dumps(manifest_value), encoding="utf-8")

            stage_profile = json.loads(json.dumps(self.profile))
            stage_profile["g0"]["configurationCapture"] = {
                "path": str(manifest.relative_to(root)),
                "sha256": sha256(manifest),
                "fixtureRoot": str(fixtures.relative_to(root)),
                "roleCount": 3,
            }
            record = self.runner.materialise_product_stage(
                source, product_sha, stage, fixtures, manifest,
                stage_profile)
            self.assertNotEqual(historical_product_sha, product_sha)
            self.assertEqual(product_sha, record["productSha"])
            manifest_bytes = manifest.read_bytes()
            manifest.write_bytes(manifest_bytes + b"\n")
            try:
                with self.assertRaisesRegex(
                        self.runner.RunnerError, "profile binding differs"):
                    self.runner.materialise_product_stage(
                        source, product_sha, root / "unbound-stage", fixtures,
                        manifest, stage_profile)
            finally:
                manifest.write_bytes(manifest_bytes)
            self.assertEqual(
                sum(path.stat().st_size for path in (
                    source / "project.godot", source / "tracked.txt",
                    source / "AGENTS.md", source / "CLAUDE.md")),
                record["trackedBytes"])
            self.assertEqual("tracked\n", (stage / "tracked.txt").read_text())
            self.assertTrue((stage / "CLAUDE.md").is_symlink())
            self.assertFalse((stage / "untracked-secret").exists())
            self.assertEqual(set(roles), {
                path.name for path in (stage / ".godot").iterdir()})
            for name, binding in roles.items():
                path = stage / ".godot" / name
                self.assertTrue(path.is_file() and not path.is_symlink())
                self.assertEqual(binding["sha256"], sha256(path))

            with mock.patch.multiple(
                    self.verifier, OBSERVER_ROOT=root,
                    CONFIGURATION_ROOT=fixtures,
                    CONFIGURATION_MANIFEST_PATH=manifest):
                verified = self.verifier.verify_product_stage(
                    source, product_sha, stage, stage_profile)
                self.assertEqual(record["trackedBytes"], verified["trackedBytes"])
                tracked = stage / "tracked.txt"
                tracked.write_text("tampered\n", encoding="utf-8")
                with self.assertRaisesRegex(
                        self.verifier.VerificationFailure, "trusted command failed"):
                    self.verifier.verify_product_stage(
                        source, product_sha, stage, stage_profile)
                tracked.write_text("tracked\n", encoding="utf-8")
                generated = stage / ".godot" / "uid_cache.bin"
                generated.chmod(0o644); generated.write_bytes(b"tampered")
                with self.assertRaisesRegex(
                        self.verifier.VerificationFailure, "staged configuration differs"):
                    self.verifier.verify_product_stage(
                        source, product_sha, stage, stage_profile)
                generated.write_bytes((fixtures / "uid_cache.bin").read_bytes())
                injected = stage / "injected-regular"
                injected.write_text("not in the product tree\n", encoding="utf-8")
                with self.assertRaisesRegex(
                        self.verifier.VerificationFailure,
                        "product stage additive inventory differs"):
                    self.verifier.verify_product_stage(
                        source, product_sha, stage, stage_profile)
                injected.unlink()
                extra_configuration = stage / ".godot" / "extra-role.cfg"
                extra_configuration.parent.chmod(0o755)
                extra_configuration.write_text("not frozen\n", encoding="utf-8")
                with self.assertRaisesRegex(
                        self.verifier.VerificationFailure,
                        "product stage additive inventory differs"):
                    self.verifier.verify_product_stage(
                        source, product_sha, stage, stage_profile)
                extra_configuration.unlink()
                extra_configuration.parent.chmod(0o555)

            (source / ".godot").mkdir()
            (source / ".godot/tracked.cfg").write_text("forbidden\n", encoding="utf-8")
            subprocess.run(["git", "add", ".godot/tracked.cfg"], cwd=source, check=True)
            subprocess.run([
                "git", "-c", "user.name=Test", "-c", "user.email=test@example.invalid",
                "commit", "-qm", "tracked generated configuration",
            ], cwd=source, check=True)
            generated_sha = subprocess.run(
                ["git", "rev-parse", "HEAD"], cwd=source, check=True,
                capture_output=True, text=True).stdout.strip()
            with self.assertRaisesRegex(
                    self.runner.RunnerError, "already contains generated configuration"):
                self.runner.materialise_product_stage(
                    source, generated_sha, root / "forbidden-stage", fixtures,
                    manifest, stage_profile)

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

    def test_packet_preflight_caps_and_rejects_directories_before_json_read(self) -> None:
        with tempfile.TemporaryDirectory(prefix="godot-packet-preflight-") as temporary:
            packet = Path(temporary) / "packet"
            packet.mkdir()
            (packet / "manifest.json").write_text("{}", encoding="utf-8")
            (packet / "oracle.gd").write_text("extends SceneTree\n", encoding="utf-8")
            (packet / "nested").mkdir()
            with self.assertRaisesRegex(
                    self.runner.RunnerError, "regular non-symlink"):
                self.runner.read_packet_manifest(packet, self.profile)
            (packet / "nested").rmdir()
            (packet / "corpus.json").write_text("{}\n", encoding="utf-8")
            capped = json.loads(json.dumps(self.profile))
            capped["caps"]["maxPacketManifestBytes"] = 1
            with self.assertRaisesRegex(self.runner.RunnerError, "manifest cap"):
                self.runner.read_packet_manifest(packet, capped)

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
                "authorityComment": 5530338723,
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
                    authority_comment=5530338723)

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
                "authorityComment": 5530338723,
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
                    authority_comment=5530338723)

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
        verifier_spec = importlib.util.spec_from_file_location(
            "godot_runtime_verify_campaign", VERIFIER_PATH)
        assert verifier_spec and verifier_spec.loader
        cls.verifier = importlib.util.module_from_spec(verifier_spec)
        verifier_spec.loader.exec_module(cls.verifier)

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
                "authorityComment": 5530338723,
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
            with self.assertRaisesRegex(self.campaign.CampaignError, "member cap exceeded"):
                self.campaign.campaign_evidence_bytes(
                    output, mounts, maximum_members=1)
            with self.assertRaisesRegex(self.campaign.CampaignError, "byte cap exceeded"):
                self.campaign.campaign_evidence_bytes(
                    output, mounts, len(b"evidence") - 1)
            (output / "cases/replay-link").symlink_to(output / "cases/receipt.json")
            with self.assertRaisesRegex(self.campaign.CampaignError, "non-regular"):
                self.campaign.campaign_evidence_bytes(output, mounts)

    def test_unmount_failure_attempts_every_target_and_fails_closed(self) -> None:
        failed = subprocess.CompletedProcess(["umount"], 32)
        with mock.patch.object(self.campaign.subprocess, "run", return_value=failed) as invoked:
            with self.assertRaisesRegex(self.campaign.CampaignError, "unmount failed"):
                self.campaign.unmount_all([Path("/outside/product"), Path("/outside/packet")])
        self.assertEqual(2, invoked.call_count)
        self.assertIn(
            'tempfile.mkdtemp(prefix="glassvow-godot-runtime-input-")',
            CAMPAIGN_PATH.read_text(encoding="utf-8"),
        )

    def test_mount_cleanup_removes_read_only_staged_configuration(self) -> None:
        with tempfile.TemporaryDirectory(prefix="godot-cleanup-") as temporary:
            mounts_root = Path(temporary) / "inputs"
            product_stage = mounts_root / "product-stage"
            generated = product_stage / ".godot"
            generated.mkdir(parents=True)
            role = generated / "global_script_class_cache.cfg"
            role.write_bytes(b"frozen")
            role.chmod(0o444)
            generated.chmod(0o555)
            self.campaign.remove_mounts_root(mounts_root, product_stage)
            self.assertFalse(mounts_root.exists())

    def test_cleanup_failure_preserves_primary_campaign_failure(self) -> None:
        primary = self.campaign.CampaignError("G00 verifier failed")
        cleanup = self.campaign.CampaignError("read-only input cleanup failed")
        with mock.patch.object(self.campaign, "unmount_all"), \
                mock.patch.object(
                    self.campaign, "remove_mounts_root", side_effect=cleanup):
            with self.assertRaisesRegex(
                    self.campaign.CampaignError,
                    "G00 verifier failed; cleanup also failed: "
                    "read-only input cleanup failed",
            ) as raised:
                self.campaign.cleanup_campaign_inputs(
                    [], Path("/unused"), Path("/unused"), primary)
        self.assertIs(primary, raised.exception.__cause__)

    def test_a1_nonpass_still_publishes_a_terminal_admission_receipt(self) -> None:
        with tempfile.TemporaryDirectory(prefix="godot-admission-") as temporary:
            output = Path(temporary)
            (output / "cases/G00").mkdir(parents=True)
            self.campaign.write_json(output / "cases/G00/receipt.json", {
                "verdict": "INCONCLUSIVE", "reason": "PROVENANCE_INCOMPLETE",
                "receiptSha256": "a" * 64,
            })
            self.campaign.write_json(output / "capability-prerequisite.json", {
                "schema": "test-prerequisite",
            })
            args = types.SimpleNamespace(
                request_index="0", observer_sha="b" * 40, product_sha="c" * 40,
                packet_sha="d" * 40, packet_root="research_packets/a1-v2",
                authority_issue=421, authority_comment=5524340839,
            )
            result = self.campaign.write_admission_receipt(output, args, {
                "capabilityRun": 123,
                "capabilityReceiptSha256": "e" * 64,
            })
            published = self.campaign.read_json(output / "admission-receipt.json")
            self.assertEqual("INCONCLUSIVE", result["verdict"])
            self.assertEqual(result, published)
            self.assertEqual("a" * 64, published["caseReceiptSha256"])
        self.assertIn(
            "allowed_returncodes=(0, 1) if args.admit_only else (0,)",
            CAMPAIGN_PATH.read_text(encoding="utf-8"),
        )

    def test_g14_mutates_socket_syscall_event_and_address_consistently(self) -> None:
        with tempfile.TemporaryDirectory(prefix="godot-g14-") as temporary:
            case = Path(temporary)
            (case / "trace.tsv").write_text("\n".join((
                "SYSCALL_E\t1\t100\t0\tsocket\t16\t526339\t15\t0\t0\t0",
                "SOCKET\t2\t100\t5\t16\t526339\t15",
                "BIND\t3\t100\t5\t16\t0\t2\t12\t0",
            )) + "\n", encoding="utf-8")
            self.campaign.write_json(case / "statement.json", {
                "caseId": "G14", "trace": {},
            })
            self.campaign.apply_attack(case, "G14", {}, {})
            lines = [line.split("\t") for line in
                     (case / "trace.tsv").read_text(encoding="utf-8").splitlines()]
            self.assertEqual(("2", "2", "2"),
                             (lines[0][5], lines[1][4], lines[2][4]))
            self.assertEqual(("526339", "15", "2", "12"),
                             (lines[1][5], lines[1][6], lines[2][6], lines[2][7]))

    def test_g18_replays_both_prior_stderr_bytes_and_declaration(self) -> None:
        with tempfile.TemporaryDirectory(prefix="godot-g18-") as temporary:
            root = Path(temporary); case = root / "G18"; prior = root / "G15"
            case.mkdir(); prior.mkdir()
            prior_stderr = b"current diagnostic\n"
            (prior / "stderr.bin").write_bytes(prior_stderr)
            prior_record = {"path": "/prior/stderr.bin", "size": len(prior_stderr),
                            "sha256": hashlib.sha256(prior_stderr).hexdigest()}
            self.campaign.write_json(prior / "statement.json", {
                "streams": {"stderr": prior_record},
            })
            (case / "stderr.bin").write_bytes(b"different\n")
            self.campaign.write_json(case / "statement.json", {
                "caseId": "G18", "streams": {"stderr": {"sha256": "0" * 64}},
            })
            self.campaign.apply_attack(case, "G18", {"G15": prior}, {})
            mutated = self.campaign.read_json(case / "statement.json")
            self.assertEqual(prior_stderr, (case / "stderr.bin").read_bytes())
            self.assertEqual(prior_record, mutated["streams"]["stderr"])

    def test_g21_changes_one_thread_edge_to_a_process_edge(self) -> None:
        with tempfile.TemporaryDirectory(prefix="godot-g21-") as temporary:
            case = Path(temporary); flags = 4001536
            (case / "trace.tsv").write_text(
                f"LINEAGE\t1\t100\t101\tclone_thread\t{flags}\n",
                encoding="utf-8")
            self.campaign.write_json(case / "statement.json", {
                "caseId": "G21", "trace": {},
            })
            self.campaign.apply_attack(case, "G21", {}, {})
            fields = (case / "trace.tsv").read_text(encoding="utf-8").split("\t")
            self.assertEqual("clone_process", fields[4])
            self.assertEqual(flags & ~0x10000, int(fields[5]))

    def test_g25_reaches_semantic_mapping_reason_after_fd_accounting(self) -> None:
        profile = json.loads(PROFILE_PATH.read_text(encoding="utf-8"))
        caps = profile["caps"]
        limits = [str(caps[key]) for key in caps["tracerStartLimitOrder"]]
        with tempfile.TemporaryDirectory(prefix="godot-g25-") as temporary:
            case = Path(temporary)
            original = (case / "runtime-object").resolve()
            corpus = (case / "corpus.json").resolve()
            original.write_bytes(b"runtime")
            corpus.write_bytes(b"semantic")
            metadata = original.stat()
            null_identity = Path("/dev/null").stat()
            original_hex = str(original).encode().hex()
            lines = [
                "GODOTTRACEv1",
                "\t".join(["START", "1", "100", TRACE_CHALLENGE, *limits]),
                "POLICY\t2\t100\t1\t1\t1",
                f"INITIAL_FD\t3\t100\t0\t0\t{null_identity.st_dev}\t"
                f"{null_identity.st_ino}\t2f6465762f6e756c6c",
                "INITIAL_FD\t4\t100\t1\t1\t1\t11\t706970653a5b31315d",
                "INITIAL_FD\t5\t100\t2\t1\t1\t12\t706970653a5b31325d",
                "SYSCALL_E\t6\t100\t257\topenat\t18446744073709551516\t0\t524288\t0\t0\t0",
                f"PATH\t7\t100\topenat\t{original_hex}\t{original_hex}",
                "SYSCALL_X\t8\t100\t257\topenat\t3\t0\t0",
                f"PATH_X\t9\t100\topenat\t3\t{original_hex}",
                f"OPEN\t10\t100\t3\t524288\tI\t{metadata.st_dev}\t{metadata.st_ino}\t{original_hex}",
                "SYSCALL_E\t11\t100\t9\tmmap\t0\t4096\t1\t2\t3\t0",
                "SYSCALL_X\t12\t100\t9\tmmap\t4096\t0\t0",
                f"MMAP\t13\t100\t4096\t4096\t1\t2\t3\t0\tI\t{metadata.st_dev}\t{metadata.st_ino}\t{original_hex}",
                "SYSCALL_E\t14\t100\t3\tclose\t3\t0\t0\t0\t0\t0",
                "SYSCALL_X\t15\t100\t3\tclose\t0\t0\t0",
                f"CLOSE\t16\t100\t3\tI\t{metadata.st_dev}\t{metadata.st_ino}\t{original_hex}",
                "SYSCALL_E\t17\t100\t231\texit_group\t0\t0\t0\t0\t0\t0",
                "EXIT\t18\t100\t0",
                "\t".join([
                    "END", "19", "100", "200", "100",
                    "0", "1", "0", "4", "3", "0", "0", "1", "0", "0",
                    "1", "1", "1", "0", "0", "0", "0", "0", "0", "-",
                    TRACE_CHALLENGE,
                ]),
            ]
            (case / "trace.tsv").write_text("\n".join(lines) + "\n", encoding="utf-8")
            self.campaign.write_json(case / "statement.json", {
                "caseId": "G25", "trace": {},
                "roles": [{"role": "corpus", "path": str(corpus)}],
            })
            self.campaign.apply_attack(case, "G25", {}, {})
            trace_bytes = (case / "trace.tsv").read_bytes()
            trace = self.verifier.parse_trace_lines(
                trace_bytes.decode().splitlines(), caps["maxEvents"])
            self.verifier.validate_trace_accounting(
                trace, caps, len(trace_bytes), 0, str(ROOT))
            open_entry = next(
                event for event in trace["events"]
                if event["type"] == "SYSCALL_E" and event["name"] == "openat")
            opened = next(
                event for event in trace["events"] if event["type"] == "OPEN")
            self.assertEqual(0, open_entry["arguments"][2])
            self.assertEqual(0, opened["flags"])
            with self.assertRaisesRegex(
                    self.verifier.VerificationFailure, "SEMANTIC_MAPPING_DENIED"):
                self.verifier.reject_semantic_mappings(
                    trace["events"], {str(corpus)})

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
