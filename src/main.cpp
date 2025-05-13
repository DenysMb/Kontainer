#include "distroboxmanager.h"
#include "version-kontainer.h"
#include <KAboutData>
#include <KIconTheme>
#include <KLocalizedContext>
#include <KLocalizedString>
#include <QApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QUrl>
#include <QtQml>

int main(int argc, char *argv[])
{
    KIconTheme::initTheme();

    QApplication app(argc, argv);

    if (qEnvironmentVariableIsEmpty("QT_QUICK_CONTROLS_STYLE")) {
        QQuickStyle::setStyle(QStringLiteral("org.kde.desktop"));
    }

    KLocalizedString::setApplicationDomain("kontainer");
    QApplication::setOrganizationName(QStringLiteral("DenysMb"));
    QApplication::setOrganizationDomain(QStringLiteral("io.github.DenysMb"));
    QApplication::setApplicationName(QStringLiteral("Kontainer"));
    QApplication::setDesktopFileName(QStringLiteral("io.github.DenysMb.Kontainer"));

    KAboutData aboutData(
        // The program name used internally.
        QStringLiteral("kontainer"),
        // A displayable program name string.
        i18nc("@title", "Kontainer"),
        // The program version string.
        QStringLiteral(KONTAINER_VERSION_STRING),
        // Short description of what the app does.
        i18n("Manage Distrobox containers."),
        // The license this code is released under.
        KAboutLicense::GPL_V3,
        // Copyright Statement.
        i18n("Denys Madureira (c) 2025"));
    aboutData.addAuthor(i18nc("@info:credit", "Denys Madureira"),
                        i18nc("@info:credit", "Author"),
                        QStringLiteral("denysmb@zoho.com"),
                        QStringLiteral("https://github.com/DenysMb/Kontainer"));
    aboutData.setTranslator(i18nc("NAME OF TRANSLATORS", "Your names"), i18nc("EMAIL OF TRANSLATORS", "Your emails"));
    KAboutData::setApplicationData(aboutData);

    QGuiApplication::setWindowIcon(QIcon::fromTheme(QStringLiteral("io.github.DenysMb.Kontainer")));

    QQmlApplicationEngine engine;

    // Create and register the DistroboxManager instance
    DistroboxManager *distroBoxManager = new DistroboxManager(&engine);
    engine.rootContext()->setContextProperty(QStringLiteral("distroBoxManager"), distroBoxManager);

    engine.rootContext()->setContextObject(new KLocalizedContext(&engine));
    engine.loadFromModule("io.github.DenysMb.Kontainer", "Main");

    if (engine.rootObjects().isEmpty()) {
        return -1;
    }

    return app.exec();
}
