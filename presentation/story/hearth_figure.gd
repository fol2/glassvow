class_name HearthFigure
extends Control
## #283 cutout seated on the empty hearth step. The plate is an empty hall
## (art-ledger); 爐前仍坐着一個兜帽身影 is this overlay's job in every beat
## that needs it (opening hearth, L0 departure linger).

const ART: String = "res://assets/art/meta/keeper.png"
const NAME: String = "HearthFigure"
## Seat on opening-hearth-c, measured off the plate (#334 review). The hem
## lands on the hearth platform's near edge — plate y 861 of 1024 — instead of
## sinking into the 8% dialogue band, and the box sits far enough right that
## the copy panel (520 wide, centred) crosses under 13% of the cutout instead
## of 40%. Both bounds are pinned in `test_bespoke_staging`.
const SEAT_LEFT: float = 0.674
const SEAT_RIGHT: float = 0.911
const SEAT_TOP: float = 0.420
const SEAT_BOTTOM: float = 0.841
## The cutout ships at studio chroma (`docs/art-ledger.md:266-297`) against a
## hall that is warm-black. Multiplied down and warmed so the glass reads as
## lit by this fire, not pasted over it. Warm means r > g > b.
const HEARTH_GRADE: Color = Color(0.66, 0.56, 0.48)
## `modulate` is a multiply: it moves value, never chroma, so on its own the
## jewel panes stay studio-saturated over a warm-black hall. This ember haze
## is composited over the cutout and clipped to its own alpha, which pulls the
## panes toward one hearth-lit hue. Kept under a third so the glass survives —
## the style bible's whole point is that the Keeper is stained glass.
const HEARTH_HAZE: Color = Color(0.40, 0.25, 0.13, 0.28)

var _sprite: TextureRect


static func present() -> bool:
	return ResourceLoader.exists(ART)


static func attach(plate: TextureRect) -> HearthFigure:
	var existing: Node = plate.find_child(NAME, false, false)
	if existing is HearthFigure:
		var found: HearthFigure = existing
		found._apply_seat()
		return found
	var figure: HearthFigure = HearthFigure.new()
	figure._apply_seat()
	plate.add_child(figure)
	return figure


func _init() -> void:
	name = NAME
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate = HEARTH_GRADE
	_sprite = TextureRect.new()
	_sprite.name = "Sprite"
	_sprite.texture = load(ART) as Texture2D if present() else null
	_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sprite.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	add_child(_sprite)
	var haze: ColorRect = ColorRect.new()
	haze.name = "Haze"
	haze.color = HEARTH_HAZE
	haze.set_anchors_preset(Control.PRESET_FULL_RECT)
	haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sprite.add_child(haze)
	resized.connect(_layout)


func _ready() -> void:
	_layout()


func _apply_seat() -> void:
	anchor_left = SEAT_LEFT
	anchor_right = SEAT_RIGHT
	anchor_top = SEAT_TOP
	anchor_bottom = SEAT_BOTTOM
	offset_left = 0.0
	offset_right = 0.0
	offset_top = 0.0
	offset_bottom = 0.0
	_layout()


func _layout() -> void:
	if _sprite == null or _sprite.texture == null:
		return
	var box: Vector2 = size
	if box.x < 1.0 or box.y < 1.0:
		return
	var tex: Vector2 = _sprite.texture.get_size()
	if tex.y < 1.0:
		return
	var h: float = box.y
	var w: float = h * tex.x / tex.y
	if w > box.x:
		w = box.x
		h = w * tex.y / tex.x
	_sprite.size = Vector2(w, h)
	_sprite.position = Vector2((box.x - w) * 0.5, box.y - h)
