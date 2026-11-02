#!/bin/sh
#
# Roseto-Agent – läuft IM PowerPC-Mac (Mac OS X 10.3 – 10.5) im Hintergrund
# der angemeldeten Sitzung. Er wartet auf eingelegte Roseto-CDs, kopiert die
# darauf übergebenen Programme nach ~/Applications/Roseto und startet sie.
#
# Bewusst schlichtes /bin/sh, damit es auch mit der Shell von 10.3/10.4 läuft.

STATE="$HOME/Library/Application Support/Roseto"
APPS="$HOME/Applications/Roseto"
LOG="$STATE/agent.log"
DONE="$STATE/erledigt.txt"
PIDF="$STATE/agent.pid"
SHARED=/Users/Shared/Roseto

mkdir -p "$STATE" "$APPS"
touch "$DONE"

# nur eine Instanz
if [ -f "$PIDF" ]; then
  oldpid=`cat "$PIDF" 2>/dev/null`
  if [ -n "$oldpid" ] && kill -0 "$oldpid" 2>/dev/null; then
    exit 0
  fi
fi
echo $$ > "$PIDF"

log() {
  echo "`date '+%Y-%m-%d %H:%M:%S'` $*" >> "$LOG"
}

handle_job() {
  vol="$1"
  file="$vol/roseto-autorun.txt"
  job=`sed -n 's/^JOB=//p' "$file" | head -n 1`
  action=`sed -n 's/^ACTION=//p' "$file" | head -n 1`
  [ -n "$job" ] || return 0
  if grep -x -F "$job" "$DONE" >/dev/null 2>&1; then
    return 0
  fi
  echo "$job" >> "$DONE"
  log "Auftrag $job ($action) von $vol"

  # 1. alles von der CD kopieren (die CD wird danach ausgeworfen)
  sed -n 's/^TARGET=//p' "$file" > "$STATE/targets.txt"
  while read target; do
    [ -n "$target" ] || continue
    src="$vol/payload/$target"
    dst="$APPS/$target"
    if [ ! -e "$src" ]; then
      log "fehlt auf der CD: $target"
      continue
    fi
    rm -rf "$dst"
    if ditto "$src" "$dst" 2>>"$LOG"; then
      log "kopiert: $target"
    else
      cp -Rp "$src" "$dst" 2>>"$LOG" && log "kopiert (cp): $target"
    fi
  done < "$STATE/targets.txt"

  # 2. Hosts-Einträge sichern (der Hosts-Dienst liest sie auch von dort) und
  #    kurz warten, bis sie aktiv sind – damit z. B. MSN Explorer gleich beim
  #    ersten Start deinen Server findet
  if [ -f "$vol/roseto-hosts.txt" ] && [ -d "$SHARED" ]; then
    cp "$vol/roseto-hosts.txt" "$SHARED/roseto-hosts.txt.tmp" 2>/dev/null &&
      mv -f "$SHARED/roseto-hosts.txt.tmp" "$SHARED/roseto-hosts.txt"
    first=`grep '[^[:space:]]' "$vol/roseto-hosts.txt" | head -n 1 | awk '{print $1, $2}'`
    if [ -n "$first" ]; then
      i=0
      while [ "$i" -lt 15 ]; do
        awk '{print $1, $2}' /etc/hosts | grep -x -F "$first" >/dev/null 2>&1 && break
        sleep 1
        i=`expr "$i" + 1`
      done
    fi
  fi

  # 3. CD auswerfen, damit Roseto die nächste einlegen kann
  hdiutil eject "$vol" >/dev/null 2>&1 || disktool -e "$vol" >/dev/null 2>&1

  # 4. starten
  if [ "$action" = "copy" ]; then
    open "$APPS"
    return 0
  fi
  while read target; do
    [ -n "$target" ] || continue
    if [ -e "$APPS/$target" ]; then
      log "starte: $target"
      open "$APPS/$target" 2>>"$LOG"
    fi
  done < "$STATE/targets.txt"
}

log "Agent gestartet (PID $$)"
while :; do
  for f in /Volumes/*/roseto-autorun.txt; do
    [ -f "$f" ] || continue
    handle_job "`dirname "$f"`"
  done
  sleep 3
done
