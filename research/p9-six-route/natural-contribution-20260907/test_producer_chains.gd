extends SceneTree
const Fixture: GDScript=preload("res://test_stock_ramp.gd")
const Diagnostic: GDScript=preload("res://diagnostic_rules.gd")
var checks: int=0
var failures: int=0
var path: String=""
func ck(ok: bool,note: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("CHAIN_TEST "+note)
func load_variant(kind: String,producer: bool) -> ContentDB:
 var db: ContentDB=ContentDB.load_from(path,true)
 if producer:return db
 var cid: String=str({"multihit":"empower","growth":"momentum","handstock":"nightSight","catalyst":"venomStrike","echo":"chisel"}[kind])
 var d: Dictionary=db.cards[cid].duplicate(true)
 for up: bool in [false,true]:
  var x: Dictionary=d.get("up",{}) if up else d
  if kind=="echo":x["chip"]=0
  for fx: Dictionary in x.get("effects",[]):
   if kind=="multihit" and fx.get("id")=="str":fx["n"]=0
   if kind=="growth" and fx.get("id")=="momentum":fx["grow"]=0
   if kind=="handstock" and fx.get("id")=="nightsight":fx["n"]=0
   if kind=="catalyst" and fx.get("id")=="poison":fx["n"]=0
 db.cards[cid]=d
 return db
func _initialize() -> void:
 var args: PackedStringArray=OS.get_cmdline_user_args()
 if args.size()!=1:quit(2);return
 path=args[0]
 var helper: SceneTree=Fixture.new();var report: Dictionary={}
 for kind: String in ["multihit","growth","handstock","catalyst","echo"]:
  for aspect: int in [0,1]:
   for up: bool in [false,true]:
    var values: Array=[]
    for p: bool in [false,true]:
     for c: bool in [false,true]:
      var db: ContentDB=load_variant(kind,p)
      var g: GlassvowGame=helper.game(db,aspect);g.rules=Diagnostic.new(db)
      var producer: String=str({"multihit":"empower","growth":"momentum","handstock":"nightSight","catalyst":"venomStrike","echo":"chisel"}[kind])
      var consumer: String=str({"multihit":"flurry","growth":"momentum","handstock":"phantomBlades","catalyst":"catalyst","echo":"resonantLance"}[kind])
      g.cb.hand.append(CardInst.new(900,StringName(producer),up))
      if kind=="echo":g.cb.enemies[0].facet_max=4;g.cb.enemies[0].chips=2
      if kind=="handstock":
       for j: int in range(7):g.cb.draw.append(CardInst.new(1000+j,&"defend"))
       g.cb.draw.append(CardInst.new(901,StringName(consumer),up))
      elif kind!="growth":g.cb.hand.append(CardInst.new(901,StringName(consumer),up))
      g.apply({"t":"playCard","uid":900,"target":null if kind in ["multihit","handstock"] else 0})
      ck(g.last_ret==true,"legal actual producer "+kind)
      if kind in ["growth","handstock"]:
       g.cb.enemies[0].staggered=true
       g.apply({"t":"endTurn"})
      var hp: int=g.cb.enemies[0].hp
      var poison: int=int(g.cb.enemies[0].statuses.get("poison",0))
      g.rules.erased_consumer="" if c else kind
      g.apply({"t":"playCard","uid":900 if kind=="growth" else 901,"target":0})
      ck(g.last_ret==true,"legal independently chosen consumer "+kind)
      var value: int=int(g.cb.enemies[0].statuses.get("poison",0))-poison if kind=="catalyst" else hp-g.cb.enemies[0].hp
      values.append(value)
      if kind=="catalyst" and aspect==0:ck(value==0,"Ash-only player poison")
      if kind=="growth":ck(value==(1 if up else 0)+(17 if up else 14)*int(p and c),"real same-instance growth after shuffle")
    var interaction: int=values[3]-values[2]-values[1]+values[0]
    var expected: int=0
    if kind=="multihit":expected=16 if up else 12
    if kind=="growth":expected=17 if up else 14
    if kind=="handstock":expected=7 if up else 6
    if kind=="catalyst" and aspect==1:expected=10 if up else 4
    if kind=="echo" and aspect==0:expected=15 if up else 11
    ck(interaction==expected,"independent chain interaction "+kind+" "+str(aspect)+" "+str(up)+" values "+str(values))
    report[kind+"-a"+str(aspect)+"-up"+str(up)]={"arms":values,"interaction":interaction}
 helper.free()
 print("CHAIN_RESULTS "+JSON.stringify(report))
 print("CHAIN_CHECKS "+str(checks)+" FAILURES "+str(failures))
 quit(0 if failures==0 else 3)
