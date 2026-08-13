#!/usr/bin/env bash
# Fixture harness for tools/check_store_dev_exclusion.py.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/glassvow-store-dev.XXXXXX") || exit 1
trap 'rm -rf -- "$tmpdir"' EXIT
output="$tmpdir/output"
failures=0

check_case() {
	name=$1 expected_rc=$2 expected_text=$3
	shift 3
	"$@" >"$output" 2>&1
	rc=$?
	if [ "$rc" -ne "$expected_rc" ] || ! grep -Fq "$expected_text" "$output"; then
		printf 'not ok - %s: rc %d (want %d)\n' "$name" "$rc" "$expected_rc"
		cat "$output"
		failures=$((failures + 1))
		return
	fi
	printf 'ok - %s\n' "$name"
}

ini() {
	cat >"$1" <<EOF
[preset.0]
name="Web Dev"
custom_features="$4"
exclude_filter=""
[preset.1]
name="macOS"
custom_features="$3"
exclude_filter="$2"
[preset.2]
name="iOS"
custom_features=""
exclude_filter="port_fixtures/*,presentation/dev/*"
[preset.3]
name="Android (Play AAB)"
custom_features=""
exclude_filter="port_fixtures/*,presentation/dev/*"
[preset.4]
name="iOS Dev Review"
custom_features="dev_tools"
exclude_filter="port_fixtures/*"
EOF
}

root="$tmpdir/tree"
mkdir -p "$root/presentation/dev" "$root/application"
printf 'extends RefCounted\n' >"$root/presentation/dev/boot.gd"
printf 'extends RefCounted\n' >"$root/application/main.gd"
printf 'presentation/dev/boot.gd\napplication/main.gd\n' >"$tmpdir/tracked"
run() {
	env STORE_DEV_PRESETS="$1" STORE_DEV_TRACKED="$tmpdir/tracked" \
		STORE_DEV_ROOT="$root" python3 tools/check_store_dev_exclusion.py
}

ini "$tmpdir/missing.cfg" "" "" "dev_tools"
check_case "missing exclude" 1 "exclude_filter does not match" run "$tmpdir/missing.cfg"
ini "$tmpdir/feat.cfg" "presentation/dev/*" "dev_tools" "dev_tools"
check_case "dev_tools on store" 1 "lists custom feature dev_tools" run "$tmpdir/feat.cfg"
printf 'extends RefCounted\nfunc f() -> void:\n\tpass # --scenario=\n' >"$root/application/main.gd"
ini "$tmpdir/ok.cfg" "presentation/dev/*" "" "dev_tools"
check_case "scenario leak" 1 "forbidden token --scenario" run "$tmpdir/ok.cfg"
printf 'extends RefCounted\n' >"$root/application/main.gd"
check_case "happy path" 0 "store-dev-exclusion OK" run "$tmpdir/ok.cfg"

if [ "$failures" -ne 0 ]; then
	printf '%d store-dev-exclusion regression test(s) failed.\n' "$failures"
	exit 1
fi
printf 'check_store_dev_exclusion regression tests OK (4 cases)\n'
