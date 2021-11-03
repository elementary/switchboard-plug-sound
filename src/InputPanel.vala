// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2016-2017 elementary LLC. (https://elementary.io)
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

public class Sound.InputPanel : Gtk.Grid {
    private Gtk.ListBox devices_listbox;
    private unowned PulseAudioManager pam;

    Gtk.Scale volume_scale;
    Gtk.Switch volume_switch;
    Gtk.LevelBar level_bar;

    private Device? default_device = null;
    private InputDeviceMonitor device_monitor;

    construct {
        margin = 12;
        margin_bottom = 24;
        margin_top = 0;
        column_spacing = 12;
        row_spacing = 6;

        devices_listbox = new Gtk.ListBox () {
            activate_on_single_click = true
        };

        devices_listbox.row_activated.connect ((row) => {
            pam.set_default_device.begin (((Sound.DeviceRow) row).device);
        });

        var scrolled = new Gtk.ScrolledWindow (null, null);
        scrolled.add (devices_listbox);
        var devices_frame = new Gtk.Frame (null) {
            expand = true
        };
        devices_frame.add (scrolled);

        var volume_label = new Gtk.Label (_("Input volume:")) {
            valign = Gtk.Align.CENTER,
            halign = Gtk.Align.END
        };

        volume_scale = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 0, 100, 5) {
            margin_top = 18,
            draw_value = false,
            hexpand = true
        };

        volume_scale.add_mark (10, Gtk.PositionType.BOTTOM, _("Unamplified"));
        volume_scale.add_mark (80, Gtk.PositionType.BOTTOM, _("100%"));

        volume_switch = new Gtk.Switch () {
            valign = Gtk.Align.CENTER,
            active = true
        };

        var level_label = new Gtk.Label (_("Input level:")) {
            halign = Gtk.Align.END
        };

        level_bar = new Gtk.LevelBar.for_interval (0.0, 18.0) {
            max_value = 18,
            mode = Gtk.LevelBarMode.DISCRETE
        };

        level_bar.add_offset_value ("low", 16.1);
        level_bar.add_offset_value ("middle", 16.0);
        level_bar.add_offset_value ("high", 14.0);

        var no_device_grid = new Granite.Widgets.AlertView (_("No Input Device"), _("There is no input device detected. You might want to add one to start recording anything."), "audio-input-microphone-symbolic");
        no_device_grid.show_all ();
        devices_listbox.set_placeholder (no_device_grid);

        attach (devices_frame, 0, 1, 3, 1);
        attach (volume_label, 0, 2, 1, 1);
        attach (volume_scale, 1, 2, 1, 1);
        attach (volume_switch, 2, 2, 1, 1);
        attach (level_label, 0, 3, 1, 1);
        attach (level_bar, 1, 3, 1, 1);

        device_monitor = new InputDeviceMonitor ();
        device_monitor.update_fraction.connect (update_fraction);

        pam = PulseAudioManager.get_default ();
        pam.new_device.connect (add_device);
        pam.notify["default-input"].connect (() => {
            default_changed ();
        });

        volume_switch.bind_property ("active", volume_scale, "sensitive", BindingFlags.DEFAULT);

        connect_signals ();
    }

    public void set_visibility (bool is_visible) {
        if (is_visible) {
            device_monitor.start_record ();
        } else {
            device_monitor.stop_record ();
        }
    }

    private void disconnect_signals () {
        volume_switch.notify["active"].disconnect (volume_switch_changed);
        volume_scale.value_changed.disconnect (volume_scale_value_changed);
    }

    private void connect_signals () {
        volume_switch.notify["active"].connect (volume_switch_changed);
        volume_scale.value_changed.connect (volume_scale_value_changed);
    }

    private void volume_scale_value_changed () {
        disconnect_signals ();
        pam.change_device_volume (default_device, volume_scale.get_value ());
        connect_signals ();
    }

    private void volume_switch_changed () {
        disconnect_signals ();
        pam.change_device_mute (default_device, !volume_switch.active);
        connect_signals ();
    }

    private void default_changed () {
        disconnect_signals ();
        lock (default_device) {
            if (default_device != null) {
                default_device.notify.disconnect (device_notify);
            }

            default_device = pam.default_input;
            if (default_device != null) {
                device_monitor.set_device (default_device);
                volume_switch.active = !default_device.is_muted;
                volume_scale.set_value (default_device.volume);
                default_device.notify.connect (device_notify);
            }
        }

        connect_signals ();
    }

    private void device_notify (ParamSpec pspec) {
        disconnect_signals ();
        switch (pspec.get_name ()) {
            case "is-muted":
                volume_switch.active = !default_device.is_muted;
                break;
            case "volume":
                volume_scale.set_value (default_device.volume);
                break;
        }

        connect_signals ();
    }

    private void update_fraction (float fraction) {
        /* Since we split the bar in 18 segments, get the value out of 18 instead of 1 */
        level_bar.value = fraction * 18;
    }

    private void add_device (Device device) {
        if (!device.input) {
            return;
        }

        var device_row = new DeviceRow (device);
        Gtk.ListBoxRow? row = devices_listbox.get_row_at_index (0);
        if (row != null) {
            device_row.link_to_row ((DeviceRow) row);
        }

        device_row.show_all ();
        devices_listbox.add (device_row);
        device_row.set_as_default.connect (() => {
            pam.set_default_device.begin (device);
        });
    }
}
