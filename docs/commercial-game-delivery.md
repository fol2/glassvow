# Commercial Game Delivery — Policy & Boundaries

This document outlines reusable delivery policies for roguelite deckbuilders on
multiple platforms. The policy is engine-neutral; milestone gates may name a
project-specific target, metric and evidence set, as Glassvow §5 does below.

## 1. Save Versioning & Migration Policy

**Envelope structure:** Each save is a versioned container with a schema version, user-facing content, and metadata. Schema changes = version bump.

**When to migrate:**
- **Additive change** (new field with a safe default): bump minor version, apply default on load.
- **Removed field** (unsupported feature): bump major version, provide a migration handler or reject old saves.
- **Renamed or restructured field**: always a major version (break in contract).

**Web → native never migrates:** Save formats are platform-specific by design. A user's web progress is archived; native restarts the player at zero. (Exception: future web-to-web ports can migrate if schemas align, but this requires deliberate alignment.)

**Stale content handling:** On load, validate every content ID (card, relic, enemy, status) against the current content registry. Missing IDs are replaced with null/baseline values, or the entire save is rejected if critical IDs fail. This prevents crashes from removed content.

**Versioned lineage:** Each game/platform pins a save version. Once a milestone ships (e.g., M4 in this plan), that save version is frozen. Future schema changes start a new major version line (e.g., v2), with a migration story documented.

## 2. Platform-Adapter Boundary

**Storage contract:** The game logic writes a JSON envelope to persistent storage; the storage layer (OS-native APIs) handles the actual persistence. Layers:
- **Domain** (game logic): produces a normalized Dictionary/object.
- **Serialization** (encoder): converts to JSON, applying version and type rules.
- **Storage adapter** (platform-specific): `user://` URL or native file APIs. On load, the adapter returns JSON; the decoder parses and validates it.

**Cross-platform consistency:** Same JSON → same game state on any platform. JSON is the interchange format; no platform-specific binary blobs in saves.

**Locale separation:** Content IDs (the "true" names) are immutable; display strings are locale data. Saves store IDs only. Rendering picks the locale-appropriate display name at runtime. Changing a display string does NOT invalidate saves.

## 3. Determinism Contract

**One seeded RNG stream per run:** A run's seed produces exactly one pseudo-random stream (e.g., Mulberry32 or similar). Every random draw (shuffle, enemy AI, variance in damage) pulls from this stream in a fixed order. The stream state is persisted; resuming a run replays from the same cursor.

**Fixtures as spec:** Snapshot saves, action traces, and final outcomes are committed as JSON fixtures. A new implementation must reproduce these traces byte-for-byte (within numeric precision, e.g., same floor/round semantics for damage). Fixtures prove parity.

**No other randomness sources:** Wall-clock time, user input timing, network latency — none of these are game-state RNG. They may affect scheduling or UI, but not the run's outcome.

**Replayability:** Given a seed and a trace of actions, any implementation reproduces the same events and final state. This enables:
- Deterministic test fixtures.
- Replay mode (watch a previous run).
- Cross-platform sync (cloud save desync detection via trace).

## 4. Content-ID Stability

**IDs are immutable once frozen:** Internal IDs for cards, relics, enemies, statuses, and abilities are engine-level constants. Once a release ships with a set of IDs, changing an ID breaks all prior saves (they reference the old ID). Removals, renames, splits, and merges all require a save-version bump and migration logic.

**Display vs. internal:** Internally, a card is `"strike"` (the ID). The player sees "Strike", "鬥擊", or "Attaque" depending on locale. Display strings change freely; IDs do not.

**Content-addition gates:** Adding new content (cards, relics, enemies) is safe if IDs don't collide and the new content doesn't introduce dependencies on yet-unavailable features. Coordinate additions with the release checklist to avoid partial shipments.

**Deprecated IDs:** If an ID must be removed, leave a migration handler: "Card X was removed; players' decks that have it swap it for Card Y." This allows old saves to load without rejection.

## 5. Performance Budgets

**Targets are set at milestone gates.** The standing cross-platform targets are
60 FPS on the named device and cold save-load ≤2 seconds (for example,
"resume from kill"). Memory limits are device-specific and must name both the
metric and the device; renderer allocation, process physical footprint and RSS
are not interchangeable.

**Glassvow P8.1 proposed Mac gate (awaiting James's PM approval on PR #143):**

- Target: Mac mini `Mac16,10`, Apple M4, 16 GiB unified memory, macOS 26.6.1
  (25G76), official Godot 4.7.1 native `arm64`, Forward Mobile.
- Godot renderer allocation peak ≤1228.8 MiB.
- macOS process physical-footprint peak ≤1536 MiB.
- Observed whole-frame p95 ≤16.00 ms in every independent run.

These are proposed thresholds, not signed or approved thresholds. James's
approval of the final head of PR #143 makes this exact proposal the P8.1 gate;
the wording is ready for signature without a follow-up documentation edit.
Issue #105 measured a 50-row exported-combat matrix (five authored shapes ×
`en`/`zh-Hant` × five fresh processes) under the act-1 Leviathan boss,
seed 717, with 96 sustained VFX particles. Its maxima were 543.640625 MiB
renderer allocation, 1056.204544 MiB process physical footprint and 9.578 ms
observed whole-frame p95. The immutable [manifest](https://github.com/fol2/glassvow/blob/1ce1ce8915b33ae1914714a6b2c40af89fb6ac22/manifest.md)
and [summary](https://github.com/fol2/glassvow/blob/1ce1ce8915b33ae1914714a6b2c40af89fb6ac22/binding/summary.json)
bind measurement source `cf1b3d51af2992e1db8a419a49ff6254d6147581` and
verifier `5fb7d95a0bfa75953d184e172c3cd4a7d91d7786`.

On Apple unified memory, renderer allocation is not physical VRAM and must not
be added to process footprint. Physical footprint is macOS
`auxiliary.phys_footprint_peak`, not RSS. GPU time was unavailable on Metal;
zero reported by Godot does not mean free GPU work. Issue #105 did not measure
the standing cold save-load ≤2-second target; #108 remeasures it as a
release-candidate gate.

**Measurement:** Profile before optimizing. Common traps:
- Allocating per frame (pools, reuse).
- Sync I/O on frame boundary (async, or preload).
- Overdrawing (occlusion, batching).

**Upgrade path:** If a budget is exceeded, the project explicitly decides: add a new platform tier (e.g., "lite" mode on low-end), optimize the hot path, or scope-cut. Never ignore a miss; never add "we'll optimize later" without a specific plan.

## 6. Release Gates & Stop Conditions

**Milestone gates:** Before advancing, verify:
- All acceptance tests green (parity fixtures, if applicable).
- No regressions in previous milestones.
- One human visual review (art, UI, gameplay feel) passes.
- Performance budgets met on target device.

**Stop conditions (halt and re-plan):**
- **Schema change** — save format breaks compatibility without a migration story.
- **New platform plugin work** — native SDK integration (e.g., push notifications, in-app purchase) is a separate deliverable and expertise.
- **Scope creep >threshold** — a single task balloons beyond estimation (e.g., >400 line changes). Stop, surface findings, produce a revised plan.

**Red = handled event, not emergency:** A failed test or CI gate means the change is incomplete. Fix it, re-run, and advance. There is no "we'll ship it anyway and fix it later" for save-critical or determinism-critical code.

**Deliberate simplifications:** Mark known ceilings with a searchable comment:
```
# ceiling: global lock; per-account locks if throughput matters
# ceiling: O(n²) search; hash-table indexing if content scales
```

This acknowledges the trade-off and documents the upgrade path for future scale.
