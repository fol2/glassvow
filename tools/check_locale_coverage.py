#!/usr/bin/env python3
"""Reject narrative copy that resolves through another locale at runtime.

English ContentDB display copy comes from content/full-content.json; zh-Hant
hydrates only the matching fields from locale/zh-Hant.json.  Comparing the two
locale bundles alone therefore misses a zh leaf omitted from the hydration
bundle.  Whispers and future story scripts are direct locale lookups, so they
are compared bundle-to-bundle instead.

Run normally for the repository, or use --self-test to prove that missing zh,
missing en, and banned en-to-zh copy-through each produce a non-zero child run.
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Iterator

ROOT = Path(__file__).resolve().parents[1]
DISPLAY_LEAVES = frozenset({
    "name", "nameBare", "namePattern", "text", "desc", "label", "sub",
    "bossName", "blurb", "inscription", "mode", "deathDialogue", "resolved",
    "accepted", "final", "huntInscription", "huntName", "bought", "death",
    "itemName", "itemText", "poor", "ask", "cannot", "paid",
})
DISPLAY_STRING_ARRAYS = frozenset({"floorEchoes", "fragments", "progress", "pages", "dialogue"})
CONTENT_DOMAINS = {
    "acts": "acts", "affixes": "affixes", "arts": "arts", "aspects": "aspects",
    "boons": "boons", "cards": "cards", "deeds": "deeds", "enemies": "enemies",
    "events": "events", "omens": "omens", "potions": "potions", "quests": "quests",
    "relics": "relics", "shadeKits": "shadeKits", "status": "statuses",
    "variants": "variants", "vows": "vows",
}
# Narrative copy has no legitimate byte-for-byte English carry-over.  Any future
# exception must name its exact canonical path and justify it in the reviewing PR.
COPY_THROUGH_ALLOWLIST = frozenset()
# Domains that carry display-named leaves but were measured unrendered on
# 2026-08-16: `themes` is loaded (content_db.gd:266) and never read for display
# text — act names and bossName render from the hydrated `acts` domain; and
# `content.player` has no accessor (code reads game.run.player, the run state).
# A domain listed here that later grows a rendered string moves to
# CONTENT_DOMAINS; every other unmapped domain is scanned and fails closed.
AUDITED_NON_DISPLAY = frozenset({"themes", "player"})


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--content", type=Path, default=ROOT / "content/full-content.json")
    parser.add_argument("--en", type=Path, default=ROOT / "locale/en.json")
    parser.add_argument("--zh", type=Path, default=ROOT / "locale/zh-Hant.json")
    parser.add_argument("--self-test", action="store_true", help="prove the three failure classes")
    return parser.parse_args()


def read_json(path: Path) -> dict:
    parsed = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(parsed, dict):
        raise ValueError(f"{path}: expected a JSON object")
    return parsed


def path_text(path: tuple[str, ...]) -> str:
    return ".".join(path)


def rows(value: object) -> Iterator[tuple[str, dict]]:
    if isinstance(value, dict):
        for key, row in value.items():
            if isinstance(row, dict):
                yield str(key), row
    elif isinstance(value, list):
        for index, row in enumerate(value):
            if isinstance(row, dict):
                row_id = row.get("id")
                yield str(row_id) if isinstance(row_id, str) else str(index), row


def display_leaves(value: object, path: tuple[str, ...], domain: str,
        event_root: tuple[str, ...] | None = None) -> Iterator[tuple[tuple[str, ...], str]]:
    """Yield canonical locale paths for hydrated ContentDB strings.

    This mirrors Locale._overlay_node's two non-isomorphic shapes: card upgrade
    text is textUp in locale JSON, and event roll outcomes are keyed by roll id.
    """
    if isinstance(value, dict):
        for key, child in value.items():
            key_s = str(key)
            if isinstance(child, str) and key_s in DISPLAY_LEAVES:
                yield path + (key_s,), child
            elif domain == "cards" and key_s == "textUp" and isinstance(child, str):
                yield path + (key_s,), child
            elif domain == "cards" and key_s == "up" and isinstance(child, dict):
                text = child.get("text")
                if isinstance(text, str):
                    yield path + ("textUp",), text
            elif domain == "events" and key_s == "roll" and isinstance(child, list):
                for outcome in child:
                    if isinstance(outcome, dict) and isinstance(outcome.get("id"), str):
                        yield from display_leaves(outcome,
                            (event_root or path) + ("rolls", outcome["id"]), domain, event_root)
            elif isinstance(child, (dict, list)):
                yield from display_leaves(child, path + (key_s,), domain, event_root)
    elif isinstance(value, list):
        parent = path[-1] if path else ""
        for index, child in enumerate(value):
            index_s = str(index)
            if isinstance(child, str) and parent in DISPLAY_STRING_ARRAYS:
                yield path + (index_s,), child
            elif isinstance(child, (dict, list)):
                yield from display_leaves(child, path + (index_s,), domain, event_root)


def hydrated_english(content: dict) -> dict[str, str]:
    leaves: dict[str, str] = {}
    for locale_domain, content_domain in CONTENT_DOMAINS.items():
        for row_id, row in rows(content.get(content_domain)):
            prefix = ("content", locale_domain, row_id)
            for path, value in display_leaves(row, prefix, locale_domain, prefix):
                leaves[path_text(path)] = value
    return leaves


def hydrated_zh(zh: dict) -> dict[str, str]:
    leaves: dict[str, str] = {}
    content = zh.get("content")
    if not isinstance(content, dict):
        return leaves
    for domain, _content_domain in CONTENT_DOMAINS.items():
        for row_id, row in rows(content.get(domain)):
            prefix = ("content", domain, row_id)
            for path, value in display_leaves(row, prefix, domain, prefix):
                leaves[path_text(path)] = value
    return leaves


def flatten_strings(value: object, path: tuple[str, ...] = ()) -> dict[str, str]:
    found: dict[str, str] = {}
    if isinstance(value, str):
        found[path_text(path)] = value
    elif isinstance(value, dict):
        for key, child in value.items():
            found.update(flatten_strings(child, path + (str(key),)))
    elif isinstance(value, list):
        for index, child in enumerate(value):
            found.update(flatten_strings(child, path + (str(index),)))
    return found


def direct_narrative(locale: dict) -> dict[str, str]:
    found = flatten_strings(locale.get("story", {}), ("story",))
    content = locale.get("content")
    if isinstance(content, dict):
        found.update(flatten_strings(content.get("whispers", []), ("content", "whispers")))
    return found


def compare_pair(en: dict[str, str], zh: dict[str, str], errors: list[str]) -> None:
    for path in sorted(en.keys() - zh.keys()):
        errors.append(f"MISSING_ZH {path}")
    for path in sorted(zh.keys() - en.keys()):
        errors.append(f"MISSING_EN {path}")
    for path in sorted(en.keys() & zh.keys()):
        if en[path] == zh[path] and en[path].strip() and path not in COPY_THROUGH_ALLOWLIST:
            errors.append(f"COPY_THROUGH {path}")


def uncovered_domains(content: dict, errors: list[str]) -> None:
    """Fail closed on any content domain the mapping does not cover.

    A domain added to content/full-content.json that carries display-leaf
    strings must be mapped in CONTENT_DOMAINS or audited in
    AUDITED_NON_DISPLAY, or this gate cannot see its missing translations.
    """
    covered = set(CONTENT_DOMAINS.values()) | AUDITED_NON_DISPLAY
    for domain in sorted(content.keys()):
        if domain in covered:
            continue
        for path, _value in display_leaves(content[domain], (domain,), domain):
            errors.append(
                f"UNCOVERED_DOMAIN {path_text(path)} — map {domain!r} in "
                "CONTENT_DOMAINS or audit it in AUDITED_NON_DISPLAY")
            break


def check(content_path: Path, en_path: Path, zh_path: Path) -> tuple[list[str], tuple[int, int, int]]:
    content = read_json(content_path)
    en = read_json(en_path)
    zh = read_json(zh_path)
    hydrated_en = hydrated_english(content)
    hydrated_zh_leaves = hydrated_zh(zh)
    direct_en = direct_narrative(en)
    direct_zh = direct_narrative(zh)
    errors: list[str] = []
    uncovered_domains(content, errors)
    compare_pair(hydrated_en, hydrated_zh_leaves, errors)
    compare_pair(direct_en, direct_zh, errors)
    return errors, (len(hydrated_en), len(direct_en), len(direct_zh))


def fixture(root: Path) -> tuple[Path, Path, Path]:
    content = root / "content.json"
    en = root / "en.json"
    zh = root / "zh.json"
    content.write_text(json.dumps({"cards": {"sample": {"name": "English narrative"}}}), encoding="utf-8")
    en.write_text(json.dumps({"content": {"whispers": ["English whisper"]}, "story": {"opening": "English story"}}), encoding="utf-8")
    zh.write_text(json.dumps({"content": {"cards": {"sample": {"name": "中文敘事"}}, "whispers": ["中文低語"]}, "story": {"opening": "中文故事"}}), encoding="utf-8")
    return content, en, zh


def self_test() -> int:
    with tempfile.TemporaryDirectory(prefix="glassvow-locale-coverage-") as temp:
        root = Path(temp)
        content, en, zh = fixture(root)
        for label in ("missing zh leaf", "missing en leaf", "copy-through", "uncovered domain"):
            case_dir = root / label.replace(" ", "-")
            case_dir.mkdir()
            files = [case_dir / "content.json", case_dir / "en.json", case_dir / "zh.json"]
            for source, destination in zip((content, en, zh), files):
                shutil.copyfile(source, destination)
            if label == "copy-through":
                data = json.loads(files[2].read_text(encoding="utf-8"))
                data["content"]["cards"]["sample"]["name"] = "English narrative"
                files[2].write_text(json.dumps(data), encoding="utf-8")
            elif label == "uncovered domain":
                data = json.loads(files[0].read_text(encoding="utf-8"))
                data["vessels"] = {"relic": {"name": "English lore"}}
                files[0].write_text(json.dumps(data), encoding="utf-8")
            else:
                target = files[2] if label == "missing zh leaf" else files[0]
                data = json.loads(target.read_text(encoding="utf-8"))
                if label == "missing zh leaf":
                    data["content"]["cards"]["sample"].pop("name")
                else:
                    data["cards"]["sample"].pop("name")
                target.write_text(json.dumps(data), encoding="utf-8")
            result = subprocess.run(
                [sys.executable, str(Path(__file__).resolve()), "--content", str(files[0]), "--en", str(files[1]), "--zh", str(files[2])],
                capture_output=True, text=True, check=False,
            )
            if result.returncode == 0:
                print(f"locale coverage self-test FAILED: {label} was accepted", file=sys.stderr)
                return 1
            detail = next((line for line in result.stderr.splitlines() if line.startswith(("MISSING_", "COPY_", "UNCOVERED_"))), "no diagnostic")
            print(f"self-test {label}: rejected (exit {result.returncode}; {detail})")
    print("locale coverage self-test OK (4 seeded defects rejected)")
    return 0


def main() -> int:
    args = parse_args()
    if args.self_test:
        return self_test()
    try:
        errors, counts = check(args.content, args.en, args.zh)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"locale coverage FAILED: {error}", file=sys.stderr)
        return 2
    if errors:
        print(f"locale coverage FAILED ({len(errors)} issue(s))", file=sys.stderr)
        print("\n".join(errors), file=sys.stderr)
        return 1
    hydrated, en_direct, zh_direct = counts
    print(f"locale coverage OK ({hydrated} hydrated leaves; {en_direct}/{zh_direct} direct narrative leaves)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
