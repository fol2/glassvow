#!/usr/bin/env python3
"""CI-negative check: store/RC packs cannot carry the Console tree or its CLI."""

from __future__ import annotations

import os
import re
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


def tracked_paths(root: Path) -> list[str]:
    listed = os.environ.get("STORE_DEV_TRACKED")
    if listed:
        return [ln.strip() for ln in Path(listed).read_text().splitlines() if ln.strip()]
    out = subprocess.check_output(["git", "ls-files"], cwd=root, text=True)
    return [ln for ln in out.splitlines() if ln]


def main() -> int:
    root = Path(os.environ.get("STORE_DEV_ROOT", Path(__file__).resolve().parent.parent))
    presets_path = Path(os.environ.get("STORE_DEV_PRESETS", root / "export_presets.cfg"))
    errors: list[str] = []
    presets = parse_presets(presets_path.read_text())
    by_name = {item["name"]: item for item in presets}
    tracked = tracked_paths(root)
    dev_files = [p for p in tracked if p.startswith(DEV_PREFIX)]
    dev_gd = [p for p in dev_files if p.endswith(".gd")]
    if not dev_gd:
        errors.append("presentation/dev/ has no tracked .gd (vacuous exclude)")
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
        for path in dev_files:
            if not any(glob_match(g, path) for g in globs):
                errors.append("%s exclude_filter does not match %s" % (name, path))
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
    if errors:
        for msg in errors:
            print(msg, file=sys.stderr)
        return 1
    print("store-dev-exclusion OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
