extends RefCounted
## Research policy. No hidden draw order or live RNG state is inspected.
var route: String="balanced"
var random_build: bool=false
var random_play: bool=false
var params: Dictionary={}
var _turn_key: String=""
var _draw_seen: Dictionary={}
var repeat_draw_avoided: int=0
# Information-set policy memory, not a claim of complete runtime-state equivalence.
# It does not inspect the RNG state or the hidden draw-pile order.
func visible_draw_key(g: GlassvowGame) -> String:
 var h: Array=[]
 for c: CardInst in g.cb.hand:h.append([c.uid,String(c.id),c.up,c.bonus])
 h.sort_custom(func(a: Array,b: Array)->bool:return a[0]<b[0])
 var es: Array=[]
 for e: EnemyCombatant in g.cb.enemies:es.append([e.idx,e.hp,e.block,e.chips,e.facet_max,e.staggered,e.statuses])
 var useful_block: float=g.cb.player.block if si(g.cb.player.statuses,"barricade")>0 else minf(g.cb.player.block,incoming(g))
 return JSON.stringify([h,g.cb.player.hp,g.cb.player.energy,useful_block,g.cb.player.statuses,g.cb.embers,g.cb.draw.size(),g.cb.discard.size(),es])
func pure_draw(d: Dictionary) -> bool:
 var effects: Array=d.get("effects",[])
 if effects.is_empty():return false
 for fx: Dictionary in effects:
  if str(fx.get("kind",""))!="draw":return false
 return true
const FIT: Dictionary={
 "facet":{"chisel":8,"quakeblow":12,"resonantLance":10,"uppercut":7,"limitBreak":10,"warCry":6,"executioner":6},
 "fervor":{"empower":14,"flurry":13,"twinFangs":7,"tempest":7,"risingLitany":10,"frenzy":4},
 "cycle":{"momentum":18,"preparation":10,"quickSlash":6,"deflect":5,"nightSight":6},
 "smolder":{"venomStrike":7,"toxicMist":10,"ashenChoir":8,"catalyst":17,"virulence":9,"annihilate":5,"smother":4},
 "hand":{"phantomBlades":18,"preparation":10,"nightSight":12,"surge":7,"deflect":5,"quickSlash":3},
 "ember":{"novaflare":18,"tithe":12,"pyreheart":14,"emberdance":5,"firstSpark":3},"balanced":{}}
func ji(v: Variant) -> int:return int(float(str(v)))
func si(d: Dictionary,k: String) -> int:return ji(d.get(k,0))
func copies(g: GlassvowGame,id: String) -> int:
 var n: int=0
 for c: CardInst in g.run.player.deck:
  if String(c.id)==id:n+=1
 return n
func threat(g: GlassvowGame,e: EnemyCombatant) -> float:
 if e.hp<=0 or e.staggered or si(e.statuses,"poison")>=e.hp:return 0.0
 var pv: Variant=g.rules.preview_enemy_dmg(g.cb,e,g.run)
 return float(ji(pv.get("dmg",0))*ji(pv.get("times",1))) if typeof(pv)==TYPE_DICTIONARY else 0.0
func incoming(g: GlassvowGame) -> float:
 var v: float=0.0
 for e: EnemyCombatant in g.cb.enemies:v+=threat(g,e)
 return v
func ember_value(g: GlassvowGame) -> float:
 if route=="ember" and copies(g,"novaflare")>0:return 3.2 if g.cb.embers<8 else 0.8
 return 1.4 if g.run.aspect==0 else 2.8
func draw_value(g: GlassvowGame) -> float:
 # A pure draw has no unconditional value after spending all energy.
 # Other effects (energy, damage, exhaust/Embers) retain their own value.
 if g.cb.player.energy<=0:return 0.0
 return 4.0*(1.25 if route in ["hand","cycle"] else 1.0)
func choose_action(g: GlassvowGame) -> Dictionary:
 var tk: String=str(g.cb.get_instance_id())+":"+str(g.cb.turn)
 if tk!=_turn_key:_draw_seen.clear();_turn_key=tk
 var dk: String=visible_draw_key(g);var repeat_draw: bool=_draw_seen.has(dk)
 _draw_seen[dk]=true
 var aa: Array[Dictionary]=[];var ss: Array[float]=[]
 for c: CardInst in g.cb.hand:
  var d: Dictionary=g.rules.card_data(c);var targets: Array=[null]
  if str(d.get("target",""))=="enemy":
   targets=[]
   for e: EnemyCombatant in g.cb.living_enemies():targets.append(e.idx)
  if repeat_draw and pure_draw(d) and not d.get("exhaust",false):
   repeat_draw_avoided+=1;continue
  for target: Variant in targets:
   if g.rules.can_play(g.run,g.cb,c,target):
    aa.append({"t":"playCard","uid":c.uid,"target":target});ss.append(score(g,c,d,target,false))
 if random_play and not aa.is_empty():return aa[g.run.rng.pick_index(aa.size())]
 if g.rules.can_use_art(g.run,g.cb):
  var a: Dictionary=g.content.arts[String(g.run.art)]
  if random_play:return {"t":"useArt"}
  aa.append({"t":"useArt"});ss.append(score(g,null,{"type":"art","target":"allEnemies","effects":a.get("effects",[])},null,true)-ji(a.get("cost",0))*ember_value(g))
 if not g.cb.over:
  var worst: CardInst=null;var ws: float=INF
  for c: CardInst in g.cb.hand:
   var d: Dictionary=g.rules.card_data(c)
   if not g.rules.can_kindle(g.run,g.cb,c):continue
   var s: float=draft(g,d,String(c.id),false)
   if s<ws:ws=s;worst=c
  if worst!=null:
   var v: float=ember_value(g)-maxf(0,ws)*0.18
   if g.run.has_relic("verdantBranch"):v+=draw_value(g)
   if g.run.has_relic("crownOfTithes"):v+=minf(3,maxf(0,incoming(g)-g.cb.player.block))
   if String(worst.id) in ["strike","defend","ashBite"]:v+=1
   aa.append({"t":"kindleFromHand","uid":worst.uid});ss.append(v)
 var best: int=-1;var top: float=0.01
 for i: int in range(ss.size()):
  if ss[i]>top:top=ss[i];best=i
 return {} if best<0 else aa[best]
func attack_hit(g: GlassvowGame,e: EnemyCombatant,n: int) -> int:
 n+=si(g.cb.player.statuses,"str")
 if si(g.cb.player.statuses,"weak")>0:n=int(floorf(n*0.75))
 if si(e.statuses,"vulnerable")>0:n=int(floorf(n*1.5))
 return maxi(0,n)
func poison_value(e: EnemyCombatant,n: int) -> float:
 var p: int=si(e.statuses,"poison");var v: int=0
 for k: int in range(3):v+=maxi(0,p+n-k)-maxi(0,p-k)
 return minf(v,maxi(0,e.hp-p))*(1.2 if route=="smolder" else 0.85)
func score(g: GlassvowGame,c: CardInst,d: Dictionary,target: Variant,art: bool) -> float:
 var p: PlayerCombatant=g.cb.player;var t: EnemyCombatant=g.cb.enemies[ji(target)] if target!=null else null
 var selected: Array[EnemyCombatant]=[]
 if str(d.get("target",""))=="allEnemies":selected=g.cb.living_enemies()
 elif t!=null:selected.append(t)
 var inc: float=incoming(g);var unblocked: float=maxf(0,inc-p.block)
 var life: float=float(params.get("life",2.3)) if unblocked<p.hp else 8.0
 var damage: Dictionary={};var extra: int=0;var block: float=0;var value: float=0;var sid: String=""
 for fx: Dictionary in d.get("effects",[]):
  var kind: String=str(fx.get("kind",""));var n: int=ji(fx.get("n",0))
  if kind=="dmg":
   for e: EnemyCombatant in selected:damage[e.idx]=float(damage.get(e.idx,0))+(n if art else attack_hit(g,e,n))*ji(fx.get("times",1))
  elif kind=="block":block+=n if art else g.rules.preview_block(g.cb,n,g.run)
  elif kind=="chip":extra+=n
  elif kind=="draw":value+=draw_value(g)*minf(n,11-g.cb.hand.size())
  elif kind=="energy":value+=n*5.5*minf(1.2,0.25+0.2*g.cb.hand.size())
  elif kind=="heal":value+=minf(n,p.max_hp-p.hp)*2
  elif kind=="loseHp":value-=n*life
  elif kind=="ember":value+=minf(n,g.cb.ember_cap-g.cb.embers)*ember_value(g)
  elif kind=="status":
   var status: String=str(fx.get("id",""));var who: String=str(fx.get("who",""))
   if who=="self":
    if status=="str":value+=n*(7 if route=="fervor" else 4.5)
    elif status=="dex":value+=n*3.5
    elif status=="regen":value+=n*minf(4,1+float(p.max_hp-p.hp)/8)
    elif status=="ritual":value+=n*5
    elif status=="metallicize":block+=n;value+=n*2
    elif status=="energized":value+=12*n
    elif status=="nightsight":value+=11*n
    elif status=="emberflow":value+=3*n*ember_value(g)
    elif status=="venomous" and g.run.aspect==1:value+=10*n
    elif status=="barricade":value+=6+maxf(0,p.block-inc)
    elif status=="vulnerable":value-=2*n
    elif status=="beacon" and g.run.aspect==0:value+=3*n
   else:
    for e: EnemyCombatant in selected:
     if status=="poison" and g.run.aspect==1:
      value+=poison_value(e,n)
      if si(e.statuses,"poison")+n>=e.hp:value+=threat(g,e)*life
     elif status=="weak":value+=threat(g,e)*0.25*life*minf(n,2)
     elif status=="vulnerable":value+=2.5*n
     elif status=="str" and n<0:value-=n*2
  elif kind=="special":
   sid=str(fx.get("id",""))
   if sid=="doubleBlock":block+=p.block
   elif sid=="flawless":block+=n*(2 if g.cb.hp_lost==0 else 1)
   elif sid=="emberdance":block+=n*g.cb.embers;value-=g.cb.embers*ember_value(g)
   elif sid=="pyreTithe":
    value+=ji(fx.get("draw",0))*draw_value(g)+maxi(0,g.cb.hand.size()-1)*ember_value(g)
    for h: CardInst in g.cb.hand:
     if c==null or h.uid!=c.uid:value-=maxf(0,draft(g,g.rules.card_data(h),String(h.id),false))*0.2
   elif t!=null:
    var raw: int=n
    if sid=="execute" and si(t.statuses,"vulnerable")>0:raw+=ji(fx.get("bonus",0))
    elif sid=="momentum":raw+=c.bonus;value+=ji(fx.get("grow",0))*minf(2,10.0/maxi(5,g.run.player.deck.size()))
    elif sid=="phantom":raw*=maxi(0,g.cb.hand.size()-1)
    elif sid=="emberNova":raw*=g.cb.embers
    elif sid=="shatterEcho" and (t.staggered or si(t.statuses,"vulnerable")>0):raw*=2
    elif sid=="catalyst":
     if g.run.aspect==1:
      var added: int=si(t.statuses,"poison")*(n-1);value+=poison_value(t,added)
      if si(t.statuses,"poison")+added>=t.hp:value+=threat(g,t)*life
     raw=0
    if raw>0:
     damage[t.idx]=float(damage.get(t.idx,0))+attack_hit(g,t,raw)
     if sid=="leech":value+=minf(maxf(0,float(damage[t.idx])-t.block)*0.5,p.max_hp-p.hp)*1.5
 for e: EnemyCombatant in selected:
  var loss: float=maxf(0,float(damage.get(e.idx,0))-e.block);value+=minf(loss,e.hp)
  var chips: int=extra
  if str(d.get("type",""))=="attack" and loss>0:chips+=1+ji(d.get("chip",0))+si(p.statuses,"beacon")
  if g.run.aspect!=0:chips=0
  if loss>=e.hp:value+=threat(g,e)*life+2+(8 if sid=="devour" else 0)
  elif chips>0:
   if e.chips+chips>=e.facet_max:
    if not e.staggered:value+=threat(g,e)*life
    value+=4+(3 if route=="facet" else 0)
   else:value+=chips*(2.3 if route=="facet" else 0.7)
 value+=minf(block,unblocked)*life
 if si(p.statuses,"barricade")>0:value+=maxf(0,block-unblocked)*0.4
 if not art:
  value/=pow(maxf(1,g.rules.eff_cost(g.run,g.cb,c)),0.7)
  if d.get("exhaust",false) and str(d.get("type",""))!="power":value+=ember_value(g)
 return value
func draft(g: GlassvowGame,d: Dictionary,id: String,acquire: bool=true) -> float:
 if str(d.get("type","")) in ["curse","status"]:return -30
 var v: float=-2.0*ji(d.get("cost",0))
 for fx: Dictionary in d.get("effects",[]):
  var n: int=ji(fx.get("n",0));var kind: String=str(fx.get("kind",""))
  if kind=="dmg":v+=n*ji(fx.get("times",1))*(1.4 if str(d.get("target",""))=="allEnemies" else 1)
  elif kind=="block":v+=n*0.9
  elif kind=="heal":v+=n*2
  elif kind=="draw":v+=n*4
  elif kind=="energy":v+=n*4
  elif kind=="loseHp":v-=n*1.5
  elif kind=="ember":v+=n*(3.5 if route=="ember" else 2)
  elif kind=="chip":v+=n*(4 if g.run.aspect==0 else 0)
  elif kind=="status":
   var sid: String=str(fx.get("id",""))
   if sid=="poison":v+=n*(3 if g.run.aspect==1 else 0)
   elif sid=="str":v+=n*3.5 if str(fx.get("who",""))=="self" else -n*2.5
   elif sid in ["dex","metallicize"]:v+=n*3
   elif sid=="regen":v+=n*5
   elif sid in ["weak","vulnerable"]:v+=n*2*(2 if str(fx.get("who",""))=="allEnemies" else 1)
   elif sid=="ritual":v+=n*6
   elif sid in ["nightsight","energized","barricade"]:v+=14
   elif sid=="emberflow":v+=10*n
   elif sid=="venomous" and g.run.aspect==1:v+=14
  elif kind=="special":
   var sid: String=str(fx.get("id",""))
   v+=float({"leech":n*1.7,"execute":n+ji(fx.get("bonus",0))*0.5,"momentum":n+ji(fx.get("grow",0))*2,"phantom":n*4.0,"devour":n+8,"catalyst":10 if g.run.aspect==1 else -10,"shatterEcho":n*1.6,"emberNova":n*3.5,"doubleBlock":9,"flawless":n*1.4,"pyreTithe":9,"emberdance":9}.get(sid,0))
 v+=ji(d.get("chip",0))*(4 if g.run.aspect==0 else 0)
 var fit: float=float(FIT.get(route,{}).get(id,0))
 if str(d.get("type",""))=="power" and copies(g,id)>=2:fit*=0.3
 v+=fit*float(params.get("fit",1))
 if acquire:
  var n: int=copies(g,id);v-=maxi(0,n-1)*3
  if route=="cycle" and id!="momentum" and n>=2:v-=6
 return v
func choose_card(ids: Array,g: GlassvowGame,decline: bool=true) -> String:
 if ids.is_empty():return ""
 if random_build:return str(ids[g.run.rng.pick_index(ids.size())])
 var best: String="";var top: float=-INF
 for raw: Variant in ids:
  var id: String=str(raw);var v: float=draft(g,g.content.cards.get(id,{}),id)
  if v>top:top=v;best=id
 var threshold: float=float(params.get("decline",12))+maxi(0,g.run.player.deck.size()-18)*0.6
 if route=="cycle":threshold+=maxi(0,g.run.player.deck.size()-12)
 return "" if decline and top<threshold else best
func relic_score(id: String,g: GlassvowGame) -> float:
 var v: float=float({"hollowCrown":50,"crownOfTheHearth":45,"crownOfCinders":25,"crownOfTithes":30,"shatterersCrown":35 if g.run.aspect==0 else -5,"duskmirror":45,"verdantBranch":40,"frozenCore":28,"sunBlossom":25,"wardingCharm":25,"reapersBell":30,"vialOfLife":20,"gravebloom":20,"silkFan":23,"ironTalisman":25,"warFetish":18,"riverPearl":14,"travelersPack":22,"emberLantern":24,"sweetRoot":12,"thornBand":12,"seersOrb":18,"merchantsMark":14,"executionersSeal":20}.get(id,12))
 if route=="fervor" and id in ["ironTalisman","warFetish"]:v+=12
 if route=="hand" and id in ["travelersPack","verdantBranch"]:v+=12
 if route=="ember" and id in ["crownOfCinders","crownOfTheHearth"]:v+=18
 return v
func choose_relic(ids: Array,g: GlassvowGame) -> String:
 if ids.is_empty():return ""
 if random_build:return str(ids[g.run.rng.pick_index(ids.size())])
 var best: String=str(ids[0]);var top: float=-INF
 for raw: Variant in ids:
  var v: float=relic_score(str(raw),g)
  if v>top:top=v;best=str(raw)
 return best
func best_card(g: GlassvowGame,worst: bool=false,upgradable: bool=false) -> CardInst:
 var best: CardInst=null;var top: float=-INF
 for c: CardInst in g.run.player.deck:
  var d: Dictionary=g.content.cards[String(c.id)]
  if upgradable and (c.up or not d.has("up")):continue
  var v: float=draft(g,d,String(c.id),false)
  if upgradable:
   var du: Dictionary=d.duplicate(true);du.merge(d["up"],true)
   v=draft(g,du,String(c.id),false)-v+float(FIT.get(route,{}).get(String(c.id),0))*0.15
   if String(c.id)=="preparation":v+=8
  elif c.up:v+=4
  if worst:v=-v
  if v>top:top=v;best=c
 return best
