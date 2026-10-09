# Pakete auf dem Pi aktualisieren, ohne neu zu flashen

Ein komplettes Image muss nur neu auf die SD-Karte geschrieben werden, wenn sich Partitionierung, Bootloader, Dateisystem oder die grundlegende Installation aendern soll. Fuer normale Programm- und Bibliotheksupdates kann das passende Yocto-IPK auf dem laufenden Pi installiert werden. Die Aenderung bleibt auch nach einem Neustart erhalten.

## Was du brauchst

- Eine SSH-Verbindung zum Pi und ein Konto mit `sudo`
- Das eingerichtete Yocto-Buildverzeichnis
- Genug freien Speicher im Buildverzeichnis fuer das Paket

Das Image verwendet IPK-Pakete; auf dem Pi verwaltet `opkg` sie.

## Ein Paket bauen

Auf dem Build-PC:

```sh
cd /pfad/zu/rpi-openrct2/build
source ../layers/openembedded-core/oe-init-build-env .
BB_NUMBER_THREADS=2 PARALLEL_MAKE=2 nice -n 19 bitbake openrct2
```

Das baut nur OpenRCT2 samt Paket, kein neues SD-Karten-Image. Die IPK-Datei liegt unter `tmp/deploy/ipk/cortexa72/`; ihr Name enthaelt die Paketversion, zum Beispiel `openrct2_<Version>-r0_cortexa72.ipk`.

Fuer andere Pakete den Namen austauschen. Ein einzelnes IPK kann aus bereits vorhandenen Build-Ergebnissen mit diesem Task geschrieben werden:

```sh
bitbake -c package_write_ipk <paketname>
```

## Auf den Pi kopieren und installieren

Beispiel fuer OpenRCT2. `<Version>` durch den tatsaechlichen Dateinamen ersetzen:

```sh
scp tmp/deploy/ipk/cortexa72/openrct2_<Version>-r0_cortexa72.ipk \
    openrct2@rpi-openrct2.local:/tmp/
ssh openrct2@rpi-openrct2.local
```

Auf dem Pi:

```sh
sudo systemctl stop openrct2.service
sudo opkg install /tmp/openrct2_<Version>-r0_cortexa72.ipk
sudo systemctl start openrct2.service
```

Das Paket wird in das bestehende System installiert. Spielstaende und nicht paketverwaltete Benutzerdateien bleiben erhalten; ein Flashen ist nicht noetig.

## Mehrere abhaengige Pakete

Wenn mehrere Pakete geaendert wurden, alle passenden IPKs kopieren und gemeinsam installieren. Runtime, Spielprogramm und Spieldaten sind getrennte Pakete:

```sh
scp tmp/deploy/ipk/cortexa72/openrct2_<Version>-r0_cortexa72.ipk \
    tmp/deploy/ipk/cortexa72/rpi-openrct2-runtime_1.0-r0_cortexa72.ipk \
    tmp/deploy/ipk/cortexa72/rct-game-data_1.0-r0_cortexa72.ipk \
    openrct2@rpi-openrct2.local:/tmp/
```

```sh
sudo systemctl stop openrct2.service
sudo opkg install /tmp/openrct2_<Version>-r0_cortexa72.ipk \
    /tmp/rpi-openrct2-runtime_1.0-r0_cortexa72.ipk \
    /tmp/rct-game-data_1.0-r0_cortexa72.ipk
sudo systemctl start openrct2.service
```

Nur Pakete kopieren, die fuer deine Aenderung neu gebaut wurden. Fuer OpenRCT2-Versionen gibt es ausserdem `layers/meta-custom/recipes-games/openrct2/update-openrct2.sh`. Erst mit `--help` und `--check` pruefen, bevor das Skript Pakete installiert und den Pi neu startet.

## Pruefen

```sh
opkg status openrct2 | grep -E '^(Version|Status):'
/usr/bin/openrct2-cli --version
systemctl is-active openrct2.service
journalctl -u openrct2.service -n 60 --no-pager
```

Ein Paketupdate braucht normalerweise nur einen Neustart des betroffenen Dienstes. Ein kompletter Pi-Neustart ist nur fuer Kernel-, Bootloader- oder andere grundlegende Systemupdates noetig.

## Wann doch ein neues Image noetig ist

- Aenderungen an Bootloader, Kernel, Partitionierung oder Dateisystem
- Aenderungen an fruehen Bootdiensten oder Image-Erstellungsregeln
- Pakete, die nicht separat paketiert oder auf dem Pi aktualisiert werden

Bei neuen/lokal bereitgestellten RCT-Spielinhalten zuerst `scripts/prepare-build-assets.sh` mit der eigenen lizenzierten Installation ausfuehren und danach `rct-game-data` bauen. Ein bewusstes Downgrade nur nach Versionspruefung und gezielt mit `opkg --force-downgrade` ausfuehren.