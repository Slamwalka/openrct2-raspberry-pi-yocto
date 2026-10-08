#include <QCoreApplication>
#include <QSysInfo>
#include <QDebug>

int main(int argc, char *argv[])
{
    QCoreApplication application(argc, argv);

    qInfo().noquote() << "Qt version:" << QT_VERSION_STR;
    qInfo().noquote() << "Architecture:" << QSysInfo::currentCpuArchitecture();
    qInfo().noquote() << "Product:" << QSysInfo::prettyProductName();

    return 0;
}