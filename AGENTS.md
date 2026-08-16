# Agent Contract — Glassvow Godot

**Glassvow** (琉璃誓言) is a Godot 4.7.1 roguelite deckbuilder, parallel-ported from a web original and, since 2026-08-16, **detached from it** — see THE REFERENCE below. The 18 files in `port_fixtures/` began as exports from that original and are now the port's own regression goldens, pinning its behaviour rather than the web's. The map system was always a deliberate redesign (horizontal "glassvow world" journey, not the vertical tower). Before beginning any implementation work, load `.claude/skills/glassvow-godot/SKILL.md` — it binds the engine contract, architecture boundaries, testing strategy, and stop conditions.

## THE REFERENCE — detached 2026-08-16

**This port owns its content and its behaviour. Nothing parity-checks against the
web original any more, and "the web did it differently" is not by itself an
argument.** The standard is the commercial rubric (issue #157). The reference did
its job — it got a deckbuilder from the browser into Godot — and development is
now ahead of it, so continuing to benchmark against it would only hold the port
back. See issue #317 for the decision and `docs/benchmark-divergence.md` for what
was measured on the way out.

**The 612 surviving `file:line` citations are frozen history, not instructions.**
They explain 403 code sites and cost nothing to leave alone, and the commit they
name cannot drift. Do not re-resolve them; roughly two thirds were written against
the wrong tree anyway (see the incident below), so their provenance value is
already part fiction. **Writing a new one is banned** — cite this port's own code,
and `python3 tools/check_benchmark_freeze.py` will refuse a 613th.

**Nothing serves `http://localhost:5190` any more, and no gate reads the
checkout.** If you genuinely need to look at the original — which should be rare,
and never to settle what this port ought to do:

```bash
# The pinned commit, in full. `%h` abbreviations lengthen as a repo grows.
#   6e06911853ba8e26d05ac4db0a1ad119a6c2275a   2026-07-13, pre-Pixi
git clone https://github.com/fol2/roguecardv2.git /tmp/rc2 \
  && git -C /tmp/rc2 checkout 6e06911853ba8e26d05ac4db0a1ad119a6c2275a
```

`~/Coding/roguecardv2-benchmark` may still sit on that commit locally, but do not
treat it as durable: it is a **linked git worktree** of `~/Coding/roguecardv2`,
not a standalone clone, so its 1.3 GB dies with its parent. The commit is an
ancestor of that repo's `main`, so the clone recipe above always works and the
disk is reclaimable whenever someone wants it back.

**`~/Coding/roguecardv2` was never the reference.** It is on `main`, tag
`web-reference-v1` (`1343e1d`) — 284 commits ahead and **post-Pixi**, carrying
`src/ui/combat-gl.js`, `#uigl`, `chromePulse` and a Pixi `artCast` that the pinned
commit does not have. This contract itself once named that tag as the reference,
and on 2026-07-26 the error produced three commits ported against code the
benchmark does not contain (`e071e34`, `d367e44`, `806272c` — reverted or redone).
Both trees are now equally not the standard, but the distinction still matters
when reading a frozen citation: it tells you which of the two a line number was
written against.

**A function existing in the source is not evidence that it renders** — learned
the same day, and the one rule here that outlives the reference entirely.
`ring()` and `slashArc()` push particles with no `vx`/`vy` while the draw loop
does `p.x += p.vx * dt` unconditionally, so their coordinates go NaN before they
draw. They never appeared on screen at either commit, and a port of them would
have been a port of nothing. Measure the running thing; do not infer from source.

## Verification (all from repo root)

```bash
godot --version                          # must print 4.7.1.stable
tools/check_imports.sh                   # asset import; fails on stderr ERRORs or process status
tools/check_scripts.sh                   # per-file parse + warnings-as-errors gate
godot --headless -s res://tests/run_all.gd   # run test suite; must exit 0 (PASS)
python3 tools/check_anchors.py           # doc file:line anchors still point where they claim
python3 tools/check_benchmark_freeze.py  # no new citations into the detached reference
```

**Why the parse gate is a script and not a one-line loop.** `godot --headless
--check-only -s FILE` writes its diagnostics to **stderr and exits 0 whatever it
found**. Measured on 4.7.1 across four seeded error classes — a duplicate `var`
in one scope, an unterminated string, `var x: int = "text"`, and an untyped
`var x = 1` — the status was 0 on all four, so the `|| exit 1` loop that stood
here until 2026-08-06 could not fail and never once caught a defect. What the
tree was actually being protected by was `tests/run_all.gd`, and only as a side
effect: a parse error makes `load()` return null and the run fail.
`tools/check_scripts.sh` greps the stderr instead, which is the only signal
`--check-only` gives, and both this gate and CI call that one script so the two
cannot drift.

The default sweep deliberately uses `git ls-files`, so it protects tracked
scripts only. Stage every new `.gd` file with an explicit path before running
the full gate; an untracked script is outside both the local sweep and CI.

Warnings-as-errors is not the broken half. `project.godot` sets
`untyped_declaration`, `inferred_declaration`, `unsafe_cast` and
`unsafe_call_argument` to level 2, and an untyped `var x = 1` really does print
`Parse Error: Variable "x" has no static type. (Warning treated as error.)` —
detected, and now enforced by the stderr grep rather than by the exit code.

**CI enforces all of them, and that is new.** `check_anchors.py` joined `ci.yml`
on 2026-08-13, after main was found sitting on a drifted anchor — a
`docs/solutions/` citation still naming the line `_capture_and_quit` had since
moved off. The gate existed, ran locally, and exited 1 correctly; nothing called
it before a merge, so it caught nothing for as long as everyone remembered to
forget it.

Until 2026-08-16 there was one hand-run exception, `check_web_anchors.py`, and
**that is exactly why it is now deleted rather than kept.** It resolved citations
against the benchmark checkout, so it returned **2 — "benchmark tree not found"**
on every CI runner and inside every git worktree; putting it in CI would have
painted the tree red for a reason unrelated to anchors, and special-casing that
exit away would have turned a real gate into a no-op — the same disease as the
`--check-only` loop above. With new citations banned outright, counting them is
the whole of the job, and `check_benchmark_freeze.py` counts: no checkout, so it
runs in CI, where the rule is actually broken. A gate that cannot run where the
work lands is not a gate.

Screenshots go through `tools/shot.sh` (one-off) or `tools/live.sh` (iteration
loop) rather than a bare `godot` launch — see `docs/session-ownership.md` ›
Organiser-owned files for why and for the two caveats.

## References

- **SKILL.md** — `.claude/skills/glassvow-godot/SKILL.md` — 10-section binding contract (engine pin, architecture, IDs, save compatibility, stop conditions).
- **Commercial Game Delivery** — `docs/commercial-game-delivery.md` — engine-neutral policy (save versioning, determinism, content stability, performance gates).
- **Fixtures** — `port_fixtures/` holds 18 **port-owned goldens**, read by 6 of the test files. Their immutability contract ended with the detachment (#317 D5): they pin this port's behaviour, so a deliberate behaviour change may update one, in its own commit, saying what changed and why. No port-side regeneration tool exists yet — it gets designed the first time a refactor actually needs one, never speculatively.
- **Documented Solutions** — `docs/solutions/` — solved problems and conventions, by category, with YAML frontmatter (`module`, `tags`, `problem_type`). Relevant when implementing or debugging in a documented area.
- **Developer Tools** — `docs/dev-tools.md` — the shared browser/CLI inventory and the binding creation and maintenance contract.
- **Shared Vocabulary** — `CONCEPTS.md` — domain terms with project-specific meaning; relevant when orienting to an area or settling on names.
- **Art Ledger** — `docs/art-ledger.md` — points at the upstream art bibles that govern every raster asset, and records the prompts for the few this port authored itself. Relevant before generating or replacing any asset under `assets/art/`.

---

Created during M0 bootstrap (2026-07-24).
