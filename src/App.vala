/*
* SPDX-License-Identifier: LGPL-3.0-or-later
* SPDX-FileCopyrightText: 2023 elementary, Inc. (https://elementary.io)
*
* Authored by: Leonhard Kargl <leo.kargl@proton.me>
*/

public class Sound.App : Object {
    public signal void changed ();

    public uint32 index { get; private set; }
    public string name { get; private set; }
    public string display_name { get; private set; }
    public Icon icon { get; private set; }

    public string media_name { get; set; }
    public double volume { get; set; }
    public bool muted { get; set; }
    public PulseAudio.ChannelMap channel_map { get; set; }

    public App.from_sink_input_info (PulseAudio.SinkInputInfo sink_input) {
        index = sink_input.index;
        name = sink_input.proplist.gets (PulseAudio.Proplist.PROP_APPLICATION_NAME);

        string app_id;
        if (sink_input.proplist.contains (PulseAudio.Proplist.PROP_APPLICATION_ID) == 1) {
            app_id = sink_input.proplist.gets (PulseAudio.Proplist.PROP_APPLICATION_ID);
        } else {
            app_id = name;
        }

        var app_info = new DesktopAppInfo (app_id + ".desktop");

        if (app_info == null) {
            var results = DesktopAppInfo.search (app_id);
            if (results[0] != null && results[0][0] != null) {
                app_info = new DesktopAppInfo (results[0][0]);
            }
        }

        if (app_info != null) {
            display_name = app_info.get_name ();
            icon = app_info.get_icon ();
        } else {
            display_name = name;

            if (sink_input.proplist.contains (PulseAudio.Proplist.PROP_APPLICATION_ICON_NAME) == 1) {
                icon = new ThemedIcon (sink_input.proplist.gets (PulseAudio.Proplist.PROP_APPLICATION_ICON_NAME));
            } else {
                icon = new ThemedIcon ("application-default-icon");
            }
        }
    }
}
