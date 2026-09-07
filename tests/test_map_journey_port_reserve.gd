extends RefCounted
const Reserve = preload("res://presentation/map/map_journey_port_reserve.gd")
static func run(fails: Array[String]) -> void:
	var quality: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/map/map-quality-v2.json"))
	var nodes: Array = [{"id":"A"},{"id":"B"},{"id":"C"}]
	var edges: Array = [{"from":"A","to":"C"},{"from":"B","to":"C"}]
	var authority: Dictionary = Reserve.context(nodes,edges,quality)
	var anchors: Dictionary = {"A":[0.0,0.0,0.0],"B":[1.0,0.0,0.0],"C":[10.0,0.0,0.0]}
	var ids: Array[String] = ["A","B"]
	var rejected: Dictionary = Reserve.rejection(ids,anchors,authority)
	if rejected.is_empty(): fails.append("journey ports: hidden neighbour blocks an unavoidable access but passes preflight")
	# Check against the real inflated router obstacle, over the entire declared
	# access interval including its endpoints; no camera pixels enter this proof.
	var polygon: PackedVector2Array = [Vector2(.37,-.98),Vector2(.37,.98),Vector2(1.63,.98),Vector2(1.63,-.98)]
	var obstacles: Array[Dictionary] = [{"id":"node:B","polygon":polygon}]
	var inflated: Array = MapSingleEdgeRouter.inflate_obstacles(obstacles,1.6)
	for i: int in range(11):
		var port: Vector2 = Vector2(.63*i/10.0,0)
		if MapSingleEdgeRouter.segment_is_clear(port,port,inflated):
			fails.append("journey ports: preflight claims obstruction outside the actual reserved geometry")
	anchors["B"] = [3.0,0.0,0.0]
	if not Reserve.rejection(ids,anchors,authority).is_empty():
		fails.append("journey ports: rejected an access that can leave its node")
	# A single edge may pass between its own endpoints. They are deliberately
	# excluded from one another's router obstacles.
	var pair_edges: Array = [{"from":"A","to":"B"}]
	var pair_nodes: Array = [{"id":"A"},{"id":"B"}]
	authority = Reserve.context(pair_nodes,pair_edges,quality)
	anchors["B"] = [1.0,0.0,0.0]
	if not Reserve.rejection(ids,anchors,authority).is_empty():
		fails.append("journey ports: treated a route endpoint as its own obstacle")

	# The final seed-717 blocker occupies its incoming/outgoing road portals,
	# wider than its stone marker. Candidate domains prove both accesses exist.
	var graph: Array = [{"id":"A"},{"id":"B"},{"id":"C"},{"id":"D"}]
	var links: Array = [{"from":"A","to":"C"},{"from":"A","to":"B"},{"from":"B","to":"D"}]
	var points: Dictionary = {"A":[27.867941,0.0,14.393537],"B":[30.837021,0.0,13.187938],"C":[29.471891,0.0,7.779468],"D":[40.0,0.0,13.0]}
	var sets: Dictionary = {}
	for id: String in points: sets[id] = {"candidates":[{"anchor":points[id]}]}
	authority = Reserve.context(graph,links,quality)
	Reserve.nearby_pairs(sets,authority)
	if Reserve.rejection(ids,points,authority).is_empty():
		fails.append("journey ports: seed-717 swept portal obstruction passed preflight")
