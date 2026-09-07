extends SceneTree
## A bounded native canary: identical geometry, no off-thread render Nodes.
const Routes = preload("res://presentation/map/chapters/common/fitted_routes.gd")
class NoRuins extends RefCounted:
	var sites: Array[Dictionary] = []
	var failure: String = ""
	func build(_sample: Dictionary,_anchors: Dictionary,_routes: Dictionary) -> void:
		pass

func _initialize() -> void:
	_run.call_deferred()

func _builder() -> Routes:
	var value: Routes = Routes.new()
	value.levels=preload("res://presentation/map/chapters/common/terrace_levels.gd").new()
	value.ruin_plan=NoRuins.new()
	value.height_profile=preload("res://presentation/map/chapters/act2/generated_profile.gd").new()
	value.bridge_style=preload("res://presentation/map/chapters/stone_bridge/presets.gd").drowned_city()
	value.bridge_style["sample_spacing"]=.8
	return value

func _run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Thread canary requires the native renderer")
		quit(2)
		return
	var sample: Dictionary = {"anchors":{"a":[-8,0,0],"b":[8,0,0],"c":[0,1,-8],"d":[0,1,8]},
		"edges":{"a>b":{"from":"a","to":"b","centerline":[[-8,0,0],[0,0,0],[8,0,0]]},
		"c>d":{"from":"c","to":"d","centerline":[[0,1,-8],[0,1,0],[0,1,8]]}}}
	var reference: Routes = _builder()
	reference.build(sample)
	var pending: Routes = _builder()
	pending.defer_instances=true
	var started: int = Time.get_ticks_usec()
	var metrics: Dictionary = {"frames":0,"worst":0,"previous":started}
	var track: Callable = func() -> void:
		var now: int = Time.get_ticks_usec()
		var previous: int = metrics["previous"]
		var worst: int = metrics["worst"]
		metrics["worst"]=maxi(worst,now-previous)
		metrics["previous"]=now
		metrics["frames"]+=1
	process_frame.connect(track)
	var lease: RefCounted = preload("res://presentation/map/chapters/common/geometry_job.gd").new()
	await lease.run(pending,sample,self,root)
	process_frame.disconnect(track)
	var frames: int = metrics["frames"]
	var worst_gap: int = metrics["worst"]
	var no_render_nodes: bool = pending.get_child_count()==0
	var same: bool = _geometry(reference)==_geometry(pending)
	var records: int = pending.instance_rows.size()
	pending.publish_instances()
	var published: bool = pending.get_child_count()==reference.get_child_count() and records==pending.get_child_count()
	print("GEOMETRY_THREAD_CANARY ",JSON.stringify({"same_mesh_bytes":same,"no_render_nodes_in_job":no_render_nodes,
		"published_same_instances":published,"frames_while_working":frames,"maximum_frame_gap_ms":worst_gap/1000.0,
		"elapsed_ms":(Time.get_ticks_usec()-started)/1000.0,"failure":pending.failure}))
	var passed: bool = same and no_render_nodes and published and frames>0 and pending.failure.is_empty()
	var owner: Node = Node.new()
	root.add_child(owner)
	var cancelled: Routes = _builder()
	var abandoned: RefCounted = preload("res://presentation/map/chapters/common/geometry_job.gd").new()
	abandoned.run(cancelled,sample,self,owner)
	for i: int in range(2): await process_frame
	owner.queue_free()
	while abandoned._task>=0: await process_frame
	var stopped: bool = abandoned.token.cancelled() and not cancelled.failure.is_empty() and cancelled.get_child_count()==0
	abandoned=null
	var freed: bool = not is_instance_valid(cancelled)
	print("GEOMETRY_JOB_CANCELLATION ",JSON.stringify({"stopped_without_publication":stopped,"unpublished_geometry_freed":freed}))
	passed=passed and stopped and freed

	reference.free()
	pending.free()
	quit(0 if passed else 1)

func _geometry(value: Routes) -> PackedByteArray:
	var arrays: Array = []
	for meshes: Array in [value.deck_meshes,value.underside_meshes,value.decoration_meshes]:
		for mesh: ArrayMesh in meshes:
			for i: int in range(mesh.get_surface_count()): arrays.append(mesh.surface_get_arrays(i))
	return var_to_bytes(arrays)
