class_name CombatScreen
extends Control
## The combat screen (M5a skeleton). Owns the views and the event sequencer;
## game truth lives in GlassvowGame — this layer only plays events back.
## Composition-root injection: main instantiates with the game (SKILL §2).
##
## Playback contract: the startCombat batch is hard-synced (views don't exist
## until after apply returns); every later batch replays through the
## sequencer, then _sync_all() corrects any drift once the pump idles.

signal combat_over(result: String)
signal result_continue
signal menu_requested
signal potion_requested(slot: int)

## The composition this screen is drawn for, and the act it is showing.
##
## Both used to be constants here — a ground line of 232, a hero at x 200, a
## 1180x820 stage — because the project rendered at exactly one shape and every
## number could be the `pad-landscape` value written out longhand. They now come
## from `assets/layout/combat-layout.json` through `LayoutBook`, which is the
## same table (`src/battlefield-layout.js`) read rather than transcribed.
##
## The defaults are not arbitrary: `pad-landscape` at act 0 resolves to exactly
## the numbers that were here, so a default-constructed screen is unchanged to
## the pixel. That identity is the regression gate for this whole change —
## `CONCEPTS.md:193` rests the parity method on this shape being 1:1 with the
## reference build, so every `file:line` in this file stops meaning anything the
## day a default boot stops landing on 1180x820 act 0.
var shape: StringName = StageShape.IDENTITY
var act: int = 0

## Ground line, hero seat, formations and plates, as authored. Read through
## `_layout()` rather than directly: the flex is spent at read time, against the
## stage as it is at that moment.
var _authored: Dictionary = {}
var _placed: Dictionary = {}
var _placed_at: Vector2i = Vector2i.ZERO

## The three plates of an act, by act INDEX and layer name.
##
## The file names are one-based and the act index is zero-based, which is the
## whole of the mapping and also how it went wrong: this was
## `"…/act1-%s.png"` with the digit baked in, so every act drew act one's
## scenery. All three sets have been in `assets/art/stage/` since the import,
## and the book has authored act 1 and act 2 overrides for every shape from the
## day it landed — the layout moved when `--act=` changed and the painting never
## did. Upstream picks the same way, from `themes.js`'s `plates` (theme 0 names
## `act1-*`, theme 1 `act2-*`, theme 2 `act3-*`).
const STAGE_ART: String = "res://assets/art/stage/act%d-%s.png"

## How long one plate takes to complete a drift cycle. NOT in the book, and not
## an oversight: `battlefield-layout.js` authors the amplitude (`drift`) but no
## period at all, so these three were read off the running benchmark's own
## elements. They are a property of the animation, not of the shape.
const PLATE_PERIODS: Dictionary[String, float] = {
	"backdrop": 26.0, "mid": 18.0, "ledge": 12.0,
}

## The benchmark reads the hero's art off the run's aspect
## (`runCatalogues().aspects[run.aspect].id`, and `HERO_LOOKS[aspect]` for the
## hue — art.js:329-332). The live content book carries both, so the hero is
## read from it: an Ashwarden run finally wears the Ashwarden's glass, and the
## Own Shade duel reads as you against your own shade. The fallback is the
## slice-content case — labs and tests that never embark a run.
const HERO_FALLBACK_ART: StringName = &"duskblade"
const HERO_FALLBACK_HUE: float = 225.0  # HERO_LOOKS[0].hue in art.js

## `.combat-screen::after` — `rgba(5,7,14,.55)` reached at 75% of a 300px band.
const MIST: Color = Color(0.019607844, 0.02745098, 0.05490196, 0.55)
const MIST_H: float = 300.0

## `#vignette` — `rgba(4,5,12,.55)` at the ellipse's rim.
const VIGNETTE_EDGE: Color = Color(0.015686275, 0.019607844, 0.047058824, 0.55)
## `@keyframes lowhp` — `rgba(255,40,40,.12)` over 120px to `.34` over 180px, and
## back, over 1.6s. `.lowhp` is `hp / maxHp <= 0.3` (combat.js:451).
const LOW_HP_TINT: Color = Color(1.0, 0.15686275, 0.15686275)
const LOW_HP_AT: float = 0.3
const LOW_HP_PERIOD: float = 1.6
const LOW_HP_REACH: Array[float] = [120.0, 180.0]
const LOW_HP_ALPHA: Array[float] = [0.12, 0.34]

## `.stage-dim` (styles.css:701) — the light economy, and the one piece of this
## screen that is a rule rather than a mood: your HP **is** the lantern. As the
## player bleeds a pool of darkness closes in around them, and it darkens the
## PAINTED GROUND ONLY — z 4 sits over the plates and under the cast shadows, the
## warp canvas and the battlefield, so foes, bodies and chrome stay lit. That
## restriction is the whole design: losing does not make the fight harder to
## read, it makes the world around it shrink.
##
## The full-screen version of the same radial is `#lantern`, which is empty until
## defeat — see `_build_lantern`.
## Ambient darkening, OFF by owner decision (2026-07-27).
##
## The benchmark dims the battlefield twice: `.stage-dim` lays the HP lantern's
## pool over the plates with a hole cut around the hero, and `#vignette` rings
## the screen. Both are faithful and both are switched off here — a deliberate
## divergence, not a parity gap, and the only one on this screen.
##
## The layers are still BUILT. The pool carries the lantern's position for the
## aim lean and hands its gradient to the defeat snuff; the vignette carries the
## low-HP pulse. Deleting them would take those with it, so they are made
## invisible instead and everything below keeps its numbers for the day the
## decision is revisited.
const DIM_SCREEN: bool = false
const DIM_DARK: Color = Color(0.011764706, 0.015686275, 0.039215688)  # rgb(3,4,10)
## `transparent 42%, dark 100%` — the clear hole, as a fraction of the radius.
const DIM_HOLE: float = 0.42
## `la = t * 0.82` and `lr = 1500 - t * 1000`, where
## `t = clamp((0.68 - hp/maxHp) / 0.53, 0, 1)`. Full HP is no darkness at all;
## the pool starts closing at 68% and is at its tightest by 15%.
const DIM_AT: float = 0.68
const DIM_SPAN: float = 0.53
const DIM_MAX_ALPHA: float = 0.82
const DIM_RADIUS: Array[float] = [1500.0, 500.0]
## `gutter 1.9s infinite` on the layer's own opacity, above `t > 0.55` — the
## flame is failing, not the light level changing.
const DIM_GUTTER_AT: float = 0.55
const DIM_GUTTER_PERIOD: float = 1.9
const DIM_GUTTER_OFFSETS: Array[float] = [0.0, 0.41, 0.45, 0.62, 0.78, 1.0]
const DIM_GUTTER_VALUES: Array[float] = [1.0, 0.8, 0.97, 0.86, 0.96, 1.0]
## CSS's default `animation-timing-function`, which — unlike a WAAPI keyframe
## list — is applied to EACH interval rather than once to the iteration. That
## difference is why `Motion.keyframe` cannot be used on its own here.
const CSS_EASE: Array[float] = [0.25, 0.1, 0.25, 1.0]
## `aimMove` (combat.js:1913) — "the lantern leans toward where you mean to
## strike: intent illuminates". A third of the way, not all of it.
const DIM_AIM_LEAN: float = 0.3

## `#lantern.snuff` (styles.css:91, fired at drain.js:967) — you lose, and the
## lantern goes out. The SAME radial `.stage-dim` paints, but full-screen and at
## `--la: 1` with `--lr: 160px`: the whole view collapses to a dying point of
## light around the body that was carrying it. Nothing transitions `#lantern`'s
## background, so it snaps there and then gutters for the beat it is held.
const SNUFF_ALPHA: float = 1.0
const SNUFF_RADIUS: float = 160.0

## `#transit`'s two combat leaves — `victory-out` and `defeat` — used to live
## here, fired from `victoryFlow` / `defeatFlow` the way combat.js does. They
## moved to `TransitionLayer` (main's ceremony layer) on the finding that a
## leaf built inside this screen dies with it: `_clear_route()` frees the
## screen within a frame of `combat_over`, so the 900/700ms leaves never
## played. Main now fires them where the route swap cannot reach.

## `body.worldstop` (styles.css:101) — a boss dies and the world stops. Colour
## drains to 7% saturation at 85% brightness over a 0.22s `ease`, holds for one
## silent beat, and comes back the same way.
##
## DEPARTURE, and it is structural rather than a choice: there, the filter is put
## on `#screen` so the `#mesh` canvas BESIDE it keeps its colour — every warped
## body stays lit while the DOM world greys out. This port has no separate canvas
## for bodies; an actor is a node in the same tree. So the drain takes the actors
## with it. The shot survives because what it is actually about is white: the
## doomed seams stroke pure `#ffffff`, and `saturate()` does nothing to white.
const WORLDSTOP_SAT: float = 0.07
const WORLDSTOP_BRIGHT: float = 0.85
const WORLDSTOP_FADE: float = 0.22
## `V.hitstop(110)` then `await sleep(820)` (drain.js:597).
const WORLDSTOP_HOLD: float = 0.82
const WORLDSTOP_STOP: float = 110.0

## `#grain` — opacity .05, and `grain 0.9s steps(1)` is eight discrete jumps.
const GRAIN_AMOUNT: float = 0.05
const GRAIN_STEP: float = 0.9 / 8.0
## `translate(±3–7%)` of a 240px tile, in whole pixels so the noise re-rolls
## rather than resampling itself.
const GRAIN_JUMPS: Array[Vector2] = [
	Vector2(0.0, 0.0), Vector2(-14.0, 7.0), Vector2(10.0, -17.0), Vector2(-7.0, 14.0),
	Vector2(17.0, 5.0), Vector2(-14.0, -10.0), Vector2(7.0, 17.0), Vector2(-10.0, -7.0)]

## How tall the hand box is, when the book is silent. Its overhang past the
## stage's bottom edge is `UIC.hand.bottom` — 12 on a pad, 6 in phone portrait,
## 33 held sideways — and the box height is now `chrome.hand.h`.
##
## That entry is new, and this constant is what it had to reconcile with: the
## benchmark states the box as `.hand-zone { height: 260px }` measured from the
## zone's own bottom, which already includes the overhang, while this port
## stated 248 measured from the STAGE's bottom. 248 + 12 is 260, so the two were
## the same number written from opposite edges, and pad-landscape is unmoved.
const HAND_H: float = 248.0

## The size the Kindle chip is DRAWN at, whatever the book then scales it to.
const KINDLE_BOX: Vector2 = Vector2(116.0, 32.0)

## `clampCombatChrome` (combat.js:516) — the two lines an actor's status may not
## cross. Measured on the reference at pad-landscape they come out at 60 and 654,
## and BOTH are routinely hit: a gravewarden's intent sits at y25 unclamped, fully
## behind the 56px HUD bar, and a sporeling's HP rail hangs 9px into the hand.
##
## The ceiling is the HUD bar's own bottom edge plus a hair, floored at 6 for a
## screen with no bar. It reads the constant rather than the live widget on
## purpose: the bar flies in at the top of a fight, and a ceiling measured off a
## widget still in flight would drag every crown down with it.
const CHROME_CEIL_PAD: float = 4.0
const CHROME_CEIL_MIN: float = 6.0
## The floor is the RESTING hand-fan's top, and `handChromeCeiling` builds it from
## the fan's law rather than from live cards — "static on purpose", because a card
## lifting on hover or leaving for a cast would otherwise yank every HP plate on
## the stage up and down. The slack is the benchmark's own: chrome may sit 50px
## into the upper hand band, where resting cards leave the stage empty anyway.
const CHROME_HAND_SLACK: float = 50.0
const CHROME_FLOOR_PAD: float = 4.0
## `minLeft` / `stageW() - maxRight` (combat.js:524-525) — the side margins the
## same clamp keeps chrome inside on the other axis.
const CHROME_EDGE_PAD: float = 6.0

## The damage sources that do not shove the body (drain.js:626). A blow throws
## you; poison does not, and neither does your own burn.
const INDIRECT_SOURCES: Array[String] = ["poison", "burn", "self", "thorns"]

## `tr('ui.combat.*')` — the copy the drain announces with, from `i18n/en/ui.js`.
## Held here rather than typed at each call site so the wording is one edit when
## this port grows a locale table of its own.
const SAY_YOUR_TURN: String = "YOUR TURN"
const SAY_ENEMY_TURN: String = "ENEMY TURN"
const SAY_SHATTER: String = "SHATTER"
const SAY_STAGGERED: String = "STAGGERED"
const SAY_GLASS_HOLDS: String = "THE GLASS HOLDS"
const SAY_GUARD_SHATTERED: String = "GUARD SHATTERED"
const SAY_RESHUFFLE: String = "Reshuffle"
const SAY_PERFECT: String = "PERFECT"
## Tooltip copy (`ui.combat.*`, i18n/en/ui.js:143). Keyword copy is not here —
## it belongs with the vocabulary that produces it, in `RulesText`.
const TIP_FACETS_TITLE: String = "Facets"
const TIP_FACETS_BODY: String = "Every creature is glass. Attacks that draw unblocked blood chip a facet; fill the gauge and the glass [b]shatters[/b] — it loses its next action, is Cracked, and spills Embers into your lantern."
const TIP_STAGGERED_TITLE: String = "Staggered"
const TIP_STAGGERED_BODY: String = "The glass has shattered — this creature loses its next action while it reseams."
const TIP_LANTERN_TITLE: String = "The Lantern"
const TIP_LANTERN_ART_TITLE: String = "Lantern Art — %s"
const TIP_LANTERN_LEAD: String = "<b>%d Embers, once a turn:</b> %s<br><br>"
const TIP_LANTERN_BODY: String = "The lantern holds the <b>Embers</b> spilled by shattered and slain glass. Drag any card onto it to <b>kindle</b> — burn the card away for an ember, once a turn. Curses refuse the fire."
const TIP_LANTERN_SUB: String = "A · use Art"
const TIP_AFFIX_TITLE: String = "%s — an elite's title"
const TIP_BUFF: String = "Buff"
const TIP_DEBUFF: String = "Debuff"

## The palette the drain names inline. Every one of these is a literal in
## `drain.js`; they are the effect layer's own colours, not the theme's.
const GLASS_BLUE: Color = Color(0.8745098, 0.91764706, 1.0)     # #dfeaff
const WARD_BLUE: Color = Color(0.62352943, 0.83137256, 1.0)     # #9fd4ff
const POISON_TAN: Color = Color(0.827451, 0.6313726, 0.3529412) # #d3a15a
const WARM_GOLD: Color = Color(1.0, 0.84705883, 0.627451)       # #ffd8a0
const EMBER_ORANGE: Color = Color(1.0, 0.7019608, 0.3529412)    # #ffb35a
const SPARK_WHITE: Color = Color(1.0, 0.9529412, 0.8392157)     # #fff3d6
const SOUL_VIOLET: Color = Color(0.7882353, 0.6901961, 1.0)     # #c9b0ff
const REVIVE_LILAC: Color = Color(0.9098039, 0.8627451, 1.0)    # #e8dcff
const POWER_LILAC: Color = Color(0.7882353, 0.65882355, 1.0)    # #c9a8ff
const HOLLOW_GREY: Color = Color(0.5686275, 0.627451, 0.6862745) # #91a0af
const HEAL_GREEN: Color = Color(0.56078434, 0.9098039, 0.627451) # #8fe8a0
const BUFF_BLUE: Color = Color(0.62352943, 0.78431374, 1.0)     # #9fc8ff
const WARD_ICON: Texture2D = preload("res://assets/art/ui/ward.png")

## The four signatures that fire on the PLAY rather than on an impact
## (drain.js:495) — they are the card's gesture, not its landing, so they must
## not wait for something to be hit.
const PLAY_TIME_BESPOKE: Array[String] = [
	"ascension", "pyreheart", "emberdance", "limitBreak"]

## `big` (drain.js:540) — the damage at which a blow earns its own ceremony.
const BIG_HIT: int = 16
## `Math.min(1, ev.amount / 24)` — what counts as a full-power blow.
const POWER_SCALE: float = 24.0

## `.art-cast` (drain.js:403, styles.css:1122) — the art's own face rises off the
## hero and goes. A DOM `<img>` appended to `#floaties`, 110px square,
## `object-fit: contain`, at z 57 — one above `#floaties` itself, so the face is
## over the damage numerals.
##
## The WAAPI list, verbatim:
##
##     translate(-50%,-50%) scale(0.4)   opacity 0
##     translate(-50%,-58%) scale(1)     opacity 1   offset 0.3
##     translate(-50%,-70%) scale(1.05)  opacity 0
##     duration 900, easing cubic-bezier(.2,.7,.3,1)
##
## The Y steps are PERCENTAGES OF THE ELEMENT'S OWN HEIGHT, not pixels: -50% is
## the centring, so the travel is 8% and then a further 12% of 110px — 8.8px,
## then 22px in total. Read as pixels it would rise nearly twice as far.
##
## A keyframe list interpolates LINEARLY between offsets with the easing applied
## once to the whole iteration, so `Motion.ease` shapes the clock and
## `Motion.keyframe` reads the three tracks off it.
const CAST_ART: String = "res://assets/art/arts/%s.png"
const CAST_MS: float = 0.9
const CAST_SIZE: float = 110.0
## `img.style.top = hy - 30` — the ghost starts a head above the body.
const CAST_LIFT: float = 30.0
const CAST_EASE: Array[float] = [0.2, 0.7, 0.3, 1.0]
const CAST_AT: Array[float] = [0.0, 0.3, 1.0]
const CAST_SCALE: Array[float] = [0.4, 1.0, 1.05]
const CAST_ALPHA: Array[float] = [0.0, 1.0, 0.0]
const CAST_RISE: Array[float] = [0.0, 0.08, 0.2]
## `filter: drop-shadow(0 0 24px rgba(255, 217, 122, .5))`. Godot has no CSS
## drop-shadow, so the glow is the same texture drawn additively behind and
## spread by the blur radius. It follows the silhouette, which a radial would
## not; what it does not reproduce is a real gaussian's falloff.
const CAST_GLOW: Color = Color(1.0, 0.8509804, 0.47843137, 0.5)
const CAST_BLUR: float = 24.0

## `setTimeout(..., 440)` (drain.js:371) — how long the lantern waits before it
## answers a spill. Just short of the 460ms flight, so the pop is starting as the
## last mote arrives rather than beginning after it.
const EMBER_LAND: float = 0.44

class Plate:
	extends Control
	var art: String = ""
	var is_ledge: bool = false
	var tex: Texture2D
	var where: Vector2 = Vector2(0.5, 0.5)
	## `sl-drift` (styles.css:687) — the diorama breathes sideways. `--amp` is
	## overridden per layer by `battlefield-layout.js`, and the live values are
	## 30px on the backdrop, 10 on the mid and 0 on the ledge, so the floor never
	## slides under the combatants standing on it.
	var amp: float = 0.0
	var period: float = 26.0
	## This plate's own width at its authored zoom, before `min-width: 100%` is
	## applied — and the offset from centred it is hung at. Kept so `fit` can
	## re-derive the box when the stage flexes under it, which is the one thing
	## about a plate that is NOT settled at build time.
	var art_w: float = 0.0
	var zoom: float = 1.0
	var dx: float = 0.0
	var _t: float = 0.0
	var _dx: float = 0.0

	## The box never moves; the PAINT does.
	##
	## Two reasons, and the first is fatal on its own.
	## `gui/common/snap_controls_to_pixels` is true by default, so a Control's
	## rect is rounded to whole pixels before it is drawn. A 30px sweep over 26
	## seconds crosses a pixel boundary roughly twice a second at its fastest and
	## far more slowly at the turns, so the backdrop does not glide — it ticks,
	## holds, and ticks again. That is the stepping. Draw commands take floats
	## and are not snapped (`snap_2d_vertices_to_pixel` is false), so moving the
	## destination rect instead restores the sub-pixel glide.
	##
	## The second reason is that this is also what the benchmark does: `sl-drift`
	## is a `transform: translateX`, which moves the painted image and leaves
	## layout alone. Writing offsets re-sorts the container every frame and,
	## because moving one edge resizes the box, re-derives the `cover` crop from
	## a width that is no longer the one the plate was measured at.
	func set_home(left: float, w: float) -> void:
		offset_left = left
		offset_right = left + w

	## Re-fit to a stage that has flexed under this plate.
	##
	## Every other number a plate carries is a gap from an edge and survives a
	## wider stage untouched. Its WIDTH does not: `min-width: 100%` is measured
	## against the live stage, and the screen is built before it has a size — so a
	## plate sized at the shape's reference falls short the moment the stage
	## stretches. At +12% on pad-landscape that left 40px of bare sky down each
	## side, past the edges of a ledge the actors were standing on.
	func fit(stage_w: float) -> void:
		var w: float = zoom * maxf(stage_w + 2.0 * amp, art_w)
		set_home(-w * 0.5 + dx, w)

	func _process(delta: float) -> void:
		if amp <= 0.0 or period <= 0.0:
			set_process(false)
			return
		_t += delta
		# `infinite alternate`: one leg out, one leg back, and `ease-in-out`
		# applied to each leg rather than to the pair. The curve is symmetric,
		# so the mirrored leg reads from the same solve.
		var u: float = fmod(_t, period * 2.0) / period
		if u > 1.0:
			u = 2.0 - u
		_dx = lerpf(-amp, amp, Motion.ease(Motion.EASE_IN_OUT, u))
		queue_redraw()

	func _draw() -> void:
		if tex == null:
			return
		var t: Vector2 = tex.get_size()
		if t.x <= 0.0 or t.y <= 0.0 or size.x <= 0.0 or size.y <= 0.0:
			return
		# cover: the smallest scale that still fills the box, so the window we
		# read out of the source is the box divided by it.
		var s: float = maxf(size.x / t.x, size.y / t.y)
		var window: Vector2 = Vector2(size.x / s, size.y / s)
		var origin: Vector2 = (t - window) * where
		draw_texture_rect_region(
			tex, Rect2(Vector2(_dx, 0.0), size), Rect2(origin, window))


var game: GlassvowGame
var seq: EventSequencer = EventSequencer.new()

var _rules: CombatRules
var _enemy_views: Array[EnemyView] = []
var _hand: HandView
var _hud: HudBar
## The targeting arc, drawn only while a card that targets an enemy is aimed.
var _aim: AimArc
## The region above the ground line, and the only parent an actor ever has. Its
## bottom IS the ground line, so an actor placed at bottom 0 stands on it.
var _battlefield: Control
## The player, as an actor rather than a panel. `char-meta` types `duskblade` as
## tier `hero`, which is how EnemyView knows to leave off the intent chip, the
## name line and the facet gauge without being told.
var _hero: EnemyView
var _kindle_toggle: Button
## The three scenery plates, kept so a flexing stage can re-fit them.
var _plates: Array[Plate] = []
var _encounter_text: String = ""
var _overlay: ColorRect
var _overlay_title: Label
var _overlay_body: Label
var _overlay_button: Button
var _inspector: Control
var _inspector_pane: PanelContainer
var _inspector_title: Label
var _inspector_subtitle: Label
var _inspector_rows: VBoxContainer
var _vignette: ColorRect
var _vignette_mat: ShaderMaterial
var _sky: SkyField
var _cast: TextureRect
var _cast_glow: TextureRect
var _cast_home: Vector2 = Vector2.ZERO
var _stage_dim: ColorRect
var _stage_dim_mat: ShaderMaterial
var _lantern: ColorRect
var _lantern_mat: ShaderMaterial
## Once the lantern is out it stays out: the HP pool must not take the light back
## while the defeat beat is still being held.
var _snuffed: bool = false
## The drain has no node of its own — it rides the grain's material, and
## GRAIN_SHADER says why.
var _worldstop_tween: Tween
var _worldstop_from: float = 0.0
var _worldstop_to: float = 0.0
var _worldstop_at: float = 0.0
var _grain: ColorRect
var _grain_mat: ShaderMaterial
var _atmos_t: float = 0.0
## Where the pointer last rested while a card was armed, so the lantern can lean
## toward it. Separate from `_aim_hover`, which is a foe or nothing: the light
## follows the pointer across empty stage too.
var _aim_at: Vector2 = Vector2.ZERO
var _has_aim_at: bool = false
## `pileVisualOverride` (drain.js:192) — what a pile is SHOWING while a wave is
## in the air, as against what the engine says it holds. Empty means the engine.
var _pile_override: Dictionary[StringName, int] = {}
var _over_emitted: bool = false
## `choreoDone` — whether the card currently resolving has already been swung
## for. Starts spent, so nothing lunges before a card is ever played.
var _hero_swung: bool = true
## Everything the shake moves: `#shake` wraps the screen, the lantern and the
## chrome, but NOT the effect canvas — which is why sparks hang still while the
## world jolts under them.
var _shake_host: Control
var _vfx: VfxLayer
var _floaters: Floaters
## `sfx` (audio.js). Owned here rather than reached for globally: the fight is
## the only screen that has sound yet, and `main.gd` is the sole composition
## root, so a second owner would have to be handed one rather than find one.
var _sfx: SfxBus
## `#tooltip` at z 70 — above the hand, the chrome and the floaters, because
## everything it explains is underneath it.
var _tips: TooltipLayer
## `vfxSource.archetype` — which blow language the action now resolving speaks.
## Set by `play` from the card's own `vfx` field and by `enemyAct` from the
## body's kind, then read by every hit until the next action replaces it.
var _archetype: String = "slash"
## `vfxSource.cardId` — WHICH card is acting, as against what family its blows
## belong to. Only this can select a signature effect: `BESPOKE_VFX` is keyed on
## the card, `archetypeHit` on its `vfx` field, and both fire on the same blow.
var _vfx_card_id: String = ""
## `bespokeFired` — a signature is the moment of the PLAY, not of each hit, so a
## card that strikes three times still gets exactly one.
var _bespoke_fired: bool = false
## `hitSeq` — how many numbers this action has already thrown, so a multi-hit
## card fans its damage across three columns instead of stacking it in one.
var _hit_seq: int = 0
## `emberFrom` — where the last fire spilled, so the embers it feeds the lantern
## start at the body that gave them rather than at the hero.
var _ember_from: Vector2 = Vector2.ZERO
var _has_ember_from: bool = false
## `targetIdx` — what the card about to resolve was aimed at, so `play` can
## throw it there. Null for an untargeted card and for anything the engine
## started on its own.
var _play_target: Variant = null
## `target-hover` — the foe under the pointer while a card is aimed, -1 for
## none. Held here because the previews and the arc both read it.
var _aim_hover: int = -1
## `S.selectedCardUid` / `S.targeting` — the keyboard's cursor through the fan,
## and whether the card it is on has been ARMED and is waiting for a target.
var _selected_uid: int = -1
var _targeting: bool = false


## Fully constructed at new() — no tree dependency, so headless tests can
## drive it before (or without) entering the tree.
##
## The shape and act are injected by the composition root, which is the only
## place that knows what window this is (`SKILL.md:23-24` — no manager
## singletons, and `application/main.tscn` is the one composition root). They
## default to the identity composition so every existing caller, and every
## headless test, gets exactly the screen it got before.
func _init(game_ref: GlassvowGame, stage_shape: StringName = StageShape.IDENTITY,
		stage_act: int = 0) -> void:
	game = game_ref
	_rules = game.rules
	shape = stage_shape if StageShape.REFERENCES.has(stage_shape) else StageShape.IDENTITY
	act = stage_act
	_authored = LayoutBook.resolve(&"battlefield", shape, act)
	seq.handler = _handle_event
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = GlassStyle.theme()
	_build_ui()
	seq.busy_changed.connect(_on_busy_changed)


## Swap the authored battlefield while keeping the encounter, actors and fracture
## worlds alive. Main calls this when a live window crosses a shape boundary.
func set_shape(stage_shape: StringName) -> void:
	var next: StringName = stage_shape if StageShape.REFERENCES.has(stage_shape) \
		else StageShape.IDENTITY
	if next == shape:
		return
	shape = next
	_authored = LayoutBook.resolve(&"battlefield", shape, act)
	_placed = {}
	_placed_at = Vector2i.ZERO
	_build_hud()
	_apply_stage_layout()
	# `content_scale_size` and Control anchors settle on the next layout pass.
	# Repeating the same idempotent placement then spends the new live flex.
	call_deferred(&"_apply_stage_layout")


## The layout for the stage as it is right now, with the flex already spent.
##
## Read through here rather than off `_authored`, because `size` is the live
## stage and the foes are bound to its right edge — a window that gained 60px of
## flex must move them 60px, and nothing else. Cached against the size it was
## computed for, so the common case is a comparison rather than a deep merge.
##
## Before the screen has a size — during `_init`, and in headless tests that
## never lay out — the reference size stands in. That is not a fallback so much
## as the no-shrink invariant restated: a stage never goes below its reference,
## so clamping up to it is the only honest reading of a zero.
func _layout() -> Dictionary:
	var ref: Vector2i = StageShape.REFERENCES.get(shape, StageShape.REFERENCES[StageShape.IDENTITY])
	var stage: Vector2i = Vector2i(maxi(ref.x, roundi(size.x)), maxi(ref.y, roundi(size.y)))
	if stage != _placed_at or _placed.is_empty():
		_placed_at = stage
		_placed = LayoutBook.place(&"battlefield", _authored, shape, stage)
	return _placed


## The ground line, in stage px up from the bottom. The battlefield ends here
## and every actor stands on it: an actor drawn at bottom 0 has its feet here.
## Foes and the hero are the same animal, which is the contract `enemy_view.gd`
## was already built against.
func _ground_y() -> float:
	return LayoutBook.num(_layout().get("groundY"), 232.0)


## Where the hero's centre stands. His BOX is not from here: char-meta types
## `duskblade` as tier `hero` (`tierSizes.hero` = 285) and EnemyView sizes itself
## off that, the same way it sizes a foe.
func _hero_x() -> float:
	return LayoutBook.num(_layout().get("hero", {}).get("x"), 200.0)


## The live stage width in stage px. Not the shape's reference width: inside the
## flex cap those differ, and the difference is exactly the room the composition
## was given to spread into.
## How far the hand box hangs past the bottom edge — `UIC.hand.bottom`, which
## the book authors NEGATIVE (the box sits below the stage line) and which this
## screen wants as a positive overhang.
func _hand_overhang() -> float:
	var hand: Dictionary = LayoutBook.resolve(&"chrome", shape, act).get("hand", {})
	return -LayoutBook.num(hand.get("bottom"), -12.0)


## The hand box's height ABOVE the stage line — the book states the whole box,
## overhang included, so the overhang comes back off here.
func _hand_height() -> float:
	var hand: Dictionary = LayoutBook.resolve(&"chrome", shape, act).get("hand", {})
	return LayoutBook.num(hand.get("h"), HAND_H + 12.0) - _hand_overhang()


## How big an actor draws its name, ward, HP rail and facets on this shape.
func _actor_scale() -> float:
	var actor: Dictionary = LayoutBook.resolve(&"chrome", shape, act).get("actor", {})
	return LayoutBook.num(actor.get("scale"), 1.0)


## What a card is worth on this shape: the benchmark's `--cw`, and the gap
## between a resting card's bottom edge and the hand box's floor.
func _card_metrics() -> Vector2:
	var card: Dictionary = LayoutBook.resolve(&"chrome", shape, act).get("card", {})
	return Vector2(LayoutBook.num(card.get("w"), CardView.CARD_W),
		LayoutBook.num(card.get("inset"), HandView.CARD_INSET))


## The stage grew or shrank inside the flex band. Re-read the placed book: foe
## seats are right-bound and plate widths and the hand fan use the live stage.
func _on_stage_resized() -> void:
	_apply_stage_layout()


func _stage_w() -> float:
	var ref: Vector2i = StageShape.REFERENCES.get(shape, StageShape.REFERENCES[StageShape.IDENTITY])
	return maxf(float(ref.x), size.x)


func _apply_stage_layout() -> void:
	if _shake_host == null:
		return
	if _battlefield != null:
		_battlefield.offset_bottom = -_ground_y()
	for plate: Plate in _plates:
		if is_instance_valid(plate):
			_layout_plate(plate)
	_layout_kindle()
	_layout_hand()
	_layout_actors()
	_fit_inspector()


func _layout_hand() -> void:
	if _hand == null:
		return
	var card: Vector2 = _card_metrics()
	var stage_width: float = _stage_w()
	_hand.stage_w = stage_width
	_hand.offset_left = -HandView.zone_width(5, stage_width, card.x) * 0.5
	_hand.offset_right = HandView.zone_width(5, stage_width, card.x) * 0.5
	_hand.offset_top = -_hand_height()
	_hand.offset_bottom = _hand_overhang()
	_hand.set_card_metrics(card.x, card.y)


func _layout_kindle() -> void:
	if _kindle_toggle == null:
		return
	var kindle: Dictionary = LayoutBook.resolve(&"chrome", shape, act).get("kindle", {})
	_kindle_toggle.offset_left = LayoutBook.num(kindle.get("left"), 16.0)
	_kindle_toggle.offset_right = _kindle_toggle.offset_left + KINDLE_BOX.x
	_kindle_toggle.offset_top = LayoutBook.num(kindle.get("top"), 66.0)
	_kindle_toggle.offset_bottom = _kindle_toggle.offset_top + KINDLE_BOX.y
	var k: float = LayoutBook.num(kindle.get("w"), KINDLE_BOX.x) / KINDLE_BOX.x
	_kindle_toggle.scale = Vector2.ONE * k


# ---------------------------------------------------------------- build

func _build_ui() -> void:
	# `#shake` — the world wrapper the screen shake translates. Everything the
	# fight happens in goes inside it; the effect canvas and the floaters do not,
	# because `#vfx` and `#floaties` are its SIBLINGS in the benchmark and that
	# is why a spark stays where it was thrown while the stage jolts under it.
	_shake_host = Control.new()
	_shake_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shake_host.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_shake_host)

	_build_stage()

	# Between the two, and that ORDER is the feature: the darkness covers the
	# plates it is added after and nothing added later.
	_build_stage_dim()

	# `.battlefield` — inset 0 with `bottom: var(--ground-y)`. Actors are its only
	# children and are placed by their FEET, so the container's bottom edge is
	# the ground line and nothing has to convert coordinates to say so.
	_battlefield = Control.new()
	_battlefield.set_anchors_preset(Control.PRESET_FULL_RECT)
	_battlefield.offset_bottom = -_ground_y()
	_battlefield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shake_host.add_child(_battlefield)

	# `#lantern` carries z 21 — over the actors, under the hand (22) and the
	# chrome (24). It is empty for the whole fight and only paints on defeat.
	_build_lantern()

	# The whole chrome layer, in one widget, measured against the same
	# 1180x820 the stage above is. `plate = false` because the ward chip and HP
	# rail belong to the actor they describe — see docs/hud-handoff.md §2.
	_build_hud()

	_hand = HandView.new()
	# `.hand-zone` — centred on the stage, 260 tall, hanging 12px past the
	# bottom edge. The WIDTH is not a constant: the benchmark sizes the box to
	# hug the fan, so HandView re-edges itself on every relayout and this is
	# only the resting five-card figure it starts at.
	_hand.anchor_left = 0.5
	_hand.anchor_right = 0.5
	_hand.anchor_top = 1.0
	_hand.anchor_bottom = 1.0
	# Against the LIVE stage, which is what `hand_view.gd:445` measures the fan
	# gap against. These two agreed only because the stage was frozen at one
	# size; on any other shape the resting box and the fan inside it would have
	# been sized off different widths.
	# Before the box is measured, because the resting width is a function of the
	# card's own width and a phone's card is a third narrower than a pad's.
	var card: Vector2 = _card_metrics()
	_hand.card_w = card.x
	_hand.card_inset = card.y
	_hand.stage_w = _stage_w()
	_hand.offset_left = -HandView.zone_width(5, _stage_w(), card.x) * 0.5
	_hand.offset_right = HandView.zone_width(5, _stage_w(), card.x) * 0.5
	_hand.offset_top = -_hand_height()
	_hand.offset_bottom = _hand_overhang()
	_hand.card_tapped.connect(_on_card_tapped)
	_hand.card_drag_moved.connect(_on_card_drag_moved)
	_hand.card_drag_released.connect(_on_card_drag_released)
	_hand.card_hover_changed.connect(_on_card_hover_changed)
	_hand.card_drag_armed.connect(_on_card_drag_armed)
	_hand.card_drag_refused.connect(_on_card_drag_refused)
	# The fan is the one part of the composition whose spread is a function of
	# the LIVE stage width rather than the shape's reference — inside the flex
	# cap those differ by up to 12%, and that difference is exactly the room the
	# hand was given to open into.
	resized.connect(_on_stage_resized)
	_shake_host.add_child(_hand)

	# `#vignette` is a SIBLING of `#shake` carrying z 4, and `#shake` carries no
	# z at all — so the darkening falls over the stage, the actors and the chrome
	# alike, and only the arc, the sparks and the tips are above it.
	_build_vignette()

	# Above the hand: the arc launches 80px over the card it comes from, so it
	# clears the fan on its own, but the reticle must never end up behind a
	# neighbouring card when aiming across the hand.
	_aim = AimArc.new()
	add_child(_aim)

	# `#vfx` then `#floaties`, both siblings of `#shake` and both above `#aim`:
	# a damage numeral is never hidden by the body it came off, and a spark is
	# never hidden by the HUD.
	_vfx = VfxLayer.new(_shake_host)
	add_child(_vfx)
	_floaters = Floaters.new()
	add_child(_floaters)

	# `.art-cast` carries z 57 against `#floaties`' 55 — the art's face is over
	# the damage numerals, so it is added after them.
	_cast_glow = TextureRect.new()
	_cast_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cast_glow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cast_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cast_glow.modulate = CAST_GLOW
	var glow_mat: CanvasItemMaterial = CanvasItemMaterial.new()
	glow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_cast_glow.material = glow_mat
	_cast_glow.visible = false
	add_child(_cast_glow)   # behind the face it belongs to
	_cast = TextureRect.new()
	_cast.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cast.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED  # object-fit: contain
	_cast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cast.visible = false
	add_child(_cast)

	_sfx = SfxBus.new()
	add_child(_sfx)

	_tips = TooltipLayer.new()
	_tips.source = _tip_at
	add_child(_tips)

	# Kindle is this port's own control: the benchmark's chrome has no seat for
	# it, and HudBar reserves none. Still parked under the strip, because where
	# it belongs is a design question nobody has answered
	# (docs/assembly-integration-plan.md D4) — but the four numbers that put it
	# there are the book's now. They were literals, and 116 of a phone's 390px is
	# a third of the stage spent on a debug toggle.
	_kindle_toggle = Button.new()
	_kindle_toggle.text = "Kindle: off"
	_kindle_toggle.toggle_mode = true
	_kindle_toggle.anchor_top = 0.0
	_kindle_toggle.anchor_bottom = 0.0
	# Drawn at KINDLE_BOX and scaled to the authored one, the same bargain
	# `HudBar._place_widget` strikes: the chip's padding, corner radius and font
	# come from one styled Button that knows nothing about shapes, and the shape
	# is spent on the outside of it. At pad-landscape the scale is exactly 1.
	_kindle_toggle.pivot_offset = Vector2.ZERO
	# Uniform, and taken from `w` alone: a Button's height is its stylebox's
	# content margins plus its font, and that minimum wins over any offset — the
	# chip is 43 tall however hard 32 is asked for. So the book authors what can
	# be authored and the chip keeps its own proportions.
	_layout_kindle()
	GlassStyle.style_button(_kindle_toggle, GlassStyle.EMBER)
	_kindle_toggle.toggled.connect(_on_kindle_toggled)
	_kindle_toggle.visible = false
	_shake_host.add_child(_kindle_toggle)

	_overlay = ColorRect.new()
	_overlay.color = Color(0.01, 0.015, 0.03, 0.8)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	add_child(_overlay)
	var overlay_center: CenterContainer = CenterContainer.new()
	overlay_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(overlay_center)
	var overlay_pane: PanelContainer = PanelContainer.new()
	overlay_pane.add_theme_stylebox_override("panel", GlassStyle.pane(GlassStyle.GLASS, 0.95))
	overlay_center.add_child(overlay_pane)
	var overlay_box: VBoxContainer = VBoxContainer.new()
	overlay_box.add_theme_constant_override("separation", 16)
	overlay_box.custom_minimum_size = Vector2(360, 0)
	overlay_pane.add_child(overlay_box)
	_overlay_title = _label("")
	_overlay_title.add_theme_font_size_override("font_size", 34)
	_overlay_title.add_theme_color_override("font_color", Color(0.82, 0.9, 1.0))
	overlay_box.add_child(_overlay_title)
	_overlay_body = _label("")
	_overlay_body.add_theme_color_override("font_color", GlassStyle.TEXT_DIM)
	overlay_box.add_child(_overlay_body)
	_overlay_button = Button.new()
	_overlay_button.custom_minimum_size = Vector2(220, 48)
	GlassStyle.style_button(_overlay_button, GlassStyle.EMBER)
	_overlay_button.pressed.connect(func() -> void: result_continue.emit())
	overlay_box.add_child(_overlay_button)

	_build_inspector()

	# `#transit`'s combat leaves live on main's TransitionLayer now — above
	# this whole screen — so nothing to build here.

	# Last, because `#grain` carries z 75 — above the tooltip and above the
	# overlay — and because it reads the screen it is blended onto.
	_build_grain()


## Chrome has no encounter state. Rebuilding this one presentation node is the
## smallest safe way to re-resolve all ten authored seats and the top bar.
func _build_hud() -> void:
	if _shake_host == null:
		return
	var sibling: int = -1
	if _hud != null:
		sibling = _hud.get_index()
		_shake_host.remove_child(_hud)
		_hud.queue_free()
	_hud = HudBar.new(true, true, false, shape)
	_hud.end_turn_pressed.connect(_on_end_turn_pressed)
	_hud.lantern_pressed.connect(_on_art_pressed)
	_hud.menu_pressed.connect(func() -> void: menu_requested.emit())
	_hud.potion_pressed.connect(func(slot: int) -> void: potion_requested.emit(slot))
	_hud.deck_pressed.connect(_show_deck)
	_hud.pile_pressed.connect(_show_pile)
	_shake_host.add_child(_hud)
	if sibling >= 0:
		_shake_host.move_child(_hud, sibling)
	_push_hud()
	var locked: bool = seq.is_busy() or game.cb == null or game.cb.over
	_hud.set_locked(locked)


func _build_inspector() -> void:
	_inspector = Control.new()
	_inspector.set_anchors_preset(Control.PRESET_FULL_RECT)
	_inspector.mouse_filter = Control.MOUSE_FILTER_STOP
	_inspector.visible = false
	add_child(_inspector)

	var shade: ColorRect = ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.015, 0.03, 0.88)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inspector.add_child(shade)
	var scrim: Button = Button.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.flat = true
	scrim.focus_mode = Control.FOCUS_NONE
	scrim.pressed.connect(_close_inspector)
	_inspector.add_child(scrim)

	_inspector_pane = PanelContainer.new()
	_inspector_pane.anchor_left = 0.5
	_inspector_pane.anchor_right = 0.5
	_inspector_pane.anchor_top = 0.5
	_inspector_pane.anchor_bottom = 0.5
	_inspector_pane.add_theme_stylebox_override(
		"panel", GlassStyle.pane(GlassStyle.GLASS, 0.98))
	_inspector.add_child(_inspector_pane)

	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 18)
	_inspector_pane.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	_inspector_title = _label("")
	_inspector_title.add_theme_font_size_override("font_size", 28)
	_inspector_title.add_theme_color_override("font_color", Color(0.82, 0.9, 1.0))
	column.add_child(_inspector_title)
	_inspector_subtitle = _label("")
	_inspector_subtitle.add_theme_color_override("font_color", GlassStyle.TEXT_DIM)
	column.add_child(_inspector_subtitle)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_inspector_rows = VBoxContainer.new()
	_inspector_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inspector_rows.add_theme_constant_override("separation", 8)
	scroll.add_child(_inspector_rows)

	var close: Button = Button.new()
	close.text = "CLOSE"
	close.custom_minimum_size = Vector2(160, 44)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	GlassStyle.style_button(close, GlassStyle.EMBER)
	close.pressed.connect(_close_inspector)
	column.add_child(close)
	_fit_inspector()


func _fit_inspector() -> void:
	if _inspector_pane == null:
		return
	var ref: Vector2i = StageShape.REFERENCES.get(
		shape, StageShape.REFERENCES[StageShape.IDENTITY])
	var stage: Vector2 = Vector2(maxf(size.x, float(ref.x)), maxf(size.y, float(ref.y)))
	var box: Vector2 = Vector2(minf(520.0, stage.x - 32.0),
		minf(540.0, stage.y - 48.0))
	_inspector_pane.offset_left = -box.x * 0.5
	_inspector_pane.offset_right = box.x * 0.5
	_inspector_pane.offset_top = -box.y * 0.5
	_inspector_pane.offset_bottom = box.y * 0.5


func _show_deck() -> void:
	_show_inspector("DECK", game.run.player.deck)


func _show_pile(which: StringName) -> void:
	match which:
		&"draw":
			_show_inspector("DRAW PILE", game.cb.draw)
		&"discard":
			_show_inspector("DISCARD PILE", game.cb.discard)
		&"ashes":
			_show_inspector("ASHES", game.cb.exhaust)


func _show_inspector(title: String, cards: Array[CardInst]) -> void:
	for child: Node in _inspector_rows.get_children():
		_inspector_rows.remove_child(child)
		child.queue_free()
	_inspector_title.text = title
	_inspector_subtitle.text = "%d card%s" % [cards.size(), "" if cards.size() == 1 else "s"]
	var counts: Dictionary[String, int] = {}
	var order: PackedStringArray = []
	for card: CardInst in cards:
		var key: String = String(card.id) + ("+" if card.up else "")
		if not counts.has(key):
			counts[key] = 0
			order.append(key)
		counts[key] += 1
	for key: String in order:
		var id: String = key.trim_suffix("+")
		var definition: Dictionary = game.content.cards.get(id, {})
		var row: HBoxContainer = HBoxContainer.new()
		var name: Label = _label(str(definition.get("name", id)) + ("+" if key.ends_with("+") else ""))
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		var count: Label = _label("×%d" % counts[key])
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.add_theme_color_override("font_color", GlassStyle.TEXT_DIM)
		row.add_child(count)
		_inspector_rows.add_child(row)
	if cards.is_empty():
		var empty: Label = _label("No cards")
		empty.add_theme_color_override("font_color", GlassStyle.TEXT_DIM)
		_inspector_rows.add_child(empty)
	_inspector.visible = true


func _close_inspector() -> void:
	_inspector.visible = false


## `radial-gradient(ellipse at 50% 45%, transparent 55%, edge 100%)` and the
## `inset 0 0 Npx` red glow composited over it. One shader because they are one
## element there, and because the red has to sit ON the darkening rather than
## be averaged into it — source-over, not a mix.
const VIGNETTE_SHADER: String = """
shader_type canvas_item;

uniform vec4 edge : source_color = vec4(0.016, 0.02, 0.047, 0.55);
uniform vec4 low_tint : source_color = vec4(1.0, 0.157, 0.157, 1.0);
uniform float low_reach = 0.0;   // px the inset glow reaches in from the frame
uniform float low_alpha = 0.0;
uniform vec2 stage_px = vec2(1180.0, 820.0);

void fragment() {
	// The gradient's default extent is farthest-corner, so the radii are the
	// distances from (50%, 45%) to the far edge in each axis: 0.5 and 0.55.
	float r = length((UV - vec2(0.5, 0.45)) / vec2(0.5, 0.55));
	float dark = smoothstep(0.55, 1.0, r) * edge.a;
	vec2 px = UV * stage_px;
	float d = min(min(px.x, stage_px.x - px.x), min(px.y, stage_px.y - px.y));
	float glow = low_alpha * (1.0 - smoothstep(0.0, max(0.001, low_reach), d));
	float a = glow + dark * (1.0 - glow);
	vec3 c = (low_tint.rgb * glow + edge.rgb * dark * (1.0 - glow)) / max(0.001, a);
	COLOR = vec4(c, a);
}
"""

## `radial-gradient(circle var(--lr) at var(--lx) var(--ly), transparent 42%,
## rgba(3,4,10,var(--la)) 100%)`. A CSS radial ramps LINEARLY between its stops
## and holds the last colour past 100%, so the alpha is a clamped line rather
## than a smoothstep — a soft edge here would put a visible halo on the floor
## where the benchmark has a straight fall-off.
##
## Driven in px, not UV, because the circle must stay round on any window: the
## radius is a distance on the stage, and dividing by a non-square UV would make
## it an ellipse that changes shape as the window does.
const STAGE_DIM_SHADER: String = """
shader_type canvas_item;

uniform vec4 dark : source_color = vec4(0.012, 0.016, 0.039, 1.0);
uniform vec2 centre_px = vec2(590.0, 400.0);
uniform vec2 stage_px = vec2(1180.0, 820.0);
uniform float radius_px = 1500.0;
uniform float hole = 0.42;
uniform float la = 0.0;

void fragment() {
	float d = distance(UV * stage_px, centre_px) / max(1.0, radius_px);
	float t = clamp((d - hole) / max(0.001, 1.0 - hole), 0.0, 1.0);
	COLOR = vec4(dark.rgb, t * la);
}
"""

## `mix-blend-mode: overlay` at 5%, against a noise field that jumps rather than
## slides. `CanvasItemMaterial` has no overlay mode, so the blend is done here
## against the screen this layer is the last thing drawn over.
##
## The world drain rides in the SAME shader, and that is not tidiness — it is the
## only arrangement that works. **Godot takes one backbuffer copy per frame**,
## positioned before the FIRST canvas item that declares `hint_screen_texture`,
## and every such item samples that one copy. This layer is drawn last, reads it,
## and writes back opaque across the whole screen — so anything drawn between the
## copy and here is erased without a warning. A second screen-reading layer
## beneath this one is silently a no-op; measured 2026-07-26 by holding an opaque
## blue screen-reader inside `#shake` and watching it vanish the moment the grain
## was visible, and reappear the moment it was hidden.
##
## The cost of folding them: the drain reaches the sparks, the floaters and the
## arc, which `body.worldstop #screen` leaves lit — they are siblings of `#shake`
## there, not children. It does not show, because the world-stop beat runs BEFORE
## the rite throws anything: `#vfx` and `#floaties` are empty for its whole 820ms.
const GRAIN_SHADER: String = """
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec2 jitter = vec2(0.0);
uniform float amount : hint_range(0.0, 1.0) = 0.05;
// `filter: saturate(0.07) brightness(0.85)`, spelled out. CSS `saturate(s)` is
// a lerp from luminance toward the original at `s` — the full feColorMatrix
// reduces to exactly that — and `brightness(b)` is a straight multiply, both in
// sRGB, which is the space the framebuffer is already in.
uniform float drain : hint_range(0.0, 1.0) = 0.0;
uniform float drain_sat = 0.07;
uniform float drain_bright = 0.85;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec3 base = texture(screen_tex, SCREEN_UV).rgb;
	// The drain first, because there it is a filter on the world UNDER the
	// grain: the noise blends over an already-colourless frame.
	vec3 lum = vec3(dot(base, vec3(0.213, 0.715, 0.072)));
	base = mix(base, mix(lum, base, drain_sat) * drain_bright, drain);
	// `feTurbulence baseFrequency 0.85` is grain at roughly the pixel, so one
	// hash per pixel stands in for the tile. Whole-pixel jitter, so a jump
	// re-rolls the field instead of resampling it blurrier.
	vec3 g = vec3(hash(floor(FRAGCOORD.xy) + jitter));
	vec3 over = mix(2.0 * base * g,
		1.0 - 2.0 * (1.0 - base) * (1.0 - g), step(vec3(0.5), base));
	COLOR = vec4(mix(base, over, amount), 1.0);
}
"""


# ---------------------------------------------------------------- the stage

## The painted ground the fight happens on: three plates, a glow band pooled at
## the ground line, the lit lip above it, depth mist, and two slow breaths.
## Ported from `combat.js:215-223` and the `.sl` / `.stage-*` rules; the plate
## geometry is `BF.base` merged with `shapes['pad-landscape']` at act 0.
##
## This replaces a procedural indigo gradient, an ember radial and a vignette —
## a look the M5d craft pass invented rather than ported. The art it needed had
## been sitting in `assets/art/stage/` unreferenced the whole time.
##
## Deferred on purpose, each cheap to add later and none of them load-bearing
## for the layout: the plates' idle parallax drift (`--amp`), and
## `.cast-shadow-layer` — EnemyView already projects its own shadow, so a shared
## layer only earns its place once shadows interact. `.stage-dim` is no longer
## among them: it is built by `_build_stage_dim`, immediately after this returns.
func _build_stage() -> void:
	# What is behind the plates. `body { background: #000 }` is the page, not the
	# stage: the act's plate art has a transparent sky and `#bg3d` is what shows
	# through it. Black there is the single biggest reason a still frame of this
	# fight read as flat next to the same frame on the benchmark.
	_sky = SkyField.new(act)
	_shake_host.add_child(_sky)

	# Draw order is the benchmark's paint order: the plates and the breath sit
	# at z 0, the mist at 2, the ledge band at 3.
	#
	# Every figure each plate needs — height, lift, offset, zoom, opacity, crop
	# focus and drift amplitude — now comes out of the book for this shape and
	# act. They used to be nine literals per call, measured off the running
	# benchmark's own `.sl-*` elements because the resolved values are what the
	# DOM ends up with. That measurement still stands: it agreed with
	# `battlefield-layout.js` to the number, which is why swapping the source
	# changes nothing on screen and everything about what happens on a phone.
	_plate("backdrop")
	_plate("mid")
	_build_mist()
	_plate("ledge", true)

	# NOT BUILT, and the benchmark's own stylesheet says why:
	#
	#   /* act-themed ground glow off — stage-ledge + stage-breath both tint
	#      --ledge (act1 = green) */
	#   .stage-ledge, .stage-breath { opacity: 0; animation: none; }
	#
	# The 120px ledge glow, its 1.5px lit lip and the two breathing blobs are all
	# defined and then switched OFF at the visual standard, because every one of
	# them tints `--ledge` and act 1 resolves that green. They were ported before
	# that line was read, and the green band across the floor that followed was
	# never a tuning problem — it was two layers that are not meant to exist.
	# Putting them back is a deliberate departure, not a fix.


## `.combat-screen::after` (styles.css:734) — the depth mist. 300px at the stage
## bottom, `transparent → rgba(5,7,14,.55) 75%`, at z 2: BETWEEN the mid plate
## and the ledge, which is the whole trick. It sinks the far plates into haze
## while the floor the fight stands on stays clear, and without it the backdrop
## and the ground read at the same distance.
##
## This was in `_build_stage`'s docstring as though it were built. It was not.
func _build_mist() -> void:
	var grad: Gradient = Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.75, 1.0])
	grad.colors = PackedColorArray([
		Color(MIST.r, MIST.g, MIST.b, 0.0), MIST, MIST])
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(0.0, 1.0)
	tex.width = 8   # a vertical ramp needs no horizontal resolution
	tex.height = 256
	var rect: TextureRect = TextureRect.new()
	rect.texture = tex
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	rect.offset_top = -MIST_H
	rect.offset_bottom = 0.0
	_shake_host.add_child(rect)


## `#vignette` (styles.css:66) and `body.low-hp` (styles.css:69), which are one
## element in the benchmark and so are one here.
##
## The vignette is always on: `radial-gradient(ellipse at 50% 45%, transparent
## 55%, rgba(4,5,12,.55) 100%)`. Nothing about the fight turns it on or off, and
## its absence is why a still of this screen read as evenly lit to the corners
## where the benchmark's falls away.
##
## The heartbeat is the other half and it is the only place the screen itself
## tells you that you are dying: at 30% HP or less an inset red glow breathes in
## from the frame, 120px at 12% to 180px at 34%, over 1.6s.
func _build_vignette() -> void:
	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.color = Color.WHITE   # the shader writes every channel
	_vignette_mat = ShaderMaterial.new()
	var sh: Shader = Shader.new()
	sh.code = VIGNETTE_SHADER
	_vignette_mat.shader = sh
	_vignette_mat.set_shader_parameter("edge", VIGNETTE_EDGE)
	_vignette_mat.set_shader_parameter("low_tint", LOW_HP_TINT)
	_vignette.material = _vignette_mat
	_vignette.visible = DIM_SCREEN
	add_child(_vignette)


## `.stage-dim` — the HP lantern's pool, over the plates and under everything
## that matters. Built empty; `_update_stage_dim` gives it its light each frame.
func _build_stage_dim() -> void:
	_stage_dim = ColorRect.new()
	_stage_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage_dim.color = Color.WHITE   # the shader writes every channel
	_stage_dim_mat = ShaderMaterial.new()
	var sh: Shader = Shader.new()
	sh.code = STAGE_DIM_SHADER
	_stage_dim_mat.shader = sh
	_stage_dim_mat.set_shader_parameter("dark", DIM_DARK)
	_stage_dim_mat.set_shader_parameter("hole", DIM_HOLE)
	_stage_dim.material = _stage_dim_mat
	_stage_dim.visible = DIM_SCREEN
	_shake_host.add_child(_stage_dim)


## `#lantern` — the full-screen twin of `.stage-dim`, sharing its shader because
## the stylesheet gives them the same gradient verbatim. Invisible until defeat.
func _build_lantern() -> void:
	_lantern = ColorRect.new()
	_lantern.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lantern.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lantern.color = Color.WHITE
	_lantern.visible = false
	_lantern_mat = ShaderMaterial.new()
	var sh: Shader = Shader.new()
	sh.code = STAGE_DIM_SHADER
	_lantern_mat.shader = sh
	_lantern_mat.set_shader_parameter("dark", DIM_DARK)
	_lantern_mat.set_shader_parameter("hole", DIM_HOLE)
	_lantern_mat.set_shader_parameter("la", 0.0)
	_lantern.material = _lantern_mat
	_shake_host.add_child(_lantern)


## `#grain` (styles.css:74) — z 75, over everything including the tooltip.
## Opacity .05, `mix-blend-mode: overlay`, and a 240px noise tile that JUMPS
## eight times a second (`grain 0.9s steps(1)`) rather than sliding.
##
## Overlay is not one of `CanvasItemMaterial`'s blend modes, so it is done in the
## shader against the screen — which is also the only way to get it, and costs
## one screen read on a layer that is already the last thing drawn.
##
## Cheap to dismiss and the single most pervasive difference in a still frame:
## every surface in the benchmark has this on it.
func _build_grain() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_grain = ColorRect.new()
	_grain.set_anchors_preset(Control.PRESET_FULL_RECT)
	_grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grain.color = Color.WHITE
	_grain_mat = ShaderMaterial.new()
	var sh: Shader = Shader.new()
	sh.code = GRAIN_SHADER
	_grain_mat.shader = sh
	_grain_mat.set_shader_parameter("amount", GRAIN_AMOUNT)
	_grain_mat.set_shader_parameter("drain_sat", WORLDSTOP_SAT)
	_grain_mat.set_shader_parameter("drain_bright", WORLDSTOP_BRIGHT)
	_grain_mat.set_shader_parameter("drain", 0.0)
	_grain.material = _grain_mat
	add_child(_grain)


## One painted plate. `h` and `y` are stage px, `y` being the plate's bottom
## above the stage bottom — except the ledge, which hangs off the ground line
## instead (`combat.js:384`).
##
## The box is `h` tall by at least the stage's width (`min-width: 100%`), scaled
## by `zoom`, and CENTRED BY ITS SCALED WIDTH on the stage's centre plus `dx`.
## That last part was got wrong first time from reading the CSS transform order,
## and then measured off the running build: the mid plate lands at x 394 with a
## 600-wide box, which is 690 minus half of 600, not half of 1500.
func _plate(art: String, is_ledge: bool = false) -> void:
	var path: String = STAGE_ART % [act + 1, art]
	if not ResourceLoader.exists(path):
		# Named rather than silent: a missing plate is otherwise an invisible
		# hole in the ground with nothing in the log saying which one.
		push_warning("stage: missing plate %s" % path)
		return
	var tex: Texture2D = load(path)
	var r: Plate = Plate.new()
	r.art = art
	r.is_ledge = is_ledge
	r.tex = tex
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.anchor_left = 0.5
	r.anchor_right = 0.5
	r.anchor_top = 1.0
	r.anchor_bottom = 1.0
	_shake_host.add_child(r)
	_plates.append(r)
	_layout_plate(r)


## Re-apply every shape-authored field to an existing plate. Keeping the node is
## what preserves its paint order and its current drift phase through a rotation.
func _layout_plate(r: Plate) -> void:
	var stage: Dictionary = _layout()
	var layer: Dictionary = stage.get("layers", {}).get(r.art, {})
	var h: float = LayoutBook.num(layer.get("h"))
	var y: float = LayoutBook.num(layer.get("y"))
	r.dx = LayoutBook.num(layer.get("x"))
	r.zoom = LayoutBook.num(layer.get("zoom"), 1.0)
	r.modulate = Color(1.0, 1.0, 1.0,
		LayoutBook.num(layer.get("opacity"), 1.0))
	r.where = Vector2(
		LayoutBook.num(layer.get("posX"), 50.0),
		LayoutBook.num(layer.get("posY"), 100.0)) * 0.01
	r.amp = LayoutBook.num(layer.get("drift"))
	r.period = PLATE_PERIODS.get(r.art, 26.0)
	var aspect: float = float(r.tex.get_width()) / maxf(1.0, float(r.tex.get_height()))
	r.art_w = h * aspect
	var lip: float = LayoutBook.num(stage.get("ledgeLip"), 14.0)
	var bottom: float = maxf(0.0, _ground_y() + lip - h + y) if r.is_ledge else y
	r.offset_top = -(bottom + h * r.zoom)
	r.offset_bottom = -bottom
	r.fit(_stage_w())
	r.set_process(r.amp > 0.0)
	r.queue_redraw()


func start_encounter(enemy_ids: Array, kind: String, encounter_text: String) -> void:
	_over_emitted = false
	_encounter_text = encounter_text
	# A fight begins with the light in the player's hands again.
	_snuffed = false
	if _lantern != null:
		_lantern.visible = false
	# Headless playback takes no ceremony with it: a test driving the sequencer
	# must never wait on a tween that will not tick.
	_floaters.instant = seq.instant
	_floaters.clear_all()
	# `V.setWeather(theme?.weather, { boss: kind === 'boss' })` — the air a fight
	# happens in, thicker for a boss.
	_vfx.set_weather(not seq.instant, kind == "boss")
	# Live play rolls the elite affix inside start_combat (traces passed it
	# explicitly only to skip the rng draw).
	game.apply({"t": "startCombat", "enemies": enemy_ids, "kind": kind})
	for view: EnemyView in _enemy_views:
		view.queue_free()
	_enemy_views.clear()
	# The hero outlives the encounter — it is the same body between fights, and
	# rebuilding it would throw away a 3D stage for no reason.
	if _hero == null:
		var look: Dictionary = _hero_look()
		var look_hue: float = look["hue"]
		var look_art: StringName = look["art"]
		_hero = EnemyView.new(-1, "", look_hue, look_art, 1.0, _hero_frame())
		# A hero is a rogue in the profile table regardless of aspect — neither
		# has a kind of its own — and char-meta's own block (duskblade breathe
		# 1.6 / sway 0.5, ashwarden breathe 1.3 / sway 0) is laid over it, which
		# is why the one breathes harder and the other stands like smoke.
		_hero.set_profile("rogue")
		_battlefield.add_child(_hero)
	_stand(_hero, _hero_x(), 0.0)
	var slots: Array[Vector2] = _slots(game.cb.enemies.size())
	var scales: PackedFloat32Array = _slot_scales(game.cb.enemies.size())
	# `bfEnemyZOrder`: lower on screen draws in front, so a foe standing further
	# up the ledge sits behind the one nearer the lip. Expressed as the order the
	# actors are ADDED in, because child order is the only ordering that is
	# relative to a sibling. `z_index` is measured against the whole canvas: a
	# foe given z −42 does not go behind its neighbour, it goes behind the STAGE.
	# That is what made two of three foes disappear entirely.
	var order: Array[int] = []
	for i: int in range(game.cb.enemies.size()):
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		var la: float = slots[a].y if a < slots.size() else 0.0
		var lb: float = slots[b].y if b < slots.size() else 0.0
		return la > lb)
	_enemy_views.resize(game.cb.enemies.size())
	for idx: int in order:
		var e: EnemyCombatant = game.cb.enemies[idx]
		# The affix is NOT glued onto the name: it is its own span in its own tone
		# (combat.js:606), so it is handed over separately and the plate keeps the
		# two apart.
		var affix_name: String = ""
		var affix_tone: Color = EnemyView.NAME_DIM
		if game.cb.affix != &"":
			var affix_def: Dictionary = game.content.affixes.get(String(game.cb.affix), {})
			affix_name = str(affix_def.get("name", String(game.cb.affix)))
			var tone_hex: String = str(affix_def.get("tone", ""))
			if tone_hex.begins_with("#"):
				affix_tone = Color(tone_hex)
		var art: Dictionary = e.def.get("art", {})
		var hue_num: int = art.get("hue", 210)
		# The art id is the foe's own key: every slice foe has a painting under
		# that name and char-meta types its box and its feet by the same one.
		# Passing nothing here is what left the fight full of fallback gems.
		var mul: float = scales[idx] if idx < scales.size() else 1.0
		var view: EnemyView = EnemyView.new(e.idx, e.name, float(hue_num), e.key, mul)
		view.set_affix(affix_name, affix_tone)
		# `meshProfileFor(kind, id)` — a golem does not breathe like a wisp, and
		# `art.kind` is the only thing that knows which it is.
		view.set_profile(_foe_kind(e.idx))
		_battlefield.add_child(view)
		_enemy_views[idx] = view
		var slot: Vector2 = slots[idx] if idx < slots.size() else Vector2(_stage_w() * 0.5, 0.0)
		_stand(view, slot.x, slot.y)
	_sync_all()
	_open_fight(slots)


## The opening hand is BUILT by `_sync_all`, not replayed — the startCombat batch
## is hard-synced because the views do not exist until after `apply` returns, so
## its draws never reach `_handle_event` and never fly. Dealt here on the same
## schedule, because otherwise the first thing a fight shows is five cards
## appearing out of nothing, and that is the moment the deal most needs to read.
## Everything that has to wait for the first layout pass. `HudBar._place` hangs
## each cluster off the nearest window edge and `_stand` anchors each actor to
## the ground line, and neither resolves until then — asked in the same frame,
## the draw pile reports a box at y −162 and an actor reports position zero.
func _open_fight(slots: Array[Vector2]) -> void:
	if seq.instant or not is_inside_tree():
		return
	await get_tree().process_frame
	_play_entrance(slots)
	_deal_opening_hand()
	_play_opening_ceremony()


## The start batch is hard-synced, so its bossIntro and variantDialogue events
## never reach `_handle_event` — the ceremony is replayed here from the same
## combat state, over the tail of the walk-in, which is where the benchmark's
## drain lands it (drain.js:253-278). Death lines mid-fight arrive through the
## drain as ordinary events and never pass this way.
func _play_opening_ceremony() -> void:
	if game.cb == null or game.cb.enemies.is_empty():
		return
	var boss: bool = game.cb.enemies[0].boss
	var spoken: Array[String] = []
	var aspect_name: String = ""
	if game.run.aspect >= 0 and game.run.aspect < game.content.aspects.size():
		var aspect_v: Variant = game.content.aspects[game.run.aspect]
		if typeof(aspect_v) == TYPE_DICTIONARY:
			var aspect_d: Dictionary = aspect_v
			aspect_name = str(aspect_d.get("name", "")).trim_prefix("The ")
	for e: EnemyCombatant in game.cb.enemies:
		var lines_v: Variant = e.def.get("dialogue")
		if typeof(lines_v) != TYPE_ARRAY:
			continue
		var lines: Array = lines_v
		for line_v: Variant in lines:
			spoken.append(str(line_v).replace("{aspect}", aspect_name))
	if not boss and spoken.is_empty():
		return
	await _wait(0.9)  # let the walk-in and the deal land first
	if not is_inside_tree():
		return
	if boss:
		_vfx.flash(Color("#1a0a20"), 0.5, 0.9)
		_sky.kick(1.6)
		_sfx.play(&"bigDeath")
		await _floaters.banner(game.cb.enemies[0].name, "boss", 2.1)
	for line: String in spoken:
		if not is_inside_tree():
			return
		await _floaters.banner(line, "variant", 1.8)


## `.combat-screen.intro` (styles.css:739) — the hero walks in from the left,
## the foes from the right, and the furniture rises a beat behind both.
##
## Position is tweened and then handed back to `_stand`, because an actor is
## ANCHORED to the ground line: writing `position` rewrites its offsets, so the
## entrance would quietly cost the layout that keeps its feet on the floor at
## any window height. Re-standing it at the end restores that exactly, and that
## re-anchor is why the slide is driven from here — `EnemyView.enter` owns the
## motion, this owns the slot.
##
## Runs one frame after the views are built (`_open_fight`), because `_stand`
## does not resolve until the first layout pass. Until 2026-07-27 a SECOND
## entrance also fired from `_build_battlefield`, one frame earlier, sliding the
## painting inside its stage while this slid the Control it lives in — two
## animations on one arrival, both mine.
##
## The stagger is `160 + i * 130ms` on the foes only (`combat.js:280`); `heroIn`
## carries no delay. It is what tells the player how many foes there are before a
## single name is read, so it is per SEAT and not one arrival for the lineup.
func _play_entrance(_slots: Array[Vector2]) -> void:
	if _hero != null:
		_hero.enter(0.0, _stand_live_hero)
	for idx: int in range(_enemy_views.size()):
		var view: EnemyView = _enemy_views[idx]
		if view == null:
			continue
		view.enter(EnemyView.ENTER_LEAD + float(idx) * EnemyView.ENTER_STEP,
			_stand_live_enemy.bind(idx))
	_hud.play_entrance()


func _stand_live_hero() -> void:
	if _hero != null:
		_stand(_hero, _hero_x(), 0.0)


func _stand_live_enemy(idx: int) -> void:
	if idx < 0 or idx >= _enemy_views.size():
		return
	var view: EnemyView = _enemy_views[idx]
	if view == null:
		return
	var slots: Array[Vector2] = _slots(_enemy_views.size())
	var slot: Vector2 = slots[idx] if idx < slots.size() \
		else Vector2(_stage_w() * 0.5, 0.0)
	_stand(view, slot.x, slot.y)


func _deal_opening_hand() -> void:
	var opening: Array[int] = _hand.uids()
	if opening.is_empty():
		return
	var flight: float = HandView.deal_flight(opening.size())
	var stagger: float = HandView.deal_stagger(opening.size())
	var pile: Rect2 = _hud.pile_rect(&"draw")
	for i: int in range(opening.size()):
		_hand.deal_in(opening[i], pile, float(i) * stagger, flight)


## The authored formation for this many foes, as (x centre, lift off the ground
## line). Three formations used to be written out here as nine literals — they
## were the `pad-landscape` column of `BF.slots`, and the interpolation below
## them was `bfSlots` reimplemented. Both now come from the book, so a phone gets
## its own formation instead of the iPad one scaled down.
##
## The x values are already flexed: a slot is bound to the RIGHT edge, so extra
## stage width opens the gap between the hero and the foe line rather than
## stretching either.
func _slots(count: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for slot: Dictionary in LayoutBook.slots(_layout(), maxi(count, 0)):
		out.append(Vector2(LayoutBook.num(slot.get("x")), LayoutBook.num(slot.get("y"))))
	return out


## The per-formation size multiplier, `BF.slots[n][i].s`. It is 1 in every
## `pad-landscape` formation and well under it everywhere else — a phone seats
## three foes at 0.5 — which is what keeps a wide lineup on the ledge instead of
## off the side of it.
func _slot_scales(count: int) -> PackedFloat32Array:
	var out: PackedFloat32Array = []
	for slot: Dictionary in LayoutBook.slots(_layout(), maxi(count, 0)):
		out.append(LayoutBook.num(slot.get("s"), 1.0))
	return out


## The hero's resolved battlefield frame. Unlike foes, its authored box is not
## square: pad-landscape is 190 × 285, and phone shapes narrow both axes.
func _hero_frame() -> Vector2:
	var hero: Dictionary = _layout().get("hero", {})
	return Vector2(LayoutBook.num(hero.get("w"), 190.0),
		LayoutBook.num(hero.get("h"), 285.0))


## The aspect's own art id and hue, straight off the content book —
## `runCatalogues().aspects[run.aspect]`. Falls back to the Duskblade look when
## no run is live (labs, tests, slice content without an aspects table).
func _hero_look() -> Dictionary:
	if game != null and game.run != null and game.content != null \
			and game.run.aspect >= 0 and game.run.aspect < game.content.aspects.size():
		var aspect_v: Variant = game.content.aspects[game.run.aspect]
		if typeof(aspect_v) == TYPE_DICTIONARY:
			var aspect_d: Dictionary = aspect_v
			return {
				"art": StringName(str(aspect_d.get("id", HERO_FALLBACK_ART))),
				"hue": LayoutBook.num(aspect_d.get("hue"), HERO_FALLBACK_HUE),
			}
	return {"art": HERO_FALLBACK_ART, "hue": HERO_FALLBACK_HUE}


func _layout_actors() -> void:
	if _hero != null:
		_hero.set_body_frame(_hero_frame())
		_stand(_hero, _hero_x(), 0.0)
		_battlefield.move_child(_hero, 0)
	if game.cb == null:
		return
	var count: int = mini(game.cb.enemies.size(), _enemy_views.size())
	var slots: Array[Vector2] = _slots(count)
	var scales: PackedFloat32Array = _slot_scales(count)
	for idx: int in range(count):
		var view: EnemyView = _enemy_views[idx]
		if view == null:
			continue
		var e: EnemyCombatant = game.cb.enemies[idx]
		var body: float = maxf(8.0, EnemyView.art_box(e.key))
		var body_scale: float = scales[idx] if idx < scales.size() else 1.0
		view.set_body_frame(Vector2.ONE * body * body_scale)
		var slot: Vector2 = slots[idx] if idx < slots.size() \
			else Vector2(_stage_w() * 0.5, 0.0)
		_stand(view, slot.x, slot.y)
	var order: Array[int] = []
	for idx: int in range(count):
		order.append(idx)
	order.sort_custom(func(a: int, b: int) -> bool:
		var ay: float = slots[a].y if a < slots.size() else 0.0
		var by: float = slots[b].y if b < slots.size() else 0.0
		return ay > by)
	var first: int = 1 if _hero != null else 0
	for idx: int in order:
		var view: EnemyView = _enemy_views[idx]
		if view != null:
			_battlefield.move_child(view, first)
			first += 1


## Stand an actor on the ground line: `x` is where its centre goes, `lift` how
## far off the line it stands. `foot` comes from char-meta and is what lets a
## painting whose feet are not at its own bottom edge still touch the ground.
##
## Anchored rather than positioned, because `_battlefield`'s bottom edge IS the
## ground line — so layout does the arithmetic, at whatever size the window is,
## and nothing here has to know the viewport's height.
func _stand(view: EnemyView, x: float, lift: float) -> void:
	# Every actor placed is an actor whose ground chrome must fit this shape, and
	# this is the one funnel both the hero and every foe pass through.
	view.set_chrome_scale(_actor_scale())
	var box: Vector2 = view.size
	view.anchor_left = 0.0
	view.anchor_right = 0.0
	view.anchor_top = 1.0
	view.anchor_bottom = 1.0
	view.offset_left = roundf(x - box.x * 0.5 + view.foot.x)
	view.offset_right = view.offset_left + box.x
	view.offset_bottom = -(lift + view.foot.y)
	view.offset_top = view.offset_bottom - box.y
	# The plate hangs off the GROUND, not off this actor's box. A painting with
	# empty canvas under the creature sinks its box by `foot.y`, and a plate left
	# on the box bottom goes with it — which is why the gravewarden stood on the
	# ledge with its name and its HP rail somewhere under the hand.
	view.align_plate(view.foot.y)


static func _label(initial: String) -> Label:
	var l: Label = Label.new()
	l.text = initial
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func show_result(title: String, body: String, button_text: String) -> void:
	_overlay_title.text = title
	_overlay_body.text = body
	_overlay_button.text = button_text
	_overlay.visible = true


# ---------------------------------------------------------------- input

## Play through the rules gate; false leaves state untouched (drop snaps back).
func request_play(uid: int, target: Variant) -> bool:
	if seq.is_busy() or game.cb.over:
		return false
	var inst: CardInst = _find_card(uid)
	if inst == null or not _rules.can_play(game.run, game.cb, inst, target):
		return false
	# `drain(targetIdx)` — the drain is told what was aimed at, because the
	# `play` event does not carry it and a targeted card flies at its foe.
	_play_target = target
	seq.enqueue(game.apply({"t": "playCard", "uid": uid, "target": target}))
	return true


func request_kindle(uid: int) -> bool:
	if seq.is_busy() or game.cb.over:
		return false
	var inst: CardInst = _find_card(uid)
	if inst == null or not _rules.can_kindle(game.run, game.cb, inst):
		return false
	seq.enqueue(game.apply({"t": "kindleFromHand", "uid": uid}))
	return true


func request_potion(slot: int, target: Variant = null) -> bool:
	if seq.is_busy() or game.cb.over:
		return false
	var events: Array[Dictionary] = game.apply({
		"t": "usePotion",
		"slot": slot,
		"target": target,
	})
	if not (game.last_ret is bool and game.last_ret):
		return false
	seq.enqueue(events)
	_push_hud()
	return true


func refresh_chrome() -> void:
	_push_hud()


## `onCardClick` (combat.js:1667). A click is not an inspection — it is the
## primary way the fight is played, and what it does depends entirely on how many
## things the card could be aimed at:
##
##   - nothing to choose (a `self` card, or an `enemy` card with one survivor
##     left) → the card is PLAYED on the spot
##   - something to choose → the card ARMS, the arc opens, and every living foe
##     starts glowing until one of them is clicked
##   - the armed card clicked again → it is put back down
##   - unplayable, or unaffordable → a refusal sound and nothing else
##
## The port used to open a panel here that restated the card's own rules text.
## Nothing in the benchmark does that: the card face already carries its text, so
## the panel was a second copy of what the player is looking at, sitting on top of
## the fight it was meant to explain.
func _on_card_tapped(uid: int) -> void:
	if seq.is_busy() or game.cb == null or game.cb.over:
		return
	var inst: CardInst = _find_card(uid)
	if inst == null:
		return
	# `COARSE && S.hoveredCard !== uid` — a finger has no hover, so the first tap
	# buys the lift that a mouse gets for free and only the second commits.
	if _coarse() and _hand.hovered_uid != uid and not (_targeting and _selected_uid == uid):
		_hand.hovered_uid = uid
		_hand.raise_seat(uid)
		_sfx.play(&"hover")
		_update_previews()
		return
	# Clicking the card that is already armed is how you change your mind.
	if _targeting and _selected_uid == uid:
		_cancel_targeting()
		return
	_selected_uid = uid
	_hand.hovered_uid = uid
	_activate_selected()


## `matchMedia('(pointer: coarse)')`. A machine with a touchscreen AND a mouse is
## not coarse — the benchmark's query answers for the pointer actually in use, and
## the closest honest reading here is "a touchscreen is all there is".
func _coarse() -> bool:
	return DisplayServer.is_touchscreen_available() \
		and not DisplayServer.has_feature(DisplayServer.FEATURE_MOUSE)


## The benchmark wires hover at all only behind `if (FINE)` (combat.js:960) —
## `c.onmouseenter` sets the hovered card, ticks and relays out, and on a coarse
## pointer that handler is never attached. `FINE` is
## `matchMedia('(hover: hover) and (pointer: fine)')` (context.js:10).
##
## So a finger gets exactly ONE tick per card, from the COARSE first-tap branch
## in `_on_card_pressed`. Godot synthesises mouse motion from touch, so this
## handler runs there too and the port was ticking twice for one tap. The
## previews still update — `layoutHand` recomputes them on the tap either way —
## but the sound is the benchmark's and belongs to the fine pointer only.
func _on_card_hover_changed(uid: int) -> void:
	if uid >= 0 and not _coarse():
		_sfx.play(&"hover")
	_update_previews()


## `beginCardDrag` (combat.js:1534) — lifting a card ticks like hovering one, and
## a card lifted AT something arms exactly as a clicked one does: `beginCardDrag`
## calls the same `setTargeting` (combat.js:1547), so the same halo comes up on
## every living foe. A card that acts on you clears it and travels free instead.
##
## Without this the drag path lit nothing at all: `.targetable` has one setter in
## the benchmark and both gestures go through it.
func _on_card_drag_armed(uid: int) -> void:
	_sfx.play(&"hover")
	var view: CardView = _hand.card_view(uid)
	_targeting = view != null and view.target_kind == "enemy"
	_selected_uid = uid if _targeting else -1
	_aim_hover = -1
	_hand.arm_seat(_selected_uid)
	_update_previews()


## `beginCardDrag` (combat.js:1540) — a card that can neither be paid for nor
## burned refuses out loud, so a dead drag is not mistaken for a dropped input.
func _on_card_drag_refused(_uid: int) -> void:
	_sfx.play(&"debuff")


func _on_card_drag_moved(uid: int, global_pos: Vector2) -> void:
	if not _hand.is_aiming():
		return
	# The arc reaches the POINTER, not the enemy under it — a shot that misses
	# still has to look aimed somewhere.
	_aim.draw_between(_hand.seat_centre(uid), global_pos)
	# `hoverEnemyAt` (combat.js:1594): the rim is no longer set here. Which
	# bodies light up is one decision with three rules in it, and it belongs
	# where the card, the aim and the survivor count are all known.
	_aim_hover = _enemy_at(global_pos)
	_update_previews()


func _on_card_drag_released(uid: int, global_pos: Vector2) -> void:
	_aim.clear_aim()
	_aim_hover = -1
	# The drag armed it (see `_on_card_drag_armed`), so the drag disarms it. Not
	# `_cancel_targeting`: that snaps every seat home, and the card being released
	# is mid-flight to a foe or mid-snap-back on its own clock.
	_targeting = false
	_selected_uid = -1
	_has_aim_at = false
	_hand.armed_uid = -1
	_clear_previews()
	var view: CardView = _hand.card_view(uid)
	if view == null:
		return
	if _hud.lantern_rect().has_point(global_pos):
		if request_kindle(uid):
			return
	elif view.target_kind == "enemy":
		var idx: int = _enemy_at(global_pos)
		if idx >= 0 and request_play(uid, idx):
			return
	elif _above_hand(global_pos) and request_play(uid, null):
		return
	_hand.snap_back(uid)


func _above_hand(global_pos: Vector2) -> bool:
	return global_pos.y < _hand.get_global_rect().position.y


## `hitEnemy` (pointer.js:139) — **backwards**, `for (let i = enemies.length - 1;
## i >= 0; i -= 1)`. Art boxes are squares and they overlap: an elite's box is
## wide enough to swallow the centre of the sporeling standing beside it, and
## walking forwards would hand every one of those presses to the elite.
func _enemy_at(global_pos: Vector2) -> int:
	for i: int in range(_enemy_views.size() - 1, -1, -1):
		var ev: EnemyView = _enemy_views[i]
		if ev == null or not ev.body_rect().has_point(global_pos):
			continue
		if ev.idx < game.cb.enemies.size() and game.cb.enemies[ev.idx].hp > 0:
			return ev.idx
	return -1


func _on_end_turn_pressed() -> void:
	if seq.is_busy() or game.cb.over:
		return
	_sfx.play(&"click")
	seq.enqueue(game.apply({"t": "endTurn"}))


func _on_art_pressed() -> void:
	if seq.is_busy() or game.cb.over:
		return
	if _rules.can_use_art(game.run, game.cb):
		seq.enqueue(game.apply({"t": "useArt"}))
	else:
		_sfx.play(&"debuff")


func _on_kindle_toggled(on: bool) -> void:
	_kindle_toggle.text = "Kindle: on" if on else "Kindle: off"
	_hand.kindle_mode = on
	_aim.clear_aim()
	_hand.cancel_drag()
	_sync_all()  # playability flips between play-cost and kindle rules


## The two things on this screen that never stop moving and belong to nothing in
## the fight: the grain jumping, and the vignette's heartbeat once the player is
## low enough for the screen itself to say so.
func _process(delta: float) -> void:
	_atmos_t += delta
	if _grain_mat != null:
		var step: int = int(_atmos_t / GRAIN_STEP) % GRAIN_JUMPS.size()
		_grain_mat.set_shader_parameter("jitter", GRAIN_JUMPS[step])
	_update_stage_dim()
	_clamp_chrome()
	if _vignette_mat == null:
		return
	_vignette_mat.set_shader_parameter("stage_px", size)
	var low: bool = game.cb != null and game.cb.player.max_hp > 0 \
		and float(game.cb.player.hp) / float(game.cb.player.max_hp) <= LOW_HP_AT
	if not low:
		_vignette_mat.set_shader_parameter("low_alpha", 0.0)
		return
	# `lowhp 1.6s ease-in-out infinite` — out and back inside one iteration, so
	# the keyframe is read at an already-eased t rather than tweened in halves.
	var e: float = Motion.ease(Motion.EASE_IN_OUT,
		fmod(_atmos_t, LOW_HP_PERIOD) / LOW_HP_PERIOD)
	_vignette_mat.set_shader_parameter("low_reach", Motion.keyframe(e,
		[0.0, 0.5, 1.0], [LOW_HP_REACH[0], LOW_HP_REACH[1], LOW_HP_REACH[0]]))
	_vignette_mat.set_shader_parameter("low_alpha", Motion.keyframe(e,
		[0.0, 0.5, 1.0], [LOW_HP_ALPHA[0], LOW_HP_ALPHA[1], LOW_HP_ALPHA[0]]))


## Keep every actor's status on stage. The benchmark schedules this on a rAF from
## the four places that can move chrome — the entrance settling, a refit, a combat
## sync and a hand relayout. A frame is the same coalescing point and it cannot
## miss a fifth caller, so the port pays for the pass every frame instead: a
## handful of floats per actor, and nothing is written while the row already fits.
##
## The lines are in stage px, and a combatant's `position` is battlefield-local,
## whose top edge is the stage's — so the two spaces are already the same one.
func _clamp_chrome() -> void:
	var ceiling: float = maxf(CHROME_CEIL_MIN, _hud.bar_height() + CHROME_CEIL_PAD)
	# The fan's top edge, which is what a status row must stay clear of — so both
	# terms are the card as it is drawn on THIS shape, not as it is authored.
	# Read off the hand rather than the book, because the hand is what actually
	# laid the cards out and the two cannot then disagree.
	var card_h: float = _hand.card_w * (CardView.CARD_H / CardView.CARD_W)
	var floor_y: float = size.y + _hand_overhang() - _hand.card_inset \
		- card_h + CHROME_HAND_SLACK - CHROME_FLOOR_PAD
	# `minLeft = 6` / `maxRight = stageW() - 6` (combat.js:524-525). The horizontal
	# half of the clamp, which had never been ported: at 1180px three foes are far
	# enough apart that nothing reaches an edge, and at 390px the third one loses
	# most of its name off the right side.
	var left: float = global_position.x + CHROME_EDGE_PAD
	var right: float = global_position.x + size.x - CHROME_EDGE_PAD
	for view: EnemyView in _enemy_views:
		if view != null:
			view.clamp_chrome(ceiling, floor_y, left, right)
	if _hero != null:
		_hero.clamp_chrome(ceiling, floor_y, left, right)


## `if (cb.player.block > 0) syncWardMesh(heroSprite, true, true)`
## (combat.js:2580, 2585) — a screen built onto a fighter who is ALREADY warded,
## which is what a mid-combat restore is. Raised without the grow: the stone was
## up before this screen existed, so it does not form again in front of you.
##
## It lives on the sync rather than in `set_ward` because `blockGain` raises the
## shell BEFORE the sync it triggers — putting the raise inside `set_ward` lets
## that sync answer the gain first and swallow the grow it was meant to start.
func _restore_ward_shell(who: EnemyView, block: int) -> void:
	if who != null and block > 0 and not who.ward_shell_on():
		who.set_ward_shell(true, false)


## `updateLantern` (combat.js:404) — how far the light has failed, where it is
## standing, and whether it is guttering. Run every frame rather than at the
## benchmark's call sites: the pool is centred on a body that breathes, sways and
## recoils, and a light that only moves when the HUD is rewritten slides off the
## hero the moment they are hit.
func _update_stage_dim() -> void:
	if _stage_dim_mat == null:
		return
	if _snuffed:
		# The light has been handed to `#lantern`; the stage pool is done.
		_lantern.modulate.a = _gutter_opacity()
		return
	var cb: CombatState = game.cb
	if cb == null or cb.player.max_hp <= 0:
		_stage_dim_mat.set_shader_parameter("la", 0.0)
		_stage_dim.modulate.a = 1.0
		return
	var t: float = clampf(
		(DIM_AT - float(cb.player.hp) / float(cb.player.max_hp)) / DIM_SPAN, 0.0, 1.0)
	_stage_dim_mat.set_shader_parameter("la", t * DIM_MAX_ALPHA)
	_stage_dim_mat.set_shader_parameter("radius_px", lerpf(DIM_RADIUS[0], DIM_RADIUS[1], t))
	_stage_dim_mat.set_shader_parameter("stage_px", _stage_dim.size)
	# `V.centerOf(S.ce.hero)` — the pool hangs off the body carrying the lantern.
	# Taken in the layer's own space so the screen shake, which moves both, does
	# not drag the light across the floor.
	var centre: Vector2 = _hero_centre()
	if _targeting and _has_aim_at:
		centre += (_aim_at - centre) * DIM_AIM_LEAN
	_stage_dim_mat.set_shader_parameter("centre_px", centre - _stage_dim.global_position)
	_stage_dim.modulate.a = 1.0 if t <= DIM_GUTTER_AT else _gutter_opacity()


## `L.classList.add('snuff', 'gutter')` (drain.js:969) — the light goes out. The
## stage pool hands its light over rather than adding to it (`dim --la: 0`,
## gutter off there): two radials at once would double-darken the floor, and the
## one that matters now is the one that covers everything.
func _snuff() -> void:
	if _lantern_mat == null:
		return
	_snuffed = true
	_lantern.visible = true
	_lantern.modulate.a = 1.0
	_lantern_mat.set_shader_parameter("la", SNUFF_ALPHA)
	_lantern_mat.set_shader_parameter("radius_px", SNUFF_RADIUS)
	_lantern_mat.set_shader_parameter("stage_px", _lantern.size)
	# `--lx` / `--ly` are whatever `updateLantern` last wrote, so the view
	# collapses onto the body that was carrying the lantern.
	_lantern_mat.set_shader_parameter("centre_px",
		_hero_centre() - _lantern.global_position)
	if _stage_dim_mat != null:
		_stage_dim_mat.set_shader_parameter("la", 0.0)
		_stage_dim.modulate.a = 1.0


## `document.body.classList.toggle('worldstop')` against
## `#bg3d, #screen { transition: filter 0.22s ease }` — the drain is a CSS
## transition, so it ramps rather than snapping, and the same ramp brings the
## colour back. Tweened through a linear 0→1 and eased inside the callback,
## because Godot's `Tween` easings are a different family from cubic-bezier.
func _set_worldstop(on: bool) -> void:
	if _grain_mat == null:
		return
	if _worldstop_tween != null and _worldstop_tween.is_valid():
		_worldstop_tween.kill()
	_worldstop_from = _worldstop_at
	_worldstop_to = 1.0 if on else 0.0
	if is_equal_approx(_worldstop_from, _worldstop_to):
		return
	if seq.instant:
		_worldstop_drain(1.0)
		return
	_worldstop_tween = create_tween()
	_worldstop_tween.tween_method(_worldstop_drain, 0.0, 1.0, WORLDSTOP_FADE)


func _worldstop_drain(x: float) -> void:
	_worldstop_at = lerpf(_worldstop_from, _worldstop_to, Motion.ease(CSS_EASE, x))
	_grain_mat.set_shader_parameter("drain", _worldstop_at)


## `@keyframes gutter` (styles.css:111) — a flame that is nearly out. Read at the
## raw phase, then eased WITHIN the interval it lands in, because that is what a
## CSS keyframe animation does with its timing function and what makes the dip at
## 41% fall away slowly and snap back.
func _gutter_opacity() -> float:
	var phase: float = fmod(_atmos_t, DIM_GUTTER_PERIOD) / DIM_GUTTER_PERIOD
	for i: int in range(1, DIM_GUTTER_OFFSETS.size()):
		if phase > DIM_GUTTER_OFFSETS[i]:
			continue
		var span: float = DIM_GUTTER_OFFSETS[i] - DIM_GUTTER_OFFSETS[i - 1]
		var f: float = 0.0 if span <= 0.0 else (phase - DIM_GUTTER_OFFSETS[i - 1]) / span
		return lerpf(DIM_GUTTER_VALUES[i - 1], DIM_GUTTER_VALUES[i],
			Motion.ease(CSS_EASE, f))
	return DIM_GUTTER_VALUES[DIM_GUTTER_VALUES.size() - 1]


func _find_card(uid: int) -> CardInst:
	for pile: Array[CardInst] in [game.cb.hand, game.cb.draw, game.cb.discard, game.cb.exhaust]:
		for c: CardInst in pile:
			if c.uid == uid:
				return c
	return null


# ---------------------------------------------------------------- playback

func _wait(seconds: float) -> void:
	if seq.instant:
		return
	await get_tree().create_timer(seconds).timeout


## A one-shot timer that outlives the handler that scheduled it. `_wait` cannot
## do this: it is awaited inside the drain and holds the queue up, while a
## benchmark `setTimeout` deliberately runs alongside it.
func _after(seconds: float, what: Callable) -> void:
	if seq.instant:
		what.call()
		return
	get_tree().create_timer(seconds).timeout.connect(what, CONNECT_ONE_SHOT)


## What the lantern does once the embers have crossed the screen to it. The
## benchmark's timer also re-runs `syncCombat`; here the count is restated by
## the `_push_hud()` at the top of the case, which is a beat early and is a
## separate question from the pop's timing.
func _lantern_answers() -> void:
	_hud.pulse(&"lantern")


## `.art-cast` (drain.js:403). NOT awaited: the benchmark fires the animation and
## walks straight on to `kick(0.7)`, `syncCombat()` and a 420ms beat, so the face
## is still rising while the queue moves. Awaiting it would hold the drain for
## 900ms the benchmark spends elsewhere.
func _art_cast(id: String, at: Vector2) -> void:
	if _cast == null:
		return
	var path: String = CAST_ART % id
	if not ResourceLoader.exists(path):
		# `if (au)` — an art with no face simply does not cast one.
		return
	var tex: Texture2D = load(path)
	_cast.texture = tex
	_cast_glow.texture = tex
	_cast_home = at - Vector2(0.0, CAST_LIFT)
	_cast_step(0.0)
	if seq.instant:
		return
	_cast.visible = true
	_cast_glow.visible = true
	var tw: Tween = create_tween()
	tw.tween_method(_cast_step, 0.0, 1.0, CAST_MS).set_trans(Tween.TRANS_LINEAR)
	tw.tween_callback(_cast_done)


## `onfinish = () => img.remove()`
func _cast_done() -> void:
	_cast.visible = false
	_cast_glow.visible = false


## Linear time in, `cubic-bezier(.2,.7,.3,1)` shaping the clock, and the three
## tracks read off it linearly between the offsets — the WAAPI contract.
func _cast_step(x: float) -> void:
	var t: float = Motion.ease(CAST_EASE, x)
	var s: float = Motion.keyframe(t, CAST_AT, CAST_SCALE)
	var a: float = Motion.keyframe(t, CAST_AT, CAST_ALPHA)
	var box: Vector2 = Vector2.ONE * CAST_SIZE * s
	# A percentage of the element's OWN height, so the rise grows with the scale.
	var rise: float = Motion.keyframe(t, CAST_AT, CAST_RISE) * box.y
	var top_left: Vector2 = _cast_home - box * 0.5 - Vector2(0.0, rise)
	_cast.size = box
	_cast.position = top_left
	_cast.modulate.a = a
	var halo: Vector2 = box + Vector2.ONE * CAST_BLUR * 2.0
	_cast_glow.size = halo
	_cast_glow.position = top_left - Vector2.ONE * CAST_BLUR
	_cast_glow.modulate.a = CAST_GLOW.a * a


func _enemy_view(idx: int) -> EnemyView:
	if idx >= 0 and idx < _enemy_views.size():
		return _enemy_views[idx]
	return null


## `combatantView(en).kind` — the body shape `choreoAttack` sorts by. It rides on
## the enemy's own content, so a golem loads in place and a wisp drifts without
## anything here having to know which is which.
func _foe_kind(idx: int) -> String:
	if idx < 0 or idx >= game.cb.enemies.size():
		return "humanoid"
	var art: Dictionary = game.cb.enemies[idx].def.get("art", {})
	return str(art.get("kind", "humanoid"))


## `mvDef?.intent` — what the move about to resolve promises.
func _move_intent(idx: int, move_key: String) -> String:
	if idx < 0 or idx >= game.cb.enemies.size():
		return ""
	var moves: Dictionary = game.cb.enemies[idx].def.get("moves", {})
	var mv: Dictionary = moves.get(move_key, {})
	return str(mv.get("intent", ""))


## `mvDef?.intent?.startsWith('attack')` — only an attacking move is thrown.
func _move_is_attack(idx: int, move_key: String) -> bool:
	return _move_intent(idx, move_key).begins_with("attack")


## `presentation.enemyCenter(idx)` — the middle of a foe's painted body, and the
## point every effect aimed at it is thrown from.
func _enemy_centre(idx: int) -> Vector2:
	var v: EnemyView = _enemy_view(idx)
	if v == null:
		return size * 0.5
	return v.body_centre()


## `cb.enemies.findIndex((e) => e.hp > 0)` — the foe a play-time signature aims
## at when it has to aim at something.
func _first_living() -> int:
	if game.cb == null:
		return -1
	for e: EnemyCombatant in game.cb.enemies:
		if e.hp > 0:
			return e.idx
	return -1


func _hero_centre() -> Vector2:
	if _hero == null:
		return Vector2(_hero_x(), size.y - _ground_y() - 120.0)
	return _hero.body_centre()


## Either side of a hit, by the `who` the domain speaks: a string for the player,
## an index for a foe.
func _who_centre(who: Variant) -> Vector2:
	if typeof(who) == TYPE_STRING:
		return _hero_centre()
	var idx: int = who
	return _enemy_centre(idx)


## Fire-and-forget rising numeral. Thin so the drain branches below read as the
## benchmark's do — `floatText(x, y, text, cls)` and nothing else.
func _float(at: Vector2, msg: String, cls: String = "dmg",
		tint: Color = Color(0, 0, 0, 0), dx: float = 0.0,
		icon: Texture2D = null, icon_px: int = 0) -> void:
	_floaters.float_text(at, msg, cls, tint, dx, icon, icon_px)


## `presentation.holdPendingPileArrivals` in one line: a card in flight has
## already left the engine's hand, so the pile it is heading for would otherwise
## show its new count while the card is still mid-air. Nothing is held here yet —
## the counts are corrected by `_sync_all` when the pump idles — but the bump is
## the arrival the flight was missing.
func _land_in_pile(which: StringName) -> void:
	_hud.bump_pile(which)

func _handle_event(ev: Dictionary) -> void:
	var t: StringName = ev["t"]
	match t:
		EventTypes.TURN:
			# `if (ev.n > 1)` — turn 1 opens the fight and needs no announcement;
			# every turn after it gets the plate and a longer beat.
			var n: int = ev["n"]
			_sync_actors()
			if n > 1:
				_sfx.play(&"turn")
				_floaters.banner(SAY_YOUR_TURN, "turn")
				await _wait(0.5)
			else:
				await _wait(0.12)
		EventTypes.INTENT:
			_sync_actors()
		EventTypes.ENERGY:
			_sfx.play(&"energy")
			_sync_actors()
			_hud.pulse(&"energy")
		EventTypes.DRAW:
			var uid: int = ev["uid"]
			var inst: CardInst = _find_card(uid)
			if inst != null:
				# The wave is paced by its own size, so the handler asks how many
				# draws it heads rather than guessing from the hand.
				var wave: int = seq.run_length(EventTypes.DRAW)
				# `replacePileVisualOverride` — opened on the FIRST card of the
				# wave and holding what the pile had before the engine emptied it.
				if not _pile_override.has(&"draw"):
					_pile_override[&"draw"] = game.cb.draw.size() + wave
				_sfx.play(&"draw")
				_hand.add_card(inst, _rules.card_data(inst),
					_rules.eff_cost(game.run, game.cb, inst))
				# This card has now left the pile, so the pile is one lighter. The
				# count walks down with the deal instead of arriving already spent.
				_pile_override[&"draw"] = maxi(0, int(_pile_override[&"draw"]) - 1)
				_push_hud()
				_hand.deal_in(uid, _hud.pile_rect(&"draw"), 0.0,
					HandView.deal_flight(wave))
				# Only the stagger is waited on: the flights overlap, which is
				# what makes a five-card draw read as one deal rather than five.
				await _wait(HandView.deal_stagger(wave))
				if seq.run_length(EventTypes.DRAW) == 1:
					# `clearPileVisualOverride` + `bumpPile` (drain.js:263, :281) —
					# the wave is over, so the pile goes back to telling the truth
					# and takes its one bump for the whole deal.
					_pile_override.erase(&"draw")
					_land_in_pile(&"draw")
					_push_hud()
		EventTypes.RESHUFFLE:
			var shuffled: int = ev.get("n", 0)
			await _reshuffle_ceremony(shuffled)
			_sync_actors()
		EventTypes.PLAY:
			var uid: int = ev["uid"]
			var inst: CardInst = _find_card(uid)
			# `vfxSource` — the card decides what its blows look like, and every
			# hit until the next action reads it back.
			_archetype = "slash"
			_vfx_card_id = ""
			if inst != null:
				_archetype = str(_rules.card_data(inst).get("vfx", "slash"))
				_vfx_card_id = str(inst.id)
			_bespoke_fired = false
			# `['ascension','pyreheart','emberdance','limitBreak']` (drain.js:495) —
			# four signatures that are not an impact at all. They fire on the PLAY,
			# at the hero, before anything has been struck; only limitBreak reaches
			# out, to the first living foe.
			if PLAY_TIME_BESPOKE.has(_vfx_card_id):
				var living: int = _first_living()
				var from_at: Vector2 = _hero_centre()
				if _vfx_card_id == "limitBreak" and living >= 0:
					from_at = _enemy_centre(living)
				_bespoke_fired = _vfx.bespoke(_vfx_card_id, from_at)
			_hit_seq = 0
			_hero_swung = false  # this card's swing is owed
			_sfx.play(&"card")
			# `if (c && targetIdx != null && cb.enemies[targetIdx])` — a targeted
			# attack does not go quietly to the discard from the hand. The card
			# itself streaks into the foe, and the `toDiscard` that follows moves
			# the pile copy.
			var aimed: int = _play_target if typeof(_play_target) == TYPE_INT else -1
			_play_target = null
			if aimed >= 0 and aimed < game.cb.enemies.size():
				_hand.strike_to(uid, _enemy_centre(aimed))
			else:
				_hand.remove_card(uid)
			_sync_actors()
			await _wait(0.2)
		EventTypes.HIT_ENEMY:
			await _hit_enemy(ev)
		EventTypes.HIT_PLAYER:
			await _hit_player(ev)
		EventTypes.CHIP:
			var idx: int = ev["idx"]
			var chips: int = ev["chips"]
			var facet_max: int = ev["facetMax"]
			var at: Vector2 = _enemy_centre(idx)
			_sfx.play(&"chip")
			_vfx.burst(at, Color(0.9098039, 0.95686275, 1.0), 5, 190.0,
				TAU, 0.0, 1.8, 240.0)
			# Sync FIRST, then the flourish — the benchmark restates the count and
			# only then re-triggers `pop`, so the pane that pops is the new one.
			_sync_actors()
			var view: EnemyView = _enemy_view(idx)
			if view != null:
				view.set_facets(chips, facet_max, true)
			await _wait(0.11)
		EventTypes.SHATTER:
			var idx: int = ev["idx"]
			var facet_max: int = ev["facetMax"]
			var at: Vector2 = _enemy_centre(idx)
			_sfx.play(&"shatter")
			_vfx.hitstop(90.0)
			_vfx.ring(at, GLASS_BLUE, 10.0, 700.0, 5.0)
			_vfx.burst(at, GLASS_BLUE, 26, 430.0, TAU, 0.0, 2.4, 300.0)
			_float(at + Vector2(0.0, -58.0), SAY_SHATTER, "shatterf", GLASS_BLUE)
			_vfx.shake(10.0)
			_sky.kick(0.9)
			var view: EnemyView = _enemy_view(idx)
			if view != null:
				view.set_facets(0, facet_max, true)
				view.crack()          # addCrack(x.art, true)
				view.take_hit(false)  # the `hurt` flash without the shove
			_sync_actors()
			await _wait(0.38)
		EventTypes.STAGGERED:
			var idx: int = ev["idx"]
			_sfx.play(&"stagger")
			_float(_enemy_centre(idx) + Vector2(0.0, -76.0), SAY_STAGGERED,
				"staggerf", WARM_GOLD)
			# `.reseaming` for 720ms (drain.js:458) — the shimmer runs alongside
			# the 520ms beat rather than holding it up, so it is still finishing
			# as the queue moves on.
			var staggered: EnemyView = _enemy_view(idx)
			if staggered != null:
				staggered.reseam()
			# The intent chip becomes the STAGGERED plate here, not a beat later —
			# `syncCombat` reads `en.staggered` and rewrites the telegraph.
			_sync_actors()
			await _wait(0.52)
		EventTypes.DIE:
			var dead_idx: int = ev["idx"]
			await _die(dead_idx)
		EventTypes.EMBER:
			var n: int = ev.get("n", 0)
			_sfx.play(&"ember")
			_push_hud()
			if n > 0:
				var to: Vector2 = _hud.lantern_rect().get_center()
				var from: Vector2 = _ember_from if _has_ember_from else _hero_centre()
				_vfx.fly_to(from, to, EMBER_ORANGE, mini(n * 2, 5), 6.0, 0.46)
				# `setTimeout(..., 440)` (drain.js:371) — the pop and the resync both
				# wait out the 460ms flight while the drain itself moves on at 300.
				# The port fired the pop on the call, so the lantern answered embers
				# that were still in the air.
				_after(EMBER_LAND, _lantern_answers)
				await _wait(0.3)
			_has_ember_from = false
		EventTypes.BLOCK_GAIN:
			var who_v: Variant = ev["who"]
			var total: int = ev["total"]
			var n: int = ev.get("n", total)
			var at: Vector2 = _who_centre(who_v)
			_sfx.play(&"block")
			# `syncWardMesh(host, true, true)` (drain.js:663) — GAINING guard is the
			# one call that passes `grow`, and that is the whole distinction: a
			# resync only states that ward is still there, while this says it was
			# just put up. The first one grows the stone; after that it pulses the
			# facets, so a second Ward card is visibly a second Ward card.
			if typeof(who_v) == TYPE_STRING:
				if _hero != null:
					_hero.set_ward(total)
					_hero.set_ward_shell(true, true)
				_hud.pulse(&"ward")
			else:
				var who_idx: int = who_v
				var view: EnemyView = _enemy_view(who_idx)
				if view != null:
					view.set_ward(total)
					view.set_ward_shell(true, true)
			_float(at + Vector2(0.0, -10.0), str(n), "blockf", WARD_BLUE, 0.0,
				WARD_ICON, 22)
			_sync_actors()
			await _wait(0.14)
		EventTypes.STATUS:
			var who_v: Variant = ev["who"]
			var n: int = ev["n"]
			var id: String = str(ev.get("id", ""))
			var at: Vector2 = _who_centre(who_v)
			var info: Dictionary = game.content.statuses.get(id, {})
			var display: String = str(info.get("name", id))
			# `isDebuff` (drain.js:681) — a status is bad news if the catalogue
			# says so, or if it is strength going the wrong way.
			var debuff: bool = str(info.get("kind", "buff")) == "debuff" \
				or (id == "str" and n < 0)
			# `(ev.id === 'poison' ? sfx.poison : isDebuff ? sfx.debuff : sfx.buff)()`
			if id == "poison":
				_sfx.play(&"poison")
			else:
				_sfx.play(&"debuff" if debuff else &"buff")
			var sign: String = "+" if n > 0 else ""
			_float(at + Vector2(0.0, -46.0), "%s%d %s" % [sign, n, display],
				"debufff" if debuff else "bufff")
			if not debuff:
				_vfx.motes(at, BUFF_BLUE, 6)
			# The chip has to appear WITH the number that announced it. Waiting for
			# the pump to idle is what made a poison stack look like it had not
			# been applied at all.
			_sync_actors()
			await _wait(0.17)
		EventTypes.HEAL:
			var n: int = ev["n"]
			var at: Vector2 = _who_centre(ev.get("who", "player"))
			_sfx.play(&"heal")
			_vfx.motes(at, HEAL_GREEN, 14)
			_float(at + Vector2(0.0, -30.0), "+%d" % n, "healf")
			_sync_actors()
			await _wait(0.2)
		EventTypes.TO_DISCARD, EventTypes.EXHAUST:
			var uid: int = ev["uid"]
			# Each pile takes its own cards back. Ash is not the discard: a card
			# that burns out has to be seen going somewhere else, or the two
			# piles are the same pile wearing different labels.
			var pile: StringName = &"ashes" if t == EventTypes.EXHAUST else &"discard"
			_hand.spend_to(uid, _hud.pile_rect(pile))
			# `await presentation.flyCardBacks(..., 200, ...)` (drain.js:864) — the
			# pile is bumped by the card ARRIVING, not by it setting off. Without
			# the wait the count ticked while the card was still in the air and the
			# next event opened over the top of the flight.
			await _wait(HandView.SPEND_FLIGHT)
			_land_in_pile(pile)
			_sync_actors()
		EventTypes.POWER_CONSUMED:
			# `powerConsumed` (drain.js:935): a power is not discarded — it
			# settles into the glass. The card goes, and what travels to the hero
			# is the power itself.
			var uid: int = ev["uid"]
			_sfx.play(&"buff")
			var view: CardView = _hand.card_view(uid)
			var from: Vector2 = view.global_centre() if view != null \
				else Vector2(size.x * 0.5, size.y - 180.0)
			_hand.remove_card(uid)
			var hero_at: Vector2 = _hero_centre()
			_vfx.fly_to(from, hero_at, POWER_LILAC, 7, 7.0, 0.56)
			await _wait(0.3)
			_vfx.ring(hero_at, POWER_LILAC, 12.0, 460.0, 4.0)
			_vfx.motes(hero_at, POWER_LILAC, 8)
		EventTypes.KINDLE:
			var uid: int = ev["uid"]
			_sfx.play(&"kindle")
			# Burnt for embers is still burnt: `kindleFromHand` calls
			# `exhaust_card` right after queueing this (combat.gd:752), so the
			# card lands in ash. The EXHAUST that follows finds it already gone
			# and does nothing, which is why it is flown from here rather than
			# left for that event to move twice.
			var view: CardView = _hand.card_view(uid)
			if view != null:
				# `emberFrom = V.centerOf(c)` — the fire this feeds the lantern
				# leaves from the card that burned, not from the hero.
				_ember_from = view.global_centre()
				_has_ember_from = true
				_vfx.burst(_ember_from, EMBER_ORANGE, 22, 190.0, TAU, 0.0,
					2.4, -150.0, "spark", true, 0.85)
			_hand.spend_to(uid, _hud.pile_rect(&"ashes"))
			await _wait(HandView.SPEND_FLIGHT)
			_land_in_pile(&"ashes")
			_sync_actors()
		EventTypes.ART:
			var id: String = str(ev.get("id", ""))
			var art: Dictionary = game.content.arts.get(id, {})
			# `art.tone` is authored in the benchmark's own art catalogue, which
			# the slice exporter does not carry — the lantern's ember stands in
			# until it does.
			var tone: Color = EMBER_ORANGE
			var tone_hex: String = str(art.get("tone", ""))
			if tone_hex.begins_with("#"):
				tone = Color(tone_hex)
			var hero_at: Vector2 = _hero_centre()
			_sfx.play(&"art")
			# An art is the lantern's doing: it flares there and settles on the
			# body. The hero does not swing for it (`!startsWith('art:')`).
			_archetype = "fire"
			_hero_swung = true
			_vfx.flash(tone, 0.12, 0.5)
			_vfx.ring(_hud.lantern_rect().get_center(), tone, 10.0, 620.0, 5.0)
			# `V.BESPOKE_VFX['art:'+id]?.(lx, ly)` (drain.js:435) — an art's own
			# signature fires AT THE LANTERN, immediately, and is marked spent so
			# the impacts that follow do not fire it a second time.
			_vfx_card_id = "art:" + id
			_bespoke_fired = _vfx.bespoke(_vfx_card_id,
				_hud.lantern_rect().get_center())
			_vfx.motes(hero_at, tone, 12)
			_float(hero_at + Vector2(0.0, -84.0),
				str(art.get("name", id)).to_upper(), "artf", tone)
			_art_cast(id, hero_at)
			_sky.kick(0.7)
			_sync_actors()
			await _wait(0.42)
		EventTypes.POTION:
			_sfx.play(&"potion")
			await _wait(0.12)
		EventTypes.DISCARD_HAND:
			var uids: Array = ev["uids"]
			if not uids.is_empty():
				_sfx.play(&"card")
			var discard_rect: Rect2 = _hud.pile_rect(&"discard")
			for uid_v: Variant in uids:
				var uid_i: int = uid_v
				_hand.spend_to(uid_i, discard_rect)
			# Same rule as `toDiscard`: the pile is bumped on arrival. An end of turn
			# that swept five cards used to tick the count before any of them
			# reached it, so the enemy's banner opened over a hand still in flight.
			if not uids.is_empty():
				await _wait(HandView.SPEND_FLIGHT)
				_land_in_pile(&"discard")
			_sync_actors()
		EventTypes.BOSS_INTRO:
			# drain.js:253-268 — the plate names the boss while the world dims,
			# takes the kick, and the big bell tolls. The banner is awaited; the
			# rest land on its first frame.
			_vfx.flash(Color("#1a0a20"), 0.5, 0.9)
			_sky.kick(1.6)
			_sfx.play(&"bigDeath")
			await _floaters.banner(str(ev.get("name", "")), "boss", 2.1)
		EventTypes.VARIANT_DIALOGUE:
			await _floaters.banner(str(ev.get("text", "")), "variant", 1.8)
		EventTypes.END_TURN:
			# `heroActing = false` — nothing swings again until a card is played.
			_hero_swung = true
			_floaters.banner(SAY_ENEMY_TURN, "turn")
			await _wait(0.48)
		EventTypes.ENEMY_ACT:
			await _enemy_act(ev)
		EventTypes.SMOLDER_JUMP:
			var from_idx: int = ev.get("from", -1)
			var to_idx: int = ev.get("to", -1)
			_sfx.play(&"poison")
			_vfx.fly_to(_enemy_centre(from_idx), _enemy_centre(to_idx),
				POISON_TAN, 5, 7.0, 0.46)
			await _wait(0.4)
		EventTypes.RELIC_PROC:
			# The chrome has no relic row yet (docs/hud-handoff.md D5), so the
			# proc says its own name instead of lighting a chip that is not there.
			_float(_hero_centre() + Vector2(0.0, -110.0),
				str(ev.get("id", "")).to_upper(), "notice")
			await _wait(0.09)
		&"addCard":
			_sync_all()
			await _wait(0.09)
		&"adamantHold":
			var idx: int = ev.get("idx", -1)
			var view: EnemyView = _enemy_view(idx)
			if view != null:
				view.reseam()
			_float(_enemy_centre(idx) + Vector2(0.0, -70.0), "ADAMANT", "notice")
			_sync_actors()
			await _wait(0.18)
		EventTypes.VICTORY:
			await _wait(0.32)
			_sfx.play(&"victory")
			_vfx.flash(Color(1.0, 0.9137255, 0.6745098), 0.16, 0.6)
			var perfect: bool = ev.get("perfect", false)
			if perfect:
				await _floaters.banner(SAY_PERFECT, "perfect", 1.4)
				await _wait(0.5)
		EventTypes.DEFEAT:
			await _wait(0.4)
			_sfx.play(&"defeat")
			_vfx.flash(Color(0.2, 0.0, 0.0), 0.5, 1.2)
			_snuff()
			await _wait(0.9)
		_:
			push_warning("CombatScreen: unhandled event %s" % String(t))


# ------------------------------------------------------- the heavier branches

## `hitEnemy` (drain.js:532). Poison ticks quietly; everything else is a swing,
## an impact, a number and a shove, in that order.
func _hit_enemy(ev: Dictionary) -> void:
	var idx: int = ev["idx"]
	var amount: int = ev["amount"]
	var hp_after: int = ev["hpAfter"]
	var blocked: int = ev.get("blocked", 0)
	# The domain flags a poison tick the same way the benchmark's drain reads
	# `ev.poison`, so the two never have to agree by coincidence.
	var poison: bool = ev.get("poison", false)
	var view: EnemyView = _enemy_view(idx)
	var at: Vector2 = _enemy_centre(idx)

	if poison:
		_sfx.play(&"poison")
		_vfx.motes(at, POISON_TAN, 14)
		_float(at + Vector2(0.0, -20.0), str(amount), "poisonf", POISON_TAN)
	else:
		var big: bool = amount >= BIG_HIT
		# `choreoDone` (drain.js:542): the hero swings once for the CARD and the
		# blows land after it, so a three-hit attack is one swing and three
		# recoils rather than three swings.
		if not _hero_swung and _hero != null:
			_hero_swung = true
			await _wait(_hero.lunge("humanoid"))
		_sfx.attack(&"hero", amount, blocked)
		# The signature FIRST and the family under it (drain.js:545-549) — both fire
		# on the same blow, and the latch is what keeps a three-hit card from
		# throwing its signature three times.
		if not _bespoke_fired and not _vfx_card_id.is_empty():
			_bespoke_fired = _vfx.bespoke(_vfx_card_id, at)
		_vfx.archetype_hit(at, _archetype, minf(1.0, float(amount) / POWER_SCALE))
		if view != null:
			view.take_hit(true)  # choreoHit — the recoil and the hurt flash
		if blocked > 0:
			_sfx.play(&"blocked")
			# The stone answers for having stopped it. Separate from `take_hit` above, which
			# is the body recoiling — a warded creature does both, an unwarded one does only
			# the recoil, and `ward_hit` is a no-op when there is no stone.
			if view != null:
				view.ward_hit(Vector2.LEFT)
			_float(at + Vector2(0.0, 26.0), str(blocked), "blockedf",
				Color(0, 0, 0, 0), 0.0, WARD_ICON, 19)
			_vfx.burst(at + Vector2(0.0, 8.0), WARD_BLUE, 9, 210.0, TAU, 0.0,
				2.0, 260.0)  # ward chips off
			if idx < game.cb.enemies.size() and game.cb.enemies[idx].block == 0 \
					and amount == 0:
				_floaters.banner(SAY_GUARD_SHATTERED, "guard-shattered")
				_vfx.shard_spray(at, WARD_BLUE, 14)
		if amount > 0:
			var killing: bool = ev.get("killingBlow", false)
			var overkill: int = ev.get("overkill", 0)
			var tier: String = "dmg"
			if killing and overkill >= 8:
				tier = "dmg-overkill"
			elif killing:
				tier = "dmg-kill"
			elif big:
				tier = "dmg-big"
			# `dx: (hitSeq++ % 3 - 1) * 34` — a multi-hit card lays its numbers
			# in three columns so the second does not land on the first.
			var dx: float = float(_hit_seq % 3 - 1) * 34.0
			_hit_seq += 1
			var tone: Color = VfxLayer.TONES.get(_archetype, Color.WHITE)
			_float(at + Vector2(0.0, -24.0), str(amount), tier, tone, dx)
			if view != null:
				# `addCrack(x.art, big)`, with the damage number passed through — the last
				# gap in `docs/fracture-model.md`, whose §3 calls this conversion the one
				# honest fudge. Until now every blow scored the same star whatever it cost,
				# so a 3 and a 40 broke the glass identically. `EnemyView.energy_of` is the
				# `bite` calibration; the view holds `_max_hp`, so it is handed the raw
				# number rather than a fraction this file would have to derive.
				view.crack(EnemyView.ANYWHERE, amount)
			_vfx.shake(minf(4.0 + float(amount) * 0.5, 15.0))
			_sky.kick(minf(0.2 + float(amount) / 26.0, 1.0))
			if big:
				_vfx.hitstop(70.0)
				_vfx.ring(at, WARM_GOLD, 10.0, 620.0, 5.0)
			if killing:
				# the blow that ends a life lands heavier — and overkill heavier still
				_vfx.hitstop(130.0 if overkill >= 8 else 90.0)
				_sky.kick(minf(1.6, 0.6 + float(overkill) * 0.06))
				_vfx.ring(at, Color.WHITE, 8.0, 780.0, 5.0)
				_vfx.ring(at, WARM_GOLD, 14.0, 900.0, 4.0)
				_vfx.flash(Color(1.0, 0.9019608, 0.6901961), 0.09, 0.28)
				if overkill >= 8:
					_vfx.flash(Color.WHITE, 0.12, 0.24)
					_vfx.burst(at, SPARK_WHITE, 26, 620.0, TAU, 0.0, 2.6, 200.0)
					_vfx.burst(at, Color(1.0, 0.84313726, 0.43137255), 12, 300.0,
						TAU, 0.0, 3.4, 120.0)
		elif blocked == 0:
			_float(at + Vector2(0.0, -24.0), "0", "blockedf")

	if view != null and idx < game.cb.enemies.size():
		view.set_hp(hp_after, game.cb.enemies[idx].max_hp)
		if poison:
			view.take_hit(false)  # the `hurt` flash, with no shove behind it
	# The ward that just absorbed the blow, the facet that just went dark and the
	# rail all restate here. `reap` stays false: this hit may have been the killing
	# one, and the death rite has not run yet.
	_sync_actors()
	await _wait(0.23)


## `hitPlayer` (drain.js:625). The source decides whether the body is thrown:
## a blow shoves, poison and your own burn do not.
func _hit_player(ev: Dictionary) -> void:
	var amount: int = ev["amount"]
	var hp_after: int = ev["hpAfter"]
	var blocked: int = ev.get("blocked", 0)
	var source: String = str(ev.get("source", ""))
	var indirect: bool = source in INDIRECT_SOURCES
	var at: Vector2 = _hero_centre()

	if source == "poison":
		_sfx.play(&"poison")
		_vfx.motes(at, POISON_TAN, 14)
	elif source == "burn" or source == "self":
		_sfx.play(&"debuff")
	elif source == "thorns":
		_sfx.play(&"blocked")
	elif not indirect:
		_sfx.attack(&"enemy", amount, blocked)
		if amount > 0:
			_vfx.flash(Color(1.0, 0.13333334, 0.2), minf(0.05 + float(amount) * 0.012, 0.3), 0.3)
		_vfx.archetype_hit(at, _archetype, minf(1.0, float(amount) / POWER_SCALE))
	if _hero != null:
		_hero.set_hp(maxi(0, hp_after), game.cb.player.max_hp)
		_hero.take_hit(not indirect)
	if blocked > 0:
		_sfx.play(&"blocked")
		# The same pair `_hit_enemy` makes, and the half the hero was missing. `take_hit`
		# above is the BODY recoiling; this is the stone answering for having stopped the
		# blow. A foe that ate one flinched its shield and rang the facets facing the
		# hero; the hero ate the identical blow and its stone did not move, so a guarded
		# hero and an unguarded one were the same picture apart from the numeral.
		#
		# `RIGHT` where the foe gets `LEFT`, and it has to be the mirror rather than the
		# default: `from` points from the creature toward whoever struck it, so it drives
		# the shield away from that side and lights the facets on it. The foes are on the
		# hero's right, and passing the default would drive the hero's stone INTO the blow.
		if _hero != null:
			_hero.ward_hit(Vector2.RIGHT)
		_float(at + Vector2(0.0, 30.0), str(blocked), "blockedf",
			Color(0, 0, 0, 0), 0.0, WARD_ICON, 19)
		_vfx.burst(at + Vector2(0.0, 8.0), WARD_BLUE, 9, 210.0, TAU, 0.0, 2.0, 260.0)
		if game.cb.player.block == 0 and amount == 0:
			_floaters.banner(SAY_GUARD_SHATTERED, "guard-shattered")
			_vfx.shard_spray(at, WARD_BLUE, 14)
	if amount > 0:
		var dx: float = float(_hit_seq % 3 - 1) * 34.0
		_hit_seq += 1
		var tone: Color = VfxLayer.TONES.get(_archetype, Color.WHITE)
		_float(at + Vector2(0.0, -30.0), str(amount),
			"dmg-big" if amount >= BIG_HIT else "dmg", tone, dx)
		_vfx.shake(minf(5.0 + float(amount) * 0.6, 18.0))
		_sky.kick(minf(0.3 + float(amount) / 22.0, 1.2))
		# no hero cracks (user call, 2026-07-07): the glass language is for foes
	elif blocked == 0:
		_float(at + Vector2(0.0, -30.0), "0", "blockedf")
	_sync_actors()
	await _wait(0.24)


## `die` (drain.js:589). The body sags, the fire wells up through its own
## fractures, and at the instant the blaze peaks the glass gives.
func _die(idx: int) -> void:
	var view: EnemyView = _enemy_view(idx)
	var at: Vector2 = _enemy_centre(idx)
	var boss: bool = idx < game.cb.enemies.size() and game.cb.enemies[idx].boss
	var elite: bool = idx < game.cb.enemies.size() and game.cb.enemies[idx].elite
	# the fire inside spills toward the lantern
	_ember_from = at
	_has_ember_from = true
	if boss:
		# `worldstop` (drain.js:594) — the world stops: colour drains, the cracks
		# blaze with inner light, one silent beat, and only then is the vessel
		# allowed to fail. The drain and the seams both come back off before the
		# rite proper starts, because the rite has its own light.
		_set_worldstop(true)
		if view != null:
			view.set_doomed(true)
		_vfx.hitstop(WORLDSTOP_STOP)
		await _wait(WORLDSTOP_HOLD)
		_set_worldstop(false)
		if view != null:
			view.set_doomed(false)
	if view != null:
		await _wait(view.stagger())
	var beat: float = 0.32 if boss else 0.2
	if view != null:
		view.mark_dead(beat)
	await _wait(beat)
	_sfx.play(&"bigDeath" if (boss or elite) else &"death")
	_vfx.burst(at, GLASS_BLUE, 30, 480.0, TAU, 0.0, 2.6, 340.0)
	_vfx.burst(at, SOUL_VIOLET, 26, 380.0, TAU, 0.0, 3.2, 60.0, "dot")
	_vfx.ring(at, REVIVE_LILAC, 12.0, 720.0, 6.0)
	_vfx.flash(Color.WHITE, 0.24 if boss else 0.1, 0.3)
	_vfx.shake(22.0 if boss else 12.0)
	_sky.kick(2.0 if boss else 0.9)
	await _wait(0.9 if boss else 0.5)


## `enemyAct` (drain.js:884). The chip blazes, the name reads, THEN the body
## moves — a move that does not attack still holds the beat, so the enemy turn
## keeps its rhythm whether or not anything swings.
func _enemy_act(ev: Dictionary) -> void:
	var idx: int = ev["idx"]
	var view: EnemyView = _enemy_view(idx)
	var move_key: String = str(ev.get("move", ""))
	var attacking: bool = _move_is_attack(idx, move_key)
	_hit_seq = 0
	# `vfxSource` for the enemy phase: an attack speaks its body's language, a
	# debuff speaks void and a ward speaks ward.
	var kind: String = _foe_kind(idx)
	_archetype = VfxLayer.KIND_ARCHETYPE.get(kind, "slash")
	# `cardId: null` (drain.js:896) — a foe has no signature. Cleared rather than
	# left, or a thorns tick during the enemy phase would throw the hero's last
	# card's effect back at them.
	_vfx_card_id = ""
	_bespoke_fired = false
	var intent: String = _move_intent(idx, move_key)
	if intent == "debuff":
		_archetype = "void"
	elif intent == "buff" or intent == "block":
		_archetype = "ward"
	if view != null:
		view.telegraph()
		_float(_enemy_centre(idx) + Vector2(0.0, -90.0),
			str(ev.get("name", "")), "movef")
	await _wait(0.3)
	if view != null and attacking:
		await _wait(view.lunge(kind))
	else:
		await _wait(0.32)


## `playReshuffleCeremony` (drain.js:132) — the discard walks back into the draw
## pile as a stream of card backs, and the pile answers when they land.
func _reshuffle_ceremony(n: int) -> void:
	if seq.instant:
		return
	_sfx.play(&"card")
	# The same freeze the draw wave uses (drain.js:198): the engine has already
	# moved the discard into the draw pile, so both piles would show the finished
	# state while the backs are still flying between them. Held at what they were
	# — an empty draw pile and a full discard — until the flight lands.
	_pile_override[&"draw"] = 0
	_pile_override[&"discard"] = n
	_push_hud()
	# `Array.from({ length: n })` — one back per card, capped: past eight the
	# stream stops reading as more cards and starts reading as noise.
	_hud.fly_backs(&"discard", &"draw", maxi(1, mini(n, 8)), 0.6)
	await _wait(0.6)
	_pile_override.erase(&"draw")
	_pile_override.erase(&"discard")
	_land_in_pile(&"draw")
	_push_hud()
	_float(_hud.pile_rect(&"draw").get_center() + Vector2(0.0, -46.0),
		SAY_RESHUFFLE, "notice")


# ---------------------------------------------------------------- sync

## Everything the chrome layer shows, in one call. `set_values()` guards on its
## ten ints and returns immediately when none of them moved, so driving this
## from an event handler as well as from the drain-idle sync costs one array
## compare rather than ten label re-shapes.
func _push_hud() -> void:
	var cb: CombatState = game.cb
	if cb == null or _hud == null:
		return
	# `replacePileVisualOverride` (drain.js:192) — the engine is ALREADY post-draw
	# by the time the drain runs, so a pile left to read its own state has emptied
	# before the first card has left it. The override holds the pre-wave count and
	# is walked down one card at a time as they fly (`setPileVisualOverride`,
	# drain.js:252), which is the only way the deck can be seen being dealt from.
	var draw_n: int = _pile_override.get(&"draw", cb.draw.size())
	var discard_n: int = _pile_override.get(&"discard", cb.discard.size())
	_hud.set_values(maxi(0, cb.player.hp), cb.player.max_hp, cb.player.block,
		game.run.player.gold, cb.player.energy, cb.player.energy_max,
		draw_n, discard_n, cb.exhaust.size(), cb.hand.size())
	_hud.set_potions(game.run.player.potions,
		game.run.reveals_all or game.run.reveals.has("phials"))
	# Embers are the number the lantern carries; the rules gate is whether it
	# can be spent at all (docs/hud-handoff.md §3).
	_hud.set_lantern(
		cb.embers,
		_rules.can_use_art(game.run, cb),
		cb.ember_cap,
		cb.art_used_turn == cb.turn)
	# The strip's middle carries the place. The turn rides its dim tail — the
	# benchmark's own bar has no seat for a number it does not show, and the
	# tail is the honest one (assembly-integration-plan.md D3).
	_hud.set_title(_encounter_text, "Turn %d" % cb.turn)


## `!S.busy` guards the hover branch of `updatePreviews`: nothing is previewed
## while the drain is resolving, because the state the preview would be read
## against is mid-change.
func _on_busy_changed(busy: bool) -> void:
	var locked: bool = busy or game.cb == null or game.cb.over
	# `ce.endTurn.classList.add('enemy-phase')` — the guard was already there in
	# `_on_end_turn_pressed`; `set_locked` is the half of it the player can see.
	_kindle_toggle.disabled = locked
	_hand.locked = locked
	_hud.set_locked(locked)
	if locked:
		_aim.clear_aim()
		_hand.cancel_drag()
		_aim_hover = -1
		_clear_previews()
	if not busy:
		_sync_all()
		# The hand the player is now holding is not the one the last preview was
		# read against — the card may have been spent, or the foe may be dead.
		_update_previews()


## "7" or "4×2" from the {"dmg", "times"} preview; "" for non-attacks.
func _fmt_enemy_dmg(preview: Variant) -> String:
	if preview == null:
		return ""
	var p: Dictionary = preview
	var dmg: int = p.get("dmg", 0)
	var times: int = p.get("times", 1)
	return str(dmg) if times <= 1 else "%d×%d" % [dmg, times]


func _refresh_intent(idx: int) -> void:
	var view: EnemyView = _enemy_view(idx)
	if view == null:
		return
	var e: EnemyCombatant = game.cb.enemies[idx]
	if e.hp <= 0:
		return
	var mv: Dictionary = e.move()
	view.set_intent(
		StringName(str(mv.get("intent", ""))),
		_fmt_enemy_dmg(_rules.preview_enemy_dmg(game.cb, e, game.run)),
		str(mv.get("name", String(e.move_key))))


## `syncCombat` (combat.js:1039) — every body's numbers, and nothing else. The
## hand is NOT here, which is the reason this exists apart from `_sync_all`: the
## benchmark restates the bodies twenty-odd times inside a single drain and the
## hand only where a card actually moved.
##
## Without it a status chip, a ward number and a facet count all waited for the
## whole drain to idle, so a foe took three hits and a poison stack while showing
## the readings it had before any of them landed.
func _sync_actors(reap: bool = false) -> void:
	var cb: CombatState = game.cb
	if cb == null:
		return
	_push_hud()
	# The hero reads its own numbers, because the plate that shows them is the
	# hero's — the same markup a foe carries (docs/hud-handoff.md §2).
	if _hero != null:
		_hero.set_hp(maxi(0, cb.player.hp), cb.player.max_hp)
		_hero.set_ward(cb.player.block)
		_restore_ward_shell(_hero, cb.player.block)
		_hero.set_statuses(cb.player.statuses, game.content.statuses)
	for e: EnemyCombatant in cb.enemies:
		var view: EnemyView = _enemy_view(e.idx)
		if view == null:
			continue
		_restore_ward_shell(view, e.block)
		var intent: StringName = &""
		var move_name: String = ""
		var dmg_text: String = ""
		if e.hp > 0 and e.staggered:
			# `if (en.hp > 0 && en.flags.staggered)` (combat.js:1065) — a staggered
			# foe's telegraph is REPLACED, not annotated. It has no move this turn,
			# so showing the one it would have made is a lie about what is coming.
			# The benchmark's `iconSvg('stagger')` has no counterpart in
			# assets/art/ui, so the plate carries the word alone.
			intent = &"staggered"
			dmg_text = SAY_STAGGERED
			move_name = SAY_STAGGERED
		elif e.hp > 0:
			var mv: Dictionary = e.move()
			intent = StringName(str(mv.get("intent", "")))
			move_name = str(mv.get("name", String(e.move_key)))
			dmg_text = _fmt_enemy_dmg(_rules.preview_enemy_dmg(cb, e, game.run))
		view.sync(e, dmg_text, intent, move_name, game.content.statuses, reap)


func _sync_all() -> void:
	var cb: CombatState = game.cb
	if cb == null:
		return
	_sync_actors(true)
	var first_living: int = -1
	for e: EnemyCombatant in cb.enemies:
		if e.hp > 0:
			first_living = e.idx
			break
	# Reconciled, not rebuilt. Adding is idempotent, so a card the drain already
	# dealt keeps the node that is flying it; only what the engine no longer
	# holds is taken out.
	var order: Array[int] = []
	for c: CardInst in cb.hand:
		_hand.add_card(c, _rules.card_data(c), _rules.eff_cost(game.run, cb, c))
		order.append(c.uid)
	_hand.sync_hand(order)
	for c: CardInst in cb.hand:
		var view: CardView = _hand.card_view(c.uid)
		if view == null:
			continue
		var target_probe: Variant = first_living if view.target_kind == "enemy" else null
		view.set_playable(
			_rules.can_play(game.run, cb, c, target_probe)
			or _rules.can_kindle(game.run, cb, c))
	if cb.over and not _over_emitted:
		_over_emitted = true
		# `victoryFlow` / `defeatFlow` (combat.js:2683, 2720) each open with their
		# transition, before anything is torn down — the fight is what the wipe
		# is covering, so it has to still be on screen when it starts.
		combat_over.emit(cb.result)


# ---------------------------------------------------------------- tooltips

## `findTipped` (tooltip.js:49), inverted.
##
## The benchmark walks UP from whatever the pointer is over until it meets a
## node carrying `_tip`. There is nothing to walk up here — a keyword inside a
## card's rules paragraph is a run of glyphs the paragraph drew, not a node — so
## the screen walks DOWN its own chrome instead, in front-to-back paint order,
## and answers with the first tip it finds.
##
## Every sentence is assembled here rather than in the widget that was hit,
## because a widget in `presentation/` does not read content and these are all
## catalogue copy.
func _tip_at(global_pos: Vector2) -> Dictionary:
	if game.cb == null:
		return {}
	# The hand is above everything, and a keyword beats the card that holds it —
	# the benchmark gets the same order for free, because a `.kw` span is a
	# descendant of the `.card` and the walk stops at the first `_tip` it meets.
	var word: String = _hand.keyword_at(global_pos)
	if word != "":
		return _keyword_tip(word)
	# A card that is NOT under a keyword answers nothing, and it stops the walk:
	# the tip must not fall through to whatever body the card happens to be
	# covering. The benchmark hangs `{title: name, body: text}` on a hand card
	# (combat.js:270) and it is redundant there and redundant here — the face
	# already carries both, so the panel restates what the cursor is resting on.
	# Only the glossary earns a tip, because a keyword's meaning is NOT on the
	# card.
	if _hand.card_at(global_pos) >= 0:
		return {}
	if _hud != null and _hud.lantern_rect().has_point(global_pos):
		return _lantern_tip()
	for view: EnemyView in _enemy_views:
		var hit: Array[StringName] = view.tip_zone(global_pos)
		var zone: StringName = hit[0]
		if zone == &"":
			continue
		var tip: Dictionary = {}
		match zone:
			&"status":
				tip = _status_tip(view.idx, hit[1])
			&"intent":
				tip = _intent_tip(view.idx)
			&"facets":
				tip = {"title": TIP_FACETS_TITLE, "body": TIP_FACETS_BODY}
			&"name":
				tip = _affix_tip(view.idx)
		# A zone that resolves to nothing is not a stop. A common foe's name
		# line carries no `_tip` in the benchmark at all, so the walk keeps
		# going rather than answering "nothing is tipped here".
		if not tip.is_empty():
			return tip
	if _hero != null:
		var hero_hit: Array[StringName] = _hero.tip_zone(global_pos)
		if hero_hit[0] == &"status":
			return _status_tip(-1, hero_hit[1])
	return {}


## `keywordLegend`'s glossary (tooltip.js:14). Six of the twenty-one read their
## body out of the status catalogue so retuning a status retunes its keyword.
func _keyword_tip(word: String) -> Dictionary:
	var status_id: String = str(RulesText.KEYWORD_STATUS.get(word, ""))
	if status_id != "":
		var info: Dictionary = game.content.statuses.get(status_id, {})
		return {"title": word, "body": str(info.get("desc", ""))}
	return {"title": word, "body": str(RulesText.KEYWORD_TEXT.get(word, ""))}


## `intentFor` (combat.js:997). The chip shows a number; the tip spells out
## everything the move intends, in the order the benchmark lists it.
func _intent_tip(idx: int) -> Dictionary:
	if idx < 0 or idx >= game.cb.enemies.size():
		return {}
	var e: EnemyCombatant = game.cb.enemies[idx]
	if e.staggered:
		return {"title": TIP_STAGGERED_TITLE, "body": TIP_STAGGERED_BODY}
	var mv: Dictionary = e.move()
	var bits: PackedStringArray = PackedStringArray()
	var preview: Variant = _rules.preview_enemy_dmg(game.cb, e, game.run)
	if preview != null:
		var pv: Dictionary = preview
		var dmg: int = pv.get("dmg", 0)
		var times: int = pv.get("times", 1)
		var figure: String = "%d×%d" % [dmg, times] if times > 1 else str(dmg)
		bits.append("attack for [b]%s[/b]" % figure)
	var block_n: int = mv.get("block", 0)
	if block_n > 0:
		bits.append("gain Ward")
	var heal_n: int = mv.get("heal", 0)
	if heal_n > 0:
		bits.append("heal itself")
	var fx: Array = mv.get("fx", [])
	var on_player: bool = false
	var on_self: bool = false
	for f_v: Variant in fx:
		var f: Dictionary = f_v
		if str(f.get("who", "")) == "player":
			on_player = true
		else:
			on_self = true
	if on_player:
		bits.append("afflict you")
	if on_self:
		bits.append("empower")
	var what: String = ", ".join(bits) if bits.size() > 0 else "act"
	return {"title": str(mv.get("name", String(e.move_key))),
		"body": "Intends to %s." % what}


## `statusChips` (combat.js:993). `N` in the catalogue body stands for the
## magnitude the chip is actually carrying, so the sentence reads as this
## creature's condition rather than as a rule.
func _status_tip(idx: int, id: StringName) -> Dictionary:
	var statuses: Dictionary = game.cb.player.statuses if idx < 0 \
		else game.cb.enemies[idx].statuses
	var n: int = statuses.get(String(id), 0)
	var info: Dictionary = game.content.statuses.get(String(id), {})
	var kind: String = str(info.get("kind", "buff"))
	if String(id) == "str" and n < 0:
		kind = "debuff"
	var body: String = str(info.get("desc", "")).replace("N", str(absi(n)))
	return {"title": str(info.get("name", String(id))), "body": body,
		"sub": TIP_DEBUFF if kind == "debuff" else TIP_BUFF}


## `if (afx) $('.name', box)._tip = ...` (combat.js:622). The title belongs to
## the ENCOUNTER, not to the creature — `startCombat` rolls one affix and hangs
## it on every name line in the fight, elite or not, because it is what the
## whole fight is wearing.
func _affix_tip(idx: int) -> Dictionary:
	if idx < 0 or idx >= game.cb.enemies.size():
		return {}
	var affix_id: String = str(game.cb.affix)
	if affix_id.is_empty():
		return {}
	var affix: Dictionary = game.content.affixes.get(affix_id, {})
	if affix.is_empty():
		return {}
	return {"title": TIP_AFFIX_TITLE % str(affix.get("name", affix_id)),
		"body": str(affix.get("text", ""))}


## `ce.lantern._tip` (combat.js:644). The art's own rule leads, then what the
## lantern is for.
func _lantern_tip() -> Dictionary:
	var art_id: String = str(game.run.art)
	var art: Dictionary = game.content.arts.get(art_id, {})
	if art.is_empty():
		return {"title": TIP_LANTERN_TITLE, "body": TIP_LANTERN_BODY,
			"sub": TIP_LANTERN_SUB}
	var art_cost: int = art.get("cost", 0)
	var lead: String = TIP_LANTERN_LEAD % [art_cost, str(art.get("text", ""))]
	return {"title": TIP_LANTERN_ART_TITLE % str(art.get("name", art_id)),
		"body": lead + TIP_LANTERN_BODY, "sub": TIP_LANTERN_SUB}


## A touchscreen has no hover, so the benchmark gives it a 380ms long press
## instead (`pointerdown` → `setTimeout(..., 380)`, tooltip.js:104). The screen
## forwards the gesture because the tooltip layer is deliberately pointer-inert
## and would never see it.
func _input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if _inspector != null and _inspector.visible:
		if key != null and key.pressed and not key.echo:
			if key.keycode == KEY_ESCAPE:
				_close_inspector()
			get_viewport().set_input_as_handled()
		return
	if key != null and key.pressed and not key.echo:
		if _combat_key(key.keycode):
			get_viewport().set_input_as_handled()
		return
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			_tips.press(touch.position)
			_stage_pressed(touch.position)
		else:
			_tips.release()
		return
	var drag: InputEventScreenDrag = event as InputEventScreenDrag
	if drag != null:
		_tips.press_moved(drag.position)
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		# `aimMove` runs on every stage pointermove with no gesture live: an armed
		# card's arc reaches the CURSOR, not the foe under it, so a shot lining up
		# between two bodies still looks aimed somewhere.
		_aim_move(motion.position)
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_stage_pressed(mb.position)


## `onEnemyClick` (combat.js:1694) and `tapBackground` (combat.js:1372), which are
## only ever heard while a card is armed — nothing else on this screen answers a
## bare press on the stage.
func _stage_pressed(at: Vector2) -> void:
	# A press that landed on a card or a foe is that thing's, never the
	# background's — the benchmark's own first line, and it guards BOTH branches
	# below rather than only the targeting one.
	if _hand.card_at(at) >= 0:
		return
	if not _targeting:
		# The other half of the same handler, and this port had none of it: with
		# nothing armed, pressing the stage sets a lifted card back down. On a
		# touchscreen the first tap on a card lifts it to be read, so without
		# this there is no way to put it down again except by playing it.
		if _hand.hovered_uid >= 0:
			# `drop_seat` rather than a new lowering call: nothing is armed on
			# this branch, so clearing `armed_uid` alongside the hover is a
			# no-op, and `hand_view.gd` belongs to another lane.
			_hand.drop_seat()
			_update_previews()
			get_viewport().set_input_as_handled()
		return
	var idx: int = _enemy_at(at)
	if idx >= 0:
		_commit_selected(idx)
		get_viewport().set_input_as_handled()
		return
	# `!event.target?.closest?.('... button, a, input, textarea, [data-act]')` —
	# chrome is not background, or ending the turn would first disarm the card and
	# the press would be spent doing nothing visible.
	if get_viewport().gui_get_hovered_control() is BaseButton:
		return
	_cancel_targeting()
	get_viewport().set_input_as_handled()


func _aim_move(at: Vector2) -> void:
	if not _targeting or _selected_uid < 0:
		return
	_aim.draw_between(_hand.seat_centre(_selected_uid), at)
	# The lantern leans on the pointer, not on the foe: it follows across empty
	# stage too, which is what makes aiming feel like turning a light.
	_aim_at = at
	_has_aim_at = true
	# `enemyHover` (combat.js:1493) — the aimed foe changes only when the pointer
	# crosses a body, not on every pixel it travels.
	var idx: int = _enemy_at(at)
	if idx == _aim_hover:
		return
	_aim_hover = idx
	_update_previews()


# ---------------------------------------------------------------- previews

## `updatePreviews` (combat.js:1606) — the consequence, spelled out.
##
## While a card is hovered, armed or being dragged, every foe it could touch
## shows exactly what it would lose: an aim rim on the bodies the card would
## reach, a bright segment on the rail where the damage would land, the facet
## panes it would take, and — when the number is lethal — the seams lit.
##
## Which foes light up is not "the ones it could hit". Three rules, and the
## middle one is the whole reason this is not a one-liner:
##   - `allEnemies` reaches every living foe while INSPECTING (hovered, not yet
##     armed) or while being carried loose
##   - a single-target card reaches the lone survivor, or — once aiming — only
##     the foe under the pointer, never all of them just because one was hovered
##   - a foe that is a legal target but not the one aimed at is DIMMED: it keeps
##     its rail preview and loses the death-mark and the shatter ring, so a
##     three-foe lineup cannot claim three kills at once
func _update_previews() -> void:
	if game.cb == null or _hand == null:
		return
	# `S.targeting ?? S.drag ?? S.hoveredCard` — an armed card outranks a
	# dragged one, and a dragged one outranks whatever the cursor is merely
	# resting on.
	var uid: int = _selected_uid if _targeting else -1
	if uid < 0:
		uid = _hand.dragged_uid()
	if uid < 0 and not seq.is_busy():
		uid = _hand.hovered_uid
	var inst: CardInst = _find_card(uid) if uid >= 0 else null
	if inst == null or game.cb.over:
		_clear_previews()
		return
	var d: Dictionary = _rules.card_data(inst)
	var unplayable: bool = d.get("unplayable", false)
	if unplayable:
		_clear_previews()
		return
	var target: String = str(d.get("target", ""))
	# Armed by a click and armed by a drag are the same posture: the card has been
	# committed to and is now looking for something to land on.
	var aiming: bool = _targeting or _hand.is_aiming()
	var inspect: bool = not aiming
	var living: int = 0
	for e: EnemyCombatant in game.cb.enemies:
		if e.hp > 0:
			living += 1
	var aimed: int = _aim_target()

	# `heroOn = inspect && d.target === 'self'` — a card that acts on you shows
	# it on you, and only while it is being read rather than thrown.
	if _hero != null:
		_hero.set_targetable(inspect and target == "self")

	for view: EnemyView in _enemy_views:
		var i: int = view.idx
		if i >= game.cb.enemies.size():
			continue
		var en: EnemyCombatant = game.cb.enemies[i]
		if en.hp <= 0:
			view.set_targetable(false)
			view.clear_preview()
			continue
		var hovered: bool = i == aimed
		var aim_all: bool = target == "allEnemies" and (inspect or _hand.is_free_drag())
		# `targetable` goes on EVERY legal foe while a single-target card is
		# armed (combat.js:1199-1257) — the pulse is how the player learns the
		# card has options. The hovered one alone gets `.target-hover`.
		var aim_one: bool = target == "enemy" and (aiming or living == 1)
		view.set_targetable(aim_all or aim_one, aiming and hovered)

		var preview: Variant = null
		var dim: bool = false
		if target == "allEnemies":
			preview = _rules.preview_play(game.cb, inst, i, game.run)
		elif target == "enemy" and (aiming or living == 1):
			preview = _rules.preview_play(game.cb, inst, i, game.run)
			dim = aiming and living > 1 and not hovered
		if preview == null:
			view.clear_preview()
			continue
		var pv: Dictionary = preview
		var total: int = pv.get("total", 0)
		var chips: int = pv.get("chips", 0)
		if total <= 0 and chips <= 0:
			view.clear_preview()
			continue
		var loss: int = pv.get("loss", 0)
		var lethal: bool = pv.get("lethal", false)
		var will_shatter: bool = pv.get("willShatter", false)
		view.set_preview(loss, lethal and not dim)
		view.set_facet_ghost(0 if dim else chips, will_shatter and not dim)


func _clear_previews() -> void:
	if _hero != null:
		_hero.set_targetable(false)
	for view: EnemyView in _enemy_views:
		view.set_targetable(false)
		view.clear_preview()


## Which foe the aim is resting on. `x.root.classList.contains('target-hover')`,
## and the important half is what it says when the answer is NOTHING: an armed
## card with the pointer resting between two foes marks neither, and both stay
## dimmed. A fallback to "the first survivor" would claim a kill the player has
## not aimed at yet. The keyboard seeds this itself, which is what
## `S.selectedEnemyIndex` is for.
func _aim_target() -> int:
	return _aim_hover


# ---------------------------------------------------------------- keyboard

## `handleCombatKey` (combat.js:1741). The whole fight is playable without a
## pointer, and every branch below is one of the benchmark's — including which
## keys are refused and when.
##
## E and A answer even mid-animation guard (they check `S.busy` themselves and
## are no-ops when it is set); everything after the busy gate does not.
func _combat_key(key: Key) -> bool:
	if game.cb == null or game.cb.over:
		return false
	if key == KEY_ESCAPE:
		if _hand.dragged_uid() >= 0 or _selected_uid >= 0:
			_cancel_targeting()
			return true
		return false
	if key == KEY_E:
		_on_end_turn_pressed()
		return true
	if key == KEY_A:
		_on_art_pressed()
		return true
	if seq.is_busy():
		return false

	var hand: Array[int] = _hand.uids()
	var living: Array[int] = []
	for e: EnemyCombatant in game.cb.enemies:
		if e.hp > 0:
			living.append(e.idx)
	# `targetingMulti` — cycling foes only means anything once a card is armed
	# AND there is more than one thing to choose between.
	var aiming_multi: bool = _selected_uid >= 0 and _targeting and living.size() > 1

	if aiming_multi and (key == KEY_UP or key == KEY_DOWN):
		var at: int = living.find(_aim_hover)
		if at < 0:
			at = 0
		elif key == KEY_UP:
			at = (at - 1 + living.size()) % living.size()
		else:
			at = (at + 1) % living.size()
		_aim_hover = living[at]
		_aim.draw_between(_hand.seat_centre(_selected_uid),
			_enemy_centre(_aim_hover))
		_update_previews()
		return true

	if aiming_multi and (key == KEY_ENTER or key == KEY_KP_ENTER or key == KEY_SPACE):
		if _aim_hover >= 0:
			_commit_selected(_aim_hover)
		return true

	if key == KEY_LEFT or key == KEY_RIGHT:
		if hand.is_empty():
			return true
		var at: int = hand.find(_selected_uid)
		if at < 0:
			at = 0
		elif key == KEY_LEFT:
			at = (at - 1 + hand.size()) % hand.size()
		else:
			at = (at + 1) % hand.size()
		_select_card(hand[at])
		return true

	if key == KEY_ENTER or key == KEY_KP_ENTER or key == KEY_SPACE:
		# A card already armed against a fight with one survivor commits without
		# ever asking which one.
		if _selected_uid >= 0 and _targeting and living.size() <= 1:
			if not living.is_empty():
				_commit_selected(living[0])
			return true
		if _selected_uid < 0 and not hand.is_empty():
			_select_card(hand[0])
			return true
		if _selected_uid < 0:
			return true
		_activate_selected()
		return true
	return false


## `S.selectedCardUid` — the keyboard's cursor through the fan. It also sets
## the hover, which is what makes the previews follow it.
func _select_card(uid: int) -> void:
	_selected_uid = uid
	_hand.hovered_uid = uid
	_hand.raise_seat(uid)
	_sfx.play(&"hover")
	_update_previews()


## `onCardClick` (combat.js:1667) reached from the keyboard: a card that needs
## a target ARMS rather than plays, unless there is only one thing to hit.
func _activate_selected() -> void:
	var inst: CardInst = _find_card(_selected_uid)
	if inst == null:
		return
	var d: Dictionary = _rules.card_data(inst)
	var unplayable: bool = d.get("unplayable", false)
	if unplayable or _rules.eff_cost(game.run, game.cb, inst) > game.cb.player.energy:
		_sfx.play(&"debuff")
		return
	if str(d.get("target", "")) == "enemy":
		var living: Array[int] = []
		for e: EnemyCombatant in game.cb.enemies:
			if e.hp > 0:
				living.append(e.idx)
		if living.size() == 1:
			_commit_selected(living[0])
			return
		# `setTargeting` (combat.js:1702): every living foe is marked choosable, and
		# `S.selectedEnemyIndex` opens on the first survivor so the keyboard has
		# somewhere to start cycling from. The arc opens onto that foe, and the
		# pointer takes it over from the next mouse move.
		_targeting = true
		_aim_hover = living[0] if not living.is_empty() else -1
		_hand.arm_seat(_selected_uid)
		if _aim_hover >= 0:
			_aim.draw_between(_hand.seat_centre(_selected_uid),
				_enemy_centre(_aim_hover))
		_update_previews()
		return
	_commit_selected(-1)


func _commit_selected(target_idx: int) -> void:
	var uid: int = _selected_uid
	_cancel_targeting()
	if uid >= 0:
		request_play(uid, null if target_idx < 0 else target_idx)


func _cancel_targeting() -> void:
	_targeting = false
	_selected_uid = -1
	_aim_hover = -1
	# `updateLantern()` at the tail of `cancelTargeting` — hand the light back.
	_has_aim_at = false
	_aim.clear_aim()
	_hand.hovered_uid = -1
	_hand.drop_seat()
	_update_previews()
