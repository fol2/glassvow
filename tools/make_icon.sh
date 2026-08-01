#!/bin/zsh
# Build glassvow.icns from the 1024px master via sips + iconutil (macOS only).
# The master is a candidate crop of the emberglass rose; swapping the icon is
# a one-file replace of assets/icon/glassvow-icon.png followed by this script.
#   tools/make_icon.sh
set -eu
ROOT="${0:A:h:h}"
MASTER="$ROOT/assets/icon/glassvow-icon.png"
SET="$ROOT/assets/icon/glassvow.iconset"
mkdir -p "$SET"
for side in 16 32 128 256 512; do
	sips -z $side $side "$MASTER" --out "$SET/icon_${side}x${side}.png" >/dev/null
	double=$((side * 2))
	sips -z $double $double "$MASTER" --out "$SET/icon_${side}x${side}@2x.png" >/dev/null
done
iconutil -c icns "$SET" -o "$ROOT/assets/icon/glassvow.icns"
rm -r "$SET"
print "wrote assets/icon/glassvow.icns"
