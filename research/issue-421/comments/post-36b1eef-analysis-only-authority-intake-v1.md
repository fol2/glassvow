## PM authority intake — Emberglass analysis-only correction approved

Ash, Glassvow PM, supplied this authority. James is not acting as development authority for this decision. The goal remains #421 and the #108 P9 receipt, under the current AI-SDLC and four-rule contract.

Exactly one analysis-only correction is authorised:

- run the original frozen v1 deterministic analysis on the already-frozen v2 baseline and candidate probe outputs;
- allow the overlay validator to handle the protocol only;
- create no Godot process, row, seed identity, candidate, grammar change, simulator row, protected-seed row or product mutation;
- do not repair or rerun the identity gate;
- do not choose option B or C.

The two v2 outputs and every preceding version remain immutable. No endpoint content may be read before the analysis-only protocol, input hashes, inherited gates, budgets and success/futility/inconclusive rules are frozen and published. Deterministic code alone loads the outputs, runs the original v1 `_analyse` function and applies the unchanged decision rule once.

If the result passes, continue only to the next eligible #421 gate that the inherited v1 success rule actually unlocks. A failed or unavailable result closes or stops exactly as preregistered. Any wider action fails closed back to Ash without a successor.

Live provenance:

- task SSOT: current #421 body, SHA-256 with one terminal LF `c1bfb91aacb7ae79f95428d822e554f06e910063d254d2889089a5d201ddcb42`;
- controlling v2 result and decision boundary: comment `5470153869`, body SHA-256 `0fa5942a4187611be90f99b35aa85261b92315d7c78b2142600d7eec11a6e541`;
- current process-authority `main`: `a130c7b00c6961165ab80e83fac85e186a55bd1b`;
- current-main `AGENTS.md`: `3b22bcd95bf60dc5119799da001edf360f1e0f80c6f38daa201492cc938b50ee`;
- current-main AI-SDLC: `87effbc352c2b137afddaaf2eb7fd99c62bc1beb8bd099287dd6d6d73383b90a`;
- immutable v2 result receipt head: `36b1eef1a6daf1340bb140900c8d97957e19b419`;
- frozen baseline output SHA-256: `6b56900ab1cfdf6919d1a429bc9ab62e4cb0b905be6da022969493678aac5d91`;
- frozen candidate output SHA-256: `cfece8e320ea104c03ff9d52e02457a2cc8baafb6cb4006ca7037b5a0818f052`.

The next write is the separately versioned analysis-only preregistration. No endpoint has been read or analysed under this authority yet.
