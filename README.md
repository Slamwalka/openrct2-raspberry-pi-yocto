# OpenRCT2 auf dem Raspberry Pi 4 mit Yocto

Dieses Projekt baut ein 64-Bit-Yocto-System fuer einen Raspberry Pi 4 Model B. Der Server laeuft ohne grafische Oberflaeche; Display, VNC, VPN und NAS-Speicher sind getrennte, teilweise optionale Funktionen.

Der Rezeptstand pinnt **OpenRCT2 0.5.6** auf Commit `82b309798a83346b7f9fc61a53847f4323deb19d`.

## Referenzhardware

Getestet wird auf einem **Raspberry Pi 4 Model B mit 8 GB RAM** und dem **offiziellen Raspberry Pi Touch Display** am DSI-Anschluss. Andere Pi-Modelle oder Displaygenerationen koennen zusaetzliche Anpassungen erfordern. Der optionale DSI-Viewer dient als lokale Parkansicht und **interaktiver Bilderrahmen**: Bei automatischer Serverpause dunkelt er ab; Touch oder die Rueckkehr eines aktiven Spielers wecken die Anzeige.

## Server und Laufzeit

Das Image installiert einen headless Mehrspielerserver mit einer konfigurierten Grenze von 64 Spielern. Wenn nur Host und Spectators (Gruppe 1) verbunden sind, pausiert die Simulation; ein aktiver Spieler setzt sie fort. Der lokale DSI-Viewer kann als Spectator beitreten und bietet Auto-Tour, Backlight-Steuerung, Inaktivitaetsabdunklung und Touchbedienung.

Die Touchunterstuetzung blendet den Cursor nach Inaktivitaet aus, behaelt den Touchzustand fuer Drag bei und erkennt Doubletap-Kamera-Drag. Schnelle Wiederbeitritte desselben Schluessels erhalten eine kurze Verzoegerung.

Zwei Mehrspieler-Schutzmassnahmen adressieren plausible Desync-Pfade: Waehrend automatischer Headless-Pause aktualisiert der Server MoneyEffects nicht einseitig. MoneyEffects und checksumrelevante Entitaeten teilen sich eine Entity-Freiliste, sodass asynchrone Freigaben spaetere Entity-IDs auseinanderlaufen lassen koennten. Bei einem schnellen Wiederbeitritt desselben Schluessels wartet der Server ausserdem fuenf Sekunden, wenn der vorherige Disconnect weniger als zwei Minuten zurueckliegt. Diese Massnahmen decken nicht automatisch alle Desync-Ursachen ab. Hinweise zur Diagnose und zum sicheren Betrieb: [Serverzugang und Spielerrechte](docs/SERVER-ACCESS.md).

Das Rezept pinnt OpenRCT2 **0.5.6** auf Commit `82b309798a83346b7f9fc61a53847f4323deb19d`. Das GitHub-Rezept enthaelt die lokalen Yocto-Anpassungen und benoetigten Titel-Sequenzen.

## Schnellstart

Vorausgesetzt sind ein Linux-x86_64-Build-PC, Git, die Host-Werkzeuge aus [Build und Installation](docs/BUILD.md), eine SD-Karte sowie eigene lizenzierte RCT1-/RCT2-Daten. Ersetze `DEIN_GITHUB_OWNER` unten durch den GitHub-Benutzer oder die Organisation, unter der das Repository veroeffentlicht wird:

```sh
OWNER=DEIN_GITHUB_OWNER
git clone "https://github.com/${OWNER}/rpi-openrct2.git"
cd rpi-openrct2
./scripts/setup-build.sh
./scripts/prepare-build-assets.sh /pfad/zu/OpenRCT_Sys
source layers/openembedded-core/oe-init-build-env build
bitbake -p
nice -n 19 bitbake rpi-openrct2
```

`setup-build.sh` klont die in `sources.lock` gepinnten Yocto-Layer und richtet `build/` ein. Die gemeinsamen Projektdefaults verwenden vier BitBake-Threads und vier Compilerjobs; passe sie bei wenig RAM in `build/conf/local.conf` weiter nach unten an.

Die Assets muessen mindestens `RCT/Data/CSG1.DAT` und `RCT2/Data/g1.dat` enthalten. Das Skript packt die benoetigten Spieldaten lokal und prueft die offiziellen OpenRCT2-Objekte anhand der Release-Pruefsumme. Lizenzierte Daten und gebaute Images werden nicht in Git gespeichert.

Das Image liegt unter `build/tmp/deploy/images/raspberrypi4-64/`. Das Flashen loescht den gesamten Ziel-Datentraeger:

```sh
cd build
../scripts/flash-image.sh tmp/deploy/images/raspberrypi4-64/<image>.wic.bz2 /dev/sdX
```

Ersetze `/dev/sdX` durch das ganze SD-Kartengeraet, nicht durch eine Partition. Das Skript zeigt das Geraet an und verlangt eine genaue Bestaetigung. Pruefe den Namen mit `lsblk`.

## Erste Anmeldung

Beim ersten Start richte an der Konsole das Administrationskonto ein. Der vorgesehene Benutzername ist `openrct2`; der OpenRCT2-Server laeuft als eigenes Dienstkonto. Nach der Einrichtung ist der Rechner im lokalen Netz normalerweise unter `rpi-openrct2.local` erreichbar.

Optional kannst du vor dem Build einen oeffentlichen SSH-Schluessel in `build/local-assets/authorized_keys.example` hinterlegen. Nur oeffentliche Schluessel verwenden. Private Schluessel, VPN-Dateien und NAS-Passwoerter gehoeren nicht ins Repository.

## Anleitungen

- [Build und Installation](docs/BUILD.md): Host vorbereiten, Spieldaten verpacken, Image bauen und flashen.
- [Optionale Funktionen](docs/OPTIONAL-FEATURES.md): WireGuard, SMB/CIFS, Zeitzone, Displaydrehung, VNC und Viewer-Einstellungen.
- [Serverzugang und Spielerrechte](docs/SERVER-ACCESS.md): Beitritt, Gruppen, Pause, Sicherheit und Desync-Berichte.
- [Lokaler DSI-Viewer](docs/LOCAL-DISPLAY-AUTOSTART.md): Xorg und Spectator auf dem Panel einrichten.
- [Paketupdates](docs/PACKAGE-UPDATES.md): OpenRCT2 aktualisieren, ohne ein neues Image zu flashen.
- [Qt-SDK](layers/meta-custom/docs/qtcreator-sdk.md): optionales Entwickler-SDK fuer Qt-Anwendungen.
- [qmake-Test](layers/meta-custom/examples/qt-qmake-smoke/README.md): kleiner SDK-Selbsttest.

## Bilder und GIFs

Screenshots und kurze Animationen liegen im Ordner [`media/`](media/). Neue Dateien dort nach Moeglichkeit klein halten und keine Konten, privaten Schluessel, VPN-Profile oder Zugangsdaten zeigen.

## Sicherheit

Die Beispielkonfiguration bewirbt den Server oeffentlich, verlangt kein gemeinsames Passwort und akzeptiert neue Spielerschluessel. Behandle ihn daher als oeffentlichen Community-Server. Leite den Spielport nicht direkt aus dem Internet weiter. Fuer Fernzugriff nutze ein VPN; VNC wird ausschliesslich ueber einen SSH-Tunnel angeboten. Details und sichere Alternativen stehen in [Serverzugang und Spielerrechte](docs/SERVER-ACCESS.md).

Die Layer-Revisionen sind in `sources.lock` festgehalten. Build-Ausgabe, private Schluessel, VPN-Konfigurationen und lizenzierte Originalspieldaten bleiben lokal.

`sources.lock` pinnt die externen Yocto-Layer; das OpenRCT2-Rezept pinnt Quellrevision und lokale Patches. Ein Build erzeugt ein neues Image, aendert aber kein bereits geflashtes Geraet. Fuer einzelne OpenRCT2-Aktualisierungen kann das IPK-Updateverfahren aus [Paketupdates](docs/PACKAGE-UPDATES.md) verwendet werden.

## Begriffe

- **Yocto** baut ein Linux-System aus vielen getrennten Bausteinen fuer ein bestimmtes Geraet.
- Ein **Layer** ist ein Ordner mit Rezepten, Einstellungen und Dateien fuer solche Bausteine.
- Ein **Rezept** (`.bb`) sagt BitBake, woher ein Programm kommt, wie es gebaut und als Paket abgelegt wird.
- **BitBake** ist das Build-Werkzeug; ein **IPK** ist ein installierbares Paket fuer das laufende Pi-System.
