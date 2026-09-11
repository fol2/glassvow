extends "res://causal_probe.gd"
## Narrow observation regression. Existing fixed states, no policy or new cohort.
const Legacy: GDScript = preload("res://observer_old.gd")
const Expanded: GDScript = preload("res://observer_new.gd")
var case_count: int = 0
var command_count: int = 0
var failures: int = 0

func wrap_game(g: GlassvowGame, script: GDScript) -> GlassvowGame:
	var memo: Dictionary = {}
	var state: RunState = Legacy.clone_value(g.run, memo)
	var clone: GlassvowGame = script.new(db, state)
	clone.cb = Legacy.clone_value(g.cb, memo)
	clone.last_ret = Legacy.clone_value(g.last_ret, memo)
	return clone

func check_case(a: int, v: int, u: bool, context: String, old_stream: FileAccess,
		new_stream: FileAccess) -> void:
	var plain: GlassvowGame = make_game(a, v, u, context, -1)
	var old: GlassvowGame = wrap_game(plain, Legacy)
	var changed: GlassvowGame = wrap_game(plain, Expanded)
	var key: String = "%s:%d:%d:%s:%s" % [source, a, v, str(u), context]
	Legacy.begin(key, old_stream)
	Expanded.begin(key, new_stream)
	var commands: Array[Dictionary] = [
		{"t":"playCard", "uid":900, "target":null},
		{"t":"playCard", "uid":901, "target":0},
		{"t":"endTurn"}]
	for command: Dictionary in commands:
		var before: Dictionary = Legacy.snapshot(plain)
		var events: Array[Dictionary] = plain.apply(command)
		var old_events: Array[Dictionary] = old.apply(command)
		var new_events: Array[Dictionary] = changed.apply(command)
		var after: Dictionary = Legacy.snapshot(plain)
		var same: bool = events == old_events and events == new_events \
			and after == Legacy.snapshot(old) and after == Legacy.snapshot(changed)
		if not same:
			failures += 1
		output.store_line(JSON.stringify({"case":key,"sequence":command_count % 3,
			"command":command,"before":before,"after":after,"events":events,
			"same":same,"old_after":Legacy.snapshot(old),"new_after":Legacy.snapshot(changed)}))
		command_count += 1
	case_count += 1

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 3:
		quit(2)
		return
	db = ContentDB.load_full(true)
	output = FileAccess.open(args[0], FileAccess.WRITE)
	var old_stream: FileAccess = FileAccess.open(args[1], FileAccess.WRITE)
	var new_stream: FileAccess = FileAccess.open(args[2], FileAccess.WRITE)
	if db == null or output == null or old_stream == null or new_stream == null:
		quit(2)
		return
	for name: String in ["preparation", "surge", "bloodRite"]:
		source = name
		for aspect: int in [0, 1]:
			for vow: int in [0, 5]:
				for up: bool in [false, true]:
					check_case(aspect, vow, up, "available", old_stream, new_stream)
		for context: String in ["no_energy", "shuffle", "blocked", "already_lethal", "source_fatal"]:
			check_case(1, 5, true, context, old_stream, new_stream)
	output.store_line(JSON.stringify({"kind":"terminal","cases":case_count,
		"commands":command_count,"failures":failures}))
	output.close()
	old_stream.close()
	new_stream.close()
	quit(0 if failures == 0 else 3)
