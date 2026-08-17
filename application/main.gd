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
## Dev boots (`--fight=` / `--map` / `--enter=` / `--dawn`) skip the opening
## and the L0 departure plant — they construct against the real vigil.
var _opening_suppressed: bool = false
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
## book authors the benchmark's three and exposes the optional fourth seam.
## Map generation is never act-forced.
var _forced_act: int = -1
## --onboard=<id>: production-flow photo bench for first-run hints. Not a
## suppressed boot — scenes_seen gains "opening" in memory so the gate opens.
var _onboard: String = ""
## --settle=SECONDS: extra wait before a `--shot=` capture, so a composition is
## photographed at rest rather than mid-entrance.
var _settle: float = 0.0
## The ceremony layer — wipe, transit leaves, grain — living above every routed
## screen so a leaf started before a route swap finishes over the incoming
## screen. Screens never see it; main fires it around its own route helpers.
var _transitions: TransitionLayer
var _scenes: Dictionary = {}
## Transient Rose Window replay: no cursor, no once-flag.
var _scene_replay: bool = false
var _hints: HintGuide


func _init() -> void:
	# Install the default UI face on the shipping composition root after imported
	# resources exist. Routed screens may refine this theme; unthemed descendants
	# such as RunHud still inherit the same Noto Serif TC default.
	theme = GlassStyle.theme()
	_hints = HintGuide.new()
	_hints.main = self
	add_child(_hints)


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
		_route_idle()


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
	# tools/shot.sh --onboard=map-select --shot=...    (first-run hint stills)
	# tools/shot.sh --scene=opening --cursor=2 --shot=…   (bespoke scene beat)
	# tools/shot.sh --scene=departure --settle=0.7 --shot=…  (L0 linger)
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
	var map_bench: bool = false
	var scene_shot: String = ""
	var scene_cursor: int = 0
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
		elif arg == "--map-bench":
			map_bench = true
		elif arg.begins_with("--onboard="):
			_onboard = arg.trim_prefix("--onboard=")
		elif arg.begins_with("--scene="):
			scene_shot = arg.trim_prefix("--scene=")
		elif arg.begins_with("--cursor="):
			scene_cursor = maxi(0, int(arg.trim_prefix("--cursor=")))
		elif arg.begins_with("--finale-form="):
			# Render-pick switch for the walk beat's two candidate forms
			# (#312): --finale-form=step | hold. Dev capture only.
			FinaleStaging.form = StringName(arg.trim_prefix("--finale-form="))
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
	if map_bench:
		# #233's pan-repaint sweep, hosted here because this is the only launch
		# route a deployed iOS app has: `-s` is silently ignored by the iOS
		# template (measured 2026-08-14, iPad 8), while user args pass through
		# the Info.plist `godot_cmdline` array. Same isolation as the labs — a
		# bench over content, no run, no title behind the timed frames.
		var bench_script: GDScript = load("res://tools/bench_map_scene.gd") as GDScript
		if bench_script == null:
			push_error("map bench did not load")
			get_tree().quit(2)
			return
		var bench_instance: Variant = bench_script.new()
		if not bench_instance is Node:
			push_error("map bench did not instantiate")
			get_tree().quit(2)
			return
		var bench: Node = bench_instance
		add_child(bench)
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
		_continue_run(_load_run())
	elif not scene_shot.is_empty():
		_opening_suppressed = true
		if not _show_scene_shot(scene_shot, scene_cursor):
			get_tree().quit(2)
			return
		if shot_path != "":
			_capture_and_quit(shot_path)
		return
	elif show_dawn_bench:
		# The Dawn ceremony bench: a fresh run handed a representative feed, so
		# the victory beat can be photographed without walking three acts.
		# Same reason --fight= exists (see _start_fight's docblock).
		_opening_suppressed = true
		_new_run()
		game.run.pending_run_end = null
		# The fixture mirrors _on_terminal_commit's event shapes EXACTLY — same
		# kinds, same field layout (title = the earned thing, kicker speaks the
		# register) — so what the bench photographs is what a player sees.
		game.run.pending_dawn = {"events": [
			{"kind": "whisper", "title": "",
				"body": "The road kept none of what you gave it."},
			{"kind": "quest", "title": "The Pale Ones",
				"body": "Three walkers went pale before you. Find what bleached them."},
			{"kind": "progress", "title": "The Pale Ones", "body": "",
				"count": "2/3"},
			{"kind": "shard", "title": "The Shade That Fell",
				"body": "One pane answers.", "icon": "shard"},
			{"kind": "unlock", "title": "New cards and relics join the pilgrimage.",
				"body": ""},
			{"kind": "unlock", "title": "A sealed door opens beyond the crown.",
				"body": "", "icon": "door"},
			{"kind": "memory", "title": "The Vigil Remembers",
				"body": "Victory · 3 shards lit"},
		], "cursor": 0}
		if _store_run():
			_show_dawn()
	elif show_map:
		_opening_suppressed = true
		_new_run()
	elif not fight.is_empty():
		_opening_suppressed = true
		_new_run()
		_start_fight(fight, fight_kind)
	elif enter_node >= 0:
		_opening_suppressed = true
		_new_run()
		if _map_screen == null:
			return
		_map_screen.instant = true  # skip the travel tween, land on the fight
		_map_screen.choose(enter_node)
	elif not _onboard.is_empty():
		_boot_onboard(_onboard)
	else:
		_route_idle()
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


## The whole profile boundary. `_run_save_path` / `_vigil_save_path` are the
## authority — production defaults on a normal boot, the kernel's isolated
## `user://glassvow_dev_*` files once `apply_dev_scenario` repoints them — and
## these six helpers are the only place in this file allowed to name a
## `SaveService` entry point. Every other runtime save, load and clear goes
## through them, so a Scenario can never read or overwrite a real pilgrimage
## and no screen has to know which profile is live.
## `tests/test_profile_isolation.gd` re-censuses this file and fails on any
## `SaveService` call outside these six, or on any one of the six that stops
## handing over its path field.
func _store_run() -> bool:
	return SaveService.store(game.run, _run_save_path)


func _store_vigil() -> bool:
	return SaveService.store_vigil(_vigil, _vigil_save_path)


func _load_run() -> RunState:
	return SaveService.load_run(content, _run_save_path)


func _load_vigil() -> VigilState:
	return SaveService.load_vigil(_vigil_save_path)


## Terminal receipts pass the run id they durably committed; the empty default
## is the "erase everything" door, which has no id to protect.
func _clear_run(expected_run_id: String = "") -> bool:
	return SaveService.clear_run(expected_run_id, _run_save_path)


func _clear_vigil() -> void:
	SaveService.clear_vigil(_vigil_save_path)


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
	if _onboard == "targeting" or _onboard == HintGuide.TARGETING:
		_onboard_arm_target()
		for _j: int in range(30):
			await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(path)
	print("shot saved: " + path)
	get_tree().quit(0)


func _onboard_arm_target() -> void:
	if _screen == null or game == null or game.cb == null:
		return
	for c: CardInst in game.cb.hand:
		var view: CardView = _screen._hand.card_view(c.uid)
		if view == null or view.target_kind != "enemy" or not view.playable:
			continue
		_screen._selected_uid = c.uid
		_screen._activate_selected()
		if _hints != null and _hints.showing() != HintGuide.TARGETING:
			_hints.consider(HintGuide.TARGETING, _screen.first_enemy_anchor())
		return


func _clear_route() -> void:
	# Everything below is about to be freed: drop the whole freeze stack, not
	# one level of it, so no count survives into the next surface.
	_freeze_count = 0
	_thaw_surfaces()
	if _hints != null:
		_hints.hide_callout()
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
	var saved: RunState = _load_run()
	var choices: Array[Dictionary] = []
	if saved != null:
		choices.append({"id": "continue", "label": Locale.active.t("ui.menu.backToRoad")})
	choices.append_array([
		{"id": "begin", "label": Locale.active.t("ui.menu.rekindle")},
		{"id": "vigil", "label": Locale.active.t("ui.menu.theVigil"), "quiet": true},
		{"id": "help", "label": Locale.active.t("ui.menu.howToPlay"), "quiet": true},
		{"id": "settings", "label": Locale.active.t("ui.menu.settings"), "quiet": true},
		{"id": "credits", "label": Locale.active.t("ui.menu.credits"), "quiet": true},
	])
	# Dev-only — ChoiceScreen seats this outside the ceremonial three-tier.
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
		"begin": _begin_rekindle()
		"vigil": _show_vigil()
		"rose": _show_vigil(true)
		"help": _show_help()
		"settings": _show_settings()
		"credits": _show_credits()
		"dev": _show_dev_console()
		"quit": _quit_game()


func _begin_rekindle() -> void:
	# Skip Embark only when the opening is unseen AND the screen would
	# offer nothing (single aspect, vow 0). The skip exists because run 1
	# has no real choice; a legacy v2 profile that never saw the opening
	# but has aspect2 / vow_unlocked > 0 must not be forced onto defaults.
	# Embark then creates the run, and `_plays_opening()` still fires.
	if _vigil.scenes_seen.has("opening") or not _embark_is_zero_choice():
		_show_embark()
	else:
		_on_embark_begin(0, 0)


func _embark_is_zero_choice() -> bool:
	return not _vigil.unlocks.has("aspect2") and _vigil.vow_unlocked <= 0


func _show_embark() -> void:
	_remember_route(_show_embark)
	var saved: bool = _load_run() != null
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
	if _load_run() == null:
		_new_run({"aspect": _embark_aspect, "vow": _embark_vow})
	else:
		_show_choice(Locale.active.t("ui.menu.beginAnew").to_upper(),
			Locale.active.t("ui.menu.beginAnewBody"),
			[{"id": "begin", "label": Locale.active.t("ui.menu.beginAnew")},
				{"id": "back", "label": Locale.active.t("ui.menu.stayOnRoad"), "quiet": true}],
			_on_begin_anew, {"cancel": "back"})


func _on_begin_anew(id: String) -> void:
	if id == "back":
		_show_title()
		return
	var saved: RunState = _load_run()
	if saved == null:
		_new_run({"aspect": _embark_aspect, "vow": _embark_vow})
		return
	game = GlassvowGame.new(content, saved)
	game.run.pending_run_end = {"outcome": "abandon", "bequestAnswered": true}
	if not _vigil.commit_run(game.run, "abandon", content) or not _store_vigil():
		_show_save_error("ui.persistence.detail.currentPilgrimageClose")
		return
	if not _clear_run(game.run.run_id):
		_show_save_error("ui.persistence.detail.currentPilgrimageClear")
		return
	_new_run({"aspect": _embark_aspect, "vow": _embark_vow})


func _show_vigil(open_rose: bool = false) -> void:
	_remember_route(_show_vigil.bind(open_rose))
	var screen: VigilScreen = VigilScreen.new(_vigil, content, _shape, open_rose, _sfx_bus)
	screen.back_requested.connect(_show_title)
	screen.cue_requested.connect(func(cue: StringName) -> void: _music.play(cue))
	screen.replay_requested.connect(_on_unsealing_replay)
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
	_clear_run()
	_clear_vigil()
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
	# Continuations first, same shape as #332's Vigil-scoped Retry: inspect
	# live state, re-hold the write that failed, then resume the owed surface.
	# Generic `_store_run()` → `_route_run()` drops both of these.
	if id == "retry" and _hint_layer_ahead():
		if _store_vigil():
			if _hints != null:
				_hints.on_persist_ok()
		else:
			_show_title()
		return
	if id == "retry" and _vigil.guidance_skipped \
			and not _load_vigil().guidance_skipped:
		if _store_vigil():
			if game != null:
				_route_run()
			else:
				_show_title()
		else:
			_show_title()
		return
	if id == "retry" and game != null and _plays_departure_staging():
		var saved: RunState = _load_run()
		if saved == null or saved.run_id != game.run.run_id:
			if _store_run():
				_show_departure_staging()
			else:
				_show_title()
			return
	if id == "retry" and game != null and _store_run():
		_route_run()
	elif id == "retry" and game == null \
			and typeof(_vigil.pending_scene) == TYPE_DICTIONARY \
			and _store_vigil():
		_show_scene()
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
	if _plays_opening():
		game.run.pending_scene = {"id": "opening", "cursor": 0}
	if _plays_departure_staging():
		PoolBeats.stage(game.run, _vigil, content, PoolBeats.SLOT_HEARTH,
			PoolBeats.KEY_START, PoolBeats.RESUME_MAP)
	if _store_run():
		if _plays_departure_staging():
			_show_departure_staging()
		else:
			_route_run()
	else:
		_show_save_error("ui.persistence.detail.pilgrimageStart")


func _story_flow() -> bool:
	return not _opening_suppressed and not _dev_claimed


func _hint_layer_ahead() -> bool:
	var disk: VigilState = _load_vigil()
	for id: String in _vigil.hints_seen:
		if disk == null or not disk.hints_seen.has(id):
			return true
	if _vigil.guidance_skipped and (disk == null or not disk.guidance_skipped) \
			and _hints != null and not _hints.showing().is_empty():
		return true
	return false


func _plays_opening() -> bool:
	return _story_flow() and not _vigil.scenes_seen.has("opening") \
		and _scene_script("opening") != null


func _plays_departure_staging() -> bool:
	return _story_flow() and _vigil.scenes_seen.has("opening")


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
	if ref.scenario_id == "vigil" or ref.scenario_id == "unsealing-replay":
		# Install the constructed run so no earlier run survives the profile
		# switch; the Vigil is the destination, not a detour from a live run.
		game = GlassvowGame.new(content, run)
		var restored: WorldMap = WorldMap.from_dict(run.map)
		if restored != null:
			_map = restored
		_show_vigil(true)
		return true
	_continue_run(run)
	return true


func _continue_run(saved: RunState) -> void:
	_route_checkpoint_quarantined = false
	if saved == null:
		_route_idle()
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
		_route_idle()
	elif typeof(game.run.pending_scene) == TYPE_DICTIONARY:
		_show_scene()
	elif typeof(game.run.pending_pool) == TYPE_DICTIONARY:
		_show_pending_pool()
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
	_map_screen.before_pick = _on_map_before_pick
	add_child(_map_screen)
	_map_screen.refresh(game.run)
	# --map --act=N: dress scenery only (domain map stays the run's act).
	if _forced_act >= 0:
		_map_screen.set_act_scenery(_forced_act)
	_transitions.set_grain(true)
	_transitions.screen_in(_map_screen)
	_attach_run_hud()
	_music.play(&"map")
	if _hints != null:
		_hints.consider_map(_map_screen)


func _show_run_menu() -> void:
	if _route_screen is ScenePlayer or _route_screen is DepartureStaging:
		return
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
		_route_idle()
	)
	menu.quit_requested.connect(func() -> void:
		_close_overlay()
		_show_choice(Locale.active.t("ui.menu.leaveRoadTitle"),
			Locale.active.t("ui.menu.leaveRoadBody"),
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
		{"id": "no", "label": Locale.active.t("ui.menu.stayOnRoad"), "quiet": true},
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
	game.run.pending_pool = null
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
	if not _store_run():
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


func _on_map_before_pick() -> bool:
	if _hints == null:
		return true
	return _hints.record_dismiss(HintGuide.MAP_SELECT)


func _on_node_chosen(i: int) -> void:
	if _route_checkpoint_quarantined:
		return
	var n: MapNode = _map.nodes[i]
	var was_unlit: bool = n.unlit
	game.run.node_id = n.id
	game.run.waystones_lit = n.row + 1
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
	if _story_flow() and _stage_pool_line(
			PoolBeats.SLOT_WAYSTONE, PoolBeats.waystone_key(n.id),
			PoolBeats.RESUME_NODE):
		if _transitions != null and _transitions.instant:
			PoolBeats.clear_pending(game.run)
			if not _store_run():
				_show_save_error("ui.persistence.detail.chosenWaystoneHold")
				return
		else:
			_show_pending_pool()
			return
	_enter_chosen_node(n)


func _enter_chosen_node(n: MapNode) -> void:
	if _stage_act4_arrival(n):
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


## Act IV node-arrival interstitials (07-scenes §4): 1–3 lines on first
## arrival at each of the five authored waystones, once per Vigil like the
## Lamplighter scenes. A combat node arms its encounter in the same store, so
## a process death mid-scene resumes into the owed fight, never a re-roll.
## Returns true when it took the route over (including the save-error hold).
func _stage_act4_arrival(n: MapNode) -> bool:
	var scene_id: String = _act4_arrival_scene(n)
	if scene_id.is_empty():
		return false
	if n.is_combat():
		_arm_encounter(n)
		if typeof(game.run.pending_enemy_ids) != TYPE_ARRAY:
			return false  # the roll failed closed (#222); no fight to front
	game.run.pending_scene = {"id": scene_id, "cursor": 0}
	if not _store_run():
		game.run.pending_scene = null
		game.run.pending_combat = null
		game.run.pending_enemy_ids = null
		_show_save_error("ui.persistence.detail.sceneHold")
		return true
	_route_run()
	return true


func _act4_arrival_scene(n: MapNode) -> String:
	if not _story_flow() or game == null or game.run == null \
			or game.run.act != 3 or not game.run.is_final_act():
		return ""
	if n.row < 0 or n.row >= WorldMap.ACT4_TYPES.size():
		return ""
	var scene_id: String = "act4-node%d" % (n.row + 1)
	if _vigil.scenes_seen.has(scene_id) or _scene_script(scene_id) == null:
		return ""
	return scene_id


func _finish_node() -> void:
	game.run.pending_hollow_route = null
	_map.clear_current()
	game.run.map = _map.to_dict()
	for key: String in ["eventNode", "eventPending", "eventStory", "eventChoice",
			"shopStock", "treasureClaim"]:
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
	var story_v: Variant = game.run.quest_scratch.get("eventStory")
	if typeof(story_v) == TYPE_DICTIONARY:
		var story: Dictionary = story_v
		var phase: String = str(story.get("phase", "result"))
		var choice: int = int(float(str(story.get("choice", 0))))
		var key: String = _event_story_key(event_id, choice, phase)
		var story_screen: EventScreen = EventScreen.new(
			event_id, event, Locale.active.t(key), false, true, _shape, _sfx_bus)
		story_screen.continue_requested.connect(_on_event_story_continue)
		_show_route(story_screen, true, &"map")
		return
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
	game.run.quest_scratch["eventChoice"] = int(choice_text)
	var ops: Array = choice.get("ops", [])
	var pending: Dictionary = game.rewards.apply_event_ops(game.run, ops)
	if str(pending.get("kind", "")).is_empty():
		_continue_event_after_ops()
		return
	game.run.quest_scratch["eventPending"] = pending
	if _store_event_choice():
		_show_event_pick(pending)


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
		_continue_event_after_ops()
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
	_continue_event_after_ops()


func _event_story_key(event_id: String, choice: int, phase: String) -> String:
	if phase == "coda":
		return "story.event-%s.coda" % event_id
	return "story.event-%s.c%d" % [event_id, choice]


func _event_has_story(event_id: String, choice: int) -> bool:
	var result_key: String = _event_story_key(event_id, choice, "result")
	var coda_key: String = _event_story_key(event_id, choice, "coda")
	return Locale.active.t(result_key) != result_key \
		and Locale.active.t(coda_key) != coda_key


func _continue_event_after_ops() -> void:
	game.run.quest_scratch.erase("eventPending")
	var event_id: String = str(game.run.quest_scratch.get("eventNode", ""))
	var choice: int = int(float(str(game.run.quest_scratch.get("eventChoice", -1))))
	if _event_has_story(event_id, choice):
		_begin_event_story(event_id, choice)
		return
	_finish_node()


func _begin_event_story(event_id: String, choice: int) -> void:
	game.run.quest_scratch["eventStory"] = {
		"id": event_id, "choice": choice, "phase": "result",
	}
	if _store_event_choice():
		_show_event()


func _on_event_story_continue() -> void:
	var story_v: Variant = game.run.quest_scratch.get("eventStory")
	if typeof(story_v) != TYPE_DICTIONARY:
		_finish_node()
		return
	var story: Dictionary = story_v
	if str(story.get("phase", "")) == "result":
		story["phase"] = "coda"
		game.run.quest_scratch["eventStory"] = story
		if _store_event_choice():
			_show_event()
		return
	_finish_node()


func _store_event_choice() -> bool:
	if _store_run():
		return true
	_show_save_error("ui.persistence.detail.eventChoiceHold")
	return false


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
		if _story_flow() and _usurper_hearth_owed() and _stage_pool_line(
				PoolBeats.SLOT_HEARTH, PoolBeats.KEY_USURPER,
				PoolBeats.RESUME_LEAVE):
			if _transitions != null and _transitions.instant:
				PoolBeats.clear_pending(game.run)
				if not _store_run():
					_show_save_error("ui.persistence.detail.emptyLanternPurchaseHold")
					return
			else:
				_show_pending_pool()
				return
		_finish_node()
		return
	if id == "quest:flamelessLantern":
		if game.quests.buy_usurper(game.run) and _store_run():
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
	if _store_run():
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
	if _store_run():
		_refresh_shop()
	else:
		_show_save_error("ui.persistence.detail.removedCardHold")


# ---------------------------------------------------------------- combat

func _arm_encounter(n: MapNode) -> void:
	var enemies: Array[String] = n.enemies.duplicate()
	if enemies.is_empty():
		enemies = game.quests.encounter_override(game.run, n.type, n)
		if enemies.is_empty():
			enemies = game.rewards.roll_encounter(game.run, n.type, n.row, n)
	if enemies.is_empty():
		game.run.pending_combat = null
		game.run.pending_enemy_ids = null
		return
	game.run.pending_combat = n.type
	game.run.pending_enemy_ids = enemies


func _prepare_encounter(n: MapNode) -> void:
	_arm_encounter(n)
	if typeof(game.run.pending_enemy_ids) != TYPE_ARRAY:
		return
	if not _store_run():
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
	_screen.hint_guide = _hints
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
	_screen.hint_guide = _hints
	add_child(_screen)
	_screen.start_encounter(known, kind, "Bench  ·  %s" % kind.capitalize())
	_music.play(_combat_music(kind))


## Production-flow stills of the six first-run hints. Not a suppressed boot:
## the opening gate is satisfied in memory, `_story_flow()` stays true, and
## `--fight=` / `--map` remain hint-free.
func _boot_onboard(id: String) -> void:
	if not _vigil.scenes_seen.has("opening"):
		_vigil.scenes_seen.append("opening")
	if _forced_seed < 0:
		_forced_seed = 32101
	_new_run()
	if _route_screen is DepartureStaging:
		_show_map()
	if id != "map-select" and id != HintGuide.MAP_SELECT \
			and not _vigil.hints_seen.has(HintGuide.MAP_SELECT):
		_vigil.hints_seen.append(HintGuide.MAP_SELECT)
	match id:
		"map-select", HintGuide.MAP_SELECT:
			return
		"drag-play", HintGuide.DRAG_PLAY:
			_onboard_fight(PackedStringArray(["duskfang"]), "normal")
		"targeting", HintGuide.TARGETING:
			if not _vigil.hints_seen.has(HintGuide.DRAG_PLAY):
				_vigil.hints_seen.append(HintGuide.DRAG_PLAY)
			_onboard_fight(PackedStringArray(["sporeling", "sporeling"]), "normal")
		"end-turn", HintGuide.END_TURN:
			if not _vigil.hints_seen.has(HintGuide.DRAG_PLAY):
				_vigil.hints_seen.append(HintGuide.DRAG_PLAY)
			_onboard_fight(PackedStringArray(["duskfang"]), "normal")
			_onboard_spend_energy()
		"intent", HintGuide.INTENT:
			if not _vigil.hints_seen.has(HintGuide.DRAG_PLAY):
				_vigil.hints_seen.append(HintGuide.DRAG_PLAY)
			_onboard_fight(PackedStringArray(["duskfang"]), "normal")
			if _screen != null:
				_screen._on_end_turn_pressed()
		"reward", HintGuide.REWARD:
			_onboard_reward()
		_:
			push_error("--onboard wants map-select|drag-play|targeting|end-turn|intent|reward")


func _onboard_fight(ids: PackedStringArray, kind: String) -> void:
	_transitions.set_grain(false)
	_clear_route()
	_screen = CombatScreen.new(game, _shape, maxi(0, _forced_act), _sfx_bus)
	_screen.seq.instant = true
	_screen.combat_over.connect(_on_combat_over)
	_screen.result_continue.connect(_on_result_continue)
	_screen.menu_requested.connect(_show_run_menu)
	_screen.potion_requested.connect(_show_combat_potion_menu)
	_screen.hint_guide = _hints
	add_child(_screen)
	_screen.start_encounter(ids, kind, "Onboard  ·  %s" % kind.capitalize())


func _onboard_spend_energy() -> void:
	if _screen == null or game == null or game.cb == null:
		return
	# Playing the hand can kill the foe and skip the still. The trigger is
	# exhausted energy; write that state directly.
	game.cb.player.energy = 0
	_screen._sync_all()
	if _hints != null:
		_hints.consider_combat(_screen)


func _onboard_reward() -> void:
	game.run.pending_reward = {
		"rewards": game.gen_combat_rewards("normal", &""),
		"taken": {"gold": false, "card": false, "potion": false, "relic": false},
		"slain_enemy": {},
	}
	_show_pending_reward()


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
	var act: int = clampi(game.run.act + 1, 1, LayoutBook.ACTS)
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
		# A fall at the swap point carries the finale's own epitaph beat
		# (07-scenes §5) ahead of the unchanged RunEndScreen flow — every
		# fall there, not once; the Queue grows by one each time.
		var fall_node: MapNode = _map.current()
		if _story_flow() and fall_node != null and fall_node.type == "boss" \
				and game.run.act == 3 and game.run.is_final_act() \
				and _scene_script("finale-loss") != null:
			game.run.pending_scene = {"id": "finale-loss", "cursor": 0}
		if not _store_run():
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
		if not _store_run():
			_show_save_error("ui.persistence.detail.shadeVictoryHold")
			return
		_route_run()
		return
	if node.type == "boss" and game.run.is_final_act():
		# The swap took the fight (finaleHandoff): the scripted segment and
		# the ascended close play ahead of the terminal commit. A first win
		# plays the full swap then the ascended sequence; a repeat win plays
		# only the short close (07-scenes §5).
		if _story_flow() and game.run.act == 3 \
				and game.cb != null and game.cb.finale_handoff:
			var close_id: String = _finale_close_scene()
			if not close_id.is_empty():
				game.run.pending_scene = {"id": close_id, "cursor": 0}
		game.run.mark_mirrored_road_cleared()
		game.run.pending_run_end = {"outcome": "win"}
		if not _store_run():
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
	if not _store_run():
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
	if _hints != null:
		_hints.consider(HintGuide.REWARD, _reward_screen.callout_anchor())


func _on_reward_claimed(what: StringName, id: String) -> void:
	if _hints != null and not _hints.record_dismiss(HintGuide.REWARD):
		return
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
	if not _store_run():
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
	if _store_run():
		_show_pending_reward()
	else:
		_show_save_error("ui.persistence.detail.phialChoiceHold")


func _on_reward_finished() -> void:
	game.run.pending_reward = null
	_map.clear_current()
	game.run.map = _map.to_dict()
	if _store_run():
		_route_run()
	else:
		_show_save_error("ui.persistence.detail.clearedWaystoneHold")


func _has_pending_boss_relic() -> bool:
	var node: MapNode = _map.current()
	return node != null and node.type == "boss" and _map.is_cleared(_map.at) \
		and not game.run.is_final_act() and game.run.boss_relic_act != game.run.act


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
		if not _store_run():
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
	_map = WorldMap.for_run(game.run, content)
	game.quests.decorate_map(game.run, _map)
	game.run.map = _map.to_dict()
	var crossing: String = _act4_crossing_scene()
	if not crossing.is_empty():
		game.run.pending_scene = {"id": crossing, "cursor": 0}
	if _store_run():
		if not crossing.is_empty():
			# The entry beat IS the arrival ceremony (07-scenes §3+§4); the
			# act plate stays on the sceneless path only.
			_route_run()
			return
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
		game.run.pending_scene = null
		_show_save_error("ui.persistence.detail.nextActHold")


## First win: the full swap segment (the walk beat rides it), which chains
## into the ascended sequence on finish. Repeat win: only the short close.
func _finale_close_scene() -> String:
	if not _vigil.scenes_seen.has("finale") and _scene_script("finale") != null:
		return "finale"
	return "finale-win" if _scene_script("finale-win") != null else ""


## The Act III→IV door crossing (07-scenes §3+§4). The first crossing plays
## the act4-entry beat; every later crossing plays the short door-open beat.
## The short beat degrades to no beat at all when its plate is absent — the
## L0 hearth-plant precedent — and the map's sealed-door ceremony stays the
## shipped rose either way.
func _act4_crossing_scene() -> String:
	if not _story_flow() or game == null or game.run == null or game.run.act != 3:
		return ""
	if not _vigil.scenes_seen.has("act4-entry"):
		return "act4-entry" if _scene_script("act4-entry") != null else ""
	var short_script: SceneScript = _scene_script("unsealing-short")
	if short_script == null:
		return ""
	var art: String = str(short_script.beat_at(0).get("art", ""))
	if art.is_empty() or not ResourceLoader.exists(art):
		return ""
	return "unsealing-short"


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
		game.run.waystones_lit,
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
		"waystones": game.run.waystones_lit,
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
		"row": maxi(0, game.run.waystones_lit - 1),
		"shadeAspect": game.run.aspect,
		"bequest": bequest,
	}
	game.run.quest_scratch["ownShade"] = scratch
	var pending: Dictionary = game.run.pending_run_end
	pending["bequestAnswered"] = true
	if _store_run():
		_show_run_end()
	else:
		_show_save_error("ui.persistence.detail.bequestHold")


func _on_terminal_commit(_id: String) -> void:
	var pending: Dictionary = game.run.pending_run_end
	var outcome: String = str(pending["outcome"])
	var before_unlocks: Array = _vigil.unlocks.duplicate()
	var before_quests: Dictionary = _vigil.quests.duplicate(true)
	var before_shards: int = _vigil.shards.size()
	var before_whispers: int = _vigil.whispers
	var recorded: bool = _vigil.commit_run(game.run, outcome, content)
	var dawn_leaves: Array[String] = []
	if recorded:
		dawn_leaves = DawnPassages.archive(_vigil, DawnPassages.earned(
			before_quests, _vigil.quests, before_shards, _vigil.shards.size()))
	if not recorded or not _store_vigil():
		_show_save_error("ui.persistence.detail.vigilRecord")
		return
	if outcome != "win":
		var run_id: String = game.run.run_id
		if _clear_run(run_id):
			_vigil = _load_vigil()
			game = null
			_route_idle()
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
				"quest": id,
				"title": name,
				"body": str(quest.get("inscription", "")),
			})
		if after_progress > before_progress and after_state != "complete":
			var progress_event: Dictionary = {
				"kind": "progress",
				"quest": id,
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
			"quest": id,
			"title": str(content.quests[id].get("name", id)),
			# `ui.dawn.shardGrantCopy` (i18n/en/ui.js:237).
			"body": Locale.active.t("ui.dawn.shardGrantCopy"),
			"icon": "shard",
		})
	for unlock_v: Variant in _vigil.unlocks:
		var unlock: String = str(unlock_v)
		if not before_unlocks.has(unlock) and unlock != RunState.MIRRORED_ROAD:
			var unlock_event: Dictionary = {
				"kind": "unlock",
				"title": _unlock_dawn_copy(unlock),
				"body": "",
			}
			if unlock == "act4":
				unlock_event["cue"] = "sealedDoor"
				unlock_event["icon"] = "door"
			events.append(unlock_event)
	_fill_dawn_bodies(events, dawn_leaves)
	if events.is_empty():
		events.append({
			"kind": "memory",
			"title": Locale.active.t("ui.dawn.memoryTitle"),
			"body": Locale.active.t("ui.dawn.memoryBody", {"count": _vigil.shards.size()}),
		})
	game.run.pending_run_end = null
	game.run.pending_dawn = {"events": events, "cursor": 0}
	if _store_run():
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


func _fill_dawn_bodies(events: Array, leaves: Array[String]) -> void:
	var used: Dictionary = {}
	for ev_v: Variant in events:
		if typeof(ev_v) != TYPE_DICTIONARY:
			continue
		var ev: Dictionary = ev_v
		var leaf: String = DawnPassages.attach_leaf(
			str(ev.get("quest", "")), str(ev.get("kind", "")), leaves)
		var text: String = _dawn_text(leaf)
		if text.is_empty():
			continue
		ev["body"] = text
		used[leaf] = true
	for leaf: String in leaves:
		if used.has(leaf):
			continue
		var text: String = _dawn_text(leaf)
		if text.is_empty():
			continue
		events.append({
			"kind": "memory",
			"title": _dawn_card_title(leaf),
			"body": text,
		})


func _dawn_text(leaf: String) -> String:
	if leaf.is_empty():
		return ""
	var text: String = Locale.active.t(leaf)
	return "" if text == leaf else text


func _dawn_card_title(leaf: String) -> String:
	if leaf.begins_with("story.dawn.pane."):
		return Locale.active.t("ui.pilgrimage.roseWindow")
	var id: String = DawnPassages.quest_of(leaf)
	if id.is_empty() or not content.quests.has(id):
		return Locale.active.t("ui.dawn.memoryTitle")
	return str(content.quests[id].get("name", id))


## Built ONCE; the feed animates in place (DawnScreen, P3.3). The durable
## contract is unchanged — every cursor advance is a persisted save before the
## next memory shows — but the screen now ASKS for each advance instead of the
## route being rebuilt around a 0.72s timer. drainEndQueue's shape exactly
## (end.js:134-151): show, persist, only then the next.
func _scene_script(scene_id: String) -> SceneScript:
	if _scenes.is_empty():
		var loaded: Variant = SceneScript.load_all()
		if typeof(loaded) == TYPE_DICTIONARY:
			_scenes = loaded
	var found: Variant = _scenes.get(scene_id)
	if found is SceneScript:
		return found
	return null


func _route_idle() -> void:
	# A resumable run owns the route — title Continue is how the player
	# returns to it. Queuing the unsealing here would invert 07-scenes §3
	# when a process death lands between the Vigil fold and pending_dawn:
	# six shards, unseen unsealing, and a run still on disk. Once that run
	# reaches a terminal path, clear_run runs and the next idle fires.
	if _load_run() == null \
			and typeof(_vigil.pending_scene) != TYPE_DICTIONARY \
			and _vigil.shards.size() >= 6 \
			and not _vigil.scenes_seen.has("unsealing") \
			and _scene_script("unsealing") != null:
		_vigil.pending_scene = {"id": "unsealing", "cursor": 0}
		if not _store_vigil():
			_vigil.pending_scene = null
			_show_save_error("ui.persistence.detail.sceneHold")
			return
	if typeof(_vigil.pending_scene) == TYPE_DICTIONARY:
		_show_scene()
	else:
		_show_title()


func _active_pending_scene() -> Variant:
	if game != null and game.run != null and typeof(game.run.pending_scene) == TYPE_DICTIONARY:
		return game.run.pending_scene
	if typeof(_vigil.pending_scene) == TYPE_DICTIONARY:
		return _vigil.pending_scene
	return null


func _on_unsealing_replay() -> void:
	if _vigil.shards.size() < 6 or _scene_script("unsealing") == null:
		return
	_scene_replay = true
	_show_scene()


func _show_departure_staging() -> void:
	_remember_route(_show_departure_staging)
	_apply_pending_content_hydration()
	# Instant skips the ambient plant. The hearth row is already staged on
	# the run; display tests use a non-instant route to read it.
	if _transitions != null and _transitions.instant:
		if typeof(game.run.pending_pool) == TYPE_DICTIONARY:
			PoolBeats.clear_pending(game.run)
			if not _store_run():
				_show_save_error("ui.persistence.detail.pilgrimageStart")
				return
		_route_run()
		return
	var screen: DepartureStaging = DepartureStaging.new()
	screen.line_row = PoolBeats.row_of(content.line_table, game.run)
	screen.finished.connect(_on_pool_finished)
	_show_route(screen, false)


func _stage_pool_line(slot: String, key: String, resume: String) -> bool:
	if game == null or game.run == null:
		return false
	var row: Dictionary = PoolBeats.stage(game.run, _vigil, content, slot, key, resume)
	if row.is_empty():
		return false
	if not _store_run():
		PoolBeats.clear_pending(game.run)
		_show_save_error("ui.persistence.detail.chosenWaystoneHold")
		return false
	return true


func _usurper_hearth_owed() -> bool:
	if game == null or game.run == null:
		return false
	var rec_v: Variant = game.run.quests.get("usurper")
	if typeof(rec_v) != TYPE_DICTIONARY:
		return false
	var rec: Dictionary = rec_v
	return str(rec.get("state", "")) == "revealed" \
		and not game.run.pool_beats.has(PoolBeats.KEY_USURPER)


func _show_pending_pool() -> void:
	if game == null or game.run == null:
		_show_title()
		return
	var pending: Dictionary = PoolBeats.pending_of(game.run)
	if pending.is_empty():
		_route_run()
		return
	if str(pending.get("slot", "")) == PoolBeats.SLOT_HEARTH:
		_show_departure_staging()
		return
	_remember_route(_show_pending_pool)
	_apply_pending_content_hydration()
	var row: Dictionary = PoolBeats.row_of(content.line_table, game.run)
	if row.is_empty():
		_continue_after_pool()
		return
	var screen: ScenePlayer = ScenePlayer.new(
		SceneScript.pool_beat(""), 0, _shape, _sfx_bus, row)
	screen.instant = _transitions != null and _transitions.instant
	screen.advance_requested.connect(_on_pool_advance.bind(screen))
	screen.finished.connect(_on_pool_finished)
	_show_route(screen, false)


func _on_pool_advance(screen: ScenePlayer) -> void:
	if not _store_run():
		_show_save_error("ui.persistence.detail.chosenWaystoneHold")
		return
	if is_instance_valid(screen):
		screen.advance_confirmed()


func _on_pool_finished() -> void:
	_continue_after_pool()


func _continue_after_pool() -> void:
	if game == null or game.run == null:
		_show_title()
		return
	var pending: Dictionary = PoolBeats.pending_of(game.run)
	var resume: String = str(pending.get("resume", PoolBeats.RESUME_MAP))
	PoolBeats.clear_pending(game.run)
	if not _store_run():
		game.run.pending_pool = pending
		_show_save_error("ui.persistence.detail.chosenWaystoneHold")
		return
	match resume:
		PoolBeats.RESUME_LEAVE:
			_finish_node()
		PoolBeats.RESUME_NODE:
			var node: MapNode = _map.current() if _map != null else null
			if node == null:
				_show_map()
			else:
				_enter_chosen_node(node)
		_:
			_route_run()


func _show_scene() -> void:
	_remember_route(_show_scene)
	var script: SceneScript = null
	var cursor: int = 0
	if _scene_replay:
		script = _scene_script("unsealing")
		if script == null:
			_scene_replay = false
			_show_vigil(true)
			return
	else:
		var pending_v: Variant = _active_pending_scene()
		if typeof(pending_v) != TYPE_DICTIONARY:
			if game != null:
				_route_run()
			else:
				_show_title()
			return
		var pending: Dictionary = pending_v
		script = _scene_script(str(pending.get("id", "")))
		if script == null:
			if game != null and game.run != null \
					and typeof(game.run.pending_scene) == TYPE_DICTIONARY:
				game.run.pending_scene = null
			else:
				_vigil.pending_scene = null
			if game != null:
				_route_run()
			else:
				_show_title()
			return
		cursor = int(float(str(pending.get("cursor", 0))))
	var screen: ScenePlayer = ScenePlayer.new(script, cursor, _shape, _sfx_bus)
	screen.instant = _transitions != null and _transitions.instant
	screen.advance_requested.connect(_on_scene_advance.bind(screen))
	screen.finished.connect(_on_scene_finished)
	_show_route(screen, false)


## Capture hook for bespoke beats (`--scene=`). Not ScenePlayer grammar —
## it mounts an already-authored scene at a cursor, or the L0 linger.
func _show_scene_shot(scene_id: String, cursor: int) -> bool:
	if scene_id == "departure":
		var linger: DepartureStaging = DepartureStaging.new()
		linger.instant = false
		_show_route(linger, false, &"", false)
		return true
	var script: SceneScript = _scene_script(scene_id)
	if script == null:
		push_error("unknown scene %s" % scene_id)
		return false
	var screen: ScenePlayer = ScenePlayer.new(
		script, clampi(cursor, 0, script.line_count()), _shape, _sfx_bus)
	screen.instant = true
	_show_route(screen, false, &"", false)
	return true


func _on_scene_advance(screen: ScenePlayer) -> void:
	if _scene_replay:
		if is_instance_valid(screen):
			screen.advance_confirmed()
		return
	var pending_v: Variant = _active_pending_scene()
	if typeof(pending_v) != TYPE_DICTIONARY:
		return
	var pending: Dictionary = pending_v
	pending["cursor"] = int(float(str(pending.get("cursor", 0)))) + 1
	var ok: bool = true
	if game != null and game.run != null and typeof(game.run.pending_scene) == TYPE_DICTIONARY:
		ok = _store_run()
	else:
		ok = _store_vigil()
	if not ok:
		_show_save_error("ui.persistence.detail.sceneCursorHold")
		return
	if is_instance_valid(screen):
		screen.advance_confirmed()


func _on_scene_finished() -> void:
	if _scene_replay:
		_scene_replay = false
		_show_vigil(true)
		return
	var scene_id: String = ""
	var run_pending: bool = game != null and game.run != null \
			and typeof(game.run.pending_scene) == TYPE_DICTIONARY
	if run_pending:
		var pending: Dictionary = game.run.pending_scene
		scene_id = str(pending.get("id", ""))
		game.run.pending_scene = null
	elif typeof(_vigil.pending_scene) == TYPE_DICTIONARY:
		var pending: Dictionary = _vigil.pending_scene
		scene_id = str(pending.get("id", ""))
		_vigil.pending_scene = null
	if not scene_id.is_empty() and not _vigil.scenes_seen.has(scene_id):
		_vigil.scenes_seen.append(scene_id)
	# The swap hands into the ascended sequence (07-scenes §5). Queued before
	# the store below, so the once-flag and the owed next scene land in one
	# write; a kill in between replays the swap, which finishes idempotently.
	if run_pending and scene_id == "finale" \
			and typeof(game.run.pending_run_end) == TYPE_DICTIONARY \
			and str(game.run.pending_run_end.get("outcome", "")) == "win" \
			and _scene_script("finale-win") != null:
		game.run.pending_scene = {"id": "finale-win", "cursor": 0}
	# Vigil first. If the run store then fails or the process dies between
	# them, the once-flag is already on disk and the run still points at the
	# scene; resume replays a scene that finishes idempotently because
	# scenes_seen already holds it. Run-then-Vigil is the harmful order:
	# the disk run says the opening is done while the disk Vigil never
	# recorded it, so the next run replays.
	if not _store_vigil() or (run_pending and not _store_run()):
		_show_save_error("ui.persistence.detail.sceneHold")
		return
	var player: ScenePlayer = _route_screen as ScenePlayer
	if scene_id == "opening" and player != null and player.skipped \
			and not _vigil.guidance_skipped:
		_show_skip_guidance_offer()
		return
	if game != null:
		_route_run()
	else:
		_show_title()


func _show_skip_guidance_offer() -> void:
	_show_choice(Locale.active.t("ui.scene.skipGuidance.title"), "",
		[{"id": "skip", "label": Locale.active.t("ui.scene.skipGuidance.skip")},
			{"id": "keep", "label": Locale.active.t("ui.scene.skipGuidance.keep"),
				"quiet": true}],
		_on_skip_guidance_choice)


func _on_skip_guidance_choice(id: String) -> void:
	if id == "skip":
		_vigil.guidance_skipped = true
		if not _store_vigil():
			_show_save_error("ui.persistence.detail.sceneHold")
			return
	if game != null:
		_route_run()
	else:
		_show_title()


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
	if not _store_run():
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
	if _clear_run(run_id):
		_vigil = _load_vigil()
		game = null
		_route_idle()
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
	if not _store_run():
		_show_save_error("ui.persistence.detail.shadeDuelHold")
		return
	_vigil.last_fall = null
	if _store_vigil():
		_resume_pending_combat()
	else:
		_show_save_error("ui.persistence.detail.standingBequestClear")


func _lamplighter_scene_id(meeting: int, phase: String) -> String:
	return "lamplighter-m%d-%s" % [meeting + 1, phase]


func _show_hollow() -> void:
	var pending: Dictionary = game.run.pending_hollow
	var meetings: Array = content.quests["hollowLamplighter"].get("meetings", [])
	var step: int = clampi(int(float(str(pending.get("meeting", 0)))), 0, meetings.size() - 1)
	var pre_id: String = _lamplighter_scene_id(step, "pre")
	if not _vigil.scenes_seen.has(pre_id) and _scene_script(pre_id) != null:
		if typeof(game.run.pending_scene) != TYPE_DICTIONARY:
			game.run.pending_scene = {"id": pre_id, "cursor": 0}
			if not _store_run():
				game.run.pending_scene = null
				_show_save_error("ui.persistence.detail.sceneHold")
				return
		_show_scene()
		return
	_remember_route(_show_hollow)
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
		if not _store_run():
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
	var meetings: Array = content.quests["hollowLamplighter"].get("meetings", [])
	var step: int = clampi(int(float(str(pending.get("meeting", 0)))), 0, meetings.size() - 1)
	var post_id: String = _lamplighter_scene_id(step, "post")
	var play_post: bool = pending.get("paid", false) \
		and not _vigil.scenes_seen.has(post_id) \
		and _scene_script(post_id) != null
	if play_post and typeof(game.run.pending_scene) != TYPE_DICTIONARY:
		game.run.pending_scene = {"id": post_id, "cursor": 0}
	game.run.pending_hollow = null
	if node.is_combat():
		if play_post:
			_arm_encounter(node)
			if not _store_run():
				_show_save_error("ui.persistence.detail.encounterFreeze")
				return
			_show_scene()
			return
		_prepare_encounter(node)
		return
	var event_id: Variant = game.rewards.roll_event(game.run) if node.type == "event" else null
	game.run.pending_hollow_route = {
		"nodeId": node.id, "type": node.type, "eventId": event_id,
	}
	if event_id != null:
		game.run.quest_scratch["eventNode"] = event_id
	if _store_run():
		if play_post:
			_show_scene()
		elif not _dispatch_current_route():
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
		if not _store_run():
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
	if _store_run():
		_show_map()
	else:
		_show_save_error("ui.persistence.detail.lamplighterGiftHold")


## Route kinds are stable mechanics IDs. Only their display parameter crosses
## the frozen catalogue before composition into the encounter header.
static func _combat_encounter_header(route_kind: String, act_number: int) -> String:
	var kind: String = Locale.active.t("ui.combat.encounterKind.%s" % route_kind)
	return Locale.active.t("ui.combat.encounterHeader", {"kind": kind, "act": act_number})
