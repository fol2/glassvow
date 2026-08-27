extends SceneTree

const ALGORITHM: String = "keyed-exponential-race-v1"
const TIERS: Array[String] = ["common", "uncommon", "rare"]
const TEST_SEEDS: Array[int] = [101, 202, 303, 404, 52101, 52102]
const TEST_KINDS: Array[String] = ["normal", "elite", "boss"]


func _initialize() -> void:
	var failures: Array[String] = []
	_identity_replay(failures)
	_weighted_invariants(failures)
	_invalid_configurations(failures)
	_reveal_gate(failures)
	if failures.is_empty():
		print("PASS reward exposure prototype (native invariants)")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)


func _identity_replay(failures: Array[String]) -> void:
	var legacy: ContentDB = ContentDB.load_full(false)
	var identity: ContentDB = ContentDB.load_full(false)
	identity.card_reward_exposure = _identity_config(identity, true)
	for vow: int in [0, 5]:
		for seed: int in TEST_SEEDS:
			for kind: String in TEST_KINDS:
				var legacy_result: Dictionary = _reward(legacy, seed, kind, vow)
				var identity_result: Dictionary = _reward(identity, seed, kind, vow)
				_expect(identity_result == legacy_result, failures,
					"identity exposure changed %s vow %d seed %d" % [kind, vow, seed])


func _weighted_invariants(failures: Array[String]) -> void:
	var ordered: ContentDB = ContentDB.load_full(false)
	ordered.card_reward_exposure = _random_regression_config(false)
	var reversed: ContentDB = ContentDB.load_full(false)
	reversed.card_reward_exposure = _random_regression_config(true)
	var legacy: ContentDB = ContentDB.load_full(false)
	for seed: int in range(52100, 52200):
		var first: Dictionary = _reward(ordered, seed, "normal", 0)
		var replay: Dictionary = _reward(ordered, seed, "normal", 0)
		var reordered: Dictionary = _reward(reversed, seed, "normal", 0)
		var legacy_result: Dictionary = _reward(legacy, seed, "normal", 0)
		_expect(first == replay, failures, "weighted replay changed seed %d" % seed)
		_expect(first == reordered, failures, "dictionary order changed seed %d" % seed)
		_expect(str(first["cursor"]) == str(legacy_result["cursor"]), failures,
			"weighted reward changed the outer cursor seed %d" % seed)
		var cards: Array = first["reward"]["cards"]
		var unique: Dictionary = {}
		for card_v: Variant in cards:
			unique[str(card_v)] = true
		_expect(unique.size() == cards.size(), failures,
			"weighted reward sampled with replacement seed %d" % seed)
	var cursor: int = _run(ordered, 52199, 0).rng_state()
	var uniform_a: float = RewardRules._exposure_uniform(cursor, "card|common|quickSlash")
	var uniform_b: float = RewardRules._exposure_uniform(cursor, "card|common|quickSlash")
	_expect(uniform_a == uniform_b and uniform_a > 0.0 and uniform_a < 1.0, failures,
		"counter-based common random number is unstable")


func _invalid_configurations(failures: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	var run: RunState = _run(content, 52103, 0)
	var rules: RewardRules = RewardRules.new(content)
	for row: Dictionary in [
		{"name": "non-dictionary", "config": 7},
		{"name": "unknown algorithm", "config": {"algorithm": "other", "pools": {}}},
		{"name": "negative", "config": {
			"algorithm": ALGORITHM, "defaultWeight": -1.0, "pools": {}}},
		{"name": "all zero", "config": {
			"algorithm": ALGORITHM, "defaultWeight": 0.0, "pools": {}}},
		{"name": "under-supported", "config": _under_supported_config(content)},
		{"name": "unknown card", "config": {
			"algorithm": ALGORITHM, "defaultWeight": 1.0,
			"pools": {"common": {"not-a-card": 2.0}}}},
	]:
		content.card_reward_exposure = row["config"]
		var plan: Dictionary = rules._exposure_plan(run, 3)
		_expect(str(plan.get("ok", false)) != "true", failures,
			"%s exposure configuration did not fail closed" % str(row["name"]))
	content.card_reward_exposure = {
		"algorithm": ALGORITHM, "defaultWeight": 0.0, "pools": {},
	}
	_expect(rules._roll_card_reward(run, "boss").is_empty(), failures,
		"all-zero exposure produced a reward")


func _reveal_gate(failures: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	var gate_ids: Array = content.pool_gate_cards.keys()
	gate_ids.sort()
	_expect(not gate_ids.is_empty(), failures, "content has no reveal-gated card witness")
	if gate_ids.is_empty():
		return
	var card_id: String = str(gate_ids[0])
	var tier: String = str(content.cards[card_id].get("rarity", ""))
	var tier_weights: Dictionary = {}
	tier_weights[card_id] = 1000.0
	var configured_pools: Dictionary = {}
	configured_pools[tier] = tier_weights
	content.card_reward_exposure = {
		"algorithm": ALGORITHM,
		"defaultWeight": 1.0,
		"pools": configured_pools,
	}
	var hidden: Dictionary = RewardRules.new(content)._exposure_plan(
		RunState.new_run(content, 52104, "hidden", {"reveals": []}), 3)
	var revealed: Dictionary = RewardRules.new(content)._exposure_plan(
		RunState.new_run(content, 52104, "revealed", {"reveals": null}), 3)
	var hidden_pools: Dictionary = hidden.get("pools", {})
	var revealed_pools: Dictionary = revealed.get("pools", {})
	var hidden_tier: Dictionary = hidden_pools.get(tier, {})
	var revealed_tier: Dictionary = revealed_pools.get(tier, {})
	_expect(str(hidden.get("ok", false)) == "true" and not hidden_tier.has(card_id), failures,
		"unrevealed weighted card entered its rarity pool")
	_expect(str(revealed.get("ok", false)) == "true" and revealed_tier.has(card_id), failures,
		"revealed weighted card did not enter its rarity pool")


func _reward(content: ContentDB, seed: int, kind: String, vow: int) -> Dictionary:
	var game: GlassvowGame = GlassvowGame.new(content, _run(content, seed, vow))
	return {"reward": game.gen_combat_rewards(kind), "cursor": game.run.rng_state()}


func _run(content: ContentDB, seed: int, vow: int) -> RunState:
	return RunState.new_run(content, seed, "exposure-%d-%d" % [seed, vow], {
		"vow": vow,
		"reveals": null,
	})


func _identity_config(content: ContentDB, reverse: bool) -> Dictionary:
	var pools: Dictionary = {}
	var tiers: Array[String] = TIERS.duplicate()
	if reverse:
		tiers.reverse()
	for tier: String in tiers:
		var ids: Array = content.card_pools[tier].duplicate()
		if reverse:
			ids.reverse()
		var weights: Dictionary = {}
		for id_v: Variant in ids:
			weights[str(id_v)] = 1.0
		pools[tier] = weights
	var result: Dictionary = {}
	if reverse:
		result["pools"] = pools
		result["defaultWeight"] = 1.0
		result["algorithm"] = ALGORITHM
	else:
		result["algorithm"] = ALGORITHM
		result["defaultWeight"] = 1.0
		result["pools"] = pools
	return result


func _random_regression_config(reverse: bool) -> Dictionary:
	var pools: Dictionary = {}
	var tiers: Array[String] = TIERS.duplicate()
	if reverse:
		tiers.reverse()
	for tier: String in tiers:
		pools[tier] = {"hex": 24.0}
	var result: Dictionary = {}
	if reverse:
		result["pools"] = pools
		result["defaultWeight"] = 1.0
		result["algorithm"] = ALGORITHM
	else:
		result["algorithm"] = ALGORITHM
		result["defaultWeight"] = 1.0
		result["pools"] = pools
	return result


func _under_supported_config(content: ContentDB) -> Dictionary:
	var pools: Dictionary = {}
	for tier: String in TIERS:
		pools[tier] = {str(content.card_pools[tier][0]): 1.0}
	return {"algorithm": ALGORITHM, "defaultWeight": 0.0, "pools": pools}


func _expect(condition: bool, failures: Array[String], message: String) -> void:
	if not condition:
		failures.append(message)
