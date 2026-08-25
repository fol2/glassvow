#!/usr/bin/env python3
"""Uncertainty-aware sequential-racing decisions for #458."""
from __future__ import annotations

from typing import Any

DEFICIT_KEYS = ("c1a", "c1b", "c2arm", "c2gap")


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


def _hard_constraint_regression(row: dict[str, Any]) -> bool:
    grids = row.get("bootstrap", {}).get("grids", {})
    return any(float(proxy["arm2Rate"]["p025"]) >= 0.5
               or float(proxy["margin"]["p975"]) < 0.35 for proxy in grids.values())


def _credible_binding_path(row: dict[str, Any]) -> bool:
    paired = row.get("bootstrap", {}).get("vsC000", {}).get("deficitDelta", {})
    return any(key in paired and float(paired[key]["p975"]) > 0.0
               for key in ("c1a", "c1b"))


def racing_decisions(rows: list[dict[str, Any]], max_promotions: int) -> list[dict[str, str]]:
    """Record deterministic promote/stop decisions from the evidence at one layer."""
    baseline = next((row for row in rows if row.get("id") == "c000"), None)
    if baseline is None:
        raise ValueError("racing summary has no c000 paired incumbent")
    complete = [row for row in rows if row.get("status") == "complete"
                and not row.get("earlyStop") and not _hard_constraint_regression(row)]
    decisions: list[dict[str, str]] = []
    survivors: list[dict[str, Any]] = []
    for row in rows:
        candidate_id = str(row["id"])
        if candidate_id == "c000":
            decisions.append({"id": candidate_id, "decision": "baseline",
                              "reason": "paired-incumbent"})
        elif row.get("status") != "complete" or row.get("earlyStop"):
            decisions.append({"id": candidate_id, "decision": "stop",
                              "reason": str(row.get("earlyStop") or "incomplete")})
        elif _hard_constraint_regression(row):
            decisions.append({"id": candidate_id, "decision": "stop",
                              "reason": "hard-constraint-regression"})
        elif any(_envelope_dominates(other, row) for other in complete
                 if other["id"] != row["id"]):
            decisions.append({"id": candidate_id, "decision": "stop",
                              "reason": "confidence-envelope-dominated"})
        elif not _credible_binding_path(row):
            decisions.append({"id": candidate_id, "decision": "stop",
                              "reason": "no-credible-binding-improvement"})
        else:
            survivors.append(row)
    survivors.sort(key=lambda row: (float(row["deficits"]["sum"]), str(row["id"])))
    promoted = {str(row["id"]) for row in survivors[:max_promotions]}
    for row in survivors:
        candidate_id = str(row["id"])
        decisions.append({
            "id": candidate_id,
            "decision": "promote" if candidate_id in promoted else "stop",
            "reason": "non-dominated" if candidate_id in promoted else "bounded-racing-budget",
        })
    return decisions
