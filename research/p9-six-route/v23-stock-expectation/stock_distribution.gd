extends RefCounted
## Bounded uncertainty sensitivity, NOT a calibrated model of game resources.
## Both comparison arms use this same mean and support; only aggregation differs.
static func binomial(mean_stock: float, capacity: int) -> Array[float]:
 assert(capacity > 0 and is_finite(mean_stock))
 assert(mean_stock >= 0.0 and mean_stock <= float(capacity))
 var p: float = mean_stock / float(capacity)
 var mass: Array[float] = []
 mass.resize(capacity + 1)
 mass.fill(0.0)
 mass[0] = 1.0
 for trial: int in range(capacity):
  for q: int in range(trial + 1, -1, -1):
   mass[q] = mass[q] * (1.0-p) + (mass[q-1]*p if q>0 else 0.0)
 return mass

static func raw_value(stock: float, effect: Dictionary) -> float:
 var q: float = maxf(0.0, stock)
 var reserve: float = maxf(0.0, float(effect.get("reserve", 0)))
 if effect.get("id") == "heldEmberWard":
  return float(effect.get("n",0)) + float(effect.get("per",0))*maxf(0.0,q-reserve)
 assert(effect.get("id") in ["phantom", "emberNova"])
 return float(effect.get("n",0))*maxf(0.0,q-reserve) + float(effect.get("floor_per",0))*minf(q,reserve)

static func expected(mass: Array[float], effect: Dictionary) -> float:
 var out: float = 0.0
 var total: float = 0.0
 for q: int in range(mass.size()):
  assert(mass[q] >= 0.0 and is_finite(mass[q]))
  out += mass[q]*raw_value(float(q),effect)
  total += mass[q]
 assert(absf(total-1.0) < 0.00000001)
 return out
