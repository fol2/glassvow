extends RefCounted
## Combat-law parity vs port_fixtures/combat-probes/probes.jsonl (136 rng-free
## rows). Each row carries a `pre` combat projection, an op, and the recorded
## events / post / ret (+ preview mirror for attack rows). We reconstruct `pre`,
## run the op through CombatRules, and assert everything.
##
## All 136 rows are covered; SUPPORTED_TAG_PREFIXES is the known tag surface,
## so a regenerated fixture with a new tag family shows up as pending > 0.

const SUPPORTED_TAG_PREFIXES: PackedStringArray = [
	"attack/", "special/", "block/", "potion/", "previewBlock/", "previewEnemyDmg/",
]

const Diff: GDScript = preload("res://tests/support/diff.gd")


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_slice()
	var rules: CombatRules = CombatRules.new(content)
	var text: String = FileAccess.get_file_as_string("res://port_fixtures/combat-probes/probes.jsonl")
	if text.is_empty():
		fails.append("probes.jsonl: unreadable")
		return
	var covered: int = 0
	var pending: int = 0
	for line: String in text.split("\n", false):
		var v: Variant = JSON.parse_string(line)
		if typeof(v) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = v
		var tag: String = str(row["tag"])
		if not _supported(tag):
			pending += 1
			continue
		covered += 1
		var op: String = str(row["op"])
		var before: int = fails.size()
		match op:
			"playCard":
				_probe_play(content, rules, row, fails)
			"usePotion":
				_probe_potion(content, rules, row, fails)
			"previewBlock":
				_probe_preview_block(rules, row, fails)
			"previewEnemyDmg":
				_probe_preview_enemy(content, rules, row, fails)
			_:
				fails.append("probe %s: unhandled op %s" % [tag, op])
		if fails.size() != before and fails.size() > 8:
			fails.append("probes: stopping after 8 failures")
			return
	print("  probes: %d covered, %d pending" % [covered, pending])


static func _supported(tag: String) -> bool:
	for prefix: String in SUPPORTED_TAG_PREFIXES:
		if tag.begins_with(prefix):
			return true
	return false


static func _probe_play(
	content: ContentDB, rules: CombatRules, row: Dictionary, fails: Array[String]
) -> void:
	var pre: Dictionary = row["pre"]
	var pre_player: Dictionary = pre["player"]
	var run_state: RunState = StateBuild.probe_run(pre_player)
	var cb: CombatState = StateBuild.combat_from_projection(content, pre)
	var target_v: Variant = row.get("target")
	var target: Variant = null if target_v == null else StateBuild.ji(target_v)
	var inst: CardInst = cb.hand[0]
	if row.has("preview"):
		var pv: Variant = rules.preview_play(cb, inst, target)
		_check(row, "preview", pv, row["preview"], fails)
	var ret: bool = rules.play_card(run_state, cb, inst.uid, target)
	_check(row, "ret", ret, row["ret"], fails)
	_check(row, "events", cb.queue, row["events"], fails)
	_check(row, "post", cb.to_dict(), row["post"], fails)


static func _probe_potion(
	content: ContentDB, rules: CombatRules, row: Dictionary, fails: Array[String]
) -> void:
	var args: Dictionary = row["args"]
	var pre: Dictionary = row["pre"]
	var pre_player: Dictionary = pre["player"]
	var run_state: RunState = StateBuild.probe_run(pre_player)
	var slot: int = StateBuild.ji(args["slot"])
	run_state.player.potions[slot] = str(args["potionId"])
	var cb: CombatState = StateBuild.combat_from_projection(content, pre)
	var target_v: Variant = args.get("target")
	var target: Variant = null if target_v == null else StateBuild.ji(target_v)
	var ret: bool = rules.use_potion(run_state, cb, slot, target)
	_check(row, "ret", ret, row["ret"], fails)
	_check(row, "events", cb.queue, row["events"], fails)
	_check(row, "post", cb.to_dict(), row["post"], fails)


static func _probe_preview_block(rules: CombatRules, row: Dictionary, fails: Array[String]) -> void:
	var args: Dictionary = row["args"]
	var pre: Dictionary = row["pre"]
	var pre_player: Dictionary = pre["player"]
	var cb: CombatState = CombatState.new()
	var pst: Dictionary = pre_player["statuses"]
	StateBuild.statuses_into(pst, cb.player.statuses)
	var got: int = rules.preview_block(cb, StateBuild.ji(args["base"]))
	_check(row, "ret", got, row["ret"], fails)


static func _probe_preview_enemy(
	content: ContentDB, rules: CombatRules, row: Dictionary, fails: Array[String]
) -> void:
	var pre: Dictionary = row["pre"]
	var pre_player: Dictionary = pre["player"]
	var cb: CombatState = CombatState.new()
	var pst: Dictionary = pre_player["statuses"]
	StateBuild.statuses_into(pst, cb.player.statuses)
	var ed: Dictionary = pre["enemy"]
	var e: EnemyCombatant = StateBuild.enemy_from(content, ed)
	var got: Variant = rules.preview_enemy_dmg(cb, e)
	_check(row, "ret", got, row.get("ret"), fails)


static func _check(
	row: Dictionary, field: String, actual: Variant, expected: Variant, fails: Array[String]
) -> void:
	var diverged: String = Diff.deep_eq(StateBuild.jsonish(actual), expected)
	if diverged == "":
		return
	fails.append(
		"probe %s: %s diverges at %s\n      expected: %s\n      actual:   %s"
		% [
			str(row["tag"]), field, diverged,
			JSON.stringify(expected).left(400), JSON.stringify(actual).left(400),
		]
	)
