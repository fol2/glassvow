# Issue Tracker and Work Ownership

GitHub issues hold durable specs, decisions, dependencies, and handoffs. Use `gh` inside a clone or the GitHub integration. Do not create tracker work merely to mirror a complete direct owner instruction.

## One outcome, one owner

An independently mergeable delivery outcome gets one issue when durable tracking is needed, one assignee, one branch, and one ordinary PR. Claim an existing issue before mutating the repository. Do not create a second issue or PR because another machine or agent continues the same work.

A concise delivery issue states outcome, non-goals, acceptance, active constraints, dependencies, and stop conditions. Implementation transcripts and repeated status summaries do not belong in the specification.

Unless the issue or owner instruction explicitly says not to merge, the owner agent carries the outcome through implementation, the risk-required independent review, batched fixes, relevant green gates, merge, and branch cleanup. Do not hand routine plan approval, candidate selection, review resolution, or merge-button work to a person.

## Research is not a ticket tree

A bounded research question may use one research issue containing its hypothesis, experiment budget, immutable inputs, evidence, stop rule, and decision. Individual runs are rows or artifacts under that issue—not child tickets and not PRs.

Create a child issue only when the result is independently mergeable, independently owned, or genuinely blocks another delivery. Promotion from research creates or updates one delivery issue with the selected decision and reproducible acceptance; rejected exploration stays out of the delivery context.

## Dependencies and parallel work

Use GitHub's native issue dependency where available; otherwise put `Blocked by: #<n>` at the top. Parallelise only unblocked tasks with non-overlapping mutable surfaces. A dependency on unmerged code is not resolved by repeatedly rebasing several active tickets against one another.

Before opening a new branch, search open issues and PRs for the same outcome and files. When overlap is discovered, choose one authority, integrate the stronger completed work once, and close the duplicate route. Do not let two classifiers, contracts, or single sources of truth land side by side.

Legacy `wayfinder:*` maps may remain useful for genuinely uncertain programmes, but do not create a map and child hierarchy for a normal feature or a handful of experiments.

## Pre-authorised finite programmes

When an issue accepts a finite decision graph, record every node's immutable inputs, budget, correction limit, PASS/FAIL/INCONCLUSIVE transition, and terminal owner boundary in that issue before execution. Prove any required venue, permission, tool, or observation channel before freezing a dependent experiment. The assigned owner then follows already-authorised transitions without child issues or repeated approval comments. Escalate only after the declared graph and safe capability ladder are exhausted, or when the next transition crosses a credential, cost, regulated, irreversible, compatibility, product, or release-authority boundary.

## Basic operations

- Read an issue with comments and labels before work.
- Claim with assignment as the first tracker write.
- Comment only decisions, blockers, exact evidence, or handoff state that another session needs.
- Close when acceptance is met or a documented stop decision is made.
- Use the canonical triage labels in `docs/agents/triage-labels.md`.

GitHub shares one number space for issues and PRs; resolve an ambiguous `#n` before acting.

## Pull request record

The PR body is the compact integration record: outcome, key design choice, selected CI scopes, final-head commands and results, visual evidence when relevant, and residual risk. Do not paste full logs or duplicate the issue. Review findings should be concrete and batched; another loop is justified only by a new defect or invalidated evidence.

A semantic or policy change, or a non-mechanical multi-file change with interacting risks, receives one exact-head review from `.claude/agents/ai-sdlc-reviewer.md`. A fully mechanical change with decisive deterministic proof does not need a ceremonial model review. When the reviewer shares the owner's connector identity, record its verdict as a PR `COMMENT` rather than manufacturing `APPROVE`. Human review is requested only under the escalation conditions in `docs/agents/ai-sdlc.md` or when repository policy requires it.
