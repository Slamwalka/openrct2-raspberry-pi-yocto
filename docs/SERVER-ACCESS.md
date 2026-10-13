# Serverzugang und Spielerrechte

## Zugang

Die Beispielkonfiguration bewirbt den Server in der OpenRCT2-Serverliste. Standardmäßig ist `known_keys_only = false`, `default_password` leer und `advertise = true`. Neue Spieler können damit ohne vorherige Freigabe beitreten.

Der Server verwendet TCP-Port `11753`. Ein Client verbindet sich mit dem in der Serverliste angezeigten Namen oder direkt mit der Adresse:

```sh
openrct2 join <server-name-oder-ip> --port 11753
```

Normale Spieler erhalten die Gruppe `Normal User`. Sie können den Park bearbeiten, Fahrgeschäfte bauen, Wege und Landschaft ändern, Personal einstellen und chatten. Admin-, Kick-, Gruppenverwaltungs- und Cheat-Rechte sind nicht Teil der Standardgruppe.

## Serverpause ohne aktive Spieler

Der Server läuft ohne grafische Oberfläche. Die Projektoption `pause_server_if_only_spectators = true` pausiert die Simulation, wenn nur der Host und Spectators (Gruppe 1) verbunden sind. Ein echter Spieler hebt die automatische Pause auf. Der lokale DSI-Viewer darf als Spectator über `127.0.0.1` verbunden sein.

Normale Spieler können den Server nicht über die Gruppenrechte pausieren; OpenRCT2 sperrt das zusätzlich im Netzwerkcode.

### Entity-Zustand und Desync-Hypothese

Bei automatischer Headless-Pause bleibt `GameIsPaused()` unverändert: Der Server hält den Simulationstick an, ohne die ausdrückliche Spielpause zu setzen. Clients führen bei unverändertem Server-Tick keine Simulationsupdates aus. MoneyEffects liegen nicht in der Netzwerk-Entity-Checksum; Gäste, Personal, Fahrzeuge und Litter dagegen schon. Da alle Entitäten eine gemeinsame Freiliste verwenden, kann einseitiges Entfernen von MoneyEffects spätere Entity-IDs auseinanderlaufen lassen.

Patch `0012` aktualisiert MoneyEffects deshalb nur während einer ausdrücklichen Spielpause, nicht während der automatischen Headless-Pause. Dies ist eine gezielte Vorsichtsmassnahme gegen einen plausiblen Desync-Pfad, keine Garantie gegen alle Desync-Ursachen. Die Funktion ist in der Rezept-Patchserie dieses Projekts enthalten.

### Sicheres Wartungsfenster

Vor einem Serverneustart müssen alle echten Spielclients getrennt sein; den lokalen Spectator in Gruppe 1 nicht als Spieler zählen. Eine nicht-lokale `ESTABLISHED`-Verbindung auf TCP-Port `11753` ist ein konservativer Grund zu warten. Ein Leave-Eintrag allein beweist nicht, dass keine andere Sitzung verbunden ist.

Prüfe ausserdem, dass ein gültiger Autosave nach der letzten Spielaktion existiert. `systemctl stop`/`SIGTERM` schreibt nicht garantiert einen zusätzlichen Spielstand. Bei Unsicherheit den nächsten Autosave abwarten. Nach dem Start Log und geladenen Parkstand kontrollieren.

## Gruppen ändern

Die Gruppenvorlage liegt in `layers/meta-custom/recipes-games/rpi-openrct2-runtime/files/openrct2-groups.json`. Auf einem bestehenden Pi ist die aktive Datei `~/.config/OpenRCT2/groups.json`. Der Server liest sie beim Start. Nach einer Änderung:

```sh
sudo systemctl restart openrct2.service
systemctl is-active openrct2.service
journalctl -u openrct2.service -n 60 --no-pager
```

## Verbindungsprobleme unterscheiden

- „Keine Berechtigung“ bedeutet meist, dass eine Spielaktion für die Gruppe nicht erlaubt ist.
- Eine Beitrittsablehnung nennt meist Passwort, Schlüssel, Version oder volle Plätze.
- Ein Desync bedeutet, dass Clients denselben Simulationsstand nicht mehr bestätigen. Er beweist für sich allein weder Paketverlust noch einen bestimmten fehlerhaften Spielbefehl.

Die Serverlogs liegen unter `~/.config/OpenRCT2/serverlogs/`. Der Server protokolliert dort Beitritte mit der gesehenen Client-IP und angenommene Spielaktionen. Die Desync-Dateien schreibt jeder Client lokal nach `~/.config/OpenRCT2/desyncs/`; deshalb können auf dem PC neuere Berichte liegen als auf dem Pi.

Beim Vergleich eines Reports zuerst Ticknummer und `srand0` vergleichen. Stimmen beide überein und weichen nur bewegliche Sprites wie `Money effect` oder `Litter` ab, ist das anders zu bewerten als ein anderer RNG-Seed oder Abweichungen bei Gästen/Personal. Danach Server-/Clientversion, Verbindungsabbrüche, Wiederbeitritte, geladene Objekte und die letzten protokollierten Aktionen gegen die Reportzeit legen. Eine zeitliche Nähe ist ein Hinweis, kein Beweis.

Für aussagekräftige Netzwerktests während einer ganzen Sitzung dieselbe Route nutzen. Bei Wechsel zwischen LAN, VPN, Mobilfunk oder öffentlichem Hostnamen erst sauber trennen, OpenRCT2 vollständig beenden und erst nach stabilem Netz neu starten.

## Sicherheit

Die Beispielkonfiguration ist offen und öffentlich auffindbar. Jeder kann mit den Standardrechten dem Spiel beitreten und den Park bearbeiten. Die Schlüsselsignatur prüft die Spieleridentität, verschlüsselt aber nicht den Spielverkehr.

Leite TCP-Port `11753` nicht direkt im Router aus dem Internet weiter. Für Fernzugriff nutze ein VPN. VNC ist ausschliesslich über einen SSH-Tunnel vorgesehen; siehe [Optionale Funktionen](OPTIONAL-FEATURES.md). Für einen privaten Server setze ein Passwort oder aktiviere `known_keys_only` und trage die Spielerschlüssel gezielt ein.