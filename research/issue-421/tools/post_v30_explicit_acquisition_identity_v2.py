#!/usr/bin/env python3
"""Versioned explicit-acquisition identity after exact call-binding correction."""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path
from typing import Any

import post_v30_explicit_acquisition_identity as v1
import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v30-explicit-acquisition-identity-v2.json"
SUMMARY = core.ROOT / "summaries/post-v30-explicit-acquisition-identity-v2.json"
SOURCE = core.ROOT / "dusk-explicit-acquisition-identity-v2-source"
V1_SOURCE = core.ROOT / "dusk-explicit-acquisition-identity-v1-source"
BASE_VERIFY = v1.verify_preflight

# Reuse the frozen v1 engine; only its source and runner provenance are rebound.
v1.SOURCE = SOURCE
v1.PROTOCOL = PROTOCOL
v1.SUMMARY = SUMMARY
v1.__file__ = __file__


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Explicit acquisition identity v2 mismatch: {label}")


def cache(digest: str) -> dict[str, Any]:
    path = core.CACHE / f"{digest}.json"
    require(f"cache {digest}", path.is_file() and core.file_sha(path) == digest)
    value = json.loads(path.read_text())
    require(f"cache {digest} type", isinstance(value, dict))
    return value


def correction_exact(protocol: dict[str, Any]) -> bool:
    contract = protocol["callBindingContract"]
    old = (V1_SOURCE / contract["probePath"]).read_text()
    new = (SOURCE / contract["probePath"]).read_text()
    require("corrected omitted template", new.count(contract["omittedTemplate"]) == 1)
    require("corrected off template", new.count(contract["offTemplate"]) == 1)
    require("old omitted template absent", contract["faultyOmittedTail"] not in new)
    require("old off template absent", contract["faultyOffTail"] not in new)
    normalised = new.replace(
        contract["correctedOmittedTail"], contract["faultyOmittedTail"],
    ).replace(contract["correctedOffTail"], contract["faultyOffTail"])
    require("probe semantic diff", normalised == old)
    for relative in contract["unchangedSourcePaths"]:
        require(f"unchanged v1 source {relative}",
                (SOURCE / relative).read_bytes() == (V1_SOURCE / relative).read_bytes())
    sim = (SOURCE / "tools/balance_sim.gd").read_text()
    require("off is excluded from enabled injection", sim.count(
        'if aspect == "duskblade" and dusk_acquisition_choice in '
        '["executioner", "guardedStrike"]:'
    ) == 1)
    return True


def preflight(
    protocol: dict[str, Any], protocol_sha: str,
) -> tuple[dict[str, Any], dict[str, Any], dict[str, Any], dict[str, Any]]:
    baseline, result, plans = BASE_VERIFY(protocol, protocol_sha)
    require("two-binding correction exact", correction_exact(protocol))
    reused = protocol["reusedDirectEvidence"]
    direct_output = cache(reused["outputSha256"])
    require("reused direct plan", direct_output["planSha256"] == reused["planSha256"])
    require("reused direct probe", direct_output["probeSha256"] == reused["probeSha256"])
    require("reused direct provenance", direct_output["contentIdentity"] ==
            reused["contentIdentity"])
    require("reused direct rows", len(direct_output["rows"]) == reused["rows"])
    content = cache(protocol["immutableInputs"]["contentSha256"])
    direct = v1.analyse_direct(direct_output["rows"], protocol, content)
    result.update({
        "completeCallTemplatesExact": True,
        "v1ToV2SemanticDiffLimitedToTwoBindings": True,
        "directControlsReusedUnderExactUnchangedSource": True,
    })
    return baseline, result, plans, direct


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite explicit acquisition identity v2")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    deadline = started + float(protocol["budget"]["maximumWallTimeSeconds"])
    ledger_before: dict[str, Any] = {}
    ledger_after: dict[str, Any] = {}
    mechanical: dict[str, Any] = {"status": "UNRESOLVED"}
    direct: dict[str, Any] = {}
    sentinel: dict[str, Any] = {}
    full: dict[str, Any] = {}
    cache_objects: dict[str, str] = {}
    execution_error = ""
    unavailable = False
    new_rows = 0
    godot_processes = 0
    baseline: dict[str, Any] = {}
    plans: dict[str, Any] = {}
    try:
        ledger_before = identity.ledger_identity()
        require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
        baseline, mechanical, plans, direct = preflight(protocol, protocol_sha)
    except (FileNotFoundError, json.JSONDecodeError, KeyError, TypeError,
            ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        execution_error, unavailable = str(error), True

    if not execution_error:
        try:
            sentinel_output, plan_sha, output_sha = v1.run_probe(
                plans["sentinel"], deadline,
            )
            godot_processes += 1
            cache_objects.update({
                "sentinelPlanSha256": plan_sha,
                "sentinelOutputSha256": output_sha,
            })
            sentinel_expected = protocol["staging"]["expectedOutputRows"]["sentinel"]
            try:
                v1.verify_output(
                    "sentinel", sentinel_output, sentinel_expected, protocol, True,
                )
            except RuntimeError as error:
                execution_error, unavailable = str(error), True
            if not execution_error:
                new_rows += len(sentinel_output["rows"])
                per_arm = sentinel_expected // 2
                base_rows = baseline["rows"][:per_arm]
                omitted = sentinel_output["rows"][:per_arm]
                off = sentinel_output["rows"][per_arm:]
                sentinel = {
                    "pristineVersusOmitted": v1.comparison(
                        base_rows, omitted, protocol,
                    ),
                    "omittedVersusOff": v1.comparison(omitted, off, protocol),
                }
                if all(v1.exact(value) for value in sentinel.values()):
                    remainder_output, plan_sha, output_sha = v1.run_probe(
                        plans["remainder"], deadline,
                    )
                    godot_processes += 1
                    cache_objects.update({
                        "remainderPlanSha256": plan_sha,
                        "remainderOutputSha256": output_sha,
                    })
                    remainder_expected = protocol["staging"][
                        "expectedOutputRows"
                    ]["remainder"]
                    try:
                        v1.verify_output(
                            "remainder", remainder_output, remainder_expected,
                            protocol, True,
                        )
                    except RuntimeError as error:
                        execution_error, unavailable = str(error), True
                    if not execution_error:
                        new_rows += len(remainder_output["rows"])
                        per_remainder = remainder_expected // 2
                        omitted += remainder_output["rows"][:per_remainder]
                        off += remainder_output["rows"][per_remainder:]
                        require("full arm cardinality", len(omitted) == len(off) ==
                                protocol["cohort"]["rows"])
                        full = {
                            "pristineVersusOmitted": v1.comparison(
                                baseline["rows"], omitted, protocol,
                            ),
                            "omittedVersusOff": v1.comparison(
                                omitted, off, protocol,
                            ),
                        }
        except (OSError, subprocess.TimeoutExpired) as error:
            execution_error, unavailable = str(error), True
        except (FileNotFoundError, json.JSONDecodeError, KeyError, TypeError,
                ValueError, RuntimeError) as error:
            execution_error = str(error)

    try:
        ledger_after = identity.ledger_identity()
        require("zero-row ledger identity", ledger_after == ledger_before)
    except (RuntimeError, OSError) as error:
        execution_error, unavailable = str(error), True
    elapsed = time.monotonic() - started
    if elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        execution_error, unavailable = "explicit acquisition identity v2 exceeded wall-time cap", True
    if new_rows > protocol["budget"]["maximumNewIdentityObservationRows"]:
        execution_error, unavailable = "explicit acquisition identity v2 exceeded row cap", True
    if godot_processes > protocol["budget"]["maximumGodotProcesses"]:
        execution_error, unavailable = "explicit acquisition identity v2 exceeded process cap", True
    full_exact = bool(full) and all(v1.exact(value) for value in full.values())
    if execution_error and unavailable:
        boundary, outcome = 3, "inconclusive"
        decision = "record-explicit-acquisition-identity-v2-inconclusive"
    elif execution_error or not full_exact:
        boundary, outcome = 2, "futility"
        decision = "close-explicit-acquisition-factor-on-v2-identity-failure"
    else:
        boundary, outcome = 1, "success"
        decision = "freeze-explicit-acquisition-factor-for-support"
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "decisionBoundary": boundary,
        "decision": decision,
        "outcomeClass": outcome,
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "mechanicalPreflight": mechanical,
        "directControls": {
            "source": "reused immutable v1 under exact unchanged direct source",
            **direct,
        },
        "sentinelIdentity": sentinel,
        "fullNullIdentity": full,
        "cacheObjects": cache_objects,
        "executionError": execution_error,
        "newIdentityObservationRows": new_rows,
        "reusedDirectIdentityRows": protocol["reusedDirectEvidence"]["rows"],
        "enabledWholeRunRows": 0,
        "newSupportRows": 0,
        "newCausalRows": 0,
        "newLedgerRows": 0,
        "GodotProcesses": godot_processes,
        "protectedSeedRows": ledger_after.get(
            "protectedSeedRows", ledger_before.get("protectedSeedRows", 0),
        ),
        "maximumModelContextTokens": 0,
        "wallTimeSeconds": elapsed,
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "authority": protocol["decisionRules"][f"{outcome}Authority"],
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": "PASS",
        "decisionBoundary": boundary,
        "decision": decision,
        "newIdentityObservationRows": new_rows,
        "enabledWholeRunRows": 0,
        "summarySha256": core.file_sha(SUMMARY),
    }))


if __name__ == "__main__":
    main()
