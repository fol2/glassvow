class_name BalancePolicy
extends RefCounted
## Live default() is p8-d0-v1. sample_origin() is frozen p7-d2-v1 for sampler/CEM replay.

static func default() -> Dictionary:
	return {
		"cardDecline": 14.0958831273019,
		"removalAppetite": 16.4400114826858,
		"removalMinCopies": 2,
		"shopMinRatio": 0.06475653649074956,
		"restHpPct": 67,
		"potionHealMissing": 23,
		"routeLowHpPct": 59,
		"shopGoldHigh": 174,
		"shopGoldLow": 44,
		"potionShopDefault": 15.27079566909635,
		"potionHealing": 27.1403281589842,
		"card": {
			"rarity": {"starter": 0, "common": 4.5915674100619, "uncommon": 4.8437263622436255, "rare": 6.99049021397807},
			"blockHeal": 0.847886087458699, "drawEnergy": 10.03605729808525, "chipDusk": 6.7617601186515, "chipAsh": 2.2778339702244352,
			"ember": 2.16564561226858, "loseHp": 0.38116165561253, "power": 6.5654367491250945, "aspectBonus": 7.27725827486158,
		},
		"status": {
			"poisonDusk": 0.20213950910252398, "poisonAsh": 0.779955671227815,
			"vulnerableDusk": 10.4961529566287, "vulnerableAsh": 3.70383807935751,
			"weak": 5.51631708339288, "str": 7.49465968032341, "dex": 5.549792717976205, "regen": 11.76985144414705,
			"venomousDusk": 5.79026208118971, "venomousAsh": 18.9127656174971,
			"ritual": 6.526393909972665, "barricade": 8.37046439591552,
			"beaconDusk": 10.4626743871535, "beaconAsh": 4.120495069530225, "nightsight": 7.86991789675343,
		},
		"special": {
			"catalystDusk": 5.731335081503705, "catalystAsh": 31.1169328405239,
			"shatterEchoDusk": 14.4155518047532, "shatterEchoAsh": 7.3614481384374955,
			"execute": 10.7156203095633, "leech": 14.3692959512496, "doubleBlock": 7.67567992016291,
			"pyreTithe": 5.52944612840346, "fallback": 7.51102251855123,
		},
		"combat": {
			"loss": 1.0766330860876399, "blockUrgent": 1.639448077985075, "blockNormal": 0.951755785258475,
			"shatterDusk": 86.1521802982367, "shatterAsh": 20.5137386175696, "lethal": 271.86061460559597,
			"poisonDusk": 0.231435933369507, "poisonAsh": 0.75471690400962,
			"catalystDusk": 0.658742733904453, "catalystAsh": 3.073545159698565,
			"eclipse": 51.7435703707365, "eclipseFollow": 34.6681027677087, "vulnAttack": 18.086788624044,
			"chip": 10.9225678185387, "power": 12.335912949551,
		},
		"route": {
			"boss": 1032.790216282955, "treasure": 998.033788718737, "restLow": 772.9093415727995, "restOk": 157.065698273801,
			"shopRich": 792.709464154913, "shopMid": 469.8618856791045, "shopPoor": 102.128217699784, "event": 461.622808106524,
			"eliteOk": 549.670237009942, "eliteLow": 53.61779932846405, "monster": 233.00472524985,
		},
		"relics": {
			"hollowCrown": 129.500764113312, "frozenCore": 69.4572216547818, "crownOfCinders": 57.9996331733703, "verdantBranch": 63.268974786966254,
			"crownOfTheHearth": 61.14961803580935, "shatterersCrown": 52.8618166131941, "crownOfTithes": 53.5004637104158, "warFetish": 49.78863992702955,
			"emberLantern": 45.3790460681222, "sunBlossom": 47.04474458252035, "duskmirror": 38.5323948882649, "merchantsMark": 42.3181258498368,
			"travelersPack": 34.3068052095502, "silkFan": 37.4983116806541, "seersOrb": 33.1517449564163, "ironTalisman": 34.41249808750775,
			"executionersSeal": 28.0583018089109, "wardingCharm": 28.390878657812, "basaltIdol": 26.915813259946148, "riverPearl": 23.5320631723973,
			"gravebloom": 25.2314974165005, "reapersBell": 23.0626748970696, "vialOfLife": 20.7623625215193, "thornBand": 19.1184448219892,
			"sweetRoot": 17.1104150542746, "prismCharm": 15.7655728762468, "bellOfEndings": 16.187093653280648, "thiefOfWicks": 13.602636355105151,
		},
		"relicRarity": {"common": 13.171215746162, "uncommon": 23.1168193559307, "rare": 33.28335175184075, "boss": 51.3885985858431},
		"relicFallback": 10.00420772943006,
		"relicDuskBonus": 12.413662948659852,
		"relicAshBonus": 15.6087664564039,
	}


static func sample_origin() -> Dictionary:
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


static func sample_range(root_seed: int, first: int, count: int) -> Array[Dictionary]:
	var rng: Rng = Rng.new(root_seed)
	var out: Array[Dictionary] = []
	for index: int in range(first + count):
		var vector: Dictionary = sample_origin()
		for group: String in ["card", "status", "special", "combat", "route", "relics", "relicRarity"]:
			var weights: Dictionary = vector[group]
			_scale_group(weights, rng)
		for key: String in ["potionShopDefault", "potionHealing", "relicFallback",
				"relicDuskBonus", "relicAshBonus"]:
			vector[key] = float(str(vector[key])) * _log_factor(rng)
		vector["cardDecline"] = 40.0 * rng.next()
		vector["removalAppetite"] = 4.0 + 24.0 * rng.next()
		vector["removalMinCopies"] = 1 + rng.pick_index(3)
		vector["shopMinRatio"] = 0.01 + 0.11 * rng.next()
		vector["restHpPct"] = rng.irange(25, 90)
		vector["potionHealMissing"] = rng.irange(5, 40)
		vector["routeLowHpPct"] = rng.irange(25, 90)
		vector["shopGoldLow"] = rng.irange(0, 90)
		vector["shopGoldHigh"] = rng.irange(100, 250)
		if index >= first:
			out.append(vector)
	return out


static func _scale_group(group: Dictionary, rng: Rng) -> void:
	for key_v: Variant in group:
		var key: String = str(key_v)
		var value: Variant = group[key]
		if typeof(value) == TYPE_DICTIONARY:
			var child: Dictionary = value
			_scale_group(child, rng)
		elif float(str(value)) != 0.0:
			group[key] = float(str(value)) * _log_factor(rng)


static func _log_factor(rng: Rng) -> float:
	return 0.25 * (16.0 ** rng.next())


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
