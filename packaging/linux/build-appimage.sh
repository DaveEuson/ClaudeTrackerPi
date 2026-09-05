#!/usr/bin/env bash
# Build the AppImage from a binary PyInstaller has already produced.
#
# Usage: build-appimage.sh <version> <tray-binary> <output-dir>
#
# An AppImage is a single file you chmod +x and run, with no install step and
# no root. That makes it the counterpart to the .deb rather than a duplicate
# of it: the .deb is for distributions that use apt, this is for everything
# else and for people who would rather not install anything at all.
set -euo pipefail

VERSION="${1:?version required, e.g. 1.10.0}"
TRAY_BIN="${2:?path to the tray binary required}"
OUT_DIR="${3:-.}"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG="yoyu-companion"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
APPDIR="$WORK/AppDir"

install -d -m 0755 "$APPDIR/usr/bin"
install -m 0755 "$TRAY_BIN" "$APPDIR/usr/bin/$PKG"

# The desktop file and icon have to sit at the AppDir root as well, which is
# where appimagetool looks for them.
install -m 0644 "$HERE/yoyu-companion.desktop" "$APPDIR/$PKG.desktop"
install -d -m 0755 "$APPDIR/usr/share/applications"
install -m 0644 "$HERE/yoyu-companion.desktop" \
        "$APPDIR/usr/share/applications/$PKG.desktop"

install -d -m 0755 "$APPDIR/usr/share/metainfo"
install -m 0644 "$HERE/yoyu-companion.metainfo.xml" \
        "$APPDIR/usr/share/metainfo/$PKG.appdata.xml"

ICON_TMP="$(mktemp -d)"
python3 "$HERE/make-icons.py" "$ICON_TMP" >/dev/null
install -m 0644 "$ICON_TMP/yoyu-companion-256.png" "$APPDIR/$PKG.png"
for px in 64 128 256; do
  d="$APPDIR/usr/share/icons/hicolor/${px}x${px}/apps"
  install -d -m 0755 "$d"
  install -m 0644 "$ICON_TMP/yoyu-companion-${px}.png" "$d/$PKG.png"
done
rm -rf "$ICON_TMP"

# AppRun is what the runtime executes. Exec the real binary so it keeps PID 1
# of the payload and signals reach it, and pass arguments straight through so
# --install, --once and the rest work from an AppImage too.
cat > "$APPDIR/AppRun" <<'APPRUN'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
exec "$HERE/usr/bin/yoyu-companion" "$@"
APPRUN
chmod 0755 "$APPDIR/AppRun"

TOOL="$WORK/appimagetool"
curl -fsSL -o "$TOOL" \
  "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage"
chmod +x "$TOOL"

mkdir -p "$OUT_DIR"
OUT="$OUT_DIR/YoyuCompanion-${VERSION}-x86_64.AppImage"
# --appimage-extract-and-run because a CI container has no FUSE to mount with.
ARCH=x86_64 VERSION="$VERSION" \
  "$TOOL" --appimage-extract-and-run "$APPDIR" "$OUT" >/dev/null
chmod +x "$OUT"
echo "$OUT"
