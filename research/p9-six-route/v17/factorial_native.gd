extends SceneTree
## Controlled native coupling experiments, not run-level strategy admission.
var checks: int=0
var failures: int=0
var records: Array=[]
func ck(ok: bool,note: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("FACTORIAL_FAIL "+note)
func game(aspect: int) -> GlassvowGame:
 var db: ContentDB=ContentDB.load_from("/mnt/data/p9_current/shortcut_content/control.json",true)
 var r: RunState=RunState.new_run(db,17000001,"factorial",{"aspect":aspect,"vow":0,"reveals":db.reveal_ids.duplicate(),"unlocks":["aspect2"],"quests":{},"shards":[]})
 r.omens=[null,null,null];r.player.relics.clear()
 var g: GlassvowGame=GlassvowGame.new(db,r)
 g.apply({"t":"startCombat","enemies":["sporeling"],"kind":"normal","affix":null})
 g.cb.affix=&"";g.cb.player.hp=64;g.cb.player.max_hp=64;g.cb.player.energy=3;g.cb.player.statuses={};g.cb.player.block=0
 g.cb.hand.clear();g.cb.draw.clear();g.cb.discard.clear();g.cb.exhaust.clear();g.cb.embers=0
 g.cb.art_used_turn=g.cb.turn;g.cb.kindled_turn=g.cb.turn;g.cb.kindles_this_turn=1
 var e: EnemyCombatant=g.cb.enemies[0]
 e.hp=200;e.max_hp=200;e.block=0;e.chips=0;e.facet_max=100;e.statuses={};e.flags={};e.staggered=false
 e.def={"moves":{"attack":{"dmg":10,"intent":"attack"}}};e.move_key=&"attack"
 return g
func card(g: GlassvowGame,id: String,up: bool=false) -> CardInst:
 var c: CardInst=CardInst.new(g.run.next_uid(),StringName(id),up);g.cb.hand.append(c);return c
func play(g: GlassvowGame,c: CardInst) -> void:
 var d: Dictionary=g.rules.card_data(c);var t: Variant=0 if d.get("target")=="enemy" else null
 ck(g.rules.can_play(g.run,g.cb,c,t),"legality "+String(c.id))
 g.apply({"t":"playCard","uid":c.uid,"target":t});ck(g.last_ret==true,"native play "+String(c.id))
func trial(name: String,producer: bool,consumer: bool) -> Dictionary:
 var a: int=0 if name in ["facet","fervor","cycle"] else 1
 var g: GlassvowGame=game(a);var e: EnemyCombatant=g.cb.enemies[0]
 var payoff: float=0
 if name=="facet":
  e.chips=2;e.facet_max=4
  if not producer:g.content.cards["chisel"]["chip"]=0
  if not consumer:e.flags["adamant"]=true
  play(g,card(g,"chisel"));g.apply({"t":"endTurn"})
  payoff=10-(64-g.cb.player.hp)
 elif name=="fervor":
  if not producer:g.content.cards["empower"]["effects"][0]["n"]=0
  if not consumer:g.content.cards["flurry"]["effects"][0]["times"]=1
  play(g,card(g,"empower"));play(g,card(g,"flurry"));payoff=200-e.hp
 elif name=="cycle":
  if not producer:g.content.cards["momentum"]["effects"][0]["grow"]=0
  var m: CardInst=card(g,"momentum");var q: CardInst=card(g,"quickSlash")
  play(g,m);play(g,q)
  ck(g.cb.hand.has(m),"same Momentum redrawn by native reshuffle")
  if not consumer:g.content.cards["momentum"]["effects"][0]={"kind":"dmg","n":0}
  var before: int=e.hp;play(g,m);payoff=before-e.hp
 elif name=="smolder":
  if not producer:g.content.cards["toxicMist"]["effects"][0]["n"]=0
  if not consumer:g.content.cards["catalyst"]["effects"][0]["n"]=1
  play(g,card(g,"toxicMist"));play(g,card(g,"catalyst"));g.apply({"t":"endTurn"});payoff=200-e.hp
 elif name=="hand":
  if not producer:g.content.cards["preparation"]["up"]["effects"][0]["n"]=0
  if not consumer:g.content.cards["phantomBlades"]["effects"][0]["n"]=0
  var prep: CardInst=card(g,"preparation",true);var ph: CardInst=card(g,"phantomBlades")
  for i: int in range(3):card(g,"defend")
  for i: int in range(3):g.cb.draw.append(CardInst.new(g.run.next_uid(),&"strike"))
  play(g,prep);play(g,ph);payoff=200-e.hp
 elif name=="ember":
  if not producer:
   for fx: Dictionary in g.content.cards["tithe"]["effects"]:
    if fx.get("kind")=="ember":fx["n"]=0
  if not consumer:g.content.cards["novaflare"]["effects"][0]["n"]=0
  g.cb.embers=4
  play(g,card(g,"tithe"));var before: int=g.cb.embers
  play(g,card(g,"novaflare"));ck(g.cb.embers==before,"Nova retains held resource");payoff=200-e.hp
 return {"route":name,"producer":producer,"consumer":consumer,"payoff":payoff,"end_hp":g.cb.player.hp,"end_energy":g.cb.player.energy,"enemy_hp":e.hp,"embers":g.cb.embers}
func _initialize() -> void:
 for name: String in ["facet","fervor","cycle","smolder","hand","ember"]:
  var values: Array=[]
  for p: bool in [false,true]:
   for c: bool in [false,true]:
    var rec: Dictionary=trial(name,p,c);records.append(rec);values.append(rec.payoff)
  var interaction: float=values[3]-values[2]-values[1]+values[0]
  ck(interaction>0,"positive coupling "+name)
  print(JSON.stringify({"kind":"factorial","route":name,"values_00_01_10_11":values,"interaction":interaction}))
 var out: FileAccess=FileAccess.open("/mnt/data/p9_current/micro/rows.json",FileAccess.WRITE)
 out.store_string(JSON.stringify(records,"  ")+"\n")
 print("FACTORIAL_NATIVE_ASSERTIONS ",checks," FAILURES ",failures)
 quit(0 if failures==0 else 3)
