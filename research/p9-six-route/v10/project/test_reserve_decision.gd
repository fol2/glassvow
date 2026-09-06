extends SceneTree
const Old: GDScript=preload("res://policy_buggy_v9.gd")
const New: GDScript=preload("res://lab_policy.gd")
var n: int=0
var fails: int=0
func ck(b: bool,m: String) -> void:
 n+=1
 if not b:fails+=1;push_error("RESERVE_DECISION_FAIL "+m)
func game(aspect: int) -> GlassvowGame:
 var db: ContentDB=ContentDB.load_full()
 var r: RunState=RunState.new_run(db,8300000,"causal-decision",{"aspect":aspect,"vow":0,"reveals":db.reveal_ids.duplicate(),"unlocks":["aspect2"],"quests":{},"shards":[]})
 var g: GlassvowGame=GlassvowGame.new(db,r);g.apply({"t":"startCombat","enemies":["sporeling"],"kind":"normal"})
 r.player.relics.clear();g.cb.hand.clear();g.cb.draw.clear();g.cb.discard.clear();g.cb.exhaust.clear()
 g.cb.player.energy=1;g.cb.player.hp=8;g.cb.player.block=0;g.cb.player.statuses={};g.cb.embers=3
 g.cb.art_used_turn=g.cb.turn;g.cb.kindled_turn=g.cb.turn;g.cb.kindles_this_turn=1
 var e: EnemyCombatant=g.cb.enemies[0];e.hp=16 if aspect==1 else 40;e.max_hp=e.hp;e.block=0;e.statuses={};e.chips=0 if aspect==1 else 2;e.facet_max=3;e.staggered=false;e.flags={}
 e.def={"moves":{"attack":{"dmg":12,"intent":"attack"}}};e.move_key=&"attack"
 db.cards["novaflare"]["cost"]=1;db.cards["novaflare"]["effects"]=[{"kind":"special","id":"emberNova","n":6,"reserve":3}]
 g.cb.hand.append(CardInst.new(100,&"novaflare"));g.cb.hand.append(CardInst.new(101,&"defend"))
 r.player.deck.append(CardInst.new(100,&"novaflare"))
 return g
func _initialize() -> void:
 for aspect: int in [0,1]:
  var old: RefCounted=Old.new();old.route="ember";old.params={"bank_mode":"current-plus-next"}
  var fixed: RefCounted=New.new();fixed.route="ember";fixed.params=old.params.duplicate()
  var g: GlassvowGame=game(aspect)
  var old_choice: Dictionary=old.choose_action(g);var new_choice: Dictionary=fixed.choose_action(g)
  print("RESERVE_CHOICE "+JSON.stringify({"aspect":aspect,"old":old_choice,"new":new_choice}))
  ck(old_choice.get("uid")==100,"red witness: old policy selects imaginary payoff")
  ck(new_choice.get("uid")==101,"green witness: fixed policy chooses actual protection")
  g.apply(old_choice);ck(g.cb.enemies[0].hp==(16 if aspect==1 else 40) and not g.cb.enemies[0].staggered,"native reserve has no damage or shatter")
  g.apply({"t":"endTurn"});ck(g.cb.over and g.cb.result=="loss","old choice really loses")
  g=game(aspect);g.apply(new_choice);g.apply({"t":"endTurn"});ck(not g.cb.over and g.cb.player.hp==1,"new choice really survives at1HP")
  g=game(aspect);g.content.cards["novaflare"]["effects"][0].reserve=0;old=Old.new();fixed=New.new();old.route="ember";fixed.route="ember"
  ck(old.choose_action(g)==fixed.choose_action(g),"zero-reserve decision remains identical")
 print("RESERVE_DECISION_TESTS "+str(n)+" FAILURES "+str(fails));quit(0 if fails==0 else 3)
