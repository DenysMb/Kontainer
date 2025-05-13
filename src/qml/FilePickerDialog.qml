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