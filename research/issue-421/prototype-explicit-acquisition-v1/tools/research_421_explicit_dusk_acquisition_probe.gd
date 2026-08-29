extends SceneTree
## Research-only explicit Dusk acquisition identity probe.

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
	var rows_v: Variant = plan.get("rows", [])
	if typeof(rows_v) != TYPE_ARRAY:
		_fail("rows must be an array")
		return
	for spec_v: Variant in rows_v:
		if typeof(spec_v) != TYPE_DICTIONARY:
			_fail("every row must be a dictionary")
			return
		var validation: Dictionary = spec_v
		var acquisition: String = str(validation.get("acquisition", ""))
		if acquisition not in ["", "off", "executioner", "guardedStrike"]:
			_fail("acquisition accepts only omitted, off, executioner or guardedStrike")
			return
		if str(validation.get("mode", "")) == "whole" \
				and acquisition in ["executioner", "guardedStrike"]:
			_fail("enabled whole-run is prohibited during identity preflight")
			return
	var loaded: Dictionary = BalanceCatalogue.open({"content": str(plan.get("content", ""))})
	if loaded.has("error"):
		_fail(str(loaded["error"]))
		return
	var content: ContentDB = BalanceCatalogue.load_prepared(loaded)
	if content == null:
		_fail("content did not load")
		return
	var rows: Array[Dictionary] = []
	for spec_v: Variant in rows_v:
		var spec: Dictionary = spec_v
		if str(spec.get("mode", "")) == "whole":
			rows.append(_whole(content, spec))
		elif str(spec.get("mode", "")) == "direct":
			rows.append(_direct(content, spec))
		else:
			_fail("mode accepts only whole or direct")
			return
	_write(opts, loaded, rows)


func _whole(content: ContentDB, spec: Dictionary) -> Dictionary:
	var sampled: Array[Dictionary] = Policy.sample_range(
		int(float(str(spec["policyRoot"]))), int(float(str(spec["policyIndex"]))), 1)
	if not spec.has("acquisition"):
		return Sim.simulate(
			content, str(spec["aspect"]), int(float(str(spec["seed"]))),
			int(float(str(spec["vow"]))), PackedStringArray(), sampled[0],
			false, false, {}, null, false, false)
	return Sim.simulate(
		content, str(spec["aspect"]), int(float(str(spec["seed"]))),
		int(float(str(spec["vow"]))), PackedStringArray(), sampled[0],
		false, false, {}, null, false, false, str(spec["acquisition"]))


func _direct(content: ContentDB, spec: Dictionary) -> Dictionary:
	var random_build: bool = spec.get("randomBuild", false) == true
	var aspect: String = str(spec.get("aspect", "duskblade"))
	var acquisition: String = str(spec.get("acquisition", ""))
	var seed: int = int(float(str(spec.get("seed", 0))))
	var choice_rng: Rng = Rng.new(seed)
	var choice_rng_before: int = choice_rng.get_state()
	var choice: String = acquisition \
		if aspect == "duskblade" and acquisition in ["executioner", "guardedStrike"] else ""
	var choice_rng_after: int = choice_rng.get_state()
	var base_profile: Dictionary = {
		"aspect": 1 if aspect == "ashwarden" else 0,
		"vow": 0,
		"reveals": content.reveal_ids.duplicate(),
		"unlocks": ["aspect2"],
		"quests": {},
		"shards": [],
		"lamplighter": false,
	}
	var enabled_profile: Dictionary = base_profile.duplicate(true)
	if not choice.is_empty():
		enabled_profile["duskPackageConsumer"] = choice
	var null_run: RunState = RunState.new_run(content, seed, "direct-null", base_profile)
	var enabled_run: RunState = RunState.new_run(content, seed, "direct-enabled", enabled_profile)
	var reloaded: RunState = RunState.from_save_dict(enabled_run.to_save_dict(), content)
	if reloaded == null:
		_fail("enabled run did not reload")
		return {}
	return {
		"id": str(spec.get("id", "")),
		"aspect": aspect,
		"acquisition": acquisition,
		"randomBuild": random_build,
		"choice": choice,
		"choiceRngBefore": choice_rng_before,
		"choiceRngAfter": choice_rng_after,
		"nullDeck": _deck(null_run),
		"enabledDeck": _deck(enabled_run),
		"reloadedDeck": _deck(reloaded),
		"nullRunRng": null_run.rng_state(),
		"enabledRunRng": enabled_run.rng_state(),
		"reloadedRunRng": reloaded.rng_state(),
		"nullUid": null_run.uid,
		"enabledUid": enabled_run.uid,
		"reloadedUid": reloaded.uid,
		"poolWave2Gate": str(content.pool_gate_cards.get("executioner", "")),
		"guardedStrikeGate": str(content.pool_gate_cards.get("guardedStrike", "")),
		"producerDefinitions": {
			"chisel": content.cards.get("chisel", {}).duplicate(true),
			"defend": content.cards.get("defend", {}).duplicate(true),
		},
		"consumerDefinitions": {
			"executioner": content.cards.get("executioner", {}).duplicate(true),
			"guardedStrike": content.cards.get("guardedStrike", {}).duplicate(true),
		},
	}


func _deck(run: RunState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for card: CardInst in run.player.deck:
		out.append({"id": String(card.id), "uid": card.uid, "up": card.up})
	return out


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
		_fail("cannot write output")
		return
	file.store_string(JSON.stringify(output) + "\n")
	print(JSON.stringify({"status": "PASS", "rows": rows.size()}))
	quit(0)


func _fail(message: String) -> void:
	push_error("research_421_explicit_dusk_acquisition_probe: %s" % message)
	quit(2)


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
