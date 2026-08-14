class_name BalanceSweep
extends SceneTree
## Shardable #215 Slice C sampler, controls and raw-run writer.
const Sim: GDScript = preload("res://tools/balance_sim.gd")
const Pilot: GDScript = preload("res://tools/balance_pilot.gd")
const Policy: GDScript = preload("res://tools/balance_policy.gd")

func _initialize() -> void:
	var opts: Dictionary = _options(OS.get_cmdline_user_args())
	if opts.has("error"):
		push_error("balance_sweep: %s" % opts["error"])
		quit(2)
		return
	var content: ContentDB = ContentDB.load_full(false)
	var git_out: Array = []
	OS.execute("git", ["rev-parse", "HEAD"], git_out)
	var manifest: Dictionary = opts.duplicate()
	manifest["commit"] = str(git_out[0]).strip_edges() if not git_out.is_empty() else "unknown"
	manifest["godot"] = Engine.get_version_info().get("string", "unknown")
	manifest["contentSha256"] = FileAccess.get_sha256(ContentDB.FULL_PATH)
	var file: FileAccess = FileAccess.open(str(opts["out"]), FileAccess.WRITE)
	if file == null:
		push_error("balance_sweep: cannot write --out")
		quit(2)
		return
	var count: int = 0
	if opts["mode"] == "controls":
		var rows: Array[Dictionary] = _controls(content, opts)
		count = rows.size()
		file.store_line(JSON.stringify({"manifest": manifest, "runs": rows}))
	else:
		file.store_line(JSON.stringify({"manifest": manifest}))
		count = _write_policies(content, opts, file)
	print(JSON.stringify({"mode": opts["mode"], "runs": count, "out": opts["out"]}))
	quit(0)

static func _controls(content: ContentDB, opts: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var arms: Array[Dictionary] = [
		{"arm": 1, "build": 0, "play": 0}, {"arm": 2, "build": 1, "play": 0},
		{"arm": 3, "build": 0, "play": 1}, {"arm": 4, "build": 1, "play": 1},
	]
	for arm: Dictionary in arms:
		for aspect: String in ["duskblade", "ashwarden"]:
			for vow: int in [0, 5]:
				for offset: int in range(_i(opts, "seeds")):
					var row: Dictionary = Sim.simulate(content, aspect, _i(opts, "seed0") + offset,
						vow, PackedStringArray(), {}, _i(arm, "build") == 1, _i(arm, "play") == 1)
					row["arm"] = arm["arm"]
					rows.append(row)
	return rows

static func _write_policies(content: ContentDB, opts: Dictionary, file: FileAccess) -> int:
	var count: int = 0
	var policies: Array[Dictionary] = Policy.sample_range(_i(opts, "rootSeed"),
		_i(opts, "policyFirst"), _i(opts, "policyCount"))
	var vows: Array[int] = [0]
	if opts["mode"] == "sweep":
		vows.append(5)
	for local_index: int in range(policies.size()):
		var policy_index: int = _i(opts, "policyFirst") + local_index
		for aspect: String in ["duskblade", "ashwarden"]:
			for vow: int in vows:
				for offset: int in range(_i(opts, "seeds")):
					var row: Dictionary = Sim.simulate(content, aspect, _i(opts, "seed0") + offset,
						vow, PackedStringArray(), policies[local_index])
					file.store_line(JSON.stringify({"policyIndex": policy_index, "seed": row["seed"],
						"aspect": row["aspect"], "vow": row["vow"], "outcome": row["outcome"],
						"error": row["error"], "deck": row["deck"], "fights": row["fights"],
						"rng": row["rng"], "policy": row["policy"]}))
					count += 1
	return count

static func _options(args: PackedStringArray) -> Dictionary:
	var out: Dictionary = {"mode": "sweep", "out": "", "rootSeed": 215,
		"policyFirst": 0, "policyCount": 2000, "seeds": 40, "seed0": 3000}
	for arg: String in args:
		if not arg.begins_with("--") or not arg.contains("="):
			return {"error": "expected --name=value, got %s" % arg}
		var key: String = arg.get_slice("=", 0).trim_prefix("--")
		if not out.has(key):
			return {"error": "unknown option --%s" % key}
		out[key] = arg.substr(arg.find("=") + 1)
	for key: String in ["rootSeed", "policyFirst", "policyCount", "seeds", "seed0"]:
		if not str(out[key]).is_valid_int():
			return {"error": "--%s must be an integer" % key}
		out[key] = int(float(str(out[key])))
	if str(out["mode"]) not in ["preflight", "controls", "sweep"]:
		return {"error": "--mode must be preflight, controls or sweep"}
	if str(out["out"]).is_empty() or _i(out, "policyFirst") < 0 \
			or _i(out, "policyCount") < 1 or _i(out, "seeds") < 1:
		return {"error": "--out is required and counts must be positive"}
	return out

static func _i(values: Dictionary, key: String) -> int:
	return int(float(str(values[key])))
