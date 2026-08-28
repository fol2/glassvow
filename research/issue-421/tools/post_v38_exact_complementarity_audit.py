#!/usr/bin/env python3
"""Zero-row exact-content complementarity audit for Glassvow issue #421."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity_v1
import research as core


SUMMARY = core.ROOT / "summaries/post-v38-exact-complementarity-audit-v1.json"
CANDIDATE_SHA = "765d9efd639fe3507d92ea2f7515b3ed92afd15166925a6db2f8934e3a777f07"
INPUTS = {
    "factorialProtocol": (
        "protocols/post-v38-factorial-v1.json",
        "9c53ef14c63b4981eedbb5b1aab315da5ad46d0cf45f174a52340d8d09427d01",
    ),
    "factorialSummary": (
        "summaries/post-v38-factorial-v1.json",
        "3244f38ca060c3257b6fb21846752e2887b8655d78a40575878c5891f2484795",
    ),
    "localDiscovery": (
        "cache/sha256/86ece2a789b71f827a51d3bab4866fb1ed094301cbc87f315a2bf918f04e67b0.json",
        "86ece2a789b71f827a51d3bab4866fb1ed094301cbc87f315a2bf918f04e67b0",
    ),
    "localValidation": (
        "cache/sha256/36721f0976f47ccc0402e2aafbdd071e1f702fd2480a5a25f91320752d2a946b.json",
        "36721f0976f47ccc0402e2aafbdd071e1f702fd2480a5a25f91320752d2a946b",
    ),
    "heldOutProtocol": (
        "protocols/post-v38-heldout-confirmation-v1.json",
        "d8496263dbaab0534cf44702e9ea1078c952b87c145b5c04b3492085d6f15be0",
    ),
    "heldOutSummary": (
        "summaries/post-v38-heldout-confirmation-v1.json",
        "1574e08b855cb17381e0333db26f091d352a5c6ed0c21ec381238bd9eafb280f",
    ),
    "heldOutAnalysis": (
        "cache/sha256/aa4ac97242d701bd3ff187ebcf8ee6bd804e7277845aba0474f435267b03dcb3.json",
        "aa4ac97242d701bd3ff187ebcf8ee6bd804e7277845aba0474f435267b03dcb3",
    ),
}


def load_inputs() -> dict[str, dict[str, Any]]:
    loaded: dict[str, dict[str, Any]] = {}
    for name, (relative, expected) in INPUTS.items():
        path = core.ROOT / relative
        if not path.is_file() or core.file_sha(path) != expected:
            raise RuntimeError(f"immutable audit input drifted: {name}")
        loaded[name] = json.loads(path.read_text())
    return loaded


def compact_cell(cell: dict[str, Any]) -> dict[str, Any]:
    return {
        "activation": cell["activation"],
        "aspectSeparation": cell["aspectSeparation"],
        "duration": cell["duration"],
        "policyWitnesses": cell["policyWitnesses"],
        "addedStalls": cell["addedStalls"],
        "clear": cell["clear"],
        "decisiveFailure": cell["decisiveFailure"],
    }


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite an existing complementarity audit")
    inputs = load_inputs()
    protocol = inputs["factorialProtocol"]
    if protocol["contentVariants"]["score-low__after-low__rarity-uncommon"] \
            != CANDIDATE_SHA:
        raise RuntimeError("factorial evidence does not bind the selected content")
    if inputs["heldOutSummary"].get("decision") != "confirm-one-frozen-candidate" \
            or inputs["heldOutSummary"]["candidate"]["contentSha256"] != CANDIDATE_SHA:
        raise RuntimeError("whole-run held-out entry gate is not exact")
    discovery = inputs["localDiscovery"]["cells"]
    validation = inputs["localValidation"]["cells"]
    score = "dusk-scoreline:low:setup-0"
    after = "dusk-afterimage-guard:low:setup-0"
    after_control = "dusk-afterimage-guard:low:setup-2"
    if not discovery[score]["clear"] or not validation[score]["clear"]:
        raise RuntimeError("existing exact Scoreline complementarity is not reproducible")
    if discovery[after]["clear"] or validation[after]["clear"] \
            or discovery[after]["decisiveFailure"] \
            or validation[after]["decisiveFailure"]:
        raise RuntimeError("existing W0 Afterimage result was misclassified")
    if not discovery[after_control]["clear"] or not validation[after_control]["clear"]:
        raise RuntimeError("existing W2 Afterimage mechanism control is not reproducible")
    held_out = inputs["heldOutAnalysis"]
    if not held_out["strategyPackageActivation"]["clear"]:
        raise RuntimeError("whole-run four-package activation gate is not green")
    ledger = identity_v1.ledger_identity()
    result = {
        "schemaVersion": 1,
        "decision": "heldout-four-package-causal-panel-required",
        "candidateContentSha256": CANDIDATE_SHA,
        "newSimulatorObservationRows": 0,
        "immutableInputs": {name: digest for name, (_, digest) in INPUTS.items()},
        "existingExactCandidateDuskEvidence": {
            "scorelineW0": {
                "discovery": compact_cell(discovery[score]),
                "validation": compact_cell(validation[score]),
                "decision": "reproducible-clear",
            },
            "afterimageW0": {
                "discovery": compact_cell(discovery[after]),
                "validation": compact_cell(validation[after]),
                "decision": "unresolved-not-decisive",
            },
            "afterimageW2MechanismControl": {
                "discovery": compact_cell(discovery[after_control]),
                "validation": compact_cell(validation[after_control]),
                "decision": "reproducible-clear-but-not-the-frozen-W0-setting",
            },
        },
        "wholeRunHeldOut": {
            "decision": held_out["decision"],
            "policyIdentityAudit": held_out["policyIdentityAudit"],
            "strategyPackageActivation": held_out["strategyPackageActivation"],
        },
        "evidenceBoundary": {
            "resolved": "Exact-content Scoreline local complementarity and four-package whole-run held-out activation/repertoire evidence.",
            "unresolved": "Exact frozen-setting Afterimage complementarity and exact-content held-out local complementarity for both Ash packages.",
            "cheapestDiscriminator": "One equal 128-policy causal panel covering all four packages, both aspects and all four none/A/B/AB arms on the exact candidate content and frozen Q2/W0 settings.",
            "forbiddenInference": "Do not substitute the W2 Afterimage control or older non-exact Ash content for the frozen candidate, and do not give only unresolved or promising packages extra support.",
        },
        "ledgerUnchanged": ledger,
        "authority": "Preregister one 4 x 2 x 4 x 128 equal-cohort exact-candidate causal panel. No alternative scalar cell, ML, RL, product promotion or protected seed is authorised.",
    }
    SUMMARY.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": "PASS",
        "decision": result["decision"],
        "summarySha256": core.file_sha(SUMMARY),
        "newSimulatorObservationRows": 0,
        "ledgerRecords": ledger["records"],
    }))


if __name__ == "__main__":
    main()
