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

The first Web build needs Godot's exact `4.7.1.stable`
`web_nothreads_debug.zip` export template. Install the Web debug template from
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
| Editor scene inspection and mutation | Funplay editor plugin | Editor MCP only |

Additional flags stay owned and parsed by their lab. The browser allow-list
rejects another surface's selector and any flag that deliberately exits the live
host. Temporal enemy strips therefore remain one-off captures:

```bash
tools/shot.sh --enemies --idle=gloomslime --strip=/tmp/idle.png
```

For a native iteration loop use `tools/live.sh start …`, then `shot`, `reload`,
`resize W H`, `key`, `click`, `drag` and `stop`. `resize` changes the existing
Godot window, so it is the headed gate for a live shape change without rebuilding
the current screen. Non-visual tools remain direct, honest
commands: `tools/check_anchors.py`, `godot --headless -s
res://tools/check_fracture.gd`, the windowed
`res://tools/bench_actor_stage.gd` probe, and:

```bash
godot --headless -s res://tools/probe_layout.gd -- --all [--act=N]
```

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
