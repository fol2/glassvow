class_name FacetPips
extends Control
## The facet gauge: one leaded pane per facet, painted rather than drawn. Pure
## _draw; the view pushes counts in through set_pips.
##
## The asset names are inverted against game state, and that is deliberate — a
## filename describes the PANE, not the slot. A facet that has NOT been chipped
## still holds its light, so it draws `facet-chipped.png` (bright glass, one
## corner gone); a facet that HAS been chipped has gone dark, so it draws
## `facet-empty.png` (the same pane, black). Same mapping the benchmark makes in
## facetPips() — roguecardv2 src/ui/combat.js:1018.

const PIP: float = 16.0
const GAP: float = 5.0
const ROW_H: float = 18.0
## Past one row of panes the gauge stops being countable, so boss glass reads as
## a number instead. The benchmark's own cutoff.
const MAX_PIPS: int = 8

const INTACT: Texture2D = preload("res://assets/art/ui/facet-chipped.png")
const CHIPPED: Texture2D = preload("res://assets/art/ui/facet-empty.png")

## The dark pane is near-black and would vanish on the night ground; the lit one
## is already white and blows out if pushed. Lifted apart rather than together.
const INTACT_LIFT: Color = Color(1.0, 1.0, 1.0, 1.0)
const CHIPPED_LIFT: Color = Color(1.35, 1.35, 1.45, 1.0)
## A pane that WOULD go, drawn as taken but held back from the lit one so the
## eye can still tell a prediction from a fact.
const WILL_LIFT: Color = Color(1.35, 1.35, 1.45, 0.55)
## `.facet-row.willshatter .pip { border-color: #ffd8a0 }` — the gauge about to
## fill rings itself in warm gold.
const SHATTER_RING: Color = Color(1.0, 0.84705883, 0.627451, 1.0)

var _filled: int = 0
var _total: int = 0
## `facetPips(en, ghost)` — how many panes the card under the cursor WOULD chip,
## and whether that fills the gauge. The consequence, before the blow.
var _ghost: int = 0
var _will_shatter: bool = false


func set_pips(filled: int, total: int) -> void:
	_filled = maxi(filled, 0)
	_total = maxi(total, 0)
	var count: int = mini(_total, MAX_PIPS)
	var w: float = float(count) * PIP + float(maxi(count - 1, 0)) * GAP if _total <= MAX_PIPS \
		else PIP + GAP + 46.0
	custom_minimum_size = Vector2(w, ROW_H)
	queue_redraw()


## The panes an armed card would take, and whether taking them shatters the
## glass. `.willchip` marks the panes; `.facet-row.willshatter` (styles.css:1061)
## rings every pane in warm gold, because the gauge filling is the whole point
## of aiming a chip card at this creature rather than the one beside it.
func set_ghost(ghost: int, will_shatter: bool) -> void:
	var n: int = maxi(ghost, 0)
	if n == _ghost and will_shatter == _will_shatter:
		return
	_ghost = n
	_will_shatter = will_shatter
	queue_redraw()


## `.facet-row.pop` — `chipPop`, 0.4s ease-out, 35% larger at 40% through. The
## gauge answers the blow that chipped it; without it a facet goes dark with no
## more ceremony than a label changing.
func pop() -> void:
	if not is_inside_tree() or size == Vector2.ZERO:
		return
	pivot_offset = size * 0.5
	var tw: Tween = create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(self, "scale", Vector2.ONE * 1.35, 0.16)
	tw.tween_property(self, "scale", Vector2.ONE, 0.24)


func _draw() -> void:
	if _total <= 0:
		return
	var cy: float = size.y * 0.5
	if _total > MAX_PIPS:
		# One pane, then the count — the gauge a boss needs.
		# `${en.chips}${ghost ? `<i>+${ghost}</i>` : ''}/${en.facetMax}`
		var text: String = "%d+%d/%d" % [_filled, _ghost, _total] if _ghost > 0 \
			else "%d/%d" % [_filled, _total]
		var font: Font = get_theme_default_font()
		var fs: int = 12
		var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x
		var span: float = PIP + GAP + tw
		var x: float = (size.x - span) * 0.5
		draw_texture_rect(CHIPPED, Rect2(Vector2(x, cy - PIP * 0.5), Vector2(PIP, PIP)),
			false, CHIPPED_LIFT)
		draw_string(font, Vector2(x + PIP + GAP, cy + float(fs) * 0.36), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, GlassStyle.TEXT)
		return
	var span_w: float = float(_total) * PIP + float(_total - 1) * GAP
	var start_x: float = (size.x - span_w) * 0.5
	for i: int in range(_total):
		var chipped: bool = i < _filled
		# `will = !filled && i < en.chips + ghost` — a pane the armed card would
		# take draws as though it were already taken, which is what makes the
		# gauge answer the card rather than the last blow.
		var will: bool = not chipped and i < _filled + _ghost
		var at: Rect2 = Rect2(
			Vector2(start_x + float(i) * (PIP + GAP), cy - PIP * 0.5), Vector2(PIP, PIP))
		draw_texture_rect(CHIPPED if (chipped or will) else INTACT, at, false,
			(WILL_LIFT if will else CHIPPED_LIFT) if (chipped or will) else INTACT_LIFT)
		if _will_shatter:
			draw_rect(at.grow(1.0), SHATTER_RING, false, 1.0)
