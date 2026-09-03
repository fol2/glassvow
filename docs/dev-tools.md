# Developer tools

This is the authority for creating, finding and maintaining Glassvow developer
tools. The organiser owns `tools/`; every lane may run the tools, but changes to
the shared launcher, capture host or top-level registry are sequenced through the
organiser.

## One front door

```bash
python3 tools/dev.py --open
```

The browser at `http://127.0.0.1:8766` offers two render paths over one
catalogue:

- **Interactive Web** exports the project and runs the selected scene directly
  in a Godot Web canvas. Start/restart and Reload code make a fresh debug export
  in ignored, regenerate-only `build/web-dev/`.
- **Native Proof** drives the existing native host and projects its viewport.
  Use it for frame-accurate motion, final approval and tools that write back to
  the checkout.

Use **Hide controls** to collapse the catalogue and give the running surface the
full browser width.

Neither path reimplements a screen. Both route the selected flags through
`application/main.tscn` and the normal `main.gd` parser.

Funplay's **editor MCP** is a separate inspection and mutation surface, not a
third renderer. It exists only while the Godot editor is open and its HTTP
server is enabled. Native Proof instead uses Funplay's file-backed **runtime
bridge** inside the running game; it does not depend on the editor MCP or port
8765.

The first Web build needs Godot 4.7.2 stable or later stable, with that engine's
matching `web_nothreads_debug.zip` export template. Install the Web debug template from
**Editor → Manage Export Templates**, or ask the organiser to provision it.
For a build-only check:

```bash
python3 tools/dev.py --build-web
```

For a trusted LAN or Tailscale connection:

```bash
python3 tools/dev.py --host=0.0.0.0
```

Non-loopback binding generates a per-session token. Use the printed tokenised URL
with this Mac's trusted hostname. API calls and Web export assets share that
session boundary. Never expose this process to the public internet: it can
export, start, reload and control development builds.

Plain HTTP LAN and Tailscale Web sessions use Godot's Dummy audio driver because
browser audio worklets require a secure context. Localhost or HTTPS keeps audio.

The Enemy bench and the Layout book are interactive in both paths, but saving is
deliberately Native Proof-only: a Web export cannot write back into the
checked-out `res://` tree. Neither bench discovers this at the file — the guard
is in `DataFile.write`, so a Web session is told it cannot save instead of
failing halfway through one.

## Inventory

| Surface | Authority | Browser |
|---|---|---|
| World and run | `application/main.gd` default route | `World & run` |
| Real combat bench | `--fight=… --kind=… --seed=…` | `Combat bench` |
| Card catalogue / materials | `--cards`, `--surfaces` | `Card catalogue` |
| Card material editor | `--studio` | `Card studio` |
| Enemy roster / states / fracture sheet | `--enemies` | `Enemy roster` |
| Enemy and fracture editor | `--enemies --bench` | `Enemy bench` |
| Status and intent chips | `--chips` | `Status & intent chips` |
| Scripted HUD mock | `--hud` | `HUD mock` |
| Fixed-spoils reward mock | `--reward` | `Reward mock` |
| Stage-shape layout authoring | `--layout --shape=… --scope=… --act=…` | `Layout book` |
| Scenario launch | `--scenario=<json>` via `python3 tools/dev.py --scenario` | CLI only |
| Editor scene inspection and mutation | Funplay editor plugin | Editor MCP only |
| Music / SFX generation | `.claude/skills/glassvow-suno`, `.claude/skills/glassvow-elevenlabs`, `.cursor/mcp.json` | not a browser surface — ledgers `docs/music-ledger.md`, `docs/sfx-ledger.md` |

### Hosted execution provenance

The manual `Linux execution provenance evidence` workflow keeps its workload
profiles separately gated. The original qualified inert profile remains fixed.
The additive `godot-runtime` qualification mode is limited to the measured
Godot 4.7.2 headless path: one exact current-main product, one external
GDScript, one corpus, one request index, a fresh HOME, and a fresh output
directory. It is a provenance capability, not a general executable sandbox or
evidence that a research or balance claim is correct.

A Godot run accepts an exact product commit, packet commit, packet root, and
OWNER-authored authority comment. The packet commit must have current main as
its sole parent and may add only the manifest-declared regular `.gd` and `.json`
roles below that root. The trusted workflow, profile, runner, tracer, and
verifier always come from the observer checkout. The declared GDScript executes
only through the bound Godot invocation; packet content is never imported or
executed as shell, Python, or workflow code. Product and packet inputs are
mounted read-only. Full profile qualification re-runs the unchanged inert
campaign before the frozen actual-Godot matrix and publishes only bounded
capability evidence.

The separate `godot-runtime-a1` mode admits one packet-declared request through
the same qualified G00 path. It runs only from exact current `main`, requires
the fixed #421 A1-v2 owner authority and an exact-main #535 PASS marker bound to
the successful specialist run and independently rehashed campaign receipt. Its
admission receipt also binds the exact capability run, receipt, and prerequisite
record. A1 does not consume the #535 qualification-attempt budget, interpret
mutation meaning, or replace A1's separately frozen scientific contract. The
owning research run deletes its ephemeral packet ref after publishing the
terminal receipt.

Additional flags stay owned and parsed by their lab. The browser allow-list
rejects another surface's selector and any flag that deliberately exits the live
host. Temporal enemy strips therefore remain one-off captures:

```bash
tools/shot.sh --enemies --idle=gloomslime --strip=/tmp/idle.png
```

A Development Scenario launches Native Proof through the same `--scenario=<json>`
flag the excluded boot handler already owns. Pass the reference verbatim, or
compose the bounded Custom controls with `--scn key=value`:

```bash
python3 tools/dev.py --scenario='{"id":"custom","revision":1,"seed":7}'
python3 tools/dev.py --scenario --scn seed=7 --scn gold=10 --scn add_cards=strike,defend
python3 tools/dev.py --scenario --scn id=vigil --scn shards=6
```

For a native iteration loop use `tools/live.sh start …`, then `shot`, `reload`,
`resize W H`, `key`, `click`, `drag` and `stop`. `resize` changes the existing
Godot window, so it is the headed gate for a live shape change without rebuilding
the current screen.

Native Proof click and drag map captured backing-store pixels through the Stage
rectangle the live host reports on the runtime-bridge heartbeat (`window_size`,
`stage_size`, `stage_rect`). The capture is the drawn Stage (or, if it matches
the window, the full window including KEEP bars). That conversion handles a
resized window, a letterboxed Stage, and non-1× Retina captures. It fails
rather than guessing when the geometry is missing, stale, or the point falls
outside the Stage.
`python3 tools/dev.py --check` covers the mapping. Interactive Web does not use
this path: the browser delivers events to the Godot canvas directly. Non-visual tools remain direct, honest
commands: `tools/check_imports.sh`, `tools/check_anchors.py`,
`tools/check_benchmark_freeze.py`, `godot
--headless -s res://tools/check_fracture.gd`, the windowed
`res://tools/bench_actor_stage.gd` probe, and:

```bash
godot --headless -s res://tools/probe_layout.gd -- --all [--act=N]
```

The #128 runtime-font proof also stays on the headed capture route. It renders
an unoverridden `Label` through `GlassStyle.theme().default_font`, verifies the
four title glyphs, captures, and exits:

```bash
tools/shot.sh --font-probe --shot=/tmp/glassvow-runtime-font.png
```

Whole-run balance calibration is a CLI-only, domain simulation. The default
replays both aspects over the same 200 contiguous seeds; `--out` retains the
manifest, every run row, derived metrics and calibration verdict as JSON:

```bash
godot --headless -s res://tools/balance_sim.gd -- --aspect=all --runs=200 \
  --seed0=1000 --vow=0 --out=/tmp/balance.json [--mobs=path.json]
```

Map layout is measured the same way, over seeds rather than shapes. The probe
deals the scenery for each seed and prints rates — overlapping waystone pairs,
nodes hidden behind scenery, scenery fouling scenery, the largest shove the node
solver applied — so a layout change is judged by a before/after number instead
of by six screenshots:

```bash
godot --headless -s res://tools/probe_map_seeds.gd -- --seeds=200
```

**`tools/probe_map_seeds.gd` reports a rate, never a verdict, and its
thresholds are its own.** The clumping counter it ships with fires at `gap <
1.0` — footprints just touching. Figures quoted elsewhere in the repo are
sometimes taken at half or three-quarter reach; instrument for the threshold you
mean to quote rather than assuming the shipped one matches. Its footprint radius
and hide-depth arithmetic is duplicated from `MapScene._bind_asset_geometry`,
which has already drifted once — the probe's own header carries that warning.

**`tools/probe_layout.gd` reads the composition back rather than photographing
it.** A capture shows where something LOOKS like it is; on a 390px phone that is
how a twelve-pixel error survives. The probe builds the real `CombatScreen` at a
shape, lets the entrance settle, and prints every box in stage px as gaps from
the edge each is bound to — so a row can be compared with the layout book, and
with the benchmark's own DOM measurements, without arithmetic. It is what found
the hand fanning 586px wide instead of 282 everywhere but a running game.

Two capture flags exist for the same reason:

- **`--act=N`** stages a fight at any act. The domain does not model acts, so a
  `--fight=` bench is act 0 and the other two were reachable only through the
  layout bench.
- **`--settle=SECONDS`** photographs a composition at rest. Thirty frames is
  enough for a first paint and not for a fight: the opening hand is still in the
  air at half a second, so two runs of the same build differed across 2.4% of the
  frame, all of it in the fan. With `--settle=4` that falls to 0.03%, which is
  what makes a before/after diff of a layout change readable at all.

## Creation and maintenance contract

1. First reuse a shipping screen, existing lab mode or existing probe. Do not
   create a second viewer for the same subject.
2. Classify the tool: a production bench follows the real game path; a lab
   isolates presentation; a probe measures and exits. Name mocks as mocks.
3. Visual surfaces live in `presentation/lab/`; shell, browser and measurement
   orchestration live in `tools/`; assertions that belong to every build live in
   `tests/`.
4. `application/main.gd` owns top-level selection. A lab owns its detailed
   arguments. Add a browser catalogue entry in `tools/dev.py` only when the
   surface can remain alive safely.
5. Web runtime data hidden by `.gdignore` belongs in the narrow allow-list in
   `addons/glassvow_web_export/plugin.gd`; do not export the fixture tree.
6. Native window-sizing helpers must return on Web; the browser owns canvas
   geometry and its input transform.
7. A lab constructing production UI must mirror every production setup call
   before first paint. Record intentional differences beside the call.
8. Do not add a dependency for tooling covered by Godot, the Python standard
   library or the existing runtime bridge. The runtime bridge is not the
   editor-bound Funplay MCP server.
9. Leave one runnable check. At minimum run `python3 tools/dev.py --check`,
   `python3 tools/dev.py --build-web`, the changed GDScript parse check, and the
   project verification gate. Inspect a real browser canvas and native capture
   for any presentation change.

Browser support is earned by a safe lifecycle, not by adding a link. Tools that
quit, write arbitrary paths, require a real-time renderer, or expose broad editor
mutation stay CLI-only until those constraints change.

## Web-reference citations — frozen, and counted

`tools/check_anchors.py` owns in-repo citations. Web references — `styles.css:834`,
`src/ui/drain.js:511-512`, bare `mesh.js:928` — used to be resolved against a
checkout of the pinned pre-Pixi benchmark. **They are not resolved any more.** The
port detached from the reference on 2026-08-16 (#317), the 607 existing citations
are frozen as history, and writing a new one is banned:

```bash
python3 tools/check_benchmark_freeze.py           # exit 1 if the count moved
python3 tools/check_benchmark_freeze.py --update  # re-baseline DOWNWARD only
```

It counts `*.js` / `*.css` `file:line` forms per file against
`tools/benchmark-citations.txt` and fails on any increase — `--update` refuses to
raise a number, so adding a citation means editing the census by hand where a
reviewer sees it. A decrease also fails, with instructions to re-baseline, so that
removing one citation cannot quietly fund another in the same file.

**Why counting replaced resolving.** The old gate needed the benchmark checkout,
so it returned exit 2 — "benchmark tree not found" — on every CI runner and inside
every git worktree, and had to be run by hand. With new citations banned outright,
the count is the whole of the rule, and a gate that needs nothing runs everywhere
the rule can be broken. The old tool's method is described in
`docs/benchmark-divergence.md` if it is ever wanted again; it read `.js` / `.css`
cites, range-checked them against the benchmark `src/` tree, then asked whether a
backticked token from the citing prose still sat within ±20 lines.
