extends RefCounted
## #464: pure, deterministic Map Compiler v2 input/result contracts.

const _SHA_A: String = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
const _SHA_B: String = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
const _SHA_C: String = "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
const _SHA_D: String = "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"
const _CANONICAL_FIXTURE: String = (
	"map-layout-canonical-v1|"
	+ "d2{s1:a;f000000000000c03f;s1:b;i1;}"
)
const _CANONICAL_FIXTURE_SHA: String = (
	"7bf64ad444f26793326713b36146e3f339baab9299e2a563bf5dcb0ab3a5edb8"
)


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_map_layout_contract: %s" % what)


static func run(fails: Array[String]) -> void:
	_test_canonical_codec(fails)
	var fixture: Dictionary = _input_fixture()
	var raw: Dictionary = fixture["raw"]
	var world: WorldMap = fixture["world"]
	var before: Dictionary = fixture["before"]
	var input: MapLayoutInput = MapLayoutInput.from_dict(raw)
	_check(fails, input != null, "seed-717 input validates headlessly")
	_check(fails, world.to_dict() == before, "building the input does not mutate WorldMap")
	if input == null:
		return
	_test_input_identity(input, raw, fails)
	_test_input_fail_closed(raw, fails)
	var result: MapLayoutResult = MapLayoutResult.create(_result_identity(input))
	_check(fails, result != null, "result fixture validates headlessly")
	if result == null:
		return
	_test_result_round_trip(result, fails)
	_test_result_fail_closed(result, fails)
	_test_float_identity(result, fails)


static func _test_canonical_codec(fails: Array[String]) -> void:
	var first: Dictionary = {"b": 1, "a": 0.125}
	var second: Dictionary = {"a": 0.125, "b": 1}
	_check(
		fails,
		MapLayoutCanonical.canonical_text(first) == _CANONICAL_FIXTURE,
		"canonical precision policy has a frozen byte fixture",
	)
	_check(
		fails,
		MapLayoutCanonical.canonical_bytes(first) == MapLayoutCanonical.canonical_bytes(second),
		"dictionary insertion order never changes canonical bytes",
	)
	_check(
		fails,
		MapLayoutCanonical.digest(first) == _CANONICAL_FIXTURE_SHA,
		"canonical fixture SHA-256 is stable",
	)
	_check(
		fails,
		MapLayoutCanonical.FLOAT_POLICY.contains("binary64"),
		"the exact float precision policy is named",
	)


static func _input_fixture() -> Dictionary:
	var content: ContentDB = ContentDB.load_slice()
	var run_state: RunState = RunState.new_run(content, 717, "layout-contract-717")
	var world: WorldMap = WorldMap.benchmark(run_state)
	var before: Dictionary = world.to_dict().duplicate(true)
	var by_id: Dictionary[String, MapNode] = {}
	for map_node: MapNode in world.nodes:
		by_id[map_node.id] = map_node
	var current: MapNode = null
	for map_node: MapNode in world.nodes:
		if map_node.row == 0:
			current = map_node
			break
	var selected: Array[MapNode] = []
	while current != null and selected.size() < 6:
		selected.append(current)
		if current.next.is_empty():
			break
		current = by_id[current.next[0]]
	var nodes: Array[Dictionary] = []
	var edges: Array[Dictionary] = []
	for i: int in range(selected.size()):
		var map_node: MapNode = selected[i]
		nodes.append({
			"id": map_node.id,
			"row": map_node.row,
			"col": map_node.col,
			"type": map_node.type,
			"jitter": [map_node.jx, map_node.jy],
		})
		if i + 1 < selected.size():
			var to_id: String = selected[i + 1].id
			edges.append({
				"id": MapLayoutInput.edge_id(map_node.id, to_id),
				"from": map_node.id,
				"to": to_id,
			})
	return {
		"world": world,
		"before": before,
		"raw": {
			"schema_version": MapLayoutInput.SCHEMA_VERSION,
			"generator_schema": "map-compiler-v2",
			"generator_version": "2.0.0-contract.1",
			"nodes": nodes,
			"edges": edges,
			"act": run_state.act,
			"run_seed": 717,
			"scenery_seed": 17634,
			"asset_profile_digest": _SHA_A,
			"camera_profile_digest": _SHA_B,
			"hero_anchor_contract": _hero_contract(),
			"quality_registry_digest": _SHA_C,
		},
	}


static func _hero_contract() -> Dictionary:
	return {
		"schema_version": MapLayoutInput.HERO_ANCHOR_SCHEMA_VERSION,
		"anchors": {
			"terminus": {
				"asset_id": "hero/terminus",
				"profile_id": "profile/terminus",
				"role": "terminus",
				"position": [3.0, 0.0, 15.0],
				"yaw_radians": 0.0,
				"scale": [1.0, 1.0, 1.0],
				"protected_zone_id": "terminus-clearance",
			},
			"vigil": {
				"asset_id": "hero/vigil",
				"profile_id": "profile/vigil",
				"role": "vigil",
				"position": [3.0, 0.0, -1.0],
				"yaw_radians": 0.0,
				"scale": [1.0, 1.0, 1.0],
				"protected_zone_id": "vigil-clearance",
			},
		},
		"protected_zones": {
			"terminus-clearance": {
				"role": "terminus",
				"polygon": [[1.5, 13.5], [4.5, 13.5], [4.5, 16.5], [1.5, 16.5]],
			},
			"vigil-clearance": {
				"role": "vigil",
				"polygon": [[1.5, -2.0], [4.5, -2.0], [4.5, 0.0], [1.5, 0.0]],
			},
		},
	}


static func _test_input_identity(
	input: MapLayoutInput, raw: Dictionary, fails: Array[String]
) -> void:
	var reordered_raw: Dictionary = _reordered_copy(raw)
	var reordered_nodes: Array = reordered_raw["nodes"]
	var reordered_edges: Array = reordered_raw["edges"]
	reordered_nodes.reverse()
	reordered_edges.reverse()
	var reordered: MapLayoutInput = MapLayoutInput.from_dict(reordered_raw)
	_check(fails, reordered != null, "reordered equivalent input remains valid")
	_check(
		fails,
		reordered != null and input.canonical_bytes() == reordered.canonical_bytes(),
		"equivalent input has identical canonical bytes",
	)
	_check(
		fails,
		reordered != null and input.digest() == reordered.digest(),
		"equivalent input has identical digest",
	)
	var baseline_digest: String = input.digest()
	var exposed: Dictionary = input.to_dict()
	var exposed_nodes: Array = exposed["nodes"]
	var exposed_first: Dictionary = exposed_nodes[0]
	exposed_first["type"] = "mutated-outside-contract"
	_check(fails, input.digest() == baseline_digest,
		"returned input dictionaries cannot mutate contract identity")
	var mutations: Array[Dictionary] = [
		{"kind": "node", "label": "node mutation"},
		{"kind": "edge", "label": "edge mutation"},
		{"kind": "asset", "label": "asset authority mutation"},
		{"kind": "profile", "label": "profile mutation"},
		{"kind": "camera", "label": "camera registry mutation"},
		{"kind": "quality", "label": "quality registry mutation"},
	]
	for mutation: Dictionary in mutations:
		var changed: MapLayoutInput = MapLayoutInput.from_dict(
			_mutated_input(raw, str(mutation["kind"]))
		)
		_check(
			fails,
			changed != null and changed.digest() != input.digest(),
			"%s changes input digest" % str(mutation["label"]),
		)


static func _mutated_input(raw: Dictionary, kind: String) -> Dictionary:
	var copy: Dictionary = raw.duplicate(true)
	match kind:
		"node":
			var nodes: Array = copy["nodes"]
			var first: Dictionary = nodes[0]
			first["type"] = "elite" if str(first["type"]) != "elite" else "monster"
		"edge":
			var edges: Array = copy["edges"]
			edges.remove_at(edges.size() - 1)
		"asset":
			copy["asset_profile_digest"] = _SHA_D
		"profile":
			var contract: Dictionary = copy["hero_anchor_contract"]
			var anchors: Dictionary = contract["anchors"]
			var vigil: Dictionary = anchors["vigil"]
			vigil["profile_id"] = "profile/vigil-v2"
		"camera":
			copy["camera_profile_digest"] = _SHA_D
		"quality":
			copy["quality_registry_digest"] = _SHA_D
	return copy


static func _test_input_fail_closed(raw: Dictionary, fails: Array[String]) -> void:
	var unknown_schema: Dictionary = raw.duplicate(true)
	unknown_schema["schema_version"] = 99
	_check(fails, MapLayoutInput.from_dict(unknown_schema) == null, "unknown input schema fails closed")
	var duplicate: Dictionary = raw.duplicate(true)
	var duplicate_nodes: Array = duplicate["nodes"]
	duplicate_nodes.append(duplicate_nodes[0].duplicate(true))
	_check(fails, MapLayoutInput.from_dict(duplicate) == null, "duplicate node ID fails closed")
	var bad_endpoint: Dictionary = raw.duplicate(true)
	var endpoint_edges: Array = bad_endpoint["edges"]
	var endpoint_edge: Dictionary = endpoint_edges[0]
	endpoint_edge["to"] = "missing-node"
	endpoint_edge["id"] = MapLayoutInput.edge_id(str(endpoint_edge["from"]), "missing-node")
	_check(fails, MapLayoutInput.from_dict(bad_endpoint) == null, "unknown edge endpoint fails closed")
	var non_finite: Dictionary = raw.duplicate(true)
	var non_finite_nodes: Array = non_finite["nodes"]
	var non_finite_node: Dictionary = non_finite_nodes[0]
	non_finite_node["jitter"] = [INF, 0.0]
	_check(fails, MapLayoutInput.from_dict(non_finite) == null, "non-finite input coordinate fails closed")
	var bad_hero_schema: Dictionary = raw.duplicate(true)
	var bad_contract: Dictionary = bad_hero_schema["hero_anchor_contract"]
	bad_contract["schema_version"] = 99
	_check(fails, MapLayoutInput.from_dict(bad_hero_schema) == null,
		"unknown hero-anchor schema fails closed")
	var object_reference: Dictionary = raw.duplicate(true)
	var object_contract: Dictionary = object_reference["hero_anchor_contract"]
	var object_anchors: Dictionary = object_contract["anchors"]
	var object_vigil: Dictionary = object_anchors["vigil"]
	object_vigil["role"] = RefCounted.new()
	_check(fails, MapLayoutInput.from_dict(object_reference) == null,
		"engine object reference fails closed")


static func _result_identity(input: MapLayoutInput) -> Dictionary:
	var anchors: Dictionary = {}
	for node: Dictionary in input.node_records():
		var jitter: Array = node["jitter"]
		anchors[node["id"]] = [
			float(node["col"]) + float(jitter[0]),
			0.0,
			float(node["row"]) + float(jitter[1]),
		]
	var edges: Dictionary = {}
	for edge: Dictionary in input.edge_records():
		var start: Array = anchors[edge["from"]]
		var finish: Array = anchors[edge["to"]]
		var midpoint: Array[float] = [
			(float(start[0]) + float(finish[0])) * 0.5,
			0.0,
			(float(start[2]) + float(finish[2])) * 0.5,
		]
		edges[edge["id"]] = {
			"from": edge["from"],
			"to": edge["to"],
			"centerline": [start.duplicate(), midpoint, finish.duplicate()],
			"corridor_width": 0.72,
		}
	return {
		"schema_version": MapLayoutResult.SCHEMA_VERSION,
		"generator_version": "2.0.0-contract.1",
		"node_anchors": anchors,
		"edges": edges,
		"hero_placements": {
			"vigil": {
				"asset_id": "hero/vigil",
				"profile_id": "profile/vigil",
				"transform": _transform([3.0, 0.0, -1.0], 0.0, [1.0, 1.0, 1.0]),
			},
		},
		"scenery_instances": {
			"scenery-001": {
				"asset_id": "ashen/stump-a",
				"profile_id": "profile/stump-a",
				"semantic_zone": "road-bank",
				"transform": _transform([0.25, 0.0, 3.75], 0.2, [1.0, 1.0, 1.0]),
			},
			"scenery-002": {
				"asset_id": "ashen/wall-a",
				"profile_id": "profile/wall-a",
				"semantic_zone": "vista",
				"transform": _transform([5.25, 0.0, 8.5], -0.4, [1.2, 1.2, 1.2]),
			},
		},
		"hard_measurements": {
			"edge_crossings": {"unit": "count", "value": 0},
			"minimum_node_clearance": {
				"unit": "world", "value": 1.125, "entities": ["0,0", "1,0"],
			},
		},
		"soft_scores": {"branch_separation": 0.875, "route_length": 12.625},
		"selected_restart_id": 2,
		"selected_candidate_id": "restart-2/candidate-7",
		"input_digest": input.digest(),
	}


static func _transform(origin: Array, yaw: float, scale: Array) -> Dictionary:
	return {"origin": origin, "yaw_radians": yaw, "scale": scale}


static func _test_result_round_trip(result: MapLayoutResult, fails: Array[String]) -> void:
	var serial: Dictionary = result.to_dict()
	var copy: MapLayoutResult = MapLayoutResult.from_dict(serial)
	_check(fails, copy != null, "result round-trip validates")
	_check(fails, copy != null and copy.to_dict() == serial,
		"result round-trip preserves every point and identity field")
	_check(fails, copy != null and copy.identity_bytes() == result.identity_bytes(),
		"result round-trip preserves canonical identity bytes")
	_check(fails, copy != null and copy.digest() == result.digest(),
		"result round-trip preserves layout digest")
	var reordered_serial: Dictionary = _reordered_copy(serial)
	var reordered: MapLayoutResult = MapLayoutResult.from_dict(reordered_serial)
	_check(fails, reordered != null and reordered.canonical_bytes() == result.canonical_bytes(),
		"result dictionary reordering is byte-stable")
	var metadata_a: Dictionary = serial.duplicate(true)
	metadata_a[MapLayoutResult.RUNTIME_METADATA_FIELD] = {
		"frame_ms": 2.5, "engine_instance_id": 41,
	}
	var metadata_b: Dictionary = _reordered_copy(serial)
	metadata_b[MapLayoutResult.RUNTIME_METADATA_FIELD] = {
		"engine_instance_id": 999999, "frame_ms": 17.0,
	}
	var normalised_a: MapLayoutResult = MapLayoutResult.from_dict(metadata_a)
	var normalised_b: MapLayoutResult = MapLayoutResult.from_dict(metadata_b)
	_check(
		fails,
		normalised_a != null and normalised_b != null
			and normalised_a.canonical_bytes() == normalised_b.canonical_bytes(),
		"explicitly excluded runtime metadata cannot enter identity",
	)
	var exposed: Dictionary = result.to_dict()
	var exposed_scores: Dictionary = exposed["soft_scores"]
	exposed_scores["route_length"] = 999.0
	_check(fails, result.to_dict() == serial, "returned result dictionaries cannot mutate the contract")


static func _test_result_fail_closed(result: MapLayoutResult, fails: Array[String]) -> void:
	var bad_endpoint: Dictionary = result.identity_dict()
	var endpoint_edges: Dictionary = bad_endpoint["edges"]
	var edge_ids: Array[String] = MapLayoutCanonical.sorted_keys(endpoint_edges)
	var endpoint_edge: Dictionary = endpoint_edges[edge_ids[0]]
	endpoint_edge["to"] = "missing-node"
	_check(fails, MapLayoutResult.create(bad_endpoint) == null, "result edge endpoint fails closed")
	var non_finite: Dictionary = result.identity_dict()
	var anchors: Dictionary = non_finite["node_anchors"]
	var anchor_ids: Array[String] = MapLayoutCanonical.sorted_keys(anchors)
	anchors[anchor_ids[0]] = [NAN, 0.0, 0.0]
	_check(fails, MapLayoutResult.create(non_finite) == null,
		"non-finite result coordinate fails closed")
	var unknown_schema: Dictionary = result.identity_dict()
	unknown_schema["schema_version"] = 99
	_check(fails, MapLayoutResult.create(unknown_schema) == null, "unknown result schema fails closed")
	var unknown_field: Dictionary = result.identity_dict()
	unknown_field["renderer_instance_id"] = 77
	_check(fails, MapLayoutResult.create(unknown_field) == null, "unknown identity field fails closed")
	var tampered: Dictionary = result.to_dict()
	var scores: Dictionary = tampered["soft_scores"]
	scores["route_length"] = float(scores["route_length"]) + 1.0
	_check(fails, MapLayoutResult.from_dict(tampered) == null,
		"tampered serial content fails its layout digest")
	var object_metadata: Dictionary = result.to_dict()
	object_metadata[MapLayoutResult.RUNTIME_METADATA_FIELD] = {"screen": RefCounted.new()}
	_check(fails, MapLayoutResult.from_dict(object_metadata) == null,
		"excluded metadata still rejects engine object references")


static func _test_float_identity(result: MapLayoutResult, fails: Array[String]) -> void:
	var first_raw: Dictionary = result.identity_dict()
	var first_scenery: Dictionary = first_raw["scenery_instances"]
	var first_instance: Dictionary = first_scenery["scenery-001"]
	var first_transform: Dictionary = first_instance["transform"]
	first_transform["origin"] = [1.0, 0.0, 3.75]
	var second_raw: Dictionary = result.identity_dict()
	var second_scenery: Dictionary = second_raw["scenery_instances"]
	var second_instance: Dictionary = second_scenery["scenery-001"]
	var second_transform: Dictionary = second_instance["transform"]
	second_transform["origin"] = [1.0000000000000002, 0.0, 3.75]
	var first: MapLayoutResult = MapLayoutResult.create(first_raw)
	var second: MapLayoutResult = MapLayoutResult.create(second_raw)
	_check(
		fails,
		first != null and second != null and first.digest() != second.digest(),
		"adjacent binary64 world points do not collapse in layout identity",
	)


static func _reordered_copy(value: Variant) -> Variant:
	match typeof(value):
		TYPE_ARRAY:
			var rows: Array = value
			var out_rows: Array = []
			for row_v: Variant in rows:
				out_rows.append(_reordered_copy(row_v))
			return out_rows
		TYPE_DICTIONARY:
			var row: Dictionary = value
			var keys: Array[String] = MapLayoutCanonical.sorted_keys(row)
			keys.reverse()
			var out: Dictionary = {}
			for key: String in keys:
				out[key] = _reordered_copy(row[key])
			return out
		_:
			return value
