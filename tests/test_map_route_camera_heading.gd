extends RefCounted
const Planner = preload("res://tools/map_workshop/common/route_camera_heading.gd")
static func run(fails: Array[String]) -> void:
	var points: Array[Vector3] = [Vector3.ZERO,Vector3(10,0,0)]
	var headings: Array[float] = [-25,25,55]
	var result: Dictionary = Planner.choose(points,headings,func(point: Vector3,heading: float) -> bool: return heading==55 or (point.x==0 and heading==-25) or (point.x==10 and heading==25))
	if result["ok"] != true or result["heading"] != 55:
		fails.append("route camera: did not choose heading clear across the whole route")
	var impossible: Dictionary = Planner.choose(points,[-25.0,25.0],func(point: Vector3,heading: float) -> bool: return (point.x==0 and heading==-25) or (point.x==10 and heading==25))
	if impossible["ok"] == true:
		fails.append("route camera: per-point visibility incorrectly proves stable route heading")
	var travel: Array[Vector3] = [Vector3.ZERO,Vector3(1,0,0),Vector3(2,0,0)]
	var path: Dictionary = Planner.path(travel,[0.0,10.0,20.0],func(point: Vector3,heading: float) -> bool: return (point.x==0 and heading==0) or point.x==1 or (point.x==2 and heading==20))
	if path.get("ok") != true or path.get("headings") != [0.0,10.0,20.0]:
		fails.append("route camera: did not anticipate obstruction with bounded intermediate turn")
	var fast: Dictionary = Planner.path([Vector3.ZERO,Vector3(.1,0,0)],[0.0,20.0],func(point: Vector3,heading: float) -> bool: return (point.x==0 and heading==0) or (point.x>0 and heading==20))
	if fast["ok"] == true:
		fails.append("route camera: accepted abrupt heading jump over a short distance")
	var endpoints: Array[Vector3] = [Vector3.ZERO,Vector3(1,0,0)]
	var occluded_middle: Callable = func(point: Vector3,_heading: float) -> bool: return point.x<.4 or point.x>.6
	if Planner.visible_path(endpoints,[0.0],occluded_middle)["ok"] == true:
		fails.append("route camera: visible endpoints concealed an occluded interpolation")
	var alternate: Dictionary = Planner.visible_path(endpoints,[0.0,10.0],func(point: Vector3,heading: float) -> bool: return heading>5 or point.x<.4 or point.x>.6)
	if alternate["ok"] != true:
		fails.append("route camera: failed to find clear alternative after rejecting hidden midpoint")
