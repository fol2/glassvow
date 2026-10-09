# R3.3: stone (issue #660)

Branch `map/r3-3-stone-2026-10-05`, on main `711302a5`. This is step R3.3 of
the R3 plan: Act I's rocks, cliffs and ruins. The ravine reads as a gorge of
stepped strata, mossy granite outcrops anchor the islands between the road
loops, and gravestones and broken walls stand along the roads.

Nothing here touches `domain/`, the save schema, the layout or its digests,
route ids, waystones, tokens, pins or other screens. Acts II–IV keep their
scenery: they are painted landscapes with no kit, terrain or rivers for the
stone to stand in, so the kit does not apply to them cheaply (as R3.2 found
for the floor).

**The woodland moved.** Placing the stone changes the kit's placement
sequence, so the woodland, which R3.1 b's unchanged rules plant round the
kit, re-flows. About two thirds of its cards stand where they stood and the
rest stand elsewhere, with the same totals and mix. The orchestrator
accepted the re-flow on 9 Oct ([below](#the-woodland-re-flowed)).

## What changed

| Commit | What |
|---|---|
| `fbf822a4` | **tools(map): the stone kit.** The Blender recipes (`tools/map_atelier/journey/stone/`: `sculpt.py`, `outcrops.py`, `cliffs.py`, `ruins.py`, `build_stone.py`, `prepare_stone.py`), the generated source pictures and their prompts, the masters (`journey/sources/<kind>.blend`), the hero kinds' reduced GLBs and the ruins' sculpts with their baked colour. None of it ships. `cover_tools.py` is shared with the floor's recipe. |
| `9a33cfd8` | **map: the stone.** The merged stone (`land_stone.gd`, `stone_pieces.gd`, `stone.gdshader`), the ravine's rule (`ravine_cliffs.gd`), the islands (`land_islands.gd`), the kit's groups, gravestones, walls and rocks off the water (`kit.gd`), the ruins as cards (`impostor_atlas.gd`, `impostor_wood.gd`, `wood_planting.gd`), the floor's strata, stamps and warm-up, the art (`assets/art/map-journey/stone/`, the woodland atlas re-baked), the packers, the probe's `--trace-kill=stone`, the payload budgets and the tests (`test_map_stone`, new; `test_map_wood` and `test_map_floor` for the stone; `test_map_floor` also checks that a settled floor is kept when its land is let go, the orchestrator's follow-up to #703). |
| `4fa0cee8` | **test(map): determinism and the ruins' sight.** `test_map_stone` builds seed 717's land twice and compares a digest of every placement; at four seeds it asserts that no ruin hides a road, a waystone or a token, and that nothing the kit keeps in sight was placed behind an earlier ruin's card. |
| this commit | This README and its evidence, the art ledger's R3.3 section, and R3.2's README: re-anchored by a line where two preloads moved, and its prose on the live casters and the bake's cards brought up to date. |

Where the lane measured:

- the Mac's proofs and figures at `1ae3888c` and `abde6da0` (neither
  pushed). Their production files are the code commit's: they differ from
  the PR only in `test_map_stone.gd` (`1ae3888c`) and the docs;
- the device builds are of the same code ([Gates](#gates));
- the token gate's Acts II–IV and their sheets at `99a23e3c`. Those acts
  draw no kit, stone or ravine, and nothing they run changed after it. The
  pin tripwire's history across the lane's heads is in
  [`mac/pin-diagnosis.txt`](mac/pin-diagnosis.txt).

## The look

Sheets cover every stop at both shapes, main on the left of each pair (Act I:
seeds 717 and 1–3, from the token gate's stop captures at the code-final
runtime; Acts II–IV: seeds 1–3):

| Act | Pad | Phone |
|---|---|---|
| I | [`act1-pad.jpg`](frames/act1-pad.jpg) | [`act1-phone.jpg`](frames/act1-phone.jpg) |
| II | [`act2-pad.jpg`](frames/act2-pad.jpg) | [`act2-phone.jpg`](frames/act2-phone.jpg) |
| III | [`act3-pad.jpg`](frames/act3-pad.jpg) | [`act3-phone.jpg`](frames/act3-phone.jpg) |
| IV | [`act4-pad.jpg`](frames/act4-pad.jpg) | [`act4-phone.jpg`](frames/act4-phone.jpg) |

Acts II–IV differ from main by at most 1.2% of a frame's pixels (the motes
and the mist; [`frames/pixel-diff.txt`](frames/pixel-diff.txt)).

Crops at 2×, main beside the branch (seed 1, pad, lean, under the A12
condition):

- [the ravine](frames/crop-ravine.jpg): stepped strata on both banks, with
  the lip a rock edge at the rim;
- [an island's group](frames/crop-island.jpg): a mossy tor with a conifer
  behind it;
- [outcrops and gravestones by the gateway](frames/crop-outcrops.jpg): the
  granite ridge and a boulder, with their moss, cracks and contact shade;
- [gravestones](frames/crop-ruins.jpg) on the verges and by the bridge;
- [a broken wall](frames/crop-wall.jpg) at the Journey stop;
- [the hero pieces on their own](frames/pieces.jpg), under the land's key
  light and ambient, and [the ruins' cards](frames/ruin-cards.jpg) as
  baked.

**The iPad 8 frame** (the branch at Journey, seed 1): pending: iPad batch
(keychain).

## The kit

Crafted in Blender 5.2.2 (background, 4 threads), one recipe per kind, in
`tools/map_atelier/journey/stone/`:

- `outcrops.py`: five granite outcrops;
- `cliffs.py`: six cliff pieces;
- `ruins.py`: four gravestones, three broken walls and three rubble clusters.

Every kind is made the same way (`sculpt.py`):

1. **Sculpt.** Masses are fused into one solid by a voxel remesh: rounded
   blocks for granite, slabs for strata, ashlar for walls.
2. **Cut.** Joint planes are cut through the solid, and the remesh runs
   again to weather the cuts.
3. **Displace.** Every vertex moves along its normal by a seeded noise:
   Voronoi cracks along the joints, a slow swell, a fine grain, and level
   grooves at the strata.
4. **Retopologise.** Quadric collapse brings each kind to its triangle budget.
5. **Unwrap.** Each hero kind is unwrapped into its own cell of one atlas.
6. **Bake** (Cycles, CPU): normals, ambient occlusion and colour. The colour
   is the stone picture box-projected, darkened in its cavities and lifted on
   its edges, then darkened by the baked occlusion (a share of 0.75).

The masters are in `tools/map_atelier/journey/sources/`. A re-run of the kit
reproduces every shipped and source file byte for byte; only the `.blend`
masters differ, as Blender writes bytes of its own into them.

| Kind | Drawn as | Triangles | Circle (m) | Top (m) | What |
|---|---|---|---|---|---|
| `granite-bank` | mesh | 1,250 | 1.81 | 1.54 | Broad low granite mound: three rounded blocks on a flat joint top, a fallen piece at its foot |
| `granite-ridge` | mesh | 1,150 | 2.26 | 1.00 | Long low granite ridge: four jointed blocks falling away to one end |
| `granite-shard` | mesh | 900 | 0.99 | 2.13 | Upright granite pillar split from its bed, a leaning slab against it |
| `granite-tor` | mesh | 1,400 | 1.88 | 2.33 | Stacked granite tor: three blocks on level joints, a boulder shed at its side |
| `granite-boulder` | mesh | 874 | 1.07 | 0.90 | A single rounded granite boulder with a split face and a chip beside it |
| `cliff-wall` | mesh | 1,074 | 2.08 | 0.29 | Strata wall: even ledges stepping back from the water |
| `cliff-notch` | mesh | 1,074 | 1.94 | 0.35 | Strata wall cut by a deep weathered band, the layer above it overhanging |
| `cliff-buttress` | mesh | 1,074 | 1.98 | 0.40 | Strata wall with a jutting buttress whose facets turn toward the camera |
| `cliff-bend` | mesh | 1,074 | 1.99 | 0.32 | Strata wall curved outward, for the outside of the river's bends |
| `cliff-step` | mesh | 1,074 | 1.87 | -0.28 | Low broken strata step where the rim stands low over the water |
| `cliff-tall` | mesh | 1,074 | 2.14 | 0.51 | Tall strata wall with a high lip and an overhanging top ledge |
| `grave-arched` | card | 3,000 | 0.35 | 0.99 | Round-headed headstone with a sunk panel, leaning, its corner chipped |
| `grave-cross` | card | 3,500 | 0.39 | 1.26 | Ringed cross on a stepped plinth, one arm broken short |
| `grave-broken` | card | 3,000 | 0.81 | 0.67 | Pointed headstone snapped across, its head fallen at its foot |
| `grave-tablet` | card | 3,000 | 1.12 | 0.61 | Squat tablet leaning hard over its sunken ledger slab |
| `wall-run` | card | 6,000 | 1.79 | 1.70 | Run of coursed ashlar falling from shoulder height to its footing |
| `wall-corner` | card | 6,000 | 2.23 | 1.71 | Corner of a ruined building, its two runs broken off |
| `wall-pier` | card | 5,996 | 1.91 | 2.20 | Wall ending in a tall pier, an arch's springer stone left on it |
| `rubble-blocks` | card | 3,000 | 0.89 | 0.28 | Heap of fallen ashlar blocks, half sunk |
| `rubble-scree` | card | 3,000 | 0.97 | 0.25 | Fan of angular granite scree |
| `rubble-mossy` | card | 2,500 | 0.74 | 0.22 | Low mound of stones under moss |

**Hero kinds** (the outcrops and the cliffs) are drawn as meshes:

- `assets/art/map-journey/stone/stone-albedo.png` (2048×1536, 4×3 cells of
  512) holds their colour, which carries the occlusion;
- `stone-normal.png` (1024×768) holds the tangent-space normals at half size,
  imported as a normal map;
- `stone-pieces.res` holds the reduced meshes as plain arrays.
  `pack_stone.gd` packs them from the GLBs under
  `tools/map_atelier/journey/stone/glb/`; the GLBs themselves do not ship.

**Ruins** are drawn as impostor cards, re-baked into the woodland's atlas
(`impostors/wood-*`, from 2048×1408 to 2048×1776). Their sources are under
`tools/map_atelier/journey/impostors/stone/`: each sculpt at 2,500–6,000
triangles and its baked colour. They do not ship. The re-bake is
deterministic, and the woodland's own 42 tiles are the same as main's on
every covered texel; only the colour bled under the transparent texels
differs.

**Textures.**

- The granite and the cliff strata were generated with the image tool R3.2
  used, one candidate each. The prompts are in `stone/sources/prompts.txt`,
  with the pictures beside them.
- `prepare_stone.py` takes the slow light out, wraps the edges and grades
  the pictures. It shares its helpers with the floor's recipe
  (`cover_tools.py`), which still reproduces the floor byte for byte.
- The moss on the stone is the floor's own moss (`floor/floor-moss.png`),
  sampled in world space and lifted to an olive green, so it ships nothing
  new.

Every asset is a lane pick with a row in `docs/art-ledger.md`; the owner may
re-pick any of them.

## How the stone is drawn

`land_stone.gd`, `presentation/map/landscape/land_stone.gd:95 (build)`:

- The kit's granite and the ravine's cliff pieces are merged into one mesh per
  32 m cell on one material, so the stone draws in a few draws (seven at
  seed 717 for 49 pieces, six at seed 1 for 65). The merge is `SurfaceTool.append_from` over the
  packed arrays (`presentation/map/landscape/land_stone.gd:125 (_merge)`), which are
  held as meshes the renderer never sees, so nothing is read back from the
  renderer on the land's worker. The pieces load on the loader's threads
  before any land is built (`presentation/map/landscape/land_stone.gd:54 (prepare_step)`,
  from `Kit.preload_step`).
- `stone.gdshader` (`presentation/map/landscape/stone.gdshader:34 (fragment)`):
  - three samplers, none anisotropic: the atlas's colour and normals, and the
    moss;
  - a grade on the baked colour (`stone_tint`): granite reads grey under the
    warm key, not tan;
  - a moss cap where the mapped normal faces the sky, broken up by the moss
    picture; the cliffs' strata take a third of the outcrops' moss (by their
    cells in the atlas), so the rim reads as rock;
  - nothing that moves;
  - no vertex stage of its own, so its shadow uses the renderer's shared
    shadow pipeline.
- **The stone casts into the floor's bake, not live** (a [judgement
  call](#judgement-calls)). The live shadow pass keeps only the gateway arch
  and the bridges' parapets (`presentation/map/landscape/land_floor.gd:28 (LIVE_CASTERS)`).
- The floor's warm-up draws a sample of the stone's pipeline before the
  title, behind the launch screen, on a mesh in the stone's own vertex format
  (`presentation/map/landscape/floor_warm.gd:196 (_stone_mesh)`).

**The ravine** (`presentation/map/landscape/ravine_cliffs.gd:57 (plan)`): along both
banks of both rivers, a piece stands every 0.82 of its own width.

- **Placement.** Its face is turned to the water and its lip sits at the
  rim. A piece reaches 4.0 m below its rim and is scaled up, never down,
  where the rim stands high, so that its foot always reaches 0.5 m under the
  water.
- **Kind** (`presentation/map/landscape/ravine_cliffs.gd:94 (_kind)`). The bend piece
  goes on the outside of a bend, the low step where the rim stands low, and
  the tall wall where it stands high. Elsewhere a wall, a notched wall or a
  buttress is chosen by hash.
- **Clearances.** No piece stands:
  - by a bridge deck, an abutment, a waystone or a road;
  - within 2.5 m of the land's far edge or 8.9 m of its near edge. The
    camera sees under the near edge, and pieces there hung their feet below
    the land in the Whole act view.
  - where its foot would sink below the journey camera's slab
    (`MapJourneyCameraContract.LAND_LOW`, 5 m below the land's zero).
    Pieces 5.4 m deep broke that contract at low rims; `test_map_journey`
    caught it.
- **The banks.** The floor's bake lays the strata on the steep banks
  (`floor_paint.gdshader`), biplanar along the bank.

**The islands** (`presentation/map/landscape/land_islands.gd:30 (find)`,
`presentation/map/landscape/kit.gd:469 (_islands)`):

- **Finding them.** The ground no road or river lets out to the land's edge.
  Each island is held at its pole, the cell farthest from a road.
- **The group.** Each of the eight largest is anchored by an outcrop (the
  largest that fits of a tor, a bank and a boulder), with a conifer behind it,
  shrubs round it and gravestones either side of it (in front, a card would
  hide the rock).

**Gravestones and ruins**:

- **Gravestones.** Short rows of two along the roads' verges, one row every
  13 m of road on alternating sides, 2.3–3.1 m off the line, placed before
  the woodland's families (`presentation/map/landscape/kit.gd:528 (_verge_graves)`);
  after them, one beside each of up to eight memorial shrines, of the first
  sixteen (`presentation/map/landscape/kit.gd:510 (_shrine_graves)`); more on the
  islands; at most 30 on the verges and by the shrines (15–26 gravestones a
  land in all at seeds 717 and 1–3).
- **Broken walls** (`presentation/map/landscape/kit.gd:573 (_ruins)`). Up to four
  stand 3 to 5.5 m off a road, at least 16 m apart, turned across the
  camera's view, each with fallen blocks and a mossy mound beside it.
- **Only where they will be drawn** (`presentation/map/landscape/kit.gd:634 (_in_sight)`,
  `presentation/map/landscape/kit.gd:653 (_unhidden)`). A ruin is a card, and the
  woodland draws a card only where it hides nothing it must keep in sight:
  the roads' lanes, the decks, the waystones, the lamps, the water, the
  gateway, the shrines, the rocks and the other ruins. The kit asks the same
  question before it places a ruin, of the same grid
  (`presentation/map/landscape/wood_planting.gd:261 (protect_ground)`,
  `presentation/map/landscape/wood_planting.gd:309 (protected_area)`), and keeps it up
  to date with every placement after; and it places nothing the woodland
  keeps in sight behind a ruin's card. The planting then plants against the
  kit's grid (`presentation/map/landscape/kit.gd:434 (woodland_sight)`), the same
  protection over the same placements, so the grid is built once. Without
  this, 34 of 58 ruins at seed 717 were placed and then left out.
- **Planting.** The woodland plants them as cards where the kit placed them,
  never shrunk (`presentation/map/landscape/wood_planting.gd:527 (_fit_stone)`).
- **Floor and motion.** The standing ruins cast into the floor's bake
  through their cards (`presentation/map/landscape/wood_planting.gd:536 (casts)`), and
  their cards never sway (`presentation/map/landscape/impostor_wood.gd:159 (card_colour)`).

**Rocks off the water** (`presentation/map/landscape/kit.gd:805 (_clear)`): an
outcrop's footprint circle may reach over the bank and at most a quarter of
its radius over the water. On main, two to five rocks a land reached further
over the river (2, 3, 5 and 2 at seeds 717, 1, 2 and 3).

The granite kinds replace the R1 slate kinds in the same places, with the
same footprints (`granite-bank`, `granite-ridge`, `granite-shard`). The
slate scree is now the `rubble-scree` card. The new kinds' circles are the
kit's own, from its manifest.

## The woodland re-flowed

The woodland is R3.1 b's lane pick, planted by its unchanged rules round the
kit's placements. R3.3 changes the kit's placement sequence:

- the islands' groups, the walls and the verge rows come before the
  woodland's families;
- the new kinds have footprints of their own;
- rocks keep off the water.

Every later clearance follows from the earlier ones, so the woodland
re-flows. On 9 Oct the orchestrator accepted the re-flow, for four reasons:

- the owner picked R3.1 b's rules and character, not a fixed set of
  positions;
- nothing in the layout moves;
- the islands' groups are an R3.3 deliverable;
- main's rocks over the river are a defect.

The woodland stays a lane pick the owner may re-pick.

Built headless from the run seed, main `711302a5` against the branch's
code-final head (`tools/wood_dump.gd.txt`, `tools/wood_final.py.txt`,
[`mac/woodland.txt`](mac/woodland.txt)). The cards of the ruins are left out
of every count but the first column's note.

| Seed | Cards, main → branch | Identical | Re-flowed (main's, branch's) | Re-flowed within 5 m of a stone or ruin | Trees, main → branch | Kit placements in the same place |
|---|---|---|---|---|---|---|
| 717 | 3,788 → 3,762 (−0.7%; +42 ruins) | 2,542 (67.1%) | 1,246, 1,220 | 74% | 233 → 206 | 74 of 478 |
| 1 | 3,904 → 3,868 (−0.9%; +35) | 2,624 (67.2%) | 1,280, 1,244 | 71% | 270 → 267 | 78 of 532 |
| 2 | 3,866 → 3,822 (−1.1%; +40) | 2,624 (67.9%) | 1,242, 1,198 | 69% | 270 → 249 | 100 of 525 |
| 3 | 4,020 → 3,983 (−0.9%; +39) | 2,706 (67.3%) | 1,314, 1,277 | 66% | 271 → 249 | 77 of 562 |

- **Determinism.** Each seed was built twice on the branch: the two builds
  are identical, byte for byte. The layout digests are main's at every seed,
  and `tests/test_map_layout_fast.gd`, untouched, passes.
- **The mix holds** (R3.1 b's art direction, 35–40% conifers): conifers
  38.3, 39.3, 39.0 and 36.9% of the trees at the four seeds (main 38.2,
  39.3, 38.5, 38.0); crimson 36.9–38.6% (main 35.6–39.3); rust and amber
  22.9–24.8% (main 21.5–26.2).
- **Kinds that moved by more than 10%** over the four seeds: `ember-round`
  211 → 185 (−12.3%), `conifer-spire` 190 → 164 (−13.7%) and `conifer-wind`
  51 → 41 (−19.6%). The trees give way where the stone stands: the islands'
  poles, which crowns covered on main, now hold their groups; the verge rows,
  the walls and the rocks moved off the river take ground the woodland's
  families and the fill's crowns stood on; and a crown may not stand in front
  of a stone. `conifer-wind` is an accent of ten or so a land, so a few go a
  long way. Undergrowth moves by under 7% a kind; all cards by −0.9%.
- **Kit foliage left out by the sight rule** ('kit sight'): 717 19 → 21, 1
  18 → 25, 2 27 → 27, 3 30 → 32, every one foliage (every ruin is drawn).
  `test_map_wood`'s line, under a tenth of the kit's foliage, holds.
- **Main's rocks over the river**: 2, 3, 5 and 2 at seeds 717, 1, 2 and 3
  (`slate-bank`, `slate-ridge`, one `slate-shard`), each with more than a
  quarter of its radius over the water. The branch has none
  (`test_map_stone` checks the four seeds).

**R3.1 b's woodland gates, re-run** (its own tools, on the Mac under the
A12 Metal condition, lean, Reduce Motion stills, no drifting air, seed 1;
the cover by the flat-magenta count with the ruins' stone cards left out;
[`mac/woodland-gates.txt`](mac/woodland-gates.txt)):

| Figure | Gate | Main | Branch |
|---|---|---|---|
| Canopy cover, pad Journey | ≥ 45% | 45.3% | **43.6%** (misses by 1.4 points) |
| Canopy cover, pad Whole act | ≥ 45% | 43.9% (R3.1 b's exception) | 42.8% |
| Canopy cover, pad fresh-run opening | ≥ 45% | 45.8% | 45.8% |
| Canopy cover, phone Journey | ≥ 45% | 44.2% | 42.8% |
| Red share, pad Journey | 6.3–16.3% | 16.7% (R3.1 b's open residual) | **16.1%**, inside the band |
| Red share, pad Whole act | 6.3–16.3% | 11.5% | 12.2% |
| Red share, pad fresh-run opening | 6.3–16.3% | 12.5% | 12.3% |
| Red share, phone Journey | 6.3–16.3% | 12.5% | 14.1% |
| Saturated reds' hue bands (345–355 / 355–5 / 5–15°), pad Journey | the target's 5 / 56 / 39 | 0 / 59 / 41 | 0 / 55 / 45 |
| Pins, R2's tripwire (rim minimum) | pad 1.10, phone 1.05, desktop 1.10 | 1.93, 1.07, 1.96 | 1.91, **1.04**, 1.93 |
| Kit foliage left out by sight, seeds 717 / 1 / 2 / 3 | under a tenth of the kit's foliage | 19 / 18 / 27 / 30 | 21 / 25 / 27 / 32 |
| Token gate (#679), Act I, seeds 717 and 1–3, phone and pad | 0 failed | 0 failed in 8 runs, worst margin 1.006–1.023 | **0 failed** in 8 runs, worst margin 1.006–1.025 |

- **Cover** falls where crowns gave way to stone: the outcrops, the cliff
  ledges at the rim, the walls and the gravestones stand where crowns stood,
  and the ruins' own cards are not counted. The pad's Journey now misses the
  45% line by 1.4 points, as Whole act already did on main. The
  orchestrator accepted this exception as the stone's cost on 9 Oct, at
  about 44.1% (pad Journey) and 41.8% (phone Journey) on an earlier lane
  head, and re-confirmed it the same day at 43.6% and 42.8% after seeing the
  side-by-side sheets. R3.6 is to re-measure the cover against the target
  with the stone in place. Seen on
  the side-by-side sheets (Journey and Close, pad and phone, seeds 717 and
  1–3), nowhere reads barren where crowns gave way to stone: the stone stands
  in a wood as dense as main's, and the roads, the waystones and their touch
  squares stay clear.
- **Red share at the pad's Journey** comes inside its band, 16.1% against
  16.3%, which closes R3.1 b's open residual of that view (16.7%): some of
  the crimson crowns there gave way to grey stone.
- **The pins' tripwire on the phone** moves from 1.07 to 1.04, a hundredth
  under its re-baseline of 1.05. The orchestrator accepted this as a named
  move of the tripwire. The token is at (266, 113) on R2's mount
  ([`mac/pin-diagnosis.txt`](mac/pin-diagnosis.txt); [8× crop of main, the
  branch and their difference](frames/pin-phone-weakest-8x.png)).
  - Nothing inside the drawn token changed: 0 pixels within 16 px of its
    centre.
  - The probe gives the token's pane radius as 28 px, but the drawn token
    ends at about 16 px. So the method's "rim" band (23–27 px) and most of
    its "disc" band lie on the land outside the token. Since #679, the
    method compares land with land.
  - What moved is the land round the token: a crimson crown re-flowed to
    its left, and the floor beside it changed.
  - Across the lane's heads the figure read 1.02, 1.05 and 1.04. At the
    first of those heads the weakest token was another, at (455, 285): the
    gateway's companion bank, moved off the river, replaced a dark crimson
    crown in its ring.
  - The token gate, the legibility authority since #679, passes with the
    same margins.
  - Retiring R2's method for #679's tokens is proposed as a follow-up on
    #660.

**What R3.3 places** ([`mac/placements.txt`](mac/placements.txt)):

| Seed | Cliff pieces | Outcrops (tor, bank, ridge, shard, boulder) | Stone triangles | Gravestones | Walls | Rubble |
|---|---|---|---|---|---|---|
| 717 | 26 | 23 (3, 7, 2, 3, 8) | 52,866 | 23 | 4 | 15 |
| 1 | 36 | 29 (1, 7, 7, 3, 11) | 69,178 | 18 | 4 | 13 |
| 2 | 32 | 23 (2, 7, 3, 3, 8) | 59,060 | 21 | 4 | 15 |
| 3 | 32 | 16 (2, 2, 4, 3, 5) | 51,338 | 26 | 4 | 9 |

## Gates

### iPad 8

**Pending: iPad batch (keychain).** The QA builds need the login keychain to
sign, and it was locked from 03:09 on 9 Oct. This section will hold:

- batch S1: main against the branch, interleaved, two installs each, with
  every launch listed and every outlier named, and three short Journey
  launches an install for video memory (six a build, every launch's
  readings listed; the gate is R3.2's Journey-hold VRAM within +20 MiB of
  main on the pooled median). It covers R3.2's gates still holding:
  - the floor fragment;
  - the bake ≤ 0.4 s with no frame over 100 ms;
  - the live shadow ≤ 15k primitives;
  - VRAM;
  - the cold open, the warmed open and reopens;
  - rest at vsync with 0 missed frames;
- batch S2's Metal System Traces of the branch at Journey: as it is, without
  the stone (`--trace-kill=stone`) and without the ground. They give the
  hero meshes' cost at the reference clock (gate ≤ 1.0 ms) and the floor's;
- batch T1: the fresh-install title path by the nonce method. Fresh-install
  builds give never-used nonces to the five floor shaders and
  `stone.gdshader` on the branch, and to main's five floor shaders. Each is
  launched fresh and then cached, and frame 0 is reported against main's.

### Mac measurements

These were taken on the M1 Max with the map probe (`tools/map_trace/probe.gd`):

- the A12 Metal condition, lean, pad, seed 1, two steps in;
- 120-frame holds;
- main `711302a5` against the branch's code-final runtime, five interleaved
  pairs ([`mac/probe.txt`](mac/probe.txt)). The geometry was the same in
  every run.

The geometry is the device's: it is the same land and the same lean profile.

| View | Stage, main | Stage, branch | Live shadow, main | Live shadow, branch |
|---|---|---|---|---|
| Journey | 56,430 primitives, 79 draws | **86,882**, 78 | 5,031, 8 | 4,118, 2 |
| River | 54,718, 68 | 98,376, 68 | 3,758, 5 | 3,108, 1 |
| Close | 44,010, 58 | 74,400, 57 | 4,706, 6 | 4,118, 2 |
| Whole act | 109,134, 220 | 173,292, 214 | 5,928, 14 | 4,118, 2 |

- **Stage ≤ 130k primitives at the Journey view** (the plan's gate): 86,882.
  Draws stay within the plan's 95 there (78). Whole act is inside its 200k
  primitives. Its draws were over the plan's 150 on main already (220), and
  fall by six.
- **The stone itself**: 51–69k triangles a land at seeds 717 and 1–3
  ([`mac/placements.txt`](mac/placements.txt)), in 6–7 draws. At seed 717: 49 pieces,
  52,866 triangles, 47,932 vertices. At seed 1: 65 pieces, 69,178
  triangles. That is about 2.5 MiB of vertex and index buffers.
- **Video memory** (Metal's allocation, the Journey hold): main reads
  236.6 MiB in all five runs. The branch reads 251.2 in three runs
  (**+14.6 MiB**) and 259.2 in two (**+22.6 MiB**); every later branch run
  read the higher figure. The step between them is exactly 8.0 MiB. The
  delta has two parts ([`mac/vram-hunt.txt`](mac/vram-hunt.txt)):
  1. **Ours**, which Godot's own accounting holds: textures +5.0 MiB and
     buffers +2.0. Loaded one at a time on the Mac (S3TC), the stone's
     atlas costs 2.0 MiB, its normals 1.0, the strata 0.2, and the woodland
     atlas's growth 1.2; the merged stone's buffers are 1.9–2.5 MiB a land.
     That is about 7 MiB against the plan's 18 MiB line for hero meshes and
     textures (the atlas's growth belongs to the impostor atlases' 16).
     `LandStone`'s pieces, held arrays and material are statics that live
     for the process, as the woodland atlas does; only the per-land merged
     meshes go with their land.
  2. **The engine's transfer staging**, which Godot does not account:
     **+8 or +16 MiB**, held for the process. A RenderingDevice transfer
     worker's staging buffer grows to the next power of two above the
     largest single upload it has made and is never shrunk
     (Godot 4.7's `servers/rendering/rendering_device.cpp`, lines
     7221–7244; measured with plain uploads by `tools/staging_rule.gd.txt`). The woodland atlas's
     colour, grown to 2048×1776 by the ruins' 37 tiles, is 4.63 MiB with its
     mips (S3TC here, ETC2 on iOS, the same size). It is the only texture in
     the game over 4 MiB; main's is 3.67 MiB. Loaded alone, it costs
     +20.8 MiB, of which +16.0 is untracked; main's costs +3.9, none of it
     untracked (`tools/tex_cost.gd.txt`). Whether one or two loader threads'
     workers end up holding the larger buffer is decided by the timing of
     the threaded loads behind the launch screen. That is the 8 MiB step:
     it is set before the first frame and never moves, so it is not a
     transient caught by the measurement.

  The gate grades the total: R3.2's Journey-hold VRAM within +20 MiB of
  main, on the iPad's pooled median ([Gates](#gates)).
- **The land's build** (headless, seed 1, nine builds each, interleaved,
  medians, load 11–12; [`mac/land-time.txt`](mac/land-time.txt)):
  - the kit: 322 ms on main, 376 on the branch (+54);
  - the woodland: 99 and 92 (−7, because the planting reuses the kit's
    sight grid);
  - net: **+47 ms**.

  The stone's stages:
  - the island search, 8.9 ms;
  - the islands' groups, 26.1 (including the sight grid's 7.1);
  - the walls, 1.1;
  - the verge rows, 1.3;
  - the shrines' graves, 2.8;
  - the merge, 8.9.

  The kit asks 8,624 clearance questions against main's 6,984 (117 ms
  against 88).
- **Opens** (medians of the four clean pairs, load 7–12):
  - cold: 1,763.8 ms against 1,707.7 (+56);
  - warmed: 58.7 against 54.9;
  - reopen: 13.3–14.9 against 13.3–15.5.

  The device's opens are under [Gates](#gates).
- **Payload** (`tools/payload_report.py`, iOS; [`mac/payload.txt`](mac/payload.txt)):
  the pck estimate goes from 277.2 to 282.1 MiB, **+4.86 MiB** (the plan's
  gate: +10 MB).
  - The map-journey group gains 4.83 MiB (the stone's art and the woodland
    atlas's growth). Its budget is raised from 12 to 17 MiB, as R3.2 raised
    it for its own art.
  - The presentation group gains 42 KB (the stone's scripts and shaders).
    Its budget is raised from 3.2 to 3.3 MiB.

## Visual proof and conditions

- **The A12 condition**
  (`GODOT_MTL_DISABLE_ARGUMENT_BUFFERS=1 --rendering-driver metal --rendering-method mobile`),
  at pad, phone and desktop, en and zh-Hant lean and en full: **no "Error
  compiling shader"**, no script error and no other error, on main and the
  branch ([`mac/a12-and-reduce-motion.txt`](mac/a12-and-reduce-motion.txt)).
  The token gate's stop captures, Act I, every seed and shape: none either.
  Acts II–IV show main's own 10 lines a run on both builds (`map_mineral`'s
  sampler 17). `stone.gdshader` binds three samplers, none anisotropic.
- **Reduce Motion** at Close, two frames 1.5 s apart:
  - With it on, 12,801 pixels change on the branch and 10,288 on main.
    **Every one of them is the river's water**
    ([frame](frames/reduce-motion-close.png), in magenta, main on the left).
    The branch shows more water there because main's bank stood over the
    river.
  - With it off, 115,904 change on the branch and 116,513 on main.
  - The stone has no vertex stage and reads no time, and the ruins' cards
    never sway (`test_map_stone`).
- **The token gate** (`tools/map_token_gate.gd`): **0 failed** in every run.
  Act I at the head, seeds 717 and 1–3, phone and pad: worst margins
  1.006–1.025 against main's 1.006–1.023. Acts II–IV, seeds 1–3, at the
  earlier head `99a23e3c`: margins the same as main's
  ([`mac/token-gate.txt`](mac/token-gate.txt)).
- **The floor's GPU proof** (`tools/check_floor_bake.gd`) passes under the
  A12 condition with the stone casting into the bake
  ([`mac/floor-bake-check.txt`](mac/floor-bake-check.txt)).
- **Mutation proof**: 27 of 27 mutations of `test_map_stone`'s
  subject were caught ([`mac/mutations.txt`](mac/mutations.txt)). Earlier
  runs' survivors each led to a stricter check:
  - all gravestones gone, and rocks over the water: the rocks are now
    checked off the water at four seeds, and gravestones beyond the islands
    and beside the shrines;
  - cliffs by the waystones, once the pieces moved: the cliffs are now
    checked at all four seeds;
  - ruins that hide what stands behind them, and ruins placed blind to the
    woodland's sight: these were caught only by the count of ruins drawn.
    The test now asserts it directly on the land as placed: no road
    (sampled every 0.5 m), waystone or token behind a ruin's silhouette, and
    no shrine, gateway, rock or standing ruin placed behind an earlier ruin's
    card. Each mutation now fails on that assertion first.
- **Determinism**, committed: `test_map_stone` builds seed 717's land twice
  and checks that a digest of every kit placement, stone piece and woodland
  card is the same. An unseeded `randf_range` in the islands' rock yaw fails
  it.
- **The kit reproduces**: a re-run of `build_stone.py` gives every shipped
  and source file byte for byte, except the `.blend` masters. The impostor
  re-bake is the same run to run. `prepare_stone.py` and `prepare_floor.py`
  give their files byte for byte.

## Core gate

Run once on the final code and tests (`4fa0cee8`), at `d03e5c35`, which adds only docs, on `711302a5`. Mac, 9 Oct, 05:39–06:16, each step waiting for load under 50 ([`mac/core-gate.txt`](mac/core-gate.txt)). It covers the core gate and every check `tools/ci_scope.py` selects for the PR's diff (223 paths).

| Command | Exit | Last verdict line |
|---|---|---|
| `godot --version` | 0 | 4.7.2.stable.official.ed1daf0bf |
| `tools/check_imports.sh` | 0 | asset import OK |
| `tools/check_scripts.sh` | 0 | scripts OK (497 checked) |
| `godot --headless -s res://tests/run_all.gd` | 0 | PASS (157 tests) |
| `python3 -B tests/test_ci_scope.py` | 0 | OK |
| `python3 tools/check_store_dev_exclusion.py` | 0 | store-dev-exclusion OK |
| `tools/test_check_store_dev_exclusion.sh` | 0 | check_store_dev_exclusion regression tests OK (12 cases) |
| `python3 -B tools/check_export_paths.py --self-test` | 0 | export-paths self-test OK (10 cases) |
| `python3 -B tools/check_export_paths.py` | 0 | export-paths OK |
| `godot --headless -s res://tests/run_all.gd -- --tests=res://tests/test_release_identity.gd,res://tests/test_sentry_release.gd` | 0 | PASS (2 tests) |
| `python3 -B tools/check_anchors.py` | 0 | anchors OK |
| `python3 -B tools/check_benchmark_freeze.py` | 0 | benchmark citations frozen (592 in 52 file(s)) |
| `python3 -B tools/build_site.py --self-test` | 0 | site self-test OK (20 seeded defects rejected; samples rendered exactly) |
| `python3 -B tools/build_site.py --check` | 0 | site is current: 7 files |
| `python3 -B tools/check_map_assets.py --self-test` | 0 | self-test OK (all injected gates failed; GPU silhouette uses _silhouette_noise) |
| `python3 -B tools/land_map_glb.py --self-test` | 0 | self-test OK (default land writes no provenance; accept is provenance-only) |
| `python3 -B tools/check_map_assets.py` | 0 | map assets OK (48 payload files; runtime landscape and retained asset library) |
| `python3 -B tools/check_map_quality_v2.py --self-test` | 0 | self-test OK (12 fail-closed mutation fixtures) |
| `python3 -B tools/check_map_quality_v2.py` | 0 | map quality v2 OK schema=1 contract=2.0.0 hard=18 soft=12 provisional=25 digest=4b54927afa7459be4b8b1bedc88fd8 |
| `python3 -B tests/test_performance_budget.py` | 0 | OK |
| `godot --headless -s res://tools/probe_map_seeds.gd -- --seeds=20` | 0 | map profiles OK (4 acts, 125978 candidate transforms; complete-layout proof is separate) |
| `godot --headless -s res://tests/choice_scroll_reachability.gd` | 0 | PASS choice scroll reachability (844x390) |
| `godot --headless -s res://tests/boss_relic_choice_containment.gd` | 0 | PASS boss relic choice containment (1180x820 en+zh-Hant) |
| `godot --headless -s res://tests/dawn_phone_containment.gd` | 0 | PASS dawn containment (en + zh-Hant, pad-landscape) |
| `godot --headless -s res://tests/measure_hud_location.gd` | 0 | MEASURE OK (0 clipped) |
| `godot --headless -s res://tests/event_phone_containment.gd` | 0 | PASS event containment (2024 rects, en + zh-Hant, 11 events, 3 shapes) |
| `python3 tools/payload_report.py` | 0 | TOTAL (pck estimate)                  282.1      400  ok |
| `python3 tools/ci_scope.py --changed-paths-nul <lane>/changed.nul --changed-gdscript-nul <lane>/changed-gd.nul --repository-root .` | 0 | every selected check is a row above |

28 of 28 steps exit 0.

The same gate ran earlier at `abde6da0` (the code commit's runtime, before the test commit): 28 of 28 steps exit 0, `PASS (157 tests)`.

## Judgement calls

1. **The stone casts into the bake, not live** (settled by the orchestrator,
   5 Oct). R3.2 kept its slate outcrops as live casters. Their replacements
   are not, for two reasons:
   - the stone is 51–69k triangles a land (48–65 pieces at seeds 717 and
     1–3), which the live shadow pass's 15k primitives cannot hold;
   - the key light is static, so the baked normals and occlusion carry the
     stone's own form.

   Their shadows on the ground are in the floor's bake, with contact
   occlusion at each outcrop's foot. What is lost is a rock's shadow on the
   water and on another rock, which the floor does not hold: main's big bank
   by the river at seed 1 threw its shadow on the water; the branch's does
   not. At Close the outcrops do not read flat. Their baked normals and
   occlusion, moss caps and cracks give them form under the key, and the
   floor holds a contact shade at each foot ([outcrops](frames/crop-outcrops.jpg),
   [the tor](frames/crop-island.jpg)).
2. **One atlas and merged meshes.** All the hero stone shares one material,
   so it draws in a few draws, not a draw per kind per cell. The cost is one
   2048×1536 atlas, whose cells must be baked together.
3. **The ruins are cards.** They are re-baked into the woodland's atlas.
   They cost no draws and 1.25 MB, and they cast into the bake through their
   cards.
4. **Slate replaced in place.** The granite kinds keep the slate kinds'
   footprints, so the kit's composition, and the gateway's companions with
   it, stays close to R3.2's.
5. **Moss from the floor's own picture.** It adds no texture, and the stone's
   moss matches the ground's.
6. **A few tries, not a search.** The groups' placements try their mark and
   at most twelve spots round it; a verge row's stone tries its own spot
   only. The land is built on a worker the opening map waits for.
7. **The kit places ruins by the woodland's own sight rule** (above), so no
   ruin is placed and then left out, and the planting reuses the kit's grid.
8. **Gravestones either side of an island's rock, not before it**, and one
   beside a shrine, not a pair round it: in front, their cards would hide
   the rock or the shrine, and the woodland would leave them out.
9. **Rocks kept off the water.** Main's rule let a rock stand on the bank
   with its circle over the river (two to five a land). The branch keeps
   three quarters of each rock's radius off the water, which moves the
   gateway's companion bank at seed 1 back from the river.
10. **The woodland re-flows** (accepted by the orchestrator, 9 Oct; below).
11. **The stone's grade is the lane's**: `stone_tint` (0.8, 0.83, 0.88),
    `moss_tint` (1.15, 1.5, 0.6), the strata a third of the moss, the
    occlusion's share 0.75. The final balance against the north star belongs
    to R3.6's grade.

## For the owner: points to re-pick

Seen against the Act I target by the orchestrator on 9 Oct. Each is a lane
pick the owner may re-pick. None is tuned in this PR: R3.6 (light and grade)
is to revisit the stone's value against the target.

- **The stone's value and its moss.** The target's rocks are darker and more
  broken, and its moss a darker green. Ours are a paler grey with a bright
  olive-yellow cap: at Journey they are among the brightest things after the
  tokens.
- **The cliff tops at Close** read as striped tan ledges, where the target
  has dark broken rock.

## Open risks

1. **The land costs more to build on the worker**: the kit +54 ms and the
   woodland −7 ms on the Mac (+47 ms net, `mac/land-time.txt`). The cold
   open waits for it. The device's cold open is pending: iPad batch (keychain).
2. **Video memory** reads +14.6 or +22.6 MiB against main on the Mac, in
   two parts ([Mac measurements](#mac-measurements)):
   - ours, about 7 MiB (the stone's textures and buffers and the woodland
     atlas's tracked growth), inside the plan's 18 MiB hero line;
   - the engine's transfer staging, +8 or +16 MiB held for the process,
     because the woodland atlas's colour (4.63 MiB with mips, grown by the
     ruins' tiles) is now the only texture in the game over 4 MiB.

   The device's reading is pending: iPad batch (keychain). If the iPad's pooled median is over +20 MiB, splitting
   the atlas comes into scope before merge. The follow-up either way: keep
   every texture upload at or under 4 MiB. The engine sizes the staging per
   layer: in Godot 4.7's `servers/rendering/rendering_device.cpp`,
   `texture_create` initialises each array layer on its own (lines
   1755–1757), and `_texture_initialize` sizes one layer's whole mip chain
   (lines 2124–2125) before acquiring the worker (line 2147). So a two-layer `Texture2DArray` of 2048×888 pages, about
   2.3 MiB each, would stay inside the 4 MiB staging buffer with the
   impostor shader's sampler count unchanged (it binds two). A check that
   fails when any shipped texture's upload exceeds 4 MiB belongs with that
   follow-up.
3. **The woodland re-flowed** (accepted by the orchestrator). Canopy cover
   at the pad's Journey now misses the 45% line by 1.4 points, as Whole act
   already did on main. This is accepted as the stone's cost; R3.6 is to
   re-measure the cover against the target with the stone in place.
4. **R2's pin tripwire on the phone** reads 1.04, a hundredth under its
   re-baseline of 1.05 (main 1.07), accepted by the orchestrator as a named
   move. The cause is land the method samples outside the token. The token
   gate, the legibility authority since #679, passes with the same margins.
5. **The stone's shadows are in the floor only**: no rock shades the water or
   another rock.
6. **The art is a set of lane picks**: the granite and strata pictures (one
   candidate each), the kit's sculpts and the stone's grade.
7. **Pre-existing, not this branch's**:
   - main's `map_mineral` A12 shader lines in Acts II–IV;
   - the exit-time "resources still in use" and RID-leak lines;
   - water that moves under Reduce Motion;
   - the export presets "Web Dev", "iOS Dev Review" and "Android Dev Review"
     (presets 0, 4 and 5) filter only `port_fixtures/*`. So a Dev Review or
     Web Dev build carries the stone kit's imported GLBs and ruin pictures
     under `tools/map_atelier/`, about 3.1 MiB as imported. The `.blend`
     masters and the source pictures sit under `.gdignore` and never
     import. The store presets (macOS, iOS, Android) and the QA app
     (`qa_export.sh`, on the iOS preset) exclude `tools/map_*`.

## Files

- `mac/`: the woodland and its gates, the pin diagnosis, the token gate, the
  A12 condition and Reduce Motion, the floor's GPU proof, the probe's
  geometry and opens, the land's build times, the placements, the payload,
  the mutations and the core gate.
- `device/`: the batches' logs, summaries and rows ([Gates](#gates));
  pending: iPad batch (keychain).
- `frames/`: the sheets, the crops, the pieces and cards, the conditions,
  the pin crops, and the iPad 8 screenshot (pending: iPad batch
  (keychain)).
- `tools/`: the lane's scratch harnesses, never part of the game, as `.txt`.
  They include R3.1 b's and R3.2's own tools where they were reused (the
  cover count's `look.gd`, its `magenta.gdshader`, R2's pin mount `look4n.gd`
  with a listing added) and the woodland's `wood_dump.gd` and
  `wood_compare.py`.

### Safety

- Nothing was deleted on the iPad or on the Mac outside the lane's scratch
  folder (`.claude/worktrees/map-lane`) and its worktrees.
- A fresh install was simulated only by the nonce method; no cache was
  cleared.
- The QA app was the only app installed or launched, under the shared lock.
- The removals the lane's tools make are all inside its scratch folder, and
  each tool prints the folder it cleans before it runs:
  - the device helper (`tools/map_trace/device.zsh`) removes each launch's
    stale row and launch files and any cut-short trace, inside the batch's
    folder;
  - `qa_export.sh` clears the measuring worktree's `build/ios-qa`.
- One slip: a file list (7 KB) was written to `/tmp/r33files.txt` on 9 Oct
  at 01:52. The orchestrator checked it and removed it.
