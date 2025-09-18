/*
    SPDX-License-Identifier: GPL-3.0-or-later
    SPDX-FileCopyrightText: 2025 Denys Madureira <denysmb@zoho.com>
    SPDX-FileCopyrightText: 2025 Thomas Duckworth <tduck@filotimoproject.org>
    SPDX-FileCopyrightText: 2025 Hadi Chokr <hadichokr@icloud.com>
*/

#include "distroboxmanager.h"
#include "distroboxcli.h"
#include "distrocolors.h"
#include "packageinstallcommand.h"
#include "terminallauncher.h"
#include <KLocalizedContext>
#include <KLocalizedString>
#include <KShell>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QRegularExpression>
#include <QSettings>
#include <QStandardPaths>
#include <QTextStream>

using namespace Qt::Literals::StringLiterals;

// Constructor: Initializes the manager and populates available images lists
DistroboxManager::DistroboxManager(QObject *parent)
    : QObject(parent)
{
    const auto images = DistroboxCli::availableImages();
    m_availableImages = images.displayNames;
    m_fullImageNames = images.fullNames;
}

// Lists all existing containers and their base images in JSON format
QString DistroboxManager::listContainers()
{
    return DistroboxCli::containersJson();
}

// Lists all available container images in JSON format
QString DistroboxManager::listAvailableImages()
{
    if (m_availableImages.isEmpty() || m_fullImageNames.isEmpty()) {
        const auto images = DistroboxCli::availableImages();
        m_availableImages = images.displayNames;
        m_fullImageNames = images.fullNames;
    }

    return DistroboxCli::availableImagesJson(DistroboxCli::AvailableImages{m_availableImages, m_fullImageNames});
}

// Creates a new container with specified name and base image
bool DistroboxManager::createContainer(const QString &name, const QString &image, const QString &args)
{
    // Construct distrobox create command
    QString command = u"distrobox create --name %1 --image %2 --yes"_s.arg(name, image);
    if (!args.isEmpty()) {
        command += QLatin1Char(' ') + args;
    }

    bool success;
    DistroboxCli::runCommand(command, success);
    return success;
}

// Opens an interactive shell in the specified container
bool DistroboxManager::enterContainer(const QString &name)
{
    const QString command = u"distrobox enter %1"_s.arg(name);
    return launchCommandInTerminal(command);
}

// Removes a container
bool DistroboxManager::removeContainer(const QString &name)
{
    // Use -f flag to force removal without confirmation
    QString command = u"distrobox rm -f %1"_s.arg(name);
    bool success;
    DistroboxCli::runCommand(command, success);
    return success;
}

// Upgrades all packages in a container
bool DistroboxManager::upgradeContainer(const QString &name)
{
    QString message = i18n("Press any key to close this terminal…");
    QString upgradeCmd = u"distrobox upgrade %1 && echo '' && echo '%2' && read -s -n 1"_s.arg(name, message);
    QString command = u"bash -c \"%1\""_s.arg(upgradeCmd);

    return launchCommandInTerminal(command);
}

bool DistroboxManager::launchCommandInTerminal(const QString &command, const QString &workingDirectory)
{
    return TerminalLauncher::launch(command, workingDirectory, this);
}

// Returns a color associated with the distribution for UI purposes
QString DistroboxManager::getDistroColor(const QString &image)
{
    return DistroColors::colorForImage(image);
}

// Generates .desktop files for applications in containers
bool DistroboxManager::generateEntry(const QString &name)
{
    QString command;
    if (name.isEmpty()) {
        // Generate entries for all containers
        command = u"distrobox generate-entry -a"_s;
    } else {
        // Generate entries for specific container
        command = u"distrobox generate-entry %1"_s.arg(name);
    }

    bool success;
    DistroboxCli::runCommand(command, success);
    return success;
}

// Installs a package file in a container using the appropriate package manager
bool DistroboxManager::installPackageInContainer(const QString &name, const QString &packagePath, const QString &image)
{
    QString homeDir = QDir::homePath();
    // Remove "file://" prefix if present
    QString actualPackagePath = packagePath;
    if (actualPackagePath.startsWith(u"file://"_s)) {
        actualPackagePath = actualPackagePath.mid(7);
    }

    const auto installCmd = PackageInstallCommand::forImage(image, actualPackagePath);
    if (!installCmd) {
        // Show error message if distribution is not recognized
        QString message = i18n(
            "Cannot automatically install packages for this distribution. Please enter the distrobox manually and install it using the appropriate package "
            "manager.");
        QString script = u"echo "_s + KShell::quoteArg(message) + u"; read -n 1"_s;
        QString command = u"bash -c "_s + KShell::quoteArg(script);
        return launchCommandInTerminal(command, homeDir);
    }

    // Run installation command in container and wait for user input before closing
    QString message = i18n("Press any key to close this terminal…");
    QString fullCmd = u"distrobox enter %1 -- bash -c \"%2 && echo '' && echo '%3' && read -s -n 1\""_s.arg(name, *installCmd, message);
    QString command = u"bash -c "_s + KShell::quoteArg(fullCmd);
    return launchCommandInTerminal(command, homeDir);
}

bool DistroboxManager::isFlatpak() const
{
    return DistroboxCli::isFlatpak();
}

QVariantList DistroboxManager::availableApps(const QString &container)
{
    QString findCmd = QStringLiteral("find /usr/share/applications -type f -name '*.desktop' ! -exec grep -q '^NoDisplay=true' {} \\; -print");
    QString output = u"distrobox enter %1 -- sh -c %2"_s.arg(container, KShell::quoteArg(findCmd));
    bool success = false;
    QString raw = DistroboxCli::runCommand(output, success);
    QVariantList list;
    if (!success)
        return list;

    for (const QString &line : raw.split(QChar::fromLatin1('\n'), Qt::SkipEmptyParts)) {
        if (!line.endsWith(QStringLiteral(".desktop")))
            continue;

        // Extract basename from the full path (remove /usr/share/applications/ and .desktop)
        QString basename = line;
        if (basename.startsWith(QStringLiteral("/usr/share/applications/"))) {
            basename.remove(0, 24); // Remove "/usr/share/applications/"
        }
        if (basename.endsWith(QStringLiteral(".desktop"))) {
            basename.chop(8); // Remove ".desktop"
        }

        // Read desktop file from container
        QString readCmd = QStringLiteral("cat %1").arg(KShell::quoteArg(line));
        QString desktopOutput = u"distrobox enter %1 -- sh -c %2"_s.arg(container, KShell::quoteArg(readCmd));
        bool readSuccess = false;
        QString desktopContent = DistroboxCli::runCommand(desktopOutput, readSuccess);

        if (!readSuccess)
            continue;

        // Parse desktop file content line by line
        QVariantMap app;
        app[QStringLiteral("basename")] = basename;

        QString name = basename;
        QString icon;

        for (const QString &desktopLine : desktopContent.split(QChar::fromLatin1('\n'), Qt::SkipEmptyParts)) {
            if (desktopLine.startsWith(QStringLiteral("Name="))) {
                name = desktopLine.mid(5); // Remove "Name="
            } else if (desktopLine.startsWith(QStringLiteral("Icon="))) {
                icon = desktopLine.mid(5); // Remove "Icon="
            }
        }

        app[QStringLiteral("name")] = name;
        app[QStringLiteral("icon")] = icon;

        list << app;
    }
    return list;
}

QVariantList DistroboxManager::exportedApps(const QString &container)
{
    QString appsPath = QStandardPaths::writableLocation(QStandardPaths::ApplicationsLocation);
    if (DistroboxCli::isFlatpak()) {
        appsPath = QDir::homePath() + QStringLiteral("/.local/share/applications");
    }

    QVariantList list;
    QDir dir(appsPath);
    QStringList patterns;
    patterns << QStringLiteral("%1-*.desktop").arg(container);

    for (const QFileInfo &file : dir.entryInfoList(patterns, QDir::Files)) {
        QString fileName = file.fileName();
        if (!fileName.endsWith(QStringLiteral(".desktop")))
            continue;

        // Extract basename (remove container prefix and .desktop suffix)
        QString basename = fileName;
        QString prefix = container + QLatin1String("-");
        if (basename.startsWith(prefix)) {
            basename.remove(0, prefix.length());
        }
        if (basename.endsWith(QStringLiteral(".desktop"))) {
            basename.chop(8);
        }

        QSettings desktop(file.filePath(), QSettings::IniFormat);
        QVariantMap app;
        app[QStringLiteral("basename")] = basename;

        QString fullName = desktop.value(QStringLiteral("Desktop Entry/Name"), basename).toString();
        app[QStringLiteral("name")] = fullName.section(QStringLiteral(" (on "), 0, 0);
        app[QStringLiteral("icon")] = desktop.value(QStringLiteral("Desktop Entry/Icon"), QString()).toString();

        list << app;
    }
    return list;
}

bool DistroboxManager::exportApp(const QString &basename, const QString &container)
{
    // Construct the full path to the desktop file in the container
    QString desktopPath = QStringLiteral("/usr/share/applications/") + basename + QStringLiteral(".desktop");
    QString command = u"distrobox enter %1 -- distrobox-export --app %2"_s.arg(KShell::quoteArg(container), KShell::quoteArg(desktopPath));
    bool success;
    DistroboxCli::runCommand(command, success);
    return success;
}

bool DistroboxManager::unexportApp(const QString &basename, const QString &container)
{
    // Use the basename directly (distrobox-export will handle the container path internally)
    QString command = u"distrobox enter %1 -- distrobox-export --app %2 --delete"_s.arg(KShell::quoteArg(container), KShell::quoteArg(basename));
    bool success;
    DistroboxCli::runCommand(command, success);
    return success;
}
