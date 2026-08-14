# Asset inventory for story design (ticket #175)

Surveyed 2026-08-14 by 10-agent workflow (wf_8a3a852c-7a9); 103 images described.
Full structured data: task output `wdmkitip5.output` (same scratchpad session dir).
**Not surveyed** (subagent session limit): `art/cards` (60), `art/relics` (31),
`art/statuses` (17), `art/potions` (7) — item-scale icons; resumable from cache
after the limit resets (1:50am Europe/London).

## The one asset that changes everything

`art/meta/emberglass-mural.png` — a six-panel stained-glass wheel, one panel per
quest thread, with **a glowing arched doorway at the hub**:

1. top (purple): three pale robed figures carrying a long blue glass shard down
   black stairs — *Pale Ones*
2. upper-right (white/grey): a pale figure and a black tendrilled shadow figure
   palm-to-palm — *Own Shade*
3. lower-right (blue): spiked gold crown above a dark-robed hand dangling a
   small caged lantern — *Usurper*
4. bottom (gold): rosette of eight pale shards crossed by one dark slash —
   *Eighth Omen*
5. lower-left (violet): cascade of blank pages — *Unreadable Page*
6. upper-left (teal): gaunt bald robed figure reaching toward a standing flame —
   *Hollow Lamplighter*

Per-quest alpha masks (`emberglass-mask-*.png`) + `emberglass-frame.png` exist
for progressive per-panel reveal. The sixth-Shard unsealing scene's centrepiece
art already exists.

## Portrait-capable cast (face readable enough for dialogue)

| Figure | Asset(s) | Notes |
|---|---|---|
| Hollow Lamplighter | `meta/hollow-lamplighter.svg`, mural panel 6 | vector, scales to any size; unlit lantern on pole |
| Sovereign 永恆君王 | `enemies/sovereign.png` | crown, scepter, **broken halo with a missing shard gap at top right** |
| The Shade 影 | `enemies/shade.png`, `events/mirror.png` | mirror.png IS the Shade in a mirror, slight smile — ready dialogue scene |
| Merchant | `props/merchant.png` | faceted glass mask, no eyes/mouth — mask rhymes with Sovereign |
| Flesh Trader | `events/fleshTrader.png` | pale featureless mask + skeletal pale hand; weighs a red glass heart |
| Herald of End 終焉使者 | `enemies/heraldOfEnd.png` | terrified expressive face, cracked horn on back |
| Wounded Knight | `events/woundedKnight.png` | dying figure holding out an amber crystal — fallen-predecessor scene ready |
| Gambler | `events/gambler.png` | skeleton, comic register |
| Star Cultist / Ash Acolyte | enemies | masked cult figures; star + pale-mask iconography |
| Tidecaller | `enemies/tidecaller.png` | sea-hermit look, act2 NPC candidate |

Both heroes (`ashwarden`, `duskblade`) are deliberately faceless — player-insert.

## Measured motif density (facts, not interpretation)

**Lantern**: ashwarden's flail IS a lit lantern; duskblade chest bears a lantern
emblem; act1-mid has paired lit lanterns; deepmaw + leviathan carry lure-lanterns
(lit false light); arts set = lantern pouring ash / lit beacon / lantern fire
jet; deeds darkWalker = an unlit black lantern exactly; lanternFed = lantern
eating a card; omens heavyAir = chained lantern; merchant stall lantern;
`meta/fallen.png` = one lit lantern beside a monument; title background = spiral
of small orange lights ascending the Spire to one bright peak light.

**Broken circle above the Spire (act 3)**: sovereign's broken halo (missing
shard); act3-backdrop — broken gold ring arcs behind the tallest peak;
act3-mid — floating broken ring with a large crystal shard suspended beneath;
voidColossus, watcherEye, starCultist, voidWisp, obsidianGolem all carry broken
rings/halos; omens waningMoon = moon crumbling into glass shards.

**Star / watching-eye**: watcherEye (lone eye + severed pointing hands),
starCultist (star spear, star-burst shield), chaosHound (starburst chest),
obsidianGolem (eight-point star panel), forgottenShrine (amber eye above a lit
doorway), meteors in act3-mid.

**Pale**: fleshTrader mask/hands, ashAcolyte dripping bone mask, drownedOne
blisters, thinGlass omen, mural's pale figures. No standalone Pale One enemy art
exists — they are marked variants of existing foes in the quest mechanics.

## Scene-ready backdrops

- **Prologue/establishing**: `title-background/background.png` — the Spire seen
  from the Ashen Woods, ascending lights, one bright light at the crown.
- **Endings**: `meta/ascended.png` (cathedral city above clouds, golden dawn —
  triumph) and `meta/fallen.png` (dark hall, obsidian monolith, single lit
  lantern — memorial/defeat). Both painterly, both unused-in-run scale.
- **Per-act**: 3× backdrop/mid/ledge; act-mid arches are natural dialogue
  staging frames (threshold composition, both acts rhyme).
- **Event locations**: flooded library (act2 lore reveals), forgotten shrine,
  ember fountain, ruined camp (dead travellers), forge.

## Confirmed empty story space (nothing exists — free to author)

- Act IV region art, roster (9 enemies), boss — #220/#221 confirmed no upstream.
- The thing above / true antagonist — zero art.
- Mythic cards (6) — zero art (#212 owns designs).
- The keeper (boon-giver) — no figure art; `LamplighterScreen` shows hero art.
- The Pale Ones as standalone figures — mural panel only.
- Opening scene art beyond the title background.
