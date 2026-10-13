RPI_OPENRCT2_DSI_ROTATION ?= "0"
CMDLINE:append:raspberrypi4-64 = "${@bb.utils.contains('RPI_OPENRCT2_DSI_ROTATION', '180', ' video=DSI-1:800x480@60,rotate=180', '', d)}"