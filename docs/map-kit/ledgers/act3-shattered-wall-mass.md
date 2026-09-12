# act3-shattered-wall-mass — conversion concept

Wave-1 ordinary kit for Act III (黑曜王庭 / The Obsidian Court). Direction:
`docs/map-kit/act3-prompt-direction.md` §7 `act3-shattered-wall-mass`. Bill A3-4
in `docs/map-scene-asset-bill.md`.

| Field | Value |
|---|---|
| `asset_id` | `act3-shattered-wall-mass` |
| `billed_id` | `act3-shattered-wall-mass` (bill A3-4) |
| `act_key` | `act3` |
| role | ordinary |
| dest | `assets/art/map/geometry/act3/shattered-wall-mass.glb` |
| dest_on_disk | no |
| concept | `assets/art/map-concepts/act3-shattered-wall-mass.jpg` |
| world scale seat | 4.6 |
| reshape-vs-new | **new** — dest was absent; first generate, not a reshape of an old mesh |
| silhouette job | broad ruined court wall mass, one connected shattered masonry block wider than tall with a coarse bite, no window lace |
| attempts | 3 |
| last_self_review | **fail** |
| sha256 (landed attempt 3) | `02134d2575f9c5c48cf0f80d88bc070eaac1c05097fb8eefa03671f29a9b19f3` |
| pixels | 1024×1024 RGB JPEG |

The wave direction names the concept `.png`. This slot saved `.jpg` as the
conversion-concept task required. Square 1024×1024 RGB JPEG.

Do not append `docs/art-ledger.md`. No GLB was generated on this pass.

L3 risk: yes (window lace / rose / six panes). Combat `act3-mid.png` is full of
gothic stained-glass windows; that is the trap. Checked
`docs/story/05-foreshadow-ledger.md` rule 2: kits are L0 scenery; six panes are
the shard count (L3). None of the three pictures show a rose, wheel, circular
window, stained tracery, or countable panes.

---


**GLB landed 2026-08-25** as Studio HD textured (`--textured`, ordinary 1500/1K/Ultra off). Dest is on disk. 20-placement: `docs/reviews/292/act3-shattered-wall-mass-20.png`. This ledger’s “no GLB / do not append art-ledger” lines are historical.
## Prompt (attempt 1, `image_gen`, aspect 1:1)

> Square 1:1 game-kitbash 3D prop concept, entire object centred with even margin, three-quarter view from 35–40 degrees above. Isolated subject, large in frame. Flat even neutral mid-grey background #8A8A8A, ground-free void, no horizon, no environment, no sky, no storm, no landscape, no floor plane, no checkerboard, no ground disc, no cast shadow, no contact shadow, no baked AO puddle under the object, no depth of field, no fog, no rim light, no character, no scale figure.
>
> Subject: a single broad ruined court wall mass. One connected shattered masonry block, clearly wider than it is tall, like a thick broken rampart chunk sitting on implied ground. Substantial thickness, a squat rectangular volume, not a thin wall plane, not a complete curtain wall, not a building, not a tower, not a doorway, not an arch.
>
> A coarse bite taken from the upper-right corner of the same volume: a concave masonry wound, a missing chunk of the block itself, jagged faceted notch in the top corner. The bite does NOT go through as a hole, does NOT reach the ground, is NOT a window, is NOT a pointed gothic opening, is NOT a doorway, is NOT an arch, is NOT a keyhole. No see-through gap. Still one solid connected volume. No fallen bricks, no separate rubble pile, no chips floating beside it.
>
> Material: faceted obsidian-ashlar court-stone, almost-black dull glass-stone that does not transmit light. Big planar facet faces, few of them, low-poly-friendly. Weathered coursed faces as quiet albedo planes, NOT brick-by-brick grout lines, NOT crack line drawings, NOT pores, NOT gold leaf, NOT runes, NOT glyphs, NOT numbers. Faint dull magenta-violet sheen only in the facet seams. Cold violet-black low-contrast matte illumination from above-front studio light. No chrome spec, no emissive glow, no neon, no flame, no will-light leaking from cracks, no transparent glass, no stained-glass panes.
>
> Hard bans: ZERO windows, ZERO window lace, ZERO tracery, ZERO rose, ZERO circular windows, ZERO six panes, ZERO arrow-slits, ZERO colonettes, ZERO pointed gothic openings, ZERO stained glass, ZERO doors, ZERO locks, ZERO keyholes, ZERO hanging crystals, ZERO rings, ZERO crowns, ZERO thrones, ZERO figures, ZERO hands, ZERO faces, ZERO text. Not clay-maquette, not grey clay, not untextured clay. Textured obsidian court stone albedo. Clean planar game-asset concept. One object only.

## Prompt (attempt 2, `image_edit` of attempt 1)

> Keep the same isolated 3D prop on a flat even mid-grey #8A8A8A void. Keep square 1:1, three-quarter view from 35–40 degrees above, whole object centred with even margin, no floor, no horizon, no cast shadow, no contact AO puddle, no environment.
>
> Change the subject into ONE fused connected volume, not stacked separate bricks. Melt the grout joints away. Courses may remain only as large planar facet planes on the same obsidian mass, not as brick-by-brick blocks that could split. Make the silhouette clearly wider than tall: a thick broken rampart chunk, a broad ruined court wall mass, low and wide, substantial thickness.
>
> The coarse bite must be a missing upper-right corner of the same block: a concave jagged masonry wound in the silhouette, a chunk taken from the top corner, still solid. Fill any through-hole, crater-cavity, window, or see-through gap. The bite is NOT a window, NOT a pointed gothic opening, NOT an arch, NOT a doorway, NOT a keyhole. No lace, no tracery, no rose, no panes, no colonettes.
>
> Material: faceted obsidian-ashlar, almost-black dull glass-stone, broad planar faces, faint dull magenta-violet sheen only in seams. Cold violet-black low-contrast matte studio light from above-front. No glow, no neon, no transparent glass, no stained glass, no gold, no runes, no rubble islands, no fallen bricks beside it. One object only.

## Prompt (attempt 3, `image_edit` of attempt 2) — landed, did not pass

> Aggressive reshape of this same isolated 3D prop. Keep square 1:1, centred with even margin, three-quarter camera from 35–40 degrees above, flat even mid-grey #8A8A8A void, no floor, no horizon, no cast shadow, no AO puddle, no environment.
>
> FUSE EVERYTHING into one single monolithic connected volume. Completely erase grout joints, brick courses, and stacked-block seams. It must no longer look like separate bricks. One thick shattered masonry block only.
>
> Stretch the silhouette so it is obviously WIDER THAN TALL, about two times as wide as it is high: a broad ruined court wall mass, a thick broken rampart chunk, low and wide, sitting as one heel on implied ground.
>
> The coarse bite is a large missing upper-right CORNER of that one block: a stepped concave silhouette wound, as if a big chunk was bitten off the top corner. Solid faceted interior of the same obsidian, no hole through, no cavity to the background, no window, no pointed opening, no arch, no door. Coarsen the shattered area into a few large planar facets, not a pile of small rubble crystals.
>
> Material: faceted obsidian-ashlar court-stone, almost-black dull glass-stone, broad planar faces, faint magenta-violet sheen only along a few facet edges. Cold violet-black low-contrast matte above-front light. No glow, no stained glass, no lace, no tracery, no rose, no panes, no glyphs, no figures, no extra rubble pieces. One object.

---

## Attempts

Blind descriptions were written from `read_file` of the generated image
**before** scoring the spec.

### 1 — fail

- tool: `image_gen`, aspect 1:1
- sha256 `05bc319431e6bea8d47d5c1b8de6771f4bfe66350cc007dfb9b3ee2cd763fd6f`
- 1024×1024 RGB JPEG, 130682 bytes

**Blind:** Isolated three-quarter mass on a flat mid-grey void, no floor or
cast shadow. A dark violet-black stacked ashlar block, roughly as wide as
tall, three grouted courses. Coarse shattered crater in the upper-right with
a deep dark cavity. No figures, text, rose, or gothic lace.

**Spec:** Framing holds. Textured obsidian-ashlar, not clay. Foreshadow (no
window lace / six panes / rose) holds. Silhouette fails: brick-by-brick grout
(HD split / brick-scatter risk); cube not a broad rampart; bite is a crater
that may read as a hole, not a missing-corner masonry wound.

### 2 — fail

- tool: `image_edit` of attempt 1
- sha256 `d7b12f3d055e64d3c6b671c595fe44d04fdb087eea24141c6ebb8976cefd1394`
- 1024×1024 RGB JPEG, 111603 bytes

**Blind:** Same grey-void framing. Near-black stacked three-course ashlar with
grout still readable. Upper-right shattered crater now filled with faceted
stone rather than a through-hole. Still cube-like, not a wide rampart. No
windows, figures, or lace.

**Spec:** Through-hole filled (good). Grout and cube proportions still fail
the fused wide-mass job. Bite remains a scooped crater.

### 3 — fail (landed)

- tool: `image_edit` of attempt 2
- path `assets/art/map-concepts/act3-shattered-wall-mass.jpg`
- 1024×1024 RGB JPEG, 97272 bytes
- sha256 `02134d2575f9c5c48cf0f80d88bc070eaac1c05097fb8eefa03671f29a9b19f3`

**Blind:** Square mid-grey void, no floor, no horizon, no cast shadow,
three-quarter from above. One fused almost-black mass — grout gone. Large
shattered bite in the upper-right with many small magenta-violet crystal
facets, shinier than the matte body. A dark arched hollow / undercut at the
bottom-left of the near face, grey showing in the notch. Bounding box still
about as wide as tall. No windows, lace, rose, figures, text, or sky.

**Spec (after re-read):**

| Gate | Result |
|---|---|
| silhouette job | **fail** — fused one volume and a coarse upper-right bite, and no window lace, but the mass is still a cube not a broad rampart (wider-than-tall is weak); heel undercut reads as a small arched doorway; bite is a geode of many small shards, not a few planar masonry facets |
| framing | **pass** — 1:1, whole object, centred, #8A8A8A void, ground-free, no horizon, no cast-shadow puddle, ~35–40° three-quarter |
| textured surface | **pass with nit** — faceted obsidian albedo, not clay-maquette; bite sheen is louder than “faint dull magenta-violet in the seams only” (albedo-shout risk) |
| foreshadow bans | **pass** on L3 glass (no rose / six / wheel / lace / stained pane). Heel notch is not a sealed-door diagram, but it is still a doorway-shaped opening the subject paragraph forbids |

Max 3 attempts; no further edit.

## Why last review failed

Attempt 3 is the right *material family* (violet-black obsidian, grey converter
void, no grout, no window lace) but it is the wrong *wall*. A3-4’s job is a
broad bitten rampart chunk, one connected masonry block, heel planted. This
picture is a cube with a crystal-cluster crater and a scooped underside. Do not
send it to Studio until:

1. the silhouette is obviously wider than tall (thick broken rampart, not a
   cube);
2. the heel undercut is filled so the mass sits as one planted block (no arch,
   no doorway, no floating jewellery);
3. the bite is a missing top or corner of the same volume, coarsened to a few
   large planar facets, not a geode of small shards HD will split.

## Foreshadow

Map kits are L0 scenery (`docs/story/05-foreshadow-ledger.md` rule 2). This
subject must not show a six-pane rose, wheel window, stained-glass tracery, or
window lace (L3 shard count; Vigil already banned this on the road face). None
of the three attempts leak that. Failure mode 9 (window street) is the combat
mid-plate clone; these pictures do not have pointed openings in the wall face.
The remaining defects are silhouette / mesh-readiness, not a ledger leak.

## Not done here

No GLB. `docs/art-ledger.md` not appended. Dest
`geometry/act3/shattered-wall-mass.glb` remains absent. Ordinary HD profile when
a later slice converts, after a passing concept: `--textured --privacy private
--faces 1500 --topology triangle --texture-quality 1k --pbr off`. Caps 192 KiB /
600–2500 triangles. Tripo Studio only; never the API.
