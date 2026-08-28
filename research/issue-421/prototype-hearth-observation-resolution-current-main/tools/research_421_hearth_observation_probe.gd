extends SceneTree
## Fresh branch-time Hearth observation witness for issue #421.

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
	if mode == "controlled":
		rows = _controlled(content, plan.get("rows", []))
	elif mode == "whole-runs":
		rows = _whole_runs(content, plan.get("rows", []), _bool(plan, "capture"))
	else:
		_fail("mode must be controlled or whole-runs")
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


func _controlled(content: ContentDB, raw_rows: Variant) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if typeof(raw_rows) != TYPE_ARRAY:
		_fail("controlled rows must be an array")
		return rows
	for spec_v: Variant in raw_rows:
		if typeof(spec_v) != TYPE_DICTIONARY:
			_fail("every controlled row must be a dictionary")
			return []
		var spec: Dictionary = spec_v
		var capture: bool = _bool(spec, "capture")
		var trace: Dictionary = {"captureHearth": capture, "hearthBranchEvents": []}
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
		rows.append({
			"state": str(spec["state"]),
			"capture": capture,
			"fight": _int(spec, "fight"),
			"hp": run.player.hp,
			"maxHp": run.player.max_hp,
			"relics": run.player.relics.duplicate(),
			"embers": cb.embers,
			"result": cb.result,
			"over": cb.over,
			"queue": cb.queue.duplicate(true),
			"rngBefore": rng_before,
			"rngAfter": run.rng_state(),
			"trace": trace,
		})
	return rows


func _whole_runs(
	content: ContentDB, raw_rows: Variant, capture: bool
) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if typeof(raw_rows) != TYPE_ARRAY:
		_fail("whole-run rows must be an array")
		return rows
	for spec_v: Variant in raw_rows:
		if typeof(spec_v) != TYPE_DICTIONARY:
			_fail("every whole-run row must be a dictionary")
			return []
		var spec: Dictionary = spec_v
		var policies: Array[Dictionary] = Policy.sample_range(
			_int(spec, "policyRoot"), _int(spec, "policyIndex"), 1)
		var trace: Dictionary = {"captureHearth": capture, "pathCapture": true}
		var row: Dictionary = Sim.simulate(
			content, str(spec["aspect"]), _int(spec, "seed"), _int(spec, "vow"),
			PackedStringArray(), policies[0], false, false, {}, null, false, trace)
		row["policyIndex"] = _int(spec, "policyIndex")
		row["researchTrace"] = trace
		rows.append(row)
	return rows


static func _int(values: Dictionary, key: String) -> int:
	var value: Variant = values.get(key)
	if typeof(value) != TYPE_INT:
		return int(float(str(value)))
	return value


static func _bool(values: Dictionary, key: String) -> bool:
	var value: Variant = values.get(key)
	return value if typeof(value) == TYPE_BOOL else false


func _fail(message: String) -> void:
	push_error("research_421_hearth_observation_probe: %s" % message)
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
