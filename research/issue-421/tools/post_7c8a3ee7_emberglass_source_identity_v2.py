#!/usr/bin/env python3
"""Run the one authorised mechanical v2 correction of the #421 Emberglass gate."""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path
from typing import Any


V1_PATH = Path(__file__).with_name(
    "post_7c8a3ee7_emberglass_source_identity_v1.py"
)
SPEC = importlib.util.spec_from_file_location("emberglass_source_identity_v1", V1_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"cannot load frozen v1 runner: {V1_PATH}")
V1 = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(V1)

_V1_LOAD = V1._load
_V1_RUN_PROBE = V1._run_probe
_V1_SELF_TEST = V1._self_test

EXPECTED_OVERLAY_KEYS = {
    "schemaVersion",
    "issue",
    "name",
    "kind",
    "state",
    "parentProtocol",
    "authority",
    "correction",
    "inheritedSectionSha256",
    "runner",
}
EXPECTED_CORRECTION = {
    "version": 2,
    "preserveV1": True,
    "onlyRunnerBoundaryChange": (
        "Resolve the already-frozen plan and output paths to absolute paths "
        "before both Godot invocations."
    ),
    "maximumCorrectedVersions": 1,
    "furtherCorrections": 0,
    "candidateSubstitution": False,
    "grammarWidening": False,
    "simulatorRows": 0,
    "protectedSeedRows": 0,
}


def _canonical_sha256(value: Any) -> str:
    return V1.hashlib.sha256(V1._canonical(value).encode("utf-8")).hexdigest()


def _load_v2_overlay(path: Path) -> dict[str, Any]:
    overlay = _V1_LOAD(path)
    if set(overlay) != EXPECTED_OVERLAY_KEYS:
        raise ValueError("v2 overlay keys differ from the frozen correction schema")
    if (
        overlay.get("schemaVersion") != 1
        or overlay.get("issue") != 421
        or overlay.get("kind") != "MECHANICAL_CORRECTION_OVERLAY"
        or overlay.get("state") != "FROZEN_BEFORE_EXECUTION"
    ):
        raise ValueError("invalid v2 correction overlay identity")
    if overlay.get("correction") != EXPECTED_CORRECTION:
        raise ValueError("v2 correction exceeds the authorised mechanical delta")

    parent_info = overlay["parentProtocol"]
    parent_path = V1.ISSUE_ROOT / str(parent_info["path"])
    if V1._sha256(parent_path) != str(parent_info["sha256"]):
        raise ValueError("frozen v1 protocol hash mismatch")
    parent = _V1_LOAD(parent_path)
    for key, expected in overlay["inheritedSectionSha256"].items():
        if key not in parent or _canonical_sha256(parent[key]) != expected:
            raise ValueError(f"inherited v1 section mismatch: {key}")

    authority = overlay["authority"]
    authority_path = V1.ISSUE_ROOT / str(authority["commentPath"])
    if V1._sha256(authority_path) != str(authority["commentBodySha256"]):
        raise ValueError("owner correction authority hash mismatch")

    runner = overlay["runner"]
    runner_path = Path(__file__).resolve()
    expected_runner_path = str(runner_path.relative_to(V1.ISSUE_ROOT.resolve()))
    if runner.get("path") != expected_runner_path:
        raise ValueError("v2 runner path mismatch")
    if runner.get("sha256") != V1._sha256(runner_path):
        raise ValueError("v2 runner hash mismatch")

    merged = V1.copy.deepcopy(parent)
    merged["name"] = overlay["name"]
    merged["runner"] = V1.copy.deepcopy(runner)
    merged["mechanicalCorrection"] = V1.copy.deepcopy(overlay["correction"])
    merged["authorityDelta"] = V1.copy.deepcopy(authority)
    return merged


def _absolute_probe_paths(plan_path: Path, output_path: Path) -> tuple[Path, Path]:
    return plan_path.resolve(), output_path.resolve()


def _run_probe(
    godot: Path,
    root: Path,
    plan_path: Path,
    output_path: Path,
    stdout_path: Path,
    stderr_path: Path,
    timeout_seconds: int,
) -> tuple[int, float]:
    absolute_plan, absolute_output = _absolute_probe_paths(plan_path, output_path)
    return _V1_RUN_PROBE(
        godot,
        root,
        absolute_plan,
        absolute_output,
        stdout_path,
        stderr_path,
        timeout_seconds,
    )


def _self_test() -> None:
    plan, output = _absolute_probe_paths(Path("plan.json"), Path("output.json"))
    assert plan.is_absolute() and plan.name == "plan.json"
    assert output.is_absolute() and output.name == "output.json"
    _V1_SELF_TEST()
    print("PASS (2 v2 absolute-path checks)")


V1._load = _load_v2_overlay
V1._run_probe = _run_probe
V1._self_test = _self_test
V1.__file__ = __file__


if __name__ == "__main__":
    sys.exit(V1.main())
