extends SceneTree
## Deterministic research-only whole-run probe for issue #421 upgrade telemetry.

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
	var specs_v: Variant = plan.get("rows", [])
	if typeof(specs_v) != TYPE_ARRAY:
		_fail("plan rows must be an array")
		return
	var loaded: Dictionary = BalanceCatalogue.open({"content": str(plan.get("content", ""))})
	if loaded.has("error"):
		_fail(str(loaded["error"]))
		return
	var content: ContentDB = BalanceCatalogue.load_prepared(loaded)
	if content == null:
		_fail("content did not load a catalogue")
		return
	var rows: Array[Dictionary] = []
	for spec_v: Variant in specs_v:
		if typeof(spec_v) != TYPE_DICTIONARY:
			_fail("every row must be a dictionary")
			return
		var spec: Dictionary = spec_v
		var row: Dictionary = _run(content, spec)
		if not str(row.get("error", "")).is_empty():
			_fail("%s: %s" % [str(spec.get("id", "?")), str(row["error"])])
			return
		rows.append(row)
	var output: Dictionary = {
		"schemaVersion": 1,
		"planSha256": FileAccess.get_sha256(str(opts["plan"])),
		"runnerSha256": FileAccess.get_sha256(str(get_script().resource_path)),
		"contentIdentity": loaded["identity"],
		"rows": rows,
	}
	var file: FileAccess = FileAccess.open(str(opts["out"]), FileAccess.WRITE)
	if file == null:
		_fail("cannot write --out")
		return
	file.store_string(JSON.stringify(output) + "\n")
	print(JSON.stringify({"status": "PASS", "rows": rows.size()}))
	quit(0)


func _run(content: ContentDB, spec: Dictionary) -> Dictionary:
	for key: String in ["id", "arm", "policyRoot", "policyIndex", "seed", "vow"]:
		if not spec.has(key):
			return {"error": "missing %s" % key}
	var arm: String = str(spec["arm"])
	if arm not in ["explicit-null", "enabled"]:
		return {"error": "arm must be explicit-null or enabled"}
	var sampled: Array[Dictionary] = Policy.sample_range(
		int(float(str(spec["policyRoot"]))), int(float(str(spec["policyIndex"]))), 1)
	var row: Dictionary = Sim.simulate(
		content, "duskblade", int(float(str(spec["seed"]))), int(float(str(spec["vow"]))),
		PackedStringArray(), sampled[0], false, false, {}, null, false, arm == "enabled")
	row["id"] = str(spec["id"])
	row["stage"] = "post-v38-upgrade-telemetry-identity"
	row["arm"] = arm
	row["policyRoot"] = int(float(str(spec["policyRoot"])))
	row["policyIndex"] = int(float(str(spec["policyIndex"])))
	return row


func _options(args: PackedStringArray) -> Dictionary:
	var out: Dictionary = {"plan": "", "out": ""}
	for arg: String in args:
		if not arg.begins_with("--") or not arg.contains("="):
			return {"error": "expected --name=value, got %s" % arg}
		var key: String = arg.get_slice("=", 0).trim_prefix("--")
		if not out.has(key):
			return {"error": "unknown option --%s" % key}
		if not str(out[key]).is_empty():
			return {"error": "duplicate --%s" % key}
		out[key] = arg.substr(arg.find("=") + 1)
	for key: String in out:
		if str(out[key]).is_empty():
			return {"error": "--%s is required" % key}
	return out


func _fail(message: String) -> void:
	push_error("research_421_upgrade_probe: %s" % message)
	quit(2)
