/*
 *   SPDX-License-Identifier: GPL-3.0-or-later
 *   SPDX-FileCopyrightText: 2025 Denys Madureira <denysmb@zoho.com>
 *   SPDX-FileCopyrightText: 2025 Thomas Duckworth <tduck@filotimoproject.org>
 *   SPDX-FileCopyrightText: 2025 Hadi Chokr <hadichokr@icloud.com>
 */

#include "distroboxmanager.h"
#include "distroboxcli.h"
#include "distrocolors.h"
#include "packageinstallcommand.h"
#include "terminallauncher.h"
#include <KLocalizedContext>
#include <KLocalizedString>
#include <KShell>
#include <QByteArray>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QHash>
#include <QPointer>
#include <QRegularExpression>
#include <QSettings>
#include <QStandardPaths>
#include <QTextStream>
#include <QUrl>
#include <distroicons.h>

using namespace Qt::Literals::StringLiterals;

namespace
{
QString ensureIconCacheDirectory(const QString &container)
{
    const QString cacheBase = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
    if (cacheBase.isEmpty()) {
        return {};
    }

    QDir cacheDir(cacheBase);
    const QString iconsRoot = cacheDir.filePath(QStringLiteral("kontainer/icons/%1").arg(container));
    QDir().mkpath(iconsRoot);
    return iconsRoot;
}

QString runContainerCommand(const QString &container, const QString &script, bool &success)
{
    const QString command = u"distrobox enter %1 -- /usr/bin/env sh -c %2"_s.arg(container, KShell::quoteArg(script));
    return DistroboxCli::runCommand(command, success);
}

QString resolveIconPathInContainer(const QString &container, const QString &iconValue)
{
    if (iconValue.trimmed().isEmpty()) {
        return {};
    }

    // Create a Python script file to avoid complex shell quoting
    const QString pythonScript = QStringLiteral(
        "import os, sys\n"
        "icon = sys.argv[1]\n"
        "if not icon:\n"
        "    sys.exit(1)\n"
        "if os.path.isabs(icon) and os.path.exists(icon):\n"
        "    print(icon, end='')\n"
        "    sys.exit(0)\n"
        "search_dirs = ['/usr/share/icons', '/usr/local/share/icons', '/usr/share/pixmaps', '/usr/share/applications', '/usr/share/icons/hicolor']\n"
        "extensions = ['.png', '.svg', '.xpm', '.jpg', '.jpeg', '.ico']\n"
        "icon_path, icon_base = os.path.split(icon)\n"
        "if not icon_base:\n"
        "    icon_base = icon\n"
        "    icon_path = ''\n"
        "base, suffix = os.path.splitext(icon_base)\n"
        "if suffix:\n"
        "    candidates = [icon_base]\n"
        "else:\n"
        "    candidates = [icon_base + ext for ext in extensions]\n"
        "candidate_dirs = []\n"
        "if icon_path and icon_path != '.':\n"
        "    for root in search_dirs:\n"
        "        candidate_dir = os.path.join(root, icon_path)\n"
        "        if os.path.isdir(candidate_dir):\n"
        "            candidate_dirs.append(candidate_dir)\n"
        "else:\n"
        "    candidate_dirs.extend([d for d in search_dirs if os.path.isdir(d)])\n"
        "for directory in candidate_dirs:\n"
        "    for candidate in candidates:\n"
        "        candidate_path = os.path.join(directory, candidate)\n"
        "        if os.path.exists(candidate_path):\n"
        "            print(candidate_path, end='')\n"
        "            sys.exit(0)\n"
        "for directory in search_dirs:\n"
        "    if not os.path.isdir(directory):\n"
        "        continue\n"
        "    for root, _, files in os.walk(directory):\n"
        "        for candidate in candidates:\n"
        "            if candidate in files:\n"
        "                print(os.path.join(root, candidate), end='')\n"
        "                sys.exit(0)\n"
        "print('', end='')\n"
        "sys.exit(1)");

    bool success = false;
    const QString output = runContainerCommand(container,
                                               QStringLiteral("/usr/bin/env python3 -c %1 %2").arg(KShell::quoteArg(pythonScript), KShell::quoteArg(iconValue)),
                                               success);
    if (!success) {
        return {};
    }

    return output.trimmed();
}

QString cacheIconFromContainer(const QString &container, const QString &basename, const QString &iconValue)
{
    static QHash<QString, QString> iconCache;

    const QString cacheKey = container + QLatin1Char('|') + iconValue;
    if (iconCache.contains(cacheKey)) {
        return iconCache.value(cacheKey);
    }

    const QString iconPath = resolveIconPathInContainer(container, iconValue);
    if (iconPath.isEmpty()) {
        iconCache.insert(cacheKey, QString());
        return {};
    }

    const QString cacheDirectory = ensureIconCacheDirectory(container);
    if (cacheDirectory.isEmpty()) {
        iconCache.insert(cacheKey, QString());
        return {};
    }

    const QFileInfo iconInfo(iconPath);
    QString localName = basename;
    if (localName.isEmpty()) {
        localName = iconInfo.completeBaseName();
    }

    QString suffix = iconInfo.suffix();
    if (suffix.isEmpty()) {
        suffix = QStringLiteral("png");
    }

    const QString localPath = QDir(cacheDirectory).filePath(localName + QLatin1Char('.') + suffix);

    if (!QFile::exists(localPath)) {
        const QString pythonScript = QStringLiteral(
            "import base64, sys\n"
            "path = sys.argv[1]\n"
            "with open(path, 'rb') as handler:\n"
            "    data = handler.read()\n"
            "    print(base64.b64encode(data).decode('ascii'), end='')\n");

        bool success = false;
        const QString base64Data =
            runContainerCommand(container,
                                QStringLiteral("/usr/bin/env python3 -c %1 %2").arg(KShell::quoteArg(pythonScript), KShell::quoteArg(iconPath)),
                                success);
        if (!success || base64Data.isEmpty()) {
            iconCache.insert(cacheKey, QString());
            return {};
        }

        const QByteArray binaryData = QByteArray::fromBase64(base64Data.trimmed().toUtf8());
        if (binaryData.isEmpty()) {
            iconCache.insert(cacheKey, QString());
            return {};
        }

        QFile localFile(localPath);
        if (!localFile.open(QIODevice::WriteOnly)) {
            iconCache.insert(cacheKey, QString());
            return {};
        }

        localFile.write(binaryData);
        localFile.close();
    }

    const QString url = QUrl::fromLocalFile(localPath).toString();
    iconCache.insert(cacheKey, url);
    return url;
}
}

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

// Clone a container to a user-provided name
bool DistroboxManager::cloneContainer(const QString &sourceName, const QString &cloneName)
{
    const QString trimmedSource = sourceName.trimmed();
    const QString trimmedClone = cloneName.trimmed();

    if (trimmedSource.isEmpty() || trimmedClone.isEmpty()) {
        return false;
    }

    QString message = i18n("Press any key to close this terminal…");
    // Use a simple shell script without nested bash -c
    QString command = QStringLiteral("distrobox-stop %1 -Y && distrobox create --clone %1 --name %2 && echo && echo '%3' && read -s -n 1")
                          .arg(trimmedSource, trimmedClone, message);

    QPointer<DistroboxManager> self(this);
    auto callback = [self, trimmedClone](bool success) {
        if (!self) {
            return;
        }
        Q_EMIT self->containerCloneFinished(trimmedClone, success);
    };

    return launchCommandInTerminal(command, QDir::homePath(), callback);
}

// Upgrades all packages in a container
bool DistroboxManager::upgradeContainer(const QString &name)
{
    QString message = i18n("Press any key to close this terminal…");
    QString command = QStringLiteral("distrobox upgrade %1 && echo && echo '%2' && read -s -n 1").arg(name, message);

    return launchCommandInTerminal(command);
}

bool DistroboxManager::upgradeAllContainer()
{
    QString message = i18n("Press any key to close this terminal…");
    QString command = QStringLiteral("distrobox upgrade --all && echo && echo '%1' && read -s -n 1").arg(message);

    return launchCommandInTerminal(command);
}

bool DistroboxManager::launchCommandInTerminal(const QString &command, const QString &workingDirectory, const std::function<void(bool)> &onFinished)
{
    return TerminalLauncher::launch(command, workingDirectory, this, onFinished);
}

// Returns a color associated with the distribution for UI purposes
QString DistroboxManager::getDistroColor(const QString &image)
{
    return DistroColors::colorForImage(image);
}

// Returns an Icon associated with the distribution for UI purposes
QString DistroboxManager::getDistroIcon(const QString &container)
{
    return DistroIcons::resolveDistroboxIcon(container);
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
        const QString message = i18n(
            "Cannot automatically install packages for this distribution. "
            "Please enter the distrobox manually and install it using the appropriate package manager.");

        // Simple command without nested shell
        const QString command = QStringLiteral("echo %1; read -n 1").arg(KShell::quoteArg(message));
        return launchCommandInTerminal(command, QDir::homePath());
    }

    // Clean installation command without nested bash -c
    QString message = i18n("Press any key to close this terminal…");
    QString command = QStringLiteral("distrobox enter %1 -- %2 && echo && echo '%3' && read -s -n 1").arg(name, *installCmd, message);

    return launchCommandInTerminal(command, homeDir);
}

bool DistroboxManager::isFlatpak() const
{
    return DistroboxCli::isFlatpak();
}

QVariantList DistroboxManager::allApps(const QString &container)
{
    qDebug() << "=== allApps for container:" << container << "===";

    QString findCmd = QStringLiteral("find /usr/share/applications -type f -name '*.desktop' ! -exec grep -q '^NoDisplay=true' {} \\; -print");
    bool success = false;
    QString raw = runContainerCommand(container, findCmd, success);
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
        bool readSuccess = false;
        QString desktopContent = runContainerCommand(container, readCmd, readSuccess);

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

        const QString iconSource = cacheIconFromContainer(container, basename, icon);
        if (!iconSource.isEmpty()) {
            app[QStringLiteral("iconSource")] = iconSource;
        }

        qDebug() << "App:" << name << "| Basename:" << basename << "| Generic:" << genericName << "| Source:" << line;
        list << app;
    }

    qDebug() << "Total apps found:" << list.size();
    return list;
}

QVariantList DistroboxManager::exportedApps(const QString &container)
{
    QVariantList list;
    bool isFlatpakRuntime = DistroboxCli::isFlatpak();
    QStringList searchPaths;

    if (isFlatpakRuntime) {
        // Flatpak build only has read access to the host exports directory
        searchPaths = {QDir::homePath() + QStringLiteral("/.local/share/applications")};
    } else {
        searchPaths = {QStandardPaths::writableLocation(QStandardPaths::ApplicationsLocation)};
    }

    QStringList patterns;
    patterns << QStringLiteral("%1-*.desktop").arg(container);

    for (const QString &searchPath : searchPaths) {
        QDir dir(searchPath);
        if (!dir.exists()) {
            continue;
        }

        for (const QFileInfo &file : dir.entryInfoList(patterns, QDir::Files)) {
            QString fileName = file.fileName();
            if (!fileName.endsWith(QStringLiteral(".desktop"))) {
                continue;
            }

            // Skip clone files explicitly
            if (fileName.endsWith(QStringLiteral("clone.desktop"), Qt::CaseInsensitive)
                || fileName.contains(QStringLiteral("-clone.desktop"), Qt::CaseInsensitive)) {
                continue;
            }

            // Extract basename from filename
            QString prefix = container + QLatin1String("-");
            QString basename = fileName;
            if (basename.startsWith(prefix)) {
                basename.remove(0, prefix.length());
            }
            if (basename.endsWith(QStringLiteral(".desktop"))) {
                basename.chop(8);
            }

            // Skip if we already found this app
            bool alreadyExists = false;
            for (const QVariant &existingApp : list) {
                QVariantMap existingMap = existingApp.toMap();
                if (existingMap[QStringLiteral("basename")].toString() == basename) {
                    alreadyExists = true;
                    break;
                }
            }
            if (alreadyExists) {
                continue;
            }

            QSettings desktop(file.filePath(), QSettings::IniFormat);
            QVariantMap app;
            app[QStringLiteral("basename")] = basename;

            QString fullName = desktop.value(QStringLiteral("Desktop Entry/Name"), basename).toString();
            QString icon = desktop.value(QStringLiteral("Desktop Entry/Icon"), QString()).toString();

            app[QStringLiteral("name")] = fullName.section(QStringLiteral(" (on "), 0, 0);
            app[QStringLiteral("icon")] = icon;

            qDebug() << "Exported app:" << app[QStringLiteral("name")].toString() << "| Basename:" << basename << "| File:" << fileName;
            list << app;
        }
    }

    return list;
}

bool DistroboxManager::exportApp(const QString &basename, const QString &container)
{
    // Construct the full path to the desktop file in the container
    QString desktopPath = QStringLiteral("/usr/share/applications/") + basename + QStringLiteral(".desktop");
    QString command = u"distrobox enter %1 -- distrobox-export --app %2"_s.arg(container, KShell::quoteArg(desktopPath));

    bool success;
    QString output = DistroboxCli::runCommand(command, success);

    qDebug() << "Export" << basename << ":" << (success ? "SUCCESS" : "FAILED") << "Output:" << output;
    return success;
}

bool DistroboxManager::isAppExportedByOtherContainers(const QString &basename, const QString &excludeContainer)
{
    qDebug() << "Checking if" << basename << "is exported by containers other than" << excludeContainer;

    bool isFlatpakRuntime = DistroboxCli::isFlatpak();
    QStringList searchPaths;

    if (isFlatpakRuntime) {
        searchPaths = {QDir::homePath() + QStringLiteral("/.local/share/applications")};
    } else {
        searchPaths = {QStandardPaths::writableLocation(QStandardPaths::ApplicationsLocation)};
    }

    qDebug() << "Searching in paths:" << searchPaths;

    for (const QString &searchPath : searchPaths) {
        QDir dir(searchPath);
        if (!dir.exists()) {
            qDebug() << "Search path does not exist:" << searchPath;
            continue;
        }

        // Look for any desktop files that match the pattern *-{basename}.desktop
        // but exclude the specific container we're checking against
        QStringList nameFilters;
        nameFilters << QStringLiteral("*-%1.desktop").arg(basename);

        qDebug() << "Looking for files matching pattern:" << nameFilters << "in" << searchPath;

        QFileInfoList matchingFiles = dir.entryInfoList(nameFilters, QDir::Files);
        qDebug() << "Found" << matchingFiles.size() << "matching files";

        for (const QFileInfo &file : matchingFiles) {
            QString fileName = file.fileName();
            qDebug() << "Examining file:" << fileName;

            // Skip clone files
            if (fileName.endsWith(QStringLiteral("clone.desktop"), Qt::CaseInsensitive)
                || fileName.contains(QStringLiteral("-clone.desktop"), Qt::CaseInsensitive)) {
                qDebug() << "Skipping clone file:" << fileName;
                continue;
            }

            // Extract container name from filename (format: container-basename.desktop)
            QString containerFromFile = fileName;
            containerFromFile.remove(QStringLiteral("-%1.desktop").arg(basename));

            qDebug() << "Extracted container name:" << containerFromFile << "from file:" << fileName;

            // If this file belongs to a different container, the app is exported by others
            if (containerFromFile != excludeContainer) {
                qDebug() << "Found" << basename << "exported by another container:" << containerFromFile;
                return true;
            }
        }
    }

    qDebug() << "No other containers found exporting" << basename;
    return false;
}

bool DistroboxManager::unexportApp(const QString &basename, const QString &container)
{
    qDebug() << "=== UNEXPORT OPERATION START ===";
    qDebug() << "Attempting to unexport:" << basename << "from container:" << container;

    // Check if this app is exported by other containers
    qDebug() << "Checking if app is exported by other containers...";
    bool exportedByOthers = isAppExportedByOtherContainers(basename, container);

    if (exportedByOthers) {
        qDebug() << "DECISION: App" << basename << "is exported by other containers";
        qDebug() << "STRATEGY: Using manual file removal only (preserving shared icons/metadata)";

        // Only remove the specific container's desktop file, don't use distrobox-export --delete
        // which might remove shared icons/metadata
        if (!DistroboxCli::isFlatpak()) {
            QString appsPath = QStandardPaths::writableLocation(QStandardPaths::ApplicationsLocation);
            QString desktopFileName = container + QLatin1String("-") + basename + QLatin1String(".desktop");
            QString fullDesktopPath = appsPath + QLatin1String("/") + desktopFileName;
            QFile desktopFile(fullDesktopPath);

            qDebug() << "Target desktop file:" << fullDesktopPath;
            qDebug() << "Desktop file exists:" << desktopFile.exists();

            if (desktopFile.exists()) {
                qDebug() << "Attempting manual removal of desktop file:" << desktopFileName;
                if (desktopFile.remove()) {
                    qDebug() << "SUCCESS: Manual removal completed successfully";
                    qDebug() << "=== UNEXPORT OPERATION END (SUCCESS) ===";
                    return true;
                } else {
                    qDebug() << "FAILURE: Manual removal failed - could not delete file";
                    qDebug() << "=== UNEXPORT OPERATION END (FAILED) ===";
                    return false;
                }
            } else {
                qDebug() << "FAILURE: Desktop file does not exist:" << desktopFileName;
                qDebug() << "=== UNEXPORT OPERATION END (FAILED) ===";
                return false;
            }
        } else {
            qDebug() << "FAILURE: Manual removal skipped - read-only access inside Flatpak runtime";
            qDebug() << "=== UNEXPORT OPERATION END (FAILED) ===";
            return false;
        }
    } else {
        qDebug() << "DECISION: App" << basename << "is only exported by this container";
        qDebug() << "STRATEGY: Safe to use distrobox-export --delete (will remove icons/metadata)";

        // First try with just the basename (how distrobox-export expects it)
        QString command = u"distrobox enter %1 -- distrobox-export --app %2 --delete"_s.arg(container, KShell::quoteArg(basename));
        qDebug() << "Executing command:" << command;

        bool success;
        QString output = DistroboxCli::runCommand(command, success);
        qDebug() << "Command result - Success:" << success << "Output:" << output;

        if (success) {
            qDebug() << "SUCCESS: Unexport successful with basename approach";
            qDebug() << "=== UNEXPORT OPERATION END (SUCCESS) ===";
            return true;
        }

        qDebug() << "First attempt failed, trying with full path approach...";

        // If that fails, try with the full path
        QString desktopPath = QStringLiteral("/usr/share/applications/") + basename + QStringLiteral(".desktop");
        QString altCommand = u"distrobox enter %1 -- distrobox-export --app %2 --delete"_s.arg(container, KShell::quoteArg(desktopPath));
        qDebug() << "Executing alternative command:" << altCommand;

        output = DistroboxCli::runCommand(altCommand, success);
        qDebug() << "Alternative command result - Success:" << success << "Output:" << output;

        if (success) {
            qDebug() << "SUCCESS: Unexport successful with full path approach";
            qDebug() << "=== UNEXPORT OPERATION END (SUCCESS) ===";
            return true;
        }

        qDebug() << "Both distrobox-export attempts failed, falling back to manual removal";
        qDebug() << "Final command output:" << output;

        // As a last resort, try to manually remove the desktop file
        if (!DistroboxCli::isFlatpak()) {
            QString appsPath = QStandardPaths::writableLocation(QStandardPaths::ApplicationsLocation);
            QString desktopFileName = container + QLatin1String("-") + basename + QLatin1String(".desktop");
            QString fullDesktopPath = appsPath + QLatin1String("/") + desktopFileName;
            QFile desktopFile(fullDesktopPath);

            qDebug() << "Fallback: Target desktop file:" << fullDesktopPath;
            qDebug() << "Fallback: Desktop file exists:" << desktopFile.exists();

            if (desktopFile.exists()) {
                qDebug() << "Fallback: Attempting manual removal of:" << desktopFileName;
                if (desktopFile.remove()) {
                    qDebug() << "SUCCESS: Fallback manual removal successful";
                    qDebug() << "=== UNEXPORT OPERATION END (SUCCESS) ===";
                    return true;
                } else {
                    qDebug() << "FAILURE: Fallback manual removal failed";
                }
            } else {
                qDebug() << "FAILURE: Fallback - desktop file does not exist";
            }
        } else {
            qDebug() << "Fallback: Manual removal skipped - read-only access inside Flatpak runtime";
        }

        qDebug() << "FAILURE: All unexport attempts exhausted";
        qDebug() << "=== UNEXPORT OPERATION END (FAILED) ===";
        return false;
    }
}
