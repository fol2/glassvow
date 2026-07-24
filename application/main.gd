extends Control
## Composition root (SKILL §2): owns the single GlassvowGame and routes
## screens. M5a drives the trace encounter ladder as a playable loop; the
## world map replaces the ladder at M6, and reward *claiming* (card pick,
## potion slot) lands with the M6 RewardScreen — here gold auto-banks and
## the rest is displayed.

const ENCOUNTERS: Array = [
	{"enemies": ["sporeling", "sporeling"], "kind": "normal", "label": "Sporeling pair"},
	{"enemies": ["duskfang"], "kind": "normal", "label": "Duskfang"},
	{"enemies": ["waylayer"], "kind": "normal", "label": "Waylayer"},
	{"enemies": ["gravewarden"], "kind": "elite", "label": "Gravewarden (elite)"},
]

var content: ContentDB
var game: GlassvowGame
var _screen: CombatScreen = null
var _encounter_i: int = 0
var _run_over: bool = false
var _forced_seed: int = -1  # --seed=N: reproducible shots for layout diffing


func _ready() -> void:
	print("glassvow boot " + str(Engine.get_version_info()["string"]))
	content = ContentDB.load_slice()
	var fails: Array[String] = []
	content.validate(fails)
	for msg: String in fails:
		push_error(msg)
	# Screenshot-loop hook for agent iteration without the editor MCP:
	# godot --path . -- --shot=/tmp/combat.png [--seed=N]
	var shot_path: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			shot_path = arg.trim_prefix("--shot=")
		elif arg.begins_with("--seed="):
			_forced_seed = int(arg.trim_prefix("--seed="))
	_new_run()
	if shot_path != "":
		_capture_and_quit(shot_path)


func _capture_and_quit(path: String) -> void:
	for _i: int in range(30):  # let layout + first paint settle
		await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(path)
	print("shot saved: " + path)
	get_tree().quit(0)


func _new_run() -> void:
	var run_seed: int = _forced_seed if _forced_seed >= 0 else randi() & 0x7FFFFFFF
	game = GlassvowGame.new(content, RunState.new_run(content, run_seed))
	_encounter_i = 0
	_run_over = false
	_start_encounter()


func _start_encounter() -> void:
	if _screen != null:
		_screen.queue_free()
	_screen = CombatScreen.new(game)
	_screen.combat_over.connect(_on_combat_over)
	_screen.result_continue.connect(_on_result_continue)
	add_child(_screen)
	var enc: Dictionary = ENCOUNTERS[_encounter_i]
	var enemies: Array = enc["enemies"]
	var label: String = "%s  ·  %d / %d" % [str(enc["label"]), _encounter_i + 1, ENCOUNTERS.size()]
	_screen.start_encounter(enemies, str(enc["kind"]), label)


func _on_combat_over(result: String) -> void:
	if result == "win":
		var enc: Dictionary = ENCOUNTERS[_encounter_i]
		var rewards: Dictionary = game.gen_combat_rewards(str(enc["kind"]), game.cb.affix)
		var gold: int = rewards["gold"]
		game.run.player.gold += gold
		var lines: Array[String] = ["Gold +%d" % gold]
		var cards: Array = rewards["cards"]
		if not cards.is_empty():
			var card_names: Array[String] = []
			for id_v: Variant in cards:
				var card_def: Dictionary = content.cards.get(str(id_v), {})
				card_names.append(str(card_def.get("name", str(id_v))))
			lines.append("Cards offered: %s" % ", ".join(card_names))
		if rewards["potion"] != null:
			var potion_def: Dictionary = content.potions.get(str(rewards["potion"]), {})
			lines.append("Potion: %s" % str(potion_def.get("name", str(rewards["potion"]))))
		if rewards["relic"] != null:
			var relic_def: Dictionary = content.relics.get(str(rewards["relic"]), {})
			lines.append("Relic: %s" % str(relic_def.get("name", str(rewards["relic"]))))
		lines.append("(claiming lands with the M6 reward screen)")
		var last: bool = _encounter_i + 1 >= ENCOUNTERS.size()
		if last:
			_run_over = true
			_screen.show_result("Slice cleared", "\n".join(lines), "New Run")
		else:
			_screen.show_result("Victory", "\n".join(lines), "Continue")
	else:
		_run_over = true
		_screen.show_result("Defeat", "The glass goes dark.", "New Run")


func _on_result_continue() -> void:
	if _run_over:
		_new_run()
	else:
		_encounter_i += 1
		_start_encounter()
