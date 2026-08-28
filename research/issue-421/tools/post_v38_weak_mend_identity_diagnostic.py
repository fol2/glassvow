#!/usr/bin/env python3
"""Zero-row diagnosis of the frozen weak-mend identity failure."""

from __future__ import annotations

import copy
import json
from pathlib import Path
from typing import Any

import research as core


IDENTITY = core.ROOT / "summaries/post-v38-weak-mend-identity-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-weak-mend-identity-diagnostic-v1.json"
SOURCE = core.ROOT / "weak-mend-identity-source"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Weak-mend diagnostic mismatch: {label}")


def ordered_differences(left: Any, right: Any, path: str = "") -> list[str]:
    differences: list[str] = []
    if isinstance(left, dict) and isinstance(right, dict):
        if list(left) != list(right):
            differences.append(path or "$")
        for key in left.keys() & right.keys():
            differences.extend(ordered_differences(
                left[key], right[key], f"{path}.{key}" if path else str(key)
            ))
    elif isinstance(left, list) and isinstance(right, list):
        for index, (a, b) in enumerate(zip(left, right)):
            differences.extend(ordered_differences(a, b, f"{path}[{index}]"))
    return differences


def first_list_difference(left: list[Any], right: list[Any]) -> dict[str, Any]:
    for index, (a, b) in enumerate(zip(left, right)):
        if a != b:
            return {"index": index, "omitted": a, "zero": b}
    return {"index": min(len(left), len(right)), "omitted": None, "zero": None}


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the weak-mend diagnostic")
    identity = json.loads(IDENTITY.read_text())
    require("frozen identity outcome", identity["decisionBoundary"] == 2)
    require("focused controls passed", not identity["controlFaults"])
    objects = identity["cacheObjects"]
    omitted_path = core.CACHE / f"{objects['omittedWholeOutputSha256']}.json"
    zero_path = core.CACHE / f"{objects['zeroWholeOutputSha256']}.json"
    zero_content_path = core.CACHE / f"{objects['explicitZeroContentSha256']}.json"
    for path in (omitted_path, zero_path, zero_content_path):
        require(f"cache {path.name}", core.file_sha(path) == path.stem)

    base_content = json.loads((SOURCE / "content/full-content.json").read_text())
    zero_content = json.loads(zero_content_path.read_text())
    stripped_zero = copy.deepcopy(zero_content)
    weak_mend = stripped_zero["relics"]["emberHeart"].pop("weakMend")
    require("zero factor level", weak_mend == 0)
    require("semantic content delta", stripped_zero == base_content)
    order_differences = ordered_differences(base_content, stripped_zero)
    base_affixes = list(base_content["affixes"])
    zero_affixes = list(zero_content["affixes"])
    require("affix order changed", base_affixes != zero_affixes)
    combat_source = (SOURCE / "domain/rules/combat.gd").read_text()
    require("affix selection consumes dictionary order",
            "var keys: Array = content.affixes.keys()" in combat_source)

    omitted_rows = json.loads(omitted_path.read_text())["rows"]
    zero_rows = json.loads(zero_path.read_text())["rows"]
    require("paired rows", len(omitted_rows) == len(zero_rows) == 256)
    mismatches = [index for index, pair in enumerate(zip(omitted_rows, zero_rows))
                  if pair[0] != pair[1]]
    first_index = mismatches[0]
    omitted = omitted_rows[first_index]
    zero = zero_rows[first_index]
    changed_fields = [key for key in omitted if omitted[key] != zero[key]]
    trajectory_differences = {
        key: first_list_difference(omitted["trajectory"][key], zero["trajectory"][key])
        for key in omitted["trajectory"]
        if isinstance(omitted["trajectory"][key], list)
        and omitted["trajectory"][key] != zero["trajectory"][key]
    }
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "kind": "zero-row-read-only-diagnostic",
        "identitySummarySha256": core.file_sha(IDENTITY),
        "sourceCommit": "c4130163c7fb8edd865c0adc95732aae03e1bad2",
        "combatRulesSha256": core.file_sha(SOURCE / "domain/rules/combat.gd"),
        "semanticContentDeltaAfterRemovingFactor": 0,
        "weakMendLevel": weak_mend,
        "dictionaryOrderDifferenceCount": len(order_differences),
        "dictionaryOrderDifferenceExamples": order_differences[:20],
        "affixOrder": {"omitted": base_affixes, "explicitZero": zero_affixes},
        "pathSensitiveSource": "CombatRules.start_combat selects affixes from content.affixes.keys() in insertion order.",
        "recomputedIdentity": {
            "pairedRows": len(omitted_rows),
            "mismatchRows": len(mismatches),
            "rngMismatchRows": sum(a["rng"] != b["rng"]
                                   for a, b in zip(omitted_rows, zero_rows)),
            "trajectoryMismatchRows": sum(a["trajectory"] != b["trajectory"]
                                          for a, b in zip(omitted_rows, zero_rows)),
            "firstMismatchRowIndex": first_index,
            "firstMismatchChangedFields": changed_fields,
            "firstTrajectoryDifferences": trajectory_differences,
        },
        "failureClass": "candidate-content-construction-order-alias",
        "finding": "Canonical JSON construction sorted every dictionary. Although the sole semantic value delta was emberHeart.weakMend=0, the serialised order of path-sensitive catalogues, including affixes, changed. The explicit-zero arm therefore did not encode the frozen null path.",
        "decision": "Preserve preregistered decision boundary 2. The focused primitive isolation passed, but weak-mend-persistence is closed without constructor repair or rerun.",
        "newSimulatorRows": 0,
        "newLedgerRows": 0,
        "protectedSeeds": 0,
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": "PASS",
        "failureClass": summary["failureClass"],
        "mismatchRows": len(mismatches),
        "summarySha256": core.file_sha(SUMMARY),
    }))


if __name__ == "__main__":
    main()
