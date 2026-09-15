# P9 current capsule — #547 SPEC_BOUND; pointer closeout

## Goal, scope and ownership

Finish the remaining #547 capsule pointer, then continue #542 as source-only entry preparation. Preserve the existing research writer and `research/p9-six-route-local-20260905`. No competing tree, experiment ticket, PR, CI, second binding receipt, or second review of unchanged head `5b6b3a71`.

## Bound identities (immutable)

- Binding receipt: [#547 comment 5683984558](https://github.com/fol2/glassvow/issues/547#issuecomment-5683984558) (`D547-PC1-20260914-BIND-01`).
- Independent exact-head review: [#547 comment 5682513452](https://github.com/fol2/glassvow/issues/547#issuecomment-5682513452), `Verdict: APPROVE`, head `5b6b3a718b8c6200d12d5c06c85702ea9a0f35c6`.
- Downstream delivery to #542: [#542 comment 5684770969](https://github.com/fol2/glassvow/issues/542#issuecomment-5684770969).
- Bound artifact: `5b6b3a718b8c6200d12d5c06c85702ea9a0f35c6:research/p9-six-route/duskblade-first-proof-20260912/`.
- Tested code head: `f8a6bd076c55feeab2a99266deb65e8e6a8c34c3`; the bound head is its evidence-only child.
- Active implementation map: `ADAPTER_RECORDS.md` (blob `ba53bce69de7667ac62038026eb29474c5567460`). Do not use stale `OBLIGATION_MAP.md` as the live control index.
- Frozen evidence snapshot, unchanged: `f8a3c7b9965c6cb21fa1714b59c8537bcb89c3be`.
- Historical product reference, unchanged: `2ed6cdb0302ba3aab5845a18d862841165e8aaf7`.
- `SESSION-STATE.json` blob, unchanged: `8be35c9286b4a31ffc90ea9cac411e4653707311`.
- On-disk `ALLOCATION.json` remains the approved unbound zero-spend template (blob `824ff18acbca2f776533beed83a43b21d9a50f2c`, `status=OWNER_AUTHORISED_DESIGN_NOT_BOUND`, `binding_receipt=null`, all `used=0`). Template preservation is not an absence of the binding receipt.
- Current operating main at this pointer: `07b5aa9dec8436132a524511d5438c510e322070`.

This capsule-only update does not rewrite the approved artifact. The external receipt plus those immutable bytes establish SPEC_BOUND.

## Status

#547 is SPEC_BOUND. Certificates remain 0/3 Duskblade, 0/3 Ashwarden, 0/6 overall. No candidate-native runs, new outcomes, #542 freeze, threshold change, or budget spend belong to this pointer. R11 remains SUMMARY_ONLY and R12 INCOMPLETE for required raw/source closure.

## Exact next action

1. Fetch this file from `origin/research/p9-six-route-local-20260905` and confirm it names `5683984558`, `5682513452`, and `5684770969` while the approved prefix bytes remain identical to `5b6b3a71`.
2. Then close #547 as completed and reconcile #421 A0 to that closeout.
3. #542 continues from the received contract and the source-only entry package committed outside the approved D547-PC1 prefix. Native execution stays blocked until its concrete stage prerequisites exist.
