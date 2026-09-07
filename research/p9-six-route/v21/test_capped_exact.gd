extends SceneTree
const Fixture: GDScript=preload("res://test_stock_ramp.gd")
var n: int=0
var failures: int=0
func ck(ok: bool,label: String) -> void:
 n+=1
 if not ok:failures+=1;push_error("CAPPED_TEST "+label)
func _initialize() -> void:
 var args: PackedStringArray=OS.get_cmdline_user_args()
 if args.size()!=1:quit(2);return
 var defs: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
 var f: SceneTree=Fixture.new()
 for label: String in defs:
  var db: ContentDB=ContentDB.load_from(defs[label].path,true)
  ck(db!=null,"content valid")
  for aspect: int in [0,1]:
   for up: bool in [false,true]:
    for q: int in range(13):
     for lethal: bool in [false,true]:
      var g: GlassvowGame=f.game(db,aspect);g.cb.ember_cap=12;g.cb.embers=q
      var c: CardInst=CardInst.new(800,&"novaflare",up);g.cb.hand.append(c)
      var enemy: EnemyCombatant=g.cb.enemies[0]
      if lethal and q>0:enemy.hp=1;enemy.max_hp=1
      var hp: int=enemy.hp;var energy: int=g.cb.player.energy
      var expected: int=(9 if up else 8)*mini(q,2)
      var preview: Dictionary=g.rules.preview_play(g.cb,c,0,g.run)
      var damage: int=0
      for hit: Dictionary in preview.get("hits",[]):damage+=int(hit.dmg)*int(hit.times)
      ck(damage==expected,"preview formula")
      var events: Array[Dictionary]=g.apply({"t":"playCard","uid":c.uid,"target":0})
      var nominal: int=0
      for ev: Dictionary in events:
       if ev.get("t")==EventTypes.HIT_ENEMY:nominal+=int(ev.get("amount",0))
      ck(nominal==expected,"nominal raw damage")
      ck(g.last_ret==true,"legal paid play")
      ck(hp-enemy.hp==mini(hp,expected),"clipped actual health removed")
      ck(g.cb.embers==q-mini(q,2),"fuel debit before lethal")
      ck(g.cb.player.energy==energy-1,"paid energy")
      ck(int(g.run.stats.get("embersSpent",0))==mini(q,2),"actual debit accounting")
 f.free()
 print("CAPPED_TESTS "+str(n)+" FAILURES "+str(failures))
 quit(0 if failures==0 else 3)
