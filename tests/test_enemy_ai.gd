extends RefCounted
## Enemy-AI parity vs port_fixtures/ai/enemy-ai.json for the 4 slice species.
## For each recorded case we seed a fresh Rng, run EnemyAi.decide, and assert both
## the returned move AND rng.get_state(). Matching final state from the same seed
## proves identical draw count+order (Mulberry32 is a bijection on state), so it
## subsumes the fixture's rng.calls without a separate counter.

const SLICE_ENEMIES: Array[String] = ["sporeling", "duskfang", "waylayer", "gravewarden"]


## JSON.parse_string yields float for every number; whole values are exact.
static func _ji(v: Variant) -> int:
	return int(float(str(v)))


static func _str_or_empty(v: Variant) -> String:
	return "" if v == null else str(v)


static func run(fails: Array[String]) -> void:
	var raw: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://port_fixtures/ai/enemy-ai.json")
	)
	if typeof(raw) != TYPE_DICTIONARY:
		fails.append("enemy-ai.json: parse failed")
		return
	var root: Dictionary = raw
	var entries: Array = root["enemyAi"]
	var by_id: Dictionary = {}
	for entry_v: Variant in entries:
		var entry: Dictionary = entry_v
		by_id[str(entry["id"])] = entry

	for eid: String in SLICE_ENEMIES:
		if not by_id.has(eid):
			fails.append("enemy-ai.json: missing slice enemy %s" % eid)
			continue
		var entry: Dictionary = by_id[eid]
		var cases: Array = entry["cases"]
		for ci: int in range(cases.size()):
			var c: Dictionary = cases[ci]
			var seed: int = _ji(c["seed"])
			var turn: int = _ji(c["turn"])
			var last: String = _str_or_empty(c["last"])
			var prev: String = _str_or_empty(c["prev"])
			var hp_frac: float = float(str(c["hpFrac"]))
			var rng: Rng = Rng.new(seed)
			var got: StringName = EnemyAi.decide(StringName(eid), turn, last, prev, hp_frac, rng)
			var expected_move: String = str(c["returned"])
			if String(got) != expected_move:
				fails.append(
					"ai %s case %d (turn=%d last=%s): move expected %s got %s"
					% [eid, ci, turn, last, expected_move, String(got)]
				)
			var rng_info: Dictionary = c["rng"]
			var expected_state: int = _ji(rng_info["state"])
			var got_state: int = rng.get_state()
			if got_state != expected_state:
				fails.append(
					"ai %s case %d (turn=%d last=%s): rng state expected %d got %d — draw count/order mismatch"
					% [eid, ci, turn, last, expected_state, got_state]
				)
