# act3-broken-halo — conversion concept ledger

| Field | Value |
|---|---|
| `asset_id` | `act3-broken-halo` |
| `billed_id` | `act3-broken-halo` |
| bill | A3-2 |
| `act_key` | `act3` |
| dest | `assets/art/map/geometry/act3/broken-halo.glb` |
| concept | `assets/art/map-concepts/act3-broken-halo.jpg` |
| role | ordinary kit (scale seat 2.8) |
| reshape-vs-new | **new** — dest absent; only signed hero `terminus-broken-ring-arch.glb` sits in `geometry/act3/`. Not a reshape of that hero. |
| attempts | 3 (1× `image_gen`, 2× `image_edit`) |
| last self-review | **pass** |
| concept sha256 | `68d6ad48ca23c6f2a64163d6dd4272a37f03c0637fc6adace3e2b73cba25e340` |
| pixels | 1024×1024 RGB JPEG, 100200 bytes |

Direction: `docs/map-kit/act3-prompt-direction.md`. Foreshadow: `docs/story/05-foreshadow-ledger.md` rule 2 (L3 rose/six-panes; halo gap must not become a lock diagram). No GLB was generated. `docs/art-ledger.md` was not appended.

Silhouette job (slot): thick grounded broken halo, C-shaped incomplete ring with a missing-shard gap, one connected volume, **not a doorway arch**.

---


**GLB landed 2026-08-25** as Studio HD textured (`--textured`, ordinary 1500/1K/Ultra off). Dest is on disk. 20-placement: `docs/reviews/292/act3-broken-halo-20.png`. This ledger’s “no GLB / do not append art-ledger” lines are historical.
## Spec prompt skeleton (direction §7 + shared preamble)

Square 1:1 game-kitbash 3D prop concept, entire object centred with even margin, three-quarter view from 35–40° above. Isolated subject, large in frame. Flat neutral mid-grey background (#8A8A8A), ground-free, no horizon, no environment, no cast shadow, no baked AO puddle, no depth of field. Cold violet-black low-contrast matte illumination from above-front; no rim light, no chrome spec, no emissive glow. Faceted obsidian court-stone: almost-black glass that does not transmit light, broad planar facets, a faint dull magenta-violet sheen in the seams only. Clean planar low-poly-friendly game-asset concept. One connected volume sitting on an implied ground, no floor disc. No characters, hands, faces, text, glyphs, windows, rose lace, lanterns, water, ash, roots, or sky.

Subject:

> A single thick grounded broken halo: one C-shaped incomplete ring, a horseshoe of faceted obsidian, both cut ends of the C planted on the ground, a missing-shard gap in the ring itself. One connected volume. Thick torus-section, not a wire, not a thin hoop. The gap is a coarse bite out of the same ring, not a doorway, not an architectural arch, not a lock socket, not a shard-shaped keyhole. No flanking pylons, no plinth-bar, no hanging crystal in the gap, no second ring, no floating jewellery. Not the monumental ring-arch terminus. Squat, grounded, court debris.

---

## Attempt 1 — `image_gen` 1:1 — fail

sha256 `542cc030f7639861a586cec99c9edd07fcc08571858793f5628de5a04a676eb2` (session `images/1.jpg`, 1024×1024 RGB JPEG).

**Prompt (verbatim):**

> Square 1:1 game-kitbash 3D prop concept, entire object centred with even margin, three-quarter view from 35–40 degrees above. Isolated subject, large in frame. Flat neutral mid-grey background (#8A8A8A), ground-free, no horizon, no environment, no cast shadow, no baked AO puddle, no depth of field. Cold violet-black low-contrast matte illumination from above-front; no rim light, no chrome spec, no emissive glow.
>
> Subject: a single thick grounded broken halo. One C-shaped incomplete ring — a squat horseshoe of faceted obsidian court-stone. Both cut ends of the C planted on the implied ground as blunt fractured stumps. A missing-shard gap in the ring itself: a coarse irregular bite taken out of the same volume, jagged broken facet faces, not a fitted socket and not a keyhole. One connected volume only.
>
> Geometry: thick torus-section, fat tube, chunky. The ring's cross-section is a heavy rounded hexagonal / faceted stone tube, almost as thick as the inner hole is wide, so the leftover inner void is a small remnant, not a walkable portal. Overall silhouette is squat and wider than tall, like fallen court debris, slightly reclined. Even thickness all the way around the C. Rounded circular incomplete ring, not a pointed gothic lancet, not a doorway, not an architectural arch you walk through. Not a thin wire hoop. Not a closed circle. Gap is clearly open (about a quarter of the ring missing) so it cannot read as a complete O.
>
> Material: faceted obsidian, almost-black dull glass-stone that does not transmit light. Broad planar facets, few of them, low-poly-friendly. A faint dull magenta-violet sheen only in the facet seams. Weathered matte, not chrome, not wet, not transparent panes. Quiet albedo, no gold leaf, no glowing runes, no brick grout lines, no crack-line noise.
>
> Forbidden: no flanking pylons, no rectangular plinth-bar or floor slab, no hanging crystal in the gap, no second ring, no floating jewellery, no towers, no doorway, no stained-glass windows, no rose lace, no six panes, no gold halo, no neon, no flame, no characters, hands, faces, text, glyphs, lanterns, water, ash, roots, or sky. Not a miniature of a monumental ring-arch on a base. Clean planar game-asset concept sitting on implied ground with no floor disc.

**Blind description (written from the picture, before re-scoring the spec):**

Square mid-grey void, no horizon, no floor disc, no contact shadow. Isolated C of dark faceted glass-stone with magenta-violet facet flash. Camera is nearly top-down; the ring lies in the picture plane like a cuff on a table, not a sculpture standing on two feet. Two openings: a coarse gap at the near side and a second jagged split on the far-right that almost severs a shard. A small circular bore is drilled through the inner wall of the torus (bead-hole / keyhole). Tube is medium, inner void large. Many tiny gem-cut facets, specular. No pylons, plinth, hanging crystal, gold, windows, or figures.

**Score:** silhouette fail (recumbent jewelry, not planted-end horseshoe; two-shell risk at the second split). Framing fail (too top-down). Textured: yes, but chrome-gem not matte court-stone. Foreshadow fail (drilled hole reads as a lock/keyhole).

---

## Attempt 2 — `image_edit` of attempt 1 — fail

sha256 `ab7925dbdea1d519a53183487fbecbb1a829d5fc0fe67768b617bf6fd6c19209` (session `images/2.jpg`).

**Edit prompt (verbatim):**

> Keep the same isolated square 1:1 framing: flat solid mid-grey background (#8A8A8A), no ground plane, no floor disc, no horizon, no cast shadow, no AO puddle, even margin, object large and centred.
>
> Rewrite the pose and mass. This must be a 3D game-kitbash prop seen in three-quarter view from 35–40 degrees above (same camera band as a product shot of a small sculpture, NOT a top-down jewelry photo). The broken halo now STANDS as squat court debris: a thick C-shaped horseshoe of faceted obsidian, both fractured cut-ends planted down as blunt feet on the implied ground. The opening of the C is a single coarse missing-chunk gap between those two planted ends. One connected volume only.
>
> Thicken the torus a lot: fat chunky tube, low-poly, few broad planar facets, overall wider than tall, slightly reclined. Inner void is small because the stone is fat — not a walkable doorway, not a pointed gothic arch, not a thin hoop, not a closed circle.
>
> Delete the drilled circular hole through the ring. Delete the second crack/split on the upper-right so it cannot become two pieces. No detached shard, no hanging crystal, no pylons, no plinth slab.
>
> Material: dull almost-black faceted obsidian glass-stone, low-contrast matte, faint magenta-violet sheen only in the seams, no chrome, no gem sparkle, no transparency, no gold, no glow, no brick grout. Cold even studio light from above-front, no rim light.
>
> Same object family as the input (dark faceted incomplete ring) but now a grounded squat horseshoe sculpture, not a bracelet lying on a table.

**Blind description:**

Square mid-grey. Object is now a standing C / horseshoe, both broken ends at the bottom, three-quarter from above. One gap, no second split, no drilled hole, no pylons, no plinth, no hanging crystal. Soft cast shadow / contact puddle under the right foot and a slight ground gradient — a floor cue. Inner hole still large; upright pose plus that hole reads as a portal. Facets still many and jewelry-regular. Left broken end is a fused rocky lump, still one volume.

**Score:** silhouette mixed (planted ends yes; doorway-arch risk yes). Framing fail (cast shadow / floor). Textured mixed (obsidian colour, too specular/gem). Foreshadow hold (gap is a coarse bite, not a socket).

---

## Attempt 3 — `image_edit` of attempt 2 — pass (shipped)

sha256 `68d6ad48ca23c6f2a64163d6dd4272a37f03c0637fc6adace3e2b73cba25e340` — copied to `assets/art/map-concepts/act3-broken-halo.jpg`.

**Edit prompt (verbatim):**

> Keep this same incomplete C-ring identity and the three-quarter view from 35–40 degrees above. Square 1:1, object centred with even margin, isolated, large in frame.
>
> CRITICAL floor fix: remove every cast shadow, contact darkening, and ground gradient. Background must be a perfectly flat even mid-grey (#8A8A8A) with no floor plane and no puddle under the feet. The object sits on implied ground only.
>
> CRITICAL mass fix: make the torus much fatter and the whole sculpture squat. Tube cross-section should be a heavy chunky faceted stone, almost as thick as the leftover inner hole is wide. Overall wider than tall, slightly reclined like fallen court debris, both fractured ends still planted as blunt feet. The inner void must be a small remnant, not a walkable doorway or gothic arch. Keep one coarse missing-chunk gap between the two planted ends. One connected volume. No second crack, no drilled hole, no detached chip.
>
> CRITICAL surface fix: replace the many tiny gem-cut facets with a few large planar low-poly obsidian faces, game-kitbash, readable at a distance. Dull almost-black glass-stone, low-contrast matte, faint magenta-violet sheen only in the seams. No chrome sparkle, no transparency, no gold, no glow.
>
> Keep: no pylons, no plinth slab, no hanging crystal, no second ring, no windows, no characters, no text. Not a pointed lancet. Not a thin hoop. Not a closed circle. Not jewelry on a table.

**Blind description:**

Square even mid-grey, no horizon, no floor disc, no visible contact puddle. Isolated incomplete ring, one coarse rocky gap toward camera, both broken ends as rough stumps. The C is squat and reclined, wider than tall on the page; we look down enough to see inner-wall depth, not a pointed gothic door. Tube is thicker than attempt 1; facets are broader planar faces with a dull magenta-violet sheen, almost-black, not clay. One connected volume. No pylons, no plinth-bar, no hanging crystal, no second ring, no gold, no windows, no figures, no glyphs. A small dark pock sits on the inner upper wall — a surface pit, not a through-bore and not in the gap.

**Score (after re-reading the spec):**

| Gate | Hold? | Note |
|---|---|---|
| silhouette_job | yes | Thick grounded C with a missing-shard gap, one volume. Recumbent/squat court debris, not a walkable doorway, not a miniature of `terminus-broken-ring-arch` (no pylons, no plinth, no suspended shard). Gap stays open (not a closed-ring coin). |
| framing | yes | 1:1, whole object, even margin, isolated, flat #8A8A8A, ground-free, no horizon, no cast shadow. High three-quarter on a squat mass; both broken ends and the inner void are visible. |
| textured surface | yes | Faceted obsidian albedo, faint violet seam sheen, not clay-maquette, not grout lace, not gold leaf, not emissive. |
| foreshadow bans | yes | No rose / six panes / wheel window / stained tracery. Gap is a coarse bite, not a fitted emberglass socket. No gold halo, no hanging crystal, no pylons, no sealed door, no throne, no faces/glyphs/“six”/“III”, no will-light, no transparent pane. Inner-wall pock is not in the halo gap and is not shard-shaped. |

Anti-clone vs signed hero: the billed terminus is a ring-arch on a rectangular plinth with two pylons and a suspended shard. This kit concept is a single reclined C of court-stone.

---

## Out of this pass

- No Studio generate, no API call, no GLB under `assets/art/map/geometry/act3/` except the already-signed hero (untouched).
- No `docs/art-ledger.md` row.
- No `domain/` edit.
