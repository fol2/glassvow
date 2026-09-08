# Recorded control feasibility: a review supplement, not another certification stage

This isolated directory preserves the code, 14 passing tests, exact-input result
and execution log for the post-observation review in #421 comment 5591125386.
It complements the existing six-package disposition, without replacing its reader,
common capsule, workflow or historical experiments. No game ran and no model fit.

On the recorded V0 research assignment, balanced controls win Dusk 44/64 and Ash
46/64. Even a perfect strategy has at most 20/64 = 31.25pp and 18/64 = 28.125pp
observed gaps. Thus policy-only improvement cannot create a 35pp gap on those same
recorded controls. The frozen preregistration explicitly says these controls are
NOT signed original arm2. This is not signed C2 FAIL, a population impossibility,
a new acceptance rule, a requirement for a new content candidate, or permission
to weaken controls/refit/replay. Existing source-bound hand-size work remains
eligible; resolve the control/competence evidence before a large new certificate
batch, rather than quietly ignoring the stronger-control observation.

The archive is a deterministic tar.xz with six regular files, all identified in
MANIFEST.json. Verify the archive SHA256 before unpacking. From the unpacked copy:

    python -m unittest -v test_control_feasibility
    python control_feasibility.py REPO

REPO must contain the three exact committed inputs named in RESULT.json. The
reader checks their hashes and the complete original 1024-row compact assignment.
No engine or font is included. This supplement is not a new mandatory review
loop. The duplicate local whole-disposition draft was superseded by the already
published implementation, not promoted as a second verifier. P9 remains unfinished.
