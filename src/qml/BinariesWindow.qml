/*
 *   SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Kirigami.ApplicationWindow {
    id: binariesWindow

    width: 600
    height: 400
    minimumWidth: 600
    minimumHeight: 400

    title: i18n("Binaries Management - %1", containerName)

    property string containerName: ""
    property bool loading: true
    property bool operationInProgress: false
    property var exportedBinaries: []
    property var availableBinaries: []
    property string exportedSearchText: ""
    property string availableSearchText: ""
    property int currentTabIndex: 0

    function refreshBinaries() {
        loading = true;
        Qt.callLater(function () {
            exportedBinaries = distroBoxManager.exportedBinaries(containerName) || [];
            availableBinaries = distroBoxManager.availableBinaries(containerName) || [];
            loading = false;
        });
    }

    function refreshBinaryLists() {
        Qt.callLater(function () {
            exportedBinaries = distroBoxManager.exportedBinaries(containerName) || [];
            availableBinaries = distroBoxManager.availableBinaries(containerName) || [];
        });
    }

    function filterBinaries(binaries, searchText) {
        if (!searchText)
            return binaries;
        return binaries.filter(function (bin) {
            return bin.basename && bin.basename.toLowerCase().includes(searchText.toLowerCase()) || bin.path && bin.path.toLowerCase().includes(searchText.toLowerCase());
        });
    }

    function isBinaryExported(path) {
        if (!path || !exportedBinaries || exportedBinaries.length === 0)
            return false;
        return exportedBinaries.some(function (bin) {
            return bin && bin.path === path;
        });
    }

    onContainerNameChanged: {
        if (containerName)
            refreshBinaries();
    }

    Controls.BusyIndicator {
        anchors.centerIn: parent
        running: loading || operationInProgress
        visible: loading || operationInProgress
        width: Kirigami.Units.iconSizes.huge
        height: width
        z: 1000
    }

    Loader {
        id: mainContentLoader
        anchors.fill: parent
        active: !loading
        sourceComponent: mainContentComponent
    }

    Component {
        id: mainContentComponent

        Kirigami.Page {
            id: page

            title: binariesWindow.title

            actions: [
                Kirigami.Action {
                    id: refreshAction
                    text: i18n("Refresh")
                    icon.name: "view-refresh"
                    onTriggered: refreshBinaries()
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
                            text: i18n("Exported Binaries (%1)", exportedBinaries.length)
                            checkable: true
                            checked: currentTabIndex === 0
                            onClicked: currentTabIndex = 0
                        }

                        Controls.ToolButton {
                            Layout.fillWidth: true
                            text: i18n("Available Binaries (%1)", availableBinaries.length)
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

            StackLayout {
                anchors.fill: parent
                currentIndex: currentTabIndex

                // Tab 1: Exported Binaries
                Item {
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: Kirigami.Units.largeSpacing

                        Kirigami.SearchField {
                            id: exportedSearchField
                            Layout.fillWidth: true
                            Layout.preferredHeight: visible ? implicitHeight : 0
                            visible: filterBinaries(exportedBinaries, exportedSearchText).length > 0 || exportedSearchText.length > 0
                            placeholderText: i18n("Search exported binaries...")
                            text: exportedSearchText
                            onTextChanged: exportedSearchText = text
                        }

                        Loader {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.topMargin: exportedSearchField.visible ? Kirigami.Units.largeSpacing : 0

                            sourceComponent: {
                                if (filterBinaries(exportedBinaries, exportedSearchText).length === 0) {
                                    return exportedPlaceholderComponent;
                                } else {
                                    return exportedListViewComponent;
                                }
                            }
                        }
                    }
                }

                // Tab 2: Available Binaries
                Item {
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: Kirigami.Units.largeSpacing

                        Kirigami.SearchField {
                            id: availableSearchField
                            Layout.fillWidth: true
                            Layout.preferredHeight: visible ? implicitHeight : 0
                            visible: filterBinaries(availableBinaries, availableSearchText).length > 0 || availableSearchText.length > 0
                            placeholderText: i18n("Search available binaries...")
                            text: availableSearchText
                            onTextChanged: availableSearchText = text
                        }

                        Loader {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.topMargin: availableSearchField.visible ? Kirigami.Units.largeSpacing : 0

                            sourceComponent: {
                                if (filterBinaries(availableBinaries, availableSearchText).length === 0) {
                                    return availablePlaceholderComponent;
                                } else {
                                    return availableListViewComponent;
                                }
                            }
                        }
                    }
                }
            }

            Component {
                id: exportedPlaceholderComponent
                Kirigami.PlaceholderMessage {
                    text: exportedSearchText ? i18n("No exported binaries found matching '%1'", exportedSearchText) : i18n("No exported binaries found")
                }
            }

            Component {
                id: availablePlaceholderComponent
                Kirigami.PlaceholderMessage {
                    text: availableSearchText ? i18n("No binaries found matching '%1'", availableSearchText) : i18n("No binaries found in container")
                    explanation: !availableSearchText ? i18n("This container might not have binaries in /usr/bin or /usr/local/bin.") : ""
                }
            }

            Component {
                id: exportedListViewComponent
                Controls.ScrollView {
                    clip: true

                    ListView {
                        id: exportedListView
                        model: filterBinaries(exportedBinaries, exportedSearchText)
                        spacing: Kirigami.Units.smallSpacing

                        delegate: Kirigami.AbstractCard {
                            contentItem: RowLayout {
                                spacing: Kirigami.Units.largeSpacing

                                Kirigami.Icon {
                                    source: "application-x-executable"
                                    width: Kirigami.Units.iconSizes.medium
                                    height: width
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    Controls.Label {
                                        text: modelData.basename || "Unknown"
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        font.bold: true
                                    }

                                    Controls.Label {
                                        text: modelData.path || ""
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                                        opacity: 0.7
                                    }
                                }

                                Controls.Button {
                                    text: i18n("Unexport")
                                    icon.name: "list-remove"
                                    enabled: !operationInProgress
                                    onClicked: {
                                        operationInProgress = true;
                                        var success = distroBoxManager.unexportBinary(modelData.path, containerName);
                                        if (success) {
                                            refreshBinaryLists();
                                            operationInProgress = false;
                                        } else {
                                            showPassiveNotification(i18n("Failed to unexport binary"));
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
                        model: filterBinaries(availableBinaries, availableSearchText)
                        spacing: Kirigami.Units.smallSpacing

                        delegate: Kirigami.AbstractCard {
                            contentItem: RowLayout {
                                spacing: Kirigami.Units.largeSpacing

                                Kirigami.Icon {
                                    source: "application-x-executable"
                                    width: Kirigami.Units.iconSizes.medium
                                    height: width
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    Controls.Label {
                                        text: modelData.basename || "Unknown"
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        font.bold: true
                                    }

                                    Controls.Label {
                                        text: modelData.path || ""
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                                        opacity: 0.7
                                    }
                                }

                                Controls.Button {
                                    text: binariesWindow.isBinaryExported(modelData.path) ? i18n("Unexport") : i18n("Export")
                                    icon.name: binariesWindow.isBinaryExported(modelData.path) ? "list-remove" : "list-add"
                                    enabled: !operationInProgress
                                    onClicked: {
                                        var wasExported = binariesWindow.isBinaryExported(modelData.path);
                                        operationInProgress = true;
                                        var success = wasExported ? distroBoxManager.unexportBinary(modelData.path, containerName) : distroBoxManager.exportBinary(modelData.path, containerName);
                                        if (success) {
                                            refreshBinaryLists();
                                            operationInProgress = false;
                                        } else {
                                            showPassiveNotification(wasExported ? i18n("Failed to unexport binary") : i18n("Failed to export binary"));
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
}
