# Qt Creator und Yocto-SDK fuer Raspberry Pi 4

## Verwendetes SDK

Fuer Qt-Anwendungen ist das SDK `meta-toolchain-qt6` zu verwenden, nicht das kleinere `rpi-openrct2`-SDK. Das hier erzeugte SDK ist fuer `raspberrypi4-64`/`cortexa72`, Qt 6.11.3 und Poky 6.0.4 gebaut. Das installierte Beispiel liegt unter `~/Qt/YoctoQt6113SDK`.

Installer und Manifeste liegen unter:

```text
build/tmp/deploy/sdk/
```

Den Installer `*meta-toolchain-qt6*cortexa72*toolchain-6.0.4.sh` ausfuehren und als Installationsziel `~/Qt/YoctoQt6113SDK` waehlen. Bei einer geaenderten Image-Konfiguration das SDK neu erzeugen und in ein neues Verzeichnis installieren, damit alte und neue Sysroots nicht vermischt werden.

Qt Creator selbst ist eine Host-Anwendung und nicht Teil dieses SDKs. Auf dem Entwicklungs-PC muss Qt Creator separat ueber dessen Linux-Paketverwaltung oder das offizielle Qt-Installationsverfahren installiert sein. Das Target-Qt aus dem Yocto-Sysroot nicht als Desktop-Qt auf dem Host installieren. Auf diesem Entwicklungs-PC ist `qtcreator` aktuell noch nicht installiert.

## Shell-Umgebung

Vor jedem Kommandozeilen-Build das vom SDK generierte Setup-Skript sourcen:

```sh
source ~/Qt/YoctoQt6113SDK/environment-setup-cortexa72-poky-linux
```

Es muss `source` (oder `. ...`) verwendet werden, nicht das direkte Ausfuehren des Skripts: Es exportiert Variablen in die aktuelle Shell. `LD_LIBRARY_PATH` muss vor dem Sourcen leer sein; das SDK-Skript bricht andernfalls absichtlich ab, weil Host-Bibliotheken den SDK-Compiler und dessen Werkzeuge stoeren koennen.

Wichtige Variablen des installierten SDK:

| Variable | Bedeutung |
| --- | --- |
| `SDKTARGETSYSROOT` | Target-Header, -Libraries und Target-Pakete fuer das Pi-System. |
| `CC`, `CXX`, `CPP` | AArch64-C-, C++- und Praeprozessor-Compiler samt Cortex-A72-Flags und `--sysroot`. |
| `AR`, `AS`, `LD`, `NM`, `RANLIB`, `STRIP`, `OBJCOPY`, `OBJDUMP`, `READELF` | Zum Cross-Compiler passende Binutils. |
| `GDB` | AArch64-GDB fuer Debugging auf dem Ziel oder remote. |
| `ARCH`, `CROSS_COMPILE`, `TARGET_PREFIX` | Kernel-/Make-Konventionen fuer Architektur und Toolnamen: `arm64` und `aarch64-poky-linux-`. |
| `CFLAGS`, `CXXFLAGS`, `CPPFLAGS`, `LDFLAGS` | Vorgesehene Optimierungs-, Debug- und Linker-Flags. Beim SDK-Build nicht durch Host-Flags ersetzen. |
| `PKG_CONFIG_SYSROOT_DIR` | Leitet `pkg-config` auf den Target-Sysroot um. |
| `PKG_CONFIG_PATH` | Target-`.pc`-Dateien fuer Libraries im Sysroot. |
| `PKG_CONFIG_SYSTEM_INCLUDE_PATH`, `PKG_CONFIG_SYSTEM_LIBRARY_PATH` | Korrigieren Include- und Library-Pfade fuer `pkg-config` im Cross-Build. |
| `CONFIG_SITE` | Target-Erkennung fuer Autoconf-Projekte, damit Configure-Tests nicht den Build-PC als Ziel behandeln. |
| `CMAKE_TOOLCHAIN_FILE` | Yocto-CMake-Toolchain-Datei; fuer CMake-Projekte relevant, nicht fuer qmake. |
| `OECORE_NATIVE_SYSROOT` | Host-Werkzeuge des SDKs, z. B. natives qmake, moc und weitere Qt-Tools. |
| `OECORE_TARGET_SYSROOT` | Entspricht dem Target-Sysroot und wird von Yocto-Werkzeugen verwendet. |
| `OECORE_TARGET_ARCH`, `OECORE_TARGET_OS`, `OECORE_TARGET_BITS`, `OECORE_TARGET_ENDIAN` | Target-Beschreibung fuer Buildsysteme: `aarch64`, Linux, 64 Bit, little-endian. |
| `OECORE_SDK_VERSION`, `OECORE_DISTRO_VERSION` | Versionen des erzeugenden SDKs und der Distribution. |
| `PATH` | Stellt natives qmake, Cross-Compiler und passende Werkzeuge vor Host-Versionen bereit. |

Qt Creator/qmake wird als Host-Werkzeug ausgefuehrt, kompiliert aber fuer AArch64. Deshalb nie das System-`qmake` des Build-PCs oder ein separates Desktop-Qt fuer diesen Kit nehmen.

## Qt Creator einrichten

Am zuverlaessigsten wird Qt Creator aus einer SDK-aktivierten Shell gestartet, damit die kompletten Yocto-Variablen an die IDE vererbt werden. Eine bereits laufende Qt-Creator-Instanz vorher schliessen: Ein zweiter Start kann sonst nur das Projekt an die alte Instanz weiterreichen, die noch die falsche Umgebung hat.

```sh
source ~/Qt/YoctoQt6113SDK/environment-setup-cortexa72-poky-linux
qtcreator
```

In **Preferences > Kits** einen eigenen Kit anlegen:

| Kit-Feld | Wert |
| --- | --- |
| C compiler | `aarch64-poky-linux-gcc` aus `sysroots/x86_64-pokysdk-linux/usr/bin/aarch64-poky-linux` |
| C++ compiler | `aarch64-poky-linux-g++` aus demselben Ordner |
| Debugger | `aarch64-poky-linux-gdb` aus demselben Ordner |
| Qt version | `sysroots/x86_64-pokysdk-linux/usr/bin/qmake` (Qt 6.11.3) |
| Sysroot | `sysroots/cortexa72-poky-linux` |
| Device | Generic Linux Device ueber SSH zum Pi, Benutzer `openrct2` (oder dein Firstboot-Benutzer) |

Im Kit als Build-Umgebung die oben genannten `source`-Anweisungen bzw. deren Variablen verwenden. Nicht den Ordner `sysroots/cortexa72-poky-linux/usr/bin/qmake` auswaehlen: Dieser waere ein Target-Programm und kann auf dem Entwicklungs-PC nicht laufen. Das SDK-qmake meldet `QMAKE_SPEC=linux-oe-g++` und `QMAKE_XSPEC=linux-oe-g++`.

Der SSH-Deploy braucht einen passenden privaten Schluessel im SSH-Agent oder in der Qt-Creator-Device-Konfiguration. Keine Schluessel oder Passwoerter in das Projekt oder diese Dokumentation eintragen.

Falls Qt Creator nicht aus der SDK-Shell gestartet werden soll, muessen die SDK-Variablen aus `environment-setup-cortexa72-poky-linux` in **Preferences > Kits > Environment** uebernommen werden. Mindestens `PATH`, `SDKTARGETSYSROOT`, `CC`, `CXX`, `CFLAGS`, `CXXFLAGS`, `LDFLAGS`, `PKG_CONFIG_SYSROOT_DIR`, `PKG_CONFIG_PATH` und `CONFIG_SITE` muessen zum selben SDK gehoeren. Nicht einzelne Pfade aus verschiedenen SDK-Installationen mischen.

## Kommandozeilen-Build

```sh
source ~/Qt/YoctoQt6113SDK/environment-setup-cortexa72-poky-linux
cd layers/meta-custom/examples/qt-qmake-smoke
qmake qt-qmake-smoke.pro
make -j2
file qt-qmake-smoke
```

`file` muss ein ELF 64-bit LSB executable fuer ARM aarch64 melden. Das Binary kann mit `scp` auf den Pi kopiert und dort ausgefuehrt werden, sofern die verwendeten Qt-Laufzeitpakete im Image vorhanden sind.

## qmake-Test

Das minimale Projekt unter `layers/meta-custom/examples/qt-qmake-smoke` verwendet ausschliesslich Qt Core. Dadurch prueft es qmake, Cross-Compiler, Qt-Header und Linker ohne zusaetzliche GUI-Plugins. `main.cpp` gibt Qt-Version und erkannte Architektur aus.