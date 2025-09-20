/*
 *    SPDX-License-Identifier: GPL-3.0-or-later
 *    SPDX-FileCopyrightText: 2025 Denys Madureira <denysmb@zoho.com>
 *    SPDX-FileCopyrightText: 2025 Hadi Chokr <hadichokr@icloud.com>
 */

#pragma once

#include <QDir>
#include <QObject>
#include <QString>
#include <QStringList>

/**
 * @class DistroboxManager
 * @brief Manages interactions with Distrobox containers
 *
 * This class provides a Qt-based interface to manage Distrobox containers.
 * It handles container creation, deletion, listing, and various container operations.
 * Distrobox allows running Linux distributions as containers with full integration
 * with the host system.
 */
class DistroboxManager : public QObject
{
    Q_OBJECT

public:
    /**
     * @brief Constructs a DistroboxManager object
     * @param parent The parent QObject (optional)
     *
     * During construction, it initializes the list of available images
     * that can be used to create containers.
     */
    explicit DistroboxManager(QObject *parent = nullptr);

    /**
     * @struct ExportedApp
     * @brief Represents an application exported from a container to the host
     *
     * Contains information about the exported application, including
     * its filesystem basename, display name, and icon name/path.
     */
    struct ExportedApp {
        QString basename; ///< The binary or executable basename
        QString name; ///< Display name of the application
        QString icon; ///< Icon name or path
    };

    /**
     * @struct AvailableApp
     * @brief Represents an application available inside a container
     *
     * Contains metadata about an application that exists inside a container,
     * which can potentially be exported to the host system.
     */
    struct AvailableApp {
        QString basename; ///< The binary or executable basename
        QString name; ///< Display name of the application
        QString icon; ///< Icon name or path
    };

public Q_SLOTS:

    /**
     * @brief Lists all existing Distrobox containers
     * @return JSON string containing array of containers with their names and base images
     */
    QString listContainers();

    /**
     * @brief Lists all available container images
     * @return JSON string containing array of available images with display and full names
     */
    QString listAvailableImages();

    /**
     * @brief Creates a new Distrobox container
     * @param name Name for the new container
     * @param image Base image to use for the container
     * @param args Additional arguments to pass to distrobox create command
     * @return true if container creation was successful, false otherwise
     */
    bool createContainer(const QString &name, const QString &image, const QString &args);

    /**
     * @brief Opens an interactive shell in the specified container
     * @param name Name of the container to enter
     * @return true if the operation was successful, false otherwise
     */
    bool enterContainer(const QString &name);

    /**
     * @brief Removes a Distrobox container
     * @param name Name of the container to remove
     * @return true if container removal was successful, false otherwise
     */
    bool removeContainer(const QString &name);

    /**
     * @brief Upgrades packages in the specified container
     * @param name Name of the container to upgrade
     * @return true if upgrade was successful, false otherwise
     */
    bool upgradeContainer(const QString &name);

    /**
     * @brief Gets a color associated with the distribution
     * @param image Base image name to get color for
     * @return Hex color code (e.g., "#FF0000") for the distribution
     */
    QString getDistroColor(const QString &image);

    /**
     * @brief Generates desktop entry files for container applications
     * @param name Container name (optional, generates for all containers if empty)
     * @return true if entry generation was successful, false otherwise
     */
    bool generateEntry(const QString &name = QString());

    /**
     * @brief Installs a package file in a container
     * @param name Container name
     * @param packagePath Path to the package file to install
     * @param image Base image name (used to determine package manager)
     * @return true if package installation was successful, false otherwise
     */
    bool installPackageInContainer(const QString &name, const QString &packagePath, const QString &image);

    /**
     * @brief Checks if the application is running as a Flatpak
     * @return true if running as Flatpak, false otherwise
     */
    bool isFlatpak() const;

    /**
     * @brief Lists available applications inside the given container
     * @param container Name of the container
     * @return QVariantList of AvailableApp structs representing available applications
     */
    Q_INVOKABLE QVariantList allApps(const QString &container);

    /**
     * @brief Lists applications exported from the given container
     * @param container Name of the container
     * @return QVariantList of ExportedApp structs representing exported applications
     */
    Q_INVOKABLE QVariantList exportedApps(const QString &container);

    /**
     * @brief Exports an application from a container to the host system
     * @param basename Basename of the application to export
     * @param container Name of the container
     * @return true if export was successful, false otherwise
     */
    Q_INVOKABLE bool exportApp(const QString &basename, const QString &container);

    /**
     * @brief Removes an exported application from the host system
     * @param basename Basename of the exported application
     * @param container Name of the container the application was exported from
     * @return true if unexport was successful, false otherwise
     */
    Q_INVOKABLE bool unexportApp(const QString &basename, const QString &container);

private:
    QStringList m_availableImages; ///< List of available container base images
    QStringList m_fullImageNames; ///< List of full image names/URLs

    /**
     * @brief Launches a command in a terminal window
     * @param command Command to execute
     * @param workingDirectory Directory to start the terminal in (optional)
     * @return true if the terminal was successfully launched, false otherwise
     */
    bool launchCommandInTerminal(const QString &command, const QString &workingDirectory = QDir::homePath());
};
