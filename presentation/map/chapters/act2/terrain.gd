extends "res://presentation/map/landscape/terrain.gd"
## Adapt the shared journey's contact queries to the city's separate deck levels.
const Causeways = preload("res://presentation/map/chapters/act2/causeways.gd")
var causeways: Causeways

func build(sample: Dictionary, _grey: bool, extent: Rect2 = Rect2(-48,-30,96,60), cache: Resource = null) -> void:
	bounds=extent
	anchors=sample["anchors"]
	source_edges=sample["edges"]
	causeways=Causeways.new()
	# Keep the complete shared node landing level before the raised approach.
	causeways.bridge_style["approach_landing"]=3.2
	causeways.height_profile=preload("res://presentation/map/chapters/act2/generated_profile.gd").new()
	var preferred: PackedVector3Array = []
	for uv: Vector2 in [Vector2(1,.5),Vector2(.25,.1),Vector2(.55,.1),Vector2(.8,.5),Vector2(.12,.8),Vector2(.38,.7),Vector2(.66,.85),Vector2(.86,.7)]:
		var at: Vector2 = bounds.position+bounds.size*uv
		preferred.append(Vector3(at.x,0,at.y))
	for node: Dictionary in sample["nodes"]:
		if node["type"]=="boss":
			var raw: Array = anchors[node["id"]]
			preferred[0]=Meshes.v3(raw)+Vector3(18,0,0)
	causeways.ruin_plan.preferred_centres=preferred
	add_child(causeways)
	if cache!=null and cache.get("chapter_data").get("kind","")=="drowned-city":
		var stored: Dictionary = cache.get("chapter_data")
		preload("res://presentation/map/chapters/act2/cache.gd").restore_roads(causeways,stored)
		restored=true
	else:
		causeways.build(sample)
	failure=causeways.failure
	landform=causeways.levels
	lines=causeways.lines

func present(p: Vector3, upper: bool = false) -> Vector3:
	var preferred: int = 1 if upper or p.y>.015 else 0
	var nearest: float = INF
	var height: float = p.y
	for i: int in range(causeways.fields.size()):
		var query: Dictionary = causeways.fields[i].field(Vector2(p.x,p.z))
		var distance: float = query["distance"]
		if distance<nearest:
			nearest=distance
			height=query["height"]
		if i==preferred and distance<0:
			return Vector3(p.x,MapLayoutCanonical.float_value(query["height"]),p.z)
	return Vector3(p.x,height,p.z)

func height_at(x: float, z: float) -> float:
	return present(Vector3(x,0,z)).y

func surface_height(x: float, z: float) -> float:
	return height_at(x,z)

func is_dry(p: Vector3) -> bool:
	return present(p).y>1.18
