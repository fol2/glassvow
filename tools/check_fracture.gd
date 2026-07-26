extends SceneTree
## Invariant checks for `presentation/combat/fracture/` — the pure fracture model.
##
##   godot --headless -s res://tools/check_fracture.gd
##
## **Written in the suite's shape on purpose.** `tests/run_all.gd` discovers
## `res://tests/test_*.gd` and calls a static `run(fails)`; this file provides
## exactly that, so folding it in is a verbatim copy to `tests/test_fracture.gd`
## with no edits. It lives here rather than there because `tests/` is not this
## lane's to write — the organiser owns the suite verdict
## (`docs/session-ownership.md`) — and a module that cannot be asserted is not
## worth the purity discipline that makes it assertable.
##
## Why these checks and not others: `docs/glass-crack-rendering.md` §3 lists five
## verified defects in the Voronoi web this model replaces. Three of them are
## properties of the NET and the MASK rather than of the propagator, so they can be
## gated before any physics exists:
##
##   §3.2 cracks relocate      -> a committed strand is byte-identical afterwards
##   §3.3 no body mask         -> `reaches` refuses to cross a void
##   §3.1 wrong topology       -> the terminus vocabulary and the junction census
##
## The remaining two need `FractureField`, and their checks land with it.

const DIR: String = "res://presentation/combat/fracture"

## The purity gate. `fracture/` is `RefCounted` geometry: no scene tree, no clock,
## no I/O. Two of these bans do real work rather than tidiness —
##
##   `RandomNumberGenerator` so the module cannot re-introduce the shared-stream
##   defect recorded as `docs/glass-crack-rendering.md` §7, where the camera shake
##   advanced the same generator the crack pattern drew from. The only randomness
##   allowed in is an injected `Rng`.
##
##   `Time` so propagation cannot become time-driven INSIDE the model. The model
##   emits a finished strand; the renderer reveals it. That is `CONCEPTS.md` ›
##   *Angle, not time* applied at the right seam, and it is why an animation can
##   never desync from the geometry — there is only one geometry.
const BANNED: Array[String] = [
	"Node", "SceneTree", "Tween", "Mesh", "Material", "Shader", "Viewport",
	"Time", "RandomNumberGenerator", "FileAccess", "DirAccess", "Input", "OS",
	"get_tree", "Image",
]
## `BodyMask` is the module's boundary with the painting and is the one file
## allowed to name `Image` — which is the whole reason the mask is a separate
## object rather than an alpha lookup inlined into the propagator.
const EXEMPT: Dictionary = {"body_mask.gd": ["Image"]}


func _initialize() -> void:
	var fails: Array[String] = []
	run(fails)
	if fails.is_empty():
		print("check_fracture: PASS")
		quit(0)
		return
	for f: String in fails:
		print("FAIL %s" % f)
	print("check_fracture: %d failure(s)" % fails.size())
	quit(1)


static func run(fails: Array[String]) -> void:
	_check_purity(fails)
	_check_net_append_only(fails)
	_check_net_arc(fails)
	_check_net_rejects(fails)
	_check_net_nearest(fails)
	_check_net_junctions(fails)
	_check_mask_rect(fails)
	_check_mask_void(fails)


# ------------------------------------------------------------------ the gate

static func _check_purity(fails: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(DIR)
	if dir == null:
		fails.append("purity: cannot open %s" % DIR)
		return
	var seen: int = 0
	for name: String in dir.get_files():
		if not name.ends_with(".gd"):
			continue
		seen += 1
		var text: String = FileAccess.get_file_as_string("%s/%s" % [DIR, name])
		var allowed: Array = EXEMPT.get(name, [])
		var n: int = 0
		for raw: String in text.split("\n"):
			n += 1
			# Comments are stripped before scanning. A banned name in a docblock is
			# prose, not a dependency, and these files discuss what they exclude —
			# scanning the comments would fail the module for explaining itself.
			# Cut at the first `#`: no file here puts one inside a string literal.
			var hash_at: int = raw.find("#")
			var code: String = raw if hash_at < 0 else raw.substr(0, hash_at)
			if code.strip_edges().is_empty():
				continue
			for token: String in BANNED:
				if token in allowed:
					continue
				if _names(code, token):
					fails.append("purity: %s:%d names banned %s" % [name, n, token])
	if seen == 0:
		fails.append("purity: no .gd files found under %s" % DIR)


## Whole-identifier match, so `Time` does not fire on `lifetime` and `OS` does not
## fire on `_to_string`. GDScript identifiers are word characters, so the test is
## that neither neighbour is one.
static func _names(code: String, token: String) -> bool:
	var from: int = 0
	while true:
		var at: int = code.find(token, from)
		if at < 0:
			return false
		var before: String = code.substr(at - 1, 1) if at > 0 else " "
		var after_at: int = at + token.length()
		var after: String = code.substr(after_at, 1) if after_at < code.length() else " "
		if not _word(before) and not _word(after):
			return true
		from = at + 1
	return false


static func _word(c: String) -> bool:
	if c.is_empty():
		return false
	return c == "_" or c.to_lower() != c.to_upper() or c.is_valid_int()


# --------------------------------------------------------------------- the net

static func _strand(pts: PackedVector2Array, term: StringName) -> Dictionary:
	return {"points": pts, "terminus": term, "origin": pts[0]}


## §3.2. The defect this replaces re-partitioned the plane on every hit, so blow N
## reshaped blows 1..N-1. Here a later commit must leave earlier geometry alone,
## byte for byte.
static func _check_net_append_only(fails: Array[String]) -> void:
	var net: CrackNet = CrackNet.new()
	var first: PackedVector2Array = PackedVector2Array([
		Vector2(0.5, 0.5), Vector2(0.7, 0.5), Vector2(0.8, 0.6)])
	net.commit([_strand(first, CrackNet.T_FREE)])
	var before: PackedVector2Array = net.strand(0)
	for i: int in range(6):
		net.commit([_strand(PackedVector2Array([
			Vector2(0.2, 0.2 + 0.05 * float(i)), Vector2(0.9, 0.3)]),
			CrackNet.T_SILHOUETTE)])
	var after: PackedVector2Array = net.strand(0)
	if before != after:
		fails.append("net: strand 0 changed after later commits (%s vs %s)"
			% [before, after])
	if net.strand_count() != 7:
		fails.append("net: expected 7 strands, got %d" % net.strand_count())
	# The accessor must hand out a copy, or append-only is a promise the type does
	# not keep.
	var grabbed: PackedVector2Array = net.strand(0)
	grabbed.append(Vector2(9.0, 9.0))
	if net.strand(0).size() != first.size():
		fails.append("net: mutating a returned strand reached back into the net")


static func _check_net_arc(fails: Array[String]) -> void:
	var net: CrackNet = CrackNet.new()
	var pts: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(0.3, 0.0), Vector2(0.3, 0.4)])
	net.commit([_strand(pts, CrackNet.T_FREE)])
	var arc: PackedFloat32Array = net.arc(0)
	if arc.size() != 3:
		fails.append("net: arc size %d, expected 3" % arc.size())
		return
	if absf(arc[0]) > 1e-6:
		fails.append("net: arc[0] = %f, expected 0" % arc[0])
	if absf(arc[1] - 0.3) > 1e-5 or absf(arc[2] - 0.7) > 1e-5:
		fails.append("net: arc = %s, expected [0, 0.3, 0.7]" % str(arc))
	if absf(net.length(0) - 0.7) > 1e-5:
		fails.append("net: length %f, expected 0.7" % net.length(0))


## A net that accepts a one-point strand or an invented terminus cannot be relied
## on by the renderer, which switches on the terminus to decide whether a groove
## tapers to nothing or stops dead against another crack.
static func _check_net_rejects(fails: Array[String]) -> void:
	print("check_fracture: the next few ERROR lines are expected — testing rejects")
	var net: CrackNet = CrackNet.new()
	net.commit([{"points": PackedVector2Array([Vector2(0.5, 0.5)]),
		"terminus": CrackNet.T_FREE}])
	net.commit([{"points": PackedVector2Array([Vector2(0.1, 0.1), Vector2(0.2, 0.2)]),
		"terminus": &"Q"}])
	net.commit(["not a dictionary"])
	if not net.is_empty():
		fails.append("net: accepted %d malformed strand(s)" % net.strand_count())


static func _check_net_nearest(fails: Array[String]) -> void:
	var net: CrackNet = CrackNet.new()
	if net.nearest(Vector2(0.5, 0.5)) != INF:
		fails.append("net: nearest on an empty net must be INF")
	net.commit([_strand(PackedVector2Array([
		Vector2(0.0, 0.5), Vector2(1.0, 0.5)]), CrackNet.T_SILHOUETTE)])
	var d: float = net.nearest(Vector2(0.5, 0.8))
	if absf(d - 0.3) > 1e-5:
		fails.append("net: nearest = %f, expected 0.3" % d)
	# Off the end of the segment, so the answer is to the endpoint rather than to
	# the infinite line — the distinction a crack tip actually cares about.
	var e: float = net.nearest(Vector2(1.4, 0.5))
	if absf(e - 0.4) > 1e-5:
		fails.append("net: nearest past the end = %f, expected 0.4" % e)


## §3.1. Two strands ending ON a third are two T-junctions and no Y — the
## signature of sequential impact fracture. A Y needs three ends at one point,
## which is what a simultaneous isotropic process makes.
static func _check_net_junctions(fails: Array[String]) -> void:
	var net: CrackNet = CrackNet.new()
	net.commit([
		_strand(PackedVector2Array([Vector2(0.1, 0.5), Vector2(0.9, 0.5)]),
			CrackNet.T_SILHOUETTE),
		_strand(PackedVector2Array([Vector2(0.4, 0.1), Vector2(0.4, 0.5)]),
			CrackNet.T_CRACK),
		_strand(PackedVector2Array([Vector2(0.6, 0.9), Vector2(0.6, 0.5)]),
			CrackNet.T_CRACK),
	])
	var j: Dictionary = net.junctions(0.01)
	if j["T"] != 2:
		fails.append("net: T count %d, expected 2" % j["T"])
	if j["Y"] != 0:
		fails.append("net: Y count %d, expected 0" % j["Y"])


# -------------------------------------------------------------------- the mask

static func _check_mask_rect(fails: Array[String]) -> void:
	var m: BodyMask = BodyMask.rect()
	if not m.solid(Vector2(0.5, 0.5)):
		fails.append("mask: rect() must be solid at the centre")
	if m.solid(Vector2(1.2, 0.5)) or m.solid(Vector2(0.5, -0.1)):
		fails.append("mask: rect() must not be solid outside 0..1")
	if not m.reaches(Vector2(0.1, 0.5), Vector2(0.9, 0.5)):
		fails.append("mask: rect() must reach across itself")
	if m.reaches(Vector2(0.1, 0.5), Vector2(1.5, 0.5)):
		fails.append("mask: rect() must not reach outside itself")


## §3.3, and the check the whole `reaches` method exists for. A transparent band
## down the middle is a tendrilled painting in miniature: `solid` at either side
## says yes, and only a swept test can say the two sides are not connected.
static func _check_mask_void(fails: Array[String]) -> void:
	var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	img.fill_rect(Rect2i(28, 0, 8, 64), Color(0, 0, 0, 0))
	var m: BodyMask = BodyMask.from_image(img)
	if not m.solid(Vector2(0.1, 0.5)):
		fails.append("mask: left side should be solid")
	if m.solid(Vector2(0.5, 0.5)):
		fails.append("mask: the void should not be solid")
	if not m.solid(Vector2(0.9, 0.5)):
		fails.append("mask: right side should be solid")
	if m.reaches(Vector2(0.1, 0.5), Vector2(0.9, 0.5)):
		fails.append("mask: reaches() crossed a void — a crack would cross it too")
	if not m.reaches(Vector2(0.05, 0.5), Vector2(0.35, 0.5)):
		fails.append("mask: reaches() refused a path that stays on the body")
	# Vertical, well clear of the band: the void is a column, so a crack running
	# parallel to it must be unaffected.
	if not m.reaches(Vector2(0.1, 0.1), Vector2(0.1, 0.9)):
		fails.append("mask: reaches() refused a path parallel to the void")
