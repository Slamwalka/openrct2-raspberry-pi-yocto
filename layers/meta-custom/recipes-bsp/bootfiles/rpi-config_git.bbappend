RPI_OPENRCT2_DSI_ROTATION ?= "0"
RPI_EXTRA_CONFIG:append:raspberrypi4-64 = "dtoverlay=vc4-kms-dsi-7inch${@bb.utils.contains('RPI_OPENRCT2_DSI_ROTATION', '180', ',invx,invy', '', d)}"