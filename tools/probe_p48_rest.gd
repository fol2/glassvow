extends SceneTree
## Throwaway probe for the P4.8 overlay-choice verification. Domain-only: walks
## a fresh run's map to the last row before the guaranteed rest row (ROWS-2),
## clearing nodes without fighting, and stores the save. A live host booted
## afterwards continues this run one click away from the rest screen, whose
## TEMPER A CARD choice is one of the five P4.8 scrim overlays.
##   godot --headless -s res://tools/probe_p48_rest.gd


func _initialize() -> void:
	var content: ContentDB = ContentDB.load_slice()
	var run: RunState = RunState.new_run(content, 20260801)
	var m: WorldMap = WorldMap.benchmark(run)
	while true:
		var open: Array[int] = m.reachable()
		if open.is_empty():
			print("walk stuck at row ", m.current().row if m.current() != null else -1)
			quit(1)
			return
		if not m.enter(open[0]):
			print("enter refused: ", open[0])
			quit(1)
			return
		m.clear_current()
		if m.current().row >= WorldMap.ROWS - 3:
			break
	run.map = m.to_dict()
	if not SaveService.store(run):
		print("save failed")
		quit(1)
		return
	print("saved at row ", m.current().row, " — next reachable: ", m.reachable())
	quit(0)
