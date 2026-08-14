class_name Main
extends Control
## Composition root (SKILL §2): owns the single GlassvowGame and routes
## title, durable run checkpoints, the benchmark map, combat and terminal
## screens. Domain mutation remains behind GlassvowGame and its rules.

const RARITY_RANK: Dictionary = {
	"starter": 0, "special": 0, "common": 1, "uncommon": 2, "rare": 3, "boss": 4,
}
const ChoiceScreenType: GDScript = preload("res://presentation/run/choice_screen.gd")

var content: ContentDB
var game: GlassvowGame
var _map: WorldMap
var _screen: CombatScreen = null
## A fight owns one complete language. Settings may persist a request during
## combat, but Locale and ContentDB change together only at the next route seam.
var _content_hydration_pending: bool = false
var _pending_language: StringName = &""
var _route_checkpoint_quarantined: bool = false
## Exact live route constructor; durable resume reconstructs the initial route.
var _route_rebuilder: Callable = Callable()
var _map_screen: WorldMapScreen = null
var _choice_screen: Control = null
var _reward_screen: RewardScreen = null
var _route_screen: Control = null
var _run_hud: RunHud = null
var _modal: Control = null
## Routed surface held under a modal/choice overlay (`PROCESS_MODE_DISABLED`).
## Combat (`_screen`) is never frozen — its awaits must not desync.
var _frozen_under_modal: Control = null
## Veils may stack (a modal over an overlay choice): the surface thaws only
## when the last one lifts.
var _freeze_count: int = 0
## Title buttons barred from keyboard focus while a modal is up (see
## `_freeze_under_modal`): one {button, mode} entry each, so thaw restores
## what a button HAD, not what we assume it had.
var _defocused_under_modal: Array[Dictionary] = []
## The button holding focus when the veil rose — thaw hands it back, so the
## title does not come back keyboard-dead.
var _refocus_after_thaw: BaseButton = null
## Whether the current `_modal` froze the world — the run-menu drawer does not.
var _modal_froze: bool = false
## Above RunHud's z 100 (run_hud.gd:37): the veil must outdraw the chrome it
## subdues, or a frozen HUD is the brightest thing on a veiled screen.
const MODAL_Z: int = 200
var _music: MusicBus
var _sfx_bus: SfxBus
var _vigil: VigilState
var _embark_aspect: int = 0
var _embark_vow: int = 0
var _run_over: bool = false
var _bench_fight: bool = false
var _run_save_path: String = SaveService.RUN_PATH
var _vigil_save_path: String = SaveService.VIGIL_PATH
## Set when the optional Development boot handled this launch.
var _dev_claimed: bool = false
var last_dev_error: String = ""
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
## --act=N: which act's scenery the fight or map is dressed in. The domain does
## not model acts yet, so a fight from `--fight=` / a `--map` run is act 0 and
## there was no way to see the other two outside the layout bench — while the
## book authors all three for every shape. Clamped to the three the benchmark
## authors (`src/dev/bf-editor.js:169`). Map generation is never act-forced.
var _forced_act: int = -1
## --settle=SECONDS: extra wait before a `--shot=` capture, so a composition is
## photographed at rest rather than mid-entrance.
var _settle: float = 0.0
## The ceremony layer — wipe, transit leaves, grain — living above every routed
## screen so a leaf started before a route swap finishes over the incoming
## screen. Screens never see it; main fires it around its own route helpers.
var _transitions: TransitionLayer


func _init() -> void:
	# Install the default UI face on the shipping composition root after imported
	# resources exist. Routed screens may refine this theme; unthemed descendants
	# such as RunHud still inherit the same Noto Serif TC default.
	theme = GlassStyle.theme()


## The pool turned into an amount. The fraction is the frozen web law and
## RewardRules owns it (engine.js restHealFrac: `min(0.3, omen, vow)`) — this
## is only the rounding, kept in one place so the rest screen's promise and
## the heal it applies can never round apart.
static func rest_heal_amount(max_hp: int, fraction: float) -> int:
	return int(roundf(float(max_hp) * fraction))


func _apply_content_hydration() -> int:
	_content_hydration_pending = false
	return Locale.active.hydrate_content(content)


func _apply_pending_content_hydration() -> int:
	if not _content_hydration_pending:
		return 0
	if not _pending_language.is_empty():
		if not Locale.active.set_language(_pending_language):
			return 0
		_pending_language = &""
	return _apply_content_hydration()


func _remember_route(rebuilder: Callable) -> void:
	_route_rebuilder = rebuilder


func _rebuild_active_route() -> void:
	var rebuild: Callable = _route_rebuilder
	if rebuild.is_valid():
		rebuild.call()
	elif game != null:
		_route_run()
	else:
		_show_title()


func _ready() -> void:
	print("glassvow boot " + str(Engine.get_version_info()["string"]))
	content = ContentDB.load_full()
	_vigil = _load_vigil()
	Preferences.active = Preferences.read_from_disk()
	# Locale follows Preferences: main publishes the live handle; labs keep the
	# default English stand-in (docs/p7-locale-design.md §3). Language comes
	# from the saved setting, else OS (`zh*` → zh-Hant).
	Locale.active = Locale.new(Preferences.active.effective_language())
	# Content display fields are overlaid onto the live rows, not looked up at
	# every draw (docs/p7-locale-design.md §3) — presentation keeps reading
	# `name` / `text` / move names straight off ContentDB.
	_apply_content_hydration()
	_music = MusicBus.new()
	add_child(_music)
	_sfx_bus = SfxBus.new()
	add_child(_sfx_bus)
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
	# godot --path . -- --act=2                  (dress fight/map in act 2's scenery)
	# tools/shot.sh --resume --shot=...          (exercise the durable router)
	# tools/shot.sh --fight=… --settle=3 --shot=…  (photograph it at rest)
	# tools/shot.sh --font-probe --shot=/tmp/font.png  (runtime default font)
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
	# --map: start a run and STOP on the world map, instead of walking on to a
	# fight the way `--enter=` does. The map was the one production screen with
	# no route to it — `--fight=` skips past it and `--enter=` uses it and leaves
	# — so its composition could be reasoned about and never looked at. A screen
	# that cannot be captured cannot be verified, and this lane's whole method is
	# to measure rather than to argue.
	var show_map: bool = false
	var show_dawn_bench: bool = false
	var show_font_probe: bool = false
	var performance_probe: bool = false
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
		elif arg == "--map":
			show_map = true
		elif arg == "--dawn":
			show_dawn_bench = true
		elif arg == "--font-probe":
			show_font_probe = true
		elif arg.begins_with("--perf-out="):
			performance_probe = true
		elif arg in ["--enemies", "--chips", "--hud", "--reward", "--layout"]:
			lab_flag = arg
	if performance_probe and (fight.is_empty() or not shot_path.is_empty()
			or cards_lab or studio or not lab_flag.is_empty()):
		push_error("--perf-out requires one --fight route and no capture or lab")
		get_tree().quit(2)
		return
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
	# A plain boot is the player's window; any tooling invocation (--shot=,
	# labs, --fight=, --vp=) owns its own window and must not be hijacked by a
	# saved fullscreen choice. Applied before the shape pick so the stage is
	# chosen against the window the player will actually see.
	if OS.get_cmdline_user_args().is_empty():
		Preferences.active.apply_display()
	_apply_shape()
	var window: Window = get_window()
	if window != null:
		window.size_changed.connect(_apply_shape)
	_transitions = TransitionLayer.new()
	# A capture must photograph the destination, not the ceremony over it.
	_transitions.instant = shot_path != ""
	add_child(_transitions)
	if show_font_probe:
		_show_runtime_font_probe()
		if shot_path != "":
			_capture_and_quit(shot_path)
		return
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
	if DevTools.available():
		var boot: GDScript = load(DevTools.BOOT) as GDScript
		if boot != null:
			boot.call("apply", self, OS.get_cmdline_user_args())
		if _dev_claimed:
			if performance_probe:
				_attach_performance_probe()
			elif shot_path != "":
				_capture_and_quit(shot_path)
			return
	if resume_run:
		_continue_run(SaveService.load_run(content))
	elif show_dawn_bench:
		# The Dawn ceremony bench: a fresh run handed a representative feed, so
		# the victory beat can be photographed without climbing three acts.
		# Same reason --fight= exists (see _start_fight's docblock).
		_new_run()
		game.run.pending_run_end = null
		# The fixture mirrors _on_terminal_commit's event shapes EXACTLY — same
		# kinds, same field layout (title = the earned thing, kicker speaks the
		# register) — so what the bench photographs is what a player sees.
		game.run.pending_dawn = {"events": [
			{"kind": "whisper", "title": "",
				"body": "The Spire kept none of what you gave it."},
			{"kind": "quest", "title": "The Pale Ones",
				"body": "Three climbers went pale before you. Find what bleached them."},
			{"kind": "progress", "title": "The Pale Ones", "body": "",
				"count": "2/3"},
			{"kind": "shard", "title": "The Shade That Fell",
				"body": "One pane answers.", "icon": "shard"},
			{"kind": "unlock", "title": "New cards and relics enter the climb.",
				"body": ""},
			{"kind": "unlock", "title": "A sealed door opens above the crown.",
				"body": "", "icon": "door"},
			{"kind": "memory", "title": "The Vigil Remembers",
				"body": "Victory · 3 shards lit"},
		], "cursor": 0}
		if SaveService.store(game.run):
			_show_dawn()
	elif show_map:
		_new_run()
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
	if performance_probe:
		_attach_performance_probe()
	elif shot_path != "":
		_capture_and_quit(shot_path)


func _attach_performance_probe() -> void:
	var script: GDScript = load("res://tools/bench_combat.gd") as GDScript
	if script == null:
		push_error("performance probe did not load")
		get_tree().quit(2)
		return
	var instance: Variant = script.new()
	if not instance is Node:
		push_error("performance probe did not instantiate")
		get_tree().quit(2)
		return
	var probe: Node = instance
	add_child(probe)


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
	var repicked: bool = shape != _shape
	_shape = shape
	window.content_scale_size = size
	print("stage %s %dx%d  window %dx%d  flex %+.1f%%" % [shape, size.x, size.y,
		px.x, px.y, StageShape.flex_of(shape, px) * 100.0])
	if repicked:
		_reshape()


## Tell the live screen its shape changed, not just its size.
##
## The two are different events and only one of them used to arrive. Growing
## INSIDE a shape is the flex, and every number in the book is bound to an edge,
## so a screen follows that by itself — `CombatScreen._layout()` re-places
## against `size` at read time and needs no telling. Crossing an aspect boundary
## re-picks the shape, which swaps the whole authored composition: different card
## width, different formation, different chrome seats. Nothing re-resolved it,
## so the window changed size and the composition stayed on the old shape's
## numbers until the next screen was built.
##
## Routed by capability rather than by type. A screen that can re-seat itself
## says so with a `set_shape` method; one that cannot is left alone, because a
## half-applied shape looks like a bug rather than like a missing feature.
##
## Combat participates without rebuilding the encounter: its setter re-frames
## each existing EnemyView while retaining the SubViewport, fracture and tweens.
func _reshape() -> void:
	for screen: Control in [
		_screen, _map_screen, _choice_screen, _reward_screen,
		_route_screen, _run_hud, _modal,
	]:
		if screen != null and screen.has_method(&"set_shape"):
			screen.call(&"set_shape", _shape)


## The physical screen diagonal in inches, or 0 when it cannot be measured —
## which is exactly what `StageShape.class_for` wants for "unknowable". Only the
## touch platforms ever consult it; a named desktop OS decides before this runs.
func _screen_diagonal() -> float:
	var dpi: int = DisplayServer.screen_get_dpi()
	if dpi <= 0:
		return 0.0
	return Vector2(DisplayServer.screen_get_size()).length() / float(dpi)


## Saves are durable at every boundary, so this needs no flush — it exists so
## every quit door (title, run menu, window close) goes through one frame, today
## and when the path grows.
func _quit_game() -> void:
	get_tree().quit()


func _store_run() -> bool:
	return SaveService.store(game.run, _run_save_path)


func _store_vigil() -> bool:
	return SaveService.store_vigil(_vigil, _vigil_save_path)


func _load_vigil() -> VigilState:
	return SaveService.load_vigil(_vigil_save_path)


## Window close is a clean quit: with `config/auto_accept_quit=false` the engine
## hands us NOTIFICATION_WM_CLOSE_REQUEST instead of exiting itself. No save
## flush — durable at every boundary; the interception is the single path.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit_game()


## A headed proof of the shipping root's default font. The Label carries no font
## override: its resolved face can only come from Main.theme.
func _show_runtime_font_probe() -> void:
	var ground: ColorRect = ColorRect.new()
	ground.color = GlassStyle.NIGHT_BOT
	ground.set_anchors_preset(Control.PRESET_FULL_RECT)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)
	var label: Label = Label.new()
	label.text = "琉璃誓言"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 72)
	label.add_theme_color_override("font_color", GlassStyle.TEXT)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(label)


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
	# Everything below is about to be freed: drop the whole freeze stack, not
	# one level of it, so no count survives into the next surface.
	_freeze_count = 0
	_thaw_surfaces()
	for screen: Control in [
		_screen, _map_screen, _choice_screen, _reward_screen,
		_route_screen, _run_hud, _modal,
	]:
		if screen != null:
			screen.queue_free()
	_screen = null
	_map_screen = null
	_choice_screen = null
	_reward_screen = null
	_route_screen = null
	_run_hud = null
	_modal = null


func _freeze_under_modal() -> void:
	_freeze_count += 1
	if _freeze_count > 1:
		return
	# First live non-combat surface; combat stays running so awaits do not
	# desync. The title is a deliberate exception too: it lives in
	# `_choice_screen`, never a candidate here, so its world keeps breathing
	# behind Settings — routed worlds are held, the living sky is not hung.
	var under: Control = _route_screen
	if under == null:
		under = _map_screen
	if under == null:
		under = _reward_screen
	if under != null:
		under.process_mode = Node.PROCESS_MODE_DISABLED
		_frozen_under_modal = under
	if _run_hud != null:
		_run_hud.process_mode = Node.PROCESS_MODE_DISABLED
	# The breathing title must still lose the KEYBOARD: its buttons stay
	# focusable under the veil, and focus traversal ignores the scrim — a
	# Tab from the button that opened the modal lands on Quit, and Enter
	# presses it. Bar focus while any modal is up; restore on thaw.
	if _choice_screen != null:
		_choice_screen.set_process_unhandled_key_input(false)
		for node: Node in _choice_screen.find_children("", "BaseButton", true, false):
			var button: BaseButton = node
			if button.focus_mode != Control.FOCUS_NONE:
				if button.has_focus():
					_refocus_after_thaw = button
					button.release_focus()
				_defocused_under_modal.append({
					"button": button, "mode": button.focus_mode,
				})
				button.focus_mode = Control.FOCUS_NONE


func _thaw_under_modal() -> void:
	if _freeze_count == 0:
		return
	_freeze_count -= 1
	if _freeze_count == 0:
		_thaw_surfaces()


func _thaw_surfaces() -> void:
	if _frozen_under_modal != null and is_instance_valid(_frozen_under_modal):
		_frozen_under_modal.process_mode = Node.PROCESS_MODE_INHERIT
	_frozen_under_modal = null
	for entry: Dictionary in _defocused_under_modal:
		var button: BaseButton = entry["button"]
		var mode: int = entry["mode"]
		if is_instance_valid(button):
			button.focus_mode = mode as Control.FocusMode
	_defocused_under_modal.clear()
	if _refocus_after_thaw != null and is_instance_valid(_refocus_after_thaw):
		_refocus_after_thaw.grab_focus()
	_refocus_after_thaw = null
	if _choice_screen != null and is_instance_valid(_choice_screen):
		_choice_screen.set_process_unhandled_key_input(true)
	if _run_hud != null and is_instance_valid(_run_hud):
		_run_hud.process_mode = Node.PROCESS_MODE_INHERIT


func _close_choice_overlay() -> void:
	if _choice_screen != null:
		_choice_screen.queue_free()
		_choice_screen = null
	_thaw_under_modal()


func _show_route(screen: Control, with_hud: bool = false,
		cue: StringName = &"", entrance: bool = true) -> void:
	# The wipe fires on every screen change with a live run, and only then —
	# navigation.js:80. The title and a fresh boot arrive without ceremony.
	if game != null and game.run != null:
		_transitions.wipe()
	_clear_route()
	_route_screen = screen
	add_child(screen)
	_transitions.set_grain(true)
	# Death owns its own graveReveal + monumentRise; skip the generic screen_in
	# so the two entrances do not stack (issue #18).
	if entrance:
		_transitions.screen_in(screen)
	if with_hud:
		_attach_run_hud()
	if not cue.is_empty():
		_music.play(cue)


func _attach_run_hud() -> void:
	_run_hud = RunHud.new(game.run, content, _shape, _sfx_bus)
	_run_hud.deck_requested.connect(_show_run_deck)
	_run_hud.menu_requested.connect(_show_run_menu)
	_run_hud.potion_requested.connect(_show_potion_menu)
	add_child(_run_hud)


func _show_overlay(screen: Control, freeze: bool = true) -> void:
	if _modal != null:
		if _modal_froze:
			_thaw_under_modal()
		_modal.queue_free()
	_modal = screen
	screen.z_index = MODAL_Z
	add_child(screen)
	if freeze:
		_freeze_under_modal()
	_modal_froze = freeze
	# RunHud's Escape rung must not fire under an overlay — the modal owns cancel.
	if _run_hud != null:
		_run_hud.set_process_unhandled_key_input(false)


func _close_overlay() -> void:
	if _modal == null:
		return
	_modal.queue_free()
	_modal = null
	if _modal_froze:
		_thaw_under_modal()
	_modal_froze = false
	if _run_hud != null:
		_run_hud.set_process_unhandled_key_input(true)


func _show_choice(title: String, body: String, choices: Array[Dictionary], handler: Callable,
		context: Dictionary = {}) -> void:
	# The shape rides in the context rather than in a fifth positional argument:
	# `ChoiceScreen` already had a context bag for the title variant, and every
	# other caller of it stays untouched.
	var ctx: Dictionary = context.duplicate()
	ctx["shape"] = String(_shape)
	var overlay: bool = ctx.get("overlay", false) == true
	var live: bool = _route_screen != null or _map_screen != null or _reward_screen != null
	if overlay and live:
		# Keep the routed surface; veil + freeze instead of a wipe/clear.
		if _choice_screen != null:
			_close_choice_overlay()
		_freeze_under_modal()
		_choice_screen = ChoiceScreenType.new(title, body, choices, ctx, _sfx_bus)
		_choice_screen.z_index = MODAL_Z
		_choice_screen.connect("chosen", func(id: String) -> void:
			_close_choice_overlay()
			handler.call(id)
		)
		add_child(_choice_screen)
		_transitions.screen_in(_choice_screen)
		return
	if game != null and game.run != null:
		_transitions.wipe()
	_clear_route()
	_choice_screen = ChoiceScreenType.new(title, body, choices, ctx, _sfx_bus)
	_choice_screen.connect("chosen", handler)
	add_child(_choice_screen)
	_transitions.set_grain(true)
	_transitions.screen_in(_choice_screen)


func _show_title() -> void:
	_remember_route(_show_title)
	_apply_pending_content_hydration()
	var saved: RunState = SaveService.load_run(content)
	var choices: Array[Dictionary] = []
	if saved != null:
		choices.append({"id": "continue", "label": Locale.active.t("ui.menu.continueClimb")})
	choices.append_array([
		{"id": "begin", "label": Locale.active.t("ui.menu.beginClimb")},
		{"id": "vigil", "label": Locale.active.t("ui.menu.theVigil"), "quiet": true},
		{"id": "help", "label": Locale.active.t("ui.menu.howToPlay"), "quiet": true},
		{"id": "settings", "label": Locale.active.t("ui.menu.settings"), "quiet": true},
		{"id": "credits", "label": Locale.active.t("ui.menu.credits"), "quiet": true},
	])
	if DevTools.available():
		var dev_label: String = _dev_console_label()
		if not dev_label.is_empty():
			choices.append({"id": "dev", "label": dev_label, "quiet": true})
	# Desktop only — web has no process to leave.
	if not OS.has_feature("web"):
		choices.append({"id": "quit", "label": Locale.active.t("ui.menu.quit"), "quiet": true})

	var title_stats: String = Locale.active.t("ui.brand.stats", {
		"runs": int(float(str(_vigil.deeds.get("runs", 0)))),
		"wins": int(float(str(_vigil.deeds.get("wins", 0)))),
		"slain": int(float(str(_vigil.deeds.get("slain", 0)))),
	})
	if not _vigil.unlocks.is_empty():
		title_stats += Locale.active.t("ui.brand.secrets", {"n": _vigil.unlocks.size()})
	_show_choice(Locale.active.t("ui.brand.title"),
		Locale.active.t("ui.brand.tagline"), choices,
		_on_title_choice.bind(saved), {
		"variant": "title",
		"stats": title_stats,
		# One build string, one source: the same setting the settings-panel
		# footer reads. The benchmark's 0.5.0+6e06911 stamp lives on in the
		# parity docs, not on the player's title screen.
		"version": str(ProjectSettings.get_setting("application/config/version", "")),
		"rose_shards": _vigil.shards,
	})
	_music.play(&"title")


func _on_title_choice(id: String, saved: RunState) -> void:
	match id:
		"continue": _continue_run(saved)
		"begin": _show_embark()
		"vigil": _show_vigil()
		"rose": _show_vigil(true)
		"help": _show_help()
		"settings": _show_settings()
		"credits": _show_credits()
		"dev": _show_dev_console()
		"quit": _quit_game()


func _show_embark() -> void:
	_remember_route(_show_embark)
	var saved: bool = SaveService.load_run(content) != null
	var screen: EmbarkScreen = EmbarkScreen.new(
		content.aspects,
		content.vows,
		_vigil.unlocks.has("aspect2"),
		_vigil.vow_unlocked,
		saved,
		_embark_aspect,
		_embark_vow,
		_shape,
		_sfx_bus)
	screen.begin_requested.connect(_on_embark_begin)
	screen.back_requested.connect(_show_title)
	_show_route(screen, false, &"embark")


func _on_embark_begin(aspect: int, vow: int) -> void:
	_embark_aspect = aspect
	_embark_vow = vow
	if SaveService.load_run(content) == null:
		_new_run({"aspect": _embark_aspect, "vow": _embark_vow})
	else:
		_show_choice(Locale.active.t("ui.menu.beginAnew").to_upper(),
			Locale.active.t("ui.menu.beginAnewBody"),
			[{"id": "begin", "label": Locale.active.t("ui.menu.beginAnew")},
				{"id": "back", "label": Locale.active.t("ui.menu.keepClimbing"), "quiet": true}],
			_on_begin_anew, {"cancel": "back"})


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
	if not _vigil.commit_run(game.run, "abandon", content) or not _store_vigil():
		_show_save_error("ui.persistence.detail.currentPilgrimageClose")
		return
	if not SaveService.clear_run(game.run.run_id):
		_show_save_error("ui.persistence.detail.currentPilgrimageClear")
		return
	_new_run({"aspect": _embark_aspect, "vow": _embark_vow})


func _show_vigil(open_rose: bool = false) -> void:
	_remember_route(_show_vigil.bind(open_rose))
	var screen: VigilScreen = VigilScreen.new(_vigil, content, _shape, open_rose, _sfx_bus)
	screen.back_requested.connect(_show_title)
	screen.cue_requested.connect(func(cue: StringName) -> void: _music.play(cue))
	_show_route(screen, false, &"vigil")


func _show_help() -> void:
	var screen: HelpScreen = HelpScreen.new(_shape, _sfx_bus)
	screen.closed.connect(_close_overlay)
	_show_overlay(screen)


func _show_credits() -> void:
	var screen: CreditsScreen = CreditsScreen.new(_shape, _sfx_bus)
	screen.closed.connect(_close_overlay)
	_show_overlay(screen)


func _dev_console_label() -> String:
	var script: GDScript = load(DevTools.CONSOLE) as GDScript
	return str(script.call("entry_label")) if script != null else ""


func _show_dev_console() -> void:
	var script: GDScript = load(DevTools.CONSOLE) as GDScript
	if not DevTools.available() or script == null:
		return
	var screen: Control = script.new(self, _shape, _sfx_bus)
	screen.connect("closed", _close_overlay)
	_show_overlay(screen, true)


func _show_settings(focus_language: bool = false) -> void:
	var deferred: bool = _screen != null and _content_hydration_pending
	var screen: SettingsPanel = SettingsPanel.new(
		Preferences.active, _run_over, _sfx_bus, deferred)
	screen.set_shape(_shape)
	screen.closed.connect(_close_overlay)
	screen.reset_requested.connect(_confirm_reset)
	screen.language_changed.connect(_on_language_changed)
	_show_overlay(screen)
	if focus_language:
		screen.focus_language()


## Main owns the language transaction. Non-combat activates, hydrates and
## rebuilds one route atomically; combat persists the request but keeps its
## entire Locale/ContentDB pair until the next route constructor.
func _on_language_changed(code: StringName) -> void:
	if code != Locale.CODE_EN and code != Locale.CODE_ZH_HANT:
		return
	Preferences.active.set_language(String(code))
	_pending_language = code
	_content_hydration_pending = code != Locale.active.code
	if not _content_hydration_pending:
		_pending_language = &""
	_close_overlay()
	if _screen != null:
		_show_settings(true)
		return
	_apply_pending_content_hydration()
	_rebuild_active_route()
	_show_settings(true)


func _confirm_reset() -> void:
	_close_overlay()
	# Typed local, not an inline literal: `.new()` does not convert an untyped
	# Array to the `Array[Dictionary]` parameter and construction fails.
	var choices: Array[Dictionary] = [
		{"id": "yes", "label": Locale.active.t("ui.settings.eraseEverything")},
		{"id": "no", "label": Locale.active.t("ui.common.cancel"), "quiet": true},
	]
	var screen: Control = ChoiceScreenType.new(
		Locale.active.t("ui.settings.eraseAllTitle"),
		Locale.active.t("ui.settings.resetConfirmPlain"),
		choices,
		{"shape": String(_shape), "cancel": "no", "overlay": true},
		_sfx_bus)
	screen.connect("chosen", _on_reset_choice)
	_show_overlay(screen)


func _on_reset_choice(id: String) -> void:
	if id != "yes":
		_close_overlay()
		return
	SaveService.clear()
	SaveService.clear_vigil(_vigil_save_path)
	game = null
	_map = null
	_vigil = _load_vigil()
	_show_title()


func _show_save_error(detail_key: String) -> void:
	_show_choice(Locale.active.t("ui.persistence.lightWouldNotHoldTitle"),
		Locale.active.t(detail_key) + "\n" + Locale.active.t("ui.persistence.noProgressDiscarded"),
		[{"id": "retry", "label": Locale.active.t("ui.common.retry")},
			{"id": "title", "label": Locale.active.t("ui.common.title"), "quiet": true}],
		_on_save_error_choice)


func _on_save_error_choice(id: String) -> void:
	if id == "retry" and game != null and SaveService.store(game.run):
		_route_run()
	else:
		_show_title()


func _new_run(profile: Dictionary = {}) -> void:
	_route_checkpoint_quarantined = false
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
	game.run.stats["start"] = Time.get_unix_time_from_system()
	game.quests.prepare_run(game.run)
	# Six shards used to replace the whole pilgrimage with a one-node Act IV
	# ceremony (the loop in #217). The sealed door is an overlay on the ordinary
	# final-act map — map.js:106 — not a different graph.
	_map = WorldMap.benchmark(game.run)
	game.quests.decorate_map(game.run, _map)
	game.run.map = _map.to_dict()
	_run_over = false
	if _store_run():
		_route_run()
	else:
		_show_save_error("ui.persistence.detail.pilgrimageStart")


## Route a Development Scenario onto the kernel's default profile. Fail-closed.
func apply_dev_scenario(ref: ScenarioReference) -> bool:
	_dev_claimed = true
	last_dev_error = ""
	if ref == null or not ref.error.is_empty():
		last_dev_error = ref.error if ref != null else "Scenario reference is unreadable"
		push_error(last_dev_error)
		return false
	var kernel: ScenarioKernel = ScenarioKernel.new(content)
	var run: RunState = kernel.construct(ref)
	if run == null:
		last_dev_error = kernel.last_error
		push_error(kernel.last_error)
		return false
	# Review-state locale only. Do not persist through the player settings file.
	if not ref.locale.is_empty():
		var wanted: StringName = StringName(ref.locale)
		if Locale.active.code != wanted:
			if not Locale.active.set_language(wanted):
				last_dev_error = "unsupported locale %s" % ref.locale
				push_error(last_dev_error)
				return false
			_content_hydration_pending = true
	_run_save_path = kernel.run_path
	_vigil_save_path = kernel.vigil_path
	_vigil = _load_vigil()
	_continue_run(run)
	return true


func _continue_run(saved: RunState) -> void:
	_route_checkpoint_quarantined = false
	if saved == null:
		_show_title()
		return
	var restored: WorldMap = WorldMap.from_dict(saved.map)
	if restored == null:
		_show_save_error("ui.persistence.detail.savedPilgrimageMapUnreadable")
		return
	game = GlassvowGame.new(content, saved)
	_map = restored
	_route_run()


func _route_run() -> void:
	_apply_pending_content_hydration()
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
		if not _dispatch_current_route():
			_show_map()
	elif _has_pending_monument():
		_show_monument()
	elif _has_pending_boss_relic():
		_show_boss_relic()
	elif game.run.pending_lamplighter:
		_show_lamplighter()
	elif _dispatch_current_route():
		pass
	else:
		_show_map()


func _dispatch_current_route() -> bool:
	if _map == null or game == null or game.run == null:
		return false
	var node: MapNode = _map.current()
	var scratch: Dictionary = game.run.quest_scratch
	var route_keys: Array[String] = [
		"eventNode", "eventPending", "shopStock", "treasureClaim"]
	var has_route_scratch: bool = route_keys.any(
		func(key: String) -> bool: return scratch.has(key))
	var receipt_v: Variant = game.run.pending_hollow_route
	if node == null or _map.is_cleared(_map.at) \
			or node.type not in ["rest", "event", "shop", "treasure"]:
		return _quarantine_route() if has_route_scratch or receipt_v != null else false
	if game.run.node_id != node.id:
		return _quarantine_route()
	var allowed: Dictionary = {"rest": [], "event": ["eventNode", "eventPending"],
		"shop": ["shopStock"], "treasure": ["treasureClaim"]}
	for key: String in route_keys:
		if scratch.has(key) and not allowed[node.type].has(key):
			return _quarantine_route()
	if receipt_v != null and not _valid_hollow_route(receipt_v, node):
		return _quarantine_route()
	match node.type:
		"rest":
			_show_rest()
			return true
		"event":
			var event_v: Variant = scratch.get("eventNode")
			var event_id: String = event_v if typeof(event_v) == TYPE_STRING else ""
			if scratch.has("eventNode") \
					and (event_id.is_empty() or not content.events.has(event_id)):
				return _quarantine_route()
			var pending_v: Variant = scratch.get("eventPending")
			if scratch.has("eventPending") \
					and (not scratch.has("eventNode") \
					or not game.rewards.valid_event_checkpoint(
						game.run, event_id, pending_v)):
				return _quarantine_route()
			_show_event()
			if typeof(pending_v) == TYPE_DICTIONARY:
				var pending: Dictionary = pending_v
				_show_event_pick(pending)
			return true
		"shop":
			var stock_v: Variant = scratch.get("shopStock")
			if scratch.has("shopStock") and not game.rewards.valid_shop_checkpoint(
					game.run, stock_v):
				return _quarantine_route()
			_show_shop()
			return true
		"treasure":
			var claim_v: Variant = scratch.get("treasureClaim")
			if scratch.has("treasureClaim") and not game.rewards.valid_treasure_checkpoint(
					game.run, claim_v):
				return _quarantine_route()
			_show_treasure()
			return true
	return false


func _valid_hollow_route(value: Variant, node: MapNode) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	var route: Dictionary = value
	if route.size() != 3 or not route.has_all(["nodeId", "type", "eventId"]) \
			or typeof(route["nodeId"]) != TYPE_STRING \
			or typeof(route["type"]) != TYPE_STRING \
			or route["nodeId"] != node.id or route["type"] != node.type:
		return false
	if node.type == "event":
		return typeof(route["eventId"]) == TYPE_STRING \
			and route["eventId"] == game.run.quest_scratch.get("eventNode")
	return route["eventId"] == null


func _quarantine_route() -> bool:
	_route_checkpoint_quarantined = true
	return false
# ---------------------------------------------------------------- map

func _show_map() -> void:
	_remember_route(_show_map)
	_apply_pending_content_hydration()
	if game != null and game.run != null:
		_transitions.wipe()
	_clear_route()
	_map_screen = WorldMapScreen.new(_map, content, _shape)
	_map_screen.node_chosen.connect(_on_node_chosen)
	_map_screen.sealed_door_requested.connect(_on_sealed_door_requested)
	add_child(_map_screen)
	_map_screen.refresh(game.run)
	# --map --act=N: dress scenery only (domain map stays the run's act).
	if _forced_act >= 0:
		_map_screen.set_act_scenery(_forced_act)
	_transitions.set_grain(true)
	_transitions.screen_in(_map_screen)
	_attach_run_hud()
	_music.play(&"map")


func _show_run_menu() -> void:
	var menu: RunMenuPanel = RunMenuPanel.new(_shape, _run_over, _sfx_bus)
	menu.closed.connect(_close_overlay)
	menu.help_requested.connect(func() -> void:
		_close_overlay()
		_show_help()
	)
	menu.settings_requested.connect(func() -> void:
		_close_overlay()
		_show_settings()
	)
	menu.dev_requested.connect(func() -> void:
		_close_overlay()
		_show_dev_console()
	)
	menu.title_requested.connect(func() -> void:
		_close_overlay()
		# Save on disk is the truth — drop the in-memory run, same as reset.
		game = null
		_map = null
		_show_title()
	)
	menu.quit_requested.connect(func() -> void:
		_close_overlay()
		_show_choice(Locale.active.t("ui.menu.leaveSpireTitle"),
			Locale.active.t("ui.menu.leaveSpireBody"),
			[{"id": "yes", "label": Locale.active.t("ui.common.leave")},
				{"id": "no", "label": Locale.active.t("ui.common.stay"), "quiet": true}],
			func(id: String) -> void:
				if id == "yes":
					_quit_game(),
			{"cancel": "no", "overlay": true})
	)
	menu.abandon_requested.connect(_confirm_abandon)
	# The drawer neither veils nor freezes: seeing the world stay alive is the
	# point of a glance at the menu. Veil and stillness travel together.
	_show_overlay(menu, false)


func _confirm_abandon() -> void:
	_close_overlay()
	# Typed local, not an inline literal — see `_confirm_reset`.
	var choices: Array[Dictionary] = [
		{"id": "yes", "label": Locale.active.t("ui.menu.abandonRun")},
		{"id": "no", "label": Locale.active.t("ui.menu.keepClimbing"), "quiet": true},
	]
	var screen: Control = ChoiceScreenType.new(
		Locale.active.t("ui.menu.abandonConfirmTitle").to_upper(),
		Locale.active.t("ui.menu.abandonConfirmBody"),
		choices,
		{"shape": String(_shape), "cancel": "no", "overlay": true},
		_sfx_bus)
	screen.connect("chosen", _on_abandon_choice)
	_show_overlay(screen)


func _on_abandon_choice(id: String) -> void:
	if id != "yes":
		_close_overlay()
		return
	game.run.pending_combat = null
	game.run.pending_enemy_ids = null
	game.run.pending_quest_id = null
	game.run.pending_reward = null
	game.run.pending_hollow = null
	game.run.pending_hollow_route = null
	game.run.pending_run_end = {"outcome": "abandon", "bequestAnswered": true}
	if _store_run():
		_show_run_end()
	else:
		_show_save_error("ui.persistence.detail.abandonmentHold")


func _show_run_deck() -> void:
	var choices: Array[Dictionary] = []
	for card: CardInst in game.run.player.deck:
		choices.append(_card_choice(card, "card:%d" % card.uid, true))
	choices.append({"id": "close", "label": Locale.active.t("ui.menu.close"), "quiet": true})
	var deck: Control = ChoiceScreenType.new(
		Locale.active.t("ui.hud.deckOverlayTitle"),
		Locale.active.t("ui.hud.deckOverlayCount", {"count": game.run.player.deck.size()}),
		choices, {"shape": String(_shape), "cancel": "close", "overlay": true},
		_sfx_bus)
	deck.connect("chosen", func(_id: String) -> void: _close_overlay())
	_show_overlay(deck)


func _card_choice(card: CardInst, id: String, disabled: bool = false) -> Dictionary:
	return {
		"id": id,
		"card": card,
		"definition": game.rules.card_data(card),
		"disabled": disabled,
	}


func _show_potion_menu(slot: int) -> void:
	if slot < 0 or slot >= game.run.player.potions.size():
		return
	var id: String = game.run.player.potions[slot]
	if id.is_empty():
		return
	var definition: Dictionary = content.potions.get(id, {})
	# Typed local, not an inline literal — see `_confirm_reset`.
	var choices: Array[Dictionary] = [
		{
			"id": "use",
			"label": Locale.active.t("ui.common.use"),
			"disabled": definition.get("combatOnly", false),
		},
		{"id": "toss", "label": Locale.active.t("ui.hud.tossPotion"), "quiet": true},
		{"id": "close", "label": Locale.active.t("ui.menu.close"), "quiet": true},
	]
	var menu: Control = ChoiceScreenType.new(
		str(definition.get("name", id)),
		str(definition.get("text", "")),
		choices,
		{"shape": String(_shape), "cancel": "close", "overlay": true},
		_sfx_bus)
	menu.connect("chosen", _on_potion_menu_choice.bind(slot))
	_show_overlay(menu)


func _on_potion_menu_choice(action: String, slot: int) -> void:
	if action == "close":
		_close_overlay()
		return
	if action == "toss":
		game.run.player.potions[slot] = ""
	elif not game.rules.use_potion(game.run, null, slot):
		return
	if not SaveService.store(game.run):
		_show_save_error("ui.persistence.detail.phialChoiceHold")
		return
	_close_overlay()
	if _run_hud != null:
		_run_hud.refresh(game.run)


func _show_combat_potion_menu(slot: int) -> void:
	if slot < 0 or slot >= game.run.player.potions.size():
		return
	var id: String = game.run.player.potions[slot]
	if id.is_empty():
		return
	var definition: Dictionary = content.potions.get(id, {})
	var choices: Array[Dictionary] = []
	if definition.get("needsTarget", false):
		for enemy: EnemyCombatant in game.cb.enemies:
			if enemy.hp > 0:
				choices.append({
					"id": "use:%d" % enemy.idx,
					"label": Locale.active.t("ui.hud.usePotionOn", {"name": enemy.name}),
				})
	else:
		choices.append({"id": "use", "label": Locale.active.t("ui.common.use")})
	choices.append({"id": "toss", "label": Locale.active.t("ui.hud.tossPotion"), "quiet": true})
	choices.append({"id": "close", "label": Locale.active.t("ui.menu.close"), "quiet": true})
	var menu: Control = ChoiceScreenType.new(
		str(definition.get("name", id)),
		str(definition.get("text", "")),
		choices,
		{"shape": String(_shape), "cancel": "close"},
		_sfx_bus)
	menu.connect("chosen", _on_combat_potion_choice.bind(slot))
	_show_overlay(menu)


func _on_combat_potion_choice(action: String, slot: int) -> void:
	if action == "close":
		_close_overlay()
		return
	if action == "toss":
		game.run.player.potions[slot] = ""
		_screen.refresh_chrome()
		_close_overlay()
		return
	var target: Variant = int(action.trim_prefix("use:")) \
		if action.begins_with("use:") else null
	if _screen.request_potion(slot, target):
		_close_overlay()


func _on_node_chosen(i: int) -> void:
	if _route_checkpoint_quarantined:
		return
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
	if not _store_run():
		_show_save_error("ui.persistence.detail.chosenWaystoneHold")
		return
	if hollow:
		_show_hollow()
		return
	match n.type:
		"monster", "elite", "boss":
			# The iris covers at the chosen waystone and reveals over the
			# arriving fight (map.js:296). The wipe still fires beneath it,
			# unseen — the benchmark runs both.
			if _map_screen != null:
				_transitions.iris(_map_screen.marker_screen_position())
			_prepare_encounter(n)
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
	if _store_run():
		_route_run()
	else:
		_show_save_error("ui.persistence.detail.clearedWaystoneHold")


func _show_rest() -> void:
	_remember_route(_show_rest)
	var heal_amount: int = rest_heal_amount(game.run.player.max_hp,
		game.rewards.rest_heal_fraction(game.run))
	var can_upgrade: bool = game.run.player.deck.any(func(card: CardInst) -> bool:
		return not card.up and content.cards.get(String(card.id), {}).has("up"))
	var screen: RestScreen = RestScreen.new(
		game.run.player.hp,
		game.run.player.max_hp,
		heal_amount,
		can_upgrade,
		_shape,
		_sfx_bus)
	screen.action_requested.connect(
		func(action: StringName) -> void: _on_rest_choice(String(action)))
	_show_route(screen, true, &"safeNodes")


func _on_rest_choice(id: String) -> void:
	if id == "heal":
		var amount: int = rest_heal_amount(game.run.player.max_hp,
			game.rewards.rest_heal_fraction(game.run))
		game.run.player.hp = mini(game.run.player.max_hp, game.run.player.hp + amount)
		_finish_node()
		return
	var choices: Array[Dictionary] = []
	for card: CardInst in game.run.player.deck:
		var definition: Dictionary = content.cards.get(String(card.id), {})
		if not card.up and definition.has("up"):
			choices.append(_card_choice(card, str(card.uid)))
	if choices.is_empty():
		_finish_node()
		return
	_show_choice(Locale.active.t("ui.rest.temperCardTitle"),
		Locale.active.t("ui.rest.temperCardBody"), choices, _on_rest_upgrade,
		{"overlay": true})


func _on_rest_upgrade(uid_text: String) -> void:
	var uid: int = int(uid_text)
	for card: CardInst in game.run.player.deck:
		if card.uid == uid:
			card.up = true
			break
	_finish_node()


func _show_event() -> void:
	_remember_route(_show_event)
	var event_id: String = str(game.run.quest_scratch.get("eventNode", ""))
	if event_id.is_empty():
		event_id = game.rewards.roll_event(game.run)
		game.run.quest_scratch["eventNode"] = event_id
		if not _store_run():
			_show_save_error("ui.persistence.detail.eventHold")
			return
	var event: Dictionary = content.events[event_id].duplicate(true)
	var rows: Array = event.get("choices", [])
	for row_v: Variant in rows:
		if typeof(row_v) == TYPE_DICTIONARY:
			var row: Dictionary = row_v
			row["disabled"] = game.run.player.gold < int(float(str(
				row.get("needGold", 0))))
	var screen: EventScreen = EventScreen.new(
		event_id, event, "", true, false, _shape, _sfx_bus)
	screen.choice_selected.connect(func(ordinal: int) -> void:
		_on_event_choice(str(ordinal), event_id)
	)
	_show_route(screen, true, &"map")


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
	if _store_run():
		_show_event_pick(pending)
	else:
		_show_save_error("ui.persistence.detail.eventChoiceHold")


func _show_event_pick(pending: Dictionary) -> void:
	var kind: String = str(pending["kind"])
	var choices: Array[Dictionary] = []
	if kind == "card":
		for id_v: Variant in pending.get("cards", []):
			var id: String = str(id_v)
			choices.append(_card_choice(CardInst.new(
				-choices.size() - 1, StringName(id), false), id))
	else:
		for card: CardInst in game.run.player.deck:
			var definition: Dictionary = content.cards.get(String(card.id), {})
			if kind != "upgrade" or (not card.up and definition.has("up")):
				choices.append(_card_choice(card, str(card.uid)))
	if choices.is_empty():
		_finish_node()
		return
	_show_choice(Locale.active.t("ui.event.chooseCardTitle").to_upper(),
		Locale.active.t("ui.event.chooseCardBody"), choices,
		_on_event_pick.bind(kind), {"overlay": true})


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
	_remember_route(_show_treasure)
	var claim_v: Variant = game.run.quest_scratch.get("treasureClaim")
	var claim: Dictionary
	if typeof(claim_v) == TYPE_DICTIONARY:
		claim = claim_v
	else:
		claim = game.rewards.claim_treasure(game.run)
		game.run.quest_scratch["treasureClaim"] = claim
		if not _store_run():
			_show_save_error("ui.persistence.detail.treasureHold")
			return
	var screen: TreasureScreen = TreasureScreen.new(claim, content, _shape, _sfx_bus)
	screen.continue_requested.connect(_finish_node)
	_show_route(screen, true, &"safeNodes")


func _on_sealed_door_requested() -> void:
	# Overlay, not a route: the pilgrimage stays under the ceremony, and closing
	# returns to the map (map.js:127-132). `_show_act4_entrance` remains for
	# saves that still carry the one-node act4 graph.
	var screen: ThresholdScreen = ThresholdScreen.new(_shape, _sfx_bus)
	screen.threshold_touched.connect(_transitions.bloom)
	screen.vigil_requested.connect(_close_sealed_door)
	_sfx_bus.play(&"click")
	_show_overlay(screen)
	_music.play(&"sealedDoor")


func _close_sealed_door() -> void:
	_close_overlay()
	_music.play(&"map")


func _show_act4_entrance() -> void:
	_remember_route(_show_act4_entrance)
	var screen: ThresholdScreen = ThresholdScreen.new(_shape, _sfx_bus)
	screen.threshold_touched.connect(_transitions.bloom)
	screen.vigil_requested.connect(func() -> void: _show_vigil())
	_show_route(screen, false, &"sealedDoor")


func _show_shop() -> void:
	_remember_route(_show_shop)
	var stock_v: Variant = game.run.quest_scratch.get("shopStock")
	var stock: Dictionary
	if typeof(stock_v) == TYPE_DICTIONARY:
		stock = stock_v
	else:
		stock = game.rewards.gen_shop(game.run)
		game.run.quest_scratch["shopStock"] = stock
		if not _store_run():
			_show_save_error("ui.persistence.detail.merchantStockHold")
			return
	var quest_item: Dictionary = game.quests.usurper_offer(game.run)
	var screen: ShopScreen = ShopScreen.new(
		stock,
		game.run.player.gold,
		content,
		quest_item,
		game.run.player.potions.has(""),
		_shape,
		_sfx_bus)
	screen.action_selected.connect(_on_shop_choice)
	_show_route(screen, true, &"safeNodes")


func _refresh_shop() -> void:
	var shop: ShopScreen = _route_screen as ShopScreen
	if shop == null:
		_show_shop()
		return
	var stock: Dictionary = game.run.quest_scratch["shopStock"]
	shop.update(stock, game.run.player.gold,
		game.quests.usurper_offer(game.run),
		game.run.player.potions.has(""))
	if _run_hud != null:
		_run_hud.refresh(game.run)


func _on_shop_choice(id: String) -> void:
	if id == "leave":
		_finish_node()
		return
	if id == "quest:flamelessLantern":
		if game.quests.buy_usurper(game.run) and SaveService.store(game.run):
			_refresh_shop()
		else:
			_show_save_error("ui.persistence.detail.emptyLanternPurchaseHold")
		return
	var stock: Dictionary = game.run.quest_scratch["shopStock"]
	if id == "remove":
		var choices: Array[Dictionary] = []
		for card: CardInst in game.run.player.deck:
			choices.append(_card_choice(card, str(card.uid)))
		_show_choice(Locale.active.t("ui.shop.cardRemoval.pickTitle").to_upper(),
		Locale.active.t("ui.shop.cardRemoval.confirmBody"), choices,
			_on_shop_remove, {"overlay": true})
		return
	var parts: PackedStringArray = id.split(":")
	var category: String = parts[0]
	var rows: Array = stock[category]
	var row: Dictionary = rows[int(parts[1])]
	var price: int = int(float(str(row["price"])))
	if row.get("sold", false) or game.run.player.gold < price:
		_refresh_shop()
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
		_refresh_shop()
	else:
		_show_save_error("ui.persistence.detail.purchaseHold")


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
		_refresh_shop()
	else:
		_show_save_error("ui.persistence.detail.removedCardHold")


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
		_show_save_error("ui.persistence.detail.encounterFreeze")
		return
	_resume_pending_combat()


func _resume_pending_combat() -> void:
	if game.run.pending_quest_id == "ownShade" and _vigil.last_fall != null:
		_vigil.last_fall = null
		if not _store_vigil():
			_show_save_error("ui.persistence.detail.standingBequestClear")
			return
	var enemies: Array[String] = []
	for id_v: Variant in game.run.pending_enemy_ids:
		enemies.append(str(id_v))
	_transitions.wipe()
	# Combat carries its own grain (the world-stop drain rides that material)
	# and its own entrance choreography — one screen reader per frame, and no
	# fade over heroIn.
	_transitions.set_grain(false)
	_clear_route()
	_screen = CombatScreen.new(game, _shape,
		_forced_act if _forced_act >= 0 else game.run.act, _sfx_bus)
	_screen.combat_over.connect(_on_combat_over)
	_screen.result_continue.connect(_on_result_continue)
	_screen.menu_requested.connect(_show_run_menu)
	_screen.potion_requested.connect(_show_combat_potion_menu)
	add_child(_screen)
	var route_kind: String = str(game.run.pending_combat)
	var combat_kind: String = "normal" if route_kind == "monster" else route_kind
	_screen.start_encounter(enemies, combat_kind,
		_combat_encounter_header(route_kind, game.run.act + 1))
	_music.play(_combat_music(route_kind))


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
		# Variants are legal here too — startCombat resolves them the same way
		# the quest route does, and the bench exists to stand up ANY encounter.
		if content.enemies.has(id) or content.variants.has(id):
			known.append(id)
		else:
			# Named, not skipped silently: a typo would otherwise open an empty
			# battlefield and look like the screen was broken.
			push_error("--fight: no enemy '%s' in the slice. Known: %s"
				% [id, ", ".join(content.enemies.keys() + content.variants.keys())])
	if known.is_empty():
		return
	_bench_fight = true
	_transitions.set_grain(false)
	_clear_route()
	_screen = CombatScreen.new(game, _shape, maxi(0, _forced_act), _sfx_bus)
	_screen.combat_over.connect(_on_combat_over)
	_screen.result_continue.connect(_on_result_continue)
	_screen.menu_requested.connect(_show_run_menu)
	_screen.potion_requested.connect(_show_combat_potion_menu)
	add_child(_screen)
	_screen.start_encounter(known, kind, "Bench  ·  %s" % kind.capitalize())
	_music.play(_combat_music(kind))


func _combat_music(kind: String) -> StringName:
	var quest: String = str(game.run.pending_quest_id) \
		if game.run.pending_quest_id != null else ""
	match quest:
		"paleOnes": return &"paleOnes"
		"ownShade": return &"shadeDuel"
		"usurper": return &"usurper"
	if kind != "boss" and game.run.act >= 0 and game.run.act < game.run.omens.size() \
			and game.run.omens[game.run.act] == "eighthOmen":
		return &"eighthOmen"
	if kind == "elite":
		return &"elite"
	var act: int = clampi(game.run.act + 1, 1, 3)
	return StringName("act%dBoss" % act if kind == "boss" \
		else "act%dCombat" % act)


func _on_combat_over(result: String) -> void:
	if _bench_fight:
		_run_over = result != "win"
		_screen.show_result("Victory" if result == "win" else "Defeat",
			"The bench fight is complete.", "Map" if result == "win" else "New Run")
		return
	# The combat leaves fire HERE, above the route swap, so the 900ms bloom and
	# 700ms crack finish over whatever screen arrives — victoryFlow/defeatFlow's
	# own beat, which used to die with the CombatScreen a frame after it played.
	if result == "win":
		_transitions.bloom()
	else:
		_transitions.crack()
	if result != "win":
		game.run.pending_combat = null
		game.run.pending_enemy_ids = null
		game.run.pending_run_end = {"outcome": "death"}
		if not SaveService.store(game.run):
			_show_save_error("ui.persistence.detail.fallHold")
			return
		_route_run()
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
			_show_save_error("ui.persistence.detail.shadeVictoryHold")
			return
		_route_run()
		return
	if node.type == "boss" and game.run.act == 2:
		game.run.pending_run_end = {"outcome": "win"}
		if not SaveService.store(game.run):
			_show_save_error("ui.persistence.detail.finalVictoryHold")
			return
		_route_run()
		return
	var rewards: Dictionary = game.gen_combat_rewards(node.combat_kind(), game.cb.affix)
	var reward_cards: Array = rewards["cards"]
	game.quests.adjust_reward_cards(game.run, node.combat_kind(), reward_cards)
	# D1 (docs/reward-embers-3d-plan.md § cross-lane): the embers concept is
	# painted in the dead enemy's hue over the dead enemy's OWN body, and a
	# reward Dictionary carried neither. Additive field — an old save without
	# it falls back to lantern-ember and the generic husk, which is the plan's
	# own fallback path.
	# The BIGGEST body in the fight is the one the reward wears — enemies[0]
	# is merely the leftmost. Named slain_enemy because run.stats["slain"] is
	# already an integer kill count; one name carrying two types in one save
	# file is a bug that waits.
	var slain_enemy: Dictionary = {}
	if game.cb != null and not game.cb.enemies.is_empty():
		var largest: EnemyCombatant = game.cb.enemies[0]
		for foe: EnemyCombatant in game.cb.enemies:
			if foe.max_hp > largest.max_hp:
				largest = foe
		var slain_art: Dictionary = largest.def.get("art", {})
		slain_enemy = {"id": String(largest.key), "hue": slain_art.get("hue", 22)}
	game.run.pending_reward = {
		"rewards": rewards,
		"taken": {"gold": false, "card": false, "potion": false, "relic": false},
		"slain_enemy": slain_enemy,
	}
	if not SaveService.store(game.run):
		_show_save_error("ui.persistence.detail.victoryRewardsHold")
		return
	_route_run()


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
	_remember_route(_show_pending_reward)
	var pending: Dictionary = game.run.pending_reward
	var rewards: Dictionary = pending["rewards"]
	var taken: Dictionary = pending["taken"]
	var reward_kind: String = _map.current().combat_kind() \
		if _map.current() != null else "normal"
	_transitions.wipe()
	_clear_route()
	_reward_screen = RewardScreen.new(rewards, content,
		reward_kind, false, _shape)
	_reward_screen.claimed.connect(_on_reward_claimed)
	_reward_screen.finished.connect(_on_reward_finished)
	add_child(_reward_screen)
	_transitions.set_grain(true)
	_transitions.screen_in(_reward_screen)
	_attach_run_hud()
	if reward_kind == "boss":
		_music.play(&"victory")
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
		_show_save_error("ui.persistence.detail.claimedRewardHold")


func _show_potion_replace(id: String) -> void:
	var choices: Array[Dictionary] = []
	for slot: int in range(game.run.player.potions.size()):
		var held: String = game.run.player.potions[slot]
		var held_def: Dictionary = content.potions.get(held, {})
		choices.append({
			"id": str(slot),
			"label": Locale.active.t("ui.reward.replacePotion", {
				"name": str(held_def.get("name", held))}),
		})
	choices.append({"id": "discard",
		"label": Locale.active.t("ui.reward.discardNewPhial"), "quiet": true})
	_show_choice(Locale.active.t("ui.reward.phialRackFullTitle"),
		Locale.active.t("ui.reward.phialRackFullBody"), choices,
		_on_potion_replace.bind(id), {"overlay": true})


func _on_potion_replace(choice: String, id: String) -> void:
	if choice != "discard":
		game.run.player.potions[int(choice)] = id
	var pending: Dictionary = game.run.pending_reward
	var taken: Dictionary = pending["taken"]
	taken["potion"] = true
	if SaveService.store(game.run):
		_show_pending_reward()
	else:
		_show_save_error("ui.persistence.detail.phialChoiceHold")


func _on_reward_finished() -> void:
	game.run.pending_reward = null
	_map.clear_current()
	game.run.map = _map.to_dict()
	if SaveService.store(game.run):
		_route_run()
	else:
		_show_save_error("ui.persistence.detail.clearedWaystoneHold")


func _has_pending_boss_relic() -> bool:
	var node: MapNode = _map.current()
	return node != null and node.type == "boss" and _map.is_cleared(_map.at) \
		and game.run.act < 2 and game.run.boss_relic_act != game.run.act


func _show_boss_relic() -> void:
	_remember_route(_show_boss_relic)
	var offer_v: Variant = game.run.quest_scratch.get("bossRelicOffer")
	var offer: Array[String] = []
	if typeof(offer_v) == TYPE_ARRAY:
		for id_v: Variant in offer_v:
			offer.append(str(id_v))
	else:
		offer = game.rewards.roll_boss_relics(game.run)
		game.run.quest_scratch["bossRelicOffer"] = offer.duplicate()
		if not SaveService.store(game.run):
			_show_save_error("ui.persistence.detail.crownRelicsHold")
			return
	var choices: Array[Dictionary] = []
	for id: String in offer:
		var relic: Dictionary = content.relics.get(id, {})
		choices.append({
			"id": id,
			"label": "%s\n%s" % [
				str(relic.get("name", id)),
				str(relic.get("text", "")),
			],
			"hint": str(relic.get("text", "")),
			"icon": "res://assets/art/relics/%s.png" % id,
		})
	choices.append({"id": "", "label": Locale.active.t("ui.reward.bossTakeNone"),
		"quiet": true})
	_show_choice(Locale.active.t("ui.reward.bossCrownTitle"),
		Locale.active.t("ui.reward.bossCrownBody"), choices, _on_boss_relic_chosen)


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
		# The act-change plate rides over the arriving map, concurrent rather
		# than awaited (reward.js:181 fires it on the boss-reward continue).
		var act_name: String = "ACT %d" % (game.run.act + 1)
		if game.run.act < content.acts.size():
			var act_v: Variant = content.acts[game.run.act]
			if typeof(act_v) == TYPE_DICTIONARY:
				var act_d: Dictionary = act_v
				act_name = str(act_d.get("name", act_name))
		var omen_name: String = ""
		var omen_tone: Color = Color.WHITE
		var omen_icon: Texture2D = null
		if game.run.act < game.run.omens.size() \
				and game.run.omens[game.run.act] != null:
			var omen_id: String = str(game.run.omens[game.run.act])
			var omen: Dictionary = content.omens.get(omen_id, {})
			omen_name = str(omen.get("name", ""))
			omen_tone = Color(str(omen.get("tone", "#8b93ad")))
			var icon_path: String = "res://assets/art/omens/%s.png" % omen_id
			if ResourceLoader.exists(icon_path):
				omen_icon = load(icon_path) as Texture2D
		_transitions.act_plate(act_name, omen_name, omen_tone, omen_icon)
	else:
		_show_save_error("ui.persistence.detail.nextActHold")


# ---------------------------------------------------------------- terminal and durable side routes

func _show_run_end() -> void:
	_remember_route(_show_run_end)
	_apply_pending_content_hydration()
	var pending: Dictionary = game.run.pending_run_end
	var outcome: String = str(pending.get("outcome", "abandon"))
	if outcome == "win":
		_on_terminal_commit("commit")
		return
	var stats: Dictionary = _run_end_stats()
	var bequest_answered: bool = pending.get("bequestAnswered", false)
	# No ternary: an untyped `[]` does not convert to Array[Dictionary]
	# through one — it throws at runtime and --check-only cannot see it
	# (issue #58; the ternary variant of the typed-array .new() trap).
	var choices: Array[Dictionary] = []
	if outcome == "death" and not bequest_answered:
		choices = _bequest_choices()
	var screen: RunEndScreen = RunEndScreen.new(
		outcome,
		stats,
		choices,
		bequest_answered,
		game.run.floors_climbed,
		_shape,
		_sfx_bus)
	screen.bequest_requested.connect(_on_bequest_chosen)
	screen.commit_requested.connect(
		func() -> void: _on_terminal_commit("commit"))
	screen.deck_requested.connect(_show_run_deck)
	# Death plays graveReveal + monumentRise itself; abandon keeps screen_in.
	_show_route(screen, false, &"defeat", outcome != "death")


func _run_end_stats() -> Dictionary:
	return {
		"floors": game.run.floors_climbed,
		"slain": int(float(str(game.run.stats.get("slain", 0)))),
		"elites_bosses": int(float(str(game.run.stats.get("elites", 0)))) \
			+ int(float(str(game.run.stats.get("bosses", 0)))),
		"deck_size": game.run.player.deck.size(),
		"damage_dealt": int(float(str(game.run.stats.get("dmgDealt", 0)))),
		"damage_taken": int(float(str(game.run.stats.get("dmgTaken", 0)))),
		"cards_played": int(float(str(game.run.stats.get("cardsPlayed", 0)))),
		"run_time": _run_time_text(),
		"act_name": str(content.acts[clampi(
			game.run.act, 0, content.acts.size() - 1)].get("name", "")),
	}


func _run_time_text() -> String:
	var started: float = float(str(game.run.stats.get("start", 0)))
	if started <= 0.0:
		var stamp: String = game.run.run_id.get_slice("-", 2)
		if stamp.is_valid_hex_number():
			started = float(stamp.hex_to_int()) / 1000.0
	if started <= 0.0:
		return "—"
	var minutes: int = maxi(1, roundi(
		(Time.get_unix_time_from_system() - started) / 60.0))
	return "%dm" % minutes


func _bequest_choices() -> Array[Dictionary]:
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
		var relic_name: String = str(content.relics[best_relic].get(
			"name", best_relic))
		choices.append({"id": "relic:" + best_relic,
			"kind": "relic",
			"name": relic_name,
			"note": Locale.active.t("ui.end.bequestNote.relic"),
			"icon": "res://assets/art/bequests/relic.png",
			"art": "res://assets/art/relics/%s.png" % best_relic})
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
		var card_name: String = "%s%s" % [
			str(definition.get("name", String(best_card.id))),
			"+" if best_card.up else "",
		]
		choices.append({"id": "card:%d" % best_card.uid,
			"kind": "card",
			"name": card_name,
			"note": Locale.active.t("ui.end.bequestNote.card"),
			"icon": "res://assets/art/bequests/card.png",
			"art": "res://assets/art/cards/%s.jpg" % String(best_card.id)})
	if game.run.player.gold >= 25:
		var amount: int = mini(game.run.player.gold, 75)
		choices.append({"id": "gold:%d" % amount,
			"kind": "gold",
			"name": Locale.active.t("ui.end.bequestNote.gold", {"n": amount}),
			"note": Locale.active.t("ui.end.bequestNote.goldCache"),
			"icon": "res://assets/art/bequests/gold.png",
			"art": "res://assets/art/ui/coin.png"})
	return choices


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
		_show_save_error("ui.persistence.detail.bequestHold")


func _on_terminal_commit(_id: String) -> void:
	var pending: Dictionary = game.run.pending_run_end
	var outcome: String = str(pending["outcome"])
	var before_unlocks: Array = _vigil.unlocks.duplicate()
	var before_quests: Dictionary = _vigil.quests.duplicate(true)
	var before_whispers: int = _vigil.whispers
	if not _vigil.commit_run(game.run, outcome, content) or not _store_vigil():
		_show_save_error("ui.persistence.detail.vigilRecord")
		return
	if outcome != "win":
		var run_id: String = game.run.run_id
		if SaveService.clear_run(run_id):
			_vigil = _load_vigil()
			game = null
			_show_title()
		else:
			_show_save_error("ui.persistence.detail.completedRunClose")
		return

	# The kicker already speaks the register ("A JOURNEY REVEALED"), so the
	# title carries the thing the player EARNED — the quest's name, the
	# whisper's words — never the register said twice. The benchmark's cards
	# are built the same way round (end.js:94-121: kicker, then .dawn-name IS
	# the name). The first cut wrote the register into both lines and demoted
	# every name to 11px body text.
	var events: Array = []
	if _vigil.whispers > before_whispers:
		var whisper_index: int = mini(_vigil.whispers, 24) - 1
		events.append({
			"kind": "whisper",
			"title": "",
			"body": Locale.active.whisper(maxi(0, whisper_index)),
		})
	for id: String in content.quest_ids:
		var before: Dictionary = before_quests.get(id, {})
		var after: Dictionary = _vigil.quests.get(id, {})
		var quest: Dictionary = content.quests.get(id, {})
		var name: String = str(quest.get("name", id))
		var before_state: String = str(before.get("state", "dormant"))
		var after_state: String = str(after.get("state", "dormant"))
		var before_progress: int = int(float(str(before.get("progress", 0))))
		var after_progress: int = int(float(str(after.get("progress", 0))))
		if after_state != before_state and after_state in ["armed", "revealed"]:
			events.append({
				"kind": "quest",
				"title": name,
				"body": str(quest.get("inscription", "")),
			})
		if after_progress > before_progress and after_state != "complete":
			var progress_event: Dictionary = {
				"kind": "progress",
				"title": name,
				"body": "",
				# `.dawn-count` (styles.css:2589) — progress lives beside the
				# body, not in it (end.js:105).
				"count": "%d/%d" % [
					after_progress,
					int(float(str(quest.get("target", after_progress)))),
				],
			}
			if id == "unreadablePage":
				progress_event["cue"] = "unreadablePage"
			events.append(progress_event)
	var receipt: Dictionary = _vigil.receipts["runEnd"]
	for id_v: Variant in receipt.get("completed", []):
		var id: String = str(id_v)
		events.append({
			"kind": "shard",
			"title": str(content.quests[id].get("name", id)),
			# `ui.dawn.shardGrantCopy` (i18n/en/ui.js:237).
			"body": Locale.active.t("ui.dawn.shardGrantCopy"),
			"icon": "shard",
		})
	for unlock_v: Variant in _vigil.unlocks:
		var unlock: String = str(unlock_v)
		if not before_unlocks.has(unlock):
			var unlock_event: Dictionary = {
				"kind": "unlock",
				"title": _unlock_dawn_copy(unlock),
				"body": "",
			}
			if unlock == "act4":
				unlock_event["cue"] = "sealedDoor"
				unlock_event["icon"] = "door"
			events.append(unlock_event)
	if events.is_empty():
		events.append({
			"kind": "memory",
			"title": Locale.active.t("ui.dawn.memoryTitle"),
			"body": Locale.active.t("ui.dawn.memoryBody", {"count": _vigil.shards.size()}),
		})
	game.run.pending_run_end = null
	game.run.pending_dawn = {"events": events, "cursor": 0}
	if SaveService.store(game.run):
		_show_dawn()
	else:
		_show_save_error("ui.persistence.detail.dawnHold")


func _unlock_dawn_copy(id: String) -> String:
	match id:
		"lamplighter": return Locale.active.t("ui.dawn.unlock.lamplighter")
		"phials": return Locale.active.t("ui.dawn.unlock.phials")
		"omens": return Locale.active.t("ui.dawn.unlock.omens")
		"poolWave2", "poolWave3", "poolFull":
			return Locale.active.t("ui.dawn.unlock.pool")
		"emberglass": return Locale.active.t("ui.dawn.unlock.emberglass")
		"act4": return Locale.active.t("ui.dawn.unlock.act4")
		_: return id.capitalize()


## Built ONCE; the feed animates in place (DawnScreen, P3.3). The durable
## contract is unchanged — every cursor advance is a persisted save before the
## next memory shows — but the screen now ASKS for each advance instead of the
## route being rebuilt around a 0.72s timer. drainEndQueue's shape exactly
## (end.js:134-151): show, persist, only then the next.
func _show_dawn() -> void:
	_remember_route(_show_dawn)
	var dawn: Dictionary = game.run.pending_dawn
	var events: Array = dawn["events"]
	var cursor: int = int(float(str(dawn.get("cursor", 0))))
	var screen: DawnScreen = DawnScreen.new(events, cursor, _shape, _run_end_stats(), _sfx_bus)
	screen.deck_requested.connect(_show_run_deck)
	screen.commit_requested.connect(_finish_dawn)
	screen.advance_requested.connect(_on_dawn_advance.bind(screen))
	var cue: StringName = &"victory" if cursor == 0 else &""
	if cursor < events.size():
		var event: Dictionary = events[cursor]
		if not str(event.get("cue", "")).is_empty():
			cue = StringName(str(event["cue"]))
	_show_route(screen, false, cue)


func _on_dawn_advance(screen: DawnScreen) -> void:
	if game == null or game.run == null or game.run.pending_dawn == null:
		return
	var dawn: Dictionary = game.run.pending_dawn
	var next: int = int(float(str(dawn.get("cursor", 0)))) + 1
	dawn["cursor"] = next
	if not SaveService.store(game.run):
		_show_save_error("ui.persistence.detail.dawnCursorHold")
		return
	var events: Array = dawn["events"]
	if next < events.size():
		var event: Dictionary = events[next]
		var cue: String = str(event.get("cue", ""))
		if not cue.is_empty():
			_music.play(StringName(cue))
	if is_instance_valid(screen):
		screen.advance_confirmed()


func _finish_dawn() -> void:
	# Belt beside the screen's braces: the commit button is disabled until the
	# feed settles, but a run must never close while memories are still owed —
	# clear_run would erase the cursor a mid-feed kill relies on.
	if game != null and game.run != null and game.run.pending_dawn != null:
		var dawn: Dictionary = game.run.pending_dawn
		var events: Array = dawn.get("events", [])
		if int(float(str(dawn.get("cursor", 0)))) < events.size():
			return
	var run_id: String = game.run.run_id
	if SaveService.clear_run(run_id):
		_vigil = _load_vigil()
		game = null
		_show_title()
	else:
		_show_save_error("ui.persistence.detail.completedRunClose")


func _has_pending_monument() -> bool:
	var node: MapNode = _map.current()
	return node != null and node.type == "monument" and not _map.is_cleared(_map.at)


func _show_monument() -> void:
	_remember_route(_show_monument)
	if typeof(game.run.monument) != TYPE_DICTIONARY:
		_finish_node()
		return
	var monument: Dictionary = game.run.monument
	var bequest_v: Variant = monument.get("bequest")
	var body: String = Locale.active.t("ui.end.monument.body")
	if typeof(bequest_v) == TYPE_DICTIONARY:
		body = Locale.active.t("ui.end.monument.bodyWithBequest")
	_show_choice(Locale.active.t("ui.end.monument.title"), body, [
		{"id": "claim", "label": Locale.active.t("ui.end.monument.claim")},
		{"id": "leave", "label": Locale.active.t("ui.end.monument.leave"), "quiet": true},
	], _on_monument_choice, {"overlay": true})


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
		_show_save_error("ui.persistence.detail.shadeDuelHold")
		return
	_vigil.last_fall = null
	if _store_vigil():
		_resume_pending_combat()
	else:
		_show_save_error("ui.persistence.detail.standingBequestClear")


func _show_hollow() -> void:
	_remember_route(_show_hollow)
	var pending: Dictionary = game.run.pending_hollow
	var meetings: Array = content.quests["hollowLamplighter"].get("meetings", [])
	var step: int = clampi(int(float(str(pending.get("meeting", 0)))), 0, meetings.size() - 1)
	var meeting: Dictionary = meetings[step]
	var screen: HollowScreen = HollowScreen.new(
		pending, meeting, step + 1, meetings.size(), _shape, _sfx_bus)
	screen.action_requested.connect(
		func(action: StringName) -> void: _on_hollow_choice(String(action)))
	_show_route(screen, true, &"hollowLamplighter")


func _on_hollow_choice(id: String) -> void:
	if id == "pay":
		var result: Dictionary = game.quests.pay_hollow_price(game.run)
		if not result.get("ok", false):
			if _route_screen is HollowScreen:
				(_route_screen as HollowScreen).show_error(
					str(result.get("message", "")))
			return
		if not SaveService.store(game.run):
			_show_save_error("ui.persistence.detail.hollowPriceHold")
			return
		_show_hollow()
		return
	_stage_hollow_exit()


func _stage_hollow_exit() -> void:
	var pending: Dictionary = game.run.pending_hollow
	var node: MapNode = _map.current()
	if node == null or node.id != str(pending.get("nodeId")) \
			or node.type != str(pending.get("type")):
		_show_save_error("ui.persistence.detail.heldHollowDestinationUnreadable")
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
	if _store_run():
		if not _dispatch_current_route():
			_show_save_error("ui.persistence.detail.heldHollowDestinationUnreadable")
	else:
		_show_save_error("ui.persistence.detail.hollowDestinationHold")


func _show_lamplighter() -> void:
	_remember_route(_show_lamplighter)
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
			_show_save_error("ui.persistence.detail.lamplighterGiftsHold")
			return
	var aspect: Dictionary = content.aspects[game.run.aspect]
	var boons: Array = offer.get("boons", [])
	var screen: LamplighterScreen = LamplighterScreen.new(
		aspect,
		content.boons,
		content.arts,
		boons,
		game.run.art,
		_shape,
		_sfx_bus)
	screen.confirmed.connect(_on_lamplighter_confirmed)
	_show_route(screen, false, &"map")


func _on_lamplighter_confirmed(boon_id: String, art_id: StringName) -> void:
	var offer: Dictionary = game.run.quest_scratch["lamplighterOffer"]
	if not offer.get("boons", []).has(boon_id) \
			or not content.boons.has(boon_id) \
			or not content.arts.has(String(art_id)):
		return
	game.run.art = art_id
	game.rewards.apply_boon(game.run, boon_id)
	game.run.pending_lamplighter = false
	game.run.quest_scratch.erase("lamplighterOffer")
	if SaveService.store(game.run):
		_show_map()
	else:
		_show_save_error("ui.persistence.detail.lamplighterGiftHold")


## Route kinds are stable mechanics IDs. Only their display parameter crosses
## the frozen catalogue before composition into the encounter header.
static func _combat_encounter_header(route_kind: String, act_number: int) -> String:
	var kind: String = Locale.active.t("ui.combat.encounterKind.%s" % route_kind)
	return Locale.active.t("ui.combat.encounterHeader", {"kind": kind, "act": act_number})
