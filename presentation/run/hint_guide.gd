class_name HintGuide
extends Control
## First-run hint policy. Presentation only — domain learns nothing.
## Records live on Vigil `hints_seen`, never `unlocks`. Gated on opening
## completion (`scenes_seen.has("opening")`) and production story flow.

const Z: int = 150
const MAP_SELECT: String = "hint_map_select"
const DRAG_PLAY: String = "hint_drag_play"
const TARGETING: String = "hint_targeting"
const END_TURN: String = "hint_end_turn"
const INTENT: String = "hint_intent"
const REWARD: String = "hint_reward"
const COPY: Dictionary = {
	"hint_map_select": "ui.hint.mapSelect",
	"hint_drag_play": "ui.hint.dragPlay",
	"hint_targeting": "ui.hint.targeting",
	"hint_end_turn": "ui.hint.endTurn",
	"hint_intent": "ui.hint.intent",
	"hint_reward": "ui.hint.reward",
}

var main: Main
var overlay: HintOverlay
var active_id: String = ""
var _queued: String = ""
var _queued_anchor: Control = null
var _offer_skip: bool = false


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = Z
	overlay = HintOverlay.new()
	overlay.skip_requested = skip_guidance
	add_child(overlay)


func showing() -> String:
	return active_id


func eligible() -> bool:
	if main == null or main._vigil == null:
		return false
	if not main._story_flow():
		return false
	if not main._vigil.scenes_seen.has("opening"):
		return false
	if main._vigil.guidance_skipped:
		return false
	return true


func hide_callout() -> void:
	active_id = ""
	_queued = ""
	_queued_anchor = null
	overlay.dismiss()


func consider(id: String, anchor: Control) -> void:
	if not eligible() or main._vigil.hints_seen.has(id):
		return
	if not active_id.is_empty():
		if _queued.is_empty() and id != active_id:
			_queued = id
			_queued_anchor = anchor
		return
	_offer_skip = main._vigil.hints_seen.is_empty()
	active_id = id
	if is_inside_tree():
		var parent: Node = get_parent()
		if parent != null:
			parent.move_child(self, -1)
	var ghost_from_n: Control = null
	var ghost_to_n: Control = null
	if id == DRAG_PLAY and main._screen != null:
		ghost_from_n = main._screen.drag_anchor()
		ghost_to_n = main._screen.first_enemy_anchor()
	overlay.present(Locale.active.t(str(COPY.get(id, id))), anchor,
		_offer_skip, ghost_from_n, ghost_to_n)
	if id == MAP_SELECT and main._map_screen != null:
		main._map_screen.set_survey_retired(true)


func consider_map(screen: WorldMapScreen) -> void:
	if screen == null:
		return
	if eligible() and (main._vigil.hints_seen.has(MAP_SELECT) or active_id == MAP_SELECT):
		screen.set_survey_retired(true)
	consider(MAP_SELECT, screen.first_live_waystone())


func consider_combat(screen: CombatScreen) -> void:
	if screen == null or screen.game == null or screen.game.cb == null:
		return
	if screen.seq.is_busy() or screen.game.cb.over:
		return
	var cb: CombatState = screen.game.cb
	if not cb.hand.is_empty():
		consider(DRAG_PLAY, screen.drag_anchor())
	if cb.turn >= 2:
		consider(INTENT, screen.intent_anchor())
	if screen.energy_or_plays_exhausted():
		consider(END_TURN, screen.end_turn_anchor())


func on_card_grabbed(screen: CombatScreen, view: CardView) -> void:
	if view == null or view.target_kind != "enemy":
		return
	if screen.game == null or screen.game.cb == null:
		return
	if screen.game.cb.living_enemies().size() < 2:
		return
	if active_id == DRAG_PLAY:
		return
	consider(TARGETING, screen.first_enemy_anchor())


func record_if_active(id: String) -> bool:
	if active_id != id:
		return true
	return record_dismiss(id)


func record_dismiss(id: String) -> bool:
	if main == null or main._vigil == null:
		return true
	if not eligible():
		return true
	if not main._vigil.hints_seen.has(id):
		main._vigil.hints_seen.append(id)
	# In-memory is not enough: a failed flush must not let the named action
	# through, or a retry-then-pick would advance with the record still only
	# in RAM (#332 persist-before-advance).
	if not _disk_has_hint(id):
		if not main._store_vigil():
			main._show_save_error("ui.persistence.detail.vigilRecord")
			return false
	if active_id == id:
		overlay.dismiss()
		active_id = ""
		_flush_queue()
	return true


func _disk_has_hint(id: String) -> bool:
	var disk: VigilState = SaveService.load_vigil(main._vigil_save_path)
	return disk.hints_seen.has(id)


func skip_guidance() -> void:
	if main == null or main._vigil == null:
		return
	main._vigil.guidance_skipped = true
	if not main._store_vigil():
		main._show_save_error("ui.persistence.detail.vigilRecord")
		return
	hide_callout()


func on_persist_ok() -> void:
	if main == null or main._vigil == null:
		return
	if main._vigil.guidance_skipped:
		hide_callout()
		return
	if not active_id.is_empty() and main._vigil.hints_seen.has(active_id):
		overlay.dismiss()
		active_id = ""
		_flush_queue()


func _flush_queue() -> void:
	var nxt: String = _queued
	var anchor: Control = _queued_anchor
	_queued = ""
	_queued_anchor = null
	if nxt.is_empty():
		return
	consider(nxt, anchor)


