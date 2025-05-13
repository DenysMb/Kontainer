import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.kirigami.templates.private as KT

Kirigami.Dialog {
    id: createDialog
    title: "Create New Container"
    padding: Kirigami.Units.largeSpacing
    standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
    
    width: Math.min(root.width - Kirigami.Units.largeSpacing * 4, Kirigami.Units.gridUnit * 30)
    
    property bool isCreating: false
    property var errorDialog
    
    // Timer for container creation
    Timer {
        id: createTimer
        interval: 0
        onTriggered: {
            var imageName = imageField.fullImageName || imageField.currentText;
            
            var success = distroBoxManager.createContainer(nameField.text, imageName, argsField.text)
            
            createDialog.isCreating = false
            createDialog.standardButtons = Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
            
            if (success) {
                // Refresh the container list after creation
                var result = distroBoxManager.listContainers()
                mainPage.containersList = JSON.parse(result)
                nameField.text = ""
                imageField.currentIndex = 0
                argsField.text = ""
                createDialog.close()
            } else {
                errorDialog.text = "Failed to create container. Please check your inputs and try again."
                errorDialog.open()
            }
        }
    }
    
    onAccepted: {
        var imageName = imageField.fullImageName || imageField.currentText;
        
        if (nameField.text && imageName) {
            console.log("Creating container:", nameField.text, imageName, argsField.text)
            // Show busy indicator
            isCreating = true
            standardButtons = Kirigami.Dialog.NoButton
            
            // Use a timer to allow the UI to update before starting the creation process
            createTimer.start()
        } else {
            errorDialog.text = "Name and Image fields are required."
            errorDialog.open()
        }
    }
    
    onRejected: {
        createDialog.close()
    }
    
    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing
        
        Kirigami.FormLayout {
            Layout.fillWidth: true
            enabled: !createDialog.isCreating
            wideMode: false
            
            Controls.TextField {
                id: nameField
                Kirigami.FormData.label: "Name:"
                placeholderText: "Fedora"
                Layout.fillWidth: true
            }
            
            Controls.ComboBox {
                id: imageField
                Kirigami.FormData.label: "Image:"
                model: []
                editable: false
                Layout.fillWidth: true
                
                // Property to store the full image name
                property string fullImageName: ""
                
                // Use textRole to display the simplified name
                textRole: "display"
                
                // Update the full image name when selection changes
                onCurrentIndexChanged: {
                    if (currentIndex >= 0 && model.length > 0) {
                        fullImageName = model[currentIndex].full
                        console.log("Selected image:", model[currentIndex].display, "Full name:", fullImageName)
                    }
                }
                
                Component.onCompleted: {
                    // Populate the ComboBox with available images
                    var images = JSON.parse(distroBoxManager.listAvailableImages())
                    model = images
                    if (model.length > 0) {
                        currentIndex = 0
                        // Initialize fullImageName with the first item
                        fullImageName = model[0].full
                        console.log("Initial image:", model[0].display, "Full name:", fullImageName)
                    }
                }
            }
            
            Controls.TextField {
                id: argsField
                Kirigami.FormData.label: "Arguments:"
                placeholderText: "--home=/path/to/home (optional)"
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
                text: "Command preview:"
                font.bold: true
            }
            
            Controls.Label {
                Layout.fillWidth: true
                text: "distrobox create --name " + (nameField.text || "...") + 
                      " --image " + (imageField.fullImageName || imageField.currentText || "...") + 
                      (argsField.text ? " " + argsField.text : "")
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
                    text: "Creating container..."
                }
            }
        }
    }
}
