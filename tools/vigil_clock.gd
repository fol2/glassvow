class_name VigilClock
extends RefCounted
## Cross-run instrument: chain 3-act sims into a Vigil ledger.
## Measures runs-to-N-wins (the closed emberglass clock). Shards stay 0
## unless a run actually completes a quest — the 3-act sim does not.

const Sim: GDScript = preload("res://tools/balance_sim.gd")
const ARM_WINS: Array[int] = [1, 2, 4, 6, 8, 10]


static func chain(content: ContentDB, aspect: String, seed0: int, vow: int,
		mix: Dictionary, n_vigils: int, win_target: int, cap: int,
		weak: bool) -> Dictionary:
	var times: Array[int] = []
	var armed_at: Dictionary = {}
	for w: int in ARM_WINS:
		armed_at[w] = []
	var shard_hits: int = 0
	var capped: int = 0
	for v: int in range(n_vigils):
		var vigil: VigilState = VigilState.blank()
		var runs: int = 0
		var wins: int = 0
		var hit: Dictionary = {}
		while wins < win_target and runs < cap:
			var seed: int = seed0 + v * cap + runs
			var row: Dictionary = Sim.simulate(content, aspect, seed, vow,
				PackedStringArray(), {}, weak, weak, mix, vigil, false)
			runs += 1
			if str(row.get("outcome", "")) == "win":
				wins += 1
				for w: int in ARM_WINS:
					if wins == w and not hit.has(w):
						hit[w] = runs
						var bucket: Array = armed_at[w]
						bucket.append(runs)
			if vigil.shards.size() >= 6:
				shard_hits += 1
				break
		if wins >= win_target:
			times.append(runs)
		else:
			capped += 1
			times.append(cap)
	return {
		"aspect": aspect, "vow": vow, "nVigils": n_vigils, "winTarget": win_target,
		"cap": cap, "weak": weak, "capped": capped, "shardHits": shard_hits,
		"meanRuns": _mean(times), "medianRuns": _median(times),
		"armedMean": _armed_means(armed_at),
	}


static func expected_wins(p: float, k: int) -> float:
	if p <= 0.0:
		return INF
	return float(k) / p


static func expected_own_shade(p: float) -> float:
	if p <= 0.0 or p >= 1.0:
		return INF
	return expected_wins(p, 2) + 3.0 / (1.0 - p)


static func _mean(values: Array[int]) -> float:
	if values.is_empty():
		return 0.0
	var s: int = 0
	for v: int in values:
		s += v
	return float(s) / float(values.size())


static func _median(values: Array[int]) -> float:
	if values.is_empty():
		return 0.0
	var copy: Array[int] = values.duplicate()
	copy.sort()
	var n: int = copy.size()
	if n % 2 == 1:
		return float(copy[n / 2])
	return 0.5 * float(copy[n / 2 - 1] + copy[n / 2])


static func _armed_means(armed_at: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for w: int in ARM_WINS:
		var bucket: Array = armed_at[w]
		var nums: Array[int] = []
		for v: Variant in bucket:
			nums.append(int(float(str(v))))
		out[w] = _mean(nums)
	return out
