SUMMARY = "Interactive first-boot user setup for the Raspberry Pi image"
LICENSE = "CLOSED"

FILESEXTRAPATHS:prepend := "${TOPDIR}/local-assets:${THISDIR}/../images/files:"
SRC_URI = "file://firstboot-user-setup \
           file://rpi-firstboot-user-setup.service \
           file://authorized_keys.example \
"

S = "${UNPACKDIR}"

inherit systemd

RDEPENDS:${PN} = "shadow sudo"

SYSTEMD_SERVICE:${PN} = "rpi-firstboot-user-setup.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

do_install() {
    install -d ${D}${libexecdir}
    install -m 0755 ${UNPACKDIR}/firstboot-user-setup ${D}${libexecdir}/rpi-firstboot-user-setup

    install -d ${D}${datadir}/rpi-firstboot
    install -m 0644 ${UNPACKDIR}/authorized_keys.example ${D}${datadir}/rpi-firstboot/authorized_keys

    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${UNPACKDIR}/rpi-firstboot-user-setup.service ${D}${systemd_system_unitdir}/
}

FILES:${PN} += "${libexecdir}/rpi-firstboot-user-setup ${datadir}/rpi-firstboot/authorized_keys ${systemd_system_unitdir}/rpi-firstboot-user-setup.service"