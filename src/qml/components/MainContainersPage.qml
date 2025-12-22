/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.ScrollablePage {
    id: page

    property var containersList: []
    property bool appRefreshing: false
    property bool fallbackToDistroColors: false
    property bool containerEngineAvailable: true
    property var pendingContainers: ({}) // Map of containerName -> bool

    signal createRequested
    signal upgradeAllRequested
    signal refreshRequested
    signal initialLoadRequested
    signal installPackageRequested(string containerName, string containerImage)
    signal manageApplicationsRequested(string containerName)
    signal openTerminalRequested(string containerName)
    signal upgradeContainerRequested(string containerName)
    signal cloneContainerRequested(string containerName)
    signal removeContainerRequested(string containerName)
    signal startContainerRequested(string containerName, bool setPending)
    signal stopContainerRequested(string containerName, bool setPending)
    signal rebootContainerRequested(string containerName, bool setPending)

    spacing: Kirigami.Units.smallSpacing
    padding: Kirigami.Units.smallSpacing

    title: i18n("Distrobox Containers")

    supportsRefreshing: true
    onRefreshingChanged: if (refreshing)
        page.refreshRequested()

    actions: [
        Kirigami.Action {
            text: i18n("Create…")
            icon.name: "list-add"
            enabled: page.containerEngineAvailable
            onTriggered: page.createRequested()
        },
        Kirigami.Action {
            text: i18n("Upgrade all…")
            icon.name: "system-software-update"
            enabled: page.containerEngineAvailable
            onTriggered: page.upgradeAllRequested()
        },
        Kirigami.Action {
            text: i18n("Refresh")
            icon.name: "view-refresh"
            onTriggered: page.refreshRequested()
        }
    ]

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.largeSpacing

        Kirigami.CardsListView {
            id: containersListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: page.containersList

            delegate: ContainerCard {
                container: modelData
                fallbackToDistroColors: page.fallbackToDistroColors
                isPending: page.pendingContainers[modelData.name] || false
                onInstallPackageRequested: function (containerName, containerImage) {
                    page.installPackageRequested(containerName, containerImage);
                }
                onManageApplicationsRequested: function (containerName) {
                    page.manageApplicationsRequested(containerName);
                }
                onOpenTerminalRequested: function (containerName) {
                    page.openTerminalRequested(containerName);
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
                isEmpty: containersListView.count === 0
                isRefreshing: page.appRefreshing
                containerEngineAvailable: page.containerEngineAvailable
                onCreateRequested: page.createRequested()
            }
        }
    }

    Component.onCompleted: page.initialLoadRequested()
}
