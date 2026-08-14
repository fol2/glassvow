class_name BalancePolicy
extends RefCounted
## One sampled weight vector. default() is exactly today's p7-d2-v1 constants.

static func default() -> Dictionary:
	return {
		"cardDecline": -1.0e9,
		"removalAppetite": 8.5,
		"removalMinCopies": 3,
		"shopMinRatio": 0.06,
		"restHpPct": 70,
		"potionHealMissing": 20,
		"routeLowHpPct": 60,
		"shopGoldHigh": 140,
		"shopGoldLow": 45,
		"potionShopDefault": 16.0,
		"potionHealing": 22.0,
		"card": {
			"rarity": {"starter": 0, "common": 3, "uncommon": 6, "rare": 10},
			"blockHeal": 0.7, "drawEnergy": 4.5, "chipDusk": 6.0, "chipAsh": 2.5,
			"ember": 2.0, "loseHp": 0.4, "power": 10.0, "aspectBonus": 8.0,
		},
		"status": {
			"poisonDusk": 0.22, "poisonAsh": 0.85,
			"vulnerableDusk": 12.0, "vulnerableAsh": 4.0,
			"weak": 5.0, "str": 8.0, "dex": 5.5, "regen": 6.0,
			"venomousDusk": 6.0, "venomousAsh": 20.0,
			"ritual": 10.0, "barricade": 12.0,
			"beaconDusk": 10.0, "beaconAsh": 4.0, "nightsight": 8.0,
		},
		"special": {
			"catalystDusk": 6.0, "catalystAsh": 30.0,
			"shatterEchoDusk": 16.0, "shatterEchoAsh": 8.0,
			"execute": 13.0, "leech": 12.0, "doubleBlock": 9.0,
			"pyreTithe": 6.0, "fallback": 8.0,
		},
		"combat": {
			"loss": 1.15, "blockUrgent": 1.6, "blockNormal": 0.85,
			"shatterDusk": 80.0, "shatterAsh": 22.0, "lethal": 280.0,
			"poisonDusk": 0.22, "poisonAsh": 0.85,
			"catalystDusk": 0.8, "catalystAsh": 3.2,
			"eclipse": 48.0, "eclipseFollow": 36.0, "vulnAttack": 18.0,
			"chip": 12.0, "power": 14.0,
		},
		"route": {
			"boss": 1000, "treasure": 900, "restLow": 800, "restOk": 150,
			"shopRich": 700, "shopMid": 520, "shopPoor": 100, "event": 400,
			"eliteOk": 450, "eliteLow": 50, "monster": 300,
		},
		"relics": {
			"hollowCrown": 90, "frozenCore": 70, "crownOfCinders": 68, "verdantBranch": 62,
			"crownOfTheHearth": 60, "shatterersCrown": 58, "crownOfTithes": 55, "warFetish": 48,
			"emberLantern": 46, "sunBlossom": 44, "duskmirror": 42, "merchantsMark": 40,
			"travelersPack": 38, "silkFan": 36, "seersOrb": 34, "ironTalisman": 32,
			"executionersSeal": 30, "wardingCharm": 28, "basaltIdol": 26, "riverPearl": 24,
			"gravebloom": 24, "reapersBell": 22, "vialOfLife": 20, "thornBand": 18,
			"sweetRoot": 18, "prismCharm": 16, "bellOfEndings": 16, "thiefOfWicks": 14,
		},
		"relicRarity": {"common": 12, "uncommon": 22, "rare": 34, "boss": 50},
		"relicFallback": 10,
		"relicDuskBonus": 12.0,
		"relicAshBonus": 16.0,
	}


static func resolve(over: Dictionary) -> Dictionary:
	var v: Dictionary = default()
	_merge(v, over)
	return v


static func _merge(base: Dictionary, over: Dictionary) -> void:
	for key: Variant in over:
		var k: String = str(key)
		var incoming: Variant = over[key]
		if base.has(k) and typeof(base[k]) == TYPE_DICTIONARY and typeof(incoming) == TYPE_DICTIONARY:
			var child: Dictionary = base[k]
			var incoming_d: Dictionary = incoming if typeof(incoming) == TYPE_DICTIONARY else {}
			_merge(child, incoming_d)
			base[k] = child
		else:
			base[k] = incoming
