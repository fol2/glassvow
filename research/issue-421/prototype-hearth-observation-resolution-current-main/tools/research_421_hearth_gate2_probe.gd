extends SceneTree
## Fresh qualified-runtime Hearth Gate 2 probe for issue #421.

const Policy: GDScript = preload("res://tools/balance_policy.gd")
const Pilot: GDScript = preload("res://tools/balance_pilot.gd")
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
	if mode == "controls":
		rows = _controls(content, plan.get("rows", []))
	elif mode == "whole-runs":
		rows = _whole_runs(content, plan)
	else:
		_fail("mode must be controls or whole-runs")
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


func _controls(content: ContentDB, raw_rows: Variant) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if typeof(raw_rows) != TYPE_ARRAY:
		_fail("control rows must be an array")
		return rows
	for spec_v: Variant in raw_rows:
		if typeof(spec_v) != TYPE_DICTIONARY:
			_fail("every control row must be a dictionary")
			return []
		var spec: Dictionary = spec_v
		if str(spec.get("kind", "")) == "payoff":
			rows.append(_payoff_control(content, spec))
		elif str(spec.get("kind", "")) == "priority":
			rows.append(_priority_control(content, spec))
		else:
			_fail("control kind must be payoff or priority")
			return []
	return rows


func _payoff_control(content: ContentDB, spec: Dictionary) -> Dictionary:
	CombatRules.set_research421_hearth_payoff_per_ember(_int(spec, "payoff"))
	var trace: Dictionary = {"captureHearth": true, "hearthBranchEvents": []}
	CombatRules.set_research421_hearth_observation(trace, _int(spec, "fight"))
	var run: RunState = RunState.new()
	run.aspect = 0
	run.player.hp = _int(spec, "hp")
	run.player.max_hp = _int(spec, "maxHp")
	for relic_v: Variant in spec.get("relics", []):
		run.player.relics.append(str(relic_v))
	var cb: CombatState = CombatState.new()
	cb.player.hp = run.player.hp
	cb.player.max_hp = run.player.max_hp
	cb.embers = _int(spec, "embers")
	cb.hp_lost = 1
	var rng_before: int = run.rng_state()
	var rules: CombatRules = CombatRules.new(content)
	rules._win_combat(run, cb)
	return {
		"id": str(spec["id"]), "kind": "payoff", "payoff": _int(spec, "payoff"),
		"fight": _int(spec, "fight"), "hp": run.player.hp, "maxHp": run.player.max_hp,
		"relics": run.player.relics.duplicate(), "embers": cb.embers,
		"result": cb.result, "over": cb.over, "queue": cb.queue.duplicate(true),
		"rngBefore": rng_before, "rngAfter": run.rng_state(), "trace": trace,
	}


func _priority_control(content: ContentDB, spec: Dictionary) -> Dictionary:
	Pilot.apply_policy({})
	var banned_v: Variant = spec.get("banned", [])
	if typeof(banned_v) != TYPE_ARRAY:
		_fail("priority banned list must be an array")
		return {}
	var banned_values: Array = banned_v
	var banned: PackedStringArray = PackedStringArray()
	for id_v: Variant in banned_values:
		banned.append(str(id_v))
	Pilot.set_ban(banned)
	Pilot.set_modes(_bool(spec, "randomBuild"), false)
	Pilot.set_research421_hearth_priority(_bool(spec, "enabled"))
	var rng: Rng = Rng.new(_int(spec, "rngSeed"))
	var rng_before: int = rng.get_state()
	var offered: Array = spec.get("offered", [])
	var selected: String = Pilot.choose_relic(offered, content, 0, rng)
	return {
		"id": str(spec["id"]), "kind": "priority", "enabled": _bool(spec, "enabled"),
		"randomBuild": _bool(spec, "randomBuild"), "banned": spec.get("banned", []),
		"offered": offered.duplicate(true), "selected": selected,
		"rngBefore": rng_before, "rngAfter": rng.get_state(),
	}


func _whole_runs(content: ContentDB, plan: Dictionary) -> Array[Dictionary]:
	var raw_rows: Variant = plan.get("rows", [])
	if typeof(raw_rows) != TYPE_ARRAY:
		_fail("whole-run rows must be an array")
		return []
	var settings_v: Variant = plan.get("settings", {})
	if typeof(settings_v) != TYPE_DICTIONARY:
		_fail("settings must be a dictionary")
		return []
	var settings: Dictionary = settings_v
	var rows: Array[Dictionary] = []
	for spec_v: Variant in raw_rows:
		if typeof(spec_v) != TYPE_DICTIONARY:
			_fail("every whole-run row must be a dictionary")
			return []
		var spec: Dictionary = spec_v
		var policies: Array[Dictionary] = Policy.sample_range(
			_int(spec, "policyRoot"), _int(spec, "policyIndex"), 1)
		var trace: Dictionary = {"captureHearth": true, "pathCapture": true}
		var row: Dictionary = Sim.simulate(
			content, str(spec["aspect"]), _int(spec, "seed"), _int(spec, "vow"),
			PackedStringArray(), policies[0], false, false, {}, null, false, trace, settings)
		row["policyIndex"] = _int(spec, "policyIndex")
		row["researchTrace"] = trace
		rows.append(row)
	return rows


static func _int(values: Dictionary, key: String) -> int:
	var value: Variant = values.get(key)
	return value if typeof(value) == TYPE_INT else int(float(str(value)))


static func _bool(values: Dictionary, key: String) -> bool:
	var value: Variant = values.get(key)
	return value if typeof(value) == TYPE_BOOL else false


func _fail(message: String) -> void:
	push_error("research_421_hearth_gate2_probe: %s" % message)
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
