/*
* Copyright 2020 elementary, Inc. (https://elementary.io)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 3 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*/

public class Sound.AppRow : Gtk.ListBoxRow {
    public App app { get; construct; }
    private Gtk.Label description_label;
    private Gtk.Revealer description_revealer;

    public AppRow (App app) {
        Object (app: app);
    }

    construct {
        hexpand = true;
        var appinfo = new GLib.DesktopAppInfo (app.name + ".desktop");

        Gtk.Image image;
        if (appinfo != null && appinfo.get_icon () != null) {
            image = new Gtk.Image.from_gicon (appinfo.get_icon (), Gtk.IconSize.DND);
        } else {
            image = new Gtk.Image.from_icon_name ("application-default-icon", Gtk.IconSize.DND);
        }

        image.pixel_size = 32;

        var title_label = new Gtk.Label (appinfo != null ? appinfo.get_name () : app.name) {
            ellipsize = Pango.EllipsizeMode.END,
            valign = Gtk.Align.END,
            xalign = 0
        };
        title_label.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);

        var scale = new Gtk.Scale.with_range (HORIZONTAL, 0, 1, 0.01) {
            hexpand = true,
            draw_value = false
        };
        scale.set_value (app.volume);

        var grid = new Gtk.Grid () {
            column_spacing = 6,
            margin_top = 6,
            margin_end = 6,
            margin_bottom = 6,
            margin_start = 6
        };
        grid.attach (image, 0, 0, 1, 2);
        grid.attach (title_label, 1, 0);
        grid.attach (scale, 1, 1);

        child = grid;

        app.notify["volume"].connect (() => {
            scale.set_value (app.volume);
        });

        scale.change_value.connect ((type, new_value) => {
            PulseAudioManager.get_default ().change_application_volume (app, new_value.clamp (0, 1));
            return true;
        });
    }
}
