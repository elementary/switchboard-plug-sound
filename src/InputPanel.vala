/*
 * SPDX-License-Identifier: LGPL-2.0-or-later
 * SPDX-FileCopyrightText: 2016-2023 elementary, Inc. (https://elementary.io)
 *
 * Authored by: Corentin Noël <corentin@elementary.io>
 */

public class Sound.InputPanel : Gtk.Box {
    private Device? default_device = null;
    private Gtk.LevelBar level_bar;
    private Gtk.ListBox devices_listbox;
    private Gtk.Scale volume_scale;
    private Gtk.Switch volume_switch;
    private InputDeviceMonitor device_monitor;
    private unowned PulseAudioManager pam;

    construct {
        margin_bottom = 12;

        var no_device_grid = new Granite.Widgets.AlertView (
            _("No Connected Audio Devices Detected"),
            _("Check that all cables are securely attached and audio input devices are powered on."),
            "audio-input-microphone-symbolic"
        );
        no_device_grid.show_all ();

        devices_listbox = new Gtk.ListBox () {
            activate_on_single_click = true,
            vexpand = true
        };
        devices_listbox.set_placeholder (no_device_grid);

        devices_listbox.row_activated.connect ((row) => {
            pam.set_default_device.begin (((Sound.DeviceRow) row).device);
        });

        var scrolled = new Gtk.ScrolledWindow (null, null) {
            child = devices_listbox
        };

        var devices_frame = new Gtk.Frame (null) {
            child = scrolled
        };

        var volume_label = new Granite.HeaderLabel (_("Input Volume"));

        volume_scale = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 0, 100, 5) {
            draw_value = false,
            hexpand = true,
            margin_top = 3
        };

        volume_scale.add_mark (10, Gtk.PositionType.BOTTOM, _("Unamplified"));
        volume_scale.add_mark (80, Gtk.PositionType.BOTTOM, _("100%"));

        volume_switch = new Gtk.Switch () {
            valign = START
        };

        level_bar = new Gtk.LevelBar.for_interval (0.0, 1.0);
        level_bar.get_style_context ().add_class ("inverted");

        level_bar.add_offset_value ("low", 0.8);
        level_bar.add_offset_value ("high", 0.95);
        level_bar.add_offset_value ("full", 1.0);

        var volume_grid = new Gtk.Grid () {
            column_spacing = 12,
            row_spacing = 3
        };
        volume_grid.attach (volume_label, 0, 0);
        volume_grid.attach (level_bar, 0, 1);
        volume_grid.attach (volume_scale, 0, 2);
        volume_grid.attach (volume_switch, 1, 1, 1, 2);

        orientation = VERTICAL;
        spacing = 18;
        add (devices_frame);
        add (volume_grid);

        device_monitor = new InputDeviceMonitor ();
        device_monitor.update_fraction.connect ((fraction) => {
            level_bar.value = fraction;
        });

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
                if (volume_switch.active == default_device.is_muted) {
                    volume_switch.activate ();
                }
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
                if (volume_switch.active == default_device.is_muted) {
                    volume_switch.activate ();
                }
                break;
            case "volume":
                volume_scale.set_value (default_device.volume);
                break;
        }

        connect_signals ();
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
