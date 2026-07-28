---
title: "Capture through a long-lived host, not a process per screenshot"
date: 2026-07-26
last_refreshed: 2026-07-28
category: tooling-decisions
module: tools/live
problem_type: tooling_decision
component: tooling
severity: high
applies_when:
  - "Iterating on a Godot screen by capturing screenshots from the command line on macOS"
  - "Adding any tool that launches a windowed Godot process while the user is working"
  - "Hot-reloading GDScript inside a running process rather than restarting it"
  - "Proving that a focus, timing, or interruption fix actually worked"
  - "Comparing two captures of a screen that animates, where a diff needs a noise floor first"
  - "Making a helper process long-lived, so resources a one-shot process freed on exit are now held indefinitely"
symptoms:
  - "Every `godot --path . -- --shot=...` run raises a window, takes the keyboard for roughly 0.6s, then quits — once per visual iteration"
  - "Seven measured workarounds all failed: --headless hangs with no viewport texture, while WINDOW_FLAG_NO_FOCUS, the display/window/size/no_focus setting, --verbose, an LSUIElement bundle, an LSBackgroundOnly bundle, and an AppleScript reclaim watcher each still lost the desktop"
  - "A reload reported `success: true` while the running screen kept its old code"
  - "Captures taken immediately after a rebuild come back fully black"
  - "The first focus measurement reported 40/40 clean samples because the harness waited for focus to return before it started sampling"
root_cause: missing_tooling
resolution_type: tooling_addition
related_components:
  - "development_workflow"
  - "documentation"
tags: [godot, macos, window-focus, screenshot-capture, hot-reload, gdscript-reload, developer-tooling, verification]
---

# Capture through a long-lived host, not a process per screenshot

## Context

The visual-iteration loop in this project is a screenshot hook in the game's own
entry point. `application/main.gd:56-72` (in `_ready`) documents it and
`application/main.gd:83-133` (in `_ready`) parses it out of
`OS.get_cmdline_user_args()`:

```gdscript
# Screenshot-loop hook for agent iteration without the editor MCP. A run that
# carries --shot= captures and then quits, and goes through tools/shot.sh;
# without it the run is a viewer to work in, so it launches godot directly.
# ...
# tools/shot.sh --shot=/tmp/map.png [--seed=N] [--enter=0]
```

`--shot=PATH` is read at `application/main.gd:73-74` (in `_ready`), and each
route exit — studio, card lab, the lab branch, and the real run — calls
`_capture_and_quit()` (`application/main.gd:141`, `147`, `166`, `175`, all in
`_ready`). That function is short and worth reading in full, because two of its
lines become load-bearing later:

```gdscript
func _capture_and_quit(path: String) -> void:
	for _i: int in range(30):  # let layout + first paint settle
		await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(path)
	print("shot saved: " + path)
	get_tree().quit(0)
```

(`application/main.gd:242` (`_capture_and_quit`).) It waits 30 frames for the
first paint, reads the viewport texture, and quits.

The capture must run windowed. `docs/hud-handoff.md:167-169` already states the
constraint plainly: captures "must be run **windowed** — headless has no
viewport texture and the run hangs rather than failing." `godot --help` on this
machine corroborates the mechanism: `--headless` is documented as
`--display-driver headless --audio-driver Dummy`, and the `--display-driver`
entry lists exactly one rendering driver for `headless` — `"dummy"`.

That leaves a real window, and on macOS a real window means the process takes
the frontmost slot. Per this session's measurements, each run held the desktop
for roughly 0.6 seconds before quitting. Run dozens of times a day by an agent
while the user is typing in another application, that is a constant
interruption. The user's request was precise: keep capturing, stop bringing the
window to the front.

That request turned out to be the narrow end of a standing one.
`docs/visual-direction.md:24-25` records that "Every session independently asked
for the same thing: an **interactive viewer/editor**, not a PNG dump." A host
that stays up and accepts input is the first thing in this project that answers
it; the focus fix is what made keeping one up bearable.

The root cause is outside the project's reach. Godot on macOS calls
`activateIgnoringOtherApps` as its window comes up, and nothing outside the
process declines it — engine behaviour inferred from the measurements below,
not read out of the engine source. That single sentence is what makes this a tooling problem
rather than a configuration problem, and seven attempts to treat it as
configuration are recorded below.

**Status: landed.** When this document was written the tooling was untracked and
uncommitted, and the paragraph here said so. It is no longer true —
`tools/live.gd`, its `.uid`, `tools/live.sh`, `tools/live.tscn` and
`tools/shot.sh` are all tracked, having landed on `main` the same day in
`72b25ce` (*feat(tools): the capture host outlives the edit, and the desktop is
handed back*) and `7d33899` (*fix(tools): the off-screen park never worked, and
five documents said it did*), both ancestors of the current HEAD. This work was
still deliberately confined to new files under `tools/` because six parallel
lanes share this tree — no existing game file was modified.

**And the evidence behind the numbers:** every measurement quoted here is this
session's own, taken with an ad-hoc AppleScript sampler that was not kept. The
figures are the basis for the decision, but they cannot be re-derived from this
repository — treat them as reported, not as reproducible. If a future change to
the capture path needs to disprove one of them, rebuild the sampler from the
`osascript` primitive above and sample continuously, per the trap described in
*Why This Matters*.

### What did not work

Seven attempts, each measured against an AppleScript sampler polling the
frontmost process. The sampler's primitive is the same query the shipped tool
now uses at `tools/live.sh:42` (in `hand_back`):

```sh
osascript -e 'tell application "System Events" to name of first process whose frontmost is true'
```

1. **`--headless`.** No viewport texture; the run hangs rather than erroring.
   Already recorded at `docs/hud-handoff.md:167-169`; the attempt re-confirmed
   it.
2. **`DisplayServer.window_set_flag(WINDOW_FLAG_NO_FOCUS, true)` from
   `_ready()`.** The window exists and has already activated before any GDScript
   runs. Measured: still 2 of 3 samples on `godot`.
3. **`display/window/size/no_focus` as a project setting, injected via
   `override.cfg`.** A probe script confirmed the setting existed and read back
   `value=true`. The application still took the desktop.
4. **`--verbose`,** on the theory that the engine skips activation in verbose
   runs. No effect; if anything worse, because the run takes longer.
5. **An `LSUIElement` app bundle.** `cp -cR` (APFS clone) of
   `/Applications/Godot.app`, `PlistBuddy -c "Add :LSUIElement bool true"`,
   ad-hoc `codesign --force --deep --sign -`. The clone ran and reported
   `4.7.1.stable.official`, and it still activated. An accessory application can
   still be activated by `activateIgnoringOtherApps`.
6. **The same bundle trick with `LSBackgroundOnly`.** The measured timeline
   showed samples 04-06 on `Godot`, then focus returning. Still activated.
7. **An AppleScript watcher racing to reclaim focus.** It does reclaim — and
   Godot activates again. The measured timeline went
   `Claude → godot → Claude → godot`. Focus flips twice instead of once, which
   is strictly worse than doing nothing.

That list is not archaeology; it is recorded in prose in the header comment of
`tools/shot.sh:16-35` — the names, not the per-item measurements — so the next
person who reaches for the NO_FOCUS flag reads it before spending the
afternoon.

### The one positive finding, which turned out to be vacuous

This section used to record a finding: *a window parked at
`--position -4000,-4000` still renders a complete, correct frame*, verified by
comparing off-screen captures against on-screen ones and finding them
equivalent. It was offered as the result that made an invisible host viable.

It was not a finding. On 2026-07-26 the window bounds were read out of
`CGWindowListCopyWindowInfo` while a capture ran, and macOS had been clamping
the request the whole time: asking for `1400,900` put the window at roughly
`1412,844`, tracking the request, while asking for `-4000,-4000` put it at
roughly `422,234` — on the desktop. A window is constrained to stay on screen,
so the "off-screen" captures in that comparison had never been off-screen. What
was proved is that an on-screen capture matches an on-screen capture.

The failure mode is the same one that produced the false all-clear recorded
below, in a quieter form: an experiment was run against a state that the
experiment never established. "Does an off-screen window render correctly?" is
only answerable once something confirms the window went off-screen, and nothing
did. Verify the precondition, not just the outcome.

`-4000,-4000` remains the default in both tools (`tools/shot.sh:49`,
`tools/live.sh:24`, both overridable via `GLASSVOW_SHOT_POSITION`) because it
costs nothing and a platform that honoured it would be strictly better. Nothing
downstream may assume that it works.

**The conclusion survives this, and the reason is worth stating plainly.** The
host's value was never that its window is invisible — it is that the window is
created *once*. The focus grab is a boot cost, and a host boots once a session.
Every measurement below about per-capture cost still holds; the only claim that
does not is that you never see the window.

## Guidance

**Stop launching a process per capture. Run one long-lived host, drive it over
files, and reload its code in place.**

Four files implement this, and none of them touches the game.

### `tools/shot.sh` — the one-off, for when a host is overkill

Forty-odd lines of comment and five lines of code. It requests an off-screen
position — which macOS declines, see above — and passes every argument straight
through to `main.gd`'s `--shot` hook (`tools/shot.sh:51`):

```sh
exec "$GODOT" --path "$ROOT" --position "$POSITION" -- "$@"
```

It does not fix the focus grab and says so at `tools/shot.sh:20-26`. It exists
so a single ad-hoc capture does not require booting a host, and so the failed
attempts have a home.

### `tools/live.gd` + `tools/live.tscn` — the host

`tools/live.tscn` is six lines: a bare `Node` named `LiveHost` with
`tools/live.gd` attached. The script instantiates the *real* game scene
unchanged — `const GAME_SCENE_PATH: String = "res://application/main.tscn"`
(`tools/live.gd:24`) — and adds funplay's runtime bridge beside it
(`tools/live.gd:25`, instantiated at `tools/live.gd:43-46`):

```gdscript
func _ready() -> void:
	var bridge: Node = Node.new()
	bridge.name = "FunplayRuntimeBridge"
	bridge.set_script(load(BRIDGE_SCRIPT_PATH))
	add_child(bridge)
	_build_game()
	_announce_ready()
```

The bridge already speaks the commands the loop needs — its dispatch at
`addons/funplay_mcp/runtime/funplay_mcp_runtime_bridge.gd:136-143` matches
`query_node`, `capture_view`, `send_input`, and `get_events` — over `user://`
command and response files declared at that file's lines 3-6. The host adds one
command of its own, `reload`, on a *separate* channel
(`tools/live.gd:26-28`), for the reason given at `tools/live.sh:104-105`: a
reload re-parses the scripts the bridge would otherwise be answering from.

### `tools/live.sh` — the client

`start` / `shot` / `reload` / `key` / `action` / `click` / `drag` / `query` /
`events` / `status` / `stop`, dispatched at `tools/live.sh:74-140`. Launch is
one line (`tools/live.sh:84-85`):

```sh
"$GODOT" --path "$ROOT" --position "$POSITION" res://tools/live.tscn -- "$@" \
  > "$LOG" 2>&1 &
```

Everything after that boot is a file write and a poll. `send()`
(`tools/live.sh:57` (`send`)) mints a fresh id per call, clears the response file,
writes the command, and polls for up to 200 × 0.05s. `shot` asks the bridge to
save under `user://shots/` and copies the result out
(`tools/live.sh:95-102`). `reload` uses the host's own channel and polls for up
to 400 × 0.05s (`tools/live.sh:104-120`).

**Do not pass `--shot` to the host.** That hook captures once and quits
(`application/main.gd:242` (`_capture_and_quit`)), which is the exact behaviour the host exists to
avoid. `tools/live.gd:22` and `tools/live.sh:14` both say so.

### Hot reload is the load-bearing part

A host that must be rebooted after every code edit reproduces the original
interruption, so it would be pointless. Four engine gotchas stand between "a
long-lived process" and "a long-lived process that is still useful after you
edit a file", and each was found by measurement.

**1. Free the scene before touching any script.** GDScript refuses to reload a
script while any instance of it is alive — the error is
`Cannot reload script while instances exist`, reported in this session as
originating at `modules/gdscript/gdscript.cpp:754` — a path in *Godot's own
source*, not in this repository, and a line number taken from the error output
rather than verified against a checkout of the engine. And `queue_free()` is deferred to the end of
the frame, so it does not clear the instances in time. The scene must be
`free()`d outright, first. `_teardown_game()` is called at `tools/live.gd:97`,
before the script loop, and it does not defer (`tools/live.gd:162-167`):

```gdscript
func _teardown_game() -> void:
	if _game == null:
		return
	remove_child(_game)
	_game.free()
	_game = null
```

**2. `Script.reload()` does not re-read disk.** It recompiles the source the
script object is already holding. Without assigning `script.source_code` from
the file first, it is a **silent no-op that still returns `OK`**. This produced
a thoroughly convincing false positive: the reload reported `success: true` with
`failed_scripts: []` while the running screen still showed the old code. It was
caught only because a deliberately planted, visually checkable change — a gold
counter set to `12345` — failed to appear on screen. The fix is the assignment
at `tools/live.gd:116`, inside the pass loop:

```gdscript
script.source_code = FileAccess.get_file_as_string(path)
if script.reload(false) != OK:
	failed.append(path)
```

Two passes are run (`RELOAD_PASSES: int = 2`, `tools/live.gd:36`) because a
dependency compiled after its dependent leaves the dependent holding the older
copy; the second pass settles it (`tools/live.gd:33-35`).

**3. A rebuilt screen re-takes the desktop.** The new screen calls
`grab_focus()`, which makes the window key again and drags the macOS desktop
with it — measured at 8 of 30 samples on `godot` during a reload. The fix is to
toggle `WINDOW_FLAG_NO_FOCUS` on **for the rebuild only**: set at
`tools/live.gd:92`, cleared at `tools/live.gd:129` (and on the early-return
failure path at `tools/live.gd:120`). Leaving it on permanently is a trap that
was itself measured, and the comment at `tools/live.gd:88-91` records the
result: with the flag always set, focus never returns to the user at all,
because a window that can never be key is never the one the system hands focus
to next.

**4. The first frame after a rebuild is black.** A viewport texture read before
the rebuilt screen has painted comes back black; several early captures were
fully black PNGs. The host waits 30 frames before announcing ready or replying
to a reload — `SETTLE_FRAMES: int = 30` at `tools/live.gd:32`, deliberately
matching `main.gd`'s own hook at `application/main.gd:243-244` (in `_capture_and_quit`). `_settle()` is
awaited from both `_announce_ready()` (`tools/live.gd:151`) and the reload's
success path (`tools/live.gd:128`), so **a successful reply doubles as "safe to
capture now"** (`tools/live.gd:127`).

**4b. Thirty frames means "not black". It does not mean "settled".** Half a
second is enough for a first paint and is not enough for a fight: a combat
screen's opening hand is still in the air, so the capture records the entrance
at whatever position the wall clock had reached. Measured on the stage-shape
work — two runs of the **same build**, same seed, same arguments, differed
across **2.4%** of the frame, all of it in the hand. That is a noise floor high
enough to swallow most layout changes, and it made the first before/after
comparisons of that work unreadable. Adding a wall-clock wait
(`--settle=SECONDS`, `application/main.gd:245-246` (in `_capture_and_quit`))
drops the same comparison to **0.030%**.

The rule that follows applies to any capture of an animated screen: **establish
the noise floor before trusting a diff.** Capture the same build twice and
measure the difference between those two; only a change larger than that number
is evidence of anything. A diff taken without that baseline cannot distinguish a
moved widget from a drifting ember.

### The fifth finding, and the one the user actually felt

A one-shot process quits, which prompts macOS to hand the desktop back. A host
never quits, so it holds the desktop indefinitely — measured holding focus from
boot at 2.03s all the way to 10.95s, which is far worse than the 0.6s the host
was built to eliminate.

The fix is in the client, not the engine. `tools/live.sh:81` records the
previously-frontmost application before launching, and `hand_back()`
(`tools/live.sh:39` (`hand_back`)) reactivates it once the host writes its ready
file (called at `tools/live.sh:88`):

```sh
hand_back() {
  [[ -n "${owner:-}" && "$owner" != *odot* ]] || return 0
  local now
  now="$(osascript -e 'tell application "System Events" to name of first process whose frontmost is true' 2>/dev/null)"
  [[ "$now" == *odot* ]] || return 0
  osascript -e "tell application \"System Events\" to set frontmost of process \"$owner\" to true" 2>/dev/null
}
```

The second check matters: it only hands back if Godot is *still* the frontmost
process, so a deliberate application switch mid-boot is left alone. (The
`*odot*` substring test matches both `godot` and `Godot`, which is why the
cloned-bundle experiments in the failed-attempts list appear under both names.)

Measured after the fix: focus goes to `godot` at 2.03s and returns at 5.08s,
with no further transitions across a subsequent `reload` and captures.

### Known limits, measured rather than assumed

- **A `class_name` that did not exist at boot cannot be compiled by a reload.**
  The global class registry is built once at startup. Tested directly: a
  throwaway `domain/hot_probe.gd` declaring `class_name HotProbe`, referenced
  from `main.gd`, made `main.gd` fail to re-parse. (Both the probe and the
  reference were reverted as soon as the result was in — neither exists in the
  tree, so the citation is historical.) Worse, the host originally still
  reported `success: true` — a silent failure that would have let someone
  capture stale code believing it fresh. `tools/live.gd:136-142` now reports the
  refusal:

  ```gdscript
  if not failed.is_empty():
  	return {
  		"success": false,
  		"error": "%d script(s) kept their old code — restart the host if you added or renamed a class_name." % failed.size(),
  		"scripts": paths.size(),
  		"failed_scripts": failed,
  	}
  ```

  The comment above it (`tools/live.gd:132-135`) states the principle:
  "Reporting the refusal is the difference between a reload and a lie."

- **The host's own code and the bridge are never reloaded.**
  `_collect_scripts()` skips `res://addons` and `res://tools` outright
  (`tools/live.gd:190`), because reloading either would pull the command channel
  out from under the reply that is being written.

- **Run state is discarded by design.** A reload re-parses scripts and rebuilds
  the scene from disk, so whatever run was in progress is gone
  (`tools/live.gd:18-19`). That is what makes a capture reproducible rather than
  path-dependent.

- **Editing the host or the autoload set still needs a restart**
  (`tools/live.gd:20-22`).

- **Errors are reported, not raised.** A half-typed edit should leave the host
  answering commands rather than take it down (`tools/live.gd:84-85`), which is
  why the failure paths return dictionaries instead of pushing errors and
  quitting.

- **Thirty frames is a frame count, not a duration — and a fight's actors have
  not arrived yet.** Both settle loops count frames: `_capture_and_quit` at
  `application/main.gd:243-244` (in `_capture_and_quit`) and `SETTLE_FRAMES` at
  `tools/live.gd:32`,
  `158`. Thirty frames is half a second at 60fps. A combat entrance is longer
  than that: each actor tweens for `ENTER_TIME` 0.55s after a stagger of
  `ENTER_LEAD` 0.16s plus `ENTER_STEP` 0.13s per index
  (`presentation/combat/enemy_view.gd:283`, `288-289`), so the third foe is
  still travelling at 1.27s. A one-off `tools/shot.sh --fight=...` therefore
  photographs an empty floor with healthy-looking chrome, and so does a
  `live.sh shot` taken straight after a `reload` that rebuilt the scene. The
  host itself is immune once it has been up a while — the entrance is long over
  — which is a second reason to keep one running rather than boot per capture.
  Nothing here is wrong with the settle loop; it settles layout and first paint,
  which is what it was written for. It was never a wait for choreography.

- **The host does not outlive the process group that launched it.** Measured
  2026-07-27: a `tools/live.sh start` issued from a foreground shell reported
  `host ready (pid 49755)` and served one `shot`, and the next invocation
  answered `no host running`. The host's log ended with only the funplay
  bridge's `_exit_tree` serialisation noise — no game error, no crash. Launching
  the same command with the invocation backgrounded produced a host that
  answered `status` across later, separate calls. So the daemon inherits its
  launcher's process group and dies when that group is torn down. Any caller
  that ends its shell between commands — an agent harness running one command
  per tool call is the case that found this — must background the `start`, or it
  pays the boot and the focus grab it was trying to avoid on every single
  capture, which is precisely the cost this whole decision exists to remove.

## Why This Matters

Two lessons here transfer well beyond Godot and beyond macOS. Both are about
verification, and both produced a confident, wrong answer before they were
caught.

### A measurement harness that waits for the healthy state cannot observe the unhealthy one

The first focus measurement in this session used a harness that *waited for
focus to return before it began sampling*. It reported 40 out of 40 samples
clean — a total all-clear — while the host was in fact holding the desktop from
2.03s to 10.95s. The harness was structurally incapable of seeing the bug it was
built to detect, because the condition it waited on was the absence of the bug.

The bug was exposed only by continuous timestamped sampling that started
*before* the process booted and ran to the end of the interaction. That is the
general rule: **a harness that synchronises on the healthy state has defined the
unhealthy state out of its own observation window.** Any "wait for ready, then
measure" pattern is suspect whenever the thing being measured is a transient —
focus, a lock, a spinner, a stale cache, a first-paint artefact. Sample across
the whole window, timestamp every sample, and read the timeline rather than the
pass rate.

The same error has a further level, found on 2026-07-27: a harness can be missing
not just the *window* in which a defect appears but any *mode* in which a whole
category of behaviour could appear at all. Five enemy-lab strip modes all
photographed one-shot beats; none sampled a loop, so an entire per-kind idle layer
was absent from the port and nothing in the project could have raised it. A
harness that synchronises on the healthy state hides an instance; a harness with
no mode for a shape hides a class. See
[Drive the lab the way the game drives it](./drive-the-lab-the-way-the-game-drives-it.md).

This also explains why the seven failed attempts are worth their space in
`tools/shot.sh:28-35`. Each one *looked* plausible, and several of them
(`no_focus` reading back `value=true`; the `LSUIElement` clone reporting
`4.7.1.stable.official`) produced a satisfying intermediate confirmation that
had nothing to do with the outcome. A configuration that reads back correctly is
evidence about the configuration, not about the behaviour.

### An API that returns OK without doing the work will be trusted until something visual contradicts it

`Script.reload()` recompiles the source the object already holds. Call it after
editing a file on disk and it succeeds, returns `OK`, changes nothing, and the
caller reports success. The reload path had `failed_scripts: []` and
`success: true` while the screen showed old code. Nothing in the return value
was wrong; the return value was simply answering a different question than the
one being asked.

The only thing that caught it was a **planted, visually checkable change** — a
gold counter set to `12345` that either appears in the HUD or does not. That is
the technique worth keeping: when verifying a mechanism whose success signal is
self-reported, plant a change whose presence is observable through a completely
different channel from the one reporting success. A boolean returned by the
system under test is not evidence that the system under test did anything.

The same failure mode recurred one level up, which is the strongest argument for
the technique. The `class_name` limit was originally a silent
`success: true` too. Both were fixed the same way: make the reply tell the
truth, including when the truth is "I did nothing" (`tools/live.gd:136-142`).

### Process-per-operation is a cost that compounds invisibly

The 0.6-second focus grab was individually trivial and collectively intolerable,
because the loop runs dozens of times a day. Seven attempts were spent trying to
make each individual boot cheaper before the framing changed to *stop booting*.
When a per-operation cost cannot be removed, the question to reach for sooner is
whether the operation needs its own process at all. The residual cost of the
final design is one boot per session, which was then measured and handed back
(2.03s → 5.08s) rather than assumed to be acceptable.

## When to Apply

- **Any command-line Godot capture on macOS while the user is at the keyboard.**
  Use `tools/live.sh` for a loop; use `tools/shot.sh` for a single ad-hoc shot
  where booting a host is not worth it.
- **Before reaching for `WINDOW_FLAG_NO_FOCUS`, `display/window/size/no_focus`,
  `LSUIElement`, `LSBackgroundOnly`, or a focus-reclaiming watcher.** All five
  were measured and all five failed; read `tools/shot.sh:28-35` first.
- **Before adding `--headless` to anything that captures a viewport.** Headless
  has no viewport texture and the run hangs rather than failing
  (`docs/hud-handoff.md:167-169`), and `godot --help` confirms the headless
  display driver offers only the `dummy` rendering driver.
- **Whenever hot-reloading GDScript in a running process:** free instances
  before touching scripts, assign `source_code` from disk before calling
  `reload()`, suppress key status for the length of a rebuild only, and wait for
  the paint before reading the viewport.
- **After adding or renaming a `class_name`, or editing an autoload,
  `tools/live.gd`, or the funplay runtime bridge** — `stop` and `start`. The host will
  now tell you, but restarting is the fix either way.
- **Whenever measuring a transient** — focus, locks, first paint, cache
  staleness. Sample continuously from before the event; never synchronise the
  harness on the condition you are trying to falsify.
- **Whenever a mechanism reports its own success.** Plant an independently
  observable change and check for it through a different channel.

## Examples

### Boot once, capture many

```bash
tools/live.sh start --fight=duskfang --kind=elite   # the one boot; hands focus back
tools/live.sh shot /tmp/a.png                       # no new window, no focus grab
tools/live.sh key space
tools/live.sh click 590 700
tools/live.sh shot /tmp/b.png
tools/live.sh stop
```

The usage block at `tools/live.sh:2-17` is the same list, and the bare
invocation prints it (`tools/live.sh:136-138`) — note the printer stops at 17,
so the `class_name` caveat on line 18 is in the file but not in the printed
help.

### Edit code, then reload — no restart, no focus grab

```bash
# ... edit application/main.gd ...
tools/live.sh reload
tools/live.sh shot /tmp/after.png
```

Proven end-to-end in this session by editing the encounter label string in
`main.gd` and calling `reload`: the combat screen's top bar then read
`HOT-RELOADED · NORMAL · Turn 1`, with no process restart. An earlier proof used
a planted `game.run.player.gold = 12345`, which appeared in the HUD after
reload.

### The correct reload order

Wrong — `queue_free()` defers to end of frame, so the instances are still alive
when the script loop runs, and GDScript refuses with
`Cannot reload script while instances exist`:

```gdscript
_game.queue_free()
for path: String in paths:
	(ResourceLoader.load(path, "GDScript") as GDScript).reload(false)
```

Wrong in a quieter way — instances are gone, but `reload()` recompiles the
source already in memory. This returns `OK` for every script and changes
nothing:

```gdscript
_teardown_game()
for path: String in paths:
	var script := ResourceLoader.load(path, "GDScript", ResourceLoader.CACHE_MODE_REPLACE) as GDScript
	script.reload(false)          # <- silent no-op; source_code never re-read
```

Right — free outright first, re-read from disk, then recompile, twice
(`tools/live.gd:97-118`):

```gdscript
_teardown_game()
for pass_index: int in RELOAD_PASSES:
	failed = PackedStringArray()
	for path: String in paths:
		var resource: Resource = ResourceLoader.load(
			path, "GDScript", ResourceLoader.CACHE_MODE_REPLACE)
		...
		script.source_code = FileAccess.get_file_as_string(path)
		if script.reload(false) != OK:
			failed.append(path)
```

### Suppressing the rebuild's focus grab, and only the rebuild's

```gdscript
DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
_teardown_game()
# ... reload scripts, rebuild scene ...
await _settle()
DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, false)
```

(`tools/live.gd:92`, `97`, `128-129`.) Leaving the flag on permanently was
measured: focus never returns to the user at all.

### A measurement harness that can see the bug

Wrong — this reported 40/40 samples clean while the host held the desktop from
2.03s to 10.95s, because it did not start sampling until the bug was over:

```sh
# wait for focus to come back, THEN start sampling  <- defines the bug out of the window
until [[ "$(frontmost)" != *odot* ]]; do sleep 0.1; done
for i in {1..40}; do frontmost; sleep 0.1; done
```

Right — start before the boot, timestamp every sample, read the timeline:

```sh
start=$(date +%s.%N)
( while :; do printf '%s %s\n' "$(echo "$(date +%s.%N) - $start" | bc)" \
    "$(osascript -e 'tell application "System Events" to name of first process whose frontmost is true')"
  sleep 0.1; done ) &
tools/live.sh start --fight=duskfang
```

The measured timeline after the hand-back fix was
`0.00 Claude → 2.03 godot → 5.08 Claude`, with no further transitions across a
subsequent `reload` and captures.

### Recognising the two failure signatures

- **Black capture.** A combat-screen PNG is around 1.18 MB with full content. A
  capture taken before the rebuilt screen painted came out around 29 KB of solid
  black. If a capture is two orders of magnitude too small, it is a settle
  problem, not a rendering problem.
- **A reload that lied.** `success: true` with `failed_scripts: []` while the
  screen still shows old code is the `source_code` no-op. `success: false` with
  a populated `failed_scripts` and the message
  `"N script(s) kept their old code — restart the host if you added or renamed a class_name."`
  is the host doing its job — `stop` and `start`.

## Related

- `tools/live.gd` — the host: bridge wiring (`:43-46`), command loop
  (`:51-65`), reload (`:86-147`), settle (`:157-160`), script collection with
  the `addons`/`tools` skip (`:186-201`). Tracked; landed in `72b25ce`.
- `tools/live.sh` — the client: focus hand-back (`:38-44`), request/reply
  (`:56-71`), boot (`:74-92`), reload channel (`:103-119`). Tracked.
- `tools/shot.sh` — the one-off wrapper, and the record of all seven failed
  focus attempts (`:11-26`). Tracked.
- `tools/live.tscn` — six lines; a `Node` named `LiveHost` with `live.gd`
  attached. Tracked.
- `application/main.gd:56-72` (in `_ready`), `:219` (`_capture_and_quit`) — the `--shot`
  hook the host deliberately does not use, and the 30-frame settle the host
  copies. (The range here read `:138-144` until a refresh caught it: that stops
  at the function's own declaration and excludes the settle loop it claims to
  cite. It survived because an anchor carrying no `(symbol)` annotation is not
  validated in the checker's default mode — `tools/check_anchors.py:52-57`.)
- `addons/funplay_mcp/runtime/funplay_mcp_runtime_bridge.gd:3-6`, `:136-143` —
  the `user://` file paths and the `query_node` / `capture_view` / `send_input`
  / `get_events` dispatch the host reuses unchanged.
- `docs/hud-handoff.md:157-173` — §8, the pre-existing record that captures must
  be windowed because headless has no viewport texture and hangs.
- `docs/solutions/ui-bugs/godot-label-placement-guessed-font-height.md:167-178` —
  the empirical backing for workaround #1, measured independently and earlier:
  a headless capture exits 124 after a 60s timeout and never writes the PNG.
  Cited rather than re-argued. The same rule appears again at
  `docs/solutions/conventions/per-recipe-shader-knobs.md:210` and in the `Lab`
  entry of `CONCEPTS.md` — it is settled project knowledge, not a new finding.
- `CONCEPTS.md`, `Live host` entry — the glossary definition this doc
  introduces, with the reload/restart rules stated for a reader who has not read
  this doc.
- `CONCEPTS.md`, `Lab` entry — the vocabulary this host drives: the
  contact-sheet/bench split, and the standing constraint that a Lab needs a real
  viewport to photograph. (Which of the two shapes wants a `reload` versus a
  fresh `start` is this doc's inference, not something the `Lab` entry says.)
- `docs/visual-direction.md:22-25` — the standing cross-session request for an
  interactive viewer rather than a PNG dump, which this closes.
- `docs/solutions/conventions/per-recipe-shader-knobs.md` — the same discipline
  in the presentation layer: measure the blast radius rather than reason about
  it, and prove the untouched case did not move.
- Auto-memory `godot-macos-capture-steals-focus` — written during this same
  session; corroborating, not independent evidence.
- `docs/session-ownership.md` — why this work was confined to new files under
  `tools/`: six lanes share this tree.
