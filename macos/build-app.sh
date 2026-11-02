#!/bin/bash
#
# Baut Roseto.app (Finder-Droplet) – nur unter macOS.
#   ./macos/build-app.sh [ZIELORDNER]      (Standard: ./build)

set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
OUT="${1:-$ROOT/build}"
APP="$OUT/Roseto.app"

[ "$(uname -s)" = Darwin ] || { echo "build-app.sh: nur unter macOS möglich." >&2; exit 1; }

VERSION="$(sed -n 's/^ROSETO_VERSION="\(.*\)"/\1/p' "$ROOT/bin/roseto")"

mkdir -p "$OUT"
rm -rf "$APP"
osacompile -o "$APP" "$HERE/Roseto.applescript"

RES="$APP/Contents/Resources/roseto"
mkdir -p "$RES"
cp -R "$ROOT/bin" "$ROOT/guest" "$RES/"
chmod 755 "$RES/bin/roseto"

PB=/usr/libexec/PlistBuddy
PL="$APP/Contents/Info.plist"
$PB -c "Add :CFBundleIdentifier string de.roseto.app" "$PL" 2>/dev/null ||
  $PB -c "Set :CFBundleIdentifier de.roseto.app" "$PL"
$PB -c "Set :CFBundleName Roseto" "$PL" 2>/dev/null || $PB -c "Add :CFBundleName string Roseto" "$PL"
$PB -c "Add :CFBundleShortVersionString string $VERSION" "$PL" 2>/dev/null ||
  $PB -c "Set :CFBundleShortVersionString $VERSION" "$PL"

# Nach dem Ändern der Ressourcen neu (ad-hoc) signieren, sonst meldet macOS
# auf Apple Silicon die App als "beschädigt".
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

echo "Fertig: $APP"
