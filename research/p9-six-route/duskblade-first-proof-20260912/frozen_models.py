"""D547-PC1 development-only standardisation and nearest-centroid inference.

This module computes arithmetic, not provenance. Callers must first bind the
training records, feature declaration and model bytes to the external manifest.
"""
from __future__ import annotations

import math


def vector(value, width):
    if not isinstance(value, list) or len(value) != width:
        raise ValueError("model vector width")
    if any(type(x) not in (int, float) or not math.isfinite(x) for x in value):
        raise ValueError("model finite numeric vector required")
    return value


def fit(cases, names, classes):
    """Deterministically reconstruct the specified development estimator."""
    if not isinstance(names, list) or not 1 <= len(names) <= 32:
        raise ValueError("model feature count")
    if len(set(names)) != len(names) or any(not isinstance(n, str) for n in names):
        raise ValueError("model feature names")
    if not isinstance(cases, list) or not cases or len(set(classes)) != 2:
        raise ValueError("model training/classes")
    rows, labels = [], []
    for case in cases:
        if not isinstance(case, dict) or set(case) != {"x", "label"}:
            raise ValueError("model training schema")
        rows.append(vector(case["x"], len(names)))
        if type(case["label"]) is not int or case["label"] not in classes:
            raise ValueError("model training label")
        labels.append(case["label"])
    if set(labels) != set(classes):
        raise ValueError("model missing development class")
    mean = [math.fsum(row[j] for row in rows) / len(rows) for j in range(len(names))]
    scale = [math.sqrt(math.fsum((row[j] - mean[j]) ** 2 for row in rows) / len(rows))
             for j in range(len(names))]
    scaled = [[(row[j] - mean[j]) / scale[j] if scale[j] else 0.0
               for j in range(len(names))] for row in rows]
    centroids = {}
    for label in classes:
        selected = [row for row, y in zip(scaled, labels) if y == label]
        centroids[str(label)] = [math.fsum(row[j] for row in selected) / len(selected)
                                 for j in range(len(names))]
    return {"recipe": "standardised-nearest-centroid-v1", "features": names[:],
            "classes": list(classes), "mean": mean, "scale": scale,
            "centroids": centroids}


def validate(model, cases=None, names=None, classes=None):
    if not isinstance(model, dict) or set(model) != {
        "recipe", "features", "classes", "mean", "scale", "centroids"
    }:
        raise ValueError("model schema")
    if model["recipe"] != "standardised-nearest-centroid-v1":
        raise ValueError("model recipe")
    features, labels = model["features"], model["classes"]
    if not isinstance(features, list) or not 1 <= len(features) <= 32:
        raise ValueError("model features")
    if any(not isinstance(n, str) or not n for n in features) or len(set(features)) != len(features):
        raise ValueError("model feature names")
    if (not isinstance(labels, list) or len(labels) != 2 or
            any(type(x) is not int for x in labels) or len(set(labels)) != 2):
        raise ValueError("model classes")
    width = len(features)
    vector(model["mean"], width)
    if any(x < 0 for x in vector(model["scale"], width)):
        raise ValueError("model negative standard deviation")
    if not isinstance(model["centroids"], dict) or set(model["centroids"]) != set(map(str, labels)):
        raise ValueError("model centroids")
    for centroid in model["centroids"].values():
        vector(centroid, width)
    if names is not None and features != names:
        raise ValueError("model feature declaration mismatch")
    if classes is not None and labels != list(classes):
        raise ValueError("model class declaration mismatch")
    if cases is not None and model != fit(cases, features, labels):
        raise ValueError("model is not the frozen development estimator")
    return model


def predict(model, values):
    """Exact squared-distance ties abstain (None), including constant features."""
    x = vector(values, len(model["features"]))
    z = [(v - m) / s if s else 0.0
         for v, m, s in zip(x, model["mean"], model["scale"])]
    distances = [(math.fsum((a - b) ** 2 for a, b in zip(z, model["centroids"][str(c)])), c)
                 for c in model["classes"]]
    if not all(math.isfinite(d) for d, _ in distances):
        raise ValueError("model distance overflow")
    if distances[0][0] == distances[1][0]:
        return None
    return min(distances)[1]


def features(public, names):
    if not isinstance(public, dict) or any(name not in public for name in names):
        raise ValueError("missing registered public feature")
    return vector([public[name] for name in names], len(names))
