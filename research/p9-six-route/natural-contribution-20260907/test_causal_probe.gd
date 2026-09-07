extends SceneTree
const Fixture: GDScript=preload("res://test_stock_ramp.gd")
const Probe: GDScript=preload("res://causal_probe.gd")
var checks: int=0
var failures: int=0
func ck(ok: bool,note: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("CAUSAL_TEST "+note)
func _initialize() -> void:
 var args: PackedStringArray=OS.get_cmdline_user_args()
 if args.size()!=1:quit(2);return
 var db: ContentDB=ContentDB.load_from(args[0],true)
 if db==null:quit(3);return
 var helper: SceneTree=Fixture.new()
 var roles: Dictionary={"flurry":"multihit","momentum":"growth","phantomBlades":"handstock","catalyst":"catalyst","chisel":"chip_supply","resonantLance":"echo"}
 for a: int in [0,1]:
  for up: bool in [false,true]:
   for active: bool in [false,true]:
    for cid: String in roles:
     var g: GlassvowGame=helper.game(db,a)
     var inst: CardInst=CardInst.new(900,StringName(cid),up)
     g.cb.hand.append(inst)
     if cid=="flurry":g.cb.player.statuses["str"]=3 if active else 0
     if cid=="momentum":inst.bonus=14 if active else 0
     if cid=="phantomBlades":
      for i: int in range(6 if active else 4):g.cb.hand.append(CardInst.new(1000+i,&"defend"))
     if cid=="catalyst":g.cb.enemies[0].statuses["poison"]=3 if active else 0
     if cid=="chisel":g.cb.enemies[0].facet_max=4;g.cb.enemies[0].chips=2 if active else 0
     if cid=="resonantLance":g.cb.enemies[0].staggered=active
     # Exercise queued-history exclusion and shared state without hiding a mismatch.
     var cmd: Dictionary={"t":"playCard","uid":900,"target":0}
     ck(Probe.role(g,cmd)==roles[cid],"real source role "+cid)
     var before: String=Probe.fingerprint(g);var old_queue: String=JSON.stringify(g.cb.queue)
     var sample: Dictionary=Probe.sample(g,cmd)
     ck(sample.get("ok",false),"capture "+cid+" "+str(sample.get("reason","")))
     if not sample.get("ok",false):continue
     ck(before==Probe.fingerprint(g) and old_queue==JSON.stringify(g.cb.queue),"noninterference "+cid)
     var expected: Array=[0,0,0,0]
     if active:
      if cid=="flurry":expected=[12,12,0,0]
      if cid=="momentum":expected=[14,14,0,0]
      if cid=="phantomBlades":expected=[14 if up else 12,14 if up else 12,0,0]
      if cid=="catalyst" and a==1:expected=[0,0,6 if up else 3,0]
      if cid=="chisel" and a==0:expected=[0,0,0,1]
      if cid=="resonantLance":expected=[10 if up else 7,10 if up else 7,0,0]
     ck(sample.record.interaction==expected,"independent formula "+cid+" a"+str(a)+" up"+str(up)+" active"+str(active)+" "+str(sample.record.interaction))
     var events: Array[Dictionary]=g.apply(cmd)
     ck(Probe.verify_factual(g,events,sample),"live factual events/state equality "+cid)
     # Factual result must reject a changed return or event, not only accept itself.
     g.last_ret=false
     ck(not Probe.verify_factual(g,events,sample),"ret corruption rejected")
 # Saturation: nominal interaction can survive while immediate HP interaction is zero.
 var saturated: GlassvowGame=helper.game(db,1)
 saturated.cb.enemies[0].hp=1;saturated.cb.player.statuses["str"]=3
 saturated.cb.hand.append(CardInst.new(900,&"flurry",true))
 var sat: Dictionary=Probe.sample(saturated,{"t":"playCard","uid":900,"target":0})
 ck(sat.get("ok",false),"saturation captured")
 ck(sat.record.interaction[0]==0,"HP cap is not mislabelled absent raw effect")
 var live: Array[Dictionary]=saturated.apply({"t":"playCard","uid":900,"target":0})
 ck(Probe.verify_factual(saturated,live,sat),"lethal exact clone equality")
 helper.free()
 print("CAUSAL_CHECKS "+str(checks)+" FAILURES "+str(failures))
 quit(0 if failures==0 else 3)
