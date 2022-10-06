# Sound Settings
[![Translation status](https://l10n.elementary.io/widgets/switchboard/-/switchboard-plug-sound/svg-badge.svg)](https://l10n.elementary.io/engage/switchboard/?utm_source=widget)

![screenshot](data/screenshot-output.png?raw=true)

## Building and Installation

You'll need the following dependencies:

* libcanberra-gtk3-dev
* libgranite-dev
* libgtk-3-dev
* libpulse-dev
* libswitchboard-3-dev
* meson
* valac

Run `meson` to configure the build environment and then `ninja` to build

    meson build --prefix=/usr
    cd build
    ninja

To install, use `ninja install`

    sudo ninja install
