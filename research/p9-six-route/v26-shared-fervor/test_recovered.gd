extends SceneTree
const Fixture: GDScript=preload("res://test_stock_ramp.gd")
const Planner: GDScript=preload("res://lab_policy.gd")
var checks: int=0
var failures: int=0
func ck(ok: bool,note: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("SHARED_FERVOR_TEST "+note)
func _initialize() -> void:
 var args: PackedStringArray=OS.get_cmdline_user_args()
 if args.size()!=1:quit(2);return
 var db: ContentDB=ContentDB.load_from(args[0],true)
 var helper: SceneTree=Fixture.new()
 ck(db!=null,"native content load")
 ck(db.card_pools.common.has("empower") and db.card_pools.common.has("flurry"),"real common acquisition")
 for up: bool in [false,true]:
  var g: GlassvowGame=helper.game(db,1)
  g.cb.hand.append(CardInst.new(701,&"empower",up));g.cb.hand.append(CardInst.new(702,&"flurry",up))
  var before: String=JSON.stringify([g.run.to_dict(),g.cb.to_dict(),g.run.rng_state()])
  var policy: RefCounted=Planner.new();policy.route="fervor";policy.params={"native_rollout":true,"rollout_samples":2,"rollout_steps":12,"leaf_terminal":false}
  var action: Dictionary=policy.choose_action(g)
  ck(not action.is_empty(),"existing controller can choose in Ash")
  ck(before==JSON.stringify([g.run.to_dict(),g.cb.to_dict(),g.run.rng_state()]),"native planning read-only")
  g.apply({"t":"playCard","uid":701,"target":null})
  ck(g.last_ret==true and g.cb.player.energy==2,"setup paid")
  ck(int(g.cb.player.statuses.get("str",0))==(4 if up else 3),"actual Fervor")
  g.apply({"t":"playCard","uid":702,"target":0})
  ck(g.last_ret==true and g.cb.player.energy==1,"consumer paid")
  ck(1000-g.cb.enemies[0].hp==(25 if up else 15),"five hit health removal")
  ck(g.cb.enemies[0].chips==0 and not g.cb.enemies[0].staggered,"Ash does not inherit Dusk chips or stun")
 helper.free()
 print("SHARED_FERVOR_CHECKS "+str(checks)+" FAILURES "+str(failures))
 quit(0 if failures==0 else 3)
