extends Button
## Screen-readable engraving above a physical waystone; the hit target stays 48 px.
const KINDS: Array[String] = ["monster","elite","rest","shop","treasure","event","unlit","monument","boss"]
var kind: String = "event"
var available: bool = false
var current: bool = false
var visited: bool = false
var chosen: bool = false
var overview: bool = false
var bounty: int = 0
var glyph: AtlasTexture

func _ready() -> void:
	flat = true
	for state: String in ["normal","hover","pressed","disabled","focus"]:
		add_theme_stylebox_override(state,StyleBoxEmpty.new())
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)

func configure(node: MapNode, reachable: bool, here: bool, cleared: bool, selected: bool) -> void:
	kind = "unlit" if node.unlit else node.type
	available = reachable
	current = here
	visited = cleared
	chosen = selected
	bounty = node.bounty if node.unlit else 0
	glyph = AtlasTexture.new()
	glyph.atlas = preload("res://assets/art/ui/map-glyphs.svg")
	glyph.region = Rect2(maxi(0,KINDS.find(kind))*96,0,96,96)
	glyph.filter_clip = true
	tooltip_text = ("Unlit encounter" if node.unlit else node.type.capitalize()) + " · stage %d" % (node.row+1)
	if bounty>0:
		tooltip_text += " · bounty %d" % bounty
	focus_mode = Control.FOCUS_ALL
	queue_redraw()

func _draw() -> void:
	var centre: Vector2 = size*.5
	var tint: Color = Color("d6c7b0") if available or current else Color("b3afb8")
	if visited and not current:
		tint = Color("91878a")
	if overview:
		if glyph!=null:
			var bounds: Rect2 = Rect2(centre-Vector2.ONE*18,Vector2.ONE*36)
			draw_texture_rect(glyph,Rect2(bounds.position+Vector2(0,1),bounds.size),false,Color("211c25"))
			draw_texture_rect(glyph,bounds,false,tint)
		if visited and not current:
			draw_polyline(PackedVector2Array([centre+Vector2(-3,11),centre+Vector2(-1,13),centre+Vector2(4,8)]),tint,1.4,true)
		if chosen or current:
			draw_arc(centre,14,0,TAU,24,Color("efc984"),1.5,true)
		elif available:
			draw_line(centre+Vector2(-6,13),centre+Vector2(6,13),Color("deb677"),1.5,true)
		return
	# The engraving is quiet: no opaque circular menu button covering the land.
	var bounds: Rect2 = Rect2(centre-Vector2(27,29),Vector2(54,54))
	if glyph!=null:
		draw_texture_rect(glyph,Rect2(bounds.position+Vector2(0,1),bounds.size),false,Color(0.04,0.03,0.04,.9))
		draw_texture_rect(glyph,bounds,false,tint)
	if visited and not current:
		draw_polyline(PackedVector2Array([centre+Vector2(-4,16),centre+Vector2(-1,19),centre+Vector2(5,12)]),tint,1.6,true)
	if available or current:
		draw_line(centre+Vector2(-8,20),centre+Vector2(8,20),Color("deb677"),2,true)
	if bounty>0:
		var font: Font = get_theme_font("font")
		var label: String = str(bounty)
		var width: float = font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
		var pill: Rect2 = Rect2(centre+Vector2(14,-16),Vector2(width+10,18))
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color("242028")
		style.set_corner_radius_all(4)
		draw_style_box(style,pill)
		draw_string(font,pill.position+Vector2(5,13),label,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("e5c38d"))
	if chosen or has_focus() or is_hovered():
		var colour: Color = Color("f0cd8b") if chosen else Color("eee3d0")
		for sx: float in [-1,1]:
			for sy: float in [-1,1]:
				var corner: Vector2 = centre+Vector2(23*sx,24*sy)
				draw_line(corner,corner-Vector2(7*sx,0),colour,1.5,true)
				draw_line(corner,corner-Vector2(0,7*sy),colour,1.5,true)
