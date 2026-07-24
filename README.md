# Glassvow / 琉璃誓言

A Godot 4.7.1 reimplementation of **Glassvow**, the web-based roguelite deckbuilder. This repo is a parallel port of the reference implementation frozen at [`web-reference-v1`](https://github.com/fol2/roguecardv2/tree/web-reference-v1) in the original roguecardv2 repository. The web engine is the executable specification; parity is proven against the JSON fixtures in `port_fixtures/`. One deliberate redesign: the map is a horizontally-traversed glassvow world, not the web version's vertical tower.

## Verification

```bash
godot --version                          # must print 4.7.1.stable
godot --headless --import                # import .tscn/.gd assets; verify no errors
for f in $(git ls-files '*.gd' | grep -v '^addons/'); do
  godot --headless --check-only -s "$f" || exit 1   # parse + warnings-as-errors gate
done
godot --headless -s res://tests/run_all.gd   # run test suite; must exit 0
```

## Status

**M0 scaffold** — project structure, minimal example scene, test harness, and CI template. Parity implementation begins at M1.

## Fixtures

The `port_fixtures/` directory contains test snapshots and traces generated from the reference web implementation via `roguecardv2/tools/capture-port-fixtures.mjs`. Fixtures are immutable — they are never edited in this repo; regeneration happens only in roguecardv2 and is pushed here via commits.

---

Reference implementation: [fol2/roguecardv2](https://github.com/fol2/roguecardv2) @ web-reference-v1
