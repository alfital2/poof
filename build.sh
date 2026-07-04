#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP="Poof.app"
BIN="poof"

echo "Building release binary..."
swift build -c release

echo "Assembling $APP..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/$BIN" "$APP/Contents/MacOS/$BIN"
cp "Resources/Info.plist" "$APP/Contents/Info.plist"

echo "Ad-hoc code signing..."
codesign --force --sign - "$APP"

echo "Done: $APP"
