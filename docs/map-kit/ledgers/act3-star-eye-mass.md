# Concept ledger — `act3-star-eye-mass`

| Field | Value |
|---|---|
| asset_id | `act3-star-eye-mass` |
| billed_id | `act3-star-eye-mass` |
| bill | A3-5 |
| act_key | `act3` |
| dest_path | `assets/art/map/geometry/act3/star-eye-mass.glb` |
| concept_path | `assets/art/map-concepts/act3-star-eye-mass.jpg` |
| role | ordinary |
| world scale seat | 3.2 |
| reshape-vs-new | **new** — dest absent on 2026-08-25 (act3 geometry folder holds only signed `terminus-broken-ring-arch.glb`). Not a reshape. Not a clay copy. |
| silhouette_job | coarse star-and-watching-eye as one fused stellate blob, low squat court mass with a blunt lens bulge, no tassels or pointing hands |
| direction | `docs/map-kit/act3-prompt-direction.md` (present) |
| L3 risk | yes — map is L0; rose/six-pane/window-lace, faces, iris, cult tassels/hands, gold halo, sealed door, and fire-physics glow are banned. `docs/story/05-foreshadow-ledger.md` rule 2. |
| generator | Grok Imagine `image_gen` / `image_edit`, aspect 1:1 |
| attempts | 3 (cap) |
| last self-review | **FAIL** |
| concept sha256 | `c7cd3be1839e1366af83c97799cb81fc06f4256b27a41f28caceeb923b808158` |
| pixels | 1024×1024 JPEG |

Do not convert this picture in Studio until a later concept pass fuses the lens. The last frame still reads as a second blob.

---


**GLB landed 2026-08-25** as Studio HD textured (`--textured`, ordinary 1500/1K/Ultra off). Dest is on disk. 20-placement: `docs/reviews/292/act3-star-eye-mass-20.png`. This ledger’s “no GLB / do not append art-ledger” lines are historical.
## Prompt (attempt 1, `image_gen`)

Square 1:1 game-kitbash 3D prop concept for a low-poly game map module. Entire object centred with even margin on all sides, nothing cropped. Three-quarter view from 35 to 40 degrees above, camera looking down-forward at the object. Isolated subject, large in frame, filling most of the square.

BACKGROUND: perfectly flat solid neutral mid-grey studio field #8A8A8A, edge to edge. Ground-free. NO horizon, NO floor, NO ground plane, NO environment, NO sky, NO storm clouds, NO landscape, NO backdrop, NO fog. NO cast shadow on a ground, NO contact shadow, NO baked AO puddle, NO floor disc, NO reflection. No depth of field.

SUBJECT: a single coarse fused stellate blob — one connected volume of faceted almost-black obsidian court-stone sitting as a low squat architectural mass, wider than it is tall, planted on an implied ground (but draw no ground). It is court debris / a chunky game-kitbash prop, NOT a creature, NOT a face, NOT a cult ornament, NOT jewellery.

SHAPE: a thick melted 3D star-mass. About six to eight blunt rounded star-points fused into one solid blob, like a squat starfish-lump of stone that has been melted together. Points are coarse, rounded, chunky, low-poly planar, melted into the body — not sharp spikes, not needles, not a Christmas star, not a 2D cutout, not a star on a stick, not an ornament on a pole. The body is a low wide court mass. The silhouette must still read as a star/stellate blob if all internal facets were removed. Distinct from a smooth cairn mound: the points must be obvious in silhouette.

LENS BULGE: on the near facing side, one blunt convex dome bulge continuous with the same obsidian volume — a thick lens-like swelling of the SAME opaque stone, fused, not a separate object. No iris, no pupil, no concentric rings, no eyelashes, no eyelids, no sclera, no eye whites, no looking-at-you face. It is a dome of dead glass-stone, not an eyeball.

MATERIAL: faceted obsidian court-stone. Almost-black opaque glass that does NOT transmit light. Broad planar low-poly facets, few of them, large readable planes. Dull matte-to-satin surface. A faint dull magenta-violet sheen ONLY in the facet seams, low-contrast. Weathered quiet albedo. NOT clay, NOT grey untextured maquette, NOT untextured. Named material: dull violet-black glass-stone.

LIGHTING: cold violet-black low-contrast matte illumination from above-front studio light. Even, no key-and-fill drama, no rim light, no chrome specular, no emissive glow, no neon, no gold, no flame, no lantern, no will-light.

BANNED: characters, hands, pointing hands, arms, fingers, faces, tassels, hanging ornaments, spears, shields, cultists, masks, crowns, thrones, windows, rose windows, stained-glass panes, window lace, gold leaf, gold trim, glowing runes, glyphs, text, numbers, six-count, transparent glass you can see through, hanging crystal, broken halo ring, pylons, door, lock, keyhole, tower, spire, water, ash, roots, wood, brick grout, crack lines, floating jewellery, second object, floor.

Clean planar low-poly-friendly textured game-asset concept. One object. Architectural mass. Opaque. Squat. Grounded heel.

---

## Attempts

Blind description is written from `read_file` on the generated image **before** scoring against the spec.

### Attempt 1 — generate — FAIL

sha256 `3251f0c30d8f5a7c335dff057f882add93e3261f64b760d581c31975447eb2b5`

**Blind.** Isolated dark faceted 8-point star on flat mid-grey, no ground, no horizon, no floor shadow. Three-quarter from above. The star is a thin regular cookie-cutter plaque. A faceted oval cabochon sits on top of it as a separate gem. Violet sheen on some planes. No hands, tassels, gold, glow, text, iris, or windows.

**Score.** Framing pass. Textured (not clay) pass. Foreshadow bans pass. Silhouette_job fail: not one fused blob; lens is a second object; pancake star, not a squat court mass; points too regular (Christmas-star badge). Two-shell risk (failure mode 17).

### Attempt 2 — `image_edit` of 1.jpg — FAIL

Edit asked to fuse the gem into a near-face bulge, thicken into a mass, blunt/melt the points, keep grey ground-free framing.

sha256 `87476994f4a68cff3cd9110d21865aba709219fdf64271cabb7cdc22645d7116`

**Blind.** Isolated 6-point rounded star blob, thicker, dark violet-black, still on mid-grey with no floor. A large smooth egg still sits on the roof with a visible undercut. Surface is organic and glossy, not planar facets. No hands, face, tassels, gold, or glow.

**Score.** Framing pass. Foreshadow bans pass. Textured-not-clay pass, but too smooth/chrome for “broad planar facets” / “no chrome spec”. Silhouette_job fail: lens still a second blob; still a lying star-cookie rather than a court mass with a near-face bulge.

### Attempt 3 — `image_edit` of 2.jpg — FAIL (last)

Edit asked for real height, lens as a continuous near-wall swelling with no undercut, broad planar obsidian facets, matte not resin.

sha256 `c7cd3be1839e1366af83c97799cb81fc06f4256b27a41f28caceeb923b808158` (this is the saved concept)

**Blind.** Isolated 6-point dark star mass on mid-grey, no ground, no floor shadow, square, centred, even margin, high three-quarter. Star body has some planar facets and a violet plane on the near face. A large smooth purple-black egg still sits in a groove on the top/near centre, glossy highlight, undercut around the base. No iris, pupil, lids, hands, tassels, gold, glow, windows, glyphs, or figures.

**Score (last self-review).**

| Gate | Result |
|---|---|
| framing (1:1, whole object, centred, #8A8A8A, ground-free, no horizon, no cast shadow, 35–40° 3/4) | **pass** |
| textured surface (obsidian albedo, not clay-maquette) | **pass** (body faceted; egg still too glossy) |
| foreshadow bans (no rose/six-pane/lace, no face/iris, no tassels/hands, no gold halo, no sealed door, no glow, no transparent pane) | **pass** |
| silhouette_job (one fused stellate blob, low squat court mass, blunt lens bulge) | **fail** — lens is still a second egg on a lying star, not a fused near-face bulge of one mass. HD would likely emit two shells (direction reshape note + 20-placement mode 17). Still reads as a star badge, not a squat court mass. |

Cap reached. No fourth picture.

---

## Saved concept

`assets/art/map-concepts/act3-star-eye-mass.jpg` is attempt 3, kept as the conversion candidate on disk so the fail is inspectable. It is **not** signed for Studio HD. A later concept pass must:

1. Fuse the oval into the near wall as a convex swelling with no undercut and no roof-egg.
2. Give the body real squat height (court mass, not a pancake star).
3. Keep blunt stellate points so it does not collapse to Act I cairn at seat 3.2.
4. Keep the converter framing and the foreshadow bans, which already hold.

No GLB was generated. `docs/art-ledger.md` was not appended.
