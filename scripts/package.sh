#!/usr/bin/env bash
#
# Builds a Release AnswerSheetToolkit.app and packages it for distribution as
# both a .dmg (drag-to-Applications installer) and a .zip.
#
# Usage:
#   ./scripts/package.sh
#
# Output goes to ./dist/
#
set -euo pipefail

SCHEME="AnswerSheetToolkit"
APP_NAME="AnswerSheetToolkit"
CONFIG="Release"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT/build"
DIST_DIR="$ROOT/dist"
DERIVED="$BUILD_DIR/DerivedData"

rm -rf "$BUILD_DIR" "$DIST_DIR"
mkdir -p "$DIST_DIR"

echo "==> Building $SCHEME ($CONFIG)…"
xcodebuild build \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  | tail -n 3

APP_PATH="$DERIVED/Build/Products/$CONFIG/$APP_NAME.app"
if [ ! -d "$APP_PATH" ]; then
  echo "error: build product not found at $APP_PATH" >&2
  exit 1
fi

VERSION="$(/usr/bin/defaults read "$APP_PATH/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "1.0")"

# --- ZIP (preserves macOS metadata via ditto) ---
echo "==> Creating ZIP…"
ZIP_PATH="$DIST_DIR/${APP_NAME}-${VERSION}.zip"
/usr/bin/ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
echo "    -> $ZIP_PATH"

# --- DMG (with an Applications symlink for drag-install) ---
echo "==> Creating DMG…"
DMG_PATH="$DIST_DIR/${APP_NAME}-${VERSION}.dmg"
STAGING="$BUILD_DIR/dmg-staging"
rm -rf "$STAGING"; mkdir -p "$STAGING"
cp -R "$APP_PATH" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING" \
  -ov -format UDZO \
  "$DMG_PATH" >/dev/null
echo "    -> $DMG_PATH"

echo ""
echo "==> Done. Distributables in $DIST_DIR:"
ls -lh "$DIST_DIR"
echo ""
echo "NOTE: This build is unsigned. On another Mac, Gatekeeper will warn the app"
echo "      is from an unidentified developer. To open it, the recipient should"
echo "      right-click the app -> Open (once), or run:"
echo "        xattr -dr com.apple.quarantine /Applications/${APP_NAME}.app"
