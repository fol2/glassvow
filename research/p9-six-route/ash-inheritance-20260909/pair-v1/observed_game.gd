extends GlassvowGame
## Trace and clone observations never alter the factual run or its policy.
static var stream: FileAccess
static var row_key: String = ""
static var sequence: int = 0
var fight: int = -1

static func begin(key: String, file: FileAccess) -> void:
	row_key = key
	stream = file
	sequence = 0

static func view(v: Variant) -> Variant:
	if v is Object:
		var d: Dictionary = {}
		for prop: Dictionary in v.get_property_list():
			if (int(prop.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0:
				d[str(prop.name)] = view(v.get(str(prop.name)))
		return d
	if v is Dictionary:
		var d: Dictionary = {}
		for k: Variant in v:
			d[str(k)] = view(v[k])
		return d
	if v is Array:
		var a: Array = []
		for item: Variant in v:
			a.append(view(item))
		return a
	return str(v) if typeof(v) == TYPE_STRING_NAME else v

static func clone_value(v: Variant, memo: Dictionary) -> Variant:
	if v is Object:
		var oid: int = v.get_instance_id()
		if memo.has(oid):
			return memo[oid]
		var c: Variant
		if v is CardInst:
			c = CardInst.new(v.uid, v.id, v.up)
		elif v is Rng:
			c = Rng.new(0)
		else:
			c = v.get_script().new()
		memo[oid] = c
		for prop: Dictionary in v.get_property_list():
			if (int(prop.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0:
				c.set(str(prop.name), clone_value(v.get(str(prop.name)), memo))
		return c
	if v is Array:
		var a: Array = v.duplicate()
		for i: int in range(a.size()):
			a[i] = clone_value(v[i], memo)
		return a
	if v is Dictionary:
		var d: Dictionary = v.duplicate()
		for k: Variant in v:
			d[k] = clone_value(v[k], memo)
		return d
	return v

static func snapshot(g: GlassvowGame) -> Dictionary:
	return {"run": view(g.run), "combat": view(g.cb), "return": view(g.last_ret)}

func clone_game() -> GlassvowGame:
	var memo: Dictionary = {}
	var cloned_run: RunState = clone_value(run, memo)
	var g: GlassvowGame = GlassvowGame.new(content, cloned_run)
	g.cb = clone_value(cb, memo)
	g.last_ret = clone_value(last_ret, memo)
	return g

func compact() -> Dictionary:
	var deck: Array = []
	for c: CardInst in run.player.deck:
		if String(c.id) in ["bloodRite", "leechBlade", "preparation", "surge", "phantomBlades"]:
			deck.append({"uid":c.uid, "id":String(c.id), "up":c.up})
	var hand: Array = []
	if cb != null:
		for c: CardInst in cb.hand:
			hand.append({"uid":c.uid, "id":String(c.id), "up":c.up})
	return {"deck":deck, "hand":hand, "bloodfire":int(cb.player.statuses.get("bloodfire",0)) if cb != null else 0,
		"energy":cb.player.energy if cb != null else 0, "hp":cb.player.hp if cb != null else run.player.hp,
		"turn":cb.turn if cb != null else 0, "over":cb.over if cb != null else false}

func apply(cmd: Dictionary) -> Array[Dictionary]:
	if str(cmd.t) == "startCombat":
		fight += 1
	var card: String = ""
	if str(cmd.t) == "playCard" and cb != null:
		for c: CardInst in cb.hand:
			if c.uid == int(cmd.get("uid",-1)):
				card = String(c.id)
	var before: Dictionary = compact()
	var cloned: Dictionary = {}
	var factual_before: Dictionary = {}
	if card == "leechBlade":
		factual_before = snapshot(self)
		for arm: String in ["none", "A", "B", "AB"]:
			var g: GlassvowGame = clone_game()
			var initial_equal: bool = snapshot(g) == factual_before
			if arm in ["none", "B"]:
				g.cb.player.statuses.erase("bloodfire")
			g.rules.set("bloodfire_consumer_enabled", arm in ["B", "AB"])
			var intervened_before: Dictionary = snapshot(g)
			var events: Array[Dictionary] = g.apply(cmd)
			cloned[arm] = {"initial_equal":initial_equal, "before":intervened_before,
				"after":snapshot(g), "events":events, "ret":g.last_ret}
	var untouched: bool = factual_before.is_empty() or snapshot(self) == factual_before
	var events: Array[Dictionary] = super.apply(cmd)
	var factual_match: bool = true
	if not cloned.is_empty():
		factual_match = cloned.AB.after == snapshot(self) and cloned.AB.events == events and cloned.AB.ret == last_ret
	stream.store_line(JSON.stringify({"kind":"command", "row_key":row_key, "sequence":sequence,
		"fight":fight, "command":cmd, "card":card, "before":before, "after":compact(),
		"events":events, "ret":last_ret, "clones":cloned, "factual_before":factual_before,
		"factual_after":snapshot(self) if not cloned.is_empty() else {},
		"original_untouched_by_clones":untouched, "factual_clone_match":factual_match}))
	stream.flush()
	sequence += 1
	return events
