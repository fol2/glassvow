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
that the cited line falls within that symbol's body — which is the check that
catches the dangerous case, where drift has carried an anchor out of its
function and into unrelated code that still reads plausibly. That one is
reported, never auto-fixed: nothing in the document says how far the interior
line should have moved, and guessing would launder a wrong number into a
confident one.

Two limits worth knowing before trusting a green run.

**`(in symbol)` cannot see drift INSIDE a function that grew.** The check is
containment, so an anchor that was line 3 of a 20-line body and is now line 3 of
a 190-line body still passes while pointing somewhere else entirely. Measured on
2026-07-27: six citations into `application/main.gd`'s `_ready` had all moved
10-11 lines and every one passed. Containment is the check that catches an
anchor leaving its function; nothing here catches one drifting within it.

**The regex is a whitelist of citation spellings, and the docs write more than
one.** Three separate silent classes have now been found and closed — a bare
basename that went ambiguous, a path-less `:NNNN`, and the markdown-link form
whose annotation lands after the link's own closing paren. Each read as checked
and was skipped. When adding a fourth spelling to the docs, add it here first,
or it joins them.

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
# The `sym` group tolerates three spellings of the same annotation, because the
# docs use all three and a shape the regex does not know is a shape it silently
# passes. Measured on 2026-07-27: the markdown-link spelling alone was hiding
# three drifted anchors in one doc, including a `_sync_pile` citation that had
# come to rest inside `_keyframe_pop` — the precise failure this module's own
# docstring claims the symbol annotation prevents.
#
#     `enemy_view.gd:752` (`_update_shadow`)                 plain
#     [hud_bar.gd:934](../../hud_bar.gd#L934) (in `_sync_pile`)   markdown link
#     `enemy_lab.gd:1296-1304`, in `_ready`                  comma, no parens
ANCHOR = re.compile(
    r"(?P<path>[\w./-]+\.(?:" + "|".join(CODE_SUFFIXES) + r"))"
    r":(?P<start>\d+)(?:-(?P<end>\d+))?"
    r"(?P<sym>(?:\]\([^)]*\))?`?"
    r"(?:\s*\((?P<in>in\s+)?`?(?P<symbol>[A-Za-z_][\w]*)`?\)"
    r"|,\s*(?P<in2>in\s+)?`(?P<symbol2>[A-Za-z_][\w]*)`))?"
)

# The THIRD silent class, and the one that reads as the most trustworthy.
#
# A citation that drops the filename entirely — `` `:1374` (`HIT_FRAMES`) `` — is
# invisible to ANCHOR above, which needs a path with a code suffix before it will
# match anything. It carries a symbol annotation, so it looks like the checked
# form; it is checked zero times. Measured on 2026-07-27: 50 of these across
# three docs, and every one into `enemy_lab.gd` had drifted 38-75 lines while the
# run over that same doc printed "anchors OK".
#
# This repo has now been bitten by the same shape twice. The first was the bare
# basename that went ambiguous and was skipped in silence; the fix then was to
# make the skip impossible rather than to resolve it. Same fix here: a path-less
# anchor is REPORTED, never guessed at. The checker cannot know which file the
# prose meant, and inventing one would launder a citation nobody wrote.
BARE_ANCHOR = re.compile(
    r"(?<![\w./-])`:(?P<start>\d+)(?:-(?P<end>\d+))?`"
    r"(?P<sym>\s*\(`?(?:in\s+)?`?(?P<symbol>[A-Za-z_][\w]*)`?\))?"
)

# How a symbol is declared in the languages this repo actually uses. Ordered:
# the first match wins, so a `func foo` beats a later mention of `foo`.
DECLARATIONS = (
    "func {s}",
    "static func {s}",
    "const {s}",
    "var {s}",
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
        self.kind = kind          # missing | range | drift | escaped | unanchored | ambiguous
        self.detail = detail
        self.actual = actual

    def __str__(self) -> str:
        rel = self.doc.relative_to(REPO)
        return f"{rel}:{self.doc_line}  {self.kind.upper():10} {self.text} — {self.detail}"


# Directories whose files are not the subject of any citation. `.claude` earns
# its place the hard way: it holds `worktrees/`, a full second checkout of the
# tree, so every bare `enemy_view.gd:NNNN` in the docs matched TWO paths, went
# ambiguous in `resolve`, and was skipped in silence. Measured on 2026-07-27:
# 69 of the 186 citations in `docs/solutions/` were invisible, 65 of them for
# exactly this reason, and the checker reported "anchors OK" over all of them.
# A green result on an anchor nobody checked is worse than a red one.
SKIP_DIRS: set[str] = {".git", ".godot", ".claude", "addons", "_attic", "build"}


def index_repo_files() -> dict[str, list[Path]]:
    """Map bare filenames to every path that carries them.

    Docs cite both `presentation/combat/enemy_view.gd:752` and a bare
    `enemy_view.gd:697`; the bare form only resolves if the name is unique.
    """
    index: dict[str, list[Path]] = {}
    for suffix in CODE_SUFFIXES:
        for path in REPO.rglob(f"*.{suffix}"):
            # Judged on the path RELATIVE to the repo. `path.parts` is absolute,
            # so a checkout whose own location contains one of these names skips
            # its entire tree — and `.claude/worktrees/` is exactly that: every
            # lane working in a worktree indexed zero files and got a green run
            # over anchors nothing had looked at, which is the failure this set
            # was added to prevent.
            if any(part in SKIP_DIRS for part in path.relative_to(REPO).parts):
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
    for pattern in DECLARATIONS:
        needle = pattern.format(s=symbol)
        for i, line in enumerate(lines, start=1):
            stripped = line.lstrip()
            if stripped.startswith(needle) or stripped.startswith("@" ) and needle in stripped:
                return i
    # Fall back to any standalone mention, which still beats reporting nothing.
    word = re.compile(rf"\b{re.escape(symbol)}\b")
    for i, line in enumerate(lines, start=1):
        if word.search(line):
            return i
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
            for b in BARE_ANCHOR.finditer(line):
                named = b.group("symbol")
                findings.append(Finding(
                    doc, doc_line, b.group(0).strip(), "pathless",
                    "names no file, so it was never checked — write the full"
                    " repo-relative path" + (f" for `{named}`" if named else "")))
            for m in ANCHOR.finditer(line):
                cited, start = m.group("path"), int(m.group("start"))
                # Either spelling of the annotation; see ANCHOR.
                symbol = m.group("symbol") or m.group("symbol2")
                text = m.group(0).strip()

                target = resolve(cited, index)
                if target is None:
                    # Two very different reasons land here and they must not
                    # share one silent path. A name this repo does not carry at
                    # all is plausibly external (the benchmark's `src/…`) or
                    # deleted — that is the claims validator's job, not this
                    # one, so skip it. A name this repo carries MORE THAN ONCE
                    # is a citation this checker could have verified and simply
                    # declined to, and staying quiet about it is how a green
                    # run came to certify anchors nobody had looked at.
                    if len(index.get(Path(cited).name, [])) > 1:
                        findings.append(Finding(
                            doc, doc_line, text, "ambiguous",
                            f"{cited} names %d files — cite the full repo-relative path"
                            % len(index[Path(cited).name])))
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
                elif m.group("in") or m.group("in2"):
                    last = symbol_body(body, actual)
                    end = int(m.group("end") or start)
                    if not (actual <= start and end <= last):
                        findings.append(Finding(
                            doc, doc_line, text, "escaped",
                            f"`{symbol}` spans :{actual}-{last}; the anchor sits outside it"))
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
                if int(m.group("start")) != old or (
                        m.group("symbol") is None and m.group("symbol2") is None):
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
    # A hard failure of its own, and deliberately not lumped in with drift:
    # --fix cannot repair it. The doc has to name a full repo-relative path,
    # because the checker has no way to guess which same-named file was meant.
    vague = sum(1 for f in findings if f.kind == "ambiguous")
    # Same standing as `vague`, and for the same reason: --fix cannot repair it
    # and guessing the file would be worse than reporting it.
    pathless = sum(1 for f in findings if f.kind == "pathless")
    if soft:
        print(f"\n{soft} anchor(s) carry no symbol and cannot be drift-checked.")
    if vague:
        print(f"\n{vague} anchor(s) cite a bare name this repo carries more than"
              " once, so they were never checked. Cite the full repo-relative path.")
    if pathless:
        print(f"\n{pathless} anchor(s) name no file at all, so they were never"
              " checked despite carrying a symbol. Cite the full repo-relative path.")
    if drift:
        print(f"\n{drift} anchor(s) no longer point where they claim."
              " Run with --fix to re-anchor the drifted ones.")
    if drift or vague or pathless:
        return 1
    print("anchors OK" + (f" ({soft} uncheckable)" if soft else ""))
    return 1 if (args.strict and soft) else 0


if __name__ == "__main__":
    sys.exit(main())
