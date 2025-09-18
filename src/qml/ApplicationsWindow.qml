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
    property bool loading: true
    property bool operationInProgress: false
    property var exportedApps: []
    property var availableApps: []
    property var selectedApps: ({})
    property string lastOperation: ""
    // Separate search text for each tab
    property string exportedSearchText: ""
    property string availableSearchText: ""

    signal dataReady() // emitted when both lists are loaded

    function refreshApplications() {
        loading = true

        // Let the window paint first
        Qt.callLater(function() {
            exportedApps = distroBoxManager.exportedApps(containerName) || []
            availableApps = distroBoxManager.availableApps(containerName) || []
            loading = false
            dataReady()
        })
    }

    function refreshAppLists() {
        // Only refresh the lists without showing loading screen
        Qt.callLater(function() {
            var oldExportedCount = exportedApps.length;
            exportedApps = distroBoxManager.exportedApps(containerName) || []
            availableApps = distroBoxManager.availableApps(containerName) || []

            // Switch to exported tab if we just exported an app and the count increased
            if (exportedApps.length > oldExportedCount && tabBar.currentIndex === 1) {
                tabBar.currentIndex = 0;
            }
        })
    }

    function filterApps(apps, searchText) {
        if (!searchText) return apps;
        return apps.filter(function(app) {
            return app.name && app.name.toLowerCase().includes(searchText.toLowerCase()) ||
            app.basename && app.basename.toLowerCase().includes(searchText.toLowerCase());
        });
    }

    onContainerNameChanged: {
        if (containerName) refreshApplications()
    }

    // Loader ensures main UI is only created after data is ready
    Loader {
        id: mainContentLoader
        anchors.fill: parent
        active: !loading
        sourceComponent: mainContentComponent
    }

    // Simple cogwheel loader without background
    Controls.BusyIndicator {
        anchors.centerIn: parent
        running: loading || operationInProgress
        visible: loading || operationInProgress
        width: Kirigami.Units.iconSizes.huge
        height: width
        z: 1000
    }

    // Main content component loaded after data
    Component {
        id: mainContentComponent

        Kirigami.Page {
            id: page

            title: applicationsWindow.title

            // Global actions for the page (refresh and close)
            actions: [
                Kirigami.Action {
                    id: refreshAction
                    text: i18n("Refresh")
                    icon.name: "view-refresh"
                    onTriggered: refreshApplications()
                    shortcut: "F5"
                },
                Kirigami.Action {
                    text: i18n("Close")
                    icon.name: "window-close"
                    onTriggered: applicationsWindow.close()
                    shortcut: "Ctrl+W"
                }
            ]

            header: Controls.ToolBar {
                contentItem: RowLayout {
                    Controls.ToolButton {
                        action: refreshAction
                        visible: true
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    Controls.ToolButton {
                        icon.name: "window-close"
                        text: i18n("Close")
                        onClicked: applicationsWindow.close()
                    }
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

                        RowLayout {
                            Layout.fillWidth: true
                            visible: filterApps(exportedApps, exportedSearchText).length > 0 || exportedSearchText.length > 0
                            Controls.TextField {
                                id: exportedSearchField
                                Layout.fillWidth: true
                                placeholderText: i18n("Search exported applications...")
                                onTextChanged: exportedSearchText = text
                            }
                            Controls.Button {
                                icon.name: "edit-clear"
                                text: i18n("Clear")
                                onClicked: {
                                    exportedSearchField.text = ""
                                    exportedSearchText = ""
                                }
                                visible: exportedSearchField.text.length > 0
                            }
                        }

                        Kirigami.PlaceholderMessage {
                            Layout.alignment: Qt.AlignCenter
                            visible: filterApps(exportedApps, exportedSearchText).length === 0
                            text: exportedSearchText ? i18n("No exported applications found matching '%1'", exportedSearchText)
                            : i18n("No exported applications found")
                            helpfulAction: Kirigami.Action {
                                text: i18n("Switch to Available tab")
                                icon.name: "go-next"
                                onTriggered: tabBar.currentIndex = 1
                            }
                        }

                        Controls.ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: filterApps(exportedApps, exportedSearchText).length > 0

                            ListView {
                                id: exportedListView
                                model: filterApps(exportedApps, exportedSearchText)
                                spacing: Kirigami.Units.smallSpacing

                                delegate: Kirigami.AbstractCard {
                                    width: exportedListView.width - Kirigami.Units.smallSpacing * 2

                                    contentItem: RowLayout {
                                        spacing: Kirigami.Units.largeSpacing

                                        Controls.CheckBox {
                                            checked: selectedApps[modelData.basename] || false
                                            onCheckedChanged: selectedApps[modelData.basename] = checked
                                            visible: Object.keys(selectedApps).length > 0 || checked
                                        }

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
                                            enabled: !operationInProgress
                                            onClicked: {
                                                operationInProgress = true;
                                                lastOperation = modelData.name || modelData.basename;
                                                var success = distroBoxManager.unexportApp(modelData.basename, containerName);
                                                if (success) {
                                                    refreshAppLists();
                                                    operationInProgress = false;
                                                } else {
                                                    showPassiveNotification(i18n("Failed to unexport application"));
                                                    lastOperation = "";
                                                    operationInProgress = false;
                                                }
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

                        RowLayout {
                            Layout.fillWidth: true
                            visible: filterApps(availableApps, availableSearchText).length > 0 || availableSearchText.length > 0
                            Controls.TextField {
                                id: availableSearchField
                                Layout.fillWidth: true
                                placeholderText: i18n("Search available applications...")
                                onTextChanged: availableSearchText = text
                            }
                            Controls.Button {
                                icon.name: "edit-clear"
                                text: i18n("Clear")
                                onClicked: {
                                    availableSearchField.text = ""
                                    availableSearchText = ""
                                }
                                visible: availableSearchField.text.length > 0
                            }
                        }

                        Kirigami.PlaceholderMessage {
                            Layout.alignment: Qt.AlignCenter
                            visible: filterApps(availableApps, availableSearchText).length === 0
                            text: availableSearchText ? i18n("No applications found matching '%1'", availableSearchText)
                            : i18n("No applications found in container")
                            explanation: availableSearchText ? "" : i18n("This container might not have desktop applications installed or they might not be detectable.")
                            helpfulAction: Kirigami.Action {
                                text: i18n("Open Distrobox to install applications")
                                icon.name: "application-menu"
                                onTriggered: distroBoxManager.enterContainer(containerName)
                            }
                        }

                        Controls.ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: filterApps(availableApps, availableSearchText).length > 0

                            ListView {
                                id: availableListView
                                model: filterApps(availableApps, availableSearchText)
                                spacing: Kirigami.Units.smallSpacing

                                delegate: Kirigami.AbstractCard {
                                    width: availableListView.width - Kirigami.Units.smallSpacing * 2

                                    contentItem: RowLayout {
                                        spacing: Kirigami.Units.largeSpacing

                                        Controls.CheckBox {
                                            checked: selectedApps[modelData.basename] || false
                                            onCheckedChanged: selectedApps[modelData.basename] = checked
                                            visible: Object.keys(selectedApps).length > 0 || checked
                                        }

                                        Kirigami.Icon {
                                            source: modelData.icon || "package-x-generic"
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
                                            enabled: !operationInProgress
                                            onClicked: {
                                                operationInProgress = true;
                                                lastOperation = modelData.name || modelData.basename;
                                                var success = distroBoxManager.exportApp(modelData.basename, containerName);
                                                if (success) {
                                                    // Switch to exported tab after exporting
                                                    tabBar.currentIndex = 0;
                                                    refreshAppLists();
                                                    operationInProgress = false;
                                                } else {
                                                    showPassiveNotification(i18n("Failed to export application"));
                                                    lastOperation = "";
                                                    operationInProgress = false;
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            footer: Controls.ToolBar {
                visible: Object.keys(selectedApps).length > 0
                RowLayout {
                    width: parent.width
                    Controls.Label { text: i18n("%1 selected", Object.keys(selectedApps).length) }
                    Item { Layout.fillWidth: true }
                    Controls.Button {
                        text: tabBar.currentIndex === 0 ? i18n("Unexport Selected") : i18n("Export Selected")
                        icon.name: tabBar.currentIndex === 0 ? "list-remove" : "list-add"
                        enabled: !operationInProgress
                        onClicked: {
                            operationInProgress = true;
                            var appNames = Object.keys(selectedApps).filter(function(key) { return selectedApps[key] });
                            for (var i=0; i<appNames.length; i++) {
                                if (tabBar.currentIndex === 0) {
                                    distroBoxManager.unexportApp(appNames[i], containerName);
                                } else {
                                    distroBoxManager.exportApp(appNames[i], containerName);
                                }
                            }
                            lastOperation = i18n("%1 applications", appNames.length);
                            selectedApps = {};

                            // Switch to exported tab if we exported apps
                            if (tabBar.currentIndex === 1) {
                                tabBar.currentIndex = 0;
                            }
                            refreshAppLists();
                            operationInProgress = false;
                        }
                    }
                    Controls.Button {
                        text: i18n("Clear Selection");
                        icon.name: "edit-clear";
                        onClicked: selectedApps = {};
                        enabled: !operationInProgress
                    }
                }
            }
        }
    }

    Timer {
        id: refreshTimer
        interval: 1000
        onTriggered: refreshApplications()
    }
}
