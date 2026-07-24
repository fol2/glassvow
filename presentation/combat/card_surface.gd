class_name CardSurface
extends RefCounted
## WHAT THE CARD IS MADE OF — four independent layers, stacked.
##
## The rarity pill was a label: a 24x5 bar that *told* you the tier. A real card
## never tells you. You know a rare in your hand before you read it, because the
## stock is thicker, the coating catches light differently, and the surface has
## a tooth the common one hasn't. So the pill goes, and the tier is carried by
## the material instead — which means the material has to be worth reading.
##
## Four layers, because that is how a printed card is actually built, and each
## answers a different question:
##
##   material  what it is made OF        paper, glass, gold leaf, PVC, lead
##   texture   how the surface BREAKS    tooth, linen weave, engine-turning
##   finish    the coating ON it         matte, satin, metallic, holo, pearl
##   stock     the BODY's grade          thickness, cut, weight, rigidity
##
## They are separate catalogues and they compose: nothing here is bound to
## rarity. `RECIPES` names a stack, `BY_RARITY` picks a default recipe, and
## everything downstream of that is override — per type, per card, or straight
## off the card data. Nine materials x seven textures x thirteen finishes x six
## stocks is 4,914 distinguishable surfaces; the six the game ships are one
## table entry each, and adding a seventh costs one line.
##
## The layers own disjoint keys on purpose. A merge is then just a merge — no
## layer can quietly overwrite another's channel, so a new texture cannot
## accidentally change how a finish reflects. `params()` folds them in stack
## order and hands the result to one shader (card_surface.gdshader) plus three
## non-optical properties the slab reads directly: thickness, shadow weight and
## the release spring.
##
## Angle, not time. The card freezes both its offscreen viewports when it comes
## to rest, so anything driven by TIME would silently stop. Every channel here
## is a function of geometry — the view vector, the surface normal, the card's
## own axes — which is what a real material is anyway. Head-on and still, a
## finish is nearly invisible; that is not restraint, it is what foil does.

const GOLD_LIT: Color = Color(1.000, 0.914, 0.675)
const GOLD: Color = Color(0.949, 0.757, 0.306)
const RULE: Color = Color(0.020, 0.027, 0.055)

## ── LAYER 1: MATERIAL ────────────────────────────────────────────────────
## What the card is made of. Owns the colour light comes back as, what the
## body does to light that gets inside it, and the colour of the cut edge.
##
##   ink        the reflection's own colour — paper returns white, leaf returns
##              its metal. This is the hue of every highlight on the card.
##   ink_tint   0..1 how far that reflection is pulled toward the card's TYPE
##              tint. Glass is the game's conceit: its highlights are coloured.
##   soak       absorption. Light that lands does not come back — the surface
##              goes DARKER where it should shine. Only lead does this.
##   bleed      subsurface scatter: the body glows faintly at grazing angles
##              and lifts its own blacks. Paper does a little, acrylic a lot.
##   body/body_tint/body_dark   the slab's cross-section, which is the one place
##              you see the material itself rather than its coating.
const MATERIAL: Dictionary = {
	"pulp": {                                  # cheap uncoated paper
		"ink": Color(0.96, 0.95, 0.92), "ink_tint": 0.15,
		"soak": 0.0, "bleed": 0.35,
		"body": RULE, "body_tint": 0.50, "body_dark": 0.55,
	},
	"stock": {                                 # proper card stock
		"ink": Color(1.0, 1.0, 1.0), "ink_tint": 0.20,
		"soak": 0.0, "bleed": 0.22,
		"body": RULE, "body_tint": 0.55, "body_dark": 0.40,
	},
	"glass": {                                 # the game's own substance
		"ink": Color(1.0, 1.0, 1.0), "ink_tint": 0.55,
		"soak": 0.0, "bleed": 0.30,
		"body": RULE, "body_tint": 0.85, "body_dark": 0.15,
	},
	"silver-leaf": {
		"ink": Color(0.87, 0.90, 0.96), "ink_tint": 0.10,
		"soak": 0.0, "bleed": 0.10,
		"body": Color(0.72, 0.76, 0.84), "body_tint": 0.12, "body_dark": 0.10,
	},
	"gold-leaf": {
		"ink": GOLD_LIT, "ink_tint": 0.06,
		"soak": 0.0, "bleed": 0.12,
		"body": GOLD, "body_tint": 0.0, "body_dark": 0.0,
	},
	"nacre": {                                 # mother-of-pearl pigment
		"ink": Color(0.98, 0.97, 1.0), "ink_tint": 0.25,
		"soak": 0.0, "bleed": 0.40,
		"body": Color(0.80, 0.82, 0.88), "body_tint": 0.35, "body_dark": 0.22,
	},
	"pvc": {                                   # rigid plastic card
		"ink": Color(0.94, 0.96, 1.0), "ink_tint": 0.10,
		"soak": 0.0, "bleed": 0.08,
		"body": Color(0.62, 0.66, 0.74), "body_tint": 0.20, "body_dark": 0.30,
	},
	"acrylic": {                               # thick clear block
		"ink": Color(1.0, 1.0, 1.0), "ink_tint": 0.40,
		"soak": 0.0, "bleed": 0.55,
		"body": Color(1.0, 1.0, 1.0), "body_tint": 1.0, "body_dark": 0.0,
	},
	"lead": {                                  # glass that drinks light
		"ink": Color(0.30, 0.33, 0.40), "ink_tint": 0.30,
		"soak": 0.30, "bleed": 0.0,
		"body": Color(0.05, 0.06, 0.09), "body_tint": 0.0, "body_dark": 0.0,
	},
}

## ── LAYER 2: TEXTURE ─────────────────────────────────────────────────────
## The surface you could feel. Pure geometry: a height field in card pixels
## that bends the normal, so it changes WHERE light lands without adding any
## light of its own. This is the layer that survives at rest — relief reads
## even head-on, because the highlight has to flow around it.
##
##   relief_kind  0 flat · 1 linen weave · 2 engine-turned rings ·
##                3 crosshatch etch · 4 pebble (value noise)
##   relief       DEPTH IN DEGREES: the steepest tilt the pattern gives the
##                surface normal. Degrees rather than an amplitude because the
##                card only presents 4 to 14 degrees of half-angle in total —
##                3 modulates the highlight, 22 scrambles it into drawn lines.
##                The shader converts to a height for whatever the pitch is.
##   relief_scale the pattern's period in CARD pixels, not texels — a 3.4px
##                weave stays 3.4px whatever the render scale.
##   grain        fibre, in the same degrees, at grain_scale's finer period.
##                Keep the period at or above ~1.8 card px: the stage renders
##                at 2x, so anything finer falls under Nyquist and stops being
##                texture — it survives only as a brightness bias, measured at
##                +11 of 255 on a 1.1px grain that showed no visible tooth.
const TEXTURE: Dictionary = {
	"smooth": {
		"relief": 0.0, "relief_kind": 0, "relief_scale": 8.0,
		"grain": 0.8, "grain_scale": 1.8,
	},
	"tooth": {                                 # uncoated paper's own fibre
		"relief": 1.8, "relief_kind": 4, "relief_scale": 7.0,
		"grain": 2.5, "grain_scale": 1.8,
	},
	"linen": {                                 # woven card stock
		"relief": 3.0, "relief_kind": 1, "relief_scale": 3.4,
		"grain": 1.5, "grain_scale": 1.8,
	},
	"soft-touch": {                            # velvety, almost rubbery
		"relief": 1.5, "relief_kind": 4, "relief_scale": 5.0,
		"grain": 2.2, "grain_scale": 1.8,
	},
	"engine-turned": {                         # guilloche, as on a watch dial
		"relief": 1.4, "relief_kind": 2, "relief_scale": 5.5,
		"grain": 0.6, "grain_scale": 1.8,
	},
	"cross-etch": {                            # etched foil's cut hatching
		"relief": 2.0, "relief_kind": 3, "relief_scale": 4.2,
		"grain": 0.8, "grain_scale": 1.8,
	},
	"glassy": {                                # nothing at all to feel
		"relief": 0.0, "relief_kind": 0, "relief_scale": 8.0,
		"grain": 0.0, "grain_scale": 1.0,
	},
}

## ── LAYER 3: FINISH ──────────────────────────────────────────────────────
## The coating. Everything here is a way of returning light, and every one of
## them is angle-gated — which is why the card must be touched to show them.
##
##   sheen/tight  the specular lobe: strength, and how tight. Both are set in
##                LINEAR light, where the card's own stock sits at about 0.006
##                and its text band at 0.020 — so 0.075 is a real sheen and 0.3
##                is metal, not a mistake. `tight` is the exponent, and it has
##                to be in the hundreds: the card presents only 4.25 to 13.65
##                degrees of half-angle at rest, so anything under ~100 covers
##                the whole face and reads as a flat wash rather than a band.
##                Measured at these numbers, tight 900 lifts the face by 0.012
##                at rest and 0.139 when the card leans into the lamp — humble
##                until touched, which is the entire point.
##   aniso        -1..1 stretches the lobe along one card axis. Brushed metal
##                and satin are anisotropic; varnish is not.
##   holo         diffraction. A grating throws each wavelength to a different
##                angle, so sweeping the view sweeps the spectrum past the eye.
##                `holo_scale` is the grating pitch (cycles per unit sine),
##                `holo_dir` the groove direction in degrees.
##   pearl        thin-film interference: the path length through the film
##                grows as 1/cos(theta), so the colour rings AROUND the view
##                axis instead of banding across it. Softer, and radial —
##                that is how you tell pearl from holo at a glance.
##   sparkle      discrete flakes, each a microfacet with its own tilt, each
##                flashing over a few degrees only. `flake_px` is their pitch.
##   mask         0 whole face · 1 everything but the art (reverse holo) ·
##                2 the art window only · 3 the frame band (spot foil)
const FINISH: Dictionary = {
	"matte": {
		"sheen": 0.0030, "tight": 24.0, "aniso": 0.0,
		"holo": 0.0, "holo_scale": 6.0, "holo_dir": 0.0,
		"pearl": 0.0, "pearl_scale": 62.0,
		"sparkle": 0.0, "flake_px": 4.0, "mask": 0,
	},
	"smooth-matte": {
		"sheen": 0.012, "tight": 90.0, "aniso": 0.0,
		"holo": 0.0, "holo_scale": 6.0, "holo_dir": 0.0,
		"pearl": 0.0, "pearl_scale": 62.0,
		"sparkle": 0.0, "flake_px": 4.0, "mask": 0,
	},
	"satin": {
		"sheen": 0.03, "tight": 260.0, "aniso": 0.35,
		"holo": 0.0, "holo_scale": 6.0, "holo_dir": 0.0,
		"pearl": 0.0, "pearl_scale": 62.0,
		"sparkle": 0.0, "flake_px": 4.0, "mask": 0,
	},
	"gloss": {
		"sheen": 0.056, "tight": 900.0, "aniso": 0.0,
		"holo": 0.0, "holo_scale": 6.0, "holo_dir": 0.0,
		"pearl": 0.0, "pearl_scale": 62.0,
		"sparkle": 0.0, "flake_px": 4.0, "mask": 0,
	},
	"metallic": {
		"sheen": 0.08, "tight": 900.0, "aniso": 0.50,
		"holo": 0.0, "holo_scale": 6.0, "holo_dir": 0.0,
		"pearl": 0.0, "pearl_scale": 62.0,
		"sparkle": 0.036, "flake_px": 3.2, "mask": 0,
	},
	"pearlescent": {
		"sheen": 0.02, "tight": 200.0, "aniso": 0.0,
		"holo": 0.0, "holo_scale": 6.0, "holo_dir": 0.0,
		"pearl": 0.03, "pearl_scale": 62.0,
		"sparkle": 0.03, "flake_px": 4.5, "mask": 0,
	},
	"holo": {
		"sheen": 0.024, "tight": 300.0, "aniso": 0.0,
		"holo": 0.036, "holo_scale": 6.0, "holo_dir": 0.0,
		"pearl": 0.0, "pearl_scale": 62.0,
		"sparkle": 0.0, "flake_px": 4.0, "mask": 0,
	},
	"rainbow": {
		"sheen": 0.028, "tight": 260.0, "aniso": 0.0,
		"holo": 0.045, "holo_scale": 13.0, "holo_dir": 24.0,
		"pearl": 0.0, "pearl_scale": 62.0,
		"sparkle": 0.0, "flake_px": 4.0, "mask": 0,
	},
	"reverse-holo": {
		"sheen": 0.02, "tight": 200.0, "aniso": 0.0,
		"holo": 0.039, "holo_scale": 7.5, "holo_dir": 0.0,
		"pearl": 0.0, "pearl_scale": 62.0,
		"sparkle": 0.0, "flake_px": 4.0, "mask": 1,
	},
	"spot-foil": {
		"sheen": 0.104, "tight": 900.0, "aniso": 0.40,
		"holo": 0.0, "holo_scale": 6.0, "holo_dir": 0.0,
		"pearl": 0.0, "pearl_scale": 62.0,
		"sparkle": 0.0, "flake_px": 4.0, "mask": 3,
	},
	"prismatic": {
		"sheen": 0.048, "tight": 600.0, "aniso": 0.0,
		"holo": 0.03, "holo_scale": 9.0, "holo_dir": 0.0,
		"pearl": 0.024, "pearl_scale": 78.0,
		"sparkle": 0.054, "flake_px": 3.6, "mask": 0,
	},
	"cosmos": {
		"sheen": 0.032, "tight": 400.0, "aniso": 0.0,
		"holo": 0.024, "holo_scale": 17.0, "holo_dir": 0.0,
		"pearl": 0.0, "pearl_scale": 62.0,
		"sparkle": 0.084, "flake_px": 2.4, "mask": 0,
	},
	"dead": {                                  # the coating that gives nothing
		"sheen": 0.0015, "tight": 12.0, "aniso": 0.0,
		"holo": 0.0, "holo_scale": 6.0, "holo_dir": 0.0,
		"pearl": 0.0, "pearl_scale": 62.0,
		"sparkle": 0.0, "flake_px": 4.0, "mask": 0,
	},
}

## ── LAYER 4: STOCK ───────────────────────────────────────────────────────
## The body. None of this is a shader channel — stock is the one layer you
## read without light, which is why it belongs with the others rather than
## being folded into the finish.
##
##   thick    the slab's real thickness in px (~0.4 mm each, at card scale)
##   cut      how the edge was worked, straight into card_edge.gdshader:
##            0 raw · 1 cut · 2 polished · 3 gilt · 4 leaden
##   shadow   weight. A heavier card sits harder on the table.
##   spring   (omega, zeta) for the RELEASE settle. This is rigidity, and it
##            is the one property you feel rather than see: thin stock wobbles
##            back with a long, loose ring; a rigid plastic card stops dead.
const STOCK: Dictionary = {
	"thin": {"thick": 5.0, "cut": 0, "shadow": 0.85, "spring": Vector2(9.0, 0.45)},
	"standard": {"thick": 7.0, "cut": 1, "shadow": 1.00, "spring": Vector2(11.0, 0.55)},
	"premium": {"thick": 9.0, "cut": 2, "shadow": 1.12, "spring": Vector2(13.0, 0.62)},
	"gilded": {"thick": 10.0, "cut": 3, "shadow": 1.20, "spring": Vector2(13.5, 0.66)},
	"rigid": {"thick": 12.0, "cut": 2, "shadow": 1.25, "spring": Vector2(17.0, 0.80)},
	"cursed": {"thick": 8.0, "cut": 4, "shadow": 1.35, "spring": Vector2(7.5, 0.35)},
}

## ── THE STACK ────────────────────────────────────────────────────────────
## A recipe names one entry per layer. The six above the rule are what the
## game deals today; everything below it is stocked and unused — a card gets
## one by naming it, and nothing about rarity has to move.
const RECIPES: Dictionary = {
	"plain": ["pulp", "tooth", "matte", "thin"],
	"card": ["stock", "smooth", "smooth-matte", "standard"],
	"satin": ["glass", "linen", "satin", "premium"],
	"gilt": ["gold-leaf", "engine-turned", "metallic", "gilded"],
	"velvet": ["stock", "soft-touch", "matte", "premium"],
	"leaden": ["lead", "tooth", "dead", "cursed"],
	# ──
	"holofoil": ["silver-leaf", "cross-etch", "holo", "gilded"],
	"rainbow": ["silver-leaf", "smooth", "rainbow", "gilded"],
	"reverse": ["stock", "smooth", "reverse-holo", "premium"],
	"pearl": ["nacre", "smooth", "pearlescent", "premium"],
	"cosmos": ["silver-leaf", "cross-etch", "cosmos", "gilded"],
	"prism": ["glass", "engine-turned", "prismatic", "gilded"],
	"plastic": ["pvc", "glassy", "gloss", "rigid"],
	"crystal": ["acrylic", "glassy", "gloss", "rigid"],
	"spot": ["stock", "smooth", "spot-foil", "premium"],
}

## The DEFAULT only. Rarity picks a recipe here and has no other say — every
## resolution step below outranks it, and the recipes themselves know nothing
## about tiers. Point "rare" at "plastic" and rares are plastic; nothing else
## in the file needs to change.
const BY_RARITY: Dictionary = {
	"starter": "plain",
	"common": "card",
	"uncommon": "satin",
	"rare": "gilt",
	"special": "velvet",
}
## Type outranks rarity, the way curse already overrides the edge cut.
const BY_TYPE: Dictionary = {"curse": "leaden"}
## Authored exceptions, by card id. Empty by design: this is the seam for
## "this one card is the chase card", and it should stay visible when unused.
const BY_CARD: Dictionary = {}

const FALLBACK: String = "card"


## Which recipe a card wears. Highest authority first: whatever the content
## says, then the authored exception table, then type, then rarity.
static func recipe_of(id: StringName, data: Dictionary) -> String:
	var named: String = str(data.get("surface", ""))
	if RECIPES.has(named):
		return named
	if BY_CARD.has(String(id)):
		return str(BY_CARD[String(id)])
	var ctype: String = str(data.get("type", ""))
	if BY_TYPE.has(ctype):
		return str(BY_TYPE[ctype])
	var rarity: String = str(data.get("rarity", ""))
	return str(BY_RARITY.get(rarity, FALLBACK))


## Fold a recipe's four layers into one flat parameter set. Layers own
## disjoint keys, so this is a plain merge and the order cannot matter — the
## assert is there to keep it that way if someone adds a key to two tables.
static func params(recipe: String) -> Dictionary:
	var stack: Array = RECIPES.get(recipe, RECIPES[FALLBACK])
	var out: Dictionary = {}
	for pair: Array in [[MATERIAL, stack[0]], [TEXTURE, stack[1]],
			[FINISH, stack[2]], [STOCK, stack[3]]]:
		var table: Dictionary = pair[0]
		var layer: Dictionary = table[pair[1]]
		for k: Variant in layer:
			assert(not out.has(k), "surface layers overlap on '%s'" % str(k))
			out[k] = layer[k]
	return out


## The slab's cross-section: the material's own colour, pulled toward the
## card's type tint by however much of the glass conceit it carries.
static func body_color(p: Dictionary, tint: Color) -> Color:
	var base: Color = p["body"]
	var toward: float = p["body_tint"]
	var dark: float = p["body_dark"]
	return base.lerp(tint, toward).darkened(dark)


## Push the optical layers at the face shader. The three non-optical stock
## properties (thick, shadow, spring) are read by the slab directly and are
## deliberately absent here.
static func apply(mat: ShaderMaterial, p: Dictionary, tint: Color) -> void:
	mat.set_shader_parameter("tint", tint)
	for key: String in ["ink", "ink_tint", "soak", "bleed",
			"relief", "relief_kind", "relief_scale", "grain", "grain_scale",
			"sheen", "tight", "aniso", "holo", "holo_scale", "holo_dir",
			"pearl", "pearl_scale", "sparkle", "flake_px", "mask"]:
		mat.set_shader_parameter(key, p[key])
