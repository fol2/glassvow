extends RefCounted
## #270 acceptance: headless N-run planting. No post-reveal line fires
## pre-reveal, and every twist-critical plant occupies ≥2 slots before payoff.
## SLOT_LEVEL is an independent handwritten fixture from 00-truth.md §5 and
## 04-delivery.md's per-channel ceiling table — never derived from a row's
## own conditions, so a row that loses its gate must fail.

const RUNS: int = 24
## slot → minimum reveal level that may fire. This fixture is the sole
## reveal gate — including for asserts.plant / asserts.payoff rows — so a
## dual-reading plant in a shard-0-reachable pool is allowed at shards 0.
## Pool slots are shard-0 reachable (04-delivery loss/hearth/waystone);
## whisper and Own Shade death are L1; quest closers L2; sixth-shard closer L3.
const SLOT_LEVEL: Dictionary = {
	"whisper": 1,
	"death.ownShade1": 1,
	"death.ownShade2": 1,
	"death.ownShade3": 1,
	"closer.ownShade": 2,
	"closer.usurper": 2,
	"closer.eighthOmen": 2,
	"closer.l3": 3,
	"hearth": 0,
	"waystone": 0,
	"loss": 0,
}


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_narrative_planting: %s" % what)


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	var rows: Array = content.line_table
	_simulate(rows, fails)
	var mutated: Array = _copy_rows(rows)
	var shade2: Dictionary = LineTable.row_by_id(mutated, "death.ownShade2")
	_check(fails, not shade2.is_empty(), "shipping table has no death.ownShade2")
	if shade2.is_empty():
		return
	shade2["conditions"] = {}
	var mutated_fails: Array[String] = []
	_simulate(mutated, mutated_fails)
	_check(fails, not mutated_fails.is_empty(),
		"removing death.ownShade2's condition did not report a planting violation")


static func _simulate(rows: Array, fails: Array[String]) -> void:
	var plants: Dictionary = {}
	var payoffs: Dictionary = {}
	for row_v: Variant in rows:
		if typeof(row_v) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_v
		var asserts_v: Variant = row.get("asserts", {})
		if typeof(asserts_v) != TYPE_DICTIONARY:
			continue
		var asserts: Dictionary = asserts_v
		var plant: String = str(asserts.get("plant", ""))
		if not plant.is_empty():
			if not plants.has(plant):
				plants[plant] = []
			plants[plant].append(str(row.get("id", "")))
		var payoff: String = str(asserts.get("payoff", ""))
		if not payoff.is_empty():
			payoffs[payoff] = str(row.get("id", ""))
	_check(fails, not plants.is_empty() and not payoffs.is_empty(),
		"shipping table has no twist-critical plants")

	var slots: PackedStringArray = _slots_of(rows)
	for slot: String in slots:
		_check(fails, SLOT_LEVEL.has(slot), "SLOT_LEVEL fixture omits slot %s" % slot)
	for key_v: Variant in SLOT_LEVEL:
		var key: String = str(key_v)
		_check(fails, slots.has(key), "SLOT_LEVEL fixture has stale slot %s" % key)

	for plant_id_v: Variant in plants:
		var plant_id: String = str(plant_id_v)
		var occupied_slots: Dictionary = {}
		for id_v: Variant in plants[plant_id]:
			var plant_row: Dictionary = LineTable.row_by_id(rows, str(id_v))
			var plant_slot: String = str(plant_row.get("slot", ""))
			occupied_slots[plant_slot] = true
			_check(fails, SLOT_LEVEL.has(plant_slot),
				"plant %s row %s uses slot %s missing from SLOT_LEVEL"
				% [plant_id, str(id_v), plant_slot])
		if plant_id == "standing-stone":
			_check(fails, occupied_slots.has("waystone") and occupied_slots.has("loss"),
				"standing-stone plants are not in the batch-3 waystone/loss slots")
			for occupied_slot_v: Variant in occupied_slots:
				var occupied_slot: String = str(occupied_slot_v)
				_check(fails, int(float(str(SLOT_LEVEL.get(occupied_slot, 99)))) == 0,
					"standing-stone slot %s is not shard-0 reachable in SLOT_LEVEL" % occupied_slot)

	# A plant may fire at shard 0 — that is what planting means. A payoff may
	# not: it reads the twist out loud. The fixture gates by slot, so a payoff
	# authored into a shard-0-reachable pool would pass every other check here.
	for row_v: Variant in rows:
		var row: Dictionary = row_v
		var asserts_v: Variant = row.get("asserts", {})
		if typeof(asserts_v) != TYPE_DICTIONARY:
			continue
		var asserts: Dictionary = asserts_v
		if str(asserts.get("payoff", "")).is_empty():
			continue
		var payoff_slot: String = str(row.get("slot", ""))
		_check(fails, int(float(str(SLOT_LEVEL.get(payoff_slot, 0)))) > 0,
			"payoff row %s sits in shard-0-reachable slot %s"
			% [str(row.get("id")), payoff_slot])

	var plant_slots: Dictionary = {}
	var payoff_ready: Dictionary = {}
	for plant_id_v: Variant in plants:
		plant_slots[str(plant_id_v)] = {}
		payoff_ready[str(plant_id_v)] = false

	var rng: Rng = Rng.new(270)
	var once: Array = []
	var recent: Array = []
	var last_id: String = ""
	for n: int in range(RUNS):
		var shards: int = _shards_for(n)
		var ctx: Dictionary = {"shards": shards, "act": 0, "quests": {}}
		var drawn: Array = []
		var memory: Dictionary = {"recent": recent, "once": once, "last_id": last_id}
		for row_v: Variant in rows:
			if typeof(row_v) != TYPE_DICTIONARY:
				continue
			var row: Dictionary = row_v
			if not LineTable.conditions_match(row.get("conditions", {}), ctx):
				continue
			var slot: String = str(row.get("slot", ""))
			var need: int = int(float(str(SLOT_LEVEL.get(slot, 99))))
			_check(fails, _ladder(shards) >= need,
				"row %s (slot %s) fired at shards %d; fixture requires L%d"
				% [str(row.get("id")), slot, shards, need])
		for slot: String in slots:
			if not LineTable.slot_open(rows, slot, ctx):
				continue
			var picked: Dictionary = LineTable.select(rows, slot, ctx, rng, memory)
			if picked.is_empty():
				continue
			_check(fails, LineTable.conditions_match(picked.get("conditions", {}), ctx),
				"select returned a line whose conditions fail at shards %d" % shards)
			var id: String = str(picked.get("id", ""))
			drawn.append(id)
			if picked.get("once", false) and not once.has(id):
				once.append(id)
			_note_plant(picked, str(picked.get("slot", "")), plant_slots, payoff_ready,
				payoffs, fails, n)
		recent = LineTable.remember(recent, drawn)
		if not drawn.is_empty():
			last_id = str(drawn[drawn.size() - 1])

	for plant_id_v: Variant in plants:
		var plant_id: String = str(plant_id_v)
		var occupied: Dictionary = plant_slots[plant_id]
		_check(fails, occupied.size() >= 2,
			"plant %s occupied %d slot(s) before payoff" % [plant_id, occupied.size()])
		if payoffs.has(plant_id):
			var reached: bool = false
			if payoff_ready[plant_id]:
				reached = true
			_check(fails, reached,
				"plant %s never reached its payoff" % plant_id)


static func _copy_rows(rows: Array) -> Array:
	var out: Array = []
	for row_v: Variant in rows:
		if typeof(row_v) == TYPE_DICTIONARY:
			var row: Dictionary = row_v
			out.append(row.duplicate(true))
	return out


static func _slots_of(rows: Array) -> PackedStringArray:
	var seen: Dictionary = {}
	var out: PackedStringArray = PackedStringArray()
	for row_v: Variant in rows:
		if typeof(row_v) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_v
		var slot: String = str(row.get("slot", ""))
		if slot.is_empty() or seen.has(slot):
			continue
		seen[slot] = true
		out.append(slot)
	return out


static func _shards_for(n: int) -> int:
	if n < 4:
		return 0
	if n < 16:
		return 1 + (n % 3)
	if n < 20:
		return 4 + (n % 2)
	return 6


static func _ladder(shards: int) -> int:
	if shards >= LineTable.L3_SHARDS:
		return 3
	if shards >= LineTable.L2_SHARDS:
		return 2
	if shards >= LineTable.L1_SHARDS:
		return 1
	return 0


static func _note_plant(
		row: Dictionary, slot: String, plant_slots: Dictionary,
		payoff_ready: Dictionary, payoffs: Dictionary, fails: Array[String], n: int
) -> void:
	var asserts_v: Variant = row.get("asserts", {})
	if typeof(asserts_v) != TYPE_DICTIONARY:
		return
	var asserts: Dictionary = asserts_v
	var plant: String = str(asserts.get("plant", ""))
	if not plant.is_empty() and plant_slots.has(plant):
		var occupied: Dictionary = plant_slots[plant]
		occupied[slot] = true
	var payoff: String = str(asserts.get("payoff", ""))
	if payoff.is_empty() or not plant_slots.has(payoff):
		return
	var seen: Dictionary = plant_slots[payoff]
	_check(fails, seen.size() >= 2,
		"payoff %s fired at run %d before the plant occupied two slots" % [payoff, n])
	payoff_ready[payoff] = true
