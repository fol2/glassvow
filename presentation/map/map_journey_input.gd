extends RefCounted
## Presentation input only. Domain records, node IDs and the v2 save are untouched.
## The save JSON loses a few binary64 tail bits. Canonicalise only visual jitter
## to one billionth of a lane unit, so live/loaded maps share their derived surface.
const JITTER_QUANTUM: float = .000000001
static func bind(world: WorldMap, act: int) -> Dictionary:
	var out: Dictionary = MapLayoutInputBinding.bind(world,act)
	if out.get("ok")!=true: return out
	for node: Dictionary in out["nodes"]:
		for axis: int in range(2):
			node["jitter"][axis]=snappedf(MapLayoutCanonical.float_value(node["jitter"][axis]),JITTER_QUANTUM)
	return out
