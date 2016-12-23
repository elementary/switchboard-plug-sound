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

public class Sound.PulseAudioManager : GLib.Object {
    private static PulseAudioManager pam;
    public static unowned PulseAudioManager get_default () {
        if (pam == null) {
            pam = new PulseAudioManager ();
        }

        return pam;
    }

    public signal void new_device (Device dev);

    private PulseAudio.GLibMainLoop loop;
    private PulseAudio.Context context;
    private bool is_ready = false;
    private uint reconnect_timer_id = 0U;
    private HashTable<uint32, Device> input_devices;
    private HashTable<uint32, Device> output_devices;
    private unowned Device default_output;
    private unowned Device default_input;
    private string default_source_name;
    private string default_sink_name;

    private PulseAudioManager () {
        
    }

    construct {
        loop = new PulseAudio.GLibMainLoop ();
        input_devices = new HashTable<uint32, Device> (direct_hash, direct_equal);
        output_devices = new HashTable<uint32, Device> (direct_hash, direct_equal);
    }

    public void start () {
        reconnect_to_pulse.begin ();
    }

    public void set_default_device (Device device) {
        if (device.input) {
            default_source_name = device.name;
            var ope = context.set_default_source (device.name, null);
            if (ope != null) {
                PulseAudio.ext_stream_restore_read (context, ext_stream_restore_read_source_callback);
            }
        } else {
            default_sink_name = device.name;
            var ope = context.set_default_sink (device.name, null);
            if (ope != null) {
                PulseAudio.ext_stream_restore_read (context, ext_stream_restore_read_sink_callback);
            }
        }
    }

    private bool reconnect_timeout () {
        reconnect_timer_id = 0U;
        reconnect_to_pulse.begin ();
        return false; // G_SOURCE_REMOVE
    }

    private async void reconnect_to_pulse () {
        if (is_ready) {
            context.disconnect ();
            context = null;
            is_ready = false;
        }

        var props = new PulseAudio.Proplist ();
        props.sets (PulseAudio.Proplist.PROP_APPLICATION_NAME, "Switchboard sound");
        props.sets (PulseAudio.Proplist.PROP_APPLICATION_ID, "org.pantheon.switchboard.plug.sound");
        props.sets (PulseAudio.Proplist.PROP_APPLICATION_ICON_NAME, "multimedia-volume-control");
        props.sets (PulseAudio.Proplist.PROP_APPLICATION_VERSION, "0.1");

        context = new PulseAudio.Context (loop.get_api (), null, props);
        context.set_state_callback (context_state_callback);

        if (context.connect(null, PulseAudio.Context.Flags.NOFAIL, null) < 0) {
            warning ("pa_context_connect() failed: %s\n", PulseAudio.strerror(context.errno()));
        }
    }

    private void ext_stream_restore_read_sink_callback (PulseAudio.Context c, PulseAudio.ExtStreamRestoreInfo? info, int eol) {
        if (eol != 0 || !info.name.has_prefix ("sink-input-by")) {
            return;
        }

        // We need to duplicate the info but with the right device name
        var new_info = PulseAudio.ExtStreamRestoreInfo ();
        new_info.name = info.name;
        new_info.channel_map = info.channel_map;
        new_info.volume = info.volume;
        new_info.mute = info.mute;
        new_info.device = default_sink_name;
        PulseAudio.ext_stream_restore_write (c, PulseAudio.UpdateMode.REPLACE, {new_info}, 1, null);
    }

    private void ext_stream_restore_read_source_callback (PulseAudio.Context c, PulseAudio.ExtStreamRestoreInfo? info, int eol) {
        if (eol != 0 || !info.name.has_prefix ("source-output-by")) {
            return;
        }

        // We need to duplicate the info but with the right device name
        var new_info = PulseAudio.ExtStreamRestoreInfo ();
        new_info.name = info.name;
        new_info.channel_map = info.channel_map;
        new_info.volume = info.volume;
        new_info.mute = info.mute;
        new_info.device = default_source_name;
        PulseAudio.ext_stream_restore_write (c, PulseAudio.UpdateMode.REPLACE, {new_info}, 1, null);
    }

    private void context_state_callback (PulseAudio.Context c) {
        switch (c.get_state ()) {
            case PulseAudio.Context.State.READY:
                c.set_subscribe_callback (subscribe_callback);
                c.subscribe (PulseAudio.Context.SubscriptionMask.SERVER |
                        PulseAudio.Context.SubscriptionMask.SINK_INPUT |
                        PulseAudio.Context.SubscriptionMask.SOURCE_OUTPUT);
                context.get_server_info (server_info_callback);
                is_ready = true;
                break;

            case PulseAudio.Context.State.FAILED:
            case PulseAudio.Context.State.TERMINATED:
                if (reconnect_timer_id == 0U)
                    reconnect_timer_id = Timeout.add_seconds (2, reconnect_timeout);
                break;

            default:
                is_ready = false;
                break;
        }
    }


    private void subscribe_callback (PulseAudio.Context c, PulseAudio.Context.SubscriptionEventType t, uint32 index) {
        switch (t & PulseAudio.Context.SubscriptionEventType.FACILITY_MASK) {
            case PulseAudio.Context.SubscriptionEventType.SINK:
                //TODO
                break;

            case PulseAudio.Context.SubscriptionEventType.SINK_INPUT:
                switch (t & PulseAudio.Context.SubscriptionEventType.TYPE_MASK) {
                    case PulseAudio.Context.SubscriptionEventType.NEW:
                        //c.get_sink_input_info (index, handle_new_sink_input_cb);
                        break;

                    case PulseAudio.Context.SubscriptionEventType.CHANGE:
                        //c.get_sink_input_info (index, handle_changed_sink_input_cb);
                        break;

                    case PulseAudio.Context.SubscriptionEventType.REMOVE:
                        //remove_sink_input_from_list (index);
                        break;
                    default:
                        debug ("Sink input event not known.");
                        break;
                }
                break;

            case PulseAudio.Context.SubscriptionEventType.SOURCE:
                //TODO
                break;

            case PulseAudio.Context.SubscriptionEventType.SOURCE_OUTPUT:
                switch (t & PulseAudio.Context.SubscriptionEventType.TYPE_MASK) {
                    case PulseAudio.Context.SubscriptionEventType.NEW:
                        //c.get_source_output_info (index, source_output_info_cb);
                        break;

                    case PulseAudio.Context.SubscriptionEventType.REMOVE:
                        //this.active_mic = false;
                        break;
                }
                break;
        }
    }

    private void source_info_callback (PulseAudio.Context c, PulseAudio.SourceInfo? i, int eol) {
        if (i == null)
            return;

        // completely ignore monitors, they're not real sources
        if (i.monitor_of_sink != PulseAudio.INVALID_INDEX) {
            return;
        }

        Device device = null;
        if (input_devices.contains (i.index)) {
            device = input_devices.get (i.index);
            //TODO: do things
        } else {
            device = new Device (i.index);
            device.input = true;
            device.name = i.name;
            device.display_name = i.description;

            var form_factor = i.proplist.gets (PulseAudio.Proplist.PROP_DEVICE_FORM_FACTOR);
            if (form_factor != null) {
                device.form_factor = form_factor;
            }

            device.is_default = i.name == default_source_name;
            input_devices.insert (i.index, device);
            default_output = device;
            new_device (device);
        }
    }

    private void sink_info_callback (PulseAudio.Context c, PulseAudio.SinkInfo? i, int eol) {
        if (i == null)
            return;

        Device device = null;
        if (output_devices.contains (i.index)) {
            device = output_devices.get (i.index);
            //TODO: do things
        } else {
            device = new Device (i.index);
            device.input = false;
            device.name = i.name;
            device.display_name = i.description;

            var form_factor = i.proplist.gets (PulseAudio.Proplist.PROP_DEVICE_FORM_FACTOR);
            if (form_factor != null) {
                device.form_factor = form_factor;
            }

            device.is_default = i.name == default_sink_name;
            output_devices.insert (i.index, device);
            default_input = device;
            new_device (device);
        }
    }

    private void server_info_callback (PulseAudio.Context c, PulseAudio.ServerInfo? i) {
        if (i == null)
            return;

        default_source_name = i.default_source_name;
        default_sink_name = i.default_sink_name;
        context.get_sink_info_list (sink_info_callback);
        context.get_source_info_list (source_info_callback);
    }
}
