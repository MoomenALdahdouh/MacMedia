#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/build"
APP="$BUILD_DIR/MacMedia.app"
STAGE="$BUILD_DIR/dmg-stage"
DMG="$BUILD_DIR/MacMedia.dmg"

if [[ ! -d "$APP" ]]; then
  "$ROOT/Scripts/package-app.sh"
fi

rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/MacMedia.app"
ln -s /Applications "$STAGE/Applications"
cp "$ROOT/README.md" "$STAGE/README.md"
cp "$ROOT/LICENSE" "$STAGE/LICENSE"
cp "$ROOT/THIRD_PARTY_LICENSES.md" "$STAGE/THIRD_PARTY_LICENSES.md"

hdiutil create -volname "MacMedia" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
echo "Created $DMG"
ls -lh "$DMG"
