---
title: "Edit Benchmark mobs as validated sparse complete-entry overrides"
date: 2026-07-31
category: tooling-decisions
module: presentation/lab
problem_type: tooling_decision
component: tooling
severity: medium
applies_when:
  - "Tuning generated mob mechanics without changing frozen identifiers or executable AI policy"
  - "Persisting selected content differences while keeping the checked-in catalogue legible"
  - "Building a Lab editor whose preview, applied state and saved JSON must not diverge silently"
tags: [enemy-lab, benchmark-parity, mob-overrides, content-validation, safe-save]
---

# Edit Benchmark mobs as validated sparse complete-entry overrides

> **Citation convention.** `6e06911` below is the pinned revision of the separate
> `~/Coding/roguecardv2-benchmark` reference repository, so a claims validator
> running against Glassvow will not resolve it here.

> **Amended by #323 (2026-08-16).** The pattern this document describes is
> unchanged and still correct. Its *premise* is not: `content/full-content.json`
> was a generated capture of `6e06911` when this was written, and is now
> port-authored and hand-editable. Read "the baseline" below as "the checked-in
> catalogue", not "the frozen upstream". The `original-content.json` overlay this
> document also described is gone, collapsed into that catalogue.

## Context

The checked-in content catalogue is `content/full-content.json`, but mob tuning
needs an authoring surface that shows what changed. Editing the catalogue in
place is legitimate for content decisions, yet it records a tuning experiment as
an indistinguishable edit among 5,485 lines. Copying the entire catalogue into a
second authored file would hide which mobs actually changed.

The content loader therefore keeps three states distinct: the checked-in
catalogue, the sparse override dictionary, and the effective catalogue consumed
by the game. `ContentDB.load_full()` loads the baseline first and applies
`content/mob-overrides.json` only when requested
(`content/content_db.gd:56-62`). `mob-overrides` is the only layer between the
two. The Enemy Lab separately loads
`ContentDB.load_full(false)` as its comparison baseline and derives the sparse set
from entries that differ (`presentation/lab/enemy_lab.gd:347-352`). The checked-in
override file can remain `{}` when there is no local tuning.

The editable boundary is also narrower than “anything in an enemy object”. The
Lab exposes serialisable mechanics while declaring names, IDs and AI policy
read-only (`presentation/lab/enemy_lab.gd:786-803`). Move IDs remain fixed because
executable AI selects them; enemy and move names remain localisation-owned. The
validator enforces both boundaries (`content/content_db.gd`
(`enemy_override_faults`) and its per-entry half, `content/content_db.gd`
(`enemy_faults`)).

## What Didn't Work

- Validating only that a mob ID exists was too weak. A known mob could still carry
  a malformed HP range, an unknown art kind, a missing AI move or a bad status
  reference.
- Treating in-memory all-or-nothing application as the whole atomicity story left
  the authored file exposed. Opening the destination for writing first can
  truncate its only copy before replacement is ready.
- A single “dirty” flag could not distinguish applied changes awaiting Save from
  JSON text that had never been applied. Saving the former while the latter was
  visible would silently lose the visible edit.
- A partial deep-merge format looked smaller but would need extra semantics for
  missing keys, `null`, deletion, arrays and nested move dictionaries. Sparse
  complete entries give the smaller contract.

## Guidance

### Be sparse between mobs and complete within each changed mob

Leave the checked-in baseline alone for *tuning*; a balance decision may edit it,
but a Lab experiment must not. Store only changed mob IDs in
`content/mob-overrides.json`, but store each changed mob as a complete serialisable
definition. Apply is then a whole-entry replacement, not a recursive patch. When
an edited definition matches the baseline again, remove its ID from the override
dictionary (`presentation/lab/enemy_lab.gd:1062-1077`).

Complete-entry validation should cover the actual trust boundary: HP shape and
range; tier flags; facets; recognised art kinds and bounds; known starting
statuses; the exact baseline move-ID set; move intents and numeric values; effects;
referenced cards; and unchanged locale-owned names
(`content/content_db.gd:85-97` (`enemy_override_faults`)). Do not put executable AI or localisation into
the JSON editor merely to make the object appear more complete.

### Validate the whole candidate before mutating anything

Validation and application must be separate passes:

```gdscript
var faults := enemy_override_faults(raw)
if not faults.is_empty():
    return faults
for id in raw:
    enemies[id] = raw[id].duplicate(true)
```

This is the ordering in `ContentDB.apply_enemy_overrides()`
(`content/content_db.gd:74-83` (`apply_enemy_overrides`)). The regression check supplies a dictionary with
both a broken known mob and an unknown ID, then confirms the known mob was not
partially changed (`tests/test_content.gd:97-116` (`_enemy_overrides`)). Validation interleaved with
assignment would fail that guarantee.

### Preview through effective content, not a private editor model

Apply and Reset update both the Lab roster and the injected `ContentDB` used by
runtime consumers (`presentation/lab/enemy_lab.gd:1062-1097`); Apply first
validates the single entry through `_benchmark.enemy_faults()`
(`presentation/lab/enemy_lab.gd:1066`), while the whole-dictionary
`enemy_override_faults` still guards Save. The frozen baseline
is retained only for comparison and reset. This keeps the picture under review
and the content the game will consume on the same path.

### Track text-dirty and file-dirty as different states

`_mob_text_dirty` means the editor contains JSON that has not passed Apply;
`_mob_file_dirty` means an applied override state is pending Save. The resulting
transitions are deliberate:

- **Apply** validates the selected definition, updates effective content, clears
  text-dirty and leaves a save pending.
- **Discard** restores the selected mob's applied JSON without changing the
  pending override dictionary.
- **Reset** restores the frozen definition, removes its override and leaves a save
  pending.
- **Save** refuses while text is dirty, validates the entire override dictionary
  again, and only then writes it.

Selection is also refused while text is dirty, so changing mobs cannot overwrite
an unapplied edit (`presentation/lab/enemy_lab.gd:1038-1059`,
`presentation/lab/enemy_lab.gd:1100-1115`).

### Serialise first, then replace the file

Use the shared `DataFile` boundary rather than letting each Lab invent a writer.
It emits stable two-space JSON with a trailing newline, rejects empty output and
Web writes, writes to a sibling temporary, flushes and closes it, then replaces
the destination. A failed open or replacement returns an error instead of
reporting success (`presentation/data_file.gd:26-56`).

This disk guarantee is independent of all-or-nothing content application. Both
are required: validation protects the effective catalogue; sibling replacement
protects the previously saved authored file.

## Why This Matters

The checked-in catalogue stays the single readable record of authored content, the
override file shows only deliberate local tuning, and the game consumes a
validated effective catalogue.
Invalid multi-mob input cannot half-apply, fixed IDs cannot drift away from AI,
unapplied text cannot masquerade as saved work, and a save does not begin by
truncating the destination.

The result is a narrow editor rather than a second content system. It reuses the
existing Lab, content loader and shared writer, and adds no generic patch language
or data-driven AI layer.

## When to Apply

- Use this pattern when a large checked-in catalogue must stay legible as a record
  while a bounded serialisable subset needs experimental tuning.
- Use it when entries are small enough that a complete replacement is easier to
  validate and review than field-level patch operations.
- Do not use it for executable policy, localisation or migrations.
- If entries become too large for complete replacement, define explicit
  field-level operations and their deletion semantics instead of quietly adding a
  generic deep merge.
- If several processes must write concurrently, replace the single-writer sibling
  temporary with an explicitly locked persistence design.

## Examples

A safe HP tune starts from the complete effective `duskfang` definition, changes
only its `hp`, and retains its art, move definitions and read-only identity fields.
The saved dictionary contains one complete `duskfang` entry. Reset removes that
entry from the pending override dictionary; after Save, if it was the only
override, the canonical file returns to `{}`.

`{"duskfang": {"hp": [31, 35]}}` is not a supported small patch. As a whole-entry
replacement it would discard required fields; as a deep merge it would introduce
an undocumented patch language. A definition that removes `bite`, adds `chomp`,
changes a localised name or invents `art.kind = "slmie"` is likewise refused by
the current boundary.

## Related

- [Drive the lab the way the game drives it](./drive-the-lab-the-way-the-game-drives-it.md)
  — the companion rule that an isolated Lab must exercise production setup and
  arguments before its preview can be trusted.
- [Measure the running reference, not the tables it publishes](../conventions/measure-the-running-reference-not-its-tables.md)
  — source data is the baseline; the effective rendered result is the parity
  evidence.
- `CONCEPTS.md` › **Benchmark** and **Lab** — the shared vocabulary for the frozen
  authority and its isolated tuning surface.
- `docs/dev-tools.md` — the governed Enemy bench entry point and its Native
  Proof-only save boundary.
