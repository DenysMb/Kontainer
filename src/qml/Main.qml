import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import QtQuick.Dialogs

import org.kde.kirigami as Kirigami

Kirigami.ApplicationWindow {
    id: root

    width: 600
    height: 500

    title: "Kontainer"
    
    globalDrawer: Kirigami.GlobalDrawer {
        isMenu: true
        actions: [
            Kirigami.Action {
                text: "Create Container…"
                icon.name: "list-add"
                onTriggered: createDialog.open()
            },
            Kirigami.Action {
                text: "Create Distrobox Shortcut…"
                icon.name: "document-new"
                enabled: mainPage.containersList.length > 0
                onTriggered: shortcutDialog.open()
            },
            Kirigami.Action {
                separator: true
            },
            Kirigami.Action {
                text: "Open Distrobox Documentation"
                icon.name: "help-contents"
                onTriggered: Qt.openUrlExternally("https://distrobox.it/#distrobox")
            },
            Kirigami.Action {
                text: "Open Distrobox Useful Tips"
                icon.name: "help-hint"
                onTriggered: Qt.openUrlExternally("https://github.com/89luca89/distrobox/blob/main/docs/useful_tips.md")
            }
        ]
    }

    ErrorDialog {
        id: errorDialog
    }
    
    DistroboxRemoveDialog {
        id: removeDialog
    }
    
    DistroboxCreateDialog {
        id: createDialog
        errorDialog: errorDialog
    }
    
    DistroboxShortcutDialog {
        id: shortcutDialog
        containersList: mainPage.containersList
    }

    FilePickerDialog {
        id: packageFileDialog
    }
    
    pageStack.initialPage: Kirigami.ScrollablePage {
        id: mainPage
        spacing: Kirigami.Units.smallSpacing

        title: "Distrobox Containers"
        
        supportsRefreshing: true
        onRefreshingChanged: {
            if (refreshing) {
                var result = distroBoxManager.listContainers()
                mainPage.containersList = JSON.parse(result)
            }
        }

        property var containersList: []
        
        actions: [
            Kirigami.Action {
                text: "Create…"
                icon.name: "list-add"
                onTriggered: createDialog.open()
            },
            Kirigami.Action {
                text: "Refresh"
                icon.name: "view-refresh"
                onTriggered: {
                    var result = distroBoxManager.listContainers()
                    mainPage.containersList = JSON.parse(result)
                }
            }
        ]
        
        Component.onCompleted: {
            var result = distroBoxManager.listContainers()
            console.log("Containers:", result)
            mainPage.containersList = JSON.parse(result)
        }
        
        ColumnLayout {
            anchors.fill: parent
            spacing: Kirigami.Units.largeSpacing
            
            Kirigami.CardsListView {
                id: containersListView
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: mainPage.containersList
                
                delegate: Kirigami.AbstractCard {
                    contentItem: RowLayout {
                        spacing: Kirigami.Units.smallSpacing
                        
                        Rectangle {
                            width: Kirigami.Units.smallSpacing
                            Layout.fillHeight: true
                            color: distroBoxManager.getDistroColor(modelData.image)
                            radius: 4
                        }
                        
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.margins: Kirigami.Units.smallSpacing
                            
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                
                                Controls.Label {
                                    text: modelData.name.charAt(0).toUpperCase() + modelData.name.slice(1)
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    font.bold: true
                                }
                                
                                Controls.Label {
                                    text: modelData.image
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                                    opacity: 0.7
                                }
                            }
                            
                            RowLayout {
                                spacing: Kirigami.Units.smallSpacing

                                Controls.Button {
                                    icon.name: "delete"
                                    icon.color: Kirigami.Theme.negativeTextColor
                                    
                                    Controls.ToolTip {
                                        text: "Remove Container"
                                        visible: parent.hovered
                                        delay: 500
                                    }
                                    
                                    onClicked: {
                                        removeDialog.containerName = modelData.name
                                        removeDialog.open()
                                    }
                                }
                                
                                Controls.Button {
                                    icon.name: "system-software-update"
                                    
                                    Controls.ToolTip {
                                        text: "Upgrade Container"
                                        visible: parent.hovered
                                        delay: 500
                                    }
                                    
                                    onClicked: {
                                        distroBoxManager.upgradeContainer(modelData.name)
                                    }
                                }
                                
                                Controls.Button {
                                    icon.name: "install-symbolic"
                                    
                                    Controls.ToolTip {
                                        text: "Install Package"
                                        visible: parent.hovered
                                        delay: 500
                                    }
                                    
                                    onClicked: {
                                        packageFileDialog.containerName = modelData.name
                                        packageFileDialog.containerImage = modelData.image
                                        packageFileDialog.open()
                                    }
                                }
                                
                                Controls.Button {
                                    icon.name: "utilities-terminal-symbolic"
                                    
                                    Controls.ToolTip {
                                        text: "Open Terminal"
                                        visible: parent.hovered
                                        delay: 500
                                    }
                                    
                                    onClicked: {
                                        distroBoxManager.enterContainer(modelData.name)
                                    }
                                }
                            }
                        }
                    }
                }

                Kirigami.PlaceholderMessage {
                    anchors.centerIn: parent
                    visible: containersListView.count === 0
                    text: "No containers found. Create a new container now?"
                    helpfulAction: Kirigami.Action {
                        text: "Create Container"
                        icon.name: "list-add"
                        onTriggered: createDialog.open()
                    }
                }
            }
        }
    }
}
