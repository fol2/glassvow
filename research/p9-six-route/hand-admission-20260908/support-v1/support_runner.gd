extends "res://support_base_runner.gd"
## Same existing controller; only independent parameter vectors and observation differ.
const HandGame = preload("res://hand_game.gd")
var trace: FileAccess
var endpoint: FileAccess
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 3 or FileAccess.file_exists(args[1]) or FileAccess.file_exists(args[2]):
		quit(2); return
	cfg = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	policy = Policy.new()
	policy.route = cfg.route
	policy.random_build = false; policy.random_play = false
	policy.params = cfg.params
	var db: ContentDB = ContentDB.load_from("res://content/full-content.json",true)
	trace = FileAccess.open(args[2],FileAccess.WRITE)
	endpoint = FileAccess.open(args[1],FileAccess.WRITE)
	if db == null or trace == null or endpoint == null:quit(2); return
	var header := {"kind":"header","engine":Engine.get_version_info(),"config":cfg,
		"content_sha256":FileAccess.get_sha256("res://content/full-content.json"),
		"runner_sha256":FileAccess.get_sha256("res://support_runner.gd"),
		"game_sha256":FileAccess.get_sha256("res://hand_game.gd")}
	endpoint.store_line(JSON.stringify(header)); endpoint.flush()
	for i: int in range(int(cfg.runs)):
		var seed: int = int(cfg.seed0)+i
		HandGame.start_row(str(cfg.id)+":"+str(seed),trace)
		var result: Dictionary = simulate(db,seed)
		if HandGame.failed:result.result = "error"
		result["policy_id"] = cfg.policy_id
		result["policy_parameters"] = cfg.params
		result["hand_counters"] = HandGame.counters.duplicate(true)
		endpoint.store_line(JSON.stringify(result)); endpoint.flush()
		HandGame.emit({"kind":"row_end","endpoint_sha256":JSON.stringify(result).sha256_text(),
			"result":result.result,"counters":HandGame.counters.duplicate(true)})
		if HandGame.failed:
			trace.close(); endpoint.close(); quit(3); return
	trace.close(); endpoint.close(); quit(0)
