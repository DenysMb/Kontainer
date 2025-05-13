/*
    SPDX-License-Identifier: GPL-3.0-or-later
    SPDX-FileCopyrightText: 2025 Denys Madureira <denysmb@zoho.com>
*/

#pragma once

#include <QObject>
#include <QProcess>
#include <QString>

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

private:
    QStringList m_availableImages; ///< List of available container base images
    QStringList m_fullImageNames; ///< List of full image names/URLs

    /**
     * @brief Executes a shell command and returns its output
     * @param command Command to execute
     * @param success Set to true if command succeeded, false otherwise
     * @return Command output as string
     */
    QString runCommand(const QString &command, bool &success) const;

    /**
     * @brief Gets list of available container images
     * @return List of available image names
     */
    QStringList getAvailableImages() const;

    /**
     * @brief Gets list of full image names/URLs
     * @return List of full image names
     */
    QStringList getFullImageNames() const;
};
