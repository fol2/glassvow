class_name Main
extends Control
## Composition root (SKILL §2): owns the single GlassvowGame and routes
## screens. M6 replaces the hard-coded encounter ladder with the world map —
## the run now walks the pilgrimage strip (docs/map-concept-brief.md §4) and
## enters combat from a waystone. Reward *claiming* (card pick, potion slot)
## still lands with a later RewardScreen; here gold auto-banks and the rest is
## displayed.

## Rest heals 30% of max HP — the frozen web law (engine.js restHealFrac:
## min(0.3, omen, vow), and a fresh core-only profile carries neither
## modifier). Applied in the application layer like reward gold: no domain
## command exists for out-of-combat healing yet, and the slice does not need
## one. ponytail: move this into domain rules when rest grows a real screen
## (heal / upgrade choice) or when omens and vows land.
const REST_HEAL_FRAC: float = 0.3

var content: ContentDB
var game: GlassvowGame
var _map: WorldMap
var _screen: CombatScreen = null
var _map_screen: WorldMapScreen = null
var _run_over: bool = false
var _forced_seed: int = -1  # --seed=N: reproducible shots for layout diffing


static func rest_heal_amount(max_hp: int) -> int:
	return int(roundf(float(max_hp) * REST_HEAL_FRAC))


func _ready() -> void:
	print("glassvow boot " + str(Engine.get_version_info()["string"]))
	content = ContentDB.load_slice()
	var fails: Array[String] = []
	content.validate(fails)
	for msg: String in fails:
		push_error(msg)
	# Screenshot-loop hook for agent iteration without the editor MCP:
	# godot --path . -- --shot=/tmp/map.png [--seed=N] [--enter=0]
	# godot --path . -- --cards[=id,id] --shot=/tmp/cards.png   (card designer)
	# godot --path . -- --cards=bastion --surfaces[=gilt,holofoil]  (materials)
	var shot_path: String = ""
	var enter_node: int = -1
	var cards_lab: bool = false
	var cards_only: PackedStringArray = PackedStringArray()
	var cards_zoom: float = 1.0
	var surfaces: PackedStringArray = PackedStringArray()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			shot_path = arg.trim_prefix("--shot=")
		elif arg.begins_with("--seed="):
			_forced_seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--enter="):
			enter_node = int(arg.trim_prefix("--enter="))
		elif arg == "--cards":
			cards_lab = true
		elif arg.begins_with("--cards="):
			cards_lab = true
			cards_only = arg.trim_prefix("--cards=").split(",", false)
		elif arg.begins_with("--zoom="):
			cards_zoom = float(arg.trim_prefix("--zoom="))
		elif arg == "--surfaces":
			cards_lab = true
			surfaces = PackedStringArray(CardSurface.RECIPES.keys())
		elif arg.begins_with("--surfaces="):
			cards_lab = true
			surfaces = arg.trim_prefix("--surfaces=").split(",", false)
	if cards_lab:
		# The lab is a contact sheet, not a run — no game state is built.
		add_child(CardLab.new(content, cards_only, cards_zoom, surfaces))
		if shot_path != "":
			_capture_and_quit(shot_path)
		return
	_new_run()
	if enter_node >= 0 and _map_screen != null:
		_map_screen.instant = true  # skip the travel tween, land on the fight
		_map_screen.choose(enter_node)
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
	_map = WorldMap.slice()
	_run_over = false
	_show_map()


# ---------------------------------------------------------------- map

func _show_map() -> void:
	if _screen != null:
		_screen.queue_free()
		_screen = null
	if _map_screen != null:
		_map_screen.queue_free()
	_map_screen = WorldMapScreen.new(_map, content)
	_map_screen.node_chosen.connect(_on_node_chosen)
	add_child(_map_screen)
	_map_screen.refresh(game.run)


func _on_node_chosen(i: int) -> void:
	var n: MapNode = _map.nodes[i]
	if n.type == "rest":
		var healed: int = mini(game.run.player.max_hp - game.run.player.hp,
			rest_heal_amount(game.run.player.max_hp))
		game.run.player.hp += maxi(0, healed)
		_map.clear_current()
		_show_map()
		return
	_start_encounter(n)


# ---------------------------------------------------------------- combat

func _start_encounter(n: MapNode) -> void:
	if _map_screen != null:
		_map_screen.queue_free()
		_map_screen = null
	_screen = CombatScreen.new(game)
	_screen.combat_over.connect(_on_combat_over)
	_screen.result_continue.connect(_on_result_continue)
	add_child(_screen)
	var enemies: Array[String] = n.enemies
	var label: String = "%s  ·  waystone %d / %d" % [
		n.type.capitalize(), _map.at + 1, _map.nodes.size()]
	_screen.start_encounter(enemies, n.combat_kind(), label)


func _on_combat_over(result: String) -> void:
	if result != "win":
		_run_over = true
		_screen.show_result("Defeat", "The glass goes dark.", "New Run")
		return
	var node: MapNode = _map.current()
	var rewards: Dictionary = game.gen_combat_rewards(node.combat_kind(), game.cb.affix)
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
	lines.append("(claiming lands with the reward screen)")
	# ponytail: the strip is linear, so the last index ends the run. The
	# generator milestone replaces this with "no reachable node remains".
	if _map.at >= _map.nodes.size() - 1:
		_run_over = true
		_screen.show_result("Slice cleared", "\n".join(lines), "New Run")
	else:
		_screen.show_result("Victory", "\n".join(lines), "Continue")


func _on_result_continue() -> void:
	if _run_over:
		_new_run()
		return
	_map.clear_current()
	_show_map()
