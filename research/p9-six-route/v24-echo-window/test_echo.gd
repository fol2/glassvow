extends SceneTree
const Fixture: GDScript=preload("res://test_stock_ramp.gd")
const Policy: GDScript=preload("res://greedy_policy.gd")
var checks: int=0
var failures: int=0
func ck(ok: bool,note: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("ECHO_TEST "+note)
func _initialize() -> void:
 var args: PackedStringArray=OS.get_cmdline_user_args()
 if args.size()!=1:quit(2);return
 var arms: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
 var helper: SceneTree=Fixture.new()
 var factorial: Dictionary={}
 for label: String in arms:
  var db: ContentDB=ContentDB.load_from(arms[label].path,true)
  ck(db!=null,"valid content")
  for aspect: int in [0,1]:
   for up: bool in [false,true]:
    var game: GlassvowGame=helper.game(db,aspect)
    var enemy: EnemyCombatant=game.cb.enemies[0]
    enemy.facet_max=5 if up else 4
    var producer: CardInst=CardInst.new(700,&"quakeblow",up)
    var consumer: CardInst=CardInst.new(701,&"resonantLance",up)
    game.cb.hand.append(producer);game.cb.hand.append(consumer)
    game.apply({"t":"playCard","uid":700,"target":0})
    ck(game.last_ret,"producer legal")
    ck(game.cb.player.energy==1,"producer costs two")
    ck(enemy.staggered==(aspect==0 and bool(arms[label].supply)),"supply reaches actual Shatter")
    var pre: Variant=game.rules.preview_play(game.cb,consumer,0,game.run)
    ck(typeof(pre)==TYPE_DICTIONARY,"consumer preview exists")
    var hp: int=enemy.hp
    game.apply({"t":"playCard","uid":701,"target":0})
    ck(game.last_ret and game.cb.player.energy==0,"consumer fits three-energy sequence")
    var expected: int=10 if up else 7
    if aspect==0 and bool(arms[label].supply):
     expected=int(floorf(expected*(3 if bool(arms[label].payoff) else 2)*1.5))
    ck(hp-enemy.hp==expected,"actual conditional damage")
    ck(pre.total==expected and pre.loss==expected,"preview/execution")
    var total: int=1000-enemy.hp
    factorial[label+"-a"+str(aspect)+"-up"+str(up)]=total
    ck(int(game.run.stats.get("shatters",0))==(1 if aspect==0 else 0),"bundled Shatter unchanged")
    # Conditional bonus cannot leak to a Vulnerable-only target.
    for staggered: bool in [false,true]:
     for vulnerable: bool in [false,true]:
      for strength: int in [0,3]:
       for weak: bool in [false,true]:
        game=helper.game(db,aspect);enemy=game.cb.enemies[0]
        enemy.staggered=staggered
        if vulnerable:enemy.statuses["vulnerable"]=2
        game.cb.player.statuses["str"]=strength
        if weak:game.cb.player.statuses["weak"]=1
        consumer=CardInst.new(703,&"resonantLance",up);game.cb.hand.append(consumer)
        pre=game.rules.preview_play(game.cb,consumer,0,game.run)
        var multiplier: int=(3 if bool(arms[label].payoff) else 2) if staggered else (2 if vulnerable else 1)
        expected=(10 if up else 7)*multiplier+strength
        if weak:expected=int(floorf(expected*0.75))
        if vulnerable:expected=int(floorf(expected*1.5))
        var state: String=JSON.stringify([game.run.to_dict(),game.cb.to_dict()])
        var policy: RefCounted=Policy.new();policy.route="facet"
        policy.score(game,consumer,game.rules.card_data(consumer),0,false)
        ck(state==JSON.stringify([game.run.to_dict(),game.cb.to_dict()]),"valuation read only")
        game.apply({"t":"playCard","uid":703,"target":0})
        ck(game.last_ret,"consumer legal")
        ck(1000-enemy.hp==expected and pre.total==expected,"status-aware conditional law")
        ck(game.cb.player.energy==2,"same cost")
 var base: Array=[];var upgraded: Array=[]
 for key: String in ["supply0_payoff0","supply0_payoff1","supply1_payoff0","supply1_payoff1"]:
  base.append(factorial[key+"-a0-upfalse"]);upgraded.append(factorial[key+"-a0-uptrue"])
 ck(base==[15,15,29,39],"base factorial")
 ck(upgraded==[21,21,41,56],"upgraded factorial")
 print("ECHO_FACTORIAL "+JSON.stringify({"base":base,"upgraded":upgraded,"base_interaction":base[3]-base[2]-base[1]+base[0],"upgraded_interaction":upgraded[3]-upgraded[2]-upgraded[1]+upgraded[0]}))
 helper.free()
 print("ECHO_TESTS "+str(checks)+" FAILURES "+str(failures))
 quit(0 if failures==0 else 3)
