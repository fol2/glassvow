extends SceneTree
## Fixed whole-run and direct-mediator probe for issue #421 weak-mend identity.

const Policy: GDScript = preload("res://tools/balance_policy.gd")
const Sim: GDScript = preload("res://tools/balance_sim.gd")


func _initialize() -> void:
	var opts: Dictionary = _options(OS.get_cmdline_user_args())
	if opts.has("error"):
		_fail(str(opts["error"]))
		return
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(opts["plan"])))
	if typeof(raw) != TYPE_DICTIONARY:
		_fail("plan must be a dictionary")
		return
	var plan: Dictionary = raw
	var content: ContentDB = ContentDB.load_from(str(plan.get("content", "")), false)
	if content == null:
		_fail("content did not load")
		return
	var mode: String = str(plan.get("mode", ""))
	var rows: Array[Dictionary] = []
	if mode == "whole-runs":
		rows = _whole_runs(content, plan.get("rows", []))
	elif mode == "focused-controls":
		rows = _focused_controls(content, plan.get("controls", []))
	else:
		_fail("mode must be whole-runs or focused-controls")
		return
	var output: Dictionary = {
		"schemaVersion": 1,
		"planSha256": FileAccess.get_sha256(str(opts["plan"])),
		"probeSha256": FileAccess.get_sha256(str(get_script().resource_path)),
		"rows": rows,
	}
	var file: FileAccess = FileAccess.open(str(opts["out"]), FileAccess.WRITE)
	if file == null:
		_fail("cannot write output")
		return
	file.store_string(JSON.stringify(output) + "\n")
	print(JSON.stringify({"status": "PASS", "rows": rows.size()}))
	quit(0)


func _whole_runs(content: ContentDB, raw_rows: Variant) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if typeof(raw_rows) != TYPE_ARRAY:
		_fail("rows must be an array")
		return rows
	for spec_v: Variant in raw_rows:
		if typeof(spec_v) != TYPE_DICTIONARY:
			_fail("every row must be a dictionary")
			return []
		var spec: Dictionary = spec_v
		var policy: Array[Dictionary] = Policy.sample_range(
			_int(spec, "policyRoot"), _int(spec, "policyIndex"), 1)
		var trace: Dictionary = {"capture": true}
		var row: Dictionary = Sim.simulate(
			content, str(spec["aspect"]), _int(spec, "seed"), _int(spec, "vow"),
			PackedStringArray(), policy[0], false, false, {}, null, false,
			{"schemaVersion": 1}, trace)
		row["trajectory"] = trace
		rows.append(row)
	return rows


func _focused_controls(content: ContentDB, raw_controls: Variant) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if typeof(raw_controls) != TYPE_ARRAY:
		_fail("controls must be an array")
		return rows
	for spec_v: Variant in raw_controls:
		if typeof(spec_v) != TYPE_DICTIONARY:
			_fail("every control must be a dictionary")
			return []
		var spec: Dictionary = spec_v
		var run: RunState = RunState.new()
		run.aspect = _int(spec, "aspect")
		run.player.hp = _int(spec, "playerHp")
		run.player.max_hp = _int(spec, "playerMaxHp")
		if spec.get("emberHeart", false) == true:
			run.player.relics.append("emberHeart")
		var cb: CombatState = CombatState.new()
		cb.player.hp = run.player.hp
		cb.player.max_hp = run.player.max_hp
		for enemy_v: Variant in spec.get("enemies", []):
			var enemy_spec: Dictionary = enemy_v
			var enemy: EnemyCombatant = EnemyCombatant.new()
			enemy.idx = _int(enemy_spec, "idx")
			enemy.hp = _int(enemy_spec, "hp")
			enemy.max_hp = _int(enemy_spec, "maxHp")
			enemy.statuses = enemy_spec.get("statuses", {}).duplicate(true)
			cb.enemies.append(enemy)
		var rng_before: int = run.rng_state()
		var rules: CombatRules = CombatRules.new(content)
		var healed: int = rules.heal_player(
			run, null if spec.get("postCombat", false) == true else cb,
			_int(spec, "heal"))
		var enemies: Array[Dictionary] = []
		for enemy: EnemyCombatant in cb.enemies:
			enemies.append({"idx": enemy.idx, "hp": enemy.hp,
				"statuses": enemy.statuses.duplicate(true)})
		rows.append({
			"id": str(spec["id"]), "healed": healed,
			"combatPlayerHp": cb.player.hp, "runPlayerHp": run.player.hp,
			"enemies": enemies, "queue": cb.queue.duplicate(true),
			"rngBefore": rng_before, "rngAfter": run.rng_state(),
		})
	return rows


static func _int(values: Dictionary, key: String) -> int:
	return int(float(str(values[key])))


func _fail(message: String) -> void:
	push_error("research_421_weak_mend_probe: %s" % message)
	quit(2)


static func _options(args: PackedStringArray) -> Dictionary:
	var out: Dictionary = {"plan": "", "out": ""}
	for arg: String in args:
		if not arg.begins_with("--") or not arg.contains("="):
			return {"error": "expected --name=value"}
		var key: String = arg.get_slice("=", 0).trim_prefix("--")
		if not out.has(key):
			return {"error": "unknown option --%s" % key}
		out[key] = arg.substr(arg.find("=") + 1)
	if str(out["plan"]).is_empty() or str(out["out"]).is_empty():
		return {"error": "--plan and --out are required"}
	return out
