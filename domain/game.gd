class_name GlassvowGame
extends RefCounted
## Facade: apply(cmd) -> Array[Dictionary] GameEvents (SKILL §2).
## Command "t" values mirror the recorded web trace op names verbatim
## (playCard, endTurn, kindleFromHand, useArt, usePotion, startCombat,
## addCardToDeck) so the fixture replayer is a passthrough.


var content: ContentDB
var rules: CombatRules
var run: RunState
var cb: CombatState = null
## Return value of the last op (web playCard/usePotion return bool).
var last_ret: Variant = null


func _init(content_db: ContentDB, run_state: RunState) -> void:
	content = content_db
	rules = CombatRules.new(content_db)
	run = run_state


func apply(cmd: Dictionary) -> Array[Dictionary]:
	var t: String = str(cmd.get("t", ""))
	last_ret = null
	var q_before: int = cb.queue.size() if cb != null else 0
	match t:
		"startCombat":
			var enemies: Array = cmd.get("enemies", [])
			var kind: StringName = StringName(str(cmd.get("kind", "normal")))
			var affix_v: Variant = cmd.get("affix")
			var affix: StringName = &"" if affix_v == null else StringName(str(affix_v))
			cb = rules.start_combat(run, enemies, kind, affix)
			q_before = 0
		"playCard":
			var uid: int = cmd.get("uid", 0)
			var target_v: Variant = cmd.get("target")
			last_ret = rules.play_card(run, cb, uid, target_v)
		"kindleFromHand":
			# The recorded traces carry ret:null for these ops — the web recorder
			# only captures playCard's return — so last_ret stays null here.
			var kindle_uid: int = cmd.get("uid", 0)
			rules.kindle_from_hand(run, cb, kindle_uid)
		"useArt":
			rules.use_art(run, cb)
		"usePotion":
			var slot: int = cmd.get("slot", 0)
			var potion_target: Variant = cmd.get("target")
			last_ret = rules.use_potion(run, cb, slot, potion_target)
		"addCardToDeck":
			var card_id: StringName = StringName(str(cmd.get("cardId", "")))
			run.player.deck.append(CardInst.new(run.next_uid(), card_id, false))
		_:
			push_error("GlassvowGame.apply: unknown command %s" % t)
	var out: Array[Dictionary] = []
	if cb != null:
		for k: int in range(q_before, cb.queue.size()):
			out.append(cb.queue[k])
	return out
