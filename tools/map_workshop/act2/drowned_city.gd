extends Node3D
## Precincts occupy verified empty rectangles in the generated city route plan.
const Ward = preload("res://tools/map_workshop/act2/ward.gd")
var sites: Array[Vector3] = []
var failure: String = ""
var placement_evidence: Array[Dictionary] = []
const HALF: Vector2 = Vector2(4.85,3.35)
const ROAD_MARGIN: float = 1.35

func build(causeways: Node3D, library_position: Vector3) -> void:
	var source_lines: Array[PackedVector3Array] = causeways.lines
	var spatial_scale: float = causeways.height_profile.planar_scale
	for source_site: Vector3 in [Vector3(-6,0,-27),Vector3(18,0,-25),Vector3(26,0,0)]:
		var preferred: Vector3 = source_site*spatial_scale
		var choices: Array[Dictionary] = []
		for dx: int in range(-4,5,2):
			for dz: int in range(-4,5,2):
				var at: Vector3 = preferred+Vector3(dx,0,dz)
				if Vector2(at.x-library_position.x,at.z-library_position.z).length()<14:
					continue
				if _clear(at,source_lines):
					choices.append({"at":at,"score":at.distance_to(preferred)})
		choices.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a["score"]<b["score"])
		if choices.is_empty():
			failure = "No clear site for Act II civic precinct "+str(preferred)
			return
		var at: Vector3 = choices[0]["at"]
		var ward: Ward = Ward.new()
		add_child(ward)
		ward.position = at
		ward.build_ward(6.6 if sites.size()==0 else 5.4,sites.size()%2==0)
		sites.append(at)
		placement_evidence.append({"centre":[at.x,at.z],"half_extent":[HALF.x,HALF.y],"route_margin":ROAD_MARGIN,"source_segments_clear":true})
	print("ACT_II_PRECINCTS ",JSON.stringify(placement_evidence))

func _clear(at: Vector3,lines: Array[PackedVector3Array],footprint: Vector2 = HALF) -> bool:
	var half_extent: Vector2 = footprint+Vector2.ONE*ROAD_MARGIN
	var low: Vector2 = Vector2(at.x,at.z)-half_extent
	var high: Vector2 = Vector2(at.x,at.z)+half_extent
	for line: PackedVector3Array in lines:
		for i: int in range(line.size()-1):
			var a: Vector2 = Vector2(line[i].x,line[i].z)
			var b: Vector2 = Vector2(line[i+1].x,line[i+1].z)
			var start: float = 0
			var end: float = 1
			var hit: bool = true
			for axis: int in range(2):
				var delta: float = b[axis]-a[axis]
				if absf(delta)<.000001:
					if a[axis]<low[axis] or a[axis]>high[axis]:
						hit = false
						break
				else:
					var t0: float = (low[axis]-a[axis])/delta
					var t1: float = (high[axis]-a[axis])/delta
					start = maxf(start,minf(t0,t1))
					end = minf(end,maxf(t0,t1))
					if start>end:
						hit = false
						break
			if hit:
				return false
	return true
