# SPECIFICATION §8 obligation → function / test map

Not a second scientific authority. Restored `SPECIFICATION.md`, `WORKER_TASK.md`, `reference_kernel.py`, and `ALLOCATION.json` are unchanged.

| Obligation | Function | Tests |
|---|---|---|
| Out-of-band identities/receipts; locators are not proof | `TrustedContext.resolve`, `_ingest_resolved_records`, `_resolve_locator` | `ProvenanceRecordTests`, `EmpiricalGateTests` |
| Packet cannot supply verifier/verdict flags | `_reject_packet_verdicts` | `AuthorGateTests` |
| Empirical BLOCKED without binding/freeze/review; cannot select synthetic context | `evaluate_packet` mode branch, `TrustedContext.has_required_empirical_receipts` | `EmpiricalGateTests` |
| Derive 204 counts from per-root records; summaries compared only | `_derive_counts`, `_compare_summaries` | `CountDerivationTests`, `KernelWiringTests` |
| Consistency: `l<=b`, `g<=n-b`, `r` in `[0,n]`; K support; exclusive; blind vs full | `_check_count_consistency` | `ConsistencyTests` |
| Identical signed B permitted; K/R disagreement from legal preflight actions | `_check_identities_from_records` | `IdentityRuleTests` |
| Frozen frame/sampler/timestamps; cross-vow/panel/dev collisions; missing development | `_check_roots_from_records` | `RootManifestTests` |
| First-eligible-root measurement selection; immediate GT vs native check | `_derive_counts` measurement block | `MeasurementProvenanceTests` |
| Allocation template + kernel `Ledger` event fold; malformed schema rejection | `_check_allocation`, `_fold_allocation_events` | `AllocationTests` |
| 152 predicates via restored `kernel.decide` / `interval` / `paired` | `_predicates` | `KernelWiringTests`, `NumericalMutantTests` |
