#!/bin/zsh
# Capture a screen. The entry point for every --shot= run in this repo.
#
# Every argument is passed straight through to the game's own --shot hook
# (application/main.gd), so anything that works there works here:
#
#   tools/shot.sh --shot=/tmp/map.png --seed=1
#   tools/shot.sh --fight=duskfang --kind=elite --shot=/tmp/fight.png
#   tools/shot.sh --hud --state=3 --shot=/tmp/hud.png
#
# NEVER add --headless. A capture needs a real window: headless has no viewport
# texture, so save_png is handed a null image and the run HANGS rather than
# failing — exit code 124 on a full 60s timeout, PNG never written
# (docs/hud-handoff.md §8).
#
# WHAT THIS WRAPPER DOES NOT FIX — including one thing this header used to
# claim it did.
#
# The window is requested at -4000,-4000 to keep it off the desktop. macOS
# declines. A window is constrained to stay on screen, so the request is
# clamped and the capture lands in front of you anyway. Measured 2026-07-26 by
# reading window bounds out of CGWindowListCopyWindowInfo while a capture ran:
# asking for 1400,900 put the window at roughly 1412,844 — the request tracked
# — while asking for -4000,-4000 put it at roughly 422,234, back on the
# desktop. The claim that used to stand here rested on having verified that an
# off-screen window still RENDERS, which was never the question being asked.
#
# Nor can any wrapper stop the focus grab from outside the engine: on macOS
# Godot calls activateIgnoringOtherApps as its window comes up, so the capture
# takes the frontmost slot for roughly half a second before macOS hands it
# back. Measured against a frontmost-app sampler, each of these still lost the
# desktop: the NO_FOCUS window flag, the display/window/size/no_focus project
# setting, --verbose, an LSUIElement app bundle, an LSBackgroundOnly app
# bundle, and an AppleScript watcher racing to reclaim focus (which only makes
# the focus flip twice instead of once).
#
# So a one-off capture costs you the desktop for about a second, every time.
# The fix is to stop starting a process per capture: tools/live.sh boots ONE
# instance and hot-reloads it, so only the first capture of a session
# interrupts you. Reach for this wrapper for a single shot; reach for live.sh
# for a loop.
#
# GLASSVOW_SHOT_POSITION overrides the request. An on-screen value is honoured
# exactly, which is the only way to put the window somewhere deliberate.
set -u

ROOT="${0:A:h:h}"
GODOT="${GODOT:-godot}"
POSITION="${GLASSVOW_SHOT_POSITION:--4000,-4000}"

exec "$GODOT" --path "$ROOT" --position "$POSITION" -- "$@"
