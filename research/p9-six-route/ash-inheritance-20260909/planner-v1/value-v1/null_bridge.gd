extends SceneTree
const Sim: GDScript=preload("res://tools/observed_sim.gd")
const Stock: GDScript=preload("res://tools/balance_sim.gd")
const Bridge: GDScript=preload("res://combat_bridge.gd")
const Observer: GDScript=preload("res://observed_game.gd")
func _initialize() -> void:
 var args: PackedStringArray=OS.get_cmdline_user_args()
 if args.size()!=2:quit(2);return
 var output: FileAccess=FileAccess.open(args[0],FileAccess.WRITE)
 var trace: FileAccess=FileAccess.open(args[1],FileAccess.WRITE)
 var db: ContentDB=BalanceCatalogue.load_prepared({"path":"res://content/full-content.json"})
 var count: int=0;var fail: int=0
 for aspect: String in ["duskblade","ashwarden"]:
  for vow: int in [0,5]:
   for random_flags: Array in [[true,false],[false,true]]:
    var key: String="null:%d" % count
    Observer.begin(key,trace);Bridge.reset();Bridge.enabled=true
    var actual: Dictionary=Sim.simulate(db,aspect,73410001,vow,PackedStringArray(),{},random_flags[0],random_flags[1])
    var original: Dictionary=Stock.simulate(db,aspect,73410001,vow,PackedStringArray(),{},random_flags[0],random_flags[1])
    var equal: bool=actual==original and Bridge.queries==0 and Bridge.faults.is_empty()
    output.store_line(JSON.stringify({"key":key,"aspect":aspect,"vow":vow,"random_flags":random_flags,"actual":actual,"original":original,"planner_queries":Bridge.queries,"equal":equal}));output.flush()
    if not equal:fail+=1
    count+=1
 output.store_line(JSON.stringify({"kind":"terminal","pairs":count,"failures":fail}));output.close();trace.close();quit(0 if fail==0 else 3)
