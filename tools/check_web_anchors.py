#!/usr/bin/env python3
"""Verify that web-reference `file:line` citations still point where they claim.

Glassvow cites the pre-Pixi benchmark (roguecardv2 @ 6e06911) from docs and from
presentation / application / domain comments — `styles.css:834`,
`src/ui/drain.js:511-512`, bare `mesh.js:928`. Those line numbers rot the same
way Godot anchors do, and the failure that matters is the same: a citation that
still resolves, into the right file, onto a plausible and wrong line.

`tools/check_anchors.py` owns `.gd` (and other in-repo) anchors. This script
owns the web half: every `*.js` / `*.css` citation whose path resolves under the
benchmark's `src/`. It range-checks the line, then — when the citing prose
names a backticked token nearby — asks whether that token still appears near
the cite (±20, with a longer look-back for `case` / `function` headers). No
usable token in the target file means range-check only; a token that lives
elsewhere in the same file is DRIFT.

False positives are worse than misses. The token window is deliberately soft,
and a citation with no usable token is never failed for content.

Usage:
    tools/check_web_anchors.py           # report; exit 1 if anything drifted
    tools/check_web_anchors.py --list    # every citation, OK included
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
BENCHMARK = REPO.parent / "roguecardv2-benchmark"
PINNED_COMMIT = "6e06911"

# path.ext:N  |  path.ext:N-M  — hyphen, en-dash, or em-dash between the ends.
# Docs write all three; treating only ASCII `-` would silently skip the
# assembly plan's `combat.js:215–257` form.
WEB_ANCHOR = re.compile(
    r"(?P<path>[\w./-]+\.(?:js|css))"
    r":(?P<start>\d+)(?:[-–—](?P<end>\d+))?"
)

# Backtick spans that are not themselves a web citation. The citation is also
# usually backticked, so it has to be filtered out before it is treated as a
# content token.
BACKTICK = re.compile(r"`([^`]+)`")

# Words that appear in backticks as units or filler and never identify a site
# in the reference. Prefer a miss over calling these DRIFT.
NOISE = frozenset({
    "the", "a", "an", "of", "to", "in", "on", "for", "and", "or", "is", "at",
    "by", "as", "it", "be", "if", "so", "no", "vs", "via", "per", "not",
    "px", "ms", "em", "rem", "vh", "vw", "deg", "rad", "s", "hz", "db",
    "true", "false", "null", "undefined", "var", "let", "const", "function",
    "return", "new", "this", "that", "with", "from", "into", "over", "under",
    "then", "than", "also", "only", "same", "both", "each", "all", "any",
    "css", "js", "dom", "api", "url", "id", "ok", "na", "n/a",
    # Too common in both CSS and prose to locate a cite: a `scale` token on a
    # drain.js line matches the nearest `transform: scale` dozens of lines away.
    "scale", "show", "hide", "add", "remove", "set", "get", "name", "type",
    "color", "width", "height", "left", "right", "top", "size", "text",
    "font-weight", "battlefield", "saturate", "brightness", "opacity",
    "settimeout", "touppercase", "float", "pin", "intent", "raw", "origin",
    "cubic-bezier", "transform", "animation", "transition", "pow", "sin", "cos",
})


class Finding:
    def __init__(self, doc: Path, doc_line: int, text: str, kind: str, detail: str):
        self.doc = doc
        self.doc_line = doc_line
        self.text = text
        self.kind = kind  # ok | drift | missing | out-of-range | ambiguous
        self.detail = detail

    def __str__(self) -> str:
        rel = self.doc.relative_to(REPO)
        return (f"{rel}:{self.doc_line}  {self.kind.upper():12} "
                f"{self.text} — {self.detail}")


def abort(msg: str) -> int:
    print(f"check_web_anchors: {msg}", file=sys.stderr)
    return 2


def verify_benchmark(root: Path) -> str | None:
    """Return an error message if the benchmark pin is wrong, else None."""
    if not root.is_dir():
        return f"benchmark tree not found at {root}"
    try:
        # %H, not %h: git's auto-abbrev length grows with the object count, so
        # an abbreviated HEAD stops matching a fixed-width PINNED_COMMIT.
        head = subprocess.check_output(
            ["git", "-C", str(root), "log", "-1", "--format=%H"],
            text=True,
        ).strip()
    except (subprocess.CalledProcessError, FileNotFoundError) as e:
        return f"cannot read benchmark HEAD at {root}: {e}"
    if not head.startswith(PINNED_COMMIT):
        return (f"benchmark at {root} is {head}, expected {PINNED_COMMIT}."
                " Aborting — citations are pinned to the pre-Pixi reference.")
    return None


def git_ls(*paths: str) -> list[Path]:
    out = subprocess.check_output(
        ["git", "ls-files", "-z", *paths], cwd=REPO, text=True,
    )
    return [REPO / p for p in out.split("\0") if p]


def scan_targets() -> list[Path]:
    """Docs + root contract files, and the three layers that cite the web ref."""
    docs = [p for p in git_ls("docs", "CLAUDE.md", "CONCEPTS.md")
            if p.suffix == ".md"]
    code = git_ls("presentation", "application", "domain")
    code = [p for p in code if p.suffix == ".gd"]
    return sorted(docs + code)


def index_src(root: Path) -> dict[str, list[Path]]:
    """Map bare filenames under benchmark `src/` to their full paths."""
    src = root / "src"
    index: dict[str, list[Path]] = {}
    if not src.is_dir():
        return index
    for path in src.rglob("*"):
        if path.suffix in {".js", ".css"} and path.is_file():
            index.setdefault(path.name, []).append(path)
    return index


def resolve(cited: str, root: Path, index: dict[str, list[Path]]) -> Path | None | str:
    """Resolve a cited path into the benchmark `src/` tree.

    Returns a Path on success, the string `"ambiguous"` when a bare name hits
    more than one file, or None when the citation does not resolve under `src/`
    at all (external, typo, or not a web ref we own — skipped, not failed).
    """
    cited = cited.lstrip("./")
    # Strip a leading repo-name prefix some docs write:
    # `roguecardv2-benchmark src/ui/drain.js:587`
    for prefix in ("roguecardv2-benchmark/", "roguecardv2/"):
        if cited.startswith(prefix):
            cited = cited[len(prefix):]

    direct = root / cited
    if direct.is_file():
        try:
            direct.relative_to(root / "src")
        except ValueError:
            return None
        return direct

    # Bare or partial: unique basename under src/, or a unique tail match.
    matches = index.get(Path(cited).name, [])
    if not matches:
        return None
    if len(matches) == 1:
        return matches[0]
    tail = [m for m in matches if str(m).replace("\\", "/").endswith(cited)]
    if len(tail) == 1:
        return tail[0]
    return "ambiguous"


# A content token is an identifier or CSS selector — not an expression, not a
# commit hash, not a query string. Multi-cite lines share one backtick soup
# (`idleSway` next to both combat.js and styles.css); expressions and foreign
# tokens have to drop out or every sibling cite becomes a false MISSING.
_TOKEN_OK = re.compile(
    r"^[A-Za-z_][\w:-]*$"          # ident, CONSTANT, idle-sway, ::after after strip
    r"|^[A-Za-z_][\w-]*(?:\.[A-Za-z_][\w-]*)+$"  # dotted: lantern.snuff, schip.pop
)


def clean_token(raw: str) -> str | None:
    """Turn a backticked span into a match needle, or None if it is noise."""
    tok = raw.strip()
    if not tok or WEB_ANCHOR.search(tok):
        return None
    # Filenames, paths, HTML, and query strings are not content tokens.
    if "/" in tok or "?" in tok or "<" in tok or tok.endswith(
            (".js", ".css", ".gd", ".tscn", ".json", ".md", ".png")):
        return None
    # Strip a leading CSS/DOM sigil, then anything from an open paren onward
    # so `V.hitstop(110)` and `.enemy.doomed` both become useful needles.
    tok = tok.lstrip(".#")
    if "(" in tok:
        tok = tok.split("(", 1)[0]
    # Pseudo-elements arrive as `combat-screen::after` — keep one leading run.
    tok = tok.strip().rstrip(".,;:!?")
    if not tok or len(tok) < 2:
        return None
    if tok.isdigit() or re.fullmatch(r"\d+(\.\d+)?", tok):
        return None
    # Git SHAs and bare hex colours show up in backticks around citations.
    if re.fullmatch(r"[0-9a-f]{6,}", tok, re.I):
        return None
    if tok.lower() in NOISE:
        return None
    # Spaces / operators ⇒ expression (`H = 820`, `z <= -7`). Drop it.
    if any(c in tok for c in " =<>*+[]{}'\","):
        return None
    # `L.classList.add` / `x.root.classList.add` match every classList site.
    if "classList" in tok or tok.count(".") > 2:
        return None
    if not _TOKEN_OK.match(tok):
        return None
    return tok


def context_tokens(lines: list[str], line_idx: int) -> list[str]:
    """Backticked tokens on the citing line and up to two lines above it.

    Stops at a blank line so a new paragraph does not donate tokens. Order is
    preserved; duplicates are dropped.
    """
    chunks: list[str] = []
    for back in range(0, 3):
        i = line_idx - back
        if i < 0:
            break
        text = lines[i]
        if back > 0 and not text.strip():
            break
        chunks.append(text)
    seen: set[str] = set()
    out: list[str] = []
    for text in chunks:
        for m in BACKTICK.finditer(text):
            tok = clean_token(m.group(1))
            if tok and tok not in seen:
                seen.add(tok)
                out.append(tok)
    return out


def token_needles(tok: str) -> list[str]:
    """Match forms for one token, softest last.

    Full token first. For dotted selectors (`lantern.snuff`, `enemy.doomed`)
    also try the final segment — the drain site that adds `'snuff'` is still
    the right cite for `#lantern.snuff`, and failing it is a false positive.
    """
    needles = [tok]
    if "." in tok:
        last = tok.rsplit(".", 1)[-1]
        if (len(last) > 1 and last.lower() not in NOISE
                and re.search(r"[A-Za-z_]", last)):
            needles.append(last)
    return needles


def find_nearest(lines: list[str], tok: str, around: int) -> int | None:
    """1-based line nearest to `around` where any needle for `tok` appears."""
    needles = token_needles(tok)
    best: int | None = None
    best_dist: int | None = None
    for i, line in enumerate(lines, start=1):
        if any(n in line for n in needles):
            dist = abs(i - around)
            if best_dist is None or dist < best_dist:
                best, best_dist = i, dist
    return best


def is_block_header(line: str, tok: str) -> bool:
    """True when `line` opens a function / case / keyframes / rule for `tok`.

    A call site (`weather = makePoints(...)`) is not a header — accepting those
    would bless a cite that sits below an unrelated call of the same name.
    """
    s = line.strip()
    for n in token_needles(tok):
        if re.match(r"(?:async\s+)?function\s+" + re.escape(n) + r"\b", s):
            return True
        if re.match(r"(?:const|let|var)\s+" + re.escape(n) + r"\s*=", s):
            return True
        if re.match(r"case\s+['\"]" + re.escape(n) + r"['\"]\s*:", s):
            return True
        if s.startswith("@keyframes ") and n in s.split():
            return True
        # CSS rule opener: `.enemy.hurt` / `#lantern.snuff` / `.block-chip.pulse`
        if s.startswith((".", "#")) and n in s and s.rstrip().endswith("{"):
            return True
    return False


# ±20 around the cite, plus a longer look-back for block headers. A cite into
# `case 'hitEnemy': { … }` routinely sits 30–50 lines below the label that
# carries the only occurrence of the token; the look-back treats that as still
# on-site. A look-forward stays tight — a token that only appears later is the
# classic wrong-line failure.
WINDOW = 20
BLOCK_LOOKBACK = 80


def window_has_token(lines: list[str], start: int, end: int, tokens: list[str]) -> bool:
    lo = max(1, start - WINDOW)
    hi = min(len(lines), end + WINDOW)
    text = "\n".join(lines[lo - 1:hi])
    for tok in tokens:
        if any(n in text for n in token_needles(tok)):
            return True
    # Preceding block header within LOOKBACK.
    block_lo = max(1, start - BLOCK_LOOKBACK)
    for tok in tokens:
        for i in range(start - 1, block_lo - 2, -1):
            if i < 0:
                break
            if is_block_header(lines[i], tok):
                return True
    return False


def tokens_in_file(lines: list[str], tokens: list[str]) -> list[str]:
    """Subset of tokens that appear anywhere in the reference file.

    A multi-cite line hands every sibling the same backtick soup. Tokens that
    never occur in THIS file are almost always meant for another cite on the
    same line (or for the Godot side) — content-checking them is how a green
    styles.css cite made its combat.js neighbour MISSING for `idleSway`.
    """
    body = "\n".join(lines)
    return [t for t in tokens if any(n in body for n in token_needles(t))]


def check(root: Path, listing: bool) -> list[Finding]:
    index = index_src(root)
    # Cache file bodies; many citations share a file.
    bodies: dict[Path, list[str]] = {}
    findings: list[Finding] = []

    for doc in scan_targets():
        try:
            lines = doc.read_text(errors="replace").splitlines()
        except OSError as e:
            findings.append(Finding(doc, 0, str(doc.name), "missing",
                                    f"cannot read citing file: {e}"))
            continue

        for doc_line, line in enumerate(lines, start=1):
            for m in WEB_ANCHOR.finditer(line):
                cited = m.group("path")
                start = int(m.group("start"))
                end = int(m.group("end") or start)
                text = m.group(0)

                target = resolve(cited, root, index)
                if target is None:
                    continue
                if target == "ambiguous":
                    n = len(index.get(Path(cited).name, []))
                    findings.append(Finding(
                        doc, doc_line, text, "ambiguous",
                        f"{cited} names {n} files under src/ — cite src/… path"))
                    continue

                if target not in bodies:
                    bodies[target] = target.read_text(errors="replace").splitlines()
                body = bodies[target]
                nlines = len(body)

                if start < 1 or end < start or start > nlines or end > nlines:
                    findings.append(Finding(
                        doc, doc_line, text, "out-of-range",
                        f"{cited} has {nlines} lines"))
                    continue

                tokens = context_tokens(lines, doc_line - 1)
                present = tokens_in_file(body, tokens) if tokens else []
                if not present:
                    # No usable token in this file: range-check only. Spec
                    # MISSING is reserved for the rare case below where a
                    # present token somehow evaporates between the two scans.
                    if listing:
                        why = ("in range (no token to content-check)" if not tokens
                               else "in range (nearby tokens not in this file)")
                        findings.append(Finding(doc, doc_line, text, "ok", why))
                    continue

                if window_has_token(body, start, end, present):
                    if listing:
                        findings.append(Finding(
                            doc, doc_line, text, "ok",
                            f"token(s) {', '.join(f'`{t}`' for t in present[:3])} nearby"))
                    continue

                # Pick the token whose nearest hit is closest to the cite —
                # reporting the first context token was blaming the wrong name
                # when a secondary token sat nearer.
                best_tok, best_near, best_dist = present[0], None, None
                for tok in present:
                    near = find_nearest(body, tok, start)
                    if near is None:
                        continue
                    dist = min(abs(near - start), abs(near - end))
                    if best_dist is None or dist < best_dist:
                        best_tok, best_near, best_dist = tok, near, dist
                if best_near is None:
                    findings.append(Finding(
                        doc, doc_line, text, "missing",
                        f"`{best_tok}` not found in {cited}"))
                else:
                    findings.append(Finding(
                        doc, doc_line, text, "drift",
                        f"`{best_tok}` nearest at :{best_near}"))

    return findings


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--list", action="store_true",
                    help="print every citation, including OK")
    ap.add_argument("--benchmark", type=Path, default=BENCHMARK,
                    help=f"benchmark checkout (default: {BENCHMARK})")
    args = ap.parse_args()

    err = verify_benchmark(args.benchmark)
    if err:
        return abort(err)

    findings = check(args.benchmark, args.list)

    problems = [f for f in findings if f.kind != "ok"]
    show = findings if args.list else problems
    for f in show:
        print(f)

    # --list alone still exits non-zero when problems exist.
    counts = {k: 0 for k in ("ok", "drift", "missing", "out-of-range", "ambiguous")}
    # When not listing, OK rows were never appended — recount from a full pass
    # only for the summary when --list was requested.
    for f in findings:
        counts[f.kind] = counts.get(f.kind, 0) + 1

    hard = sum(counts[k] for k in ("drift", "missing", "out-of-range", "ambiguous"))
    if hard:
        print(f"\n{hard} web-reference citation(s) no longer point where they claim.")
        return 1
    if args.list:
        print(f"web-reference anchors OK ({counts['ok']} citation(s))")
    else:
        print("web-reference anchors OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
