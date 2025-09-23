/*
 *   SPDX-License-Identifier: GPL-3.0-or-later
 *   SPDX-FileCopyrightText: 2025 Denys Madureira <denysmb@zoho.com>
 *   SPDX-FileCopyrightText: 2025 Thomas Duckworth <tduck@filotimoproject.org>
 *   SPDX-FileCopyrightText: 2025 Hadi Chokr <hadichokr@icloud.com>
 */

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import QtQuick.Dialogs
import QtCore

import org.kde.kirigami as Kirigami

Kirigami.ApplicationWindow {
    id: root

    width: 700
    height: 500

    title: i18n("Kontainer")

    About {
        id: aboutPage
        visible: false
    }

    property bool refreshing: false

    // persistent settings storage using QtCore.Settings
    Settings {
        id: kontainerSettings
        category: "Appearance"
        property bool showColors: false
    }

    // alias for clarity
    property alias fallbackToDistroColors: kontainerSettings.showColors

    function refresh() {
        refreshing = true;
        var result = distroBoxManager.listContainers();
        mainPage.containersList = JSON.parse(result);
        refreshing = false;
    }

    Connections {
        target: distroBoxManager
        function onContainerCloneFinished(clonedName, success) {
            if (success) {
                refresh();
            }
        }
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

            // toggle between distro-provided icons and colors
            Kirigami.Action {
                text: i18n("Show Container Icons")
                icon.name: "view-list-icons"
                checkable: true
                checked: !root.fallbackToDistroColors
                onToggled: root.fallbackToDistroColors = !checked
            },
            Kirigami.Action {
                text: i18n("Clone Container…")
                icon.name: "edit-copy"
                enabled: mainPage.containersList.length > 0
                onTriggered: cloneDialog.openWithContainer("")
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
    DistroboxCloneDialog {
        id: cloneDialog
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
        onRefreshingChanged: if (refreshing)
            refresh()

        property var containersList: []

        actions: [
            Kirigami.Action {
                text: i18n("Create…")
                icon.name: "list-add"
                onTriggered: createDialog.open()
            },
            Kirigami.Action {
                text: i18n("Upgrade all…")
                icon.name: "system-software-update"
                onTriggered: distroBoxManager.upgradeAllContainer()
            },
            Kirigami.Action {
                text: i18n("Refresh")
                icon.name: "view-refresh"
                onTriggered: refresh()
            }
        ]

        Component.onCompleted: refresh()

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
                            visible: root.fallbackToDistroColors
                            width: Kirigami.Units.smallSpacing
                            Layout.fillHeight: true
                            color: distroBoxManager.getDistroColor(modelData.image)
                            radius: 4
                        }

                        Rectangle {
                            visible: !root.fallbackToDistroColors
                            width: Kirigami.Units.iconSizes.medium + Kirigami.Units.smallSpacing * 2
                            Layout.fillHeight: true
                            color: {
                                const baseColor = distroBoxManager.getDistroColor(modelData.image);
                                if (typeof baseColor === "string" && baseColor.startsWith("#")) {
                                    const hex = baseColor.slice(1);
                                    const alphaHex = Math.round(0.15 * 255).toString(16).padStart(2, "0");
                                    if (hex.length === 6) {
                                        return "#" + alphaHex + hex;
                                    }
                                    if (hex.length === 8) {
                                        return "#" + alphaHex + hex.slice(2);
                                    }
                                }
                                return Qt.rgba(0, 0, 0, 0.15);
                            }
                            radius: 4

                            Kirigami.Icon {
                                anchors.centerIn: parent
                                source: distroBoxManager.getDistroIcon(modelData.name)
                                width: Kirigami.Units.iconSizes.medium
                                height: Kirigami.Units.iconSizes.medium
                            }
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
                                        icon.name: "package-x-generic"
                                        text: i18n("Install Package")
                                        onTriggered: {
                                            packageFileDialog.containerName = modelData.name;
                                            packageFileDialog.containerImage = modelData.image;
                                            packageFileDialog.open();
                                        }
                                    },
                                    Kirigami.Action {
                                        icon.name: "applications-all-symbolic"
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
                                    },
                                    Kirigami.Action {
                                        text: i18n("More options")
                                        icon.name: "view-more-symbolic"
                                        Kirigami.Action {
                                            icon.name: "system-software-update"
                                            text: i18n("Upgrade Container")
                                            onTriggered: {
                                                distroBoxManager.upgradeContainer(modelData.name);
                                            }
                                        }
                                        Kirigami.Action {
                                            icon.name: "edit-copy"
                                            text: i18n("Clone Container")
                                            onTriggered: {
                                                cloneDialog.openWithContainer(modelData.name);
                                            }
                                        }
                                        Kirigami.Action {
                                            icon.name: "delete"
                                            text: i18n("Remove Container")
                                            onTriggered: {
                                                removeDialog.containerName = modelData.name;
                                                removeDialog.open();
                                            }
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

                Controls.BusyIndicator {
                    anchors.centerIn: parent
                    visible: containersListView.count === 0 && refreshing && !loadingTimer.running
                }

                Timer {
                    id: loadingTimer
                    interval: 100
                    repeat: false
                }

                Component.onCompleted: loadingTimer.start()
            }
        }
    }
}
