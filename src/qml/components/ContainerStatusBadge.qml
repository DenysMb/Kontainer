/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: badge

    property string status: ""

    signal toggleRequested

    readonly property string normalizedStatus: (status || "").toLowerCase()
    readonly property bool isPaused: normalizedStatus.indexOf("paus") >= 0
    readonly property bool isRunning: normalizedStatus.startsWith("up") || isPaused
    readonly property color statusColor: isRunning ? (isPaused ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.positiveTextColor) : Kirigami.Theme.disabledTextColor

    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight

    Row {
        id: content

        spacing: Kirigami.Units.smallSpacing

        Rectangle {
            id: statusDot

            anchors.verticalCenter: parent.verticalCenter
            width: Kirigami.Units.iconSizes.small - Kirigami.Units.smallSpacing * 2
            height: width
            radius: width / 2
            color: badge.statusColor

            SequentialAnimation on opacity {
                running: badge.isRunning
                loops: Animation.Infinite
                NumberAnimation {
                    to: 0.3
                    duration: 800
                }
                NumberAnimation {
                    to: 1.0
                    duration: 800
                }
            }
        }

        Controls.Label {
            text: badge.isRunning ? (badge.isPaused ? i18n("Paused") : i18n("Running")) : i18n("Stopped")
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            color: badge.statusColor
        }
    }

    Controls.ToolTip.visible: hoverHandler.hovered
    Controls.ToolTip.text: badge.status
    Controls.ToolTip.delay: Kirigami.Units.toolTipDelay

    HoverHandler {
        id: hoverHandler
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: badge.toggleRequested()
    }
}
