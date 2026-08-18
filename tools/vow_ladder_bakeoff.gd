extends SceneTree
## #211 bake-off driver. One process, sequential cells. Penalty cells pass
## catalog `none`; empty mix on the sim follows live shipping A.
const Sim: GDScript = preload("res://tools/balance_sim.gd")
const Metrics: GDScript = preload("res://tools/balance_metrics.gd")
const Incentives: GDScript = preload("res://tools/vow_incentives.gd")
const Clock: GDScript = preload("res://tools/vigil_clock.gd")

const SEED0: int = 7000
const CLOCK_SEED0: int = 9000


func _initialize() -> void:
	var opts: Dictionary = _options(OS.get_cmdline_user_args())
	if opts.has("error"):
		push_error("vow_ladder_bakeoff: %s" % opts["error"])
		quit(2)
		return
	var suite: String = str(opts["suite"])
	var out_dir: String = str(opts["out"])
	if not out_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(out_dir)
	var cells: Array[Dictionary] = []
	match suite:
		"penalties":
			cells = _run_penalties(int(float(str(opts["runs"]))))
		"mixes":
			cells = _run_mixes(int(float(str(opts["runs"]))))
		"clock":
			cells = _run_clock()
		"smoke":
			cells = _run_smoke()
		_:
			push_error("vow_ladder_bakeoff: unknown --suite")
			quit(2)
			return
	var text: String = JSON.stringify({"suite": suite, "cells": cells})
	if out_dir.is_empty():
		print(text)
	else:
		var path: String = "%s/%s.json" % [out_dir, suite]
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			push_error("vow_ladder_bakeoff: cannot write %s" % path)
			quit(2)
			return
		file.store_string(text + "\n")
		_write_csv("%s/%s.csv" % [out_dir, suite], cells)
		print(JSON.stringify({"suite": suite, "cells": cells.size(), "out": path}))
	quit(0)


static func _run_penalties(n: int) -> Array[Dictionary]:
	var cells: Array[Dictionary] = []
	var none: Dictionary = Incentives.by_id("none")
	for vow: int in range(6):
		cells.append(_cell("ladder", vow, false, none, n, false, ""))
	for name: String in ["iron", "malice", "deep", "mark", "waning", "deadhex", "empty1"]:
		cells.append(_cell("iso", int(float(str(Incentives.isolate(_fresh(), name)["vow"]))),
			false, none, n, false, name))
	return cells


static func _run_mixes(n: int) -> Array[Dictionary]:
	var cells: Array[Dictionary] = []
	# Penalty-only weak control so the crossover (strong lift vs weak lift) is measured.
	var none: Dictionary = Incentives.by_id("none")
	cells.append(_cell("mix", 5, true, none, n, false, ""))
	for mix: Dictionary in Incentives.catalog():
		var id: String = str(mix["id"])
		if id == "none":
			continue
		for vow: int in [0, 2, 5]:
			cells.append(_cell("mix", vow, false, mix, n, false, ""))
		cells.append(_cell("mix", 5, true, mix, n, false, ""))
	return cells


static func _run_clock() -> Array[Dictionary]:
	var cells: Array[Dictionary] = []
	var content: ContentDB = ContentDB.load_full(false)
	var none: Dictionary = Incentives.by_id("none")
	for vow: int in [0, 5]:
		cells.append(Clock.chain(content, "duskblade", CLOCK_SEED0, vow, none, 20, 10, 30, false))
		cells.append(Clock.chain(content, "ashwarden", CLOCK_SEED0, vow, none, 20, 10, 30, false))
	var modest: Dictionary = Incentives.by_id("A_modest_linear")
	cells.append(Clock.chain(content, "duskblade", CLOCK_SEED0, 5, modest, 20, 10, 30, false))
	cells.append(Clock.chain(content, "duskblade", CLOCK_SEED0, 5, modest, 20, 10, 30, true))
	return cells


static func _run_smoke() -> Array[Dictionary]:
	var cells: Array[Dictionary] = []
	var none: Dictionary = Incentives.by_id("none")
	cells.append(_cell("ladder", 0, false, none, 2, false, ""))
	cells.append(_cell("iso", 1, false, none, 2, false, "deadhex"))
	return cells


static func _cell(kind: String, vow: int, weak: bool, mix: Dictionary, n: int,
		strip: bool, isolate_name: String) -> Dictionary:
	var content: ContentDB = _fresh()
	var iso_strip: bool = strip
	if not isolate_name.is_empty():
		var spec: Dictionary = Incentives.isolate(content, isolate_name)
		vow = int(float(str(spec.get("vow", vow))))
		iso_strip = spec.get("strip_hex", false) == true
	var rows: Array[Dictionary] = []
	for aspect: String in ["duskblade", "ashwarden"]:
		for i: int in range(n):
			rows.append(Sim.simulate(content, aspect, SEED0 + i, vow, PackedStringArray(),
				{}, weak, weak, mix, null, iso_strip))
	var summary: Dictionary = _summarise(rows)
	summary["kind"] = kind
	summary["vow"] = vow
	summary["weak"] = weak
	summary["mix"] = str(mix.get("id", "none"))
	summary["isolate"] = isolate_name
	summary["concentration"] = _concentration(rows)
	summary["elitesPerWin"] = _elites_per_win(rows)
	var dusk_v: Variant = summary["duskblade"]
	var ash_v: Variant = summary["ashwarden"]
	var dusk: Dictionary = dusk_v
	var ash: Dictionary = ash_v
	print("cell %s v%d %s mix=%s n=%d dusk=%.3f ash=%.3f" % [
		kind, vow, "weak" if weak else "strong", summary["mix"], n,
		float(str(dusk.get("winRate", 0))), float(str(ash.get("winRate", 0))),
	])
	return summary


static func _summarise(rows: Array[Dictionary]) -> Dictionary:
	var grouped: Dictionary = {"duskblade": [], "ashwarden": []}
	for row: Dictionary in rows:
		var aspect: String = str(row["aspect"])
		var group: Array = grouped[aspect]
		group.append(row)
	var out: Dictionary = {}
	for aspect: String in grouped:
		var group: Array = grouped[aspect]
		var wins: int = 0
		var gold: float = 0.0
		var hp: float = 0.0
		for row_v: Variant in group:
			var row: Dictionary = row_v
			if str(row.get("outcome", "")) == "win":
				wins += 1
			gold += float(str(row.get("goldEarned", 0)))
			hp += float(str(row.get("hp", 0)))
		var n: int = group.size()
		var rate: float = float(wins) / float(n) if n > 0 else 0.0
		out[aspect] = {
			"runs": n, "wins": wins, "winRate": Metrics._round(rate),
			"wilson95": Metrics.wilson95(wins, n),
			"meanGold": Metrics._round(gold / float(n)) if n > 0 else 0.0,
			"meanHp": Metrics._round(hp / float(n)) if n > 0 else 0.0,
			"eRunsTo10": Clock.expected_wins(rate, 10),
			"eOwnShade": Clock.expected_own_shade(rate),
		}
	return out


static func _concentration(rows: Array[Dictionary]) -> Dictionary:
	var wins: int = 0
	var relics: Dictionary = {}
	for row: Dictionary in rows:
		if str(row.get("outcome", "")) != "win":
			continue
		wins += 1
		for id_v: Variant in row.get("relics", []):
			var id: String = str(id_v)
			relics[id] = int(float(str(relics.get(id, 0)))) + 1
	var top_id: String = ""
	var top_n: int = 0
	for id: String in relics:
		var n: int = int(float(str(relics[id])))
		if n > top_n:
			top_n = n
			top_id = id
	return {
		"wins": wins, "topRelic": top_id,
		"topShare": Metrics._round(float(top_n) / float(wins)) if wins > 0 else 0.0,
	}


static func _elites_per_win(rows: Array[Dictionary]) -> float:
	var n: int = 0
	var elites: int = 0
	for row: Dictionary in rows:
		if str(row.get("outcome", "")) != "win":
			continue
		n += 1
		for fight_v: Variant in row.get("fights", []):
			var fight: Dictionary = fight_v
			if str(fight.get("kind", "")) == "elite":
				elites += 1
	return Metrics._round(float(elites) / float(n)) if n > 0 else 0.0


static func _fresh() -> ContentDB:
	return ContentDB.load_full(false)


static func _write_csv(path: String, cells: Array[Dictionary]) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_line("kind,vow,weak,mix,isolate,aspect,wins,runs,winRate,lo,hi,gold,eRunsTo10,eOwnShade,topRelic,topShare")
	for cell: Dictionary in cells:
		if cell.has("nVigils"):
			file.store_line("clock,%s,%s,,,,,%s,,%s" % [
				cell.get("vow", ""), cell.get("weak", ""), cell.get("nVigils", ""),
				cell.get("meanRuns", ""),
			])
			continue
		for aspect: String in ["duskblade", "ashwarden"]:
			if not cell.has(aspect):
				continue
			var a: Dictionary = cell[aspect]
			var ci: Dictionary = a.get("wilson95", {})
			var conc: Dictionary = cell.get("concentration", {})
			file.store_line("%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s" % [
				cell.get("kind", ""), cell.get("vow", ""), cell.get("weak", ""),
				cell.get("mix", ""), cell.get("isolate", ""), aspect,
				a.get("wins", ""), a.get("runs", ""), a.get("winRate", ""),
				ci.get("lower", ""), ci.get("upper", ""), a.get("meanGold", ""),
				a.get("eRunsTo10", ""), a.get("eOwnShade", ""),
				conc.get("topRelic", ""), conc.get("topShare", ""),
			])


static func _options(args: PackedStringArray) -> Dictionary:
	var out: Dictionary = {"suite": "smoke", "runs": 80, "out": ""}
	for arg: String in args:
		if not arg.begins_with("--") or not arg.contains("="):
			return {"error": "expected --name=value, got %s" % arg}
		var key: String = arg.get_slice("=", 0).trim_prefix("--")
		if not out.has(key):
			return {"error": "unknown option --%s" % key}
		out[key] = arg.substr(arg.find("=") + 1)
	if not str(out["runs"]).is_valid_int():
		return {"error": "--runs must be an integer"}
	out["runs"] = int(float(str(out["runs"])))
	if str(out["suite"]) not in ["penalties", "mixes", "clock", "smoke"]:
		return {"error": "--suite must be penalties, mixes, clock or smoke"}
	return out
