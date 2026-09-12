extends RefCounted
## Place court level changes at the nearest crossing-free graph cuts.
## Crossed routes retain a common baseline; node IDs and topology never change.
static func resolve(nodes: Array,edges: Array,assignments: Dictionary,targets: Array[int],row_count: int) -> Dictionary:
	var records: Dictionary = {}
	for node: Dictionary in nodes: records[node["id"]]=node
	var blocked: Dictionary = {}
	for i: int in range(edges.size()):
		var a: Dictionary = edges[i]
		var row: int = int(MapLayoutCanonical.float_value(records[a["from"]]["row"]))
		for j: int in range(i+1,edges.size()):
			var b: Dictionary = edges[j]
			if records[b["from"]]["row"]!=records[a["from"]]["row"]: continue
			var from_delta: float = MapLayoutCanonical.float_value(assignments[a["from"]])-MapLayoutCanonical.float_value(assignments[b["from"]])
			var to_delta: float = MapLayoutCanonical.float_value(assignments[a["to"]])-MapLayoutCanonical.float_value(assignments[b["to"]])
			if from_delta*to_delta<0: blocked[row]=true
	var candidates: Array[Dictionary] = [{"cuts":[],"cost":0}]
	for target: int in targets:
		var next: Array[Dictionary] = []
		for candidate: Dictionary in candidates:
			var cuts: Array = candidate["cuts"]
			var begin: int = 1 if cuts.is_empty() else int(MapLayoutCanonical.float_value(cuts[-1]))+2
			for cut: int in range(begin,row_count-1):
				if blocked.has(cut): continue
				var proposed: Array = cuts.duplicate()
				proposed.append(cut)
				next.append({"cuts":proposed,"cost":int(MapLayoutCanonical.float_value(candidate["cost"]))+absi(cut-target)})
		candidates=next
	if candidates.is_empty(): return {"ok":false,"reason":"No crossing-free cuts preserve every court level","blocked":blocked.keys()}
	var best: Dictionary = candidates[0]
	for candidate: Dictionary in candidates:
		if int(MapLayoutCanonical.float_value(candidate["cost"]))<int(MapLayoutCanonical.float_value(best["cost"])): best=candidate
	return {"ok":true,"cuts":best["cuts"],"displacement_rows":best["cost"],"blocked":blocked.keys()}
