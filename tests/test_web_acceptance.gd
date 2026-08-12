extends RefCounted
## #146: Web Dev exposes one read-only browser acceptance projection without
## turning the composition root into a command or persistence adapter.

const MAIN_PATH: String = "res://application/main.gd"
const SEAM_PATH: String = "res://application/web_acceptance.gd"
const SAVE_PATH: String = "user://test_web_acceptance_run.json"


class AcceptanceSpy extends WebAcceptance:
	var observed_path: String = ""

	func observe_route(_rebuilder: Callable, _game: GlassvowGame, _content: ContentDB,
			durable_path: String) -> void:
		observed_path = durable_path


static func run(fails: Array[String]) -> void:
	_source_contract(fails)
	_path_binding_contract(fails)
	_projection_contract(fails)
	SaveService.clear_run("", SAVE_PATH)


static func _source_contract(fails: Array[String]) -> void:
	var main: String = FileAccess.get_file_as_string(MAIN_PATH)
	var seam: String = FileAccess.get_file_as_string(SEAM_PATH)
	if not seam.contains('OS.has_feature("web_dev")'):
		fails.append("web acceptance guard: projection is not restricted to web_dev")
	var publish: String = _function_body(seam, "_publish")
	if publish.find('OS.has_feature("web_dev")') < 0 \
			or publish.find('OS.has_feature("web_dev")') > publish.find("JavaScriptBridge"):
		fails.append("web acceptance guard: JavaScriptBridge is reachable before the web_dev guard")
	if not publish.contains("var serialized: String = JSON.stringify(") \
			or not publish.contains(
				"projection_for(route, live_run, content, durable_path)"):
		fails.append("web acceptance bridge: projection is not serialized before JavaScript marshalling")
	if not publish.contains('JavaScriptBridge.get_interface("JSON")'):
		fails.append("web acceptance bridge: JavaScript JSON interface is missing")
	if not publish.contains("window[GLOBAL_NAME] = js_json.parse(serialized)"):
		fails.append("web acceptance bridge: global is not assigned a parsed plain JavaScript object")
	if publish.contains("window.set(") \
			or publish.contains("window[GLOBAL_NAME] = projection_for("):
		fails.append("web acceptance bridge: Dictionary is marshalled directly to the JavaScript global")
	if not seam.contains("SaveService.load_run(content, durable_path)"):
		fails.append("web acceptance durable read: projection does not independently load the save")
	if main.contains("JavaScriptBridge"):
		fails.append("web acceptance boundary: Main accesses JavaScriptBridge directly")
	var ready: String = _function_body(main, "_ready")
	if ready.find('OS.has_feature("web_dev")') < 0 \
			or ready.find('OS.has_feature("web_dev")') > ready.find("WebAcceptance.new()"):
		fails.append("web acceptance allocation: helper exists outside web_dev")
	if not _function_body(main, "_remember_route").contains(
			"_web_acceptance.observe_route(rebuilder, game, content, _run_save_path)"):
		fails.append("web acceptance path: Main does not publish from its live injected save path")
	if not seam.contains('call_deferred("_publish"'):
		fails.append("web acceptance readiness: projection publishes before route construction returns")


static func _path_binding_contract(fails: Array[String]) -> void:
	var main: Main = Main.new()
	var spy: AcceptanceSpy = AcceptanceSpy.new()
	main._run_save_path = "user://superseded_web_acceptance_run.json"
	main._web_acceptance = spy
	main._run_save_path = SAVE_PATH
	main._remember_route(Callable(main, "_show_title"))
	if spy.observed_path != SAVE_PATH:
		fails.append("web acceptance path: route observation captured a stale save path")
	main._web_acceptance = null
	spy.free()
	main.free()


static func _projection_contract(fails: Array[String]) -> void:
	var seam: Script = load(SEAM_PATH) as Script
	if seam == null or not seam.has_method("projection_for"):
		fails.append("web acceptance projection: helper or projection_for is missing")
		return
	var main: Main = Main.new()
	if seam.call("canonical_route", Callable(main, "_show_vigil").bind(true)) != "vigil" \
			or seam.call("canonical_route", Callable(main, "_resume_pending_combat")) != "combat":
		fails.append("web acceptance route: bound and pending constructors are not canonical")
	main.free()
	var content: ContentDB = ContentDB.load_full()
	var live: RunState = RunState.new_run(content, 14601, "live-run-146")
	var durable: RunState = RunState.new_run(content, 14602, "durable-run-146")
	durable.player.gold = 146
	if not SaveService.store(durable, SAVE_PATH):
		fails.append("web acceptance fixture: durable run could not be stored")
		return
	var projection: Dictionary = seam.call(
		"projection_for", "map", live, content, SAVE_PATH)
	var keys: Array = projection.keys()
	keys.sort()
	var expected_keys: Array = [
		"durableRunId", "durableSaveSha256", "liveRunId",
		"ready", "route", "schemaVersion",
	]
	if keys != expected_keys:
		fails.append("web acceptance schema: projection keys are not exact: %s" % [keys])
	if projection.get("schemaVersion") != 1 \
			or projection.get("ready") != true or projection.get("route") != "map":
		fails.append("web acceptance schema: version, readiness or canonical route is wrong")
	if projection.get("liveRunId") != "live-run-146" \
			or projection.get("durableRunId") != "durable-run-146":
		fails.append("web acceptance durable read: live and independently loaded run IDs collapsed")
	var expected_loaded: RunState = SaveService.load_run(content, SAVE_PATH)
	var expected_digest: String = JSON.stringify(expected_loaded.to_save_dict()).sha256_text()
	if projection.get("durableSaveSha256") != expected_digest:
		fails.append("web acceptance durable read: digest is not the loaded canonical v2 save projection")
	SaveService.clear_run("", SAVE_PATH)
	var empty_projection: Dictionary = seam.call(
		"projection_for", "title", null, content, SAVE_PATH)
	if empty_projection.get("liveRunId", "missing") != null \
			or empty_projection.get("durableRunId", "missing") != null \
			or empty_projection.get("durableSaveSha256", "missing") != null:
		fails.append("web acceptance nulls: missing live or durable state is not explicit")


static func _function_body(source: String, function_name: String) -> String:
	var start: int = source.find("func %s(" % function_name)
	if start < 0:
		return ""
	var next: int = source.find("\nfunc ", start + 1)
	return source.substr(start) if next < 0 else source.substr(start, next - start)
