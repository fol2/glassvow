#!/bin/zsh
# Drive a long-lived capture host, so repeated shots cost no window activation.
#
#   tools/live.sh start --fight=duskfang --kind=elite   # boots once, off-screen
#   tools/live.sh shot /tmp/a.png                       # no window, no focus grab
#   tools/live.sh reload                                 # re-parse code, rebuild
#   tools/live.sh key space                             # drive the screen
#   tools/live.sh action ui_accept
#   tools/live.sh click 590 700
#   tools/live.sh status
#   tools/live.sh stop
#
# `start` takes the same game arguments as tools/shot.sh — minus --shot, which
# captures once and quits. Everything after it is served over funplay's runtime
# bridge (user:// command files), so only the boot ever touches your desktop.
# `reload` re-parses every project script and rebuilds the scene inside the
# running process, so an edit costs no boot and no focus grab either. Adding or
# renaming a class_name still needs stop+start: that registry is built at boot.
set -u

ROOT="${0:A:h:h}"
GODOT="${GODOT:-godot}"
POSITION="${GLASSVOW_SHOT_POSITION:--4000,-4000}"
USERDATA="$HOME/Library/Application Support/Godot/app_userdata/Glassvow"
CMD="$USERDATA/funplay_mcp_runtime_command.json"
RESP="$USERDATA/funplay_mcp_runtime_response.json"
STATE="$USERDATA/funplay_mcp_runtime_bridge.json"
PIDFILE="$USERDATA/glassvow_live.pid"
LOG="$USERDATA/glassvow_live.log"
RELOAD_REQUEST="$USERDATA/glassvow_live_request.json"
RELOAD_RESULT="$USERDATA/glassvow_live_result.json"
READY="$USERDATA/glassvow_live_ready"

die() { print -u2 "live: $1"; exit 1; }

# Give the desktop back to whoever had it before the boot — but only if the
# host is the one holding it, so a deliberate switch mid-boot is left alone.
hand_back() {
  [[ -n "${owner:-}" && "$owner" != *odot* ]] || return 0
  local now
  now="$(osascript -e 'tell application "System Events" to name of first process whose frontmost is true' 2>/dev/null)"
  [[ "$now" == *odot* ]] || return 0
  osascript -e "tell application \"System Events\" to set frontmost of process \"$owner\" to true" 2>/dev/null
}

host_pid() {
  [[ -f "$PIDFILE" ]] || return 1
  local pid; pid="$(cat "$PIDFILE")"
  kill -0 "$pid" 2>/dev/null || return 1
  print "$pid"
}

# One request, one reply. The bridge dedupes on id and overwrites the response
# file, so a fresh id per call is what keeps replies from being mistaken for
# each other.
send() {
  local name="$1" args="$2" id i
  host_pid >/dev/null || die "no host running — tools/live.sh start [game args]"
  id="c$(date +%s)$RANDOM"
  rm -f "$RESP"
  printf '{"id":"%s","command":"%s","arguments":%s}\n' "$id" "$name" "$args" > "$CMD"
  for i in {1..200}; do
    if [[ -f "$RESP" ]] && grep -q "$id" "$RESP"; then
      cat "$RESP"
      grep -q '"success": true' "$RESP" || return 1
      return 0
    fi
    /bin/sleep 0.05
  done
  die "timed out waiting for '$name' (see $LOG)"
}

case "${1-}" in
  start)
    shift
    host_pid >/dev/null && die "already running (pid $(host_pid)) — stop it first"
    # Remember who owns the desktop. The boot activation cannot be declined,
    # and unlike a one-shot process the host never quits, so macOS is never
    # prompted to hand focus back on its own — it has to be handed back.
    owner="$(osascript -e 'tell application "System Events" to name of first process whose frontmost is true' 2>/dev/null)"
    mkdir -p "$USERDATA"
    rm -f "$STATE" "$RESP" "$CMD" "$RELOAD_REQUEST" "$RELOAD_RESULT" "$READY"
    "$GODOT" --path "$ROOT" --position "$POSITION" res://tools/live.tscn -- "$@" \
      > "$LOG" 2>&1 &
    print $! > "$PIDFILE"
    for i in {1..160}; do
      [[ -f "$READY" ]] && { hand_back; print "live: host ready (pid $(cat "$PIDFILE"))"; exit 0; }
      kill -0 "$(cat "$PIDFILE")" 2>/dev/null || { tail -5 "$LOG"; die "host exited during boot"; }
      /bin/sleep 0.25
    done
    die "host booted but never finished its first paint (see $LOG)"
    ;;

  shot)
    out="${2-}"
    [[ -n "$out" ]] || die "usage: tools/live.sh shot <out.png>"
    rel="shots/$(basename "$out")"
    send capture_view "{\"save_path\":\"user://$rel\"}" > /dev/null || die "capture failed (see $LOG)"
    cp "$USERDATA/$rel" "$out" || die "capture saved but could not be copied to $out"
    print "$out"
    ;;

  reload)
    # The host's own channel, not the bridge's: a reload re-parses the scripts
    # the bridge would otherwise be answering from.
    host_pid >/dev/null || die "no host running — tools/live.sh start [game args]"
    id="r$(date +%s)$RANDOM"
    rm -f "$RELOAD_RESULT"
    printf '{"id":"%s","command":"reload"}\n' "$id" > "$RELOAD_REQUEST"
    for i in {1..400}; do
      if [[ -f "$RELOAD_RESULT" ]] && grep -q "$id" "$RELOAD_RESULT"; then
        cat "$RELOAD_RESULT"
        grep -q '"success": true' "$RELOAD_RESULT" || die "reload failed (see $LOG)"
        exit 0
      fi
      /bin/sleep 0.05
    done
    die "timed out waiting for reload (see $LOG)"
    ;;

  key)     send send_input "{\"type\":\"key\",\"key\":\"${2-}\"}" > /dev/null && print "key ${2-}" ;;
  action)  send send_input "{\"type\":\"action\",\"action\":\"${2-}\"}" > /dev/null && print "action ${2-}" ;;
  click)   send send_input "{\"type\":\"mouse_button\",\"button\":\"left\",\"position\":{\"x\":${2-0},\"y\":${3-0}}}" > /dev/null && print "click ${2-0},${3-0}" ;;
  query)   send query_node "{\"node_path\":\"${2-current_scene}\"}" ;;
  events)  send get_events "{}" ;;
  status)
    if pid="$(host_pid)"; then print "running (pid $pid)"; [[ -f "$STATE" ]] && cat "$STATE"
    else print "not running"; fi
    ;;
  stop)
    pid="$(host_pid)" || die "not running"
    kill "$pid" && rm -f "$PIDFILE" && print "stopped $pid"
    ;;
  *)
    sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac
