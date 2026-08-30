#!/usr/bin/env python3
"""Build the bounded #421 enemy-action source projection."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import time
from pathlib import Path
from typing import Any


EXPECTED_HEAD = "5f53020f588145ec5fbf803de32d82c7d29c06d2"
SOURCE_HASHES = {
    "domain/rules/combat.gd": "3adb0e063a536bf249d3b5d9524427facf1398304206da59d97594d3fff246e8",
    "domain/state/enemy_combatant.gd": "f689c34f580b70f798c2337feecf8a666eb69a378b2bd213161ba919e09776b7",
    "domain/rules/enemy_ai.gd": "30a20a1f60b0c53ce7d68405ab5bde551e42820928a2a3d4925c52148e59c417",
    "domain/events/event_types.gd": "445a68f3887baa87b2d666ab4c9d380fba6d9d56fffb1bef13e6016dbc83903a",
    "tools/balance_pilot.gd": "4ff5934fc03af84e9d0c8fb285a91c6b7d5dfcab180b88825b1e75bb47ea6c47",
    "presentation/combat/combat_screen.gd": "312d66afa344c441724cc4abe1e87889fb0f9b66637dc8eed4f6ef44c6137542",
    "presentation/combat/intent_chip.gd": "fc147f6b762d7bb1f9c9a1c0bfca32024bf60038e4f059474c8b017c0c5a4ac7",
    "content/full-content.json": "a0d608a5142d2e3aab799cdf33d3163922b402c2aaf2a895e46e096399b56cf1",
    "CONCEPTS.md": "463f986857c72cbeb6ce84e216c41c25d776502596294437f8213bf88c905ac5",
    "docs/commercial-game-delivery.md": "00537bcdd314d884b318f0720c2a8a79cc1f3f4bc03452fa8ad75f46f2a08bec",
}
BYTE_CAP = 90_000
WALL_CAP_SECONDS = 30


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def git(source: Path, *args: str) -> str:
    return subprocess.run(
        ["git", "-C", str(source), *args], check=True, capture_output=True, text=True
    ).stdout.strip()


def validate_source(source: Path) -> dict[str, str]:
    require(git(source, "rev-parse", "HEAD") == EXPECTED_HEAD, "source head mismatch")
    require(git(source, "status", "--porcelain", "--untracked-files=all") == "", "source dirty")
    observed: dict[str, str] = {}
    for relative, expected in SOURCE_HASHES.items():
        value = sha256((source / relative).read_bytes())
        require(value == expected, f"source hash mismatch: {relative}")
        observed[relative] = value
    return observed


def extract_functions(text: str, names: tuple[str, ...]) -> dict[str, list[str]]:
    lines = text.splitlines()
    starts: list[tuple[int, str]] = []
    for index, line in enumerate(lines):
        match = re.match(r"^(?:static )?func ([A-Za-z0-9_]+)\(", line)
        if match:
            starts.append((index, match.group(1)))
    wanted = set(names)
    bounds = {
        name: (start, starts[position + 1][0] if position + 1 < len(starts) else len(lines))
        for position, (start, name) in enumerate(starts)
        if name in wanted
    }
    require(set(bounds) == wanted, f"missing functions: {sorted(wanted - set(bounds))}")
    return {name: lines[start:end] for name, (start, end) in sorted(bounds.items())}


def extract_heading(text: str, heading: str) -> list[str]:
    lines = text.splitlines()
    start = lines.index(heading)
    prefix = heading.split(" ", 1)[0] + " "
    end = next(
        (index for index in range(start + 1, len(lines)) if lines[index].startswith(prefix)),
        len(lines),
    )
    return lines[start:end]


def extract_event_branches(text: str, labels: tuple[str, ...]) -> dict[str, list[str]]:
    lines = text.splitlines()
    starts: list[tuple[int, str]] = []
    pattern = re.compile(r"^\t\t(EventTypes\.[A-Z_]+):$")
    for index, line in enumerate(lines):
        match = pattern.match(line)
        if match and match.group(1) in labels:
            starts.append((index, match.group(1)))
    require([label for _, label in starts] == list(labels), "presentation branch mismatch")
    result: dict[str, list[str]] = {}
    for start, label in starts:
        end = next(
            (
                index
                for index in range(start + 1, len(lines))
                if re.match(r'^\t\t(?:EventTypes\.[A-Z_]+|&"[^"]+"):$', lines[index])
            ),
            len(lines),
        )
        result[label] = lines[start:end]
    return result


def parse_declarations(text: str, keyword: str) -> list[dict[str, str]]:
    pattern = re.compile(rf"^{keyword} ([A-Za-z0-9_]+)(?:: ([^=]+?))?\s*=\s*(.*?)(?:\s+#.*)?$")
    return [
        {"name": match.group(1), "type": (match.group(2) or "").strip(), "value": match.group(3).strip()}
        for line in text.splitlines()
        if (match := pattern.match(line))
    ]


def clean_move(move: dict[str, Any]) -> dict[str, Any]:
    keys = ("intent", "dmg", "times", "block", "heal", "ramp", "fx", "addCards")
    return {key: move[key] for key in keys if key in move}


def project_content(content: dict[str, Any]) -> dict[str, Any]:
    enemies = content.get("enemies")
    encounters = content.get("encounters")
    require(isinstance(enemies, dict), "enemies must be an object")
    require(isinstance(encounters, list), "encounters must be an array")
    enemy_moves = {
        enemy_id: {
            move_id: clean_move(move)
            for move_id, move in sorted(enemy.get("moves", {}).items())
        }
        for enemy_id, enemy in sorted(enemies.items())
    }
    multi_enemy_groups: list[dict[str, Any]] = []
    for act_index, act in enumerate(encounters):
        require(isinstance(act, dict), "encounter act must be an object")
        for tier in sorted(act):
            for group_index, group in enumerate(act[tier]):
                if len(group) > 1:
                    multi_enemy_groups.append(
                        {"act": act_index + 1, "tier": tier, "index": group_index, "enemies": group}
                    )
    return {
        "enemyMoves": enemy_moves,
        "enemyCount": len(enemy_moves),
        "moveCount": sum(len(moves) for moves in enemy_moves.values()),
        "multiEnemyGroups": multi_enemy_groups,
        "multiEnemyGroupCount": len(multi_enemy_groups),
    }


def canonical_bytes(value: dict[str, Any]) -> bytes:
    previous = -1
    value["projectionBytes"] = 0
    while value["projectionBytes"] != previous:
        previous = value["projectionBytes"]
        encoded = (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode()
        value["projectionBytes"] = len(encoded)
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode()


def self_test(source: Path) -> None:
    sample = """var count: int = 0
const EVENT: StringName = &"event"
func first() -> void:
\tpass

func second() -> void:
\tpass
"""
    assert list(extract_functions(sample, ("first", "second"))) == ["first", "second"]
    assert extract_heading("### A\none\n### B\ntwo\n", "### A") == ["### A", "one"]
    branches = extract_event_branches(
        "\t\tEventTypes.INTENT:\n\t\t\tpass\n\t\tEventTypes.STAGGERED:\n\t\t\tpass\n\t\tEventTypes.ENEMY_ACT:\n\t\t\tpass\n\t\tEventTypes.DIE:\n\t\t\tpass\n",
        ("EventTypes.INTENT", "EventTypes.STAGGERED", "EventTypes.ENEMY_ACT"),
    )
    assert list(branches) == ["EventTypes.INTENT", "EventTypes.STAGGERED", "EventTypes.ENEMY_ACT"]
    assert parse_declarations(sample, "var") == [{"name": "count", "type": "int", "value": "0"}]
    projected = project_content(
        {"enemies": {"a": {"moves": {"x": {"name": "X", "dmg": 2}}}}, "encounters": [{"normal": [["a", "a"], ["a"]]}]}
    )
    assert projected["enemyMoves"] == {"a": {"x": {"dmg": 2}}}
    assert projected["multiEnemyGroupCount"] == 1
    encoded = canonical_bytes({"schemaVersion": 1})
    assert json.loads(encoded)["projectionBytes"] == len(encoded)
    assert len(validate_source(source)) == len(SOURCE_HASHES)
    print("PASS (8 checks)")


def build(source: Path) -> dict[str, Any]:
    source_hashes = validate_source(source)
    combat = (source / "domain/rules/combat.gd").read_text(encoding="utf-8")
    enemy_state = (source / "domain/state/enemy_combatant.gd").read_text(encoding="utf-8")
    enemy_ai = (source / "domain/rules/enemy_ai.gd").read_text(encoding="utf-8")
    event_types = (source / "domain/events/event_types.gd").read_text(encoding="utf-8")
    policy = (source / "tools/balance_pilot.gd").read_text(encoding="utf-8")
    screen = (source / "presentation/combat/combat_screen.gd").read_text(encoding="utf-8")
    chip = (source / "presentation/combat/intent_chip.gd").read_text(encoding="utf-8")
    concepts = (source / "CONCEPTS.md").read_text(encoding="utf-8")
    commercial = (source / "docs/commercial-game-delivery.md").read_text(encoding="utf-8")
    content = json.loads((source / "content/full-content.json").read_text(encoding="utf-8"))
    return {
        "schemaVersion": 1,
        "generatorSha256": sha256(Path(__file__).read_bytes()),
        "sourceHead": EXPECTED_HEAD,
        "sourceStatus": [],
        "sourceSha256": source_hashes,
        "enemyStateDeclarations": parse_declarations(enemy_state, "var"),
        "enemyStateFunctions": extract_functions(enemy_state, ("move", "to_dict")),
        "eventConstants": parse_declarations(event_types, "const"),
        "combatFunctions": extract_functions(combat, ("_compute_intents", "end_turn", "preview_enemy_dmg")),
        "enemyAiFunctions": extract_functions(enemy_ai, ("decide",)),
        "policyFunctions": extract_functions(policy, ("_pick_play", "_combat_score", "_target", "_incoming")),
        "presentationBranches": extract_event_branches(
            screen, ("EventTypes.INTENT", "EventTypes.STAGGERED", "EventTypes.ENEMY_ACT")
        ),
        "intentChipFunctions": extract_functions(chip, ("primary", "accent_for", "icons_for", "set_intent", "telegraph")),
        "conceptIntent": extract_heading(concepts, "### Intent"),
        "commercialSections": {
            heading: extract_heading(commercial, heading)
            for heading in (
                "## 1. Save Versioning & Migration Policy",
                "## 3. Determinism Contract",
                "## 4. Content-ID Stability",
                "## 6. Release Gates & Stop Conditions",
            )
        },
        "content": project_content(content),
        "limits": {
            "sourceFiles": len(SOURCE_HASHES),
            "projectionByteCap": BYTE_CAP,
            "wallTimeSeconds": WALL_CAP_SECONDS,
            "GodotProcesses": 0,
            "simulatorRows": 0,
            "cacheReads": 0,
            "cacheWrites": 0,
            "ledgerReads": 0,
            "ledgerWrites": 0,
            "protectedSeedRows": 0,
        },
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument("--self-test", action="store_true")
    action.add_argument("--build", action="store_true")
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    if args.self_test:
        self_test(args.source)
        return
    require(args.output is not None, "--output is required for --build")
    require(not args.output.exists(), "refusing to overwrite projection")
    started = time.monotonic()
    projection = build(args.source)
    encoded = canonical_bytes(projection)
    require(len(encoded) <= BYTE_CAP, "projection byte cap exceeded")
    require(time.monotonic() - started <= WALL_CAP_SECONDS, "projection wall cap exceeded")
    with args.output.open("xb") as handle:
        handle.write(encoded)
    print(json.dumps({"status": "PASS", "bytes": len(encoded), "sha256": sha256(encoded), "wallTimeSeconds": round(time.monotonic() - started, 6)}, sort_keys=True))


if __name__ == "__main__":
    main()
