#!/usr/bin/env bash
# Build the .deb from binaries PyInstaller has already produced.
#
# Usage: build-deb.sh <version> <tray-binary> <cli-binary> <output-dir>
#
# Deliberately does NOT enable the login item. A package manager installing
# something is not the same as you asking it to start with your session, and
# the app has its own "Start at login" for that.
set -euo pipefail

VERSION="${1:?version required, e.g. 1.10.0}"
TRAY_BIN="${2:?path to the tray binary required}"
CLI_BIN="${3:?path to the cli binary required}"
OUT_DIR="${4:-.}"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCH="$(dpkg --print-architecture)"
PKG="yoyu-companion"
ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT

install -d -m 0755 "$ROOT/DEBIAN"
install -d -m 0755 "$ROOT/usr/bin"
install -d -m 0755 "$ROOT/usr/share/applications"
install -d -m 0755 "$ROOT/usr/share/doc/$PKG"

install -m 0755 "$TRAY_BIN" "$ROOT/usr/bin/yoyu-companion"
install -m 0755 "$CLI_BIN"  "$ROOT/usr/bin/yoyu-companion-cli"
install -m 0644 "$HERE/yoyu-companion.desktop" \
        "$ROOT/usr/share/applications/$PKG.desktop"

# Icons, rendered from the tray's own art.
ICON_TMP="$(mktemp -d)"
python3 "$HERE/make-icons.py" "$ICON_TMP" >/dev/null
for px in 64 128 256; do
  d="$ROOT/usr/share/icons/hicolor/${px}x${px}/apps"
  install -d -m 0755 "$d"
  install -m 0644 "$ICON_TMP/yoyu-companion-${px}.png" "$d/$PKG.png"
done
rm -rf "$ICON_TMP"

cp "$HERE/../../LICENSE" "$ROOT/usr/share/doc/$PKG/copyright" 2>/dev/null || true

# AppStream metadata, so a software centre shows a name and a description
# rather than a bare package id.
install -d -m 0755 "$ROOT/usr/share/metainfo"
install -m 0644 "$HERE/yoyu-companion.metainfo.xml" \
        "$ROOT/usr/share/metainfo/$PKG.metainfo.xml"

# A changelog is required, not decorative: lintian errors without one, and
# apt-listchanges shows it before an upgrade. The detail lives in the GitHub
# releases, so this points there rather than duplicating it badly.
cat > "$ROOT/usr/share/doc/$PKG/changelog" <<CHANGELOG
$PKG ($VERSION) stable; urgency=medium

  * Release $VERSION. Release notes:
    https://github.com/DaveEuson/Yoyu/releases/tag/v$VERSION

 -- Dave Euson <daveeuson@gmail.com>  $(date -R)
CHANGELOG
gzip -9n "$ROOT/usr/share/doc/$PKG/changelog"
chmod 0644 "$ROOT/usr/share/doc/$PKG/changelog.gz"

# Size in KiB, which is what dpkg wants and apt shows before installing.
SIZE="$(du -sk "$ROOT/usr" | cut -f1)"

cat > "$ROOT/DEBIAN/control" <<CONTROL
Package: $PKG
Version: $VERSION
Section: utils
Priority: optional
Architecture: $ARCH
Maintainer: Dave Euson <daveeuson@gmail.com>
Installed-Size: $SIZE
Depends: libc6
Homepage: https://github.com/DaveEuson/Yoyu
Description: Feed Claude Code usage to a Yoyu desk display
 Yoyu is a small ESP32 desk gadget that shows how much of your Claude Code
 usage window is left. This is the companion that reads your usage on this
 computer and pushes it to the board over your network.
 .
 Ships two programs: yoyu-companion, a tray app, and yoyu-companion-cli for
 servers and headless use.
 .
 The binaries are built on Ubuntu 24.04 and need a glibc of that vintage or
 newer. On an older distribution, run the companion from source instead.
CONTROL

mkdir -p "$OUT_DIR"
DEB="$OUT_DIR/${PKG}_${VERSION}_${ARCH}.deb"
dpkg-deb --build --root-owner-group "$ROOT" "$DEB" >/dev/null
echo "$DEB"
