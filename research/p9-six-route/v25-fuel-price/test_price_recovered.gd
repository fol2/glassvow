extends SceneTree
const Fixture: GDScript=preload("res://test_stock_ramp.gd")
const Cloner: GDScript=preload("res://public_rollout.gd")
const Planner: GDScript=preload("res://lab_policy.gd")
var checks: int=0
var failures: int=0
func ck(value: bool,label: String) -> void:
 checks+=1
 if not value:failures+=1;push_error("PRICE_TEST "+label)
func maximum_damage(g: GlassvowGame) -> int:
 var best: int=1000-g.cb.enemies[0].hp
 for card: CardInst in g.cb.hand:
  if not g.rules.can_play(g.run,g.cb,card,0):continue
  var branch: GlassvowGame=Cloner.clone_public(g,0)
  branch.apply({"t":"playCard","uid":card.uid,"target":0})
  if not branch.last_ret:continue
  best=maxi(best,maximum_damage(branch))
 return best
func _initialize() -> void:
 var args: PackedStringArray=OS.get_cmdline_user_args()
 if args.size()!=1:quit(2);return
 var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
 var helper: SceneTree=Fixture.new()
 var optimum: Dictionary={}
 for label: String in manifest:
  var db: ContentDB=ContentDB.load_from(str(manifest[label].path),true)
  ck(db!=null,"valid database")
  var energy_cost: int=int(manifest[label].energy)
  for aspect: int in [0,1]:
   for upgraded: bool in [false,true]:
    for capacity: int in [9,12]:
     for stock: int in range(capacity+1):
      var g: GlassvowGame=helper.game(db,aspect)
      g.cb.ember_cap=capacity;g.cb.embers=stock
      var card: CardInst=CardInst.new(700,&"novaflare",upgraded)
      g.cb.hand.append(card)
      var before: String=JSON.stringify([g.run.to_dict(),g.cb.to_dict()])
      var preview: Variant=g.rules.preview_play(g.cb,card,0,g.run)
      ck(before==JSON.stringify([g.run.to_dict(),g.cb.to_dict()]),"preview is read-only")
      var paid: int=mini(stock,2)
      var expected: int=(9 if upgraded else 8)*paid
      ck(preview.total==expected and preview.loss==expected,"raw stock payoff")
      ck(g.rules.eff_cost(g.run,g.cb,card)==energy_cost,"declared energy")
      var hp: int=g.cb.player.hp
      g.apply({"t":"playCard","uid":700,"target":0})
      ck(g.last_ret==true,"legal play")
      ck(1000-g.cb.enemies[0].hp==expected,"actual enemy health")
      ck(g.cb.embers==stock-paid,"actual fuel debit")
      ck(g.cb.player.energy==3-energy_cost,"energy debit")
      ck(g.cb.player.hp==hp,"no HP creation")
      ck(g.cb.hand.is_empty() and g.cb.discard.size()==1 and g.cb.exhaust.is_empty(),"paid card leaves hand with no draw")
      ck(g.cb.draw.is_empty(),"no created draw")
      ck(int(g.run.stats.get("embersSpent",0))==paid,"spent accounting")
  for stock: int in [0,2]:
   var g: GlassvowGame=helper.game(db,1);g.cb.embers=stock
   g.cb.hand.append(CardInst.new(700,&"novaflare"))
   for j: int in range(3):g.cb.hand.append(CardInst.new(710+j,&"strike"))
   var state: String=JSON.stringify([g.run.to_dict(),g.cb.to_dict()])
   var best: int=maximum_damage(g)
   ck(state==JSON.stringify([g.run.to_dict(),g.cb.to_dict()]),"enumeration read-only")
   ck(best==(18 if stock==0 else (34 if energy_cost==0 else 28)),"finite native action optimum")
   optimum[label+"-stock"+str(stock)]=best
   var policy: RefCounted=Planner.new()
   policy.route="ember";policy.params={"native_rollout":true,"rollout_samples":2,"rollout_steps":12}
   var action: Dictionary=policy.choose_action(g)
   ck(state==JSON.stringify([g.run.to_dict(),g.cb.to_dict()]),"planner read-only")
   ck(not action.is_empty(),"planner returns action")
 print("PRICE_ENUMERATION "+JSON.stringify(optimum))
 helper.free()
 print("PRICE_TESTS "+str(checks)+" FAILURES "+str(failures))
 quit(0 if failures==0 else 3)
