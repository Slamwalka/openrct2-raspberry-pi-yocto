require recipes-core/images/core-image-minimal.bb

DESCRIPTION = "Pi image for OpenRCT2 + WireGuard"

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
}
do_custom_setup[fakeroot] = "1"
addtask do_custom_setup after do_rootfs before do_image

SYSTEMD_AUTO_ENABLE:avahi-daemon = "enable"
