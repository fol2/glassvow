# Glass-crack rendering — the Godot side

Status, 2026-07-26: the **death shatter is shipped and approved**. The **standing
crack web is not** — it reads as a stack of same-radius circles, and the cause is
geometric rather than a tuning miss. This document records what is built, why the
circles are there, and the options on the table. No option has been chosen.

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
(`presentation/combat/enemy_view.gd:1277` (`_voronoi`)):

| | standing crack web | death shatter |
|---|---|---|
| entry | `crack()` (`enemy_view.gd:1382` (`crack`)) | `mark_dead()` (`enemy_view.gd:1441` (`mark_dead`)) |
| sites | `_sites`, appended one per call, cap `MAX_SITES` | `_death_sites()` — graded rings around the burst |
| cells | `_cells()` (`enemy_view.gd:1306` (`_cells`)) — **`reach` > 0** | `_death_cells()` (`enemy_view.gd:1494` (`_death_cells`)) — **`reach` = 0** |
| body mask | none | `_touches_art()` (`enemy_view.gd:1506` (`_touches_art`)) |
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
every cell against `_disc(sites[i], reach)` (`enemy_view.gd:1264` (`_disc`)) — a
20-gon of **constant radius**. The arc is not an artefact of shading or of
sampling. It is drawn.

**2.2 The arc wears the brightest treatment in the effect.** `_prism()`
(`enemy_view.gd:1321` (`_prism`)) extrudes *every* edge of the cell into a side
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
(`enemy_view.gd:1357` (`_rebuild_glass`)) returns early below two sites, so the
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

This is a **causal** break rather than a cosmetic one — the cracks scored into a
creature have no bearing on how it comes apart — and it is independent of every
other item here. Whichever option below is chosen, the shatter should consume the
crack network rather than invent a second one.

**3.5 Sites do not cluster at the blow.** `crack()` with no argument picks
uniformly from UV 0.2–0.8, so crack position is unrelated to where the hit landed
or how hard. Real impact fragments finely at the strike and coarsely outward —
and `_death_sites()` (`enemy_view.gd:1471` (`_death_sites`)) *already does this*,
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
accumulating toward `MAX_SITES` (`enemy_view.gd:64` (`MAX_SITES`)) = 32. So the
port runs a disabled experiment, for a whole fight instead of a fifth of a
second.

**Therefore the first question is not visual.** Should standing accumulation
exist at all, or do cracks belong only to the death rite as the benchmark ships
it? Keeping accumulation means going ahead of the reference and owning the
design. That is allowed, but it should be a decision rather than a leftover.

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

## 6. On the table

Numbering follows the session discussion. **Option 1 (port the feather) is
rejected** — see 4.3.

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

**Morphology 2, stopping rules 4-lite, amount 5, rendering 7 with 6 as the
fallback, and the shatter consuming the crack network in every case.** That
combination removes the disc rather than hiding it, produces T-junctions,
prevents old cracks from moving, ties crack quantity to damage, and buys crack
growth — with the shatter finally breaking the body along the cracks it was
carrying.

**Option 3 stays on the table as the low-risk alternative.** It fixes 3.1 through
3.5 with the machinery already in the file and no new rendering path. What it
cannot do is propagate, and its cuts read as cuts.

Sequence, if the recommendation is taken: decide §4.1 first (does standing
accumulation exist at all), then 2+4-lite as a CPU-side crack generator behind
the existing `crack()` signature, then 7, then 5, then rewire the shatter.

## 7. Verification

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
