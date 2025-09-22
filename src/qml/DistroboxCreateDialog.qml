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
    property var allImages: []    // store all available images here

    // Timer for container creation
    Timer {
        id: createTimer
        interval: 0
        onTriggered: {
            var imageName = imageField.fullImageName || imageField.currentText;

            var success = distroBoxManager.createContainer(nameField.text, imageName, argsField.text);

            createDialog.isCreating = false;
            createDialog.standardButtons = Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel;

            if (success) {
                // Refresh the container list after creation
                var result = distroBoxManager.listContainers();
                mainPage.containersList = JSON.parse(result);
                nameField.text = "";
                imageSearch.text = "";
                imageField.currentIndex = 0;
                argsField.text = "";
                createDialog.close();
            } else {
                errorDialog.text = i18n("Failed to create container. Please check your input and try again.");
                errorDialog.open();
            }
        }
    }

    onAccepted: {
        var imageName = imageField.fullImageName || imageField.currentText;

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
        imageSearch.text = ""; // reset search on cancel
    }

    ColumnLayout {
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

            Controls.TextField {
                id: imageSearch
                Kirigami.FormData.label: i18n("Search")
                placeholderText: i18n("Search images…")
                Layout.fillWidth: true
                rightPadding: clearSearch.width + Kirigami.Units.smallSpacing

                onTextChanged: {
                    if (createDialog.allImages.length === 0) return;
                    if (text.length === 0) {
                        imageField.model = createDialog.allImages;
                    } else {
                        var filtered = [];
                        for (var i = 0; i < createDialog.allImages.length; i++) {
                            if (createDialog.allImages[i].display.toLowerCase().indexOf(text.toLowerCase()) !== -1) {
                                filtered.push(createDialog.allImages[i]);
                            }
                        }
                        imageField.model = filtered;
                    }

                    if (imageField.model.length > 0) {
                        imageField.currentIndex = 0;
                        imageField.fullImageName = imageField.model[0].full;
                    } else {
                        imageField.currentIndex = -1;
                        imageField.fullImageName = "";
                    }
                }

                // Small clear button inside the search field
                Controls.ToolButton {
                    id: clearSearch
                    visible: imageSearch.text.length > 0
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: Kirigami.Units.smallSpacing
                    icon.name: "edit-clear"
                    onClicked: {
                        imageSearch.text = "";
                    }
                }
            }

            Controls.ComboBox {
                id: imageField
                Kirigami.FormData.label: i18n("Image")
                model: []
                editable: false
                Layout.fillWidth: true

                // Property to store the full image name
                property string fullImageName: ""

                textRole: "display"

                onCurrentIndexChanged: {
                    if (currentIndex >= 0 && model.length > 0) {
                        fullImageName = model[currentIndex].full;
                        console.log("Selected image:", model[currentIndex].display, "Full name:", fullImageName);
                    }
                }

                Component.onCompleted: {
                    // Populate the ComboBox with available images
                    var images = JSON.parse(distroBoxManager.listAvailableImages());
                    createDialog.allImages = images;
                    model = images;
                    if (model.length > 0) {
                        currentIndex = 0;
                        fullImageName = model[0].full;
                        console.log("Initial image:", model[0].display, "Full name:", fullImageName);
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
                text: "distrobox create --name " + (nameField.text || "…") + " --image " + (imageField.fullImageName || imageField.currentText || "…") + (argsField.text ? " " + argsField.text : "") + " --yes"
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
}
