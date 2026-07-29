class_name Main
extends Control
## Composition root (SKILL §2): owns the single GlassvowGame and routes
## title, durable run checkpoints, the benchmark map, combat and terminal
## screens. Domain mutation remains behind GlassvowGame and its rules.

## Rest heals 30% of max HP — the frozen web law (engine.js restHealFrac:
## min(0.3, omen, vow), and a fresh core-only profile carries neither
## modifier). `rest_heal_amount` remains as the slice-fixture compatibility
## helper; live runs ask RewardRules for the complete law.
const REST_HEAL_FRAC: float = 0.3
const RARITY_RANK: Dictionary = {
	"starter": 0, "special": 0, "common": 1, "uncommon": 2, "rare": 3, "boss": 4,
}
const ChoiceScreenType: GDScript = preload("res://presentation/run/choice_screen.gd")

var content: ContentDB
var game: GlassvowGame
var _map: WorldMap
var _screen: CombatScreen = null
var _map_screen: WorldMapScreen = null
var _choice_screen: Control = null
var _reward_screen: RewardScreen = null
var _vigil: VigilState
var _embark_aspect: int = 0
var _embark_vow: int = 0
var _run_over: bool = false
var _bench_fight: bool = false
var _forced_seed: int = -1  # --seed=N: reproducible shots for layout diffing
## The virtual stage this window is composed against. A 1180x820 window resolves
## to `pad-landscape` at zero flex, so the default boot is identical to the port
## before shapes existed — which is the gate `tests/test_stage_shape.gd` holds.
var _shape: StringName = StageShape.IDENTITY
## --shape=<name>: the port of the benchmark's `?shape=` (`src/stage.js:33`).
## Not a debug nicety — it is how every parity measurement is taken, because a
## bare wide window silently resolves to `desktop-landscape` and reads a
## different layout table entirely (docs/battlefield-parity.md).
var _forced_shape: StringName = &""
## --act=N: which act's scenery the fight is dressed in. The domain does not model
## acts yet, so a fight built from `--fight=` is act 0 and there was no way to see
## the other two outside the layout bench — while the book authors all three for
## every shape and `sky_field.gd` inlines act 1's theme. Clamped to the three the
## benchmark authors (`src/dev/bf-editor.js:169`).
var _forced_act: int = -1
## --settle=SECONDS: extra wait before a `--shot=` capture, so a composition is
## photographed at rest rather than mid-entrance.
var _settle: float = 0.0


static func rest_heal_amount(max_hp: int) -> int:
	return int(roundf(float(max_hp) * REST_HEAL_FRAC))


func _ready() -> void:
	print("glassvow boot " + str(Engine.get_version_info()["string"]))
	content = ContentDB.load_full()
	_vigil = SaveService.load_vigil()
	var fails: Array[String] = []
	content.validate(fails)
	for msg: String in fails:
		push_error(msg)
	# Screenshot-loop hook for agent iteration without the editor MCP. A run that
	# carries --shot= captures and then quits, and goes through tools/shot.sh;
	# without it the run is a viewer to work in, so it launches godot directly.
	# Neither may add --headless — a headless run has no viewport texture, so the
	# capture hangs rather than failing. For a LOOP of captures use tools/live.sh
	# instead: it boots one instance and hot-reloads it, so only the first shot of
	# a session takes the desktop off you.
	# tools/shot.sh --shot=/tmp/map.png [--seed=N] [--enter=0]
	# tools/shot.sh --cards[=id,id] --shot=/tmp/cards.png        (card designer)
	# tools/shot.sh --enemies|--chips|--hud|--reward --shot=...  (labs)
	# godot --path . -- --cards=bastion --surfaces[=gilt,holofoil]  (materials)
	# godot --path . -- --studio[=bastion] [--zoom=3]   (material bench)
	# godot --path . -- --fight=id[,id] [--kind=normal|elite|boss]   (battlefield)
	# godot --path . -- --vp=1280x720            (watch the shape re-pick live)
	# godot --path . -- --shape=phone-portrait   (force one; ?shape= ported)
	# godot --path . -- --act=2                  (dress the fight in act 2's scenery)
	# tools/shot.sh --resume --shot=...          (exercise the durable router)
	# tools/shot.sh --fight=… --settle=3 --shot=…  (photograph it at rest)
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
	var resume_run: bool = false
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
		elif arg.begins_with("--shape="):
			_forced_shape = StringName(arg.trim_prefix("--shape="))
		elif arg.begins_with("--settle="):
			_settle = maxf(0.0, float(arg.trim_prefix("--settle=")))
		elif arg.begins_with("--act="):
			_forced_act = clampi(int(arg.trim_prefix("--act=")), 0, LayoutBook.ACTS - 1)
		elif arg.begins_with("--vp="):
			# Resize the OS window to see how the screen holds up, and to watch
			# `_apply_shape` re-pick as you cross an aspect boundary. It DOES
			# reflow now: the stretch mode is still `canvas_items` with
			# `aspect=keep` (project.godot), but the stage size follows the window
			# and the layout book supplies a composition per shape, so crossing a
			# boundary re-lays the fight out rather than re-proportioning one
			# frozen picture. `--shape=` pins the choice; this varies the window
			# the choice is made from, which is the only way to see the flex.
			var wh: PackedStringArray = arg.trim_prefix("--vp=").split("x", false)
			if wh.size() == 2:
				DisplayServer.window_set_size(Vector2i(int(wh[0]), int(wh[1])))
			else:
				push_warning("--vp wants WIDTHxHEIGHT, e.g. --vp=1280x720")
		elif arg == "--resume":
			resume_run = true
		elif arg in ["--enemies", "--chips", "--hud", "--reward", "--layout"]:
			lab_flag = arg
	# `--shape=` means two different things to a screen and to the layout bench.
	# To a screen it is "run the window at this stage". To the bench it is "author
	# THIS shape", and the bench already hosts its own stage at that shape's
	# reference size — so honouring it here as well would squeeze the window down
	# to 437x844 and leave the bench's own readout unreadable beside it.
	if lab_flag == "--layout":
		_forced_shape = &""
	# The stage is chosen before anything is built, so every screen below is
	# constructed against the size it will actually be laid out in. Re-picked on
	# every window change after that: an iPadOS 26 window has no fixed aspect
	# (UIRequiresFullScreen is deprecated) and a desktop window never did.
	_apply_shape()
	var window: Window = get_window()
	if window != null:
		window.size_changed.connect(_apply_shape)
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
		# The layout bench builds its OWN fight, at its own selected shape, so it
		# is a lab rather than a route: `--shape=` here would pick the window's
		# stage, and what that bench needs to vary is the stage it DRAWS.
		"--layout": lab = LayoutLab.new(content)
	if lab != null:
		add_child(lab)
		if shot_path != "":
			_capture_and_quit(shot_path)
		return
	if resume_run:
		_continue_run(SaveService.load_run(content))
	elif not fight.is_empty():
		_new_run()
		_start_fight(fight, fight_kind)
	elif enter_node >= 0:
		_new_run()
		if _map_screen == null:
			return
		_map_screen.instant = true  # skip the travel tween, land on the fight
		_map_screen.choose(enter_node)
	else:
		_show_title()
	if shot_path != "":
		_capture_and_quit(shot_path)


# ---------------------------------------------------------------- stage shape

## Pick the virtual stage this window gets, and hand its size to the engine.
##
## `content_scale_aspect` stays `keep` and `project.godot` is untouched:
## `StageShape` expresses the flex as a SIZE, so inside the cap the size already
## matches the window's aspect and `keep` finds nothing to letterbox. Past the
## cap the size stops and `keep` bars the remainder. One mechanism, no mode
## switching, and the default 1180x820 boot resolves to exactly 1180x820.
##
## Nothing here resizes the WINDOW. `docs/dev-tools.md` rule 6 keeps native
## window sizing off the Web export because the browser owns its canvas, and
## content scaling is the half of this that works in both places.
func _apply_shape() -> void:
	var window: Window = get_window()
	if window == null:
		return
	var px: Vector2i = window.size
	if px.x <= 0 or px.y <= 0:
		return
	var device: StringName = StageShape.class_for(OS.get_name(), _screen_diagonal())
	var shape: StringName = StageShape.pick(px, device, _forced_shape)
	var size: Vector2i = StageShape.stage_size(shape, px)
	if shape == _shape and window.content_scale_size == size:
		return
	_shape = shape
	window.content_scale_size = size
	print("stage %s %dx%d  window %dx%d  flex %+.1f%%" % [shape, size.x, size.y,
		px.x, px.y, StageShape.flex_of(shape, px) * 100.0])


## The physical screen diagonal in inches, or 0 when it cannot be measured —
## which is exactly what `StageShape.class_for` wants for "unknowable". Only the
## touch platforms ever consult it; a named desktop OS decides before this runs.
func _screen_diagonal() -> float:
	var dpi: int = DisplayServer.screen_get_dpi()
	if dpi <= 0:
		return 0.0
	return Vector2(DisplayServer.screen_get_size()).length() / float(dpi)


## Wait, then photograph, then quit.
##
## Thirty frames is enough for layout and a first paint, and NOT enough for a
## fight: the opening hand is still in the air at half a second, so a combat
## capture caught the fan mid-deal at whatever position the wall clock had
## reached. Two runs of the same build differed across 2.4% of the frame, all of
## it in the hand — which makes a before/after comparison of a layout change
## unreadable. `--settle=` buys the extra time when the shot is of a settled
## composition rather than of the entrance.
func _capture_and_quit(path: String) -> void:
	for _i: int in range(30):  # let layout + first paint settle
		await get_tree().process_frame
	if _settle > 0.0:
		await get_tree().create_timer(_settle).timeout
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(path)
	print("shot saved: " + path)
	get_tree().quit(0)


func _clear_route() -> void:
	for screen: Control in [_screen, _map_screen, _choice_screen, _reward_screen]:
		if screen != null:
			screen.queue_free()
	_screen = null
	_map_screen = null
	_choice_screen = null
	_reward_screen = null


func _show_choice(title: String, body: String, choices: Array[Dictionary], handler: Callable) -> void:
	_clear_route()
	_choice_screen = ChoiceScreenType.new(title, body, choices)
	_choice_screen.connect("chosen", handler)
	add_child(_choice_screen)


func _show_title() -> void:
	var saved: RunState = SaveService.load_run(content)
	_show_choice("GLASSVOW", "Carry the lantern through three nights.", [
		{"id": "continue", "label": "Continue", "disabled": saved == null},
		{"id": "begin", "label": "Begin"},
		{"id": "vigil", "label": "Vigil", "quiet": true},
		{"id": "help", "label": "Help", "quiet": true},
		{"id": "settings", "label": "Settings", "quiet": true},
	], _on_title_choice.bind(saved))


func _on_title_choice(id: String, saved: RunState) -> void:
	match id:
		"continue": _continue_run(saved)
		"begin": _show_embark()
		"vigil": _show_vigil()
		"help": _show_help()
		"settings": _show_settings()


func _show_embark() -> void:
	var choices: Array[Dictionary] = [
		{"id": "0", "label": str(content.aspects[0].get("name", "The Duskblade"))},
	]
	if _vigil.unlocks.has("aspect2") and content.aspects.size() > 1:
		choices.append({"id": "1", "label": str(content.aspects[1].get("name", "The Ashwarden"))})
	choices.append({"id": "back", "label": "Back", "quiet": true})
	_show_choice("EMBARK", "Choose the glass that will carry the light.", choices, _on_aspect_choice)


func _on_aspect_choice(id: String) -> void:
	if id == "back":
		_show_title()
		return
	_embark_aspect = int(id)
	_show_vow_choice()


func _show_vow_choice() -> void:
	var choices: Array[Dictionary] = [{"id": "0", "label": "No Vow"}]
	for level: int in range(1, mini(_vigil.vow_unlocked, content.vows.size()) + 1):
		choices.append({
			"id": str(level),
			"label": "Vow %d · %s" % [level, str(content.vows[level - 1].get("name", ""))],
		})
	choices.append({"id": "back", "label": "Back", "quiet": true})
	_show_choice("THE VOW", "Each vow keeps every earlier promise.", choices, _on_vow_choice)


func _on_vow_choice(id: String) -> void:
	if id == "back":
		_show_embark()
		return
	_embark_vow = int(id)
	if SaveService.load_run(content) == null:
		_new_run({"aspect": _embark_aspect, "vow": _embark_vow})
	else:
		_show_choice("BEGIN ANEW",
			"The current pilgrimage will be recorded as abandoned before a new one begins.",
			[{"id": "begin", "label": "Begin Anew"},
				{"id": "back", "label": "Keep Climbing", "quiet": true}],
			_on_begin_anew)


func _on_begin_anew(id: String) -> void:
	if id == "back":
		_show_title()
		return
	var saved: RunState = SaveService.load_run(content)
	if saved == null:
		_new_run({"aspect": _embark_aspect, "vow": _embark_vow})
		return
	game = GlassvowGame.new(content, saved)
	game.run.pending_run_end = {"outcome": "abandon", "bequestAnswered": true}
	if not _vigil.commit_run(game.run, "abandon", content) or not SaveService.store_vigil(_vigil):
		_show_save_error("The current pilgrimage could not be closed.")
		return
	if not SaveService.clear_run(game.run.run_id):
		_show_save_error("The current pilgrimage could not be cleared.")
		return
	_new_run({"aspect": _embark_aspect, "vow": _embark_vow})


func _show_vigil() -> void:
	var deeds: Dictionary = _vigil.deeds
	var body: String = "Runs %d   ·   Wins %d   ·   Shards %d / 6\n\n%s" % [
		_vigil.runs_played, int(float(str(deeds.get("wins", 0)))), _vigil.shards.size(),
		"The Rose Window is dark." if _vigil.shards.is_empty()
			else "Lit panes: %s" % ", ".join(_vigil.shards),
	]
	_show_choice("THE VIGIL", body, [{"id": "back", "label": "Back"}],
		func(_id: String) -> void: _show_title())


func _show_help() -> void:
	_show_choice("HOW TO CARRY THE LIGHT",
		"Choose a reachable waystone. In combat, play cards, kindle one card each turn, "
		+ "and spend Embers on your Lantern Art. Break every enemy pane before your own light fails.",
		[{"id": "back", "label": "Back"}], func(_id: String) -> void: _show_title())


func _show_settings() -> void:
	_show_choice("SETTINGS", "Audio follows the system output. Window size and input may be changed at any time.",
		[{"id": "back", "label": "Back"}], func(_id: String) -> void: _show_title())


func _show_save_error(message: String) -> void:
	_show_choice("THE LIGHT WOULD NOT HOLD", message + "\nNo progress was discarded.",
		[{"id": "retry", "label": "Retry"}, {"id": "title", "label": "Title", "quiet": true}],
		_on_save_error_choice)


func _on_save_error_choice(id: String) -> void:
	if id == "retry" and game != null and SaveService.store(game.run):
		_route_run()
	else:
		_show_title()


func _new_run(profile: Dictionary = {}) -> void:
	var run_seed: int = _forced_seed if _forced_seed >= 0 else randi() & 0x7FFFFFFF
	var run_id: String = "run-%08x-%x" % [run_seed, int(Time.get_unix_time_from_system() * 1000.0)]
	var merged: Dictionary = {
		"aspect": profile.get("aspect", 0),
		"vow": profile.get("vow", 0),
		"reveals": _vigil.unlocks.filter(func(id: String) -> bool: return content.reveal_ids.has(id)),
		"unlocks": _vigil.unlocks,
		"monument": _vigil.last_fall,
		"quests": _vigil.quests,
		"shards": _vigil.shards,
		"lamplighter": _vigil.unlocks.has("lamplighter"),
	}
	game = GlassvowGame.new(content, RunState.new_run(content, run_seed, run_id, merged))
	game.quests.prepare_run(game.run)
	if _vigil.shards.size() >= 6:
		_map = WorldMap.act4_entrance()
	else:
		_map = WorldMap.benchmark(game.run)
		game.quests.decorate_map(game.run, _map)
	game.run.map = _map.to_dict()
	_run_over = false
	if SaveService.store(game.run):
		_route_run()
	else:
		_show_save_error("The pilgrimage could not be started.")


func _continue_run(saved: RunState) -> void:
	if saved == null:
		_show_title()
		return
	var restored: WorldMap = WorldMap.from_dict(saved.map)
	if restored == null:
		_show_save_error("The saved pilgrimage map is unreadable.")
		return
	game = GlassvowGame.new(content, saved)
	_map = restored
	_route_run()


func _route_run() -> void:
	if game == null:
		_show_title()
	elif game.run.pending_dawn != null:
		_show_dawn()
	elif game.run.pending_run_end != null:
		_show_run_end()
	elif game.run.pending_hollow != null:
		_show_hollow()
	elif game.run.pending_reward != null:
		_show_pending_reward()
	elif game.run.pending_combat != null:
		_resume_pending_combat()
	elif game.run.pending_hollow_route != null:
		_show_hollow_route()
	elif _has_pending_monument():
		_show_monument()
	elif _has_pending_boss_relic():
		_show_boss_relic()
	elif game.run.pending_lamplighter:
		_show_lamplighter()
	else:
		_show_map()


# ---------------------------------------------------------------- map

func _show_map() -> void:
	_clear_route()
	_map_screen = WorldMapScreen.new(_map, content)
	_map_screen.node_chosen.connect(_on_node_chosen)
	_map_screen.menu_requested.connect(_show_run_menu)
	add_child(_map_screen)
	_map_screen.refresh(game.run)


func _show_run_menu() -> void:
	_show_choice("PILGRIMAGE PAUSED", "The current checkpoint is safe.", [
		{"id": "continue", "label": "Continue"},
		{"id": "title", "label": "Save and Return to Title", "quiet": true},
		{"id": "abandon", "label": "Abandon Run", "quiet": true},
	], _on_run_menu_choice)


func _on_run_menu_choice(id: String) -> void:
	match id:
		"continue":
			_show_map()
		"title":
			_show_title()
		"abandon":
			game.run.pending_run_end = {"outcome": "abandon", "bequestAnswered": true}
			if SaveService.store(game.run):
				_show_run_end()
			else:
				_show_save_error("The abandonment could not be held.")


func _on_node_chosen(i: int) -> void:
	var n: MapNode = _map.nodes[i]
	var was_unlit: bool = n.unlit
	game.run.node_id = n.id
	game.run.floors_climbed = n.row + 1
	if was_unlit:
		var bounty: int = n.bounty * (2 if game.run.has_relic("thiefOfWicks") else 1)
		game.run.player.gold += bounty
		game.run.stats["goldEarned"] = int(float(str(
			game.run.stats.get("goldEarned", 0)))) + bounty
		game.run.stats["unlitVisited"] = int(float(str(
			game.run.stats.get("unlitVisited", 0)))) + 1
		n.unlit = false
		n.bounty = 0
	var hollow: bool = game.quests.stage_hollow_meeting(game.run, n, was_unlit)
	game.run.map = _map.to_dict()
	if not SaveService.store(game.run):
		_show_save_error("The chosen waystone could not be held.")
		return
	if hollow:
		_show_hollow()
		return
	match n.type:
		"monster", "elite", "boss": _prepare_encounter(n)
		"rest": _show_rest()
		"event": _show_event()
		"shop": _show_shop()
		"treasure": _show_treasure()
		"monument": _show_monument()
		"act4": _show_act4_entrance()


func _finish_node() -> void:
	game.run.pending_hollow_route = null
	_map.clear_current()
	game.run.map = _map.to_dict()
	for key: String in ["eventNode", "eventPending", "shopStock", "treasureClaim"]:
		game.run.quest_scratch.erase(key)
	if SaveService.store(game.run):
		_route_run()
	else:
		_show_save_error("The cleared waystone could not be held.")


func _show_rest() -> void:
	_show_choice("A QUIET HEARTH", "The fire offers one service before it fades.", [
		{"id": "heal", "label": "Mend %d%%" % int(game.rewards.rest_heal_fraction(game.run) * 100.0)},
		{"id": "upgrade", "label": "Temper a card"},
	], _on_rest_choice)


func _on_rest_choice(id: String) -> void:
	if id == "heal":
		var amount: int = int(roundf(float(game.run.player.max_hp)
			* game.rewards.rest_heal_fraction(game.run)))
		game.run.player.hp = mini(game.run.player.max_hp, game.run.player.hp + amount)
		_finish_node()
		return
	var choices: Array[Dictionary] = []
	for card: CardInst in game.run.player.deck:
		var definition: Dictionary = content.cards.get(String(card.id), {})
		if not card.up and definition.has("up"):
			choices.append({
				"id": str(card.uid),
				"label": str(definition.get("name", String(card.id))),
			})
	if choices.is_empty():
		_finish_node()
		return
	_show_choice("TEMPER A CARD", "Choose one pane to strengthen.", choices, _on_rest_upgrade)


func _on_rest_upgrade(uid_text: String) -> void:
	var uid: int = int(uid_text)
	for card: CardInst in game.run.player.deck:
		if card.uid == uid:
			card.up = true
			break
	_finish_node()


func _show_event() -> void:
	var event_id: String = str(game.run.quest_scratch.get("eventNode", ""))
	if event_id.is_empty():
		event_id = game.rewards.roll_event(game.run)
		game.run.quest_scratch["eventNode"] = event_id
		if not SaveService.store(game.run):
			_show_save_error("The event could not be held.")
			return
	var event: Dictionary = content.events[event_id]
	var choices: Array[Dictionary] = []
	var rows: Array = event.get("choices", [])
	for i: int in range(rows.size()):
		var row: Dictionary = rows[i]
		choices.append({
			"id": str(i),
			"label": str(row.get("label", "Leave")),
			"hint": str(row.get("sub", "")),
			"disabled": game.run.player.gold < int(float(str(row.get("needGold", 0)))),
		})
	_show_choice(str(event.get("name", "A Strange Place")), str(event.get("text", "")),
		choices, _on_event_choice.bind(event_id))


func _on_event_choice(choice_text: String, event_id: String) -> void:
	var event: Dictionary = content.events[event_id]
	var choices: Array = event.get("choices", [])
	var choice: Dictionary = choices[int(choice_text)]
	var ops: Array = choice.get("ops", [])
	var pending: Dictionary = game.rewards.apply_event_ops(game.run, ops)
	if str(pending.get("kind", "")).is_empty():
		_finish_node()
		return
	game.run.quest_scratch["eventPending"] = pending
	if SaveService.store(game.run):
		_show_event_pick(pending)
	else:
		_show_save_error("The event choice could not be held.")


func _show_event_pick(pending: Dictionary) -> void:
	var kind: String = str(pending["kind"])
	var choices: Array[Dictionary] = []
	if kind == "card":
		for id_v: Variant in pending.get("cards", []):
			var id: String = str(id_v)
			choices.append({"id": id, "label": str(content.cards[id].get("name", id))})
	else:
		for card: CardInst in game.run.player.deck:
			var definition: Dictionary = content.cards.get(String(card.id), {})
			if kind != "upgrade" or (not card.up and definition.has("up")):
				choices.append({"id": str(card.uid), "label": str(definition.get("name", String(card.id)))})
	if choices.is_empty():
		_finish_node()
		return
	_show_choice("CHOOSE A CARD", "The choice is part of the price.", choices,
		_on_event_pick.bind(kind))


func _on_event_pick(id: String, kind: String) -> void:
	if kind == "card":
		game.run.player.deck.append(CardInst.new(game.run.next_uid(), StringName(id), false))
	else:
		var picked: CardInst = null
		for card: CardInst in game.run.player.deck:
			if card.uid == int(id):
				picked = card
				break
		if picked != null:
			match kind:
				"remove": game.run.player.deck.erase(picked)
				"upgrade": picked.up = true
				"duplicate":
					game.run.player.deck.append(CardInst.new(
						game.run.next_uid(), picked.id, picked.up))
	_finish_node()


func _show_treasure() -> void:
	var claim_v: Variant = game.run.quest_scratch.get("treasureClaim")
	var claim: Dictionary
	if typeof(claim_v) == TYPE_DICTIONARY:
		claim = claim_v
	else:
		claim = game.rewards.claim_treasure(game.run)
		game.run.quest_scratch["treasureClaim"] = claim
		if not SaveService.store(game.run):
			_show_save_error("The treasure could not be held.")
			return
	var message: String = "The empty coffer yields 60 gold."
	if claim.get("relic") != null:
		var id: String = str(claim["relic"])
		message = "You recover %s." % str(content.relics[id].get("name", id))
	_show_choice("A LEADED COFFER", message, [{"id": "continue", "label": "Continue"}],
		func(_id: String) -> void: _finish_node())


func _show_act4_entrance() -> void:
	_show_choice("THE ROSE WINDOW OPENS",
		"Six Emberglass panes answer the lantern. A fourth road is visible beyond the crown.",
		[{"id": "enter", "label": "Touch the Act IV threshold"},
			{"id": "title", "label": "Return to Title", "quiet": true}],
		func(id: String) -> void:
			if id == "enter":
				_show_choice("ACT IV", "The threshold answers. Act IV gameplay is beyond this programme.",
					[{"id": "title", "label": "Return to Title"}],
					func(_back: String) -> void: _show_title())
			else:
				_show_title())


func _show_shop() -> void:
	var stock_v: Variant = game.run.quest_scratch.get("shopStock")
	var stock: Dictionary
	if typeof(stock_v) == TYPE_DICTIONARY:
		stock = stock_v
	else:
		stock = game.rewards.gen_shop(game.run)
		game.run.quest_scratch["shopStock"] = stock
		if not SaveService.store(game.run):
			_show_save_error("The merchant's stock could not be held.")
			return
	var choices: Array[Dictionary] = []
	for category: String in ["cards", "relics", "potions"]:
		var rows: Array = stock[category]
		for i: int in range(rows.size()):
			var row: Dictionary = rows[i]
			if row.get("sold", false):
				continue
			var id: String = str(row["id"])
			var registry: Dictionary = content.cards if category == "cards" \
				else (content.relics if category == "relics" else content.potions)
			choices.append({
				"id": "%s:%d" % [category, i],
				"label": "%s · %d gold" % [
					str(registry[id].get("name", id)), int(float(str(row["price"])))],
				"disabled": game.run.player.gold < int(float(str(row["price"]))) \
					or (category == "potions" and not game.run.player.potions.has("")),
			})
	var quest_item: Dictionary = game.quests.usurper_offer(game.run)
	if not quest_item.is_empty():
		choices.append({
			"id": "quest:flamelessLantern",
			"label": "%s · %d gold" % [
				str(quest_item["name"]), int(float(str(quest_item["price"])))],
			"disabled": game.run.player.gold < int(float(str(quest_item["price"]))),
		})
	if not stock.get("removed", false):
		choices.append({
			"id": "remove",
			"label": "Remove a card · %d gold" % int(float(str(stock["removeCost"]))),
			"disabled": game.run.player.gold < int(float(str(stock["removeCost"]))),
		})
	choices.append({"id": "leave", "label": "Leave", "quiet": true})
	_show_choice("THE GLASS MERCHANT", "Gold %d" % game.run.player.gold, choices,
		_on_shop_choice)


func _on_shop_choice(id: String) -> void:
	if id == "leave":
		_finish_node()
		return
	if id == "quest:flamelessLantern":
		if game.quests.buy_usurper(game.run) and SaveService.store(game.run):
			_show_shop()
		else:
			_show_save_error("The empty lantern purchase could not be held.")
		return
	var stock: Dictionary = game.run.quest_scratch["shopStock"]
	if id == "remove":
		var choices: Array[Dictionary] = []
		for card: CardInst in game.run.player.deck:
			choices.append({"id": str(card.uid), "label": str(
				content.cards[String(card.id)].get("name", String(card.id)))})
		_show_choice("REMOVE A CARD", "The merchant keeps the broken pane.", choices,
			_on_shop_remove)
		return
	var parts: PackedStringArray = id.split(":")
	var category: String = parts[0]
	var rows: Array = stock[category]
	var row: Dictionary = rows[int(parts[1])]
	var price: int = int(float(str(row["price"])))
	if row.get("sold", false) or game.run.player.gold < price:
		_show_shop()
		return
	game.run.player.gold -= price
	var item_id: String = str(row["id"])
	match category:
		"cards":
			game.run.player.deck.append(CardInst.new(game.run.next_uid(), StringName(item_id), false))
		"relics":
			game.rewards.gain_relic(game.run, item_id)
		"potions":
			game.run.player.potions[game.run.player.potions.find("")] = item_id
	row["sold"] = true
	if SaveService.store(game.run):
		_show_shop()
	else:
		_show_save_error("The purchase could not be held.")


func _on_shop_remove(uid_text: String) -> void:
	var stock: Dictionary = game.run.quest_scratch["shopStock"]
	var cost: int = int(float(str(stock["removeCost"])))
	for card: CardInst in game.run.player.deck:
		if card.uid == int(uid_text):
			game.run.player.deck.erase(card)
			break
	game.run.player.gold -= cost
	stock["removed"] = true
	if SaveService.store(game.run):
		_show_shop()
	else:
		_show_save_error("The removed card could not be held.")


# ---------------------------------------------------------------- combat

func _prepare_encounter(n: MapNode) -> void:
	var enemies: Array[String] = n.enemies
	if enemies.is_empty():
		enemies = game.quests.encounter_override(game.run, n.type, n)
		if enemies.is_empty():
			enemies = game.rewards.roll_encounter(game.run, n.type, n.row, n)
	game.run.pending_combat = n.type
	game.run.pending_enemy_ids = enemies
	if not SaveService.store(game.run):
		_show_save_error("The encounter could not be frozen.")
		return
	_resume_pending_combat()


func _resume_pending_combat() -> void:
	if game.run.pending_quest_id == "ownShade" and _vigil.last_fall != null:
		_vigil.last_fall = null
		if not SaveService.store_vigil(_vigil):
			_show_save_error("The standing bequest could not be cleared.")
			return
	var enemies: Array[String] = []
	for id_v: Variant in game.run.pending_enemy_ids:
		enemies.append(str(id_v))
	_clear_route()
	_screen = CombatScreen.new(game, _shape,
		_forced_act if _forced_act >= 0 else game.run.act)
	_screen.combat_over.connect(_on_combat_over)
	_screen.result_continue.connect(_on_result_continue)
	add_child(_screen)
	var route_kind: String = str(game.run.pending_combat)
	var combat_kind: String = "normal" if route_kind == "monster" else route_kind
	_screen.start_encounter(enemies, combat_kind,
		"%s  ·  act %d" % [route_kind.capitalize(), game.run.act + 1])


## The battlefield bench: a REAL fight, not a mock — the same GlassvowGame, the
## same CombatScreen and the same input paths the map route uses. It only skips
## choosing a waystone, so any encounter can be stood up in one command:
##
##   godot --path . -- --fight=sporeling,sporeling
##   godot --path . -- --fight=gravewarden --kind=elite --seed=7
##   godot --path . -- --fight=duskfang --vp=1280x720
##   godot --path . -- --fight=duskfang --shape=pad-portrait --act=2
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
	_bench_fight = true
	_clear_route()
	_screen = CombatScreen.new(game, _shape, maxi(0, _forced_act))
	_screen.combat_over.connect(_on_combat_over)
	_screen.result_continue.connect(_on_result_continue)
	add_child(_screen)
	_screen.start_encounter(known, kind, "Bench  ·  %s" % kind.capitalize())


func _on_combat_over(result: String) -> void:
	if _bench_fight:
		_run_over = result != "win"
		_screen.show_result("Victory" if result == "win" else "Defeat",
			"The bench fight is complete.", "Map" if result == "win" else "New Run")
		return
	if result != "win":
		game.run.pending_combat = null
		game.run.pending_enemy_ids = null
		game.run.pending_run_end = {"outcome": "death"}
		if not SaveService.store(game.run):
			_show_save_error("The fall could not be held.")
			return
		_screen.show_result("Defeat", "The glass goes dark.", "Continue")
		return
	var node: MapNode = _map.current()
	var quest_id: String = str(game.run.pending_quest_id) \
		if game.run.pending_quest_id != null else ""
	game.run.pending_combat = null
	game.run.pending_enemy_ids = null
	game.run.pending_quest_id = null
	if quest_id == "ownShade":
		var scratch_v: Variant = game.run.quest_scratch.get("ownShade")
		if typeof(scratch_v) == TYPE_DICTIONARY:
			var scratch: Dictionary = scratch_v
			_grant_bequest(scratch.get("pendingBequest"))
			scratch.erase("pendingBequest")
		_map.clear_current()
		game.run.map = _map.to_dict()
		if not SaveService.store(game.run):
			_show_save_error("The shade victory could not be held.")
			return
		_screen.show_result("The Shade Breaks",
			"The standing glass releases what it carried.", "Continue")
		return
	if node.type == "boss" and game.run.act == 2:
		game.run.pending_run_end = {"outcome": "win"}
		if not SaveService.store(game.run):
			_show_save_error("The final victory could not be held.")
			return
		_screen.show_result("The Third Dawn", "The Sovereign's glass is broken.", "Continue")
		return
	var rewards: Dictionary = game.gen_combat_rewards(node.combat_kind(), game.cb.affix)
	var reward_cards: Array = rewards["cards"]
	game.quests.adjust_reward_cards(game.run, node.combat_kind(), reward_cards)
	game.run.pending_reward = {
		"rewards": rewards,
		"taken": {"gold": false, "card": false, "potion": false, "relic": false},
	}
	if not SaveService.store(game.run):
		_show_save_error("The victory rewards could not be held.")
		return
	_screen.show_result("Victory", "The spoils wait beyond the broken glass.", "Continue")


func _grant_bequest(value: Variant) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		return
	var bequest: Dictionary = value
	match str(bequest.get("kind")):
		"gold":
			game.run.player.gold += int(float(str(bequest.get("amount", 0))))
		"relic":
			var id: String = str(bequest.get("id"))
			game.rewards.gain_relic(game.run, id)
		"card":
			var id: String = str(bequest.get("id"))
			if content.cards.has(id):
				var upgraded: bool = bequest.get("up", false)
				game.run.player.deck.append(CardInst.new(
					game.run.next_uid(), StringName(id), upgraded))


func _on_result_continue() -> void:
	if _bench_fight:
		_bench_fight = false
		if _run_over:
			_new_run()
		else:
			_show_map()
		return
	if _run_over:
		_new_run()
		return
	_route_run()


# ---------------------------------------------------------------- rewards and acts

func _show_pending_reward() -> void:
	var pending: Dictionary = game.run.pending_reward
	var rewards: Dictionary = pending["rewards"]
	var taken: Dictionary = pending["taken"]
	_clear_route()
	_reward_screen = RewardScreen.new(rewards, content,
		_map.current().combat_kind() if _map.current() != null else "normal")
	_reward_screen.claimed.connect(_on_reward_claimed)
	_reward_screen.finished.connect(_on_reward_finished)
	add_child(_reward_screen)
	for key: String in ["gold", "card", "potion", "relic"]:
		if taken.get(key, false):
			_reward_screen.mark_taken(StringName(key))


func _on_reward_claimed(what: StringName, id: String) -> void:
	var pending: Dictionary = game.run.pending_reward
	var taken: Dictionary = pending["taken"]
	var key: String = String(what)
	if taken.get(key, false):
		return
	match what:
		&"gold":
			var rewards: Dictionary = pending["rewards"]
			var gold: int = int(float(str(rewards.get("gold", 0))))
			game.run.player.gold += gold
			game.run.stats["goldEarned"] = int(float(str(
				game.run.stats.get("goldEarned", 0)))) + gold
		&"card":
			if not id.is_empty():
				game.run.player.deck.append(CardInst.new(game.run.next_uid(), StringName(id), false))
		&"potion":
			var slot: int = game.run.player.potions.find("")
			if slot < 0:
				_show_potion_replace(id)
				return
			game.run.player.potions[slot] = id
		&"relic":
			if not id.is_empty():
				game.rewards.gain_relic(game.run, id)
	taken[key] = true
	if not SaveService.store(game.run):
		_show_save_error("The claimed reward could not be held.")


func _show_potion_replace(id: String) -> void:
	var choices: Array[Dictionary] = []
	for slot: int in range(game.run.player.potions.size()):
		var held: String = game.run.player.potions[slot]
		var held_def: Dictionary = content.potions.get(held, {})
		choices.append({
			"id": str(slot),
			"label": "Replace %s" % str(held_def.get("name", held)),
		})
	choices.append({"id": "discard", "label": "Discard the new phial", "quiet": true})
	_show_choice("PHIAL RACK FULL", "Choose what leaves the rack.", choices,
		_on_potion_replace.bind(id))


func _on_potion_replace(choice: String, id: String) -> void:
	if choice != "discard":
		game.run.player.potions[int(choice)] = id
	var pending: Dictionary = game.run.pending_reward
	var taken: Dictionary = pending["taken"]
	taken["potion"] = true
	if SaveService.store(game.run):
		_show_pending_reward()
	else:
		_show_save_error("The phial choice could not be held.")


func _on_reward_finished() -> void:
	game.run.pending_reward = null
	_map.clear_current()
	game.run.map = _map.to_dict()
	if SaveService.store(game.run):
		_route_run()
	else:
		_show_save_error("The cleared waystone could not be held.")


func _has_pending_boss_relic() -> bool:
	var node: MapNode = _map.current()
	return node != null and node.type == "boss" and _map.is_cleared(_map.at) \
		and game.run.act < 2 and game.run.boss_relic_act != game.run.act


func _show_boss_relic() -> void:
	var offer_v: Variant = game.run.quest_scratch.get("bossRelicOffer")
	var offer: Array[String] = []
	if typeof(offer_v) == TYPE_ARRAY:
		for id_v: Variant in offer_v:
			offer.append(str(id_v))
	else:
		offer = game.rewards.roll_boss_relics(game.run)
		game.run.quest_scratch["bossRelicOffer"] = offer.duplicate()
		if not SaveService.store(game.run):
			_show_save_error("The crown relics could not be held.")
			return
	var choices: Array[Dictionary] = []
	for id: String in offer:
		var relic: Dictionary = content.relics.get(id, {})
		choices.append({"id": id, "label": str(relic.get("name", id))})
	choices.append({"id": "", "label": "Take no crown", "quiet": true})
	_show_choice("A CROWN OF BROKEN GLASS", "Choose one relic before the next night.",
		choices, _on_boss_relic_chosen)


func _on_boss_relic_chosen(id: String) -> void:
	if not id.is_empty():
		game.rewards.gain_relic(game.run, id)
	game.run.boss_relic_act = game.run.act
	game.run.quest_scratch.erase("bossRelicOffer")
	game.run.start_next_act(content)
	_map = WorldMap.benchmark(game.run)
	game.quests.decorate_map(game.run, _map)
	game.run.map = _map.to_dict()
	if SaveService.store(game.run):
		_show_map()
	else:
		_show_save_error("The next act could not be held.")


# ---------------------------------------------------------------- terminal and durable side routes

func _show_run_end() -> void:
	var pending: Dictionary = game.run.pending_run_end
	var outcome: String = str(pending.get("outcome", "abandon"))
	if outcome == "death" and not pending.get("bequestAnswered", false):
		var choices: Array[Dictionary] = []
		var best_relic: String = ""
		var best_relic_rank: int = 0
		for relic_id: String in game.run.player.relics:
			var relic: Dictionary = content.relics.get(relic_id, {})
			var rank: int = int(float(str(
				RARITY_RANK.get(str(relic.get("rarity", "starter")), 0))))
			if rank > best_relic_rank:
				best_relic = relic_id
				best_relic_rank = rank
		if not best_relic.is_empty():
			choices.append({"id": "relic:" + best_relic,
				"label": "Leave %s" % str(content.relics[best_relic].get("name", best_relic))})
		var best_card: CardInst = null
		var best_card_rank: int = 0
		for card: CardInst in game.run.player.deck:
			var definition: Dictionary = content.cards.get(String(card.id), {})
			var rank: int = int(float(str(
				RARITY_RANK.get(str(definition.get("rarity", "starter")), 0))))
			if rank > best_card_rank or (rank == best_card_rank and rank > 0 \
					and card.up and (best_card == null or not best_card.up)):
				best_card = card
				best_card_rank = rank
		if best_card != null:
			var definition: Dictionary = content.cards[String(best_card.id)]
			choices.append({"id": "card:%d" % best_card.uid,
				"label": "Leave %s%s" % [
					str(definition.get("name", String(best_card.id))), "+" if best_card.up else ""]})
		if game.run.player.gold >= 25:
			var amount: int = mini(game.run.player.gold, 75)
			choices.append({"id": "gold:%d" % amount,
				"label": "Leave %d gold in the stone" % amount})
		choices.append({"id": "none", "label": "Leave nothing", "quiet": true})
		_show_choice("THE LAST LIGHT", "Choose what the next pilgrim may find.",
			choices, _on_bequest_chosen)
		return
	var title: String = "DAWN" if outcome == "win" else (
		"THE LANTERN FALLS" if outcome == "death" else "THE VOW IS SET ASIDE")
	_show_choice(title, "The Vigil is waiting to record this pilgrimage.",
		[{"id": "commit", "label": "Face the Vigil"}], _on_terminal_commit)


func _on_bequest_chosen(id: String) -> void:
	var bequest: Variant = null
	if id.begins_with("gold:"):
		bequest = {"kind": "gold", "amount": int(id.trim_prefix("gold:"))}
	elif id.begins_with("relic:"):
		var relic_id: String = id.trim_prefix("relic:")
		if content.relics.has(relic_id):
			bequest = {"kind": "relic", "id": relic_id}
	elif id.begins_with("card:"):
		var uid: int = int(id.trim_prefix("card:"))
		for card: CardInst in game.run.player.deck:
			if card.uid == uid:
				bequest = {"kind": "card", "id": String(card.id), "up": card.up}
				break
	var scratch: Dictionary = game.run.quest_scratch.get("ownShade", {})
	scratch["fall"] = {
		"act": game.run.act,
		"row": maxi(0, game.run.floors_climbed - 1),
		"shadeAspect": game.run.aspect,
		"bequest": bequest,
	}
	game.run.quest_scratch["ownShade"] = scratch
	var pending: Dictionary = game.run.pending_run_end
	pending["bequestAnswered"] = true
	if SaveService.store(game.run):
		_show_run_end()
	else:
		_show_save_error("The bequest could not be held.")


func _on_terminal_commit(_id: String) -> void:
	var pending: Dictionary = game.run.pending_run_end
	var outcome: String = str(pending["outcome"])
	if not _vigil.commit_run(game.run, outcome, content) or not SaveService.store_vigil(_vigil):
		_show_save_error("The Vigil could not record this pilgrimage.")
		return
	var events: Array = [{
		"title": "The Vigil Remembers",
		"body": "%s · %d shards lit" % [outcome.capitalize(), _vigil.shards.size()],
	}]
	var receipt: Dictionary = _vigil.receipts["runEnd"]
	for id_v: Variant in receipt.get("completed", []):
		var id: String = str(id_v)
		events.append({
			"title": "Emberglass Lit",
			"body": str(content.quests[id].get("name", id)),
		})
	game.run.pending_run_end = null
	game.run.pending_dawn = {"events": events, "cursor": 0}
	if SaveService.store(game.run):
		_show_dawn()
	else:
		_show_save_error("Dawn could not be held.")


func _show_dawn() -> void:
	var dawn: Dictionary = game.run.pending_dawn
	var events: Array = dawn["events"]
	var cursor: int = int(float(str(dawn.get("cursor", 0))))
	if cursor >= events.size():
		var run_id: String = game.run.run_id
		if SaveService.clear_run(run_id):
			_vigil = SaveService.load_vigil()
			game = null
			_show_title()
		else:
			_show_save_error("The completed run could not be closed.")
		return
	var event: Dictionary = events[cursor]
	_show_choice(str(event.get("title", "Dawn")), str(event.get("body", "")),
		[{"id": "continue", "label": "Continue"}], _on_dawn_continue)


func _on_dawn_continue(_id: String) -> void:
	var dawn: Dictionary = game.run.pending_dawn
	dawn["cursor"] = int(float(str(dawn.get("cursor", 0)))) + 1
	if SaveService.store(game.run):
		_show_dawn()
	else:
		_show_save_error("The Dawn cursor could not be held.")


func _has_pending_monument() -> bool:
	var node: MapNode = _map.current()
	return node != null and node.type == "monument" and not _map.is_cleared(_map.at)


func _show_monument() -> void:
	if typeof(game.run.monument) != TYPE_DICTIONARY:
		_finish_node()
		return
	var monument: Dictionary = game.run.monument
	var bequest_v: Variant = monument.get("bequest")
	var body: String = "A previous pilgrim stands inside the stone."
	if typeof(bequest_v) == TYPE_DICTIONARY:
		body += "\nSomething remains in their hands."
	_show_choice("MONUMENT OF THE LAST FALL", body, [
		{"id": "claim", "label": "Touch the standing glass"},
		{"id": "leave", "label": "Leave it", "quiet": true},
	], _on_monument_choice)


func _on_monument_choice(id: String) -> void:
	if id == "leave":
		_finish_node()
		return
	var monument: Dictionary = game.run.monument
	monument["claimed"] = true
	var scratch: Dictionary = game.run.quest_scratch.get("ownShade", {})
	scratch["pendingBequest"] = monument.get("bequest")
	game.run.quest_scratch["ownShade"] = scratch
	var progress: int = 0
	var quest_v: Variant = game.run.quests.get("ownShade")
	if typeof(quest_v) == TYPE_DICTIONARY:
		var quest: Dictionary = quest_v
		progress = int(float(str(quest.get("progress", 0))))
	var tier: int = clampi(progress + 1, 1, 3)
	game.run.pending_combat = "monster"
	game.run.pending_enemy_ids = ["ownShade%d" % tier]
	game.run.pending_quest_id = "ownShade"
	if not SaveService.store(game.run):
		_show_save_error("The shade duel could not be held.")
		return
	_vigil.last_fall = null
	if SaveService.store_vigil(_vigil):
		_resume_pending_combat()
	else:
		_show_save_error("The standing bequest could not be cleared.")


func _show_hollow() -> void:
	var pending: Dictionary = game.run.pending_hollow
	var meetings: Array = content.quests["hollowLamplighter"].get("meetings", [])
	var step: int = clampi(int(float(str(pending.get("meeting", 0)))), 0, meetings.size() - 1)
	var meeting: Dictionary = meetings[step]
	var body: String = str(pending.get("answer", "")) if pending.get("paid", false) \
		else str(meeting.get("ask", ""))
	var choices: Array[Dictionary] = []
	if pending.get("paid", false):
		choices.append({"id": "continue", "label": "Continue"})
	else:
		choices.append({"id": "pay", "label": "Pay the price"})
		choices.append({"id": "leave", "label": "Return another night", "quiet": true})
	_show_choice("THE HOLLOW LAMPLIGHTER", body, choices, _on_hollow_choice)


func _on_hollow_choice(id: String) -> void:
	if id == "pay":
		var result: Dictionary = game.quests.pay_hollow_price(game.run)
		if not result.get("ok", false):
			_show_choice("THE HOLLOW LAMPLIGHTER", str(result.get("message", "")),
				[{"id": "back", "label": "Return"}], func(_back: String) -> void: _show_hollow())
			return
		if not SaveService.store(game.run):
			_show_save_error("The Hollow price could not be held.")
			return
		_show_hollow()
		return
	_stage_hollow_exit()


func _stage_hollow_exit() -> void:
	var pending: Dictionary = game.run.pending_hollow
	var node: MapNode = _map.current()
	if node == null or node.id != str(pending.get("nodeId")) \
			or node.type != str(pending.get("type")):
		_show_save_error("The held Hollow destination is unreadable.")
		return
	game.run.pending_hollow = null
	if node.is_combat():
		_prepare_encounter(node)
		return
	var event_id: Variant = game.rewards.roll_event(game.run) if node.type == "event" else null
	game.run.pending_hollow_route = {
		"nodeId": node.id, "type": node.type, "eventId": event_id,
	}
	if event_id != null:
		game.run.quest_scratch["eventNode"] = event_id
	if SaveService.store(game.run):
		_show_hollow_route()
	else:
		_show_save_error("The Hollow destination could not be held.")


func _show_hollow_route() -> void:
	var route: Dictionary = game.run.pending_hollow_route
	match str(route.get("type")):
		"rest": _show_rest()
		"shop": _show_shop()
		"event": _show_event()
		_: _show_save_error("The held Hollow destination is unreadable.")


func _show_lamplighter() -> void:
	var offer_v: Variant = game.run.quest_scratch.get("lamplighterOffer")
	var offer: Dictionary
	if typeof(offer_v) == TYPE_DICTIONARY:
		offer = offer_v
	else:
		var pool: Array[String] = []
		for id: String in content.boons:
			var ops: Array = content.boons[id].get("ops", [])
			var needs_phials: bool = ops.any(func(op_v: Variant) -> bool:
				var op: Dictionary = op_v
				return op.has("potion"))
			if game.run.reveals_all or game.run.reveals.has("phials") or not needs_phials:
				pool.append(id)
		var ids: Array[String] = []
		var offer_count: int = mini(3, pool.size())
		while ids.size() < offer_count:
			ids.append(pool.pop_at(game.run.rng.pick_index(pool.size())))
		offer = {"boons": ids}
		game.run.quest_scratch["lamplighterOffer"] = offer
		if not SaveService.store(game.run):
			_show_save_error("The Lamplighter's gifts could not be held.")
			return
	var choices: Array[Dictionary] = []
	for id_v: Variant in offer.get("boons", []):
		var id: String = str(id_v)
		var boon: Dictionary = content.boons[id]
		choices.append({"id": id, "label": str(boon.get("name", id)),
			"hint": str(boon.get("text", ""))})
	_show_choice("THE LAMPLIGHTER", "Choose one gift before the first step.",
		choices, _on_lamplighter_boon)


func _on_lamplighter_boon(id: String) -> void:
	var offer: Dictionary = game.run.quest_scratch["lamplighterOffer"]
	if not offer.get("boons", []).has(id):
		return
	offer["boon"] = id
	if not SaveService.store(game.run):
		_show_save_error("The chosen gift could not be held.")
		return
	var choices: Array[Dictionary] = []
	for art_id: String in content.arts:
		var art: Dictionary = content.arts[art_id]
		choices.append({"id": art_id, "label": str(art.get("name", art_id)),
			"hint": str(art.get("text", ""))})
	_show_choice("THE LANTERN ART", "Choose how the carried flame will answer.",
		choices, _on_lamplighter_art)


func _on_lamplighter_art(id: String) -> void:
	var offer: Dictionary = game.run.quest_scratch["lamplighterOffer"]
	var boon_id: String = str(offer.get("boon", ""))
	if not content.arts.has(id) or not content.boons.has(boon_id):
		return
	game.run.art = StringName(id)
	game.rewards.apply_boon(game.run, boon_id)
	game.run.pending_lamplighter = false
	game.run.quest_scratch.erase("lamplighterOffer")
	if SaveService.store(game.run):
		_show_map()
	else:
		_show_save_error("The Lamplighter's gift could not be held.")
