/*
    SPDX-License-Identifier: GPL-3.0-or-later
    SPDX-FileCopyrightText: 2025 Denys Madureira <denysmb@zoho.com>
    SPDX-FileCopyrightText: 2025 Thomas Duckworth <tduck@filotimoproject.org>
*/

#include "distroboxmanager.h"
#include "terminallauncher.h"
#include <KLocalizedContext>
#include <KLocalizedString>
#include <KShell>
#include <QDir>
#include <QEventLoop>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QRandomGenerator>
#include <QRegularExpression>
#include <qtimer.h>

using namespace Qt::Literals::StringLiterals;

// Constructor: Initializes the manager and populates available images lists
DistroboxManager::DistroboxManager(QObject *parent)
    : QObject(parent)
{
    // Initialize lists of available images when the manager is created
    m_availableImages = getAvailableImages();
    m_fullImageNames = getFullImageNames();
}

// Helper function to execute shell commands and capture their output
QString DistroboxManager::runCommand(const QString &command, bool &success) const
{
    QString actualCommand = command;
    if (isFlatpak()) {
        actualCommand = u"flatpak-spawn --host "_s + command;
    }

    QString output;

    QProcess *process = new QProcess();
    connect(process, &QProcess::finished, this, [&](int exitCode, QProcess::ExitStatus) {
        output = QString::fromUtf8(process->readAllStandardOutput());
        success = (exitCode == 0);
    });

    process->start(u"sh"_s, QStringList() << QLatin1String("-c") << actualCommand);

    // Local event loop - ensures UI isn't blocked while function is blocking
    QEventLoop loop;
    connect(process, &QProcess::finished, &loop, &QEventLoop::quit);
    loop.exec();

    return output;
}

// Gets list of available container images that can be created
QStringList DistroboxManager::getAvailableImages() const
{
    bool success;
    // Run distrobox create -C to list available images
    QString output = runCommand(u"distrobox create -C"_s, success);

    if (!success) {
        return QStringList();
    }

    // Split output into lines and clean up
    QStringList lines = output.split(QChar::fromLatin1('\n'), Qt::SkipEmptyParts);
    if (!lines.isEmpty() && lines.first().trimmed().isEmpty()) {
        lines.removeFirst();
    }

    return lines;
}

// Currently returns same as getAvailableImages(), but may be extended in future
QStringList DistroboxManager::getFullImageNames() const
{
    return getAvailableImages();
}

// Lists all existing containers and their base images in JSON format
QString DistroboxManager::listContainers()
{
    bool success;
    // Extract container names from distrobox list output
    QString namesOutput = runCommand(u"distrobox list | tail -n +2 | cut -d'|' -f2 | awk '{$1=$1;print}'"_s, success);
    if (!success)
        return u"[]"_s;

    // Extract container images from distrobox list output
    QString imagesOutput = runCommand(u"distrobox list | tail -n +2 | cut -d'|' -f4 | awk '{$1=$1;print}'"_s, success);
    if (!success)
        return u"[]"_s;

    // Split outputs into lists
    QStringList names = namesOutput.split(QChar::fromLatin1('\n'), Qt::SkipEmptyParts);
    QStringList images = imagesOutput.split(QChar::fromLatin1('\n'), Qt::SkipEmptyParts);

    // Create JSON array of container objects
    QJsonArray containerArray;
    for (int i = 0; i < qMin(names.size(), images.size()); ++i) {
        QJsonObject container;
        container[u"name"_s] = names[i];
        container[u"image"_s] = images[i];
        containerArray.append(container);
    }

    return QString::fromUtf8(QJsonDocument(containerArray).toJson());
}

// Lists all available container images in JSON format
QString DistroboxManager::listAvailableImages()
{
    if (m_availableImages.isEmpty() || m_fullImageNames.isEmpty()) {
        return u"[]"_s;
    }

    // Create JSON array of image objects with display and full names
    QJsonArray imageArray;
    for (int i = 0; i < m_availableImages.size() && i < m_fullImageNames.size(); ++i) {
        QJsonObject image;
        image[u"display"_s] = m_availableImages[i];
        image[u"full"_s] = m_fullImageNames[i];
        imageArray.append(image);
    }

    return QString::fromUtf8(QJsonDocument(imageArray).toJson());
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
    runCommand(command, success);
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
    runCommand(command, success);
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
    QString imageLower = image.toLower();

    // Structure to hold distribution regex patterns and their associated colors
    struct DistroColor {
        QRegularExpression regex;
        QString color;
    };

    // List of known distributions and their brand colors
    const QVector<DistroColor> distroColors = {// Major distributions
                                               {QRegularExpression(u"fedora|bluefin|ublue-os/fedora|fedoraproject\\.org/fedora"_s), u"#3c6eb4"_s},
                                               {QRegularExpression(u"ubuntu|toolbx/ubuntu|ubuntu-toolbox"_s), u"#e95420"_s},
                                               {QRegularExpression(u"debian|neurodebian"_s), u"#d70a53"_s},
                                               {QRegularExpression(u"opensuse|tumbleweed|leap"_s), u"#73ba25"_s},
                                               {QRegularExpression(u"arch|blackarch|ublue-os/arch|bazzite-arch|arch-toolbox"_s), u"#1793d1"_s},
                                               {QRegularExpression(u"centos|rhel|rocky|alma|ubi[789]?/|amazonlinux"_s), u"#262577"_s},
                                               // Other distributions
                                               {QRegularExpression(u"gentoo"_s), u"#54487a"_s},
                                               {QRegularExpression(u"alpine"_s), u"#0d597f"_s},
                                               {QRegularExpression(u"kali"_s), u"#367bf0"_s},
                                               {QRegularExpression(u"mint"_s), u"#87cf3e"_s},
                                               {QRegularExpression(u"void"_s), u"#478061"_s},
                                               {QRegularExpression(u"nixos"_s), u"#5277c3"_s},
                                               {QRegularExpression(u"deepin|linuxdeepin"_s), u"#0188D7"_s},
                                               {QRegularExpression(u"crystal"_s), u"#1E63A4"_s},
                                               {QRegularExpression(u"clear"_s), u"#003366"_s},
                                               {QRegularExpression(u"slack"_s), u"#333333"_s},
                                               {QRegularExpression(u"steamos"_s), u"#1A9FFF"_s},
                                               {QRegularExpression(u"vanilla"_s), u"#0F0F0F"_s},
                                               {QRegularExpression(u"wolfi|chainguard"_s), u"#007D9C"_s},
                                               {QRegularExpression(u"oracle"_s), u"#C74634"_s},
                                               {QRegularExpression(u"kde|neon"_s), u"#1D99F3"_s}};

    // Check if image name matches any known distribution
    for (const auto &distro : distroColors) {
        if (imageLower.contains(distro.regex)) {
            return distro.color;
        }
    }

    // If no match found, generate a random pastel color
    auto *rng = QRandomGenerator::global();
    int r = rng->bounded(100, 201); // Range 100-200 for pastel colors
    int g = rng->bounded(100, 201);
    int b = rng->bounded(100, 201);
    return u"#%1%2%3"_s.arg(r, 2, 16, QLatin1Char('0')).arg(g, 2, 16, QLatin1Char('0')).arg(b, 2, 16, QLatin1Char('0'));
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
    runCommand(command, success);
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

    QString installCmd;
    QString imageLower = image.toLower();

    // Determine package manager command based on distribution
    if (imageLower.contains(QRegularExpression(u"fedora|bluefin|ublue-os/fedora|fedoraproject\\.org/fedora"_s))) {
        installCmd = u"sudo dnf install %1"_s.arg(actualPackagePath);
    } else if (imageLower.contains(QRegularExpression(u"ubuntu|toolbx/ubuntu|ubuntu-toolbox|debian|neurodebian|mint|kali|neon"_s))) {
        installCmd = u"sudo apt install %1"_s.arg(actualPackagePath);
    } else if (imageLower.contains(QRegularExpression(u"opensuse|tumbleweed|leap"_s))) {
        installCmd = u"sudo zypper install %1"_s.arg(actualPackagePath);
    } else if (imageLower.contains(QRegularExpression(u"arch|blackarch|ublue-os/arch|bazzite-arch|arch-toolbox"_s))) {
        installCmd = u"sudo pacman -U --noconfirm %1"_s.arg(actualPackagePath);
    } else if (imageLower.contains(QRegularExpression(u"centos|rhel|rocky|alma|ubi[789]?/|amazonlinux|oracle"_s))) {
        installCmd = u"sudo dnf install %1"_s.arg(actualPackagePath);
    } else if (imageLower.contains(QRegularExpression(u"alpine"_s))) {
        installCmd = u"sudo apk add --allow-untrusted %1"_s.arg(actualPackagePath);
    } else if (imageLower.contains(QRegularExpression(u"void"_s))) {
        installCmd = u"sudo xbps-install %1"_s.arg(actualPackagePath);
    } else if (imageLower.contains(QRegularExpression(u"gentoo"_s))) {
        installCmd = u"sudo emerge %1"_s.arg(actualPackagePath);
    } else if (imageLower.contains(QRegularExpression(u"slack"_s))) {
        installCmd = u"sudo installpkg %1"_s.arg(actualPackagePath);
    } else if (imageLower.contains(QRegularExpression(u"wolfi|chainguard"_s))) {
        installCmd = u"sudo apk add --allow-untrusted %1"_s.arg(actualPackagePath);
    } else {
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
    QString fullCmd = u"distrobox enter %1 -- bash -c \"%2 && echo '' && echo '%3' && read -s -n 1\""_s.arg(name, installCmd, message);
    QString command = u"bash -c "_s + KShell::quoteArg(fullCmd);
    return launchCommandInTerminal(command, homeDir);
}

bool DistroboxManager::isFlatpak() const
{
    return QFile::exists(u"/.flatpak-info"_s);
}
