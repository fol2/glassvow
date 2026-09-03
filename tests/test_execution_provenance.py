#!/usr/bin/env python3
"""Focused tests for the Linux execution-provenance capability."""
from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PREFLIGHT_PATH = ROOT / "tools/execution_provenance/preflight.py"
SPEC = importlib.util.spec_from_file_location(
    "execution_provenance_preflight", PREFLIGHT_PATH)
assert SPEC and SPEC.loader
PREFLIGHT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PREFLIGHT)


def trace_lines(*events: str, count: int | None = None) -> list[str]:
    event_count = len(events) if count is None else count
    return [
        "TRACEv1",
        "START\t100",
        "INPUT\t11\t22\t32\t2f63617073756c652f6f70617175652e62696e",
        *events,
        f"END\t{event_count}\t100\t250\t150\t0\t0\t-",
    ]


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

    def test_self_test_does_not_require_linux_or_sudo(self) -> None:
        with tempfile.TemporaryDirectory(prefix="glassvow-provenance-self-test-"):
            self.assertEqual(0, PREFLIGHT.main(["--self-test"]))


if __name__ == "__main__":
    unittest.main()
