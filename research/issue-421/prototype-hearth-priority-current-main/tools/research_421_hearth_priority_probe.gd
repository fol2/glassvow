extends SceneTree
## Fixed whole-run and direct-choice probe for issue #421 Hearth priority identity.

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
	var priority_v: Variant = plan.get("priority", false)
	if typeof(priority_v) != TYPE_BOOL:
		_fail("priority must be a bool when present")
		return
	var priority: bool = priority_v
	var mode: String = str(plan.get("mode", ""))
	var rows: Array[Dictionary] = []
	if mode == "whole-runs":
		rows = _whole_runs(content, plan.get("rows", []), priority)
	elif mode == "focused-controls":
		rows = _focused_controls(content, plan.get("controls", []), priority)
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


func _whole_runs(
	content: ContentDB, raw_rows: Variant, priority: bool
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
		Pilot.set_hearth_priority(priority)
		var trace: Dictionary = {"capture": true}
		var row: Dictionary = Sim.simulate(
			content, str(spec["aspect"]), _int(spec, "seed"), _int(spec, "vow"),
			PackedStringArray(), policy[0], false, false, {}, null, false,
			{"schemaVersion": 1}, trace)
		row["trajectory"] = trace
		rows.append(row)
	return rows


func _focused_controls(
	content: ContentDB, raw_controls: Variant, priority: bool
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
		var policy: Array[Dictionary] = Policy.sample_range(
			_int(spec, "policyRoot"), _int(spec, "policyIndex"), 1)
		var banned: PackedStringArray = PackedStringArray()
		for id_v: Variant in spec.get("banned", []):
			banned.append(str(id_v))
		Pilot.set_ban(banned)
		Pilot.apply_policy(policy[0])
		Pilot.set_modes(spec.get("randomBuild", false) == true, false)
		Pilot.set_hearth_priority(priority)
		var rng: Rng = Rng.new(_int(spec, "seed"))
		var before: int = rng.get_state()
		var offered: Array = spec.get("offered", []).duplicate()
		var chosen: String = Pilot.choose_relic(
			offered, content, _int(spec, "aspect"), rng)
		rows.append({
			"id": str(spec["id"]), "offered": offered, "chosen": chosen,
			"rngBefore": before, "rngAfter": rng.get_state(),
		})
	return rows


static func _int(values: Dictionary, key: String) -> int:
	return int(float(str(values[key])))


func _fail(message: String) -> void:
	push_error("research_421_hearth_priority_probe: %s" % message)
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
