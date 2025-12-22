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
    property bool advancedOpen: false

    // Indicates whether any advanced option is currently set,
    // so the user doesn't forget hidden changes.
    readonly property bool advancedModified: argsField.text.trim().length > 0 || createDialog.customHomePath.length > 0 || volumesModel.count > 0

    readonly property string advancedOptionsSummary: {
        const parts = [];

        if (argsField.text.trim().length > 0) {
            parts.push(i18nc("Short name of advanced option", "arguments"));
        }

        if (createDialog.customHomePath.length > 0) {
            parts.push(i18nc("Short name of advanced option", "custom home"));
        }

        if (volumesModel.count > 0) {
            parts.push(i18np("%1 volume", "%1 volumes", volumesModel.count));
        }

        return parts.join(i18nc("Separator between enabled advanced options", ", "));
    }

    property var availableImages: []

    property var filteredImages: []
    property string selectedImageFull: ""
    property string selectedImageDisplay: ""
    property bool selectedImageIsCustom: false
    property string imageSearchQuery: ""
    property string pendingContainerName: ""
    property string customHomePath: ""

    ListModel {
        id: volumesModel
    }

    FileDialog {
        id: iniFileDialog
        title: i18n("Choose .ini file")
        fileMode: FileDialog.OpenFile
        nameFilters: [i18n("INI files (*.ini)")]
        onAccepted: {
            distroBoxManager.assembleContainer(selectedFile);
        }
    }

    FolderDialog {
        id: homeDirectoryDialog
        title: i18n("Select custom home directory")
        onAccepted: {
            createDialog.customHomePath = selectedFolder.toString().replace("file://", "");
        }
    }

    FolderDialog {
        id: volumeDirectoryDialog
        title: i18n("Select volume directory")
        onAccepted: {
            var volumePath = selectedFolder.toString().replace("file://", "");
            // Check for duplicates
            for (var i = 0; i < volumesModel.count; i++) {
                if (volumesModel.get(i).path === volumePath) {
                    return; // Already exists, don't add
                }
            }
            volumesModel.append({
                "path": volumePath
            });
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
                createDialog.advancedOpen = false;
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
        createDialog.advancedOpen = false;
        createDialog.customHomePath = "";

        volumesModel.clear();

        if (availableImages && availableImages.length > 0) {
            selectedImageFull = availableImages[0].full;
            selectedImageDisplay = availableImages[0].display;
            selectedImageIsCustom = false;
        } else {
            selectedImageFull = "";
            selectedImageDisplay = "";
            selectedImageIsCustom = false;
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
            if (!selectedImageIsCustom) {
                selectedImageFull = "";
                selectedImageDisplay = "";
            }
        } else {
            var trimmed = imageSearchQuery.trim().toLowerCase();
            if (trimmed.length === 0) {
                filteredImages = availableImages.slice();
            } else {
                filteredImages = availableImages.filter(function (image) {
                    return image.display.toLowerCase().includes(trimmed) || image.full.toLowerCase().includes(trimmed);
                });
                
                // If no matches found and user typed something, add custom image option
                if (filteredImages.length === 0 && imageSearchQuery.trim().length > 0) {
                    filteredImages = [{
                        display: i18n("Use custom image: %1", imageSearchQuery.trim()),
                        full: imageSearchQuery.trim(),
                        isCustom: true
                    }];
                }
            }

            if (filteredImages.length > 0) {
                // Check if current selection exists in filtered results
                var match = filteredImages.find(function (image) {
                    return image.full === selectedImageFull;
                });

                if (match) {
                    selectedImageDisplay = match.display;
                } else if (!selectedImageIsCustom) {
                    // Only change selection if it's not a custom image
                    selectedImageFull = filteredImages[0].full;
                    selectedImageDisplay = filteredImages[0].display;
                }
                // If it's a custom image, keep the current selection even if not in list
            } else {
                if (!selectedImageIsCustom) {
                    selectedImageFull = "";
                    selectedImageDisplay = "";
                }
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
        if (createDialog.customHomePath.length > 0) {
            fullArgs += (fullArgs.length > 0 ? " " : "") + "--home \"" + createDialog.customHomePath + "\"";
        }
        // Add all volumes from the model
        for (var i = 0; i < volumesModel.count; i++) {
            var volumePath = volumesModel.get(i).path;
            fullArgs += (fullArgs.length > 0 ? " " : "") + "--volume \"" + volumePath + "\"";
        }
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
        createDialog.advancedOpen = false;
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
                        visible: createDialog.selectedImageFull.length > 0 && (createDialog.selectedImageFull !== createDialog.selectedImageDisplay || createDialog.selectedImageIsCustom)
                        text: createDialog.selectedImageIsCustom ? i18n("Custom image: %1", createDialog.selectedImageFull) : createDialog.selectedImageFull
                        wrapMode: Text.Wrap
                        color: createDialog.selectedImageIsCustom ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.disabledTextColor
                        font.italic: createDialog.selectedImageIsCustom
                    }
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

                Kirigami.Separator {
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    Layout.bottomMargin: Kirigami.Units.smallSpacing
                }

                Controls.Button {
                    Layout.fillWidth: true
                    icon.name: createDialog.advancedOpen ? "arrow-down" : "arrow-right"
                    text: createDialog.advancedOpen ? i18n("Hide advanced options") : i18n("Show advanced options")
                    enabled: !createDialog.isCreating
                    onClicked: createDialog.advancedOpen = !createDialog.advancedOpen

                    Controls.ToolTip.visible: hovered && createDialog.advancedModified
                    Controls.ToolTip.text: i18n("Some advanced options are set")
                    Controls.ToolTip.delay: Kirigami.Units.toolTipDelay
                }

                Controls.Label {
                    Kirigami.FormData.label: ""
                    Layout.fillWidth: true
                    visible: createDialog.advancedModified || createDialog.advancedOpen
                    wrapMode: Text.Wrap
                    color: createDialog.advancedModified ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.disabledTextColor
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    text: createDialog.advancedModified ? i18n("Using advanced options: %1", createDialog.advancedOptionsSummary) : i18n("No advanced options set")
                }

                // Advanced section content
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: createDialog.advancedOpen
                    spacing: Kirigami.Units.largeSpacing

                    Controls.TextField {
                        id: argsField
                        Kirigami.FormData.label: i18n("Arguments")
                        placeholderText: i18n("Additional arguments (optional)")
                        Layout.fillWidth: true
                    }

                    ColumnLayout {
                        Kirigami.FormData.label: i18n("Custom Home")
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing / 2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing

                            Controls.Button {
                                Layout.fillWidth: true
                                icon.name: "folder-open"
                                text: createDialog.customHomePath.length > 0 ? createDialog.customHomePath : i18n("Use custom home directory")
                                enabled: !createDialog.isCreating
                                onClicked: homeDirectoryDialog.open()
                            }

                            Controls.Button {
                                visible: createDialog.customHomePath.length > 0
                                enabled: !createDialog.isCreating
                                icon.name: "edit-clear"
                                onClicked: createDialog.customHomePath = ""
                                Controls.ToolTip.visible: hovered
                                Controls.ToolTip.text: i18n("Clear custom home directory")
                                Controls.ToolTip.delay: Kirigami.Units.toolTipDelay
                            }
                        }

                        Controls.Label {
                            Layout.fillWidth: true
                            visible: createDialog.customHomePath.length === 0
                            text: i18n("By default, the container will use your home directory")
                            wrapMode: Text.Wrap
                            color: Kirigami.Theme.disabledTextColor
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                        }
                    }

                    ColumnLayout {
                        Kirigami.FormData.label: i18n("Additional Volumes")
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing / 2

                            Repeater {
                                model: volumesModel

                                delegate: Controls.ItemDelegate {
                                    required property string path
                                    required property int index

                                    Layout.fillWidth: true
                                    contentItem: RowLayout {
                                        spacing: Kirigami.Units.smallSpacing

                                        Kirigami.Icon {
                                            source: "folder"
                                            Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                            Layout.preferredHeight: Kirigami.Units.iconSizes.small
                                        }

                                        Controls.Label {
                                            Layout.fillWidth: true
                                            text: path
                                            elide: Text.ElideMiddle
                                        }

                                        Controls.Button {
                                            icon.name: "edit-delete-remove"
                                            flat: true
                                            enabled: !createDialog.isCreating
                                            onClicked: volumesModel.remove(index)
                                            Controls.ToolTip.visible: hovered
                                            Controls.ToolTip.text: i18n("Remove volume")
                                            Controls.ToolTip.delay: Kirigami.Units.toolTipDelay
                                        }
                                    }
                                }
                            }

                            Controls.Button {
                                Layout.fillWidth: true
                                icon.name: "list-add"
                                text: i18n("Add Volume")
                                enabled: !createDialog.isCreating
                                onClicked: volumeDirectoryDialog.open()
                            }

                            Controls.Label {
                                Layout.fillWidth: true
                                visible: volumesModel.count === 0
                                text: i18n("Mount additional directories inside the container")
                                wrapMode: Text.Wrap
                                color: Kirigami.Theme.disabledTextColor
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                            }
                        }
                    }
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
                    text: "distrobox create --name " + ((nameField.text && nameField.text.trim().length > 0) ? nameField.text.trim().replace(/\s+/g, "-") : "…") + " --image " + (selectedImageFull || selectedImageDisplay || "…") + (getFullArgs().length > 0 ? " " + getFullArgs() : "") + " --yes"
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
                        createDialog.selectedImageIsCustom = modelData.isCustom || false;
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

                    contentItem: RowLayout {
                        spacing: Kirigami.Units.smallSpacing

                        Kirigami.Icon {
                            source: modelData.isCustom ? "document-new" : "application-x-container"
                            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                            color: modelData.isCustom ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.textColor
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing / 2

                            Controls.Label {
                                Layout.fillWidth: true
                                text: modelData.display
                                wrapMode: Text.Wrap
                                font.bold: true
                                color: modelData.isCustom ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.textColor
                            }

                            Controls.Label {
                                Layout.fillWidth: true
                                text: modelData.full
                                wrapMode: Text.Wrap
                                color: Kirigami.Theme.disabledTextColor
                                visible: modelData.full !== modelData.display && !modelData.isCustom
                            }
                        }
                    }
                }
            }

            Kirigami.PlaceholderMessage {
                Layout.fillWidth: true
                visible: createDialog.filteredImages.length === 0 && imageSearchField.text.trim().length === 0
                text: i18n("Type to search for images")
            }
        }
    }
}
