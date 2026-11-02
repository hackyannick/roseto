# Roseto

**PowerPC-Mac-Programme auf Apple Silicon (M1–M4) ausführen – wie das originale Rosetta, nur in die andere Richtung: PowerPC → ARM64.**

Gebaut, um z. B. **MSN Explorer für Mac OS X** gegen einen eigenen MSN-Server zu testen, wenn die iBooks zu alt sind und der M4 zu neu.

```bash
roseto run "MSN Explorer.app"
```

Oder einfach das Programm im Finder auf **Roseto.app** ziehen.

---

## Wie es funktioniert (und warum nicht „nur“ ein CPU-Übersetzer)

Das originale Rosetta (Mac OS X 10.4/10.5 auf Intel) hat *nur die CPU-Befehle* übersetzt. Alles andere – Carbon, Cocoa, der Code Fragment Manager (CFM), 32-Bit-Unterstützung – war im damaligen System noch vorhanden.

Auf einem M4 mit aktuellem macOS fehlt all das: Es gibt keine 32-Bit-Prozesse mehr, kein Carbon, kein CFM und keine PowerPC-Bibliotheken. Ein reiner Befehlsübersetzer hätte für MSN Explorer also nichts, womit er reden könnte.

Roseto hat deshalb zwei Schichten:

```
 ┌──────────────────────────────────────────────────────────┐
 │  MSN Explorer (PowerPC, Carbon/CFM)                      │
 ├──────────────────────────────────────────────────────────┤
 │  Original Mac OS X 10.4 Tiger (PowerPC)                  │  ← Bibliotheks-Schicht
 │  + Roseto-Agent (startet übergebene Programme)           │    (dein eigenes System)
 ├──────────────────────────────────────────────────────────┤
 │  QEMU TCG: JIT-Übersetzer PowerPC → ARM64                │  ← Übersetzungs-Schicht
 │  (übersetzt Codeblöcke zur Laufzeit und cached sie –     │    (Prinzip wie Rosetta)
 │   dasselbe Verfahren wie Rosetta)                        │
 ├──────────────────────────────────────────────────────────┤
 │  roseto: erkennt die Architektur, übergibt Programme,    │  ← Rosetta-artige
 │  setzt Hosts für deinen Server, startet/stoppt alles     │    Bedienung
 ├──────────────────────────────────────────────────────────┤
 │  macOS auf Apple Silicon (M4)                            │
 └──────────────────────────────────────────────────────────┘
```

Was `roseto run` macht:

1. **Erkennt die Architektur** (Mach-O, Universal/Fat, PEF/CFM, Classic). Native ARM64- und Intel-64-Apps öffnet es direkt mit macOS, genau wie Rosetta nur dort übersetzt, wo es nötig ist.
2. **Packt das Programm** auf eine HFS-CD (Resource-Forks bleiben erhalten) und legt sie in den PowerPC-Mac ein, auch während er läuft.
3. Der **Roseto-Agent im PowerPC-Mac** kopiert es nach `~/Applications/Roseto`, trägt deine Server-Hosts in `/etc/hosts` ein und **startet es**.

## Schnellstart (M4-Mac)

### 1. Installieren

```bash
git clone https://github.com/hackyannick/roseto.git
```

```bash
cd roseto && ./install.sh
```

Das installiert QEMU über Homebrew (`brew install qemu`), den Befehl `roseto` und **Roseto.app** in `~/Applications`.

### 2. Mac OS X 10.4 Tiger (PowerPC) als Image bereitstellen

Du brauchst die Installations-DVD von Mac OS X 10.4 (oder 10.5) **für PowerPC**, z. B. die Original-DVD, die bei deinem iBook dabei war. Ein M4 hat kein DVD-Laufwerk, also das Image am besten auf dem iBook erstellen:

- Festplatten-Dienstprogramm → DVD auswählen → „Neues Image“ → Format **„DVD/CD-Master“** → ergibt eine `.cdr`-Datei.

Roseto nimmt `.iso`, `.cdr`, `.toast` und `.dmg` (wird automatisch umgewandelt).

### 3. PowerPC-Mac einrichten

```bash
roseto setup ~/Downloads/MacOSX-Tiger.cdr
```

Im Fenster, das sich öffnet:

1. Sprache wählen, dann **Dienstprogramme → Festplatten-Dienstprogramm**.
2. Die QEMU-Festplatte löschen, Format **Mac OS Extended (Journaled)**.
3. Mac OS X installieren.
4. Zeigt der Mac nach dem Neustart wieder den Installer, das Fenster schließen und:

```bash
roseto start
```

Nach der Ersteinrichtung (Benutzer anlegen) die Gast-Werkzeuge einlegen:

```bash
roseto tools
```

und **im PowerPC-Mac** unter Programme → Dienstprogramme → Terminal einmalig ausführen:

```bash
sh "/Volumes/Roseto Tools/install.sh"
```

### 4. Deinen MSN-Server eintragen

Aus Sicht des PowerPC-Macs ist **`10.0.2.2` immer dein M4** (der Host). Läuft dein MSN-Server auf dem M4, trägst du die Hostnamen, die MSN Explorer anfragt, auf `10.0.2.2` ein:

```bash
roseto hosts add 10.0.2.2 messenger.hotmail.com gateway.messenger.hotmail.com
```

```bash
roseto hosts add 10.0.2.2 login.passport.com loginnet.passport.com nexus.passport.com
```

Läuft der Server auf einem anderen Rechner im LAN, nimm dessen normale IP. Die Einträge gelangen bei jedem `roseto run` automatisch in `/etc/hosts` des PowerPC-Macs; sofort geht es mit `roseto hosts push`. Alles anzeigen bzw. bearbeiten mit `roseto hosts` und `roseto hosts edit`.

> Hinweis: Welche Hostnamen genau gebraucht werden, hängt von deinem Server und der MSN-Explorer-Version ab. Ein Mitschnitt mit Wireshark oder das Server-Log zeigt die angefragten Namen. MSN Explorer kann außerdem nur alte SSL/TLS-Versionen (SSL 3.0 / TLS 1.0) und alte Cipher. Dein Server muss diese für HTTPS-Endpunkte anbieten.

### 5. MSN Explorer starten

```bash
roseto run "MSN Explorer.app"
```

Oder im Finder auf **Roseto.app** ziehen. Installer (`.pkg`), Disk-Images (`.dmg`) und StuffIt-Archive (`.sit`) gehen genauso: Sie werden im PowerPC-Mac geöffnet.

Läuft der PowerPC-Mac noch nicht, startet Roseto ihn. Das Programm öffnet sich dann automatisch nach der Anmeldung.

## Befehle

| Befehl | Zweck |
|---|---|
| `roseto run PROGRAMM…` | PowerPC-Programm/Installer/Archiv im PowerPC-Mac starten (`--copy`: nur kopieren, `--force`: auch native Apps) |
| `roseto info PROGRAMM…` | Architektur anzeigen (PowerPC, Intel, ARM64, Classic …) |
| `roseto setup IMAGE` | PowerPC-Mac einrichten (`--size 30G`, `--reinstall`) |
| `roseto start` / `stop [--force]` | PowerPC-Mac starten / herunterfahren |
| `roseto status` | Zustand aller Profile |
| `roseto tools` | Gast-Werkzeuge-CD einlegen |
| `roseto hosts [add|remove|edit|push]` | Hosts-Einträge für eigene Server |
| `roseto eject` / `log` / `doctor` | CD auswerfen / QEMU-Protokoll / Voraussetzungen prüfen |

Mit `--profile` (bzw. `-p`) wählst du das Gast-System:

| Profil | System | RAM |
|---|---|---|
| `tiger` (Standard) | Mac OS X 10.4 Tiger | 1024 MB |
| `leopard` | Mac OS X 10.5 Leopard | 1536 MB |
| `panther` | Mac OS X 10.3 Panther (ohne launchd: Hosts nur bei Installation bzw. manuell) | 768 MB |
| `os9` | Mac OS 9.2 (für reine Classic-Programme, kein Autostart) | 512 MB |

Programme, die nur für Classic gebaut sind (z. B. eine OS-9-Version von MSN Explorer), erkennt Roseto und schickt sie automatisch ins `os9`-Profil, wenn eines eingerichtet ist.

## Einstellungen

`~/.roseto/config` (oder gleichnamige Umgebungsvariablen):

```sh
ROSETO_PROFILE=tiger            # Standard-Profil
ROSETO_RAM=1024                 # RAM in MB (mac99: max. 2048)
ROSETO_RESOLUTION=1280x1024x32  # Bildschirmauflösung des PowerPC-Macs
ROSETO_TABLET=1                 # USB-Tablet statt Maus (Mauszeiger ohne "Einfangen")
ROSETO_VERBOSE_BOOT=1           # Mac OS X im ausführlichen Modus starten
ROSETO_QEMU_EXTRA="-smp 1"      # zusätzliche QEMU-Optionen
```

Die Daten liegen in `~/.roseto/`: `vms/<profil>/disk.qcow2` ist die Festplatte, `hosts` die Hosts-Einträge.

## Fehlersuche

- **Nichts startet automatisch:** Sind die Gast-Werkzeuge installiert (`roseto tools`)? Das Protokoll im PowerPC-Mac steht unter `~/Library/Application Support/Roseto/agent.log`.
- **QEMU startet nicht:** `roseto log` und `roseto doctor`.
- **Mauszeiger hängt/springt:** In der QEMU-Fensterleiste die Maus freigeben (Ctrl+Alt+G) oder `ROSETO_TABLET=1` ausprobieren.
- **Server nicht erreichbar:** Im PowerPC-Mac im Terminal `ping 10.0.2.2` bzw. `cat /etc/hosts` prüfen. Ping kann in QEMUs Benutzer-Netzwerk ausfallen, obwohl TCP funktioniert; besser mit `curl http://10.0.2.2:PORT/` testen.

## Entwicklung

```bash
./tests/run-tests.sh
```

Die Tests prüfen Syntax/Shellcheck, die Architektur-Erkennung (künstliche Mach-O-, Fat- und PEF-Header), die QEMU-Befehlszeile und, falls `qemu-system-ppc` installiert ist, einen echten Durchlauf: PowerPC-Maschine booten, Transfer-CD im laufenden Betrieb einlegen, beenden. Außerdem simulieren sie die Hosts-Verwaltung des Gastes.

`bin/roseto` muss mit dem macOS-eigenen **bash 3.2** laufen und die Gast-Skripte mit dem `/bin/sh` von Mac OS X 10.3–10.5.

## Aufbau

```
bin/roseto                 Hauptbefehl (Host, macOS)
macos/Roseto.applescript   Finder-Droplet
macos/build-app.sh         baut Roseto.app
guest/                     Werkzeuge für den PowerPC-Mac (Agent, Hosts-Dienst, Installer)
install.sh                 Installation auf dem M4
tests/run-tests.sh         Tests
```

## Rechtliches

Roseto enthält kein Apple-Betriebssystem und keine Microsoft-Software. Verwende dein eigenes Mac-OS-X-Installationsmedium (z. B. das deines iBooks) und deine eigene MSN-Explorer-Kopie.
