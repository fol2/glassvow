extends "res://policy_v8.gd"
## Research-only spending model. Falsifiable, no live RNG or hidden draw-order access.
func exposure_probability(population: int,successes: int,draws: int) -> float:
 if population<=0 or successes<=0 or draws<=0:return 0.0
 var miss: float=1.0
 for j: int in range(mini(population,draws)):
  miss*=float(maxi(0,population-successes-j))/float(population-j)
 return 1.0-miss
func nova_spend_cost(g: GlassvowGame,spent: int) -> float:
 var n: int=0;var reserve: int=0;var owned: int=0
 for c: CardInst in g.run.player.deck:
  if c.id==&"novaflare":
   var d: Dictionary=card_definition(g,c);var fx: Dictionary=d.effects[0]
   n+=ji(fx.n);reserve=ji(fx.get("reserve",0));owned+=1
 if owned==0:return spent*super.ember_value(g)
 var coefficient: float=float(n)/owned
 var currently_available: bool=false
 for c: CardInst in g.cb.hand:
  if c.id==&"novaflare" and g.cb.player.energy>=g.rules.eff_cost(g.run,g.cb,c):currently_available=true
 var stock: int=g.cb.embers
 var current_delta: float=coefficient*(maxi(0,stock-reserve)-maxi(0,stock-spent-reserve))
 if currently_available:return current_delta*float(params.get("bank_discount",1.0))
 for c: CardInst in g.cb.exhaust:
  if c.id==&"novaflare":owned-=1
 var population: int=g.cb.hand.size()+g.cb.draw.size()+g.cb.discard.size()
 var draws: int=5+si(g.cb.player.statuses,"nightsight")
 var probability: float=exposure_probability(population,maxi(0,owned),draws)
 # Explicit one-turn approximation: source emberflow and one normal Kindle.
 # Treat as a controller forecast, never as observed future game state.
 var gain: int=si(g.cb.player.statuses,"emberflow")+1
 var no_spend: int=mini(g.cb.ember_cap,stock+gain)
 var after_spend: int=mini(g.cb.ember_cap,maxi(0,stock-spent)+gain)
 var delta: float=coefficient*(maxi(0,no_spend-reserve)-maxi(0,after_spend-reserve))
 return delta*probability*float(params.get("bank_discount",1.0))
func score(g: GlassvowGame,c: CardInst,d: Dictionary,target: Variant,art: bool) -> float:
 var v: float=super.score(g,c,d,target,art)
 if params.get("bank_mode","legacy")!="current-plus-next":return v
 if copies(g,"novaflare")==0:return v
 if art:
  var spent: int=ji(g.content.arts[String(g.run.art)].get("cost",0))
  v+=spent*ember_value(g)-nova_spend_cost(g,spent)
 else:
  for fx: Dictionary in d.get("effects",[]):
   if fx.get("kind")=="special" and fx.get("id")=="emberdance":
    var f: float=pow(maxf(1,g.rules.eff_cost(g.run,g.cb,c)),0.7)
    v+=(g.cb.embers*ember_value(g)-nova_spend_cost(g,g.cb.embers))/f
 return v
