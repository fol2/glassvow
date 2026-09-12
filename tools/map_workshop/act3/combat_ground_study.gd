extends SceneTree
## Paired real-combat capture: freeze one scene, replace only its ground texture.
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var scene: PackedScene = load("res://application/main.tscn")
	var main: Main = scene.instantiate() as Main
	root.add_child(main)
	await create_timer(4).timeout
	var combat: CombatScreen = main._screen as CombatScreen
	assert(combat != null and combat.act == 2)
	paused = true
	var ground: CombatScreen.Plate
	for plate: CombatScreen.Plate in combat._plates:
		if plate.is_ledge:
			ground = plate
	assert(ground != null)
	var final_material: Material = ground.material
	assert(final_material != null)
	ground.material = null
	ground.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var size_label: String = str(root.size.x)
	assert(root.get_texture().get_image().save_png("/tmp/act3-combat-"+size_label+"-before.png")==OK)
	ground.material = final_material
	ground.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("/tmp/act3-combat-"+size_label+"-after.png")==OK)
	print("GROUND_STUDY single_frozen_scene=true replaced_plates=1 act=2 size=",root.size)
	quit()
