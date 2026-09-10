extends RefCounted
func ji(v: Variant) -> int:
 if typeof(v)==TYPE_INT:
  var integer: int=v
  if integer>=-9007199254740991 and integer<=9007199254740991:
   return integer
 return int(float(str(v)))
