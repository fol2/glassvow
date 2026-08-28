extends SceneTree
## Fixed direct-mediator and whole-run probe for issue #421 Hearth payoff identity.

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
	var payoff_level: String = str(plan.get("payoffLevel", ""))
	if not ["omitted", "three", "zero"].has(payoff_level):
		_fail("payoffLevel must be omitted, three or zero")
		return
	if payoff_level != "omitted":
		CombatRules.set_research421_hearth_payoff_per_ember(
			3 if payoff_level == "three" else 0)
	var priority_v: Variant = plan.get("priority", false)
	if typeof(priority_v) != TYPE_BOOL:
		_fail("priority must be a bool when present")
		return
	var priority: bool = priority_v
	Pilot.set_hearth_priority(priority)
	var mode: String = str(plan.get("mode", ""))
	var rows: Array[Dictionary] = []
	if mode == "whole-runs":
		var capture_v: Variant = plan.get("capture", false)
		if typeof(capture_v) != TYPE_BOOL:
			_fail("capture must be a bool")
			return
		var capture: bool = capture_v
		rows = _whole_runs(content, plan.get("rows", []), capture)
	elif mode == "focused-controls":
		rows = _focused_controls(content, plan.get("controls", []))
	else:
		_fail("mode must be whole-runs or focused-controls")
		return
	var output: Dictionary = {
		"schemaVersion": 1,
		"planSha256": FileAccess.get_sha256(str(opts["plan"])),
		"probeSha256": FileAccess.get_sha256(str(get_script().resource_path)),
		"payoffLevel": payoff_level,
		"rows": rows,
	}
	var file: FileAccess = FileAccess.open(str(opts["out"]), FileAccess.WRITE)
	if file == null:
		_fail("cannot write output")
		return
	file.store_string(JSON.stringify(output) + "\n")
	print(JSON.stringify({"status": "PASS", "rows": rows.size()}))
	quit(0)


func _whole_runs(
	content: ContentDB, raw_rows: Variant, capture: bool
) -> Array[Dictionary]:
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
		var trace: Dictionary = {"capture": capture}
		var row: Dictionary = Sim.simulate(
			content, str(spec["aspect"]), _int(spec, "seed"), _int(spec, "vow"),
			PackedStringArray(), policy[0], false, false, {}, null, false,
			{"schemaVersion": 1}, trace)
		row["trajectory"] = trace
		rows.append(row)
	return rows


func _focused_controls(
	content: ContentDB, raw_controls: Variant
) -> Array[Dictionary]:
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
		run.aspect = 0
		run.player.hp = _int(spec, "playerHp")
		run.player.max_hp = _int(spec, "playerMaxHp")
		for relic_v: Variant in spec.get("relics", []):
			run.player.relics.append(str(relic_v))
		var cb: CombatState = CombatState.new()
		cb.player.hp = run.player.hp
		cb.player.max_hp = run.player.max_hp
		cb.embers = _int(spec, "embers")
		cb.hp_lost = 1
		var hp_before: int = run.player.hp
		var rng_before: int = run.rng_state()
		var rules: CombatRules = CombatRules.new(content)
		rules._win_combat(run, cb)
		rows.append({
			"id": str(spec["id"]), "runHpBefore": hp_before,
			"runHpAfter": run.player.hp, "runHpDelta": run.player.hp - hp_before,
			"combatPlayerHp": cb.player.hp, "terminalEmbers": cb.embers,
			"queue": cb.queue.duplicate(true), "result": cb.result, "over": cb.over,
			"relics": run.player.relics.duplicate(),
			"rngBefore": rng_before, "rngAfter": run.rng_state(),
		})
	return rows


static func _int(values: Dictionary, key: String) -> int:
	return int(float(str(values[key])))


func _fail(message: String) -> void:
	push_error("research_421_hearth_payoff_probe: %s" % message)
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
