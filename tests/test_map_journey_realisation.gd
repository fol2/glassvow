extends RefCounted
## The production receipt must describe the visible section, not legacy scenery.
const Landscape = preload("res://presentation/map/map_journey_landscape.gd")
const Realisation = preload("res://presentation/map/map_journey_realisation.gd")
static func run(fails: Array[String]) -> void:
	var sample: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/map/studies/camera-composition/act1-seed717.json"))
	var data: Dictionary = {"schema_version":1,"generator_version":MapLayoutCompiler.VERSION,
		"node_anchors":sample["anchors"],"edges":sample["edges"],"hero_placements":sample["hero_placements"],"scenery_instances":{},
		"hard_measurements":{},"soft_scores":{},"selected_restart_id":0,"selected_candidate_id":"approved-section",
		"input_digest":sample["input_digest"]}
	var source: MapLayoutResult = MapLayoutResult.create(data)
	if source == null:
		fails.append("journey realisation: invalid approved source fixture: "+str(MapLayoutResult.validate_identity(data)))
		return
	var original: String = source.digest()
	var scene: MapScene = MapScene.new()
	var quality: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/map/map-quality-v2.json"))
	quality = preload("res://presentation/map/map_journey_camera_registry.gd").quality(quality)
	var result: MapLayoutResult = scene.bind_layout(source,quality)
	if result == null:
		fails.append("journey realisation: "+str(scene.layout_failure()))
		scene.free()
		return
	var landscape: Landscape = scene._landscape as Landscape
	var instance: int = landscape.get_instance_id()
	var repeated: MapLayoutResult = scene.bind_layout(source,quality)
	_check(fails,repeated!=null and repeated.digest()==result.digest() and scene._landscape.get_instance_id()==instance,"encounter refresh rebuilt identical geometry")
	var receipt: Dictionary = {"assets":scene.realised_asset_bundle()}
	var actual: Dictionary = result.identity_dict()
	_check(fails,source.digest()==original,"source proposal changed")
	var match_1: bool = actual["node_anchors"].keys()==data["node_anchors"].keys()
	_check(fails,match_1,"node identity changed")
	var match_2: bool = actual["edges"].keys()==data["edges"].keys()
	_check(fails,match_2,"edge identity changed")
	for i: int in range(landscape.node_ids.size()):
		var id: String = landscape.node_ids[i]
		var at: Vector3 = MapLandscape.v3(actual["node_anchors"][id])
		var base: Vector3 = landscape.journey.bases[i].position
		var before: Vector3 = MapLandscape.v3(data["node_anchors"][id])
		_check(fails,at.is_equal_approx(base) and at.x==before.x and at.z==before.z,"waystone not at recorded supported position: "+id)
		_check(fails,landscape.resolved_anchor(at).is_equal_approx(at),"height applied twice: "+id)
	for id: String in actual["edges"]:
		var edge: Dictionary = actual["edges"][id]
		var match_3: bool = edge["from"]==data["edges"][id]["from"] and edge["to"]==data["edges"][id]["to"]
		_check(fails,match_3,"route endpoint changed")
		var match_4: bool = edge["centerline"][0]==actual["node_anchors"][edge["from"]] and edge["centerline"][-1]==actual["node_anchors"][edge["to"]]
		_check(fails,match_4,"route no longer joins its stops")
	var count: int = actual["hero_placements"].size()+actual["scenery_instances"].size()
	_check(fails,count==landscape.kit.placed_nodes.size(),"scenery count describes a different scene")
	var profiles: Dictionary = receipt["assets"]["profiles"]
	for i: int in range(landscape.kit.placed.size()):
		var item: Dictionary = landscape.kit.placed[i]
		var key: String = "woodland-gateway" if item["kind"]=="amber-arch" else "woodland-%04d"%i
		var row: Dictionary = actual["hero_placements"].get(key,actual["scenery_instances"].get(key,{}))
		var placed: Node3D = landscape.kit.placed_nodes[i]
		_check(fails,MapLandscape.v3(row["transform"]["origin"]).is_equal_approx(placed.position),"scenery transform mismatch: "+key)
		_check(fails,profiles.has(row["profile_id"]),"missing actual imported asset profile: "+key)
	var measured: Dictionary = actual["hard_measurements"]
	_check(fails,measured.size()==1 and measured.has("journey_camera"),"source measurements misrepresented as surface evidence")
	scene.free()

static func _check(fails: Array[String], ok: bool, message: String) -> void:
	if not ok: fails.append("journey realisation: "+message)
