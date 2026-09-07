extends "res://presentation/map/landscape/bridge_surfaces.gd"
var stair_profile: RefCounted
var _boundary_positions: Dictionary = {}
## Compact interpolation removes nearest-segment creases on the outside of bends.
func setup(source: Array[Dictionary],height: Callable,deck_profile: Callable = Callable()) -> void:
	_boundary_positions.clear()
	cells.clear()
	vertices.clear()
	super.setup(source,height,deck_profile)
	# Include the entire interpolation support around widened node landings.
	# Reusing the narrower outline index made that support change at cell edges.
	cells.clear()
	for span: Dictionary in spans:
		var a: Vector3 = span["a"]
		var b: Vector3 = span["b"]
		var low: Vector2 = Vector2(minf(a.x,b.x),minf(a.z,b.z))-Vector2.ONE*1.65
		var high: Vector2 = Vector2(maxf(a.x,b.x),maxf(a.z,b.z))+Vector2.ONE*1.65
		for x: int in range(floori(low.x/CELL),ceili(high.x/CELL)+1):
			for z: int in range(floori(low.y/CELL),ceili(high.y/CELL)+1):
				var key: Vector2i = Vector2i(x,z)
				if not cells.has(key):
					cells[key] = []
				cells[key].append(span)

func field(at: Vector2) -> Dictionary:
	var result: Dictionary = super.field(at)
	var candidates: Array = cells.get(Vector2i(floori(at.x/CELL),floori(at.y/CELL)),[])
	var flights: Dictionary = {}
	var height_sum: float = 0
	var weight_sum: float = 0
	for span: Dictionary in candidates:
		var a: Vector3 = span["a"]
		var b: Vector3 = span["b"]
		var start: Vector2 = Vector2(a.x,a.z)
		var finish: Vector2 = Vector2(b.x,b.z)
		var delta: Vector2 = finish-start
		var t: float = clampf((at-start).dot(delta)/maxf(.000001,delta.length_squared()),0,1)
		var d2: float = at.distance_squared_to(start+delta*t)
		var kernel: float = maxf(0,1.0-d2/2.25)
		var weight: float = kernel*kernel*kernel*delta.length()/(.02+d2)
		var height: float = lerpf(a.y,b.y,t)
		if stair_profile!=null and weight>0:
			var owner: String = str(span.get("edge",""))
			if not flights.has(owner): flights[owner]=stair_profile.sample(at,owner)
			var fitted: Vector2 = flights[owner]
			height=lerpf(height,fitted.x-.022,fitted.y)
		height_sum += height*weight
		weight_sum += weight
	if weight_sum>.000000001:
		result["height"] = height_sum/weight_sum+.022
		# Keep the nearest arch profile: averaging it pinches the solid piers.
		# Deck heights still use the smooth multi-span blend above.
	return result

func _position(item: Dictionary) -> Vector3:
	var result: Vector3 = super._position(item)
	var distance: float = item["distance"]
	if absf(distance)<.00000001:
		# A clipping edge lies between an inside sample and an outside sample.
		# The outside sample can belong to another leg of a tight bend; do not
		# interpolate that unrelated height into the road's actual boundary.
		var key: Vector2 = Vector2(result.x,result.z)
		if not _boundary_positions.has(key):
			_boundary_positions[key] = field(key)["height"]
		result.y = _boundary_positions[key]
	return result
