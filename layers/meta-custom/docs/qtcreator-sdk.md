# Qt-Anwendungen mit dem Yocto-SDK bauen

Das optionale SDK ist fuer eigene Qt-Anwendungen gedacht. Fuer OpenRCT2 oder das Pi-Image brauchst du es nicht. Das hier beschriebene Target ist `raspberrypi4-64`/Cortex-A72 mit Qt 6.11.3.

## SDK bauen und installieren

Im Build-Verzeichnis des Repositories:

```sh
source ../layers/openembedded-core/oe-init-build-env .
BB_NUMBER_THREADS=8 PARALLEL_MAKE="-j 4" nice -n 19 bitbake meta-toolchain-qt6
```

Der Installer liegt unter `tmp/deploy/sdk/`. Fuehre die passende Datei mit `cortexa72` und der verwendeten Poky-Version aus und installiere sie zum Beispiel nach `~/Qt/YoctoQt6113SDK`.

## SDK-Umgebung laden

Vor jedem Kommandozeilen-Build:

```sh
source ~/Qt/YoctoQt6113SDK/environment-setup-cortexa72-poky-linux
```

Das Skript muss in der aktuellen Shell geladen werden. Es setzt Cross-Compiler, Qt-Werkzeuge und Target-Sysroot. Ein Cross-Compiler baut fuer ARM64 auf dem Pi; das SDK-`qmake` laeuft dagegen als Werkzeug auf dem Linux-Build-PC. Verwende nicht das System-`qmake` des PCs und nicht `qmake` aus dem Target-Sysroot.

`SDKTARGETSYSROOT` zeigt auf Header und Bibliotheken fuer den Pi. `CC` und `CXX` sind die Cross-Compiler. `PKG_CONFIG_SYSROOT_DIR` sorgt dafuer, dass `pkg-config` nicht versehentlich Bibliotheken des PCs verwendet. Die vom SDK gesetzten Flags nicht durch Host-Flags ersetzen.

## Qt Creator einrichten

Installiere Qt Creator getrennt auf dem Build-PC und starte ihn aus einer SDK-aktivierten Shell:

```sh
source ~/Qt/YoctoQt6113SDK/environment-setup-cortexa72-poky-linux
qtcreator
```

Lege in **Preferences > Kits** einen Kit fuer Linux/GCC an und waehle:

- C-Compiler: `aarch64-poky-linux-gcc`
- C++-Compiler: `aarch64-poky-linux-g++`
- Debugger: `aarch64-poky-linux-gdb`
- Qt-Version: das `qmake` unter `sysroots/x86_64-pokysdk-linux/usr/bin/`
- Sysroot: `sysroots/cortexa72-poky-linux`

Die konkreten Pfade stehen im Installationsverzeichnis des SDKs. Nicht Host-Qt, Target-qmake und Compiler aus verschiedenen SDKs mischen. Fuer Deploy ueber SSH muss der passende private Schluessel lokal im SSH-Agent oder in Qt Creator eingetragen sein; ihn nie ins Repository kopieren.

## SDK testen

Das Beispiel unter `layers/meta-custom/examples/qt-qmake-smoke` nutzt nur Qt Core:

```sh
source ~/Qt/YoctoQt6113SDK/environment-setup-cortexa72-poky-linux
mkdir -p /tmp/qt-qmake-smoke-build
cd /tmp/qt-qmake-smoke-build
qmake /pfad/zum/rpi-openrct2/layers/meta-custom/examples/qt-qmake-smoke/qt-qmake-smoke.pro
make -j2
file qt-qmake-smoke
```

`file` soll ein 64-Bit-ELF fuer ARM AArch64 melden. Das Programm laesst sich zum Laufzeittest per SSH auf den Pi kopieren, wenn die benoetigten Qt-Laufzeitpakete im Image installiert sind.