class_name EnemyView
extends Control
## One enemy as an ACTOR, not a placard: the painted creature standing at its
## own size, chrome hanging free above and below it, and — when it breaks — real
## glass.
##
## The contract this view keeps (benchmark: roguecardv2 src/ui/combat.js:600,
## styles.css:757) is that **this Control's rect IS the art box, and its bottom
## edge IS the creature's feet**. Nothing is drawn inside a panel. Sizing is the
## benchmark's own `tierSizes[tier] * scale`, read from
## assets/art/enemies/char-meta.json — 115px (sporeling) to 1120px (leviathan).
##
## THE GLASS IS ACTUALLY 3D. The body is a lit quad inside a SubViewport with
## its own World3D — the same trick card_view.gd uses for card stock — and the
## cracks are real extruded Voronoi shards with a refracting, clearcoated glass
## material, lit by real lights against a real sky. On death the vessel is
## swapped, in ONE frame, for pieces of ITSELF — opaque shards each carrying the
## patch of painting it covered — which tumble under real gravity, cool, and
## crumble to embers. The web benchmark had to fake every one of those: it
## hand-rolled ballistics in JS, baked crack normals to a 192px canvas, and
## needed an opaque back-buffer pass to get transmission at all. Here the engine
## does it. Both architectures, what this port did not carry across, and the open
## question about the STANDING crack web are in docs/glass-crack-rendering.md.
##
## Renders from explicit sync calls / event fields — never reads combat state
## directly (the sequencer contract). Targeting is drop-based (the hand's drag
## machine hit-tests get_global_rect(), which is why the rect is the art box).

## Foes and heroes are the same animal — a painting standing at its own size on
## the ground line — so one actor serves both and the art id decides the folder.
const ART_DIRS: Array[String] = [
	"res://assets/art/enemies/%s.png", "res://assets/art/heroes/%s.png",
]
const META_PATH: String = "res://assets/art/enemies/char-meta.json"
const WARD_ICON: Texture2D = preload("res://assets/art/ui/ward.png")
## `.hpbar > .ghost` — `rgba(255, 230, 160, .55)`, screened over the rail, with
## `transition: width 0.9s ease 0.25s`. The delay is the whole point: the trail
## has to sit still long enough to be read as the damage that was just done.
## `.pv` — the loss an armed card would take out of this rail.
const PREVIEW_WARM: Color = Color(1.0, 0.9411765, 0.84705883, 0.9)
## `pvPulse 0.9s ease-in-out infinite` with `50% { opacity: 0.4 }`.
const PREVIEW_PULSE: float = 0.9
const PREVIEW_DIP: float = 0.4
const GHOST_WARM: Color = Color(1.0, 0.90196079, 0.627451, 0.55)
const GHOST_HOLD: float = 0.25
const GHOST_FALL: float = 0.9

## Chrome geometry (benchmark styles.css: .hpbar-wrap width 150, .cplate gap 6,
## .top-chrome bottom calc(100% + 8px)).
const PLATE_W: float = 150.0
## `.hpbar` (styles.css:833) — the rule that actually paints. The stylesheet
## carries a second one at :825 for a bezelled rail; it is keyed on
## `:has(.hp-vial-frame)` and no such element exists at run time, so its radius
## 2, its 0.35 track and its 4px side margin never apply to anything. This port
## had all three.
const RAIL_H: float = 9.0
const RAIL_RADIUS: int = 5
const RAIL_TRACK: Color = Color(0.0, 0.0, 0.0, 0.55)
## `border: 1px solid var(--lead)`. The rule also carries
## `inset 0 0 0 1px rgba(255,255,255,.06)` — a 6% white hairline immediately
## inside the border. Not ported: a StyleBoxFlat has one border, and a second
## box stacked under a 9px rail to carry six percent of white is more machinery
## than the effect is worth. Recorded so nobody looks for it twice.
const RAIL_EDGE: Color = Color(0.019607844, 0.02745098, 0.05490196)   # #05070e
const RAIL_FROM: Color = Color(0.70980394, 0.16470589, 0.24313726)   # #b52a3e
const RAIL_TO: Color = Color(1.0, 0.41568628, 0.36862746)            # #ff6a5e
const VIAL_H: float = 14.0
## `.hp-label`
const HP_LABEL_W: float = 52.0
const HP_LABEL_PX: int = 12
const HP_LABEL_TINT: Color = Color(1.0, 0.7254902, 0.7254902)        # #ffb9b9
const PLATE_GAP: float = 8.0
const CROWN_GAP: float = 8.0
const WARD_ICON_PX: float = 20.0
## Both chrome boxes are given far more room than their rows need and then let
## their contents settle against the near edge — the crown hangs from its bottom,
## the plate sits on its top. The benchmark gets this for free from flex, which
## shrink-wraps; a Godot container has to be told a size, so the size is one that
## can never bind and `get_combined_minimum_size()` is what reports the real row.
const CHROME_BOX_H: float = 200.0

## 1 px of art box = 0.01 world units, so a 176px creature stands 1.76m tall and
## the physics engine's own gravity is already in the right ballpark.
const UNIT: float = 0.01
## Head-room around the box for shards to fly into before the viewport clips.
const PAD_FRAC: float = 0.38
const FOV_DEG: float = 28.0
## Glass plate thickness as a fraction of the box — thin, but NOT zero: thickness
## is what makes a shard catch a highlight on its edge and refract at all.
const GLASS_THICK: float = 0.035
## How many cracks one creature can ever carry. Owner's ruling, 2026-07-26: a
## crack is NOT one per hit, and a mob caps out well under ten. Landing on eight
## rather than five is arithmetic — the reference caps its own drawn cracks at the
## same number (`addCrack`: `layer.children.length < 8`), and eight cut lines part
## a body into roughly nine to sixteen pieces, which is where `_death_sites`'
## rings were already tuned and where the rite is already approved. Five would
## give about six, and `_death_sites` warns in the other direction: a piece must
## stay big enough to carry a readable patch of the painting.
##
## The cap is a BACKSTOP, not the mechanism. Once the fracture model lands
## (`docs/fracture-model.md`), a blow into already-relieved glass produces a crack
## that arrests immediately, so the count self-limits for a causal reason — the
## glass is already broken there — rather than because a counter filled up.
const MAX_SITES: int = 8

## `_voronoiParts` (src/vfx.js:236), in UV. Two crack sites closer than
## `SITE_MERGE` are one crack. The filler grid steps by `GRID_STEP`, is jittered by
## `GRID_JITTER` so it never reads as a lattice, and no filler point lands within
## `GRID_EXCLUDE` of a real crack — which is what keeps a blow's own fine cells
## from being diluted by the coarse background.
const SITE_MERGE: float = 0.02
const GRID_STEP: float = 0.21
const GRID_JITTER: float = 0.06
const GRID_EXCLUDE: float = 0.13
## Smallest debris cell, as a fraction of the plate. The reference culls at
## 0.3 of its 100×100 space, which is this number.
const CELL_MIN_AREA: float = 0.00003
const VP_MAX: int = 2048

## Being struck (benchmark `choreoHit` / `hurtFlash`). The displacement is the
## benchmark's own 9 px, in the actor's own pixels rather than as a fraction of the
## box — which means a sporeling is knocked 8% of its width sideways and a
## leviathan barely twitches. That began as a CSS convenience, but it reads as
## mass, so it is kept; scale it by the box if a giant ever needs to flinch harder.
const KICK_PX: float = 9.0
const SQUASH: float = 0.03            ## scale(.97, 1.03) at the peak
const HIT_TIME: float = 0.3           ## the whole recoil, cubic-bezier(.22,1,.36,1)
## `choreoHit`'s offsets and the magnitude at them. The peak sits at 0.25 rather
## than at 0, so a blow travels INTO the body before it recovers — but 0.25 is an
## offset in EASED progress, not a quarter of the clock. `cubic-bezier(.22,1,.36,1)`
## is steep enough at the start that eased progress passes 0.25 about 18 ms into
## the 300 ms (measured, not read off the curve's name). The impact is therefore
## near-instant and the remaining 94% of the duration is the recovery, which is
## what makes it read as a hit rather than as a push.
const HIT_AT: Array[float] = [0.0, 0.25, 1.0]
const HIT_V: Array[float] = [0.0, 1.0, 0.0]
const FLARE_RISE: float = 0.09        ## hurtFlash peaks at 30% of its 0.3s
## `meshFlash(el, 160)` (mesh.js:1030) — the layer below this one had missed.
##
## A struck creature in the benchmark is hit by THREE things, not one. The
## shader comment further down reasons carefully about `hurtFlash`, the CSS
## filter, and rejects three literal ports of it for good reasons. It never
## mentions this, and this is the one that whitens the body:
##
##     p.mat.uniforms.uFlash.value = 0.9;                        // mesh.js:1031
##     gl_FragColor = vec4(base.rgb + uFlash * a, ...);          // mesh.js:245
##
## A FLAT 0.9 added to every channel across the whole silhouette, masked only by
## the sprite's own alpha — indifferent to what is painted underneath, so a dark
## creature goes as white as a bright one. Hard on, hard off after 160ms: no
## ramp, because a `setTimeout` has none.
##
## That is why the flare alone never read as the benchmark's blow. The flare is
## keyed to the creature's painting and is right to be; this is not keyed to
## anything, and the two are meant to land together.
const HIT_WHITE: float = 0.9
const HIT_WHITE_HOLD: float = 0.16
## An incidental hit — poison, burn, thorns, self-damage — never gets the shove or
## the squash, only `hurtFlash`'s own smaller two-phase wobble: +7 px then -5 px,
## expressed against the 9 px kick so one constant governs the scale of all of it.
const NUDGE_OUT: float = 7.0 / KICK_PX
const NUDGE_BACK: float = -5.0 / KICK_PX

## `doomTremble 0.09s linear infinite` (styles.css:104) — a boss under the
## world-stop. Not the flinch: this is the vessel failing to hold still, a fast
## sub-pixel-ish rattle in the art's own px, and it runs on `linear` because a
## tremble that eases is a wobble. CSS y is screen-down and the vessel's is
## world-up, so the y track is negated where it is read.
## The ward is a CUT GEM HELD IN FRONT of the creature, and that is a deliberate
## departure from the benchmark rather than a port of it.
##
## What the port inherited was a shell whose facets were a **Voronoi second-nearest seam
## over 37 sites** — which is, primitive for primitive, the construction of the disc crack
## web `docs/glass-crack-rendering.md` §2.2 condemns and `CrackField` replaced. Two things
## that must read as opposites were built out of the same part, so a guarded creature and a
## damaged one spoke the same language. On the web there was no better option: a 192²
## canvas bake cannot cheaply carry authored facet geometry. Here there is a shader.
##
## So the shell becomes a stone: a **table** (the flat centre) ringed by a **crown** of few,
## large, hard-edged facets, each with a CONSTANT normal, alternating pitch, cut in as the
## ward forms. Nothing about it is a distance to a set of scattered points.
##
## Three further changes follow from *held in front* rather than *worn*:
##
## * It hangs off `_ward_root` under the stage, not off `_vessel`, so it does not inherit
##   the recoil SQUASH. `_vessel.scale` is the tell that mattered — a gem does not deform,
##   and a shield that squashes with the body it protects is made of the body. Position it
##   still follows, because a shield goes where its holder goes.
## * It stands proud in Z, so the perspective camera gives it real parallax against the
##   body when the stage shakes. The old shell shared the body's plane and was ordered in
##   front only by `render_priority`, which is not depth.
## * Its size comes from the box HEIGHT alone with the gem's own aspect, not from the
##   body's own width and height scaled up. A narrow creature got a narrow shield.
##
## And it is ORDERED. Nothing about the stone is hashed, jittered or seeded, which is a
## reversal of `reshuffleWardShape`'s whole intent — that generator existed to make "no two
## guards in a fight the same stone", and a raw uneven crystal is what it produced.
##
## The opposite is the right answer here, and it settles the same problem the cut does but
## at the level of meaning rather than of primitive. **A ward is manufactured and identical
## every time; a fracture is natural and never repeats.** Order against chaos is a contrast
## an eye reads instantly and without being taught, where "Voronoi cells of one size versus
## Voronoi cells of another" is not a contrast at all. Every ward in the game is the same
## regular stone because it is the same protection.
##
## `WARD_GROW`, `WARD_OPACITY`, `WARD_TINT` and `WARD_PULSE` are kept from `ward-params.js`
## — those are values somebody chose through the benchmark's `?vfxedit=1` panel, and the cut
## is what was wrong, not the timing or the colour.
const WARD_OPACITY: float = 0.4
const WARD_GROW: float = 0.56         ## growMs 560 — and the break is faster; see WARD_BREAK
const WARD_EDGE_SOFT: float = 0.01    ## all but a hard cut
const WARD_ROUGH: float = 0.0
const WARD_ENV: float = 0.72
const WARD_TINT: Color = Color(0.28627452, 0.5647059, 0.7490196)   # #4a90bf
## Re-gaining ward keeps the silhouette and re-cuts the FACETS: they collapse to
## 12% and are cut again. `growMs * 0.55`.
const WARD_PULSE: float = 0.56 * 0.55
const WARD_PULSE_TO: float = 0.12

## How many crown facets the stone is cut with.
##
## EIGHT, and both the count and its evenness are the argument. Thirty-seven Voronoi sites
## over a body-sized pane give cells a few percent of the pane across — finer than the eye
## resolves at any actor size, so it reads as texture, which is exactly how a crack web
## reads. Eight facets are each an eighth of the stone: individually legible, individually
## lit, and countable. **Even**, because the crown alternates two pitches and an odd ring
## puts two of the same next to each other where it closes — one seam in a machined object
## that does not match is the thing an eye finds first.
const WARD_CUT_N: int = 8
## Where the flat table ends, as a fraction of the outline's radius. The table is the part
## that goes dead and mirror-flat, and it has to be large enough to be a face rather than a
## hub — under about a third the stone reads as a rosette.
const WARD_TABLE_R: float = 0.42
## How far the stone stands in front of the body, in box heights. Small on purpose: the
## camera is perspective, so this also magnifies the stone by `dist / (dist - z)` — at 0.15
## of a box height against a camera 2.97 box heights out, that is 5 %, which is the amount
## an interposed object should grow rather than a size change anybody notices.
const WARD_LIFT: float = 0.15
## The stone's own size, in box heights, and its own aspect. Not the body's box scaled up.
const WARD_SIZE: float = 1.12
const WARD_ASPECT: float = 0.86
## How long the stone takes to come apart. Much shorter than the 560 ms it took to form, and
## deliberately so: a thing is built slowly and gives way at once.
const WARD_BREAK: float = 0.34
## How long an absorbed blow rings in the stone, and how far it drives it back in box
## heights. Shorter than the body's own 300 ms recoil: the shield answers first and is done
## before the creature has finished flinching, which is the order the two things happen in.
const WARD_RING: float = 0.20
const WARD_FLINCH: float = 0.055

const DOOM_PERIOD: float = 0.09
const DOOM_AT: Array[float] = [0.0, 0.25, 0.5, 0.75, 1.0]
const DOOM_X: Array[float] = [0.0, 1.6, -1.4, 1.0, 0.0]
const DOOM_Y: Array[float] = [0.0, -1.0, 1.2, 1.4, 0.0]

## `choreoAttack` (combat.js:1956) — the body throws itself at what it is
## striking. Three bodies, sorted by the enemy's `art.kind`, and the difference
## between them is the whole point: a golem cannot lunge, so it loads and
## releases in place; a wisp drifts forward and up rather than stepping; anything
## with legs winds back before it swings.
##
## Every frame below is that file's, converted only from CSS px to this port's
## px. The keyframes are read at an already-eased `t` rather than being tweened
## segment by segment, because a single `easing` over a Web Animations iteration
## eases the WHOLE run and interpolates linearly between offsets — easing each
## segment separately would put a settle in the middle of the swing.
const HEAVY_KINDS: Array[String] = ["golem", "treeboss", "leviathan", "crab"]
const FLOATY_KINDS: Array[String] = ["wisp", "shade", "siren", "eye", "cultist"]

const HEAVY_TIME: float = 0.42
const HEAVY_AT: Array[float] = [0.0, 0.35, 1.0]
const HEAVY_SX: Array[float] = [1.0, 1.08, 1.0]
const HEAVY_SY: Array[float] = [1.0, 0.86, 1.0]

const FLOATY_TIME: float = 0.38
const FLOATY_AT: Array[float] = [0.0, 0.4, 0.7, 1.0]
const FLOATY_X: Array[float] = [0.0, 6.0, 10.0, 0.0]
const FLOATY_UP: Array[float] = [0.0, 5.0, 2.0, 0.0]
const FLOATY_SX: Array[float] = [1.0, 0.98, 1.0, 1.0]
const FLOATY_SY: Array[float] = [1.0, 1.02, 1.0, 1.0]

const SWING_TIME: float = 0.33

## `heroIn` / `enemyIn` — 0.55s on cubic-bezier(.2,.75,.3,1), the hero from -70px and a foe
## from +90px (styles.css:724-730). The asymmetry is the benchmark's and is kept: a foe has
## further to come because it arrives from off the board rather than from the player's side
## of it.
##
## MAGNITUDES. The sign comes from `_away()`, which already knows which side an actor
## fights for and is what the lunge and the recoil read too — carrying the direction in
## these constants as well would be the same fact written twice, free to disagree.
const ENTER_TIME: float = 0.55
const HERO_IN_PX: float = 70.0
const FOE_IN_PX: float = 90.0
## `160 + i * 130` (combat.js:345-351) — what a caller adds up per seat. Here so the lineup
## and the actor agree on one figure.
const ENTER_LEAD: float = 0.16
const ENTER_STEP: float = 0.13
const SWING_AT: Array[float] = [0.0, 0.3, 0.62, 1.0]
const SWING_X: Array[float] = [0.0, -8.0, 34.0, 0.0]
const SWING_SX: Array[float] = [1.0, 0.97, 1.02, 1.0]
const SWING_SY: Array[float] = [1.0, 1.02, 0.99, 1.0]

## How hard the struck flash reads. Awaiting a decision, so it is a static the lab
## can sweep (`--flare=N`) rather than a number buried in the shader.
static var flare_gain: float = 1.0

## The stage renders at this multiple of the box. At 1.0 a 176px creature is a
## 176px render being upscaled by the window's own content scale (and again by
## the bench's zoom), which is exactly the softness the first 3D pass had.
##
## **2.0, down from 2.5** — the one memory concession this view makes, worth −20%
## of a 310 MB four-actor stage (docs/actor-stage-frame-budget.md). Stage pixels
## go as the square of this, so it is the cheapest place to buy memory back.
## Judged at 1:1 against MSAA in the lab: dropping it coarsens the lit lip along a
## shard's edge but the lip stays lit, and 1.5 was too soft on the paintings.
static var oversample: float = 2.0

## Anti-aliasing on the actor stage — the same memory saving as `oversample`
## (4x → 2x is −21% against that knob's −20%) for a much worse price, which is why
## it is NOT the one that moved.
##
## MSAA is what makes a shard's edge *lit*; `oversample` only makes it *fine*. The
## side band is a sub-pixel sliver, so its specular highlight lives or dies on
## sub-pixel coverage: at 2x the continuous bright lip breaks into a dim broken
## line and the piece stops reading as glass at all — see
## docs/solutions/design-patterns/procedural-glass-reads-off-its-edges.md. The
## aggregate difference is small (RMSE 0.005) because the affected area is a few
## hundred pixels; those are the load-bearing ones.
##
## A static, like `oversample`, so a lab can compare settings without editing the
## file it is judging.
static var msaa: Viewport.MSAA = Viewport.MSAA_4X

## How far into its own silhouette a painting is corroded, in UV — the port of
## `uErode` (`mesh.js:315`), which the benchmark also mirrors for its non-mesh
## path as the SVG `#alpha-erode` filter (`feMorphology erode 0.65` then
## `feComposite in`, `index.html:58`, worn by `.enemy-sprite > .raster-art` at
## `styles.css:786`). Both do one thing: eat the outermost ring of the matte.
##
## **Eleven of the twenty-seven paintings carry a pale halo** and nine of them
## carry it badly. Measuring un-premultiplied fringe luma against the opaque core
## of the same file: gloomslime +523, rootheart +434, ashAcolyte +429, waylayer
## +408, thornling +405, then voltEel, mirelurker, gravewarden and sporeling
## between +290 and +360. The other sixteen are neutral or dark — abyssalKnight
## is −35 — which is why sampling one creature and generalising got this wrong
## once already. It is a per-asset defect, not a per-project one.
##
## `process/fix_alpha_border` in the importer does NOT cover it. That pads FULLY
## transparent texels with their nearest opaque colour; the halo lives in the
## PARTIALLY transparent ring, whose RGB the art itself authored pale.
##
## 0.0024 is the benchmark's number and it transfers unchanged, because it is UV
## on both sides: 1.2 texels of its 512 atlas and 2.5 of our 1024 source are the
## same fraction of the same creature.
static var erode_uv: float = 0.0024

## The rite's fireworks: the burst flash, the embers and the fire flare. Turning
## them off is a LAB affordance and never a game setting — they are additive and
## they cover the debris completely, so while they are on a screenshot of the
## shatter cannot show whether the body broke along its own cracks. Judging the
## fracture needs a frame with nothing in front of it.
static var rite_fx: bool = true
static var _fx_shader: Shader = null

var idx: int = 0
## Placement offsets for whoever puts this actor on the battlefield. Feet are
## this box's bottom edge (benchmark bfEnemyFootX / bfEnemyFootY).
var foot: Vector2 = Vector2.ZERO
var art_size: float = 0.0
## Which side this actor fights for, and how big it is — one field, because
## char-meta already models a hero as a size class (`tierSizes.hero` = 285)
## alongside normal, elite and boss. Nothing has to be passed in: the art id
## resolves the tier the same way it already resolves the box and the folder.
## An actor with no painting falls back to the gem, which is a foe's avatar.
var tier: String = "normal"

var _hue: float = 210.0
var _max_hp: int = 1
## Current HP, kept beside the rail rather than read back off it: the preview
## segment needs an integer, and the rail's value is a float mid-tween.
var _hp: int = 0
var _marked: bool = false
var _ward_mesh: MeshInstance3D = null
var _ward_mat: ShaderMaterial = null
## `wardOn` / `wardGrow` / `wardSiteF` — whether the shell is wanted, how much of
## it has formed, and how many of its facets are cut. They are separate because
## a re-gain moves the second without moving the first.
var _ward_on: bool = false
var _ward_grow: float = 0.0
var _ward_grow_from: float = 0.0
var _ward_t: float = 0.0
var _ward_site_f: float = 0.0
var _ward_pulsing: bool = false
var _ward_pulse_from: float = 0.0
var _ward_pulse_t: float = 0.0
var _ward_sites_used: int = -1
## The stone's own root, outside `_vessel` so the recoil squash cannot reach it, and the
## break: 0 intact, 1 gone.
var _ward_root: Node3D = null
var _ward_breaking: bool = false
var _ward_burst: float = 0.0
## A blow the stone ate: how much is left of it, and which way it came from.
var _ward_hit: float = 0.0
var _ward_from: Vector2 = Vector2.LEFT
var _doomed: bool = false
var _doom_t: float = 0.0
var _intent: IntentChip
var _gem: GlassGem
var _name_label: Label
var _affix_label: Label
var _name_row: HBoxContainer
var _hp_bar: ProgressBar
## The trail behind a loss — the same rail, a beat late.
var _hp_ghost: ProgressBar
## `.hpbar > .pv` (styles.css:969) — the slice of the rail an armed card would
## take. Not a ProgressBar: it is a SEGMENT, anchored where the loss begins
## rather than at the left edge.
var _hp_preview: ColorRect
var _preview_t: float = 0.0
var _ghost_tween: Tween = null
var _hp_label: Label
var _facets: FacetPips
var _ward_chip: PanelContainer
## Transparent seat for the ward numeral — carries the `blockPulse` glow only.
## Empty at rest so the chip stays a painted lock, not a text pill.
var _ward_chip_sb: StyleBoxFlat
var _ward: Label
var _ward_icon: TextureRect
## Last ward shown on the chip. A gain (`block > _previous_ward`) fires
## `blockPulse`; a fall or a same-value resync does not.
var _previous_ward: int = 0
var _block_pulse_tween: Tween = null
var _statuses: StatusRow
var _crown: VBoxContainer
var _plate: VBoxContainer
## Two independent reasons move the foot plate and they ADD: `align_plate` hangs
## it off the ground line, `clamp_chrome` lifts it clear of the hand. The
## benchmark spends `--chrome-dy` on the clamp alone, because there a combatant's
## box bottom already IS its feet; this port carries both in the same offset.
var _plate_ground_dy: float = 0.0
var _plate_clamp_dy: float = 0.0
var _crown_clamp_dy: float = 0.0
var _dead: bool = false
## The recoil, signed and in units of KICK_PX — tweened, then composed into the
## idle by _process. Positive is away from the hero, which is where a foe is
## knocked; a hero is knocked the other way (see _away).
var _hit: float = 0.0
var _hit_squash: float = 0.0
var _hit_tween: Tween = null
## Which way the current blow throws this body. Latched when the recoil starts
## rather than read per frame, because `_away()` is derived from `tier` and the
## sign must not change under a swing already in flight.
var _hit_dir: float = 1.0
## The lunge, composed onto the idle in `_process` the same way the recoil is.
## Held as px and a plain scale multiplier so a blow landing mid-swing adds to
## the swing rather than cancelling it — which is what two CSS animations on one
## element do NOT do, and is the better read.
var _lunge_x: float = 0.0
## Where the entrance starts, in Control px — see `enter`, which slides the whole actor
## rather than the vessel inside its stage.
var _enter_from: float = 0.0
var _enter_tween: Tween = null
var _lunge_up: float = 0.0
var _lunge_scale: Vector2 = Vector2.ONE
var _lunge_kind: String = ""
var _lunge_dir: float = 1.0
var _lunge_tween: Tween = null
var _flare_tween: Tween = null
var _white_tween: Tween = null
## The throwaway stream: camera shake only. Nothing whose position anyone will
## ever compare between two runs may draw from it — see `_frac`.
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Everything that decides fracture GEOMETRY draws from here instead, and the
## reason is a defect this replaces. `_rng` is advanced twice per frame by the
## camera shake in `_process` while `_shake > 0`, and `shatter()` sets
## `_shake = 1.0` — so a rite spent roughly 26 extra draws at 60 Hz and 53 at
## 120 Hz, `reset_glass()` never reseeded, and re-running the rite gave a
## different pattern every time in a frame-rate-dependent way. `CONCEPTS.md` ›
## Lab states the lab exists to prove that a change meant to alter nothing
## altered nothing; for the glass it could not. It also silently poisoned a
## screenshot comparison earlier the same day, where the variance was put down to
## particles alone.
##
## `Rng` rather than `RandomNumberGenerator` because it is the project's own pure
## Mulberry32 and its state is readable, so a pattern can be reproduced from a
## number rather than from a frame count.
var _frac: Rng = Rng.new(0)
## Kept so `reset_glass()` can rewind the stream. `art_id` is a build-time
## parameter and is not retained, and re-deriving the seed is not the point: a
## reset has to put the stream back where it started or the lab still cannot
## repeat a rite.
var _frac_seed: int = 0

# --- the 3D stage
var _stage: SubViewport = null
var _display: TextureRect = null
## Where the art sat when the slump began. The stagger is authored as a relative
## `translateY`, so the rest position has to be latched rather than assumed to be
## zero — an actor mid-entrance is not standing at its origin.
var _stagger_from: Vector2 = Vector2.ZERO
var _display_mat: ShaderMaterial = null
var _reseam_tween: Tween = null
var _quad: MeshInstance3D = null
var _body_mat: ShaderMaterial = null
## `.enemy .name` and its two tier overrides (styles.css:807, :814, :821).
const NAME_PX: int = 14        # 13.5px, and a font size is an integer here
const NAME_PX_BOSS: int = 15
const NAME_OUTLINE: int = 2
const NAME_SHADOW_BLUR: int = 8
const NAME_DIM: Color = Color(0.54509807, 0.5764706, 0.6784314)    # --text-dim
const NAME_ELITE: Color = Color(1.0, 0.67058825, 0.47843137)       # #ffab7a
const NAME_BOSS: Color = Color(1.0, 0.60784316, 0.91764706)        # #ff9bea

## The box `charAim().width` is authored against — `tierSizes.normal`. The
## fraction only means a thickness once it is told which creature it was measured
## on; see `_read_aim` for why that creature is the normal-tier one and not
## whichever body is being drawn.
const AIM_REF_BOX: float = 185.0

## `SEG_X`, `SEG_Y`, `INTENSITY` (mesh.js:20). The subdivision is what the idle
## deformation has to bend; the intensity is the single global dial the benchmark
## keeps in front of every term of it.
const SEG_X: int = 24
const SEG_Y: int = 36
const IDLE_INTENSITY: float = 0.45

## `PROFILE` (mesh.js:140) — an idle per `art.kind`, and the reason a golem does
## not breathe like a wisp. Read as the BASE; `char-meta`'s own `mesh` block is
## laid over it per creature, which is what `meshProfileFor` does.
##
## `float` is not a warp term: it is a whole-body lift in stage px (mesh.js:1271)
## and it is applied to the vessel rather than to the vertices.
const IDLE_PROFILES: Dictionary[StringName, Dictionary] = {
	&"wisp": {"sway": 0.55, "bob": 1.85, "breathe": 0.95, "head": 0.4, "cloth": 0.0, "pin": 1.05, "float": 1.35},
	&"beast": {"sway": 1.15, "bob": 0.85, "breathe": 0.65, "head": 0.55, "cloth": 0.2, "float": 0.0},
	&"slime": {"sway": 0.55, "bob": 0.55, "breathe": 1.35, "head": 0.0, "cloth": 0.55, "pin": 1.2, "float": 0.25},
	&"rogue": {"sway": 1.0, "bob": 1.0, "breathe": 1.0, "head": 1.0, "cloth": 0.8, "float": 0.0},
	&"plant": {"sway": 0.7, "bob": 0.75, "breathe": 0.85, "head": 0.25, "cloth": 1.15, "pin": 1.1, "float": 0.55},
	&"cultist": {"sway": 0.95, "bob": 0.95, "breathe": 1.0, "head": 0.85, "cloth": 0.7, "float": 0.0},
	&"golem": {"sway": 0.28, "bob": 0.25, "breathe": 0.35, "head": 0.15, "cloth": 0.0, "float": 0.0},
	&"treeboss": {"sway": 0.4, "bob": 0.3, "breathe": 0.5, "head": 0.2, "cloth": 0.6, "float": 0.0},
	&"zombie": {"sway": 0.7, "bob": 0.5, "breathe": 0.6, "head": 0.4, "cloth": 0.3, "float": 0.0},
	&"serpent": {"sway": 0.95, "bob": 0.65, "breathe": 0.45, "head": 0.35, "cloth": 0.15, "float": 0.15},
	&"crawler": {"sway": 0.9, "bob": 0.6, "breathe": 0.55, "head": 0.45, "cloth": 0.1, "float": 0.0},
	&"crab": {"sway": 0.5, "bob": 0.35, "breathe": 0.4, "head": 0.2, "cloth": 0.0, "float": 0.0},
	&"maw": {"sway": 0.65, "bob": 0.45, "breathe": 0.7, "head": 0.5, "cloth": 0.0, "float": 0.1},
	&"knight": {"sway": 0.85, "bob": 0.7, "breathe": 0.75, "head": 0.7, "cloth": 0.5, "float": 0.0},
	&"siren": {"sway": 1.05, "bob": 1.25, "breathe": 0.8, "head": 0.6, "cloth": 0.9, "pin": 1.1, "float": 0.85},
	&"leviathan": {"sway": 0.35, "bob": 0.25, "breathe": 0.45, "head": 0.3, "cloth": 0.2, "float": 0.0},
	&"shade": {"sway": 0.9, "bob": 1.05, "breathe": 0.7, "head": 0.5, "cloth": 0.6, "pin": 1.1, "float": 0.7},
	&"eye": {"sway": 0.35, "bob": 1.45, "breathe": 1.0, "head": 0.0, "cloth": 0.0, "pin": 0.95, "float": 1.2},
	&"sovereign": {"sway": 0.45, "bob": 0.35, "breathe": 0.55, "head": 0.45, "cloth": 0.35, "float": 0.0},
	&"humanoid": {"sway": 1.0, "bob": 1.0, "breathe": 1.0, "head": 1.0, "cloth": 0.85, "float": 0.0},
}
## `pin` is absent from most profiles; `pow(v, 1.6)` is the default weighting.
const IDLE_PIN: float = 1.6
## `float * 12 * INTENSITY` (mesh.js:1271), in stage px, never negative.
const FLOAT_PX: float = 12.0
const FLOAT_RATE: float = 1.15

## The SECOND idle layer, and the one this port never had. `FLOAT_PX` above is
## the mesh plane's own offset; on top of it the benchmark hangs a per-KIND CSS
## animation on the sprite box, one per archetype and mutually exclusive
## (`src/styles.css:1612-1624`, applied at `src/ui/combat.js:1841`). Four shapes,
## and every kind gets exactly one:
##
## - `idleFloat` — a whole-box hover, never below the line. A wisp rises 16px
##   over 3.1s there against 7.29px over 5.46s here, which is why the port's
##   floaters read as standing still and why the cast shadow had nothing to
##   answer to.
## - `idleSlime` — `translateY 0 / -4 / +2` with `scaleX 1 / 1.04 / .97` at
##   0/33/66%. It DOES leave the ground, briefly, and it also sinks below it.
## - `idleSway` — `translateX 5px` with `rotate 1.8deg`. Serpents only.
## - `idleBreathe` — `scaleY 1.025`, and the closest thing the benchmark has to
##   a default. Six walking kinds share it.
##
## The vertex-stage deform (`IDLE_PROFILES`) is the OTHER layer and runs with
## whichever of these applies; over there the mesh plane tracks the CSS box each
## frame, so both are live at once (`src/styles.css:1611`).
const KIND_IDLE: Dictionary = {
	&"wisp": &"float", &"eye": &"float", &"siren": &"float", &"shade": &"float",
	&"plant": &"float", &"slime": &"slime", &"serpent": &"sway",
	&"beast": &"breathe", &"rogue": &"breathe", &"cultist": &"breathe",
	&"knight": &"breathe", &"zombie": &"breathe", &"crawler": &"breathe",
}
const KIND_IDLE_PERIOD: Dictionary = {
	&"wisp": 3.1, &"eye": 3.4, &"siren": 3.6, &"shade": 3.6, &"plant": 3.8,
	&"slime": 4.2, &"serpent": 3.5, &"beast": 3.6, &"rogue": 3.6,
	&"cultist": 3.6, &"knight": 3.6, &"zombie": 3.6, &"crawler": 3.6,
}
## `--float-y`, in stage px — `idleFloat` only.
const KIND_FLOAT_PX: Dictionary = {
	&"wisp": 16.0, &"eye": 18.0, &"siren": 12.0, &"shade": 12.0, &"plant": 9.0,
}
## The keyframe stops, and the values at them. CSS signs throughout: `translateY`
## is DOWN and `rotate` is clockwise, so both are negated on the way into a
## Godot basis. Kept in the source's own numbers so a line here greps against a
## line there.
const HALF_AT: Array[float] = [0.0, 0.5, 1.0]
const SLIME_AT: Array[float] = [0.0, 0.33, 0.66, 1.0]
const SLIME_Y: Array[float] = [0.0, -4.0, 2.0, 0.0]
const SLIME_SX: Array[float] = [1.0, 1.04, 0.97, 1.0]
const SWAY_X: float = 5.0
const SWAY_DEG: float = 1.8
const BREATHE_SY: float = 1.025
## `kind === 'wisp' || kind === 'plant'` (`src/ui/combat.js:1845`).
const MOTE_KINDS: Array[StringName] = [&"wisp", &"plant"]

## `floatKinds` (`src/ui/combat.js:1856`) — how much lift, in stage px, counts as
## fully airborne where the shadow is concerned. A slime that leaves the ground
## at all has left it; a wisp is expected to.
const SHADOW_MAX: Dictionary = {
	&"wisp": 20.0, &"eye": 20.0, &"siren": 14.0, &"shade": 14.0,
	&"plant": 10.0, &"slime": 6.0,
}
const SHADOW_MAX_DEFAULT: float = 12.0

## `charAim(id).color`, resolved once from the character table.
var _aim_tint: Color = Color(0.894, 0.835, 0.984)
## In UV, so that `aim_px / art_size` is a CONSTANT number of screen pixels.
var _aim_width: float = 0.012
var _vessel: Node3D = null
var _glass_root: Node3D = null
var _breathe: float = 1.0
## The other two thirds of the idle. They were riding on `_breathe`, which meant
## every body swayed and bobbed in exact proportion to how hard it breathed —
## and `char-meta` authors them as three separate knobs precisely because they
## are not the same thing.
var _idle_sway: float = 1.0
var _idle_bob: float = 1.0
var _idle_head: float = 1.0
var _idle_cloth: float = 0.85
var _idle_pin: float = IDLE_PIN
var _idle_float: float = 0.0
## Which of the four kind animations this creature runs, and over what period.
var _kind_idle: StringName = &""
var _kind_period: float = 3.6
## `--float-y` in world units, for the `float` shape only.
var _hover_amp: float = 0.0
## The two drifting spores, on wisps and plants only.
var _motes: IdleMotes = null
## The kind's `floatKinds` ceiling (`SHADOW_MAX`), in world units.
var _hover_span: float = SHADOW_MAX_DEFAULT * UNIT
## `char-meta`'s own `mesh` block, kept so the kind's profile can be swapped in
## underneath it later without losing the per-creature overrides on top.
var _idle_over: Dictionary = {}
var _idle_t: float = 0.0
var _phase: float = 0.0
var _shards: Array[Node3D] = []
var _key: DirectionalLight3D = null
var _rim: OmniLight3D = null
var _fire: OmniLight3D = null
var _env: Environment = null
var _sites: PackedVector2Array = PackedVector2Array()

## The fracture model and its renderer. Built on the first blow, not at construction:
## most actors in a fight never take one, and a `CrackField` is a 128 KB byte array.
var _net: CrackNet = null
var _frac_field: FractureField = null
var _cracks: CrackField = null
## Blows delivered, capped at `MAX_SITES`. Counted separately from `_sites` because
## `_sites` only fills while `discs` is on, and the cap is on IMPACTS either way
## (`CONCEPTS.md` › Crack).
var _blows: int = 0
var _art_id: StringName = &""
## The propagation front, and where the light comes from when the vessel ignites.
var _reveal_tween: Tween = null
## Running centroid of every impact, in body UV — `bakeCrackBeams` takes the same
## centroid for the same reason (`crack_hearth`). Centre until something lands.
var _hearth: Vector2 = Vector2(0.5, 0.5)
var _hearth_n: int = 0

## How fast a crack front runs, in body widths per second.
##
## Not a physical number and it must not pretend to be: glass cracks at something like
## 1500 m/s, so an honest duration would be a fraction of one frame. This is a LEGIBILITY
## duration — long enough for the eye to read a star being thrown rather than appearing,
## short enough to land inside the recoil it belongs to. At 2.6 a typical 0.3-body arm
## takes 0.12 s, and the longest arm a blow can buy still finishes inside `HIT_TIME`.
const CRACK_SPEED: float = 2.6

## What a hit costs in fracture when the caller does not say, in body widths of crack.
##
## 1.1, which is `ARM_LENGTH × 4` — a four-armed star, the same figure the reference
## authors by hand for an ordinary hit and the energy the kill-test sheet was judged at.
##
## First set to 0.34 on the reasoning that one arm per hit is the modest choice. That was
## wrong and the render said so immediately: `int(0.34 / 0.26)` is one arm, and a single
## isolated arm has no star, no branch and no junction, so six hits read as six scratches
## rather than as broken glass. An impact star is the smallest unit that reads as
## fracture at all — the arm is not.
##
## Much of this is refunded in practice: arms that reach the silhouette stop there, so
## eight blows at 1.1 land ~2.9 body of crack rather than 8.8.
##
## It is now the FLOOR of the damage conversion below rather than the whole story, and it
## still earns the name: a caller that knows a hit landed and not how hard gets this.
const DEFAULT_ENERGY: float = 1.1

## `bite` — the damage number becoming fracture energy, and `docs/fracture-model.md` §3's
## one honest fudge. No physics connects a card's damage to joules, so this is a unit
## conversion, which is the one class of constant allowed to be arbitrary. It is global
## rather than per-creature, and it was CALIBRATED rather than dialled.
##
## The calibration §3 asks for: choose it so a blow removing all of a foe's health carves
## into 9–14 shards, the band `_death_sites`' rings were tuned to and the rite is already
## approved at. Measured over five seeds on three real silhouettes — one blow, relieved,
## carved — 2.0 gives 11.4 on a duskfang, 12.4 on a gravewarden and 14.0 on an emberwisp.
##
## The measurement also said something the calibration did not ask for and is worth
## keeping: the count SATURATES around 2.5 and then FALLS, reaching 8.6 by 6.0. More energy
## past that point buys longer arms out of one impact rather than more of them —
## `MAX_ARMS` caps the count — and long siblings arrest on each other, so the extra crack
## makes T-junctions instead of through-cuts. There is no energy at which a single blow
## shatters a body into dust, which is the right shape for the model to have and was not
## designed in.
const BITE: float = 2.0

## The old Voronoi disc web, OFF.
##
## This is the thing the owner identified: every cell hard-clipped to a constant-radius
## 20-gon, given the brightest and most emissive treatment in the effect, so each crack
## sat inside a visible circle and the circles stacked
## (`docs/glass-crack-rendering.md` §2.2). `CrackField` replaces it.
##
## Kept behind a flag rather than deleted, and the reason has changed now that the carve
## has landed: the rite no longer needs it. What survives is the COMPARISON — turning this
## on renders both models over the same net in the running game, which is the only way to
## judge a replacement against the thing it replaced. `_voronoi_cells()` is the separate
## survival, for a vessel that shatters without ever having been struck.
static var discs: bool = false
var _span: float = 0.0          # padded box, in px
var _box_u: float = 0.0         # box HEIGHT, in world units
## Box WIDTH. The art box is square (the benchmark's hit rect) but the painting
## inside it is `contain`-fitted, and 6 of 27 foes plus both heroes are not
## square — drawn on a square quad they stretch. Fit by height, narrow by aspect.
var _quad_w: float = 0.0
var _shadow: MeshInstance3D = null
var _shadow_mat: ShaderMaterial = null
## Where the painting actually touches the ground, read off its own alpha: u
## across the quad, and the transparent margin the painting leaves below its
## lowest opaque row.
##
## That margin is FRAMING, not height, and it used to drive the shadow's lift
## response. Measured across all 27 paintings the bottom margin matches the top
## to a tenth of a percent on most of them — 10.0/10.0, 5.2/5.2, 13.0/13.0,
## 20.7/20.6 — because it is a uniform export border. The largest belongs to
## `shellback`, a crab flat on the floor, at 20.7%; `voidWisp`, which is a wisp,
## has 4.3%. So the old response was not merely static, it was inverted: it gave
## the crab the most float and the wisp almost none. Height now comes from the
## body's own transform (`_update_shadow`), and this stays what it is — a
## framing offset for the hinge.
var _contact_u: float = 0.5
var _art_pad: float = 0.0
## The contact ROW, as a texture v — `1.0 - _art_pad / _box_u`, kept as its own
## number because the shadow's vertex stage works in UV and converting there
## would need the box height twice.
var _contact_v: float = 1.0
## The ground line, one sample per painting column, as a 64x1 R-float texture.
##
## A flat billboard has ONE depth, so the projection could only ever have one
## contact line, and that line has to be the lowest opaque row — anything higher
## would bury the nearest foot. A creature standing on more than one foot is then
## drawn with every other foot ABOVE its own shadow, which is the whole of what
## "floating" looks like. Measured on `duskfang`, whose four paws span 12.5% of a
## body height: the near paw was planted and the other three hovered.
##
## The painting does hold the missing information — the ground is depicted, and
## the silhouette's own bottom edge samples it wherever the creature touches
## down. So the ground line is READ rather than assumed flat, and the projection
## runs from each column's own contact instead of from a single line.
var _ground_tex: ImageTexture = null
## `shadow.dy` read as a resting height — see `_read_hover`.
var _hover_rest: float = 0.0
## The death rite fades the shadow with a tween while the projection rewrites the
## same uniform sixty times a second. Two writers, one uniform: so the fade is a
## FACTOR the projection multiplies, never a value it overwrites.
var _shadow_fade: float = 1.0
## How dark the contact is. **0.95, up from 0.55** — the old figure was
## calibrated in the lab, where an actor stands on flat navy and a 55% black
## smear is unmissable. The battlefield's floor is painted stone that is ALREADY
## dark, and at 0.55 the shadow was drawn correctly and could not be seen at all:
## the geometry, the silhouette and the fall-off were all fine and the whole
## thing read as "the shadow is missing". Judged on the stage, not in the lab.
var _shadow_opacity: float = 0.95
var _ignite: float = 0.0
## Glass reach past each crack site, as a fraction of the box — the benchmark's
## GLASS_AREA. Under 1.0 the body is mostly bare, which is the point: glass
## exists ONLY where the creature is broken.
var _glass_area: float = 0.45
var _glass_mat: ShaderMaterial = null
var _shard_shader: Shader = null
var _debris: Node3D = null
var _cam: Camera3D = null
var _shake: float = 0.0
var _art_img: Image = null

static var _meta: Dictionary = {}
static var _fx_cache: Dictionary = {}
## One mask per PAINTING, not per actor: eight duskfangs in a fight share one
## silhouette, and the alpha read is the expensive part.
static var _mask_cache: Dictionary = {}


## Corrode the matte fringe: take the neighbourhood MINIMUM alpha, lean most of
## the way onto it, then soften what is left. Eight directions at two radii —
## sixteen taps, the same walk the aim rim makes with `max` instead of `min`,
## because erode and dilate are one operator read in opposite directions. Ported
## from `uErode` in the benchmark's `BODY_FRAG` (`mesh.js:200-250`); the mix at
## 0.88 and the closing `smoothstep(0.02, 0.18, ...)` are its numbers.
##
## A contrast curve cannot stand in for this, which is what the tree tried
## first: `smoothstep(0.12, 0.45, c.a)` re-graded every texel against itself, so
## a pale edge texel came out MORE opaque rather than less. A fringe is a
## SPATIAL defect and only a spatial operator reaches it.
##
## Spliced into both shaders that wear the painting rather than written twice,
## because `SHARD_SHADER` states the reason as an invariant: a cap face carries
## "the same alpha curve as the body, so the union of shards at the handoff
## frame IS the body". Two copies of this walk is two chances for that frame to
## pop.
const ERODE_GLSL: String = """
uniform float erode = 0.0;

float eaten(sampler2D tex, vec2 uv) {
	float a = texture(tex, uv).a;
	if (erode <= 0.0 || a <= 0.001) { return a; }
	float lo = a;
	for (int i = 0; i < 8; i++) {
		vec2 d = vec2(cos(float(i) * 0.7853981634), sin(float(i) * 0.7853981634)) * erode;
		lo = min(lo, texture(tex, uv + d).a);
		lo = min(lo, texture(tex, uv + d * 0.55).a);
	}
	float e = mix(a, lo, 0.88);
	return e * smoothstep(0.02, 0.18, e);
}
"""


## Splice `ERODE_GLSL` into a shader at its `//__ERODE__` marker. The marker sits
## below `render_mode`, because a uniform cannot precede it.
static func with_erode(src: String) -> String:
	return src.replace("//__ERODE__", ERODE_GLSL)


## The body: a flat plate that takes REAL light. The painting has no normal map,
## so one is derived from its own luminance gradient in the fragment stage —
## every leaded seam and lit pane becomes relief the lamps can rake across. The
## bright panes also emit, because in this world the creature IS a lantern.
const BODY_SHADER: String = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley,
	specular_schlick_ggx;

uniform sampler2D body_tex : source_color, filter_linear_mipmap;

// `deformPlane` (mesh.js:914) — the idle, and the whole difference between a
// creature that is alive and a picture that is being wobbled. Six terms, each
// weighted by WHERE on the body it acts, so the feet stay planted and the head,
// the chest and the hem move on their own clocks. Run in the vertex stage
// rather than on the CPU: the benchmark walks its vertex array in JS every
// frame, and there is no reason to pay that here.
uniform float idle_t = 0.0;
uniform float idle_seed = 0.0;
uniform float p_sway = 1.0;
uniform float p_bob = 1.0;
uniform float p_breathe = 1.0;
uniform float p_head = 1.0;
uniform float p_cloth = 0.85;
uniform float p_pin = 1.6;
uniform float idle_gain = 1.0;

// `bell(v, 0.62, 0.12)` — the chest. Breathing acts THERE, not everywhere, and
// that is what stops a body from pulsing like a jellyfish.
float idle_bell(float v, float c, float w) {
	float d = (v - c) / w;
	return exp(-d * d);
}

// Half the plane's width, so `VERTEX.x` can be read in the benchmark's own
// units: its geometry is `PlaneGeometry(2, 2)`, i.e. half-extent 1.
uniform float half_w = 1.0;

void vertex() {
	// UV.y 0 is the crown and 1 the feet, so `v` is height above the ground.
	float v = 1.0 - UV.y;
	// `w = pow(v, pin)` — pinned at the contact line. Everything that leans is
	// scaled by this, so a creature sways from its feet rather than sliding.
	float w = pow(max(v, 0.0), p_pin);
	float t = idle_t;
	float s = idle_seed;
	float dx = 0.0;
	float dy = 0.0;
	// Sway: two harmonics, so the lean is not a metronome.
	dx += 0.028 * w * p_sway * sin(t * 0.9 + s);
	dx += 0.010 * w * w * p_sway * sin(t * 1.7 + 1.0 + s * 0.3);
	// Breathe: the chest WIDENS (x scales about the centre) and rises.
	float chest = idle_bell(v, 0.62, 0.12);
	dx += (VERTEX.x / max(0.0001, half_w)) * 0.020 * chest * p_breathe
		* sin(t * 2.2 + s * 0.5);
	dy += 0.012 * chest * p_breathe * sin(t * 2.2 + s * 0.5);
	// Bob.
	dy += 0.014 * w * p_bob * sin(t * 1.1 + 0.4 + s);
	// Head: the top fifth only.
	dx += 0.012 * max(0.0, (v - 0.8) / 0.2) * p_head * sin(t * 0.7 + s);
	// Cloth: a wave travelling DOWN the hem, below 45% height.
	dx += 0.010 * max(0.0, (0.45 - v) / 0.45) * w * p_cloth * sin(v * 12.0 - t * 2.5 + s);
	VERTEX.x += dx * idle_gain;
	VERTEX.y += dy * idle_gain;
}

uniform float bump = 3.5;
uniform float emission_gain = 0.85;
uniform float target_lit = 0.0;
// `charAim(id).color` — the aim outline is tinted per creature, and the
// character table has carried the overrides all along (duskblade #6d9edf,
// ashwarden #f9bd95). The default is CHAR_AIM_DEFAULT's #e4d5fb.
uniform vec3 aim_tint = vec3(0.894, 0.835, 0.984);
// `charAim(id).width` — 0.012 of the plane by default, 0.006 for the largest
// body in the table. Carried in UV so it scales with the creature's own art
// rather than with its pixel count, which is what the benchmark's shader does.
uniform float aim_width = 0.012;
// Struck: 0 at rest, 1 at the peak of the flash. See take_hit().
uniform float flare = 0.0;
// How hard that peak hits. A knob rather than a constant because the CSS number
// does not transfer (see the flare block) so it has to be judged by eye.
uniform float flare_gain = 1.0;
// `meshFlash`'s `uFlash` — flat white added across the silhouette, keyed to
// nothing. Sits beside `flare` rather than inside it because the two answer to
// different clocks: this one is a 160ms square wave, the flare is a ramp.
uniform float hit_white = 0.0;
// The vessel leaving. A custom shader that writes ALPHA overrides
// GeometryInstance3D.transparency outright, so the fade has to be a uniform.
uniform float fade = 1.0;
//__ERODE__

// ---------------------------------------------------------------- the fracture
//
// The crack network as a distance field: R is the distance to the nearest crack,
// normalised by that crack's own local half-width so the taper is already baked in,
// and G is the glint at each impact point. Built by `CrackField` (see its docblock for
// why a field and not drawn lines) and read HERE rather than in a layer of its own —
// `docs/solutions/rendering/one-backbuffer-copy-per-frame.md`: a second pass under an
// opaque one is silently erased, so effects fold into one shader.
//
// Folding it in also gets the thing an overlay could never have. The groove is part of
// the body material, so it warps with the idle deform in vertex() and shakes with the
// camera, by construction and with no code. That is why the lab's FractureProbe could
// only ever be judged as a still.
uniform sampler2D crack_tex : filter_linear;
// The same lantern warmth the debris shader uses, so a crack that is about to become a
// fracture edge does not change colour when it does.
const vec3 WARM_CRACK = vec3(1.0, 0.60, 0.24);
// 0 disables the whole block, including its three texture taps. A creature that has
// not been hit pays nothing.
uniform float crack_on = 0.0;
// The three band thresholds, from CrackField.BANDS, which owns the numbers.
uniform vec3 crack_bands = vec3(0.3333, 0.1552, 0.0805);
// How hard the groove tilts the surface normal. This is the ONE knob that decides
// whether the crack reads as a cut into glass or as a line drawn on top of it.
uniform float crack_relief = 26.0;
// Heat in the fractures, 0..1 — the death ramp. Only the innermost band may emit and
// only under this or `crack_marked`; see the emission block for why.
uniform float crack_ignite = 0.0;
// The seam catching a rim light before the blow lands (§5.5's second cheap addition).
uniform float crack_marked = 0.0;
// The centroid of every impact, in body UV — where the light comes from when the vessel
// ignites. `bakeCrackBeams` (mesh.js:460) takes the same centroid for the same reason.
uniform vec2 crack_hearth = vec2(0.5, 0.5);

// LIGHT ESCAPES THROUGH THE CRACKS — `bakeCrackBeams` (mesh.js:460), the first of §5.5's
// two cheap additions. A zoom blur of the groove away from the hearth, so every crack
// throws a shaft outward as the fire takes hold.
//
// The reference bakes it onto a plane padded 1.6x past the body precisely so the rays
// LEAVE the sprite. This cannot, and the constraint is worth naming rather than hiding:
// folded into the body material, the beams inherit the body's ALPHA, which is the
// painting's own — so a ray past the silhouette lands on a transparent texel and
// contributes nothing. What is here is the light bleeding along and out of the grooves,
// which is most of the effect. The rays that leave the creature need the padded display
// plane, and that is a different change with a different owner.

// 24 taps, near the reference's 26, and the count is NOT padding. A zoom blur is a sum of
// displaced copies, so the taps have to land closer together than the thing being smeared
// is wide or they read as separate copies. At 8 the shafts came out as ladders of parallel
// stripes: for a pixel 0.3 body from the hearth the spacing was 0.017, wider than the whole
// groove. At 24 the spacing is a quarter of the groove's outer band and it reads continuous.
//
// It costs 24 texture fetches in the body fragment — paid only while the vessel is burning,
// which is the two hundred milliseconds before it stops existing.
const int BEAM_TAPS = 24;
// How far the shafts stretch, in hearth distances. Well under the reference's 1.1, which it
// can afford because its rays leave the sprite and these cannot: reach past the silhouette
// is only paying for taps that land on a transparent texel.
const float BEAM_REACH = 0.45;
const float BEAM_DECAY = 1.55;   // how fast a ray dies along its length (mesh.js:40)
// Peak brightness at the groove. Judged off an A/B on the `ignite` state, which is static
// and so the only deterministic instrument here — a rite strip's frames land at different
// points of the ramp on every run and cannot be diffed. At 1.15 the shafts washed the head
// out and read as white paint rather than as light; at 0.65 they stay directional and the
// armour panels underneath survive. The seams were already hot without them: the beams' job
// is the DIRECTION, not the brightness.
const float BEAM_GAIN = 0.65;

float luma(vec2 uv) {
	vec4 c = texture(body_tex, uv);
	return dot(c.rgb, vec3(0.299, 0.587, 0.114)) * c.a;
}

void fragment() {
	// NO uv warp here. The idle motion is a transform on the vessel node that
	// carries the glass with it — warping the texture instead slid the creature
	// out from under its own cracks, which is what "the crack does not align"
	// looks like.
	vec2 uv = UV;
	vec4 c = texture(body_tex, uv);
	ALBEDO = c.rgb;
	ALPHA = eaten(body_tex, uv) * fade;

	vec2 ts = 1.0 / vec2(textureSize(body_tex, 0));
	float l = luma(uv);
	float lx = luma(uv + vec2(ts.x, 0.0));
	float ly = luma(uv + vec2(0.0, ts.y));
	// UV y runs down, world y runs up — flip or every lamp lights from below.
	vec2 relief = vec2((l - lx) * bump, (ly - l) * bump);

	EMISSION = c.rgb * pow(l, 3.2) * emission_gain;
	ROUGHNESS = 0.78;
	METALLIC = 0.0;
	// Low specular: a painted body is not varnished, and a broad highlight over
	// the whole silhouette is the other half of the fog.
	SPECULAR = 0.18;

	// THREE BANDS, AND ONLY THE INNERMOST MAY EMIT (docs/fracture-model.md §5.3).
	//
	// The rule exists because the old disc web broke it: `GLASS_SHADER` lights albedo,
	// alpha AND emission on one contour, which is exactly why that boundary read as the
	// loudest line on the actor. A standing web has to be visible without being loud,
	// and this is the arrangement that achieves it — the groove is a DENT that catches
	// the real key light, not a stroke that glows.
	//
	// So: albedo darkens (a groove is in shadow), the mid band takes the lit lip's
	// roughness and specular so it catches the key, and emission is reserved for the
	// core under heat. ALPHA is never touched.
	if (crack_on > 0.0) {
		vec2 cts = 1.0 / vec2(textureSize(crack_tex, 0));
		vec2 cf = texture(crack_tex, uv).rg;
		float r = cf.r;
		float rx = texture(crack_tex, uv + vec2(cts.x, 0.0)).r;
		float ry = texture(crack_tex, uv + vec2(0.0, cts.y)).r;
		// Screen-space feather, so the groove antialiases itself at any zoom and at any
		// MSAA level. This is the property §5.2 records as the reason a field groove
		// survives a forced drop to 2x where an extruded ribbon does not.
		float aa = max(fwidth(r), 0.008);
		float dark = 1.0 - smoothstep(crack_bands.x - aa, crack_bands.x + aa, r);
		float lite = 1.0 - smoothstep(crack_bands.y - aa, crack_bands.y + aa, r);
		float core = 1.0 - smoothstep(crack_bands.z - aa, crack_bands.z + aa, r);
		float glint = cf.g;

		// The NORMAL. `r` rises away from the crack, so the groove floor is a valley in
		// `r` and the tilt is the same form as the luma relief above — which is the whole
		// argument for storing a distance field rather than drawing three strokes.
		// Suppressed outside the outer band so the field's own quantisation cannot
		// texture the clean body.
		relief += vec2(r - rx, ry - r) * crack_relief * step(0.0001, dark);

		// A groove is a shadowed slot; the lip beside it is bare glass.
		//
		// The lip is LIGHT, not paint. An earlier version added `vec3(0.26, 0.31, 0.38)`
		// to the light band, which on the near-black armour between this creature's panes
		// manufactured a pale grey line out of nothing — a chalk mark, unaffected by
		// where the key actually was. The lift is multiplicative now, so an unlit groove
		// on black armour stays black and only the specular below can brighten it. That
		// is `procedural-glass-reads-off-its-edges.md` as a code change rather than as a
		// quotation: glass is read off its edges, UNEVENLY, as a function of each edge's
		// normal against a real light.
		ALBEDO *= mix(1.0, 0.18, dark * 0.80);
		ALBEDO = mix(ALBEDO, ALBEDO * 2.1 + vec3(0.02, 0.025, 0.032), lite * 0.62);
		ROUGHNESS = mix(ROUGHNESS, 0.10, lite);
		SPECULAR = mix(SPECULAR, 0.88, max(lite, glint));

		// Heat. `marked` is deliberately a fraction of `ignite`: a previewed blow should
		// suggest the fire, not stage the death.
		float heat = max(crack_ignite, crack_marked * 0.30);
		EMISSION += WARM_CRACK * (core * heat * 1.6 + glint * heat * 0.9);

		// The beams. On `crack_ignite` ALONE and not on `heat` — a previewed blow gets the
		// rim light above and never the shafts, because a preview must suggest the fire and
		// not stage the death, and shafts of light leaving the body are the death.
		if (crack_ignite > 0.0) {
			vec2 ray = uv - crack_hearth;
			float beam = 0.0;
			float wsum = 0.0;
			for (int i = 0; i < BEAM_TAPS; i++) {
				float bt = float(i) / float(BEAM_TAPS);
				float w = pow(1.0 - bt, BEAM_DECAY);
				// Read INWARD. The reference draws progressively LARGER copies of the seam
				// outward from the hearth; gathering at a pixel from progressively nearer
				// the hearth is the same operation with the loop turned inside out. Every
				// tap lands between the hearth and this pixel, so all of them are in range
				// and the sampler's wrap mode never comes into it.
				float sr = texture(crack_tex, crack_hearth + ray / (1.0 + bt * BEAM_REACH)).r;
				// The whole groove emits, not just the core: the light is escaping through
				// the opening, and the opening is the outer band.
				beam += (1.0 - smoothstep(0.0, crack_bands.x, sr)) * w;
				wsum += w;
			}
			EMISSION += WARM_CRACK * (beam / max(wsum, 0.0001)) * BEAM_GAIN * crack_ignite;
		}
	}

	NORMAL_MAP = normalize(vec3(relief, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;

	// ONE dilated-alpha ring, two consumers: the targeting rim and the struck
	// flare's glow. Same silhouette, different colour and gain — the six taps are
	// the expensive part and there is no reason to pay for them twice.
	float rim = 0.0;
	if (target_lit > 0.0 || flare > 0.0) {
		// The struck flare wants a broad halo; the aim outline wants a LINE.
		// One ring, two widths — the six taps are the expensive part.
		vec2 px = target_lit > 0.0 ? vec2(aim_width) : ts * 9.0;
		float ring = 0.0;
		ring = max(ring, texture(body_tex, uv + vec2(px.x, 0.0)).a);
		ring = max(ring, texture(body_tex, uv - vec2(px.x, 0.0)).a);
		ring = max(ring, texture(body_tex, uv + vec2(0.0, px.y)).a);
		ring = max(ring, texture(body_tex, uv - vec2(0.0, px.y)).a);
		ring = max(ring, texture(body_tex, uv + px * 0.72).a);
		ring = max(ring, texture(body_tex, uv - px * 0.72).a);
		rim = clamp(ring - c.a, 0.0, 1.0);
	}
	if (target_lit > 0.0) {
		// A lit edge, not a floodlight. At gain 3 with the alpha forced opaque
		// the outline blew to white and swallowed its own tint, so the per-
		// creature colour the character table authors could not be seen at all.
		EMISSION += rim * target_lit * aim_tint * 0.55;
		ALPHA = max(ALPHA, rim * target_lit * 0.9);
	}
	// Struck. The benchmark's `hurtFlash` peaks at brightness 2.6 with
	// saturate .4 and an 18px white halo, so the glass goes briefly white-hot and
	// the silhouette carries a rim of it. Desaturating FIRST is what stops a red
	// creature simply going redder — the flash has to read as light, not as paint.
	// Struck. Two rejected attempts are worth recording, because both were the
	// CSS instruction taken literally:
	//   * `brightness(2.6)` as an EMISSION term over the whole body washed the
	//     creature out completely — a lit shader that already emits is not a
	//     composited sprite, so the number does not transfer.
	//   * the 18px halo as `ALPHA = max(ALPHA, rim)` widened the SILHOUETTE, which
	//     reads as a sticker outline or a selection highlight, not as a blow. A
	//     glow must sit over the body, never extend it.
	// What is left flashes the glass the creature is already made of: the lit panes
	// go white-hot, the dark armour between them does not, and the halo is a hint.
	// A third rejected attempt: `saturate(.4)`, ported as a 0.35 mix toward grey,
	// DOMINATED. On a warm creature under low light the desaturation lands before
	// the added light does, so frames 0-2 read as the beast going briefly pale and
	// frames 3-5 as it recovering its colour — the opposite event. CSS gets away
	// with it because `brightness(2.6)` overwhelms the desaturation; here the
	// light has to lead and the grey is a whisper on top of it.
	if (flare > 0.0) {
		float f = flare * flare_gain;
		// pow(l, 1.4) rather than the body's own 3.2: the flash reaches further
		// down the tonal range than the resting lantern glow, so a mid-tone pane
		// lights up too — but it is still keyed to the painting, so the flash has
		// the creature's own shape rather than being a wash over its box.
		vec3 lit = ALBEDO * pow(l, 1.4) * f * 4.0;
		float g = dot(ALBEDO, vec3(0.299, 0.587, 0.114));
		ALBEDO = mix(ALBEDO, vec3(g), 0.10 * f) * (1.0 + 0.8 * f);
		EMISSION += lit + rim * f * 0.3;
	}
	// `base.rgb + uFlash * a` (mesh.js:245). Added last and added flat: the
	// benchmark does this AFTER its own lighting, so nothing above may shape it.
	// The alpha mask is Godot's to apply at composite, which is what `* a` is.
	EMISSION += vec3(hit_white);
}
"""


## Real glass: the view ray is refracted through the shard's own normal and used
## to sample what has already been drawn in this viewport — which is the body.
## So the creature genuinely bends behind its own fractures, with a Fresnel edge
## that whitens at grazing angles and a warm bloom as the vessel ignites.
##
## StandardMaterial3D's `refraction_enabled` cannot do this job here: it forces
## ALPHA to 1 and reads a screen that, inside a transparent SubViewport, is
## empty — which is why the first pass came out as grey pebbles.
## The ward stone — a CUT GEM held in front of the creature. See `WARD_CUT_N` and the
## `WARD_*` block for why this is a rewrite rather than a port, and what it replaced.
##
## Descended from `meshWard` (mesh.js:1300) and keeps its silhouette generator: a signed
## distance to an irregular 8-gon, so no two guards in a fight are the same stone. What it
## does NOT keep is that shell's normal — a Voronoi second-nearest seam over 37 scattered
## sites, which is the crack web's own construction and the reason a guarded creature and a
## damaged one read alike.
##
## In its place, a cut. The stone is divided into `WARD_CUT_N` angular wedges and **the
## normal is constant inside a wedge**, which is the entire trick: a constant normal is a
## flat facet, and flat facets meeting at a jump are hard edges. Everything else follows —
## a table where the wedges' inner ends are flat, an alternating crown pitch so no two
## neighbours read as one larger face, and a bright rib exactly on each boundary, which is
## both what a real gem edge does with light and what hides the normal discontinuity.
##
## What the stone is NOT is a refractor, and that is inherited reasoning worth keeping:
## `refraction: 2` scales `thickness`, authored at 0, so transmission bends nothing there
## either. Every bit of structure you see is a facet normal turning against the view at
## `roughness: 0`. Reading the thickness first is what stops this becoming an expensive
## screen-space effect that looks less like a gem, not more.
const WARD_SHADER: String = """
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, specular_schlick_ggx;

uniform vec2 outline[16];
uniform int outline_n = 8;
// How many crown facets have been CUT. Growth raises this, so the stone is cut as it forms
// rather than faded in whole — which is the one thing worth keeping from the shell's
// `syncWardNormalMap` behaviour.
uniform int facet_n = 0;
uniform int cut_n = 8;
uniform float table_r = 0.42;
uniform float grow = 0.0;
// The stone coming apart, 0 intact to 1 gone. A shield that runs out is CONSUMED, and an
// object that is consumed breaks — the fade this replaced was the only thing a shell could
// do, because a shell has no pieces to break into. A cut does: its facets are its fracture
// planes, so the same eight numbers that draw the stone also decide how it goes.
uniform float burst = 0.0;
// A blow ABSORBED, 0..1, decaying. This exists because taking the stone off `_vessel` took
// away the only reaction it had: the old shell squashed with the body and so appeared to
// answer a hit. An independent object that eats a full blow and does not move is worse than
// one that never looked independent, so the decoupling owes this.
uniform float ward_hit = 0.0;
// Where the blow came FROM, in stone space, so the facets facing it answer hardest. A
// shield lights where it was struck.
uniform vec2 hit_from = vec2(-1.0, 0.0);
// How far a facet travels by the end, in stone radii.
const float BURST_D = 0.52;
uniform vec4 tint : source_color = vec4(0.29, 0.565, 0.749, 1.0);
uniform float shell_opacity = 0.4;
uniform float edge_soft = 0.01;
uniform float rough = 0.0;
uniform float env_gain = 0.72;
// The key light's direction in the stone's own space, so a facet can be lit by the light
// that actually exists rather than by a painted highlight. Swings with `set_light_angle`.
uniform vec3 key_dir = vec3(-0.42, 0.55, 0.72);
// How the stone's 0.4 of opacity is SPENT, and the total is what matters: these sum to
// 0.79 before `shell_opacity`, so the most solid a facet ever gets is 0.32 and only the
// flash goes past it. The first pass summed to 2.1 and buried the creature's head under a
// pale slab — which is the same failure the shell this replaces recorded in its own comment
// and then avoided only by having almost no lit area at all.
//
// Almost none on the table. The rest on the three things that are actually a gem: its
// edges, how steeply each face is cut, and its flashes.
const float FACE = 0.07;
const float RIB_A = 0.34;
// A face's own steepness, and this is where a Fresnel term was and should not have been. A
// crown facet here is tilted about 40 degrees, and `1 - dot(N, V)` at 40 degrees is 0.06 —
// so grading the facets by Fresnel graded them all to nothing, and the pane came back. The
// pitch IS the quantity that separates one face from the next, so spend on it directly.
// The alternating crown then reads as a 2:1 step between neighbours, which is the cut.
const float FACET_A = 0.55;
// A flash covers a WHOLE FACE. That follows from the normal being constant across one — a
// tight lobe on a curved surface is a speck, and on a flat one it is the entire plate. The
// first pass priced it as a speck at 0.85 and lit three faces to near-solid across the
// creature's head.
const float FLASH_A = 0.30;
// The absorbed blow. Larger than any standing term, because it is the one moment the stone
// is supposed to be the loudest thing on the actor — and it is gone in a fifth of a second.
// 0.75 was too much: the whole stone went to a pale slab and buried the creature exactly as
// the first alpha budget did, which is the second time this shader has had to be talked
// down from the same mistake.
const float HIT_A = 0.45;
// How hard a crown facet tilts. TWO values, alternating around the ring, because two
// adjacent facets at the same pitch have the same normal and therefore read as ONE larger
// facet — the ring would come out as a bevel rather than as a cut.
const float PITCH_MAIN = 0.66;
const float PITCH_BREAK = 0.33;
// A rib's half-width, in stone radii. A gem's edges are lines, not bands.
const float RIB_W = 0.013;

// `signedDistPoly` — negative inside. The winding test is the standard one. The outline is
// convex now that it is a regular polygon and a half-plane test would do, but this is three
// lines of already-correct code and the girdle is the one place a future cut might not be.
float sd_poly(vec2 p) {
	float d = dot(p - outline[0], p - outline[0]);
	float s = 1.0;
	for (int i = 0, j = outline_n - 1; i < outline_n; j = i, i++) {
		vec2 e = outline[j] - outline[i];
		vec2 w = p - outline[i];
		vec2 b = w - e * clamp(dot(w, e) / max(1e-6, dot(e, e)), 0.0, 1.0);
		d = min(d, dot(b, b));
		bvec3 c = bvec3(p.y >= outline[i].y, p.y < outline[j].y, e.x * w.y > e.y * w.x);
		if (all(c) || all(not(c))) { s = -s; }
	}
	return s * sqrt(d);
}

void fragment() {
	// The mask is measured in the same oval the reference bakes into:
	// centre (0.5, 0.52), radii (0.46, 0.48).
	vec2 q = vec2((UV.x - 0.5) / 0.46, (UV.y - 0.52) / 0.48);
	float fn = float(cut_n);
	// TAU is a Godot shading-language built-in; declaring one here is a redefinition error.

	// THE CUT. A wedge index around the centre, and inside a wedge the normal is CONSTANT.
	// That is the whole mechanism: a constant normal is a flat facet, and two flat facets
	// meeting at a jump is a hard edge. No smoothing and no hashing anywhere — the stone is
	// a machined object and every facet is the same as its opposite number.
	//
	// THE BREAK is resolved in the same pass, because it is the same question asked of moved
	// pieces: each crown facet travels out along its own axis, so a fragment shows whichever
	// piece has ARRIVED at it and the geometry has to be looked up where that piece started.
	//
	// It has to be a search over the pieces and not a test of the fragment's own angle. The
	// first version did the latter — cheaper, and wrong in a way that took a strip to see: a
	// facet translated outward pushes its far corners past the angular wedge it came from, so
	// clipping by the fragment's angle CUT EACH PLATE BACK as it left. Eight plates flying
	// apart came out as one ring quietly expanding, which is a different event entirely.
	//
	// Eight iterations, entered only while the stone is breaking.
	int hit = -1;
	vec2 p = q;
	float table_hit = 0.0;
	if (burst <= 0.0) {
		hit = int(floor(fract(atan(q.y, q.x) / TAU + 0.5) * fn));
	} else {
		// The table does not travel, so it is tested where the fragment is and tested first.
		float u0 = fract(atan(q.y, q.x) / TAU + 0.5);
		int k0 = int(floor(u0 * fn));
		float off0 = (fract(u0 * fn) - 0.5) / fn * TAU;
		if (length(q) <= table_r / max(0.25, cos(off0))) {
			hit = k0;
			table_hit = 1.0;
		} else {
			for (int i = 0; i < cut_n; i++) {
				float m = ((float(i) + 0.5) / fn - 0.5) * TAU;
				vec2 pi = q - vec2(cos(m), sin(m)) * burst * BURST_D;
				if (int(floor(fract(atan(pi.y, pi.x) / TAU + 0.5) * fn)) == i) {
					hit = i;
					p = pi;
					break;
				}
			}
		}
	}
	if (hit < 0) { discard; }   // the gap a departed piece left behind

	float k = float(hit);
	// The wedge's own outward direction, recovered from the INDEX and not from the fragment,
	// so every fragment in a facet gets the same vector. Screen y runs down against the
	// world's up, so the y term is negated where the normal is built.
	float mid = ((k + 0.5) / fn - 0.5) * TAU;
	vec2 axis = vec2(cos(mid), sin(mid));

	// The table is a POLYGON and not a disc: its boundary is a straight chord across each
	// wedge, so at an angular offset from the wedge's centre its radius is the apothem over
	// the cosine.
	float within = fract(fract(atan(p.y, p.x) / TAU + 0.5) * fn);
	float off = (within - 0.5) / fn * TAU;
	float tr = table_r / max(0.25, cos(off));
	float r = length(p);
	bool on_table = table_hit > 0.5 || (burst <= 0.0 && r <= tr);
	bool cut = hit < facet_n;

	float sd = sd_poly(p);
	float t = edge_soft <= 0.001
		? (sd <= 0.0 ? 1.0 : 0.0)
		: 1.0 - smoothstep(-edge_soft, 0.0, sd);
	// The table goes by fading — it is the face the crown was cut around and has nowhere to
	// travel to — and it goes FASTER, so the plates are alone on screen at the end.
	t *= grow * (on_table ? 1.0 - min(1.0, burst * 1.8) : 1.0 - burst);
	if (t < 0.01) { discard; }
	if (!on_table && r <= tr) { discard; }   // a plate is a plate, not a plate plus its table

	vec2 nrm = vec2(0.0);
	if (cut && !on_table) {
		// Strictly alternating, and nothing else. A machined cut has two facet angles and
		// they take turns; `WARD_CUT_N` is even so the ring closes on the right one.
		float pitch = mod(k, 2.0) < 1.0 ? PITCH_MAIN : PITCH_BREAK;
		nrm = vec2(axis.x, -axis.y) * pitch;
	}
	NORMAL_MAP = vec3(nrm * 0.5 + 0.5, sqrt(max(0.05, 1.0 - dot(nrm, nrm))));

	// The RIBS: the facet boundaries, as lines of constant width rather than of constant
	// angle. `within` is angular, so the arc it stands for grows with radius — multiplying
	// by `r` is what stops a rib being a hairline at the table and a wedge at the girdle.
	//
	// They are not decoration. A hard normal jump aliases, and a bright line sitting exactly
	// on the jump both hides it and is what a real gem edge does with light.
	//
	// **Only outside the table**, and that is not a detail. Eight boundaries all measured to
	// the centre meet there, so the first version drew eight spokes converging on a hub — a
	// cartwheel, which is precisely the wrong object. A crown facet ends where the table
	// begins; the ribs have to end there too.
	float aa = max(fwidth(r), 0.0015);
	float rib = 0.0;
	if (cut && !on_table) {
		float to_ray = min(within, 1.0 - within) / fn * TAU * r;
		rib = 1.0 - smoothstep(RIB_W - aa, RIB_W + aa, min(to_ray, abs(r - tr)));
	} else if (cut) {
		// The table's own outline, from the inside.
		rib = 1.0 - smoothstep(RIB_W - aa, RIB_W + aa, tr - r);
	}
	// A stone gives way at its edges first, so the ribs flare — but only a little. At 2.2 the
	// flare turned every plate's boundary into a long bright spoke and the strip read as a
	// star rather than as eight pieces leaving; the plates have to stay plates.
	rib *= 1.0 + burst * 0.8;

	// THE FACETS HAVE TO BE READ OFF THEIR OWN NORMAL, and the reason is a Godot mechanic
	// rather than a taste: `NORMAL` still holds the GEOMETRIC normal while `fragment()` runs
	// — the normal map is applied after it — so reading `dot(NORMAL, VIEW)` on a flat quad
	// gives the same number for every fragment on the stone. The first version did exactly
	// that and every facet came out identical, which is a faceted stone rendered as a pane.
	//
	// The quad faces the camera, so tangent space is view space here.
	vec3 n = vec3(nrm, sqrt(max(0.05, 1.0 - dot(nrm, nrm))));
	float facet = length(nrm);
	// Against the REAL key, which is the project's standing rule applied to a stone: glass
	// is read off its faces unevenly, as a function of each face's normal against a light
	// that exists. A cut answers a light in flashes — whole faces at a time, and only the
	// two or three whose normals happen to point that way.
	vec3 h = normalize(key_dir + vec3(0.0, 0.0, 1.0));
	float flash = pow(clamp(dot(n, h), 0.0, 1.0), 80.0);

	// `transmission: 1` with `thickness: 0` is CLEAR glass, and the reference says in as
	// many words that "MeshPhysicalMaterial.opacity barely affects transmission glass"
	// (mesh.js:680) — so `opacity: 0.4` is not a 40% wash over the creature. Read as one it
	// buries the body under a coloured slab, which is what a first pass here did and what
	// this one had to be talked down from twice. The stone is nearly invisible across its
	// table; what you see of it is the ribs, the pitch of each face, and whichever of them
	// the key happens to be answering.
	// THE BLOW ABSORBED. Weighted by how squarely each facet faces where it came from, so
	// the struck side answers and the far side barely does — which is the same rule the
	// flashes follow and the reason this is a per-facet term rather than a wash over the
	// stone. A FIFTH of it is unweighted, because a struck gem does ring all over; at nearly
	// half the direction stopped reading and the whole stone simply lit.
	float took = ward_hit * (0.18 + 0.82 * max(0.0, dot(axis, -hit_from)));

	ALBEDO = tint.rgb;
	ALPHA = clamp(t * shell_opacity
		* (FACE + rib * RIB_A + facet * FACET_A + flash * FLASH_A + took * HIT_A), 0.0, 1.0);
	ROUGHNESS = rough;
	METALLIC = 0.0;
	SPECULAR = 0.5 + env_gain * 0.5;
	// The stage is dark and there is no environment map to catch, so the glint the
	// `envMapIntensity` buys there is spent here as emission — at the ribs and in the
	// flashes only, which is the only place it lands there either.
	EMISSION = (tint.rgb * facet * 0.14 + vec3(1.0) * (rib * (0.14 + took * 0.5)
		+ flash * 0.30)) * env_gain;
}
"""


const GLASS_SHADER: String = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley,
	specular_schlick_ggx;

// The shard shows THE CREATURE, refracted through its own thickness. That is
// the whole point of the shatter: the benchmark snapshots body+fire+glass and
// breaks the capture, so every flying piece carries the part of the monster it
// covered. A blank glass chip flying off a still-intact mob reads as debris.
uniform sampler2D body_tex : source_color, filter_linear_mipmap;
uniform float ior = 1.45;
uniform float bend = 0.055;     // how far the shard displaces what it holds
uniform float tint_a = 0.55;
uniform float rough = 0.12;
uniform float ignite = 0.0;
uniform vec3 tint = vec3(0.86, 0.93, 1.0);
uniform vec3 warm = vec3(1.0, 0.62, 0.26);
// `.enemy.marked .cracks` (styles.css:976) — the seams catch the light BEFORE
// the blow is thrown, so a lethal preview is read off the creature rather than
// off a number. Same Fresnel the death blaze uses, at a fraction of its gain
// and in the pale #ffeadf the stylesheet strokes the seams with, so an
// undamaged creature — which has no seams — shows nothing, exactly as there.
uniform float marked = 0.0;
const vec3 MARK = vec3(1.0, 0.918, 0.875);
// `.enemy.doomed .cracks path { stroke: #ffffff; opacity: 1 }` with a 7px white
// drop-shadow — the world-stop beat before a boss's glass gives way. The same
// Fresnel again, but PURE white at full opacity rather than the pale seam
// colour: this is the light already escaping, not a warning that it might.
uniform float doomed = 0.0;

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	vec3 r = refract(-v, n, 1.0 / ior);
	// UV arrives already in body space (see _prism), so the shard samples the
	// exact pixels it sits over — aligned by construction, flying or not.
	vec2 uv = UV + r.xy * bend;
	vec4 c = texture(body_tex, uv);
	float f = pow(1.0 - clamp(dot(n, v), 0.0, 1.0), 3.0);
	ALBEDO = mix(c.rgb * tint, vec3(1.0), f * 0.45);
	// Opaque where it holds the creature, glassy at its edges, and never so
	// transparent that a flying piece disappears.
	ALPHA = clamp(max(c.a, 0.10) * tint_a + f * 0.6 + ignite * 0.1, 0.0, 1.0);
	ROUGHNESS = rough;
	METALLIC = 0.0;
	SPECULAR = 0.5;
	// The fire wells up through the FRACTURES: Fresnel is high on the side band
	// and the rim, near zero across the face.
	EMISSION = warm * ignite * pow(f, 1.4) * 5.0 + c.rgb * ignite * 0.35
		+ MARK * marked * pow(f, 1.4) * 1.6
		+ vec3(1.0) * doomed * pow(f, 1.4) * 2.6;
}
"""


## Death debris is NOT the overlay glass. A flying shard must BE a piece of the
## creature — cap faces carry the painting at full strength (same alpha curve as
## the body, so the union of shards at the handoff frame IS the body), fracture
## faces run molten and cool, and the whole piece finally crumbles to nothing
## through a blocky hash so debris never ghost-fades or litters the stage.
const SHARD_SHADER: String = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley,
	specular_schlick_ggx;

uniform sampler2D body_tex : source_color, filter_linear_mipmap;
uniform float heat = 1.0;      // molten fracture edges + inner glow, cools to 0
uniform float dissolve = 0.0;  // 0 whole -> 1 burned away to nothing
//__ERODE__

const vec3 WARM = vec3(1.0, 0.60, 0.24);

void fragment() {
	vec4 c = texture(body_tex, UV);
	// _prism colors the side band red and the caps black: COLOR.r is literally
	// "this face is a fracture surface".
	float edge = COLOR.r;
	// Blocky hash over BODY uv: the piece crumbles away cell by cell instead of
	// ghost-fading, and neighbouring shards never vanish in sync.
	float h = fract(sin(dot(floor(UV * 90.0), vec2(12.9898, 78.233))) * 43758.5453);
	float gone = step(h, dissolve);
	float brink = (1.0 - smoothstep(0.0, 0.2, h - dissolve)) * step(0.001, dissolve);
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	float f = pow(1.0 - clamp(dot(n, v), 0.0, 1.0), 3.0);
	// A cap is THE PAINTING — these are pieces of the mob, not glass in front of
	// it. A fracture face is molten while hot, dark cooled glass after. Heat is
	// seasoning, never paint: push the glow past a whisper and every piece is
	// the same white-hot popcorn and the creature is gone AGAIN, just hotter.
	ALBEDO = mix(c.rgb, WARM * 0.5, edge * (0.2 + 0.3 * heat));
	// The cap term is the BODY's alpha, corroded exactly as the body corrodes it —
	// that is what makes the union of shards at the handoff frame the body. The
	// fracture term is a looser mask for the molten side band and is not a
	// silhouette, so the fringe never reaches it.
	float amask = smoothstep(0.05, 0.30, c.a);
	ALPHA = mix(eaten(body_tex, UV), amask, edge) * (1.0 - gone);
	ROUGHNESS = mix(0.55, 0.9, edge);
	METALLIC = 0.0;
	SPECULAR = 0.3;
	// The caps keep the body's own lantern glow (same pow(luma) curve as
	// BODY_SHADER) — a falling piece stays lit the way it was lit standing,
	// which is most of what makes it recognisably the same creature.
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114)) * c.a;
	// 0.90 on the fracture face, unchanged since the rite was built — and this comment used
	// to claim 0.30, which the code beside it never was. That was mine: `c122bb3` proposed
	// dropping it because carved slivers show more fracture face than Voronoi plates did, a
	// diagnostic then disproved the premise, the code was reverted and the justification was
	// not. A comment arguing for a number the file does not hold is worse than no comment,
	// so the record of what actually happened replaces it.
	//
	// The premise has now failed twice. Painting `COLOR.r` red proved the pale surfaces are
	// not fracture faces; zeroing this whole term proved they are not emission at all. See
	// `docs/fracture-model.md` §9 for where the tan does come from — it is the lighting, and
	// it is not a defect in this shader.
	EMISSION = WARM * (edge * heat * 0.9 + brink * 1.1 + f * heat * 0.3)
		+ c.rgb * (pow(l, 3.2) * 0.85 * (1.0 - edge) + heat * 0.25);
}
"""


static func meta(art_id: StringName) -> Dictionary:
	if _meta.is_empty():
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(META_PATH))
		if typeof(raw) == TYPE_DICTIONARY:
			_meta = raw
		else:
			push_warning("enemy view: %s unreadable — actors fall back to the gem"
				% META_PATH)
			_meta = {"chars": {}, "tierSizes": {}}
	var chars: Dictionary = _meta.get("chars", {})
	var entry: Dictionary = chars.get(String(art_id), {})
	return entry


## Where a creature's painting lives. Static because the mask below needs the same
## answer without an actor to ask, and two copies of the search order is two places
## for a folder move to break.
static func art_texture(art_id: StringName) -> Texture2D:
	if art_id == &"":
		return null
	for pattern: String in ART_DIRS:
		var path: String = pattern % art_id
		if ResourceLoader.exists(path):
			return load(path)
	return null


## Mask resolution. One propagator step is `FractureField.STEP` = 0.012 body, so at
## 256 a step spans three texels and `BodyMask.reaches` gets three probes across it
## — enough to catch any gap wide enough to stop a real crack. Full resolution would
## buy nothing but a 4 MB CPU image per painting.
const MASK_RES: int = 256


## The creature's silhouette, for the fracture model. Cached, decompressed, and
## downsampled — see `MASK_RES`. A creature with no painting gets the rectangle
## rather than nothing, because a crack that runs to the box edge is a better
## failure than one that arrests on its first step.
static func body_mask(art_id: StringName) -> BodyMask:
	if _mask_cache.has(art_id):
		var hit: BodyMask = _mask_cache[art_id]
		return hit
	var mask: BodyMask = BodyMask.rect()
	var tex: Texture2D = art_texture(art_id)
	if tex != null:
		var img: Image = tex.get_image()
		if img != null:
			img = img.duplicate()
			if img.is_compressed():
				img.decompress()
			img.resize(MASK_RES, MASK_RES, Image.INTERPOLATE_BILINEAR)
			mask = BodyMask.from_image(img)
	_mask_cache[art_id] = mask
	return mask


## The benchmark's own size formula: tierSizes[tier] * scale (bfEnemySize).
static func art_box(art_id: StringName) -> float:
	var entry: Dictionary = meta(art_id)
	if entry.is_empty():
		return 0.0
	var tiers: Dictionary = _meta.get("tierSizes", {})
	var base: float = tiers.get(str(entry.get("tier", "normal")), 185)
	var scale: float = entry.get("scale", 1.0)
	return base * scale


## Editor seam. char-meta.json is presentation tuning data, not content and not
## a fixture, so the bench edits it in place — the same job the benchmark's
## ?charedit=1 does by rewriting src/char-meta.js. res:// is writable in a debug
## run; an exported build would have to keep its overrides in user://.
static func set_meta_value(art_id: StringName, key: String, value: Variant) -> void:
	meta(art_id)  # force the load before anyone mutates it
	var chars: Dictionary = _meta.get("chars", {})
	var entry: Dictionary = chars.get(String(art_id), {})
	entry[key] = value
	chars[String(art_id)] = entry
	_meta["chars"] = chars


static func save_meta() -> bool:
	var f: FileAccess = FileAccess.open(META_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("enemy view: cannot write %s" % META_PATH)
		return false
	f.store_string(JSON.stringify(_meta, "  "))
	f.close()
	return true


## `art_id` stays optional: a caller that does not pass one gets exactly the
## avatar it got before the paintings landed, because GlassGem is the missing-art
## fallback here just as enemySvg() is in the benchmark (assets.js:7).
func _init(enemy_idx: int, display_name: String, hue: float = 210.0,
		art_id: StringName = &"") -> void:
	idx = enemy_idx
	_hue = hue
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex: Texture2D = art_texture(art_id)
	if art_id != &"" and tex == null:
		push_warning("enemy view: no painting for %s" % art_id)

	if tex != null:
		var entry: Dictionary = meta(art_id)
		tier = str(entry.get("tier", "normal"))
		art_size = art_box(art_id)
		if art_size <= 0.0:
			art_size = 185.0
		var fx: float = entry.get("footX", 0.0)
		var fy: float = entry.get("footY", 0.0)
		foot = Vector2(fx, fy)
		_read_idle(entry)
		_read_aim(entry)
		_read_hover(entry)
		custom_minimum_size = Vector2(art_size, art_size)
		size = custom_minimum_size
		_rng.seed = hash(String(art_id)) + enemy_idx
		_frac_seed = _stable_seed(String(art_id), enemy_idx)
		_frac = Rng.new(_frac_seed)
		_art_id = art_id
		_build_stage(tex, enemy_idx)
	else:
		# No painting: the procedural gem, at the box it has always used. This is
		# also the world map's emblem widget, so it is left exactly alone.
		custom_minimum_size = Vector2(150, 92)
		size = custom_minimum_size
		art_size = 92.0
		_gem = GlassGem.new()
		_gem.set_anchors_preset(Control.PRESET_FULL_RECT)
		_gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_gem.set_state(_hue, 1.0, false)
		add_child(_gem)

	_build_chrome(display_name)


func _ready() -> void:
	if _stage == null:
		return
	# The stage is sized against the SCREEN, so it has to be resized when the
	# window is. `_init` cannot do this: at that point the node is not in the
	# tree, and even at `_ready` the window is still at its project size —
	# measured here as scale 1.000 at `_ready` and 3.068 thirty frames later.
	get_viewport().size_changed.connect(_fit_stage)
	_fit_stage()


## Canvas units are not pixels, and `oversample` is a promise about pixels.
##
## `stretch/mode = "canvas_items"` (project.godot) fixes the canvas at 1180x820
## units whatever the window measures, so the whole composition is scaled by
## `window / 1180` on its way to the screen. `_display` is `_span` canvas units
## across, so a stage sized from `_span` alone is divided by exactly that scale.
##
## Measured with the window filling a 4112x2658 screen: canvas scale 3.068, an
## elite's `_display` covering 1614 screen pixels, its stage supplying 1052
## texels — **0.65 texels per pixel**. The 2.0 above was not a supersample at
## all; it was a 1.53x MAGNIFICATION, and the silhouette on screen was a
## bilinear blow-up of a render that never held the detail. Multiplying by the
## scale is what makes the constant mean again what it was judged to mean.
##
## `VP_MAX` is where the promise runs out, and it is an arithmetic wall rather
## than a round number. Stage memory runs about 49 MB per megapixel
## (docs/actor-stage-frame-budget.md: 0.6 Mpx → 162 MB, 3.6 Mpx → 310 MB), the
## proposed budget for a four-actor fight is 200 MB and the fight already spends
## 248. Keeping the promise at scale 3.068 wants 9.4x the stage pixels — about
## 1.2 GB. So above roughly a 2x window the cap binds on purpose and the actor
## renders below the mark. **That shortfall is an architecture bill — one MSAA
## 4x stage per actor — not a knob**, and `VP_MAX` is the single line to turn
## down if the memory matters more than the edge.
func _fit_stage() -> void:
	if _stage == null or not is_inside_tree():
		return
	var scale: float = maxf(1.0, get_viewport_transform().get_scale().x)
	var want: int = ceili(_span * scale * oversample)
	# Quantised, because a live window drag would otherwise reallocate four
	# render targets on every frame of the drag for sub-texel gains.
	var px: int = clampi(ceili(want / 64.0) * 64, 64, VP_MAX)
	if _stage.size.x != px:
		_stage.size = Vector2i(px, px)


# ---------------------------------------------------------------- the 3D stage

func _build_stage(tex: Texture2D, enemy_idx: int) -> void:
	_span = art_size * (1.0 + 2.0 * PAD_FRAC)
	_box_u = art_size * UNIT
	var aspect: float = 1.0
	if tex.get_height() > 0:
		aspect = float(tex.get_width()) / float(tex.get_height())
	_quad_w = _box_u * aspect
	_read_contact(tex)

	_stage = SubViewport.new()
	var vp_px: int = mini(int(_span * oversample), VP_MAX)
	_stage.size = Vector2i(vp_px, vp_px)
	_stage.own_world_3d = true
	_stage.transparent_bg = true
	_stage.msaa_3d = msaa
	_stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_stage)

	# A real sky, used ONLY as light. background_mode stays CLEAR_COLOR so the
	# viewport keeps its alpha, while ambient and reflections still come off the
	# sky's radiance map — that is what gives the shards something to mirror.
	_env = Environment.new()
	_env.background_mode = Environment.BG_CLEAR_COLOR
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_env.ambient_light_energy = 0.22
	var sky: Sky = Sky.new()
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	# The night-lantern key the rest of the screen is lit by: deep indigo dome,
	# ember bounce off the ground.
	sky_mat.sky_top_color = Color(0.05, 0.07, 0.16)
	sky_mat.sky_horizon_color = Color(0.16, 0.18, 0.30)
	sky_mat.ground_bottom_color = Color(0.16, 0.09, 0.05)
	sky_mat.ground_horizon_color = Color(0.22, 0.14, 0.08)
	sky.sky_material = sky_mat
	_env.sky = sky
	# LINEAR, not ACES: the filmic curve lifts blacks and desaturates, which on a
	# painting that is already 80% near-black reads as fog over the whole mob.
	_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.environment = _env
	_stage.add_child(world_env)

	# Key: the lantern above and to the left, warm.
	_key = DirectionalLight3D.new()
	_key.light_color = Color(1.0, 0.86, 0.68)
	_key.light_energy = 1.5
	_key.rotation_degrees = Vector3(-38.0, -32.0, 0.0)
	_stage.add_child(_key)
	# Rim: cold glass-blue from behind, so the silhouette separates from night.
	_rim = OmniLight3D.new()
	_rim.light_color = GlassStyle.GLASS
	_rim.light_energy = 1.8
	_rim.omni_range = _box_u * 4.0
	_rim.position = Vector3(_box_u * 0.7, _box_u * 0.5, -_box_u * 0.9)
	_stage.add_child(_rim)
	# Fire: dark until the vessel ignites, then it is the light inside the glass.
	_fire = OmniLight3D.new()
	_fire.light_color = GlassStyle.EMBER
	_fire.light_energy = 0.0
	_fire.omni_range = _box_u * 3.0
	_fire.position = Vector3(0.0, 0.0, -_box_u * 0.25)
	_stage.add_child(_fire)

	# Body and glass share ONE node. The idle motion is this node's transform, so
	# a crack can never drift off the creature it was scored into.
	_vessel = Node3D.new()
	_stage.add_child(_vessel)
	_phase = float(enemy_idx) * 1.7

	_quad = MeshInstance3D.new()
	# `PlaneGeometry(2, 2, SEG_X, SEG_Y)` (mesh.js:314) — a SUBDIVIDED plane, and
	# that is the whole reason the benchmark's creatures look alive: the idle is a
	# vertex deformation, so a body bends. A single quad can only be moved
	# rigidly, which is what this port was doing.
	var qm: PlaneMesh = PlaneMesh.new()
	qm.size = Vector2(_quad_w, _box_u)
	qm.orientation = PlaneMesh.FACE_Z
	qm.subdivide_width = SEG_X
	qm.subdivide_depth = SEG_Y
	_quad.mesh = qm
	var sh: Shader = Shader.new()
	sh.code = with_erode(BODY_SHADER)
	_body_mat = ShaderMaterial.new()
	_body_mat.shader = sh
	_body_mat.set_shader_parameter("body_tex", tex)
	_body_mat.set_shader_parameter("erode", erode_uv)
	_body_mat.set_shader_parameter("flare_gain", flare_gain)
	# Their plane is 2 units across, so a displacement of 0.028 is 1.4% of the
	# half-height. `idle_gain` puts that back into world units, INTENSITY and all.
	_body_mat.set_shader_parameter("half_w", _quad_w * 0.5)
	_body_mat.set_shader_parameter("idle_gain", _box_u * 0.5 * IDLE_INTENSITY)
	_body_mat.set_shader_parameter("idle_seed", _phase)
	_push_profile()
	_body_mat.set_shader_parameter("aim_tint",
		Vector3(_aim_tint.r, _aim_tint.g, _aim_tint.b))
	_body_mat.set_shader_parameter("aim_width", _aim_width)
	_body_mat.render_priority = -1   # drawn before the glass
	_quad.set_surface_override_material(0, _body_mat)
	_vessel.add_child(_quad)

	_glass_root = Node3D.new()
	_vessel.add_child(_glass_root)

	# The shell hangs off the VESSEL, so it travels with the recoil and the sway,
	# and carries its OWN geometry, so it does not bend with the idle: "own geo —
	# shell shape/scale independent of body warp" (mesh.js:738). A warped ward is
	# a ward made of the same stuff as the creature, which is the opposite of
	# what it is.
	_build_ward_shell()

	# Outside the vessel: the ground does not breathe with the creature.
	_build_shadow(tex)

	# Ground for the shards to land on, at the creature's own feet.
	var floor_body: StaticBody3D = StaticBody3D.new()
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(_box_u * 6.0, _box_u * 0.1, _box_u * 6.0)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	floor_body.position = Vector3(0.0, -_box_u * 0.5 - _box_u * 0.05, 0.0)
	floor_body.physics_material_override = _bounce()
	_stage.add_child(floor_body)

	_cam = Camera3D.new()
	_cam.fov = FOV_DEG
	var dist: float = (_span * UNIT) * 0.5 / tan(deg_to_rad(FOV_DEG * 0.5))
	_cam.position = Vector3(0.0, 0.0, dist)
	_cam.near = dist * 0.25
	_cam.far = dist * 3.0
	_stage.add_child(_cam)

	var pad: float = art_size * PAD_FRAC

	# Added BEFORE the body, because a drop-shadow is behind what casts it. It
	# shares the body's texture and geometry exactly, so the halo cannot drift off
	# the creature when the vessel breathes.
	_display = TextureRect.new()
	_display.texture = _stage.get_texture()
	_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_display.stretch_mode = TextureRect.STRETCH_SCALE
	_display.position = Vector2(-pad, -pad)
	_display.size = Vector2(_span, _span)
	_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The reseam shimmer needs a channel `modulate` cannot give it, because
	# `saturate()` is a mix towards luminance and not a multiply. At rest the
	# shader is the identity, so this costs the frame nothing until a pane
	# shatters.
	_display_mat = ShaderMaterial.new()
	var reseam_sh: Shader = Shader.new()
	reseam_sh.code = RESEAM_SHADER
	_display_mat.shader = reseam_sh
	_display.material = _display_mat
	add_child(_display)


## `0.7s ease-out` with its only stop at 30%: the shimmer peaks fast and takes
## more than twice as long to leave. CSS applies the timing function PER
## INTERVAL, so ease-out runs once up to the peak and again back down — which is
## not the same curve as one eased pass through 0 → 1 → 0.
const RESEAM_MS: float = 0.7
const RESEAM_AT: float = 0.3
const RESEAM_BRIGHT: float = 1.55
const RESEAM_SAT: float = 0.55
## CSS `ease-out`, spelled out. `Motion` carries `ease-in-out` and the two
## authored curves; this one is only ever asked for here.
const CSS_EASE_OUT: Array[float] = [0.0, 0.0, 0.58, 1.0]
## `choreoStagger` — the death slump, and the one animation here that does NOT
## return: `fill: forwards` leaves the body dropped, tilted and dimmed for the
## ignition that follows it.
const STAGGER_TIME: float = 0.36
const STAGGER_DROP: float = 5.0
const STAGGER_TILT: float = -2.5
const STAGGER_DIM: float = 0.6

## `.enemy.reseaming .enemy-art { animation: reseam 0.7s ease-out }` with
## `@keyframes reseam { 30% { filter: brightness(1.55) saturate(0.55); } }`
## (styles.css:1076). Two CSS filters, and neither is `modulate`: brightness IS a
## multiply, but `saturate(s)` is `mix(luminance, base, s)` and a CanvasItem has
## no channel for it. At the identity (1, 1) this shader hands the texture
## straight back.
const RESEAM_SHADER: String = """
shader_type canvas_item;

uniform float bright : hint_range(0.0, 4.0) = 1.0;
uniform float sat : hint_range(0.0, 2.0) = 1.0;

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	vec3 lum = vec3(dot(src.rgb, vec3(0.213, 0.715, 0.072)));
	COLOR = vec4(mix(lum, src.rgb, sat) * bright, src.a);
}
"""


## The cast shadow, and the reason it is nine knobs lighter than the benchmark's.
##
## The web shadow is a black copy of the sprite squashed by hand: --sh-sx/sy,
## --sh-skew, --sh-x/y, --sh-blur, --foot-ox/oy, --sh-o, authored per creature
## (styles.css .cast-shadow). Every one of those numbers is a person estimating
## where a light they do not have would throw the silhouette, because CSS cannot
## project. Here there IS a light, so the shape is derived: the lean and length
## come from the key's direction, the contact point from the painting's own
## alpha, the softening from distance off the ground. What is left to author is
## opacity.
##
## The projection runs in the VERTEX stage rather than in the node's basis, and
## that is not a refactor for its own sake: a basis can only shear about one
## origin, so a basis-projected shadow has exactly one contact line. Per column
## it has to be per vertex. Doing it here also retires a trap the basis version
## carried — `Node3D.scale` is derived from the basis, so writing it after a
## sheared basis silently re-orthonormalised the shear away.
const SHADOW_SHADER: String = """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

uniform sampler2D body_tex : source_color, filter_linear_mipmap;
// The ground line, one sample per painting column, as a texture v. Linear
// filtering is what turns 64 samples into a continuous line under the feet.
uniform sampler2D ground_tex : filter_linear, repeat_disable;
uniform float opacity = 0.55;
uniform float softness = 1.0;
uniform float box_u = 1.0;
// Where the mesh origin sits in the painting, as a v — the lowest contact.
uniform float contact_v = 1.0;
// The projection, resolved on the CPU from the key light: how far the cast runs
// per unit of height, how far it leans doing it, and how wide it stays.
uniform float cast_run = 1.0;
uniform float cast_lean = 0.0;
uniform float cast_wide = 1.0;
uniform float tilt_cos = 0.208;
uniform float tilt_sin = 0.978;

// Height above THIS column's ground, in box heights. The fragment stage wants it
// too: a contact shadow is sharp at the contact and diffuses with distance, and
// with four feet at four heights "distance" is per column as well.
varying float v_far;

void vertex() {
	// UV.y 1 is the bottom of the painting, so a SMALLER v is higher up.
	float gv = texture(ground_tex, vec2(UV.x, 0.5)).r;
	v_far = clamp(gv - UV.y, 0.0, 1.0);
	float h = v_far * box_u;
	// The column's own contact, in mesh space: the mesh origin is the lowest
	// contact, and this column's sits that much higher.
	float gy = (contact_v - gv) * box_u;
	VERTEX = vec3(
		VERTEX.x * cast_wide + h * cast_lean,
		gy + h * cast_run * tilt_cos,
		-h * cast_run * tilt_sin);
}

void fragment() {
	float r = (0.003 + 0.035 * v_far) * softness;
	float a = 0.0;
	for (int i = -1; i <= 1; i++) {
		for (int j = -1; j <= 1; j++) {
			a += texture(body_tex, UV + vec2(float(i), float(j)) * r).a;
		}
	}
	a /= 9.0;
	ALBEDO = vec3(0.0);
	ALPHA = smoothstep(0.04, 0.55, a) * opacity * (1.0 - v_far * 0.5);
}
"""

## How far the ground plane is tipped from the picture plane. cos(78°) = 0.208,
## near the benchmark's --sh-sy default of 0.24 — the same foreshortening,
## except here it is a plane the light projects onto rather than a scale factor.
const GROUND_TILT_DEG: float = 78.0
## How far the cast may run, in body heights. The projection alone would put the
## key's 38° pitch at 1.6 body heights, which is true and looks wrong: in a
## side-on view a long cast reads as the creature hovering over its own shadow.
## Clamped to a ground POOL that leans with the light instead of a dramatic
## throw — the benchmark lands in the same place with sx 1.0 / sy 0.24.
##
## Restated ×1.137 from 0.6/1.15 when the ground line went per column, and that
## is a restoration rather than a new judgement. Height used to be measured from
## the LOWEST contact, which overstates it for every column standing on higher
## ground; measured across the 27 paintings, weighted by silhouette, the per-column
## line REDUCED mean height by 12.0% (`shade` 21.1%, `sovereign` 0.3%). The factor
## is that reduction inverted — 1/(1 - 0.120) = 1.137, not 1.12 — because the
## clamp multiplies the height rather than being measured in it. So the old clamp
## was judged against a cast that ran 12% long, and leaving it alone would have
## let a geometry fix quietly shorten every shadow in the game. The look these
## two numbers encode is the thing being preserved; the arithmetic under it
## changed.
const CAST_MIN: float = 0.68
const CAST_MAX: float = 1.31


## Read the contact point off the painting instead of authoring --foot-ox/oy:
## the lowest opaque row is where the creature meets the ground, and the
## horizontal centroid of that band is where its weight sits. Downsampled first
## — a contact point does not need 1024 rows, and a per-pixel scan of the full
## image in GDScript would cost more than the whole stage build.
func _read_contact(tex: Texture2D) -> void:
	var img: Image = tex.get_image()
	if img == null:
		return
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.resize(64, 64, Image.INTERPOLATE_BILINEAR)
	var bottom: int = -1
	for y: int in range(63, -1, -1):
		for x: int in range(64):
			if img.get_pixel(x, y).a > 0.15:
				bottom = y
				break
		if bottom >= 0:
			break
	if bottom < 0:
		return
	var sum: float = 0.0
	var weight: float = 0.0
	for y: int in range(maxi(bottom - 4, 0), bottom + 1):
		for x: int in range(64):
			var a: float = img.get_pixel(x, y).a
			sum += float(x) * a
			weight += a
	if weight > 0.0:
		_contact_u = (sum / weight + 0.5) / 64.0
	_contact_v = (float(bottom) + 1.0) / 64.0
	_art_pad = (1.0 - _contact_v) * _box_u
	_read_ground(img, bottom)


## How far above the lowest contact a silhouette's bottom edge may still be
## standing on the ground. Everything within the band is read as a contact;
## everything above it is read as body — a belly between legs, a tail in the air,
## a cloak that does not reach — and the ground is interpolated underneath it
## from the contacts on either side.
##
## 0.15 of a box is not a taste knob, it is the gap between two populations.
## Measured across all 27 paintings, the widest spread of admitted contacts is
## 0.141 of a box — thirteen of them reach it, `duskfang` among them — while the
## nearest feature that is plainly NOT footing, `duskfang`'s belly at 0.188 and
## its tail at 0.25, sits above. So the band has to land inside [0.141, 0.188],
## and 0.15 does.
##
## Read that measurement honestly: it is partly circular, because the spread it
## reports is the spread of whatever this same band admitted. It cannot see a
## creature whose feet genuinely span more than 0.15, and no painting on the
## current roster is known to. Widening the band is what would reveal one — so if
## a new painting stands with its shadow starting mid-leg, raise this and re-read
## the spread before assuming the scan is at fault.
const CONTACT_BAND: float = 0.15
## One ground sample per column of the 64-wide scan `_read_contact` already runs.
const GROUND_N: int = 64


## Derive the ground line from the painting's own silhouette.
##
## For each column, the lowest opaque row is a candidate contact. Those within
## `CONTACT_BAND` of the lowest are taken as real, and the line is interpolated
## between them across everything else — so a belly is spanned rather than stood
## on, and a tail that hangs in the air is given the ground under the feet beside
## it rather than a ground of its own.
##
## Columns with no paint at all get the same treatment and it costs nothing: the
## shadow's alpha comes from the same silhouette, so a column the creature does
## not occupy casts nothing wherever its ground line happens to land.
func _read_ground(img: Image, bottom: int) -> void:
	var xs: PackedFloat32Array = PackedFloat32Array()
	var rows: PackedFloat32Array = PackedFloat32Array()
	var band: float = float(bottom) - CONTACT_BAND * float(GROUND_N)
	for x: int in range(GROUND_N):
		var low: int = -1
		for y: int in range(GROUND_N - 1, -1, -1):
			if img.get_pixel(x, y).a > 0.15:
				low = y
				break
		if low >= 0 and float(low) >= band:
			xs.append(float(x))
			rows.append(float(low))
	if xs.is_empty():
		return
	# `v` for the shader, not a row: the vertex stage compares it against UV.y.
	var line: PackedFloat32Array = PackedFloat32Array()
	for x: int in range(GROUND_N):
		line.append((_interp(float(x), xs, rows) + 1.0) / float(GROUND_N))
	var strip: Image = Image.create_from_data(GROUND_N, 1, false, Image.FORMAT_RF,
		line.to_byte_array())
	_ground_tex = ImageTexture.create_from_image(strip)


## One flat line at the lowest contact, for a painting whose alpha reads nothing.
func _flat_ground() -> ImageTexture:
	var line: PackedFloat32Array = PackedFloat32Array()
	line.resize(GROUND_N)
	line.fill(_contact_v)
	return ImageTexture.create_from_image(Image.create_from_data(
		GROUND_N, 1, false, Image.FORMAT_RF, line.to_byte_array()))


## Piecewise-linear through the samples, held flat beyond the ends. Written out
## because GDScript has no `Array` lerp over a second array, and the alternative
## — a Curve resource — would put an editable artefact in the way of a number
## that is measured, never authored.
static func _interp(x: float, xs: PackedFloat32Array,
		ys: PackedFloat32Array) -> float:
	var n: int = xs.size()
	if x <= xs[0]:
		return ys[0]
	if x >= xs[n - 1]:
		return ys[n - 1]
	var i: int = 1
	while i < n and xs[i] < x:
		i += 1
	var span: float = xs[i] - xs[i - 1]
	if span <= 0.0:
		return ys[i]
	return lerpf(ys[i - 1], ys[i], (x - xs[i - 1]) / span)


func _build_shadow(tex: Texture2D) -> void:
	_shadow = MeshInstance3D.new()
	# SUBDIVIDED, and for the same reason the body's plane is: the shape is a
	# vertex deformation now. One quad has four corners and therefore one ground
	# line; a column of vertices per ground sample is what lets each foot stand on
	# its own. Vertically two rows would do — the projection is linear in height —
	# but the ground clamp puts a kink at the contact, so it gets a few more.
	var qm: PlaneMesh = PlaneMesh.new()
	qm.size = Vector2(_quad_w, _box_u)
	qm.orientation = PlaneMesh.FACE_Z
	qm.subdivide_width = GROUND_N - 1
	qm.subdivide_depth = 8
	# Origin on the CONTACT POINT the painting was measured for — the lowest
	# opaque row, at the weight centroid of the band above it. Not the quad's
	# corner: this quad carries the same texture as the body, so the creature is
	# already placed inside it, and a hinge anywhere else casts a shadow of a
	# creature standing somewhere the creature is not. The bottom edge was close
	# enough for anything drawn centred over its own feet and 15% of a body wide
	# of the mark for `duskfang`, which stands on paws far to the left of frame.
	qm.center_offset = Vector3(
		-(_contact_u - 0.5) * _quad_w, _box_u * 0.5 - _art_pad, 0.0)
	_shadow.mesh = qm
	var sh: Shader = Shader.new()
	sh.code = SHADOW_SHADER
	_shadow_mat = ShaderMaterial.new()
	_shadow_mat.shader = sh
	_shadow_mat.render_priority = -2   # under the body (-1) and the glass (1)
	_shadow_mat.set_shader_parameter("body_tex", tex)
	_shadow_mat.set_shader_parameter("box_u", _box_u)
	_shadow_mat.set_shader_parameter("contact_v", _contact_v)
	_shadow_mat.set_shader_parameter("tilt_cos", cos(deg_to_rad(GROUND_TILT_DEG)))
	_shadow_mat.set_shader_parameter("tilt_sin", sin(deg_to_rad(GROUND_TILT_DEG)))
	# A painting with no readable contact at all falls back to one flat line at
	# the lowest opaque row, which is exactly the behaviour before the ground line.
	_shadow_mat.set_shader_parameter("ground_tex",
		_ground_tex if _ground_tex != null else _flat_ground())
	_shadow.set_surface_override_material(0, _shadow_mat)
	_stage.add_child(_shadow)
	# Position belongs to `_update_shadow` now, not here: the contact point moves
	# with the body's height and cannot be written once at build.
	_update_shadow()


## Project the silhouette along the key light. This is the entire shadow model:
## run per unit height gives the lean, its magnitude gives the length, and the
## ground tilt does the foreshortening. Swing the key and the shadow swings —
## which the authored version could never do at any number of knobs.
##
## The lift response is the half that was missing. The benchmark resynchronises
## its darkened copy against the body's live transform on every frame of the rig
## loop (`spriteLiftPx` + `meshLift` into `syncCastShadow`,
## `src/ui/combat.js:1795-1819`, `src/ui/combat.js:1930-1932`). This ran twice in
## an actor's whole life — at build and at reset — and read its only variable off
## the painting's transparent border, which is framing rather than height (see
## `_art_pad`). Height now comes from the body's own transform.
##
## And because there is a real light here, height does the one thing nine
## authored knobs could not buy: the contact point MOVES. A rising creature
## slides its shadow along the light's ground track and leaves it behind, which
## is the cue the eye actually reads as distance. CSS cannot project, so over
## there a rising creature only got a smaller copy in the same place — and the
## five floaters carry a hand-set `shadow.dy` shove to paper over it.
func _update_shadow() -> void:
	if _shadow == null or _key == null:
		return
	var l: Vector3 = -_key.transform.basis.z
	# A light at or below the horizon would throw the shadow to infinity.
	l.y = minf(l.y, -0.12)
	var run: float = clampf(1.0 / -l.y, CAST_MIN, CAST_MAX)
	# Height off the ground: whatever raised the body, plus the resting hover the
	# painting was made with. Floored at zero exactly as `spriteLiftPx` is — a
	# body driven DOWN does not push its shadow underground.
	var hover: float = _hover_rest
	if _vessel != null:
		hover += maxf(0.0, _vessel.position.y)
	# `floatKinds` measures the ANIMATED lift over there, because `dy` is not part
	# of `lift` at all — it is applied straight to the box. Here the resting hover
	# goes through the projection with everything else, so the ceiling has to
	# cover both or the four creatures whose `dy` already meets their kind's
	# span — `watcherEye` 24 against 20, `shade` 16 against 14, `voltEel` 13
	# against 12, `sporeling` 10 against 10 — would sit pinned at full fade with
	# no room left to answer their own bob.
	var f: float = clampf(hover / maxf(_hover_rest + _hover_span, 0.0001), 0.0, 1.0)
	# `syncCastShadow`'s own response at full lift, ported: width ×(1-.26t),
	# length ×(1-.5t), opacity ×(1-.55t), and blur 1.5px +2.8t — a ×2.87
	# softening. Its skew relax is deliberately NOT ported: over there the lean
	# is a hand-set fake that had to be walked back at height, here it is the
	# projection, and a body further off the ground does not lean less.
	var wide: float = 1.0 - f * 0.26
	var long: float = 1.0 - f * 0.5
	# The shear the basis used to carry, handed to the vertex stage — where it can
	# be applied about each column's own contact rather than about one origin.
	_shadow_mat.set_shader_parameter("cast_run", run * long)
	_shadow_mat.set_shader_parameter("cast_lean",
		clampf(l.x * run, -1.2, 1.2) * long)
	_shadow_mat.set_shader_parameter("cast_wide", wide)
	# Put the mesh's contact origin back onto the body's own foot line, so the
	# projection starts where the creature meets the ground and the CAST slides
	# out from there: that is what separation means. This pairs with the
	# `center_offset` in `_build_shadow` — the two must move together or the
	# silhouette shifts off the body by exactly the offset applied to one of them.
	#
	# `_hover_rest` DROPS that line, and this is the half of `dy` that was missing.
	# The ground line is read off the silhouette's lowest opaque row, which for a
	# creature painted already airborne is not a contact at all — it is the bottom
	# of a hovering body. `dy` is the one number that says so, and saying so has to
	# mean the ground is that much lower. It was only sliding the cast sideways
	# along the light's track, which is the other half and, under a camera looking
	# dead on, the weaker cue of the two: `watcherEye`'s shadow hung off its own
	# tassels. The LIVE part of the hover is deliberately left out — a body driven
	# up by the idle moves away from a ground that stays where it is.
	_shadow.position = Vector3(
		(_contact_u - 0.5) * _quad_w + hover * l.x * run,
		-_box_u * 0.5 + _art_pad - _hover_rest, 0.0)
	_shadow_mat.set_shader_parameter("opacity",
		_shadow_opacity * _shadow_fade * (1.0 - f * 0.55))
	_shadow_mat.set_shader_parameter("softness", 1.0 + f * 1.87)


static func _bounce(bounce: float = 0.28, friction: float = 0.7) -> PhysicsMaterial:
	var pm: PhysicsMaterial = PhysicsMaterial.new()
	pm.bounce = bounce
	pm.friction = friction
	return pm


## One glass material shared by every shard, so a tuning slider is one write.
func _glass_material() -> ShaderMaterial:
	if _glass_mat != null:
		return _glass_mat
	var sh: Shader = Shader.new()
	sh.code = GLASS_SHADER
	_glass_mat = ShaderMaterial.new()
	_glass_mat.shader = sh
	_glass_mat.render_priority = 1   # after the body
	if _body_mat != null:
		_glass_mat.set_shader_parameter("body_tex",
			_body_mat.get_shader_parameter("body_tex"))
	return _glass_mat


## Idle. A standing creature that never moves reads as a sticker, so the vessel
## leans and swells — as a TRANSFORM, which the glass rides along with. When the
## rite begins the idle hands over to the STRAIN — a rising quiver and swell, the
## vessel failing to contain its own fire — and after the burst the camera
## carries a short shake while the shards own their own motion.
func _process(delta: float) -> void:
	# `pvPulse 0.9s ease-in-out infinite` with `50% { opacity: 0.4 }`. The
	# easing runs the whole iteration and the keyframes interpolate linearly
	# between offsets, which is why the dip is read at an already-eased t.
	if _hp_preview != null and _hp_preview.visible:
		_preview_t = fmod(_preview_t + delta, PREVIEW_PULSE)
		var e: float = Motion.ease(Motion.EASE_IN_OUT, _preview_t / PREVIEW_PULSE)
		_hp_preview.modulate.a = Motion.keyframe(e, [0.0, 0.5, 1.0],
			[1.0, PREVIEW_DIP, 1.0])
	_step_ward(delta)
	if _cam != null and _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 4.5)
		var kick: float = _box_u * 0.02 * _shake * _shake
		_cam.h_offset = _rng.randf_range(-kick, kick)
		_cam.v_offset = _rng.randf_range(-kick, kick)
	if _vessel == null:
		return
	var t: float = Time.get_ticks_msec() * 0.001 + _phase
	if _dead:
		if _vessel.visible and _ignite > 0.0:
			var q: float = _ignite * _ignite
			var amp: float = _box_u * 0.009 * q
			_vessel.position = Vector3(
				sin(t * 61.0) * amp, sin(t * 47.0) * amp * 0.7, 0.0)
			var s: float = 1.0 + 0.03 * q
			_vessel.scale = Vector3(s, s, 1.0)
		return
	# The idle is no longer here. It used to be three sine terms writing the
	# vessel's scale, rotation and position — one rigid card being wobbled, which
	# is a different animal from a body that BENDS. It now lives in the vertex
	# stage (`deformPlane`), weighted by height so the feet stay planted, and this
	# function is left with only the things that really do move the whole body.
	_idle_t += delta
	if _body_mat != null:
		_body_mat.set_shader_parameter("idle_t", _idle_t)
	# The recoil rides ON the idle rather than being tweened onto the vessel: this
	# function rewrites scale and position every frame, so a Tween aimed at either
	# would be erased before it was ever seen. `_hit` and `_hit_squash` are the
	# tweened values; composing them here is what makes the two coexist.
	# The kind layer — one of `idleFloat` / `idleSlime` / `idleSway` /
	# `idleBreathe`, and never more than one. Composed here for the same reason
	# the recoil is: this function rewrites scale, rotation and position every
	# frame, so a Tween aimed at any of the three would be erased unseen.
	var kind_x: float = 0.0
	var kind_y: float = 0.0
	var kind_sx: float = 1.0
	var kind_sy: float = 1.0
	var kind_rot: float = 0.0
	if _kind_idle != &"":
		var u: float = fposmod(t, _kind_period) / _kind_period
		match _kind_idle:
			&"float":
				kind_y = _hover_amp * Motion.css_pulse(u, 0.0, 1.0)
			&"slime":
				# CSS `translateY` is DOWN; a Godot basis counts up. The +2px stop
				# really does sink the body under the line, and the shadow reads
				# `max(0, y)` exactly as `spriteLiftPx` does, so the dip is its own
				# beat and not a shadow underground.
				kind_y = -Motion.css_keyframe(u, SLIME_AT, SLIME_Y) * UNIT
				kind_sx = Motion.css_keyframe(u, SLIME_AT, SLIME_SX)
			&"sway":
				kind_x = Motion.css_pulse(u, 0.0, SWAY_X) * UNIT
				# CSS `rotate` is clockwise on screen and +Z is anticlockwise.
				kind_rot = -deg_to_rad(Motion.css_pulse(u, 0.0, SWAY_DEG))
			&"breathe":
				kind_sy = Motion.css_pulse(u, 1.0, BREATHE_SY)
	_vessel.scale = Vector3(
		(1.0 - SQUASH * _hit_squash) * _lunge_scale.x * kind_sx,
		(1.0 + SQUASH * _hit_squash) * _lunge_scale.y * kind_sy, 1.0)
	_vessel.rotation.z = kind_rot
	# `float` is the one idle term that is NOT a warp: a whole-body lift in stage
	# px, never negative, so a wisp hangs above the line it was placed on rather
	# than sinking through it.
	var lift: float = 0.0
	if _idle_float > 0.0:
		lift = maxf(0.0, _idle_float * FLOAT_PX * IDLE_INTENSITY
			* sin(t * FLOAT_RATE + _phase * 0.7)) * UNIT
	var tremble: Vector2 = _doom_tremble(delta)
	_vessel.position = Vector3(
		(_hit * KICK_PX + _lunge_x + tremble.x) * UNIT + kind_x,
		lift + kind_y + (_lunge_up + tremble.y) * UNIT, 0.0)
	# The resync the rig loop does on every frame. This one call is the whole of
	# what was missing: a shadow that could answer the body's height, asked twice
	# in an actor's life.
	_update_shadow()


## `doomTremble` — the rattle, in the art's own px, composed into the idle the
## same way the recoil is. Zero unless the world has stopped for this creature.
func _doom_tremble(delta: float) -> Vector2:
	if not _doomed:
		return Vector2.ZERO
	_doom_t = fmod(_doom_t + delta, DOOM_PERIOD)
	var phase: float = _doom_t / DOOM_PERIOD
	return Vector2(Motion.keyframe(phase, DOOM_AT, DOOM_X),
		-Motion.keyframe(phase, DOOM_AT, DOOM_Y))


# ---------------------------------------------------------------- striking


## The ward stone. Built once and left hidden; `set_ward_shell` is what turns it on, and
## `_step_ward` is what cuts it.
##
## Hung off its OWN root under the stage rather than off `_vessel`, and that is the whole
## structural half of this rewrite. `_vessel.scale` carries the recoil squash, so a stone
## parented there stretched and flattened with the body it was protecting — which is the
## single clearest way to say "this is made of the same stuff as the creature". Position is
## mirrored across in `_step_ward` because a held shield does travel with its holder; scale
## is refused.
func _build_ward_shell() -> void:
	_ward_root = Node3D.new()
	_stage.add_child(_ward_root)
	_ward_mesh = MeshInstance3D.new()
	var qm: QuadMesh = QuadMesh.new()
	# The stone's own size, from the box HEIGHT and the gem's own aspect. Deriving the width
	# from `_quad_w` gave a narrow creature a narrow shield, which is a shield cut to fit
	# rather than one held up.
	qm.size = Vector2(_box_u * WARD_SIZE * WARD_ASPECT, _box_u * WARD_SIZE)
	_ward_mesh.mesh = qm
	# Proud in Z, so the perspective camera gives real parallax against the body when the
	# stage shakes. `render_priority` orders draws; it does not make a thing be in front.
	_ward_mesh.position = Vector3(0.0, 0.0, _box_u * WARD_LIFT)
	var sh: Shader = Shader.new()
	sh.code = WARD_SHADER
	_ward_mat = ShaderMaterial.new()
	_ward_mat.shader = sh
	_ward_mat.render_priority = 4   # over the body and the crack glass
	_ward_mat.set_shader_parameter("tint", WARD_TINT)
	_ward_mat.set_shader_parameter("shell_opacity", WARD_OPACITY)
	_ward_mat.set_shader_parameter("edge_soft", WARD_EDGE_SOFT)
	_ward_mat.set_shader_parameter("rough", WARD_ROUGH)
	_ward_mat.set_shader_parameter("env_gain", WARD_ENV)
	_ward_mat.set_shader_parameter("cut_n", WARD_CUT_N)
	_ward_mat.set_shader_parameter("table_r", WARD_TABLE_R)
	_ward_mat.set_shader_parameter("grow", 0.0)
	_ward_mat.set_shader_parameter("facet_n", 0)
	_ward_mesh.set_surface_override_material(0, _ward_mat)
	_ward_mesh.visible = false
	_ward_root.add_child(_ward_mesh)
	_push_key_dir()
	_cut_girdle()


## THE GIRDLE, and it is the same stone every time.
##
## This replaces `reshuffleWardShape`, whose entire purpose was the opposite: uneven angular
## spacing and radius spikes, reseeded on every guard, "so no two guards in a fight are the
## same stone". A raw crystal. See the `WARD_*` block for why the reversal is the point —
## the ward is a manufactured thing and the fracture is a natural one, and that contrast is
## what stops the two speaking the same language.
##
## A regular `WARD_CUT_N`-gon with its VERTICES on the facet boundaries, so each crown facet
## owns exactly one girdle edge and the outline is the cut seen from outside rather than a
## Called on every fresh guard rather than once at build, and that is not vestigial: it also
## clears `_ward_sites_used`, which is what forces the facet count back to the shader when a
## stone is cut a second time.
func _cut_girdle() -> void:
	if _ward_mat == null:
		return
	var outline: PackedVector2Array = PackedVector2Array()
	outline.resize(16)
	for i: int in range(WARD_CUT_N):
		# The facet boundaries sit at k/N of the turn measured from the same origin the
		# shader uses, so the polygon's corners land exactly on the ribs. Getting this half a
		# facet out puts a vertex in the middle of every face, which reads as a bevelled
		# octagon rather than as a cut.
		var ang: float = (float(i) / float(WARD_CUT_N) - 0.5) * TAU
		outline[i] = Vector2(cos(ang), sin(ang))
	_ward_mat.set_shader_parameter("outline", outline)
	_ward_mat.set_shader_parameter("outline_n", WARD_CUT_N)
	_ward_sites_used = -1


## Whether a shell is up or on its way up. Read by the sync that restores one on
## a rebuilt screen, so it can tell "already warded" from "just warded".
func ward_shell_on() -> bool:
	return _ward_on


## The stone ATE a blow. Rings the facets facing where it came from and drives it back.
##
## Separate from `take_hit` and not folded into it, because the two are different events
## that happen to coincide: the body recoils from being struck, and the shield answers for
## having stopped it. A creature with no ward gets only the first, and calling this on one
## is a no-op rather than a caller's problem.
##
## `from` is a screen-space heading pointing at the creature — `Vector2.LEFT` for a foe
## struck by the hero, which is the default because it is every case the sequencer has.
func ward_hit(from: Vector2 = Vector2.LEFT) -> void:
	if not _ward_on or _ward_mat == null:
		return
	_ward_hit = 1.0
	_ward_from = from.normalized() if from.length() > 0.0 else Vector2.LEFT
	_ward_mat.set_shader_parameter("hit_from", _ward_from)


## `meshWard(el, on, {grow})`. Three cases, and the middle one is the reason this
## is not a boolean: gaining ward while you already have it keeps the stone and
## re-cuts its facets — they collapse to 12% and are cut again — so a second Ward card
## reads as the guard being reinforced rather than as nothing happening.
##
## Going OFF now BREAKS the stone rather than fading it, and the trigger is already exactly
## right without touching the sequencer: `set_ward(0)` routes here, and the sequencer's own
## `SAY_GUARD_SHATTERED` beat is the same instant. A ward is consumed, not dismissed.
func set_ward_shell(on: bool, grow: bool = true) -> void:
	if _ward_mat == null:
		return
	if not on:
		if not _ward_on:
			return   # already off or breaking; do not restart the clock on a resync
		_ward_on = false
		_ward_pulsing = false
		# The stone stays whole and `burst` does the work, so the silhouette does not shrink
		# out from under the pieces that are leaving it.
		_ward_grow = 1.0
		_ward_grow_from = 1.0
		_ward_breaking = true
		_ward_burst = 0.0
		_ward_t = 0.0
		return
	if _ward_on:
		if not grow:
			return   # a sync says "still warded", not "warded again"
		_ward_grow = 1.0
		_ward_grow_from = 1.0
		_ward_pulsing = true
		_ward_pulse_from = _ward_site_f
		_ward_pulse_t = 0.0
		_ward_sites_used = -1
		return
	_cut_girdle()
	_ward_on = true
	_ward_pulsing = false
	_ward_breaking = false
	_ward_burst = 0.0
	_ward_mat.set_shader_parameter("burst", 0.0)
	_ward_t = 0.0
	_ward_grow = 0.0 if grow else 1.0
	_ward_grow_from = _ward_grow
	_ward_site_f = _ward_grow


## The stone's own clock: cut in, break, re-cut, or ring from a blow it ate.
func _step_ward(delta: float) -> void:
	if _ward_mat == null:
		return
	# The ring decays on its own clock and composes with everything else, so a stone can be
	# struck while it is still forming and answer anyway.
	if _ward_hit > 0.0:
		_ward_hit = maxf(0.0, _ward_hit - delta / WARD_RING)
	if _ward_pulsing:
		_ward_pulse_t += delta
		var u: float = clampf(_ward_pulse_t / WARD_PULSE, 0.0, 1.0)
		_ward_site_f = lerpf(_ward_pulse_from, WARD_PULSE_TO, u * u * (3.0 - 2.0 * u))
		if u >= 1.0:
			_ward_site_f = 1.0
			_ward_pulsing = false
	elif _ward_on and _ward_grow < 1.0:
		_ward_t += delta
		var u: float = clampf(_ward_t / WARD_GROW, 0.0, 1.0)
		_ward_grow = _ward_grow_from + (1.0 - _ward_grow_from) * (u * u * (3.0 - 2.0 * u))
		_ward_site_f = _ward_grow
	elif _ward_breaking:
		_ward_t += delta
		# EASE_OUT rather than smoothstep, and it is the opposite curve to the grow on
		# purpose: forming is a thing being made and settles into place, breaking is a thing
		# letting go and is fastest at the instant it gives.
		var u: float = clampf(_ward_t / WARD_BREAK, 0.0, 1.0)
		_ward_burst = 1.0 - (1.0 - u) * (1.0 - u)
		_ward_site_f = 1.0
		if u >= 1.0:
			_ward_breaking = false
			_ward_burst = 0.0
			_ward_grow = 0.0
			_ward_site_f = 0.0
	elif _ward_on:
		_ward_site_f = 1.0
	_ward_mesh.visible = _ward_grow > 0.02
	if not _ward_mesh.visible:
		return
	_ward_mat.set_shader_parameter("burst", _ward_burst)
	# Travel with the holder, but do NOT deform with it. `_vessel.position` is the kick, the
	# lunge, the float and the doom tremble — all things a held object shares. `_vessel.scale`
	# is the recoil squash, which is the one it must not, and refusing it is why this hangs
	# off its own root at all.
	#
	# The stone's OWN flinch composes on top, along the blow rather than along the body's
	# recoil axis: a shield is driven back by where it was struck.
	if _ward_root != null and _vessel != null:
		var back: Vector2 = -_ward_from * _ward_hit * WARD_FLINCH * _box_u
		_ward_root.position = _vessel.position + Vector3(back.x, -back.y, 0.0)
	_ward_mat.set_shader_parameter("grow", _ward_grow)
	# SQUARED on the way out. The decay above is linear because a linear clock is the easy
	# thing to reason about; a ring is not linear, it spikes and drops, and squaring here
	# keeps the clock honest while the light behaves.
	_ward_mat.set_shader_parameter("ward_hit", _ward_hit * _ward_hit)
	# `syncWardNormalMap` only rebaked when the floored count stepped. There is no bake here,
	# but the uniform write is still worth not doing every frame — and with nine facets the
	# count steps rarely enough that the guard earns more than it did over thirty-seven.
	var n: int = roundi(float(WARD_CUT_N) * _ward_site_f)
	if n != _ward_sites_used:
		_ward_sites_used = n
		_ward_mat.set_shader_parameter("facet_n", n)


## `char-meta.chars[id].mesh` — the per-character idle the benchmark authors and
## this port has been ignoring since the actor was built. Four of the
## twenty-nine characters carry a block and one of them is the HERO: `breathe
## 1.6, sway 0.5, bob 0` — a body that fills its chest harder, leans less and
## does not float. Everything defaults to 1.0, so a character without a block
## idles exactly as it did.
func _read_idle(entry: Dictionary) -> void:
	_idle_over = entry.get("mesh", {})
	_resolve_profile(&"humanoid")


## `shadow.dy` — the one knob out of the benchmark's nine that survives the
## derive, and it survives because it is the only one that is not derivable.
## Contact point, lean, length and softening all fall out of the painting's own
## alpha and the key light. `dy` says the thing the alpha cannot: this painting
## was made of a creature that is ALREADY off the ground. Five carry it in the
## benchmark, and they are exactly its floaters — `watcherEye` 24, `shade` 16,
## `voltEel` 13, `sporeling` 10, `voidWisp` 9 (`src/char-meta.js:44-55`).
##
## Read here as a RESTING HEIGHT, not as the downward nudge it is over there.
## CSS has no projection, so `dy` could only shove the darkened copy straight
## down and hope; here the same number enters the same projection the live hover
## enters, and the shadow lands offset, smaller, fainter and softer the way an
## airborne creature's does. One authored number instead of nine, doing the job
## the other eight were approximating.
##
## `thornling` carries a SIXTH, at 9, and it is a deliberate deviation rather than
## a transcription: the benchmark gives it `{ ox: 51, oy: 91 }` and no `dy`, so
## over there it is a plant that runs the `float` idle while standing on the
## floor. Judged on the stage and called wrong — a plant that bobs but never
## leaves is the one creature on the roster whose animation and footing disagree.
## 9 rather than `sporeling`'s 10 because `SHADOW_MAX` caps the kind at 10 and a
## `dy` sitting on the cap leaves the bob no room to read. Removing the number
## restores parity exactly; nothing else in the port depends on it.
func _read_hover(entry: Dictionary) -> void:
	var sh: Dictionary = entry.get("shadow", {})
	var dy: float = sh.get("dy", 0.0)
	_hover_rest = maxf(0.0, dy) * UNIT


## `meshProfileFor(kind, id)` (mesh.js:1249) — the kind's profile, with the
## character's own `mesh` block laid over it. The kind is passed rather than
## looked up, on the same rule as everything else here: a widget in
## `presentation/` does not read content.
func set_profile(kind: String) -> void:
	_resolve_profile(StringName(kind))
	_push_profile()


func _resolve_profile(kind: StringName) -> void:
	var base: Dictionary = IDLE_PROFILES.get(kind, IDLE_PROFILES[&"humanoid"])
	_breathe = _idle_knob(base, "breathe", 1.0)
	_idle_sway = _idle_knob(base, "sway", 1.0)
	_idle_bob = _idle_knob(base, "bob", 1.0)
	_idle_head = _idle_knob(base, "head", 1.0)
	_idle_cloth = _idle_knob(base, "cloth", 0.85)
	_idle_pin = _idle_knob(base, "pin", IDLE_PIN)
	_idle_float = _idle_knob(base, "float", 0.0)
	_kind_idle = KIND_IDLE.get(kind, &"")
	var period: float = KIND_IDLE_PERIOD.get(kind, 3.6)
	_kind_period = period
	var amp: float = KIND_FLOAT_PX.get(kind, 0.0)
	_hover_amp = amp * UNIT
	var span: float = SHADOW_MAX.get(kind, SHADOW_MAX_DEFAULT)
	_hover_span = span * UNIT
	_sync_motes(kind)


## `kind === 'wisp' || kind === 'plant'` (`src/ui/combat.js:1845`) — only those
## two shed. Built on demand rather than hidden, because the kind is set once per
## actor and the lab is the only caller that ever re-profiles a live view.
func _sync_motes(kind: StringName) -> void:
	if MOTE_KINDS.has(kind) == (_motes != null):
		return
	if _motes != null:
		_motes.queue_free()
		_motes = null
		return
	_motes = IdleMotes.new(_hue)
	add_child(_motes)
	# Over the painting, under the plate: `.idle-motes` sits at `z-index: 2`
	# inside `.enemy-sprite`, and `.cplate` is a later sibling of `.enemy-art`.
	if _display != null:
		move_child(_motes, _display.get_index() + 1)


func _idle_knob(base: Dictionary, key: String, fallback: float) -> float:
	if _idle_over.has(key):
		var over: float = _idle_over[key]
		return over
	if base.has(key):
		var v: float = base[key]
		return v
	return fallback


func _push_profile() -> void:
	if _body_mat == null:
		return
	_body_mat.set_shader_parameter("p_sway", _idle_sway)
	_body_mat.set_shader_parameter("p_bob", _idle_bob)
	_body_mat.set_shader_parameter("p_breathe", _breathe)
	_body_mat.set_shader_parameter("p_head", _idle_head)
	_body_mat.set_shader_parameter("p_cloth", _idle_cloth)
	_body_mat.set_shader_parameter("p_pin", maxf(0.05, _idle_pin))


## `charAim(id)` (char-meta.js:113) — the global default with the character's
## own partial laid over it. Only the colour is read: `style` is `solid` for
## every creature in the table, and `speed`, `beams` and `dashes` only mean
## anything to the spin/chase styles nobody uses.
func _read_aim(entry: Dictionary) -> void:
	var default_block: Dictionary = _meta.get("aimDefault", {})
	var tint_hex: String = str(default_block.get("color", "#e4d5fb"))
	var own: Dictionary = entry.get("aim", {})
	if own.has("color"):
		tint_hex = str(own["color"])
	var width: float = default_block.get("width", 0.012)
	if own.has("width"):
		var own_width: float = own["width"]
		width = own_width
	# `Math.min(0.06, Math.max(0.006, width))` (mesh.js:1287) — and then out of a
	# FRACTION and into PIXELS, which is the whole point.
	#
	# The authored number is a fraction of the creature's own plane, so taken
	# literally it makes the outline scale with the body: a 1120px leviathan gets
	# a fat band and a 115px sporeling gets a third of a pixel, which is to say
	# nothing at all. The benchmark's other aim path says what the figure is
	# really worth — `#aim-outline-atk` is `feMorphology dilate radius="2"`, two
	# CSS px on every creature alive — and the two agree at the NORMAL tier:
	# 0.012 x 185 = 2.2px. So the fraction is calibrated against that one box and
	# then held at that many px everywhere, rather than re-scaled per creature.
	var aim_px: float = clampf(width, 0.006, 0.06) * AIM_REF_BOX
	_aim_width = aim_px / maxf(1.0, art_size)
	if not tint_hex.begins_with("#"):
		return
	_aim_tint = Color(tint_hex)


## Read a keyframe track at `t`: linear between the offsets in `at`. `at` is
## ascending and the two arrays are the same length.
##
## Past the last offset this CONTINUES the final segment where `Motion.keyframe`
## holds at it, and that is the only reason a second copy of this exists. An
## overshooting curve hands back eased progress above 1 — `Motion.SPRING` is
## `cubic-bezier(.34, 1.56, .64, 1)` and peaks at 1.098 around x = 0.57 — and
## WAAPI keeps interpolating rather than stopping at the last stop. That
## continuation is not a rounding artefact: it IS the spring's swing back past
## centre, which is the whole reason `choreoAttack` was authored on that curve.
##
## Holding is not a near-miss either. Measured on the normal lunge track
## (0/.3/.62/1 → 0/-8/34/0 px), eased progress crosses the last offset at about
## x = 0.38 and never comes back under it, so holding pins translateX at 0 for
## the final 60% of the swing — the body would snap to rest and stand still for
## most of its own attack. Extrapolating instead carries it to -8.6 px and back.
##
## Every other track read here rides a curve that stays inside [0, 1], so the
## tail arm never fires for them and their reads are unchanged.
static func _keyframe(t: float, at: Array[float], v: Array[float]) -> float:
	for i: int in range(1, at.size()):
		if t <= at[i]:
			var span: float = at[i] - at[i - 1]
			var f: float = 0.0 if span <= 0.0 else (t - at[i - 1]) / span
			return lerpf(v[i - 1], v[i], f)
	var n: int = at.size() - 1
	var tail: float = at[n] - at[n - 1]
	if tail <= 0.0:
		return v[n]
	return lerpf(v[n - 1], v[n], (t - at[n - 1]) / tail)


## Throw this body at what it is striking. `kind` is the enemy's `art.kind` from
## content; anything unlisted swings. Returns how long the lunge takes, so a
## caller that has to land the blow on the strike can wait for it.
func lunge(kind: String) -> float:
	if _dead or _vessel == null:
		return 0.0
	if _lunge_tween != null and _lunge_tween.is_valid():
		_lunge_tween.kill()
	_lunge_kind = kind
	# A foe stands right of the hero and strikes left; the hero strikes right.
	# The same fact `_away()` already derives, read from the other end.
	_lunge_dir = -_away()
	var seconds: float = SWING_TIME
	if HEAVY_KINDS.has(kind):
		seconds = HEAVY_TIME
	elif FLOATY_KINDS.has(kind):
		seconds = FLOATY_TIME
	# `choreoAttack` (combat.js:1956-1977) eases the WHOLE iteration once on
	# cubic-bezier(.34, 1.56, .64, 1) and then reads its keyframe list linearly.
	# TRANS_BACK / EASE_OUT was the nearest Godot family and it is a different
	# curve, so the tween is only a clock now and `Motion.SPRING` does the
	# shaping in `_set_lunge`, where the keyframe reads already are.
	_lunge_tween = create_tween()
	_lunge_tween.tween_method(_set_lunge, 0.0, 1.0, seconds) \
		.set_trans(Tween.TRANS_LINEAR)
	_lunge_tween.tween_callback(_clear_lunge)
	return seconds


## `heroIn` / `enemyIn` (styles.css:725-729) — the actor arrives instead of appearing.
##
## Two design facts ride on this and neither is decoration. The opposing DIRECTIONS say
## which side an actor fights for before any chrome is read; the staggered DELAY says how
## many foes there are before any of them is counted. `combat.js:280` sets the delay per
## seat and this takes it as an argument, because a widget does not know its own index in
## a lineup. The hero gets none — `heroIn` carries no `animation-delay`.
##
## `modulate.a` rides along because a slide that starts fully opaque reads as a shove
## rather than as an arrival, and the benchmark's own keyframe fades from 0.
##
## **This moves the whole actor, not the body inside its stage.** The animation is on
## `.enemy` and `.player-zone` — the boxes that carry the name plate, the HP vial and the
## intent — so an entrance that slid only the painting would leave the chrome standing at
## the destination waiting for it. Until 2026-07-27 there were two of these: this one had
## the stagger and moved the vessel, while `CombatScreen._enter` moved the Control with the
## right curve and no stagger, and both ran on the same fight. The Control is the correct
## element and the stagger is the correct behaviour, so they are one function now.
##
## `done` is the caller's re-anchor. An actor is ANCHORED to the ground line, and writing
## `position` rewrites the offsets that hold it there, so the layout has to be restored by
## whoever owns it — `EnemyView` does not know its slot.
func enter(delay: float = 0.0, done: Callable = Callable()) -> void:
	if _enter_tween != null and _enter_tween.is_valid():
		_enter_tween.kill()
	# The hero comes from the left and a foe from the right — `_away()` is the same fact
	# read from the other end, and reusing it is what keeps the two from disagreeing the
	# day a third tier appears.
	_enter_from = _away() * (HERO_IN_PX if tier == "hero" else FOE_IN_PX)
	var home: Vector2 = position
	var rest: float = modulate.a
	# CSS `animation-fill-mode: backwards` — during the delay the actor already holds the
	# `from` frame. Without this the lineup flashes into place and then slides.
	position = home + Vector2(_enter_from, 0.0)
	modulate.a = 0.0
	_enter_tween = create_tween()
	if delay > 0.0:
		_enter_tween.tween_interval(delay)
	_enter_tween.tween_method(func(t: float) -> void:
		var e: float = Motion.ease(Motion.ENTER, t)
		position = home + Vector2(_enter_from * (1.0 - e), 0.0)
		modulate.a = rest * e,
		0.0, 1.0, ENTER_TIME)
	if done.is_valid():
		_enter_tween.tween_callback(done)


## `x` is linear time; `t` is the benchmark's eased progress, and every track
## below is read at it — one ease across the iteration, then linear between the
## offsets, which is what a WAAPI keyframe list does. `t` runs past 1 near the
## middle because the curve overshoots; `_keyframe` is built for that.
func _set_lunge(x: float) -> void:
	var t: float = Motion.ease(Motion.SPRING, x)
	var at: Array[float] = SWING_AT
	if HEAVY_KINDS.has(_lunge_kind):
		# A golem does not travel: it loads and releases where it stands.
		_lunge_x = 0.0
		_lunge_up = 0.0
		_lunge_scale = Vector2(
			_keyframe(t, HEAVY_AT, HEAVY_SX), _keyframe(t, HEAVY_AT, HEAVY_SY))
		return
	if FLOATY_KINDS.has(_lunge_kind):
		at = FLOATY_AT
		_lunge_x = _keyframe(t, at, FLOATY_X) * _lunge_dir
		_lunge_up = _keyframe(t, at, FLOATY_UP)
		_lunge_scale = Vector2(
			_keyframe(t, at, FLOATY_SX), _keyframe(t, at, FLOATY_SY))
		return
	_lunge_x = _keyframe(t, at, SWING_X) * _lunge_dir
	_lunge_up = 0.0
	_lunge_scale = Vector2(
		_keyframe(t, at, SWING_SX), _keyframe(t, at, SWING_SY))


func _clear_lunge() -> void:
	_lunge_x = 0.0
	_lunge_up = 0.0
	_lunge_scale = Vector2.ONE


# ---------------------------------------------------------------- being struck

## The body is struck.
##
## Two beats, and the benchmark separates them by *source* rather than by amount.
## `hurtFlash` fires on every hit a foe takes — poison included — so the flash
## does not distinguish; the shove does. A direct attack gets `choreoHit`'s full
## shove and squash; poison, burn, thorns and self-damage get only hurtFlash's
## smaller two-phase wobble, because a body recoiling hard from nothing visible
## reads as being punched by an invisible hand.
##
## The two are not stacked. In the benchmark they are two animations on one
## element, both writing `transform` and `filter`, so only one of them was ever
## visible on a direct hit — porting the conflict rather than the result would be
## transcribing a workaround.
##
## `hurtFlash` is a foe's animation there, and a struck hero is shoved without
## flashing, so the flare is withheld from a hero rather than dimmed for one.
## The middle of the painted body, in global px — where an effect aimed at this
## actor starts. `presentation.enemyCenter` / `heroCenter` read the art element's
## own box; here the actor's box IS the art box (the name plate is a child hung
## off it), so the centre is the box centre and nothing has to know how the 3D
## stage inside is padded.
func body_centre() -> Vector2:
	return global_position + size * 0.5


## `choreoStagger` (combat.js:1991) — the beat before the vessel fails: the
## body sags 5px, tips two and a half degrees and darkens to 0.6 brightness over
## 360ms, and STAYS there (`fill: 'forwards'`) because what follows is the
## shatter, not a recovery.
##
## Slumped onto the display rather than the 3D vessel: `_process` rewrites the
## vessel's transform every frame from the idle, so a tween on it would be
## overwritten, and a body that is about to break has no business still
## breathing. Returns how long the caller should wait.
func stagger() -> float:
	if _dead or _display == null:
		return 0.0
	_display.pivot_offset = _display.size * 0.5
	_stagger_from = _display.position
	# `choreoStagger` (combat.js:1991-2000) is a two-stop list on
	# cubic-bezier(.22, 1, .36, 1) with `fill: forwards` — one ease across the
	# whole 360 ms, and the slump holds where it lands. TRANS_CUBIC was the
	# nearest family and is not that curve; the three properties also have to
	# move together, so one clock drives all of them.
	var tw: Tween = create_tween()
	tw.tween_method(_set_stagger, 0.0, 1.0, STAGGER_TIME).set_trans(Tween.TRANS_LINEAR)
	return STAGGER_TIME


func _set_stagger(x: float) -> void:
	if _display == null:
		return
	var t: float = Motion.ease(Motion.OUT_SOFT, x)
	_display.position = _stagger_from + Vector2(0.0, STAGGER_DROP * t)
	_display.rotation = deg_to_rad(STAGGER_TILT * t)
	var dim: float = lerpf(1.0, STAGGER_DIM, t)
	_display.modulate = Color(dim, dim, dim)


## `x.root.classList.add('reseaming')` (drain.js:458) — a shattered pane spends
## its turn knitting itself back together, and besides the intent plate reading
## STAGGERED this is the only thing on screen that says so. The art flares and
## half-desaturates in a fifth of a second, then bleeds back over half of one:
## glass reseaming, not a body taking a hit.
func reseam() -> void:
	if _dead or _display_mat == null:
		return
	if _reseam_tween != null and _reseam_tween.is_valid():
		_reseam_tween.kill()
	_reseam_tween = create_tween()
	_reseam_tween.tween_method(_set_reseam, 0.0, 1.0, RESEAM_MS) \
		.set_trans(Tween.TRANS_LINEAR)


## Linear time in, per-interval CSS easing out — the tween is only a clock.
func _set_reseam(x: float) -> void:
	if _display_mat == null:
		return
	var f: float = 0.0
	if x < RESEAM_AT:
		f = Motion.ease(CSS_EASE_OUT, x / RESEAM_AT)
	else:
		f = 1.0 - Motion.ease(CSS_EASE_OUT, (x - RESEAM_AT) / (1.0 - RESEAM_AT))
	_display_mat.set_shader_parameter("bright", lerpf(1.0, RESEAM_BRIGHT, f))
	_display_mat.set_shader_parameter("sat", lerpf(1.0, RESEAM_SAT, f))


func take_hit(direct: bool = true) -> void:
	if _dead:
		return
	if _gem != null:
		_gem_flash()
		return
	if _vessel == null:
		return
	# The white beat is everyone's. `choreoHit` calls `meshFlash` unconditionally
	# and the drain calls `choreoHit` on both sides — `choreoHit(x.root, 1)` for a
	# foe (drain.js:512), `choreoHit(ce.hero, -1)` for the hero (drain.js:596).
	# Only the CSS flare below is a foe's, because `hurtFlash` hangs off
	# `.enemy.hurt` and a hero is not `.enemy`.
	_white_beat()
	if tier != "hero":
		_flare()
	if direct:
		_shove()
	else:
		_nudge()


## `meshFlash(el, 160)` — a square wave, not a ramp: a `setTimeout` has no
## easing. Held by a constant-value leg because a tween from 0.9 to 0.9 is how
## that is spelled here.
func _white_beat() -> void:
	if _body_mat == null:
		return
	if _white_tween != null and _white_tween.is_valid():
		_white_tween.kill()
	_white_tween = create_tween()
	_white_tween.tween_method(_set_hit_white, HIT_WHITE, HIT_WHITE, HIT_WHITE_HOLD)
	_white_tween.tween_callback(_set_hit_white.bind(0.0))


## Which way a blow throws this actor. Derived rather than passed, on the same
## reasoning as `tier`: the hero stands left of the foes, so a struck foe is
## thrown right and a struck hero is thrown left.
func _away() -> float:
	return -1.0 if tier == "hero" else 1.0


func _shove() -> void:
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	# `choreoHit` (combat.js:1979-1989) is a THREE-stop list — rest, peak at
	# offset 0.25, rest — eased once across 300 ms by cubic-bezier(.22, 1, .36, 1)
	# and read linearly between the stops. What stood here started AT the peak
	# and decayed on TRANS_QUINT, which is a different shape as well as a
	# different curve: the body had travel away from the blow and none into it,
	# so a hit read as a shove rather than as an impact that recovers.
	_hit_dir = _away()
	_hit_tween = create_tween()
	_hit_tween.tween_method(_set_shove, 0.0, 1.0, HIT_TIME) \
		.set_trans(Tween.TRANS_LINEAR)


## Both tracks share one read: the displacement carries the sign, the squash is
## the same 0→1→0 magnitude, and they peak on the same frame because in the
## benchmark they are two properties of a single keyframe.
func _set_shove(x: float) -> void:
	var f: float = _keyframe(Motion.ease(Motion.OUT_SOFT, x), HIT_AT, HIT_V)
	_hit = _hit_dir * f
	_hit_squash = f


## hurtFlash's own displacement: out, back past centre, settle. No squash — an
## unstruck-looking body that merely twitches is the whole read for a poison tick.
func _nudge() -> void:
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	_hit_squash = 0.0
	var away: float = _away()
	_hit_tween = create_tween()
	_hit_tween.tween_property(self, "_hit", away * NUDGE_OUT, FLARE_RISE) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hit_tween.tween_property(self, "_hit", away * NUDGE_BACK, FLARE_RISE) \
		.set_trans(Tween.TRANS_SINE)
	_hit_tween.tween_property(self, "_hit", 0.0, HIT_TIME - FLARE_RISE * 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Up in 90ms, down over the rest — hurtFlash peaks at 30% of its 0.3s and the
## asymmetry is the point: a flash that faded as slowly as it rose would read as
## the creature glowing rather than as it being hit.
func _flare() -> void:
	if _body_mat == null:
		return
	if _flare_tween != null and _flare_tween.is_valid():
		_flare_tween.kill()
	# SINE / EASE_IN_OUT both ways, which is what interpolating between CSS
	# keyframes actually does. An EASE_OUT rise was tried and it front-loads so
	# hard that the flash was already at 45% on the first frame — the ramp the
	# benchmark spends 90ms on has to be visible as a ramp, or there was no reason
	# to give it 30% of the animation.
	_flare_tween = create_tween()
	_flare_tween.tween_method(_set_flare, 0.0, 1.0, FLARE_RISE) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_flare_tween.tween_method(_set_flare, 1.0, 0.0, HIT_TIME - FLARE_RISE) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _set_hit_white(v: float) -> void:
	if _body_mat != null:
		_body_mat.set_shader_parameter("hit_white", v)


func _set_flare(v: float) -> void:
	if _body_mat != null:
		_body_mat.set_shader_parameter("flare", v)


## The gem has no body to shove and no shader to flash, so the fallback avatar
## takes the hit as a brightness pulse — the same channel set_targetable uses.
func _gem_flash() -> void:
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate", Color(2.2, 2.0, 2.0, 1.0), FLARE_RISE) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate", Color(1, 1, 1, 1), HIT_TIME - FLARE_RISE) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)


# ---------------------------------------------------------------- the cracks

## Half-plane clip: keep the side of the a|b bisector that belongs to `a`.
## Geometry2D has no half-plane primitive, so the plane arrives as a rectangle
## far larger than the box — the intersection is identical and it is four lines
## of code instead of a clipper.
static func _clip(poly: PackedVector2Array, a: Vector2, b: Vector2,
		big: float) -> PackedVector2Array:
	var mid: Vector2 = (a + b) * 0.5
	var n: Vector2 = (a - b).normalized()
	var t: Vector2 = Vector2(-n.y, n.x)
	var half: PackedVector2Array = PackedVector2Array([
		mid + t * big, mid - t * big, mid - t * big + n * big, mid + t * big + n * big,
	])
	var hit: Array[PackedVector2Array] = Geometry2D.intersect_polygons(poly, half)
	return hit[0] if not hit.is_empty() else PackedVector2Array()


## A circle as a polygon — Geometry2D only intersects polygons, and 20 sides is
## indistinguishable from round at the size a shard is ever drawn.
static func _disc(centre: Vector2, r: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for i: int in range(20):
		var a: float = TAU * float(i) / 20.0
		out.append(centre + Vector2(cos(a), sin(a)) * r)
	return out


## Voronoi cells for `sites`, in world units, centred on the quad. With
## `reach` > 0 each cell is bounded to a disc around its own site — without that
## every cell tiles the whole quad and the overlay "glass" becomes an opaque
## pane over the art. reach <= 0 keeps the full tiling, which is exactly what
## the death rite wants: the WHOLE body cut into panes.
func _voronoi(sites: PackedVector2Array, reach: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var hw: float = _quad_w * 0.5
	var hh: float = _box_u * 0.5
	var big: float = _box_u * 8.0
	var box: PackedVector2Array = PackedVector2Array([
		Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh),
	])
	for i: int in range(sites.size()):
		var cell: PackedVector2Array = box
		for j: int in range(sites.size()):
			if i == j:
				continue
			cell = _clip(cell, sites[i], sites[j], big)
			if cell.is_empty():
				break
		if cell.size() < 3:
			continue
		if reach <= 0.0:
			out.append(cell)
			continue
		var patch: Array[PackedVector2Array] = Geometry2D.intersect_polygons(
			cell, _disc(sites[i], reach))
		if not patch.is_empty() and patch[0].size() >= 3:
			out.append(patch[0])
	return out


## The overlay cells: the crack web the creature carries while it still stands.
func _cells() -> Array[PackedVector2Array]:
	return _voronoi(_sites, _glass_area * minf(_quad_w, _box_u) * 0.5)


## Extrude a cell into a real plate with thickness. Thickness is the point: a
## zero-depth polygon cannot catch a highlight on its edge or bend anything.
##
## `origin` re-centres the vertices while the UVs stay in body space. A debris
## piece MUST be built around its own centroid: the first shatter pass left
## vertices in body coordinates with the RigidBody at the origin, so every
## shard's spin axis was the middle of the CREATURE — they swept arcs instead of
## tumbling, landed on an edge, and stood there like headstones.
##
## Vertex color is the face tag: caps BLACK, side band RED — the shard shader
## reads COLOR.r as "fracture surface" and pours the molten glow only there.
static func _prism(cell: PackedVector2Array, thick: float, box: Vector2,
		origin: Vector2 = Vector2.ZERO) -> ArrayMesh:
	var tri: PackedInt32Array = Geometry2D.triangulate_polygon(cell)
	if tri.is_empty():
		return null
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z: float = thick * 0.5
	# The cell's own centre, for deciding which way "out" is along each edge below. Winding
	# is not a reliable source for that here: the carve and the Voronoi path hand this
	# function polygons wound to their own conventions, and the shard shader's Fresnel is
	# only correct while the normals point out of the solid.
	var mid: Vector2 = Vector2.ZERO
	for p: Vector2 in cell:
		mid += p
	mid /= float(cell.size())

	# CAPS. Normals AUTHORED rather than generated, and that is this function's whole bug
	# history in one line.
	#
	# `generate_normals()` averages the faces meeting at a vertex, and on a shard EVERY cap
	# vertex is on the outline — a carved piece has no interior vertices at all — so every
	# one of them got averaged with the side band it touches. The result is not a flat cap
	# with a bevelled rim; it is a cap that is bevelled EVERYWHERE, a dome. Measured by
	# writing the Fresnel term straight to EMISSION: `f` sat at 0.45 across faces pointing
	# at the camera, where a flat cap reads 0. `WARM * f * heat * 0.3` then poured warm light
	# over the painting, and that is the "plywood" the debris has read as since the rite was
	# built. `docs/fracture-model.md` §5.2 named the mechanism and expected it to bite the
	# crack ribbon; it was already biting the debris.
	#
	# `set_smooth_group(-1)` did not fix it — tried, measured, still 0.45 — so the normals
	# are written rather than asked for.
	st.set_color(Color(0, 0, 0))
	for face: int in range(2):
		var zz: float = z if face == 0 else -z
		st.set_normal(Vector3(0.0, 0.0, 1.0 if face == 0 else -1.0))
		var i: int = 0
		while i < tri.size():
			for k: int in range(3):
				# The back cap is wound the other way. `triangulate_polygon` returns one
				# winding; reusing it at -z leaves the back cap facing into the shard, which
				# `cull_disabled` happily draws.
				var at: int = tri[i + k] if face == 0 else tri[i + (2 - k)]
				var p: Vector2 = cell[at]
				st.set_uv(Vector2(p.x / box.x + 0.5, 0.5 - p.y / box.y))
				st.add_vertex(Vector3(p.x - origin.x, p.y - origin.y, zz))
			i += 3
	# Side band, quad per edge — where the thickness actually shows. One flat outward normal
	# per edge, perpendicular to it and turned to face away from the centre.
	st.set_color(Color(1, 0, 0))
	for i: int in range(cell.size()):
		var a: Vector2 = cell[i]
		var b: Vector2 = cell[(i + 1) % cell.size()]
		var edge: Vector2 = b - a
		if edge.length() <= 0.0:
			continue
		var out: Vector2 = Vector2(edge.y, -edge.x).normalized()
		if out.dot((a + b) * 0.5 - mid) < 0.0:
			out = -out
		st.set_normal(Vector3(out.x, out.y, 0.0))
		var quad: Array[Vector3] = [
			Vector3(a.x, a.y, z), Vector3(b.x, b.y, z), Vector3(b.x, b.y, -z),
			Vector3(a.x, a.y, z), Vector3(b.x, b.y, -z), Vector3(a.x, a.y, -z),
		]
		for v: Vector3 in quad:
			st.set_uv(Vector2(v.x / box.x + 0.5, 0.5 - v.y / box.y))
			st.add_vertex(v - Vector3(origin.x, origin.y, 0.0))
	return st.commit()


## Rebuild the shard set from the current sites. Cheap enough to redo on every
## crack: a handful of convex cells and one SurfaceTool pass each.
func _rebuild_glass() -> void:
	if _glass_root == null:
		return
	for c: Node in _glass_root.get_children():
		c.queue_free()
	_shards.clear()
	if _sites.size() < 2:
		return
	var mat: ShaderMaterial = _glass_material()
	var thick: float = _box_u * GLASS_THICK
	for cell: PackedVector2Array in _cells():
		var mesh: ArrayMesh = _prism(cell, thick, Vector2(_quad_w, _box_u))
		if mesh == null:
			continue
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = mesh
		mi.set_surface_override_material(0, mat)
		mi.position = Vector3(0.0, 0.0, thick * 0.6)
		_glass_root.add_child(mi)
		_shards.append(mi)


## FNV-1a over the art id. `hash()` is deliberately not used: it carries no
## cross-version guarantee in Godot, and this seed decides a shipped creature's
## fracture pattern, so a golden-image suite built on `hash()` breaks on an engine
## upgrade rather than on a change anyone made.
static func _stable_seed(id: String, idx: int) -> int:
	var h: int = 0x811C9DC5
	for c: int in id.to_utf8_buffer():
		h = ((h ^ c) * 0x01000193) & 0xFFFFFFFF
	return (h + idx * 0x9E3779B9) & 0xFFFFFFFF


## `Rng` exposes `next()` and integer helpers only. `domain/rng/rng.gd` is a
## byte-exact port of the web engine's `makeRng` and is not this lane's to extend,
## so the float range lives here.
func _frand(a: float, b: float) -> float:
	return a + (b - a) * _frac.next()


## Body UV (y down, 0..1) ↔ quad-local world units (y up, centred on the plate).
## Both directions exist because the reference reasons in UV — its spacings are
## UV constants — while `_sites` and the meshes are in world units.
func _to_uv(p: Vector2) -> Vector2:
	return Vector2(p.x / _quad_w + 0.5, 0.5 - p.y / _box_u)


func _from_uv(u: Vector2) -> Vector2:
	return Vector2((u.x - 0.5) * _quad_w, (0.5 - u.y) * _box_u)


## Body UV ↔ this Control's own local pixels. Public because two callers outside
## need it and both were getting it wrong by hand: the bench's click-to-crack read
## `local / size`, which is only right for a square painting, and anything drawing
## over the actor needs the same mapping to land on the creature.
##
## Derived, not measured. The stage camera frames exactly `_span * UNIT` of world at
## the plate and `_display` covers `-pad .. art_size + pad`, so world-to-pixel is
## `1 / UNIT` flat and the world origin lands on the box centre — which is why the
## aspect ratio has to enter through `_quad_w` and cannot be assumed away.
func uv_to_local(u: Vector2) -> Vector2:
	if _quad_w <= 0.0:
		return u * size
	var w: Vector2 = _from_uv(u)
	return Vector2(art_size * 0.5 + w.x / UNIT, art_size * 0.5 - w.y / UNIT)


func local_to_uv(p: Vector2) -> Vector2:
	if _quad_w <= 0.0:
		return Vector2(p.x / maxf(size.x, 1.0), p.y / maxf(size.y, 1.0))
	return _to_uv(Vector2((p.x - art_size * 0.5) * UNIT,
		(art_size * 0.5 - p.y) * UNIT))


## The `at` a caller passes when it knows a hit landed and not where. Named because it was
## a bare `Vector2(-1, -1)` in three files and a magic pair is not a contract.
const ANYWHERE: Vector2 = Vector2(-1, -1)


## Score a crack. `at` is in body UV, or `ANYWHERE`; `damage` is what the blow took off, and
## 0 means the caller does not know — a sync, a lab key, or the `SHATTER` beat, which is the
## facet gauge giving way rather than a damage number.
##
## Kept as the name every caller already uses. `strike()` below is the real entry point and
## this is the door for a caller that has a damage number instead of a physics one.
func crack(at: Vector2 = ANYWHERE, damage: int = 0) -> void:
	strike(at, Vector2.ZERO, energy_of(damage), 0.5)


## `bite`, applied. See `BITE` for the calibration and `docs/fracture-model.md` §3 for why a
## unit conversion is the one arbitrary constant allowed here.
##
## AFFINE and not proportional, and the floor is the reason. A proportional map sends a
## small hit to a small energy, and `int(0.2 / ARM_LENGTH)` is zero arms — clamped to one,
## which `DEFAULT_ENERGY`'s docblock already records as the thing that reads as a scratch
## rather than as broken glass. Zero is not a legible outcome, so the map runs from *a star*
## to *the body comes apart* rather than from nothing: every hit says something, and every
## damage number changes what it says. A tenth of a foe's health buys four arms; all of it
## buys seven.
func energy_of(damage: int) -> float:
	if damage <= 0 or _max_hp <= 0:
		return DEFAULT_ENERGY
	var frac: float = clampf(float(damage) / float(_max_hp), 0.0, 1.0)
	return DEFAULT_ENERGY + (BITE - DEFAULT_ENERGY) * frac


## A BLOW, and the seam `docs/fracture-model.md` §2.5 specifies. Feeds the propagator,
## the field the body shader reads, and — while `discs` is on — the old Voronoi web too,
## so the two can be compared in the running game rather than only in the lab.
##
## `at` in body UV (y down); `dir` a unit heading, zero for face-on; `energy` in body
## widths of crack bought, 1.0 being one; `sharp` 0..1 indenter acuity, accepted and
## not yet spent (see `FractureField`'s docblock).
func strike(at: Vector2 = ANYWHERE, dir: Vector2 = Vector2.ZERO,
		energy: float = DEFAULT_ENERGY, sharp: float = 0.5) -> void:
	if _glass_root == null or _blows >= MAX_SITES:
		return
	var p: Vector2 = at
	if p.x < 0.0:
		p = _somewhere_on_body()
	_blows += 1
	if _net == null:
		_net = CrackNet.new()
		_frac_field = FractureField.new(_frac, body_mask(_art_id))
		_cracks = CrackField.new()
	# The NET is committed whole and immediately; only the FIELD runs a front over it. That
	# ordering is the seam, not an accident: the next blow's screening has to see the crack
	# that exists rather than the crack that has been drawn so far.
	var grown: Array[Dictionary] = _frac_field.strike(_net, blow_of(p, dir, energy, sharp))
	_net.commit(grown)
	# Running mean, so the hearth is the centroid of every impact without keeping the list.
	_hearth = (_hearth * float(_hearth_n) + p) / float(_hearth_n + 1)
	_hearth_n += 1
	_begin_reveal(grown)
	# `_sites` keeps filling whatever `discs` says, and now feeds only the comparison — the
	# rite carves along the net (`_death_cells`). Left in place because a flag that renders
	# the old model over the same blows is worth more than the four bytes.
	_sites.append(_from_uv(p))
	if discs:
		_rebuild_glass()


## Run the propagation front out over the new strands, so a blow THROWS a star rather than
## revealing one. `docs/fracture-model.md` §5.
##
## `EASE_OUT`, because a crack front decelerates into its own arrest — it is losing the
## stress that drives it the whole way out. Linear read as a line being drawn.
func _begin_reveal(grown: Array[Dictionary]) -> void:
	if _reveal_tween != null and _reveal_tween.is_valid():
		_reveal_tween.kill()
	# `begin` finishes whatever the killed tween had left, so no geometry is lost, and it
	# lays the impact glints at once — the flash is the blow, not the propagation.
	var span: float = _cracks.begin(grown)
	_push_crack_field()
	if span <= 0.0:
		return
	_reveal_tween = create_tween()
	_reveal_tween.tween_method(_set_reveal, 0.0, span, span / CRACK_SPEED) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _set_reveal(arc: float) -> void:
	_cracks.reveal(arc)
	_push_crack_field()


## Snap any propagation front to complete, for a caller building a STATE rather than playing
## a beat — the lab's `--cracked=N` wants six blows already scored, not the sixth still on
## its way out. Without it a pre-cracked strip photographs a half-drawn star in its first
## cell and reads as a rendering fault.
func settle_cracks() -> void:
	_finish_reveal()


## No front left running, and the field showing the whole net. The rite needs this before
## it carves: the carve reads the net, which has been complete since the blow landed, so a
## half-drawn field would throw shards along cracks the player was never shown.
func _finish_reveal() -> void:
	if _reveal_tween != null and _reveal_tween.is_valid():
		_reveal_tween.kill()
	if _cracks != null and _cracks.growing():
		_cracks.finish()
		_push_crack_field()


## A blow point that is actually ON the creature, for the callers that know a hit landed
## and not where — both `combat_screen.gd` calls, and the rite's top-up.
##
## The mask check is not a nicety. A flat `_frand(0.2, 0.8)` box was scoring blows in
## empty air for a quarter of them, and a crack that starts off the body fails
## `BodyMask.reaches` on its first step and produces nothing at all: the hit landed, the
## damage applied, and the glass said nothing. Two of eight measured blows on a duskfang,
## whose silhouette is a lean quadruped with a long tail and nothing like a filled box.
##
## Falls back to the centre, which for every painting in the roster is body.
func _somewhere_on_body() -> Vector2:
	var mask: BodyMask = body_mask(_art_id)
	for _t: int in range(32):
		var p: Vector2 = Vector2(_frand(0.16, 0.84), _frand(0.12, 0.88))
		if mask.solid(p):
			return p
	return Vector2(0.5, 0.5)


## Built here rather than inline so `mark_dead()` and the lab share one definition of
## what a blow is.
static func blow_of(at: Vector2, dir: Vector2, energy: float, sharp: float) -> Blow:
	return Blow.new(at, dir, energy, sharp)


## Run every open tip out to the silhouette. Idempotent — `CrackNet.open_tips()` is what
## makes it so, and a death beat firing twice is not hypothetical in this codebase
## (`c77b56b`).
func _relieve_net() -> void:
	if _net == null or _frac_field == null or _cracks == null:
		return
	# Any front still running belongs to the last blow. The rite is not the moment to keep
	# animating it, and the carve below must not cut along a groove that is half drawn.
	_finish_reveal()
	var extra: Array[Dictionary] = _frac_field.relieve(_net)
	if extra.is_empty():
		return
	_net.commit(extra)
	_cracks.add(extra)
	_push_crack_field()


func _push_crack_field() -> void:
	if _body_mat == null or _cracks == null:
		return
	_body_mat.set_shader_parameter("crack_tex", _cracks.texture())
	_body_mat.set_shader_parameter("crack_bands", CrackField.BANDS)
	_body_mat.set_shader_parameter("crack_hearth", _hearth)
	_body_mat.set_shader_parameter("crack_on", 1.0)


func reset_glass() -> void:
	_dead = false
	_ignite = 0.0
	_shake = 0.0
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	if _flare_tween != null and _flare_tween.is_valid():
		_flare_tween.kill()
	_hit = 0.0
	_hit_squash = 0.0
	_set_flare(0.0)
	_sites = PackedVector2Array()
	# The net, the propagator and the field go with the sites. Clearing one and not the
	# others is the same class of bug as clearing `_sites` without rewinding `_frac`,
	# which is the note directly below.
	_blows = 0
	_net = null
	_frac_field = null
	_hearth = Vector2(0.5, 0.5)
	_hearth_n = 0
	# The front before the field it draws into. A tween left running would compose the last
	# vessel's arms onto the new one's blank buffer.
	if _reveal_tween != null and _reveal_tween.is_valid():
		_reveal_tween.kill()
	if _cracks != null:
		_cracks.clear()
	if _body_mat != null:
		_body_mat.set_shader_parameter("crack_on", 0.0)
	# Rewind the fracture stream, not just the site list. Clearing one without the
	# other is what made two runs of the same rite differ.
	_frac = Rng.new(_frac_seed)
	modulate = Color(1, 1, 1, 1)
	if _debris != null:
		if is_instance_valid(_debris):
			_debris.queue_free()
		_debris = null
	if _vessel != null:
		_vessel.visible = true
		_vessel.transform = Transform3D.IDENTITY
	if _cam != null:
		_cam.h_offset = 0.0
		_cam.v_offset = 0.0
	# The rite's fade is a factor the projection multiplies; left at 0 the next
	# actor built on this view would stand over nothing.
	_shadow_fade = 1.0
	_update_shadow()
	if _glass_mat != null:
		_glass_mat.set_shader_parameter("ignite", 0.0)
	if _fire != null:
		_fire.light_energy = 0.0
		_fire.position = Vector3(0.0, 0.0, -_box_u * 0.25)
	if _body_mat != null:
		_body_mat.set_shader_parameter("fade", 1.0)
		_body_mat.set_shader_parameter("emission_gain", 0.85)
	if _quad != null:
		_quad.visible = true
		_quad.position = Vector3.ZERO
	_rebuild_glass()


# ---------------------------------------------------------------- the death rite

## The vessel gives. The fire inside wells up through every fracture, one last
## web races the glass — then the shards STOP being decoration and become
## rigid bodies. No hand-rolled ballistics: gravity, tumble and the floor bounce
## are the physics engine's, which is the whole reason to be in Godot.
## `beat` is `igniteVessel`'s hold (drain.js:607): how long the fire takes to
## well up before the glass gives. The benchmark spends 200ms on it and 320 on a
## boss; the caller waits the same beat and then throws the burst, so the sparks
## leave at the instant the vessel fails rather than after it.
func mark_dead(beat: float = 0.2) -> void:
	if _dead:
		return
	# A hero does not break. The benchmark spends no crack, no ignition and no
	# shatter on the player's own body — a defeat is the screen's overlay, not the
	# vessel coming apart — so the rite is a foe's ending and this returns before
	# scoring anything. Guarded here rather than left to the caller, because the
	# rite is irreversible without rebuilding the actor.
	if tier == "hero":
		return
	_dead = true
	clear_intent()
	if _gem != null:
		_gem.set_state(_hue, 0.0, true)
		modulate = Color(0.5, 0.5, 0.56, 0.5)
		return
	# THE RITE RELEASES WHAT WAS CARRIED — it does not score a fresh pattern. Every tip
	# that stopped for want of tension runs the rest of the way out to the silhouette at
	# toughness zero, which is both the physically true statement and what turns an
	# arrested network into one that partitions the plane: an arrested crack is a
	# dangling edge and separates nothing (`docs/fracture-model.md` §2.4).
	_relieve_net()
	# NO top-up. It was here until the carve landed — `_sites` padded to the cap so the
	# Voronoi partition had enough seeds to look legible — and it was the one place
	# `CONCEPTS.md` › Crack was not kept, because it made every death break into the same
	# number of pieces however it had been earned. `Carve` reads the net, so the shard
	# count follows the damage and the padding is not just unnecessary but wrong.
	var tw: Tween = create_tween()
	tw.tween_method(set_ignite, _ignite, 1.0, maxf(0.01, beat)).set_trans(Tween.TRANS_CUBIC)
	tw.tween_callback(shatter)


## The radial fracture map. Sites ring the burst point — dense near it, sparse
## far — which is how tempered glass actually fails: small hot cells at the
## impact, long wedges toward the silhouette.
func _death_sites(burst: Vector2) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	out.append(burst)
	var reach: float = _box_u * 0.52
	# Fewer, larger cells: a piece must be big enough to carry a readable patch
	# of the painting, or the rite degrades into confetti.
	var rings: Array[Array] = [[0.16, 4], [0.36, 7], [0.62, 9], [0.85, 10]]
	for ring: Array in rings:
		var rf: float = ring[0]
		var n: int = ring[1]
		for i: int in range(n):
			var a: float = TAU * (float(i) + _frand(-0.35, 0.35)) / float(n)
			var r: float = reach * rf * _frand(0.82, 1.22)
			var p: Vector2 = burst + Vector2(cos(a), sin(a)) * r
			p.x = clampf(p.x, -_quad_w * 0.49, _quad_w * 0.49)
			p.y = clampf(p.y, -_box_u * 0.49, _box_u * 0.49)
			out.append(p)
	return out


## The body breaks along the cracks it was CARRYING. `_sites` is the standing web;
## a sparse jittered background grid fills the intact glass, so the vessel comes
## apart into fine cells where the blows landed and long slabs everywhere else.
##
## This is `_voronoiParts` (src/vfx.js:236), and it is the reference's PRIMARY
## path. It was never ported. `_death_sites` was — and that is the reference's
## `_radialParts()` FALLBACK: src/vfx.js:296 reads
## `_voronoiParts(opts.sites) || _radialParts()`. So this port shipped the fallback
## as its primary, `_sites` was never read at death, and the creature broke along a
## pattern unrelated to its own cracks. `CONCEPTS.md` › Crack says cracks
## "determine how the Vessel breaks apart when the Death rite runs"; until now
## they did not, which made it a compliance defect rather than a divergence.
##
## Under three harvested sites the reference falls back and so does this: three
## points cannot describe a fracture, and the radial map is the better guess.
func _break_sites(burst: Vector2) -> PackedVector2Array:
	if _sites.size() < 3:
		return _death_sites(burst)
	# Reasoned in UV, because the reference's spacings are UV constants and a
	# creature's plate is not square — converting them to world units per axis
	# would make the filler grid denser on the narrow one.
	var uv: Array[Vector2] = []
	for s: Vector2 in _sites:
		var u: Vector2 = _to_uv(s)
		var keep: bool = true
		for q: Vector2 in uv:
			if q.distance_to(u) < SITE_MERGE:
				keep = false
				break
		if keep:
			uv.append(u)
	var gu: float = 0.1
	while gu < 1.0:
		var gv: float = 0.09
		while gv < 1.0:
			# Named rather than inline: unary minus on a typed const folds to
			# Variant, and the gate treats that as an error at the call.
			var jitter: float = GRID_JITTER
			var p: Vector2 = Vector2(gu + _frand(-jitter, jitter),
				gv + _frand(-jitter, jitter))
			var free: bool = true
			for q: Vector2 in uv:
				if q.distance_to(p) < GRID_EXCLUDE:
					free = false
					break
			if free:
				uv.append(p)
			gv += GRID_STEP
		gu += GRID_STEP
	var out: PackedVector2Array = PackedVector2Array()
	for u: Vector2 in uv:
		out.append(_from_uv(u))
	return out


## Full-body panes, minus the empty ones. A cell whose every probe lands on
## transparent art would fly as an invisible slab wearing a glowing fracture
## rim — which is exactly "shattering something that is not the mob". Slivers go
## too: a needle triangulates and extrudes perfectly well, then flies as a splinter
## carrying no readable painting, which the reference culls for the same reason.
## THE BODY BREAKS ALONG THE CRACKS IT WAS CARRYING, and nothing else. `Carve` cuts the
## net out of the body and the pieces that come back are the shards — so a creature that
## died having been hit twice breaks into a few large ones and a worn-down one breaks into
## many, which is `CONCEPTS.md` › Crack finally being true rather than promised.
##
## Falls back to the Voronoi cells when there is no net at all. That path is not dead
## code: a vessel can be shattered without ever having been struck — the lab's `S` key
## does exactly that, and so does any caller that skips straight to the ending.
func _death_cells(burst: Vector2) -> Array[PackedVector2Array]:
	if _net != null and not _net.is_empty():
		var carved: Array[PackedVector2Array] = []
		# `Carve.MIN_AREA` and not `CELL_MIN_AREA`, and not a conversion between them.
		# Both are fractions of the body — UV area 1.0 IS the quad — so dividing by the
		# quad's world area was a unit error that made the floor ten times too permissive
		# and let one-pixel specks through with a RigidBody each. The carve's floor is
		# also derived differently, because a carved network throws thin offcuts where a
		# Voronoi partition threw compact cells.
		for shard: PackedVector2Array in Carve.shards(_net, CrackField.APERTURE):
			var cell: PackedVector2Array = PackedVector2Array()
			for v: Vector2 in shard:
				cell.append(_from_uv(v))
			var centre: Vector2 = Vector2.ZERO
			for v: Vector2 in cell:
				centre += v
			centre /= float(cell.size())
			# The same cull the disc path used: a shard covering no painting is a pane of
			# empty box, and the shard shader would render it as nothing while the physics
			# still tumbled it.
			if _touches_art(cell, centre):
				carved.append(cell)
		if not carved.is_empty():
			return carved
	return _voronoi_cells(burst)


## The disc path's cells, kept for a vessel that breaks without ever having been struck.
func _voronoi_cells(burst: Vector2) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var floor_area: float = _quad_w * _box_u * CELL_MIN_AREA
	for cell: PackedVector2Array in _voronoi(_break_sites(burst), 0.0):
		if _area(cell) < floor_area:
			continue
		var centre: Vector2 = Vector2.ZERO
		for v: Vector2 in cell:
			centre += v
		centre /= float(cell.size())
		if _touches_art(cell, centre):
			out.append(cell)
	return out


## Shoelace, absolute. Cells arrive in either winding depending on which clips ran.
static func _area(poly: PackedVector2Array) -> float:
	var a: float = 0.0
	for i: int in range(poly.size()):
		var p: Vector2 = poly[i]
		var q: Vector2 = poly[(i + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	return absf(a) * 0.5


func _touches_art(cell: PackedVector2Array, centre: Vector2) -> bool:
	if _art_img == null:
		return true
	if _alpha_at(centre) > 0.08:
		return true
	for v: Vector2 in cell:
		if _alpha_at((centre + v) * 0.5) > 0.08:
			return true
	return false


## The OLDER of two silhouette readers, kept deliberately. `body_mask()` is the one
## the fracture model uses; this one is full-resolution and feeds the death cull on a
## visual that is already signed off, so it is not being rewritten underneath that
## approval. Step 6 of `docs/fracture-model.md` deletes this path along with the
## Voronoi cells it culls — until then, two readers and a note beats a silent
## behaviour change to an approved death.
func _alpha_at(p: Vector2) -> float:
	var w: int = _art_img.get_width()
	var h: int = _art_img.get_height()
	var x: int = clampi(int((p.x / _quad_w + 0.5) * float(w)), 0, w - 1)
	var y: int = clampi(int((0.5 - p.y / _box_u) * float(h)), 0, h - 1)
	return _art_img.get_pixel(x, y).a


## The vessel gives — and the CREATURE is what breaks. One frame it stands
## whole; the next, the painting itself is cut into radial panes, every piece
## opaque with the patch of art it covered, molten along its fracture edges.
## The intact body is HIDDEN the same frame (the benchmark's meshHandoff):
## nothing may remain behind the debris, because a mob still visible behind its
## own shards reads as "a pane in front broke, and the monster left". Then real
## physics carries the pieces — tumble biased out of the picture plane so
## nothing lands balanced on an edge — and every piece cools and crumbles to
## embers inside two seconds. Debris that lingers is scenery; debris that
## disperses is an event.
func shatter() -> void:
	if _vessel == null or not _vessel.visible:
		return
	if tier == "hero":
		return  # see mark_dead(): a hero's vessel never breaks
	_dead = true
	clear_intent()
	if _art_img == null and _body_mat != null:
		var t: Texture2D = _body_mat.get_shader_parameter("body_tex")
		if t != null:
			_art_img = t.get_image()
			if _art_img != null and _art_img.is_compressed():
				_art_img.decompress()
	# The handoff: the standing vessel vanishes THIS frame; its pieces replace it.
	# Its shadow goes with it — nothing is standing there to cast one.
	_vessel.transform = Transform3D.IDENTITY
	_vessel.visible = false
	# `setTimeout(() => x.root.classList.add('gone'), 830)` — the plate goes with
	# the body it described. Left standing, a dead foe's name and its 0/13 rail
	# sit on the empty ledge for the rest of the fight, which is what the port
	# was doing: the rite broke the glass and then left the label behind.
	if _plate != null:
		var reap: Tween = create_tween()
		reap.tween_interval(0.45)
		reap.tween_property(_plate, "modulate:a", 0.0, 0.38)
		reap.tween_callback(_plate.hide)
	if _shadow != null:
		var sfade: Tween = create_tween()
		sfade.tween_method(_set_shadow_fade, 1.0, 0.0, 0.35)
	if _debris != null and is_instance_valid(_debris):
		_debris.queue_free()
	_debris = Node3D.new()
	_stage.add_child(_debris)
	var burst: Vector2 = Vector2(0.0, _box_u * 0.05)
	var body_tex: Variant = null
	if _body_mat != null:
		body_tex = _body_mat.get_shader_parameter("body_tex")
	if _shard_shader == null:
		_shard_shader = Shader.new()
		_shard_shader.code = with_erode(SHARD_SHADER)
	# Thinner than the overlay plate: a thick prism reads as a crouton, all
	# fracture-face and no painting.
	var thick: float = _box_u * GLASS_THICK * 0.9
	var spin: float = 10.0 / maxf(1.0, sqrt(_box_u))
	for cell: PackedVector2Array in _death_cells(burst):
		var centre: Vector2 = Vector2.ZERO
		for v: Vector2 in cell:
			centre += v
		centre /= float(cell.size())
		var mesh: ArrayMesh = _prism(cell, thick, Vector2(_quad_w, _box_u), centre)
		if mesh == null:
			continue
		var smat: ShaderMaterial = ShaderMaterial.new()
		smat.shader = _shard_shader
		smat.set_shader_parameter("body_tex", body_tex)
		smat.set_shader_parameter("erode", erode_uv)
		# Explicit, not redundant: a ShaderMaterial returns nil for any uniform
		# never set on the MATERIAL (defaults live in the shader), and a Tween
		# with a nil start value refuses the property outright.
		smat.set_shader_parameter("heat", 1.0)
		smat.set_shader_parameter("dissolve", 0.0)
		var rb: RigidBody3D = RigidBody3D.new()
		rb.physics_material_override = _bounce(0.35, 0.4)
		rb.gravity_scale = 2.4
		rb.angular_damp = 0.6
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = mesh
		mi.set_surface_override_material(0, smat)
		rb.add_child(mi)
		var shape: CollisionShape3D = CollisionShape3D.new()
		var conv: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
		conv.points = mesh.get_faces()
		shape.shape = conv
		rb.add_child(shape)
		rb.position = Vector3(centre.x, centre.y, 0.0)
		_debris.add_child(rb)
		# Blown outward from the burst with a shove toward the lens; tumble is
		# biased around the in-plane axes so plates FLIP out of the picture
		# plane rather than pinwheeling flat and settling upright.
		var out2: Vector2 = centre - burst
		var dir: Vector3 = Vector3.UP
		if out2.length() > _box_u * 0.001:
			dir = Vector3(out2.x, out2.y, 0.0).normalized()
		rb.linear_velocity = dir * _box_u * _frand(0.45, 1.05) \
			+ Vector3(0.0, _box_u * 0.35, _box_u * _frand(0.6, 1.5))
		rb.angular_velocity = Vector3(
			_frand(-spin, spin) * 1.3,
			_frand(-spin, spin) * 1.3,
			_frand(-spin, spin) * 0.5)
		var cool_t: Tween = rb.create_tween()
		cool_t.tween_property(smat, "shader_parameter/heat", 0.0,
			_frand(0.9, 1.4)) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		# Short lives, staggered: most pieces crumble at or just after first
		# bounce. A plate that settles flat shows the lens only its side band —
		# debris left lying around is where the "standing glass" read came from.
		var fade_t: Tween = rb.create_tween()
		fade_t.tween_interval(_frand(0.55, 1.05))
		fade_t.tween_property(smat, "shader_parameter/dissolve", 1.0, 0.35)
		fade_t.tween_callback(rb.queue_free)
	_spawn_burst_flash(burst)
	_spawn_embers(burst)
	# The flash: the vessel's fire escapes all at once, thrown FORWARD onto the
	# flying pieces, then dies away with the embers.
	if _fire != null and rite_fx:
		_fire.position = Vector3(burst.x, burst.y, _box_u * 0.5)
		_fire.light_energy = 4.5
		var flash_t: Tween = create_tween()
		flash_t.tween_property(_fire, "light_energy", 0.0, 0.7) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_shake = 1.0
	# The stage clears itself; nothing of the rite may stand around afterwards.
	var d_t: Tween = _debris.create_tween()
	d_t.tween_interval(2.4)
	d_t.tween_callback(_debris.queue_free)


## One-shot ember burst: sparks thrown with the shards, floating a beat longer.
func _spawn_embers(burst: Vector2) -> void:
	if not rite_fx:
		return
	var emb: CPUParticles3D = CPUParticles3D.new()
	emb.one_shot = true
	emb.explosiveness = 1.0
	emb.amount = 48
	emb.lifetime = 0.9
	emb.lifetime_randomness = 0.5
	var qm: QuadMesh = QuadMesh.new()
	qm.size = Vector2.ONE * _box_u * 0.05
	emb.mesh = qm
	emb.material_override = _add_mat(_fx_tex("ember"))
	emb.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	emb.emission_sphere_radius = _box_u * 0.14
	emb.direction = Vector3(0.0, 0.5, 1.0)
	emb.spread = 180.0
	emb.gravity = Vector3(0.0, -_box_u * 1.6, 0.0)
	emb.initial_velocity_min = _box_u * 0.8
	emb.initial_velocity_max = _box_u * 2.4
	emb.damping_min = _box_u * 0.5
	emb.damping_max = _box_u * 1.2
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(1.0, 0.86, 0.5, 1.0))
	grad.add_point(0.55, Color(1.0, 0.55, 0.2, 0.85))
	grad.set_color(1, Color(0.9, 0.3, 0.08, 0.0))
	emb.color_ramp = grad
	var curve: Curve = Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	emb.scale_amount_curve = curve
	emb.position = Vector3(burst.x, burst.y, _box_u * 0.1)
	_debris.add_child(emb)
	emb.finished.connect(emb.queue_free)


## The impact frame: a radial flare that blooms and is gone in a quarter second.
func _spawn_burst_flash(burst: Vector2) -> void:
	if not rite_fx:
		return
	var mi: MeshInstance3D = MeshInstance3D.new()
	var qm: QuadMesh = QuadMesh.new()
	qm.size = Vector2.ONE * _box_u * 1.1
	mi.mesh = qm
	var m: ShaderMaterial = _add_mat(_fx_tex("burst"))
	mi.material_override = m
	mi.position = Vector3(burst.x, burst.y, _box_u * 0.3)
	mi.scale = Vector3.ONE * 0.55
	_debris.add_child(mi)
	var tw: Tween = mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * 1.5, 0.28) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "shader_parameter/tint", Color(0, 0, 0, 0), 0.28) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)


## FX sprites are additive (black reads as transparent); a missing file falls
## back to a procedural radial gradient.
##
## The IMPORTED resource first, and only then the raw file. `Image.load_from_file`
## bypasses the import system, which is fine in the editor and is a hole in an
## exported build — the engine says so on every death ("this will not work on
## export"). Reading the resource means the shipped `.ctex` is what plays, and
## the raw read stays as the mid-session path for art dropped in without a
## reimport.
static func _fx_tex(fx_name: String) -> Texture2D:
	if _fx_cache.has(fx_name):
		var hit: Texture2D = _fx_cache[fx_name]
		return hit
	var path: String = "res://assets/art/enemies/fx/%s.png" % fx_name
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	if tex == null and FileAccess.file_exists(path):
		var img: Image = Image.load_from_file(path)
		if img != null:
			tex = ImageTexture.create_from_image(img)
	if tex == null:
		var g: Gradient = Gradient.new()
		g.set_color(0, Color(1.0, 0.92, 0.7, 1.0))
		g.add_point(0.35, Color(1.0, 0.55, 0.2, 1.0))
		g.set_color(1, Color(0.0, 0.0, 0.0, 1.0))
		var gt: GradientTexture2D = GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(0.5, 0.0)
		gt.width = 64
		gt.height = 64
		tex = gt
	_fx_cache[fx_name] = tex
	return tex


## Additive FX sprites, with alpha DERIVED rather than sampled — because there is
## none to sample. `burst.png` and `ember.png` are both PNG colour type 2: RGB, no
## alpha channel, so `texture().a` reads 1.0 at every texel.
##
## Under `BLEND_MODE_ADD` that is not harmless. Godot's additive blend accumulates
## alpha alongside colour, so the black field of a 512px burst sprite added nothing
## to the colour and drove this transparent SubViewport's alpha to 1 across the
## whole quad. The result composited over the battlefield as an **opaque black
## square**, roughly 1.65× the creature's height, behind every death — and it read
## as part of the flash rather than as a bug, which is why it survived.
##
## An additive sprite authored on black wants alpha = its own brightness. That is
## one line in a shader and would otherwise be an art change to two files.
## `StandardMaterial3D` cannot express it: there is no derive-alpha-from-luminance
## affordance on `BaseMaterial3D`.
##
## The vertex stage reproduces `BILLBOARD_ENABLED` + `billboard_keep_scale`
## exactly, rather than dropping billboarding on the argument that this stage's
## camera never rotates. It does not today, and the argument would be correct
## today, and it would be a trap the first time one does.
const FX_SHADER: String = """
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, shadows_disabled;

uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec4 c = texture(tex, UV);
	// COLOR is the particle ramp — CPUParticles3D writes it, and the ember ramp
	// fades its alpha to zero. A plain quad leaves COLOR white, so one path serves
	// the flash and the sparks without a second material.
	ALBEDO = c.rgb * COLOR.rgb * tint.rgb;
	ALPHA = dot(c.rgb, vec3(0.299, 0.587, 0.114)) * COLOR.a * tint.a;
}
"""


static func _add_mat(tex: Texture2D) -> ShaderMaterial:
	if _fx_shader == null:
		_fx_shader = Shader.new()
		_fx_shader.code = FX_SHADER
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = _fx_shader
	m.set_shader_parameter("tex", tex)
	# Assigned explicitly even though the shader declares a default: a uniform that
	# has never been set is not yet a property on the material, so
	# `tween_property(m, "shader_parameter/tint", ...)` fails at runtime with "does
	# not exist in object". The declared default is for the shader; this is for the
	# Tween.
	m.set_shader_parameter("tint", Color(1, 1, 1, 1))
	return m


## The death ramp, 0..1. Public so the bench can hold it at a frame the eye can
## look at — the benchmark's own rite is 200ms and unwatchable in a still.
func set_ignite(v: float) -> void:
	_ignite = clampf(v, 0.0, 1.0)
	if _fire != null:
		_fire.light_energy = 4.0 * _ignite
	if _body_mat != null:
		_body_mat.set_shader_parameter("emission_gain", 0.85 + 1.0 * _ignite)
		# Only the groove's INNERMOST band may emit, and only under this (§5.3). The
		# gate is in the shader; this is the ramp that opens it.
		_body_mat.set_shader_parameter("crack_ignite", _ignite)
	if _glass_mat != null:
		_glass_mat.set_shader_parameter("ignite", _ignite)


# ---------------------------------------------------------------- bench seams

## Live knobs. The glass constants are material properties and light energies
## rather than baked numbers, so a tuning surface can move them while it runs.
func set_glass_param(param: StringName, value: float) -> void:
	match param:
		&"ignite":
			set_ignite(value)
		&"breathe":
			_breathe = value
		&"bump", &"emission_gain":
			if _body_mat != null:
				_body_mat.set_shader_parameter(param, value)
		&"flare_gain":
			# Both, deliberately: the material so the actor on screen changes now,
			# and the static so the next actor the bench builds keeps the setting.
			flare_gain = value
			if _body_mat != null:
				_body_mat.set_shader_parameter("flare_gain", value)
		&"glass_area":
			_glass_area = value
			_rebuild_glass()
		&"shadow":
			_shadow_opacity = value
			_update_shadow()
		&"roughness":
			_glass_material().set_shader_parameter("rough", value)
		&"refraction":
			_glass_material().set_shader_parameter("bend", value)
		&"alpha":
			_glass_material().set_shader_parameter("tint_a", value)
		&"ior":
			_glass_material().set_shader_parameter("ior", value)
		&"key", &"rim", &"fire":
			var lamp: Light3D = _key if param == &"key" \
				else (_rim if param == &"rim" else _fire)
			if lamp != null:
				lamp.light_energy = value


## Swing the key light. Real lighting only reads as real when it moves — and
## the shadow is a projection along this light, so it swings with it.
func set_light_angle(yaw_deg: float, pitch_deg: float) -> void:
	if _key != null:
		_key.rotation_degrees = Vector3(pitch_deg, yaw_deg, 0.0)
	_push_key_dir()
	_update_shadow()


## The key's direction, handed to the ward stone so its facets answer the light that is
## actually in the scene. A `DirectionalLight3D` shines down its own -Z, so the direction
## light TRAVELS is `-basis.z` and the direction TOWARD it — which is what a dot against a
## surface normal wants — is `+basis.z`.
func _push_key_dir() -> void:
	if _ward_mat == null or _key == null:
		return
	_ward_mat.set_shader_parameter("key_dir", _key.transform.basis.z.normalized())


## The rite's fade. A FACTOR, not a value: `_update_shadow` owns the opacity
## uniform now and runs every frame, so a tween writing it directly would be
## erased before the next vsync.
func _set_shadow_fade(v: float) -> void:
	_shadow_fade = v
	_update_shadow()


func set_targetable(on: bool) -> void:
	if _dead:
		return
	if _body_mat != null:
		_body_mat.set_shader_parameter("target_lit", 1.0 if on else 0.0)
		return
	modulate = Color(1.28, 1.14, 0.9, 1.0) if on else Color(1, 1, 1, 1)


# ---------------------------------------------------------------- chrome

## A hero wears less chrome than a foe, and the benchmark's own DOM is the reason:
## its `.top-chrome` holds the status row ALONE, and its `.cplate` holds the ward
## chip, the HP vial and the HP label alone. A foe's crown adds `.intent`, and its
## plate adds a name line and a `.facet-row`
## (roguecardv2 src/ui/combat.js:215-257). Those three are therefore never built
## for a hero rather than built and hidden — an invisible widget still holds a
## slot open in a VBox, which is exactly the gap a hero's plate must not have.
##
## Every setter that would drive a missing widget is a no-op, so a caller does not
## have to know which kind of actor it is holding.
func _build_chrome(display_name: String) -> void:
	var is_hero: bool = tier == "hero"

	# ---- crown chrome: intent, then statuses. Anchored ABOVE the art box.
	_crown = VBoxContainer.new()
	_crown.add_theme_constant_override("separation", 4)
	_crown.alignment = BoxContainer.ALIGNMENT_END
	_crown.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_crown.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_crown.offset_bottom = -CROWN_GAP
	_crown.offset_top = -CHROME_BOX_H
	_crown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_crown)

	# The standalone widgets, swapped in for the inline ember chip and the text
	# line that stood here. Both start empty: an intent with no kind and no
	# figure draws nothing (`.intent:empty`), and an actor with no conditions
	# has no row, rather than an invisible one holding a slot open.
	if not is_hero:
		_intent = IntentChip.new(&"", "")
		_crown.add_child(_center(_intent))

	_statuses = StatusRow.new()
	_crown.add_child(_statuses)

	# ---- foot plate: name (foes only), ward + HP vial, facets (foes only).
	# Anchored BELOW the feet.
	_plate = VBoxContainer.new()
	_plate.add_theme_constant_override("separation", 6)
	_plate.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_plate.grow_vertical = Control.GROW_DIRECTION_END
	_plate.offset_top = PLATE_GAP
	_plate.offset_bottom = PLATE_GAP + CHROME_BOX_H
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_plate)

	if not is_hero:
		# `.name` (styles.css:807) — Cinzel, `.1em`, `--text-dim`, and a letterpress
		# of four 1px black offsets plus two soft drops. The port had it in the
		# project's own sans at `--text` with nothing behind it, which is why a foe's
		# name floated over the floor instead of being cut into it.
		#
		# One row, two labels: the affix is its own `<span>` in the benchmark
		# carrying the affix's tone, and it cannot be a colour on the whole line.
		_name_row = HBoxContainer.new()
		_name_row.alignment = BoxContainer.ALIGNMENT_CENTER
		_name_row.add_theme_constant_override("separation", 5)
		_name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_plate.add_child(_name_row)
		_affix_label = _name_style(_label(""), NAME_DIM)
		_affix_label.visible = false
		_name_row.add_child(_affix_label)
		# `.toUpperCase()` (combat.js:606) — done in the markup there, not by the
		# stylesheet, so a name arrives here already spoken in capitals.
		_name_label = _name_style(_label(display_name.to_upper()), _name_tint())
		_name_row.add_child(_name_label)

	var vial_row: HBoxContainer = HBoxContainer.new()
	vial_row.add_theme_constant_override("separation", 6)
	vial_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vial_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.add_child(vial_row)

	# Ward is the painted lock, not a text pill — the same asset the benchmark
	# hangs on the left of the vial. The StyleBoxFlat is transparent at rest;
	# `blockPulse` only ever borrows its shadow.
	_ward_chip = PanelContainer.new()
	_ward_chip_sb = StyleBoxFlat.new()
	_ward_chip_sb.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	_ward_chip_sb.set_border_width_all(0)
	_ward_chip_sb.shadow_color = Color(0.498, 0.831, 1.0, 0.9)  # rgba(127,212,255,0.9)
	_ward_chip_sb.shadow_size = 0
	_ward_chip.add_theme_stylebox_override("panel", _ward_chip_sb)
	_ward_chip.visible = false
	_ward_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The pivot has to follow the chip, not be read once when a pulse starts. A
	# hidden child is skipped by its container's sort, so at the moment the FIRST
	# gain makes the chip visible its size is still zero — reading the pivot there
	# drops the one pulse the animation exists for. The numeral also widens from
	# one digit to two mid-fight, which moves the centre again.
	_ward_chip.resized.connect(func() -> void:
		_ward_chip.pivot_offset = _ward_chip.size * 0.5)
	var ward_box: HBoxContainer = HBoxContainer.new()
	ward_box.add_theme_constant_override("separation", 2)
	_ward_icon = TextureRect.new()
	_ward_icon.texture = WARD_ICON
	_ward_icon.custom_minimum_size = Vector2(WARD_ICON_PX, WARD_ICON_PX)
	_ward_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ward_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ward_box.add_child(_ward_icon)
	_ward = _label("")
	_ward.add_theme_color_override("font_color", GlassStyle.GLASS)
	_ward.add_theme_font_size_override("font_size", 13)
	_ward.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ward_box.add_child(_ward)
	_ward_chip.add_child(ward_box)
	vial_row.add_child(_ward_chip)

	# `.hpbar-wrap` (styles.css:828) — 150px TOTAL holding three things in a row:
	# the ward chip, a vial that takes whatever is left (`flex: 1`), and the
	# reading BESIDE it. The port had the 150 on the vial alone and the numbers
	# centred on top of the rail, which made the row wider than the plate and put
	# white text over a red bar.
	vial_row.custom_minimum_size = Vector2(PLATE_W, 0.0)
	# `width: 150px` is a WIDTH, not a floor. The plate is as wide as the creature
	# — 575px for an elite — and a row left to fill it hands every one of those
	# pixels to the vial, which then stretches a 22px bezel across the whole body.
	vial_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	# `.hp-vial` — the seat the bezel and the rail share. It is taller than the
	# rail because the bezel overhangs it.
	var vial: Control = Control.new()
	vial.custom_minimum_size = Vector2(0.0, VIAL_H)
	vial.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vial_row.add_child(vial)

	# `.hpbar` (styles.css:833) — `flex: 1`, so it fills the vial edge to edge.
	# The 4px side margin this used to carry belongs to the bezelled branch at
	# :825, which never matches; with no bezel there is nothing to inset for.
	var rail: Control = Control.new()
	rail.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	rail.anchor_right = 1.0
	rail.anchor_top = 0.5
	rail.anchor_bottom = 0.5
	rail.offset_top = -RAIL_H * 0.5
	rail.offset_bottom = RAIL_H * 0.5
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vial.add_child(rail)

	# `.hpbar > .ghost` (styles.css:849) — the warm trail the loss leaves behind.
	# It carries the TRACK, and the live rail above it is given a transparent
	# background, so the ghost shows in the gap the fill has just left instead of
	# needing a blend mode Godot's CanvasItemMaterial does not have.
	_hp_ghost = ProgressBar.new()
	_hp_ghost.show_percentage = false
	_hp_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_ghost.set_anchors_preset(Control.PRESET_FULL_RECT)
	_style_rail(_hp_ghost, null, GHOST_WARM)
	rail.add_child(_hp_ghost)
	_hp_bar = ProgressBar.new()
	_hp_bar.show_percentage = false
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	# `linear-gradient(90deg, #b52a3e, #ff6a5e)` — the rail is NOT one red. The
	# dark end is what makes a nearly-empty bar read as nearly empty.
	_style_rail(_hp_bar, _rail_fill(), Color.WHITE)
	rail.add_child(_hp_bar)
	# `background: rgba(255,240,216,0.9); mix-blend-mode: screen` — Godot has no
	# screen blend on a CanvasItem, and additive over the rail's red lands within
	# a couple of percent of what screen produces for these two colours.
	_hp_preview = ColorRect.new()
	_hp_preview.color = PREVIEW_WARM
	_hp_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_preview.visible = false
	var add_mat: CanvasItemMaterial = CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_hp_preview.material = add_mat
	_hp_preview.anchor_top = 0.0
	_hp_preview.anchor_bottom = 1.0
	rail.add_child(_hp_preview)

	# NO BEZEL. `.hp-vial-frame` (styles.css:817) is a real rule and nothing in
	# the reference ever inserts the element it styles: measured on the running
	# benchmark in a two-foe fight, `.hp-vial-frame` matched **zero** nodes across
	# all three rails, and no `<img>` on the page carries that art. `ui-chrome.js`
	# names it in a preload list, which is not a use.
	#
	# The bezel was drawn here from that dead rule, and — worse — it dragged the
	# rail's own numbers with it, because `styles.css:825` is
	# `.hp-vial:has(.hp-vial-frame) .hpbar`. That branch only applies when the
	# frame is present, so this port took radius 2, track alpha 0.35 and a 4px
	# side margin from a selector that never matches. The live rule is
	# `.hpbar` at :833. Its numbers are the ones above now.

	# `.hp-label` (styles.css:850) — 12px 700 `#ffb9b9`, 52px min, left-aligned
	# and tabular, so a rail that is losing digits does not shuffle sideways.
	_hp_label = _label("")
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp_label.custom_minimum_size = Vector2(HP_LABEL_W, 0.0)
	_hp_label.add_theme_font_size_override("font_size", HP_LABEL_PX)
	_hp_label.add_theme_color_override("font_color", HP_LABEL_TINT)
	var alegreya_bold: FontFile = load(GlassStyle.ALEGREYA_700)
	if alegreya_bold != null:
		_hp_label.add_theme_font_override("font", alegreya_bold)
	_hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vial_row.add_child(_hp_label)

	if not is_hero:
		_facets = FacetPips.new()
		_facets.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_plate.add_child(_facets)


## One rail. `fill_tex` paints the gradient the CSS declares on `.fill`; passing
## null falls back to `flat`, which is what the ghost wants.
##
## The track is `rgba(0,0,0,.35)` with NO border: the bezel over it is the frame,
## and `GlassStyle.style_bar`'s rim — tinted by the fill colour at 28% — was
## drawing a red outline round a red bar.
static func _style_rail(bar: ProgressBar, fill_tex: Texture2D, flat: Color) -> void:
	var track: StyleBoxFlat = StyleBoxFlat.new()
	track.bg_color = RAIL_TRACK
	track.set_corner_radius_all(RAIL_RADIUS)
	# `border: 1px solid var(--lead)` — the rail's own edge, which the bezelled
	# branch removes and which therefore never made it into this port. Godot
	# draws a border inside the box, which is where CSS puts it too.
	track.set_border_width_all(1)
	track.border_color = RAIL_EDGE
	bar.add_theme_stylebox_override("background", track)
	if fill_tex == null:
		var solid: StyleBoxFlat = StyleBoxFlat.new()
		solid.bg_color = flat
		solid.set_corner_radius_all(RAIL_RADIUS)
		bar.add_theme_stylebox_override("fill", solid)
		return
	# The live rail sits ON the ghost, so its own track must not hide it.
	var clear: StyleBoxFlat = StyleBoxFlat.new()
	clear.bg_color = Color(0, 0, 0, 0)
	bar.add_theme_stylebox_override("background", clear)
	var box: StyleBoxTexture = StyleBoxTexture.new()
	box.texture = fill_tex
	bar.add_theme_stylebox_override("fill", box)


## `linear-gradient(90deg, #b52a3e, #ff6a5e)`. Stretched with the fill, exactly
## as the CSS is: the gradient lives on the `.fill` element, so it compresses as
## the element narrows rather than staying put behind it.
static func _rail_fill() -> GradientTexture2D:
	var g: Gradient = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([RAIL_FROM, RAIL_TO])
	var t: GradientTexture2D = GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0.0, 0.0)
	t.fill_to = Vector2(1.0, 0.0)
	t.width = 128
	t.height = 8
	return t


static func _label(initial: String) -> Label:
	var l: Label = Label.new()
	l.text = initial
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## `.enemy .name` (styles.css:793). The face is Cinzel, and the rule names no
## `font-weight` at all — so the browser asks for 400, and the benchmark's
## `@font-face` set is 500/600/700/800. CSS matching checks 500 before anything
## heavier when the desired weight is 400, so a foe's name is **500** on screen.
##
## This port shipped only 700 and 800 and drew every name a step too heavy.
## `Cinzel-500.woff2` is byte-identical to the benchmark's own
## `cinzel-latin-500-normal`, as are the 700 and 800 already here.
func _name_style(l: Label, tint: Color) -> Label:
	var cinzel: FontFile = load(GlassStyle.CINZEL_500)
	if cinzel != null:
		# `letter-spacing: 0.1em` at 13.5px is 1.35px, and a glyph advance is an
		# integer here.
		var face: FontVariation = FontVariation.new()
		face.base_font = cinzel
		face.spacing_glyph = 1
		l.add_theme_font_override("font", face)
	l.add_theme_font_size_override("font_size", NAME_PX_BOSS if tier == "boss" else NAME_PX)
	l.add_theme_color_override("font_color", tint)
	# Four 1px offsets at 0.95 is a ring, which is what `outline_size` draws.
	l.add_theme_constant_override("outline_size", NAME_OUTLINE)
	l.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	# `0 2px 8px rgba(0,0,0,.85)` — the softer of the two drops; the `0 0 4px` one
	# is what the outline above already reads as.
	l.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_outline_size", NAME_SHADOW_BLUR)
	return l


## `.elite-e .name` / `.boss-e .name` — a foe that is more than a foe says so in
## its own colour before it does anything else.
func _name_tint() -> Color:
	match tier:
		"elite": return NAME_ELITE
		"boss": return NAME_BOSS
		_: return NAME_DIM


## `<span class="affix-name" style="color:${afx.tone}">` (combat.js:606). Passed
## in rather than looked up: a widget in `presentation/` does not read content.
func set_affix(display: String, tone: Color) -> void:
	if _affix_label == null:
		return
	_affix_label.text = display.to_upper()
	_affix_label.visible = display != ""
	_affix_label.add_theme_color_override("font_color", tone)


## Chips size to content; wrap in a centre container so they don't stretch.
static func _center(node: Control) -> CenterContainer:
	var cc: CenterContainer = CenterContainer.new()
	cc.add_child(node)
	return cc


## Hang the foot plate from the GROUND rather than from this actor's own box.
## An actor whose art carries empty space under the creature sinks its box below
## the line (footY), and a row where every HP vial sat at a different height
## would be unreadable — the benchmark aligns the same way through --chrome-dy.
func align_plate(dy: float) -> void:
	_plate_ground_dy = dy
	_apply_plate_dy()


func _apply_plate_dy() -> void:
	var dy: float = _plate_ground_dy + _plate_clamp_dy
	_plate.offset_top = dy + PLATE_GAP
	_plate.offset_bottom = dy + PLATE_GAP + CHROME_BOX_H


## `clampOne` (combat.js:533) — an actor's status has to be READABLE, and neither
## end of it is safe on its own. A tall sprite lifts its crown behind the HUD bar,
## and any sprite standing on the ground line drops its HP rail into the hand. So
## the crown is pushed DOWN off a ceiling and the plate is pushed UP off a floor;
## nothing moves when the row already fits, which is the common case.
##
## `ceiling` and `floor_y` arrive in the parent's own space, which for a combatant
## is the battlefield — whose top edge IS the stage's, so these are stage numbers.
##
## The measurement takes its own clamp back out before comparing, which is what
## the benchmark buys by writing `--chrome-dy: 0px` and re-reading. Same reading,
## one layout pass instead of two, and it cannot oscillate.
func clamp_chrome(ceiling: float, floor_y: float) -> void:
	if _crown != null:
		var crown_h: float = _crown.get_combined_minimum_size().y
		if crown_h > 1.0:
			var top: float = position.y + _crown.position.y + _crown.size.y \
				- crown_h - _crown_clamp_dy
			var want: float = maxf(0.0, roundf(ceiling - top))
			if not is_equal_approx(want, _crown_clamp_dy):
				_crown_clamp_dy = want
				_crown.offset_top = -CHROME_BOX_H + want
				_crown.offset_bottom = -CROWN_GAP + want
	if _plate != null:
		var plate_h: float = _plate.get_combined_minimum_size().y
		if plate_h > 1.0:
			var bottom: float = position.y + _plate.position.y + plate_h - _plate_clamp_dy
			var want: float = minf(0.0, roundf(floor_y - bottom))
			if not is_equal_approx(want, _plate_clamp_dy):
				_plate_clamp_dy = want
				_apply_plate_dy()


# ---------------------------------------------------------------- state in

## Full sync from an enemy snapshot. `dmg_text` is already formatted by the
## screen ("" when the move deals no damage), `intent` is the move's own kind, and
## `infos` is the content status table for the hover text.
##
## `reap` is `x.reaped` (combat.js:1060): a sync fired mid-drain must NOT bury a
## foe whose HP has just reached zero, because the death rite that is about to run
## is the whole point — the body still has to sag, crack and come apart. Only the
## drain-idle sync, long after the rite, re-asserts the corpse.
func sync(e: EnemyCombatant, dmg_text: String, intent: StringName,
		move_name: String = "", infos: Dictionary = {}, reap: bool = true) -> void:
	set_hp(e.hp, e.max_hp)
	set_ward(e.block)
	set_facets(mini(e.chips, e.facet_max), e.facet_max)
	set_statuses(e.statuses, infos)
	set_intent(intent, dmg_text, move_name)
	if e.hp <= 0 and reap:
		mark_dead()


## HP moves the vial, not the body. The benchmark keeps combat cracks OFF
## (COMBAT_CRACKS = false, combat.js:2642) and its `.lowhp` tilt is explicitly
## scoped away from the raster body — the glass language is spent on the death
## rite, not on attrition. The gem fallback still dims, because that is what a
## gem with no painting has to say.
func set_hp(hp: int, max_hp: int) -> void:
	_max_hp = maxi(max_hp, 1)
	var now: int = maxi(0, hp)
	_hp = now
	var was: float = _hp_bar.value
	_hp_bar.max_value = _max_hp
	_hp_bar.value = now
	_hp_label.text = "%d / %d" % [now, max_hp]
	_ghost_to(was, float(now))
	if _gem != null and not _dead:
		_gem.set_state(_hue, float(now) / float(_max_hp), hp <= 0)


## The trail: hold at the old reading for a beat, then run down to the new one.
## A gain skips the ceremony — the rail is already ahead of the ghost, so there
## is nothing behind to show.
func _ghost_to(was: float, now: float) -> void:
	if _hp_ghost == null:
		return
	_hp_ghost.max_value = _max_hp
	if now >= was or not is_inside_tree():
		_hp_ghost.value = now
		return
	if _ghost_tween != null and _ghost_tween.is_valid():
		_ghost_tween.kill()
	_hp_ghost.value = maxf(_hp_ghost.value, was)
	_ghost_tween = create_tween()
	_ghost_tween.tween_interval(GHOST_HOLD)
	_ghost_tween.tween_property(_hp_ghost, "value", now, GHOST_FALL) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func set_ward(block: int) -> void:
	_ward_chip.visible = block > 0
	if block > 0:
		_ward.text = str(block)
	# `.block-chip.pulse` / `blockPulse` (styles.css:858-859, drain.js:628-630) —
	# only a gain restarts the chip; a fall or a same-value sync stays quiet.
	if block > _previous_ward:
		_block_pulse()
	_previous_ward = block
	# `if (en.block <= 0) syncWardMesh(x.art, false)` (combat.js:1053). A sync
	# only ever takes the shell OFF — it is `blockGain` that puts one up, and
	# routing both through here would let the resync that follows every gain
	# swallow the grow it was supposed to start.
	if block <= 0:
		set_ward_shell(false)


## `.block-chip.pulse` — `blockPulse`, 0.4s ease-out: scale 1.3 and a 22px cyan
## glow at 40%, then home. Kill/restart so a second gain does not stack tweens.
func _block_pulse() -> void:
	if _ward_chip == null or not is_inside_tree():
		return
	if _ward_chip.size == Vector2.ZERO:
		# The FIRST gain is the one this animation exists for, and it is the one
		# that arrives with nothing to scale: the chip was hidden, so its container
		# skipped it and it has neither size nor pivot until the next layout pass.
		# Wait for that pass instead of returning — an early return here is how the
		# first pulse was silently dropped.
		await get_tree().process_frame
		if _ward_chip == null or not is_inside_tree() or not _ward_chip.visible:
			return
	if _block_pulse_tween != null and _block_pulse_tween.is_valid():
		_block_pulse_tween.kill()
	_ward_chip.pivot_offset = _ward_chip.size * 0.5
	_ward_chip.scale = Vector2.ONE
	_ward_chip_sb.shadow_size = 0
	_block_pulse_tween = create_tween()
	_block_pulse_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_block_pulse_tween.tween_property(_ward_chip, "scale", Vector2.ONE * 1.3, 0.16)
	_block_pulse_tween.parallel().tween_property(_ward_chip_sb, "shadow_size", 22, 0.16)
	_block_pulse_tween.tween_property(_ward_chip, "scale", Vector2.ONE, 0.24)
	_block_pulse_tween.parallel().tween_property(_ward_chip_sb, "shadow_size", 0, 0.24)


## A hero has no facet gauge to move — structural integrity is a foe's concept.
## `pop` marks a facet that just went dark, as opposed to a drain-idle resync
## restating a count that has not moved (`x.facets.classList.add('pop')` is only
## in the `chip` and `shatter` branches).
func set_facets(chips: int, facet_max: int, pop: bool = false) -> void:
	if _facets == null:
		return
	_facets.set_pips(chips, facet_max)
	if pop:
		_facets.pop()


## The telegraph. `intent` is the move's own `intent` field — `attack`,
## `attack_block`, `debuff` — NOT its display name: the chip resolves both its
## icons and the single colour everything on it tints to from that id.
##
## The name goes to the tooltip instead of onto the chip, which is what the
## benchmark's `cursor: help` is for. It is passed in rather than looked up
## because a widget in `presentation/` does not read content.
##
## A hero telegraphs nothing — it acts when the player plays a card, so there is
## no next move to announce and no chip to announce it on.
func set_intent(intent: StringName, amount_text: String, move_name: String = "") -> void:
	if _intent == null:
		return
	_intent.set_intent(intent, amount_text)
	_intent.tooltip_text = move_name


## The telegraph has been spent, or there is nothing to telegraph. An intent
## with no kind and no figure draws nothing, so this is one call rather than a
## visibility flag someone downstream has to remember to restore.
## The chip blazes in the beat before the body swings. Forwarded rather than
## reached through, because the chip is this actor's own furniture and the drain
## has no business knowing an EnemyView keeps one.
func telegraph() -> void:
	if _intent != null:
		_intent.telegraph()


func clear_intent() -> void:
	set_intent(&"", "")


func set_statuses(statuses: Dictionary, infos: Dictionary = {}) -> void:
	_statuses.sync(statuses, infos)


## Which piece of this actor's chrome the pointer is over, as `[zone, id]`.
##
## Zones are `&"intent"`, `&"facets"`, `&"name"` and `&"status"` (whose `id` is
## the status the chip carries); `[&"", &""]` is nothing. The copy is NOT built
## here — a widget in `presentation/` does not read content, which is the same
## reason `set_intent` is handed its move name rather than looking one up.
## The screen owns the catalogue and turns a zone into a sentence.
func tip_zone(global_pos: Vector2) -> Array[StringName]:
	var none: Array[StringName] = [&"", &""]
	if _dead:
		return none
	if _statuses != null and _statuses.visible:
		for child: Node in _statuses.get_children():
			var chip: StatusChip = child as StatusChip
			if chip != null and chip.get_global_rect().has_point(global_pos):
				var hit: Array[StringName] = [&"status", chip.status_id]
				return hit
	if _intent != null and _intent.visible \
			and _intent.get_global_rect().has_point(global_pos):
		var intent_hit: Array[StringName] = [&"intent", &""]
		return intent_hit
	if _facets != null and _facets.visible \
			and _facets.get_global_rect().has_point(global_pos):
		var facets_hit: Array[StringName] = [&"facets", &""]
		return facets_hit
	# The affix tip hangs on `.name`, and the affix word is INSIDE it — so the
	# zone is the whole row, not just the creature's own half of it.
	if _name_row != null and _name_row.visible \
			and _name_row.get_global_rect().has_point(global_pos):
		var name_hit: Array[StringName] = [&"name", &""]
		return name_hit
	return none


## `updatePreviews` (combat.js:1606), the part that lands on this actor: the
## slice of the rail an armed card would take, and the death-mark when the
## number is lethal.
##
## `loss` is already block-eaten and vulnerability-multiplied by the engine's
## own preview — the rail only has to say where it starts and how wide it is.
## `dim` is a foe that is a legal target but not the one under the cursor: it
## still shows the loss, but neither the death-mark nor the shatter ring, so a
## three-foe lineup does not claim three kills.
func set_preview(loss: int, lethal: bool) -> void:
	if _hp_preview == null:
		return
	if loss <= 0 or _max_hp <= 0 or _dead:
		_hp_preview.visible = false
		set_marked(false)
		return
	var taken: float = float(mini(_hp, loss)) / float(_max_hp)
	var from: float = float(maxi(0, _hp - loss)) / float(_max_hp)
	_hp_preview.anchor_left = from
	_hp_preview.anchor_right = minf(1.0, from + taken)
	_hp_preview.offset_left = 0.0
	_hp_preview.offset_right = 0.0
	if not _hp_preview.visible:
		_preview_t = 0.0
		_hp_preview.visible = true
	set_marked(lethal)


func clear_preview() -> void:
	if _hp_preview != null:
		_hp_preview.visible = false
	set_marked(false)
	if _facets != null:
		_facets.set_ghost(0, false)


## `.enemy.marked .cracks` — the seams catch the light before the blow is
## thrown. The crack overlay is the same one a real hit scores, held lit rather
## than drawn anew, so a marked creature already looks like it is about to go.
func set_marked(on: bool) -> void:
	if _marked == on:
		return
	_marked = on
	if _glass_mat != null:
		_glass_mat.set_shader_parameter("marked", 1.0 if on else 0.0)
	# The BODY's seams too, which is §5.5's second cheap addition and was a real gap rather
	# than a missing feature: `BODY_SHADER` has carried a `crack_marked` uniform and a
	# docblock claiming it lights the fracture cores since the groove landed, and nothing
	# ever set it. The ward glass was catching the preview and the cracks were not.
	if _body_mat != null:
		_body_mat.set_shader_parameter("crack_marked", 1.0 if on else 0.0)


## `.enemy.doomed` (drain.js:594) — the world-stop beat, and a boss's alone. The
## seams blaze pure white and the body rattles; nothing else about the creature
## changes, because what follows is the death rite it was already going to get.
func set_doomed(on: bool) -> void:
	if _doomed == on:
		return
	_doomed = on
	_doom_t = 0.0
	if _glass_mat != null:
		_glass_mat.set_shader_parameter("doomed", 1.0 if on else 0.0)


## The panes an armed card would take, forwarded to the gauge that draws them.
func set_facet_ghost(ghost: int, will_shatter: bool) -> void:
	if _facets != null:
		_facets.set_ghost(ghost, will_shatter)
