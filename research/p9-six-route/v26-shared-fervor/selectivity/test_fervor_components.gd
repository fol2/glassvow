extends SceneTree
const Fixture:GDScript=preload("res://test_stock_ramp.gd")
var checks:int=0
var failures:int=0
func ck(ok:bool,note:String)->void:
 checks+=1
 if not ok:failures+=1;push_error("FERVOR_COMPONENT "+note)
func _initialize()->void:
 var args:PackedStringArray=OS.get_cmdline_user_args()
 if args.size()!=1:quit(2);return
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
 var fixture:SceneTree=Fixture.new()
 var payoffs:Dictionary={}
 for label:String in manifest:
  var spec:Dictionary=manifest[label]
  var db:ContentDB=ContentDB.load_from(str(spec.path),true)
  for up:bool in [false,true]:
   for external_str:int in [0,2]:
    var g:GlassvowGame=fixture.game(db,1)
    g.cb.player.statuses["str"]=external_str
    g.cb.hand.append(CardInst.new(901,&"empower",up));g.cb.hand.append(CardInst.new(902,&"flurry",up))
    var a:CardInst=g.cb.hand[0];var b:CardInst=g.cb.hand[1]
    var energy:int=g.cb.player.energy
    var expected_cost:int=g.rules.eff_cost(g.run,g.cb,a)+g.rules.eff_cost(g.run,g.cb,b)
    g.apply({"t":"playCard","uid":901,"target":null})
    ck(g.last_ret==true,"producer legal")
    var strength:int=external_str+(4 if up else 3)*int(spec.producer)
    ck(int(g.cb.player.statuses.get("str",0))==strength,"only declared supply changed")
    var hits:int=5 if spec.consumer else 1
    var damage:int=(5 if up else 0)+hits*strength
    var pv:Variant=g.rules.preview_play(g.cb,b,0,g.run)
    ck(pv.total==damage,"native preview")
    var before:int=g.cb.enemies[0].hp
    var events:Array[Dictionary]=g.apply({"t":"playCard","uid":902,"target":0})
    ck(g.last_ret==true,"consumer legal")
    ck(before-g.cb.enemies[0].hp==damage,"raw factorial independent formula")
    ck(g.cb.player.energy==energy-expected_cost,"same total energy")
    ck(g.cb.enemies[0].chips==0 and not g.cb.enemies[0].staggered,"Ash identity")
    var observed:int=0
    for ev:Dictionary in events:
     if ev.get("t")==EventTypes.HIT_ENEMY:observed+=1
    ck(observed==hits,"actual hit multiplicity")
    if external_str==0:payoffs[label+('-up' if up else '-base')]=damage
 for up:bool in [false,true]:
  var suffix:String='-up' if up else '-base'
  var interaction:int=int(payoffs['p1c1'+suffix])-int(payoffs['p1c0'+suffix])-int(payoffs['p0c1'+suffix])+int(payoffs['p0c0'+suffix])
  ck(interaction==(16 if up else 12),"true producer-consumer interaction")
 fixture.free()
 print('FERVOR_FACTORIAL '+JSON.stringify(payoffs))
 print('FERVOR_COMPONENT_CHECKS '+str(checks)+' FAILURES '+str(failures))
 quit(0 if failures==0 else 3)
