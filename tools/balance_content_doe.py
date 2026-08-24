#!/usr/bin/env python3
"""Generate deterministic content candidates for scientific balance search.

This tool only creates candidate content files. It never edits the source
catalogue and never runs the acceptance holdout. Evaluation is a separate step.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import random
import re
import shutil
import sys
from collections import Counter
from copy import deepcopy
from pathlib import Path
from typing import Any

TOKEN_RE = re.compile(r"([^.\[\]]+)|\[(\d+)\]")


def read_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ValueError(f"cannot read JSON {path}: {exc}") from exc


def stable_json_bytes(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode()


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def path_tokens(path: str) -> list[str | int]:
    tokens: list[str | int] = []
    for match in TOKEN_RE.finditer(path):
        tokens.append(match.group(1) if match.group(1) is not None else int(match.group(2)))
    if not tokens or "".join(str(t) for t in tokens) == "":
        raise ValueError(f"invalid JSON path: {path!r}")
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
    return int(round(result)) if write.get("type", "int") == "int" else result


def feature_levels(feature: dict[str, Any]) -> list[int | float | str]:
    levels = feature.get("values")
    if not isinstance(levels, list) or not levels:
        raise ValueError(f"feature {feature.get('id')} needs a non-empty values list")
    if len({json.dumps(v, sort_keys=True) for v in levels}) != len(levels):
        raise ValueError(f"feature {feature.get('id')} has duplicate values")
    return levels


def baseline_value(content: Any, feature: dict[str, Any]) -> int | float | str:
    levels = feature_levels(feature)
    matches: list[int | float | str] = []
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
        for write in writes:
            path = str(write.get("path", ""))
            if not path or path in seen_paths:
                raise ValueError(f"write path must be non-empty and unique: {path!r}")
            seen_paths.add(path)
            current = get_path(content, path)
            if isinstance(current, bool) or not isinstance(current, (int, float)):
                raise ValueError(f"v1 only supports numeric leaves: {path}")
        baseline[feature["id"]] = baseline_value(content, feature)
    return baseline


def latin_hypercube(count: int, dimensions: int, rng: random.Random) -> list[list[float]]:
    columns: list[list[float]] = []
    for _ in range(dimensions):
        column = [(i + rng.random()) / count for i in range(count)]
        rng.shuffle(column)
        columns.append(column)
    return [[columns[d][i] for d in range(dimensions)] for i in range(count)]


def map_point(point: list[float], features: list[dict[str, Any]]) -> dict[str, Any]:
    values: dict[str, Any] = {}
    for coordinate, feature in zip(point, features, strict=True):
        levels = feature_levels(feature)
        index = min(int(coordinate * len(levels)), len(levels) - 1)
        values[feature["id"]] = levels[index]
    return values


def unique_design(count: int, features: list[dict[str, Any]], baseline: dict[str, Any],
                  rng: random.Random) -> list[dict[str, Any]]:
    if count < 1:
        raise ValueError("count must be positive")
    combinations = 1
    for feature in features:
        combinations *= len(feature_levels(feature))
    if count > combinations:
        raise ValueError(f"requested {count} candidates but only {combinations} combinations exist")
    design = [baseline]
    seen = {stable_json_bytes(baseline)}
    batch = max(count * 2, 16)
    attempts = 0
    while len(design) < count and attempts < 100:
        for point in latin_hypercube(batch, len(features), rng):
            values = map_point(point, features)
            key = stable_json_bytes(values)
            if key not in seen:
                seen.add(key)
                design.append(values)
                if len(design) == count:
                    break
        attempts += 1
    if len(design) != count:
        raise RuntimeError(f"could only generate {len(design)} unique candidates")
    return design


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
    parser.set_defaults(repo=repo)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    repo: Path = args.repo
    space_path = resolve_repo_path(repo, args.space)
    space = read_json(space_path)
    base_path = resolve_repo_path(repo, args.base or space["base"])
    base = read_json(base_path)
    baseline = validate_space(base, space)
    features: list[dict[str, Any]] = space["features"]
    combination_count = 1
    for feature in features:
        combination_count *= len(feature_levels(feature))
    summary = {
        "space": str(space_path),
        "base": str(base_path),
        "features": len(features),
        "numericWrites": sum(len(feature["writes"]) for feature in features),
        "combinations": combination_count,
        "baseline": baseline,
    }
    if args.inventory:
        inventory = numeric_inventory(base)
        print(json.dumps({"numericLeaves": inventory.pop("__total__", 0), "byTopLevel": inventory}, indent=2, sort_keys=True))
        return 0
    if args.check:
        print(json.dumps(summary, indent=2, sort_keys=True))
        return 0
    out = Path(args.out)
    if out.exists():
        if not args.force:
            raise ValueError(f"output exists: {out}; pass --force to replace it")
        shutil.rmtree(out)
    out.mkdir(parents=True)
    rng = random.Random(args.seed)
    design = unique_design(args.count, features, baseline, rng)
    rows: list[dict[str, Any]] = []
    for index, values in enumerate(design):
        candidate_id = f"c{index:03d}"
        candidate_dir = out / candidate_id
        candidate_dir.mkdir()
        content, patch = apply_values(base, features, values)
        content_bytes = stable_json_bytes(content)
        (candidate_dir / "full-content.json").write_bytes(content_bytes)
        candidate = {
            "id": candidate_id,
            "baseline": index == 0,
            "values": values,
            "patch": patch,
            "contentSha256": sha256_bytes(content_bytes),
        }
        (candidate_dir / "candidate.json").write_text(
            json.dumps(candidate, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )
        rows.append(candidate)
    manifest = {
        **summary,
        "seed": args.seed,
        "count": args.count,
        "baseSha256": sha256_bytes(base_path.read_bytes()),
        "spaceSha256": sha256_bytes(space_path.read_bytes()),
        "candidates": rows,
    }
    (out / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    print(json.dumps({"out": str(out), **summary, "count": args.count}, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (KeyError, TypeError, ValueError, RuntimeError) as exc:
        print(f"balance_content_doe: {exc}", file=sys.stderr)
        raise SystemExit(2) from exc
