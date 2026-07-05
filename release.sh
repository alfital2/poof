#!/bin/bash
#
# release.sh - build a SIGNED + NOTARIZED + STAPLED Poof.app.zip for distribution.
#
# Requires a "Developer ID Application" certificate in the keychain and a stored
# notarytool credential profile (default: flickey-notarize, shared across the
# lab's apps; set up once with `xcrun notarytool store-credentials`). Override
# with NOTARY_PROFILE=<name> ./release.sh
#
# For fast local dev builds use ./build.sh (ad-hoc signed) instead.
set -euo pipefail
cd "$(dirname "$0")"

APP="Poof.app"
BIN="poof"
NOTARY_PROFILE="${NOTARY_PROFILE:-flickey-notarize}"

DEV_ID=$(security find-identity -v -p codesigning \
  | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)"/\1/')
if [ -z "$DEV_ID" ]; then
  echo "ERROR: no 'Developer ID Application' certificate in the keychain." >&2
  exit 1
fi
echo "Signing identity: $DEV_ID"

echo "==> Building release binary"
swift build -c release

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/$BIN" "$APP/Contents/MacOS/$BIN"
cp "Resources/Info.plist" "$APP/Contents/Info.plist"
cp "Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

echo "==> Signing (Developer ID, hardened runtime, secure timestamp)"
codesign --force --sign "$DEV_ID" --timestamp --options runtime "$APP/Contents/MacOS/$BIN"
codesign --force --sign "$DEV_ID" --timestamp --options runtime "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "==> Zipping for notarization"
rm -f "$APP.zip"
ditto -c -k --keepParent "$APP" "$APP.zip"

echo "==> Submitting to Apple notary service (this waits for the result)"
xcrun notarytool submit "$APP.zip" --keychain-profile "$NOTARY_PROFILE" --wait

echo "==> Stapling the ticket to the app"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute --verbose=4 "$APP" || true

echo "==> Re-zipping the stapled app"
rm -f "$APP.zip"
ditto -c -k --keepParent "$APP" "$APP.zip"
echo "Done: $APP.zip (Developer ID signed, notarized, stapled)"
