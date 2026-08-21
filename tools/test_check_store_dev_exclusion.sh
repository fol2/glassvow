#!/usr/bin/env bash
# Fixture harness for tools/check_store_dev_exclusion.py.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/glassvow-store-dev.XXXXXX") || exit 1
trap 'rm -rf -- "$tmpdir"' EXIT
output="$tmpdir/output"
failures=0
OK_FILTER="port_fixtures/*,presentation/dev/*,tests/*,addons/funplay_mcp/*,addons/core/*,addons/runtime/*,addons/ui/*,addons/plugin.*,addons/icon.svg*,addons/glassvow_ios_export/*,addons/glassvow_web_export/*,tools/balance_*,tools/bench_*,tools/capture_*,tools/check_*,tools/live.*,tools/map_*,tools/probe_*,tools/raster_*,tools/vigil_*,tools/vow_ladder_*"

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
	review_ex=${5:-port_fixtures/*}
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
exclude_filter="$2"
[preset.3]
name="Android (Play AAB)"
custom_features=""
exclude_filter="$2"
[preset.4]
name="iOS Dev Review"
custom_features="dev_tools"
exclude_filter="$review_ex"
EOF
}

write_pck() {
	python3 -c '
import struct, sys
from pathlib import Path
dest = Path(sys.argv[1])
version = int(sys.argv[2]) if len(sys.argv) > 2 else 2
paths = [ln.encode("utf-8") for ln in sys.stdin.read().splitlines() if ln]
entries = b""
for raw in paths:
    entries += struct.pack("<I", len(raw)) + raw
    entries += struct.pack("<QQ", 0, 0)
    entries += b"\x00" * 16
    entries += struct.pack("<I", 0)
flags = 2 if version >= 3 else 0
header = struct.pack("<6I", 0x43504447, version, 4, 7, 2, flags)
header += struct.pack("<Q", 0)
if version >= 3:
    header += struct.pack("<Q", 40)
else:
    header += b"\x00" * 64
header += struct.pack("<I", len(paths))
dest.write_bytes(header + entries)
' "$1" "${2:-2}"
}

root="$tmpdir/tree"
mkdir -p "$root/presentation/dev" "$root/application"
printf 'extends RefCounted\n' >"$root/presentation/dev/boot.gd"
printf 'extends RefCounted\n' >"$root/application/main.gd"
printf 'presentation/dev/boot.gd\napplication/main.gd\ntests/run_all.gd\n' >"$tmpdir/tracked"
run() {
	env STORE_DEV_PRESETS="$1" STORE_DEV_TRACKED="$tmpdir/tracked" \
		STORE_DEV_ROOT="$root" python3 tools/check_store_dev_exclusion.py
}
run_pck() {
	env STORE_DEV_PRESETS="$tmpdir/ok.cfg" STORE_DEV_TRACKED="$tmpdir/tracked" \
		STORE_DEV_ROOT="$root" python3 tools/check_store_dev_exclusion.py --pck "$1"
}

ini "$tmpdir/missing.cfg" "" "" "dev_tools"
check_case "missing exclude" 1 "exclude_filter does not match" run "$tmpdir/missing.cfg"
ini "$tmpdir/feat.cfg" "$OK_FILTER" "dev_tools" "dev_tools"
check_case "dev_tools on store" 1 "lists custom feature dev_tools" run "$tmpdir/feat.cfg"
printf 'extends RefCounted\nfunc f() -> void:\n\tpass # --scenario=\n' >"$root/application/main.gd"
ini "$tmpdir/ok.cfg" "$OK_FILTER" "" "dev_tools"
check_case "scenario leak" 1 "forbidden token --scenario" run "$tmpdir/ok.cfg"
printf 'extends RefCounted\n' >"$root/application/main.gd"
check_case "happy path" 0 "store-dev-exclusion OK" run "$tmpdir/ok.cfg"
ini "$tmpdir/notests.cfg" "presentation/dev/*" "" "dev_tools"
check_case "missing tests" 1 "does not match tests/run_all.gd" run "$tmpdir/notests.cfg"
ini "$tmpdir/tools.cfg" "presentation/dev/*,tests/*,tools/*" "" "dev_tools"
check_case "blanket tools" 1 "drops tools/vow_incentives.gd" run "$tmpdir/tools.cfg"
ini "$tmpdir/sentry.cfg" "presentation/dev/*,tests/*,addons/*" "" "dev_tools"
check_case "drops sentry" 1 "drops Sentry" run "$tmpdir/sentry.cfg"
ini "$tmpdir/review.cfg" "$OK_FILTER" "" "dev_tools" "port_fixtures/*,presentation/dev/*"
check_case "review console" 1 "must include the Console tree" run "$tmpdir/review.cfg"

write_pck "$tmpdir/good.pck" <<'EOF'
res://tools/vow_incentives.gd
res://application/dev_tools.gd
res://addons/sentry/sentry.gdextension
res://presentation/lab/card_lab.gd
EOF
write_pck "$tmpdir/tests.pck" <<'EOF'
res://tools/vow_incentives.gd
res://application/dev_tools.gd
res://addons/sentry/sentry.gdextension
res://presentation/lab/card_lab.gd
res://tests/run_all.gd
EOF
write_pck "$tmpdir/good-v4.pck" 4 <<'EOF'
res://tools/vow_incentives.gd.remap
res://tools/vow_incentives.gdc
res://application/dev_tools.gdc
res://addons/sentry/sentry.gdextension
res://presentation/lab/card_lab.gdc
EOF
write_pck "$tmpdir/no-extension.pck" 4 <<'EOF'
res://tools/vow_incentives.gd
res://application/dev_tools.gd
res://addons/sentry/user_feedback/sentry_feedback.gd
res://presentation/lab/card_lab.gd
EOF
check_case "pck happy" 0 "pck-dir OK" run_pck "$tmpdir/good.pck"
check_case "pck tests" 1 "pck carries tests/" run_pck "$tmpdir/tests.pck"
check_case "pck v4" 0 "pck-dir OK" run_pck "$tmpdir/good-v4.pck"
check_case "pck sentry extension" 1 "pck missing Sentry extension" run_pck "$tmpdir/no-extension.pck"

if [ "$failures" -ne 0 ]; then
	printf '%d store-dev-exclusion regression test(s) failed.\n' "$failures"
	exit 1
fi
printf 'check_store_dev_exclusion regression tests OK (12 cases)\n'
