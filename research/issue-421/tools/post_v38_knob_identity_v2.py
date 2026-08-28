#!/usr/bin/env python3
"""Repaired zero-ledger identity preflight for issue #421 research knobs."""

from __future__ import annotations

import copy
import json
import subprocess
import tempfile
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as v1
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-knob-identity-v2.json"
SUMMARY = core.ROOT / "summaries/post-v38-knob-identity-v2.json"


def verify_inputs(protocol: dict[str, Any]) -> tuple[dict[str, Any], dict[str, Any]]:
    source = v1.source_identity()
    source["runnerSha256"] = core.file_sha(Path(__file__))
    ledger = v1.ledger_identity()
    for key, expected in protocol["immutableInputs"].items():
        if source.get(key) != expected:
            raise RuntimeError(
                f"immutable input drift: {key} expected {expected} got {source.get(key)}"
            )
    for key, expected in protocol["ledgerFreeze"].items():
        if ledger.get(key) != expected:
            raise RuntimeError(
                f"ledger drift: {key} expected {expected} got {ledger.get(key)}"
            )
    return source, ledger


def invalid_key_fails_closed(
    protocol_sha: str, content: str, seed: int, timeout: int
) -> str:
    plan = {
        "schemaVersion": 1,
        "protocolSha256": protocol_sha,
        "content": content,
        "rows": [{
            "id": "invalid-key",
            "mode": "knob-surface",
            "seed": seed,
            "research421": {"notAResearchKnob": 1},
        }],
    }
    plan_sha, plan_path = core.cache_json(plan)
    with tempfile.TemporaryDirectory(prefix="issue-421-knob-v2-invalid-") as tmp:
        out = Path(tmp) / "output.json"
        result = subprocess.run(
            ["godot", "--headless", "-s", "res://tools/research_421_probe.gd", "--",
             f"--plan={plan_path}", f"--out={out}"],
            cwd=core.SOURCE, text=True, capture_output=True, timeout=timeout,
        )
    if result.returncode == 0 or "unknown research421 key" not in result.stderr:
        raise RuntimeError("unknown research knob did not fail closed")
    return plan_sha


def main() -> None:
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    source, ledger_before = verify_inputs(protocol)
    started = time.monotonic()
    content = str(core.CACHE / f"{protocol['immutableInputs']['contentSha256']}.json")
    defaults = protocol["factorDefinitions"]["nullSettings"]
    rows: list[dict[str, Any]] = []
    for case in protocol["identityCases"]:
        common = {
            "id": case["id"],
            "stage": "post-v38-knob-identity-v2",
            "mode": "whole-run",
            "aspect": case["aspect"],
            "vow": case["vow"],
            "seed": case["seed"],
            "policyRoot": case["policyRoot"],
            "policyIndex": case["policyIndex"],
            "captureTrace": True,
        }
        rows.append(common)
        explicit = copy.deepcopy(common)
        explicit["research421"] = defaults
        rows.append(explicit)
    surface = {
        "id": "null-surface-v2",
        "stage": "post-v38-knob-identity-v2",
        "mode": "knob-surface",
        "seed": protocol["surfaceCase"]["seed"],
        "policy": protocol["surfaceCase"]["policy"],
    }
    rows.append(surface)
    explicit_surface = copy.deepcopy(surface)
    explicit_surface["research421"] = defaults
    rows.append(explicit_surface)
    for label, settings in protocol["surfaceCase"]["settings"].items():
        row = copy.deepcopy(surface)
        row["id"] = label
        row["research421"] = settings
        rows.append(row)
    if len(rows) != protocol["budget"]["probeRowsMaximum"]:
        raise RuntimeError("probe plan does not match the frozen row ceiling")
    plan = {
        "schemaVersion": 1,
        "protocolSha256": protocol_sha,
        "content": content,
        "rows": rows,
    }
    output, plan_sha, output_sha = v1.run_probe(
        plan, protocol["budget"]["maximumWallTimeSeconds"]
    )
    observed = output["rows"]
    identity: dict[str, Any] = {}
    cursor = 0
    for case in protocol["identityCases"]:
        absent, explicit = observed[cursor], observed[cursor + 1]
        v1.require_equal(f"{case['id']} absent versus explicit null", absent, explicit)
        identity[case["id"]] = {
            "rowSha256": core.sha(core.canonical(absent).encode()),
            "policySha256": core.sha(core.canonical(absent["policy"]).encode()),
            "trajectorySha256": core.sha(
                core.canonical(absent["trajectory"]).encode()
            ),
            "rng": absent["rng"],
            "outcome": absent["outcome"],
        }
        cursor += 2
    absent_surface, explicit_surface_result = observed[cursor], observed[cursor + 1]
    v1.require_equal(
        "controlled surface absent versus explicit null",
        absent_surface,
        explicit_surface_result,
    )
    cursor += 2
    surfaces = {
        label: observed[cursor + offset]
        for offset, label in enumerate(protocol["surfaceCase"]["settings"])
    }
    ward_low, ward_high = surfaces["ward-low"], surfaces["ward-high"]
    acquisition_low = surfaces["acquisition-low"]
    acquisition_high = surfaces["acquisition-high"]
    for key in (
        "policy", "scorelineCompletionBonus", "afterimageCompletionBonus",
        "rngBeforeChoice", "rngAfterChoice",
    ):
        v1.require_equal(f"Ward isolation {key}", ward_low[key], ward_high[key])
    expected_cards = {"defend", "guardedStrike", "strike"}
    if set(ward_low["combatScores"]) != expected_cards \
            or set(ward_high["combatScores"]) != expected_cards:
        raise RuntimeError("controlled Ward surface did not expose the frozen legal hand")
    for card_id in ("guardedStrike", "strike"):
        v1.require_equal(
            f"Ward isolation {card_id} score",
            ward_low["combatScores"][card_id],
            ward_high["combatScores"][card_id],
        )
    ward_delta = ward_high["combatScores"]["defend"] \
        - ward_low["combatScores"]["defend"]
    if ward_delta != protocol["surfaceCase"]["expectedWardDefendScoreDelta"]:
        raise RuntimeError(
            f"Ward direct score delta expected "
            f"{protocol['surfaceCase']['expectedWardDefendScoreDelta']} got {ward_delta}"
        )
    for key in (
        "policy", "combatScores", "firstChoice", "rngBeforeChoice", "rngAfterChoice",
    ):
        v1.require_equal(
            f"acquisition isolation {key}", acquisition_low[key], acquisition_high[key]
        )
    expected_bonus = protocol["surfaceCase"]["expectedCompletionBonus"]
    for route in ("scoreline", "afterimage"):
        field = f"{route}CompletionBonus"
        if acquisition_low[field] != expected_bonus["low"] \
                or acquisition_high[field] != expected_bonus["high"]:
            raise RuntimeError(f"acquisition knob missed the {route} reward mediator")
    if ward_low["rngBeforeChoice"] != ward_low["rngAfterChoice"] \
            or ward_high["rngBeforeChoice"] != ward_high["rngAfterChoice"]:
        raise RuntimeError("controlled combat scoring consumed RNG")
    invalid_plan_sha = invalid_key_fails_closed(
        protocol_sha,
        content,
        protocol["surfaceCase"]["seed"],
        protocol["budget"]["maximumWallTimeSeconds"],
    )
    elapsed = time.monotonic() - started
    if elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        raise RuntimeError("preflight exceeded the frozen wall-time ceiling")
    ledger_after = v1.ledger_identity()
    v1.require_equal("append-only ledger", ledger_before, ledger_after)
    summary = {
        "schemaVersion": 1,
        "decision": "knobs-identity-safe",
        "protocolSha256": protocol_sha,
        "runnerSha256": source["runnerSha256"],
        "planSha256": plan_sha,
        "outputSha256": output_sha,
        "invalidPlanSha256": invalid_plan_sha,
        "identityCases": identity,
        "nullSurfaceSha256": core.sha(core.canonical(absent_surface).encode()),
        "mediatorIsolation": {
            "wardSetupPriority": {
                "lowDefendScore": ward_low["combatScores"]["defend"],
                "highDefendScore": ward_high["combatScores"]["defend"],
                "defendScoreDelta": ward_delta,
                "otherCardScoresUnchanged": True,
                "completionBonusesPolicyAndRngUnchanged": True,
                "lowChoice": ward_low["firstChoice"],
                "highChoice": ward_high["firstChoice"],
            },
            "acquisitionPriority": {
                "lowBonus": expected_bonus["low"],
                "highBonus": expected_bonus["high"],
                "combatScoresChoicePolicyAndRngUnchanged": True,
            },
        },
        "unknownKeyFailedClosed": True,
        "wallTimeSeconds": elapsed,
        "newLedgerObservationRows": 0,
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical(summary))


if __name__ == "__main__":
    main()
