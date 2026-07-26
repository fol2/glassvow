# Agent Contract — Glassvow Godot

**Glassvow** (琉璃誓言) is a Godot 4.7.1 reimplementation of the web-based roguelite deckbuilder, parallel-ported from the reference implementation frozen at [web-reference-v1](https://github.com/fol2/roguecardv2/tree/web-reference-v1). Parity is verified against deterministic test fixtures exported from the web version; the map system is a deliberate redesign (horizontal "glassvow world" journey, not the vertical tower). Before beginning any implementation work, load `.claude/skills/glassvow-godot/SKILL.md` — it binds the engine contract, architecture boundaries, testing strategy, and stop conditions.

## Verification (all from repo root)

```bash
godot --version                          # must print 4.7.1.stable
godot --headless --import                # asset import; must complete without errors
for f in $(git ls-files '*.gd' | grep -v '^addons/'); do
  godot --headless --check-only -s "$f" || exit 1   # parse + warnings-as-errors gate
done
godot --headless -s res://tests/run_all.gd   # run test suite; must exit 0 (PASS)
```

## References

- **SKILL.md** — `.claude/skills/glassvow-godot/SKILL.md` — 10-section binding contract (engine pin, architecture, IDs, save compatibility, stop conditions).
- **Commercial Game Delivery** — `docs/commercial-game-delivery.md` — engine-neutral policy (save versioning, determinism, content stability, performance gates).
- **Fixture Provenance** — `port_fixtures/` is generated only by `roguecardv2/tools/capture-port-fixtures.mjs`; never edited here.
- **Documented Solutions** — `docs/solutions/` — solved problems and conventions, by category, with YAML frontmatter (`module`, `tags`, `problem_type`). Relevant when implementing or debugging in a documented area.
- **Shared Vocabulary** — `CONCEPTS.md` — domain terms with project-specific meaning; relevant when orienting to an area or settling on names.

---

Created during M0 bootstrap (2026-07-24).
