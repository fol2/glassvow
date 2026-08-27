# Glassvow / 琉璃誓言

Glassvow is a Godot 4.7.2+ roguelite deckbuilder. The project began as a port of a web game, but detached from that reference on 2026-08-16. This repository now owns its behaviour and content; the 18 files in `port_fixtures/` are port-owned regression goldens, and the commercial rubric is the product standard. The world map is a deliberate horizontal journey rather than the former vertical tower.

## Development

Read `AGENTS.md` first. The repository uses a risk-proportional AI-SDLC: pure research is isolated from delivery, feature-branch pushes do not duplicate CI, pull requests run one audited scope-aware gate, and each push to `main` reclassifies the exact introduced tree diff on the integrated branch. CI-authority and unknown production inputs fail closed; daily scheduled and manual runs retain the complete maintained integration gate.

To inspect the scope selection for a committed branch diff:

```bash
git diff --name-only --no-renames -z origin/main...HEAD > /tmp/glassvow-ci-paths.zlist
python3 -B tools/ci_scope.py \
  --changed-paths-nul /tmp/glassvow-ci-paths.zlist \
  --repository-root .
```

The classifier is deterministic, supports overlapping scopes, explains every selected and skipped check, and fails closed on malformed or unknown production input. Its focused fixtures live in `tests/test_ci_scope.py`.

During implementation, run the narrow deterministic check that answers the current question. For production Godot delivery, run import, the full tracked-script parse, and the discovered Godot suite once on the coherent final candidate before first push. Documentation and isolated balance/ML tooling run only their matching checks.

## Architecture

Pure game logic lives in `domain/`; `GlassvowGame.apply` is the command-to-event seam, and presentation never owns game truth. Internal IDs, seeded randomness, the v2 save lineage, and load validation are compatibility contracts. Deeper engine and editing guidance lives in `.claude/skills/glassvow-godot/SKILL.md`.

## Delivery standard

The active standard is `docs/commercial-rubric.md` and `docs/rc-bar.md`. Historical web-reference citations are frozen and no new ones may be added. The detachment decision and measurements are recorded in `docs/benchmark-divergence.md` and issue #317.

The development operating model is documented in `docs/agents/ai-sdlc.md`.
