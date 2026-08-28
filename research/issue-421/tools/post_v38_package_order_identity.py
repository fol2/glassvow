#!/usr/bin/env python3
"""Zero-ledger identity preflight for the issue #421 package-order grammar."""

from __future__ import annotations

import copy
import json
import subprocess
import tempfile
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-package-order-identity-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-package-order-identity-v1.json"


def verify_inputs(protocol: dict[str, Any]) -> tuple[dict[str, Any], dict[str, Any]]:
    source = identity.source_identity()
    source["runnerSha256"] = core.file_sha(Path(__file__))
    ledger = identity.ledger_identity()
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


def invalid_level_fails_closed(
    protocol_sha: str, content: str, seed: int, timeout: int
) -> str:
    plan = {
        "schemaVersion": 1,
        "protocolSha256": protocol_sha,
        "content": content,
        "rows": [{
            "id": "invalid-package-order-level",
            "mode": "package-order-surface",
            "pairIndex": 0,
            "seed": seed,
            "research421": {"packageOrder": 2},
        }],
    }
    plan_sha, plan_path = core.cache_json(plan)
    with tempfile.TemporaryDirectory(prefix="issue-421-package-order-invalid-") as tmp:
        out = Path(tmp) / "output.json"
        result = subprocess.run(
            ["godot", "--headless", "-s", "res://tools/research_421_probe.gd", "--",
             f"--plan={plan_path}", f"--out={out}"],
            cwd=core.SOURCE, text=True, capture_output=True, timeout=timeout,
        )
    if result.returncode == 0 or "unregistered level" not in result.stderr:
        raise RuntimeError("unregistered package-order level did not fail closed")
    return plan_sha


def main() -> None:
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    source, ledger_before = verify_inputs(protocol)
    started = time.monotonic()
    content = str(core.CACHE / f"{protocol['immutableInputs']['contentSha256']}.json")
    rows: list[dict[str, Any]] = []
    defaults = protocol["factorDefinition"]["nullSettings"]
    for case in protocol["wholeRunIdentityCases"]:
        common = {
            "id": case["id"],
            "stage": case["stage"],
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
    for pair in protocol["surfaceCases"]:
        for mediator_present in (False, True):
            for level in (0, 1):
                settings = copy.deepcopy(defaults)
                settings["packageOrder"] = level
                rows.append({
                    "id": f"pair-{pair['pairIndex']}-present-{int(mediator_present)}-"
                          f"order-{level}",
                    "mode": "package-order-surface",
                    "pairIndex": pair["pairIndex"],
                    "mediatorPresent": mediator_present,
                    "seed": pair["seed"],
                    "policy": protocol["surfacePolicy"],
                    "research421": settings,
                })
    if len(rows) != protocol["budget"]["probeRowsMaximum"]:
        raise RuntimeError("probe plan does not match the frozen row ceiling")
    plan = {
        "schemaVersion": 1,
        "protocolSha256": protocol_sha,
        "content": content,
        "rows": rows,
    }
    output, plan_sha, output_sha = identity.run_probe(
        plan, protocol["budget"]["maximumWallTimeSeconds"]
    )
    observed = output["rows"]
    frozen = json.loads(
        (core.CACHE / f"{protocol['frozenPath']['outputSha256']}.json").read_text()
    )["rows"]
    whole_run_identity: dict[str, Any] = {}
    cursor = 0
    for case in protocol["wholeRunIdentityCases"]:
        absent, explicit = observed[cursor], observed[cursor + 1]
        identity.require_equal(f"{case['id']} omitted versus explicit null", absent, explicit)
        old = frozen[int(case["frozenRowIndex"])]
        identity.require_equal(f"{case['id']} versus frozen path", absent, old)
        whole_run_identity[case["id"]] = {
            "rowSha256": core.sha(core.canonical(absent).encode()),
            "policySha256": core.sha(core.canonical(absent["policy"]).encode()),
            "trajectorySha256": core.sha(core.canonical(absent["trajectory"]).encode()),
            "rng": absent["rng"],
            "outcome": absent["outcome"],
        }
        cursor += 2
    surface_results: dict[str, Any] = {}
    for pair in protocol["surfaceCases"]:
        pair_rows = observed[cursor:cursor + 4]
        cursor += 4
        by_cell = {
            (row["mediatorPresent"], int(row["research421"]["packageOrder"])): row
            for row in pair_rows
        }
        for row in pair_rows:
            if row["producer"] != pair["producer"] \
                    or row["consumer"] != pair["consumer"] \
                    or row["mediator"] != pair["mediator"]:
                raise RuntimeError(f"pair {pair['pairIndex']} drifted from its frozen identity")
            if row["producerEstablishesMediator"] is not True:
                raise RuntimeError(f"pair {pair['pairIndex']} producer missed its mediator")
            if set(row["combatScores"]) != {pair["producer"], pair["consumer"], "strike"}:
                raise RuntimeError(f"pair {pair['pairIndex']} legal hand drifted")
            if row["rngBeforeChoice"] != row["rngAfterChoice"]:
                raise RuntimeError(f"pair {pair['pairIndex']} choice consumed RNG")
        for mediator_present in (False, True):
            off = by_cell[(mediator_present, 0)]
            on = by_cell[(mediator_present, 1)]
            for key in ("policy", "combatScores", "rngBeforeChoice", "rngAfterChoice"):
                identity.require_equal(
                    f"pair {pair['pairIndex']} presence {mediator_present} {key}",
                    off[key], on[key],
                )
            off_settings = copy.deepcopy(off["research421"])
            on_settings = copy.deepcopy(on["research421"])
            off_settings.pop("packageOrder")
            on_settings.pop("packageOrder")
            identity.require_equal(
                f"pair {pair['pairIndex']} non-target research settings",
                off_settings, on_settings,
            )
            if mediator_present:
                identity.require_equal(
                    f"pair {pair['pairIndex']} present-mediator negative control",
                    off["firstChoice"], on["firstChoice"],
                )
            elif on["firstChoice"] != pair["producer"]:
                raise RuntimeError(f"pair {pair['pairIndex']} did not choose its producer")
        surface_results[str(pair["pairIndex"])] = {
            "producer": pair["producer"],
            "consumer": pair["consumer"],
            "mediator": pair["mediator"],
            "absentOffChoice": by_cell[(False, 0)]["firstChoice"],
            "absentOnChoice": by_cell[(False, 1)]["firstChoice"],
            "presentOffChoice": by_cell[(True, 0)]["firstChoice"],
            "presentOnChoice": by_cell[(True, 1)]["firstChoice"],
            "policyScoresAndRngExactWithinContrasts": True,
            "presentMediatorNegativeControlExact": True,
        }
    invalid_plan_sha = invalid_level_fails_closed(
        protocol_sha,
        content,
        protocol["surfaceCases"][0]["seed"],
        protocol["budget"]["maximumWallTimeSeconds"],
    )
    elapsed = time.monotonic() - started
    if elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        raise RuntimeError("preflight exceeded the frozen wall-time ceiling")
    ledger_after = identity.ledger_identity()
    identity.require_equal("append-only ledger", ledger_before, ledger_after)
    summary = {
        "schemaVersion": 1,
        "decision": "package-order-identity-safe",
        "protocolSha256": protocol_sha,
        "runnerSha256": source["runnerSha256"],
        "planSha256": plan_sha,
        "outputSha256": output_sha,
        "invalidPlanSha256": invalid_plan_sha,
        "frozenPathOutputSha256": protocol["frozenPath"]["outputSha256"],
        "wholeRunIdentity": whole_run_identity,
        "surfaceResults": surface_results,
        "wallTimeSeconds": elapsed,
        "newLedgerObservationRows": 0,
        "unregisteredLevelFailedClosed": True,
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical(summary))


if __name__ == "__main__":
    main()
