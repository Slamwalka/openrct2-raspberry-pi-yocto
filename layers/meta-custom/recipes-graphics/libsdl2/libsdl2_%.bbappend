EXTRA_OECMAKE:remove:class-target = "-DSDL_X11_XINPUT=OFF"
EXTRA_OECMAKE:append:class-target = " ${@bb.utils.contains('PACKAGECONFIG', 'x11', '-DSDL_X11_XINPUT=ON', '', d)}"
DEPENDS:append:class-target = " ${@bb.utils.contains('PACKAGECONFIG', 'x11', 'libxi', '', d)}"
RDEPENDS:${PN}:append:class-target = " ${@bb.utils.contains('PACKAGECONFIG', 'x11', 'libxi', '', d)}"
