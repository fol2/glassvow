extends SceneTree
## Throwaway probe for the P4.10 RunHud diff refresh. Proves the four claims
## the diff makes: a refresh with unchanged data keeps the same controls,
## keyboard focus survives that tick, a potion change rebuilds the right
## cluster, and a relic change rebuilds the collection. Exits 1 on any FAIL.
##   godot --path . --position -4000,-4000 -s res://tools/probe_p410_diff.gd


func _initialize() -> void:
	var host: Control = Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var content: ContentDB = ContentDB.load_slice()
	var run: RunState = RunState.new_run(content, 12345)
	var hud: RunHud = RunHud.new(run, content)
	host.add_child(hud)
	hud.refresh(run)
	await process_frame

	var right: HBoxContainer = hud._right
	var deck: Button = right.get_child(right.get_child_count() - 2) as Button
	var deck_id: int = deck.get_instance_id()
	var seat_id: int = right.get_child(0).get_instance_id()
	deck.grab_focus()
	await process_frame

	hud.refresh(run)
	await process_frame
	var same_deck: bool = right.get_child(right.get_child_count() - 2) \
		.get_instance_id() == deck_id
	var same_seat: bool = right.get_child(0).get_instance_id() == seat_id
	var focus_held: bool = hud.get_viewport().gui_get_focus_owner() == deck
	print("skip keeps controls: ", "PASS" if same_deck and same_seat else "FAIL")
	print("focus survives tick: ", "PASS" if focus_held else "FAIL")

	run.player.potions[0] = content.potions.keys()[0]
	hud.refresh(run)
	await process_frame
	var rebuilt: bool = right.get_child(right.get_child_count() - 2) \
		.get_instance_id() != deck_id
	print("potion change rebuilds: ", "PASS" if rebuilt else "FAIL")

	var coll_id: int = 0
	if hud._collection.get_child_count() > 0:
		coll_id = hud._collection.get_child(0).get_instance_id()
	run.player.relics.append(content.relics.keys()[0])
	hud.refresh(run)
	await process_frame
	var coll_rebuilt: bool = hud._collection.get_child_count() > 0 \
		and hud._collection.get_child(0).get_instance_id() != coll_id
	print("relic change rebuilds: ", "PASS" if coll_rebuilt else "FAIL")
	var all_pass: bool = same_deck and same_seat and focus_held \
		and rebuilt and coll_rebuilt
	quit(0 if all_pass else 1)
