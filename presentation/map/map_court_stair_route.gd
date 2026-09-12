extends RefCounted
## Opt-in transverse court stairs. Every route keeps its graph endpoints; the
## spatial recipe owns one stair axis per level boundary. Compiler evaluation
## still owns collision, reserve and route acceptance after this transformation.
static func apply(routes: Dictionary, anchors: Dictionary, rows: Array) -> Dictionary:
	var out: Dictionary = routes.duplicate(true)
	for id: String in MapLayoutCanonical.sorted_keys(routes):
		var edge: Dictionary = routes[id]
		if not anchors.has(edge["from"]) or not anchors.has(edge["to"]):
			return {"ok":false,"edge_id":id,"reason":"missing court anchor"}
		var a: Array = anchors[edge["from"]]
		var b: Array = anchors[edge["to"]]
		var low: float = MapLayoutCanonical.float_value(a[1])
		var high: float = MapLayoutCanonical.float_value(b[1])
		if absf(low-high) < .0001:
			for point: Array in out[id]["centerline"]:
				point[1] = low
			continue
		var row: int = str(edge["from"]).get_slice(",",0).to_int()
		if row < 0 or row+1 >= rows.size():
			return {"ok":false,"edge_id":id,"reason":"court boundary row unavailable"}
		var x: float = (MapLayoutCanonical.float_value(rows[row]["station_m"])+MapLayoutCanonical.float_value(rows[row+1]["station_m"]))*.5
		var line: Array = edge["centerline"]
		var run: float = absf(high-low)/.40
		var start: float = x-run*.5
		var end: float = x+run*.5
		if line.size()<4 or MapLayoutCanonical.float_value(line[1][0]) >= start-1.5 or MapLayoutCanonical.float_value(line[-2][0]) <= end+1.5:
			return {"ok":false,"edge_id":id,"reason":"court stair cannot fit level approach turns"}
		var z: float = INF
		for index: int in range(line.size()-1):
			var p: Array = line[index]
			var q: Array = line[index+1]
			var px: float = MapLayoutCanonical.float_value(p[0])
			var qx: float = MapLayoutCanonical.float_value(q[0])
			if px <= x and qx > x:
				z = lerpf(MapLayoutCanonical.float_value(p[2]),MapLayoutCanonical.float_value(q[2]),(x-px)/(qx-px))
				break
		if not is_finite(z):
			return {"ok":false,"edge_id":id,"reason":"route does not cross its court boundary"}
		# Retain the compiler's departure/arrival guides before fitting stairs.
		# Replacing them with a diagonal towards the stair axis folds branches together.
		var fitted: Array = []
		for index: int in range(line.size()-1):
			var point: Array = line[index]
			if MapLayoutCanonical.float_value(point[0])>=start-1.5: break
			fitted.append([point[0],low,point[2]])
		fitted.append_array([[start-1.5,low,z],[start,low,z],[end,high,z],[end+1.5,high,z]])
		for index: int in range(1,line.size()):
			var point: Array = line[index]
			if MapLayoutCanonical.float_value(point[0])<=end+1.5: continue
			fitted.append([point[0],high,point[2]])
		out[id]["centerline"] = fitted

	return {"ok":true,"routes":out}
