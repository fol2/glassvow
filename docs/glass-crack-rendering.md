# Glass-crack rendering — the Godot side

Status, 2026-07-26: the **death shatter is shipped and approved**. The **standing
crack web is not** — it reads as a stack of same-radius circles, and the cause is
geometric rather than a tuning miss. §6 records two three-seat reviews: the first
settled the design surface, the second refined the surviving option into
`docs/fracture-model.md`, which is the buildable specification. Two changes are
cleared to build ahead of everything else — §7 and §6.4 step 1.

Line anchors here are correct at the commit that wrote them and drift within
hours, because six lanes edit `presentation/` concurrently and one was editing
`enemy_view.gd` while this was written. Re-anchor with
`python3 tools/check_anchors.py --fix` rather than trusting a number.

## Why this file exists

`presentation/combat/enemy_view.gd:22` (`in EnemyView`) and
`presentation/lab/enemy_lab.gd:444` (`in KNOBS`) both cite
`docs/glass-crack-rendering.md`. Until today that path resolved **only in the
benchmark worktree**, so both citations were dangling references in this repo —
a reader following either one found nothing.

The benchmark's document is still the authority for the *web* architecture and
for the approved measures. Read it at
`../roguecardv2-benchmark/docs/glass-crack-rendering.md` (85 lines,
roguecardv2@6e069118). It describes a three.js `MeshPhysicalMaterial`
transmission stack built out of baked 192² canvases — an architecture this port
deliberately does **not** share. This file describes what Godot actually builds.

## 1. What is built

Two paths share one Voronoi routine, `_voronoi(sites, reach)`
(`presentation/combat/enemy_view.gd:2050` (`_voronoi`)):

| | standing crack web | death shatter |
|---|---|---|
| entry | `crack()` (`enemy_view.gd:2210` (`crack`)) | `mark_dead()` (`enemy_view.gd:2358` (`mark_dead`)) |
| sites | `_sites`, appended one per call, cap `MAX_SITES` | `_death_sites()` — graded rings around the burst |
| cells | `_cells()` (`enemy_view.gd:2079` (`_cells`)) — **`reach` > 0** | `_death_cells()` (`enemy_view.gd:2481` (`_death_cells`)) — **`reach` = 0** |
| body mask | none | `_touches_art()` (`enemy_view.gd:2534` (`_touches_art`)) |
| geometry | `_prism()` → `MeshInstance3D` under `_glass_root` | `_prism()` with per-shard `origin` → `RigidBody3D` |
| material | `GLASS_SHADER` — refraction + Fresnel | `SHARD_SHADER` — opaque cap, molten fracture face |

`reach` is the whole difference. At `reach = 0` the cells tile the quad
completely, which is what the rite wants: the **whole** body cut into panes. At
`reach > 0` each cell is additionally intersected with a disc around its own
site — and that is where the circles come from.

## 2. Why the standing web reads as circles

Four mechanisms, all verified in source, compounding.

**2.1 The circle is a literal circle.** `_cells()` passes
`_glass_area * minf(_quad_w, _box_u) * 0.5` as `reach`, and `_voronoi` clips
every cell against `_disc(sites[i], reach)` (`enemy_view.gd:2037` (`_disc`)) — a
20-gon of **constant radius**. The arc is not an artefact of shading or of
sampling. It is drawn.

**2.2 The arc wears the brightest treatment in the effect.** `_prism()`
(`enemy_view.gd:2094` (`_prism`)) extrudes *every* edge of the cell into a side
band tagged `COLOR.r = 1`, and `GLASS_SHADER` (`enemy_view.gd:450`
(`GLASS_SHADER`)) lights that band by Fresnel: `ALBEDO` mixes toward white,
`ALPHA` gains `f * 0.6`, `EMISSION` gains `pow(f, 1.4)` for both `ignite` and
`marked`. All three channels emphasise the same contour, so the disc boundary is
the whitest, most opaque and most emissive line on the actor.

Per `docs/solutions/design-patterns/procedural-glass-reads-off-its-edges.md`, a
lit bevel *is* the visual signal for "cut glass". The shader is not wrong — it is
faithfully telling the player there is a fracture there. The geometry is lying.

Worse, the arc and the bisector — the boundary and the actual crack — get
**identical** material treatment. Nothing distinguishes "this is a fracture" from
"this is where drawing stopped".

**2.3 The arcs concentrate on the outside of the crack cluster.** Derived from
the code, not yet confirmed by render: `reach` is roughly 0.225 UV, while six
sites drawn uniformly from UV 0.2–0.8 sit a mean nearest-neighbour distance of
about 0.12 UV apart. So *interior* sites have Voronoi cells smaller than the
disc, the disc does not bind, and they tile correctly. It is the sites on the
**perimeter** of the cluster — whose cells run out to the quad edge — that get
truncated. Each new fringe crack adds one more arc to a scalloped outer
boundary, and every arc shares one radius.

**Constant curvature is the giveaway.** Real fracture boundaries have no
characteristic radius; a set of co-radial arcs can only read as circles.

**2.4 The first state the player sees is the worst one.** `_rebuild_glass()`
(`enemy_view.gd:2130` (`_rebuild_glass`)) returns early below two sites, so the
first visible crack state is two half-moons — one straight chord and one large
arc each. Maximum circle, minimum crack.

## 3. Four breaks that are not about the circle

**3.1 The topology is the wrong physics.** Voronoi bisectors meet three at a time
at roughly 120° — **Y-junctions**. That is the signature of *simultaneous,
isotropic* cracking: mud, basalt columns, glaze crazing, drying paint, all of
which genuinely are Voronoi-like because every crack nucleates at once and they
meet in the middle. Impact fracture is *sequential*: a running crack **arrests**
when it reaches an existing crack, because that free surface has already released
the stress driving it. Sequential cracking produces **T-junctions**. The current
web contains none.

**3.2 Existing cracks move.** `_rebuild_glass()` frees every child and re-runs
the Voronoi over all sites, so landing hit *N* reshapes the shards of hits
1…*N*−1. A fracture cannot relocate. This is likely a large part of the "looks
right, is not right" reading even where a player could not name it.

**3.3 The standing web has no body mask.** `_death_cells()` filters cells through
`_touches_art()`; `_cells()` does not. A standing disc can therefore hang off the
silhouette into empty space. Every benchmark bake gates on `alpha[i+3] > 90`.

**3.4 The body does not break along its own cracks.** `mark_dead()` tops `_sites`
up to nine, and then `_death_cells()` calls `_voronoi(_death_sites(burst), 0.0)`
— **`_sites` is never read**. The standing crack web is discarded at the instant
of death and replaced by a fresh radial pattern generated from the burst point.

The benchmark does the opposite, deliberately and in three places: `meshCrackSites`
exists to harvest the site UVs, `src/vfx.js:213` reads "the shatter breaks the body
along the exact seams the crack shader showed", and its own doc says the handoff
"harvests the sites … breaks the capture into its exact Voronoi cells".

**More precisely: this port shipped the reference's fallback as its primary.**
`src/vfx.js:296` reads

```js
const { parts: cells, ix, iy } = _voronoiParts(opts.sites) || _radialParts();
```

`_voronoiParts` is the primary and consumes the harvested crack sites plus a
sparse background grid, so the body breaks finely where the blows landed and in
coarse slabs elsewhere. `_radialParts()` is the **no-sites fallback**.
`_death_sites()` is a port of the fallback. The primary was never ported, so the
fix is not to invent anything — it is to port the path that already exists.

This is a **causal** break rather than a cosmetic one — the cracks scored into a
creature have no bearing on how it comes apart — and it is independent of every
other item here. Whichever option below is chosen, the shatter should consume the
crack network rather than invent a second one.

**And it violates committed project vocabulary, not merely benchmark parity.**
`CONCEPTS.md:117` (`Crack`) states that cracks "determine how the Vessel breaks
apart when the Death rite runs". They do not.

**3.5 Sites do not cluster at the blow.** `crack()` with no argument picks
uniformly from UV 0.2–0.8, so crack position is unrelated to where the hit landed
or how hard. Real impact fragments finely at the strike and coarsely outward —
and `_death_sites()` (`enemy_view.gd:2393` (`_death_sites`)) *already does this*,
with graded rings. The death path understands the grading; the standing path does
not.

## 4. What the benchmark did, and what this port did not carry

**4.1 Combat cracks are switched off in the benchmark.** `src/ui/combat.js:2004`:

```js
// TEMP (2026-07-07): combat cracks off while glass tuning continues — death
// rite still cracks via igniteVessel → meshCrack (not this helper).
const COMBAT_CRACKS = false;
```

So standing crack accumulation is **not shipped benchmark behaviour**. It is a
path its author disabled *because the glass was not right yet* — the same
conclusion reached here, nineteen days earlier. On the shipped path the mesh
crack overlay exists only inside the death rite, with three sites
(`for (let k = 0; k < 3; k++) meshCrack(x.art)`), for about 200 ms, and then
everything shatters. The disc has no time to become a problem.

This port calls `view.crack()` on **every landed hit** and again on ward shatter
(`presentation/combat/combat_screen.gd`, two sites, both annotated `addCrack`),
accumulating toward `MAX_SITES` (`enemy_view.gd:92` (`MAX_SITES`)) = 32. So the
port runs a disabled experiment, for a whole fight instead of a fifth of a
second.

**And this project already ruled on it.** `CONCEPTS.md:115-120`, the shared
vocabulary, under `Crack`:

> They are deliberately *not* driven by ordinary damage — the glass vocabulary is
> spent on death rather than on attrition, so a wounded creature does not visibly
> craze.

So standing accumulation from ordinary damage is **a compliance defect, not an
open design question.** Six lines of `CONCEPTS.md` carry two rules and the code
breaks both — this one, and the "determine how the Vessel breaks apart" clause
that §3.4 violates.

The compliant fix for this half is deleting the ordinary-damage `crack()` call,
which takes a fight from roughly thirty accumulated sites to none. Whether the
ward-shatter call also goes is a smaller judgement: a guard shattering *is* a
glass event rather than attrition, so it has a case the damage call does not.

If standing accumulation is wanted after all, that is legitimate — but it is then
**an edit to `CONCEPTS.md`**, made deliberately, rather than a leftover defended
after the fact.

`docs/actor-animation-checklist.md` §1.10 previously recorded that `crack()` "is
already only called from the lab". That was true when written and is now false:
`combat_screen.gd` acquired both call sites when the drain was wired. Corrected
there.

**4.2 Two approved measures diverge.** From the benchmark's approved-measures
table (user sign-off 2026-07-07):

| constant | benchmark | this port | |
|---|---|---|---|
| `GLASS_AREA` | 0.45 UV radius | 0.225 UV (`_glass_area` × ½) | **halved** |
| `GLASS_FEATHER` | 1 — *"region edge fades from the core — no visible disc"* | not ported | **absent** |
| site cap | 56 | 32 | |

The benchmark's mask is `inner = R * (1 - 0.9 * GLASS_FEATHER)`, so the outer
**90 % of the radius is feather**, followed by a smoothstep whose comment reads
"no visible ring at either boundary". The disc there is an alpha falloff and
never becomes a contour. What is visible is only `bakeCrackNormal`'s seam bevel,
where the normal deviates within `SEAM ≈ 0.0137` UV of a bisector — "FLAT except
at seams".

The two treatments are exact opposites. The benchmark makes the bisector visible
and the disc invisible; this port makes both visible and lights them the same
way. Both knobs also moved the wrong direction at once: a *large* radius with
90 % feather is invisible, and a *small* radius with a hard edge is maximally
conspicuous.

**4.3 Porting the feather is rejected as the fix.** Ruled 2026-07-26. The feather
is a web-era compensation: the benchmark could only bake distance-to-*site* into
a 192² canvas, so partial coverage had to be a soft disc, and the disc then had
to be hidden. Adopting it here would hide the boundary without removing the need
for one — coverage would still be governed by a disc, the network would still be
Voronoi, and 3.1 through 3.5 would all survive untouched. Godot can carry crack
*curves* and real geometry, which is a reason the engine was chosen; the fix
should remove the boundary rather than blur it.

Recorded because the feather is the obvious move, is the parity-safe move, and
carries a sign-off — so it will be proposed again unless the reasoning is
written down.

## 5. The physics worth stealing

A blunt or sharp impact on a thin brittle plate:

- **Radial cracks** nucleate at the impact and run outward. They form first,
  driven by hoop tension on the distal face as the plate flexes.
- **Concentric (circumferential) cracks** form between the radials as flexure
  continues, and they **terminate on** the radials. Radials do not cross one
  another.
- Fragmentation is **fine at the impact and coarse outward**; crack density falls
  with radius.
- Crack **length** scales with the energy delivered (Griffith: a crack extends
  while released elastic energy exceeds the surface energy created).
- A second blow near the first meets glass whose stress has **already been
  relieved** by the existing crack, so its cracks are shorter and bend toward the
  old one.

The last point is the one that matters most for how this reads: real accumulated
damage *interacts*. Independent patterns stacking is precisely what looks wrong.

**There is an authority for the morphology, and it is not the mesh path.** The
benchmark's own drawn crack, `src/art.js:58`, is exactly this figure:

> radial cracks that fork, tied by faint concentric web rings, dark-scored and
> light-caught, with a glint where the blow landed

Four branches, six for a big hit; forks at 45 % probability; and — worth noting —
`src/art.js:91` bows each ring chord inward "so it reads as a ring, not a
polygon". The author had already met the *my-arc-looks-wrong* artefact and fixed
it.

## 6. Council round 1, consolidated

Three independent reviews, 2026-07-26, with deliberately different charges:
architecture and synthesis; the minimal model plus a line-count audit; and a red
team. They were briefed from this document and from source, and did not see each
other's work. What follows separates what they **settled** from what is still
open, and records where a seat was wrong, because two of the findings that read
most decisively did not survive checking.

### 6.1 The simplification thesis: false in lines, true in coupling

All three seats independently concluded that a physics-first model does **not**
reduce GDScript line count. The decomposition that made this legible came from the
architecture seat and was then explicitly endorsed by the audit seat:

Of the ~416 lines of crack-and-shatter machinery, roughly **247 are death-rite
staging** — `mark_dead`, `shatter`, `_spawn_embers`, `_bounce` — which **no option
on this table changes**. `_prism` survives for debris regardless, and
`_touches_art`/`_alpha_at` survive and gain a caller. What a physics model actually
replaces is about **81 lines**: `_clip`, `_disc`, `_voronoi`, `_cells`,
`_death_sites`, `_death_cells`, and the site-push in `crack`.

| variant | replaces | born | net |
|---|---:|---:|---|
| full stack (morphology + field + budget + ribbons + carve) | 81 | ~240 GDScript + ~40 shader | **~3×** |
| same, with option 6 instead of option 7 | 81 | ~145 | ~+95 |
| **cracks confined to the rite, standing render path deleted** | 81 + `GLASS_SHADER` (54) + standing setup/teardown | ~150–170 | **~50 lines saved** |

So the thesis holds in exactly one branch — the one that also happens to be the
`CONCEPTS.md`-compliant branch (§4.1). The two conclusions are independent and
they agree.

**What actually shrinks is coupling, and that is the argument worth making.**
`_glass_area` currently sets coverage *and* disc radius from one number; `reach` in
`_voronoi` is a single parameter switching between two unrelated intents;
`MAX_SITES` caps a quantity with no physical meaning. A physics model is larger and
**sparse** — every parameter has one job and a unit. Coupling is what produced the
exitless tuning loop recorded in
`docs/solutions/design-patterns/procedural-glass-reads-off-its-edges.md`, so the
trade is worth making. Sell it as *fewer things that can be wrong*, not as fewer
lines, or the first line count will be read as a failure.

### 6.2 Settled unanimously

1. **Cracks belong to the death rite, not to attrition.** Reached independently by
   all three seats, and it is what `CONCEPTS.md:115-120` already says (§4.1). The
   three-crack variant is, in the audit seat's words, *"a knob, not a model
   change"*.
2. **The shatter must consume the crack network** (§3.4). Every seat named it.
3. **Memory is a non-argument.** The standing mesh is a few hundred triangles —
   tens of kilobytes. The 113 MB/actor figure is dominated by the `SubViewport`
   colour and depth attachments, so the crack model is *orthogonal* to the MSAA and
   `oversample` levers. Reached independently by the audit seat after the red team
   asserted a 32 MB saving, which is not physically possible at that triangle
   count.

### 6.3 Independently converged: how to carve cells from curves

The architecture and audit seats, without contact, proposed the **identical**
construction, and both explicitly rejected writing a DCEL or arrangement:

> At death, run every arrested crack tip to completion with the same propagator
> and `toughness = 0`. Then `Geometry2D.offset_polyline` each completed polyline
> into a thin knife polygon, `Geometry2D.clip_polygons` the body polygon by each
> knife in turn, and send non-convex results through
> `Geometry2D.decompose_polygon_in_convex` for the collision shape.
> `triangulate_polygon` and `_prism` are unchanged.

The reason completion is needed is worth stating, because it is the pit a naive
plan walks into: **a physically correct arrested network does not partition the
plane.** A crack that stops on `drive < toughness` is a dangling edge that
separates nothing. That is a consequence of the physics being *right*, not a bug in
it. Clipper does the robustness, and the kerf the knife removes is physically
correct.

Failure modes the audit seat named, to carry into any implementation: numerical
ill-conditioning where two cracks meet near-tangentially (jitter, or snap to a T or
X); `offset_polyline` silently vanishing segments shorter than the offset (clamp
minimum segment length to ≥ 2× offset); and clipping each completed polyline
against the body polygon *before* carving, since completion can otherwise run
outside the silhouette.

### 6.4 Sequencing: two seats disagreed, and the conflict dissolves

The audit seat wanted a cheap kill-test first — radial arms drawn as a polyline
overlay, hours not days — with the carve last. The architecture seat wanted the
**opposite**: build the shatter's consumption of the network *first*, while its
input is still trivially convex, because *"a seam with one consumer is not a
seam"*. Its argument is organisational rather than technical: the rite is shipped
and approved, the standing web is broken, and rewiring the shatter is the hardest
piece — so the natural path is to fix the visible thing, ship it, and never touch
the approved thing. Break 3.4, the causal one, then survives.

These do not actually conflict, because the architecture seat's step **needs no
model at all**. Resolved order:

| | step | blocked by |
|---|---|---|
| 0 | Give fracture its own RNG stream (§7) | nothing — precondition for every render comparison |
| 1 | `_death_cells()` reads `_sites` plus a sparse background grid — i.e. port `_voronoiParts`, the primary that was never ported (§3.4) | nothing — fixes 3.4 today, on convex input, and makes the network a two-consumer seam before any generator exists |
| 2 | Resolve the ordinary-damage `crack()` call against `CONCEPTS.md` (§4.1) | owner |
| 3 | Kill-test: radial arms, damage → length, drawn as a polyline overlay | 1, 2 |
| 4 | Stress field and screening | 3 reads as fracture |
| 5 | Swap the carve to offset / clip / decompose (§6.3) | 4 |
| 6 | Optional: distance field or ribbons for a visible 200 ms propagation | 5 |

Cost, from the audit seat: about **2.4 ms of CPU per rite**, amortised over the
200 ms rite at roughly **0.012 ms per frame** — negligible. The accumulating
variant is a different matter: the architecture seat costed a growing
nearest-segment query at roughly **115 000 distance queries per hit** in GDScript,
two orders of magnitude more, which is a further argument for confining the web to
the rite.

### 6.5 Where a seat was wrong

Recorded because both claims read as decisive and neither survived checking.

- **The red team costed the simplification thesis against a ~20-line baseline** —
  only the two entry functions, `crack` and `_rebuild_glass`, ignoring `_clip`,
  `_disc`, `_voronoi`, `_cells`, `_prism`, `_death_sites`, `_death_cells`,
  `_touches_art` and `_alpha_at`. Its direction was right and its magnitude
  ("3× the code") came from shrinking the comparison base about twentyfold.
- **Its determinism objection assumed the model would be domain or run state.** It
  is not: there is no crack state anywhere in `domain/`, `port_fixtures/` or
  `tests/`; `EnemyView` already draws from a view-local `RandomNumberGenerator`
  rather than the run's seeded stream; and `docs/commercial-game-delivery.md` §3
  states outright that non-RNG sources "may affect scheduling or UI, but not the
  run's outcome" — fixtures compare event traces, not pixels. What survives is one
  narrow rule: keep the model in presentation, on a presentation-local stream, and
  do not persist a stress field. The *real* determinism defect is unrelated to the
  contract and is recorded as §7.

The red team's durable contributions are the pathological-input list (§6.6) and
the steelman of the do-nothing branch, which is now the settled position.

### 6.6 Pathological inputs any model must survive

From the red team, and worth treating as an acceptance list rather than as
objections:

- The size ladder, 115 px sporeling to 1120 px leviathan — which is what makes a
  body-relative length budget (option 5) a requirement rather than a nicety.
- Paintings whose alpha has holes, tendrils or disconnected regions. A crack
  cannot cross a void, so arrest needs a connectivity test, not just an alpha
  sample.
- Twenty small hits in one turn versus one enormous hit. A single budget rule has
  to serve both, and tuning it for one can break the other.
- Poison and other `indirect` damage, which must not read as impact at all.

### 6.7 Corrections to the option table below

Three, all from the architecture seat:

- **Option 6 can animate propagation.** The table below implies only option 7 can.
  A `min()` composite is monotone and incremental, so a growing crack is literally
  "composite the next segment" — no mesh rebuild per frame, and cheaper than the
  ribbon.
- **Option 3 is not an alternative to option 4 — it is option 4's death half.** Its
  stated weakness, that a straight cut reads as *cut* rather than *propagated*,
  does not apply to debris, because a debris edge **is** a cut. Keeping option 3 as
  the standing-web fallback keeps the wrong half of it.
- **Option 6's field must be sized from `_box_u`.** 256² is right for a sporeling
  and mush on a leviathan.

One rule to disarm in advance: `CONCEPTS.md` › *Angle, not time* is scoped to
surface channels on a card that freezes its viewport. A one-shot 120 ms
propagation on an actor is an **event**, not a material channel, and the rule
should not be cited against it.

### 6.8 What round 1 never examined

Every seat discussed how cracks are **generated**. None examined how the glass is
**rendered** — reflection, refraction, Fresnel, dispersion. The current
`GLASS_SHADER` fakes refraction by offsetting the body-texture lookup
(`uv + r.xy * bend`), which is not a light path. Round 2 carries that axis.

### The options, with status

Numbering follows the original session discussion.

| | option | status |
|---|---|---|
| 1 | port `GLASS_FEATHER` | **rejected**, §4.3 |
| 2 | radial and concentric per blow | folded into 4 as its morphology |
| 3 | sequential splitting | **reclassified** as 4's death half, §6.7 |
| 4 | stress-field propagation | **the surviving option**, refining in round 2 |
| 5 | Griffith length budget | **required**, not optional — see §6.6 |
| 6 | incremental distance field | live; can animate, §6.7 |
| 7 | crack ribbons | live; real thickness and MSAA on the lip |

### Option 2 — Radial and concentric, one figure per blow

Each hit scores its own star: four to six forking radials, one or two bowed
concentric arcs, a glint at the impact point. Benchmark-authored taste and
correct physics.

- **Local by construction.** Several blows make several stars, which is what
  actually happens. No coverage parameter, so no disc and nothing to hide.
- Reach is irregular for free — jittered radial lengths, not one radius.
- Changes what a "site" means: a site becomes a *figure*, not a Voronoi seed.
  `_death_sites()` already keeps its own list, so the rite is unaffected.
- Needs a rendering answer for curves — see options 6 and 7.

### Option 3 — Sequential splitting instead of re-partitioning

Keep a list of cells. Per hit, cut the cell containing the impact with a line.

- Every cut terminates on that cell's existing boundary → **T-junctions**.
- Old cells never change → **cracks stop moving** (fixes 3.2 outright).
- Cells stay convex → `Geometry2D.triangulate_polygon` and `_prism` work
  unchanged, which makes this the cheapest structural fix by a wide margin.
- Bias cell choice toward the impact → graded density for free (fixes 3.5).
- Feeds the shatter directly: the cells *are* the shards (fixes 3.4).
- **Weakness:** a straight cut spanning a whole cell reads as *cut* rather than
  *propagated*, and it cannot animate a crack growing. Jittering a cut into a
  polyline breaks convexity and with it the cheap-machinery argument.

Gilbert tessellation is the closer physical model — seeds grow two rays and stop
on contact — but it yields non-convex cells, so it loses the same argument.

### Option 4 — Stress-field propagation (the scientific option)

Model the field, not the pattern. Each blow deposits a stress field; a crack tip
advances perpendicular to maximum tensile stress; a crack **stops** when it meets
an existing crack, leaves the body alpha, or its driving stress falls below
toughness.

Everything in §5 then emerges rather than being authored: radial-then-concentric
morphology, T-junctions, graded density, **anisotropy from the blow direction**
(a slash and a stab differ, and `take_hit(direct)` plus the archetype already
know which), and blow-to-blow interaction.

Cheap in the form that matters: a few dozen Euler steps per crack, on CPU, on
hit. The 90 %-value simplification is to treat existing cracks as **screening** —
each segment reduces driving stress nearby, so a new blow's radials shorten and
bend toward old cracks — which costs one distance-to-nearest-segment query.

**Risk:** it can quietly become a physics project. Bound it to the screened-field
simplification and stop there.

### Option 5 — Griffith budget (a layer, not a rival)

Spend crack **length** proportional to damage rather than adding one site per
hit. A three-damage hit buys three body-relative units of crack; it may spend
them on one long radial or three short ones.

Sits on top of option 2 or 4. Gives well-behaved scaling across the size ladder —
sporeling 115 px to leviathan 1120 px — because the budget is in body-relative
units, where the present one-site-per-hit rule ignores both damage and size.

### Option 6 — Incremental distance field

Rasterise each new crack polyline into a 256² R8 "distance to nearest crack"
image, `min()`-composited into the existing one. The body shader reads it:
`NORMAL_MAP` from its gradient, an alpha band from its value, `EMISSION` in the
trough for `ignite` and `marked`.

- **Immutability is free from the data structure.** `min()`-compositing is
  monotone, so an old crack physically cannot move. 3.2 becomes unrepresentable.
- Coverage is a thin band around real cracks, so `GLASS_AREA` disappears entirely
  rather than being retuned.
- Incremental: cost is in the *new* segments, bounded to their bounding boxes,
  and only on a hit. 64 KB per damaged actor; 256 KB at four actors, against a
  310 MB stage measurement (`docs/actor-stage-frame-budget.md`).
- No per-actor geometry rebuild, no extra draw call, no site list, no
  `MAX_SITES`.
- **Weakness:** no real thickness, so no self-shadowing or parallax in the
  groove. Probably acceptable — `docs/card-angular-budget.md` records that relief
  in this project is measured in degrees, which a normal-mapped groove can carry.

Note this is the benchmark's Panel A mechanism (per-fragment nearest-feature)
applied to *curves* instead of Voronoi sites. Panel A lost to Panel B in three.js
for "flat unlit refraction, no real thickness, fresnel or environment response" —
**and that reason does not hold here**, because a Godot spatial shader on a lit
stage gets Fresnel and real lamps on a perturbed normal for free. Panel A's cost
with Panel B's look.

### Option 7 — Crack ribbons: real geometry

Each crack curve becomes an extruded V-groove in front of the body quad — a strip
of quads with normals rotated outward, width tapering to zero at the tip, merged
into one `SurfaceTool` mesh per actor.

- A crack that ends simply ends. No boundary, no mask, no disc, by construction.
- Real geometry means real Fresnel, real specular, and MSAA on the edge — and
  MSAA 4× was already kept for exactly this reason, that a shard's lit lip breaks
  into a dim broken line at 2× (`docs/actor-stage-frame-budget.md`).
- **A crack can propagate.** Extending the ribbon's tip over ~120 ms is the
  single most convincing thing glass can do, and neither the web version nor the
  present code can do it at all. This is the clearest answer to *what is the
  engine for*.
- Cheap: roughly 30–60 triangles per crack, so ~500 for eight.
- Hands its own polylines to the shatter as cut lines (3.4).

### Recommendation

Superseded by §6, which is the consolidated position. The original recommendation
— morphology 2, stopping rules 4-lite, amount 5, rendering 7 with 6 as fallback,
and the shatter consuming the network in every case — survived review largely
intact, with three corrections (§6.7) and one reclassification: option 3 is not
the low-risk alternative it was tabled as. It is option 4's death half, and
keeping it as the standing-web fallback keeps the wrong half.

The criterion has also moved. Line count is no longer the measure — **elegance
is**, on the owner's ruling of 2026-07-26, together with performance as the first
constraint. §6.1 explains why the line count was never the argument that mattered.

Sequence, if the recommendation is taken: decide §4.1 first (does standing
accumulation exist at all), then 2+4-lite as a CPU-side crack generator behind
the existing `crack()` signature, then 7, then 5, then rewire the shatter.

## 6.9 Council round 2: the design is specified in `docs/fracture-model.md`

A second round refined option 4 into a buildable specification, which now lives in
`docs/fracture-model.md`. This section records only what round 2 *settled*, and
what it got wrong.

**All three seats converged on the field renderer (option 6) over ribbons
(option 7)** — including the architecture seat, which reversed its own round-1
ordering. The arguments that decided it: the field is one concept (distance to the
network) with four consumers, it adds no node and no draw call, propagation
animation is free and incremental rather than merely possible, and — the
architectural point — a ribbon groove is a *silhouette* edge and therefore inherits
the **gated** MSAA 4× dependency, where a normal-mapped groove antialiases itself.
If the memory gate later forces MSAA to 2×, the field renderer survives and the
ribbon does not.

**Accumulation is affordable, and the fix is one structure.** The architecture seat
corrected its own round-1 figure upward by ~27×: a 30-blow fight leaves ≈ 9 600
segments, so blow 30 alone needs ≈ 3.1 M nearest-segment queries — seconds in
GDScript. Replacing the walk with a model-internal 128² quantised distance cache
makes screening O(1) and constant in fight length. So whether standing accumulation
exists is now purely a design question, not a performance one.

**`min()`-compositing makes crack immutability structural in two independent
places** — the screening cache and the render field. Neither can move an old crack.

**Two corrections that had to be made before the round could be used:**

- **The update rule was inverted by one seat.** Its prose was right — radials run
  outward along maximum tensile stress — but its pseudocode took the heading as
  `blow.dir.rotated(PI/2)`, a single direction everywhere, which makes every crack
  run parallel instead of radiating. Radials advance along the **radial** direction
  because they open against hoop tension; the blow direction modulates *magnitude*.
  Corrected in `fracture-model.md` §2.4 and recorded there.
- **"Pre-baked" was conflated with "offline asset".** Two seats described the
  reference as baking one fixed figure per creature at import, and one concluded
  from that a loss of damage-responsive morphology. The reference bakes at
  **runtime, on each `meshCrack()` call, from the sites that exist at that moment**
  — a memoisation of a per-fragment computation, fully impact-responsive. There are
  three tiers, not two, and the middle one is both real calculation and
  pre-calculation. `fracture-model.md` §1 states them.

Three further claims did not survive checking and are not carried: that the shards
are flat quads with no thickness (they are extruded prisms, `GLASS_THICK`); that
screen-reading refraction "works" inside the `SubViewport` (the docblock above
`GLASS_SHADER` records that it reads empty and came out as grey pebbles); and a
"Griffith scale calculation" attributed to the benchmark, which contains no
fracture mechanics at all. The last came from the seat that also produced a
fabricated VRAM figure in round 1 — a pattern, and the reason every magnitude from
that seat was re-derived.

## 7. A blocking precondition: the glass cannot be A/B'd today

Before any option is built or judged, one defect has to go, because every
comparison depends on it.

`EnemyView` owns a single `RandomNumberGenerator` (`enemy_view.gd:200`
(`_rng`)), seeded once when the stage is built from
`hash(String(art_id)) + enemy_idx`. Three unrelated consumers share that one
stream: crack placement (`crack`), the death pattern (`_death_sites`), and the
debris ballistics in `shatter`.

The fourth consumer is the problem. The camera shake in `_process` draws from it
**twice per frame** while `_shake > 0`, and `shatter()` sets `_shake = 1.0` with a
`delta * 4.5` decay — so a rite spends roughly 26 extra draws at 60 Hz and 53 at
120 Hz. `reset_glass()` clears `_sites` but does not reseed.

Consequences, in order of how much they cost:

1. **Re-running the rite gives a different pattern every time, and the divergence
   is frame-rate dependent.** `CONCEPTS.md` › `Lab` states the lab's purpose as
   proving that "a change meant to alter nothing can be proven to have altered
   nothing". For the glass it cannot.
2. **Screenshot comparison on any glass frame is unsound.** A measurement pass
   earlier on 2026-07-26 attributed run-to-run variance in shard frames entirely
   to `CPUParticles3D` embers and the burst flash. That was incomplete: the
   debris ballistics themselves read a stream the shake had already advanced by a
   frame-rate-dependent amount.
3. `hash()` carries no cross-version guarantee in Godot, so any golden-image
   suite built on it is fragile across engine upgrades.

The fix is small and the pieces exist: give fracture its own stream from
`domain/rng/rng.gd` (`class_name Rng`, already pure, with `get_state()`), seed it
from `(art_id, enemy_idx)` with a stable hash rather than `hash()`, and let the
shake keep the throwaway generator. **This should land before any model work**,
as its own change, because it is the precondition for every claim made by
comparing two renders.

## 8. Verification

Numbers in §2.3 are derived from the source, not measured. Before building, the
model is worth one render:

```bash
godot --path . -- --enemies --states
```

and for native-pixel strips at 1:1, `--rite` rather than `--states` — the states
grid renders at 53 % and downscaling is itself an antialiasing pass, so it cannot
be used to judge an edge.

The benchmark's own tuning bench is still runnable, and is the reference for the
approved look:

```bash
npx vite --port 5522
```

in `../roguecardv2-benchmark`, then open `/glass-compare.html` — Panel A and B
side by side, GLASS and BEAMS sliders, and ☠ runs the timing-faithful rite.
