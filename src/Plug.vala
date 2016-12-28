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

public class Sound.Plug : Switchboard.Plug {
    Gtk.Grid main_grid;
    Gtk.Stack stack;

    InputPanel input_panel;

    public Plug () {
        var settings = new Gee.TreeMap<string, string?> (null, null);
        settings.set ("sound", "null");
        settings.set ("sound/input", "input");
        settings.set ("sound/output", "output");
        Object (category: Category.HARDWARE,
                code_name: "hardware-pantheon-sound",
                display_name: _("Sound"),
                description: _("Change sound and microphone volume"),
                icon: "preferences-desktop-sound",
                supported_settings: settings);
    }

    public override Gtk.Widget get_widget () {
        if (main_grid == null) {
            var output_panel = new OutputPanel ();
            input_panel = new InputPanel ();

            stack = new Gtk.Stack ();
            stack.expand = true;
            var stack_switcher = new Gtk.StackSwitcher ();
            stack_switcher.margin = 12;
            stack_switcher.halign = Gtk.Align.CENTER;
            stack_switcher.set_stack (stack);

            stack.add_titled (output_panel, "output", _("Output"));
            stack.add_titled (input_panel, "input", _("Input"));

            stack.notify["visible-child"].connect (() => {
                input_panel.set_visibility (stack.visible_child == input_panel);
            });

            main_grid = new Gtk.Grid ();
            main_grid.orientation = Gtk.Orientation.VERTICAL;
            main_grid.add (stack_switcher);
            main_grid.add (stack);
            main_grid.show_all ();

            var pam = PulseAudioManager.get_default ();
            pam.start ();
        }

        return main_grid;
    }

    public override void shown () {
        main_grid.show ();
        if (stack.visible_child == input_panel) {
            input_panel.set_visibility (true);
        }
    }

    public override void hidden () {
        main_grid.hide ();
        input_panel.set_visibility (false);
    }

    public override void search_callback (string location) {
        switch (location) {
            case "input":
                stack.set_visible_child_name ("input");
                break;
            case "output":
                stack.set_visible_child_name ("output");
                break;
        }
    }

    // 'search' returns results like ("Keyboard → Behavior → Duration", "keyboard<sep>behavior")
    public override async Gee.TreeMap<string, string> search (string search) {
        var search_results = new Gee.TreeMap<string, string> ((GLib.CompareDataFunc<string>)strcmp, (Gee.EqualDataFunc<string>)str_equal);
        return search_results;
    }
}


public Switchboard.Plug get_plug (Module module) {
    debug ("Activating Sound plug");
    var plug = new Sound.Plug ();
    return plug;
}
