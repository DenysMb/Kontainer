import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls

import org.kde.kirigami as Kirigami

Kirigami.Dialog {
    id: removeDialog
    title: "Remove Container"
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
                errorDialog.text = "Failed to remove container."
                errorDialog.open()
            }
        }
    }
    
    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing
        
        Kirigami.Heading {
            level: 4
            text: "Are you sure you want to remove " + removeDialog.containerName + "?"
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }
        
        Controls.Label {
            text: "This action cannot be undone."
            Layout.fillWidth: true
            wrapMode: Text.Wrap
        }
    }
}
