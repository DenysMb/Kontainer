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
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QPointer>
#include <QProcess>
#include <QRegularExpression>
#include <QSettings>
#include <QStandardPaths>
#include <QTextStream>
#include <QUrl>
#include <algorithm>
#include <cstring>
#include <distroicons.h>
#include <sys/xattr.h>

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

// Distrobox 2.0+ prints the container name to stdout when auto-starting
// a stopped container (podman start <name> via Interactive mode). This
// contaminates the output of "distrobox enter <container> -- sh -c ..."
// commands. Strip the container name from the first line when present.
// See: https://github.com/DenysMb/Kontainer/issues/73
QString stripContainerStartupNoise(const QString &output, const QString &container)
{
    if (container.isEmpty() || output.isEmpty()) {
        return output;
    }

    const int newlinePos = output.indexOf(QLatin1Char('\n'));
    if (newlinePos < 0) {
        return output;
    }

    const QString firstLine = output.left(newlinePos);
    if (firstLine.trimmed() == container.trimmed()) {
        return output.mid(newlinePos + 1);
    }

    return output;
}

QString runContainerCommand(const QString &container, const QString &script, bool &success)
{
    const QString command = u"distrobox enter %1 -- sh -c %2"_s.arg(container, KShell::quoteArg(script));
    QString output = DistroboxCli::runCommand(command, success);
    return stripContainerStartupNoise(output, container);
}

static QString resolveDocumentPortalPath(const QString &path)
{
    // Only check paths under /run/user/$UID/doc/
    if (!path.startsWith(QStringLiteral("/run/user/")))
        return path;

    if (!path.contains(QStringLiteral("/doc/")))
        return path;

    const QByteArray pathUtf8 = path.toLocal8Bit();
    const ssize_t size = getxattr(pathUtf8.constData(), "user.document-portal.host-path", nullptr, 0);
    if (size <= 0)
        return path;

    QByteArray value(size, '\0');
    const ssize_t len = getxattr(pathUtf8.constData(), "user.document-portal.host-path", value.data(), value.size());
    if (len <= 0)
        return path;

    // Older xdg-desktop-portal versions include a trailing NUL in the xattr value
    return QString::fromUtf8(value.constData(), strnlen(value.constData(), len));
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

// Starts a stopped container
bool DistroboxManager::startContainer(const QString &name)
{
    QString command = u"podman start %1"_s.arg(name);
    bool success;
    DistroboxCli::runCommand(command, success);
    return success;
}

// Stops a running container
bool DistroboxManager::stopContainer(const QString &name)
{
    QString command = u"distrobox-stop %1 -Y"_s.arg(name);
    bool success;
    DistroboxCli::runCommand(command, success);
    return success;
}

// Reboots a container (stop then start)
bool DistroboxManager::rebootContainer(const QString &name)
{
    QString command = u"distrobox-stop %1 -Y && podman start %1"_s.arg(name);
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
    QString cloneCmd =
        u"distrobox-stop %1 -Y && distrobox create --clone %1 --name %2 && echo '' && echo '%3' && read -s -n 1"_s.arg(trimmedSource, trimmedClone, message);
    QString command = u"sh -c \"%1\""_s.arg(cloneCmd);
    QPointer<DistroboxManager> self(this);
    auto callback = [self, trimmedClone](bool success) {
        if (!self) {
            return;
        }
        Q_EMIT self->containerCloneFinished(trimmedClone, success);
    };

    return launchCommandInTerminal(command, QDir::homePath(), callback);
}

// Assemble a container from an .ini File
bool DistroboxManager::assembleContainer(const QString &iniFile)
{
    QString trimmedFile = iniFile.trimmed();
    if (trimmedFile.isEmpty()) {
        return false;
    }

    if (trimmedFile.startsWith(u"file://"_s)) {
        trimmedFile = trimmedFile.mid(7);
    }

    // Resolve potential portal FUSE path to actual host path
    trimmedFile = resolveDocumentPortalPath(trimmedFile);

    QString message = i18n("Press any key to close this terminal…");

    QString assembleCmd = u"distrobox assemble create --file %1 && echo '' && echo '%2' && read -s -n 1"_s.arg(trimmedFile, message);

    QString command = u"sh -c \"%1\""_s.arg(assembleCmd);

    QPointer<DistroboxManager> self(this);
    auto callback = [self](bool success) {
        if (!self)
            return;
        Q_EMIT self->containerAssembleFinished(success);
    };

    return launchCommandInTerminal(command, QDir::homePath(), callback);
}

// Upgrades all packages in a container
bool DistroboxManager::upgradeContainer(const QString &name)
{
    QString message = i18n("Press any key to close this terminal…");
    QString upgradeCmd = u"distrobox upgrade %1 && echo '' && echo '%2' && read -s -n 1"_s.arg(name, message);
    QString command = u"sh -c \"%1\""_s.arg(upgradeCmd);

    return launchCommandInTerminal(command);
}

bool DistroboxManager::upgradeAllContainer()
{
    QString message = i18n("Press any key to close this terminal…");
    QString upgradeCmd = u"distrobox upgrade --all && echo '' && echo '%1' && read -s -n 1"_s.arg(message);
    QString command = u"sh -c \"%1\""_s.arg(upgradeCmd);

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

// Installs a Package File with the Containers Package Manager
// Doesnt like POSIX sh and wants GNU bash for launching in the Terminal
// TODO: Make the function use POSIX sh to increase portability
bool DistroboxManager::installPackageInContainer(const QString &name, const QString &packagePath, const QString &image)
{
    QString homeDir = QDir::homePath();

    // Remove "file://" prefix if present
    QString actualPackagePath = packagePath;
    if (actualPackagePath.startsWith(u"file://"_s))
        actualPackagePath = actualPackagePath.mid(7);

    // Resolve document portal FUSE path to host path if needed
    actualPackagePath = resolveDocumentPortalPath(actualPackagePath);

    const auto installCmd = PackageInstallCommand::forImage(image, actualPackagePath);
    if (!installCmd) {
        const QString message = i18n(
            "Cannot automatically install packages for this distribution.\n"
            "Please enter the distrobox manually and install it using the appropriate package manager.");

        // Escape single quotes for embedding inside double quotes
        QString safeMessage = message;
        safeMessage.replace(u"'"_s, u"'\\''"_s);

        // Use consistent quoting style as the install path
        const QString script = QStringLiteral("echo '%1'; read -n 1 -s -r -p \'Press any key to continue...\'").arg(safeMessage);

        // Bash -c in double quotes to avoid nested single-quote issues
        const QString command = QStringLiteral("bash -c \"%1\"").arg(script);

        return launchCommandInTerminal(command, homeDir);
    }

    QString message = i18n("Press any key to close this terminal…");

    QString safeMessage = message;
    safeMessage.replace(u"'"_s, u"'\\''"_s);

    QString innerScript = QStringLiteral("%1 && echo && echo '%2' && read -s -n 1").arg(*installCmd, safeMessage);

    QString fullCmd = QStringLiteral("distrobox enter %1 -- /usr/bin/env bash -c \"%2\"").arg(name, innerScript);

    return launchCommandInTerminal(fullCmd, homeDir);
}

bool DistroboxManager::isFlatpak() const
{
    return DistroboxCli::isFlatpak();
}

QString DistroboxManager::resolveHostPath(const QString &path) const
{
    return resolveDocumentPortalPath(path);
}

QString DistroboxManager::distroboxVersion() const
{
    return DistroboxCli::distroboxVersion();
}

QString DistroboxManager::distroboxPath() const
{
    return DistroboxCli::distroboxPath();
}

bool DistroboxManager::isContainerEngineAvailable() const
{
    // Check if podman is available
    bool success = false;
    QString podmanCheck = DistroboxCli::runCommand(QStringLiteral("sh -c 'command -v podman'"), success);
    if (success && !podmanCheck.trimmed().isEmpty()) {
        return true;
    }

    // Check if docker is available
    QString dockerCheck = DistroboxCli::runCommand(QStringLiteral("sh -c 'command -v docker'"), success);
    if (success && !dockerCheck.trimmed().isEmpty()) {
        return true;
    }

    return false;
}

void DistroboxManager::startLogsStream(const QString &name, bool timestamps, int maxLines)
{
    stopLogsStream();

    auto *process = new QProcess(this);
    m_logsProcess = process;

    QObject::connect(process, &QProcess::readyReadStandardOutput, this, [this, process]() {
        Q_EMIT containerLogsReceived(QString::fromUtf8(process->readAllStandardOutput()));
    });
    QObject::connect(process, &QProcess::readyReadStandardError, this, [this, process]() {
        Q_EMIT containerLogsReceived(QString::fromUtf8(process->readAllStandardError()));
    });
    QObject::connect(process, &QProcess::finished, this, [this, process](int, QProcess::ExitStatus) {
        process->deleteLater();
        if (m_logsProcess == process) {
            m_logsProcess.clear();
        }
        Q_EMIT logsStreamFinished();
    });

    const QString flags = timestamps ? u"--timestamps "_s : QString();
    QString command = u"podman logs %1--follow --tail %2 %3"_s.arg(flags).arg(maxLines).arg(KShell::quoteArg(name));
    if (DistroboxCli::isFlatpak()) {
        command = u"flatpak-spawn --host /usr/bin/env "_s + command;
    }

    process->start(u"sh"_s, QStringList() << QLatin1String("-c") << command);
}

void DistroboxManager::stopLogsStream()
{
    if (!m_logsProcess) {
        return;
    }

    QProcess *process = m_logsProcess;
    m_logsProcess.clear();
    QObject::disconnect(process, nullptr, this, nullptr);
    process->kill();
    process->deleteLater();
}

bool DistroboxManager::exportTextToFile(const QString &content, const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        return false;
    }

    file.write(content.toUtf8());
    return true;
}

bool DistroboxManager::openFileManager(const QString &name)
{
    bool success = false;
    const QString output = DistroboxCli::runCommand(QStringLiteral("podman inspect ") + KShell::quoteArg(name), success);
    if (!success) {
        return false;
    }

    QJsonParseError parseError;
    const QJsonDocument doc = QJsonDocument::fromJson(output.toUtf8(), &parseError);
    if (parseError.error != QJsonParseError::NoError || !doc.isArray() || doc.array().isEmpty()) {
        return false;
    }

    const QJsonObject container = doc.array().first().toObject();

    QString home = QDir::homePath();
    const QJsonArray env = container[u"Config"_s].toObject()[u"Env"_s].toArray();
    for (const QJsonValue &entry : env) {
        const QString variable = entry.toString();
        if (variable.startsWith(u"HOME="_s)) {
            home = variable.mid(5);
            break;
        }
    }

    QString hostPath = home;
    const QJsonArray mounts = container[u"Mounts"_s].toArray();
    for (const QJsonValue &mountValue : mounts) {
        const QJsonObject mount = mountValue.toObject();
        if (mount[u"Destination"_s].toString() == home) {
            hostPath = mount[u"Source"_s].toString();
            break;
        }
    }

    const QString command = u"xdg-open "_s + KShell::quoteArg(hostPath);
    bool openSuccess = false;
    DistroboxCli::runCommand(command, openSuccess);
    if (!openSuccess) {
        qWarning() << "openFileManager: failed to open" << hostPath << "for container" << name;
    }
    return openSuccess;
}

void DistroboxManager::requestContainerStats()
{
    if (m_statsProcess) {
        return;
    }

    auto *process = new QProcess(this);
    m_statsProcess = process;

    QObject::connect(process, &QProcess::finished, this, [this, process](int exitCode, QProcess::ExitStatus) {
        process->deleteLater();
        m_statsProcess.clear();

        QVariantList stats;
        if (exitCode != 0) {
            Q_EMIT containerStatsReady(stats);
            return;
        }

        const QByteArray raw = process->readAllStandardOutput();
        if (raw.trimmed().isEmpty()) {
            Q_EMIT containerStatsReady(stats);
            return;
        }

        QJsonParseError parseError;
        const QJsonDocument doc = QJsonDocument::fromJson(raw, &parseError);
        if (parseError.error != QJsonParseError::NoError || !doc.isArray()) {
            Q_EMIT containerStatsReady(stats);
            return;
        }

        for (const QJsonValue &val : doc.array()) {
            const QJsonObject obj = val.toObject();
            QVariantMap entry;
            entry[QStringLiteral("name")] = obj[QStringLiteral("name")].toString();
            entry[QStringLiteral("cpuPercent")] = obj[QStringLiteral("cpu_percent")].toString();
            entry[QStringLiteral("memUsage")] = obj[QStringLiteral("mem_usage")].toString();
            entry[QStringLiteral("memPercent")] = obj[QStringLiteral("mem_percent")].toString();
            entry[QStringLiteral("netIo")] = obj[QStringLiteral("net_io")].toVariant().toString();
            entry[QStringLiteral("blockIo")] = obj[QStringLiteral("block_io")].toVariant().toString();
            entry[QStringLiteral("pids")] = obj[QStringLiteral("pids")].toVariant().toString();
            stats.append(entry);
        }

        Q_EMIT containerStatsReady(stats);
    });

    QString command = u"podman stats --no-stream --format json"_s;
    if (DistroboxCli::isFlatpak()) {
        command = u"flatpak-spawn --host /usr/bin/env "_s + command;
    }

    process->start(u"sh"_s, QStringList() << QLatin1String("-c") << command);
}

QVariantList DistroboxManager::allApps(const QString &container)
{
    QVariantList list;

    const QString pythonScript = QStringLiteral(
        "python3 - <<'PY'\n"
        "import base64\n"
        "import json\n"
        "import os\n"
        "\n"
        "search_dirs = [\"/usr/share/icons\", \"/usr/local/share/icons\", \"/usr/share/pixmaps\", \"/usr/share/applications\", \"/usr/share/icons/hicolor\"]\n"
        "extensions = [\".png\", \".svg\", \".xpm\", \".jpg\", \".jpeg\", \".ico\"]\n"
        "\n"
        "def resolve_icon(icon):\n"
        "    if not icon:\n"
        "        return ''\n"
        "    if os.path.isabs(icon) and os.path.exists(icon):\n"
        "        return icon\n"
        "    icon_path, icon_base = os.path.split(icon)\n"
        "    if not icon_base:\n"
        "        icon_base = icon\n"
        "        icon_path = ''\n"
        "    base, suffix = os.path.splitext(icon_base)\n"
        "    candidates = [icon_base] if suffix else [icon_base + ext for ext in extensions]\n"
        "    candidate_dirs = []\n"
        "    if icon_path and icon_path != '.':\n"
        "        for root in search_dirs:\n"
        "            candidate_dir = os.path.join(root, icon_path)\n"
        "            if os.path.isdir(candidate_dir):\n"
        "                candidate_dirs.append(candidate_dir)\n"
        "    else:\n"
        "        candidate_dirs.extend([d for d in search_dirs if os.path.isdir(d)])\n"
        "    for directory in candidate_dirs:\n"
        "        for candidate in candidates:\n"
        "            candidate_path = os.path.join(directory, candidate)\n"
        "            if os.path.exists(candidate_path):\n"
        "                return candidate_path\n"
        "    for directory in search_dirs:\n"
        "        if not os.path.isdir(directory):\n"
        "            continue\n"
        "        for root, _, files in os.walk(directory):\n"
        "            for candidate in candidates:\n"
        "                if candidate in files:\n"
        "                    return os.path.join(root, candidate)\n"
        "    return ''\n"
        "\n"
        "apps = []\n"
        "for root, _, files in os.walk(\"/usr/share/applications\"):\n"
        "    for file_name in files:\n"
        "        if not file_name.endswith(\".desktop\"):\n"
        "            continue\n"
        "        path = os.path.join(root, file_name)\n"
        "        english = None\n"
        "        fallback = None\n"
        "        icon = ''\n"
        "        generic = ''\n"
        "        nodisplay = False\n"
        "        with open(path, errors=\"replace\") as handler:\n"
        "            for line in handler:\n"
        "                stripped = line.strip()\n"
        "                if stripped.startswith(\"NoDisplay=true\"):\n"
        "                    nodisplay = True\n"
        "                    break\n"
        "                if stripped.startswith(\"Name[en]=\"):\n"
        "                    english = stripped[8:]\n"
        "                elif stripped.startswith(\"Name=\"):\n"
        "                    fallback = stripped[5:]\n"
        "                elif stripped.startswith(\"Icon=\"):\n"
        "                    icon = stripped[5:]\n"
        "                elif stripped.startswith(\"GenericName=\"):\n"
        "                    generic = stripped[12:]\n"
        "        if nodisplay:\n"
        "            continue\n"
        "        basename = file_name[:-len(\".desktop\")]\n"
        "        apps.append({\n"
        "            \"basename\": basename,\n"
        "            \"name\": english or fallback or basename,\n"
        "            \"icon\": icon,\n"
        "            \"genericName\": generic,\n"
        "            \"sourceFile\": path,\n"
        "        })\n"
        "\n"
        "icon_data = {}\n"
        "for app in apps:\n"
        "    icon_path = resolve_icon(app[\"icon\"])\n"
        "    app[\"iconPath\"] = icon_path\n"
        "    if icon_path and icon_path not in icon_data:\n"
        "        try:\n"
        "            with open(icon_path, \"rb\") as handler:\n"
        "                icon_data[icon_path] = base64.b64encode(handler.read()).decode(\"ascii\")\n"
        "        except OSError:\n"
        "            icon_data[icon_path] = ''\n"
        "    app[\"iconData\"] = icon_data.get(icon_path, '') if icon_path else ''\n"
        "\n"
        "print(json.dumps(apps))\n"
        "PY");

    bool success = false;
    const QString output = runContainerCommand(container, pythonScript, success);

    QJsonParseError parseError;
    const QJsonDocument doc = QJsonDocument::fromJson(output.trimmed().toUtf8(), &parseError);
    if (!success || parseError.error != QJsonParseError::NoError || !doc.isArray()) {
        qWarning() << "allApps batch query failed for container:" << container;
        return allAppsWithoutIcons(container);
    }

    const QString cacheDirectory = ensureIconCacheDirectory(container);

    for (const QJsonValue &value : doc.array()) {
        const QJsonObject obj = value.toObject();

        QVariantMap app;
        const QString basename = obj[QStringLiteral("basename")].toString();
        app[QStringLiteral("basename")] = basename;
        app[QStringLiteral("name")] = obj[QStringLiteral("name")].toString();
        app[QStringLiteral("icon")] = obj[QStringLiteral("icon")].toString();
        app[QStringLiteral("genericName")] = obj[QStringLiteral("genericName")].toString();
        app[QStringLiteral("sourceFile")] = obj[QStringLiteral("sourceFile")].toString();

        const QString iconPath = obj[QStringLiteral("iconPath")].toString();
        const QString iconData = obj[QStringLiteral("iconData")].toString();
        if (!iconPath.isEmpty() && !iconData.isEmpty() && !cacheDirectory.isEmpty()) {
            QString suffix = QFileInfo(iconPath).suffix();
            if (suffix.isEmpty()) {
                suffix = QStringLiteral("png");
            }

            const QString localPath = QDir(cacheDirectory).filePath(basename + QLatin1Char('.') + suffix);
            if (!QFile::exists(localPath)) {
                const QByteArray binaryData = QByteArray::fromBase64(iconData.toUtf8());
                QFile localFile(localPath);
                if (localFile.open(QIODevice::WriteOnly)) {
                    localFile.write(binaryData);
                    localFile.close();
                }
            }

            if (QFile::exists(localPath)) {
                app[QStringLiteral("iconSource")] = QUrl::fromLocalFile(localPath).toString();
            }
        }

        list << app;
    }

    return list;
}

QVariantList DistroboxManager::allAppsWithoutIcons(const QString &container)
{
    QVariantList list;

    const QString script = QStringLiteral(
        "find /usr/share/applications -type f -name '*.desktop' ! -exec grep -q '^NoDisplay=true' {} \\; -print | while IFS= read -r f; do printf '@@@%s\\n' "
        "\"$f\"; cat \"$f\"; done");

    bool success = false;
    const QString output = runContainerCommand(container, script, success);
    if (!success) {
        return list;
    }

    QVariantMap app;
    bool hasApp = false;
    const auto flushApp = [&list, &app, &hasApp]() {
        if (hasApp) {
            list << app;
            app = QVariantMap();
            hasApp = false;
        }
    };

    QString englishName;
    QString fallbackName;

    for (const QString &line : output.split(QChar::fromLatin1('\n'))) {
        if (line.startsWith(QStringLiteral("@@@"))) {
            flushApp();
            hasApp = true;
            englishName.clear();
            fallbackName.clear();

            const QString path = line.mid(3);
            QString basename = path;
            if (basename.startsWith(QStringLiteral("/usr/share/applications/"))) {
                basename.remove(0, 24);
            }
            if (basename.endsWith(QStringLiteral(".desktop"))) {
                basename.chop(8);
            }
            app[QStringLiteral("basename")] = basename;
            app[QStringLiteral("sourceFile")] = path;
            app[QStringLiteral("icon")] = QString();
            continue;
        }

        if (!hasApp) {
            continue;
        }

        if (line.startsWith(QStringLiteral("Name[en]="))) {
            englishName = line.mid(8);
        } else if (line.startsWith(QStringLiteral("Name="))) {
            fallbackName = line.mid(5);
        } else if (line.startsWith(QStringLiteral("Icon="))) {
            app[QStringLiteral("icon")] = line.mid(5);
        } else if (line.startsWith(QStringLiteral("GenericName="))) {
            app[QStringLiteral("genericName")] = line.mid(12);
        }

        const QString name = !englishName.isEmpty() ? englishName : (!fallbackName.isEmpty() ? fallbackName : app[QStringLiteral("basename")].toString());
        app[QStringLiteral("name")] = name;
    }
    flushApp();

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
    QString command = u"distrobox enter %1 -- distrobox-export --app %2"_s.arg(KShell::quoteArg(container), KShell::quoteArg(desktopPath));

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
        QString command = u"distrobox enter %1 -- distrobox-export --app %2 --delete"_s.arg(KShell::quoteArg(container), KShell::quoteArg(basename));
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
        QString altCommand = u"distrobox enter %1 -- distrobox-export --app %2 --delete"_s.arg(KShell::quoteArg(container), KShell::quoteArg(desktopPath));
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

QVariantList DistroboxManager::exportedBinaries(const QString &container)
{
    QVariantList list;
    const QString binDir = QDir::homePath() + QStringLiteral("/.local/bin");
    const QDir dir(binDir);
    if (!dir.exists()) {
        return list;
    }

    const QFileInfoList entries = dir.entryInfoList(QDir::Files);
    for (const QFileInfo &fileInfo : entries) {
        QFile file(fileInfo.absoluteFilePath());
        if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            continue;
        }

        const QString content = QString::fromUtf8(file.readAll());
        file.close();

        if (!content.contains(QLatin1String("# distrobox_binary"))) {
            continue;
        }

        const QString marker = u"# name: %1"_s.arg(container);
        if (!content.contains(marker)) {
            continue;
        }

        const QString basename = fileInfo.fileName();

        QString path = basename;
        static const QRegularExpression pathRx(QStringLiteral("--\\s+(.+?)\\s+\"\\$@\""));
        const QRegularExpressionMatch match = pathRx.match(content);
        if (match.hasMatch()) {
            path = match.captured(1).trimmed();
            if ((path.startsWith(QLatin1Char('\'')) && path.endsWith(QLatin1Char('\'')))
                || (path.startsWith(QLatin1Char('"')) && path.endsWith(QLatin1Char('"')))) {
                path = path.mid(1, path.length() - 2);
            }
        }

        QVariantMap entry;
        entry[QStringLiteral("basename")] = basename;
        entry[QStringLiteral("path")] = path;
        list.append(entry);
    }

    return list;
}

QVariantList DistroboxManager::availableBinaries(const QString &container)
{
    QVariantList list;
    const QString script =
        u"for f in /usr/bin/* /usr/local/bin/*; do [ -f \"$f\" ] && [ -x \"$f\" ] && printf '%s\\t%s\\n' \"$(basename \"$f\")\" \"$f\"; done"_s;

    bool success = false;
    const QString output = runContainerCommand(container, script, success);
    if (!success || output.trimmed().isEmpty()) {
        return list;
    }

    const QStringList lines = output.split(QLatin1Char('\n'), Qt::SkipEmptyParts);
    for (const QString &line : lines) {
        const int tabPos = line.indexOf(QLatin1Char('\t'));
        if (tabPos < 0) {
            continue;
        }

        QVariantMap entry;
        entry[QStringLiteral("basename")] = line.left(tabPos);
        entry[QStringLiteral("path")] = line.mid(tabPos + 1);
        list.append(entry);
    }

    std::sort(list.begin(), list.end(), [](const QVariant &a, const QVariant &b) {
        return a.toMap()[QStringLiteral("basename")].toString().compare(b.toMap()[QStringLiteral("basename")].toString(), Qt::CaseInsensitive) < 0;
    });

    return list;
}

bool DistroboxManager::exportBinary(const QString &path, const QString &container)
{
    const QString command =
        u"distrobox enter %1 -- distrobox-export --bin %2 --export-path ~/.local/bin"_s.arg(KShell::quoteArg(container), KShell::quoteArg(path));

    bool success = false;
    DistroboxCli::runCommand(command, success);
    return success;
}

bool DistroboxManager::unexportBinary(const QString &path, const QString &container)
{
    const QString command =
        u"distrobox enter %1 -- distrobox-export --bin %2 --export-path ~/.local/bin --delete"_s.arg(KShell::quoteArg(container), KShell::quoteArg(path));

    bool success = false;
    DistroboxCli::runCommand(command, success);
    return success;
}
