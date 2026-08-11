#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# The source artwork lives in assets/ and is tracked. packaging/ stays what it
# has always been, a folder of generated output that .gitignore excludes, which
# is exactly why an icon left there never reached CI.
SRC="assets/icon_1024.png"
[ -f "$SRC" ] || { echo "missing $SRC, run: python3 scripts/icon_gen.py" >&2; exit 1; }

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
