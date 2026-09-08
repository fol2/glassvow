extends RefCounted
## Imported JSON resources survive export remapping; raw glTF is editor-only.
const ENVELOPES: Dictionary = {
	"conifer": preload("res://assets/art/map-journey/conifer-envelope.json"),
	"conifer-spire": preload("res://assets/art/map-journey/conifer-spire-envelope.json"),
	"conifer-wind": preload("res://assets/art/map-journey/conifer-wind-envelope.json"),
	"conifer-snag": preload("res://assets/art/map-journey/conifer-snag-envelope.json"),
}
static func load_conifer(kind: String = "conifer") -> PackedVector2Array:
	var result: PackedVector2Array = []
	if not ENVELOPES.has(kind):
		push_error("Unknown conifer envelope: "+kind)
		return result
	var document: JSON = ENVELOPES[kind]
	var data: Dictionary = document.data
	# The import/asset gate checks the original source. Release packages contain
	# imported scenes rather than raw glTF bytes, so FileAccess cannot hash them.
	if OS.has_feature("editor") and str(data.get("source_sha256", "")) != FileAccess.get_sha256("res://assets/art/map-journey/%s.glb" % kind):
		push_error("Conifer envelope must be regenerated for this mesh")
		return result
	for point: Array in data["points"]:
		result.append(Vector2(float(str(point[0])),float(str(point[1]))))
	return result
