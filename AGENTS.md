# Agent Contract — Glassvow Godot

**Glassvow** (琉璃誓言) is a Godot 4.7.1 reimplementation of the web-based roguelite deckbuilder, parallel-ported from the reference implementation. Parity is verified against deterministic test fixtures exported from the web version; the map system is a deliberate redesign (horizontal "glassvow world" journey, not the vertical tower). Before beginning any implementation work, load `.claude/skills/glassvow-godot/SKILL.md` — it binds the engine contract, architecture boundaries, testing strategy, and stop conditions.

## THE REFERENCE — read this before quoting any `file:line`

**The reference is roguecardv2 at commit `6e06911` (2026-07-13). It is PRE-PIXI.**
On this machine that checkout is **`~/Coding/roguecardv2-benchmark`**, and it is
what `http://localhost:5190` serves. Confirm before reading:

```bash
git -C ~/Coding/roguecardv2-benchmark log -1 --format=%h   # must print 6e06911
```

**Do not read parity specs from `~/Coding/roguecardv2`.** That checkout is on
`main`, tag `web-reference-v1` (`1343e1d`, 2026-07-24) — **284 commits ahead** and
**post-Pixi**. It contains `src/ui/combat-gl.js`, `src/ui/combat-presentation.js`,
`src/ui/combat-choreo.js`, `#uigl`, `chromePulse` and a Pixi `artCast`, none of
which exist in the reference. `styles.css` differs by 725+/179−, `drain.js` by
161+/186−, `mesh.js` by 118+/22−, `vfx.js` by 72+/7−. It is still the home of
`tools/capture-port-fixtures.mjs` (see Fixture Provenance) — the fixture
exporter's repo, not the visual reference.

This line used to name `web-reference-v1` as the reference. It was wrong, and on
2026-07-26 that error produced three commits ported against code the benchmark
does not contain (`e071e34`, `d367e44`, `806272c` — reverted or redone).

One rule that follows, learned the same day: **a function existing in the source
is not evidence that it renders.** `ring()` and `slashArc()` push particles with
no `vx`/`vy` while the draw loop does `p.x += p.vx * dt` unconditionally, so
their coordinates go NaN before they draw. They have never appeared on screen at
either commit. Measure on the running page; do not infer from the source.

## Verification (all from repo root)

```bash
godot --version                          # must print 4.7.1.stable
godot --headless --import                # asset import; must complete without errors
for f in $(git ls-files '*.gd' | grep -v '^addons/'); do
  godot --headless --check-only -s "$f" || exit 1   # parse + warnings-as-errors gate
done
godot --headless -s res://tests/run_all.gd   # run test suite; must exit 0 (PASS)
python3 tools/check_anchors.py           # doc file:line anchors still point where they claim
```

Screenshots go through `tools/shot.sh` (one-off) or `tools/live.sh` (iteration
loop) rather than a bare `godot` launch — see `docs/session-ownership.md` ›
Organiser-owned files for why and for the two caveats.

## References

- **SKILL.md** — `.claude/skills/glassvow-godot/SKILL.md` — 10-section binding contract (engine pin, architecture, IDs, save compatibility, stop conditions).
- **Commercial Game Delivery** — `docs/commercial-game-delivery.md` — engine-neutral policy (save versioning, determinism, content stability, performance gates).
- **Fixture Provenance** — `port_fixtures/` is generated only by `roguecardv2/tools/capture-port-fixtures.mjs`; never edited here.
- **Documented Solutions** — `docs/solutions/` — solved problems and conventions, by category, with YAML frontmatter (`module`, `tags`, `problem_type`). Relevant when implementing or debugging in a documented area.
- **Shared Vocabulary** — `CONCEPTS.md` — domain terms with project-specific meaning; relevant when orienting to an area or settling on names.

---

Created during M0 bootstrap (2026-07-24).
