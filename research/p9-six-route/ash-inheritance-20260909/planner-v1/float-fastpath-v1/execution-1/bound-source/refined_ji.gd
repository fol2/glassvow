extends RefCounted
func ji(v: Variant) -> int:
 if typeof(v)==TYPE_INT:
  var integer: int=v
  if integer>=-9007199254740991 and integer<=9007199254740991:
   return integer
 if typeof(v)==TYPE_FLOAT:
  var value: float=v
  if value>=-1024.0 and value<=1024.0:
   var whole: int=int(value)
   if value==float(whole):return whole
 return int(float(str(v)))
