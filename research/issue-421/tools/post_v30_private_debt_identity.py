#!/usr/bin/env python3
"""Exact-runtime identity preflight for the private combat-debt prototype."""

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


PROTOCOL = core.ROOT / "protocols/post-v30-private-debt-identity-v1.json"
SUMMARY = core.ROOT / "summaries/post-v30-private-debt-identity-v1.json"
SOURCE = core.ROOT / "private-debt-baseline-source"
PROTOTYPE = core.ROOT / "private-debt-identity-source"
GODOT = Path("/Applications/Godot.app/Contents/MacOS/Godot")
DIRECT_PROBE = PROTOTYPE / "tools/research_421_private_debt_probe.gd"
META = ("id", "stage", "arm")


def require(label: str, condition: bool) -> None:
    if not condition:
        raise RuntimeError(f"Private-debt identity mismatch: {label}")


def card_definitions(enabled: bool) -> dict[str, dict[str, Any]]:
    producer_effects = [{"kind": "dmg", "n": 8}]
    producer_up = [{"kind": "dmg", "n": 12}]
    consumer_effects = [{"kind": "block", "n": 6}]
    consumer_up = [{"kind": "block", "n": 9}]
    if enabled:
        add = {"kind": "addCard", "id": "glassDebt", "where": "hand", "aspect": 0}
        remove = {
            "kind": "removeCardFromHand", "id": "glassDebt",
            "maximum": 1, "aspect": 0,
        }
        producer_effects.append(add)
        producer_up.append(copy.deepcopy(add))
        consumer_effects.append(remove)
        consumer_up.append(copy.deepcopy(remove))
    return {
        "debtEdge": {
            "type": "attack", "rarity": "common", "cost": 1,
            "target": "enemy", "vfx": "pierce", "effects": producer_effects,
            "up": {"effects": producer_up, "text": "Deal @12@ damage. Add a Glass Debt."},
            "name": "Debt Edge", "text": "Deal @8@ damage. Add a Glass Debt.",
        },
        "debtWard": {
            "type": "skill", "rarity": "uncommon", "cost": 1,
            "target": "self", "vfx": "ward", "effects": consumer_effects,
            "up": {"effects": consumer_up,
                   "text": "Gain #9# Ward. Clear a Glass Debt from your hand."},
            "name": "Debt Ward",
            "text": "Gain #6# Ward. Clear a Glass Debt from your hand.",
        },
        "glassDebt": {
            "type": "curse", "rarity": "special", "cost": None,
            "target": "none", "vfx": "void", "unplayable": True,
            "endTurnLoseHp": 1, "effects": [], "name": "Glass Debt",
            "text": "Unplayable. At the end of your turn, lose 1 HP. Refuses the fire.",
        },
    }


def build_content(enabled: bool) -> bytes:
    content = json.loads((SOURCE / "content/full-content.json").read_text())
    cards = content["cards"]
    require("candidate IDs absent", not set(card_definitions(enabled)) & set(cards))
    cards.update(card_definitions(enabled))
    return (json.dumps(content, ensure_ascii=False, separators=(",", ":")) + "\n").encode()


def source_identity() -> dict[str, Any]:
    return {
        "sourceCommit": subprocess.run(
            ["git", "rev-parse", "HEAD"], cwd=PROTOTYPE, check=True,
            text=True, capture_output=True,
        ).stdout.strip(),
        "baselineSourceCommit": subprocess.run(
            ["git", "rev-parse", "HEAD"], cwd=SOURCE, check=True,
            text=True, capture_output=True,
        ).stdout.strip(),
        "godotVersion": subprocess.run(
            [str(GODOT), "--version"], check=True, text=True, capture_output=True,
        ).stdout.strip(),
        "godotBinarySha256": core.file_sha(GODOT),
        "pristineContentSha256": core.file_sha(SOURCE / "content/full-content.json"),
        "prototypeCombatRulesSha256": core.file_sha(PROTOTYPE / "domain/rules/combat.gd"),
        "balanceSimSha256": core.file_sha(SOURCE / "tools/balance_sim.gd"),
        "pilotSha256": core.file_sha(SOURCE / "tools/balance_pilot.gd"),
        "policySha256": core.file_sha(SOURCE / "tools/balance_policy.gd"),
        "directProbeSha256": core.file_sha(
            PROTOTYPE / "tools/research_421_private_debt_probe.gd"),
        "directProbeUidSha256": core.file_sha(
            PROTOTYPE / "tools/research_421_private_debt_probe.gd.uid"),
        "designProtocolSha256": core.file_sha(
            core.ROOT / "protocols/post-v30-minimum-new-mediator-design-audit-v1.json"),
        "designSummarySha256": core.file_sha(
            core.ROOT / "summaries/post-v30-minimum-new-mediator-design-audit-v1.json"),
        "taskCapsuleSha256": core.file_sha(core.ROOT / "task-capsule.json"),
        "runnerSha256": core.file_sha(Path(__file__)),
    }


def remaining(deadline: float) -> int:
    seconds = int(deadline - time.monotonic())
    if seconds < 1:
        raise TimeoutError("private-debt identity exceeded its wall-time ceiling")
    return seconds


def run_probe(
    source: Path, script: Path, plan: dict[str, Any], deadline: float,
) -> tuple[dict[str, Any], str, str]:
    plan_sha, plan_path = core.cache_json(plan)
    core.WORK.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=core.WORK, prefix="private-debt-identity-") as tmp:
        output_path = Path(tmp) / "output.json"
        result = subprocess.run(
            [str(GODOT), "--headless", "-s", str(script), "--",
             f"--plan={plan_path}", f"--out={output_path}"],
            cwd=source, text=True, capture_output=True, timeout=remaining(deadline),
        )
        if result.returncode or not output_path.is_file():
            raise OSError(
                f"probe failed ({result.returncode})\n"
                f"{result.stdout[-2000:]}\n{result.stderr[-4000:]}")
        output = json.loads(output_path.read_text())
    require("plan identity", output.get("planSha256") == plan_sha)
    output_sha, _ = core.cache_json(output)
    return output, plan_sha, output_sha


def direct_specs() -> list[dict[str, Any]]:
    return [
        {"id": "producer-dusk-base", "kind": "producer", "aspect": "duskblade",
         "upgraded": False, "fillerCount": 0, "seed": 422120},
        {"id": "producer-dusk-up-full", "kind": "producer", "aspect": "duskblade",
         "upgraded": True, "fillerCount": 9, "seed": 422121},
        {"id": "producer-ash-base", "kind": "producer", "aspect": "ashwarden",
         "upgraded": False, "fillerCount": 0, "seed": 422122},
        {"id": "consumer-dusk-two", "kind": "consumer", "aspect": "duskblade",
         "upgraded": False, "debtCount": 2, "seed": 422123},
        {"id": "consumer-dusk-up-one", "kind": "consumer", "aspect": "duskblade",
         "upgraded": True, "debtCount": 1, "seed": 422124},
        {"id": "consumer-dusk-zero", "kind": "consumer", "aspect": "duskblade",
         "upgraded": False, "debtCount": 0, "seed": 422125},
        {"id": "consumer-ash-two", "kind": "consumer", "aspect": "ashwarden",
         "upgraded": False, "debtCount": 2, "seed": 422126},
        {"id": "penalty-dusk", "kind": "penalty", "aspect": "duskblade",
         "seed": 422127},
    ]


def direct_plan(
    protocol_sha: str, null_path: Path, enabled_path: Path,
) -> dict[str, Any]:
    rows = []
    for spec in direct_specs():
        for arm, path in (("null", null_path), ("enabled", enabled_path)):
            rows.append({**spec, "id": f"{spec['id']}-{arm}", "baseId": spec["id"],
                         "arm": arm, "content": str(path)})
    return {"schemaVersion": 1, "protocolSha256": protocol_sha,
            "mode": "direct", "rows": rows}


def stripped(row: dict[str, Any], *extra: str) -> dict[str, Any]:
    value = copy.deepcopy(row)
    for key in ("id", "arm", *extra):
        value.pop(key, None)
    return value


def event_rows(row: dict[str, Any], event_type: str) -> list[dict[str, Any]]:
    return [event for event in row["events"] if event.get("t") == event_type]


def card_rows(row: dict[str, Any], zone: str, card_id: str) -> list[dict[str, Any]]:
    return [card for card in row[zone] if card.get("id") == card_id]


def analyse_direct(rows: list[dict[str, Any]]) -> dict[str, Any]:
    indexed = {(str(row["id"]).removesuffix(f"-{row['arm']}"), str(row["arm"])): row
               for row in rows}
    require("direct row count", len(rows) == len(indexed) == 16)
    for spec in direct_specs():
        base = spec["id"]
        null, enabled = indexed[(base, "null")], indexed[(base, "enabled")]
        require(f"{base} paired RNG", null["rngBefore"] == enabled["rngBefore"]
                and null["rngAfter"] == enabled["rngAfter"])
        if spec["kind"] != "penalty":
            require(f"{base} no action RNG", null["rngBefore"] == null["rngAfter"]
                    and enabled["rngBefore"] == enabled["rngAfter"])
        if spec["kind"] == "producer":
            damage = 12 if spec["upgraded"] else 8
            require(f"{base} exact damage", all(
                row["enemyHpBefore"] - row["enemyHpAfter"] == damage
                for row in (null, enabled)))
            expected_chips = 1 if spec["aspect"] == "duskblade" else 0
            require(f"{base} base Facet identity", null["enemyChips"] ==
                    enabled["enemyChips"] == expected_chips)
            require(f"{base} carrier disposition", all(
                len(card_rows(row, "discard", "debtEdge")) == 1
                and not row["exhaust"] and row["embers"] == 3
                for row in (null, enabled)))
            require(f"{base} null mediator absent",
                    not card_rows(null, "hand", "glassDebt")
                    and not event_rows(null, "addCard"))
            if spec["aspect"] == "duskblade":
                debts = card_rows(enabled, "hand", "glassDebt")
                events = event_rows(enabled, "addCard")
                require(f"{base} exact generated debt", len(debts) == len(events) == 1
                        and events[0] == {"t": "addCard", "id": "glassDebt",
                                          "uid": debts[0]["uid"], "where": "hand"})
                require(f"{base} full-hand placement",
                        len(enabled["hand"]) == int(spec["fillerCount"]) + 1)
                normal = stripped(enabled)
                normal["hand"] = [card for card in normal["hand"]
                                  if card["id"] != "glassDebt"]
                normal["events"] = [event for event in normal["events"]
                                    if event.get("t") != "addCard"]
                require(f"{base} producer isolation", normal == stripped(null))
            else:
                require(f"{base} Ash inert", stripped(null) == stripped(enabled))
        elif spec["kind"] == "consumer":
            ward = 9 if spec["upgraded"] else 6
            require(f"{base} exact Ward", null["playerBlock"] ==
                    enabled["playerBlock"] == ward)
            require(f"{base} no Kindle alias", all(
                not row["exhaust"] and row["embers"] == 3
                and len(card_rows(row, "discard", "debtWard")) == 1
                for row in (null, enabled)))
            debt_count = int(spec["debtCount"])
            require(f"{base} null debts", len(card_rows(null, "hand", "glassDebt"))
                    == debt_count and not event_rows(null, "removeCardFromHand"))
            removes = event_rows(enabled, "removeCardFromHand")
            should_remove = spec["aspect"] == "duskblade" and debt_count > 0
            require(f"{base} removal count", len(removes) == int(should_remove))
            require(f"{base} enabled debts",
                    len(card_rows(enabled, "hand", "glassDebt"))
                    == debt_count - int(should_remove))
            if should_remove:
                removed_uids = {card["uid"] for card in card_rows(null, "hand", "glassDebt")} - {
                    card["uid"] for card in card_rows(enabled, "hand", "glassDebt")}
                require(f"{base} exact removal identity", len(removed_uids) == 1
                        and removes[0]["id"] == "glassDebt"
                        and removes[0]["uid"] in removed_uids)
                require(f"{base} consumer isolation",
                        stripped(null, "hand", "events") ==
                        stripped(enabled, "hand", "events"))
            else:
                require(f"{base} inert", stripped(null) == stripped(enabled))
        else:
            require("penalty HP cost", null["playerHpBefore"] ==
                    enabled["playerHpBefore"] == 20
                    and null["playerHpAfter"] == enabled["playerHpAfter"] == 19)
            require("penalty Kindle exclusion",
                    null["canKindle"] is False and enabled["canKindle"] is False)
            require("penalty exact identity", stripped(null) == stripped(enabled))
    return {
        "status": "PASS", "rows": len(rows), "controls": len(direct_specs()),
        "producerPlacementExact": True, "consumerRemovalExact": True,
        "aspectIsolationExact": True, "rngIdentityExact": True,
        "KindleAndEmberIsolationExact": True, "naturalPenaltyExact": True,
    }


def whole_plan(
    protocol: dict[str, Any], protocol_sha: str, arm: str, content: Path,
) -> dict[str, Any]:
    cohort = protocol["identityCohort"]
    rows = [
        {
            "id": f"private-debt-{arm}-p{policy_index}-s{seed}",
            "stage": "post-v30-private-debt-identity", "arm": arm,
            "mode": "whole-run", "aspect": cohort["aspect"], "vow": cohort["vow"],
            "seed": seed, "policyRoot": cohort["policyRoot"],
            "policyIndex": policy_index, "captureTrace": True,
        }
        for policy_index in cohort["policyIndices"]
        for seed in cohort["simulationSeeds"]
    ]
    require("whole arm size", len(rows) == cohort["identities"])
    return {"schemaVersion": 1, "protocolSha256": protocol_sha,
            "mode": "whole-runs", "content": str(content), "rows": rows}


def normalised_whole(row: dict[str, Any]) -> str:
    value = copy.deepcopy(row)
    for key in META:
        value.pop(key, None)
    return core.canonical(value)


def analyse_whole(outputs: dict[str, dict[str, Any]], protocol: dict[str, Any]) -> dict[str, Any]:
    cohort = protocol["identityCohort"]
    arms: dict[str, dict[tuple[int, int], dict[str, Any]]] = {}
    for arm, output in outputs.items():
        rows = output.get("rows", [])
        require(f"{arm} whole row count", len(rows) == cohort["identities"])
        indexed = {(int(row["policyIndex"]), int(row["seed"])): row for row in rows}
        require(f"{arm} unique whole identities", len(indexed) == len(rows))
        arms[arm] = indexed
    require("whole CRN identities", len({frozenset(rows) for rows in arms.values()}) == 1)
    baseline = arms["current-main"]
    mismatches = {"prototypeCodeCurrentContent": 0, "prototypeNullContent": 0}
    faults = 0
    for key, expected in baseline.items():
        for arm, label in (
            ("prototype-code-current-content", "prototypeCodeCurrentContent"),
            ("prototype-null-content", "prototypeNullContent"),
        ):
            observed = arms[arm][key]
            mismatches[label] += normalised_whole(expected) != normalised_whole(observed)
            faults += bool(observed.get("error")) or observed.get("outcome") in ("stall", "error")
        faults += bool(expected.get("error")) or expected.get("outcome") in ("stall", "error")
    require("prototype code null identity", mismatches["prototypeCodeCurrentContent"] == 0)
    require("prototype content null identity", mismatches["prototypeNullContent"] == 0)
    require("whole-run reliability", faults == 0)
    return {
        "status": "PASS", "identities": cohort["identities"],
        "rows": cohort["identities"] * len(arms), "mismatchRows": mismatches,
        "reliabilityFaultRows": faults,
        "pathRngPolicyResultAndTelemetryExact": True,
    }


def main() -> None:
    if SUMMARY.exists():
        raise RuntimeError("refusing to overwrite private-debt identity summary")
    protocol, protocol_sha = core.load_protocol(PROTOCOL)
    source = source_identity()
    for key, expected in protocol["immutableInputs"].items():
        require(f"immutable {key}", source.get(key) == expected)
    require("frozen direct controls", direct_specs() == protocol["directControls"])
    ledger_before = identity.ledger_identity()
    require("ledger freeze", ledger_before == protocol["ledgerFreeze"])
    null_sha, null_path = core.cache_bytes(build_content(False), "json")
    enabled_sha, enabled_path = core.cache_bytes(build_content(True), "json")
    require("null content identity", null_sha == protocol["contentLevels"]["nullSha256"])
    require("enabled content identity", enabled_sha ==
            protocol["contentLevels"]["enabledSha256"])

    started = time.monotonic()
    deadline = started + float(protocol["budget"]["maximumWallTimeSeconds"])
    manifests: dict[str, Any] = {}
    direct: dict[str, Any] = {}
    whole: dict[str, Any] = {}
    process_count = 0
    whole_rows = 0
    direct_rows = 0
    failure = ""
    outcome = "success"
    try:
        output, plan_sha, output_sha = run_probe(
            PROTOTYPE, DIRECT_PROBE,
            direct_plan(protocol_sha, null_path, enabled_path), deadline)
        process_count += 1
        direct_rows = len(output.get("rows", []))
        direct = analyse_direct(output["rows"])
        manifests["direct"] = {"planSha256": plan_sha, "outputSha256": output_sha}

        specs = (
            ("current-main", SOURCE, SOURCE / "content/full-content.json"),
            ("prototype-code-current-content", PROTOTYPE,
             SOURCE / "content/full-content.json"),
            ("prototype-null-content", PROTOTYPE, null_path),
        )
        outputs: dict[str, dict[str, Any]] = {}
        for arm, source_path, content_path in specs:
            output, plan_sha, output_sha = run_probe(
                source_path, DIRECT_PROBE,
                whole_plan(protocol, protocol_sha, arm, content_path), deadline)
            process_count += 1
            whole_rows += len(output.get("rows", []))
            outputs[arm] = output
            manifests[arm] = {"planSha256": plan_sha, "outputSha256": output_sha}
        whole = analyse_whole(outputs, protocol)
        require("direct row ceiling",
                direct_rows == protocol["budget"]["directExecutions"])
        require("whole row ceiling",
                whole_rows == protocol["budget"]["maximumWholeRunIdentityObservationRows"])
        require("process ceiling", process_count == protocol["budget"]["maximumGodotProcesses"])
    except RuntimeError as exc:
        outcome, failure = "futility", str(exc)
    except (OSError, subprocess.SubprocessError, TimeoutError) as exc:
        outcome, failure = "inconclusive", str(exc)

    elapsed = time.monotonic() - started
    if elapsed > float(protocol["budget"]["maximumWallTimeSeconds"]):
        outcome = "inconclusive"
        failure = failure or "wall-time ceiling exceeded"
    if outcome == "success":
        boundary, decision = 1, "admit-private-debt-implementation-identity"
    elif outcome == "futility":
        boundary, decision = 2, "close-private-debt-design-at-identity"
    else:
        boundary, decision = 3, "record-private-debt-identity-inconclusive-at-cap"
    ledger_after = identity.ledger_identity()
    require("zero-row ledger identity", ledger_after == ledger_before)
    authority_key = f"{outcome}Authority"
    summary = {
        "schemaVersion": 1, "issue": 421, "decisionBoundary": boundary,
        "decision": decision, "outcomeClass": outcome, "failure": failure,
        "protocolSha256": protocol_sha, "runnerSha256": source["runnerSha256"],
        "sourceIdentity": source, "contentLevels": protocol["contentLevels"],
        "direct": direct, "wholeRunIdentity": whole, "manifests": manifests,
        "GodotProcesses": process_count, "directExecutions": direct_rows,
        "newSimulatorObservationRows": whole_rows, "enabledWholeRunRows": 0,
        "causalRows": 0, "newLedgerRows": 0,
        "ledgerBefore": ledger_before, "ledgerAfter": ledger_after,
        "protectedSeedRows": ledger_after["protectedSeedRows"],
        "maximumModelContextTokens": 0, "wallTimeSeconds": elapsed,
        "authority": protocol["decisionRules"][authority_key],
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(core.canonical({
        "status": "PASS", "decisionBoundary": boundary, "decision": decision,
        "failure": failure, "newSimulatorObservationRows": whole_rows,
        "summarySha256": core.file_sha(SUMMARY),
    }))


if __name__ == "__main__":
    main()
