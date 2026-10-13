# Lokaler DSI-Viewer

Der DSI-Viewer ist optional und läuft als eigener Clientprozess. Der headless Server braucht weder Xorg noch ein angeschlossenes Display. Die lokale Unit ist nicht Teil des Image-Rezepts; dadurch startet ein Pi ohne Panel weiterhin normal.

## Touch und Cursor

Patch `0011` blendet den Cursor nach zehn Sekunden ohne Eingabe aus. Fingerereignisse und echte Mausbuttons wecken ihn wieder; reine Positionssprünge gelten nicht als Aktivität. Der Touch-Gerätestatus bleibt für Drag und native Doubletap-Erkennung erhalten. Patch `0013` misst das Doubletapfenster ab dem Loslassen des ersten Taps; der zweite Tap kann so als gehaltener Rechtsklick die Kamera verschieben. Nach dem Wecken wird der Bildschirmschoner nach 120 Sekunden ohne Eingabe erneut scharf.

Patches `0011` und `0013` sind im Rezept dieses GitHub-Checkouts enthalten. Touch und Cursor sind auf der Referenzhardware bestätigt; der Doubletap-Kamerazug muss nach dem Erstellen des Images am Panel geprüft werden.

## Voraussetzungen

- Das DSI-Panel ist angeschlossen und wird als `DSI-1` erkannt.
- Der OpenRCT2-Server lauscht auf `127.0.0.1:11753`.
- Xorg, `xrandr`, `xauth` und die OpenRCT2-Datenpakete sind installiert.
- Für ein kopfüber montiertes Panel müssen Build-Drehung, Xorg-Drehung und `display_rotation` zusammenpassen. Siehe [Optionale Funktionen](OPTIONAL-FEATURES.md).

## Startskript

Lege auf dem Pi `/usr/local/sbin/openrct2-display-start` an. Das Beispiel ist für ein kopfüber montiertes DSI-Panel (`rotation=180`). Bei normaler Montage ändere den Wert zu `0` und verwende `xrandr --rotate normal`.

```sh
#!/bin/sh
set -eu

DISPLAY=:0
rotation=180
status_file=/sys/class/drm/card1-DSI-1/status
if [ ! -r "$status_file" ] || [ "$(cat "$status_file")" != connected ]; then
    echo "DSI-1 is not connected; skipping the local spectator."
    exit 0
fi

server_user=$(systemctl show --property=User --value openrct2.service)
[ -n "$server_user" ] || server_user=openrct2
passwd_entry=$(getent passwd "$server_user")
[ -n "$passwd_entry" ] || { echo "OpenRCT2 service user not found: $server_user" >&2; exit 1; }
server_home=$(printf '%s\n' "$passwd_entry" | cut -d: -f6)
server_group=$(id -g "$server_user")
profile_dir="$server_home/.config/OpenRCT2"
config_file="$profile_dir/config.ini"
rct1_data_path=/usr/share/rct-game-data/RCT
[ -d "$rct1_data_path" ] || rct1_data_path="$server_home/OpenRCT2-local-data/RCT"
rct2_data_path=/usr/share/rct-game-data/RCT2
[ -d "$rct2_data_path" ] || rct2_data_path="$server_home/OpenRCT2-local-data/RCT2"
backlight_path=/sys/class/backlight/10-0045/brightness
backlight_initial=
backlight_owner_initial=
backlight_group_initial=
backlight_mode_initial=
if [ -r "$backlight_path" ]; then
    backlight_owner_initial=$(stat -c %u "$backlight_path")
    backlight_group_initial=$(stat -c %g "$backlight_path")
    backlight_mode_initial=$(stat -c %a "$backlight_path")
    chgrp "$server_group" "$backlight_path"
    chmod g+w "$backlight_path"
    backlight_initial=$(cat "$backlight_path")
fi

if [ ! -r "$config_file" ]; then
    install -d -o "$server_user" -g "$server_group" -m 0750 "$profile_dir"
    install -o "$server_user" -g "$server_group" -m 0644 \
        /etc/skel/.config/OpenRCT2/config.ini "$config_file"
fi

python3 - "$config_file" "$rotation" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
rotation = sys.argv[2]
lines = path.read_text().splitlines()
section = ""
for index, line in enumerate(lines):
    value = line.strip()
    if value.startswith("[") and value.endswith("]"):
        section = value[1:-1]
    elif section == "general" and value.split("=", 1)[0].strip() == "display_rotation":
        lines[index] = f"display_rotation = {rotation}"
        break
else:
    general = next(index for index, line in enumerate(lines) if line.strip() == "[general]")
    lines.insert(general + 1, f"display_rotation = {rotation}")
path.write_text("\n".join(lines) + "\n")
PY

runtime_dir=/run/openrct2-display
authority_file="$runtime_dir/Xauthority"
install -d -o root -g "$server_group" -m 0750 "$runtime_dir"
xauth -f "$authority_file" add "$DISPLAY" MIT-MAGIC-COOKIE-1 "$(mcookie)"
chown "root:$server_group" "$authority_file"
chmod 0640 "$authority_file"

/usr/bin/Xorg "$DISPLAY" -noreset -nolisten tcp -auth "$authority_file" \
    -logfile /var/log/openrct2-Xorg.log &
xorg_pid=$!
gui_pid=

cleanup() {
    result=$?
    trap - EXIT HUP INT TERM
    if [ -n "$gui_pid" ]; then
        kill -TERM "$gui_pid" 2>/dev/null || true
        wait "$gui_pid" 2>/dev/null || true
    fi
    kill -TERM "$xorg_pid" 2>/dev/null || true
    wait "$xorg_pid" 2>/dev/null || true
    if [ -n "$backlight_initial" ]; then
        printf '%s\n' "$backlight_initial" > "$backlight_path" || true
        chown "$backlight_owner_initial:$backlight_group_initial" "$backlight_path" || true
        chmod "$backlight_mode_initial" "$backlight_path" || true
    fi
    exit "$result"
}
trap cleanup EXIT HUP INT TERM

attempt=0
while [ ! -S /tmp/.X11-unix/X0 ]; do
    kill -0 "$xorg_pid" 2>/dev/null || { echo "Xorg exited before display :0 became ready." >&2; exit 1; }
    attempt=$((attempt + 1))
    [ "$attempt" -lt 30 ] || { echo "Timed out waiting for Xorg display :0." >&2; exit 1; }
    sleep 1
done

if [ "$rotation" = 180 ]; then
    DISPLAY="$DISPLAY" XAUTHORITY="$authority_file" /usr/bin/xrandr --output DSI-1 --rotate inverted
else
    DISPLAY="$DISPLAY" XAUTHORITY="$authority_file" /usr/bin/xrandr --output DSI-1 --rotate normal
fi

attempt=0
while ! python3 -c 'import socket; s=socket.create_connection(("127.0.0.1", 11753), timeout=1); s.close()' 2>/dev/null; do
    attempt=$((attempt + 1))
    [ "$attempt" -lt 120 ] || { echo "OpenRCT2 server did not open port 11753." >&2; exit 1; }
    sleep 1
done

runtime_user_dir="/tmp/runtime-$server_user"
install -d -o "$server_user" -g "$server_group" -m 0700 "$runtime_user_dir"
runuser -u "$server_user" -- env \
    HOME="$server_home" \
    XDG_RUNTIME_DIR="$runtime_user_dir" \
    DISPLAY="$DISPLAY" \
    XAUTHORITY="$authority_file" \
    SDL_VIDEODRIVER=x11 \
    /usr/bin/openrct2 join 127.0.0.1 --port 11753 \
    --user-data-path="$profile_dir" \
    --openrct2-data-path=/usr/share/openrct2 \
    --rct1-data-path="$rct1_data_path" \
    --rct2-data-path="$rct2_data_path" &
gui_pid=$!
wait "$gui_pid"
```

Speichere das Skript und mache es ausführbar:

```sh
sudo chmod 0755 /usr/local/sbin/openrct2-display-start
```

Das Skript legt beim ersten Lauf das Profil an, verwendet vorhandene Spieldaten aus Paketen oder dem Benutzerverzeichnis und stellt die Backlight-Rechte beim Beenden wieder her.

## systemd-Unit

Lege `/etc/systemd/system/openrct2-display.service` an:

```ini
[Unit]
Description=OpenRCT2 DSI display and local spectator
Requires=openrct2.service
After=systemd-udev-settle.service openrct2.service
ConditionPathExists=/sys/class/drm/card1-DSI-1/status

[Service]
Type=simple
ExecCondition=/bin/sh -c 'test "$(cat /sys/class/drm/card1-DSI-1/status)" = connected'
ExecStart=/bin/sh /usr/local/sbin/openrct2-display-start
Restart=on-failure
RestartSec=5
TimeoutStopSec=15
KillMode=control-group

[Install]
WantedBy=multi-user.target
```

Vor dem Start eine eventuell manuell gestartete GUI und Xorg beenden, damit Anzeige `:0` frei ist. Den Serverdienst nicht beenden:

```sh
sudo pkill -TERM -x openrct2 || true
sudo pkill -TERM -x Xorg || true
sudo systemctl daemon-reload
sudo systemctl enable --now openrct2-display.service
systemctl status openrct2-display.service --no-pager
```

Fehlt das Panel, wird der Spectator übersprungen. Der headless Server bleibt unabhängig davon nutzbar. Die Unit ist eine lokale Geräteeinstellung und wird nicht durch Paketupdates überschrieben.

VNC wird separat installiert und ausschliesslich über SSH erreicht. Die Schritte stehen in [OPTIONAL-FEATURES.md](OPTIONAL-FEATURES.md).