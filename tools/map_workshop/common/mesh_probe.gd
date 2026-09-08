extends RefCounted
## Vertical samples against rendered triangles, indexed in one-metre X/Z cells.
var cells: Dictionary = {}

func build(mesh: Mesh) -> void:
	var faces: PackedVector3Array = mesh.get_faces()
	for i: int in range(0,faces.size(),3):
		var a: Vector3 = faces[i]
		var b: Vector3 = faces[i+1]
		var c: Vector3 = faces[i+2]
		var cross: float = Vector2(b.x-a.x,b.z-a.z).cross(Vector2(c.x-a.x,c.z-a.z))
		if absf(cross)<.0000001:
			continue
		var lo: Vector2 = Vector2(minf(a.x,minf(b.x,c.x)),minf(a.z,minf(b.z,c.z)))
		var hi: Vector2 = Vector2(maxf(a.x,maxf(b.x,c.x)),maxf(a.z,maxf(b.z,c.z)))
		var triangle: Array[Vector3] = [a,b,c]
		for x: int in range(floori(lo.x),floori(hi.x)+1):
			for z: int in range(floori(lo.y),floori(hi.y)+1):
				var key: Vector2i = Vector2i(x,z)
				if not cells.has(key):
					cells[key] = []
				cells[key].append(triangle)

func heights(at: Vector2) -> PackedFloat32Array:
	var result: PackedFloat32Array = []
	var candidates: Array = cells.get(Vector2i(floori(at.x),floori(at.y)),[])
	for triangle: Array[Vector3] in candidates:
		var a: Vector3 = triangle[0]
		var b: Vector3 = triangle[1]
		var c: Vector3 = triangle[2]
		var ab: Vector2 = Vector2(b.x-a.x,b.z-a.z)
		var ac: Vector2 = Vector2(c.x-a.x,c.z-a.z)
		var delta: Vector2 = at-Vector2(a.x,a.z)
		var denominator: float = ab.cross(ac)
		var u: float = delta.cross(ac)/denominator
		var v: float = ab.cross(delta)/denominator
		if u>=-.00001 and v>=-.00001 and u+v<=1.00001:
			result.append(a.y*(1-u-v)+b.y*u+c.y*v)
	return result
