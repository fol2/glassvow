extends RefCounted
## The layout book: its canonical form, its schema, and the three-level merge.
##
## The load-bearing gate is `_canonical`. The book is the one authored file an
## editor will rewrite in place, and `enemy_view.gd:1636` shows the failure mode
## being avoided — that writer truncates the file before it has validated
## anything. Pinning the on-disk form to exactly what `JSON.stringify(…, "  ")`
## emits means the editor's first save is a zero-line diff, so any diff at all
## after an edit is the edit and nothing else.


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_layout_book: %s" % what)


## `got` is a Variant because every value here comes out of a parsed JSON
## dictionary. Absence reads as the caller's own sentinel and fails loudly.
static func _near(fails: Array[String], got: Variant, want: float, what: String) -> void:
	var v: float = _num(got)
	_check(fails, absf(v - want) < 0.001, "%s is %s, wanted %s" % [what, v, want])


static func run(fails: Array[String]) -> void:
	LayoutBook.reload()
	_canonical(fails)
	_schema(fails)
	_merge(fails)
	_layers(fails)
	_slots(fails)
	_provenance(fails)
	_flex(fails)
	_sizes(fails)
	_authoring(fails)
	# The book is a shared static cache and the authoring pass edited it in
	# memory. Anything downstream — `test_presentation` builds a real
	# CombatScreen — must meet the book as it is on disk.
	LayoutBook.reload()


# ------------------------------------------------------------------ authoring

## The editor's write path: which way a drag counts, where an edit lands, and
## what a revert leaves behind.
##
## Nothing here touches the file. `save()` is exercised only through its REFUSAL,
## because the one thing that must never happen is the file being truncated by an
## editor holding a book that does not validate — which is the defect
## `enemy_view.gd:1635` still had until `DataFile` took the writing over.
static func _authoring(fails: Array[String]) -> void:
	# A drag reads the schema and nothing else. A left-bound gap grows rightwards
	# and a right-bound one grows leftwards; an ABSOLUTE coordinate follows the
	# pointer either way, because its binding says where flex goes, not which way
	# the number counts. `hero/x` and `slot/x` are the pair that proves it: the
	# same axis, opposite edges, identical step.
	_check(fails, LayoutBook.drag_step(&"hero", "x") == Vector2(1.0, 0.0),
		"dragging right raises hero/x")
	_check(fails, LayoutBook.drag_step(&"slot", "x") == Vector2(1.0, 0.0),
		"dragging right raises slot/x, though it binds to the right edge")
	_check(fails, LayoutBook.drag_step(&"box", "right") == Vector2(-1.0, 0.0),
		"dragging right shrinks a right-bound gap")
	_check(fails, LayoutBook.drag_step(&"box", "left") == Vector2(1.0, 0.0),
		"dragging right grows a left-bound gap")
	_check(fails, LayoutBook.drag_step(&"stage", "groundY") == Vector2(0.0, -1.0),
		"dragging the ground line up raises groundY")
	_check(fails, LayoutBook.drag_step(&"layer", "x") == Vector2(1.0, 0.0),
		"a centred plate's offset follows the pointer")
	for field: String in ["w", "h"]:
		_check(fails, LayoutBook.drag_step(&"box", field) == Vector2.ZERO,
			"a drag never resizes: box/%s does not move" % field)
	_check(fails, LayoutBook.drag_step(&"layer", "zoom") == Vector2.ZERO,
		"a drag never zooms a plate")

	# An edit lands in the level it was told to, and `origin` says so — which is
	# the whole contract: the bench shows where a number comes from BEFORE the
	# edit, and where it went after.
	_check(fails, not LayoutBook.is_dirty(), "a freshly loaded book is clean")
	_check(fails, LayoutBook.origin(&"battlefield", &"pad-landscape", 0, "hero/w")
		== LayoutBook.FROM_BASE, "hero/w starts inherited from base")
	LayoutBook.author(&"battlefield", &"pad-landscape", 0, LayoutBook.FROM_SHAPE,
		"hero", "w", 191.0)
	_check(fails, LayoutBook.is_dirty(), "authoring marks the book edited")
	_check(fails, LayoutBook.origin(&"battlefield", &"pad-landscape", 0, "hero/w")
		== LayoutBook.FROM_SHAPE, "the edit promoted hero/w to a shape override")
	_near(fails, LayoutBook.resolve(&"battlefield", &"pad-landscape", 0)
		.get("hero", {}).get("w"), 191.0, "the override resolves")
	# …and the level below is untouched, so a revert has something to fall back to.
	LayoutBook.unauthor(&"battlefield", &"pad-landscape", 0, LayoutBook.FROM_SHAPE,
		"hero", "w")
	_check(fails, LayoutBook.origin(&"battlefield", &"pad-landscape", 0, "hero/w")
		== LayoutBook.FROM_BASE, "reverting drops back to base, not to nothing")
	_near(fails, LayoutBook.resolve(&"battlefield", &"pad-landscape", 0)
		.get("hero", {}).get("w"), 190.0, "and base's own value comes back")

	# A seat cannot be authored a field at a time. Arrays replace wholesale, so
	# the first edit to any seat must carry the whole formation into the bucket
	# or the other seats vanish on the next merge.
	var before: Array = LayoutBook.slots(
		LayoutBook.resolve(&"battlefield", &"pad-landscape", 0), 3)
	LayoutBook.author(&"battlefield", &"pad-landscape", 0, LayoutBook.FROM_ACT,
		"slots/3/1", "x", 851.0)
	var after: Array = LayoutBook.slots(
		LayoutBook.resolve(&"battlefield", &"pad-landscape", 0), 3)
	_check(fails, after.size() == 3, "editing one seat keeps all three")
	_near(fails, after[1].get("x"), 851.0, "the edited seat moved")
	_near(fails, after[0].get("x"), _num(before[0].get("x")), "seat 0 came along unchanged")
	_near(fails, after[2].get("x"), _num(before[2].get("x")), "seat 2 came along unchanged")
	LayoutBook.unauthor(&"battlefield", &"pad-landscape", 0, LayoutBook.FROM_ACT,
		"slots/3/1", "x")
	_near(fails, LayoutBook.slots(LayoutBook.resolve(&"battlefield", &"pad-landscape", 0),
		3)[1].get("x"), _num(before[1].get("x")), "reverting a seat reverts the formation")

	# The refusal. A book carrying a value outside its declared range must not
	# reach the file — and the file must still be there afterwards, byte for byte.
	var on_disk: String = FileAccess.get_file_as_string(LayoutBook.BOOK_PATH)
	LayoutBook.author(&"battlefield", &"pad-landscape", 0, LayoutBook.FROM_SHAPE,
		"", "groundY", 99999.0)
	_check(fails, not LayoutBook.save().is_empty(), "save refuses a book that fails validate")
	_check(fails, FileAccess.get_file_as_string(LayoutBook.BOOK_PATH) == on_disk,
		"and the refused save left the file untouched")

	# The writer's own two fixes, on a scratch path so nothing authored is at risk.
	var scratch: String = "user://test-data-file.json"
	_check(fails, DataFile.write(scratch, "").begins_with("refusing"),
		"the writer refuses to truncate a file to nothing")
	_check(fails, DataFile.write(scratch, DataFile.to_text({"b": 2, "a": 1})).is_empty(),
		"the writer writes")
	_check(fails, FileAccess.get_file_as_string(scratch) == "{\n  \"a\": 1,\n  \"b\": 2\n}\n",
		"canonical: sorted keys, two spaces, and the trailing newline")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch))


# -------------------------------------------------------------- canonical form

static func _canonical(fails: Array[String]) -> void:
	var src: String = FileAccess.get_file_as_string(LayoutBook.BOOK_PATH)
	_check(fails, not src.is_empty(), "the book is readable")
	var parsed: Variant = JSON.parse_string(src)
	_check(fails, parsed is Dictionary, "the book parses")
	if not parsed is Dictionary:
		return
	_check(fails, JSON.stringify(parsed, "  ") + "\n" == src,
		"the book is in canonical form (sorted keys, two-space indent, one trailing newline)")


# --------------------------------------------------------------------- schema

## Every field the schema names must belong to a form, and every form must be
## reachable from a scope. A field nobody can author is dead weight; a form no
## scope points at is a serialiser waiting to be re-invented.
static func _schema(fails: Array[String]) -> void:
	for key: StringName in LayoutBook.FIELDS:
		var parts: PackedStringArray = String(key).split("/")
		_check(fails, parts.size() == 2, "%s is a form/field pair" % key)
		if parts.size() != 2:
			continue
		var form: StringName = StringName(parts[0])
		_check(fails, LayoutBook.FORMS.has(form), "%s names a real form" % key)
		if LayoutBook.FORMS.has(form):
			var order: PackedStringArray = LayoutBook.FORMS.get(form, PackedStringArray())
			_check(fails, order.find(parts[1]) >= 0,
				"%s is listed in its form's field order" % key)
		var spec: Dictionary = LayoutBook.FIELDS[key]
		_check(fails, spec.has("bind") and spec.has("unit"), "%s declares bind and unit" % key)

	var used: Dictionary = {}
	for scope: StringName in LayoutBook.SCOPES:
		for path: String in LayoutBook.SCOPES[scope]:
			used[LayoutBook.SCOPES[scope][path]] = true
	for form: StringName in LayoutBook.FORMS:
		_check(fails, used.has(form), "form %s is reachable from a scope" % form)
		# THROUGH `fields()`, and the SIZE first. `LayoutBook.FORMS[form]` with a
		# variable key hands back a value that reports itself empty (see the
		# pinned hazard below), so this loop used to run zero times and the
		# assertion inside it had never once executed while the suite reported
		# PASS. A guard for a container that lies about being empty must fail on
		# the count before it walks anything.
		var order: PackedStringArray = LayoutBook.fields(form)
		_check(fails, order.size() > 0, "form %s has a non-empty field order" % form)
		for field: String in order:
			_check(fails, LayoutBook.FIELDS.has(StringName("%s/%s" % [form, field])),
				"%s/%s is declared" % [form, field])

	# The engine hazard `LayoutBook._fields` exists to route around, pinned so a
	# future simplification back to `has()` fails here rather than silently in
	# the validator. On 4.7.1 a PackedStringArray taken out of a typed Dictionary
	# by a runtime-built key answers has() false and find() 0 for the same string.
	# If this ever starts passing, the workaround may go — but only then.
	var built: StringName = StringName("st" + "age")
	var raw_order: PackedStringArray = LayoutBook.FORMS[built]
	_check(fails, raw_order.find("groundY") >= 0,
		"find() locates a field through a runtime-built form key")
	# And the SIZE, which is the half the first diagnosis missed: `has()` lying
	# reads as a comparison bug, `size()` returning 0 for a two-item array names
	# the real fault. If this ever reports 2, the const has stopped dropping its
	# packed type and `fields()` can go back to a subscript.
	_check(fails, raw_order.size() == 0,
		"a const typed Dictionary still hands back an empty-looking packed array")

	# …and the book itself must satisfy all of it. This is the check that catches
	# a hand edit before a fight does.
	var complaints: PackedStringArray = LayoutBook.validate()
	_check(fails, complaints.is_empty(),
		"the book validates (%s)" % ", ".join(complaints))


# ---------------------------------------------------------------------- merge

## base -> shape -> act, with the exact numbers upstream authors, so a silent
## reordering of the three levels cannot pass.
static func _merge(fails: Array[String]) -> void:
	var bf: StringName = &"battlefield"

	# base only: `phone-portrait` never mentions ledgeLip, so it inherits 14.
	var phone: Dictionary = LayoutBook.resolve(bf, &"phone-portrait", 0)
	_near(fails, phone.get("ledgeLip", -1.0), 14.0, "phone-portrait ledgeLip (base)")
	_near(fails, phone.get("groundY", -1.0), 250.0, "phone-portrait groundY (shape over base 232)")

	# shape over base: pad-landscape moves the hero from 179 to 200 and changes
	# nothing else about him, so w and h still come from base.
	var pad: Dictionary = LayoutBook.resolve(bf, &"pad-landscape", 0)
	var hero: Dictionary = pad.get("hero", {})
	_near(fails, hero.get("x", -1.0), 200.0, "pad-landscape hero.x (shape)")
	_near(fails, hero.get("w", -1.0), 190.0, "pad-landscape hero.w (base)")
	_near(fails, hero.get("h", -1.0), 285.0, "pad-landscape hero.h (base)")

	# act over shape over base: act 1 lowers the ground line to 220.
	_near(fails, pad.get("groundY", -1.0), 232.0, "pad-landscape act 0 groundY (base)")
	var pad1: Dictionary = LayoutBook.resolve(bf, &"pad-landscape", 1)
	_near(fails, pad1.get("groundY", -1.0), 220.0, "pad-landscape act 1 groundY (act)")

	# an unknown shape degrades to base rather than throwing — upstream's rule,
	# and the reason a typo in `--shape=` costs a wrong composition, not a crash.
	var unknown: Dictionary = LayoutBook.resolve(bf, &"no-such-shape", 0)
	_near(fails, unknown.get("groundY", -1.0), 232.0, "an unknown shape resolves to base")

	# arrays replace WHOLESALE. pad-landscape re-authors the 3-slot formation
	# (middle x 845 -> 850) and leaves the 1-slot one alone.
	var slots3: Array[Dictionary] = LayoutBook.slots(pad, 3)
	_check(fails, slots3.size() == 3, "pad-landscape authors three slots for three foes")
	if slots3.size() == 3:
		_near(fails, slots3[1].get("x", -1.0), 850.0, "pad-landscape slot 2 x (shape array)")
	var slots1: Array[Dictionary] = LayoutBook.slots(pad, 1)
	if slots1.size() == 1:
		_near(fails, slots1[0].get("x", -1.0), 980.0, "pad-landscape slot 1 x (base array)")

	# chrome resolves the same way and by the same code — the whole point of one
	# book. `endTurn` is re-pinned at pad-landscape; `draw` is untouched base.
	var chrome: Dictionary = LayoutBook.resolve(&"chrome", &"pad-landscape", 0)
	var end_turn: Dictionary = chrome.get("endTurn", {})
	_near(fails, end_turn.get("right", -1.0), 0.0, "pad-landscape endTurn.right (shape)")
	_near(fails, end_turn.get("bottom", -1.0), 163.0, "pad-landscape endTurn.bottom (shape)")
	_near(fails, chrome.get("draw", {}).get("left", -1.0), 16.0, "pad-landscape draw.left (base)")
	_near(fails, chrome.get("hud", {}).get("height", -1.0), 56.0, "pad-landscape hud.height (base)")
	# …and the act dimension is real but unused here: chrome authors no acts, so
	# every act must return the same chrome.
	_check(fails, LayoutBook.resolve(&"chrome", &"pad-landscape", 2) == chrome,
		"chrome is act-independent, as authored")


# --------------------------------------------------------------------- layers

static func _layers(fails: Array[String]) -> void:
	for shape: StringName in StageShape.REFERENCES:
		var layout: Dictionary = LayoutBook.resolve(&"battlefield", shape, 0)
		var layers: Dictionary = layout.get("layers", {})
		for name: String in LayoutBook.LAYERS:
			_check(fails, layers.has(name),
				"%s always has a %s plate, authored or not" % [shape, name])

	# The defaults that are not in the book: posY and drift per plate. The ground
	# must not slide underfoot, so its drift is 0 and stays 0.
	var pad: Dictionary = LayoutBook.resolve(&"battlefield", &"pad-landscape", 0)
	var ledge: Dictionary = pad["layers"]["ledge"]
	_near(fails, ledge.get("drift", -1.0), 0.0, "the ledge never drifts")
	_near(fails, ledge.get("posY", -1.0), 0.0, "the ledge crops from its top")
	var phone: Dictionary = LayoutBook.resolve(&"battlefield", &"phone-portrait", 0)
	_near(fails, phone["layers"]["backdrop"].get("posY", -1.0), 100.0,
		"phone-portrait backdrop posY (schema default)")
	_near(fails, phone["layers"]["backdrop"].get("drift", -1.0), 20.0,
		"phone-portrait backdrop drift (authored, beating the default 6)")

	# The one place all three levels meet on a NESTED key. pad-landscape authors
	# backdrop.y = 0 at the shape; act 0 overrides it to 280 and act 1 changes the
	# plate height with it, while posX is never touched by either and stays base.
	_near(fails, pad["layers"]["backdrop"].get("y", -1.0), 280.0,
		"pad-landscape act 0 backdrop.y (act, beating the shape's 0)")
	_near(fails, pad["layers"]["backdrop"].get("h", -1.0), 640.0,
		"…with the plate height still base")
	var pad1: Dictionary = LayoutBook.resolve(&"battlefield", &"pad-landscape", 1)
	_near(fails, pad1["layers"]["backdrop"].get("h", -1.0), 800.0,
		"pad-landscape act 1 backdrop.h (act)")
	_near(fails, pad1["layers"]["backdrop"].get("posX", -1.0), 50.0,
		"…while posX still comes from base")


# ---------------------------------------------------------------------- slots

static func _slots(fails: Array[String]) -> void:
	var pad: Dictionary = LayoutBook.resolve(&"battlefield", &"pad-landscape", 0)
	# A count nobody authored spreads along the widest authored formation at its
	# smallest size, so an unplanned lineup lands on the ledge rather than off it.
	var four: Array[Dictionary] = LayoutBook.slots(pad, 4)
	_check(fails, four.size() == 4, "four foes get four slots")
	if four.size() == 4:
		_near(fails, four[0].get("x", -1.0), 698.0, "the spread starts at the widest formation's left")
		_near(fails, four[3].get("x", -1.0), 996.0, "…and ends at its right")
		_check(fails, _num(four[1]["x"]) > _num(four[0]["x"])
				and _num(four[2]["x"]) > _num(four[1]["x"]),
			"…strictly left to right in between")

	# A book with no formations at all still answers, because a fight that cannot
	# place its foes is worse than one that places them badly.
	var bare: Array[Dictionary] = LayoutBook.slots({}, 2)
	_check(fails, bare.size() == 2, "an unauthored book still yields slots")


# ----------------------------------------------------------------- provenance

## The question `bf-editor.js:14-15` cannot answer, and the reason editing a
## number there silently promotes it to a shape override.
static func _provenance(fails: Array[String]) -> void:
	var bf: StringName = &"battlefield"
	_check(fails, LayoutBook.origin(bf, &"pad-landscape", 0, "hero/x") == LayoutBook.FROM_SHAPE,
		"pad-landscape hero.x is authored at the shape")
	_check(fails, LayoutBook.origin(bf, &"pad-landscape", 0, "hero/w") == LayoutBook.FROM_BASE,
		"pad-landscape hero.w is inherited from base")
	_check(fails, LayoutBook.origin(bf, &"pad-landscape", 1, "groundY") == LayoutBook.FROM_ACT,
		"pad-landscape act 1 groundY is authored at the act")
	_check(fails, LayoutBook.origin(bf, &"pad-landscape", 0, "groundY") == LayoutBook.FROM_BASE,
		"…and at act 0 it is base again")
	_check(fails, LayoutBook.origin(bf, &"pad-landscape", 0, "hero/y") == LayoutBook.FROM_DEFAULT,
		"hero.y is nowhere in the book and comes from the schema")
	_check(fails, LayoutBook.origin(bf, &"pad-landscape", 0, "hero/nonsense")
			== LayoutBook.FROM_ABSENT,
		"a key nobody authored reports absent rather than guessing")

	# Provenance is only true while resolving stays read-only. A shallow copy
	# anywhere in the merge lets `_defaults` write into the cached book, after
	# which every schema default reports itself as authored at base — invisible in
	# the composition and fatal to the editor's whole reason for existing.
	var before: String = JSON.stringify(LayoutBook.raw(), "  ")
	for shape: StringName in StageShape.REFERENCES:
		for act: int in [0, 1, 2]:
			LayoutBook.resolve(bf, shape, act)
			LayoutBook.resolve(&"chrome", shape, act)
	LayoutBook.resolve(bf, &"no-such-shape", 0)
	_check(fails, JSON.stringify(LayoutBook.raw(), "  ") == before,
		"resolving never writes back into the book")


# ---------------------------------------------------------------- shape sizing

## The per-shape sizing table, measured off the running benchmark @ 6e06911 by
## reading each element's client rect over the stage transform at every
## `?shape=`, and pinned here.
##
## These are the numbers the benchmark keeps in `styles.css` rather than in
## `ui-chrome-layout.js` — the `--cw` custom property, `.hand-zone { height }`,
## `.hand-zone .card { bottom }`, the energy orb's box and the whole HUD rail —
## which is why the port had none of them and drew a pad's 152px card on a 390px
## phone. A `@container stage` regime has no editor upstream and no schema, so
## nothing was ever going to notice they were missing. This table is what
## noticing looks like.
static func _sizes(fails: Array[String]) -> void:
	# shape: card w, card inset, hand h, energy w, energy h, hud height, hud title
	var want: Dictionary[StringName, Array] = {
		&"pad-landscape": [152.0, 8.0, 260.0, 120.0, 90.0, 56.0, 1.0],
		&"desktop-landscape": [152.0, 8.0, 260.0, 120.0, 90.0, 56.0, 1.0],
		&"pad-portrait": [132.0, 8.0, 230.0, 102.0, 78.0, 56.0, 1.0],
		&"phone-portrait": [118.0, 46.0, 214.0, 84.0, 66.0, 47.0, 0.0],
		&"phone-landscape": [104.0, 0.0, 128.0, 72.0, 57.0, 34.0, 1.0],
	}
	var paths: PackedStringArray = ["card/w", "card/inset", "hand/h",
		"energy/w", "energy/h", "hud/height", "hud/title"]
	for shape: StringName in want:
		var L: Dictionary = LayoutBook.resolve(&"chrome", shape, 0)
		var row: Array = want[shape]
		for i: int in paths.size():
			var parts: PackedStringArray = paths[i].split("/")
			var widget: Dictionary = L.get(parts[0], {})
			var expect: float = row[i]
			_near(fails, widget.get(parts[1]), expect, "%s %s" % [shape, paths[i]])
		# Every shape must seat the port's own Kindle chip, or it falls back to a
		# literal that is a third of a phone's width.
		var kindle: Dictionary = L.get("kindle", {})
		_check(fails, not kindle.is_empty(), "%s seats the kindle chip" % shape)

	# The identity shape is the identity in this scope too: every figure above is
	# the one the port drew before shapes existed, so `card/w` is exactly the
	# authored silhouette and no card is rescaled at 1180x820.
	var identity: Dictionary = LayoutBook.resolve(&"chrome", StageShape.IDENTITY, 0)
	_near(fails, identity.get("card", {}).get("w"), CardView.CARD_W,
		"the identity card is drawn at CARD_W")
	_near(fails, identity.get("actor", {}).get("scale"), 1.0,
		"the identity actor plate is unscaled")

	# A phone shrinks its actor chrome and a pad does not — one ratio, because
	# `_plate` is the single box a name, ward, HP rail and facets all hang in.
	var phone: Dictionary = LayoutBook.resolve(&"chrome", &"phone-portrait", 0)
	_check(fails, LayoutBook.num(phone.get("actor", {}).get("scale"), 1.0) < 1.0,
		"a phone shrinks its actor chrome")


# ----------------------------------------------------------------------- flex

## What `place` spends the stage's extra room on. The rule is that widening a
## side-view fight opens the gap BETWEEN the two lines: the hero holds his
## distance from the left edge, the foes hold theirs from the right.
static func _flex(fails: Array[String]) -> void:
	var bf: StringName = &"battlefield"
	var shape: StringName = &"pad-landscape"
	var ref: Vector2i = StageShape.REFERENCES[shape]
	var authored: Dictionary = LayoutBook.resolve(bf, shape, 0)

	# Identity: an unflexed stage must not move a single number. This is the same
	# gate `tests/test_stage_shape.gd` puts on the stage size, one level up.
	_check(fails, LayoutBook.place(bf, authored, shape, ref) == authored,
		"an unflexed stage leaves the layout untouched")

	var wide: Vector2i = ref + Vector2i(120, 0)
	var flexed: Dictionary = LayoutBook.place(bf, authored, shape, wide)
	_near(fails, flexed["hero"].get("x", -1.0), 200.0,
		"the hero holds his distance from the left edge")
	var slot: Dictionary = LayoutBook.slots(flexed, 1)[0]
	_near(fails, slot.get("x", -1.0), 980.0 + 120.0,
		"the foe holds his distance from the right edge")
	_near(fails, flexed["layers"]["mid"].get("x", -1.0),
		_num(authored["layers"]["mid"].get("x")),
		"a plate offset is measured from centre and does not move")
	_near(fails, flexed.get("groundY", -1.0), _num(authored.get("groundY")),
		"the ground line is a distance from the bottom and does not move")

	# The chrome scope has no absolute coordinates at all — every widget is a gap
	# from the edge it names — so the flex must pass straight through it.
	var chrome: Dictionary = LayoutBook.resolve(&"chrome", shape, 0)
	_check(fails, LayoutBook.place(&"chrome", chrome, shape, wide) == chrome,
		"the chrome scope is flex-invariant by construction")

	# …and the composed call agrees with the two steps taken separately.
	_check(fails, LayoutBook.for_stage(bf, shape, 0, wide) == flexed,
		"for_stage is place(resolve(...))")


static func _num(v: Variant) -> float:
	if v is float:
		var f: float = v
		return f
	if v is int:
		var i: int = v
		return float(i)
	return 0.0
