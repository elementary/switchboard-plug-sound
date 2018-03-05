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
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301 USA.
 *
 * Authored by: Corentin Noël <corentin@elementary.io>
 */

/*
 * Vocabulary of PulseAudio:
 *  - Source: Input (microphone)
 *  - Sink: Output (speaker)
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
    public signal void default_input_changed ();
    public signal void default_output_changed ();

    public PulseAudio.Context context { get; private set; }
    public bool has_echo_cancellation { get; private set; }
    private PulseAudio.GLibMainLoop loop;
    private bool is_ready = false;
    private uint reconnect_timer_id = 0U;
    private Gee.HashMap<uint32, Device> input_devices;
    private Gee.HashMap<uint32, Device> output_devices;
    private Device default_output;
    private Device default_input;
    private Device echo_cancel_output;
    private Device echo_cancel_input;
    private string default_source_name;
    private string default_sink_name;
    private Gee.HashMap<uint32, PulseAudio.Operation> volume_operations;
    private Gee.LinkedList<Device> parent_missing;

    private PulseAudioManager () {
        
    }

    construct {
        loop = new PulseAudio.GLibMainLoop ();
        input_devices = new Gee.HashMap<uint32, Device> ();
        output_devices = new Gee.HashMap<uint32, Device> ();
        volume_operations = new Gee.HashMap<uint32, PulseAudio.Operation> ();
        parent_missing = new Gee.LinkedList<Device> ();
        new_device.connect ((d) => {
            parent_missing.foreach ((device) => {
                associate_device_with_parent (device);
                return GLib.Source.CONTINUE;
            });
        });
    }

    public void start () {
        reconnect_to_pulse.begin ();
    }

    public void set_default_device (Device device, bool force = false) {
        if (device.input) {
            bool use_echo = input_uses_echo ();
            default_source_name = device.name;
            var ope = context.set_default_source (device.name, null);
            if (ope != null && use_echo && !force) {
                default_source_name = echo_cancel_input.name;
                ope = context.set_default_source (default_source_name, null);
            }

            if (ope != null) {
                PulseAudio.ext_stream_restore_read (context, ext_stream_restore_read_source_callback);
            }
        } else {
            bool use_echo = output_uses_echo ();
            default_sink_name = device.name;
            var ope = context.set_default_sink (device.name, null);
            if (ope != null && use_echo && !force) {
                default_sink_name = echo_cancel_output.name;
                ope = context.set_default_sink (default_sink_name, null);
            }

            if (ope != null) {
                PulseAudio.ext_stream_restore_read (context, ext_stream_restore_read_sink_callback);
            }
        }
    }

    public void change_device_mute (Device device, bool mute = true) {
        if (device.input) {
            context.set_source_mute_by_index (device.index, mute, null);
        } else {
            context.set_sink_mute_by_index (device.index, mute, null);
        }
    }

    public void change_device_volume (Device device, double volume) {
        device.volume_operations.foreach ((operation) => {
            if (operation.get_state () == PulseAudio.Operation.State.RUNNING) {
                operation.cancel ();
            }

            device.volume_operations.remove (operation);
            return GLib.Source.CONTINUE;
        });

        var cvol = device.cvolume;
        cvol.scale (double_to_volume (volume));
        PulseAudio.Operation? operation = null;
        if (device.input) {
            operation = context.set_source_volume_by_index (device.index, cvol, null);
        } else {
            operation = context.set_sink_volume_by_index (device.index, cvol, null);
        }

        if (operation != null) {
            device.volume_operations.add (operation);
        }
    }

    public void change_device_balance (Device device, float balance) {
        var cvol = device.cvolume;
        cvol = cvol.set_balance (device.channel_map, balance);
        PulseAudio.Operation? operation = null;
        if (device.input) {
            operation = context.set_source_volume_by_index (device.index, cvol, null);
        } else {
            operation = context.set_sink_volume_by_index (device.index, cvol, null);
        }

        if (operation != null) {
            device.volume_operations.add (operation);
        }
    }

    public Device get_real_default_input () {
        return get_topmost_input_device (default_input);
    }

    public Device get_real_default_output () {
        return get_topmost_output_device (default_output);
    }

    public bool input_uses_echo () {
        return default_input == echo_cancel_input;
    }

    public bool output_uses_echo () {
        return default_output == echo_cancel_output;
    }

    public void set_cancel_echo_input (bool cancel_echo) {
        set_default_device (cancel_echo ? echo_cancel_input : get_real_default_input (), true);
    }

    public void set_cancel_echo_output (bool cancel_echo) {
        set_default_device (cancel_echo ? echo_cancel_output : get_real_default_output (), true);
    }

    private Device get_topmost_input_device (Device d) {
        if (d.parent_device_name == null) {
            return d;
        }

        foreach (var device in input_devices) {
            if (device != null) {
                if (device.name == d.parent_device_name) {
                    return get_topmost_input_device (device);
                }
            }
        }

        return d;
    }

    private Device get_topmost_output_device (Device d) {
        if (d.parent_device_name == null) {
            return d;
        }

        foreach (var device in output_devices) {
            if (device != null) {
                if (device.name == d.parent_device_name) {
                    return get_topmost_output_device (device);
                }
            }
        }

        return d;
    }

    private void associate_device_with_parent (Device device) {
        if (device.input) {
            var topmost_device = get_topmost_input_device (device);
            if (device != topmost_device) {
                parent_missing.remove (device);
                if (device.is_default) {
                    topmost_device.is_default = true;
                    default_input_changed ();
                }
            }
        } else {
            var topmost_device = get_topmost_output_device (device);
            if (device != topmost_device) {
                parent_missing.remove (device);
                if (device.is_default) {
                    topmost_device.is_default = true;
                    default_output_changed ();
                }
            }
        }
    }

    /*
     * Private methods to connect to the PulseAudio async interface
     */

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
        props.sets (PulseAudio.Proplist.PROP_APPLICATION_ID, "org.pantheon.switchboard.plug.sound");
        context = new PulseAudio.Context (loop.get_api (), null, props);
        context.set_state_callback (context_state_callback);

        if (context.connect (null, PulseAudio.Context.Flags.NOFAIL, null) < 0) {
            warning ("pa_context_connect() failed: %s\n", PulseAudio.strerror (context.errno ()));
        }
    }

    private void context_state_callback (PulseAudio.Context c) {
        switch (c.get_state ()) {
            case PulseAudio.Context.State.READY:
                c.set_subscribe_callback (subscribe_callback);
                c.subscribe (PulseAudio.Context.SubscriptionMask.SERVER |
                        PulseAudio.Context.SubscriptionMask.SINK |
                        PulseAudio.Context.SubscriptionMask.SOURCE |
                        PulseAudio.Context.SubscriptionMask.SINK_INPUT |
                        PulseAudio.Context.SubscriptionMask.SOURCE_OUTPUT |
                        PulseAudio.Context.SubscriptionMask.MODULE);
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

    /*
     * This is the main signal callback
     */

    private void subscribe_callback (PulseAudio.Context c, PulseAudio.Context.SubscriptionEventType t, uint32 index) {
        var source_type = t & PulseAudio.Context.SubscriptionEventType.FACILITY_MASK;
        switch (source_type) {
            case PulseAudio.Context.SubscriptionEventType.SINK:
            case PulseAudio.Context.SubscriptionEventType.SINK_INPUT:
                var event_type = t & PulseAudio.Context.SubscriptionEventType.TYPE_MASK;
                switch (event_type) {
                    case PulseAudio.Context.SubscriptionEventType.NEW:
                        c.get_sink_info_by_index (index, sink_info_callback);
                        break;

                    case PulseAudio.Context.SubscriptionEventType.CHANGE:
                        c.get_sink_info_by_index (index, sink_info_callback);
                        break;

                    case PulseAudio.Context.SubscriptionEventType.REMOVE:
                        var device = output_devices.get (index);
                        if (device != null) {
                            device.removed ();
                            output_devices.unset (index);
                        }

                        break;
                }

                break;

            case PulseAudio.Context.SubscriptionEventType.SERVER:
                context.get_server_info (server_info_callback);
                break;

            case PulseAudio.Context.SubscriptionEventType.SOURCE:
            case PulseAudio.Context.SubscriptionEventType.SOURCE_OUTPUT:
                var event_type = t & PulseAudio.Context.SubscriptionEventType.TYPE_MASK;
                switch (event_type) {
                    case PulseAudio.Context.SubscriptionEventType.NEW:
                        c.get_source_info_by_index (index, source_info_callback);
                        break;

                    case PulseAudio.Context.SubscriptionEventType.CHANGE:
                        c.get_source_info_by_index (index, source_info_callback);
                        break;

                    case PulseAudio.Context.SubscriptionEventType.REMOVE:
                        var device = input_devices.get (index);
                        if (device != null) {
                            device.removed ();
                            input_devices.unset (index);
                        }

                        break;
                }

                break;

            case PulseAudio.Context.SubscriptionEventType.MODULE:
                var event_type = t & PulseAudio.Context.SubscriptionEventType.TYPE_MASK;
                switch (event_type) {
                    case PulseAudio.Context.SubscriptionEventType.NEW:
                    case PulseAudio.Context.SubscriptionEventType.CHANGE:
                        c.get_module_info (index, module_info_callback);
                        break;

                    case PulseAudio.Context.SubscriptionEventType.REMOVE:
                        c.get_module_info (index, module_info_remove_callback);

                        break;
                }

                break;
        }
    }

    /*
     * Retrieve object informations
     */

    private void source_info_callback (PulseAudio.Context c, PulseAudio.SourceInfo? i, int eol) {
        if (i == null)
            return;

        // completely ignore monitors, they're not real sources
        if (i.monitor_of_sink != PulseAudio.INVALID_INDEX) {
            return;
        }

        Device device = null;
        bool is_new = !input_devices.has_key (i.index);
        if (is_new) {
            device = new Device (i.index);
        } else {
            device = input_devices.get (i.index);
        }

        device.input = true;
        device.name = i.name;
        device.display_name = i.description;
        device.is_muted = (i.mute != 0);
        device.cvolume = i.volume;
        device.channel_map = i.channel_map;
        device.balance = i.volume.get_balance (i.channel_map);
        device.volume_operations.foreach ((operation) => {
            if (operation.get_state () != PulseAudio.Operation.State.RUNNING) {
                device.volume_operations.remove (operation);
            }

            return GLib.Source.CONTINUE;
        });

        if (device.volume_operations.is_empty) {
            device.volume = volume_to_double (i.volume.max ());
        }

        bool is_default = i.name == default_source_name;
        device.is_default = is_default;
        if (is_default) {
            if (default_input != device) {
                default_input = device;
                default_input_changed ();
            }
        }

        device.form_factor = i.proplist.gets (PulseAudio.Proplist.PROP_DEVICE_FORM_FACTOR);
        device.parent_device_name = i.proplist.gets (PulseAudio.Proplist.PROP_DEVICE_MASTER_DEVICE);
        if (device.parent_device_name != null) {
            parent_missing.add (device);
            associate_device_with_parent (device);
        }

        // Add it to the list then.
        if (is_new) {
            input_devices.set (i.index, device);
            if (i.name.has_suffix (".echo-cancel")) {
                echo_cancel_input = device;
            } else {
                new_device (device);
            }
        }
    }

    private void sink_info_callback (PulseAudio.Context c, PulseAudio.SinkInfo? i, int eol) {
        if (i == null)
            return;

        Device device = null;
        bool is_new = !output_devices.has_key (i.index);
        if (is_new) {
            device = new Device (i.index);
        } else {
            device = output_devices.get (i.index);
        }

        device.input = false;
        device.name = i.name;
        device.display_name = i.description;
        device.is_muted = (i.mute != 0);
        device.cvolume = i.volume;
        device.channel_map = i.channel_map;
        device.balance = i.volume.get_balance (i.channel_map);
        device.volume_operations.foreach ((operation) => {
            if (operation.get_state () != PulseAudio.Operation.State.RUNNING) {
                device.volume_operations.remove (operation);
            }

            return GLib.Source.CONTINUE;
        });

        if (device.volume_operations.is_empty) {
            device.volume = volume_to_double (i.volume.max ());
        }

        bool is_default = i.name == default_sink_name;
        device.is_default = is_default;
        if (device.is_default) {
            if (default_output != device) {
                default_output = device;
                default_output_changed ();
            }
        }

        var form_factor = i.proplist.gets (PulseAudio.Proplist.PROP_DEVICE_FORM_FACTOR);
        device.parent_device_name = i.proplist.gets (PulseAudio.Proplist.PROP_DEVICE_MASTER_DEVICE);
        if (device.parent_device_name != null) {
            parent_missing.add (device);
            associate_device_with_parent (device);
        }

        // Add it to the list then.
        if (is_new) {
            output_devices.set (i.index, device);

            if (i.name.has_suffix (".echo-cancel")) {
                echo_cancel_output = device;
            } else {
                new_device (device);
            }
        }
    }

    private void server_info_callback (PulseAudio.Context c, PulseAudio.ServerInfo? i) {
        if (i == null)
            return;

        default_source_name = i.default_source_name;
        default_sink_name = i.default_sink_name;
        context.get_sink_info_list (sink_info_callback);
        context.get_source_info_list (source_info_callback);
        context.get_module_info_list (module_info_callback);
    }

    public void module_info_callback (PulseAudio.Context c, PulseAudio.ModuleInfo? i, int eol) {
        if (i == null)
            return;

        if (i.name == "module-echo-cancel") {
            has_echo_cancellation = true;
        }
    }

    public void module_info_remove_callback (PulseAudio.Context c, PulseAudio.ModuleInfo? i, int eol) {
        if (i == null)
            return;

        if (i.name == "module-echo-cancel") {
            has_echo_cancellation = false;
        }
    }

    /*
     * Change the Source
     */

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

    /*
     * Volume utils
     */

    private static double volume_to_double (PulseAudio.Volume vol) {
        double tmp = (double)(vol - PulseAudio.Volume.MUTED);
        return 100 * tmp / (double)(PulseAudio.Volume.NORM - PulseAudio.Volume.MUTED);
    }

    private static PulseAudio.Volume double_to_volume (double vol) {
        double tmp = (double)(PulseAudio.Volume.NORM - PulseAudio.Volume.MUTED) * vol/100;
        return (PulseAudio.Volume)tmp + PulseAudio.Volume.MUTED;
    }
}
