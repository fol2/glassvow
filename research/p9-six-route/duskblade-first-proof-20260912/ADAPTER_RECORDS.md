# D547-PC1 R1–R3 record adapter — author handoff contract

This is the implementation map for the existing `SPECIFICATION.md` / `CONTRACT.md`, not a replacement scientific design or an empirical approval. Authority: #156 comment 5672517659, #547 corrective batch 5672501610 and reproduction/Boolean aid 5672510804. Work stays on `research/p9-six-route-local-20260905`. Main instructions were read at `07b5aa9dec8436132a524511d5438c510e322070`.

## Public entry and the trust boundary

Call `prospective_admission.evaluate_packet(packet, context)`. The public module delegates to `admission_pipeline`; the archived count-first adapter and generator are never imported. The entry returns integrity, a separate statistical decision, all available per-rule predicates, derived counts and predictions, resource reconciliation, and explicit false certificate flags. A valid record can have a numerical FAIL or INCONCLUSIVE. Missing authority is BLOCKED; malformed or contradictory records are REJECT; fewer than 256 eligible or natural-negative roots is INCONCLUSIVE, not a seed top-up.

`TrustedContext` is a host dependency, not a packet-selected verifier. The runner must authenticate the external manifest and receipt issuers **before** constructing it. It supplies exact artifact head, epoch, candidate, expected role/locator/SHA256 bindings, required exposure namespaces, canonical allocation, and authenticated issuer/receipt digests. The library verifies their content, scope, links and chronology; it does not authenticate GitHub accounts, digital signatures or native semantics by itself. A URI, well-formed hash, nonempty receipt, `approved:true`, or `legal:true` is not sufficient.

Native source semantics remain the explicitly checked external extractor/reader boundary permitted by R1. The extraction receipt binds the exact extractor source and supported meanings: ordinary terminal win, complete MEC acquisition/enactment, first preconsumer immediate eligibility/payoff, public feature extraction, and legal public policy actions. The separate guardrail receipt closes MEC source provenance, legal profile, signed control, policy information/cost and unchanged invariants. Missing/mismatched receipts block or reject before numerical admission. This batch implements and tests the consumer of that boundary; it does **not** implement a second Godot simulator, run a native extraction, obtain real receipts, bind #547 or certify #542.

The test factory can only create synthetic contexts and synthetic issuers. Its `repin` function is explicitly test-only: most semantic mutations are repinned so the tests exercise content validation rather than merely stale hashes. Byte-corruption tests do not repin. Synthetic receipt fields containing APPROVE/BOUND are fabricated test inputs and never a real reviewer verdict or binding operation. Empirical contexts reject synthetic issuers even when their environment text and expected digest are changed.

## Record-to-decision pipeline

| Existing obligation | Active implementation | Decisive controls |
|---|---|---|
| Exact bytes, typed references, authenticated receipt content | `evidence_boundary.verify`, `record_io.ingest/reference`, `admission_pipeline.identities` | `BoundaryRecordTests`, `ReceiptTests`, digest guard deletion/restoration |
| Primitive ordinary wins, acquisition, enactment and same-arm multi-label membership | `observation_records.normalize/derive`, `primitive_reduction.paired` | `PrimitiveTests`, exhaustive `PrimitiveReductionTests`, 40,960-row positive |
| Frozen development selection and centroid arithmetic, full/blind/peer inference | `model_contract.development_models`, `frozen_models` | `ModelTests`, `NumericalEntryTests`, frozen-model guard deletion/restoration |
| Fixed frame, exposure/protection namespaces, dev/confirmation disjointness, mandatory CRN and first eligible selection | `record_contract.validate/validate_preflight`, `observation_records.measurement` | root/alias/CRN/selection/chronology controls; sampler guard deletion |
| Frozen available cost envelope and observed per-arm work | `model_contract.cost_envelope` | cost report mutation, frozen-cap change, actual evaluation/CPU overrun, summary reconciliation |
| Candidate attempt, idempotent readback versus retries, finite accounting/state and alpha | `allocation_events.fold/validate` | `AllocationRecordTests`; allocation guard deletion/restoration |
| Exact 204 occupied intervals / 152 predicates | `admission_pipeline._predicates` delegates to unchanged `reference_kernel` | positive/failure/straddle entry controls, 16 kernel methods including exact PMF enumeration |

### Schema and source pointers

JSON is parsed without duplicate keys or nonfinite constants. A record pointer is exactly `{"role": "native_export/A/v0", "path": ["arms", "K1", 0, ...]}`. It resolves only inside the out-of-band digest-bound store. List indices must be nonnegative integers; paths cannot escape the store or fetch arbitrary URLs.

Each `D547-NATIVE-EXPORT-2` stratum binds producer, product, profile, native reader and all five policy hashes. Its five arm arrays contain exactly 2,048 trajectories in assigned effective-root order. Every trajectory has an ordinary terminal record; ordered acquisition snapshots of actual components/resources; a complete K1/K2/K3 decision-membership map; a public canonical fingerprint; and observed work (`forward_evaluations`, `cpu_seconds`). Each decision contains an exact sequence, native reader, eligibility/payoff/complete-chain observations and registered native views. Complete enactment must reference an earlier qualifying acquisition snapshot in that same trajectory. Ineligible continuations retain an UNKNOWN unavailable tail, never an invented downstream zero.

Ordinary terminal outcomes produce wins. Snapshot contents produce acquisition. The complete native chain and preceding acquisition produce enactment. Win-and-enact is the per-root AND. R/B and K/R discordances are recomputed from aligned outcome pairs. Exclusivity is `enact_K AND NOT enact_L` **in a K-policy trajectory**, not a contrast between separately enacted K and L policy runs. A multi-route trajectory remains multi-label.

`D547-FACTUAL-2`, `D547-MEASUREMENT-2`, and `D547-PEER-2` records bind exact stratum/source identities. Factual records contain mandatory five-leg CRN maps and typed export references, not authoritative correctness arrays. Measurement records identify the first 256 eligible roots and first 256 natural-negative roots under each pre-output frozen permutation; each mask pointer must resolve to the first qualifying decision at that root. Full/disabled immediate native labels must be 1/0. Peer records point to the complete 2,048 trajectories per class, without filtering losses or failed acquisition.

Optional `bits`, predictions and summary rows are cross-checks only. Changing cached correctness without changing observations rejects. Changing native view features changes actual computed predictions and can produce numerical FAIL. Exact centroid ties are abstentions: wrong for positive/negative sensitivity and peer correctness, adverse for natural-null conservatism. Supplied summaries cannot rescue wrong predictions or impossible paired bits.

### Development and frozen inputs

The development export has 64 roots per panel/vow and every declared configuration for each R/K role (at most eight). K configurations need at least 16 full enactments. Selection is highest unconditional development win count, lexicographic policy-hash tie-break. R and signed B may remain identical across panels; K panel differences require the pinned legal-action preflight evidence.

Feature declarations, semantic blind-removal list, policy rosters and available cost caps are pre-development inputs. Full/blind models are reconstructed from the same selected development cases with the specified population-standard-deviation normalization, zero-variance-to-zero rule, class centroids and squared distances. Peer training uses every development trajectory in each class. Every frozen estimator is validated against that reconstruction; confirmation never fits or selects a model. Public Boolean features become 0/1; model parameters remain finite numeric vectors.

The input-manifest digest includes source, native reader, profiles, signed B, policies, preflight and its native trace, development, features, models, frame/sampler and freeze. It deliberately excludes future output bytes and the later aggregate cost report. The complete evidence-manifest digest includes those later exports, cost and allocation. Thus the freeze does not circularly claim to know future outcomes. The available cost caps are nevertheless frozen in the feature declaration, and later cost reports must match them and the bound per-trajectory work records. Required cost statistics and CPU sums are derived, not accepted on flag/name matching.

### Accounting and unchanged scope

`ALLOCATION.json` is byte-identical to the restored zero-spend original. Execution records are validator inputs, never commands to execute. Exact event readback is idempotent; a real retry has a new invocation/event identity and debits again. Renaming the same invocation, conflicting assignment results, a second candidate, borrowing the #548 reserve, historical UNKNOWN credit, cap inflation, refunded alpha, stage jumps and false usage/attempt summaries reject. The first execution consumes exactly one candidate attempt; confirmation freeze commits the existing .025 account. Actual empirical record admission additionally requires authenticated receipts, valid event state and sufficient recorded execution/CPU coverage. The adapter never issues a certificate or changes the on-disk ledger.

No product/runtime files, signed C2 predicates, holdout-only Vow-5 ceiling, #548 thresholds, closed-family negatives, Stun/Shatter semantics or Ash's later Hand obligation are modified. The unchanged reference kernel retains 204 occupied slots, 52 sealed slots, the 0.025/0.025 split and original cutoffs. No new game outcome, protected run, source refit, research attempt, PR/CI run, binding or release action belongs to this batch.

## Reproduction and evidence format

From this directory, use:

```sh
python verify_r1_r3.py --code-head <exact-code-commit> --output /tmp/d547-r1-r3-evidence
```

The script compiles/parses all active Python files, verifies protected source blobs, runs the complete entry/primitive suite and the 16-method reference suite, captures all test output, checks source unchanged, and records every captured entry probe. The entry suite also invokes the 16 reference methods internally; the report distinguishes these counts rather than treating them as independent evidence.

`AUTHOR-R1-R3-POSITIVE.json` contains every derived count, predicate and prediction stream; scalar arrays use lossless `$rle` encoding decoded by `verify_r1_r3.unpack`. `AUTHOR-R1-R3-PROBES.json` retains all captured probe outcomes; each complete 152-decision map is losslessly represented against an explicit ordered key list (`P/F/I`). Empty vectors mean no predicates, not omitted failures. Cases named `guard-deleted-*` deliberately monkey-patch production guards to demonstrate false acceptance, then restore and recheck them. They are not unmodified-entry accepts. No result is selected by a role/expected-reason field in the packet.

`AUTHOR-R1-R3-INPUTS.json` contains the complete packet, external test context identity/receipt records and every generated byte locator/hash/length. The complete deterministic input source is `synthetic_records.py`, not precomputed pass bits. Add `--export-fixture /tmp/d547-expanded` to write **all** generated synthetic store bytes and the input index; no external source, package installation or network access is needed. These are fabricated test observations, not empirical raw outcomes. The run report anchors the exact tested code commit and per-file Git blob identities; later evidence-only commits do not imply a retest of changed code.

This is author evidence. A genuinely fresh, isolated, read-only exact-head review is still required before the existing external process can bind #547 for #542. The author has not performed or claimed that review. All later integration, native, #548, C2/P9 and release gates remain separate.
