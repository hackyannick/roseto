#!/bin/bash
#
# Roseto installieren (macOS, Apple Silicon):
#   ./install.sh
#
# - installiert QEMU über Homebrew (falls nötig)
# - verlinkt den Befehl "roseto" nach $(brew --prefix)/bin bzw. ~/bin
# - baut Roseto.app nach ~/Applications

set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"

if [ "$(uname -s)" != Darwin ]; then
  echo "Roseto ist für macOS gedacht. Unter $(uname -s) kannst du bin/roseto direkt benutzen." >&2
  exit 1
fi

if ! command -v qemu-system-ppc >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    echo "==> Installiere QEMU (enthält den PowerPC→ARM64-Übersetzer) ..."
    brew install qemu
  else
    echo "Homebrew fehlt. Bitte zuerst installieren: https://brew.sh – danach ./install.sh erneut starten." >&2
    exit 1
  fi
fi

if command -v brew >/dev/null 2>&1 && [ -w "$(brew --prefix)/bin" ]; then
  BIN="$(brew --prefix)/bin"
else
  BIN="$HOME/bin"
  mkdir -p "$BIN"
fi
ln -sf "$ROOT/bin/roseto" "$BIN/roseto"
echo "==> Befehl installiert: $BIN/roseto"
case ":$PATH:" in *":$BIN:"*) ;; *) echo "    (Hinweis: $BIN ist nicht in deinem PATH)";; esac

mkdir -p "$HOME/Applications"
"$ROOT/macos/build-app.sh" "$HOME/Applications"

echo ""
"$ROOT/bin/roseto" doctor || true
