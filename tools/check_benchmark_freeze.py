#!/usr/bin/env python3
"""Hold the web-reference citation count at or below its frozen census.

The port detached from the benchmark on 2026-08-16 (#317). The 607 `file:line`
citations into `roguecardv2 @ 6e06911` that were already in the tree stay: they
explain 403 code sites, the commit they name cannot drift, and re-resolving them
would buy little — the divergence ledger's own audit found only 45 of 174 sampled
anchors landing in the real reference, the rest having been written against the
post-Pixi tree. Deleting them would destroy the explanation for nothing.

What must not happen is the 608th. A citation written after detachment points
into a tree nobody reads, nobody serves, and nobody checks, and it re-opens the
coupling the detachment closed.

**This gate exists because the gate it replaces could not run here.**
`tools/check_web_anchors.py` validated citations against the benchmark checkout,
so it returned "benchmark tree not found" on every CI runner and inside every git
worktree, and CLAUDE.md had to ask for it by hand. Its only remaining job was
catching a newly written wrong line — and with new citations banned outright,
counting them is enough, needs no checkout, and therefore runs where the rule is
actually broken.

Counting, not resolving, is also what makes the rule honest: a prose ban is
undone by the next copy edit. This repo has learned that twice — the retired
vertical vocabulary needed `_retired_vertical_vocabulary` before the ban held,
and a `--check-only` loop guarded the scripts for weeks while being unable to
fail.

Usage:
    tools/check_benchmark_freeze.py           # compare; exit 1 on any drift
    tools/check_benchmark_freeze.py --update  # re-baseline DOWNWARD only
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
CENSUS = REPO / "tools" / "benchmark-citations.txt"

# The reference is a web app, so its citations are the only `.js` / `.css`
# `file:line` forms the tree writes. Docs use all three dash characters between
# the ends of a range; counting only ASCII `-` would miss the `<name>.js:NNN–NNN` form.
WEB_ANCHOR = re.compile(r"[\w./-]+\.(?:js|css):\d+(?:[-–—]\d+)?")

TEXT_SUFFIXES = (".md", ".gd", ".gdshader", ".py", ".sh", ".json", ".cfg", ".godot")


def scanned_text_files() -> list[str]:
    """Tracked files, plus untracked ones git would not ignore.

    `git ls-files` alone cannot see a file before it is staged, and a brand-new
    document is exactly how forty fresh citations would arrive. Measured while
    building this gate: a new `docs/` file carrying one citation passed a tracked-
    only sweep, which is the same hole CLAUDE.md already warns about for
    `check_scripts.sh` and works around by asking the author to remember to stage
    first. Not inherited here.
    """
    seen: list[str] = []
    for extra in ([], ["--others", "--exclude-standard"]):
        out = subprocess.check_output(["git", "ls-files", "-z", *extra],
                                      cwd=REPO, text=True)
        seen += [p for p in out.split("\0") if p.endswith(TEXT_SUFFIXES)]
    return sorted(set(seen))


def census_now() -> dict[str, int]:
    counts: dict[str, int] = {}
    for rel in scanned_text_files():
        try:
            body = (REPO / rel).read_text(errors="replace")
        except OSError:
            continue
        n = len(WEB_ANCHOR.findall(body))
        if n:
            counts[rel] = n
    return counts


def census_frozen() -> dict[str, int]:
    counts: dict[str, int] = {}
    if not CENSUS.is_file():
        return counts
    for line in CENSUS.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        count, _, rel = line.partition("\t")
        counts[rel.strip()] = int(count)
    return counts


def write_census(counts: dict[str, int]) -> None:
    total = sum(counts.values())
    body = [
        "# Frozen web-reference citation census — see tools/check_benchmark_freeze.py.",
        "#",
        "# One line per file: count, tab, repo-relative path. A count may only ever",
        "# go DOWN. Raising one means writing a new citation into a benchmark this",
        "# port detached from on 2026-08-16 (#317), so `--update` refuses to do it and",
        "# the number has to be edited by hand, in a diff a reviewer can see.",
        f"#",
        f"# {total} occurrence(s) across {len(counts)} file(s).",
        "",
    ]
    body += [f"{n}\t{rel}" for rel, n in sorted(counts.items())]
    CENSUS.write_text("\n".join(body) + "\n")


def main() -> int:
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--update", action="store_true",
                    help="re-baseline the census; refuses to raise any count")
    args = ap.parse_args()

    now, frozen = census_now(), census_frozen()

    if not frozen:
        if not args.update:
            print(f"{CENSUS.relative_to(REPO)} is missing or empty — will not invent"
                  " a baseline (the same silent-pass as grading `--check-only` by"
                  " its exit code). Restore the file, or pass --update once to write"
                  " one.")
            return 1
        write_census(now)
        print(f"census written: {sum(now.values())} citation(s) in {len(now)} file(s)")
        return 0

    risen = sorted((rel, frozen.get(rel, 0), n)
                   for rel, n in now.items() if n > frozen.get(rel, 0))
    fallen = sorted((rel, frozen[rel], now.get(rel, 0))
                    for rel in frozen if now.get(rel, 0) < frozen[rel])

    if args.update:
        if risen:
            for rel, was, is_ in risen:
                print(f"{rel}  {was} → {is_}  REFUSED")
            print(f"\n--update will not raise a count. {len(risen)} file(s) gained a"
                  " citation into the detached benchmark; remove them, or edit"
                  f" {CENSUS.relative_to(REPO)} by hand and say why in the commit.")
            return 1
        write_census({rel: n for rel, n in now.items()})
        print(f"census lowered to {sum(now.values())} citation(s) in {len(now)} file(s)")
        return 0

    for rel, was, is_ in risen:
        print(f"{rel}  {was} → {is_}  NEW CITATION")
    for rel, was, is_ in fallen:
        print(f"{rel}  {was} → {is_}  removed — run --update")

    if risen:
        print(f"\n{sum(is_ - was for _, was, is_ in risen)} new web-reference"
              " citation(s). The port detached from `6e06911` on 2026-08-16 (#317):"
              " cite the port's own code, or docs/benchmark-divergence.md for what the"
              " reference used to do.")
    if fallen:
        print(f"\n{len(fallen)} file(s) hold fewer citations than the census."
              " That is the right direction — run --update to record it.")
    if risen or fallen:
        return 1
    print(f"benchmark citations frozen ({sum(now.values())} in {len(now)} file(s))")
    return 0


if __name__ == "__main__":
    sys.exit(main())
