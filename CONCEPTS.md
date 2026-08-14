# Concepts

Shared domain vocabulary for this project — entities, named processes, and
status concepts with project-specific meaning. Seeded with core domain
vocabulary, then accretes as ce-compound and ce-compound-refresh process
learnings; direct edits are fine. Glossary only, not a spec or catch-all.

## Developer tooling

### Developer Console
A development-only scenario orchestrator that places a valid, deterministic
run at a named player-facing state through the game's real routing seams. It is
a navigation and inspection convenience, not a place to author content. It is
not release evidence except for the endgame surfaces named in the RC bar's P5
clause.

### Dev Review build
An internal Web, native or signed-mobile build carrying the explicit
`dev_tools` capability and a visible Developer Console entry. It exists for
review and diagnosis; a store or release-candidate build never carries that
capability or entry point.

### Scenario
A named, versioned recipe for reaching one deterministic player-facing state.
It has a stable identity and declares its seed, locale and valid run/route
inputs, so two reviewers asking for the same Scenario mean the same setup. A
Scenario is constructed through production seams rather than by editing live
screen nodes or raw state.

### Scenario reference
The portable identity of one reproducible Scenario invocation: its stable ID
and revision, product build, seed, locale, Stage shape and bounded overrides.
It describes how to reconstruct the state rather than carrying a save blob. A
reference whose revision is no longer supported fails explicitly instead of
silently acquiring newer semantics.

### Custom Scenario
A Scenario assembled from the Console's bounded gameplay controls rather than
from a catalogue entry. It still produces a valid run through production seams;
it is not an editor for raw save dictionaries, RNG cursors or live screen
nodes.

### Synthesised history
The coherent completed path constructed before a Scenario enters a requested
map node. It preserves route and checkpoint invariants but makes no claim that a
player performed those earlier actions.

### Development profile
The persistence boundary used by the Developer Console. Its checkpoints are
disjoint from a player's ordinary run and Vigil, so starting, altering or
restarting a Scenario cannot contaminate player progress.

### Authoring Lab
An isolated tool for inspecting and editing one authored presentation or
content subject. A Lab may construct production UI, but it does not stand in for
the routed game or for release evidence.

### Gate
A check whose purpose is to fail when a defect is present, so that its passing
is evidence rather than habit.

A gate is only as good as the signal it reads. One wired to a signal that cannot
express the failure passes for reasons unrelated to correctness, and is
indistinguishable from a working gate until something else catches the defect.
Two forms recur: the signal is silent about the failure, and the trigger
condition is narrower than the set of ways the thing can fail. Both read green,
so a gate is not trusted until it has been watched failing on a seeded defect in
the environment it guards. When a gate cannot run somewhere, that is stated
rather than allowed to pass.

### Evidence Harness
A tool that records or verifies a named gate under its declared conditions.
Evidence from a Harness keeps its own proof boundary; reaching the same surface
through the Developer Console does not inherit that evidence — except the
endgame surfaces named in `docs/rc-bar.md` P5, which may be signed on a Dev
Review build reached through the Scenario kernel. That exception is an
amendment of the sign-off protocol, not a waiver of any criterion, and it does
not make Console-reached states evidence for any other surface.

### Diagnostic overlay
A development-only live performance readout used to spot and reproduce likely
problems. Its numbers guide investigation but are never release evidence; an
Evidence Harness performs the release measurement.

## The release

### RC bar
The single checkable document a release-candidate build must clear, composing
the rubric sign-offs, the performance floor, the on-device QA and save-integrity
protocols, the beta round, and the compliance checklist into one falsifiable
gate. The bar is the measure; the release gate is the act of holding one named
build against it. A bar instantiates per platform wave — the same pillars,
that wave's floor devices.

### Twin build
A development-signed build of the exact release-candidate commit and the exact
release export configuration, differing from the RC artifact only in signing
identity. It exists because distribution signing denies evidence access (the
app container, byte-level save fingerprints); it is not a Dev Review build —
it carries no `dev_tools` — and evidence captured on it must state that it was.

### RC signature receipt
The signed comment that pronounces a build the release candidate, binding the
exact product head, the artifact hash, and every pillar's evidence address. A
verifier passing proves the evidence clears the gate; the signature is the
distinct human approval — the two are never merged.

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

One line serves the whole encounter, and it is a layout decision — it says where
actors are placed, not what any individual painting depicts. Where a given
creature's own art touches down is its Contact line.

Where the line sits is authored per Stage shape and per act rather than held as
one constant. It is a distance from the stage's bottom edge — an Edge binding —
so a taller stage lowers nothing.

### Stage px
The virtual coordinate space every authored layout number in this project is
written in, and the only space in which the port and the reference are comparable.
*Avoid:* virtual px, design px, logical px

Real pixels are not it: the stage is scaled uniformly into whatever window is
holding it, so a number that is right in stage px stays right on a phone and on a
monitor. The conversion happens once, at the boundary — a pointer coming in, a
measurement going out — and mixing the two spaces anywhere else is how a
composition that looks aligned turns out to have its input somewhere else.

Both sides of a parity check must be read into this space before they are
compared. Comparing a port's source against the reference's source instead is
what lets a layout store that neither source declares go unnoticed.

### Layout book
The single authored store of layout numbers: every Stage shape, every act, every
scope, under one declared schema.
*Avoid:* layout table, layout data, BF/UIC

Singular on purpose. The reference keeps the same information in several stores
with a separate editor and an implicit schema for each, which is why it has two
editors for one screen and a third body of numbers with no editor at all. One
book with the schema declared as data means the resolver's defaults, the
validator, the flex correction and the editor's widgets all read from the same
declaration, and a new scope costs an entry rather than a serialiser.

A number's presence in the book is what makes it authorable, checkable and
visible to an editor. A layout number kept anywhere else is not merely
inconsistent — it is unreachable by every tool that would otherwise notice it was
wrong or missing.

### Stage shape
An authored screen composition for an encounter, selected by device class and
orientation. A Stage shape is a design reference rather than a frame the game
is locked into: the real window stretches the stage along one axis to meet it,
up to a cap, and letterboxes only past that.

One landscape composition is the identity shape, and that is load-bearing
rather than incidental. Every measured number this port carries was read at
that size, so a composition that stops resolving to it one-to-one has quietly
invalidated every Anchor in the repo at once.

A shape says nothing about what device is holding it. Device class — phone, pad,
desktop — is a separate question answered from the platform name and the physical
diagonal, and it decides which shapes a window is even allowed to be given.

### Edge binding
Which edge of the stage a layout number is measured from, and therefore what
happens to it when the stage flexes. A value bound left or top keeps its number;
one bound right or bottom keeps its distance from that edge; one bound to the
centre keeps its offset from the middle.

Most authored numbers are already distances and survive a wider stage untouched.
The few that are absolute coordinates — the hero's seat and each foe slot — carry
a binding precisely so extra width opens the gap BETWEEN the two lines rather
than being split arbitrarily or spent on one of them.

Deliberately not called an anchor. That word is already taken here by a
`file:line` citation and by the engine's layout anchors; see *Flagged
ambiguities*.

### Authoring level
One of the three places a layout number may be written: the base that every
Stage shape inherits, one shape's own override, or one act's override within that
shape. A resolved number is the innermost level that supplies it, and *origin* is
the name for which level that turned out to be.
*Avoid:* bucket, tier

Two rules make the level worth naming rather than treating as an implementation
detail. Objects merge key by key, but **arrays replace whole** — so a level that
touches one seat in a formation has taken ownership of every seat in it, and
reverting one number reverts the formation. And editing a number that came from
an outer level does not move it; it *promotes* it, creating an override that
every later change to the outer level will silently no longer reach. Origin is
therefore something an editor must show before an edit, not after.

A number present at no level at all is not the same as a number set to zero. An
unauthored value may legitimately mean "use the actor's own", so absence is
carried rather than filled, except where the schema declares a default.

### Natural size
The size a piece of furniture is DRAWN at, as distinct from the box the layout
book gives it on a particular Stage shape. Every internal offset, font size and
icon inside a widget is authored against its natural size; the shape is spent
outside it, as one scale.
*Avoid:* base size, intrinsic size

The alternative is teaching every widget to lay itself out at any size, which is
as many chances to disagree as there are widgets — the same duplication the
single layout book exists to remove. So a card, a pile, the energy orb, the END
seal and an actor's foot plate are each built once, at the identity shape's
figures, and a scale carries the difference.

Two consequences that have already cost this port bugs. A piece scaled about its
own centre does not move that centre, so an expression that places one by
multiplying its half-size by the scale is correcting for a displacement that
never happens — and lands it half a shrinkage away. And a resting scale is a
*multiplier*, never a replacement: a lift, a drag and a flight all multiply it,
or they snap the thing back to its natural size mid-gesture.

### Foot offset
A per-character correction that slides an actor off its computed position so the
painted creature's apparent feet land on the ground line even when the painting
carries empty space below or beside the body. It corrects the *art*, not the
layout — distinct from any lift the formation itself applies.

### Contact line
Where a painting says its creature meets the floor, recovered from the painting's
own silhouette rather than declared. It is sampled across the width of the
painting, so a creature standing on several feet at several heights has a contact
line that steps and slopes rather than a single height.
*Avoid:* using "ground line" for this — see Ground line, which is a layout
concept shared by every actor in an encounter.

Not every low point of a silhouette is a contact: a belly between legs and a tail
hanging in the air are body, not footing. Only samples close to the lowest one
count as touching down, and the line is carried across the rest by interpolation.
A creature the art depicts as *already airborne* has no contact anywhere in its
silhouette, and the only signal that says so is authored — which is why one
authored shadow value survives the port's derivation of all the others.

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
A fracture propagated into a Vessel by a blow. Cracks accumulate as geometry that
rides with the body and determine how the Vessel breaks apart when the Death rite
runs.

Cracks **are** driven by damage: a hit scores fracture where it landed, so a
wounded creature visibly carries what has been done to it and the glass tells the
truth about the fight. What a Crack is not is *one line per hit* — a blow throws a
star of several arms, and how many it throws and how far they run are bought with
its energy, so a light hit leaves a short mark and a heavy one reaches across the
body. A Vessel caps recorded impacts for legibility; beyond the cap the body
would read as frosted rather than as broken. The cap is a presentation rule, not
a rule about combat.

The accumulated Cracks are the **only** thing the Death rite breaks along. It adds
no new pattern of its own — it releases what the creature was already carrying,
carrying every arrested crack tip the rest of the way out to the silhouette so the
network finally separates the body into pieces. A creature that died having been
hit twice breaks into few large shards; one that was worn down breaks into many.

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
Temporary protection that absorbs damage before health does. Absent rather than zero when a
combatant has none. *Ward* is the word the game shows the player; *block* is the rules' word.

It is rendered in two parts, and **bare "ward" names the protection, never either part** —
the parts have their own names because they are separately owned and separately timed:

- **Ward chip** — the numeral beside the health vial. A foe's belongs to the actor; the
  hero's belongs to the run chrome for as long as the hero has no actor plate of its own.
- **Ward stone** — the regular faceted gem shell held in front of the creature, showing
  manufactured order against the glass's natural cracks. It flashes when struck and
  shatters as an expanding ring.

The stone belongs to the **Actor**, and so to the hero exactly as much as to a foe — one
class draws both, and a guarded hero raises, rings and breaks the same stone a guarded foe
does. It is not a foe-only affordance, and reading it as one is how a hero-side gap goes
unnoticed.

The two parts do not share a clock. The chip appears and vanishes on the instant the
number changes; the stone takes time to cut itself in, to answer a blow it stopped, and to
break. Each of those is its own beat with its own duration, so a still frame can agree
with the number and still be wrong about the stone.

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

### Compensation
A value or shape in the reference material that exists to work around a limit of
the platform it was authored on, rather than to express an artistic decision.
*Avoid:* calling these "the reference values" without sorting them.

One question sorts them: if the source could have computed this, would the
number still exist? If it would not, it is a Compensation and the port derives
it from whatever the source lacked; if it would, it is a design decision and the
port carries it across unchanged. The distinction has a structural form as well
as a numeric one — a shape can be a Compensation when the source platform had no
other way to express it. Deriving is not the same as obeying physics: derive the
shape, then clamp it for art direction.

That clamp is not independent of the derivation it clamps. It is expressed in the
units of a derived quantity and was judged against whatever that quantity meant at
the time, so correcting a systematic error in the derivation changes what the
clamp asks for. Preserving an approved look across such a correction means
restating the clamp by the same factor; leaving its numbers untouched changes the
look while appearing to hold it steady.

### Census
An exhaustive enumeration of one declarative surface of the Benchmark, turned
into a fixed set of yes/no questions for the port, so that divergences are
counted instead of noticed.
*Avoid:* calling an audit a Census when it sampled rather than enumerated.

A Census is only possible where the reference states the behaviour declaratively
— a stylesheet's transitions and animations enumerate; a canvas draw loop does
not. Its value is the denominator: once the set is finite, "how much of this
surface is unimplemented" has an answer rather than an impression, and missing
work separates from hard work, because several absences turn out to be a call to
something the port already has. Three traps sit inside the enumeration, and the
first two cost a wrong Verdict before they were named. A declaration can be
switched off by a later unconditional one, so its presence is not evidence that
it ever runs. And a declaration is worth only what triggers it — a transition on
a property nothing ever changes is a no-op that will otherwise rank high on
effort it does not deserve.

The third is the one that costs no Verdict at all, which is why it is the worst.
An enumeration can silently under-enumerate: a declaration the extraction never
matched has no row, and a Census with a missing row reads exactly as complete as
one without. A wrong Verdict is visible in the table and argues for itself; an
absent row argues for nothing. So the denominator a Census buys is completeness
over what the extraction matched, not over the surface — which makes it a floor
rather than a total until the row count has been reconciled against a raw count
of the surface itself.

Every Verdict in a Census carries quoted port code and its location; one with no
evidence is discarded rather than believed. What a Census cannot settle is
whether a matching value is attached to the thing the player actually watches —
that still wants a Live host and a look. And the look has preconditions of its
own: it must be at a surface that drives the subject the way a fight does, in a
mode that shows the shape being checked. A look is worth only what the surface
being looked at is worth.

### Verdict
The judgement a Census records against one declaration of the Benchmark.

Six values. *Match* is the one that needs no explanation — the port does the
thing with the same numbers — and the distinctions that matter are between the
other five, which look alike in pairs. *Absent* means the port is missing
something the reference shows; *not
applicable* means the reference never shows it either, or it drives a renderer
this port replaced — reporting the second as the first is the most common way a
Census manufactures work. *Diverges* means the port does the thing with other
numbers; *diverges, documented* exists so a deliberate departure the port
explains in its own comments is not re-raised as a defect on every pass.
*Unresolved* is not a softer absence: it means the question was answered about
the wrong element, and it is held open rather than guessed.

### Lane
One concurrent line of work on this project, holding its own branch or worktree
over the single shared tree and owning a declared subset of files while it runs.

Lanes are why a line number written correctly goes stale in hours rather than
months: several are editing the same directories at once, and none of them sees
another's work until it lands. Ownership is declared per file, not inferred — a
Lane reads anything and writes only what it owns. Two rules follow. A Lane does
not re-anchor a citation against another Lane's uncommitted work, because the
number it would write is true only until that work changes shape. And a Lane
holding edits to a shared document grows more out of date the longer it holds
them, so what the shared tree currently says must be re-read before appending
rather than assumed from the branch's own copy.

### Noise floor
How far two captures of the *same* build differ, and therefore the bar a
before/after comparison has to clear before it is evidence of anything.
*Avoid:* margin of error, tolerance

Every screen here animates — embers drift, actors breathe, a hand deals itself
in — so two photographs of an unchanged build are never identical, and the
difference between them is not small. Established by capturing the same build at
least three times under the same seed and arguments and measuring every pair; a
change smaller than the result distinguishes nothing, and a change concentrated
in one region of the frame means more than a larger one spread evenly across it.

Three captures rather than two, because a single pair cannot tell a floor from a
coincidence. Where the motion is phase-bound, two captures that happen to land in
the same phase agree closely and read as a tight floor, while either of them
against a third differs by an order of magnitude more.

The floor is a property of *how* the capture was taken, not a constant. Catching
a screen mid-entrance rather than at rest raises it by two orders of magnitude,
which is enough to swallow most layout changes whole — so the settling is part of
the measurement, and a floor quoted without the capture conditions that produced
it says nothing. It is also a property of the screen and the sitting: a floor
measured on one screen governs only that screen, and re-measuring the same screen
later can return a different band.

Some screens have no floor at all. Settling works because an entrance *finishes*;
a continuously drifting scene never reaches rest, so its same-build spread is
bimodal rather than a band, and no amount of waiting narrows it. When that
happens the comparison is not a weak gate to be tightened — it is not a gate, and
the honest move is to state that plainly and gate the change somewhere it is
deterministic instead, above the renderer. The capture is still taken; it is
answering a different question.

### Anchor
A citation in prose that names a code file and a symbol, optionally with a line
or range; the optional location can rot silently when code moves.

Anchors are checked mechanically rather than trusted, because the failure is
invisible from the prose side: the sentence still reads correctly while the line
it points at has become something else entirely.

Know what the mechanical check actually proves. It verifies that a citation's
line and its symbol annotation agree with each other; it cannot know what the
surrounding *prose* claims is there. An Anchor naming the wrong function, and the
line that function happens to start on, is internally consistent and passes clean
— one was found citing a line in one function for a snippet that lived twenty-one
lines later in another. A green run means no Anchor has rotted, not that every
Anchor points where its sentence says. Only reading the cited line against the
sentence establishes that.

A green run is also quieter than it looks, because whole classes of Anchor go
unexamined, and every one of them reads as checked. A citation carrying no
symbol annotation is not validated at all by default, so it may point anywhere
and still pass. An Anchor into another prose document is invisible to the check
entirely — only citations into code are recognised as Anchors at all. A citation
that names no file, only a line, is skipped for the same reason even when it
carries a symbol, which makes it the most trustworthy-looking of the lot. And an
Anchor whose annotation says only that the line falls *inside* a named function
keeps passing as that function grows, so drift within a long body is never
reported at all.

The pattern behind those is worth more than the list: the checker recognises a
fixed set of citation spellings, so a spelling it does not know is a spelling it
silently approves. Three such classes have been found and closed on separate
occasions, each after a clean run had certified work nobody had looked at. The citations documents make about each other are
therefore the least checked and the most quietly wrong, which is the opposite of
how a clean report reads.

There is a third class, and it is the one that made "a green run means no Anchor
has rotted" untrue rather than merely incomplete. An Anchor that names only a bare
filename can be resolved only while that name is unique in the tree; the moment a
second copy exists anywhere — a scratch checkout, a vendored duplicate — the
citation becomes ambiguous, and the check has no way to guess which was meant. It
was passing over those in silence, so a large share of the corpus was being
certified without ever being read. An Anchor should therefore carry its full
path, not just a filename, and an ambiguous one should be reported rather than
skipped. A check that cannot see a claim must say so; the danger is not the
unchecked Anchor, it is the clean report over it.

An Anchor has two halves and they do not age alike. The symbol is durable: over a
day of ordinary work on the most-edited files, none of roughly nine hundred were
renamed or removed, while up to nearly all of their line numbers moved. The line
is therefore not a second fact but a cache of the first, which is why the repair
tooling regenerates it from the symbol and never the other way round. The
preferred form names the file and the symbol and no line at all, leaving nothing
that can go stale; a line is written only when the line itself is what the
sentence is about, or when the thing cited has no symbol to name. The older
line-carrying form stays valid and stays checked.

Two further consequences follow. An Anchor that drifts is repaired by moving the
citation to where its subject went,
never by editing the subject to match the citation. And drift caused by another
lane's work in progress is left alone — re-anchoring against an uncommitted tree
writes a claim that is false the moment that work changes shape.

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
Several traps come with the territory. A Lab may scale what it shows for
inspection, which makes a magnified Lab screenshot the wrong evidence for
judging sharpness — judge at actual size. A Lab needs a real viewport to
capture from, so a headless run can parse-check its code but cannot photograph
it. A Lab may not *dress* its subjects the way production dresses them: it
stands the widget up itself, so every call the shipping screen makes between
construction and first paint has to be made here too — **and with the arguments
production passes**, since a Lab that hands the subject a constant where the
game derives a value is testing a premise it supplied itself — or the Lab is
certifying
an object the game never builds. And a Lab's set of capture modes bounds what
can be found *missing* — a category of behaviour with no mode is invisible
rather than absent, which is a stronger failure than a wrong value, because
nothing ever raises it. Its capture range matters too: a value the surface
cannot resolve is invisible even when the right frame was sampled. Finally, a
Lab inherits the timebase of what it verifies, so a clock knob only reaches the
clocks the engine owns.

Scaling, viewport and capture range distort what a Lab shows; production
driving, capture modes and timebase decide whether it is showing production at
all. "A change meant to alter nothing can be proven to have altered nothing"
holds only of a Lab that is.

### Live host
A single game process kept running out of sight for a whole working session, so
that photographing a screen — a Lab or a real run — costs no window of its own
and does not take the desktop. Distinct from a one-off capture, which starts,
photographs and quits; the host starts once and is then driven capture by
capture. It does hold a visible window the whole time — an attempt to park it
off the desktop is refused by the platform — and its one start still takes the
desktop briefly. The saving is *per photograph*: one interruption a session
rather than one a shot, not an absence of one.

A host re-reads the project's code and rebuilds the screen on demand, which is
what lets it outlive an edit, and two consequences follow. A rebuild discards
scene-local run state, but a production route may immediately restore a durable
checkpoint, so reproducibility requires a declared route or disposable profile.
And a name that did not exist when the host started cannot be adopted, so
introducing one is the edit that still costs a restart. A rebuild that cannot
re-read a script reports the refusal rather than the success: the alternative is
photographing stale code while believing it fresh.

One class of capture a host cannot serve, and it is worth knowing before
reaching for one. Anything a screen reads *once from the process environment* is
fixed for the host's whole life, so a before/after pair that has to vary such a
value — a dump prefix, a held pose — genuinely needs two processes and pays two
interruptions. The host is the default, not the universal answer.

A session may hold a second long-lived process, and confusing the two is easy: a
Godot editor open on the project serves its own set of agent tools. A Live host
is neither that editor nor dependent on one — see *Flagged ambiguities*.

### Interactive Web
The browser-native development path that runs a freshly exported Lab or
production surface as a live Godot canvas, with browser input reaching the
surface directly.

Interactive Web proves browser layout and interaction. It does not stand in for
native-only behaviour such as desktop window fidelity or writing editor output
back into the project.

### Native Proof
The development path that drives a Live host and presents its captured viewport
through the browser control surface, preserving native rendering while browser
gestures are forwarded to the game.

Native Proof is the approval path when the evidence depends on the desktop
build rather than the Web platform; its image is a projection of the native
viewport, not a second renderer.

### Funplay editor server
The editor-bound agent surface for inspecting and mutating the project. It
exists only while the editor is open and is independent of any running game.

### Funplay runtime bridge
The file-backed command surface loaded inside a running game so a Live host can
be driven without an editor.

---

## Localisation

### Language transaction
The player-facing activation that makes a selected language current by
synchronising its dynamic UI catalogue, authored-content overlay, and exact
routed-screen reconstruction as one presentation unit.

A selection records the Pending language immediately. A fight defers the
Language transaction until its next route boundary; each new selection replaces
the pending target, and selecting the Active language again cancels it.

### Active language
The one language whose dynamic UI catalogue and live authored-content
projection are allowed to render the current route together.

### Pending language
The latest selected target waiting for a safe route boundary while the Active
language deliberately continues to own the current fight.

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

### 燼 (The Embers)
The screen reached after a victory: the defeated body's glass drawn as cooling
wreckage, with the run's winnings laid out on it. The name is the concept rather
than a label for the layout, and the screen's lighting follows from it — what is
on screen is a bed of embers, so light comes from the fire below rather than
from a lamp above.

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

### Husk
The defeated enemy's body as the reward presents it: the creature's own
painting standing dead in the room, not a reproduction of its silhouette and
not a prop in front of it. The Embers' whole claim rests on the husk being the
real body — the wreckage is what you broke, still in the colour of the thing
you broke it out of. A husk no longer emits as a living vessel does; the fire
beneath it is what lights it.

---

## The pilgrimage

### Pilgrimage
The journey across one act, walked west to east past lit and unlit stones toward
the Spire. It is a graph the run advances through one node at a time, and a
composed scene the player surveys by dragging — the same structure serving both,
which is why its geometry is presentation's to project and the run's to decide.

*Avoid:* the trail, the tower, the climb — the last is the vertical arrangement
this replaced and now means nothing here.

### Waystone
One node of the Pilgrimage: a place the journey can stop, carrying what waits
there and whether it has been reached. Unlit until the lantern arrives, lit
after. What a Waystone *is* comes from the run; how large, how faint and how far
apart it draws comes from Depth.

### Step
The unit of the walk axis. One Step is the distance between consecutive rows of
the graph, and every other distance on the map is quoted in Steps rather than in
pixels — a stone's depth, the camera's reach, the road's taper. Deriving a Step
from the stage's width rather than fixing it is what lets one composition hold
across every Stage shape.

### Lane
*(map sense — distinct from the concurrent-work Lane under **The port**; see
Flagged ambiguities)* One track of the fan a Pilgrimage spreads across, holding
the stones of a single column. Lanes converge with distance and are floored so
two stones never crowd below a thumb's width.

### Depth
How far a point sits from the camera's seat, measured in Steps. **The map's one
projection** — stone size, stone alpha, Lane compression, the terminus arch and
the road's taper are each a curve read from it, and each is a separate curve on
purpose. Anything that computes distance-from-camera without going through Depth
is a second derivation of the same geometry, which is the failure this map has
paid for more than once.

### Band
One plane of the Pilgrimage, drawn at its own parallax factor: sky and region
behind, the play plane carrying stones and road, weather in front. Paint order
is the plane order, so a thing's Band decides both how fast it travels and what
it may cover. Moving something between Bands is a change of meaning, not of
depth — scenery on the play plane travels at the player's speed, and light drawn
in front of the stones stops being distance and becomes glare.

### Road
The drawn ground the Pilgrimage walks: a bed tapering with Depth, ending at a
lip that is a break in the gradient rather than a stroke. It reads as ground
without competing with the play plane, which is why it carries no hard line of
its own — the graph's dashes own the only one.

### Terminus
The frame the journey ends on: the act's boss seated short of the far edge with
sky beyond, and the arch composed around it. It is the one view the whole
horizontal arrangement exists to compose, so what fits *there* is a constraint on
every Stage shape rather than a property of the widest one.

---

## The vigil

### Vigil
The cross-run ledger — deeds counted, quests with their memories, Shards
collected, and receipts of committed runs — that survives every run and
carries all meta-progression.

It loads all-or-nothing: a saved ledger that fails validation is silently
replaced by a fresh blank one rather than partially accepted, so any
behaviour built on planted or migrated vigil state must be proven by reading
the state back through the same load path the game uses.

### Shard
The token a completed emberglass quest leaves in the Vigil — one per quest,
never duplicated, never from an unknown quest.

Collecting all six is what unseals the Act IV threshold; with any fewer the
journey routes onto an ordinary act map.

---

## Flagged ambiguities

- **"Lane" carries two unrelated meanings — check which cluster you are in.**
  Under **The port**, a Lane is one concurrent line of work over the shared tree,
  owning a declared subset of files. Under **The pilgrimage**, a Lane is one
  track of the fan the map's stones sit in. Nothing connects them; a sentence
  about "the lane" is unreadable without its cluster. The collision is live —
  both are in daily use — so prefer "work lane" and "map lane" wherever the two
  could be read in the same breath.
- **"Depth" on the map is a distance in Steps, not a paint order.** Depth is how
  far a point is from the camera's seat. Which plane a thing is drawn on is its
  Band. They move together in the far distance and come apart on the play plane,
  where everything shares one Band and Depth still varies across the frame.
- **"Holo" had been used for both depth and rainbow colour — these are
  distinct.** Holo is the depth cue (points at different depths sliding past
  each other under tilt). Spectral colour is a separate, independent channel a
  Finish may or may not carry. A Finish can be holo without being rainbow, and
  rainbow without being holo.
- **Two different lights, both "in the object's own space" — the Lamp is not the
  actor's key.** The Lamp belongs to a card and follows the cursor while that
  card is hovered. An actor's stage is lit by a fixed key and rim that do not
  track the pointer; the actor's cast shadow is a projection along that key.
- **"Ground line" had been used for both the encounter's shared line and a
  painting's own footing — these are distinct.** The Ground line is one layout
  decision for every actor on the battlefield. A Contact line is read off a single
  painting's silhouette and varies across that painting's width. An actor's feet
  meeting the Ground line is placement; its shadow starting at its Contact line is
  rendering, and the two are computed from different things.
- **"Stage" means two different things, and only one of them is a screen.** A
  Stage shape is an authored screen composition for the whole encounter. An
  actor's stage is that actor's own private 3D viewport — its lit box, one per
  creature. They share no code and no units: the first is measured across the
  window, the second inside a single painting.
- **"Anchor" is taken; layout uses Edge binding instead.** An Anchor is a
  `file:line` citation checked mechanically. Where a widget hangs is an Edge
  binding. The engine's layout anchors are a third thing again — the mechanism
  an Edge binding is usually implemented with, but not the concept.
- **A Crack and a fracture edge are different things.** A Crack is scored on an
  intact Vessel and rides with the body before it breaks; a fracture edge is the
  lit boundary of a piece that has already broken away. Only the first is
  accumulated state — the second is a property of debris.
- **An enemy is an Actor, not a card.** Earlier work drew enemies as card-like
  placards; that framing is retired. The procedural gem survives only as the
  fallback avatar when a painting is missing, and as the world map's emblem.
- **"Reward" had been used for both the whole bundle and the card choice — these
  are distinct.** A reward is Spoils plus an Offering, and only the Offering is
  chosen. Treating the two as one uniform list is what produces a screen asking
  the player to click three times to acknowledge news.
- **Bare "ward" had been used for the protection and for each of its two parts —
  these are three things.** Ward is the protection. The Ward chip is the numeral;
  the Ward stone is the gem shell. An ownership sentence written about "the ward"
  is unreadable, because a foe's chip, the hero's chip and the stone are each
  owned separately — a sentence assigning "the ward" to one owner is not a
  statement anyone can act on.
- **Two surfaces had both been called "funplay" — these are distinct.** The
  Funplay editor server needs the editor; the Funplay runtime bridge belongs to
  a running game and does not. One being unavailable says nothing about the
  other.
- **"Noise floor" is the capture one; a shader's recompilation jitter is a
  different floor.** The Noise floor is how far two captures of one build differ,
  and it is measured in pixels across a frame. Adding or removing a shader
  uniform separately perturbs every recipe that shader draws — including recipes
  whose code path never runs — because the driver reschedules the rest of the
  program. That second floor is per-channel and tiny, it is a property of
  editing the shader rather than of photographing the screen, and a comparison
  that clears one says nothing about the other.
