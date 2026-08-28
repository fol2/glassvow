#!/usr/bin/env python3
"""Zero-row live Lantern-Art repertoire coverage audit for issue #421."""

from __future__ import annotations

import json
import re
import subprocess
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v30-lantern-art-repertoire-audit-v1.json"
SUMMARY = core.ROOT / "summaries/post-v30-lantern-art-repertoire-audit-v1.json"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Lantern-Art repertoire mismatch: {label}")


def main_blob(path: str) -> bytes:
    return subprocess.run(
        ["git", "show", f"HEAD:{path}"], cwd=core.SOURCE,
        check=True, capture_output=True,
    ).stdout


def function_source(source: str, name: str, static: bool = False) -> str:
    prefix = "static func" if static else "func"
    match = re.search(rf"(?m)^{prefix} {re.escape(name)}\(", source)
    require(f"function {name}", match is not None)
    assert match is not None
    following = re.search(r"(?m)^(?:static )?func [A-Za-z0-9_]+\(", source[match.end():])
    end = len(source) if following is None else match.end() + following.start()
    return source[match.start():end]


def art_signatures(content: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {
        art_id: {"cost": art["cost"], "effects": art["effects"]}
        for art_id, art in sorted(content["arts"].items())
    }


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the Lantern-Art repertoire summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    immutable = protocol["immutableInputs"]
    require("runner SHA", core.file_sha(Path(__file__)) == immutable["runnerSha256"])
    source_commit = subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=core.SOURCE,
        check=True, capture_output=True, text=True,
    ).stdout.strip()
    require("source commit", source_commit == immutable["sourceCommit"])
    for path, expected in immutable["sourceSha256"].items():
        require(f"source {path}", core.sha(main_blob(path)) == expected)
    for path, expected in immutable["fileSha256"].items():
        require(path, core.file_sha(core.ROOT / path) == expected)

    ledger_before = identity.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
    content = json.loads(main_blob("content/full-content.json"))
    application = main_blob("application/main.gd").decode()
    run_state = main_blob("domain/state/run_state.gd").decode()
    combat = main_blob("domain/rules/combat.gd").decode()
    simulator = main_blob("tools/balance_sim.gd").decode()
    pilot = main_blob("tools/balance_pilot.gd").decode()
    policy = main_blob("tools/balance_policy.gd").decode()

    signatures = art_signatures(content)
    require("complete Art catalogue", signatures == protocol["artSignatures"])
    reveal = content["progression"]["revealThresholds"]["lamplighter"]
    require("one-run deterministic reveal", reveal == protocol["liveRoute"]["unlockThreshold"])
    live_new_run = function_source(application, "_new_run")
    live_screen = function_source(application, "_show_lamplighter")
    live_confirm = function_source(application, "_on_lamplighter_confirmed")
    for label, source, sentinels in (
        ("live new-run", live_new_run, protocol["liveRoute"]["newRunSentinels"]),
        ("live screen", live_screen, protocol["liveRoute"]["screenSentinels"]),
        ("live confirm", live_confirm, protocol["liveRoute"]["confirmSentinels"]),
    ):
        for sentinel in sentinels:
            require(f"{label} {sentinel}", sentinel in source)

    new_run = function_source(run_state, "new_run", static=True)
    simulate = function_source(simulator, "simulate", static=True)
    play_turn = function_source(pilot, "play_turn", static=True)
    require("new-run aspect default", protocol["simulatorGap"]["defaultArtSentinel"]
            in new_run)
    require("new-run has no profile Art override", 'profile.get("art"' not in new_run)
    require("simulator disables Lamplighter",
            protocol["simulatorGap"]["disabledLamplighterSentinel"] in simulate)
    require("simulator has no Art override", 'profile["art"]' not in simulate
            and 'run.art =' not in simulate)
    for sentinel in protocol["simulatorGap"]["automaticUseSentinels"]:
        require(f"automatic use {sentinel}", sentinel in play_turn)
    require("pilot has no Art selector", "choose_art" not in pilot)
    require("policy has no Art selector", '"art"' not in policy)

    direct_dusk = []
    default_dusk = str(content["aspects"][0]["art"])
    for art_id, art in content["arts"].items():
        if art_id == default_dusk:
            continue
        if any(effect.get("kind") == "status"
               and effect.get("who") == "self"
               and effect.get("id") == "beacon"
               and int(effect.get("n", 0)) > 0
               for effect in art["effects"]):
            direct_dusk.append(art_id)
    direct_dusk.sort()
    require("source-selected Art class",
            direct_dusk == protocol["selectionRule"]["expectedDirectDuskCoreArts"])
    require("Beacon consumed by implicit chips",
            protocol["selectionRule"]["beaconConsumerSentinel"] in combat)

    elapsed = time.monotonic() - started
    if elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        boundary, outcome = 3, "inconclusive"
        decision, selected = "record-lantern-art-repertoire-inconclusive-at-cap", None
    elif len(direct_dusk) == 1:
        boundary, outcome = 1, "success"
        selected = direct_dusk[0]
        decision = "freeze-beacon-art-factor-for-identity-preflight"
    elif not direct_dusk:
        boundary, outcome = 2, "futility"
        selected = None
        decision = "close-live-lantern-art-route-without-preflight"
    else:
        boundary, outcome = 3, "inconclusive"
        selected = None
        decision = "record-multiple-direct-dusk-art-routes-at-cap"

    ledger_after = identity.ledger_identity()
    require("zero-row ledger identity", ledger_after == ledger_before)
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "decisionBoundary": boundary,
        "decision": decision,
        "outcomeClass": outcome,
        "selectedArt": selected,
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "sourceIdentity": {"commit": source_commit,
                           "sha256": immutable["sourceSha256"]},
        "liveRoute": {
            "unlockThreshold": reveal,
            "allSelectableArts": sorted(signatures),
            "defaultDuskArt": default_dusk,
            "directDuskCoreAlternativeArts": direct_dusk,
            "deterministicChoice": True,
        },
        "simulatorGap": {
            "lamplighterHardDisabled": True,
            "aspectDefaultArtOnly": True,
            "planArtOverride": False,
            "policyArtSelector": False,
            "automaticArtUse": True,
            "failureClass": "policy-repertoire-factor-omission",
        },
        "artSignatures": signatures,
        "newSimulatorObservationRows": 0,
        "cachedObservationRowsRead": 0,
        "newLedgerRows": 0,
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "protectedSeedRows": ledger_after["protectedSeedRows"],
        "maximumModelContextTokens": 0,
        "wallTimeSeconds": elapsed,
        "factorDisposition": protocol["factorDisposition"],
        "authority": protocol["decisionRules"][f"{outcome}Authority"],
    }
    SUMMARY.parent.mkdir(parents=True, exist_ok=True)
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": "PASS",
        "decision": decision,
        "decisionBoundary": boundary,
        "selectedArt": selected,
        "newSimulatorObservationRows": 0,
        "summarySha256": core.file_sha(SUMMARY),
    }))


if __name__ == "__main__":
    main()
