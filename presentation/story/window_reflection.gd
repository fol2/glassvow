class_name WindowReflection
extends Control
## 窗中反影遲半拍 (`docs/story/00-truth.md:177-178`) — the reflection lags half
## a beat **in the rose window**, not in the whole hall. James signed route A
## on #334: a ghost in the glass, never a second body in the doorway and never
## a lit lobe at zero shards (`docs/art-ledger.md:228-233`: 「James ruled one」).
##
## Geometry is measured off the plate and converted once. The frame is engine
## locked to 1180x820 (`project.godot:45` `window/stretch/aspect="keep"`), and
## the 1536x1024 plate covers it at 820/1024, so a plate fraction `u` lands at
## screen `u * 1.042373 - 0.021186` across and at `u` down.

const NAME: String = "WindowReflection"
## Rose window glass — plate px x 137..288, y 105..262. 「高處左牆一面圓形
## 六瓣玫瑰窗,暗玻璃」(`docs/design/2026-08-16-scene-plates/README.md:97-98`).
const ROSE: Rect2 = Rect2(0.0718, 0.1025, 0.1024, 0.1533)
## Ghost height as a fraction of the opening it sits in.
const GHOST_FILL: float = 0.88
## Dark glass at night returns a cold copy of a warm room. Held above the
## plate's starfield, which is near-black — a darker ghost is an invisible one.
const GHOST_GRADE: Color = Color(0.72, 0.82, 1.0)
## Where the pane stops being solid and starts feathering into the stone.
const PANE_CORE: float = 0.66

var _pane: TextureRect
var _ghost: TextureRect = null


func _init() -> void:
	name = NAME
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_seat(ROSE)
	_pane = TextureRect.new()
	_pane.name = "Pane"
	_pane.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pane.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pane.stretch_mode = TextureRect.STRETCH_SCALE
	_pane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pane)
	# The disc is the window, not a sprite: it masks the ghost to the opening
	# with a soft rim, so nothing of the reflection spills onto the stone. Its
	# core is flat — `GlassStyle.disc` halves by 52% of the radius, which eats
	# a figure this small before it can be read.
	_pane.texture = GlassStyle.grad_tex(
		PackedColorArray([Color.WHITE, Color.WHITE, Color(1.0, 1.0, 1.0, 0.0)]),
		PackedFloat32Array([0.0, PANE_CORE, 1.0]), true,
		Vector2(0.5, 0.5), Vector2(1.0, 0.5))
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
