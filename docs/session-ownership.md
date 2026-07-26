# Parallel lanes — ownership, rules, and the cross-lane queue

Six Claude Code sessions share this tree and this `main` branch. Until now the
ownership boundary lived in one session's private memory, which meant five of
the six could not read it. This file is the shared copy.

Companion documents: `docs/visual-direction.md` (what was **decided**, including
the rejections) and `docs/port-status.md` (what has **landed**).

## Why the boundary exists

Two failure modes have already happened, both silent:

- **`git add -A` sweeps up another lane's half-finished work.** A commit that
  looks like one lane's change carries another lane's broken intermediate state.
- **A parse failure in one lab file takes down every lab.** `enemy_lab.gd` once
  broke `godot --path . -- --studio` for all six sessions with typed-GDScript
  errors (warnings-as-errors: `Variant` passed where `Dictionary`/`float`/`bool`
  was required). The labs share one entry point in `application/main.gd`, so a
  red file is not a local problem.

## Lanes

| Lane | Owns | Session |
|---|---|---|
| **Card** | `presentation/combat/` — `card_view.gd`, `card_surface.gd`, `card_surface.gdshader`, `card_edge.gdshader`, `card_gem.gdshader`, `rules_text.gd` · `presentation/lab/card_lab.gd`, `card_studio.gd` | `ca1bf21d` |
| **Enemy / hero** | `presentation/combat/` — `enemy_view.gd`, `glass_gem.gd`, `facet_pips.gd`, `status_row.gd` · `presentation/lab/enemy_lab.gd` · `assets/art/enemies/char-meta.json` · **`combat_screen.gd`** (see below) | `fbe74755` |
| **Reward** | `presentation/reward/` — all nine `.gd` and both `.gdshader` · `presentation/lab/reward_lab.gd` | `b3bb71f0` |
| **Combat HUD** | `presentation/combat/hud_bar.gd` · `presentation/lab/hud_lab.gd` | `6fa343a6` |
| **Status / intent chips** | `presentation/combat/status_chip.gd`, `intent_chip.gd` · `presentation/lab/chip_lab.gd` | `15dcffdb` |
| **Assembly** | `application/main.gd`, `main.tscn`, `save_service.gd` · `presentation/combat/event_sequencer.gd`, `hand_view.gd` · `project.godot` | `4bb74d72` |

**`combat_screen.gd` is contested.** It moved to the Enemy / hero lane on
2026-07-26 when that lane's scope was extended to cover heroes, for the hero
placement and § 4's screen-level effects
(`docs/actor-animation-checklist.md` §5.1, §4). The Assembly lane has since
written `docs/assembly-integration-plan.md`, whose S1–S3 restructure the same
file around a real ported stage — on the finding that
**`assets/art/stage/` holds nine committed PNGs that not one `.gd` file loads**,
so the M5d craft pass invented a look rather than porting one. Verified: zero
loaders.

The two plans do not disagree about the destination. Assembly explicitly defers
the contested part (D1, the hero as an actor) to the Enemy lane and says to
rebase onto the chip wave rather than plan around it. What is missing is an
**order**, and the natural one is Assembly first: its stage establishes the
ground line that every hero-placement number is then measured against.

Each lane's current open item is in `docs/visual-direction.md` under **Worker
sessions**; the card line's is under **Card line**. The Enemy / hero lane's is
now the full checklist in `docs/actor-animation-checklist.md`.

## Shared surfaces — nobody owns these, everybody reads them

- **`presentation/combat/glass_style.gd`** — the palette and stylebox factory.
  **23 files consume it.** It is the highest-blast-radius file in the tree and
  the one most likely to be edited by two lanes at once for opposite reasons.
- **`application/main.gd`** — the single lab registry. Every lab is reachable
  only through the flag loop there. Its own comment states the contract: *each
  lab reads `OS.get_cmdline_user_args()` itself rather than growing this loop*,
  so adding a knob to your lab is a lane-local change, not a shared one.
- **`CONCEPTS.md`, `AGENTS.md`, `docs/`** — append-only in practice. Two lanes
  appending in the same minute will conflict.
- **`domain/`, `content/`, `port_fixtures/`, `tests/`** — off-limits to visual
  work entirely. `port_fixtures/` is generated only by roguecardv2's
  `tools/capture-port-fixtures.mjs` and is never hand-edited here.

**Rule for shared surfaces:** do not edit them from a lane. Raise it with the
organiser, who sequences the change into one lane at one time. A palette change
in particular must be a deliberate cross-lane event, because every lane's
screenshots stop being comparable the moment it lands.

## Git rule

Commit with **explicit paths only**. Never `git add -A`, never `git add .`.
Before committing, run `git status --short` and confirm every staged path is one
this lane owns.

## Gate rule

Do **not** run the full suite (`godot --headless -s res://tests/run_all.gd`)
from a lane — it may be red for reasons that belong to another lane, and the
result is not information about your change. Gate per file instead:

```bash
godot --headless --check-only -s presentation/combat/card_view.gd
```

The organiser runs the whole-tree parse gate and the suite, and owns the verdict.

## Cross-lane queue

Work that cannot be finished inside one lane, because it edits files two or
three lanes own. These wait for the organiser to sequence them.

1. ~~**Wire the chips into the game.**~~ **Done in flight, uncommitted as of
   2026-07-26 12:27.** The Enemy / hero lane landed it: `_player_statuses` and
   the actor's status line both became `StatusRow`, the actor's hand-built ember
   panel became a real `IntentChip`, and `combat_screen` now passes the move's
   `intent` id rather than a formatted string. `intent_chip.gd` was touched, but
   only to harden `primary()` against an empty id — `"".split("_", false)[0]`
   indexed past the end of an empty array. That is a bug fix in the consumed
   widget, not a redesign of it, which is the correct way to cross into another
   lane's file. **The chip lane should be told before it polishes on top of a
   file it no longer solely controls.**
2. **CONTRADICTION — who owns the player's ward chip and HP rail?** Two lanes
   have written down opposite answers, in two documents, about a file neither of
   them owns:

   - `docs/actor-animation-checklist.md` §5.1 (Enemy / hero lane): *"the chrome
     does **not** mirror a foe's foot plate: `hud_bar.gd` already carries the
     hero's HP and ward, by its own lane's design."*
   - `docs/assembly-integration-plan.md` D2 (Assembly lane): *"The benchmark says
     the actor owns it. Confirm `HudBar._build_plate()` goes unused rather than
     both being wired."*

   The file in question is `hud_bar.gd`, which belongs to the **HUD lane** — and
   which that lane is editing right now. Three lanes, two written positions, no
   owner in the conversation.

   **Read from the benchmark source, the answer is that both are right about
   different elements, and neither's work is wasted.** The benchmark has *two*
   HP readouts and they are not the same one:

   - **`#hud` › `.hud-hp-wrap`** (`src/ui/combat.js:145-148`) — a heart icon, a
     `hp / maxHp` numeral and a `.hud-hpbar` rail. This is **run** chrome: it is
     hidden on title, embark, vigil, end and lamplighter (`:138`), and shown on
     every other screen. It carries gold, act, floor, boss, deck, menu, relics
     and omen alongside the HP.
   - **`.player-zone` › `.cplate`** (`src/ui/combat.js:232`) — a `.hpbar-wrap`
     holding `[block-chip][hp-vial][hp-label]`. This is the **combat actor's**
     plate, structurally identical to an enemy's (`:287`) minus the name and the
     facet row, and it hangs off the bottom of the hero's own box.

   `hud_bar.gd` has already built **both**, correctly and to spec:
   `_build_top_bar()` (`:349`, `HP_WRAP_W` 170) is the first; `_build_plate()`
   (`:473`, `PLATE_PARITY_W` 150, `.hpbar-wrap` verbatim) is the second.

   So the disagreement was never about *what* the plate is — only about *where
   it hangs*. It sits in the HUD layer today because there is no hero body to
   hang it off. Once the hero becomes an actor, `EnemyView` already carries that
   exact shape for foes, so `HudBar._build_plate()` does fall out of use — but
   `_build_top_bar()`'s HP **must stay**, because it is a different element of
   the benchmark and deleting it would lose the run readout.

   The Enemy lane's §5.1 note is therefore true as a description of today and
   wrong as a statement of design: it is a temporary arrangement, not a
   deliberate divergence from the benchmark.

3. **The deck at the bottom of the HUD.** Raised in the HUD lane and never
   answered: should there be three decks, each with its own assets? The answer
   changes `hud_bar.gd` and `combat_screen.gd` together — and `combat_screen.gd`
   is now contested between the Enemy / hero and Assembly lanes (see below).
3. **Screen shake sits at the wrong level.** It runs inside each actor's own
   `SubViewport`, so it shakes one creature's private stage while the rest of the
   battlefield holds still (`docs/actor-animation-checklist.md` §4.3). The fix is
   structural and belongs to the battlefield, not to an actor.
4. **Any `glass_style.gd` change.** See above.

## Standing risk: the per-actor 3D stage — **measured**

`docs/actor-animation-checklist.md` §5.4 flagged this as unmeasured. It has now
been measured: **`docs/actor-stage-frame-budget.md`**, tool at
`tools/bench_actor_stage.gd`.

Short version: **frame time passes with room** — a real fight costs about 0.9 ms
of the 16 ms budget, so the checklist's PORT items are not blocked. **Memory does
not** — roughly 113 MB of video memory per actor, 310 MB for a four-actor fight,
before any texture, UI or audio. And the memory budget in
`commercial-game-delivery.md` §5 is literally written "≤X MB" — **never filled
in**, so no pass can be declared against it. Setting that number is a gate
decision.

Knobs are priced in that note — MSAA, `oversample`, and the fact that all 245
textures import lossless with no VRAM compression at all. **None of them is to be
turned yet.** Ruled 2026-07-26: optimisation waits for a real battlefield that
has been visually approved, because every one of these is a visual trade and the
screen to judge it against does not exist yet. The measured figures are also a
floor — the stage restructure adds to them — so when the battlefield lands the
probe gets re-run rather than the old prices re-used.

## Organiser-owned files

`tools/` and the coordination documents (`docs/session-ownership.md`,
`docs/actor-stage-frame-budget.md`) belong to the organiser. `tools/` is
deliberately not `tests/`: `tests/run_all.gd` discovers only
`res://tests/test_*.gd`, so a probe there would never join the suite by accident.

## Shared dependency: the visual benchmark

The visual standard is **`roguecardv2@6e069118`** — the pre-pixi approved visual.
Web `main` is itself a regression and is *not* the target: it has since added
`pixi.js` and Capacitor. Parity work reads the **source** through the DOM; it
never samples the render.

It serves at **`localhost:5190`** from a detached worktree, so roguecardv2's own
`main` is never disturbed:

```bash
cd /Users/jamesto/Coding/roguecardv2-benchmark && npx vite --port 5190 --strictPort
```

The worktree was created with `git worktree add --detach
/Users/jamesto/Coding/roguecardv2-benchmark 6e069118` and has its own
`node_modules` (23 packages, `npm ci` against that commit's lockfile) — it must
not share main's, which would pull `pixi.js` into the benchmark.

**Confirm you are looking at the right build before trusting a comparison:** the
title screen stamps the version bottom-right. It must read `0.5.0+6e06911`.

**Save state is per browser profile.** A fresh profile starts at
`0 climbs · 0 dawns · 0 slain`, so reaching a combat or reward screen means
pressing *Begin the Climb* once. After that the standing rule applies — **Continue
the Climb, never Begin Anew** — or the run every lane is comparing against is gone.

Restoring the benchmark is the organiser's job, not a lane's.
