extends SceneTree
## Pristine current-main whole-run anchor for the Dusk acquisition identity preflight.

const Policy: GDScript = preload("res://tools/balance_policy.gd")
const Sim: GDScript = preload("res://tools/balance_sim.gd")


func _initialize() -> void:
	var opts: Dictionary = _options(OS.get_cmdline_user_args())
	if opts.has("error"):
		push_error("research_421_dusk_acquisition_probe: %s" % str(opts["error"]))
		quit(2)
		return
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(opts["plan"])))
	if typeof(raw) != TYPE_DICTIONARY:
		push_error("research_421_dusk_acquisition_probe: plan must be a dictionary")
		quit(2)
		return
	var plan: Dictionary = raw
	var rows_v: Variant = plan.get("rows", [])
	if typeof(rows_v) != TYPE_ARRAY:
		push_error("research_421_dusk_acquisition_probe: rows must be an array")
		quit(2)
		return
	for spec_v: Variant in rows_v:
		if typeof(spec_v) != TYPE_DICTIONARY:
			push_error("research_421_dusk_acquisition_probe: every row must be a dictionary")
			quit(2)
			return
		var validation: Dictionary = spec_v
		if validation.has("acquisition"):
			push_error("research_421_dusk_acquisition_probe: pristine rows accept no acquisition key")
			quit(2)
			return
	var loaded: Dictionary = BalanceCatalogue.open({"content": str(plan.get("content", ""))})
	if loaded.has("error"):
		push_error("research_421_dusk_acquisition_probe: %s" % str(loaded["error"]))
		quit(2)
		return
	var content: ContentDB = BalanceCatalogue.load_prepared(loaded)
	if content == null:
		push_error("research_421_dusk_acquisition_probe: content did not load")
		quit(2)
		return
	var rows: Array[Dictionary] = []
	for spec_v: Variant in rows_v:
		var spec: Dictionary = spec_v
		var sampled: Array[Dictionary] = Policy.sample_range(
			int(float(str(spec["policyRoot"]))), int(float(str(spec["policyIndex"]))), 1)
		rows.append(Sim.simulate(
			content, str(spec["aspect"]), int(float(str(spec["seed"]))),
			int(float(str(spec["vow"]))), PackedStringArray(), sampled[0],
			false, false, {}, null, false))
	_write(opts, loaded, rows)


func _write(opts: Dictionary, loaded: Dictionary, rows: Array[Dictionary]) -> void:
	var output: Dictionary = {
		"schemaVersion": 1,
		"planSha256": FileAccess.get_sha256(str(opts["plan"])),
		"probeSha256": FileAccess.get_sha256(str(get_script().resource_path)),
		"contentIdentity": loaded["identity"],
		"rows": rows,
	}
	var file: FileAccess = FileAccess.open(str(opts["out"]), FileAccess.WRITE)
	if file == null:
		push_error("research_421_dusk_acquisition_probe: cannot write output")
		quit(2)
		return
	file.store_string(JSON.stringify(output) + "\n")
	print(JSON.stringify({"status": "PASS", "rows": rows.size()}))
	quit(0)


func _options(args: PackedStringArray) -> Dictionary:
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
