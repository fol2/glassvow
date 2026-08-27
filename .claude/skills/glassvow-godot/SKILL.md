---
name: glassvow-godot
description: Progressive-disclosure contract for Glassvow Godot runtime, test, scene, resource, import, and visual work. Do not load for docs-only work or pure Python balance research.
---

# Glassvow Godot Delivery Contract

## 1. Scope

Load this skill only when the task touches Godot runtime code, tests, scenes, resources, imports, visual composition, or engine-facing tools. `AGENTS.md` and `docs/agents/ai-sdlc.md` govern the development loop; this file supplies Godot-specific invariants.

Pure documentation and isolated Python balance or ML research do not need this context and must not inherit the Godot gate merely because the repository is a game.

## 2. Engine contract

The minimum is Godot 4.7.2 stable; later stable releases are supported. Reject older and pre-release builds. A release or evidence protocol may bind one exact supported version, and historical evidence keeps the version it actually used.

Before engine work, check `godot --version`. Do not install or replace the provisioned Cloud Agent toolchain unless the environment contract explicitly says it is missing.

Godot 4.7 traps that matter here:

- Typed-return overrides need an explicit return on every path.
- Modifying a temporary value can trigger `CONFUSABLE_TEMPORARY_MODIFICATION`; assign, mutate, and write back.
- `godot --check-only` reports parse failures on stderr while often exiting zero. Never grade it directly; use `tools/check_scripts.sh`.

## 3. Architecture boundaries

- `domain/` contains pure `RefCounted` game logic. It must not depend on Node, SceneTree, FileAccess, DirAccess, Input, DisplayServer, OS, or `get_tree()`.
- `GlassvowGame.apply(cmd: Dictionary) -> Array[Dictionary]` is the command-to-event seam. Event type constants live under `domain/events/`; presentation casts fields at the boundary.
- `application/main.tscn` is the composition root. Do not add a global EventBus or manager singleton.
- Presentation subscribes to events and renders state; it never becomes the source of game truth.

Search `CONCEPTS.md` for task terms and read only matching sections. Read a relevant ADR or solution note when the changed surface points to one; do not preload all historical design material.

## 4. IDs, locale, determinism, and saves

Internal `StringName` IDs for cards, relics, enemies, statuses, and abilities are compatibility keys. Change display strings in locale or content data, not internal IDs. An ID change requires an explicit migration design.

All gameplay randomness flows through the run's seeded RNG cursor. Do not introduce another random source. Dictionary events and cast-at-boundary semantics remain the serialization and test seam.

The live save lineage is the v2 run/vigil pair. A breaking envelope or top-level schema change requires a version bump and migration handler. Loading validates every saved content ID; unknown IDs reject the whole save rather than being silently dropped or substituted.

## 5. Editing methods

- Hand-edit small scripts and simple project or resource values.
- Use the Godot editor for significant `.tscn` composition and save the generated result.
- Use the Funplay MCP for large presentation restructuring, hierarchy inspection, and screenshot-driven iteration.
- Never edit `.godot/` or hand-edit generated import sidecars.
- Include required `.import` and `.uid` sidecars with the asset they describe.
- Keep one delivery outcome on one branch. Do not let another agent or machine mutate the same branch or worktree.

## 6. Risk-proportional verification

`tools/ci_scope.py` is the CI selection authority. Pull requests parse changed GDScript through the shared explicit-path gate, run the complete discovered Godot suite for Godot-code changes, and add only the specialist checks justified by overlapping scopes. Main and manual runs execute every maintained check.

During iteration, run the narrow deterministic check that answers the current question. Once a production Godot change is coherent, run the core final-candidate gate once before first push:

```bash
godot --version
tools/check_imports.sh
tools/check_scripts.sh
godot --headless -s res://tests/run_all.gd
```

Grade `tests/run_all.gd` by its process status and `PASS (N tests)` line. The headless dummy renderer can emit harmless leaked-RID or null-material warnings on stderr; do not turn those into failures when the runner exits 0.

Add the specialist map, locale, performance, release, or containment check only when that surface changed. Stage new `.gd` files before the full script sweep because `tools/check_scripts.sh` discovers tracked scripts with `git ls-files`.

For a focused component proof, parse only the owned files and use the filtered runner:

```bash
tools/check_scripts.sh presentation/map/map_waylight_tracer.gd tests/test_map_waylight_tracer.gd
godot --headless -s res://tests/run_all.gd -- \
  --tests=res://tests/test_map_waylight_tracer.gd
```

The filtered runner rejects missing, duplicate, malformed, and outside-`tests/` paths. It does not replace the complete final-candidate gate for production delivery; it keeps component evidence from replaying unrelated tests.

Never run unrelated suites to manufacture confidence, and never skip a relevant check. If the classifier misses a real dependency, run the needed check immediately, then extend `tools/ci_scope.py` and `tests/test_ci_scope.py` so the correction becomes permanent.

## 7. Visual and audio proof

Any layout, composition, animation, VFX, shader, camera, or audio-routing change requires inspection of the running result at the affected reference shapes. Use Funplay capture when the editor or runtime bridge is available; otherwise use `tools/shot.sh` or `tools/live.sh` as documented in `docs/dev-tools.md`.

A deterministic upstream gate should prove resolved values, state transitions, geometry, or contracts. A capture proves composition and perception. One does not replace the other. On headless Cloud Agents, captures require `xvfb-run` and an on-screen position; never use `--headless` for a viewport capture.

## 8. Fixtures and external reference

`port_fixtures/` contains port-owned goldens. A deliberate behaviour change may update a fixture in an explicit commit describing what changed and why. Never edit a golden merely to clear a failure.

The former web implementation is detached and is not a product oracle. Do not add new web-reference citations. When historical source must be inspected, use the pinned commit named in `docs/benchmark-divergence.md`, and never infer rendered behaviour from a function merely existing in source.

## 9. Stop conditions

Stop and produce a concrete blocker or separate migration or platform plan when any of these appears:

1. A breaking save-schema or internal-ID change.
2. Native Android or iOS plugin or SDK integration.
3. More than 600 additions plus deletions in one code file in one commit.
4. An unavailable relevant gate or evidence surface.
5. A requested change that contradicts the commercial rubric, an active architecture contract, or the task's acceptance criteria.

Do not weaken the requirement to keep moving.
