# Build- und Installationsanleitung

## Build-PC vorbereiten

Verwende einen aktuellen Linux-x86_64-Rechner. Fuer Debian/Ubuntu/Zorin sind mindestens diese ueblichen Yocto-Werkzeuge noetig:

```sh
sudo apt update
sudo apt install build-essential chrpath cpio debianutils diffstat file gawk git iputils-ping jq libacl1 liblz4-tool locales python3 python3-git python3-jinja2 python3-pexpect python3-pip python3-subunit socat texinfo unzip wget xz-utils zstd curl
```

Yocto-Versionen koennen weitere Hostpakete benoetigen. Wenn BitBake beim Start ein fehlendes Werkzeug meldet, dieses Paket ebenfalls installieren. Baue nicht als root. Plane fuer Downloads und Build-Ausgabe reichlich Platz ein; ein komplettes Qt-SDK ist deutlich groesser als das Image.

## 1. Yocto-Layer einrichten

Im Repo-Stamm ausfuehren:

```sh
./scripts/setup-build.sh
```

Das Skript klont die benoetigten Repositories auf die in `sources.lock` gespeicherten Commit-IDs. Wenn ein Layer bereits existiert und lokale Aenderungen enthaelt, bricht es ab, statt diese zu ueberschreiben.

## 2. Eigene RCT-Spieldaten vorbereiten

Verwende eine eigene lizenzierte Installation. Das Quellverzeichnis muss mindestens diese Dateien enthalten:

```text
OpenRCT_Sys/
  RCT/Data/CSG1.DAT
  RCT2/Data/g1.dat
```

Weitere benoetigte `Data`, `ObjData`, `Scenarios` und `Tracks` werden mit eingepackt.

```sh
./scripts/prepare-build-assets.sh /pfad/zu/OpenRCT_Sys
```

Das Skript erzeugt die lokalen Archive im OpenRCT2-Layer. Es laedt ausserdem die offiziellen OpenRCT2-Objekte aus dem AppImage der im Rezept eingetragenen Version und vergleicht dessen SHA-256 mit der offiziellen Release-Pruefsumme. Bei Fehlern bricht es ab.

Die Archive sind gross und enthalten lizenzierte Inhalte. Sie stehen absichtlich in `.gitignore`; nicht in GitHub hochladen.

## 3. Image bauen

```sh
cd build
bitbake rpi-openrct2
```

Das kann beim ersten Mal laenger dauern und viele Gigabyte Downloads/Build-Ausgabe erzeugen. Das fertige Image liegt in `build/tmp/deploy/images/raspberrypi4-64/`.

Ein Qt-Entwicklungs-SDK fuer den Build-PC wird separat gebaut:

```sh
bitbake meta-toolchain-qt6
```

Den Installer findest du danach in `build/tmp/deploy/sdk/`. Die Installation und Qt-Creator-Konfiguration ist in `layers/meta-custom/docs/qtcreator-sdk.md` beschrieben.

## 4. Image auf die SD-Karte schreiben

Waehle eine `.wic.bz2`-Datei in `build/tmp/deploy/images/raspberrypi4-64/` und schreibe sie mit einem SD-Kartenprogramm auf die Raspberry-Pi-Karte. Vorher das Zielgeraet sorgfaeltig kontrollieren: Beim Schreiben wird dessen bisheriger Inhalt geloescht.

## Erste Anmeldung

Beim ersten Start zeigt die lokale Systemkonsole die Benutzer-Einrichtung. Waehle dort Benutzername und Passwort. Danach ist SSH verfuegbar. Das Image bringt absichtlich keinen privaten oder persoenlichen SSH-Schluessel mit.

`openrct2` ist der Standardbenutzer und wird auch vom OpenRCT2-Serverdienst verwendet. Wenn du bei der Einrichtung einen anderen Namen waehlst, musst du den Benutzer in `rpi-openrct2-runtime/files/openrct2.service` passend aendern.

Optional kannst du nach `scripts/setup-build.sh` deinen oeffentlichen SSH-Schluessel in `build/local-assets/authorized_keys.example` eintragen. Das Build-Verzeichnis ist in `.gitignore` ausgeschlossen. Private Schluessel gehoeren niemals in dieses Repo.

## Einstellungen

Die projektweiten Einstellungen liegen in `conf/rpi-openrct2.conf`. Dazu gehoeren Zielgeraet, Qt-Edition, akzeptierte Lizenzkennzeichnung und eine moderate Build-Parallelitaet. Die ausgecheckten Upstream-Revisionen stehen in `sources.lock`.

Die Build-Ausgabe `build/`, heruntergeladene Quellen, SDKs und Spieldaten werden nicht versioniert. Sie sind gross und lassen sich aus den gepinnten Quellen bzw. der eigenen RCT-Installation neu erzeugen.
