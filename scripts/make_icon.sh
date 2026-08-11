#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# packaging/icon_1024.png is checked in, so the icon no longer depends on a
# Swift drawing script running correctly at build time.
SRC="packaging/icon_1024.png"
[ -f "$SRC" ] || { echo "missing $SRC"; exit 1; }

ICONSET="packaging/Pasty.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"

gen() { sips -z "$1" "$1" "$SRC" --out "$ICONSET/$2" >/dev/null; }
gen 16   icon_16x16.png
gen 32   icon_16x16@2x.png
gen 32   icon_32x32.png
gen 64   icon_32x32@2x.png
gen 128  icon_128x128.png
gen 256  icon_128x128@2x.png
gen 256  icon_256x256.png
gen 512  icon_256x256@2x.png
gen 512  icon_512x512.png
gen 1024 icon_512x512@2x.png

iconutil -c icns "$ICONSET" -o packaging/Pasty.icns
echo "wrote packaging/Pasty.icns"
