/*
    SPDX-License-Identifier: GPL-3.0-or-later
    SPDX-FileCopyrightText: 2025 Denys Madureira <denysmb@zoho.com>
    SPDX-FileCopyrightText: 2025 Thomas Duckworth <tduck@filotimoproject.org>
*/

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

Kirigami.ApplicationWindow {
    id: root

    width: 600
    height: 500

    title: i18n("Kontainer")

    About {
        id: aboutPage
        visible: false
    }

    property bool refreshing: false

    function refresh() {
        refreshing = true;
        var result = distroBoxManager.listContainers();
        mainPage.containersList = JSON.parse(result);
        refreshing = false;
    }

    globalDrawer: Kirigami.GlobalDrawer {
        isMenu: true
        actions: [
            Kirigami.Action {
                text: i18n("Create Container…")
                icon.name: "list-add"
                onTriggered: createDialog.open()
            },
            Kirigami.Action {
                text: i18n("Create Distrobox Shortcut…")
                icon.name: "document-new"
                enabled: mainPage.containersList.length > 0
                onTriggered: shortcutDialog.open()
            },
            Kirigami.Action {
                separator: true
            },
            Kirigami.Action {
                text: i18n("Open Distrobox Documentation")
                icon.name: "help-contents"
                onTriggered: Qt.openUrlExternally("https://distrobox.it/#distrobox")
            },
            Kirigami.Action {
                text: i18n("Open Distrobox Useful Tips")
                icon.name: "help-hint"
                onTriggered: Qt.openUrlExternally("https://github.com/89luca89/distrobox/blob/main/docs/useful_tips.md")
            },
            Kirigami.Action {
                separator: true
            },
            Kirigami.Action {
                text: i18n("About Kontainer")
                icon.name: "io.github.DenysMb.Kontainer"
                onTriggered: {
                    if (root.pageStack.layers.currentItem !== aboutPage) {
                        root.pageStack.layers.push(aboutPage);
                    }
                }
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
        padding: Kirigami.Units.smallSpacing

        title: i18n("Distrobox Containers")

        supportsRefreshing: true
        onRefreshingChanged: {
            if (refreshing) {
                refresh();
            }
        }

        property var containersList: []

        actions: [
            Kirigami.Action {
                text: i18n("Create…")
                icon.name: "list-add"
                onTriggered: createDialog.open()
            },
            Kirigami.Action {
                text: i18n("Refresh")
                icon.name: "view-refresh"
                onTriggered: refresh()
            }
        ]

        Component.onCompleted: {
            refresh();
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
                                spacing: Kirigami.Units.smallSpacing
                                Layout.maximumWidth: implicitWidth

                                Controls.Label {
                                    text: modelData.name.charAt(0).toUpperCase() + modelData.name.slice(1)
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
                                    font.bold: true
                                }

                                Controls.Label {
                                    text: modelData.image
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                                    opacity: 0.7
                                }
                            }

                            Kirigami.ActionToolBar {
                                id: actionToolBar

                                Layout.fillWidth: true
                                spacing: Kirigami.Units.smallSpacing

                                alignment: Qt.AlignRight
                                display: Controls.Button.IconOnly
                                flat: false

                                actions: [
                                    Kirigami.Action {
                                        icon.name: "delete"
                                        text: i18n("Remove Container")
                                        onTriggered: {
                                            removeDialog.containerName = modelData.name;
                                            removeDialog.open();
                                        }
                                    },
                                    Kirigami.Action {
                                        icon.name: "system-software-update"
                                        text: i18n("Upgrade Container")
                                        onTriggered: {
                                            distroBoxManager.upgradeContainer(modelData.name);
                                        }
                                    },
                                    Kirigami.Action {
                                        icon.name: "install-symbolic"
                                        text: i18n("Install Package")
                                        onTriggered: {
                                            packageFileDialog.containerName = modelData.name;
                                            packageFileDialog.containerImage = modelData.image;
                                            packageFileDialog.open();
                                        }
                                    },
                                    Kirigami.Action {
                                        icon.name: "applications-other-symbolic"
                                        text: i18n("Manage Applications")
                                        onTriggered: {
                                            var component = Qt.createComponent("ApplicationsWindow.qml");
                                            if (component.status === Component.Ready) {
                                                var window = component.createObject(root, {
                                                    containerName: modelData.name
                                                });
                                                window.show();
                                            } else {
                                                console.error("Error loading ApplicationsWindow:", component.errorString());
                                            }
                                        }
                                    },
                                    Kirigami.Action {
                                        icon.name: "utilities-terminal-symbolic"
                                        text: i18n("Open Terminal")
                                        onTriggered: {
                                            distroBoxManager.enterContainer(modelData.name);
                                        }
                                    }
                                ]
                            }
                        }
                    }
                }

                Kirigami.PlaceholderMessage {
                    anchors.centerIn: parent
                    visible: containersListView.count === 0 && !refreshing
                    text: i18n("No containers found. Create a new container now?")
                    helpfulAction: Kirigami.Action {
                        text: i18n("Create Container")
                        icon.name: "list-add"
                        onTriggered: createDialog.open()
                    }
                }

                // Since the UI thread isn't blocked by runCommand anymore, this shows on refresh
                // that the distroboxes are being loaded -- rather than freezing the application.
                Controls.BusyIndicator {
                    anchors.centerIn: parent
                    visible: containersListView.count === 0 && refreshing && !loadingTimer.running
                }

                // Avoids flickering when distroboxes load quickly.
                Timer {
                    id: loadingTimer
                    interval: 100 // 100ms
                    repeat: false
                }

                Component.onCompleted: {
                    loadingTimer.start();
                }
            }
        }
    }
}
