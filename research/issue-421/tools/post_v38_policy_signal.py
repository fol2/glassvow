#!/usr/bin/env python3
"""Zero-row policy-signal audit for the issue #421 factorial evidence."""

from __future__ import annotations

import argparse
import json
import math
import random
import sqlite3
import statistics
from pathlib import Path
from typing import Any

import numpy as np
import sklearn
from sklearn.ensemble import HistGradientBoostingRegressor
from sklearn.metrics import r2_score
from sklearn.model_selection import GroupKFold, cross_val_score
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.linear_model import Ridge

import research as core


FACTORIAL_PROTOCOL_SHA = "9c53ef14c63b4981eedbb5b1aab315da5ad46d0cf45f174a52340d8d09427d01"
PROTOCOL = core.ROOT / "protocols/post-v38-policy-signal-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-policy-signal-v1.json"
ROUTES = {
    "scoreline": ("scorelineApplied", "scorelineConsumed"),
    "afterimage": ("afterimageApplied", "afterimageConsumed"),
}


def _flatten(value: dict[str, Any], prefix: str = "") -> dict[str, float]:
    out: dict[str, float] = {}
    for key in sorted(value):
        if key == "_research421":
            continue
        name = f"{prefix}.{key}" if prefix else key
        child = value[key]
        if isinstance(child, dict):
            out.update(_flatten(child, name))
        elif isinstance(child, (int, float)):
            out[name] = float(child)
        else:
            raise ValueError(f"non-numeric policy leaf {name}")
    return out


def _cell(row_id: str, split: str) -> tuple[str, dict[str, float]]:
    prefix = f"factorial-policy-{split}-"
    if not row_id.startswith(prefix):
        raise ValueError(f"unexpected policy row id {row_id}")
    cell, _policy, _seed = row_id.removeprefix(prefix).rsplit("-", 2)
    parts = dict(part.split("-", 1) for part in cell.split("__"))
    return cell, {
        "cell.scoreHigh": float(parts["score"] == "high"),
        "cell.afterHigh": float(parts["after"] == "high"),
        "cell.setup": float(parts["setup"]),
        "cell.acquisition": float(parts["acq"]),
        "cell.rarityRare": float(parts["rarity"] == "rare"),
    }


def _rows() -> list[dict[str, Any]]:
    db = sqlite3.connect(core.LEDGER)
    found = []
    for (raw,) in db.execute(
        "SELECT payload_json FROM records WHERE kind = 'observation' AND identity LIKE ?",
        (f"{FACTORIAL_PROTOCOL_SHA}:%",),
    ):
        row = json.loads(raw)
        if row.get("stage") == "post-v38-factorial-policy":
            found.append(row)
    if len(found) != 12288:
        raise ValueError(f"expected 12288 frozen policy rows, got {len(found)}")
    return found


def _dataset(rows: list[dict[str, Any]], split: str, route: str) -> tuple[
        np.ndarray, np.ndarray, np.ndarray, np.ndarray, list[str]]:
    applied, consumed = ROUTES[route]
    buckets: dict[tuple[str, int], dict[str, Any]] = {}
    for row in rows:
        if f"-{split}-" not in row["id"]:
            continue
        cell, cell_values = _cell(row["id"], split)
        key = (cell, int(row["policyIndex"]))
        bucket = buckets.setdefault(key, {
            "cell": cell_values, "policy": _flatten(row["policy"]), "targets": [],
        })
        if bucket["policy"] != _flatten(row["policy"]):
            raise ValueError(f"policy drift within {key}")
        events = row.get("packageEvents") or {}
        bucket["targets"].append(min(
            int(events.get(applied, 0)), int(events.get(consumed, 0))))
    if len(buckets) != 1536 or any(len(row["targets"]) != 4 for row in buckets.values()):
        raise ValueError(f"incomplete {split}/{route} policy-cell rectangle")
    policy_names = sorted(next(iter(buckets.values()))["policy"])
    cell_names = sorted(next(iter(buckets.values()))["cell"])
    feature_names = [*policy_names, *cell_names,
                     *(f"{policy}*{cell}" for policy in policy_names for cell in cell_names)]
    full, baseline, target, groups = [], [], [], []
    for (cell, policy_index), row in sorted(buckets.items()):
        policy = [row["policy"][name] for name in policy_names]
        factors = [row["cell"][name] for name in cell_names]
        full.append([*policy, *factors,
                     *(left * right for left in policy for right in factors)])
        baseline.append(factors)
        target.append(math.log1p(statistics.fmean(row["targets"])))
        groups.append(policy_index)
    return (np.asarray(full), np.asarray(baseline), np.asarray(target),
            np.asarray(groups), feature_names)


def _model(name: str) -> Any:
    if name.startswith("ridge-"):
        alpha = float(name.split("-", 1)[1])
        return make_pipeline(StandardScaler(), Ridge(alpha=alpha, solver="svd"))
    if name == "hist-gradient-boosting":
        return HistGradientBoostingRegressor(
            learning_rate=0.05, max_iter=200, max_leaf_nodes=15,
            l2_regularization=1.0, random_state=421,
        )
    raise ValueError(name)


def _interval(values: list[float]) -> dict[str, float]:
    return {"point": statistics.fmean(values),
            "p025": core.percentile(values, 0.025),
            "p975": core.percentile(values, 0.975)}


def _bootstrap(y: np.ndarray, full: np.ndarray, baseline: np.ndarray,
               groups: np.ndarray, seed: int) -> dict[str, Any]:
    rng = random.Random(seed)
    unique = sorted(set(int(group) for group in groups))
    by_group = {group: np.flatnonzero(groups == group) for group in unique}
    full_scores, baseline_scores, deltas = [], [], []
    for _ in range(5000):
        indices = np.concatenate([by_group[rng.choice(unique)] for _ in unique])
        full_score = r2_score(y[indices], full[indices])
        baseline_score = r2_score(y[indices], baseline[indices])
        full_scores.append(float(full_score))
        baseline_scores.append(float(baseline_score))
        deltas.append(float(full_score - baseline_score))
    return {"fullR2": _interval(full_scores), "cellOnlyR2": _interval(baseline_scores),
            "policyIncrementR2": _interval(deltas)}


def analyse(rows: list[dict[str, Any]]) -> dict[str, Any]:
    candidates = ("ridge-1", "ridge-10", "ridge-100", "hist-gradient-boosting")
    routes: dict[str, Any] = {}
    for route_index, route in enumerate(ROUTES):
        x_discovery, base_discovery, y_discovery, groups, names = _dataset(
            rows, "discovery", route)
        x_validation, base_validation, y_validation, validation_groups, names_v = _dataset(
            rows, "validation", route)
        if names != names_v:
            raise ValueError("feature identities differ across splits")
        cv = GroupKFold(n_splits=8)
        scores = {name: float(statistics.fmean(cross_val_score(
            _model(name), x_discovery, y_discovery, groups=groups,
            cv=cv, scoring="r2"))) for name in candidates}
        selected = max(candidates, key=lambda name: (scores[name], -candidates.index(name)))
        full_model = _model(selected).fit(x_discovery, y_discovery)
        baseline_model = _model(selected).fit(base_discovery, y_discovery)
        full_prediction = full_model.predict(x_validation)
        baseline_prediction = baseline_model.predict(base_validation)
        evidence = _bootstrap(
            y_validation, full_prediction, baseline_prediction, validation_groups,
            42100 + route_index,
        )
        heldout_r2 = float(r2_score(y_validation, full_prediction))
        baseline_r2 = float(r2_score(y_validation, baseline_prediction))
        clear = heldout_r2 >= 0.50 and evidence["policyIncrementR2"]["p025"] > 0
        routes[route] = {
            "selectedModel": selected, "discoveryGroupedCvR2": scores,
            "heldoutR2": heldout_r2, "heldoutCellOnlyR2": baseline_r2,
            "bootstrapByValidationPolicy": evidence,
            "policyGroupsPerSplit": 32, "cellCount": 48,
            "featureCount": len(names), "clear": clear,
        }
    clear = all(row["clear"] for row in routes.values())
    return {
        "schemaVersion": 1, "stage": "post-v38-policy-signal",
        "target": "log1p of mean mediator consumptions over four seeds per policy-cell",
        "routes": routes,
        "decision": "binary-predicate-saturated" if clear else "policy-grammar-insufficient",
    }


def execute() -> None:
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    runner_sha = core.file_sha(Path(__file__))
    if runner_sha != protocol["immutableInputs"]["runnerSha256"]:
        raise RuntimeError("runner drift")
    if np.__version__ != protocol["immutableInputs"]["numpyVersion"] \
            or sklearn.__version__ != protocol["immutableInputs"]["sklearnVersion"]:
        raise RuntimeError("ML dependency drift")
    db = core.open_ledger()
    if core.existing_record(db, protocol_sha) is None:
        count = int(db.execute("SELECT COUNT(*) FROM records").fetchone()[0])
        if count != protocol["immutableInputs"]["ledgerRecordsAtFreeze"] \
                or core.file_sha(core.LEDGER) != protocol["immutableInputs"]["ledgerSha256AtFreeze"]:
            raise RuntimeError("ledger changed after protocol freeze")
    core.record(db, "protocol", protocol_sha, protocol)
    result = analyse(_rows())
    result["protocolSha256"] = protocol_sha
    result["runnerSha256"] = runner_sha
    digest, _ = core.cache_json(result)
    core.record(db, "analysis", f"post-v38-policy-signal:{protocol_sha}",
                {**result, "analysisSha256": digest})
    SUMMARY.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"decision": result["decision"], "summary": str(SUMMARY),
                      "analysisSha256": digest}, sort_keys=True))


def self_check() -> None:
    policy = {"a": 1, "nested": {"b": 2}, "_research421": {"ignored": 3}}
    assert _flatten(policy) == {"a": 1.0, "nested.b": 2.0}
    model = _model("ridge-10")
    x = np.arange(16, dtype=float).reshape(-1, 1)
    prediction = model.fit(x, x[:, 0]).predict([[16]])[0]
    assert 12 < prediction < 14
    print("PASS post_v38_policy_signal.py self-check")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("self-check", "execute"))
    args = parser.parse_args()
    self_check() if args.command == "self-check" else execute()


if __name__ == "__main__":
    main()
