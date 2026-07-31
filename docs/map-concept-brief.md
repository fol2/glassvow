# M6 — Horizontal World Map: concept brief

> **SUPERSEDED IN PART (2026-07-24).** The "all procedural, no raster assets"
> premise below is **withdrawn**. The visual standard for this port is now
> `roguecardv2@6e069118` (the pre-Pixi build; local branch `pre-pixi`) — a
> raster-art game carried by `src/assets/` (243 images at that commit).
> Glassvow currently ships **zero** art assets and draws everything in `_draw()`;
> closing that gap is the active work. §1 (Pilgrimage frame) and §4 (slice data)
> are unaffected and still stand. Treat every "procedural" / "buildable" note
> below as describing the *old* plan, not the target.

Founding artifact for the map redesign. **Sign this before any map code is written.**
The web map is a vertical 3D tower (a helix of lanterns climbed upward). The port
replaces it with a horizontally traversed *glassvow world* — a parallax glass
landscape scrolled left-to-right, nodes selected on a path. **Game and battle
systems are unchanged**; only map presentation + generation are new. Everything
below extends the M5 night-glass style (`presentation/combat/glass_style.gd`):
indigo night gradients, glass-blue `#8fd0ff`, ember `#ff9a4d`, faceted-crystal
forms, all procedural (no raster assets — that is a later gate decision).

---

## 1. The journey — what the horizontal traverse *is*

**Recommendation: the Pilgrimage.** The run is a pilgrimage *across* the glass
world toward the distant Spire. You walk left-to-right through three regions of a
ruined stained-glass land; **the Spire stands on the horizon and grows larger
each act** — small and pale behind the Ashen Woods, half-risen over the Sunken
City, filling the whole sky in Act 3 until you arrive at its threshold. The tower
is still "the Spire"; you are not climbing it yet, you are *reaching* it.

Why this wins: horizontal motion reads natively as travel-across-land, not as a
tower on its side. The horizon-Spire gives the run a single constant goal-anchor
that doubles as an at-a-glance act meter (bigger Spire = further along) and pays
off the strongest parallax layer for free — the far silhouette that barely moves.
It reframes the vertical climb without fighting it: the *climb* is Act 4 / the
summit, off-screen beyond this journey, so nothing about the Spire's identity is
spent. It keeps each node a discrete waypoint, so node-type reading stays clean.

**Named alternative: the Toppled Procession** (the Spire laid on its side, a
rotated climb — you walk *up* it horizontally). Cheapest engineering (conceptually
rotate the existing helix 90°) and keeps "you are on the Spire" literal, but the
fiction is weak — nothing in the lore topples the tower, and a sideways climb
reads as a bug, not a pilgrimage. Rejected unless the horizon-Spire proves too
costly to render convincingly.

*(Not chosen: "run as panes of a great window" — beautiful, but it over-commits
the Rose Window / Emberglass quest lore, which is a specific in-game chain, not
the whole run, and makes every node a pane, muddying node-type legibility.)*

**Decision requested:** approve the Pilgrimage as the fictional frame. Everything
downstream (regions, horizon, weather, marker) is built to serve it.

---

## 2. Reading the map — the node language

Eight frozen type keys, plus the `unlit` flag. Keys never change; the visual
vocabulary below is all reinvention. Each node is a **waystone**: a small faceted
`GlassGem`-style emblem seated on a leaded pane on the path band, its rim kindled
(ember-lit) when reachable, dim glass when not.

- **`monster`** — a single small pale-glass gem in the enemy's hue; the plain step.
- **`elite`** — a larger, harder-cut gem, ember-charged from within, wearing a
  three-spike crown silhouette (the affix); brighter glow, faint heat-shimmer.
- **`event`** — a shrouded pane: an unlit-blue swirl behind frosted glass with a
  single rune, deliberately unreadable — you know it's *something*, not *what*.
- **`rest`** — a warm ember bonfire in a lantern-cage; the only node that glows
  amber at rest, a held breath of light on the dark path.
- **`shop`** — a merchant's glass stall, a hung lantern and a glint of stacked
  coin-discs; ember-gold accent.
- **`treasure`** — a sealed reliquary: a small leaded chest with a gold seam of
  light leaking from the lid crack.
- **`boss`** — not a waystone but the region *terminus*: a towering rose-window
  silhouette straddling the path, spokes of leaded light, scaled far larger than
  any node (see §3).
- **`monument`** — a carved standing memorial-stone in cold Vigil-blue (ties the
  meta-progression's monuments/bequests into the world); still, unlit, patient.
- **`unlit` flag** (on any node above) — the emblem is replaced by a **dark
  unkindled lantern**: silhouette only, type hidden. Selecting shows a bounty
  cost; pay it and the lantern *kindles* — the true node emblem blooms into view.
  One reusable dark-lantern marker + a reveal animation covers every unlit type.

**Buildable:** this is nine `_draw` routines (seven waystone emblems + the boss
rose-window + the dark lantern) + one shared kindled/dim rim
state, all extending the existing `glass_gem.gd` / `glass_style.gd` idiom.

---

## 3. The three acts as regions

Each act is a horizontal region with its own horizon silhouette, palette tint over
the shared night gradient, and weather. The **boss terminates the region**: the
path runs *into* it, the camera can go no further, and clearing it wipes to the
next region's opening.

- **Act 1 — The Ashen Woods** (boss **Rootheart**; accent green `#7ddb8f`, ember
  `#ff9a4d`). *Horizon:* charred glass-tree silhouettes, the Spire small and pale
  far behind them. *Palette:* night indigo warmed with green facet-light in the
  midground, ember embers near. *Weather:* fine ash sifting down across all layers.
  *Terminus:* the path chokes into a great root-clotted glass hollow — Rootheart is
  the gate; its rose-window is knotted with roots.

- **Act 2 — The Sunken City** (boss **Leviathan**; drowned sinking light).
  *Horizon:* half-submerged glass towers, the Spire risen to mid-height, its base
  in water. *Palette:* colder, dimmer — teal/cyan caustic shafts sinking through
  the bands, glass-blue dominant, ember reduced to drowned coals. *Weather:*
  descending light and slow-rising motes (caustics drift, the world sinks).
  *Terminus:* the path steps *down* into flooded depths; Leviathan surfaces as the
  terminus rose-window, spokes rippling like water.

- **Act 3 — The Obsidian Spire** (boss **the Sovereign**, id `sovereign` — its
  rose-window is the Spire's threshold-gate; storm embers,
  silent heat lightning). *Horizon:* the Spire now *fills the sky* — black glass,
  no longer distant. *Palette:* deep violet-black, ember streaks torn sideways by
  wind, highest contrast. *Weather:* storm embers streaking past between silent
  flashes of heat lightning that light the whole world for a frame. *Terminus:*
  you arrive *at* the Spire — the region ends at its obsidian threshold-gate, the
  final rose-window bloom.

**Buildable:** three tint palettes + three horizon silhouette sets + three weather
particle configs, driven off act index; the boss terminus is one scaled rose-window
`_draw` re-tinted per act.

---

## 4. The slice segment (concrete data sketch)

M6 builds **one hand-authored strip** covering the existing M5 encounter ladder.
No events/shops/treasure (content not ported). Linear, no branching yet. Author
this straight into a JSON/GDScript literal:

```
region: "ashen_woods"   # Act 1 tint + falling ash
nodes:
  n0  type=monster  enemies=["sporeling","sporeling"]  world_x=0
  n1  type=monster  enemies=["duskfang"]                world_x=1
  n2  type=monster  enemies=["waylayer"]                world_x=2
  n3  type=rest     enemies=[]                           world_x=3
  n4  type=elite    enemies=["gravewarden"]  affix=null  world_x=4
edges: [n0->n1, n1->n2, n2->n3, n3->n4]
start: n0     # lantern marker seats here on entry
```

Notes for the author: `enemies` are content ids the CombatScreen ladder already
consumes (the M5 `main.gd` sequence). `affix=null` in the slice — the elite trace
passes its affix explicitly, so the slice matches the trace by leaving it unset
until the trace value is wired. `world_x` is an ordinal the camera maps to stage
px; spacing is a screen-tuning constant, not data.

**Buildable:** this literal + a `MapNode` struct (`type`, `enemies`, `world_x`,
`unlit`, `affix`) + an `edges` adjacency list is the entire M6 data model.

---

## 5. Screen & motion

**Parallax bands (far → near), scroll factor relative to camera pan:**

1. **skyband** — night gradient + horizon Spire silhouette; **0.10** (barely moves;
   the Spire feels distant and fixed).
2. **region** — act silhouettes (trees / drowned towers / obsidian mass); **0.35**.
3. **path** — the ground line, the leaded path, the node waystones + lantern marker;
   **1.0** (the play plane — nodes live here, in world-x).
4. **veil** — near weather (ash / caustics / storm embers) drifting across; **1.35**
   (parallax overshoot, sells depth).

**Node markers & affordance:** waystones sit on the path band at their `world_x`.
Reachable nodes (adjacent to the marker's node via `edges`) show a kindled ember
rim + gentle pulse; unreachable nodes are dim glass, non-interactive. Hover/press
raises a node's glow (mouse) or shows its label chip (touch).

**Marker travel:** on select, the **lantern marker glides horizontally along the
path** to the target node (eased, ~0.4s), the camera panning to keep it in the
lead-third of the frame. Arrival → a **band-of-light wipe** hands off to the
CombatScreen (reusing the M5 scene-transition key). Return from combat re-seats
the marker on the cleared node and re-evaluates reachability.

**Both stage shapes** (fixed virtual stage, uniform scale, layout in stage px):

- **Phone-portrait:** path runs in the lower third; camera frames ~2–3 nodes;
  parallax bands stack to fill height; markers sized up for thumb-reach; horizon
  Spire sits high and small.
- **Pad-landscape:** path mid-low; camera frames ~4–5 nodes; wider horizon lets
  the Spire read larger and the region silhouettes spread; same world-x data,
  wider camera window.

**Buildable:** four `TextureRect`/`_draw` bands parented under a camera-x node,
each multiplying pan by its factor; one marker tween; reachability = a set lookup
over `edges`. No new transition tech — reuse the combat wipe.

---

## 6. Deferred (out of M6 scope)

- **Map generation** — the slice is hand-authored. The full generator (branching
  paths, ~15-row acts like the web, weighted node-type pools, unlit placement,
  boss-per-act) is a later milestone. The concept only needs to *leave room*: the
  `MapNode`/`edges` model above already expresses branching (multiple out-edges)
  and arbitrary length — nothing here forecloses it.
- **Events / shops / treasure content** — node *types* are designed above but the
  underlying encounters aren't ported; the slice omits them.
- ~~**Raster art** — everything is procedural night-glass for now. Whether the map
  ever takes painted horizons/props is a separate asset-strategy gate, unchanged
  by this brief.~~ **Withdrawn 2026-07-24.** The gate was decided: the port aligns
  to `roguecardv2@6e069118`, which is raster throughout. Painted assets are the
  target, not an open question. Known blocker: the map's four parallax bands are
  one `_draw()` pass on a single Control (`world_map_screen.gd:429` (`_draw`)), and Godot
  renders children above a parent's `_draw()` — so bands must become `Node2D`
  children with `z_index` before sprites can interleave with waystones. The old
  marker-offset workaround is already gone: `_draw_marker()` now uses the
  waystone position directly (`world_map_screen.gd:502-507` (in `_draw_marker`)).

---

*Approve §1 (the Pilgrimage frame) and §4 (the slice data) to unblock M6 map code.*

---

## Addendum — what actually happened (2026-07-24)

Recorded because the order of events matters to anyone reading this later.

1. M6a map code (`presentation/map/`, commit `942f0a3`) was written and merged
   **before** the §1/§4 sign-off this document asks for. It is functional and
   staying (its camera, travel tween, reachability wiring and input are sound —
   roughly 60% of those two files is art-independent); only the `_draw*` layer
   is superseded.
2. The user reviewed the running builds and confirmed **`roguecardv2@6e069118`
   (pre-Pixi)** as the visual to align to. Reachable locally via branch
   `pre-pixi`; a worktree sits at `../roguecardv2-prepixi`.
3. The `main` branch of roguecardv2 is a *regression* from that reference (the
   card layer most visibly). Tracking down which commit caused it is open work,
   independent of the port.

**Open, not yet decided:** whether audio ships too (`src/assets/musics`, `sfx`
exist at the reference and Glassvow has neither), and how 243 source images map
onto Godot import settings. Nothing has been imported yet.
