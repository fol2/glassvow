extends "res://legacy_policy.gd"
## v8 research controller: public-state marginal estimates, never a P9 certificate.
## The archived v5 policy is retained verbatim as legacy_policy.gd.
var _feature_signature: String=""
var _features: Dictionary={}
func card_definition(g: GlassvowGame,c: CardInst) -> Dictionary:
 var d: Dictionary=g.content.cards[String(c.id)].duplicate(true)
 if c.up:d.merge(d.get("up",{}),true)
 return d
func features(g: GlassvowGame) -> Dictionary:
 var sig: String=str(g.content.get_instance_id())+":"
 for c: CardInst in g.run.player.deck:sig+=str(c.uid)+":"+String(c.id)+":"+str(c.up)+";"
 if sig==_feature_signature:return _features
 _feature_signature=sig
 var f: Dictionary={"size":g.run.player.deck.size(),"attack":0.0,"hits":0.0,"multi":0.0,"str":0.0,"draw":0.0,"sight":0.0,"flow":0.0,"embers":0.0,"poison":0.0,"exhaust":0.0,"powers":0.0}
 for c: CardInst in g.run.player.deck:
  var d: Dictionary=card_definition(g,c)
  if str(d.get("type",""))=="power":f.powers+=1.0
  if d.get("exhaust",false):f.exhaust+=1.0
  var hits: float=0.0
  for fx: Dictionary in d.get("effects",[]):
   var n: float=float(fx.get("n",0));var kind: String=str(fx.get("kind",""))
   if kind=="dmg":hits+=float(fx.get("times",1))
   elif kind=="special" and str(fx.get("id","")) in ["momentum","phantom","emberNova","execute","leech","devour","shatterEcho"]:hits+=1.0
   elif kind=="draw" and ji(d.get("cost",0))<=1:f.draw+=n
   elif kind=="ember":f.embers+=n
   elif kind=="status":
    var sid: String=str(fx.get("id",""))
    if sid=="str" and fx.get("who")=="self":f.str+=n
    elif sid=="nightsight":f.sight+=n
    elif sid=="emberflow":f.flow+=n
    elif sid=="poison":f.poison+=n*(1.5 if fx.get("who")=="allEnemies" else 1.0)
  if hits>0:f.attack+=1.0;f.hits+=hits;f.multi+=maxf(0,hits-1)
 _features=f
 return f
func cycle_repeats(g: GlassvowGame) -> float:
 var f: Dictionary=features(g)
 # Finite four-turn draft horizon; spent powers/exhausts shrink later cycles.
 var effective: float=maxf(7.0,float(f.size)-0.65*float(f.powers)-0.45*float(f.exhaust))
 var draws: float=5.0+minf(2.0,float(f.sight))+minf(3.0,5.0*float(f.draw)/maxf(1,float(f.size)))
 return clampf(4.0*draws/effective,1.0,4.0)
func expected_embers(g: GlassvowGame) -> float:
 var f: Dictionary=features(g)
 var producers: float=float(f.exhaust)*0.35+float(f.flow)*2.0+float(f.embers)*0.6
 return clampf(1.5+producers,1.0,8.0)
func ember_value(g: GlassvowGame) -> float:
 if route=="ember" and copies(g,"novaflare")>0:
  var raw: Dictionary=g.content.cards["novaflare"]
  var fx: Dictionary=raw.effects[0]
  return maxf(1.4,float(fx.n)*float(params.get("bank_value",1.1)))
 return 1.4 if g.run.aspect==0 else 2.8
func visible_draw_key(g: GlassvowGame) -> String:
 # Canonicalise only policy memory. No actual game resource is clamped.
 var text: String=super.visible_draw_key(g)
 var x: Array=JSON.parse_string(text)
 x[3]=minf(g.cb.player.block,maxf(30.0,2.0*incoming(g)))
 return JSON.stringify(x)
func non_damage_threat(g: GlassvowGame,e: EnemyCombatant) -> float:
 if e.hp<=0 or e.staggered or si(e.statuses,"poison")>=e.hp:return 0.0
 var mv: Dictionary=e.move();var v: float=minf(float(mv.get("heal",0)),maxi(0,e.max_hp-e.hp))*0.65
 v+=minf(12,float(mv.get("block",0)))*0.25
 for fx: Dictionary in mv.get("fx",[]):
  var n: float=float(fx.get("n",0));var who: String=str(fx.get("who",""));var sid: String=str(fx.get("id",""))
  if who=="player":
   if sid=="poison":v+=n*2.2
   elif sid in ["weak","frail","vulnerable"]:v+=n*2.5
  elif sid=="str":v+=n*2.2
 if mv.has("addCards"):v+=float(mv.addCards.get("n",0))*2.0
 return v
func score(g: GlassvowGame,c: CardInst,d: Dictionary,target: Variant,art: bool) -> float:
 var value: float=super.score(g,c,d,target,art)
 var cost_factor: float=1.0 if art else pow(maxf(1,g.rules.eff_cost(g.run,g.cb,c)),0.7)
 var remaining_energy: int=g.cb.player.energy if art else g.cb.player.energy-g.rules.eff_cost(g.run,g.cb,c)
 for fx: Dictionary in d.get("effects",[]):
  var n: float=float(fx.get("n",0))
  if fx.get("kind")=="draw":
   var usable: float=4.0*(1.25 if route in ["hand","cycle"] else 1.0)*clampf(remaining_energy/1.5,0,1)
   value+=(usable-draw_value(g))*minf(n,11-g.cb.hand.size())/cost_factor
  if fx.get("kind")=="status" and fx.get("who")=="self" and fx.get("id")=="str":
   var hits: float=0
   for h: CardInst in g.cb.hand:
    if c!=null and h.uid==c.uid:continue
    for hfx: Dictionary in g.rules.card_data(h).get("effects",[]):
     if hfx.get("kind")=="dmg":hits+=float(hfx.get("times",1))
   var f: Dictionary=features(g)
   var future: float=clampf(2.0*float(f.hits)/maxf(1,float(f.attack)),2.0,8.0)
   value+=n*(minf(hits,6)+future-(7.0 if route=="fervor" else 4.5))/cost_factor
  if fx.get("kind")=="special" and fx.get("id")=="momentum":
   var remaining: float=clampf(cycle_repeats(g)-0.45*maxi(0,g.cb.turn-1),0,3)
   value+=float(fx.get("grow",0))*(remaining-minf(2,10.0/maxi(5,g.run.player.deck.size())))/cost_factor
  if fx.get("kind")=="special" and fx.get("id") in ["phantom","emberNova"] and target!=null:
   var stock: int=maxi(0,g.cb.hand.size()-1) if fx.id=="phantom" else g.cb.embers
   var reserve: int=ji(fx.get("reserve",0))
   if reserve>0:
    var e: EnemyCombatant=g.cb.enemies[ji(target)]
    var old_loss: float=maxf(0,attack_hit(g,e,int(n)*stock)-e.block)
    var new_loss: float=maxf(0,attack_hit(g,e,int(n)*maxi(0,stock-reserve))-e.block)
    value+=(minf(new_loss,e.hp)-minf(old_loss,e.hp))/cost_factor
    if old_loss>=e.hp and new_loss<e.hp:value-=(threat(g,e)*float(params.get("life",2.3))+2)/cost_factor
 if not art and si(g.cb.player.statuses,"barricade")>0:
  var pv_block: Variant=g.rules.preview_play(g.cb,c,target,g.run)
  var b: float=float(pv_block.get("block",0)) if typeof(pv_block)==TYPE_DICTIONARY else 0.0
  var unblocked: float=maxf(0,incoming(g)-g.cb.player.block)
  var carry_room: float=maxf(0,maxf(30,2*incoming(g))-maxf(g.cb.player.block,incoming(g)))
  value-=maxf(0,b-unblocked-carry_room)*0.4/cost_factor
 if not art and target!=null:
  var e: EnemyCombatant=g.cb.enemies[ji(target)]
  var pv: Variant=g.rules.preview_play(g.cb,c,target,g.run)
  if typeof(pv)==TYPE_DICTIONARY and (pv.get("lethal",false) or (g.run.aspect==0 and pv.get("willShatter",false))):
   value+=non_damage_threat(g,e)*float(params.get("disrupt",1.5))/cost_factor
 return value
func draft(g: GlassvowGame,d: Dictionary,id: String,acquire: bool=true) -> float:
 var value: float=super.draft(g,d,id,acquire)
 if str(d.get("type","")) in ["curse","status"]:return value
 var f: Dictionary=features(g);var size: float=maxf(1,float(f.size))
 var anticipated_strength: float=minf(7,float(f.str)*0.7)
 for fx: Dictionary in d.get("effects",[]):
  var n: float=float(fx.get("n",0));var kind: String=str(fx.get("kind",""));var sid: String=str(fx.get("id",""))
  if kind=="status" and sid=="str" and fx.get("who")=="self":
   value+=n*minf(7,0.8+float(f.multi)*0.85)
  elif kind=="dmg":value+=anticipated_strength*float(fx.get("times",1))
  elif kind=="draw":
   value+=n*minf(2,copies(g,"phantomBlades")*0.6+copies(g,"momentum")*0.35)
  elif kind=="status" and sid=="nightsight":
   value+=n*minf(10,copies(g,"phantomBlades")*3+copies(g,"momentum")*2)
  elif kind=="status" and sid=="emberflow":
   value+=n*minf(10,2+copies(g,"novaflare")*4)
  elif kind=="ember":value+=n*minf(4,copies(g,"novaflare")*1.5)
  elif kind=="special":
   if sid=="momentum":
    # Replace unconditional two-growth valuation with circulation estimate.
    value+=float(fx.get("grow",0))*(0.5*maxf(0,cycle_repeats(g)-1)-2)
    value+=anticipated_strength
   elif sid=="phantom":
    var hand: float=clampf(3.0+float(f.sight)*0.7+5.0*float(f.draw)/size,2,7)
    value+=n*(maxf(0,hand-float(fx.get("reserve",0)))-4)+anticipated_strength
   elif sid=="emberNova":
    value+=n*(maxf(0,expected_embers(g)-float(fx.get("reserve",0)))-3.5)+anticipated_strength
   elif sid=="catalyst" and g.run.aspect==1:
    value+=minf(12,float(f.poison)*0.5)*(n-1)-5
 if str(d.get("type",""))=="power" and copies(g,id)>0:value-=5*copies(g,id)
 return value
