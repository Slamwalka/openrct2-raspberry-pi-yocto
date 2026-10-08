#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
LAYERS="$ROOT/layers"
BUILD="$ROOT/build"

for tool in git; do
    command -v "$tool" >/dev/null || { echo "Bitte zuerst installieren: $tool" >&2; exit 1; }
done

clone_pinned() {
    local name=$1 remote=$2 branch=$3 commit=$4
    local destination="$LAYERS/$name"

    if [[ -e "$destination" ]]; then
        if ! git -C "$destination" rev-parse --git-dir >/dev/null 2>&1; then
            echo "$destination existiert, ist aber kein Git-Checkout. Bitte erst pruefen." >&2
            exit 1
        fi
        if [[ -n "$(git -C "$destination" status --porcelain)" ]]; then
            echo "$destination hat lokale Aenderungen. Sie werden nicht ueberschrieben." >&2
            exit 1
        fi
        origin=$(git -C "$destination" remote get-url origin 2>/dev/null) || {
            echo "$destination hat kein origin-Remote." >&2
            exit 1
        }
        [[ "$origin" == "$remote" ]] || {
            echo "$destination nutzt ein anderes Remote ($origin); bitte erst pruefen." >&2
            exit 1
        }
    else
        git clone --branch "$branch" "$remote" "$destination"
    fi

    git -C "$destination" fetch origin "$branch"
    git -C "$destination" checkout --detach "$commit"
    [[ "$(git -C "$destination" rev-parse HEAD)" == "$commit" ]] || {
        echo "Falscher Commit fuer $name" >&2
        exit 1
    }
}

while IFS='|' read -r name remote branch commit || [[ -n "${name:-}" ]]; do
    [[ -n "$name" && "$name" != \#* ]] || continue
    echo "Hole $name auf $commit"
    clone_pinned "$name" "$remote" "$branch" "$commit"
done < "$ROOT/sources.lock"

set +u
source "$LAYERS/openembedded-core/oe-init-build-env" "$BUILD" >/dev/null
set -u

add_layer() {
    local path=$1
    local current_layers
    current_layers=$(bitbake-layers show-layers)
    if ! grep -Fq "$path" <<<"$current_layers"; then
        bitbake-layers add-layer "$path"
    fi
}

add_layer "$LAYERS/meta-yocto/meta-poky"
add_layer "$LAYERS/meta-yocto/meta-yocto-bsp"
add_layer "$LAYERS/meta-openembedded/meta-oe"
add_layer "$LAYERS/meta-openembedded/meta-python"
add_layer "$LAYERS/meta-openembedded/meta-networking"
add_layer "$LAYERS/meta-raspberrypi"
add_layer "$LAYERS/meta-qt6"
add_layer "$LAYERS/meta-custom"

mkdir -p "$BUILD/local-assets"
if [[ ! -e "$BUILD/local-assets/authorized_keys.example" ]]; then
    cp "$ROOT/conf/authorized_keys.example" "$BUILD/local-assets/authorized_keys.example"
fi

LOCAL_CONF="$BUILD/conf/local.conf"
INCLUDE_LINE="require $ROOT/conf/rpi-openrct2.conf"
if ! grep -Fq "$INCLUDE_LINE" "$LOCAL_CONF"; then
    printf '\n# Project settings; see conf/rpi-openrct2.conf\n%s\n' "$INCLUDE_LINE" >> "$LOCAL_CONF"
fi

echo "Build-Verzeichnis vorbereitet: $BUILD"
echo "Naechste Schritte stehen in README.md."