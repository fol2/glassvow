#!/usr/bin/env python3
"""Compile issue #490's pre-registered Tier-1 candidates without mutating live content."""
from __future__ import annotations
import argparse, json, math, random, re, shutil, sys
from copy import deepcopy
from pathlib import Path
from typing import Any
from balance_content_doe import canonical_json_bytes, design_metrics, read_json, set_path, sha256_bytes
from balance_s009_reconstruct import FINALISTS_REL, catalogue_bytes, reconstruct
REPO = Path(__file__).resolve().parents[1]
REGISTRY_REL = "docs/balance/490-tier1-registry-v1.json"; FILES = ("content/full-content.json", "locale/en.json", "locale/zh-Hant.json")
TOOL_ID = "glassvow-balance-tier1-design"; MARKER = f".{TOOL_ID}"  # RFC 6901 patches; v1 DOE uses incompatible dotted paths.
def _tokens(pointer: str) -> list[str]:
    if not isinstance(pointer, str) or not pointer.startswith("/") or pointer == "/":
        raise ValueError(f"invalid JSON pointer: {pointer!r}")
    parts = pointer[1:].split("/")
    if any(not part or "~" in part.replace("~0", "").replace("~1", "") for part in parts):
        raise ValueError(f"invalid JSON pointer: {pointer!r}")
    return [part.replace("~1", "/").replace("~0", "~") for part in parts]
def pointer_get(root: Any, pointer: str) -> Any:
    current = root
    for token in _tokens(pointer):
        try:
            current = current[int(token)] if isinstance(current, list) and token.isdigit() else current[token]
        except (KeyError, IndexError, TypeError, ValueError) as exc:
            raise ValueError(f"path not found: {pointer}") from exc
    return current
def _pointer_set(root: Any, pointer: str, value: Any, add: bool = False) -> None:
    parts = _tokens(pointer); parent = root
    for token in parts[:-1]:
        try:
            parent = parent[int(token)] if isinstance(parent, list) and token.isdigit() else parent[token]
        except (KeyError, IndexError, TypeError, ValueError) as exc:
            raise ValueError(f"path not found: {pointer}") from exc
    leaf = parts[-1]
    if isinstance(parent, list):
        if add or not leaf.isdigit():
            raise ValueError(f"array additions are not registered: {pointer}")
        parent[int(leaf)] = value
    elif isinstance(parent, dict):
        if add == (leaf in parent):
            raise ValueError(f"path {'already exists' if add else 'not found'}: {pointer}")
        parent[leaf] = value
    else:
        raise ValueError(f"path parent is not a container: {pointer}")
def replay_patches(base: Any, patches: list[dict[str, Any]]) -> Any:
    replay = deepcopy(base)
    for patch in patches:
        path, operation = str(patch["path"]), str(patch["op"])
        if operation == "replace":
            if pointer_get(replay, path) != patch["before"]: raise ValueError(f"patch before-value mismatch: {path}")
            _pointer_set(replay, path, patch["after"])
        elif operation == "add": _pointer_set(replay, path, patch["after"], True)
        else: raise ValueError(f"unsupported patch operation: {operation}")
    return replay
def _diff(before: Any, after: Any, pointer: str = "") -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    if isinstance(before, dict) and isinstance(after, dict):
        if set(before) - set(after): raise ValueError(f"candidate deletes content below {pointer or '/'}")
        for key in sorted(after):
            path = f"{pointer}/{str(key).replace('~', '~0').replace('/', '~1')}"
            out += ([{"op": "add", "path": path, "after": after[key]}] if key not in before else _diff(before[key], after[key], path))
    elif isinstance(before, list) and isinstance(after, list):
        if len(before) != len(after): raise ValueError(f"candidate changes array shape below {pointer}")
        for index, (left, right) in enumerate(zip(before, after, strict=True)):
            out += _diff(left, right, f"{pointer}/{index}")
    elif before != after:
        out.append({"op": "replace", "path": pointer, "before": before, "after": after})
    return out
def _base_roots(repo: Path) -> tuple[dict[str, Any], dict[str, Any], dict[str, Any]]:
    sources = {relative: read_json(repo / relative) for relative in FILES}; packet = reconstruct(repo)
    targets = deepcopy(sources); targets[FILES[0]] = packet["content"]
    finalists = read_json(repo / FINALISTS_REL); row = next(item for item in finalists["orderedFinalists"] if item["id"] == "s009")
    for relative in FILES[1:]:
        for path, value in row["intendedHydratedUpdates"][relative].items():
            set_path(targets[relative], path, value)
    return sources, targets, packet
def _hydration_values(item: dict[str, Any], level: int) -> list[tuple[str, str, str]]:
    kind, item_id = item["kind"], item["id"]
    en, zh = item["en"][level], item["zhHant"][level]
    if kind == "card":
        return [(FILES[0], f"/cards/{item_id}/text", en[0]), (FILES[0], f"/cards/{item_id}/up/text", en[1]), (FILES[1], f"/content/cards/{item_id}/text", en[0]), (FILES[1], f"/content/cards/{item_id}/textUp", en[1]), (FILES[2], f"/content/cards/{item_id}/text", zh[0]), (FILES[2], f"/content/cards/{item_id}/textUp", zh[1])]
    if kind == "relic":
        return [(FILES[0], f"/relics/{item_id}/text", en), (FILES[1], f"/content/relics/{item_id}/text", en), (FILES[2], f"/content/relics/{item_id}/text", zh)]
    if kind == "eventChoice":
        choice = item["choice"]
        return [(FILES[0], f"/events/{item_id}/choices/{choice}/sub", en), (FILES[1], f"/content/events/{item_id}/choices/{choice}/sub", en), (FILES[2], f"/content/events/{item_id}/choices/{choice}/sub", zh)]
    raise ValueError(f"unknown hydration kind: {kind}")
def _numbers(value: Any) -> list[int]:
    strings = value if isinstance(value, list) else [value]
    if not strings or any(not isinstance(item, str) for item in strings): raise ValueError("hydration text must be a string or string pair")
    return [abs(int(token)) for item in strings for token in re.findall(r"-?\d+", item)]
def _validate_hydration(feature: dict[str, Any], item: dict[str, Any], content: dict[str, Any]) -> None:
    writes = {write["path"]: write["values"] for write in feature["writes"]}; groups = item.get("pathGroups")
    if not isinstance(groups, list) or not groups or any(not isinstance(group, list) or not group or len(group) != len(set(group)) or any(not isinstance(path, str) for path in group) for group in groups): raise ValueError(f"invalid hydration bindings: {item.get('id')}")
    for level in range(3):
        en = item["en"][level] if isinstance(item["en"][level], list) else [item["en"][level]]; zh = item["zhHant"][level] if isinstance(item["zhHant"][level], list) else [item["zhHant"][level]]
        if len(en) != len(groups) or len(zh) != len(groups) or any(_numbers(left) != [abs(writes[path][level] if path in writes else pointer_get(content, path)) for path in group] or _numbers(right) != _numbers(left) for group, left, right in zip(groups, en, zh, strict=True)): raise ValueError(f"hydration numbers do not match writes: {feature['id']}/{item.get('id')}")
def _apply_feature(roots: dict[str, Any], feature: dict[str, Any], level: int) -> None:
    content = roots[FILES[0]]
    for write in feature["writes"]:
        path, value = write["path"], write["values"][level]
        try:
            pointer_get(content, path)
        except ValueError:
            if "fallback" not in write: raise
            if level == 1 and value == write["fallback"]: continue
            _pointer_set(content, path, value, True)
        else: _pointer_set(content, path, value)
    for item in feature.get("hydration", []):
        for relative, path, value in _hydration_values(item, level):
            _pointer_set(roots[relative], path, value)
def _validate(registry: dict[str, Any], roots: dict[str, Any], history: dict[str, Any], response: dict[str, Any]) -> None:
    design, features = registry.get("design", {}), registry.get("features", [])
    if registry.get("schemaVersion") != 1 or registry.get("issue") != 490 or len(features) != 8: raise ValueError("registry must contain the eight issue #490 families")
    if design != {"count": 48, "seed": 490, "version": "anchored-balanced-maximin-d-optimal-v1", "restarts": 256, "levels": ["low", "s009", "high"], "candidatePrefix": "t1-c"}: raise ValueError("Tier-1 design controls drifted")
    ids = [feature.get("id") for feature in features]
    if len(set(ids)) != 8 or any(not value for value in ids): raise ValueError("feature ids must be non-empty and unique")
    if set(history.get("hypotheses", {})) != {f"H{i}" for i in range(1, 73)}: raise ValueError("known-history table must cover H1-H72 exactly")
    if set(history.get("programmes", {})) != {"#457", "#458", "s009"} or len(history.get("excludedTargets", [])) != 5: raise ValueError("known-history table must cover prior programmes and exclusions")
    axes = response.get("frozenAxes", {})
    if axes.get("deckCuts") != {"thinMax": 25, "midMax": 35} or axes.get("medians") != {"duskblade": {"shattersPerFight": 1.1111, "smolderKillsPerFight": 0.1111}, "ashwarden": {"shattersPerFight": 0.6154, "smolderKillsPerFight": 0.8519}} or axes.get("tieOrder") != ["shatter", "smolder", "attrition"]: raise ValueError("F0 contract drifted from frozen #215 axes")
    if list(response.get("packageDiagnostics", {}).get("packages", {})) != ids: raise ValueError("F0 package diagnostics do not match the registry")
    required = {"id", "values", "fileSha256", "semanticSha256", "inputHash", "controlArms", "controls", "cells", "proxies", "controlStalls", "controlErrors", "landscapeStalls", "landscapeErrors", "observationsSha256", "controlRowCount", "landscapeRowCount", "wallSeconds", "godotVersion", "hostFingerprint", "commit", "deficits", "bootstrap", "status", "earlyStop", "deckBands", "rankGaps", "occupiedValidCells", "finalDeckSize", "packageDiagnostics", "guardrails", "decision"}
    guards = response.get("guardrails", {}).get("definitions", {}); validity = response.get("cellValidity", {}); decision = response.get("decision", {})
    if set(response.get("requiredTopLevel", [])) != required or validity.get("minimumDistinctPolicies") != 20 or validity.get("minimumRuns") != 400 or guards.get("c2") != {"absoluteArm2": {"operator": "<", "value": 0.5}, "appliesTo": "every-grid", "topMinusArm2": {"operator": ">=", "value": 0.35}} or guards.get("vow5Proxy") != {"appliesTo": ["duskblade:v5", "ashwarden:v5"], "metric": "topValidCellWinRate", "operator": "<=", "value": 0.9} or response.get("guardrails", {}).get("required") != ["c2", "identity", "vow5Proxy"] or not response.get("guardrails", {}).get("failClosedWhenMissing") or response.get("diagnosticOnly") != ["finalDeckSize.distribution", "finalDeckSize.entropy"] or decision.get("mustGate") != ["c2", "identity", "vow5Proxy", "simulatorClear", "mechanismFired", "breadthClear"]: raise ValueError("F0 response/guardrail contract is incomplete")
    seen: set[tuple[str, str]] = {(FILES[0], fixed["path"]) for fixed in registry.get("fixed", [])}
    for fixed in registry.get("fixed", []):
        if pointer_get(roots[FILES[0]], fixed["path"]) != fixed["value"]: raise ValueError(f"fixed mechanism drifted: {fixed['path']}")
    for feature in features:
        refs = feature.get("history", [])
        if any(ref not in history["hypotheses"] for ref in refs):
            raise ValueError(f"unknown history reference in {feature['id']}")
        if any(history["hypotheses"][ref][0] == "revert" for ref in refs) \
                and feature["id"] not in history.get("reapplications", {}):
            raise ValueError(f"reverted level lacks grouped justification: {feature['id']}")
        for write in feature.get("writes", []):
            path, values = write.get("path"), write.get("values")
            bounds = write.get("range")
            if write.get("transform", "replace") != "replace" or not isinstance(values, list) or len(values) != 3 \
                    or any(type(value) is not int for value in values) or not isinstance(bounds, list) or len(bounds) != 2 \
                    or any(type(value) is not int for value in bounds) or bounds[0] > bounds[1] or any(not bounds[0] <= value <= bounds[1] for value in values) \
                    or ((path.endswith("/cost") or "/effects/" in path) and bounds[0] < 0):
                raise ValueError(f"invalid registered levels/transform: {path}")
            if (FILES[0], path) in seen:
                raise ValueError(f"semantic write collision: {path}")
            seen.add((FILES[0], path))
            try:
                centre = pointer_get(roots[FILES[0]], path)
            except ValueError:
                centre = write.get("fallback")
                if centre is None:
                    raise
            if type(centre) is not int or centre != values[1] or ("fallback" in write and (type(write["fallback"]) is not int or write["fallback"] != values[1])):
                raise ValueError(f"s009 centre mismatch: {path}")
        for item in feature.get("hydration", []):
            _validate_hydration(feature, item, roots[FILES[0]])
            for relative, path, value in _hydration_values(item, 1):
                if (relative, path) in seen or pointer_get(roots[relative], path) != value:
                    raise ValueError(f"hydration collision/centre mismatch: {relative}{path}")
                seen.add((relative, path))
def _logdet(rows: list[list[int]]) -> float:
    coded = [[value - 1 for value in row] for row in rows]
    matrix = [[float(sum(row[i] * row[j] for row in coded)) for j in range(8)] for i in range(8)]
    total = 0.0
    for column in range(8):
        pivot = max(range(column, 8), key=lambda row: abs(matrix[row][column]))
        matrix[column], matrix[pivot] = matrix[pivot], matrix[column]
        value = abs(matrix[column][column])
        if value < 1e-12:
            return float("-inf")
        total += math.log(value)
        for row in range(column + 1, 8):
            factor = matrix[row][column] / matrix[column][column]
            for other in range(column, 8):
                matrix[row][other] -= factor * matrix[column][other]
    return total
def _metrics(rows: list[list[int]], ids: list[str], seed: int) -> dict[str, Any]:
    metrics = design_metrics(rows, [{"id": feature_id, "values": [0, 1, 2]} for feature_id in ids])
    metrics["marginalCounts"] = {ids[i]: {name: sum(row[i] == level for row in rows)
                                          for level, name in enumerate(("low", "s009", "high"))} for i in range(8)}
    coverage = {f"{ids[i]}:{ids[j]}": len({(row[i], row[j]) for row in rows})
                for i in range(8) for j in range(i + 1, 8)}
    generated_distances = [sum(a != b for a, b in zip(rows[i], rows[j], strict=True))
                           for i in range(17, 48) for j in range(i + 1, 48)]
    metrics.update({"method": "anchored-balanced-maximin-d-optimal-v1", "seed": seed, "restarts": 256,
                    "mainEffectAnchors": 16, "minimumGeneratedHammingDistance": min(generated_distances),
                    "pairwiseLevelCombinations": sum(coverage.values()),
                    "pairwiseLevelCoverage": {"observed": sum(coverage.values()), "possible": 252, "perPair": coverage},
                    "maximumAbsoluteColumnCorrelation": round(metrics["maximumAbsoluteColumnCorrelation"], 12),
                    "dOptimalLogDet": round(_logdet(rows), 12), "vectorSha256": sha256_bytes(canonical_json_bytes(rows))})
    return metrics
def _design(ids: list[str], seed: int) -> tuple[list[list[int]], dict[str, Any]]:
    fixed = [[1] * 8]
    for column in range(8):
        for level in (0, 2):
            row = [1] * 8
            row[column] = level
            fixed.append(row)
    best: tuple[tuple[int, int, float, float], list[list[int]], dict[str, Any]] | None = None
    for restart in range(256):
        rng, columns = random.Random((seed << 16) + restart), []
        for _column in range(8):
            pool = [0] * 15 + [1] + [2] * 15
            rng.shuffle(pool)
            columns.append(pool)
        rows = fixed + [[columns[column][index] for column in range(8)] for index in range(31)]
        if len(set(map(tuple, rows))) != 48:
            continue
        metrics = _metrics(rows, ids, seed)
        score = (metrics["minimumGeneratedHammingDistance"], metrics["pairwiseLevelCoverage"]["observed"], metrics["dOptimalLogDet"],
                 -metrics["maximumAbsoluteColumnCorrelation"])
        if best is None or score > best[0]:
            best = score, rows, metrics
    if best is None:
        raise RuntimeError("no unique Tier-1 design found")
    return best[1], best[2]
def _identity(path: Path, value: Any) -> dict[str, str]:
    return {"fileSha256": sha256_bytes(path.read_bytes()), "semanticSha256": sha256_bytes(canonical_json_bytes(value))}
def compile_design(repo: Path = REPO, registry_path: Path | None = None,
                   seed: int | None = None) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    path = registry_path or repo / REGISTRY_REL
    registry, sources, base, packet = read_json(path), *_base_roots(repo)
    history_path, response_path = repo / registry["history"], repo / registry["responseContract"]
    history, response = read_json(history_path), read_json(response_path)
    if sha256_bytes(response_path.read_bytes()) != registry.get("responseContractFileSha256"): raise ValueError("frozen F0 response contract drifted")
    if packet["identity"]["fileSha256"] != registry["base"]["fileSha256"] or packet["identity"]["semanticSha256"] != registry["base"]["semanticSha256"]:
        raise ValueError("registry base is not the exact s009 exam catalogue")
    _validate(registry, base, history, response)
    actual_seed = registry["design"]["seed"] if seed is None else seed
    ids = [feature["id"] for feature in registry["features"]]
    rows, metrics = _design(ids, actual_seed)
    published = registry.get("publishedDesign") if seed is None else None
    if published is not None and any(metrics.get(key) != value for key, value in published.items()):
        raise ValueError("published design diagnostics drifted")
    candidates, artefacts, semantics = [], [], set()
    for index, row in enumerate(rows):
        roots = deepcopy(base)
        for column, level in enumerate(row):
            _apply_feature(roots, registry["features"][column], level)
        for column, level in enumerate(row):
            for write in registry["features"][column]["writes"]:
                effective = pointer_get(roots[FILES[0]], write["path"]) if not (level == 1 and "fallback" in write) else write["fallback"]
                if effective != write["values"][level]:
                    raise ValueError(f"candidate does not map to {ids[column]}")
            for item in registry["features"][column].get("hydration", []):
                if any(pointer_get(roots[relative], path) != value for relative, path, value in _hydration_values(item, level)):
                    raise ValueError(f"candidate hydration does not map to {ids[column]}")
        semantic = canonical_json_bytes(roots[FILES[0]])
        if semantic in semantics:
            raise ValueError("distinct vectors collide on one semantic catalogue")
        semantics.add(semantic)
        file_meta, patch_files, blobs = {}, {}, {}
        for relative in FILES:
            blob = catalogue_bytes(roots[relative])
            patches = _diff(sources[relative], roots[relative])
            replay = replay_patches(sources[relative], patches)
            if replay != roots[relative] or catalogue_bytes(replay) != blob:
                raise ValueError(f"hydration replay mismatch: {relative}")
            identity = {"fileSha256": sha256_bytes(blob), "semanticSha256": sha256_bytes(canonical_json_bytes(roots[relative])), "patches": len(patches)}
            file_meta[relative], blobs[relative] = identity, blob
            patch_files[relative] = {**identity, "patch": patches, "replayFileSha256": sha256_bytes(catalogue_bytes(replay)), "replaySemanticSha256": sha256_bytes(canonical_json_bytes(replay))}
        candidate = {"id": f"t1-c{index:03d}", "baseline": index == 0, "fileSha256": file_meta[FILES[0]]["fileSha256"], "semanticSha256": file_meta[FILES[0]]["semanticSha256"], "searchSpaceSha256": sha256_bytes(path.read_bytes()), "patch": patch_files[FILES[0]]["patch"],
                     "values": {ids[column]: registry["design"]["levels"][level] for column, level in enumerate(row)}, "files": file_meta}
        candidates.append(candidate)
        artefacts.append({"candidate": candidate, "blobs": blobs, "patches": {"candidate": candidate["id"], "files": patch_files}})
    manifest = {"tool": TOOL_ID, "registry": REGISTRY_REL, "features": 8,
                "numericWrites": sum(len(feature["writes"]) for feature in registry["features"]),
                "combinations": 3 ** 8, "seed": actual_seed, "count": 48, "baseIdentity": {key: value for key, value in packet["identity"].items() if key != "livePath"},
                "registryIdentity": _identity(path, registry), "historyIdentity": _identity(history_path, history),
                "responseContractIdentity": _identity(response_path, response), "design": metrics, "candidates": candidates}
    return manifest, artefacts
def _prepare_output(out: Path, force: bool) -> None:
    if out.is_symlink(): raise ValueError(f"refusing output symlink: {out}")
    if out.exists():
        marker = out / MARKER
        if not force: raise ValueError(f"output exists: {out}; pass --force to replace it")
        if not out.is_dir() or marker.is_symlink() or not marker.is_file() or marker.read_text() != f"{TOOL_ID}\n": raise ValueError(f"refusing --force for unmarked output directory: {out}")
        shutil.rmtree(out)
    out.mkdir(parents=True)
    (out / MARKER).write_text(f"{TOOL_ID}\n")
def generate_bundle(repo: Path, out: Path, force: bool = False, seed: int | None = None) -> dict[str, Any]:
    manifest, artefacts = compile_design(repo, seed=seed)
    _prepare_output(out, force)
    for artefact in artefacts:
        directory = out / artefact["candidate"]["id"]
        directory.mkdir()
        (directory / "full-content.json").write_bytes(artefact["blobs"][FILES[0]])
        (directory / "candidate.json").write_text(json.dumps(artefact["candidate"], ensure_ascii=False, indent=2, sort_keys=True) + "\n")
        (directory / "hydration-patches.json").write_text(json.dumps(artefact["patches"], ensure_ascii=False, indent=2, sort_keys=True) + "\n")
    (out / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
    return manifest
def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=Path("/tmp/glassvow-490-tier1")); parser.add_argument("--seed", type=int)
    parser.add_argument("--check", action="store_true"); parser.add_argument("--force", action="store_true")
    args = parser.parse_args()
    if args.check:
        manifest, _ = compile_design(REPO, seed=args.seed)
        print(json.dumps({key: value for key, value in manifest.items() if key != "candidates"}, indent=2, sort_keys=True))
    else:
        manifest = generate_bundle(REPO, args.out, args.force, args.seed)
        print(json.dumps({"out": str(args.out), "count": manifest["count"], "design": manifest["design"]}, sort_keys=True))
    return 0
if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (KeyError, OSError, StopIteration, TypeError, ValueError, RuntimeError) as exc:
        print(f"balance_tier1_design: {exc}", file=sys.stderr)
        raise SystemExit(2) from exc
