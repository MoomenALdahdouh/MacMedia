#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR="$ROOT/Vendor"
SRC="$VENDOR/src/mpv"
PREFIX="$VENDOR"
LIB="$VENDOR/lib"
INCLUDE="$VENDOR/include"
BUILD="$VENDOR/build/mpv"

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
if [[ -d /opt/homebrew/lib/pkgconfig ]]; then
  export PKG_CONFIG_PATH="/opt/homebrew/lib/pkgconfig:/opt/homebrew/opt/libarchive/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
elif [[ -d /usr/local/lib/pkgconfig ]]; then
  export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
fi
export MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-13.0}"

mkdir -p "$VENDOR/src" "$LIB" "$INCLUDE" "$BUILD"

if [[ ! -d "$SRC/.git" ]]; then
  git clone --depth 1 --branch v0.41.0 https://github.com/mpv-player/mpv.git "$SRC"
fi

if [[ ! -f "$BUILD/build.ninja" ]]; then
  meson setup "$BUILD" "$SRC" \
    --prefix="$PREFIX" \
    --buildtype=release \
    -Dlibmpv=true \
    -Dcplayer=false \
    -Dlua=disabled \
    -Djavascript=disabled \
    -Dvapoursynth=disabled \
    -Dlibarchive=enabled \
    -Dswift-build=enabled \
    -Dcocoa=enabled \
    -Dgl-cocoa=enabled \
    -Dmacos-cocoa-cb=disabled \
    -Dmanpage-build=disabled \
    -Dhtml-build=disabled
fi

meson compile -C "$BUILD"
meson install -C "$BUILD"

# Headers used by CMpv also live in Sources/CMpv; keep Vendor/include in sync.
mkdir -p "$INCLUDE/mpv"
cp -R "$PREFIX/include/mpv/." "$INCLUDE/mpv/" 2>/dev/null || true
cp -R "$SRC/include/mpv/." "$ROOT/Sources/CMpv/include/mpv/"

python3 "$ROOT/Scripts/rewrite-rpaths.py" "$LIB"
find "$LIB" -name '*.dylib' -exec codesign --force --sign - {} \;

echo "Vendored libmpv at $LIB"
ls -lh "$LIB"/libmpv* || true
