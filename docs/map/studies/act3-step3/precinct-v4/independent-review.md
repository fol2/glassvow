# Independent final-candidate review

Head: `5e3e86429470eec07f2b545fff303f2519adaf11`
Verdict: **APPROVE**

## Blocking findings

None. The shader now preserves authored modulation; the previous blocker is resolved.

## Non-blocking observations

None. The seed-label correction is complete.

## Evidence reviewed

- Exact candidate diff against `41cf16e`, retaining the earlier base-to-candidate review.
- Vertex-stage modulation preservation and expanded native alpha probe.
- Red evidence: 94,929 and 94,922 differing pixels at opacity 0.8 and 0.9.
- Green evidence: zero differing alpha pixels across 294,912 samples at opacity 0.8, 0.9 and 1.0.
- Refreshed wide, tablet and phone combat captures; committed media hashes verified.
- Updated report, receipt and comparison-page references.
- Previously reviewed native guidance, graph preservation, support sampling and selected checks remain applicable.

## Residual risk

The complete core regression and final parser sweep remain delivery gates; this
semantic approval does not certify their completion. Host captures establish
reference-shape composition, not physical device performance.

## Review provenance

Independent read-only reviewer, isolated detached worktree, no author transcript.
Base: `a4d4417e4625651a998bf9f04f8b2f692926e62e`.
First verdict at `41cf16e00935423037154f6d61c02c400e314d2f`: REQUEST_CHANGES,
for dropped CanvasItem modulation. One batched fix and one revised-head review.
This is a semantic review, not a GitHub identity approval or owner art acceptance.
