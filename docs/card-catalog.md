# Card catalogue — benchmark roguecardv2@6e069118

Authoritative list, read out of the benchmark worktree at
`../roguecardv2-prepixi` — `src/packs/core/cards.js` for the definitions and
`src/i18n/en/content.js` for the display names.

**`x` = present in the Godot slice** (`port_fixtures/content/slice-content.json`).

Names and ids diverge hard here, which is the point of SKILL.md §3: ids are
frozen save keys, names are locale data. `strike` is "Edge", `cleave` is
"Fan of Glass", `executioner` is "Faultline". Reading a lab sheet by name and
expecting the id to match will look like invented content when it is not — every
card in the slice was verified against this list, and all 18 match on rarity too.

Rarity coverage: starter 6/7, common 3/11, uncommon 6/22, **rare 0/17**,
special 3/4. The whole rare tier is unported.

| | Name | id | Rarity | Type | Cost |
|---|---|---|---|---|---|
|  | Ashbite | `ashBite` | starter | attack | 1 |
| x | Chisel | `chisel` | starter | attack | 1 |
| x | Eclipse Slash | `eclipseSlash` | starter | attack | 1 |
| x | Edge | `strike` | starter | attack | 1 |
| x | First Spark | `firstSpark` | starter | skill | 0 |
| x | Smother | `smother` | starter | skill | 1 |
| x | Ward | `defend` | starter | skill | 1 |
|  | Dimming Cut | `lunge` | common | attack | 1 |
|  | Emberbite | `venomStrike` | common | attack | 1 |
| x | Fan of Glass | `cleave` | common | attack | 1 |
|  | Flicker | `quickSlash` | common | attack | 0 |
|  | Glasstep | `sidestep` | common | skill | 0 |
|  | Held Light | `brace` | common | skill | 1 |
| x | Quarry Maul | `heavyBlow` | common | attack | 2 |
| x | Refract | `deflect` | common | skill | 1 |
|  | Tinder | `preparation` | common | skill | 0 |
|  | Twin Shards | `twinFangs` | common | attack | 1 |
|  | Warden's Edge | `guardedStrike` | common | attack | 1 |
|  | Ashcloud | `toxicMist` | uncommon | skill | 1 |
|  | Ashen Choir | `ashenChoir` | uncommon | skill | 1 |
|  | Blood for Oil | `bloodRite` | uncommon | skill | 0 |
|  | Emberdance | `emberdance` | uncommon | skill | 0 |
| x | Faultline | `executioner` | uncommon | attack | 1 |
|  | Glasswall | `bulwark` | uncommon | skill | 2 |
|  | Glazier's Poise | `agility` | uncommon | power | 1 |
|  | Gutter | `cripple` | uncommon | skill | 1 |
|  | Hailglass | `tempest` | uncommon | attack | 2 |
|  | Hearthglow | `regrowth` | uncommon | power | 1 |
| x | Honing Edge | `momentum` | uncommon | attack | 1 |
| x | Inner Blaze | `empower` | uncommon | power | 1 |
| x | Mirrorlight | `fortify` | uncommon | skill | 2 |
|  | Night Sight | `nightSight` | uncommon | power | 1 |
|  | Quakeblow | `quakeblow` | uncommon | attack | 2 |
|  | Ringing Blow | `uppercut` | uncommon | attack | 2 |
|  | Shatterhymn | `warCry` | uncommon | skill | 1 |
| x | Splinterstorm | `flurry` | uncommon | attack | 1 |
| x | Struck Match | `surge` | uncommon | skill | 0 |
|  | Thirsting Shard | `leechBlade` | uncommon | attack | 2 |
|  | Tithe of Panes | `tithe` | uncommon | skill | 1 |
|  | Vitrify | `ironSkin` | uncommon | power | 1 |
|  | Anneal | `bastion` | rare | power | 3 |
|  | Annealing Rite | `limitBreak` | rare | skill | 1 |
|  | Bellows | `catalyst` | rare | skill | 1 |
|  | Bellstrike | `oblivionStrike` | rare | attack | 3 |
|  | Cathedral Glass | `aegis` | rare | skill | 2 |
|  | Eat the Flame | `devour` | rare | attack | 1 |
|  | Emberfang | `virulence` | rare | power | 2 |
|  | Flawless Form | `flawlessForm` | rare | skill | 1 |
|  | Novaflare | `novaflare` | rare | attack | 2 |
|  | Overglow | `frenzy` | rare | power | 2 |
|  | Phantom Blades | `phantomBlades` | rare | attack | 1 |
|  | Pyre Tithe | `offering` | rare | skill | 1 |
|  | Pyreheart | `pyreheart` | rare | power | 2 |
|  | Requiem | `annihilate` | rare | attack | 2 |
|  | Resonant Lance | `resonantLance` | rare | attack | 1 |
|  | Rising Litany | `ascension` | rare | power | 3 |
|  | Shardstorm | `shardstorm` | rare | attack | 3 |
| x | Cinder | `burn` | special | status | - |
| x | Hex | `hex` | special | curse | - |
| x | Shard | `wound` | special | status | - |
|  | The Unreadable Page | `unreadablePage` | special | curse | 0 |

**61 cards total; 18 in the Godot slice.**
