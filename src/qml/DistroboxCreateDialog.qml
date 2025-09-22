/*
    SPDX-License-Identifier: GPL-3.0-or-later
    SPDX-FileCopyrightText: 2025 Denys Madureira <denysmb@zoho.com>
    SPDX-FileCopyrightText: 2025 Thomas Duckworth <tduck@filotimoproject.org>
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

    width: Math.min(root.width - Kirigami.Units.largeSpacing * 4, Kirigami.Units.gridUnit * 30)

    property bool isCreating: false
    property var errorDialog
    property bool selectingImage: false
    property var availableImages: []
    property var filteredImages: []
    property string selectedImageFull: ""
    property string selectedImageDisplay: ""
    property string imageSearchQuery: ""

    function updateFilteredImages(query) {
        imageSearchQuery = query || "";

        if (!availableImages || availableImages.length === 0) {
            filteredImages = [];
            selectedImageFull = "";
            selectedImageDisplay = "";
        } else {
            var trimmed = imageSearchQuery.trim().toLowerCase();
            if (trimmed.length === 0) {
                filteredImages = availableImages.slice();
            } else {
                filteredImages = availableImages.filter(function(image) {
                    return image.display.toLowerCase().includes(trimmed)
                        || image.full.toLowerCase().includes(trimmed);
                });
            }

            if (filteredImages.length > 0) {
                var match = filteredImages.find(function(image) {
                    return image.full === selectedImageFull;
                });

                if (match) {
                    selectedImageDisplay = match.display;
                } else {
                    selectedImageFull = filteredImages[0].full;
                    selectedImageDisplay = filteredImages[0].display;
                }
            } else {
                selectedImageFull = "";
                selectedImageDisplay = "";
            }
        }

        if (typeof imageListView !== "undefined" && imageListView) {
            var targetIndex = filteredImages.findIndex(function(image) {
                return image.full === selectedImageFull;
            });
            imageListView.currentIndex = targetIndex;
        }
    }

    // Timer for container creation
    Timer {
        id: createTimer
        interval: 0
        onTriggered: {
            var imageName = selectedImageFull || selectedImageDisplay;

            var success = distroBoxManager.createContainer(nameField.text, imageName, argsField.text);

            createDialog.isCreating = false;
            createDialog.standardButtons = Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel;

            if (success) {
                // Refresh the container list after creation
                var result = distroBoxManager.listContainers();
                mainPage.containersList = JSON.parse(result);
                nameField.text = "";
                imageSearchField.text = "";
                updateFilteredImages("");
                argsField.text = "";
                createDialog.selectingImage = false;
                createDialog.close();
            } else {
                errorDialog.text = i18n("Failed to create container. Please check your input and try again.");
                errorDialog.open();
            }
        }
    }

    onAccepted: {
        var imageName = selectedImageFull || selectedImageDisplay;

        if (nameField.text && imageName) {
            console.log("Creating container:", nameField.text, imageName, argsField.text);
            selectingImage = false;
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
        createDialog.selectingImage = false;
    }

    Component.onCompleted: {
        var images = JSON.parse(distroBoxManager.listAvailableImages());
        availableImages = images;
        updateFilteredImages(imageSearchField ? imageSearchField.text : "");
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        ColumnLayout {
            id: formPage
            visible: !createDialog.selectingImage
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing

            Kirigami.FormLayout {
                Layout.fillWidth: true
                enabled: !createDialog.isCreating

                Controls.TextField {
                    id: nameField
                    Kirigami.FormData.label: i18n("Name")
                    placeholderText: i18n("Fedora")
                    Layout.fillWidth: true
                }

                ColumnLayout {
                    Kirigami.FormData.label: i18n("Image")
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing / 2

                    Controls.Button {
                        id: imageSelectButton
                        Layout.fillWidth: true
                        icon.name: "view-list-icons"
                        text: createDialog.selectedImageDisplay || i18n("Select container image…")
                        enabled: !createDialog.isCreating
                        onClicked: {
                            createDialog.selectingImage = true;
                            if (imageSearchField) {
                                imageSearchField.text = createDialog.imageSearchQuery;
                                imageSearchField.forceActiveFocus();
                            }
                            updateFilteredImages(imageSearchField ? imageSearchField.text : createDialog.imageSearchQuery);
                        }
                    }

                    Controls.Label {
                        Layout.fillWidth: true
                        visible: createDialog.selectedImageFull.length > 0
                                 && createDialog.selectedImageFull !== createDialog.selectedImageDisplay
                        text: createDialog.selectedImageFull
                        wrapMode: Text.Wrap
                        color: Kirigami.Theme.disabledTextColor
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
                    text: "distrobox create --name " + (nameField.text || "…") + " --image " + (selectedImageFull || selectedImageDisplay || "…") + (argsField.text ? " " + argsField.text : "") + " --yes"
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

        ColumnLayout {
            id: imageSelectionLayout
            visible: createDialog.selectingImage
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Kirigami.SearchField {
                id: imageSearchField
                Layout.fillWidth: true
                enabled: !createDialog.isCreating
                placeholderText: i18n("Search images…")
                onTextChanged: updateFilteredImages(text)
            }

            ListView {
                id: imageListView
                Layout.fillWidth: true
                Layout.minimumHeight: Kirigami.Units.gridUnit * 8
                Layout.preferredHeight: Math.min(contentHeight, Kirigami.Units.gridUnit * 14)
                clip: true
                spacing: Kirigami.Units.smallSpacing
                enabled: !createDialog.isCreating
                interactive: createDialog.filteredImages.length > 0
                model: createDialog.filteredImages

                delegate: Controls.ItemDelegate {
                    required property var modelData
                    required property int index

                    width: ListView.view.width
                    checkable: true
                    checked: createDialog.selectedImageFull === modelData.full
                    onClicked: {
                        createDialog.selectedImageFull = modelData.full;
                        createDialog.selectedImageDisplay = modelData.display;
                        imageListView.currentIndex = index;
                        createDialog.selectingImage = false;
                        if (imageSearchField && imageSearchField.text.length > 0) {
                            Qt.callLater(function() {
                                imageSearchField.text = "";
                            });
                        } else {
                            Qt.callLater(function() {
                                updateFilteredImages("");
                            });
                        }
                    }

                    contentItem: ColumnLayout {
                        spacing: Kirigami.Units.smallSpacing / 2

                        Controls.Label {
                            Layout.fillWidth: true
                            text: modelData.display
                            wrapMode: Text.Wrap
                            font.bold: true
                        }

                        Controls.Label {
                            Layout.fillWidth: true
                            text: modelData.full
                            wrapMode: Text.Wrap
                            color: Kirigami.Theme.disabledTextColor
                            visible: modelData.full !== modelData.display
                        }
                    }
                }
            }

            Kirigami.PlaceholderMessage {
                Layout.fillWidth: true
                visible: createDialog.filteredImages.length === 0
                text: i18n("No images match your search")
            }
        }
    }
}
