# Enemy-action report consolidation preflight

Verdict: `PASS`.

- Protocol SHA-256 `b2af1f5f035925d11407524a96064f50e0cd6e7eea44179680a1937810baa488` and runner SHA-256 `f98bb865d400fa98b8fa81afc85e8161653174f39ac764b52fb1f459ec320fda` matched the independent packet.
- The isolated self-check passed: `PASS (5 checks)`.
- The runner binds the protocol before report reads; enforces exact report hashes, schemas, fields, transform order, types, evidence and prohibited-action emptiness; implements every frozen eligibility condition and the exact six-level ranking; emits at most one abstract contract; and exposes no owner or agent override.
- No-overwrite uses both an existence refusal and exclusive creation and is covered by the self-check.
- The verifier read no report, source projection, repository source, ledger, cache, issue or GitHub state and found no pre-live defect.
