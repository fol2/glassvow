#!/usr/bin/env python3
"""Reproducible F1/F2 search analysis and candidate preparation for #458."""
from __future__ import annotations

import random
from typing import Any

from balance_content_doe import design_metrics, feature_levels

DEFICIT_KEYS = ("c1a", "c1b", "c2arm", "c2gap")


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


def _envelope_dominates(left: dict[str, Any], right: dict[str, Any]) -> bool:
    left_intervals = left.get("bootstrap", {}).get("deficits", {})
    right_intervals = right.get("bootstrap", {}).get("deficits", {})
    if not all(key in left_intervals and key in right_intervals for key in DEFICIT_KEYS):
        return False
    weak = all(left_intervals[key]["p975"] <= right_intervals[key]["p025"]
               for key in DEFICIT_KEYS)
    strict = any(left_intervals[key]["p975"] < right_intervals[key]["p025"]
                 for key in DEFICIT_KEYS)
    return weak and strict


def racing_decisions(rows: list[dict[str, Any]], max_promotions: int) -> list[dict[str, str]]:
    """Record deterministic promote/stop decisions from the evidence at one layer."""
    complete = [row for row in rows if row.get("status") == "complete" and not row.get("earlyStop")]
    decisions: list[dict[str, str]] = []
    survivors: list[dict[str, Any]] = []
    for row in rows:
        candidate_id = str(row["id"])
        if candidate_id == "c000":
            decisions.append({"id": candidate_id, "decision": "baseline", "reason": "paired-incumbent"})
        elif row.get("status") != "complete" or row.get("earlyStop"):
            decisions.append({"id": candidate_id, "decision": "stop",
                              "reason": str(row.get("earlyStop") or "incomplete")})
        elif any(_envelope_dominates(other, row) for other in complete
                 if other["id"] != row["id"]):
            decisions.append({"id": candidate_id, "decision": "stop",
                              "reason": "confidence-envelope-dominated"})
        else:
            survivors.append(row)
    survivors.sort(key=lambda row: (float(row["deficits"]["sum"]), str(row["id"])))
    promoted = {str(row["id"]) for row in survivors[:max_promotions]}
    for row in survivors:
        candidate_id = str(row["id"])
        decisions.append({"id": candidate_id, "decision": "promote" if candidate_id in promoted else "stop",
                          "reason": "non-dominated" if candidate_id in promoted else "bounded-racing-budget"})
    return decisions
