extends SceneTree
## Direct source and identity probe for issue #421 Emberglass Memory.

const RELIC_ID: String = "researchEmberglassMemory"
const CARRIER_KEY: String = "relic.emberglassMemory"


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
	var content: ContentDB = ContentDB.load_full(false)
	content.relics[RELIC_ID] = {
		"name": "Emberglass Memory", "rarity": "uncommon",
		"text": "As the Duskblade, preserve up to 1 unspent Ember after victory for the next combat.",
	}
	var rows: Array[Dictionary] = []
	var specs: Array = specs_v
	for spec_v: Variant in specs:
		if typeof(spec_v) != TYPE_DICTIONARY:
			_fail("every row must be a dictionary")
			return
		var spec: Dictionary = spec_v
		rows.append(_execute(content, spec))
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


func _execute(content: ContentDB, spec: Dictionary) -> Dictionary:
	if str(spec.get("kind", "")) == "composition":
		return {
			"id": str(spec.get("id", "")),
			"factorAvailable": CombatRules.new(content).has_method(
				"configure_research421_emberglass_memory"),
			"uninterrupted": _composition_lane(content, spec, false),
			"resumed": _composition_lane(content, spec, true),
		}
	var run: RunState = _new_run(content, spec)
	var rules: CombatRules = CombatRules.new(content)
	var available: bool = _configure(rules, spec)
	var kind: String = str(spec.get("kind", ""))
	var before: Dictionary
	var after: Dictionary
	if kind == "start":
		before = _snapshot(run, null)
		var start_cb: CombatState = rules.start_combat(run, ["sporeling"], &"normal")
		after = _snapshot(run, start_cb)
	elif kind == "manual-start":
		var manual_cb: CombatState = CombatState.new()
		manual_cb.embers = _int(spec, "startEmbers")
		manual_cb.ember_cap = _int(spec, "startCap")
		before = _snapshot(run, manual_cb)
		rules._apply_start_relics(run, manual_cb)
		after = _snapshot(run, manual_cb)
	else:
		var cb: CombatState = rules.start_combat(run, ["sporeling"], &"normal")
		cb.embers = _int(spec, "terminalEmbers")
		before = _snapshot(run, cb)
		if kind == "win":
			rules._win_combat(run, cb)
		elif kind == "loss":
			rules.lose_combat(run, cb)
		else:
			return {"id": str(spec.get("id", "")), "error": "unknown kind"}
		after = _snapshot(run, cb)
	return {
		"id": str(spec.get("id", "")), "factorAvailable": available,
		"configured": spec.get("configured", true) == true,
		"charge": spec.get("charge", false) == true,
		"consume": spec.get("consume", false) == true,
		"before": before, "after": after,
	}


func _composition_lane(content: ContentDB, spec: Dictionary, resume: bool) -> Dictionary:
	var run: RunState = _new_run(content, spec)
	var rules: CombatRules = CombatRules.new(content)
	_configure(rules, spec)
	var first: CombatState = rules.start_combat(run, ["sporeling"], &"normal")
	first.embers = _int(spec, "terminalEmbers")
	rules._win_combat(run, first)
	var after_charge: Dictionary = _snapshot(run, first)
	if resume:
		var loaded: RunState = RunState.from_save_dict(run.to_save_dict(), content)
		if loaded == null:
			return {"error": "save reload rejected"}
		run = loaded
		rules = CombatRules.new(content)
		_configure(rules, spec)
	var second: CombatState = rules.start_combat(run, ["sporeling"], &"normal")
	var after_consume: Dictionary = _snapshot(run, second)
	var third: CombatState = rules.start_combat(run, ["sporeling"], &"normal")
	return {
		"afterCharge": after_charge,
		"afterConsume": after_consume,
		"afterSecondStart": _snapshot(run, third),
	}


func _new_run(content: ContentDB, spec: Dictionary) -> RunState:
	var run: RunState = RunState.new_run(content, _int(spec, "seed"),
		"research-421-%s" % str(spec.get("id", "row")),
		{"aspect": _int(spec, "aspect")})
	if spec.get("owned", false) == true:
		run.player.relics.append(RELIC_ID)
	var relics_v: Variant = spec.get("additionalRelics", [])
	if typeof(relics_v) == TYPE_ARRAY:
		var relics: Array = relics_v
		for relic_v: Variant in relics:
			var relic_id: String = str(relic_v)
			if not run.player.relics.has(relic_id):
				run.player.relics.append(relic_id)
	if spec.has("omen"):
		run.omens[0] = str(spec["omen"])
	if spec.has("carrier"):
		run.quest_scratch[CARRIER_KEY] = spec["carrier"]
	run.quest_scratch["neighbour"] = {"kept": 7}
	return run


func _configure(rules: CombatRules, spec: Dictionary) -> bool:
	var available: bool = rules.has_method("configure_research421_emberglass_memory")
	if not available:
		return false
	rules.call("configure_research421_emberglass_memory", false, false)
	if spec.get("configured", true) == true:
		rules.call("configure_research421_emberglass_memory",
			spec.get("charge", false) == true, spec.get("consume", false) == true)
	return true


static func _snapshot(run: RunState, cb: CombatState) -> Dictionary:
	var combat: Variant = null
	if cb != null:
		combat = {
			"projection": cb.to_dict(), "emberCap": cb.ember_cap,
			"events": cb.queue.duplicate(true),
		}
	return {"run": run.to_save_dict(), "combat": combat, "rng": run.rng_state()}


static func _int(values: Dictionary, key: String) -> int:
	return int(float(str(values.get(key, 0))))


func _fail(message: String) -> void:
	push_error("research_421_emberglass_direct_probe: %s" % message)
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
