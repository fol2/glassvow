#!/usr/bin/env python3
"""Fail-closed unit laws for the release-performance evidence replay."""
from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "run_performance_budget", ROOT / "tools/run_performance_budget.py")
assert SPEC and SPEC.loader
PERF = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PERF)


def dump(path: Path, value: Any) -> None:
    path.write_text(json.dumps(value, sort_keys=True) + "\n", encoding="utf-8")


class PerformanceEvidenceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory(prefix="glassvow-perf-test-")
        self.root = Path(self.temp.name)
        (self.root / "raw").mkdir()
        (self.root / "environment").mkdir()
        self.name = "phone-landscape--en--r1"
        self.pid = 4242
        self.plan = {
            "schema": 1, "commit": "a" * 40,
            "fight": ["leviathan"],
            "kind": "boss", "seed": 717, "act": 1, "mode": "full",
            "shapes": ["phone-landscape"], "languages": ["en"],
            "repeats": 1, "budgets": None, "app_sha256": "b" * 64,
            "pck_sha256": "c" * 64,
            "environment": dict(PERF.TARGET_ENVIRONMENT),
        }
        values = [17.0] * 600
        zeros = [0.0] * 600
        cpu = [0.5] * 600
        setup = [0.1] * 600
        total = [0.6] * 600
        renderer = [400.0 * 1048576] * 600
        self.report = {
            "schema": 1,
            "provenance": {"claimed_commit": "a" * 40, "godot": "4.7.1-stable",
                           "os": "macOS", "architecture": "arm64",
                           "renderer": "Apple M4 (Apple9)", "release": True,
                           "rendering_method": "mobile"},
            "request": {"fight": self.plan["fight"], "kind": "boss",
                        "seed": 717, "act": 1, "shape": "phone-landscape",
                        "window": [844, 390], "language": "en",
                        "mode": "full"},
            "method": {"warmup_seconds": 6.0, "warmup_frames_min": 300,
                       "sample_seconds": 10.0, "sample_frames_min": 600,
                       "measured_viewports": 5,
                       "viewport_sizes": [[844, 390]] + [[100, 100]] * 4,
                       "actor_stage_sizes": [[100, 100], [100, 100]],
                       "viewport_pixels": 844 * 390 + 40000},
            "samples": {"observed_frame_ms": values, "render_cpu_ms": cpu,
                        "frame_setup_cpu_ms": setup,
                        "render_cpu_plus_setup_ms": total,
                        "render_gpu_ms": zeros,
                        "renderer_allocated_bytes": renderer},
            "summary": {"sample_count": 600,
                        "observed_frame_median_ms": 17.0,
                        "observed_frame_p95_ms": 17.0,
                        "render_cpu_plus_setup_p95_ms": 0.6,
                        "render_gpu_available": False, "render_gpu_p95_ms": 0.0,
                        "renderer_allocated_peak_mib": 400.0},
        }
        self.footprint = {
            "unit": "byte", "bytes per unit": 1,
            "samples": [{"errors": [],
                "start_time": {"mach_continuous_time_ns": index * 3_000_000_000 + 1},
                "processes": [{
                "pid": self.pid, "translated": False, "footprint": 700 * 1048576,
                "auxiliary": {"phys_footprint": 700 * 1048576,
                              "phys_footprint_peak": 710 * 1048576}}]}
                for index in range(8)],
        }
        self.footprint["samples"].append({
            "errors": [], "start_time": {"mach_continuous_time_ns": 24_000_000_001},
            "processes": []})
        self.status = {"process_returncode": 0, "footprint_returncode": 0,
                       "launcher_pid": self.pid}
        self._write_bundle()

    def tearDown(self) -> None:
        self.temp.cleanup()

    def _reset(self) -> None:
        self.tearDown()
        self.setUp()

    def _write_bundle(self) -> None:
        dump(self.root / "plan.json", self.plan)
        dump(self.root / "environment/app.json", {
            "executable_sha256": self.plan["app_sha256"],
            "pck_sha256": self.plan["pck_sha256"],
        })
        raw = self.root / "raw"
        dump(raw / f"{self.name}.report.json", self.report)
        dump(raw / f"{self.name}.footprint.json", self.footprint)
        dump(raw / f"{self.name}.status.json", self.status)
        ready = {"pid": self.pid, "shape": "phone-landscape",
                 "window": [844, 390], "actors": 2, "measured_viewports": 5,
                 "language": "en", "renderer": "Apple M4 (Apple9)"}
        (raw / f"{self.name}.stdout").write_text(
            "BENCH_READY " + json.dumps(ready) + "\nBENCH_RESULT "
            + json.dumps(self.report["summary"]) + "\n", encoding="utf-8")
        for suffix in ("stderr", "footprint.stdout", "footprint.stderr"):
            (raw / f"{self.name}.{suffix}").write_text("", encoding="utf-8")

    def assert_rejected(self, mutator: Any) -> None:
        mutator()
        self._write_bundle()
        with self.assertRaises(PERF.EvidenceError):
            PERF.replay(self.root)

    def test_valid_report_and_footprint_replay(self) -> None:
        metrics = PERF.validate_report(self.report, PERF.expected(
            self.plan, "phone-landscape", "en"))
        self.assertEqual(400.0, metrics["renderer_allocated_peak_mib"])
        self.assertEqual(710.0, PERF.validate_footprint(self.footprint, self.pid))

    def test_plan_matrix_and_types_fail_closed(self) -> None:
        self.assert_rejected(lambda: self.plan.update(shapes=["phone-landscape"] * 2))
        self._reset()
        self.assert_rejected(lambda: self.plan.update(repeats=False))
        self._reset()
        self.assert_rejected(lambda: self.plan.update(shapes=[{}]))

    def test_method_and_derived_cpu_fail_closed(self) -> None:
        self.assert_rejected(lambda: self.report["method"].update(sample_seconds=2.0))
        self._reset()
        self.assert_rejected(lambda: self.report["samples"]
                             ["render_cpu_plus_setup_ms"].__setitem__(0, 9.0))
        self._reset()
        self.assert_rejected(lambda: self.report["samples"]
                             .update(renderer_allocated_bytes=[0.0] * 600))

    def test_request_and_method_integer_types_are_strict(self) -> None:
        for section, key, value in (("request", "act", False),
                                    ("request", "seed", 717.0),
                                    ("method", "measured_viewports", 5.9),
                                    ("method", "viewport_pixels", 369160.5)):
            with self.subTest(section=section, key=key):
                self._reset()
                self.assert_rejected(lambda section=section, key=key, value=value:
                                     self.report[section].update({key: value}))

    def test_logs_status_and_footprint_fail_closed(self) -> None:
        self.assert_rejected(lambda: self.status.update(process_returncode=1))
        self._reset()
        self.assert_rejected(lambda: self.status.update(process_returncode=False))
        self._reset()
        self.assert_rejected(lambda: self.status.update(launcher_pid=float(self.pid)))
        self._reset()
        self.assert_rejected(lambda: self.footprint.update(unit="page"))
        self._reset()
        self.assert_rejected(lambda: self.footprint["samples"][0]
                             .update(processes=[42]))
        self._reset()
        self.assert_rejected(lambda: self.footprint["samples"][0]["processes"][0]
                             ["auxiliary"].update(phys_footprint_peak=0))
        self._reset()
        self.assert_rejected(lambda: self.footprint["samples"][0]["processes"][0]
                             ["auxiliary"].update(phys_footprint_peak=1))
        self._reset()
        self.assert_rejected(lambda: [sample["start_time"].update(
            mach_continuous_time_ns=index * 1_000_000_000 + 1)
            for index, sample in enumerate(self.footprint["samples"])])
        self._reset()
        self.assert_rejected(lambda: self.footprint["samples"].pop())
        self._reset()
        (self.root / "raw" / f"{self.name}.stdout").unlink()
        with self.assertRaises(PERF.EvidenceError):
            PERF.replay(self.root)

    def test_bench_lines_must_be_objects(self) -> None:
        path = self.root / "raw" / f"{self.name}.stdout"
        path.write_text("BENCH_READY []\nBENCH_RESULT "
                        + json.dumps(self.report["summary"]) + "\n",
                        encoding="utf-8")
        with self.assertRaises(PERF.EvidenceError):
            PERF.replay(self.root)

    def test_result_line_must_match_report(self) -> None:
        path = self.root / "raw" / f"{self.name}.stdout"
        path.write_text(path.read_text().replace('"sample_count": 600',
                                                '"sample_count": 599'),
                        encoding="utf-8")
        with self.assertRaises(PERF.EvidenceError):
            PERF.replay(self.root)

    def test_partial_matrix_cannot_be_release_evidence(self) -> None:
        self.plan["budgets"] = {"renderer_mib": 400.0,
                                "footprint_mib": 710.0,
                                "frame_p95_ms": 17.0}
        self._write_bundle()
        with self.assertRaises(PERF.EvidenceError):
            PERF.replay(self.root)

    def test_budget_boundary_and_miss_are_exact(self) -> None:
        rows = [{"stem": self.name, "renderer_allocated_peak_mib": 400.0,
                 "process_physical_footprint_peak_mib": 710.0,
                 "observed_frame_p95_ms": 17.0,
                 "render_cpu_plus_setup_p95_ms": 0.6}]
        self.plan["budgets"] = {"renderer_mib": 400.0,
                                "footprint_mib": 710.0,
                                "frame_p95_ms": 17.0}
        self.assertEqual("pass", PERF.aggregate(self.plan, rows)["status"])
        self.plan["budgets"]["frame_p95_ms"] = 16.999
        self.assertEqual("miss", PERF.aggregate(self.plan, rows)["status"])

    def test_release_matrix_requires_both_locales_and_five_repeats(self) -> None:
        self.plan["shapes"] = list(PERF.SHAPES)
        self._write_bundle()
        with self.assertRaises(PERF.EvidenceError):
            PERF.replay(self.root)


if __name__ == "__main__":
    unittest.main()
