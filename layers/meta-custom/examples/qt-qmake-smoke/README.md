# Qt qmake Smoke Test

Kleines Qt-Core-Programm zum Testen des Yocto-Qt-SDKs für Raspberry Pi 4 / Cortex-A72. Es gibt Qt-Version, Zielarchitektur und Betriebssystem aus.

SDK laden und ausserhalb des Quellordners bauen:

```sh
source ~/Qt/YoctoQt6113SDK/environment-setup-cortexa72-poky-linux
mkdir -p /tmp/qt-qmake-smoke-build
cd /tmp/qt-qmake-smoke-build
qmake /path/to/meta-custom/examples/qt-qmake-smoke/qt-qmake-smoke.pro
make -j2
file qt-qmake-smoke
```

`file` soll `ELF 64-bit LSB pie executable, ARM aarch64` melden. Das Binary kann zum Laufzeittest auf den Pi kopiert werden:

```sh
scp qt-qmake-smoke openrct2@rpi-openrct2.local:/tmp/
ssh openrct2@rpi-openrct2.local /tmp/qt-qmake-smoke
```