#!/usr/bin/env python3
"""Zero-row opportunity and identity-design audit for #421 target-acts-last."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import tempfile
import time
from pathlib import Path
from typing import Any


PROTOCOL_SHA = "63b64bf656cc926f6f689946a4075a75ef3c733af6d934640072e065771f0859"
BYTE_CAP = 40_000
WALL_CAP_SECONDS = 30


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def git(source: Path, *args: str) -> str:
    return subprocess.run(
        ["git", "-C", str(source), *args], check=True, capture_output=True, text=True
    ).stdout.strip()


def validate_source(source: Path, protocol: dict[str, Any]) -> dict[str, str]:
    identity = protocol["sourceIdentity"]
    require(git(source, "rev-parse", "HEAD") == identity["head"], "source head mismatch")
    require(git(source, "status", "--porcelain", "--untracked-files=all") == "", "source dirty")
    observed: dict[str, str] = {}
    for relative, expected in identity["files"].items():
        value = sha256((source / relative).read_bytes())
        require(value == expected, f"source hash mismatch: {relative}")
        observed[relative] = value
    return observed


def move_packets(move: dict[str, Any]) -> int:
    damage = move.get("dmg")
    times = move.get("times", 1)
    require(type(damage) is int and damage > 0, "possible first-turn move is not damaging")
    require(type(times) is int and times > 0, "possible first-turn move has invalid packet count")
    return times


def opportunity_census(content: dict[str, Any], protocol: dict[str, Any]) -> list[dict[str, Any]]:
    specification = protocol["naturalOpportunityCensus"]
    domains = specification["firstTurnMoveDomains"]
    enemies = content["enemies"]
    surge = enemies["tidecaller"]["moves"]["surge"]
    require("dmg" not in surge, "surge unexpectedly damages")
    require(surge.get("fx") == [{"who": "allies", "id": "str", "n": 2}], "surge producer mismatch")
    witnesses: list[dict[str, Any]] = []
    for act_index, act in enumerate(content["encounters"]):
        for tier in sorted(act):
            for group_index, group in enumerate(act[tier]):
                if len(group) < 2 or group[0] != "tidecaller":
                    continue
                later: list[dict[str, Any]] = []
                valid = True
                for enemy_id in group[1:]:
                    if enemy_id not in domains:
                        valid = False
                        break
                    packets: list[int] = []
                    for move_id in domains[enemy_id]:
                        try:
                            packets.append(move_packets(enemies[enemy_id]["moves"][move_id]))
                        except (KeyError, ValueError):
                            valid = False
                            break
                    if not valid:
                        break
                    later.append({
                        "enemyId": enemy_id,
                        "possibleFirstTurnMoves": domains[enemy_id],
                        "minimumAttackPackets": min(packets),
                    })
                if valid:
                    witnesses.append({
                        "act": act_index + 1,
                        "tier": tier,
                        "index": group_index,
                        "enemies": group,
                        "laterEnemies": later,
                        "guaranteedFirstTurnStrengthExposures": sum(
                            row["minimumAttackPackets"] for row in later
                        ),
                    })
    return witnesses


def source_surface_checks(source: Path) -> dict[str, bool]:
    combat = (source / "domain/rules/combat.gd").read_text(encoding="utf-8")
    enemy_ai = (source / "domain/rules/enemy_ai.gd").read_text(encoding="utf-8")
    enemy_state = (source / "domain/state/enemy_combatant.gd").read_text(encoding="utf-8")
    combat_state = (source / "domain/state/combat_state.gd").read_text(encoding="utf-8")
    events = (source / "domain/events/event_types.gd").read_text(encoding="utf-8")
    pilot = (source / "tools/balance_pilot.gd").read_text(encoding="utf-8")
    screen = (source / "presentation/combat/combat_screen.gd").read_text(encoding="utf-8")
    research_marker = "research421TargetActsLast"
    damage = combat.index("func damage_player(")
    strength = combat.index('dmg += _sget(attacker.statuses, "str")', damage)
    weak = combat.index('if _sget(attacker.statuses, "weak") > 0:', strength)
    vulnerable = combat.index('if _sget(p.statuses, "vulnerable") > 0:', weak)
    enemy_phase = combat.index("# ---- enemy phase")
    enemy_loop = combat.index("for e: EnemyCombatant in cb.enemies:", enemy_phase)
    intent_recompute = combat.index("_compute_intents(run, cb)", enemy_loop)
    return {
        "currentMainResearchMarkerAbsent": all(
            research_marker not in text
            for text in (combat, enemy_ai, enemy_state, combat_state, events, pilot, screen)
        ),
        "authoredEnemyOrderIsArrayOrder": enemy_phase < enemy_loop < intent_recompute,
        "damageReadsStrengthBeforeWeakAndVulnerable": strength < weak < vulnerable,
        "alliesEffectVisitsLivingEnemyArray": 'elif who == "allies":' in combat
        and "for ally: EnemyCombatant in cb.enemies:" in combat
        and "if ally.hp > 0:" in combat,
        "tidecallerFirstTurnSurge": 'return &"surge" if turn == 1' in enemy_ai,
        "voltEelFirstTurnShock": 'var eel: Array[StringName] = [&"shock", &"coil", &"discharge"]' in enemy_ai,
        "mirelurkerFirstTurnDamageDomain": 'return &"sting" if rng.next() < 0.55 else &"barb"' in enemy_ai,
        "fightLocalFlagsCarrierExists": "var flags: Dictionary = {}" in enemy_state,
        "flagsOmittedFromEnemyProjection": '"flags"' not in enemy_state.split("func to_dict()", 1)[1],
        "noRunOrCombatSaveFieldNeeded": research_marker not in combat_state,
        "ordinaryEnemyTargetEnumerationExists": 'if str(d.get("target", "")) == "enemy":' in pilot
        and "for enemy: EnemyCombatant in game.cb.living_enemies():" in pilot,
        "oneEventAndPresentationSurfaceAvailable": "class_name EventTypes" in events
        and "match StringName(str(ev.get(\"t\", \"\"))):" in screen,
    }


def protocol_checks(protocol: dict[str, Any]) -> dict[str, bool]:
    prototype = protocol["minimalResearchPrototype"]
    identity = protocol["identityGateDesign"]
    marker = prototype["marker"]
    event = prototype["event"]
    return {
        "selectedContractBound": protocol["selectedAbstractContract"]["id"] == "TARGET_ACTS_LAST_THIS_PHASE",
        "scorelineOffSeparate": protocol["frozenCausalFactors"]["scoreline"]["level"] == "off"
        and "Separate causal factor" in protocol["frozenCausalFactors"]["scoreline"]["independence"],
        "afterimageOffSeparate": protocol["frozenCausalFactors"]["afterimage"]["level"] == "off"
        and "Separate causal factor" in protocol["frozenCausalFactors"]["afterimage"]["independence"],
        "oneLogicalMarker": marker["logicalFieldCount"] == 1
        and marker["newDeclaredCombatStateFields"] == 0
        and marker["newDeclaredEnemyStateFields"] == 0,
        "twoGameplayHooks": len(prototype["gameplayHooks"]) == 2,
        "oneEventTypeAndPresentationHook": event["newEventTypeCount"] == 1
        and event["presentationHooks"] == 1,
        "threeProductFilesMaximum": len(prototype["sourceFilesPermitted"]) == 3,
        "noPolicyOptimiserHook": all(
            token in prototype["policyBoundary"]
            for token in ("No new policy score", "ML", "RL")
        ),
        "wholeRunAndMatchedNullsFrozen": bool(identity["wholeRunNull"])
        and bool(identity["matchedDirectNull"]),
        "twoDirectPositiveScenarios": len(identity["directPositiveScenarios"]) == 2,
        "boundedFutureIdentity": identity["futureExecutionCeilings"] == {
            "maximumGodotProcesses": 12,
            "maximumDirectScenarios": 8,
            "maximumWholeRunNullRowsPerArm": 64,
            "maximumSimulatorObservationRows": 128,
            "maximumLedgerWrites": 0,
            "maximumProtectedSeedRows": 0,
            "maximumWallTimeSeconds": 180,
            "maximumModelContextTokensDuringExecutionAndDecision": 0,
            "mechanicalCorrectionCap": 1,
        },
    }


def canonical(value: dict[str, Any]) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n").encode()


def enforce_caps(byte_count: int, elapsed_seconds: float) -> None:
    require(byte_count <= BYTE_CAP, "output byte cap exceeded")
    require(elapsed_seconds <= WALL_CAP_SECONDS, "wall-time cap exceeded")


def write_once(path: Path, data: bytes) -> None:
    require(not path.exists(), "refusing to overwrite audit")
    with path.open("xb") as handle:
        handle.write(data)


def self_test() -> None:
    protocol = {
        "naturalOpportunityCensus": {
            "firstTurnMoveDomains": {
                "tidecaller": ["surge"], "mirelurker": ["sting", "barb"], "voltEel": ["shock"]
            }
        }
    }
    content = {
        "enemies": {
            "tidecaller": {"moves": {"surge": {"fx": [{"who": "allies", "id": "str", "n": 2}]}}},
            "mirelurker": {"moves": {"sting": {"dmg": 6}, "barb": {"dmg": 9}}},
            "voltEel": {"moves": {"shock": {"dmg": 7}}},
        },
        "encounters": [{"normal": [["tidecaller", "mirelurker"], ["tidecaller", "voltEel"]]}],
    }
    witnesses = opportunity_census(content, protocol)
    assert len(witnesses) == 2
    assert sum(row["guaranteedFirstTurnStrengthExposures"] for row in witnesses) == 2
    content["enemies"]["voltEel"]["moves"]["shock"] = {"block": 7}
    assert len(opportunity_census(content, protocol)) == 1
    enforce_caps(BYTE_CAP, WALL_CAP_SECONDS)
    for byte_count, elapsed in ((BYTE_CAP + 1, 0.0), (0, WALL_CAP_SECONDS + 0.001)):
        try:
            enforce_caps(byte_count, elapsed)
            raise AssertionError("cap breach accepted")
        except ValueError:
            pass
    with tempfile.TemporaryDirectory() as directory:
        output = Path(directory) / "audit.json"
        data = canonical({"status": "PASS"})
        write_once(output, data)
        try:
            write_once(output, data)
            raise AssertionError("overwrite accepted")
        except ValueError:
            pass
    print("PASS (6 checks)")


def build(protocol_path: Path, source: Path) -> dict[str, Any]:
    protocol_bytes = protocol_path.read_bytes()
    require(sha256(protocol_bytes) == PROTOCOL_SHA, "protocol hash mismatch")
    protocol = json.loads(protocol_bytes)
    source_hashes = validate_source(source, protocol)
    content = json.loads((source / "content/full-content.json").read_text(encoding="utf-8"))
    witnesses = opportunity_census(content, protocol)
    required = protocol["naturalOpportunityCensus"]["requiredExactWitnesses"]
    observed_identities = [
        {key: row[key] for key in ("act", "tier", "index", "enemies")} for row in witnesses
    ]
    distinct_later = sorted({
        later["enemyId"] for row in witnesses for later in row["laterEnemies"]
    })
    strength_exposures = sum(row["guaranteedFirstTurnStrengthExposures"] for row in witnesses)
    thresholds = protocol["naturalOpportunityCensus"]["successThresholds"]
    opportunity_checks = {
        "exactRequiredWitnesses": observed_identities == required,
        "minimumWitnessEncounterDefinitions": len(witnesses) >= thresholds["minimumWitnessEncounterDefinitions"],
        "minimumDistinctLaterEnemyIds": len(distinct_later) >= thresholds["minimumDistinctLaterEnemyIds"],
        "minimumGuaranteedFirstTurnStrengthExposures": strength_exposures
        >= thresholds["minimumGuaranteedFirstTurnStrengthExposures"],
    }
    surfaces = source_surface_checks(source)
    design = protocol_checks(protocol)
    success = all(opportunity_checks.values()) and all(surfaces.values()) and all(design.values())
    return {
        "schemaVersion": 1,
        "issue": 421,
        "outcome": "SUCCESS" if success else "FUTILITY",
        "decisionBoundary": 1 if success else 2,
        "decision": "AUTHORISE_ONE_RESEARCH_PROTOTYPE_AND_IDENTITY_GATE" if success
        else "CLOSE_TARGET_ACTS_LAST_THIS_PHASE",
        "protocolSha256": PROTOCOL_SHA,
        "runnerSha256": sha256(Path(__file__).read_bytes()),
        "sourceHead": protocol["sourceIdentity"]["head"],
        "sourceStatus": [],
        "sourceSha256": source_hashes,
        "opportunityChecks": opportunity_checks,
        "sourceSurfaceChecks": surfaces,
        "protocolDesignChecks": design,
        "witnesses": witnesses,
        "estimands": {
            "witnessEncounterDefinitions": len(witnesses),
            "distinctLaterEnemyIds": len(distinct_later),
            "laterEnemyIds": distinct_later,
            "guaranteedFirstTurnStrengthExposures": strength_exposures,
        },
        "selectedAbstractContract": "TARGET_ACTS_LAST_THIS_PHASE",
        "authorisedResearchPrototypes": 1 if success else 0,
        "candidateCount": 0,
        "GodotProcesses": 0,
        "simulatorRows": 0,
        "cacheReads": 0,
        "cacheWrites": 0,
        "ledgerReads": 0,
        "ledgerWrites": 0,
        "protectedSeedRows": 0,
        "claimBoundary": protocol["claimBoundary"],
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--self-test", action="store_true")
    mode.add_argument("--audit", action="store_true")
    parser.add_argument("--protocol", type=Path)
    parser.add_argument("--source", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return
    require(all((args.protocol, args.source, args.output)), "all audit paths required")
    started = time.monotonic()
    result = build(args.protocol, args.source)
    result["wallTimeSeconds"] = round(time.monotonic() - started, 6)
    data = canonical(result)
    enforce_caps(len(data), time.monotonic() - started)
    write_once(args.output, data)
    print(json.dumps({
        "status": result["outcome"],
        "decision": result["decision"],
        "outputSha256": sha256(data),
        "bytes": len(data),
        "wallTimeSeconds": round(time.monotonic() - started, 6),
    }, sort_keys=True))


if __name__ == "__main__":
    main()
