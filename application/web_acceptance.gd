class_name WebAcceptance
extends Node
## Read-only Web Dev projection for the browser acceptance run. This object
## owns the complete JavaScript boundary; production exports never publish it.

const SCHEMA_VERSION: int = 1
const GLOBAL_NAME: String = "glassvowAcceptance"

var save_path: String = SaveService.RUN_PATH


func observe_route(rebuilder: Callable, game: GlassvowGame, content: ContentDB) -> void:
	if not OS.has_feature("web_dev"):
		return
	var live_run: RunState = game.run if game != null else null
	call_deferred("_publish", canonical_route(rebuilder), live_run, content)


static func canonical_route(rebuilder: Callable) -> String:
	var method: String = String(rebuilder.get_method())
	if method.begins_with("_show_"):
		return method.trim_prefix("_show_")
	if method.begins_with("_resume_pending_"):
		return method.trim_prefix("_resume_pending_")
	return method.trim_prefix("_")


static func projection_for(route: String, live_run: RunState, content: ContentDB,
		durable_path: String = SaveService.RUN_PATH) -> Dictionary:
	var durable_run: RunState = SaveService.load_run(content, durable_path)
	var durable_json: Variant = null
	if durable_run != null:
		durable_json = JSON.stringify(durable_run.to_save_dict())
	return {
		"schemaVersion": SCHEMA_VERSION,
		"ready": true,
		"route": route,
		"liveRunId": live_run.run_id if live_run != null else null,
		"durableRunId": durable_run.run_id if durable_run != null else null,
		"durableSaveSha256": str(durable_json).sha256_text()
			if durable_json != null else null,
	}


func _publish(route: String, live_run: RunState, content: ContentDB) -> void:
	if not OS.has_feature("web_dev"):
		return
	var serialized: String = JSON.stringify(projection_for(route, live_run, content, save_path))
	var window: JavaScriptObject = JavaScriptBridge.get_interface("window")
	var js_json: JavaScriptObject = JavaScriptBridge.get_interface("JSON")
	if window != null and js_json != null:
		window[GLOBAL_NAME] = js_json.parse(serialized)
