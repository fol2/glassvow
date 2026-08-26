# act2-lure-lantern-post — conversion concept

- **asset_id:** `act2-lure-lantern-post`
- **billed_id:** A2-5
- **act_key / title:** act2 / Act II kits
- **role:** ordinary
- **dest_path:** `assets/art/map/geometry/act2/lure-lantern-post.glb`
- **existing_path:** (none)
- **concept_path:** `assets/art/map-concepts/act2-lure-lantern-post.jpg`
- **reshape-vs-new:** **new**. Dest was absent (`geometry/act2/` held only `terminus-flooded-threshold.glb`). First picture, not a reshape of a prior mesh or clay copy.
- **attempts:** 3
- **last self-review:** pass (attempt 3)
- **sha256:** `77839af250214e2c4ba6d45df8ffe6b2584ad3f9e7b64984b3ad079dbf463a66`
- **bytes / size:** 149151 bytes, 1024×1024 RGB JPEG
- **do not convert from:** `map-concepts/act2-terminus-flooded-threshold.png` (combat-plate chains / paired hanging lamps)


**GLB landed 2026-08-25** as Studio HD textured (`--textured`, ordinary 1500/1K/Ultra off). Dest is on disk. 20-placement: `docs/reviews/292/act2-lure-lantern-post-20.png`. This ledger’s “no GLB / do not append art-ledger” lines are historical.
## Silhouette job

False-light landmark: one thick upright post with a blunt globular lantern head fused on top, opaque lure-glow as albedo not true flame, no cage bars, chains, wick, or Act I paired lamps.

## Shared prompt preamble (every id)

Orthographic three-quarter view from 35–40° above of a single game-kitbash 3D prop. Entire object centred with even margin in a square 1:1 frame. Whole object visible, nothing cropped. Flat neutral mid-grey background (#8A8A8A), ground-free: no floor plane, no horizon, no environment, no cast shadow, no contact-shadow puddle, no depth of field, no vignette, no rim light. Even cold studio illumination from above-front, low-contrast, no baked AO, no theatrical key slash. TEXTURED concept, not a clay maquette: HD Model will bake albedo from this picture, so the surface must show drowned-masonry / silted-stone colour and courses — weathered blue-grey ashlar, rust-stained joints, pale silt crust — large planar faces, low-poly-friendly, matte. One connected solid volume sitting as if on invisible ground. Clean silhouette. Isolated subject, large in frame. Not a tile texture, not a landscape, not a diorama.

## Shared negatives (every id)

No towers, no spires, no climb, no wrapping stair, no stair-as-the-road. No cage bars, no chains, no hanging lamps, no paired Act I lanterns, no wick, no true flame, no fire, no ember. No kelp, no coral, no starfish, no fish, no bubbles, no painted water sheets, no caustic shafts, no water planes. No grout lace, no thin crack lines, no moss hair, no grass. No readable text, no letters, no glyphs, no page-spreads with writing. No rose window, no wheel window, no circular six-pane disc, no trefoil as a counted emblem, no broken halo, no obsidian star, no watching eye, no queue of standing figures, no person, no skeleton, no Leviathan. No inverted hearth-amber, no gold-city, no sealed east door. No second prop. No floor disc. No cast shadow. No chips detached from the mass.

## Species subject (A2-5)

Subject: one false-light landmark. A single thick upright masonry-and-iron post with a blunt globular lantern head fused on top — one lollipop, not a hanging lamp, not a pair. The head is a closed opaque glass bulge, cold teal lure-glow painted as albedo, not a flame, not a wick, not an emissive flare. No cage, no bars, no chain, no hook, no cross-arm. Post slightly wider at the silted foot, sitting on invisible ground. Drowned masonry on the post, rust streaks, silt at the base; the globe a smooth brine-teal glass mass. Distinct single-post silhouette, one connected volume.

Species extra negatives: no second lamp, no arch, no hanging pair, no Act I lantern language, no angler-fish, no creature, no open flame, no bars.

## Attempts

### 1 — fail (fuse)

**Method:** `image_gen`, aspect_ratio `1:1`.

**Prompt (generation):** preamble + subject + shared/species negatives, plus kit-scale emphasis (four to six ashlar courses, bollard-thick, globe fused with a short thick neck, opaque teal with no bloom halo).

**Blind description (written from the picture, before re-scoring the spec):** Square 1:1, uniform mid-grey void, no floor, no horizon, no ground-cast shadow. One object, three-quarter from above, even margin. Tapered square masonry pillar, wider at the foot: blue-grey coursed ashlar, rust streaks on one face, pale silt crust on the lowest course. On top, a round opaque teal sphere sits on a short grey cylinder and a rusty circular flange with bolt heads. No cage, chain, wick, flame, or second lamp. Surface is textured stone, not clay. The sphere is a separate ball on a neck, not melted into the post.

**Score:** framing pass; textured pass; foreshadow bans pass (no rose, pair, cage, flame, kelp, water, text, creature). Silhouette fail: globe not fused — thin neck + bolt flange is the exact island risk ("if the globe detaches, fuse head to post"). Bolts are small-part noise.

### 2 — fail (still stacked)

**Method:** `image_edit` of attempt 1.

**Edit:** remove thin neck and bolt flange; fuse globe to post as one lollipop; keep grey void and drowned masonry.

**Blind description:** Same framing and masonry post. Teal sphere now rests on a short rusty/silted cylindrical puck instead of the bolted flange. Neck/bolts gone. Globe still a free sphere on a stacked collar — three parts (globe, puck, pillar) with a hard contact line. No cage, chain, flame, pair, floor, or water.

**Score:** framing / texture / bans still pass. Silhouette fail: not one lollipop volume; HD can still lift the globe off the puck.

### 3 — pass (shipped concept)

**Method:** `image_edit` of attempt 2. This file is the saved JPG.

**Edit:** melt globe into the post; remove the separate puck; stone courses wrap up into a short thick neck the width of the post top; slightly squash the globe into a blunt bulge.

**Blind description:** Same square mid-grey void, no floor, no cast-shadow puddle, three-quarter from above, one centred subject. Tapered square drowned-masonry pillar, blue-grey ashlar, rust streaks, pale silt at the wider foot. Upper courses flare into a rounded stone neck that is continuous with the post. A blunt opaque brine-teal glass head sits in that neck — more a squashed globe / dome with a thick equatorial lip than a free sphere. No cage bars, chains, wick, open flame, hook, cross-arm, or second lamp. No kelp, coral, water sheet, rose disc, text, figure, or floor disc. Colour is in the materials (stone, rust, silt, painted teal), even cold studio light, no bloom halo.

**Score:**

| Gate | Verdict |
|---|---|
| Silhouette job | **pass.** One thick upright post; blunt globular lantern head on a fused stone neck; opaque teal albedo, not flame; no cage, chains, wick, or paired Act I lamps. Reads as one post at yaw. Residual: glass/stone socket line and a thick equatorial lip on the head — not bars, not a second lamp; watch for a crease if HD over-sculpts, reshape by thickening not by adding parts. |
| Framing | **pass.** 1:1, whole object, even margin, centred, 35–40° three-quarter, `#8A8A8A` family void, no horizon/floor/cast-shadow disc/DOF/vignette. |
| Textured surface | **pass.** Coursed drowned masonry, rust joints, silt crust, teal glass as painted albedo. Not clay-maquette grey. |
| Foreshadow bans | **pass.** L0–L1 scenery only. No six-pane rose, walker queue, inverted hearth, court star/eye, paired hanging lamps, sealed door, spire, readable glyphs, cage/chain/wick/flame, kelp/coral/painted water, drowned figure or angler creature, grout lace. False-light is the allowed Act II motif, not deepmaw-as-creature. |

## HD / Studio notes (not run)

Ordinary flags from the Act II direction: `--textured --privacy private --faces 1500 --topology triangle --texture-quality 1k --pbr off`. Generation surface is Tripo Studio only. Do not call the API. Do not Generate Multi-Views. If the globe comes back as a second island, reshape this picture (thicken the neck, lose the lip) and reconvert — do not Blender-sculpt a shipping mesh as the first move.

No GLB was generated in this concept pass.
