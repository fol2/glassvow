#!/usr/bin/env python3
"""Read-only independent audit of the #421 ward whole-run first look."""

from __future__ import annotations

import json
import sqlite3
from pathlib import Path
from typing import Any, Callable

import post_v38_knob_identity as identity
import research as core


PROTOCOL = core.ROOT / "protocols/post-v38-ward-whole-run-discovery-v1.json"
SUMMARY = core.ROOT / "summaries/post-v38-ward-whole-run-discovery-v1.json"
AUDIT = core.ROOT / "summaries/post-v38-ward-whole-run-discovery-v1-audit.json"


def active_indices(rows: list[dict[str, Any]], predicate: Callable[[dict[str, Any]], bool]) \
        -> set[int]:
    return {
        int(row["policyIndex"]) for row in rows
        if row.get("arm") == "policy" and row.get("aspect") == "duskblade"
        and predicate(row)
    }


def scoreline_active(row: dict[str, Any]) -> bool:
    deck = set(map(str, row.get("deckIds", [])))
    events = row.get("packageEvents") or {}
    return {"chisel", "executioner"}.issubset(deck) \
        and int(events.get("scorelineApplied", 0)) > 0 \
        and int(events.get("scorelineConsumed", 0)) > 0


def pair_reachable(row: dict[str, Any], producer: str, consumer: str) -> bool:
    return {producer, consumer}.issubset(set(map(str, row.get("deckIds", []))))


def ward_active(row: dict[str, Any], producer: str) -> bool:
    events = row.get("packageEvents") or {}
    return pair_reachable(row, producer, "fortify") \
        and int(events.get(f"{producer}Played", 0)) > 0 \
        and int(events.get("fortifyPlayed", 0)) > 0 \
        and int(events.get("wardDoubledByFortify", 0)) > 0


def output_packets(protocol_sha: str) -> dict[str, dict[str, Any]]:
    with sqlite3.connect(f"file:{core.LEDGER}?mode=ro", uri=True) as db:
        records = db.execute(
            "SELECT payload_json FROM records WHERE kind = 'probe-run' "
            "AND json_extract(payload_json, '$.protocolSha256') = ? ORDER BY seq",
            (protocol_sha,),
        ).fetchall()
    if len(records) != 2:
        raise RuntimeError("ward audit did not find exactly two probe outputs")
    packets: dict[str, dict[str, Any]] = {}
    for (payload_json,) in records:
        record = json.loads(payload_json)
        path = core.CACHE / f"{record['outputSha256']}.json"
        if not path.is_file() or core.file_sha(path) != record["outputSha256"]:
            raise RuntimeError("ward output cache is missing or corrupt")
        output = json.loads(path.read_text())
        arm = str(output["rows"][0]["id"]).split("-")[3]
        if arm not in ("baseline", "candidate") or arm in packets:
            raise RuntimeError("ward output arm identity is invalid")
        if len(output["rows"]) != record["rowCount"]:
            raise RuntimeError("ward output row count drifted")
        packets[arm] = {"record": record, "output": output}
    return packets


def policy_snapshot_audit(baseline: list[dict[str, Any]],
                          candidate: list[dict[str, Any]]) -> dict[str, Any]:
    snapshots: dict[int, set[str]] = {}
    for rows in (baseline, candidate):
        for row in rows:
            if row.get("arm") != "policy":
                continue
            index = int(row["policyIndex"])
            snapshots.setdefault(index, set()).add(
                core.sha(core.canonical(row["policy"]).encode())
            )
    exact = len(snapshots) == 64 and all(len(values) == 1 for values in snapshots.values())
    return {
        "policyIdentities": len(snapshots),
        "uniqueSnapshots": len({next(iter(values)) for values in snapshots.values()}),
        "exactAcrossArmsAspectsAndSeeds": exact,
    }


def support(rows: list[dict[str, Any]]) -> dict[str, Any]:
    scoreline = active_indices(rows, scoreline_active)
    brace = active_indices(rows, lambda row: ward_active(row, "brace"))
    mirror = active_indices(rows, lambda row: ward_active(row, "mirrorEdge"))
    ward = brace | mirror
    scoreline_reachable = active_indices(
        rows, lambda row: pair_reachable(row, "chisel", "executioner")
    )
    scoreline_consumed = active_indices(
        rows, lambda row: pair_reachable(row, "chisel", "executioner")
        and int((row.get("packageEvents") or {}).get("scorelineConsumed", 0)) > 0
    )
    brace_reachable = active_indices(
        rows, lambda row: pair_reachable(row, "brace", "fortify")
    )
    mirror_reachable = active_indices(
        rows, lambda row: pair_reachable(row, "mirrorEdge", "fortify")
    )
    return {
        "scoreline": {
            "active": len(scoreline), "inactive": 64 - len(scoreline),
            "reachable": len(scoreline_reachable),
            "consumerReached": len(scoreline_consumed),
        },
        "ward": {
            "active": len(ward), "inactive": 64 - len(ward),
            "reachable": len(brace_reachable | mirror_reachable),
            "consumerReached": len(ward),
        },
        "edges": {
            "brace": {"active": len(brace), "reachable": len(brace_reachable)},
            "mirrorEdge": {"active": len(mirror), "reachable": len(mirror_reachable)},
        },
        "separation": {
            "scorelineOnly": len(scoreline - ward),
            "wardOnly": len(ward - scoreline),
            "crossActive": len(scoreline & ward),
        },
        "sets": {"scoreline": scoreline, "ward": ward},
    }


def random_build(baseline: list[dict[str, Any]],
                 candidate: list[dict[str, Any]]) -> dict[str, Any]:
    key = lambda row: (str(row["aspect"]), int(row["vow"]), int(row["seed"]))
    base = {key(row): row for row in baseline if row.get("arm") == "random"}
    cand = {key(row): row for row in candidate if row.get("arm") == "random"}
    if set(base) != set(cand) or len(base) != 256:
        raise RuntimeError("RandomBuild CRN rectangle is not exact")
    result: dict[str, Any] = {}
    for aspect in ("duskblade", "ashwarden"):
        for vow in (0, 5):
            keys = [found for found in sorted(cand) if found[:2] == (aspect, vow)]
            candidate_wins = sum(cand[found]["outcome"] == "win" for found in keys)
            baseline_wins = sum(base[found]["outcome"] == "win" for found in keys)
            result[f"{aspect}:v{vow}"] = {
                "candidateWins": candidate_wins,
                "baselineWins": baseline_wins,
                "pairs": len(keys),
                "candidateWinRate": candidate_wins / len(keys),
                "candidateMinusBaseline": (candidate_wins - baseline_wins) / len(keys),
            }
    return result


def faults(rows: list[dict[str, Any]]) -> int:
    return sum(
        str(row.get("outcome", "")) in ("stall", "error")
        or bool(str(row.get("error", ""))) for row in rows
    )


def main() -> None:
    if AUDIT.exists():
        raise RuntimeError("refusing to overwrite the ward audit")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    summary = json.loads(SUMMARY.read_text())
    if summary.get("protocolSha256") != protocol_sha \
            or summary.get("decisionBoundary") != 2:
        raise RuntimeError("ward summary is not the frozen boundary-2 result")
    analysis_path = core.CACHE / f"{summary['analysisSha256']}.json"
    if not analysis_path.is_file() or core.file_sha(analysis_path) != summary["analysisSha256"]:
        raise RuntimeError("ward analysis cache is missing or corrupt")
    published = json.loads(analysis_path.read_text())
    packets = output_packets(protocol_sha)
    baseline = packets["baseline"]["output"]["rows"]
    candidate = packets["candidate"]["output"]["rows"]
    if len(baseline) != 768 or len(candidate) != 768:
        raise RuntimeError("ward audit row rectangle is incomplete")
    if packets["baseline"]["output"]["contentIdentity"]["contentFileSha256"] \
            != protocol["baseline"]["contentSha256"]:
        raise RuntimeError("baseline output content identity drifted")
    if packets["candidate"]["output"]["contentIdentity"]["contentFileSha256"] \
            != protocol["candidate"]["contentSha256"]:
        raise RuntimeError("candidate output content identity drifted")

    policy_identity = policy_snapshot_audit(baseline, candidate)
    baseline_support = support(baseline)
    candidate_support = support(candidate)
    random = random_build(baseline, candidate)
    if not policy_identity["exactAcrossArmsAspectsAndSeeds"]:
        raise RuntimeError("ward policy identity audit failed")
    expected = {
        "scoreline": {"active": 0, "inactive": 64, "reachable": 55,
                      "consumerReached": 0},
        "ward": {"active": 14, "inactive": 50, "reachable": 20,
                 "consumerReached": 14},
        "edges": {
            "brace": {"active": 6, "reachable": 11},
            "mirrorEdge": {"active": 13, "reachable": 19},
        },
        "separation": {"scorelineOnly": 0, "wardOnly": 14, "crossActive": 0},
    }
    comparable = {key: candidate_support[key] for key in expected}
    if comparable != expected:
        raise RuntimeError("independent ward support counts differ from the frozen analysis")
    dusk_v0 = random["duskblade:v0"]
    ash_v0 = random["ashwarden:v0"]
    hard_failures = {
        "scorelineSensitivity": candidate_support["scoreline"]["active"] < 16,
        "scorelineConsumerReach": candidate_support["scoreline"]["consumerReached"] < 8,
        "wardSensitivity": candidate_support["ward"]["active"] < 16,
        "braceEdge": candidate_support["edges"]["brace"]["active"] < 8,
        "functionalSeparation": candidate_support["separation"]["scorelineOnly"] < 4,
        "duskRandomBuildCeiling": dusk_v0["candidateWinRate"] >= 0.5,
        "duskRandomBuildMovement": dusk_v0["candidateMinusBaseline"] > 0.1,
        "ashRandomBuildMovement": ash_v0["candidateMinusBaseline"] > 0.1,
    }
    if not all(hard_failures.values()) or faults(candidate):
        raise RuntimeError("ward boundary-2 hard-failure witnesses did not reproduce")
    published_packages = published["strategyPackageActivation"]
    if published_packages["packages"]["dusk-scoreline"]["active"] != 0 \
            or published_packages["packages"]["dusk-ward-mirror-edge"]["active"] != 14:
        raise RuntimeError("published ward analysis does not match the independent audit")

    ledger_before = identity.ledger_identity()
    result = {
        "schemaVersion": 1,
        "issue": 421,
        "status": "PASS",
        "protocolSha256": protocol_sha,
        "analysisSha256": summary["analysisSha256"],
        "decisionBoundary": 2,
        "decision": "reject-exact-ward-candidate-close-tested-direction",
        "rows": {"baseline": len(baseline), "candidate": len(candidate), "total": 1536},
        "outputs": {
            arm: {
                "planSha256": packet["record"]["planSha256"],
                "outputSha256": packet["record"]["outputSha256"],
            } for arm, packet in packets.items()
        },
        "policyIdentity": policy_identity,
        "baselineSupport": {key: value for key, value in baseline_support.items()
                            if key != "sets"},
        "candidateSupport": {key: value for key, value in candidate_support.items()
                             if key != "sets"},
        "randomBuild": random,
        "candidateFaults": faults(candidate),
        "hardFailureWitnesses": hard_failures,
        "newSimulatorObservationRows": 0,
        "newLedgerRows": 0,
        "protectedSeedRows": 0,
        "ledgerBefore": ledger_before,
        "ledgerAfter": ledger_before,
        "authority": "The frozen boundary-2 rejection is independently reproduced. Do not retune or rerun this ward packet.",
    }
    AUDIT.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": result["status"],
        "decision": result["decision"],
        "auditSha256": core.file_sha(AUDIT),
        "newSimulatorObservationRows": 0,
    }))


if __name__ == "__main__":
    main()
