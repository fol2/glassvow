#!/usr/bin/env python3
"""#491 response fields on top of the existing F0 evaluator.

Existing aggregate_controls / grid_proxies / deficits stay the #457 v1
definitions. This module adds the frozen #490 contract fields: valid-cell
rankGaps, occupancy, package diagnostics, guardrails and the promotion
decision. It never emits C1-C4 PASS/FAIL labels.
"""
from __future__ import annotations

import math
import random
from collections import defaultdict
from typing import Any

ASPECTS = ("duskblade", "ashwarden")
VOWS = (0, 5)
TIE = ("shatter", "smolder", "attrition")
THICK = ("thin", "mid", "fat")
GRIDS = tuple(f"{aspect}:v{vow}" for aspect in ASPECTS for vow in VOWS)
REASON = {
    "breadth": "breadth-not-credible",
    "c2": "c2-failed",
    "identity": "identity-failed",
    "vow5": "vow5-proxy-failed",
    "simulator": "simulator-fault",
    "mechanism": "mechanism-not-fired",
    "effect": "package-effect-uncertain",
}
# Distinct from breadth_pareto (valid-cell occupancy at 128x8). Recorded in
# docs/balance/2026-08-26-491-tier1-f0.md for the #492 race.
RACING_SET = ("t1-c012", "t1-c036", "t1-c040", "t1-c005")


def _grid(aspect: str, vow: int) -> str:
    return f"{aspect}:v{vow}"


def _rate(wins: int, runs: int) -> float | None:
    return (wins / runs) if runs else None


def cell_is_valid(cell: dict[str, Any], minimum_policies: int = 20,
                  minimum_runs: int = 400) -> bool:
    return int(cell.get("policies", 0)) >= minimum_policies \
        and int(cell.get("runs", 0)) >= minimum_runs


def _validity(contract: dict[str, Any]) -> tuple[int, int]:
    spec = contract.get("cellValidity", {})
    return int(spec.get("minimumDistinctPolicies", 20)), int(spec.get("minimumRuns", 400))


def _lean_thick(row: dict[str, Any], axes: dict[str, Any]) -> tuple[str, str]:
    from balance_f0 import lean_and_thick
    return lean_and_thick(row, axes)


def _valid_cells(cells: dict[str, dict[str, Any]], contract: dict[str, Any],
                 grid: str) -> list[tuple[str, dict[str, Any]]]:
    policies, runs = _validity(contract)
    ranked: list[tuple[str, dict[str, Any]]] = []
    for lean in TIE:
        for thick in THICK:
            name = f"{lean}:{thick}"
            cell = cells.get(f"{grid}:{name}", {"policies": 0, "runs": 0, "winRate": 0.0})
            if cell_is_valid(cell, policies, runs):
                ranked.append((name, cell))
    ranked.sort(key=lambda item: (
        -float(item[1].get("winRate") or 0.0),
        TIE.index(item[0].split(":")[0]),
        THICK.index(item[0].split(":")[1]),
    ))
    return ranked


def rank_gaps(cells: dict[str, dict[str, Any]], contract: dict[str, Any]) -> dict[str, Any]:
    out: dict[str, Any] = {}
    for grid in GRIDS:
        ranked = _valid_cells(cells, contract, grid)
        rates = [float(cell["winRate"]) for _name, cell in ranked]

        def _at(index: int) -> float | None:
            return rates[index] if len(rates) > index else None

        top, third, fourth = _at(0), _at(2), _at(3)
        out[grid] = {
            "topRate": top, "thirdRate": third, "fourthRate": fourth,
            "topToThird": None if top is None or third is None else top - third,
            "topToFourth": None if top is None or fourth is None else top - fourth,
            "topCell": ranked[0][0] if ranked else None,
        }
    return out


def occupied_valid_cells(cells: dict[str, dict[str, Any]],
                         contract: dict[str, Any]) -> dict[str, int]:
    return {grid: len(_valid_cells(cells, contract, grid)) for grid in GRIDS}


def deck_bands(rows: list[dict[str, Any]], axes: dict[str, Any]) -> dict[str, Any]:
    buckets: dict[tuple[str, str], dict[str, Any]] = defaultdict(
        lambda: {"wins": 0, "runs": 0, "policies": set()})
    for row in rows:
        if "policyIndex" not in row:
            continue
        _lean, thick = _lean_thick(row, axes)
        key = (_grid(str(row["aspect"]), int(row["vow"])), thick)
        bucket = buckets[key]
        bucket["runs"] += 1
        if row.get("outcome") == "win":
            bucket["wins"] += 1
        bucket["policies"].add(int(row["policyIndex"]))
    out: dict[str, Any] = {}
    for grid in GRIDS:
        bands: dict[str, Any] = {}
        for thick in THICK:
            bucket = buckets[(grid, thick)]
            runs = int(bucket["runs"])
            wins = int(bucket["wins"])
            bands[thick] = {
                "distinctPolicies": len(bucket["policies"]),
                "runs": runs, "wins": wins, "winRate": _rate(wins, runs),
            }
        out[grid] = bands
    return out


def final_deck_size(rows: list[dict[str, Any]]) -> dict[str, Any]:
    groups: dict[str, list[int]] = defaultdict(list)
    for row in rows:
        if "policyIndex" not in row:
            continue
        groups[_grid(str(row["aspect"]), int(row["vow"]))].append(int(row.get("deck") or 0))
    out: dict[str, Any] = {}
    for grid in GRIDS:
        values = groups.get(grid, [])
        dist: dict[str, int] = {}
        for size in values:
            key = str(size)
            dist[key] = dist.get(key, 0) + 1
        n = len(values)
        entropy = 0.0
        if n:
            entropy = -sum((count / n) * math.log2(count / n) for count in dist.values() if count)
        out[grid] = {
            "distribution": dist, "observations": n,
            "min": min(values) if values else None,
            "max": max(values) if values else None,
            "mean": (sum(values) / n) if n else None,
            "entropy": entropy,
        }
    return out


def package_diagnostics(rows: list[dict[str, Any]], contract: dict[str, Any]) -> dict[str, Any]:
    packages = contract["packageDiagnostics"]["packages"]
    out: dict[str, Any] = {}
    for name, spec in packages.items():
        eligible_aspects = set(spec["eligibleAspects"])
        exposure_keys = list(spec["exposureEvents"])
        use_keys = list(spec["useEvents"])
        event_keys = exposure_keys + [key for key in use_keys if key not in exposure_keys]
        by_grid: dict[str, Any] = {}
        for grid in GRIDS:
            aspect, vow_text = grid.split(":v")
            eligible = [row for row in rows
                        if str(row.get("aspect")) == aspect
                        and int(row.get("vow", -1)) == int(vow_text)
                        and aspect in eligible_aspects]
            events = {key: 0 for key in event_keys}
            exposed_runs = used_runs = 0
            for row in eligible:
                counts = row.get("packageEvents") or {}
                for key in event_keys:
                    events[key] += int(counts.get(key, 0) or 0)
                exposed = any(int((counts.get(key, 0) or 0)) > 0 for key in exposure_keys)
                used = exposed and any(int((counts.get(key, 0) or 0)) > 0 for key in use_keys)
                exposed_runs += int(exposed)
                used_runs += int(used)
            eligible_n = len(eligible)
            if eligible_n == 0:
                reach = "not-applicable"
            elif exposed_runs == 0:
                reach = "unreachable"
            else:
                reach = "reached"
            by_grid[grid] = {
                "eligibleRuns": eligible_n,
                "exposedRuns": exposed_runs,
                "usedRuns": used_runs,
                "exposureRate": _rate(exposed_runs, eligible_n),
                "useRate": _rate(used_runs, exposed_runs),
                "mechanismFired": used_runs > 0,
                "reachability": reach,
                "events": events,
            }
        out[name] = by_grid
    return out


def valid_proxies(controls: dict[str, dict[str, Any]], cells: dict[str, dict[str, Any]],
                  contract: dict[str, Any]) -> dict[str, Any]:
    gaps = rank_gaps(cells, contract)
    out: dict[str, Any] = {}
    for grid in GRIDS:
        ranked = _valid_cells(cells, contract, grid)
        aspect, vow_text = grid.split(":v")
        arm2 = controls.get(f"2:{aspect}:v{vow_text}", {"winRate": 0.0, "wins": 0, "runs": 0})
        top_rate = gaps[grid]["topRate"]
        floor = None if top_rate is None else (float(arm2.get("winRate") or 0.0) + top_rate) / 2
        within = sum(1 for _name, cell in ranked
                     if top_rate is not None and float(cell["winRate"]) >= top_rate - 0.10)
        viable = sum(1 for _name, cell in ranked
                     if floor is not None and float(cell["winRate"]) >= floor)
        out[grid] = {
            "topCell": gaps[grid]["topCell"],
            "topRate": top_rate,
            "thirdRate": gaps[grid]["thirdRate"],
            "fourthRate": gaps[grid]["fourthRate"],
            "within10": within,
            "viable": viable,
            "arm2Rate": float(arm2.get("winRate") or 0.0),
            "margin": None if top_rate is None else top_rate - float(arm2.get("winRate") or 0.0),
            "occupiedValidCells": len(ranked),
        }
    return out


def breadth_metric(within10: int, viable: int) -> float:
    return max(0.0, 3 - within10) / 3.0 + max(0.0, 4 - viable) / 4.0


def valid_c1(valid: dict[str, Any]) -> dict[str, float]:
    c1a = c1b = 0.0
    per: dict[str, float] = {}
    for grid in GRIDS:
        proxy = valid[grid]
        value = breadth_metric(int(proxy["within10"]), int(proxy["viable"]))
        per[grid] = value
        c1a += max(0.0, 3 - int(proxy["within10"])) / 3.0
        c1b += max(0.0, 4 - int(proxy["viable"])) / 4.0
    return {"c1a": c1a, "c1b": c1b, "sum": c1a + c1b, **{f"grid:{grid}": per[grid] for grid in GRIDS}}


def identity_load(content: dict[str, Any]) -> dict[str, bool]:
    cards = content.get("cards", {})

    def _status(card_id: str, status: str) -> bool:
        card = cards.get(card_id) or {}
        return any(str(fx.get("id", "")) == status
                   for fx in card.get("effects") or [] if isinstance(fx, dict))

    def _chip(card_id: str) -> bool:
        card = cards.get(card_id) or {}
        return int(card.get("chip", 0) or 0) > 0 or any(
            str(fx.get("kind", "")) == "chip" for fx in card.get("effects") or []
            if isinstance(fx, dict))

    dusk_starters = ("strike", "eclipseSlash", "chisel")
    ash_starters = ("ashBite", "smother")
    return {
        "duskblade:shatter-enabled": _status("eclipseSlash", "vulnerable") or _chip("chisel"),
        "duskblade:smolder-application-blocked": not any(
            _status(card_id, "poison") for card_id in dusk_starters),
        "ashwarden:shatter-blocked": not any(_chip(card_id) for card_id in ash_starters),
        "ashwarden:smolder-enabled": _status("ashBite", "poison"),
    }


def _identity_observation(control_rows: list[dict[str, Any]],
                          valid: dict[str, Any], strict: bool = False) -> str:
    paired: dict[tuple[Any, ...], dict[str, str]] = {}
    for row in control_rows:
        if int(row.get("arm", 0)) not in (1, 2):
            continue
        key = (int(row["arm"]), int(row["vow"]), int(row["seed"]))
        paired.setdefault(key, {})[str(row["aspect"])] = str(row["outcome"])
    if paired and all(pair.get("duskblade") == pair.get("ashwarden") and len(pair) == 2
                      for pair in paired.values()):
        return "identity-collapse"
    for vow in VOWS:
        dusk = str(valid[_grid("duskblade", vow)].get("topCell") or "")
        ash = str(valid[_grid("ashwarden", vow)].get("topCell") or "")
        if strict and not dusk.startswith("shatter"):
            return f"dusk-not-shatter-led:v{vow}"
        if strict and not ash.startswith("smolder"):
            return f"ash-not-smolder-led:v{vow}"
        if dusk.startswith("smolder") and ash.startswith("shatter"):
            return "identity-reversal"
    return ""


def guardrails(result: dict[str, Any], contract: dict[str, Any],
               load_rules: dict[str, bool], strict: bool = False) -> dict[str, Any]:
    proxies = result["proxies"]
    valid = result["validProxies"]
    c2_by: dict[str, bool] = {}
    c2_ok = True
    for grid in GRIDS:
        proxy = proxies[grid]
        ok = float(proxy["arm2Rate"]) < 0.5 and float(proxy["margin"]) >= 0.35
        c2_by[grid] = ok
        c2_ok = c2_ok and ok
    vow5_by: dict[str, bool | None] = {}
    vow5_ok = True
    for grid in ("duskblade:v5", "ashwarden:v5"):
        rate = valid[grid]["topRate"]
        ok = rate is not None and (float(rate) < 0.9 if strict else float(rate) <= 0.9)
        vow5_by[grid] = ok
        vow5_ok = vow5_ok and ok
    # #492's stronger identity bar is aspect-level, so it follows the best observed
    # all-cell route. The valid-cell floor can be empty or contain only populated
    # loss buckets at early racing fidelity and is not an identity observation.
    identity_proxies = proxies if strict else valid
    fault = _identity_observation(result.get("_controlRows") or [], identity_proxies, strict)
    identity_ok = all(load_rules.values()) and not fault
    reasons: list[str] = []
    if not c2_ok:
        reasons.append(REASON["c2"])
    if not identity_ok:
        reasons.append(REASON["identity"])
    if not vow5_ok:
        reasons.append(REASON["vow5"])
    return {
        "clear": c2_ok and identity_ok and vow5_ok,
        "byGrid": {"c2": c2_by, "vow5Proxy": vow5_by},
        "identity": {"loadRules": load_rules, "observationFault": fault or None,
                     "clear": identity_ok},
        "reasons": reasons,
    }


def _interval_excludes_zero(interval: dict[str, float]) -> bool:
    return float(interval["p975"]) < 0.0 or float(interval["p025"]) > 0.0


def decide(result: dict[str, Any], baseline: dict[str, Any] | None,
           effects: dict[str, Any], contract: dict[str, Any]) -> dict[str, Any]:
    reasons: list[str] = []
    guards = result.get("guardrails") or {"clear": False, "reasons": [REASON["simulator"]]}
    valid = result.get("validProxies") or {}
    simulator_clear = int(result.get("controlErrors") or 0) == 0 \
        and int(result.get("landscapeErrors") or 0) == 0
    if baseline is not None:
        simulator_clear = simulator_clear \
            and int(result.get("controlStalls") or 0) <= int(baseline.get("controlStalls") or 0) \
            and int(result.get("landscapeStalls") or 0) <= int(baseline.get("landscapeStalls") or 0)
    if not simulator_clear:
        reasons.append(REASON["simulator"])
    if not guards.get("clear"):
        reasons.extend(reason for reason in guards.get("reasons", []) if reason not in reasons)

    values = result.get("values") or {}
    diagnostics = result.get("packageDiagnostics") or {}
    credited: list[str] = []
    for name, spec in contract["packageDiagnostics"]["packages"].items():
        if values.get(name) == "s009":
            continue
        fired = any(grid["mechanismFired"] for grid in diagnostics.get(name, {}).values())
        effect = (effects.get(name) or {}).get(
            "highVsS009" if values.get(name) == "high" else "lowVsS009")
        if fired and isinstance(effect, dict) and _interval_excludes_zero(effect) \
                and float(effect["p975"]) < 0.0:
            credited.append(name)
    mechanism_ok = bool(credited)
    if not mechanism_ok:
        fired = any(
            values.get(name) != "s009" and any(
                grid.get("mechanismFired") for grid in (diagnostics.get(name) or {}).values())
            for name in values)
        reasons.append(REASON["effect"] if fired else REASON["mechanism"])

    vs = ((result.get("bootstrap") or {}).get("vsBaseline") or {}).get("breadth") or {}
    improved: dict[str, bool] = {}
    for grid in GRIDS:
        interval = vs.get(grid) or {}
        cand = valid.get(grid) or {"within10": 0, "viable": 0}
        base = ((baseline or {}).get("validProxies") or {}).get(grid) or cand
        point = int(cand["within10"]) > int(base.get("within10", 0)) \
            or int(cand["viable"]) > int(base.get("viable", 0))
        ub = interval.get("p975")
        improved[grid] = bool(point and ub is not None and float(ub) < 0.0)
    dusk_ok = improved["duskblade:v0"] or improved["duskblade:v5"]
    ash_ok = improved["ashwarden:v0"] or improved["ashwarden:v5"]
    both = dusk_ok and ash_ok
    aspect_exception = False
    if (dusk_ok ^ ash_ok) and credited:
        improved_aspect = "duskblade" if dusk_ok else "ashwarden"
        aspect_exception = any(
            contract["packageDiagnostics"]["packages"][name]["eligibleAspects"] == [improved_aspect]
            for name in credited)
    breadth_clear = both or aspect_exception
    if not breadth_clear:
        reasons.append(REASON["breadth"])

    eligible = guards.get("clear") and simulator_clear and mechanism_ok and breadth_clear
    return {
        "eligible": bool(eligible),
        "reasons": reasons,
        "creditedPackages": credited,
        "breadthBothAspects": both,
        "aspectSpecificException": aspect_exception,
        "breadthClear": breadth_clear,
        "simulatorClear": simulator_clear,
        "gridImprovement": improved,
    }


def package_effects(candidates: list[dict[str, Any]], features: list[str],
                    n_boot: int, rng_seed: int) -> dict[str, Any]:
    complete = [row for row in candidates if row.get("status") == "complete"
                and isinstance(row.get("values"), dict)]
    rng = random.Random(rng_seed)
    out: dict[str, Any] = {}
    if not complete:
        return out
    for feature in features:
        samples = {level: [] for level in ("low", "s009", "high")}
        for _ in range(n_boot):
            draw = [complete[rng.randrange(len(complete))] for _ in complete]
            grouped: dict[str, list[float]] = defaultdict(list)
            for row in draw:
                grouped[str(row["values"].get(feature, "s009"))].append(
                    float(row.get("validBreadthSum", (row.get("deficits") or {}).get("sum", 0.0))))
            means = {level: (sum(vals) / len(vals) if vals else 0.0)
                     for level, vals in grouped.items()}
            samples["low"].append(means.get("low", 0.0) - means.get("s009", 0.0))
            samples["high"].append(means.get("high", 0.0) - means.get("s009", 0.0))
        out[feature] = {
            "lowVsS009": _interval(samples["low"]),
            "highVsS009": _interval(samples["high"]),
        }
    return out


def pairwise_effects(candidates: list[dict[str, Any]], features: list[str],
                     n_boot: int, rng_seed: int) -> list[dict[str, Any]]:
    complete = [row for row in candidates if row.get("status") == "complete"
                and isinstance(row.get("values"), dict)]
    rng = random.Random(rng_seed)
    out: list[dict[str, Any]] = []
    if not complete:
        return out
    for i, left in enumerate(features):
        for right in features[i + 1:]:
            samples: list[float] = []
            for _ in range(n_boot):
                draw = [complete[rng.randrange(len(complete))] for _ in complete]
                cells: dict[tuple[str, str], list[float]] = defaultdict(list)
                for row in draw:
                    cells[(str(row["values"].get(left, "s009")),
                           str(row["values"].get(right, "s009")))].append(
                        float(row.get("validBreadthSum",
                                      (row.get("deficits") or {}).get("sum", 0.0))))

                def mean(a: str, b: str) -> float:
                    vals = cells.get((a, b), [])
                    return sum(vals) / len(vals) if vals else 0.0

                samples.append(mean("high", "high") - mean("high", "s009")
                               - mean("s009", "high") + mean("s009", "s009"))
            interval = _interval(samples)
            out.append({"left": left, "right": right, "highHighInteraction": interval,
                        "excludesZero": _interval_excludes_zero(interval)})
    return out


def _interval(values: list[float]) -> dict[str, float]:
    if not values:
        return {"p025": 0.0, "p50": 0.0, "p975": 0.0}
    ordered = sorted(values)
    def pct(p: float) -> float:
        index = min(len(ordered) - 1, max(0, int(round((p / 100) * (len(ordered) - 1)))))
        return ordered[index]
    return {"p025": pct(2.5), "p50": pct(50), "p975": pct(97.5)}


def occupancy_deficits(bands: dict[str, Any]) -> dict[str, float]:
    thin = mid = 0.0
    for grid in GRIDS:
        if int(bands[grid]["thin"]["runs"]) == 0:
            thin += 1.0
        if int(bands[grid]["mid"]["runs"]) == 0:
            mid += 1.0
    return {"thin": thin, "mid": mid}


def breadth_pareto(candidates: list[dict[str, Any]]) -> list[str]:
    eligible = [row for row in candidates
                if row.get("status") == "complete" and not row.get("earlyStop")
                and (row.get("guardrails") or {}).get("clear")
                and (row.get("decision") or {}).get("simulatorClear")]
    keys = ("validC1a", "validC1b", "thinDeficit", "midDeficit")
    keep: list[str] = []
    for row in eligible:
        dominated = any(all(float(other[key]) <= float(row[key]) for key in keys)
                        and any(float(other[key]) < float(row[key]) for key in keys)
                        for other in eligible if other["id"] != row["id"])
        if not dominated:
            keep.append(row["id"])
    return keep


def attach_tier1_fields(result: dict[str, Any], axes: dict[str, Any],
                        contract: dict[str, Any], load_rules: dict[str, bool],
                        landscape_rows: list[dict[str, Any]] | None = None,
                        control_rows: list[dict[str, Any]] | None = None,
                        strict: bool = False) -> dict[str, Any]:
    landscape = landscape_rows if landscape_rows is not None else result.get("_landscapeRows") or []
    controls = control_rows if control_rows is not None else result.get("_controlRows") or []
    result["_controlRows"] = controls
    result["deckBands"] = deck_bands(landscape, axes)
    result["rankGaps"] = rank_gaps(result.get("cells") or {}, contract)
    result["occupiedValidCells"] = occupied_valid_cells(result.get("cells") or {}, contract)
    result["finalDeckSize"] = final_deck_size(landscape)
    # Explicit raw inputs are a provenance boundary: never retain derived summary evidence.
    if landscape_rows is not None or control_rows is not None:
        result["packageDiagnostics"] = package_diagnostics(controls + landscape, contract)
    else:
        result["packageDiagnostics"] = result.get("packageDiagnostics") or package_diagnostics(
            controls + landscape, contract)
    result["validProxies"] = valid_proxies(result.get("controls") or {},
                                           result.get("cells") or {}, contract)
    c1 = valid_c1(result["validProxies"])
    result["validC1a"] = c1["c1a"]
    result["validC1b"] = c1["c1b"]
    result["validBreadthSum"] = c1["sum"]
    occ = occupancy_deficits(result["deckBands"])
    result["thinDeficit"] = occ["thin"]
    result["midDeficit"] = occ["mid"]
    result["guardrails"] = guardrails(result, contract, load_rules, strict)
    return result


def bootstrap_breadth(control: dict[int, list[dict[str, Any]]],
                      landscape: dict[int, list[dict[str, Any]]],
                      baseline_control: dict[int, list[dict[str, Any]]] | None,
                      baseline_landscape: dict[int, list[dict[str, Any]]] | None,
                      axes: dict[str, Any], contract: dict[str, Any],
                      cells: dict[str, dict[str, Any]],
                      n_boot: int, rng_seed: int,
                      baseline_cells: dict[str, dict[str, Any]] | None = None) -> dict[str, Any]:
    """Seed-block bootstrap of valid-cell breadth. Policy occupancy is frozen."""
    rng = random.Random(rng_seed)
    c_ids, l_ids = sorted(control), sorted(landscape)
    policies: dict[str, int] = {
        key: int(cell.get("policies", 0)) for key, cell in cells.items()
    }
    baseline_policies: dict[str, int] = {
        key: int(cell.get("policies", 0)) for key, cell in (baseline_cells or cells).items()
    }

    def _tally(rows: list[dict[str, Any]], kind: str) -> dict[tuple[Any, ...], dict[str, int]]:
        buckets: dict[tuple[Any, ...], dict[str, int]] = defaultdict(
            lambda: {"wins": 0, "runs": 0, "stalls": 0, "errors": 0})
        for row in rows:
            if kind == "control":
                key: tuple[Any, ...] = (int(row["arm"]), str(row["aspect"]), int(row["vow"]))
            else:
                key = (str(row["aspect"]), int(row["vow"]), *_lean_thick(row, axes))
            bucket = buckets[key]
            bucket["runs"] += 1
            outcome = str(row.get("outcome", ""))
            if outcome == "win":
                bucket["wins"] += 1
            elif outcome == "stall":
                bucket["stalls"] += 1
            elif outcome == "error":
                bucket["errors"] += 1
        return buckets

    def _seed_map(grouped: dict[int, list[dict[str, Any]]], kind: str) \
            -> dict[int, dict[tuple[Any, ...], dict[str, int]]]:
        return {seed: _tally(rows, kind) for seed, rows in grouped.items()}

    def _combine(seed_tallies: dict[int, dict[tuple[Any, ...], dict[str, int]]],
                 ids: list[int]) -> dict[tuple[Any, ...], dict[str, int]]:
        combined: dict[tuple[Any, ...], dict[str, int]] = defaultdict(
            lambda: {"wins": 0, "runs": 0, "stalls": 0, "errors": 0})
        for seed in ids:
            for key, values in seed_tallies[seed].items():
                for field in ("wins", "runs", "stalls", "errors"):
                    combined[key][field] += values[field]
        return combined

    def _cell_dict(tallies: dict[tuple[Any, ...], dict[str, int]],
                   policy_counts: dict[str, int]) -> dict[str, dict[str, Any]]:
        out: dict[str, dict[str, Any]] = {}
        for aspect in ASPECTS:
            for vow in VOWS:
                for lean in TIE:
                    for thick in THICK:
                        key = (aspect, vow, lean, thick)
                        stats = tallies.get(key, {"wins": 0, "runs": 0, "stalls": 0, "errors": 0})
                        runs = int(stats["runs"])
                        wins = int(stats["wins"])
                        name = f"{aspect}:v{vow}:{lean}:{thick}"
                        out[name] = {
                            "wins": wins, "runs": runs,
                            "stalls": int(stats["stalls"]), "errors": int(stats["errors"]),
                            "winRate": (wins / runs) if runs else 0.0,
                            "policies": int(policy_counts.get(name, 0)),
                        }
        return out

    c_t = _seed_map(control, "control")
    l_t = _seed_map(landscape, "landscape")
    b_c = _seed_map(baseline_control, "control") if baseline_control is not None else None
    b_l = _seed_map(baseline_landscape, "landscape") if baseline_landscape is not None else None
    acc: dict[str, list[float]] = defaultdict(list)
    vs: dict[str, list[float]] = defaultdict(list)
    for _ in range(n_boot):
        c_draw = [rng.choice(c_ids) for _ in c_ids] if c_ids else []
        l_draw = [rng.choice(l_ids) for _ in l_ids] if l_ids else []
        control_tbl = _combine(c_t, c_draw)
        controls = {}
        for arm in (1, 2):
            for aspect in ASPECTS:
                for vow in VOWS:
                    stats = control_tbl.get((arm, aspect, vow),
                                            {"wins": 0, "runs": 0, "stalls": 0, "errors": 0})
                    runs = int(stats["runs"])
                    wins = int(stats["wins"])
                    controls[f"{arm}:{aspect}:v{vow}"] = {
                        "wins": wins, "runs": runs, "stalls": int(stats["stalls"]),
                        "errors": int(stats["errors"]),
                        "winRate": (wins / runs) if runs else 0.0,
                    }
        cand_cells = _cell_dict(_combine(l_t, l_draw), policies)
        cand_valid = valid_proxies(controls, cand_cells, contract)
        cand_c1 = valid_c1(cand_valid)
        for grid in GRIDS:
            acc[f"{grid}:breadth"].append(float(cand_c1[f"grid:{grid}"]))
            acc[f"{grid}:within10"].append(float(cand_valid[grid]["within10"]))
            acc[f"{grid}:viable"].append(float(cand_valid[grid]["viable"]))
        acc["c1a"].append(float(cand_c1["c1a"]))
        acc["c1b"].append(float(cand_c1["c1b"]))
        acc["sum"].append(float(cand_c1["sum"]))
        if b_c is not None and b_l is not None:
            base_tbl = _combine(b_c, c_draw)
            base_controls = {}
            for arm in (1, 2):
                for aspect in ASPECTS:
                    for vow in VOWS:
                        stats = base_tbl.get((arm, aspect, vow),
                                             {"wins": 0, "runs": 0, "stalls": 0, "errors": 0})
                        runs = int(stats["runs"])
                        wins = int(stats["wins"])
                        base_controls[f"{arm}:{aspect}:v{vow}"] = {
                            "wins": wins, "runs": runs, "stalls": int(stats["stalls"]),
                            "errors": int(stats["errors"]),
                            "winRate": (wins / runs) if runs else 0.0,
                        }
            base_cells = _cell_dict(_combine(b_l, l_draw), baseline_policies)
            base_valid = valid_proxies(base_controls, base_cells, contract)
            base_c1 = valid_c1(base_valid)
            vs["c1a"].append(float(cand_c1["c1a"] - base_c1["c1a"]))
            vs["c1b"].append(float(cand_c1["c1b"] - base_c1["c1b"]))
            vs["sum"].append(float(cand_c1["sum"] - base_c1["sum"]))
            for grid in GRIDS:
                vs[grid].append(float(cand_c1[f"grid:{grid}"] - base_c1[f"grid:{grid}"]))
    result: dict[str, Any] = {
        "nBoot": n_boot,
        "breadth": {grid: _interval(acc[f"{grid}:breadth"]) for grid in GRIDS},
        "within10": {grid: _interval(acc[f"{grid}:within10"]) for grid in GRIDS},
        "viable": {grid: _interval(acc[f"{grid}:viable"]) for grid in GRIDS},
        "c1": {key: _interval(acc[key]) for key in ("c1a", "c1b")},
        "sum": _interval(acc["sum"]),
    }
    if vs:
        result["vsBaseline"] = {
            "c1": {key: _interval(vs[key]) for key in ("c1a", "c1b")},
            "breadth": {grid: _interval(vs[grid]) for grid in GRIDS},
            "sum": _interval(vs["sum"]),
        }
    return result
