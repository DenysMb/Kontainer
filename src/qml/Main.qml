/*
 *   SPDX-License-Identifier: GPL-3.0-or-later
 *   SPDX-FileCopyrightText: 2025 Denys Madureira <denysmb@zoho.com>
 *   SPDX-FileCopyrightText: 2025 Thomas Duckworth <tduck@filotimoproject.org>
 *   SPDX-FileCopyrightText: 2025 Hadi Chokr <hadichokr@icloud.com>
 */

import QtQuick
import QtCore

import org.kde.kirigami as Kirigami

Kirigami.ApplicationWindow {
    id: root

    width: 700
    height: 500

    title: i18n("Kontainer")

    About {
        id: aboutPage
        visible: false
    }

    property bool refreshing: false

    // persistent settings storage using QtCore.Settings
    Settings {
        id: kontainerSettings
        category: "Appearance"
        property bool showColors: false
    }

    // alias for clarity
    property alias fallbackToDistroColors: kontainerSettings.showColors

    function refresh() {
        refreshing = true;
        var result = distroBoxManager.listContainers();
        containersPage.containersList = JSON.parse(result);
        refreshing = false;
    }

    Connections {
        target: distroBoxManager
        function onContainerCloneFinished(clonedName, success) {
            if (success) {
                refresh();
            }
        }
    }
    Connections {
        target: distroBoxManager
        function onContainerAssembleFinished(success) {
            if (success) {
                refresh()
            }
        }
    }


    globalDrawer: MainGlobalDrawer {
        hasContainers: containersPage.containersList.length > 0
        fallbackToDistroColors: root.fallbackToDistroColors
        onCreateRequested: createDialog.open()
        onShortcutRequested: shortcutDialog.open()
        onCloneRequested: cloneDialog.openWithContainer(containerName)
        onShowContainerIconsToggled: root.fallbackToDistroColors = fallbackToDistroColors
        onAboutRequested: {
            if (root.pageStack.layers.currentItem !== aboutPage) {
                root.pageStack.layers.push(aboutPage);
            }
        }
    }

    ErrorDialog {
        id: errorDialog
    }
    DistroboxRemoveDialog {
        id: removeDialog
        mainPage: containersPage
    }
    DistroboxCreateDialog {
        id: createDialog
        errorDialog: errorDialog
        mainPage: containersPage
    }
    DistroboxShortcutDialog {
        id: shortcutDialog
        containersList: containersPage.containersList
    }
    DistroboxCloneDialog {
        id: cloneDialog
        containersList: containersPage.containersList
    }
    FilePickerDialog {
        id: packageFileDialog
    }

    pageStack.initialPage: MainContainersPage {
        id: containersPage
        fallbackToDistroColors: root.fallbackToDistroColors
        appRefreshing: root.refreshing
        onCreateRequested: createDialog.open()
        onUpgradeAllRequested: distroBoxManager.upgradeAllContainer()
        onRefreshRequested: refresh()
        onInitialLoadRequested: refresh()
        onInstallPackageRequested: function(containerName, containerImage) {
            packageFileDialog.containerName = containerName;
            packageFileDialog.containerImage = containerImage;
            packageFileDialog.open();
        }
        onManageApplicationsRequested: function(containerName) {
            var component = Qt.createComponent("ApplicationsWindow.qml");
            if (component.status === Component.Ready) {
                var window = component.createObject(root, {
                    containerName: containerName
                });
                window.show();
            } else {
                console.error("Error loading ApplicationsWindow:", component.errorString());
            }
        }
        onOpenTerminalRequested: function(containerName) {
            distroBoxManager.enterContainer(containerName);
        }
        onUpgradeContainerRequested: function(containerName) {
            distroBoxManager.upgradeContainer(containerName);
        }
        onCloneContainerRequested: function(containerName) {
            cloneDialog.openWithContainer(containerName);
        }
        onRemoveContainerRequested: function(containerName) {
            removeDialog.containerName = containerName;
            removeDialog.open();
        }
    }
}
