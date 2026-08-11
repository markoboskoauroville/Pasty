#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-1.0.0}"
BUILD="${BUILD:-1}"
APP="packaging/Pasty.app"

# A universal (arm64 + x86_64) build is driven by xcbuild, which ships with full
# Xcode and NOT with the Command Line Tools. Asking for it on a CLT-only machine
# fails with "xcbuild executable ... does not exist". So the fat build is used
# only when xcbuild is actually present; otherwise build for this machine, which
# is all a local install needs.
#
# No bash arrays here on purpose: macOS still ships bash 3.2, where expanding an
# empty array under `set -u` aborts the script.
XCBUILD="/Library/Developer/SharedFrameworks/XCBuild.framework/Versions/A/Support/xcbuild"
if [ -x "$XCBUILD" ]; then
    echo "==> Building universal release binary (arm64 + x86_64)"
    swift build -c release --arch arm64 --arch x86_64
    BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/Pasty"
else
    echo "==> Building release binary for this machine ($(uname -m))"
    echo "    full Xcode not found, so skipping the universal build"
    swift build -c release
    BIN="$(swift build -c release --show-bin-path)/Pasty"
fi
echo "    binary: $BIN"

echo "==> Generating icon"
bash scripts/make_icon.sh >/dev/null

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Pasty"
cp packaging/Pasty.icns "$APP/Contents/Resources/Pasty.icns"

sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD/" \
    packaging/Info.plist > "$APP/Contents/Info.plist"

printf 'APPL????' > "$APP/Contents/PkgInfo"

# Ad-hoc signature so macOS treats the bundle consistently.
codesign --force --sign - "$APP" >/dev/null 2>&1 || echo "    note: ad-hoc signing skipped"

echo "==> Built $APP"
/usr/bin/file "$APP/Contents/MacOS/Pasty"
echo "    version $VERSION ($BUILD)"
