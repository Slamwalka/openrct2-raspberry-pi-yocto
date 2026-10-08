SUMMARY = "OpenRCT2 latest-save server startup"
LICENSE = "CLOSED"

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI = " \
    file://openrct2-autosave-start.sh \
    file://openrct2.service \
    file://openrct2-config.ini \
"

inherit systemd

S = "${UNPACKDIR}"

RDEPENDS:${PN} = "openrct2 rct-game-data"
SYSTEMD_SERVICE:${PN} = "openrct2.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${UNPACKDIR}/openrct2-autosave-start.sh ${D}${bindir}/

    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${UNPACKDIR}/openrct2.service ${D}${systemd_system_unitdir}/

    install -d ${D}${sysconfdir}/skel/.config/OpenRCT2
    install -m 0644 ${UNPACKDIR}/openrct2-config.ini ${D}${sysconfdir}/skel/.config/OpenRCT2/config.ini
}

FILES:${PN} = " \
    ${bindir}/openrct2-autosave-start.sh \
    ${systemd_system_unitdir}/openrct2.service \
    ${sysconfdir}/skel/.config/OpenRCT2/config.ini \
"