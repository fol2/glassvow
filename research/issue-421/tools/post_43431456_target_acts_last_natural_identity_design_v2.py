#!/usr/bin/env python3
"""Corrected zero-row audit for #421 target-acts-last."""

from __future__ import annotations

import copy
import json
import tempfile
from pathlib import Path
from typing import Any

import post_43431456_target_acts_last_natural_identity_design_v1 as v1


V1_SHA = "edd97cb336242647443b0e1bed8f3f00d8ee7ca3de78f18091556c277080dea0"
ORIGINAL_BUILD = v1.build
ORIGINAL_CENSUS = v1.opportunity_census
ORIGINAL_SOURCE_CHECKS = v1.source_surface_checks
ORIGINAL_PROTOCOL_CHECKS = v1.protocol_checks


def validate_v1() -> None:
    v1.require(v1.sha256(Path(v1.__file__).read_bytes()) == V1_SHA, "v1 runner drift")


def canonical_encounters(content: dict[str, Any]) -> list[dict[str, Any]]:
    encounters = content.get("encounters")
    acts = content.get("acts")
    themes = content.get("themes")
    theme_order = content.get("themeOrder")
    v1.require(isinstance(encounters, list) and isinstance(acts, list), "canonical encounter arrays missing")
    v1.require(len(encounters) == len(acts), "top-level encounter/act cardinality mismatch")
    v1.require(isinstance(themes, dict) and isinstance(theme_order, list), "theme encounter mirrors missing")
    v1.require(set(theme_order) == set(themes), "theme encounter mirror identity mismatch")
    for theme_id in theme_order:
        v1.require(isinstance(theme_id, str) and theme_id.startswith("act"), "invalid theme act identity")
        suffix = theme_id.removeprefix("act")
        v1.require(suffix.isdigit(), "invalid theme act ordinal")
        index = int(suffix) - 1
        v1.require(0 <= index < len(encounters), "theme act ordinal outside canonical encounters")
        theme = themes[theme_id]
        v1.require(isinstance(theme, dict) and theme.get("encounters") == encounters[index],
                   f"theme encounter mirror drift: {theme_id}")
    return encounters


def witness_identities(witnesses: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [
        {key: row[key] for key in ("act", "tier", "index", "enemies")}
        for row in witnesses
    ]


def opportunity_census(content: dict[str, Any], protocol: dict[str, Any]) -> list[dict[str, Any]]:
    projected = copy.deepcopy(content)
    projected["encounters"] = canonical_encounters(content)
    return ORIGINAL_CENSUS(projected, protocol)


def source_surface_checks(source: Path) -> dict[str, bool]:
    checks = ORIGINAL_SOURCE_CHECKS(source)
    combat = (source / "domain/rules/combat.gd").read_text(encoding="utf-8")
    enemy_ai = (source / "domain/rules/enemy_ai.gd").read_text(encoding="utf-8")
    enemy_state = (source / "domain/state/enemy_combatant.gd").read_text(encoding="utf-8")
    combat_state = (source / "domain/state/combat_state.gd").read_text(encoding="utf-8")
    events = (source / "domain/events/event_types.gd").read_text(encoding="utf-8")
    pilot = (source / "tools/balance_pilot.gd").read_text(encoding="utf-8")
    screen = (source / "presentation/combat/combat_screen.gd").read_text(encoding="utf-8")
    content = (source / "content/full-content.json").read_text(encoding="utf-8")
    marker = "research421TargetActsLast"
    checks["currentMainResearchMarkerAbsent"] = all(
        marker not in text
        for text in (combat, enemy_ai, enemy_state, combat_state, events, pilot, screen, content)
    )
    checks["oneEventAndPresentationSurfaceAvailable"] = all(
        token in screen for token in (
            "func _handle_event(ev: Dictionary) -> void:",
            'var t: StringName = ev["t"]',
            "match t:",
            "EventTypes.INTENT:",
            "EventTypes.ENEMY_ACT:",
        )
    ) and "class_name EventTypes" in events
    checks["canonicalEncounterSurfaceComplete"] = bool(canonical_encounters(json.loads(content)))
    return checks


def protocol_checks(protocol: dict[str, Any]) -> dict[str, bool]:
    checks = ORIGINAL_PROTOCOL_CHECKS(protocol)
    prototype = protocol["minimalResearchPrototype"]
    marker = prototype["marker"]
    event = prototype["event"]
    identity = protocol["identityGateDesign"]
    source_files = prototype["sourceFilesPermitted"]
    card = prototype["card"]
    checks.update({
        "defaultFalseExactContentConfiguration": all(
            token in prototype["configuration"]
            for token in ("defaults false", "Current-main content contains no research card", "cannot activate")
        ),
        "exactResearchCardContract": card == {
            "id": "research421TargetActsLast",
            "type": "skill",
            "rarity": "special",
            "cost": 1,
            "target": "enemy",
            "effect": {"kind": "special", "id": "research421TargetActsLast"},
            "bundledEffects": 0,
            "aspect": "Duskblade only by harness construction; invalid outside aspect 0",
        },
        "exactMarkerCarrierAndProducer": marker["carrier"]
        == "EnemyCombatant.flags[research421TargetActsLast] on exactly one living target"
        and all(token in marker["producer"] for token in ("Clear the key", "selected living target", "enabled", "Duskblade")),
        "completeMarkerLifecycle": all(
            token in marker["consumer"]
            for token in ("local phase-order array", "without mutating cb.enemies", "normal, death and combat-end exits", "before ordinary intent recomputation")
        ) and all(
            token in protocol["selectedAbstractContract"]["expiry"]
            for token in ("next enemy phase", "marked-target death", "combat end", "aspect mismatch", "never enters run state or a save")
        ),
        "exactDirectEventContract": event == {
            "newEventTypeCount": 1,
            "id": "RESEARCH421_TARGET_ACTS_LAST",
            "fields": ["targetIdx", "beforeLivingPosition", "afterLivingPosition", "moved"],
            "cardinality": "Exactly one event per eligible marker consumption; zero when disabled or no marker exists.",
            "presentationHooks": 1,
        },
        "exactPermittedProductFiles": source_files == [
            "domain/rules/combat.gd",
            "domain/events/event_types.gd",
            "presentation/combat/combat_screen.gd",
        ] and set(source_files) <= set(protocol["sourceIdentity"]["files"]),
        "exactPermittedResearchFiles": prototype["researchFilesPermitted"] == [
            "one deterministic content projection",
            "one direct identity probe",
        ],
        "completeWholeRunDisabledPath": all(
            token in identity["wholeRunNull"]
            for token in ("exact-main source/content", "configured false", "identical policy identities, seeds, estimator and stopping rule", "byte-identical canonical outputs", "RNG state", "event sequence", "all existing fields")
        ),
        "completeMatchedDirectNull": all(
            token in identity["matchedDirectNull"]
            for token in ("configured false versus configured true", "same constructed combat state and RNG identity", "Energy cost", "hand/discard movement", "PLAY/ENERGY/TO_DISCARD events")
        ),
        "completeInvalidAndExpiryMatrix": set(identity["invalidOrExpiryScenarios"]) == {
            "Ashwarden activation is rejected.",
            "Dead target produces no marker.",
            "Same-target replay is idempotent.",
            "Different-target replay replaces rather than stacks.",
            "Already-last target consumes with moved=false and no action-order change.",
            "Marked-target death and combat end clear the marker without save/run state.",
        },
    })
    return checks


def build(protocol_path: Path, source: Path) -> dict[str, Any]:
    validate_v1()
    result = ORIGINAL_BUILD(protocol_path, source)
    result["runnerSha256"] = v1.sha256(Path(__file__).read_bytes())
    result["witnesses"] = opportunity_census(
        json.loads((source / "content/full-content.json").read_text(encoding="utf-8")),
        json.loads(protocol_path.read_bytes()),
    )
    return result


def self_test() -> None:
    validate_v1()
    required = [
        {"act": 1, "tier": "normal", "index": 0, "enemies": ["tidecaller", "mirelurker"]},
        {"act": 2, "tier": "normal", "index": 0, "enemies": ["tidecaller", "voltEel"]},
    ]
    protocol = {
        "naturalOpportunityCensus": {
            "firstTurnMoveDomains": {
                "tidecaller": ["surge"], "mirelurker": ["sting", "barb"], "voltEel": ["shock"]
            },
            "requiredExactWitnesses": required,
        }
    }
    content = {
        "acts": [{}, {}],
        "themes": {"act1": {"encounters": {"normal": [["tidecaller", "mirelurker"]]}}},
        "themeOrder": ["act1"],
        "enemies": {
            "tidecaller": {"moves": {"surge": {"fx": [{"who": "allies", "id": "str", "n": 2}]}}},
            "mirelurker": {"moves": {"sting": {"dmg": 6}, "barb": {"dmg": 9}}},
            "voltEel": {"moves": {"shock": {"dmg": 7}}},
        },
        "encounters": [
            {"normal": [["tidecaller", "mirelurker"]]},
            {"normal": [["tidecaller", "voltEel"]]},
        ],
    }
    witnesses = opportunity_census(content, protocol)
    assert witness_identities(witnesses) == required
    assert sum(row["guaranteedFirstTurnStrengthExposures"] for row in witnesses) == 2
    extra = copy.deepcopy(content)
    extra["encounters"][1]["normal"].append(["tidecaller", "voltEel"])
    assert witness_identities(opportunity_census(extra, protocol)) != required
    mismatch = copy.deepcopy(content)
    mismatch["themes"]["act1"]["encounters"] = {"normal": []}
    try:
        canonical_encounters(mismatch)
        raise AssertionError("theme encounter mirror drift accepted")
    except ValueError:
        pass
    non_damage = copy.deepcopy(content)
    non_damage["enemies"]["voltEel"]["moves"]["shock"] = {"block": 7}
    assert len(opportunity_census(non_damage, protocol)) == 1
    v1.enforce_caps(v1.BYTE_CAP, v1.WALL_CAP_SECONDS)
    for byte_count, elapsed in ((v1.BYTE_CAP + 1, 0.0), (0, v1.WALL_CAP_SECONDS + 0.001)):
        try:
            v1.enforce_caps(byte_count, elapsed)
            raise AssertionError("cap breach accepted")
        except ValueError:
            pass
    with tempfile.TemporaryDirectory() as directory:
        output = Path(directory) / "audit.json"
        data = v1.canonical({"status": "PASS"})
        v1.write_once(output, data)
        try:
            v1.write_once(output, data)
            raise AssertionError("overwrite accepted")
        except ValueError:
            pass
    print("PASS (9 checks)")


v1.opportunity_census = opportunity_census
v1.source_surface_checks = source_surface_checks
v1.protocol_checks = protocol_checks
v1.build = build
v1.self_test = self_test


if __name__ == "__main__":
    v1.main()
