/*-
 * Copyright 2016-2021 elementary, Inc. (https://elementary.io)
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301 USA.
 *
 * Authored by: Corentin Noël <corentin@elementary.io>
 */

public class Sound.DeviceRow : Gtk.ListBoxRow {
    public signal void set_as_default ();

    public Device device { get; construct; }

    private Gtk.RadioButton activate_radio;
    private bool ignore_default = false;

    public DeviceRow (Device device) {
        Object (device: device);
    }

    construct {
        activate_radio = new Gtk.RadioButton (null) {
            halign = Gtk.Align.END,
            valign = Gtk.Align.END
        };

        var image = new Gtk.Image.from_icon_name (device.icon_name, Gtk.IconSize.DND) {
            tooltip_text = device.get_nice_form_factor (),
            use_fallback = true
        };

        var overlay = new Gtk.Overlay ();
        overlay.add (image);
        overlay.add_overlay (activate_radio);

        var name_label = new Gtk.Label (device.display_name) {
            xalign = 0
        };

        var description_label = new Gtk.Label (device.description) {
            xalign = 0
        };

        unowned var description_style_context = description_label.get_style_context ();
        description_style_context.add_class (Gtk.STYLE_CLASS_DIM_LABEL);
        description_style_context.add_class (Granite.STYLE_CLASS_SMALL_LABEL);

        var grid = new Gtk.Grid () {
            margin = 6,
            column_spacing = 12,
            orientation = Gtk.Orientation.HORIZONTAL
        };

        grid.attach (overlay, 1, 0, 1, 2);
        grid.attach (name_label, 2, 0);
        grid.attach (description_label, 2, 1);

        add (grid);

        activate.connect (() => {
            activate_radio.active = true;
        });

        activate_radio.toggled.connect (() => {
            if (activate_radio.active && !ignore_default) {
                set_as_default ();
            }
        });

        device.bind_property ("display-name", name_label, "label");
        device.bind_property ("description", description_label, "label");

        device.removed.connect (() => destroy ());
        device.notify["is-default"].connect (() => {
            ignore_default = true;
            activate_radio.active = device.is_default;
            ignore_default = false;
        });
    }

    public void link_to_row (DeviceRow row) {
        activate_radio.join_group (row.activate_radio);
        activate_radio.active = device.is_default;
    }
}
