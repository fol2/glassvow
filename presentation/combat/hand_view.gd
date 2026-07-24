class_name HandView
extends HBoxContainer
## The hand strip. M5a: a centered row of CardViews with click-to-play;
## the arc layout + drag-to-play input pass replaces the interaction in M5b.

signal card_pressed(uid: int)

var _views: Dictionary = {}  # uid -> CardView


func _init() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 10)


func has_card(uid: int) -> bool:
	return _views.has(uid)


func card_view(uid: int) -> CardView:
	var v: CardView = _views.get(uid)
	return v


func add_card(inst: CardInst, data: Dictionary, cost: int) -> CardView:
	if _views.has(inst.uid):
		return _views[inst.uid]
	var view: CardView = CardView.new(inst, data, cost)
	_views[inst.uid] = view
	add_child(view)
	view.pressed.connect(func() -> void: card_pressed.emit(view.uid))
	return view


func remove_card(uid: int) -> void:
	var view: CardView = _views.get(uid)
	if view == null:
		return
	_views.erase(uid)
	remove_child(view)  # detach now — queue_free alone leaves a zombie until frame end
	view.queue_free()


func clear() -> void:
	for uid_v: Variant in _views.keys():
		var view: CardView = _views[uid_v]
		remove_child(view)
		view.queue_free()
	_views.clear()


func uids() -> Array[int]:
	var out: Array[int] = []
	for uid_v: Variant in _views.keys():
		out.append(uid_v)
	return out
