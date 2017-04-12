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

public class Sound.TestPopover : Gtk.Popover {
    private Gtk.Grid main_grid;
    private Device default_device;

    public TestPopover (Gtk.ToggleButton relative_to) {
        Object (relative_to: relative_to);
    }

    construct {
        main_grid = new Gtk.Grid ();
        main_grid.margin = 12;
        main_grid.column_spacing = 6;
        main_grid.row_spacing = 6;
        var me = new Granite.Widgets.Avatar.with_default_icon (48);
        main_grid.attach (me, 2, 1, 1, 1);
        main_grid.show_all ();
        add (main_grid);

        unowned PulseAudioManager pam = PulseAudioManager.get_default ();
        pam.notify["default-output"].connect (() => {
            default_changed ();
        });

        var icon_theme = Gtk.IconTheme.get_default ();
        icon_theme.add_resource_path ("/io/elementary/switchboard/sound/icons/");
    }

    private void create_position_button (PulseAudio.ChannelPosition pa_position) {
        var button = new PositionButton (pa_position);
        switch (pa_position) {
            case PulseAudio.ChannelPosition.FRONT_LEFT:
                main_grid.attach (button, 0, 0, 1, 1);
                break;
            case PulseAudio.ChannelPosition.FRONT_RIGHT:
                main_grid.attach (button, 4, 0, 1, 1);
                break;
            case PulseAudio.ChannelPosition.FRONT_CENTER:
                main_grid.attach (button, 2, 0, 1, 1);
                break;
            case PulseAudio.ChannelPosition.REAR_LEFT:
                main_grid.attach (button, 0, 2, 1, 1);
                break;
            case PulseAudio.ChannelPosition.REAR_RIGHT:
                main_grid.attach (button, 4, 2, 1, 1);
                break;
            case PulseAudio.ChannelPosition.REAR_CENTER:
                main_grid.attach (button, 2, 2, 1, 1);
                break;
            case PulseAudio.ChannelPosition.LFE:
                main_grid.attach (button, 3, 2, 1, 1);
                break;
            case PulseAudio.ChannelPosition.SIDE_LEFT:
                main_grid.attach (button, 0, 1, 1, 1);
                break;
            case PulseAudio.ChannelPosition.SIDE_RIGHT:
                main_grid.attach (button, 4, 1, 1, 1);
                break;
            case PulseAudio.ChannelPosition.FRONT_LEFT_OF_CENTER:
                main_grid.attach (button, 1, 0, 1, 1);
                break;
            case PulseAudio.ChannelPosition.FRONT_RIGHT_OF_CENTER:
                main_grid.attach (button, 3, 0, 1, 1);
                break;
            case PulseAudio.ChannelPosition.MONO:
                main_grid.attach (button, 2, 0, 1, 1);
                break;
        }
    }

    private void default_changed () {
        if (default_device != null) {
            default_device.notify.disconnect (device_notify);
            clear_buttons ();
        }

        unowned PulseAudioManager pam = PulseAudioManager.get_default ();
        default_device = pam.default_output;
        default_device.notify.connect (device_notify);
        add_buttons ();
    }

    private void device_notify (ParamSpec pspec) {
        switch (pspec.get_name ()) {
            case "channel-positions":
                clear_buttons ();
                add_buttons ();
                break;
        }
    }

    private void clear_buttons () {
        main_grid.get_children ().foreach ((child) => {
            if (child is PositionButton) {
                child.destroy ();
            }
        });
    }

    private void add_buttons () {
        foreach (var position in default_device.channel_map.map) {
            if (position > 0 && position < PulseAudio.ChannelPosition.MAX) {
                create_position_button (position);
            }
        }

        main_grid.show_all ();
    }

    public class PositionButton : Gtk.Button {
        public PulseAudio.ChannelPosition pa_position { get; construct; }
        private bool playing = false;
        public PositionButton (PulseAudio.ChannelPosition pa_position) {
            Object (pa_position: pa_position);
            image = new Gtk.Image.from_icon_name (get_icon (), Gtk.IconSize.DIALOG);
            ((Gtk.Image) image).pixel_size = 48;
        }

        construct {
            get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
        }

        private string get_icon () {
            switch (pa_position) {
                case PulseAudio.ChannelPosition.FRONT_LEFT:
                    return playing ? "audio-speaker-left-testing" : "audio-speaker-left";
                case PulseAudio.ChannelPosition.FRONT_RIGHT:
                    return playing ? "audio-speaker-right-testing" : "audio-speaker-right";
                case PulseAudio.ChannelPosition.FRONT_CENTER:
                    return playing ? "audio-speaker-center-testing" : "audio-speaker-center";
                case PulseAudio.ChannelPosition.REAR_LEFT:
                    return playing ? "audio-speaker-left-back-testing" : "audio-speaker-left-back";
                case PulseAudio.ChannelPosition.REAR_RIGHT:
                    return playing ? "audio-speaker-right-back-testing" : "audio-speaker-right-back";
                case PulseAudio.ChannelPosition.REAR_CENTER:
                    return playing ? "audio-speaker-center-back-testing" : "audio-speaker-center-back";
                case PulseAudio.ChannelPosition.LFE:
                    return playing ? "audio-subwoofer-testing" : "audio-subwoofer";
                case PulseAudio.ChannelPosition.SIDE_LEFT:
                    return playing ? "audio-speaker-left-side-testing" : "audio-speaker-left-side";
                case PulseAudio.ChannelPosition.SIDE_RIGHT:
                    return playing ? "audio-speaker-right-side-testing" : "audio-speaker-right-side";
                case PulseAudio.ChannelPosition.FRONT_LEFT_OF_CENTER:
                    return playing ? "audio-speaker-front-left-of-center-testing" : "audio-speaker-front-left-of-center";
                case PulseAudio.ChannelPosition.FRONT_RIGHT_OF_CENTER:
                    return playing ? "audio-speaker-front-right-of-center-testing" : "audio-speaker-front-right-of-center";
                case PulseAudio.ChannelPosition.MONO:
                    return playing ? "audio-speaker-mono-testing" : "audio-speaker-mono";
                default:
                    return "audio-speaker-mono";
            }
        }

        private string get_sound_name () {
            switch (pa_position) {
                case PulseAudio.ChannelPosition.FRONT_LEFT:
                    return "audio-channel-front-left";
                case PulseAudio.ChannelPosition.FRONT_RIGHT:
                    return "audio-channel-front-right";
                case PulseAudio.ChannelPosition.FRONT_CENTER:
                    return "audio-channel-front-center";
                case PulseAudio.ChannelPosition.REAR_LEFT:
                    return "audio-channel-rear-left";
                case PulseAudio.ChannelPosition.REAR_RIGHT:
                    return "audio-channel-rear-right";
                case PulseAudio.ChannelPosition.REAR_CENTER:
                    return "audio-channel-rear-center";
                case PulseAudio.ChannelPosition.LFE:
                    return "audio-channel-lfe";
                case PulseAudio.ChannelPosition.SIDE_LEFT:
                    return "audio-channel-side-left";
                case PulseAudio.ChannelPosition.SIDE_RIGHT:
                    return "audio-channel-side-right";
                case PulseAudio.ChannelPosition.FRONT_LEFT_OF_CENTER:
                    return "audio-channel-front-left-of-center";
                case PulseAudio.ChannelPosition.FRONT_RIGHT_OF_CENTER:
                    return "audio-channel-front-right-of-center";
                case PulseAudio.ChannelPosition.MONO:
                    return "audio-channel-mono";
                default:
                    return "audio-test-signal";
            }
        }

        private string get_pretty_position () {
            if (pa_position == PulseAudio.ChannelPosition.LFE)
                return "Subwoofer";

            return pa_position.to_pretty_string ();
        }

        public override void clicked () {
            playing = true;
            ((Gtk.Image) image).icon_name = get_icon ();
            Canberra.Proplist proplist;
            Canberra.Proplist.create (out proplist);
            proplist.sets (Canberra.PROP_MEDIA_ROLE, "test");
            proplist.sets (Canberra.PROP_MEDIA_NAME, get_pretty_position ());
            proplist.sets (Canberra.PROP_CANBERRA_FORCE_CHANNEL, pa_position.to_string ());
            proplist.sets (Canberra.PROP_CANBERRA_ENABLE, "1");
            proplist.sets (Canberra.PROP_EVENT_ID, get_sound_name ());
            unowned Canberra.Context? canberra = CanberraGtk.context_get ();
            canberra.play_full (1, proplist, play_full_callback);
        }

        private void play_full_callback (Canberra.Context c, uint32 id, int code) {
            playing = false;
            ((Gtk.Image) image).icon_name = get_icon ();
        }
    }
}
