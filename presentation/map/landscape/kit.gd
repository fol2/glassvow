extends Node3D
## Placement study shared by grey masses and their authored asset replacements.
const Meshes = preload("res://presentation/map/landscape/mesh_tools.gd")
const AssetLights = preload("res://presentation/map/landscape/asset_lights.gd")
const AssetSurfaces = preload("res://presentation/map/landscape/asset_surfaces.gd")
const Envelope = preload("res://presentation/map/landscape/foliage_envelope.gd")
const GroundContacts = preload("res://presentation/map/landscape/ground_contacts.gd")
const GatewaySites = preload("res://presentation/map/landscape/gateway_sites.gd")
const Terrain = preload("res://presentation/map/landscape/terrain.gd")
var tree_envelopes: Dictionary = {}
var contacts: GroundContacts
var placed: Array[Dictionary] = []
var placed_nodes: Array[Node3D] = []
var terrain: Terrain
var anchors: PackedVector3Array
var failure: String = ""
var build_complete: bool = false
var hero_override: String = ""
# Conservative circles enclosing the exported X/Z bounds at every yaw.
const PROFILES: Dictionary = {
	"conifer": Vector2(2.50, 6.40),
	"conifer-wind": Vector2(2.70, 5.50),
	"conifer-snag": Vector2(2.40, 5.30),
	"ash-bramble": Vector2(2.10, .90),
	"ash-fern": Vector2(1.30, .60),
	"slate-shard": Vector2(1.20, 2.20),
	"slate-scree": Vector2(2.20, .50),
	"conifer-spire": Vector2(1.80, 6.40),
	"ash-heath": Vector2(2.1, 1.05),
	"slate-ridge": Vector2(2.25, 1.10),
	"ash-copse": Vector2(1.65, 1.30),
	"slate-bank": Vector2(1.90, 1.70),
	"memorial": Vector2(0.55, 1.95),
	"amber-arch": Vector2(2.65, 5.50),
}

func build(surface: Terrain, points: PackedVector3Array, grey: bool) -> void:
	for kind: String in ["conifer","conifer-spire","conifer-wind","conifer-snag"]:
		var envelope: PackedVector2Array = Envelope.load_conifer(kind)
		if envelope.is_empty():
			failure = "Missing current tree envelope: " + kind
			return
		tree_envelopes[kind] = envelope
	terrain = surface
	anchors = points
	contacts = GroundContacts.new()
	add_child(contacts)
	contacts.begin(terrain)
	_landmark(grey)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7401
	for family: String in ["conifer", "slate-bank", "ash-copse", "memorial"]:
		for i: int in range(1000):
			# Establish the six substantial forms before any accent can occupy a gap.
			var kind: String = family
			if i % 2 == 1:
				kind = {"conifer":"conifer-spire", "slate-bank":"slate-ridge", "ash-copse":"ash-heath"}.get(family, family)
			var p: Vector3 = Vector3(rng.randf_range(-43, 43), 0, rng.randf_range(-23, 23))
			var scale_value: float = rng.randf_range(0.65, 1.05)
			if kind.begins_with("conifer"):
				scale_value = rng.randf_range(0.95, 1.35)
			elif kind.begins_with("ash-"):
				scale_value = rng.randf_range(0.85, 1.25)
			elif kind.begins_with("slate-"):
				scale_value = rng.randf_range(1.0, 1.45)
			elif kind == "memorial" and i > 200:
				continue
			# Broad groves leave breathing space between groups, rather than an
			# even carpet of individually spaced decorative objects.
			var grove: float = sin(p.x * 0.31 + p.z * 0.09) + cos(p.z * 0.41 - p.x * 0.12)
			if (kind.begins_with("conifer") or kind.begins_with("ash-")) and grove < -0.35:
				continue
			var profile: Vector2 = PROFILES[kind]
			var height: float = profile.y
			var radius: float = profile.x
			p.y = terrain.surface_height(p.x, p.z)
			if not clear(p, radius * scale_value, height * scale_value, kind):
				continue
			p.y = terrain.surface_height(p.x, p.z)
			if not terrain.is_dry(p):
				continue
			_place(kind, p, scale_value, rng.randf_range(-PI, PI), grey)
	_undergrowth(grey)
	_verges(grey)
	_accents(grey)
	contacts.finish()
	if not grey:
		preload("res://presentation/map/landscape/terrain_paint.gd").bind_habitat(terrain,placed,terrain.lines,terrain.is_elevated)
	var counts: Dictionary = {}
	for item: Dictionary in placed:
		counts[item["kind"]] = int(str(counts.get(item["kind"],0))) + 1
	print("WORKSHOP_VARIETIES ",JSON.stringify(counts))
	build_complete = true

func _landmark(grey: bool) -> void:
	var site: Dictionary = GatewaySites.choose(terrain, anchors)
	if site.is_empty():
		failure = "No clear gateway passage in this workshop sample"
		push_error(failure)
		return
	var at: Vector3 = site["position"]
	var yaw: float = float(str(site["yaw"]))
	if not grey:
		var ground: MeshInstance3D = terrain.get_node("Quiet sculpted ground") as MeshInstance3D
		var paint: ShaderMaterial = ground.material_override as ShaderMaterial
		paint.set_shader_parameter("gateway_position", Vector2(at.x, at.z))
	_place("amber-arch", at, 1.0, yaw, grey)
	_companion("memorial", at + Vector3(-4, 0, -1), 1.0, -0.2, grey)
	_companion("slate-bank", at + Vector3(4, 0, 1), 1.15, 0.5, grey)
	_companion("slate-bank", at + Vector3(6, 0, -6), 1.20, -0.35, grey)
	_companion("slate-ridge", at + Vector3(-7, 0, -7), 1.10, 0.4, grey)
	_companion("conifer", at + Vector3(-5, 0, -7), 1.2, 0.7, grey)
	_companion("conifer-spire", at + Vector3(1, 0, -8), 1.15, -0.4, grey)
	_companion("conifer", at + Vector3(6, 0, -5), 1.05, 0.3, grey)
	print("WORKSHOP_GATEWAY ", JSON.stringify(site))

func _companion(kind: String, target: Vector3, scale_value: float, yaw: float, grey: bool) -> void:
	var profile: Vector2 = PROFILES[kind] * scale_value
	var best: Vector3 = Vector3.INF
	var distance: float = INF
	for x: int in range(-8, 9):
		for z: int in range(-8, 9):
			var p: Vector3 = target + Vector3(x * 0.5, 0, z * 0.5)
			p.y = terrain.surface_height(p.x, p.z)
			if not terrain.is_dry(p) or not clear(p, profile.x, profile.y, kind):
				continue
			var candidate: float = p.distance_to(target)
			if candidate < distance:
				distance = candidate
				best = p
	if best.is_finite():
		_place(kind, best, scale_value, yaw, grey)

func _undergrowth(grey: bool) -> void:
	var groups: Array[Dictionary] = placed.duplicate()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7523
	for group: Dictionary in groups:
		var family: String = str(group["kind"])
		if not family.begins_with("conifer") and not family.begins_with("slate"):
			continue
		var centre: Vector3 = group["position"]
		for i: int in range(12):
			var angle: float = rng.randf_range(-PI, PI)
			var p: Vector3 = centre + Vector3(cos(angle), 0, sin(angle)) * rng.randf_range(1.2, 3.0)
			p.y = terrain.surface_height(p.x, p.z)
			var kind: String = "ash-heath" if i % 3 != 0 else "ash-copse"
			var scale_value: float = rng.randf_range(0.65, 1.0)
			var profile: Vector2 = PROFILES[kind] * scale_value
			if terrain.is_dry(p) and clear(p, profile.x, profile.y, kind):
				_place(kind, p, scale_value, angle, grey)

func _verges(grey: bool) -> void:
	# Route-directed candidates use the narrow pockets missed by broad scatter.
	# Each short group leaves a gap; both sides retain the exact same road and
	# node-clearance checks as larger props.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7501
	for line: PackedVector3Array in terrain.lines:
		for index: int in range(line.size() - 1):
			var a: Vector3 = line[index]
			var b: Vector3 = line[index + 1]
			var direction: Vector3 = (b - a).normalized()
			var side: Vector3 = direction.cross(Vector3.UP).normalized()
			var count: int = maxi(1, ceili(a.distance_to(b) / 0.65))
			for step: int in range(count):
				var centre: Vector3 = a.lerp(b, (step + 0.5) / count)
				for sign_value: float in [-1, 1]:
					if sin(centre.x * 0.7 + centre.z * 0.6 + sign_value) < -0.35:
						continue
					var kind: String = "ash-heath" if rng.randf() < 0.55 else "ash-copse"
					var profile: Vector2 = PROFILES[kind]
					var scale_value: float = rng.randf_range(0.70, 1.05)
					var p: Vector3 = centre + side * sign_value * rng.randf_range(2.0, 3.2)
					p.y = terrain.surface_height(p.x, p.z)
					if not terrain.is_dry(p) or not clear(p, profile.x * scale_value, profile.y * scale_value, kind):
						continue
					_place(kind, p, scale_value, rng.randf_range(-PI, PI), grey)

func _accents(grey: bool) -> void:
	# Accent candidates only run after the complete woodland composition.
	# They cannot replace its canopies, shrubs, banks or their reserved space.
	var groups: Array[Dictionary] = placed.duplicate()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7631
	var hero: Vector3 = groups[0]["position"]
	var limits: Dictionary = {"ash-fern":22,"ash-bramble":10,"slate-scree":7,"slate-shard":3,"conifer-wind":3,"conifer-snag":2}
	var counts: Dictionary = {}
	for group: Dictionary in groups:
		var family: String = str(group["kind"])
		if not family.begins_with("conifer") and not family.begins_with("slate"):
			continue
		var centre: Vector3 = group["position"]
		for kind: String in limits:
			var count: int = int(str(counts.get(kind,0)))
			if count >= int(str(limits[kind])):
				continue
			if kind.begins_with("conifer") and centre.distance_to(hero)<11:
				continue
			if kind.begins_with("slate") and not family.begins_with("slate"):
				continue
			for attempt: int in range(24):
				var angle: float = rng.randf_range(-PI,PI)
				var radius: float = rng.randf_range(1.4,3.6)
				if kind.begins_with("slate"):
					radius = rng.randf_range(3.0,5.5)
				if kind.begins_with("conifer"):
					radius = rng.randf_range(2.4,4.4)
				var p: Vector3 = centre+Vector3(cos(angle),0,sin(angle))*radius
				p.y = terrain.surface_height(p.x,p.z)
				var scale_value: float = rng.randf_range(.65,.85)
				if kind.begins_with("conifer"):
					scale_value = rng.randf_range(.90,1.05)
				var profile: Vector2 = PROFILES[kind]*scale_value
				if absf(p.x)>43 or absf(p.z)>23 or not terrain.is_dry(p) or not clear(p,profile.x,profile.y,kind):
					continue
				_place(kind,p,scale_value,angle,grey)
				counts[kind] = count+1
				break
	print("WORKSHOP_ACCENTS ",JSON.stringify(counts))

func clear(p: Vector3, radius: float, height: float, kind: String = "") -> bool:
	# Canopies may reach the shoulder; woody roots stay off the walking lane.
	var road_radius: float = radius
	if kind.begins_with("conifer"):
		road_radius *= 0.38
	elif kind.begins_with("ash-"):
		road_radius *= 0.65
	if terrain.distance_to_roads(p) < road_radius + 0.85:
		return false
	var silhouette: PackedVector2Array = []
	if kind.begins_with("conifer"):
		var profile: Vector2 = PROFILES[kind]
		for point: Vector2 in tree_envelopes[kind]:
			silhouette.append(point * (height / profile.y))
	for point: Vector3 in anchors:
		var delta: Vector3 = p - point
		var projected_z: float = delta.z - (p.y - point.y) / tan(deg_to_rad(55))
		if absf(delta.x) < radius + 1.2 and projected_z > -radius - 1.3 and projected_z < radius + height / tan(deg_to_rad(55)) + 1.3:
			if not kind.begins_with("conifer"):
				return false
			var projected: Vector2 = Vector2(-delta.x, -delta.z + (p.y - point.y) / tan(deg_to_rad(55)))
			var reserve: PackedVector2Array = [projected + Vector2(-1.2,-1.3), projected + Vector2(1.2,-1.3), projected + Vector2(1.2,1.3), projected + Vector2(-1.2,1.3)]
			if not Geometry2D.intersect_polygons(silhouette, reserve).is_empty():
				return false
	for placement: Dictionary in placed:
		var other: Vector3 = placement["position"]
		var separation: float = radius + float(str(placement["radius"]))
		# The same undergrowth overlap applies whichever member was placed first.
		# Canopies and shrubs can interleave; road/node reserves stay unchanged.
		if kind.begins_with("conifer") and str(placement["kind"]).begins_with("conifer"):
			separation *= 0.58
		elif kind.begins_with("ash-") and str(placement["kind"]).begins_with("ash-"):
			separation *= 0.38
		elif (kind.begins_with("ash-") and str(placement["kind"]).begins_with("conifer")) or (kind.begins_with("conifer") and str(placement["kind"]).begins_with("ash-")):
			separation *= 0.30
		elif (kind.begins_with("ash-") and str(placement["kind"]).begins_with("slate")) or (kind.begins_with("slate") and str(placement["kind"]).begins_with("ash-")):
			separation *= 0.50
		if Vector2(other.x - p.x, other.z - p.z).length() < separation:
			return false
	return true

func _place(kind: String, p: Vector3, scale_value: float, yaw: float, grey: bool) -> void:
	var item: Node3D
	var path: String = "res://assets/art/map-journey/%s.glb" % kind
	if kind == "amber-arch" and not hero_override.is_empty():
		path = hero_override
	if not grey:
		if not ResourceLoader.exists(path):
			failure = "Missing imported workshop asset: " + path
			push_error(failure)
			return
		var resource: PackedScene = load(path) as PackedScene
		if resource == null:
			failure = "Cannot load workshop asset: " + path
			push_error(failure)
			return
		item = resource.instantiate() as Node3D
		add_child(item)
		var foliage_surfaces: int = AssetSurfaces.prepare(item)
		if (kind.begins_with("conifer") or kind.begins_with("ash-")) and kind not in ["conifer-snag","ash-fern"] and foliage_surfaces == 0:
			failure = "No cut-out foliage surface prepared: " + kind
			return
		if kind == "amber-arch" and not hero_override.is_empty():
			if not AssetLights.attach_trial(item):
				failure = "Missing trial lamp attachment"
		else:
			AssetLights.attach(item, kind)
	else:
		var profile: Vector2 = PROFILES[kind]
		var height: float = profile.y
		var radius: float = profile.x
		item = Meshes.box(self, Vector3.ZERO, Vector3(radius * 1.6, height, radius), Meshes.material(Color("6c707c")), kind)
		(item as MeshInstance3D).mesh = (item as MeshInstance3D).mesh.duplicate() as Mesh
		item.position.y = height * 0.5
	var lift: float = item.position.y
	item.position = p + Vector3.UP * lift * scale_value
	item.scale = Vector3.ONE * scale_value
	item.rotation.y = yaw
	if not grey:
		contacts.place(kind, p, scale_value, yaw)
	var footprint: Vector2 = PROFILES[kind]
	placed_nodes.append(item)
	placed.append({"kind": kind, "position": p, "radius": footprint.x * scale_value, "height": footprint.y * scale_value, "scale":scale_value, "yaw":yaw})
