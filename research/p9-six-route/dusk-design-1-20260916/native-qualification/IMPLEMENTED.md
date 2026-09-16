# DD1-NATIVE-1 implemented vs unresolved

Scientific overlay on M=`07b5aa9dec8436132a524511d5438c510e322070`. Roles fixed. No development/confirmation/merge/release.

## Implemented and verified on the shipped path

Driven through `GlassvowGame.apply` / `CombatRules.play_card` / `preview_play` / `RewardRules.card_pool` / v2 `RunState` save. Two identical PASS runs: `native-tests-1.log`, `native-tests-2.log` (`native_starts=30` each).

| Obligation | Native observation |
|---|---|
| P then C, consume before primary, both hits before insertion-ordered chips | Crosscut on B after Set the Angle on A: hits B then A, chips B then A |
| Same-target spends without return | One hit, mark cleared |
| Replace, no stack; second consumer cannot reuse | Second producer overwrites; second Crosscut is primary-only |
| Illegal UID/energy/OOR/dead target does not mutate mark | last_ret false, mark retained |
| Base/up 4/6 block and 5/7 both hits; Duskmirror first-card 0 | apply + eff_cost |
| Expiry before enemy phase; death and victory clear | endTurn / kill marked / win |
| Ash return null-domain | Crosscut on Ash: one hit |
| Two-target vs same-target vs full-Block return preview | `preview_play` return field |
| K1 guard `staggered OR vulnerable>0` | staggered-only 14; cracked-only 21; neither 7; both 21 with staggered remaining |
| K1 Chisel extra chip and shatter coupling | chips 2; near-threshold staggers and applies Cracked |
| K1 proper subsets | Strike implicit chip only; Eclipse Slash can Shatter without Lance |
| K2 Empower +2 Strength, Flurry three hits + Strength, one settlement | 4+4+4 then chips; Iron Talisman on third Attack |
| Mixed three-role | Strength on both Crosscut hits; Lance does not consume the mark |
| Both pool insertion paths | Dusk uncommon includes both IDs; Ash base and unlock exclude; remaining order identical |
| v2 save / pending reconstruction | no new field; reconstructed combat unmarked; new-ID save loads on new binary |
| Narrow export reader | ordered play/hit pointers, physical HP vs amount/overkill |

## Unresolved / not claimed passed

| Item | Disposition |
|---|---|
| First-valid legitimate Dusk-earned profiles P_v for vows {0,5} | UNKNOWN — not run; constructed hands are not those witnesses |
| Natural acquisition / shop rates / live multi-enemy support rates | UNKNOWN — pool presence is not acquisition |
| Headed marker create/replace/consume visual capture | Venue: Funplay down; DISPLAY unset; headed Godot started on Metal but no completed capture. Unit preview + source existence used |
| Authenticated extraction receipt / guardrail receipt | Absent; not manufactured |
| Development (N1), confirmation (N2), certificates | Not opened. 0/3 Duskblade |
| Full production Godot suite / CI / merge / release | Out of scope |

A handoff ready for isolated review is not a native certificate.
