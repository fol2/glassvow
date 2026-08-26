#!/usr/bin/env python3
"""#503 disruption-profile fields on the existing F0 evaluator.

Reuses frozen #490/#215 valid-cell/identity/C2 fields and generic F0 tallies.
Adds profile diagnostics, factorial contrasts and racingSet.
Never emits C1-C4 PASS/FAIL labels.
"""
import random
from collections import defaultdict
from itertools import combinations
from typing import Any

from balance_f0_tier1 import (
    ASPECTS, GRIDS, THICK, TIE, VOWS, attach_tier1_fields,
    deck_bands, rank_gaps, valid_c1, valid_proxies,
)
from balance_seed_contract import REPO, read_json

KNOBS = ("blockMitigation", "blockTempoTrade", "disruptionIntensity", "disruptionTempoTrade")
LINEAR = {"low": -1, "baseline": 0, "high": 1}
QUADRATIC = {"low": 1, "baseline": -2, "high": 1}
PAIRS = {"block": ("gravewarden", "shellback"), "disruption": ("waylayer", "watcherEye")}
ALLOWED_STATUS = {"poison", "weak", "frail", "vulnerable"}
INTENSITY_AMOUNT = {"low": 1, "baseline": 2, "high": 3}
FIXED_AMOUNT = {("gravewarden", "entomb", "frail"): 2,
                ("gravewarden", "entomb", "vulnerable"): 2}
PAIR_CONDITIONS = (
    "encountered-block-pair", "encountered-disruption-pair",
    "encountered-both-pairs", "encountered-neither-pair")
_TERMS = ("linear", "quadratic")
PAIR_TERMS = [(left, right, f"{left}:{right}") for left in _TERMS for right in _TERMS]
CONTRACT_PAIRS = list(combinations(KNOBS, 2))
RESPONSES = (
    "c1aProxy", "c1bProxy", "topToThird", "topToFourth",
    "thinOccupancyRate", "thinWinRate", "midOccupancyRate", "midWinRate",
    "fatOccupancyRate", "fatWinRate", "profileFiringRate", "conditionalPairWinRate",
    "c2Gap", "aspectIdentity", "vow5Proxy", "stalls", "errors")
REASON = {
    "breadth": "breadth-not-credible", "aspect": "one-aspect-only",
    "thin": "thin-mid-not-strengthened", "global": "global-difficulty-only",
    "simulator": "simulator-fault", "unreachable": "profile-unreachable",
    "attribution": "profile-attribution-failed"}

def contrast_weight(term: str, level: str) -> int:
    return int((LINEAR if term == "linear" else QUADRATIC)[level])

def authored_amount(vector: dict[str, str], enemy: str, move: str, status: str) -> int | None:
    keyed = (enemy, move, status)
    if keyed in FIXED_AMOUNT:
        return FIXED_AMOUNT[keyed]
    if keyed in (("waylayer", "trick", "frail"), ("watcherEye", "gaze", "vulnerable")):
        return INTENSITY_AMOUNT[str(vector.get("disruptionIntensity", "baseline"))]
    return None

def occupancy_rate_bands(rows: list[dict[str, Any]], axes: dict[str, Any]) -> dict[str, Any]:
    bands = deck_bands(rows, axes)
    for grid_bands in bands.values():
        total = sum(int(grid_bands[thick]["runs"]) for thick in THICK)
        for thick in THICK:
            runs = int(grid_bands[thick]["runs"])
            grid_bands[thick]["occupancyRate"] = (runs / total) if total else None
    return bands

def _merge_profile(rows: list[dict[str, Any]]) -> dict[str, Any]:
    encounters: dict[str, int] = defaultdict(int)
    moves: dict[str, dict[str, int]] = defaultdict(lambda: defaultdict(int))
    counts = {"block": 0, "heal": 0, "disruption": 0, "tempo": 0,
              "fightN": 0, "turns": 0, "hpLost": 0}
    shatters = smolder = 0.0
    events: list[dict[str, Any]] = []
    for row in rows:
        for fight in [item for item in (row.get("fights") or []) if isinstance(item, dict)]:
            counts["fightN"] += 1
            counts["turns"] += int(fight.get("turns") or 0)
            counts["hpLost"] += int(fight.get("hpLost") or 0)
            shatters += float(fight.get("shatters") or 0)
            smolder += float(fight.get("smolderKills") or 0)
            diag = fight.get("profileDiagnostics") or {}
            for enemy, count in (diag.get("encounters") or {}).items():
                encounters[str(enemy)] += int(count or 0)
            for enemy, by_move in (diag.get("moves") or {}).items():
                for move, count in (by_move or {}).items():
                    moves[str(enemy)][str(move)] += int(count or 0)
            for key in ("block", "heal", "disruption", "tempo"):
                counts[key] += len(diag.get(key) or [])
            events.extend(diag.get("disruption") or [])
    return {
        "encounters": dict(encounters),
        "moves": {enemy: dict(by_move) for enemy, by_move in moves.items()},
        "blockEvents": counts["block"], "healEvents": counts["heal"],
        "disruptionEvents": counts["disruption"], "tempoEvents": counts["tempo"],
        "fightN": counts["fightN"], "turns": counts["turns"], "hpLost": counts["hpLost"],
        "shatters": shatters, "smolderKills": smolder, "disruption": events,
    }

def _pair_hit(encounters: dict[str, int], pair: str) -> bool:
    return any(int(encounters.get(enemy, 0) or 0) > 0 for enemy in PAIRS[pair])

def _pair_fired(moves: dict[str, dict[str, int]], pair: str) -> bool:
    return any(any(int(c) > 0 for c in (moves.get(e) or {}).values()) for e in PAIRS[pair])

def _row_profile(row: dict[str, Any]) -> dict[str, Any]:
    merged = _merge_profile([row])
    block = _pair_hit(merged["encounters"], "block")
    disruption = _pair_hit(merged["encounters"], "disruption")
    fired = (block and _pair_fired(merged["moves"], "block")) \
        or (disruption and _pair_fired(merged["moves"], "disruption"))
    cond = ("encountered-both-pairs" if block and disruption else
            "encountered-block-pair" if block else
            "encountered-disruption-pair" if disruption else
            "encountered-neither-pair")
    merged.update({"exposed": block or disruption, "fired": fired,
                   "both": block and disruption, "cond": cond})
    return merged

def profile_attribution_fault(rows: list[dict[str, Any]],
                              vector: dict[str, str] | None = None) -> str:
    for row in rows:
        for fight in [item for item in (row.get("fights") or []) if isinstance(item, dict)]:
            for event in (fight.get("profileDiagnostics") or {}).get("disruption") or []:
                if not isinstance(event, dict) \
                        or str(event.get("target", "")) != "player" \
                        or str(event.get("status", "")) not in ALLOWED_STATUS:
                    return "profile-attribution-failed"
                if vector is not None:
                    expected = authored_amount(
                        vector, str(event.get("enemy", "")), str(event.get("move", "")),
                        str(event.get("status", "")))
                    if expected is not None and int(event.get("amount") or 0) != expected:
                        return "profile-attribution-failed"
    return ""

def _profile_tables(rows: list[dict[str, Any]]) -> tuple[dict[str, Any], dict[str, Any]]:
    flagged = [(row, _row_profile(row)) for row in rows]
    diag: dict[str, Any] = {}
    cond: dict[str, Any] = {}
    for grid in GRIDS:
        aspect, vow_text = grid.split(":v")
        items = [(row, flags) for row, flags in flagged
                 if str(row.get("aspect")) == aspect
                 and int(row.get("vow", -1)) == int(vow_text)]
        merged = _merge_profile([row for row, _flags in items])
        eligible = len(items)
        reach = {}
        for pair in PAIRS:
            pair_exposed = sum(1 for _row, flags in items
                               if _pair_hit(flags["encounters"], pair))
            reach[pair] = ("not-applicable" if eligible == 0
                           else "unreachable" if pair_exposed == 0 else "reached")
        exposed_runs = sum(int(flags["exposed"]) for _row, flags in items)
        fired_runs = sum(int(flags["fired"]) for _row, flags in items)
        diag[grid] = {
            "eligibleRuns": eligible, "exposedRuns": exposed_runs, "firedRuns": fired_runs,
            "encounters": merged["encounters"],
            "moveExecutions": sum(sum(by_move.values()) for by_move in merged["moves"].values()),
            "blockEvents": merged["blockEvents"], "healEvents": merged["healEvents"],
            "disruptionEvents": merged["disruptionEvents"], "tempoEvents": merged["tempoEvents"],
            "exposureRate": (exposed_runs / eligible) if eligible else None,
            "firingRate": (fired_runs / exposed_runs) if exposed_runs else None,
            "reachability": reach,
        }
        buckets: dict[str, list[dict[str, Any]]] = {name: [] for name in PAIR_CONDITIONS}
        for row, flags in items:
            buckets[flags["cond"]].append(row)
        by_cond: dict[str, Any] = {}
        for name, group in buckets.items():
            wins = sum(1 for row in group if row.get("outcome") == "win")
            stats = _merge_profile(group)
            n, fights = len(group), int(stats["fightN"])
            by_cond[name] = {
                "runs": n, "wins": wins, "winRate": (wins / n) if n else None,
                "meanFightTurns": (stats["turns"] / fights) if fights else None,
                "meanHpLost": (stats["hpLost"] / fights) if fights else None,
                "shattersPerFight": (stats["shatters"] / fights) if fights else None,
                "smolderKillsPerFight": (stats["smolderKills"] / fights) if fights else None,
            }
        cond[grid] = by_cond
    return diag, cond

def profile_diagnostics(rows: list[dict[str, Any]],
                        contract: dict[str, Any] | None = None) -> dict[str, Any]:
    del contract
    return _profile_tables(rows)[0]

def conditional_outcomes(rows: list[dict[str, Any]]) -> dict[str, Any]:
    return _profile_tables(rows)[1]

def _mean(values: list[float | None]) -> float | None:
    present = [float(value) for value in values if value is not None]
    return (sum(present) / len(present)) if present else None

def candidate_responses(result: dict[str, Any]) -> dict[str, float]:
    bands, gaps = result.get("deckBands") or {}, result.get("rankGaps") or {}
    proxies, diag = result.get("proxies") or {}, result.get("profileDiagnostics") or {}
    cond, guards = result.get("conditionalOutcomes") or {}, result.get("guardrails") or {}

    def band(field: str, thick: str) -> float:
        return float(_mean([(bands.get(grid) or {}).get(thick, {}).get(field)
                            for grid in GRIDS]) or 0.0)

    out = {
        "c1aProxy": float(result.get("validC1a") or 0.0),
        "c1bProxy": float(result.get("validC1b") or 0.0),
        "topToThird": float(_mean([(gaps.get(grid) or {}).get("topToThird") for grid in GRIDS]) or 0.0),
        "topToFourth": float(_mean([(gaps.get(grid) or {}).get("topToFourth") for grid in GRIDS]) or 0.0),
        "profileFiringRate": float(_mean([(diag.get(grid) or {}).get("firingRate")
                                          for grid in GRIDS]) or 0.0),
        "conditionalPairWinRate": float(_mean([
            ((cond.get(grid) or {}).get("encountered-both-pairs") or {}).get("winRate")
            for grid in GRIDS]) or 0.0),
        "c2Gap": float(_mean([(proxies.get(grid) or {}).get("margin") for grid in GRIDS]) or 0.0),
        "aspectIdentity": 1.0 if (guards.get("identity") or {}).get("clear") else 0.0,
        "vow5Proxy": 0.0 if any(str(reason).endswith("vow5-proxy-failed")
                                for reason in guards.get("reasons") or []) else 1.0,
        "stalls": float(int(result.get("controlStalls") or 0)
                        + int(result.get("landscapeStalls") or 0)),
        "errors": float(int(result.get("controlErrors") or 0)
                        + int(result.get("landscapeErrors") or 0)),
    }
    for thick in THICK:
        out[f"{thick}OccupancyRate"] = band("occupancyRate", thick)
        out[f"{thick}WinRate"] = band("winRate", thick)
    return out

def _term(weights: list[float], ys: list[float]) -> float:
    denom = sum(weight * weight for weight in weights)
    if denom == 0:
        return 0.0
    return sum(weight * value for weight, value in zip(weights, ys, strict=True)) / denom

def _effect_blob(samples: list[float], estimate: float | None = None) -> dict[str, Any]:
    from balance_f0 import _interval
    interval = _interval(samples)
    point = estimate if estimate is not None else interval["p50"]
    crosses = not (interval["p975"] < 0.0 or interval["p025"] > 0.0)
    return {"estimate": point, "p025": interval["p025"], "p975": interval["p975"],
            "crossesZero": crosses, "finding": (not crosses) and point != 0.0}

def _values(row: dict[str, Any]) -> dict[str, str]:
    return dict(row.get("values") or row.get("vector") or {})

def _response_of(row: dict[str, Any], name: str) -> float:
    return float((row.get("responses") or candidate_responses(row)).get(name) or 0.0)

def _knob_weights(rows: list[dict[str, Any]], knob: str, term: str) -> list[float]:
    return [float(contrast_weight(term, _values(row)[knob])) for row in rows]

def _pair_weights(rows: list[dict[str, Any]], left: str, right: str,
                  left_term: str, right_term: str) -> list[float]:
    return [float(contrast_weight(left_term, _values(row)[left])
                  * contrast_weight(right_term, _values(row)[right])) for row in rows]

def _empty_effects() -> dict[str, Any]:
    pairwise = {f"{left}:{right}": {label: {} for _lt, _rt, label in PAIR_TERMS}
                for left, right in CONTRACT_PAIRS}
    return {"main": {knob: {"linear": {}, "quadratic": {}} for knob in KNOBS},
            "pairwise": pairwise}

def _fill_effects(effects: dict[str, Any], complete: list[dict[str, Any]],
                  samples_main: dict[tuple[str, str, str], list[float]],
                  samples_pair: dict[tuple[str, str, str], list[float]]) -> dict[str, Any]:
    for response in RESPONSES:
        ys = [_response_of(row, response) for row in complete]
        for knob in KNOBS:
            for term in _TERMS:
                effects["main"][knob][term][response] = _effect_blob(
                    samples_main[(knob, term, response)],
                    _term(_knob_weights(complete, knob, term), ys))
        for left, right in CONTRACT_PAIRS:
            key = f"{left}:{right}"
            for left_term, right_term, label in PAIR_TERMS:
                effects["pairwise"][key][label][response] = _effect_blob(
                    samples_pair[(key, label, response)],
                    _term(_pair_weights(complete, left, right, left_term, right_term), ys))
    return effects

def _record_draw(rows: list[dict[str, Any]],
                 main_acc: dict[tuple[str, str, str], list[float]],
                 pair_acc: dict[tuple[str, str, str], list[float]]) -> None:
    for response in RESPONSES:
        ys = [_response_of(row, response) for row in rows]
        for knob in KNOBS:
            for term in _TERMS:
                main_acc[(knob, term, response)].append(
                    _term(_knob_weights(rows, knob, term), ys))
        for left, right in CONTRACT_PAIRS:
            for left_term, right_term, label in PAIR_TERMS:
                pair_acc[(f"{left}:{right}", label, response)].append(
                    _term(_pair_weights(rows, left, right, left_term, right_term), ys))

def _seed_cache(row: dict[str, Any], axes: dict[str, Any]) -> dict[str, Any]:
    from balance_f0 import _seed_tallies, by_seed, lean_and_thick
    landscape = row.get("_landscapeRows") or []
    l_grouped = by_seed(landscape)
    profile: dict[int, dict[str, dict[str, int]]] = {}
    for item in landscape:
        flags = _row_profile(item)
        bucket = profile.setdefault(int(item["seed"]), {}).setdefault(
            f"{item['aspect']}:v{item['vow']}",
            {"exposed": 0, "fired": 0, "both_runs": 0, "both_wins": 0})
        bucket["exposed"] += int(flags["exposed"])
        bucket["fired"] += int(flags["fired"])
        if flags["both"]:
            bucket["both_runs"] += 1
            bucket["both_wins"] += int(item.get("outcome") == "win")
    responses = candidate_responses(row)
    return {
        "c_t": _seed_tallies(by_seed(row.get("_controlRows") or []),
                             lambda item: (int(item["arm"]), str(item["aspect"]), int(item["vow"]))),
        "l_t": _seed_tallies(l_grouped, lambda item: (str(item["aspect"]), int(item["vow"]),
                                                      *lean_and_thick(item, axes))),
        "b_t": _seed_tallies(l_grouped, lambda item: (str(item["aspect"]), int(item["vow"]),
                                                      lean_and_thick(item, axes)[1])),
        "p_t": profile,
        "policies": {key: int(cell.get("policies") or 0)
                     for key, cell in (row.get("cells") or {}).items()},
        "flags": responses,
        "proxy": {"values": _values(row), "responses": responses, "status": "complete"},
    }

def _band_rate(bands: dict[Any, dict[str, int]], thick: str, field: str) -> float:
    values: list[float] = []
    for aspect in ASPECTS:
        for vow in VOWS:
            stats = bands.get((aspect, vow, thick), {"wins": 0, "runs": 0})
            runs = int(stats.get("runs") or 0)
            if field == "winRate":
                values.append((int(stats.get("wins") or 0) / runs) if runs else 0.0)
            else:
                total = sum(int(bands.get((aspect, vow, name), {}).get("runs") or 0)
                            for name in THICK)
                values.append((runs / total) if total else 0.0)
    return sum(values) / len(values) if values else 0.0

def _tally_sum(tallies: dict[int, dict[Any, dict[str, int]]], ids: list[int], field: str) -> int:
    return sum(int(stats.get(field) or 0)
               for seed in ids for stats in (tallies.get(seed) or {}).values())

def _responses_from_cache(cache: dict[str, Any], c_ids: list[int], l_ids: list[int],
                          contract: dict[str, Any]) -> dict[str, float]:
    from balance_f0 import (_cells_from_tallies, _combine_tallies, _controls_from_tallies,
                            grid_proxies)
    controls = _controls_from_tallies(_combine_tallies(cache["c_t"], c_ids))
    cells = _cells_from_tallies(_combine_tallies(cache["l_t"], l_ids))
    for name, cell in cells.items():
        cell["policies"] = int(cache["policies"].get(name, 0))
    proxies = grid_proxies(controls, cells)
    ranked = rank_gaps(cells, contract)
    c1 = valid_c1(valid_proxies(controls, cells, contract))
    bands = _combine_tallies(cache["b_t"], l_ids)
    exposed = fired = both_runs = both_wins = 0
    for seed in l_ids:
        for flags in (cache["p_t"].get(seed) or {}).values():
            exposed += int(flags.get("exposed") or 0)
            fired += int(flags.get("fired") or 0)
            both_runs += int(flags.get("both_runs") or 0)
            both_wins += int(flags.get("both_wins") or 0)
    frozen = cache["flags"]
    out = {
        "c1aProxy": float(c1["c1a"]), "c1bProxy": float(c1["c1b"]),
        "topToThird": float(_mean([ranked[grid].get("topToThird") for grid in GRIDS]) or 0.0),
        "topToFourth": float(_mean([ranked[grid].get("topToFourth") for grid in GRIDS]) or 0.0),
        "profileFiringRate": (fired / exposed) if exposed else 0.0,
        "conditionalPairWinRate": (both_wins / both_runs) if both_runs else 0.0,
        "c2Gap": float(_mean([proxies[grid].get("margin") for grid in GRIDS]) or 0.0),
        "aspectIdentity": float(frozen.get("aspectIdentity") or 0.0),
        "vow5Proxy": float(frozen.get("vow5Proxy") or 0.0),
        "stalls": float(_tally_sum(cache["c_t"], c_ids, "stalls")
                        + _tally_sum(cache["l_t"], l_ids, "stalls")),
        "errors": float(_tally_sum(cache["c_t"], c_ids, "errors")
                        + _tally_sum(cache["l_t"], l_ids, "errors")),
    }
    for thick in THICK:
        out[f"{thick}OccupancyRate"] = _band_rate(bands, thick, "occupancyRate")
        out[f"{thick}WinRate"] = _band_rate(bands, thick, "winRate")
    return out

def _seed_block_factorial(complete: list[dict[str, Any]], n_boot: int, rng_seed: int,
                          axes: dict[str, Any], rng: random.Random) -> dict[str, Any]:
    inherited = read_json(REPO / "docs/balance/490-f0-response-contract-v1.json")
    caches = [_seed_cache(row, axes) for row in complete]
    c_ids = sorted({int(item["seed"]) for row in complete
                    for item in row.get("_controlRows") or []})
    l_ids = sorted({int(item["seed"]) for row in complete
                    for item in row.get("_landscapeRows") or []})
    main_acc: dict[tuple[str, str, str], list[float]] = defaultdict(list)
    pair_acc: dict[tuple[str, str, str], list[float]] = defaultdict(list)
    for _ in range(n_boot):
        c_draw = [rng.choice(c_ids) for _ in c_ids] if c_ids else []
        l_draw = [rng.choice(l_ids) for _ in l_ids] if l_ids else []
        draw = [{"values": cache["proxy"]["values"], "status": "complete",
                 "responses": _responses_from_cache(cache, c_draw, l_draw, inherited)}
                for cache in caches]
        _record_draw(draw, main_acc, pair_acc)
    effects = _fill_effects(_empty_effects(), [cache["proxy"] for cache in caches],
                            main_acc, pair_acc)
    effects.update({"nBoot": n_boot, "rngSeed": rng_seed,
                    "method": "paired seed-block bootstrap"})
    return effects

def factorial_effects(candidates: list[dict[str, Any]], n_boot: int,
                      rng_seed: int, axes: dict[str, Any] | None = None) -> dict[str, Any]:
    complete = [row for row in candidates if row.get("status") == "complete"
                and isinstance(row.get("values") or row.get("vector"), dict)]
    rng = random.Random(rng_seed)
    if not complete:
        return _empty_effects()
    if axes is not None and all(row.get("_landscapeRows") for row in complete):
        return _seed_block_factorial(complete, n_boot, rng_seed, axes, rng)
    main_acc: dict[tuple[str, str, str], list[float]] = defaultdict(list)
    pair_acc: dict[tuple[str, str, str], list[float]] = defaultdict(list)
    for _ in range(n_boot):
        _record_draw([complete[rng.randrange(len(complete))] for _ in complete],
                     main_acc, pair_acc)
    effects = _fill_effects(_empty_effects(), complete, main_acc, pair_acc)
    effects.update({"nBoot": n_boot, "rngSeed": rng_seed})
    return effects

def _thin_mid_strengthened(result: dict[str, Any], baseline: dict[str, Any]) -> dict[str, bool]:
    out = {"duskblade": False, "ashwarden": False}
    for aspect in ASPECTS:
        for vow in VOWS:
            grid = f"{aspect}:v{vow}"
            top = str(((result.get("proxies") or {}).get(grid) or {}).get("topCell") or "")
            for lean in TIE:
                for thick in ("thin", "mid"):
                    name = f"{lean}:{thick}"
                    cand = (result.get("cells") or {}).get(f"{grid}:{name}") or {}
                    base = (baseline.get("cells") or {}).get(f"{grid}:{name}") or {}
                    if name != top and int(cand.get("runs") or 0) > 0 \
                            and float(cand.get("winRate") or 0.0) > float(base.get("winRate") or 0.0):
                        out[aspect] = True
    return out

def decide(result: dict[str, Any], baseline: dict[str, Any] | None,
           contract: dict[str, Any]) -> dict[str, Any]:
    del contract
    reasons: list[str] = []
    guards = result.get("guardrails") or {"clear": False, "reasons": [REASON["simulator"]]}
    diag = result.get("profileDiagnostics") or {}
    simulator_clear = int(result.get("controlErrors") or 0) == 0 \
        and int(result.get("landscapeErrors") or 0) == 0
    if baseline is not None:
        simulator_clear = simulator_clear \
            and int(result.get("controlStalls") or 0) <= int(baseline.get("controlStalls") or 0) \
            and int(result.get("landscapeStalls") or 0) <= int(baseline.get("landscapeStalls") or 0)
    if not simulator_clear:
        reasons.append(REASON["simulator"])
    if not guards.get("clear"):
        reasons.extend(reason for reason in guards.get("reasons") or [] if reason not in reasons)
    exposed = any(int((diag.get(grid) or {}).get("exposedRuns") or 0) > 0 for grid in GRIDS)
    fired = any(int((diag.get(grid) or {}).get("firedRuns") or 0) > 0 for grid in GRIDS)
    fault = profile_attribution_fault(
        (result.get("_controlRows") or []) + (result.get("_landscapeRows") or []),
        dict(result.get("values") or {}))
    attribution_ok = bool(exposed and fired and not fault)
    if not exposed or not fired:
        reasons.append(REASON["unreachable"])
    if fault:
        reasons.append(REASON["attribution"])
    vs = ((result.get("bootstrap") or {}).get("vsBaseline") or {})
    improved = {}
    for grid in GRIDS:
        cand = (result.get("validProxies") or {}).get(grid) or {"within10": 0, "viable": 0}
        base = ((baseline or {}).get("validProxies") or {}).get(grid) or cand
        point = int(cand["within10"]) > int(base.get("within10", 0)) \
            or int(cand["viable"]) > int(base.get("viable", 0))
        ub = ((vs.get("breadth") or {}).get(grid) or {}).get("p975")
        improved[grid] = bool(point and ub is not None and float(ub) < 0.0)
    dusk_ok = improved["duskblade:v0"] or improved["duskblade:v5"]
    ash_ok = improved["ashwarden:v0"] or improved["ashwarden:v5"]
    both = dusk_ok and ash_ok
    c1 = vs.get("c1") or {}
    c1_clear = any(float((c1.get(key) or {}).get("p975") or 1.0) < 0.0 for key in ("c1a", "c1b"))
    credible = bool(c1_clear and both)
    if not both and (dusk_ok or ash_ok):
        reasons.append(REASON["aspect"])
    if not credible:
        reasons.append(REASON["breadth"])
    thin_mid = _thin_mid_strengthened(result, baseline or {}) if baseline \
        else {"duskblade": False, "ashwarden": False}
    thin_ok = thin_mid["duskblade"] and thin_mid["ashwarden"]
    if not thin_ok:
        reasons.append(REASON["thin"])
    fat_only = False
    if baseline is not None:
        cand, base = candidate_responses(result), candidate_responses(baseline)
        fat_only = cand["fatWinRate"] > base["fatWinRate"] \
            and cand["thinWinRate"] <= base["thinWinRate"] \
            and cand["midWinRate"] <= base["midWinRate"]
        if fat_only:
            reasons.append(REASON["global"])
    return {
        "eligible": bool(guards.get("clear") and simulator_clear and attribution_ok
                         and credible and thin_ok and not fat_only),
        "reasons": list(dict.fromkeys(reasons)),
        "breadthBothAspects": both, "credibleBreadth": credible,
        "thinMidRoutes": thin_ok, "profileAttribution": attribution_ok,
        "simulatorClear": simulator_clear, "gridImprovement": improved,
        "globalDifficultyOnly": fat_only,
    }

def pareto_ids(candidates: list[dict[str, Any]]) -> list[str]:
    keys = ("validC1a", "validC1b", "thinDeficit", "midDeficit", "gapThird", "gapFourth")
    eligible = [row for row in candidates
                if row.get("status") == "complete" and not row.get("earlyStop")
                and (row.get("guardrails") or {}).get("clear")
                and (row.get("decision") or {}).get("simulatorClear")]
    keep: list[str] = []
    for row in eligible:
        worse = lambda other, key: float(other.get(key) or 0.0) <= float(row.get(key) or 0.0)
        better = lambda other, key: float(other.get(key) or 0.0) < float(row.get(key) or 0.0)
        dominated = any(all(worse(other, key) for key in keys)
                        and any(better(other, key) for key in keys)
                        for other in eligible if other["id"] != row["id"])
        if not dominated:
            keep.append(row["id"])
    return keep

def racing_set(candidates: list[dict[str, Any]], cap: int = 4) -> list[str]:
    by_id = {row["id"]: row for row in candidates}
    kept: list[str] = []
    seen: list[dict[str, str]] = []
    for cid in pareto_ids(candidates):
        row = by_id[cid]
        if cid == "t2-c000" or not (row.get("decision") or {}).get("eligible"):
            continue
        vector = _values(row)
        if any(sum(int(vector.get(knob) != previous.get(knob)) for knob in KNOBS) <= 1
               for previous in seen):
            continue
        kept.append(cid)
        seen.append(vector)
        if len(kept) >= cap:
            break
    return kept

def tidy_candidate(result: dict[str, Any]) -> dict[str, Any]:
    bands = result.get("deckBands") or {}
    proxies, valid = result.get("proxies") or {}, result.get("validProxies") or {}
    decision, guards = result.get("decision") or {}, result.get("guardrails") or {}

    def band_sum(thick: str, field: str) -> float:
        return sum(float((bands.get(grid) or {}).get(thick, {}).get(field))
                   for grid in GRIDS
                   if (bands.get(grid) or {}).get(thick, {}).get(field) is not None)

    def band_rate(thick: str) -> float | None:
        if any("wins" in ((bands.get(grid) or {}).get(thick) or {}) for grid in GRIDS):
            runs = band_sum(thick, "runs")
            return (band_sum(thick, "wins") / runs) if runs else None
        return _mean([(bands.get(grid) or {}).get(thick, {}).get("winRate") for grid in GRIDS])

    grid_map = lambda src, key: {grid: (src.get(grid) or {}).get(key) for grid in GRIDS}
    return {
        "id": result["id"], "vector": _values(result), "status": result.get("status"),
        "earlyStop": result.get("earlyStop"),
        "controlErrors": int(result.get("controlErrors") or 0), "controlStalls": int(result.get("controlStalls") or 0),
        "landscapeErrors": int(result.get("landscapeErrors") or 0), "landscapeStalls": int(result.get("landscapeStalls") or 0),
        "observationsSha256": result.get("observationsSha256"),
        "controlRowCount": result.get("controlRowCount"), "landscapeRowCount": result.get("landscapeRowCount"),
        "validC1a": result.get("validC1a"), "validC1b": result.get("validC1b"),
        "thinDeficit": result.get("thinDeficit"), "midDeficit": result.get("midDeficit"),
        "thinRuns": int(band_sum("thin", "runs")), "midRuns": int(band_sum("mid", "runs")),
        "fatRuns": int(band_sum("fat", "runs")), "thinWinRate": band_rate("thin"),
        "midWinRate": band_rate("mid"), "fatWinRate": band_rate("fat"),
        "occupiedValidCells": result.get("occupiedValidCells"),
        "within10": grid_map(valid, "within10"), "viable": grid_map(valid, "viable"),
        "topCell": grid_map(proxies, "topCell"), "arm2": grid_map(proxies, "arm2Rate"),
        "guardrailsClear": bool(guards.get("clear")),
        "identityClear": bool((guards.get("identity") or {}).get("clear")),
        "guardReasons": list(guards.get("reasons") or []),
        "simulatorClear": bool(decision.get("simulatorClear")),
        "profileAttribution": bool(decision.get("profileAttribution")),
        "eligible": bool(decision.get("eligible")), "decisionReasons": list(decision.get("reasons") or []),
    }

def attach_tier2_fields(result: dict[str, Any], axes: dict[str, Any], contract: dict[str, Any],
                        load_rules: dict[str, bool], landscape_rows: list[dict[str, Any]] | None = None,
                        control_rows: list[dict[str, Any]] | None = None) -> dict[str, Any]:
    inherited_path = (contract.get("inheritedTier1") or {}).get("path")
    inherited = read_json(REPO / inherited_path) if inherited_path else contract
    attach_tier1_fields(result, axes, inherited, load_rules, landscape_rows, control_rows)
    result.pop("packageDiagnostics", None)
    landscape = landscape_rows if landscape_rows is not None else result.get("_landscapeRows") or []
    controls = control_rows if control_rows is not None else result.get("_controlRows") or []
    diag, cond = _profile_tables(list(controls) + list(landscape))
    bands = occupancy_rate_bands(landscape, axes)
    result["deckBands"] = bands
    result["thinDeficit"] = sum(1.0 - float((bands[g]["thin"].get("occupancyRate") or 0.0))
                                for g in GRIDS)
    result["midDeficit"] = sum(1.0 - float((bands[g]["mid"].get("occupancyRate") or 0.0))
                               for g in GRIDS)
    result["profileDiagnostics"], result["conditionalOutcomes"] = diag, cond
    gaps = result.get("rankGaps") or {}
    result["gapThird"] = float(_mean([(gaps.get(g) or {}).get("topToThird") for g in GRIDS]) or 0.0)
    result["gapFourth"] = float(_mean([(gaps.get(g) or {}).get("topToFourth") for g in GRIDS]) or 0.0)
    result["responses"] = candidate_responses(result)
    result["vector"] = dict(result.get("values") or {})
    return result
