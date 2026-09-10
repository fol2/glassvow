extends SceneTree
## Fixed compatibility experiment, not package or policy-quality admission.
const Planner: GDScript = preload("res://lab_policy.gd")
const Clone: GDScript = preload("res://public_rollout.gd")
const OldClone: GDScript = preload("res://public_rollout_base.gd")
const PARAMETERS: Dictionary = {"bank_mode":"current-plus-next", "native_rollout":true, "rollout_samples":2, "rollout_steps":12, "leaf_terminal":false}
var output: FileAccess
var db: ContentDB
var mode: String
var failures: int = 0

func view(v: Variant) -> Variant:
 if v is Object:
  var d: Dictionary = {}
  for prop: Dictionary in v.get_property_list():
   if (int(prop.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0:
    d[str(prop.name)] = view(v.get(str(prop.name)))
  return d
 if v is Dictionary:
  var d: Dictionary = {}
  for k: Variant in v:d[str(k)] = view(v[k])
  return d
 if v is Array:
  var a: Array = []
  for item: Variant in v:a.append(view(item))
  return a
 if typeof(v) == TYPE_STRING_NAME:return str(v)
 return v

func state(g: GlassvowGame) -> Dictionary:
 return {"run":view(g.run), "combat":view(g.cb), "return":g.last_ret}

func public_frame(x: Dictionary) -> Dictionary:
 var n: Dictionary = x.duplicate(true)
 n.run.erase("rng"); n.run.erase("seed"); n.run.erase("run_id")
 n.combat["queue"] = []
 n.combat.draw.sort_custom(func(a: Dictionary,b: Dictionary)->bool: return JSON.stringify(a)<JSON.stringify(b))
 return n

func switches(g: GlassvowGame) -> Dictionary:
 var out: Dictionary = {}
 for prop: Dictionary in g.rules.get_property_list():
  if str(prop.name) in Clone.SWITCHES:out[str(prop.name)] = g.rules.get(str(prop.name))
 return out

func make_game(aspect: int, vow: int, upgraded: bool, pattern: int, modifiers: bool) -> GlassvowGame:
 var r: RunState = RunState.new_run(db,73400001,"planner-compatibility",{"aspect":aspect,"vow":vow,"reveals":db.reveal_ids.duplicate(),"unlocks":["aspect2"],"quests":{},"shards":[]})
 r.omens = [null,null,null]; r.player.relics.clear()
 var g: GlassvowGame = GlassvowGame.new(db,r)
 if mode != "baseline":
  g.rules.set("bloodfire_enabled",mode != "off")
  g.rules.set("bloodfire_producer_enabled",mode != "producer_off")
  g.rules.set("bloodfire_consumer_enabled",mode != "consumer_off")
 g.apply({"t":"startCombat","enemies":["sporeling"],"kind":"normal"})
 g.cb.affix = &"";g.cb.player.statuses={};g.cb.player.energy=2
 g.cb.player.hp=3 if pattern==2 else 24;g.cb.player.max_hp=70
 g.run.player.hp=g.cb.player.hp;g.run.player.max_hp=70;g.cb.player.block=0
 g.cb.hand.clear();g.cb.draw.clear();g.cb.discard.clear();g.cb.exhaust.clear()
 g.cb.art_used_turn=g.cb.turn;g.cb.kindled_turn=g.cb.turn;g.cb.kindles_this_turn=1
 var e: EnemyCombatant=g.cb.enemies[0]
 e.hp=24 if pattern==1 else 18;e.max_hp=e.hp;e.block=3 if modifiers else 0
 e.chips=0;e.facet_max=100;e.staggered=false;e.statuses={};e.flags={}
 e.def={"moves":{"attack":{"dmg":4,"intent":"attack"}}};e.move_key=&"attack"
 if modifiers:
  e.statuses["vulnerable"]=1;e.statuses["thorns"]=2;g.cb.player.statuses["weak"]=1
 var hand: Array[String]=["bloodRite","leechBlade","strike"]
 if pattern==1:hand=["preparation","phantomBlades","bloodRite","leechBlade"]
 var uid: int=100
 r.player.deck.clear()
 for id: String in hand:
  g.cb.hand.append(CardInst.new(uid,StringName(id),upgraded));r.player.deck.append(CardInst.new(uid,StringName(id),upgraded));uid+=1
 for id: String in ["defend","strike","preparation"]:
  g.cb.draw.append(CardInst.new(uid,StringName(id)));r.player.deck.append(CardInst.new(uid,StringName(id)));uid+=1
 g.cb.player.statuses["bloodfire"]=1 if pattern==1 else 0
 g.cb.queue.clear();g.last_ret=null
 return g

func choose(g: GlassvowGame, route: String) -> Dictionary:
 var p: RefCounted=Planner.new();p.route=route;p.params=PARAMETERS.duplicate(true)
 var choices: Array[Dictionary]=p.actions(g)
 var action: Dictionary=p.choose_action(g)
 var normal: Dictionary={"t":"endTurn"} if action.is_empty() else action
 return {"action":normal,"alternatives":p.last_alternatives.duplicate(true),"legal_candidates":choices,"root_rollouts":p.rollout_count}

func emit(x: Dictionary) -> void:
 output.store_line(JSON.stringify(x));output.flush()

func check_case(aspect: int,vow: int,upgraded: bool,pattern: int,modifiers: bool,route: String) -> void:
 var g: GlassvowGame=make_game(aspect,vow,upgraded,pattern,modifiers)
 var before: Dictionary=state(g)
 var content_before: String=JSON.stringify(view(g.content)).sha256_text()
 var flags_before: Dictionary=switches(g)
 var normal: Dictionary=choose(g,route)
 var after: Dictionary=state(g)
 var model: GlassvowGame=Clone.clone_public(g,0)
 var original_clone: GlassvowGame=OldClone.clone_public(g,0)
 var clone_before: Dictionary=state(model)
 var flags: Dictionary=switches(g)
 var clone_flags: Dictionary=switches(model)
 var old_flags: Dictionary=switches(original_clone)
 var frame: Dictionary=public_frame(before)
 var same_clone_frame: bool=frame==public_frame(clone_before)
 var hidden_input: Dictionary=before.duplicate(true)
 g.cb.draw.reverse();g.run.seed=987654321;g.run.run_id="unobservable-label"
 g.run.rng.next();g.run.rng.next()
 var permuted_before: Dictionary=state(g)
 var permuted: Dictionary=choose(g,route)
 var permuted_after: Dictionary=state(g)
 var content_after: String=JSON.stringify(view(g.content)).sha256_text()
 var flags_after: Dictionary=switches(g)
 var same_public: bool=frame==public_frame(permuted_before)
 var cloned_hidden: Dictionary=state(Clone.clone_public(g,0))
 var action: Dictionary=normal.action
 var native_events: Array[Dictionary]=model.apply(action)
 var native_after: Dictionary=state(model)
 var legal: bool=normal.legal_candidates.has(action)
 var paid_play_succeeded: bool=action.t!="playCard" or model.last_ret==true
 var avoid_suicide: bool=not (pattern==2 and action.t=="playCard" and int(action.uid)==100)
 var checks: Dictionary={"live_state_unchanged":before==after,"second_query_unchanged":permuted_before==permuted_after,
  "public_frame_retained":same_clone_frame,"hidden_change_is_private":same_public,
  "hidden_input_independent":normal==permuted,"same_public_determinization":clone_before==cloned_hidden,
  "intervention_flags_retained":flags==clone_flags,"legal_action":legal,"paid_play_succeeded":paid_play_succeeded,
  "does_not_choose_known_fatal_source":avoid_suicide,
  "fixed_two_samples":int(normal.root_rollouts)==normal.legal_candidates.size()*2,
  "content_readonly":content_before==content_after,"rule_switches_readonly":flags_before==flags_after}
 for key: String in checks:
  if not checks[key]:failures+=1
 emit({"kind":"case","mode":mode,"aspect":aspect,"vow":vow,"upgraded":upgraded,"pattern":pattern,"modifiers":modifiers,"route":route,
  "checks":checks,"before":hidden_input,"after_query":after,"permuted_before":permuted_before,"permuted_after":permuted_after,
  "decision":normal,"permuted_decision":permuted,"clone_before":clone_before,"clone_after":native_after,"events":native_events,
  "flags":flags,"clone_flags":clone_flags,"unadapted_flags":old_flags,"clone_hidden":cloned_hidden,
  "flags_before":flags_before,"flags_after":flags_after,"content_before":content_before,"content_after":content_after})

func _initialize() -> void:
 var args: PackedStringArray=OS.get_cmdline_user_args()
 if args.size()!=2:quit(2);return
 mode=args[0];db=ContentDB.load_full(true);output=FileAccess.open(args[1],FileAccess.WRITE)
 if db==null or output==null:quit(2);return
 emit({"kind":"header","mode":mode,"engine":Engine.get_version_info()["string"],"params":PARAMETERS,
  "content_sha256":FileAccess.get_sha256("res://content/full-content.json"),"combat_sha256":FileAccess.get_sha256("res://domain/rules/combat.gd")})
 for aspect: int in [0,1]:
  for vow: int in [0,5]:
   for upgraded: bool in [false,true]:
    for pattern: int in [0,1,2]:
     for modifiers: bool in [false,true]:
      for route: String in ["balanced","hand"]:check_case(aspect,vow,upgraded,pattern,modifiers,route)
 emit({"kind":"terminal","cases":96,"failed_checks":failures})
 output.close();quit(0 if failures==0 else 3)
