extends RefCounted
## Frame terminal architecture from the actual imported geometry, without making
## its corners selectable targets or moving the generator's route anchors.
static func terminals(data: Dictionary, assets: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var placement: Dictionary = data["hero_placements"].get("terminus",{})
	if placement.is_empty(): return out
	var profile: Dictionary = assets["profiles"].get(placement["profile_id"],{})
	if not profile.get("local_aabb") is AABB: return out
	var box: AABB = profile["local_aabb"]
	var pose: Dictionary = placement["transform"]
	var basis: Basis = Basis(Vector3.UP,MapLayoutCanonical.float_value(pose["yaw_radians"]))
	basis=basis.scaled_local(MapLandscape.v3(pose["scale"]))
	var transform: Transform3D = Transform3D(basis,MapLandscape.v3(pose["origin"]))
	var corners: PackedVector3Array = []
	for i: int in range(8): corners.append(transform*box.get_endpoint(i))
	var departures: Dictionary = {}
	for edge: Dictionary in data["edges"].values(): departures[edge["from"]]=true
	for id: String in data["node_anchors"]:
		if not departures.has(id): out[id]=corners
	return out
