extends SceneTree
const Fixture: GDScript=preload("res://test_stock_ramp.gd")
var checks: int=0
var failures: int=0
func ck(ok: bool,note: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("FERVOR_FACTORIAL "+note)
func _initialize() -> void:
 var args: PackedStringArray=OS.get_cmdline_user_args()
 if args.size()!=1:quit(2);return
 var records: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
 var helper: SceneTree=Fixture.new()
 var values: Dictionary={}
 for label: String in records:
  var spec: Dictionary=records[label]
  var db: ContentDB=ContentDB.load_from(str(spec.path),true)
  ck(db!=null,"valid content")
  for up: bool in [false,true]:
   for aspect: int in [0,1]:
    var g: GlassvowGame=helper.game(db,aspect)
    var strength: int=(4 if up else 3)*int(spec.producer)
    var hits: int=5 if spec.consumer else 1
    var base: int=5 if up else 0
    g.cb.hand.append(CardInst.new(701,&"empower",up))
    g.cb.hand.append(CardInst.new(702,&"flurry",up))
    g.apply({"t":"playCard","uid":701,"target":null})
    ck(g.last_ret==true and g.cb.player.energy==2,"paid producer")
    ck(int(g.cb.player.statuses.get("str",0))==strength,"real mediator")
    var preview: Variant=g.rules.preview_play(g.cb,g.cb.hand[0],0,g.run)
    var expected: int=base+hits*strength
    ck(preview.total==expected,"actual consumer preview")
    var events: Array[Dictionary]=g.apply({"t":"playCard","uid":702,"target":0})
    ck(g.last_ret==true and g.cb.player.energy==1,"paid consumer")
    ck(1000-g.cb.enemies[0].hp==expected,"native health removed")
    ck(g.cb.enemies[0].chips==(1 if aspect==0 and expected>0 else 0),"once-per-card and aspect rule")
    ck(g.cb.discard.size()==1,"same discard behavior")
    if aspect==1:values[label+('-up' if up else '-base')]=expected
 helper.free()
 ck(int(values['p1c1-base'])-int(values['p1c0-base'])-int(values['p0c1-base'])+int(values['p0c0-base'])==12,"base interaction")
 ck(int(values['p1c1-up'])-int(values['p1c0-up'])-int(values['p0c1-up'])+int(values['p0c0-up'])==16,"upgrade interaction")
 print("FERVOR_FACTORIAL_VALUES "+JSON.stringify(values))
 print("FERVOR_FACTORIAL_CHECKS "+str(checks)+" FAILURES "+str(failures))
 quit(0 if failures==0 else 3)
