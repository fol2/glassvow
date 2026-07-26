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
	_check_field_radiates(fails)
	_check_field_termini(fails)
	_check_field_body(fails)
	_check_field_energy(fails)
	_check_field_arm_count(fails)
	_check_field_screening(fails)
	_check_field_always_marks(fails)
	_check_field_determinism(fails)
	_check_field_convergence(fails)
	_check_field_relieve(fails)


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


# ------------------------------------------------------------------- the field

static func _field(seed_v: int, mask: BodyMask, tuning: Dictionary = {}) -> FractureField:
	return FractureField.new(Rng.new(seed_v), mask, tuning)


static func _total_length(strands: Array[Dictionary]) -> float:
	var net: CrackNet = CrackNet.new()
	net.commit(strands)
	var sum: float = 0.0
	for i: int in range(net.strand_count()):
		sum += net.length(i)
	return sum


## THE check that guards the update rule. One review seat wrote the heading as
## `blow.dir.rotated(PI/2)` — one direction everywhere — which makes every arm of
## the star run parallel instead of radiating. Its prose was right and its
## pseudocode was not, and nothing downstream would have caught it: the strands
## would be valid, arrested, on the body, and wrong.
##
## Primary arms leave the blow point, so the mean of their unit headings is near
## zero when they radiate and near one when they are parallel. Forks start
## elsewhere and are excluded by their first point.
static func _check_field_radiates(fails: Array[String]) -> void:
	var f: FractureField = _field(1234, BodyMask.rect())
	# Energy 1.2, not 0.30. Under the corrected count rule 0.30 buys ONE arm, and a
	# single arm cannot be asked whether it radiates. The old figure passed only
	# because the count rule was degenerate — it returned seven arms for any energy
	# at all, so this check was reading a saturated cap and calling it radiation.
	var blow: Blow = Blow.new(Vector2(0.5, 0.5), Vector2.ZERO, 1.2, 0.5)
	var strands: Array[Dictionary] = f.strike(CrackNet.new(), blow)
	var mean: Vector2 = Vector2.ZERO
	var arms: int = 0
	for s: Dictionary in strands:
		var pts: PackedVector2Array = s["points"]
		if pts[0] != blow.at or pts.size() < 2:
			continue
		mean += (pts[1] - pts[0]).normalized()
		arms += 1
	if arms < 4:
		fails.append("field: expected at least 4 primary arms at energy 1.20, got %d"
			% arms)
		return
	var clustering: float = (mean / float(arms)).length()
	if clustering > 0.6:
		fails.append("field: arms are not radiating — mean heading length %.2f over %d arms (parallel would be ~1.0)"
			% [clustering, arms])


## Every strand must have stopped for a stated reason, and a `T` must actually
## touch something — otherwise the renderer draws a groove ending in mid-glass.
static func _check_field_termini(fails: Array[String]) -> void:
	var f: FractureField = _field(77, BodyMask.rect())
	var net: CrackNet = CrackNet.new()
	# Energies and spacing raised with `ARM_LENGTH`. At 0.24 energy and 0.08 apart —
	# the old fixture — every blow after the first lands inside its predecessor's
	# process zone and is screened into a sub-floor stub, so the network never grows
	# the crossings this check exists to census. That is the screening rule working
	# correctly; the fixture was simply calibrated against the degenerate arm count.
	for i: int in range(4):
		var blow: Blow = Blow.new(Vector2(0.30 + 0.13 * float(i), 0.45),
			Vector2(1.0, 0.2), 1.1, 0.5)
		net.commit(f.strike(net, blow))
	if net.strand_count() < 4:
		fails.append("field: four blows produced only %d strands" % net.strand_count())
		return
	for i: int in range(net.strand_count()):
		if not CrackNet.TERMINI.has(net.terminus(i)):
			fails.append("field: strand %d has terminus %s" % [i, net.terminus(i)])
		if net.terminus(i) != CrackNet.T_CRACK:
			continue
		var pts: PackedVector2Array = net.strand(i)
		var tip: Vector2 = pts[pts.size() - 1]
		var others: Array[PackedVector2Array] = []
		for j: int in range(net.strand_count()):
			if j != i:
				others.append(net.strand(j))
		var d: float = CrackNet.dist_to_strands(others, tip)
		if d > FractureField.STEP * 1.5:
			fails.append("field: strand %d claims T but its tip is %.4f from any other strand"
				% [i, d])
	var j: Dictionary = net.junctions(FractureField.STEP * 1.5)
	if j["T"] < j["Y"]:
		fails.append("field: %d T-junctions vs %d Y — impact fracture is T-junctioned"
			% [j["T"], j["Y"]])
	# Without this the comparison above passes vacuously at T = 0, and "T-junctioned"
	# would be a claim about a network that has no junctions at all. Four overlapping
	# blows must produce arrests on each other's cracks or the arrest rule is not
	# firing.
	if j["T"] == 0:
		fails.append("field: four overlapping blows produced no T-junction at all")


## §3.3. Every vertex on the body, every segment staying on it. The void here is a
## transparent column, so a crack aimed across it must stop at the edge.
static func _check_field_body(fails: Array[String]) -> void:
	var img: Image = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	img.fill_rect(Rect2i(72, 0, 10, 128), Color(0, 0, 0, 0))
	var mask: BodyMask = BodyMask.from_image(img)
	var f: FractureField = _field(9, mask)
	var net: CrackNet = CrackNet.new()
	net.commit(f.strike(net, Blow.new(Vector2(0.3, 0.5), Vector2.ZERO, 0.45, 0.5)))
	if net.is_empty():
		fails.append("field: no strands grown on a masked body")
		return
	for i: int in range(net.strand_count()):
		var pts: PackedVector2Array = net.strand(i)
		for k: int in range(pts.size()):
			if not mask.solid(pts[k]):
				fails.append("field: strand %d vertex %d at %v is off the body"
					% [i, k, pts[k]])
				break
		for k: int in range(pts.size() - 1):
			if not mask.reaches(pts[k], pts[k + 1]):
				fails.append("field: strand %d segment %d crosses a void" % [i, k])
				break


## Griffith, as an assertion: energy buys length, monotonically.
static func _check_field_energy(fails: Array[String]) -> void:
	var small: float = _total_length(
		_field(5, BodyMask.rect()).strike(CrackNet.new(),
			Blow.new(Vector2(0.5, 0.5), Vector2.ZERO, 0.12, 0.5)))
	var big: float = _total_length(
		_field(5, BodyMask.rect()).strike(CrackNet.new(),
			Blow.new(Vector2(0.5, 0.5), Vector2.ZERO, 0.60, 0.5)))
	if not (big > small):
		fails.append("field: 0.60 energy bought %.3f of crack, 0.12 bought %.3f"
			% [big, small])


## Griffith says nothing about how the energy is SPLIT, which is how the arm count
## rule managed to be degenerate while every other field check passed: total length
## stayed exactly proportional to energy whether the budget went into one arm or
## seven. So the count needs its own assertion — a heavier blow must throw a wider
## star, not just a longer one, until the cap.
##
## Written after `FractureField.ARM_LENGTH` was split out of `MIN_ARM`. Before that
## split every energy from 0.23 upward returned exactly `MAX_ARMS`.
static func _check_field_arm_count(fails: Array[String]) -> void:
	var counts: Array[int] = []
	for e: float in [0.20, 0.60, 1.20, 2.40] as Array[float]:
		var strands: Array[Dictionary] = _field(9, BodyMask.rect()).strike(
			CrackNet.new(), Blow.new(Vector2(0.5, 0.5), Vector2.ZERO, e, 0.5))
		# Primaries only: forks do not leave the impact point, so counting them would
		# measure branching rather than how the blow was divided.
		var n: int = 0
		for s: Dictionary in strands:
			var pts: PackedVector2Array = s["points"]
			if pts[0] == Vector2(0.5, 0.5):
				n += 1
		counts.append(n)
	if counts[0] != 1:
		fails.append("field: a 0.20 blow should buy a single arm, got %d" % counts[0])
	for i: int in range(1, counts.size()):
		if counts[i] <= counts[i - 1] and counts[i - 1] < FractureField.MAX_ARMS:
			fails.append("field: arm count did not grow with energy — %s across 0.20/0.60/1.20/2.40"
				% str(counts))
			return
	# And the arms must stay long enough to see once the count has capped, or the
	# cap would be buying density at the cost of legibility.
	var top: Array[Dictionary] = _field(9, BodyMask.rect()).strike(
		CrackNet.new(), Blow.new(Vector2(0.5, 0.5), Vector2.ZERO, 2.40, 0.5))
	for s: Dictionary in top:
		var pts: PackedVector2Array = s["points"]
		if pts[0] != Vector2(0.5, 0.5):
			continue
		var run: float = 0.0
		for k: int in range(pts.size() - 1):
			run += pts[k].distance_to(pts[k + 1])
		if run < FractureField.MIN_ARM:
			fails.append("field: a 2.40 blow threw an arm of only %.3f body, under the %.3f floor"
				% [run, FractureField.MIN_ARM])
			return


## The behaviour the old web could not express at all, and the one the owner
## described as missing: a blow into glass that is ALREADY broken finds the tension
## there released, so it scores less. Both fields share a seed and are struck at the
## same point with the same blow, so the only difference is what was already there.
static func _check_field_screening(fails: Array[String]) -> void:
	# 1.2 rather than 0.40, so BOTH sides grow a real star. At one arm each the
	# screened side is filtered to nothing and `0 < 0.40` passes while saying much
	# less than it appears to: "less" is the claim, and a comparison of two non-zero
	# lengths is the only way to see it.
	var blow: Blow = Blow.new(Vector2(0.5, 0.5), Vector2.ZERO, 1.2, 0.5)
	var virgin: float = _total_length(
		_field(31, BodyMask.rect()).strike(CrackNet.new(), blow))
	if virgin <= 0.0:
		fails.append("field: the virgin strike grew nothing — the check cannot run")
		return
	# Placed by hand rather than struck, so the second field's RNG is untouched.
	var broken: CrackNet = CrackNet.new()
	broken.commit([{
		"points": PackedVector2Array([Vector2(0.5, 0.44), Vector2(0.5, 0.56)]),
		"terminus": CrackNet.T_SILHOUETTE, "origin": Vector2(0.5, 0.5)}])
	var screened: float = _total_length(
		_field(31, BodyMask.rect()).strike(broken, blow))
	if not (screened < virgin):
		fails.append("field: screening did nothing — %.3f of crack on broken glass vs %.3f on virgin"
			% [screened, virgin])


## Same seed, same result. Without this the lab cannot prove that a change meant to
## alter nothing altered nothing, which is the defect recorded as
## `docs/glass-crack-rendering.md` §7 in a different guise.
static func _check_field_determinism(fails: Array[String]) -> void:
	var blow: Blow = Blow.new(Vector2(0.45, 0.55), Vector2(0.6, -0.8), 0.35, 0.5)
	var a: Array[Dictionary] = _field(4242, BodyMask.rect()).strike(CrackNet.new(), blow)
	var b: Array[Dictionary] = _field(4242, BodyMask.rect()).strike(CrackNet.new(), blow)
	if a.size() != b.size():
		fails.append("field: same seed gave %d and %d strands" % [a.size(), b.size()])
		return
	for i: int in range(a.size()):
		var pa: PackedVector2Array = a[i]["points"]
		var pb: PackedVector2Array = b[i]["points"]
		if pa != pb:
			fails.append("field: same seed diverged at strand %d" % i)
			return


## The other half of screening, and the half that was missing: a blow into broken glass
## must do LESS, never NOTHING. `CONCEPTS.md` › Crack promises the glass tells the truth
## about the fight, and a hit that leaves no mark at all breaks that promise.
##
## Written after measuring four of eight blows scoring zero strands on a duskfang. The
## screening check above cannot catch this — it asserts `screened < virgin`, and zero
## satisfies that perfectly.
##
## The fixture is a tight CLUSTER — eight blows inside a 0.09 box, so every one after the
## first lands well within its predecessors' process zone (`SCREEN_RADIUS` is 0.08).
##
## Deliberately NOT eight blows onto one identical point, which was the first version and
## which asserts something physically false. A point that already has six cracks
## radiating out of it is comminuted: the glass there is fully relieved and pulverised,
## and a seventh set of radials from it is not what happens. Real glass answers a repeat
## hit on the exact same spot with a frosted crush zone, which this model does not
## represent and does not claim to. What it must handle is the case the game actually
## produces — blows landing NEAR each other — and that is what this asserts.
static func _check_field_always_marks(fails: Array[String]) -> void:
	var f: FractureField = _field(21, BodyMask.rect())
	var net: CrackNet = CrackNet.new()
	for i: int in range(8):
		var at: Vector2 = Vector2(0.46 + 0.012 * float(i % 4 - 2),
			0.46 + 0.013 * float(i / 4))
		var grown: Array[Dictionary] = f.strike(
			net, Blow.new(at, Vector2.ZERO, 1.1, 0.5))
		if grown.is_empty():
			fails.append("field: blow %d into a cluster scored NOTHING at %v — a hit must always mark"
				% [i + 1, at])
			return
		net.commit(grown)


## `STEP`'s claim, run rather than asserted in prose: halve the integrator step and
## no tip may move by more than one step. Grain is set to zero because the jitter is
## a per-step random draw — with it on, halving the step changes the random sequence
## and the test would measure noise instead of convergence.
static func _check_field_convergence(fails: Array[String]) -> void:
	var blow: Blow = Blow.new(Vector2(0.5, 0.5), Vector2.ZERO, 0.20, 0.5)
	var coarse: float = FractureField.STEP
	var a: Array[Dictionary] = _field(8, BodyMask.rect(),
		{"heterogeneity": 0.0, "step": coarse}).strike(CrackNet.new(), blow)
	var b: Array[Dictionary] = _field(8, BodyMask.rect(),
		{"heterogeneity": 0.0, "step": coarse * 0.5}).strike(CrackNet.new(), blow)
	if a.is_empty() or b.is_empty():
		fails.append("field: convergence check grew nothing")
		return
	var pa: PackedVector2Array = a[0]["points"]
	var pb: PackedVector2Array = b[0]["points"]
	var moved: float = pa[pa.size() - 1].distance_to(pb[pb.size() - 1])
	if moved > coarse * 1.5:
		fails.append("field: halving the step moved the tip %.4f, more than one step (%.4f)"
			% [moved, coarse])


## The rite. Every tip that stopped for want of tension runs the rest of the way
## out, and the continuation starts exactly where the old one ended — which is what
## lets an append-only net describe a connected network.
static func _check_field_relieve(fails: Array[String]) -> void:
	var f: FractureField = _field(60, BodyMask.rect())
	var net: CrackNet = CrackNet.new()
	net.commit(f.strike(net, Blow.new(Vector2(0.5, 0.5), Vector2.ZERO, 0.18, 0.5)))
	var free_tips: Array[Vector2] = []
	for i: int in net.open_tips():
		var p: PackedVector2Array = net.strand(i)
		free_tips.append(p[p.size() - 1])
	if free_tips.is_empty():
		fails.append("field: no free tips to relieve — the check cannot run")
		return
	var extra: Array[Dictionary] = f.relieve(net)
	if extra.size() != free_tips.size():
		fails.append("field: %d free tips produced %d continuations"
			% [free_tips.size(), extra.size()])
	for s: Dictionary in extra:
		var pts: PackedVector2Array = s["points"]
		var joins: bool = false
		for t: Vector2 in free_tips:
			if pts[0].distance_to(t) < 1e-5:
				joins = true
				break
		if not joins:
			fails.append("field: a continuation starts at %v, which is no free tip"
				% pts[0])
		if s["terminus"] == CrackNet.T_FREE:
			fails.append("field: a continuation still ended free at toughness zero")
	# Idempotent. An append-only net cannot re-terminate the strand it continued, so
	# the rite has to recognise a tip that is already carried out by what GROWS from
	# it. Without that, a death beat firing twice doubles the entire network — and this
	# codebase has had a death fire twice before (`c77b56b`).
	net.commit(extra)
	var again: Array[Dictionary] = f.relieve(net)
	if not again.is_empty():
		fails.append("field: relieving twice grew %d more continuations — not idempotent"
			% again.size())
