// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2016-2018 elemntary LLC. (https://elementary.io)
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

public class Sound.OutputPanel : Gtk.Grid {
    private Gtk.ListBox devices_listbox;
    private unowned PulseAudioManager pam;

    Gtk.Scale volume_scale;
    Gtk.Switch volume_switch;
    Gtk.Scale balance_scale;

    private Device default_device = null;

    construct {
        margin = 12;
        margin_top = 0;
        column_spacing = 12;
        row_spacing = 6;

        var available_label = new Gtk.Label (_("Available Sound Output Devices:"));
        available_label.get_style_context ().add_class ("h4");
        available_label.halign = Gtk.Align.START;

        devices_listbox = new Gtk.ListBox ();
        devices_listbox.activate_on_single_click = true;
        devices_listbox.row_activated.connect ((row) => {
            pam.set_default_device.begin (((Sound.DeviceRow) row).device);
        });

        var scrolled = new Gtk.ScrolledWindow (null, null);
        scrolled.add (devices_listbox);

        var devices_frame = new Gtk.Frame (null);
        devices_frame.expand = true;
        devices_frame.margin_bottom = 18;
        devices_frame.add (scrolled);

        var volume_label = new Gtk.Label (_("Output volume:"));
        volume_label.halign = Gtk.Align.END;

        volume_scale = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 0, 100, 5);
        volume_scale.adjustment.page_increment = 5;
        volume_scale.draw_value = false;
        volume_scale.hexpand = true;

        volume_switch = new Gtk.Switch ();
        volume_switch.valign = Gtk.Align.CENTER;
        volume_switch.active = true;

        var balance_label = new Gtk.Label (_("Balance:"));
        balance_label.valign = Gtk.Align.START;
        balance_label.halign = Gtk.Align.END;
        balance_label.margin_bottom = 18;

        balance_scale = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, -1, 1, 0.1);
        balance_scale.adjustment.page_increment = 0.1;
        balance_scale.draw_value = false;
        balance_scale.has_origin = false;
        balance_scale.margin_bottom = 18;
        balance_scale.add_mark (-1, Gtk.PositionType.BOTTOM, _("Left"));
        balance_scale.add_mark (0, Gtk.PositionType.BOTTOM, _("Center"));
        balance_scale.add_mark (1, Gtk.PositionType.BOTTOM, _("Right"));

        var alerts_label = new Gtk.Label (_("Event alerts:"));
        alerts_label.halign = Gtk.Align.END;

        var audio_alert_check = new Gtk.CheckButton.with_label (_("Play sound"));

        var visual_alert_check = new Gtk.CheckButton.with_label (_("Flash screen"));
        visual_alert_check.halign = Gtk.Align.START;
        visual_alert_check.hexpand = true;

        var alerts_info = new Gtk.Label (_("Event alerts occur when the system cannot do something in response to user input, like attempting to backspace in an empty input or switch windows when only one is open."));
        alerts_info.max_width_chars = 80;
        alerts_info.wrap = true;
        alerts_info.xalign = 0;
        alerts_info.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        var test_button = new Gtk.ToggleButton.with_label (_("Test Speakers…"));
        test_button.halign = Gtk.Align.END;
        test_button.margin_top = 18;

        var test_popover = new TestPopover (test_button);
        test_button.bind_property ("active", test_popover, "visible", GLib.BindingFlags.BIDIRECTIONAL);

        var no_device_grid = new Granite.Widgets.AlertView (_("No Output Device"), _("There is no output device detected. You might want to add one to start listening to anything."), "audio-volume-muted-symbolic");
        no_device_grid.show_all ();
        devices_listbox.set_placeholder (no_device_grid);

        attach (available_label, 0, 0, 3, 1);
        attach (devices_frame, 0, 1, 3, 1);
        attach (volume_label, 0, 2);
        attach (volume_scale, 1, 2, 2);
        attach (volume_switch, 3, 2);
        attach (balance_label, 0, 3);
        attach (balance_scale, 1, 3, 2);
        attach (alerts_label, 0, 4);
        attach (audio_alert_check, 1, 4);
        attach (visual_alert_check, 2, 4);
        attach (alerts_info, 1, 5, 2);
        attach (test_button, 0, 6, 4);

        pam = PulseAudioManager.get_default ();
        pam.new_device.connect (add_device);
        pam.notify["default-output"].connect (default_changed);

        volume_switch.bind_property ("active", volume_scale, "sensitive", BindingFlags.DEFAULT);
        volume_switch.bind_property ("active", balance_scale, "sensitive", BindingFlags.DEFAULT);

        var sound_settings = new Settings ("org.gnome.desktop.sound");
        sound_settings.bind ("event-sounds", audio_alert_check, "active", GLib.SettingsBindFlags.DEFAULT);

        var wm_settings = new Settings ("org.gnome.desktop.wm.preferences");
        wm_settings.bind ("visual-bell", visual_alert_check, "active", GLib.SettingsBindFlags.DEFAULT);

        connect_signals ();
    }

    private void default_changed () {
        disconnect_signals ();
        lock (default_device) {
            if (default_device != null) {
                default_device.notify.disconnect (device_notify);
            }

            default_device = pam.default_output;
            if (default_device != null) {
                volume_switch.active = !default_device.is_muted;
                volume_scale.set_value (default_device.volume);
                balance_scale.set_value (default_device.balance);
                default_device.notify.connect (device_notify);
            }
        }

        connect_signals ();
    }

    private void disconnect_signals () {
        volume_switch.notify["active"].disconnect (volume_switch_changed);
        volume_scale.value_changed.disconnect (volume_scale_value_changed);
        balance_scale.value_changed.disconnect (balance_scale_value_changed);
    }

    private void connect_signals () {
        volume_switch.notify["active"].connect (volume_switch_changed);
        volume_scale.value_changed.connect (volume_scale_value_changed);
        balance_scale.value_changed.connect (balance_scale_value_changed);
    }

    private void volume_scale_value_changed () {
        disconnect_signals ();
        pam.change_device_volume (default_device, (float)volume_scale.get_value ());
        connect_signals ();
    }

    private void balance_scale_value_changed () {
        disconnect_signals ();
        pam.change_device_balance (default_device, (float)balance_scale.get_value ());
        connect_signals ();
    }

    private void volume_switch_changed () {
        disconnect_signals ();
        pam.change_device_mute (default_device, !volume_switch.active);
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
            case "balance":
                balance_scale.set_value (default_device.balance);
                break;
        }

        connect_signals ();
    }

    private void add_device (Device device) {
        if (device.input) {
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
