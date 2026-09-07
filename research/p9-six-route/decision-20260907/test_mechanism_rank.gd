extends SceneTree
const Fixture: GDScript=preload("res://test_stock_ramp.gd")
var checks: int=0
var failures: int=0
func ck(ok: bool,note: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("MECHANISM_RANK "+note)
func outcome(helper: SceneTree,db: ContentDB,aspect: int,up: bool,id: String,s: int,b: int,h: int) -> int:
 var g: GlassvowGame=helper.game(db,aspect)
 g.cb.player.statuses["str"]=s;g.cb.embers=0
 var c: CardInst=CardInst.new(700,StringName(id),up);c.bonus=b
 g.cb.hand.append(c)
 for i: int in range(h):g.cb.hand.append(CardInst.new(800+i,&"defend"))
 var p: Variant=g.rules.preview_play(g.cb,c,0,g.run)
 g.apply({"t":"playCard","uid":700,"target":0})
 var n: int=1000-g.cb.enemies[0].hp
 ck(g.last_ret==true,"legal paid command")
 ck(n==int(p.total),"native preview match")
 ck(g.cb.player.energy==2,"energy held equal")
 return n
func _initialize() -> void:
 var args: PackedStringArray=OS.get_cmdline_user_args()
 if args.size()!=1:quit(2);return
 var db: ContentDB=ContentDB.load_from(args[0],true)
 var helper: SceneTree=Fixture.new();var results: Array=[]
 for aspect: int in [0,1]:
  for up: bool in [false,true]:
   var matrix: Array=[];var baseline: Array=[]
   for id: String in ["flurry","momentum","phantomBlades"]:
    var base: int=outcome(helper,db,aspect,up,id,0,0,4);baseline.append(base)
    matrix.append([outcome(helper,db,aspect,up,id,3,0,4)-base,
      outcome(helper,db,aspect,up,id,0,14,4)-base,
      outcome(helper,db,aspect,up,id,0,0,8)-base])
   # Bonus belongs to Momentum only; normal attacks do not read CardInst.bonus.
   var expected: Array=[[15,0,0],[3,14,0],[3,0,28 if up else 24]]
   ck(matrix==expected,"independent sensitivity matrix")
   results.append({"aspect":aspect,"upgraded":up,"baseline":baseline,"matrix":matrix})
 helper.free()
 print("MECHANISM_RANK_RESULT "+JSON.stringify(results))
 print("MECHANISM_RANK_CHECKS "+str(checks)+" FAILURES "+str(failures))
 quit(0 if failures==0 else 3)
