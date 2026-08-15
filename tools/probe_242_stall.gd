extends SceneTree
## Photograph and measure the Night Stall at one shape (#242 slice 3+).
##
## The stall is the one production screen with no route to it from `--shot=`:
## `--enter=` walks a map, and a shop node is not reachable deterministically.
## So this builds the real `ShopScreen` with a full stock, seats it at a shape,
## and either captures it or prints where every ware landed IN IMAGE SPACE —
## which is the space the region book is authored in, so a seat that has drifted
## off the painted shelf shows as a number rather than as a squint.
##
##   tools/shot.sh is for main.gd; this one runs directly, WITHOUT --headless
##   when capturing (headless has no viewport texture and save_png hangs):
##
##   godot --path . --position -4000,-4000 -s res://tools/probe_242_stall.gd -- \
##       --shape=pad-landscape --size=1180x820 --shot=/tmp/stall.png
##   godot --headless -s res://tools/probe_242_stall.gd -- --dump
##
## `--dump` needs no window and prints every shape in the landscape family.

const DUMP_SHAPES: Array[StringName] = [
	&"pad-landscape", &"phone-landscape", &"desktop-landscape",
]


func _initialize() -> void:
	var shape: StringName = StageShape.IDENTITY
	var size: Vector2i = Vector2i.ZERO
	var shot: String = ""
	var dump: bool = false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shape="):
			shape = StringName(arg.trim_prefix("--shape="))
		elif arg.begins_with("--size="):
			var parts: PackedStringArray = arg.trim_prefix("--size=").split("x")
			if parts.size() == 2:
				size = Vector2i(int(parts[0]), int(parts[1]))
		elif arg.begins_with("--shot="):
			shot = arg.trim_prefix("--shot=")
		elif arg == "--dump":
			dump = true
	if dump:
		for one: StringName in DUMP_SHAPES:
			await _run(one, StageShape.REFERENCES[one], "")
		quit(0)
		return
	if not StageShape.REFERENCES.has(shape):
		shape = StageShape.IDENTITY
	if size == Vector2i.ZERO:
		size = StageShape.REFERENCES[shape]
	await _run(shape, size, shot)
	quit(0)


func _run(shape: StringName, size: Vector2i, shot: String) -> void:
	if shot != "":
		DisplayServer.window_set_size(size)
		root.size = size
		root.content_scale_size = size
		await process_frame
	# The full catalogue, not the test slice: the slice carries ONE relic, so a
	# capture taken against it never shows the second counter stand.
	var content: ContentDB = ContentDB.load_full()
	var stock: Dictionary = _stock(content)
	var offer: Dictionary = {
		"id": "flamelessLantern",
		"name": str(content.quests.get("usurper", {}).get("itemName",
			"A Lantern with No Flame")),
		"price": 300,
	}
	var screen: ShopScreen = ShopScreen.new(stock, 260, content, offer, true)
	if shot != "":
		root.add_child(screen)
	screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
	screen.size = Vector2(size)
	screen.set_shape(shape)
	if shot != "":
		await process_frame
		await process_frame
	_report(shape, screen, Vector2(size))
	if shot != "":
		var image: Image = root.get_texture().get_image()
		image.save_png(shot)
		print("shot saved: " + shot)
		root.remove_child(screen)
	screen.free()


## Every seat, back in image space, beside the painted line it is meant to hit.
func _report(shape: StringName, screen: ShopScreen, frame: Vector2) -> void:
	var canvas: Rect2 = StallLayout.canvas(frame)
	print("\n== %s  frame %s  canvas %s  type_scale %.4f" % [
		shape, frame, canvas, StallLayout.type_scale(frame)])
	for entry: Dictionary in screen._slots:
		var control: Control = entry["control"]
		var card: CardView = control as CardView
		var rect: Rect2 = ShopScreen.card_rect(card) if card != null \
			else Rect2(control.position, control.size)
		var tag: WareTag = entry["tag"]
		print("  %-8s %-8s ware v[%.4f..%.4f] u[%.4f..%.4f] %.0fx%.0fpx-img   tag h %.4f  fill %.0f%% (%s)" % [
			entry["kind"], entry["region"],
			(rect.position.y - canvas.position.y) / canvas.size.y,
			(rect.end.y - canvas.position.y) / canvas.size.y,
			(rect.position.x - canvas.position.x) / canvas.size.x,
			(rect.end.x - canvas.position.x) / canvas.size.x,
			rect.size.x / canvas.size.x * StallLayout.IMAGE.x,
			rect.size.y / canvas.size.y * StallLayout.IMAGE.y,
			tag.size.y / canvas.size.y, _fill(tag) * 100.0, _fullest(tag)])
	var band: Rect2 = StallLayout.rack_band(frame)
	print("  rack band %s   say y %.1f (hud %.1f)" % [
		band, screen._say.position.y, screen._hud_band()])


## How full the widest DRAWN row sits in its block, and which row it is.
##
## This is the number CI moves and macOS cannot: Linux measures the same fonts
## wider, so a row already near 100% here is the one that wraps or overruns
## there. `tests/test_stall_layout.gd` asserts run <= block; anything the probe
## reports above ~85% is worth watching on the CI run rather than locally.
static func _fill(tag: WareTag) -> float:
	var worst: float = 0.0
	for row: Dictionary in tag._rows:
		if str(row["wrap"]) == "false":
			worst = maxf(worst, float(str(row["run"])) / maxf(1.0, tag.size.x))
	return worst


static func _fullest(tag: WareTag) -> String:
	var worst: float = 0.0
	var text: String = "-"
	for row: Dictionary in tag._rows:
		if str(row["wrap"]) != "false":
			continue
		var fill: float = float(str(row["run"])) / maxf(1.0, tag.size.x)
		if fill > worst:
			worst = fill
			text = str(row["text"]).left(22)
	return text


func _stock(content: ContentDB) -> Dictionary:
	var cards: Array = []
	for id: Variant in content.cards.keys().slice(0, 5):
		cards.append({"id": str(id), "price": 60, "sold": false})
	var relics: Array = []
	for id: Variant in content.relics.keys().slice(0, 2):
		relics.append({"id": str(id), "price": 150, "sold": false})
	var potions: Array = []
	for id: Variant in content.potions.keys().slice(0, 2):
		potions.append({"id": str(id), "price": 55, "sold": false})
	return {"cards": cards, "relics": relics, "potions": potions,
		"removeCost": 75, "removed": false}
