# Act III kits — prompt direction

Status: **direction for wave-1 ordinary kits only**. This file does not generate
images or meshes. Concepts land later under `assets/art/map-concepts/`; shipping
GLBs land later at the dests below.

Act: **III — 黑曜王庭 / The Obsidian Court** (`act_key=act3`, manifest `act: 2`).
Bill IDs A3-1…A3-5 in `docs/map-scene-asset-bill.md`. Hero terminus
`act3-terminus` / `geometry/act3/terminus-broken-ring-arch.glb` is already
signed (#294) and is **not** a slot in this wave.

Disk survey (this tree, 2026-08-25):

| Path | Present? |
|---|---|
| `assets/art/map/geometry/act3/` | only the signed hero `terminus-broken-ring-arch.glb` |
| `assets/art/map-concepts/act3-*.jpg/.png` kit concepts | **none** |
| five dest GLBs listed below | **none** — first generate, not a reshape |

Shared road slabs and the standing monument already occupy the other three of
the eight kit seats. Act III kits fill seats 3–7 at the existing `KIT_SCALE`
row in `presentation/map/map_scene.gd` (`6.2`, `2.8`, `2.2`, `4.6`, `3.2`).

## Wave-1 slots

| asset_id | bill | dest | role | world scale seat | silhouette job |
|---|---|---|---|---|---|
| `act3-obsidian-blade` | A3-1 | `assets/art/map/geometry/act3/obsidian-blade.glb` | ordinary | 6.2 | large faceted obsidian wedge, blade-leaning mass with a broad grounded heel, one connected volume, **not a tower** |
| `act3-broken-halo` | A3-2 | `assets/art/map/geometry/act3/broken-halo.glb` | ordinary | 2.8 | thick grounded broken halo, C-shaped incomplete ring with a missing-shard gap, one connected volume, **not a doorway arch** |
| `act3-court-plinth` | A3-3 | `assets/art/map/geometry/act3/court-plinth.glb` | ordinary | 2.2 | Sovereign-court stacked slab dais, two or three fused terraces as one low rectangular mass, **no separate steps** |
| `act3-shattered-wall-mass` | A3-4 | `assets/art/map/geometry/act3/shattered-wall-mass.glb` | ordinary | 4.6 | broad ruined court wall mass, one connected shattered masonry block wider than tall with a coarse bite, **no window lace** |
| `act3-star-eye-mass` | A3-5 | `assets/art/map/geometry/act3/star-eye-mass.glb` | ordinary | 3.2 | coarse star-and-watching-eye as one fused stellate blob, low squat court mass with a blunt lens bulge, **no tassels or pointing hands** |

Concept files (when authored) live outside `assets/art/map/` so
`tools/check_map_assets.py` does not treat them as undeclared payload:

```text
assets/art/map-concepts/act3-obsidian-blade.png
assets/art/map-concepts/act3-broken-halo.png
assets/art/map-concepts/act3-court-plinth.png
assets/art/map-concepts/act3-shattered-wall-mass.png
assets/art/map-concepts/act3-star-eye-mass.png
```

PNG, square, textured language (see §4). Do not reuse the Act I `.jpg`
clay-maquette files as seeds.

---

## 1. Visual language

The court is the east stretch, **in front of the door**, not a spire and not a
climb (`docs/story/03-acts.md`, `docs/story/06-glossary.md`). Courtiers are
people who walked this far, were not recognised by the door, and sat. A thousand
years of that sitting turned glass dark: **obsidian = glass that no longer
lets will through** (`docs/story/01-world.md` fire-physics; `00-truth.md` §8.6).
The map is L0. It may look like a dark ruined court. It may not explain why.

Motif pool for these five masses, and only these, from the act entry:

- **obsidian** — faceted, almost-black, matte-to-satin glass-stone. Light dies
  on the way through; the surface can take a dull violet sheen, never a
  transparent pane, never a gold glow that reads as a lit lantern.
- **broken ring / broken halo** — an incomplete circle as architecture. The
  wound is a missing chunk of the same volume. Grounded. Thick.
- **star and watching-eye** — one fused stellate blob with a blunt lens bulge,
  not a creature, not a face, not a cult prop.
- **court masonry** — stacked, shattered, or terraced stone of the same
  obsidian family. Courses may be visible as *facet planes*, not as grout
  lines, window tracery, or brick lace.

Combat plates (`assets/art/stage/act3-backdrop.png`, `act3-mid.png`,
`act3-ledge.png`) and the signed grade (`map/grades/act3-grade.png`) are the
hue and grain reference: violet storm, magenta seam in faceted black, low
polygonal ground. They are **not** a kit catalogue.

Do not port into a kit:

- the backdrop's **tall faceted spires** (that is the retired climb/spire
  read; the blade's job is "not a tower");
- the mid plate's **gothic stained-glass windows and rose lace** (combat
  staging; the wall kit bans window lace);
- the mid plate's **floating broken ring with a hanging crystal** (owned by
  combat *and* by the signed hero terminus);
- meteor streaks, lightning bolts, sky, horizon, or a landscape.

Ramp dress for this act (`presentation/map/map_regions.gd` row 2): sky
`#120a1e`, fog `#1e1230`, particles `#c27bff`, accent `#c99aff`, weather
`storm`. Grade arc near 0.78 / far 0.70 / corridor 0.62. Concepts may carry a
cold violet-black albedo because HD will bake it; keep it **low-contrast
matte**. Hue on the road still belongs to the grade. Do not paint a second
storm sky onto the prop.

Shared-kit contrast: road slabs stay the path; the standing monument stays the
fallen-walker stele. Act III kits must not rhyme with either — no paving
block, no person-height upright with a shoulder bite.

Act I contrast: no ash, roots, trunks, stumps, cairns, or wood.
Act II contrast: no silt, water, rust, drowned arches, shelves, or lantern
posts.
Act IV contrast: no mirrored road, standing *pair*, inverted hearth-light, or
rose-threshold wheel.

Chunky, planar, low-poly-friendly game-kitbash masses. One object per file.
Readable as a black silhouette if every internal facet were removed.

---

## 2. Foreshadow bans

The pilgrimage map is on screen from run 1. Ledger rule 2 (`docs/story/05-foreshadow-ledger.md`):
a sentence — or a picture — that discloses before its tier is rewritten or
deferred. The Vigil concept is the model (`docs/art-ledger.md` map-concepts
vigil row): the west face of the hall *has* a six-pane window in the fiction,
and the prompt still bans rose, wheel, and circular windows, because six panes
*are* the shard count (L3, the single reveal). Row 10 of the ledger is the
other model: `mirror.png` ships as L0 art with its meaning withheld.

**Do not put any of the following in a concept or a mesh:**

| Ban | Why |
|---|---|
| Rose Window, six panes, six countable shards, wheel/circular windows, stained-glass tracery, window lace | L3; Vigil already banned this. Wall kit restates "no window lace". |
| A shard-shaped socket / keyhole in the halo gap that looks like "insert emberglass here" | Turns the L0 ruin into a lock diagram. Gap = missing chunk of the same ring, not a fitted vacancy. |
| Complete / closed gold halo | The court motif is the *break*. A closed ring is the un-happened wound (Act IV node-2 mirror), not this stretch. |
| Floating sky-ring, hanging crystal under a break, two pylons spanning a ring-arch | Already the signed hero `terminus-broken-ring-arch.glb` and the combat mid plate. Kits do not clone the terminus. |
| Sealed door, lock, keyhole, "door pretending to be dawn" | East of this act; not kit furniture. |
| Spire, tower, climb, summit, stair-as-the-road, vertical pilgrimage | Glossary banned. Blade job is "not a tower". Old shipped name "Obsidian Spire" is retired. |
| Seated king, wearable crown, scepter, Sovereign portrait, throne-with-a-sitter | The court is a place of sitting-down, not a portrait of the boss. "Beyond the crown" is a copy formula (ledger row 31), not a prop. |
| Queue of standing monuments as a road; mirrored pair; inverted hearth-light; Gilded City / gold cloud-city | Act IV. |
| Pale Ones, pointing hands, severed arms, tassels, cult spears, masks | Combat `watcherEye` / `starCultist`. Star-eye kit restates "no tassels or pointing hands". |
| Ash, spores, roots, water, rust, silt, lure-lanterns, cages, chains, kelp | Wrong act's material. Waystone w58: this stretch has no ash and no water. |
| Lit Vigil hall, chimney, hearth fire, rose-as-mirror | West bookend, already authored. |
| Faces, figures, hands, readable glyphs, numbers, the count "six", the roman "III" | Not a kitbash mass. |
| Neon / emissive gold halo, flame, will-light pouring out of a crack | States the fire-physics equation on an L0 map. Dull obsidian, dead light. A faint violet facet sheen is the ceiling. |
| Transparent glass, stained panes you can see through | Obsidian does not transmit. Waystone w47. |

Allowed L0 surface read: dark ruined court; faceted black glass-stone; an
incomplete ring lying as architecture; a low dais; a bitten wall; a squat
stellate blob. After-reveal (not for the picture): the whole act's broken-ring
art is the museum of light lost at the moment of giving up (`03-acts.md`).

---

## 3. Converter framing

Framing is for **Tripo HD reconstruction**, not for a pretty illustration.
Tripo builds what it can see. A horizon, a ground plane, or a contact shadow
comes back as geometry (Vigil concept note, `docs/art-ledger.md`).

Every concept, all five IDs:

- **square 1:1**
- **whole object in frame**, even margin, nothing cropped
- **centred**, isolated, large in frame
- **flat mid-grey background** (neutral `#8A8A8A`), **ground-free**
- **no horizon**, no environment, no sky, no storm clouds, no landscape
- **no cast shadow** on a ground, no baked AO puddle, no contact darkening
  that could mesh as a floor island
- three-quarter view from **35–40° above** (same camera band as the Vigil
  concept; production map tilt is −55° and will re-photograph later)
- no depth of field, no fog, no rim light, no character, no scale figure
- not a tile texture, not a top-down, not an orthographic elevation sheet

If a first picture grows a floor disc, a second halo, or a backdrop ridge:
edit the picture, do not "fix it in Studio".

---

## 4. TEXTURED concept language — not clay-maquette

Act I / shared kit concepts were **matte untextured clay-maquette** for Smart
Mesh, which has no texture stage. This wave is **not that**. HD Model bakes
**albedo from the picture** (`docs/solutions/tooling-decisions/the-textured-studio-path-is-the-hd-tab-not-the-script.md`).
A grey clay lump becomes a grey clay GLB with a 1k map of grey clay.

Write and generate like the Vigil concept, not like `shared-road-slab-a.jpg`:

- name the material: **faceted obsidian**, **coursed court ashlar fused into
  obsidian**, **dull violet-black glass-stone**
- name the illumination: **cold violet-black low-contrast matte**, even
  above-front studio light, no key-and-fill drama, no specular chrome
- name the grain HD should bake: broad planar facets, faint magenta-violet
  seam in the dark, weathered coursed faces on the plinth and wall **as
  albedo**, not as carved micro-displacement
- keep it game-asset planar: large facets, few of them, readable at map zoom
- **PBR stays off** in Studio; do not paint a roughness/metal story the
  shader will not sample

Banned concept words for this wave: `clay-maquette`, `untextured clay`,
`grey clay`, `matte untextured stone surface` as the whole material brief,
`keep the exact same clay-maquette look`. Those prompts exist to starve Smart
Mesh of albedo. Feeding them to HD is the wrong starve.

Do not over-texture either: no brick-by-brick grout, no crack *lines*, no
normal-mapped pores, no gold leaf, no glowing runes. Albedo is a quiet
obsidian court, not a trim sheet.

---

## 5. Studio conversion

Generating product is **Tripo Studio** (`studio.tripo3d.ai`), paid Pro credits.
**Never the API.** Forbidden hosts: `openapi.tripo3d.ai`, `platform.tripo3d.ai`
generation, any `/v2/openapi` or `/v3/generation`. A Studio subscription does
not pay the API.

Driver: `bun tools/studio_image_to_glb.ts --textured --privacy private`.
`--textured` stays on the **HD Model** tab and bakes albedo. Do not click
**Generate Multi-Views** (it appears after upload). Do not click away onto
Smart Mesh. `--ai-complete` stays off (invents unseen backsides). `--pbr off`
(map shaders sample one map; metallic/roughness/normal would sit inside the
byte cap for nothing on screen).

Credit order, do not skip:

```bash
# 1. dry-run — no Chrome, no credits
bun tools/studio_image_to_glb.ts --dry-run --textured --privacy private \
  --faces 1500 --topology triangle --texture-quality 1k --pbr off \
  --image assets/art/map-concepts/act3-obsidian-blade.png \
  --out /tmp/glassvow-studio-act3-obsidian-blade.glb

# 2. smoke-run — Chrome + login + form. Generate is not clicked.
bun tools/studio_image_to_glb.ts --smoke-run --textured --privacy private \
  --faces 1500 --topology triangle --texture-quality 1k --pbr off \
  --image assets/art/map-concepts/act3-obsidian-blade.png \
  --out /tmp/glassvow-studio-act3-obsidian-blade.glb

# 3. generate — spends the quoted HD credits
bun tools/studio_image_to_glb.ts --textured --privacy private \
  --faces 1500 --topology triangle --texture-quality 1k --pbr off \
  --image assets/art/map-concepts/act3-obsidian-blade.png \
  --out /tmp/glassvow-studio-act3-obsidian-blade.glb
```

Replace the image and `--out` per `asset_id`. Same flags for all five ordinary
rows.

| Role | Flag profile | Caps |
|---|---|---|
| **Ordinary** (this wave) | `--textured --privacy private --faces 1500 --topology triangle --texture-quality 1k --pbr off` | **192 KiB** (`bytes_max` 196608); accepted **600–2500** triangles |
| **Hero / threshold** (not this wave; Vigil / termini) | `--textured --privacy private --faces 6000 --topology triangle --texture-quality 2k --pbr off` | **768 KiB** (`bytes_max` 786432); hard **8000** triangles |

`--texture-quality 4k` blows those caps. `--faces` is the Studio slider, not
the shipping triangle count. Export format **GLB**. Privacy **Private** (HD
default is Sharing Only; the driver must mouse-click Private).

Do not generate on this pass. This file is direction only.

---

## 6. Mesh contract

- **One connected volume.** The sole exception in the whole map library is the
  Vigil: hall + chimney smoke (`components_max: 2` on the `threshold` row).
  These five kits are `kind: kit` and may not declare `components_max`.
- **Y-up, metres, pivot on ground contact, min Y = 0.0** as exported.
- One mesh, one triangulated surface. No animation, skeleton, or extra
  islands. No floor disc. No hidden internal shells.
- Ordinary: 600–2500 triangles, GLB ≤ 192 KiB. Hero/threshold (documented,
  not this wave): ≤ 8000 triangles, ≤ 768 KiB.
- Closed or deliberately open *broad* forms only. A C-shaped halo is one
  horseshoe solid, not a tube with a hole and a separate shard.
- Ground the heel. Floating jewellery fails the map: kits scatter on Y=0
  and the camera is tilted.

If Studio returns two shells, fuse the *concept* (concave bite, not a
detached chip) and regenerate. Do not boolean the signed terminus into a kit.

---

## 7. Per-id prompt skeletons

Preamble is shared. Subject paragraphs differ. Paste as one block.

**Shared preamble (every ID):**

> Square 1:1 game-kitbash 3D prop concept, entire object centred with even
> margin, three-quarter view from 35–40° above. Isolated subject, large in
> frame. Flat neutral mid-grey background (#8A8A8A), ground-free, no horizon,
> no environment, no cast shadow, no baked AO puddle, no depth of field.
> Cold violet-black low-contrast matte illumination from above-front; no rim
> light, no chrome spec, no emissive glow. Faceted obsidian court-stone:
> almost-black glass that does not transmit light, broad planar facets, a
> faint dull magenta-violet sheen in the seams only. Clean planar
> low-poly-friendly game-asset concept. One connected volume sitting on an
> implied ground, no floor disc. No characters, hands, faces, text, glyphs,
> windows, rose lace, lanterns, water, ash, roots, or sky.

### `act3-obsidian-blade`

- dest: `assets/art/map/geometry/act3/obsidian-blade.glb`
- concept: `assets/art/map-concepts/act3-obsidian-blade.png`
- scale seat **6.2** (largest act kit; the Act I fork sits here — height is
  cheap, *tower* is not)

**Subject:**

> A single large faceted obsidian wedge: a blade-leaning mass, one thick
> triangular shard-block with a broad grounded heel and a leaning crest, the
> whole thing one connected volume. Wider heel than crest. Low centre of
> mass. Chunky geometric facets, not a honed sword, no hilt, no guard, no
> tang, no standing obelisk, no spire, no tower, no needle. Not a monument
> stele. Not a roof finial. The lean is a wedge lying into the ground, not a
> vertical climb.

**Reshape notes:** dest is absent. First generate. If the picture or the GLB
reads as a tower, an obelisk, a weapon, or the backdrop's peak cluster, push
the heel wider and the crest shorter in the concept; do not steal height from
the signed ring-arch.

### `act3-broken-halo`

- dest: `assets/art/map/geometry/act3/broken-halo.glb`
- concept: `assets/art/map-concepts/act3-broken-halo.png`
- scale seat **2.8** (small; must not impersonate the hero)

**Subject:**

> A single thick grounded broken halo: one C-shaped incomplete ring, a
> horseshoe of faceted obsidian, both cut ends of the C planted on the
> ground, a missing-shard gap in the ring itself. One connected volume.
> Thick torus-section, not a wire, not a thin hoop. The gap is a coarse bite
> out of the same ring, not a doorway, not an architectural arch, not a lock
> socket, not a shard-shaped keyhole. No flanking pylons, no plinth-bar, no
> hanging crystal in the gap, no second ring, no floating jewellery. Not the
> monumental ring-arch terminus. Squat, grounded, court debris.

**Reshape notes:** dest is absent. The signed hero
`terminus-broken-ring-arch.glb` is a ring-arch on a rectangular plinth with
two pylons and a suspended shard — **do not reshape that file into this
kit**, and do not author this kit as a miniature of it. If HD emits a
doorway arch or a floor slab, thicken the C, plant both ends, delete pylons
in the concept.

### `act3-court-plinth`

- dest: `assets/art/map/geometry/act3/court-plinth.glb`
- concept: `assets/art/map-concepts/act3-court-plinth.png`
- scale seat **2.2** (lowest act kit; the Act I stump sits here)

**Subject:**

> A single Sovereign-court stacked-slab dais: two or three fused terraces as
> one low rectangular mass, wider than tall, sitting on the ground. One
> connected volume. Terraces are the same obsidian, melted together — no
> separate steps, no stair flight, no gaps between slabs, no tiny risers HD
> will split into islands. No throne, no chair, no seated figure, no
> cushion, no crown on top. Not a road paving slab (those are shared kit).
> Not a tall podium. Blunt rectangular silhouette, a short ziggurat fused
> into one block.

**Reshape notes:** dest is absent. If the picture grows a staircase or three
loose slabs, fuse them in the concept until the silhouette is one low
rectangle with two terrace *shoulders*, not a climb.

### `act3-shattered-wall-mass`

- dest: `assets/art/map/geometry/act3/shattered-wall-mass.glb`
- concept: `assets/art/map-concepts/act3-shattered-wall-mass.png`
- scale seat **4.6** (wide; the Act I fallen-bough arch sits here)

**Subject:**

> A single broad ruined court wall mass: one connected shattered masonry
> block, wider than it is tall, a coarse bite taken from the top or a
> corner, still one volume. Faceted obsidian-ashlar, big planar faces, no
> window, no window lace, no tracery, no rose, no arrow-slit, no colonette.
> No fallen bricks as extra pieces, no separate rubble pile, no through-arch.
> Not a complete curtain wall. Not a doorway. A bitten block of court, like
> a thick broken rampart chunk sitting on the ground.

**Reshape notes:** dest is absent. Combat `act3-mid.png` is full of gothic
windows — that is the trap. If lace or a pointed opening appears, fill it in
the concept until the bite is a concave masonry wound, not a window.

### `act3-star-eye-mass`

- dest: `assets/art/map/geometry/act3/star-eye-mass.glb`
- concept: `assets/art/map-concepts/act3-star-eye-mass.png`
- scale seat **3.2** (cairn-sized; squat)

**Subject:**

> A single coarse star-and-watching-eye as one fused stellate blob: a low
> squat court mass, wider than tall, with blunt star-points melted into the
> same volume and one blunt lens bulge on the near face. One connected
> volume. Architectural, not a creature. No iris, no pupil, no eyelashes, no
> lids, no face, no tassels, no pointing hands, no arms, no spear, no
> shield, no cultist. Not a Christmas star on a stick. Not a cairn of loose
> stones. Eight-ish coarse points at most, rounded, fused. The lens is a
> convex obsidian dome continuous with the blob, not a glass pane and not a
> hanging ornament.

**Reshape notes:** dest is absent. If HD grows hands, tassels, or a second
blob for the eye, fuse the lens into the body in the concept and blunt the
points until it still reads as a squat star from −55° but never as a figure.

---

## 8. Twenty-placement failure modes

Scalar gate and human review are different instruments
(`docs/solutions/tooling-decisions/a-signable-20-placement-review-is-a-lit-clay-grid.md`).
Masks: eight yaws at 45°, `MapCameraRig.TILT_DEGREES` −55°, widest zoom 28,
`silhouette_noise` ≤ 0.04. Review: lit 5×4 clay grid, 1280×720, seed-292 yaw
and scale. A noise pass does not close the visual clause.

A **one-module** pass looks like Act I's cairn grid: the same item, different
size and angle. A **map-level** pass needs five distinct Act III contours plus
the three shared kits, 24–32 instances, each ordinary module used 2–5 times.
This wave must not ship a set that, once seated together, reads as twenty
wedges.

Fail the concept (before Studio) or the GLB (before land) if any of these
show up in a 20-placement or in a mixed-kit mock:

1. **Tower field** — `obsidian-blade` at scale 6.2 reads as a spire forest;
   twenty copies become the retired climb skyline.
2. **Weapon rack** — the blade reads as a sword / hilted weapon under yaw;
   a pilgrimage map is not an armoury.
3. **Doorway colonnade** — `broken-halo` yaws into a pointed arch; twenty
   copies become a cloister. Job is "not a doorway arch".
4. **Mini-terminus army** — the halo clones `terminus-broken-ring-arch`
   (pylons + hanging shard + plinth-bar). Hero identity leaks into scatter.
5. **Closed-ring coins** — the gap closes under some yaws; twenty full circles
   are a different motif (and a foreshadow miss).
6. **Wire hoops** — thin halo tubes silhouette-noise above 0.04, or split
   into two islands.
7. **Stair farm** — `court-plinth` keeps separate steps; yaw turns them into
   a climb, which is banned vocabulary *and* a second-island risk.
8. **Paving collision** — the plinth rhymes with `shared-road-slab-a/b`;
   the road disappears into dais clutter.
9. **Window street** — `shattered-wall-mass` keeps lace or a pointed opening;
   twenty copies become the combat mid plate, and L3 glass is on the map.
10. **Brick scatter** — the wall sheds rubble islands; component count > 1.
11. **Watcher choir** — `star-eye-mass` grows a face, iris, hands, or tassels;
    twenty copies stare. Job is "no tassels or pointing hands".
12. **Cairn collision** — the star-blob rhymes with Act I `ash-cairn-mass`
    (same 3.2 seat): a mound with no stellate read.
13. **Monument collision** — any kit rhymes with `shared-standing-monument`
    (upright stele, shoulder bite).
14. **Wedge monopoly** — blade, wall, and star all read as the same faceted
    triangular lump at −55° / zoom 20; five IDs, one contour.
15. **Floor islands** — horizon or cast shadow in the concept meshed as a
    disc; twenty copies tile a second ground.
16. **Floating jewellery** — halo or star-eye not planted at Y=0; scatter
    hangs above the road.
17. **Two-shell Vigil mistake** — a kit ships hall+smoke logic (detached
    chip, detached lens, detached shard). Only the Vigil may be two
    components.
18. **Albedo shout** — HD-baked gold glow / stained glass / storm sky on the
    1k map; twenty copies flicker against the grade and leak L3 colour.
19. **Unreadable white scatter** — review PNG is unshaded blobs, or a
    composition dump like the terminus `twenty-placements.png` pile, not a
    lit 5×4 grid a human can sign.
20. **Same-item failure of the wrong kind** — twenty copies look like
    *twenty different objects* (identity lost) *or* the mixed act kit looks
    like *one object used twenty times* (repetition). One module must hold
    identity; five modules must not collapse to one.

Land path after a signed grid is `tools/land_map_glb.py` with
`--accept-signed-capture` and reviewer `fol2`. Existence of a PNG is not a
Gate. This file does not land, generate, or capture.

---

## Out of scope

- No image generation, no `image_gen` / `image_edit`, no Studio Generate.
- No GLB write under `assets/art/map/geometry/act3/` except the already-signed
  hero, which this wave does not touch.
- No new citations into the detached web reference.
- No `domain/` edits.
- Act III tiles (`act3-ground-obsidian-dust`, `act3-prop-obsidian-facet`) and
  the painted grade are a different bill slice; do not bake a second tile
  into these concepts.
