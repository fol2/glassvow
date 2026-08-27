#!/usr/bin/env python3
"""Deterministic Phase-C package synthesis for Glassvow issue #525."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
import random
import shutil
import sqlite3
import statistics
import subprocess
from collections import defaultdict
from pathlib import Path

import numpy as np
from scipy.stats import qmc
from sklearn.ensemble import ExtraTreesRegressor
from sklearn.linear_model import Ridge


ROOT = Path("/Users/jamesto/Research/glassvow-mechanism-package-synthesis")
SOURCE = ROOT / "source"
RUNNER = ROOT / "tools/mechanism_probe.gd"
LEDGER = ROOT / "ledger/experiments-v1.sqlite"
CACHE = ROOT / "cache/sha256"
CONTENT = SOURCE / "content/full-content.json"
GRAMMAR = ROOT / "artifacts/design-grammar-v1.json"
PREREG = ROOT / "protocols/preregistration-v1.json"
POLICIES = Path("/Users/jamesto/Research/glassvow-codesign-520/work/detector3-policies-confirmatory-v1.ndjson")
SOURCE_COMMIT = "0f005282e8881d970da284f4868caedf60cc8142"
GODOT_VERSION = "4.7.2.stable.official.ed1daf0bf"
PREREG_SHA256 = "e493981086c63da2cff05c3abd170e44cdc4d231faab7c82d1d903aadbe883d4"
RUNNER_SHA256 = "a11e959070f47cee8ff00dc3d7df67d255d3d7d90e3418337e918e256fa14a05"
SCREEN_SEEDS = tuple(range(23000, 23004))
DISCOVERY_SEEDS = tuple(range(23000, 23032))
VALIDATION_SEEDS = tuple(range(23100, 23132))
CONTEXTS = (
    ("act1-mixed", ["duskfang", "sporeling"], "normal"),
    ("act1-solo", ["ashAcolyte"], "normal"),
    ("act1-elite", ["gravewarden"], "elite"),
    ("act2-mixed", ["drownedOne", "mirelurker"], "normal"),
)

PACKAGES = {
    "hand-size-payoff-positive-control": {
        "family": "hand-size-payoff-positive-control", "package": "hand-size-payoff",
        "aspect": "ashwarden", "nodes": ("preparation", "surge", "phantomBlades"),
        "response": "directDamage", "edges": (
            {"id": "preparation->phantomBlades", "producer": "preparation",
             "consumer": "phantomBlades", "probe": "hand"},
            {"id": "surge->phantomBlades", "producer": "surge",
             "consumer": "phantomBlades", "probe": "hand"},
        ),
    },
    "ash-poison-catalyst-l1": {
        "family": "ash-poison-catalyst-l1", "package": "ash-poison-catalyst",
        "aspect": "ashwarden", "nodes": ("venomStrike", "toxicMist", "catalyst"),
        "response": "poisonApplied", "edges": (
            {"id": "venomStrike->catalyst", "producer": "venomStrike",
             "consumer": "catalyst", "probe": "poison"},
            {"id": "toxicMist->catalyst", "producer": "toxicMist",
             "consumer": "catalyst", "probe": "poison"},
        ),
    },
    "ward-double-l1": {
        "family": "ward-double-l1", "package": "ward-double",
        "aspect": "duskblade", "nodes": ("brace", "bulwark", "fortify"),
        "response": "blockGain", "edges": (
            {"id": "brace->fortify", "producer": "brace",
             "consumer": "fortify", "probe": "block"},
            {"id": "bulwark->fortify", "producer": "bulwark",
             "consumer": "fortify", "probe": "block"},
        ),
    },
    "dusk-kindle-draw-l1": {
        "family": "dusk-kindle-draw-l1", "package": "kindle-draw",
        "aspect": "duskblade", "nodes": ("firstSpark", "offering", "verdantBranch"),
        "response": "draw", "edges": (
            {"id": "firstSpark->verdantBranch", "producer": "firstSpark",
             "consumer": "verdantBranch", "probe": "branch"},
            {"id": "offering->verdantBranch", "producer": "offering",
             "consumer": "verdantBranch", "probe": "branch"},
        ),
    },
}


def canonical(value: object) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def digest(value: object) -> str:
    return hashlib.sha256(canonical(value).encode()).hexdigest()


def file_sha256(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(block)
    return value.hexdigest()


def write_json_once(path: Path, value: object) -> None:
    text = json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    if path.exists():
        if path.read_text() != text:
            raise RuntimeError(f"immutable output drift: {path}")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


def open_ledger() -> sqlite3.Connection:
    connection = sqlite3.connect(LEDGER, timeout=60)
    connection.execute("pragma journal_mode=wal")
    if connection.execute("pragma integrity_check").fetchone()[0] != "ok":
        raise RuntimeError("ledger integrity failure")
    return connection


def record(connection: sqlite3.Connection, stage: str, payload: object) -> None:
    raw = canonical(payload)
    identity = digest({"stage": stage, "payload": payload})
    previous = connection.execute(
        "select payload from event where identity_sha256=?", (identity,)
    ).fetchone()
    if previous is not None:
        if previous[0] != raw:
            raise RuntimeError(f"event identity collision: {stage}")
        return
    connection.execute(
        "insert into event(stage,identity_sha256,payload) values(?,?,?)",
        (stage, identity, raw),
    )
    connection.commit()


def verify_authority() -> None:
    if file_sha256(PREREG) != PREREG_SHA256 or file_sha256(RUNNER) != RUNNER_SHA256:
        raise RuntimeError("preregistration or mechanism runner drift")
    checks = (
        (["git", "rev-parse", "HEAD"], SOURCE_COMMIT),
        (["git", "branch", "--show-current"], ""),
        (["godot", "--version"], GODOT_VERSION),
    )
    for args, expected in checks:
        result = subprocess.run(args, cwd=SOURCE, text=True, capture_output=True, check=True)
        if result.stdout.strip() != expected:
            raise RuntimeError(f"authority drift: {' '.join(args)}")
    prereg = json.loads(PREREG.read_text())
    if file_sha256(CONTENT) != prereg["identities"]["contentSha256"]:
        raise RuntimeError("base content drift")
    excluded = open_ledger().execute("select count(*) from exclusion").fetchone()[0]
    if excluded != 504:
        raise RuntimeError("excluded identity cohort drift")


def pointer_get(root: object, pointer: str) -> object:
    value = root
    for component in pointer.strip("/").split("/"):
        value = value[int(component)] if isinstance(value, list) else value[component]
    return value


def pointer_set(root: object, pointer: str, replacement: object) -> None:
    components = pointer.strip("/").split("/")
    value = root
    for component in components[:-1]:
        value = value[int(component)] if isinstance(value, list) else value[component]
    final = components[-1]
    if isinstance(value, list):
        value[int(final)] = replacement
    else:
        value[final] = replacement


def synchronise_rarity(root: dict, kind: str, item_id: str, rarity: str) -> None:
    pool_key = "cardPools" if kind == "cards" else "relicPools"
    pools = root[pool_key]
    original = json.loads(CONTENT.read_text())[pool_key]
    order = [item for tier in original.values() for item in tier]
    order_index = {item: index for index, item in enumerate(order)}
    for ids in pools.values():
        while item_id in ids:
            ids.remove(item_id)
    pools[rarity].append(item_id)
    pools[rarity].sort(key=lambda item: (order_index.get(item, len(order)), item))


def valid_parameters(parameters: dict[str, object]) -> bool:
    pairs = (
        ("/cards/catalyst/effects/0/n", "/cards/catalyst/up/effects/0/n"),
        ("/cards/toxicMist/effects/0/n", "/cards/toxicMist/up/effects/0/n"),
        ("/cards/brace/effects/0/n", "/cards/brace/up/effects/0/n"),
        ("/cards/bulwark/effects/0/n", "/cards/bulwark/up/effects/0/n"),
        ("/cards/firstSpark/effects/0/n", "/cards/firstSpark/up/effects/0/n"),
        ("/cards/offering/effects/0/draw", "/cards/offering/up/effects/0/draw"),
    )
    return all(left not in parameters or right not in parameters
               or int(parameters[right]) >= int(parameters[left]) for left, right in pairs)


def candidate_pool() -> list[dict]:
    grammar = json.loads(GRAMMAR.read_text())
    base = json.loads(CONTENT.read_text())
    out: list[dict] = []
    for family_index, family in enumerate(grammar["families"]):
        if family["id"].endswith("positive-control"):
            continue
        choices = family["parameters"]
        paths = sorted(choices)
        points = qmc.Sobol(len(paths), scramble=True, seed=525 + family_index).random_base2(7)
        samples: list[tuple[str, dict]] = []
        seen: set[str] = set()
        for point in points:
            parameters = {
                path: choices[path][min(int(point[index] * len(choices[path])), len(choices[path]) - 1)]
                for index, path in enumerate(paths)
            }
            key = canonical(parameters)
            if key not in seen and valid_parameters(parameters):
                seen.add(key)
                samples.append(("sobol", parameters))
            if len(samples) == 8:
                break
        generator = random.Random(52500 + family_index)
        random_count = 0
        while random_count < 8:
            parameters = {path: generator.choice(choices[path]) for path in paths}
            key = canonical(parameters)
            if key in seen or not valid_parameters(parameters):
                continue
            seen.add(key)
            samples.append(("random", parameters))
            random_count += 1
        for method, parameters in samples:
            candidate_id = digest({"family": family["id"], "parameters": parameters})
            candidate = copy.deepcopy(base)
            for pointer, value in parameters.items():
                pointer_set(candidate, pointer, value)
                bits = pointer.strip("/").split("/")
                if bits[-1] == "rarity":
                    synchronise_rarity(candidate, bits[0], bits[1], str(value))
            path = ROOT / "candidates" / f"{candidate_id}.json"
            write_json_once(path, candidate)
            changed = sum(pointer_get(base, pointer) != value for pointer, value in parameters.items())
            distance = 0.0
            for pointer, value in parameters.items():
                values = choices[pointer]
                current = pointer_get(base, pointer)
                if current in values and value in values and len(values) > 1:
                    distance += abs(values.index(value) - values.index(current)) / (len(values) - 1)
            out.append({
                "id": candidate_id, "family": family["id"], "method": method,
                "parameters": parameters, "contentPath": str(path),
                "contentSha256": file_sha256(path), "changedFields": changed,
                "normalisedL1": distance,
            })
    if len(out) != 48 or len({row["id"] for row in out}) != 48:
        raise RuntimeError("candidate generation did not produce 48 unique candidates")
    return out


def freeze_candidates(connection: sqlite3.Connection) -> list[dict]:
    candidates = candidate_pool()
    for row in candidates:
        path = Path(row["contentPath"])
        identity = digest({"kind": "candidate-content", "sha256": row["contentSha256"]})
        connection.execute(
            "insert or ignore into object values(?,525,'candidate-content',?,?,?)",
            (identity, row["contentSha256"], str(path.relative_to(ROOT)), path.stat().st_size),
        )
    connection.commit()
    freeze = {"schemaVersion": 1, "issue": 525, "candidateCount": len(candidates),
              "candidates": candidates}
    write_json_once(ROOT / "artifacts/phase-c-level1-candidate-freeze-v1.json", freeze)
    return candidates


def all_unlocks(content: dict) -> list[str]:
    values = ["aspect2"]
    for deed in content["deeds"].values():
        values.extend(str(value) for value in deed.get("unlocks", []))
    return sorted(set(values))


def controlled_row(package: dict, edge: dict, seed: int, split: str, treated: bool) -> dict:
    setup: dict = {"energy": 20, "enemyHp": 30}
    actions: list[dict] = []
    hand_fill: list[str] = []
    draw_fill: list[str] = []
    relics: list[str] = []
    if edge["probe"] == "poison":
        setup["enemyStatus"] = {"poison": 8 if treated else 0}
        actions = [{"card": edge["consumer"]}]
    elif edge["probe"] == "block":
        setup["block"] = 12 if treated else 0
        actions = [{"card": "fortify"}]
    elif edge["probe"] == "branch":
        actions = [{"card": edge["producer"]}]
        hand_fill = ["defend", "strike", "defend"] if edge["producer"] == "offering" else []
        draw_fill = ["strike"] * 8
        relics = ["verdantBranch"] if treated else []
    elif edge["probe"] == "hand":
        actions = [{"card": "phantomBlades"}]
        hand_fill = ["unreadablePage"] * (4 if treated else 0)
    else:
        raise RuntimeError(f"unsupported probe: {edge['probe']}")
    return {
        "id": f"controlled:{package['package']}:{edge['id']}:{split}:{seed}:{int(treated)}",
        "stage": "controlled", "package": package["package"], "edge": edge["id"],
        "arm": "mediator" if treated else "control", "split": split,
        "context": edge["probe"], "aspect": package["aspect"], "seed": seed,
        "response": package["response"], "mode": "scripted",
        "deck": ["strike"] * 5 + ["defend"] * 5, "relics": relics,
        "actions": actions, "handFill": hand_fill, "drawFill": draw_fill, "setup": setup,
    }


def micro_row(package: dict, edge: dict, seed: int, split: str, context_index: int,
              arm: str) -> dict:
    context, enemies, kind = CONTEXTS[context_index]
    deck = ["strike"] * 5 + ["defend"] * 5
    relics: list[str] = []
    if arm in {"A", "AB"}:
        deck[0:2] = [edge["producer"]] * 2
    if arm in {"B", "AB"}:
        if edge["consumer"] == "verdantBranch":
            relics.append(edge["consumer"])
        else:
            deck[2:4] = [edge["consumer"]] * 2
    return {
        "id": f"micro:{package['package']}:{edge['id']}:{split}:{seed}:{context_index}:{arm}",
        "stage": "microdeck", "package": package["package"], "edge": edge["id"],
        "arm": arm, "split": split, "context": context, "aspect": package["aspect"],
        "seed": seed, "response": package["response"], "mode": "pilot", "maxTurns": 20,
        "deck": deck, "relics": relics, "enemies": enemies, "kind": kind,
    }


def panel_row(package: dict, content: dict, seed: int, split: str, context_index: int,
              arm: str) -> dict:
    context, enemies, kind = CONTEXTS[context_index]
    aspect = next(row for row in content["aspects"] if row["id"] == package["aspect"])
    base_deck = list(aspect["startDeck"])
    card_nodes = [node for node in package["nodes"] if node in content["cards"]]
    relic_nodes = [node for node in package["nodes"] if node in content["relics"]]
    package_deck = [node for node in card_nodes for _ in range(2)]
    package_deck.extend(base_deck[:10 - len(package_deck)])
    return {
        "id": f"panel:{package['package']}:{split}:{seed}:{context_index}:{arm}",
        "stage": "panel", "package": package["package"], "edge": "", "arm": arm,
        "split": split, "context": context, "aspect": package["aspect"], "seed": seed,
        "response": package["response"], "mode": "pilot", "maxTurns": 25,
        "deck": base_deck if arm == "baseline" else package_deck,
        "relics": [aspect["startRelic"]] if arm == "baseline"
        else [aspect["startRelic"], *relic_nodes],
        "enemies": enemies, "kind": kind,
    }


def plan(candidate: dict, seeds_by_split: dict[str, tuple[int, ...]], fidelity: str) -> dict:
    package = PACKAGES[candidate["family"]]
    content = json.loads(Path(candidate["contentPath"]).read_text())
    rows: list[dict] = []
    for split, seeds in seeds_by_split.items():
        for seed in seeds:
            for edge in package["edges"]:
                rows.extend(controlled_row(package, edge, seed, split, treated)
                            for treated in (False, True))
                for context_index in range(len(CONTEXTS)):
                    rows.extend(micro_row(package, edge, seed, split, context_index, arm)
                                for arm in ("00", "A", "B", "AB"))
            for context_index in range(len(CONTEXTS)):
                rows.extend(panel_row(package, content, seed, split, context_index, arm)
                            for arm in ("baseline", "package"))
    unlocks = all_unlocks(content)
    for row in rows:
        row["unlocks"] = unlocks
    return {
        "schemaVersion": 1, "issue": 525, "stage": fidelity,
        "sourceCommit": SOURCE_COMMIT, "candidateId": candidate["id"],
        "content": candidate["contentPath"], "rows": rows,
    }


def register_object(connection: sqlite3.Connection, identity: str, kind: str, path: Path) -> Path:
    sha = file_sha256(path)
    target = CACHE / sha
    CACHE.mkdir(parents=True, exist_ok=True)
    if not target.exists():
        shutil.copy2(path, target)
    if file_sha256(target) != sha or target.stat().st_size != path.stat().st_size:
        raise RuntimeError(f"cache drift: {sha}")
    connection.execute(
        "insert or ignore into object values(?,525,?,?,?,?)",
        (identity, kind, sha, str(target.relative_to(ROOT)), target.stat().st_size),
    )
    connection.commit()
    return target


def run_plan(connection: sqlite3.Connection, candidate: dict, plan_value: dict,
             fidelity: str) -> list[dict]:
    plan_sha = digest(plan_value)
    plan_path = ROOT / "work/batches" / f"{plan_sha}.plan.json"
    write_json_once(plan_path, plan_value)
    batch_identity = digest({
        "kind": "mechanism-batch", "planSha256": file_sha256(plan_path),
        "runnerSha256": RUNNER_SHA256, "sourceCommit": SOURCE_COMMIT,
        "godotVersion": GODOT_VERSION, "contentSha256": candidate["contentSha256"],
    })
    object_identity = digest({"kind": "mechanism-output", "batchIdentity": batch_identity})
    cached = connection.execute(
        "select relative_path,sha256,bytes from object where identity_sha256=?", (object_identity,)
    ).fetchone()
    if cached is None:
        output = ROOT / "work/batches" / f"{batch_identity}.output.json"
        if not output.exists():
            result = subprocess.run(
                ["godot", "--headless", "--path", str(SOURCE), "-s", str(RUNNER), "--",
                 f"--plan={plan_path}", f"--out={output}"],
                cwd=ROOT, text=True, capture_output=True,
            )
            if result.returncode:
                raise RuntimeError(f"Godot batch failed: {result.stdout[-1000:]}\n{result.stderr[-4000:]}")
        payload = json.loads(output.read_text())
        if payload.get("planSha256") != file_sha256(plan_path) \
                or payload.get("runnerSha256") != RUNNER_SHA256 \
                or len(payload.get("rows", [])) != len(plan_value["rows"]):
            raise RuntimeError("completed batch identity mismatch")
        cache_path = register_object(connection, object_identity, "mechanism-output", output)
    else:
        cache_path = ROOT / cached[0]
        if cache_path.stat().st_size != cached[2] or file_sha256(cache_path) != cached[1]:
            raise RuntimeError("cached batch drift")
        payload = json.loads(cache_path.read_text())
    specs = {row["id"]: row for row in plan_value["rows"]}
    excluded = {row[0] for row in connection.execute("select identity_sha256 from exclusion")}
    semantic = payload["contentIdentity"]["contentSemanticSha256"]
    for row in payload["rows"]:
        spec = specs[row["id"]]
        identity = digest({
            "sourceCommit": SOURCE_COMMIT, "godotVersion": GODOT_VERSION,
            "runnerSha256": RUNNER_SHA256, "contentSemanticSha256": semantic,
            "fidelity": fidelity, "spec": spec,
        })
        if identity in excluded:
            raise RuntimeError("excluded issue-519 identity reappeared")
        raw = canonical({**row, "identitySha256": identity,
                         "contentSemanticSha256": semantic})
        previous = connection.execute(
            "select row_json from sim_row where identity_sha256=?", (identity,)
        ).fetchone()
        if previous is not None:
            if previous[0] != raw:
                raise RuntimeError("simulator identity collision")
            continue
        connection.execute(
            "insert into sim_row values(?,525,1,?,?,?,?,?,?,?)",
            (identity, candidate["family"], candidate["id"], digest(spec.get("policy", {})),
             f"{row['aspect']}:v0", int(row["seed"]), fidelity, raw),
        )
    connection.commit()
    return payload["rows"]


def response(row: dict, metric: str | None = None) -> float:
    key = metric or row["response"]
    if key == "win":
        return 1.0 if row["outcome"] == "win" else 0.0
    if key == "stall":
        return 1.0 if row["outcome"] == "stall" else 0.0
    if key == "error":
        return 1.0 if row.get("error") or row["outcome"] == "error" else 0.0
    if key == "turns":
        return float(row["turns"])
    return float(row["totals"].get(key, 0))


def quantile(values: list[float], probability: float) -> float:
    ordered = sorted(values)
    position = (len(ordered) - 1) * probability
    lower = math.floor(position)
    upper = math.ceil(position)
    if lower == upper:
        return ordered[lower]
    return ordered[lower] * (upper - position) + ordered[upper] * (position - lower)


def bootstrap_summary(deltas: list[float], values: list[float], label: str) -> dict:
    scale = statistics.pstdev(values) or 1.0
    generator = random.Random(int(digest(label)[:16], 16))
    boots = [statistics.fmean(generator.choices(deltas, k=len(deltas))) for _ in range(5000)]
    delta = statistics.fmean(deltas)
    return {
        "pairs": len(deltas), "delta": delta, "scale": scale,
        "standardisedDelta": delta / scale,
        "pairedBootstrapP05": quantile(boots, 0.05),
        "pairedBootstrapP95": quantile(boots, 0.95),
    }


def interaction_models(rows: list[dict], metric: str) -> tuple[float, float]:
    contexts = sorted({row["context"] for row in rows})
    context_index = {value: index for index, value in enumerate(contexts)}
    x: list[list[float]] = []
    y: list[float] = []
    for row in rows:
        a = 1.0 if row["arm"] in {"A", "AB"} else 0.0
        b = 1.0 if row["arm"] in {"B", "AB"} else 0.0
        one_hot = [0.0] * len(contexts)
        one_hot[context_index[row["context"]]] = 1.0
        x.append([1.0, a, b, a * b, *one_hot])
        y.append(response(row, metric))
    matrix = np.asarray(x)
    target = np.asarray(y)
    ridge = float(Ridge(alpha=1.0, fit_intercept=False).fit(matrix, target).coef_[3])
    forest = ExtraTreesRegressor(n_estimators=256, random_state=525, max_features=None)
    forest.fit(matrix[:, [1, 2, *range(4, matrix.shape[1])]], target)
    effects = []
    for context in contexts:
        one_hot = [0.0] * len(contexts)
        one_hot[context_index[context]] = 1.0
        predictions = {}
        for arm, a, b in (("00", 0.0, 0.0), ("A", 1.0, 0.0),
                          ("B", 0.0, 1.0), ("AB", 1.0, 1.0)):
            predictions[arm] = float(forest.predict(np.asarray([[a, b, *one_hot]]))[0])
        effects.append(predictions["AB"] - predictions["A"] - predictions["B"] + predictions["00"])
    return ridge, statistics.fmean(effects)


def paired_arm_summary(rows: list[dict], left: str, right: str, metric: str,
                       label: str) -> dict:
    arms: dict[str, dict[tuple[int, str], dict]] = defaultdict(dict)
    for row in rows:
        arms[row["arm"]][(int(row["seed"]), row["context"])] = row
    keys = sorted(set(arms[left]) & set(arms[right]))
    left_values = [response(arms[left][key], metric) for key in keys]
    right_values = [response(arms[right][key], metric) for key in keys]
    return bootstrap_summary([b - a for a, b in zip(left_values, right_values)],
                             [*left_values, *right_values], label)


def analyse(rows: list[dict], family: str, strict: bool) -> dict:
    package = PACKAGES[family]
    controlled_checks = {}
    edge_checks = {}
    panel_checks = {}
    splits = sorted({row["split"] for row in rows})
    for split in splits:
        for edge in package["edges"]:
            controlled = [row for row in rows if row["stage"] == "controlled"
                          and row["split"] == split and row["edge"] == edge["id"]]
            controlled_summary = paired_arm_summary(
                controlled, "control", "mediator", package["response"],
                f"controlled:{family}:{edge['id']}:{split}",
            )
            controlled_summary["pass"] = (controlled_summary["delta"] > 0
                                                   and controlled_summary["pairedBootstrapP05"] > 0)
            controlled_checks[f"{edge['id']}|{split}"] = controlled_summary
            micro = [row for row in rows if row["stage"] == "microdeck"
                     and row["split"] == split and row["edge"] == edge["id"]]
            by_key: dict[tuple[int, str], dict[str, dict]] = defaultdict(dict)
            for row in micro:
                by_key[(int(row["seed"]), row["context"])][row["arm"]] = row
            deltas: list[float] = []
            values: list[float] = []
            for arms in by_key.values():
                if set(arms) != {"00", "A", "B", "AB"}:
                    raise RuntimeError("incomplete A/B/AB contrast")
                values.extend(response(arms[arm], package["response"])
                              for arm in ("00", "A", "B", "AB"))
                deltas.append(response(arms["AB"], package["response"])
                              - response(arms["A"], package["response"])
                              - response(arms["B"], package["response"])
                              + response(arms["00"], package["response"]))
            summary = bootstrap_summary(deltas, values, f"micro:{family}:{edge['id']}:{split}")
            ridge, forest = interaction_models(micro, package["response"])
            summary.update({"ridgeInteractionCoefficient": ridge,
                            "extraTreesInteraction": forest,
                            "controlledProbePass": controlled_summary["pass"]})
            summary["pass"] = (controlled_summary["pass"]
                               and summary["standardisedDelta"] >= 0.25
                               and summary["pairedBootstrapP05"] > 0
                               and ridge > 0 and forest > 0)
            edge_checks[f"{edge['id']}|{split}"] = summary
        panel = [row for row in rows if row["stage"] == "panel" and row["split"] == split]
        activation = paired_arm_summary(panel, "baseline", "package", package["response"],
                                        f"panel:{family}:{split}:activation")
        turns = paired_arm_summary(panel, "baseline", "package", "turns",
                                   f"panel:{family}:{split}:turns")
        win = paired_arm_summary(panel, "baseline", "package", "win",
                                 f"panel:{family}:{split}:win")
        stall = paired_arm_summary(panel, "baseline", "package", "stall",
                                   f"panel:{family}:{split}:stall")
        error = paired_arm_summary(panel, "baseline", "package", "error",
                                   f"panel:{family}:{split}:error")
        edges_pass = all(edge_checks[f"{edge['id']}|{split}"]["pass"]
                         for edge in package["edges"])
        panel_pass = (activation["standardisedDelta"] >= 0.25
                      and activation["pairedBootstrapP05"] > 0
                      and turns["delta"] <= 1.0 and stall["delta"] <= 0
                      and error["delta"] <= 0 and win["delta"] >= 0)
        panel_checks[split] = {
            "activation": activation, "turns": turns, "win": win, "stall": stall,
            "error": error, "bothEdgesPass": edges_pass, "panelPass": panel_pass,
            "packagePass": edges_pass and panel_pass,
        }
    discovery_edges = [edge_checks[f"{edge['id']}|discovery"]["standardisedDelta"]
                       for edge in package["edges"]]
    discovery_panel = panel_checks["discovery"]
    score = (min(discovery_edges) + discovery_panel["activation"]["standardisedDelta"]
             - max(0.0, discovery_panel["turns"]["delta"])
             - 10.0 * max(0.0, discovery_panel["stall"]["delta"])
             - 10.0 * max(0.0, discovery_panel["error"]["delta"]))
    admitted = strict and all(panel_checks[split]["packagePass"] for split in splits)
    return {
        "family": family, "package": package["package"], "aspect": package["aspect"],
        "rows": len(rows), "strict": strict, "score": score,
        "controlled": controlled_checks, "edges": edge_checks, "panels": panel_checks,
        "admittedAtProbePanelGate": admitted,
    }


def base_candidate() -> dict:
    return {
        "id": digest({"family": "hand-size-payoff-positive-control",
                      "contentSha256": file_sha256(CONTENT)}),
        "family": "hand-size-payoff-positive-control", "method": "positive-control",
        "parameters": {}, "contentPath": str(CONTENT), "contentSha256": file_sha256(CONTENT),
        "changedFields": 0, "normalisedL1": 0.0,
    }


def run_positive_control(connection: sqlite3.Connection) -> dict:
    candidate = base_candidate()
    fidelity = "issue-525-phase-c-positive-control-v1"
    rows = run_plan(connection, candidate, plan(candidate, {
        "discovery": DISCOVERY_SEEDS, "validation": VALIDATION_SEEDS,
    }, fidelity), fidelity)
    result = analyse(rows, candidate["family"], strict=True)
    result["candidateId"] = candidate["id"]
    write_json_once(ROOT / "artifacts/phase-c-positive-control-v1.json", result)
    record(connection, "phase-c-positive-control", {
        "candidateId": candidate["id"], "rows": len(rows),
        "pass": result["admittedAtProbePanelGate"],
    })
    if not result["admittedAtProbePanelGate"]:
        raise RuntimeError("preregistered hand-size positive control did not reproduce")
    return result


def screen() -> dict:
    verify_authority()
    connection = open_ledger()
    positive = run_positive_control(connection)
    candidates = freeze_candidates(connection)
    compact: list[dict] = []
    for index, candidate in enumerate(candidates, start=1):
        fidelity = "issue-525-phase-c-level1-screen-v1"
        rows = run_plan(connection, candidate, plan(candidate, {"discovery": SCREEN_SEEDS},
                                                    fidelity), fidelity)
        result = analyse(rows, candidate["family"], strict=False)
        compact.append({
            "candidateId": candidate["id"], "family": candidate["family"],
            "method": candidate["method"], "parameters": candidate["parameters"],
            "contentSha256": candidate["contentSha256"], "changedFields": candidate["changedFields"],
            "normalisedL1": candidate["normalisedL1"], "rows": len(rows),
            "score": result["score"], "edges": result["edges"], "panels": result["panels"],
        })
        if index % 8 == 0:
            print(canonical({"stage": "screen", "complete": index, "total": len(candidates)}),
                  flush=True)
    recommendations = []
    for family in sorted({row["family"] for row in compact}):
        for method in ("sobol", "random"):
            group = [row for row in compact if row["family"] == family and row["method"] == method]
            chosen = max(group, key=lambda row: (row["score"], -row["changedFields"],
                                                 -row["normalisedL1"], row["candidateId"]))
            recommendations.append({key: chosen[key] for key in (
                "candidateId", "family", "method", "parameters", "contentSha256",
                "changedFields", "normalisedL1", "score")})
    result = {
        "schemaVersion": 1, "issue": 525, "decision": "VALIDATE_MATCHED_METHOD_RECOMMENDATIONS",
        "positiveControl": {"candidateId": positive["candidateId"], "rows": positive["rows"],
                            "pass": positive["admittedAtProbePanelGate"]},
        "candidateCount": len(candidates), "screenRows": sum(row["rows"] for row in compact),
        "recommendations": recommendations, "candidates": compact,
    }
    write_json_once(ROOT / "artifacts/phase-c-level1-screen-v1.json", result)
    record(connection, "phase-c-level1-screen", {
        "candidateCount": len(candidates), "rows": result["screenRows"],
        "recommendations": [row["candidateId"] for row in recommendations],
    })
    print(canonical({"decision": result["decision"], "positiveControl": True,
                     "screenRows": result["screenRows"], "recommendations": recommendations}))
    return result


def validate() -> dict:
    verify_authority()
    connection = open_ledger()
    screen_result = json.loads((ROOT / "artifacts/phase-c-level1-screen-v1.json").read_text())
    candidates = {row["id"]: row for row in freeze_candidates(connection)}
    results = []
    for recommendation in screen_result["recommendations"]:
        candidate = candidates[recommendation["candidateId"]]
        fidelity = "issue-525-phase-c-level1-validation-v1"
        rows = run_plan(connection, candidate, plan(candidate, {
            "discovery": DISCOVERY_SEEDS, "validation": VALIDATION_SEEDS,
        }, fidelity), fidelity)
        analysed = analyse(rows, candidate["family"], strict=True)
        results.append({
            "candidateId": candidate["id"], "family": candidate["family"],
            "method": candidate["method"], "parameters": candidate["parameters"],
            "contentSha256": candidate["contentSha256"], "changedFields": candidate["changedFields"],
            "normalisedL1": candidate["normalisedL1"], **analysed,
        })
        print(canonical({"stage": "validation", "family": candidate["family"],
                         "method": candidate["method"],
                         "pass": analysed["admittedAtProbePanelGate"]}), flush=True)
    selected = []
    method_race = []
    for family in sorted({row["family"] for row in results}):
        group = [row for row in results if row["family"] == family]
        method_race.append({
            "family": family,
            "recommendations": [{"method": row["method"], "candidateId": row["candidateId"],
                                  "heldOutScore": row["score"],
                                  "pass": row["admittedAtProbePanelGate"]} for row in group],
        })
        admitted = [row for row in group if row["admittedAtProbePanelGate"]]
        if admitted:
            chosen = min(admitted, key=lambda row: (row["changedFields"], row["normalisedL1"],
                                                   -row["score"], row["candidateId"]))
            selected.append({key: chosen[key] for key in (
                "candidateId", "family", "method", "parameters", "contentSha256",
                "changedFields", "normalisedL1", "score")})
    missing = sorted(set(PACKAGES) - {"hand-size-payoff-positive-control"}
                     - {row["family"] for row in selected})
    decision = "PROCEED_TO_FULL_RUN_PACKAGE_ADMISSION" if not missing \
        else "ESCALATE_FAILED_FAMILIES_TO_LEVEL2"
    result = {
        "schemaVersion": 1, "issue": 525, "decision": decision,
        "validatedRecommendations": len(results), "validationRows": sum(row["rows"] for row in results),
        "selected": selected, "failedFamilies": missing, "methodRace": method_race,
        "results": results,
    }
    write_json_once(ROOT / "artifacts/phase-c-level1-validation-v1.json", result)
    record(connection, "phase-c-level1-validation", {
        "decision": decision, "rows": result["validationRows"],
        "selected": [row["candidateId"] for row in selected], "failedFamilies": missing,
    })
    print(canonical({key: result[key] for key in (
        "decision", "validatedRecommendations", "validationRows", "selected", "failedFamilies")}))
    return result


def verify() -> dict:
    verify_authority()
    connection = open_ledger()
    duplicate = connection.execute(
        "select count(*)-count(distinct identity_sha256) from sim_row"
    ).fetchone()[0]
    counts = dict(connection.execute(
        "select fidelity,count(*) from sim_row group by fidelity order by fidelity"
    ))
    objects = list(connection.execute(
        "select sha256,relative_path,bytes from object order by identity_sha256"
    ))
    for sha, relative, size in objects:
        path = ROOT / relative
        if not path.is_file() or path.stat().st_size != size or file_sha256(path) != sha:
            raise RuntimeError(f"cache object drift: {relative}")
    result = {"status": "PASS", "duplicateIdentities": duplicate,
              "rowsByFidelity": counts, "cacheObjectsVerified": len(objects)}
    if duplicate:
        raise RuntimeError("duplicate simulator identity")
    print(canonical(result))
    return result


def self_check() -> None:
    sample = {"cards": {"x": {"rarity": "common"}},
              "cardPools": {"common": ["x"], "uncommon": [], "rare": []}}
    pointer_set(sample, "/cards/x/rarity", "uncommon")
    assert pointer_get(sample, "/cards/x/rarity") == "uncommon"
    values = bootstrap_summary([1.0] * 8, [0.0] * 8 + [1.0] * 8, "self-check")
    assert values["delta"] == 1.0 and values["pairedBootstrapP05"] == 1.0
    assert len(CONTEXTS) == 4 and len(PACKAGES) == 4
    print(canonical({"status": "PASS", "requiredValidationPairsPerEdge":
                     len(VALIDATION_SEEDS) * len(CONTEXTS)}))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("self-check", "screen", "validate", "verify"))
    args = parser.parse_args()
    if args.command == "self-check":
        self_check()
    elif args.command == "screen":
        screen()
    elif args.command == "validate":
        validate()
    else:
        verify()


if __name__ == "__main__":
    main()
