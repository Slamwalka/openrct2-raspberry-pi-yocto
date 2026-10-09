# OpenRCT2-Server: Zugang und Spielerrechte

## Offener Beitritt

Der Server wird in der öffentlichen Liste angezeigt. Seine `config.ini` verwendet `known_keys_only = false` und ein leeres `default_password`. Neue Spieler muessen also nicht vorher eingetragen werden und brauchen kein gemeinsames Passwort.

## Rechte neuer Spieler

Neue Spieler erhalten die in `groups.json` festgelegte Standardgruppe `Normal User` (Gruppe 3). Sie koennen chatten, den Park bauen und bearbeiten, Fahrgeschaefte, Wege, Landschaft, Gaeste und Personal verwalten. Admin-, Kick-, Gruppenverwaltungs- und Cheat-Rechte bleiben anderen Gruppen vorbehalten.

OpenRCT2 verhindert das Pausieren durch normale Clients zusaetzlich direkt im Netzwerkcode; eine Gruppenfreigabe wuerde das nicht aendern.

Die Vorlage liegt unter `layers/meta-custom/recipes-games/rpi-openrct2-runtime/files/openrct2-groups.json` und wird bei neuen Benutzerprofilen mitgeliefert. Auf einem bestehenden Pi liegt sie unter `~/.config/OpenRCT2/groups.json`. Der Server liest die Gruppendatei beim Start; nach einer Aenderung muss `openrct2.service` neu gestartet werden.

## „Keine Berechtigung“

Diese Meldung erscheint normalerweise, wenn ein Spieler eine nicht erlaubte Aktion ausfuehrt, etwa Terraforming oder Pause. Eine echte Ablehnung beim Beitritt wird anders gemeldet. Das Serverjournal zeigt dann, ob Passwort, Spielversion, Schluessel oder freie Plaetze das Problem sind.

```sh
sudo systemctl restart openrct2.service
systemctl is-active openrct2.service
journalctl -u openrct2.service -n 60 --no-pager
```

## Hinweis zur Sichtbarkeit

Weil der Server ohne Passwort in der oeffentlichen Liste steht und unbekannte Schluessel akzeptiert, kann grundsaetzlich jeder beitreten und den Park mit den Standardrechten bearbeiten. Fuer einen privaten Server setze ein Passwort oder aktiviere `known_keys_only` und trage die Spieler gezielt ein. Gib der Standardgruppe keine Admin- oder Moderationsrechte.
