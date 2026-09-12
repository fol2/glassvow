extends RefCounted
## Frame actual entry and terminal architecture without changing selectable nodes.
static func terminals(data: Dictionary, assets: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var departures: Dictionary = {}
	var arrivals: Dictionary = {}
	for edge: Dictionary in data["edges"].values():
		departures[edge["from"]]=true
		arrivals[edge["to"]]=true
	for role: String in ["terminus","vigil"]:
		var placement: Dictionary = data["hero_placements"].get(role,{})
		if placement.is_empty(): continue
		var profile: Dictionary = assets["profiles"].get(placement["profile_id"],{})
		if not profile.get("local_aabb") is AABB: continue
		var box: AABB = profile["local_aabb"]
		var pose: Dictionary = placement["transform"]
		var basis: Basis = Basis(Vector3.UP,MapLayoutCanonical.float_value(pose["yaw_radians"]))
		basis=basis.scaled_local(MapLandscape.v3(pose["scale"]))
		var transform: Transform3D = Transform3D(basis,MapLandscape.v3(pose["origin"]))
		var corners: PackedVector3Array = []
		for i: int in range(8): corners.append(transform*box.get_endpoint(i))
		for id: String in data["node_anchors"]:
			if (role=="terminus" and not departures.has(id)) or (role=="vigil" and not arrivals.has(id)):
				out[id]=corners
	return out
