class_name LayoutBook
extends RefCounted
## The authored layout for every stage shape, and the schema that describes it.
##
## The benchmark keeps this in two files with two editors and two serialisers —
## `battlefield-layout.js` + `bf-editor.js` + `bf-serialize.js` for the fight,
## `ui-chrome-layout.js` + `bfui-editor.js` + `bfui-serialize.js` for the chrome —
## roughly 1.6k lines doing one job twice. They are two editors for ONE screen,
## split only by the order they were built in. The reason the second copy exists
## is that each serialiser re-declares its schema implicitly, in code, so neither
## could be reused for the other's data.
##
## So the schema is declared HERE, once, as data. `FIELDS` says what a number
## means; `FORMS` says which numbers a thing has and in what order a human should
## meet them; `SCOPES` says where those things sit in the file. That one
## declaration is what the resolver defaults from, what the validator checks,
## what the flex correction walks, and what the editor will build its widgets
## from. Adding a scope — reward, map, card — is a `SCOPES` entry and a bucket in
## the JSON, not a change to anything here.
##
## The DATA is `assets/layout/combat-layout.json`, transliterated verbatim from
## the benchmark at 6e06911. It lives in `assets/` and not `content/`, which
## `docs/session-ownership.md:69` puts off-limits to visual work; the precedent
## next door is `assets/art/enemies/char-meta.json`.
##
## Resolution is the benchmark's three-level key-wise merge (`battlefield.js:59-83`,
## `uic.js:36-47`): base, then the shape, then the act. Arrays replace wholesale,
## so a shape that touches one formation must supply that formation complete —
## upstream's rule, kept, because a half-merged slot array has no sane meaning.
##
## Pure by construction, like `StageShape`: no Node, no `DisplayServer`, every
## input an argument. `tests/test_layout_book.gd` drives all five shapes headlessly.

const BOOK_PATH: String = "res://assets/layout/combat-layout.json"

## How many acts a run has, and therefore how many act buckets a shape may hold.
## Three upstream, clamped to three in the benchmark's own editor
## (`src/dev/bf-editor.js:169`). Here rather than in a caller because it is a fact
## about the schema, and both the bench and `--act=` need it.
const ACTS: int = 3

## Which stage edge a number is measured from. Drives the flex correction and,
## later, which drag handle the editor draws.
const BIND_LEFT: StringName = &"left"
const BIND_RIGHT: StringName = &"right"
const BIND_TOP: StringName = &"top"
const BIND_BOTTOM: StringName = &"bottom"
const BIND_CENTRE: StringName = &"centre"
const BIND_NONE: StringName = &"none"

## Where a resolved value came from, for the editor's provenance readout. The
## benchmark cannot answer this question at all — `bf-editor.js:14-15` writes into
## a fixed bucket, so a number in front of you might be authored at this shape or
## inherited from base, and editing it silently promotes it to an override.
const FROM_ACT: StringName = &"act"
const FROM_SHAPE: StringName = &"shape"
const FROM_BASE: StringName = &"base"
const FROM_DEFAULT: StringName = &"default"
const FROM_ABSENT: StringName = &"absent"

## Every authorable number, keyed `form/field`.
##
##   bind      — the edge it is measured from (BIND_*).
##   absolute  — the number is a COORDINATE in the shape's reference frame rather
##               than a distance from `bind`. Only such values need correcting
##               when the stage flexes; everything else is already edge-relative
##               and survives a wider stage untouched. True in exactly two places,
##               and those two are the whole of `place()`'s work.
##   unit      — "px" | "ratio" | "percent". The editor's widget choice.
##   min/max   — validator bounds, and the editor's slider range.
##   default   — filled in by `resolve` when the key is absent everywhere. A field
##               without one stays absent, which is meaningful: an unauthored
##               `footY` means "use the actor's own", not "use zero".
const FIELDS: Dictionary[StringName, Dictionary] = {
	# --- battlefield: the stage itself
	&"stage/groundY": {"bind": BIND_BOTTOM, "unit": "px", "min": 0.0, "max": 1200.0},
	&"stage/ledgeLip": {"bind": BIND_NONE, "unit": "px", "min": 0.0, "max": 200.0},

	# --- battlefield: the hero, bound LEFT so widening opens the gap to the foes
	&"hero/x": {"bind": BIND_LEFT, "absolute": true, "unit": "px", "min": 0.0, "max": 1600.0},
	&"hero/y": {"bind": BIND_BOTTOM, "unit": "px", "min": -400.0, "max": 400.0, "default": 0.0},
	&"hero/w": {"bind": BIND_NONE, "unit": "px", "min": 0.0, "max": 800.0},
	&"hero/h": {"bind": BIND_NONE, "unit": "px", "min": 0.0, "max": 800.0},

	# --- battlefield: a foe slot, bound RIGHT for the same reason, from the far
	# side. Extra width lands between the two lines rather than inside either.
	&"slot/x": {"bind": BIND_RIGHT, "absolute": true, "unit": "px", "min": 0.0, "max": 1600.0},
	&"slot/y": {"bind": BIND_BOTTOM, "unit": "px", "min": -400.0, "max": 400.0, "default": 0.0},
	&"slot/s": {"bind": BIND_NONE, "unit": "ratio", "min": 0.1, "max": 3.0, "default": 1.0},
	&"slot/footX": {"bind": BIND_NONE, "unit": "px", "min": -400.0, "max": 400.0},
	&"slot/footY": {"bind": BIND_NONE, "unit": "px", "min": -400.0, "max": 400.0},

	# --- battlefield: a scenery plate. `x` is already an offset from centred, so
	# it is edge-relative in the only sense that matters and is not `absolute`.
	&"layer/h": {"bind": BIND_NONE, "unit": "px", "min": 0.0, "max": 2400.0},
	&"layer/y": {"bind": BIND_BOTTOM, "unit": "px", "min": -600.0, "max": 1600.0},
	&"layer/x": {"bind": BIND_CENTRE, "unit": "px", "min": -800.0, "max": 800.0},
	&"layer/zoom": {"bind": BIND_NONE, "unit": "ratio", "min": 0.05, "max": 4.0},
	&"layer/posX": {"bind": BIND_NONE, "unit": "percent", "min": 0.0, "max": 100.0},
	&"layer/posY": {"bind": BIND_NONE, "unit": "percent", "min": 0.0, "max": 100.0},
	&"layer/opacity": {"bind": BIND_NONE, "unit": "ratio", "min": 0.0, "max": 1.0},
	&"layer/drift": {"bind": BIND_NONE, "unit": "px", "min": 0.0, "max": 200.0},

	# --- chrome: one widget box. Every value is a gap from the edge it names, so
	# nothing here is `absolute` and `place()` leaves the whole scope alone.
	&"box/left": {"bind": BIND_LEFT, "unit": "px", "min": 0.0, "max": 1600.0},
	&"box/right": {"bind": BIND_RIGHT, "unit": "px", "min": 0.0, "max": 1600.0},
	&"box/top": {"bind": BIND_TOP, "unit": "px", "min": 0.0, "max": 1600.0},
	&"box/bottom": {"bind": BIND_BOTTOM, "unit": "px", "min": -200.0, "max": 1600.0},
	&"box/w": {"bind": BIND_NONE, "unit": "px", "min": 0.0, "max": 600.0},
	&"box/h": {"bind": BIND_NONE, "unit": "px", "min": 0.0, "max": 600.0},
	&"box/scale": {"bind": BIND_NONE, "unit": "ratio", "min": 0.1, "max": 3.0, "default": 1.0},

	# --- chrome: the HUD rail, which is a height and a scale rather than a box.
	#
	# `scale`, `title` and `stat` are the port's answer to fourteen CSS
	# declarations. The benchmark re-states the bar's font sizes, icon boxes,
	# potion boxes, gaps and padding in each `@container stage` regime
	# (`styles.css:2106-2117, 2189-2197`) — every one of them a fixed multiple of
	# the desktop figure, between 0.83 and 0.9, with two exceptions that are real
	# decisions rather than shrinkage: the HP block drops much further than the
	# rest (170 to 96), and the location line is `display: none` on a phone held
	# upright because 390px has no room for it. So one ratio carries the
	# shrinkage and those two exceptions are stated on their own.
	&"hud/height": {"bind": BIND_NONE, "unit": "px", "min": 0.0, "max": 240.0},
	&"hud/scale": {"bind": BIND_NONE, "unit": "ratio", "min": 0.1, "max": 3.0, "default": 1.0},
	## Whether the location line is shown at all. Below 1 it goes: there is no
	## half-shown title, and a shrinking one runs off the edge instead.
	&"hud/title": {"bind": BIND_NONE, "unit": "ratio", "min": 0.0, "max": 1.0, "default": 1.0},
	## The HP block's own width, which does not follow `scale` — see above.
	&"hud/stat": {"bind": BIND_NONE, "unit": "px", "min": 40.0, "max": 400.0, "default": 170.0},

	# --- chrome: how big a card in the hand is, and how far it sits above the
	# hand box's own floor. The benchmark keeps both in `styles.css` rather than
	# in `ui-chrome-layout.js`, as the `--cw` custom property and a `bottom` on
	# `.hand-zone .card`, re-declared in each `@container stage` regime
	# (`:500, 2059, 2134, 2206` and `:620, 2139, 2211`). They are layout numbers
	# that vary per shape and have no editor upstream, which is the whole reason
	# a phone-portrait card was drawn at the pad's 152px and covered a third of
	# the stage. Measured off the running benchmark, not read off the source.
	&"card/w": {"bind": BIND_NONE, "unit": "px", "min": 40.0, "max": 400.0, "default": 152.0},
	&"card/inset": {"bind": BIND_BOTTOM, "unit": "px", "min": -200.0, "max": 400.0, "default": 8.0},

	# --- chrome: how big an actor draws its own ground chrome. See
	# `EnemyView.set_chrome_scale` for why one ratio rather than four numbers.
	&"actor/scale": {"bind": BIND_NONE, "unit": "ratio", "min": 0.2, "max": 2.0, "default": 1.0},

	# --- map: the waystone field. Rows are steps along the pilgrimage (the
	# walk axis); columns are lanes across it. The vertical Spire's row-gap and
	# column-gutter died with that frame — what replaced them is a STEP along X
	# and a LANE GAP along Y, both rate-clamped so a wider stage shows the same
	# NUMBER of steps rather than more of them. See `WorldMapScreen._step`.
	#
	# `pathY` is where the centre lane sits; `horizonY` is the ground line
	# `_draw` reads; `lead` is the fraction of the stage the camera holds the
	# current node at (the lead-third rule). Portrait shapes may override the
	# rates later — P5.7 — the defaults alone keep every reference readable.
	&"trail/scale": {"bind": BIND_NONE, "unit": "ratio", "min": 0.05, "max": 2.0, "default": 0.36},
	## Steps are `stepRate` of the stage width apart, held inside `[stepMin,
	## stepMax]`. The rate keeps the same NUMBER of nodes on screen as the
	## stage grows; the band stops a phone held sideways from packing them.
	&"trail/stepRate": {"bind": BIND_NONE, "unit": "ratio", "min": 0.05, "max": 0.6, "default": 0.22},
	&"trail/stepMin": {"bind": BIND_NONE, "unit": "px", "min": 40.0, "max": 600.0, "default": 150.0},
	&"trail/stepMax": {"bind": BIND_NONE, "unit": "px", "min": 40.0, "max": 600.0, "default": 290.0},
	## Lanes are `laneRate` of the stage height apart, held inside `[laneMin,
	## laneMax]`. Col 3 is the centre lane; depth still compresses the gap.
	&"trail/laneRate": {"bind": BIND_NONE, "unit": "ratio", "min": 0.01, "max": 0.3, "default": 0.06},
	&"trail/laneMin": {"bind": BIND_NONE, "unit": "px", "min": 8.0, "max": 200.0, "default": 34.0},
	&"trail/laneMax": {"bind": BIND_NONE, "unit": "px", "min": 8.0, "max": 200.0, "default": 50.0},
	&"trail/pathY": {"bind": BIND_NONE, "unit": "ratio", "min": 0.2, "max": 0.9, "default": 0.52},
	&"trail/horizonY": {"bind": BIND_NONE, "unit": "ratio", "min": 0.2, "max": 0.9, "default": 0.64},
	## Where in the frame the camera seats the current node. A third from the
	## left leaves the road ahead readable without parking the lantern mid-stage.
	&"trail/lead": {"bind": BIND_NONE, "unit": "ratio", "min": 0.1, "max": 0.6, "default": 0.333},
	## The smallest a waystone may be to the finger, in stage px. Zero on the
	## shapes a mouse points at, 44 on a phone — the floor Apple's HIG and
	## Material both set. It grows the HIT rect only; see `GlassWaystone.
	## set_touch_min` for why that costs no pixels and no extra node.
	&"trail/touch": {"bind": BIND_NONE, "unit": "px", "min": 0.0, "max": 120.0, "default": 0.0},

	# --- map: the top rail. One ratio carries the shrinkage, and the line that
	# cannot shrink usefully is switched off instead of squeezed.
	#
	# `region` is gone. It was authored against a `size.x < 650.0` threshold in
	# the old `refresh()`, that function was rewritten, and no defect ever
	# pointed at it again — so unlike `title`, which earned its keep the day the
	# Spire rail started saying the same words, this one had no case behind it.
	# A field with no reader is not automatically wrong; this one was.
	&"mapbar/scale": {"bind": BIND_NONE, "unit": "ratio", "min": 0.1, "max": 3.0, "default": 1.0},
	&"mapbar/title": {"bind": BIND_NONE, "unit": "ratio", "min": 0.0, "max": 1.0, "default": 1.0},
	## Where the act line sits when `title` is on. Bound to the top because the
	## rail it hangs under is; `inset` is the margin it keeps off both sides,
	## which is what stops a long act name being clipped on a narrow stage.
	&"mapbar/titleTop": {"bind": BIND_TOP, "unit": "px", "min": 0.0, "max": 400.0, "default": 62.0},
	&"mapbar/titleH": {"bind": BIND_NONE, "unit": "px", "min": 8.0, "max": 200.0, "default": 26.0},
	&"mapbar/titleInset": {"bind": BIND_NONE, "unit": "px", "min": 0.0, "max": 400.0, "default": 0.0},

	# --- run: the choice panel every non-combat decision is drawn in. It asked
	# for a 520px minimum width inside a 24px inset, which on a 390px stage is
	# 178px wider than the stage has, hanging 89px off each side; and a 420px
	# scroll floor, which is taller than a phone held sideways is.
	&"panel/w": {"bind": BIND_NONE, "unit": "px", "min": 120.0, "max": 1600.0, "default": 520.0},
	&"panel/inset": {"bind": BIND_NONE, "unit": "px", "min": 0.0, "max": 200.0, "default": 24.0},
	&"panel/scroll": {"bind": BIND_NONE, "unit": "px", "min": 80.0, "max": 1600.0, "default": 420.0},
	&"panel/scale": {"bind": BIND_NONE, "unit": "ratio", "min": 0.1, "max": 3.0, "default": 1.0},

	# --- run: the title screen, which is the same Control in its `_title_variant`
	# and was the largest inline shape table left in the port. Fourteen figures
	# across five branches, keyed off `size.x >= 1000.0 and size.y <= 860.0` — a
	# threshold with no shape name on it that happens to select exactly the two
	# wide-and-short references, and does so with 38px of margin once flex has
	# been spent. That is an enumeration written as a measurement, and the two
	# read differently the first time a sixth shape is authored.
	#
	# The three width formulas collapsed to one each without changing an output:
	# `minf(wordmarkMax, size.x * wordmarkRate)` and `minf(columnW, size.x - 32)`.
	## The wordmark is a picture of a name, so it is capped in px AND held to a
	## share of the stage — the cap keeps it from swelling on a wide desktop, the
	## share keeps it off both edges on a narrow phone.
	&"titlescreen/wordmarkMax": {"bind": BIND_NONE, "unit": "px", "min": 80.0, "max": 1600.0, "default": 520.0},
	&"titlescreen/wordmarkRate": {"bind": BIND_NONE, "unit": "ratio", "min": 0.05, "max": 1.0, "default": 0.60},
	&"titlescreen/columnW": {"bind": BIND_NONE, "unit": "px", "min": 120.0, "max": 1600.0, "default": 340.0},
	&"titlescreen/gap": {"bind": BIND_NONE, "unit": "px", "min": 0.0, "max": 80.0, "default": 8.0},
	## How the two button blocks tile. A phone held sideways has room across and
	## none down, so the primary block goes two-wide there and nowhere else.
	&"titlescreen/primaryCols": {"bind": BIND_NONE, "unit": "count", "min": 1.0, "max": 4.0, "default": 1.0},
	&"titlescreen/utilityCols": {"bind": BIND_NONE, "unit": "count", "min": 1.0, "max": 4.0, "default": 2.0},
	&"titlescreen/primaryPt": {"bind": BIND_NONE, "unit": "px", "min": 8.0, "max": 48.0, "default": 17.0},
	&"titlescreen/utilityPt": {"bind": BIND_NONE, "unit": "px", "min": 8.0, "max": 48.0, "default": 13.0},
	## The tagline is the first thing to go: it is flavour, and a phone held
	## sideways needs the row for the buttons.
	&"titlescreen/tagline": {"bind": BIND_NONE, "unit": "ratio", "min": 0.0, "max": 1.0, "default": 1.0},
	&"titlescreen/taglinePt": {"bind": BIND_NONE, "unit": "px", "min": 6.0, "max": 32.0, "default": 14.0},
	&"titlescreen/taglineTrack": {"bind": BIND_NONE, "unit": "px", "min": 0.0, "max": 20.0, "default": 5.0},
	## Break "How to Play" over two rows. Wanted where the utility block is three
	## across and the buttons are therefore narrow, but never on a phone, where
	## the same three columns are narrower still and a second row costs more than
	## the wrap saves.
	&"titlescreen/wrapHelp": {"bind": BIND_NONE, "unit": "ratio", "min": 0.0, "max": 1.0, "default": 1.0},
	## The Emberglass medallion in the corner. The last inline shape ternary in
	## `_fit_title`, and it is here because leaving one behind in the function
	## whose table was just collected is how the next table starts.
	&"titlescreen/roseSide": {"bind": BIND_NONE, "unit": "px", "min": 16.0, "max": 200.0, "default": 78.0},

	# --- reward: the spoils rack. `CARD_SCALE` was a `const` derived from
	# `CardView.CARD_W` in four files, so a phone drew the pad's card and the
	# rack ran off the stage. Authored as a WIDTH, like `card/w`, because that
	# is the number a human can measure on the screen.
	&"rack/w": {"bind": BIND_NONE, "unit": "px", "min": 40.0, "max": 400.0, "default": 178.0},
	&"rack/gap": {"bind": BIND_NONE, "unit": "px", "min": 0.0, "max": 200.0, "default": 16.0},
	&"rack/scale": {"bind": BIND_NONE, "unit": "ratio", "min": 0.1, "max": 3.0, "default": 1.0},
	## The glass panel the spoils stand in, in its two states: `panel` while the
	## rows are up, `deep` once the offering has raised it. Both were constants
	## (560 and 640) against a stage that is 390 wide on a phone, so the cards
	## could be shrunk into a panel that still hung 194px off the right edge —
	## the defect a resolved-value table cannot show and one capture does.
	&"rack/panel": {"bind": BIND_NONE, "unit": "px", "min": 160.0, "max": 1600.0, "default": 560.0},
	&"rack/deep": {"bind": BIND_NONE, "unit": "px", "min": 160.0, "max": 1600.0, "default": 640.0},
	## What the panel's frame keeps clear at top and bottom. The top figure is
	## the benchmark's `.center-panel` padding, sized to clear a HUD that is
	## itself shorter on a phone.
	&"rack/top": {"bind": BIND_TOP, "unit": "px", "min": 0.0, "max": 400.0, "default": 96.0},
	&"rack/bottom": {"bind": BIND_BOTTOM, "unit": "px", "min": 0.0, "max": 400.0, "default": 20.0},
}

## The fields each form has, in the order a human should meet them. This is the
## editor's row order and the only reason `FIELDS` can be a flat table.
const FORMS: Dictionary[StringName, PackedStringArray] = {
	&"stage": ["groundY", "ledgeLip"],
	&"hero": ["x", "y", "w", "h"],
	&"slot": ["x", "y", "s", "footX", "footY"],
	&"layer": ["h", "y", "x", "zoom", "posX", "posY", "opacity", "drift"],
	&"box": ["left", "right", "top", "bottom", "w", "h", "scale"],
	&"hud": ["height", "scale", "title", "stat"],
	&"card": ["w", "inset"],
	&"actor": ["scale"],
	&"trail": ["scale", "stepRate", "stepMin", "stepMax", "laneRate", "laneMin", "laneMax",
		"pathY", "horizonY", "lead", "touch"],
	&"mapbar": ["scale", "title", "titleTop", "titleH", "titleInset"],
	&"panel": ["w", "inset", "scroll", "scale"],
	&"titlescreen": ["wordmarkMax", "wordmarkRate", "columnW", "gap",
		"primaryCols", "utilityCols", "primaryPt", "utilityPt",
		"tagline", "taglinePt", "taglineTrack", "wrapHelp", "roseSide"],
	&"rack": ["w", "gap", "scale", "panel", "deep", "top", "bottom"],
}

## Where each form's values sit inside a resolved layout. A path is slash-
## separated with `*` matching any key or index; the empty path is the layout
## itself. One walker serves every scope because of this table, which is the
## whole reason a new scope costs a line rather than a serialiser.
const SCOPES: Dictionary[StringName, Dictionary] = {
	&"battlefield": {
		"": &"stage",
		"hero": &"hero",
		"slots/*/*": &"slot",
		"layers/*": &"layer",
	},
	&"chrome": {
		"energy": &"box", "lantern": &"box", "endTurn": &"box",
		"draw": &"box", "discard": &"box", "ashes": &"box",
		"omen": &"box", "relics": &"box", "hand": &"box",
		# The port's own control, not one of `UIC`'s. It has no upstream seat —
		# the benchmark burns a card for embers from the card itself — so it was
		# parked at a fixed (16, 66, 116x32) under the rail. That is 30% of a
		# phone's width. A widget on the screen needs a seat per shape whether or
		# not it came from the reference, and giving it one costs this line.
		"kindle": &"box",
		# Not a UIC widget — it is the ACTOR's own name, ward, HP rail and facets.
		# It lives here because it is a chrome size that varies per shape, and a
		# second place for those is how the benchmark ended up with two editors.
		"actor": &"actor",
		"hud": &"hud", "card": &"card",
	},
	## The world map. The trail's own numbers sit at the root, the rail is a
	## sub-dict — the same shape as `battlefield`, and for the same reason: the
	## thing the screen IS goes at the root and its parts hang off it.
	&"map": {
		"": &"trail",
		"bar": &"mapbar",
	},
	## Every non-combat decision panel: title, vigil, run menu, lamplighter. The
	## title screen hangs off the same scope rather than taking its own, because
	## it is the same Control in a variant and shares the panel's re-pick path.
	&"run": {
		"": &"panel",
		"title": &"titlescreen",
	},
	## The spoils rack. Four reward screens share one rack size, which is what
	## made four copies of `CARD_SCALE` possible in the first place.
	&"reward": {
		"": &"rack",
	},
}

## The three scenery plates, in back-to-front order, and the defaults each one
## carries where the book is silent (`battlefield.js:50-55`). Per-layer rather
## than per-field because the default is the only thing that varies between
## them: the ground must not drift, so its amplitude is 0 and the sky's is 6.
const LAYERS: PackedStringArray = ["backdrop", "mid", "ledge"]
const LAYER_DEFAULTS: Dictionary[StringName, Dictionary] = {
	&"backdrop": {"x": 0.0, "posY": 100.0, "drift": 6.0},
	&"mid": {"x": 0.0, "posY": 100.0, "drift": 3.0},
	&"ledge": {"x": 0.0, "posY": 0.0, "drift": 0.0},
}

## Widgets that must pin to exactly one horizontal edge, never both and never
## neither (`ui-chrome-layout.js:6-7`). `hud` is not a box and is exempt.
const ONE_EDGE_WIDGETS: PackedStringArray = [
	"energy", "lantern", "endTurn", "draw", "discard", "ashes", "omen", "relics", "hand",
	"kindle",
]

static var _book: Dictionary = {}
static var _dirty: bool = false


## The book as authored, loaded once. Callers must not mutate the result — the
## editor's write path goes through its own copy, and this one is shared.
static func raw() -> Dictionary:
	if _book.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BOOK_PATH))
		if parsed is Dictionary:
			_book = parsed
		else:
			push_error("layout book: cannot parse %s" % BOOK_PATH)
	return _book


## Drop the cache so the next `raw()` re-reads from disk. The editor's soft-apply
## hook (`battlefield.js:12-21` does this with a listener set); here the caller
## simply re-resolves, because nothing caches a resolved layout.
static func reload() -> void:
	_book = {}
	_dirty = false


## The authored layout for a shape and act, in that shape's REFERENCE px.
##
## This is what the editor shows and edits. Screens want `for_stage`, which is
## this plus the flex correction. An unknown shape resolves to base alone, which
## is upstream's behaviour and the reason a typo degrades rather than crashes.
static func resolve(scope: StringName, shape: StringName, act: int = 0) -> Dictionary:
	var scopes: Dictionary = raw().get("scopes", {})
	var book: Dictionary = scopes.get(String(scope), {})
	var shapes: Dictionary = book.get("shapes", {})
	var chunk: Dictionary = shapes.get(String(shape), {})
	var base: Dictionary = book.get("base", {})
	var layout: Dictionary = _merge(_strip_acts(base), _strip_acts(chunk))
	layout = _merge(layout, _act_over(chunk, act))
	if SCOPES.get(scope, {}).has("layers/*"):
		layout["layers"] = _layers_of(layout)
	return _defaults(scope, layout)


## The layout a screen should draw with: `resolve`, then the flex spent on the
## edge each number is bound to.
static func for_stage(scope: StringName, shape: StringName, act: int,
		stage: Vector2i) -> Dictionary:
	return place(scope, resolve(scope, shape, act), shape, stage)


## Spend the flex. A stage only ever grows from its reference (`StageShape.
## stage_size`), so the slack is non-negative and this only ever pushes values
## outward — nothing is ever squeezed and no composition is cropped.
##
## Only `absolute` fields move, which today means `hero/x` and `slot/x`. The
## whole chrome scope passes through untouched, and that is not an oversight:
## every chrome number is already a gap from the edge it names, so a wider stage
## keeps each widget exactly where it was relative to its own corner.
static func place(scope: StringName, layout: Dictionary, shape: StringName,
		stage: Vector2i) -> Dictionary:
	var ref: Vector2i = StageShape.REFERENCES.get(shape, StageShape.REFERENCES[StageShape.IDENTITY])
	var slack: Vector2 = Vector2(stage - ref)
	if slack.is_zero_approx():
		return layout
	var out: Dictionary = layout.duplicate(true)
	for path: String in SCOPES.get(scope, {}):
		var form: StringName = SCOPES[scope][path]
		for target: Dictionary in _walk(out, path):
			for field: String in fields(form):
				var spec: Dictionary = FIELDS.get(StringName("%s/%s" % [form, field]), {})
				if not spec.get("absolute", false) or not target.has(field):
					continue
				var bind: StringName = spec["bind"]
				var axis: float = slack.y if _is_vertical(bind) else slack.x
				target[field] = num(target[field]) + axis * _bind_share(bind)
	return out


## Where a resolved value came from, for the editor's provenance readout: the
## act bucket, the shape, base, a schema default, or nowhere at all. `path` is
## the same slash-separated form the `SCOPES` table uses, e.g. `hero/x`.
static func origin(scope: StringName, shape: StringName, act: int,
		path: String) -> StringName:
	var scopes: Dictionary = raw().get("scopes", {})
	var book: Dictionary = scopes.get(String(scope), {})
	var chunk: Dictionary = book.get("shapes", {}).get(String(shape), {})
	if _has_at(_act_over(chunk, act), path):
		return FROM_ACT
	if _has_at(_strip_acts(chunk), path):
		return FROM_SHAPE
	var base: Dictionary = book.get("base", {})
	if _has_at(_strip_acts(base), path):
		return FROM_BASE
	if _has_at(resolve(scope, shape, act), path):
		return FROM_DEFAULT
	return FROM_ABSENT


## The one dictionary a `SCOPES`-style path selects out of a resolved layout, or
## an empty one. The editor addresses a target by path and then wants its
## values; this keeps that from meaning a second copy of the walker.
static func at(layout: Dictionary, path: String) -> Dictionary:
	var found: Array[Dictionary] = _walk(layout, path)
	return found[0] if not found.is_empty() else {}


## The formation for an enemy count. A count the book does not author is spread
## along the widest one it does, at that formation's smallest size, which is
## `bfSlots` (`battlefield.js:96-113`) — chosen upstream so an unplanned lineup
## lands on the ledge rather than off the side of it.
static func slots(layout: Dictionary, count: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var table: Dictionary = layout.get("slots", {})
	var authored: Variant = table.get(str(count))
	if authored is Array:
		for entry: Variant in authored:
			var slot: Dictionary = entry
			out.append(slot)
		return out

	var counts: Array[int] = []
	for key: String in table:
		if key.is_valid_int():
			counts.append(int(key))
	if counts.is_empty():
		for i: int in count:
			out.append({"x": 200.0 + float(i) * 200.0, "s": 1.0})
		return out
	counts.sort()
	var src: Array = table[str(counts[counts.size() - 1])]
	var lo: Dictionary = src[0]
	var hi: Dictionary = src[src.size() - 1]
	for i: int in count:
		var t: float = 1.0 if count == 1 else float(i) / float(count - 1)
		out.append({
			"x": roundf(lerpf(num(lo.get("x")), num(hi.get("x")), t)),
			"s": minf(num(lo.get("s"), 1.0), num(hi.get("s"), 1.0)),
			"y": roundf(lerpf(num(lo.get("y")), num(hi.get("y")), t)),
		})
	return out


## Every complaint the book can earn: an unknown key, a value outside its
## declared range, a widget pinned to both edges or to neither. Empty means the
## book is authorable as-is. Run by the test suite, and by the editor before it
## is ever allowed to overwrite the file — `enemy_view.gd:1636` truncates first
## and validates never, and that defect is not being copied forward.
static func validate() -> PackedStringArray:
	var out: PackedStringArray = []
	var scopes: Dictionary = raw().get("scopes", {})
	for scope: StringName in SCOPES:
		var book: Dictionary = scopes.get(String(scope), {})
		if book.is_empty():
			out.append("%s: no such scope in the book" % scope)
			continue
		var shapes: Dictionary = book.get("shapes", {})
		for shape: String in shapes:
			if not StageShape.REFERENCES.has(StringName(shape)):
				out.append("%s.%s: not a stage shape" % [scope, shape])
		for shape: StringName in StageShape.REFERENCES:
			var acts: Array[int] = [0]
			for act: String in shapes.get(String(shape), {}).get("acts", {}):
				if act.is_valid_int():
					acts.append(int(act))
			for act: int in acts:
				_audit(out, scope, shape, act, resolve(scope, shape, act))
	return out


# ------------------------------------------------------------------ authoring

## The three levels an editor may write into, outermost first. They are the
## same names `origin()` reports, so "where did this come from" and "where will
## my edit go" are answered in one vocabulary — which is the whole point, and
## exactly what `bf-editor.js:14-15` cannot do with its one fixed bucket.
const LEVELS: Array[StringName] = [FROM_BASE, FROM_SHAPE, FROM_ACT]


## Has the book been edited since it was loaded or last saved?
static func is_dirty() -> bool:
	return _dirty


## How one pixel of pointer movement changes a field. `Vector2.ZERO` means the
## field is not a position and a drag must leave it alone.
##
## Derived entirely from the schema, and that is the point. An editor carrying
## its own table of "which numbers does dragging this box move, and which way"
## would be a second declaration of facts already declared — and a second
## declaration of the schema is precisely what the benchmark's two serialisers
## grew out of.
static func drag_step(form: StringName, field: String) -> Vector2:
	var spec: Dictionary = FIELDS.get(StringName("%s/%s" % [form, field]), {})
	if spec.is_empty():
		return Vector2.ZERO
	var bind: StringName = spec["bind"]
	if bind == BIND_NONE:
		return Vector2.ZERO
	var axis: Vector2 = Vector2(0.0, 1.0) if _is_vertical(bind) else Vector2(1.0, 0.0)
	# An ABSOLUTE coordinate follows the pointer whichever edge it is bound to:
	# the binding says where flex slack goes, not which way the number counts. A
	# GAP counts away from its own edge, so right- and bottom-bound gaps run
	# backwards — dragging a widget left makes its distance from the right edge
	# larger, not smaller.
	if (spec.get("absolute", false) or bind == BIND_LEFT or bind == BIND_TOP
			or bind == BIND_CENTRE):
		return axis
	return -axis


## Write one value into a named level, creating whatever the path needs.
##
## The level is the caller's decision and must be shown before the edit, not
## after: authoring `hero/x` at `shape` when it came from `base` is a promotion
## to an override, which is a real and permanent change to how every other shape
## inherits — and upstream it happens silently on the first drag.
static func author(scope: StringName, shape: StringName, act: int,
		level: StringName, path: String, field: String, value: float) -> void:
	var layout: Dictionary = resolve(scope, shape, act)
	var target: Dictionary = _author_at(_bucket(scope, shape, act, level), layout, path)
	if target.is_empty() and not path.is_empty():
		push_warning("layout book: cannot author %s/%s at %s" % [path, field, level])
		return
	target[field] = value
	_dirty = true


## Drop an authored value so the field falls back to whatever it inherits.
##
## A SEAT reverts whole. Formations replace wholesale on merge
## (`battlefield.js:38-47`), so a bucket left holding half a formation would keep
## the other seats at values the level above no longer agrees with — an override
## that survives its own revert.
static func unauthor(scope: StringName, shape: StringName, act: int,
		level: StringName, path: String, field: String) -> void:
	var bucket: Dictionary = _bucket(scope, shape, act, level)
	var parts: PackedStringArray = path.split("/")
	if parts.size() == 3 and parts[0] == "slots":
		var table: Dictionary = bucket.get("slots", {})
		if table.has(parts[1]):
			table.erase(parts[1])
			_dirty = true
	else:
		var target: Dictionary = at(bucket, path)
		if target.has(field):
			target.erase(field)
			_dirty = true
	_prune(bucket)


## The book as it stands, in the canonical form the file on disk is written in.
static func to_text() -> String:
	return DataFile.to_text(raw())


## Overwrite the book on disk, refusing outright if what is in memory would not
## validate. Returns why it refused, or "" when it wrote.
##
## `enemy_view.gd:1635` truncates on open and validates never, which means a bad
## edit and a crashed serialiser both end as an empty authored file. Here the
## check runs first and `DataFile` does not open anything until there is good
## text to put in it.
static func save() -> String:
	var faults: PackedStringArray = validate()
	if not faults.is_empty():
		return "%d complaint(s) — first: %s" % [faults.size(), faults[0]]
	var why: String = DataFile.write(BOOK_PATH, to_text())
	if why.is_empty():
		_dirty = false
	return why


## Where a level's bucket lives, created if this is its first override.
static func _bucket(scope: StringName, shape: StringName, act: int,
		level: StringName) -> Dictionary:
	var book: Dictionary = _sub(_sub(raw(), "scopes"), String(scope))
	if level == FROM_BASE:
		return _sub(book, "base")
	var chunk: Dictionary = _sub(_sub(book, "shapes"), String(shape))
	if level == FROM_SHAPE:
		return chunk
	return _sub(_sub(chunk, "acts"), str(act))


## The chunk inside a bucket that `path` names, created along the way.
##
## A seat is the exception, and the interesting one. `slots/2/0` cannot be
## authored a field at a time: the array replaces on merge, so a bucket holding
## one seat would drop the other two. The first edit to any seat therefore
## materialises the WHOLE resolved formation into this bucket, which from then on
## owns it outright. That is what the merge rule already means; the benchmark's
## editor simply wrote whatever array its own state happened to hold.
static func _author_at(bucket: Dictionary, layout: Dictionary, path: String) -> Dictionary:
	if path.is_empty():
		return bucket
	var parts: PackedStringArray = path.split("/")
	if parts.size() == 3 and parts[0] == "slots":
		var table: Dictionary = _sub(bucket, "slots")
		if not table.get(parts[1]) is Array:
			var seats: Array = layout.get("slots", {}).get(parts[1], [])
			table[parts[1]] = seats.duplicate(true)
		var here: Array = table[parts[1]]
		var i: int = int(parts[2])
		if i < 0 or i >= here.size():
			return {}
		var seat: Dictionary = here[i]
		return seat
	var node: Dictionary = bucket
	for part: String in parts:
		node = _sub(node, part)
	return node


## The dictionary at `key`, created empty if it is not there yet.
static func _sub(node: Dictionary, key: String) -> Dictionary:
	if not node.get(key) is Dictionary:
		node[key] = {}
	var out: Dictionary = node[key]
	return out


## Drop dictionaries an edit emptied, so reverting the last override in a bucket
## leaves the file as it was rather than as `{"hero": {}}`. The bucket itself is
## left standing even when empty — deleting `base` outright would restructure the
## file, which is more than a revert was asked to do.
static func _prune(node: Dictionary) -> void:
	for key: Variant in node.keys():
		var child: Variant = node[key]
		if child is Dictionary:
			var d: Dictionary = child
			_prune(d)
			if d.is_empty():
				node.erase(key)


# ------------------------------------------------------------------ internals

static func _audit(out: PackedStringArray, scope: StringName, shape: StringName,
		act: int, layout: Dictionary) -> void:
	var where: String = "%s.%s act %d" % [scope, shape, act]
	# The root form's fields sit beside the buckets the scope's OTHER rows own,
	# so walking the root meets keys that are not its fields and must not be
	# reported as strays. Which keys those are is already stated — they are the
	# first segment of every other path in this scope — so it is derived here
	# rather than listed. It used to read `field == "hero" or field == "slots"
	# or field == "layers"`, which was the battlefield's three names written out;
	# the first scope to add a bucket of its own (`map`'s `bar`) was reported as
	# a fault by the validator that was supposed to be checking it.
	var buckets: Dictionary = {}
	for path: String in SCOPES[scope]:
		if not path.is_empty():
			buckets[path.split("/", false)[0]] = true
	for path: String in SCOPES[scope]:
		var form: StringName = SCOPES[scope][path]
		for target: Dictionary in _walk(layout, path):
			for field: String in target:
				if path.is_empty() and buckets.has(field):
					continue  # buckets other rows own, not stray keys
				if not _declares(form, field):
					out.append("%s: %s has no field %s" % [where, form, field])
					continue
				var spec: Dictionary = FIELDS[StringName("%s/%s" % [form, field])]
				var v: float = num(target[field])
				if v < num(spec["min"]) or v > num(spec["max"]):
					out.append("%s: %s/%s is %s, outside %s..%s"
						% [where, form, field, v, spec["min"], spec["max"]])
	if scope != &"chrome":
		return
	for widget: String in ONE_EDGE_WIDGETS:
		var box: Dictionary = layout.get(widget, {})
		if box.is_empty():
			continue
		if box.has("left") == box.has("right"):
			out.append("%s: %s must pin to exactly one of left/right" % [where, widget])


## Objects merge key-wise; arrays and scalars replace wholesale, so a shape that
## overrides a formation must supply that slot array complete (`battlefield.js:38-47`).
##
## DEEP copies, and that is load-bearing rather than cautious. A shallow
## `duplicate()` hands back the book's own nested dictionaries for every key the
## upper level does not also author, and `_defaults` then writes schema defaults
## straight into the cached book. Nothing visible changes — a default written
## over an absence is the same number — but `origin()` starts answering "base"
## where the truth is "default", which is the one question this class exists to
## answer honestly.
static func _merge(base: Dictionary, over: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	for k: Variant in over:
		var was: Variant = out.get(k)
		var now: Variant = _copy(over[k])
		if was is Dictionary and now is Dictionary:
			var a: Dictionary = was
			var b: Dictionary = now
			out[k] = _merge(a, b)
		else:
			out[k] = now
	return out


## A value nobody else holds a reference to. Scalars are already that.
static func _copy(v: Variant) -> Variant:
	if v is Dictionary:
		var d: Dictionary = v
		return d.duplicate(true)
	if v is Array:
		var a: Array = v
		return a.duplicate(true)
	return v


## A layout chunk without its act buckets, which merge separately and later.
static func _strip_acts(chunk: Dictionary) -> Dictionary:
	var out: Dictionary = chunk.duplicate()
	out.erase("acts")
	return out


## The act override authored at this shape, or nothing. The benchmark also falls
## back to `BF.base.acts` for `pad-landscape` and then to a top-level `BF.acts`
## (`battlefield.js:65-70`); neither bucket exists in the data at 6e06911, so
## both are dead branches and are not carried.
static func _act_over(chunk: Dictionary, act: int) -> Dictionary:
	return chunk.get("acts", {}).get(str(act), {})


## All three plates always exist, defaulted, whatever the book authored
## (`battlefield.js:76-79`) — a missing `mid` must be a still, invisible plate
## rather than a null the draw code has to test for.
static func _layers_of(layout: Dictionary) -> Dictionary:
	var authored: Dictionary = layout.get("layers", {})
	var out: Dictionary = {}
	for name: String in LAYERS:
		var layer: Dictionary = LAYER_DEFAULTS[StringName(name)].duplicate()
		var over: Dictionary = authored.get(name, {})
		layer.merge(over, true)
		out[name] = layer
	return out


## Fill in every field whose schema declares a default and whose value is absent
## everywhere. A field with no declared default stays absent on purpose.
static func _defaults(scope: StringName, layout: Dictionary) -> Dictionary:
	for path: String in SCOPES.get(scope, {}):
		var form: StringName = SCOPES[scope][path]
		for target: Dictionary in _walk(layout, path):
			for field: String in fields(form):
				var spec: Dictionary = FIELDS.get(StringName("%s/%s" % [form, field]), {})
				if spec.has("default") and not target.has(field):
					target[field] = spec["default"]
	return layout


## Every dictionary a slash-separated path selects, with `*` matching any key or
## index. The empty path selects the layout itself.
static func _walk(node: Variant, path: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if path.is_empty():
		if node is Dictionary:
			found.append(node)
		return found
	var parts: PackedStringArray = path.split("/")
	var here: Array = [node]
	for part: String in parts:
		var next: Array = []
		for item: Variant in here:
			if item is Array and part == "*":
				var list: Array = item
				next.append_array(list)
			elif item is Dictionary:
				var d: Dictionary = item
				if part == "*":
					for k: Variant in d:
						next.append(d[k])
				elif d.has(part):
					next.append(d[part])
		here = next
	for item: Variant in here:
		if item is Dictionary:
			found.append(item)
	return found


## Does a slash-separated path resolve to a value in this chunk? Used only by
## `origin`, where the question is presence rather than value.
static func _has_at(chunk: Dictionary, path: String) -> bool:
	var node: Variant = chunk
	for part: String in path.split("/"):
		if not node is Dictionary:
			return false
		var d: Dictionary = node
		if not d.has(part):
			return false
		node = d[part]
	return true


## The fields of a form, in author order. Public because the editor builds its
## rows from it, in this order.
##
## Do NOT inline this as `FORMS[form]`. On 4.7.1, a `PackedStringArray` fetched
## from a typed Dictionary by a runtime-built `StringName` key answers `has(x)`
## with false while `find(x)` answers 0 — the same array, the same string. A
## literal key is fine and `.get()` is fine, which is exactly what makes the bug
## survive a casual reading. Everything here goes through `.get()` and asks
## `find` rather than `has`, and `tests/test_layout_book.gd` pins the behaviour.
static func fields(form: StringName) -> PackedStringArray:
	return FORMS.get(form, PackedStringArray())


## Is `field` part of `form`? See `fields` for why this is not `has`.
static func _declares(form: StringName, field: String) -> bool:
	return fields(form).find(field) >= 0


## A number out of the book. `JSON.parse_string` hands back Variants and the
## warnings-as-errors gate refuses `float(Variant)`, so every authored value is
## read through here — which also makes "absent" and "not a number" the same
## answer, deliberately: a corrupt key falls back rather than crashing a fight.
static func num(v: Variant, fallback: float = 0.0) -> float:
	if v is float:
		var f: float = v
		return f
	if v is int:
		var i: int = v
		return float(i)
	return fallback


static func _is_vertical(bind: StringName) -> bool:
	return bind == BIND_TOP or bind == BIND_BOTTOM


## How much of the slack an absolute coordinate on this edge takes. A left- or
## top-bound coordinate keeps its number; a right- or bottom-bound one takes all
## of it; a centre-bound one takes half.
static func _bind_share(bind: StringName) -> float:
	match bind:
		BIND_RIGHT, BIND_BOTTOM:
			return 1.0
		BIND_CENTRE:
			return 0.5
	return 0.0
