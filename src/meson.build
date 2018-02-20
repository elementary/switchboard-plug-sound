plug_files = files(
    'TestPopover.vala',
    'PulseAudioManager.vala',
    'Plug.vala',
    'OutputPanel.vala',
    'InputPanel.vala',
    'InputDeviceMonitor.vala',
    'DeviceRow.vala',
    'Device.vala'
)

switchboard_dep = dependency('switchboard-2.0')

shared_module(
    meson.project_name(),
    plug_files,
    dependencies: [
        dependency('glib-2.0'),
        dependency('gio-2.0'),
        dependency('gobject-2.0'),
        dependency('granite'),
        dependency('gtk+-3.0'),
        dependency('libpulse'),
        dependency('libpulse-mainloop-glib'),
        dependency('libcanberra'),
        dependency('libcanberra-gtk'),
        meson.get_compiler('vala').find_library('libpulse-ext', dirs: join_paths(meson.source_root(), 'vapi')),
        switchboard_dep
    ],
    install: true,
    install_dir : join_paths(switchboard_dep.get_pkgconfig_variable('plugsdir'), 'system')
)
