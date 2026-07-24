extends RefCounted
## Combat parity vs the recorded slice traces
## (port_fixtures/traces/slice-combat/seed-*.jsonl). Replays each trace's
## command stream through GlassvowGame.apply, asserting per row: events delta,
## op return, rngState cursor, and the combat / run snapshots.
##
## Staged coverage while M3 lands: ops listed in SUPPORTED_OPS are replayed;
## the first unsupported op ends that seed's replay early (M3b-e grow the list
## until all four traces replay to the end). Reward rows resync the rng cursor
## and gold — reward *generation* parity is M4's suite.

const SEEDS: PackedInt32Array = [101, 202, 303, 404]
const SUPPORTED_OPS: PackedStringArray = ["playCard"]

const Diff: GDScript = preload("res://tests/support/diff.gd")


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_slice()
	for seed: int in SEEDS:
		_replay(seed, content, fails)


static func _replay(seed: int, content: ContentDB, fails: Array[String]) -> void:
	var path: String = "res://port_fixtures/traces/slice-combat/seed-%d.jsonl" % seed
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		fails.append("%s: unreadable" % path)
		return
	var rows: Array[Dictionary] = []
	for line: String in text.split("\n", false):
		var v: Variant = JSON.parse_string(line)
		if typeof(v) == TYPE_DICTIONARY:
			rows.append(v)
	if rows.is_empty() or str(rows[0].get("type", "")) != "snapshot":
		fails.append("%s: no start snapshot row" % path)
		return

	var snap0: Dictionary = rows[0]["run"]
	var game: GlassvowGame = GlassvowGame.new(content, StateBuild.run_from_snapshot(snap0))
	var replayed: int = 0
	for row: Dictionary in rows:
		var rtype: String = str(row.get("type", ""))
		var before: int = fails.size()
		match rtype:
			"snapshot":
				_check(seed, row, "run", game.run.to_dict(), row["run"], fails)
			"startCombat":
				var cmd: Dictionary = {"t": "startCombat", "enemies": row["enemies"], "kind": row["kind"]}
				# The trace script passes the elite affix explicitly, so the
				# engine's own affix pick (an rng draw) must not fire on replay.
				if str(row["kind"]) == "elite" and row.get("affix") != null:
					cmd["affix"] = row["affix"]
				var events: Array[Dictionary] = game.apply(cmd)
				_check(seed, row, "events", events, row["events"], fails)
				_check(seed, row, "combat", game.cb.to_dict(), row["combat"], fails)
				_check_rng(seed, row, game, fails)
			"step":
				var op: String = str(row["op"])
				if not SUPPORTED_OPS.has(op):
					print("  trace seed-%d: stopped before unsupported op %s (row %d)"
						% [seed, op, StateBuild.ji(row["i"])])
					return
				var args: Dictionary = row["args"]
				var events: Array[Dictionary] = game.apply(_step_cmd(op, args))
				_check(seed, row, "ret", game.last_ret, row["ret"], fails)
				_check(seed, row, "events", events, row["events"], fails)
				_check_rng(seed, row, game, fails)
			"combatEnd":
				_check(seed, row, "result", game.cb.result, row["result"], fails)
				_check(seed, row, "combat", game.cb.to_dict(), row["combat"], fails)
				_check_rng(seed, row, game, fails)
			"reward":
				# M4 owns reward-generation parity; resync the recorded outcome.
				game.run.rng = Rng.new(StateBuild.ji(row["rngState"]))
				var reward: Dictionary = row["reward"]
				game.run.player.gold += StateBuild.ji(reward["gold"])
		if fails.size() != before:
			return  # state past the first divergence is meaningless
		replayed += 1
	print("  trace seed-%d: %d rows replayed to end" % [seed, replayed])


static func _step_cmd(op: String, args: Dictionary) -> Dictionary:
	var cmd: Dictionary = {"t": op}
	if args.has("uid"):
		cmd["uid"] = StateBuild.ji(args["uid"])
	if args.has("cardId"):
		cmd["cardId"] = str(args["cardId"])
	if args.has("slot"):
		cmd["slot"] = StateBuild.ji(args["slot"])
	if args.has("target"):
		var tv: Variant = args["target"]
		cmd["target"] = null if tv == null else StateBuild.ji(tv)
	return cmd


static func _check(
	seed: int, row: Dictionary, field: String, actual: Variant, expected: Variant,
	fails: Array[String]
) -> void:
	var diverged: String = Diff.deep_eq(StateBuild.jsonish(actual), expected)
	if diverged == "":
		return
	fails.append(
		"trace seed-%d row %d (%s): %s diverges at %s\n      expected: %s\n      actual:   %s"
		% [
			seed, StateBuild.ji(row.get("i", -1)), str(row.get("op", row.get("type", "?"))),
			field, diverged,
			JSON.stringify(expected).left(400), JSON.stringify(actual).left(400),
		]
	)


static func _check_rng(seed: int, row: Dictionary, game: GlassvowGame, fails: Array[String]) -> void:
	var expected: int = StateBuild.ji(row["rngState"])
	var got: int = game.run.rng_state()
	if got != expected:
		fails.append(
			"trace seed-%d row %d (%s): rngState expected %d got %d — draw count/order mismatch"
			% [seed, StateBuild.ji(row.get("i", -1)), str(row.get("op", row.get("type", "?"))), expected, got]
		)
