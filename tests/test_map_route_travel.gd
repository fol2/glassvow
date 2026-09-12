extends RefCounted
const Travel = preload("res://tools/map_workshop/common/route_travel.gd")
static func run(fails: Array[String]) -> void:
	var travel: Travel = Travel.new()
	var points: Array[Vector3] = [Vector3.ZERO,Vector3.ZERO,Vector3(2,1,0),Vector3(2,1,3)]
	var headings: Array[float] = [0,0,10,20]
	if not travel.begin(points,headings,1):
		fails.append("travel: valid path rejected")
	var first: Dictionary = travel.advance(sqrt(5.0)*.5)
	var position: Vector3 = first["point"]
	var angle: float = first["heading"]
	if not position.is_equal_approx(Vector3(1,.5,0)) or not is_equal_approx(angle,5.0):
		fails.append("travel: interpolation does not follow distance on ascending segment")
	travel.cancel()
	if not travel.advance(10).is_empty():
		fails.append("travel: cancelled preview continues moving")
	travel.begin(points,headings,1)
	var end: Dictionary = travel.advance(20)
	if end["point"] != points[-1] or end["finished"] != true or travel.active:
		fails.append("travel: did not stop exactly at route end")
	travel.begin([Vector3.ZERO,Vector3(.2,0,0)],[0.0,40.0],4.0)
	var turning: Dictionary = travel.advance(.1)
	var turned: float = turning["heading"]
	if turned > 4.0001 or turning["finished"] == true:
		fails.append("travel: short turn exceeds 40 degrees per second instead of slowing translation")
