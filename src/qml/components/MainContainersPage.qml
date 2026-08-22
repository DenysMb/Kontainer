/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.ScrollablePage {
    id: page

    property var containersList: []
    property bool appRefreshing: false
    property bool fallbackToDistroColors: false
    property bool containerEngineAvailable: true
    property var pendingContainers: ({}) // Map of containerName -> bool
    property var containerStats: ({})
    property bool showContainerStatus: false
    property string statusFilter: "all" // all | running | stopped
    property string sortMode: "name" // name | status
    property string searchText: ""
    property bool searching: false
    property var filteredContainers: []

    function updateView() {
        function isRunning(entry) {
            var status = (entry.status || "").toLowerCase();
            return status.startsWith("up") || status.indexOf("paus") >= 0;
        }
        var list = page.containersList.slice();
        if (page.statusFilter === "running") {
            list = list.filter(function (entry) {
                return isRunning(entry);
            });
        } else if (page.statusFilter === "stopped") {
            list = list.filter(function (entry) {
                return !isRunning(entry);
            });
        }
        if (page.searchText !== "") {
            list = list.filter(function (entry) {
                return (entry.name || "").toLowerCase().indexOf(page.searchText.toLowerCase()) >= 0;
            });
        }
        if (page.sortMode === "status") {
            list.sort(function (a, b) {
                if (isRunning(a) === isRunning(b)) {
                    return (a.name || "").localeCompare(b.name || "");
                }
                return isRunning(a) ? -1 : 1;
            });
        } else {
            list.sort(function (a, b) {
                return (a.name || "").localeCompare(b.name || "");
            });
        }
        page.filteredContainers = list;
    }

    onContainersListChanged: updateView()
    onStatusFilterChanged: updateView()
    onSortModeChanged: updateView()
    onSearchTextChanged: updateView()

    signal createRequested
    signal upgradeAllRequested
    signal refreshRequested
    signal initialLoadRequested
    signal installPackageRequested(string containerName, string containerImage)
    signal manageApplicationsRequested(string containerName)
    signal manageBinariesRequested(string containerName)
    signal openTerminalRequested(string containerName)
    signal openFileManagerRequested(string containerName)
    signal upgradeContainerRequested(string containerName)
    signal cloneContainerRequested(string containerName)
    signal removeContainerRequested(string containerName)
    signal startContainerRequested(string containerName, bool setPending)
    signal stopContainerRequested(string containerName, bool setPending)
    signal rebootContainerRequested(string containerName, bool setPending)

    spacing: Kirigami.Units.smallSpacing
    padding: Kirigami.Units.smallSpacing

    title: i18n("Distrobox Containers")

    footer: Controls.ToolBar {
        visible: page.searching

        Kirigami.SearchField {
            id: searchField

            anchors.fill: parent
            placeholderText: i18n("Search containers…")
            onTextChanged: page.searchText = text
            Keys.onEscapePressed: page.searching = false

            onVisibleChanged: {
                if (visible) {
                    forceActiveFocus();
                } else if (text !== "") {
                    text = "";
                }
            }
        }
    }

    supportsRefreshing: true
    onRefreshingChanged: if (refreshing)
        page.refreshRequested()

    actions: [
        Kirigami.Action {
            text: i18n("Create…")
            icon.name: "list-add"
            shortcut: "Ctrl+N"
            enabled: page.containerEngineAvailable
            onTriggered: page.createRequested()
        },
        Kirigami.Action {
            text: i18n("Upgrade all…")
            icon.name: "system-software-update"
            shortcut: "Ctrl+U"
            enabled: page.containerEngineAvailable
            onTriggered: page.upgradeAllRequested()
        },
        Kirigami.Action {
            text: i18n("Refresh")
            icon.name: "view-refresh"
            shortcut: "F5"
            onTriggered: page.refreshRequested()
        },
        Kirigami.Action {
            text: i18n("Search containers…")
            icon.name: "edit-find"
            shortcut: "Ctrl+F"
            displayHint: Kirigami.DisplayHint.AlwaysHide
            onTriggered: page.searching = !page.searching
        },
        Kirigami.Action {
            text: i18n("Filter")
            icon.name: "view-filter"
            displayHint: Kirigami.DisplayHint.AlwaysHide
            Kirigami.Action {
                text: i18n("All statuses")
                checkable: true
                checked: page.statusFilter === "all"
                onTriggered: page.statusFilter = "all"
            }
            Kirigami.Action {
                text: i18n("Running")
                checkable: true
                checked: page.statusFilter === "running"
                onTriggered: page.statusFilter = "running"
            }
            Kirigami.Action {
                text: i18n("Stopped")
                checkable: true
                checked: page.statusFilter === "stopped"
                onTriggered: page.statusFilter = "stopped"
            }
        },
        Kirigami.Action {
            text: i18n("Sort")
            icon.name: "view-sort-ascending"
            displayHint: Kirigami.DisplayHint.AlwaysHide
            Kirigami.Action {
                text: i18n("By name")
                checkable: true
                checked: page.sortMode === "name"
                onTriggered: page.sortMode = "name"
            }
            Kirigami.Action {
                text: i18n("By status")
                checkable: true
                checked: page.sortMode === "status"
                onTriggered: page.sortMode = "status"
            }
        }
    ]

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.largeSpacing

        Kirigami.CardsListView {
            id: containersListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: page.filteredContainers

            delegate: ContainerCard {
                container: modelData
                fallbackToDistroColors: page.fallbackToDistroColors
                showContainerStatus: page.showContainerStatus
                isPending: page.pendingContainers[modelData.name] || false
                stats: page.containerStats[modelData.name] || null
                onInstallPackageRequested: function (containerName, containerImage) {
                    page.installPackageRequested(containerName, containerImage);
                }
                onManageApplicationsRequested: function (containerName) {
                    page.manageApplicationsRequested(containerName);
                }
                onManageBinariesRequested: function (containerName) {
                    page.manageBinariesRequested(containerName);
                }
                onOpenTerminalRequested: function (containerName) {
                    page.openTerminalRequested(containerName);
                }
                onOpenFileManagerRequested: function (containerName) {
                    page.openFileManagerRequested(containerName);
                }
                onUpgradeContainerRequested: function (containerName) {
                    page.upgradeContainerRequested(containerName);
                }
                onCloneContainerRequested: function (containerName) {
                    page.cloneContainerRequested(containerName);
                }
                onRemoveContainerRequested: function (containerName) {
                    page.removeContainerRequested(containerName);
                }
                onStartContainerRequested: function (containerName) {
                    page.startContainerRequested(containerName, true);
                }
                onStopContainerRequested: function (containerName) {
                    page.stopContainerRequested(containerName, true);
                }
                onRebootContainerRequested: function (containerName) {
                    page.rebootContainerRequested(containerName, true);
                }
            }

            ContainerListStatus {
                isEmpty: page.containersList.length === 0
                isRefreshing: page.appRefreshing
                containerEngineAvailable: page.containerEngineAvailable
                onCreateRequested: page.createRequested()
            }
        }
    }

    Component.onCompleted: {
        updateView();
        page.initialLoadRequested();
    }
}
