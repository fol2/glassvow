#!/usr/bin/env python3
"""Generate deterministic content candidates for scientific balance search.

This tool only creates candidate content files. It never edits the source
catalogue and never runs the acceptance holdout. Evaluation is a separate step.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import random
import re
import shutil
import sys
import tempfile
from collections import Counter
from copy import deepcopy
from pathlib import Path
from typing import Any

TOKEN_RE = re.compile(r"([^.\[\]]+)|\[(\d+)\]")
PATH_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_-]*(?:(?:\.[A-Za-z_][A-Za-z0-9_-]*)|(?:\[\d+\]))*")
TOOL_ID = "glassvow-balance-content-doe"
MARKER = f".{TOOL_ID}"
DESIGN_METHOD = "balanced-maximin-discrete-v1"
DESIGN_RESTARTS = 256


def read_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ValueError(f"cannot read JSON {path}: {exc}") from exc


def canonical_json_bytes(value: Any) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def path_tokens(path: str) -> list[str | int]:
    if not isinstance(path, str) or PATH_RE.fullmatch(path) is None:
        raise ValueError(f"invalid JSON path: {path!r}")
    tokens: list[str | int] = []
    for match in TOKEN_RE.finditer(path):
        tokens.append(match.group(1) if match.group(1) is not None else int(match.group(2)))
    return tokens


def get_path(root: Any, path: str) -> Any:
    cur = root
    for token in path_tokens(path):
        try:
            cur = cur[token]
        except (KeyError, IndexError, TypeError) as exc:
            raise ValueError(f"path not found: {path}") from exc
    return cur


def set_path(root: Any, path: str, value: Any) -> None:
    tokens = path_tokens(path)
    cur = root
    for token in tokens[:-1]:
        try:
            cur = cur[token]
        except (KeyError, IndexError, TypeError) as exc:
            raise ValueError(f"path not found: {path}") from exc
    last = tokens[-1]
    try:
        cur[last] = value
    except (KeyError, IndexError, TypeError) as exc:
        raise ValueError(f"cannot write path: {path}") from exc


def transformed(value: int | float, write: dict[str, Any]) -> int | float:
    result = float(value) * float(write.get("scale", 1)) + float(write.get("offset", 0))
    if not math.isfinite(result):
        raise ValueError("write transformation produced a non-finite value")
    return int(round(result)) if write.get("type", "int") == "int" else result


def feature_levels(feature: dict[str, Any]) -> list[int | float]:
    levels = feature.get("values")
    if not isinstance(levels, list) or not levels:
        raise ValueError(f"feature {feature.get('id')} needs a non-empty values list")
    if any(isinstance(value, bool) or not isinstance(value, (int, float))
           or not math.isfinite(float(value)) for value in levels):
        raise ValueError(f"feature {feature.get('id')} v1 levels must be finite non-boolean numbers")
    if len({json.dumps(v, sort_keys=True) for v in levels}) != len(levels):
        raise ValueError(f"feature {feature.get('id')} has duplicate values")
    return levels


def baseline_value(content: Any, feature: dict[str, Any]) -> int | float:
    levels = feature_levels(feature)
    matches: list[int | float] = []
    for candidate in levels:
        if all(get_path(content, write["path"]) == transformed(candidate, write)
               for write in feature["writes"]):
            matches.append(candidate)
    if len(matches) != 1:
        raise ValueError(
            f"feature {feature['id']} baseline must match exactly one level; matched {matches}"
        )
    return matches[0]


def validate_space(content: Any, space: dict[str, Any]) -> dict[str, Any]:
    if space.get("schemaVersion") != 1:
        raise ValueError("only search-space schemaVersion 1 is supported")
    features = space.get("features")
    if not isinstance(features, list) or not features:
        raise ValueError("search space needs a non-empty features list")
    ids = [str(feature.get("id", "")) for feature in features]
    if any(not feature_id for feature_id in ids) or len(set(ids)) != len(ids):
        raise ValueError("feature ids must be non-empty and unique")
    seen_paths: set[str] = set()
    baseline: dict[str, Any] = {}
    for feature in features:
        writes = feature.get("writes")
        if not isinstance(writes, list) or not writes:
            raise ValueError(f"feature {feature['id']} needs writes")
        levels = feature_levels(feature)
        for write in writes:
            if not isinstance(write, dict):
                raise ValueError(f"feature {feature['id']} writes must be objects")
            path = write.get("path")
            if not isinstance(path, str) or path in seen_paths:
                raise ValueError(f"write path must be non-empty and unique: {path!r}")
            path_tokens(path)
            seen_paths.add(path)
            current = get_path(content, path)
            if isinstance(current, bool) or not isinstance(current, (int, float)):
                raise ValueError(f"v1 only supports numeric leaves: {path}")
            if write.get("type", "int") not in ("int", "float"):
                raise ValueError(f"write type must be 'int' or 'float': {path}")
            for field, default in (("scale", 1), ("offset", 0)):
                parameter = write.get(field, default)
                if isinstance(parameter, bool) or not isinstance(parameter, (int, float)) \
                        or not math.isfinite(float(parameter)):
                    raise ValueError(f"write {field} must be a finite non-boolean number: {path}")
        vectors = [tuple(transformed(level, write) for write in writes) for level in levels]
        if len(set(vectors)) != len(vectors):
            raise ValueError(f"feature {feature['id']} has transformed-level collisions")
        baseline[feature["id"]] = baseline_value(content, feature)
    return baseline


def design_metrics(rows: list[list[int]], features: list[dict[str, Any]]) -> dict[str, Any]:
    distances = [
        sum(left != right for left, right in zip(rows[i], rows[j], strict=True))
        for i in range(len(rows)) for j in range(i + 1, len(rows))
    ]
    minimum = min(distances, default=0)
    correlations: list[float] = []
    for left in range(len(features)):
        x = [row[left] for row in rows]
        x_mean = sum(x) / len(x)
        for right in range(left + 1, len(features)):
            y = [row[right] for row in rows]
            y_mean = sum(y) / len(y)
            numerator = sum((a - x_mean) * (b - y_mean) for a, b in zip(x, y, strict=True))
            denominator = math.sqrt(
                sum((a - x_mean) ** 2 for a in x) * sum((b - y_mean) ** 2 for b in y)
            )
            correlations.append(abs(numerator / denominator) if denominator else 0.0)
    marginals: dict[str, dict[str, int]] = {}
    for column, feature in enumerate(features):
        counts = Counter(row[column] for row in rows)
        marginals[feature["id"]] = {
            json.dumps(level, ensure_ascii=False): counts[index]
            for index, level in enumerate(feature_levels(feature))
        }
    return {
        "method": DESIGN_METHOD,
        "restarts": DESIGN_RESTARTS,
        "marginalCounts": marginals,
        "minimumHammingDistance": minimum,
        "closestPairCount": distances.count(minimum),
        "maximumAbsoluteColumnCorrelation": max(correlations, default=0.0),
        "correlationEncoding": "ordinal-level-index",
        "uniqueVectors": len(set(map(tuple, rows))),
    }


def balanced_design(count: int, features: list[dict[str, Any]], baseline: dict[str, Any],
                    seed: int) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    if count < 1:
        raise ValueError("count must be positive")
    combinations = 1
    for feature in features:
        combinations *= len(feature_levels(feature))
    if count > combinations:
        raise ValueError(f"requested {count} candidates but only {combinations} combinations exist")
    master = random.Random(seed)
    best_rows: list[list[int]] | None = None
    best_metrics: dict[str, Any] | None = None
    best_score: tuple[int, int, float] | None = None
    for _restart in range(DESIGN_RESTARTS):
        rng = random.Random(master.getrandbits(64))
        columns: list[list[int]] = []
        for feature in features:
            levels = feature_levels(feature)
            baseline_index = levels.index(baseline[feature["id"]])
            quotient, remainder = divmod(count, len(levels))
            counts = [quotient] * len(levels)
            extras = list(range(len(levels)))
            rng.shuffle(extras)
            chosen = extras[:remainder]
            if quotient == 0 and baseline_index not in chosen:
                chosen[-1] = baseline_index
            for level_index in chosen:
                counts[level_index] += 1
            pool = [level_index for level_index, amount in enumerate(counts)
                    for _ in range(amount)]
            pool.remove(baseline_index)
            rng.shuffle(pool)
            columns.append([baseline_index, *pool])
        rows = [[column[row_index] for column in columns] for row_index in range(count)]
        if len(set(map(tuple, rows))) != count:
            continue
        metrics = design_metrics(rows, features)
        score = (
            metrics["minimumHammingDistance"],
            -metrics["closestPairCount"],
            -metrics["maximumAbsoluteColumnCorrelation"],
        )
        if best_score is None or score > best_score:
            best_rows, best_metrics, best_score = rows, metrics, score
    if best_rows is None or best_metrics is None:
        raise RuntimeError(f"no unique balanced design found in {DESIGN_RESTARTS} seeded restarts")
    design = [
        {feature["id"]: feature_levels(feature)[row[column]]
         for column, feature in enumerate(features)}
        for row in best_rows
    ]
    return design, best_metrics


def apply_values(base: Any, features: list[dict[str, Any]], values: dict[str, Any]) -> tuple[Any, list[dict[str, Any]]]:
    content = deepcopy(base)
    patch: list[dict[str, Any]] = []
    for feature in features:
        value = values[feature["id"]]
        for write in feature["writes"]:
            path = write["path"]
            before = get_path(content, path)
            after = transformed(value, write)
            set_path(content, path, after)
            patch.append({"feature": feature["id"], "path": path, "before": before, "after": after})
    return content, patch


def verify_requested_values(content: Any, features: list[dict[str, Any]],
                            requested: dict[str, Any]) -> None:
    for feature in features:
        matches = [
            level for level in feature_levels(feature)
            if all(get_path(content, write["path"]) == transformed(level, write)
                   for write in feature["writes"])
        ]
        if matches != [requested[feature["id"]]]:
            raise ValueError(
                f"candidate does not map back to requested {feature['id']}="
                f"{requested[feature['id']]!r}; matched {matches}"
            )


def prepare_output(out: Path, force: bool) -> None:
    if out.is_symlink():
        raise ValueError(f"refusing output symlink: {out}")
    if out.exists():
        if not force:
            raise ValueError(f"output exists: {out}; pass --force to replace it")
        marker = out / MARKER
        if not out.is_dir() or not marker.is_file() or marker.read_text() != f"{TOOL_ID}\n":
            raise ValueError(f"refusing --force for unmarked output directory: {out}")
        shutil.rmtree(out)
    out.mkdir(parents=True)
    (out / MARKER).write_text(f"{TOOL_ID}\n")


def compile_bundle(base_path: Path, space_path: Path, count: int,
                   seed: int) -> tuple[dict[str, Any], list[tuple[dict[str, Any], bytes]]]:
    base_bytes = base_path.read_bytes()
    space_bytes = space_path.read_bytes()
    base = read_json(base_path)
    space = read_json(space_path)
    baseline = validate_space(base, space)
    features: list[dict[str, Any]] = space["features"]
    combinations = math.prod(len(feature_levels(feature)) for feature in features)
    design, metrics = balanced_design(count, features, baseline, seed)
    semantic_catalogues: dict[bytes, dict[str, Any]] = {}
    candidates: list[tuple[dict[str, Any], bytes]] = []
    for index, values in enumerate(design):
        content, patch = apply_values(base, features, values)
        verify_requested_values(content, features, values)
        semantic_bytes = canonical_json_bytes(content)
        previous = semantic_catalogues.get(semantic_bytes)
        if previous is not None and previous != values:
            raise ValueError(f"different feature vectors produce one semantic catalogue: {previous} and {values}")
        semantic_catalogues[semantic_bytes] = values
        file_bytes = base_bytes if index == 0 else semantic_bytes + b"\n"
        candidate = {
            "id": f"c{index:03d}",
            "baseline": index == 0,
            "values": values,
            "patch": patch,
            "fileSha256": sha256_bytes(file_bytes),
            "semanticSha256": sha256_bytes(semantic_bytes),
        }
        candidates.append((candidate, file_bytes))
    manifest = {
        "tool": TOOL_ID,
        "space": str(space_path),
        "base": str(base_path),
        "features": len(features),
        "numericWrites": sum(len(feature["writes"]) for feature in features),
        "combinations": combinations,
        "baseline": baseline,
        "seed": seed,
        "count": count,
        "design": metrics,
        "baseIdentity": {
            "fileSha256": sha256_bytes(base_bytes),
            "semanticSha256": sha256_bytes(canonical_json_bytes(base)),
        },
        "spaceIdentity": {
            "fileSha256": sha256_bytes(space_bytes),
            "semanticSha256": sha256_bytes(canonical_json_bytes(space)),
        },
        "candidates": [candidate for candidate, _content_bytes in candidates],
    }
    return manifest, candidates


def generate_bundle(base_path: Path, space_path: Path, out: Path, count: int,
                    seed: int, force: bool) -> dict[str, Any]:
    manifest, candidates = compile_bundle(base_path, space_path, count, seed)
    prepare_output(out, force)
    for candidate, content_bytes in candidates:
        candidate_dir = out / candidate["id"]
        candidate_dir.mkdir()
        (candidate_dir / "full-content.json").write_bytes(content_bytes)
        (candidate_dir / "candidate.json").write_text(
            json.dumps(candidate, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
        )
    (out / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    )
    return manifest


def numeric_inventory(value: Any, prefix: str = "") -> Counter[str]:
    counts: Counter[str] = Counter()
    if isinstance(value, dict):
        for key, child in value.items():
            child_prefix = f"{prefix}.{key}" if prefix else str(key)
            counts.update(numeric_inventory(child, child_prefix))
    elif isinstance(value, list):
        for index, child in enumerate(value):
            counts.update(numeric_inventory(child, f"{prefix}[{index}]"))
    elif not isinstance(value, bool) and isinstance(value, (int, float)):
        group = prefix.split(".", 1)[0].split("[", 1)[0]
        counts[group] += 1
        counts["__total__"] += 1
    return counts


def resolve_repo_path(repo: Path, value: str) -> Path:
    path = Path(value)
    return path if path.is_absolute() else repo / path


def parse_args() -> argparse.Namespace:
    repo = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--space", default="docs/balance/421-content-search-space-v1.json")
    parser.add_argument("--base", help="override the base content path in the search-space file")
    parser.add_argument("--count", type=int, default=32, help="total candidates, including baseline c000")
    parser.add_argument("--seed", type=int, default=421)
    parser.add_argument("--out", default="/tmp/glassvow-421-content-doe")
    parser.add_argument("--check", action="store_true", help="validate and print the space without writing candidates")
    parser.add_argument("--inventory", action="store_true", help="print numeric-leaf counts for the base content")
    parser.add_argument("--force", action="store_true", help="replace an existing output directory")
    parser.add_argument("--self-test", action="store_true", help="run the stdlib-only synthetic regression suite")
    parser.set_defaults(repo=repo)
    return parser.parse_args()


def self_test() -> int:
    with tempfile.TemporaryDirectory(prefix="glassvow-content-doe-") as temp:
        root = Path(temp)
        base_path = root / "base.json"
        space_path = root / "space.json"
        values: list[int] = []
        features: list[dict[str, Any]] = []
        for feature_index, level_count in enumerate([5, 5, 5, 5, 4, 4, 4, 4]):
            writes: list[dict[str, Any]] = []
            for write_index in range(2 if feature_index < 5 else 1):
                offset = 100 * write_index
                path_index = len(values)
                values.append(offset)
                write: dict[str, Any] = {"path": f"values[{path_index}]"}
                if offset:
                    write["offset"] = offset
                writes.append(write)
            features.append({"id": f"f{feature_index}", "values": list(range(level_count)), "writes": writes})
        base_bytes = (json.dumps({"values": values}, indent=2) + "  \n").encode()
        base_path.write_bytes(base_bytes)
        space_path.write_text(json.dumps({"schemaVersion": 1, "base": str(base_path), "features": features}))

        first, second, changed = root / "first", root / "second", root / "changed"
        generate_bundle(base_path, space_path, first, 32, 421, False)
        generate_bundle(base_path, space_path, second, 32, 421, False)
        manifest = read_json(first / "manifest.json")
        counts = manifest["design"]["marginalCounts"]
        assert manifest["design"]["uniqueVectors"] == 32
        assert all(max(column.values()) - min(column.values()) <= 1 for column in counts.values())
        assert (first / "c000" / "full-content.json").read_bytes() == base_bytes

        def snapshot(directory: Path) -> dict[str, bytes]:
            return {str(path.relative_to(directory)): path.read_bytes()
                    for path in directory.rglob("*") if path.is_file()}

        expected = snapshot(first)
        assert expected == snapshot(second)
        generate_bundle(base_path, space_path, first, 32, 421, True)
        assert expected == snapshot(first)
        generate_bundle(base_path, space_path, changed, 32, 422, False)
        changed_manifest = read_json(changed / "manifest.json")
        assert manifest["candidates"][1:] != changed_manifest["candidates"][1:]

        for malformed in ("foo..bar", "foo[x]", "foo[1]bar", "foo.", "foo["):
            try:
                path_tokens(malformed)
            except ValueError:
                continue
            raise AssertionError(f"malformed path accepted: {malformed}")
        unsafe = root / "unsafe"
        unsafe.mkdir()
        sentinel = unsafe / "keep.txt"
        sentinel.write_text("keep")
        try:
            prepare_output(unsafe, True)
        except ValueError:
            pass
        else:
            raise AssertionError("unsafe --force accepted an unmarked directory")
        assert sentinel.read_text() == "keep"
    print("balance content DOE self-test OK")
    return 0


def main() -> int:
    args = parse_args()
    if args.self_test:
        return self_test()
    repo: Path = args.repo
    space_path = resolve_repo_path(repo, args.space)
    space = read_json(space_path)
    base_path = resolve_repo_path(repo, args.base or space["base"])
    if args.inventory:
        base = read_json(base_path)
        inventory = numeric_inventory(base)
        print(json.dumps({"numericLeaves": inventory.pop("__total__", 0), "byTopLevel": inventory}, indent=2, sort_keys=True))
        return 0
    manifest, _candidates = compile_bundle(base_path, space_path, args.count, args.seed)
    if args.check:
        summary = {key: value for key, value in manifest.items() if key != "candidates"}
        print(json.dumps(summary, indent=2, sort_keys=True))
        return 0
    out = Path(args.out)
    generate_bundle(base_path, space_path, out, args.count, args.seed, args.force)
    print(json.dumps({
        "out": str(out),
        "features": manifest["features"],
        "numericWrites": manifest["numericWrites"],
        "combinations": manifest["combinations"],
        "count": args.count,
        "design": manifest["design"],
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (KeyError, TypeError, ValueError, RuntimeError) as exc:
        print(f"balance_content_doe: {exc}", file=sys.stderr)
        raise SystemExit(2) from exc
