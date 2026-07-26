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
	# godot --path . -- --studio[=bastion] [--zoom=3]   (material bench)
	# godot --path . -- --enemies|--chips|--hud|--reward [--shot=...]  (labs)
	# godot --path . -- --fight=id[,id] [--kind=normal|elite|boss]   (battlefield)
	# godot --path . -- --vp=1280x720            (see the scaling, nothing reflows)
	var shot_path: String = ""
	var enter_node: int = -1
	var lab_flag: String = ""
	var fight: PackedStringArray = PackedStringArray()
	var fight_kind: String = "normal"
	var cards_lab: bool = false
	var cards_only: PackedStringArray = PackedStringArray()
	var cards_zoom: float = 1.0
	var surfaces: PackedStringArray = PackedStringArray()
	var studio: bool = false
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
		elif arg == "--studio":
			studio = true
		elif arg.begins_with("--studio="):
			studio = true
			cards_only = arg.trim_prefix("--studio=").split(",", false)
		elif arg.begins_with("--fight="):
			fight = arg.trim_prefix("--fight=").split(",", false)
		elif arg.begins_with("--kind="):
			fight_kind = arg.trim_prefix("--kind=")
		elif arg.begins_with("--vp="):
			# Resize the OS window to see how the screen holds up. Note what this
			# does NOT do: the stretch mode is `canvas_items` with `aspect=keep`
			# (project.godot), so the VIEWPORT stays 1180x820 and the whole
			# composition is scaled and letterboxed into whatever size is asked
			# for. Nothing reflows. That is the honest state of viewport support
			# and this flag is the fastest way to see it for yourself.
			var wh: PackedStringArray = arg.trim_prefix("--vp=").split("x", false)
			if wh.size() == 2:
				DisplayServer.window_set_size(Vector2i(int(wh[0]), int(wh[1])))
			else:
				push_warning("--vp wants WIDTHxHEIGHT, e.g. --vp=1280x720")
		elif arg in ["--enemies", "--chips", "--hud", "--reward"]:
			lab_flag = arg
	if studio:
		# The material bench: one card, four layer pickers, no game state. It
		# takes --zoom for the PANEL's scale only; the card has its own size
		# picker, because scaling the window there costs stage room.
		add_child(CardStudio.new(content, cards_only, cards_zoom))
		if shot_path != "":
			_capture_and_quit(shot_path)
		return
	if cards_lab:
		# The lab is a contact sheet, not a run — no game state is built.
		add_child(CardLab.new(content, cards_only, cards_zoom, surfaces))
		if shot_path != "":
			_capture_and_quit(shot_path)
		return
	# The other four labs, same deal: a screen over content, no run behind it.
	# Built after the loop, not inside it, so two flags leak no orphan Control.
	# Each lab owns any further args it wants — read OS.get_cmdline_user_args()
	# there rather than growing this loop, so the four sessions never collide here.
	var lab: Control = null
	match lab_flag:
		"--enemies": lab = EnemyLab.new(content)
		"--chips": lab = ChipLab.new(content)
		"--hud": lab = HudLab.new(content)
		"--reward": lab = RewardLab.new(content)
	if lab != null:
		add_child(lab)
		if shot_path != "":
			_capture_and_quit(shot_path)
		return
	_new_run()
	if not fight.is_empty():
		_start_fight(fight, fight_kind)
	elif enter_node >= 0 and _map_screen != null:
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


## The battlefield bench: a REAL fight, not a mock — the same GlassvowGame, the
## same CombatScreen and the same input paths the map route uses. It only skips
## choosing a waystone, so any encounter can be stood up in one command:
##
##   godot --path . -- --fight=sporeling,sporeling
##   godot --path . -- --fight=gravewarden --kind=elite --seed=7
##   godot --path . -- --fight=duskfang --vp=1280x720
##
## Winning drops back onto the map, which is the honest continuation: the run
## behind the bench is a real run.
func _start_fight(ids: PackedStringArray, kind: String) -> void:
	var known: Array[String] = []
	for id: String in ids:
		if content.enemies.has(id):
			known.append(id)
		else:
			# Named, not skipped silently: a typo would otherwise open an empty
			# battlefield and look like the screen was broken.
			push_error("--fight: no enemy '%s' in the slice. Known: %s"
				% [id, ", ".join(content.enemies.keys())])
	if known.is_empty():
		return
	if _map_screen != null:
		_map_screen.queue_free()
		_map_screen = null
	_screen = CombatScreen.new(game)
	_screen.combat_over.connect(_on_combat_over)
	_screen.result_continue.connect(_on_result_continue)
	add_child(_screen)
	_screen.start_encounter(known, kind, "Bench  ·  %s" % kind.capitalize())


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
