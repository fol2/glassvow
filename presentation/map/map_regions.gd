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
## How many of the veil's scattered motes this region DRAWS. The scatter
## itself stays the full deterministic 128 so switching acts never reshuffles
## it — storm halves the visible field because 64 hard streaks already carry
## more luminance than 128 soft discs (PR #75 DL R1).
var particle_count: int = 128


static func for_act(act_i: int, content: ContentDB) -> MapRegions:
	var cfg: MapRegions = MapRegions.new()
	var index: int = clampi(act_i, 0, FALLBACK_SKIES.size() - 1)
	cfg.act = index
	cfg.weather = WEATHER_BY_ACT[index]
	if cfg.weather == &"storm":
		cfg.particle_count = 64
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
