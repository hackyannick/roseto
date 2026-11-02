#!/bin/sh
#
# Teil der Gast-Installation, der Administratorrechte braucht.
# Wird von install.sh über sudo aufgerufen.

SRC="$1"
DEST=/Library/Roseto
PLIST=/Library/LaunchDaemons/de.roseto.hosts.plist

if [ -z "$SRC" ] || [ ! -f "$SRC/roseto-agent.sh" ]; then
  echo "install-root.sh: Quelle nicht gefunden"
  exit 1
fi

mkdir -p "$DEST" || exit 1
cp "$SRC/roseto-agent.sh" "$SRC/roseto-hosts.sh" "$DEST/" || exit 1
chmod 755 "$DEST/roseto-agent.sh" "$DEST/roseto-hosts.sh"

# Kleines Anmelde-Programm, das den Agenten in der Benutzersitzung startet.
# (So darf der Agent mit "open" Programme im Fenster des Benutzers öffnen.)
rm -rf "$DEST/RosetoAgent.app"
osacompile -o "$DEST/RosetoAgent.app" \
  -e 'do shell script "/bin/sh /Library/Roseto/roseto-agent.sh > /dev/null 2>&1 &"' || {
  echo "osacompile fehlgeschlagen"
  exit 1
}
chmod -R a+rX "$DEST"

# Ablage, über die der Agent (ohne Adminrechte) Hosts-Einträge weiterreicht
mkdir -p /Users/Shared/Roseto
chmod 1777 /Users/Shared/Roseto

# Hosts-Dienst (benötigt launchd, also ab Mac OS X 10.4)
if [ -x /bin/launchctl ]; then
  cp "$SRC/de.roseto.hosts.plist" "$PLIST" || exit 1
  chown root:wheel "$PLIST"
  chmod 644 "$PLIST"
  launchctl unload "$PLIST" >/dev/null 2>&1
  launchctl load -w "$PLIST"
else
  echo "Hinweis: Mac OS X 10.3 hat kein launchd. Hosts-Einträge werden jetzt einmal"
  echo "übernommen; später bei Bedarf erneut mit:"
  echo "    sudo sh /Library/Roseto/roseto-hosts.sh"
fi

# Hosts sofort übernehmen
/bin/sh "$DEST/roseto-hosts.sh"
exit 0
