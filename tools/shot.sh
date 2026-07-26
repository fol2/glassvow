#!/bin/zsh
# Capture a screen without the window landing on your desktop.
#
# Every argument is passed straight through to the game's own --shot hook
# (application/main.gd), so anything that works there works here:
#
#   tools/shot.sh --shot=/tmp/map.png --seed=1
#   tools/shot.sh --fight=duskfang --kind=elite --shot=/tmp/fight.png
#   tools/shot.sh --hud --state=3 --shot=/tmp/hud.png
#
# Why this wrapper exists, and what it does NOT fix.
#
# A capture needs a real window: headless has no viewport texture and the run
# hangs rather than failing (docs/hud-handoff.md §8). The window is therefore
# parked far off the desktop — off-screen windows still render, verified by
# comparing captures at -4000,-4000 against on-screen ones.
#
# What no wrapper can fix from outside the engine: on macOS Godot calls
# activateIgnoringOtherApps as its window comes up, so the capture process
# takes the frontmost slot for roughly half a second before macOS hands it
# back. Measured against a frontmost-app sampler, each of these still lost the
# desktop: the NO_FOCUS window flag, the display/window/size/no_focus project
# setting, --verbose, an LSUIElement app bundle, an LSBackgroundOnly app
# bundle, and an AppleScript watcher racing to reclaim focus (which only makes
# the focus flip twice instead of once). The fix for that is to stop starting a
# process per capture — one long-lived instance, driven over a command file.
set -u

ROOT="${0:A:h:h}"
GODOT="${GODOT:-godot}"
POSITION="${GLASSVOW_SHOT_POSITION:--4000,-4000}"

exec "$GODOT" --path "$ROOT" --position "$POSITION" -- "$@"
