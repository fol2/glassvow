extends "res://greedy_policy.gd"
## Exact pure-query memoisation, scoped to ONE greedy continuation decision.
## No score formula, action enumeration, random draw, or game state is changed.
var _memo_game: GlassvowGame = null
var _memo: Dictionary = {}

func choose_action(g: GlassvowGame) -> Dictionary:
 _memo.clear()
 _memo_game = g if not random_play else null
 var answer: Dictionary = super.choose_action(g)
 _memo_game = null
 _memo.clear()
 return answer

func features(g: GlassvowGame) -> Dictionary:
 if g != _memo_game:return super.features(g)
 if not _memo.has("features"):_memo["features"] = super.features(g)
 return _memo["features"]

func copies(g: GlassvowGame, id: String) -> int:
 if g != _memo_game:return super.copies(g,id)
 var key: String = "copies:"+id
 if not _memo.has(key):_memo[key] = super.copies(g,id)
 return _memo[key]

func incoming(g: GlassvowGame) -> float:
 if g != _memo_game:return super.incoming(g)
 if not _memo.has("incoming"):_memo["incoming"] = super.incoming(g)
 return _memo["incoming"]

func threat(g: GlassvowGame, e: EnemyCombatant) -> float:
 if g != _memo_game:return super.threat(g,e)
 var key: String = "threat:"+str(e.get_instance_id())
 if not _memo.has(key):_memo[key] = super.threat(g,e)
 return _memo[key]

func non_damage_threat(g: GlassvowGame, e: EnemyCombatant) -> float:
 if g != _memo_game:return super.non_damage_threat(g,e)
 var key: String = "non_damage_threat:"+str(e.get_instance_id())
 if not _memo.has(key):_memo[key] = super.non_damage_threat(g,e)
 return _memo[key]

func ember_value(g: GlassvowGame) -> float:
 if g != _memo_game:return super.ember_value(g)
 if not _memo.has("ember_value"):_memo["ember_value"] = super.ember_value(g)
 return _memo["ember_value"]

func draw_value(g: GlassvowGame) -> float:
 if g != _memo_game:return super.draw_value(g)
 if not _memo.has("draw_value"):_memo["draw_value"] = super.draw_value(g)
 return _memo["draw_value"]

func cycle_repeats(g: GlassvowGame) -> float:
 if g != _memo_game:return super.cycle_repeats(g)
 if not _memo.has("cycle_repeats"):_memo["cycle_repeats"] = super.cycle_repeats(g)
 return _memo["cycle_repeats"]

func expected_embers(g: GlassvowGame) -> float:
 if g != _memo_game:return super.expected_embers(g)
 if not _memo.has("expected_embers"):_memo["expected_embers"] = super.expected_embers(g)
 return _memo["expected_embers"]

func nova_spend_cost(g: GlassvowGame, spent: int) -> float:
 if g != _memo_game:return super.nova_spend_cost(g,spent)
 var key: String = "nova_spend_cost:"+str(spent)
 if not _memo.has(key):_memo[key] = super.nova_spend_cost(g,spent)
 return _memo[key]

## int -> decimal string -> binary64 -> int is identity in this exact range.
## All other Variant cases retain the original conversion, including rounding.
func ji(v: Variant) -> int:
 if typeof(v)==TYPE_INT:
  var integer: int=v
  if integer>=-9007199254740991 and integer<=9007199254740991:
   return integer
 return super.ji(v)
