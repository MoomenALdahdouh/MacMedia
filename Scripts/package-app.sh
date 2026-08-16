#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/build"
APP="$BUILD_DIR/MacMedia.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
FW="$CONTENTS/Frameworks"
RES="$CONTENTS/Resources"
IDENTITY="${CODESIGN_IDENTITY:-}"
if [[ -z "$IDENTITY" ]]; then
  if security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
    IDENTITY="$(security find-identity -v -p codesigning | awk -F'"' '/Developer ID Application/ {print $2; exit}')"
  elif security find-identity -v -p codesigning | grep -q "Apple Development"; then
    IDENTITY="$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development/ {print $2; exit}')"
  fi
fi

cd "$ROOT"
if [[ ! -f "$ROOT/Vendor/lib/libmpv.dylib" && ! -f "$ROOT/Vendor/lib/libmpv.2.dylib" ]]; then
  echo "Vendored libmpv missing. Run Scripts/vendor-libs.sh first."
  exit 1
fi

swift build -c release --product MacMedia

BIN="$(swift build -c release --show-bin-path)/MacMedia"
rm -rf "$APP"
mkdir -p "$MACOS" "$FW" "$RES"

cp "$BIN" "$MACOS/MacMedia"
cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"
echo -n "APPL????" > "$CONTENTS/PkgInfo"
cp "$ROOT/LICENSE" "$RES/LICENSE"
cp "$ROOT/THIRD_PARTY_LICENSES.md" "$RES/THIRD_PARTY_LICENSES.md"
if [[ -f "$ROOT/NOTICE.md" ]]; then
  cp "$ROOT/NOTICE.md" "$RES/NOTICE.md"
fi
if [[ -f "$ROOT/Resources/HowToOpen.txt" ]]; then
  cp "$ROOT/Resources/HowToOpen.txt" "$RES/HowToOpen.txt"
fi
if [[ -d "$ROOT/Resources/Licenses" ]]; then
  cp -R "$ROOT/Resources/Licenses" "$RES/Licenses"
fi
if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
  cp "$ROOT/Resources/AppIcon.icns" "$RES/AppIcon.icns"
fi

cp -R "$ROOT/Vendor/lib/"*.dylib "$FW/" 2>/dev/null || true
# Preserve compatibility symlinks used by @rpath install names.
shopt -s nullglob
for link in "$ROOT/Vendor/lib/"*.dylib; do
  if [[ -L "$link" ]]; then
    cp -P "$link" "$FW/" || true
  fi
done
python3 "$ROOT/Scripts/rewrite-rpaths.py" "$FW"
find "$FW" -name '*.dylib' -exec codesign --force --sign - {} \;

install_name_tool -add_rpath "@executable_path/../Frameworks" "$MACOS/MacMedia" 2>/dev/null || true

# Ensure the binary looks up libmpv via rpath.
if otool -L "$MACOS/MacMedia" | grep -q libmpv; then
  while read -r dep; do
    name="$(basename "$dep")"
    if [[ -f "$FW/$name" ]]; then
      install_name_tool -change "$dep" "@rpath/$name" "$MACOS/MacMedia" || true
    fi
  done < <(otool -L "$MACOS/MacMedia" | awk '/libmpv|libav|libass|libplacebo|libsw|libsoxr|libx264|libx265|libopus|libvpx|libdav1d|libarchive/ {print $1}')
fi

chmod +x "$MACOS/MacMedia"

if [[ -n "$IDENTITY" ]] && security find-identity -v -p codesigning | grep -F -q "$IDENTITY"; then
  codesign --force --deep --sign "$IDENTITY" --timestamp --options runtime "$APP" || codesign --force --deep --sign "$IDENTITY" "$APP"
  echo "SIGNED with $IDENTITY"
else
  codesign --force --deep --sign - "$APP"
  echo "SIGNED ad-hoc (no matching codesigning identity)"
fi

echo "Built $APP"
file "$MACOS/MacMedia"
otool -L "$MACOS/MacMedia" | head
