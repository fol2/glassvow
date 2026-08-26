#!/usr/bin/env python3
"""Registry-driven evaluator for paired controls and mini-landscapes.

It supports F0 screening, progressive F1 racing and explicitly unsealed,
non-gating audits. It never emits C1-C4 acceptance verdicts. The historical
filename is retained so recorded replay commands remain valid.
"""
from __future__ import annotations

import argparse
import json
import random
import shutil
import subprocess
import sys
import tempfile
import time
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from typing import Any

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

from balance_content_doe import generate_bundle as generate_doe_bundle  # noqa: E402
from balance_host_qualify import host_identity, require_godot  # noqa: E402
from balance_tier1_design import generate_bundle as generate_tier1_bundle  # noqa: E402
from balance_f0_tier1 import (  # noqa: E402
    RACING_SET,
    attach_tier1_fields,
    bootstrap_breadth,
    breadth_pareto,
    decide,
    identity_load,
    package_effects,
    pairwise_effects,
)
from balance_seed_contract import (  # noqa: E402
    CONTRACT_REL,
    LIVE_REL,
    MOBS_REL,
    REPO,
    SPACE_REL,
    canonical_json_bytes,
    catalogue_identity,
    check_invocation,
    file_sha256,
    load_contract,
    read_json,
    resolve_mobs_path,
    sha256_bytes,
)

ASPECTS = ("duskblade", "ashwarden")
VOWS = (0, 5)
TIE = ("shatter", "smolder", "attrition")
THICK = ("thin", "mid", "fat")
RANK_ARMS = (1, 2)
CONTROL_SEEDS = (6000, 6031)
LAND_SEEDS = (6100, 6107)
LAND_N = LAND_SEEDS[1] - LAND_SEEDS[0] + 1
POLICY_ROOT = 454
POLICY_COUNT = 128
BOOT_SEED = 454
TOOL_ID = "glassvow-balance-f0"
MARKER = f".{TOOL_ID}"
VOLATILE = frozenset({
    "wallSeconds", "rowsPerSecond", "startedAt", "finishedAt", "hostname",
    "out", "contentPath", "searchSpacePath", "mobOverridePath",
})
HOST_PACKETS = (
    "docs/balance/data/456/m1-max.json",
    "docs/balance/data/456/m4-mac-mini.json",
)
HOST_PACKETS_TIER1 = (
    "docs/balance/data/489/m1-max.json",
    "docs/balance/data/489/m4-mac-mini.json",
)
RESPONSE_CONTRACT_REL = "docs/balance/490-f0-response-contract-v1.json"
PROXY_KEYS = ("topRate", "thirdRate", "fourthRate", "within10", "viable", "arm2Rate", "margin")
RATE_PROXY_KEYS = ("topRate", "thirdRate", "fourthRate", "arm2Rate", "margin")
DEFICIT_KEYS = ("c1a", "c1b", "c2arm", "c2gap")


def dump(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
                    encoding="utf-8")


def split_span(first: int, last: int, jobs: int) -> list[dict[str, int]]:
    n = last - first + 1
    jobs = max(1, min(jobs, n))
    base, rem = divmod(n, jobs)
    start, out = first, []
    for index in range(jobs):
        take = base + (1 if index < rem else 0)
        out.append({"seed0": start, "seeds": take})
        start += take
    return out


def split_count(total: int, jobs: int) -> list[dict[str, int]]:
    jobs = max(1, min(jobs, total))
    base, rem = divmod(total, jobs)
    start, out = 0, []
    for index in range(jobs):
        take = base + (1 if index < rem else 0)
        out.append({"policyFirst": start, "policyCount": take})
        start += take
    return out


def progressive_plans(previous: dict[str, Any], current: dict[str, Any],
                      jobs: int) -> tuple[list[dict[str, int]], list[dict[str, int]]]:
    """Return only the disjoint rectangles not already present in a nested layer."""
    if previous["controlStage"] != current["controlStage"] \
            or previous["controlRoot"] != current["controlRoot"] \
            or previous["controlFirst"] != current["controlFirst"] \
            or previous["controlArms"] != current["controlArms"] \
            or previous["controlLast"] > current["controlLast"]:
        raise ValueError("inherited control range is not nested inside the current layer")
    if previous["landscapeStage"] != current["landscapeStage"] \
            or previous["landscapeRoot"] != current["landscapeRoot"] \
            or previous["landscapeFirst"] != current["landscapeFirst"] \
            or previous["landscapeLast"] > current["landscapeLast"] \
            or previous["policyFirst"] != current["policyFirst"] \
            or previous["policyCount"] > current["policyCount"]:
        raise ValueError("inherited landscape rectangle is not nested inside the current layer")
    controls = split_span(previous["controlLast"] + 1, current["controlLast"], jobs) \
        if previous["controlLast"] < current["controlLast"] else []
    rectangles: list[dict[str, int]] = []
    if previous["landscapeLast"] < current["landscapeLast"]:
        rectangles.append({
            "policyFirst": current["policyFirst"], "policyCount": previous["policyCount"],
            "seed0": previous["landscapeLast"] + 1,
            "seeds": current["landscapeLast"] - previous["landscapeLast"],
        })
    if previous["policyCount"] < current["policyCount"]:
        rectangles.append({
            "policyFirst": current["policyFirst"] + previous["policyCount"],
            "policyCount": current["policyCount"] - previous["policyCount"],
            "seed0": current["landscapeFirst"],
            "seeds": current["landscapeLast"] - current["landscapeFirst"] + 1,
        })
    landscape: list[dict[str, int]] = []
    for rectangle in rectangles:
        for part in split_count(rectangle["policyCount"], jobs):
            landscape.append({
                "policyFirst": rectangle["policyFirst"] + part["policyFirst"],
                "policyCount": part["policyCount"],
                "seed0": rectangle["seed0"], "seeds": rectangle["seeds"],
            })
    return controls, landscape


def protocol(contract: dict[str, Any]) -> dict[str, Any]:
    return {
        "issue": 457,
        "controls": {"stage": "f0-controls", "root": POLICY_ROOT,
                     "first": CONTROL_SEEDS[0], "last": CONTROL_SEEDS[1],
                     "arms": list(RANK_ARMS), "emitArms": [1, 2, 3, 4]},
        "landscape": {"stage": "f0-mini-landscape", "root": POLICY_ROOT,
                      "policyFirst": 0, "policyCount": POLICY_COUNT,
                      "first": LAND_SEEDS[0], "last": LAND_SEEDS[1]},
        "frozenLandscape": contract["frozenLandscape"],
        "bootSeed": BOOT_SEED,
    }


def evaluation_spec(proto: dict[str, Any]) -> dict[str, Any]:
    """Resolve the generic evaluator ranges while preserving the F0 defaults."""
    controls, landscape = proto["controls"], proto["landscape"]
    return {
        "controlStage": str(controls.get("stage", "f0-controls")),
        "controlRoot": int(controls.get("root", landscape.get("root", POLICY_ROOT))),
        "controlFirst": int(controls["first"]), "controlLast": int(controls["last"]),
        "controlArms": [int(arm) for arm in controls.get(
            "emitArms", controls.get("arms", [1, 2, 3, 4]))],
        "landscapeStage": str(landscape.get("stage", "f0-mini-landscape")),
        "landscapeRoot": int(landscape.get("root", POLICY_ROOT)),
        "landscapeFirst": int(landscape["first"]), "landscapeLast": int(landscape["last"]),
        "policyFirst": int(landscape.get("policyFirst", 0)),
        "policyCount": int(landscape["policyCount"]),
    }


def evaluation_from_registry(registry: dict[str, Any], name: str,
                             axes: dict[str, Any]) -> dict[str, Any]:
    """Select one immutable evaluation without leaking unrelated registry fields."""
    selected = registry.get("evaluations", {}).get(name)
    if not isinstance(selected, dict):
        raise ValueError(f"unknown evaluation {name!r}")
    selected_out: dict[str, Any] = {
        "issue": int(registry["issue"]), "evaluation": name,
        "controls": selected["controls"], "landscape": selected["landscape"],
        "frozenLandscape": axes, "bootstrap": int(selected.get("bootstrap", 1000)),
        "finalistAudit": bool(selected.get("finalistAudit", False)),
    }
    for key in ("completeRectangle", "candidateSource", "candidateCount", "candidateSeed"):
        if key in selected:
            selected_out[key] = selected[key]
    if "bootstrapSeed" in selected:
        selected_out["bootSeed"] = int(selected["bootstrapSeed"])
    if registry.get("hostPackets"):
        selected_out["hostPackets"] = list(registry["hostPackets"])
    elif selected.get("hostPackets"):
        selected_out["hostPackets"] = list(selected["hostPackets"])
    if registry.get("responseContract"):
        selected_out["responseContract"] = str(registry["responseContract"])
    for key in ("baseline", "racingSet", "candidateManifest", "strictGuardrails"):
        if key in registry:
            selected_out[key] = registry[key]
    return selected_out


def is_tier1_profile(proto: dict[str, Any]) -> bool:
    """Tier-1 analysis is selected by its candidate source, not one issue number."""
    return str(proto.get("candidateSource", "")) == "tier1"


def validate_candidate_manifest(actual: dict[str, Any], expected: dict[str, Any]) -> None:
    """Require the generated bundle to preserve #491's exact candidate identities."""
    keys = ("id", "baseline", "values", "fileSha256", "semanticSha256")

    def identities(value: dict[str, Any]) -> list[dict[str, Any]]:
        return [{key: row.get(key) for key in keys} for row in value.get("candidates", [])]

    if int(actual.get("count", -1)) != int(expected.get("count", -2)) \
            or int(actual.get("seed", -1)) != int(expected.get("seed", -2)) \
            or identities(actual) != identities(expected):
        raise ValueError("candidate manifest drifted from the committed #491 identities")


def validate_audit_finalist_set(path: Path, protocol_path: Path, registry: dict[str, Any],
                                candidate_manifest: dict[str, Any], wanted: list[str],
                                out: Path) -> dict[str, Any]:
    """Bind the one sealed audit to the committed Layer-3 promotion receipt."""
    audit = registry["audit"]
    expected_path = (REPO / str(audit["finalistSetPath"])).resolve()
    if path.resolve() != expected_path or out.resolve() != Path(str(audit["auditOutput"])).resolve():
        raise ValueError("sealed audit paths do not match the frozen invocation")
    packet = read_json(path)
    required = set(audit["finalistSetSchema"]["required"])
    if not required.issubset(packet) or int(packet.get("schemaVersion", 0)) != 1 \
            or int(packet.get("issue", 0)) != int(registry["issue"]):
        raise ValueError("sealed audit finalist set is malformed")
    if packet["protocolSha256"] != file_sha256(protocol_path) \
            or packet["candidateManifestSha256"] != file_sha256(
                REPO / str(registry["candidateManifest"])):
        raise ValueError("sealed audit finalist-set inputs drifted")
    decisions_path = REPO / str(packet["layer3Decisions"])
    if not decisions_path.is_file() \
            or packet["layer3DecisionsSha256"] != file_sha256(decisions_path):
        raise ValueError("sealed audit Layer-3 decisions are missing or stale")
    decisions = read_json(decisions_path)
    finalists = [str(value) for value in packet.get("finalists", [])]
    if decisions.get("evaluation") != "layer3" or decisions.get("promoted") != finalists \
            or not 1 <= len(finalists) <= int(registry["finalistBar"]["maximumFinalists"]):
        raise ValueError("sealed audit finalists do not equal the Layer-3 promotions")
    promoted_rows = {str(row["id"]): row for row in decisions.get("decisions", [])}
    if any(not promoted_rows.get(candidate_id, {}).get("strongBreadth", {}).get("clear")
           for candidate_id in finalists):
        raise ValueError("sealed audit finalist did not clear strong breadth")
    baseline = str(packet.get("baseline", ""))
    if baseline != str(registry["baseline"]) or wanted != [baseline, *finalists]:
        raise ValueError("sealed audit --only is not the exact frozen candidate set")
    validate_candidate_manifest(candidate_manifest,
                                read_json(REPO / str(registry["candidateManifest"])))
    known_candidates = {str(row["id"]) for row in candidate_manifest["candidates"]}
    if baseline not in known_candidates or baseline in finalists \
            or len(finalists) != len(set(finalists)) \
            or any(candidate_id not in known_candidates for candidate_id in finalists):
        raise ValueError("sealed audit finalist is not in the frozen candidate manifest")
    return packet


def create_audit_receipt(out: Path, finalist_set: Path, packet: dict[str, Any],
                         protocol_path: Path) -> None:
    receipt = out / "audit-invocation.json"
    if receipt.exists() or any((out / candidate_id).exists()
                               for candidate_id in [packet["baseline"], *packet["finalists"]]):
        raise ValueError("sealed audit invocation receipt already exists")
    value = {"issue": int(packet["issue"]), "protocolSha256": file_sha256(protocol_path),
             "finalistSetSha256": file_sha256(finalist_set),
             "baseline": packet["baseline"], "finalists": packet["finalists"]}
    with receipt.open("x", encoding="utf-8") as handle:
        json.dump(value, handle, indent=2, sort_keys=True)
        handle.write("\n")


def input_parts(proto: dict[str, Any], identity: dict[str, Any], candidate: dict[str, Any],
                godot: str, commit: str) -> dict[str, Any]:
    return {
        "protocol": proto,
        "candidate": {"id": candidate["id"], "values": candidate["values"],
                      "fileSha256": candidate["fileSha256"],
                      "semanticSha256": candidate["semanticSha256"]},
        "identity": {k: identity[k] for k in
                     ("contentFileSha256", "contentSemanticSha256", "searchSpaceSha256",
                      "driverSha256", "mobOverrideFileSha256", "mobOverrideSemanticSha256")},
        "seedRegistrySha256": identity["seedRegistrySha256"],
        "godotVersion": godot,
        "commit": commit,
    }


def input_hash(parts: dict[str, Any]) -> str:
    return sha256_bytes(canonical_json_bytes(parts))


def drop_volatile(value: Any) -> Any:
    if isinstance(value, dict):
        return {k: drop_volatile(v) for k, v in value.items() if k not in VOLATILE}
    if isinstance(value, list):
        return [drop_volatile(item) for item in value]
    return value


def lean_and_thick(row: dict[str, Any], axes: dict[str, Any]) -> tuple[str, str]:
    fights = row.get("fights") or []
    n = len(fights)
    shatter = sum(float(fight["shatters"]) for fight in fights) / n if n else 0.0
    smolder = sum(float(fight["smolderKills"]) for fight in fights) / n if n else 0.0
    med = axes["medians"][str(row["aspect"])]
    lean = "shatter" if shatter > med["shattersPerFight"] else (
        "smolder" if smolder > med["smolderKillsPerFight"] else "attrition")
    deck = int(row.get("deck") or 0)
    cuts = axes["deckCuts"]
    thick = "thin" if deck <= int(cuts["thinMax"]) else (
        "mid" if deck <= int(cuts["midMax"]) else "fat")
    return lean, thick


def _cell(wins: int, runs: int, stalls: int = 0, errors: int = 0) -> dict[str, Any]:
    return {"wins": wins, "runs": runs, "stalls": stalls, "errors": errors,
            "winRate": (wins / runs) if runs else 0.0}


def _tally(rows: list[dict[str, Any]], key_fn: Any) -> dict[tuple[Any, ...], dict[str, int]]:
    buckets: dict[tuple[Any, ...], dict[str, int]] = defaultdict(
        lambda: {"wins": 0, "runs": 0, "stalls": 0, "errors": 0})
    for row in rows:
        bucket = buckets[key_fn(row)]
        bucket["runs"] += 1
        outcome = str(row.get("outcome", ""))
        if outcome == "win":
            bucket["wins"] += 1
        elif outcome == "stall":
            bucket["stalls"] += 1
        elif outcome == "error":
            bucket["errors"] += 1
    return buckets


def aggregate_controls(rows: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
    buckets = _tally(rows, lambda row: (int(row["arm"]), str(row["aspect"]), int(row["vow"])))
    arms = sorted({int(row["arm"]) for row in rows}) or list(RANK_ARMS)
    return {f"{arm}:{aspect}:v{vow}": _cell(**buckets[(arm, aspect, vow)])
            for arm in arms for aspect in ASPECTS for vow in VOWS}


def aggregate_cells(rows: list[dict[str, Any]], axes: dict[str, Any]) -> dict[str, dict[str, Any]]:
    buckets = _tally(rows, lambda row: (str(row["aspect"]), int(row["vow"]), *lean_and_thick(row, axes)))
    policies: dict[tuple[Any, ...], set[int]] = defaultdict(set)
    for row in rows:
        key = (str(row["aspect"]), int(row["vow"]), *lean_and_thick(row, axes))
        if "policyIndex" in row:
            policies[key].add(int(row["policyIndex"]))
    out: dict[str, dict[str, Any]] = {}
    for aspect in ASPECTS:
        for vow in VOWS:
            for lean in TIE:
                for thick in THICK:
                    key = (aspect, vow, lean, thick)
                    cell = _cell(**buckets[key])
                    cell["policies"] = len(policies[key])
                    out[f"{aspect}:v{vow}:{lean}:{thick}"] = cell
    return out


def grid_proxies(controls: dict[str, dict[str, Any]],
                 cells: dict[str, dict[str, Any]]) -> dict[str, dict[str, Any]]:
    out: dict[str, dict[str, Any]] = {}
    for aspect in ASPECTS:
        for vow in VOWS:
            gkey = f"{aspect}:v{vow}"
            grid = {f"{lean}:{thick}": cells[f"{gkey}:{lean}:{thick}"]
                    for lean in TIE for thick in THICK}
            ranked = sorted(grid.items(), key=lambda item: (-item[1]["winRate"], item[0]))
            top_name, top = ranked[0]
            arm2 = controls[f"2:{aspect}:v{vow}"]
            floor = (arm2["winRate"] + top["winRate"]) / 2
            out[gkey] = {
                "topCell": top_name, "topRate": top["winRate"],
                "thirdRate": ranked[2][1]["winRate"], "fourthRate": ranked[3][1]["winRate"],
                "within10": sum(1 for cell in grid.values()
                                if cell["winRate"] >= top["winRate"] - 0.10),
                "viable": sum(1 for cell in grid.values() if cell["winRate"] >= floor),
                "arm2Wins": arm2["wins"], "arm2Runs": arm2["runs"],
                "arm2Rate": arm2["winRate"], "margin": top["winRate"] - arm2["winRate"],
            }
    return out


def deficits(proxies: dict[str, dict[str, Any]]) -> dict[str, float]:
    c1a = c1b = c2arm = c2gap = 0.0
    for proxy in proxies.values():
        c1a += max(0.0, 3 - proxy["within10"]) / 3
        c1b += max(0.0, 4 - proxy["viable"]) / 4
        c2arm += max(0.0, proxy["arm2Rate"] - 0.5) / 0.5
        c2gap += max(0.0, 0.35 - proxy["margin"]) / 0.35
    return {"c1a": c1a, "c1b": c1b, "c2arm": c2arm, "c2gap": c2gap,
            "sum": c1a + c1b + c2arm + c2gap}


def identity_fault(rows: list[dict[str, Any]]) -> str:
    paired: dict[tuple[Any, ...], dict[str, str]] = {}
    for row in rows:
        if int(row.get("arm", 0)) not in RANK_ARMS:
            continue
        key = (int(row["arm"]), int(row["vow"]), int(row["seed"]))
        paired.setdefault(key, {})[str(row["aspect"])] = str(row["outcome"])
    if paired and all(pair.get("duskblade") == pair.get("ashwarden") and len(pair) == 2
                      for pair in paired.values()):
        return "identity-collapse"
    return ""


def landscape_fault(proxies: dict[str, dict[str, Any]]) -> str:
    for vow in VOWS:
        dusk = str(proxies[f"duskblade:v{vow}"]["topCell"])
        ash = str(proxies[f"ashwarden:v{vow}"]["topCell"])
        if dusk.startswith("smolder") and ash.startswith("shatter"):
            return "identity-reversal"
    return ""


def ranked_control_rows(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [row for row in rows if int(row.get("arm", 0)) in RANK_ARMS]


def control_fault(rows: list[dict[str, Any]], baseline_stalls: int,
                  complete_rectangle: bool = False) -> str:
    ranked = ranked_control_rows(rows)
    errors = sum(1 for row in ranked if row.get("outcome") == "error")
    stalls = sum(1 for row in ranked if row.get("outcome") == "stall")
    if errors:
        return "errors"
    if complete_rectangle:
        return ""
    if stalls > baseline_stalls:
        return "stalls-beyond-baseline"
    return identity_fault(ranked)


def landscape_errors_fault(rows: list[dict[str, Any]]) -> str:
    return "errors" if any(row.get("outcome") == "error" for row in rows) else ""


def screening_metric_fault(proxies: dict[str, dict[str, Any]] | None = None,
                           bootstrap: dict[str, Any] | None = None,
                           baseline_bootstrap: dict[str, Any] | None = None,
                           complete_rectangle: bool = False) -> str:
    """Poor metrics must not stop a complete-rectangle candidate."""
    if complete_rectangle:
        return ""
    if proxies:
        found = landscape_fault(proxies)
        if found:
            return found
    if bootstrap and baseline_bootstrap and envelope_dominated(bootstrap, baseline_bootstrap):
        return "dominated-envelope"
    return ""


def by_seed(rows: list[dict[str, Any]]) -> dict[int, list[dict[str, Any]]]:
    grouped: dict[int, list[dict[str, Any]]] = defaultdict(list)
    for row in rows:
        grouped[int(row["seed"])].append(row)
    return dict(grouped)


def percentile(values: list[float], pct: float) -> float:
    if not values:
        return 0.0
    ordered = sorted(values)
    index = min(len(ordered) - 1, max(0, int(round((pct / 100) * (len(ordered) - 1)))))
    return ordered[index]


def _interval(values: list[float]) -> dict[str, float]:
    return {"p025": percentile(values, 2.5), "p50": percentile(values, 50),
            "p975": percentile(values, 97.5)}


def _draw(grouped: dict[int, list[dict[str, Any]]], ids: list[int]) -> list[dict[str, Any]]:
    return [row for seed in ids for row in grouped[seed]]


def _seed_tallies(grouped: dict[int, list[dict[str, Any]]], key_fn: Any) \
        -> dict[int, dict[tuple[Any, ...], dict[str, int]]]:
    return {seed: _tally(rows, key_fn) for seed, rows in grouped.items()}


def _combine_tallies(seed_tallies: dict[int, dict[tuple[Any, ...], dict[str, int]]],
                     ids: list[int]) -> dict[tuple[Any, ...], dict[str, int]]:
    combined: dict[tuple[Any, ...], dict[str, int]] = defaultdict(
        lambda: {"wins": 0, "runs": 0, "stalls": 0, "errors": 0})
    for seed in ids:
        for key, values in seed_tallies[seed].items():
            for field in ("wins", "runs", "stalls", "errors"):
                combined[key][field] += values[field]
    return combined


def _controls_from_tallies(tallies: dict[tuple[Any, ...], dict[str, int]]) \
        -> dict[str, dict[str, Any]]:
    arms = sorted({int(key[0]) for key in tallies}) or list(RANK_ARMS)
    return {f"{arm}:{aspect}:v{vow}": _cell(**tallies[(arm, aspect, vow)])
            for arm in arms for aspect in ASPECTS for vow in VOWS}


def _cells_from_tallies(tallies: dict[tuple[Any, ...], dict[str, int]]) \
        -> dict[str, dict[str, Any]]:
    cells: dict[str, dict[str, Any]] = {}
    for aspect in ASPECTS:
        for vow in VOWS:
            for lean in TIE:
                for thick in THICK:
                    cell = _cell(**tallies[(aspect, vow, lean, thick)])
                    cell["policies"] = 0  # Policy cardinality is not a bootstrap response.
                    cells[f"{aspect}:v{vow}:{lean}:{thick}"] = cell
    return cells


def seed_block_bootstrap(control: dict[int, list[dict[str, Any]]],
                         landscape: dict[int, list[dict[str, Any]]],
                         baseline_control: dict[int, list[dict[str, Any]]] | None,
                         baseline_landscape: dict[int, list[dict[str, Any]]] | None,
                         axes: dict[str, Any], n_boot: int, rng_seed: int) -> dict[str, Any]:
    rng = random.Random(rng_seed)
    c_ids, l_ids = sorted(control), sorted(landscape)
    control_tallies = _seed_tallies(
        control, lambda row: (int(row["arm"]), str(row["aspect"]), int(row["vow"])))
    landscape_tallies = _seed_tallies(
        landscape, lambda row: (str(row["aspect"]), int(row["vow"]),
                                *lean_and_thick(row, axes)))
    baseline_control_tallies = _seed_tallies(
        baseline_control, lambda row: (int(row["arm"]), str(row["aspect"]), int(row["vow"]))) \
        if baseline_control is not None else None
    baseline_landscape_tallies = _seed_tallies(
        baseline_landscape, lambda row: (str(row["aspect"]), int(row["vow"]),
                                         *lean_and_thick(row, axes))) \
        if baseline_landscape is not None else None
    grid_acc: dict[str, dict[str, list[float]]] = defaultdict(lambda: defaultdict(list))
    def_acc: dict[str, list[float]] = defaultdict(list)
    vs_acc: dict[str, list[float]] = defaultdict(list)
    for _ in range(n_boot):
        c_draw = [rng.choice(c_ids) for _ in c_ids] if c_ids else []
        l_draw = [rng.choice(l_ids) for _ in l_ids] if l_ids else []
        proxies = grid_proxies(
            _controls_from_tallies(_combine_tallies(control_tallies, c_draw)),
            _cells_from_tallies(_combine_tallies(landscape_tallies, l_draw)))
        deficit = deficits(proxies)
        for grid, proxy in proxies.items():
            for key in PROXY_KEYS:
                grid_acc[grid][key].append(float(proxy[key]))
        for key, value in deficit.items():
            def_acc[key].append(float(value))
        if baseline_control is not None and baseline_landscape is not None:
            assert baseline_control_tallies is not None and baseline_landscape_tallies is not None
            b_proxies = grid_proxies(
                _controls_from_tallies(_combine_tallies(baseline_control_tallies, c_draw)),
                _cells_from_tallies(_combine_tallies(baseline_landscape_tallies, l_draw)))
            b_def = deficits(b_proxies)
            vs_acc["sum"].append(float(b_def["sum"] - deficit["sum"]))
            for key in DEFICIT_KEYS:
                vs_acc[f"deficit:{key}"].append(float(b_def[key] - deficit[key]))
            for grid in proxies:
                for key in RATE_PROXY_KEYS:
                    vs_acc[f"grid:{grid}:{key}"].append(
                        float(proxies[grid][key] - b_proxies[grid][key]))
            vs_acc["margin"].append(float(
                sum(proxies[g]["margin"] - b_proxies[g]["margin"] for g in proxies) / len(proxies)))
    result: dict[str, Any] = {
        "nBoot": n_boot,
        "grids": {grid: {key: _interval(vals) for key, vals in series.items()}
                  for grid, series in grid_acc.items()},
        "deficits": {key: _interval(vals) for key, vals in def_acc.items()},
    }
    if vs_acc:
        result["vsC000"] = {
            "pLowerDeficitSum": sum(1 for value in vs_acc["sum"] if value > 0) / n_boot,
            "deficitSumDelta": _interval(vs_acc["sum"]),
            "deficitDelta": {
                key: _interval(vs_acc[f"deficit:{key}"]) for key in DEFICIT_KEYS
            },
            "gridDelta": {
                grid: {key: _interval(vs_acc[f"grid:{grid}:{key}"])
                       for key in RATE_PROXY_KEYS}
                for grid in sorted(proxies)
            },
            "marginDelta": _interval(vs_acc["margin"]),
        }
    return result


def envelope_dominated(boot: dict[str, Any], baseline: dict[str, Any]) -> bool:
    left, right = boot.get("deficits", {}), baseline.get("deficits", {})
    return bool(left and right and all(
        left[key]["p025"] >= right[key]["p975"] for key in DEFICIT_KEYS))


def pareto_ids(candidates: list[dict[str, Any]]) -> list[str]:
    eligible = [row for row in candidates
                if row.get("status") == "complete" and not row.get("earlyStop")]
    keep: list[str] = []
    for row in eligible:
        dominated = any(all(other["deficits"][key] <= row["deficits"][key] for key in DEFICIT_KEYS)
                        and any(other["deficits"][key] < row["deficits"][key] for key in DEFICIT_KEYS)
                        for other in eligible if other["id"] != row["id"])
        if not dominated:
            keep.append(row["id"])
    return keep


def screening_effects(candidates: list[dict[str, Any]]) -> list[dict[str, Any]]:
    complete = [row for row in candidates if row.get("status") == "complete"
                and isinstance(row.get("values"), dict) and row.get("deficits")]
    if not complete:
        return []
    effects: list[dict[str, Any]] = []
    for feature in complete[0]["values"]:
        groups: dict[str, list[float]] = defaultdict(list)
        for row in complete:
            groups[json.dumps(row["values"][feature], sort_keys=True)].append(
                float(row["deficits"]["sum"]))
        means = {level: sum(vals) / len(vals) for level, vals in groups.items()}
        effects.append({"feature": feature, "levelMeans": means,
                        "range": max(means.values()) - min(means.values()) if means else 0.0})
    effects.sort(key=lambda row: -row["range"])
    return effects


def bind_row(row: dict[str, Any], identity: dict[str, Any],
             extras: bool = False) -> dict[str, Any]:
    bound = {
        "candidateId": identity["id"], "values": identity["values"],
        "candidateFileSha256": identity["fileSha256"],
        "candidateSemanticSha256": identity["semanticSha256"],
        "searchSpaceSha256": identity["searchSpaceSha256"],
        "seedRegistrySha256": identity["seedRegistrySha256"],
        "commit": identity["commit"], "driverSha256": identity["driverSha256"],
        "godotVersion": identity["godotVersion"], "hostFingerprint": identity["hostFingerprint"],
        "aspect": row["aspect"], "vow": int(row["vow"]), "seed": int(row["seed"]),
        "outcome": row["outcome"], "error": row.get("error", ""), "deck": row.get("deck"),
        "fights": row.get("fights", []), "rng": row.get("rng"),
    }
    if "arm" in row:
        bound["arm"] = int(row["arm"])
    if "policyIndex" in row:
        bound["policyIndex"] = int(row["policyIndex"])
    if extras:
        if "deckIds" in row:
            bound["deckIds"] = row["deckIds"]
        if "relics" in row:
            bound["relics"] = row["relics"]
        if "packageEvents" in row:
            bound["packageEvents"] = row["packageEvents"]
    return bound


def git_head() -> str:
    proc = subprocess.run(["git", "rev-parse", "HEAD"], cwd=REPO, capture_output=True, text=True)
    return proc.stdout.strip() if proc.returncode == 0 else "unknown"


def qualified_packet(host: dict[str, Any], godot: str,
                     packets: tuple[str, ...] | list[str] | None = None) -> dict[str, Any]:
    for rel in packets or HOST_PACKETS:
        path = REPO / rel
        if not path.is_file():
            continue
        packet = read_json(path)
        if packet.get("qualified") and packet.get("godotVersion") == godot \
                and packet.get("host", {}).get("cpu") == host.get("cpu"):
            return packet
    raise ValueError(f"host {host.get('cpu')} / {godot} is not QUALIFIED by #456")


def prepare_out(out: Path, fresh: bool) -> None:
    if out.is_symlink():
        raise ValueError(f"refusing output symlink: {out}")
    marker = out / MARKER
    if out.exists():
        if marker.is_symlink() or not out.is_dir() or not marker.is_file() \
                or marker.read_text(encoding="utf-8") != f"{TOOL_ID}\n":
            raise ValueError(f"refusing unmarked output directory: {out}")
        if fresh:
            shutil.rmtree(out)
        else:
            return
    out.mkdir(parents=True)
    (out / MARKER).write_text(f"{TOOL_ID}\n", encoding="utf-8")


def ensure_candidates(path: Path, count: int, seed: int,
                      source: str = "doe") -> dict[str, Any]:
    manifest_path = path / "manifest.json"
    if manifest_path.is_file():
        manifest = read_json(manifest_path)
        if int(manifest.get("count", -1)) != count or int(manifest.get("seed", -1)) != seed:
            raise ValueError(f"stale DOE bundle at {path}")
        return manifest
    if source == "tier1":
        return generate_tier1_bundle(REPO, path, False, seed)
    return generate_doe_bundle(REPO / LIVE_REL, REPO / SPACE_REL, path, count, seed, False)


def godot_sweep(godot: str, flags: list[str], dest: Path, log: Path) -> None:
    cmd = [godot, "--headless", "-s", "res://tools/balance_sweep.gd", "--", *flags]
    log.parent.mkdir(parents=True, exist_ok=True)
    with log.open("w", encoding="utf-8") as handle:
        handle.write(" ".join(cmd) + "\n")
        proc = subprocess.run(cmd, cwd=REPO, stdout=handle, stderr=subprocess.STDOUT)
    if proc.returncode != 0:
        raise RuntimeError(f"balance_sweep exited {proc.returncode}; see {log}")
    if not dest.is_file() or dest.stat().st_size == 0:
        raise RuntimeError(f"balance_sweep wrote no output: {dest}")


def controls_complete(path: Path, expected: int, content_sha: str,
                      mobs_sha: str = "") -> bool:
    if not path.is_file():
        return False
    blob = read_json(path)
    runs = blob.get("runs") if isinstance(blob, dict) else None
    man = blob.get("manifest", {}) if isinstance(blob, dict) else {}
    return isinstance(runs, list) and len(runs) == expected \
        and str(man.get("contentFileSha256", "")) == content_sha \
        and (not mobs_sha or str(man.get("mobOverrideFileSha256", "")) == mobs_sha)


def landscape_complete(path: Path, expected: int, content_sha: str,
                       mobs_sha: str = "") -> bool:
    if not path.is_file():
        return False
    with path.open(encoding="utf-8") as handle:
        first = handle.readline()
        count = sum(1 for _ in handle)
    if count != expected:
        return False
    try:
        header = json.loads(first)
    except json.JSONDecodeError:
        return False
    man = header.get("manifest", header) if isinstance(header, dict) else {}
    return str(man.get("contentFileSha256", "")) == content_sha \
        and (not mobs_sha or str(man.get("mobOverrideFileSha256", "")) == mobs_sha)


def load_control_rows(paths: list[Path]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for path in paths:
        rows.extend(read_json(path).get("runs") or [])
    rows.sort(key=lambda row: (int(row["arm"]), str(row["aspect"]), int(row["vow"]), int(row["seed"])))
    return rows


def load_landscape_rows(paths: list[Path]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for path in paths:
        with path.open(encoding="utf-8") as handle:
            next(handle, None)
            for line in handle:
                rows.append(json.loads(line))
    rows.sort(key=lambda row: (int(row["policyIndex"]), str(row["aspect"]),
                               int(row["vow"]), int(row["seed"])))
    return rows


def attach_raw(result: dict[str, Any], cand_dir: Path) -> dict[str, Any]:
    c_paths = sorted((cand_dir / "controls").glob("shard-*.json"))
    l_paths = sorted((cand_dir / "landscape").glob("shard-*.ndjson"))
    control_rows = load_control_rows(c_paths) if c_paths else []
    if isinstance(result.get("controlArms"), list):
        selected = {int(arm) for arm in result["controlArms"]}
        control_rows = [row for row in control_rows if int(row["arm"]) in selected]
    result["_controlRows"] = control_rows
    result["_landscapeRows"] = load_landscape_rows(l_paths) if l_paths else []
    return result


def observation_bytes(rows: list[dict[str, Any]], identity: dict[str, Any],
                      extras: bool = False) -> bytes:
    return "".join(json.dumps(bind_row(row, identity, extras), ensure_ascii=False, sort_keys=True,
                              separators=(",", ":")) + "\n" for row in rows).encode()


def write_observations(path: Path, rows: list[dict[str, Any]], identity: dict[str, Any],
                       extras: bool = False) -> str:
    payload = observation_bytes(rows, identity, extras)
    path.write_bytes(payload)
    return sha256_bytes(payload)


def require_stage(stage: str, first: int, last: int, root: int,
                  sealed_token: str | None = None) -> None:
    err = check_invocation(load_contract(), stage, first, last, root,
                           sealed_token=sealed_token)
    if err:
        raise ValueError(err)


def stage_args(stage: str, sealed_token: str | None) -> list[str]:
    args = [f"--stage={stage}"]
    if sealed_token:
        args.append(f"--sealedToken={sealed_token}")
    return args


def launch(godot: str, jobs: int, plan: list[dict[str, int]], worker: Any) -> list[Path]:
    with ThreadPoolExecutor(max_workers=max(1, min(jobs, len(plan)))) as pool:
        return list(pool.map(worker, enumerate(plan)))


def evaluate_candidate(godot: str, jobs: int, doe: Path, cand: dict[str, Any], out: Path,
                       proto: dict[str, Any], host_fp: str, commit: str, godot_version: str,
                       resume: bool, baseline: dict[str, Any] | None, n_boot: int,
                       axes: dict[str, Any], inherit: Path | None = None,
                       inherit_proto: dict[str, Any] | None = None) -> dict[str, Any]:
    cand_dir = out / cand["id"]
    content = doe / cand["id"] / "full-content.json"
    if file_sha256(content) != cand["fileSha256"]:
        raise ValueError(f"{cand['id']} file SHA drifted")
    mobs = resolve_mobs_path(cand, doe)
    cat = catalogue_identity(content, REPO / SPACE_REL, mobs_path=mobs)
    cat["searchSpaceSha256"] = str(cand.get("searchSpaceSha256", cat["searchSpaceSha256"])); cat["seedRegistrySha256"] = file_sha256(REPO / CONTRACT_REL)
    resolved = evaluation_spec(proto)
    prior_dir: Path | None = None
    prior_manifest: dict[str, Any] | None = None
    prior_resolved: dict[str, Any] | None = None
    if inherit is not None:
        if inherit_proto is None:
            raise ValueError("inherited output has no protocol")
        prior_dir = inherit / str(cand["id"])
        prior_manifest_path = prior_dir / "manifest.json"
        if not prior_manifest_path.is_file():
            raise ValueError(f"inherited layer has no {cand['id']} manifest")
        prior_manifest = read_json(prior_manifest_path)
        if prior_manifest.get("status") != "complete" \
                or str(prior_manifest.get("fileSha256")) != str(cand["fileSha256"]):
            raise ValueError(f"candidate {cand['id']} is not complete and identical in inherited layer")
        prior_resolved = evaluation_spec(inherit_proto)
        progressive_plans(prior_resolved, resolved, jobs)  # Validate before touching output.
    parts = input_parts(proto, cat, cand, godot_version, commit)
    if prior_manifest is not None and prior_resolved is not None:
        parts["inheritance"] = {
            "protocol": inherit_proto,
            "resolved": prior_resolved,
            "observationsSha256": prior_manifest["observationsSha256"],
            "inputHash": prior_manifest["inputHash"],
        }
    digest = input_hash(parts)
    input_path = cand_dir / "input.json"
    if cand_dir.exists() and resume and input_path.is_file() \
            and read_json(input_path).get("inputHash") == digest \
            and (cand_dir / "manifest.json").is_file():
        saved = read_json(cand_dir / "manifest.json")
        if saved.get("status") in ("complete", "early-stop"):
            return attach_raw(saved, cand_dir)
    elif cand_dir.exists() and (not resume or not input_path.is_file()
                                or read_json(input_path).get("inputHash") != digest):
        shutil.rmtree(cand_dir)
    cand_dir.mkdir(parents=True, exist_ok=True)
    bind = {
        "id": cand["id"], "values": cand["values"], "fileSha256": cand["fileSha256"],
        "semanticSha256": cand["semanticSha256"],
        "searchSpaceSha256": cat["searchSpaceSha256"],
        "seedRegistrySha256": cat["seedRegistrySha256"], "commit": commit,
        "driverSha256": cat["driverSha256"], "godotVersion": godot_version,
        "hostFingerprint": host_fp,
    }
    dump(input_path, {"inputHash": digest, "parts": parts})
    t0 = time.perf_counter()

    def copy_inherited(kind: str, pattern: str) -> None:
        assert prior_dir is not None
        destination_dir = cand_dir / kind
        destination_dir.mkdir(parents=True, exist_ok=True)
        for index, source_path in enumerate(sorted((prior_dir / kind).glob(pattern))):
            suffix = ".ndjson" if kind == "landscape" else ".json"
            destination = destination_dir / f"shard-inherited-{index:02d}{suffix}"
            if not destination.exists():
                shutil.copy2(source_path, destination)

    if prior_resolved is not None:
        c_plan, l_plan = progressive_plans(prior_resolved, resolved, jobs)
        copy_inherited("controls", "shard-*.json")
    else:
        c_plan = split_span(resolved["controlFirst"], resolved["controlLast"], jobs)
        l_plan = [{"policyFirst": resolved["policyFirst"] + part["policyFirst"],
                   "policyCount": part["policyCount"],
                   "seed0": resolved["landscapeFirst"],
                   "seeds": resolved["landscapeLast"] - resolved["landscapeFirst"] + 1}
                  for part in split_count(resolved["policyCount"], jobs)]
    for shard in c_plan:
        require_stage(resolved["controlStage"], shard["seed0"],
                      shard["seed0"] + shard["seeds"] - 1, resolved["controlRoot"],
                      proto.get("sealedToken"))
    require_stage(resolved["landscapeStage"], resolved["landscapeFirst"],
                  resolved["landscapeLast"], resolved["landscapeRoot"],
                  proto.get("sealedToken"))

    def control_job(item: tuple[int, dict[str, int]]) -> Path:
        index, spec = item
        dest = cand_dir / "controls" / f"shard-new-{index:02d}.json"
        dest.parent.mkdir(parents=True, exist_ok=True)
        expected = len(resolved["controlArms"]) * 4 * spec["seeds"]
        if resume and controls_complete(dest, expected, cand["fileSha256"],
                                        cat["mobOverrideFileSha256"]):
            return dest
        tmp = dest.with_suffix(".json.tmp")
        godot_sweep(godot, [
            "--mode=controls", f"--seeds={spec['seeds']}", f"--seed0={spec['seed0']}",
            f"--arms={','.join(str(arm) for arm in resolved['controlArms'])}",
            f"--rootSeed={resolved['controlRoot']}",
            *stage_args(resolved["controlStage"], proto.get("sealedToken")),
            f"--content={content}", f"--mobs={mobs}",
            f"--out={tmp}",
        ], tmp, dest.with_suffix(".log"))
        tmp.replace(dest)
        if not controls_complete(dest, expected, cand["fileSha256"],
                                 cat["mobOverrideFileSha256"]):
            raise RuntimeError(f"control shard incomplete: {dest}")
        return dest

    launch(godot, jobs, c_plan, control_job)
    selected_arms = set(resolved["controlArms"])
    control_rows = [row for row in load_control_rows(
        sorted((cand_dir / "controls").glob("shard-*.json")))
                    if int(row["arm"]) in selected_arms]
    ranked_controls = ranked_control_rows(control_rows)
    baseline_stalls = int(baseline["controlStalls"]) if baseline else sum(
        1 for row in ranked_controls if row.get("outcome") == "stall")
    complete_rectangle = bool(proto.get("completeRectangle"))
    fault = control_fault(control_rows, baseline_stalls,
                          complete_rectangle=complete_rectangle)
    landscape_rows: list[dict[str, Any]] = []
    if not fault:
        if prior_resolved is not None:
            copy_inherited("landscape", "shard-*.ndjson")

        def land_job(item: tuple[int, dict[str, int]]) -> Path:
            index, spec = item
            dest = cand_dir / "landscape" / f"shard-new-{index:02d}.ndjson"
            dest.parent.mkdir(parents=True, exist_ok=True)
            expected = spec["policyCount"] * 4 * spec["seeds"]
            if resume and landscape_complete(dest, expected, cand["fileSha256"],
                                            cat["mobOverrideFileSha256"]):
                return dest
            tmp = Path(str(dest) + ".tmp")
            godot_sweep(godot, [
                "--mode=sweep", f"--rootSeed={resolved['landscapeRoot']}",
                f"--policyFirst={spec['policyFirst']}",
                f"--policyCount={spec['policyCount']}",
                f"--seeds={spec['seeds']}", f"--seed0={spec['seed0']}",
                *stage_args(resolved["landscapeStage"], proto.get("sealedToken")),
                f"--content={content}", f"--mobs={mobs}", f"--out={tmp}",
            ], tmp, dest.with_suffix(".log"))
            tmp.replace(dest)
            if not landscape_complete(dest, expected, cand["fileSha256"],
                                     cat["mobOverrideFileSha256"]):
                raise RuntimeError(f"landscape shard incomplete: {dest}")
            return dest

        launch(godot, jobs, l_plan, land_job)
        landscape_rows = load_landscape_rows(
            sorted((cand_dir / "landscape").glob("shard-*.ndjson")))
    elif any((cand_dir / "landscape").glob("shard-*.ndjson")):
        raise RuntimeError(f"landscape rows exist after control early-stop for {cand['id']}")
    fault = fault or landscape_errors_fault(landscape_rows)
    controls = aggregate_controls(control_rows)
    cells = aggregate_cells(landscape_rows, axes) if landscape_rows else {}
    proxies = grid_proxies(controls, cells) if landscape_rows else {}
    if not fault:
        fault = screening_metric_fault(
            proxies=proxies or None, complete_rectangle=complete_rectangle)
    result: dict[str, Any] = {
        "id": cand["id"], "values": cand["values"], "fileSha256": cand["fileSha256"],
        "semanticSha256": cand["semanticSha256"], "inputHash": digest,
        "controlArms": resolved["controlArms"],
        "controls": controls, "cells": cells, "proxies": proxies,
        "controlStalls": sum(1 for row in ranked_controls if row.get("outcome") == "stall"),
        "controlErrors": sum(1 for row in ranked_controls if row.get("outcome") == "error"),
        "landscapeStalls": sum(1 for row in landscape_rows if row.get("outcome") == "stall"),
        "landscapeErrors": sum(1 for row in landscape_rows if row.get("outcome") == "error"),
        "observationsSha256": write_observations(
            cand_dir / "observations.jsonl", control_rows + landscape_rows, bind,
            extras=is_tier1_profile(proto)),
        "controlRowCount": len(control_rows), "landscapeRowCount": len(landscape_rows),
        "wallSeconds": round(time.perf_counter() - t0, 3),
        "godotVersion": godot_version, "hostFingerprint": host_fp, "commit": commit,
        "_controlRows": control_rows, "_landscapeRows": landscape_rows,
    }
    if prior_manifest is not None:
        result["inheritance"] = parts["inheritance"]
    expected_controls = (resolved["controlLast"] - resolved["controlFirst"] + 1) \
        * len(resolved["controlArms"]) * 4
    expected_landscape = resolved["policyCount"] * 4 \
        * (resolved["landscapeLast"] - resolved["landscapeFirst"] + 1)
    control_keys = {(int(row["arm"]), str(row["aspect"]), int(row["vow"]), int(row["seed"]))
                    for row in control_rows}
    landscape_keys = {(int(row["policyIndex"]), str(row["aspect"]), int(row["vow"]),
                       int(row["seed"])) for row in landscape_rows}
    if len(control_rows) != expected_controls or len(control_keys) != expected_controls:
        raise RuntimeError(f"control coverage is not exact for {cand['id']}")
    if landscape_rows and (len(landscape_rows) != expected_landscape
                           or len(landscape_keys) != expected_landscape):
        raise RuntimeError(f"landscape coverage is not exact for {cand['id']}")
    if landscape_rows:
        result["deficits"] = deficits(proxies)
        base_c = by_seed(baseline["_controlRows"]) if baseline and baseline.get("_controlRows") else None
        base_l = by_seed(baseline["_landscapeRows"]) if baseline and baseline.get("_landscapeRows") else None
        boot_seed = int(proto.get("bootSeed", BOOT_SEED))
        result["bootstrap"] = seed_block_bootstrap(
            by_seed(control_rows), by_seed(landscape_rows), base_c, base_l, axes, n_boot, boot_seed)
        if is_tier1_profile(proto):
            extra = bootstrap_breadth(
                by_seed(control_rows), by_seed(landscape_rows), base_c, base_l, axes,
                read_json(REPO / str(proto.get("responseContract", RESPONSE_CONTRACT_REL))),
                result.get("cells") or {}, n_boot, boot_seed,
                baseline_cells=(baseline or {}).get("cells"))
            result["bootstrap"] = {**result["bootstrap"], **extra}
        if baseline and baseline.get("bootstrap"):
            fault = fault or screening_metric_fault(
                bootstrap=result["bootstrap"],
                baseline_bootstrap=baseline["bootstrap"],
                complete_rectangle=complete_rectangle)
    if is_tier1_profile(proto):
        contract = read_json(REPO / str(proto.get("responseContract", RESPONSE_CONTRACT_REL)))
        attach_tier1_fields(result, axes, contract, identity_load(read_json(content)),
                            landscape_rows, control_rows,
                            strict=bool(proto.get("strictGuardrails", False)))
    result["status"] = "early-stop" if fault else "complete"
    result["earlyStop"] = fault or None
    dump(cand_dir / "manifest.json", {k: v for k, v in result.items() if not k.startswith("_")})
    print(f"{cand['id']} {result['status']} controls={len(control_rows)} "
          f"landscape={len(landscape_rows)} {result.get('earlyStop') or ''}", flush=True)
    return result


def recover_provenance(out: Path, rows: list[dict[str, Any]]) -> dict[str, str]:
    for row in rows:
        godot = str(row.get("godotVersion") or "")
        fingerprint = str(row.get("hostFingerprint") or "")
        commit = str(row.get("commit") or "")
        if godot and godot != "summarise-only" and fingerprint:
            return {"godotVersion": godot, "hostFingerprint": fingerprint, "commit": commit}
    for cid in ("c000", *(row.get("id") for row in rows)):
        obs = out / str(cid) / "observations.jsonl"
        if not cid or not obs.is_file():
            continue
        with obs.open(encoding="utf-8") as handle:
            line = handle.readline()
        if not line:
            continue
        first = json.loads(line)
        godot = str(first.get("godotVersion") or "")
        fingerprint = str(first.get("hostFingerprint") or "")
        commit = str(first.get("commit") or "")
        if godot and fingerprint:
            return {"godotVersion": godot, "hostFingerprint": fingerprint, "commit": commit}
    raise ValueError("cannot recover godotVersion/hostFingerprint from manifests or observations")


def publish_summary(candidates: list[dict[str, Any]], proto: dict[str, Any],
                    host: dict[str, Any], packet: dict[str, Any],
                    identity: dict[str, Any], commit: str, godot: str,
                    live_sha: str, out: Path) -> dict[str, Any]:
    public = [{k: v for k, v in row.items() if not k.startswith("_")} for row in candidates]
    if is_tier1_profile(proto):
        contract = read_json(REPO / str(proto.get("responseContract", RESPONSE_CONTRACT_REL)))
        features = list(contract["packageDiagnostics"]["packages"])
        boot_n = int(proto.get("bootstrap", 1000))
        boot_seed = int(proto.get("bootSeed", 3454))
        effects = package_effects(public, features, boot_n, boot_seed)
        interactions = pairwise_effects(public, features, min(400, boot_n), boot_seed)
        by_id = {row["id"]: row for row in public}
        baseline = next((row for row in public if row.get("id") == "t1-c000"), None)
        for row in public:
            row["decision"] = decide(row, baseline, effects, contract)
            dump(out / row["id"] / "manifest.json",
                 {k: v for k, v in {**by_id.get(row["id"], {}), **row}.items()
                  if not str(k).startswith("_")})
        display = sorted((row for row in public if row.get("validBreadthSum") is not None),
                         key=lambda row: (float(row["validBreadthSum"]), row["id"]))
        summary = {
            "issue": int(proto.get("issue", 491)), "protocol": proto,
            "commit": commit, "godotVersion": godot,
            "liveContentFileSha256": live_sha,
            "searchSpaceSha256": identity["searchSpaceSha256"],
            "seedRegistrySha256": identity["seedRegistrySha256"],
            "driverSha256": identity["driverSha256"], "host": host,
            "hostFingerprint": packet["fingerprint"]["fingerprintHash"],
            "candidates": public,
            "pareto": pareto_ids(public),
            "breadthPareto": breadth_pareto(public),
            "displayOrder": [row["id"] for row in display],
            "displayOrderNote": "sorted by valid-cell C1 breadth deficit for readability, not a score",
            "effects": screening_effects(public),
            "packageEffects": effects,
            "pairwiseEffects": [row for row in interactions if row["excludesZero"]],
            "shortlist": [row["id"] for row in public
                          if (row.get("decision") or {}).get("eligible")],
            "racingSet": list(proto.get("racingSet", RACING_SET)),
        }
        dump(out / "summary.json", summary)
        return summary
    display = sorted((row for row in public if row.get("deficits")),
                     key=lambda row: (row["deficits"]["sum"], row["id"]))
    summary = {
        "issue": int(proto.get("issue", 457)), "protocol": proto,
        "commit": commit, "godotVersion": godot,
        "liveContentFileSha256": live_sha,
        "searchSpaceSha256": identity["searchSpaceSha256"],
        "seedRegistrySha256": identity["seedRegistrySha256"],
        "driverSha256": identity["driverSha256"], "host": host,
        "hostFingerprint": packet["fingerprint"]["fingerprintHash"],
        "candidates": public, "pareto": pareto_ids(public),
        "displayOrder": [row["id"] for row in display],
        "displayOrderNote": "sorted by summed normalised gate deficit for readability, not a score",
        "effects": screening_effects(public),
    }
    dump(out / "summary.json", summary)
    return summary


def self_test() -> int:
    contract = load_contract()
    assert check_invocation(contract, "f0-controls", 5000, 5000, POLICY_ROOT)
    assert check_invocation(contract, "f0-mini-landscape", 6100, 6107, 215)
    assert check_invocation(contract, "f0-controls", 5200, 5200, POLICY_ROOT)
    assert not check_invocation(contract, "f0-controls", 6000, 6031, POLICY_ROOT)
    assert not check_invocation(contract, "f0-mini-landscape", 6100, 6107, POLICY_ROOT)
    proto, axes = protocol(contract), protocol(contract)["frozenLandscape"]
    parts = input_parts(proto, {
        "contentFileSha256": "a" * 64, "contentSemanticSha256": "b" * 64,
        "searchSpaceSha256": "c" * 64, "driverSha256": "d" * 64,
        "seedRegistrySha256": "e" * 64,
        "mobOverrideFileSha256": "m" * 64, "mobOverrideSemanticSha256": "n" * 64,
    }, {"id": "c001", "values": {"flareDamage": 9}, "fileSha256": "f" * 64,
        "semanticSha256": "g" * 64}, "4.7.2.stable", "deadbeef")
    digest = input_hash(parts)
    parts["identity"]["contentFileSha256"] = "0" * 64
    assert input_hash(parts) != digest
    parts["identity"]["contentFileSha256"] = "a" * 64
    parts["identity"]["mobOverrideFileSha256"] = "1" * 64
    assert input_hash(parts) != digest
    row = {"aspect": "duskblade", "vow": 0, "deck": 20, "outcome": "win", "policyIndex": 0,
           "seed": 6100, "fights": [{"shatters": 2, "smolderKills": 0}]}
    assert lean_and_thick(row, axes) == ("shatter", "thin")
    row["deck"] = 26
    assert lean_and_thick(row, axes)[1] == "mid"
    row["deck"] = 36
    assert lean_and_thick(row, axes)[1] == "fat"
    assert lean_and_thick({**row, "fights": [{"shatters": 2, "smolderKills": 1}]}, axes)[0] == "shatter"
    assert lean_and_thick({**row, "fights": [{"shatters": 0, "smolderKills": 0}]}, axes)[0] == "attrition"

    def grid_rows(win_to: int, arm: int) -> list[dict[str, Any]]:
        return [{"arm": arm, "aspect": aspect, "vow": vow, "seed": seed,
                 "outcome": "win" if seed < win_to else "loss", "error": "", "deck": 30, "fights": []}
                for aspect in ASPECTS for vow in VOWS
                for seed in range(CONTROL_SEEDS[0], CONTROL_SEEDS[1] + 1)]

    c000_c = grid_rows(6016, 2) + grid_rows(6016, 1)
    cand_c = grid_rows(6024, 2) + grid_rows(6024, 1)
    fights = [{"shatters": 2, "smolderKills": 0}]
    c000_l, cand_l = [], []
    for aspect in ASPECTS:
        for vow in VOWS:
            for seed in range(LAND_SEEDS[0], LAND_SEEDS[1] + 1):
                c000_l.append({"aspect": aspect, "vow": vow, "seed": seed, "policyIndex": 0,
                               "outcome": "win" if seed < 6104 else "loss", "error": "",
                               "deck": 40, "fights": fights})
                cand_l.append({"aspect": aspect, "vow": vow, "seed": seed, "policyIndex": 0,
                               "outcome": "win" if seed < 6106 else "loss", "error": "",
                               "deck": 40, "fights": fights})
    controls, cells = aggregate_controls(c000_c), aggregate_cells(c000_l, axes)
    proxies = grid_proxies(controls, cells)
    blob = json.dumps({"controls": controls, "cells": cells, "proxies": proxies,
                       "deficits": deficits(proxies)})
    for banned in ("PASS", "FAIL", '"C1a"', '"C1b"', '"C2"', '"verdict"'):
        assert banned not in blob
    assert controls["2:duskblade:v0"]["wins"] == 16
    assert controls["2:duskblade:v0"]["runs"] == 32
    boot = seed_block_bootstrap(by_seed(cand_c), by_seed(cand_l), by_seed(c000_c),
                                by_seed(c000_l), axes, 50, BOOT_SEED)
    assert 0.0 <= boot["vsC000"]["pLowerDeficitSum"] <= 1.0
    assert sum(spec["seeds"] for spec in split_span(6000, 6031, 8)) == 32
    assert sum(spec["policyCount"] for spec in split_count(128, 8)) == 128
    cands = [
        {"id": "c000", "status": "complete", "earlyStop": None,
         "deficits": {"c1a": 2, "c1b": 2, "c2arm": 2, "c2gap": 2, "sum": 8},
         "values": {"flareDamage": 9}},
        {"id": "c001", "status": "complete", "earlyStop": None,
         "deficits": {"c1a": 1, "c1b": 1, "c2arm": 1, "c2gap": 1, "sum": 4},
         "values": {"flareDamage": 11}},
        {"id": "c002", "status": "early-stop", "earlyStop": "errors",
         "deficits": {"c1a": 0, "c1b": 0, "c2arm": 0, "c2gap": 0, "sum": 0},
         "values": {"flareDamage": 7}},
    ]
    assert pareto_ids(cands) == ["c001"]
    split_ok = [
        {"arm": arm, "aspect": aspect, "vow": 0, "seed": 6000, "outcome": outcome,
         "error": "", "deck": 30, "fights": []}
        for arm in RANK_ARMS for aspect, outcome in (("duskblade", "win"), ("ashwarden", "loss"))
    ]
    arm4_stall = split_ok + [{"arm": 4, "aspect": "duskblade", "vow": 0, "seed": 6000,
                              "outcome": "stall", "error": "", "deck": 30, "fights": []}]
    assert control_fault(arm4_stall, 0) == ""
    arm1_stall = split_ok + [{"arm": 1, "aspect": "duskblade", "vow": 0, "seed": 6001,
                              "outcome": "stall", "error": "", "deck": 30, "fights": []}]
    assert control_fault(arm1_stall, 0) == "stalls-beyond-baseline"
    collapse = [{"arm": arm, "aspect": aspect, "vow": 0, "seed": 6000,
                 "outcome": "win" if arm == 1 else "loss"}
                for arm in RANK_ARMS for aspect in ASPECTS]
    assert identity_fault(collapse) == "identity-collapse"
    assert drop_volatile({"wallSeconds": 1, "out": "/tmp/a", "runs": [{"outcome": "win"}]}) == \
        drop_volatile({"wallSeconds": 9, "out": "/tmp/b", "runs": [{"outcome": "win"}]})
    proven = Path(tempfile.mkdtemp(prefix="glassvow-f0-prov-"))
    try:
        obs = proven / "c000" / "observations.jsonl"
        obs.parent.mkdir(parents=True)
        obs.write_text(json.dumps({
            "godotVersion": "4.7.2.stable.official.ed1daf0bf",
            "hostFingerprint": "27a837c0" + "ab" * 28,
            "commit": "deadbeef",
        }, sort_keys=True) + "\n", encoding="utf-8")
        recovered = recover_provenance(proven, [{"id": "c000"}])
        assert recovered["godotVersion"].startswith("4.7.2.stable")
        assert recovered["hostFingerprint"].startswith("27a837c0")
        assert recovered["commit"] == "deadbeef"
    finally:
        shutil.rmtree(proven)
    stale = Path(tempfile.mkdtemp(prefix="glassvow-f0-stale-"))
    try:
        dump(stale / "shard.json", {"manifest": {"contentFileSha256": "nope"}, "runs": [1]})
        assert not controls_complete(stale / "shard.json", 1, "yes")
    finally:
        shutil.rmtree(stale)
    print("balance F0 self-test OK")
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--summarise-only", action="store_true")
    parser.add_argument("--fresh", action="store_true")
    parser.add_argument("--jobs", type=int, default=8)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--protocol", default="", help="versioned protocol registry JSON")
    parser.add_argument("--evaluation", default="", help="evaluation name within --protocol")
    parser.add_argument("--finalist-audit", action="store_true",
                        help="explicitly unseal a registry evaluation marked finalistAudit")
    parser.add_argument("--audit-finalists", default="",
                        help="committed finalist-set receipt required by a sealed audit")
    parser.add_argument("--out", default="/tmp/glassvow-457-f0")
    parser.add_argument("--candidates", default="")
    parser.add_argument("--count", type=int, default=32)
    parser.add_argument("--seed", type=int, default=421)
    parser.add_argument("--boot", type=int, default=None)
    parser.add_argument("--only", default="", help="comma-separated candidate ids")
    parser.add_argument("--inherit", default="",
                        help="prior nested layer output; simulate only disjoint new rectangles")
    parser.add_argument("--replay", default="", help="re-run one candidate into --out")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.self_test:
        return self_test()
    if args.finalist_audit and args.fresh:
        raise ValueError("sealed audit forbids --fresh and any second data-bearing invocation")
    out = Path(args.out)
    prepare_out(out, args.fresh)
    contract = load_contract()
    axes = contract["frozenLandscape"]
    if args.protocol:
        if not args.evaluation:
            raise ValueError("--evaluation is required with --protocol")
        proto = evaluation_from_registry(read_json(Path(args.protocol)), args.evaluation, axes)
    elif args.evaluation:
        raise ValueError("--protocol is required with --evaluation")
    else:
        proto = protocol(contract)
    if args.finalist_audit:
        resolved = evaluation_spec(proto)
        stage = contract["stages"].get(resolved["controlStage"], {})
        audit = stage.get("seeds", {})
        seal = str(stage.get("sealedUntil", ""))
        if not proto.get("finalistAudit") or not seal \
                or resolved["landscapeStage"] != resolved["controlStage"] \
                or resolved["controlFirst"] != int(audit.get("first", -1)) \
                or resolved["controlLast"] != int(audit.get("last", -1)):
            raise ValueError("--finalist-audit requires the full registered finalist audit")
        proto["sealedToken"] = seal
    boot_n = int(args.boot if args.boot is not None else proto.get("bootstrap", 1000))
    live, live_sha = REPO / LIVE_REL, file_sha256(REPO / LIVE_REL)
    live_mobs, live_mobs_sha = REPO / MOBS_REL, file_sha256(REPO / MOBS_REL)
    identity = catalogue_identity(live, REPO / SPACE_REL)
    identity["seedRegistrySha256"] = file_sha256(REPO / CONTRACT_REL)
    commit = git_head()
    wanted = [part for part in args.only.split(",") if part]
    inherit_path = Path(args.inherit) if args.inherit else None
    inherit_proto: dict[str, Any] | None = None
    if inherit_path is not None:
        inherit_summary = read_json(inherit_path / "summary.json")
        inherit_proto = inherit_summary.get("protocol")
        if not isinstance(inherit_proto, dict):
            raise ValueError("--inherit summary has no protocol")
    doe_path = Path(args.candidates) if args.candidates else out / "doe"
    count = int(proto.get("candidateCount") or args.count)
    seed = int(proto.get("candidateSeed") or args.seed)
    source = str(proto.get("candidateSource") or "doe")
    manifest = ensure_candidates(doe_path, count, seed, source)
    if proto.get("candidateManifest"):
        validate_candidate_manifest(
            manifest, read_json(REPO / str(proto["candidateManifest"])))
    identity["searchSpaceSha256"] = str(manifest.get("registryIdentity", {}).get("fileSha256", identity["searchSpaceSha256"]))
    if args.summarise_only:
        rows = [read_json(out / row["id"] / "manifest.json")
                for row in manifest["candidates"]
                if (out / row["id"] / "manifest.json").is_file()]
        provenance = recover_provenance(out, rows)
        host = host_identity(args.jobs)
        packet = {"fingerprint": {"fingerprintHash": provenance["hostFingerprint"]}}
        summary = publish_summary(rows, proto, host, packet, identity, provenance["commit"],
                                  provenance["godotVersion"], live_sha, out)
        print(json.dumps({"pareto": summary["pareto"], "n": len(rows),
                          "godotVersion": provenance["godotVersion"],
                          "hostFingerprint": provenance["hostFingerprint"][:16]}, sort_keys=True))
        return 0
    godot_version = require_godot(args.godot)
    host = host_identity(args.jobs)
    packets = tuple(proto["hostPackets"]) if proto.get("hostPackets") else (
        HOST_PACKETS_TIER1 if is_tier1_profile(proto) else HOST_PACKETS)
    packet = qualified_packet(host, godot_version, packets)
    baseline_ids = [row["id"] for row in manifest["candidates"] if row.get("baseline")]
    if len(baseline_ids) != 1: raise ValueError("candidate manifest must identify exactly one baseline")
    baseline_id = baseline_ids[0]; names = [args.replay] if args.replay else (wanted or [row["id"] for row in manifest["candidates"]])
    if args.finalist_audit:
        if not args.audit_finalists or args.replay or args.inherit or not wanted:
            raise ValueError("sealed audit requires its finalist set and exact --only invocation")
        finalist_path = Path(args.audit_finalists)
        finalist_packet = validate_audit_finalist_set(
            finalist_path, Path(args.protocol), read_json(Path(args.protocol)),
            manifest, wanted, out)
        create_audit_receipt(out, finalist_path, finalist_packet, Path(args.protocol))
    by_id = {row["id"]: row for row in manifest["candidates"]}; baseline: dict[str, Any] | None = None
    if baseline_id not in names and (out / baseline_id / "manifest.json").is_file(): baseline = attach_raw(read_json(out / baseline_id / "manifest.json"), out / baseline_id)
    ordered = [baseline_id] + [name for name in names if name != baseline_id] if baseline_id in names else names
    results: list[dict[str, Any]] = []
    for name in ordered:
        if name not in by_id:
            raise ValueError(f"unknown candidate {name}")
        row = evaluate_candidate(
            args.godot, args.jobs, doe_path, by_id[name], out, proto,
            str(packet["fingerprint"]["fingerprintHash"]), commit, godot_version,
            not args.fresh, baseline, boot_n, axes, inherit_path, inherit_proto)
        if name == baseline_id:
            baseline = row
        results.append(row)
        if file_sha256(live) != live_sha:
            raise RuntimeError("live content/full-content.json changed during F0")
        if file_sha256(live_mobs) != live_mobs_sha:
            raise RuntimeError("live content/mob-overrides.json changed during F0")
    if args.replay:
        print(json.dumps({"id": args.replay, "observationsSha256": results[0]["observationsSha256"],
                          "status": results[0]["status"]}, sort_keys=True))
        return 0
    if wanted:
        print(json.dumps({
            "complete": sum(1 for row in results if row["status"] == "complete"),
            "earlyStop": sum(1 for row in results if row["status"] == "early-stop"),
            "ids": [row["id"] for row in results],
        }, indent=2, sort_keys=True))
        return 0
    summary = publish_summary(results, proto, host, packet, identity, commit, godot_version,
                              live_sha, out)
    print(json.dumps({
        "complete": sum(1 for row in results if row["status"] == "complete"),
        "earlyStop": sum(1 for row in results if row["status"] == "early-stop"),
        "pareto": summary["pareto"],
        "displayOrder": summary["displayOrder"][:8],
        "liveUnchanged": file_sha256(live) == live_sha,
    }, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (KeyError, OSError, TypeError, ValueError, RuntimeError) as exc:
        print(f"balance_f0: {exc}", file=sys.stderr)
        raise SystemExit(2) from exc
