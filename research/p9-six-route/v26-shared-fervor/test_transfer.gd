extends SceneTree
const Fixture: GDScript=preload("res://test_stock_ramp.gd")
const Planner: GDScript=preload("res://lab_policy.gd")
var checks:int=0
var failures:int=0
func ck(ok:bool,note:String)->void:
 checks+=1
 if not ok:failures+=1;push_error("ASH_TRANSFER "+note)
func _initialize()->void:
 var args:PackedStringArray=OS.get_cmdline_user_args()
 if args.size()!=1:quit(2);return
 var db:ContentDB=ContentDB.load_from(args[0],true)
 var fixture:SceneTree=Fixture.new()
 for id:String in ["empower","flurry"]:ck(db.card_pools.common.has(id),"natural common access "+id)
 for up:bool in [false,true]:
  var g:GlassvowGame=fixture.game(db,1)
  var a:CardInst=CardInst.new(710,&"empower",up)
  var b:CardInst=CardInst.new(711,&"flurry",up)
  g.cb.hand.append(a);g.cb.hand.append(b)
  var first_cost:int=g.rules.eff_cost(g.run,g.cb,a)
  var second_cost:int=g.rules.eff_cost(g.run,g.cb,b)
  var before:int=g.cb.player.energy
  g.apply({"t":"playCard","uid":710,"target":null})
  ck(g.last_ret==true,"paid producer legal")
  ck(int(g.cb.player.statuses.get("str",0))==(4 if up else 3),"real Fervor")
  ck(g.cb.player.energy==before-first_cost,"producer cost")
  var hp:int=g.cb.enemies[0].hp
  var events:Array[Dictionary]=g.apply({"t":"playCard","uid":711,"target":0})
  ck(g.last_ret==true,"consumer legal")
  ck(hp-g.cb.enemies[0].hp==(25 if up else 15),"native five-hit payoff")
  ck(g.cb.player.energy==before-first_cost-second_cost,"consumer cost")
  ck(g.cb.enemies[0].chips==0 and not g.cb.enemies[0].staggered,"Ash no Dusk facet control")
  var shatters:int=0
  for e:Dictionary in events:
   if e.get("t")==EventTypes.SHATTER:shatters+=1
  ck(shatters==0,"no Shatter events")
  var h:GlassvowGame=fixture.game(db,1)
  h.cb.hand.append(CardInst.new(712,&"empower",up));h.cb.hand.append(CardInst.new(713,&"flurry",up))
  h.cb.art_used_turn=h.cb.turn;h.cb.kindles_this_turn=1;h.cb.kindled_turn=h.cb.turn
  var saved:String=JSON.stringify([h.run.to_dict(),h.cb.to_dict(),h.run.rng_state()])
  var planner:RefCounted=Planner.new();planner.route="fervor";planner.params={"native_rollout":true,"rollout_samples":2,"rollout_steps":12,"leaf_terminal":false,"bank_mode":"current-plus-next"}
  var chosen:Dictionary=planner.choose_action(h)
  ck(not chosen.is_empty(),"existing planner selects action")
  ck(JSON.stringify([h.run.to_dict(),h.cb.to_dict(),h.run.rng_state()])==saved,"no live mutation")
 fixture.free()
 print("ASH_TRANSFER_CHECKS "+str(checks)+" FAILURES "+str(failures))
 quit(0 if failures==0 else 3)
