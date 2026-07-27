/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick
import org.kde.kirigami as Kirigami

Kirigami.GlobalDrawer {
    id: drawer

    property bool hasContainers: false
    property bool fallbackToDistroColors: false
    property bool showContainerStatus: false

    signal createRequested()
    signal shortcutRequested()
    signal cloneRequested(string containerName)
    signal showContainerIconsToggled(bool fallbackToDistroColors)
    signal showContainerStatusToggled(bool status)
    signal aboutRequested()

    isMenu: true

    actions: [
        Kirigami.Action {
            text: i18n("Create Container…")
            icon.name: "list-add"
            onTriggered: drawer.createRequested()
        },
        Kirigami.Action {
            text: i18n("Create Distrobox Shortcut…")
            icon.name: "document-new"
            enabled: drawer.hasContainers
            onTriggered: drawer.shortcutRequested()
        },
        Kirigami.Action {
            separator: true
        },
        Kirigami.Action {
            text: i18n("Show Container Icons")
            icon.name: "view-list-icons"
            checkable: true
            checked: !drawer.fallbackToDistroColors
            onToggled: drawer.showContainerIconsToggled(!checked)
        },
        Kirigami.Action {
            text: i18n("Show Container Status")
            icon.name: "office-chart-bar"
            checkable: true
            checked: drawer.showContainerStatus
            onToggled: drawer.showContainerStatusToggled(checked)
        },
        Kirigami.Action {
            text: i18n("Clone Container…")
            icon.name: "edit-copy"
            enabled: drawer.hasContainers
            onTriggered: drawer.cloneRequested("")
        },
        Kirigami.Action {
            separator: true
        },
        Kirigami.Action {
            text: i18n("Open Distrobox Documentation")
            icon.name: "help-contents"
            onTriggered: Qt.openUrlExternally("https://distrobox.it/#distrobox")
        },
        Kirigami.Action {
            text: i18n("Open Distrobox Useful Tips")
            icon.name: "help-hint"
            onTriggered: Qt.openUrlExternally("https://github.com/89luca89/distrobox/blob/main/docs/useful_tips.md")
        },
        Kirigami.Action {
            separator: true
        },
        Kirigami.Action {
            text: i18n("About Kontainer")
            icon.name: "io.github.DenysMb.Kontainer"
            onTriggered: drawer.aboutRequested()
        }
    ]
}
