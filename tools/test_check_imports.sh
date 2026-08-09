#!/usr/bin/env bash
# Contract tests for Godot, diagnostic, and diagnostic-checker failure signals.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

run_case() {
	local name="$1"
	local body="$2"
	local want_rc="$3"
	local fake="$TMP/godot-$name"
	printf '#!/usr/bin/env bash\n%s\n' "$body" >"$fake"
	chmod +x "$fake"
	set +e
	GODOT="$fake" "$ROOT/tools/check_imports.sh" >"$TMP/$name.out" 2>"$TMP/$name.err"
	local got_rc=$?
	set -e
	if [ "$got_rc" -ne "$want_rc" ]; then
		printf '%s: wanted rc %s, got %s\n' "$name" "$want_rc" "$got_rc" >&2
		cat "$TMP/$name.err" >&2
		exit 1
	fi
}

run_case clean 'echo "Godot import complete"; exit 0' 0
run_case stderr_error 'echo "ERROR: Failed loading resource" >&2; exit 0' 1
run_case invocation_error 'echo "launcher failed" >&2; exit 23' 1

mkdir "$TMP/bin"
printf '#!/usr/bin/env bash\nexit 2\n' >"$TMP/bin/grep"
chmod +x "$TMP/bin/grep"
set +e
PATH="$TMP/bin:$PATH" GODOT="$TMP/godot-clean" \
	"$ROOT/tools/check_imports.sh" >"$TMP/checker_error.out" 2>"$TMP/checker_error.err"
checker_error_rc=$?
set -e
if [ "$checker_error_rc" -ne 1 ]; then
	printf 'checker_error: wanted rc 1, got %s\n' "$checker_error_rc" >&2
	exit 1
fi

grep -q 'asset import OK' "$TMP/clean.out"
grep -q 'stderr errors=1' "$TMP/stderr_error.err"
grep -q 'godot rc=23' "$TMP/invocation_error.err"
grep -q 'checker rc=2' "$TMP/checker_error.err"

echo "check_imports tests OK (4 cases)"
