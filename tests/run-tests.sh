#!/bin/bash
#
# Roseto-Tests:  ./tests/run-tests.sh
#
# 1. Syntax-/Lint-Prüfung aller Skripte (shellcheck, falls vorhanden)
# 2. Architektur-Erkennung mit künstlichen Mach-O-/Fat-/PEF-Headern
# 3. QEMU-Befehlszeile (Trockenlauf)
# 4. Integrationstest mit echtem qemu-system-ppc (falls installiert):
#    PowerPC-Mac booten (ohne System), CD im laufenden Betrieb wechseln, beenden

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
R="$ROOT/bin/roseto"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/roseto-test.XXXXXX")"
export ROSETO_HOME="$WORK/home"
export ROSETO_DISPLAY=none
unset ROSETO_PROFILE ROSETO_RAM ROSETO_QEMU_EXTRA

PASS=0
FAIL=0
ok()   { PASS=$((PASS + 1)); printf '  ok    %s\n' "$1"; }
bad()  { FAIL=$((FAIL + 1)); printf '  FEHLT %s\n' "$1"; [ -n "${2:-}" ] && printf '        %s\n' "$2"; }
expect_eq() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "erwartet '$3', erhalten '$2'"; fi; }
expect_has() { case $2 in *"$3"*) ok "$1" ;; *) bad "$1" "'$3' fehlt in: $2" ;; esac; }

cleanup() {
  ROSETO_HOME="$ROSETO_HOME" "$R" stop --force >/dev/null 2>&1
  rm -rf "$WORK"
}
trap cleanup EXIT

echo "== Syntax"
for f in "$R" "$ROOT"/install.sh "$ROOT"/macos/build-app.sh "$ROOT"/tests/run-tests.sh; do
  if bash -n "$f"; then ok "bash -n $(basename "$f")"; else bad "bash -n $f"; fi
done
for f in "$ROOT"/guest/*.sh; do
  if sh -n "$f"; then ok "sh -n guest/$(basename "$f")"; else bad "sh -n $f"; fi
done
if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck -s bash -e SC2155,SC2317 "$R" "$ROOT"/install.sh "$ROOT"/macos/build-app.sh; then
    ok "shellcheck (bash)"
  else bad "shellcheck (bash)"; fi
  if shellcheck -s sh -e SC2006,SC2162,SC2129,SC2003,SC2012 "$ROOT"/guest/*.sh; then
    ok "shellcheck (Gast, sh)"
  else bad "shellcheck (Gast, sh)"; fi
fi
# Bash-4-Features dürfen nicht vorkommen (macOS hat bash 3.2)
if grep -nE 'declare -A|mapfile|readarray|\$\{[a-zA-Z_]+(\^|,)|&>>|\|&' "$R"; then
  bad "keine Bash-4-Features in bin/roseto"
else ok "keine Bash-4-Features in bin/roseto"; fi

echo "== Architektur-Erkennung"
F="$WORK/fixtures"
mkdir -p "$F"
pad() { head -c 64 /dev/zero; }
{ printf '\xfe\xed\xfa\xce\x00\x00\x00\x12'; pad; } > "$F/ppc-thin"
{ printf '\xcf\xfa\xed\xfe\x0c\x00\x00\x01'; pad; } > "$F/arm64-thin"
{ printf '\xcf\xfa\xed\xfe\x07\x00\x00\x01'; pad; } > "$F/x86_64-thin"
{ printf '\xce\xfa\xed\xfe\x07\x00\x00\x00'; pad; } > "$F/i386-thin"
# Universal: ppc + i386
{ printf '\xca\xfe\xba\xbe\x00\x00\x00\x02'
  printf '\x00\x00\x00\x12\x00\x00\x00\x00\x00\x00\x10\x00\x00\x00\x10\x00\x00\x00\x00\x0c'
  printf '\x00\x00\x00\x07\x00\x00\x00\x03\x00\x00\x20\x00\x00\x00\x10\x00\x00\x00\x00\x0c'
  pad; } > "$F/universal-ppc-i386"
# Universal: x86_64 + arm64
{ printf '\xca\xfe\xba\xbe\x00\x00\x00\x02'
  printf '\x01\x00\x00\x07\x00\x00\x00\x03\x00\x00\x10\x00\x00\x00\x10\x00\x00\x00\x00\x0c'
  printf '\x01\x00\x00\x0c\x00\x00\x00\x00\x00\x00\x20\x00\x00\x00\x10\x00\x00\x00\x00\x0c'
  pad; } > "$F/universal-x86_64-arm64"
# Java-Klasse (cafebabe, aber keine Fat-Binary)
{ printf '\xca\xfe\xba\xbe\x00\x00\x00\x34'; pad; } > "$F/Foo.class"
# PEF/CFM
{ printf 'Joy!peffpwpc'; pad; printf 'CarbonLib'; pad; } > "$F/pef-carbon"
{ printf 'Joy!peffpwpc'; pad; printf 'InterfaceLib'; pad; } > "$F/pef-classic"
printf 'hallo' > "$F/text.txt"
: > "$F/MSN Installer.dmg"
# App-Bundle mit PowerPC-Programm
B="$F/MSN Explorer.app"
mkdir -p "$B/Contents/MacOS"
cat > "$B/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
	<key>CFBundleName</key>
	<string>MSN Explorer</string>
	<key>CFBundleExecutable</key>
	<string>MSN Explorer</string>
</dict>
</plist>
EOF
cp "$F/pef-carbon" "$B/Contents/MacOS/MSN Explorer"
B2="$F/Native.app"
mkdir -p "$B2/Contents/MacOS"
cp "$F/arm64-thin" "$B2/Contents/MacOS/Native"   # ohne Info.plist -> Fallback

check() { expect_eq "$1" "$("$R" info --short "$F/$1")" "$2"; }
check ppc-thin                "ppc ppc"
check arm64-thin              "native arm64"
check x86_64-thin             "rosetta2 x86_64"
check i386-thin               "i386 i386"
check universal-ppc-i386      "ppc ppc i386"
check universal-x86_64-arm64  "native x86_64 arm64"
check Foo.class               "unknown -"
check pef-carbon              "ppc pef-carbon"
check pef-classic             "classic pef-classic"
check text.txt                "unknown -"
check "MSN Installer.dmg"     "archive -"
check "MSN Explorer.app"      "ppc pef-carbon"
check "Native.app"            "native arm64"
expect_has "info (lang)" "$("$R" info "$B")" "PowerPC Mac OS X – wird von Roseto übersetzt"

echo "== Hosts"
"$R" hosts add 10.0.2.2 messenger.hotmail.com login.passport.com >/dev/null 2>&1
"$R" hosts add 192.168.1.50 explorer.msn.com >/dev/null 2>&1
H="$("$R" hosts)"
expect_has "hosts add" "$H" "10.0.2.2   messenger.hotmail.com login.passport.com"
"$R" hosts remove login.passport.com >/dev/null 2>&1
"$R" hosts remove explorer.msn.com >/dev/null 2>&1
H="$("$R" hosts)"
expect_eq "hosts remove" "$H" "10.0.2.2   messenger.hotmail.com"
if "$R" hosts add 'evil;rm' x >/dev/null 2>&1; then bad "ungültige IP abgelehnt"; else ok "ungültige IP abgelehnt"; fi

echo "== Trockenlauf"
mkdir -p "$ROSETO_HOME/vms/tiger" && : > "$ROSETO_HOME/vms/tiger/disk.qcow2"
C="$("$R" --dry-run start)"
expect_has "start: mac99"    "$C" "-M mac99,via=pmu"
expect_has "start: RAM"      "$C" "-m 1024"
expect_has "start: Netzwerk" "$C" "sungem,netdev=net0"
expect_has "start: Boot HD"  "$C" "-boot c"
C="$("$R" --profile os9 --dry-run setup "$F/text.txt" 2>&1)"
expect_has "os9: vga-ndrv"   "$C" "vga-ndrv?=true"
expect_has "os9: Boot CD"    "$C" "-boot d"
C="$("$R" --dry-run run "$F/arm64-thin" 2>&1)"
expect_has "native App -> direkt öffnen" "$C" "läuft ohne Roseto"
C="$("$R" --dry-run run "$B" 2>&1)"
expect_has "PowerPC-App -> VM mit Disk" "$C" "disc-"
mkdir -p "$WORK/k,omma"; cp -R "$B" "$WORK/k,omma/"
C="$(ROSETO_HOME="$WORK/k,omma/home" "$R" --dry-run setup "$F/text.txt" 2>&1)"
expect_has "Kommas in Pfaden escaped" "$C" "k,,omma"

echo "== Integration (echtes QEMU)"
if ! command -v qemu-system-ppc >/dev/null 2>&1 || ! command -v qemu-img >/dev/null 2>&1; then
  echo "  (übersprungen: qemu-system-ppc nicht installiert)"
else
  rm -rf "$ROSETO_HOME/vms"
  : > "$WORK/leer.iso"
  "$R" setup --size 64M "$WORK/leer.iso" >/dev/null 2>&1
  if "$R" status | grep -q '^tiger: läuft'; then ok "setup bootet PowerPC-Maschine"; else bad "setup bootet PowerPC-Maschine" "$(cat "$ROSETO_HOME/vms/tiger/qemu.log" 2>/dev/null)"; fi
  "$R" run "$B" >/dev/null 2>&1
  ISO="$(ls "$ROSETO_HOME"/vms/tiger/disc-*.iso 2>/dev/null)"
  if [ -n "$ISO" ] && [ "$(echo "$ISO" | wc -l)" -eq 1 ]; then ok "Transfer-Disk erstellt, alte aufgeräumt"; else bad "Transfer-Disk" "$ISO"; fi
  # Inhalt der Disk prüfen
  if command -v isoinfo >/dev/null 2>&1; then
    L="$(isoinfo -R -f -i "$ISO")"
    expect_has "Disk: Auftrag" "$L" "/roseto-autorun.txt"
    expect_has "Disk: Hosts"   "$L" "/roseto-hosts.txt"
    expect_has "Disk: App"     "$L" "/payload/MSN Explorer.app/Contents/MacOS/MSN Explorer"
    A="$(isoinfo -R -i "$ISO" -x /roseto-autorun.txt)"
    expect_has "Auftrag: TARGET" "$A" "TARGET=MSN Explorer.app"
    expect_has "Auftrag: ACTION" "$A" "ACTION=open"
  fi
  B_INFO="$(cd "$ROSETO_HOME/vms/tiger" && { printf 'info block ide1-cd0\n'; sleep 1; } | nc -U -w 2 monitor.sock 2>/dev/null)"
  expect_has "Disk im laufenden Betrieb eingelegt" "$B_INFO" "$(basename "$ISO")"
  "$R" stop --force >/dev/null 2>&1
  if "$R" status | grep -q '^tiger: eingerichtet, gestoppt'; then ok "stop --force"; else bad "stop --force"; fi
fi

echo "== Gast-Skripte (simuliert)"
G="$WORK/guest"
mkdir -p "$G/etc"
printf '127.0.0.1 localhost\n# >>> roseto (automatisch verwaltet)\n1.2.3.4 alt.example\n# <<< roseto\n' > "$G/etc/hosts"
mkdir -p "$G/Volumes/Roseto"
printf '10.0.2.2   messenger.hotmail.com\n' > "$G/Volumes/Roseto/roseto-hosts.txt"
sed -e "s#/etc/hosts#$G/etc/hosts#; s#HOSTS=/etc/hosts#HOSTS=$G/etc/hosts#" \
    -e "s#/Volumes/#$G/Volumes/#g; s#/Users/Shared/Roseto#$G/shared#g" \
    "$ROOT/guest/roseto-hosts.sh" > "$G/hosts.sh"
sh "$G/hosts.sh"
HG="$(cat "$G/etc/hosts")"
expect_has "Gast-Hosts: neuer Eintrag" "$HG" "10.0.2.2   messenger.hotmail.com"
case $HG in *alt.example*) bad "Gast-Hosts: alter Block ersetzt" ;; *) ok "Gast-Hosts: alter Block ersetzt" ;; esac
expect_has "Gast-Hosts: Rest bleibt" "$HG" "127.0.0.1 localhost"
sh "$G/hosts.sh"
expect_eq "Gast-Hosts: idempotent" "$(grep -c roseto "$G/etc/hosts")" "2"

echo ""
echo "Ergebnis: $PASS bestanden, $FAIL fehlgeschlagen"
[ "$FAIL" -eq 0 ]
