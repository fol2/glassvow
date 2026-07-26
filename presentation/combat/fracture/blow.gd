class_name Blow
extends RefCounted
## One impact, as the fracture model sees it. Everything a blow needs and nothing
## a blow does not: no damage number, no archetype, no colour, no timing. The
## caller converts at the boundary, which is what keeps the model free of the
## game's vocabulary — see `docs/fracture-model.md` §2.5.
##
## Coordinates are **body UV, y down, 0..1**, matching how `body_tex` is sampled
## so a crack cannot disagree with the painting it is scored into. Lengths are
## body-relative: 1.0 is the art box's smaller side, which is what lets one
## parameter set serve a 115px sporeling and a 1120px leviathan without
## per-creature authoring (`docs/fracture-model.md` §3).


## Where it landed.
var at: Vector2 = Vector2(0.5, 0.5)
## Heading, unit length. **Zero length means a face-on impact** with no preferred
## axis, which is a real case (a fall, a crush) and not a missing value — so it is
## the default rather than an error.
var dir: Vector2 = Vector2.ZERO
## Dimensionless. 1.0 buys one body-width of crack, before screening takes its
## cut. The conversion from a damage integer lives at the boundary and is the
## model's one honest fudge (`docs/fracture-model.md` §3).
var energy: float = 0.0
## Indenter acuity, 0 blunt .. 1 sharp. Sets the radial/concentric energy split:
## a point splits the plate along radials, a broad face flexes it into rings.
var sharp: float = 0.5


func _init(p_at: Vector2 = Vector2(0.5, 0.5), p_dir: Vector2 = Vector2.ZERO,
		p_energy: float = 0.0, p_sharp: float = 0.5) -> void:
	at = p_at
	# Normalised here rather than trusted, because every caller computes it
	# differently — one from a drag vector, one from which side the foe stands on.
	dir = p_dir.normalized() if p_dir.length() > 0.0 else Vector2.ZERO
	energy = maxf(0.0, p_energy)
	sharp = clampf(p_sharp, 0.0, 1.0)


func _to_string() -> String:
	return "Blow(at=%.3v dir=%.3v energy=%.3f sharp=%.2f)" % [at, dir, energy, sharp]
