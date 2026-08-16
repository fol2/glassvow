#!/usr/bin/env python3
"""Build the shipped Noto Serif TC and symbol fallback subsets.

Inputs are deliberately not committed.  The three static CJK OTFs come from
notofonts/noto-cjk Serif2.003's language-specific Traditional Chinese archive:

  https://github.com/notofonts/noto-cjk/releases/download/Serif2.003/10_NotoSerifCJKtc.zip

The archive contains ``OTF/TraditionalChinese/NotoSerifCJKtc-<weight>.otf``.
Each selected source is SHA-256 pinned below, so a successful build never
silently changes fonts when the download endpoint is replaced.  Noto Sans
Symbols2 comes from the official Symbols2 v2.008 release, likewise pinned.

Bootstrap FontTools outside the checkout (do not install into system Python):

  python3 -m venv /private/tmp/glassvow-fonttools
  /private/tmp/glassvow-fonttools/bin/pip install 'fonttools[woff]>=4.63,<4.64'
  PATH=/private/tmp/glassvow-fonttools/bin:$PATH tools/subset_noto_serif_tc.py

The corpus is all characters in ``locale/*.json``, the inline ``zh`` strings in
``content/line-table.json``, plus printable ASCII.  It is
sorted before it reaches pyftsubset; given these pinned sources and FontTools,
the woff2 output is deterministic and may be regenerated in place.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
import sys
import tempfile
import urllib.request
import zipfile
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
LOCALE_DIR = REPO_ROOT / "locale"
LINE_TABLE = REPO_ROOT / "content" / "line-table.json"
OUTPUT_DIR = REPO_ROOT / "assets" / "fonts"
DEFAULT_SOURCE_DIR = Path("/private/tmp/glassvow-noto-serif-tc-sources")

CJK_ARCHIVE_URL = (
    "https://github.com/notofonts/noto-cjk/releases/download/Serif2.003/"
    "10_NotoSerifCJKtc.zip"
)
SYMBOL_ARCHIVE_URL = (
    "https://github.com/notofonts/symbols/releases/download/"
    "NotoSansSymbols2-v2.008/NotoSansSymbols2-v2.008.zip"
)
SYMBOL_ARCHIVE_SHA256 = "346c930bbe8eb946701a05c54e9c11a2094dee1d93c387bf1771c0a3e335688f"

# These are source-file checksums from the official Serif2.003 release, not
# checksums of a local cache archive.  They pin exactly the files pyftsubset
# consumes even if a release mirror repacks its zip container.
CJK_SOURCES: dict[str, tuple[str, str, str]] = {
    "Regular": (
        "NotoSerifCJKtc-Regular.otf",
        "234301038e76e7c35c43113785024700c4e4fe7bdce1d1fbbc42fca7e6683798",
        "NotoSerifTC-Regular.woff2",
    ),
    "SemiBold": (
        "NotoSerifCJKtc-SemiBold.otf",
        "422e868b6a983caa3a661f6580295fbaf00f26694087e86810fa58577e9be27a",
        "NotoSerifTC-SemiBold.woff2",
    ),
    "Black": (
        "NotoSerifCJKtc-Black.otf",
        "3ad2c936d8757c8c4d661394592a40d29bd66351d0e6971310f19b159d380db7",
        "NotoSerifTC-Black.woff2",
    ),
}
SYMBOL_SOURCE_NAME = "NotoSansSymbols2-Regular.ttf"
SYMBOL_OUTPUT_NAME = "NotoSansSymbols2-Glassvow.woff2"
# The two production locale glyphs are U+2726 and U+2B24.  U+2B2D is retained
# because the design ticket spells the second marker that way; it costs one
# glyph and makes either authored spelling deterministic.
SYMBOL_TEXT = "✦⬤⬭"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def require_sha256(path: Path, expected: str) -> None:
    actual = sha256(path)
    if actual != expected:
        raise RuntimeError(
            f"checksum mismatch for {path}: expected {expected}, got {actual}"
        )


def download(url: str, destination: Path, expected_sha256: str | None = None) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists() and expected_sha256 is not None:
        try:
            require_sha256(destination, expected_sha256)
            return
        except RuntimeError:
            destination.unlink()
    with tempfile.NamedTemporaryFile(dir=destination.parent, delete=False) as handle:
        temporary = Path(handle.name)
    try:
        print(f"download {url}")
        with urllib.request.urlopen(url) as response, temporary.open("wb") as handle:
            shutil.copyfileobj(response, handle)
        if expected_sha256 is not None:
            require_sha256(temporary, expected_sha256)
        temporary.replace(destination)
    finally:
        temporary.unlink(missing_ok=True)


def extract_matching_member(archive: Path, member_suffix: str, destination: Path) -> None:
    with zipfile.ZipFile(archive) as bundle:
        members = [name for name in bundle.namelist() if name.endswith(member_suffix)]
        if len(members) != 1:
            raise RuntimeError(
                f"expected one member ending {member_suffix!r} in {archive}, found {members}"
            )
        destination.parent.mkdir(parents=True, exist_ok=True)
        with bundle.open(members[0]) as source, destination.open("wb") as output:
            shutil.copyfileobj(source, output)


def ensure_cjk_sources(source_dir: Path) -> dict[str, Path]:
    source_dir.mkdir(parents=True, exist_ok=True)
    missing = [name for name, (filename, _, _) in CJK_SOURCES.items()
               if not (source_dir / filename).exists()]
    if missing:
        archive = source_dir / "10_NotoSerifCJKtc.zip"
        # The release's per-file SHA-256 pins are authoritative below.  The
        # vendor does not publish an archive digest alongside every asset.
        download(CJK_ARCHIVE_URL, archive)
        for weight in missing:
            filename, _, _ = CJK_SOURCES[weight]
            extract_matching_member(archive, filename, source_dir / filename)
    resolved: dict[str, Path] = {}
    for weight, (filename, expected_sha256, _) in CJK_SOURCES.items():
        source = source_dir / filename
        if not source.exists():
            raise RuntimeError(f"missing {weight} source: {source}")
        require_sha256(source, expected_sha256)
        resolved[weight] = source
    return resolved


def ensure_symbol_source(source_dir: Path) -> Path:
    source_dir.mkdir(parents=True, exist_ok=True)
    source = source_dir / SYMBOL_SOURCE_NAME
    if source.exists():
        return source
    archive = source_dir / "NotoSansSymbols2-v2.008.zip"
    download(SYMBOL_ARCHIVE_URL, archive, SYMBOL_ARCHIVE_SHA256)
    # Leading slash: "unhinted/ttf/…" also ends with "hinted/ttf/…".
    extract_matching_member(archive, f"/hinted/ttf/{SYMBOL_SOURCE_NAME}", source)
    return source


def locale_corpus() -> str:
    locale_paths = sorted(LOCALE_DIR.glob("*.json"))
    if not locale_paths:
        raise RuntimeError(f"no locale JSON files found in {LOCALE_DIR}")
    if not LINE_TABLE.is_file():
        raise RuntimeError(f"line table missing: {LINE_TABLE.relative_to(REPO_ROOT)}")
    characters = {chr(codepoint) for codepoint in range(0x20, 0x7F)}
    for locale_path in locale_paths:
        characters.update(json_string_characters(locale_path))
    characters.update(line_table_zh_characters(LINE_TABLE))
    return "".join(sorted(characters))


def json_string_characters(locale_path: Path) -> set[str]:
    """Return authored JSON-string characters, excluding indentation/newlines."""
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

    visit(json.loads(locale_path.read_text(encoding="utf-8")))
    return characters


def line_table_zh_characters(path: Path) -> set[str]:
    """Inline zh copy in the line table is shipped, not locale-overlaid."""
    parsed = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(parsed, list):
        raise RuntimeError(f"{path.relative_to(REPO_ROOT)}: expected a JSON array")
    characters: set[str] = set()
    for row in parsed:
        if not isinstance(row, dict):
            continue
        value = row.get("zh")
        if isinstance(value, str):
            characters.update(character for character in value if ord(character) >= 0x20)
    if not characters:
        raise RuntimeError(f"{path.relative_to(REPO_ROOT)}: no zh strings")
    return characters


def subset(pyftsubset: str, source: Path, text: str, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    # Keep the temporary output beside its destination. `replace()` is atomic
    # only within a filesystem; this checkout may live on an external volume
    # while the platform default temporary directory is on the system volume.
    with tempfile.TemporaryDirectory(
        prefix="glassvow-font-subset-", dir=destination.parent
    ) as temporary_dir:
        corpus_path = Path(temporary_dir) / "corpus.txt"
        temporary_output = Path(temporary_dir) / destination.name
        corpus_path.write_text(text, encoding="utf-8")
        command = [
            pyftsubset,
            str(source),
            f"--text-file={corpus_path}",
            "--flavor=woff2",
            "--layout-features=*",
            "--name-IDs=*",
            "--name-legacy",
            "--name-languages=*",
            "--notdef-glyph",
            "--notdef-outline",
            "--recommended-glyphs",
            "--hinting",
            "--no-recalc-timestamp",
            f"--output-file={temporary_output}",
        ]
        print("subset", source.name, "->", destination.relative_to(REPO_ROOT))
        subprocess.run(command, check=True)
        temporary_output.replace(destination)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--source-dir",
        type=Path,
        default=DEFAULT_SOURCE_DIR,
        help="uncommitted cache for downloaded/extracted Noto sources",
    )
    parser.add_argument(
        "--pyftsubset",
        default=shutil.which("pyftsubset"),
        help="pyftsubset executable (defaults to PATH)",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.pyftsubset is None:
        raise RuntimeError("pyftsubset is not on PATH; follow the bootstrap in this file header")

    corpus = locale_corpus()
    cjk_sources = ensure_cjk_sources(args.source_dir)
    symbol_source = ensure_symbol_source(args.source_dir)
    print(f"locale corpus: {len(corpus)} unique characters (includes printable ASCII)")

    for weight, source in cjk_sources.items():
        destination = OUTPUT_DIR / CJK_SOURCES[weight][2]
        subset(args.pyftsubset, source, corpus, destination)
    subset(args.pyftsubset, symbol_source, SYMBOL_TEXT, OUTPUT_DIR / SYMBOL_OUTPUT_NAME)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, subprocess.CalledProcessError, zipfile.BadZipFile) as error:
        print(f"subset build failed: {error}", file=sys.stderr)
        raise SystemExit(1)
