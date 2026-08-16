#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${1:-$ROOT/build/MacMedia.app}"
DEST="/Applications/MacMedia.app"

if [[ ! -d "$APP" ]]; then
  echo "MacMedia.app not found at $APP"
  echo "Build it first: Scripts/package-app.sh"
  exit 1
fi

rm -rf "$DEST"
cp -R "$APP" "$DEST"
xattr -cr "$DEST" 2>/dev/null || true
echo "Installed $DEST"
echo "If macOS blocks it: right-click MacMedia in Applications and choose Open."
open "$DEST"
