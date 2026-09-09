extends RefCounted
## Research combat-only dispatch. Shipping acquisition and signed arms unchanged.
const Stock: GDScript = preload("res://tools/balance_pilot.gd")
const Planner: GDScript = preload("res://lab_policy.gd")
const Observer: GDScript = preload("res://observed_game.gd")
static var enabled: bool = false
static var queries: int = 0
static var root_rollouts: int = 0
static var query_usec: int = 0
static var faults: Array = []
static var decisions: Array = []

static func reset() -> void:
 queries=0;root_rollouts=0;query_usec=0;faults=[];decisions=[]

static func play_turn(g: GlassvowGame) -> void:
 if not enabled or Stock.random_build or Stock.random_play:
  Stock.play_turn(g);return
 Stock._use_potions(g)
 if g.cb.over:return
 var planner: RefCounted=Planner.new()
 planner.route="balanced"
 planner.params={"bank_mode":"current-plus-next","native_rollout":true,"rollout_samples":2,"rollout_steps":12,"leaf_terminal":false}
 for _guard: int in range(100):
  if g.cb.over:return
  var before: Dictionary=Observer.snapshot(g)
  var started: int=Time.get_ticks_usec()
  var prior_rollouts: int=planner.rollout_count
  var action: Dictionary=planner.choose_action(g)
  query_usec+=Time.get_ticks_usec()-started;queries+=1
  root_rollouts+=planner.rollout_count-prior_rollouts
  var unchanged: bool=before==Observer.snapshot(g)
  decisions.append({"turn":g.cb.turn,"action":action,"alternatives":planner.last_alternatives.duplicate(true),"readonly":unchanged,"root_rollouts":planner.rollout_count-prior_rollouts})
  if not unchanged:
   faults.append({"reason":"LIVE_QUERY_MUTATION","before":before,"after":Observer.snapshot(g)})
   push_error("LIVE_QUERY_MUTATION");return
  if action.is_empty():return
  if not planner.actions(g).has(action):
   faults.append({"reason":"ILLEGAL_PLANNED_ACTION","action":action});push_error("ILLEGAL_PLANNED_ACTION");return
  g.apply(action)
  if action.get("t")=="playCard" and g.last_ret!=true:
   faults.append({"reason":"REJECTED_PLANNED_PLAY","action":action});push_error("REJECTED_PLANNED_PLAY");return
 faults.append({"reason":"PLANNER_TURN_ACTION_CAP","turn":g.cb.turn})
 push_error("PLANNER_TURN_ACTION_CAP")
