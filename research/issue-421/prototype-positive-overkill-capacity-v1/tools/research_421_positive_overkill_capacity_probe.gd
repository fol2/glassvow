extends SceneTree
## Fixed-policy whole-run capacity probe for issue #421 positive-overkill excess.

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
	var rules: CombatRules = CombatRules.new(content)
	var factor_available: bool = rules.has_method("configure_research421_positive_overkill")
	var rows: Array[Dictionary] = []
	for spec_v: Variant in rows_v:
		if typeof(spec_v) != TYPE_DICTIONARY:
			_fail("every row must be a dictionary")
			return
		var spec: Dictionary = spec_v
		for key: String in ["producer", "consumer"]:
			if spec.has(key) and typeof(spec[key]) != TYPE_BOOL:
				_fail("%s must be boolean" % key)
				return
		var configured: bool = spec.has("producer") or spec.has("consumer")
		var producer: bool = spec.get("producer", false)
		var consumer: bool = spec.get("consumer", false)
		if configured:
			if not factor_available:
				_fail("excess interface unavailable")
				return
			rules.call("configure_research421_positive_overkill", producer, consumer)
		var sampled: Array[Dictionary] = Policy.sample_range(
			_int(spec, "policyRoot"), _int(spec, "policyIndex"), 1)
		var row: Dictionary = Sim.simulate(
			content, str(spec["aspect"]), _int(spec, "seed"), _int(spec, "vow"),
			PackedStringArray(), sampled[0])
		row["research421PolicyIndex"] = _int(spec, "policyIndex")
		row["research421FactorAvailable"] = factor_available
		row["research421Configured"] = configured
		row["research421Producer"] = producer
		row["research421Consumer"] = consumer
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


static func _int(values: Dictionary, key: String) -> int:
	return int(float(str(values.get(key, 0))))


func _fail(message: String) -> void:
	push_error("research_421_positive_overkill_capacity_probe: %s" % message)
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
