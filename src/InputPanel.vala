// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2016-2017 elemntary LLC. (https://elementary.io)
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
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 * Authored by: Corentin Noël <corentin@elementary.io>
 */

public class Sound.InputPanel : Gtk.Grid {
    private Gtk.ListBox devices_listbox;
    private unowned PulseAudioManager pam;

    public InputPanel () {
        
    }

    construct {
        margin = 12;
        margin_top = 0;
        column_spacing = 12;
        row_spacing = 6;
        var available_label = new Gtk.Label (_("Available Sound Input Devices:"));
        available_label.get_style_context ().add_class ("h4");
        available_label.halign = Gtk.Align.START;
        devices_listbox = new Gtk.ListBox ();
        var scrolled = new Gtk.ScrolledWindow (null, null);
        scrolled.add (devices_listbox);
        var devices_frame = new Gtk.Frame (null);
        devices_frame.expand = true;
        devices_frame.add (scrolled);
        var volume_label = new Gtk.Label (_("Input Volume:"));
        volume_label.halign = Gtk.Align.END;
        var volume_scale = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 0, 100, 5);
        volume_scale.draw_value = false;
        volume_scale.hexpand = true;
        volume_scale.add_mark (10, Gtk.PositionType.BOTTOM, _("Unamplified"));
        volume_scale.add_mark (80, Gtk.PositionType.BOTTOM, _("100%"));
        var volume_switch = new Gtk.Switch ();
        volume_switch.valign = Gtk.Align.CENTER;
        var level_label = new Gtk.Label (_("Input Level:"));
        level_label.halign = Gtk.Align.END;
        var level_bar = new Gtk.LevelBar ();

        var no_device_grid = new Granite.Widgets.AlertView (_("No Input Device"), _("There is no input device detected. You might want to add one to start recording anything."), "audio-input-microphone-symbolic");
        no_device_grid.show_all ();
        devices_listbox.set_placeholder (no_device_grid);

        attach (available_label, 0, 0, 3, 1);
        attach (devices_frame, 0, 1, 3, 1);
        attach (volume_label, 0, 2, 1, 1);
        attach (volume_scale, 1, 2, 1, 1);
        attach (volume_switch, 2, 2, 1, 1);
        attach (level_label, 0, 3, 1, 1);
        attach (level_bar, 1, 3, 2, 1);

        pam = PulseAudioManager.get_default ();
    }

}
