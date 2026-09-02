#!/usr/bin/env python3
"""Deterministic, fail-closed path scopes for the repository CI workflow."""
from __future__ import annotations

import argparse
import html
import sys
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from typing import Iterable


class ScopeInputError(ValueError):
    """Changed paths were not a safe, complete classifier input."""


SCOPE_NAMES = (
    "godot_code",
    "map_code",
    "map_assets",
    "balance_ml",
    "locale_content",
    "agent_config",
    "docs",
    "release_platform",
    "presentation",
    "dev_tools",
    "ci_infra",
    "conservative_core",
)


@dataclass(frozen=True)
class Check:
    key: str
    label: str
    scopes: tuple[str, ...] = ()
    always: bool = False
    changed_gdscript: bool = False


CHECKS = (
    Check("run_scope_contract", "Test CI scope classifier", always=True),
    Check("run_agent_contracts", "Check AI-SDLC agent contracts", ("agent_config",)),
    Check("setup_godot", "Setup Godot", (
        "godot_code", "map_code", "map_assets", "balance_ml", "locale_content",
        "release_platform", "presentation", "conservative_core")),
    Check("run_import_assets", "Import assets", (
        "godot_code", "map_code", "map_assets", "locale_content",
        "release_platform", "presentation", "conservative_core")),
    Check("run_import_gate_tests", "Test asset import gate failures", ("ci_infra",)),
    Check("run_gdscript_parse", "Check GDScript syntax", changed_gdscript=True),
    Check("run_gdscript_gate_tests", "Test GDScript gate failures", ("ci_infra",)),
    Check("run_locale_font", "Check zh-Hant bundled font coverage", ("locale_content",)),
    Check("run_locale_coverage", "Check narrative locale coverage", ("locale_content",)),
    Check("run_store_exclusion", "Check store Dev-tree exclusion", ("release_platform",)),
    Check("run_store_gate_tests", "Test store Dev-tree exclusion gate", ("release_platform",)),
    Check("run_dev_tools", "Check developer-tool registry and coordinate conversion", ("dev_tools",)),
    Check("run_balance_doe", "Test balanced content DOE generator", ("balance_ml",)),
    Check("run_balance_seed", "Test content-search seed contract", ("balance_ml",)),
    Check("run_balance_s009", "Test s009 exam catalogue reconstruction", ("balance_ml",)),
    Check("run_balance_registry", "Test Tier-1 grouped breadth registry", ("balance_ml",)),
    Check("run_balance_host", "Test candidate loading and host-qualify fail-closed", ("balance_ml",)),
    Check("run_balance_f0", "Test F0 evaluator protocol", ("balance_ml",)),
    Check("run_balance_tier1_f0", "Test Tier-1 F0 response contract", ("balance_ml",)),
    Check("run_balance_f1_f2", "Test F1/F2 racing and model adequacy rules", ("balance_ml",)),
    Check("run_doc_anchors", "Check doc file:line anchors", ("docs",)),
    Check("run_benchmark_freeze", "Check no new web-reference citations", ("docs",)),
    Check("run_map_assets", "Check map tile and module assets", ("map_assets",)),
    Check("run_map_quality", "Check Map Compiler v2 quality contract", ("map_code",)),
    Check("run_performance_evidence", "Test performance evidence replay", (
        "release_platform", "presentation")),
    Check("run_godot_tests", "Run tests", (
        "godot_code", "locale_content", "conservative_core")),
    Check("run_map_profiles", "Probe shared map asset profiles", ("map_code", "map_assets")),
    Check("run_choice_scroll", "Test phone-landscape scroll reachability", (
        "release_platform", "presentation")),
    Check("run_boss_relic", "Test boss-relic phone containment", (
        "release_platform", "presentation")),
    Check("run_dawn_containment", "Test Dawn phone containment", (
        "release_platform", "presentation")),
    Check("run_hud_location", "Test run HUD location fit", (
        "release_platform", "presentation")),
)


@dataclass(frozen=True)
class Selection:
    full_gate: bool
    paths: tuple[str, ...]
    scopes: dict[str, bool]
    scope_paths: dict[str, tuple[str, ...]]
    changed_gdscripts: tuple[str, ...]
    checks: dict[str, bool]
    check_reasons: dict[str, str]

    def outputs(self) -> dict[str, str]:
        values = {name: _bool(self.scopes[name]) for name in SCOPE_NAMES}
        values.update({key: _bool(value) for key, value in self.checks.items()})
        values["full_gate"] = _bool(self.full_gate)
        values["changed_path_count"] = str(len(self.paths))
        values["changed_gdscript_count"] = str(len(self.changed_gdscripts))
        return values


def _bool(value: bool) -> str:
    return "true" if value else "false"


def _normalise_paths(paths: Iterable[str]) -> tuple[str, ...]:
    if isinstance(paths, (str, bytes)):
        raise ScopeInputError("changed paths must be a sequence, not a scalar")
    values = list(paths)
    if not values:
        raise ScopeInputError("changed path input is empty")
    seen: set[str] = set()
    for path in values:
        if not isinstance(path, str) or not path:
            raise ScopeInputError("every changed path must be a non-empty string")
        if any(ord(character) < 32 or ord(character) == 127 for character in path):
            raise ScopeInputError(f"changed path contains a control character: {path!r}")
        parts = path.split("/")
        if path.startswith("/") or any(part in ("", ".", "..") for part in parts):
            raise ScopeInputError(f"changed path is not repository-relative: {path!r}")
        if str(PurePosixPath(path)) != path:
            raise ScopeInputError(f"changed path is not canonical: {path!r}")
        if path in seen:
            raise ScopeInputError(f"changed path is duplicated: {path!r}")
        seen.add(path)
    return tuple(sorted(values))


def _starts(path: str, *prefixes: str) -> bool:
    return any(path.startswith(prefix) for prefix in prefixes)


def _scope_matches(path: str) -> set[str]:
    lower = path.lower()
    name = PurePosixPath(lower).name
    matches: set[str] = set()

    if (path == "project.godot" or lower.endswith((
            ".gd", ".gd.uid", ".tscn", ".tres", ".gdshader",
            ".gdshader.uid", ".gdshaderinc"))):
        matches.add("godot_code")

    map_named_test = _starts(lower, "tests/", "tools/") and (
        "map" in name or "waylight" in name)
    if (_starts(lower, "presentation/map/", "domain/map_layout/", "docs/map/")
            or map_named_test):
        matches.add("map_code")

    map_asset_tools = {
        "tools/check_map_assets.py",
        "tools/land_map_glb.py",
        "tools/map_asset_checks.py",
        "tools/map_asset_self_test.py",
        "tools/bench_map_assets.gd",
        "tools/bench_map_assets.gd.uid",
    }
    if (_starts(lower, "assets/art/map/")
            or (_starts(lower, "presentation/map/") and lower.endswith((
                ".gdshader", ".gdshader.uid", ".gdshaderinc")))
            or lower in map_asset_tools):
        matches.add("map_assets")

    if (_starts(lower, "tools/balance_", "tests/test_balance_", "domain/balance/",
                "docs/balance/")
            or lower in {"docs/p6-balance-ledger.md", "tools/requirements-balance-f2.txt"}):
        matches.add("balance_ml")

    locale_named_test = _starts(lower, "tests/") and any(token in name for token in (
        "locale", "content", "line_table", "narrative"))
    if (_starts(lower, "locale/", "content/", "assets/fonts/")
            or lower in {"application/locale.gd", "application/locale.gd.uid",
                         "tools/check_locale_coverage.py",
                         "tools/check_locale_font_coverage.py"}
            or locale_named_test):
        matches.add("locale_content")

    github_agent_instruction = (
        lower == ".github/copilot-instructions.md"
        or _starts(lower, ".github/instructions/"))
    if (lower in {"agents.md", "claude.md"}
            or github_agent_instruction
            or _starts(lower, ".claude/", ".grok/workflows/", "docs/agents/")
            or lower in {"tools/check_agent_contracts.py",
                         "tests/test_agent_contracts.py"}):
        matches.add("agent_config")

    if (_starts(lower, "docs/", ".grok/history/")
            or lower.endswith((".md", ".markdown"))
            or lower in {"license", "tools/check_anchors.py",
                         "tools/check_benchmark_freeze.py",
                         "tools/benchmark-citations.txt"}):
        matches.add("docs")

    release_named = any(token in lower for token in (
        "release", "performance", "containment", "phone", "store", "signing"))
    if (lower == "export_presets.cfg"
            or _starts(lower, "scripts/", "addons/glassvow_ios_export/",
                       "addons/glassvow_web_export/", "addons/sentry/",
                       "application/sentry_")
            or ((_starts(lower, "tests/", "tools/", "docs/")) and release_named)):
        matches.add("release_platform")

    if _starts(lower, "presentation/"):
        matches.add("presentation")

    if (lower in {"tools/dev.py", "tools/test_dev_point.py", "docs/dev-tools.md"}
            or _starts(lower, ".cursor/")
            or _starts(lower, "tools/live.", "tools/shot.")):
        matches.add("dev_tools")

    if ((_starts(lower, ".github/") and not github_agent_instruction)
            or lower in {"tools/ci_scope.py", "tests/test_ci_scope.py",
                         "tools/check_imports.sh", "tools/test_check_imports.sh",
                         "tools/check_scripts.sh", "tools/test_check_scripts.sh"}):
        matches.add("ci_infra")

    return matches


def _select_checks(
        full_gate: bool,
        scopes: dict[str, bool],
        changed_gdscripts: tuple[str, ...],
) -> tuple[dict[str, bool], dict[str, str]]:
    selected: dict[str, bool] = {}
    reasons: dict[str, str] = {}
    force_all = full_gate or scopes["ci_infra"]
    for check in CHECKS:
        if full_gate:
            selected[check.key] = True
            reasons[check.key] = "full scheduled/manual integration gate"
        elif force_all:
            selected[check.key] = True
            reasons[check.key] = "CI authority input changed; fail-closed full PR gate"
        elif check.changed_gdscript:
            selected[check.key] = bool(changed_gdscripts)
            reasons[check.key] = (
                f"{len(changed_gdscripts)} changed GDScript file(s) remain at the PR head"
                if changed_gdscripts else "no changed GDScript file remains at the PR head")
        elif check.always:
            selected[check.key] = True
            reasons[check.key] = "selection authority is tested on every run"
        else:
            active = tuple(scope for scope in check.scopes if scopes[scope])
            selected[check.key] = bool(active)
            reasons[check.key] = (
                "selected scope(s): " + ", ".join(active)
                if active else "none of the relevant scopes selected: " + ", ".join(check.scopes))
    return selected, reasons


def classify_paths(
        paths: Iterable[str],
        present_paths: Iterable[str] | None = None,
) -> Selection:
    normalised = _normalise_paths(paths)
    if present_paths is None:
        present = set(normalised)
    else:
        present_values = list(present_paths)
        present = set(_normalise_paths(present_values)) if present_values else set()
    if not present.issubset(set(normalised)):
        raise ScopeInputError("present paths must be a subset of changed paths")

    scope_paths: dict[str, list[str]] = {name: [] for name in SCOPE_NAMES}
    for path in normalised:
        matches = _scope_matches(path)
        if not matches:
            matches.add("conservative_core")
        for scope in matches:
            scope_paths[scope].append(path)

    frozen_scope_paths = {name: tuple(scope_paths[name]) for name in SCOPE_NAMES}
    scopes = {name: bool(frozen_scope_paths[name]) for name in SCOPE_NAMES}
    changed_gdscripts = tuple(
        path for path in normalised if path.endswith(".gd") and path in present)
    checks, reasons = _select_checks(False, scopes, changed_gdscripts)
    return Selection(False, normalised, scopes, frozen_scope_paths,
                     changed_gdscripts, checks, reasons)


def full_selection() -> Selection:
    scopes = {name: True for name in SCOPE_NAMES}
    scope_paths = {name: () for name in SCOPE_NAMES}
    checks, reasons = _select_checks(True, scopes, ())
    return Selection(True, (), scopes, scope_paths, (), checks, reasons)


def read_nul_paths(path: Path) -> tuple[str, ...]:
    try:
        payload = path.read_bytes()
    except OSError as error:
        raise ScopeInputError(f"cannot read changed paths: {error}") from error
    if not payload:
        raise ScopeInputError("changed path input is empty")
    if not payload.endswith(b"\0"):
        raise ScopeInputError("changed path input is not NUL terminated")
    try:
        values = [item.decode("utf-8", errors="strict") for item in payload[:-1].split(b"\0")]
    except UnicodeDecodeError as error:
        raise ScopeInputError("changed paths are not valid UTF-8") from error
    return _normalise_paths(values)


def render_summary(selection: Selection) -> str:
    mode = "full scheduled/manual integration gate" if selection.full_gate else "scope-aware changed-path gate"
    coverage = (
        "GDScript mode: **discovered full sweep**."
        if selection.full_gate else
        f"Changed paths: **{len(selection.paths)}**; changed GDScript files parsed: "
        f"**{len(selection.changed_gdscripts)}**."
    )
    lines = [
        "## CI check selection",
        "",
        f"Mode: **{mode}**. {coverage}",
        "",
        "### Scopes",
        "",
        "| Scope | Decision | Reason |",
        "| --- | --- | --- |",
    ]
    for scope in SCOPE_NAMES:
        selected = selection.scopes[scope]
        count = len(selection.scope_paths[scope])
        reason = ("full integration boundary" if selection.full_gate else
                  f"{count} changed path(s) matched" if selected else "no changed path matched")
        lines.append(f"| `{scope}` | **{'SELECTED' if selected else 'SKIPPED'}** | {reason} |")

    lines.extend(("", "### Checks", "", "| Check | Decision | Reason |",
                  "| --- | --- | --- |"))
    for check in CHECKS:
        decision = "SELECTED" if selection.checks[check.key] else "SKIPPED"
        lines.append(
            f"| {check.label} | **{decision}** | {selection.check_reasons[check.key]} |")

    if selection.paths:
        lines.extend(("", "<details><summary>Classified changed paths</summary>", "", "<ul>"))
        lines.extend(f"<li><code>{html.escape(path)}</code></li>" for path in selection.paths)
        lines.extend(("</ul>", "", "</details>"))
    return "\n".join(lines) + "\n"


def _append(path: Path, text: str) -> None:
    try:
        with path.open("a", encoding="utf-8", newline="\n") as handle:
            handle.write(text)
    except OSError as error:
        raise ScopeInputError(f"cannot write {path}: {error}") from error


def _write_changed_gdscripts(path: Path, scripts: tuple[str, ...]) -> None:
    try:
        path.write_bytes(b"".join(script.encode("utf-8") + b"\0" for script in scripts))
    except OSError as error:
        raise ScopeInputError(f"cannot write changed GDScript paths: {error}") from error


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--full-gate", action="store_true")
    source.add_argument("--changed-paths-nul", type=Path)
    parser.add_argument("--repository-root", type=Path, default=Path.cwd())
    parser.add_argument("--changed-gdscript-nul", type=Path)
    parser.add_argument("--github-output", type=Path)
    parser.add_argument("--github-summary", type=Path)
    args = parser.parse_args(argv)

    try:
        if args.full_gate:
            selection = full_selection()
        else:
            paths = read_nul_paths(args.changed_paths_nul)
            present = tuple(path for path in paths if (args.repository_root / path).is_file())
            selection = classify_paths(paths, present)
        if args.changed_gdscript_nul:
            _write_changed_gdscripts(args.changed_gdscript_nul, selection.changed_gdscripts)
        if args.github_output:
            _append(args.github_output, "".join(
                f"{key}={value}\n" for key, value in selection.outputs().items()))
        summary = render_summary(selection)
        if args.github_summary:
            _append(args.github_summary, summary)
        else:
            print(summary, end="")
    except ScopeInputError as error:
        print(f"ci_scope: {error}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
