#include "distroboxmanager.h"
#include <QProcess>
#include <QJsonArray>
#include <QJsonObject>
#include <QJsonDocument>
#include <QDir>
#include <QRegularExpression>
#include <QRandomGenerator>
#include <QFile>

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
    if (isFlatpak())
    {
        actualCommand = QStringLiteral("flatpak-spawn --host ") + command;
    }

    QProcess process;
    // Use sh -c to execute the command to support shell features like pipes
    process.start(QStringLiteral("sh"), QStringList() << QLatin1String("-c") << actualCommand);
    process.waitForFinished();

    // Command is successful if it exits with code 0
    success = (process.exitCode() == 0);
    return QString::fromUtf8(process.readAllStandardOutput());
}

// Gets list of available container images that can be created
QStringList DistroboxManager::getAvailableImages() const
{
    bool success;
    // Run distrobox create -C to list available images
    QString output = runCommand(QStringLiteral("distrobox create -C"), success);

    if (!success)
    {
        return QStringList();
    }

    // Split output into lines and clean up
    QStringList lines = output.split(QChar::fromLatin1('\n'), Qt::SkipEmptyParts);
    if (!lines.isEmpty() && lines.first().trimmed().isEmpty())
    {
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
    QString namesOutput = runCommand(QStringLiteral("distrobox list | tail -n +2 | cut -d'|' -f2 | awk '{$1=$1;print}'"), success);
    if (!success)
        return QStringLiteral("[]");

    // Extract container images from distrobox list output
    QString imagesOutput = runCommand(QStringLiteral("distrobox list | tail -n +2 | cut -d'|' -f4 | awk '{$1=$1;print}'"), success);
    if (!success)
        return QStringLiteral("[]");

    // Split outputs into lists
    QStringList names = namesOutput.split(QChar::fromLatin1('\n'), Qt::SkipEmptyParts);
    QStringList images = imagesOutput.split(QChar::fromLatin1('\n'), Qt::SkipEmptyParts);

    // Create JSON array of container objects
    QJsonArray containerArray;
    for (int i = 0; i < qMin(names.size(), images.size()); ++i)
    {
        QJsonObject container;
        container[QStringLiteral("name")] = names[i];
        container[QStringLiteral("image")] = images[i];
        containerArray.append(container);
    }

    return QString::fromUtf8(QJsonDocument(containerArray).toJson());
}

// Lists all available container images in JSON format
QString DistroboxManager::listAvailableImages()
{
    if (m_availableImages.isEmpty() || m_fullImageNames.isEmpty())
    {
        return QStringLiteral("[]");
    }

    // Create JSON array of image objects with display and full names
    QJsonArray imageArray;
    for (int i = 0; i < m_availableImages.size() && i < m_fullImageNames.size(); ++i)
    {
        QJsonObject image;
        image[QStringLiteral("display")] = m_availableImages[i];
        image[QStringLiteral("full")] = m_fullImageNames[i];
        imageArray.append(image);
    }

    return QString::fromUtf8(QJsonDocument(imageArray).toJson());
}

// Creates a new container with specified name and base image
bool DistroboxManager::createContainer(const QString &name, const QString &image, const QString &args)
{
    // Construct distrobox create command
    QString command = QStringLiteral("distrobox create --name %1 --image %2").arg(name, image);
    if (!args.isEmpty())
    {
        command += QLatin1Char(' ') + args;
    }

    bool success;
    runCommand(command, success);
    return success;
}

// Opens an interactive shell in the specified container using Konsole
bool DistroboxManager::enterContainer(const QString &name)
{
    QString homeDir = QDir::homePath();
    // Open Konsole and run distrobox enter
    QString command = QStringLiteral("konsole --workdir %1 -e distrobox enter %2")
                          .arg(homeDir, name);

    bool success;
    runCommand(command, success);
    return success;
}

// Removes a container
bool DistroboxManager::removeContainer(const QString &name)
{
    // Use -f flag to force removal without confirmation
    QString command = QStringLiteral("distrobox rm -f %1").arg(name);
    bool success;
    runCommand(command, success);
    return success;
}

// Upgrades all packages in a container
bool DistroboxManager::upgradeContainer(const QString &name)
{
    QString homeDir = QDir::homePath();
    // Run upgrade command and wait for user input before closing
    QString upgradeCmd = QStringLiteral("distrobox upgrade %1 && echo '' && echo 'Press any key to close this terminal...' && read -n 1").arg(name);
    QString command = QStringLiteral("konsole --workdir %1 -e bash -c \"%2\"")
                          .arg(homeDir, upgradeCmd);

    bool success;
    runCommand(command, success);
    return success;
}

// Returns a color associated with the distribution for UI purposes
QString DistroboxManager::getDistroColor(const QString &image)
{
    QString imageLower = image.toLower();

    // Structure to hold distribution regex patterns and their associated colors
    struct DistroColor
    {
        QRegularExpression regex;
        QString color;
    };

    // List of known distributions and their brand colors
    const QVector<DistroColor> distroColors = {
        // Major distributions
        {QRegularExpression(QStringLiteral("fedora|bluefin|ublue-os/fedora|fedoraproject\\.org/fedora")), QStringLiteral("#3c6eb4")},
        {QRegularExpression(QStringLiteral("ubuntu|toolbx/ubuntu|ubuntu-toolbox")), QStringLiteral("#e95420")},
        {QRegularExpression(QStringLiteral("debian|neurodebian")), QStringLiteral("#d70a53")},
        {QRegularExpression(QStringLiteral("opensuse|tumbleweed|leap")), QStringLiteral("#73ba25")},
        {QRegularExpression(QStringLiteral("arch|blackarch|ublue-os/arch|bazzite-arch|arch-toolbox")), QStringLiteral("#1793d1")},
        {QRegularExpression(QStringLiteral("centos|rhel|rocky|alma|ubi[789]?/|amazonlinux")), QStringLiteral("#262577")},

        // Other distributions
        {QRegularExpression(QStringLiteral("gentoo")), QStringLiteral("#54487a")},
        {QRegularExpression(QStringLiteral("alpine")), QStringLiteral("#0d597f")},
        {QRegularExpression(QStringLiteral("kali")), QStringLiteral("#367bf0")},
        {QRegularExpression(QStringLiteral("mint")), QStringLiteral("#87cf3e")},
        {QRegularExpression(QStringLiteral("void")), QStringLiteral("#478061")},
        {QRegularExpression(QStringLiteral("nixos")), QStringLiteral("#5277c3")},
        {QRegularExpression(QStringLiteral("deepin|linuxdeepin")), QStringLiteral("#0188D7")},
        {QRegularExpression(QStringLiteral("crystal")), QStringLiteral("#1E63A4")},
        {QRegularExpression(QStringLiteral("clear")), QStringLiteral("#003366")},
        {QRegularExpression(QStringLiteral("slack")), QStringLiteral("#333333")},
        {QRegularExpression(QStringLiteral("steamos")), QStringLiteral("#1A9FFF")},
        {QRegularExpression(QStringLiteral("vanilla")), QStringLiteral("#0F0F0F")},
        {QRegularExpression(QStringLiteral("wolfi|chainguard")), QStringLiteral("#007D9C")},
        {QRegularExpression(QStringLiteral("oracle")), QStringLiteral("#C74634")},
        {QRegularExpression(QStringLiteral("kde|neon")), QStringLiteral("#1D99F3")}};

    // Check if image name matches any known distribution
    for (const auto &distro : distroColors)
    {
        if (imageLower.contains(distro.regex))
        {
            return distro.color;
        }
    }

    // If no match found, generate a random pastel color
    auto *rng = QRandomGenerator::global();
    int r = rng->bounded(100, 201); // Range 100-200 for pastel colors
    int g = rng->bounded(100, 201);
    int b = rng->bounded(100, 201);
    return QStringLiteral("#%1%2%3")
        .arg(r, 2, 16, QLatin1Char('0'))
        .arg(g, 2, 16, QLatin1Char('0'))
        .arg(b, 2, 16, QLatin1Char('0'));
}

// Generates .desktop files for applications in containers
bool DistroboxManager::generateEntry(const QString &name)
{
    QString command;
    if (name.isEmpty())
    {
        // Generate entries for all containers
        command = QStringLiteral("distrobox generate-entry -a");
    }
    else
    {
        // Generate entries for specific container
        command = QStringLiteral("distrobox generate-entry %1").arg(name);
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
    if (actualPackagePath.startsWith(QStringLiteral("file://")))
    {
        actualPackagePath = actualPackagePath.mid(7);
    }

    QString installCmd;
    QString imageLower = image.toLower();

    // Determine package manager command based on distribution
    if (imageLower.contains(QRegularExpression(QStringLiteral("fedora|bluefin|ublue-os/fedora|fedoraproject\\.org/fedora"))))
    {
        installCmd = QStringLiteral("sudo dnf install %1").arg(actualPackagePath);
    }
    else if (imageLower.contains(QRegularExpression(QStringLiteral("ubuntu|toolbx/ubuntu|ubuntu-toolbox|debian|neurodebian|mint|kali|neon"))))
    {
        installCmd = QStringLiteral("sudo apt install %1").arg(actualPackagePath);
    }
    else if (imageLower.contains(QRegularExpression(QStringLiteral("opensuse|tumbleweed|leap"))))
    {
        installCmd = QStringLiteral("sudo zypper install %1").arg(actualPackagePath);
    }
    else if (imageLower.contains(QRegularExpression(QStringLiteral("arch|blackarch|ublue-os/arch|bazzite-arch|arch-toolbox"))))
    {
        installCmd = QStringLiteral("sudo pacman -U --noconfirm %1").arg(actualPackagePath);
    }
    else if (imageLower.contains(QRegularExpression(QStringLiteral("centos|rhel|rocky|alma|ubi[789]?/|amazonlinux|oracle"))))
    {
        installCmd = QStringLiteral("sudo dnf install %1").arg(actualPackagePath);
    }
    else if (imageLower.contains(QRegularExpression(QStringLiteral("alpine"))))
    {
        installCmd = QStringLiteral("sudo apk add --allow-untrusted %1").arg(actualPackagePath);
    }
    else if (imageLower.contains(QRegularExpression(QStringLiteral("void"))))
    {
        installCmd = QStringLiteral("sudo xbps-install %1").arg(actualPackagePath);
    }
    else if (imageLower.contains(QRegularExpression(QStringLiteral("gentoo"))))
    {
        installCmd = QStringLiteral("sudo emerge %1").arg(actualPackagePath);
    }
    else if (imageLower.contains(QRegularExpression(QStringLiteral("slack"))))
    {
        installCmd = QStringLiteral("sudo installpkg %1").arg(actualPackagePath);
    }
    else if (imageLower.contains(QRegularExpression(QStringLiteral("wolfi|chainguard"))))
    {
        installCmd = QStringLiteral("sudo apk add --allow-untrusted %1").arg(actualPackagePath);
    }
    else
    {
        // Show error message if distribution is not recognized
        QString message = QStringLiteral("Cannot automatically install packages for this distribution. Please enter the distrobox manually and install it using the appropriate package manager.");
        QString command = QStringLiteral("konsole --workdir %1 -e bash -c \"echo '%2'; read -n 1\"")
                              .arg(homeDir, message);
        bool success;
        runCommand(command, success);
        return success;
    }

    // Run installation command in container and wait for user input before closing
    QString fullCmd = QStringLiteral("distrobox enter %1 -- %2 && echo '' && echo 'Press any key to close this terminal...' && read -n 1")
                          .arg(name, installCmd);
    QString command = QStringLiteral("konsole --workdir %1 -e bash -c \"%2\"")
                          .arg(homeDir, fullCmd);

    bool success;
    runCommand(command, success);
    return success;
}

bool DistroboxManager::isFlatpak() const
{
    return QFile::exists(QStringLiteral("/.flatpak-info"));
}