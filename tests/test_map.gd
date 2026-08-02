extends RefCounted
## M6: the pilgrimage graph gates where the lantern may go, and the map screen
## refuses anything the graph refuses. Covers the slice strip shape, the
## reachability walk, and the rest-site heal law.


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_map: %s" % what)


## How many pairs of bounty pills would land on each other, given their spans.
static func _collisions(spans: Array[Vector2]) -> int:
	var hits: int = 0
	for a: int in range(spans.size()):
		for b: int in range(a + 1, spans.size()):
			if MapBand.ChipBand.spans_overlap(spans[a], spans[b]):
				hits += 1
	return hits


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
	var generated_copy: WorldMap = WorldMap.from_dict(generated.to_dict())
	_check(fails, generated_copy != null and generated_copy.nodes.size() == 65,
		"benchmark map survives its save projection")
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
	var raw: Array[Vector2] = []
	for ws: GlassWaystone in sib._waystones:
		if not ws.has_chip():
			continue
		var s: float = ws.scale.x
		var c: float = ws.position.x + ws.size.x * s * 0.5
		if not MapBand.ChipBand.on_screen(c, ws.pane_radius() * s, sib.size.x):
			continue
		raw.append(MapBand.ChipBand.pill_span(c, ws.chip_inner() * s, ws.chip_reach() * s,
			MapBand.ChipBand.flips(c, ws.chip_reach() * s, sib.size.x)))
	var pills: Array[Vector2] = []
	var chosen: Dictionary[int, bool] = sib._chip_band.seats(sib.size.x)
	for i: int in chosen:
		var ws: GlassWaystone = sib._waystones[i]
		var s: float = ws.scale.x
		pills.append(MapBand.ChipBand.pill_span(ws.position.x + ws.size.x * s * 0.5,
			ws.chip_inner() * s, ws.chip_reach() * s, chosen[i]))
	_check(fails, _collisions(raw) >= 1,
		"seed 17634 at cam 627.53 still reproduces the sibling collision to guard against")
	_check(fails, _collisions(pills) == 0, "no bounty pill is painted over another")
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

	# ---- rest heals 30% of max HP, clamped (web engine.js restHealFrac)
	_check(fails, Main.rest_heal_amount(72) == 22, "rest heals 22 of a 72 HP pool")
	_check(fails, Main.rest_heal_amount(0) == 0, "no pool, no heal")
