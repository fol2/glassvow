# Guided First Run — onboarding design (#176)

Decided HITL with James, 2026-08-16, on wayfinder ticket #176. Scope per the
#263 boundary amendment: the tap / hold-0.6s scene grammar belongs to the
shared scene player (`docs/story/07-scenes.md` §1); this design consumes it.
An adversarial verify panel (three lenses: rubric compliance, flow edges,
story contract) ran before sign-off; its confirmed findings are folded in
below and marked `[panel]`.

## Placement

- Title remains the first surface on boot — no cold open. Store screenshots,
  settings and language access all keep their anchor.
- Fresh profile: Title → Begin (續火) → the four-beat opening
  (`docs/story/07-scenes.md` §2) → straight into run 1. **EmbarkScreen is
  skipped on run 1**: a fresh profile has zero real choices (single aspect,
  vow 0 only) and the Keeper's boon beat is the diegetic embark. Embark
  returns from run 2 onward, **unconditionally** — even when a first-run loss
  leaves it still choice-less: it anchors the loop's structure and carries
  the vow-penalty atmosphere copy (#206).
- **Flow invariant**: a production-flow new run created while
  `opening_played` is unset plays the opening and skips Embark. The flag is
  written when the opening **completes** — a hold-skip counts as completion,
  an interruption does not `[panel: a flag written at scene start soft-locks
  an interrupted profile out of an opening that has no replay path]`. A
  begin-anew that abandons an interrupted first run therefore replays the
  opening from the start.
- The run is created at the Begin tap; the opening is the run's first
  surface and its beat cursor persists in the run save (the DawnScreen
  `pending_dawn` pattern). Process death mid-opening resumes on the same
  line via Continue / 返回路上. `[panel: _route_run() needs a
  pending_opening branch ordered before map dispatch; additive save field,
  absent = not pending — old saves are mid-run and correctly skip it.]`
- No run-menu chrome mounts over the opening — Abandon Run is unreachable
  mid-scene `[panel]`.

## Hint set

Six hints. Each fires the first time its trigger state exists while its
record is absent, never on a timer; at most one on screen; each dismisses
permanently the first time the player performs the action it names.

| # | Hint | Trigger state | Record key |
|---|---|---|---|
| H1 | Map node-select | first time the map screen is interactive | `hint_map_select` |
| H2 | Drag-to-play — gesture ghost traces from an enemy-target card in the real hand onto the enemy | first hand dealt in the profile's first combat | `hint_drag_play` |
| H3 | Target choice | first time an enemy-target card is grabbed with two or more living enemies | `hint_targeting` |
| H4 | End turn | first time energy is exhausted / no playable card remains | `hint_end_turn` |
| H5 | Enemy intent | first time a second player turn begins in a combat | `hint_intent` |
| H6 | Reward pick | first reward screen — pick or skip both dismiss | `hint_reward` |

- H2's ghost teaches drag **and** targeting in one demonstration: a
  single-target drop already requires landing on the enemy
  (`presentation/combat/combat_screen.gd` `_on_card_drag_released` snaps
  back on a miss even with one enemy alive). H3 is the target-*choice*
  teach and waits for the first state that requires it, which may be a
  later fight. `[panel: a defend-heavy first hand can exhaust energy before
  any enemy card is dragged, so H4 may precede H3 — the rubric's order
  criterion is amended to make state-triggering authoritative; see below.]`
- The map screen's persistent survey label (`ui.pilgrimage.survey`) retires
  when H1 lands — no double teaching.
- Not in the set: shop, rest, event, potions, deck view, Vigil —
  self-explanatory tap UIs, or carried by their own story beats.

## Rubric amendment

The first-combat order criterion in `docs/commercial-rubric.md` is amended
by this ticket (same PR as this document): state-triggering is
authoritative; the named order drag → targeting → end-turn is the canonical
path; the targeting hint's state is the first real target choice. The
two-taps and destination-naming criteria stand **unamended** — the skip
design below satisfies them literally.

## Skip semantics

- The scene player's hold-0.6s story skip and the hint system's
  skip-guidance are **independent** decisions.
- Opening hold-skip: the fast-forward holds a minimum ~1 s dwell on beat ②
  — the Keeper naming the destination — so the destination is named legibly
  even under skip `[panel: the scene player's 40 ms/beat fast-forward would
  blank the rubric's unconditional destination-naming criterion]`.
- At skip completion a one-tap offer —「跳過教學指引?」/ "Skip guidance
  too?" (copy TBD at drafting) — appears; accepting records
  `guidance_skipped`. Veteran path: tap Begin (1) → hold-skip → tap the
  offer (2): unhinted play within two taps of starting, as the rubric
  demands. Declining changes nothing — the first hint still carries the
  one-tap skip-guidance control per the rubric.
- The skip-guidance control appears on the **first hint only**; suppression
  is profile-wide and permanent.

## Records

- All cross-run onboarding state lives in Vigil `unlocks` (additive
  strings, no save bump — the unsealing once-flag's storage shape):
  `opening_played`, `guidance_skipped`, and the six `hint_*` keys above.
- `[panel]` The storage shape is shared but the persistence timing is not:
  today `_store_vigil()` fires only at run-terminal moments, so hint
  dismissals must **flush the vigil save at dismissal time** or a mid-run
  process death resurrects dismissed hints.
- The hint system is **globally gated on `opening_played`** — the rubric
  requires no teaching callout before the opening completes, and the same
  gate keeps hints out of every dev boot: `--fight=` / `--map` / `--enter=`
  construct runs against the real vigil without the Scenario kernel
  `[panel]`, so parity captures stay clean with no dev special-casing.
  Scenario review states inherit the same suppression (a kernel-built vigil
  has no `opening_played`); a bounded kernel control may set it so the
  onboarding surfaces themselves can be reviewed. This supersedes the
  earlier plan to seed `guidance_skipped` in review states — one gate
  covers both.

## Departure staging

The L0 every-departure ambient plant — camera lingers a beat on the hooded
figure at the hearth, the window reflection lags half a beat
(`docs/story/07-scenes.md` §2, required standing by #270's planting gate) —
is homed by this design `[panel: previously unowned from run 2 onward]`:
run 1 rides the opening's beats ③–④; run 2+ rides the Embark → run
transition. Child ticket A owns both instances.

## Hint copy

- Plain UI-register locale keys (en + zh-Hant), drafted zh-first (Fable
  drafts, James reviews), 着/裏 orthography gates as everywhere.
- Hints never carry lore — no canon facts, no Keeper, no door — so
  canon-lint / twist-safety do not apply. The mechanical gates still do,
  project-wide: the #300 locale key-parity lint and the font-subset
  coverage gate (`tools/check_locale_font_coverage.py` locally before
  landing new zh glyphs).

## Execution

Two child tickets of #156, A blocking B:

- **A — Wire the opening and departure staging into the run flow**: the
  flow invariant, run-1 Embark skip, completion-written `opening_played`,
  `pending_opening` resume, beat-② skip dwell, the skip-completion offer,
  no run-menu over the opening, and both homes of the L0 departure plant.
- **B — Build the guided first run hint system**: H1–H6 with the triggers
  above, glass panel + anchored pointer + gesture ghost per the rubric,
  skip-guidance on the first hint, Vigil records flushed at dismissal,
  survey-label retirement, the `opening_played` gate.
