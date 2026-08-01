class_name MapStrip
extends RefCounted
## Resolves and tiles the pilgrimage map's painted strips. Art is optional by
## construction: P5.6 ships the wiring, P5.8 ships the pngs, and a missing file
## falls back to the band's procedural draw rather than to empty stage.

const DIR: String = "res://assets/art/map"
## Draw-call ceiling per band per frame — see `draw_tiled`.
const MAX_TILES: int = 16

## ART CONTRACT for P5.8. Strips are ATMOSPHERE, never architecture:
##
## * `act{N}-skyband.png` — cloud, haze, star field. **No Spire.** The §1 goal
##   anchor is a single screen-anchored object drawn on top of this strip by
##   `MapBand.SkyBand._draw_spire`; a tiling backdrop lays two copies on a wide
##   stage and a lone constant anchor cannot survive being repeated.
## * `act{N}-region.png` — the far skyline silhouette. Loop-safe left/right
##   edges, and **transparent below its skyline**: the strip is stretched over
##   the whole ground rect, and act 1's caustic shafts now draw in front of it.
##
## Both are height-fitted, and the two bands have different rect heights — sky is
## `horizonY` of the stage (≈303 px at 1180×820), region is the remainder
## (≈533 px). Author to those proportions, not to a shared canvas size, or a tree
## and a cloud will disagree about scale (PR #77 DL R1 m6).

## One disk probe and one warning per (act, kind) for the process lifetime. A
## band repaints every frame the camera moves; a per-draw `ResourceLoader.exists`
## would hit the filesystem as fast as the map scrolls, and a per-draw
## `push_warning` would bury the log it is meant to be read from.
static var _cache: Dictionary[String, Texture2D] = {}


## Acts are 1-based in asset filenames (`act1-…`) and 0-based in code, matching
## how content.acts is indexed. The test pins this so the two never drift.
static func path_for(act: int, kind: StringName) -> String:
	return "%s/act%d-%s.png" % [DIR, act + 1, kind]


static func fetch(act: int, kind: StringName) -> Texture2D:
	var key: String = path_for(act, kind)
	if _cache.has(key):
		return _cache[key]
	var tex: Texture2D = null
	if ResourceLoader.exists(key):
		tex = load(key) as Texture2D
		if tex == null:
			push_warning("MapStrip: %s exists but is not a Texture2D" % key)
	else:
		push_warning("MapStrip: %s absent — act %d %s uses the procedural draw"
			% [key, act, kind])
	_cache[key] = tex
	return tex


## Repeats `tex` across `rect`, height-fitted, scrolled by `offset_x` so the
## strip travels at its band's parallax factor and wraps seamlessly. The art
## contract (P5.8) is loop-safe left/right edges; a strip narrower than the
## stage simply repeats more times.
static func draw_tiled(ci: CanvasItem, tex: Texture2D, rect: Rect2,
		offset_x: float, tint: Color) -> void:
	if tex == null or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var tex_h: float = maxf(float(tex.get_height()), 1.0)
	var draw_w: float = float(tex.get_width()) * (rect.size.y / tex_h)
	if draw_w <= 0.0:
		return
	var x: float = rect.position.x - fposmod(offset_x, draw_w)
	var end_x: float = rect.position.x + rect.size.x
	# Bounded so a mis-authored asset degrades into a visible gap instead of a
	# frame-rate collapse: a 4px-wide strip on a 1440px stage would otherwise
	# issue 360 draw calls per band per frame, and the band redraws on camera
	# movement. Real strips are 2048–3072 wide, i.e. one or two tiles.
	var drawn: int = 0
	while x < end_x and drawn < MAX_TILES:
		ci.draw_texture_rect(tex,
			Rect2(Vector2(x, rect.position.y), Vector2(draw_w, rect.size.y)),
			false, tint)
		x += draw_w
		drawn += 1
