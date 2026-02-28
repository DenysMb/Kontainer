/*
    SPDX-License-Identifier: GPL-3.0-or-later
    SPDX-FileCopyrightText: 2025 Denys Madureira <denysmb@zoho.com>
    SPDX-FileCopyrightText: 2025 Thomas Duckworth <tduck@filotimoproject.org>
*/

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

using namespace Qt::Literals::StringLiterals;

int main(int argc, char *argv[])
{
    KIconTheme::initTheme();

    QApplication app(argc, argv);

    if (qEnvironmentVariableIsEmpty("QT_QUICK_CONTROLS_STYLE")) {
        QQuickStyle::setStyle(u"org.kde.desktop"_s);
    }

    KLocalizedString::setApplicationDomain("kontainer");
    QApplication::setOrganizationName(u"DenysMb"_s);
    QApplication::setOrganizationDomain(u"io.github.DenysMb"_s);
    QApplication::setApplicationName(u"Kontainer"_s);
    QApplication::setDesktopFileName(u"io.github.DenysMb.Kontainer"_s);

    KAboutData aboutData(
        // The program name used internally.
        u"kontainer"_s,
        // A displayable program name string.
        i18nc("@title", "Kontainer"),
        // The program version string.
        QStringLiteral(KONTAINER_VERSION_STRING),
        // Short description of what the app does.
        i18n("Manage Distrobox containers"),
        // The license this code is released under.
        KAboutLicense::GPL_V3,
        // Copyright Statement.
        i18n("Denys Madureira (c) 2025"));
    aboutData.addAuthor(i18nc("@info:credit", "Denys Madureira"), i18nc("@info:credit", "Author"), u"denysmb@zoho.com"_s, u"https://invent.kde.org/denysmb"_s);
    aboutData.setTranslator(i18nc("NAME OF TRANSLATORS", "Your names"), i18nc("EMAIL OF TRANSLATORS", "Your emails"));
    KAboutData::setApplicationData(aboutData);

    QGuiApplication::setWindowIcon(QIcon::fromTheme(u"io.github.DenysMb.Kontainer"_s));

    QQmlApplicationEngine engine;

    // Create and register the DistroboxManager instance
    DistroboxManager *distroBoxManager = new DistroboxManager(&engine);
    engine.rootContext()->setContextProperty(u"distroBoxManager"_s, distroBoxManager);

    engine.rootContext()->setContextObject(new KLocalizedContext(&engine));
    engine.loadFromModule("io.github.DenysMb.Kontainer", "Main");

    if (engine.rootObjects().isEmpty()) {
        return -1;
    }

    return app.exec();
}
