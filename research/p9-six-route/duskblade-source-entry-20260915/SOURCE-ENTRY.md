# #542 source-only entry package — 15 September 2026

Parent: #542. Bound contract: `5b6b3a718b8c6200d12d5c06c85702ea9a0f35c6:research/p9-six-route/duskblade-first-proof-20260912/` via [#547 binding 5683984558](https://github.com/fol2/glassvow/issues/547#issuecomment-5683984558) and [review 5682513452](https://github.com/fol2/glassvow/issues/547#issuecomment-5682513452). Prerequisite received: [#542 comment 5684770969](https://github.com/fol2/glassvow/issues/542#issuecomment-5684770969).

This file is source analysis over already-bound records. It is not a candidate freeze, native extractor qualification, certificate, population outcome, or #542 execution authority. Certificate count remains **0/3 Duskblade**. No closed R1–R14 panel is rerun. `ALLOCATION.json` stays the zero-spend template.

Operating main used for instruction/content identity: `07b5aa9dec8436132a524511d5438c510e322070`. Frozen evidence snapshot: `f8a3c7b9965c6cb21fa1714b59c8537bcb89c3be`. `SESSION-STATE.json` blob `8be35c9286b4a31ffc90ea9cac411e4653707311` is historical ledger, not current nomination authority.

Active implementation map: `ADAPTER_RECORDS.md` blob `ba53bce69de7667ac62038026eb29474c5567460`.

---

## 1. Proposed product / dependency identities and eligibility

### Proposed product (not yet frozen)

| Field | Exact identity | Source |
|---|---|---|
| Class / vows | Duskblade; `{0,5}` | CONTRACT §1; SPECIFICATION.md §2; binding 5683984558 |
| Operating tree | `origin/main` `07b5aa9dec8436132a524511d5438c510e322070` | binding receipt; current-main |
| Historical product reference commit | `2ed6cdb0302ba3aab5845a18d862841165e8aaf7` | SESSION-STATE `product_reference`; CONTRACT §1 |
| Shipping content | `content/full-content.json` git blob `1fdf17c5b5acda33159b4cc5badac9d166c3bf8e`, SHA256 `a0d608a5142d2e3aab799cdf33d3163922b402c2aaf2a895e46e096399b56cf1` | identical on `07b5aa9d`, research tip `5b6b3a71`, and `2ed6cdb0`; DISPOSITION `baseline_sha256`; COMPOSITION.json `inputs.base/content/full-content.json` |
| Shipping combat | `domain/rules/combat.gd` git blob `58c9b8c8f162e77d802fac6c10e5b884b53c8b15`, SHA256 `3adb0e063a536bf249d3b5d9524427facf1398304206da59d97594d3fff246e8` | identical on those three commits; COMPOSITION.json `inputs.base/domain/rules/combat.gd` |
| Shipping rewards | `domain/rules/rewards.gd` git blob `55ecfc6f4615287d90c62737632f7ae4b3133085`, SHA256 `fe69d19ecf6448aad71b466d9beee1716e1957fe277a62c5bacf8daba3c7ac83` | identical on those three commits; source-package-audit PROTOCOL `source_sha256` for rewards.gd |
| Native RNG | `domain/rng/rng.gd` blob `4cee9c92891dacadccd22f08e4a4b79442ced412`; constructor `seed & 0xFFFFFFFF` | SPECIFICATION.md §1; CONTRACT §4.1 |

This shipping identity is the **baseline**, not a selected #542 candidate. Binding a specification does not freeze it.

### Closed / ineligible families (do not reuse)

| Identity | Disposition | Source |
|---|---|---|
| Bulk candidate content SHA256 `3c7b2f9dba362d19128ef82ad559d3f26e54925371d823a665767032255eadaa` | Closed. SESSION-STATE still names it historically; CONTRACT §1: not a current nomination. Added `banklight` (absent from shipping). Combat SHA256 `a6fd99eb53030d3cf1401153bdeceec8b86ccc2af8b7643481855c681906f2ba` ≠ shipping combat. | R6 `candidate-decision-20260909/DECISION.json` blob `e7e7c0722e02b60c153befc6711d26516ca1d1b7`; DISPOSITION `candidate_sha256` / `existing_candidate_added_card_ids`; COMPOSITION.json `inputs.candidate/*` |
| Restoration `91fd5de56727df42fdcb539b61e7cc7a32e77f3f85dbbe13baef3513e7003cfb` | Closed with the bulk candidate on assigned signed-control screens (Ash V0 `absolute_random_build_movement_at_most_tenth`). | R6 DECISION.json `frozen_failed_candidates` |
| Historical descriptor `2cfe1d8ff00d5ff695664c597be3a93e3960f39732fa049eac82b9397184bab7` | Not an admitted current descriptor. | CONTRACT §1 |
| R13 Hand/Bloodfire nominations content `4107c7c0bbed5d9acf8c2bdf97023552426920242ea958c8ebdec793b712afd9` / combat `3ccb89f69f50e41d5a46eadd8f48c0a907fd0e382cd492b2c34dd5f93e091ad0` | Different from R6 closed bulk; Ash-inheritance joint-controller V5 stock/aware summaries; **not a Dusk nomination**. | CONTRACT R13; SELECTION-FREEZE.json blob `e1f60e680271b790ec37a6d4b7ebd27e7b2b41d7` |
| post-v38 Afterimage/Scoreline four-package archive `c802be36510273481b6d0f865b92fac43abf6aff` blob `96e899bf6fbaa2dc6ab926621aa72340818d8dda` | Different candidate and four-package authorisation; not current Dusk three-package authority. | CONTRACT §4.1 |
| Historical resonance producers `eclipseSlash` + `warCry` with consumer `resonantLance` | `REJECT_EXISTING_RESONANCE_PACKAGE` (pilot activation upper bound 0.0181 vs target 0.25). Not Chisel/coupled-Shatter. | R5 `source-scope-20260908/EXACT-CLOSURE-SCOPE.json` `historical_resonance` |
| Whole-command Facet zero-interaction controls | `COMMAND_CONTRACT_FAIL`; 672 rows, 64 failed checks. Immutable. | R3 `command-chain-20260908/recovery-v1/REMOTE-READBACK.json` raw SHA256 `62ae02bd4fda08381ce61a4a40b88a98391d7476b6b33d090bc896b622663785` |
| Dusk V5 stock policy family `BalancePolicy.sample_range(73209000,0,128)` | `FIXED_NATIVE_POLICY_FAMILY_INSUFFICIENT_UPPER_BOUND`. Do not retry this sampler. V0 unopened, not failed. Ash grids in the same terminal stay Ash-scoped. | R14 PROTOCOL blob `0da0ecf658dc2e1c9b73788448e40b0546c48e78`; TERMINAL blob `46fa97f316e5a205a30d1338d8474cd597598227` |
| Ash Hand / Preparation / Surge / Phantom; Ash Smolder; Ash Cycle | Out of Dusk first-class scope. Hand include-or-improve obligation stays with #544. | #542 body; CONTRACT §2; DISPOSITION routes `ashwarden/*` |

R6 did **not** prove universal Dusk impossibility. Native-foundation Dusk V0/V5 screens on the **closed candidate** are not shipping-product qualification (R6 `candidate_selected_for_further_population_certification: null`).

### Eligibility of the proposed shipping product

- Shipping content SHA256 `a0d608a5…` ≠ closed candidate `3c7b2f9d…`. Banklight is absent from shipping.
- Shipping combat SHA256 `3adb0e06…` ≠ closed-candidate combat `a6fd99eb…`.
- CONTRACT §3: a current-main docs-only diff does not prove equivalence between a research candidate and main. A new product, profile, policy or observer invalidates the corresponding dependency-bound claim.
- Therefore R1–R5 packets recorded against candidate `3c7b2f9d` / engine `8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e` **do not automatically bind** to shipping `a0d608a5` / `3adb0e06`. Equivalence is an unresolved #542 source gap, not a reuse.
- R14 **does** bind to unchanged shipping `BalancePolicy` at Dusk V5: that stock family remains a necessary-screen negative on the proposed product.
- COMPOSITION.json `inputs.base/*` already pins shipping content+combat. Its Facet/Cycle decisions are therefore comparable to the proposed product for those exact card/operator claims, not a licence to reuse the closed candidate as the #542 product.

**Decision recorded here:** propose shipping Duskblade `a0d608a5` + combat `3adb0e06` at main `07b5aa9d` as the only eligible non-closed product identity in permitted source. Do not revive `3c7b2f9d` / `91fd5de5`. Do not freeze it in this batch.

---

## 2. Source-backed K1/K2/K3 package tuples (not three labels)

Required tuple (CONTRACT §2): `producer -> visible mediator -> independently enabled consumer -> bounded payoff -> expiry/reset`, plus acquisition conditions and enacted policy.

DISPOSITION.json (`package-disposition-20260908/DISPOSITION.json`) defines three **Dusk hypotheses** against the **closed candidate**. Compare each tuple to shipping `content/full-content.json` `a0d608a5…`.

### K1 — `duskblade/facet` (source-backed on the proposed shipping product)

| Leg | DISPOSITION contract (candidate) | Shipping `a0d608a5` |
|---|---|---|
| Producer | Connecting Dusk Attack chips, including printed Chisel chip; Shatter threshold on the same living target before Echo | `chisel` starter, chip 1, dmg 4/up 7. COMPOSITION.json `cards.chisel.exact_changed_keys: []` (identical old/candidate/shipping) |
| Mediator | Target staggered or `vulnerable > 0` at consumer guard; attributed Shatter precedes the action. Stun/Shatter remain coupled | Same native `_shatter_enemy` / `shatterEcho` operators in COMPOSITION `exact_common_blocks` |
| Consumer | `resonantLance`, cost 1, shatterEcho n=7/up 10 | Present: rare (not candidate uncommon), `locked: paneBreaker`, same n=7/10 |
| Payoff | Nominal hit, Block absorbed, HP removed kept separate | Unchanged claim class; no new native payoff proof here |
| Expiry/reset | Status expiry, Stun consumption, target death, combat reset; post-hit Shatter cannot cause the preceding Echo | Unchanged native lifecycle claim; R3 whole-command null remains FAIL and is not repaired |

Canonical comparisons (do not treat as certificates):

- Historical resonance (`eclipseSlash` + `warCry` → `resonantLance`) is a **different producer contract** and is REJECTED (R5). Shipping still contains both cards (`eclipseSlash` starter Cracked; `warCry`/`Shatterhymn` uncommon). DISPOSITION facet `alternatives`: direct Cracked producers enable the same consumer but are not this package.
- R4 four-state shortest words 5/5/7/7 and 156 positional proper subsets: bounded language on candidate `3c7b2f9d`, protocol pins that candidate; **not directly transferable** (CONTRACT R4).
- R5 two named producer-role aliases refuted; `canonical_equivalence_or_union_proved: false`; `all_closed_package_comparisons_complete: false` (COMPOSITION.json `decisions`).
- R3 672-row COMMAND_CONTRACT_FAIL retained; not a new producer, Block reset, or Stun unbundle.

Acquisition on shipping: `resonantLance` is **not** in common/uncommon/rare open pools as a free card; deed `paneBreaker` (`deeds.paneBreaker`: Shatter 15 facets) unlocks `card:resonantLance` and `card:quakeblow`. Starter deck already has `chisel`. See §3.

Obligations from DISPOSITION remain `formal_family: OPEN_FULL_PACKAGE_COMPARISON`, `complete_causal_subset_null: PARTIAL_RETAINED_EVIDENCE`, `competent_multi_policy_support: MISSING_FOR_EXACT_CANDIDATE`, `population_reachability: MISSING_QUALIFIED_SUPPORT`.

### K2 — DISPOSITION `duskblade/fervor` is **not** the shipping consumer

DISPOSITION candidate consumer: Flurry/`Splinterstorm`, rarity **common**, **five** hits, printed raw **0/up 1**.

Shipping `flurry`:

- rarity **uncommon**
- effects `dmg n=2 times=3` / up `n=3 times=3`
- name still Splinterstorm

That is a different consumer topology (3×2 vs 5×0), not a scalar of the audited package. R1 selective-Fervor nulls preserved **five-hit** topology on candidate `3c7b2f9d` (`source-package-audit-20260908/PROTOCOL.json`). CONTRACT §3: a semantic-preserving change still needs relevant equivalence evidence; a different consumer is not that evidence.

Shipping producer `empower` / Inner Blaze exists (power, uncommon, `str` 2/up 3). DISPOSITION also names Ritual; **ritual is ABSENT** from shipping `content/full-content.json`.

**Unresolved gap:** no source-backed K2 tuple on the proposed shipping product. Do not relabel shipping 3×2 Splinterstorm as the audited Fervor package. Do not reopen Hand/Bloodfire (R7/R13) as a Dusk K2.

### K3 — DISPOSITION `duskblade/cycle` is **not** substantiated on shipping

DISPOSITION candidate consumer: same-UID Momentum, n=0/up 1, grow 14/up 17, **plus guarded draw 1**, rarity common.

Shipping `momentum` / Honing Edge:

- rarity **uncommon**
- effects `momentum n=6 grow=4` / up `n=8 grow=6`
- **no draw**

COMPOSITION.json:

- `cycle_exact_guarded_effect_composition: true` on the **candidate** expansion
- `cycle_identical_to_old_whole_card: false`
- `historical_limit`: proves composition of inherited operators, **not** equivalence to the frozen old Honing card (which **is** the shipping card)

**K3 is not invented.** The permitted source names a third Dusk hypothesis only on ineligible candidate `3c7b2f9d`. On the proposed shipping product that tuple is absent. Do not substitute Afterimage, Scoreline, Bloodfire, Hand, or historical resonance as K3.

### Same-product three-package set

| Slot | On closed candidate `3c7b2f9d` | On proposed shipping `a0d608a5` |
|---|---|---|
| K1 Facet | DEFINED (candidate rarity/lock differ) | DEFINED at source (Chisel identical; Resonant Lance rare + paneBreaker) |
| K2 Fervor | DEFINED (5×0 Flurry) | **Not substantiated** (shipping 3×2 Splinterstorm; Ritual absent) |
| K3 Cycle | DEFINED (grow 14 + draw) | **Not substantiated** (shipping old Honing; composition forbids equating them) |

Exact source-level gap: **there is no eligible same-product three-package set in permitted source.** One Dusk tuple is source-backed on the eligible product. The other two DISPOSITION Dusk tuples live on a closed candidate. Pairwise functional/behavioural separation, competent-policy, live acquisition and certificates are all unproven (DISPOSITION `packages_admitted: 0`).

---

## 3. Legal per-vow acquisition / profile prerequisites and native predecessor witnesses

SPECIFICATION.md §2 (bound): for each vow v in `{0,5}`, one common **legitimately earned** starting profile `P_v` for all five arms. The profile unlocks opportunity; it must not grant a target deck, relic, money, achievement or victory through a test-only shortcut. Native predecessor path from the ordinary initial ledger using Duskblade and permitted progression. Any common profile requiring an unavailable Ash action fails. This is a post-prerequisite gameplay population, not a first-run distribution. #543 owns complete fresh/returning campaign proof.

### Ordinary initial Duskblade ledger (shipping)

`content/full-content.json` `player` (id `duskblade`): startDeck `strike×4, defend×3, eclipseSlash, chisel, firstSpark`; startRelic `emberHeart`; startGold 99; energy 3; handSize 5.

R10: bound initial profile unlocks only `aspect2`. Night Sight is outside the initial pool/starter (`locked: darkWalker`). `even_all_reveal_gates_open_is_insufficient: true`. Source-only retry class pruned. First Spark starter inclusion ≠ reward-tier membership.

### Package-specific legal unlocks on shipping

| Dependency | Shipping gate | Witness required before freeze |
|---|---|---|
| K1 consumer `resonantLance` | Deed `paneBreaker`: stat `shatters`, n=15, unlocks `card:resonantLance` | Native predecessor in which Duskblade earned 15 shatters under ordinary rules, then the card is in the legal pool. Not a test grant. |
| Uncommon pool (`flurry`, `empower`, `momentum`, `warCry`) | `cardPools.uncommon` plus reveal/pool waves | Legal pool membership after ordinary reveals; not all-reveals at t=0 |
| `momentum` also in `progression.poolWaves.poolWave2` | `revealThresholds.poolWave2.runsPlayed: 2` | Native ledger with `runsPlayed >= 2` if that wave is required |
| Night Sight | `darkWalker` (6 unlit lanterns) | **Not** a Dusk first-class package prerequisite; do not unlock it to patch Hand/draw. R10 remains. |
| Ash-only cards (`catalyst`, `phantomBlades` rare pool, etc.) | Out of scope | Must not appear as `P_v` requirements |

R2 natural-enactment: 9 reproduced runs, 10 factual temporal witnesses, 40 counterfactual actions, 10 dormant exact-null pairs; two requested contexts absent (Ash hand V0 seed 45010004; Ash cycle V5 seed 45010000). Raw SHA256 `61af4dc208880364c668ec724519e0bc639c44e447f1e106c4fad3893a3ca31b`. Existence exhibits, not `P(acquire_K)` on the 2048-root population. Candidate-scoped.

R1 acquisition.parts: 12 component co-ownership/use witnesses in nine unique rows across six routes and vows 0/5 — post-hoc existence, not frequency (`source-package-audit-20260908/README.md`).

No recovered native predecessor save for a legal Dusk `P_v` that includes `paneBreaker` is identified in permitted source. Obtaining it is SPECIFICATION.md §2 / allocation preflight (cap 8192), **not** this batch.

### `tools/balance_sim.gd` is not live `P_v`

File blob on main/research/product_ref: `3578488bea72c6ba45a787228dfc1e669c11969c`.

```
const PROFILE: String = "mature-three-act-no-side-state-v1"
## Domain-only whole runs: all reveals, no quests or cross-run side state.
profile = { aspect, vow, reveals: content.reveal_ids.duplicate(), unlocks: ["aspect2"], quests: {}, shards: [], lamplighter: false }
```

Comparison to bound target population:

| Property | Bound `P_v` (SPEC §2) | `balance_sim.gd` PROFILE |
|---|---|---|
| Reveals | Legitimately earned; freeze required unlock set from package definitions | **All** `content.reveal_ids` at start |
| Unlocks | Ordinary Dusk progression; paneBreaker etc. witnessed | Hard-coded `["aspect2"]` plus all reveals |
| Quests / shards / lamplighter | Native predecessor state | Empty / false (no side state) |
| Acts | Ordinary terminal | Forced three-act domain loop |
| Population | Post-prerequisite gameplay; not first-run; not all-unlocked fixture | Explicit all-reveals fixture |

SPECIFICATION.md §2: “No all-unlocked fixture is silently treated as a fresh-player distribution.” R10: even all-reveal gates open is insufficient for Night Sight membership. This profile is a **signed control / sim fixture**, not live `P_v` proof. **The signed control is unchanged in this batch.**

---

## 4. Native source → `ADAPTER_RECORDS` field / receipt mapping

Consumer (already implemented, synthetic-only): `prospective_admission.evaluate_packet(packet, context)` → `admission_pipeline` (`ADAPTER_RECORDS.md`). Host must authenticate issuers **before** `TrustedContext`. Library does not authenticate GitHub, signatures, or native semantics.

### Required native export fields (`D547-NATIVE-EXPORT-2`)

From `synthetic_records.trajectory` / `observation_records.normalize` and ADAPTER_RECORDS.md:

| Native meaning | Record field | Adapter check |
|---|---|---|
| Extractor identity | `producer_sha256` | Must equal authenticated `extractor_source` digest |
| Product / profile / oracle / five policy hashes | `product`, `profile`, `native_oracle`, `policies` | Header identity vs `TrustedContext` expected roles |
| Effective root | `root` | `kernel.effective_seed` (`seed & 0xFFFFFFFF`) |
| Ordinary terminal win/loss | `terminal.kind="ordinary"`, `terminal.outcome in {win,loss}`, `terminal.sequence` | Primitive win |
| Acquisition snapshots | `snapshots[].sequence,components,resources` | `observation_records.acquired` vs package definition components/resources |
| Route membership | `decisions.K1/K2/K3[]` | Must be exactly those three keys; multi-label allowed |
| Enactment | decision `native.chain_complete` + `snapshot_index` into earlier qualifying snapshot | Enactment without acquisition REJECT |
| Immediate eligibility/payoff | `native.eligible`, `native.payoff`; ineligible tail `unavailable_tail="UNKNOWN"` | `label()` |
| Masked views | `views[mask].public`, `.native`, `.reader_sha256` | Full mask required; reader digest = oracle |
| Public fingerprint | `public_fingerprint` | Peer features; no package/policy/card-name IDs, seeds, arm labels, win label shortcut (SPEC §5) |
| Work | `work.forward_evaluations`, `work.cpu_seconds` | Cost envelope; 128 forward evals/decision cap |

Factual/measurement/peer schemas: `D547-FACTUAL-2`, `D547-MEASUREMENT-2`, `D547-PEER-2`. Pointers are `{role, path}` into the digest-bound store only.

### Receipts (`evidence_boundary`)

| Role | Scope / verdict | Must bind |
|---|---|---|
| `independent_review` | `547-adapter` / APPROVE | Already: comment 5682513452 (specification, not #542 freeze) |
| `binding` | `547-contract` / BOUND | Already: comment 5683984558 |
| `freeze` | `542-candidate` / FROZEN | **Missing** — this batch must not issue it |
| `extraction` | `542-extraction` / VERIFIED | `producer_sha256`, `supported_semantics` = `normal-terminal-win-v1`, `mec-acquire-complete-chain-v1`, `first-preconsumer-immediate-eligibility-payoff-v1`, `public-feature-extraction-v1`, `legal-public-policy-action-v1` |
| `guardrails` | `542-invariants` / VERIFIED | `mec-source-closure`, `legal-profile-provenance`, `signed-control`, `policy-information-cost`, `unchanged-invariants` |

Empirical contexts reject `synthetic:` issuers. Packet `approved`/`bound`/`certificate` flags REJECT.

### Reusable producers (scoped; not a second simulator)

| Producer | What it already emits | Qualification gap vs adapter |
|---|---|---|
| `source-package-audit-20260908/` `test_package_nulls.gd`, `selective_fervor.gd`, `assemble.py`, `read_audit.py` | 677 native assertions; followup 60 locality + 17 omitted-field mutations; AUDIT/FOLLOWUP remote readbacks | Candidate `3c7b2f9d` + engine `8d106cbe…`; not `D547-NATIVE-EXPORT-2`; 5-hit Fervor topology ≠ shipping 3×2 |
| `natural-enactment-20260908/` | 9 runs, snapshots/temporal/counterfactual/dormant-null | Existence, not 2048-root CRN export; two Ash contexts absent |
| `package-proof-20260908/facet-language-v1/` | Four-state words 5/5/7/7; 156 subsets | Candidate-pinned; command traces, not population export |
| `package-proof-20260908/composition-v1/` compose/read_native | 128 constructed traces; COMPOSITION.json blob `f711e2c5ea26c79212ae4e0157b5b0a969de6bf8` | Operator composition, not adapter trajectories |
| `command-chain-20260908/` | 672-row negative | Preserve; do not replay as a producer |
| `minimal-native-20260909/capacity/` | Stock-family necessary screen | R14 closed for that sampler |
| `tools/balance_sim.gd` + `balance_policy.gd` + `balance_pilot.gd` | Domain whole-run fixture | All-reveals PROFILE ≠ `P_v`; no adapter export; signed control unchanged |
| D547-PC1 `synthetic_records.py` | Complete adapter-shaped store | Fabricated; empirical mode must reject it |

### Smallest missing qualification work (no execution here)

1. A native extractor whose **source digest** is host-authenticated and whose output matches `D547-NATIVE-EXPORT-2` for shipping combat `3adb0e06` + content `a0d608a5`.
2. Guardrail receipt covering MEC source closure, legal `P_v` provenance (not all-reveals), signed B (`landscape-arm2-random-build-competent-play` / C2 reader `b68de162503ca63134c0870818aa6daa206230d5`), policy information/cost, Stun/Shatter unchanged.
3. Equivalence **or** explicit invalidation of R1–R5 packets against shipping identities (CONTRACT §3).
4. PaneBreaker predecessor witness for K1; do not proceed to K2/K3 definitions until shipping tuples exist or the gap remains a freeze blocker.
5. Host authentication of manifest/receipt issuers (review residual risk; not repaired by consumer tests).

R11 SUMMARY_ONLY (`f7be1dbdd81c4447f10360ee5e692bcee26f6f33`) and R12 INCOMPLETE (validation raw unrecovered; original-arm archive `b866d60d7d9dad9bbd83610c145e242ed026bf046806ca5c7cab83f4b58d326c` not remotely complete) remain execution blockers for dependent MEAS claims. Do not resend blocked payloads.

---

## 5. Staged-readiness manifest

Stages follow SPECIFICATION.md §6 finite transitions. This batch stops before `CANDIDATE_PREFLIGHT` empirical spend.

| Dependency | Established | Missing | Next permitted action |
|---|---|---|---|
| D547-PC1 specification | Bound artifact `5b6b3a71`; review 5682513452 APPROVE; receipt 5683984558; delivered 5684770969 | Capsule pointer (separate #547 closeout) | Administrative pointer only; no artifact rewrite |
| Product identity | Shipping content `a0d608a5` + combat `3adb0e06` distinguished from closed `3c7b2f9d` / `91fd5de5` | Formal #542 freeze of one eligible identity | Freeze only after extractor/`P_v`/package set are instantiable |
| K1 Facet tuple | Source-defined on shipping (Chisel + paneBreaker Resonant Lance); aliases/resonance/command-chain negatives retained | Closed-family union; live ACQ; POL; peers; paneBreaker predecessor | Source/oracle equivalence for R4/R5 vs shipping; legal paneBreaker witness |
| K2 tuple | Candidate 5×0 Fervor defined and ineligible with that candidate | **No shipping-substantiated K2** | Do not invent one; do not freeze three packages |
| K3 tuple | Candidate grow14+draw Cycle defined; composition proves it is not shipping Honing | **No shipping-substantiated K3** | Do not invent Afterimage/Hand/Bloodfire/resonance as K3 |
| Same-product 3-set | Gap recorded | Eligible K2 and K3 on shipping, or owner decision for a different eligible product that is not a closed candidate | Block freeze of a three-package nomination |
| `P_v` / acquisition | Initial Dusk deck, `aspect2`, paneBreaker/darkWalker deeds, pool waves documented from shipping JSON; R10 | Witnessed native predecessor ledgers; no all-reveals shortcut | Preflight capture of legal saves (allocation cap 8192) **after** freeze authority; not this batch |
| `balance_sim.gd` PROFILE | Compared; all-reveals ≠ `P_v` | None for this claim | Do not change the signed control; do not treat it as live-profile proof |
| Native extractor / adapter mapping | Consumer + synthetic schema bound; reusable producers listed with scope | Real `D547-NATIVE-EXPORT-2` producer; extraction+guardrail receipts; host issuer auth | Qualify extractor on shipping identities; no candidate-native population |
| Signed B / C2 | Landscape reader blob `b68de162…`; CEM `b3890bcc…`; rc-bar `405e0b4b…` | Candidate-specific signed-control run on the **eligible** product | Necessary screen after freeze; do not retry R14 sampler; do not treat native-foundation candidate Dusk cells as shipping proof |
| R11/R12 raw | Status recorded SUMMARY_ONLY / INCOMPLETE | Required raw/source through an already permitted channel | Do not resend blocked payloads; dependent MEAS stays BLOCKED |
| Policy rosters | Rules bound (≤8 configs/role; 16/64 enacted; 128 evals) | Actual legal public policies on shipping | Instantiate only after product+packages freeze |
| Allocation / spend | Template `824ff18a…`, all used=0, binding_receipt=null on disk | Operative ledger after freeze | No spend this batch |
| #548 / certificates | Interface text in CONTRACT §5 | Admitted set, holdout, detector | Out of this batch |
| Certificates | 0/3 Duskblade | All five claim classes × 3 packages | Report 0/3 |

Next permitted action after this package is published and fetched back: **either** close #547 if the capsule pointer is remotely verified, **or** leave only that closeout pending. #542 must not freeze, run natives, or spend budget until an eligible same-product three-tuple set exists **or** the recorded K2/K3 shipping gap is accepted as a freeze blocker.

---

## Exact source locators (R1–R14 and controls)

| ID | Locator | Blob / SHA (as bound) |
|---|---|---|
| CONTRACT.md | `research/p9-six-route/duskblade-first-proof-20260912/CONTRACT.md` | git blob `265f2e7b696896659b0352e2bc69b31d5d938991` |
| SPECIFICATION.md | `research/p9-six-route/duskblade-first-proof-20260912/SPECIFICATION.md` | git blob `45ca750e193fe114bb528f517088e21bbbcde908` |
| ADAPTER_RECORDS.md | `research/p9-six-route/duskblade-first-proof-20260912/ADAPTER_RECORDS.md` | git blob `ba53bce69de7667ac62038026eb29474c5567460` |
| R1 | `source-package-audit-20260908/AUDIT-REMOTE-READBACK.json`, `FOLLOWUP-REMOTE-READBACK.json` | CONTRACT table |
| R2 | `natural-enactment-20260908/REMOTE-READBACK.json` | raw `61af4dc2…` |
| R3 | `command-chain-20260908/recovery-v1/REMOTE-READBACK.json` | raw `62ae02bd…` |
| R4 | `package-proof-20260908/facet-language-v1/` | raw `c86b7bff…` |
| R5 | `source-scope-20260908/EXACT-CLOSURE-SCOPE.json`; composition REMOTE-READBACK | raw `70176a36…`; COMPOSITION git blob `f711e2c5…` |
| R6 | `candidate-decision-20260909/DECISION.json` | git blob `e7e7c072…` |
| R7 | hand-admission / ash-inheritance pair/acquisition/planner terminals | CONTRACT table |
| R8 | ash-inheritance descriptor RESULTS | CONTRACT table |
| R9 | hand-value / two-slope / acceptance-scope | inference blob `dbadd165…` |
| R10 | `nightsight-opportunity-v1/availability-1/RESULTS.json`, `frontier-1/DECISION.json` | CONTRACT table |
| R11 | selected-recapture RESULT-INDEX.json | `f7be1dbd…` SUMMARY_ONLY |
| R12 | SESSION-STATE validation/original_arms | archive `b866d60d…` INCOMPLETE |
| R13 | `prospective-package-20260911/SELECTION-FREEZE.json` | freeze blob `e1f60e68…` |
| R14 | `minimal-native-20260909/capacity/PROTOCOL.json`, `native-1/TERMINAL.json` | `0da0ecf6…` / `46fa97f3…` |
| C2 | `tools/balance_landscape.py` | `b68de162503ca63134c0870818aa6daa206230d5` |
| Vow-5 ceiling | `tools/balance_cem_report.py` | `b3890bcc3e3fc792ab72177c46a0ed256163db52` |
| p9 method | `docs/balance/p9-strategy-diversity-system.md` | `d03f3985a843ce89c8ff7db679aa75b484a5206e` |
| Kernel / allocation | `reference_kernel.py` / `ALLOCATION.json` | SHA256 `7aa2592f…` / `c7669b23…`; git blobs `ee091fb5…` / `824ff18a…` |
