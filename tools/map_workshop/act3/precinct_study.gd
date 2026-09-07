extends SceneTree
## Private whole-place composition experiment. Reserves are not yet certified.
const Inspector = preload("res://tools/map_workshop/act3/precinct_inspection.gd")
const M = preload("res://presentation/map/landscape/mesh_tools.gd")
const Envelope = preload("res://tools/map_workshop/common/precinct_envelope.gd")
const CourtStairs = preload("res://tools/map_workshop/common/court_stair_assembly.gd")
const Occupancy = preload("res://tools/map_workshop/common/architectural_occupancy.gd")
var buildings: Array[Node3D] = []
var world: Node3D
var stone: Material
var asset_templates: Dictionary = {}
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var build_started: int = Time.get_ticks_usec()
	var viewport_size: Vector2i = Vector2i(1458,820)
	var sample_path: String = "res://docs/map/studies/act3-step3/precinct-v2-seed717.json"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--viewport="):
			var parts: PackedStringArray = argument.trim_prefix("--viewport=").split("x")
			viewport_size = Vector2i(parts[0].to_int(),parts[1].to_int())
		if argument.begins_with("--sample="):
			sample_path = argument.trim_prefix("--sample=")
	var sample: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(sample_path))
	var spatial: Dictionary = sample["spatial_profile"]
	var rows: Array = spatial["rows"]
	var bounds: Array = spatial["bounds_xz_m"]
	var west: float = MapLayoutCanonical.float_value(bounds[0])
	var east: float = MapLayoutCanonical.float_value(bounds[2])
	var near_z: float = MapLayoutCanonical.float_value(bounds[1])
	var far_z: float = MapLayoutCanonical.float_value(bounds[3])
	var divisions: Array[float] = []
	for index: int in range(1,rows.size()):
		if rows[index].get("region") == rows[index-1].get("region"):
			continue
		divisions.append((MapLayoutCanonical.float_value(rows[index-1]["station_m"])+MapLayoutCanonical.float_value(rows[index]["station_m"]))*.5)
	root.content_scale_size = viewport_size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.size = viewport_size
	root.msaa_3d = Viewport.MSAA_4X
	world = Node3D.new()
	root.add_child(world)
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("121019")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("b9b5d2")
	env.environment.ambient_light_energy = .20
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment.tonemap_exposure = .70
	world.add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48,-30,0)
	sun.light_color = Color("d1cbe0")
	sun.light_energy = 1.5
	sun.light_specular = .16
	sun.shadow_enabled = "--diagnostic-no-shadows" not in OS.get_cmdline_user_args()
	sun.directional_shadow_max_distance = 240
	world.add_child(sun)
	var rim: DirectionalLight3D = DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-22,145,0)
	rim.light_color = Color("9c8bc5")
	rim.light_energy = .4
	rim.light_specular = .2
	rim.shadow_enabled = false
	world.add_child(rim)
	stone = _stone_material(ObsidianFinish.STONE,ObsidianFinish.SLAB_METRES,ObsidianFinish.JOINT_COVERAGE,ObsidianFinish.JOINT_STRENGTH)
	ObsidianFinish.apply_world(stone as ShaderMaterial)
	var paving: ShaderMaterial = stone as ShaderMaterial
	# All graph routes remain visible: no discarded edges to rescue composition.
	var edges: Dictionary = sample["edges"]
	var region_stations: Array[float] = [west,divisions[0],divisions[1],divisions[2],east]
	var envelopes: Array[Dictionary] = Envelope.regions(edges,region_stations)
	var terminal: Vector3 = _point(sample["anchors"]["14,3"])
	envelopes[-1]["near"] = minf(MapLayoutCanonical.float_value(envelopes[-1]["near"]),terminal.z-18)
	envelopes[-1]["far"] = maxf(MapLayoutCanonical.float_value(envelopes[-1]["far"]),terminal.z+18)
	var route_plans: Array[Dictionary] = []
	var plans_by_id: Dictionary = {}
	for id: String in edges:
		var edge: Dictionary = edges[id]
		var line: PackedVector3Array = []
		for point: Variant in edge["centerline"]:
			line.append(_point(point))
		var plan: Dictionary = preload("res://tools/map_workshop/common/resolved_route_surface.gd").resolve(line,2.5,-1,.65)
		if plan.get("ok") != true:
			push_error("Unresolved route "+id+": "+str(plan))
			quit(1)
			return
		route_plans.append(plan)
		plans_by_id[id] = plan
	var architecture_routes: Dictionary = edges.duplicate(true)
	var stair_groups: Array[Dictionary] = []
	if spatial.get("stair_version", "") == "transverse-court-v1":
		var assembly: Dictionary = CourtStairs.resolve(route_plans,divisions)
		if assembly.get("ok") != true:
			push_error(str(assembly))
			quit(1)
			return
		route_plans = assembly["plans"]
		stair_groups = assembly["groups"]
		var reserves: Dictionary = assembly["reserves"]
		architecture_routes.merge(reserves)
	var union_start: int = Time.get_ticks_usec()
	var joined: Dictionary = preload("res://tools/map_workshop/common/walking_surface_union.gd").resolve(route_plans)
	if joined.get("ok") != true:
		push_error(str(joined))
		quit(1)
		return
	print("WALKING_UNION removed_m2=",joined["removed_overlap_m2"]," build_ms=",(Time.get_ticks_usec()-union_start)/1000.0)
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = "ResolvedWalking"
	instance.mesh = preload("res://tools/map_workshop/common/flight_mesh.gd").build(joined)
	instance.material_override = paving
	world.add_child(instance)
	var landscape_openings: Array[Rect2] = []
	if "--landscape-openings" in OS.get_cmdline_user_args():
		landscape_openings = preload("res://tools/map_workshop/common/court_landscape_openings.gd").select(envelopes,edges)
	print("LANDSCAPE_OPENINGS count=",landscape_openings.size())
	var patches: Array[Dictionary] = []
	var court_heights: Array[float] = []
	for region: Dictionary in envelopes:
		var x0: float = region["west"]
		var x1: float = region["east"]
		var z0: float = region["near"]
		var z1: float = region["far"]
		var height: float = _court_height((x0+x1)*.5,rows)
		court_heights.append(height)
		patches.append({"height":height,"outline":PackedVector2Array([
			Vector2(x0,z0),Vector2(x1,z0),Vector2(x1,z1),Vector2(x0,z1)])})
		for piece: Rect2 in preload("res://tools/map_workshop/common/court_landscape_openings.gd").subtract(Rect2(x0,z0,x1-x0,z1-z0),landscape_openings):
			_box(Vector3(piece.get_center().x,-1.05,piece.get_center().y),Vector3(piece.size.x,2,piece.size.y),stone)
	var plinth_material: StandardMaterial3D = M.material(Color("373441"),.7)
	var terrain_reserves: Array[Rect2] = []
	var terrain_bounds: Rect2 = Rect2(Vector2(west,near_z),Vector2(east-west,far_z-near_z))
	for region: Dictionary in envelopes:
		var reserve: Rect2 = Rect2(Vector2(MapLayoutCanonical.float_value(region["west"]),MapLayoutCanonical.float_value(region["near"])),Vector2(MapLayoutCanonical.float_value(region["east"])-MapLayoutCanonical.float_value(region["west"]),MapLayoutCanonical.float_value(region["far"])-MapLayoutCanonical.float_value(region["near"])))
		terrain_reserves.append(reserve.grow(2.0))
		terrain_bounds = terrain_bounds.merge(reserve)
	var terrain_profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/map_workshop/act3/terrain-profile.json"))
	terrain_profile = preload("res://tools/map_workshop/common/landscape_relief.gd").resolve_profile(terrain_profile,terrain_reserves)
	var terrain_contact_reserves: Array[Rect2] = []
	for reserve: Rect2 in terrain_reserves:
		terrain_contact_reserves.append_array(preload("res://tools/map_workshop/common/court_landscape_openings.gd").subtract(reserve,landscape_openings))
	var terrain_mesh: MeshInstance3D = preload("res://tools/map_workshop/common/landscape_relief.gd").build(terrain_bounds.grow(32),terrain_profile,terrain_contact_reserves,M.material(Color("24232e"),.95))
	world.add_child(terrain_mesh)
	plinth_material.vertex_color_use_as_albedo = true
	preload("res://tools/map_workshop/common/precinct_plinth.gd").build(world,envelopes,court_heights,plinth_material)
	var court_masks: Array[Dictionary] = route_plans.duplicate()
	for opening: Rect2 in landscape_openings:
		court_masks.append(preload("res://tools/map_workshop/common/court_landscape_openings.gd").mask(opening,-.1))
	var court: Dictionary = preload("res://tools/map_workshop/common/court_surface.gd").resolve(patches,court_masks)
	if court.get("ok") != true:
		push_error(str(court))
		quit(1)
		return
	var court_mesh: MeshInstance3D = MeshInstance3D.new()
	court_mesh.name = "CourtSurface"
	court_mesh.mesh = preload("res://tools/map_workshop/common/flight_mesh.gd").build(court)
	court_mesh.material_override = stone
	world.add_child(court_mesh)
	print("COURT_SURFACE triangles=",court["tops"].size())
	var anchors: Dictionary = sample["anchors"]
	var boss: Vector3 = _point(anchors["14,3"])
	# The seal is in the existing walking material, not a coplanar decal mesh.
	for floor_material: ShaderMaterial in [stone as ShaderMaterial,paving]:
		floor_material.set_shader_parameter("inlay_centre",boss)
		floor_material.set_shader_parameter("inlay_radius",8.5)
		floor_material.set_shader_parameter("inlay_colour",Color("62516d"))
	var halo: Node3D = preload("res://tools/map_workshop/act3/sovereign_halo.gd").new()
	halo.position = boss+Vector3(0,7.2,0)
	halo.rotation_degrees = Vector3(48,0,18)
	world.add_child(halo)
	# Hall front faces the sovereign forecourt; the terminal node stays generated.
	var hall_source: String = "res://tools/map_workshop/act3/kit/obsidian-great-hall.glb"
	var hall_binding: Dictionary = sample.get("hero_placements",{}).get("terminus",{})
	if hall_binding.get("asset_id") == "act3-obsidian-great-hall":
		var source: Dictionary = sample["hero_sources"][hall_binding["asset_id"]]
		hall_source = str(source["path"])
		if FileAccess.get_sha256(hall_source) != str(source["sha256"]):
			push_error("Hero asset changed since layout generation")
			quit(1)
			return
	var hall: Node3D = _asset("obsidian-great-hall",hall_source)
	hall.position = Vector3(boss.x+16,boss.y,boss.z)
	hall.rotation.y = -PI*.5
	if hall_binding.get("asset_id") == "act3-obsidian-great-hall":
		var transform: Dictionary = hall_binding["transform"]
		hall.position = _point(transform["origin"])
		hall.rotation.y = MapLayoutCanonical.float_value(transform["yaw_radians"])
		hall.scale = _point(transform["scale"])
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
				push_error("No legal gallery placement at threshold "+str(x))
				quit(1)
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
			_glazing_light(building,Vector3(0,2.8,2.0),7.0,2.4)
	_glazing_light(hall,Vector3(-8.25,4.0,13.0),9.0,3.0)
	_glazing_light(hall,Vector3(8.25,4.0,13.0),9.0,3.0)
	var occupancy_report: Array = []
	var collision_count: int = 0
	for building: Node3D in buildings:
		if building != hall:
			building.position.y = _court_height(building.position.x,rows)
		var box: AABB = Occupancy.bounds(building)
		if building != hall and not Envelope.supports(box,envelopes,landscape_openings):
			push_error("Building footprint leaves its supporting court: "+str(building.name))
			quit(1)
			return
		var clashes: Array[String] = Occupancy.conflicts(box,architecture_routes)
		collision_count += clashes.size()
		occupancy_report.append({"asset":building.name,"position":[building.position.x,building.position.y,building.position.z],
			"bounds_position":[box.position.x,box.position.y,box.position.z],
			"bounds_size":[box.size.x,box.size.y,box.size.z],"route_conflicts":clashes})
	var receipt: FileAccess = FileAccess.open("/tmp/act3-precinct-occupancy.json",FileAccess.WRITE)
	receipt.store_string(JSON.stringify({"buildings":occupancy_report,"route_conflicts":collision_count},"\t"))
	receipt.close()
	print("ARCHITECTURE_OCCUPANCY conflicts=",collision_count)
	var trim_material: StandardMaterial3D = M.material(Color("323544"),.38)
	trim_material.emission_enabled = true
	trim_material.emission = Color(.07,.002,.04)
	var thresholds: Array = []
	var threshold_roots: Array[Node3D] = []
	for threshold_x: float in divisions:
		var local_bounds: Vector2 = Envelope.at_x(envelopes,threshold_x)
		var threshold: Dictionary = preload("res://tools/map_workshop/common/precinct_threshold.gd").plan(edges,threshold_x,local_bounds.x,local_bounds.y)
		if not stair_groups.is_empty():
			threshold = CourtStairs.threshold(stair_groups,threshold_x,local_bounds.x,local_bounds.y)
		if threshold.get("ok") != true:
			push_error(str(threshold))
			quit(1)
			return
		# Internal court stairs are open-air; pointed vaults belong to the galleries.
		if not stair_groups.is_empty():
			threshold_roots.append(CourtStairs.build_retaining(world,threshold,stone,trim_material))
		else:
			threshold_roots.append(preload("res://tools/map_workshop/common/precinct_threshold.gd").build(world,threshold,stone,trim_material,0.0))
		thresholds.append(threshold)
	var threshold_file: FileAccess = FileAccess.open("/tmp/act3-thresholds.json",FileAccess.WRITE)
	threshold_file.store_string(JSON.stringify(thresholds,"\t"))
	threshold_file.close()
	if "--audit-obstruct-threshold" in OS.get_cmdline_user_args():
		M.box(threshold_roots[0],Vector3(divisions[0],2.2,0),Vector3(1.6,.2,far_z-near_z),stone,"AuditOnlyObstruction")
	if "--audit-thresholds" in OS.get_cmdline_user_args():
		var audit: Dictionary = preload("res://tools/map_workshop/common/threshold_mesh_audit.gd").run(threshold_roots,instance,edges,false)
		audit["scope"] = "all route widths: actual walking support and open-air threshold obstruction"
		audit["input_digest"] = sample["input_digest"]
		audit["layout_digest"] = sample["layout_digest"]
		var audit_file: FileAccess = FileAccess.open("/tmp/act3-threshold-mesh-audit.json",FileAccess.WRITE)
		audit_file.store_string(JSON.stringify(audit,"\t"))
		audit_file.close()
		print("THRESHOLD_MESH_AUDIT ok=",audit["ok"]," probes=",audit["probe_count"]," minimum=",audit["minimum_headroom_m"])
		if audit["ok"] != true:
			quit(1)
			return
	var masonry: Array[Node3D] = []
	for pair: Array in _passage_pairs(edges):
		var upper: Dictionary = edges[pair[0]]
		var lower: Dictionary = edges[pair[1]]
		masonry.append(preload("res://tools/map_workshop/common/passage_masonry.gd").build(world,upper,lower,stone,true))
	if "--audit-obstruct-foundation" in OS.get_cmdline_user_args():
		var at: Vector3 = _point(anchors[sample["current"]])
		M.box(masonry[0],at+Vector3(0,.6,0),Vector3(4,.2,4),stone,"AuditOnlyFoundationObstruction")
	if "--audit-foundations" in OS.get_cmdline_user_args():
		var audit: Dictionary = preload("res://tools/map_workshop/common/foundation_audit.gd").run(masonry,instance,edges,buildings)
		var audit_file: FileAccess = FileAccess.open("/tmp/act3-foundation-audit.json",FileAccess.WRITE)
		audit_file.store_string(JSON.stringify(audit,"\t"))
		audit_file.close()
		print("FOUNDATION_AUDIT ",JSON.stringify(audit))
		if audit["ok"] != true:
			quit(1)
			return
	if "--audit-passage" in OS.get_cmdline_user_args():
		var passage_index: int = 0
		for passage_pair: Array in _passage_pairs(edges):
			var passage_mesh: MeshInstance3D = MeshInstance3D.new()
			var passage_plan: Dictionary = plans_by_id[passage_pair[0]]
			passage_mesh.mesh = preload("res://tools/map_workshop/common/flight_mesh.gd").build(passage_plan)
			passage_mesh.visible = false
			world.add_child(passage_mesh)
			var passage_roots: Array[Node3D] = [passage_mesh,masonry[passage_index]]
			var lower_routes: Dictionary = {passage_pair[1]:edges[passage_pair[1]]}
			var passage_audit: Dictionary = preload("res://tools/map_workshop/common/threshold_mesh_audit.gd").run(passage_roots,instance,lower_routes)
			passage_audit["scope"] = "sampled actual central passage deck, walls and flights above lower route"
			passage_audit["input_digest"] = sample["input_digest"]
			var passage_file: FileAccess = FileAccess.open("/tmp/act3-passage-audit-%d.json" % passage_index,FileAccess.WRITE)
			passage_file.store_string(JSON.stringify(passage_audit,"\t"))
			passage_file.close()
			passage_mesh.queue_free()
			print("CENTRAL_PASSAGE_AUDIT ok=",passage_audit["ok"]," probes=",passage_audit["probe_count"]," minimum=",passage_audit["minimum_headroom_m"])
			if passage_audit["ok"] != true:
				quit(1)
				return
			passage_index += 1
	var camera: Camera3D = Camera3D.new()
	print("PRECINCT_BUILD_MS ",(Time.get_ticks_usec()-build_started)/1000.0)
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.far = 500
	camera.make_current()
	if "--wayfinding-study" in OS.get_cmdline_user_args():
		await preload("res://tools/map_workshop/act3/wayfinding_study.gd").run(self,world,camera,sample)
		quit()
		return
	var views: Array[Dictionary] = [
		{"name":"whole","target":Vector3((west+east)*.5,2,0),"size":(east-west)*.63},
		{"name":"journey","target":Vector3((divisions[0]+divisions[1])*.5,2,0),"size":45.0},
		{"name":"court","target":Vector3(boss.x+10,9,boss.z),"size":52.0,"offset":Vector3(-85,65,75)},
		{"name":"threshold","target":Vector3(divisions[0],2,0),"size":44.0,"offset":Vector3(-48,25,28)}]
	if not masonry.is_empty():
		views.append({"name":"passage","target":masonry[0].get_meta("crossing_centre"),"size":19.0,"offset":Vector3(-25,16,25)})
	for view: Dictionary in views:
		var target: Vector3 = view["target"]
		camera.size = view["size"]
		var camera_offset: Vector3 = view.get("offset",Vector3(-35,90,105))
		camera.position = target+camera_offset
		camera.look_at(target)
		if view["name"] == "whole":
			# Fit actual architecture, not an aspect-dependent fraction of map length.
			var extent: Vector2 = Vector2.ZERO
			for building: Node3D in buildings:
				var box: AABB = Occupancy.bounds(building)
				for corner: int in range(8):
					var projected: Vector2 = camera.unproject_position(box.get_endpoint(corner))
					extent = extent.max((projected-Vector2(viewport_size)*.5).abs())
			camera.size *= maxf(extent.x/(viewport_size.x*.45),extent.y/(viewport_size.y*.45))
		for frame: int in range(4):
			await process_frame
		await RenderingServer.frame_post_draw
		if "--profile-native" in OS.get_cmdline_user_args() and view["name"] in ["whole","journey","court"]:
			var timing: Dictionary = await preload("res://tools/map_workshop/common/viewport_profile.gd").measure(root)
			timing["view"] = view["name"]
			print("PRECINCT_TIMING ",JSON.stringify(timing))
		print("PRECINCT_VIEW ",JSON.stringify({"view":view["name"],
			"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			"renderer_mib":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0,
			"scope":"native capture counters; not frame-time qualification"}))
		var error: Error = root.get_texture().get_image().save_png("/tmp/act3-precinct-"+str(view["name"])+".png")
		if error != OK:
			quit(1)
			return
	print("PRECINCT_COMPOSITION captured whole/journey/court; uncertified placement study")
	if "--interactive" in OS.get_cmdline_user_args() or "--exercise-input" in OS.get_cmdline_user_args():
		var inspector: Inspector = Inspector.new()
		inspector.chapter_heading = "  III  /  THE OBSIDIAN COURT"
		inspector.landmark_label = "Court"
		inspector.camera = camera
		inspector.world = world
		inspector.walking = instance
		inspector.data = sample
		for id: String in anchors:
			inspector.anchors[id] = _point(anchors[id])
		inspector.library_at = hall.position
		inspector.landmark = hall
		inspector.ruin_owners["14,3"] = "Sovereign court"
		for blocker: Node3D in buildings+threshold_roots+masonry+[court_mesh,terrain_mesh]:
			inspector.sightlines.collect(blocker)
		inspector.marker_extent = maxf(44.0,60.0*viewport_size.y/820.0)
		inspector.control_extent = maxf(48.0,inspector.marker_extent)
		inspector.extra_controls = ["Travel"]
		root.add_child(inspector)
		inspector.focus_journey()
		if "--exercise-input" in OS.get_cmdline_user_args():
			for frame: int in range(4):
				await process_frame
			var input_report: Dictionary = await inspector.exercise()
			if "--exercise-guidance" in OS.get_cmdline_user_args():
				input_report["guidance"] = await inspector.exercise_guidance()
			input_report["sightlines"] = inspector.sightline_report
			input_report["overview"] = await inspector.measure_overview()
			if "--exercise-all-nodes" in OS.get_cmdline_user_args():
				input_report["all_nodes"] = await inspector.exercise_all_nodes()
			if "--exercise-travel" in OS.get_cmdline_user_args():
				input_report["travel"] = await inspector.exercise_travel()
			if "--exercise-tour" in OS.get_cmdline_user_args():
				input_report["tour"] = await inspector.exercise_tour()
			if "--exercise-routes" in OS.get_cmdline_user_args():
				input_report["route_camera"] = await inspector.exercise_routes()
			if "--diagnostic-stair-probe" in OS.get_cmdline_user_args():
				var pixels: Array[Vector2] = [Vector2(550,440),Vector2(550,426),Vector2(550,452),Vector2(618,323)]
				print("STAIR_SCREEN_PROBE ",JSON.stringify(preload("res://tools/map_workshop/common/mesh_screen_probe.gd").run(world,camera,pixels)))
			print("PRECINCT_INPUT ",JSON.stringify(input_report))
			await RenderingServer.frame_post_draw
			var capture_error: Error = root.get_texture().get_image().save_png("/tmp/act3-precinct-input.png")
			var input_ok: bool = capture_error == OK
			for key: String in ["target_sizes_pass","current_visible","drag_pan","drag_preserves_selection","journey_button","select_current","source_current_unchanged","viewport_matches_pixels","wheel_zoom","whole_button"]:
				input_ok = input_ok and input_report.get(key,false) == true
			var overview: Dictionary = input_report["overview"]
			var overlaps: Array = overview["overlaps"]
			input_ok = input_ok and overview["target_sizes_pass"] == true and overview["represented"] == overview["nodes"] and overlaps.is_empty() and overview["cluster_open"] == true and overview["single_select"] == true
			if input_report.has("guidance"):
				input_ok = input_ok and input_report["guidance"]["ok"] == true
			if input_report.has("all_nodes"):
				var all_nodes: Dictionary = input_report["all_nodes"]
				input_ok = input_ok and all_nodes.get("ok",false) == true
			if input_report.has("route_camera"):
				input_ok = input_ok and input_report["route_camera"]["ok"] == true
			if input_report.has("travel"):
				input_ok = input_ok and input_report["travel"]["ok"] == true
			if input_report.has("tour"):
				input_ok = input_ok and input_report["tour"]["ok"] == true
			quit(0 if input_ok else 1)
		return
	quit()
func _box(position: Vector3, size: Vector3, material: Material) -> void:
	var instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	world.add_child(instance)
func _asset(asset_name: String, source_path: String = "") -> Node3D:
	var path: String = source_path if not source_path.is_empty() else "res://tools/map_workshop/act3/kit/"+asset_name+".glb"
	if asset_templates.has(path):
		var template: PackedScene = asset_templates[path]
		var repeated: Node3D = template.instantiate()
		world.add_child(repeated)
		buildings.append(repeated)
		return repeated
	var document: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	var error: Error = document.append_from_file(path,state)
	assert(error == OK)
	var instance: Node3D = document.generate_scene(state)
	for child: Node in instance.find_children("*","MeshInstance3D",true,false):
		var mesh_instance: MeshInstance3D = child
		for surface: int in range(mesh_instance.mesh.get_surface_count()):
			var source: Material = mesh_instance.mesh.surface_get_material(surface)
			if not source is StandardMaterial3D:
				continue
			var roof: bool = source.resource_name.begins_with("Intact slate")
			if not roof and not source.resource_name.begins_with("Obsidian broad"):
				continue
			var standard: StandardMaterial3D = source
			var dressed: ShaderMaterial = _stone_material(standard.albedo_color,Vector2(6.4,5.6) if roof else Vector2(6.0,2.4),.20,.20)
			dressed.set_shader_parameter("architectural_mapping",true)
			if asset_name in ["obsidian-great-hall","glazed-gallery-bay"]:
				dressed.set_shader_parameter("structural_joint_height",.32)
			dressed.set_shader_parameter("roughness_range",Vector2(.22,.40))
			mesh_instance.set_surface_override_material(surface,dressed)
	instance.set_meta("asset_name",asset_name)
	var template: PackedScene = PackedScene.new()
	assert(template.pack(instance) == OK)
	asset_templates[path] = template
	world.add_child(instance)
	buildings.append(instance)
	return instance

func _point(value: Variant) -> Vector3:
	var coordinates: Array = value
	return M.v3(coordinates)

func _court_height(x: float, rows: Array) -> float:
	var value: float = MapLayoutCanonical.float_value(rows[0]["height_m"])
	for i: int in range(1,rows.size()):
		var boundary: float = (MapLayoutCanonical.float_value(rows[i-1]["station_m"])+MapLayoutCanonical.float_value(rows[i]["station_m"]))*.5
		if x < boundary:
			break
		value = MapLayoutCanonical.float_value(rows[i]["height_m"])
	return value

func _passage_pairs(edges: Dictionary) -> Array[Array]:
	var conflicts: Array[Dictionary] = MapGradeSeparation._xz_conflicts(edges,.001)
	var pairs: Array[Array] = []
	for conflict: Dictionary in conflicts:
		var ids: Array = conflict["edge_ids"]
		var peaks: Array[float] = []
		for id: String in ids:
			var peak: float = -INF
			for point: Array in edges[id]["centerline"]:
				peak = maxf(peak,MapLayoutCanonical.float_value(point[1]))
			peaks.append(peak)
		var ordered: Array[String] = [str(ids[0]),str(ids[1])]
		if peaks[1] > peaks[0]:
			ordered.reverse()
		pairs.append(ordered)
	return pairs

func _stone_material(colour: Color, slab: Vector2, coverage: float, strength: float) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load("res://tools/map_workshop/common/precinct_stone.gdshader")
	if "--diagnostic-unlit" in OS.get_cmdline_user_args():
		material.shader = Shader.new()
		material.shader.code = "shader_type spatial; render_mode unshaded; void fragment() { ALBEDO = abs((INV_VIEW_MATRIX * vec4(NORMAL,0.0)).xyz)*0.7+vec3(0.1); }"
		return material
	material.set_shader_parameter("roughness_range",Vector2(.42,.58))
	material.set_shader_parameter("obsidian_facets",true)
	material.set_shader_parameter("stone_colour",colour)
	material.set_shader_parameter("slab_size",slab)
	material.set_shader_parameter("joint_coverage",coverage)
	material.set_shader_parameter("joint_strength",strength)
	return material

func _glazing_light(parent: Node3D, local_position: Vector3, reach: float, energy: float) -> void:
	var light: OmniLight3D = OmniLight3D.new()
	light.name = "RecessedGlazingSpill"
	light.position = local_position
	light.light_color = Color("b33b9e")
	light.light_energy = energy
	light.omni_range = reach
	light.omni_attenuation = 1.5
	light.light_specular = .35
	parent.add_child(light)
