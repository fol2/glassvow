#!/usr/bin/env python3
"""Fail-closed unit laws for the release-performance evidence replay."""
from __future__ import annotations

import copy
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
            "kind": "boss", "seed": 717, "act": 1,
            "shapes": list(PERF.SHAPES), "languages": ["en", "zh-Hant"],
            "repeats": 5, "budgets": None, "app_sha256": "b" * 64,
            "pck_sha256": "c" * 64,
            "environment": dict(PERF.TARGET_ENVIRONMENT),
        }
        values = [17.0] * 600
        zeros = [0.0] * 600
        cpu = [0.5] * 600
        setup = [0.1] * 600
        renderer = [400.0 * 1048576] * 600
        self.report = {
            "schema": 1,
            "provenance": {"claimed_commit": "a" * 40,
                           "godot": PERF.TARGET_ENVIRONMENT["godot"],
                           "os": "macOS", "architecture": "arm64",
                           "renderer": "Apple M4 (Apple9)", "release": True,
                           "rendering_method": "mobile"},
            "request": {"fight": self.plan["fight"], "kind": "boss",
                        "seed": 717, "act": 1, "shape": "phone-landscape",
                        "window": [844, 390], "language": "en"},
            "method": {"warmup_seconds": 6.0, "warmup_frames_min": 300,
                       "sample_seconds": 10.0, "sample_frames_min": 600,
                       "vfx_particles_start": 96, "vfx_particles_end": 96,
                       "measured_viewports": 5,
                       "viewport_sizes": [[844, 390]] + [[100, 100]] * 4,
                       "actor_stage_sizes": [[100, 100], [100, 100]],
                       "viewport_pixels": 844 * 390 + 40000},
            "samples": {"observed_frame_ms": values, "render_cpu_ms": cpu,
                        "frame_setup_cpu_ms": setup,
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
                "start_time": {"mach_continuous_time_ns": index * 2_000_000_000 + 1},
                "processes": [{
                "pid": self.pid, "translated": False, "footprint": 700 * 1048576,
                "auxiliary": {"phys_footprint": 700 * 1048576,
                              "phys_footprint_peak": 710 * 1048576}}]}
                for index in range(9)],
        }
        self.footprint["samples"].append({
            "errors": [], "start_time": {"mach_continuous_time_ns": 18_000_000_001},
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
        for path in raw.iterdir():
            path.unlink()
        for shape in self.plan["shapes"]:
            for language in self.plan["languages"]:
                for repeat in range(1, self.plan["repeats"] + 1):
                    name = f"{shape}--{language}--r{repeat}"
                    report = self.report if name == self.name else copy.deepcopy(self.report)
                    report["request"] = PERF.expected(self.plan, shape, language)
                    report["request"].pop("commit")
                    window = PERF.SHAPES[shape]
                    report["method"]["viewport_sizes"][0] = window
                    report["method"]["viewport_pixels"] = window[0] * window[1] + 40000
                    footprint = self.footprint if name == self.name else copy.deepcopy(self.footprint)
                    status = self.status if name == self.name else dict(self.status)
                    dump(raw / f"{name}.report.json", report)
                    dump(raw / f"{name}.footprint.json", footprint)
                    dump(raw / f"{name}.status.json", status)
                    ready = {"pid": self.pid, "shape": shape, "window": window,
                             "actors": 2, "measured_viewports": 5,
                             "language": language, "renderer": "Apple M4 (Apple9)"}
                    (raw / f"{name}.stdout").write_text(
                        "BENCH_READY " + json.dumps(ready) + "\nBENCH_RESULT "
                        + json.dumps(report["summary"]) + "\n", encoding="utf-8")
                    for suffix in ("stderr", "footprint.stdout", "footprint.stderr"):
                        (raw / f"{name}.{suffix}").write_text("", encoding="utf-8")

    def assert_replay_rejected(self, mutator: Any) -> None:
        mutator()
        self._write_bundle()
        with self.assertRaises(PERF.EvidenceError):
            PERF.replay(self.root)

    def assert_report_rejected(self, mutator: Any) -> None:
        mutator()
        with self.assertRaises(PERF.EvidenceError):
            PERF.validate_report(self.report, PERF.expected(
                self.plan, "phone-landscape", "en"))

    def assert_footprint_rejected(self, mutator: Any) -> None:
        mutator()
        with self.assertRaises(PERF.EvidenceError):
            PERF.validate_footprint(self.footprint, self.pid)

    def test_valid_report_and_footprint_replay(self) -> None:
        metrics = PERF.validate_report(self.report, PERF.expected(
            self.plan, "phone-landscape", "en"))
        self.assertEqual(400.0, metrics["renderer_allocated_peak_mib"])
        self.assertEqual(710.0, PERF.validate_footprint(self.footprint, self.pid))
        self.assertEqual(50, len(PERF.replay(self.root)["rows"]))

    def test_capture_merges_live_and_exit_footprint_samples(self) -> None:
        live = self.root / "live.json"
        exited = self.root / "exit.json"
        merged = self.root / "merged.json"
        dump(live, self.footprint)
        exit_sample = {"unit": "byte", "bytes per unit": 1,
                       "samples": [{"errors": [], "start_time": {
                           "mach_continuous_time_ns": 20_000_000_001},
                           "processes": []}]}
        dump(exited, exit_sample)
        PERF.merge_footprints(live, exited, merged)
        evidence = json.loads(merged.read_text())
        self.assertEqual(11, len(evidence["samples"]))
        self.assertEqual([], evidence["samples"][-1]["processes"])

    def test_footprint_accepts_only_the_observed_terminal_teardown_race(self) -> None:
        def evidence(error: str) -> dict[str, Any]:
            race = copy.deepcopy(self.footprint)
            teardown = copy.deepcopy(race["samples"][-2])
            teardown["start_time"]["mach_continuous_time_ns"] = 17_000_000_001
            teardown["processes"][0]["footprint"] = None
            teardown["errors"] = [error]
            race["samples"].insert(-1, teardown)
            return race

        for error in (
                "mach_vm_region_recurse - (os/kern) invalid argument",
                "mach_vm_page_range_query - (os/kern) invalid argument"):
            with self.subTest(error=error):
                self.assertEqual(710.0, PERF.validate_footprint(
                    evidence(error), self.pid))

        unknown = evidence("unexpected sampling failure")
        with self.assertRaises(PERF.EvidenceError):
            PERF.validate_footprint(unknown, self.pid)

        duplicate = evidence(
            "mach_vm_region_recurse - (os/kern) invalid argument")
        duplicate["samples"][-2]["errors"].append(
            "mach_vm_page_range_query - (os/kern) invalid argument")
        with self.assertRaises(PERF.EvidenceError):
            PERF.validate_footprint(duplicate, self.pid)

        nonterminal = evidence(
            "mach_vm_region_recurse - (os/kern) invalid argument")
        nonterminal["samples"].insert(-1, copy.deepcopy(
            nonterminal["samples"][-3]))
        with self.assertRaises(PERF.EvidenceError):
            PERF.validate_footprint(nonterminal, self.pid)

        for label, mutate in (
                ("timestamp", lambda sample: sample["start_time"].update(
                    mach_continuous_time_ns=0)),
                ("pid", lambda sample: sample["processes"][0].update(pid=7)),
                ("translated", lambda sample: sample["processes"][0].update(
                    translated=True)),
                ("auxiliary", lambda sample: sample["processes"][0].pop(
                    "auxiliary")),
                ("current", lambda sample: sample["processes"][0]["auxiliary"]
                    .update(phys_footprint=0)),
                ("peak", lambda sample: sample["processes"][0]["auxiliary"]
                    .update(phys_footprint_peak=1))):
            with self.subTest(field=label):
                malformed = evidence(
                    "mach_vm_region_recurse - (os/kern) invalid argument")
                mutate(malformed["samples"][-2])
                with self.assertRaises(PERF.EvidenceError):
                    PERF.validate_footprint(malformed, self.pid)

    def test_plan_matrix_and_types_fail_closed(self) -> None:
        self.plan.update(shapes=["phone-landscape"] * 2)
        with self.assertRaises(PERF.EvidenceError):
            PERF.validate_plan(self.plan)
        self._reset()
        self.plan.update(repeats=False)
        with self.assertRaises(PERF.EvidenceError):
            PERF.validate_plan(self.plan)
        self._reset()
        self.plan.update(shapes=[{}])
        with self.assertRaises(PERF.EvidenceError):
            PERF.validate_plan(self.plan)

    def test_method_and_derived_cpu_fail_closed(self) -> None:
        self.assert_report_rejected(
            lambda: self.report["method"].update(sample_seconds=2.0))
        self._reset()
        self.assert_report_rejected(lambda: self.report["summary"]
                                    .update(render_cpu_plus_setup_p95_ms=9.0))
        self._reset()
        self.assert_report_rejected(lambda: self.report["samples"]
                                    .update(renderer_allocated_bytes=[0.0] * 600))
        self._reset()
        self.assert_report_rejected(lambda: self.report["method"]
                                    .update(vfx_particles_end=95))

    def test_exported_vector_inventory_replays_and_malformed_vectors_fail(self) -> None:
        self.report["method"]["viewport_sizes"] = [
            "(844, 390)", "(100, 100)", "(100, 100)",
            "(100, 100)", "(100, 100)"]
        self.report["method"]["actor_stage_sizes"] = ["(100, 100)"] * 2
        PERF.validate_report(self.report, PERF.expected(
            self.plan, "phone-landscape", "en"))
        self.report["method"]["viewport_sizes"][1] = "Vector2i(100, 100)"
        with self.assertRaises(PERF.EvidenceError):
            PERF.validate_report(self.report, PERF.expected(
                self.plan, "phone-landscape", "en"))

    def test_request_and_method_integer_types_are_strict(self) -> None:
        for section, key, value in (("request", "act", False),
                                    ("request", "seed", 717.0),
                                    ("method", "measured_viewports", 5.9),
                                    ("method", "viewport_pixels", 369160.5)):
            with self.subTest(section=section, key=key):
                self._reset()
                self.assert_report_rejected(
                    lambda section=section, key=key, value=value:
                    self.report[section].update({key: value}))

    def test_runtime_provenance_matches_the_signed_target(self) -> None:
        self.assert_report_rejected(lambda: self.report["provenance"]
                                    .update(godot="4.7.1.counterfeit"))
        self._reset()
        self.assert_report_rejected(lambda: self.report["provenance"]
                                    .update(renderer="Another GPU"))

    def test_logs_accept_only_known_runtime_warnings(self) -> None:
        expected = PERF.expected(self.plan, "phone-landscape", "en")
        summary = self.report["summary"]
        ready = {"pid": self.pid, "shape": "phone-landscape",
                 "window": [844, 390], "actors": 2, "language": "en"}
        stdout = "BENCH_READY " + json.dumps(ready) + "\nBENCH_RESULT " \
            + json.dumps(summary) + "\n"
        warnings = "\n".join((
            "WARNING: MapStrip: absent — act 1 skyband uses the procedural draw",
            "WARNING: 2 ObjectDB instances were leaked at exit",
        ))
        self.assertEqual(self.pid, PERF.validate_logs(stdout, warnings,
                                                      expected, summary))
        with self.assertRaises(PERF.EvidenceError):
            PERF.validate_logs(stdout, warnings + "\nWARNING: surprise",
                               expected, summary)

    def test_logs_status_and_footprint_fail_closed(self) -> None:
        self.assert_replay_rejected(lambda: self.status.update(process_returncode=1))
        self._reset()
        self.assert_replay_rejected(lambda: self.status.update(process_returncode=False))
        self._reset()
        self.assert_replay_rejected(lambda: self.status.update(launcher_pid=float(self.pid)))
        self._reset()
        self.assert_footprint_rejected(lambda: self.footprint.update(unit="page"))
        self._reset()
        self.assert_footprint_rejected(lambda: self.footprint["samples"][0]
                                       .update(processes=[42]))
        self._reset()
        self.assert_footprint_rejected(
            lambda: self.footprint["samples"][0]["processes"][0]
            ["auxiliary"].update(phys_footprint_peak=0))
        self._reset()
        self.assert_footprint_rejected(
            lambda: self.footprint["samples"][0]["processes"][0]
            ["auxiliary"].update(phys_footprint_peak=1))
        self._reset()
        self.assert_footprint_rejected(lambda: [sample["start_time"].update(
            mach_continuous_time_ns=index * 1_000_000_000 + 1)
            for index, sample in enumerate(self.footprint["samples"])])
        self._reset()
        self.assert_footprint_rejected(lambda: self.footprint["samples"].pop())
        self._reset()
        self.assert_footprint_rejected(lambda: [sample.update(processes=[])
            for sample in self.footprint["samples"][1:]])
        self._reset()
        self.footprint["samples"][3]["start_time"]["mach_continuous_time_ns"] += \
            3_000_000_000
        with self.assertRaises(PERF.EvidenceError):
            PERF.validate_footprint(self.footprint, self.pid)
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
        self.plan["shapes"] = ["phone-landscape"]
        self.plan["budgets"] = {"renderer_mib": 400.0,
                                "footprint_mib": 710.0,
                                "frame_p95_ms": 17.0}
        with self.assertRaises(PERF.EvidenceError):
            PERF.validate_plan(self.plan)

    def test_budget_boundary_and_miss_are_exact(self) -> None:
        rows = [{"stem": self.name, "renderer_allocated_peak_mib": 400.0,
                 "process_physical_footprint_peak_mib": 710.0,
                 "observed_frame_p95_ms": 17.0,
                 "render_cpu_plus_setup_p95_ms": 0.6}]
        plan = dict(self.plan, shapes=["phone-landscape"], languages=["en"],
                    repeats=1, budgets={"renderer_mib": 400.0,
                    "footprint_mib": 710.0, "frame_p95_ms": 17.0})
        self.assertEqual("pass", PERF.aggregate(plan, rows)["status"])
        plan["budgets"]["frame_p95_ms"] = 16.999
        self.assertEqual("miss", PERF.aggregate(plan, rows)["status"])

    def test_release_matrix_requires_both_locales_and_five_repeats(self) -> None:
        self.plan["languages"] = ["en"]
        with self.assertRaises(PERF.EvidenceError):
            PERF.validate_plan(self.plan)


if __name__ == "__main__":
    unittest.main()
