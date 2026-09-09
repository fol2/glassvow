extends SceneTree
const Stock = preload("res://tools/balance_sim.gd")
const Observed = preload("res://tools/observed_sim.gd")
const Recorder = preload("res://observed_game.gd")
const Policy = preload("res://tools/balance_policy.gd")

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 3 or FileAccess.file_exists(args[1]) or FileAccess.file_exists(args[2]):quit(2); return
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var db: ContentDB = BalanceCatalogue.load_prepared({"path":"res://content/full-content.json"})
	var endpoint: FileAccess = FileAccess.open(args[1],FileAccess.WRITE)
	var trace: FileAccess = FileAccess.open(args[2],FileAccess.WRITE)
	if db == null or endpoint == null or trace == null:quit(2); return
	var params: Array[Dictionary] = Policy.sample_range(int(cfg.policy_root),0,int(cfg.policies))
	var sources: Dictionary = {}
	for name: String in ["balance_sim.gd","balance_pilot.gd","balance_policy.gd","vow_incentives.gd"]:
		sources[name] = FileAccess.get_sha256("res://tools/"+name)
	endpoint.store_line(JSON.stringify({"kind":"header","config":cfg,"engine":Engine.get_version_info()["string"],
		"content_sha256":FileAccess.get_sha256("res://content/full-content.json"),"sources":sources,
		"observer_sha256":FileAccess.get_sha256("res://observed_game.gd"),"driver_sha256":FileAccess.get_sha256("res://probe.gd"),
		"observed_sim_sha256":FileAccess.get_sha256("res://tools/observed_sim.gd"),"policy_vectors":params}))
	endpoint.flush()
	for i: int in range(int(cfg.first),int(cfg.first)+int(cfg.count)):
		for offset: int in range(int(cfg.runs)):
			var seed: int = int(cfg.seed0)+offset
			var key: String = str(i)+":"+str(seed)
			Recorder.begin(key,trace)
			var row: Dictionary
			if cfg.observed:
				row = Observed.simulate(db,str(cfg.aspect),seed,int(cfg.vow),PackedStringArray(),params[i],false,false)
			else:
				row = Stock.simulate(db,str(cfg.aspect),seed,int(cfg.vow),PackedStringArray(),params[i],false,false)
			var serialized: String = JSON.stringify(row)
			endpoint.store_line(JSON.stringify({"kind":"endpoint","policy_index":i,"seed":seed,"serialized":serialized}))
			endpoint.flush()
			trace.store_line(JSON.stringify({"kind":"row_end","row_key":key,"commands":Recorder.sequence,"endpoint_sha256":serialized.sha256_text()}))
			trace.flush()
	endpoint.close();trace.close();quit(0)
