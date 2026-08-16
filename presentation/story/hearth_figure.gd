class_name HearthFigure
extends Control
## #283 cutout seated on the empty hearth step. The plate is an empty hall
## (art-ledger); 爐前仍坐着一個兜帽身影 is this overlay's job in every beat
## that needs it (opening hearth, L0 departure linger).

const ART: String = "res://assets/art/meta/keeper.png"
const NAME: String = "HearthFigure"
## Seat on opening-hearth-c: the long low step before the right-hand fire.
const SEAT_LEFT: float = 0.60
const SEAT_RIGHT: float = 0.90
const SEAT_TOP: float = 0.36
const SEAT_BOTTOM: float = 0.98

var _sprite: TextureRect


static func present() -> bool:
	return ResourceLoader.exists(ART)


static func attach(plate: TextureRect, flipped: bool = false) -> HearthFigure:
	var existing: Node = plate.find_child(NAME, false, false)
	if existing is HearthFigure:
		var found: HearthFigure = existing
		found._apply_seat(flipped)
		return found
	var figure: HearthFigure = HearthFigure.new()
	figure._apply_seat(flipped)
	plate.add_child(figure)
	return figure


func _init() -> void:
	name = NAME
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sprite = TextureRect.new()
	_sprite.name = "Sprite"
	_sprite.texture = load(ART) as Texture2D if present() else null
	_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sprite)
	resized.connect(_layout)


func _ready() -> void:
	_layout()


func _apply_seat(flipped: bool) -> void:
	anchor_left = (1.0 - SEAT_RIGHT) if flipped else SEAT_LEFT
	anchor_right = (1.0 - SEAT_LEFT) if flipped else SEAT_RIGHT
	anchor_top = SEAT_TOP
	anchor_bottom = SEAT_BOTTOM
	offset_left = 0.0
	offset_right = 0.0
	offset_top = 0.0
	offset_bottom = 0.0
	if _sprite != null:
		_sprite.flip_h = flipped
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
