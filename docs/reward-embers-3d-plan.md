# Reward — the embers, in real 3D

Lane: **Reward** (`b3bb71f0`). Written 2026-07-26, before any code, because
`SKILL.md` §9 requires a plan for work over 400 changed lines and this is a
rewrite of the concept's drawing layer rather than a polish of it.

Companions: `docs/visual-direction.md` (what was decided, including the
rejections), `docs/session-ownership.md` (lanes and cross-lane rules),
`docs/actor-stage-frame-budget.md` (the measured cost of a 3D stage).

## Why

Embers is the chosen reward concept. Its whole claim is that the reward is the
enemy you just broke, still in the colour of the thing you broke it out of — and
every remaining complaint on the backlog was one complaint wearing six hats:
**a flat drawing cannot be a material.** Fracture rims drawn as fat lines read as
two-tone paper; slabs filled with the item's colour read as tokens; twelve
identical pie wedges read as a decoration. All six dissolve if a piece is an
actual solid in an actual lit room, which is the same answer the card lane
reached ("every card became a real 3D glass slab") and the enemy lane reached
("THE GLASS IS ACTUALLY 3D").

The second half is **bullet-time**, and it is not decoration. `card_surface.gdshader`
opens by stating that nothing in it may read TIME: every channel is a function of
geometry, because a material is not an animation. The cost of that discipline is
that an angle-driven material shows nothing while it is still. A piece turning
slowly under a light is not a violation of that rule — it is the only thing that
ever satisfied it.

## Decisions already taken

Taken by the organiser on 2026-07-26, in answer to the four forks raised before
this document existed:

1. **No physics.** Ruled by `SKILL.md` §7 and by the property the current code
   already protects: a shot of this screen is the same shot tomorrow.
2. **The generic lamp stays the generic lamp.** The fire is *not* the only light
   in the scene — that line in `reward_embers.gd`'s header is now wrong and gets
   corrected in the first commit. The fire is an added atmosphere light, and it
   **may fall on the offered cards**.
3. **Bullet-time holds tension without travelling.** Very slow, quiet, a little
   dynamic — not a freeze, and not a drift that keeps going somewhere.
4. **The husk is the enemy's real body**, not a reproduction of its silhouette.

## What is inherited, and from where

Nothing below is invented. It is read out of two lanes that already solved it.

| Thing | Where it already exists | Note |
|---|---|---|
| Extruding a 2D cell into a real plate | `enemy_view.gd:3392` (`_prism`) — `(cell, thick, box, origin)` | Vertex colour is a face tag: **caps black, side band red**, and the shard shader pours molten glow only where `COLOR.r` says fracture. This is the "the cut is the brightest part" thesis, already built. |
| Pieces must be built around their own centroid | same docstring | Recorded there as a bug already paid for: body-space vertices made every shard spin about the middle of the creature, so they swept arcs and landed upright. |
| Transparent 3D stage inside a Control | `enemy_view.gd:1893-1909` (in `_build_stage`), `card_view.gd:675` (`_build_stage`) | `own_world_3d`, `transparent_bg`, `BG_CLEAR_COLOR` with `AMBIENT_SOURCE_SKY` + `REFLECTION_SOURCE_SKY` — keeps the alpha while still giving glass something to mirror. |
| Tonemap | `enemy_view.gd:1908-1910` (in `_build_stage`) | `TONE_MAPPER_LINEAR`, never ACES: the filmic curve lifts blacks and desaturates, which on near-black art reads as fog over everything. |
| The lamp itself | `enemy_view.gd:1915-1920` (in `_build_stage`) | Warm `DirectionalLight3D`, `rotation_degrees(-38, -32, 0)`. This is the generic lamp, and the reward stage uses the same numbers so the wreckage and the cards do not disagree about where the light is. |
| Freezing an idle viewport | `card_view.gd:1008-1012` (`_set_live`) | `UPDATE_ALWAYS` → `UPDATE_ONCE` when a thing stops moving. |

**Ownership constraint:** `enemy_view.gd` belongs to the Enemy / hero lane. This
lane may read it and may not edit it. The prism builder is therefore **copied
into `presentation/reward/`** rather than shared, and the duplication is raised
in the cross-lane queue below for the organiser to resolve deliberately — a
reward shard and an enemy shard want different thicknesses and different tags,
so they may honestly be two functions, but that is not a lane's call to make
permanent.

**Two failures not to inherit.** `docs/visual-direction.md` records that the
enemy lane's shatter was rejected twice: it read as shattering a pane *in front
of* the mob rather than the mob itself, and the shards stood upright afterwards.
Both are addressed structurally here — the husk **is** the body (decision 4), and
nothing ever lands, so nothing can land badly (decision 3).

## What this retires

From the outstanding list, these stop existing rather than getting fixed:
**A1** (rim width in pixels), **A2** (slabs as flat fills), **A3** (identical pie
wedges), **B1** (debris in a symmetric wreath), **B2** (the bed reads as a lens
flare with nothing resting on it — in bullet-time nothing is *supposed* to rest),
**B3** (no light shared between the fire and the cards — decision 2 grants it).

Still live and unchanged: **B4** (the gold-only case has a dead middle), **B5**
(the art/label box sits on a rotated piece), **C1** (`encounter_kind` unused),
**C3** (nothing happens after the pick). **D2–D4** are done. **D1** grows: see
cross-lane.

## Structure

**One stage for the whole screen**, not one per piece. This matters for cost: the
historical component ladder allocated one stage per actor, so a fight paid four
stage allocations. The reward screen pays for one stage.

Layers, back to front:

1. `ColorRect` night ground (unchanged).
2. **`SubViewport` 3D stage** → `TextureRect`, full rect. The husk, every piece,
   the fire, and the lamp live here.
3. Additive fire bloom in 2D (kept — a real light does the modelling, a 2D bloom
   does the atmosphere, and the second is far cheaper than making the first
   bright enough to bleed).
4. Motes (`RewardKit.embers`, already hue-driven).
5. The 2D UI: spoil art and labels, `CardView`s, the take line, the word row.

The three `CardView`s keep their own two-viewport rig. They are the card lane's
contract, they are proven, and they already freeze themselves when idle. They are
**not** moved into this stage.

## Geometry

- The husk is built from the dead enemy's own art and metadata, the same inputs
  `EnemyView` reads. The reward screen therefore needs the enemy's **id** as well
  as its hue (see D1).
- Fracture cells come from the existing Voronoi-style split, then each cell is
  extruded to a prism about its own centroid. Cell count stays in the 12–18 range
  that the current code argues for: enough to read as shattered, few enough that
  every piece is still a shape.
- **The three spoil pieces are chosen, not promoted.** They are the three largest
  cells, and they turn to face the camera as they brake so their art and label
  read flat. `_slab()`'s hand-made pentagons go away.

## The timeline

| Beat | Length | What happens |
|---|---|---|
| Sit | 0.18 | The body, whole and still. It is the thing that just died. |
| Blaze | 0.10 | The cracks take light from inside, while it is still one piece. |
| Burst | 0.30 | It comes apart at real speed. Short — this beat is not the point. |
| **Brake** | 0.35 | Hard deceleration into the hold. The *deceleration* is what reads as time slowing; things merely stopping reads as a bug. |
| **Hang** | held | Pieces keep their spread mid-air pose. Residual drift only: on the order of 2°/s of rotation and under 2 px/s of travel — enough that a highlight walks across a facet over several seconds, not enough to compete with the card text below. |
| Cool | 0.40, overlapping the brake | Fracture faces go from white-hot to the item's colour. |

Nothing lands, nothing settles, nothing comes to rest on a floor. Tension is the
spread pose plus the deceleration, not continued travel.

## Lighting

Three lights, and the first two are quoted from the enemy stage so the whole game
agrees about where the light is:

- **Key** — the generic warm lamp, `rotation_degrees(-38, -32, 0)`. Not moved,
  not negotiable.
- **Rim** — cold `GlassStyle.GLASS` from behind, so pieces separate from night.
- **Fire** — `OmniLight3D` at the bed, in the enemy's hue, which is the concept's
  one float doing its work in three dimensions instead of one. Its reach extends
  past the wreckage far enough to touch the cards (decision 2).

## Material

Follow `card_surface.gdshader`'s route: an **unshaded spatial shader doing its own
lighting maths**, not Godot's transmission/refraction. Real refraction is a
screen-space pass this screen cannot afford on mobile, and the card lane has
already demonstrated that a hand-built specular term at a very high exponent is
what sells small glass. The fracture-face tag from `_prism` selects where the
molten term is allowed.

## Cost and the current gate

`docs/actor-stage-frame-budget.md` now leads with the real #105 exported-combat
matrix. Its proposed P8.1 Mac limits are 1228.8 MiB renderer allocation,
1536 MiB macOS process physical footprint and 16.00 ms observed whole-frame p95;
James's PM approval on PR #143 remains pending.

The reward stage is one stage. **Measured 2026-08-01** (`tools/bench_reward_stage.gd`,
same instruments as the actor probe): **127.4 MiB of renderer allocation** at
the hold — beside the historical per-actor component reading, not under it,
because an actor's viewport is a fixed
box and this one is the window × OVERSAMPLE 1.5. Two properties worth knowing
before turning knobs: `stretch/mode="canvas_items"` pins the logical canvas at
1180×820, so the stage renders at 1770×1230 on every display and the figure does
NOT grow with the monitor (`VP_MAX` 2048 never engages) — on a 2560-wide display
OVERSAMPLE is therefore a *sharpness* lever, not only a cost one. The engine's
per-viewport GPU clock reads zero through this path on this driver; the frame-time
story stays with the actor probe's method. This historical component reading is
not part of the current exported-combat matrix. Two lifetime questions remain:

1. If the combat screen is still alive behind the reward screen, four actor
   stages and this one are resident at once. Whoever wires this in should free
   the combat stage or drop its viewports to `UPDATE_DISABLED` while the reward
   screen is up.
2. The isolated reward-stage reading is historical component guidance, not a
   separate pass against the proposed whole-product gate. Renderer allocation
   is not physical VRAM and must not be added to process physical footprint on
   Apple unified memory; physical footprint is not RSS. GPU time was unavailable
   on Metal. #105 also did not measure cold save-load ≤2 seconds; #108 does.

## Cross-lane items

1. **D1, grown.** The reward Dictionary carries neither hue nor enemy. Assembly's
   `_on_combat_over` must pass **both** the dead enemy's `art.hue` and its id.
   Without them the screen falls back to lantern-ember and a generic husk, and
   the concept's entire claim quietly stops being true.
2. **Prism duplication.** A copy of `_prism` lands in `presentation/reward/`. If
   the organiser would rather it were shared, that is a shared-surface change and
   belongs to one lane at one time.
3. **Concurrent stages.** See cost, item 1 — this is Assembly's call, not this
   lane's.

## Staged delivery

Each stage ends with a per-file parse gate and a captured shot, and stops for a
look. No stage is allowed to grow past the point where its diff can be read.

| Stage | Delivers | Judged on |
|---|---|---|
| 1 | The stage, the lamp, the fire, and the **intact husk** standing in it. No break at all. | Does the enemy's body read as a solid object in a lit room? |
| 2 | The break: cells, prisms, trajectories, the brake into the hold. | Does it read as a thing failing, and does the hold hold? |
| 3 | Fracture material — the molten cut, the cooling into the item's colour. | Is it glass? |
| 4 | The spoils: three pieces carrying the announcements, cards in front, the hover-to-turn. | Does it read as a reward rather than a diorama? |
| 5 | Measurement, then B4/B5/C1/C3 off the old backlog. | Numbers, then the leftovers. |

## Open questions

- **Hover to turn.** Proposed but not decided: moving the cursor over a spoil
  piece turns it, exactly the contract a card already has. It is the cheapest way
  to let a curious player interrogate the material without animating at idle.
- **C1, elite.** Still unanswered from the backlog: should an elite win look
  different, and how? In 3D the cheap answers get better — more pieces, a colder
  fire, a longer hold — but it is a design call, not an implementation one.
