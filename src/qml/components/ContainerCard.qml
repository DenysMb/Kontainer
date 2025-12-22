/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.AbstractCard {
    id: card

    property var container: ({})
    property bool fallbackToDistroColors: false

    signal installPackageRequested(string containerName, string containerImage)
    signal manageApplicationsRequested(string containerName)
    signal openTerminalRequested(string containerName)
    signal upgradeContainerRequested(string containerName)
    signal cloneContainerRequested(string containerName)
    signal removeContainerRequested(string containerName)
    signal startContainerRequested(string containerName)
    signal stopContainerRequested(string containerName)
    signal rebootContainerRequested(string containerName)

    contentItem: RowLayout {
        spacing: Kirigami.Units.smallSpacing

        ContainerBadge {
            fallbackToDistroColors: card.fallbackToDistroColors
            containerName: card.container.name || ""
            containerImage: card.container.image || ""
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: Kirigami.Units.smallSpacing

            ColumnLayout {
                spacing: Kirigami.Units.smallSpacing
                Layout.maximumWidth: implicitWidth

                Controls.Label {
                    text: card.container.name ? card.container.name.charAt(0).toUpperCase() + card.container.name.slice(1) : ""
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
                    font.bold: true
                }

                Controls.Label {
                    text: card.container.image || ""
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    opacity: 0.7
                }
            }

            ContainerActionsToolbar {
                containerName: card.container.name || ""
                containerImage: card.container.image || ""
                containerStatus: card.container.status || ""
                onInstallPackageRequested: function(containerName, containerImage) {
                    card.installPackageRequested(containerName, containerImage)
                }
                onManageApplicationsRequested: function(containerName) {
                    card.manageApplicationsRequested(containerName)
                }
                onOpenTerminalRequested: function(containerName) {
                    card.openTerminalRequested(containerName)
                }
                onUpgradeContainerRequested: function(containerName) {
                    card.upgradeContainerRequested(containerName)
                }
                onCloneContainerRequested: function(containerName) {
                    card.cloneContainerRequested(containerName)
                }
                onRemoveContainerRequested: function(containerName) {
                    card.removeContainerRequested(containerName)
                }
                onStartContainerRequested: function(containerName) {
                    card.startContainerRequested(containerName)
                }
                onStopContainerRequested: function(containerName) {
                    card.stopContainerRequested(containerName)
                }
                onRebootContainerRequested: function(containerName) {
                    card.rebootContainerRequested(containerName)
                }
            }
        }
    }
}
