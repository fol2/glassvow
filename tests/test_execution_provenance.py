#!/usr/bin/env python3
"""Focused tests for the Linux execution-provenance capability."""
from __future__ import annotations

import copy
import importlib.util
import hashlib
import json
import os
import shutil
import tempfile
import unittest
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
PREFLIGHT_PATH = ROOT / "tools/execution_provenance/preflight.py"
SPEC = importlib.util.spec_from_file_location(
    "execution_provenance_preflight", PREFLIGHT_PATH)
assert SPEC and SPEC.loader
PREFLIGHT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PREFLIGHT)

VERIFIER_PATH = ROOT / "tools/execution_provenance/verify.py"
VERIFIER_SPEC = importlib.util.spec_from_file_location(
    "execution_provenance_verifier", VERIFIER_PATH)
assert VERIFIER_SPEC and VERIFIER_SPEC.loader
VERIFIER = importlib.util.module_from_spec(VERIFIER_SPEC)
VERIFIER_SPEC.loader.exec_module(VERIFIER)

RUNNER_PATH = ROOT / "tools/execution_provenance/runner.py"
RUNNER_SPEC = importlib.util.spec_from_file_location(
    "execution_provenance_runner", RUNNER_PATH)
assert RUNNER_SPEC and RUNNER_SPEC.loader
RUNNER = importlib.util.module_from_spec(RUNNER_SPEC)
RUNNER_SPEC.loader.exec_module(RUNNER)

CAMPAIGN_PATH = ROOT / "tools/execution_provenance/campaign.py"
CAMPAIGN_SPEC = importlib.util.spec_from_file_location(
    "execution_provenance_campaign", CAMPAIGN_PATH)
assert CAMPAIGN_SPEC and CAMPAIGN_SPEC.loader
CAMPAIGN = importlib.util.module_from_spec(CAMPAIGN_SPEC)
CAMPAIGN_SPEC.loader.exec_module(CAMPAIGN)

PROTOCOL_PATH = ROOT / "tools/execution_provenance/protocol.json"


def trace_lines(*events: str, count: int | None = None) -> list[str]:
    event_count = len(events) if count is None else count
    return [
        "TRACEv1",
        "START\t100",
        "INPUT\t11\t22\t32\t2f63617073756c652f6f70617175652e62696e",
        *events,
        f"END\t{event_count}\t100\t250\t150\t0\t0\t-",
    ]


def build_test_capsule(root: Path) -> Path:
    workspace = root / "workspace"
    workspace.mkdir()
    fake_executable = root / "fake-executable"
    fake_executable.write_bytes(b"bounded executable")
    digest = hashlib.sha256(fake_executable.read_bytes()).hexdigest()
    fake_build = {
        "compiler": "/usr/bin/cc", "compilerVersion": "test",
        "commands": [], "tracer": str(fake_executable),
        "tracerSha256": digest, "workload": str(fake_executable),
        "workloadSha256": digest,
    }
    with mock.patch.object(RUNNER, "compile_components", return_value=fake_build):
        record = RUNNER.build_capsule(PROTOCOL_PATH, workspace)
    return Path(record["capsule"])


class ExecutionProvenanceCampaignTests(unittest.TestCase):
    def test_n05_replay_uses_a_fresh_packet_and_preserves_sealed_evidence(
            self) -> None:
        with tempfile.TemporaryDirectory(
                prefix="glassvow-campaign-replay-test-") as temporary:
            output = Path(temporary) / "campaign"

            def fake_run(command: object, *, timeout: int = 30) -> None:
                del timeout
                arguments = list(command)
                program = Path(arguments[1]).name if len(arguments) > 1 else ""
                operation = arguments[2] if len(arguments) > 2 else ""
                if program == "runner.py" and operation == "build":
                    workspace = Path(arguments[arguments.index("--workspace") + 1])
                    capsule = workspace / "capsule-under-test"
                    capsule.mkdir()
                    (capsule / "opaque-role.bin").write_bytes(b"input")
                    (capsule / "expected-executable").write_bytes(b"executable")
                    CAMPAIGN.write_json(
                        workspace / "build.json", {"capsule": str(capsule)})
                elif program == "verify.py" and operation == "challenge":
                    destination = Path(arguments[arguments.index("--output") + 1])
                    case_id = arguments[arguments.index("--case") + 1]
                    CAMPAIGN.write_json(
                        destination, {"case": case_id, "challenge": case_id})
                elif program == "runner.py" and operation == "run":
                    packet = Path(arguments[arguments.index("--packet") + 1])
                    packet.mkdir()
                    (packet / "runtime-capsule").mkdir()
                    for name in (
                            "trace.tsv", "subject.bin", "stdout.bin", "stderr.bin",
                            "statement.json", "mount.json",
                            "executed-executable.bin"):
                        (packet / name).write_bytes(packet.name.encode("ascii"))
                    os.chmod(packet / "executed-executable.bin", 0o444)
                elif program == "verify.py" and operation == "mount":
                    destination = Path(arguments[arguments.index("--output") + 1])
                    destination.write_bytes(b"attestation")
                elif program == "verify.py" and operation == "case":
                    destination = Path(arguments[arguments.index("--output") + 1])
                    CAMPAIGN.write_json(destination, {"matchesExpectation": True})
                elif program == "verify.py" and operation == "campaign":
                    destination = Path(arguments[arguments.index("--output") + 1])
                    CAMPAIGN.write_json(
                        destination, {"verdict": "PASS", "gitHead": "test-head"})

            with mock.patch.object(CAMPAIGN, "CASE_IDS", ["V00", "N05"]), \
                    mock.patch.object(CAMPAIGN, "run", side_effect=fake_run):
                result = CAMPAIGN.run_campaign(PROTOCOL_PATH, output)

            preserved = output / "cases/N05-current"
            self.assertEqual("PASS", result["verdict"])
            self.assertEqual(
                b"N05", (preserved / "executed-executable.bin").read_bytes())
            self.assertEqual(
                0o444,
                os.stat(preserved / "executed-executable.bin").st_mode & 0o777)
            self.assertEqual(
                b"V00",
                (output / "cases/N05/executed-executable.bin").read_bytes())


class ExecutionProvenancePreflightTests(unittest.TestCase):
    def test_valid_trace_binds_lineage_and_actual_read_bytes(self) -> None:
        lines = trace_lines(
            "EXEC\t1\t1001\t33\t44\t2f776f726b6c6f6164",
            "FORK\t2\t1001\t1002\tfork",
            "READ\t3\t1002\tread\t3\t0\t16\t16\t11\t22\t"
            "2f63617073756c652f6f70617175652e62696e\t"
            "000102030405060708090a0b0c0d0e0f",
            "EXIT\t4\t1002\t0",
            "READ\t5\t1001\tpread64\t3\t16\t16\t16\t11\t22\t"
            "2f63617073756c652f6f70617175652e62696e\t"
            "101112131415161718191a1b1c1d1e1f",
            "EXIT\t6\t1001\t0",
        )
        trace = PREFLIGHT.parse_trace_lines(lines)
        result = PREFLIGHT.validate_valid_trace(
            trace,
            expected_bytes=bytes(range(32)),
            expected_device=11,
            expected_inode=22,
        )
        self.assertEqual([1001, 1002], result["lineage"])
        self.assertEqual(32, result["consumed_bytes"])
        self.assertEqual(0, result["dropped_events"])

    def test_sequence_gap_fails_closed(self) -> None:
        lines = trace_lines(
            "EXEC\t1\t1001\t33\t44\t2f776f726b6c6f6164",
            "EXIT\t3\t1001\t0",
        )
        with self.assertRaisesRegex(PREFLIGHT.PreflightError, "sequence"):
            PREFLIGHT.parse_trace_lines(lines)

    def test_actual_bytes_must_match_the_bound_input(self) -> None:
        lines = trace_lines(
            "EXEC\t1\t1001\t33\t44\t2f776f726b6c6f6164",
            "FORK\t2\t1001\t1002\tfork",
            "READ\t3\t1002\tread\t3\t0\t16\t16\t11\t22\t"
            "2f63617073756c652f6f70617175652e62696e\t"
            "ff0102030405060708090a0b0c0d0e0f",
            "EXIT\t4\t1002\t0",
            "READ\t5\t1001\tpread64\t3\t16\t16\t16\t11\t22\t"
            "2f63617073756c652f6f70617175652e62696e\t"
            "101112131415161718191a1b1c1d1e1f",
            "EXIT\t6\t1001\t0",
        )
        trace = PREFLIGHT.parse_trace_lines(lines)
        with self.assertRaisesRegex(PREFLIGHT.PreflightError, "actual read bytes"):
            PREFLIGHT.validate_valid_trace(
                trace,
                expected_bytes=bytes(range(32)),
                expected_device=11,
                expected_inode=22,
            )

    def test_negative_probe_requires_its_exact_policy_reason(self) -> None:
        lines = trace_lines(
            "EXEC\t1\t1001\t33\t44\t2f776f726b6c6f6164",
            "VIOLATION\t2\t1001\tUNSUPPORTED_MMAP_INPUT",
            "EXIT\t3\t1001\t137",
        )
        trace = PREFLIGHT.parse_trace_lines(lines[:-1] + [
            "END\t3\t100\t250\t150\t0\t137\tUNSUPPORTED_MMAP_INPUT"])
        PREFLIGHT.validate_rejection_trace(trace, "UNSUPPORTED_MMAP_INPUT")
        with self.assertRaisesRegex(PREFLIGHT.PreflightError, "reason"):
            PREFLIGHT.validate_rejection_trace(trace, "UNTRACEABLE_CLONE_FLAG")

    def test_workflow_is_pinned_and_component_scoped(self) -> None:
        workflow = (ROOT / ".github/workflows/execution-provenance-evidence.yml")
        text = workflow.read_text(encoding="utf-8")
        self.assertIn("runs-on: ubuntu-24.04", text)
        self.assertIn("workflow_dispatch:", text)
        self.assertIn("tools/execution_provenance/**", text)
        self.assertIn("ImageVersion", text)
        self.assertNotIn("ubuntu-latest", text)
        self.assertIn(
            "actions/checkout@11d5960a326750d5838078e36cf38b85af677262", text)
        self.assertIn(
            "actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02",
            text)
        self.assertIn("tree=$tree_sha protocol_sha256=$protocol_sha", text)
        self.assertIn("issues/$authority_issue/comments", text)
        self.assertIn('author_association == "OWNER"', text)
        self.assertIn('grep -Fxq "$head_marker"', text)
        self.assertIn('grep -Fxq "$tree_marker"', text)
        self.assertNotIn(
            'if [[ "$EVENT_NAME" == "workflow_dispatch" ]]; then\n'
            '            echo "approved=true"', text)

    def test_self_test_does_not_require_linux_or_sudo(self) -> None:
        with tempfile.TemporaryDirectory(prefix="glassvow-provenance-self-test-"):
            self.assertEqual(0, PREFLIGHT.main(["--self-test"]))


class ExecutionProvenancePolicyTests(unittest.TestCase):
    def setUp(self) -> None:
        self.protocol = json.loads(PROTOCOL_PATH.read_text(encoding="utf-8"))
        self.cases = {case["id"]: case for case in self.protocol["cases"]}
        self.observation = {
            "provenance_complete": True,
            "trace_violation": None,
            "challenge_matches": True,
            "runtime_capsule_matches": True,
            "input_path_matches": True,
            "input_bytes_match": True,
            "executable_matches": True,
            "request_matches": True,
            "timing_present_and_matches": True,
            "current_consumption_complete": True,
            "subject_is_current_output": True,
            "output_matches": True,
            "external_duration_ns": 1,
            "child_claim_ns": None,
        }

    def verdict(self, case_id: str, **changes: object) -> dict[str, str]:
        observation = dict(self.observation)
        observation.update(changes)
        return VERIFIER.policy_verdict(
            self.protocol, self.cases[case_id], observation)

    def test_protocol_freezes_one_valid_and_ten_distinct_controls(self) -> None:
        VERIFIER.validate_protocol(self.protocol)
        self.assertEqual(11, len(self.cases))
        self.assertEqual(
            ["V00"] + [f"N{index:02d}" for index in range(1, 11)],
            [case["id"] for case in self.protocol["cases"]])
        self.assertEqual(
            len(self.cases),
            len({case["expectedReason"] for case in self.protocol["cases"]}))

    def test_protocol_rejects_every_complete_contract_drift_probe(self) -> None:
        mutations = {
            "authority issue": lambda value: value["authority"].__setitem__(
                "issue", 421),
            "missing bounded workload": lambda value: value.pop("boundedWorkload"),
            "threat exclusion": lambda value: value["trustMap"][
                "excludedClaims"].__setitem__(0, "changed exclusion"),
            "unknown top-level binding": lambda value: value.__setitem__(
                "unexpected", True),
        }
        for label, mutate in mutations.items():
            with self.subTest(probe=label):
                changed = copy.deepcopy(self.protocol)
                mutate(changed)
                with self.assertRaisesRegex(
                        VERIFIER.VerificationError, "complete frozen contract"):
                    VERIFIER.validate_protocol(changed)

    def test_common_policy_accepts_only_the_complete_valid_observation(self) -> None:
        self.assertEqual(
            {"verdict": "PASS", "reason": "ADMITTED"},
            self.verdict("V00"))
        cases = {
            "N01": {"runtime_capsule_matches": False},
            "N02": {"input_path_matches": False, "input_bytes_match": False},
            "N03": {"executable_matches": False},
            "N04": {"request_matches": False},
            "N05": {"challenge_matches": False},
            "N06": {
                "current_consumption_complete": False,
                "subject_is_current_output": False,
            },
            "N07": {"timing_present_and_matches": False},
            "N08": {
                "external_duration_ns": self.protocol["caps"]["judgementWallNs"] + 1,
                "child_claim_ns": 1,
            },
            "N09": {"trace_violation": "UNDECLARED_INPUT_PATH"},
            "N10": {"provenance_complete": False},
        }
        for case_id, mutation in cases.items():
            with self.subTest(case=case_id):
                self.assertEqual(
                    {
                        "verdict": self.cases[case_id]["expectedVerdict"],
                        "reason": self.cases[case_id]["expectedReason"],
                    },
                    self.verdict(case_id, **mutation))

    def test_independent_verifier_does_not_import_execution_code(self) -> None:
        source = VERIFIER_PATH.read_text(encoding="utf-8")
        for forbidden in (
                "import runner", "from runner", "import preflight",
                "from preflight", "ptrace_tracer", "inert_workload"):
            self.assertNotIn(forbidden, source)

    def test_capsule_builder_binds_all_frozen_roles_and_permissions(self) -> None:
        with tempfile.TemporaryDirectory(prefix="glassvow-capsule-test-") as temporary:
            root = Path(temporary)
            capsule = build_test_capsule(root)
            manifest = json.loads(
                (capsule / "manifest.json").read_text(encoding="utf-8"))
            payload = {"schema": manifest["schema"], "members": manifest["members"]}
            self.assertEqual(
                manifest["root"],
                hashlib.sha256(RUNNER.canonical_bytes(payload)).hexdigest())
            self.assertEqual(14, len(manifest["members"]))
            modes = {member["path"]: member["mode"] for member in manifest["members"]}
            self.assertEqual("0555", modes["expected-executable"])
            self.assertTrue(all(
                mode == "0444" for path, mode in modes.items()
                if path != "expected-executable"))
            self.assertEqual(0o555, os.stat(capsule).st_mode & 0o777)
            observed = VERIFIER._observed_capsule(capsule, self.protocol)
            self.assertEqual(manifest["root"], observed["actualRoot"])
            self.assertEqual("0444", observed["manifestMode"])
            self.assertEqual(
                (capsule / "manifest.json").stat().st_size,
                observed["manifestBytes"])

            mode_tamper = root / "manifest-mode-tamper"
            shutil.copytree(capsule, mode_tamper)
            os.chmod(mode_tamper / "manifest.json", 0o777)
            mode_observed = VERIFIER._observed_capsule(
                mode_tamper, self.protocol)
            self.assertEqual("0777", mode_observed["manifestMode"])
            self.assertNotEqual(observed, mode_observed)

            size_tamper = root / "manifest-size-tamper"
            shutil.copytree(capsule, size_tamper)
            os.chmod(size_tamper / "manifest.json", 0o644)
            with (size_tamper / "manifest.json").open("ab") as handle:
                handle.write(b"\n")
            os.chmod(size_tamper / "manifest.json", 0o444)
            size_observed = VERIFIER._observed_capsule(
                size_tamper, self.protocol)
            self.assertNotEqual(
                observed["manifestBytes"], size_observed["manifestBytes"])
            self.assertNotEqual(observed, size_observed)

            alternate_protocol = root / "alternate-protocol.json"
            alternate_protocol.write_bytes(PROTOCOL_PATH.read_bytes() + b"\n")
            with self.assertRaisesRegex(
                    VERIFIER.VerificationError, "embedded protocol bytes"):
                VERIFIER._capsule(
                    capsule, self.protocol, alternate_protocol)
            supplied = root / "supplied"
            shutil.copytree(capsule, supplied)
            os.chmod(supplied, 0o755)
            os.chmod(supplied / "opaque-role.bin", 0o644)
            with (supplied / "opaque-role.bin").open("ab") as handle:
                handle.write(b"trailing bytes must change the root")
            self.assertNotEqual(
                manifest["root"],
                VERIFIER._observed_capsule(supplied, self.protocol)["actualRoot"])
            (supplied / "opaque-role.bin").write_bytes(
                (capsule / "opaque-role.bin").read_bytes())
            os.chmod(supplied / "opaque-role.bin", 0o444)
            (supplied / "undeclared.bin").write_bytes(b"undeclared")
            os.chmod(supplied / "undeclared.bin", 0o444)
            self.assertNotEqual(
                manifest["root"],
                VERIFIER._observed_capsule(supplied, self.protocol)["actualRoot"])

    def test_saved_mount_attestation_replays_without_a_live_mount(self) -> None:
        with tempfile.TemporaryDirectory(prefix="glassvow-replay-test-") as temporary:
            root = Path(temporary).resolve()
            capsule = build_test_capsule(root)
            campaign = root / "campaign"
            packet = campaign / "cases" / "V00"
            packet.mkdir(parents=True)
            supplied = campaign / "supplied-capsules" / "V00" / capsule.name
            supplied.parent.mkdir(parents=True)
            shutil.copytree(capsule, supplied)
            (packet / "trace.tsv").write_bytes(b"portable raw trace")
            (packet / "executed-executable.bin").write_bytes(b"bounded executable")
            runtime_target = "/detached/original/runtime-capsule"
            mount = {
                "source": "/detached/original/supplied-capsule",
                "target": runtime_target,
                "options": "ro,relatime",
                "writeRejected": True,
            }
            VERIFIER.write_json(packet / "mount.json", mount)
            observed = VERIFIER._observed_capsule(supplied, self.protocol)
            input_stat = (supplied / "opaque-role.bin").stat()
            attestation = {
                "schema": VERIFIER.RUNTIME_CAPSULE_ATTESTATION_SCHEMA,
                "protocolSha256": VERIFIER.sha256_file(PROTOCOL_PATH),
                "frozenCapsuleRoot": observed["actualRoot"],
                "suppliedEvidence": supplied.relative_to(campaign).as_posix(),
                "runtimeTarget": runtime_target,
                "runtimeInput": {
                    "path": f"{runtime_target}/opaque-role.bin",
                    "device": input_stat.st_dev,
                    "inode": input_stat.st_ino,
                    "bytes": input_stat.st_size,
                    "sameSourceObject": True,
                },
                "mountBound": True,
                "matchesFrozenRoot": True,
                "suppliedObservation": observed,
                "runtimeObservation": observed,
                "osMount": {
                    "source": "/dev/root[/detached/original/supplied-capsule]",
                    "target": runtime_target,
                    "options": "ro,relatime",
                },
                "writeRejectedByVerifier": True,
                "evidence": {
                    "traceSha256": VERIFIER.sha256_file(packet / "trace.tsv"),
                    "mountSha256": VERIFIER.sha256_file(packet / "mount.json"),
                    "executedExecutableSha256": VERIFIER.sha256_file(
                        packet / "executed-executable.bin"),
                    "verifierSha256": VERIFIER.sha256_file(VERIFIER_PATH),
                },
            }
            attestation["attestationSha256"] = VERIFIER.sha256_bytes(
                VERIFIER.canonical_bytes(attestation))
            VERIFIER.write_json(
                packet / "runtime-capsule-attestation.json", attestation)
            self.assertFalse(Path(runtime_target).exists())
            with mock.patch.object(
                    VERIFIER.subprocess, "run",
                    side_effect=AssertionError("offline replay called findmnt")):
                replay = VERIFIER._runtime_attestation(
                    PROTOCOL_PATH, capsule, packet)
            self.assertTrue(replay["matchesFrozenRoot"])

    def test_native_surfaces_name_every_frozen_control(self) -> None:
        workload = (ROOT / "tools/execution_provenance/inert_workload.c").read_text(
            encoding="utf-8")
        supervisor = (ROOT / "tools/execution_provenance/ptrace_tracer.c").read_text(
            encoding="utf-8")
        for case in self.protocol["cases"]:
            actual = case.get("actualRequestToken", case["requestToken"])
            self.assertIn(f'"{actual}"', workload)
        for reason in (
                "UNDECLARED_INPUT_PATH", "PROVENANCE_INCOMPLETE",
                "UNSUPPORTED_MMAP_INPUT", "UNTRACEABLE_CLONE_FLAG"):
            self.assertIn(reason, supervisor)


if __name__ == "__main__":
    unittest.main()
