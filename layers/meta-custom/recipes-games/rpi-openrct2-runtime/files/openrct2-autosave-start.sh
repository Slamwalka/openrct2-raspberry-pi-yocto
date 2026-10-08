#!/bin/sh
set -eu

USER_DATA_PATH="${XDG_CONFIG_HOME:-${HOME:-/home/openrct2}/.config}/OpenRCT2"
LOCAL_SAVE_DIR="$USER_DATA_PATH/save"
NAS_SAVE_DIR="${OPENRCT2_NAS_SAVE_DIR:-/mnt/OpenRCT_SYS/config/save}"
OPENRCT2_CLI="${OPENRCT2_CLI:-$(command -v openrct2-cli || echo /usr/bin/openrct2-cli)}"
RCT1_DATA_PATH="${OPENRCT2_RCT1_DATA_PATH:-/usr/share/rct-game-data/RCT}"
RCT2_DATA_PATH="${OPENRCT2_RCT2_DATA_PATH:-/usr/share/rct-game-data/RCT2}"
LATEST_SAVE=

[ -d "$RCT1_DATA_PATH" ] || RCT1_DATA_PATH="${HOME:-/home/openrct2}/OpenRCT2-local-data/RCT"
[ -d "$RCT2_DATA_PATH" ] || RCT2_DATA_PATH="${HOME:-/home/openrct2}/OpenRCT2-local-data/RCT2"

for SAVE_DIR in "$LOCAL_SAVE_DIR" "$LOCAL_SAVE_DIR/autosave" "$NAS_SAVE_DIR" "$NAS_SAVE_DIR/autosave"; do
    for CANDIDATE in "$SAVE_DIR"/*.park; do
        [ -f "$CANDIDATE" ] || continue
        if [ -z "$LATEST_SAVE" ] || [ "$CANDIDATE" -nt "$LATEST_SAVE" ]; then
            LATEST_SAVE=$CANDIDATE
        fi
    done
done

if [ -z "$LATEST_SAVE" ]; then
    DEFAULT_SCENARIO="$RCT2_DATA_PATH/Scenarios/Alpine Adventures.SC6"
    if [ -f "$DEFAULT_SCENARIO" ]; then
        LATEST_SAVE=$DEFAULT_SCENARIO
        echo "No saved park found; starting default scenario: $LATEST_SAVE"
    else
        echo "No park save or default scenario found in the configured data paths" >&2
        exit 1
    fi
fi

echo "Loading latest park save: $LATEST_SAVE"
exec "$OPENRCT2_CLI" host "$LATEST_SAVE" \
    --port "${OPENRCT2_PORT:-11753}" \
    --verbose \
    --user-data-path="$USER_DATA_PATH" \
    --rct1-data-path="$RCT1_DATA_PATH" \
    --rct2-data-path="$RCT2_DATA_PATH"