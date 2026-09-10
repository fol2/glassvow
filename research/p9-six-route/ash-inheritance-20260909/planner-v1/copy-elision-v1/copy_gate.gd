extends SceneTree
## Pure score/draft comparison, including all authored cards and converter sentinels.
const Driver: GDScript=preload("res://greedy_policy.gd")
const Observe: GDScript=preload("res://observed_game.gd")
var output: FileAccess
var count: int=0
var failures: int=0

func query(g: GlassvowGame,p: RefCounted,id: String,d: Dictionary,up: bool,context: int) -> void:
 var card: CardInst=CardInst.new(99999,StringName(id if g.content.cards.has(id) else "strike"),up)
 var before: Dictionary=Observe.snapshot(g)
 var original: String=JSON.stringify(d)
 var target: Variant=0 if str(d.get("target",""))=="enemy" else null
 var score: float=p.score(g,card,d,target,false)
 var draft: float=p.draft(g,d,id,false)
 var same: bool=original==JSON.stringify(d) and before==Observe.snapshot(g)
 if not same:failures+=1
 output.store_line(JSON.stringify({"kind":"query","context":context,"id":id,"up":up,"score":score,"draft":draft,"input_unchanged":same}))
 count+=1

func _initialize() -> void:
 var args: PackedStringArray=OS.get_cmdline_user_args()
 if args.size()!=1:quit(2);return
 output=FileAccess.open(args[0],FileAccess.WRITE)
 var db: ContentDB=ContentDB.load_full(true)
 if output==null or db==null:quit(2);return
 var extras: Array[Dictionary]=[
  {"type":"skill","cost":1,"target":"self","effects":[{"kind":"special","id":"heldEmberWard","n":2,"per":3,"reserve":4}]},
  {"type":"skill","cost":1,"target":"enemy","effects":[{"kind":"special","id":"catalyst","n":2,"bonus":3}]},
  {"type":"attack","cost":1,"target":"enemy","effects":[{"kind":"special","id":"phantom","n":2,"reserve":2}]},
  {"type":"attack","cost":1,"target":"enemy","effects":[{"kind":"special","id":"emberNova","n":4,"reserve":2}]},
  {"type":"skill","cost":1,"target":"self","effects":[{"kind":"block","n":4}]}]
 output.store_line(JSON.stringify({"kind":"header","authored_cards":db.cards.size(),"contexts":8,"extras":extras.size()}))
 for context: int in range(8):
  var run: RunState=RunState.new_run(db,73409010,"copy-query-proof",{"aspect":context%2,"vow":5,"reveals":db.reveal_ids.duplicate(),"unlocks":["aspect2"],"quests":{},"shards":[]})
  run.omens=[null,null,null]
  var g: GlassvowGame=GlassvowGame.new(db,run)
  g.apply({"t":"startCombat","enemies":["sporeling"],"kind":"normal"})
  g.cb.player.energy=3;g.cb.player.hp=20+context;g.cb.player.max_hp=100;g.cb.embers=context
  g.cb.player.statuses={"str":context%3,"weak":context%2,"nightsight":1}
  g.cb.enemies[0].hp=50;g.cb.enemies[0].max_hp=50;g.cb.enemies[0].block=context
  g.cb.enemies[0].statuses={"poison":2+context,"vulnerable":context%2}
  var p: RefCounted=Driver.new();p.route=["balanced","hand","ember","fervor"][context%4]
  p.params={"bank_mode":"current-plus-next"}
  output.store_line(JSON.stringify({"kind":"state","context":context,"state":Observe.snapshot(g)}))
  for id: String in db.cards:
   for up: bool in [false,true]:
    var card: CardInst=CardInst.new(99999,StringName(id),up)
    query(g,p,id,g.rules.card_data(card),up,context)
  for i: int in range(extras.size()):query(g,p,"banklight" if i==4 else "synthetic-"+str(i),extras[i].duplicate(true),false,context)
 output.store_line(JSON.stringify({"kind":"terminal","cases":count,"failures":failures}))
 output.close();quit(0 if failures==0 else 3)
