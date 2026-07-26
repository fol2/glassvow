class_name FractureField
extends RefCounted
## The mechanics. A blow goes in, finished crack strands come out — and every one
## of them has already stopped, for a stated reason.
##
## The chain is short on purpose (`docs/fracture-model.md` §0): kinetic energy →
## elastic strain energy → new fracture surface, and Griffith collapses that to
## **crack length is proportional to delivered energy**. So `Blow.energy` IS a
## length: 1.0 buys one body-width of crack. There is no joules-to-pixels constant
## in here, because the only honest conversion is damage → energy and that belongs
## at the boundary where the game's vocabulary lives.
##
## What is deliberately absent, and why, since each was considered:
##
## * **A 1/r stress falloff from the impact.** It would double-count. The energy
##   budget already limits how far a crack gets; a falloff on top would say the same
##   thing twice and give two numbers to tune against each other.
## * **A plate-bending solve.** Physics theatre at this scale — nothing a player can
##   see comes out of it that the budget and the screening do not already give.
## * **Concentric arcs.** Real, and `sharp` is the parameter that will split energy
##   between radial and circumferential cracking. Not in this pass: the question the
##   first render has to answer is whether radials read as fracture at all, and
##   arcs cannot rescue radials that do not. `sharp` is accepted and ignored, which
##   is recorded here rather than hidden.
##
## Pure: no Node, no clock, no randomness except the injected `Rng`. The purity gate
## in `tools/check_fracture.gd` enforces that, and the `Time` ban is what keeps
## propagation from becoming time-driven in here — the model emits a finished
## strand and the renderer reveals it.


# ---------------------------------------------------------------- the parameters

## Normalised driving tension below which a crack stops, 0..1. Griffith's G_c
## expressed as a threshold rather than as an energy, because `Blow.energy` already
## carries the energy and a second unit would be a second thing to get wrong.
## `relieve()` sets this to zero: the vessel has given up.
const TOUGHNESS: float = 0.34

## The process zone, as a body fraction. How far an existing free surface relieves
## the tension around it — so how tightly a later crack bends toward, and dies
## against, an earlier one. This is the whole reason a second blow into broken glass
## does less than the first, which is the behaviour the old web could not express.
const SCREEN_RADIUS: float = 0.08

## Inside this distance of an existing crack, a tip whose tension has died is treated
## as having JOINED that crack rather than as having stopped near it. Half the process
## zone, which is comfortably outside the largest radius a tension death can occur at
## (0.033 body — see the derivation at the capture branch in `_grow`), so no tension
## death is ever mistaken for an arrest in open glass.
const CAPTURE_RADIUS: float = SCREEN_RADIUS * 0.5

## Grain: radians of wander per body fraction travelled. A crack in glass is not a
## ruler line, and a perfectly straight radial reads as a laser cut.
const HETEROGENEITY: float = 2.4

## How hard the radial direction pulls a wandering tip back, per step, 0..1.
##
## This constant exists because the first version had no such thing: it ASSIGNED the
## heading from the radial every step. That looks like the same statement and is not.
## An assignment erases the accumulated wander on every step, so the grain above
## could not compound and each arm was pinned to an exact ray — the kill-test sheet
## came out as a surveyor's crosshair, four straight lines at right angles, and read
## as a reticle rather than as a break.
##
## It also silently deleted every fork. A fork starts ON its parent, so its radial IS
## the parent's radial; assigning from it erased the 35° fork angle one step after the
## fork was made, and the branch then ran inside its parent's own step width and
## arrested on it. Eight blows produced twenty strands and not one branch.
##
## As a partial pull the physics is also the truer statement: a crack follows the
## local maximum-tension direction, which is radial in the mean and perturbed in
## detail. `docs/fracture-model.md` §2.4.
const RADIAL_PULL: float = 0.09

## How much the blow's own heading biases the tension. At 0 a slash and a stab
## fracture identically, which they do not.
const ANISO: float = 0.55

## Euler step, body fraction. Carries a convergence test rather than taste: halve it
## and no tip may move by more than one step (see `tools/check_fracture.gd`).
const STEP: float = 0.012

## A crack cannot exceed 1.5 body diagonals, so the cap is derived rather than
## chosen. It exists to bound the loop, not to shape the result.
const MAX_STEPS: int = int(1.5 / STEP) + 1

## The shortest mark worth making at all, as a body fraction. Derived from the
## renderer's own floor: a groove must be ≥0.0065 body wide to survive sampling
## (`docs/fracture-model.md` §3), and a mark needs to be several times longer than
## it is wide before the eye reads it as a line rather than as a speck. Five times.
## A blow that cannot buy one of these makes nothing.
const MIN_ARM: float = 0.033

## The length a radial WANTS to be, and therefore what divides the energy into arms.
##
## These were ONE constant and that was wrong. Dividing the budget by the legibility
## floor makes the arm count saturate at `MAX_ARMS` for any energy above 0.23 — so a
## tap and a killing blow both threw seven arms and only their length differed, which
## is the exact opposite of the intended story ("the energy decides how many arms it
## can afford") and of the reference's own behaviour: four arms normally, six for a
## big hit. The floor and the preferred length are different quantities and
## collapsing them cost the count rule its meaning.
##
## Split, the count grows with energy until it caps and the length stays near a
## quarter body — which is what the reference authors by hand, arrived at here from
## the energy instead. Found by building the lab probe, because nothing in the model
## could see it: total length was still exactly proportional to energy, so Griffith
## held and the arm count was free to be nonsense.
const ARM_LENGTH: float = 0.26

## A running tip splits when local drive exceeds twice the arrest threshold: a
## single crack front cannot dissipate much beyond 2 G_c. Fixed on the mechanics and
## not exposed, which is the point — the reference authors a 45% fork chance.
const FORK_DRIVE: float = 2.0
## Where the fork leaves, in radians off the parent heading.
const FORK_ANGLE: float = 0.62
## A fork inherits this share of what its parent had left.
const FORK_SHARE: float = 0.38
## No fork before the arm has committed to a direction, or the star reads as a bush.
const FORK_AFTER: float = 0.4

const MAX_ARMS: int = 7

## The spread of the uneven split, as multiples of an even share. Roughly four to one
## between the longest and shortest arm a blow can throw, which is what breaks the
## symmetry that made the star read as a symbol. Not wider: past about five to one the
## short arms fall under `MIN_ARM` and are dropped, so a heavy blow would quietly
## throw fewer arms than its energy paid for.
const ARM_SPREAD_LOW: float = 0.45
const ARM_SPREAD_HIGH: float = 1.75


var _rng: Rng
var _mask: BodyMask
var _toughness: float = TOUGHNESS
var _step: float = STEP
var _grain: float = HETEROGENEITY
var _max_steps: int = MAX_STEPS


## `tuning` overrides the constants by name. It exists for two callers and no
## others: the lab, which has to be able to move a parameter and see the field
## change, and the convergence test — `STEP`'s claim is that halving it moves no tip
## by more than one step, and a claim that cannot be run is not a claim. Everything
## defaults, so the game never passes this.
func _init(rng: Rng, mask: BodyMask, tuning: Dictionary = {}) -> void:
	_rng = rng
	_mask = mask
	# Narrowed through typed locals: `Dictionary.get` returns `Variant`, and this
	# project's gate treats a Variant handed to a typed parameter as an error.
	var t: float = tuning.get("toughness", TOUGHNESS)
	var s: float = tuning.get("step", STEP)
	var g: float = tuning.get("heterogeneity", HETEROGENEITY)
	_toughness = t
	_step = maxf(1e-4, s)
	_grain = g
	# Derived from the step, never passed in: a crack cannot exceed 1.5 body
	# diagonals, so the cap tracks whatever the step becomes.
	_max_steps = int(1.5 / _step) + 1


# ------------------------------------------------------------------ the field

## The driving tension at `p`, normalised. Public for ONE reason: the lab has to be
## able to sample this on a grid and draw it. The old disc was wrong in a way you
## could see; six invisible constants are wrong in a way you cannot, and
## `docs/solutions/design-patterns/procedural-glass-reads-off-its-edges.md` records
## what six screenshot rounds of tuning-without-seeing costs.
func drive_at(net: CrackNet, blow: Blow, p: Vector2) -> float:
	var heading: Vector2 = (p - blow.at)
	heading = heading.normalized() if heading.length() > 0.0 else Vector2.RIGHT
	return _bias(heading, blow) * (1.0 - _relief(net, [], p))


## Existing cracks are free surfaces: the tension near them has already been spent.
## Exponential rather than linear so the falloff has no edge of its own — a linear
## ramp would put a visible ring at `SCREEN_RADIUS`, which is the same mistake as
## the disc.
func _relief(net: CrackNet, buffer: Array[PackedVector2Array], p: Vector2) -> float:
	var d: float = net.nearest(p)
	if not buffer.is_empty():
		d = minf(d, CrackNet.dist_to_strands(buffer, p))
	if d == INF:
		return 0.0
	return exp(-d / SCREEN_RADIUS)


func _bias(heading: Vector2, blow: Blow) -> float:
	if blow.dir == Vector2.ZERO:
		return 1.0
	return 1.0 + ANISO * absf(heading.dot(blow.dir))


func _rand(a: float, b: float) -> float:
	return a + (b - a) * _rng.next()


# ------------------------------------------------------------------ the strike

## Grow this blow's cracks. The caller commits them — the field never touches the
## net, so a strike can be inspected, discarded or replayed.
func strike(net: CrackNet, blow: Blow) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if blow.energy < MIN_ARM:
		return out
	# Derived, not authored: how many arms of a legible length the delivered energy
	# can afford. Past `MAX_ARMS` the extra energy lengthens the arms instead, which
	# is why a big hit reads as reach rather than as a denser star.
	var arms: int = clampi(int(blow.energy / ARM_LENGTH), 1, MAX_ARMS)
	var base: float = _rand(0.0, TAU)
	# The energy is split UNEVENLY. An even split was the other half of the crosshair:
	# four arms of identical length at near-identical spacing read as a drawn symbol,
	# and a real impact star is one or two long arms with several short ones. The
	# weights are normalised, so the total is still exactly the delivered energy and
	# Griffith is untouched — only its distribution is.
	var weight: Array[float] = []
	var total_w: float = 0.0
	for i: int in range(arms):
		var w: float = _rand(ARM_SPREAD_LOW, ARM_SPREAD_HIGH)
		weight.append(w)
		total_w += w
	# In-flight strands are visible to the arrest test, so a radial can die on a
	# sibling from its own blow. A crack arrests on any free surface, whenever made.
	var buffer: Array[PackedVector2Array] = []
	var pending: Array[Array] = []
	for i: int in range(arms):
		var a: float = base + TAU * float(i) / float(arms) \
			+ _rand(-0.35, 0.35) / float(arms) * TAU
		pending.append([blow.at, Vector2(cos(a), sin(a)),
			blow.energy * weight[i] / total_w])
	while not pending.is_empty():
		var job: Array = pending.pop_front()
		# Unpacked into typed locals rather than indexed straight into the call: a
		# `Variant` handed to a typed parameter is a warning, and warnings are errors
		# in this project's gate.
		var j_from: Vector2 = job[0]
		var j_dir: Vector2 = job[1]
		var j_budget: float = job[2]
		var grown: Dictionary = _grow(net, buffer, blow, j_from, j_dir, j_budget)
		var pts: PackedVector2Array = grown["points"]
		# The legibility floor applies to what is EMITTED, not just to what is
		# attempted. Arms leave the impact point together, so the jitter can put two
		# of them within a third of a spacing of each other and the trailing one
		# arrests on its neighbour after two steps — physically right, and a 0.02-body
		# stub the renderer would have to draw as a speck. Dropped from the buffer as
		# well as from the output: a mark that does not exist cannot screen anything.
		#
		# `relieve()` is deliberately NOT filtered this way. Its continuations START on
		# an existing tip, so a short one extends a visible line instead of being a
		# speck of its own.
		if pts.size() >= 2 and CrackNet.arc_length(pts) >= MIN_ARM:
			buffer.append(pts)
			out.append({
				"points": pts,
				"terminus": grown["terminus"],
				"origin": blow.at,
			})
		var forks: Array = grown["forks"]
		for f: Variant in forks:
			var fa: Array = f
			if out.size() + pending.size() < MAX_ARMS * 2:
				pending.append(fa)
	return out


## One arm, from `from` heading `dir0`, spending `budget` of length. Returns the
## polyline, why it stopped, and any forks it wants grown.
func _grow(net: CrackNet, buffer: Array[PackedVector2Array], blow: Blow,
		from: Vector2, dir0: Vector2, budget: float) -> Dictionary:
	var pts: PackedVector2Array = PackedVector2Array([from])
	var forks: Array[Array] = []
	var tip: Vector2 = from
	var heading: Vector2 = dir0
	var spent: float = 0.0
	var term: StringName = CrackNet.T_FREE
	for _s: int in range(_max_steps):
		if spent >= budget:
			break
		# The heading is RADIAL — outward from the blow — because a radial crack
		# opens against hoop tension. The blow's direction biases the DRIVE, not the
		# heading. Getting this the other way round makes every crack in the star run
		# parallel instead of radiating (`docs/fracture-model.md` §2.4).
		#
		# Turned TOWARD the radial by a fraction, never set to it. See `RADIAL_PULL`:
		# the assignment this replaces is what made the first kill-test sheet a
		# crosshair. `angle_to` gives the signed shortest turn and cannot degenerate
		# the way lerping two near-opposite directions would.
		var radial: Vector2 = (tip - blow.at)
		if radial.length() > _step:
			heading = heading.rotated(heading.angle_to(radial) * RADIAL_PULL)
		heading = heading.rotated(_rand(-1.0, 1.0) * _grain * _step)
		var next: Vector2 = tip + heading * _step
		# Order matters and is the order in `docs/fracture-model.md` §2.4: out of
		# body first, because a tip outside it cannot be asked about tension.
		if not _mask.reaches(tip, next):
			term = CrackNet.T_SILHOUETTE
			break
		# TWO distances, and keeping them apart is the physics rather than an
		# optimisation. Contact reads the net AND this blow's own in-flight arms,
		# because a crack cannot cross any free surface whenever it was made.
		# Screening reads the net ONLY.
		#
		# Siblings from one blow form SIMULTANEOUSLY — one impact, one release — so
		# they do not relieve each other's tension. Reading the buffer into the
		# screening term instead makes every arm after the first die on its first
		# step, since all arms leave the same point and are therefore inside each
		# other's process zone. That is what `_check_field_radiates` caught: seven
		# arms in, one arm out.
		var d_contact: float = net.nearest(next)
		if not buffer.is_empty():
			d_contact = minf(d_contact, CrackNet.dist_to_strands(buffer, next))
		if d_contact <= _step and pts.size() > 1:
			# Arrest ON the crack it met, not a step short of it: the groove has to
			# end at the seam or the renderer draws a gap.
			pts.append(next)
			term = CrackNet.T_CRACK
			break
		var d_relief: float = net.nearest(next)
		var drive: float = _bias(heading, blow) \
			* (1.0 - (0.0 if d_relief == INF else exp(-d_relief / SCREEN_RADIUS)))
		if drive < _toughness:
			# CAPTURE, not arrest. The only thing that can reduce the drive is an
			# existing crack relieving it, so a tension death always happens inside
			# that crack's process zone — and a crack approaching a free surface is
			# steered INTO it by the relief gradient, terminating on it. Stopping a few
			# steps short instead recorded `F` where the physics says `T`, and would
			# have the renderer draw a groove that ends in mid-glass with a visible gap
			# short of the seam it was running to. That was the `no T-junction at all`
			# failure: twenty strands, every crossing missed by three steps.
			#
			# The final vertex is the nearest point ON the other crack, so the strand
			# genuinely meets it — which the carve needs as much as the renderer does.
			if d_relief < CAPTURE_RADIUS:
				pts.append(net.nearest_point(next))
				term = CrackNet.T_CRACK
			else:
				# Unreachable at the shipped constants and kept anyway: it becomes
				# reachable the moment `TOUGHNESS` is tuned past 1.0, which the lab can
				# do. Deriving the bound is what shows it is currently unreachable —
				# `_bias` is at least 1.0, so a drive under 0.34 needs relief over 0.66,
				# which needs a crack within 0.033 body.
				term = CrackNet.T_FREE
			break
		pts.append(next)
		spent += _step
		if drive > _toughness * FORK_DRIVE and spent > budget * FORK_AFTER \
				and forks.is_empty():
			var side: float = 1.0 if _rng.next() < 0.5 else -1.0
			forks.append([next, heading.rotated(side * FORK_ANGLE),
				(budget - spent) * FORK_SHARE])
		tip = next
	return {"points": pts, "terminus": term, "forks": forks}


# ------------------------------------------------------------------- the rite

## The vessel gives. Every tip that stopped because it ran out of tension runs the
## rest of the way out, at toughness zero — which is the physically true statement
## and also what turns an arrested network into one that partitions the plane. An
## arrested crack is a dangling edge and separates nothing, so a carve without this
## has nothing to cut along (`docs/fracture-model.md` §6.3).
##
## The continuations are NEW strands starting exactly at the old tips, because the
## net is append-only. They join by coincidence of endpoint, which is all the carve
## needs.
func relieve(net: CrackNet) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var buffer: Array[PackedVector2Array] = []
	var was: float = _toughness
	_toughness = 0.0
	# OPEN tips, not free termini. The net is append-only, so a tip that was already
	# carried out keeps its `T_FREE` terminus and only `open_tips()` can tell the
	# difference — asking for the terminus instead makes a second call grow a second
	# continuation from every tip, which is how a death fired twice would double the
	# whole network.
	for i: int in net.open_tips():
		var pts: PackedVector2Array = net.strand(i)
		var tip: Vector2 = pts[pts.size() - 1]
		var prev: Vector2 = pts[pts.size() - 2]
		var heading: Vector2 = (tip - prev).normalized()
		# Carries on from the tip in the direction it was already going, with the
		# ORIGINAL blow point still standing in for the radial centre so the
		# continuation does not curl back on itself.
		var blow: Blow = Blow.new(net.origin(i), Vector2.ZERO, 1.5, 0.5)
		var grown: Dictionary = _grow(net, buffer, blow, tip, heading, 1.5)
		var g: PackedVector2Array = grown["points"]
		if g.size() >= 2:
			buffer.append(g)
			out.append({
				"points": g,
				"terminus": grown["terminus"],
				"origin": net.origin(i),
			})
	_toughness = was
	return out
