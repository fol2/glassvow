extends RefCounted
## Runtime contacts use the exact resolved walking faces, including each tread.
var cells: Dictionary = {}
const CELL: float = 2.0
const EDGE_TOLERANCE: float = .00025

func add(tops: Array) -> void:
	for polygon: PackedVector3Array in tops:
		for index: int in range(1,polygon.size()-1):
			var a: Vector3 = polygon[0]
			var b: Vector3 = polygon[index]
			var c: Vector3 = polygon[index+1]
			var ab: Vector2 = Vector2(b.x-a.x,b.z-a.z)
			var ac: Vector2 = Vector2(c.x-a.x,c.z-a.z)
			var cross: float = ab.cross(ac)
			if absf(cross)<.0000001: continue
			var row: Dictionary = {"a":a,"ab":ab,"ac":ac,"cross":cross,"yb":b.y-a.y,"yc":c.y-a.y}
			var low: Vector2 = Vector2(minf(a.x,minf(b.x,c.x)),minf(a.z,minf(b.z,c.z)))
			var high: Vector2 = Vector2(maxf(a.x,maxf(b.x,c.x)),maxf(a.z,maxf(b.z,c.z)))
			for x: int in range(floori((low.x-EDGE_TOLERANCE)/CELL),floori((high.x+EDGE_TOLERANCE)/CELL)+1):
				for z: int in range(floori((low.y-EDGE_TOLERANCE)/CELL),floori((high.y+EDGE_TOLERANCE)/CELL)+1):
					var key: Vector2i = Vector2i(x,z)
					if not cells.has(key): cells[key]=[]
					cells[key].append(row)

func height(at: Vector3) -> float:
	var best: float = INF
	var result: float = INF
	var supporting: float = -INF
	for row: Dictionary in cells.get(Vector2i(floori(at.x/CELL),floori(at.z/CELL)),[]):
		var a: Vector3 = row["a"]
		var delta: Vector2 = Vector2(at.x-a.x,at.z-a.z)
		var ab: Vector2 = row["ab"]
		var ac: Vector2 = row["ac"]
		var u: float = delta.cross(ac)/row["cross"]
		var v: float = ab.cross(delta)/row["cross"]
		if u<0 or v<0 or u+v>1:
			var polygon: PackedVector2Array = [Vector2.ZERO,ab,ac]
			var distance: float = INF
			for edge: int in range(3):
				distance=minf(distance,delta.distance_to(Geometry2D.get_closest_point_to_segment(delta,polygon[edge],polygon[(edge+1)%3])))
			if distance>EDGE_TOLERANCE: continue
		var y: float = a.y+u*row["yb"]+v*row["yc"]
		if y>=at.y-.18 and y<=at.y+.18: supporting=maxf(supporting,y)
		var distance: float = absf(y-at.y)
		if distance<best:
			best=distance
			result=y
	return supporting if is_finite(supporting) else result
