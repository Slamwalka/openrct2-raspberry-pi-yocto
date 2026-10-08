SUMMARY = "Local RCT1 and RCT2 game data for OpenRCT2"
DESCRIPTION = "Original game data copied from the locally licensed NAS installation"
LICENSE = "CLOSED"

FILESEXTRAPATHS:prepend := "${THISDIR}/../openrct2/files:"
SRC_URI = "file://rct-game-data.tar.gz;name=rctgamedata;subdir=rct-game-data-src"
SRC_URI[rctgamedata.sha256sum] = "61f1171b41330d0e739ad4e73850df0f1df1d0a124ace38944d0cbb521285e3e"

S = "${UNPACKDIR}"

do_install() {
    install -d ${D}${datadir}/rct-game-data
    cp -R ${UNPACKDIR}/rct-game-data-src/RCT ${D}${datadir}/rct-game-data/
    cp -R ${UNPACKDIR}/rct-game-data-src/RCT2 ${D}${datadir}/rct-game-data/
    chown -R root:root ${D}${datadir}/rct-game-data
    chmod -R a+rX,u+w,go-w ${D}${datadir}/rct-game-data
}
do_install[fakeroot] = "1"

FILES:${PN} = "${datadir}/rct-game-data"