/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.ActionToolBar {
    id: toolbar

    property string containerName: ""
    property string containerImage: ""
    property string containerStatus: ""
    property bool isPending: false

    signal installPackageRequested(string containerName, string containerImage)
    signal manageApplicationsRequested(string containerName)
    signal openTerminalRequested(string containerName)
    signal upgradeContainerRequested(string containerName)
    signal cloneContainerRequested(string containerName)
    signal removeContainerRequested(string containerName)
    signal startContainerRequested(string containerName)
    signal stopContainerRequested(string containerName)
    signal rebootContainerRequested(string containerName)

    Layout.fillWidth: true
    Layout.fillHeight: true
    spacing: Kirigami.Units.smallSpacing
    alignment: Qt.AlignRight
    display: Controls.Button.IconOnly
    flat: false

    actions: [
        Kirigami.Action {
            readonly property bool isRunning: toolbar.containerStatus.toLowerCase().includes("up")
            icon.name: isRunning ? "process-stop-symbolic" : "media-playback-start"
            text: isRunning ? i18n("Stop Container") : i18n("Start Container")
            enabled: !toolbar.isPending
            onTriggered: {
                if (isRunning) {
                    toolbar.stopContainerRequested(toolbar.containerName);
                } else {
                    toolbar.startContainerRequested(toolbar.containerName);
                }
            }
        },
        Kirigami.Action {
            icon.name: "applications-all-symbolic"
            text: i18n("Manage Applications")
            enabled: !toolbar.isPending
            onTriggered: toolbar.manageApplicationsRequested(toolbar.containerName)
        },
        Kirigami.Action {
            icon.name: "utilities-terminal-symbolic"
            text: i18n("Open Terminal")
            enabled: !toolbar.isPending
            onTriggered: toolbar.openTerminalRequested(toolbar.containerName)
        },
        Kirigami.Action {
            text: i18n("More options")
            icon.name: "view-more-symbolic"
            enabled: !toolbar.isPending
            Kirigami.Action {
                icon.name: "package-x-generic"
                text: i18n("Install Package")
                enabled: !toolbar.isPending
                onTriggered: toolbar.installPackageRequested(toolbar.containerName, toolbar.containerImage)
            }
            Kirigami.Action {
                icon.name: "system-reboot"
                text: i18n("Reboot Container")
                enabled: !toolbar.isPending
                onTriggered: toolbar.rebootContainerRequested(toolbar.containerName)
            }
            Kirigami.Action {
                icon.name: "system-software-update"
                text: i18n("Upgrade Container")
                enabled: !toolbar.isPending
                onTriggered: toolbar.upgradeContainerRequested(toolbar.containerName)
            }
            Kirigami.Action {
                icon.name: "edit-copy"
                text: i18n("Clone Container")
                enabled: !toolbar.isPending
                onTriggered: toolbar.cloneContainerRequested(toolbar.containerName)
            }
            Kirigami.Action {
                icon.name: "delete"
                text: i18n("Remove Container")
                enabled: !toolbar.isPending
                onTriggered: toolbar.removeContainerRequested(toolbar.containerName)
            }
        }
    ]
}
