extends RefCounted
## Byte-exact Mulberry32 + derived-helper parity against port_fixtures/rng/.


static func run(fails: Array[String]) -> void:
	_smoke(fails)
	_edge_and_long(fails)
	_derived(fails)


## JSON.parse_string yields float for every number; whole values ≤ 2^32 are exact.
static func _ji(v: Variant) -> int:
	return int(float(str(v)))


static func _smoke(fails: Array[String]) -> void:
	var rng: Rng = Rng.new(1)
	var expect_u32: Array[int] = [2693262067, 11749833, 2265367787]
	var expect_state: Array[int] = [1831565814, -631835669, 1199730144]
	for i: int in range(3):
		var d: float = rng.next()
		var got_u32: int = int(d * 4294967296.0)
		if d * 4294967296.0 != float(expect_u32[i]) or got_u32 != expect_u32[i]:
			fails.append(
				"smoke draw %d: u32 expected %d got %d" % [i, expect_u32[i], got_u32]
			)
		var st: int = rng.get_state()
		if st != expect_state[i]:
			fails.append(
				"smoke draw %d: state expected %d got %d" % [i, expect_state[i], st]
			)


static func _edge_and_long(fails: Array[String]) -> void:
	var raw: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://port_fixtures/rng/mulberry32.json")
	)
	if typeof(raw) != TYPE_DICTIONARY:
		fails.append("mulberry32.json: parse failed")
		return
	var root: Dictionary = raw
	var edges: Array = root["edgeSeeds"]
	for edge_v: Variant in edges:
		var edge: Dictionary = edge_v
		var seed: int = _ji(edge["seed"])
		var draws: Array = edge["draws"]
		var rng: Rng = Rng.new(seed)
		for i: int in range(draws.size()):
			var pair: Array = draws[i]
			var expected_u32: int = _ji(pair[0])
			var expected_state: int = _ji(pair[1])
			var d: float = rng.next()
			var got_u32: int = int(d * 4294967296.0)
			if d * 4294967296.0 != float(expected_u32) or got_u32 != expected_u32:
				fails.append(
					(
						"mulberry32 seed %d draw %d: u32 expected %d got %d"
						% [seed, i, expected_u32, got_u32]
					)
				)
			var st: int = rng.get_state()
			if st != expected_state:
				fails.append(
					(
						"mulberry32 seed %d draw %d: state expected %d got %d"
						% [seed, i, expected_state, st]
					)
				)
	var long_stream: Dictionary = root["longStream"]
	var long_seed: int = _ji(long_stream["seed"])
	var checkpoints: Array = long_stream["checkpoints"]
	var cp_by_i: Dictionary = {}
	for cp_v: Variant in checkpoints:
		var cp: Array = cp_v
		cp_by_i[_ji(cp[0])] = cp
	var rng_long: Rng = Rng.new(long_seed)
	var draw_count: int = _ji(long_stream["draws"])
	for i: int in range(draw_count):
		var d: float = rng_long.next()
		if not cp_by_i.has(i):
			continue
		var cp: Array = cp_by_i[i]
		var expected_u32: int = _ji(cp[1])
		var expected_state: int = _ji(cp[2])
		var got_u32: int = int(d * 4294967296.0)
		if d * 4294967296.0 != float(expected_u32) or got_u32 != expected_u32:
			fails.append(
				(
					"longStream draw %d: u32 expected %d got %d"
					% [i, expected_u32, got_u32]
				)
			)
		var st: int = rng_long.get_state()
		if st != expected_state:
			fails.append(
				(
					"longStream draw %d: state expected %d got %d"
					% [i, expected_state, st]
				)
			)


static func _derived(fails: Array[String]) -> void:
	var raw: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://port_fixtures/rng/derived-helpers.json")
	)
	if typeof(raw) != TYPE_DICTIONARY:
		fails.append("derived-helpers.json: parse failed")
		return
	var root: Dictionary = raw
	var seed_keys: Array[String] = ["1", "20260710", "2026071000"]
	var irange_bounds: Array = [[0, 0], [1, 6], [-3, 3], [0, 255], [5, 80]]
	var shuffle_ns: Array[int] = [5, 10, 20, 53]
	for seed_key: String in seed_keys:
		var seed: int = int(seed_key)
		var section: Dictionary = root[seed_key]
		var rng: Rng = Rng.new(seed)
		var irange_fix: Dictionary = section["irange"]
		for bounds_v: Variant in irange_bounds:
			var bounds: Array = bounds_v
			var a: int = _ji(bounds[0])
			var b: int = _ji(bounds[1])
			var key: String = "[%d,%d]" % [a, b]
			var expected: Array = irange_fix[key]
			for i: int in range(expected.size()):
				var got: int = rng.irange(a, b)
				var exp: int = _ji(expected[i])
				if got != exp:
					fails.append(
						(
							"derived seed %s irange %s[%d]: expected %d got %d"
							% [seed_key, key, i, exp, got]
						)
					)
		var pick_fix: Dictionary = section["pick"]
		for L: int in range(1, 9):
			var expected: Array = pick_fix[str(L)]
			for i: int in range(expected.size()):
				var got: int = rng.pick_index(L)
				var exp: int = _ji(expected[i])
				if got != exp:
					fails.append(
						(
							"derived seed %s pick L=%d[%d]: expected %d got %d"
							% [seed_key, L, i, exp, got]
						)
					)
		var shuffle_fix: Dictionary = section["shuffle"]
		for n: int in shuffle_ns:
			var expected: Array = shuffle_fix[str(n)]
			var got: Array[int] = rng.shuffle_indices(n)
			if got.size() != expected.size():
				fails.append(
					(
						"derived seed %s shuffle n=%d: length expected %d got %d"
						% [seed_key, n, expected.size(), got.size()]
					)
				)
				continue
			for i: int in range(expected.size()):
				var exp: int = _ji(expected[i])
				if got[i] != exp:
					fails.append(
						(
							"derived seed %s shuffle n=%d[%d]: expected %d got %d"
							% [seed_key, n, i, exp, got[i]]
						)
					)
					break
