#!/usr/bin/env python3
"""Build the bounded, deterministic #421 current-main source projection."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import tempfile
from pathlib import Path
from typing import Any


SOURCE_FILES = (
    "AGENTS.md",
    ".claude/skills/glassvow-godot/SKILL.md",
    "docs/commercial-game-delivery.md",
    "content/full-content.json",
    "domain/rules/combat.gd",
    "domain/state/combat_state.gd",
    "domain/state/player_combatant.gd",
    "domain/state/enemy_combatant.gd",
    "domain/state/card_inst.gd",
    "domain/events/event_types.gd",
    "tools/balance_pilot.gd",
    "tools/balance_policy.gd",
)

COMBAT_FUNCTIONS = (
    "draw_cards",
    "gain_embers",
    "damage_player",
    "heal_player",
    "hit_enemy",
    "gain_block_player",
    "apply_chips",
    "_shatter_enemy",
    "can_play",
    "play_card",
    "_apply_effect",
    "_apply_special",
    "end_turn",
)

POLICY_FUNCTIONS = (
    "_pick_play",
    "_combat_score",
    "_target",
    "card_score",
    "_status_value",
    "_special_value",
    "_advances_fight",
    "choose_card",
)

PROJECTION_BYTE_CEILING = 60_000
MODEL_CONTEXT_TOKEN_CEILING = 24_000


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def git(source: Path, *args: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(source), *args],
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def extract_functions(text: str, names: tuple[str, ...]) -> dict[str, list[str]]:
    lines = text.splitlines()
    starts: list[tuple[int, str]] = []
    wanted = set(names)
    for index, line in enumerate(lines):
        match = re.match(r"^(?:static )?func ([A-Za-z0-9_]+)\(", line)
        if match:
            starts.append((index, match.group(1)))
    bounds = {
        name: (start, starts[position + 1][0] if position + 1 < len(starts) else len(lines))
        for position, (start, name) in enumerate(starts)
        if name in wanted
    }
    missing = sorted(wanted - set(bounds))
    if missing:
        raise ValueError(f"missing functions: {', '.join(missing)}")
    return {name: lines[start:end] for name, (start, end) in sorted(bounds.items())}


def parse_declarations(text: str, keyword: str) -> list[dict[str, str]]:
    pattern = re.compile(
        rf"^{keyword} ([A-Za-z0-9_]+)(?:: ([^=]+?))?\s*=\s*(.*?)(?:\s+#.*)?$"
    )
    declarations: list[dict[str, str]] = []
    for line in text.splitlines():
        match = pattern.match(line)
        if match:
            declarations.append(
                {
                    "name": match.group(1),
                    "type": (match.group(2) or "").strip(),
                    "value": match.group(3).strip(),
                }
            )
    return declarations


def clean_card(card_id: str, card: dict[str, Any]) -> dict[str, Any]:
    omitted = {"name", "text", "vfx"}
    result = {"id": card_id}
    for key in sorted(card):
        if key in omitted:
            continue
        value = card[key]
        if key == "up" and isinstance(value, dict):
            value = {nested: value[nested] for nested in sorted(value) if nested not in omitted}
        result[key] = value
    return result


def content_projection(content: dict[str, Any]) -> dict[str, Any]:
    cards = content.get("cards")
    if not isinstance(cards, dict):
        raise ValueError("content cards must be an object")
    aspects = content.get("aspects")
    if not isinstance(aspects, list):
        raise ValueError("content aspects must be an array")
    aspect_projection = []
    for aspect in aspects:
        aspect_projection.append(
            {
                key: aspect[key]
                for key in ("id", "energy", "handSize", "startDeck", "startRelic")
                if key in aspect
            }
        )
    return {
        "aspects": aspect_projection,
        "cardPools": content.get("cardPools", {}),
        "cards": [clean_card(card_id, cards[card_id]) for card_id in sorted(cards)],
    }


def canonical_bytes(value: dict[str, Any]) -> bytes:
    previous = -1
    value["projectionBytes"] = 0
    while value["projectionBytes"] != previous:
        previous = value["projectionBytes"]
        encoded = (
            json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
            + "\n"
        ).encode("utf-8")
        value["projectionBytes"] = len(encoded)
    return (
        json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
        + "\n"
    ).encode("utf-8")


def build_projection(source: Path, expected_head: str, factor_path: Path) -> dict[str, Any]:
    head = git(source, "rev-parse", "HEAD")
    if head != expected_head:
        raise ValueError(f"source head mismatch: {head}")
    status = git(source, "status", "--porcelain", "--untracked-files=all")
    if status:
        raise ValueError("source checkout is not clean")

    paths = {relative: source / relative for relative in SOURCE_FILES}
    missing = [relative for relative, path in paths.items() if not path.is_file()]
    if missing:
        raise ValueError(f"missing source files: {', '.join(missing)}")

    factor_document = json.loads(factor_path.read_text(encoding="utf-8"))
    factors = factor_document.get("frozenCausalFactors", {})
    factor_projection = {
        key: factors[key] for key in ("scorelinePayoff", "afterimagePayoff")
    }

    combat_text = paths["domain/rules/combat.gd"].read_text(encoding="utf-8")
    policy_text = paths["tools/balance_pilot.gd"].read_text(encoding="utf-8")
    state_files = (
        "domain/state/combat_state.gd",
        "domain/state/player_combatant.gd",
        "domain/state/enemy_combatant.gd",
        "domain/state/card_inst.gd",
    )

    return {
        "schemaVersion": 1,
        "generatorSha256": sha256_file(Path(__file__)),
        "sourceHead": head,
        "sourceStatus": [],
        "sourceSha256": {relative: sha256_file(path) for relative, path in paths.items()},
        "factorSource": {
            "path": str(factor_path),
            "sha256": sha256_file(factor_path),
            "projection": factor_projection,
        },
        "content": content_projection(
            json.loads(paths["content/full-content.json"].read_text(encoding="utf-8"))
        ),
        "stateDeclarations": {
            relative: parse_declarations(paths[relative].read_text(encoding="utf-8"), "var")
            for relative in state_files
        },
        "eventConstants": parse_declarations(
            paths["domain/events/event_types.gd"].read_text(encoding="utf-8"), "const"
        ),
        "combatFunctions": extract_functions(combat_text, COMBAT_FUNCTIONS),
        "policyFunctions": extract_functions(policy_text, POLICY_FUNCTIONS),
        "limits": {
            "sourceFiles": len(SOURCE_FILES),
            "projectionByteCeiling": PROJECTION_BYTE_CEILING,
            "maximumModelContextTokensForJudgement": MODEL_CONTEXT_TOKEN_CEILING,
            "GodotProcesses": 0,
            "simulatorRows": 0,
            "cacheReads": 0,
            "cacheWrites": 0,
            "ledgerReads": 0,
            "ledgerWrites": 0,
            "protectedSeedRows": 0,
        },
    }


def self_test() -> None:
    sample = """var count: int = 0
const EVENT: StringName = &\"event\"
func first(x: int) -> int:
\treturn x

static func second() -> void:
\tpass
"""
    assert parse_declarations(sample, "var") == [
        {"name": "count", "type": "int", "value": "0"}
    ]
    assert parse_declarations(sample, "const") == [
        {"name": "EVENT", "type": "StringName", "value": "&\"event\""}
    ]
    functions = extract_functions(sample, ("first", "second"))
    assert functions["first"][0] == "func first(x: int) -> int:"
    assert functions["second"][-1] == "\tpass"
    assert clean_card("x", {"name": "X", "vfx": "v", "cost": 1, "up": {"text": "Y", "cost": 0}}) == {
        "id": "x",
        "cost": 1,
        "up": {"cost": 0},
    }
    encoded = canonical_bytes({"schemaVersion": 1})
    parsed = json.loads(encoded)
    assert parsed["projectionBytes"] == len(encoded)
    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory) / "projection.json"
        path.write_bytes(encoded)
        assert sha256_file(path) == sha256_bytes(encoded)
    print("PASS (5 checks)")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--source", type=Path)
    parser.add_argument("--expected-head")
    parser.add_argument("--factor-protocol", type=Path)
    parser.add_argument("--expected-factor-sha256")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    if args.self_test:
        self_test()
        return
    required = (
        args.source,
        args.expected_head,
        args.factor_protocol,
        args.expected_factor_sha256,
        args.output,
    )
    if any(value is None for value in required):
        parser.error("projection mode requires every non-self-test argument")
    if sha256_file(args.factor_protocol) != args.expected_factor_sha256:
        raise SystemExit("factor protocol SHA-256 mismatch")
    projection = build_projection(args.source, args.expected_head, args.factor_protocol)
    encoded = canonical_bytes(projection)
    if len(encoded) > PROJECTION_BYTE_CEILING:
        raise SystemExit(
            f"projection exceeds {PROJECTION_BYTE_CEILING} bytes: {len(encoded)}"
        )
    try:
        with args.output.open("xb") as handle:
            handle.write(encoded)
    except FileExistsError as error:
        raise SystemExit(f"output already exists: {args.output}") from error
    print(f"PASS projection bytes={len(encoded)} sha256={sha256_bytes(encoded)}")


if __name__ == "__main__":
    main()
