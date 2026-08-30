## Preregistration — Emberglass source/identity analysis-only correction

Ash's PM authority is frozen in comment `5470587102`. This gate runs the original v1 deterministic `_analyse` function exactly once on the two immutable complete v2 probe outputs. It creates no new observation and does not repair or rerun the identity gate.

The analysis protocol binds every v1 scientific section by canonical hash and freezes these immutable inputs before endpoint loading:

- baseline output SHA-256 `6b56900ab1cfdf6919d1a429bc9ab62e4cb0b905be6da022969493678aac5d91`;
- candidate output SHA-256 `cfece8e320ea104c03ff9d52e02457a2cc8baafb6cb4006ca7037b5a0818f052`;
- v2 plan SHA-256 `df35ac85d12f55da95b22b134be1f01ccdc9d8fcbd7f29d84550c39387ccf8ce`;
- v2 execution audit SHA-256 `38616144ebef7ffe649256048e108df9a584a77724331c2e9ac0e6dc162a1041`;
- v1 protocol SHA-256 `b08e185903bbd0fdbf3b4cc29b065b9483e91b6e835ef6239d079537c47e4ef2`;
- analysis-only protocol SHA-256 `3726136358dcbc055d3cc8fd4b15666f3f4e0a25326c65a2ace76255ac212c0b`;
- analysis-only runner SHA-256 `fc739ddf2f875af64c6564a6623daaf56803c874a80841ab32517b227db336d6` (`PASS (3 checks)`);
- preregistration audit: `research/issue-421/audits/post-7c8a3ee7-emberglass-source-identity-analysis-only-preregistration-v1.json`, SHA-256 `455d15b10abd41eb9f4a50157c05169e1e9212d37141790cb0d3277db444bb1b`.

Loader scope is explicit: a dedicated loader validates this analysis protocol; the original v1 `_load` reads baseline and candidate outputs; no overlay validator is installed globally or applied to a probe output. The runner verifies input hashes before and after analysis.

Ceilings are one `_analyse` execution and five seconds, with zero new Godot processes, rows, seed identities, candidates, grammar changes, simulator rows, ledger reads/writes, protected seeds, product mutations, further corrections and model-context tokens during analysis and deterministic decision.

The decision boundary is exact:

1. every original v1 gate passes: freeze source/identity and continue only to a separately preregistered fixed-policy non-causal shadow-capacity screen;
2. any original v1 gate fails: close this exact one-carry contract without repair, rerun, substitution, B or C; or
3. input or analysis unavailable at cap: record inconclusive and fail closed back to Ash without another correction, B or C.

Preflight passed using hashes and protocol metadata only. Neither endpoint output has been loaded or inspected under this authority, and no analysis has run yet.

This can establish only the original v1 exact source/identity result. It cannot establish natural capacity, causality, balance, product scope, #421 acceptance or the #108 P9 receipt.
