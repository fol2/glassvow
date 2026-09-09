extends GlassvowGame
## Observation only: no card, rule, choice, RNG or acquisition changes.
static var stream: FileAccess
static var row_key: String = ""
static var sequence: int = 0
var fight: int = -1

static func begin(key: String, file: FileAccess) -> void:
	row_key = key; stream = file; sequence = 0

func view() -> Dictionary:
	var enemies: Array = []
	if cb != null:
		for e: EnemyCombatant in cb.enemies:
			enemies.append({"idx":e.idx,"hp":e.hp,"poison":int(e.statuses.get("poison",0))})
	var deck: Array = []
	for c: CardInst in run.player.deck:
		if String(c.id) in ["empower","flurry","venomStrike","catalyst"]:
			deck.append({"id":String(c.id),"uid":c.uid,"up":c.up})
	return {"aspect":run.aspect,"vow":run.vow,"seed":run.seed,"deck":deck,
		"str":int(cb.player.statuses.get("str",0)) if cb != null else 0,
		"energy":cb.player.energy if cb != null else 0,"enemies":enemies,
		"turn":cb.turn if cb != null else 0,"over":cb.over if cb != null else false}

func apply(cmd: Dictionary) -> Array[Dictionary]:
	if cmd.t == "startCombat":fight += 1
	var card: String = ""
	if cmd.t == "playCard" and cb != null:
		for c: CardInst in cb.hand:
			if c.uid == int(cmd.get("uid",-1)):card = String(c.id)
	var before: Dictionary = view()
	var events: Array[Dictionary] = super.apply(cmd)
	stream.store_line(JSON.stringify({"kind":"command","row_key":row_key,"sequence":sequence,
		"fight":fight,"command":cmd,"card":card,"before":before,"after":view(),
		"events":events,"ret":last_ret}))
	stream.flush(); sequence += 1
	return events
