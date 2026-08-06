extends SceneTree
## Content hydration overlay: the active language's `content.*` strings land on
## the live ContentDB rows presentation already reads (issues #100/#101/#102).
##
## Runs under `tests/run_all.gd` through the static `run`, and standalone as
## `godot --headless -s res://tests/test_locale_hydration.gd`.

## A stand-in catalogue holding every shape the real one uses: the flat
## `textUp` rename (bake: `up.text`), statuses under the SINGULAR `status`,
## moves nested by id, event choices keyed by index, event rolls keyed by roll
## id, quest string arrays, aspects keyed by row id, vows/acts by array index.
const FAKE_TREE: Dictionary = {
	"cards": {"strike": {"name": "鋒刃", "text": "造成 @6@ 傷害。", "textUp": "造成 @9@ 傷害。"}},
	"relics": {"emberHeart": {"name": "燼心"}},
	"enemies": {"sporeling": {"name": "孢生", "moves": {"spit": {"name": "孢子噴吐"}}}},
	"status": {"str": {"name": "熾熱", "desc": "內火高漲。"}},
	"events": {
		"gambler": {
			"name": "骨骰賭徒",
			"choices": {"0": {"label": "押上四十金", "sub": "四成五機會贏得一百一十金。"}},
			"rolls": {"win": {"text": "骨骰偏向你。"}},
		},
	},
	"quests": {"paleOnes": {"name": "蒼白者", "progress": ["透鏡無光。"]}},
	"aspects": {"duskblade": {"name": "暮刃"}},
	"vows": {"0": {"name": "鐵之誓"}},
	"acts": {"0": {"name": "灰燼林", "bossName": "根心"}},
	"variants": {"paleDuskfang": {"name": "蒼白暮牙"}},
	"shadeKits": {"duskblade": {"moves": {"eclipse": {"name": "追憶之蝕"}}}},
	"potions": {"healing": {"name": "曙光之瓶"}}, "boons": {"fullPurse": {"name": "滿囊"}},
	"omens": {"eighthOmen": {"name": "第八徵兆"}}, "affixes": {"vitrified": {"name": "琉璃化"}},
	"arts": {"flare": {"name": "耀焰"}}, "deeds": {"paneBreaker": {"name": "碎窗者"}},
}


static func run(fails: Array[String]) -> void:
	_english_is_a_no_op(fails)
	_seed_matches_the_bake(fails)
	_overlay_reaches_the_live_rows(fails)
	_missing_keys_leave_the_bake(fails)
	_real_zh_catalogue(fails)


## The English seed must agree with the bake on every display string it carries.
## A disagreement is invisible in English — `en` hydration is a no-op — but
## zh-Hant inherits the seed's wording, so a drifted string renders a wrong
## number over correct mechanics the moment the player switches language.
## Applying the `en` tree through the real overlay is the check: if the seed
## agrees, the overlay is a no-op; anything it rewrites is drift.
static func _seed_matches_the_bake(fails: Array[String]) -> void:
	var file: FileAccess = FileAccess.open(Locale.EN_PATH, FileAccess.READ)
	if file == null:
		fails.append("hydration: cannot open %s" % Locale.EN_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		fails.append("hydration: %s is not a JSON object" % Locale.EN_PATH)
		return
	var root: Dictionary = parsed
	# `overlay_content` takes the content sub-dict, not the whole bundle: its
	# keys are domain names, so handing it the root silently matches nothing
	# and writes zero — a gate that cannot fail.
	var content_v: Variant = root.get("content", {})
	if typeof(content_v) != TYPE_DICTIONARY:
		fails.append("hydration: %s has no content object" % Locale.EN_PATH)
		return
	var tree: Dictionary = content_v
	var db: ContentDB = ContentDB.load_full()
	var before: String = _fingerprint(db)
	var undo: Array = []
	var wrote: int = Locale.overlay_content(db, tree, undo)
	if wrote == 0 and not tree.is_empty():
		fails.append("hydration: the seed gate matched no domain at all — it cannot fail")
		return
	if _fingerprint(db) == before:
		return
	# Name the drifted rows rather than only the count: the fix is per string.
	var drifted: PackedStringArray = []
	for entry: Array in undo:
		var container: Variant = entry[0]
		var key: Variant = entry[1]
		var was: Variant = entry[2]
		var now: Variant = container[key]
		if typeof(was) == TYPE_STRING and typeof(now) == TYPE_STRING and was != now:
			drifted.append("%s: bake %s / seed %s" % [key, was, now])
	fails.append("hydration: %s disagrees with the bake on %d display string(s): %s"
		% [Locale.EN_PATH, drifted.size(), ", ".join(drifted)])


## English is the bake: `full-content.json` carries the balanced text, so
## hydrating `en` must not copy `locale/en.json` over it. The seed is generated
## from the pre-P6 web fixture, so it drifts whenever balance edits a display
## string — `emberHeart` said "heal 6 HP" against a rebalanced 3 until it was
## corrected (`1e0f0b9` moved the number; the seed did not follow).
## `_seed_matches_the_bake` below is the gate that catches the next one.
static func _english_is_a_no_op(fails: Array[String]) -> void:
	var db: ContentDB = ContentDB.load_full()
	var before: String = _fingerprint(db)
	var written: int = Locale.new().hydrate_content(db)
	if written != 0:
		fails.append("hydration: English wrote %d strings; it must be a no-op" % written)
	if _fingerprint(db) != before:
		fails.append("hydration: English hydration changed the baked catalogue")
	if _at(db.relics, ["emberHeart", "text"]) != "At the end of combat, heal 3 HP.":
		fails.append("hydration: English hydration resurrected the stale seed relic text")


static func _overlay_reaches_the_live_rows(fails: Array[String]) -> void:
	var db: ContentDB = ContentDB.load_full()
	var bake: String = _fingerprint(db)
	var card_ids: Array[StringName] = db.card_ids()
	var enemy_ids: Array[StringName] = db.enemy_ids()
	var undo: Array = []
	var written: int = Locale.overlay_content(db, FAKE_TREE, undo)
	if written < 24:
		fails.append("hydration: overlay wrote only %d strings" % written)
	if undo.size() != written:
		fails.append("hydration: undo log holds %d of %d writes" % [undo.size(), written])
	var checks: Array = [
		[db.cards, ["strike", "name"], "鋒刃"],
		[db.cards, ["strike", "up", "text"], "造成 @9@ 傷害。"],
		[db.enemies, ["sporeling", "moves", "spit", "name"], "孢子噴吐"],
		[db.statuses, ["str", "desc"], "內火高漲。"],
		[db.events, ["gambler", "choices", "0", "label"], "押上四十金"],
		[db.events, ["gambler", "choices", "0", "ops", "1", "roll", "win", "text"], "骨骰偏向你。"],
		[db.quests, ["paleOnes", "progress", "0"], "透鏡無光。"],
		[db.aspects, ["duskblade", "name"], "暮刃"],
		[db.vows, ["0", "name"], "鐵之誓"],
		[db.acts, ["0", "bossName"], "根心"],
		[db.variants, ["paleDuskfang", "name"], "蒼白暮牙"],
		[db.shade_kits, ["duskblade", "moves", "eclipse", "name"], "追憶之蝕"],
	]
	for check: Array in checks:
		var path: Array = check[1]
		var got: String = _at(check[0], path)
		if got != str(check[2]):
			fails.append("hydration: %s did not reach the live row (got '%s')"
				% [".".join(PackedStringArray(path)), got])
	# Idempotent: a second overlay changes nothing, and unwinding both logs
	# returns the English bake exactly.
	var after_first: String = _fingerprint(db)
	var again: Array = []
	if Locale.overlay_content(db, FAKE_TREE, again) != written:
		fails.append("hydration: re-overlay wrote a different number of slots")
	if _fingerprint(db) != after_first:
		fails.append("hydration: a second overlay changed the rows again")
	if db.card_ids() != card_ids or db.enemy_ids() != enemy_ids:
		fails.append("hydration: content IDs moved")
	_unwind(again)
	_unwind(undo)
	if _fingerprint(db) != bake:
		fails.append("hydration: unwinding the overlay did not return the English bake")


## `Locale.t` ends its fallback chain at the key itself, so a blind assignment
## would stamp `content.statuses.vulnerable.desc` into the UI. The overlay
## writes only over an existing string slot — a miss leaves the bake alone.
static func _missing_keys_leave_the_bake(fails: Array[String]) -> void:
	var db: ContentDB = ContentDB.load_full()
	var before: String = _fingerprint(db)
	var undo: Array = []
	var wrong: Dictionary = {
		"statuses": {"vulnerable": {"desc": "content.statuses.vulnerable.desc"}},
		"cards": {"noSuchCard": {"name": "x"}, "strike": {"noSuchField": "x", "up": {"nope": "x"}}},
		"enemies": {"sporeling": {"moves": {"noSuchMove": {"name": "x"}}}},
		"aspects": {"noSuchAspect": {"name": "x"}},
		"vows": {"99": {"name": "x"}},
		"quests": {"paleOnes": {"progress": ["a", "b", "c", "d", "e", "f", "g", "h"]}},
	}
	var written: int = Locale.overlay_content(db, wrong, undo)
	var progress: Array = db.quests.get("paleOnes", {}).get("progress", [])
	if written != progress.size():
		fails.append("hydration: misses wrote %d strings; only the %d real progress lines exist"
			% [written, progress.size()])
	if _at(db.statuses, ["vulnerable", "desc"]).begins_with("content."):
		fails.append("hydration: a key literal was stamped onto a status row")
	_unwind(undo)
	if _fingerprint(db) != before:
		fails.append("hydration: a missed catalogue left the bake modified")


## The shipped zh-Hant catalogue through the real handle — the boot path.
static func _real_zh_catalogue(fails: Array[String]) -> void:
	var db: ContentDB = ContentDB.load_full()
	var bake: String = _fingerprint(db)
	var locale: Locale = Locale.new(Locale.CODE_ZH_HANT)
	if locale.code != Locale.CODE_ZH_HANT:
		fails.append("hydration: zh-Hant catalogue did not load")
		return
	var written: int = locale.hydrate_content(db)
	if written < 400:
		fails.append("hydration: zh-Hant reached only %d of ~607 content strings" % written)
	if _at(db.cards, ["strike", "name"]) == "Edge":
		fails.append("hydration: zh-Hant left the card name English")
	if not _at(db.cards, ["strike", "text"]).contains("@6@"):
		fails.append("hydration: zh-Hant card text lost its @n@ markers")
	locale.restore_content()
	if _fingerprint(db) != bake:
		fails.append("hydration: zh-Hant did not restore to the English bake")


## Navigate the bake the way the overlay does — dictionary key, array index, or
## row `id`. Assertions compare against literals, so a wrong turn still fails.
static func _at(root: Variant, path: Array) -> String:
	var node: Variant = root
	for step: Variant in path:
		node = Locale._child(node, str(step))
		if node == null:
			return ""
	return str(node) if typeof(node) == TYPE_STRING else ""


static func _probe(rows: Array) -> String:
	var out: PackedStringArray = []
	for probe: Array in rows:
		var path: Array = probe[1]
		out.append("%s=%s" % [str(path[0]), _at(probe[0], path)])
	return " | ".join(out)


static func _unwind(undo: Array) -> void:
	var locale: Locale = Locale.new()
	locale._overlaid = undo
	locale.restore_content()


static func _fingerprint(db: ContentDB) -> String:
	return JSON.stringify([
		db.cards, db.relics, db.enemies, db.statuses, db.events, db.quests,
		db.aspects, db.vows, db.acts, db.variants, db.shade_kits, db.potions,
		db.boons, db.omens, db.affixes, db.arts, db.deeds,
	])


func _initialize() -> void:
	var fails: Array[String] = []
	run(fails)
	# Evidence the overlay reaches the fields the screens read. The shipped
	# zh-Hant catalogue only authors cards and six statuses so far, so the
	# stand-in tree follows to show a relic and an enemy moving too.
	var db: ContentDB = ContentDB.load_full()
	var probes: Array = [
		[db.cards, ["strike", "name"]], [db.statuses, ["poison", "name"]],
		[db.relics, ["emberHeart", "name"]], [db.enemies, ["sporeling", "name"]],
	]
	print("bake     " + _probe(probes))
	var written: int = Locale.new(Locale.CODE_ZH_HANT).hydrate_content(db)
	print("zh-Hant  %s (%d strings)" % [_probe(probes), written])
	Locale.overlay_content(db, FAKE_TREE, [])
	print("stand-in " + _probe(probes))
	if fails.is_empty():
		print("PASS test_locale_hydration")
		quit(0)
		return  # `quit` only requests the exit; the frame keeps running.
	print("FAIL test_locale_hydration (%d)" % fails.size())
	for msg: String in fails:
		print("  - %s" % msg)
	quit(1)
