class_name WindowReflection
extends Control
## 窗中反影遲半拍 (`docs/story/00-truth.md:173-174`) — the reflection lags half
## a beat **in the window**, not in the whole hall. This confines it to one
## opening of `opening-hearth.png` so the seated cutout stays the only body on
## screen (`docs/art-ledger.md:107-111`: 「James ruled one」).
##
## ROUTE FORK, awaiting James (#334). Three readings of the same spec line,
## rendered side by side in `docs/design/2026-08-16-bespoke-beats/`:
##   a — the figure's reflection inside the rose window's glass;
##   b — the same ghost in the arched doorway instead;
##   c — no figure at all; only the hearth light lagging in the rose.
## Once one is picked the other two constants go.
##
## Geometry is measured off the plate and converted once. The frame is engine
## locked to 1180x820 (`project.godot:45` `window/stretch/aspect="keep"`), and
## the 1536x1024 plate covers it at 820/1024, so a plate fraction `u` lands at
## screen `u * 1.042373 - 0.021186` across and at `u` down.

const NAME: String = "WindowReflection"
const ROUTE_ROSE_FIGURE: StringName = &"a"
const ROUTE_DOOR_FIGURE: StringName = &"b"
const ROUTE_ROSE_GLOW: StringName = &"c"
const ROUTES: Array[StringName] = [
	ROUTE_ROSE_FIGURE, ROUTE_DOOR_FIGURE, ROUTE_ROSE_GLOW,
]
## Rose window glass — plate px x 137..288, y 105..262. 「高處左牆一面圓形
## 六瓣玫瑰窗,暗玻璃」(`docs/design/2026-08-16-scene-plates/README.md:97-98`).
const ROSE: Rect2 = Rect2(0.0718, 0.1025, 0.1024, 0.1533)
## The arched doorway — plate px x 107..265, y 368..730. Route b only.
const DOOR: Rect2 = Rect2(0.0514, 0.3594, 0.1072, 0.3535)
## Ghost height as a fraction of the opening it sits in.
const GHOST_FILL: float = 0.72
## Dark glass at night returns a cold, dim copy of a warm room.
const GHOST_GRADE: Color = Color(0.46, 0.56, 0.72)
## Route c's hearth light, warmed off `RunStyle.GOLD`.
const GLOW_GRADE: Color = Color(0.62, 0.45, 0.22)

var route: StringName = ROUTE_ROSE_FIGURE
var _pane: TextureRect
var _ghost: TextureRect = null


func _init(route_id: StringName = ROUTE_ROSE_FIGURE) -> void:
	name = NAME
	route = route_id if ROUTES.has(route_id) else ROUTE_ROSE_FIGURE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_seat(DOOR if route == ROUTE_DOOR_FIGURE else ROSE)
	_pane = TextureRect.new()
	_pane.name = "Pane"
	_pane.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pane.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pane.stretch_mode = TextureRect.STRETCH_SCALE
	_pane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pane)
	if route == ROUTE_ROSE_GLOW:
		# The lag is carried by the firelight on the glass. No second body.
		_pane.texture = GlassStyle.disc(GLOW_GRADE, 1.0, 128)
		return
	# The disc is the window, not a sprite: it masks the ghost to the opening
	# with a soft rim, so nothing of the reflection spills onto the stone.
	_pane.texture = GlassStyle.disc(Color.WHITE, 1.0, 128)
	_pane.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	_ghost = TextureRect.new()
	_ghost.name = "Ghost"
	_ghost.texture = load(HearthFigure.ART) as Texture2D if HearthFigure.present() else null
	_ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_ghost.flip_h = true
	_ghost.modulate = GHOST_GRADE
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pane.add_child(_ghost)
	resized.connect(_layout)


func _ready() -> void:
	_layout()


func _seat(region: Rect2) -> void:
	anchor_left = region.position.x
	anchor_top = region.position.y
	anchor_right = region.end.x
	anchor_bottom = region.end.y
	offset_left = 0.0
	offset_right = 0.0
	offset_top = 0.0
	offset_bottom = 0.0


func _layout() -> void:
	if _ghost == null or _ghost.texture == null:
		return
	var box: Vector2 = size
	if box.x < 1.0 or box.y < 1.0:
		return
	var tex: Vector2 = _ghost.texture.get_size()
	if tex.y < 1.0:
		return
	var h: float = box.y * GHOST_FILL
	var w: float = h * tex.x / tex.y
	if w > box.x:
		w = box.x
		h = w * tex.y / tex.x
	_ghost.size = Vector2(w, h)
	_ghost.position = (box - _ghost.size) * 0.5
