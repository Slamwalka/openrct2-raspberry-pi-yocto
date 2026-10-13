# Build und Installation

Diese Anleitung gilt fuer den Build-PC. Sie beschreibt den Yocto-Build und das Schreiben des Images auf eine SD-Karte.

## Voraussetzungen

- Referenzgeraet: Raspberry Pi 4 Model B mit 8 GB RAM und dem offiziellen Raspberry Pi Touch Display am DSI-Anschluss
- Linux auf x86_64, kein Build als `root`
- Git, Internetzugang und mindestens etwa 100 GB freien Speicher fuer Quellen, Downloads und Build-Ausgabe
- Eine eigene lizenzierte RCT1-/RCT2-Installation
- Raspberry Pi 4 mit 64-Bit-System und SD-Karte fuer den spaeteren Test

Unter Debian/Ubuntu/Zorin installierst du die gaengigen Yocto-Werkzeuge so:

```sh
sudo apt update
sudo apt install build-essential chrpath cpio debianutils diffstat file gawk git iputils-ping jq libacl1 liblz4-tool locales python3 python3-git python3-jinja2 python3-pexpect python3-pip python3-subunit socat texinfo unzip wget xz-utils zstd curl
```

Wenn BitBake beim Start ein weiteres fehlendes Werkzeug nennt, installiere das zugehoerige Hostpaket. Verwende kein `sudo bitbake`.

## Yocto vorbereiten

Vom Stamm dieses Repositories:

```sh
./scripts/setup-build.sh
```

Das Skript holt die in `sources.lock` festgelegten Layer-Commits und richtet `build/` ein. Es bricht ab, wenn ein vorhandener Layer lokale Aenderungen hat oder auf ein anderes Git-Remote zeigt; diese Pruefung schuetzt lokale Arbeit.

## Eigene Spieldaten verpacken

Das Quellverzeichnis muss mindestens enthalten:

```text
OpenRCT_Sys/
  RCT/Data/CSG1.DAT
  RCT2/Data/g1.dat
```

Weitere benoetigte Daten, Objekte, Szenarien und Strecken werden mit aufgenommen. Erzeuge daraus die lokalen Yocto-Archive:

```sh
./scripts/prepare-build-assets.sh /pfad/zu/OpenRCT_Sys
```

Das Skript laedt ausserdem das offizielle OpenRCT2-AppImage der Rezeptversion, prueft dessen SHA-256 und extrahiert die OpenRCT2-Objekte. Die erzeugten Archive sind lokal und in `.gitignore` ausgeschlossen. Lade keine Originalspieldaten oder generierten Archive nach GitHub hoch.

## Image bauen

```sh
source layers/openembedded-core/oe-init-build-env build
bitbake -p
BB_NUMBER_THREADS=8 PARALLEL_MAKE="-j 4" nice -n 19 bitbake rpi-openrct2
```

`bitbake -p` prueft die Metadaten, ohne Pakete zu kompilieren. `BB_NUMBER_THREADS` begrenzt gleichzeitig laufende BitBake-Aufgaben; `PARALLEL_MAKE` begrenzt Compilerprozesse je Aufgabe. Die Projektkonfiguration startet konservativer mit vier Jobs. Passe die Werte an den Build-PC an und beobachte den freien Arbeitsspeicher. Bei Speicherdruck beide Werte reduzieren.

Das komprimierte Image wird in `build/tmp/deploy/images/raspberrypi4-64/` abgelegt. Die Zielmaschine heisst `raspberrypi4-64`; das ist das Yocto-Machine-Profil fuer den Raspberry Pi 4 mit 64-Bit-System.

Optionales Qt-Entwicklungs-SDK, nicht benoetigt fuer das OpenRCT2-Image:

```sh
BB_NUMBER_THREADS=8 PARALLEL_MAKE="-j 4" nice -n 19 bitbake meta-toolchain-qt6
```

Der Installer liegt danach in `build/tmp/deploy/sdk/`. Die Einrichtung steht in [qtcreator-sdk.md](../layers/meta-custom/docs/qtcreator-sdk.md).

## Auf SD-Karte schreiben

Das Flash-Skript schreibt das ganze Image und ueberschreibt alle Daten auf der Zielkarte. Ermittle zuerst das Geraet:

```sh
lsblk -o NAME,SIZE,MODEL,TYPE,MOUNTPOINTS
```

Haenge die Partitionen der SD-Karte aus. Fuehre dann aus dem Build-Verzeichnis aus:

```sh
../scripts/flash-image.sh tmp/deploy/images/raspberrypi4-64/<image>.wic.bz2 /dev/sdX
```

Ersetze `/dev/sdX` durch das ganze Karten-Geraet, zum Beispiel `/dev/sdb`, niemals durch eine Partition wie `/dev/sdb1`. Lies die Modell- und Groessenanzeige und bestaetige nur, wenn das Ziel eindeutig die SD-Karte ist.

## Erster Start

Verbinde Monitor und Tastatur oder eine serielle Konsole. Beim ersten Start legst du ein Administrationskonto an; der vorgesehene Name ist `openrct2`. Der Spielserver laeuft als eigenes systemd-Dienstkonto und startet den neuesten gespeicherten Parkstand.

Wenn mDNS im Netz verfuegbar ist, ist der Pi unter `rpi-openrct2.local` erreichbar. Vor dem Build kann ein oeffentlicher SSH-Schluessel in `build/local-assets/authorized_keys.example` eingetragen werden. Private Schluessel nie in diese Datei schreiben.

Weitere Build-Variablen und optionale Ausstattung stehen in [OPTIONAL-FEATURES.md](OPTIONAL-FEATURES.md).