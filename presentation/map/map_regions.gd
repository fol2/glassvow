class_name MapRegions
extends RefCounted
## Sole per-act palette for the pilgrimage map (#234 slice 4). `for_act`
## ignores the content pack's per-act theme dict — the 3D ramp owns hue.
## Tuning act 1's sunken motes must not move act 0's ash (docs/solutions/
## conventions/per-recipe-shader-knobs.md: one recipe's knobs stay off the
## shared model). Vertical ramp constants retired in #234 slice 7b2 (#207/#232).

## Per-act sky/fog/weather dress. Rows 0–2 keep the shipping-pack hexes so
## the veil palette does not jump; row 3 is Act IV's dawn-arc (residual
## umber shade, rose-gold key — same wheel as `BAND_SHADE`/`BAND_KEY`[3]).
const FALLBACK_SKIES: Array[Color] = [
	Color("#0c1410"), Color("#081420"), Color("#120a1e"), Color("#16120c")]
const FALLBACK_FOGS: Array[Color] = [
	Color("#13241a"), Color("#0d2233"), Color("#1e1230"), Color("#241e14")]
const FALLBACK_PARTICLES: Array[Color] = [
	Color("#ffa04d"), Color("#53e8ff"), Color("#c27bff"), Color("#ffc08a")]
const FALLBACK_GLOWS: Array[Color] = [
	Color("#66ff9e"), Color("#2fb8ff"), Color("#ff4fd8"), Color("#f0a878")]
const FALLBACK_ACCENTS: Array[Color] = [
	Color("#7ddb8f"), Color("#5fd6e8"), Color("#c99aff"), Color("#e8b890")]

const WEATHER_BY_ACT: Array[StringName] = [&"ash", &"sunken", &"storm", &"dawn"]

## Light arc (#207 decision 11): dusk → night → storm → dawn. Written onto
## ramp `band_shade` / `band_key` only — never albedo, never `surface_tex`.
## Act 0 (1-based act1 plates) takes the crimson forest-floor of
## `assets/art/stage/act1-backdrop.png` plus the amber window as key.
## Act 0 moved to night glass (#156 direction B). Hue on the key is close to
## free: the value-gap gate only fails at <= 0, and what actually decides
## whether a prop reads against the ground is the KEY'S LUMINANCE, because a
## prop is the ground times PROP_VALUE / GROUND_VALUE. Measured under REC709,
## the retired amber (0.96, 0.68, 0.42) carries luma 0.505 and a ground-to-prop
## separation of 0.249; this glass-blue carries 0.438 and 0.235. A whole hue
## rotation costs 0.014 of separation. Dropping the key to a true dark instead
## -- say (0.34, 0.44, 0.62), luma 0.161 -- would have cost 0.094, most of the
## separation the props have.
##
## So the darkness does not come from here. It comes from the GRADE, which
## multiplies per world position and can take the land away from the road down
## to night while the key stays bright enough to keep the props legible. That
## is the division map_ground.gdshader already documents: the ramp ends carry
## the act's tint, the grade carries the spatial work.
const BAND_SHADE: Array[Color] = [
	Color(0.05, 0.09, 0.18), Color(0.06, 0.10, 0.24),
	Color(0.10, 0.05, 0.18), Color(0.22, 0.19, 0.12)]
const BAND_KEY: Array[Color] = [
	Color(0.56, 0.70, 0.92), Color(0.70, 0.86, 0.96),
	Color(0.88, 0.72, 0.96), Color(0.96, 0.82, 0.70)]
## Grade surround hues. Journey 0→1 is `lerpf(near, far)` — same axis as
## the proxy's 0.71→0.61 cool. Corridor hues stay on the same wheel-arc
## as the surround so lerps cannot cross green on the crimson wrap.
const GRADE_HUE_NEAR: Array[float] = [0.95, 0.62, 0.78, 0.08]
const GRADE_HUE_FAR: Array[float] = [0.88, 0.55, 0.70, 0.12]
const GRADE_HUE_CORRIDOR: Array[float] = [0.98, 0.50, 0.62, 0.10]

## Act-2 heat lightning (`LIGHTNING_*`, `set_flash`, `_step_lightning`) retired
## with the sky/region bands in #234 slice 7b2 — deliberate, no 3D successor
## in this slice. Combat sky keeps its own lightning in `sky_field.gd`.

var act: int = 0
var sky: Color = FALLBACK_SKIES[0]
var fog: Color = FALLBACK_FOGS[0]
var particles: Color = FALLBACK_PARTICLES[0]
var glow: Color = FALLBACK_GLOWS[0]
var accent: Color = FALLBACK_ACCENTS[0]
var band_shade: Color = BAND_SHADE[0]
var band_key: Color = BAND_KEY[0]
var grade_hue_far: float = GRADE_HUE_FAR[0]
var grade_hue_near: float = GRADE_HUE_NEAR[0]
var grade_hue_corridor: float = GRADE_HUE_CORRIDOR[0]
var weather: StringName = &"ash"
## How many of the veil's scattered motes this region DRAWS. The scatter itself
## stays the full deterministic 128 so switching acts never reshuffles it.
##
## Every act now draws all 128. Storm used to halve it, under a docstring
## claiming "64 hard streaks already carry more luminance than 128 soft discs" —
## The per-region particle count died with VeilBand in #156 round 2. Its long
## history — halved in #69, and measured at 16× less carry than the halving
## alone implied because the same commit changed the primitive and dimmed it —
## is kept here only so a future weather pass does not rediscover it the hard way.


## `_content` is accepted so `WorldMapScreen` keeps its call shape. It is not
## read: palette truth lives in the constants above (#234, #207).
static func for_act(act_i: int, _content: ContentDB = null) -> MapRegions:
	var cfg: MapRegions = MapRegions.new()
	var index: int = clampi(act_i, 0, BAND_SHADE.size() - 1)
	cfg.act = index
	cfg.weather = WEATHER_BY_ACT[index]
	cfg.sky = FALLBACK_SKIES[index]
	cfg.fog = FALLBACK_FOGS[index]
	cfg.particles = FALLBACK_PARTICLES[index]
	cfg.glow = FALLBACK_GLOWS[index]
	cfg.accent = FALLBACK_ACCENTS[index]
	cfg.band_shade = BAND_SHADE[index]
	cfg.band_key = BAND_KEY[index]
	cfg.grade_hue_far = GRADE_HUE_FAR[index]
	cfg.grade_hue_near = GRADE_HUE_NEAR[index]
	cfg.grade_hue_corridor = GRADE_HUE_CORRIDOR[index]
	return cfg
