# Optionale Funktionen

Das Image bringt mehrere Werkzeuge mit, aktiviert aber nicht automatisch jeden Fernzugang und jede lokale Hardwarefunktion. Diese Seite erklärt, was bereits enthalten ist und was du selbst einrichten musst.

| Funktion | Im Image | Standardzustand |
| --- | --- | --- |
| WireGuard | `wireguard-tools` | Kein Tunnel und keine Schlüsseldatei eingerichtet |
| SMB/CIFS | `cifs-utils`, CIFS-Kernelmodul | Keine Freigabe eingetragen oder gemountet |
| DSI-Display | Xorg, SDL und Grafikpakete | Viewer startet nicht automatisch |
| VNC | Separates Paket `rpi-openrct2-runtime-vnc` | Nicht installiert; Dienst lauscht später nur auf Loopback |
| DSI-Drehung | Yocto-Boot- und Touch-Unterstützung | Aus (`0`), solange die Hardware nicht kopfüber montiert ist |
| Zeitzone | `tzdata-core` und `tzdata-europe` | `Europe/Busingen` |

## Build-Einstellungen

Die Datei `conf/rpi-openrct2.conf` enthält die gemeinsamen Build-Defaults. Für einen einzelnen Build kannst du Werte nach `./scripts/setup-build.sh` in `build/conf/local.conf` überschreiben. Änderungen an Bootparametern oder dem Root-Dateisystem benötigen ein neu gebautes Image; ein OpenRCT2-IPK-Update reicht dafür nicht.

### DSI-Drehung

Nur für ein physisch kopfüber montiertes DSI-Panel:

```bitbake
RPI_OPENRCT2_DSI_ROTATION = "180"
```

Der Standard ist `0`. Der Wert passt Bootausgabe und Touchachsen an. Der lokale Xorg-Start dreht zusätzlich `DSI-1`; das OpenRCT2-Profil kompensiert die Drehung für das gerenderte Bild und die Touch-Koordinaten. Diese drei Ebenen gehören zusammen. Die Rotation nicht für ein normal montiertes Panel aktivieren.

### Zeitzone

Der Image-Standard ist `Europe/Busingen`. Für ein anderes Land oder eine andere Region kannst du setzen:

```bitbake
RPI_OPENRCT2_TIMEZONE = "Europe/Berlin"
```

Verwende einen Namen aus der IANA-Zeitzonendatenbank, zum Beispiel `Europe/Berlin`, `America/Denver` oder `Asia/Tokyo`. Das Standardimage enthält nur Kern- und Europa-Daten. Für `America/*` muss zusätzlich `tzdata-americas`, für `Asia/*` `tzdata-asia` in `IMAGE_INSTALL` aufgenommen werden. Das Image-Rezept prüft, ob die gewählte Zone installiert ist. Der Wechsel wird erst nach dem Image-Build und der Installation wirksam.

## WireGuard

`wireguard-tools` ist installiert, aber das Image erzeugt weder private Schlüssel noch eine Peer-Konfiguration. Eine Tunneldatei muss lokal auf dem Pi angelegt werden. Beispiel mit einem frei gewählten Namen `remote`:

1. Erstelle `/etc/wireguard/remote.conf` mit den vom VPN-Administrator gelieferten Einstellungen.
2. Sichere die Datei, denn sie enthält einen privaten Schlüssel:

```sh
sudo chown root:root /etc/wireguard/remote.conf
sudo chmod 0600 /etc/wireguard/remote.conf
```

3. Aktiviere den Tunnel:

```sh
sudo systemctl enable --now wg-quick@remote.service
sudo wg show
```

Beende oder deaktiviere ihn mit `sudo systemctl disable --now wg-quick@remote.service`. Passe `remote` an den Dateinamen ohne `.conf` an. Private Schlüssel und vollständige VPN-Konfigurationen gehören nie ins Git-Repository. WireGuard ersetzt keine Firewall; den Spielport nicht direkt ins Internet weiterleiten.

## SMB/CIFS-Freigabe

Die CIFS-Werkzeuge und das Kernelmodul sind vorhanden, aber keine NAS-Adresse, Freigabe oder Zugangsdaten. Der Server sucht optionale Spielstände unter `/mnt/OpenRCT_SYS/config/save`; richte den Mount nur ein, wenn diese Freigabe tatsächlich existiert.

1. Lege den Mountpunkt und eine nur für root lesbare Zugangsdaten-Datei an:

```sh
sudo mkdir -p /mnt/OpenRCT_SYS /etc/samba
sudo install -m 0600 /dev/null /etc/samba/openrct2.credentials
sudoedit /etc/samba/openrct2.credentials
```

Die Datei enthält je eine Zeile `username=...`, `password=...` und bei Bedarf `domain=...`. Sie ist geheim und darf nicht ins Repository kopiert werden.

2. Ermittle die numerische Benutzer- und Gruppen-ID des Serverkontos:

```sh
id openrct2
```

3. Füge mit `sudoedit /etc/fstab` eine Zeile ein. Ersetze Server, Freigabe und IDs:

```fstab
//nas.example/share /mnt/OpenRCT_SYS cifs credentials=/etc/samba/openrct2.credentials,uid=1000,gid=1000,iocharset=utf8,_netdev,nofail,x-systemd.automount 0 0
```

`uid` und `gid` müssen zu dem Konto passen, das `openrct2.service` nutzt. Danach prüfen:

```sh
sudo systemctl daemon-reload
sudo mount /mnt/OpenRCT_SYS
mountpoint /mnt/OpenRCT_SYS
```

Beim Start wird die neueste `.park`-Datei aus lokalem Speicher und NAS gewählt. Wenn beide Orte Spielstände enthalten, vergleiche ihre Zeitstempel, damit nicht versehentlich ein älterer Stand geladen wird. Ohne Mount bleibt der lokale Speicher in Verwendung.

## DSI-Viewer, Bildschirmschoner und Tour

Xorg und der lokale Spectator laufen getrennt vom headless Server. Die Pi-spezifische Einrichtung steht in [LOCAL-DISPLAY-AUTOSTART.md](LOCAL-DISPLAY-AUTOSTART.md). Der Displaydienst muss auf dem Gerät eingerichtet sein; ohne ihn bleibt der Server auch ohne Panel nutzbar.

Im installierten OpenRCT2-Profil kann die optionale Backlight-Steuerung so gesetzt werden:

```ini
[general]
screen_saver_backlight_path = "/sys/class/backlight/10-0045/brightness"
spectator_auto_tour = true
spectator_auto_tour_min_interval = 18
spectator_auto_tour_max_interval = 42
spectator_auto_tour_idle_seconds = 30
```

Der Backlight-Pfad ist geräteabhängig. Leere den Wert oder lasse ihn weg, wenn das Panel keinen passenden sysfs-Eintrag hat. Die synchronisierte Rezept-Patchserie 0001-0013 dunkelt das Display nach 120 Sekunden ohne Server-Ticks ab und blendet es weich aus (ungefähr 5 Sekunden); beim Aufwachen wird die Backlight in etwa 1 Sekunde wieder eingeschaltet. Touch oder neue Server-Ticks wecken die Anzeige.

Die Patchserie enthält ausserdem Cursor-Ausblendung nach 10 Sekunden, eine fünfsekündige Wartezeit nach schnellem Wiederbeitritt, synchronisiertes MoneyEffect-Verhalten während automatischer Serverpause und Doubletap-Kamera-Drag. Die vollständige Patchliste und die benötigten Titel-Sequenzdateien sind im Rezept `openrct2_0.56.bb` registriert und werden beim Imagebau angewendet.

Die Auto-Tour startet nach `spectator_auto_tour_idle_seconds` ohne Touch, Mausrad oder Klick. Danach wählt sie zufällig ein Fahrgeschäft; der Abstand zwischen Zielen liegt zwischen den beiden Intervallwerten. Der lokale Projektstandard aktiviert die Tour, OpenRCT2 selbst hat sie standardmäßig ausgeschaltet.

### VNC über SSH

VNC ist ein optionales Paket und wird nicht automatisch gestartet. Auf dem Pi installieren und aktivieren:

```sh
sudo opkg install rpi-openrct2-runtime-vnc
sudo systemctl enable --now openrct2-vnc.service
```

Der VNC-Dienst bindet nur an Loopback. Auf dem PC einen SSH-Tunnel offen halten:

```sh
ssh -N -L 5900:127.0.0.1:5900 <pi-user>@<pi-host>
```

Dann im VNC-Programm `127.0.0.1:5900` öffnen. Port 5900 nicht in Router oder Firewall freigeben. Weitere Details stehen in [LOCAL-DISPLAY-AUTOSTART.md](LOCAL-DISPLAY-AUTOSTART.md).
