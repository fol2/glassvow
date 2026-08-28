#!/usr/bin/env python3
"""Current-main identity and isolation proof for upgrade-completion telemetry."""

from __future__ import annotations

import copy
import json
import subprocess
import tempfile
import time
from pathlib import Path
from typing import Any

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-upgrade-telemetry-identity-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-upgrade-telemetry-identity-v1.json"
SOURCE = core.ROOT / "current-main-source"
META = ("id", "stage", "arm", "policyRoot", "policyIndex", "trajectory")


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Upgrade telemetry identity mismatch: {label}")


def git_output(*args: str) -> str:
    return subprocess.run(
        ["git", *args], cwd=SOURCE, check=True, text=True, capture_output=True
    ).stdout


def canonical_without_observation(row: dict[str, Any]) -> str:
    value = copy.deepcopy(row)
    for key in META:
        value.pop(key, None)
    return core.canonical(value)


def run_probe(
    plan: dict[str, Any], godot: Path, timeout: int
) -> tuple[dict[str, Any], str, str]:
    plan_sha, plan_path = core.cache_json(plan)
    with tempfile.TemporaryDirectory(prefix="issue-421-upgrade-identity-") as tmp:
        output_path = Path(tmp) / "output.json"
        result = subprocess.run(
            [
                str(godot), "--headless",
                "-s", "res://tools/research_421_upgrade_probe.gd", "--",
                f"--plan={plan_path}", f"--out={output_path}",
            ],
            cwd=SOURCE, text=True, capture_output=True, timeout=timeout,
        )
        if result.returncode or not output_path.is_file():
            raise RuntimeError(
                f"upgrade probe failed ({result.returncode})\n"
                f"{result.stdout[-2000:]}\n{result.stderr[-4000:]}"
            )
        output = json.loads(output_path.read_text())
    output_sha, _ = core.cache_json(output)
    return output, plan_sha, output_sha


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite the upgrade telemetry summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    started = time.monotonic()
    immutable = protocol["immutableInputs"]
    require("runner SHA", core.file_sha(Path(__file__)) == immutable["runnerSha256"])
    for helper_path, expected_sha in immutable["helperSha256"].items():
        require(helper_path, core.file_sha(core.ROOT / helper_path) == expected_sha)
    require("source commit", git_output("rev-parse", "HEAD").strip() ==
            immutable["sourceCommit"])
    require("source status", git_output("status", "--porcelain").splitlines() ==
            immutable["sourceStatus"])
    for source_path, expected_sha in immutable["sourceSha256"].items():
        require(source_path, core.file_sha(SOURCE / source_path) == expected_sha)
    for source_path, fragments in protocol["sourceAssertions"].items():
        source_text = (SOURCE / source_path).read_text()
        for fragment in fragments:
            require(f"{source_path} source {fragment}", fragment in source_text)
    for source_path, expected_sha in immutable["currentMainBlobSha256"].items():
        blob = subprocess.run(
            ["git", "show", f"HEAD:{source_path}"], cwd=SOURCE,
            check=True, capture_output=True,
        ).stdout
        require(f"current-main {source_path}", core.sha(blob) == expected_sha)
    godot = Path(immutable["godotPath"])
    require("Godot binary SHA", core.file_sha(godot) == immutable["godotSha256"])
    version = subprocess.run(
        [str(godot), "--version"], check=True, text=True, capture_output=True
    ).stdout.strip()
    require("Godot version", version == immutable["godotVersion"])
    for name, spec in protocol["priorEvidence"].items():
        path = core.ROOT / spec["path"]
        require(f"{name} SHA", core.file_sha(path) == spec["sha256"])
        require(f"{name} decision", json.loads(path.read_text())["decision"] ==
                spec["decision"])

    ledger_before = identity.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
    baseline_path = core.CACHE / f"{protocol['baseline']['outputSha256']}.json"
    content_path = core.CACHE / f"{protocol['baseline']['contentSha256']}.json"
    require("baseline output SHA", core.file_sha(baseline_path) ==
            protocol["baseline"]["outputSha256"])
    require("content SHA", core.file_sha(content_path) ==
            protocol["baseline"]["contentSha256"])
    baseline_output = json.loads(baseline_path.read_text())
    require("baseline plan SHA", baseline_output["planSha256"] ==
            protocol["baseline"]["planSha256"])
    cohort = protocol["cohort"]
    baseline_rows = {
        (int(row["policyIndex"]), int(row["seed"])): row
        for row in baseline_output["rows"]
        if row.get("arm") == "policy" and row.get("aspect") == cohort["aspect"]
        and int(row.get("vow", -1)) == cohort["vow"]
    }
    expected_identities = cohort["policyCount"] * len(cohort["simulationSeeds"])
    require("baseline rectangle", len(baseline_rows) == expected_identities)

    audit_protocol = json.loads(
        (core.ROOT / protocol["sourceCorrection"]["protocolPath"]).read_text()
    )
    require("correction targets exact wording",
            audit_protocol["catalogueBoundary"]["excludedFullyObserved"]
            ["terminalDeckAndUpFlags"] == "row.deck")
    require("row.deck is integer size",
            all(isinstance(row.get("deck"), int) for row in baseline_rows.values()))
    require("no terminal upgrade detail",
            all("deckUp" not in row and "upgrades" not in row
                for row in baseline_rows.values()))
    require("source deck-size projection",
            '"deck": run.player.deck.size()' in
            (SOURCE / "tools/balance_sim.gd").read_text())

    rows: list[dict[str, Any]] = []
    for policy_index in range(cohort["policyCount"]):
        for seed in cohort["simulationSeeds"]:
            for arm in protocol["armOrder"]:
                rows.append({
                    "id": f"upgrade-identity-{arm}-p{policy_index}-s{seed}",
                    "arm": arm,
                    "policyRoot": cohort["policyRoot"],
                    "policyIndex": policy_index,
                    "seed": seed,
                    "vow": cohort["vow"],
                })
    require("new-row ceiling",
            len(rows) == protocol["budget"]["maximumNewSimulatorObservationRows"])
    plan = {
        "schemaVersion": 1,
        "protocolSha256": protocol_sha,
        "content": str(content_path),
        "rows": rows,
    }
    output, plan_sha, output_sha = run_probe(
        plan, godot, protocol["budget"]["maximumWallTimeSeconds"]
    )
    require("probe output runner SHA", output["runnerSha256"] ==
            immutable["sourceSha256"]["tools/research_421_upgrade_probe.gd"])
    require("probe output content SHA",
            output["contentIdentity"]["contentFileSha256"] ==
            protocol["baseline"]["contentSha256"])
    observed = {
        (str(row["arm"]), int(row["policyIndex"]), int(row["seed"])): row
        for row in output["rows"]
    }
    require("probe rectangle", len(observed) == len(rows))

    null_mismatches: list[str] = []
    enabled_mismatches: list[str] = []
    paired_mismatches: list[str] = []
    null_trace_rows: list[str] = []
    schema_faults: list[str] = []
    source_counts = {"rest": 0, "event": 0}
    empty_enabled_rows = 0
    telemetry_events = 0
    content = json.loads(content_path.read_text())
    cards = content["cards"]
    for key, baseline in baseline_rows.items():
        policy_index, seed = key
        null_row = observed[("explicit-null", policy_index, seed)]
        enabled_row = observed[("enabled", policy_index, seed)]
        baseline_clean = canonical_without_observation(baseline)
        null_clean = canonical_without_observation(null_row)
        enabled_clean = canonical_without_observation(enabled_row)
        label = f"p{policy_index}-s{seed}"
        if null_clean != baseline_clean:
            null_mismatches.append(label)
        if enabled_clean != baseline_clean:
            enabled_mismatches.append(label)
        if null_clean != enabled_clean:
            paired_mismatches.append(label)
        if "trajectory" in null_row:
            null_trace_rows.append(label)
        trajectory = enabled_row.get("trajectory")
        if not isinstance(trajectory, dict) or set(trajectory) != {"upgrades"} \
                or not isinstance(trajectory.get("upgrades"), list):
            schema_faults.append(f"{label}:trajectory")
            continue
        events = trajectory["upgrades"]
        if not events:
            empty_enabled_rows += 1
        seen_uids: set[int] = set()
        for event_index, event in enumerate(events):
            telemetry_events += 1
            event_label = f"{label}-e{event_index}"
            if not isinstance(event, dict) or set(event) != {"source", "act", "uid", "id"}:
                schema_faults.append(f"{event_label}:keys")
                continue
            source = event["source"]
            act = event["act"]
            uid = event["uid"]
            card_id = event["id"]
            if source not in source_counts:
                schema_faults.append(f"{event_label}:source")
            else:
                source_counts[source] += 1
            if not isinstance(act, int) or not 0 <= act <= 2:
                schema_faults.append(f"{event_label}:act")
            if not isinstance(uid, int) or uid < 1 or uid in seen_uids:
                schema_faults.append(f"{event_label}:uid")
            else:
                seen_uids.add(uid)
            if not isinstance(card_id, str) or card_id not in cards \
                    or "up" not in cards[card_id]:
                schema_faults.append(f"{event_label}:card")

    baseline_fault_rows = sum(
        row.get("outcome") in ("stall", "error") or bool(row.get("error"))
        for row in baseline_rows.values()
    )
    identity_safe = not (
        null_mismatches or enabled_mismatches or paired_mismatches
        or null_trace_rows or schema_faults
    )
    reliable = baseline_fault_rows <= protocol["gates"]["maximumBaselineFaultRows"]
    coverage = (
        source_counts["rest"] >= protocol["gates"]["minimumEventsPerSource"]
        and source_counts["event"] >= protocol["gates"]["minimumEventsPerSource"]
        and empty_enabled_rows >= protocol["gates"]["minimumEmptyEnabledRows"]
    )
    elapsed = time.monotonic() - started
    if elapsed > protocol["budget"]["maximumWallTimeSeconds"]:
        boundary = 3
        decision = "record-upgrade-telemetry-identity-inconclusive-at-cap"
    elif not identity_safe or not reliable:
        boundary = 2
        decision = "reject-upgrade-telemetry-as-not-identity-safe"
    elif not coverage:
        boundary = 3
        decision = "record-upgrade-telemetry-coverage-inconclusive-at-cap"
    else:
        boundary = 1
        decision = "upgrade-telemetry-identity-safe"
    ledger_after = identity.ledger_identity()
    require("zero-row ledger identity", ledger_after == ledger_before)
    authority_key = (
        "successAuthority" if boundary == 1 else
        ("futilityAuthority" if boundary == 2 else "inconclusiveAuthority")
    )
    summary = {
        "schemaVersion": 1,
        "issue": 421,
        "decisionBoundary": boundary,
        "decision": decision,
        "protocolSha256": protocol_sha,
        "runnerSha256": core.file_sha(Path(__file__)),
        "planSha256": plan_sha,
        "outputSha256": output_sha,
        "sourceCorrection": {
            "incorrectClaim": "row.deck retains terminal upgrade flags",
            "observedContract": "row.deck is an integer deck size; no terminal upgrade detail exists",
            "impact": "The correction strengthens the selected observability gap and changes no eligibility gate, selected surface or method authority.",
            "originalAuditPreserved": True,
        },
        "identity": {
            "rowsPerArm": expected_identities,
            "explicitNullVersusBaselineMismatchRows": len(null_mismatches),
            "enabledWithoutObservationVersusBaselineMismatchRows": len(enabled_mismatches),
            "pairedMismatchRows": len(paired_mismatches),
            "explicitNullUnexpectedTraceRows": len(null_trace_rows),
            "pathRngPolicyStateResultExact": identity_safe,
            "mismatchExamples": {
                "explicitNull": null_mismatches[:8],
                "enabled": enabled_mismatches[:8],
                "paired": paired_mismatches[:8],
                "nullTrace": null_trace_rows[:8],
            },
        },
        "mediatorIsolation": {
            "telemetryEvents": telemetry_events,
            "sourceCounts": source_counts,
            "emptyEnabledRows": empty_enabled_rows,
            "schemaFaults": len(schema_faults),
            "schemaFaultExamples": schema_faults[:8],
            "eventSchema": ["source", "act", "uid", "id"],
            "onlySuccessfulExistingUpgradeHook": True,
        },
        "reliability": {
            "baselineFaultRows": baseline_fault_rows,
            "maximumBaselineFaultRows": protocol["gates"]["maximumBaselineFaultRows"],
            "pass": reliable,
        },
        "newSimulatorObservationRows": len(rows),
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_after,
        "newLedgerRows": 0,
        "protectedSeedRows": ledger_after["protectedSeedRows"],
        "maximumModelContextTokens": 0,
        "wallTimeSeconds": elapsed,
        "authority": protocol["decisionRules"][authority_key],
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": "PASS",
        "decision": decision,
        "decisionBoundary": boundary,
        "identitySafe": identity_safe,
        "coverage": coverage,
        "telemetryEvents": telemetry_events,
        "summarySha256": core.file_sha(SUMMARY),
        "newSimulatorObservationRows": len(rows),
        "newLedgerRows": 0,
    }))


if __name__ == "__main__":
    main()
