extends SceneTree
## Fixed whole-run capacity probe for issue #421 Ward spend v3.

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
	var loaded: Dictionary = BalanceCatalogue.open({"content": str(plan.get("content", ""))})
	if loaded.has("error"):
		_fail(str(loaded["error"]))
		return
	var content: ContentDB = BalanceCatalogue.load_prepared(loaded)
	if content == null:
		_fail("content did not load")
		return
	var rows_v: Variant = plan.get("rows", [])
	if typeof(rows_v) != TYPE_ARRAY:
		_fail("rows must be an array")
		return
	var rows: Array[Dictionary] = []
	for spec_v: Variant in rows_v:
		if typeof(spec_v) != TYPE_DICTIONARY:
			_fail("every row must be a dictionary")
			return
		var spec: Dictionary = spec_v
		var row: Dictionary = _whole_run(content, spec)
		if not str(row.get("error", "")).is_empty():
			_fail("%s: %s" % [str(spec.get("id", "?")), str(row["error"])])
			return
		rows.append(row)
	var output: Dictionary = {
		"schemaVersion": 1,
		"planSha256": FileAccess.get_sha256(str(opts["plan"])),
		"probeSha256": FileAccess.get_sha256(str(get_script().resource_path)),
		"contentIdentity": loaded["identity"],
		"rows": rows,
	}
	var file: FileAccess = FileAccess.open(str(opts["out"]), FileAccess.WRITE)
	if file == null:
		_fail("cannot write output")
		return
	file.store_string(JSON.stringify(output) + "\n")
	print(JSON.stringify({"status": "PASS", "rows": rows.size()}))
	quit(0)


func _whole_run(content: ContentDB, spec: Dictionary) -> Dictionary:
	var sampled: Array[Dictionary] = Policy.sample_range(
		_int(spec, "policyRoot"), _int(spec, "policyIndex"), 1
	)
	var settings_v: Variant = spec.get("research421", {})
	if typeof(settings_v) != TYPE_DICTIONARY:
		return {"error": "research421 must be a dictionary"}
	var settings: Dictionary = settings_v
	var row: Dictionary = Sim.simulate(
		content, str(spec["aspect"]), _int(spec, "seed"), _int(spec, "vow"),
		PackedStringArray(), sampled[0], false, false, {}, null, false, settings
	)
	row["id"] = str(spec.get("id", ""))
	return row


static func _int(values: Dictionary, key: String) -> int:
	return int(float(str(values.get(key, 0))))


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


func _fail(message: String) -> void:
	push_error("research_421_ward_spend_capacity_probe: %s" % message)
	quit(2)
