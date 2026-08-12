class_name WebAcceptance
extends Node
## Read-only Web Dev projection for the browser acceptance run. This object
## owns the complete JavaScript boundary; production exports never publish it.

const SCHEMA_VERSION: int = 1
const GLOBAL_NAME: String = "glassvowAcceptance"

var _publish_generation: int = 0


func observe_route(rebuilder: Callable, game: GlassvowGame, content: ContentDB,
		durable_path: String) -> void:
	if not OS.has_feature("web_dev"):
		return
	var live_run: RunState = game.run if game != null else null
	_queue_publish(canonical_route(rebuilder), live_run, content, durable_path)


func _queue_publish(route: String, live_run: RunState, content: ContentDB,
		durable_path: String) -> void:
	_publish_generation += 1
	call_deferred("_publish_if_current", _publish_generation,
		route, live_run, content, durable_path)


func _publish_if_current(generation: int, route: String, live_run: RunState,
		content: ContentDB, durable_path: String) -> void:
	if generation != _publish_generation:
		return
	_publish(route, live_run, content, durable_path)


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


func _publish(route: String, live_run: RunState, content: ContentDB,
		durable_path: String) -> void:
	if not OS.has_feature("web_dev"):
		return
	var generation: int = _publish_generation
	var pending: Dictionary = projection_for(route, live_run, content, durable_path)
	pending["ready"] = false
	var ready: Dictionary = pending.duplicate(true)
	ready["ready"] = true
	_publish_plain(pending)
	_begin_indexed_db_ack(generation, JSON.stringify(ready))


func _publish_plain(projection: Dictionary) -> void:
	var serialized: String = JSON.stringify(projection)
	var window: JavaScriptObject = JavaScriptBridge.get_interface("window")
	var js_json: JavaScriptObject = JavaScriptBridge.get_interface("JSON")
	if window != null and js_json != null:
		window[GLOBAL_NAME] = js_json.parse(serialized)


func _begin_indexed_db_ack(generation: int, ready_json: String) -> void:
	var capture_source: String = """
(() => {
	if (typeof GodotOS !== "object") return;
	GodotOS.__glassvow_acceptance_generation = %d;
	GodotOS.__glassvow_acceptance_previous_promise = GodotOS._fs_sync_promise;
})();
""" % generation
	JavaScriptBridge.eval(capture_source, false)
	# Godot 4.7.1-stable (a13da4feb): force_fs_sync only requests OS_Web's
	# coordinated main-loop sync. Its distinct GodotOS promise is the ack.
	JavaScriptBridge.force_fs_sync()
	var source: String = """
(async () => {
	const generation = %d;
	const os = typeof GodotOS === "object" ? GodotOS : null;
	const currentGeneration = () => os == null ? null : os.__glassvow_acceptance_generation;
	const previousPromise = os == null ? null : os.__glassvow_acceptance_previous_promise;
	const readyJson = %s;
	try {
		if (typeof GodotFS !== "object" || typeof GodotFS.is_persistent !== "function" ||
				GodotFS.is_persistent() !== 1 || typeof GodotFS._syncing !== "boolean" ||
				os == null) {
			throw new Error("Godot IndexedDB sync API is unavailable");
		}
		let syncPromise = null;
		for (let attempt = 0; attempt < 120; attempt += 1) {
			if (currentGeneration() !== generation) return;
			const candidate = os._fs_sync_promise;
			if (candidate !== previousPromise && candidate != null &&
					typeof candidate.then === "function") {
				syncPromise = candidate;
				break;
			}
			await new Promise((resolve) => requestAnimationFrame(resolve));
		}
		if (syncPromise == null) throw new Error("coordinated sync did not start");
		const syncError = await syncPromise;
		if (syncError) throw new Error("acceptance sync failed: " + syncError);
		if (GodotFS._syncing !== false) throw new Error("acceptance sync is still active");
		if (currentGeneration() !== generation) return;
		delete os.__glassvow_acceptance_previous_promise;
		window[%s] = JSON.parse(readyJson);
	} catch (error) {
		if (currentGeneration() !== generation) return;
		const message = error instanceof Error ? error.message : String(error);
		console.error("Glassvow IndexedDB acceptance sync failed: " + message);
	}
})();
""" % [generation, JSON.stringify(ready_json), JSON.stringify(GLOBAL_NAME)]
	JavaScriptBridge.eval(source, false)
