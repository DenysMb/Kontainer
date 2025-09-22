/*
 *   SPDX-License-Identifier: GPL-3.0-or-later
 *   SPDX-FileCopyrightText: 2025 Denys Madureira <denysmb@zoho.com>
 *   SPDX-FileCopyrightText: 2025 Thomas Duckworth <tduck@filotimoproject.org>
 */

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls

import org.kde.kirigami as Kirigami

Kirigami.Dialog {
    id: createDialog
    title: i18n("Create new container")
    padding: Kirigami.Units.largeSpacing
    standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel

    width: Math.min(root.width - Kirigami.Units.largeSpacing * 4, Kirigami.Units.gridUnit * 35)
    height: Kirigami.Units.gridUnit * 25

    property bool isCreating: false
    property var errorDialog
    property var allImages: []
    property var filteredImages: []
    property string selectedImageFullName: ""
    property string selectedImageDisplay: ""

    // Timer for container creation
    Timer {
        id: createTimer
        interval: 0
        onTriggered: {
            var imageName = selectedImageFullName || selectedImageDisplay;

            var success = distroBoxManager.createContainer(nameField.text, imageName, argsField.text);

            createDialog.isCreating = false;
            createDialog.standardButtons = Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel;

            if (success) {
                // Refresh the container list after creation
                var result = distroBoxManager.listContainers();
                mainPage.containersList = JSON.parse(result);
                nameField.text = "";
                selectedImageFullName = "";
                selectedImageDisplay = "";
                argsField.text = "";
                searchField.text = "";
                createDialog.close();
            } else {
                errorDialog.text = i18n("Failed to create container. Please check your input and try again.");
                errorDialog.open();
            }
        }
    }

    onAccepted: {
        var imageName = selectedImageFullName || selectedImageDisplay;

        if (nameField.text && imageName) {
            console.log("Creating container:", nameField.text, imageName, argsField.text);
            // Show busy indicator
            isCreating = true;
            standardButtons = Kirigami.Dialog.NoButton;

            // Use a timer to allow the UI to update before starting the creation process
            createTimer.start();
        } else {
            errorDialog.text = i18n("Name and Image fields are required");
            errorDialog.open();
        }
    }

    onRejected: {
        createDialog.close();
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing
        anchors.fill: parent

        Kirigami.FormLayout {
            Layout.fillWidth: true
            enabled: !createDialog.isCreating

            Controls.TextField {
                id: nameField
                Kirigami.FormData.label: i18n("Name")
                placeholderText: i18n("Fedora")
                Layout.fillWidth: true
            }

            // Image selection with search and list
            ColumnLayout {
                Kirigami.FormData.label: i18n("Image")
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                // Search bar
                Controls.TextField {
                    id: searchField
                    Layout.fillWidth: true
                    placeholderText: i18n("Search images...")
                    onTextChanged: filterImages()

                    Controls.ToolButton {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.rightMargin: Kirigami.Units.smallSpacing
                        icon.name: "edit-clear"
                        visible: searchField.text.length > 0
                        onClicked: searchField.text = ""
                    }
                }

                // Selected image display
                Controls.Label {
                    visible: selectedImageDisplay.length > 0
                    text: i18n("Selected: %1", selectedImageDisplay)
                    font.italic: true
                    opacity: 0.8
                    Layout.fillWidth: true
                }

                // Image list view - full width with proper border
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 8
                    border.color: Kirigami.Theme.separatorColor
                    border.width: 1
                    radius: 4
                    color: Kirigami.Theme.backgroundColor

                    ListView {
                        id: imageListView
                        anchors.fill: parent
                        anchors.margins: 1
                        model: createDialog.filteredImages
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        currentIndex: -1

                        delegate: Rectangle {
                            width: imageListView.width
                            height: Kirigami.Units.gridUnit * 2
                            color: ListView.isCurrentItem ? Kirigami.Theme.highlightColor :
                            mouseArea.containsMouse ? Kirigami.Theme.alternateBackgroundColor :
                            "transparent"

                            Controls.Label {
                                anchors.fill: parent
                                anchors.leftMargin: Kirigami.Units.largeSpacing
                                anchors.rightMargin: Kirigami.Units.largeSpacing
                                text: modelData.display
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }

                            MouseArea {
                                id: mouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    imageListView.currentIndex = index
                                    createDialog.selectedImageFullName = modelData.full
                                    createDialog.selectedImageDisplay = modelData.display
                                }
                            }
                        }

                        highlight: Rectangle {
                            color: Kirigami.Theme.highlightColor
                        }

                        Controls.Label {
                            anchors.centerIn: parent
                            text: searchField.text.length > 0 ? i18n("No images found") : i18n("No images available")
                            visible: imageListView.count === 0
                            opacity: 0.5
                        }
                    }
                }
            }

            Controls.TextField {
                id: argsField
                Kirigami.FormData.label: i18n("Arguments")
                placeholderText: i18n("--home=/path/to/home (optional)")
                Layout.fillWidth: true
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Controls.Label {
                text: i18n("Command preview")
                font.bold: true
            }

            Controls.Label {
                Layout.fillWidth: true
                text: "distrobox create --name " + (nameField.text || "…") + " --image " + (selectedImageFullName || selectedImageDisplay || "…") + (argsField.text ? " " + argsField.text : "") + " --yes"
                wrapMode: Text.Wrap
                font.family: "monospace"
                font.italic: true
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.7
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: busyRow.height
            visible: createDialog.isCreating

            RowLayout {
                id: busyRow
                anchors.centerIn: parent
                spacing: Kirigami.Units.largeSpacing

                Controls.BusyIndicator {
                    running: createDialog.isCreating
                }

                Controls.Label {
                    text: i18n("Creating container…")
                }
            }
        }
    }

    function filterImages() {
        var searchText = searchField.text.toLowerCase();
        if (searchText === "") {
            createDialog.filteredImages = createDialog.allImages;
        } else {
            var filtered = [];
            for (var i = 0; i < createDialog.allImages.length; i++) {
                var image = createDialog.allImages[i];
                if (image.display.toLowerCase().includes(searchText) ||
                    image.full.toLowerCase().includes(searchText)) {
                    filtered.push(image);
                    }
            }
            createDialog.filteredImages = filtered;
        }

        // Reset selection when filtering
        imageListView.currentIndex = -1;
        createDialog.selectedImageFullName = "";
        createDialog.selectedImageDisplay = "";
    }

    Component.onCompleted: {
        refreshImages();
    }

    function refreshImages() {
        searchField.text = ""
        var images = JSON.parse(distroBoxManager.listAvailableImages());
        createDialog.allImages = images;
        createDialog.filteredImages = images;
        imageListView.currentIndex = -1;
        createDialog.selectedImageFullName = "";
        createDialog.selectedImageDisplay = "";
    }
}
