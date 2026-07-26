# Concepts

Shared domain vocabulary for this project — entities, named processes, and
status concepts with project-specific meaning. Seeded with core domain
vocabulary, then accretes as ce-compound and ce-compound-refresh process
learnings; direct edits are fine. Glossary only, not a spec or catch-all.

## Card surface

### Recipe
A named stack of exactly four layers — one Material, one Texture, one Finish,
one Stock — that fully describes how a card's face renders. Recipes are the
only named surfaces; the layers themselves are anonymous ingredients.

A Recipe knows nothing about rarity. Rarity picks a default Recipe and has no
other say — card type, card id, and the card's own data each outrank it. Naming
a new Recipe costs one table entry, which is why the catalogue is far wider than
the set the game ships.

### Material
The layer answering *what the card is made of* — paper, glass, gold leaf, lead.
It owns the colour light comes back as, what the body does to light that gets
inside it, and the colour of the cut edge.

### Texture
The layer answering *how the surface breaks* — the relief pattern light has to
travel over. Tooth, weave, and engine-turning are Textures; they say nothing
about coating.

### Finish
The layer answering *what coating sits on the surface* — how tight the highlight
is, whether the coating sparkles, diffracts, or gives nothing back. Finish is
the layer that carries a card's optical character, and the one most requests are
really about.

### Stock
The layer answering *what grade the body is* — thickness, cut, weight, rigidity.
Alone among the layers it also carries non-optical properties the physical slab
reads directly rather than the surface shader.

### Layer disjointness
The invariant that no two layer catalogues own the same parameter key. It is
what makes folding a Recipe's four layers a plain merge in which order cannot
matter, and it is asserted rather than assumed: a new Texture cannot quietly
change how a Finish reflects.

### Lamp
The single point light that stands in the card's own space and follows the
cursor while a card is hovered. It is a light in a room, not a painted glare —
the same geometry that lights the surface lights the gem and the edge.

Hover is expressed as the Lamp's gain rather than as a separate state, so a
card at rest is lit only by ambient room light. A Finish that answers strongly
to the Lamp and weakly to the room reads as foil; the reverse reads as varnish.

### Holo
Depth, not colour. A holo Finish puts its bright points at a spread of depths
below the face, so turning the card slides the deep ones through the shallow
ones. That differential motion is the whole effect.
*Avoid:* using "holo" to mean rainbow or spectral colour — see Flagged
ambiguities.

### Angle, not time
The standing rule that every surface channel is a function of geometry — view
vector, surface normal, the card's own axes — and never of elapsed time. A card
freezes its offscreen viewports when it comes to rest, so anything driven by
time would silently stop; a real material is a function of angle anyway.

---

## The actor

### Actor
A painted combatant standing on the battlefield at its own true size. Both foes
and the player's hero are actors — they differ in which side they fight for, not
in how they are built or drawn.

An actor's rectangle *is* its art box, and the bottom edge of that rectangle *is*
the creature's feet. Nothing is drawn inside a frame or panel around it. That
identity is load-bearing in two directions: targeting hit-tests the rectangle,
and placement aligns the bottom edge to the ground line.

### Art box
The square region an actor occupies, resolved from its Tier and a per-character
scale factor. The painting is fitted inside the box by height and centred
horizontally, so a painting narrower than the box is letterboxed rather than
stretched — the box is the actor's footprint for layout and targeting, not a
claim about the painting's shape.

### Ground line
The horizontal line an encounter's actors stand on. Feet meet it; chrome hangs
above and below it. Actors of wildly different sizes share one ground line rather
than being centred against one another, which is what lets a size ladder read at
a glance.

### Foot offset
A per-character correction that slides an actor off its computed position so the
painted creature's apparent feet land on the ground line even when the painting
carries empty space below or beside the body. It corrects the *art*, not the
layout — distinct from any lift the formation itself applies.

### Tier
An actor's size class, selecting the base size the Art box is built from before
the per-character scale is applied. Tiers cover ordinary foes, tougher ones,
encounter bosses, and the player's hero.

## The vessel and its breaking

### Vessel
An actor's body understood as stained glass holding light — the conceptual object
that cracks, ignites, and finally shatters. The Vessel carries the creature's
painting and its accumulated Cracks together, so a fracture scored into it cannot
drift off the creature it belongs to.

### Crack
A scored fracture site on a Vessel. Cracks accumulate as geometry that rides with
the body and determine how the Vessel breaks apart when the Death rite runs.
They are deliberately *not* driven by ordinary damage — the glass vocabulary is
spent on death rather than on attrition, so a wounded creature does not visibly
craze.

### Death rite
The sequence that replaces a defeated actor: the Vessel strains, the fire inside
wells up through its fractures, the body breaks apart, and the pieces cool and
crumble away.

Its defining rule is the **handoff** — the standing Vessel must disappear in the
*same* frame its pieces appear. Any overlap in which an intact body is still
visible behind its own falling debris reads to a viewer as "a pane in front of
the creature broke and the creature left," which is the wrong event. For the same
reason every piece carries the patch of painting it covered rather than being
blank glass, and no debris is left standing once the rite completes.

## Combat state carried by an actor

### Status
A named condition stacked on a combatant, carrying a count and persisting across
turns until it expires or is spent.

Statuses are named for states of *glass* or of *light* rather than for their
mechanics — annealed, vitrified, brittle, cracked, dimmed, smouldering. The
vocabulary is deliberate and worth preserving when new ones are added; a status
named after its numeric effect would be the odd one out. A single stack displays
without a count, because a "1" on every condition is noise a crowded row cannot
afford; the number appears only once there is more than one.

### Facet
A unit of an enemy's structural integrity, drawn as a row of glass panes. A facet
that has been chipped has gone dark; an unchipped facet still holds its light.
Past one row the gauge stops being countable and reads as a number instead.

### Ward
Temporary protection that absorbs damage before health does, shown as a painted
lock beside the health vial. Absent rather than zero when a combatant has none.
*Ward* is the word the game shows the player; *block* is the word the rules and
the card data use for the same value.

### Intent
The move an enemy has telegraphed for its next turn, shown above the actor. It is
pushed to the actor by the combat sequencer rather than read from combat state —
an actor never inspects the game itself.

An intent may name more than one action at once. When it does the first action is
the **primary**: it decides the single colour the entire telegraph is tinted, and
the further actions are shown alongside it rather than each carrying their own
colour. A compound intent is therefore one telegraph in one colour, not several
stacked — treating it as a fallback for "unknown intent" is a misreading.

---

## The port

### Benchmark
The frozen web build this project is a parallel port of, and the reference any
ported behaviour is diffed against. It is authority for *what* the game does and
for measured presentation values — not for *how* those are achieved. A shape the
web build was forced into by its own platform carries no authority here.

Its combat screen and this project's viewport are the same size, so measured
values transfer with no scaling step. That coincidence is what makes parity
checkable, and it is also what tempts a port to carry structure across along
with the numbers.

### Lab
A harness that stands one widget family up in isolation — no run, no game state
behind it — reached by its own launch flag rather than by playing to the screen
that uses it. Each presentation area has one.

A Lab is not a screenshot rig. It exists so a surface can be judged and tuned
against the Benchmark without playing a run to reach it, and so a change meant
to alter nothing can be *proven* to have altered nothing — render every state
before, render them after, diff them numerically. Values dialled in a Lab are
not real until they are written back into the widget itself; the Lab holds no
state of its own between launches.

Labs come in two shapes, and the difference decides which one a task wants. A
*contact sheet* renders every item at once so they can be compared against each
other; a *bench* renders a single item with live controls so it can be tuned.
Two traps come with the territory: a Lab may scale what it shows for
inspection, which makes a magnified Lab screenshot the wrong evidence for
judging sharpness — judge at actual size; and a Lab needs a real viewport to
capture from, so a headless run can parse-check its code but cannot photograph
it.

---

## The player's resources

### Pile
One of the three collections a card can sit in during a fight: the one cards are
drawn from, the one spent cards fall into, and the one cards removed from the
fight end in. The third is called *ashes* where the player sees it and *exhaust*
where the rules do.

A Pile draws itself as a fan of card backs, one visible face per card up to a
cap — so the fan is its own gauge, and the count beside it only carries
information once that cap is passed. An empty Pile keeps its name and its zero
and shows no faces.

### Candle
One point of the resource cards are paid for with, refilled every turn rather
than accumulated. A turn's budget is a row of Candles; spending one puts it out,
and the whole row is relit when the next turn begins.

---

## The reward

### Spoils
The part of a combat reward that is handed over rather than chosen — the gold,
and any potion or relic the fight paid out. Spoils are announcements, not a
menu: nobody declines gold, so rendering them as choices spends the player's
attention on a decision that does not exist.

### Offering
The cards laid out after a fight for the player to take one of, or none at all.
It is the only real decision a reward contains, and so outranks the Spoils for
space and attention however the screen is drawn. A fight may make no Offering;
a reward that is Spoils alone is an ordinary outcome, not a degenerate one.

---

## Flagged ambiguities

- **"Holo" had been used for both depth and rainbow colour — these are
  distinct.** Holo is the depth cue (points at different depths sliding past
  each other under tilt). Spectral colour is a separate, independent channel a
  Finish may or may not carry. A Finish can be holo without being rainbow, and
  rainbow without being holo.
- **Two different lights, both "in the object's own space" — the Lamp is not the
  actor's key.** The Lamp belongs to a card and follows the cursor while that
  card is hovered. An actor's stage is lit by a fixed key and rim that do not
  track the pointer; the actor's cast shadow is a projection along that key.
- **An enemy is an Actor, not a card.** Earlier work drew enemies as card-like
  placards; that framing is retired. The procedural gem survives only as the
  fallback avatar when a painting is missing, and as the world map's emblem.
- **"Reward" had been used for both the whole bundle and the card choice — these
  are distinct.** A reward is Spoils plus an Offering, and only the Offering is
  chosen. Treating the two as one uniform list is what produces a screen asking
  the player to click three times to acknowledge news.
