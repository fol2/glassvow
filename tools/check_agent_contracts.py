#!/usr/bin/env python3
"""Fast deterministic guardrails for active Glassvow agent instructions."""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


KERNEL_PATH = Path("AGENTS.md")
CLAUDE_PATH = Path("CLAUDE.md")
COPILOT_PATH = Path(".github/copilot-instructions.md")
SDLC_PATH = Path("docs/agents/ai-sdlc.md")
REVIEWER_PATH = Path(".claude/agents/ai-sdlc-reviewer.md")
SUNO_PATH = Path(".claude/skills/glassvow-suno/SKILL.md")
ELEVENLABS_PATH = Path(".claude/skills/glassvow-elevenlabs/SKILL.md")
STUDIO_WORKFLOW_PATH = Path(".grok/workflows/studio-dcc-map-glb.rhai")
MAX_KERNEL_BYTES = 12_000
MAX_KERNEL_LINES = 120
MAX_ENTRYPOINT_BYTES = 512
AGENT_NAME = re.compile(r"^[a-z]+(?:-[a-z]+)*$")

REQUIRED_SNIPPETS = {
    KERNEL_PATH: (
        "## Autonomy by default",
        "Human escalation is the exception",
        ".claude/agents/ai-sdlc-reviewer.md",
        "tools/check_agent_contracts.py",
    ),
    SDLC_PATH: (
        "Human judgement stays above the loop, not inside the routine critical path.",
        "A complete direct owner instruction or active issue is the intent artifact.",
        "Do not manufacture `intent.md`, `spec.md`, or `plan.md`",
        "`agent_config`",
        ".claude/agents/ai-sdlc-reviewer.md",
        "Preflight every required venue, tool, permission, and evidence channel before freezing",
        "Freeze the finite decision graph once",
        "A declared transition inside that accepted graph is execution authority",
        "Escalate only when the finite graph and its safe capability ladder are exhausted",
    ),
    REVIEWER_PATH: (
        "name: ai-sdlc-reviewer",
        "tools: Read, Glob, Grep, Bash",
        "model: sonnet",
        "permissionMode: plan",
        "maxTurns: 12",
        "effort: high",
        "isolation: worktree",
        "Verdict: `APPROVE`, `REQUEST_CHANGES`, or `INCONCLUSIVE`",
        "Do not edit, commit, push, merge",
    ),
    SUNO_PATH: (
        "approved audio-capable evaluator actually auditions every shortlisted candidate",
        "Do not infer perceptual quality from prompts, filenames, metadata, waveforms, spectrograms, or codec statistics.",
        "one bounded owner audition and choice",
    ),
    ELEVENLABS_PATH: (
        "approved audio-capable evaluator actually auditions every shortlisted candidate",
        "Do not infer perceptual quality from prompts, filenames, metadata, waveforms, spectrograms, or codec statistics.",
        "one bounded owner audition and choice",
    ),
    STUDIO_WORKFLOW_PATH: (
        "Historical observed flow: .grok/history/studio-dcc-map-glb-flow.md",
        'if task_id == "" { task_id = task_id_from(gen); }',
        "generation stopped fail-closed without a manual file handoff",
        'land_prompt += "--task-id " + task_id + " ";',
        "driver: tools/studio_image_to_glb.py + tools/land_map_glb.py",
    ),
}

REQUIRED_HISTORY_PATHS = (
    Path(".grok/history/first-paid-map-glb.rhai"),
    Path(".grok/history/studio-dcc-map-glb-flow.md"),
)

DEPRECATED_ACTIVE_PATHS = (
    Path(".grok/workflows/first-paid-map-glb.rhai"),
    Path(".grok/workflows/studio-dcc-map-glb-flow.md"),
)

# These phrases put a person on the routine critical path. Product-defining or
# irreversible decisions may still escalate under the autonomy contract.
BANNED_ROUTINE_HUMAN_GATES = (
    "James selects the candidate",
    "Fable drafts and James reviews",
    "→ James review",
    "James's attention",
)


def _read_text(root: Path, relative: Path, errors: list[str]) -> str:
    path = root / relative
    try:
        return path.read_text(encoding="utf-8")
    except OSError as error:
        errors.append(f"{relative}: cannot read: {error}")
    except UnicodeError as error:
        errors.append(f"{relative}: not valid UTF-8: {error}")
    return ""


def _active_instruction_paths(root: Path) -> tuple[Path, ...]:
    paths = {KERNEL_PATH}
    for optional in (CLAUDE_PATH, COPILOT_PATH):
        if (root / optional).is_file():
            paths.add(optional)
    paths.update(
        path.relative_to(root)
        for path in (root / ".github/instructions").rglob("*.instructions.md"))
    paths.update(path.relative_to(root) for path in (root / "docs/agents").glob("*.md"))
    paths.update(path.relative_to(root) for path in (root / ".claude/skills").rglob("SKILL.md"))
    paths.update(path.relative_to(root) for path in (root / ".claude/agents").rglob("*.md"))
    for workflow_root in (root / ".claude/workflows", root / ".grok/workflows"):
        paths.update(
            path.relative_to(root)
            for path in workflow_root.rglob("*")
            if path.is_file())
    return tuple(sorted(paths, key=lambda item: item.as_posix()))


def _frontmatter(text: str, path: Path, errors: list[str]) -> dict[str, str]:
    lines = text.splitlines()
    if not lines or lines[0] != "---":
        errors.append(f"{path}: missing opening YAML frontmatter delimiter")
        return {}
    try:
        end = lines.index("---", 1)
    except ValueError:
        errors.append(f"{path}: missing closing YAML frontmatter delimiter")
        return {}
    values: dict[str, str] = {}
    for line in lines[1:end]:
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if ":" not in line:
            errors.append(f"{path}: malformed frontmatter line: {line!r}")
            continue
        key, value = line.split(":", 1)
        values[key.strip()] = value.strip()
    for key in ("name", "description"):
        if not values.get(key):
            errors.append(f"{path}: frontmatter requires non-empty {key}")
    if len(values.get("description", "")) > 320:
        errors.append(f"{path}: description exceeds 320 characters")
    return values


def validate_repository(root: Path) -> list[str]:
    root = root.resolve()
    errors: list[str] = []
    texts: dict[Path, str] = {}
    for relative in _active_instruction_paths(root):
        texts[relative] = _read_text(root, relative, errors)

    kernel = texts.get(KERNEL_PATH, "")
    if kernel:
        byte_count = len(kernel.encode("utf-8"))
        line_count = len(kernel.splitlines())
        if byte_count > MAX_KERNEL_BYTES:
            errors.append(
                f"{KERNEL_PATH}: {byte_count} bytes exceeds {MAX_KERNEL_BYTES}; "
                "move detail behind progressive disclosure")
        if line_count > MAX_KERNEL_LINES:
            errors.append(
                f"{KERNEL_PATH}: {line_count} lines exceeds {MAX_KERNEL_LINES}; "
                "move detail behind progressive disclosure")

    claude_path = root / CLAUDE_PATH
    if not claude_path.exists():
        errors.append(f"{CLAUDE_PATH}: missing Claude Code entrypoint")
    elif claude_path.is_symlink():
        if claude_path.readlink() != Path("AGENTS.md"):
            errors.append(
                f"{CLAUDE_PATH}: symlink must target AGENTS.md, got "
                f"{claude_path.readlink()}")
    else:
        claude_entrypoint = texts.get(CLAUDE_PATH, "")
        if "@AGENTS.md" not in claude_entrypoint:
            errors.append(
                f"{CLAUDE_PATH}: regular entrypoint must import @AGENTS.md")
        if len(claude_entrypoint.encode("utf-8")) > MAX_ENTRYPOINT_BYTES:
            errors.append(
                f"{CLAUDE_PATH}: entrypoint exceeds {MAX_ENTRYPOINT_BYTES} bytes; "
                "import AGENTS.md instead of duplicating the kernel")

    for relative, snippets in REQUIRED_SNIPPETS.items():
        text = texts.get(relative)
        if text is None:
            text = _read_text(root, relative, errors)
            texts[relative] = text
        for snippet in snippets:
            if snippet not in text:
                errors.append(f"{relative}: missing required contract text: {snippet!r}")

    for relative in REQUIRED_HISTORY_PATHS:
        if not (root / relative).is_file():
            errors.append(f"{relative}: required historical workflow record is missing")

    for relative in DEPRECATED_ACTIVE_PATHS:
        if (root / relative).exists():
            errors.append(
                f"{relative}: deprecated one-off or historical record must not remain active")

    for relative, text in texts.items():
        for phrase in BANNED_ROUTINE_HUMAN_GATES:
            if phrase in text:
                errors.append(
                    f"{relative}: routine human gate is forbidden: {phrase!r}")

        relative_text = relative.as_posix()
        if (relative_text.startswith(".claude/workflows/")
                or relative_text.startswith(".grok/workflows/")):
            if "await_user(" in text:
                errors.append(
                    f"{relative}: active workflow may not hide a routine human "
                    "handoff; return a structured fail-closed blocker instead")

    skill_names: dict[str, Path] = {}
    agent_names: dict[str, Path] = {}
    agent_metadata: dict[Path, dict[str, str]] = {}
    for relative, text in texts.items():
        if relative.name == "SKILL.md":
            values = _frontmatter(text, relative, errors)
            name = values.get("name")
            if not name:
                continue
            previous = skill_names.get(name)
            if previous is not None:
                errors.append(
                    f"{relative}: duplicate skill name {name!r}; first seen in {previous}")
            else:
                skill_names[name] = relative
        elif relative.parts[:2] == (".claude", "agents") and relative.suffix == ".md":
            values = _frontmatter(text, relative, errors)
            agent_metadata[relative] = values
            name = values.get("name")
            if not name:
                continue
            if not AGENT_NAME.fullmatch(name):
                errors.append(
                    f"{relative}: agent name {name!r} must use lowercase letters and hyphens")
            previous = agent_names.get(name)
            if previous is not None:
                errors.append(
                    f"{relative}: duplicate agent name {name!r}; first seen in {previous}")
            else:
                agent_names[name] = relative

    if not skill_names:
        errors.append(".claude/skills: no active SKILL.md files found")
    if not agent_names:
        errors.append(".claude/agents: no active agent definitions found")

    reviewer = agent_metadata.get(REVIEWER_PATH, {})
    if reviewer:
        if reviewer.get("permissionMode") != "plan":
            errors.append(f"{REVIEWER_PATH}: reviewer must use permissionMode: plan")
        if reviewer.get("maxTurns") != "12":
            errors.append(f"{REVIEWER_PATH}: reviewer must use maxTurns: 12")
        if reviewer.get("effort") != "high":
            errors.append(f"{REVIEWER_PATH}: reviewer must use effort: high")
        if reviewer.get("isolation") != "worktree":
            errors.append(f"{REVIEWER_PATH}: reviewer must use isolation: worktree")
        if reviewer.get("model") != "sonnet":
            errors.append(f"{REVIEWER_PATH}: reviewer must use model: sonnet")
        tools = {item.strip() for item in reviewer.get("tools", "").split(",") if item.strip()}
        if tools != {"Read", "Glob", "Grep", "Bash"}:
            errors.append(
                f"{REVIEWER_PATH}: reviewer tools must be exactly Read, Glob, Grep, Bash")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    args = parser.parse_args(argv)
    errors = validate_repository(args.root)
    if errors:
        for error in errors:
            print(f"agent_contracts: {error}", file=sys.stderr)
        return 1
    paths = _active_instruction_paths(args.root.resolve())
    print(f"agent contracts OK ({len(paths)} active instruction files)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
