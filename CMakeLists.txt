cmake_minimum_required(VERSION 3.20)
project(kontainer VERSION 1.0.0)

set(QT6_MIN_VERSION 6.5.0)
set(KF6_MIN_VERSION 6.0.0)

find_package(ECM ${KF6_MIN_VERSION} REQUIRED NO_MODULE)

set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} ${ECM_MODULE_PATH})
set(CMAKE_EXPORT_COMPILE_COMMANDS TRUE)

include(FeatureSummary)
include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)
include(ECMSetupVersion)
include(ECMFindQmlModule)
include(KDEGitCommitHooks)

ecm_setup_version(${PROJECT_VERSION} VARIABLE_PREFIX KONTAINER VERSION_HEADER
                  "${CMAKE_CURRENT_BINARY_DIR}/src/version-kontainer.h")

find_package(Qt6 ${QT6_MIN_VERSION} REQUIRED COMPONENTS
    Core
    Quick
    Test
    Gui
    Qml
    QuickControls2
    Widgets
)

find_package(KF6 ${KF6_MIN_VERSION} REQUIRED COMPONENTS
    Kirigami
    I18n
    CoreAddons
    QQC2DesktopStyle
    IconThemes
)
find_package(KF6 REQUIRED COMPONENTS KirigamiAddons)

ecm_find_qmlmodule(org.kde.kirigami REQUIRED)
ecm_find_qmlmodule(org.kde.kirigamiaddons.formcard 1.0)

qt_policy(SET QTP0001 NEW)
add_subdirectory(src)

# Install desktop file
install(PROGRAMS io.github.DenysMb.Kontainer.desktop DESTINATION ${KDE_INSTALL_APPDIR})

# Install metainfo file
install(FILES io.github.DenysMb.Kontainer.metainfo.xml DESTINATION ${KDE_INSTALL_METAINFODIR})

# Install icon
install(FILES src/assets/io.github.DenysMb.Kontainer.svg DESTINATION ${KDE_INSTALL_ICONDIR}/hicolor/scalable/apps)

feature_summary(WHAT ALL INCLUDE_QUIET_PACKAGES FATAL_ON_MISSING_REQUIRED_PACKAGES)
