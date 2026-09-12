extends RefCounted
## One bounded presentation curve for earth, ramps and bridge stonework.
## Generated anchors and the authoritative graph remain unchanged.
static func soften(source: PackedVector3Array) -> PackedVector3Array:
	var result: PackedVector3Array = [source[0]]
	for i: int in range(1,source.size()-1):
		var at: Vector3 = source[i]
		var incoming: float = at.distance_to(source[i-1])
		var outgoing: float = at.distance_to(source[i+1])
		# Preserve the compiled rise and landing planes at elevation changes.
		if not is_equal_approx(source[i-1].y,at.y) or not is_equal_approx(source[i+1].y,at.y):
			result.append(at)
			continue
		var bisector: float = ((source[i-1]-at).normalized()+(source[i+1]-at).normalized()).length()*.5
		var trim: float = minf(.34/maxf(.34,bisector),minf(incoming,outgoing)*.44)
		var a: Vector3 = at.move_toward(source[i-1],trim)
		var b: Vector3 = at.move_toward(source[i+1],trim)
		for step: int in range(9):
			var t: float = step/8.0
			result.append(a.lerp(at,t).lerp(at.lerp(b,t),t))
	result.append(source[-1])
	return result

static func sample(source: PackedVector3Array, spacing: float = .2) -> PackedVector3Array:
	var curve: PackedVector3Array = soften(source)
	var result: PackedVector3Array = [curve[0]]
	for i: int in range(curve.size()-1):
		var count: int = maxi(1,ceili(curve[i].distance_to(curve[i+1])/spacing))
		for step: int in range(1,count+1):
			var p: Vector3 = curve[i].lerp(curve[i+1],float(step)/count)
			if p.distance_to(result[-1])>.001:
				result.append(p)
	return result
