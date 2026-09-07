extends SceneTree
const Fixture: GDScript=preload("res://test_stock_ramp.gd")
var checks: int=0
var failures: int=0
func ck(ok: bool,note: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("SPECIFICITY_TEST "+note)
func _initialize() -> void:
 var args: PackedStringArray=OS.get_cmdline_user_args()
 if args.size()!=1:quit(2);return
 var records: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
 var helper: SceneTree=Fixture.new()
 var four_turn: Dictionary={}
 for label: String in records:
  var spec: Dictionary=records[label]
  var db: ContentDB=ContentDB.load_from(str(spec.path),true)
  ck(db!=null,"load")
  for up: bool in [false,true]:
   var flow: int=(3 if up else 2)*int(spec.producer)
   for aspect: int in [0,1]:
    var setup: GlassvowGame=helper.game(db,aspect)
    setup.cb.embers=0
    var power: CardInst=CardInst.new(701,&"pyreheart",up)
    setup.cb.hand.append(power)
    setup.apply({"t":"playCard","uid":701,"target":null})
    ck(setup.last_ret==true and setup.cb.player.energy==2,"same paid setup")
    ck(int(setup.cb.player.statuses.get("emberflow",0))==flow,"actual producer status")
    ck(setup.cb.embers==0,"power is not an immediate fuel grant")
    for stock: int in range(13):
     for strength: int in [0,3]:
      var g: GlassvowGame=helper.game(db,aspect)
      g.cb.ember_cap=12;g.cb.embers=stock;g.cb.player.statuses["str"]=strength
      var card: CardInst=CardInst.new(700,&"novaflare",up)
      g.cb.hand.append(card)
      var raw: int=(9 if up else 8)*mini(stock,2)*int(spec.consumer)
      var preview: Variant=g.rules.preview_play(g.cb,card,0,g.run)
      ck(preview.total==raw+strength,"preview actual payoff plus unchanged strength")
      g.apply({"t":"playCard","uid":700,"target":0})
      ck(g.last_ret==true and g.cb.player.energy==3,"same legal zero-energy action")
      ck(g.cb.enemies[0].hp==1000-raw-strength,"selective health effect")
      ck(g.cb.embers==stock-mini(stock,2),"same fuel debit in null")
      ck(int(g.run.stats.get("embersSpent",0))==mini(stock,2),"actual spent statistics")
      ck(g.cb.discard.size()==1 and g.cb.hand.is_empty(),"same discard/no draw")
   var h: GlassvowGame=helper.game(db,1);h.cb.embers=2
   h.cb.hand.append(CardInst.new(701,&"pyreheart",up));h.cb.hand.append(CardInst.new(700,&"novaflare",up))
   h.apply({"t":"playCard","uid":701,"target":null})
   for turn: int in range(4):
    h.apply({"t":"playCard","uid":700,"target":0})
    ck(h.last_ret==true,"four-turn legal same-instance consumer")
    if turn<3:
     h.cb.enemies[0].staggered=true
     h.apply({"t":"endTurn"})
   var expected: int=(9 if up else 8)*2*(4 if spec.producer else 1)*int(spec.consumer)
   ck(1000-h.cb.enemies[0].hp==expected,"four-turn source algebra")
   four_turn[label+('-up' if up else '-base')]=1000-h.cb.enemies[0].hp
 print("SPECIFICITY_FOUR_TURN "+JSON.stringify(four_turn))
 helper.free()
 print("SPECIFICITY_CHECKS "+str(checks)+" FAILURES "+str(failures))
 quit(0 if failures==0 else 3)
