/*
* SPDX-License-Identifier: LGPL-3.0-or-later
* SPDX-FileCopyrightText: 2023 elementary, Inc. (https://elementary.io)
*
* Authored by: Leonhard Kargl <leo.kargl@proton.me>
*/

public class Sound.AppRow : Gtk.Grid {
    private App? app;
    private Gtk.Label app_name_label;
    private Gtk.Label media_name_label;
    private Gtk.Image image;
    private Gtk.Button icon_button;
    private Gtk.Scale volume_scale;
    private Gtk.Switch mute_switch;

    construct {
        image = new Gtk.Image () {
            pixel_size = 48
        };

        app_name_label = new Gtk.Label ("") {
            ellipsize = END,
            valign = END,
            xalign = 0
        };
        app_name_label.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);

        media_name_label = new Gtk.Label ("") {
            ellipsize = END,
            valign = END,
            xalign = 0
        };
        media_name_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        icon_button = new Gtk.Button.from_icon_name ("audio-volume-muted") {
            can_focus = false
        };
        icon_button.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

        volume_scale = new Gtk.Scale.with_range (HORIZONTAL, 0, 1, 0.01) {
            hexpand = true,
            draw_value = false
        };

        mute_switch = new Gtk.Switch () {
            halign = CENTER,
            valign = CENTER
        };

        hexpand = true;
        column_spacing = 6;
        margin_top = 6;
        margin_end = 6;
        margin_bottom = 6;
        margin_start = 6;

        attach (image, 0, 0, 1, 3);
        attach (app_name_label, 1, 0, 2);
        attach (media_name_label, 1, 1, 2);
        attach (icon_button, 1, 2);
        attach (volume_scale, 2, 2);
        attach (mute_switch, 3, 0, 1, 3);

        volume_scale.change_value.connect ((type, new_value) => {
            if (app != null) {
                PulseAudioManager.get_default ().change_application_volume (app, new_value.clamp (0, 1));
            }

            return true;
        });

        icon_button.clicked.connect (() => toggle_mute_application ());

        mute_switch.state_set.connect ((state) => {
            toggle_mute_application (!state);
            return true;
        });
    }

    private void toggle_mute_application (bool? custom = null) {
        if (app == null) {
            return;
        }

        PulseAudioManager.get_default ().mute_application (app, custom != null ? custom : !app.muted);
    }

    private void update () {
        media_name_label.label = media_name_label.tooltip_text = app.media_name;
        volume_scale.set_value (app.volume);
        mute_switch.state = !app.muted;
        volume_scale.sensitive = !app.muted;

        if (app.muted) {
            ((Gtk.Image) icon_button.image).icon_name = "audio-volume-muted";
        } else if (volume_scale.get_value () < 0.33) {
            ((Gtk.Image) icon_button.image).icon_name = "audio-volume-low";
        } else if (volume_scale.get_value () > 0.66) {
            ((Gtk.Image) icon_button.image).icon_name = "audio-volume-high";
        } else {
            ((Gtk.Image) icon_button.image).icon_name = "audio-volume-medium";
        }
    }

    public void bind_app (App app) {
        this.app = app;

        app_name_label.label = app.display_name;
        image.set_from_gicon (app.icon, Gtk.IconSize.DND);

        app.notify["volume"].connect (update);
        app.notify["muted"].connect (update);

        volume_scale.set_value (app.volume);
    }

    public void unbind_app () {
        app.notify["volume"].disconnect (update);
        app.notify["muted"].disconnect (update);
    }
}
