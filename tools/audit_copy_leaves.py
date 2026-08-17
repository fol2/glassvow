#!/usr/bin/env python3
"""Finder pass for the #228 bilingual copy read.

Flattens every string leaf in both locale catalogues the same way
`tests/test_locale.gd` does, then reports key parity, placeholders, retired
vertical vocabulary, token drift, punctuation, and length outliers. Line-table
rows are a second player-facing corpus (hearth / waystone / loss) and are
counted separately — they are not in the 1,197-era catalogue census.

This is a finder, not a rewrite. Exit 1 only on mechanical defects (parity,
empty/placeholder, interpolation-token mismatch). Prose flags print and stay.

Usage:
    python3 tools/audit_copy_leaves.py
    python3 tools/audit_copy_leaves.py --json docs/reviews/228/audit-findings.json
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path
from statistics import median, pstdev
from typing import Any, Iterator

ROOT = Path(__file__).resolve().parents[1]
TICKET_CENSUS = 1197

# Same flatten contract as tests/test_locale.gd › _flatten_strings.
DISPLAY_LEAVES = frozenset({
    "name", "nameBare", "namePattern", "text", "desc", "label", "sub",
    "bossName", "blurb", "inscription", "mode", "deathDialogue", "resolved",
    "accepted", "final", "huntInscription", "huntName", "bought", "death",
    "itemName", "itemText", "poor", "ask", "cannot", "paid",
})
CONTENT_DOMAINS = {
    "acts": "acts", "affixes": "affixes", "arts": "arts", "aspects": "aspects",
    "boons": "boons", "cards": "cards", "deeds": "deeds", "enemies": "enemies",
    "events": "events", "omens": "omens", "potions": "potions", "quests": "quests",
    "relics": "relics", "shadeKits": "shadeKits", "status": "statuses",
    "variants": "variants", "vows": "vows",
}

ZH_HANT_ENGLISH_ALLOWLIST = frozenset({
    "ui.language.en", "ui.language.zhHant", "ui.end.unlock.header",
})
ZH_HANT_LATIN_PATH_ALLOWLIST = frozenset({
    "ui.brand.tagline", "ui.combat.lanternSub", "ui.help.lanternBody",
    "ui.lamp.artHint", "ui.credits.bodyBrand", "ui.credits.bodyGlass",
    "ui.credits.bodyCinzel", "ui.credits.bodyAlegreya", "ui.credits.bodyNoto",
    "ui.credits.bodyEngine", "ui.credits.fontLicences", "ui.credits.footer",
    "ui.credits.musicAttribution", "ui.credits.musicAttributionCount",
    "ui.credits.sfxAttribution", "ui.credits.sfxAttributionCount", "ui.language.en",
    "content.status.beacon.desc", "content.status.dex.desc",
    "content.status.emberflow.desc", "content.status.energized.desc",
    "content.status.metallicize.desc", "content.status.nightsight.desc",
    "content.status.poison.desc", "content.status.regen.desc",
    "content.status.ritual.desc", "content.status.str.desc",
    "content.status.thorns.desc", "content.status.venomous.desc",
})
# Physical-position / status-stack keeps from docs/story/06-glossary.md.
LATIN_RE = re.compile(r"[A-Za-z]")
PLACEHOLDER_RE = re.compile(
    r"\b(TODO|FIXME|XXX|TBD|WIP|lorem|ipsum|placeholder|PLACEHOLDER)\b",
    re.IGNORECASE,
)
# Word-bounded English; Chinese is substring (no word boundaries).
EN_RETIRED = (
    ("spire", re.compile(r"\bspires?\b", re.I)),
    ("climb", re.compile(r"\bclimb(?:er|ers|ing|s)?\b", re.I)),
    ("ascend", re.compile(r"\bascend(?:ed|s|ing|ancy)?\b", re.I)),
    ("summit", re.compile(r"\bsummits?\b", re.I)),
    ("above", re.compile(r"\babove\b", re.I)),
    ("upward", re.compile(r"\bupwards?\b", re.I)),
    ("stair", re.compile(r"\bstairs?\b", re.I)),
    ("tower", re.compile(r"\btowers?\b", re.I)),
    ("floor", re.compile(r"\bfloors?\b", re.I)),
)
ZH_RETIRED = (
    ("尖塔", "尖塔"),
    ("爬", "爬"),
    ("攀", "攀"),
    ("登臨", "登臨"),
    ("頂點", "頂點"),
    ("之上", "之上"),
    ("向上", "向上"),
    ("階梯", "階梯"),
    ("高塔", "高塔"),
    ("層樓", "層樓"),
)
# Physical-position keeps from docs/story/06-glossary.md (not place-as-above).
RETIRED_ALLOWLIST = frozenset({
    "ui.help.combatBody|above",
    "story.event-forgottenShrine.coda|之上",
    "pool.loss.e37|above",
})
MARKER_RE = re.compile(r"(@[^@]+@|#[^#]+#|\{[^{}]+\}|<[^>]+>|\[[^\]\n]+\])")
COLLOQUIAL_ZH = ("嘅", "唔", "喺", "嗰", "攞", "乜", "啲", "咗", "冇", "嚟", "係咁")
# Longer forms first so 它們 is not double-counted as 它.
PRONOUN_RE = re.compile(r"它們|他們|牠們|牠|它")
HALFWIDTH_PUNCT_RE = re.compile(r"[,.!?;:()]")
CJK_RE = re.compile(r"[\u3400-\u9fff]")
INTERP_RE = re.compile(r"\{([^{}]+)\}")
KNOWN_CALQUE_KEYS = (
    "content.whispers.14",
    "content.whispers.15",
    "content.whispers.17",
    "content.whispers.21",
)

SURFACE_HOSTS: dict[str, str] = {
    "ui.brand": "Title / ChoiceScreen (`application/main.gd`)",
    "ui.menu": "Title, pause, run menu",
    "ui.common": "Shared chrome (buttons, continue/leave)",
    "ui.card": "Card face chrome",
    "ui.combat": "CombatScreen + HUD piles",
    "ui.hud": "Run HUD (`presentation/combat/hud_bar.gd`)",
    "ui.keywords": "RulesText / keyword tooltips",
    "ui.lamp": "Lantern overlay",
    "ui.help": "How-to-play panel",
    "ui.hint": "Hint overlay",
    "ui.settings": "Settings panel",
    "ui.language": "Settings language row",
    "ui.credits": "Credits sheet",
    "ui.embark": "Embark / vow select",
    "ui.end": "Run-end / victory / defeat",
    "ui.dawn": "Dawn-ceremony chrome",
    "ui.event": "EventScreen chrome",
    "ui.shop": "Shop",
    "ui.rest": "Rest site",
    "ui.reward": "RewardScreen",
    "ui.map": "World map / sealed-door threshold",
    "ui.pilgrimage": "Map survey prompt",
    "ui.vigil": "VigilScreen",
    "ui.rose": "Rose Window",
    "ui.hollow": "HollowScreen (Lamplighter meetings)",
    "ui.treasure": "Treasure node",
    "ui.smoke": "Unused smoke-test leftover (no runtime host found)",
    "ui.omen": "Act-transition plate",
    "ui.rarity": "Card rarity labels",
    "ui.persistence": "Save-error dialog",
    "ui.scene": "ScenePlayer speaker labels",
    "content.acts": "Map / embark act titles (ContentDB; en bake)",
    "content.affixes": "Elite titles in combat",
    "content.arts": "Lantern Art names",
    "content.aspects": "Aspect select",
    "content.boons": "Keeper boon pick",
    "content.cards": "Card faces (en: `content/full-content.json`)",
    "content.deeds": "Vigil deeds",
    "content.enemies": "Combat nameplates / death lines",
    "content.events": "EventScreen body copy",
    "content.omens": "Omen names / text",
    "content.potions": "Phial names / text",
    "content.quests": "Vigil / Rose Window quest copy",
    "content.relics": "Relic names / text",
    "content.shadeKits": "Shade-kit names",
    "content.status": "Status tooltips",
    "content.variants": "Enemy variant names / death lines",
    "content.vows": "Embark vow list",
    "content.whispers": "Dawn whisper + Rose Window log (`Locale.whisper`)",
    "story.opening": "ScenePlayer — opening (`content/scenes.json`)",
    "story.lamplighter": "ScenePlayer — Lamplighter meetings",
    "story.dawn": "Vigil dawn-ceremony passages",
    "story.unsealing": "ScenePlayer — sixth-shard unsealing",
    "story.act4": "ScenePlayer — Act IV nodes",
    "story.finale": "ScenePlayer — finale / win / loss",
    "story.event": "EventScreen result / coda",
    "line.hearth": "DepartureStaging — Keeper hearth (`line-table`)",
    "line.waystone": "Map interstitial (`line-table`)",
    "line.loss": "Vigil defeat epitaph (`line-table`)",
    "line.death": "Quest death / closer rows (`line-table`)",
    "line.other": "Other line-table slots",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--en", type=Path, default=ROOT / "locale/en.json")
    parser.add_argument("--zh", type=Path, default=ROOT / "locale/zh-Hant.json")
    parser.add_argument("--content", type=Path, default=ROOT / "content/full-content.json")
    parser.add_argument("--lines", type=Path, default=ROOT / "content/line-table.json")
    parser.add_argument("--json", type=Path, default=None, help="write machine findings")
    return parser.parse_args()


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def path_text(parts: tuple[str, ...]) -> str:
    return ".".join(parts)


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


def prefix_of(key: str) -> str:
    if key.startswith("story.lamplighter"):
        return "story.lamplighter"
    if key.startswith("story.unsealing"):
        return "story.unsealing"
    if key.startswith("story.act4"):
        return "story.act4"
    if key.startswith("story.finale"):
        return "story.finale"
    if key.startswith("story.event"):
        return "story.event"
    if key.startswith("story.opening"):
        return "story.opening"
    if key.startswith("story.dawn"):
        return "story.dawn"
    parts = key.split(".")
    if len(parts) >= 2:
        return ".".join(parts[:2])
    return parts[0]


def family_of(key: str) -> str:
    if key.startswith("ui."):
        return "ui"
    if key.startswith("story."):
        return "story"
    if key.startswith("content.whispers"):
        return "whispers"
    if key.startswith("content."):
        return "content"
    if key.startswith("line."):
        return "line-table"
    return "other"


def word_count(text: str) -> int:
    return len(re.findall(r"[A-Za-z0-9']+", text))


def markers(value: str) -> list[str]:
    found = [match.group(0) for match in MARKER_RE.finditer(value)]
    found.sort()
    return found


def interp_names(value: str) -> set[str]:
    return set(INTERP_RE.findall(value))


def strip_markup(value: str) -> str:
    return MARKER_RE.sub("", value)


def visible_latin(value: str) -> bool:
    return LATIN_RE.search(strip_markup(value)) is not None


def display_leaves(
    value: object, path: tuple[str, ...], domain: str,
    event_root: tuple[str, ...] | None = None,
) -> Iterator[tuple[str, str]]:
    """Same overlay shapes as tools/check_locale_coverage.py."""
    if isinstance(value, dict):
        for key, child in value.items():
            key_s = str(key)
            if isinstance(child, str) and key_s in DISPLAY_LEAVES:
                yield path_text(path + (key_s,)), child
            elif domain == "cards" and key_s == "textUp" and isinstance(child, str):
                yield path_text(path + (key_s,)), child
            elif domain == "cards" and key_s == "up" and isinstance(child, dict):
                text = child.get("text")
                if isinstance(text, str):
                    yield path_text(path + ("textUp",)), text
            elif domain == "events" and key_s == "roll" and isinstance(child, list):
                for outcome in child:
                    if isinstance(outcome, dict) and isinstance(outcome.get("id"), str):
                        yield from display_leaves(
                            outcome,
                            (event_root or path) + ("rolls", str(outcome["id"])),
                            domain, event_root,
                        )
            elif isinstance(child, (dict, list)):
                yield from display_leaves(
                    child, path + (key_s,), domain, event_root)
    elif isinstance(value, list):
        parent = path[-1] if path else ""
        for index, child in enumerate(value):
            if isinstance(child, str) and parent in {
                "waystoneEchoes", "fragments", "progress", "pages", "dialogue",
            }:
                yield path_text(path + (str(index),)), child
            elif isinstance(child, (dict, list)):
                yield from display_leaves(
                    child, path + (str(index),), domain, event_root)


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


def hydrated_english(content: dict) -> dict[str, str]:
    leaves: dict[str, str] = {}
    for locale_domain, content_domain in CONTENT_DOMAINS.items():
        for row_id, row in rows(content.get(content_domain)):
            prefix = ("content", locale_domain, row_id)
            for key, value in display_leaves(row, prefix, locale_domain, prefix):
                leaves[key] = value
    return leaves


def line_table_leaves(rows_raw: Any) -> dict[str, dict[str, str]]:
    out: dict[str, dict[str, str]] = {}
    if not isinstance(rows_raw, list):
        return out
    for row in rows_raw:
        if not isinstance(row, dict):
            continue
        row_id = str(row.get("id", "")).strip()
        slot = str(row.get("slot", "")).strip()
        if not row_id:
            continue
        out[row_id] = {
            "slot": slot,
            "zh": str(row.get("zh", "")),
            "en": str(row.get("en", "")),
        }
    return out


def line_prefix(slot: str) -> str:
    if slot == "hearth":
        return "line.hearth"
    if slot == "waystone":
        return "line.waystone"
    if slot.startswith("loss") or slot == "epitaph":
        return "line.loss"
    if slot.startswith("death") or slot.startswith("closer"):
        return "line.death"
    return "line.other"


def retired_en_hits(text: str) -> list[str]:
    return [name for name, pattern in EN_RETIRED if pattern.search(text)]


def retired_zh_hits(text: str) -> list[str]:
    return [name for name, token in ZH_RETIRED if token in text]


def placeholder_hit(text: str) -> bool:
    stripped = text.strip()
    if not stripped:
        return True
    if PLACEHOLDER_RE.search(text):
        return True
    if stripped in {"...", "…", "—", "-", "n/a", "N/A"}:
        return True
    return False


def halfwidth_punct(text: str) -> bool:
    if not CJK_RE.search(text):
        return False
    remainder = strip_markup(text)
    remainder = re.sub(r"[A-Za-z0-9][A-Za-z0-9 .,_/+%-]*[A-Za-z0-9]", " ", remainder)
    return HALFWIDTH_PUNCT_RE.search(remainder) is not None


def pronoun_hits(text: str) -> list[str]:
    return PRONOUN_RE.findall(text)


def colloquial_hits(text: str) -> list[str]:
    return [token for token in COLLOQUIAL_ZH if token in text]


def length_outliers(pairs: dict[str, tuple[str, str]]) -> list[dict[str, Any]]:
    flagged: list[dict[str, Any]] = []
    by_family: dict[str, list[tuple[str, int, int]]] = defaultdict(list)
    for key, (en, zh) in pairs.items():
        by_family[family_of(key)].append((key, len(en), len(zh)))
    for family, rows_f in by_family.items():
        if len(rows_f) < 8:
            continue
        en_lens = [row[1] for row in rows_f]
        zh_lens = [row[2] for row in rows_f]
        en_med = median(en_lens) or 1
        zh_med = median(zh_lens) or 1
        en_sd = pstdev(en_lens) if len(en_lens) > 1 else 0.0
        zh_sd = pstdev(zh_lens) if len(zh_lens) > 1 else 0.0
        for key, en_n, zh_n in rows_f:
            reasons: list[str] = []
            if en_sd > 0 and en_n > en_med + 3 * en_sd and en_n >= 80:
                reasons.append(f"en {en_n}c vs {family} median {en_med:.0f}")
            if zh_sd > 0 and zh_n > zh_med + 3 * zh_sd and zh_n >= 40:
                reasons.append(f"zh {zh_n}c vs {family} median {zh_med:.0f}")
            if en_n >= 24 and zh_n >= 8:
                ratio = zh_n / en_n
                if ratio < 0.25 or ratio > 2.4:
                    reasons.append(f"zh/en char ratio {ratio:.2f}")
            if reasons:
                flagged.append({"key": key, "en_chars": en_n, "zh_chars": zh_n, "why": reasons})
    flagged.sort(key=lambda row: row["en_chars"] + row["zh_chars"], reverse=True)
    return flagged


def duplicates(leaves: dict[str, str], narrative_only: bool) -> list[dict[str, Any]]:
    grouped: dict[str, list[str]] = defaultdict(list)
    for key, value in leaves.items():
        text = value.strip()
        if len(text) < 12:
            continue
        if narrative_only and family_of(key) not in {"story", "whispers", "content", "line-table"}:
            continue
        grouped[text].append(key)
    out = [
        {"value": value, "keys": sorted(keys)}
        for value, keys in grouped.items() if len(keys) > 1
    ]
    out.sort(key=lambda row: (-len(row["keys"]), row["keys"][0]))
    return out


def bake_drift(en_locale: dict[str, str], bake: dict[str, str]) -> list[dict[str, str]]:
    drift: list[dict[str, str]] = []
    for key, bake_value in bake.items():
        locale_value = en_locale.get(key)
        if locale_value is None:
            drift.append({"key": key, "kind": "missing_in_locale_en", "bake": bake_value, "locale": ""})
        elif locale_value != bake_value:
            drift.append({"key": key, "kind": "value_mismatch", "bake": bake_value, "locale": locale_value})
    for key in sorted(set(en_locale) - set(bake)):
        if key.startswith("content.") and not key.startswith("content.whispers"):
            # locale content.* keys that are not hydrated display leaves
            continue
    return drift


def audit(
    en_bundle: dict, zh_bundle: dict, content: dict, lines_raw: Any,
) -> dict[str, Any]:
    en_leaves = flatten_strings(en_bundle)
    zh_leaves = flatten_strings(zh_bundle)
    pairs: dict[str, tuple[str, str]] = {}
    missing_zh = sorted(set(en_leaves) - set(zh_leaves))
    extra_zh = sorted(set(zh_leaves) - set(en_leaves))
    for key in sorted(set(en_leaves) & set(zh_leaves)):
        pairs[key] = (en_leaves[key], zh_leaves[key])

    empty: list[str] = []
    placeholders: list[str] = []
    copy_through: list[str] = []
    latin_zh: list[str] = []
    token_mismatch: list[dict[str, Any]] = []
    interp_mismatch: list[dict[str, Any]] = []
    trailing: list[str] = []
    punct: list[str] = []
    orthography: list[dict[str, str]] = []
    colloquial: list[dict[str, Any]] = []
    pronouns: list[dict[str, Any]] = []
    retired: list[dict[str, Any]] = []
    brackets: list[str] = []

    for key, (en, zh) in pairs.items():
        if (not en.strip() and zh.strip()) or (en.strip() and not zh.strip()):
            empty.append(key)
        if (en.strip() and placeholder_hit(en)) or (zh.strip() and placeholder_hit(zh)):
            placeholders.append(key)
        if en == zh and en.strip() and key not in ZH_HANT_ENGLISH_ALLOWLIST:
            copy_through.append(key)
        if visible_latin(zh) and key not in ZH_HANT_LATIN_PATH_ALLOWLIST:
            latin_zh.append(key)
        if markers(en) != markers(zh):
            token_mismatch.append({
                "key": key, "en": markers(en), "zh": markers(zh),
            })
        if interp_names(en) != interp_names(zh):
            interp_mismatch.append({
                "key": key,
                "en": sorted(interp_names(en)),
                "zh": sorted(interp_names(zh)),
            })
        joiner_keys = {"ui.brand.secrets", "ui.omen.prefix"}
        if key not in joiner_keys:
            if en != en.strip() or zh != zh.strip():
                trailing.append(key)
        if halfwidth_punct(zh):
            punct.append(key)
        if "著" in zh or "裡" in zh:
            orthography.append({"key": key, "forms": [
                form for form in ("著", "裡") if form in zh
            ]})
        col = colloquial_hits(zh)
        if col:
            colloquial.append({"key": key, "tokens": col, "zh": zh})
        pro = pronoun_hits(zh)
        if pro and family_of(key) in {"story", "whispers", "content"}:
            pronouns.append({"key": key, "tokens": pro, "zh": zh})
        for term in retired_en_hits(en):
            hit = f"{key}|{term}"
            if hit not in RETIRED_ALLOWLIST:
                retired.append({"key": key, "locale": "en", "term": term, "text": en})
        for term in retired_zh_hits(zh):
            hit = f"{key}|{term}"
            if hit not in RETIRED_ALLOWLIST:
                retired.append({"key": key, "locale": "zh-Hant", "term": term, "text": zh})
        if "【" in en or "【" in zh:
            brackets.append(key)

    punct_families = Counter(family_of(key) for key in punct)
    retired_keys = sorted({row["key"] for row in retired})
    prefix_counts: dict[str, int] = Counter(prefix_of(key) for key in pairs)
    surfaces: list[dict[str, Any]] = []
    for prefix, count in sorted(prefix_counts.items(), key=lambda item: (-item[1], item[0])):
        surfaces.append({
            "prefix": prefix,
            "leaves": count,
            "host": SURFACE_HOSTS.get(prefix, "unmapped — grep Locale.t / ContentDB"),
        })

    lines = line_table_leaves(lines_raw)
    line_retired: list[dict[str, Any]] = []
    line_empty: list[str] = []
    line_copy: list[str] = []
    line_slots: Counter[str] = Counter()
    for row_id, row in lines.items():
        line_slots[row["slot"] or "(blank)"] += 1
        if not row["en"].strip() and not row["zh"].strip():
            continue
        if (not row["en"].strip()) or (not row["zh"].strip()) \
                or (row["en"].strip() and placeholder_hit(row["en"])) \
                or (row["zh"].strip() and placeholder_hit(row["zh"])):
            line_empty.append(row_id)
        if row["en"] == row["zh"] and row["en"].strip():
            line_copy.append(row_id)
        for term in retired_en_hits(row["en"]):
            hit = f"{row_id}|{term}"
            if hit not in RETIRED_ALLOWLIST:
                line_retired.append({
                    "id": row_id, "slot": row["slot"], "locale": "en",
                    "term": term, "text": row["en"],
                })
        for term in retired_zh_hits(row["zh"]):
            hit = f"{row_id}|{term}"
            if hit not in RETIRED_ALLOWLIST:
                line_retired.append({
                    "id": row_id, "slot": row["slot"], "locale": "zh-Hant",
                    "term": term, "text": row["zh"],
                })

    bake = hydrated_english(content)
    locale_content = {
        key: value for key, value in en_leaves.items() if key.startswith("content.")
    }
    bake_mismatches = bake_drift(locale_content, bake)
    calques = []
    for key in KNOWN_CALQUE_KEYS:
        if key in pairs:
            calques.append({"key": key, "en": pairs[key][0], "zh": pairs[key][1]})

    en_words = sum(word_count(en) for en, _zh in pairs.values())
    narrative_keys = [key for key in pairs if family_of(key) in {"story", "whispers"}]
    ui_keys = [key for key in pairs if family_of(key) == "ui"]
    content_keys = [key for key in pairs if family_of(key) == "content"]
    family_counts: dict[str, int] = Counter(family_of(key) for key in pairs)

    mechanical = {
        "missing_zh": missing_zh,
        "extra_zh": extra_zh,
        "empty": empty,
        "placeholders": placeholders,
        "token_mismatch": token_mismatch,
        "interp_mismatch": interp_mismatch,
    }
    return {
        "census": {
            "ticket_figure": TICKET_CENSUS,
            "en_leaves": len(en_leaves),
            "zh_leaves": len(zh_leaves),
            "paired": len(pairs),
            "delta_vs_ticket": len(pairs) - TICKET_CENSUS,
            "en_words_paired": en_words,
            "families": dict(family_counts),
            "ui_leaves": len(ui_keys),
            "content_leaves": len(content_keys),
            "narrative_leaves": len(narrative_keys),
            "narrative_en_words": sum(word_count(pairs[key][0]) for key in narrative_keys),
            "ui_en_words": sum(word_count(pairs[key][0]) for key in ui_keys),
            "content_en_words": sum(word_count(pairs[key][0]) for key in content_keys),
        },
        "mechanical": mechanical,
        "copy_through": copy_through,
        "latin_zh": latin_zh,
        "trailing_whitespace": trailing,
        "halfwidth_punct_zh": punct,
        "halfwidth_punct_families": dict(punct_families),
        "orthography": orthography,
        "colloquial": colloquial,
        "pronouns": pronouns,
        "retired_locale": retired,
        "retired_keys": retired_keys,
        "placeholder_brackets": brackets,
        "duplicates_narrative": duplicates({k: pairs[k][0] for k in pairs}, True),
        "duplicates_zh_narrative": duplicates({k: pairs[k][1] for k in pairs}, True),
        "length_outliers": length_outliers(pairs),
        "known_calques": calques,
        "surfaces": surfaces,
        "line_table": {
            "rows": len(lines),
            "slots": dict(line_slots),
            "empty_or_placeholder": line_empty,
            "copy_through": line_copy,
            "retired": line_retired,
        },
        "bake": {
            "hydrated_display_leaves": len(bake),
            "locale_en_content_leaves": len(locale_content),
            "drift_sample": bake_mismatches[:40],
            "drift_count": len(bake_mismatches),
        },
        "pairs": {key: {"en": en, "zh": zh} for key, (en, zh) in pairs.items()},
    }


def mechanical_fail_count(report: dict[str, Any]) -> int:
    mech = report["mechanical"]
    return (
        len(mech["missing_zh"]) + len(mech["extra_zh"]) + len(mech["empty"])
        + len(mech["placeholders"]) + len(mech["token_mismatch"])
        + len(mech["interp_mismatch"])
    )


def print_summary(report: dict[str, Any]) -> None:
    census = report["census"]
    print(f"catalogue leaves  en={census['en_leaves']}  zh={census['zh_leaves']}  paired={census['paired']}")
    print(
        f"vs ticket 1,197: {census['delta_vs_ticket']:+d}  "
        f"(measured {census['paired']})"
    )
    print(
        "families: "
        + ", ".join(f"{name}={count}" for name, count in sorted(census["families"].items()))
    )
    print(
        f"en words (paired): {census['en_words_paired']}  "
        f"ui={census['ui_en_words']} content={census['content_en_words']} "
        f"narrative={census['narrative_en_words']}"
    )
    mech = report["mechanical"]
    print(
        "mechanical: "
        f"missing_zh={len(mech['missing_zh'])} extra_zh={len(mech['extra_zh'])} "
        f"empty={len(mech['empty'])} placeholders={len(mech['placeholders'])} "
        f"token={len(mech['token_mismatch'])} interp={len(mech['interp_mismatch'])}"
    )
    print(
        "finder: "
        f"retired_locale={len(report['retired_locale'])} keys={len(report['retired_keys'])} "
        f"copy_through={len(report['copy_through'])} "
        f"latin_zh={len(report['latin_zh'])} "
        f"trailing={len(report['trailing_whitespace'])} "
        f"halfwidth_punct={len(report['halfwidth_punct_zh'])} "
        f"({report['halfwidth_punct_families']}) "
        f"orthography={len(report['orthography'])} "
        f"colloquial={len(report['colloquial'])} "
        f"pronouns={len(report['pronouns'])} "
        f"brackets={len(report['placeholder_brackets'])} "
        f"length_outliers={len(report['length_outliers'])}"
    )
    lt = report["line_table"]
    print(
        f"line-table rows={lt['rows']} retired={len(lt['retired'])} "
        f"empty={len(lt['empty_or_placeholder'])} copy_through={len(lt['copy_through'])}"
    )
    print(
        f"bake hydrated={report['bake']['hydrated_display_leaves']} "
        f"drift={report['bake']['drift_count']}"
    )
    print("\nper-surface:")
    for row in report["surfaces"]:
        print(f"  {row['leaves']:4d}  {row['prefix']:<28}  {row['host']}")
    if report["retired_locale"]:
        print("\nretired vocabulary (locale):")
        for row in report["retired_locale"]:
            snippet = row["text"].replace("\n", " ")[:96]
            print(f"  {row['locale']:<8} {row['term']:<6} {row['key']}  {snippet}")
    if lt["retired"]:
        print("\nretired vocabulary (line-table):")
        for row in lt["retired"]:
            snippet = row["text"].replace("\n", " ")[:96]
            print(f"  {row['locale']:<8} {row['term']:<6} {row['id']} ({row['slot']})  {snippet}")
    if report["known_calques"]:
        print("\n#177 calque candidates:")
        for row in report["known_calques"]:
            print(f"  {row['key']}")
            print(f"    zh: {row['zh']}")
            print(f"    en: {row['en']}")
    if report["pronouns"]:
        print("\npronoun hits (story/content/whispers):")
        for row in report["pronouns"]:
            print(f"  {row['key']}: {row['tokens']}  {row['zh'][:80]}")
    if report["halfwidth_punct_zh"]:
        print("\nhalf-width punct in zh-Hant:")
        for key in report["halfwidth_punct_zh"]:
            print(f"  {key}")
    if report["trailing_whitespace"]:
        print("\ntrailing/leading whitespace:")
        for key in report["trailing_whitespace"]:
            print(f"  {key}")
    if mech["token_mismatch"] or mech["interp_mismatch"] or mech["missing_zh"] or mech["extra_zh"]:
        print("\nmechanical defects:")
        for key in mech["missing_zh"]:
            print(f"  MISSING_ZH {key}")
        for key in mech["extra_zh"]:
            print(f"  EXTRA_ZH {key}")
        for row in mech["token_mismatch"]:
            print(f"  TOKEN {row['key']} en={row['en']} zh={row['zh']}")
        for row in mech["interp_mismatch"]:
            print(f"  INTERP {row['key']} en={row['en']} zh={row['zh']}")


def jsonable(report: dict[str, Any]) -> dict[str, Any]:
    slim = dict(report)
    slim.pop("pairs", None)
    return slim


def main() -> int:
    args = parse_args()
    try:
        en_bundle = read_json(args.en)
        zh_bundle = read_json(args.zh)
        content = read_json(args.content)
        lines_raw = read_json(args.lines)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"audit_copy_leaves FAILED: {error}", file=sys.stderr)
        return 2
    if not isinstance(en_bundle, dict) or not isinstance(zh_bundle, dict):
        print("audit_copy_leaves FAILED: locale root is not an object", file=sys.stderr)
        return 2
    if not isinstance(content, dict):
        print("audit_copy_leaves FAILED: content root is not an object", file=sys.stderr)
        return 2
    report = audit(en_bundle, zh_bundle, content, lines_raw)
    print_summary(report)
    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(
            json.dumps(jsonable(report), ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        print(f"\nwrote {args.json}")
    fails = mechanical_fail_count(report)
    if fails:
        print(f"\nmechanical defects: {fails}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
