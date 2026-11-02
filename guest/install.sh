#!/bin/sh
#
# Roseto-Gast-Werkzeuge installieren. Im PowerPC-Mac im Terminal ausführen:
#
#     sh "/Volumes/Roseto Tools/install.sh"
#
# (als normaler Benutzer – das Administrator-Passwort wird abgefragt)

SRC=`dirname "$0"`
ME=`id -un`

if [ "$ME" = "root" ]; then
  echo "Bitte NICHT mit sudo starten, sondern als normaler Benutzer:"
  echo "    sh \"$SRC/install.sh\""
  exit 1
fi

echo "Roseto: installiere die Gast-Werkzeuge."
echo "Bitte gleich das Administrator-Passwort dieses Macs eingeben."
sudo /bin/sh "$SRC/install-root.sh" "$SRC" || {
  echo "Installation abgebrochen."
  exit 1
}

# Agent als Anmeldeobjekt dieses Benutzers eintragen (nur einmal)
if defaults read loginwindow AutoLaunchedApplicationDictionary 2>/dev/null | grep RosetoAgent >/dev/null; then
  :
else
  defaults write loginwindow AutoLaunchedApplicationDictionary -array-add \
    '{ Hide = 1; Path = "/Library/Roseto/RosetoAgent.app"; }'
fi

# und gleich jetzt starten
open /Library/Roseto/RosetoAgent.app

echo ""
echo "Fertig! Roseto startet ab jetzt übergebene Programme automatisch."
echo "Kopierte Programme liegen in: $HOME/Applications/Roseto"
