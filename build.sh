#!/bin/bash
# Builds "Mac Dial.app" natively for Apple Silicon.
# Needs only the Command Line Tools (xcode-select --install), not full Xcode.
#
#   ./build.sh            build into ./build
#   ./build.sh --install  build, copy to /Applications and launch
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Mac Dial"
BUNDLE_ID="local.macdial.MacDial"
APP="build/$APP_NAME.app"

if ! xcrun --find swift >/dev/null 2>&1; then
    echo "No Swift toolchain found. Install the Command Line Tools first:"
    echo "    xcode-select --install"
    exit 1
fi

echo "▸ Compiling ($(uname -m), release)"
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

echo "▸ Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/MacDial" "$APP/Contents/MacOS/MacDial"
cp Resources/Info.plist "$APP/Contents/Info.plist"

ICONSET="build/AppIcon.iconset"
rm -rf "$ICONSET" && mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
    sips -z $size $size Resources/icon.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    sips -z $((size * 2)) $((size * 2)) Resources/icon.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

echo "▸ Signing (ad-hoc)"
codesign --force --sign - "$APP"

if [[ "${1:-}" == "--install" ]]; then
    echo "▸ Installing to /Applications"
    pkill -x MacDial 2>/dev/null || true
    rm -rf "/Applications/$APP_NAME.app"
    cp -R "$APP" "/Applications/"
    # Ad-hoc signatures change on every build, which leaves a stale
    # Accessibility entry behind. Clear it so macOS asks again cleanly.
    tccutil reset Accessibility "$BUNDLE_ID" >/dev/null 2>&1 || true
    open "/Applications/$APP_NAME.app"
    echo "✓ Installed. Grant Accessibility access when prompted."
else
    echo "✓ Built $APP"
fi
