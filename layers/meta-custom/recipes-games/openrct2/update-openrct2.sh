#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/../../../.." && pwd)
BUILD_DIR="$REPO_ROOT/build"
RECIPE="$SCRIPT_DIR/openrct2_0.55.bb"
FILES_DIR="$SCRIPT_DIR/files"
DEPLOY_DIR="$BUILD_DIR/tmp/deploy/ipk/cortexa72"
PI_HOST=${PI_HOST:-openrct2@rpi-openrct2.local}
THREADS=${BB_NUMBER_THREADS:-2}

FORCE=0
CHECK_ONLY=0
DRY_RUN=0
while (($#)); do
    case "$1" in
        --pi)
            (($# >= 2)) || { echo "--pi requires user@host" >&2; exit 2; }
            PI_HOST=$2
            shift 2
            ;;
        --check)
            CHECK_ONLY=1
            shift
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --force)
            FORCE=1
            shift
            ;;
        --help|-h)
            cat <<'USAGE'
Usage: update-openrct2.sh [--check] [--dry-run] [--force] [--pi user@host]

Checks the latest stable GitHub release, updates SRCREV and official objects,
builds only the OpenRCT2/runtime IPKs, installs them on the Pi, verifies the
server, and reboots the Pi.

  --check       Show versions without changing files or building.
  --dry-run     Show the planned action without changing files or building.
  --force       Rebuild/reinstall even if the current release is installed.
    --pi HOST     Override the SSH target (default: openrct2@rpi-openrct2.local).
USAGE
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 2
            ;;
    esac
done

for tool in curl git jq python3 sha256sum tar ssh scp; do
    command -v "$tool" >/dev/null || { echo "Required tool not found: $tool" >&2; exit 1; }
done
[[ -f "$RECIPE" ]] || { echo "Recipe not found: $RECIPE" >&2; exit 1; }

TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/openrct2-update.XXXXXX")
ROLLBACK=0
cleanup() {
    local status=$?
    if ((status != 0 && ROLLBACK)); then
        cp -p "$TMP_DIR/openrct2.bb" "$RECIPE"
        cp -p "$TMP_DIR/openrct2-objects.tar.gz" "$FILES_DIR/openrct2-official-objects.tar.gz"
        echo "Update preparation failed; recipe and object archive were restored." >&2
    fi
    rm -rf "$TMP_DIR"
    exit "$status"
}
trap cleanup EXIT

PV_CURRENT=$(sed -n 's/^PV = "\([^"]*\)"/\1/p' "$RECIPE" | head -n 1)
SRCREV_CURRENT=$(sed -n 's/^SRCREV = "\([0-9a-fA-F]*\)"/\1/p' "$RECIPE" | head -n 1)
[[ -n "$SRCREV_CURRENT" ]] || { echo "Could not read SRCREV from recipe." >&2; exit 1; }

curl -fsSL --retry 2 --max-time 30 \
    -H 'Accept: application/vnd.github+json' \
    https://api.github.com/repos/OpenRCT2/OpenRCT2/releases/latest \
    -o "$TMP_DIR/release.json"
TAG=$(jq -er '.tag_name' "$TMP_DIR/release.json")
[[ "$TAG" =~ ^v([0-9]+\.[0-9]+\.[0-9]+)$ ]] || {
    echo "Unsupported latest release tag: $TAG" >&2
    exit 1
}
VERSION=${BASH_REMATCH[1]}
APPIMAGE_NAME="OpenRCT2-${TAG}-linux-x86_64.AppImage"
CHECKSUM_NAME="OpenRCT2-${TAG}-sha256sums.txt"
APPIMAGE_URL=$(jq -er --arg name "$APPIMAGE_NAME" '.assets[] | select(.name == $name) | .browser_download_url' "$TMP_DIR/release.json")
CHECKSUM_URL=$(jq -er --arg name "$CHECKSUM_NAME" '.assets[] | select(.name == $name) | .browser_download_url' "$TMP_DIR/release.json")

TAG_REFS=$(git ls-remote https://github.com/OpenRCT2/OpenRCT2.git "refs/tags/$TAG" "refs/tags/$TAG^{}")
SRCREV=$(awk -v tag="$TAG" '$2 == "refs/tags/" tag "^{}" { peeled=$1 } $2 == "refs/tags/" tag { direct=$1 } END { print peeled != "" ? peeled : direct }' <<<"$TAG_REFS")
[[ "$SRCREV" =~ ^[0-9a-fA-F]{40}$ ]] || { echo "Could not resolve commit for $TAG." >&2; exit 1; }

REMOTE_VERSION=$(ssh -o BatchMode=yes -o ConnectTimeout=8 "$PI_HOST" '
    for cli in /usr/bin/openrct2-cli /usr/local/bin/openrct2-cli; do
        if [ -x "$cli" ]; then
            "$cli" --version | sed -n "1s/.*v\([0-9][0-9.]*\).*/\1/p"
            exit 0
        fi
    done
    exit 1
')

printf 'OpenRCT2 release: %s (%s)\n' "$TAG" "$SRCREV"
printf 'Recipe: PV=%s SRCREV=%s\n' "${PV_CURRENT:-filename default}" "$SRCREV_CURRENT"
printf 'Pi binary: %s\n' "$REMOTE_VERSION"

if ((CHECK_ONLY)); then
    if [[ "$SRCREV_CURRENT" == "$SRCREV" && "$REMOTE_VERSION" == "$VERSION" ]]; then
        echo "Pi and Yocto recipe are current."
    else
        echo "Update available or recipe/Pi versions differ."
    fi
    exit 0
fi

if (( ! FORCE )) && [[ "$SRCREV_CURRENT" == "$SRCREV" && "$REMOTE_VERSION" == "$VERSION" ]]; then
    echo "Already running the latest release; no build, install, or reboot needed."
    exit 0
fi

if ((DRY_RUN)); then
    printf 'Would update recipe to PV=%s SRCREV=%s, rebuild IPKs, install on %s, and reboot.\n' \
        "$VERSION" "$SRCREV" "$PI_HOST"
    exit 0
fi

cp -p "$RECIPE" "$TMP_DIR/openrct2.bb"
cp -p "$FILES_DIR/openrct2-official-objects.tar.gz" "$TMP_DIR/openrct2-objects.tar.gz"
ROLLBACK=1

curl -fsSL --retry 2 --max-time 60 "$CHECKSUM_URL" -o "$TMP_DIR/checksums.txt"
EXPECTED_SHA=$(awk -v name="./$APPIMAGE_NAME" '$2 == name { print $1; exit }' "$TMP_DIR/checksums.txt")
[[ "$EXPECTED_SHA" =~ ^[0-9a-fA-F]{64}$ ]] || {
    echo "No SHA-256 entry found for $APPIMAGE_NAME." >&2
    exit 1
}
curl -fL --retry 2 --max-time 600 "$APPIMAGE_URL" -o "$TMP_DIR/$APPIMAGE_NAME"
printf '%s  %s\n' "$EXPECTED_SHA" "$TMP_DIR/$APPIMAGE_NAME" | sha256sum --check --status || {
    echo "AppImage SHA-256 verification failed." >&2
    exit 1
}
chmod 0755 "$TMP_DIR/$APPIMAGE_NAME"
mkdir "$TMP_DIR/extract"
(
    cd "$TMP_DIR/extract"
    "$TMP_DIR/$APPIMAGE_NAME" --appimage-extract >"$TMP_DIR/extract.log" 2>&1
) || {
    tail -n 30 "$TMP_DIR/extract.log" >&2
    echo "Could not extract official objects from the release AppImage." >&2
    exit 1
}
OBJECTS_DIR="$TMP_DIR/extract/squashfs-root/usr/share/openrct2/object"
[[ -d "$OBJECTS_DIR" ]] || { echo "AppImage has no OpenRCT2 object directory." >&2; exit 1; }
OBJECT_COUNT=$(find "$OBJECTS_DIR" -type f | wc -l)
((OBJECT_COUNT > 1000)) || { echo "Unexpectedly small object tree: $OBJECT_COUNT files." >&2; exit 1; }

NEW_ARCHIVE="$TMP_DIR/openrct2-official-objects.tar.gz"
tar --sort=name --owner=0 --group=0 --numeric-owner \
    --mode='u+rwX,go+rX,go-w' --mtime='@0' \
    --use-compress-program='gzip -1 -n' \
    -cf "$NEW_ARCHIVE" -C "$OBJECTS_DIR" .
OBJECT_SHA=$(sha256sum "$NEW_ARCHIVE" | awk '{print $1}')
install -m 0644 "$NEW_ARCHIVE" "$FILES_DIR/.openrct2-official-objects.tar.gz.new"
mv "$FILES_DIR/.openrct2-official-objects.tar.gz.new" "$FILES_DIR/openrct2-official-objects.tar.gz"

python3 - "$RECIPE" "$VERSION" "$SRCREV" "$OBJECT_SHA" <<'PY'
from pathlib import Path
import re
import sys

recipe = Path(sys.argv[1])
version, srcrev, object_sha = sys.argv[2:]
text = recipe.read_text()

def replace_one(pattern, replacement, value):
    global text
    text, count = re.subn(pattern, replacement, text, count=1, flags=re.MULTILINE)
    if count != 1:
        raise SystemExit(f"Expected one {value} entry, found {count}")

if re.search(r'^PV\s*=', text, flags=re.MULTILINE):
    replace_one(r'^PV\s*=.*$', f'PV = "{version}"', "PV")
else:
    replace_one(r'^(DESCRIPTION\s*=.*)$', rf'\1\nPV = "{version}"', "DESCRIPTION")
replace_one(r'^SRCREV\s*=.*$', f'SRCREV = "{srcrev}"', "SRCREV")
replace_one(r'^SRC_URI\[openrct2objects\.sha256sum\]\s*=.*$',
            f'SRC_URI[openrct2objects.sha256sum] = "{object_sha}"', "object checksum")
replace_one(r'^DESCRIPTION\s*=.*$',
            f'DESCRIPTION = "Free reimplementation of RollerCoaster Tycoon 2 ({version})"',
            "DESCRIPTION")

temporary = recipe.with_suffix(recipe.suffix + ".new")
temporary.write_text(text)
temporary.replace(recipe)
PY

echo "Fetching source revision and building only OpenRCT2/runtime IPKs..."
set +u
source "$REPO_ROOT/layers/openembedded-core/oe-init-build-env" "$BUILD_DIR" >/dev/null
set -u
BB_NUMBER_THREADS="$THREADS" PARALLEL_MAKE="$THREADS" nice -n 19 bitbake -c fetch openrct2
BB_NUMBER_THREADS="$THREADS" PARALLEL_MAKE="$THREADS" nice -n 19 \
    bitbake package_write_ipk openrct2 rpi-openrct2-runtime

OPENRCT2_IPK="$DEPLOY_DIR/openrct2_${VERSION}-r0_cortexa72.ipk"
RUNTIME_IPK="$DEPLOY_DIR/rpi-openrct2-runtime_1.0-r0_cortexa72.ipk"
[[ -s "$OPENRCT2_IPK" ]] || { echo "Expected package not found: $OPENRCT2_IPK" >&2; exit 1; }
[[ -s "$RUNTIME_IPK" ]] || { echo "Expected package not found: $RUNTIME_IPK" >&2; exit 1; }
ROLLBACK=0

echo "Copying packages to $PI_HOST..."
scp -o BatchMode=yes "$OPENRCT2_IPK" "$RUNTIME_IPK" "$PI_HOST:/tmp/"

ssh -o BatchMode=yes "$PI_HOST" sudo -n sh -s -- \
    "${OPENRCT2_IPK##*/}" "${RUNTIME_IPK##*/}" "$VERSION" <<'REMOTE'
set -eu
openrct2_ipk=$1
runtime_ipk=$2
expected_version=$3

systemctl stop openrct2.service
opkg install --force-downgrade "/tmp/$openrct2_ipk" "/tmp/$runtime_ipk"
install -d -o root -g root -m 0755 /etc/systemd/system/openrct2.service.d
cat >/etc/systemd/system/openrct2.service.d/20-yocto-cli.conf <<'EOF'
[Service]
ExecStart=
ExecStart=/usr/bin/openrct2-autosave-start.sh
Environment=OPENRCT2_CLI=/usr/bin/openrct2-cli
EOF
chmod 0644 /etc/systemd/system/openrct2.service.d/20-yocto-cli.conf
systemctl daemon-reload
systemctl start openrct2.service
systemctl is-active --quiet openrct2.service
actual_version=$(/usr/bin/openrct2-cli --version | sed -n '1s/.*v\([0-9][0-9.]*\).*/\1/p')
[ "$actual_version" = "$expected_version" ] || {
    echo "Installed CLI reports $actual_version, expected $expected_version." >&2
    exit 1
}
if journalctl -u openrct2.service --since '-2 minutes' --no-pager | grep -E 'Unable to open park|Object not found'; then
    echo "OpenRCT2 reported missing objects after package installation." >&2
    exit 1
fi
echo "OpenRCT2 $actual_version installed and service is active."
REMOTE

echo "Rebooting Pi to verify boot-time startup..."
OLD_BOOT_ID=$(ssh -o BatchMode=yes "$PI_HOST" cat /proc/sys/kernel/random/boot_id)
ssh -o BatchMode=yes -o ConnectTimeout=8 "$PI_HOST" 'sudo -n systemctl reboot' >/dev/null 2>&1 || true
reconnected=0
for ((attempt = 0; attempt < 60; attempt++)); do
    NEW_BOOT_ID=$(ssh -o BatchMode=yes -o ConnectTimeout=3 "$PI_HOST" cat /proc/sys/kernel/random/boot_id 2>/dev/null || true)
    if [[ -n "$NEW_BOOT_ID" && "$NEW_BOOT_ID" != "$OLD_BOOT_ID" ]]; then
        reconnected=1
        break
    fi
    sleep 2
done
((reconnected)) || { echo "Pi did not return on SSH after reboot." >&2; exit 1; }

ssh -o BatchMode=yes "$PI_HOST" sudo -n sh -s -- "$VERSION" <<'REMOTE'
set -eu
expected_version=$1
systemctl is-active --quiet openrct2.service
systemctl is-active --quiet wg-quick@rglvps.service
actual_version=$(/usr/bin/openrct2-cli --version | sed -n '1s/.*v\([0-9][0-9.]*\).*/\1/p')
[ "$actual_version" = "$expected_version" ] || {
    echo "Post-reboot CLI reports $actual_version, expected $expected_version." >&2
    exit 1
}
journalctl -b -u openrct2.service --no-pager | grep -F 'Listening for clients on *:11753' >/dev/null
if journalctl -b -u openrct2.service --no-pager | grep -E 'Unable to open park|Object not found'; then
    echo "OpenRCT2 reported missing objects after reboot." >&2
    exit 1
fi
echo "Post-reboot check passed: OpenRCT2 $actual_version, service active, port 11753 listening, WireGuard active."
REMOTE

echo "Update complete: OpenRCT2 $VERSION is running on $PI_HOST."