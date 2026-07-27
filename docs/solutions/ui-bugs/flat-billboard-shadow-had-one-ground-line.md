---
title: "A flat billboard has one depth, so a four-footed shadow planted one foot"
date: 2026-07-27
category: ui-bugs
module: presentation/combat/enemy_view
problem_type: ui_bug
component: rails_view
symptoms:
  - "duskfang's cast shadow sat away from its paws — reported on sight as \"is actually floating? not from its feet\""
  - "After the hinge was corrected the remaining three paws still hovered: one contact line cannot serve four feet at four heights"
  - "shellback stood a fifth of a box above its own shadow, because the hinge sat below the lowest opaque row"
  - "The creatures painted already airborne had their shadows pinned directly beneath them, and watcherEye's hung off its own tassels"
root_cause: logic_error
resolution_type: code_fix
severity: high
related_components:
  - documentation
  - tooling
tags: [godot, shader, shadows, vertex-projection, basis, billboard, alpha-scan, derived-parameters, measured-constants, art-direction, divergence]
---

# A flat billboard has one depth, so a four-footed shadow planted one foot

## Problem

Enemy actors render a painted PNG on a quad inside a per-actor `SubViewport` 3D
stage lit by a real `DirectionalLight3D` key, and the cast shadow is derived from
that light rather than authored per creature
(`presentation/combat/enemy_view.gd:1951` (`SHADOW_SHADER`)). Looking at the
roster, the shadows did not sit under the feet. `duskfang` — a quadruped painted
in three-quarter view — cast from off to one side of its paws; once that was
corrected, three of its four paws still hovered above the cast; and the creatures
painted already off the floor had their shadows pinned directly underneath them
rather than trailing behind.

Three separate defects and one missing half, all in the same twenty lines. Two
were arithmetic. The third was structural and could not be fixed in the shape the
code was written in: the projection lived in a `Node3D` basis, and a basis shears
about exactly one origin, so the shadow had exactly one contact line no matter
what was measured.

## Symptoms

- **The contact offset was applied twice.** `_update_shadow` shifted the shadow
  quad by `(_contact_u - 0.5) * _quad_w` while `qm.center_offset` put the mesh
  origin at the quad's bottom-edge *centre* (`Vector3(0.0, _box_u * 0.5, 0.0)`,
  at `bf7b751`). The shadow quad carries the **same texture as the body**, so the
  creature is already placed inside it; adding the contact offset on top of a
  centred origin double-counted and slid the whole cast sideways. Measured across
  the 27 enemy paintings, `duskfang` is the only one past 10% of quad width, at
  **−15.1%** (`contact_u = 0.349` — its lowest opaque row is the front paws, far
  left of frame). The next largest is `waylayer` at +9.3%, then `abyssalKnight`
  and `tidecaller` at +7.3% and `voltEel` at +7.2%; the remaining 22 are inside
  ±6%. The defect was therefore visible on one creature and merely latent on the
  rest, which is exactly why it survived.

- **The contact row sat below the feet.** The hinge was
  `-_box_u * 0.5 + _art_pad * 0.15` (at `bf7b751`) — 85% of the painting's
  transparent export border *below* the creature's lowest opaque row. That border
  is framing, not height, and it is large: `shellback`'s is 20.7% of the box, the
  roster's largest (`presentation/combat/enemy_view.gd:737` (`_contact_u`)). A
  crab lying flat on the floor was floating over its own shadow by a fifth of a
  box.

- **The ground was one line, and could not be otherwise.** A flat billboard has
  one depth. A `Basis` can only shear about a single origin, so a basis-projected
  shadow has exactly one contact line — and that line has to be the lowest opaque
  row, or the nearest foot is buried under the cast. Every other foot is then
  drawn *above* its own shadow, which is the whole of what "floating" looks like.
  `duskfang`'s admitted contacts span **14.1% of a body height** in the painting
  (`presentation/combat/enemy_view.gd:756` (`_ground_tex`)), so planting the near
  one necessarily left the other three hovering.

  Bottom profile for `duskfang`, from the same 64-wide scan the code runs (row
  index, 63 = frame bottom; measured this session):

  ```
  front paws   col 2-12   row 52-56
  near paw     col 14-24  row 57-59   <- the single old hinge
  mid/rear leg col 26-34  row 49-53
  belly        col 36-42  row 38-47   <- NOT a contact
  rear paws    col 44-52  row 55-56
  tail         col 54-60  row 40-43   <- hanging in the air
  ```

- **`shadow.dy` was doing half its job.** `dy` is the one per-creature knob that
  survived the earlier derive pass
  ([Derive authored compensations instead of transcribing them when porting](../design-patterns/derive-authored-compensations-when-porting.md));
  it marks a painting made of a creature already airborne, and is read as a
  resting height (`presentation/combat/enemy_view.gd:2641` (`_read_hover`)). It
  slid the cast sideways along the light's ground track and did not lower the
  ground. Since the ground line is read off the silhouette's lowest opaque row —
  which for a hovering creature is not a contact at all, but the bottom of a
  hovering body — the shadow was pinned directly under the floating body. Under a
  camera sitting dead-on at eye height the sideways slide is the weaker of the two
  cues; `watcherEye`'s shadow hung off its own tassels.

## What Didn't Work

**Reading the source.** The defect is invisible in code review. It appeared only
when the running program was screenshotted and the shadow region was brightened
2.4–3.0×: the shadows are near-black on a near-black ground and are effectively
invisible in an unadjusted capture. This is the lesson the project has already
written down once — a constant that matches proves nothing, and the only evidence
is pixels on the running screen (auto memory [claude]).

**A plausible metric that measured the wrong quantity.** A dark-pixel "ink" count
across the whole roster showed the new shadows had lost **31%** of their area,
which read as a regression. It was not one. The count conflates cast length with
blur-fringe area, and the fringe legitimately tightened when the blur ramp became
per column. Measuring the quantity that actually changed — mean height above
ground, weighted by silhouette — gave **12.0%**, and that is the number the
compensation was built on
(`presentation/combat/enemy_view.gd:2026` (`CAST_MIN`)). Applying ×1.137 recovered
the length without recovering the ink count, which is the correct outcome and
would have read as a failure under the first metric.

**Nearly blaming the shader for a data problem.** When the shadows shrank,
`Image.FORMAT_RF` sampling was the first suspect — a 64×1 single-channel float
texture round-tripped through `ImageTexture.create_from_image` is exactly the kind
of pipeline that quietly quantises. A headless GDScript probe that read the
profile back with `.get_image()` showed CPU and GPU values identical to three
decimal places, which ruled the texture out before any shader time was spent.

**A naive-crop A/B that gave a false "shadow is gone" reading** for `shellback`,
`leviathan` and `abyssalKnight`. The shadows had merely shortened, and the crop
was being judged by eye at thumbnail scale. Per-creature crops at full resolution
corrected the reading.

**The `Basis` trap had already cost a whole shadow once.** When the derived
projection was first built, the hero's shadow vanished entirely, and the cause was
recorded then: `Node3D.scale` is not independent — it is decomposed from `basis`,
so writing a sheared basis and *then* writing `scale` runs
`orthonormalized().scaled()` and destroys the shear, silently. The workaround was
to compose shear and scale into a single basis in one write. That workaround is
what the vertex-stage move now retires (session history: the shadow's original
build, 2026-07-26).

## Solution

### Pair the mesh origin with the world anchor

The two must move together, or the silhouette shifts off the body by exactly the
offset applied to one of them. The mesh origin goes to the measured contact point
(`presentation/combat/enemy_view.gd:2155` (`_build_shadow`)) and the node position
puts that origin back on the body's own foot line
(`presentation/combat/enemy_view.gd:2217` (`_update_shadow`)):

```gdscript
qm.center_offset = Vector3(
    -(_contact_u - 0.5) * _quad_w, _box_u * 0.5 - _art_pad, 0.0)

_shadow.position = Vector3(
    (_contact_u - 0.5) * _quad_w + hover * l.x * run,
    -_box_u * 0.5 + _art_pad - _hover_rest, 0.0)
```

The `_art_pad * 0.15` fudge is gone: the hinge sits on the lowest opaque row, not
85% of an export border below it.

### Read the ground line off the painting's own alpha, per column

`_read_ground` (`presentation/combat/enemy_view.gd:2102` (`_read_ground`)) takes the lowest opaque
row of each of 64 columns as a candidate contact. Those within `CONTACT_BAND` of
the lowest are taken as real; the line is linearly interpolated between them
across everything else (`presentation/combat/enemy_view.gd:2139` (`_interp`)). A
belly is therefore spanned rather than stood on, and a tail hanging in the air is
given the ground under the feet beside it. The result is baked into a 64×1
`Image.FORMAT_RF` `ImageTexture`; a painting whose alpha reads nothing falls back
to a single flat line at the lowest contact
(`presentation/combat/enemy_view.gd:2127` (`_flat_ground`)), which is the
behaviour that existed before.

Columns the creature does not occupy cost nothing: the shadow's alpha comes off
the same silhouette, so an empty column casts nothing wherever its ground line
lands.

### Move the projection into the vertex stage

One quad has four corners and therefore one ground line. The shadow mesh becomes a
subdivided `PlaneMesh` with `subdivide_width = GROUND_N - 1`
(`presentation/combat/enemy_view.gd:2155` (`_build_shadow`)) — a column of
vertices per ground sample — and the shear the `Basis` used to carry becomes
uniforms consumed per vertex
(`presentation/combat/enemy_view.gd:1951` (`SHADOW_SHADER`)):

```glsl
void vertex() {
    // UV.y 1 is the bottom of the painting, so a SMALLER v is higher up.
    float gv = texture(ground_tex, vec2(UV.x, 0.5)).r;
    v_far = clamp(gv - UV.y, 0.0, 1.0);
    float h = v_far * box_u;
    float gy = (contact_v - gv) * box_u;
    VERTEX = vec3(
        VERTEX.x * cast_wide + h * cast_lean,
        gy + h * cast_run * tilt_cos,
        -h * cast_run * tilt_sin);
}
```

`v_far` is a varying, so the fragment stage's blur radius and alpha fade are also
measured from each column's own ground: a contact shadow is sharp at the contact
and diffuses with distance, and with four feet at four heights "distance" is per
column too. `_update_shadow` now writes `cast_run`, `cast_lean` and `cast_wide` as
uniforms rather than composing a basis.

### `CONTACT_BAND = 0.15` is a gap, not a taste knob

```gdscript
const CONTACT_BAND: float = 0.15   # presentation/combat/enemy_view.gd:2086 (CONTACT_BAND)
const GROUND_N: int = 64           # presentation/combat/enemy_view.gd:2088 (GROUND_N)
```

The constant falls in the one gap the measurements leave between two populations.
Across all 27 paintings the widest spread of admitted contacts is **0.141** of a
box — thirteen paintings reach it, `duskfang` among them — while the nearest
feature that is plainly not footing, `duskfang`'s belly at **0.188** and its tail
at **0.25**, sits above. The band has to land inside [0.141, 0.188], and 0.15
does.

The measurement is partly circular and the comment says so: the spread it reports
is the spread of whatever this same band admitted, so it cannot see a creature
whose feet genuinely span more than 0.15. No painting on the current roster is
known to. The measurement is written into the declaring comment
(`presentation/combat/enemy_view.gd:2086` (`CONTACT_BAND`)) so a later reader can
re-derive it rather than re-tune it.

### Restate the art-direction clamp by the bias the fix removed

Height used to be measured from the *lowest* contact, which overstates it for
every column standing on higher ground. Weighted by silhouette across the 27
paintings, the per-column line **reduced** mean height by **12.0%** (`shade`
21.1%, `voidWisp` 19.4%, `watcherEye` 18.7%, `mirelurker` 15.9%, `duskfang`
15.1%, `sovereign` 0.3%). The compensating factor is that reduction inverted —
1/(1 − 0.120) = 1.137 — not 1.12; the clamp multiplies the height rather than
being measured in it.
`CAST_MIN` / `CAST_MAX` were therefore restated ×1.137, from 0.6 / 1.15 to
**0.68 / 1.31** (`presentation/combat/enemy_view.gd:2026` (`CAST_MIN`); the prior
values are at `bf7b751`).

Those two numbers are not geometry. They were set when the physically correct
projection was first tried and rejected — at the key's −38° elevation the run came
out at 1.62 body heights, which in a side-on game read as the creature floating
over its own shadow. The verdict recorded at the time was "the maths is right, the
art is wrong", and the clamp is that verdict (session history: the shadow's
original build, 2026-07-26). It had
been judged against a cast that ran 12% long. Leaving the numbers alone would have
let a geometry fix quietly shorten every shadow in the game, and the shortening
would have been attributed to the wrong cause months later. The look is what is
being preserved; the arithmetic under it changed.

### `dy` drops the ground as well as sliding the cast

The **live** part of the hover is deliberately excluded: a body driven up by the
idle animation moves away from a ground that stays where it is. Only
`_hover_rest`, which is `max(0, shadow.dy) * UNIT`
(`presentation/combat/enemy_view.gd:2641` (`_read_hover`)), lowers the ground
line. Six characters carry a `dy` in `assets/art/enemies/char-meta.json`, whose `chars`
block holds 29 entries — the 27 painted foes plus two heroes with no painting.
`_hover_rest` is 0 for the rest, so the change is confined to the floaters.

## Why This Works

The original model made an assumption it never wrote down. Choosing a `Basis` to
carry the projection *implies* that the surface being projected has a single
depth, because a basis is one linear map about one origin. Nothing in the code
said "this creature stands on one point"; the constraint arrived silently, as a
property of the data structure picked to hold the transform. When the artwork
turned out to depict four paws at four heights, no amount of correcting the hinge
could help — the structure had already decided there was one hinge.

Moving the transform into the vertex stage removes the constraint rather than
working around it. A vertex program is evaluated per vertex, so a quantity that
varies across the surface can be a genuine per-vertex input; the 64×1 ground
texture is exactly that quantity, sampled by `UV.x` and turned into a continuous
line by linear filtering. The subdivision is not decoration — with four corners
there are only four places to evaluate the ground, and the shape collapses back to
what a basis could have done.

The alpha scan works because the information was already in the painting. The
ground is depicted, and the silhouette's own bottom edge samples it wherever the
creature touches down. What the scan cannot know is *which* bottom-edge samples
are contacts and which are body hanging in the air, and `CONTACT_BAND` is the
answer to precisely that question — a classifier threshold placed in the empty
region between two measured distributions, not a dial.

The `CAST_MIN` / `CAST_MAX` restatement works because the two numbers were never
geometry. They are an art-direction clamp applied to a derived quantity. When the
derived quantity's systematic bias is removed, a clamp expressed in units of that
quantity means something different than it did — so preserving the approved result
requires changing the numbers, and preserving the numbers would have changed the
result.

## This is a divergence from the reference, not a parity fix

Worth stating plainly, because this project verifies itself against a benchmark.
**The reference does not solve multi-footed creatures either.** Its model is one
`transform-origin` per creature, machine-scanned as a single lowest qualifying row
by `roguecardv2-benchmark src/dev/char-feet-scan.js` (the reference checkout at
`~/Coding/roguecardv2-benchmark` @ `6e06911`, not a path in this repo) — "prefers the lowest row whose opaque span is ≥ 8%
of the silhouette width", then a mass-weighted X across that row ±1. It buys
readability instead, with `opacity .62`, `blur 1.5px`, and a silhouette anchored
`center bottom`.

So the first two defects above are genuine bugs — the port double-counted an
offset and mis-sited a hinge, and fixing them moves the port *towards* the
reference. The per-column ground line is a different kind of change: it is the
port doing something the reference never did, on the standing rule that the web
build is authority for what the game does, never for how it had to achieve it
(session history: the "do the shadow properly" pass, 2026-07-27). Anyone auditing parity should expect this to show
as a divergence and should not "fix" it back.

## Prevention

- **When a projection is derived rather than authored, enumerate the assumptions
  the derivation silently makes.** "One depth" was never written down anywhere. It
  was implied by choosing a `Basis`, and it stayed invisible until artwork
  violated it.

- **A transform expressed as a node `Basis` cannot vary per vertex.** If the thing
  being modelled varies across the surface, the transform belongs in the vertex
  stage. Moving it there also retires the `Node3D.scale` re-orthonormalisation
  footgun, which has no error and no warning — and which had already cost this
  project a hero's entire shadow once.

- **When a fix corrects a systematic bias in a derived quantity, restate every
  art-direction clamp that was judged against the biased quantity by the same
  factor.** Otherwise the fix silently changes the approved look, and the change is
  attributed to the wrong cause months later. This is the corollary to optimising
  only after visual approval: an approved number records a judgement, and it is
  only valid against the arithmetic it was judged over (auto memory [claude]).

- **Justify a derived constant by the gap between two populations, not by taste —
  and write the measurement into the declaring comment.** `CONTACT_BAND` is
  defensible because 0.141 and 0.188 are on opposite sides of it. A reader who
  finds the measurement in the comment can re-derive the constant when the roster
  grows; a reader who finds a bare `0.15` will re-tune it by eye. Record the
  measurement's weakness too — this one is partly circular, and saying so is what
  stops a later reader trusting it further than it goes.

- **Verify a data pipeline's round-trip before suspecting its consumer.** A
  ten-line headless probe that read the `FORMAT_RF` profile back through
  `ImageTexture.get_image()` eliminated the texture as a suspect before any shader
  debugging began.

- **Choose the metric that measures the quantity you changed.** The 31% ink loss
  and the 12.0% height overstatement were both real numbers about the same change;
  only one of them was about the thing that moved. A metric that aggregates two
  effects cannot arbitrate between them.

- **Judge near-black-on-near-black on a brightened capture of the running
  program** — and finish the judgement on the battlefield, not in the lab. The
  shadow's opacity was once calibrated at 0.55 against the lab's flat backdrop and
  turned out to be completely unreadable against the real stone floor (session
  history: a legibility pass on the real battlefield, 2026-07-26). The geometry in this entry was judged on the enemy bench;
  the lab is the right place to see the shape, and the wrong place to conclude
  anything about legibility.

- **Cite `file:line` by full repo-relative path, never by bare basename.**
  `tools/check_anchors.py` resolves a bare name only when it is unique in the tree,
  and a `.claude/worktrees/` checkout puts a second copy of every file there — so
  bare citations are silently skipped and the checker reports success over them.
  Every anchor in this entry uses the full path for that reason.

## Related Issues

- [Derive authored compensations instead of transcribing them when porting](../design-patterns/derive-authored-compensations-when-porting.md)
  — the pattern this shadow implements, and the record that already carries one
  correction about a derived value measuring the wrong thing. This entry is a
  second instance of the same failure mode in the same subsystem: `_art_pad` was
  mistaken for lift there, and the lowest opaque row was mistaken for the ground
  here. That pattern record now carries both later corrections: the restated
  `CAST_MIN`/`CAST_MAX` clamp and the retirement of the `Basis`-shear path.
  The two records agree and stay separate: one is the reusable porting rule,
  while this one is the incident-level implementation and evidence.
- [Drive the lab the way the game drives it, and photograph loops as well as beats](../tooling-decisions/drive-the-lab-the-way-the-game-drives-it.md)
  — the verification half of the same failure: a defect survives when no instrument
  in the project could have shown it. Exposure is a second capture dimension the
  lab does not offer, alongside the loop-versus-beat gap that doc already records.
- [Procedural glass reads off its edges](../design-patterns/procedural-glass-reads-off-its-edges.md)
  — the same move one step earlier on the granularity axis: replace an authored
  appearance constant with a per-element term computed against a light that
  actually exists. This entry takes it from per-actor to per-column.
- [Tune one card-surface recipe with a per-recipe uniform, never the shared model](../conventions/per-recipe-shader-knobs.md)
  — the discipline that applies to the `CAST_MIN`/`CAST_MAX` restatement: a change
  requested for one case landing in shared code, and proved with a number rather
  than an impression.
- `docs/actor-animation-checklist.md` § 2 "Cast shadow — DERIVE (built)" records
  this feature as closed at two defects. Three more have since been found and
  fixed.
- `assets/art/enemies/char-meta.json` — home of `shadow.dy`, the only `shadow`
  field the port still reads.
- Landed on `main`, all reachable from `origin/main`: `bf7b751` added the height
  response; `f37eb50` carried the origin pairing, the per-column ground line, the
  vertex-stage projection and the ×1.137 clamp restatement; `8c994c4` added the
  ground drop and gave `thornling` a `dy`.
