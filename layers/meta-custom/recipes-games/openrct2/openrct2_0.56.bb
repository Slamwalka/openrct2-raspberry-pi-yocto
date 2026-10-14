SUMMARY = "OpenRCT2 - RollerCoaster Tycoon 2 reimplementation"
DESCRIPTION = "Free reimplementation of RollerCoaster Tycoon 2 (0.5.6)"
PV = "0.5.6"
OPENRCT2_DATA_VERSION = "0.5.6"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${THISDIR}/files/LICENSE;md5=3be7b8b182ccd96e48989b4e57311193"

SRC_URI = "git://github.com/OpenRCT2/OpenRCT2.git;protocol=https;nobranch=1 \
    file://0001-openrct2-add-optional-display-rotation.patch \
    file://0002-openrct2-pause-when-no-active-players.patch \
    file://0003-openrct2-pause-server-if-only-spectators.patch \
    file://0004-openrct2-blank-paused-spectator.patch \
    file://0005-openrct2-switch-off-paused-backlight.patch \
    file://0006-openrct2-spectator-auto-tour.patch \
    file://0007-openrct2-guard-missing-title-sequence.patch \
    file://0008-openrct2-fade-paused-backlight.patch \
    file://0009-openrct2-fade-paused-framebuffer.patch \
    file://0010-openrct2-delay-rapid-rejoins.patch \
    file://0011-openrct2-hide-idle-touch-cursor.patch \
    file://0012-openrct2-freeze-effects-during-auto-pause.patch \
    file://0013-openrct2-time-double-tap-from-release.patch \
    file://0014-openrct2-use-touch-coordinates-for-drag.patch \
    file://0015-openrct2-preserve-x11-touch-window-coordinates.patch \
    file://g2.dat \
    file://fonts.dat \
    file://palettes.dat \
    file://tracks.dat \
    file://openrct2.parkseq \
    file://rct1.parkseq \
    file://rct1aa.parkseq \
    file://rct1aall.parkseq \
    file://rct2.parkseq \
    file://openrct2-official-objects.tar.gz;name=openrct2objects;subdir=openrct2-objects-src \
"
SRC_URI[openrct2objects.sha256sum] = "c0800bcaa0a328f71a1ef6a40e0057bf2e7f3cc9557df7a74e2f07825e949e76"
SRCREV = "82b309798a83346b7f9fc61a53847f4323deb19d"

inherit cmake

DEPENDS = " \
    pkgconfig-native \
    pkgconfig \
    libsdl2 \
    icu \
    libzip \
    libpng \
    curl \
    openssl \
    freetype \
    fontconfig \
    zlib \
    nlohmann-json \
    speexdsp \
    mesa \
    libvorbis \
    libogg \
    flac \
"

RDEPENDS:${PN} = " \
    libsdl2 \
    icu \
    libzip \
    libpng \
    curl \
    openssl \
    freetype \
    fontconfig \
    zlib \
    speexdsp \
    mesa \
    libvorbis \
    libogg \
    flac \
"

EXTRA_OECMAKE += " \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_STANDARD=20 \
    -DCMAKE_CXX_STANDARD_REQUIRED=ON \
    -DENABLE_SCRIPTING=ON \
    -DENABLE_WEBPACK=OFF \
"

export PKG_CONFIG_PATH = "${STAGING_DIR_HOST}/usr/lib/pkgconfig"
export PKG_CONFIG_SYSROOT_DIR = "${STAGING_DIR_HOST}"

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${B}/openrct2 ${D}${bindir}/
    install -m 0755 ${B}/openrct2-cli ${D}${bindir}/

    install -d ${D}${datadir}/openrct2
    install -m 0644 ${UNPACKDIR}/g2.dat       ${D}${datadir}/openrct2/
    install -m 0644 ${UNPACKDIR}/fonts.dat    ${D}${datadir}/openrct2/
    install -m 0644 ${UNPACKDIR}/palettes.dat ${D}${datadir}/openrct2/
    install -m 0644 ${UNPACKDIR}/tracks.dat   ${D}${datadir}/openrct2/

    install -d ${D}${datadir}/openrct2/sequence
    for sequence in openrct2.parkseq rct1.parkseq rct1aa.parkseq rct1aall.parkseq rct2.parkseq; do
        install -m 0644 ${UNPACKDIR}/$sequence ${D}${datadir}/openrct2/sequence/
    done

    cp -r ${S}/data/* ${D}${datadir}/openrct2/
    install -d ${D}${datadir}/openrct2/object
    cp -a ${UNPACKDIR}/openrct2-objects-src/. ${D}${datadir}/openrct2/object/
    chown -R root:root ${D}${datadir}/openrct2/object
    chmod -R a+rX,u+w,go-w ${D}${datadir}/openrct2/object
}
do_install[fakeroot] = "1"

FILES:${PN} = " \
    ${bindir}/openrct2 \
    ${bindir}/openrct2-cli \
    ${datadir}/openrct2 \
"

# OpenRCT2 disables char8_t; keep nlohmann-json on its compatible pre-C++20 path.
CXXFLAGS:append = " -DJSON_HAS_CPP_17 -DJSON_HAS_CPP_14 -DJSON_HAS_CPP_11"
