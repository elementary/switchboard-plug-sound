/*
* SPDX-License-Identifier: LGPL-3.0-or-later
* SPDX-FileCopyrightText: 2023 elementary, Inc. (https://elementary.io)
*
* Authored by: Leonhard Kargl <leo.kargl@proton.me>
*/

public class Sound.App : Object {
    public uint32 index { get; construct; }
    public string name { get; construct; }
    public string display_name { get; construct; }
    public Icon icon { get; construct; }

    public double volume { get; set; }
    public bool muted { get; set; }
    public PulseAudio.ChannelMap channel_map { get; set; }

    public App (uint32 index, string name) {
        Object (
            index: index,
            name: name
        );
    }

    construct {
        var app_info = new GLib.DesktopAppInfo (name + ".desktop");

        if (app_info != null) {
            display_name = app_info.get_name ();
            icon = app_info.get_icon ();
        } else {
            display_name = name;
            icon = new ThemedIcon ("application-default-icon");
        }
    }
}
