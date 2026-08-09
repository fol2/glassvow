#!/usr/bin/env bash
# Regression tests for discovery and explicit-path handling in check_scripts.sh.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

tmpdir=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/glassvow-check-scripts.XXXXXX") || exit 1
fakebin="$tmpdir/bin"
output="$tmpdir/output"
mkdir -p "$fakebin" || exit 1
trap 'rm -rf -- "$tmpdir"' EXIT

cat >"$fakebin/git" <<'EOF'
#!/usr/bin/env bash
case "${FAKE_GIT_MODE:-success}" in
	error)
		exit 42
		;;
	empty)
		exit 0
		;;
	success)
		printf '%s\n' addons/ignored.gd tests/test_rng.gd
		;;
esac
EOF

cat >"$fakebin/godot" <<'EOF'
#!/usr/bin/env bash
exit "${FAKE_GODOT_RC:-0}"
EOF

cat >"$fakebin/mktemp" <<'EOF'
#!/usr/bin/env bash
if [ "${FAKE_MKTEMP_FAIL:-0}" -eq 1 ]; then
	exit 73
fi
exec /usr/bin/mktemp "$@"
EOF

chmod +x "$fakebin/git" "$fakebin/godot" "$fakebin/mktemp" || exit 1

failures=0

check_case() {
	name=$1
	expected_rc=$2
	expected_text=$3
	shift 3
	"$@" >"$output" 2>&1
	rc=$?
	if [ "$rc" -ne "$expected_rc" ]; then
		printf 'not ok - %s: expected rc %d, got %d\n' "$name" "$expected_rc" "$rc"
		cat "$output"
		failures=$((failures + 1))
		return
	fi
	if ! grep -Fq "$expected_text" "$output"; then
		printf 'not ok - %s: missing %s\n' "$name" "$expected_text"
		cat "$output"
		failures=$((failures + 1))
		return
	fi
	printf 'ok - %s\n' "$name"
}

check_case "discovery command failure" 1 \
	"DISCOVERY git ls-files exited with status 42." \
	env PATH="$fakebin:$PATH" FAKE_GIT_MODE=error tools/check_scripts.sh
check_case "zero discovered scripts" 1 \
	"DISCOVERY No tracked non-addon .gd scripts found." \
	env PATH="$fakebin:$PATH" FAKE_GIT_MODE=empty tools/check_scripts.sh
check_case "tracked discovery" 0 "scripts OK (1 checked)" \
	env PATH="$fakebin:$PATH" FAKE_GIT_MODE=success tools/check_scripts.sh
check_case "explicit path bypasses discovery" 0 "scripts OK (1 checked)" \
	env PATH="$fakebin:$PATH" FAKE_GIT_MODE=error \
	tools/check_scripts.sh tests/test_rng.gd
check_case "temporary directory failure" 1 \
	"TEMP     Unable to create a working directory." \
	env PATH="$fakebin:$PATH" FAKE_MKTEMP_FAIL=1 tools/check_scripts.sh

if [ "$failures" -ne 0 ]; then
	printf '%d check_scripts regression test(s) failed.\n' "$failures"
	exit 1
fi

printf 'check_scripts regression tests OK (5 cases)\n'
