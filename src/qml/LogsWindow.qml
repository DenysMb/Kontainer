/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.ApplicationWindow {
    id: root

    property string containerName: ""
    property int maxLines: 500
    property bool follow: true
    property bool timestamps: false
    property string levelFilter: "all" // all | error | warn
    property var rawLines: []
    property string pendingChunk: ""

    readonly property int rawLineLimit: 3000

    width: 800
    height: 600
    title: i18n("Logs — %1", root.containerName)
    flags: Qt.Window

    function restartStream() {
        distroBoxManager.stopLogsStream();
        distroBoxManager.startLogsStream(root.containerName, root.timestamps, root.maxLines);
    }

    function rebuildText() {
        var filtered = root.rawLines.filter(function (line) {
            if (root.levelFilter !== "all" && line.toLowerCase().indexOf(root.levelFilter) < 0) {
                return false;
            }
            return true;
        });
        logArea.text = filtered.join("\n");
        if (root.follow) {
            scrollToEnd();
        }
    }

    function scrollToEnd() {
        scrollView.ScrollBar.vertical.position = 1.0 - scrollView.ScrollBar.vertical.size;
    }

    function appendChunk(text) {
        root.pendingChunk += text;
        var parts = root.pendingChunk.split("\n");
        root.pendingChunk = parts.pop();
        var newLines = parts.filter(function (line) {
            return line.length > 0;
        });
        if (newLines.length === 0) {
            return;
        }
        var lines = root.rawLines.concat(newLines);
        if (lines.length > root.rawLineLimit) {
            lines = lines.slice(lines.length - root.rawLineLimit);
        }
        root.rawLines = lines;
        rebuildText();
    }

    Connections {
        target: distroBoxManager
        function onContainerLogsReceived(text) {
            root.appendChunk(text);
        }
    }

    pageStack.initialPage: Kirigami.Page {
        id: logsPage

        title: i18n("Container Logs")

        actions: [
            Kirigami.Action {
                text: i18n("Auto-scroll")
                icon.name: "go-bottom"
                checkable: true
                checked: root.follow
                onTriggered: {
                    root.follow = !root.follow;
                    if (root.follow) {
                        scrollToEnd();
                    }
                }
            },
            Kirigami.Action {
                text: i18n("Timestamps")
                icon.name: "view-time-schedule"
                checkable: true
                checked: root.timestamps
                onTriggered: {
                    root.timestamps = !root.timestamps;
                    root.rawLines = [];
                    root.pendingChunk = "";
                    root.restartStream();
                }
            },
            Kirigami.Action {
                text: i18n("More options")
                icon.name: "view-more-symbolic"
                Kirigami.Action {
                    text: i18n("Export logs to file…")
                    icon.name: "document-save-as"
                    onTriggered: exportDialog.open()
                }
                Kirigami.Action {
                    text: i18n("Clear view")
                    icon.name: "edit-clear-list"
                    onTriggered: {
                        root.rawLines = [];
                        root.rebuildText();
                    }
                }
                Kirigami.Action {
                    text: i18n("Filter by level")
                    icon.name: "view-filter"
                    Kirigami.Action {
                        text: i18n("All levels")
                        checkable: true
                        checked: root.levelFilter === "all"
                        onTriggered: root.levelFilter = "all"
                    }
                    Kirigami.Action {
                        text: i18n("Errors")
                        checkable: true
                        checked: root.levelFilter === "error"
                        onTriggered: root.levelFilter = "error"
                    }
                    Kirigami.Action {
                        text: i18n("Warnings")
                        checkable: true
                        checked: root.levelFilter === "warn"
                        onTriggered: root.levelFilter = "warn"
                    }
                }
            }
        ]

        padding: 0

        Controls.ScrollView {
            id: scrollView

            anchors.fill: parent

            Controls.TextArea {
                id: logArea

                readOnly: true
                wrapMode: TextEdit.NoWrap
                selectByMouse: true
                font: Kirigami.Theme.fixedFont
            }
        }
    }

    FileDialog {
        id: exportDialog

        fileMode: FileDialog.SaveFile
        defaultSuffix: "log"
        nameFilters: ["Log files (*.log)", "All files (*)"]
        onAccepted: {
            var path = selectedFile.toString().replace("file://", "");
            if (distroBoxManager.exportTextToFile(logArea.text, path)) {
                applicationWindow().showPassiveNotification(i18n("Logs exported"), "short");
            } else {
                applicationWindow().showPassiveNotification(i18n("Failed to export logs"), "short");
            }
        }
    }

    onLevelFilterChanged: rebuildText()

    Component.onCompleted: restartStream()
    onClosing: distroBoxManager.stopLogsStream()
}
