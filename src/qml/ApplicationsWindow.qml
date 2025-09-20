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

    width: 600
    height: 400
    minimumWidth: 600
    minimumHeight: 400

    title: i18n("Applications Management - %1", containerName)

    property string containerName: ""
    property bool loading: true
    property bool operationInProgress: false
    property var exportedApps: []
    property var allApps: []
    property var selectedApps: ({})
    property string lastOperation: ""
    // Separate search text for each tab
    property string exportedSearchText: ""
    property string availableSearchText: ""
    property int currentTabIndex: 0

    signal dataReady // emitted when both lists are loaded

    function refreshApplications() {
        loading = true;

        // Let the window paint first
        Qt.callLater(function () {
            exportedApps = distroBoxManager.exportedApps(containerName) || [];
            allApps = distroBoxManager.allApps(containerName) || [];
            loading = false;
            dataReady();
        });
    }

    function refreshAppLists() {
        // Only refresh the lists without showing loading screen
        Qt.callLater(function () {
            var oldExportedCount = exportedApps.length;
            exportedApps = distroBoxManager.exportedApps(containerName) || [];
            allApps = distroBoxManager.allApps(containerName) || [];

            // Switch to exported tab if we just exported an app and the count increased
            if (exportedApps.length > oldExportedCount && currentTabIndex === 1) {
                currentTabIndex = 0;
            }
        });
    }

    function filterApps(apps, searchText) {
        if (!searchText)
            return apps;
        return apps.filter(function (app) {
            return app.name && app.name.toLowerCase().includes(searchText.toLowerCase()) || app.basename && app.basename.toLowerCase().includes(searchText.toLowerCase());
        });
    }

    function isAppExported(basename) {
        if (!basename || !exportedApps || exportedApps.length === 0)
            return false;

        return exportedApps.some(function (app) {
            return app && app.basename === basename;
        });
    }

    function iconSourceForApp(app) {
        if (!app)
            return "";
        if (app.iconSource)
            return app.iconSource;
        if (app.icon && (app.icon.startsWith("file:") || app.icon.startsWith("/") || app.icon.startsWith("data:")))
            return app.icon;
        return "";
    }

    function iconNameForApp(app, fallbackIcon) {
        if (!app)
            return fallbackIcon;
        if (app.icon && app.icon.length > 0 && !app.icon.startsWith("/") && app.icon.indexOf("://") === -1)
            return app.icon;
        return fallbackIcon;
    }

    onContainerNameChanged: {
        if (containerName)
            refreshApplications();
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
                }
            ]

            header: Controls.ToolBar {
                contentItem: RowLayout {
                    spacing: Kirigami.Units.smallSpacing

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Controls.ToolButton {
                            Layout.fillWidth: true
                            text: i18n("Exported Applications (%1)", exportedApps.length)
                            checkable: true
                            checked: currentTabIndex === 0
                            onClicked: currentTabIndex = 0
                        }

                        Controls.ToolButton {
                            Layout.fillWidth: true
                            text: i18n("All Applications (%1)", allApps.length)
                            checkable: true
                            checked: currentTabIndex === 1
                            onClicked: currentTabIndex = 1
                        }
                    }

                    Controls.ToolButton {
                        action: refreshAction
                    }
                }
            }
            // This container will hold the search bar and list view for each tab
            StackLayout {
                anchors.fill: parent
                currentIndex: currentTabIndex

                // Tab 1: Exported Applications
                Item {
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: Kirigami.Units.largeSpacing

                        // Search bar for exported apps
                        Kirigami.SearchField {
                            id: exportedSearchField
                            Layout.fillWidth: true
                            Layout.preferredHeight: visible ? implicitHeight : 0
                            visible: filterApps(exportedApps, exportedSearchText).length > 0 || exportedSearchText.length > 0
                            placeholderText: i18n("Search exported applications...")
                            text: exportedSearchText
                            onTextChanged: exportedSearchText = text
                        }

                        // Content area
                        Loader {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.topMargin: exportedSearchField.visible ? Kirigami.Units.largeSpacing : 0

                            sourceComponent: {
                                if (filterApps(exportedApps, exportedSearchText).length === 0) {
                                    return exportedPlaceholderComponent;
                                } else {
                                    return exportedListViewComponent;
                                }
                            }
                        }
                    }
                }

                // Tab 2: Available Applications
                Item {
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: Kirigami.Units.largeSpacing

                        // Search bar for available apps
                        Kirigami.SearchField {
                            id: availableSearchField
                            Layout.fillWidth: true
                            Layout.preferredHeight: visible ? implicitHeight : 0
                            visible: filterApps(allApps, availableSearchText).length > 0 || availableSearchText.length > 0
                            placeholderText: i18n("Search available applications...")
                            text: availableSearchText
                            onTextChanged: availableSearchText = text
                        }

                        // Content area
                        Loader {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.topMargin: availableSearchField.visible ? Kirigami.Units.largeSpacing : 0

                            sourceComponent: {
                                if (filterApps(allApps, availableSearchText).length === 0) {
                                    return availablePlaceholderComponent;
                                } else {
                                    return availableListViewComponent;
                                }
                            }
                        }
                    }
                }
            }

            // Component definitions within the page scope
            Component {
                id: exportedPlaceholderComponent
                Kirigami.PlaceholderMessage {
                    text: exportedSearchText ? i18n("No exported applications found matching '%1'", exportedSearchText) : i18n("No exported applications found")
                }
            }

            Component {
                id: availablePlaceholderComponent
                Kirigami.PlaceholderMessage {
                    text: availableSearchText ? i18n("No applications found matching '%1'", availableSearchText) : i18n("No applications found in container")
                    explanation: !availableSearchText ? i18n("This container might not have desktop applications installed or they might not be detectable.") : ""
                }
            }

            Component {
                id: exportedListViewComponent
                Controls.ScrollView {
                    clip: true

                    ListView {
                        id: exportedListView
                        model: filterApps(exportedApps, exportedSearchText)
                        spacing: Kirigami.Units.smallSpacing

                        delegate: Kirigami.AbstractCard {
                            Layout.fillWidth: true

                            contentItem: RowLayout {
                                spacing: Kirigami.Units.largeSpacing

                                Controls.CheckBox {
                                    checked: selectedApps[modelData.basename] || false
                                    onCheckedChanged: selectedApps[modelData.basename] = checked
                                    visible: Object.keys(selectedApps).length > 0 || checked
                                }

                                Kirigami.Icon {
                                    readonly property string resolvedIconSource: iconSourceForApp(modelData)
                                    source: resolvedIconSource.length > 0 ? resolvedIconSource : iconNameForApp(modelData, "application-x-executable")
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

            Component {
                id: availableListViewComponent
                Controls.ScrollView {
                    clip: true

                    ListView {
                        id: availableListView
                        model: filterApps(allApps, availableSearchText)
                        spacing: Kirigami.Units.smallSpacing

                        delegate: Kirigami.AbstractCard {
                            Layout.fillWidth: true

                            contentItem: RowLayout {
                                spacing: Kirigami.Units.largeSpacing

                                Controls.CheckBox {
                                    checked: selectedApps[modelData.basename] || false
                                    onCheckedChanged: selectedApps[modelData.basename] = checked
                                    visible: Object.keys(selectedApps).length > 0 || checked
                                }

                                Kirigami.Icon {
                                    readonly property string resolvedIconSource: iconSourceForApp(modelData)
                                    source: resolvedIconSource.length > 0 ? resolvedIconSource : iconNameForApp(modelData, "package-x-generic")
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
                                    text: applicationsWindow.isAppExported(modelData.basename) ? i18n("Unexport") : i18n("Export")
                                    icon.name: applicationsWindow.isAppExported(modelData.basename) ? "list-remove" : "list-add"
                                    enabled: !operationInProgress
                                    onClicked: {
                                        var wasExported = applicationsWindow.isAppExported(modelData.basename);
                                        operationInProgress = true;
                                        lastOperation = modelData.name || modelData.basename;
                                        var success = wasExported ? distroBoxManager.unexportApp(modelData.basename, containerName) : distroBoxManager.exportApp(modelData.basename, containerName);
                                        if (success) {
                                            if (!wasExported) {
                                                // Switch to exported tab after exporting
                                                currentTabIndex = 0;
                                            }
                                            refreshAppLists();
                                            operationInProgress = false;
                                        } else {
                                            showPassiveNotification(wasExported ? i18n("Failed to unexport application") : i18n("Failed to export application"));
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

            footer: Controls.ToolBar {
                visible: Object.keys(selectedApps).length > 0
                RowLayout {
                    width: parent.width
                    Controls.Label {
                        text: i18n("%1 selected", Object.keys(selectedApps).length)
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    Controls.Button {
                        text: currentTabIndex === 0 ? i18n("Unexport Selected") : i18n("Export Selected")
                        icon.name: currentTabIndex === 0 ? "list-remove" : "list-add"
                        enabled: !operationInProgress
                        onClicked: {
                            operationInProgress = true;
                            var appNames = Object.keys(selectedApps).filter(function (key) {
                                return selectedApps[key];
                            });
                            for (var i = 0; i < appNames.length; i++) {
                                if (currentTabIndex === 0) {
                                    distroBoxManager.unexportApp(appNames[i], containerName);
                                } else {
                                    distroBoxManager.exportApp(appNames[i], containerName);
                                }
                            }
                            lastOperation = i18n("%1 applications", appNames.length);
                            selectedApps = {};

                            // Switch to exported tab if we exported apps
                            if (currentTabIndex === 1) {
                                currentTabIndex = 0;
                            }
                            refreshAppLists();
                            operationInProgress = false;
                        }
                    }
                    Controls.Button {
                        text: i18n("Clear Selection")
                        icon.name: "edit-clear"
                        onClicked: selectedApps = {}
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
