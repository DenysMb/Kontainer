import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls

import org.kde.kirigami as Kirigami

Kirigami.Dialog {
    id: shortcutDialog
        
    padding: Kirigami.Units.largeSpacing
    implicitWidth: Math.min(root.width - Kirigami.Units.largeSpacing * 4, Kirigami.Units.gridUnit * 20)

    title: "Create Distrobox Shortcuts"
    standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
    
    property string selectedContainer: ""
    property var containersList: []
    
    onAccepted: {
        if (allCheckbox.checked) {
            distroBoxManager.generateEntry()
        } else if (selectedContainer) {
            distroBoxManager.generateEntry(selectedContainer)
        }
    }
    
    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        Controls.CheckBox {
            id: allCheckbox
            text: "Create shortcuts for all containers"
            checked: false
            onCheckedChanged: if (checked) containerCombo.currentIndex = -1
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        Controls.Label {
            text: "Alternatively, select a specific container:"
            enabled: !allCheckbox.checked
        }
        
        Controls.ComboBox {
            id: containerCombo
            model: shortcutDialog.containersList
            textRole: "name"
            enabled: !allCheckbox.checked
            Layout.fillWidth: true
            onCurrentIndexChanged: {
                if (currentIndex >= 0) {
                    shortcutDialog.selectedContainer = model[currentIndex].name
                } else {
                    shortcutDialog.selectedContainer = ""
                }
            }
        }
    }
}
