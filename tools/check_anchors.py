#!/usr/bin/env python3
"""Verify that `file:line` anchors in docs/ still point where they claim.

Six lanes move `presentation/` concurrently, so a line number written today is
routinely wrong by tomorrow: a refresh on 2026-07-26 found 14 of 15 anchors in
one cluster had drifted within hours of being written. Every one had been
correct at its own shipping commit. Discipline does not fix this — the anchors
are snapshots of a moving target — so it is checked mechanically instead.

The failure that matters is not the dead link. It is the anchor that still
resolves and now points at plausible, unrelated code: a reader lands in the
right file, on the right kind of line, and is misled. That is what a symbol
annotation prevents.

    enemy_view.gd:768 (_update_shadow)      # the line IS the declaration
    reward_embers.gd:379-383 (in _draw_shard)  # the line is INSIDE that function

The two forms are checked differently, because only the first has a single
right answer. A bare `(symbol)` asserts the cited line is where the symbol is
declared: verifiable, and repairable with --fix. An `(in symbol)` asserts only
that the cited line falls within that symbol's span — its `##` doc block plus
its body, because the ported spec lives in the commentary here and citing it is
the point, not an accident — which is the check that
catches the dangerous case, where drift has carried an anchor out of its
function and into unrelated code that still reads plausibly. That one is
reported, never auto-fixed: nothing in the document says how far the interior
line should have moved, and guessing would launder a wrong number into a
confident one.

Usage:
    tools/check_anchors.py            # report; exit 1 if anything drifted
    tools/check_anchors.py --fix      # rewrite drifted line numbers in place
    tools/check_anchors.py --strict   # also fail on anchors lacking a symbol
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DOCS = ["docs", "CONCEPTS.md", "AGENTS.md"]

# Only these extensions are treated as anchors, so ports (`:8765`), times
# (`12:30`) and ratios (`1/255`) are never mistaken for one.
CODE_SUFFIXES = ("gd", "gdshader", "tscn", "py", "sh", "json", "cfg", "godot")

# path.ext:N  |  path.ext:N-M  |  either followed by  (symbol)
#
# The optional trailing backtick matters: prose writes the anchor as its own
# code span and the symbol as the next one — `enemy_view.gd:752` (`_update_shadow`)
# — so the closing backtick sits between the two and must be allowed through.
ANCHOR = re.compile(
    r"(?P<path>[\w./-]+\.(?:" + "|".join(CODE_SUFFIXES) + r"))"
    r":(?P<start>\d+)(?:-(?P<end>\d+))?"
    r"(?P<sym>`?\s*\((?P<in>in\s+)?`?(?P<symbol>[A-Za-z_][\w]*)`?\))?"
)

# How a symbol is declared in the languages this repo actually uses. Ordered:
# the first match wins, so a `func foo` beats a later mention of `foo`.
DECLARATIONS = (
    "func {s}",
    "static func {s}",
    "const {s}",
    "var {s}",
    "static var {s}",
    "@export var {s}",
    "class {s}",
    "class_name {s}",
    "signal {s}",
    "enum {s}",
    "uniform float {s}",
    "uniform vec2 {s}",
    "uniform vec3 {s}",
    "uniform vec4 {s}",
    "{s}(",
)


class Finding:
    def __init__(self, doc: Path, doc_line: int, text: str, kind: str, detail: str,
                 actual: int | None = None):
        self.doc = doc
        self.doc_line = doc_line
        self.text = text
        self.kind = kind          # missing | range | drift | escaped | unanchored
        self.detail = detail
        self.actual = actual

    def __str__(self) -> str:
        rel = self.doc.relative_to(REPO)
        return f"{rel}:{self.doc_line}  {self.kind.upper():10} {self.text} — {self.detail}"


def index_repo_files() -> dict[str, list[Path]]:
    """Map bare filenames to every path that carries them.

    Docs cite both `presentation/combat/enemy_view.gd:752` and a bare
    `enemy_view.gd:697`; the bare form only resolves if the name is unique.
    """
    index: dict[str, list[Path]] = {}
    for suffix in CODE_SUFFIXES:
        for path in REPO.rglob(f"*.{suffix}"):
            if any(part in {".git", ".godot", "addons", "_attic"} for part in path.parts):
                continue
            index.setdefault(path.name, []).append(path)
    return index


def resolve(cited: str, index: dict[str, list[Path]]) -> Path | None:
    direct = REPO / cited
    if direct.is_file():
        return direct
    matches = index.get(Path(cited).name, [])
    if len(matches) == 1:
        return matches[0]
    # Ambiguous bare name: prefer one whose tail matches the citation.
    tail = [m for m in matches if str(m).endswith(cited)]
    return tail[0] if len(tail) == 1 else None


def symbol_head(lines: list[str], decl_line: int) -> int:
    """Return the first line of the doc block attached to `decl_line`.

    This repo carries the ported CSS spec in the `##` block above a symbol, not
    beside it, so a citation's most useful target is routinely two or three
    lines ABOVE the declaration — `enemy_view.gd:2032-2038` opens in the
    commentary that explains `_update_shadow` and runs into its body. Treating
    the declaration as the hard upper edge would call every one of those an
    escape and leave roughly seventy anchors permanently unannotatable.
    """
    base = len(lines[decl_line - 1]) - len(lines[decl_line - 1].lstrip())
    first = decl_line
    for i in range(decl_line - 1, 0, -1):
        line = lines[i - 1]
        stripped = line.lstrip()
        if not stripped.startswith("#"):
            break
        if len(line) - len(stripped) != base:
            break
        first = i
    return first


def symbol_body(lines: list[str], decl_line: int) -> int:
    """Return the last line of the block opened at `decl_line` (1-based).

    Ends at the next line with no more indentation than the declaration —
    good enough for GDScript and shader source, which is all this repo holds.
    """
    base = len(lines[decl_line - 1]) - len(lines[decl_line - 1].lstrip())
    for i in range(decl_line, len(lines)):
        line = lines[i]
        if not line.strip():
            continue
        if len(line) - len(line.lstrip()) <= base:
            return i
    return len(lines)


def find_symbol(lines: list[str], symbol: str) -> int | None:
    """Return the 1-based line where `symbol` is declared, or None."""
    # A bare prefix test makes `_rng` match `var _rng_seed` and `_process` match
    # `func _process_hit` — the anchor then resolves to a neighbour and passes,
    # which is the silent half of the failure this script exists to catch.
    def hit(stripped: str, needle: str) -> bool:
        if not stripped.startswith(needle):
            return False
        rest = stripped[len(needle):]
        return not (rest[:1].isalnum() or rest[:1] == "_")

    for pattern in DECLARATIONS:
        needle = pattern.format(s=symbol)
        for i, line in enumerate(lines, start=1):
            stripped = line.lstrip()
            if hit(stripped, needle) or (stripped.startswith("@") and needle in stripped):
                return i
    # A shader function leads with its return type — `void fragment()`,
    # `vec3 screen(...)` — so no prefix in DECLARATIONS can ever reach one, and
    # the fallback below then resolves the name to whichever line mentions it
    # first. The type list is spelled out rather than left as `\w+` so that a
    # GDScript `return foo(...)` cannot pass for a declaration of `foo`.
    shader = re.compile(
        r"^(?:void|bool|int|uint|float|double|[biud]?vec[234]|mat[234](?:x[234])?"
        r"|sampler\w*)\s+" + re.escape(symbol) + r"\s*\(")
    for i, line in enumerate(lines, start=1):
        if shader.match(line.lstrip()):
            return i

    # No fall back to "any line that mentions the name". It reported something
    # for every symbol, including ones the file never declares, and what it
    # returned was routinely a call site or a string: `view.set_profile(...)`
    # satisfied `(in set_profile)` in a file declaring no such symbol, and the
    # `.tscn` inside a path literal satisfied a citation annotated `(tscn)`.
    # An anchor whose symbol cannot be located is now reported as missing,
    # which is the honest answer and the one this script exists to give.
    return None


def check(strict: bool) -> tuple[list[Finding], dict[Path, list[tuple[int, int]]]]:
    index = index_repo_files()
    findings: list[Finding] = []
    # doc -> [(old_start, new_start)] for --fix
    repairs: dict[Path, list[tuple[int, int]]] = {}

    targets: list[Path] = []
    for entry in DOCS:
        p = REPO / entry
        if p.is_dir():
            targets.extend(sorted(p.rglob("*.md")))
        elif p.is_file():
            targets.append(p)

    for doc in targets:
        for doc_line, line in enumerate(doc.read_text().splitlines(), start=1):
            for m in ANCHOR.finditer(line):
                cited, start = m.group("path"), int(m.group("start"))
                symbol = m.group("symbol")
                text = m.group(0).strip()

                target = resolve(cited, index)
                if target is None:
                    # A doc may legitimately cite an external or deleted path;
                    # those are the claims validator's job, not this one.
                    continue

                body = target.read_text(errors="replace").splitlines()
                if start > len(body):
                    findings.append(Finding(doc, doc_line, text, "range",
                                            f"{cited} has {len(body)} lines"))
                    continue

                if symbol is None:
                    if strict:
                        findings.append(Finding(doc, doc_line, text, "unanchored",
                                                "no (symbol) — drift cannot be detected"))
                    continue

                actual = find_symbol(body, symbol)
                if actual is None:
                    findings.append(Finding(doc, doc_line, text, "missing",
                                            f"symbol `{symbol}` not found in {cited}"))
                elif m.group("in"):
                    first = symbol_head(body, actual)
                    last = symbol_body(body, actual)
                    end = int(m.group("end") or start)
                    if not (first <= start and end <= last):
                        findings.append(Finding(
                            doc, doc_line, text, "escaped",
                            f"`{symbol}` spans :{first}-{last}; the anchor sits outside it"))
                elif actual != start:
                    findings.append(Finding(doc, doc_line, text, "drift",
                                            f"`{symbol}` is at :{actual}", actual))
                    repairs.setdefault(doc, []).append((start, actual))

    return findings, repairs


def apply_fixes(repairs: dict[Path, list[tuple[int, int]]]) -> int:
    fixed = 0
    for doc, pairs in repairs.items():
        text = doc.read_text()
        for old, new in pairs:
            # Rewrite only inside an anchor, never a bare number elsewhere.
            def sub(m: re.Match) -> str:
                if int(m.group("start")) != old or m.group("symbol") is None:
                    return m.group(0)
                end = m.group("end")
                span = f"-{int(end) + (new - old)}" if end else ""
                return f"{m.group('path')}:{new}{span}{m.group('sym')}"
            text, n = ANCHOR.subn(sub, text)
            fixed += 1 if n else 0
        doc.write_text(text)
    return fixed


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--fix", action="store_true", help="rewrite drifted line numbers")
    ap.add_argument("--strict", action="store_true",
                    help="also fail on anchors that carry no (symbol)")
    args = ap.parse_args()

    findings, repairs = check(args.strict)

    if args.fix and repairs:
        n = apply_fixes(repairs)
        print(f"re-anchored {n} citation(s); re-run to confirm")
        findings = [f for f in findings if f.kind != "drift"]

    for f in findings:
        print(f)

    drift = sum(1 for f in findings if f.kind in {"drift", "missing", "range", "escaped"})
    soft = sum(1 for f in findings if f.kind == "unanchored")
    if soft:
        print(f"\n{soft} anchor(s) carry no symbol and cannot be drift-checked.")
    if drift:
        print(f"\n{drift} anchor(s) no longer point where they claim."
              " Run with --fix to re-anchor the drifted ones.")
        return 1
    print("anchors OK" + (f" ({soft} uncheckable)" if soft else ""))
    return 1 if (args.strict and soft) else 0


if __name__ == "__main__":
    sys.exit(main())
