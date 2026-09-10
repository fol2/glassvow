extends SceneTree
const Observer: GDScript = preload("res://observed_game.gd")
const Public: GDScript = preload("res://public_rollout.gd")
const Planner: GDScript = preload("res://lab_policy.gd")
const HAND_FLAGS: Array[String] = ["hand_preparation_enabled", "hand_surge_enabled", "hand_phantom_enabled"]

class Expanded:
 extends CombatRules
 var raw_amount: int = 0
 func card_data(inst: CardInst) -> Dictionary:
  var d: Dictionary = super.card_data(inst)
  if String(inst.id) != "phantomBlades":return d
  var out: Dictionary = d.duplicate(true)
  out["effects"] = [{"kind":"dmg","n":raw_amount}]
  return out

var db: ContentDB
var output: FileAccess
var trace: FileAccess
var mode: String
var count: int = 0

func flags(g: GlassvowGame) -> Array:
 var available: Dictionary = {}
 for p: Dictionary in g.rules.get_property_list():available[str(p.name)] = true
 var out: Array=[]
 for key: String in HAND_FLAGS:
  out.append(bool(g.rules.get(key)) if available.has(key) else true)
 return out

func set_flags(g: GlassvowGame, active: bool) -> void:
 for p: Dictionary in g.rules.get_property_list():
  var key: String=str(p.name)
  if key in HAND_FLAGS:g.rules.set(key,active if key=="hand_phantom_enabled" else true)

func make(up: bool, aspect: int, vow: int, q: int, context: String, active: bool, key: String) -> GlassvowGame:
 var r: RunState = RunState.new_run(db,73630010,"hand-law-delta",{"aspect":aspect,"vow":vow,"reveals":db.reveal_ids.duplicate(),"unlocks":["aspect2"],"quests":{},"shards":[]})
 r.omens=[null,null,null];r.player.relics.clear()
 var g: GlassvowGame=Observer.new(db,r)
 set_flags(g,active)
 Observer.begin(key,trace)
 g.apply({"t":"startCombat","enemies":["sporeling"],"kind":"normal"})
 g.cb.affix=&"";g.cb.player.statuses={"str":2};g.cb.player.energy=1
 g.cb.player.hp=60;g.cb.player.max_hp=100;g.cb.player.block=0
 g.run.player.hp=60;g.run.player.max_hp=100
 g.cb.hand.clear();g.cb.draw.clear();g.cb.discard.clear();g.cb.exhaust.clear();g.run.player.deck.clear()
 var consumer: CardInst=CardInst.new(10002,&"phantomBlades",up)
 g.cb.hand.append(consumer);g.run.player.deck.append(consumer)
 for i: int in range(q):
  var c: CardInst=CardInst.new(11000+i,&"defend")
  g.cb.hand.append(c);g.run.player.deck.append(c)
 var e: EnemyCombatant=g.cb.enemies[0]
 e.hp=1000;e.max_hp=1000;e.block=0;e.chips=0;e.facet_max=100
 e.statuses={};e.flags={};e.staggered=false
 if context=="block":e.block=11
 if context=="weak-vulnerable":g.cb.player.statuses["weak"]=1;e.statuses["vulnerable"]=1
 if context=="lethal":e.hp=1
 if context=="fatal-thorns":e.statuses["thorns"]=100
 if context=="shatter":e.facet_max=1
 if context=="no-energy":g.cb.player.energy=0
 g.cb.queue.clear()
 return g

func expected_raw(q: int, data: Dictionary, active: bool) -> int:
 if not active:return 0
 var fx: Dictionary=data["effects"][0]
 var n: int=int(fx["n"])
 var r: int=maxi(0,int(fx.get("reserve",0)))
 return n*maxi(0,q-r)+int(fx.get("floor_per",0))*mini(q,r)

func one(up: bool, aspect: int, vow: int, q: int, context: String, active: bool) -> void:
 var key: String=str(aspect)+":"+str(vow)+":"+str(up)+":"+str(q)+":"+context+":"+str(active)
 var g: GlassvowGame=make(up,aspect,vow,q,context,active,key)
 var catalogue: String=JSON.stringify(db.cards)
 var before: Dictionary=Observer.snapshot(g)
 var card: CardInst=g.cb.hand[0]
 var original: Dictionary=db.cards["phantomBlades"].duplicate(true)
 if up:original.merge(original["up"],true)
 var raw: int=expected_raw(q,original,active)
 var observed_data: Dictionary=g.rules.card_data(card).duplicate(true)
 var actual_raw: int=expected_raw(q,observed_data,true)
 var predicted: Dictionary=observed_data.duplicate(true)
 predicted["effects"]=[{"kind":"dmg","n":raw}]
 var policy: RefCounted=Planner.new()
 policy.route="balanced"
 policy.params={"bank_mode":"current-plus-next","native_rollout":true,"rollout_samples":1,"rollout_steps":12,"leaf_terminal":false}
 var score: float=policy.score(g,card,observed_data,0,false)
 var expanded_score: float=policy.score(g,card,predicted,0,false)
 var draft: float=policy.draft(g,observed_data,"phantomBlades",false)
 var four_raw: int=expected_raw(4,original,active)
 var draft_projection: Dictionary=observed_data.duplicate(true)
 draft_projection["effects"]=[{"kind":"dmg","n":four_raw}]
 var expanded_draft: float=policy.draft(g,draft_projection,"phantomBlades",false)
 var action: Dictionary={};var alternatives: Array=[]
 if mode in ["reference","linear"] and active and q==4 and context=="plain":
  action=policy.choose_action(g);alternatives=policy.last_alternatives.duplicate(true)
 var public: GlassvowGame=Public.clone_public(g,0)
 var exact: GlassvowGame=g.call("clone_game")
 var expanded: GlassvowGame=g.call("clone_game")
 var law: Expanded=Expanded.new(db)
 law.raw_amount=raw
 expanded.rules=law;set_flags(expanded,active)
 var readonly: bool=Observer.snapshot(g)==before
 var command: Dictionary={"t":"playCard","uid":10002,"target":0}
 var events: Array[Dictionary]=g.apply(command)
 var exact_events: Array[Dictionary]=exact.apply(command)
 var expanded_events: Array[Dictionary]=expanded.apply(command)
 output.store_line(JSON.stringify({"key":key,"q":q,"up":up,"aspect":aspect,"vow":vow,"context":context,"active":active,
  "before":before,"data":observed_data,"expected_raw":raw,"actual_raw":actual_raw,
  "score":score,"expanded_score":expanded_score,"draft":draft,"expanded_draft":expanded_draft,
  "query":action,"alternatives":alternatives,"readonly":readonly,"catalogue_unchanged":catalogue==JSON.stringify(db.cards),
  "flags":flags(g),"exact_flags":flags(exact),"public_flags":flags(public),
  "return":g.last_ret,"after":Observer.snapshot(g),"events":events,
  "exact_after":Observer.snapshot(exact),"exact_events":exact_events,
  "expanded_after":Observer.snapshot(expanded),"expanded_events":expanded_events}))
 count+=1

func _initialize() -> void:
 var args: PackedStringArray=OS.get_cmdline_user_args()
 if args.size()!=3:quit(2);return
 mode=args[0];output=FileAccess.open(args[1],FileAccess.WRITE);trace=FileAccess.open(args[2],FileAccess.WRITE)
 db=BalanceCatalogue.load_prepared({"path":"res://content/full-content.json"})
 if db==null or output==null or trace==null:quit(2);return
 for aspect: int in [0,1]:
  for vow: int in [0,5]:
   for up: bool in [false,true]:
    for q: int in [0,4,5,6,9]:
     for context: String in ["plain","block","weak-vulnerable","lethal","fatal-thorns","shatter","no-energy"]:
      if mode=="legacy-mask":one(up,aspect,vow,q,context,false)
      elif mode in ["reference","legacy-query"]:one(up,aspect,vow,q,context,true)
      else:
       one(up,aspect,vow,q,context,false);one(up,aspect,vow,q,context,true)
 output.store_line(JSON.stringify({"kind":"terminal","cases":count}))
 output.close();trace.close();quit(0)
