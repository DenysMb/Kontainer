/*
    SPDX-License-Identifier: GPL-3.0-or-later
    SPDX-FileCopyrightText: 2025 Denys Madureira <denysmb@zoho.com>
    SPDX-FileCopyrightText: 2025 Thomas Duckworth <tduck@filotimoproject.org>
*/

import QtQuick
import QtQuick.Dialogs

FileDialog {
    id: packageFileDialog
    title: "Choose Package"
    nameFilters: ["Package files (*.deb *.rpm *.pkg.tar.zst *.apk *.xbps)"]
    
    property string containerName
    property string containerImage
    
    onAccepted: {
        distroBoxManager.installPackageInContainer(containerName, selectedFile, containerImage)
    }
}
