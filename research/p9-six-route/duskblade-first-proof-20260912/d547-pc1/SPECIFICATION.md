# D547-PC1 specification — executable #547 acceptance predicates

**Authority:** D547-PC1 (NEW, owner-activated Option A). Not an inherited unspent remainder of any closed protocol.  
**Scope:** Duskblade three packages, vows `{0,5}`, dry-run/control only. No game outcomes.  
**Binding:** this text does not bind #547. Independent review of the later exact head remains required.

Historical **not** Dusk certificate cutoffs: Hand 32/32/16; capacity 32/16/16; post-v38 32/16/8 / 0.25 / 9728 / 5000 / 7200; #548 detector 0.85 / 0.70 / 0.10 / 0.15 / 0.50 / 0.85 / 0.90. C2 (`top_cell − arm2 ≥ 0.35 AND arm2 < 0.50`) and Vow-5 holdout ceiling (`vow==5 and best>0.90+1e-12`) stay BAL/RC governed rules, not POL package-quality cutoffs.

Missing historical balances are **UNKNOWN**, never 0 / exhausted / available.

## Verdicts

| Verdict | Meaning |
|---|---|
| `REJECT` | known-bad or malformed; not admitted; not a certificate |
| `FORM_PASS` | necessary well-formedness only; **not** a package certificate |
| `CERTIFICATE` | forbidden in this batch (always reject if claimed) |
| `PASS` / `ADMITTED` | forbidden aliases for this batch |

Stop: first failing predicate. Ambiguity or missing required field → `REJECT` (`MISSING_FIELD` or `AMBIGUOUS`), never silent PASS.

## POL — package quality at matched cost (NEW D547-PC1)

**Obligation.** A package POL claim is competent at matched cost only if all of:

1. **Eligible family:** `policy_family` is non-empty and `unqualified` is false (a policy that failed its own resource/value gate is unqualified).
2. **Information boundary:** `privileged` is false (no oracle, future, hidden-state, or extra-protocol features).
3. **Matched cost:** `search_cost_class` and `runtime_cost_class` are non-empty strings; candidate and reference share both class ids exactly. Layer C matched-budget (QD vs enumeration) is not this predicate.
4. **Competent reference:** `competent_reference` is named and `reference_is_c2_arm2` is false (C2 arm 2 is a BAL landscape screen, not the POL cutoff).
5. **Endpoint:** `endpoint` is `whole_run_enacted_at_vow`; `quality_conditional_on_success` is false; `winners_only` is false.
6. **Route ablation:** `require_route_removal_to_reduce_adaptive_wins` is false.

**Accept FORM_PASS** iff 1–6 hold. **Reject** otherwise. **Certificate POL** is not issued here (no empirical rate; no inherited 0.85/0.25/0.5). Values for later empirical POL rates, if any, freeze only after independent review and #542 instantiation — not in this batch.

## ACQ — operational acquisition (executable form of p9 §3)

**Obligation.** Either:

- `events` names `offered`, `acquired`, and `enacted` with a declared `population`; or
- `deterministic_reachability_proof` is true **and** `witness_kind` is not `necessary_screen_count`.

**Reject** if `certificate_from_necessary_screen` is true; if `sufficient_cutoff` is one of `32/32/16`, `32/16/16`, `32/16/8`; if R14 Dusk V5 stock-family necessary-screen negative is treated as package admission; if Dusk V0 is labelled `failed` rather than `unopened`.

Numeric 32/32/16, 32/16/16, 32/16/8 remain historical/scope-limited necessary screens. Exact profiles/unlock/economy remain `#542 CANDIDATE INSTANTIATION` under p9 §3.

## MEAS — operational measurement (executable form of Layer B)

**Obligation.** Descriptor/predictive claims require all of: `ground_truth_source`, `abstention_policy`, `held_out_split_id` disjoint from training/search, `estimator_name`. `identity_only` must be false (hashes/repeated assignment prove identity/stability only).

**Reject** `identity_only`; **reject** `detector_threshold_transfer` (copying #548 0.85/0.70/… as package MEAS). Assignment-stability without held-out prediction is not predictive validity.

Observer/descriptor/reader hashes remain `#542 CANDIDATE INSTANTIATION` under Layer B.

## BAL (unchanged pointers; not re-derived here)

- C2: `CURRENT GOVERNED RULE` as CONTRACT §4.1.
- Vow-5: `CURRENT GOVERNED RULE` as CONTRACT §4.1.
- This validator does not execute C2 or Vow-5 on game rows (0 game outcomes).

## Ledger — scientific error / correction / stop / spent-remaining (NEW D547-PC1 family)

Four **non-interchangeable** families. Observed rows, nominal maxima, remaining compute, and statistical-error allowance are not substitutes.

| Family | Historical | This-batch authorised (NEW, labelled) | Debit | Stop |
|---|---|---|---|---|
| `statistical_error` | UNKNOWN | 0 inferential claims | any empirical inference → REJECT | no rows ⇒ no spend |
| `correction_attempt` | UNKNOWN | family id `D547-PC1`, initial allowance **1** coherent author-side batch | this publication spends 1; remaining 0 | a second same-scope implementation without new owner auth → REJECT (`REPEATED_RECEIPT`) |
| `observation_compute_wall_time` | UNKNOWN; post-v38 9728/5000/7200 and R13 4096/512 are HISTORICAL/SCOPE-LIMITED, not remainders | **0** game-outcome rows; **0** Godot runs | any game-outcome row or Godot run → REJECT (`EXCEEDED_CAP`) | dry-run only |
| `seed_exposure` | UNKNOWN except recorded closures | protected 3000–5199 and reserve 5200–5399 **not assigned** | any exposure or “fresh” use of an exposed/duplicate unit → REJECT | no protected-seed assignment |

`treat_unknown_as` in {`available`,`exhausted`,`zero`} → `REJECT` (`UNKNOWN_BUDGET_MISLABEL`). Missing `authority` → `REJECT` (`MISSING_AUTHORITY`). Missing required outcome when `outcomes_required` → `REJECT` (`MISSING_OUTCOMES`). Reusing `receipt_id` already in `spent_receipts` as fresh evidence → `REJECT` (`REPEATED_RECEIPT`).

## Case schema (validator input)

Each fixture is one JSON object. Required keys: `id`, `role` (`known_bad` | `form_ok`), `authority`. Other keys default to the field list below. The validator reads the object from its start state; callers must not pre-admit.

Fields: id, role, authority, unqualified, privileged, search_cost_class, runtime_cost_class, reference_search_cost_class, reference_runtime_cost_class, policy_family, competent_reference, reference_is_c2_arm2, endpoint, quality_conditional_on_success, winners_only, require_route_removal_to_reduce_adaptive_wins, events, population, deterministic_reachability_proof, witness_kind, certificate_from_necessary_screen, sufficient_cutoff, r14_treated_as_admission, dusk_v0_status, ground_truth_source, abstention_policy, held_out_split_id, estimator_name, identity_only, detector_threshold_transfer, budget_status, treat_unknown_as, outcomes_required, outcomes_present, game_outcome_rows, godot_runs, unit_exposure, unit_duplicate, receipt_id, spent_receipts, claim_certificate.

## Negative controls (all `role=known_bad` → REJECT)

| id | Fault |
|---|---|
| `NC-MISSING-AUTHORITY` | `authority` empty |
| `NC-UNKNOWN-BUDGET-AS-AVAILABLE` | UNKNOWN labelled available |
| `NC-UNKNOWN-BUDGET-AS-EXHAUSTED` | UNKNOWN labelled exhausted |
| `NC-SCOPE-LIMITED-COUNTS-AS-CERTIFICATE` | capacity 32/16/16 as sufficient certificate cutoff |
| `NC-HAND-COUNTS-AS-CERTIFICATE` | Hand 32/32/16 as sufficient |
| `NC-POST-V38-COUNTS-AS-CERTIFICATE` | post-v38 32/16/8 as sufficient |
| `NC-IDENTITY-ONLY-DESCRIPTOR` | identity-only MEAS |
| `NC-UNQUALIFIED-POLICY` | unqualified POL |
| `NC-PRIVILEGED-POLICY` | privileged POL |
| `NC-COST-UNMATCHED-POLICY` | search or runtime cost class mismatch |
| `NC-EXPOSED-UNIT-AS-FRESH` | exposed unit counted fresh |
| `NC-DUPLICATED-UNIT-AS-FRESH` | duplicate unit counted fresh |
| `NC-MISSING-OUTCOMES` | outcomes required but absent |
| `NC-EXCEEDED-CAPS` | game_outcome_rows > 0 |
| `NC-REPEATED-RECEIPT` | receipt_id already spent |
| `NC-548-THRESHOLD-TRANSFER` | #548 detector thresholds as package MEAS |
| `NC-WINNERS-ONLY-QUALITY` | POL quality on winners only |
| `NC-R14-AS-ADMISSION` | R14 necessary-screen as package admission |
| `NC-V0-AS-FAILED` | Dusk V0 labelled failed |

`NC-FORM-OK` (`role=form_ok`) → `FORM_PASS`, `certificate=false`, `game_outcome_rows=0`.

## CONTRACT.md §4.1 mapping this batch writes

- POL matched-cost quality: `CURRENT GOVERNED RULE` = this POL section (NEW D547-PC1 deterministic predicate). Not C2, not #548, not post-v38 0.25/0.5/0.1/0.9.
- Scientific error/stop ledger: `CURRENT GOVERNED RULE` = this ledger (NEW family; historical UNKNOWN; 0 game outcomes). Not post-v38 9728/5000/7200, not R13 4096/512.
- ACQ/MEAS: keep p9 §3 / Layer B as governed; add pointer that operational fields are this specification. Numeric screens stay historical/scope-limited.

§6: filling these rows does not bind. Independent exact-head review is still required. Certificates remain 0/3 Duskblade, 0/3 Ashwarden, 0/6 overall.
