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

    width: 700
    height: 500
    minimumWidth: 600
    minimumHeight: 400

    title: i18n("Applications Management - %1", containerName)

    property string containerName: ""
    property bool loadingExported: true
    property bool loadingAvailable: true
    property bool operationInProgress: false // New property to track operations
    property var exportedApps: []
    property var availableApps: []

    function refreshApplications() {
        console.log("Refreshing applications for container:", containerName)

        // Refresh exported applications
        loadingExported = true
        var exported = distroBoxManager.exportedApps(containerName)
        console.log("Exported apps:", JSON.stringify(exported))
        exportedApps = exported || []
        loadingExported = false

        // Refresh available applications
        loadingAvailable = true
        var available = distroBoxManager.availableApps(containerName)
        console.log("Available apps:", JSON.stringify(available))
        availableApps = available || []
        loadingAvailable = false
    }

    // Function to handle export operations
    function exportApp(appBasename) {
        operationInProgress = true
        distroBoxManager.exportApp(appBasename, containerName)
        refreshTimer.start()
    }

    // Function to handle unexport operations
    function unexportApp(appBasename) {
        operationInProgress = true
        distroBoxManager.unexportApp(appBasename, containerName)
        refreshTimer.start()
    }

    onContainerNameChanged: {
        if (containerName) {
            refreshApplications()
        }
    }

    Component.onCompleted: {
        if (containerName) {
            refreshApplications()
        }
    }

    // Watch for changes in exportedApps to switch tabs
    onExportedAppsChanged: {
        if (exportedApps.length > 0 && operationInProgress) {
            // Switch to exported tab after operation completes
            tabBar.currentIndex = 0
        }
    }

    pageStack.initialPage: Kirigami.Page {
        title: applicationsWindow.title

        // Overlay spinner for operations
        Rectangle {
            id: overlay
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.3)
            visible: operationInProgress
            z: 9999 // Ensure it's on top

            Controls.BusyIndicator {
                anchors.centerIn: parent
                running: parent.visible
                width: Kirigami.Units.iconSizes.large
                height: width
            }
        }

        Controls.TabBar {
            id: tabBar
            width: parent.width

            Controls.TabButton {
                text: i18n("Exported Applications (%1)", exportedApps.length)
            }
            Controls.TabButton {
                text: i18n("Available Applications (%1)", availableApps.length)
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

                        ListView {
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
                                        text: modelData.name || modelData.basename || "Unknown Application"
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        font.bold: true
                                    }

                                    Controls.Button {
                                        text: i18n("Unexport")
                                        icon.name: "list-remove"
                                        onClicked: unexportApp(modelData.basename)
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

                        ListView {
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
                                        text: modelData.name || modelData.basename || "Unknown Application"
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        font.bold: true
                                    }

                                    Controls.Button {
                                        text: i18n("Export")
                                        icon.name: "list-add"
                                        onClicked: exportApp(modelData.basename)
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

    Timer {
        id: refreshTimer
        interval: 1000 // 1 second delay to allow export/unexport operations to complete
        onTriggered: {
            refreshApplications()
            operationInProgress = false // Hide the spinner after refresh
        }
    }
}
