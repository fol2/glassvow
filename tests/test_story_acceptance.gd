extends RefCounted
## #356 story-complete acceptance: Phase 1 inventory plus bilingual journeys
## A–F on the production hosts. Isolated save paths; production pair is
## snapshotted and must return byte-identical.

const RUN_PATH: String = "user://test_story_acceptance_run_v2.json"
const VIGIL_PATH: String = "user://test_story_acceptance_vigil_v2.json"
const DEV_RUN: String = "user://test_story_acceptance_dev_run_v2.json"
const DEV_VIGIL: String = "user://test_story_acceptance_dev_vigil_v2.json"
const DEV_REF: String = "user://test_story_acceptance_dev_scenario.json"
const BUILD: String = "test-356-sha"
const LOCALES: Array[StringName] = [Locale.CODE_EN, Locale.CODE_ZH_HANT]
const ACT4_SCENES: PackedStringArray = [
	"act4-node1", "act4-node2", "act4-node3", "act4-node4", "act4-node5",
]


static func _act4_enemies(index: int) -> PackedStringArray:
	match index:
		0:
			return PackedStringArray(["unopenedSelf"])
		1:
			return PackedStringArray(["unobsidianSelf", "unwalkedSelf"])
		2:
			return PackedStringArray(["uncrossedSelf", "unsunkSelf"])
		4:
			return PackedStringArray(["eternalKeeper"])
		_:
			return PackedStringArray()


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("story_gate: %s" % what)


static func run(fails: Array[String]) -> void:
	var prod_run: Variant = _file_snapshot(SaveService.RUN_PATH)
	var prod_vigil: Variant = _file_snapshot(SaveService.VIGIL_PATH)
	var previous: Locale = Locale.active
	var content: ContentDB = ContentDB.load_full()
	_inventory(content, fails)
	for code: StringName in LOCALES:
		var loc: Locale = Locale.new(code)
		_check(fails, loc.code == code, "%s catalogue did not load" % code)
		if loc.code != code:
			continue
		Locale.active = loc
		loc.hydrate_content(content)
		_journey_a(content, code, fails)
		_journey_b(content, code, fails)
		_journey_c(content, code, fails)
		_journey_d(content, code, fails)
		_journey_e(content, code, fails)
		_journey_f(content, code, fails)
		loc.restore_content()
	_isolation(content, fails)
	Locale.active = previous
	_check(fails, _same_snap(_file_snapshot(SaveService.RUN_PATH), prod_run),
		"production run was not restored byte-for-byte")
	_check(fails, _same_snap(_file_snapshot(SaveService.VIGIL_PATH), prod_vigil),
		"production Vigil was not restored byte-for-byte")
	SaveService.clear(RUN_PATH)
	SaveService.clear_vigil(VIGIL_PATH)
	SaveService.clear(DEV_RUN)
	SaveService.clear_vigil(DEV_VIGIL)
	if FileAccess.file_exists(DEV_REF):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DEV_REF))


static func _inventory(content: ContentDB, fails: Array[String]) -> void:
	var en: Dictionary = _flatten_story(Locale.CODE_EN)
	var zh: Dictionary = _flatten_story(Locale.CODE_ZH_HANT)
	_check(fails, en.size() == 122 and zh.size() == 122,
		"story.* census is not 122/122 (en=%d zh=%d)" % [en.size(), zh.size()])
	var homes: Dictionary = _scene_homes()
	var seen: Dictionary = {}
	for key_v: Variant in en.keys():
		var key: String = str(key_v)
		_check(fails, not seen.has(key), "duplicate story id %s" % key)
		seen[key] = true
		_check(fails, zh.has(key), "zh-Hant missing %s" % key)
		var host: String = _host_of(key, homes)
		_check(fails, not host.is_empty(), "%s has no runtime host" % key)
		_check(fails, str(en[key]) != key and not str(en[key]).is_empty(),
			"en did not host %s" % key)
		_check(fails, str(zh.get(key, key)) != key
				and str(zh.get(key, "")) != str(en[key]),
			"zh-Hant did not host %s" % key)
	for key_v: Variant in homes.keys():
		var used: String = str(key_v)
		_check(fails, en.has(used), "scene key %s is not a story.* leaf" % used)
	var hearth_n: int = 0
	var waystone_n: int = 0
	var loss_n: int = 0
	for row_v: Variant in content.line_table:
		if typeof(row_v) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_v
		var id: String = str(row.get("id", ""))
		_check(fails, not id.is_empty()
				and str(row.get("zh", "")).strip_edges() != ""
				and str(row.get("en", "")).strip_edges() != ""
				and str(row.get("zh", "")) != str(row.get("en", "")),
			"line-table %s is not bilingual" % id)
		var slot: String = str(row.get("slot", ""))
		if slot == "hearth":
			hearth_n += 1
		elif slot == "waystone":
			waystone_n += 1
		elif slot == "loss":
			loss_n += 1
	_check(fails, hearth_n == 60 and waystone_n == 60 and loss_n == 50,
		"Batch 3 pools hearth=%d waystone=%d loss=%d" % [
			hearth_n, waystone_n, loss_n])
	_check(fails, content.line_table.size() == 178,
		"line-table census is not 178 (got %d)" % content.line_table.size())
	var whispers: Locale = Locale.new(Locale.CODE_EN)
	var whispers_zh: Locale = Locale.new(Locale.CODE_ZH_HANT)
	_check(fails, whispers_zh.code == Locale.CODE_ZH_HANT, "zh-Hant whispers missing")
	for i: int in range(24):
		var wkey: String = "content.whispers.%d" % i
		_check(fails, whispers.t(wkey) != wkey and whispers_zh.t(wkey) != wkey
				and whispers.t(wkey) != whispers_zh.t(wkey),
			"%s is not bilingual" % wkey)


static func _journey_a(content: ContentDB, code: StringName, fails: Array[String]) -> void:
	var tag: String = "A %s" % code
	var zh: bool = code == Locale.CODE_ZH_HANT
	var opening: SceneScript = _script("opening")
	_check(fails, opening != null and opening.line_count() == 8,
		"%s: opening did not load" % tag)
	if opening == null:
		return
	var dest: ScenePlayer = ScenePlayer.new(opening, 3)
	dest.instant = true
	dest._ready()
	var dest_line: Label = dest.find_child("Line", true, false) as Label
	var caption: Label = dest.find_child("Caption", true, false) as Label
	_check(fails, dest_line != null
			and dest_line.text == Locale.active.t("story.opening.b2.l2"),
		"%s: destination line was not the locale leaf" % tag)
	_check(fails, dest_line != null and (
			(zh and dest_line.text.contains("封門") and dest_line.text.contains("燼璃"))
			or (not zh and dest_line.text.contains("sealed door")
				and dest_line.text.contains("emberglass"))),
		"%s: opening did not name the sealed door before combat" % tag)
	_check(fails, caption != null
			and caption.text == Locale.active.t("ui.dawn.inputHint"),
		"%s: opening lost tap/hold skip grammar" % tag)
	var city: ScenePlayer = ScenePlayer.new(opening, 4)
	city.instant = true
	city._ready()
	var city_line: Label = city.find_child("Line", true, false) as Label
	_check(fails, city_line != null and (
			(zh and city_line.text.contains("金城"))
			or (not zh and city_line.text.contains("Gilded City"))),
		"%s: opening did not name the Gilded City" % tag)
	dest.free()
	city.free()
	var main: Main = _main(content)
	main._show_title()
	main._on_title_choice("begin", null)
	_wake(main)
	_check(fails, _playing(main, "opening"),
		"%s: fresh 續火 did not play the opening" % tag)
	_check(fails, _line_text(main) == Locale.active.t("story.opening.b1.l1"),
		"%s: opening first line was not the locale leaf" % tag)
	_drive(main)
	_check(fails, main._vigil.scenes_seen.has("opening"),
		"%s: finishing the opening did not mark scenes_seen" % tag)
	_check(fails, main._map_screen is WorldMapScreen,
		"%s: opening did not hand off to the map" % tag)
	_dispose(main)
	var hearth: Main = _departing(content, 35601)
	var row: Dictionary = PoolBeats.row_of(content.line_table, hearth.game.run)
	_check(fails, str(row.get("slot", "")) == PoolBeats.SLOT_HEARTH,
		"%s: run-start hearth did not draw a pool.hearth row" % tag)
	_check(fails, _hearth_text(hearth) == LineTable.text(row, zh),
		"%s: hearth did not display the locale row" % tag)
	_dispose(hearth)
	var stones: Main = _on_map(content, 35602)
	_pick_first(stones)
	_wake(stones)
	var way: Dictionary = PoolBeats.row_of(content.line_table, stones.game.run)
	_check(fails, str(way.get("slot", "")) == PoolBeats.SLOT_WAYSTONE,
		"%s: waystone interstitial did not draw" % tag)
	_check(fails, _line_text(stones) == LineTable.text(way, zh),
		"%s: waystone did not display the locale row" % tag)
	_dispose(stones)


static func _journey_b(content: ContentDB, code: StringName, fails: Array[String]) -> void:
	var tag: String = "B %s" % code
	var zh: bool = code == Locale.CODE_ZH_HANT
	var main: Main = _main(content)
	main._vigil.scenes_seen.append("opening")
	main._show_title()
	main._on_title_choice("begin", null)
	_check(fails, main._route_screen is EmbarkScreen,
		"%s: returning 續火 did not return Embark" % tag)
	_check(fails, not (main._route_screen is ScenePlayer),
		"%s: returning 續火 replayed the opening" % tag)
	_dispose(main)
	var m2: SceneScript = _script("lamplighter-m2-pre")
	_check(fails, m2 != null, "%s: lamplighter-m2-pre did not load" % tag)
	if m2 != null:
		var player: ScenePlayer = ScenePlayer.new(m2, 1)
		player.instant = true
		player._ready()
		var line: Label = player.find_child("Line", true, false) as Label
		_check(fails, line != null
				and line.text == Locale.active.t("story.lamplighter-m2.pre.l2"),
			"%s: m2 did not speak the locale prior-meeting line" % tag)
		_check(fails, line != null and (
				(zh and line.text.contains("上次"))
				or (not zh and line.text.to_lower().contains("last time"))),
			"%s: m2 did not reference the prior meeting" % tag)
		player.free()
	var producer: Main = _departing(content, 35611)
	var id: String = str(PoolBeats.row_of(content.line_table, producer.game.run).get("id", ""))
	var saved: RunState = SaveService.load_run(content, RUN_PATH)
	_dispose(producer)
	var resumed: Main = _main(content)
	resumed._vigil.scenes_seen.append("opening")
	resumed._transitions.instant = false
	resumed._continue_run(saved)
	_wake(resumed)
	_check(fails, str(PoolBeats.row_of(content.line_table, resumed.game.run).get("id", ""))
			== id and resumed.game.run.pool_draws.size() == 1,
		"%s: hearth resume advanced or redrew" % tag)
	_check(fails, _hearth_text(resumed) == LineTable.text(
			PoolBeats.row_of(content.line_table, resumed.game.run), zh),
		"%s: hearth resume changed the locale line" % tag)
	_dispose(resumed)


static func _journey_c(content: ContentDB, code: StringName, fails: Array[String]) -> void:
	var tag: String = "C %s" % code
	var zh: bool = code == Locale.CODE_ZH_HANT
	var vigil: VigilState = VigilState.blank()
	var death: RunState = _run(content, vigil, "run-356-loss")
	_check(fails, vigil.commit_run(death, "death", content)
			and vigil.defeat_epitaphs.size() == 1,
		"%s: loss did not write exactly one epitaph" % tag)
	_check(fails, vigil.commit_run(death, "death", content)
			and vigil.defeat_epitaphs.size() == 1,
		"%s: retry double-wrote the epitaph" % tag)
	var id: String = vigil.defeat_epitaphs[0]
	var row: Dictionary = LineTable.row_by_id(content.line_table, id)
	_check(fails, str(row.get("slot", "")) == "loss",
		"%s: epitaph %s is not a loss leaf" % [tag, id])
	var body: String = LineTable.text(row, zh)
	_check(fails, not body.is_empty() and body == LineTable.text(row, zh),
		"%s: earned locale leaf was empty" % tag)
	var screen: VigilScreen = VigilScreen.new(vigil, content)
	screen._show_epitaphs()
	_check(fails, _node_has_text(screen, body),
		"%s: later Vigil could not read the earned locale leaf" % tag)
	screen.free()
	var folded: VigilState = VigilState.from_dict(vigil.to_dict())
	_check(fails, folded != null and folded.defeat_epitaphs == vigil.defeat_epitaphs,
		"%s: epitaph ledger did not survive v2 load" % tag)


static func _journey_d(content: ContentDB, code: StringName, fails: Array[String]) -> void:
	var tag: String = "D %s" % code
	var kernel: ScenarioKernel = ScenarioKernel.new(content, DEV_RUN, DEV_VIGIL, DEV_REF)
	kernel.clear_profile()
	var ref: ScenarioReference = ScenarioReference.new()
	_check(fails, ref.load_from({
			"id": "act-4-map-start", "revision": 1, "build": BUILD,
			"seed": 18501, "locale": String(code), "shape": "pad-landscape",
			"overrides": {"act": 3, "shards": 6},
		}), "%s: act-4-map-start rejected: %s" % [tag, ref.error])
	var constructed: RunState = kernel.construct(ref)
	_check(fails, constructed != null and constructed.act == 3
			and constructed.is_final_act() and constructed.shards.size() == 6,
		"%s: act-4-map-start did not construct the authored road" % tag)
	kernel.clear_profile()
	var first: Main = _act4_main(content, 2, -1)
	first._on_boss_relic_chosen("")
	_wake(first)
	_check(fails, _playing(first, "act4-entry")
			and _line_text(first) == Locale.active.t("story.act4-entry.b1.l1"),
		"%s: first crossing did not play locale act4-entry" % tag)
	_drive(first)
	_check(fails, first._vigil.scenes_seen.has("act4-entry")
			and first._map_screen is WorldMapScreen,
		"%s: act4-entry did not mark and hand off" % tag)
	_dispose(first)
	var repeat: Main = _act4_main(content, 2, -1)
	repeat._vigil.scenes_seen.append("act4-entry")
	repeat._vigil.scenes_seen.append("unsealing-short")
	repeat._on_boss_relic_chosen("")
	_wake(repeat)
	_check(fails, _playing(repeat, "unsealing-short")
			and _line_text(repeat) == Locale.active.t("story.unsealing-short.b1.l1"),
		"%s: repeat crossing did not play locale unsealing-short" % tag)
	_dispose(repeat)
	for i: int in range(5):
		var node_main: Main = _act4_main(content, 3, i)
		var n: MapNode = node_main._map.nodes[i]
		node_main._enter_chosen_node(n)
		_wake(node_main)
		var scene_id: String = ACT4_SCENES[i]
		_check(fails, _playing(node_main, scene_id),
			"%s: n%d did not play %s" % [tag, i, scene_id])
		var script: SceneScript = _script(scene_id)
		if script != null:
			_check(fails, _line_text(node_main) == Locale.active.t(str(script.lines[0]["key"])),
				"%s: %s first line was not the locale leaf" % [tag, scene_id])
		if n.is_combat():
			_check(fails, _same_ids(node_main.game.run.pending_enemy_ids, _act4_enemies(i)),
				"%s: n%d did not arm the authored encounter" % [tag, i])
		_drive(node_main)
		_check(fails, node_main._vigil.scenes_seen.has(scene_id),
			"%s: finishing %s did not mark scenes_seen" % [tag, scene_id])
		_check(fails, node_main._act4_arrival_scene(n).is_empty(),
			"%s: %s remained selectable after it was seen" % [tag, scene_id])
		_dispose(node_main)
	var win: Main = _boss_main(content)
	win._on_combat_over("win")
	_wake(win)
	_check(fails, _playing(win, "finale")
			and _line_text(win) == Locale.active.t("story.finale.b1.l1"),
		"%s: first Keeper win did not play locale finale" % tag)
	_drive(win)
	_check(fails, win._vigil.scenes_seen.has("finale")
			and win._vigil.scenes_seen.has("finale-win")
			and win._route_screen is DawnScreen,
		"%s: win chain did not reach Dawn through finale-win" % tag)
	_dispose(win)
	var short: Main = _boss_main(content)
	short._vigil.scenes_seen.append("finale")
	short._on_combat_over("win")
	_wake(short)
	_check(fails, _playing(short, "finale-win")
			and _line_text(short) == Locale.active.t("story.finale-win.b1.l1"),
		"%s: repeat win did not play locale short close" % tag)
	_drive(short)
	_check(fails, not short._vigil.scenes_seen.has("finale-loss")
			and short._route_screen is DawnScreen,
		"%s: repeat short close did not hand off to Dawn" % tag)
	_dispose(short)


static func _journey_e(content: ContentDB, code: StringName, fails: Array[String]) -> void:
	var tag: String = "E %s" % code
	var loss: Main = _boss_main(content)
	loss._on_combat_over("lose")
	_wake(loss)
	_check(fails, _playing(loss, "finale-loss")
			and _line_text(loss) == Locale.active.t("story.finale-loss.b1.l1"),
		"%s: Keeper loss did not play locale finale-loss" % tag)
	_drive(loss)
	_check(fails, loss._route_screen is RunEndScreen
			and loss.game.run.pending_run_end != null
			and str(loss.game.run.pending_run_end.get("outcome", "")) == "death",
		"%s: loss scene did not close onto RunEndScreen" % tag)
	_dispose(loss)
	var again: Main = _boss_main(content)
	again._vigil.scenes_seen.append("finale")
	again._vigil.scenes_seen.append("act4-entry")
	for scene_id: String in ACT4_SCENES:
		again._vigil.scenes_seen.append(scene_id)
	again._on_combat_over("win")
	_wake(again)
	_check(fails, _playing(again, "finale-win"),
		"%s: a repeat attempt replayed first-time finale" % tag)
	_check(fails, again.game.run.unlocks.has(RunState.MIRRORED_ROAD),
		"%s: repeat win lost required route state" % tag)
	_drive(again)
	_check(fails, again._route_screen is DawnScreen,
		"%s: repeat route was not finishable" % tag)
	_dispose(again)


static func _journey_f(content: ContentDB, code: StringName, fails: Array[String]) -> void:
	var tag: String = "F %s" % code
	var zh: bool = code == Locale.CODE_ZH_HANT
	var stones: Main = _on_map(content, 35621)
	_pick_first(stones)
	_wake(stones)
	var way_id: String = str(PoolBeats.row_of(content.line_table, stones.game.run).get("id", ""))
	var way_saved: RunState = SaveService.load_run(content, RUN_PATH)
	_dispose(stones)
	var way_resumed: Main = _main(content)
	way_resumed._vigil.scenes_seen.append("opening")
	way_resumed._transitions.instant = false
	way_resumed._continue_run(way_saved)
	_wake(way_resumed)
	_check(fails, str(PoolBeats.row_of(content.line_table, way_resumed.game.run).get("id", ""))
			== way_id and way_resumed.game.run.pool_draws.size() == 2,
		"%s: waystone resume advanced or duplicated" % tag)
	_check(fails, _line_text(way_resumed) == LineTable.text(
			PoolBeats.row_of(content.line_table, way_resumed.game.run), zh),
		"%s: waystone resume changed the locale line" % tag)
	_dispose(way_resumed)
	var producer: Main = _main(content)
	producer._show_title()
	producer._on_title_choice("begin", null)
	_wake(producer)
	var opener: ScenePlayer = producer._route_screen as ScenePlayer
	if opener != null:
		opener._process(0.016)
	var opened: RunState = SaveService.load_run(content, RUN_PATH)
	_dispose(producer)
	_check(fails, opened != null and typeof(opened.pending_scene) == TYPE_DICTIONARY
			and str(opened.pending_scene.get("id", "")) == "opening"
			and int(float(str(opened.pending_scene.get("cursor", -1)))) == 1,
		"%s: interrupted opening did not persist cursor 1" % tag)
	var scene_resumed: Main = _main(content)
	scene_resumed._continue_run(opened)
	_wake(scene_resumed)
	_check(fails, _playing(scene_resumed, "opening")
			and _line_text(scene_resumed) == Locale.active.t("story.opening.b1.l2"),
		"%s: opening resume advanced or duplicated" % tag)
	_dispose(scene_resumed)
	var hp_before: int = 0
	var event_main: Main = _main(content)
	var event_run: RunState = _event_run(content, "library")
	event_run.player.hp = maxi(1, event_run.player.max_hp - 20)
	event_main._continue_run(event_run)
	hp_before = event_main.game.run.player.hp
	event_main._on_event_choice("1", "library")
	var hp_after: int = event_main.game.run.player.hp
	_check(fails, hp_after > hp_before, "%s: library rest did not apply once" % tag)
	var event_saved: RunState = SaveService.load_run(content, RUN_PATH)
	_dispose(event_main)
	var event_resumed: Main = _main(content)
	event_resumed._continue_run(event_saved)
	_check(fails, event_resumed.game.run.player.hp == hp_after,
		"%s: event resume re-applied the rest" % tag)
	var result: EventScreen = event_resumed._route_screen as EventScreen
	_check(fails, result != null
			and result._result_log == Locale.active.t("story.event-library.c1"),
		"%s: event resume dropped the locale result" % tag)
	event_resumed._on_event_story_continue()
	_check(fails, event_resumed.game.run.player.hp == hp_after,
		"%s: coda continue re-applied the rest" % tag)
	_dispose(event_resumed)
	var finale: Main = _boss_main(content)
	finale._on_combat_over("win")
	_wake(finale)
	var swap: ScenePlayer = finale._route_screen as ScenePlayer
	if swap != null:
		swap._process(0.016)
	var finale_saved: RunState = SaveService.load_run(content, RUN_PATH)
	_dispose(finale)
	_check(fails, finale_saved != null
			and typeof(finale_saved.pending_scene) == TYPE_DICTIONARY
			and str(finale_saved.pending_scene.get("id", "")) == "finale"
			and int(float(str(finale_saved.pending_scene.get("cursor", -1)))) == 1,
		"%s: interrupted finale did not persist cursor 1" % tag)
	var finale_resumed: Main = _main(content)
	finale_resumed._vigil.scenes_seen.append("opening")
	finale_resumed._continue_run(finale_saved)
	_wake(finale_resumed)
	_check(fails, _playing(finale_resumed, "finale")
			and _line_text(finale_resumed) == Locale.active.t("story.finale.b1.l2"),
		"%s: finale resume advanced or duplicated" % tag)
	_dispose(finale_resumed)


static func _isolation(content: ContentDB, fails: Array[String]) -> void:
	var kernel: ScenarioKernel = ScenarioKernel.new(content, DEV_RUN, DEV_VIGIL, DEV_REF)
	kernel.clear_profile()
	var before_run: Variant = _file_snapshot(SaveService.RUN_PATH)
	var before_vigil: Variant = _file_snapshot(SaveService.VIGIL_PATH)
	var ref: ScenarioReference = ScenarioReference.new()
	ref.load_from({
		"id": "act-4-map-terminus", "revision": 1, "build": BUILD,
		"seed": 18501, "locale": "zh-Hant", "shape": "pad-landscape",
		"overrides": {"act": 3, "shards": 6, "node": "n4",
			"kind": "boss", "enemies": ["eternalKeeper"]},
	})
	var run: RunState = kernel.construct(ref)
	_check(fails, run is RunState, "isolation: act-4-map-terminus did not construct")
	_check(fails, _same_snap(_file_snapshot(SaveService.RUN_PATH), before_run)
			and _same_snap(_file_snapshot(SaveService.VIGIL_PATH), before_vigil),
		"isolation: Scenario construct touched the production pair")
	kernel.clear_profile()


static func _host_of(key: String, homes: Dictionary) -> String:
	if homes.has(key):
		return str(homes[key])
	if key.begins_with("story.dawn."):
		return "dawn"
	if key.begins_with("story.event-"):
		return "event"
	return ""


static func _scene_homes() -> Dictionary:
	var out: Dictionary = {}
	var loaded: Variant = SceneScript.load_all()
	if typeof(loaded) != TYPE_DICTIONARY:
		return out
	var scenes: Dictionary = loaded
	for scene_id_v: Variant in scenes:
		var found: Variant = scenes[scene_id_v]
		if not (found is SceneScript):
			continue
		var script: SceneScript = found
		for line: Dictionary in script.lines:
			var key: String = str(line["key"])
			var host: String = "scene:%s" % str(scene_id_v)
			if out.has(key) and str(out[key]) != host:
				out[key] = "duplicate:%s+%s" % [out[key], host]
			else:
				out[key] = host
	return out


static func _flatten_story(code: StringName) -> Dictionary:
	var path: String = "res://locale/%s.json" % String(code)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var out: Dictionary = {}
	if typeof(parsed) != TYPE_DICTIONARY:
		return out
	var root: Dictionary = parsed
	_flatten(root.get("story", {}), "story", out)
	return out


static func _flatten(value: Variant, path: String, out: Dictionary) -> void:
	if typeof(value) == TYPE_STRING:
		out[path] = value
	elif typeof(value) == TYPE_DICTIONARY:
		var table: Dictionary = value
		for key_v: Variant in table:
			var key: String = str(key_v)
			_flatten(table[key_v], key if path.is_empty() else "%s.%s" % [path, key], out)
	elif typeof(value) == TYPE_ARRAY:
		var rows: Array = value
		for i: int in range(rows.size()):
			_flatten(rows[i], str(i) if path.is_empty() else "%s.%d" % [path, i], out)


static func _script(scene_id: String) -> SceneScript:
	var loaded: Variant = SceneScript.load_all()
	if typeof(loaded) != TYPE_DICTIONARY:
		return null
	var scenes: Dictionary = loaded
	var found: Variant = scenes.get(scene_id)
	return found if found is SceneScript else null


static func _same_ids(value: Variant, expected: PackedStringArray) -> bool:
	var got: PackedStringArray = PackedStringArray()
	if typeof(value) != TYPE_ARRAY:
		return expected.is_empty()
	var rows: Array = value
	for id_v: Variant in rows:
		got.append(str(id_v))
	return got == expected


static func _same_snap(a: Variant, b: Variant) -> bool:
	return str(a) == str(b)


static func _playing(main: Main, scene_id: String) -> bool:
	var player: ScenePlayer = main._route_screen as ScenePlayer
	return player != null and player._script.id == scene_id


static func _line_text(main: Main) -> String:
	var player: ScenePlayer = main._route_screen as ScenePlayer
	if player == null:
		return ""
	var line: Label = player.find_child("Line", true, false) as Label
	return line.text if line != null else ""


static func _hearth_text(main: Main) -> String:
	var screen: DepartureStaging = main._route_screen as DepartureStaging
	if screen == null:
		return ""
	var line: Label = screen.find_child("Line", true, false) as Label
	return line.text if line != null else ""


static func _node_has_text(node: Node, needle: String) -> bool:
	if needle.is_empty():
		return false
	if node is Label and (node as Label).text.contains(needle):
		return true
	if node is Button and (node as Button).text.contains(needle):
		return true
	if node is RichTextLabel and (node as RichTextLabel).get_parsed_text().contains(needle):
		return true
	for child: Node in node.get_children():
		if _node_has_text(child, needle):
			return true
	return false


static func _wake(main: Main) -> void:
	var hearth: DepartureStaging = main._route_screen as DepartureStaging
	if hearth != null and not hearth._line_up and not hearth._done:
		hearth._bind_line()
		hearth._await_line()
		return
	var player: ScenePlayer = main._route_screen as ScenePlayer
	if player != null and player._beat == ScenePlayer.BEAT_IDLE and not player._done:
		player._ready()


static func _drive(main: Main) -> void:
	var steps: int = 0
	while main._route_screen is ScenePlayer and steps < 32:
		_wake(main)
		(main._route_screen as ScenePlayer)._process(0.016)
		steps += 1


static func _departing(content: ContentDB, seed: int) -> Main:
	var main: Main = _main(content)
	main._forced_seed = seed
	main._vigil.scenes_seen.append("opening")
	main._transitions.instant = false
	main._new_run()
	_wake(main)
	return main


static func _on_map(content: ContentDB, seed: int) -> Main:
	var main: Main = _departing(content, seed)
	var screen: DepartureStaging = main._route_screen as DepartureStaging
	if screen != null:
		screen._tap()
	return main


static func _pick_first(main: Main) -> void:
	if main._map_screen != null:
		main._map_screen.instant = true
	var live: Array[int] = main._map.reachable() if main._map != null else []
	if live.is_empty():
		return
	if main._map_screen != null:
		main._map_screen.choose(live[0])
	else:
		main._on_node_chosen(live[0])


static func _act4_main(content: ContentDB, act: int, at: int) -> Main:
	var main: Main = _main(content)
	var run: RunState = _shard_run(content, act)
	var map: WorldMap = WorldMap.for_run(run, content)
	map.at = at
	if at >= 0:
		run.node_id = map.nodes[at].id
	run.map = map.to_dict()
	main.game = GlassvowGame.new(content, run)
	main._map = map
	return main


static func _boss_main(content: ContentDB) -> Main:
	var main: Main = _act4_main(content, 3, 4)
	main.game.cb = CombatState.new()
	main.game.cb.finale_handoff = true
	main.game.run.pending_combat = "boss"
	main.game.run.pending_enemy_ids = ["eternalKeeper"]
	return main


static func _shard_run(content: ContentDB, act: int) -> RunState:
	var vigil: VigilState = VigilState.blank()
	for id: String in VigilState.QUEST_IDS:
		vigil.quests[id]["state"] = "complete"
		vigil.shards.append(id)
	var run: RunState = RunState.new_run(content, 35600, "run-356", {
		"quests": vigil.quests.duplicate(true),
		"shards": vigil.shards.duplicate(),
	})
	run.act = act
	return run


static func _run(content: ContentDB, vigil: VigilState, run_id: String) -> RunState:
	return RunState.new_run(content, run_id.hash() & 0x7FFFFFFF, run_id, {
		"quests": vigil.quests.duplicate(true),
		"shards": vigil.shards.duplicate(),
	})


static func _event_run(content: ContentDB, event_id: String) -> RunState:
	var run: RunState = RunState.new_run(content, 35631, "run-356-event")
	var map: WorldMap = WorldMap.slice()
	map.at = 3
	map.nodes[3].type = "event"
	run.node_id = map.nodes[3].id
	run.map = map.to_dict()
	run.quest_scratch["eventNode"] = event_id
	return run


static func _main(content: ContentDB) -> Main:
	SaveService.clear(RUN_PATH)
	SaveService.clear_vigil(VIGIL_PATH)
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


static func _file_snapshot(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return FileAccess.get_file_as_string(path)
