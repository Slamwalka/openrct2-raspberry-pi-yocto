require recipes-core/images/core-image-minimal.bb

DESCRIPTION = "Pi image for OpenRCT2 + WireGuard"
RPI_OPENRCT2_TIMEZONE ?= "Europe/Busingen"

DISTRO_FEATURES:append = " x11"
IMAGE_FEATURES += "ssh-server-openssh package-management"
IMAGE_FEATURES:remove = "allow-root-login allow-empty-password"

IMAGE_INSTALL:append = " \
    wireguard-tools \
    openssh-sftp-server \
    rsync \
    xauth \
    xserver-xorg \
    xserver-xorg-extension-glx \
    xf86-input-evdev \
    xf86-video-modesetting \
    avahi-daemon \
    parted \
    e2fsprogs \
    e2fsprogs-resize2fs \
    qtbase \
    qtbase-dev \
    qtdeclarative \
    qtmultimedia \
    qtcharts \
    qtsvg \
    qtimageformats \
    qtserialport \
    qttools \
    qttranslations \
    fontconfig-utils \
    ttf-dejavu-sans \
    sudo \
    shadow \
    rpi-firstboot-user-setup \
    rct-game-data \
    rpi-openrct2-runtime \
    cifs-utils \
    kernel-module-cifs \
    tzdata-core \
    tzdata-europe \
    nano \
    openrct2 \
"

MACHINE_FEATURES:append = " vc4graphics"
IMAGE_ROOTFS_EXTRA_SPACE = "2000000"
HOSTNAME = "rpi-openrct2"

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

do_custom_setup() {
    # sshd_config
    install -d ${IMAGE_ROOTFS}/etc/ssh
    install -m 0644 ${THISDIR}/files/sshd_config ${IMAGE_ROOTFS}/etc/ssh/sshd_config

    # Resize-Service
    install -d ${IMAGE_ROOTFS}/etc/systemd/system
    install -m 0644 ${THISDIR}/files/resize-rootfs.service ${IMAGE_ROOTFS}/etc/systemd/system/
    install -d ${IMAGE_ROOTFS}/etc/systemd/system/multi-user.target.wants
    ln -sf /etc/systemd/system/resize-rootfs.service ${IMAGE_ROOTFS}/etc/systemd/system/multi-user.target.wants/resize-rootfs.service
    echo "rpi-openrct2" > ${IMAGE_ROOTFS}/etc/hostname

    # Local timezone
    [ -e ${IMAGE_ROOTFS}${datadir}/zoneinfo/${RPI_OPENRCT2_TIMEZONE} ] || { echo "Unknown timezone: ${RPI_OPENRCT2_TIMEZONE}" >&2; exit 1; }
    ln -sfn /usr/share/zoneinfo/${RPI_OPENRCT2_TIMEZONE} ${IMAGE_ROOTFS}/etc/localtime
    printf '%s\n' ${RPI_OPENRCT2_TIMEZONE} > ${IMAGE_ROOTFS}/etc/timezone
}
do_custom_setup[fakeroot] = "1"
addtask do_custom_setup after do_rootfs before do_image

SYSTEMD_AUTO_ENABLE:avahi-daemon = "enable"
