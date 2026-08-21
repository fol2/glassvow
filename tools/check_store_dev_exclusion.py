#!/usr/bin/env python3
"""CI-negative check: store/RC packs cannot carry developer-only bytecode."""

from __future__ import annotations

import os
import re
import struct
import subprocess
import sys
from pathlib import Path

STORE = ("macOS", "iOS", "Android (Play AAB)")
REVIEW_MARK = "Dev Review"
WEB_DEV = "Web Dev"
DEV_PREFIX = "presentation/dev/"
PROD_ROOTS = ("application/", "presentation/", "domain/", "content/")
TOKENS = (
    "--scenario",
    "class_name DeveloperConsole",
    'preload("res://presentation/dev/',
)
PACKABLE_TOOLS = (".gd", ".tscn", ".tres")
STORE_MUST_EXCLUDE = (
    "tests/run_all.gd",
    "presentation/dev/console.gd",
)
STORE_MUST_KEEP = (
    ("tools/vow_incentives.gd", "tools/vow_incentives.gd"),
    ("addons/sentry/sentry.gdextension", "Sentry"),
    ("application/dev_tools.gd", "application/dev_tools.gd"),
    ("presentation/lab/card_lab.gd", "presentation/lab"),
)
DEV_TREE_PREFIXES = (
    DEV_PREFIX,
    "tests/",
    "addons/funplay_mcp/",
    "addons/core/",
    "addons/runtime/",
    "addons/ui/",
    "addons/glassvow_ios_export/",
    "addons/glassvow_web_export/",
)
DEV_TREE_FILES = ("addons/plugin.gd", "addons/plugin.cfg", "addons/icon.svg")
PCK_FORBIDDEN_PREFIXES = DEV_TREE_PREFIXES + ("port_fixtures/",)
PCK_REQUIRED = (
    "tools/vow_incentives.gd",
    "application/dev_tools.gd",
    "addons/sentry/sentry.gdextension",
    "presentation/lab/card_lab.gd",
)
PACK_MAGIC = 0x43504447
PACK_DIR_ENCRYPTED = 1 << 0
PACK_VERSIONS = (2, 3, 4)
PRESET_RE = re.compile(r"^\[preset\.(\d+)\]\s*$")
KEY_RE = re.compile(r'^(name|custom_features|exclude_filter)="(.*)"\s*$')


def parse_presets(text: str) -> list[dict[str, str]]:
    presets: list[dict[str, str]] = []
    current: dict[str, str] | None = None
    in_options = False
    for line in text.splitlines():
        if line.startswith("[preset.") and line.endswith(".options]"):
            in_options = True
            continue
        if PRESET_RE.match(line):
            if current is not None:
                presets.append(current)
            current = {"name": "", "custom_features": "", "exclude_filter": ""}
            in_options = False
            continue
        if in_options or current is None:
            continue
        matched = KEY_RE.match(line)
        if matched:
            current[matched.group(1)] = matched.group(2)
    if current is not None:
        presets.append(current)
    return presets


def csv(value: str) -> list[str]:
    return [part.strip() for part in value.split(",") if part.strip()]


def glob_match(pattern: str, path: str) -> bool:
    escaped = re.escape(pattern).replace(r"\*", ".*")
    return re.fullmatch(escaped, path, flags=re.IGNORECASE) is not None


def hits(globs: list[str], path: str) -> bool:
    return any(glob_match(g, path) for g in globs)


def tracked_paths(root: Path) -> list[str]:
    listed = os.environ.get("STORE_DEV_TRACKED")
    if listed:
        return [ln.strip() for ln in Path(listed).read_text().splitlines() if ln.strip()]
    out = subprocess.check_output(["git", "ls-files"], cwd=root, text=True)
    return [ln for ln in out.splitlines() if ln]


def pack_rel(path: str) -> str:
    rel = path.split("\x00", 1)[0]
    if rel.startswith("res://"):
        return rel[6:]
    return rel


def pck_key(path: str) -> str:
    rel = pack_rel(path)
    if rel.endswith(".remap"):
        rel = rel[:-6]
    if rel.endswith(".gdc"):
        rel = rel[:-4] + ".gd"
    return rel


def is_runtime_tool(path: str) -> bool:
    return path == "tools/vow_incentives.gd" or path.startswith("tools/vow_incentives.gd.")


def is_dev_tree_path(path: str) -> bool:
    if path.startswith(DEV_TREE_PREFIXES) or path in DEV_TREE_FILES:
        return True
    if path.startswith("addons/plugin.") or path.startswith("addons/icon.svg"):
        return True
    if path.startswith("tools/") and not is_runtime_tool(path):
        return path.endswith(PACKABLE_TOOLS) or path.endswith(".uid")
    return False


def list_pck_paths(data: bytes) -> list[str]:
    if len(data) < 32:
        raise ValueError("pck too small")
    magic, version, _maj, _min, _patch, flags = struct.unpack_from("<6I", data, 0)
    if magic != PACK_MAGIC:
        raise ValueError("not a GDPC pack")
    if version not in PACK_VERSIONS:
        raise ValueError("unsupported pck version %d" % version)
    if flags & PACK_DIR_ENCRYPTED:
        raise ValueError("encrypted pck directory")
    pos = 24
    struct.unpack_from("<Q", data, pos)
    pos += 8
    if version >= 3:
        if pos + 8 > len(data):
            raise ValueError("pck directory offset truncated")
        dir_offset = struct.unpack_from("<Q", data, pos)[0]
        pos = dir_offset
    else:
        pos += 16 * 4
    if pos + 4 > len(data):
        raise ValueError("pck directory truncated")
    file_count = struct.unpack_from("<I", data, pos)[0]
    pos += 4
    paths: list[str] = []
    for _ in range(file_count):
        if pos + 4 > len(data):
            raise ValueError("pck entry truncated")
        sl = struct.unpack_from("<I", data, pos)[0]
        pos += 4
        if pos + sl + 8 + 8 + 16 + 4 > len(data):
            raise ValueError("pck path truncated")
        raw = data[pos : pos + sl].split(b"\x00", 1)[0]
        try:
            paths.append(raw.decode("utf-8"))
        except UnicodeDecodeError as exc:
            raise ValueError("pck path is not UTF-8") from exc
        pos += sl + 8 + 8 + 16 + 4
    return paths


def check_pck_paths(paths: list[str]) -> list[str]:
    errors: list[str] = []
    keys = [pck_key(p) for p in paths]
    keyset = set(keys)
    for prefix in PCK_FORBIDDEN_PREFIXES:
        if any(k.startswith(prefix) for k in keys):
            errors.append("pck carries %s" % prefix)
    for path in DEV_TREE_FILES:
        if path in keyset:
            errors.append("pck carries %s" % path)
    for key in keys:
        if key.startswith("tools/") and not is_runtime_tool(key):
            errors.append("pck carries %s" % key)
            break
    for required in PCK_REQUIRED:
        if required not in keyset:
            label = "Sentry extension" if required.startswith("addons/sentry/") else required
            errors.append("pck missing %s" % label)
    return errors


def check_presets(root: Path, presets_path: Path) -> list[str]:
    errors: list[str] = []
    presets = parse_presets(presets_path.read_text())
    by_name = {item["name"]: item for item in presets}
    tracked = tracked_paths(root)
    dev_files = [p for p in tracked if p.startswith(DEV_PREFIX)]
    dev_gd = [p for p in dev_files if p.endswith(".gd")]
    if not dev_gd:
        errors.append("presentation/dev/ has no tracked .gd (vacuous exclude)")
    if not any(p == "tests/run_all.gd" or p.startswith("tests/") for p in tracked):
        errors.append("tests/ has no tracked files (vacuous exclude)")
    sweep = [p for p in tracked if is_dev_tree_path(p)]
    for name in STORE:
        if REVIEW_MARK in name:
            continue
        preset = by_name.get(name)
        if preset is None:
            errors.append("%s preset is missing" % name)
            continue
        if "dev_tools" in csv(preset["custom_features"]):
            errors.append("%s lists custom feature dev_tools" % name)
        globs = csv(preset["exclude_filter"])
        for path in STORE_MUST_EXCLUDE:
            if not hits(globs, path):
                errors.append("%s exclude_filter does not match %s" % (name, path))
        for path in sweep:
            if not hits(globs, path):
                errors.append("%s exclude_filter does not match %s" % (name, path))
        for path, label in STORE_MUST_KEEP:
            if hits(globs, path):
                errors.append("%s exclude_filter drops %s" % (name, label))
    for preset in presets:
        name = preset["name"]
        if REVIEW_MARK not in name:
            continue
        globs = csv(preset["exclude_filter"])
        if any(glob_match(g, "presentation/dev/console.gd") for g in globs):
            errors.append("%s must include the Console tree" % name)
        if "dev_tools" not in csv(preset["custom_features"]):
            errors.append("%s must list custom feature dev_tools" % name)
    web = by_name.get(WEB_DEV)
    if web is None:
        errors.append("Web Dev preset is missing")
    elif "dev_tools" not in csv(web["custom_features"]):
        errors.append("Web Dev must list custom feature dev_tools")
    for path in tracked:
        if not path.startswith(PROD_ROOTS) or path.startswith(DEV_PREFIX):
            continue
        text = (root / path).read_text(errors="replace")
        for token in TOKENS:
            if token in text:
                errors.append("%s: forbidden token %s" % (path, token))
    return errors


def report(errors: list[str]) -> int:
    if errors:
        for msg in errors:
            print(msg, file=sys.stderr)
        return 1
    return 0


def main(argv: list[str] | None = None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    list_only = False
    pck_path: Path | None = None
    if argv[:1] == ["--list-pck"] and len(argv) == 2:
        list_only = True
        pck_path = Path(argv[1])
    elif argv[:1] == ["--pck"] and len(argv) == 2:
        pck_path = Path(argv[1])
    elif argv:
        print("usage: check_store_dev_exclusion.py [--pck FILE | --list-pck FILE]",
              file=sys.stderr)
        return 2
    if list_only:
        assert pck_path is not None
        for path in list_pck_paths(pck_path.read_bytes()):
            print(path)
        return 0
    root = Path(os.environ.get("STORE_DEV_ROOT", Path(__file__).resolve().parent.parent))
    presets_path = Path(os.environ.get("STORE_DEV_PRESETS", root / "export_presets.cfg"))
    errors = check_presets(root, presets_path)
    if pck_path is not None:
        try:
            errors.extend(check_pck_paths(list_pck_paths(pck_path.read_bytes())))
        except ValueError as exc:
            errors.append("pck: %s" % exc)
    rc = report(errors)
    if rc == 0:
        print("store-dev-exclusion OK" if pck_path is None else "store-dev-exclusion OK\npck-dir OK")
    return rc


if __name__ == "__main__":
    sys.exit(main())
