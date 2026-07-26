class_name RulesText
extends Control
## The card's rules paragraph, drawn rather than laid out by a Label.
##
## The benchmark styles three runs inside one sentence (styles.css .card-text):
##   plain     #C6CCDF, Alegreya 400
##   .val      #E8DFC8, Alegreya 700 — the numbers, wrapped in @…@ or #…#
##   .kw       the card's type tint, with `border-bottom: 1px dotted tint@60%`
##
## RichTextLabel covers the first two and not the third: its [u] draws a solid
## rule in the text's own colour, with no dotted variant and no way to drop the
## alpha independently. Patching one in from outside needs per-run rectangles,
## which RichTextLabel does not expose — and after wrapping they cannot be
## recomputed reliably. So this measures and draws the paragraph itself, which
## costs one greedy wrap loop and buys exact control over all three runs.

const KIND_PLAIN: int = 0
const KIND_VALUE: int = 1
const KIND_KEYWORD: int = 2

## Matched as whole words, not via the @…@ / #…# markers — those carry only the
## numbers. Copied from the benchmark's src/ui/tooltip.js.
##
## The order is load-bearing: these become one alternation, and a regex takes
## the first alternative that fits at a given position. Plural before singular,
## or "Embers" matches as "Ember" and leaves a stray "s" unstyled.
const KEYWORDS: Array = [
	"Cracked", "Dimmed", "Brittle", "Smolder", "Fervor", "Poise", "Kindle",
	"Ward", "Energy", "Embers", "Ember", "Chip", "Facets", "Facet", "Shatters",
	"Shatter", "Staggered", "Unplayable", "Shard", "Hex", "Cinder",
]

## The glossary behind the dotted rule (`KEYWORDS`, tooltip.js:14). Six of the
## twenty-one are STATUSES and read their description out of the run's own
## catalogue rather than out of a constant, so a status whose text is retuned
## does not have to be retuned twice. That table maps them; the rest are fixed
## UI copy (`ui.keywords`, i18n/en/ui.js:332) and live here.
##
## The aliases are the benchmark's: `Facets`, `Shatter` and `Shatters` all
## explain the facet gauge, and `Embers` explains an ember.
const KEYWORD_STATUS: Dictionary = {
	"Cracked": "vulnerable", "Dimmed": "weak", "Brittle": "frail",
	"Smolder": "poison", "Fervor": "str", "Poise": "dex",
}
const FACET_DESC: String = "Every creature is glass with a Facet gauge. Fill it and the glass Shatters — the creature loses its next action, is Cracked, and spills Embers into your lantern."
const KEYWORD_TEXT: Dictionary = {
	"Kindle": "Burned away for the rest of this combat — and the lantern gains 1 Ember.",
	"Ward": "Held light that prevents damage. Expires at the start of your turn.",
	"Energy": "Spent to play cards. Refreshes each turn.",
	"Ember": "Fuel for your Lantern Art. Spilled by shatters, deaths and kindling; held in the lantern.",
	"Embers": "Fuel for your Lantern Art. Spilled by shatters, deaths and kindling; held in the lantern.",
	"Chip": "Strike at the glass itself: adds toward a Shatter, no blood required.",
	"Facet": FACET_DESC, "Facets": FACET_DESC,
	"Shatter": FACET_DESC, "Shatters": FACET_DESC,
	"Staggered": "Shattered glass loses its next action while it reseams.",
	"Unplayable": "This card cannot be played.",
	"Shard": "Unplayable junk glass. It can still be kindled.",
	"Hex": "Curse: lose 1 HP at end of turn while in hand. Cannot be kindled.",
	"Cinder": "Take 2 damage at end of turn while in hand.",
}

## CSS `dotted` at 1px is a 1px dot every 2px.
const DOT_W: float = 1.0
const DOT_STEP: float = 2.0
const UNDERLINE_DROP: float = 2.0

## Compiled once per run, not once per keyword per run. Lazy rather than a
## static initialiser so it cannot race class load order.
static var _kw_re: RegEx = null

var plain_color: Color = Color(0.776, 0.800, 0.875)
var value_color: Color = Color(0.910, 0.875, 0.784)
var keyword_color: Color = Color(1, 1, 1)
var font_size: int = 13
var line_height: float = 17.0

var _font_plain: Font
var _font_bold: Font
var _tokens: Array = []          # [{text:String, kind:int}]
var _lines: Array = []           # [[{text, kind, w, space, space_w}]] after wrapping
var _line_widths: PackedFloat32Array = PackedFloat32Array()


func _init(text: String, tint: Color, plain: Font, bold: Font, size: int,
		leading: float) -> void:
	keyword_color = tint
	_font_plain = plain
	_font_bold = bold
	font_size = size
	line_height = leading
	_tokens = tokenize(text)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


static func _keyword_re() -> RegEx:
	if _kw_re == null:
		var alts: PackedStringArray = PackedStringArray()
		for w: String in KEYWORDS:
			alts.append(w)
		_kw_re = RegEx.create_from_string("\\b(?:%s)\\b" % "|".join(alts))
	return _kw_re


## Split rules text into styled runs. Numbers first — a marker never contains a
## keyword, so the two passes cannot overlap.
static func tokenize(text: String) -> Array:
	var out: Array = []
	var buf: String = ""
	var i: int = 0
	while i < text.length():
		var ch: String = text[i]
		if ch == "@" or ch == "#":
			var close: int = text.find(ch, i + 1)
			if close > i:
				if buf != "":
					out.append({"text": buf, "kind": KIND_PLAIN})
					buf = ""
				out.append({
					"text": text.substr(i + 1, close - i - 1), "kind": KIND_VALUE})
				i = close + 1
				continue
		buf += ch
		i += 1
	if buf != "":
		out.append({"text": buf, "kind": KIND_PLAIN})
	# Then split the plain runs on keywords.
	var split: Array = []
	for tok: Dictionary in out:
		var tok_kind: int = tok["kind"]
		if tok_kind != KIND_PLAIN:
			split.append(tok)
			continue
		split.append_array(_split_keywords(str(tok["text"])))
	return split


static func _split_keywords(text: String) -> Array:
	var out: Array = []
	var at: int = 0
	for m: RegExMatch in _keyword_re().search_all(text):
		if m.get_start() > at:
			out.append({
				"text": text.substr(at, m.get_start() - at), "kind": KIND_PLAIN})
		out.append({"text": m.get_string(), "kind": KIND_KEYWORD})
		at = m.get_end()
	if at < text.length():
		out.append({"text": text.substr(at), "kind": KIND_PLAIN})
	return out


func _font_for(kind: int) -> Font:
	return _font_bold if kind == KIND_VALUE else _font_plain


func _color_for(kind: int) -> Color:
	match kind:
		KIND_VALUE:
			return value_color
		KIND_KEYWORD:
			return keyword_color
		_:
			return plain_color


## Greedy wrap on word boundaries, keeping each word's style with it. Runs are
## split into words up front so a run can break across lines like plain text.
func _wrap(width: float) -> void:
	_lines = []
	_line_widths = PackedFloat32Array()
	# Walk the whole paragraph as one character stream, not each run separately.
	# A run boundary often falls mid-phrase ("Deal " | "4" | " damage."), and
	# splitting per run drops the space that *begins* the next one — "Deal
	# 4damage". A word takes the style of its first character.
	var words: Array = []
	var cur: String = ""
	var cur_kind: int = KIND_PLAIN
	for tok: Dictionary in _tokens:
		var kind: int = tok["kind"]
		var body: String = str(tok["text"])
		for ci: int in range(body.length()):
			var c: String = body[ci]
			if c == " ":
				if cur != "":
					words.append({"text": cur, "kind": cur_kind, "space": true})
					cur = ""
				continue
			# A word also ends where its STYLE ends, not only where a space is.
			# "Ward." is a keyword run followed by a plain one with no space
			# between them; taking the kind of the first character alone made it
			# one keyword word, which ran the dotted rule under the full stop and
			# made the glossary look up "Ward." — a key no glossary has. The
			# break carries `space: false`, so nothing is inserted between them.
			if cur != "" and kind != cur_kind:
				words.append({"text": cur, "kind": cur_kind, "space": false})
				cur = ""
			if cur == "":
				cur_kind = kind
			cur += c
	if cur != "":
		words.append({"text": cur, "kind": cur_kind, "space": false})

	# A space is the same width whatever word precedes it — it depends only on
	# the face and the size. Measure the two faces once instead of once per word.
	var space_plain: float = _font_plain.get_string_size(" ",
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var space_bold: float = _font_bold.get_string_size(" ",
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var line: Array = []
	var line_w: float = 0.0
	for word: Dictionary in words:
		var wkind: int = word["kind"]
		var f: Font = _font_for(wkind)
		var ww: float = f.get_string_size(str(word["text"]),
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
		var space_w: float = space_bold if wkind == KIND_VALUE else space_plain
		var has_space: bool = word["space"]
		# A line may only break where a space was. Splitting a word at its style
		# boundary created neighbours with no space between them ("Ward" + "."),
		# and a greedy wrap would happily strand the full stop on the next line.
		var can_break: bool = false
		if not line.is_empty():
			var prev: Dictionary = line[-1]
			can_break = prev["space"]
		if can_break and line_w + ww > width:
			_push_line(line, line_w)
			line = []
			line_w = 0.0
		word["w"] = ww
		word["space_w"] = space_w
		line.append(word)
		line_w += ww + (space_w if has_space else 0.0)
	if not line.is_empty():
		_push_line(line, line_w)


## Close a line, dropping the last word's trailing space from the measured
## width. CSS hangs a space at a break rather than counting it into the line
## box, so counting it here would shove every wrapped line half a space left.
func _push_line(line: Array, w: float) -> void:
	var last: Dictionary = line[-1]
	var trailing: bool = last["space"]
	var space_w: float = last["space_w"]
	_lines.append(line)
	_line_widths.append(w - (space_w if trailing else 0.0))


func paragraph_height() -> float:
	return float(_lines.size()) * line_height


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_wrap(size.x)
		queue_redraw()


func _draw() -> void:
	if _lines.is_empty():
		_wrap(size.x)
	var ascent: float = _font_plain.get_ascent(font_size)
	# Centre the block vertically; the benchmark's .card-text is a flex centre.
	var y: float = (size.y - paragraph_height()) * 0.5 + ascent
	for li: int in range(_lines.size()):
		var line: Array = _lines[li]
		var x: float = (size.x - _line_widths[li]) * 0.5
		for word: Dictionary in line:
			var kind: int = word["kind"]
			var w: float = word["w"]
			draw_string(_font_for(kind), Vector2(x, y), str(word["text"]),
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, _color_for(kind))
			if kind == KIND_KEYWORD:
				_draw_dotted(x, y + UNDERLINE_DROP, w)
			var sp: float = word["space_w"]
			var draw_space: bool = word["space"]
			x += w + (sp if draw_space else 0.0)
		y += line_height


## Which keyword the point lands on, or "" for none.
##
## The benchmark can ask this of the DOM because each `.kw` is a real `<span>`
## with its own box. Here the paragraph draws itself, so the hit box has to be
## re-derived — by walking the SAME geometry `_draw` lays out, so the target is
## exactly the run that carries the dotted rule and never drifts from it.
##
## The box is the glyph run plus its leading, not just the ascent: aiming at a
## 13px word by its cap height alone is a worse target than the underline
## suggests.
func keyword_at(local: Vector2) -> String:
	if _lines.is_empty():
		_wrap(size.x)
	var ascent: float = _font_plain.get_ascent(font_size)
	var y: float = (size.y - paragraph_height()) * 0.5 + ascent
	for li: int in range(_lines.size()):
		var line: Array = _lines[li]
		var x: float = (size.x - _line_widths[li]) * 0.5
		var top: float = y - ascent
		for word: Dictionary in line:
			var kind: int = word["kind"]
			var w: float = word["w"]
			if kind == KIND_KEYWORD \
					and Rect2(x, top, w, line_height).has_point(local):
				return str(word["text"])
			var sp: float = word["space_w"]
			var draw_space: bool = word["space"]
			x += w + (sp if draw_space else 0.0)
		y += line_height
	return ""


## The benchmark's `border-bottom: 1px dotted tint@60%`.
func _draw_dotted(x: float, y: float, width: float) -> void:
	var col: Color = Color(keyword_color, 0.6)
	var dx: float = 0.0
	while dx < width:
		draw_rect(Rect2(x + dx, y, minf(DOT_W, width - dx), 1.0), col)
		dx += DOT_STEP
