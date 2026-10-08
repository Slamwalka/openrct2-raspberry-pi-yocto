SUMMARY = "OpenRCT2 - RollerCoaster Tycoon 2 reimplementation"
DESCRIPTION = "Free reimplementation of RollerCoaster Tycoon 2"
PV = "0.5.5"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${THISDIR}/files/LICENSE;md5=3be7b8b182ccd96e48989b4e57311193"

SRC_URI = "git://github.com/OpenRCT2/OpenRCT2.git;protocol=https;nobranch=1 \
    file://g2.dat \
    file://fonts.dat \
    file://palettes.dat \
    file://tracks.dat \
    file://openrct2-official-objects.tar.gz;name=openrct2objects;subdir=openrct2-objects-src \
"
SRC_URI[openrct2objects.sha256sum] = "94de35790ee385a598babde2822d103884d999973d47031d030eec3a698adbf0"
SRCREV = "8694e3483690323b6a75fa7264b6c58116f51f31"

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
