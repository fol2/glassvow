extends GlassvowGame
## Observes actual play; counterfactual commands never reach a live policy.
const Observe = preload("res://causal_probe.gd")
const HandRules = preload("res://hand_rules.gd")
const Health = preload("res://health_accounting.gd")
static var stream: FileAccess
static var row_key: String = ""
static var state_keys: Dictionary = {}
static var counters: Dictionary = {}
static var failed: bool = false
var fight_index: int = -1
var origin: GlassvowGame = null
var prefix: Array[Dictionary] = []
var actual_prefix_events: Array = []

static func start_row(key: String, output: FileAccess) -> void:
	row_key = key; stream = output; state_keys = {}; counters = {}
	failed = false

static func emit(value: Dictionary) -> void:
	value["row_key"] = row_key
	stream.store_line(JSON.stringify(value))
	stream.flush()

static func require(ok: bool, why: String) -> void:
	if not ok:
		failed = true
		emit({"kind":"fault", "reason":why})
		push_error("HAND_SUPPORT " + why)

static func increment(name: String, value: int = 1) -> void:
	counters[name] = int(counters.get(name,0)) + value

static func save_state(g: GlassvowGame) -> String:
	var text: String = JSON.stringify({"future":Observe.projection([g.run,g.cb,g.last_ret],{}),
		"queue":g.cb.queue if g.cb != null else []})
	var h: String = text.sha256_text()
	if not state_keys.has(h):
		state_keys[h] = true
		emit({"kind":"state","sha256":h,"serialized":text})
	return h

static func clone(g: GlassvowGame, mask: int) -> GlassvowGame:
	var c: GlassvowGame = Observe.clone_exact(g)
	c.cb.queue = g.cb.queue.duplicate(true)
	c.rules = HandRules.new(g.content)
	c.rules.intervention_mask = mask
	require(Observe.fingerprint(g) == Observe.fingerprint(c),"CLONE_FUTURE_STATE")
	return c

static func allowed(g: GlassvowGame, cmd: Dictionary) -> bool:
	if g.cb.over:
		return false
	if cmd.t == "playCard":
		var card: CardInst = Observe.find_card(g,int(cmd.uid))
		return card != null and g.rules.can_play(g.run,g.cb,card,cmd.get("target"))
	if cmd.t == "kindleFromHand":
		var card: CardInst = Observe.find_card(g,int(cmd.uid))
		return card != null and g.rules.can_kindle(g.run,g.cb,card)
	if cmd.t == "useArt":
		return g.rules.can_use_art(g.run,g.cb)
	if cmd.t == "usePotion":
		var slot: int = int(cmd.get("slot",-1))
		if slot < 0 or slot >= g.run.player.potions.size() or g.run.player.potions[slot] == "":return false
		var definition: Dictionary = g.content.potion(StringName(g.run.player.potions[slot]))
		if definition.get("needsTarget",false):
			var target: Variant = cmd.get("target")
			if target == null or int(target) < 0 or int(target) >= g.cb.enemies.size():return false
			return g.cb.enemies[int(target)].hp > 0
		return true
	return cmd.t == "endTurn"

func _init(db: ContentDB, state: RunState) -> void:
	super(db,state)
	rules = HandRules.new(db)

func replay(commands: Array[Dictionary], mask: int) -> Dictionary:
	var c: GlassvowGame = clone(origin,mask)
	var initial: String = save_state(c)
	var steps: Array = []
	var whole_events: Array = []
	var complete: bool = true
	for cmd: Dictionary in commands:
		var before: String = save_state(c)
		if not allowed(c,cmd):
			steps.append({"command":cmd,"permitted":false,"before":before,"after":before})
			complete = false; break
		c.rules.effect_observations.clear()
		var hp: Dictionary = Health.snapshot(c.cb)
		var events: Array[Dictionary] = c.apply(cmd)
		var fold: Dictionary = Health.fold(hp,events,Health.snapshot(c.cb))
		require(fold.get("ok",false),"COUNTERFACTUAL_HEALTH_FOLD")
		if cmd.t == "playCard":require(c.last_ret == true,"COUNTERFACTUAL_LEGALITY")
		steps.append({"command":cmd,"permitted":true,"before":before,"after":save_state(c),
			"events":events,"ret":c.last_ret,"health":fold,
			"effects":c.rules.effect_observations.duplicate(true)})
		whole_events.append_array(events)
	return {"mask":mask,"initial":initial,"complete":complete,"steps":steps,
		"final":save_state(c),"events":whole_events}

func apply(cmd: Dictionary) -> Array[Dictionary]:
	if cmd.t == "startCombat":
		origin = null; prefix.clear(); actual_prefix_events.clear(); fight_index += 1
		var events: Array[Dictionary] = super.apply(cmd)
		emit({"kind":"fight_start","fight":fight_index,"initial":save_state(self),
			"command":cmd,"events":events})
		return events
	if cb == null:return super.apply(cmd)
	var card: CardInst = Observe.find_card(self,int(cmd.get("uid",-1))) if cmd.t == "playCard" else null
	var cid: String = String(card.id) if card != null else ""
	var is_supplier: bool = cid in ["preparation","surge"]
	var is_phantom: bool = cid == "phantomBlades"
	if origin == null and is_supplier:
		origin = clone(self,0)
		prefix.clear(); actual_prefix_events.clear()
	if origin != null:prefix.append(cmd.duplicate(true))
	var arms: Array = []
	var direct: Array = []
	var q: int = cb.hand.size()-1
	var before: String = save_state(self)
	if is_phantom:
		increment("phantom_plays")
		for mask: int in [0,4]:
			var c: GlassvowGame = clone(self,mask)
			var health_before: Dictionary = Health.snapshot(c.cb)
			var ev: Array[Dictionary] = c.apply(cmd)
			var fold: Dictionary = Health.fold(health_before,ev,Health.snapshot(c.cb))
			require(c.last_ret == true and fold.get("ok",false),"MARGINAL_CAPTURE")
			direct.append({"mask":mask,"initial":save_state(self),"final":save_state(c),
				"health":fold,"events":ev,"ret":c.last_ret,"effects":c.rules.effect_observations.duplicate(true)})
		if origin != null:
			for mask: int in range(8):arms.append(replay(prefix,mask))
	rules.effect_observations.clear()
	var hp_before: Dictionary = Health.snapshot(cb)
	var events: Array[Dictionary] = super.apply(cmd)
	var health: Dictionary = Health.fold(hp_before,events,Health.snapshot(cb))
	require(health.get("ok",false),"FACTUAL_HEALTH_FOLD")
	if origin != null:actual_prefix_events.append_array(events)
	var after: String = save_state(self)
	if is_supplier:increment("supplier_plays:"+cid)
	if is_phantom:
		require(direct[0].events == events and direct[0].final == after and direct[0].ret == last_ret,"MARGINAL_FACTUAL_PARITY")
		var contribution: int = int(direct[0].health.removed)-int(direct[1].health.removed)
		if contribution > 0:increment("positive_high_payoff_plays")
		if not arms.is_empty():
			require(arms[0].complete and arms[0].events == actual_prefix_events and arms[0].final == after,"PREFIX_FACTUAL_PARITY")
		emit({"kind":"consumer","fight":fight_index,"command":cmd,"q":q,"up":card.up,
			"before":before,"after":after,"health":health,"direct":direct,
			"prefix_arms":arms,"prefix_commands":prefix.duplicate(true),"high_health_contribution":contribution})
	emit({"kind":"command","fight":fight_index,"command":cmd,"card":cid,
		"before":before,"after":after,"events":events,"ret":last_ret,"health":health,
		"effects":rules.effect_observations.duplicate(true)})
	return events
