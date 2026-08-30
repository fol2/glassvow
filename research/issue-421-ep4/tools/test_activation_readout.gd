extends SceneTree
## Zero-row synthetic check for the #421 EP4 observation-only readout.

const Readout: GDScript = preload("res://research/issue-421-ep4/tools/activation_readout.gd")


func _initialize() -> void:
	var content_path: String = ContentDB.FULL_PATH
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--content="):
			content_path = arg.substr(arg.find("=") + 1)
		else:
			push_error("test_activation_readout: unknown option %s" % arg)
			quit(1)
			return
	var content: ContentDB = ContentDB.load_from(content_path, false)
	if content == null:
		push_error("test_activation_readout: content did not load")
		quit(1)
		return
	var events: Array = [
		{"t": "turn"},
		{"t": "play", "id": "preparation"}, {"t": "draw", "id": "strike"},
		{"t": "play", "id": "phantomBlades", "targetIdx": 0},
		{"t": "play", "id": "mirrorEdge", "targetIdx": 0},
		{"t": "blockGain", "who": "player", "n": 11, "total": 11},
		{"t": "play", "id": "fortify"},
		{"t": "blockGain", "who": "player", "n": 11, "total": 22},
		{"t": "play", "id": "venomStrike", "targetIdx": 0},
		{"t": "status", "who": 0, "id": "poison", "n": 4},
		{"t": "play", "id": "catalyst", "targetIdx": 0},
		{"t": "status", "who": 0, "id": "poison", "n": 8},
		{"t": "play", "id": "strike", "targetIdx": 0},
		{"t": "shatter", "idx": 0},
	]
	var got: Dictionary = Readout.observe(events, content)
	var expected: Dictionary = {
		"allShatters": 1,
		"ashPoisonCatalystActivations": 1,
		"ashPoisonCatalystFromVenomStrike": 1,
		"directShatterActivations": 1,
		"enemySmolderApplications": 2,
		"handSizePayoffActivations": 1,
		"handSizePayoffFromPreparation": 1,
		"wardMirrorEdgeActivations": 1,
		"wardMirrorEdgeFromMirrorEdge": 1,
	}
	if got != expected:
		push_error("test_activation_readout: expected %s, got %s" % [expected, got])
		quit(1)
		return
	var reset: Dictionary = Readout.observe([
		{"t": "turn"}, {"t": "play", "id": "surge"}, {"t": "draw", "id": "strike"},
		{"t": "endTurn"}, {"t": "turn"},
		{"t": "play", "id": "phantomBlades", "targetIdx": 0},
		{"t": "play", "id": "brace"},
		{"t": "blockGain", "who": "player", "n": 8, "total": 8},
		{"t": "endTurn"}, {"t": "turn"}, {"t": "play", "id": "fortify"},
		{"t": "blockGain", "who": "player", "n": 8, "total": 16},
	], content)
	if reset.has("handSizePayoffActivations") or reset.has("wardMirrorEdgeActivations"):
		push_error("test_activation_readout: turn boundary leaked activation: %s" % reset)
		quit(1)
		return
	print("PASS (2 EP4 readout checks)")
	quit(0)
