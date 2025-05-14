find_program(GETTEXT_MSGFMT_EXECUTABLE msgfmt)

if(NOT GETTEXT_MSGFMT_EXECUTABLE)
        message(
"------
                 NOTE: msgfmt not found. Translations will *not* be installed
------")
else(NOT GETTEXT_MSGFMT_EXECUTABLE)

        set(catalogname ${CMAKE_PROJECT_NAME})

        # Beautiful hackery
        # Process .desktop files
        file(GLOB_RECURSE DESKTOP_FILES ${CMAKE_SOURCE_DIR}/*.desktop)
        set(PROCESSED_DESKTOP_FILES)

        file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/desktopfiles/)

        # Move all .pot files into the temporary directory and rename them
        # also add to LINGUAS file for msgfmt to accept them
        set(LINGUAS_CONTENT "")
        file(GLOB PO_FILE_DIRS ${CMAKE_CURRENT_SOURCE_DIR}/*/)
        foreach(_poFileDir ${PO_FILE_DIRS})
                if(EXISTS ${_poFileDir}/${catalogname}.po)
                        get_filename_component(_poFileDirName ${_poFileDir} NAME)
                        set(_renamedPoFile ${CMAKE_CURRENT_BINARY_DIR}/desktopfiles/${_poFileDirName}.po)
                        file(COPY ${_poFileDirName}/${catalogname}.po DESTINATION ${CMAKE_CURRENT_BINARY_DIR}/desktopfiles/)
                        file(RENAME ${CMAKE_CURRENT_BINARY_DIR}/desktopfiles/${catalogname}.po ${_renamedPoFile})
                        set(LINGUAS_CONTENT "${LINGUAS_CONTENT}${_poFileDirName}\n")
                endif()
        endforeach(_poFileDir ${PO_FILE_DIRS})
        file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/desktopfiles/LINGUAS "${LINGUAS_CONTENT}")

        # Make a function to process & install the internationalised .desktop files in the base dir
        function(install_internationalized_desktop_file FILE DESTINATION)
                get_filename_component(fileName ${FILE} NAME)
                set(outputFile ${CMAKE_BINARY_DIR}/${fileName})
                add_custom_command(
                                OUTPUT ${outputFile}
                                COMMAND ${GETTEXT_MSGFMT_EXECUTABLE} --desktop --template=${FILE} -d ${CMAKE_BINARY_DIR}/po/desktopfiles -o ${outputFile}
                                DEPENDS ${FILE}
                )
                add_custom_target(process_internationalized_desktop_files ALL DEPENDS ${outputFile})
                install(PROGRAMS ${outputFile} DESTINATION ${DESTINATION})
        endfunction()

endif(NOT GETTEXT_MSGFMT_EXECUTABLE)
