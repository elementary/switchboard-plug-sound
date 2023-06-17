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

    unowned Canberra.Context? ca_context = null;

    uint notify_timeout_id = 0;
    public bool screen_reader_active { get; set; }

    construct {
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
            expand = true,
            margin_bottom = 18
        };

        devices_frame.add (scrolled);

        var volume_label = new Gtk.Label (_("Output volume:")) {
            halign = Gtk.Align.END
        };

        volume_scale = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 0, 100, 5) {
            draw_value = false,
            hexpand = true
        };
        volume_scale.adjustment.page_increment = 5;

        volume_scale.button_release_event.connect (e => {
            notify_change ();
            return false;
        });

        volume_scale.scroll_event.connect (e => {
            if (volume_scale.get_value () < 100) {
                notify_change ();
            }
            return false;
        });

        volume_switch = new Gtk.Switch () {
            valign = Gtk.Align.CENTER,
            active = true
        };

        var balance_label = new Gtk.Label (_("Balance:")) {
            valign = Gtk.Align.START,
            halign = Gtk.Align.END,
            margin_bottom = 18
        };

        balance_scale = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, -1, 1, 0.1) {
            draw_value = false,
            has_origin = false,
            margin_bottom = 18
        };

        balance_scale.adjustment.page_increment = 0.1;

        balance_scale.add_mark (-1, Gtk.PositionType.BOTTOM, _("Left"));
        balance_scale.add_mark (0, Gtk.PositionType.BOTTOM, _("Center"));
        balance_scale.add_mark (1, Gtk.PositionType.BOTTOM, _("Right"));

        var alerts_label = new Gtk.Label (_("Event alerts:")) {
            halign = Gtk.Align.END,
        };

        var audio_alert_check = new Gtk.CheckButton.with_label (_("Play sound"));

        var visual_alert_check = new Gtk.CheckButton.with_label (_("Flash screen")) {
            halign = Gtk.Align.START,
            hexpand = true
        };

        var alerts_info = new Gtk.Label (_("Event alerts occur when the system cannot do something in response to user input, like attempting to backspace in an empty input or switch windows when only one is open.")) {
            max_width_chars = 80,
            wrap = true,
            xalign = 0
        };

        alerts_info.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        var test_button = new Gtk.ToggleButton.with_label (_("Test Speakers…")) {
            halign = Gtk.Align.END,
            margin_top = 18
        };

        var screen_reader_label = new Gtk.Label (_("Screen Reader:")) {
            halign = Gtk.Align.END,
            xalign = 1
        };

        var screen_reader_switch = new Gtk.Switch () {
            halign = Gtk.Align.START,
            hexpand = true
        };

        var screen_reader_description_label = new Gtk.Label (_("Provide audio descriptions for items on the screen")) {
            max_width_chars = 60,
            wrap = true,
            xalign = 0
        };

        screen_reader_description_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        var test_popover = new TestPopover (test_button);
        test_button.bind_property ("active", test_popover, "visible", GLib.BindingFlags.BIDIRECTIONAL);

        var no_device_grid = new Granite.Widgets.AlertView (_("No Output Device"), _("There is no output device detected. You might want to add one to start listening to anything."), "audio-volume-muted-symbolic");
        no_device_grid.show_all ();
        devices_listbox.set_placeholder (no_device_grid);

        attach (devices_frame, 0, 1, 4, 1);
        attach (volume_label, 0, 2);
        attach (volume_scale, 1, 2, 2);
        attach (volume_switch, 3, 2);
        attach (balance_label, 0, 3);
        attach (balance_scale, 1, 3, 2);
        attach (alerts_label, 0, 4);
        attach (audio_alert_check, 1, 4);
        attach (visual_alert_check, 2, 4);
        attach (alerts_info, 1, 5, 2);
        attach (screen_reader_label, 0, 6);
        attach (screen_reader_switch, 1, 6, 2);
        attach (screen_reader_description_label, 1, 7, 2);
        attach (test_button, 0, 8, 4);

        var applications_settings = new GLib.Settings ("org.gnome.desktop.a11y.applications");
        applications_settings.bind ("screen-reader-enabled", this, "screen_reader_active", SettingsBindFlags.DEFAULT);
        bind_property ("screen_reader_active", screen_reader_switch, "active", GLib.BindingFlags.BIDIRECTIONAL, () => {
            if (screen_reader_active != screen_reader_switch.active) {
                screen_reader_switch.activate ();
            }
        }, null);

        pam = PulseAudioManager.get_default ();
        pam.new_device.connect (add_device);
        pam.notify["default-output"].connect (default_changed);

        volume_switch.bind_property ("active", volume_scale, "sensitive", BindingFlags.DEFAULT);
        volume_switch.bind_property ("active", balance_scale, "sensitive", BindingFlags.DEFAULT);

        var sound_settings = new Settings ("org.gnome.desktop.sound");
        sound_settings.bind ("event-sounds", audio_alert_check, "active", GLib.SettingsBindFlags.DEFAULT);

        var wm_settings = new Settings ("org.gnome.desktop.wm.preferences");
        wm_settings.bind ("visual-bell", visual_alert_check, "active", GLib.SettingsBindFlags.DEFAULT);

        ca_context = CanberraGtk.context_get ();
        var locale = Intl.setlocale (LocaleCategory.MESSAGES, null);
        ca_context.change_props (Canberra.PROP_APPLICATION_NAME, "switchboard-plug-sound",
                                Canberra.PROP_APPLICATION_ID, "io.elementary.switchboard.sound",
                                Canberra.PROP_APPLICATION_LANGUAGE, locale,
                                null);
        ca_context.open ();
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
                if (volume_switch.active == default_device.is_muted) {
                    volume_switch.activate ();
                }
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
                if (volume_switch.active == default_device.is_muted) {
                    volume_switch.activate ();
                }
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

    private void notify_change () {
        if (notify_timeout_id > 0) {
            return;
        }

        notify_timeout_id = Timeout.add (50, () => {
            Canberra.Proplist props;
            Canberra.Proplist.create (out props);
            props.sets (Canberra.PROP_CANBERRA_CACHE_CONTROL, "volatile");
            props.sets (Canberra.PROP_EVENT_ID, "audio-volume-change");
            ca_context.play_full (0, props);

            notify_timeout_id = 0;
            return false;
        });
    }
}
