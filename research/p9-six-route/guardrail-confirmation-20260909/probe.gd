extends SceneTree
## Research capture of signed arm 2. No controller substitutions or injected deck.
const Sim: GDScript = preload("res://tools/balance_sim.gd")
const Policy: GDScript = preload("res://tools/balance_policy.gd")

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("CONTROL_INPUT"); quit(2); return
	var cfg: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	if not cfg is Dictionary or int(cfg.get("arm", -1)) != 2:
		push_error("CONTROL_ARM"); quit(2); return
	var content: ContentDB = BalanceCatalogue.load_prepared({"path":"res://content/full-content.json"})
	var output: FileAccess = FileAccess.open(args[1], FileAccess.WRITE)
	if content == null or output == null:
		push_error("CONTROL_FILES"); quit(2); return
	var sources: Dictionary = {}
	for name: String in ["balance_catalogue.gd", "balance_metrics.gd", "balance_pilot.gd", "balance_policy.gd", "balance_sim.gd", "vow_incentives.gd"]:
		sources[name] = FileAccess.get_sha256("res://tools/" + name)
	output.store_line(JSON.stringify({"kind":"header", "config":cfg,
		"engine":Engine.get_version_info()["string"],
		"content_sha256":FileAccess.get_sha256("res://content/full-content.json"),
		"combat_sha256":FileAccess.get_sha256("res://domain/rules/combat.gd"),
		"driver_sha256":FileAccess.get_sha256("res://probe.gd"),
		"policy":Policy.resolve({}), "sources":sources,
		"signed_arm":{"random_build":true,"random_play":false,"ban":[]}}))
	output.flush()
	for offset: int in range(int(cfg["runs"])):
		var row: Dictionary = Sim.simulate(content, str(cfg["aspect"]), int(cfg["seed0"]) + offset,
			int(cfg["vow"]), PackedStringArray(), {}, true, false)
		row["arm"] = 2
		output.store_line(JSON.stringify(row)); output.flush()
	output.close(); quit(0)
