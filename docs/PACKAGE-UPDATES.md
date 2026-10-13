# Pakete auf dem Pi aktualisieren

Ein IPK-Update installiert neue Dateien in das bestehende System. Es flasht kein Image und normalerweise ist kein kompletter Pi-Neustart nötig. Das Projekt-Update-Skript aktualisiert nur OpenRCT2 und bricht ab, wenn entfernte Spieler verbunden sind.

## Automatisches OpenRCT2-Update

Zuerst Versionsstand, geplante Änderungen und Zielgerät prüfen:

```sh
layers/meta-custom/recipes-games/openrct2/update-openrct2.sh --help
layers/meta-custom/recipes-games/openrct2/update-openrct2.sh --check --pi openrct2@rpi-openrct2.local
layers/meta-custom/recipes-games/openrct2/update-openrct2.sh --dry-run --pi openrct2@rpi-openrct2.local
```

`--check` liest Versionen, ohne Dateien zu ändern oder zu bauen. `--dry-run` zeigt den Plan. Bei einem echten Update ermittelt das Skript einen stabilen OpenRCT2-Release, prüft AppImage und Datenassets, aktualisiert `SRCREV` und Paketdaten, prüft die Patchserie und baut nur das OpenRCT2-IPK.

Vor der Installation prüft das Skript die aktiven Verbindungen des Servers. Sind externe Spieler verbunden, wird abgebrochen. Danach hält es Server, DSI-Viewer und VNC geordnet an und startet nur die vorher aktiven Dienste wieder. Es rebootet den Pi nicht und baut kein Komplettimage.

```sh
layers/meta-custom/recipes-games/openrct2/update-openrct2.sh --pi openrct2@rpi-openrct2.local
```

`--force` überspringt den Vergleich mit der bereits installierten Version und baut/installiert erneut. Verwende es nur, wenn eine gezielte Neuinstallation erforderlich ist.

## Ein IPK manuell installieren

Manuelle Updates haben keine Spielerverbindungs-Prüfung. Plane ein Wartungsfenster, wenn andere Spieler den Server nutzen. Vor einem Serverneustart aktuelle Spielerliste und TCP-Verbindungen auf Port `11753` prüfen; den lokalen Spectator in Gruppe 1 nicht als aktiven Spieler zählen. Ein nicht-lokaler `ESTABLISHED`-Peer ist ein Grund zu warten.

Der Server speichert beim Stoppen nicht garantiert einen letzten Stand. Prüfe vor dem Neustart, dass der neueste gültige `.park`-Autosave nach der letzten Spielaktion geschrieben wurde. Bei Unsicherheit den nächsten Autosave abwarten. `SIGTERM` ist kein Save-Befehl. Nach dem Start im Log kontrollieren, dass der neueste erwartete Spielstand geladen wurde.

Im Buildverzeichnis des Repositories:

```sh
source ../layers/openembedded-core/oe-init-build-env .
BB_NUMBER_THREADS=8 PARALLEL_MAKE="-j 4" nice -n 19 bitbake openrct2
```

Das Paket liegt danach unter `tmp/deploy/ipk/cortexa72/`. Kopiere die tatsächlich gebaute Version auf den Pi:

```sh
scp tmp/deploy/ipk/cortexa72/openrct2_<Version>-r0_cortexa72.ipk \
    openrct2@rpi-openrct2.local:/tmp/
```

Auf dem Pi den Server während des Paketwechsels stoppen und wieder starten:

```sh
sudo systemctl stop openrct2.service
sudo opkg install /tmp/openrct2_<Version>-r0_cortexa72.ipk
sudo systemctl start openrct2.service
```

Bei einem Paket-Downgrade zuerst `opkg status openrct2` prüfen. `--force-downgrade` nicht routinemäßig einsetzen. Ein Paketupdate ändert keine Kernel-, Bootloader- oder Partitionsdateien.

## Erfolg prüfen

```sh
opkg status openrct2 | grep -E '^(Version|Status):'
/usr/bin/openrct2-cli --version
systemctl is-active openrct2.service
journalctl -u openrct2.service -n 60 --no-pager
```

Auf Fehler wie `Unable to open park`, `Object not found` oder fehlende Spieldaten achten. Bei Änderungen an Kernel, Bootparametern, Partitionen oder Image-Erstellung stattdessen ein neues Image bauen und flashen; das überschreibt die ganze SD-Karte.