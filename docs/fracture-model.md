# The fracture model — specification

Status, 2026-07-26: **specified, not built.** This is the design that survived two
rounds of three-seat review. `docs/glass-crack-rendering.md` is the companion: it
records why the present crack web is wrong, what was rejected, and the decision
history. This file says what to build.

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
presentation/combat/glass/           Node / Mesh / Shader allowed
  crack_field.gd     class_name CrackField      the field renderer — the target
  crack_ribbon.gd    class_name CrackRibbon     the ribbon renderer — optional
```

`BodyMask` is the only file in `fracture/` permitted to name `Image`. It wraps the
art alpha — today `presentation/combat/enemy_view.gd:1534` (`_alpha_at`) — behind
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

```gdscript
var radial: Vector2 = (tip - origin).normalized()          ## the heading
var bias: float = 1.0 + ANISO * absf(radial.dot(blow.dir)) ## the blow's preference
var drive: float = _energy_here(tip) * bias - _screened(tip)
tip += (radial.rotated(_rng.next_range(-jitter, jitter))) * step
```

Recorded because one review seat produced the inverse — heading taken as
`blow.dir.rotated(PI/2)`, a single direction everywhere, which makes every crack
run parallel instead of radiating. Its prose was correct and its pseudocode was
not. The closed-form Flamant point-load field it derived first *is* the right
starting point; the simplification is what inverted it.

Termination, in the order tested:

1. `drive < toughness` → **`F`**, a free tip. Must taper to literally nothing.
2. the segment fails `BodyMask.reaches` → **`S`**, the silhouette.
3. the tip comes within `step` of any existing strand → **`T`**, a T-junction.

Rule 3 is the entire topology fix. Sequential arrest on an existing free surface
is what makes impact fracture T-junctioned, where Voronoi's simultaneous
construction gives Y-junctions at 120° — the signature of shrinkage, not impact.

A tip **bifurcates** when local drive exceeds `2 × toughness`. That factor is
fixed on the mechanics — a single tip cannot dissipate much beyond 2 G_c — and is
not exposed. The reference authors a 45 % fork probability; here it is derived.

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

**Material — four.**

| | name | unit | meaning | its one job |
|---|---|---|---|---|
| 1 | `toughness` | energy per unit length | Griffith's G_c — how hard this glass is | the arrest threshold; `relieve()` sets it to 0 |
| 2 | `screen_radius` | body fraction | the process zone: how far a free surface relieves tension | how tightly a later crack bends toward an earlier one |
| 3 | `heterogeneity` | radians per body fraction | grain — how much a running tip wanders | path jitter |
| 4 | `sharp` | 0..1 | indenter acuity | the radial / concentric energy split |

**Numerics — one, plus one derived.** `step` (body fraction per Euler step), and
`max_steps = ceil(1.5 / step)` because a crack cannot exceed 1.5 body diagonals.
`step` carries a **convergence test**: halving it must move no tip by more than
`step`. A numerics constant with a convergence test is an assertion, not a knob.

**Renderer — one, plus one derived.** `aperture`, the crack mouth width at the
origin. Opening displacement goes as √(*a* − *s*), so the whole profile follows
from `aperture` and `length(i)`. And `kerf` — the width the carve knife removes —
**is `aperture` read at the strand's mid-length**, so the debris edge lines up with
the groove that was showing. One physical quantity, two consumers, where today two
unrelated numbers would be tuned apart.

Derived floor on `aperture`: the groove must be ≥ ~1.5 stage pixels at the smallest
actor or it scintillates whatever the MSAA. At a 115 px sporeling with
`oversample` = 2.0 (`enemy_view.gd:142` (`oversample`)) one body unit is ≈ 230
stage px, so **`aperture` ≥ 0.0065 body**. The reference's ≈ 0.015 clears it 2.3×.

**Blow inputs — all derived, none authored.** `at` from the hit point already
computed for the floater (`enemy_view.gd:1150` (`body_centre`)); `dir` from the
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

Six authored numbers replace roughly thirteen — but that is not the argument.
**None of the six describes a shape.** Four describe a material, one an
integrator, one an optical width. Shapes are computed. A creature added tomorrow
needs no fracture authoring, which is the same payoff
`docs/solutions/design-patterns/derive-authored-compensations-when-porting.md`
recorded for the shadow knobs.

### The one honest fudge

`bite`, converting `damage / max_hp` into fracture energy. No physics connects a
card's damage number to joules. It is honest on three counts: it is a **unit
conversion**, the one class of constant allowed to be arbitrary; it is **global,
not per-creature**; and it has a **calibration rather than a slider** — choose
`bite` so a blow removing all of a foe's health carves into 9–14 shards, the count
`_death_sites`' rings were tuned to and the rite is already approved at.

A second, smaller concession: the archetype → `sharp` mapping is taste. One number
per archetype, beside the archetype tints (`VfxLayer.TONES` is the precedent).
Taste gets ported, not derived.

## 4. Screening, and why accumulation is affordable

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
  have**. The existing `_prism` calls it (`enemy_view.gd:1359` (in `_prism`)), so
  the ribbon needs authored crease normals, not the convenience path.
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
| 4 | depth | **derived**, `GLASS_THICK × aperture(s)/aperture(0)`. `GLASS_THICK` already exists (`enemy_view.gd:78` (`GLASS_THICK`)) |
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

## 7. Cost

| | when | cost |
|---|---|---|
| propagation, one blow | on a hit | ~320 Euler steps, O(1) screening each |
| screening composite | on a hit | ~19 k byte writes, ~1 ms |
| field rasterise | on a hit | one incremental composite |
| carve, at death | once per rite | ~2.5–6 ms, amortised over a 200 ms rite ≈ 0.03 ms/frame |
| per frame, steady state | every frame | **one texture fetch** |
| memory | per damaged actor | 128² screening (16 KB) + render field sized from `_box_u` (64 KB at 256²) + ~77 KB of polylines |

Against the measured 113 MB per actor — dominated by the `SubViewport` colour and
depth attachments — this is noise. The crack model is **orthogonal** to the MSAA
and `oversample` levers, and cannot help or hurt that budget.

## 8. Build order

| | step | blocked by |
|---|---|---|
| 0 | Give fracture its own RNG stream — `glass-crack-rendering.md` §7 | nothing. Precondition for every render comparison |
| 1 | `_death_cells()` reads `_sites` plus a sparse background grid — port `_voronoiParts`, the primary that was never ported | nothing. Fixes §3.4 today on convex input, and makes the network a two-consumer seam before any generator exists |
| 2 | Resolve the ordinary-damage `crack()` call against `CONCEPTS.md` | owner |
| 3 | `Blow` / `CrackNet` / `BodyMask` + the purity gate + invariants 1–3, no renderer | 1 |
| 4 | `FractureField.strike` with the §2.4 rule and the screening oracle. Draw it in the lab via `drive_at`. **Kill-test:** radial arms as a plain polyline overlay | 3 |
| 5 | `CrackField` — the three-band groove, §5.3 | 4 reads as fracture |
| 6 | `Carve` + `relieve`, and `shatter()` consumes it. Invariant 4 | 5 |
| 7 | Optional: `reveal(t)` propagation, ignite beams, `CrackRibbon` | 6 |

Step 4 is the kill point. If radial arms with a damage-proportional length do not
read as fracture when drawn as bare polylines, no amount of optics will rescue it,
and the cheap answer is to stop there.

## 9. Open

- **Whether standing accumulation exists at all.** `CONCEPTS.md:115-120` says
  cracks are not driven by ordinary damage. The owner has accepted that
  `CONCEPTS.md` will be updated; which direction is unconfirmed. §4 makes
  accumulation affordable either way, so this is a design question and no longer a
  performance one.
- **Whether the ward-shatter `crack()` call survives** even if the ordinary-damage
  one goes. A guard shattering is a glass event rather than attrition, so it has a
  case the damage call does not.
- **The measurement that would settle nothing but is still worth having:** time
  step 4's propagator plus screening oracle on the largest creature with a
  20-blow turn. The design already assumes the oracle; the number tells you whether
  `step` can afford to be finer.
