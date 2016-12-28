find_package (PkgConfig)

# Add all your dependencies to the list below
pkg_check_modules (DEPS REQUIRED gthread-2.0 gtk+-3.0 switchboard-2.0 granite libpulse libpulse-mainloop-glib libcanberra libcanberra-gtk)

add_definitions (${DEPS_CFLAGS})
link_directories (${DEPS_LIBRARY_DIRS})

find_package (Vala REQUIRED)
include (ValaVersion)
ensure_vala_version ("0.22.0" MINIMUM)

include (ValaPrecompile)
# Add all your vala files and requires packages to the List below to include them in the build
vala_precompile (VALA_C ${CMAKE_PROJECT_NAME}
    Plug.vala
    InputPanel.vala
    OutputPanel.vala
    DeviceRow.vala
    TestPopover.vala
    Device.vala
    InputDeviceMonitor.vala
    PulseAudioManager.vala
    ${CMAKE_CURRENT_BINARY_DIR}/config.vala
PACKAGES
    granite
    gtk+-3.0
    libcanberra
    libcanberra-gtk
    libpulse
    libpulse-mainloop-glib
    libpulse-ext
    switchboard-2.0
OPTIONS
    --vapidir=${CMAKE_SOURCE_DIR}/vapi
    --thread
)

include (GResource)
glib_compile_resources (GLIB_RESOURCES_ICONS ../data/icons.gresource.xml)

add_library (${CMAKE_PROJECT_NAME} MODULE ${VALA_C} ${GLIB_RESOURCES_ICONS})
target_link_libraries(${CMAKE_PROJECT_NAME} ${DEPS_LIBRARIES})

# Installation
install (TARGETS ${CMAKE_PROJECT_NAME} DESTINATION ${PKGDATADIR})
