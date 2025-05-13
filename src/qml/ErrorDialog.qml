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
    id: errorDialog
    title: "Error"
    padding: Kirigami.Units.largeSpacing
    standardButtons: Kirigami.Dialog.Ok
    
    property string text: "Failed to create container.\nPlease check your input and try again."
    
    Controls.Label {
        text: errorDialog.text
    }
}
