#include <QApplication>
#include <QQmlApplicationEngine>
#include <QtQml>
#include <QUrl>
#include <QQuickStyle>
#include <QIcon>
#include <KLocalizedContext>
#include <KLocalizedString>
#include <KIconTheme>
#include "distroboxmanager.h"

int main(int argc, char *argv[])
{
    KIconTheme::initTheme();
    QApplication app(argc, argv);
    KLocalizedString::setApplicationDomain("kontainer");
    QApplication::setOrganizationName(QStringLiteral("KDE"));
    QApplication::setOrganizationDomain(QStringLiteral("kde.org"));
    QApplication::setApplicationName(QStringLiteral("Kontainer"));
    QApplication::setDesktopFileName(QStringLiteral("io.github.DenysMb.Kontainer"));

    QApplication::setStyle(QStringLiteral("breeze"));
    if (qEnvironmentVariableIsEmpty("QT_QUICK_CONTROLS_STYLE"))
    {
        QQuickStyle::setStyle(QStringLiteral("org.kde.desktop"));
    }

    QGuiApplication::setWindowIcon(QIcon::fromTheme(QStringLiteral("io.github.DenysMb.Kontainer")));

    QQmlApplicationEngine engine;

    // Create and register the DistroboxManager instance
    DistroboxManager *distroBoxManager = new DistroboxManager(&engine);
    engine.rootContext()->setContextProperty(QStringLiteral("distroBoxManager"), distroBoxManager);

    engine.rootContext()->setContextObject(new KLocalizedContext(&engine));
    engine.loadFromModule("io.github.DenysMb.Kontainer", "Main");

    if (engine.rootObjects().isEmpty())
    {
        return -1;
    }

    return app.exec();
}
