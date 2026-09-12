#!/usr/bin/env python3
"""Reproducible F1/F2 search analysis and candidate preparation for #458."""
from __future__ import annotations

import argparse
import json
import math
import random
import sys
from pathlib import Path
from typing import Any

from balance_content_doe import (
    apply_values,
    canonical_json_bytes,
    design_metrics,
    feature_levels,
    prepare_output,
    sha256_bytes,
    validate_space,
    verify_requested_values,
)

GRIDS = ("duskblade:v0", "duskblade:v5", "ashwarden:v0", "ashwarden:v5")
RESPONSE_KEYS = ("topRate", "thirdRate", "fourthRate", "within10", "viable",
                 "arm2Rate", "margin")


def response_deficit(values: list[float] | Any) -> float:
    """Derive the transparent normalised deficit from predicted raw responses."""
    total = 0.0
    width = len(RESPONSE_KEYS)
    for offset in range(0, len(GRIDS) * width, width):
        row = dict(zip(RESPONSE_KEYS, values[offset:offset + width], strict=True))
        total += max(0.0, 3.0 - float(row["within10"])) / 3.0
        total += max(0.0, 4.0 - float(row["viable"])) / 4.0
        total += max(0.0, float(row["arm2Rate"]) - 0.5) / 0.5
        total += max(0.0, 0.35 - float(row["margin"])) / 0.35
    return total


def _responses(row: dict[str, Any]) -> list[float]:
    return [float(row["proxies"][grid][key]) for grid in GRIDS for key in RESPONSE_KEYS]


def _summary(values: Any, np: Any) -> dict[str, float]:
    return {"p025": float(np.quantile(values, 0.025)), "p50": float(np.quantile(values, 0.5)),
            "p975": float(np.quantile(values, 0.975))}


def surrogate_report(f0: dict[str, Any], config: dict[str, Any]) -> dict[str, Any]:
    """Candidate-held-out ExtraTrees validation with calibrated intervals and diagnostics."""
    try:
        import numpy as np
        import sklearn
        from scipy.stats import spearmanr
        from sklearn.ensemble import ExtraTreesRegressor
    except ImportError as exc:
        raise RuntimeError("surrogate fitting needs scikit-learn, numpy and scipy") from exc
    rows = [row for row in f0["candidates"]
            if row.get("status") == "complete" and not row.get("earlyStop")]
    features = list(rows[0]["values"])
    x = np.asarray([[row["values"][name] for name in features] for row in rows], dtype=float)
    y = np.asarray([_responses(row) for row in rows], dtype=float)
    scale = np.ptp(y, axis=0)
    scale[scale == 0] = 1.0
    predicted, baseline, lower, upper, models = [], [], [], [], []
    seed = int(config["randomSeed"])
    for held_out in range(len(rows)):
        keep = np.arange(len(rows)) != held_out
        model = ExtraTreesRegressor(
            n_estimators=int(config["nEstimators"]),
            min_samples_leaf=int(config["minSamplesLeaf"]),
            max_features=float(config["maxFeatures"]), bootstrap=bool(config["bootstrap"]),
            max_samples=float(config["maxSamples"]), oob_score=True,
            random_state=seed + held_out, n_jobs=int(config["nJobs"]),
        )
        model.fit(x[keep], y[keep])
        point = model.predict(x[held_out:held_out + 1])[0]
        residual = np.abs(y[keep] - model.oob_prediction_)
        radius = np.quantile(residual, 0.95, axis=0, method="higher")
        distance = np.count_nonzero(x[keep] != x[held_out], axis=1)
        nearest = np.argsort(distance, kind="stable")[:5]
        weights = 1.0 / (1.0 + distance[nearest])
        predicted.append(point)
        baseline.append(np.average(y[keep][nearest], axis=0, weights=weights))
        lower.append(point - radius)
        upper.append(point + radius)
        models.append(model)
    predicted, baseline = np.asarray(predicted), np.asarray(baseline)
    lower, upper = np.asarray(lower), np.asarray(upper)
    actual_deficit = np.asarray([response_deficit(row) for row in y])
    model_deficit = np.asarray([response_deficit(row) for row in predicted])
    baseline_deficit = np.asarray([response_deficit(row) for row in baseline])
    normalised_mae = float(np.mean(np.abs(y - predicted) / scale))
    baseline_mae = float(np.mean(np.abs(y - baseline) / scale))
    model_rho = float(spearmanr(actual_deficit, model_deficit).statistic)
    baseline_rho = float(spearmanr(actual_deficit, baseline_deficit).statistic)
    quartile = int(math.ceil(len(rows) / 4))
    actual_top = set(np.argsort(actual_deficit, kind="stable")[:quartile])
    model_top = set(np.argsort(model_deficit, kind="stable")[:quartile])
    baseline_top = set(np.argsort(baseline_deficit, kind="stable")[:quartile])
    metrics = {
        "normalisedMae": normalised_mae, "baselineNormalisedMae": baseline_mae,
        "deficitSpearman": model_rho, "baselineDeficitSpearman": baseline_rho,
        "topQuartileRecall": len(actual_top & model_top) / quartile,
        "baselineTopQuartileRecall": len(actual_top & baseline_top) / quartile,
        "intervalCoverage": float(np.mean((y >= lower) & (y <= upper))),
    }
    base_error = np.mean(np.abs(y - predicted) / scale, axis=1)
    repeats = int(config["permutationRepeats"])

    def permutation_series(columns: tuple[int, ...], conditional: bool) -> Any:
        series = np.zeros(repeats)
        rng = random.Random(seed + 1009 * sum(index + 1 for index in columns)
                            + (1 if conditional else 0))
        for held_out, model in enumerate(models):
            donors = [index for index in range(len(rows)) if index != held_out]
            if conditional:
                others = [index for index in range(len(features)) if index not in columns]
                distances = {index: sum(x[index, col] != x[held_out, col] for col in others)
                             for index in donors}
                nearest_distance = min(distances.values())
                donors = [index for index in donors if distances[index] == nearest_distance]
            chosen = [rng.choice(donors) for _ in range(repeats)]
            variants = np.repeat(x[held_out:held_out + 1], repeats, axis=0)
            for column in columns:
                variants[:, column] = x[chosen, column]
            errors = np.mean(np.abs(y[held_out] - model.predict(variants)) / scale, axis=1)
            series += errors
        return series / len(rows) - float(np.mean(base_error))

    importance, ordinary = [], {}
    for column, name in enumerate(features):
        raw = permutation_series((column,), False)
        conditional = permutation_series((column,), True)
        ordinary[column] = raw
        importance.append({"feature": name, "permutation": _summary(raw, np),
                           "conditionalPermutation": _summary(conditional, np)})
    importance.sort(key=lambda row: -row["permutation"]["p50"])
    interactions = []
    for left in range(len(features)):
        for right in range(left + 1, len(features)):
            joint = permutation_series((left, right), False)
            strength = joint - ordinary[left] - ordinary[right]
            interactions.append({"features": [features[left], features[right]],
                                 "jointPermutationInteraction": _summary(strength, np)})
    interactions.sort(key=lambda row: -abs(row["jointPermutationInteraction"]["p50"]))
    response_names = [f"{grid}:{key}" for grid in GRIDS for key in RESPONSE_KEYS]
    predictions = [{
        "id": row["id"], "actualDeficit": float(actual_deficit[index]),
        "predictedDeficit": float(model_deficit[index]),
        "baselinePredictedDeficit": float(baseline_deficit[index]),
        "rawResponses": {
            name: {"actual": float(y[index, column]),
                   "predicted": float(predicted[index, column]),
                   "baselinePredicted": float(baseline[index, column]),
                   "interval": {"lower": float(lower[index, column]),
                                "upper": float(upper[index, column])}}
            for column, name in enumerate(response_names)
        },
    } for index, row in enumerate(rows)]
    return {
        "method": config["estimator"], "sklearnVersion": sklearn.__version__,
        "numpyVersion": np.__version__, "candidateHeldOut": True,
        "candidates": len(rows), "features": features,
        "responses": response_names,
        "metrics": metrics, "adequacy": adequacy_decision(metrics, config["adequacy"]),
        "predictions": predictions, "importance": importance, "interactions": interactions,
    }


def adequacy_decision(metrics: dict[str, float], thresholds: dict[str, float]) -> dict[str, Any]:
    """Apply the pre-registered all-must-pass surrogate adequacy rule."""
    checks = {
        "normalisedMaeRatio": metrics["normalisedMae"] / metrics["baselineNormalisedMae"]
        <= thresholds["maxNormalisedMaeRatio"],
        "deficitSpearman": metrics["deficitSpearman"] >= thresholds["minDeficitSpearman"],
        "deficitSpearmanLift": metrics["deficitSpearman"]
        - metrics["baselineDeficitSpearman"] >= thresholds["minSpearmanLift"],
        "topQuartileRecall": metrics["topQuartileRecall"]
        >= thresholds["minTopQuartileRecall"],
        "topQuartileRecallLift": metrics["topQuartileRecall"]
        - metrics["baselineTopQuartileRecall"] >= thresholds["minTopQuartileRecallLift"],
        "intervalCoverage": thresholds["minIntervalCoverage"]
        <= metrics["intervalCoverage"] <= thresholds["maxIntervalCoverage"],
    }
    failed = [name for name, passed in checks.items() if not passed]
    return {"adequate": not failed, "checks": checks, "failed": failed}


def pareto_front(rows: list[dict[str, Any]], field: str) -> list[str]:
    """Return stable IDs that are not dominated when every criterion is minimised."""
    keep: list[str] = []
    for row in rows:
        values = row[field]
        dominated = any(
            all(other[field][key] <= values[key] for key in values)
            and any(other[field][key] < values[key] for key in values)
            for other in rows if other["id"] != row["id"]
        )
        if not dominated:
            keep.append(str(row["id"]))
    return keep


def _vector(row: dict[str, Any], features: list[dict[str, Any]]) -> tuple[int, ...]:
    return tuple(feature_levels(feature).index(row[feature["id"]]) for feature in features)


def balanced_supplemental(features: list[dict[str, Any]], excluded: list[dict[str, Any]],
                          count: int, seed: int, restarts: int) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    """Build a balanced maximin batch with no F0 vector or duplicate."""
    if count < 1 or restarts < 1:
        raise ValueError("count and restarts must be positive")
    excluded_vectors = {_vector(row, features) for row in excluded}
    master = random.Random(seed)
    best_rows: list[list[int]] | None = None
    best_metrics: dict[str, Any] | None = None
    best_score: tuple[int, int, int, float] | None = None
    for _ in range(restarts):
        rng = random.Random(master.getrandbits(64))
        columns: list[list[int]] = []
        for feature in features:
            levels = feature_levels(feature)
            quotient, remainder = divmod(count, len(levels))
            counts = [quotient] * len(levels)
            extras = list(range(len(levels)))
            rng.shuffle(extras)
            for index in extras[:remainder]:
                counts[index] += 1
            pool = [index for index, amount in enumerate(counts) for _ in range(amount)]
            rng.shuffle(pool)
            columns.append(pool)
        rows = [[column[index] for column in columns] for index in range(count)]
        vectors = set(map(tuple, rows))
        if len(vectors) != count or vectors & excluded_vectors:
            continue
        metrics = design_metrics(rows, features)
        metrics["method"] = "balanced-maximin-discrete-v1-supplemental"
        metrics["restarts"] = restarts
        cross = min(
            (sum(left != right for left, right in zip(row, old, strict=True))
             for row in vectors for old in excluded_vectors),
            default=len(features),
        )
        metrics["minimumDistanceFromF0"] = cross
        score = (cross, metrics["minimumHammingDistance"],
                 -metrics["closestPairCount"], -metrics["maximumAbsoluteColumnCorrelation"])
        if best_score is None or score > best_score:
            best_rows, best_metrics, best_score = rows, metrics, score
    if best_rows is None or best_metrics is None:
        raise RuntimeError(f"no supplemental design found in {restarts} seeded restarts")
    values = [
        {feature["id"]: feature_levels(feature)[row[column]]
         for column, feature in enumerate(features)}
        for row in best_rows
    ]
    return values, best_metrics


def write_search_bundle(base_path: Path, space_path: Path, f0_manifest: dict[str, Any],
                        supplemental: list[dict[str, Any]], design: dict[str, Any], out: Path,
                        initial_ids: tuple[str, ...], seed: int) -> dict[str, Any]:
    """Materialise one immutable bundle for common-random-number F1 racing."""
    base_bytes, space_bytes = base_path.read_bytes(), space_path.read_bytes()
    base, space = json.loads(base_bytes), json.loads(space_bytes)
    baseline = validate_space(base, space)
    features: list[dict[str, Any]] = space["features"]
    f0_by_id = {row["id"]: row for row in f0_manifest["candidates"]}
    requested: list[tuple[str, dict[str, Any], str]] = [
        (candidate_id, f0_by_id[candidate_id]["values"], "f0") for candidate_id in initial_ids
    ]
    requested.extend((f"s{index:03d}", values, "supplemental")
                     for index, values in enumerate(supplemental, 1))
    prepared: list[tuple[dict[str, Any], bytes]] = []
    semantic_seen: set[str] = set()
    for candidate_id, values, source in requested:
        content, patch = apply_values(base, features, values)
        verify_requested_values(content, features, values)
        semantic = canonical_json_bytes(content)
        content_bytes = base_bytes if candidate_id == "c000" else semantic + b"\n"
        candidate = {
            "id": candidate_id, "baseline": candidate_id == "c000", "source": source,
            "values": values, "patch": patch, "fileSha256": sha256_bytes(content_bytes),
            "semanticSha256": sha256_bytes(semantic),
        }
        if candidate["semanticSha256"] in semantic_seen:
            raise ValueError(f"duplicate semantic catalogue in F1 bundle: {candidate_id}")
        semantic_seen.add(candidate["semanticSha256"])
        if source == "f0":
            original = f0_by_id[candidate_id]
            if candidate["fileSha256"] != original["fileSha256"] \
                    or candidate["semanticSha256"] != original["semanticSha256"]:
                raise ValueError(f"F0 candidate {candidate_id} no longer replays")
        prepared.append((candidate, content_bytes))
    prepare_output(out, False)
    for candidate, content_bytes in prepared:
        directory = out / candidate["id"]
        directory.mkdir()
        (directory / "full-content.json").write_bytes(content_bytes)
        (directory / "candidate.json").write_text(
            json.dumps(candidate, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
    manifest = {
        "tool": "glassvow-balance-f1-f2", "issue": 458, "seed": seed,
        "count": len(prepared), "baseline": baseline, "supplementalDesign": design,
        "baseIdentity": {"fileSha256": sha256_bytes(base_bytes),
                         "semanticSha256": sha256_bytes(canonical_json_bytes(base))},
        "spaceIdentity": {"fileSha256": sha256_bytes(space_bytes),
                          "semanticSha256": sha256_bytes(canonical_json_bytes(space))},
        "candidates": [candidate for candidate, _ in prepared],
    }
    (out / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return manifest


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--protocol", default="docs/balance/458-f1-f2-protocol-v1.json")
    parser.add_argument("--f0-summary", default="docs/balance/data/457/summary.json")
    parser.add_argument("--f0-manifest", default="docs/balance/data/457/doe-manifest.json")
    parser.add_argument("--space", default="docs/balance/421-content-search-space-v1.json")
    parser.add_argument("--base", default="content/full-content.json")
    parser.add_argument("--report", default="/tmp/glassvow-458/surrogate.json")
    parser.add_argument("--bundle", default="/tmp/glassvow-458/candidates")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    protocol = json.loads(Path(args.protocol).read_text(encoding="utf-8"))
    if protocol.get("schemaVersion") != 1 or protocol.get("id") != "458-f1-f2-v1":
        raise ValueError("unsupported #458 protocol")
    f0 = json.loads(Path(args.f0_summary).read_text(encoding="utf-8"))
    f0_manifest = json.loads(Path(args.f0_manifest).read_text(encoding="utf-8"))
    if len(f0_manifest.get("candidates", [])) < 32:
        raise ValueError("surrogate fitting requires the complete 32-candidate F0 design")
    report = surrogate_report(f0, protocol["surrogate"])
    supplemental: list[dict[str, Any]] = []
    design: dict[str, Any] = {"method": "none", "reason": "surrogate adequate; no new proposal required"}
    if not report["adequacy"]["adequate"]:
        space = json.loads(Path(args.space).read_text(encoding="utf-8"))
        supplemental, design = balanced_supplemental(
            space["features"], [row["values"] for row in f0_manifest["candidates"]],
            int(protocol["supplemental"]["count"]), int(protocol["supplemental"]["seed"]),
            int(protocol["supplemental"]["restarts"]),
        )
    bundle = write_search_bundle(
        Path(args.base), Path(args.space), f0_manifest, supplemental, design, Path(args.bundle),
        ("c000", "c002", "c029"), int(protocol["supplemental"]["seed"]),
    )
    inputs = {
        "protocolSha256": sha256_bytes(Path(args.protocol).read_bytes()),
        "f0SummarySha256": sha256_bytes(Path(args.f0_summary).read_bytes()),
        "f0ManifestSha256": sha256_bytes(Path(args.f0_manifest).read_bytes()),
        "toolSha256": sha256_bytes(Path(__file__).read_bytes()),
    }
    bundle.update(inputs)
    (Path(args.bundle) / "manifest.json").write_text(
        json.dumps(bundle, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    report["inputs"] = inputs
    report["proposalDecision"] = {
        "surrogateProposals": [], "supplementalTriggered": bool(supplemental),
        "reason": "adequacy failed; use the pre-registered balanced maximin batch"
        if supplemental else "adequate model; race the existing identity-clean F0 set",
        "candidateBundleManifestSha256": sha256_bytes(
            (Path(args.bundle) / "manifest.json").read_bytes()),
        "candidateCount": bundle["count"],
    }
    report_path = Path(args.report)
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"adequate": report["adequacy"]["adequate"],
                      "failed": report["adequacy"]["failed"],
                      "supplemental": len(supplemental), "candidateCount": bundle["count"],
                      "report": str(report_path), "bundle": str(args.bundle)}, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (KeyError, OSError, TypeError, ValueError, RuntimeError) as exc:
        print(f"balance_f1_f2: {exc}", file=sys.stderr)
        raise SystemExit(2) from exc
