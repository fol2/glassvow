# Visual direction — decisions ledger

Recovered 2026-07-26 from the six CLI session transcripts that the desktop app
never indexed (see the session-recovery note below). This is the standing record
of what was **chosen** and what was **rejected** across the card line and the
four parallel worker sessions, so the decisions survive the session layer.

Nothing here is new design. Where a decision was reversed, the reversal is
recorded — the rejections are the expensive part.

## Standing constraints (all sessions)

- Discussion in Cantonese; working notes and code in UK English.
- The visual standard is **`roguecardv2@6e069118`** — the pre-pixi approved
  visual. Web `main` is itself a regression and is *not* the target. The
  benchmark runs live at `localhost:5190`.
- Parity work reads the **source**, never samples the render.
- `port_fixtures/` is generated only by `roguecardv2/tools/capture-port-fixtures.mjs`
  and is never hand-edited here.
- Shared tree, five concurrent sessions: **commit with explicit paths only,
  never `git add -A`**.
- Worker sessions build 2–3 variants, screenshot each, and **stop** —
  "THE DESIGN DECISION IS NOT YOURS."
- Every session independently asked for the same thing: an **interactive
  viewer/editor**, not a PNG dump.

## Card line — "beyond the benchmark"

Run one topic at a time, user-paced. Assets were all brought into Godot and
cards resampled to 2048px; the exporter was widened so all 61 cards are
available.

| Topic | Outcome |
|---|---|
| Card shape | Defined a real silhouette — the hover beam had been escaping the card |
| Edge & outline | Encodes **both** card type and rarity |
| "The cards are flat, but they are not flat" | Every card became a real 3D glass slab. Tilt approved. Drop shadow first read as a detached halo → fixed. **Variant A kept.** |
| "Rarity pill fade away, feel rarity with texture" | Layered surface system, deliberately **not bound to rarity**: **material → texture → finish → card stock**. Many types must be possible, not 3–4. |
| "Mouse pointing, not mist, it is real light" | Real spotlight interaction with the surface layers |
| "Gem is real gem" | Cost hexagon polish |

### Recipe assignments

- **Rare** — `cosmos-art`, later narrowed to a cosmos variation **without the
  bigger dots**; texture `soft-touch`.
- **Uncommon** — `pearlescent`, settled as **Recipe Opal**.
- The original metallic coating caused a horizontal lightbar across uncommon and
  rare under the lamp. Reassigning the coatings fixed it.

### Reversals worth remembering

- **`cosmos-fine` was reverted entirely** — "act as I never asked for
  cosmos-fine". It looked like coloured dust rather than premium holo, and the
  settings leaked into every other card. This is the concrete case behind the
  per-recipe-knobs rule: tune one recipe without touching the shared model.
- **Holo does not mean rainbow colour.** It means dots at *different depths*
  that separate when the card tilts.
- Idle is the card's normal state. An effect strong enough to obscure the text
  at rest is wrong however good it looks on hover — subtle at idle, shines on
  hover.
- The big dots in `cosmos` / `cosmos-art` should stay subtle and react only when
  the light beam passes over them.

A permanent card style editor/viewer exists for debug use — card selector, layer
toggles, mouse-over interaction. Not user-facing.

## Worker sessions

### Status & intent chips — `status_chip.gd`, `intent_chip.gd`, `chip_lab.gd`
The redesigns were declined; the benchmark-matching variant won.
**Open: polish that variant.**

### Enemies — `enemy_view.gd`, `glass_gem.gd`, `facet_pips.gd`, `enemy_lab.gd`
An enemy is **not a card** — rendering one as a card was a port mistake.
The cleaner mob was accepted as a new baseline. The shatter moment was rejected
twice: it read as shattering a pane *in front of* the mob rather than the mob
itself, and the shards stood upright afterwards. Left at "working again", not
finished.

**Open:** redo the shadow properly now that the platform allows it (the old
complexity was a web limitation, not a design choice); list which animations
should and should not exist, then work the checklist. **Scope now includes
heroes** — same treatment, no separate session for them.

### Reward screen — `presentation/reward/`, `reward_lab.gd`
**"Ember" is the chosen variant.** Open: polish ember.
Fixed along the way: a truncated gem. Standing note: do not move the default lamp.

### Combat HUD — `hud_bar.gd`, `hud_lab.gd`
**All redesigns rejected.** "None of your work is better than original one…
UI simplicity is important, UI is never the main character." Reward is out of
this session's scope.

**Open:** go back to the original design and polish where it is not yet living
natively in Godot. Unresolved question raised and never answered: the deck at
the bottom — should there be three decks, each with its own assets?

## Known cross-session breakage

`enemy_lab.gd` once broke `godot --path . -- --studio` for everyone with typed-GDScript
parse errors (warnings-as-errors: `Variant` passed where `Dictionary`/`float`/`bool`
was required). A lab file failing the parse gate takes down every lab entry point,
not just its own.

## Where the transcripts are

`~/.claude/projects/-Users-jamesto-Coding-glassvow/*.jsonl` — resume from a
terminal with `claude --resume <uuid>`:

| Session | UUID |
|---|---|
| Card line (orchestrator) | `ca1bf21d-8ae6-43ef-ae37-48fe690a9b23` — 238MB, slow to reload |
| Status & intent chips | `15dcffdb-69d8-4737-9e00-2f86ef59f80b` |
| Enemies | `fbe74755-0a27-4257-94d8-b8badd5e2d34` |
| Reward screen | `b3bb71f0-22ee-4756-b744-c9525a27b627` |
| Combat HUD | `6fa343a6-3da7-4669-8310-d89ae6934116` |
