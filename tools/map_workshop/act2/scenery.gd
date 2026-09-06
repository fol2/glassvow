extends Node3D
## Habitat groups around waterborne architecture, with measured footprint exclusion.
const Assets = preload("res://tools/map_workshop/act2/scenery_assets.gd")
const M = preload("res://tools/map_workshop/mesh_tools.gd")
var assets: Assets = Assets.new()
var placed: Array[Dictionary] = []
var routes: Array[Vector3] = []
var sites: Array[Dictionary] = []
var counts: Dictionary = {}

func build(causeways: Node3D) -> void:
	assets.build()
	sites = causeways.ruin_plan.sites
	var corridors: Dictionary = causeways.sampled_routes.duplicate()
	var links: Dictionary = causeways.ruin_links
	corridors.merge(links)
	for points: PackedVector3Array in corridors.values():
		for i: int in range(0,points.size(),2):
			routes.append(points[i])
	# Broad beds flank buildings; their front approaches remain empty.
	for site: Dictionary in sites:
		var centre: Vector3 = site["centre"]
		var half: Vector2 = site["half"]
		var ordinal: int = site["ordinal"]
		for group: int in range(6):
			var yaw: float = site["yaw"]
			var angle: float = yaw+.9+ordinal*.25+(group%3)*.38+(2.4 if group>=3 else 0.0)
			var distance: float = half.length()+2.4+(group%3)*1.3
			var at: Vector3 = Vector3(centre.x+sin(angle)*distance,0,centre.z+cos(angle)*distance)
			_group(at,ordinal*11+group)
	# A few secondary beds occupy the wider pockets alongside bridge footings.
	var index: int = 0
	for points: PackedVector3Array in corridors.values():
		index += 1
		if index%4!=0 or points.size()<12:
			continue
		var mid: int = points.size()/2
		var forward: Vector3 = (points[mid+2]-points[mid-2]).normalized()
		var side: Vector3 = Vector3(-forward.z,0,forward.x)
		var at: Vector3 = points[mid]+side*(4.3 if index%2==0 else -4.3)
		at.y = 0
		_group(at,100+index)
	print("ACT_II_SCENERY ",JSON.stringify({"instances":placed.size(),"families":counts,"shared_meshes":assets.meshes.size(),"placement":"Measured X/Z footprints outside all routes, decorative links and ruin foundations; no gameplay RNG"}))

func _group(at: Vector3,seed_value: int) -> void:
	var families: Array[String] = ["slate","kelp","reeds","floating_leaves","kelp"]
	if seed_value%4==0:
		families[2] = "snag"
	if seed_value%3==0:
		families[4] = "driftwood"
	for i: int in range(families.size()):
		var angle: float = i*2.4+seed_value*.77
		var radius: float = 0 if i==0 else 1.8+(i%2)*1.3
		var target: Vector3 = at+Vector3(sin(angle)*radius,0,cos(angle)*radius)
		var scale_value: float = .85+_fraction(seed_value*17+i)*.55
		_place(families[i],seed_value%3,target,scale_value,angle)

func _place(kind: String,variant: int,at: Vector3,scale_value: float,yaw: float) -> void:
	var mesh: ArrayMesh = assets.meshes[kind+str(variant)]
	# Floating leaves and wood preserve the exact waterline across scale variants.
	var basis: Basis = Basis(Vector3.UP,yaw).scaled_local(Vector3(scale_value,1.0 if kind in ["floating_leaves","driftwood"] else scale_value,scale_value))
	var transform_value: Transform3D = Transform3D(basis,at)
	var bounds: AABB = transform_value*mesh.get_aabb()
	if not _clear(bounds):
		return
	var item: MeshInstance3D = M.node(self,mesh,assets.material,"Scenery_"+kind)
	item.transform = transform_value
	placed.append({"kind":kind,"bounds":bounds,"at":at})
	counts[kind] = int(str(counts.get(kind,0)))+1

func _clear(bounds: AABB) -> bool:
	var low: Vector3 = bounds.position
	var high: Vector3 = bounds.end
	for p: Vector3 in routes:
		if p.x>low.x-2.0 and p.x<high.x+2.0 and p.z>low.z-2.0 and p.z<high.z+2.0:
			return false
	for site: Dictionary in sites:
		var centre: Vector3 = site["centre"]
		var yaw: float = site["yaw"]
		var half: Vector2 = site["half"]
		var middle: Vector3 = bounds.get_center()
		var local: Vector3 = (middle-centre).rotated(Vector3.UP,-yaw)
		var radius: float = Vector2(bounds.size.x,bounds.size.z).length()*.5
		if absf(local.x)<half.x+radius+.35 and absf(local.z)<half.y+radius+.35:
			return false
	for previous: Dictionary in placed:
		var box: AABB = previous["bounds"]
		# Thin leaf rafts can nest beside taller beds, without equal-spaced scatter.
		var distance: Vector2 = Vector2(bounds.get_center().x-box.get_center().x,bounds.get_center().z-box.get_center().z)
		if distance.length()<.65:
			return false
	return true

func _fraction(value: int) -> float:
	return fposmod(sin(value*12.13+1.2)*427.58,1.0)
