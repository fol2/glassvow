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
	# Interleaved owners retain original segment order and exact interpolation.
	for index: int in range(12):
		var shifted: Array[Vector3] = []
		for point: Vector3 in points: shifted.append(point+Vector3(0,index*.03,index*.07))
		flight._store(shifted,"parallel-%d"%index)
	for x: int in range(25):
		for z: int in range(18):
			var at: Vector2 = Vector2(x*.1-.2,z*.1-.2)
			var cell: Vector2i = Vector2i(floori(at.x/4),floori(at.y/4))
			var candidates: Array = flight.cells.get(cell,[])
			var expected: Vector2 = flight._sample_candidates(at,"stairs",candidates)
			if flight.sample(at,"stairs")!=expected:
				fails.append("Owner index changed an exact flight sample")
				return
	flight.cells={}
	if flight.sample(Vector2(1,0),"stairs")!=Vector2.ZERO:
		fails.append("Replacing restored flight cells left a stale owner index")
	flight._store(points,"stairs")
	var rebuilt_height: float = flight.height(Vector2(1,0),3.5,"stairs")
	if absf(rebuilt_height-3.4)>.000001:
		fails.append("Adding a flight failed to invalidate the owner index")
