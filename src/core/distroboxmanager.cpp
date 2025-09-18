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
#include <QDebug>
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
    qDebug() << "=== availableApps for container:" << container << "===";

    QString findCmd = QStringLiteral("find /usr/share/applications -type f -name '*.desktop' ! -exec grep -q '^NoDisplay=true' {} \\; -print");
    QString output = u"distrobox enter %1 -- sh -c %2"_s.arg(container, KShell::quoteArg(findCmd));
    bool success = false;
    QString raw = DistroboxCli::runCommand(output, success);
    QVariantList list;
    if (!success) {
        qDebug() << "Find command failed for container:" << container;
        return list;
    }

    for (const QString &line : raw.split(QChar::fromLatin1('\n'), Qt::SkipEmptyParts)) {
        if (!line.endsWith(QStringLiteral(".desktop"))) {
            continue;
        }

        // Extract basename from the full path
        QString basename = line;
        if (basename.startsWith(QStringLiteral("/usr/share/applications/"))) {
            basename.remove(0, 24);
        }
        if (basename.endsWith(QStringLiteral(".desktop"))) {
            basename.chop(8);
        }

        // Read desktop file from container
        QString readCmd = QStringLiteral("cat %1").arg(KShell::quoteArg(line));
        QString desktopOutput = u"distrobox enter %1 -- sh -c %2"_s.arg(container, KShell::quoteArg(readCmd));
        bool readSuccess = false;
        QString desktopContent = DistroboxCli::runCommand(desktopOutput, readSuccess);

        if (!readSuccess) {
            continue;
        }

        // Parse desktop file content with proper localization handling
        QVariantMap app;
        app[QStringLiteral("basename")] = basename;

        QString name = basename;
        QString icon;
        QString genericName; // For debugging

        // Prefer English name, fall back to generic name
        QString englishName;

        for (const QString &desktopLine : desktopContent.split(QChar::fromLatin1('\n'), Qt::SkipEmptyParts)) {
            if (desktopLine.startsWith(QStringLiteral("Name[en]="))) {
                englishName = desktopLine.mid(8); // Remove "Name[en]="
            } else if (desktopLine.startsWith(QStringLiteral("Name=")) && name == basename) {
                name = desktopLine.mid(5); // Remove "Name=" (only use as fallback)
            } else if (desktopLine.startsWith(QStringLiteral("Icon="))) {
                icon = desktopLine.mid(5); // Remove "Icon="
            } else if (desktopLine.startsWith(QStringLiteral("GenericName="))) {
                genericName = desktopLine.mid(12); // For debugging
            }
        }

        // Prefer English name if available
        if (!englishName.isEmpty()) {
            name = englishName;
        }

        app[QStringLiteral("name")] = name;
        app[QStringLiteral("icon")] = icon;
        app[QStringLiteral("genericName")] = genericName; // For debugging
        app[QStringLiteral("sourceFile")] = line; // For debugging

        qDebug() << "App:" << name << "| Basename:" << basename << "| Generic:" << genericName << "| Source:" << line;
        list << app;
    }

    qDebug() << "Total apps found:" << list.size();
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
        if (!fileName.endsWith(QStringLiteral(".desktop"))) {
            continue;
        }

        // Extract basename
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
        QString icon = desktop.value(QStringLiteral("Desktop Entry/Icon"), QString()).toString();

        app[QStringLiteral("name")] = fullName.section(QStringLiteral(" (on "), 0, 0);
        app[QStringLiteral("icon")] = icon;
        app[QStringLiteral("fileName")] = fileName; // For debugging

        qDebug() << "Exported app:" << app[QStringLiteral("name")].toString() << "| Basename:" << basename << "| File:" << fileName;
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
    QString output = DistroboxCli::runCommand(command, success);

    qDebug() << "Export" << basename << ":" << (success ? "SUCCESS" : "FAILED") << "Output:" << output;
    return success;
}

bool DistroboxManager::unexportApp(const QString &basename, const QString &container)
{
    qDebug() << "Attempting to unexport:" << basename << "from:" << container;

    // First try with just the basename (how distrobox-export expects it)
    QString command = u"distrobox enter %1 -- distrobox-export --app %2 --delete"_s.arg(KShell::quoteArg(container), KShell::quoteArg(basename));

    bool success;
    QString output = DistroboxCli::runCommand(command, success);

    if (success) {
        qDebug() << "Unexport successful with basename:" << basename;
        return true;
    }

    qDebug() << "First attempt failed, trying with full path...";

    // If that fails, try with the full path
    QString desktopPath = QStringLiteral("/usr/share/applications/") + basename + QStringLiteral(".desktop");
    QString altCommand = u"distrobox enter %1 -- distrobox-export --app %2 --delete"_s.arg(KShell::quoteArg(container), KShell::quoteArg(desktopPath));

    output = DistroboxCli::runCommand(altCommand, success);

    if (success) {
        qDebug() << "Unexport successful with full path:" << desktopPath;
        return true;
    }

    qDebug() << "All unexport attempts failed for:" << basename;
    qDebug() << "Output:" << output;

    // As a last resort, try to manually remove the desktop file
    QString appsPath = QStandardPaths::writableLocation(QStandardPaths::ApplicationsLocation);
    if (DistroboxCli::isFlatpak()) {
        appsPath = QDir::homePath() + QStringLiteral("/.local/share/applications");
    }

    QString desktopFileName = container + QLatin1String("-") + basename + QLatin1String(".desktop");
    QFile desktopFile(appsPath + QLatin1String("/") + desktopFileName);

    if (desktopFile.exists()) {
        qDebug() << "Attempting manual removal of:" << desktopFileName;
        if (desktopFile.remove()) {
            qDebug() << "Manual removal successful";
            return true;
        } else {
            qDebug() << "Manual removal failed";
        }
    }

    return false;
}
