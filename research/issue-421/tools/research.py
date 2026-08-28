#!/usr/bin/env python3
"""Deterministic issue #421 research runner; never shipped with the product."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import random
import sqlite3
import statistics
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "source"
PROTOCOL = ROOT / "protocols/resonance-package-v1.json"
FACET_PROTOCOL = ROOT / "protocols/facet-focus-v1.json"
CRACKED_PROTOCOL = ROOT / "protocols/cracked-tempo-v1.json"
FLOW_PROTOCOL = ROOT / "protocols/shatter-flow-v1.json"
SCORELINE_PROTOCOL = ROOT / "protocols/scoreline-handshake-v1.json"
COMBINED_PROTOCOL = ROOT / "protocols/combined-finalist-v1.json"
FINALIST_PROTOCOL = ROOT / "protocols/combined-finalist-v38-scoreline-rarity.json"
LEDGER = ROOT / "ledger/research.sqlite"
CACHE = ROOT / "cache/sha256"
WORK = ROOT / "work"
ARMS = ("none", "A", "B", "AB")


def canonical(value: Any) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def file_sha(path: Path) -> str:
    return sha(path.read_bytes())


def cache_bytes(data: bytes, suffix: str) -> tuple[str, Path]:
    digest = sha(data)
    path = CACHE / f"{digest}.{suffix}"
    CACHE.mkdir(parents=True, exist_ok=True)
    if path.exists():
        if sha(path.read_bytes()) != digest:
            raise RuntimeError(f"corrupt cache object {digest}")
    else:
        path.write_bytes(data)
    return digest, path


def cache_json(value: Any) -> tuple[str, Path]:
    return cache_bytes((canonical(value) + "\n").encode(), "json")


def open_ledger() -> sqlite3.Connection:
    LEDGER.parent.mkdir(parents=True, exist_ok=True)
    db = sqlite3.connect(LEDGER)
    db.execute("""
        CREATE TABLE IF NOT EXISTS records (
            seq INTEGER PRIMARY KEY AUTOINCREMENT,
            kind TEXT NOT NULL,
            identity TEXT NOT NULL UNIQUE,
            payload_sha256 TEXT NOT NULL,
            payload_json TEXT NOT NULL,
            created_utc TEXT NOT NULL
        )
    """)
    db.execute("""
        CREATE TRIGGER IF NOT EXISTS records_no_update
        BEFORE UPDATE ON records BEGIN
            SELECT RAISE(ABORT, 'append-only ledger');
        END
    """)
    db.execute("""
        CREATE TRIGGER IF NOT EXISTS records_no_delete
        BEFORE DELETE ON records BEGIN
            SELECT RAISE(ABORT, 'append-only ledger');
        END
    """)
    db.commit()
    return db


def record(db: sqlite3.Connection, kind: str, identity: str, payload: Any) -> None:
    payload_json = canonical(payload)
    payload_sha = sha(payload_json.encode())
    try:
        db.execute(
            "INSERT INTO records(kind, identity, payload_sha256, payload_json, created_utc) "
            "VALUES (?, ?, ?, ?, ?)",
            (kind, identity, payload_sha, payload_json,
             datetime.now(timezone.utc).isoformat(timespec="seconds")),
        )
        db.commit()
    except sqlite3.IntegrityError:
        old = db.execute(
            "SELECT kind, payload_sha256, payload_json FROM records WHERE identity = ?",
            (identity,),
        ).fetchone()
        if old != (kind, payload_sha, payload_json):
            raise RuntimeError(f"ledger identity collision: {identity}") from None


def existing_record(db: sqlite3.Connection, identity: str) -> dict[str, Any] | None:
    row = db.execute(
        "SELECT payload_json FROM records WHERE identity = ?", (identity,)
    ).fetchone()
    return None if row is None else json.loads(row[0])


def load_protocol(path: Path) -> tuple[dict[str, Any], str]:
    protocol = json.loads(path.read_text())
    return protocol, file_sha(path)


def verify_inputs(protocol: dict[str, Any]) -> dict[str, str]:
    expected = protocol["immutableInputs"]
    actual: dict[str, str] = {
        "sourceCommit": subprocess.run(
            ["git", "rev-parse", "HEAD"], cwd=SOURCE, check=True,
            text=True, capture_output=True,
        ).stdout.strip(),
        "pilotSha256": file_sha(SOURCE / "tools/balance_pilot.gd"),
        "combatRulesSha256": file_sha(SOURCE / "domain/rules/combat.gd"),
    }
    if "candidateContentSha256" in expected:
        patch = subprocess.run(
            ["git", "diff", "--", "content/full-content.json", "domain/rules/combat.gd",
             "tools/balance_pilot.gd"],
            cwd=SOURCE, check=True, capture_output=True,
        ).stdout
        actual.update({
            "candidateContentSha256": file_sha(SOURCE / "content/full-content.json"),
            "liveContentSha256": sha(subprocess.run(
                ["git", "show", "HEAD:content/full-content.json"], cwd=SOURCE,
                check=True, capture_output=True,
            ).stdout),
            "probeSha256": file_sha(SOURCE / "tools/research_421_probe.gd"),
            "prototypePatchSha256": sha(patch),
        })
    else:
        actual["contentSha256"] = file_sha(SOURCE / "content/full-content.json")
    if "researchBalanceSimSha256" in expected:
        actual["researchBalanceSimSha256"] = file_sha(SOURCE / "tools/balance_sim.gd")
    if "cemSha256" in expected:
        actual["cemSha256"] = file_sha(SOURCE / "tools/balance_cem.gd")
    if "cemSeedPacketSha256" in expected:
        actual["cemSeedPacketSha256"] = file_sha(ROOT / protocol["cem"]["seedPacket"])
    for key, value in actual.items():
        if value != expected[key]:
            raise RuntimeError(f"immutable input drift: {key} expected {expected[key]} got {value}")
    return actual


def action(card: str, upgraded: bool = False) -> dict[str, Any]:
    return {"card": card, "up": upgraded}


def controlled_plan(protocol: dict[str, Any], split: str, pairs: int) -> dict[str, Any]:
    first = 60000 if split == "discovery" else 61000
    rows: list[dict[str, Any]] = []
    for seed in range(first, first + pairs):
        producer_up, consumer_up = bool(seed & 1), bool(seed & 2)
        for edge in protocol["candidate"]["producers"]:
            for aspect in ("duskblade", "ashwarden"):
                for arm in ARMS:
                    producer = action(edge, producer_up) if arm in ("A", "AB") \
                        else action("defend")
                    consumer = action("resonantLance", consumer_up) if arm in ("B", "AB") \
                        else action("defend")
                    rows.append({
                        "id": f"controlled-{split}-{seed}-{edge}-{aspect}-{arm}",
                        "stage": "controlled", "package": "dusk-resonance",
                        "edge": edge, "arm": arm, "split": split,
                        "context": f"producer-up-{int(producer_up)}-consumer-up-{int(consumer_up)}",
                        "aspect": aspect, "seed": seed, "vow": 0,
                        "response": "directDamage", "mode": "scripted",
                        "deck": ["strike"], "enemies": ["rootheart"],
                        "unlocks": ["aspect2", "card:resonantLance"],
                        "setup": {"energy": 20}, "actions": [producer, consumer],
                    })
    maximum = int(protocol["budget"]["controlledRowsMaximum"])
    if len(rows) > maximum:
        raise ValueError(f"plan has {len(rows)} rows, over frozen maximum {maximum}")
    return {
        "schemaVersion": 1,
        "protocolSha256": file_sha(PROTOCOL),
        "content": str(SOURCE / "content/full-content.json"),
        "rows": rows,
    }


def panel_plan(protocol: dict[str, Any], split: str, pairs: int) -> dict[str, Any]:
    first = 60000 if split == "discovery" else 61000
    rows: list[dict[str, Any]] = []
    base = ["strike"] * 4 + ["defend"] * 4
    for seed in range(first, first + pairs):
        for edge in protocol["candidate"]["producers"]:
            for aspect in ("duskblade", "ashwarden"):
                for arm in ARMS:
                    producer = edge if arm in ("A", "AB") else "defend"
                    consumer = "resonantLance" if arm in ("B", "AB") else "strike"
                    rows.append({
                        "id": f"panel-{split}-{seed}-{edge}-{aspect}-{arm}",
                        "stage": "panel", "package": "dusk-resonance",
                        "edge": edge, "arm": arm, "split": split,
                        "context": "gravewarden-ten-card", "aspect": aspect,
                        "seed": seed, "vow": 0, "response": "combatUtility",
                        "mode": "pilot", "maxTurns": 20,
                        "deck": [*base, producer, consumer],
                        "enemies": ["gravewarden"],
                        "unlocks": ["aspect2", "card:resonantLance"],
                    })
    maximum = int(protocol["budget"]["panelRowsMaximum"])
    if len(rows) > maximum:
        raise ValueError(f"plan has {len(rows)} rows, over frozen maximum {maximum}")
    return {
        "schemaVersion": 1,
        "protocolSha256": file_sha(PROTOCOL),
        "content": str(SOURCE / "content/full-content.json"),
        "rows": rows,
    }


def facet_controlled_plan(protocol: dict[str, Any], split: str, pairs: int) -> dict[str, Any]:
    first = 62000 if split == "discovery" else 63000
    rows: list[dict[str, Any]] = []
    for seed in range(first, first + pairs):
        producer_up, consumer_up = bool(seed & 1), bool(seed & 2)
        for edge in protocol["candidate"]["producers"]:
            for aspect in ("duskblade", "ashwarden"):
                for arm in ARMS:
                    producer = action(edge, producer_up) if arm in ("A", "AB") \
                        else action("defend")
                    consumer = action("faultline", consumer_up) if arm in ("B", "AB") \
                        else action("defend")
                    rows.append({
                        "id": f"facet-controlled-{split}-{seed}-{edge}-{aspect}-{arm}",
                        "stage": "facet-controlled", "package": "dusk-facet-focus",
                        "edge": edge, "arm": arm, "split": split,
                        "context": f"producer-up-{int(producer_up)}-consumer-up-{int(consumer_up)}",
                        "aspect": aspect, "seed": seed, "vow": 0,
                        "response": "directDamage", "mode": "scripted",
                        "deck": ["strike"], "enemies": ["rootheart"],
                        "unlocks": ["aspect2"], "setup": {"energy": 20},
                        "actions": [producer, consumer],
                    })
    if len(rows) > int(protocol["budget"]["controlledRowsMaximum"]):
        raise ValueError("facet controlled plan exceeds frozen maximum")
    return {
        "schemaVersion": 1, "protocolSha256": file_sha(FACET_PROTOCOL),
        "content": str(CACHE / f"{protocol['immutableInputs']['candidateContentSha256']}.json"),
        "rows": rows,
    }


def facet_panel_plan(protocol: dict[str, Any], split: str, pairs: int) -> dict[str, Any]:
    first = 62000 if split == "discovery" else 63000
    rows: list[dict[str, Any]] = []
    base = ["strike"] * 4 + ["defend"] * 4
    for seed in range(first, first + pairs):
        for edge in protocol["candidate"]["producers"]:
            for aspect in ("duskblade", "ashwarden"):
                for arm in ARMS:
                    producer = edge if arm in ("A", "AB") else "defend"
                    consumer = "faultline" if arm in ("B", "AB") else "strike"
                    rows.append({
                        "id": f"facet-panel-{split}-{seed}-{edge}-{aspect}-{arm}",
                        "stage": "facet-panel", "package": "dusk-facet-focus",
                        "edge": edge, "arm": arm, "split": split,
                        "context": "gravewarden-ten-card", "aspect": aspect,
                        "seed": seed, "vow": 0, "response": "combatUtility",
                        "mode": "pilot", "maxTurns": 20,
                        "deck": [*base, producer, consumer],
                        "enemies": ["gravewarden"], "unlocks": ["aspect2"],
                    })
    if len(rows) > int(protocol["budget"]["panelRowsMaximum"]):
        raise ValueError("facet panel plan exceeds frozen maximum")
    return {
        "schemaVersion": 1, "protocolSha256": file_sha(FACET_PROTOCOL),
        "content": str(CACHE / f"{protocol['immutableInputs']['candidateContentSha256']}.json"),
        "rows": rows,
    }


def cracked_controlled_plan(protocol: dict[str, Any], split: str,
                            pairs: int) -> dict[str, Any]:
    first = 64000 if split == "discovery" else 65000
    rows: list[dict[str, Any]] = []
    for seed in range(first, first + pairs):
        producer_up, consumer_up = bool(seed & 1), bool(seed & 2)
        for edge in protocol["candidate"]["producers"]:
            for aspect in ("duskblade", "ashwarden"):
                for arm in ARMS:
                    producer = action(edge, producer_up) if arm in ("A", "AB") \
                        else action("defend")
                    consumer = action("crackstep", consumer_up) if arm in ("B", "AB") \
                        else action("defend")
                    rows.append({
                        "id": f"cracked-controlled-{split}-{seed}-{edge}-{aspect}-{arm}",
                        "stage": "cracked-controlled", "package": "dusk-cracked-tempo",
                        "edge": edge, "arm": arm, "split": split,
                        "context": f"producer-up-{int(producer_up)}-consumer-up-{int(consumer_up)}",
                        "aspect": aspect, "seed": seed, "vow": 0,
                        "response": "draw", "mode": "scripted",
                        "deck": ["strike"], "enemies": ["rootheart"],
                        "unlocks": ["aspect2"], "setup": {"energy": 20},
                        "actions": [producer, consumer],
                        "drawFill": ["strike", "defend", "strike"],
                    })
    if len(rows) > int(protocol["budget"]["controlledRowsMaximum"]):
        raise ValueError("cracked controlled plan exceeds frozen maximum")
    return {
        "schemaVersion": 1, "protocolSha256": file_sha(CRACKED_PROTOCOL),
        "content": str(CACHE / f"{protocol['immutableInputs']['candidateContentSha256']}.json"),
        "rows": rows,
    }


def cracked_panel_plan(protocol: dict[str, Any], split: str, pairs: int) -> dict[str, Any]:
    first = 64000 if split == "discovery" else 65000
    rows: list[dict[str, Any]] = []
    base = ["strike"] * 4 + ["defend"] * 4
    for seed in range(first, first + pairs):
        for edge in protocol["candidate"]["producers"]:
            for aspect in ("duskblade", "ashwarden"):
                for arm in ARMS:
                    producer = edge if arm in ("A", "AB") else "defend"
                    consumer = "crackstep" if arm in ("B", "AB") else "strike"
                    rows.append({
                        "id": f"cracked-panel-{split}-{seed}-{edge}-{aspect}-{arm}",
                        "stage": "cracked-panel", "package": "dusk-cracked-tempo",
                        "edge": edge, "arm": arm, "split": split,
                        "context": "gravewarden-ten-card", "aspect": aspect,
                        "seed": seed, "vow": 0, "response": "combatUtility",
                        "mode": "pilot", "maxTurns": 20,
                        "deck": [*base, producer, consumer],
                        "enemies": ["gravewarden"], "unlocks": ["aspect2"],
                    })
    if len(rows) > int(protocol["budget"]["panelRowsMaximum"]):
        raise ValueError("cracked panel plan exceeds frozen maximum")
    return {
        "schemaVersion": 1, "protocolSha256": file_sha(CRACKED_PROTOCOL),
        "content": str(CACHE / f"{protocol['immutableInputs']['candidateContentSha256']}.json"),
        "rows": rows,
    }


def flow_controlled_plan(protocol: dict[str, Any], split: str,
                         pairs: int) -> dict[str, Any]:
    first = 66000 if split == "discovery" else 67000
    rows: list[dict[str, Any]] = []
    for seed in range(first, first + pairs):
        enabler_up, producer_up = bool(seed & 1), bool(seed & 2)
        for edge in protocol["candidate"]["shatterProducers"]:
            for aspect in ("duskblade", "ashwarden"):
                for arm in ARMS:
                    enabler = action("fractureRhythm", enabler_up) if arm in ("A", "AB") \
                        else action("defend")
                    producer = action(edge, producer_up) if arm in ("B", "AB") \
                        else action("defend")
                    rows.append({
                        "id": f"flow-controlled-{split}-{seed}-{edge}-{aspect}-{arm}",
                        "stage": "flow-controlled", "package": "dusk-shatter-flow",
                        "edge": edge, "arm": arm, "split": split,
                        "context": f"enabler-up-{int(enabler_up)}-producer-up-{int(producer_up)}",
                        "aspect": aspect, "seed": seed, "vow": 0,
                        "response": "draw", "mode": "scripted",
                        "deck": ["strike"], "enemies": ["rootheart"],
                        "unlocks": ["aspect2"],
                        "setup": {"energy": 20, "enemyChipsFromMax": -2},
                        "actions": [enabler, producer],
                        "drawFill": ["strike", "defend", "strike"],
                    })
    if len(rows) > int(protocol["budget"]["controlledRowsMaximum"]):
        raise ValueError("flow controlled plan exceeds frozen maximum")
    return {
        "schemaVersion": 1, "protocolSha256": file_sha(FLOW_PROTOCOL),
        "content": str(CACHE / f"{protocol['immutableInputs']['candidateContentSha256']}.json"),
        "rows": rows,
    }


def flow_panel_plan(protocol: dict[str, Any], split: str, pairs: int) -> dict[str, Any]:
    first = 66000 if split == "discovery" else 67000
    rows: list[dict[str, Any]] = []
    base = ["strike"] * 4 + ["defend"] * 4
    for seed in range(first, first + pairs):
        for edge in protocol["candidate"]["shatterProducers"]:
            for aspect in ("duskblade", "ashwarden"):
                for arm in ARMS:
                    enabler = "fractureRhythm" if arm in ("A", "AB") else "defend"
                    producer = edge if arm in ("B", "AB") else "strike"
                    rows.append({
                        "id": f"flow-panel-{split}-{seed}-{edge}-{aspect}-{arm}",
                        "stage": "flow-panel", "package": "dusk-shatter-flow",
                        "edge": edge, "arm": arm, "split": split,
                        "context": "gravewarden-ten-card", "aspect": aspect,
                        "seed": seed, "vow": 0, "response": "combatUtility",
                        "mode": "pilot", "maxTurns": 20,
                        "deck": [*base, enabler, producer],
                        "enemies": ["gravewarden"], "unlocks": ["aspect2"],
                    })
    if len(rows) > int(protocol["budget"]["panelRowsMaximum"]):
        raise ValueError("flow panel plan exceeds frozen maximum")
    return {
        "schemaVersion": 1, "protocolSha256": file_sha(FLOW_PROTOCOL),
        "content": str(CACHE / f"{protocol['immutableInputs']['candidateContentSha256']}.json"),
        "rows": rows,
    }


def scoreline_controlled_plan(protocol: dict[str, Any], split: str,
                              pairs: int) -> dict[str, Any]:
    first = 68000 if split == "discovery" else 69000
    rows: list[dict[str, Any]] = []
    for seed in range(first, first + pairs):
        producer_up, consumer_up = bool(seed & 1), bool(seed & 2)
        for aspect in ("duskblade", "ashwarden"):
            for arm in ARMS:
                producer = action("scoreline", producer_up) if arm in ("A", "AB") \
                    else action("defend")
                consumer = action("snapCut", consumer_up) if arm in ("B", "AB") \
                    else action("defend")
                rows.append({
                    "id": f"scoreline-controlled-{split}-{seed}-{aspect}-{arm}",
                    "stage": "scoreline-controlled", "package": "dusk-scoreline",
                    "edge": "scoreline-snap-cut", "arm": arm, "split": split,
                    "context": f"producer-up-{int(producer_up)}-consumer-up-{int(consumer_up)}",
                    "aspect": aspect, "seed": seed, "vow": 0,
                    "response": "directDamage", "mode": "scripted",
                    "deck": ["strike"], "enemies": ["rootheart"],
                    "unlocks": ["aspect2"], "setup": {"energy": 20},
                    "actions": [producer, consumer],
                })
    if len(rows) > int(protocol["budget"]["controlledRowsMaximum"]):
        raise ValueError("scoreline controlled plan exceeds frozen maximum")
    return {
        "schemaVersion": 1, "protocolSha256": file_sha(SCORELINE_PROTOCOL),
        "content": str(CACHE / f"{protocol['immutableInputs']['candidateContentSha256']}.json"),
        "rows": rows,
    }


def scoreline_panel_plan(protocol: dict[str, Any], split: str,
                         pairs: int) -> dict[str, Any]:
    first = 68000 if split == "discovery" else 69000
    rows: list[dict[str, Any]] = []
    base = ["strike"] * 4 + ["defend"] * 4
    for seed in range(first, first + pairs):
        for aspect in ("duskblade", "ashwarden"):
            for arm in ARMS:
                producer = "scoreline" if arm in ("A", "AB") else "defend"
                consumer = "snapCut" if arm in ("B", "AB") else "strike"
                rows.append({
                    "id": f"scoreline-panel-{split}-{seed}-{aspect}-{arm}",
                    "stage": "scoreline-panel", "package": "dusk-scoreline",
                    "edge": "scoreline-snap-cut", "arm": arm, "split": split,
                    "context": "gravewarden-ten-card", "aspect": aspect,
                    "seed": seed, "vow": 0, "response": "combatUtility",
                    "mode": "pilot", "maxTurns": 20,
                    "deck": [*base, producer, consumer],
                    "enemies": ["gravewarden"], "unlocks": ["aspect2"],
                })
    if len(rows) > int(protocol["budget"]["panelRowsMaximum"]):
        raise ValueError("scoreline panel plan exceeds frozen maximum")
    return {
        "schemaVersion": 1, "protocolSha256": file_sha(SCORELINE_PROTOCOL),
        "content": str(CACHE / f"{protocol['immutableInputs']['candidateContentSha256']}.json"),
        "rows": rows,
    }


def combined_separation_plan(protocol: dict[str, Any], split: str,
                             pairs: int) -> dict[str, Any]:
    bases = protocol.get("seedBases", {})
    first = int(bases.get(f"separation{split.title()}",
                          72000 if split == "discovery" else 73000))
    packages = protocol["candidate"]["packages"]
    rows: list[dict[str, Any]] = []
    for seed in range(first, first + pairs):
        producer_up, consumer_up = bool(seed & 1), bool(seed & 2)
        for consumer_name in sorted(packages):
            consumer_spec = packages[consumer_name]
            for producer_name in sorted(packages):
                producer_spec = packages[producer_name]
                for arm in ARMS:
                    producer = action(str(producer_spec["producer"]), producer_up) \
                        if arm in ("A", "AB") else action("brace")
                    consumer = action(str(consumer_spec["consumer"]), consumer_up) \
                        if arm in ("B", "AB") else action("strike")
                    rows.append({
                        "id": f"combined-separation-{split}-{seed}-{consumer_name}-{producer_name}-{arm}",
                        "stage": "combined-separation", "package": consumer_name,
                        "edge": producer_name, "arm": arm, "split": split,
                        "context": f"consumer-{consumer_name}-producer-{producer_name}",
                        "aspect": str(consumer_spec["aspect"]), "seed": seed, "vow": 0,
                        "response": str(consumer_spec["response"]), "mode": "scripted",
                        "deck": ["strike"], "enemies": ["rootheart"],
                        "unlocks": ["aspect2"], "setup": {
                            "energy": 20,
                            "block": int(consumer_spec.get("setupBlock", 0)),
                        },
                        "actions": [producer, consumer],
                        "handFill": ["strike", "strike", "strike", "strike"],
                        "drawFill": ["strike", "defend", "strike"],
                    })
    if len(rows) > int(protocol["budget"]["controlledSeparationRowsMaximumPerSplit"]):
        raise ValueError("combined separation plan exceeds frozen maximum")
    return {
        "schemaVersion": 1, "protocolSha256": file_sha(COMBINED_PROTOCOL),
        "content": str(CACHE / f"{protocol['immutableInputs']['candidateContentSha256']}.json"),
        "rows": rows,
    }


def combined_panel_plan(protocol: dict[str, Any], split: str,
                        pairs: int) -> dict[str, Any]:
    bases = protocol.get("seedBases", {})
    first = int(bases.get(f"panel{split.title()}",
                          72000 if split == "discovery" else 73000))
    policy_root = int(bases.get(f"policyRoot{split.title()}",
                                428 if split == "discovery" else 429))
    packages = protocol["candidate"]["packages"]
    rows: list[dict[str, Any]] = []
    for offset, seed in enumerate(range(first, first + pairs)):
        for package_name in sorted(packages):
            spec = packages[package_name]
            base = ["strike"] * 8 if package_name == "dusk-afterimage-guard" \
                else ["strike"] * 4 + ["brace"] * 4
            for aspect in ("duskblade", "ashwarden"):
                for arm in ARMS:
                    producer = str(spec["producer"]) if arm in ("A", "AB") else "brace"
                    consumer = str(spec["consumer"]) if arm in ("B", "AB") else "strike"
                    rows.append({
                        "id": f"combined-panel-{split}-{seed}-{package_name}-{aspect}-{arm}",
                        "stage": "combined-panel", "package": package_name,
                        "edge": package_name, "arm": arm, "split": split,
                        "context": f"policy-{offset}", "aspect": aspect,
                        "seed": seed, "vow": 0, "response": "combatUtility",
                        "mode": "pilot", "maxTurns": 20,
                        "policyRoot": policy_root, "policyIndex": offset,
                        "deck": [*base, producer, consumer],
                        "enemies": ["gravewarden"], "unlocks": ["aspect2"],
                    })
    if len(rows) > int(protocol["budget"]["panelRowsMaximumPerSplit"]):
        raise ValueError("combined panel plan exceeds frozen maximum")
    return {
        "schemaVersion": 1, "protocolSha256": file_sha(COMBINED_PROTOCOL),
        "content": str(CACHE / f"{protocol['immutableInputs']['candidateContentSha256']}.json"),
        "rows": rows,
    }


def run_plan(db: sqlite3.Connection, protocol_sha: str, plan: dict[str, Any],
             timeout: int | None = None) -> dict[str, Any]:
    plan_sha, plan_path = cache_json(plan)
    record(db, "plan", plan_sha, plan)
    run_identity = f"probe:{plan_sha}"
    prior = existing_record(db, run_identity)
    if prior is not None:
        output_path = CACHE / f"{prior['outputSha256']}.json"
        if not output_path.is_file() or file_sha(output_path) != prior["outputSha256"]:
            raise RuntimeError(f"missing or corrupt cached output {prior['outputSha256']}")
        output = json.loads(output_path.read_text())
    else:
        WORK.mkdir(parents=True, exist_ok=True)
        raw_path = WORK / f"{plan_sha}.output.json"
        result = subprocess.run(
            ["godot", "--headless", "-s", "res://tools/research_421_probe.gd", "--",
             f"--plan={plan_path}", f"--out={raw_path}"],
            cwd=SOURCE, text=True, capture_output=True,
            timeout=timeout if timeout is not None else (
                1800 if plan.get("mode") == "whole-run" else 180),
        )
        if result.returncode or not raw_path.is_file():
            raise RuntimeError(
                f"probe failed ({result.returncode})\n{result.stdout[-2000:]}\n{result.stderr[-4000:]}"
            )
        output = json.loads(raw_path.read_text())
        output_sha, _ = cache_json(output)
        record(db, "probe-run", run_identity, {
            "planSha256": plan_sha,
            "outputSha256": output_sha,
            "protocolSha256": protocol_sha,
            "probeSha256": file_sha(SOURCE / "tools/research_421_probe.gd"),
            "rowCount": len(output["rows"]),
        })
    for row in output["rows"]:
        record(db, "observation", f"{protocol_sha}:{plan_sha}:{row['id']}", row)
    return output


def run_control_sweep(db: sqlite3.Connection, protocol_sha: str, content_sha: str,
                      split: str, seed0: int, seeds: int) -> dict[str, Any]:
    plan = {
        "schemaVersion": 1, "mode": "controls", "split": split,
        "contentSha256": content_sha, "seed0": seed0, "seeds": seeds,
        "arms": "1,2,3,4",
    }
    plan_sha, _ = cache_json(plan)
    record(db, "plan", plan_sha, plan)
    run_identity = f"balance-sweep:{plan_sha}"
    prior = existing_record(db, run_identity)
    if prior is not None:
        output_path = CACHE / f"{prior['outputSha256']}.json"
        if not output_path.is_file() or file_sha(output_path) != prior["outputSha256"]:
            raise RuntimeError(f"missing or corrupt cached output {prior['outputSha256']}")
        output = json.loads(output_path.read_text())
    else:
        WORK.mkdir(parents=True, exist_ok=True)
        raw_path = WORK / f"{plan_sha}.controls.json"
        result = subprocess.run([
            "godot", "--headless", "-s", "res://tools/balance_sweep.gd", "--",
            "--mode=controls", f"--out={raw_path}", f"--seed0={seed0}",
            f"--seeds={seeds}", "--arms=1,2,3,4",
            f"--content={CACHE / f'{content_sha}.json'}",
        ], cwd=SOURCE, text=True, capture_output=True, timeout=900)
        if result.returncode != 0:
            raise RuntimeError(
                f"balance sweep failed ({result.returncode}):\n{result.stdout}\n{result.stderr}")
        output = json.loads(raw_path.read_text())
        output_sha, _ = cache_json(output)
        record(db, "run", run_identity, {
            "planSha256": plan_sha, "outputSha256": output_sha,
            "stdout": result.stdout.strip(), "stderr": result.stderr.strip(),
        })
    for row in output["runs"]:
        row_identity = ":".join(str(row[key]) for key in ("aspect", "vow", "arm", "seed"))
        record(db, "observation", f"{plan_sha}:{row_identity}", row)
    return output


def landscape_settings(protocol: dict[str, Any], split: str) -> tuple[int, int]:
    root, seed0 = (456, 126000) if split == "discovery" else (457, 127000)
    expected = f"root {root}, indices 0-127, seeds {seed0}-{seed0 + 15}"
    if protocol["researchCohorts"]["landscape"][split] != expected:
        raise RuntimeError("landscape cohort text does not match the frozen rectangle")
    return root, seed0


def run_landscape_sweep(db: sqlite3.Connection, protocol_sha: str, content_sha: str,
                        split: str, policy_count: int, seeds: int,
                        protocol: dict[str, Any]) -> dict[str, Any]:
    root_seed, seed0 = landscape_settings(protocol, split)
    plan = {
        "schemaVersion": 1, "mode": "sweep", "split": split,
        "contentSha256": content_sha, "rootSeed": root_seed,
        "policyFirst": 0, "policyCount": policy_count,
        "seed0": seed0, "seeds": seeds,
        "sweepSha256": file_sha(SOURCE / "tools/balance_sweep.gd"),
    }
    row_count = policy_count * seeds * 4
    if row_count > int(protocol["budget"]["landscapeRowsMaximumPerContentAndSplit"]):
        raise ValueError("landscape rectangle exceeds the frozen maximum")
    plan_sha, _ = cache_json(plan)
    record(db, "plan", plan_sha, plan)
    run_identity = f"balance-sweep:{plan_sha}"
    prior = existing_record(db, run_identity)
    if prior is not None:
        output_path = CACHE / f"{prior['outputSha256']}.json"
        if not output_path.is_file() or file_sha(output_path) != prior["outputSha256"]:
            raise RuntimeError(f"missing or corrupt cached output {prior['outputSha256']}")
        output = json.loads(output_path.read_text())
    else:
        WORK.mkdir(parents=True, exist_ok=True)
        raw_path = WORK / f"{plan_sha}.landscape.jsonl"
        result = subprocess.run([
            "godot", "--headless", "-s", "res://tools/balance_sweep.gd", "--",
            "--mode=sweep", f"--out={raw_path}", f"--rootSeed={root_seed}",
            "--policyFirst=0", f"--policyCount={policy_count}",
            f"--seed0={seed0}", f"--seeds={seeds}",
            f"--content={CACHE / f'{content_sha}.json'}",
        ], cwd=SOURCE, text=True, capture_output=True, timeout=1800)
        if result.returncode != 0 or not raw_path.is_file():
            raise RuntimeError(
                f"landscape sweep failed ({result.returncode}):\n"
                f"{result.stdout[-2000:]}\n{result.stderr[-4000:]}")
        lines = [json.loads(line) for line in raw_path.read_text().splitlines() if line]
        output = {"manifest": lines[0]["manifest"], "runs": lines[1:]}
        if len(output["runs"]) != row_count:
            raise RuntimeError("landscape sweep returned an incomplete rectangle")
        output_sha, _ = cache_json(output)
        record(db, "run", run_identity, {
            "planSha256": plan_sha, "outputSha256": output_sha,
            "stdout": result.stdout.strip(), "stderr": result.stderr.strip(),
        })
    for row in output["runs"]:
        row_identity = ":".join(str(row[key]) for key in
                                ("policyIndex", "aspect", "vow", "seed"))
        record(db, "observation", f"{plan_sha}:{row_identity}", row)
    return output


def _package_fired(row: dict[str, Any], spec: dict[str, Any]) -> bool:
    return _package_activation(row, spec) > 0


def _package_activation(row: dict[str, Any], spec: dict[str, Any]) -> int:
    deck = {str(card) for card in row.get("deckIds", [])}
    if not {str(spec["producer"]), str(spec["consumer"])}.issubset(deck):
        return 0
    events = row.get("packageEvents", {})
    mediator = str(spec["mediator"])
    event_pair = {
        "enemy-scoreline": ("scorelineApplied", "scorelineConsumed"),
        "player-afterimage": ("afterimageApplied", "afterimageConsumed"),
        "enemy-mistbound": ("mistboundAppliedByToxicMist", "mistboundConsumedByCatalyst"),
        "player-bloodfire": ("bloodfireApplied", "bloodfireConsumed"),
    }[mediator]
    return min(int(float(str(events.get(event, 0)))) for event in event_pair)


def analyse_landscape(rows: list[dict[str, Any]], controls: dict[str, Any],
                      protocol: dict[str, Any], split: str, at_maximum: bool,
                      live_rows: list[dict[str, Any]] | None = None) -> dict[str, Any]:
    packages = protocol["candidate"]["packages"]
    grids: dict[str, Any] = {}
    all_clear = True
    row_key = lambda row: (int(row["policyIndex"]), str(row["aspect"]),
                           int(row["vow"]), int(row["seed"]))
    candidate = {row_key(row): str(row.get("outcome", "")) for row in rows}
    live = {row_key(row): str(row.get("outcome", "")) for row in live_rows or rows}
    if set(candidate) != set(live):
        raise ValueError("candidate/live landscape rectangles differ")
    candidate_stalls = sum(outcome == "stall" for outcome in candidate.values())
    live_stalls = sum(outcome == "stall" for outcome in live.values())
    candidate_errors = sum(outcome == "error" for outcome in candidate.values())
    live_errors = sum(outcome == "error" for outcome in live.values())
    added_stalls = sum(outcome == "stall" and live[key] != "stall"
                       for key, outcome in candidate.items())
    reliability_failure = added_stalls > 0 or candidate_errors > 0 or live_errors > 0
    for aspect in ("duskblade", "ashwarden"):
        aspect_packages = {name: spec for name, spec in packages.items()
                           if spec["aspect"] == aspect}
        for vow in (0, 5):
            grid = f"{aspect}:v{vow}"
            grid_rows = [row for row in rows
                         if row["aspect"] == aspect and int(row["vow"]) == vow]
            arm2 = float(controls["grids"][grid]["winRates"]["2"])
            route_rows: dict[str, list[dict[str, Any]]] = {}
            route_policies: dict[str, set[int]] = {}
            for name, spec in aspect_packages.items():
                witnesses = {int(row["policyIndex"]) for row in grid_rows
                             if _package_fired(row, spec)}
                route_policies[name] = witnesses
                route_rows[name] = [row for row in grid_rows
                                    if int(row["policyIndex"]) in witnesses]
            policy_rows: dict[int, list[dict[str, Any]]] = {}
            for row in grid_rows:
                policy_rows.setdefault(int(row["policyIndex"]), []).append(row)
            policy_rates = {policy: statistics.fmean(_win(row) for row in selected)
                            for policy, selected in policy_rows.items()}
            rates = {name: max((policy_rates[policy] for policy in witnesses), default=0.0)
                     for name, witnesses in route_policies.items()}
            top = max(rates.values(), default=0.0)
            routes: dict[str, Any] = {}
            grid_clear = arm2 < 0.5 and len(aspect_packages) >= 2
            for name in aspect_packages:
                witnesses = route_policies[name]
                rate = rates[name]
                viable_policies = sorted(policy for policy in witnesses
                                         if policy_rates[policy] - arm2 >= 0.35)
                viable = len(viable_policies) >= 2
                retained = viable and rate >= top - 0.10
                route_clear = len(witnesses) >= 2 and viable and retained
                grid_clear = grid_clear and route_clear
                selected = route_rows[name]
                routes[name] = {
                    "witnessPolicies": sorted(witnesses),
                    "distinctPolicies": len(witnesses),
                    "runs": len(selected),
                    "wins": sum(_win(row) for row in selected),
                    "bestPolicyRate": rate,
                    "marginOverArm2": rate - arm2,
                    "viablePolicies": viable_policies,
                    "viablePolicyCount": len(viable_policies),
                    "retainedWithin10": retained,
                    "clear": route_clear,
                }
            policy_sets = list(route_policies.values())
            distinct_endpoints = len(policy_sets) >= 2 and policy_sets[0] != policy_sets[1]
            vow5_clear = vow != 5 or top <= 0.90
            grid_clear = grid_clear and distinct_endpoints and vow5_clear
            all_clear = all_clear and grid_clear
            grids[grid] = {
                "arm2Rate": arm2, "topRouteRate": top,
                "distinctEndpointPolicySets": distinct_endpoints,
                "vow5Clear": vow5_clear, "routes": routes, "clear": grid_clear,
            }
    clear = all_clear and not reliability_failure
    if clear:
        decision = "continue-to-validation" if split == "discovery" else "admit-landscape"
    elif reliability_failure:
        decision = "reject"
    else:
        decision = "reject" if at_maximum else "extend"
    return {
        "schemaVersion": 1, "stage": "finalist-landscape", "split": split,
        "grids": grids,
        "reliability": {
            "candidateStalls": candidate_stalls, "liveStalls": live_stalls,
            "addedStalls": added_stalls, "candidateErrors": candidate_errors,
            "liveErrors": live_errors, "clear": not reliability_failure,
        },
        "decision": decision,
    }


def repertoire_screen_plan(protocol: dict[str, Any]) -> dict[str, Any]:
    root = int(protocol["seedBases"]["repertoirePolicyRoot"])
    seed0 = int(protocol["seedBases"]["repertoireScreenSeed"])
    policies = int(protocol["budget"]["repertoireScreenPolicies"])
    seeds = int(protocol["budget"]["repertoireScreenSeeds"])
    rows = [{
        "id": f"repertoire-screen-{policy}-{seed}",
        "stage": "repertoire-screen", "mode": "whole-run",
        "aspect": "duskblade", "vow": 5, "seed": seed,
        "policyRoot": root, "policyIndex": policy,
    } for policy in range(policies) for seed in range(seed0, seed0 + seeds)]
    if len(rows) > int(protocol["budget"]["repertoireScreenRowsMaximum"]):
        raise ValueError("repertoire screen exceeds the frozen maximum")
    return {
        "schemaVersion": 1, "mode": "whole-run",
        "protocolSha256": file_sha(FINALIST_PROTOCOL),
        "content": str(CACHE / f"{protocol['immutableInputs']['candidateContentSha256']}.json"),
        "rows": rows,
    }


def analyse_repertoire_screen(rows: list[dict[str, Any]],
                              protocol: dict[str, Any]) -> dict[str, Any]:
    packages = {name: spec for name, spec in protocol["candidate"]["packages"].items()
                if spec["aspect"] == "duskblade"}
    grouped: dict[int, list[dict[str, Any]]] = {}
    for row in rows:
        grouped.setdefault(int(row["policyIndex"]), []).append(row)
    count = int(protocol["budget"]["repertoireSelectedPoliciesPerRoute"])
    selected: dict[str, list[dict[str, Any]]] = {}
    for name, spec in packages.items():
        ranked: list[tuple[int, int, int, dict[str, Any]]] = []
        for policy, policy_rows in grouped.items():
            if any(str(row["outcome"]) in ("stall", "error") for row in policy_rows):
                continue
            activation = sum(_package_activation(row, spec) for row in policy_rows)
            if activation == 0:
                continue
            wins = sum(_win(row) for row in policy_rows)
            ranked.append((-wins, -activation, policy, policy_rows[0]["policy"]))
        ranked.sort(key=lambda row: row[:3])
        selected[name] = [{
            "policyIndex": policy, "policy": policy_vector,
            "screenWins": -negative_wins, "screenActivation": -negative_activation,
        } for negative_wins, negative_activation, policy, policy_vector in ranked[:count]]
    clear = all(len(rows_for_route) == count for rows_for_route in selected.values())
    return {
        "schemaVersion": 1, "stage": "repertoire-screen",
        "selected": selected, "selectionSha256": sha(canonical(selected).encode()),
        "screenFaults": sum(str(row["outcome"]) in ("stall", "error") for row in rows),
        "decision": "continue-to-validation" if clear else "reject",
    }


def repertoire_validation_plan(protocol: dict[str, Any], selection: dict[str, Any],
                               content_sha: str, split: str = "validation",
                               vow: int = 5) -> dict[str, Any]:
    seed0 = int(protocol["seedBases"][f"repertoire{split.title()}Seed"])
    seeds = int(protocol["budget"][f"repertoire{split.title()}Seeds"])
    policies: dict[int, dict[str, Any]] = {}
    for route_rows in selection.values():
        for row in route_rows:
            policies[int(row["policyIndex"])] = row["policy"]
    rows = [{
        "id": f"repertoire-{split}-v{vow}-{content_sha[:12]}-{policy}-{seed}",
        "stage": f"repertoire-{split}", "mode": "whole-run",
        "aspect": "duskblade", "vow": vow, "seed": seed,
        "policyIndex": policy, "policy": policy_vector,
    } for policy, policy_vector in sorted(policies.items())
            for seed in range(seed0, seed0 + seeds)]
    if len(rows) > int(protocol["budget"]["repertoireValidationRowsMaximumPerContent"]):
        raise ValueError("repertoire validation exceeds the frozen maximum")
    return {
        "schemaVersion": 1, "mode": "whole-run",
        "protocolSha256": file_sha(FINALIST_PROTOCOL),
        "selectionSha256": sha(canonical(selection).encode()), "split": split, "vow": vow,
        "content": str(CACHE / f"{content_sha}.json"), "rows": rows,
    }


def analyse_repertoire_validation(candidate_rows: list[dict[str, Any]],
                                   live_rows: list[dict[str, Any]],
                                   selection: dict[str, Any], arm2: float,
                                   protocol: dict[str, Any], split: str = "validation",
                                   vow: int = 5) -> dict[str, Any]:
    row_key = lambda row: (int(row["policyIndex"]), int(row["seed"]))
    candidate = {row_key(row): row for row in candidate_rows}
    live = {row_key(row): row for row in live_rows}
    if set(candidate) != set(live):
        raise ValueError("candidate/live repertoire rectangles differ")
    candidate_stalls = sum(row["outcome"] == "stall" for row in candidate.values())
    live_stalls = sum(row["outcome"] == "stall" for row in live.values())
    added_stalls = sum(row["outcome"] == "stall" and live[key]["outcome"] != "stall"
                       for key, row in candidate.items())
    candidate_errors = sum(row["outcome"] == "error" for row in candidate.values())
    live_errors = sum(row["outcome"] == "error" for row in live.values())
    packages = protocol["candidate"]["packages"]
    routes: dict[str, Any] = {}
    best_rates: list[float] = []
    credited_sets: list[set[int]] = []
    all_selected_rates: list[float] = []
    all_clear = True
    for name, selected in selection.items():
        spec = packages[name]
        policies: dict[str, Any] = {}
        credited: set[int] = set()
        for selected_row in selected:
            policy = int(selected_row["policyIndex"])
            policy_rows = [row for (found, _), row in candidate.items() if found == policy]
            rate = statistics.fmean(_win(row) for row in policy_rows)
            activation = sum(_package_activation(row, spec) for row in policy_rows)
            viable = activation > 0 and rate - arm2 >= 0.35
            if viable:
                credited.add(policy)
            all_selected_rates.append(rate)
            policies[str(policy)] = {
                "runs": len(policy_rows), "winRate": rate,
                "marginOverArm2": rate - arm2,
                "activation": activation, "viable": viable,
            }
        best = max((row["winRate"] for row in policies.values()), default=0.0)
        route_clear = len(credited) >= 2
        all_clear = all_clear and route_clear
        best_rates.append(best)
        credited_sets.append(credited)
        routes[name] = {
            "policies": policies, "creditedPolicies": sorted(credited),
            "bestPolicyRate": best, "clear": route_clear,
        }
    retention_clear = len(best_rates) == 2 and abs(best_rates[0] - best_rates[1]) <= 0.10 \
        and credited_sets[0] != credited_sets[1]
    vow5_clear = vow != 5 or (bool(all_selected_rates) and max(all_selected_rates) <= 0.90)
    reliability_clear = added_stalls == 0 and candidate_errors == 0 and live_errors == 0
    clear = all_clear and retention_clear and vow5_clear and reliability_clear
    return {
        "schemaVersion": 1, "stage": "repertoire-validation", "split": split, "vow": vow,
        "arm2Rate": arm2, "routes": routes,
        "retentionClear": retention_clear, "vow5Clear": vow5_clear,
        "reliability": {
            "candidateStalls": candidate_stalls, "liveStalls": live_stalls,
            "addedStalls": added_stalls, "candidateErrors": candidate_errors,
            "liveErrors": live_errors, "clear": reliability_clear,
        },
        "decision": "admit-repertoire" if clear else "reject",
    }


def cem_sampler_root(protocol: dict[str, Any]) -> int:
    packet_root = int(protocol["cem"]["seedPacketSamplerRoot"])
    sampler_root = int(protocol["seedBases"]["cemSamplerRoot"])
    if packet_root != sampler_root:
        raise ValueError("CEM seed packet and sampler root differ")
    return sampler_root


def run_cem_island(db: sqlite3.Connection, protocol_sha: str,
                   protocol: dict[str, Any], island: int) -> dict[str, Any]:
    spec = protocol["cem"]
    expected_islands = [int(value) for value in spec["islands"]]
    if island not in expected_islands:
        raise ValueError("CEM island is outside the frozen set")
    content_sha = protocol["immutableInputs"]["candidateContentSha256"]
    plan = {
        "schemaVersion": 1, "mode": "cem", "island": island,
        "contentSha256": content_sha,
        "population": int(spec["population"]), "elite": int(spec["elite"]),
        "maximumGenerations": int(spec["maximumGenerations"]),
        "trainingSeedsPerGeneration": int(spec["trainingSeedsPerGeneration"]),
        "trainSeed0": int(protocol["seedBases"]["cemTrain"]),
        "holdoutSeed0": int(protocol["seedBases"]["cemHoldout"]),
        "holdoutSeeds": int(spec["holdoutSeeds"]),
        "rootSeed": int(protocol["seedBases"]["cemRoot"]),
        "samplerRoot": cem_sampler_root(protocol),
        "cemSha256": protocol["immutableInputs"]["cemSha256"],
        "seedPacketSha256": protocol["immutableInputs"]["cemSeedPacketSha256"],
    }
    plan_sha, _ = cache_json(plan)
    record(db, "plan", plan_sha, plan)
    run_identity = f"cem:{plan_sha}"
    prior = existing_record(db, run_identity)
    if prior is not None:
        raw_path = CACHE / f"{prior['outputSha256']}.ndjson"
        if not raw_path.is_file() or file_sha(raw_path) != prior["outputSha256"]:
            raise RuntimeError(f"missing or corrupt cached CEM output {prior['outputSha256']}")
        raw = raw_path.read_bytes()
    else:
        WORK.mkdir(parents=True, exist_ok=True)
        output_path = WORK / f"{plan_sha}.cem.ndjson"
        result = subprocess.run([
            "godot", "--headless", "-s", "res://tools/balance_cem.gd", "--",
            f"--island={island}",
            f"--seedsJson={ROOT / spec['seedPacket']}", f"--out={output_path}",
            f"--popSize={plan['population']}", f"--elite={plan['elite']}",
            f"--maxGen={plan['maximumGenerations']}",
            f"--seedCount={plan['trainingSeedsPerGeneration']}",
            f"--trainSeed0={plan['trainSeed0']}",
            f"--holdoutSeed0={plan['holdoutSeed0']}",
            f"--holdoutCount={plan['holdoutSeeds']}",
            f"--rootSeed={plan['rootSeed']}", f"--samplerRoot={plan['samplerRoot']}",
            f"--seedPacketSha256={plan['seedPacketSha256']}",
            f"--content={CACHE / f'{content_sha}.json'}",
        ], cwd=SOURCE, text=True, capture_output=True, timeout=1800)
        if result.returncode != 0 or not output_path.is_file():
            raise RuntimeError(
                f"CEM island {island} failed ({result.returncode}):\n"
                f"{result.stdout[-2000:]}\n{result.stderr[-4000:]}")
        raw = output_path.read_bytes()
        output_sha, _ = cache_bytes(raw, "ndjson")
        record(db, "cem-run", run_identity, {
            "planSha256": plan_sha, "outputSha256": output_sha,
            "stdout": result.stdout.strip(), "stderr": result.stderr.strip(),
        })
    rows = [json.loads(line) for line in raw.decode().splitlines() if line]
    manifests = [row for row in rows if row.get("t") == "manifest"]
    generations = [row for row in rows if row.get("t") == "gen"]
    holdout = [row for row in rows if row.get("t") == "holdout"]
    finals = [row for row in rows if row.get("t") == "final"]
    if len(manifests) != 1 or len(finals) != 1 \
            or len(holdout) != int(spec["holdoutSeeds"]):
        raise RuntimeError(f"CEM island {island} returned an incomplete result")
    for row in holdout:
        record(db, "observation",
               f"{protocol_sha}:{plan_sha}:holdout:{row['seed']}", row)
    return {
        "planSha256": plan_sha, "manifest": manifests[0],
        "generations": generations, "holdout": holdout, "final": finals[0],
    }


def cem_validation_plan(protocol: dict[str, Any], selection: dict[str, Any],
                        content_sha: str) -> dict[str, Any]:
    seed0 = int(protocol["seedBases"]["cemFinalValidation"])
    seeds = int(protocol["cem"]["holdoutSeeds"])
    policies = {int(row["policyIndex"]): row["policy"]
                for route in selection.values() for row in route}
    rows = [{
        "id": f"cem-final-{content_sha[:12]}-{policy}-{seed}",
        "stage": "cem-final-validation", "mode": "whole-run",
        "aspect": "duskblade", "vow": 5, "seed": seed,
        "policyIndex": policy, "policy": vector,
    } for policy, vector in sorted(policies.items())
            for seed in range(seed0, seed0 + seeds)]
    if len(rows) > int(protocol["budget"]["cemFinalValidationRowsPerContent"]):
        raise ValueError("CEM final validation exceeds the frozen maximum")
    return {
        "schemaVersion": 1, "mode": "whole-run",
        "protocolSha256": file_sha(FINALIST_PROTOCOL),
        "content": str(CACHE / f"{content_sha}.json"), "rows": rows,
    }


def _win(row: dict[str, Any]) -> int:
    return 1 if row["outcome"] == "win" else 0


def analyse_controls(candidate_rows: list[dict[str, Any]], live_rows: list[dict[str, Any]],
                     split: str) -> dict[str, Any]:
    by_key = lambda rows: {
        (str(row["aspect"]), int(row["vow"]), int(row["arm"]), int(row["seed"])): row
        for row in rows
    }
    candidate = by_key(candidate_rows)
    live = by_key(live_rows)
    if set(candidate) != set(live):
        raise ValueError("candidate/live control rectangles differ")
    grids: dict[str, Any] = {}
    clear = True
    decisive_failure = False
    pair_count = 0
    for aspect in ("duskblade", "ashwarden"):
        for vow in (0, 5):
            grid = f"{aspect}:v{vow}"
            rates: dict[str, float] = {}
            counts: dict[str, dict[str, int]] = {}
            for arm in (1, 2, 3, 4):
                rows = [row for (found_aspect, found_vow, found_arm, _), row in candidate.items()
                        if (found_aspect, found_vow, found_arm) == (aspect, vow, arm)]
                counts[str(arm)] = {
                    outcome: sum(row["outcome"] == outcome for row in rows)
                    for outcome in ("win", "loss", "stall", "error")
                }
                rates[str(arm)] = statistics.fmean(_win(row) for row in rows)
            paired = [_win(candidate[key]) - _win(live[key]) for key in sorted(candidate)
                      if key[:3] == (aspect, vow, 2)]
            pair_count = max(pair_count, len(paired))
            movement = interval(paired, 1.0, 42900 + vow + (0 if aspect == "duskblade" else 10))
            arm2_clear = rates["2"] < 0.5
            movement_clear = abs(movement["point"]) <= 0.10
            movement_failure = movement["p025"] > 0.10 or movement["p975"] < -0.10
            keys = [key for key in candidate if key[:2] == (aspect, vow)]
            is_fault = lambda row: str(row.get("outcome", "")) in ("stall", "error") \
                or bool(str(row.get("error", "")))
            candidate_faults = sum(is_fault(candidate[key]) for key in keys)
            live_faults = sum(is_fault(live[key]) for key in keys)
            added_faults = sum(is_fault(candidate[key]) and not is_fault(live[key])
                               for key in keys)
            grid_failure = not arm2_clear or movement_failure or added_faults > 0
            grid_clear = arm2_clear and movement_clear and added_faults == 0
            clear = clear and grid_clear
            decisive_failure = decisive_failure or grid_failure
            grids[grid] = {
                "winRates": rates, "outcomes": counts,
                "plannedMinusRandomBuildDiagnostic": rates["1"] - rates["2"],
                "arm2MovementCandidateMinusLive": movement,
                "arm2BelowHalf": arm2_clear,
                "globalMovementClear": movement_clear,
                "candidateFaults": candidate_faults, "liveFaults": live_faults,
                "addedFaults": added_faults, "faults": added_faults,
                "decisiveFailure": grid_failure, "clear": grid_clear,
            }
    if clear:
        decision = "continue-to-validation" if split == "discovery" else "admit-controls"
    elif decisive_failure:
        decision = "reject"
    else:
        decision = "inconclusive-stop" if pair_count >= 128 else "extend"
    return {
        "schemaVersion": 1, "stage": "finalist-controls", "split": split,
        "grids": grids,
        "decision": decision,
    }


def percentile(values: list[float], probability: float) -> float:
    ordered = sorted(values)
    position = (len(ordered) - 1) * probability
    low = math.floor(position)
    high = math.ceil(position)
    if low == high:
        return ordered[low]
    return ordered[low] + (ordered[high] - ordered[low]) * (position - low)


def interval(values: list[float], scale: float, seed: int) -> dict[str, float]:
    if not values:
        raise ValueError("effect interval requires observations")
    if scale <= 0:
        if all(value == 0 for value in values):
            return {"point": 0.0, "p025": 0.0, "p975": 0.0, "scale": 0.0}
        raise ValueError("non-zero effect interval requires a positive scale")
    rng = random.Random(seed)
    boot = [statistics.fmean(rng.choice(values) for _ in values) / scale
            for _ in range(5000)]
    return {
        "point": statistics.fmean(values) / scale,
        "p025": percentile(boot, 0.025),
        "p975": percentile(boot, 0.975),
        "scale": scale,
    }


def analyse_controlled(rows: list[dict[str, Any]], split: str,
                       edges: tuple[str, ...] = ("eclipseSlash", "warCry"),
                       stage: str = "controlled", boot_base: int = 42100,
                       require_ash_below: bool = False,
                       metric: str = "directDamage") -> dict[str, Any]:
    grouped: dict[tuple[str, str, int], dict[str, float]] = {}
    for row in rows:
        if row["stage"] != stage or row["split"] != split:
            continue
        key = (row["edge"], row["aspect"], int(row["seed"]))
        grouped.setdefault(key, {})[row["arm"]] = float(row["totals"][metric])
    effects: dict[str, Any] = {}
    for edge in edges:
        for aspect in ("duskblade", "ashwarden"):
            blocks = [arms for (found_edge, found_aspect, _), arms in grouped.items()
                      if found_edge == edge and found_aspect == aspect]
            if not blocks or any(set(block) != set(ARMS) for block in blocks):
                raise ValueError(f"incomplete matched block: {edge}/{aspect}/{split}")
            interactions = [block["AB"] - block["A"] - block["B"] + block["none"]
                            for block in blocks]
            scale = statistics.pstdev(value for block in blocks for value in block.values())
            effects[f"{edge}:{aspect}"] = {
                "pairs": len(blocks),
                "rawInteraction": statistics.fmean(interactions),
                "standardisedInteraction": interval(
                    interactions, scale, boot_base + (1 if split == "discovery" else 2)),
                "reproducibleValues": sorted(set(interactions)),
            }
    dusk = [effects[f"{edge}:duskblade"]["standardisedInteraction"]
            for edge in edges]
    lower = min(effect["p025"] for effect in dusk)
    upper = min(effect["p975"] for effect in dusk)
    ash = [effects[f"{edge}:ashwarden"]["standardisedInteraction"] for edge in edges]
    ash_upper = max(effect["p975"] for effect in ash)
    ash_lower = max(effect["p025"] for effect in ash)
    passes = lower >= 0.25 and (not require_ash_below or ash_upper < 0.25)
    decisive_fail = upper < 0.25 or (require_ash_below and ash_lower >= 0.25)
    at_maximum = next(iter(effects.values()))["pairs"] >= 128
    return {
        "schemaVersion": 1, "stage": stage, "split": split,
        "effects": effects, "target": 0.25,
        "decision": ("continue-to-validation" if split == "discovery" else "continue-to-panel")
        if passes else ("reject" if decisive_fail else (
            "inconclusive-stop" if at_maximum else "extend")),
    }


def analyse_panel(rows: list[dict[str, Any]], split: str,
                  edges: tuple[str, ...] = ("eclipseSlash", "warCry"),
                  stage: str = "panel", boot_base: int = 42110,
                  target_aspect: str = "duskblade",
                  require_separation: bool = True) -> dict[str, Any]:
    other_aspect = "ashwarden" if target_aspect == "duskblade" else "duskblade"
    grouped: dict[tuple[str, str, int], dict[str, dict[str, Any]]] = {}
    for row in rows:
        if row["stage"] != stage or row["split"] != split:
            continue
        key = (row["edge"], row["aspect"], int(row["seed"]))
        grouped.setdefault(key, {})[row["arm"]] = row
    effects: dict[str, Any] = {}
    activations: dict[tuple[str, str], dict[int, float]] = {}
    total_added_stalls = 0
    duration_deltas: list[float] = []
    for edge in edges:
        for aspect in ("duskblade", "ashwarden"):
            blocks = [(seed, arms) for (found_edge, found_aspect, seed), arms in grouped.items()
                      if found_edge == edge and found_aspect == aspect]
            if not blocks or any(set(block) != set(ARMS) for _, block in blocks):
                raise ValueError(f"incomplete matched panel: {edge}/{aspect}/{split}")
            utility: list[float] = []
            activation: dict[int, float] = {}
            outcomes = {arm: {"win": 0, "loss": 0, "stall": 0} for arm in ARMS}
            added_stalls = 0
            comparable_turns: list[float] = []
            for seed, block in blocks:
                values = {
                    arm: float(block[arm]["totals"]["damage"] - block[arm]["hpLost"])
                    for arm in ARMS
                }
                utility.extend(values.values())
                activation[seed] = values["AB"] - max(
                    values["A"], values["B"], values["none"])
                for arm in ARMS:
                    outcomes[arm][block[arm]["outcome"]] += 1
                if block["AB"]["outcome"] != "win" \
                        and any(block[arm]["outcome"] == "win" for arm in ("none", "A", "B")):
                    added_stalls += 1
                if all(block[arm]["outcome"] == "win" for arm in ARMS):
                    delta = float(block["AB"]["turns"] - min(
                        block[arm]["turns"] for arm in ("none", "A", "B")))
                    comparable_turns.append(delta)
                    if aspect == target_aspect:
                        duration_deltas.append(delta)
            scale = statistics.pstdev(utility)
            activations[(edge, aspect)] = activation
            effects[f"{edge}:{aspect}"] = {
                "pairs": len(blocks), "outcomes": outcomes,
                "addedStalls": added_stalls,
                "activation": interval(
                    list(activation.values()), scale,
                    boot_base + (1 if split == "discovery" else 2),
                ),
                "comparableWinPairs": len(comparable_turns),
                "turnDelta": None if not comparable_turns else interval(
                    comparable_turns, 1.0,
                    boot_base + (3 if split == "discovery" else 4),
                ),
            }
            total_added_stalls += added_stalls
    separation: dict[str, Any] = {}
    for edge in edges:
        target = activations[(edge, target_aspect)]
        control = activations[(edge, other_aspect)]
        values = [target[seed] - control[seed] for seed in sorted(target)]
        separation[edge] = interval(
            values, 1.0, boot_base + (5 if split == "discovery" else 6))
    target_activation = [effects[f"{edge}:{target_aspect}"]["activation"]
                         for edge in edges]
    activation_lower = min(value["p025"] for value in target_activation)
    activation_upper = min(value["p975"] for value in target_activation)
    separation_lower = min(value["p025"] for value in separation.values())
    separation_upper = min(value["p975"] for value in separation.values())
    duration = None if not duration_deltas else interval(
        duration_deltas, 1.0, boot_base + (7 if split == "discovery" else 8))
    passes = (activation_lower >= 0.25 and (not require_separation or separation_lower > 0)
              and total_added_stalls == 0 and duration is not None
              and duration["p975"] <= 0.25)
    decisive_fail = (activation_upper < 0.25 or total_added_stalls > 0
                     or (require_separation and separation_upper <= 0)
                     or (duration is not None and duration["p025"] > 0.25)
                     or (duration is None and len(next(iter(activations.values()))) >= 128))
    at_maximum = len(next(iter(activations.values()))) >= 128
    decision = ("continue-to-validation" if split == "discovery" else "admit-local-panel") \
        if passes else ("reject" if decisive_fail else (
            "inconclusive-stop" if at_maximum else "extend"))
    return {
        "schemaVersion": 1, "stage": stage, "split": split,
        "effects": effects, "aspectSeparation": separation,
        "duration": duration, "target": 0.25,
        "totalAddedStalls": total_added_stalls, "decision": decision,
    }


def analyse_combined_separation(rows: list[dict[str, Any]], split: str,
                                protocol: dict[str, Any]) -> dict[str, Any]:
    packages = protocol["candidate"]["packages"]
    grouped: dict[tuple[str, str, int], dict[str, float]] = {}
    for row in rows:
        key = (str(row["package"]), str(row["edge"]), int(row["seed"]))
        metric = str(row["response"])
        grouped.setdefault(key, {})[str(row["arm"])] = float(row["totals"][metric])
    effects: dict[str, Any] = {}
    diagonal_clear = True
    off_diagonal_clear = True
    for consumer_index, consumer in enumerate(sorted(packages)):
        for producer_index, producer in enumerate(sorted(packages)):
            blocks = [arms for (found_consumer, found_producer, _seed), arms in grouped.items()
                      if found_consumer == consumer and found_producer == producer]
            if not blocks or any(set(block) != set(ARMS) for block in blocks):
                raise ValueError(f"incomplete separation block: {consumer}/{producer}/{split}")
            interactions = [block["AB"] - block["A"] - block["B"] + block["none"]
                            for block in blocks]
            scale = statistics.pstdev(value for block in blocks for value in block.values())
            estimate = interval(interactions, scale,
                                42600 + consumer_index * 10 + producer_index)
            diagonal = consumer == producer
            clear = estimate["p025"] >= 0.25 if diagonal else estimate["p975"] < 0.25
            diagonal_clear = diagonal_clear and (clear if diagonal else True)
            off_diagonal_clear = off_diagonal_clear and (clear if not diagonal else True)
            effects[f"{consumer}<-{producer}"] = {
                "pairs": len(blocks), "diagonal": diagonal,
                "rawInteraction": statistics.fmean(interactions),
                "standardisedInteraction": estimate,
                "reproducibleValues": sorted(set(interactions)), "clear": clear,
            }
    passes = diagonal_clear and off_diagonal_clear
    return {
        "schemaVersion": 1, "stage": "combined-separation", "split": split,
        "effects": effects, "target": 0.25,
        "diagonalClear": diagonal_clear, "offDiagonalClear": off_diagonal_clear,
        "decision": ("continue-to-validation" if split == "discovery"
                     else "admit-functional-separation") if passes else "reject",
    }


def _combined_mechanism_fired(package: str, row: dict[str, Any]) -> bool:
    cards = row.get("cards") or {}
    if package == "ash-hand-size":
        return int((cards.get("preparation") or {}).get("draw", 0)) > 0 \
            and int((cards.get("phantomBlades") or {}).get("damage", 0)) > 0
    if package == "ash-poison-catalyst":
        return int((cards.get("toxicMist") or {}).get("status:mistbound", 0)) > 0 \
            and int((cards.get("catalyst") or {}).get("status:mistbound", 0)) < 0
    if package == "ash-bloodfire-leech":
        return int((cards.get("bloodRite") or {}).get("status:bloodfire", 0)) > 0 \
            and int((cards.get("leechBlade") or {}).get("status:bloodfire", 0)) < 0 \
            and int((cards.get("leechBlade") or {}).get("damage", 0)) > 0
    if package == "dusk-scoreline":
        return int((cards.get("chisel") or {}).get("status:scoreline", 0)) > 0 \
            and int((cards.get("executioner") or {}).get("status:scoreline", 0)) < 0 \
            and int((cards.get("executioner") or {}).get("shatter", 0)) > 0
    if package == "dusk-ward-mirror":
        return int((cards.get("mirrorEdge") or {}).get("block", 0)) > 0 \
            and int((cards.get("fortify") or {}).get("block", 0)) > 0
    if package == "dusk-afterimage-guard":
        return int((cards.get("defend") or {}).get("status:afterimage", 0)) > 0 \
            and int((cards.get("guardedStrike") or {}).get("status:afterimage", 0)) < 0 \
            and int((cards.get("guardedStrike") or {}).get("damage", 0)) > 0
    raise ValueError(f"unknown combined package {package}")


def analyse_combined_panel(rows: list[dict[str, Any]], split: str,
                           protocol: dict[str, Any]) -> dict[str, Any]:
    packages = protocol["candidate"]["packages"]
    out: dict[str, Any] = {}
    all_clear = True
    for index, package in enumerate(sorted(packages)):
        spec = packages[package]
        package_rows = [row for row in rows if row["package"] == package]
        result = analyse_panel(
            package_rows, split, (package,), "combined-panel", 42700 + index * 20,
            str(spec["aspect"]), bool(spec["requiresAspectSeparation"]),
        )
        grouped: dict[int, dict[str, dict[str, Any]]] = {}
        for row in package_rows:
            if row["aspect"] == spec["aspect"]:
                grouped.setdefault(int(row["seed"]), {})[str(row["arm"])] = row
        witnesses = 0
        for block in grouped.values():
            if set(block) != set(ARMS):
                raise ValueError(f"incomplete policy witness block: {package}/{split}")
            utility = {arm: float(block[arm]["totals"]["damage"] - block[arm]["hpLost"])
                       for arm in ARMS}
            if utility["AB"] > max(utility["A"], utility["B"], utility["none"]) \
                    and _combined_mechanism_fired(package, block["AB"]):
                witnesses += 1
        expected = "continue-to-validation" if split == "discovery" else "admit-local-panel"
        clear = result["decision"] == expected and witnesses >= 8
        all_clear = all_clear and clear
        out[package] = {"panel": result, "policyWitnesses": witnesses, "clear": clear}
    return {
        "schemaVersion": 1, "stage": "combined-panel", "split": split,
        "packages": out, "minimumPolicyWitnesses": 8,
        "decision": ("continue-to-whole-run-discovery" if split == "discovery"
                     else "admit-package-panels") if all_clear else "reject",
    }


def _card_metric(row: dict[str, Any], card: str, metric: str) -> float:
    return float((row.get("cards") or {}).get(card, {}).get(metric, 0))


def analyse_finalist_panel(rows: list[dict[str, Any]], split: str,
                           protocol: dict[str, Any]) -> dict[str, Any]:
    packages = protocol["candidate"]["packages"]
    out: dict[str, Any] = {}
    all_clear = True
    any_decisive_failure = False
    pair_count = 0
    for index, package in enumerate(sorted(packages)):
        spec = packages[package]
        target_aspect = str(spec["aspect"])
        other_aspect = "ashwarden" if target_aspect == "duskblade" else "duskblade"
        grouped: dict[tuple[str, int], dict[str, dict[str, Any]]] = {}
        for row in rows:
            if row["package"] == package:
                grouped.setdefault((str(row["aspect"]), int(row["seed"])), {})[
                    str(row["arm"])] = row
        activations: dict[str, dict[int, float]] = {
            target_aspect: {}, other_aspect: {},
        }
        outcomes = {aspect: {arm: {"win": 0, "loss": 0, "stall": 0}
                             for arm in ARMS}
                    for aspect in (target_aspect, other_aspect)}
        added_stalls = 0
        duration_deltas: list[float] = []
        witnesses = 0
        response_values: dict[str, list[float]] = {
            target_aspect: [], other_aspect: [],
        }
        consumer = str(spec["consumer"])
        metric = str(spec["cardMetric"])
        metric_direction = float(spec.get("cardMetricDirection", 1.0))
        for aspect in (target_aspect, other_aspect):
            blocks = [(seed, block) for (found_aspect, seed), block in grouped.items()
                      if found_aspect == aspect]
            if not blocks or any(set(block) != set(ARMS) for _, block in blocks):
                raise ValueError(f"incomplete finalist panel: {package}/{aspect}/{split}")
            for seed, block in blocks:
                values = {
                    arm: metric_direction * _card_metric(block[arm], consumer, metric)
                    for arm in ARMS
                }
                response_values[aspect].extend(values.values())
                activation = values["AB"] - values["B"]
                activations[aspect][seed] = activation
                for arm in ARMS:
                    outcomes[aspect][arm][str(block[arm]["outcome"])] += 1
                if aspect == target_aspect and block["AB"]["outcome"] != "win" \
                        and any(block[arm]["outcome"] == "win"
                                for arm in ("none", "A", "B")):
                    added_stalls += 1
                if aspect == target_aspect and all(
                        block[arm]["outcome"] == "win" for arm in ARMS):
                    duration_deltas.append(float(block["AB"]["turns"] - min(
                        block[arm]["turns"] for arm in ("none", "A", "B"))))
                if aspect == target_aspect and activation > 0 \
                        and _combined_mechanism_fired(package, block["AB"]):
                    witnesses += 1
        target_scale = statistics.pstdev(response_values[target_aspect])
        control_scale = statistics.pstdev(response_values[other_aspect])
        target = interval(list(activations[target_aspect].values()), target_scale,
                          42800 + index * 20 + (1 if split == "discovery" else 2))
        control = interval(list(activations[other_aspect].values()), control_scale,
                           42800 + index * 20 + (3 if split == "discovery" else 4))
        separation_values = [activations[target_aspect][seed]
                             - activations[other_aspect][seed]
                             for seed in sorted(activations[target_aspect])]
        separation = interval(
            separation_values, 1.0,
            42800 + index * 20 + (5 if split == "discovery" else 6),
        )
        duration = None if not duration_deltas else interval(
            duration_deltas, 1.0,
            42800 + index * 20 + (7 if split == "discovery" else 8),
        )
        requires_separation = bool(spec["requiresAspectSeparation"])
        pair_count = len(activations[target_aspect])
        clear = (target["p025"] >= 0.25 and witnesses >= 8 and added_stalls == 0
                 and duration is not None and duration["p975"] <= 0.25
                 and (not requires_separation or separation["p025"] > 0))
        decisive_failure = (target["p975"] < 0.25 or added_stalls > 0
                            or (duration is not None and duration["p025"] > 0.25)
                            or (requires_separation and separation["p975"] <= 0)
                            or (pair_count >= 128 and (duration is None or witnesses < 8)))
        all_clear = all_clear and clear
        any_decisive_failure = any_decisive_failure or decisive_failure
        out[package] = {
            "activation": target, "controlActivation": control,
            "aspectSeparation": separation, "duration": duration,
            "policyWitnesses": witnesses, "addedStalls": added_stalls,
            "outcomes": outcomes, "clear": clear,
            "decisiveFailure": decisive_failure,
        }
    if all_clear:
        decision = "continue-to-whole-run-discovery" if split == "discovery" \
            else "admit-package-panels"
    elif any_decisive_failure:
        decision = "reject"
    else:
        decision = "inconclusive-stop" if pair_count >= 128 else "extend"
    return {
        "schemaVersion": 1, "stage": "finalist-panel", "split": split,
        "packages": out, "activationTarget": 0.25,
        "minimumPolicyWitnesses": 8,
        "decision": decision,
    }


def self_check() -> None:
    assert cem_sampler_root({
        "cem": {"seedPacketSamplerRoot": 490},
        "seedBases": {"cemSamplerRoot": 490},
    }) == 490
    try:
        cem_sampler_root({
            "cem": {"seedPacketSamplerRoot": 490},
            "seedBases": {"cemSamplerRoot": 491},
        })
        raise AssertionError("CEM sampler mismatch was accepted")
    except ValueError as fault:
        assert str(fault) == "CEM seed packet and sampler root differ"
    rows: list[dict[str, Any]] = []
    for seed in range(4):
        for edge in ("eclipseSlash", "warCry"):
            for aspect in ("duskblade", "ashwarden"):
                for arm, damage in zip(ARMS, (0, 2, 3, 7), strict=True):
                    rows.append({
                        "stage": "controlled", "split": "discovery", "edge": edge,
                        "aspect": aspect, "seed": seed, "arm": arm,
                        "totals": {"directDamage": damage},
                    })
    result = analyse_controlled(rows, "discovery")
    assert result["decision"] == "continue-to-validation", result
    assert all(value["rawInteraction"] == 2 for value in result["effects"].values())
    panel_rows: list[dict[str, Any]] = []
    for seed in range(8):
        for edge in ("eclipseSlash", "warCry"):
            for aspect in ("duskblade", "ashwarden"):
                damage = (0, 1, 1, 4) if aspect == "duskblade" else (0, 1, 1, 2)
                for arm, value in zip(ARMS, damage, strict=True):
                    panel_rows.append({
                        "stage": "panel", "split": "discovery", "edge": edge,
                        "aspect": aspect, "seed": seed, "arm": arm,
                        "totals": {"damage": value}, "hpLost": 0,
                        "outcome": "win", "turns": 3 if arm == "AB" else 4,
                    })
    panel_result = analyse_panel(panel_rows, "discovery")
    assert panel_result["decision"] == "continue-to-validation", panel_result
    finalist_rows: list[dict[str, Any]] = []
    for seed in range(8):
        for aspect in ("duskblade", "ashwarden"):
            for arm in ARMS:
                active = aspect == "duskblade" and arm == "AB"
                guarded = 12 if active else (4 if arm in ("B", "AB") else 0)
                cards = {"guardedStrike": {"block": guarded, "damage": guarded}}
                if active:
                    cards["defend"] = {"status:afterimage": 1}
                    cards["guardedStrike"]["status:afterimage"] = -1
                finalist_rows.append({
                    "package": "dusk-afterimage-guard", "aspect": aspect,
                    "seed": seed, "arm": arm,
                    "outcome": "loss" if aspect == "ashwarden" and arm == "AB" else "win",
                    "turns": 3 if active else 4, "cards": cards,
                })
    finalist_protocol = {"candidate": {"packages": {"dusk-afterimage-guard": {
        "aspect": "duskblade", "consumer": "guardedStrike", "cardMetric": "block",
        "requiresAspectSeparation": True,
    }}}}
    finalist_result = analyse_finalist_panel(
        finalist_rows, "discovery", finalist_protocol)
    assert finalist_result["decision"] == "continue-to-whole-run-discovery", finalist_result
    control_rows: list[dict[str, Any]] = []
    for aspect in ("duskblade", "ashwarden"):
        for vow in (0, 5):
            for arm in (1, 2, 3, 4):
                for seed in range(8):
                    win = arm == 1 and (vow == 0 or seed == 0)
                    control_rows.append({
                        "aspect": aspect, "vow": vow, "arm": arm, "seed": seed,
                        "outcome": "win" if win else "loss", "error": "",
                    })
    controls_result = analyse_controls(control_rows, control_rows, "discovery")
    assert controls_result["decision"] == "continue-to-validation", controls_result
    shared_fault_rows = [dict(row) for row in control_rows]
    shared_fault_rows[16]["outcome"] = "stall"
    shared_fault_result = analyse_controls(
        shared_fault_rows, shared_fault_rows, "discovery")
    assert shared_fault_result["decision"] == "continue-to-validation", shared_fault_result
    moved_rows = [dict(row) for row in control_rows]
    moved_rows[8]["outcome"] = "win"
    movement_result = analyse_controls(moved_rows, control_rows, "discovery")
    assert movement_result["decision"] == "extend", movement_result
    moved_rows[16]["outcome"] = "stall"
    fault_result = analyse_controls(moved_rows, control_rows, "discovery")
    assert fault_result["decision"] == "reject", fault_result
    finalist = json.loads(FINALIST_PROTOCOL.read_text())
    setup_protocol = json.loads(json.dumps(finalist))
    setup_protocol["candidate"]["packages"]["dusk-afterimage-guard"]["setupBlock"] = 8
    separation_plan = combined_separation_plan(setup_protocol, "discovery", 1)
    afterimage_rows = [
        row for row in separation_plan["rows"]
        if row["package"] == "dusk-afterimage-guard"
    ]
    assert afterimage_rows
    assert {row["setup"]["block"] for row in afterimage_rows} == {8}
    neutral_protocol = json.loads(json.dumps(finalist))
    neutral_protocol["budget"]["panelRowsMaximumPerSplit"] = 4096
    panel_plan = combined_panel_plan(neutral_protocol, "discovery", 1)
    package_cards = {
        str(spec[key])
        for spec in finalist["candidate"]["packages"].values()
        for key in ("producer", "consumer")
    }
    none_rows = [row for row in panel_plan["rows"] if row["arm"] == "none"]
    assert none_rows
    assert all(not (set(row["deck"]) & package_cards) for row in none_rows)
    landscape_rows: list[dict[str, Any]] = []
    event_pairs = {
        "enemy-scoreline": ("scorelineApplied", "scorelineConsumed"),
        "player-afterimage": ("afterimageApplied", "afterimageConsumed"),
        "enemy-mistbound": ("mistboundAppliedByToxicMist", "mistboundConsumedByCatalyst"),
        "player-bloodfire": ("bloodfireApplied", "bloodfireConsumed"),
    }
    for aspect in ("duskblade", "ashwarden"):
        aspect_packages = [(name, spec) for name, spec in finalist["candidate"]["packages"].items()
                           if spec["aspect"] == aspect]
        for vow in (0, 5):
            for package_offset, (_, spec) in enumerate(aspect_packages):
                for policy_offset in range(2):
                    for seed in range(4):
                        first_event, second_event = event_pairs[str(spec["mediator"])]
                        landscape_rows.append({
                            "policyIndex": package_offset * 2 + policy_offset,
                            "aspect": aspect, "vow": vow, "seed": seed,
                            "outcome": "loss" if vow == 5 and seed == 0 else "win",
                            "deckIds": [spec["producer"], spec["consumer"]],
                            "packageEvents": {first_event: 1, second_event: 1},
                        })
    fake_controls = {"grids": {
        f"{aspect}:v{vow}": {"winRates": {"2": 0.2}}
        for aspect in ("duskblade", "ashwarden") for vow in (0, 5)
    }}
    landscape_result = analyse_landscape(
        landscape_rows, fake_controls, finalist, "discovery", False)
    assert landscape_result["decision"] == "continue-to-validation", landscape_result
    repertoire_rows: list[dict[str, Any]] = []
    dusk_packages = [(name, spec) for name, spec in finalist["candidate"]["packages"].items()
                     if spec["aspect"] == "duskblade"]
    for route_offset, (_, spec) in enumerate(dusk_packages):
        first_event, second_event = event_pairs[str(spec["mediator"])]
        for policy_offset in range(8):
            policy = route_offset * 8 + policy_offset
            for seed in range(4):
                repertoire_rows.append({
                    "policyIndex": policy, "seed": seed,
                    "outcome": "loss" if seed == 0 else "win",
                    "deckIds": [spec["producer"], spec["consumer"]],
                    "packageEvents": {first_event: 1, second_event: 1},
                    "policy": {"id": policy},
                })
    repertoire_screen = analyse_repertoire_screen(repertoire_rows, finalist)
    assert repertoire_screen["decision"] == "continue-to-validation", repertoire_screen
    repertoire_validation = analyse_repertoire_validation(
        repertoire_rows, repertoire_rows, repertoire_screen["selected"], 0.1, finalist)
    assert repertoire_validation["decision"] == "admit-repertoire", repertoire_validation
    assert percentile([0, 10], 0.5) == 5
    print("PASS research.py self-check")


def main() -> None:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("self-check")
    for name in ("controlled", "panel", "facet-controlled", "facet-panel",
                 "cracked-controlled", "cracked-panel", "flow-controlled", "flow-panel",
                 "scoreline-controlled", "scoreline-panel", "combined-separation",
                 "combined-panel", "finalist-separation", "finalist-panel"):
        command = sub.add_parser(name)
        command.add_argument("--split", choices=("discovery", "validation"), required=True)
        command.add_argument("--pairs", type=int, choices=(32, 64, 128), required=True)
    controls = sub.add_parser("finalist-controls")
    controls.add_argument("--split", choices=("discovery", "validation"), required=True)
    controls.add_argument("--seeds", type=int, choices=(32, 64, 128), required=True)
    landscape = sub.add_parser("finalist-landscape")
    landscape.add_argument("--split", choices=("discovery", "validation"), required=True)
    landscape.add_argument("--policies", type=int, choices=(64, 128), required=True)
    landscape.add_argument("--seeds", type=int, choices=(8, 16), required=True)
    sub.add_parser("finalist-repertoire-screen")
    sub.add_parser("finalist-repertoire-validation")
    frozen_repertoire = sub.add_parser("finalist-frozen-repertoire")
    frozen_repertoire.add_argument(
        "--split", choices=("discovery", "validation"), required=True)
    sub.add_parser("finalist-cem-repertoire")
    args = parser.parse_args()
    if args.command == "self-check":
        self_check()
        return
    facet = args.command.startswith("facet-")
    cracked = args.command.startswith("cracked-")
    flow = args.command.startswith("flow-")
    scoreline = args.command.startswith("scoreline-")
    combined = args.command.startswith("combined-")
    finalist = args.command.startswith("finalist-")
    protocol_path = FACET_PROTOCOL if facet else (
        CRACKED_PROTOCOL if cracked else (FLOW_PROTOCOL if flow else (
            SCORELINE_PROTOCOL if scoreline else (COMBINED_PROTOCOL if combined else (
                FINALIST_PROTOCOL if finalist else PROTOCOL)))))
    protocol, protocol_sha = load_protocol(protocol_path)
    if hasattr(args, "pairs") \
            and args.pairs > int(protocol["budget"]["maximumPairsPerArmAndSplit"]):
        raise ValueError("pair count exceeds protocol")
    identity = verify_inputs(protocol)
    if "candidateContentSha256" in protocol["immutableInputs"]:
        cached_content_sha, _ = cache_bytes(
            (SOURCE / "content/full-content.json").read_bytes(), "json")
        if cached_content_sha != protocol["immutableInputs"]["candidateContentSha256"]:
            raise RuntimeError("candidate content cache identity drift")
        live_bytes = subprocess.run(
            ["git", "show", "HEAD:content/full-content.json"], cwd=SOURCE,
            check=True, capture_output=True,
        ).stdout
        cached_live_sha, _ = cache_bytes(live_bytes, "json")
        if cached_live_sha != protocol["immutableInputs"]["liveContentSha256"]:
            raise RuntimeError("live content cache identity drift")
    db = open_ledger()
    record(db, "protocol", protocol_sha, protocol)
    record(db, "source-identity", sha(canonical(identity).encode()), identity)
    if args.command == "finalist-cem-repertoire":
        cem_outputs = [run_cem_island(db, protocol_sha, protocol, int(island))
                       for island in protocol["cem"]["islands"]]
        selection: dict[str, list[dict[str, Any]]] = {}
        cem_readout: dict[str, Any] = {}
        holdout_faults = 0
        for output in cem_outputs:
            final = output["final"]
            island = int(final["island"])
            route = str(protocol["cem"]["assignedRoutes"][str(island)])
            selection.setdefault(route, []).append({
                "policyIndex": island, "policy": final["policy"],
            })
            spec = protocol["candidate"]["packages"][route]
            activation = sum(_package_activation(row, spec) for row in output["holdout"])
            faults = sum(str(row["outcome"]) in ("stall", "error")
                         for row in output["holdout"])
            holdout_faults += faults
            cem_readout[str(island)] = {
                "assignedRoute": route, "startCell": final["startCell"],
                "generations": final["gens"], "stop": final["stop"],
                "bestTrainFitness": final["bestTrainFitness"],
                "holdoutWinRate": final["holdoutCeiling"],
                "holdoutActivation": activation, "holdoutFaults": faults,
                "planSha256": output["planSha256"],
            }
        candidate_sha = protocol["immutableInputs"]["candidateContentSha256"]
        live_sha = protocol["immutableInputs"]["liveContentSha256"]
        candidate_output = run_plan(
            db, protocol_sha, cem_validation_plan(protocol, selection, candidate_sha))
        live_output = run_plan(
            db, protocol_sha, cem_validation_plan(protocol, selection, live_sha))
        control_seed0 = int(protocol["seedBases"]["controlValidation"])
        candidate_controls = run_control_sweep(
            db, protocol_sha, candidate_sha, "validation", control_seed0, 128)
        live_controls = run_control_sweep(
            db, protocol_sha, live_sha, "validation", control_seed0, 128)
        controls_analysis = analyse_controls(
            candidate_controls["runs"], live_controls["runs"], "validation")
        arm2 = float(controls_analysis["grids"]["duskblade:v5"]["winRates"]["2"])
        validation = analyse_repertoire_validation(
            candidate_output["rows"], live_output["rows"], selection,
            arm2, protocol, "validation", 5)
        clear = holdout_faults == 0 and controls_analysis["decision"] == "admit-controls" \
            and validation["decision"] == "admit-repertoire"
        analysis = {
            "schemaVersion": 1, "stage": "cem-repertoire",
            "cem": cem_readout,
            "selectionSha256": sha(canonical(selection).encode()),
            "cemHoldoutFaults": holdout_faults,
            "controlsDecision": controls_analysis["decision"],
            "finalValidation": validation,
            "decision": "admit-cem-repertoire" if clear else "reject",
        }
        runner_sha = file_sha(Path(__file__))
        analysis["runnerSha256"] = runner_sha
        analysis_sha, analysis_path = cache_json(analysis)
        record(db, "analysis", f"{args.command}:{protocol_sha}:{runner_sha}", {
            **analysis, "analysisSha256": analysis_sha,
        })
        print(json.dumps({
            "analysis": str(analysis_path), "analysisSha256": analysis_sha,
            "decision": analysis["decision"],
            "rows": sum(len(output["holdout"]) for output in cem_outputs)
                    + len(candidate_output["rows"]) + len(live_output["rows"]),
        }, sort_keys=True))
        return
    if args.command == "finalist-frozen-repertoire":
        selection_analysis_sha = str(
            protocol["candidate"]["provenance"]["frozenSelectionAnalysisSha256"])
        selection_path = CACHE / f"{selection_analysis_sha}.json"
        if not selection_path.is_file() or file_sha(selection_path) != selection_analysis_sha:
            raise RuntimeError("missing or corrupt frozen selection analysis")
        selection_analysis = json.loads(selection_path.read_text())
        selection = selection_analysis["selected"]
        expected_selection_sha = str(
            protocol["candidate"]["provenance"]["frozenSelectionSha256"])
        if sha(canonical(selection).encode()) != expected_selection_sha:
            raise RuntimeError("frozen repertoire selection drift")
        candidate_sha = protocol["immutableInputs"]["candidateContentSha256"]
        live_sha = protocol["immutableInputs"]["liveContentSha256"]
        control_seed0 = int(protocol["seedBases"][f"control{args.split.title()}"])
        candidate_controls = run_control_sweep(
            db, protocol_sha, candidate_sha, args.split, control_seed0, 64)
        live_controls = run_control_sweep(
            db, protocol_sha, live_sha, args.split, control_seed0, 64)
        controls_analysis = analyse_controls(
            candidate_controls["runs"], live_controls["runs"], args.split)
        grids: dict[str, Any] = {}
        total_rows = 0
        for vow in (0, 5):
            candidate_output = run_plan(db, protocol_sha, repertoire_validation_plan(
                protocol, selection, candidate_sha, args.split, vow))
            live_output = run_plan(db, protocol_sha, repertoire_validation_plan(
                protocol, selection, live_sha, args.split, vow))
            arm2 = float(
                controls_analysis["grids"][f"duskblade:v{vow}"]["winRates"]["2"])
            grids[f"duskblade:v{vow}"] = analyse_repertoire_validation(
                candidate_output["rows"], live_output["rows"], selection,
                arm2, protocol, args.split, vow)
            total_rows += len(candidate_output["rows"]) + len(live_output["rows"])
        expected_control = "continue-to-validation" if args.split == "discovery" \
            else "admit-controls"
        clear = controls_analysis["decision"] == expected_control \
            and all(grid["decision"] == "admit-repertoire" for grid in grids.values())
        decision = (("continue-to-validation" if args.split == "discovery"
                     else "admit-frozen-repertoire") if clear else "reject")
        analysis = {
            "schemaVersion": 1, "stage": "frozen-repertoire", "split": args.split,
            "selectionAnalysisSha256": selection_analysis_sha,
            "selectionSha256": expected_selection_sha,
            "controlsDecision": controls_analysis["decision"],
            "grids": grids, "decision": decision,
        }
        runner_sha = file_sha(Path(__file__))
        analysis["runnerSha256"] = runner_sha
        analysis_sha, analysis_path = cache_json(analysis)
        record(db, "analysis", f"{args.command}:{protocol_sha}:{args.split}:{runner_sha}", {
            **analysis, "analysisSha256": analysis_sha,
        })
        print(json.dumps({
            "analysis": str(analysis_path), "analysisSha256": analysis_sha,
            "decision": decision, "rows": total_rows,
        }, sort_keys=True))
        return
    if args.command in ("finalist-repertoire-screen", "finalist-repertoire-validation"):
        screen_output = run_plan(db, protocol_sha, repertoire_screen_plan(protocol))
        screen_analysis = analyse_repertoire_screen(screen_output["rows"], protocol)
        if args.command == "finalist-repertoire-screen" or screen_analysis["decision"] == "reject":
            runner_sha = file_sha(Path(__file__))
            screen_analysis["runnerSha256"] = runner_sha
            analysis_sha, analysis_path = cache_json(screen_analysis)
            record(db, "analysis", f"{args.command}:{protocol_sha}:{runner_sha}", {
                **screen_analysis, "analysisSha256": analysis_sha,
            })
            print(json.dumps({
                "analysis": str(analysis_path), "analysisSha256": analysis_sha,
                "decision": screen_analysis["decision"], "rows": len(screen_output["rows"]),
            }, sort_keys=True))
            return
        selection = screen_analysis["selected"]
        candidate_sha = protocol["immutableInputs"]["candidateContentSha256"]
        live_sha = protocol["immutableInputs"]["liveContentSha256"]
        candidate_output = run_plan(
            db, protocol_sha, repertoire_validation_plan(protocol, selection, candidate_sha))
        live_output = run_plan(
            db, protocol_sha, repertoire_validation_plan(protocol, selection, live_sha))
        control_seed0 = int(protocol["seedBases"]["controlValidation"])
        candidate_controls = run_control_sweep(
            db, protocol_sha, candidate_sha, "validation", control_seed0, 64)
        live_controls = run_control_sweep(
            db, protocol_sha, live_sha, "validation", control_seed0, 64)
        controls_analysis = analyse_controls(
            candidate_controls["runs"], live_controls["runs"], "validation")
        arm2 = float(controls_analysis["grids"]["duskblade:v5"]["winRates"]["2"])
        analysis = analyse_repertoire_validation(
            candidate_output["rows"], live_output["rows"], selection, arm2, protocol)
        analysis["selectionSha256"] = screen_analysis["selectionSha256"]
        runner_sha = file_sha(Path(__file__))
        analysis["runnerSha256"] = runner_sha
        analysis_sha, analysis_path = cache_json(analysis)
        record(db, "analysis", f"{args.command}:{protocol_sha}:{runner_sha}", {
            **analysis, "analysisSha256": analysis_sha,
        })
        print(json.dumps({
            "analysis": str(analysis_path), "analysisSha256": analysis_sha,
            "decision": analysis["decision"],
            "rows": len(candidate_output["rows"]) + len(live_output["rows"]),
        }, sort_keys=True))
        return
    if args.command == "finalist-controls":
        control_seed0 = int(protocol.get("seedBases", {}).get(
            f"control{args.split.title()}",
            90000 if args.split == "discovery" else 91000))
        candidate_output = run_control_sweep(
            db, protocol_sha, protocol["immutableInputs"]["candidateContentSha256"],
            args.split, control_seed0, args.seeds)
        live_output = run_control_sweep(
            db, protocol_sha, protocol["immutableInputs"]["liveContentSha256"],
            args.split, control_seed0, args.seeds)
        analysis = analyse_controls(
            candidate_output["runs"], live_output["runs"], args.split)
        runner_sha = file_sha(Path(__file__))
        analysis["runnerSha256"] = runner_sha
        analysis_sha, analysis_path = cache_json(analysis)
        record(db, "analysis",
               f"{args.command}:{protocol_sha}:{args.split}:{args.seeds}:{runner_sha}", {
            **analysis, "analysisSha256": analysis_sha,
        })
        print(json.dumps({
            "analysis": str(analysis_path), "analysisSha256": analysis_sha,
            "decision": analysis["decision"],
            "rows": len(candidate_output["runs"]) + len(live_output["runs"]),
        }, sort_keys=True))
        return
    if args.command == "finalist-landscape":
        output = run_landscape_sweep(
            db, protocol_sha, protocol["immutableInputs"]["candidateContentSha256"],
            args.split, args.policies, args.seeds, protocol)
        live_output = run_landscape_sweep(
            db, protocol_sha, protocol["immutableInputs"]["liveContentSha256"],
            args.split, args.policies, args.seeds, protocol)
        control_seeds = 128 if args.split == "discovery" else 32
        control_seed0 = int(protocol["seedBases"][f"control{args.split.title()}"])
        controls_output = run_control_sweep(
            db, protocol_sha, protocol["immutableInputs"]["candidateContentSha256"],
            args.split, control_seed0, control_seeds)
        live_controls = run_control_sweep(
            db, protocol_sha, protocol["immutableInputs"]["liveContentSha256"],
            args.split, control_seed0, control_seeds)
        controls_analysis = analyse_controls(
            controls_output["runs"], live_controls["runs"], args.split)
        analysis = analyse_landscape(
            output["runs"], controls_analysis, protocol, args.split,
            args.policies == 128 and args.seeds == 16, live_output["runs"])
        runner_sha = file_sha(Path(__file__))
        analysis["runnerSha256"] = runner_sha
        analysis_sha, analysis_path = cache_json(analysis)
        record(db, "analysis",
               f"{args.command}:{protocol_sha}:{args.split}:{args.policies}:"
               f"{args.seeds}:{runner_sha}", {**analysis, "analysisSha256": analysis_sha})
        print(json.dumps({
            "analysis": str(analysis_path), "analysisSha256": analysis_sha,
            "decision": analysis["decision"], "rows": len(output["runs"]),
        }, sort_keys=True))
        return
    if args.command == "controlled":
        plan = controlled_plan(protocol, args.split, args.pairs)
    elif args.command == "panel":
        plan = panel_plan(protocol, args.split, args.pairs)
    elif args.command == "facet-controlled":
        plan = facet_controlled_plan(protocol, args.split, args.pairs)
    elif args.command == "facet-panel":
        plan = facet_panel_plan(protocol, args.split, args.pairs)
    elif args.command == "cracked-controlled":
        plan = cracked_controlled_plan(protocol, args.split, args.pairs)
    elif args.command == "cracked-panel":
        plan = cracked_panel_plan(protocol, args.split, args.pairs)
    elif args.command == "flow-controlled":
        plan = flow_controlled_plan(protocol, args.split, args.pairs)
    elif args.command == "flow-panel":
        plan = flow_panel_plan(protocol, args.split, args.pairs)
    elif args.command == "scoreline-controlled":
        plan = scoreline_controlled_plan(protocol, args.split, args.pairs)
    elif args.command == "scoreline-panel":
        plan = scoreline_panel_plan(protocol, args.split, args.pairs)
    elif args.command in ("combined-separation", "finalist-separation"):
        plan = combined_separation_plan(protocol, args.split, args.pairs)
    else:
        plan = combined_panel_plan(protocol, args.split, args.pairs)
    output = run_plan(db, protocol_sha, plan)
    if args.command == "controlled":
        analysis = analyse_controlled(output["rows"], args.split)
    elif args.command == "panel":
        analysis = analyse_panel(output["rows"], args.split)
    elif args.command == "facet-controlled":
        analysis = analyse_controlled(
            output["rows"], args.split, ("chisel", "limitBreak"),
            "facet-controlled", 42200, True,
        )
    elif args.command == "facet-panel":
        analysis = analyse_panel(
            output["rows"], args.split, ("chisel", "limitBreak"),
            "facet-panel", 42210,
        )
    elif args.command == "cracked-controlled":
        analysis = analyse_controlled(
            output["rows"], args.split, ("eclipseSlash", "warCry"),
            "cracked-controlled", 42300, True, "draw",
        )
    elif args.command == "cracked-panel":
        analysis = analyse_panel(
            output["rows"], args.split, ("eclipseSlash", "warCry"),
            "cracked-panel", 42310,
        )
    elif args.command == "flow-controlled":
        analysis = analyse_controlled(
            output["rows"], args.split, ("chisel", "limitBreak"),
            "flow-controlled", 42400, True, "draw",
        )
    elif args.command == "flow-panel":
        analysis = analyse_panel(
            output["rows"], args.split, ("chisel", "limitBreak"),
            "flow-panel", 42410,
        )
    elif args.command == "scoreline-controlled":
        analysis = analyse_controlled(
            output["rows"], args.split, ("scoreline-snap-cut",),
            "scoreline-controlled", 42500, True,
        )
    elif args.command == "scoreline-panel":
        analysis = analyse_panel(
            output["rows"], args.split, ("scoreline-snap-cut",),
            "scoreline-panel", 42510,
        )
    elif args.command in ("combined-separation", "finalist-separation"):
        analysis = analyse_combined_separation(output["rows"], args.split, protocol)
    elif args.command == "finalist-panel":
        analysis = analyse_finalist_panel(output["rows"], args.split, protocol)
    else:
        analysis = analyse_combined_panel(output["rows"], args.split, protocol)
    runner_sha = file_sha(Path(__file__))
    analysis["runnerSha256"] = runner_sha
    analysis_sha, analysis_path = cache_json(analysis)
    record(db, "analysis",
           f"{args.command}:{protocol_sha}:{args.split}:{args.pairs}:{runner_sha}", {
        **analysis, "analysisSha256": analysis_sha,
    })
    print(json.dumps({
        "analysis": str(analysis_path), "analysisSha256": analysis_sha,
        "decision": analysis["decision"], "rows": len(output["rows"]),
    }, sort_keys=True))


if __name__ == "__main__":
    main()
