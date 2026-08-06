#!/usr/bin/env bash
# Fail when a `.gd` file does not parse.
#
# `godot --headless --check-only -s FILE` writes its diagnostics to stderr and
# **exits 0 regardless of what it found**. Measured on 4.7.1 across every class
# this gate cares about — duplicate declaration, unterminated string, type
# mismatch, and warnings-as-errors — the exit status was 0 every time while
# stderr carried a `SCRIPT ERROR: Parse Error:` and a `Failed to load script`.
# So the `for f in …; do godot --check-only -s "$f" || exit 1; done` loop this
# script replaces (`AGENTS.md` § Verification, `.github/workflows/ci.yml`) could
# never fail, and never once caught a defect. The exit code carries no signal;
# the stderr text is the only signal there is, so that is what is graded here.
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
list=$(mktemp)
err=$(mktemp)
trap 'rm -f "$list" "$err"' EXIT

if [ "$#" -gt 0 ]; then
	printf '%s\n' "$@" >"$list"
else
	git ls-files '*.gd' | grep -v '^addons/' >"$list"
fi

checked=0
failed=0

while IFS= read -r f; do
	[ -n "$f" ] || continue
	checked=$((checked + 1))
	"$GODOT" --headless --check-only -s "$f" >/dev/null 2>"$err"
	# Deliberately NOT `if [ $? -ne 0 ]` — see the header. It is always 0.
	if grep -qE 'SCRIPT ERROR|Failed to load script' "$err"; then
		failed=$((failed + 1))
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
done <"$list"

if [ "$failed" -gt 0 ]; then
	printf '\n%d of %d script(s) failed to parse. --check-only exits 0 on all of these;\nthey were found by grepping its stderr, which is the only signal it gives.\n' \
		"$failed" "$checked"
	exit 1
fi

echo "scripts OK ($checked checked)"
