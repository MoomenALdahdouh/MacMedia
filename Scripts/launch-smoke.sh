#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/MacMedia.app"
if [[ ! -d "$APP" ]]; then
  echo "Missing $APP"
  exit 1
fi
open "$APP"
sleep 2
if pgrep -lf "MacMedia.app/Contents/MacOS/MacMedia" >/dev/null; then
  echo "APP LAUNCH: PASS"
  exit 0
fi
echo "APP LAUNCH: FAIL"
exit 1
