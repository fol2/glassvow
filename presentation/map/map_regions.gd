class_name MapRegions
extends RefCounted
## Sole per-act palette for the pilgrimage map (#234 slice 4). `for_act`
## ignores the content pack's per-act theme dict — the 3D ramp owns hue.
## Tuning act 1's shafts must not move act 0's ash (docs/solutions/conventions/
## per-recipe-shader-knobs.md: one recipe's knobs stay off the shared model).

## 2D band sky/fog/weather. Length 3 until slice 6 authors Act IV's row;
## `for_act` clamps these separately from the 4-row ramp. Hexes match the
## shipping pack so the live `WorldMapScreen` bands do not jump this slice.
const FALLBACK_SKIES: Array[Color] = [
	Color("#0c1410"), Color("#081420"), Color("#120a1e")]
const FALLBACK_FOGS: Array[Color] = [
	Color("#13241a"), Color("#0d2233"), Color("#1e1230")]
const FALLBACK_PARTICLES: Array[Color] = [
	Color("#ffa04d"), Color("#53e8ff"), Color("#c27bff")]
const FALLBACK_GLOWS: Array[Color] = [
	Color("#66ff9e"), Color("#2fb8ff"), Color("#ff4fd8")]
const FALLBACK_ACCENTS: Array[Color] = [
	Color("#7ddb8f"), Color("#5fd6e8"), Color("#c99aff")]

const WEATHER_BY_ACT: Array[StringName] = [&"ash", &"sunken", &"storm"]

## Light arc (#207 decision 11): dusk → night → storm → dawn. Written onto
## ramp `band_shade` / `band_key` only — never albedo, never `surface_tex`.
## Act 0 (1-based act1 plates) takes the crimson forest-floor of
## `assets/art/stage/act1-backdrop.png` plus the amber window as key.
const BAND_SHADE: Array[Color] = [
	Color(0.22, 0.08, 0.15), Color(0.06, 0.10, 0.24),
	Color(0.10, 0.05, 0.18), Color(0.22, 0.19, 0.12)]
const BAND_KEY: Array[Color] = [
	Color(0.96, 0.68, 0.42), Color(0.70, 0.86, 0.96),
	Color(0.88, 0.72, 0.96), Color(0.96, 0.82, 0.70)]
## Grade surround hues. Journey 0→1 is `lerpf(near, far)` — same axis as
## the proxy's 0.71→0.61 cool. Corridor hues stay on the same wheel-arc
## as the surround so lerps cannot cross green on the crimson wrap.
const GRADE_HUE_NEAR: Array[float] = [0.95, 0.62, 0.78, 0.08]
const GRADE_HUE_FAR: Array[float] = [0.88, 0.55, 0.70, 0.12]
const GRADE_HUE_CORRIDOR: Array[float] = [0.98, 0.50, 0.62, 0.10]

## Spire nearness by act — the §1 goal-anchor grows as the pilgrimage closes.
## One size and one tone at every act was PR #71 DL R2's carried note ("neither
## small nor pale nor act-varying"). Act 2 restates the wedge that shipped in
## P5.2; acts 0–1 get the distance they never had.
##   W_RATE  base width as a fraction of the stage
##   H_RATE  apex reach across the horizon→frame-top span (>1.0 = past the edge)
##   DARKEN  how deep the near silhouette cuts below the sky
##   HAZE    how far the FAR silhouette lifts toward the fog
## The tone inverts along the journey, which is the whole point: against a
## near-black sky a distant object cannot read by getting darker — atmospheric
## scatter lifts it toward the fog, and only the near tower is a true cut-out.
## Darkening alone gave act 0 a 3–5 level delta, i.e. an invisible goal-anchor.
##
## HAZE[0] is set against the COMPOSITED sky, not the theme constant: the fog
## disc already lifts the wedge's own rows before the spire draws, so a haze
## tuned against `sky` cancels against itself and lands +4 on screen where the
## arithmetic promised +23 (PR #77 DL R1). H_RATE[2] runs past 1.0 on purpose —
## a crown cropped by eight pixels reads as a mistake, one cropped by a hundred
## reads as a wall of tower leaving the frame.
const SPIRE_W_RATE: Array[float] = [0.05, 0.14, 0.50]
const SPIRE_H_RATE: Array[float] = [0.30, 0.65, 1.35]
const SPIRE_DARKEN: Array[float] = [0.00, 0.30, 0.58]
const SPIRE_HAZE: Array[float] = [0.42, 0.14, 0.00]
## tan of the silhouette's half-angle from vertical. A tower is near-vertical
## converging edges; past ~15° it is a mountain. See `MapBand.SkyBand._draw_spire`.
##
## Held EXACTLY at 13° wherever the taper floor does not bind — which is not
## everywhere, and the earlier draft of this line claiming "every act and every
## stage" was wrong (PR #77 DL R2). The floor binds where the stage is narrow
## against its own height, i.e. on both portrait shapes, in 5 of the 15
## shape × act combinations:
##
##     phone-portrait  390x844   acts 0, 1, 2   floored
##     pad-portrait    820x1180  acts 0, 1      floored
##     the three landscape shapes                clear at every act
##
## Every floored case comes out MORE vertical, never less (phone-portrait act 2
## measures 12.0°), so the design intent survives — but the invariant is "≤13°",
## not "=13°". Note also that pad-landscape act 0 clears the floor by only ~8% of
## its base width: a small `SPIRE_W_RATE[0]` tweak would tip the identity shape
## into the floored branch without anything announcing it.
const SPIRE_SLANT: float = 0.2309   # tan(13°)

## Act-2 heat lightning: irregular enough to read as weather, fixed so two
## captures of one build still match. No RNG — marks only.
const LIGHTNING_MARKS: Array[float] = [3.2, 7.9, 9.4, 14.6, 18.1, 23.0]
const LIGHTNING_PERIOD: float = 26.0
const LIGHTNING_TONE: Color = Color("#bfd4ff")
## Combat sky's own decay (presentation/combat/sky_field.gd LIGHTNING_DECAY).
const LIGHTNING_DECAY: float = 0.008

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
## measured, they carried **16× less**, because the same commit that halved the
## count also changed the primitive and dimmed it. The count stays a per-region
## seam; it is simply not a lever any act needs pulled today (#69 C3).
var particle_count: int = 128


## `_content` is accepted so `WorldMapScreen` keeps its call shape. It is not
## read: palette truth lives in the constants above (#234, #207).
static func for_act(act_i: int, _content: ContentDB = null) -> MapRegions:
	var cfg: MapRegions = MapRegions.new()
	var index: int = clampi(act_i, 0, BAND_SHADE.size() - 1)
	var tone: int = clampi(index, 0, FALLBACK_SKIES.size() - 1)
	cfg.act = index
	cfg.weather = WEATHER_BY_ACT[tone]
	cfg.sky = FALLBACK_SKIES[tone]
	cfg.fog = FALLBACK_FOGS[tone]
	cfg.particles = FALLBACK_PARTICLES[tone]
	cfg.glow = FALLBACK_GLOWS[tone]
	cfg.accent = FALLBACK_ACCENTS[tone]
	cfg.band_shade = BAND_SHADE[index]
	cfg.band_key = BAND_KEY[index]
	cfg.grade_hue_far = GRADE_HUE_FAR[index]
	cfg.grade_hue_near = GRADE_HUE_NEAR[index]
	cfg.grade_hue_corridor = GRADE_HUE_CORRIDOR[index]
	return cfg
