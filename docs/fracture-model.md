# The fracture model — specification

Status, 2026-07-26: **§8 is built, steps 0–7, with `CrackRibbon` declined for a reason
§8 states.** This is the design that survived two rounds of three-seat review.
`docs/glass-crack-rendering.md` is the companion: it records why the present crack
web is wrong, what was rejected, and the decision history. This file says what to
build, and §8 says how far that has got.

Line anchors are correct at the commit that wrote them and drift within hours —
six lanes edit `presentation/` concurrently. Re-anchor with
`python3 tools/check_anchors.py --fix` rather than trusting a number.

Nothing here requires a change to `domain/`, to the save format, or to any
fixture. The whole model is presentation.

## 0. The two chains, and where each is computed

The owner's framing, and it is the right one: **simulate the physics and the
geometry, not the appearance.** There are two physical chains and they are
separable.

| chain | question | where it runs |
|---|---|---|
| **fracture mechanics** | how does a crack form and where does it stop | CPU, once per blow |
| **optics** | how does glass carry light | GPU, per fragment, reading what the CPU left |

The chain from a damage number to a crack is: **kinetic energy of the blow →
elastic strain energy stored in the plate → released as new fracture surface.**
That last term is Griffith's surface energy, so the honest model is short. The
derivation collapses: for a crack of half-length *a* under stress σ, release goes
as σ²π*a*/E against a cost of 2γ per unit length, which yields

> **crack length is proportional to delivered energy.**

Everything between that statement and the game is a unit conversion (§3, `bite`).
A full plate-bending solve, dynamic inertia and rate-dependent toughness are
physics theatre at this scale — a player cannot see them. Anisotropy from the blow
direction *is* visible and is kept.

## 1. Pre-computation has three tiers, not two

This distinction decides the architecture, and both a round-2 seat and the web
reference have been misread on it, so it is stated first.

| | computed | impact-responsive | per-frame cost |
|---|---|---|---|
| **(a) per-fragment** | every frame, in the shader | fully | a loop over N features × every pixel |
| **(b) per-event bake** | **once per blow**, into a texture; sampled thereafter | **fully** | one texture fetch |
| **(c) offline asset bake** | at import; one fixed figure per artwork | **no** | one texture fetch |

**The web reference does (b), not (c).** `../roguecardv2-benchmark/src/mesh.js`
runs `bakeCrackMask`, `bakeCrackNormal` and `bakeSeamGlow` at 192² **on each
`meshCrack()` call, from the crack sites that exist at that moment**. It is a
memoisation of a per-fragment computation, not an art asset. It stays fully
responsive to where the blow landed.

So there is no real-time-versus-pre-baked trade to make here. **(b) is both.** The
physics is genuinely calculated, once, when something happens; the rendering is
pre-calculated, into a texture, and then costs a fetch. Real calculation where it
is cheap, cached where it is not. (c) would cost every creature the same crack
figure for every death, and is not on the table.

## 2. Architecture

### 2.1 Layout

```
presentation/combat/fracture/        pure RefCounted — gated, §6
  blow.gd            class_name Blow            the input quantum
  crack_net.gd       class_name CrackNet        the source of truth
  fracture_field.gd  class_name FractureField   the mechanics
  body_mask.gd       class_name BodyMask        alpha + connectivity probe
  carve.gd           class_name Carve           net -> closed polygons
presentation/combat/                 Image / Shader allowed
  crack_field.gd     class_name CrackField      the field renderer — the target
```

As built, one deviation from the plan above and one omission, both deliberate.
`CrackField` sits directly in `presentation/combat/` rather than in a `glass/`
subdirectory, because a directory holding one file is a directory that exists to make a
diagram symmetrical; the gate is over `fracture/` and everything the gate does not cover
lives where the rest of the actor code does. `crack_ribbon.gd` was never written — §8,
step 7 records why, and the interface in §5 is still what it would implement.

`BodyMask` is the only file in `fracture/` permitted to name `Image`. It wraps the
art alpha — today `presentation/combat/enemy_view.gd:3661` (`_alpha_at`) — behind
two methods:

```gdscript
func solid(p: Vector2) -> bool           ## is there body here
func reaches(a: Vector2, b: Vector2) -> bool   ## is there body all the way
```

`reaches` is the connectivity test, and it is not optional. A crack cannot cross a
void, and sampling alpha at the step endpoint alone lets a tip commit half a step
into the gap between two tendrils. Everything else in `fracture/` is `Image`-free,
so a test can substitute a rectangle.

### 2.2 The source of truth

```gdscript
class_name CrackNet extends RefCounted
## Append-only. commit() is the ONLY mutator.
func commit(strands: Array[Dictionary]) -> void

## Renderer and carve view — pure reads. No width, no colour, no Node.
func strand_count() -> int
func strand(i: int) -> PackedVector2Array    ## body UV, ordered origin -> tip
func arc(i: int) -> PackedFloat32Array       ## cumulative length; arc[0] == 0.0
func length(i: int) -> float
func terminus(i: int) -> StringName          ## &"T" on a crack | &"S" silhouette | &"F" free
func origin(i: int) -> Vector2               ## the blow this strand grew from

## Model view.
func nearest(p: Vector2) -> float            ## INF when empty
func is_empty() -> bool
```

One mutator is what makes the "cracks relocate" defect
(`docs/glass-crack-rendering.md` §3.2) **unrepresentable** rather than fixed. The
propagator grows polylines in a local buffer and arrests every tip before
returning; nothing already committed can be touched.

The arrest test reads net **and** buffer, so a radial can arrest on a sibling from
the same blow. That is not a wart — a crack arrests on any free surface regardless
of when it was made.

### 2.3 The mechanics

```gdscript
class_name FractureField extends RefCounted
func _init(rng: Rng, mask: BodyMask, tuning: Dictionary = {}) -> void
func strike(net: CrackNet, blow: Blow) -> Array[Dictionary]  ## new strands; caller commits
func relieve(net: CrackNet) -> Array[Dictionary]             ## the rite: every tip out, toughness 0
func drive_at(net: CrackNet, blow: Blow, p: Vector2) -> float ## public so the field can be DRAWN
```

`drive_at` is public for one reason: the lab must be able to sample the field on a
grid and draw it. The propagator's constants are *invisible* in a way the old disc
was not — you cannot see which one is wrong — and a field view is the structural
cure for the exitless tuning loop recorded in
`docs/solutions/design-patterns/procedural-glass-reads-off-its-edges.md`.

### 2.4 The update rule

**Radial cracks advance along the radial direction**, outward from the blow,
because they open against *hoop* (circumferential) tension. The blow direction
**modulates the magnitude**, producing anisotropy; it does not set the heading.

The radial direction is a **restoring pull, never an assignment** — and that
distinction is the difference between a fracture and a crosshair:

```gdscript
var radial: Vector2 = tip - blow.at
heading = heading.rotated(heading.angle_to(radial) * RADIAL_PULL)  ## a bias, not a set
heading = heading.rotated(_rand(-1.0, 1.0) * grain * step)         ## the grain
var bias: float = 1.0 + ANISO * absf(heading.dot(blow.dir))        ## the blow's preference
var drive: float = bias * (1.0 - relief_from_existing_cracks)
tip += heading * step
```

Recorded because two versions of this were wrong in two different ways:

* One review seat produced the **inverse** — heading taken as
  `blow.dir.rotated(PI/2)`, a single direction everywhere, which makes every crack
  run parallel instead of radiating. Its prose was correct and its pseudocode was
  not. The closed-form Flamant point-load field it derived first *is* the right
  starting point; the simplification is what inverted it.
* The first built version **assigned** the heading from the radial each step. That
  reads as the same statement and is not: assignment erases the accumulated grain
  every step, so each arm was pinned to an exact ray. The kill-test sheet came out
  as a surveyor's crosshair. It also silently deleted every bifurcation, because a
  fork starts *on* its parent, so its radial **is** the parent's radial — the fork
  angle was erased one step after the fork was made and the branch then arrested on
  its own parent. Eight blows, twenty strands, not one branch. Caught by looking,
  not by an invariant, which is why §8 makes the sheet a build step.

Termination, in the order tested:

1. the segment fails `BodyMask.reaches` → **`S`**, the silhouette.
2. the tip comes within `step` of any existing strand → **`T`**, a T-junction.
3. `drive < toughness` → **`T`** if within `capture_radius` of an existing crack,
   otherwise **`F`**, a free tip that must taper to literally nothing.
4. `spent >= budget` → **`F`**. The Griffith limit, and the ordinary ending.

Rule 2 is the topology fix. Sequential arrest on an existing free surface is what
makes impact fracture T-junctioned, where Voronoi's simultaneous construction gives
Y-junctions at 120° — the signature of shrinkage, not impact.

Rule 3's **capture** clause was added after the first sheet reported nine
T-junctions where the eye counted crossings and the census counted none. The only
thing that can lower the drive is an existing crack relieving it, so a tension death
always happens *inside* that crack's process zone — and a crack approaching a free
surface is steered into it by the relief gradient, terminating on it. Arresting a few
steps short instead recorded `F` where the physics says `T`, and would have the
renderer draw a groove stopping in mid-glass with a visible gap short of the seam it
was running to. The captured strand's final vertex is the nearest point **on** the
other crack, which the carve needs as much as the renderer does.

A tip **bifurcates** when local drive exceeds `2 × toughness`. That factor is
fixed on the mechanics — a single tip cannot dissipate much beyond 2 G_c — and is
not exposed. The reference authors a 45 % fork probability; here it is derived.

**What is emitted is filtered.** Arms leave the impact point together, so the
angular jitter can put two within a third of a spacing and the trailing one arrests
on its neighbour after two steps. Physically right, and a 0.02-body stub the renderer
would have to draw as a speck. A strand under `MIN_ARM` is dropped from the output
*and* from the in-flight buffer — a mark that does not exist cannot screen anything.
`relieve()` is deliberately exempt: its continuations start on an existing tip, so a
short one extends a visible line rather than being a speck of its own.

**`relieve()` is idempotent**, and cannot be without help. The net is append-only, so
a tip carried the rest of the way out keeps its `T_FREE` terminus; the continuation is
a new strand starting on it and nothing rewrites the old one. "Terminus is free" and
"still an open tip" are therefore different questions, and `CrackNet.open_tips()` is
the second one. Asking the first would make a death beat firing twice double the
entire network — which this codebase has done before (`c77b56b`).

### 2.5 Boundaries

| boundary | what crosses | direction |
|---|---|---|
| `domain/` → presentation | existing event dictionaries. **No new command, event, state field or save key.** | one way |
| `combat_screen.gd` → `EnemyView` | `strike(at, dir, energy, sharp)`, replacing `crack(at)` | one way |
| `EnemyView` → `FractureField` | `Blow` + `CrackNet` + `BodyMask` | one way |
| `FractureField` → `CrackNet` | `Array[Dictionary]`, committed whole | one way |
| `CrackNet` → renderer | the six read-only accessors, nothing else | one way |
| `CrackNet` → `Carve` → `shatter()` | closed `PackedVector2Array` in body UV | one way |

The load-bearing property: **`CrackNet` holds no reference to a renderer, and no
renderer can write to it.** Generation and optics are two independent streams
meeting at one read-only interface, so either can be built and judged against a
fixture while the other does not exist.

## 3. The parameter set

Lengths are **body-relative**: 1.0 is the art box's smaller side. That is what lets
one parameter set serve the 115 px sporeling and the 1120 px leviathan without
per-creature authoring. Angles in radians. Energy dimensionless, normalised so 1.0
buys one body-width of crack.

**Material — five.**

| | name | unit | meaning | its one job |
|---|---|---|---|---|
| 1 | `toughness` | energy per unit length | Griffith's G_c — how hard this glass is | the arrest threshold; `relieve()` sets it to 0 |
| 2 | `screen_radius` | body fraction | the process zone: how far a free surface relieves tension | how tightly a later crack bends toward an earlier one |
| 3 | `heterogeneity` | radians per body fraction | grain — how much a running tip wanders | path jitter |
| 4 | `radial_pull` | fraction per step | how hard the hoop-tension direction restores a wandering tip | keeps an arm radial *in the mean* without pinning it to a ray |
| 5 | `sharp` | 0..1 | indenter acuity | the radial / concentric energy split |

`radial_pull` is fifth because the model was built without it and was wrong without
it — see §2.4. It is not a taste knob: at 1.0 the model is the crosshair, at 0.0 the
arms are a random walk with no radiation, and both failures are visible in one sheet.

**Numerics — one, plus two derived.** `step` (body fraction per Euler step),
`max_steps = ceil(1.5 / step)` because a crack cannot exceed 1.5 body diagonals, and
`capture_radius = screen_radius / 2`, chosen only to sit comfortably outside the
largest radius at which a tension death can occur (0.033 body — derived in §2.4), so
it is a bound rather than a number. `step` carries a **convergence test**: halving it
must move no tip by more than `step`. A numerics constant with a convergence test is
an assertion, not a knob.

**Legibility floors — two, both read off the renderer.** `min_arm` = 5 × the
`aperture` floor below, because a mark must be several times longer than it is wide
before the eye reads it as a line rather than a speck. And `arm_length`, the length a
radial wants to be, which is what divides a blow's energy into arms.

These were **one** constant and that was a bug. Dividing the budget by the legibility
floor makes the arm count saturate at `max_arms` for any energy above 0.23 — so a tap
and a killing blow both threw seven arms and only their length differed, which is the
opposite of the intended story and of the reference's own behaviour (four arms
normally, six for a big hit). Griffith held throughout: total length stayed exactly
proportional to energy however the budget was split, which is precisely why no field
invariant caught it. `_check_field_arm_count` is now the invariant that would have.

**Renderer — one, plus one derived.** `aperture`, the crack mouth width at the
origin. Opening displacement goes as √(*a* − *s*), so the whole profile follows
from `aperture` and `length(i)`. And `kerf` — the width the carve knife removes —
**is `aperture` read at the strand's mid-length**, so the debris edge lines up with
the groove that was showing. One physical quantity, two consumers, where today two
unrelated numbers would be tuned apart.

Derived floor on `aperture`: the groove must be ≥ ~1.5 stage pixels at the smallest
actor or it scintillates whatever the MSAA. At a 115 px sporeling with
`oversample` = 2.0 (`enemy_view.gd:308` (`oversample`)) one body unit is ≈ 230
stage px, so **`aperture` ≥ 0.0065 body**. The reference's ≈ 0.015 clears it 2.3×.

**Blow inputs — all derived, none authored.** `at` from the hit point already
computed for the floater (`enemy_view.gd:2680` (`body_centre`)); `dir` from the
existing left/right reasoning in `take_hit`; `energy` from damage; `sharp` from the
attacking archetype.

### What dies

| dies | why it was a problem |
|---|---|
| `_glass_area` (0.45) | one number setting coverage **and** disc radius |
| `MAX_SITES` (32) | caps a quantity with no physical meaning |
| `reach` in `_voronoi` | one parameter switching two unrelated intents |
| `bend` (0.055) in `GLASS_SHADER` | a UV displacement with no unit; not a light path |
| `_death_sites`' rings `[[0.16,4],[0.36,7],[0.62,9],[0.85,10]]` | **eight** authored numbers describing a shape |
| `_clip`, `_disc`, `_cells`, `_rebuild_glass` | the disc machinery entire |

### The honest count

An earlier draft of this section claimed "six authored numbers replace thirteen, and
none of the six describes a shape". The first half was optimistic and the second half
is no longer true, so both are corrected here rather than left to be discovered.

What the built model actually carries:

| group | count | authored or not |
|---|---|---|
| material (`toughness`, `screen_radius`, `heterogeneity`, `radial_pull`, `aniso`) | 5 | authored — they describe the glass |
| numerics (`step`) | 1 | authored, and carries a convergence test |
| derived from other constants (`max_steps`, `capture_radius`, `min_arm`) | 3 | not knobs |
| fixed on the mechanics (`fork_drive` = 2 G_c, `max_arms` = 7) | 2 | not knobs |
| the star's statistics (`arm_length`, `fork_angle`, `fork_share`, `fork_after`, `arm_spread` ×2) | 6 | authored, and these **do** describe a shape |

So: **eleven authored numbers**, of which six describe what an impact star looks
like. The claim that survives is narrower and worth stating precisely, because it is
still the whole point:

* **No constant describes a *particular* shape.** The star group is statistical — a
  spread, an angle, a share — and one set of them serves every creature in the roster.
  The reference's `[[0.16,4],[0.36,7],[0.62,9],[0.85,10]]` is eight numbers describing
  one specific arrangement of rings, re-authored per look.
* **No per-creature fracture authoring, at all.** A creature added tomorrow needs
  none, which is the payoff
  `docs/solutions/design-patterns/derive-authored-compensations-when-porting.md`
  recorded for the shadow knobs.
* **Every constant has exactly one job**, which is what the old set did not: the disc
  machinery's `_glass_area` set coverage *and* radius, and `reach` switched between two
  unrelated intents depending on the caller.

The count going *up* while the model got better is the useful lesson here. Two of the
six star constants (`arm_length`, `arm_spread`) exist because a single number was
doing two jobs and the collapse was invisible until it was drawn.

### The one honest fudge

`bite`, converting `damage / max_hp` into fracture energy. No physics connects a
card's damage number to joules. It is honest on three counts: it is a **unit
conversion**, the one class of constant allowed to be arbitrary; it is **global,
not per-creature**; and it has a **calibration rather than a slider** — choose
`bite` so a blow removing all of a foe's health carves into 9–14 shards, the count
`_death_sites`' rings were tuned to and the rite is already approved at.

A second, smaller concession: the archetype → `sharp` mapping is taste. One number
per archetype, beside the archetype tints (`VfxLayer.TONES` is the precedent).
Taste gets ported, not derived. **Not built** — `sharp` is accepted by `Blow` and not yet
spent by the propagator, so a per-archetype table would be a table nothing reads.

### `bite`, as built — 2026-07-26

**`BITE = 2.0`, and it was calibrated exactly as asked.** One blow, relieved, carved, over
five seeds on three real silhouettes: 11.4 shards on a duskfang, 12.4 on a gravewarden,
14.0 on an emberwisp — inside the 9–14 band on all three.

The sweep said something the calibration did not ask for and is worth keeping. **The shard
count saturates around 2.5 and then falls**, reaching 8.6 by 6.0. Past that point extra
energy buys longer arms out of one impact rather than more of them — `MAX_ARMS` caps the
count — and long siblings arrest on each other, so the extra crack length makes T-junctions
instead of through-cuts. There is no energy at which one blow reduces a body to dust. That
is the right shape for the model to have and nobody designed it in; it falls out of the arm
cap meeting the screening term.

**The map is AFFINE, not proportional**, and the floor is why. A proportional map sends a
small hit to a small energy, and `int(0.2 / ARM_LENGTH)` is zero arms — clamped to one,
which §8's kill test already recorded as the thing that reads as a scratch rather than as
broken glass. Zero is not a legible outcome. So the conversion runs from *a star* to *the
body comes apart*:

> `energy = DEFAULT_ENERGY + (BITE − DEFAULT_ENERGY) × damage / max_hp`

Measured across the range on a duskfang, which is the check that it is a gradient and not
two cases:

| damage | energy | arms | shards |
|---|---|---|---|
| 5 % | 1.15 | 4 | 6–8 |
| 25 % | 1.33 | 5 | 9–10 |
| 50 % | 1.55 | 5 | 8–10 |
| 75 % | 1.77 | 6 | 11–12 |
| 100 % | 2.00 | 7 | 12–13 |

The floor is not a fudge on top of a fudge: `DEFAULT_ENERGY` had an independent
justification before this existed — an impact star is the smallest unit that reads as
fracture at all, and the arm is not — and this reuses it rather than inventing a second
number. What changed is that it stopped being the *whole* answer and became the bottom of a
range.

## 4. Screening, and why accumulation is affordable

> **As built, 2026-07-26: the 128² oracle below was not needed, and the reason is
> the owner's cap.** The whole cost problem in this section is that an
> *unbounded* net makes the nearest-segment query O(blows²). With cracks capped at
> eight strands the net never grows past a few hundred segments, so
> `FractureField` queries `CrackNet.nearest` directly and the quadratic never
> arrives. The section stands as the answer if the cap is ever lifted.
>
> Two corrections the invariants forced, both physics rather than code:
>
> **The contact test and the screening term must read different things.** Contact
> reads the net *and* this blow's own in-flight arms, because a crack cannot cross
> any free surface whenever it was made. Screening reads the net **only** —
> siblings from one blow form simultaneously, one impact and one release, so they
> do not relieve each other. Reading the buffer into the screening term makes every
> arm after the first die on its first step, since all arms leave the same point
> and are therefore inside each other's process zone. Seven arms in, one arm out.
>
> **A star centre is not a Y-junction.** The first junction census counted every
> strand end, which reads a seven-armed star as seven Y-junctions — inverting the
> thing the census exists for, since a star radiating from one impact *is* the
> impact signature and the opposite of the shrinkage pattern a Y means here. Only
> tips count: a birth is not a meeting.
>
> Both were caught by the invariants rather than by looking at a render, which is
> the argument for the pure module stated as a result instead of as a hope.

The naive screening query — distance to the nearest segment, walked over the whole
net — is O(net) per Euler step, so O(blows²) over a fight. Costed properly: a
30-blow fight leaves ≈ 9 600 segments, and blow 30 alone needs ≈ **3.1 M** distance
queries. Seconds, in GDScript. Unshippable.

**Make the query O(1).** Keep a model-internal **128² R8 `PackedByteArray`** of
quantised distance-to-nearest-crack, `min()`-composited as each strand commits.
`drive_at` then reads one byte.

- **Query:** 320 byte reads per blow, **constant in fight length**.
- **Composite:** rasterise per *segment*, dilated by `screen_radius`. A ~22×22 box
  × ~40 segments ≈ **19 k pixel writes per blow, ~1 ms, on a hit, never per
  frame.**
- **Fixed at 128², deliberately.** This is the *screening* cache, not the render
  source. The render field is sized from `_box_u`. One structure, one job.
  Quantising to 1/128 body is harmless — the process zone is larger than that.
- Needs no `Image`, so the purity gate keeps its single exception.
- Elegance cost: one numerics constant, with a convergence test — double it and no
  tip may move by more than one cell.

`min()`-compositing is monotone, so this structure **cannot** move an old crack
either. Immutability appears twice, in two independent places, for free.

**`MAX_SITES` is deleted, not replaced.** Capping tips or sites was only ever
needed because the query was O(net). Retaining the polylines is free: 30 blows × 8
strands × 40 points ≈ 77 KB per actor.

**Rejected: a coarse "damage state" that only resolves into geometry at the rite.**
It re-creates the defect this exercise removes. If accumulation is a scalar until
the rite, nothing on screen during the fight was caused by the blows, and at the
rite the pattern is generated from a summary with the blow *positions* lost —
which is `glass-crack-rendering.md` §3.4 wearing a different hat. Either
accumulation is a real network from the first blow, or it is nothing.

## 5. The renderer

Two renderers, one interface: `build(net, box, plate)`, `reveal(t)`,
`set_ignite(v)`, `set_marked(on)`, `clear()`. Nothing else.

`reveal(t)` is the propagation animation, driven by a `Tween` in `EnemyView`.
**The model has no clock** — it emits a finished strand and the renderer reveals
it. That is `CONCEPTS.md` › *Angle, not time* applied at the correct seam: the
material is a function of geometry, the event is a function of time, and they are
different objects. It also means the animation cannot desync from the geometry,
because there is only one geometry.

**As built it is `begin(strands) → span` then `reveal(arc)`, and the argument is an arc
length rather than a normalised `t`.** That is the physical statement: a crack front runs
at a fixed fraction of the shear wave speed and does not know how long its own arm will
turn out to be. Normalising would have every arm of one blow finish together, so a short
arm would crawl while a long one sprinted — the one thing about this animation an eye
would actually catch. The blow's glints are laid at once and are not revealed, because a
glint is the impact mark: the point flashes, and the arms then run out of it.

Two things about it are load-bearing and neither is obvious:

* **The width law must stay bound to the strand's full length, not the window's.** The
  opening tapers by the arc remaining, so a window that measured its own length would
  taper to the tip value at every growing front and leave a permanent pinch at each frame
  boundary — a beaded groove, invisible during a 0.12 s animation and there for the rest of
  the fight. No render check would catch it, because a beaded crack still looks like a
  crack. `_check_field_reveal` asserts texel-for-texel equality against compositing whole,
  and it failed on its first run for exactly this reason.
* **The rite must flush the front before it carves.** The carve reads the net, which has
  been complete since the blow landed, so a half-drawn field would throw shards along
  cracks the player was never shown.

### 5.1 `CrackField` is the target

It is **one concept — distance to the network — with four consumers**: the standing
groove, the ignite bloom, the marked preview, and the screening oracle. One
structure, four jobs, **no extra node and no extra draw call** — it writes an
`ImageTexture` and feeds it to `_body_mat` as a `crack_tex` uniform, read by
`BODY_SHADER` alongside its existing luma-derived normal.

Propagation animation is free and incremental: composite the next segment. No mesh
rebuild per frame — cheaper than the ribbon, not merely equal to it.

### 5.2 `CrackRibbon` is optional, and it inherits a gated dependency

Real extruded V-groove geometry buys real thickness and a genuinely lit lip. But:

- `SurfaceTool.generate_normals()` **averages away the crease a V-groove exists to
  have**, so the ribbon needs authored crease normals rather than the convenience path.
  This used to add "the existing `_prism` calls it" as evidence, and **it no longer does**:
  the same mechanism was found to be doming every debris cap and `_prism` now writes its
  own normals (§9). The warning stands and is stronger for having been paid once — what
  changed is that the sentence pointing at a live example has to point at a fixed one.
- A ribbon groove is a **silhouette edge**, so it inherits the MSAA dependency.
  `docs/actor-stage-frame-budget.md` records MSAA 4× as load-bearing precisely
  because a shard's lit lip breaks into a dim broken line at 2×, and prices MSAA at
  21 % of the actor-stage figure with the lever **gated** pending visual approval.

A normal-mapped field groove is shaded per fragment and antialiases itself. So
**if the memory gate later forces MSAA to 2×, `CrackField` survives unchanged and
`CrackRibbon` does not.** Building both behind one interface is a hedge against a
decision nobody has made, not gold-plating.

### 5.3 The groove is three bands, and only one may emit

From the reference's authored figure, `../roguecardv2-benchmark/src/art.js`
(`crackSvg`): three concentric strokes over a 200-unit viewBox — dark 2.9 px at
0.72 alpha, light 1.35 px at 0.9, hot core 0.7 px at 0.95 — plus a glint at the
impact point. A groove ≈ 0.015 body wide.

**Three bands, and only the innermost may emit, and only under `ignite` or
`marked`.** The present `GLASS_SHADER` lights albedo, alpha *and* emission on one
contour, which is exactly why the disc boundary reads as the loudest line on the
actor (`glass-crack-rendering.md` §2.2). A standing web has to be visible without
being loud, and that is the rule that achieves it.

### 5.4 What the renderer gets, and what it must derive

| | needs | supplied as |
|---|---|---|
| 1 | the curve | `strand(i)`, ordered origin → tip — ordering is what lets `reveal(t)` animate without the model knowing about time |
| 2 | arc length per vertex | `arc(i)` — the integrator already has it; drives taper and reveal timing |
| 3 | opening width | **derived**, from `arc`, `length` and `aperture` via √(*a* − *s*). Width is optical; in the net it would let the renderer's taste leak into the model |
| 4 | depth | **derived**, `GLASS_THICK × aperture(s)/aperture(0)`. `GLASS_THICK` already exists (`enemy_view.gd:90` (`GLASS_THICK`)) |
| 5 | the glint | `origin(i)` |
| 6 | terminus type | `terminus(i)` — the one non-geometric datum that matters: a `T` groove must not overshoot the crack it met, an `S` is hidden by the silhouette, and an `F` must taper to nothing or it reads as a *cut* |

### 5.5 The optics, bounded

- **Real refraction through the shard's thickness: no.** Not because the shards are
  flat — they are extruded prisms with real thickness — but because the project has
  already tried the screen-reading route and recorded the result. The docblock above
  `GLASS_SHADER` states that `refraction_enabled` forces `ALPHA` to 1 and reads a
  screen that, inside a transparent `SubViewport`, is **empty**; the first pass came
  out as grey pebbles. Any proposal to read the back buffer here has to answer that
  finding first.
- **Fresnel: already correct** and already the load-bearing term.
- **Total internal reflection: skip.** At grazing angles Fresnel already approaches
  1 and reads as TIR.
- **Chromatic dispersion: skip.** At shard sizes it is closer to noise than signal,
  and it costs extra taps in the one place fill is already highest.
- **The lit lip is the whole signal.** This is the project's own standing rule —
  `procedural-glass-reads-off-its-edges.md`: glass is read off its edges, unevenly,
  as a function of each edge's normal against a real light.

Two cheap additions worth building after the groove reads correctly, in order:
**light escaping through a crack during ignite** (the reference bakes this as
`bakeCrackBeams`), and **the seam catching a rim light before the blow lands**,
which the `marked` uniform already half does.

**Both built, 2026-07-26, and both cost less than this section assumed.** The beams are a
zoom blur of the groove away from the impact hearth, folded into `BODY_SHADER`'s existing
emission — no bake, no plane, no extra draw call — at 24 taps paid only while the vessel
burns. The rim light was not an addition at all: see §8, step 7. Two figures were judged
rather than derived and are recorded as such. **24 taps**, because a zoom blur is a sum of
displaced copies and at 8 they landed further apart than the groove is wide, so the shafts
came out as ladders of parallel stripes. **Gain 0.65**, because at the reference's strength
the shafts washed the head out and read as white paint; the seams were already hot without
them, so the beams' job is the direction and not the brightness.

## 6. Tests and the purity gate

`tests/test_arch.gd` already scans for banned tokens per path
(`tests/test_arch.gd:56` (`_scan_file`)). Extend it with a second rule rather than
a second scanner:

```
res://presentation/combat/fracture
  banned: Node SceneTree Tween Mesh Material Shader Viewport Time
          RandomNumberGenerator FileAccess Input OS get_tree
  exception: body_mask.gd may name Image
```

Two of those bans do real work. **`RandomNumberGenerator`** is banned so the module
cannot reintroduce the stream pollution recorded as `glass-crack-rendering.md` §7
— the only randomness is the injected `Rng` (`domain/rng/rng.gd`, already pure,
already has `get_state()`). **`Time`** is banned so propagation cannot become
time-driven inside the model.

**As built, 2026-07-26: both the gate and the invariants live in
`tools/check_fracture.gd`, not in `tests/`.** `tests/` is not this lane's to write
— the organiser owns the suite verdict — so the checker was written in the suite's
own shape instead: `tests/run_all.gd` discovers `res://tests/test_*.gd` and calls a
static `run(fails)`, which is exactly what that file provides. Folding it in is a
verbatim copy to `tests/test_fracture.gd`, no edits. Run it standalone with

```bash
godot --headless -s res://tools/check_fracture.gd
```

Three of the five verified defects are properties of the net and the mask rather
than of the propagator, so they are already gated: §3.2 by asserting a committed
strand is byte-identical after later commits (and that mutating a returned strand
cannot reach back in), §3.3 by a `reaches` test across a transparent band — a
tendrilled painting in miniature, where `solid` says yes at both ends and only a
swept test knows the two sides are unconnected — and §3.1 by the terminus
vocabulary and the junction census. The remaining two need `FractureField`.

The gate itself was verified by making it fail: a probe file naming `Time` and
`Node` was reported on the right lines and the run went red, then green again when
removed. A gate that has never failed is not known to work.

`tests/test_presentation.gd` gains the invariant set, which turns the five verified
breaks into a regression gate:

1. every terminus is `T`, `S` or `F`, and every `T` lies within `step` of another
   strand — §3.1;
2. a committed strand is byte-identical after later strikes — §3.2;
3. no vertex fails `solid`, no segment fails `reaches` — §3.3;
4. `Carve.shards()` union area is within ε of the body-polygon area, and no shard
   is degenerate — §3.4;
5. strand density falls monotonically with distance from `Blow.at` — §3.5;
6. `T`-junctions outnumber `Y`-junctions.

This is the answer to *what does visualising the physics actually buy*: a pure
model can be asserted against invariants rather than golden images, and the entire
defect list becomes a gate. The purity split and the injected mask exist **because
of** these tests, not alongside them.

### The invariants that were added because something got past the existing ones

Each of these exists because a defect survived a green run. Listed with what let it
through, since that is the reusable part:

| invariant | what it caught | why nothing else did |
|---|---|---|
| `_check_field_arm_count` | the arm count saturated at 7 for any energy above 0.23 | Griffith held perfectly — total length stayed proportional to energy however it was split, so every length-based check passed |
| the emission floor in `strike` | a 0.024-body stub, under the legibility floor | it was the *new* count invariant that surfaced it; nothing before it looked at individual arm length |
| relieve idempotency | a second rite would double the whole network | the first call's behaviour was correct, and nothing called it twice |
| the `T == 0` assertion inside `_check_field_termini` | `T ≥ Y` passing vacuously at zero junctions | a comparison of two zeroes is true |
| `_check_field_reveal` | the reveal's width law anchored to the window instead of the strand, beading every groove at each frame boundary | it is a *renderer* defect, and the only one here — the model was untouched and correct throughout. And a beaded crack still looks like a crack, so the sheet could not have caught it either |

And two defects that **no** invariant caught, both found by drawing the model:

* the radial assignment (§2.4) — every arm was a straight ray, which violates nothing
  a test was asking about. Radiation, termini, energy, body-containment and
  determinism were all satisfied by a crosshair.
* the missing capture (§2.4) — nine crossings the eye could see and the census could
  not, because a tip arresting 3 steps short of a crack is a legitimate `F`.

The lesson worth keeping: invariants catch *contradictions*, and a model can be
perfectly self-consistent and still not look like the thing it models. The sheet is
not optional and §8 makes it a build step for that reason.

**The reveal check is the one that runs the other way, and it is worth naming as its own
case.** It is the only invariant here that guards the renderer rather than the model, and
it exists because the defect it catches is invisible to *both* of the other instruments: a
beaded groove satisfies every model invariant, since the model never saw it, and it reads
as a crack in every render, since a crack is a beaded-looking thing anyway. It was written
before the code that would have shipped the defect, and it went red on the first run. That
is the whole argument for writing the assertion first when the failure mode is one an eye
cannot see.

## 7. Cost

**Measured** where it says measured. Everything else is still an estimate and is
labelled as one, because a table that mixes the two reads as though all of it were
known.

| | when | cost | how |
|---|---|---|---|
| propagation, one blow | on a hit | **0.46 – 1.96 ms**, mean 1.1 ms over 8 accumulating blows on a duskfang | measured |
| field rasterise, one blow | on a hit | **0.87 – 2.96 ms**, mean 1.6 ms, same run | measured |
| — the same, revealed | spread over the front | **1.2× the total, ÷10 per frame.** 4.7 / 8.3 / 11.4 ms whole becomes 0.62 / 0.95 / 1.40 ms per frame at ten windows, for energies 1.1 / 2.0 / 3.2 | measured |
| texture upload | on a hit, or per frame while revealing | **0.01 ms** — one `ImageTexture.update` of 128 KB. Ten of them is still 0.1 ms | measured |
| worst single hit | on a hit | **~4.5 ms**, propagate + rasterise + upload together | measured |
| the screening query | inside propagation | direct, no cache. The 128² oracle below was not needed — see §4 | as built |
| body mask | once per **painting**, not per actor | one 256² decompressed alpha image, ~256 KB, cached in `EnemyView._mask_cache` | as built |
| drive-field heatmap | lab only, on toggle | 40² samples × every segment in the net — hundreds of ms on a busy net | measured; never runs in game |
| per frame, steady state | every frame | **three texture fetches** — the value and two neighbours for the gradient, inside one `if` a clean creature never enters | as built |
| memory | per damaged actor | 128 KB `RG8` field + ~77 KB of polylines | as built |
| carve, at death | once per rite | **0.7 ms at one blow, 8.6 ms at eight** — a single-frame spike, not amortised | measured |
| shards produced | once per rite | **5 at one blow, 12 at two, 16 at eight**; the reference's band is 9–16 | measured |

**~4.5 ms is the number to watch.** That is a quarter of a 60 fps frame on the worst
single hit, it is paid once per landed blow and never per frame, and it grows with the
net because both the crossing test and the rasteriser walk what is already there. The
cap of eight impacts is what bounds it. Two mitigations are already in and are the
reason it is 4.5 and not 20: the field composites **only the new strands** rather than
rebuilding, and each strand is Douglas–Peucker simplified before rasterising, which cuts
five sixths of the segment boxes with no visible displacement.

**The reveal turned out to be a third mitigation rather than a cost, which was not the
expectation going in.** Rasterising in arc windows does more total work — 1.2× at ten
windows, because every window re-walks the segment list and re-derives its boxes — but
it removes the rasterise from the blow's own frame entirely. The spike that mattered was
`propagate + rasterise + upload` in one frame; it is now `propagate + one window +
upload`, roughly 3.4 ms, with the remainder spread across the ten frames the front takes.
Propagation itself is **not** amortised and must not be: the model has no clock, the net
is committed whole on the blow, and the next blow's screening reads it (§5). The overhead
falls as the window count rises only because each window's fixed cost is amortised over
more texels — do not read the ×1.05-at-six-windows row as an argument for fewer windows,
since fewer windows is a coarser animation at a higher per-frame spike.

If it ever needs to be cheaper, the rasteriser is the half to attack — it is a
`PackedByteArray` inner loop in GDScript and the same work on the GPU is free.

The carve's **8.6 ms is a spike on the shatter frame**, and it lands alongside spawning
sixteen `RigidBody3D`s with meshes and colliders. It was budgeted here at 2.5–6 ms and
amortised over the rite, which was wrong on both counts — it is not amortisable, it all
happens in the frame the vessel hands off. The `_weld` fold is the expensive half and it
is quadratic in ribbons before the AABB reject; welding by spatial bucket instead would
be the fix if a death ever visibly hitches.

Against the measured 113 MB per actor — dominated by the `SubViewport` colour and
depth attachments — the memory is noise. The crack model is **orthogonal** to the MSAA
and `oversample` levers, and cannot help or hurt that budget.

## 8. Build order

| | step | blocked by |
|---|---|---|
| 0 | Give fracture its own RNG stream — `glass-crack-rendering.md` §7 | nothing. Precondition for every render comparison |
| 1 | `_death_cells()` reads `_sites` plus a sparse background grid — port `_voronoiParts`, the primary that was never ported | nothing. Fixes §3.4 today on convex input, and makes the network a two-consumer seam before any generator exists |
| 2 | Resolve the ordinary-damage `crack()` call against `CONCEPTS.md` | owner |
| 3 | ✅ **built** — `Blow` / `CrackNet` / `BodyMask` + the purity gate + the net and mask invariants, no renderer | 1 |
| 4 | ✅ **built, and it passed** — `FractureField.strike` / `relieve` with the §2.4 rule, screening, capture, forking, the emission floor and five arrest cases, gated by nine field invariants (seventeen checks in all); plus `FractureProbe` and the lab's `--fracture` sheet | 3 |
| 5 | ✅ **built** — `CrackField` + the three-band groove folded into `BODY_SHADER`; the old disc web is off behind `EnemyView.discs` | 4 reads as fracture ✅ |
| 6 | ✅ **built** — `Carve`, `shatter()` consumes it, and invariant 4 is real. The shard count follows the damage | 5 |
| 7 | ✅ **built, in part deliberately** — `reveal()` propagation, the ignite beams, and `crack_marked` finally wired. `CrackRibbon` **declined**; see below | 6 |

### Step 7, and why it is not all of step 7

`reveal()` and the beams are built. **`CrackRibbon` is not, and that is a decision rather
than a remainder.** §5.2 states its purpose exactly: it is a hedge against the memory gate
forcing MSAA to 2×, where a field groove antialiases itself and an extruded ribbon breaks
into a dim broken line. Nobody has made that decision, `CrackField` reads correctly at the
MSAA the game ships with, and building a second renderer against a maybe is the
gold-plating §5.2's own last sentence disclaims. The interface stays as specified so it
remains buildable the day the gate moves; the row is closed rather than left open, because
an open row that nobody should act on is worse than a closed one with a reason.

Two things landed with the reveal that are worth separating from it:

* **`crack_marked` was wired and dead.** `BODY_SHADER` has carried the uniform and a
  docblock claiming it lights the fracture cores under a lethal preview since the groove
  landed, and `set_marked()` only ever set the ward glass. §5.5's second cheap addition was
  therefore not an addition at all — it was a two-line fix to something already written and
  never connected. Recorded because "the uniform exists" reads as "the feature exists".
* **The beams cannot leave the silhouette, and the constraint is architectural.** The
  reference bakes them onto a plane padded 1.6× past the body precisely so the rays escape.
  Folded into the body material — which is what `one-backbuffer-copy-per-frame.md` requires
  — they inherit the painting's own `ALPHA`, so a ray past the silhouette lands on a
  transparent texel and contributes nothing. What is built is the light bleeding along and
  out of the grooves. The escaping rays need the padded display plane and are a separate
  change; `BEAM_REACH` is set well under the reference's 1.1 for that reason, since a shaft
  that would have travelled outside is only paying for taps that land on nothing.

### The kill test, and its verdict

Step 4 was the kill point: if radial arms with a damage-proportional length do not
read as fracture when drawn as bare polylines, no amount of optics rescues it and the
cheap answer is to stop. The instrument is `presentation/lab/fracture_probe.gd`, drawn
over a live actor at hairline width with no taper, no groove and no light — crude on
purpose, because prettying it up destroys the evidence.

```bash
tools/shot.sh --enemies --fracture=duskfang --shot=/tmp/kill.png
tools/shot.sh --enemies --fracture --stops --shot=/tmp/stops.png
tools/shot.sh --enemies --fracture --field --energy=2.0 --shot=/tmp/field.png
```

Six cells: one blow, two, three, five, eight, then those eight with the rite run over
them. Same seed and same blow positions in every cell, so cell N+1 is cell N plus one
more blow and the accumulation is readable rather than six unrelated fights.

**First run: failed.** A surveyor's crosshair — four straight arms at near-right
angles, no branches, and `0T/0Y` across every cell. Three symptoms, two causes, both
in §2.4: the radial assignment, and an even energy split.

**Second run: passed.** Uneven arm lengths, visible curvature, branches, and a census
that grows `0T → 2T → 5T → 9T` with `0Y` throughout — T-junctioned, which is the
signature the whole model exists to produce. `31 strands · 3.62 body · F8 (0 open)`
after the rite: every free tip carried out, so the network partitions the body and the
carve of step 6 has something to cut along.

Three things the sheet settled that no invariant could:

* the arm count rule was degenerate (§3, legibility floors);
* the T-junction census was reading nine crossings the eye could see and the model
  had not made (§2.4, capture);
* `relieve()` was not idempotent (§2.4).

And one it settled the other way: the `--field` view showed the mask registering
exactly on the silhouette — tail, spikes and legs — with a cold halo tracing every
existing crack. What looked at first like cracks running off the body were cracks on
the spikes. The heatmap is the reason `drive_at` is public.

## 9. Open

- **Whether standing accumulation exists at all.** `CONCEPTS.md:115-120` says
  cracks are not driven by ordinary damage. The owner has accepted that
  `CONCEPTS.md` will be updated; which direction is unconfirmed. §4 makes
  accumulation affordable either way, so this is a design question and no longer a
  performance one.
- ~~**Whether the ward-shatter `crack()` call survives.**~~ **Closed, and it was a
  mislabel rather than a question.** There is no ward `crack()` call and there never was:
  the ward path is `set_ward_shell` / `_restore_ward_shell` and it never touches the crack
  model. The two calls are `combat_screen.gd:1802`, which is the **`SHATTER` event** — the
  FACET gauge filling, `CONCEPTS.md` › Facet, and a wholly legitimate glass event on the
  creature's body — and `combat_screen.gd:2098`, ordinary damage. Recorded rather than
  quietly deleted because the wrong label survived several passes over this file, and a
  question about a call that does not exist is worse than no question.
- **The ward and the crack no longer share a primitive, and that was the real overlap.**
  Not in the call graph — in the shader. The ported ward shell built its facets from a
  **Voronoi second-nearest seam over 37 sites**, which is construction-for-construction the
  disc web `glass-crack-rendering.md` §2.2 condemns and `CrackField` replaced, so a guarded
  creature and a damaged one spoke the same language. Rewritten 2026-07-26 as a cut gem held
  in front of the creature: eight large hard-edged facets, a table, and **nothing hashed,
  jittered or seeded anywhere**. The order is the point, and it settles the problem at the
  level of meaning rather than of primitive — *a ward is manufactured and identical every
  time; a fracture is natural and never repeats*. That contrast an eye reads without being
  taught; "Voronoi cells of one size against Voronoi cells of another" is not a contrast at
  all. `CONCEPTS.md` › Benchmark is the rule that permits it: the web build is authority for
  what the game does, never for a shape its own platform forced on it, and a 192² canvas
  bake cannot carry authored facet geometry.
- ~~**A blow into recently-broken glass can score literally nothing.**~~ **Fixed, and
  it was a modelling defect rather than the tuning question it looked like.** Measured
  at four of eight blows scoring zero on a duskfang. Screening is right for the far
  field and wrong at the contact: right under an indenter the stress is set by the
  contact pressure, which does not care that there is a free surface 0.05 body away, and
  the material there is comminuted. `CONTACT_RADIUS` now arrests nothing inside it but
  the body's edge — and because it is set above `MIN_ARM`, every arm gets enough clear
  run that "a blow always marks" is structural rather than probabilistic.
  `_check_field_always_marks` pins it. Two related fixes fell out of the same
  investigation: the arrest test became an intersection rather than a proximity (see
  §2.4), and `EnemyView`'s random blow point now consults the body mask, which was
  silently scoring a quarter of all blows in empty air.
- **A strip cannot photograph a beat shorter than its own readback, and this is not
  specific to cracks.** `_shoot_strip` waits against the wall clock and each cell costs a
  `get_image()` of the whole 3620×2516 frame, which measured at roughly 70 ms — so the
  propagation strip's *first* cell landed 64 % of the way along the arc and the six cells
  read as one still. Traced, not guessed: a print inside `_set_reveal` showed the tween's
  first step already at 0.286 of 0.444. `--crack` therefore sets `Engine.time_scale = 0.06`
  and converts its frame list from beat time to wall time; everything photographed is still
  the real tween, the real easing and the real idle deform. **`--hit`'s 90 ms flash peak
  has the same problem and has not been checked for it** — it was framed and approved
  before this was understood, so its cells may not be where its comment says they are.
- **`FractureProbe` shares the model with the shipping renderer and must not become
  it.** The moment it grows a taper it stops being evidence. `CrackField` was built
  beside it, not out of it, and the probe's hairlines are unchanged.
- **The old disc web is off, not gone.** `EnemyView.discs` defaults false and the
  comparison is still available from code. What is left of it is now only a *fallback*:
  `_voronoi_cells()` breaks a vessel that shatters without ever having been struck, which
  the lab's `S` key does and any caller that skips to the ending can. `_sites`,
  `_death_sites` and the ring table exist for that path alone and could be deleted the day
  a struck-first precondition is acceptable.
- ~~**The debris reads as plywood.**~~ **Explained, and it is not a defect.** Established
  by elimination, one capture per step, each writing the term under test straight to
  `EMISSION` so the reading is unlit — the first pass wrote them to `ALBEDO` and measured
  value × lighting, which is a trap worth naming.

  | ruled out | how |
  |---|---|
  | the fracture-face treatment | `COLOR.r` painted red: the pale areas are **caps**, not faces |
  | more fracture face after the carve | same rite before and after, pixel-comparable |
  | domed cap normals | real, and fixed — see below — but the tan survived the fix |
  | emission of any kind | whole `EMISSION` zeroed: **still tan** |

  What is left is `ALBEDO × lighting`, and a cap's albedo is the painting untouched. So it
  is the LIGHTING, and the reason is structural rather than a bug: **the body is a flat
  quad nearly edge-on to the key, and a tumbling shard turns its faces square into it.**
  The same dark painting lit as a real surface instead of as a front-lit pane goes tan.
  That is a consequence of making 3D debris out of a 2D painting and it will not be tuned
  away in `SHARD_SHADER`; if it is to change, it is an art-direction call about how much
  key a shard should take, and it belongs to whoever owns that.

- **Two real defects fell out of that hunt, and both are fixed.** Neither caused the tan.
  * `generate_normals()` **domed every cap.** It averages the faces meeting at a vertex,
    and a carved shard has NO interior vertices — every cap vertex is on the outline, so
    every one of them averaged with the side band. Not a flat cap with a bevelled rim: a
    cap bevelled everywhere. Measured at `f = 0.45` on faces pointing straight at the
    camera, where a flat cap reads 0. §5.2 named this mechanism and expected it to bite the
    crack ribbon; it had been biting the debris since the rite was built. `_prism` now
    authors its normals. `set_smooth_group(-1)` was tried first and did not fix it.
  * **The back cap was wound like the front**, so `triangulate_polygon`'s one winding left
    it facing into the shard, which `cull_disabled` draws anyway.
- **Two silhouette readers coexist, and the prediction here was wrong.** This bullet used
  to say step 6 would delete `_alpha_at`/`_touches_art` along with the Voronoi cells it
  culls. It did not, and could not: the CARVE culls through the same
  `_touches_art(cell, centre)` (`enemy_view.gd:3444` (in `_death_cells`)), because a shard
  covering no painting is a pane of empty box that the shard shader draws as nothing while
  the physics still tumbles it. So the older reader outlived the path it was written for.
  Both are still there — `body_mask()` at 256² for the model, `_alpha_at` at full
  resolution for the cull — and consolidating them would change an already-approved death
  for a refactor's sake. Left, deliberately, with the reason stated rather than a second
  prediction.
- **The measurement that would settle nothing but is still worth having:** time
  step 4's propagator on the largest creature with a 20-blow turn. Measured so far:
  0.14–1.43 ms per strike on a duskfang, which is a whole frame's budget at the top
  of that range and worth knowing before the count is raised.
