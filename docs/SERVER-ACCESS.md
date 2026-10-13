# Serverzugang und Spielerrechte

## Zugang

Die Beispielkonfiguration bewirbt den Server in der OpenRCT2-Serverliste. Standardmaessig ist `known_keys_only = false`, `default_password` leer und `advertise = true`. Neue Spieler koennen damit ohne vorherige Freigabe beitreten.

Der Server verwendet TCP-Port `11753`. Ein Client verbindet sich mit dem in der Serverliste angezeigten Namen oder direkt mit der Adresse:

```sh
openrct2 join <server-name-oder-ip> --port 11753
```

Normale Spieler erhalten die Gruppe `Normal User`. Sie koennen den Park bearbeiten, Fahrgeschaefte bauen, Wege und Landschaft aendern, Personal einstellen und chatten. Admin-, Kick-, Gruppenverwaltungs- und Cheat-Rechte sind nicht Teil der Standardgruppe.

## Serverpause ohne aktive Spieler

Der Server laeuft ohne grafische Oberflaeche. Die Projektoption `pause_server_if_only_spectators = true` pausiert die Simulation, wenn nur der Host und Spectators (Gruppe 1) verbunden sind. Ein echter Spieler hebt die automatische Pause auf. Der lokale DSI-Viewer darf als Spectator ueber `127.0.0.1` verbunden sein.

Normale Spieler koennen den Server nicht ueber die Gruppenrechte pausieren; OpenRCT2 sperrt das zusaetzlich im Netzwerkcode.

### Entity-Zustand und Desync-Hypothese

Bei automatischer Headless-Pause bleibt `GameIsPaused()` unveraendert: Der Server haelt den Simulationstick an, ohne die ausdrueckliche Spielpause zu setzen. Clients fuehren bei unveraendertem Server-Tick keine Simulationsupdates aus. MoneyEffects liegen nicht in der Netzwerk-Entity-Checksum; Gaeste, Personal, Fahrzeuge und Litter dagegen schon. Da alle Entitaeten eine gemeinsame Freiliste verwenden, kann einseitiges Entfernen von MoneyEffects spaetere Entity-IDs auseinanderlaufen lassen.

Patch `0012` aktualisiert MoneyEffects deshalb nur waehrend einer ausdruecklichen Spielpause, nicht waehrend der automatischen Headless-Pause. Dies ist eine gezielte Vorsichtsmassnahme gegen einen plausiblen Desync-Pfad, keine Garantie gegen alle Desync-Ursachen. Die Funktion ist in der Rezept-Patchserie dieses Projekts enthalten.

### Sicheres Wartungsfenster

Vor einem Serverneustart muessen alle echten Spielclients getrennt sein; den lokalen Spectator in Gruppe 1 nicht als Spieler zaehlen. Eine nicht-lokale `ESTABLISHED`-Verbindung auf TCP-Port `11753` ist ein konservativer Grund zu warten. Ein Leave-Eintrag allein beweist nicht, dass keine andere Sitzung verbunden ist.

Pruefe ausserdem, dass ein gueltiger Autosave nach der letzten Spielaktion existiert. `systemctl stop`/`SIGTERM` schreibt nicht garantiert einen zusaetzlichen Spielstand. Bei Unsicherheit den naechsten Autosave abwarten. Nach dem Start Log und geladenen Parkstand kontrollieren.

## Gruppen aendern

Die Gruppenvorlage liegt in `layers/meta-custom/recipes-games/rpi-openrct2-runtime/files/openrct2-groups.json`. Auf einem bestehenden Pi ist die aktive Datei `~/.config/OpenRCT2/groups.json`. Der Server liest sie beim Start. Nach einer Aenderung:

```sh
sudo systemctl restart openrct2.service
systemctl is-active openrct2.service
journalctl -u openrct2.service -n 60 --no-pager
```

## Verbindungsprobleme unterscheiden

- „Keine Berechtigung“ bedeutet meist, dass eine Spielaktion fuer die Gruppe nicht erlaubt ist.
- Eine Beitrittsablehnung nennt meist Passwort, Schluessel, Version oder volle Plaetze.
- Ein Desync bedeutet, dass Clients denselben Simulationsstand nicht mehr bestaetigen. Er beweist fuer sich allein weder Paketverlust noch einen bestimmten fehlerhaften Spielbefehl.

Die Serverlogs liegen unter `~/.config/OpenRCT2/serverlogs/`. Der Server protokolliert dort Beitritte mit der gesehenen Client-IP und angenommene Spielaktionen. Die Desync-Dateien schreibt jeder Client lokal nach `~/.config/OpenRCT2/desyncs/`; deshalb koennen auf dem PC neuere Berichte liegen als auf dem Pi.

Beim Vergleich eines Reports zuerst Ticknummer und `srand0` vergleichen. Stimmen beide ueberein und weichen nur bewegliche Sprites wie `Money effect` oder `Litter` ab, ist das anders zu bewerten als ein anderer RNG-Seed oder Abweichungen bei Gaesten/Personal. Danach Server-/Clientversion, Verbindungsabbrueche, Wiederbeitritte, geladene Objekte und die letzten protokollierten Aktionen gegen die Reportzeit legen. Eine zeitliche Naehe ist ein Hinweis, kein Beweis.

Fuer aussagekraeftige Netzwerktests waehrend einer ganzen Sitzung dieselbe Route nutzen. Bei Wechsel zwischen LAN, VPN, Mobilfunk oder oeffentlichem Hostnamen erst sauber trennen, OpenRCT2 vollstaendig beenden und erst nach stabilem Netz neu starten.

## Sicherheit

Die Beispielkonfiguration ist offen und oeffentlich auffindbar. Jeder kann mit den Standardrechten dem Spiel beitreten und den Park bearbeiten. Die Schluesselsignatur prueft die Spieleridentitaet, verschluesselt aber nicht den Spielverkehr.

Leite TCP-Port `11753` nicht direkt im Router aus dem Internet weiter. Fuer Fernzugriff nutze ein VPN. VNC ist ausschliesslich ueber einen SSH-Tunnel vorgesehen; siehe [Optionale Funktionen](OPTIONAL-FEATURES.md). Fuer einen privaten Server setze ein Passwort oder aktiviere `known_keys_only` und trage die Spielerschluessel gezielt ein.