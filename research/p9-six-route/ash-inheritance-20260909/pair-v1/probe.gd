extends SceneTree
const Sim: GDScript = preload("res://tools/observed_sim.gd")
const Stock: GDScript = preload("res://tools/balance_sim.gd")
const Policy: GDScript = preload("res://tools/balance_policy.gd")
const Observer: GDScript = preload("res://observed_game.gd")

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 3:
		push_error("PAIR_INPUT"); quit(2); return
	var cfg: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var output: FileAccess = FileAccess.open(args[1], FileAccess.WRITE)
	var traces: FileAccess = FileAccess.open(args[2], FileAccess.WRITE)
	var db: ContentDB = BalanceCatalogue.load_prepared({"path":"res://content/full-content.json"})
	if not cfg is Dictionary or output == null or traces == null or db == null:
		push_error("PAIR_FILES"); quit(2); return
	var policies: Array[Dictionary] = Policy.sample_range(int(cfg.root), int(cfg.first), int(cfg.count))
	var sources: Dictionary = {}
	for name: String in ["balance_sim.gd", "observed_sim.gd", "balance_pilot.gd", "balance_policy.gd", "balance_metrics.gd", "vow_incentives.gd"]:
		sources[name] = FileAccess.get_sha256("res://tools/" + name)
	output.store_line(JSON.stringify({"kind":"header", "config":cfg, "policies":policies,
		"engine":Engine.get_version_info()["string"], "sources":sources,
		"content_sha256":FileAccess.get_sha256("res://content/full-content.json"),
		"combat_sha256":FileAccess.get_sha256("res://domain/rules/combat.gd"),
		"probe_sha256":FileAccess.get_sha256("res://probe.gd"),
		"observer_sha256":FileAccess.get_sha256("res://observed_game.gd")}))
	output.flush()
	for offset: int in range(policies.size()):
		var index: int = int(cfg.first) + offset
		for seed_v: Variant in cfg.seeds:
			var seed: int = int(seed_v)
			var key: String = "%d:%d:%d" % [int(cfg.vow), index, seed]
			Observer.begin(key, traces)
			var row: Dictionary = Sim.simulate(db, "ashwarden", seed, int(cfg.vow), PackedStringArray(), policies[offset], false, false)
			var same: bool = true
			if bool(cfg.get("integration", false)):
				var control: Dictionary = Stock.simulate(db, "ashwarden", seed, int(cfg.vow), PackedStringArray(), policies[offset], false, false)
				same = row == control
			output.store_line(JSON.stringify({"kind":"outcome", "row_key":key, "index":index,
				"seed":seed, "vow":int(cfg.vow), "policy":policies[offset], "row":row,
				"observer_matches_stock":same if bool(cfg.get("integration",false)) else null}))
			output.flush()
	output.store_line(JSON.stringify({"kind":"terminal", "rows":policies.size() * cfg.seeds.size()}))
	output.close(); traces.close(); quit(0)
