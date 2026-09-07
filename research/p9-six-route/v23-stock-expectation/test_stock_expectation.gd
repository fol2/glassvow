extends SceneTree
const Distribution: GDScript = preload("res://stock_distribution.gd")
const Reference: GDScript = preload("res://greedy_fuel_reference.gd")
const Candidate: GDScript = preload("res://greedy_policy.gd")
const Fixture: GDScript = preload("res://test_stock_ramp.gd")
var assertions: int = 0
var failures: int = 0
func check(ok: bool, note: String) -> void:
 assertions += 1
 if not ok:
  failures += 1
  push_error("STOCK_EXPECTATION_FAIL " + note)
func near(a: float,b: float) -> bool:
 return absf(a-b)<0.0000001
func _initialize() -> void:
 var hard: Dictionary={"id":"emberNova","n":8,"reserve":4}
 var capped: Dictionary={"id":"emberNova","n":0,"reserve":2,"floor_per":8}
 var mix: Array[float]=[0.5,0,0,0,0,0,0,0,0.5]
 check(near(Distribution.raw_value(4,hard),0),"mean plug-in hard")
 check(near(Distribution.expected(mix,hard),16),"exact mixture hard")
 check(near(Distribution.raw_value(4,capped),16),"mean plug-in capped")
 check(near(Distribution.expected(mix,capped),8),"exact mixture capped reverses ranking")
 var ward: Dictionary={"id":"heldEmberWard","n":2,"reserve":4,"per":3}
 var sparse: Array[float]=[0,0,0,23.0/40,0,17.0/40]
 check(near(Distribution.expected(sparse,ward),3.275),"banklight expected versus 2 plug-in")
 for capacity: int in [9,12]:
  for step: int in range(capacity*4+1):
   var mean_stock: float=step/4.0
   var mass: Array[float]=Distribution.binomial(mean_stock,capacity)
   var total: float=0;var mu: float=0
   for q: int in range(mass.size()):total+=mass[q];mu+=q*mass[q]
   check(near(total,1),"normalized")
   check(near(mu,mean_stock),"same input mean")
   check(Distribution.expected(mass,hard)+0.0000001>=Distribution.raw_value(mean_stock,hard),"convex sign")
   check(Distribution.expected(mass,capped)-0.0000001<=Distribution.raw_value(mean_stock,capped),"concave sign")
 var args: PackedStringArray=OS.get_cmdline_user_args()
 if args.size()!=1:quit(2);return
 var db: ContentDB=ContentDB.load_from(args[0],true)
 var fixture: SceneTree=Fixture.new()
 var probes: Array=[]
 for aspect: int in [0,1]:
  for route: String in ["facet","fervor","cycle","smolder","hand","ember","balanced"]:
   var game: GlassvowGame=fixture.game(db,aspect)
   var before: String=JSON.stringify([game.run.to_dict(),game.cb.to_dict(),game.run.rng_state(),db.cards])
   var ref: RefCounted=Reference.new();ref.route=route
   var candidate: RefCounted=Candidate.new();candidate.route=route;candidate.params={"stock_aggregation":"mean"}
   for cid: String in db.cards:
    var d: Dictionary=db.cards[cid]
    check(near(candidate.draft(game,d,cid),ref.draft(game,d,cid)),"baseline exact draft "+cid)
   check(before==JSON.stringify([game.run.to_dict(),game.cb.to_dict(),game.run.rng_state(),db.cards]),"reference and candidate read only")
   candidate.params.stock_aggregation="expectation"
   for cid: String in ["novaflare","phantomBlades","banklight"]:
    var d: Dictionary=db.cards[cid];var fx: Dictionary=d.effects[0]
    var forecast: Dictionary=candidate.stock_forecast(game,str(fx.id))
    var plugin: float=Distribution.raw_value(forecast.mean,fx)
    var expected: float=Distribution.expected(forecast.mass,fx)
    var delta: float=0.9*(expected-float(int(plugin))) if cid=="banklight" else expected-plugin
    check(near(candidate.draft(game,d,cid)-ref.draft(game,d,cid),delta),"actual adapter payoff replacement")
    if aspect==1 and route=="ember":probes.append({"id":cid,"mean":forecast.mean,"old_score":ref.draft(game,d,cid),"expected_score":candidate.draft(game,d,cid),"payoff_mean":plugin,"payoff_expected":expected})
   check(before==JSON.stringify([game.run.to_dict(),game.cb.to_dict(),game.run.rng_state(),db.cards]),"expectation read only")
 fixture.free()
 print("STOCK_EXPECTATION_PROBES "+JSON.stringify(probes))
 print("STOCK_EXPECTATION_TESTS "+str(assertions)+" FAILURES "+str(failures))
 quit(0 if failures==0 else 3)
