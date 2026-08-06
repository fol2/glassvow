extends RefCounted
## M6: the pilgrimage graph gates where the lantern may go, and the map screen
## refuses anything the graph refuses. Covers the slice strip shape, the
## reachability walk, and the rest-site heal law.


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_map: %s" % what)


## How many pairs of bounty pills would land on each other. Rects, not spans:
## same-column stones share `world_x` and overlap in x at every camera while
## sitting a lane apart (PR #80 DL R4).
static func _collisions(rects: Array[Rect2]) -> int:
	var hits: int = 0
	for a: int in range(rects.size()):
		for b: int in range(a + 1, rects.size()):
			if rects[a].intersects(rects[b]):
				hits += 1
	return hits


## Every pill the band would paint at `frame_w`, in stage px.
static func _seated_pills(screen: WorldMapScreen) -> Array[Rect2]:
	return _pills_from(screen, screen._chip_band.seats(screen.size.x))


static func _pills_from(screen: WorldMapScreen,
		chosen: Dictionary[int, bool]) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for i: int in chosen:
		var ws: GlassWaystone = screen._waystones[i]
		out.append(MapBand.ChipBand.pill_rect(ws.chip_rect(chosen[i]),
			ws.position, ws.scale))
	return out


## Every field of one node the save projection must carry, keyed so a mismatch
## names what was lost rather than just "not equal". Save schema v2 is frozen
## (SKILL §4) — this comparison is what stands between a projection regression
## and a run that reloads wrong. `reachable` and `edges` are derived from the
## `next` id list, so they also catch a join the projection silently drops.
static func _projected(m: WorldMap, i: int) -> Dictionary:
	var n: MapNode = m.nodes[i]
	var out_edges: Array = m.edges.get(i, [])
	return {
		"id": n.id, "type": n.type, "row": n.row, "col": n.col,
		"next": n.next, "edges": out_edges, "enemies": n.enemies,
		"unlit": n.unlit, "bounty": n.bounty, "affix": n.affix,
		"quest": [n.quest_variant_id, n.quest_marked],
		"cleared": m.cleared.has(i), "reachable": m.reachable().has(i),
	}


## Every chip stone whose STONE is on screen — what the band should paint unless
## a pill genuinely lands on another.
static func _on_screen_chips(screen: WorldMapScreen) -> int:
	var n: int = 0
	for ws: GlassWaystone in screen._waystones:
		if not ws.has_chip():
			continue
		var s: float = ws.scale.x
		if MapBand.ChipBand.on_screen(ws.position.x + ws.size.x * s * 0.5,
				ws.pane_radius() * s, screen.size.x):
			n += 1
	return n


static func run(fails: Array[String]) -> void:
	# ---- one representative benchmark seed: full generator, one RNG stream
	var benchmark_content: ContentDB = ContentDB.load_slice()
	var benchmark_run: RunState = RunState.new_run(benchmark_content, 717, "run-map-golden")
	var generated: WorldMap = WorldMap.benchmark(benchmark_run)
	var type_counts: Dictionary = {}
	var unlit: Array[String] = []
	for generated_node: MapNode in generated.nodes:
		type_counts[generated_node.type] = int(float(str(type_counts.get(generated_node.type, 0)))) + 1
		if generated_node.unlit:
			unlit.append("%s:%d" % [generated_node.id, generated_node.bounty])
	_check(fails, generated.nodes.size() == 65, "benchmark seed 717 has 65 joined nodes")
	_check(fails, type_counts == {
		"monster": 34, "event": 9, "elite": 5, "treasure": 5,
		"shop": 2, "rest": 9, "boss": 1,
	}, "benchmark seed 717 node type distribution")
	_check(fails, generated.reachable().size() == 4, "seed 717 opens four distinct row-zero nodes")
	_check(fails, unlit == ["1,3:17", "6,3:17", "11,5:13", "9,5:14", "3,2:20", "7,0:20"],
		"seed 717 unlit bounty trace")
	_check(fails, benchmark_run.rng_state() == 721837281, "seed 717 consumes the benchmark RNG trace")
	# The projection is a contract, not a smoke test: field-by-field against the
	# generator's own map, because a count alone passes on a map that came back
	# with every join, bounty and affix stripped.
	var generated_copy: WorldMap = WorldMap.from_dict(generated.to_dict())
	var drift: Array[String] = []
	if generated_copy == null or generated_copy.nodes.size() != generated.nodes.size():
		drift.append("the node list itself")
	else:
		if generated_copy.region != generated.region or generated_copy.at != generated.at:
			drift.append("region/marker")
		for i: int in range(generated.nodes.size()):
			if _projected(generated_copy, i) != _projected(generated, i):
				drift.append(generated.nodes[i].id)
	_check(fails, drift.is_empty(),
		"benchmark map survives its save projection (lost: %s)" % ", ".join(drift))
	# `at` and the cleared set only mean something once the lantern has moved,
	# and `generated` is read pristine further down — so walk a copy.
	var walked: WorldMap = WorldMap.from_dict(generated.to_dict())
	walked.enter(walked.reachable()[0])
	walked.clear_current()
	var walked_copy: WorldMap = WorldMap.from_dict(walked.to_dict())
	_check(fails, walked_copy != null and walked_copy.at == walked.at
		and walked_copy.cleared == walked.cleared
		and walked_copy.reachable() == walked.reachable(),
		"a walked map's marker, cleared set and open waystones survive the projection")
	# ---- one lifecycle law: bosses move through all three authored acts
	var full: ContentDB = ContentDB.load_full()
	var lifecycle: RunState = RunState.new_run(full, 919, "run-three-acts", {"reveals": null})
	lifecycle.player.hp = 1
	lifecycle.start_next_act(full)
	var second: WorldMap = WorldMap.benchmark(lifecycle)
	lifecycle.player.hp = 1
	lifecycle.start_next_act(full)
	var third: WorldMap = WorldMap.benchmark(lifecycle)
	_check(fails, lifecycle.act == 2 and lifecycle.omens.size() == 3,
		"two boss transitions reach the third act with one omen per act")
	_check(fails, second.region == "sunken_city" and third.region == "obsidian_spire",
		"boss transitions replace the map theme")
	_check(fails, lifecycle.player.hp == 26,
		"each boss transition mends 35 percent without exceeding max HP")

	# ---- the authored strip matches the M5 encounter ladder (brief §4)
	var m: WorldMap = WorldMap.slice()
	_check(fails, m.region == "ashen_woods", "slice region is the Ashen Woods")
	_check(fails, m.nodes.size() == 5, "slice has 5 waystones")
	var types: Array[String] = []
	for n: MapNode in m.nodes:
		types.append(n.type)
	_check(fails, types == ["monster", "monster", "monster", "rest", "elite"],
		"strip reads monster×3 → rest → elite")
	_check(fails, m.nodes[0].enemies == ["sporeling", "sporeling"], "n0 is the sporeling pair")
	_check(fails, m.nodes[1].enemies == ["duskfang"], "n1 duskfang")
	_check(fails, m.nodes[2].enemies == ["waylayer"], "n2 waylayer")
	_check(fails, m.nodes[4].enemies == ["gravewarden"], "n4 gravewarden")
	_check(fails, m.nodes[4].affix == null, "elite affix stays null — start_combat rolls it")
	_check(fails, m.nodes[0].combat_kind() == "normal", "monster starts a normal combat")
	_check(fails, m.nodes[4].combat_kind() == "elite", "elite starts an elite combat")
	_check(fails, not m.nodes[3].is_combat(), "rest is not a fight")
	for i: int in range(m.nodes.size()):
		_check(fails, m.nodes[i].world_x == i, "n%d sits at world_x %d" % [i, i])

	# ---- reachability: stand on it, or step to an out-edge
	_check(fails, m.reachable() == [0], "the road opens on n0 only")
	_check(fails, not m.enter(3), "cannot skip ahead to the rest site")
	_check(fails, m.at == 0, "a refused move leaves the marker seated")
	_check(fails, m.enter(0), "entering the node under the marker is legal")
	_check(fails, m.reachable() == [0], "an unresolved node stays the only choice")
	m.clear_current()
	_check(fails, m.is_cleared(0), "n0 reads cleared")
	_check(fails, m.reachable() == [1], "clearing n0 opens n1")
	for i: int in range(1, 5):
		_check(fails, m.enter(i), "walk reaches n%d" % i)
		m.clear_current()
	_check(fails, m.is_finished(), "the strip ends after the elite")

	# ---- the screen never opens a road the graph closed
	var content: ContentDB = ContentDB.load_slice()
	var walk: WorldMap = WorldMap.slice()
	var screen: WorldMapScreen = WorldMapScreen.new(walk, content)
	screen.instant = true
	var seen: Array[int] = []
	screen.node_chosen.connect(func(i: int) -> void: seen.append(i))
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	# The far bands' bleed must cover the drift they are painted with, and the
	# strip filenames must stay 1-based against 0-based act indices.
	_check(fails, MapBand.FAR_BLEED >= WorldMapScreen.PATH_DRIFT_AMP.y / 3.0,
		"far-band bleed covers the far drift amplitude")
	_check(fails, MapStrip.path_for(0, &"skyband")
		== "res://assets/art/map/act1-skyband.png", "strip paths are 1-based")
	_check(fails, MapRegions.SPIRE_W_RATE.size() == 3
		and MapRegions.SPIRE_H_RATE.size() == 3
		and MapRegions.SPIRE_DARKEN.size() == 3, "spire ramps cover three acts")
	# A same-lane edge must actually run straight. `signf(to.y - from.y)` gave it
	# the full 10px bow off a sub-pixel jitter difference for three phases while
	# the comment above it said otherwise (#69); 1.53px is the worst same-lane
	# endpoint gap on seed 717, and a full lane step must still bow the full 10.
	var flat_from: Vector2 = Vector2(0.0, 100.0)
	var flat_mid: float = screen.edge_control(flat_from,
		Vector2(200.0, 101.53)).y - 100.765
	var step_mid: float = screen.edge_control(flat_from,
		Vector2(200.0, 100.0 + screen._lane_gap())).y - (100.0 + screen._lane_gap() * 0.5)
	_check(fails, absf(flat_mid) < 1.0, "a same-lane edge bows under 1px")
	_check(fails, absf(step_mid - 10.0) < 0.01, "a full lane step still bows 10px")
	# The terminus arch must fit the frame it is seated in, on every shape. The
	# seat and the arch's size are separate book values that nothing tied
	# together: `terminusSeat` reaches 0.95 and `trail/scale` 2.0, and 0.72
	# against phone-portrait's `scale` 0.68 already ran the arch 8.7px off a
	# 390px frame once (#69, PR #79 DL R1). Off-tree so `size` is the shape's
	# reference and no layout pass reclaims it.
	#
	# Assert the WORST realisation, not the nominal seat. The boss is drawn at
	# its own `jy` wander plus the pointer lean, both on the step axis and both
	# about the size of the margin being defended — and the seed belongs to a
	# run, so a gate on one realisation guards one run (PR #79 DL R3).
	var lean: float = WorldMapScreen.STEP_JITTER * WorldMap.JITTER_SPREAD.y * 0.5 \
		+ WorldMapScreen.PATH_DRIFT_AMP.x
	for shape_name: StringName in StageShape.REFERENCES:
		var reference: Vector2i = StageShape.REFERENCES[shape_name]
		var probe: WorldMapScreen = WorldMapScreen.new(WorldMap.slice(), content)
		probe.set_anchors_preset(Control.PRESET_TOP_LEFT)
		probe.size = Vector2(reference)
		probe.set_shape(shape_name)
		var seat_x: float = probe.size.x * probe._trail_num("terminusSeat", 0.72)
		var arch: float = probe.arch_radius(probe.terminus_depth(), probe.size.y)
		_check(fails, seat_x + lean + arch <= probe.size.x,
			"the terminus arch fits inside %s (%.1f + %.1f lean + %.1f vs %.0f)"
				% [shape_name, seat_x, lean, arch, probe.size.x])
		probe.free()
	# The road plane's taper, over the shape matrix (#69 A7/C5, #70). Three laws:
	# it never inverts, it never grows wide enough to swallow the lane the stones
	# stand in, and it is actually widest at the camera's seat — a taper that
	# stopped tapering would still satisfy the first two and would be a rectangle
	# with a gradient, which is what this task replaced.
	for shape_name: StringName in StageShape.REFERENCES:
		var road: WorldMapScreen = WorldMapScreen.new(WorldMap.slice(), content)
		road.set_anchors_preset(Control.PRESET_TOP_LEFT)
		road.size = Vector2(StageShape.REFERENCES[shape_name])
		road.set_shape(shape_name)
		var w_px: float = road.size.x
		var widest: float = road.bed_half(road._lead_px())
		var lane_room: float = road.lane_pitch(0.0) * 0.5
		var inverted: bool = false
		for step_i: int in range(0, 41):
			var probe_x: float = w_px * float(step_i) / 40.0
			var half: float = road.bed_half(probe_x)
			if half <= 0.0:
				inverted = true
			if half > widest:
				widest = half
		_check(fails, not inverted, "the road bed never inverts on %s" % shape_name)
		_check(fails, is_equal_approx(widest, road.bed_half(road._lead_px())),
			"the bed is widest at the camera's seat on %s" % shape_name)
		# BOTH edges, read directly — not the minimum anywhere on the frame.
		# The first version tracked `thinnest` over the probe sweep, and PR #84
		# PM R1 broke it with a taper that dipped to 0.8 between depth 0.5 and
		# 1.5 and then widened back to 1.0 at the far edge: a road that narrows
		# in the middle and flares at the rim passed a gate whose message says
		# "by the frame edge". `<=` because the message says "at least a tenth"
		# and `<` rejected exactly a tenth.
		var left_edge: float = road.bed_half(0.0)
		var right_edge: float = road.bed_half(w_px)
		_check(fails, left_edge <= widest * 0.9 and right_edge <= widest * 0.9,
			"…and has narrowed at least a tenth AT BOTH frame edges on %s (%.2f | %.2f vs %.2f)"
				% [shape_name, left_edge, right_edge, widest])
		_check(fails, widest * MapBand.PathBand.VERGE <= lane_room,
			"the road and its verge stay out of the next lane on %s (%.1f vs %.1f)"
				% [shape_name, widest * MapBand.PathBand.VERGE, lane_room])
		road.free()
	# The bed keys must be AUTHORED, not merely resolvable. `LayoutBook.resolve`
	# inserts every declared default through `_defaults()` before `_audit()` runs,
	# so deleting these three from the JSON leaves the book validating cleanly
	# and the road silently running on schema defaults — the schema/JSON
	# atomicity this task claimed was never enforced for the added-key case
	# (PR #84 PM R1). Read the raw file, not the resolved book.
	var book_raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://assets/layout/combat-layout.json"))
	var authored: Dictionary = {}
	if typeof(book_raw) == TYPE_DICTIONARY:
		var book: Dictionary = book_raw
		if book.has("scopes"):
			var scopes: Dictionary = book["scopes"]
			if scopes.has("map"):
				var map_scope: Dictionary = scopes["map"]
				if map_scope.has("base"):
					authored = map_scope["base"]
	for key: String in ["bedRate", "bedMin", "bedMax"]:
		_check(fails, authored.has(key),
			"combat-layout.json authors scopes.map.base.%s" % key)
	# A refresh mid-glide must RE-AIM, not seat. `set_shape` routes through
	# `refresh` → `_seat_marker`, and a hard `_cam_x` write there tore the walk
	# out from under the lantern when the window crossed an aspect boundary
	# during a travel (#69 B2). Seated: both move. Travelling: only the target.
	# The bounty chip flips to the stone's left rather than run off the frame.
	# 11% of camera positions per column put the pill past the right edge and
	# rendered "+17" as "+1" (#69 D1, PR #80 DL R1) — a window narrow enough that
	# a capture finds it by luck, so the rule is asserted instead.
	_check(fails, not MapBand.ChipBand.flips(600.0, 60.0, 1180.0),
		"a chip with room on the right stays right")
	_check(fails, MapBand.ChipBand.flips(1145.0, 60.0, 1180.0),
		"a chip that would leave the frame flips left")
	_check(fails, not MapBand.ChipBand.flips(30.0, 60.0, 100.0),
		"a chip with room on neither side does not trade edges")
	# …and the reachable failure the flip rule never covered: the STONE leaving
	# the frame while its pill does not. The seat is horizontal, so the pill
	# reaches ~49 stage px from a centre whose own ink reaches ~20 — a 29px band
	# at each edge, 12% of a node step, where a `+17` is drawn with no lantern
	# under it. Both edges photographed (#69 D1, PR #80 DL R2 MAJOR). The three
	# `flips` cases above assert a rule; these assert that it is asked at all.
	_check(fails, MapBand.ChipBand.on_screen(600.0, 20.0, 1180.0),
		"a stone in the middle of the frame draws its chip")
	_check(fails, not MapBand.ChipBand.on_screen(1205.0, 20.0, 1180.0),
		"a stone past the right edge draws no chip, flipped or not")
	_check(fails, not MapBand.ChipBand.on_screen(-30.0, 20.0, 1180.0),
		"a stone past the left edge draws no orphan pill on the road")
	_check(fails, MapBand.ChipBand.on_screen(1179.0, 20.0, 1180.0),
		"a stone still touching the right edge keeps its chip")
	# Pointer drift sweeps a stone's flip input 28 stage px with no pan at all,
	# so the threshold needs a band wider than that or the pill pops sides while
	# the player only moves the cursor (PR #80 DL R2).
	_check(fails, MapBand.ChipBand.FLIP_SLACK > 2.0 * WorldMapScreen.PATH_DRIFT_AMP.x,
		"the flip's hysteresis outruns the pointer drift that would cross it")
	_check(fails, MapBand.ChipBand.flips(1120.0, 60.0, 1180.0, true)
			and not MapBand.ChipBand.flips(1120.0, 60.0, 1180.0, false),
		"a flipped chip keeps its side inside the slack a fresh one would not take")
	# …and that the band ASKS. `flips` was pure and asserted for two rounds while
	# `_draw` painted every chip unconditionally, so a green suite and a `+17`
	# alone on the road were consistent with each other. Hold the DECISION, on
	# the real seed-717 geometry, not just the rule.
	var chip_screen: WorldMapScreen = WorldMapScreen.new(generated, benchmark_content)
	chip_screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
	chip_screen.size = Vector2(StageShape.REFERENCES[StageShape.IDENTITY])
	tree.root.add_child(chip_screen)
	chip_screen._layout_waystones()
	var chip_band: MapBand.ChipBand = chip_screen._chip_band
	var seated: Dictionary[int, bool] = chip_band.seats(chip_screen.size.x)
	_check(fails, not seated.is_empty(),
		"seed 717 seats at least one bounty chip on the opening frame")
	var orphan: int = seated.keys()[0]
	var stone: GlassWaystone = chip_screen._waystones[orphan]
	stone.position.x = chip_screen.size.x + 60.0
	_check(fails, not chip_band.seats(chip_screen.size.x).has(orphan),
		"a stone walked off the right edge takes its chip with it")
	stone.position.x = -300.0
	_check(fails, not chip_band.seats(chip_screen.size.x).has(orphan),
		"…and off the left edge, where the pill would sit alone on the road")
	tree.root.remove_child(chip_screen)
	chip_screen.free()
	# The seed-17634 pair, made a fixture: two same-lane bounty stones at
	# phone-portrait measure 100 stage px apart against 2 × 58.6 of reach, so the
	# right one's frame-flip painted its pill 17 px into the left one's and left
	# `+16` reading as its first digit. Found independently by capture and by
	# probe (PR #80 DL R3 and the PM's third pass) — a case a capture finds by
	# luck and a gate finds every run.
	var sib_run: RunState = RunState.new_run(benchmark_content, 17634, "run-siblings")
	var sib: WorldMapScreen = WorldMapScreen.new(WorldMap.benchmark(sib_run), benchmark_content)
	sib.set_anchors_preset(Control.PRESET_TOP_LEFT)
	sib.size = Vector2(StageShape.REFERENCES[&"phone-portrait"])
	tree.root.add_child(sib)
	sib.set_shape(&"phone-portrait")
	sib._cam_x = 627.53
	sib._layout_waystones()
	var raw: Array[Rect2] = []
	for ws: GlassWaystone in sib._waystones:
		if not ws.has_chip():
			continue
		var s: float = ws.scale.x
		var c: float = ws.position.x + ws.size.x * s * 0.5
		if not MapBand.ChipBand.on_screen(c, ws.pane_radius() * s, sib.size.x):
			continue
		raw.append(MapBand.ChipBand.pill_rect(
			ws.chip_rect(MapBand.ChipBand.flips(c, ws.chip_reach() * s, sib.size.x)),
			ws.position, ws.scale))
	var sib_chosen: Dictionary[int, bool] = sib._chip_band.seats(sib.size.x)
	var pills: Array[Rect2] = _pills_from(sib, sib_chosen)
	_check(fails, _collisions(raw) >= 1,
		"seed 17634 at cam 627.53 still reproduces the sibling collision to guard against")
	_check(fails, _collisions(pills) == 0, "no bounty pill is painted over another")
	# `_collisions == 0` is satisfied by painting NOTHING, so the decline needs a
	# ceiling as well as a floor: exactly one chip may be dropped here, and the
	# other on-screen chips must survive (PR #80 DL R4 MINOR).
	_check(fails, _on_screen_chips(sib) - pills.size() == 1,
		"exactly one chip is declined at the collision, not the frame's worth")
	# Pin WHICH pair, not just a count. `_collisions(raw) >= 1` is satisfied by
	# any collision, so the fixture could drift onto a different pair on a
	# different generator and still read green (PR #80 PM R4). n6 `+16` is the
	# left one and keeps its place; n7 `+22` is the one that would have flipped
	# onto it.
	# One call, reused: `seats()` writes `_flipped`, so asking twice and treating
	# the answers as one decision assumes an idempotence it does not promise
	# (DL R5 NIT).
	var sib_seats: Dictionary[int, bool] = sib_chosen
	_check(fails, sib._waystones[6].bounty == 16 and sib._waystones[7].bounty == 22,
		"seed 17634 still generates the +16 / +22 pair this fixture is about")
	_check(fails, sib_seats.has(6) and not sib_seats.has(7),
		"the pill already on the road keeps it, and the one that would bury it declines")
	# `chip_rect` became the single definition of the pill and nothing watched it:
	# `CHIP_GAP` 4→7 moved every pill on the map 3px and `CHIP_H` 19→30 grew it by
	# 58%, and the suite stayed green through both (PR #80 DL R5). The two
	# authored numbers are pinned here so moving the seat has to be deliberate,
	# and the mirror is pinned because it is a law rather than a value.
	var pin: GlassWaystone = sib._waystones[6]
	var pin_centre: Vector2 = pin._pad \
		+ Vector2(GlassWaystone.WIDTH, GlassWaystone.EMBLEM_H) * 0.5
	var pin_right: Rect2 = pin.chip_rect(false)
	var pin_left: Rect2 = pin.chip_rect(true)
	_check(fails, is_equal_approx(pin_right.size.y, 19.0),
		"the bounty pill stands 19 local px tall")
	_check(fails, is_equal_approx(
			pin_right.position.x - (pin_centre.x + pin.pane_radius()), 4.0),
		"…and starts 4 local px past the pane it labels")
	_check(fails, is_equal_approx(pin_right.get_center().y, pin_centre.y),
		"…centred on the emblem, not on the padded touch rect")
	_check(fails, is_equal_approx(pin_right.get_center().x - pin_centre.x,
			pin_centre.x - pin_left.get_center().x),
		"…and a flip mirrors it about the stone rather than re-seating it")
	# The over-decline itself, at the camera where three same-column stones share
	# the frame: judged on x alone the band dropped two of them, and a dark
	# lantern's bounty appears nowhere else in the game (DL R4 MAJOR).
	sib._cam_x = 1250.0
	sib._layout_waystones()
	var wide: Array[Rect2] = _seated_pills(sib)
	_check(fails, _on_screen_chips(sib) >= 3,
		"seed 17634 at cam 1250 still puts three chip stones in one frame")
	_check(fails, wide.size() == _on_screen_chips(sib),
		"stones a lane apart keep their prices — a shared column is not a collision")
	_check(fails, _collisions(wide) == 0, "…and still none is painted over another")
	tree.root.remove_child(sib)
	sib.free()
	# Drive the real door — resize, then `set_shape` → `refresh` → `_seat_marker`
	# — with the marker walked off node 0 and `_cam_target` seeded wrong. Both
	# matter: `_cam_for(0)` clamps to `_cam_min()` on every shape and
	# construction already seats the target there, so a re-aim assertion taken at
	# node 0 passes whether or not anything re-aims (PM R1 on PR #80).
	# Full content, not the slice: `refresh(run)` re-reads `content.acts[act]` for
	# the title line, which the slice does not carry.
	var glide_run: RunState = RunState.new_run(full, 717, "run-glide")
	var glider: WorldMapScreen = WorldMapScreen.new(WorldMap.slice(), full)
	glider.set_anchors_preset(Control.PRESET_TOP_LEFT)
	glider.size = Vector2(StageShape.REFERENCES[StageShape.IDENTITY])
	tree.root.add_child(glider)
	glider.refresh(glide_run)
	glider.map.enter(0)
	glider.map.clear_current()
	glider.map.enter(1)
	glider.map.clear_current()
	glider.map.enter(2)
	glider.size = Vector2(StageShape.REFERENCES[&"phone-portrait"])
	glider._cam_x = 999.0
	glider._cam_target = -777.0
	glider._travelling = true
	glider.set_shape(&"phone-portrait")
	var aim: float = glider._cam_for(glider.map.at)
	_check(fails, aim > 1.0,
		"the mid-glide gate stands where the camera's clamps do not decide the seat")
	_check(fails, is_equal_approx(glider._cam_x, 999.0),
		"a shape re-pick mid-glide leaves the camera where the walk put it")
	_check(fails, is_equal_approx(glider._cam_target, aim),
		"…and re-aims the target at the new shape's geometry")
	glider._travelling = false
	glider.size = Vector2(StageShape.REFERENCES[StageShape.IDENTITY])
	glider.set_shape(StageShape.IDENTITY)
	_check(fails, is_equal_approx(glider._cam_x, glider._cam_for(glider.map.at)),
		"a shape re-pick while seated still seats the camera")
	tree.root.remove_child(glider)
	glider.free()
	_check(fails, screen._waystones.size() == 5, "one waystone per node")
	_check(fails, not screen.choose(2), "screen refuses an unreachable waystone")
	_check(fails, seen.is_empty(), "a refused choice hands off nothing")
	_check(fails, screen.choose(0), "screen accepts the open waystone")
	_check(fails, seen == [0], "arrival hands the node index to the router")
	_check(fails, walk.at == 0, "the graph moved with the marker")
	screen.refresh(null)
	_check(fails, screen._waystones[0].reachable, "n0 is still live until it is cleared")
	walk.clear_current()
	screen.refresh(null)
	_check(fails, screen._waystones[0].cleared and not screen._waystones[0].reachable,
		"a cleared waystone goes dark")
	_check(fails, screen._waystones[1].reachable, "and lights the next one")
	tree.root.remove_child(screen)
	screen.free()

	# ---- rest heals 30% of max HP, clamped (web engine.js restHealFrac) — asked
	# of the two functions the rest screen itself calls: RewardRules for the
	# fraction, Main for the rounding.
	# Full content, as a live run loads it: the slice fixture authors no vows or
	# omens, so it cannot see the clamp at all.
	var rest_rules: RewardRules = RewardRules.new(full)
	var core_frac: float = rest_rules.rest_heal_fraction(RunState.new_run(full, 717, "run-rest"))
	_check(fails, Main.rest_heal_amount(72, core_frac) == 22, "rest heals 22 of a 72 HP pool")
	_check(fails, Main.rest_heal_amount(0, core_frac) == 0, "no pool, no heal")
	# The clamp half of `min(0.3, omen, vow)`: vow 5 carries restHealFrac 0.2.
	var vowed: RunState = RunState.new_run(full, 717, "run-rest-vow", {"vow": 5})
	_check(fails, Main.rest_heal_amount(72, rest_rules.rest_heal_fraction(vowed)) == 14,
		"a vow that dims the hearth clamps the rest heal under 30%")
