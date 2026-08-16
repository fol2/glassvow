extends RefCounted
## #270 acceptance: headless N-run planting. No post-reveal line fires
## pre-reveal, and every twist-critical plant occupies ≥2 slots before payoff.

const RUNS: int = 24
const SLOTS: PackedStringArray = [
	"hearth", "waystone", "loss", "death.ownShade1",
	"closer.ownShade", "closer.usurper", "closer.eighthOmen", "closer.l3",
]


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_narrative_planting: %s" % what)


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	var rows: Array = content.line_table
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
		for slot: String in SLOTS:
			if not LineTable.slot_open(rows, slot, ctx):
				continue
			var row: Dictionary = LineTable.select(rows, slot, ctx, rng, memory)
			if row.is_empty():
				continue
			_check(fails, LineTable.conditions_match(row.get("conditions", {}), ctx),
				"select returned a line whose conditions fail at shards %d" % shards)
			_check(fails, LineTable.ladder_of(row) <= _ladder(shards),
				"post-reveal line %s fired at shards %d" % [str(row.get("id")), shards])
			var id: String = str(row.get("id", ""))
			drawn.append(id)
			if row.get("once", false) and not once.has(id):
				once.append(id)
			_note_plant(row, str(row.get("slot", "")), plant_slots, payoff_ready, payoffs, fails, n)
		if not drawn.is_empty():
			recent = LineTable.remember(recent, drawn)
			last_id = str(drawn[drawn.size() - 1])

	for plant_id_v: Variant in plants:
		var plant_id: String = str(plant_id_v)
		var slots: Dictionary = plant_slots[plant_id]
		_check(fails, slots.size() >= 2,
			"plant %s occupied %d slot(s) before payoff" % [plant_id, slots.size()])
		if payoffs.has(plant_id):
			var reached: bool = false
			if payoff_ready[plant_id]:
				reached = true
			_check(fails, reached,
				"plant %s never reached its payoff" % plant_id)


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
		var slots: Dictionary = plant_slots[plant]
		slots[slot] = true
	var payoff: String = str(asserts.get("payoff", ""))
	if payoff.is_empty() or not plant_slots.has(payoff):
		return
	var seen: Dictionary = plant_slots[payoff]
	_check(fails, seen.size() >= 2,
		"payoff %s fired at run %d before the plant occupied two slots" % [payoff, n])
	payoff_ready[payoff] = true
