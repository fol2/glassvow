---
title: Verify whole-run routes with headed input and throwaway application drivers
date: 2026-07-29
category: workflow-issues
module: application/main
problem_type: workflow_issue
component: development_workflow
severity: high
applies_when:
  - A Godot gameplay flow crosses presentation input, application routing, domain commands, and durable resume state
  - Focused shared-law tests pass but do not prove that the composition root joins the complete run correctly
  - Real pointer input is needed while exhaustive progression would be slow or fragile to repeat by hand
  - Application-level coverage is needed once without committing a permanent UI-test harness
resolution_type: workflow_improvement
tags: [godot, flow-verification, headed-testing, headless-driver, application-routing, save-resume, real-input, test-harness]
---

# Verify whole-run routes with headed input and throwaway application drivers

## Context

A full roguelite run crosses UI, application routing, combat, rewards,
persistence, terminal outcomes, and meta-progression. No single verification
mode proves all of that.

Glassvow's `Main` owns the one game instance and routes the title, checkpoints,
map, combat, and terminal screens (`application/main.gd` (`Main`)). New and
resumed runs are built around the real `GlassvowGame`, map, and persisted run
state (`application/main.gd` (`_new_run`), `application/main.gd`
(`_continue_run`)). `_route_run()` then restores pending Dawn,
run-end, Hollow, reward, combat, monument, boss-relic, and Lamplighter routes
before returning to the map (`application/main.gd` (`_route_run`)).

That production composition root is the useful end-to-end seam. The goal is not
a permanent UI automation framework. It is bounded evidence that the shipped
pieces join correctly.

## Guidance

Use two complementary checks.

1. **Use headed, real-input play for presentation and interaction.** Start the
   actual game through `tools/live.sh`, then use its key, action, click, and drag
   commands against the long-lived Godot process
   ([`tools/live.sh`](../../../tools/live.sh)). Cover representative screen
   changes, card and target interaction, and at least one reload of each
   save-critical pending state. This proves that controls are visible, reachable,
   and wired. A screenshot alone is not full-flow proof:
   [`tools/shot.sh`](../../../tools/shot.sh) is the one-off capture path, while
   `tools/live.sh` is the interactive iteration loop.

2. **Use a throwaway headless driver for breadth and durable transitions.** Put
   a short GDScript under `/tmp`, instantiate `application/main.tscn`, choose
   nodes from the real map, and call the same `Main` routes and choice handlers
   as the application. Drive combat with legal commands through the game facade:

   ```gdscript
   extends SceneTree

   func _initialize() -> void:
       var main: Main = load("res://application/main.tscn").instantiate()
       root.add_child(main)
       await process_frame
       if FileAccess.file_exists(SaveService.RUN_PATH) \
               or FileAccess.file_exists(SaveService.VIGIL_PATH):
           push_error("Refusing to overwrite an existing profile")
           quit(2)
           return

       main._forced_seed = 717
       main._new_run({"aspect": 0, "vow": 0})
       await process_frame
       var run_id: String = main.game.run.run_id
       var node_index: int = main._map.reachable()[0]
       main._map.enter(node_index)
       main._on_node_chosen(node_index)

       # A real driver chooses only commands accepted by CombatRules.
       main.game.apply({"t": "endTurn"})
       if not SaveService.clear_run(run_id):
           push_error("Test run cleanup failed")
           quit(3)
           return
       quit()
   ```

   `GlassvowGame.apply()` is the shared command facade for combat operations
   such as `startCombat`, `playCard`, and `endTurn`
   (`domain/game.gd` (`GlassvowGame`), `domain/game.gd` (`apply`)). Directly
   setting HP, clearing enemies, or manufacturing a successful handler result
   bypasses the rules and proves less.

Let the driver exercise persistence boundaries as well as the happy path.
Encounter selection stores the pending combat before opening the battlefield
(`application/main.gd` (`_prepare_encounter`), `application/main.gd`
(`_resume_pending_combat`)); victory stores the pending reward before presenting
it (`application/main.gd` (`_on_combat_over`)); `_route_run()` restores both.
`SaveService` writes run and Vigil JSON beside the target, flushes, and replaces
it atomically (`application/save_service.gd` (`_store_json_atomic`)). Terminal
completion commits the Vigil, persists Dawn, advances its cursor durably, and
clears only the matching run (`application/main.gd` (`_on_terminal_commit`),
`application/main.gd` (`_show_dawn`), `application/main.gd`
(`_on_dawn_continue`)).

Parse-check the throwaway driver before accepting its run. The first driver in
this programme did not count until its inferred-static warnings were replaced
with explicit types under the project's warnings-as-errors configuration
(session history).

Preflight player data before the run. If the normal v2 save or Vigil already
exists, do not repurpose or clear it. Use a disposable profile context or stop.
After verification, remove only the driver and state carrying the known test
run IDs, then confirm both are absent.

Do not retain a large one-off harness. Promote only stable shared laws into the
permanent suite. The existing quest check accelerates Hollow, Lamplighter, six
unique shards, and a reachable Act IV node at the domain level without
pretending to prove rendered UI (`tests/test_quests.gd` (`run`)).

Treat diagnostics by provenance. In this run, the dummy renderer's
`material is null` messages were known headless noise; the explicit result line,
exit status, and final project gates determined success (session history). Do
not generalise that exception to a new error, crash, missing transition, or
absent result line.

## Why This Matters

Headed play is strong where headless execution is weak: it proves actual pixels,
hit targets, and input wiring. The throwaway driver is strong where manual play
is expensive: it can deterministically traverse dozens of nodes and fights,
reload checkpoints, and cover death and cross-run progression.

The split prevents false confidence in either direction. Source or handler
reachability does not prove that a button renders and can be pressed. A few
attractive screenshots do not prove that a long run, resume, or progression
boundary completes.

It also keeps the regression budget honest. Application-level orchestration is
used long enough to answer the release question, then removed; the permanent
suite remains focused on laws whose breakage is worth maintaining a check for.

## When to Apply

- A milestone spans several real screens and durable states.
- Manual completion is long or stochastic.
- The application has a stable composition root and a legal domain-command
  seam.
- Focused tests are green but do not establish the assembled player journey.

Use headed play alone for a purely visual claim. Use a focused permanent test
for a small shared invariant. Use headless execution alone only when pixels and
physical input are explicitly outside the claim.

## Examples

The headed pass used actual controls through Title → Embark → Vow → map →
combat → reward, then relaunched the application to restore both a pending
reward and a frozen pending combat. This was session evidence for rendered
interaction and resume behaviour, not a conclusion inferred from source.

The whole-run driver reported:

```text
FLOW_RESULT PASS nodes=45 fights=25 wins=1 hp=closed
```

It instantiated the real `Main`, selected real map nodes, sent legal combat
commands through `GlassvowGame.apply()`, and used actual route and choice
handlers. A second accelerated run reported:

```text
PROGRESSION_RESULT PASS death=1 monument=1 hollow=1 lamplighter=1 shards=6 act4=entered
```

That run found the production Act IV `Button` node and emitted `pressed`; the
button emits the same route ID as headed input
(`presentation/run/choice_screen.gd` (in `_init`)). This proved the choice wiring
and boundary route, whose production screen lives at `application/main.gd`
(`_show_act4_entrance`). It did **not** prove Act IV pixels in a headed renderer.
Both drivers and their test saves were deleted after the run.

The final gates recorded the repository-pinned Godot and benchmark revisions, a
clean import, 89 strict script parses, and 13 passing tests. These are session
results; the repository defines the required versions and commands in
[`AGENTS.md`](../../../AGENTS.md).

## Related

- [Drive the lab the way the game drives it](../tooling-decisions/drive-the-lab-the-way-the-game-drives-it.md)
  — the same production-faithful rule at presentation-lab scope.
- [Long-lived capture host, not process-per-shot](../tooling-decisions/long-lived-capture-host-not-process-per-shot.md)
  — why headed pixels and repeated real input use the live host.
- [Measure the running reference, not its tables](../conventions/measure-the-running-reference-not-its-tables.md)
  — the broader rule that source agreement is not runtime evidence.
- [Session ownership](../../session-ownership.md) — shared capture-tool ownership
  and operating boundaries.
- [Commercial game delivery](../../commercial-game-delivery.md) — determinism,
  replayability, and release-gate policy.
