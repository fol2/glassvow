extends "res://greedy_fuel_reference.gd"
## Experiment: mean-before-payoff vs payoff-before-mean on one disclosed PMF.
## Content, current-state action payoff and route priors are not changed.
const StockDistribution: GDScript = preload("res://stock_distribution.gd")
var _stock_mass_cache: Dictionary = {}

func stock_forecast(g: GlassvowGame, sid: String) -> Dictionary:
 var f: Dictionary = features(g)
 var mean_stock: float = expected_embers(g)
 var capacity: int = 12 if g.run.has_relic("crownOfCinders") else 9
 if sid == "phantom":
  mean_stock = clampf(3.0+float(f.sight)*0.7+5.0*float(f.draw)/maxf(1.0,float(f.size)),2.0,7.0)
  capacity = 9 # Native hand cap 10; the played Phantom leaves at most 9 held cards.
 var key: String = str(capacity) + ":" + str(mean_stock)
 if not _stock_mass_cache.has(key):
  _stock_mass_cache[key] = StockDistribution.binomial(mean_stock,capacity)
 return {"mean":mean_stock,"capacity":capacity,"mass":_stock_mass_cache[key]}

func draft(g: GlassvowGame, d: Dictionary, id: String, acquire: bool = true) -> float:
 var value: float = super.draft(g,d,id,acquire)
 var mode: String = str(params.get("stock_aggregation","mean"))
 assert(mode in ["mean","expectation"])
 if mode == "mean" or str(d.get("type","")) in ["curse","status"]:
  return value
 for fx: Dictionary in d.get("effects",[]):
  if fx.get("kind") != "special" or not fx.get("id") in ["phantom","emberNova","heldEmberWard"]:
   continue
  var forecast: Dictionary = stock_forecast(g,str(fx.id))
  var old: float = StockDistribution.raw_value(float(forecast.mean),fx)
  var revised: float = StockDistribution.expected(forecast.mass,fx)
  if fx.id == "heldEmberWard":
   # The unchanged parent converts its plug-in Ward to an integer block effect.
   value += 0.9*(revised-float(ji(old)))
  else:
   value += revised-old
 return value
