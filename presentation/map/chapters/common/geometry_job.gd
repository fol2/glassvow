extends RefCounted
## A scoped lease over unpublished geometry. Visible Nodes remain on the main thread.
const Cancellation = preload("res://presentation/map/chapters/common/build_cancellation.gd")
var geometry: Node3D
var token: Cancellation = Cancellation.new()
var _task: int = -1

func run(builder: Node3D,sample: Dictionary,tree: SceneTree,owner: Node) -> void:
	geometry=builder
	geometry.set("defer_instances",true)
	geometry.set("cancel_token",token)
	var lifetime: WeakRef = weakref(owner)
	_task=WorkerThreadPool.add_task(func() -> void: geometry.call("build",sample),true,"Map geometry")
	while not WorkerThreadPool.is_task_completed(_task):
		var live: Node = lifetime.get_ref()
		if live==null or live.is_queued_for_deletion(): token.cancel()
		await tree.process_frame
	WorkerThreadPool.wait_for_task_completion(_task)
	_task=-1

func _notification(what: int) -> void:
	if what!=NOTIFICATION_PREDELETE: return
	if _task>=0:
		token.cancel()
		WorkerThreadPool.wait_for_task_completion(_task)
	if is_instance_valid(geometry) and geometry.get_parent()==null:
		geometry.free()
