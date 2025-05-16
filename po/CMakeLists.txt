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

        file(MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/i18ndesktopfiletranslations/)
        file(MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/i18ndesktopfiles/)

        # Move all .pot files into the temporary directory and rename them
        # also add to LINGUAS file for msgfmt to accept them
        set(LINGUAS_CONTENT "")
        file(GLOB PO_FILE_DIRS ${CMAKE_CURRENT_SOURCE_DIR}/*/)
        foreach(_poFileDir ${PO_FILE_DIRS})
                if(EXISTS ${_poFileDir}/${catalogname}.po)
                        get_filename_component(_poFileDirName ${_poFileDir} NAME)
                        set(_renamedPoFile ${CMAKE_BINARY_DIR}/i18ndesktopfiletranslations/${_poFileDirName}.po)
                        file(COPY ${_poFileDirName}/${catalogname}.po DESTINATION ${CMAKE_BINARY_DIR}/i18ndesktopfiletranslations/)
                        file(RENAME ${CMAKE_BINARY_DIR}/i18ndesktopfiletranslations/${catalogname}.po ${_renamedPoFile})
                        set(LINGUAS_CONTENT "${LINGUAS_CONTENT}${_poFileDirName}\n")
                endif()
        endforeach(_poFileDir ${PO_FILE_DIRS})
        file(WRITE ${CMAKE_BINARY_DIR}/i18ndesktopfiletranslations/LINGUAS "${LINGUAS_CONTENT}")

        # Make a function to process & install the internationalized .desktop files in the base dir
        function(install_i18n_desktop_file FILE DESTINATION)
                get_filename_component(fileName ${FILE} NAME)

                set(outputDir ${CMAKE_BINARY_DIR}/i18ndesktopfiles/)
                set(outputFile ${outputDir}/${fileName})

                # Determine the unambiguous, full path to the source template FILE.
                if(IS_ABSOLUTE ${FILE})
                        set(abs_template_path ${FILE})
                else()
                        set(abs_template_path ${CMAKE_CURRENT_SOURCE_DIR}/${FILE})
                endif()

                # Safety check: This condition is now less likely to be true even in in-source builds
                # due to the 'outputDir', unless FILE itself points into that specific subdirectory.
                if("${abs_template_path}" STREQUAL "${outputFile}")
                        message(FATAL_ERROR "Input template file '${abs_template_path}' and output file '${outputFile}' are the same path. This will cause a dependency cycle. Please ensure the input FILE points to a source template, not the build output location.")
                endif()

                add_custom_command(
                        OUTPUT ${outputFile}
                        COMMAND ${GETTEXT_MSGFMT_EXECUTABLE} --desktop --template=${abs_template_path} -d ${CMAKE_BINARY_DIR}/i18ndesktopfiletranslations/ -o ${outputFile}
                        DEPENDS ${abs_template_path}
                        VERBATIM
                        COMMENT "Generating internationalized ${fileName} into ${outputDir} from ${abs_template_path}"
                )

                add_custom_target(i18n_desktop_file_${fileName} ALL DEPENDS ${outputFile})

                install(PROGRAMS ${outputFile} DESTINATION ${DESTINATION})
        endfunction()

endif(NOT GETTEXT_MSGFMT_EXECUTABLE)
