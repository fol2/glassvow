extends "res://presentation/map/landscape/terrain.gd"
## Shared journey contact adapter for actual court and stair walking faces.
const Courts = preload("res://presentation/map/chapters/act3/courts.gd")
const Contacts = preload("res://presentation/map/chapters/common/walking_contacts.gd")
var courts: Courts
var contacts: Contacts = Contacts.new()
var quality: Dictionary = {}
var boss_id: String = ""

func build(sample: Dictionary,_grey: bool,extent: Rect2 = Rect2(-48,-30,96,60),cache: Resource = null) -> void:
	bounds=extent
	anchors=sample["anchors"]
	source_edges=sample["edges"]
	courts=Courts.new()
	add_child(courts)
	if cache!=null and cache.get("chapter_data").get("kind","")=="obsidian-court":
		var stored: Dictionary = cache.get("chapter_data")
		preload("res://presentation/map/chapters/act3/cache.gd").restore_courts(courts,stored)
		restored=true
	else:
		courts.build(sample,quality,boss_id)
	failure=courts.failure
	if not failure.is_empty(): return
	var routes: Array = courts.joined["tops"]
	contacts.add(routes)
	var floors: Array = courts.court["tops"]
	contacts.add(floors)

func present(p: Vector3,_upper: bool = false) -> Vector3:
	var y: float = contacts.height(p)
	return Vector3(p.x,y if is_finite(y) else p.y,p.z)

func height_at(x: float,z: float) -> float:
	return present(Vector3(x,0,z)).y

func surface_height(x: float,z: float) -> float:
	return height_at(x,z)

func is_dry(_p: Vector3) -> bool:
	return true
