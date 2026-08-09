#!/usr/bin/env bash
# Fail when a `.gd` file does not parse.
#
# `godot --headless --check-only -s FILE` writes script diagnostics to stderr
# while exiting 0. Measured on 4.7.1 across every script-error class this gate
# cares about — duplicate declaration, unterminated string, type mismatch, and
# warnings-as-errors — the exit status was 0 every time while stderr carried a
# `SCRIPT ERROR: Parse Error:` and a `Failed to load script`.
# So the `for f in …; do godot --check-only -s "$f" || exit 1; done` loop this
# script replaces (`AGENTS.md` § Verification, `.github/workflows/ci.yml`) could
# never fail, and never once caught a defect. The script must therefore grade
# both signals independently: stderr for script errors, and the process status
# for invocation failures or crashes.
#
# Warnings-as-errors DOES reach `--check-only`: `project.godot` sets
# `untyped_declaration`, `inferred_declaration`, `unsafe_cast` and
# `unsafe_call_argument` to level 2, and an untyped `var x = 1` prints
# `Parse Error: Variable "x" has no static type. (Warning treated as error.)`.
# It was only ever the enforcement that was missing, not the detection.
#
# Usage:
#   tools/check_scripts.sh              # every non-addon .gd file, per git
#   tools/check_scripts.sh a.gd b.gd    # just these
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

GODOT="${GODOT:-godot}"
tmpdir=$(mktemp -d) || {
	printf 'TEMP     Unable to create a working directory.\n' >&2
	exit 1
}
list="$tmpdir/scripts"
err="$tmpdir/stderr"

cleanup() {
	rc=$?
	trap - EXIT
	if ! rm -rf -- "$tmpdir"; then
		printf 'TEMP     Unable to remove working directory %s.\n' "$tmpdir" >&2
		exit 1
	fi
	exit "$rc"
}
trap cleanup EXIT

if [ "$#" -gt 0 ]; then
	if ! printf '%s\n' "$@" >"$list"; then
		printf 'INPUT    Unable to record explicit script paths.\n' >&2
		exit 1
	fi
else
	git ls-files '*.gd' | grep -v '^addons/' >"$list"
	discovery_status=("${PIPESTATUS[@]}")
	git_rc=${discovery_status[0]}
	filter_rc=${discovery_status[1]}
	if [ "$git_rc" -ne 0 ]; then
		printf 'DISCOVERY git ls-files exited with status %d.\n' "$git_rc" >&2
		exit 1
	fi
	if [ "$filter_rc" -gt 1 ]; then
		printf 'DISCOVERY script-path filter exited with status %d.\n' "$filter_rc" >&2
		exit 1
	fi
	if [ ! -s "$list" ]; then
		printf 'DISCOVERY No tracked non-addon .gd scripts found.\n' >&2
		exit 1
	fi
fi

checked=0
failed=0

while IFS= read -r f; do
	[ -n "$f" ] || continue
	checked=$((checked + 1))
	"$GODOT" --headless --check-only -s "$f" >/dev/null 2>"$err"
	rc=$?
	file_failed=0
	if [ "$rc" -ne 0 ]; then
		printf '%s  %-7s Godot exited with status %d.\n' "$f" "PROCESS" "$rc"
		file_failed=1
	fi
	if grep -qE 'SCRIPT ERROR|Failed to load script' "$err"; then
		file_failed=1
		# One line per diagnostic: `path:line  KIND  message`, categorised so a
		# warning-as-error is not mistaken for a syntax error when triaging.
		awk -v f="$f" '
			/^SCRIPT ERROR: / { msg = substr($0, 15); next }
			msg != "" && /at: GDScript::reload/ {
				line = $0; sub(/^.*:/, "", line); sub(/\).*$/, "", line)
				kind = (msg ~ /Warning treated as error/) ? "WARNING" : "PARSE"
				printf "%s:%s  %-7s %s\n", f, line, kind, msg
				n++; msg = ""; next
			}
			/^ERROR: / { raw[++e] = $0 }
			END { if (n == 0) for (i = 1; i <= e; i++) printf "%s  %-7s %s\n", f, "LOAD", raw[i] }
		' "$err"
	fi
	if [ "$file_failed" -ne 0 ]; then
		failed=$((failed + 1))
	fi
done <"$list"

if [ "$failed" -gt 0 ]; then
	printf '\n%d of %d script check(s) failed.\n' \
		"$failed" "$checked"
	exit 1
fi

echo "scripts OK ($checked checked)"
