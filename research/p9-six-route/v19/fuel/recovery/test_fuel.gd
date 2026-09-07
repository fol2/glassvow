extends SceneTree
const Fixture: GDScript=preload("res://test_stock_ramp.gd")
const Greedy: GDScript=preload("res://greedy_policy.gd")
var n: int=0
var bad: int=0
func ck(ok: bool,note: String) -> void:
 n+=1
 if not ok:bad+=1;push_error("FUEL_TEST "+note)
func _initialize() -> void:
 var argv: PackedStringArray=OS.get_cmdline_user_args()
 if argv.size()!=1:quit(2);return
 var records: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(argv[0]))
 var fixture: SceneTree=Fixture.new()
 for key: String in records:
  var db: ContentDB=ContentDB.load_from(records[key].path,true)
  ck(db!=null,"valid recipe")
  if db==null:continue
  for a: int in [0,1]:
   for up: bool in [false,true]:
    for q: int in range(13):
     for lethal: bool in [false,true]:
      var g: GlassvowGame=fixture.game(db,a);g.cb.ember_cap=12;g.cb.embers=q
      var card: CardInst=CardInst.new(800,&"novaflare",up);g.cb.hand.append(card)
      var fx: Dictionary=g.rules.card_data(card).effects[0]
      var raw: int=g.rules.resource_payoff(q,fx)
      var debit: int=mini(q,int(fx.get("consumeEmbers",0)))
      var enemy: EnemyCombatant=g.cb.enemies[0]
      if lethal:enemy.hp=1
      var before_hp: int=enemy.hp;var before_spent: int=int(g.run.stats.get("embersSpent",0))
      var pv: Dictionary=g.rules.preview_play(g.cb,card,0,g.run)
      var ev: Array[Dictionary]=g.apply({"t":"playCard","uid":800,"target":0})
      ck(g.last_ret==true,"legal")
      ck(before_hp-enemy.hp==mini(raw,before_hp),"actual damage")
      ck(int(pv.total)==raw,"preview")
      ck(g.cb.embers==q-debit,"debit, including lethal")
      ck(int(g.run.stats.get("embersSpent",0))-before_spent==debit,"stats")
      ck(g.cb.player.energy==2,"energy")
      var debit_at: int=-1;var hit_at: int=-1
      for i: int in range(ev.size()):
       if ev[i].t==EventTypes.EMBER and int(ev[i].get("n",0))<0:debit_at=i
       if ev[i].t==EventTypes.HIT_ENEMY and hit_at<0:hit_at=i
      if debit>0:ck(debit_at>=0 and (hit_at<0 or debit_at<hit_at),"debit before hit")
      for cap: int in [9,12]:
       if q<=cap:
        ck(raw*3<=g.rules.resource_payoff(cap,fx)*mini(3,q),"stock-dependent energy bound")
 # Native four-turn factorial: pay setup, then match post-setup bank at8.
 var db: ContentDB=ContentDB.load_from(records.production1_demand3.path,true)
 var values: Array=[]
 for flow: int in [0,3]:
  for demand: int in [0,3]:
   var local_db: ContentDB=ContentDB.load_from(records.production1_demand3.path,true)
   local_db.cards.novaflare.effects[0].consumeEmbers=demand
   local_db.cards.pyreheart.effects[0].n=1 if flow>0 else 0
   var g: GlassvowGame=fixture.game(local_db,1)
   var e: EnemyCombatant=g.cb.enemies[0];e.hp=10000;e.max_hp=10000
   e.def={"moves":{"wait":{"type":"buff"}}};e.move_key=&"wait"
   g.cb.player.energy=3
   for k: int in range(3):
    g.cb.hand.append(CardInst.new(100+k,&"pyreheart"))
    g.apply({"t":"playCard","uid":100+k})
    ck(g.last_ret==true,"paid producer/placebo")
   ck(g.cb.player.energy==0,"three setup costs")
   ck(int(g.cb.player.statuses.get("emberflow",0))==flow,"actual installed flow")
   g.cb.embers=8
   var initial: int=e.hp
   for t: int in range(4):
    g.apply({"t":"endTurn"})
    g.cb.hand.clear();g.cb.draw.clear();g.cb.discard.clear()
    g.cb.hand.append(CardInst.new(900+t,&"novaflare"))
    g.apply({"t":"playCard","uid":900+t,"target":0})
    ck(g.last_ret==true,"native repeated fuel consumer")
   values.append(initial-e.hp)
 ck(values==[128,50,152,152],"four-turn raw stock factorial "+str(values))
 print("FUEL_FACTORIAL "+str(values)+" INTERACTION "+str(values[3]-values[2]-values[1]+values[0]))
 fixture.free()
 print("FUEL_TESTS "+str(n)+" FAILURES "+str(bad))
 quit(0 if bad==0 else 3)
