extends "res://test_research_instrument.gd"
# Research test; run in the recovered project fixture, not the shipping project.
func trial(repaired: bool) -> Dictionary:
 var g: GlassvowGame=game()
 g.cb.player.energy=1
 g.cb.player.hp=50
 g.cb.player.block=0
 g.cb.player.statuses={"barricade":1}
 g.run.player.relics=["silkFan"]
 if repaired:
  g.content.cards["preparation"]["up"].erase("exhaust")
  g.content.cards["preparation"]["up"]["effects"][0]["n"]=3
 for i: int in range(7):
  g.cb.hand.append(CardInst.new(3000+i,&"strike"))
 g.cb.hand.append(CardInst.new(3100,&"preparation",true))
 g.cb.discard.append(CardInst.new(3101,&"preparation",true))
 var casts: int=0
 var damage: int=0
 for i: int in range(120):
  var draw_card: CardInst=null
  for c: CardInst in g.cb.hand:
   if String(c.id)=="preparation":
    draw_card=c
    break
  if draw_card==null:
   break
  var events: Array[Dictionary]=g.apply({"t":"playCard","uid":draw_card.uid,"target":null})
  check(g.last_ret==true,"actual legal draw cast")
  for ev: Dictionary in events:
   if ev.get("t")==EventTypes.HIT_ENEMY:
    damage+=int(ev.get("amount",0))
  casts+=1
 return {"repaired":repaired,"casts":casts,"energy":g.cb.player.energy,"ward":g.cb.player.block,"enemy_damage":damage,"exhaust_count":g.cb.exhaust.size()}
func _initialize() -> void:
 var a: Dictionary=trial(false)
 var b: Dictionary=trial(true)
 check(a["casts"]==120 and a["ward"]==120 and a["energy"]==1 and a["enemy_damage"]==0,"original native rules allow productive Ward-pumping prefix")
 check(b["casts"]==2 and b["exhaust_count"]==2 and b["ward"]==0 and b["energy"]==1,"exhausting draw-three upgrade removes this repeatable cycle")
 print("PREPARATION_PUMP "+JSON.stringify({"original":a,"candidate_repair":b,"note":"Controlled state counterexample, not full-run acquisition or P9 evidence."}))
 if failures:
  print("PUMP_TEST_FAIL "+str(failures))
  quit(3)
 else:
  print("PUMP_TEST_PASS "+str(n))
  quit(0)
