# Switchboard Sound Plug
[![Translation status](https://l10n.elementary.io/widgets/switchboard/switchboard-plug-sound/svg-badge.svg)](https://l10n.elementary.io/projects/switchboard/switchboard-plug-sound/?utm_source=widget)

## Building and Installation

You'll need the following dependencies:

* cmake
* libcanberra-gtk-dev
* libgranite-dev
* libgtk-3-dev
* libswitchboard-2.0-dev
* libpulse-dev
* valac

Run `meson` to configure the build environment and then `ninja` to build

    meson build --prefix=/usr
    cd build
    ninja

To install, use `ninja install`

    sudo ninja install
