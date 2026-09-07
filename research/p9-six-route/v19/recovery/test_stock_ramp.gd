extends SceneTree
const Greedy: GDScript=preload("res://greedy_policy.gd")
var tests: int=0
var failed: int=0
func ck(ok: bool,note: String) -> void:
 tests+=1
 if not ok:failed+=1;push_error("RAMP_TEST "+note)
func game(db: ContentDB,aspect: int) -> GlassvowGame:
 var r: RunState=RunState.new_run(db,23000001,"ramp-fixture",{"aspect":aspect,"vow":0,"reveals":db.reveal_ids.duplicate(),"unlocks":["aspect2"],"quests":{},"shards":[]})
 r.omens=[null,null,null];r.player.relics.clear()
 var g: GlassvowGame=GlassvowGame.new(db,r)
 g.apply({"t":"startCombat","enemies":["sporeling"],"kind":"normal","affix":null})
 g.cb.affix=&"";g.cb.player.statuses={};g.cb.player.energy=3;g.cb.player.block=0
 g.cb.hand.clear();g.cb.draw.clear();g.cb.discard.clear();g.cb.exhaust.clear()
 var e: EnemyCombatant=g.cb.enemies[0]
 e.hp=1000;e.max_hp=1000;e.block=0;e.chips=0;e.facet_max=1000;e.statuses={};e.flags={};e.staggered=false
 return g
func _initialize() -> void:
 var args: PackedStringArray=OS.get_cmdline_user_args()
 if args.size()!=1:quit(2);return
 var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
 for label: String in manifest:
  var db: ContentDB=ContentDB.load_from(str(manifest[label].path),true)
  ck(db!=null,"content valid "+label)
  if db==null:continue
  for aspect: int in [0,1]:
   for upgraded: bool in [false,true]:
    for stock: int in range(13):
     for cid: String in ["novaflare","phantomBlades","banklight"]:
      var g: GlassvowGame=game(db,aspect)
      var c: CardInst=CardInst.new(800,&"novaflare",upgraded);c.id=StringName(cid)
      g.cb.hand.append(c);g.cb.embers=stock
      if cid=="phantomBlades":
       for j: int in range(stock):g.cb.hand.append(CardInst.new(900+j,&"strike"))
      var d: Dictionary=g.rules.card_data(c);var fx: Dictionary=d.effects[0]
      var target: Variant=null if cid=="banklight" else 0
      var expected: int=0
      if cid=="banklight":expected=int(fx.n)+int(fx.per)*maxi(0,stock-int(fx.reserve))
      else:
       expected=int(fx.n)*maxi(0,stock-int(fx.get("reserve",0)))+int(fx.get("floor_per",0))*mini(stock,int(fx.get("reserve",0)))
       ck(Greedy.g_payoff(stock,fx)==expected,"pure/native formula")
      var pv: Variant=g.rules.preview_play(g.cb,c,target,g.run)
      var before: String=JSON.stringify([g.cb.to_dict(),g.run.to_dict()])
      var policy: RefCounted=Greedy.new();policy.route="ember";policy.params={"bank_mode":"current-plus-next"}
      policy.score(g,c,d,target,false)
      ck(before==JSON.stringify([g.cb.to_dict(),g.run.to_dict()]),"evaluation read only")
      g.apply({"t":"playCard","uid":800,"target":target})
      ck(g.last_ret==true,"legal play")
      ck(g.cb.embers==stock,"held resources unchanged")
      ck(g.cb.player.energy==3-g.rules.eff_cost(g.run,g.cb,c),"paid energy")
      if cid=="banklight":
       ck(g.cb.player.block==expected,"Ward raw formula")
       ck(pv.block==expected,"Ward preview")
      else:
       ck(1000-g.cb.enemies[0].hp==expected,"damage raw formula")
       ck(pv.total==expected,"damage preview")
       ck(g.cb.enemies[0].chips==(1 if aspect==0 and expected>0 else 0),"implicit-chip identity")
 var db: ContentDB=ContentDB.load_from(str(manifest.values()[0].path),true)
 var g: GlassvowGame=game(db,1)
 ck(g.cb.ember_cap==9,"native default cap")
 var pdef: Dictionary=db.cards.preparation.duplicate(true);pdef.merge(pdef.up,true)
 ck(pdef.exhaust==true and int(pdef.effects[0].n)==3,"finite Preparation upgrade")
 print("STOCK_RAMP_TESTS "+str(tests)+" FAILURES "+str(failed))
 quit(0 if failed==0 else 3)
