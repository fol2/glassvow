class_name FractureProbe
extends Control
## The kill test for `docs/fracture-model.md`, drawn over a live actor.
##
## This is NOT the renderer. It draws the model's output as bare hairlines with no
## width, no taper, no groove, no light — because the question it exists to answer is
## whether the GEOMETRY reads as fracture. If radial arms whose length is proportional
## to the damage do not read as a break when drawn as plain lines, no amount of
## optics will rescue them and the cheap answer is to stop before building any
## (`docs/fracture-model.md` §8). Making it pretty here would destroy the evidence.
##
## Three views, because they answer three different questions:
##
##   strands        does this read as fracture           — the kill test, plain lines
##   drive field    are the six invisible constants sane — a heatmap of `drive_at`
##   termini        did each crack stop for a real reason — colour per stop reason
##
## The middle one is the reason `FractureField.drive_at` is public. Six numbers with
## no picture is exactly the failure recorded in
## `docs/solutions/design-patterns/procedural-glass-reads-off-its-edges.md`: the old
## disc was wrong in a way you could see, and constants are wrong in a way you cannot.
##
## Lives in `presentation/lab/` and not in `fracture/`: it names `Control`, `Image`
## and the clock, all of which the purity gate bans from the model.

## The heatmap grid. Every cell costs a `net.nearest`, which walks every segment in
## the net, so this is O(cells x segments) — a few million distance tests on a busy
## net. Rebuilt only when the net or the blow changes, never per frame, and the cost
## is printed to the readout rather than hidden, because a lab tool that stalls for
## an unexplained second gets blamed on the thing being measured.
const DRIVE_RES: int = 40

## Hairline. One pixel reads as a rendering artefact and three reads as a drawn
## stroke; the kill test needs it to read as neither.
const HAIR: float = 1.6

const PLAIN: Color = Color(1.0, 0.94, 0.88, 0.92)
## Ran out of tension — the tip a death rite would carry the rest of the way out.
const STOP_FREE: Color = Color(0.72, 0.55, 1.0, 0.9)
## Reached the silhouette.
const STOP_EDGE: Color = Color(0.45, 0.85, 1.0, 0.9)
## Arrested on an existing crack. The T-junction, and the signature this whole
## model exists to produce (`docs/glass-crack-rendering.md` §3.1).
const STOP_CRACK: Color = Color(1.0, 0.60, 0.30, 0.95)

var show_drive: bool = false
var show_termini: bool = false

## The blow the next click will deliver. Exposed so the panel's sliders write here
## and nothing has to be threaded through the click handler.
var energy: float = 1.2
var angle_deg: float = 0.0
var face_on: bool = true

var _view: EnemyView = null
var _net: CrackNet = CrackNet.new()
var _field: FractureField = null
var _mask: BodyMask = null
var _last: Blow = null
var _drive: ImageTexture = null
var _drive_us: int = 0
var _strike_us: int = 0


func _init(view: EnemyView, art_id: StringName, seed_at: int) -> void:
	_view = view
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_mask = EnemyView.body_mask(art_id)
	# Its own stream, seeded off the creature: the bench must be able to re-run the
	# same sequence of blows and get the same network, or nothing seen here can be
	# reported as reproducible.
	_field = FractureField.new(Rng.new(seed_at), _mask)


## Land a blow at `at` in body UV. Returns how many strands it grew, so the caller
## can say "that one did nothing" instead of leaving the user to wonder.
func strike(at: Vector2) -> int:
	var dir: Vector2 = Vector2.ZERO
	if not face_on:
		dir = Vector2.RIGHT.rotated(deg_to_rad(angle_deg))
	var blow: Blow = Blow.new(at, dir, energy, 0.5)
	var t0: int = Time.get_ticks_usec()
	var grown: Array[Dictionary] = _field.strike(_net, blow)
	_strike_us = Time.get_ticks_usec() - t0
	_net.commit(grown)
	_last = blow
	_invalidate()
	return grown.size()


## The rite: every tip that stopped for want of tension runs the rest of the way out.
func relieve() -> int:
	var extra: Array[Dictionary] = _field.relieve(_net)
	_net.commit(extra)
	_invalidate()
	return extra.size()


func clear() -> void:
	_net = CrackNet.new()
	_last = null
	_invalidate()


func _invalidate() -> void:
	_drive = null
	queue_redraw()


## One line for the bench readout. Every number here is measured, not estimated —
## §7 of the model doc costs this work in prose and this is where the prose gets
## checked.
func describe() -> String:
	var total: float = 0.0
	# Three typed counters rather than a Dictionary: this project's gate treats a
	# Variant read back out of a Dictionary and handed to `int()` as an error, and
	# three names read better than three keys anyway.
	var n_free: int = 0
	var n_edge: int = 0
	var n_crack: int = 0
	for i: int in range(_net.strand_count()):
		total += _net.length(i)
		match _net.terminus(i):
			CrackNet.T_CRACK:
				n_crack += 1
			CrackNet.T_SILHOUETTE:
				n_edge += 1
			_:
				n_free += 1
	var j: Dictionary = _net.junctions(FractureField.STEP * 1.5)
	# `open` rather than the raw free count: after the rite a relieved strand still
	# reads `T_FREE` because the net is append-only, so "F8" would claim eight loose
	# ends on a network that has none. Both are printed — the gap between them is how
	# many tips the rite has carried out.
	var out: String = "%d strands · %.2f body · F%d (%d open) S%d T%d · %dT/%dY · strike %.2f ms" % [
		_net.strand_count(), total, n_free, _net.open_tips().size(), n_edge, n_crack,
		j["T"], j["Y"], float(_strike_us) * 0.001]
	if show_drive and _drive_us > 0:
		out += " · field %.0f ms" % (float(_drive_us) * 0.001)
	return out


# ------------------------------------------------------------------- the drawing

func _draw() -> void:
	if _view == null:
		return
	if show_drive:
		_draw_drive()
	for i: int in range(_net.strand_count()):
		var pts: PackedVector2Array = _net.strand(i)
		var line: PackedVector2Array = PackedVector2Array()
		line.resize(pts.size())
		for k: int in range(pts.size()):
			line[k] = _view.uv_to_local(pts[k])
		var tint: Color = PLAIN
		if show_termini:
			match _net.terminus(i):
				CrackNet.T_CRACK:
					tint = STOP_CRACK
				CrackNet.T_SILHOUETTE:
					tint = STOP_EDGE
				_:
					tint = STOP_FREE
		draw_polyline(line, tint, HAIR, true)
	if not show_termini:
		return
	# Impact points, last so they sit on top of their own arms. Only in the debug
	# view: the kill test must not be told where to look.
	var seen: Array[Vector2] = []
	for i: int in range(_net.strand_count()):
		var o: Vector2 = _net.origin(i)
		if seen.has(o):
			continue
		seen.append(o)
		draw_arc(_view.uv_to_local(o), 5.0, 0.0, TAU, 16,
			Color(1.0, 1.0, 1.0, 0.55), 1.0, true)


## The tension the next crack would feel, sampled on a grid and stretched over the
## body. Cells off the silhouette are left transparent, which is also most of the
## saving: a typical painting fills well under half its box.
func _draw_drive() -> void:
	if _drive == null:
		_bake_drive()
	if _drive == null:
		return
	# Drawn across the BODY QUAD, not this Control's rect — the painting is only as
	# wide as its aspect ratio and a heatmap stretched to the square box would be
	# offset from the creature it describes.
	var a: Vector2 = _view.uv_to_local(Vector2.ZERO)
	var b: Vector2 = _view.uv_to_local(Vector2.ONE)
	draw_texture_rect(_drive, Rect2(a, b - a), false)


func _bake_drive() -> void:
	var blow: Blow = _last
	if blow == null:
		# Nothing struck yet: show the field a face-on blow to the centre would meet,
		# which on a virgin body is the anisotropy term alone.
		blow = Blow.new(Vector2(0.5, 0.5), Vector2.ZERO, energy, 0.5)
	var img: Image = Image.create(DRIVE_RES, DRIVE_RES, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var t0: int = Time.get_ticks_usec()
	var tough: float = FractureField.TOUGHNESS
	for y: int in range(DRIVE_RES):
		for x: int in range(DRIVE_RES):
			var uv: Vector2 = Vector2((float(x) + 0.5) / float(DRIVE_RES),
				(float(y) + 0.5) / float(DRIVE_RES))
			if not _mask.solid(uv):
				continue
			var d: float = _field.drive_at(_net, blow, uv)
			# Diverging at the arrest threshold, because the threshold is what the
			# picture is FOR: cold means a crack dies here, warm means it runs. A
			# single monotonic ramp would hide the one contour that matters.
			var c: Color
			if d < tough:
				c = Color(0.30, 0.55, 1.0, 0.10 + 0.32 * (d / maxf(tough, 1e-4)))
			else:
				var over: float = clampf((d - tough) / maxf(tough, 1e-4), 0.0, 1.0)
				c = Color(1.0, 0.55 - 0.25 * over, 0.22, 0.42 + 0.30 * over)
			img.set_pixel(x, y, c)
	_drive_us = Time.get_ticks_usec() - t0
	_drive = ImageTexture.create_from_image(img)
