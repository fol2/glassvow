extends SceneTree
const Fixture: GDScript=preload("res://test_stock_ramp.gd")
var n: int=0
var failed: int=0
func ck(ok: bool,message: String) -> void:
 n+=1
 if not ok:failed+=1;push_error("SELECTIVITY_TEST "+message)
func _initialize() -> void:
 var args: PackedStringArray=OS.get_cmdline_user_args()
 if args.size()!=1:quit(2);return
 var records: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
 var f: SceneTree=Fixture.new()
 var names: Dictionary={"venom_off":"venomStrike","catalyst_off":"catalyst","sight_off":"nightSight","phantom_off":"phantomBlades","flow_off":"pyreheart","nova_off":"novaflare"}
 for arm: String in names:
  var cid: String=names[arm]
  for up: bool in [false,true]:
   for off: bool in [false,true]:
    var db: ContentDB=ContentDB.load_from(records[arm if off else "control"].path,true)
    ck(db!=null,"valid content "+arm)
    if db==null:continue
    var g: GlassvowGame=f.game(db,1);g.cb.embers=8
    var e: EnemyCombatant=g.cb.enemies[0];e.statuses.poison=5
    var card: CardInst=CardInst.new(700,StringName(cid),up)
    g.cb.hand.append(card)
    for j: int in range(8):g.cb.hand.append(CardInst.new(800+j,&"strike"))
    var d: Dictionary=g.rules.card_data(card)
    var cost: int=g.rules.eff_cost(g.run,g.cb,card)
    var target: Variant=null if d.get("target")=="self" else 0
    g.apply({"t":"playCard","uid":700,"target":target})
    ck(g.last_ret==true,"legal "+arm)
    ck(g.cb.player.energy==3-cost,"energy "+arm)
    match arm:
     "venom_off":
      ck(e.hp==1000-(6 if up else 4),"physical preserved")
      ck(int(e.statuses.poison)==5+(0 if off else (5 if up else 4)),"venom delta")
     "catalyst_off":
      ck(int(e.statuses.poison)==5*(1 if off else (3 if up else 2)),"consumer delta")
      ck(g.cb.exhaust.has(card),"exhaust preserved")
     "sight_off":ck(int(g.cb.player.statuses.get("nightsight",0))==(0 if off else 1),"sight delta")
     "flow_off":ck(int(g.cb.player.statuses.get("emberflow",0))==(0 if off else (3 if up else 2)),"flow delta")
     "phantom_off":ck(1000-e.hp==(0 if off else (36 if up else 32)),"hand payoff")
     "nova_off":
      ck(1000-e.hp==(0 if off else (36 if up else 32)),"nova payoff")
      ck(g.cb.embers==5,"real debit retained")
 f.free()
 print("SELECTIVITY_TESTS "+str(n)+" FAILURES "+str(failed))
 quit(0 if failed==0 else 3)
