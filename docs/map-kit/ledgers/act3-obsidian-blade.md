# `act3-obsidian-blade` — conversion concept

| Field | Value |
|---|---|
| asset_id | `act3-obsidian-blade` |
| billed_id | A3-1 / `act3-obsidian-blade` |
| act | III — 黑曜王庭 / The Obsidian Court (`act_key=act3`, manifest `act: 2`) |
| role | ordinary |
| world scale seat | 6.2 |
| dest | `assets/art/map/geometry/act3/obsidian-blade.glb` — **absent** |
| concept | `assets/art/map-concepts/act3-obsidian-blade.jpg` |
| reshape-vs-new | **new** (first generate; dest was empty; not a clay copy, not a reshape) |
| attempts | 2 (attempt 1 fail, attempt 2 pass) |
| last self-review | **pass** |
| generated | 2026-08-25 |
| size | 1024×1024 RGB JPEG |
| sha256 | `afce6aced244824d51251644a7afa3a8bb2798bf45e031630fa4d9a3bd876ec6` |

Direction: `docs/map-kit/act3-prompt-direction.md`. Bill: `docs/map-scene-asset-bill.md` A3-1 (large obsidian wedge). L3 risk exists on this act (Rose Window / six panes / sealed door / intact halo); concept is held to `docs/story/05-foreshadow-ledger.md` rule 2 via the act3 foreshadow-ban table. No GLB generated this pass. `docs/art-ledger.md` not appended.

The wave direction names the concept `.png`. This slot saved `.jpg` as the conversion-concept task required. Square 1024×1024 RGB JPEG. Not an Act I clay-maquette reuse.

---


**GLB landed 2026-08-25** as Studio HD textured (`--textured`, ordinary 1500/1K/Ultra off). Dest is on disk. 20-placement: `docs/reviews/292/act3-obsidian-blade-20.png`. This ledger’s “no GLB / do not append art-ledger” lines are historical.
## Silhouette job

large faceted obsidian wedge, blade-leaning mass with a broad grounded heel, one connected volume, **not a tower**

---

## Prompt (attempt 1, `image_gen`, 1:1)

Square 1:1 game-kitbash 3D prop concept, entire object centred with even margin, three-quarter view from 35–40° above. Isolated subject, large in frame. Flat solid neutral mid-grey background (#8A8A8A), ground-free, no horizon, no environment, no sky, no storm clouds, no landscape, no cast shadow, no baked AO puddle, no contact darkening, no floor disc, no depth of field, no fog, no rim light, no character, no scale figure.

Cold violet-black low-contrast matte illumination from above-front; even studio light; no key-and-fill drama, no chrome specular, no emissive glow, no lantern, no fire.

Material is TEXTURED faceted obsidian court-stone: almost-black opaque glass-stone that does not transmit light, broad planar facets, a faint dull magenta-violet sheen in the seams only. Weathered matte-to-satin glass-stone albedo, not clay, not untextured grey plastic, not chrome, not transparent panes, not gold, not stained glass. Large few facets, low-poly-friendly game-asset.

Subject: a single large faceted obsidian wedge, one connected volume. A blade-leaning mass: one thick triangular shard-block with a BROAD GROUNDED HEEL and a short leaning crest. The wedge is LYING INTO THE GROUND like a reclining doorstop or fallen shard-block, not standing. Horizontal ground-span is clearly longer than height (about 1.7 to 1). Heel is much wider than the crest. Low centre of mass. Crest is blunt and truncated, not a sharp point. Lean angle about 35 degrees from the ground plane. Chunky geometric facets.

NOT a honed sword. No hilt, no guard, no tang, no handle, no weapon. NOT a standing obelisk, NOT a spire, NOT a tower, NOT a needle, NOT a peak cluster, NOT a monument stele, NOT a roof finial, NOT a vertical climb. Do not make it taller than it is long. One fused volume — no second cube, no detached chip, no floating shard.

No windows, no rose lace, no six panes, no circular window, no stained-glass tracery, no halo, no ring, no hanging crystal, no doorway, no sealed door, no keyhole, no throne, no crown, no faces, no hands, no figures, no text, no glyphs, no numbers, no ash, no roots, no water, no rust.

---

## Attempt 1 — blind description (before re-read of spec)

Single isolated 3D mass on a flat mid-grey void. Camera is three-quarter from above. The body is a dark almost-black faceted mineral wedge, low and long, with a thick left-front foot and a slope rising toward the right. A distinct cuboid / octagonal knob sits on the upper-right of the mass, like a turret, chimney, or head. Surface is opaque obsidian with a large lighter lilac-grey planar facet and several hairline scratches / crack lines. No second object, no sky, no window, no gold glow. One fused volume, but the knob reads as a second architectural part.

### Attempt 1 review (after re-read)

| Gate | Result |
|---|---|
| silhouette_job | **fail** — knob / turret / head on the crest; not a single triangular shard-block; slight figure read |
| framing | pass — 1:1, centred, mid-grey, ground-free, 35–40° three-quarter |
| textured surface | fail — crack lines / scratches; knob over-complicates albedo regions |
| foreshadow bans | fail — figure / head read (banned faces/figures); turret rhymes with a small tower / finial |
| tower / weapon / stele | body is reclining (good) but the knob is a small tower on a ramp |

Edit, do not keep.

---

## Prompt (attempt 2, `image_edit` of attempt 1)

Keep the same square 1:1 framing, three-quarter view from 35–40° above, flat solid mid-grey background (#8A8A8A), ground-free, no cast shadow, no floor disc, even cold studio light.

Edit the object into ONE simple thick triangular obsidian wedge — a reclining shard-block lying into the ground like a doorstop. REMOVE the cube, turret, knob, chimney, or head-like block on the upper-right. That protrusion must disappear. The crest is only the short blunt taper of the same wedge, fused, not a second volume.

Keep a broad grounded heel, much wider than the crest. Horizontal span longer than height. Low centre of mass. One connected volume. Chunky large planar facets, few of them. Almost-black faceted obsidian glass-stone, faint dull magenta-violet sheen in the facet seams only. No crack lines, no hairline scratches, no pores, no brick grout. Matte opaque, not transparent, not gold, not glowing, not clay.

Not a sword, no hilt, no guard. Not a tower, not an obelisk, not a stele, not an animal, not a figure, not a boot, not a cannon. No windows, no ring, no halo, no crystal hanging, no text. Isolated single prop.

---

## Attempt 2 — blind description (before re-read of spec)

Single isolated object, square frame, flat mid-grey background, no horizon. Three-quarter view from above. One connected doorstop / triangular prism: low blunt end on the left-front, tall triangular end on the right-rear, the top face a long slope. Almost-black opaque obsidian, a few large planar facets, one near face a dull violet-grey. No knob, no second block, no hilt, no window, no sky, no floor disc. Even studio light, no rim, no glow.

### Attempt 2 review (after re-read)

| Gate | Result |
|---|---|
| silhouette_job | **pass** — large faceted obsidian wedge, blade-leaning, broad grounded heel (tall back), one volume, longer than tall, not a tower |
| framing | **pass** — 1024×1024; object ~77% of width / ~54% of height; even margin; background mean RGB ≈ 138 (`#8A8A8A`); no horizon; no floor island; 35–40° three-quarter |
| textured surface | **pass** — painted faceted obsidian albedo, not clay; faint magenta-violet on one planar face / seams; no grout, no gold, no transparency. One residual hairline on the violet face is below grout/pore noise |
| foreshadow bans | **pass** — no rose / six panes / wheel / stained lace; no shard socket; no gold halo; no floating ring or hanging crystal; no sealed door or keyhole; no spire/climb; no throne/crown/sitter; no faces, hands, glyphs, numbers, “six”, “III”; no will-light, no transparent pane; no ash/water/roots; not a standing monument |
| 20-placement risks (concept only) | not a tower field; not a hilted weapon; not a stele; not a floor disc |

Last self-review: **pass**. Keep attempt 2.

---

## Notes for a later Studio pass (not this task)

Ordinary HD flags from the direction file: `--textured --privacy private --faces 1500 --topology triangle --texture-quality 1k --pbr off`. Do not call the Tripo API. Do not Generate Multi-Views. Do not land a GLB from this ledger.
