/*
 * SPDX-License-Identifier: LGPL-2.0-or-later
 * SPDX-FileCopyrightText: 2016-2023 elementary, Inc. (https://elementary.io)
 *
 * Authored by: Corentin Noël <corentin@elementary.io>
 */

public class Sound.OutputPanel : Gtk.Box {
    public bool screen_reader_active { get; set; }

    private Device default_device = null;
    private Gtk.ListBox devices_listbox;
    private Gtk.Scale balance_scale;
    private Gtk.Scale volume_scale;
    private Gtk.Switch volume_switch;
    private uint notify_timeout_id = 0;
    private unowned Canberra.Context? ca_context = null;
    private unowned PulseAudioManager pam;

    construct {
        var no_device_grid = new Granite.Widgets.AlertView (
            _("No Connected Output Devices Detected"),
            _("Check that all cables are securely attached and audio output devices are powered on."),
            "audio-volume-muted-symbolic"
        );
        no_device_grid.show_all ();

        devices_listbox = new Gtk.ListBox () {
            activate_on_single_click = true,
            vexpand = true
        };
        devices_listbox.set_placeholder (no_device_grid);

        var scrolled = new Gtk.ScrolledWindow (null, null) {
            child = devices_listbox
        };

        var devices_frame = new Gtk.Frame (null) {
            child = scrolled
        };

        var volume_label = new Granite.HeaderLabel (_("Volume"));

        volume_scale = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 0, 100, 5) {
            draw_value = false,
            hexpand = true
        };
        volume_scale.adjustment.page_increment = 5;

        volume_switch = new Gtk.Switch () {
            valign = Gtk.Align.CENTER,
            active = true
        };
        balance_scale = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, -1, 1, 0.1) {
            draw_value = false,
            has_origin = false
        };

        balance_scale.adjustment.page_increment = 0.1;

        balance_scale.add_mark (-1, Gtk.PositionType.BOTTOM, _("Left"));
        balance_scale.add_mark (0, Gtk.PositionType.BOTTOM, _("Center"));
        balance_scale.add_mark (1, Gtk.PositionType.BOTTOM, _("Right"));

        var alerts_label = new Granite.HeaderLabel (_("Event Alerts"));

        var audio_alert_check = new Gtk.CheckButton.with_label (_("Play sound")) {
            margin_top = 6
        };

        var visual_alert_check = new Gtk.CheckButton.with_label (_("Flash screen")) {
            margin_top = 6
        };

        var alerts_info = new Gtk.Label (
            _("Notify when the system can't do something in response to input, like attempting to backspace in an empty input or switch windows when only one is open.")
        ) {
            wrap = true,
            xalign = 0
        };

        alerts_info.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        var test_popover = new TestPopover ();

        var test_button = new Gtk.MenuButton () {
            halign = Gtk.Align.END,
            label = _("Test Speakers…"),
            popover = test_popover
        };

        var screen_reader_label = new Granite.HeaderLabel (_("Screen Reader"));

        var screen_reader_switch = new Gtk.Switch () {
            halign = END,
            valign = CENTER,
            hexpand = true
        };

        var screen_reader_description_label = new Gtk.Label (_("Provide audio descriptions for items on the screen")) {
            wrap = true,
            xalign = 0
        };
        screen_reader_description_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        var output_grid = new Gtk.Grid () {
            column_spacing = 12
        };
        output_grid.attach (volume_label, 0, 0, 2);
        output_grid.attach (volume_scale, 0, 1);
        output_grid.attach (volume_switch, 1, 1);
        output_grid.attach (balance_scale, 0, 2);

        var alerts_box = new Gtk.Box (VERTICAL, 0);
        alerts_box.add (alerts_label);
        alerts_box.add (alerts_info);
        alerts_box.add (audio_alert_check);
        alerts_box.add (visual_alert_check);

        var screen_reader_grid = new Gtk.Grid () {
            column_spacing = 12
        };
        screen_reader_grid.attach (screen_reader_label, 0, 0);
        screen_reader_grid.attach (screen_reader_description_label, 0, 1);
        screen_reader_grid.attach (screen_reader_switch, 1, 0, 1, 2);

        orientation = VERTICAL;
        spacing = 18;
        add (devices_frame);
        add (output_grid);
        add (alerts_box);
        add (screen_reader_grid);
        add (test_button);

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

        devices_listbox.row_activated.connect ((row) => {
            pam.set_default_device.begin (((Sound.DeviceRow) row).device);
        });

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

                balance_scale.sensitive = !default_device.is_muted;
                volume_scale.sensitive = !default_device.is_muted;
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
