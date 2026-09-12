extends RefCounted
## #464 self-review regression: a legal one-node domain graph has zero edges.

const _SHA: String = "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_map_layout_single_node: %s" % what)


static func run(fails: Array[String]) -> void:
	var world: WorldMap = WorldMap.act4_entrance()
	var before: Dictionary = world.to_dict().duplicate(true)
	var node: MapNode = world.nodes[0]
	var raw: Dictionary = {
		"schema_version": MapLayoutInput.SCHEMA_VERSION,
		"generator_schema": "map-compiler-v2",
		"generator_version": "2.0.0-contract.1",
		"nodes": [{
			"id": node.id,
			"row": node.row,
			"col": node.col,
			"type": node.type,
			"jitter": [node.jx, node.jy],
		}],
		"edges": [],
		"act": 3,
		"run_seed": 717,
		"scenery_seed": 17634,
		"asset_profile_digest": _SHA,
		"camera_profile_digest": _SHA,
		"hero_anchor_contract": {
			"schema_version": MapLayoutInput.HERO_ANCHOR_SCHEMA_VERSION,
			"anchors": {
				"vigil": {
					"asset_id": "hero/vigil",
					"profile_id": "profile/vigil",
					"position": [0.0, 0.0, -1.0],
				},
			},
			"protected_zones": {
				"vigil-clearance": {
					"polygon": [[-1.0, -2.0], [1.0, -2.0], [1.0, 0.0], [-1.0, 0.0]],
				},
			},
		},
		"quality_registry_digest": _SHA,
	}
	var input: MapLayoutInput = MapLayoutInput.from_dict(raw)
	_check(fails, input != null, "edge-free act4 entrance input validates")
	_check(fails, world.to_dict() == before, "input construction leaves WorldMap untouched")
	if input == null:
		return
	_check(fails, input.edge_records().is_empty(), "input preserves an empty edge collection")
	var input_copy: MapLayoutInput = MapLayoutInput.from_dict(input.to_dict())
	_check(
		fails,
		input_copy != null and input_copy.digest() == input.digest(),
		"edge-free input round-trips with the same digest",
	)
	var anchors: Dictionary = {}
	anchors[node.id] = [3.0, 0.0, 0.0]
	var result: MapLayoutResult = MapLayoutResult.create({
		"schema_version": MapLayoutResult.SCHEMA_VERSION,
		"generator_version": "2.0.0-contract.1",
		"node_anchors": anchors,
		"edges": {},
		"hero_placements": {
			"vigil": {
				"asset_id": "hero/vigil",
				"profile_id": "profile/vigil",
				"transform": {
					"origin": [0.0, 0.0, -1.0],
					"yaw_radians": 0.0,
					"scale": [1.0, 1.0, 1.0],
				},
			},
		},
		"scenery_instances": {},
		"hard_measurements": {"edge_count": {"unit": "count", "value": 0}},
		"soft_scores": {},
		"selected_restart_id": 0,
		"selected_candidate_id": "restart-0/candidate-0",
		"input_digest": input.digest(),
	})
	_check(fails, result != null, "edge-free result validates")
	if result == null:
		return
	var copy: MapLayoutResult = MapLayoutResult.from_dict(result.to_dict())
	_check(
		fails,
		copy != null
			and copy.canonical_bytes() == result.canonical_bytes()
			and copy.digest() == result.digest(),
		"edge-free result round-trips byte-for-byte",
	)
