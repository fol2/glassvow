class_name MapRegions
extends RefCounted
## Per-act region config for the pilgrimage map. Built once per theme pick —
## tuning act 1's shafts must not move act 0's ash (docs/solutions/conventions/
## per-recipe-shader-knobs.md: one recipe's knobs stay off the shared model).

## Documented fallback when `content.acts[i].theme` lacks a key. Content ints
## are truth for the shipping pack; these mirror the same hexes so a missing
## key still paints a coherent region rather than black.
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


static func for_act(act_i: int, content: ContentDB) -> MapRegions:
	var cfg: MapRegions = MapRegions.new()
	var index: int = clampi(act_i, 0, FALLBACK_SKIES.size() - 1)
	cfg.act = index
	cfg.weather = WEATHER_BY_ACT[index]
	cfg.sky = FALLBACK_SKIES[index]
	cfg.fog = FALLBACK_FOGS[index]
	cfg.particles = FALLBACK_PARTICLES[index]
	cfg.glow = FALLBACK_GLOWS[index]
	cfg.accent = FALLBACK_ACCENTS[index]
	if content == null or index >= content.acts.size():
		return cfg
	var act_v: Variant = content.acts[index]
	if typeof(act_v) != TYPE_DICTIONARY:
		return cfg
	var act_dict: Dictionary = act_v
	var theme_v: Variant = act_dict.get("theme", {})
	if typeof(theme_v) != TYPE_DICTIONARY:
		return cfg
	var theme: Dictionary = theme_v
	cfg.sky = _theme_colour(theme, "sky", cfg.sky)
	cfg.fog = _theme_colour(theme, "fog", cfg.fog)
	cfg.particles = _theme_colour(theme, "particles", cfg.particles)
	cfg.glow = _theme_colour(theme, "glow", cfg.glow)
	cfg.accent = _theme_colour(theme, "accent", cfg.accent)
	return cfg


## Content stores 24-bit RGB ints (or "#…" strings for accent/ember). Same
## `<< 8 | 0xff` widening Color.hex expects; strings go through Color().
static func _theme_colour(theme: Dictionary, key: String, fallback: Color) -> Color:
	if not theme.has(key):
		return fallback
	var v: Variant = theme[key]
	if typeof(v) == TYPE_STRING:
		var s: String = str(v)
		return Color(s) if s.begins_with("#") else fallback
	if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT:
		return fallback
	# Typed assign from Dictionary.get — same idiom as waystone hue (int()
	# on a Variant is an unsafe cast under warnings-as-errors).
	var rgb: int = theme.get(key, 0)
	return Color.hex((rgb << 8) | 0xff)
