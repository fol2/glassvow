#!/usr/bin/env python3
"""Zero-row provenance and authority audit for issue #421 evidence."""

from __future__ import annotations

import hashlib
import json
import subprocess
import time
from pathlib import Path
from typing import Any

import post_v38_action_grammar_inventory as trace
import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-provenance-authority-audit-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-provenance-authority-audit-v1.json"


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Provenance-authority audit mismatch: {label}")


def canonical_sha(value: Any) -> str:
    return hashlib.sha256(core.canonical(value).encode()).hexdigest()


def git_blob(path: str) -> bytes:
    return subprocess.run(
        ["git", "show", f"HEAD:{path}"], cwd=core.SOURCE,
        check=True, capture_output=True,
    ).stdout


def affected_protocol_manifest(anchors: dict[str, str]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for path in sorted((core.ROOT / "protocols").glob("post-v38-*.json")):
        if path == PROTOCOL:
            continue
        text = path.read_text()
        hits = [name for name, digest in anchors.items() if digest in text]
        if hits:
            rows.append({
                "path": str(path.relative_to(core.ROOT)),
                "sha256": core.file_sha(path),
                "anchors": hits,
            })
    return rows


def frozen_rows(
    output: dict[str, Any], arm: str, aspect: str, vow: int,
) -> dict[tuple[int, int], dict[str, Any]]:
    return {
        (int(row["policyIndex"]), int(row["seed"])): row
        for row in output["rows"]
        if row.get("arm") == arm and row.get("aspect") == aspect
        and int(row.get("vow", -1)) == vow
    }


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the provenance-authority summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    immutable = protocol["immutableInputs"]
    require("runner SHA", core.file_sha(Path(__file__)) == immutable["runnerSha256"])
    for helper_path, expected_sha in immutable["helperSha256"].items():
        require(f"{helper_path} SHA", core.file_sha(core.ROOT / helper_path) == expected_sha)
    require("source commit", subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=core.SOURCE, check=True,
        text=True, capture_output=True,
    ).stdout.strip() == immutable["sourceCommit"])
    for source_path, expected_sha in immutable["pristineCurrentMainSha256"].items():
        require(f"pristine {source_path} SHA", core.sha(git_blob(source_path)) == expected_sha)
    for path, expected_sha in immutable["fileSha256"].items():
        require(f"{path} SHA", core.file_sha(core.ROOT / path) == expected_sha)

    issue_body = (core.ROOT / immutable["issueBodyPath"]).read_text()
    for fragment in protocol["authorityAssertions"]["issueBody"]:
        require(f"issue body fragment {fragment}", fragment in issue_body)
    task_capsule = json.loads((core.ROOT / "task-capsule.json").read_text())
    for fragment in protocol["authorityAssertions"]["taskCapsule"]:
        require(f"task capsule fragment {fragment}", any(
            fragment in value for value in task_capsule["activeConstraints"]
        ) or fragment in task_capsule["nextAction"])

    ward_protocol = json.loads((core.ROOT / protocol["lineage"]["baselineProtocol"]).read_text())
    trace_protocol = json.loads((core.ROOT / protocol["lineage"]["traceProtocol"]).read_text())
    for key, expected in protocol["lineage"]["baselineResearchImplementation"].items():
        require(f"baseline implementation {key}",
                ward_protocol["immutableInputs"][key] == expected)
    for key, expected in protocol["lineage"]["traceResearchImplementation"].items():
        require(f"trace implementation {key}",
                trace_protocol["immutableInputs"][key] == expected)

    baseline_path = core.CACHE / f"{protocol['lineage']['baselineOutputSha256']}.json"
    trace_path = core.CACHE / f"{protocol['lineage']['traceOutputSha256']}.json"
    require("baseline output SHA", core.file_sha(baseline_path) ==
            protocol["lineage"]["baselineOutputSha256"])
    require("trace output SHA", core.file_sha(trace_path) ==
            protocol["lineage"]["traceOutputSha256"])
    baseline_output = json.loads(baseline_path.read_text())
    trace_output = json.loads(trace_path.read_text())
    require("baseline plan SHA", baseline_output["planSha256"] ==
            protocol["lineage"]["baselinePlanSha256"])
    require("trace plan SHA", trace_output["planSha256"] ==
            protocol["lineage"]["tracePlanSha256"])
    cohort = protocol["cohort"]
    baseline_rows = frozen_rows(baseline_output, "policy", cohort["aspect"], cohort["vow"])
    observed_rows = frozen_rows(trace_output, "current", cohort["aspect"], cohort["vow"])
    expected_rows = cohort["policyCount"] * len(cohort["simulationSeeds"])
    require("baseline rectangle", len(baseline_rows) == expected_rows)
    require("trace rectangle", len(observed_rows) == expected_rows)
    exact_rows = sum(
        trace.canonical_without(row) == trace.canonical_without(baseline_rows[key])
        for key, row in observed_rows.items()
    )
    require("research trace row identity", exact_rows == expected_rows)

    provenance = json.loads((core.ROOT / protocol["evidence"]["provenanceAudit"]["path"]).read_text())
    for path, expected in protocol["evidence"]["provenanceAudit"]["assertions"].items():
        value: Any = provenance
        for key in path.split("."):
            value = value[key]
        require(f"provenance {path}", value == expected)
    pristine = immutable["pristineCurrentMainSha256"]
    require("historical pilot differs from pristine",
            ward_protocol["immutableInputs"]["pilotSha256"] != pristine["tools/balance_pilot.gd"])
    require("historical simulator differs from pristine",
            ward_protocol["immutableInputs"]["balanceSimSha256"] != pristine["tools/balance_sim.gd"])
    require("policy implementation exact", provenance["baselineProvenance"]["sourceComparison"]
            ["policyBlobSha256Equal"] is True)

    evidence_values: dict[str, dict[str, Any]] = {}
    for name, spec in protocol["evidence"].items():
        if name == "provenanceAudit":
            evidence_values[name] = provenance
            continue
        path = core.ROOT / spec["path"]
        require(f"{name} SHA", core.file_sha(path) == spec["sha256"])
        value = json.loads(path.read_text())
        for dotted_path, expected in spec["assertions"].items():
            observed: Any = value
            for key in dotted_path.split("."):
                observed = observed[key]
            require(f"{name} {dotted_path}", observed == expected)
        evidence_values[name] = value

    affected = affected_protocol_manifest(protocol["lineage"]["anchorSha256"])
    require("affected protocol count", len(affected) ==
            protocol["lineage"]["affectedProtocolCount"])
    require("affected protocol manifest", canonical_sha(affected) ==
            protocol["lineage"]["affectedProtocolManifestSha256"])
    upgrade_path = protocol["scopeClasses"]["failedCrossSubstrateIdentity"][0]
    affected_paths = [row["path"] for row in affected]
    require("upgrade protocol affected", upgrade_path in affected_paths)
    research_scoped = [path for path in affected_paths if path != upgrade_path]
    require("research-scoped count", len(research_scoped) ==
            protocol["scopeClasses"]["researchHarnessEvidenceCount"])

    ledger_before = identity.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
    gates = {
        "frozenResearchLineage": exact_rows == expected_rows,
        "pristineIdentitySeparated": (
            provenance["observed"]["rngMismatchRows"] > 0
            and provenance["observed"]["nonPackageObservationMismatchRows"] > 0
        ),
        "completedBoundariesPreserved": all(
            fragment in task_capsule["activeConstraints"]
            for fragment in protocol["authorityAssertions"]["exactTaskCapsuleConstraints"]
        ),
        "upgradeTelemetryClosed": evidence_values["upgradeIdentity"]["decision"] ==
        "reject-upgrade-telemetry-as-not-identity-safe",
        "measuredBottleneckPreserved": (
            evidence_values["exactComplementarity"]["decisiveFailure"]
            ["mechanismWitnesses"] == 3
            and evidence_values["exactComplementarity"]["clearPackages"]
            ["dusk-scoreline"]["mechanismWitnesses"] == 88
            and evidence_values["mirrorOathCapacity"]["counts"]
            ["candidatePotentialActivePolicies"] >= 16
            and evidence_values["mirrorOathIdentity"]["decisionClass"] == "futility"
        ),
        "observabilityAuthorityNotWidened": (
            evidence_values["observability"]["selectedSurface"] ==
            "upgrade-completion"
            and evidence_values["observability"]["additionalMethodDecisionValue"]
            ["optimiserOrMlRlAuthorised"] is False
            and protocol["nextBoundary"]["candidateFrozen"] is False
            and protocol["nextBoundary"]["simulatorRowsAuthorised"] == 0
        ),
    }
    elapsed = time.monotonic() - started
    if elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        boundary = 3
        outcome_class = "inconclusive"
        decision = "record-provenance-authority-audit-inconclusive-at-cap"
    elif all(gates.values()):
        boundary = 2
        outcome_class = "success"
        decision = "close-cross-substrate-cache-for-pristine-main-causal-use-require-fresh-null-harness"
    else:
        boundary = 2
        outcome_class = "futility"
        decision = "close-provenance-authority-input-set-on-futility"
    ledger_after = identity.ledger_identity()
    require("zero-row ledger identity", ledger_after == ledger_before)
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "decisionBoundary": boundary,
        "decision": decision,
        "outcomeClass": outcome_class,
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "gateResults": gates,
        "sourceLineage": {
            "sourceCommit": immutable["sourceCommit"],
            "baselineResearchImplementation": protocol["lineage"]
            ["baselineResearchImplementation"],
            "traceResearchImplementation": protocol["lineage"]
            ["traceResearchImplementation"],
            "pristineCurrentMain": pristine,
            "researchTraceExactRows": exact_rows,
            "researchTraceRows": expected_rows,
            "pristineVersusResearchRngMismatchRows": provenance["observed"]
            ["rngMismatchRows"],
            "pristineVersusResearchNonPackageMismatchRows": provenance["observed"]
            ["nonPackageObservationMismatchRows"],
        },
        "affectedProtocolManifest": affected,
        "scopeClasses": {
            "researchHarnessEvidence": research_scoped,
            "failedCrossSubstrateIdentity": [upgrade_path],
            "disposition": protocol["scopeClasses"]["disposition"],
        },
        "decisionValueEvidence": {
            "scorelineMechanismWitnesses": evidence_values["exactComplementarity"]
            ["clearPackages"]["dusk-scoreline"]["mechanismWitnesses"],
            "afterimageMechanismWitnesses": evidence_values["exactComplementarity"]
            ["decisiveFailure"]["mechanismWitnesses"],
            "afterimageRequiredWitnesses": evidence_values["exactComplementarity"]
            ["decisiveFailure"]["requiredMechanismWitnesses"],
            "measuredBottleneck": evidence_values["exactComplementarity"]
            ["mechanisticNarrowing"]["sequencingIsTheMeasuredBottleneck"],
            "mirrorOathPotentialActivePolicies": evidence_values["mirrorOathCapacity"]
            ["counts"]["candidatePotentialActivePolicies"],
            "mirrorOathExactInactivePolicies": evidence_values["mirrorOathCapacity"]
            ["counts"]["exactInactivePolicies"],
            "mirrorOathViablePolicies": evidence_values["mirrorOathCapacity"]
            ["counts"]["viablePotentialActivePolicies"],
            "upgradeCompletionPaths": evidence_values["observability"]["assessments"][0]
            ["derivedCounts"]["completionPaths"],
            "upgradeDirectPolicyControls": evidence_values["observability"]
            ["assessments"][0]["derivedCounts"]["directPolicyControls"],
        },
        "nextBoundary": protocol["nextBoundary"],
        "newSimulatorObservationRows": 0,
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "newLedgerRows": 0,
        "protectedSeedRows": ledger_after["protectedSeedRows"],
        "maximumModelContextTokens": 0,
        "wallTimeSeconds": elapsed,
        "authority": protocol["decisionRules"][f"{outcome_class}Authority"],
    }
    SUMMARY.parent.mkdir(parents=True, exist_ok=True)
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": "PASS",
        "decision": decision,
        "decisionBoundary": boundary,
        "affectedProtocols": len(affected),
        "researchTraceExactRows": exact_rows,
        "newSimulatorObservationRows": 0,
        "summarySha256": core.file_sha(SUMMARY),
    }))


if __name__ == "__main__":
    main()
