#!/bin/sh
#
# Roseto-Hosts – läuft IM PowerPC-Mac als root (LaunchDaemon). Übernimmt die
# Hosts-Einträge von der zuletzt eingelegten Roseto-CD in einen eigenen,
# markierten Block in /etc/hosts. Alles außerhalb des Blocks bleibt unverändert.

BEGIN_MARK="# >>> roseto (automatisch verwaltet)"
END_MARK="# <<< roseto"
HOSTS=/etc/hosts

# Quelle: die neueste Hosts-Datei – von einer eingelegten Roseto-CD oder die
# vom Agenten gesicherte Kopie
src=`ls -t /Volumes/*/roseto-hosts.txt /Users/Shared/Roseto/roseto-hosts.txt 2>/dev/null | head -n 1`
[ -n "$src" ] && [ -f "$src" ] || exit 0

tmp=/tmp/roseto-hosts.$$
sed "/^# >>> roseto/,/^# <<< roseto/d" "$HOSTS" > "$tmp" || exit 1
if grep '[^[:space:]]' "$src" >/dev/null 2>&1; then
  {
    echo "$BEGIN_MARK"
    grep '^[[:space:]]*[0-9A-Fa-f:.][0-9A-Fa-f:.]*[[:space:]]' "$src"
    echo "$END_MARK"
  } >> "$tmp"
fi

if cmp -s "$tmp" "$HOSTS"; then
  rm -f "$tmp"
  exit 0
fi

cat "$tmp" > "$HOSTS"
rm -f "$tmp"

# DNS-Cache leeren (10.4: lookupd, 10.5: dscacheutil)
lookupd -flushcache >/dev/null 2>&1
dscacheutil -flushcache >/dev/null 2>&1
logger -t roseto "Hosts-Einträge aus $src übernommen" 2>/dev/null
exit 0
