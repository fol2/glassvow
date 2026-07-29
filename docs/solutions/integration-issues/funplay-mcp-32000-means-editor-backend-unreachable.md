---
title: "A funplay `-32000` means its configured editor backend is unreachable"
date: 2026-07-27
last_refreshed: 2026-07-29
category: integration-issues
module: addons/funplay_mcp
problem_type: integration_issue
component: tooling
severity: high
symptoms:
  - "`/mcp` reports `Failed to reconnect to funplay: -32000` and the code carries no diagnostic detail"
  - "`lsof -nP -iTCP:8765` shows nothing listening and `curl http://127.0.0.1:8765/` returns HTTP code `000`"
  - "Every config check passes — plugin enabled in `project.godot`, token and port in `funplay_mcp_settings.cfg` matching the client — while the bridge stays down"
  - "Every funplay tool fails identically, because they all funnel through the same HTTP hop"
  - "A successful `/mcp` reconnect still runs the old client version, because `--mcp-config` froze it into the session's arguments"
root_cause: incomplete_setup
resolution_type: environment_setup
related_components:
  - "development_workflow"
  - "documentation"
tags: [mcp, funplay, godot-editor, stdio-bridge, port-8765, version-skew, claude-code-config, diagnosis]
---

# A funplay `-32000` means its configured editor backend is unreachable

## Problem

Claude Code's `/mcp` panel reported `Failed to reconnect to funplay: -32000` — a
bare JSON-RPC error code with no message — while every piece of funplay
configuration on the machine was correct. The `funplay` MCP server is a stdio
*relay* to an HTTP server that lives inside the Godot editor. In this incident
no editor was open on the project, so there was nothing on the far end of the
relay.

The code does not make “editor closed” the only possible cause. The editor
plugin can be disabled, and a running server can select a fallback port when
its configured port is occupied. The durable meaning of the error is narrower:
the relay could not reach the editor backend at its configured URL.

**This project already knew that, in two places, and it cost a full diagnosis
anyway.** That is the part worth reading; the fix itself is one command.

## Symptoms

The panel gives you one line and one number:

```
Failed to reconnect to funplay: -32000
```

`-32000` is the JSON-RPC implementation-defined server-error band. It names no
server, no host and no failure mode. Everything useful lives in the `message`
field the panel does not surface.

Underneath it the port was simply dead:

```
$ lsof -nP -iTCP:8765
                                  # no output — nothing listening

$ curl -s -m 3 -o /dev/null -w "%{http_code}" http://127.0.0.1:8765/
000                               # connection refused
```

Every funplay tool fails the same way — `get_project_info`, `get_scene_tree`,
anything — because they all funnel through that one HTTP hop.

## What Didn't Work

This investigation was short and had no dead ends worth calling failures. What
it had instead is more useful to record: **a configuration surface that was
correct in every particular**, and that would absorb an afternoon from anyone
who took the symptom at face value.

`-32000` on a *reconnect* reads like a handshake problem, and a handshake
problem invites you to audit the handshake. Here is exactly how much nothing
that audit finds.

**The client entry was well-formed.** `~/.claude.json` → `mcpServers.funplay`
carried `type: stdio`, `command: npx`, `args: ["-y", "funplay-godot-mcp@0.9.4"]`,
and an `env` with `FUNPLAY_GODOT_MCP_URL=http://127.0.0.1:8765/` plus a 64-hex
`FUNPLAY_GODOT_MCP_TOKEN`. Note that `~/.claude.json` is a machine-local,
untracked file outside this repository: nothing in a checkout can confirm or
contradict it, and every quotation of it here is one session's reading of one
developer's file on one machine.

**The addon is enabled in the project.** `project.godot:32` (`enabled`) includes
Funplay alongside the Web-export helper:

```ini
[editor_plugins]

enabled=PackedStringArray(
    "res://addons/funplay_mcp/plugin.cfg",
    "res://addons/glassvow_web_export/plugin.cfg",
)
```

**The Godot-side settings agreed with the client.** The plugin persists to
`user://funplay_mcp_settings.cfg` —
`addons/funplay_mcp/core/funplay_mcp_settings.gd:6` (`SETTINGS_PATH`) — which on
macOS resolves under `~/Library/Application Support/Godot/app_userdata/Glassvow/`.
At the time of the failure it read `enabled=true`, `port=8765`,
`tool_profile="core"`, and an `auth_token` byte-identical to the client's.

**The defaults agreed too.** The settings object defaults the port at
`addons/funplay_mcp/core/funplay_mcp_settings.gd:9` (`server_port`) and the
server repeats it at
`addons/funplay_mcp/core/funplay_mcp_server.gd:9` (`DEFAULT_PORT`) — both
`8765`. There was no port to get wrong.

Token matches, port matches, URL matches, plugin enabled, server enabled: five
correct readings, zero progress. This project has already named the trap, in
[Capture through a long-lived host, not a process per screenshot](../tooling-decisions/long-lived-capture-host-not-process-per-shot.md)
— *a configuration that reads back correctly is evidence about the
configuration, not about the behaviour.* Configuration describes what will
happen when a process runs. It says nothing about whether the process is
running.

### The answer was already in the tree, filed under the wrong retrieval key

This is the finding that justifies the document.

`docs/port-status.md:99` has carried the diagnosis since the M5 milestone note:

> Funplay MCP handshake still pending (editor must be opened once) — the --shot
> loop covers agent iteration meanwhile.

And the binding contract states it as a numbered precondition —
`.claude/skills/glassvow-godot/SKILL.md:69`, § 6 *Visual Inspection*, step 1:
"Godot editor open, MCP connected (port 8765)."

So the cause was written down twice, in a status ledger and in a contract every
agent is required to read. It was still diagnosed from scratch on 2026-07-26 —
session history shows the same `fetch failed` message reached the same
conclusion in roughly seven minutes, as a side-quest during a machine migration,
and it was never written up — and then diagnosed from scratch again today.

Both existing records are indexed by the *answer* ("the editor must be opened"),
filed under a milestone heading and a workflow step. Neither is indexed by the
*symptom*: nobody holding the string `-32000` will grep their way to either one.
**Correct knowledge stored under a retrieval key nobody searches from is
knowledge that gets rediscovered.** A precondition documented in a setup
procedure is not the same artifact as a failure signature documented against its
error text, and the second is what a person in trouble actually has.

## Solution

Two moves. The first converts the opaque code into a real message; the second is
the fix.

### Run the stdio server yourself and read the message

An MCP client shows you the code. Running the server by hand shows you the
message. Pipe a JSON-RPC handshake into the same command the client runs, with
the same environment:

```bash
FUNPLAY_GODOT_MCP_TOKEN=<token> FUNPLAY_GODOT_MCP_URL=http://127.0.0.1:8765/ \
  npx -y funplay-godot-mcp@0.9.6 <<'EOF'
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"probe","version":"1"}}}
{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}
EOF
```

Against the dead port, verbatim:

```json
{"jsonrpc":"2.0","id":1,"error":{"code":-32000,"message":"Failed to reach Godot MCP at http://127.0.0.1:8765/: fetch failed"}}
```

That names the failure completely: the relay could not reach its backend.
`-32000` and `Failed to reach Godot MCP at …: fetch failed` are the same event;
only one of them is a diagnosis.

### Restore the configured editor backend

First distinguish an absent editor from a live editor whose server is disabled
or listening on another port. The server can persist `server_enabled=false`,
and `FunplayMcpServer.start()` can select a fallback from port 8766 upwards when
the configured port is occupied
(`addons/funplay_mcp/core/funplay_mcp_server.gd:44-75`, in `start`, and
`addons/funplay_mcp/core/funplay_mcp_server.gd` (in
`_resolve_startup_port`)). Read the live listener or the editor
dock before changing the relay URL.

When no editor process is serving the project, start it:

```bash
nohup godot --editor --path . >/tmp/godot-editor.log 2>&1 &
```

Port 8765 began listening roughly four seconds later — polled with `curl` in a
one-second loop, then confirmed with `lsof` showing
`Godot <pid> ... TCP 127.0.0.1:8765 (LISTEN)`. Re-running the handshake
returned:

```
initialize OK: {"name": "Funplay MCP Server - Godot", "projectIdentity": "<16-hex>", "projectName": "Glassvow", "version": "0.9.6"}
tools: 78
```

By this project's own record that was the **first** successful funplay handshake:
`docs/port-status.md:99` had described it as pending since before 2026-07-24, so
this is a never-worked path being made to work, not a regression being repaired.

There is no PR. This was a local environment fix on one machine; nothing in the
repository changed as a result of it.

### What opening the editor does to `project.godot` — and what it does not

Measured this session: the editor rewrote `project.godot` eight seconds after
launch (editor start 09:50:22, file mtime 09:50:30). The diff reordered sections
and dropped three lines that were in the committed file:
`buses/default_bus_layout`, `gdscript/warnings/exclude_addons=true`, and
`window/stretch/aspect="keep"`.

**None of the three is a behaviour change, and restoring them by hand would be
wrong.** Checked against the running engine rather than assumed:

| Dropped line | `ProjectSettings` at 4.7.1 | Why it vanished |
|---|---|---|
| `window/stretch/aspect="keep"` | `has=true`, value `keep` | equals the engine default; Godot omits defaults on save |
| `buses/default_bus_layout` | `has=true`, value `res://default_bus_layout.tres` | same |
| `gdscript/warnings/exclude_addons` | **`has=false`** | not a registered setting in 4.7.1 — it was a dead key |

The parse gate from AGENTS.md passes over every non-addon `.gd` file after the
rewrite, which is the outcome that matters; that gate never depended on
`exclude_addons` anyway, because the loop already excludes those files itself
with `grep -v '^addons/'`.

The real cost is therefore ownership, not correctness: `project.godot` belongs to
the Assembly lane (`docs/session-ownership.md:31`) and six lanes share this tree,
so an editor launch silently puts another lane's file in the working set. It was
reverted with `git checkout -- project.godot` once the settings above were
confirmed unchanged. **Opening the editor is not a read-only act — check
`git status` afterwards.**

### The version skew found on the way

The npm client was pinned at `0.9.4`; the addon in the tree reports `0.9.6` at
`addons/funplay_mcp/plugin.cfg` (`version="0.9.6"`), and the server constant
agrees at
`addons/funplay_mcp/core/funplay_mcp_server.gd:8` (`SERVER_VERSION`).
`npm view funplay-godot-mcp version` returns `0.9.6`, so the pin was simply
stale. The client entry was updated to `0.9.6` and the handshake re-verified.
The skew did not cause this failure, and it was invisible until someone ran the
handshake by hand.

### Editing the client config does not reach a running session

This session's MCP config had been passed on the command line, with the version
baked into the argument. That is directly observable in the process table: `ps`
showed the running Claude process still carrying
`--mcp-config {"mcpServers":{"funplay":{...,"args":["-y","funplay-godot-mcp@0.9.4"],...}}}`
*after* the file on disk had been changed to `0.9.6`. `/mcp` reconnect re-reads
that frozen copy, not the file. The reconnect succeeded and produced a working
server — on the old client version. A session restart is required for the bump
to land.

Worth stating alone, because it misleads twice:
**`/mcp` reconnect proves the server is reachable, not that your config edit
took effect.**

## Why This Works

The funplay HTTP server extends `EditorPlugin`
([`addons/funplay_mcp/plugin.gd`](../../../addons/funplay_mcp/plugin.gd)), and
the first thing
`_enter_tree` does is refuse to run anywhere else —
`addons/funplay_mcp/plugin.gd:21-23` (in `_enter_tree`):

```gdscript
func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		return
```

The listener starts from that same hook at
`addons/funplay_mcp/plugin.gd:36-37` (in `_enter_tree`) and is torn down in
`addons/funplay_mcp/plugin.gd:45-46` (in `_exit_tree`). The server's lifetime is
exactly the editor's lifetime. It is not a daemon, it does not outlive the
editor, and — the part that makes the symptom confusing — **the stdio bridge
cannot start it.** The npm package is a relay: it speaks MCP on stdin and HTTP
to `FUNPLAY_GODOT_MCP_URL`, and it has no way to bring that URL into existence.

That is why the config audit found nothing. This was an environment state, not a
misconfiguration, and no amount of reading the description tells you whether the
process is up.

The general shape is worth keeping separately from funplay: **when an MCP server
is a relay rather than the thing itself, its error surface reports its own
health.** The backend's absence arrives at the client as a generic transport
failure. Ask what owns the port before asking what configures it.

## What the tools then tell you, and what they do not

Once the editor is up the tools answer, but three details of their output
mislead a reader who has not been warned. All three were measured this session.

**`current_scene_path` is not the scene path.** `get_project_info` returned
`"current_scene_path": "res://"` — effectively empty — while
`current_scene_root` carried the real answer in its `scene_file_path`
(`res://application/main.tscn`). Trust `current_scene_path` and you will
conclude no scene is open.

**These tools read the editor's live scene tree, not the `.tscn` on disk.** The
returned node `path` is a chain through the editor's own UI:

```
/root/@EditorNode@19523/…/@SubViewportContainer@9914/@SubViewport@9915/Main
```

The scene is a node inside the editor's canvas SubViewport. So the tools report
what the editor currently holds — *including unsaved edits* — and they report
nothing at all when the editor is closed. They are not a file reader.

**`get_scene_tree` returning `children: []` is correct here.**
[`application/main.tscn`](../../../application/main.tscn) has a lone
`[node name="Main" type="Control"]`
with the script attached and no child nodes; everything the game shows is built
at runtime by `application/main.gd`. An empty `children` array is the honest
answer for this project's main scene, not a broken read.

**And the settings file is not a reliable statement of the live port.** Measured
after the fix: the file on disk reads `port=8766` while the running server
reports `server_port: 8765` and `lsof` confirms the listener is on 8765. The
mechanism is in the tree — `addons/funplay_mcp/core/funplay_mcp_server.gd:60-72`
(in `start`) resolves a startup port and overwrites the setting when it differs,
and `addons/funplay_mcp/core/funplay_mcp_server.gd:219-230`
(in `_resolve_startup_port`) is the walk upward from `DEFAULT_PORT + 1` that
picks the replacement. What triggered this particular rewrite was not traced, so
treat the *cause* as unexplained and only the *divergence* as measured. Read the
live port from `get_project_info` or `lsof`, never from the file.

## Two funplay surfaces, one name

`get_capability_status` returned `runtime_bridge_installed: false` alongside
`runtime_bridge_command_channel: true`, which reads as a contradiction until you
see that funplay is two things:

| Surface | What it is | Transport | Lifetime |
|---|---|---|---|
| **Editor plugin** | the MCP server `/mcp` connects to | HTTP on `127.0.0.1:8765` | the editor's |
| **Runtime bridge** | a `Node` inside a *running game* answering scene/input/capture commands | `user://` command and response JSON files | the game process's |

The bridge's file channel is declared at
`addons/funplay_mcp/runtime/funplay_mcp_runtime_bridge.gd:3-6` (`STATE_PATH`) —
state, command, response and screenshot paths, all under `user://`. No sockets,
no ports.

The two are disjoint at runtime, and the cleanest proof is a negative: **no code
under `tools/` ever contacts the port.** Grepping `8765` across `tools/` returns
exactly one hit, and it is a comment in the anchor checker explaining that a
port is not a `file:line` anchor (`tools/check_anchors.py:44`). The capture
harness talks only to `user://funplay_mcp_runtime_*.json`
(`tools/live.sh:26-28`), which is why `tools/live.sh` kept working normally
throughout the outage. "funplay is down" is ambiguous between two independent
failures that share nothing but a name.

`install_runtime_bridge` registers the bridge script as a project autoload —
`addons/funplay_mcp/core/funplay_core_tools.gd:3397-3408`
(in `install_runtime_bridge`), with the names at
`addons/funplay_mcp/core/funplay_core_tools.gd:41-43`
(`RUNTIME_BRIDGE_AUTOLOAD_NAME`). It is not installed here, so the play-mode
tools that need it (`query_runtime_node`, `send_runtime_input`,
`get_runtime_events`) will not answer until it is — and **that call writes
`project.godot`**, an Assembly-lane file. Weigh it against
`docs/session-ownership.md:31` first.

The project has not needed it, because `tools/live.gd` instantiates the bridge
itself, per-host rather than project-wide: same script at
`tools/live.gd:25` (`BRIDGE_SCRIPT_PATH`), added as a plain child in
`tools/live.gd:42-48` (in `_ready`). That is exactly why the capture harness
never had to touch `project.godot`.

## Prevention

- **Recognise the boundary.** `-32000` from funplay with no message means the
  relay could not reach its configured editor URL. Check that exact URL with
  `curl` and inspect listeners before opening a config file. No listener usually
  means the editor or plugin is not running; a listener on another port means
  the relay is stale.
- **When a client gives you a code, run the server yourself to get the
  message.** The stdio contract makes this cheap — same `command`, same `env`, a
  two-line handshake on stdin. This generalises to every stdio MCP server, not
  just funplay.
- **Ask what owns the port before auditing what configures it.** When a backend
  is embedded in another application — an editor plugin, an IDE extension, a
  debugger — its absence is indistinguishable at the client from a transport
  fault, and the config reads perfectly the whole time.
- **File the signature, not only the precondition.** The cause of this failure
  was documented twice before today and rediscovered twice anyway, because both
  records were indexed by the answer rather than by the error text. When a setup
  step has a known failure mode, write the failure mode down next to its
  message.
- **After editing the client config, restart the session.** A `--mcp-config`
  launch freezes the config into the process arguments;
  `ps -Ao command | grep mcp-config` shows what the running session actually
  holds. A successful reconnect says nothing about whether your edit landed.
- **Expect the npm pin and the addon to drift.** Separate artifacts, separate
  update paths: the pin lives in the machine-local client config, the addon is
  vendored under `addons/funplay_mcp/`. Compare with
  `npm view funplay-godot-mcp version` when anything behaves oddly.
- **Check `git status` after opening the editor.** It rewrote `project.godot`
  within eight seconds here. Nothing behavioural changed, but the file belongs to
  another lane and a shared tree should not carry churn from a session that only
  wanted a screenshot.
- **Know which surface you are asking about.** Editor tools need the editor open
  (HTTP 8765); runtime tools need a bridge inside a running game (`user://`
  files).
### One loose end, noted rather than resolved

The addon is committed twice. `addons/funplay_mcp/` holds the full plugin, and
`addons/` itself holds a second copy at its own root (`addons/plugin.cfg`,
`addons/plugin.gd`, `addons/core/`, `addons/runtime/`, `addons/ui/`). Both are
tracked; the `.gd` sources are byte-identical and only the generated `.uid`
files differ, which is what two unpacks of the same archive at different roots
would produce. The enabled Funplay plugin is unambiguous — `project.godot:32`
(`enabled`) points at `res://addons/funplay_mcp/plugin.cfg`, and nothing lists
the root-level copy — so `addons/funplay_mcp/` is live and every citation here is
against it. Whether the duplicate is harmless or should go was not investigated;
removing it would touch tracked files. Left as found, flagged for the organiser.

## Related

- `addons/funplay_mcp/plugin.gd` (`_enter_tree`) and
  `addons/funplay_mcp/plugin.gd` (`_exit_tree`) — the editor-only guard and the
  start/stop pair that define
  the server's lifetime. The whole root cause is these three fragments.
- `addons/funplay_mcp/core/funplay_mcp_server.gd` (`SERVER_VERSION`),
  `addons/funplay_mcp/core/funplay_mcp_server.gd` (`DEFAULT_PORT`),
  `addons/funplay_mcp/core/funplay_mcp_server.gd` (`start`) and
  `addons/funplay_mcp/core/funplay_mcp_server.gd`
  (`_resolve_startup_port`) — the reported version, default port, and fallback.
- `addons/funplay_mcp/core/funplay_mcp_settings.gd` (`SETTINGS_PATH`) and
  `addons/funplay_mcp/core/funplay_mcp_settings.gd` (`server_port`) — where the
  Godot-side settings live and what they default to.
- `addons/funplay_mcp/runtime/funplay_mcp_runtime_bridge.gd:3-6` (`STATE_PATH`)
  — the *other* funplay surface: a `user://` file channel with no port and a
  different lifetime.
- `addons/funplay_mcp/core/funplay_core_tools.gd`
  (`RUNTIME_BRIDGE_AUTOLOAD_NAME`) and
  `addons/funplay_mcp/core/funplay_core_tools.gd`
  (`install_runtime_bridge`) —
  why installing the bridge is a `project.godot` write rather than a runtime
  action.
- `tools/live.gd` (`BRIDGE_SCRIPT_PATH`) and `tools/live.gd` (in `_ready`) — the
  capture host wiring that same bridge per-process instead of as an autoload.
- `project.godot:32` (`enabled`) — the enabled Funplay plugin path, and the
  reason the root-level duplicate is not the live copy.
- [`application/main.tscn`](../../../application/main.tscn) — a root `Control`
  with a script and no
  children, which is why `children: []` is the correct answer.
- `docs/port-status.md:99` — the pre-existing statement of this root cause,
  filed under an M5 milestone note. Now stale in the other direction: the
  handshake is no longer pending.
- `.claude/skills/glassvow-godot/SKILL.md:69` — § 6 step 1, the same
  precondition as a contract clause. Step 3 of that section names a command
  (`mcp screenshot …`) that does not exist in the 78-tool surface; the real
  captures are `capture_editor_view` and `capture_runtime_view`. Only visible
  once the handshake worked.
- `docs/session-ownership.md` — the `project.godot` and `tools/` ownership rules
  both matter before running
  `install_runtime_bridge` or committing what the editor rewrote.
- [Capture through a long-lived host, not a process per screenshot](../tooling-decisions/long-lived-capture-host-not-process-per-shot.md)
  — the sibling surface, and the source of the principle this failure repeats: a
  configuration that reads back correctly is evidence about the configuration,
  not about the behaviour. Its subject is funplay's *runtime bridge*; nothing in
  that loop depends on the editor or on port 8765.
- `docs/dev-tools.md` — the shared tool inventory. It distinguishes the
  editor-bound MCP server from the runtime bridge used by Native Proof.
- Auto-memory `godot-macos-capture-steals-focus` — the focus-cost reasoning that
  used to argue against opening the editor, relaxed on 2026-07-27 by the move to
  remote work. Corroborating context, not independent evidence.
