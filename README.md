# Raspberry Pi OpenRCT2

Dieses Projekt baut ein Yocto-System fuer den Raspberry Pi 4 (64 Bit) mit Qt 6 und OpenRCT2. Die Anleitungen sind bewusst in einfacher Sprache geschrieben.

## Inhalt

- Ein Yocto-Image mit Qt, OpenRCT2, SSH und optionalen Netzwerkwerkzeugen
- Rezepte fuer OpenRCT2, die Originalspieldaten und den Server-Start
- Ein Skript zum Vorbereiten eines Builds mit festgelegten Layer-Versionen
- Eine Anleitung fuer das Qt-SDK und Qt Creator
- Ein kleines qmake-Projekt zum Testen der Cross-Compile-Toolchain

## Was nicht im Repo liegt

Die originalen RCT1-/RCT2-Spieldateien sind urheberrechtlich geschuetzt. Sie muessen aus einer eigenen lizenzierten Installation stammen. Das Skript `scripts/prepare-build-assets.sh` erstellt daraus lokale Build-Dateien. Diese grossen Archive sind in `.gitignore` eingetragen und sollen nicht nach GitHub geladen werden.

Private Schluessel, WireGuard-Profile und NAS-Passwoerter gehoeren ebenfalls nicht in das Repo. Die Firstboot-Keydatei enthaelt nur Kommentare. Das Image startet mit Passwortanmeldung; SSH-Schluessel koennen nach dem ersten Boot eingerichtet werden.

## Schnellstart

Voraussetzungen: Linux x86_64, Git, curl, jq, Python 3, tar/gzip, make und ausreichend freier Plattenplatz. Der erste Build laedt Yocto-Quellen herunter und benoetigt deutlich mehr Speicher als das fertige Image.

```sh
git clone <GitHub-URL> rpi-openrct2
cd rpi-openrct2
./scripts/setup-build.sh
./scripts/prepare-build-assets.sh /pfad/zu/deiner/OpenRCT_Sys-Installation
cd build
bitbake rpi-openrct2
```

Der Ordner `OpenRCT_Sys` muss `RCT/` und `RCT2/` enthalten. Das Skript prueft insbesondere `RCT/Data/CSG1.DAT` und `RCT2/Data/g1.dat`. Es packt nur die benoetigten Spielressourcen; Spielstaende kommen nicht ins Image.

Das Image erscheint unter `build/tmp/deploy/images/raspberrypi4-64/`. Das passende `*.wic.bz2`-Image mit einem SD-Kartenprogramm auf eine Karte schreiben. Achtung: Das Schreiben loescht die ausgewaehlte SD-Karte.

## Erster Start

Verbinde Bildschirm und Tastatur oder eine serielle Konsole. Beim ersten Start fragt die Einrichtung nach Benutzername und Passwort. `openrct2` ist der Standardbenutzer und passt zum Serverdienst; wenn du einen anderen Namen waehlst, musst du auch den systemd-Dienst anpassen. Danach kannst du dich per SSH anmelden.

Optional kannst du nach `scripts/setup-build.sh` deinen SSH-Public-Key in `build/local-assets/authorized_keys.example` eintragen. Diese Datei liegt im ignorierten Build-Ordner und wird nicht mit Git geteilt. Nur den Public Key eintragen, niemals den privaten Schluessel.

Die Beispielkonfiguration erlaubt Passwort-SSH und ist fuer ein vertrauenswuerdiges LAN/VPN gedacht. Oeffne SSH nicht direkt ins Internet, bevor du die Anmeldung abgesichert hast. WireGuard-Schluessel und Tunnelprofile muessen separat und privat eingerichtet werden.

## Qt und qmake

Die installierte Yocto-SDK-Umgebung und die Einstellungen fuer Qt Creator stehen in [`layers/meta-custom/docs/qtcreator-sdk.md`](layers/meta-custom/docs/qtcreator-sdk.md). Das Projekt [`qt-qmake-smoke`](layers/meta-custom/examples/qt-qmake-smoke/README.md) wurde fuer AArch64 gebaut und auf dem Pi ausgefuehrt.

## OpenRCT2 aktualisieren

```sh
layers/meta-custom/recipes-games/openrct2/update-openrct2.sh --check
```

Das Skript ohne Optionen baut bei einer neuen stabilen Version die benoetigten Pakete, installiert sie auf dem Pi und startet ihn neu. Vorher bitte `--help` lesen. Mit `--pi benutzer@host` laesst sich das SSH-Ziel aendern.

Eine allgemeine Anleitung zum Installieren einzelner IPK-Pakete ohne Neu-Flashen steht in [`docs/PACKAGE-UPDATES.md`](docs/PACKAGE-UPDATES.md).

## Layer-Versionen

`sources.lock` enthaelt die getesteten Git-Commits von BitBake und allen benoetigten Yocto-Layern. Aenderungen an diesen Pins sollten zusammen getestet werden. Details zu Setup, Spieldaten, SDK und Flashen stehen in [`docs/BUILD.md`](docs/BUILD.md).
