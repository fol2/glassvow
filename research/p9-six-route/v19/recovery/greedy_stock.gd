extends "res://additive_policy.gd"
## Two-slope research adapter. Evaluates the same law as native execution.
## Missing floor_per preserves the published v18 action/draft procedure.
func payoff(stock: int, fx: Dictionary) -> int:
 return g_payoff(stock,fx)
static func g_payoff(stock: int, fx: Dictionary) -> int:
 var q: int=maxi(0,stock)
 var r: int=maxi(0,int(fx.get("reserve",0)))
 return int(fx.n)*maxi(0,q-r)+int(fx.get("floor_per",0))*mini(q,r)
func score(g: GlassvowGame,c: CardInst,d: Dictionary,target: Variant,art: bool) -> float:
 var effective: Dictionary=d
 var changed: bool=false
 for fx: Dictionary in d.get("effects",[]):
  if fx.get("kind")=="special" and fx.get("id") in ["phantom","emberNova"] and ji(fx.get("floor_per",0))!=0:
   changed=true;break
 if changed:
  effective=d.duplicate(true)
  var effects: Array=[]
  for fx: Dictionary in effective.effects:
   if fx.get("kind")=="special" and fx.get("id") in ["phantom","emberNova"]:
    var stock: int=maxi(0,g.cb.hand.size()-1) if fx.id=="phantom" else g.cb.embers
    effects.append({"kind":"dmg","n":g_payoff(stock,fx)})
   else:effects.append(fx)
  effective.effects=effects
 return super.score(g,c,effective,target,art)
func draft(g: GlassvowGame,d: Dictionary,id: String,acquire: bool=true) -> float:
 var value: float=super.draft(g,d,id,acquire)
 for fx: Dictionary in d.get("effects",[]):
  if fx.get("kind")=="special" and fx.get("id") in ["phantom","emberNova"] and ji(fx.get("floor_per",0))!=0:
   var f: Dictionary=features(g)
   var q: float=clampf(3.0+float(f.sight)*0.7+5.0*float(f.draw)/maxf(1,float(f.size)),2,7) if fx.id=="phantom" else expected_embers(g)
   value+=float(fx.floor_per)*minf(q,float(fx.get("reserve",0)))
 return value
func nova_spend_cost(g: GlassvowGame,spent: int) -> float:
 var defs: Array[Dictionary]=[];var any_smooth: bool=false
 for c: CardInst in g.run.player.deck:
  if c.id==&"novaflare":
   var fx: Dictionary=card_definition(g,c).effects[0]
   defs.append(fx);any_smooth=any_smooth or ji(fx.get("floor_per",0))!=0
 if defs.is_empty() or not any_smooth:return super.nova_spend_cost(g,spent)
 var stock: int=g.cb.embers;var owned: int=defs.size();var now: bool=false
 for c: CardInst in g.cb.hand:
  if c.id==&"novaflare" and g.cb.player.energy>=g.rules.eff_cost(g.run,g.cb,c):now=true
 var no_spend: int=stock;var after: int=maxi(0,stock-spent);var probability: float=1.0
 if not now:
  for c: CardInst in g.cb.exhaust:
   if c.id==&"novaflare":owned-=1
  probability=exposure_probability(g.cb.hand.size()+g.cb.draw.size()+g.cb.discard.size(),maxi(0,owned),5+si(g.cb.player.statuses,"nightsight"))
  var gain: int=si(g.cb.player.statuses,"emberflow")+1
  no_spend=mini(g.cb.ember_cap,stock+gain);after=mini(g.cb.ember_cap,maxi(0,stock-spent)+gain)
 var delta: float=0.0
 for fx: Dictionary in defs:delta+=g_payoff(no_spend,fx)-g_payoff(after,fx)
 return delta/defs.size()*probability*float(params.get("bank_discount",1.0))
