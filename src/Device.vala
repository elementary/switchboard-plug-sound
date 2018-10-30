// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2016-2018 elementary LLC. (https://elementary.io)
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

// This is a read-only class, set the properties via PulseAudioManager.
public class Sound.Device : GLib.Object {
    public class Port {
        public string name;
        public string description;
        public uint32 priority;
    }

    public signal void removed ();

    // info from card and ports
    public bool input { get; set; default=true; }
    public string id { get; construct; }
    public string card_name { get; set; }
    public uint32 card_index { get; construct; }
    public string port_name { get; construct; }
    public string display_name { get; set; }
    public string form_factor { get; set; }
    public Gee.ArrayList<string> profiles { get; set; }
    public string card_active_profile_name { get; set; }
    // public Gee.ArrayList<Port> ports { get; set; }
    // public Port? default_port { get; set; default=null; }

    // sink info
    public string? sink_name { get; set; }
    public uint32? sink_index { get; set; }
    public string? card_sink_name { get; set; }
    public string? card_sink_port_name { get; set; }
    public uint32? card_sink_index { get; set; }

    // source info
    public string? source_name { get; set; }
    public uint32? source_index { get; set; }
    public string? card_source_name { get; set; }
    public string? card_source_port_name { get; set; }
    public uint32? card_source_index { get; set; }

    // info from source or sink
    public bool is_default { get; set; default=false; }
    public bool is_muted { get; set; default=false; }
    public PulseAudio.CVolume cvolume { get; set; }
    public double volume { get; set; default=0; }
    public float balance { get; set; default=0; }
    public PulseAudio.ChannelMap channel_map { get; set; }
    public Gee.LinkedList<PulseAudio.Operation> volume_operations;

    public Device (string id, uint32 card_index, string port_name) {
        Object (id: id, card_index: card_index, port_name: port_name);
    }

    construct {
        volume_operations = new Gee.LinkedList<PulseAudio.Operation> ();
        // ports = new Gee.ArrayList<Port> ();
    }

    public string get_nice_form_factor () {
        switch (form_factor) {
            case "internal":
                return _("Built-in");
            case "speaker":
                return _("Speaker");
            case "handset":
                return _("Handset");
            case "tv":
                return _("TV");
            case "webcam":
                return _("Webcam");
            case "microphone":
                return _("Microphone");
            case "headset":
                return _("Headset");
            case "headphone":
                return _("Headphone");
            case "hands-free":
                return _("Hands-Free");
            case "car":
                return _("Car");
            case "hifi":
                return _("HiFi");
            case "computer":
                return _("Computer");
            case "portable":
                return _("Portable");
            default:
                return input? _("Input") : _("Output");
        }

    }
}
