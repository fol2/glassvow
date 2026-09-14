# D547-PC1 worker task

**Batch:** D547-PC1  
**Status:** authorised owner-activated prospective completion of missing #547 acceptance definitions (Option A under #421 comment 5663572978). This file plus `SPECIFICATION.md` are the sole design source. 5663572978 remains a parent brief, not frozen numbers.  
**Not:** binding, independent review, #542 freeze, certificates, new game outcomes, a successor research tree, a research PR, Godot suite, #548/#549 execution, or a retry of denied `CHECKS.json` / capsule / raw-observer payloads.

## Goal

1. Preserve these exact bytes (`WORKER_TASK.md`, `SPECIFICATION.md`) on GitHub with GET readback naming **D547-PC1** *before* the research-branch completion commit.
2. On existing branch `research/p9-six-route-local-20260905` only, ship:
   - executable specification (this pair, copied under the artifact dir);
   - ledger;
   - negative-control fixtures;
   - shipped validator;
   - in-repo unittest that imports the shipped validator and drives the shipped fixtures;
   - CONTRACT.md §4.1 row updates so POL quality and error/stop ledger are no longer `MISSING AUTHORITY IN THE CHECKED CLOSURE` — they point at D547-PC1 as **NEW** authorised rules, not inherited remainders.
3. Run the unittest twice; both runs reject every `role=known_bad` case; no game-outcome rows.
4. Push via ordinary `git push` on that branch. GET exact-head blobs.
5. One #547 issue COMMENT completion handoff with GET readback. Do not manufacture GitHub `APPROVE`. Leave #547 open and unbound.

## Paths (research branch)

All new files under:

`research/p9-six-route/duskblade-first-proof-20260912/d547-pc1/`

| Path | Role |
|---|---|
| `WORKER_TASK.md` | this file |
| `SPECIFICATION.md` | executable rules |
| `ledger.json` | four-family spent/remaining accounting |
| `negative_control.json` | dry-run fixtures |
| `validator.py` | shipped decision function |
| `test_d547_pc1.py` | unittest importing `validator` |

Also edit `research/p9-six-route/duskblade-first-proof-20260912/CONTRACT.md` §4.1 only as specified. Do not rewrite historical reuse rows. Do not edit `docs/rc-bar.md`, product/main, or SESSION-HANDOFF (capsule writes remain a recorded denial class).

## Non-goals (hard)

- Inventing certificate cutoffs from memory.
- Adopting Hand 32/32/16, capacity 32/16/16, post-v38 32/16/8/0.25/9728/5000/7200, or #548 detector 0.85/0.70/… as Dusk three-package certificate numbers.
- Treating UNKNOWN historical balances as 0, exhausted, or available.
- Labelling a new finite allowance as an inherited unspent remainder.
- New populations, protected-seed assignment (3000–5199 / 5200–5399), certificates, binding, self-APPROVE.

## Validator / test

`validator.validate(case, ledger) -> dict` is the only admission entry. It must REJECT every `known_bad` id in `SPECIFICATION.md` §Negative controls. Well-formed cases may return `FORM_PASS` and must never return `CERTIFICATE`, `PASS`, or `ADMITTED`. `game_outcome_rows` is always 0 in this batch. Test style: `research/p9-six-route/minimal-native-20260909/capacity/test_capacity.py` (synthetic, non-empirical).
