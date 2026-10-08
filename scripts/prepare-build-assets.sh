#!/usr/bin/env bash
set -euo pipefail

if (($# != 1)); then
    echo "Aufruf: $0 /pfad/zur/OpenRCT_Sys-Installation" >&2
    exit 2
fi

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
ASSET_DIR="$ROOT/layers/meta-custom/recipes-games/openrct2/files"
RECIPE="$ROOT/layers/meta-custom/recipes-games/openrct2/openrct2_0.55.bb"
GAME_RECIPE="$ROOT/layers/meta-custom/recipes-games/rct-game-data/rct-game-data_1.0.bb"
GAME_ROOT=$(cd -- "$1" && pwd)
PV=$(sed -n 's/^PV = "\([0-9.]*\)"/\1/p' "$RECIPE" | head -n 1)
[[ -n "$PV" ]] || { echo "PV fehlt im OpenRCT2-Rezept." >&2; exit 1; }

for tool in curl jq sha256sum tar; do
    command -v "$tool" >/dev/null || { echo "Bitte zuerst installieren: $tool" >&2; exit 1; }
done

[[ -r "$GAME_ROOT/RCT/Data/CSG1.DAT" ]] || {
    echo "Nicht gefunden: $GAME_ROOT/RCT/Data/CSG1.DAT" >&2
    exit 1
}
[[ -r "$GAME_ROOT/RCT2/Data/g1.dat" ]] || {
    echo "Nicht gefunden: $GAME_ROOT/RCT2/Data/g1.dat" >&2
    exit 1
}

TMP=$(mktemp -d "${TMPDIR:-/tmp}/rpi-openrct2-assets.XXXXXX")
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

tar --sort=name --owner=0 --group=0 --numeric-owner \
    --mode='u+rwX,go+rX,go-w' --mtime='@0' \
    --use-compress-program='gzip -1 -n' \
    -cf "$TMP/rct-game-data.tar.gz" -C "$GAME_ROOT" \
    RCT/Data RCT/Scenarios RCT/Tracks \
    RCT2/Data RCT2/ObjData RCT2/Landscapes RCT2/Scenarios RCT2/Tracks

TAG="v$PV"
API="https://api.github.com/repos/OpenRCT2/OpenRCT2/releases/tags/$TAG"
curl -fsSL --retry 2 --max-time 30 -H 'Accept: application/vnd.github+json' "$API" -o "$TMP/release.json"
APPIMAGE="OpenRCT2-${TAG}-linux-x86_64.AppImage"
CHECKSUMS="OpenRCT2-${TAG}-sha256sums.txt"
APPIMAGE_URL=$(jq -er --arg name "$APPIMAGE" '.assets[] | select(.name == $name) | .browser_download_url' "$TMP/release.json")
CHECKSUM_URL=$(jq -er --arg name "$CHECKSUMS" '.assets[] | select(.name == $name) | .browser_download_url' "$TMP/release.json")
curl -fsSL --retry 2 --max-time 60 "$CHECKSUM_URL" -o "$TMP/checksums.txt"
EXPECTED=$(awk -v name="./$APPIMAGE" '$2 == name {print $1; exit}' "$TMP/checksums.txt")
[[ "$EXPECTED" =~ ^[0-9a-fA-F]{64}$ ]] || { echo "SHA-256 fehlt fuer $APPIMAGE" >&2; exit 1; }
curl -fL --retry 2 --max-time 600 "$APPIMAGE_URL" -o "$TMP/$APPIMAGE"
printf '%s  %s\n' "$EXPECTED" "$TMP/$APPIMAGE" | sha256sum --check --status || {
    echo "SHA-256-Pruefung des offiziellen AppImage fehlgeschlagen." >&2
    exit 1
}
chmod 0755 "$TMP/$APPIMAGE"
mkdir "$TMP/appimage"
(
    cd "$TMP/appimage"
    "$TMP/$APPIMAGE" --appimage-extract >"$TMP/extract.log" 2>&1
) || {
    tail -n 30 "$TMP/extract.log" >&2
    exit 1
}
OBJECTS="$TMP/appimage/squashfs-root/usr/share/openrct2/object"
[[ -d "$OBJECTS" ]] || { echo "OpenRCT2-Objektordner fehlt im AppImage." >&2; exit 1; }
COUNT=$(find "$OBJECTS" -type f | wc -l)
((COUNT > 1000)) || { echo "Unerwartet wenige Objektdateien: $COUNT" >&2; exit 1; }

tar --sort=name --owner=0 --group=0 --numeric-owner \
    --mode='u+rwX,go+rX,go-w' --mtime='@0' \
    --use-compress-program='gzip -1 -n' \
    -cf "$TMP/openrct2-official-objects.tar.gz" -C "$OBJECTS" .
OBJECT_SHA=$(sha256sum "$TMP/openrct2-official-objects.tar.gz" | awk '{print $1}')
GAME_SHA=$(sha256sum "$TMP/rct-game-data.tar.gz" | awk '{print $1}')

install -m 0644 "$TMP/rct-game-data.tar.gz" "$ASSET_DIR/.rct-game-data.tar.gz.new"
mv "$ASSET_DIR/.rct-game-data.tar.gz.new" "$ASSET_DIR/rct-game-data.tar.gz"
install -m 0644 "$TMP/openrct2-official-objects.tar.gz" "$ASSET_DIR/.openrct2-official-objects.tar.gz.new"
mv "$ASSET_DIR/.openrct2-official-objects.tar.gz.new" "$ASSET_DIR/openrct2-official-objects.tar.gz"

python3 - "$RECIPE" "$GAME_RECIPE" "$OBJECT_SHA" "$GAME_SHA" <<'PY'
from pathlib import Path
import re
import sys

recipe = Path(sys.argv[1])
game_recipe = Path(sys.argv[2])
object_digest, game_digest = sys.argv[3:]
text, count = re.subn(
    r'^SRC_URI\[openrct2objects\.sha256sum\]\s*=.*$',
    f'SRC_URI[openrct2objects.sha256sum] = "{object_digest}"',
    recipe.read_text(), count=1, flags=re.MULTILINE)
if count != 1:
    raise SystemExit("Objektarchiv-Checksumme konnte nicht aktualisiert werden")
recipe_temp = recipe.with_suffix(recipe.suffix + ".new")
recipe_temp.write_text(text)
recipe_temp.replace(recipe)

text = game_recipe.read_text()
text, count = re.subn(
    r'^SRC_URI\[rctgamedata\.sha256sum\]\s*=.*$',
    f'SRC_URI[rctgamedata.sha256sum] = "{game_digest}"',
    text, count=1, flags=re.MULTILINE)
if count == 0:
    text, count = re.subn(
        r'^(SRC_URI\s*=.*)$',
        rf'\1\nSRC_URI[rctgamedata.sha256sum] = "{game_digest}"',
        text, count=1, flags=re.MULTILINE)
if count != 1:
    raise SystemExit("Spieldaten-Checksumme konnte nicht aktualisiert werden")
temporary = game_recipe.with_suffix(game_recipe.suffix + ".new")
temporary.write_text(text)
temporary.replace(game_recipe)
PY

echo "Build-Dateien vorbereitet: $COUNT OpenRCT2-Objekte und lizenzierte RCT-Daten."
echo "Die Archive bleiben lokal und sind in .gitignore ausgeschlossen."