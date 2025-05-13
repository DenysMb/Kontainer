add_executable(kontainer)

ecm_add_qml_module(kontainer
    URI
    io.github.DenysMb.Kontainer
)

target_sources(kontainer
    PRIVATE
    main.cpp
    distroboxmanager.cpp
    distroboxmanager.h
)

ecm_target_qml_sources(kontainer
    SOURCES
    qml/Main.qml
    qml/About.qml
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
)

install(TARGETS kontainer ${KDE_INSTALL_TARGETS_DEFAULT_ARGS})
