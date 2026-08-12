extends RefCounted
## Producer-boundary proof for resumable event, shop and treasure values.


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_checkpoint_validation: %s" % what)


static func _pure_call(
	fails: Array[String], run: RunState, call: Callable, expected: bool, what: String
) -> void:
	var save_before: String = JSON.stringify(run.to_save_dict())
	var rng_before: int = run.rng_state()
	var result: bool = call.call()
	_check(fails, result == expected, what)
	_check(fails, JSON.stringify(run.to_save_dict()) == save_before and run.rng_state() == rng_before,
		"%s validator is pure" % what)


static func _event(
	fails: Array[String], rules: RewardRules, run: RunState, event_id: String,
	value: Variant, expected: bool, what: String
) -> void:
	_pure_call(fails, run, func() -> bool:
		return rules.valid_event_checkpoint(run, event_id, value), expected, what)


static func _shop(
	fails: Array[String], rules: RewardRules, run: RunState, value: Variant,
	expected: bool, what: String
) -> void:
	_pure_call(fails, run, func() -> bool:
		return rules.valid_shop_checkpoint(run, value), expected, what)


static func _treasure(
	fails: Array[String], rules: RewardRules, run: RunState, value: Variant,
	expected: bool, what: String
) -> void:
	_pure_call(fails, run, func() -> bool:
		return rules.valid_treasure_checkpoint(run, value), expected, what)


static func _reload(run: RunState, content: ContentDB, key: String, value: Dictionary) -> RunState:
	var save: Dictionary = run.to_save_dict()
	var scratch: Dictionary = save["questScratch"]
	scratch[key] = value
	var parsed_v: Variant = JSON.parse_string(JSON.stringify(save))
	var parsed: Dictionary = parsed_v
	return RunState.from_save_dict(parsed, content)


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var rules: RewardRules = RewardRules.new(content)
	_event_cases(fails, content, rules)
	_shop_cases(fails, content, rules)
	_treasure_cases(fails, content, rules)


static func _event_cases(fails: Array[String], content: ContentDB, rules: RewardRules) -> void:
	var run: RunState = RunState.new_run(content, 14801, "checkpoint-event", {"reveals": null})
	var event: Dictionary = content.events["library"]
	var choice: Dictionary = event["choices"][0]
	var ops: Array = choice["ops"]
	var library: Dictionary = rules.apply_event_ops(run, ops)
	_event(fails, rules, run, "library", library, true, "authentic Library offer")
	var reloaded: RunState = _reload(run, content, "eventPending", library)
	_event(fails, rules, reloaded, "library", reloaded.quest_scratch.eventPending, true,
		"durable v2 Library offer")
	_event(fails, rules, run, "library", {"kind": "card", "cards": [library.cards[0]]}, true,
		"short guarded Library offer")
	var six_unique: Array = []
	for tier: String in ["common", "uncommon", "rare"]:
		for id_v: Variant in rules.card_pool(run, tier):
			if six_unique.size() < 6:
				six_unique.append(id_v)
	var mutations: Array[Dictionary] = [
		{"name": "empty event cards", "value": {"kind": "card", "cards": []}},
		{"name": "duplicate event cards", "value": {"kind": "card", "cards": [library.cards[0], library.cards[0]]}},
		{"name": "six-card event offer", "value": {"kind": "card", "cards": six_unique}},
		{"name": "starter event card", "value": {"kind": "card", "cards": ["strike"]}},
		{"name": "unknown event", "value": library, "event": "notAnEvent"},
		{"name": "mismatched event kind", "value": {"kind": "remove"}},
	]
	for row: Dictionary in mutations:
		_event(fails, rules, run, str(row.get("event", "library")), row.value, false, str(row.name))
	for event_case: Array in [["forgottenShrine", "remove"], ["mirror", "duplicate"]]:
		_event(fails, rules, run, str(event_case[0]), {"kind": event_case[1]}, true,
			"authentic %s choice" % event_case[1])
	for card: CardInst in run.player.deck:
		card.up = true
	_event(fails, rules, run, "forge", {"kind": "upgrade"}, true,
		"empty eligible upgrade remains resumable")


static func _shop_cases(fails: Array[String], content: ContentDB, rules: RewardRules) -> void:
	var plain: RunState = RunState.new_run(content, 14802, "checkpoint-shop", {"reveals": null})
	var stock: Dictionary = rules.gen_shop(plain)
	_shop(fails, rules, plain, stock, true, "authentic ordinary shop")
	var reloaded: RunState = _reload(plain, content, "shopStock", stock)
	_shop(fails, rules, reloaded, reloaded.quest_scratch.shopStock, true, "durable v2 shop")
	var duplicate_stock: Dictionary = stock.duplicate(true)
	duplicate_stock.cards[1].id = duplicate_stock.cards[0].id
	duplicate_stock.potions[1].id = duplicate_stock.potions[0].id
	_shop(fails, rules, plain, duplicate_stock, true, "producer-allowed duplicate rolls")
	var mutations: Array[Dictionary] = [
		{"name": "empty free-removal shop", "edit": func(v: Dictionary) -> void:
			v.cards.clear(); v.relics.clear(); v.potions.clear(); v.removeCost = 0},
		{"name": "wrong card tier", "edit": func(v: Dictionary) -> void: v.cards[0].id = v.cards[2].id},
		{"name": "wrong card price", "edit": func(v: Dictionary) -> void: v.cards[0].price += 1000},
		{"name": "boss relic in common row", "edit": func(v: Dictionary) -> void: v.relics[0].id = "hollowCrown"},
		{"name": "wrong remove cost", "edit": func(v: Dictionary) -> void: v.removeCost += 1},
		{"name": "wrong phial count", "edit": func(v: Dictionary) -> void: v.potions.pop_back()},
		{"name": "extra stock key", "edit": func(v: Dictionary) -> void: v.extra = true},
		{"name": "non-boolean sold flag", "edit": func(v: Dictionary) -> void: v.cards[0].sold = 1},
		{"name": "fractional card price", "edit": func(v: Dictionary) -> void: v.cards[0].price = 50.5},
		{"name": "NaN card price", "edit": func(v: Dictionary) -> void: v.cards[0].price = NAN},
		{"name": "boolean remove cost", "edit": func(v: Dictionary) -> void: v.removeCost = true},
		{"name": "negative remove cost", "edit": func(v: Dictionary) -> void: v.removeCost = -75.0},
		{"name": "infinite remove cost", "edit": func(v: Dictionary) -> void: v.removeCost = INF},
	]
	for mutation: Dictionary in mutations:
		var changed: Dictionary = stock.duplicate(true)
		mutation.edit.call(changed)
		_shop(fails, rules, plain, changed, false, str(mutation.name))
	var held: RunState = RunState.new_run(content, 14810, "checkpoint-shop-held", {"reveals": null})
	var held_stock: Dictionary = rules.gen_shop(held)
	held.player.relics.append(str(held_stock.relics[0].id))
	_shop(fails, rules, held, held_stock, false, "unsold relic already held")

	var hidden: RunState = RunState.new_run(content, 14803, "checkpoint-shop-hidden")
	var hidden_stock: Dictionary = rules.gen_shop(hidden)
	_shop(fails, rules, hidden, hidden_stock, true, "authentic no-phials shop")
	var added_phial: Dictionary = hidden_stock.duplicate(true)
	added_phial.potions.append(stock.potions[0])
	_shop(fails, rules, hidden, added_phial, false, "phial added before reveal")

	var preowned: RunState = RunState.new_run(content, 14804, "checkpoint-shop-preowned", {"reveals": null})
	preowned.player.relics.append("merchantsMark")
	var discounted: Dictionary = rules.gen_shop(preowned)
	_shop(fails, rules, preowned, discounted, true, "authentic pre-owned Merchant discount")
	var hungry: RunState = RunState.new_run(content, 14809, "checkpoint-shop-hungry", {"reveals": null})
	hungry.omens[0] = "hungryDark"
	var hungry_stock: Dictionary = rules.gen_shop(hungry)
	_shop(fails, rules, hungry, hungry_stock, true, "authentic hungryDark shop multiplier")

	var bought_run: RunState
	var bought_stock: Dictionary
	for seed: int in range(1, 501):
		var candidate: RunState = RunState.new_run(content, seed, "checkpoint-mark-%d" % seed, {"reveals": null})
		var candidate_stock: Dictionary = rules.gen_shop(candidate)
		for row: Dictionary in candidate_stock.relics:
			if row.id == "merchantsMark":
				candidate.player.gold = 1000
				bought_run = candidate
				bought_stock = candidate_stock
				candidate.player.gold -= int(float(str(row.price)))
				row.sold = true
				rules.gain_relic(candidate, "merchantsMark")
				break
		if bought_run != null:
			break
	_check(fails, bought_run != null, "bounded seed search finds Merchant's Mark")
	if bought_run != null:
		_shop(fails, rules, bought_run, bought_stock, true, "sold Merchant uses creation-time full price")


static func _treasure_cases(fails: Array[String], content: ContentDB, rules: RewardRules) -> void:
	var relic_run: RunState = RunState.new_run(content, 14805, "checkpoint-treasure", {"reveals": null})
	var claim: Dictionary = rules.claim_treasure(relic_run)
	_treasure(fails, rules, relic_run, claim, true, "authentic relic treasure")
	var reloaded: RunState = _reload(relic_run, content, "treasureClaim", claim)
	_treasure(fails, rules, reloaded, reloaded.quest_scratch.treasureClaim, true,
		"durable v2 relic treasure")
	_treasure(fails, rules, relic_run, {"relic": claim.relic, "gold": 0.5}, false,
		"fractional treasure gold")
	_treasure(fails, rules, relic_run, {"relic": claim.relic, "gold": true}, false,
		"boolean treasure gold")
	_treasure(fails, rules, relic_run, {"relic": claim.relic, "gold": INF}, false,
		"infinite treasure gold")
	var starter: Dictionary = {"relic": str(content.player.startRelic), "gold": 0}
	_treasure(fails, rules, relic_run, starter, false, "starter relic treasure")
	var premature: RunState = RunState.new_run(content, 14806, "checkpoint-premature", {"reveals": null})
	premature.player.gold += 60
	_treasure(fails, rules, premature, {"relic": null, "gold": 60}, false,
		"non-exhausted null treasure")

	var exhausted: RunState = RunState.new_run(content, 14807, "checkpoint-exhausted", {"reveals": null})
	for tier: String in ["common", "uncommon", "rare"]:
		for id_v: Variant in rules.relic_pool(exhausted, tier):
			var id: String = str(id_v)
			if not exhausted.player.relics.has(id):
				exhausted.player.relics.append(id)
	var fallback: Dictionary = rules.claim_treasure(exhausted)
	_treasure(fails, rules, exhausted, fallback, true, "authentic exhausted null treasure")
	var fallback_reload: RunState = _reload(exhausted, content, "treasureClaim", fallback)
	_treasure(fails, rules, fallback_reload, fallback_reload.quest_scratch.treasureClaim, true,
		"durable v2 exhausted null treasure")
	var missing_gold: RunState = RunState.new_run(content, 14808, "checkpoint-no-gold", {"reveals": null})
	missing_gold.player.relics = exhausted.player.relics.duplicate()
	missing_gold.player.gold = 0
	_treasure(fails, rules, missing_gold, {"relic": null, "gold": 60}, false,
		"null treasure missing gold effect")
