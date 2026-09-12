extends RefCounted
## #329 gate: every runtime save, load and clear in Main obeys the active
## profile, so a Development Scenario can never read or overwrite a real
## pilgrimage.
##
## Three legs, because no single one is sufficient. The census fails on any
## new default-path `SaveService` site in `application/main.gd` — that is the
## mutation gate, and it fires whichever helper is bypassed. The boundary leg
## keeps `presentation/` from calling `SaveService` or reading Main's path
## fields. The live leg boots a named Development Scenario over deliberately
## poisoned production sentinels and proves the exercises left them
## byte-identical, which is the part a source scan cannot claim.

const MAIN_PATH: String = "res://application/main.gd"
const PRESENTATION_ROOT: String = "res://presentation"
const RUN_PATH: String = "user://test_profile_isolation_run_v2.json"
const VIGIL_PATH: String = "user://test_profile_isolation_vigil_v2.json"
const REF_PATH: String = "user://test_profile_isolation_scenario.json"
const SCENARIO_ID: String = "title-continue"
const SCENARIO_SEED: int = 18501
const SENTINEL_RUN_ID: String = "run-sentinel-329"
const SENTINEL_SCENE: String = "sentinel-329"
## Where a developer's real save waits while the sentinels stand in for it.
const STASH_SUFFIX: String = ".pretest"
const BUILD: String = "test-profile-isolation-sha"
const MapCompose: GDScript = preload("res://tests/test_map_compose.gd")

## The only functions in `application/main.gd` allowed to name `SaveService`,
## each mapped to the active-path field it must hand over. A helper that stops
## passing its field is as broken as a call site that never used one.
const HELPERS: Dictionary = {
	"_store_run": "_run_save_path",
	"_store_vigil": "_vigil_save_path",
	"_load_run": "_run_save_path",
	"_load_vigil": "_vigil_save_path",
	"_clear_run": "_run_save_path",
	"_clear_vigil": "_vigil_save_path",
}
## File scope names the production defaults once each — that is what "active
## path" defaults TO, and removing it would leave the fields untyped garbage.
const SCOPE_TOKENS: PackedStringArray = [
	"SaveService.RUN_PATH", "SaveService.VIGIL_PATH",
]


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("profile_isolation: %s" % what)


static func run(fails: Array[String]) -> void:
	# `test_opening_flow.run()`'s convention, and it earns its place twice over
	# here: this is the only suite that stands sentinels in for BOTH production
	# files, so the end-to-end comparison is what proves they came back.
	var run_before: String = _digest(SaveService.RUN_PATH)
	var vigil_before: String = _digest(SaveService.VIGIL_PATH)
	_census(fails)
	_presentation_boundary(fails)
	_live_isolation(fails)
	_check(fails, _digest(SaveService.RUN_PATH) == run_before,
		"the production run was not restored byte-for-byte")
	_check(fails, _digest(SaveService.VIGIL_PATH) == vigil_before,
		"the production Vigil was not restored byte-for-byte")


# ------------------------------------------------------------------- census

## The mutation gate. Reintroducing `SaveService.store(game.run)` anywhere in
## Main names a function that is not a helper and fails here with its line.
static func _census(fails: Array[String]) -> void:
	var lines: PackedStringArray = FileAccess.get_file_as_string(MAIN_PATH).split("\n")
	var current: String = ""
	var covered: Dictionary = {}
	for i: int in range(lines.size()):
		var line: String = lines[i]
		if line.begins_with("func ") or line.begins_with("static func "):
			current = _func_name(line)
		var bare: String = line.strip_edges()
		if bare.begins_with("#") or bare.find("SaveService.") < 0:
			continue
		var where: String = "main.gd:%d" % (i + 1)
		if current.is_empty():
			_check(fails, _any_token(line, SCOPE_TOKENS),
				"%s names SaveService at file scope outside the path defaults" % where)
			continue
		if not HELPERS.has(current):
			fails.append(
				"profile_isolation: %s in %s() bypasses the active profile — route it through a helper"
				% [where, current])
			continue
		var field: String = str(HELPERS[current])
		_check(fails, line.find(field) >= 0,
			"%s: helper %s() no longer passes %s" % [where, current, field])
		covered[current] = true
	for name_v: Variant in HELPERS.keys():
		var name: String = str(name_v)
		_check(fails, covered.has(name),
			"helper %s() is gone or no longer reaches SaveService" % name)


## Rule 5 of the ticket, stated as narrowly as it is actually enforced: no
## script under `presentation/` may call `SaveService` or read Main's path
## fields. `HintGuide` used to read `main._vigil_save_path`.
##
## This is NOT "presentation never picks a profile file" — `presentation/dev/
## console.gd` reaches the isolated files through `ScenarioKernel.clear_profile()`
## without consulting Main at all, which is fine for dev-only UI but is outside
## what these three tokens can see.
static func _presentation_boundary(fails: Array[String]) -> void:
	for path: String in _scripts_under(PRESENTATION_ROOT):
		var source: String = FileAccess.get_file_as_string(path)
		for token: String in ["SaveService.", "_run_save_path", "_vigil_save_path"]:
			_check(fails, source.find(token) < 0,
				"%s names %s — presentation must not pick the profile file" % [path, token])


# -------------------------------------------------------------- live profile

static func _live_isolation(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	# The production pair has to hold sentinels for the exercises to be worth
	# anything, and this suite shares `user://` with the real game — so a
	# developer's own save is moved ASIDE rather than overwritten. Rename is
	# atomic and leaves the file whole: kill the process anywhere below and the
	# real save is sitting at `<path>.pretest`, recoverable by hand. The
	# in-memory copy this replaced could not survive a crash, and its restore
	# truncated the target before writing.
	var run_stashed: bool = _stash(SaveService.RUN_PATH)
	var vigil_stashed: bool = _stash(SaveService.VIGIL_PATH)
	if not _poison_production(content, fails):
		_unstash(SaveService.RUN_PATH, run_stashed, fails)
		_unstash(SaveService.VIGIL_PATH, vigil_stashed, fails)
		return
	var run_mark: String = _digest(SaveService.RUN_PATH)
	var vigil_mark: String = _digest(SaveService.VIGIL_PATH)
	var before: Dictionary = _user_digests()

	var kernel: ScenarioKernel = ScenarioKernel.new(content, RUN_PATH, VIGIL_PATH, REF_PATH)
	kernel.clear_profile()
	var scenario: RunState = kernel.construct(_reference())
	if scenario == null:
		_check(fails, false, "named Scenario %s did not construct: %s"
			% [SCENARIO_ID, kernel.last_error])
	else:
		_exercise(content, kernel, scenario.run_id, run_mark, vigil_mark, fails)

	for name_v: Variant in _changed(before, _user_digests()):
		var name: String = str(name_v)
		_check(fails, false, "user://%s changed outside the development profile" % name)
	_check(fails, _digest(SaveService.RUN_PATH) == run_mark,
		"the production run sentinel was rewritten")
	_check(fails, _digest(SaveService.VIGIL_PATH) == vigil_mark,
		"the production Vigil sentinel was rewritten")
	kernel.clear_profile()
	_unstash(SaveService.RUN_PATH, run_stashed, fails)
	_unstash(SaveService.VIGIL_PATH, vigil_stashed, fails)


## Every runtime shape the ticket names, in one profile, each followed by a
## sentinel re-check so the failure points at the exercise that leaked.
static func _exercise(
	content: ContentDB, kernel: ScenarioKernel, scenario_run_id: String,
	run_mark: String, vigil_mark: String, fails: Array[String]
) -> void:
	var main: Main = _main(content, kernel)

	# Load. A bypass here would answer with the production sentinel instead.
	main._show_title()
	var seen: RunState = main._load_run()
	_check(fails, seen != null and seen.run_id == scenario_run_id,
		"the title load did not read the development checkpoint")
	_check(fails, seen == null or seen.run_id != SENTINEL_RUN_ID,
		"the title load read the production save")
	_intact(run_mark, vigil_mark, "load", fails)

	# In-run store, through the Retry continuation that re-holds a live run.
	main.game = GlassvowGame.new(content, seen)
	main._map = WorldMap.from_dict(main.game.run.map)
	main.game.run.player.gold = 4329
	main._on_save_error_choice("retry")
	var retried: RunState = main._load_run()
	_check(fails, retried != null and retried.player.gold == 4329,
		"Retry did not persist the in-run change to the development profile")
	_intact(run_mark, vigil_mark, "in-run store", fails)

	# Begin Anew: a load, a Vigil store, a run clear and a fresh store in one
	# handler — and the load is load-bypass-sensitive, because the clear that
	# follows it checks the run id it just read against the file on disk.
	main._on_begin_anew("begin")
	var fresh: RunState = main._load_run()
	_check(fails, main.game != null and main.game.run.run_id != scenario_run_id
			and main.game.run.run_id != SENTINEL_RUN_ID,
		"Begin Anew did not replace the development run")
	_check(fails, fresh != null and main.game != null
			and fresh.run_id == main.game.run.run_id,
		"the Begin Anew run did not land in the development profile")
	_intact(run_mark, vigil_mark, "begin anew", fails)

	# Terminal receipt: Vigil store, then the run clear that follows a loss.
	var dev_vigil_before: String = _digest(kernel.vigil_path)
	main.game.run.pending_run_end = {"outcome": "abandon", "bequestAnswered": true}
	main._on_terminal_commit("")
	_check(fails, not FileAccess.file_exists(kernel.run_path),
		"the terminal clear left the development run behind")
	_check(fails, _digest(kernel.vigil_path) != dev_vigil_before,
		"the terminal receipt did not record in the development Vigil")
	_intact(run_mark, vigil_mark, "terminal commit", fails)
	_dispose(main)

	# Erase everything — and be exact about what was wrong here, because the
	# shape of it is stranger than "both files were production". Until #329 the
	# door was `SaveService.clear()` (production run, always) plus
	# `clear_vigil(_vigil_save_path)` (active Vigil, correct since a74f2a5c).
	# So with a Scenario live it deleted the player's REAL run while clearing
	# the DEVELOPMENT Vigil, and `_show_title()` then re-read the dev run and
	# still offered Continue for the pilgrimage the door claimed to erase.
	# Only the run assertion below carries that regression: the Vigil one would
	# have passed before #329 too, and is here to keep the halves independent.
	var again: RunState = kernel.construct(_reference())
	_check(fails, again != null, "the Scenario did not rebuild for the erase door")
	if again != null:
		var eraser: Main = _main(content, kernel)
		eraser.game = GlassvowGame.new(content, again)
		eraser._map = WorldMap.from_dict(again.map)
		eraser._on_reset_choice("yes")
		_check(fails, not FileAccess.file_exists(kernel.run_path),
			"erase everything spared the development run")
		_check(fails, not FileAccess.file_exists(kernel.vigil_path),
			"erase everything spared the development Vigil")
		_intact(run_mark, vigil_mark, "erase everything", fails)
		_dispose(eraser)


static func _intact(
	run_mark: String, vigil_mark: String, tag: String, fails: Array[String]
) -> void:
	_check(fails, _digest(SaveService.RUN_PATH) == run_mark,
		"%s changed the production run sentinel" % tag)
	_check(fails, _digest(SaveService.VIGIL_PATH) == vigil_mark,
		"%s changed the production Vigil sentinel" % tag)


## Distinguishable, not merely present: a bypassed load answers with this run
## id, and a bypassed store or clear moves these bytes.
static func _poison_production(content: ContentDB, fails: Array[String]) -> bool:
	var run: RunState = RunState.new_run(content, 3290329, SENTINEL_RUN_ID)
	run.map = WorldMap.benchmark(run).to_dict()
	var vigil: VigilState = VigilState.blank()
	vigil.scenes_seen.append(SENTINEL_SCENE)
	var ok: bool = SaveService.store(run, SaveService.RUN_PATH) \
		and SaveService.store_vigil(vigil, SaveService.VIGIL_PATH)
	_check(fails, ok, "could not seed the production sentinels")
	return ok


static func _reference() -> ScenarioReference:
	var ref: ScenarioReference = ScenarioReference.new()
	ref.load_from({
		"id": SCENARIO_ID,
		"revision": 1,
		"build": BUILD,
		"seed": SCENARIO_SEED,
		"shape": "pad-landscape",
		"overrides": {"act": 0, "gold": 40, "add_cards": ["cleave"]},
	})
	return ref


## The Scenario boot's own installation, minus its screens: `apply_dev_scenario`
## adopts `kernel.run_path` / `kernel.vigil_path` and marks the launch claimed.
static func _main(content: ContentDB, kernel: ScenarioKernel) -> Main:
	Locale.active = Locale.new(Locale.CODE_EN)
	var main: Main = Main.new()
	main._map_layout_compile = MapCompose.fake_layout_compile()
	main.content = content
	main._dev_claimed = true
	main._forced_seed = 32900
	main._run_save_path = kernel.run_path
	main._vigil_save_path = kernel.vigil_path
	main._vigil = main._load_vigil()
	main._transitions = TransitionLayer.new()
	main._transitions.instant = true
	main.add_child(main._transitions)
	main._music = MusicBus.new()
	main.add_child(main._music)
	main._sfx_bus = SfxBus.new()
	main.add_child(main._sfx_bus)
	return main


static func _dispose(main: Main) -> void:
	main._clear_route()
	for child: Node in main.get_children():
		child.free()
	main.free()


# ------------------------------------------------------------------ file IO

static func _digest(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return "%s:%d" % [FileAccess.get_sha256(path), FileAccess.get_file_as_bytes(path).size()]


## Flat scan: the saves live at the top of `user://`, and a default-path leak
## would land there beside them.
static func _user_digests() -> Dictionary:
	var out: Dictionary = {}
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		return out
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while not name.is_empty():
		if not dir.current_is_dir():
			out[name] = _digest("user://%s" % name)
		name = dir.get_next()
	dir.list_dir_end()
	return out


static func _changed(before: Dictionary, after: Dictionary) -> Array[String]:
	var owned: PackedStringArray = [
		RUN_PATH.get_file(), VIGIL_PATH.get_file(), REF_PATH.get_file(),
	]
	var out: Array[String] = []
	var names: Dictionary = {}
	for key_v: Variant in before.keys():
		names[str(key_v)] = true
	for key_v: Variant in after.keys():
		names[str(key_v)] = true
	for name_v: Variant in names.keys():
		var name: String = str(name_v)
		if owned.has(name):
			continue
		if str(before.get(name, "")) != str(after.get(name, "")):
			out.append(name)
	out.sort()
	return out


## Move a real save out of the way, atomically. Answers whether there was one.
static func _stash(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	return DirAccess.rename_absolute(
		ProjectSettings.globalize_path(path),
		ProjectSettings.globalize_path(path + STASH_SUFFIX)) == OK


## Drop the sentinel this test wrote, then put the real save back. Restoration
## failure is a test failure — silently leaving a developer's save in the stash
## is how you find out about it a week later.
static func _unstash(path: String, stashed: bool, fails: Array[String]) -> void:
	SaveService.clear(path)
	if not stashed:
		return
	_check(fails, DirAccess.rename_absolute(
			ProjectSettings.globalize_path(path + STASH_SUFFIX),
			ProjectSettings.globalize_path(path)) == OK,
		"could not restore %s from its stash — the real save is still at %s"
			% [path, path + STASH_SUFFIX])


# ------------------------------------------------------------------- parsing

static func _func_name(line: String) -> String:
	var head: String = line.trim_prefix("static ").trim_prefix("func ")
	var open: int = head.find("(")
	return head.substr(0, open) if open > 0 else ""


static func _any_token(line: String, tokens: PackedStringArray) -> bool:
	for token: String in tokens:
		if line.find(token) >= 0:
			return true
	return false


static func _scripts_under(root: String) -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open(root)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while not name.is_empty():
		var path: String = "%s/%s" % [root, name]
		if dir.current_is_dir():
			out.append_array(_scripts_under(path))
		elif name.ends_with(".gd"):
			out.append(path)
		name = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out
