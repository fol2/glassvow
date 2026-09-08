extends RefCounted
## Fixed physical audit density, independent of the renderer's route sampling.
static func sample(source: PackedVector3Array, spacing: float = .2) -> PackedVector3Array:
	if source.is_empty(): return []
	var result: PackedVector3Array = [source[0]]
	for i: int in range(1,source.size()):
		var count: int = maxi(1,ceili(source[i-1].distance_to(source[i])/spacing))
		for station: int in range(1,count+1):
			result.append(source[i-1].lerp(source[i],float(station)/count))
	return result
