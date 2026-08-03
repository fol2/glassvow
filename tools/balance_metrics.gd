class_name BalanceMetrics
extends RefCounted
## Aggregates retained run rows; no simulation law is duplicated here.

const Z95: float = 1.959963984540054


static func report(rows: Array[Dictionary], manifest: Dictionary) -> Dictionary:
	var grouped: Dictionary = {}
	for row: Dictionary in rows:
		var aspect: String = str(row["aspect"])
		if not grouped.has(aspect):
			grouped[aspect] = []
		var group: Array = grouped[aspect]
		group.append(row)
	var summary: Dictionary = {}
	for aspect: String in grouped:
		var group: Array = grouped[aspect]
		summary[aspect] = _aspect(group)
	return {
		"manifest": manifest,
		"calibration": _calibration(rows, summary, int(float(str(manifest["vow"])))),
		"summary": summary,
		"runs": rows,
	}


static func _aspect(rows: Array) -> Dictionary:
	var wins: int = 0
	var stalls: int = 0
	var errors: int = 0
	var by_act: Dictionary = {"1": [], "2": [], "3": []}
	for row_v: Variant in rows:
		var row: Dictionary = row_v
		wins += 1 if row.get("outcome") == "win" else 0
		stalls += 1 if row.get("outcome") == "stall" else 0
		errors += 1 if row.get("outcome") == "error" else 0
		for fight_v: Variant in row.get("fights", []):
			var fight: Dictionary = fight_v
			var fights: Array = by_act[str(fight["act"])]
			fights.append(fight)
	var rate: float = float(wins) / float(rows.size()) if not rows.is_empty() else 0.0
	var acts: Dictionary = {}
	for act: String in by_act:
		var fights: Array = by_act[act]
		acts[act] = _fights(fights)
	return {"runs": rows.size(), "wins": wins, "winRate": _round(rate),
		"wilson95": wilson95(wins, rows.size()), "stalls": stalls, "errors": errors,
		"acts": acts}


static func _fights(rows: Array) -> Dictionary:
	var hp: float = 0.0
	var turns: float = 0.0
	var shatters: float = 0.0
	var smolder: int = 0
	for row_v: Variant in rows:
		var row: Dictionary = row_v
		hp += float(str(row["hpLost"]))
		turns += float(str(row["turns"]))
		shatters += float(str(row["shatters"]))
		smolder += int(float(str(row["smolderKills"])))
	var n: float = float(rows.size())
	return {"fights": rows.size(), "hpLostPerFight": _round(hp / n) if n > 0 else 0.0,
		"turnsPerFight": _round(turns / n) if n > 0 else 0.0,
		"shattersPerFight": _round(shatters / n) if n > 0 else 0.0,
		"smolderKills": smolder, "smolderKillsPerFight": _round(float(smolder) / n) if n > 0 else 0.0}


static func wilson95(wins: int, total: int) -> Dictionary:
	if total == 0:
		return {"lower": 0.0, "upper": 0.0}
	var n: float = float(total)
	var p: float = float(wins) / n
	var z2: float = Z95 * Z95
	var denominator: float = 1.0 + z2 / n
	var centre: float = (p + z2 / (2.0 * n)) / denominator
	var margin: float = Z95 * sqrt((p * (1.0 - p) + z2 / (4.0 * n)) / n) / denominator
	return {"lower": _round(centre - margin), "upper": _round(centre + margin)}


static func _calibration(rows: Array[Dictionary], summary: Dictionary, vow: int) -> Dictionary:
	if vow != 0 or not summary.has("duskblade") or not summary.has("ashwarden"):
		return {"status": "NOT_EVALUATED", "reason": "requires both aspects at vow 0"}
	var dusk: Dictionary = summary["duskblade"]
	var ash: Dictionary = summary["ashwarden"]
	var paired: Dictionary = _paired_difference(rows)
	var d_rate: float = float(str(dusk["winRate"]))
	var a_rate: float = float(str(ash["winRate"]))
	var lead: float = a_rate - d_rate
	var d_ci: Dictionary = dusk["wilson95"]
	var a_ci: Dictionary = ash["wilson95"]
	var diff_ci: Dictionary = paired["ci95"]
	var result: Dictionary = {"status": "INCONCLUSIVE", "ashLead": _round(lead),
		"pairedRuns": paired["runs"], "pairedLead95": diff_ci,
		"reason": "increase the paired sample"}
	if int(float(str(paired["runs"]))) < 200:
		return result
	if float(str(d_ci["upper"])) < 0.8 or float(str(a_ci["upper"])) < 0.8 \
			or float(str(diff_ci["upper"])) < 0.10 or float(str(diff_ci["lower"])) > 0.25:
		result["status"] = "FAIL"
		result["reason"] = "confidence interval excludes the diagnosis"
	elif float(str(d_ci["lower"])) > 0.8 and float(str(a_ci["lower"])) > 0.8 \
			and float(str(diff_ci["lower"])) > 0.10 and float(str(diff_ci["upper"])) < 0.25:
		result["status"] = "PASS"
		result["reason"] = "point estimates and intervals reproduce the diagnosis"
	return result


static func _paired_difference(rows: Array[Dictionary]) -> Dictionary:
	var by_seed: Dictionary = {}
	for row: Dictionary in rows:
		var seed: int = int(float(str(row["seed"])))
		if not by_seed.has(seed):
			by_seed[seed] = {}
		var pair: Dictionary = by_seed[seed]
		pair[str(row["aspect"])] = 1.0 if row["outcome"] == "win" else 0.0
	var values: Array[float] = []
	for pair_v: Variant in by_seed.values():
		var pair: Dictionary = pair_v
		if pair.has("duskblade") and pair.has("ashwarden"):
			values.append(float(str(pair["ashwarden"])) - float(str(pair["duskblade"])))
	var mean: float = 0.0
	for value: float in values:
		mean += value
	mean /= float(values.size()) if not values.is_empty() else 1.0
	var variance: float = 0.0
	for value: float in values:
		variance += (value - mean) * (value - mean)
	var margin: float = Z95 * sqrt(variance / float(values.size() - 1) / float(values.size())) \
		if values.size() > 1 else 1.0
	return {"runs": values.size(), "mean": _round(mean),
		"ci95": {"lower": _round(mean - margin), "upper": _round(mean + margin)}}


static func _round(value: float) -> float:
	return snappedf(value, 0.000001)
