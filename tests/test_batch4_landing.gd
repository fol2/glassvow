extends RefCounted
## #355: every approved Batch 4 leaf has one home and a consumer; dawn
## archive is idempotent; one event choice shows result then coda once.

const RUN_PATH: String = "user://test_batch4_run_v2.json"
const VIGIL_PATH: String = "user://test_batch4_vigil_v2.json"

const LEAVES: Array[String] = [
	"story.dawn.paleOnes.p1", "story.dawn.paleOnes.p2", "story.dawn.paleOnes.done",
	"story.dawn.ownShade.p1", "story.dawn.ownShade.p2", "story.dawn.ownShade.done",
	"story.dawn.usurper.p1", "story.dawn.usurper.done",
	"story.dawn.eighthOmen.p1", "story.dawn.eighthOmen.done",
	"story.dawn.unreadablePage.p1", "story.dawn.unreadablePage.p2",
	"story.dawn.unreadablePage.p3", "story.dawn.unreadablePage.p4",
	"story.dawn.unreadablePage.done",
	"story.dawn.hollowLamplighter.p1", "story.dawn.hollowLamplighter.p2",
	"story.dawn.hollowLamplighter.p3", "story.dawn.hollowLamplighter.p4",
	"story.dawn.hollowLamplighter.done",
	"story.dawn.pane.1", "story.dawn.pane.2", "story.dawn.pane.3",
	"story.dawn.pane.4", "story.dawn.pane.5",
	"story.unsealing.b1.l1", "story.unsealing.b1.l2", "story.unsealing.b1.l3",
	"story.unsealing.b2.l1", "story.unsealing.b2.l2", "story.unsealing.b2.l3",
	"story.unsealing.b3.l1", "story.unsealing.b3.l2", "story.unsealing.b3.l3",
	"story.unsealing.b3.l4",
	"story.unsealing.b4.l1", "story.unsealing.b4.l2", "story.unsealing.b4.l3",
	"story.unsealing-short.b1.l1",
	"story.act4-entry.b1.l1", "story.act4-entry.b1.l2", "story.act4-entry.b1.l3",
	"story.act4-node1.b1.l1", "story.act4-node1.b1.l2",
	"story.act4-node2.b1.l1", "story.act4-node2.b1.l2",
	"story.act4-node3.b1.l1", "story.act4-node3.b1.l2",
	"story.act4-node4.b1.l1", "story.act4-node4.b1.l2", "story.act4-node4.b1.l3",
	"story.act4-node4.b1.l4", "story.act4-node4.b1.l5",
	"story.act4-node5.b1.l1", "story.act4-node5.b1.l2", "story.act4-node5.b1.l3",
	"story.act4-node5.b1.l4",
	"story.finale.b1.l1", "story.finale.b1.l2", "story.finale.b1.l3",
	"story.finale.b2.l1", "story.finale.b2.l2", "story.finale.b2.l3",
	"story.finale.b2.l4",
	"story.finale-win.b1.l1", "story.finale-win.b1.l2", "story.finale-win.b1.l3",
	"story.finale-loss.b1.l1", "story.finale-loss.b1.l2",
	"story.event-mirror.c0", "story.event-mirror.c1", "story.event-mirror.c2",
	"story.event-mirror.coda",
	"story.event-woundedKnight.c0", "story.event-woundedKnight.c1",
	"story.event-woundedKnight.c2", "story.event-woundedKnight.coda",
	"story.event-library.c0", "story.event-library.c1", "story.event-library.coda",
	"story.event-fleshTrader.c0", "story.event-fleshTrader.c1",
	"story.event-fleshTrader.coda",
	"story.event-forgottenShrine.c0", "story.event-forgottenShrine.c1",
	"story.event-forgottenShrine.c2", "story.event-forgottenShrine.coda",
]


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("batch4: %s" % what)


static func run(fails: Array[String]) -> void:
	_check(fails, LEAVES.size() == 87, "inventory is not 87 leaves (got %d)" % LEAVES.size())
	_inventory(fails)
	_dawn_archive(fails)
	_dawn_feed(fails)
	_event_result_coda(fails)
	_scene_player_hosts(fails)


static func _inventory(fails: Array[String]) -> void:
	var en: Locale = Locale.new(Locale.CODE_EN)
	var zh: Locale = Locale.new(Locale.CODE_ZH_HANT)
	_check(fails, zh.set_language(Locale.CODE_ZH_HANT), "zh-Hant did not load")
	var homes: Dictionary = _homes()
	var seen: Dictionary = {}
	for key: String in LEAVES:
		_check(fails, not seen.has(key), "duplicate inventory id %s" % key)
		seen[key] = true
		_check(fails, homes.has(key), "%s has no consumer" % key)
		var en_text: String = en.t(key)
		var zh_text: String = zh.t(key)
		_check(fails, en_text != key and not en_text.contains("placeholder"),
			"en did not host %s" % key)
		_check(fails, zh_text != key and zh_text != en_text,
			"zh-Hant did not host %s" % key)


static func _homes() -> Dictionary:
	var out: Dictionary = {}
	var loaded: Variant = SceneScript.load_all()
	if typeof(loaded) == TYPE_DICTIONARY:
		var scenes: Dictionary = loaded
		for scene_id: Variant in scenes:
			var found: Variant = scenes[scene_id]
			if not (found is SceneScript):
				continue
			var script: SceneScript = found
			for line: Dictionary in script.lines:
				out[str(line["key"])] = "scene:%s" % str(scene_id)
	for key: String in LEAVES:
		if key.begins_with("story.dawn."):
			out[key] = "dawn"
		elif key.begins_with("story.event-"):
			out[key] = "event"
	return out


static func _dawn_archive(fails: Array[String]) -> void:
	var vigil: VigilState = VigilState.blank()
	var before: Dictionary = vigil.quests.duplicate(true)
	vigil.quests["paleOnes"]["state"] = "revealed"
	vigil.quests["paleOnes"]["progress"] = 1
	var leaves: Array[String] = DawnPassages.earned(before, vigil.quests, 0, 0)
	_check(fails, leaves.has("story.dawn.paleOnes.p1") and leaves.size() == 1,
		"paleOnes progress 1 did not earn p1 alone")
	var fresh: Array[String] = DawnPassages.archive(vigil, leaves)
	_check(fails, fresh == leaves and vigil.dawn_leaves.has("story.dawn.paleOnes.p1"),
		"p1 did not archive")
	var memory: Dictionary = vigil.quests["paleOnes"]["memory"]
	var dawn_v: Variant = memory.get("dawn", [])
	var dawn: Array = dawn_v if typeof(dawn_v) == TYPE_ARRAY else []
	_check(fails, dawn.has("story.dawn.paleOnes.p1"),
		"p1 did not enter quest memory")
	var again: Array[String] = DawnPassages.archive(vigil, DawnPassages.earned(
		vigil.quests, vigil.quests, 0, 0))
	_check(fails, again.is_empty() and vigil.dawn_leaves.size() == 1,
		"re-archive awarded p1 twice")
	var raw: Dictionary = VigilState.blank().to_dict()
	raw.erase("dawnLeaves")
	var old: VigilState = VigilState.from_dict(raw)
	_check(fails, old != null and old.dawn_leaves.is_empty(),
		"a v2 vigil without dawnLeaves did not default")


static func _dawn_feed(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	SaveService.clear(RUN_PATH)
	SaveService.clear_vigil(VIGIL_PATH)
	var run: RunState = RunState.new_run(content, 35501, "run-batch4-dawn")
	run.pending_run_end = {"outcome": "win", "bequestAnswered": true}
	run.quests["paleOnes"]["state"] = "revealed"
	run.quests["paleOnes"]["progress"] = 1
	var main: Main = _main(content)
	main.game = GlassvowGame.new(content, run)
	main._on_terminal_commit("commit")
	var pending_v: Variant = main.game.run.pending_dawn
	_check(fails, typeof(pending_v) == TYPE_DICTIONARY, "dawn feed was not stored")
	if typeof(pending_v) == TYPE_DICTIONARY:
		var pending: Dictionary = pending_v
		var events: Array = pending.get("events", [])
		var p1: String = Locale.active.t("story.dawn.paleOnes.p1")
		var hit: bool = false
		for ev_v: Variant in events:
			if typeof(ev_v) == TYPE_DICTIONARY and str(ev_v.get("body", "")) == p1:
				hit = true
				break
		_check(fails, hit, "dawn feed did not host paleOnes p1")
	_check(fails, main._vigil.dawn_leaves.has("story.dawn.paleOnes.p1"),
		"terminal commit did not archive p1")
	var rose: RoseWindowView = RoseWindowView.new(
		main._vigil.quests, content.quests, 0, [])
	var quest_v: Variant = main._vigil.quests.get("paleOnes", {})
	var quest: Dictionary = quest_v if typeof(quest_v) == TYPE_DICTIONARY else {}
	_check(fails, rose._detail_copy("paleOnes", quest) \
			== Locale.active.t("story.dawn.paleOnes.p1"),
		"rose reread is not the earned p1 leaf")
	rose.free()
	_dispose(main)
	SaveService.clear(RUN_PATH)
	SaveService.clear_vigil(VIGIL_PATH)


static func _event_result_coda(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	SaveService.clear(RUN_PATH)
	var run: RunState = _event_run(content, "library")
	run.player.hp = maxi(1, run.player.max_hp - 20)
	var main: Main = _main(content)
	main._continue_run(run)
	var hp_before: int = main.game.run.player.hp
	main._on_event_choice("1", "library")
	var hp_after: int = main.game.run.player.hp
	_check(fails, hp_after > hp_before, "library rest did not apply once")
	var screen: EventScreen = main._route_screen as EventScreen
	var result: String = Locale.active.t("story.event-library.c1")
	_check(fails, screen != null and screen._completed and screen._result_log == result,
		"library rest did not show the result leaf")
	var loaded: RunState = SaveService.load_run(content, RUN_PATH)
	_dispose(main)
	var resumed: Main = _main(content)
	resumed._continue_run(loaded)
	_check(fails, resumed.game.run.player.hp == hp_after,
		"resume re-applied the library rest")
	var again: EventScreen = resumed._route_screen as EventScreen
	_check(fails, again != null and again._result_log == result,
		"resume dropped the in-progress result")
	resumed._on_event_story_continue()
	var coda_screen: EventScreen = resumed._route_screen as EventScreen
	_check(fails, coda_screen != null
			and coda_screen._result_log == Locale.active.t("story.event-library.coda"),
		"continue did not show the coda once")
	resumed._on_event_story_continue()
	_check(fails, resumed.game.run.player.hp == hp_after,
		"coda continue re-applied the rest")
	_check(fails, not resumed.game.run.quest_scratch.has("eventStory"),
		"finished event retained eventStory")
	_dispose(resumed)
	SaveService.clear(RUN_PATH)


static func _scene_player_hosts(fails: Array[String]) -> void:
	for scene_id: String in ["unsealing", "finale-win", "finale-loss", "act4-entry"]:
		var script: SceneScript = _script(scene_id)
		_check(fails, script != null and script.line_count() > 0,
			"%s did not load for the shared player" % scene_id)
		if script == null:
			continue
		var player: ScenePlayer = ScenePlayer.new(script, 0)
		player.instant = true
		player._ready()
		var line: Label = player.find_child("Line", true, false) as Label
		_check(fails, line != null and line.text \
				== Locale.active.t(str(script.lines[0]["key"])),
			"%s did not render its first line" % scene_id)
		player.free()


static func _script(scene_id: String) -> SceneScript:
	var loaded: Variant = SceneScript.load_all()
	if typeof(loaded) != TYPE_DICTIONARY:
		return null
	var scenes: Dictionary = loaded
	var found: Variant = scenes.get(scene_id)
	return found if found is SceneScript else null


static func _event_run(content: ContentDB, event_id: String) -> RunState:
	var run: RunState = RunState.new_run(content, 35502, "run-batch4-event")
	var map: WorldMap = WorldMap.slice()
	map.at = 3
	map.nodes[3].type = "event"
	run.node_id = map.nodes[3].id
	run.map = map.to_dict()
	run.quest_scratch["eventNode"] = event_id
	return run


static func _main(content: ContentDB) -> Main:
	var main: Main = Main.new()
	main.content = content
	main._run_save_path = RUN_PATH
	main._vigil_save_path = VIGIL_PATH
	main._vigil = VigilState.blank()
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
