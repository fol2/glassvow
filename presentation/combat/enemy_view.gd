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
## `.hpbar` and the bezel that sits over it (styles.css:838-847).
const RAIL_H: float = 9.0
const RAIL_INSET: float = 4.0     # `margin: 0 4px` under the frame
const RAIL_RADIUS: int = 2
const RAIL_TRACK: Color = Color(0.0, 0.0, 0.0, 0.35)
const RAIL_FROM: Color = Color(0.70980394, 0.16470589, 0.24313726)   # #b52a3e
const RAIL_TO: Color = Color(1.0, 0.41568628, 0.36862746)            # #ff6a5e
const VIAL_H: float = 14.0
const VIAL_FRAME: String = "res://assets/art/ui/hp-vial-frame.png"
const VIAL_FRAME_H: float = 22.0
const VIAL_FRAME_PROUD: float = 5.0
## `.hp-label`
const HP_LABEL_W: float = 52.0
const HP_LABEL_PX: int = 12
const HP_LABEL_TINT: Color = Color(1.0, 0.7254902, 0.7254902)        # #ffb9b9
const PLATE_GAP: float = 8.0
const CROWN_GAP: float = 8.0
const WARD_ICON_PX: float = 20.0

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
const FLARE_RISE: float = 0.09        ## hurtFlash peaks at 30% of its 0.3s
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
## `WARD_DEFAULTS` (ward-params.js) — every one of these is authored through the
## benchmark's own `?vfxedit=1` panel and saved back to that file, so they are
## values somebody chose, not defaults nobody touched.
const WARD_PAD: float = 1.46          ## the shell stands this much proud of the body
const WARD_OPACITY: float = 0.4
const WARD_GROW: float = 0.56         ## growMs 560 — and the fade is the same, reversed
const WARD_SITES: int = 32            ## ring facets, plus five interior ones
const WARD_INNER_SITES: int = 5
const WARD_EDGE_SOFT: float = 0.01    ## all but a hard cut
const WARD_SHAPE_VERTS: int = 8
const WARD_SHAPE_JITTER: float = 0.55
## `refraction: 2` multiplies `normalScale: 0.5` — and `thickness: 0`, which is
## why none of this bends anything (see WARD_SHADER).
const WARD_NORMAL_SCALE: float = 1.0
const WARD_ROUGH: float = 0.0
const WARD_ENV: float = 0.72
const WARD_TINT: Color = Color(0.28627452, 0.5647059, 0.7490196)   # #4a90bf
## Re-gaining ward keeps the silhouette and pulses the FACETS: they collapse to
## 12% and re-cut. `growMs * 0.55`.
const WARD_PULSE: float = 0.56 * 0.55
const WARD_PULSE_TO: float = 0.12

const DOOM_PERIOD: float = 0.09
const DOOM_AT: Array[float] = [0.0, 0.25, 0.5, 0.75, 1.0]
const DOOM_X: Array[float] = [0.0, 1.6, -1.4, 1.0, 0.0]
const DOOM_Y: Array[float] = [0.0, -1.0, 1.2, 1.4, 0.0]

## `choreoAttack` (combat-choreo.js:10) — the body throws itself at what it is
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
var _ward: Label
var _ward_icon: TextureRect
var _statuses: StatusRow
var _plate: VBoxContainer
var _dead: bool = false
## The recoil, signed and in units of KICK_PX — tweened, then composed into the
## idle by _process. Positive is away from the hero, which is where a foe is
## knocked; a hero is knocked the other way (see _away).
var _hit: float = 0.0
var _hit_squash: float = 0.0
var _hit_tween: Tween = null
## The lunge, composed onto the idle in `_process` the same way the recoil is.
## Held as px and a plain scale multiplier so a blow landing mid-swing adds to
## the swing rather than cancelling it — which is what two CSS animations on one
## element do NOT do, and is the better read.
var _lunge_x: float = 0.0
var _lunge_up: float = 0.0
var _lunge_scale: Vector2 = Vector2.ONE
var _lunge_kind: String = ""
var _lunge_dir: float = 1.0
var _lunge_tween: Tween = null
var _flare_tween: Tween = null
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
## eight blows at 1.1 land ~2.9 body of crack rather than 8.8. The real number belongs to
## the damage-to-energy conversion `docs/fracture-model.md` §3 calls the one honest
## fudge, and arrives when `combat_screen.gd` passes damage through.
const DEFAULT_ENERGY: float = 1.1

## The old Voronoi disc web, OFF.
##
## This is the thing the owner identified: every cell hard-clipped to a constant-radius
## 20-gon, given the brightest and most emissive treatment in the effect, so each crack
## sat inside a visible circle and the circles stacked
## (`docs/glass-crack-rendering.md` §2.2). `CrackField` replaces it.
##
## Kept behind a flag rather than deleted, for exactly as long as the death path still
## consumes `_sites` — `shatter()` breaks the body along those cells, and step 6 of
## `docs/fracture-model.md` is what replaces that with a carve along the net. Deleting
## the web now would leave the rite with nothing to break along.
static var discs: bool = false
var _span: float = 0.0          # padded box, in px
var _box_u: float = 0.0         # box HEIGHT, in world units
## Box WIDTH. The art box is square (the benchmark's hit rect) but the painting
## inside it is `contain`-fitted, and 6 of 27 foes plus both heroes are not
## square — drawn on a square quad they stretch. Fit by height, narrow by aspect.
var _quad_w: float = 0.0
var _shadow: MeshInstance3D = null
var _shadow_mat: ShaderMaterial = null
## Where the painting actually touches the ground, read off its own alpha:
## u across the quad, and the lift of the lowest opaque pixel above the box
## bottom (a floating creature casts a smaller, fainter, softer shadow).
var _contact_u: float = 0.5
var _lift: float = 0.0
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
// The vessel leaving. A custom shader that writes ALPHA overrides
// GeometryInstance3D.transparency outright, so the fade has to be a uniform.
uniform float fade = 1.0;

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
	ALPHA = smoothstep(0.12, 0.45, c.a) * fade;

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
## `meshWard` (mesh.js:1300) — the ward shell: a raw-gemstone pane that grows
## over the creature when it takes guard. `syncWardMesh` is the only thing that
## ever showed a ward as more than a number, and this port had the mote underlay
## `archetypeHit` throws for it — vfx.js:492 says so in as many words:
## "meshWard owns the gemstone shell; keep a light mote underlay only" — without
## the shell the underlay is for.
##
## Two fields, both authored in `ward-params.js` and both computed here rather
## than baked to a canvas as the reference does: a signed distance to an
## irregular polygon for the SILHOUETTE, and a Voronoi second-nearest seam over
## 37 facet sites for the NORMAL. 192² bakes are how you do this without a
## shader; we have a shader, and 37 sites per fragment is nothing.
##
## What the shell is NOT is a refractor. `refraction: 2` scales `thickness`,
## which is authored at 0 — so transmission bends nothing, and every bit of the
## structure you see is the seam normal catching the key light at
## `roughness: 0`. Reading the thickness first is what stops this becoming an
## expensive screen-space effect that looks less like the benchmark, not more.
const WARD_SHADER: String = """
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, specular_schlick_ggx;

uniform vec2 outline[16];
uniform int outline_n = 8;
uniform vec2 sites[40];
// How many of them are showing. Grow reveals a PREFIX of the list, so the
// facets are cut into the shell as it forms rather than fading in as a set.
uniform int site_n = 0;
uniform float grow = 0.0;
uniform vec4 tint : source_color = vec4(0.29, 0.565, 0.749, 1.0);
uniform float shell_opacity = 0.4;
uniform float edge_soft = 0.01;
uniform float normal_scale = 1.0;
uniform float rough = 0.0;
uniform float env_gain = 0.72;
// How the shell's 0.4 of opacity is spent: almost none on the pane, most of it
// on the seams and the turning rim.
const float FACE = 0.10;
const float SEAM_A = 0.42;
const float RIM_A = 0.70;

// `signedDistPoly` — negative inside. The winding test is the standard one; a
// gem outline is not convex, so a half-plane test would eat the spikes.
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
	float sd = sd_poly(q);
	float t = edge_soft <= 0.001
		? (sd <= 0.0 ? 1.0 : 0.0)
		: 1.0 - smoothstep(-edge_soft, 0.0, sd);
	t *= grow;
	if (t < 0.01) { discard; }

	// `bakeWardNormal` — the seam between the two nearest facet sites, and only
	// within a hair of it. Everything else is flat glass.
	float d1 = 1e12;
	float d2 = 1e12;
	vec2 s1 = vec2(0.0);
	vec2 s2 = vec2(0.0);
	for (int i = 0; i < site_n; i++) {
		vec2 d = UV - sites[i];
		float dd = dot(d, d);
		if (dd < d1) { d2 = d1; s2 = s1; d1 = dd; s1 = sites[i]; }
		else if (dd < d2) { d2 = dd; s2 = sites[i]; }
	}
	vec2 nrm = vec2(0.0);
	if (site_n >= 2) {
		float edge = sqrt(d2) - sqrt(d1);
		float seam = 0.016;   // `SEAM = N * 0.016` at any bake size
		if (edge < seam) {
			vec2 v = s1 - s2;
			float k = (1.0 - edge / seam) * 1.05;
			nrm = vec2(v.x, -v.y) / max(1e-5, length(v)) * k;
		}
	}
	nrm *= normal_scale;
	NORMAL_MAP = vec3(nrm * 0.5 + 0.5, sqrt(max(0.05, 1.0 - dot(nrm, nrm))));

	// `transmission: 1` with `thickness: 0` is CLEAR glass, and the reference
	// says in as many words that "MeshPhysicalMaterial.opacity barely affects
	// transmission glass" (mesh.js:694) — so `opacity: 0.4` is not a 40% wash
	// over the creature. Read as one it buries the body under a coloured slab,
	// which is what a first pass here did. The shell is nearly invisible across
	// its face; what you actually see of it is the SEAMS catching light and the
	// rim turning away from you.
	float seam = clamp(length(nrm), 0.0, 1.0);
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	ALBEDO = tint.rgb;
	ALPHA = clamp(t * shell_opacity * (FACE + seam * SEAM_A + rim * RIM_A), 0.0, 1.0);
	ROUGHNESS = rough;
	METALLIC = 0.0;
	SPECULAR = 0.5 + env_gain * 0.5;
	// The stage is dark and there is no environment map to catch, so the glint
	// the `envMapIntensity` buys there is spent here as emission — at the seams
	// and the rim only, which is the only place it lands there either.
	EMISSION = (tint.rgb * rim * 0.30 + vec3(1.0) * seam * 0.13) * env_gain;
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
	float amask = smoothstep(0.05, 0.30, c.a);
	ALPHA = mix(smoothstep(0.12, 0.45, c.a), amask, edge) * (1.0 - gone);
	ROUGHNESS = mix(0.55, 0.9, edge);
	METALLIC = 0.0;
	SPECULAR = 0.3;
	// The caps keep the body's own lantern glow (same pow(luma) curve as
	// BODY_SHADER) — a falling piece stays lit the way it was lit standing,
	// which is most of what makes it recognisably the same creature.
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114)) * c.a;
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
	sh.code = BODY_SHADER
	_body_mat = ShaderMaterial.new()
	_body_mat.shader = sh
	_body_mat.set_shader_parameter("body_tex", tex)
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
	# shell shape/scale independent of body warp" (mesh.js:751). A warped ward is
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
const SHADOW_SHADER: String = """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

uniform sampler2D body_tex : source_color, filter_linear_mipmap;
uniform float opacity = 0.55;
uniform float softness = 1.0;

void fragment() {
	// UV.y 1 is the feet; the far end of the cast is the head. A real contact
	// shadow is sharp where the body meets the ground and diffuses with
	// distance, which is the whole job the authored blur radius was doing.
	float far = 1.0 - UV.y;
	float r = (0.003 + 0.035 * far) * softness;
	float a = 0.0;
	for (int i = -1; i <= 1; i++) {
		for (int j = -1; j <= 1; j++) {
			a += texture(body_tex, UV + vec2(float(i), float(j)) * r).a;
		}
	}
	a /= 9.0;
	ALBEDO = vec3(0.0);
	ALPHA = smoothstep(0.04, 0.55, a) * opacity * (1.0 - far * 0.5);
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
const CAST_MIN: float = 0.6
const CAST_MAX: float = 1.15


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
	_lift = (1.0 - (float(bottom) + 1.0) / 64.0) * _box_u


func _build_shadow(tex: Texture2D) -> void:
	_shadow = MeshInstance3D.new()
	var qm: QuadMesh = QuadMesh.new()
	qm.size = Vector2(_quad_w, _box_u)
	# Origin on the BOTTOM edge, so the quad tips away about the contact line
	# rather than sinking half of itself through the floor.
	qm.center_offset = Vector3(0.0, _box_u * 0.5, 0.0)
	_shadow.mesh = qm
	var sh: Shader = Shader.new()
	sh.code = SHADOW_SHADER
	_shadow_mat = ShaderMaterial.new()
	_shadow_mat.shader = sh
	_shadow_mat.render_priority = -2   # under the body (-1) and the glass (1)
	_shadow_mat.set_shader_parameter("body_tex", tex)
	_shadow.set_surface_override_material(0, _shadow_mat)
	_shadow.position = Vector3(
		(_contact_u - 0.5) * _quad_w, -_box_u * 0.5 + _lift * 0.15, 0.0)
	_stage.add_child(_shadow)
	_update_shadow()


## Project the silhouette along the key light. This is the entire shadow model:
## run per unit height gives the lean, its magnitude gives the length, and the
## ground tilt does the foreshortening. Swing the key and the shadow swings —
## which the authored version could never do at any number of knobs.
func _update_shadow() -> void:
	if _shadow == null or _key == null:
		return
	var l: Vector3 = -_key.transform.basis.z
	# A light at or below the horizon would throw the shadow to infinity.
	l.y = minf(l.y, -0.12)
	var run: float = clampf(1.0 / -l.y, CAST_MIN, CAST_MAX)
	# Lift is the gap between the lowest painted pixel and the ground line: a
	# creature that floats casts a smaller, fainter, softer shadow, and one
	# standing on the line casts a sharp one. Free, because the alpha knows.
	var f: float = clampf(_lift / maxf(_box_u, 0.0001), 0.0, 0.6)
	var s: float = 1.0 - f * 0.5
	# Shear and shrink in ONE basis. Node3D.scale is DERIVED from the basis, so
	# assigning it after a sheared basis re-orthonormalises and silently throws
	# the shear away — the shadow then stands straight up behind the creature.
	var shear: Basis = Basis.IDENTITY
	shear.x = Vector3(s, 0.0, 0.0)
	shear.y = Vector3(clampf(l.x * run, -1.2, 1.2) * s, run * s, 0.0)
	_shadow.transform.basis = \
		Basis(Vector3.RIGHT, deg_to_rad(-GROUND_TILT_DEG)) * shear
	_shadow_mat.set_shader_parameter("opacity", _shadow_opacity * (1.0 - f * 1.2))
	_shadow_mat.set_shader_parameter("softness", 1.0 + f * 4.0)


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
	_vessel.scale = Vector3(
		(1.0 - SQUASH * _hit_squash) * _lunge_scale.x,
		(1.0 + SQUASH * _hit_squash) * _lunge_scale.y, 1.0)
	_vessel.rotation.z = 0.0
	# `float` is the one idle term that is NOT a warp: a whole-body lift in stage
	# px, never negative, so a wisp hangs above the line it was placed on rather
	# than sinking through it.
	var lift: float = 0.0
	if _idle_float > 0.0:
		lift = maxf(0.0, _idle_float * FLOAT_PX * IDLE_INTENSITY
			* sin(t * FLOAT_RATE + _phase * 0.7)) * UNIT
	var tremble: Vector2 = _doom_tremble(delta)
	_vessel.position = Vector3(
		(_hit * KICK_PX + _lunge_x + tremble.x) * UNIT,
		lift + (_lunge_up + tremble.y) * UNIT, 0.0)


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


## The ward shell. Built once and left hidden; `set_ward_shell` is what turns it
## on, and `_step_ward` is what forms it.
func _build_ward_shell() -> void:
	_ward_mesh = MeshInstance3D.new()
	var qm: QuadMesh = QuadMesh.new()
	qm.size = Vector2(_quad_w * WARD_PAD, _box_u * WARD_PAD)
	_ward_mesh.mesh = qm
	var sh: Shader = Shader.new()
	sh.code = WARD_SHADER
	_ward_mat = ShaderMaterial.new()
	_ward_mat.shader = sh
	_ward_mat.render_priority = 4   # over the body and the crack glass
	_ward_mat.set_shader_parameter("tint", WARD_TINT)
	_ward_mat.set_shader_parameter("shell_opacity", WARD_OPACITY)
	_ward_mat.set_shader_parameter("edge_soft", WARD_EDGE_SOFT)
	_ward_mat.set_shader_parameter("normal_scale", WARD_NORMAL_SCALE)
	_ward_mat.set_shader_parameter("rough", WARD_ROUGH)
	_ward_mat.set_shader_parameter("env_gain", WARD_ENV)
	_ward_mat.set_shader_parameter("grow", 0.0)
	_ward_mat.set_shader_parameter("site_n", 0)
	_ward_mesh.set_surface_override_material(0, _ward_mat)
	_ward_mesh.visible = false
	_vessel.add_child(_ward_mesh)
	_reshuffle_ward(0.0)


## `wardHash` (mesh.js:536) — the seeded 0..1 the whole silhouette is drawn from.
static func _ward_hash(seed_v: float, i: int) -> float:
	var x: float = sin(seed_v * 12.9898 + float(i) * 78.233) * 43758.5453
	return x - floor(x)


## `reshuffleWardShape` — a NEW silhouette every time the shell appears fresh, so
## no two guards in a fight are the same stone. Held on the CPU and pushed as
## uniforms; the reference bakes the same numbers into a 192² canvas.
func _reshuffle_ward(seed_v: float) -> void:
	if _ward_mat == null:
		return
	# `wardOutline` — uneven angular spacing plus radius spikes, which is what
	# makes it read as a raw crystal rather than a smooth oval.
	var outline: PackedVector2Array = PackedVector2Array()
	outline.resize(16)
	for i: int in range(WARD_SHAPE_VERTS):
		var ang_j: float = (_ward_hash(seed_v, i) - 0.5) * WARD_SHAPE_JITTER * 0.55
		var ang: float = float(i) / float(WARD_SHAPE_VERTS) * TAU + seed_v * 0.31 + ang_j
		var rad: float = 0.78 \
			+ (_ward_hash(seed_v, i + 17) - 0.5) * WARD_SHAPE_JITTER * 0.42 \
			+ 0.1 * sin(float(i) * 2.15 + seed_v) \
			+ 0.06 * cos(float(i) * 3.7 - seed_v * 0.7)
		rad = clampf(rad, 0.55, 1.18)
		outline[i] = Vector2(cos(ang) * rad, sin(ang) * rad * 1.06)
	_ward_mat.set_shader_parameter("outline", outline)
	_ward_mat.set_shader_parameter("outline_n", WARD_SHAPE_VERTS)

	# `wardSitesFor` — a ring of facets, then five interior ones "so the shell
	# reads as cut glass, not a hollow ring only".
	var sites: PackedVector2Array = PackedVector2Array()
	sites.resize(40)
	for i: int in range(WARD_SITES):
		var a: float = float(i) / float(WARD_SITES) * TAU + seed_v * 0.17
		var r: float = 0.28 + _ward_hash(seed_v, i + 40) * 0.12
		sites[i] = Vector2(_clamp_uv(0.5 + cos(a) * r), _clamp_uv(0.52 + sin(a) * r * 0.92))
	for i: int in range(WARD_INNER_SITES):
		var a: float = seed_v + float(i) * 1.7
		sites[WARD_SITES + i] = Vector2(
			_clamp_uv(0.5 + cos(a) * 0.12), _clamp_uv(0.5 + sin(a) * 0.14))
	_ward_mat.set_shader_parameter("sites", sites)
	_ward_sites_used = -1


## `clampUv` (mesh.js:1133) — a site never sits on the very edge of the map.
static func _clamp_uv(x: float) -> float:
	return clampf(x, 0.05, 0.95)


## Whether a shell is up or on its way up. Read by the sync that restores one on
## a rebuilt screen, so it can tell "already warded" from "just warded".
func ward_shell_on() -> bool:
	return _ward_on


## `meshWard(el, on, {grow})`. Three cases, and the middle one is the reason this
## is not a boolean: gaining ward while you already have it keeps the stone and
## PULSES its facets — they collapse to 12% and re-cut — so a second Ward card
## reads as the shell being reinforced rather than as nothing happening.
func set_ward_shell(on: bool, grow: bool = true) -> void:
	if _ward_mat == null:
		return
	if not on:
		if not _ward_on:
			return   # already off or fading; do not restart the clock on a resync
		_ward_on = false
		_ward_pulsing = false
		_ward_grow_from = _ward_grow
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
	_reshuffle_ward(_rng.randf() * 10000.0)
	_ward_on = true
	_ward_pulsing = false
	_ward_t = 0.0
	_ward_grow = 0.0 if grow else 1.0
	_ward_grow_from = _ward_grow
	_ward_site_f = _ward_grow


## The shell's own clock: grow in, fade out, or pulse its facets. Smoothstep on
## both, and the fade is the grow reversed at the same duration.
func _step_ward(delta: float) -> void:
	if _ward_mat == null:
		return
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
	elif not _ward_on and _ward_grow > 0.0:
		_ward_t += delta
		var u: float = clampf(_ward_t / WARD_GROW, 0.0, 1.0)
		_ward_grow = _ward_grow_from * (1.0 - (u * u * (3.0 - 2.0 * u)))
		_ward_site_f = _ward_grow
		if _ward_grow < 0.02:
			_ward_grow = 0.0
			_ward_site_f = 0.0
	elif _ward_on:
		_ward_site_f = 1.0
	_ward_mesh.visible = _ward_grow > 0.02
	if not _ward_mesh.visible:
		return
	_ward_mat.set_shader_parameter("grow", _ward_grow)
	# `syncWardNormalMap` only rebakes when the floored count steps. There is no
	# bake here, but the uniform write is still worth not doing every frame.
	var n: int = roundi(float(WARD_SITES + WARD_INNER_SITES) * _ward_site_f)
	if n != _ward_sites_used:
		_ward_sites_used = n
		_ward_mat.set_shader_parameter("site_n", n)


## `char-meta.chars[id].mesh` — the per-character idle the benchmark authors and
## this port has been ignoring since the actor was built. Four of the
## twenty-nine characters carry a block and one of them is the HERO: `breathe
## 1.6, sway 0.5, bob 0` — a body that fills its chest harder, leans less and
## does not float. Everything defaults to 1.0, so a character without a block
## idles exactly as it did.
func _read_idle(entry: Dictionary) -> void:
	_idle_over = entry.get("mesh", {})
	_resolve_profile(&"humanoid")


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


## Read a keyframe track at `t`: linear between the offsets in `at`, held at the
## ends. `at` is ascending and the two arrays are the same length.
static func _keyframe(t: float, at: Array[float], v: Array[float]) -> float:
	for i: int in range(1, at.size()):
		if t <= at[i]:
			var span: float = at[i] - at[i - 1]
			var f: float = 0.0 if span <= 0.0 else (t - at[i - 1]) / span
			return lerpf(v[i - 1], v[i], f)
	return v[v.size() - 1]


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
	# TRANS_BACK / EASE_OUT is Godot's nearest reading of the benchmark's
	# cubic-bezier(.34, 1.56, .64, 1) — the overshoot past 1 is the whole reason
	# that curve was chosen, and a plain EASE_OUT loses it.
	_lunge_tween = create_tween()
	_lunge_tween.tween_method(_set_lunge, 0.0, 1.0, seconds) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_lunge_tween.tween_callback(_clear_lunge)
	return seconds


func _set_lunge(t: float) -> void:
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


## `plate.plateBounds` / `plate.blockBounds` (combat-gl.js:2194) — the two boxes
## `chromePulse` aims at on an actor: the foot plate for a facet beat, the ward
## chip for a guard beat. Both are global px, both are empty when the widget is
## not up, and an empty box is what `chrome_pulse` refuses on.
## The height is the CONTENT's, not the box's. `_plate` is anchored bottom-wide
## over a fixed 200px of room it lays its rows out at the top of, so its own rect
## is four fifths empty air below the facets — and `R = min(width, height) · 0.62`
## reads that as a plate three times its real depth, throwing a 124px ring
## centred under the creature's feet instead of a 37px one on the plate.
func plate_rect() -> Rect2:
	if _plate == null or not _plate.is_visible_in_tree():
		return Rect2(global_position + size * 0.5, Vector2.ZERO)
	var box: Rect2 = _plate.get_global_rect()
	box.size.y = minf(box.size.y, _plate.get_combined_minimum_size().y)
	return box


## `plate.blockBounds || plate.plateBounds` (combat-gl.js:950) — a guard beat on
## an actor with no chip up falls back to the whole plate rather than vanishing.
## The zero-width test is not paranoia: the chip lives in an HBoxContainer, so
## the frame it is first shown on it is visible and still unsized, and a beat
## aimed at it that frame would be silently dropped for having no area.
func block_rect() -> Rect2:
	if _ward_chip != null and _ward_chip.is_visible_in_tree() \
			and _ward_chip.size.x > 0.0:
		return _ward_chip.get_global_rect()
	return plate_rect()


## `choreoStagger` (combat-choreo.js:45) — the beat before the vessel fails: the
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
	var tw: Tween = create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(_display, "position", _display.position + Vector2(0.0, 5.0), 0.36)
	tw.parallel().tween_property(_display, "rotation", deg_to_rad(-2.5), 0.36)
	tw.parallel().tween_property(_display, "modulate", Color(0.6, 0.6, 0.6), 0.36)
	return 0.36


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
	if tier != "hero":
		_flare()
	if direct:
		_shove()
	else:
		_nudge()


## Which way a blow throws this actor. Derived rather than passed, on the same
## reasoning as `tier`: the hero stands left of the foes, so a struck foe is
## thrown right and a struck hero is thrown left.
func _away() -> float:
	return -1.0 if tier == "hero" else 1.0


func _shove() -> void:
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	_hit = _away()
	_hit_squash = 1.0
	# TRANS_QUINT / EASE_OUT is the near-equivalent of the benchmark's
	# cubic-bezier(.22, 1, .36, 1): almost all of the travel spent in the first
	# third, so the blow lands hard and the settle is barely noticed.
	_hit_tween = create_tween().set_parallel(true)
	_hit_tween.tween_property(self, "_hit", 0.0, HIT_TIME) \
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_hit_tween.tween_property(self, "_hit_squash", 0.0, HIT_TIME) \
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)


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
	st.set_color(Color(0, 0, 0))
	for face: int in range(2):
		var zz: float = z if face == 0 else -z
		var i: int = 0
		while i < tri.size():
			for k: int in range(3):
				var p: Vector2 = cell[tri[i + k]]
				st.set_uv(Vector2(p.x / box.x + 0.5, 0.5 - p.y / box.y))
				st.add_vertex(Vector3(p.x - origin.x, p.y - origin.y, zz))
			i += 3
	# Side band, quad per edge — where the thickness actually shows.
	st.set_color(Color(1, 0, 0))
	for i: int in range(cell.size()):
		var a: Vector2 = cell[i]
		var b: Vector2 = cell[(i + 1) % cell.size()]
		var quad: Array[Vector3] = [
			Vector3(a.x, a.y, z), Vector3(b.x, b.y, z), Vector3(b.x, b.y, -z),
			Vector3(a.x, a.y, z), Vector3(b.x, b.y, -z), Vector3(a.x, a.y, -z),
		]
		for v: Vector3 in quad:
			st.set_uv(Vector2(v.x / box.x + 0.5, 0.5 - v.y / box.y))
			st.add_vertex(v - Vector3(origin.x, origin.y, 0.0))
	st.generate_normals()
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


## Score a crack. `at` is in body UV; a random point on the body if omitted, which is
## what the two `combat_screen.gd` callers want — they know a hit landed and not where.
##
## Kept as the name every caller already uses. `strike()` below is the real entry point
## and this is the zero-argument door to it, because a blow's energy and direction are
## information `combat_screen.gd` does not have yet.
func crack(at: Vector2 = Vector2(-1, -1)) -> void:
	strike(at, Vector2.ZERO, DEFAULT_ENERGY, 0.5)


## A BLOW, and the seam `docs/fracture-model.md` §2.5 specifies. Feeds the propagator,
## the field the body shader reads, and — while `discs` is on — the old Voronoi web too,
## so the two can be compared in the running game rather than only in the lab.
##
## `at` in body UV (y down); `dir` a unit heading, zero for face-on; `energy` in body
## widths of crack bought, 1.0 being one; `sharp` 0..1 indenter acuity, accepted and
## not yet spent (see `FractureField`'s docblock).
func strike(at: Vector2 = Vector2(-1, -1), dir: Vector2 = Vector2.ZERO,
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
	var grown: Array[Dictionary] = _frac_field.strike(_net, blow_of(p, dir, energy, sharp))
	_net.commit(grown)
	# The field composites only the NEW strands — never re-walks the network — so the
	# eighth blow costs what the first did.
	_cracks.add(grown)
	_push_crack_field()
	# `_sites` keeps filling whatever `discs` says. It is TWO things wearing one name:
	# the standing web's cell seeds, and the death path's break pattern — `shatter()`
	# partitions the body along cells grown from it. Skipping the append with the web
	# off would send the rite to `_death_sites`, the unrelated ring fallback, which is
	# precisely the "the shatter must equal the cracks it was carrying" condition being
	# violated. Step 6 replaces this with a carve along the net and the field goes away.
	_sites.append(_from_uv(p))
	if discs:
		_rebuild_glass()


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
	# ...and then the SITES are topped up to the cap. This is transitional and it is the
	# one place the promise in `CONCEPTS.md` › Crack is not yet kept: `shatter()` still
	# partitions the body along Voronoi cells grown from `_sites`, and under three sites
	# it falls back to `_death_sites`' unrelated rings. Topping up keeps the partition
	# legible until step 6 carves along the net instead — at which point the shard count
	# follows the damage for real and this block, `_sites`, and the rings all go.
	#
	# SITES ONLY, deliberately. Calling `crack()` here would score new propagated stars
	# a frame before the break, which is visible and is exactly the thing the owner ruled
	# against. The grooves you see are the ones the creature was already showing.
	while _sites.size() < MAX_SITES:
		_sites.append(_from_uv(_somewhere_on_body()))
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
func _death_cells(burst: Vector2) -> Array[PackedVector2Array]:
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
		_shard_shader.code = SHARD_SHADER
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
	_update_shadow()


func _set_shadow_fade(v: float) -> void:
	if _shadow_mat != null:
		_shadow_mat.set_shader_parameter("opacity", _shadow_opacity * v)


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
	var crown: VBoxContainer = VBoxContainer.new()
	crown.add_theme_constant_override("separation", 4)
	crown.alignment = BoxContainer.ALIGNMENT_END
	crown.set_anchors_preset(Control.PRESET_TOP_WIDE)
	crown.grow_vertical = Control.GROW_DIRECTION_BEGIN
	crown.offset_bottom = -CROWN_GAP
	crown.offset_top = -200.0
	crown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(crown)

	# The standalone widgets, swapped in for the inline ember chip and the text
	# line that stood here. Both start empty: an intent with no kind and no
	# figure draws nothing (`.intent:empty`), and an actor with no conditions
	# has no row, rather than an invisible one holding a slot open.
	if not is_hero:
		_intent = IntentChip.new(&"", "")
		crown.add_child(_center(_intent))

	_statuses = StatusRow.new()
	crown.add_child(_statuses)

	# ---- foot plate: name (foes only), ward + HP vial, facets (foes only).
	# Anchored BELOW the feet.
	_plate = VBoxContainer.new()
	_plate.add_theme_constant_override("separation", 6)
	_plate.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_plate.grow_vertical = Control.GROW_DIRECTION_END
	_plate.offset_top = PLATE_GAP
	_plate.offset_bottom = PLATE_GAP + 200.0
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
	# hangs on the left of the vial.
	_ward_chip = PanelContainer.new()
	_ward_chip.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_ward_chip.visible = false
	_ward_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
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

	# `.hp-vial:has(.hp-vial-frame) .hpbar` (styles.css:838) — with the bezel
	# present the rail loses its own lead border and inset hairline and becomes a
	# 9px slot inset 4px at each end. The bezel supplies the frame; two frames
	# would just fight.
	var rail: Control = Control.new()
	rail.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	rail.anchor_right = 1.0
	rail.offset_left = RAIL_INSET
	rail.offset_right = -RAIL_INSET
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

	# `.hp-vial-frame` (styles.css:831) — the bezel, 5px proud at each end and
	# 22px tall over a 9px slot. The art has been in assets/art/ui the whole time
	# and only the HUD lab ever loaded it.
	var frame_tex: Texture2D = load(VIAL_FRAME) as Texture2D
	if frame_tex != null:
		var frame: TextureRect = TextureRect.new()
		frame.texture = frame_tex
		frame.stretch_mode = TextureRect.STRETCH_SCALE
		# Without this a TextureRect's minimum size is its TEXTURE's size, and a
		# minimum beats an anchor — the 512x179 bezel art laid itself across the
		# whole screen instead of sitting in its 94x22 slot.
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.set_anchors_preset(Control.PRESET_LEFT_WIDE)
		frame.anchor_right = 1.0
		frame.offset_left = -VIAL_FRAME_PROUD
		frame.offset_right = VIAL_FRAME_PROUD
		frame.anchor_top = 0.5
		frame.anchor_bottom = 0.5
		frame.offset_top = -VIAL_FRAME_H * 0.5
		frame.offset_bottom = VIAL_FRAME_H * 0.5
		vial.add_child(frame)

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


## `.enemy .name` (styles.css:807). The face is Cinzel; the benchmark's own
## `font-weight: normal` resolves to the 500 it loads (fonts.js:15) and this port
## bundles only 700 and 800, so the name is one step heavier than the
## benchmark's. Bundling a fourth weight is an assets change, not a lane change.
func _name_style(l: Label, tint: Color) -> Label:
	var cinzel: FontFile = load(GlassStyle.CINZEL_700)
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
	_plate.offset_top = dy + PLATE_GAP
	_plate.offset_bottom = dy + PLATE_GAP + 200.0


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
	# `if (en.block <= 0) syncWardMesh(x.art, false)` (combat.js:1053). A sync
	# only ever takes the shell OFF — it is `blockGain` that puts one up, and
	# routing both through here would let the resync that follows every gain
	# swallow the grow it was supposed to start.
	if block <= 0:
		set_ward_shell(false)


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
