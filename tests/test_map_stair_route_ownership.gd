extends RefCounted
## A flight beside another route must never lower that route's deck.
static func run(fails: Array[String]) -> void:
	var flight: RefCounted = preload("res://presentation/map/chapters/stone_bridge/flight_grade.gd").new()
	var points: Array[Vector3] = [Vector3(0,3,0),Vector3(1,3.4,0),Vector3(2,3.8,0)]
	flight._store(points,"stairs")
	var unrelated: float = flight.height(Vector2(1,1),4.8,"neighbour")
	var owned: float = flight.height(Vector2(1,0),3.5,"stairs")
	if unrelated!=4.8: fails.append("A stair field changed its neighbouring route")
	if absf(owned-3.4)>.000001: fails.append("Owned flight no longer has its fitted grade")
