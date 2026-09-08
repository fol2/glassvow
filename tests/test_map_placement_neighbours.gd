extends RefCounted
const Index = preload("res://presentation/map/landscape/placement_neighbours.gd")
static func run(fails: Array[String]) -> void:
	var index: Index = Index.new()
	if not index.query(Vector3.ZERO,3).is_empty(): fails.append("placement index: empty query returned objects")
	var rows: Array[Dictionary] = []
	for x: int in range(-5,6):
		for z: int in range(-5,6):
			var row: Dictionary = {"position":Vector3(x*8,0,z*8),"radius":.3+absf(x)*.7,"id":str(x)+":"+str(z)}
			rows.append(row)
			index.add(row)
	# Late larger objects must enlarge subsequent searches too.
	var large: Dictionary = {"position":Vector3(-17,0,7.9),"radius":18.0,"id":"large"}
	rows.append(large)
	index.add(large)
	for at: Vector3 in [Vector3.ZERO,Vector3(-8.01,0,7.99),Vector3(33,0,-33),Vector3(100,0,100)]:
		for radius: float in [.0,.01,1.5,9.0]:
			var candidates: Array[Dictionary] = index.query(at,radius)
			var actual: Array[String] = []
			var expected: Array[String] = []
			for row: Dictionary in rows:
				var other: Vector3 = row["position"]
				if Vector2(other.x-at.x,other.z-at.z).length()<radius+float(str(row["radius"])): expected.append(row["id"])
			for row: Dictionary in candidates:
				var other: Vector3 = row["position"]
				if Vector2(other.x-at.x,other.z-at.z).length()<radius+float(str(row["radius"])): actual.append(row["id"])
			actual.sort()
			expected.sort()
			if actual!=expected: fails.append("placement index: broad phase lost or duplicated a real overlap")
	if not index.query(Vector3(100,0,100),1).is_empty(): fails.append("placement index: distant query scanned irrelevant scenery")
