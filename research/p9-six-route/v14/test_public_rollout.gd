extends SceneTree
const Clone: GDScript = preload("res://public_rollout.gd")
const Policy: GDScript = preload("res://lab_policy.gd")
const Greedy: GDScript = preload("res://greedy_policy.gd")
var checks: int = 0
var failures: int = 0
func ck(condition: bool, message: String) -> void:
 checks += 1
 if not condition:
  failures += 1
  push_error("PUBLIC_ROLLOUT_TEST_FAIL " + message)
func game(aspect: int = 0) -> GlassvowGame:
 var db: ContentDB = ContentDB.load_full()
 var r: RunState = RunState.new_run(db, 14000000, "public-rollout-test", {"aspect":aspect,"vow":0,"reveals":db.reveal_ids.duplicate(),"unlocks":["aspect2"],"quests":{},"shards":[]})
 r.omens = [null,null,null]
 r.player.relics.clear()
 var g: GlassvowGame = GlassvowGame.new(db,r)
 g.apply({"t":"startCombat","enemies":["sporeling","sporeling"],"kind":"normal","affix":null})
 g.cb.affix = &""
 g.cb.player.hp = 8
 g.cb.player.energy = 1
 g.cb.player.block = 0
 g.cb.player.statuses = {}
 g.cb.embers = 0
 g.cb.art_used_turn = g.cb.turn
 g.cb.kindled_turn = g.cb.turn
 g.cb.kindles_this_turn = 1
 g.cb.hand.clear();g.cb.draw.clear();g.cb.discard.clear();g.cb.exhaust.clear()
 for i: int in range(2):
  var e: EnemyCombatant = g.cb.enemies[i]
  e.hp=30;e.max_hp=30;e.block=0;e.chips=2;e.facet_max=4;e.statuses={};e.flags={};e.staggered=false
  e.def={"moves":{"attack":{"dmg":2 if i==0 else 12,"intent":"attack"}}};e.move_key=&"attack"
 g.cb.hand.append(CardInst.new(100,&"chisel"))
 return g
func state(g: GlassvowGame) -> String:
 return JSON.stringify([g.run.to_dict(),g.cb.to_dict(),g.run.rng_state(),g.cb.queue,g.cb.counters_played,g.cb.art_used_turn,g.cb.kindled_turn])
func _initialize() -> void:
 var g: GlassvowGame=game()
 var original: String=state(g)
 var model: GlassvowGame=Clone.clone_public(g,0)
 ck(g.run!=model.run and g.cb!=model.cb,"distinct run/combat")
 ck(g.run.player!=model.run.player and g.cb.player!=model.cb.player,"distinct players")
 ck(g.cb.enemies[0]!=model.cb.enemies[0] and g.cb.hand[0]!=model.cb.hand[0],"distinct enemy/card")
 ck(model.cb.enemies[0].hp==30 and model.cb.player.energy==1,"public fields retained")
 model.apply({"t":"playCard","uid":100,"target":1})
 ck(model.cb.enemies[1].staggered and not model.cb.enemies[0].staggered,"native shatter in clone")
 ck(state(g)==original,"rollout cannot mutate live state")
 var p: RefCounted=Policy.new();p.route="facet";p.params={"native_rollout":true,"rollout_samples":2,"rollout_steps":8}
 var choice: Dictionary=p.choose_action(g)
 ck(choice.get("target")==1,"planner chooses dangerous enemy")
 ck(state(g)==original,"planning cannot mutate live state")
 g.apply(choice);g.apply({"t":"endTurn"})
 ck(not g.cb.over and g.cb.player.hp==6,"actual chosen intervention survives")
 g=game();g.cb.draw.append(CardInst.new(101,&"flurry"));g.cb.draw.append(CardInst.new(102,&"defend"));g.cb.draw.append(CardInst.new(103,&"preparation"))
 var a: GlassvowGame=Clone.clone_public(g,1)
 g.cb.draw.reverse();g.run.rng.next();g.run.rng.next()
 var b: GlassvowGame=Clone.clone_public(g,1)
 ck(state(a)==state(b),"same public state gives identical determinization despite hidden order/RNG")
 p=Policy.new();p.params={"native_rollout":true};var a1: Dictionary=p.choose_action(g)
 var scores1: String=JSON.stringify(p.last_alternatives)
 g.cb.draw.reverse();g.run.rng.next();p=Policy.new();p.params={"native_rollout":true};var a2: Dictionary=p.choose_action(g)
 ck(a1==a2 and scores1==JSON.stringify(p.last_alternatives),"action/value invariant to hidden order/RNG")
 # Every observed hidden permutation has the same multiset, not a secret peek.
 var ids: Array=[]
 for c: CardInst in a.cb.draw:ids.append(String(c.id))
 ids.sort()
 ck(ids==["defend","flurry","preparation"],"determinization preserves draw multiset")
 # Constructor cloning must retain typed arrays, modifiers and per-turn state.
 ck(a.cb.draw.is_typed() and a.cb.enemies.is_typed(),"typed arrays retained")
 ck(a.cb.art_used_turn==g.cb.art_used_turn and a.cb.kindles_this_turn==1,"per-turn limits retained")
 # End-turn simulation must implement poison death, not grant survival on an attack-only estimate.
 g=game(1);g.cb.enemies[0].statuses={"poison":40};g.cb.enemies[1].statuses={"poison":40}
 model=Clone.clone_public(g,0);model.apply({"t":"endTurn"})
 ck(model.cb.over and model.cb.result=="win","native poison-end-turn branch")
 ck(not g.cb.over,"poison rollout isolated")
 print("PUBLIC_ROLLOUT_TESTS "+str(checks)+" FAILURES "+str(failures))
 quit(0 if failures==0 else 3)
