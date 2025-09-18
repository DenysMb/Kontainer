/*
 *   SPDX-License-Identifier: GPL-3.0-or-later
 *   SPDX-FileCopyrightText: 2025 Hadi Chokr <hadichokr@icloud.com>
 */

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Kirigami.ApplicationWindow {
    id: applicationsWindow

    width: 800
    height: 600
    minimumWidth: 600
    minimumHeight: 400

    title: i18n("Applications Management - %1", containerName)

    property string containerName: ""
    property bool loadingExported: true
    property bool loadingAvailable: true
    property var exportedApps: []
    property var availableApps: []

    function refreshApplications() {
        // Refresh exported applications
        loadingExported = true
        var exported = distroBoxManager.exportedApps(containerName)
        exportedApps = exported
        loadingExported = false

        // Refresh available applications
        loadingAvailable = true
        var available = distroBoxManager.availableApps(containerName)
        availableApps = available
        loadingAvailable = false
    }

    onContainerNameChanged: {
        if (containerName) {
            refreshApplications()
        }
    }

    pageStack.initialPage: Kirigami.Page {
        title: applicationsWindow.title

        Controls.TabBar {
            id: tabBar
            width: parent.width

            Controls.TabButton {
                text: i18n("Exported Applications (%1)", exportedApps.length)
            }
            Controls.TabButton {
                text: i18n("Available Applications (%2)", availableApps.length)
            }
        }

        StackLayout {
            width: parent.width
            height: parent.height - tabBar.height
            anchors.top: tabBar.bottom
            currentIndex: tabBar.currentIndex

            // Tab 1: Exported Applications
            Item {
                ColumnLayout {
                    anchors.fill: parent
                    spacing: Kirigami.Units.smallSpacing

                    Controls.BusyIndicator {
                        Layout.alignment: Qt.AlignCenter
                        visible: loadingExported
                        running: visible
                    }

                    Kirigami.PlaceholderMessage {
                        Layout.alignment: Qt.AlignCenter
                        visible: !loadingExported && exportedApps.length === 0
                        text: i18n("No exported applications found")
                        helpfulAction: Kirigami.Action {
                            text: i18n("Switch to Available tab")
                            icon.name: "go-next"
                            onTriggered: tabBar.currentIndex = 1
                        }
                    }

                    Controls.ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: !loadingExported && exportedApps.length > 0

                        Controls.ListView {
                            id: exportedListView
                            model: exportedApps
                            spacing: Kirigami.Units.smallSpacing

                            delegate: Kirigami.AbstractCard {
                                width: exportedListView.width - Kirigami.Units.smallSpacing * 2

                                contentItem: RowLayout {
                                    spacing: Kirigami.Units.largeSpacing

                                    Kirigami.Icon {
                                        source: modelData.icon || "application-x-executable"
                                        width: Kirigami.Units.iconSizes.medium
                                        height: width
                                    }

                                    Controls.Label {
                                        text: modelData.name
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        font.bold: true
                                    }

                                    Controls.Button {
                                        text: i18n("Unexport")
                                        icon.name: "list-remove"
                                        onClicked: {
                                            distroBoxManager.unexportApp(modelData.basename, containerName)
                                            refreshApplications()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Tab 2: Available Applications
            Item {
                ColumnLayout {
                    anchors.fill: parent
                    spacing: Kirigami.Units.smallSpacing

                    Controls.BusyIndicator {
                        Layout.alignment: Qt.AlignCenter
                        visible: loadingAvailable
                        running: visible
                    }

                    Kirigami.PlaceholderMessage {
                        Layout.alignment: Qt.AlignCenter
                        visible: !loadingAvailable && availableApps.length === 0
                        text: i18n("No applications found in container")
                    }

                    Controls.ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: !loadingAvailable && availableApps.length > 0

                        Controls.ListView {
                            id: availableListView
                            model: availableApps
                            spacing: Kirigami.Units.smallSpacing

                            delegate: Kirigami.AbstractCard {
                                width: availableListView.width - Kirigami.Units.smallSpacing * 2

                                contentItem: RowLayout {
                                    spacing: Kirigami.Units.largeSpacing

                                    Kirigami.Icon {
                                        source: modelData.icon || "application-x-executable"
                                        width: Kirigami.Units.iconSizes.medium
                                        height: width
                                    }

                                    Controls.Label {
                                        text: modelData.name
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        font.bold: true
                                    }

                                    Controls.Button {
                                        text: i18n("Export")
                                        icon.name: "list-add"
                                        onClicked: {
                                            distroBoxManager.exportApp(modelData.basename, containerName)
                                            refreshApplications()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        actions: [
            Kirigami.Action {
                text: i18n("Refresh")
                icon.name: "view-refresh"
                onTriggered: refreshApplications()
            },
            Kirigami.Action {
                text: i18n("Close")
                icon.name: "window-close"
                onTriggered: applicationsWindow.close()
            }
        ]
    }
}
