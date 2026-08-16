# Commercial Quality Rubric

Created by the grilling on [#157](https://github.com/fol2/glassvow/issues/157), part of the
commercial-push map [#156](https://github.com/fol2/glassvow/issues/156). This is the per-surface
bar a mobile release candidate must clear. Sign-off records live on executing tickets, never in
this file.

## How to read this rubric

**Calibration, the hard way.** Each dimension is calibrated against a named shipped game. The
anchor is *not* the gate — the criteria extracted from it are. Every criterion is written so a
person holding a phone at arm's length can answer yes/no. Once a criterion is in this file it is
binding: failing one fails the surface's sign-off.

**The only escape is a recorded waiver.** At sign-off a criterion may be struck, but the waiver —
which criterion, why — is recorded in the sign-off comment on the executing ticket. A surface
accumulating waivers is the signal that it is below bar, not a way past it.

| Dimension | Anchor | Governs |
|---|---|---|
| `system` | Slay the Spire 1–2 / Monster Train 1–2 | structure: information, decision clarity, honest input, flow |
| `story` | Hades 1–2, at "lite" scale | a real epic story, smaller than Hades but never absent; progression visibility, ritual moments, narrative delivery |
| `cards` | Pokémon TCG Pocket | the card as object: presentation, touch feel, motion fidelity |
| `visual` | AFK Journey | UI presentation: zero stock-engine widgets, transitions, pressed states, cohesion |

**Audio is not a fifth dimension.** Each surface carries audio criteria following its own anchors:
card/combat feel sounds calibrate against Balatro/PTCGP, music/ambience/narrative against Hades,
UI sounds against AFK Journey.

**Not in this rubric:** fps and device-performance targets (they belong to the performance floor,
[#158](https://github.com/fol2/glassvow/issues/158), and are measured at the release gate);
save-integrity-across-process-death (release gate, [#108](https://github.com/fol2/glassvow/issues/108));
a collection/compendium screen (out of scope for v1, recorded on the map).

## Sign-off protocol

1. **On a real device, on a release export** — never in the editor. The build is installed on a
   phone and played by touch at arm's length.
2. **Both locales** — every surface runs its criteria once in en and once in zh-Hant. Overflow,
   font fallback, and layout breaks surface in zh-Hant first.
3. **The record is a comment on the executing ticket**, using the template below. James signs;
   the sign-off is his.
4. **Two tiers** — sign-off governs look and feel and runs on the primary phone; the release gate
   re-verifies every surface on the named floor devices once #158 lands.

```markdown
### Sign-off: <surface>
- Build: <commit>  Device: <device>  Locales: en ✅/❌  zh-Hant ✅/❌
- Criteria: <n> pass / <n> fail / <n> waived
- Waived: <criterion> — <reason>   (one line each; none is a fine answer)
- Verdict: SIGNED / NOT YET — <what blocks>
```

## Global criteria — every surface inherits these

Checked once per surface at sign-off, alongside the surface's own list.

- [ ] `visual` No default Godot theme control is visible on any screen: every button, slider, checkbox, scrollbar, progress bar, and popup renders with project-themed styleboxes and fonts, never the engine-gray default.
- [ ] `visual` Every player-facing string is readable at arm's length on a 6.1-inch phone, and no text renders below 18 px at the 1180×820 design resolution.
- [ ] `visual` Every zh-Hant string renders entirely from the bundled CJK font with no tofu boxes, no mixed-font fallback glyphs, and no overflow, clipping, or mid-string truncation on any screen.
- [ ] `visual` No interactive or readable element sits under the notch, camera cutout, rounded corner, or home-indicator zone on any supported device in landscape.
- [ ] `visual` At both 4:3 (iPad) and 20:9 (tall phone) aspect ratios, no element is cropped, overlapped, or pushed off-screen, and any area outside the 1180×820 canvas shows themed fill rather than content or bare black.
- [ ] `system` Every tappable element measures at least 60×60 px at the 1180×820 design resolution (about 9 mm on a 6.1-inch phone), including small chrome such as close buttons and toggles.
- [ ] `system` Every tappable element shows a visible pressed state (tint, scale, or highlight) within one frame of touch-down, and dragging off the element before release cancels the action without triggering it.
- [ ] `system` Every screen is reachable and every action performable by touch alone, and the Android system back gesture never hard-exits the app mid-run without a confirmation prompt.
- [ ] `system` No raw engine artifact ever appears on a player-facing screen: no debug label, stack trace, engine error dialog, untranslated key string, or magenta/placeholder texture.
- [ ] `system` Backgrounding the app (lock, call, app switch) and returning resumes the same screen with run state intact and all controls still responsive, with music continuing as a single instance — never doubled or restarted from zero.
- [ ] `audio` Every sound in the game routes through the SFX or Music bus, so the two settings sliders govern all audio: setting either slider to zero silences every sound on that bus, and no sound plays directly on Master.
- [ ] `audio` Music and SFX volume are fully independent: muting or changing one slider never alters the other, and both slider values persist across app restarts.

## Title & transitions

The title-screen world and the scene-transition ceremony layer (`presentation/stage/`).

- [ ] `visual` Within three seconds of the title appearing and with no input, at least three independent motions are visible: motes rising, ash falling, and the hanging chains swinging (AFK Journey: the title is a scene, not a static image).
- [ ] `visual` Dragging a finger across the title makes the entire scene — spire, near shards, particle fields — lean after the touch with a visible lag, and the scene drifts back to its resting composition within two seconds of the finger lifting.
- [ ] `visual` On every screen change during a live run, the lantern-light band sweeps fully across and off the screen; it never stops mid-screen or remains visible after the new screen settles.
- [ ] `visual` Tapping a combat node covers the screen with dark ink on the same frame as the tap, and the cover collapses into the tapped node's position — the combat screen's construction is never visible uncovered.
- [ ] `visual` With Reduce Motion enabled, the band wipe, iris, bloom, crack, act plate, and grain never appear and the ambient particle motion stills, while the title scene still leans in response to touch drag.
- [ ] `story` When a saved run exists, the title's primary action visibly offers continuing that run without opening a submenu; with no saved run it offers starting a new pilgrimage (Hades: continue state readable from the title).
- [ ] `story` Every act boundary shows the act plate — the act's name in gold with its omen line rendered in that omen's own tone — holding fully readable for at least one second before fading over the arriving map (Hades: region title cards).
- [ ] `story` In zh-Hant, the act plate's act name and omen line render every character with no missing-glyph boxes, and the letter tracking does not push either line beyond the plate's width (named risk: the plate's tracked Cinzel face carries no CJK glyphs).
- [ ] `system` Transition leaves never intercept input: a tap issued during the band wipe or during a fading bloom, crack, or plate registers on the screen underneath.
- [ ] `audio` A title theme distinct from the map and combat music is audible within one second of the title scene appearing and loops with no audible gap or click at the loop point (Hades-class music identity).
- [ ] `audio` The victory bloom and defeat crack each carry their own stinger that starts on the leaf's first visible frame, and the two are distinguishable with eyes closed (Hades: distinct victory and defeat cues).
- [ ] `audio` Tapping a combat node produces an audible transition cue the moment the iris cover appears, and the title/map music ducks or hands off before combat audio begins — at no moment are both tracks at full volume.

## Pilgrimage map

The horizontal drag-to-survey journey (`presentation/map/`).

- [ ] `system` Every waystone that can be travelled to this step shows the lit ember rim (pulsing, or held at full brightness under Reduce Motion), and no unreachable stone shows one.
- [ ] `system` Each waystone's emblem identifies its encounter type at arm's length before tapping — fight, elite, rest, treasure, and boss all show distinct art, and only a deliberately unlit stone hides its face behind the dark lantern.
- [ ] `system` Exactly one lantern glow marks the player's seat on the map — behind the current stone, or gliding along the drawn edge mid-travel — and never appears anywhere else.
- [ ] `system` Walked edges draw as continuous bright lines and unwalked edges as faint dashes, distinguishable at arm's length (the StS route-you-took trace).
- [ ] `system` Every bounty chip on screen shows its complete numeral beside its stone — no chip is clipped by the frame edge or overlapped by a neighbour so that its number reads as a different number.
- [ ] `system` A drag that begins on a waystone pans the map without selecting it, a fling coasts to rest, and the camera never shows dead space before the first stone or past the terminus seat.
- [ ] `visual` A slow pan separates at least three depth planes moving at visibly different rates — sky and Spire slowest, region silhouettes mid, road and stones at full speed, weather drifting faster in front.
- [ ] `visual` Panning to the eastern end frames the act boss inside the rose-window arch with its base meeting the road, and open act sky remains visible beyond the terminus.
- [ ] `story` A screenshot of any act's map is attributable to its act without reading text: the Spire reads nearer act by act, and each act carries its own weather — falling ash, light shafts with rising motes, or storm streaks (Hades: each region owns its look).
- [ ] `story` Choosing an unlit waystone plays the kindle ceremony before departure — flash, true emblem blooming in, bounty chip disappearing as the coin is paid — so the reveal is witnessed on the map, not inferred afterwards.
- [ ] `story` The title line names the region the player stands in and, when one row can hold it, who awaits at the terminus; it never wraps onto a second row or overlaps the top waystone row in en or zh-Hant.
- [ ] `audio` Arriving on the map starts an ambience bed audibly distinct from the combat mix within one second, and the bed changes with the act's weather (Hades-class region ambience).

## Combat

The core fight screen (`presentation/combat/`).

- [ ] `cards` Touching any resting card lifts it clear of the fan within one frame, at a scale where its name, cost gem, and full rules text are readable on a phone at arm's length (PTCGP card-focus class).
- [ ] `cards` A carried card tracks the finger with no visible gap opening between finger and card, and its face tilts with real perspective — the near corner enlarges and the light pool moves — rather than translating as a flat sprite.
- [ ] `cards` Every card transit is a visible flight: dealt cards leave the draw pile in a staggered wave and land with their seat's tilt, spent cards travel to their pile, burned cards blaze on the way to the ash, and a targeted card streaks into its enemy — no card ever appears in a new state without travelling there.
- [ ] `cards` A release that plays nothing returns the card to its exact seat along a visible travel, and dragging an unplayable card produces a visible refusal shake instead of arming.
- [ ] `cards` On the zh-Hant build, the card name, type rubric, and rules text stay inside the card silhouette at hand scale, and every dotted keyword underline sits under the keyword's own glyphs after CJK wrapping.
- [ ] `system` Every enemy's intent chip resolves at arm's length — the icon's kind is distinguishable, the damage numeral is legible over the scene, its colour matches the kind — and the chip flashes before its owner acts.
- [ ] `system` While a card is armed, every legal target pulses, the target under the finger is distinct from the others, and the dashed arc and reticle track the finger without dropping out (StS targeting-clarity class).
- [ ] `system` The HP rail answers both ends of a blow: aiming an attack marks the projected loss on the target's rail before release, and a landed hit leaves a pale trail at the old mark that holds long enough to read before draining.
- [ ] `system` Draw, discard, and ashes counts are visible at every moment of the fight, and tapping any pile opens a list naming every card in it with its copy count.
- [ ] `visual` A boss kill runs the full world-stop beat: the screen's colour visibly drains while the doomed white seams stay lit, the beat holds, and colour returns before the shatter.
- [ ] `visual` With no input for five seconds mid-fight, the scene is still in motion — backdrop plates drift, every creature runs its kind's idle, and ash weather falls; no combatant or stage layer is pixel-still.
- [ ] `audio` Card gesture sounds are one-to-one: crossing a card fires exactly one hover tick per card entered, arming a drag plays its tick, and a refused drag plays a distinct refusal sound (Balatro-class gesture audio).
- [ ] `audio` Impact audio is tiered by weight — a heavy blow, a light one, and a fully soaked hit each sound as what they were — and overlapping one-shots all sound without any being dropped.

## Reward

Post-combat and treasure spoils (`presentation/reward/`).

- [ ] `cards` Opening the card offering deals the three cards one after another — each arrives with its own visible rise and a distinct beat after the previous one, and no two cards first appear in the same frame (PTCGP pack-reveal cadence).
- [ ] `cards` An offered card is the same object as the card in hand: side by side, face, material, and lighting are identical except for the larger scale, and its full rules text is readable at arm's length without zooming or tapping.
- [ ] `cards` Taking a card plays the claim as one continuous motion — the card row settles with its seat flaring in tone then going cold, and the panel narrows back to the spoils view — with no cut, pop, or single-frame layout jump anywhere in the sequence.
- [ ] `system` The card slot is honest: a Skip control is visible the entire time the offering is open, skipping visibly spends the slot exactly as taking does, and a reward with no cards to offer draws no card row at all (StS-honest skip; no door onto nothing).
- [ ] `system` Every potion and relic row states what the item does in a rules line on the row itself — no effect text is reachable only through hover, long-press, or a second screen.
- [ ] `system` Pressing Continue with any unclaimed spoil always raises the leave-confirm dialog stating that unclaimed spoils are lost, and pressing it with everything claimed never raises it.
- [ ] `visual` The panel enters animated, never all at once: fade-plus-scale on the glass, the title's gold hairline drawing outward from its center, and rows arriving in a visible top-to-bottom cascade.
- [ ] `visual` Opening the card choice deepens the same glass panel (rows sink, frame widens, cards rise into it); at no point does a second window, panel, or scrim cover the spoils panel.
- [ ] `visual` A finger on a claim row turns its rim gold within one frame of touch-down — row feedback never depends on the mouse-hover slide, which cannot fire on touch.
- [ ] `visual` In zh-Hant, the title, row names, the potion/relic rules line, the offering instruction, and the leave-confirm body all render complete — no glyph is clipped, truncated, or overflowing.
- [ ] `audio` Each card of the offering's deal lands with its own sound in step with the visual stagger — three arrivals produce three audible beats, never one (Balatro/PTCGP per-card class).
- [ ] `audio` Claiming a spoil plays its claim sound on the same frame the seat flares, and the gold claim is audibly coin-voiced, distinguishable from the potion and relic claims with eyes closed.

## Shop

The merchant stall (`presentation/run/shop_screen.gd`).

- [ ] `system` Every card, relic, potion, and service in the stall displays its price directly beneath or beside it, and every price the player cannot currently pay renders in the danger red rather than gold.
- [ ] `system` The player's current gold balance is readable on the shop screen while browsing, without leaving the shop (StS keeps the purse beside the prices).
- [ ] `system` A sold item and a merely unaffordable item are distinguishable from each other at arm's length.
- [ ] `system` The card-removal service states what it does and its cost before the tap, and after one use it visibly deactivates for the rest of the visit.
- [ ] `system` Tapping a sold, unaffordable, or belt-full slot performs no purchase, and a full potion belt shows potion stock as disabled before the player taps, not after a failed attempt.
- [ ] `system` Every relic and potion shows its name and effect text on the item face itself; no purchase information is available only through a hover tooltip, which never fires on touch.
- [ ] `cards` Cards for sale are rendered by the same CardView as combat — frame, art, cost gem, and rules text all present — and the name and cost are legible at the shop's card scale on a phone at arm's length.
- [ ] `visual` The animated world backdrop remains visible around the translucent stall panel and the merchant character art appears in the header, so the shop reads as a lit stall in the world rather than an opaque full-screen list.
- [ ] `visual` The quest offer is visually set apart from ordinary stock and leaves the stall entirely once bought.
- [ ] `visual` The relic, potion, and removal buttons' fixed faces show their full zh-Hant name and effect text without clipping or overflow.
- [ ] `audio` Completing a purchase plays a confirmation sound distinct from the sound of tapping Leave, and it never fires from a sold or unaffordable slot.
- [ ] `audio` Entering the shop audibly changes the music or ambience bed relative to the map screen (Hades: the merchant carries his own theme).

## Node screens

The non-combat waystone encounters, one shared layout language: event, choice, treasure, rest,
threshold, hollow, lamplighter, dawn, vigil (`presentation/run/`).

- [ ] `system` Every event choice button states the choice's cost, gain, or risk on its sub-line before the tap, and mystery-box wording appears only where the event data designs it (StS events: consequences stated before choosing).
- [ ] `system` Tapping an event choice disables all choice buttons within one frame, and the outcome line with its Continue button appears only after resolution, so a rapid second tap cannot resolve two choices.
- [ ] `system` The hollow screen's kicker names the meeting number against the total, and its three actions encode the state exactly: Continue is disabled until the price is paid, and Pay re-labels and disables once it is.
- [ ] `system` On a phone-landscape stage, every node screen's commit button can be reached by scrolling and the view travels with focus, so no focused button sits off-screen.
- [ ] `story` The dawn ceremony reveals memories one at a time — each card slides in over its beat, a tap lands it and requests the next at once, and holding fast-forwards the remainder — player-paced, skippable, never dumped at once (Hades' end-of-run report cadence).
- [ ] `story` With Reduce Motion on, the dawn's flash and confetti do not play and each memory stands instantly while keeping its full dwell time — reduced motion never shortens reading time.
- [ ] `cards` When a node choice offers cards (claim, transform, duplicate), each option renders as a full CardView at the shape's card scale — never a text row — and releasing a card commits the pick (PTCGP: the card itself is the button).
- [ ] `visual` Every node screen heading is set in the same tracked display face over the shared glass panel, and any title rule drawn beneath it is the tapered gold gradient, never a flat hairline — any two node screens side by side show matching heading treatment.
- [ ] `visual` Disabled action buttons fade plate and label together as one unit, and no disabled button on any node screen shows a full-brightness gold plate (AFK Journey: state readable at arm's length).
- [ ] `visual` Tapping the treasure chest art itself opens it — the art swaps to the open chest within one frame and the reward line names the relic in its own tone colour or the coin count in gold.
- [ ] `audio` The treasure chest's opening sound announces the contents before the text is read: the relic tone when a relic is inside, the coin tone when only gold is (Balatro/PTCGP class: the sound carries the payoff).
- [ ] `audio` Commit sounds are classed by weight and distinguishable ear-only — plain choices click, card picks play the card sound, boon and relic moments play the relic tone — and no sound fires from a disabled control.

## Run frame

The persistent in-run chrome: HUD, run menu, settings, help, deck/pile inspector
(`presentation/run/run_hud.gd` and panels).

- [ ] `system` The HUD HP fraction, HP bar fill, gold count, and deck count always equal the current run state — spending gold, taking damage, or adding a card shows the new number before the player can tap anything else (StS keeps these counters always-current).
- [ ] `system` The deck inspector names which pile is shown, collapses duplicates into one row with a multiplied count, marks upgraded copies visibly, states the total count, and shows an explicit empty-state line for an empty pile.
- [ ] `system` Every relic, omen, and potion icon in the HUD strip reveals its name and rule text on tap or long-press on a touch screen, not only via a desktop hover tooltip (StS: every icon on the run bar is inspectable).
- [ ] `system` Master, music, and SFX sliders, per-bus mute, screen-shake and Reduce Motion toggles, and the language switch are all reachable within two taps of the HUD menu button, with no setting hidden behind a further screen.
- [ ] `system` The erase-all control sits visually apart from the other settings sections, wears the danger color in every state including focus and press, and its warning line about what erasure destroys is visible without scrolling past the button.
- [ ] `system` Switching language in settings relabels the settings panel and HUD in the new language without an app restart, and when the change must defer (mid-combat) a note stating so appears in the language row.
- [ ] `visual` The run chrome confines itself to the top band: no HUD element intercepts touches on or overlaps interactive content of the routed screen below, and the relic/omen strip wraps to new rows instead of running off-screen when a run holds many relics.
- [ ] `visual` Menu, settings, help, and inspector each close on a single tap of the dimmed area outside their panel, and back/Escape closes only the topmost overlay, never the run screen beneath it.
- [ ] `visual` All four run-frame overlays share the same glass panel construction — translucent rounded panel, accent border, drop shadow — over a scrim that dims the route behind while leaving it recognizably visible (AFK Journey: modal chrome reads as one system).
- [ ] `visual` The HUD location line ellipsizes rather than overlapping the gold counter or potion cluster, in zh-Hant as well as en, on a phone-landscape stage.
- [ ] `audio` Every button in the HUD, run menu, settings, help, and inspector sounds a click on activation, and dismissing any overlay by tapping the scrim produces the same close sound as its close button.
- [ ] `audio` Dragging the master, music, or SFX slider changes the audible output level while the finger is still down, and releasing the slider plays a confirmation click at the newly set volume.

## Run end

Victory/defeat resolution and credits (`presentation/run/run_end_screen.gd`,
`presentation/run/credits_screen.gd`).

- [ ] `story` The defeat screen lists what this run advanced in the Vigil — deeds struck, quest memories gained, and Shards earned — before the player can return to the Vigil (Hades shows darkness and keepsake gains on every death screen).
- [ ] `story` On death, the monument flame is guttering and at least one ember is rising across the face of the summary panel within five seconds of the screen appearing, and both keep moving for as long as the screen stays open.
- [ ] `system` The run summary displays the run seed.
- [ ] `system` After a completed run, every stat cell (floors, slain, elites+bosses, deck size, damage dealt, damage taken, cards played, run time) shows a real value — the placeholder dash never appears.
- [ ] `system` Tapping View Deck opens the final deck, and its card count equals the Deck Size stat shown on the summary.
- [ ] `system` When bequest choices are offered, the Return to Vigil button remains on screen and tappable without selecting any bequest.
- [ ] `visual` With Reduce Motion enabled, the death screen appears fully composed on its first frame — no black plate, no panel fade, no rise plays.
- [ ] `visual` Return to Vigil is dressed in the primary button style and View Deck in the secondary — the two end-screen actions are never identically dressed.
- [ ] `visual` In zh-Hant, every bequest choice button shows its relic name and note fully inside the card bounds with no clipped or truncated glyphs.
- [ ] `visual` The credits Close button sits outside the scroll region and is visible without scrolling at every stage shape.
- [ ] `audio` Arriving at the defeat screen resolves the music to a defeat cue that is a different piece from the victory resolution when the two are played back to back (Hades class: death and escape each have their own musical arrival).
- [ ] `audio` Selecting a bequest plays the relic chime, audibly distinct from the plain click used by View Deck and Return to Vigil.

## Onboarding — to be built

Decided form: a guided first run — contextual hints inside the real first run, no separate
tutorial mode. These criteria bind the feature when it is built; its design has its own ticket.

- [ ] `system` First-combat hints are each triggered by the game state that first requires them, never on a timer — on the canonical path this reads drag-to-play, then enemy targeting, then end-turn. The targeting hint's state is the first real target choice (an enemy-target card grabbed with two or more living enemies), so a player-chosen play order may defer it past end-turn, but no hint ever fires before its state exists. (Amended by #176: state-triggering is authoritative; the named order is the canonical path, not a gate.)
- [ ] `system` Each hint disappears the first time the player performs the action it names, is recorded cross-run, and never reappears in any later run of the same profile.
- [ ] `system` The very first hint carries a one-tap skip-guidance control that suppresses every remaining onboarding hint for the profile, so a Slay the Spire veteran reaches unhinted play within two taps of starting.
- [ ] `system` While a hint is visible, the action it names remains directly performable on the live UI — no hint adds a mandatory confirm tap or blocks input to the element it points at.
- [ ] `system` At most one hint is on screen at any moment (as StS mobile sequences its first-combat teaching).
- [ ] `story` A story dialogue beat plays before the first mechanics hint appears; no teaching callout is ever visible before the opening completes or is explicitly skipped (as Hades opens on narrative, not controls).
- [ ] `story` The opening names the journey's destination in on-screen dialogue text before the first combat begins.
- [ ] `story` A single tap during the opening advances exactly one dialogue line; skipping the whole opening requires a distinct deliberate control, so one stray tap can never dump the player past the story.
- [ ] `cards` The drag-to-play hint shows an animated gesture ghost tracing the real path from the card's actual hand position to the valid play zone, matching the motion the player's finger must make (PTCGP-style demonstration, not text-only instruction).
- [ ] `visual` Every hint callout is a custom glass-styled panel with a pointer anchored to the exact element it describes, animating in and out over multiple frames — no default tooltip, no single-frame pop, no unanchored center-screen float.
- [ ] `visual` zh-Hant hint text reads as complete written sentences with full-width CJK punctuation and no untranslated tokens or raw locale keys, and no hint bubble clips or truncates its text.
- [ ] `audio` The story opening plays over its own ambience/music, and the combat track does not start until the opening ends and the first combat begins (Hades-class scene scoring).

## Story arc — cross-surface

Not one screen: the "lite Hades" story as a whole, checked across a full playthrough. The
dialogue layer and story content have their own tickets; these criteria bind the result.

- [ ] `story` A tester who completes the Act IV terminus can name the story's beginning, its turn, and its resolution, each from a scene that played on screen during the playthrough — no manual, store page, or out-of-game text required.
- [ ] `story` Every run, won or lost, plays at least one dialogue or memory beat that did not play in the immediately previous run (Hades: every death-return delivers unheard lines).
- [ ] `story` A defeated run leaves visible narrative residue: after the defeat, at least one new line, memory, or Vigil entry exists that was absent before that run and that references the defeat itself, not only a counter increment.
- [ ] `story` A recurring character met a second time speaks lines that differ from the first meeting and explicitly reference that prior meeting (Hades: NPCs acknowledge encounter history).
- [ ] `story` Collecting the sixth Shard triggers a scripted story scene before Act IV opens; the unsealing is never shown only as a lock-state change on the map or in the Vigil.
- [ ] `story` Every completed quest leaves a memory in the Vigil written as full prose sentences and readable at any later point in the playthrough — not a checkbox, counter, or one-word label.
- [ ] `story` At any point mid-playthrough the Vigil shows which of the six Shards are held and which quests remain open, so the remaining distance to the arc's climax is countable without finishing the game.
- [ ] `story` A full playthrough in zh-Hant shows no English fallback string in any dialogue, memory, or story scene, and no narrative line a native reader marks as a word-for-word calque rather than written prose — and the same check passes for en with roles swapped.
- [ ] `audio` Every scripted story scene changes the soundscape for its duration — a music cue, motif, or ambience shift audibly distinct from the hosting screen's default loop (Hades: narrative moments carry their own scoring).
- [ ] `audio` The sixth-Shard unsealing scene plays a musical sting or cue heard nowhere else in the game.
