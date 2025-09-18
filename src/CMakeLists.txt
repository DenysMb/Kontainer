# SPDX-FileCopyrightText: 2025 Denys Madureira <denysmb@zoho.com>
# SPDX-FileCopyrightText: 2025 Thomas Duckworth <tduck@filotimoproject.org>
# SPDX-License-Identifier: GPL-3.0-or-later

add_executable(kontainer)

ecm_add_qml_module(kontainer
    URI
    io.github.DenysMb.Kontainer
)

target_sources(kontainer
    PRIVATE
    main.cpp
    core/distroboxmanager.cpp
    core/distroboxmanager.h
    core/distroboxcli.cpp
    core/distroboxcli.h
    core/packageinstallcommand.cpp
    core/packageinstallcommand.h
    core/terminallauncher.cpp
    core/terminallauncher.h
    utils/distrocolors.cpp
    utils/distrocolors.h
)

target_include_directories(kontainer
    PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/core
    ${CMAKE_CURRENT_SOURCE_DIR}/utils
)

ecm_target_qml_sources(kontainer
    SOURCES
    qml/Main.qml
    qml/About.qml
    qml/ApplicationsWindow.qml
    qml/DistroboxCreateDialog.qml
    qml/DistroboxRemoveDialog.qml
    qml/DistroboxShortcutDialog.qml
    qml/ErrorDialog.qml
    qml/FilePickerDialog.qml
)

target_link_libraries(kontainer
    PRIVATE
    Qt6::Quick
    Qt6::Qml
    Qt6::Gui
    Qt6::QuickControls2
    Qt6::Widgets
    KF6::I18n
    KF6::CoreAddons
    KF6::IconThemes
    KF6::KIOGui
)

install(TARGETS kontainer ${KDE_INSTALL_TARGETS_DEFAULT_ARGS})
