#!/usr/bin/env python3
"""Fail when a locale character is absent from every bundled text fallback.

This is intentionally a cmap gate, rather than a rendered screenshot check: it
runs in CI before a glyph can reach a player as tofu.  It reads ``locale/*.json``
and checks the actual woff2 assets committed under ``assets/fonts``.  Pass a
``--extra-char`` only for the required mutation proof; it is not used by CI.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

try:
    from fontTools.ttLib import TTFont
except ImportError as error:
    print(
        "FontTools is required; bootstrap /private/tmp/glassvow-fonttools as "
        "documented in tools/subset_noto_serif_tc.py.",
        file=sys.stderr,
    )
    raise SystemExit(2) from error


REPO_ROOT = Path(__file__).resolve().parents[1]
LOCALE_DIR = REPO_ROOT / "locale"
TEXT_FONTS = (
    REPO_ROOT / "assets/fonts/NotoSerifTC-Regular.woff2",
    REPO_ROOT / "assets/fonts/NotoSerifTC-SemiBold.woff2",
    REPO_ROOT / "assets/fonts/NotoSerifTC-Black.woff2",
    REPO_ROOT / "assets/fonts/NotoSansSymbols2-Glassvow.woff2",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--extra-char",
        action="append",
        default=[],
        help="add one or more characters to the checked corpus (mutation proof only)",
    )
    return parser.parse_args()


def describe(character: str) -> str:
    return f"{character!r} (U+{ord(character):04X})"


def load_coverage() -> set[int]:
    coverage: set[int] = set()
    for font_path in TEXT_FONTS:
        if not font_path.is_file():
            raise RuntimeError(f"bundled subset is missing: {font_path.relative_to(REPO_ROOT)}")
        font = TTFont(font_path)
        coverage.update(font.getBestCmap())
    return coverage


def locale_characters(extra: list[str]) -> set[str]:
    paths = sorted(LOCALE_DIR.glob("*.json"))
    if not paths:
        raise RuntimeError(f"no locale JSON files found in {LOCALE_DIR}")
    characters: set[str] = set()
    for path in paths:
        characters.update(json_string_characters(path))
    for value in extra:
        characters.update(value)
    return characters


def json_string_characters(path: Path) -> set[str]:
    """Check authored strings, not JSON indentation or line terminators."""
    characters: set[str] = set()

    def visit(value: object) -> None:
        if isinstance(value, str):
            # Newlines/tabs control layout, never select a visible glyph.
            characters.update(character for character in value if ord(character) >= 0x20)
        elif isinstance(value, dict):
            for key, item in value.items():
                visit(key)
                visit(item)
        elif isinstance(value, list):
            for item in value:
                visit(item)

    visit(json.loads(path.read_text(encoding="utf-8")))
    return characters


def main() -> int:
    args = parse_args()
    characters = locale_characters(args.extra_char)
    coverage = load_coverage()
    missing = sorted(character for character in characters if ord(character) not in coverage)
    if missing:
        print("locale font coverage FAILED", file=sys.stderr)
        print("missing: " + ", ".join(describe(character) for character in missing), file=sys.stderr)
        return 1
    print(
        "locale font coverage OK "
        f"({len(characters)} locale characters, {len(TEXT_FONTS)} bundled subsets)"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError) as error:
        print(f"locale font coverage FAILED: {error}", file=sys.stderr)
        raise SystemExit(2)
