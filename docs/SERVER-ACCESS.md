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

### Testläufe und unsere Beobachtung vom 13.10.2026

Der Test lief gegen eine private Instanz des gepatchten OpenRCT2-Servers `0.5.6` (`82b309798a`), gebunden an `127.0.0.1:11754` mit `advertise = false`. Der öffentliche Server auf Port `11753` blieb unangetastet. Als Testpark diente eine Kopie des NAS-Backups `pre-64-client-stress_20261013-131252.park`; dessen SHA-256 war `1c34cf375c68f23e15bf15a0e6ed81261da3de715fe9e9c260e68c52a8f956ed` und blieb auf dem NAS unverändert. Die Clients waren OpenRCT2 `0.5.6` (`Network version 0.5.6-0`) unter Linux/x86-64, gestartet mit getrennten Profilen in Xvfb über einen SSH-Tunnel.

- Ein Client lief 120 Sekunden. Die Zahl der Server-Heartbeats stieg von 270 auf 309 (+39). Im Clientprofil entstand kein neuer Desync-Bericht; Client- und Serverlogs enthielten keinen passenden Desync- oder Checksum-Fehler.
- Ein anschliessender Lauf startete vier Clients gleichzeitig für höchstens 120 Sekunden. Zwei Clientlogs meldeten beim Kartenabruf `Corrupted block detected` / `Unable to read map from server`; diese Sitzungen zählen nicht als erfolgreiche Simulationsläufe. Die Server-Heartbeat-Zahl stieg währenddessen von 144 auf 270. In den vier Profilen entstand kein neuer Desync-Bericht.
- In einer späteren Sitzung mit nur einem Testclient protokollierte die private Instanz um 17:12:18 eine erfolgreiche `SmallSceneryRemoveAction` (`sceneryType = 0541`). Dieser Einzelclientlauf prüfte weder gleichzeitige Clients noch die automatische Pause.
- Der Produktivdienst blieb aktiv. Die Testinstanz und ihre Parkkopie waren davon getrennt.

### Unsere Beobachtung auf dem Produktivserver

Während mehrere Spieler verbunden waren, haben wir gebaut, Objekte entfernt und den Park verändert. Dabei haben wir keinen Desync beobachtet. Das lokale Pi-Log `~/.config/OpenRCT2/serverlogs/20261013-133757.txt` reicht von 13:37:57 bis 17:14:37 und enthält 819 GameAction-Einträge; 27 sind mit `OK` protokolliert: unter anderem Gelände absenken/glätten/anheben, Wege platzieren/entfernen, Ride-Status und -Aussehen ändern, eine Strecke platzieren und ein Fahrgeschäft erstellen. Die übrigen Einträge werden nicht als erfolgreiche Aktionen gewertet. Im Log gibt es keine Desync-/Checksum-Signatur; die neueste lokale Pi-Desync-Datei stammt von 11:51:37, also vor diesem Logzeitraum.

Damit haben wir stärkere Praxisevidenz für normale Spielaktionen unter realer Mehrspielerlast als durch den isolierten Soaktest allein. Die gleichzeitigen Verbindungen beruhen auf unserer Beobachtung; das Log ordnet nicht jede Aktion mehreren gleichzeitig verbundenen Clients zu. Wir haben keine Clientberichte anderer Spieler gesammelt und keine Zustandsprüfsummen verglichen. Deshalb ist das kein allgemeiner Beweis, dass Spielaktionen oder alle Desync-Ursachen ausgeschlossen sind. Die Zstd-Maptransferfehler aus dem isolierten Vier-Client-Lauf bleiben ein separates Verbindungsproblem.

Die dazugehörige Upstream-Frage haben wir in [OpenRCT2 #27285](https://github.com/OpenRCT2/OpenRCT2/issues/27285) gestellt.

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