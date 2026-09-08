class_name MapJourneyCameraContract
extends RefCounted
## Shared projection contract for local decisions and non-interactive overview.
## Fitting the group is insufficient: the same pose must preserve distinct ink
## and touch rectangles. Infeasible groups are reported to the layout solver.
const VERSION: String = "journey-camera-v2"
const PITCH: float = 55.0
const HEIGHT: float = 36.0
const TOUCH_DESIGN_PX: float = 60.0
const TOUCH_FLOOR_PX: float = 60.0
const INK_RADIUS_PX: float = 30.0
const INK_GAP_PX: float = 8.0

static func touch_size(stage: Vector2) -> float:
	return maxf(TOUCH_FLOOR_PX, TOUCH_DESIGN_PX*stage.y/820.0)

static func projected_plane(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z*sin(deg_to_rad(PITCH))-point.y*cos(deg_to_rad(PITCH)))

static func resolve(points: PackedVector3Array, stage: Vector2, overview: bool = false, landmarks: PackedVector3Array = []) -> Dictionary:
	if points.is_empty() or stage.x <= 0.0 or stage.y <= 0.0:
		return {"ok": false, "reason": "empty group or invalid viewport"}
	# Reserve complete touch/ink extents above the 88 px navigation panel.
	var safe: Rect2 = Rect2(Vector2(42,106),stage-Vector2(84,236))
	var usable: Vector2 = safe.size
	if usable.x <= 0.0 or usable.y <= 0.0:
		return {"ok": false, "reason": "viewport has no safe decision area"}
	var minimum: Vector2 = Vector2(INF, INF)
	var maximum: Vector2 = Vector2(-INF, -INF)
	var plane: PackedVector2Array = []
	for point: Vector3 in points:
		if not point.is_finite():
			return {"ok": false, "reason": "non-finite anchor"}
		var projected: Vector2 = projected_plane(point)
		plane.append(projected)
		minimum = minimum.min(projected)
		maximum = maximum.max(projected)
	for point: Vector3 in landmarks:
		if not point.is_finite(): return {"ok":false,"reason":"non-finite landmark"}
		var projected: Vector2 = projected_plane(point)
		minimum=minimum.min(projected)
		maximum=maximum.max(projected)
	var span: Vector2 = maximum-minimum
	var zoom: float = maxf(12.0, maxf(span.x*stage.y/usable.x, span.y*stage.y/usable.y))
	var maximum_zoom: float = INF
	if not overview:
		for i: int in range(plane.size()):
			for j: int in range(i+1, plane.size()):
				var delta: Vector2 = (plane[i]-plane[j]).abs()
				maximum_zoom = minf(maximum_zoom, maxf(delta.x, delta.y)*stage.y/touch_size(stage))
				maximum_zoom = minf(maximum_zoom, delta.length()*stage.y/(INK_RADIUS_PX*2.0+INK_GAP_PX))
	if zoom > maximum_zoom+.0001:
		return {"ok": false, "reason": "group cannot fit without overlapping targets",
			"minimum_zoom": zoom, "maximum_zoom": maximum_zoom}
	var centre: Vector2 = (minimum+maximum)*.5+(stage*.5-safe.get_center())*zoom/stage.y
	var position: Vector3 = Vector3(centre.x, HEIGHT,
		centre.y/sin(deg_to_rad(PITCH))+HEIGHT/tan(deg_to_rad(PITCH)))
	return {"ok": true, "zoom": zoom, "position": position, "pitch": PITCH,
		"touch_size": touch_size(stage), "overview": overview, "version": VERSION}

static func screen_point(point: Vector3, resolved: Dictionary, stage: Vector2) -> Vector2:
	var position: Vector3 = resolved["position"]
	var centre: Vector2 = projected_plane(position)
	var local: Vector2 = projected_plane(point)-centre
	var zoom: float = resolved["zoom"]
	return stage*.5+local*stage.y/zoom

static func audit_surface(anchors: Dictionary, edges: Dictionary, framing: Dictionary = {}) -> Dictionary:
	var groups: Dictionary = {}
	for id: String in MapLayoutCanonical.sorted_keys(anchors): groups[id] = [id]
	for edge: Dictionary in edges.values(): groups[str(edge["from"])].append(str(edge["to"]))
	var failures: Array = []
	var checked: int = 0
	for id: String in groups:
		var points: PackedVector3Array = []
		for member: String in groups[id]:
			var raw: Array = anchors[member]
			points.append(Vector3(float(str(raw[0])),float(str(raw[1])),float(str(raw[2]))))
		for shape: StringName in StageShape.SHIPPING:
			var stage: Vector2i = StageShape.REFERENCES[shape]
			var landmarks: PackedVector3Array = framing.get(id,PackedVector3Array())
			var pose: Dictionary = resolve(points,Vector2(stage),false,landmarks)
			checked += 1
			if not pose["ok"]:
				failures.append({"focus":id,"shape":str(shape),"members":groups[id].duplicate(),"reason":pose["reason"]})
	return {"ok":failures.is_empty(),"version":VERSION,"checked_contexts":checked,"failures":failures}
