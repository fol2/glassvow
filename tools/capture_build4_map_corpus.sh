#!/usr/bin/env bash
# Rebuild the exact TestFlight 1.0.0 (4) map-defect corpus (#462).
set -euo pipefail

BUILD4_SOURCE_COMMIT="52a56e726da70c2dd57254e8c6618682c7558f90"
EXPECTED_GODOT_PREFIX="4.7.2.stable"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT="$ROOT/artifacts/build4-map-corpus"
VERIFY_REPEAT=false
CAPTURE_HEAD=""
GODOT_BIN="${GODOT_BIN:-godot}"
ON_PRODUCTION_DRIFT="fail"
DETECT_DRIFT_ONLY=false
PRODUCTION_PATHS=(
  application
  assets/art/map
  content
  domain
  presentation
  project.godot
)

usage() {
  cat <<'USAGE'
Usage: tools/capture_build4_map_corpus.sh [options]

Options:
  --output PATH                 Packet output (default: artifacts/build4-map-corpus)
  --verify-repeat               Capture twice; require byte-identical manifest/dimensions
  --capture-head SHA            Exact checked-out head (normally inferred from git)
  --godot PATH                  Godot executable (default: $GODOT_BIN or godot)
  --on-production-drift MODE    fail (default) or skip when production inputs drifted
  --detect-drift-only           Print drifted=true|false and exit 0; no Godot capture
  -h, --help                    Show this help
USAGE
}

while (($#)); do
  case "$1" in
    --output)
      [[ $# -ge 2 ]] || { echo "--output requires a path" >&2; exit 2; }
      OUTPUT="$2"
      shift 2
      ;;
    --output=*)
      OUTPUT="${1#*=}"
      shift
      ;;
    --verify-repeat)
      VERIFY_REPEAT=true
      shift
      ;;
    --capture-head)
      [[ $# -ge 2 ]] || { echo "--capture-head requires a SHA" >&2; exit 2; }
      CAPTURE_HEAD="$2"
      shift 2
      ;;
    --capture-head=*)
      CAPTURE_HEAD="${1#*=}"
      shift
      ;;
    --godot)
      [[ $# -ge 2 ]] || { echo "--godot requires a path" >&2; exit 2; }
      GODOT_BIN="$2"
      shift 2
      ;;
    --godot=*)
      GODOT_BIN="${1#*=}"
      shift
      ;;
    --on-production-drift)
      [[ $# -ge 2 ]] || { echo "--on-production-drift requires fail or skip" >&2; exit 2; }
      ON_PRODUCTION_DRIFT="$2"
      shift 2
      ;;
    --on-production-drift=*)
      ON_PRODUCTION_DRIFT="${1#*=}"
      shift
      ;;
    --detect-drift-only)
      DETECT_DRIFT_ONLY=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

cd "$ROOT"
command -v git >/dev/null || { echo "capture_build4_map_corpus: git is required" >&2; exit 2; }
if [[ "$ON_PRODUCTION_DRIFT" != "fail" && "$ON_PRODUCTION_DRIFT" != "skip" ]]; then
  echo "capture_build4_map_corpus: --on-production-drift must be fail or skip, got $ON_PRODUCTION_DRIFT" >&2
  exit 2
fi

ACTUAL_HEAD="$(git rev-parse HEAD)"
CAPTURE_HEAD="${CAPTURE_HEAD:-$ACTUAL_HEAD}"
if [[ "$CAPTURE_HEAD" != "$ACTUAL_HEAD" ]]; then
  echo "capture_build4_map_corpus: --capture-head $CAPTURE_HEAD does not match checked-out HEAD $ACTUAL_HEAD" >&2
  exit 2
fi
if [[ ! "$CAPTURE_HEAD" =~ ^[0-9a-f]{40}$ ]]; then
  echo "capture_build4_map_corpus: capture head is not a full lowercase Git SHA: $CAPTURE_HEAD" >&2
  exit 2
fi
if ! git cat-file -e "${BUILD4_SOURCE_COMMIT}^{commit}" 2>/dev/null; then
  echo "capture_build4_map_corpus: build-4 source commit is unavailable: $BUILD4_SOURCE_COMMIT" >&2
  exit 2
fi

write_drift_status() {
  local reason_dir="$ROOT/artifacts/build4-map-corpus-diagnostics"
  mkdir -p "$reason_dir"
  if $DRIFTED; then
    printf 'drifted=true\n' > "$reason_dir/drift.txt"
    {
      printf 'skipped=true\n'
      printf 'reason=production_inputs_differ_from_build4_source\n'
      printf 'build4_source=%s\n' "$BUILD4_SOURCE_COMMIT"
      printf 'capture_head=%s\n' "$CAPTURE_HEAD"
      printf 'changed_paths=\n'
      git diff --name-only "$BUILD4_SOURCE_COMMIT" "$CAPTURE_HEAD" -- "${PRODUCTION_PATHS[@]}"
    } > "$reason_dir/skip_reason.txt"
  else
    printf 'drifted=false\n' > "$reason_dir/drift.txt"
  fi
}

# The ticket is evidence-only. A drifted tree cannot regenerate the frozen
# build-4 corpus. Local capture fails; CI may skip green instead of failing.
DRIFTED=false
if ! git diff --quiet "$BUILD4_SOURCE_COMMIT" "$CAPTURE_HEAD" -- "${PRODUCTION_PATHS[@]}"; then
  DRIFTED=true
fi

if $DETECT_DRIFT_ONLY; then
  write_drift_status
  if $DRIFTED; then
    printf 'drifted=true\n'
  else
    printf 'drifted=false\n'
  fi
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    if $DRIFTED; then
      echo "drifted=true" >> "$GITHUB_OUTPUT"
    else
      echo "drifted=false" >> "$GITHUB_OUTPUT"
    fi
  fi
  exit 0
fi

if $DRIFTED; then
  echo "capture_build4_map_corpus: production inputs differ from build-4 source $BUILD4_SOURCE_COMMIT" >&2
  git diff --name-only "$BUILD4_SOURCE_COMMIT" "$CAPTURE_HEAD" -- "${PRODUCTION_PATHS[@]}" >&2
  if [[ "$ON_PRODUCTION_DRIFT" == "skip" ]]; then
    write_drift_status
    echo "capture_build4_map_corpus: skipping capture (--on-production-drift=skip)" >&2
    exit 0
  fi
  exit 2
fi

command -v "$GODOT_BIN" >/dev/null || { echo "capture_build4_map_corpus: Godot executable not found: $GODOT_BIN" >&2; exit 2; }
python3 -c 'from PIL import Image' >/dev/null 2>&1 || {
  echo "capture_build4_map_corpus: Pillow is required (python3 -m pip install 'Pillow>=10,<13')" >&2
  exit 2
}

GODOT_VERSION="$($GODOT_BIN --version | head -n 1 | tr -d '\r')"
if [[ "$GODOT_VERSION" != "$EXPECTED_GODOT_PREFIX"* ]]; then
  echo "capture_build4_map_corpus: expected Godot $EXPECTED_GODOT_PREFIX.*, got $GODOT_VERSION" >&2
  exit 2
fi

if command -v sha256sum >/dev/null 2>&1; then
  ASSET_MANIFEST_SHA256="$(sha256sum assets/art/map/map-assets.json | awk '{print $1}')"
elif command -v shasum >/dev/null 2>&1; then
  ASSET_MANIFEST_SHA256="$(shasum -a 256 assets/art/map/map-assets.json | awk '{print $1}')"
else
  echo "capture_build4_map_corpus: sha256sum or shasum is required" >&2
  exit 2
fi

if [[ -z "$OUTPUT" || "$OUTPUT" == "/" ]]; then
  echo "capture_build4_map_corpus: refusing unsafe output path: $OUTPUT" >&2
  exit 2
fi
mkdir -p "$(dirname "$OUTPUT")"
OUTPUT="$(cd "$(dirname "$OUTPUT")" && pwd)/$(basename "$OUTPUT")"
rm -rf "$OUTPUT"
mkdir -p "$OUTPUT"

run_godot_capture() {
  local run_dir="$1"
  local -a command=(
    "$GODOT_BIN"
    --path "$ROOT"
    --rendering-method gl_compatibility
    --resolution 1180x820
    --position "${GLASSVOW_SHOT_POSITION:--4000,-4000}"
    -s res://tools/capture_build4_map_corpus.gd
    --
    "--output=$run_dir"
    "--capture-head=$CAPTURE_HEAD"
    "--asset-manifest-sha256=$ASSET_MANIFEST_SHA256"
  )

  if [[ "$(uname -s)" == "Linux" && -z "${DISPLAY:-}" ]]; then
    command -v xvfb-run >/dev/null || {
      echo "capture_build4_map_corpus: Linux capture without DISPLAY requires xvfb-run" >&2
      return 2
    }
    xvfb-run -a "${command[@]}"
  else
    "${command[@]}"
  fi
}

capture_and_package() {
  local name="$1"
  local run_dir="$OUTPUT/$name"
  mkdir -p "$run_dir"
  run_godot_capture "$run_dir"
  python3 tools/package_build4_map_corpus.py package --run "$run_dir"
}

echo "capture_build4_map_corpus: source=$BUILD4_SOURCE_COMMIT head=$CAPTURE_HEAD godot=$GODOT_VERSION"
echo "capture_build4_map_corpus: asset_manifest_sha256=$ASSET_MANIFEST_SHA256"
capture_and_package run-a

if $VERIFY_REPEAT; then
  capture_and_package run-b
  python3 tools/package_build4_map_corpus.py compare \
    --first "$OUTPUT/run-a" \
    --second "$OUTPUT/run-b" \
    --output "$OUTPUT/repeatability.json"
fi

python3 tools/package_build4_map_corpus.py publish \
  --first "$OUTPUT/run-a" \
  --output "$OUTPUT"

printf 'capture_build4_map_corpus: packet ready at %s\n' "$OUTPUT"
