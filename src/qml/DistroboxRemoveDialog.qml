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
    id: removeDialog
    title: i18n("Remove container")
    padding: Kirigami.Units.largeSpacing
    standardButtons: Kirigami.Dialog.Yes | Kirigami.Dialog.No

    property string containerName: ""
    
    onAccepted: {
        if (containerName) {
            var success = distroBoxManager.removeContainer(containerName)
            if (success) {
                // Refresh the container list
                var result = distroBoxManager.listContainers()
                mainPage.containersList = JSON.parse(result)
            } else {
                errorDialog.text = i18n("Failed to remove container")
                errorDialog.open()
            }
        }
    }
    
    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing
        
        Kirigami.Heading {
            level: 4
            text: i18n("Are you sure you want to remove %1?", removeDialog.containerName)
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }
        
        Controls.Label {
            text: i18n("This action cannot be undone.")
            Layout.fillWidth: true
            wrapMode: Text.Wrap
        }
    }
}
