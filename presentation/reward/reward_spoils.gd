class_name RewardSpoils
extends RefCounted
## What a reward actually CONTAINS, resolved once against content, in the order
## it should be presented. Shared by every reward concept so the three of them
## are arguing about presentation and nothing else.
##
## THE COUNT THAT MATTERS. A reward is four things, and exactly one of them is a
## decision:
##
##   gold     an announcement — nobody has ever declined gold
##   potion   an announcement
##   relic    an announcement
##   cards    THE decision, and the only one
##
## The benchmark renders all four as identical rows with identical buttons,
## which costs the player three clicks to tell the game it heard the news. That
## is the thing worth fixing before any of the pixels are: the announcements
## should ARRIVE, and the choice should be the screen. `list()` returns only
## the announcements, in arrival order; the cards are asked for separately
## because they are a different kind of thing.
##
## Claiming is still per-item on the signal, so a screen that auto-settles its
## announcements stays save-compatible with the web's persisted
## `pendingReward.taken` — the player is spared the clicking, not the record.

const GOLD: Color = Color(0.949, 0.757, 0.306)     # #F2C14E
const COIN_ART: String = "res://assets/art/ui/coin.png"
const POTION_ART: String = "res://assets/art/potions/"
const RELIC_ART: String = "res://assets/art/relics/"

static var _fonts: Dictionary = {}


## The announcements: gold first (always), then potion, then relic. Each entry:
##   what   StringName — the `claimed` signal's first argument
##   id     String     — "" for gold, the content id otherwise
##   name   String     — display name ("17 Gold", "Emberheart")
##   sub    String     — the one line under it; "" when there is nothing to say
##   tone   Color      — the item's own colour, straight off content
##   glyph  String     — its unicode mark, for when art is missing
##   art    String     — absolute res:// path, or "" if nothing is on disk
static func list(reward: Dictionary, content: ContentDB) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var gold: int = reward.get("gold", 0)
	if gold > 0:
		out.append({
			"what": &"gold", "id": "", "name": "%d Gold" % gold,
			"sub": "", "tone": GOLD, "glyph": "◈",
			"art": COIN_ART if ResourceLoader.exists(COIN_ART) else "",
		})
	var potion_v: Variant = reward.get("potion")
	if potion_v != null:
		var def: Dictionary = content.potions.get(str(potion_v), {})
		out.append(_entry(&"potion", str(potion_v), def, POTION_ART))
	var relic_v: Variant = reward.get("relic")
	if relic_v != null:
		var def: Dictionary = content.relics.get(str(relic_v), {})
		out.append(_entry(&"relic", str(relic_v), def, RELIC_ART))
	return out


static func _entry(what: StringName, id: String, def: Dictionary,
		dir: String) -> Dictionary:
	var art: String = dir + id + ".png"
	return {
		"what": what, "id": id,
		"name": str(def.get("name", id)),
		"sub": str(def.get("text", "")),
		"tone": Color.from_string(str(def.get("tone", "")), GOLD),
		"glyph": str(def.get("glyph", "◈")),
		"art": art if ResourceLoader.exists(art) else "",
	}


## The offering. Empty when the fight gave no card choice, which is a real case
## and not an error — the screen has to look deliberate with nothing here.
static func card_ids(reward: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var raw: Array = reward.get("cards", [])
	for id_v: Variant in raw:
		out.append(str(id_v))
	return out


## A card's TYPE colour — what the glass behind it should be. Read off
## CardView's own sampled table so the offering and the hand never disagree
## about what an attack looks like.
static func tint_of(content: ContentDB, id: String) -> Color:
	var def: Dictionary = content.cards.get(id, {})
	var tint: Variant = CardView.TYPE_TINT.get(str(def.get("type", "")))
	return GlassStyle.GLASS if tint == null else tint


## One card at `scale`, wired to `on_take`. `cost` is present-but-null on the
## unplayable cards, so Dictionary.get's default never fires — this is the same
## read combat's eff_cost does.
static func card(content: ContentDB, id: String, uid: int, scale: float,
		on_take: Callable) -> CardView:
	var data: Dictionary = content.cards.get(id, {})
	var cost_v: Variant = data.get("cost")
	var cost: int = 0 if cost_v == null else int(float(str(cost_v)))
	var view: CardView = CardView.new(CardInst.new(uid, StringName(id)), data, cost)
	view.scale = Vector2(scale, scale)
	view.released_at.connect(func(_u: int, _p: Vector2) -> void: on_take.call(id))
	return view


## A scaled CardView still reports its UNSCALED rect to a container, so three
## at 1.17 would overlap by 26px each. The pedestal reserves the grown box;
## scale runs about CardView's own centred pivot, so the card needs no offset.
static func pedestal(view: CardView, scale: float) -> Control:
	var pad: Control = Control.new()
	pad.custom_minimum_size = Vector2(CardView.CARD_W, CardView.CARD_H) * scale
	view.position = (pad.custom_minimum_size
		- Vector2(CardView.CARD_W, CardView.CARD_H)) * 0.5
	pad.add_child(view)
	return pad


static func font(path: String, tracking: int) -> Font:
	var key: String = path + "#" + str(tracking)
	if _fonts.has(key):
		var hit: Font = _fonts[key]
		return hit
	var fv: FontVariation = FontVariation.new()
	fv.base_font = load(path) as FontFile
	if tracking != 0:
		fv.spacing_glyph = tracking
	_fonts[key] = fv
	return fv
