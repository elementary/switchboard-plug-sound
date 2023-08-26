/*
* SPDX-License-Identifier: LGPL-3.0-or-later
* SPDX-FileCopyrightText: 2023 elementary, Inc. (https://elementary.io)
*
* Authored by: Leonhard Kargl <leo.kargl@proton.me>
*/

public class Sound.AppRow : Gtk.ListBoxRow {
    private App? app;
    private Gtk.Label title_label;
    private Gtk.Image image;
    private Gtk.Scale volume_scale;

    construct {
        image = new Gtk.Image () {
            pixel_size = 32
        };

        title_label = new Gtk.Label ("") {
            ellipsize = Pango.EllipsizeMode.END,
            valign = Gtk.Align.END,
            xalign = 0
        };
        title_label.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);

        volume_scale = new Gtk.Scale.with_range (HORIZONTAL, 0, 1, 0.01) {
            hexpand = true,
            draw_value = false
        };

        var grid = new Gtk.Grid () {
            column_spacing = 6,
            margin_top = 6,
            margin_end = 6,
            margin_bottom = 6,
            margin_start = 6
        };
        grid.attach (image, 0, 0, 1, 2);
        grid.attach (title_label, 1, 0);
        grid.attach (volume_scale, 1, 1);

        hexpand = true;
        child = grid;

        volume_scale.change_value.connect ((type, new_value) => {
            if (app != null) {
                PulseAudioManager.get_default ().change_application_volume (app, new_value.clamp (0, 1));
            }

            return true;
        });
    }

    private void update_scale () {
        volume_scale.set_value (app.volume);
    }

    public void bind_app (App app) {
        this.app = app;

        var appinfo = new GLib.DesktopAppInfo (app.name + ".desktop");

        title_label.label = appinfo != null ? appinfo.get_name () : app.name;

        if (appinfo != null && appinfo.get_icon () != null) {
            image.set_from_gicon (appinfo.get_icon (), Gtk.IconSize.DND);
        } else {
            image.set_from_icon_name ("application-default-icon", Gtk.IconSize.DND);
        }

        app.notify["volume"].connect (update_scale);

        volume_scale.set_value (app.volume);
    }

    public void unbind_app () {
        app.notify["volume"].disconnect (update_scale);
    }
}
