#!/usr/bin/env python3
"""Regression fixtures for the active AI-SDLC instruction contract."""
from __future__ import annotations

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "check_agent_contracts", ROOT / "tools/check_agent_contracts.py")
assert SPEC and SPEC.loader
CONTRACTS = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = CONTRACTS
SPEC.loader.exec_module(CONTRACTS)


KERNEL = """# Agent kernel

## Autonomy by default
Human escalation is the exception for unresolved material decisions.
Delegate to `.claude/agents/ai-sdlc-reviewer.md`.
Run `tools/check_agent_contracts.py` for active instruction changes.
"""

SDLC = """# AI-SDLC

Human judgement stays above the loop, not inside the routine critical path.
A complete direct owner instruction or active issue is the intent artifact.
Do not manufacture `intent.md`, `spec.md`, or `plan.md` for a bounded task.
Agent instruction changes select the `agent_config` scope.
Use `.claude/agents/ai-sdlc-reviewer.md`.
Preflight every required venue, tool, permission, and evidence channel before freezing a dependent protocol.
Freeze the finite decision graph once: nodes and transitions.
A declared transition inside that accepted graph is execution authority.
Escalate only when the finite graph and its safe capability ladder are exhausted.
"""

CLAUDE = """# Claude entry point

@AGENTS.md
"""

SKILL = """---
name: fixture-skill
description: Use only for the fixture contract.
---

# Fixture
"""

AUDIO_BOUNDARY = """An approved audio-capable evaluator actually auditions every shortlisted candidate.
Do not infer perceptual quality from prompts, filenames, metadata, waveforms, spectrograms, or codec statistics.
When no evaluator is available, request one bounded owner audition and choice.
"""

SUNO_SKILL = """---
name: fixture-suno
description: Music fixture for the audio-evidence contract.
---

# Fixture Suno

""" + AUDIO_BOUNDARY

ELEVENLABS_SKILL = """---
name: fixture-elevenlabs
description: SFX fixture for the audio-evidence contract.
---

# Fixture ElevenLabs

""" + AUDIO_BOUNDARY

REVIEWER = """---
name: ai-sdlc-reviewer
description: Fresh-context exact-head review fixture.
tools: Read, Glob, Grep, Bash
model: sonnet
permissionMode: plan
maxTurns: 12
effort: high
isolation: worktree
---

Do not edit, commit, push, merge.
Verdict: `APPROVE`, `REQUEST_CHANGES`, or `INCONCLUSIVE`
"""

STUDIO = """let meta = #{
    description: "Historical observed flow: .grok/history/studio-dcc-map-glb-flow.md",
};
if task_id == "" { task_id = task_id_from(gen); }
let summary = "generation stopped fail-closed without a manual file handoff";
land_prompt += "--task-id " + task_id + " ";
report += "driver: tools/studio_image_to_glb.py + tools/land_map_glb.py";
complete(#{ ok: true, summary: summary });
"""


class AgentContractTests(unittest.TestCase):
    def make_fixture(self) -> tuple[tempfile.TemporaryDirectory[str], Path]:
        temporary = tempfile.TemporaryDirectory(prefix="glassvow-agent-contract-")
        root = Path(temporary.name)
        (root / "docs/agents").mkdir(parents=True)
        (root / ".claude/skills/fixture").mkdir(parents=True)
        (root / ".claude/skills/glassvow-suno").mkdir(parents=True)
        (root / ".claude/skills/glassvow-elevenlabs").mkdir(parents=True)
        (root / ".claude/agents").mkdir(parents=True)
        (root / ".claude/workflows").mkdir(parents=True)
        (root / ".grok/workflows").mkdir(parents=True)
        (root / ".grok/history").mkdir(parents=True)
        (root / "AGENTS.md").write_text(KERNEL, encoding="utf-8")
        (root / "CLAUDE.md").write_text(CLAUDE, encoding="utf-8")
        (root / "docs/agents/ai-sdlc.md").write_text(SDLC, encoding="utf-8")
        (root / ".claude/skills/fixture/SKILL.md").write_text(SKILL, encoding="utf-8")
        (root / ".claude/skills/glassvow-suno/SKILL.md").write_text(
            SUNO_SKILL, encoding="utf-8")
        (root / ".claude/skills/glassvow-elevenlabs/SKILL.md").write_text(
            ELEVENLABS_SKILL, encoding="utf-8")
        (root / ".claude/agents/ai-sdlc-reviewer.md").write_text(
            REVIEWER, encoding="utf-8")
        (root / ".claude/workflows/fixture.js").write_text(
            "const review = 'owner-agent'\n", encoding="utf-8")
        (root / ".grok/workflows/studio-dcc-map-glb.rhai").write_text(
            STUDIO, encoding="utf-8")
        (root / ".grok/history/first-paid-map-glb.rhai").write_text(
            "historical\n", encoding="utf-8")
        (root / ".grok/history/studio-dcc-map-glb-flow.md").write_text(
            "# Historical\n", encoding="utf-8")
        return temporary, root

    def test_repository_contract_is_current(self) -> None:
        self.assertEqual([], CONTRACTS.validate_repository(ROOT))

    def test_minimal_valid_fixture(self) -> None:
        temporary, root = self.make_fixture()
        self.addCleanup(temporary.cleanup)
        self.assertEqual([], CONTRACTS.validate_repository(root))

    def test_claude_entrypoint_imports_the_kernel(self) -> None:
        temporary, root = self.make_fixture()
        self.addCleanup(temporary.cleanup)
        path = root / "CLAUDE.md"
        path.write_text("# Stale duplicated rules\n", encoding="utf-8")
        errors = CONTRACTS.validate_repository(root)
        self.assertTrue(any("@AGENTS.md" in error for error in errors), errors)

    def test_claude_symlink_to_kernel_is_valid(self) -> None:
        temporary, root = self.make_fixture()
        self.addCleanup(temporary.cleanup)
        path = root / "CLAUDE.md"
        path.unlink()
        path.symlink_to("AGENTS.md")
        self.assertEqual([], CONTRACTS.validate_repository(root))

    def test_claude_symlink_to_wrong_target_fails(self) -> None:
        temporary, root = self.make_fixture()
        self.addCleanup(temporary.cleanup)
        path = root / "CLAUDE.md"
        path.unlink()
        (root / "OTHER.md").write_text("# Other\n", encoding="utf-8")
        path.symlink_to("OTHER.md")
        errors = CONTRACTS.validate_repository(root)
        self.assertTrue(any("symlink must target AGENTS.md" in error for error in errors), errors)

    def test_routine_human_gate_fails(self) -> None:
        temporary, root = self.make_fixture()
        self.addCleanup(temporary.cleanup)
        path = root / ".claude/skills/fixture/SKILL.md"
        path.write_text(SKILL + "\nJames selects the candidate.\n", encoding="utf-8")
        errors = CONTRACTS.validate_repository(root)
        self.assertTrue(any("routine human gate" in error for error in errors), errors)

    def test_routine_human_gate_in_active_workflow_fails(self) -> None:
        temporary, root = self.make_fixture()
        self.addCleanup(temporary.cleanup)
        path = root / ".claude/workflows/fixture.js"
        path.write_text("const note = \"worth James's attention\"\n", encoding="utf-8")
        errors = CONTRACTS.validate_repository(root)
        self.assertTrue(any("routine human gate" in error for error in errors), errors)

    def test_active_grok_workflow_human_handoff_fails(self) -> None:
        temporary, root = self.make_fixture()
        self.addCleanup(temporary.cleanup)
        path = root / ".grok/workflows/studio-dcc-map-glb.rhai"
        path.write_text(STUDIO + 'await_user("user", "Place a file and resume.");\n',
                        encoding="utf-8")
        errors = CONTRACTS.validate_repository(root)
        self.assertTrue(
            any("structured fail-closed blocker" in error for error in errors), errors)

    def test_kernel_budget_fails_closed(self) -> None:
        temporary, root = self.make_fixture()
        self.addCleanup(temporary.cleanup)
        path = root / "AGENTS.md"
        path.write_text(KERNEL + ("detail\n" * 200), encoding="utf-8")
        errors = CONTRACTS.validate_repository(root)
        self.assertTrue(any("lines exceeds" in error for error in errors), errors)

    def test_skill_frontmatter_is_required(self) -> None:
        temporary, root = self.make_fixture()
        self.addCleanup(temporary.cleanup)
        path = root / ".claude/skills/fixture/SKILL.md"
        path.write_text("# Missing frontmatter\n", encoding="utf-8")
        errors = CONTRACTS.validate_repository(root)
        self.assertTrue(any("frontmatter" in error for error in errors), errors)

    def test_required_autonomy_text_is_not_optional(self) -> None:
        temporary, root = self.make_fixture()
        self.addCleanup(temporary.cleanup)
        path = root / "docs/agents/ai-sdlc.md"
        path.write_text(
            SDLC.replace(
                "Human judgement stays above the loop, not inside the routine critical path.\n",
                ""),
            encoding="utf-8")
        errors = CONTRACTS.validate_repository(root)
        self.assertTrue(any("missing required contract text" in error for error in errors), errors)

    def test_dedicated_reviewer_is_required(self) -> None:
        temporary, root = self.make_fixture()
        self.addCleanup(temporary.cleanup)
        (root / ".claude/agents/ai-sdlc-reviewer.md").unlink()
        errors = CONTRACTS.validate_repository(root)
        self.assertTrue(any("ai-sdlc-reviewer.md" in error for error in errors), errors)

    def test_reviewer_must_stay_bounded_read_only_and_isolated(self) -> None:
        temporary, root = self.make_fixture()
        self.addCleanup(temporary.cleanup)
        path = root / ".claude/agents/ai-sdlc-reviewer.md"
        path.write_text(
            REVIEWER.replace("permissionMode: plan", "permissionMode: acceptEdits")
                    .replace("maxTurns: 12", "maxTurns: 0")
                    .replace("isolation: worktree", "isolation: none"),
            encoding="utf-8")
        errors = CONTRACTS.validate_repository(root)
        self.assertTrue(any("permissionMode: plan" in error for error in errors), errors)
        self.assertTrue(any("maxTurns: 12" in error for error in errors), errors)
        self.assertTrue(any("isolation: worktree" in error for error in errors), errors)

    def test_duplicate_agent_name_fails(self) -> None:
        temporary, root = self.make_fixture()
        self.addCleanup(temporary.cleanup)
        (root / ".claude/agents/duplicate.md").write_text(REVIEWER, encoding="utf-8")
        errors = CONTRACTS.validate_repository(root)
        self.assertTrue(any("duplicate agent name" in error for error in errors), errors)

    def test_studio_task_id_propagation_is_required(self) -> None:
        temporary, root = self.make_fixture()
        self.addCleanup(temporary.cleanup)
        path = root / ".grok/workflows/studio-dcc-map-glb.rhai"
        path.write_text(
            STUDIO.replace('if task_id == "" { task_id = task_id_from(gen); }\n', ""),
            encoding="utf-8")
        errors = CONTRACTS.validate_repository(root)
        self.assertTrue(any("task_id_from(gen)" in error for error in errors), errors)

    def test_deprecated_workflow_cannot_return_to_active_directory(self) -> None:
        temporary, root = self.make_fixture()
        self.addCleanup(temporary.cleanup)
        path = root / ".grok/workflows/first-paid-map-glb.rhai"
        path.write_text("historical\n", encoding="utf-8")
        errors = CONTRACTS.validate_repository(root)
        self.assertTrue(any("must not remain active" in error for error in errors), errors)

    def test_audio_selection_requires_real_audition_capability(self) -> None:
        temporary, root = self.make_fixture()
        self.addCleanup(temporary.cleanup)
        for relative in (
            ".claude/skills/glassvow-suno/SKILL.md",
            ".claude/skills/glassvow-elevenlabs/SKILL.md",
        ):
            path = root / relative
            path.write_text(
                path.read_text(encoding="utf-8").replace(
                    "approved audio-capable evaluator actually auditions every shortlisted candidate",
                    "owner agent scores every shortlisted candidate"),
                encoding="utf-8")
            errors = CONTRACTS.validate_repository(root)
            self.assertTrue(
                any(relative in error and "audio-capable evaluator" in error
                    for error in errors), errors)
            path.write_text(
                SUNO_SKILL if "suno" in relative else ELEVENLABS_SKILL,
                encoding="utf-8")

    def test_audio_selection_forbids_proxy_perception(self) -> None:
        temporary, root = self.make_fixture()
        self.addCleanup(temporary.cleanup)
        path = root / ".claude/skills/glassvow-suno/SKILL.md"
        path.write_text(
            SUNO_SKILL.replace(
                "Do not infer perceptual quality from prompts, filenames, metadata, waveforms, spectrograms, or codec statistics.\n",
                ""),
            encoding="utf-8")
        errors = CONTRACTS.validate_repository(root)
        self.assertTrue(any("Do not infer perceptual quality" in error for error in errors), errors)

    def test_audio_selection_keeps_one_bounded_owner_fallback(self) -> None:
        temporary, root = self.make_fixture()
        self.addCleanup(temporary.cleanup)
        path = root / ".claude/skills/glassvow-elevenlabs/SKILL.md"
        path.write_text(
            ELEVENLABS_SKILL.replace("one bounded owner audition and choice", "owner review"),
            encoding="utf-8")
        errors = CONTRACTS.validate_repository(root)
        self.assertTrue(any("one bounded owner audition and choice" in error
                            for error in errors), errors)


if __name__ == "__main__":
    unittest.main()
