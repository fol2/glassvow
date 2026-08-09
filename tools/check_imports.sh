#!/usr/bin/env bash
# Import every asset once and fail on either Godot's status or stderr errors.
#
# Godot 4.7.1 can report a failed resource import as `ERROR:` on stderr while
# exiting 0. Capturing both signals here keeps the local and CI gate identical.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

GODOT="${GODOT:-godot}"
out=$(mktemp)
err=$(mktemp)
trap 'rm -f "$out" "$err"' EXIT

"$GODOT" --headless --import >"$out" 2>"$err"
godot_rc=$?

cat "$out"
cat "$err" >&2

diagnostic_rc=0
checker_rc=0
grep -qE '^(SCRIPT )?ERROR:' "$err"
grep_rc=$?
case "$grep_rc" in
	0) diagnostic_rc=1 ;;
	1) ;;
	*) checker_rc="$grep_rc" ;;
esac

if [ "$godot_rc" -ne 0 ] || [ "$diagnostic_rc" -ne 0 ] || [ "$checker_rc" -ne 0 ]; then
	printf 'asset import failed (godot rc=%d, stderr errors=%d, checker rc=%d)\n' \
		"$godot_rc" "$diagnostic_rc" "$checker_rc" >&2
	exit 1
fi

echo "asset import OK"
