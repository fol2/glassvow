extends SceneTree
const Fixture: GDScript=preload("res://test_stock_ramp.gd")
var checks: int=0
var failures: int=0
func ck(ok: bool,note: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("SUBSTITUTION_TEST "+note)
func state(helper: SceneTree,db: ContentDB) -> GlassvowGame:
 var g: GlassvowGame=helper.game(db,1)
 g.cb.embers=0;g.cb.enemies[0].hp=20
 g.cb.hand.append(CardInst.new(701,&"empower",true))
 g.cb.hand.append(CardInst.new(702,&"flurry",true))
 g.cb.hand.append(CardInst.new(703,&"phantomBlades",true))
 g.cb.hand.append(CardInst.new(704,&"strike"))
 g.cb.hand.append(CardInst.new(705,&"defend"))
 g.cb.hand.append(CardInst.new(706,&"defend"))
 return g
func _initialize() -> void:
 var a: PackedStringArray=OS.get_cmdline_user_args()
 if a.size()!=1:quit(2);return
 var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(a[0]))
 var helper: SceneTree=Fixture.new();var results: Dictionary={}
 for label: String in manifest:
  var spec: Dictionary=manifest[label]
  var db: ContentDB=ContentDB.load_from(str(spec.path),true)
  var f: GlassvowGame=state(helper,db)
  f.apply({"t":"playCard","uid":701,"target":null});ck(f.last_ret==true,"paid Fervor producer")
  f.apply({"t":"playCard","uid":702,"target":0});ck(f.last_ret==true,"paid Fervor consumer")
  var fv: int=int(f.cb.over and f.cb.result=="win")
  ck(fv==int(spec.producer and spec.consumer),"Fervor sequence needs both components")
  var h: GlassvowGame=state(helper,db)
  h.apply({"t":"playCard","uid":703,"target":0});ck(h.last_ret==true,"paid hand-stock consumer")
  ck(h.cb.enemies[0].hp==5,"actual hand-stock damage15")
  h.apply({"t":"playCard","uid":704,"target":0});ck(h.last_ret==true,"paid finishing strike")
  var hv: int=int(h.cb.over and h.cb.result=="win")
  ck(hv==1,"alternative policy wins in every component arm")
  ck(f.cb.player.energy==1 and h.cb.player.energy==1,"equal two-energy opportunity budget")
  results[label]={"fervor_sequence_win":fv,"hand_sequence_win":hv,"optimal_win_value":maxi(fv,hv)}
 ck(results.p1c1.optimal_win_value-results.p1c0.optimal_win_value-results.p0c1.optimal_win_value+results.p0c0.optimal_win_value==0,"optimized win interaction is zero")
 helper.free()
 print("SUBSTITUTION_RESULT "+JSON.stringify(results))
 print("SUBSTITUTION_CHECKS "+str(checks)+" FAILURES "+str(failures))
 quit(0 if failures==0 else 3)
