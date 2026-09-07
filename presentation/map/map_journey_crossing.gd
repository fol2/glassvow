extends RefCounted
## Local perpendicular decks preserve a short crossing within physical approaches.
const F = preload("res://domain/map_layout/map_layout_canonical.gd")

static func repair(routes: Dictionary, quality: Dictionary, failed: Dictionary) -> Dictionary:
	var binding: Dictionary = failed.get("binding",{})
	if binding.get("id")!="two_level_infeasible": return failed
	var details: Dictionary = binding.get("details",{})
	var conflicts: Array = details.get("conflicts",[])
	if conflicts.is_empty() or conflicts.size()>MapGradeSeparation.MAX_ORIENTATION_CONFLICTS:
		return failed
	var profile: Dictionary = MapGradeSeparation.physical_profile(quality)
	var landing: float = F.float_value(profile.get("landing_m",0.0))
	for trial: int in range(2*(1<<conflicts.size())):
		var mask: int = trial % (1<<conflicts.size())
		var balance: bool = trial >= (1<<conflicts.size())
		var proposal: Dictionary = routes.duplicate(true)
		var valid: bool = true
		for i: int in range(conflicts.size()):
			var ids: Array = conflicts[i]["edge_ids"]
			if ids.size()!=2: return failed
			var selected: int = (mask>>i)&1
			var upper: Dictionary = proposal[ids[selected]]
			var lower: Dictionary = proposal[ids[1-selected]]
			valid = _chord(upper,lower,landing,balance) and valid
		if not valid: continue
		var graded: Dictionary = MapGradeSeparation.apply(proposal,quality)
		if graded.get("ok")==true:
			graded["receipt"]["crossing_proposal"]={"version":"perpendicular-chord-v1","mask":mask,"balanced":balance}
			return graded
	return failed

static func _chord(upper: Dictionary, lower: Dictionary, landing: float, balance: bool) -> bool:
	var line: Array = upper["centerline"]
	var ground: Array = lower["centerline"]
	var reach: float = (F.float_value(upper["corridor_width"])+F.float_value(lower["corridor_width"]))/2+landing*.5
	for i: int in range(line.size()-1):
		var a: Vector2 = _xz(line[i])
		var b: Vector2 = _xz(line[i+1])
		for j: int in range(ground.size()-1):
			var c: Vector2 = _xz(ground[j])
			var d: Vector2 = _xz(ground[j+1])
			var intersection: Variant = Geometry2D.segment_intersects_segment(a,b,c,d)
			if not intersection is Vector2: continue
			var centre: Vector2 = intersection
			if balance and absf(d.x-c.x)>.0001:
				var t: float = clampf(((a.x+b.x)*.5-c.x)/(d.x-c.x),.1,.9)
				centre=c.lerp(d,t)
			var direction: Vector2 = (d-c).normalized().orthogonal()
			if direction.dot(b-a)<0: direction=-direction
			var before: Vector2 = centre-direction*reach
			var after: Vector2 = centre+direction*reach
			# Journey station order stays monotone; endpoints and branch ports remain.
			if before.x<a.x or after.x<before.x or after.x>b.x: return false
			var changed: Array = line.slice(0,i+1)
			changed.append([before.x,0.0,before.y])
			changed.append([after.x,0.0,after.y])
			changed.append_array(line.slice(i+1))
			upper["centerline"]=changed
			return true
	return false

static func _xz(value: Variant) -> Vector2:
	var point: Array = value
	return Vector2(F.float_value(point[0]),F.float_value(point[2]))
