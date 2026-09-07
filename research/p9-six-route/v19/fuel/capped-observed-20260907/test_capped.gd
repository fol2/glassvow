extends SceneTree
const Fixture: GDScript=preload("res://test_stock_ramp.gd")
var checks: int=0
var failures: int=0
func ck(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("CAPPED_TEST "+label)
func _initialize() -> void:
 var a: PackedStringArray=OS.get_cmdline_user_args()
 if a.size()!=1:quit(2);return
 var recipes: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(a[0]))
 var fixture: SceneTree=Fixture.new()
 for name: String in recipes:
  var db: ContentDB=ContentDB.load_from(recipes[name].path,true)
  ck(db!=null,"content valid")
  for aspect: int in [0,1]:
   for up: bool in [false,true]:
    for q: int in range(13):
     for lethal: bool in [false,true]:
      var g: GlassvowGame=fixture.game(db,aspect)
      g.cb.ember_cap=12;g.cb.embers=q
      var e: EnemyCombatant=g.cb.enemies[0]
      e.hp=1 if lethal else 1000
      var hp: int=e.hp;var old_spent: int=int(g.run.stats.get("embersSpent",0))
      var c: CardInst=CardInst.new(800,&"novaflare",up);g.cb.hand.append(c)
      var expected: int=(9 if up else 8)*mini(q,2)
      var preview: Dictionary=g.rules.preview_play(g.cb,c,0,g.run)
      var events: Array[Dictionary]=g.apply({"t":"playCard","uid":800,"target":0})
      ck(g.last_ret==true,"legal")
      ck(preview.total==expected,"independent preview formula")
      ck(hp-e.hp==mini(hp,expected),"actual health removal")
      ck(g.cb.embers==q-mini(q,2),"actual capped debit")
      ck(int(g.run.stats.get("embersSpent",0))-old_spent==mini(q,2),"spent statistics")
      ck(g.cb.player.energy==2,"one-energy opportunity cost")
      var debit_index: int=-1;var hit_index: int=-1
      for i: int in range(events.size()):
       if events[i].t==EventTypes.EMBER and int(events[i].get("n",0))<0:debit_index=i
       if events[i].t==EventTypes.HIT_ENEMY and hit_index<0:hit_index=i
      ck(q==0 or (debit_index>=0 and debit_index<hit_index),"debit before lethal/nonlethal hit")
 fixture.free()
 print("CAPPED_NATIVE_CHECKS "+str(checks)+" FAILURES "+str(failures))
 quit(0 if failures==0 else 3)
