extends Node
## Prepare only the saved chapter's immutable resources while its title is visible.
## All scene construction stays on the main thread. Pending requests are drained
## even after a route change, so the loader cannot retain abandoned resources.
var pending: Array[String] = []
var retained: Dictionary = {}
var releasing: bool = false
var completed: int = 0
func begin(paths: Array[String]) -> void:
	for path: String in paths:
		if pending.has(path) or retained.has(path): continue
		if ResourceLoader.load_threaded_request(path,"PackedScene")==OK:
			pending.append(path)
	set_process(true)
func _process(_delta: float) -> void:
	for path: String in pending.duplicate():
		var state: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(path)
		if state==ResourceLoader.THREAD_LOAD_IN_PROGRESS: continue
		var resource: Resource = ResourceLoader.load_threaded_get(path) if state!=ResourceLoader.THREAD_LOAD_INVALID_RESOURCE else null
		pending.erase(path)
		if resource!=null:
			completed+=1
			if not releasing: retained[path]=resource
	if pending.is_empty():
		set_process(false)
		if releasing: queue_free()
func release() -> void:
	releasing=true
	retained.clear()
	if pending.is_empty(): queue_free()
