class_name BalanceCem
extends SceneTree
## #216 layer-2 CEM island. One process per island; NDJSON to --out.
const Sim: GDScript = preload("res://tools/balance_sim.gd")
const Policy: GDScript = preload("res://tools/balance_policy.gd")
const GRIDS: PackedStringArray = ["duskblade:v0", "duskblade:v5", "ashwarden:v0", "ashwarden:v5"]
const THR: PackedStringArray = ["cardDecline", "removalAppetite", "removalMinCopies",
	"shopMinRatio", "restHpPct", "potionHealMissing", "routeLowHpPct", "shopGoldLow", "shopGoldHigh"]
const THR_LO: Array[float] = [0.0, 4.0, 1.0, 0.01, 25.0, 5.0, 25.0, 0.0, 100.0]
const THR_HI: Array[float] = [40.0, 28.0, 3.0, 0.12, 90.0, 40.0, 90.0, 90.0, 250.0]
const THR_INT: Array[int] = [0, 0, 1, 0, 1, 1, 1, 1, 1]
const LOG_LO: float = -1.3862943611198906
const LOG_HI: float = 1.3862943611198906

func _initialize() -> void:
	var opts: Dictionary = _options(OS.get_cmdline_user_args())
	if opts.has("error"):
		push_error("balance_cem: %s" % opts["error"])
		quit(2)
		return
	var t0: int = Time.get_ticks_msec()
	var content: ContentDB = ContentDB.load_full(false)
	var git_out: Array = []
	OS.execute("git", ["rev-parse", "HEAD"], git_out)
	var island: int = _i(opts, "island")
	var spec: Dictionary = _spec(str(opts["seedsJson"]), island)
	if spec.has("error"):
		push_error("balance_cem: %s" % spec["error"])
		quit(2)
		return
	var file: FileAccess = FileAccess.open(str(opts["out"]), FileAccess.WRITE)
	if file == null:
		push_error("balance_cem: cannot write --out")
		quit(2)
		return
	var grid: String = GRIDS[int(island / 6.0)]
	var aspect: String = grid.get_slice(":", 0)
	var vow: int = int(float(str(grid.get_slice(":", 1).trim_prefix("v"))))
	var seed_pol: Dictionary = Policy.sample_range(215, _i(spec, "policyIndex"), 1)[0]
	var paths: PackedStringArray = _mag_paths()
	var mag_mu: Array[float] = []
	var mag_sd: Array[float] = []
	var base: Dictionary = Policy.sample_origin()
	for path: String in paths:
		var ratio: float = _at(seed_pol, path) / _at(base, path)
		mag_mu.append(log(clampf(ratio, 0.25, 4.0)))
		mag_sd.append(0.35)
	var thr_mu: Array[float] = []
	var thr_sd: Array[float] = []
	for t: int in range(THR.size()):
		thr_mu.append(float(str(seed_pol[THR[t]])))
		thr_sd.append(0.15 * (THR_HI[t] - THR_LO[t]))
	var rng: Rng = Rng.new(_i(opts, "rootSeed") + island)
	var pop: int = _i(opts, "popSize")
	var elite_n: int = mini(_i(opts, "elite"), pop)
	var max_gen: int = _i(opts, "maxGen")
	var n_train: int = _i(opts, "seedCount")
	var train0: int = _i(opts, "trainSeed0")
	var manifest: Dictionary = opts.duplicate()
	manifest["t"] = "manifest"
	manifest["commit"] = str(git_out[0]).strip_edges() if not git_out.is_empty() else "unknown"
	manifest["godot"] = Engine.get_version_info().get("string", "unknown")
	manifest["contentSha256"] = FileAccess.get_sha256(ContentDB.FULL_PATH)
	manifest["grid"] = grid
	manifest["startCell"] = str(spec["cell"])
	manifest["policyIndex"] = _i(spec, "policyIndex")
	manifest["samplerRoot"] = 215
	file.store_line(JSON.stringify(manifest))
	file.flush()
	var best_fit: float = -1.0
	var best_pol: Dictionary = seed_pol
	var history: Array[float] = []
	var stop: String = "maxGen"
	var last_gen: int = -1
	for gen: int in range(max_gen):
		var seed0: int = train0 + gen * n_train
		var fits: Array[float] = []
		var mags: Array = []
		var thrs: Array = []
		var pols: Array = []
		var gen_best: float = -1.0
		for c: int in range(pop):
			var mag: Array[float] = _sample(rng, mag_mu, mag_sd, LOG_LO, LOG_HI)
			var thr: Array[float] = _sample_thr(rng, thr_mu, thr_sd)
			var pol: Dictionary = _policy(base, paths, mag, thr)
			var wins: int = _wins(content, aspect, vow, pol, seed0, n_train)
			var fit: float = float(wins) / float(n_train)
			fits.append(fit)
			mags.append(mag)
			thrs.append(thr)
			pols.append(pol)
			if fit > gen_best:
				gen_best = fit
			if fit > best_fit:
				best_fit = fit
				best_pol = pol
		history.append(best_fit)
		last_gen = gen
		_refit(mag_mu, mag_sd, mags, fits, elite_n)
		_refit(thr_mu, thr_sd, thrs, fits, elite_n)
		file.store_line(JSON.stringify({"t": "gen", "gen": gen, "genBest": gen_best,
			"bestEver": best_fit, "meanMagSigma": _mean(mag_sd), "meanThrSigma": _mean(thr_sd),
			"trainSeed0": seed0}))
		file.flush()
		print(JSON.stringify({"island": island, "gen": gen, "genBest": gen_best,
			"bestEver": best_fit, "ms": Time.get_ticks_msec() - t0}))
		if history.size() >= 6 and history[history.size() - 1] - history[history.size() - 6] < 0.01:
			stop = "stall"
			break
	var hold_n: int = _i(opts, "holdoutCount")
	var hold0: int = _i(opts, "holdoutSeed0")
	var hold_wins: int = 0
	for o: int in range(hold_n):
		var row: Dictionary = Sim.simulate(content, aspect, hold0 + o, vow, PackedStringArray(), best_pol)
		row["t"] = "holdout"
		row["island"] = island
		if str(row["outcome"]) == "win":
			hold_wins += 1
		file.store_line(JSON.stringify(row))
	var ceiling: float = float(hold_wins) / float(hold_n)
	file.store_line(JSON.stringify({"t": "final", "island": island, "grid": grid,
		"startCell": spec["cell"], "policyIndex": spec["policyIndex"], "policy": best_pol,
		"holdoutCeiling": ceiling, "holdoutWins": hold_wins, "holdoutRuns": hold_n,
		"gens": last_gen + 1, "stop": stop, "bestTrainFitness": best_fit,
		"gen0Best": history[0] if not history.is_empty() else 0.0,
		"ms": Time.get_ticks_msec() - t0}))
	file.flush()
	print(JSON.stringify({"island": island, "stop": stop, "gens": last_gen + 1,
		"holdoutCeiling": ceiling, "holdoutWins": hold_wins, "ms": Time.get_ticks_msec() - t0}))
	quit(0)

static func _wins(content: ContentDB, aspect: String, vow: int, policy: Dictionary,
		seed0: int, n: int) -> int:
	var w: int = 0
	for o: int in range(n):
		var row: Dictionary = Sim.simulate(content, aspect, seed0 + o, vow, PackedStringArray(), policy)
		if str(row["outcome"]) == "win":
			w += 1
	return w

static func _sample(rng: Rng, mu: Array[float], sd: Array[float], lo: float, hi: float) -> Array[float]:
	var out: Array[float] = []
	for i: int in range(mu.size()):
		out.append(clampf(mu[i] + sd[i] * _gauss(rng), lo, hi))
	return out

static func _sample_thr(rng: Rng, mu: Array[float], sd: Array[float]) -> Array[float]:
	var out: Array[float] = []
	for i: int in range(mu.size()):
		var x: float = clampf(mu[i] + sd[i] * _gauss(rng), THR_LO[i], THR_HI[i])
		if THR_INT[i] == 1:
			x = roundf(x)
		out.append(x)
	return out

static func _gauss(rng: Rng) -> float:
	var u1: float = rng.next()
	if u1 < 1.0e-12:
		u1 = 1.0e-12
	return sqrt(-2.0 * log(u1)) * cos(TAU * rng.next())

static func _policy(base: Dictionary, paths: PackedStringArray, mag: Array[float],
		thr: Array[float]) -> Dictionary:
	var pol: Dictionary = Policy.sample_origin()
	for i: int in range(paths.size()):
		_put(pol, paths[i], _at(base, paths[i]) * exp(mag[i]))
	for t: int in range(THR.size()):
		if THR_INT[t] == 1:
			pol[THR[t]] = int(thr[t])
		else:
			pol[THR[t]] = thr[t]
	return pol

static func _refit(mu: Array[float], sd: Array[float], vecs: Array, fits: Array[float], k: int) -> void:
	var idx: Array[int] = _elite(fits, k)
	for d: int in range(mu.size()):
		var xs: Array[float] = []
		for j: int in idx:
			var row: Array[float] = vecs[j]
			xs.append(row[d])
		mu[d] = _mean(xs)
		sd[d] = _std(xs, mu[d])

static func _elite(fits: Array[float], k: int) -> Array[int]:
	var taken: Array[int] = []
	taken.resize(fits.size())
	taken.fill(0)
	var out: Array[int] = []
	for _n: int in range(k):
		var best: int = -1
		for i: int in range(fits.size()):
			if taken[i] == 1:
				continue
			if best < 0 or fits[i] > fits[best] or (fits[i] == fits[best] and i < best):
				best = i
		taken[best] = 1
		out.append(best)
	return out

static func _mean(xs: Array[float]) -> float:
	var s: float = 0.0
	for x: float in xs:
		s += x
	return s / float(xs.size())

static func _std(xs: Array[float], mean: float) -> float:
	if xs.size() < 2:
		return 0.02
	var s: float = 0.0
	for x: float in xs:
		var d: float = x - mean
		s += d * d
	return maxf(sqrt(s / float(xs.size() - 1)), 0.02)

static func _mag_paths() -> PackedStringArray:
	var d: Dictionary = Policy.sample_origin()
	var out: PackedStringArray = PackedStringArray()
	for group: String in ["card", "status", "special", "combat", "route", "relics", "relicRarity"]:
		_walk(d[group], group, out)
	for key: String in ["potionShopDefault", "potionHealing", "relicFallback", "relicDuskBonus",
			"relicAshBonus"]:
		out.append(key)
	return out

static func _walk(group: Variant, prefix: String, out: PackedStringArray) -> void:
	var d: Dictionary = group
	for key_v: Variant in d:
		var key: String = str(key_v)
		var value: Variant = d[key]
		var path: String = "%s.%s" % [prefix, key]
		if typeof(value) == TYPE_DICTIONARY:
			_walk(value, path, out)
		elif float(str(value)) != 0.0:
			out.append(path)

static func _at(d: Dictionary, path: String) -> float:
	var cur: Variant = d
	for part: String in path.split("."):
		var node: Dictionary = cur
		cur = node[part]
	return float(str(cur))

static func _put(d: Dictionary, path: String, value: float) -> void:
	var parts: PackedStringArray = path.split(".")
	var node: Dictionary = d
	for i: int in range(parts.size() - 1):
		var child: Variant = node[str(parts[i])]
		node = child
	node[str(parts[parts.size() - 1])] = value

static func _spec(path: String, island: int) -> Dictionary:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(raw) != TYPE_DICTIONARY:
		return {"error": "seedsJson is not an object"}
	var seeds: Dictionary = raw
	var grid: String = GRIDS[int(island / 6.0)]
	var local: int = island % 6
	var i: int = 0
	for item_v: Variant in seeds[grid]:
		if i == local:
			var item: Dictionary = item_v
			return item
		i += 1
	return {"error": "island %d missing in %s" % [island, grid]}

static func _options(args: PackedStringArray) -> Dictionary:
	var out: Dictionary = {"island": 0, "seedsJson": "", "out": "", "popSize": 60, "elite": 15,
		"maxGen": 20, "seedCount": 40, "trainSeed0": 4200, "holdoutSeed0": 5000,
		"holdoutCount": 200, "rootSeed": 216}
	for arg: String in args:
		if not arg.begins_with("--") or not arg.contains("="):
			return {"error": "expected --name=value, got %s" % arg}
		var key: String = arg.get_slice("=", 0).trim_prefix("--")
		if not out.has(key):
			return {"error": "unknown option --%s" % key}
		out[key] = arg.substr(arg.find("=") + 1)
	for key: String in ["island", "popSize", "elite", "maxGen", "seedCount", "trainSeed0",
			"holdoutSeed0", "holdoutCount", "rootSeed"]:
		if not str(out[key]).is_valid_int():
			return {"error": "--%s must be an integer" % key}
		out[key] = int(float(str(out[key])))
	if str(out["out"]).is_empty() or str(out["seedsJson"]).is_empty():
		return {"error": "--out and --seedsJson are required"}
	if _i(out, "island") < 0 or _i(out, "island") > 23 or _i(out, "popSize") < 1 \
			or _i(out, "elite") < 1 or _i(out, "maxGen") < 1 or _i(out, "seedCount") < 1 \
			or _i(out, "holdoutCount") < 1:
		return {"error": "counts must be positive and --island 0..23"}
	return out

static func _i(values: Dictionary, key: String) -> int:
	return int(float(str(values[key])))
