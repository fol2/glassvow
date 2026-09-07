extends Node3D
## Intact enclosing galleries reserve the generated routes and their full stairs.
const M = preload("res://presentation/map/landscape/mesh_tools.gd")
const Envelope = preload("res://presentation/map/chapters/common/precinct_envelope.gd")
const Occupancy = preload("res://presentation/map/chapters/common/architectural_occupancy.gd")
const Kit = preload("res://presentation/map/chapters/act3/kit.gd")
var kit: Kit = Kit.new()
var buildings: Array[Node3D] = []
var world: Node3D
var stone: Material
var failure: String = ""
var collision_count: int = 0
func build(courts: Node3D,boss: Vector3) -> void:
	world=self
	stone=courts.stone
	var rows: Array = courts.rows
	var envelopes: Array[Dictionary] = courts.envelopes
	var architecture_routes: Dictionary = courts.architecture_routes
	var divisions: Array[float] = courts.divisions
	var west: float = envelopes[0]["west"]
	var landscape_openings: Array[Rect2] = []
	# Hall front faces the sovereign forecourt; the terminal node stays generated.
	var hall: Node3D = _asset("obsidian-great-hall")
	hall.position=boss+Vector3(18,0,0)
	hall.rotation.y=-PI*.5
	var hall_box: AABB = Occupancy.bounds(hall)
	_box(Vector3(hall_box.get_center().x,boss.y*.5-.5,hall_box.get_center().z),
		Vector3(hall_box.size.x+1,boss.y+1,hall_box.size.z+1),stone)
	_box(Vector3(boss.x+10,boss.y*.5-.04,boss.z),Vector3(28,boss.y+.08,30),stone)
	# Outer gallery provides enclosure, with pauses marking the four precincts.
	for interval: Vector2 in [Vector2(west+10,divisions[0]-8),Vector2(divisions[0]+8,divisions[1]-8),Vector2(divisions[1]+8,divisions[2]-8)]:
		var x: float = interval.x
		while x <= interval.y:
			var bay: Node3D = _asset("covered-cloister-bay")
			bay.position = Vector3(x,0,Envelope.at_x(envelopes,x).x+3)
			x += 7.5
	# Short returns frame thresholds without scattering freestanding pavilions.
	for x: float in [west+5,divisions[0],divisions[1],divisions[2]]:
		var local_bounds: Vector2 = Envelope.at_x(envelopes,x)
		for z: float in [local_bounds.x+7,local_bounds.y-7]:
			var bay: Node3D = _asset("glazed-gallery-bay")
			bay.position = Vector3(x,0,z)
			# Move the entire return outwards within a bounded placement search.
			bay.rotation.y = PI*.5
			var placed: bool = false
			for orientation: float in [PI*.5,0.0]:
				bay.rotation.y = orientation
				bay.position.z = z if orientation != 0.0 else (local_bounds.x+3 if z < (local_bounds.x+local_bounds.y)*.5 else local_bounds.y-3)
				for offset: float in [0.0,-2.0,2.0,-4.0,4.0,-6.0,6.0,-8.0,8.0,-10.0,10.0]:
					bay.position.x = x+offset
					bay.position.y = _court_height(bay.position.x,rows)
					var edge_z: float = z if orientation != 0.0 else (local_bounds.x+3 if z < (local_bounds.x+local_bounds.y)*.5 else local_bounds.y-3)
					var inward: float = 1.0 if z < (local_bounds.x+local_bounds.y)*.5 else -1.0
					for inset: float in [0.0,1.5,3.0]:
						bay.position.z = edge_z+inward*inset
						var box: AABB = Occupancy.bounds(bay)
						if Envelope.supports(box,envelopes,landscape_openings) and is_equal_approx(_court_height(box.position.x,rows),_court_height(box.end.x,rows)) and Occupancy.conflicts(box,architecture_routes).is_empty() and not Occupancy.overlaps_buildings(bay,buildings):
							placed = true
							break
					if placed:
						break
				if placed:
					break
			if not placed:
				failure="No legal gallery placement at threshold "+str(x)
				return
	# Opposing, inward-facing galleries form courts; central gaps preserve views
	# from the journey camera instead of closing the foreground with a tall wall.
	for region_index: int in range(3):
		var region: Dictionary = envelopes[region_index]
		var left: float = region["west"]
		var right: float = region["east"]
		var available: float = right-left-28.0
		var count: int = mini(4,maxi(0,int(available/7.5)))
		for bay_index: int in range(count):
			var from_left: bool = bay_index < (count+1)/2
			var offset_index: int = bay_index if from_left else count-1-bay_index
			var x: float = left+14.0+offset_index*7.5 if from_left else right-14.0-offset_index*7.5
			var bay: Node3D = _asset("cloister-bay")
			bay.rotation.y = PI
			bay.position = Vector3(x,_court_height(x,rows),MapLayoutCanonical.float_value(region["far"])-3.0)
			var placed: bool = false
			for offset: float in [0.0,-2.0,2.0,-4.0,4.0,-6.0,6.0]:
				bay.position.x = x+offset
				var box: AABB = Occupancy.bounds(bay)
				if Envelope.supports(box,envelopes,landscape_openings) and Occupancy.conflicts(box,architecture_routes).is_empty() and not Occupancy.overlaps_buildings(bay,buildings):
					placed = true
					break
			if not placed:
				buildings.erase(bay)
				bay.free()
	# The sovereign enclosure continues the cloisters into the hall precinct.
	# Its open foreground preserves the close camera's view of the final ascent.
	var royal_bounds: Vector2 = Envelope.at_x(envelopes,boss.x)
	for side: int in [-1,1]:
		var royal_z: float = royal_bounds.x+3.0 if side == -1 else royal_bounds.y-3.0
		var royal_x: float = divisions[2]+10.0
		while royal_x < hall_box.end.x-3.75:
			var bay: Node3D = _asset("covered-cloister-bay" if side == -1 else "cloister-bay")
			bay.position = Vector3(royal_x,boss.y,royal_z)
			bay.rotation.y = 0.0 if side == -1 else PI
			var box: AABB = Occupancy.bounds(bay)
			var clear: bool = Envelope.supports(box,envelopes) and Occupancy.conflicts(box,architecture_routes).is_empty() and not Occupancy.overlaps_buildings(bay,buildings)
			# Keep the near half of the foreground court open, not a screen of walls.
			if not clear or (side == 1 and royal_x < boss.x+5.0):
				buildings.erase(bay)
				bay.free()
			royal_x += 7.5
	for building: Node3D in buildings:
		if building.get_meta("asset_name","") == "glazed-gallery-bay":
			Kit.glazing_light(building,Vector3(0,2.8,2.0),7.0,2.4)
	Kit.glazing_light(hall,Vector3(-8.25,4.0,13.0),9.0,3.0)
	Kit.glazing_light(hall,Vector3(8.25,4.0,13.0),9.0,3.0)
	for building: Node3D in buildings:
		if building != hall:
			building.position.y = _court_height(building.position.x,rows)
		var box: AABB = Occupancy.bounds(building)
		if building != hall and not Envelope.supports(box,envelopes,landscape_openings):
			failure="Building footprint leaves its supporting court: "+str(building.name)
			return
		var clashes: Array[String] = Occupancy.conflicts(box,architecture_routes)
		collision_count += clashes.size()

	if collision_count>0: failure="Court architecture obstructs generated routes: "+str(collision_count)
func _box(position: Vector3, size: Vector3, material: Material) -> void:
	var instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	world.add_child(instance)
func _asset(asset_name: String) -> Node3D:
	var item: Node3D = kit.instance(asset_name)
	world.add_child(item)
	buildings.append(item)
	return item

func _court_height(x: float, rows: Array) -> float:
	var value: float = MapLayoutCanonical.float_value(rows[0]["height_m"])
	for i: int in range(1,rows.size()):
		var boundary: float = (MapLayoutCanonical.float_value(rows[i-1]["station_m"])+MapLayoutCanonical.float_value(rows[i]["station_m"]))*.5
		if x < boundary:
			break
		value = MapLayoutCanonical.float_value(rows[i]["height_m"])
	return value
