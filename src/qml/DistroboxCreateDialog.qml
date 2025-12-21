/*
 *   SPDX-License-Identifier: GPL-3.0-or-later
 *   SPDX-FileCopyrightText: 2025 Denys Madureira <denysmb@zoho.com>
 *   SPDX-FileCopyrightText: 2025 Thomas Duckworth <tduck@filotimoproject.org>
 */

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami

Kirigami.Dialog {
    id: createDialog
    title: selectingImage ? i18n("Select image") : i18n("Create new container")
    padding: Kirigami.Units.largeSpacing
    standardButtons: Kirigami.Dialog.NoButton

    width: Math.min(root.width - Kirigami.Units.largeSpacing * 4, Kirigami.Units.gridUnit * 30)

    property bool isCreating: false
    property var errorDialog
    required property var mainPage
    property bool selectingImage: false
    property var availableImages: []
    property var filteredImages: []
    property string selectedImageFull: ""
    property string selectedImageDisplay: ""
    property string imageSearchQuery: ""
    property string pendingContainerName: ""

    FileDialog {
        id: iniFileDialog
        title: i18n("Choose .ini file")
        fileMode: FileDialog.OpenFile
        nameFilters: [i18n("INI files (*.ini)")]
        onAccepted: {
            distroBoxManager.assembleContainer(selectedFile);
        }
    }

    customFooterActions: [
        Kirigami.Action {
            icon.name: createDialog.isCreating ? "view-refresh" : "dialog-ok"
            text: createDialog.isCreating ? i18n("Creating…") : i18n("Create")
            visible: !createDialog.selectingImage
            enabled: !createDialog.isCreating
            onTriggered: createDialog.startCreation()
        },
        Kirigami.Action {
            icon.name: "document-open"
            text: i18n("Assemble")
            visible: !createDialog.selectingImage
            enabled: !createDialog.isCreating
            onTriggered: {
                if (creationMonitorTimer.running) {
                    creationMonitorTimer.stop();
                }
                iniFileDialog.open();
                createDialog.close();
            }
        },
        Kirigami.Action {
            icon.name: "dialog-cancel"
            text: i18n("Cancel")
            visible: !createDialog.selectingImage
            enabled: !createDialog.isCreating
            onTriggered: {
                if (creationMonitorTimer.running) {
                    creationMonitorTimer.stop();
                }
                createDialog.pendingContainerName = "";
                createDialog.isCreating = false;
                createDialog.selectingImage = false;
                createDialog.close();
            }
        }
    ]

    function finalizeCreation() {
        if (creationMonitorTimer.running) {
            creationMonitorTimer.stop();
        }

        isCreating = false;
        pendingContainerName = "";
        selectingImage = false;

        nameField.text = "";
        argsField.text = "";
        imageSearchQuery = "";
        initCheckbox.checked = false;
        nvidiaCheckbox.checked = false;

        if (availableImages && availableImages.length > 0) {
            selectedImageFull = availableImages[0].full;
            selectedImageDisplay = availableImages[0].display;
        } else {
            selectedImageFull = "";
            selectedImageDisplay = "";
        }

        if (imageSearchField) {
            imageSearchField.text = "";
        }

        updateFilteredImages("");
        createDialog.close();
    }

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
                filteredImages = availableImages.filter(function (image) {
                    return image.display.toLowerCase().includes(trimmed) || image.full.toLowerCase().includes(trimmed);
                });
            }

            if (filteredImages.length > 0) {
                var match = filteredImages.find(function (image) {
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
            var targetIndex = filteredImages.findIndex(function (image) {
                return image.full === selectedImageFull;
            });
            imageListView.currentIndex = targetIndex;
        }
    }

    function getFullArgs() {
        var fullArgs = argsField.text.trim();
        if (initCheckbox.checked) {
            fullArgs += (fullArgs.length > 0 ? " " : "") + "--init --additional-packages \"systemd\"";
        }
        if (nvidiaCheckbox.checked) {
            fullArgs += (fullArgs.length > 0 ? " " : "") + "--nvidia";
        }
        return fullArgs;
    }

    function startCreation() {
        if (isCreating) {
            return;
        }

        var imageName = selectedImageFull || selectedImageDisplay;
        var safeName = nameField.text.trim().replace(/\s+/g, "-"); // sanitize whitespace

        if (safeName && imageName) {
            console.log("Creating container:", safeName, imageName, getFullArgs());
            selectingImage = false;
            isCreating = true;

            nameField.text = safeName; // reflect sanitized name in UI
            createTimer.start();
        } else {
            errorDialog.text = i18n("Name and Image fields are required");
            errorDialog.open();
        }
    }

    Timer {
        id: createTimer
        interval: 0
        onTriggered: {
            var imageName = selectedImageFull || selectedImageDisplay;
            var safeName = nameField.text.trim().replace(/\s+/g, "-");

            var success = distroBoxManager.createContainer(safeName, imageName, getFullArgs());

            if (success) {
                createDialog.pendingContainerName = safeName;
                var result = distroBoxManager.listContainers();
                var containers = [];
                try {
                    containers = JSON.parse(result);
                } catch (e) {
                    containers = [];
                }
                if (mainPage) {
                    mainPage.containersList = containers;
                }
                createDialog.selectingImage = false;

                var containerFound = false;
                if (createDialog.pendingContainerName && containers) {
                    for (var i = 0; i < containers.length; ++i) {
                        if (containers[i].name === createDialog.pendingContainerName) {
                            containerFound = true;
                            break;
                        }
                    }
                }

                if (containerFound) {
                    createDialog.finalizeCreation();
                } else {
                    createDialog.isCreating = true;
                    if (creationMonitorTimer.running) {
                        creationMonitorTimer.stop();
                    }
                    creationMonitorTimer.start();
                }
            } else {
                createDialog.isCreating = false;
                createDialog.pendingContainerName = "";
                if (creationMonitorTimer.running) {
                    creationMonitorTimer.stop();
                }
                errorDialog.text = i18n("Failed to create container. Please check your input and try again.");
                errorDialog.open();
            }
        }
    }

    Timer {
        id: creationMonitorTimer
        interval: 1000
        repeat: true
        onTriggered: {
            if (!createDialog.pendingContainerName || createDialog.pendingContainerName.trim() === "") {
                stop();
                createDialog.isCreating = false;
                return;
            }

            var result = distroBoxManager.listContainers();
            var containers = [];
            try {
                containers = JSON.parse(result);
            } catch (e) {
                containers = [];
            }
            if (mainPage) {
                mainPage.containersList = containers;
            }

            var containerFound = false;
            for (var i = 0; i < containers.length; ++i) {
                if (containers[i].name === createDialog.pendingContainerName) {
                    containerFound = true;
                    break;
                }
            }

            if (containerFound) {
                stop();
                createDialog.finalizeCreation();
            }
        }
    }

    onRejected: {
        if (creationMonitorTimer.running) {
            creationMonitorTimer.stop();
        }
        pendingContainerName = "";
        isCreating = false;
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

                    // Real-time whitespace sanitization
                    onTextChanged: {
                        var sanitized = text.replace(/\s+/g, "-");
                        if (sanitized !== text) {
                            text = sanitized;
                            cursorPosition = text.length;
                        }
                    }
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
                        visible: createDialog.selectedImageFull.length > 0 && createDialog.selectedImageFull !== createDialog.selectedImageDisplay
                        text: createDialog.selectedImageFull
                        wrapMode: Text.Wrap
                        color: Kirigami.Theme.disabledTextColor
                    }
                }

                Controls.TextField {
                    id: argsField
                    Kirigami.FormData.label: i18n("Arguments")
                    placeholderText: i18n("--home /path/to/home (optional)")
                    Layout.fillWidth: true
                }

                Controls.CheckBox {
                    id: initCheckbox
                    Kirigami.FormData.label: i18n("Additional Options")
                    text: i18n("Enable systemd init support")
                    checked: false
                    enabled: !createDialog.isCreating
                }

                Controls.CheckBox {
                    id: nvidiaCheckbox
                    text: i18n("Enable NVIDIA GPU support")
                    checked: false
                    enabled: !createDialog.isCreating
                }
            }

            Kirigami.InlineMessage {
                Layout.fillWidth: true
                visible: true
                type: Kirigami.MessageType.Information
                text: i18n("Use Assemble to pick a distrobox.ini manifest. Kontainer will run \"distrobox assemble create --file <manifest>\" to build every container listed there.")
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
                    text: "distrobox create --name " +
                    ((nameField.text && nameField.text.trim().length > 0) ? nameField.text.trim().replace(/\s+/g, "-") : "…") +
                    " --image " +
                    (selectedImageFull || selectedImageDisplay || "…") +
                    (getFullArgs().length > 0 ? " " + getFullArgs() : "") + " --yes"
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
                            Qt.callLater(function () {
                                imageSearchField.text = "";
                            });
                        } else {
                            Qt.callLater(function () {
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
