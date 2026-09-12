#!/usr/bin/env python3
"""Sealed-audit and exact finalist evidence for #458."""
from __future__ import annotations

from typing import Any

from balance_f1_f2 import GRIDS


def _identity_shape(proxies: dict[str, Any]) -> dict[str, Any]:
    cells = {grid: str(proxies[grid]["topCell"]) for grid in GRIDS}
    expected = all(cells[f"duskblade:v{vow}"].startswith("shatter")
                   and cells[f"ashwarden:v{vow}"].startswith("smolder") for vow in (0, 5))
    return {"expectedDuskShatterAshSmolder": expected, "topCells": cells}


def _effect_change(development: dict[str, float], audit: dict[str, float],
                   threshold: float) -> dict[str, Any]:
    envelope = {
        "p025": float(audit["p025"]) - float(development["p975"]),
        "p50": float(audit["p50"]) - float(development["p50"]),
        "p975": float(audit["p975"]) - float(development["p025"]),
    }
    excludes_zero = envelope["p025"] > 0.0 or envelope["p975"] < 0.0
    return {"developmentEffect": development, "auditEffect": audit,
            "conservativeChangeEnvelope": envelope,
            "material": excludes_zero and abs(envelope["p50"]) >= threshold}


def audit_comparison(development: dict[str, Any], audit: dict[str, Any],
                     candidate_ids: list[str], threshold: float) -> dict[str, Any]:
    """Compare paired candidate effects across the development and sealed bands."""
    development_by_id = {str(row["id"]): row for row in development["candidates"]}
    audit_by_id = {str(row["id"]): row for row in audit["candidates"]}
    candidates: list[dict[str, Any]] = []
    for candidate_id in candidate_ids:
        if candidate_id == "c000":
            continue
        development_row, audit_row = development_by_id[candidate_id], audit_by_id[candidate_id]
        for key in ("fileSha256", "semanticSha256", "values"):
            if development_row.get(key) != audit_row.get(key):
                raise ValueError(f"sealed audit identity drift for {candidate_id}: {key}")
        development_identity = _identity_shape(development_row["proxies"])
        if audit_row.get("status") != "complete" or audit_row.get("earlyStop"):
            reason = str(audit_row.get("earlyStop") or audit_row.get("status") or "incomplete")
            candidates.append({
                "id": candidate_id,
                "auditStatus": audit_row.get("status"),
                "auditEarlyStop": audit_row.get("earlyStop"),
                "bindingDeficitChanges": {}, "effectChanges": {},
                "developmentIdentity": development_identity, "auditIdentity": None,
                "identityContradiction": False,
                "materialContradictions": [f"audit-early-stop:{reason}"],
                "confidenceBlocked": True, "auditHardConstraints": {},
                "auditReplayIdentity": {
                    "observationsSha256": audit_row.get("observationsSha256", ""),
                    "controlRowCount": audit_row.get("controlRowCount", 0),
                    "landscapeRowCount": audit_row.get("landscapeRowCount", 0),
                    "commit": audit_row.get("commit", ""),
                    "godotVersion": audit_row.get("godotVersion", ""),
                    "hostFingerprint": audit_row.get("hostFingerprint", ""),
                },
            })
            continue
        dev_delta = development_row["bootstrap"]["vsC000"]["gridDelta"]
        audit_delta = audit_row["bootstrap"]["vsC000"]["gridDelta"]
        dev_deficit = development_row["bootstrap"]["vsC000"]["deficitDelta"]
        audit_deficit = audit_row["bootstrap"]["vsC000"]["deficitDelta"]
        changes: dict[str, Any] = {}
        contradictions: list[str] = []
        binding_changes = {
            key: _effect_change(dev_deficit[key], audit_deficit[key], threshold)
            for key in ("c1a", "c1b")
        }
        contradictions.extend(f"binding:{key}" for key, change in binding_changes.items()
                              if change["material"])
        for grid in GRIDS:
            changes[grid] = {}
            for key in ("arm2Rate", "topRate", "thirdRate", "fourthRate", "margin"):
                comparison = _effect_change(dev_delta[grid][key], audit_delta[grid][key], threshold)
                changes[grid][key] = comparison
                if comparison["material"]:
                    contradictions.append(f"{grid}:{key}")
        dev_identity = development_identity
        audit_identity = _identity_shape(audit_row["proxies"])
        identity_contradiction = (dev_identity["expectedDuskShatterAshSmolder"]
                                  != audit_identity["expectedDuskShatterAshSmolder"])
        if identity_contradiction:
            contradictions.append("identity-shape")
        candidates.append({
            "id": candidate_id, "bindingDeficitChanges": binding_changes,
            "effectChanges": changes,
            "developmentIdentity": dev_identity, "auditIdentity": audit_identity,
            "identityContradiction": identity_contradiction,
            "materialContradictions": contradictions,
            "confidenceBlocked": bool(contradictions),
            "auditHardConstraints": {
                grid: {
                    "arm2Rate": audit_row["proxies"][grid]["arm2Rate"],
                    "arm2RateInterval": audit_row["bootstrap"]["grids"][grid]["arm2Rate"],
                    "margin": audit_row["proxies"][grid]["margin"],
                    "marginInterval": audit_row["bootstrap"]["grids"][grid]["margin"],
                } for grid in GRIDS
            },
        })
    return {"issue": 458, "nonGating": True, "threshold": threshold,
            "method": ("fail-closed audit early stops; otherwise conservative difference "
                       "of paired candidate-vs-c000 envelopes"),
            "candidates": candidates}


def hydrated_updates(values: dict[str, Any]) -> dict[str, dict[str, str]]:
    """Render every catalogue and locale string coupled to the eight numeric leaves."""
    flare = int(values["flareDamage"])
    smolder, ward = int(values["ashfallSmolder"]), int(values["ashfallWard"])
    regen, iron = int(values["regrowthHeal"]), int(values["ironSkinWard"])
    guarded, venom = int(values["guardedStrikeWard"]), int(values["venomStrikeSmolder"])
    english = {
        "arts.flare.text": f"The lantern vents. Deal {flare} damage to ALL enemies.",
        "arts.ashfall.text": (f"The Ashwarden's breath. Apply {smolder} Smolder to ALL enemies "
                               f"and gain {ward} Ward."),
        "cards.regrowth.text": f"At the end of your turn, heal {regen} HP.",
        "cards.regrowth.up.text": f"At the end of your turn, heal {regen + 1} HP.",
        "cards.ironSkin.text": f"At the end of your turn, gain {iron} Ward.",
        "cards.ironSkin.up.text": f"At the end of your turn, gain {iron + 1} Ward.",
        "cards.guardedStrike.text": f"Deal @5@ damage. Gain #{guarded}# Ward.",
        "cards.guardedStrike.up.text": f"Deal @7@ damage. Gain #{guarded + 2}# Ward.",
        "cards.venomStrike.text": f"Deal @4@ damage. Apply {venom} Smolder.",
        "cards.venomStrike.up.text": f"Deal @6@ damage. Apply {venom + 1} Smolder.",
    }
    traditional = {
        "arts.flare.text": f"提燈吐焰。對所有敵人造成 {flare} 點傷害。",
        "arts.ashfall.text": f"灰衛之息。對所有敵人施加 {smolder} 層陰燃，並獲得 {ward} 點護光。",
        "cards.regrowth.text": f"你的回合結束時回復 {regen} 點生命。",
        "cards.regrowth.up.text": f"你的回合結束時回復 {regen + 1} 點生命。",
        "cards.ironSkin.text": f"你的回合結束時獲得 {iron} 點護光。",
        "cards.ironSkin.up.text": f"你的回合結束時獲得 {iron + 1} 點護光。",
        "cards.guardedStrike.text": f"造成 @5@ 點傷害。獲得 #{guarded}# 點護光。",
        "cards.guardedStrike.up.text": f"造成 @7@ 點傷害。獲得 #{guarded + 2}# 點護光。",
        "cards.venomStrike.text": f"造成 @4@ 點傷害。施加 {venom} 層陰燃。",
        "cards.venomStrike.up.text": f"造成 @6@ 點傷害。施加 {venom + 1} 層陰燃。",
    }
    locale_en = {f"content.{path.replace('.up.text', '.textUp')}": text
                 for path, text in english.items()}
    locale_zh = {f"content.{path.replace('.up.text', '.textUp')}": text
                 for path, text in traditional.items()}
    return {"content/full-content.json": english,
            "locale/en.json": locale_en, "locale/zh-Hant.json": locale_zh}


def boundary_diagnostics(values: dict[str, Any], space: dict[str, Any]) -> dict[str, Any]:
    features: list[dict[str, Any]] = []
    for feature in space["features"]:
        levels = feature["values"]
        value = values[feature["id"]]
        position = "interior"
        if value == levels[0]:
            position = "minimum"
        elif value == levels[-1]:
            position = "maximum"
        features.append({"feature": feature["id"], "value": value,
                         "range": [levels[0], levels[-1]], "position": position})
    return {"features": features,
            "boundaryCount": sum(row["position"] != "interior" for row in features)}


def finalist_contract(candidate_ids: list[str], candidate_manifest: dict[str, Any],
                      layer_decisions: dict[str, Any], cem: dict[str, Any],
                      audit: dict[str, Any], space: dict[str, Any]) -> dict[str, Any]:
    """Bind an ordered, at-most-three shortlist to its exact implementation packet."""
    if not 1 <= len(candidate_ids) <= 3 or len(candidate_ids) != len(set(candidate_ids)):
        raise ValueError("finalist order must contain one to three unique candidates")
    promoted = set(layer_decisions["promoted"])
    if any(candidate_id not in promoted for candidate_id in candidate_ids):
        raise ValueError("every finalist must be promoted by the final racing layer")
    manifest_by_id = {str(row["id"]): row for row in candidate_manifest["candidates"]}
    decision_by_id = {str(row["id"]): row for row in layer_decisions["decisions"]}
    cem_by_id = {str(row["id"]): row for row in cem["candidates"]}
    audit_by_id = {str(row["id"]): row for row in audit["candidates"]}
    finalists: list[dict[str, Any]] = []
    for rank, candidate_id in enumerate(candidate_ids, 1):
        candidate = manifest_by_id[candidate_id]
        evidence = decision_by_id[candidate_id]["evidence"]
        proxies, bootstrap = evidence["proxies"], evidence["bootstrap"]
        identity = _identity_shape(proxies)
        point_clear = all(float(proxies[grid]["arm2Rate"]) < 0.5
                          and float(proxies[grid]["margin"]) >= 0.35 for grid in GRIDS)
        no_clear_regression = all(
            float(bootstrap["grids"][grid]["arm2Rate"]["p025"]) < 0.5
            and float(bootstrap["grids"][grid]["margin"]["p975"]) >= 0.35
            for grid in GRIDS)
        vow5 = cem_by_id[candidate_id]["vow5Ceiling"]
        identity_clear = bool(identity["expectedDuskShatterAshSmolder"])
        if (not point_clear or not no_clear_regression or not identity_clear
                or not bool(vow5["clear"])):
            raise ValueError(f"finalist {candidate_id} has a development hard-constraint fault")
        finalists.append({
            "rank": rank, "id": candidate_id, "values": candidate["values"],
            "numericPatch": candidate["patch"],
            "intendedHydratedUpdates": hydrated_updates(candidate["values"]),
            "boundaryDiagnostics": boundary_diagnostics(candidate["values"], space),
            "hardConstraintChecks": {"pointClear": point_clear,
                                     "noClearBootstrapRegression": no_clear_regression,
                                     "identityShapeClear": identity_clear,
                                     "developmentVow5Ceiling": vow5,
                                     "grids": {grid: {
                                         "arm2Rate": proxies[grid]["arm2Rate"],
                                         "arm2RateInterval": bootstrap["grids"][grid]["arm2Rate"],
                                         "margin": proxies[grid]["margin"],
                                         "marginInterval": bootstrap["grids"][grid]["margin"],
                                     } for grid in GRIDS}},
            "identityChecks": identity,
            "development": {"deficits": evidence["deficits"],
                            "pairedVsC000": bootstrap.get("vsC000", {})},
            "miniCem": cem_by_id[candidate_id],
            "sealedAudit": audit_by_id[candidate_id],
            "replayIdentity": {
                "candidateFileSha256": candidate["fileSha256"],
                "candidateSemanticSha256": candidate["semanticSha256"],
                "layerInputHash": evidence["inputHash"],
                "layerObservationsSha256": evidence["observationsSha256"],
                "layerCommit": evidence["commit"], "godotVersion": evidence["godotVersion"],
                "hostFingerprint": evidence["hostFingerprint"],
            },
        })
    return {"issue": 458, "orderedFinalists": finalists,
            "auditNonGating": bool(audit["nonGating"]),
            "tier0BoundaryCounts": {row["id"]: row["boundaryDiagnostics"]["boundaryCount"]
                                    for row in finalists}}
