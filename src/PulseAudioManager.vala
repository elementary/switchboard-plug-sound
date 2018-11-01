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

    public PulseAudio.Context context { get; private set; }
    private PulseAudio.GLibMainLoop loop;
    private bool is_ready = false;
    private uint reconnect_timer_id = 0U;
    private Gee.HashMap<string, Device> input_devices;
    private Gee.HashMap<string, Device> output_devices;
    public Device default_output { get; private set; }
    public Device default_input { get; private set; }
    private string default_source_name;
    private string default_sink_name;
    private Gee.HashMap<uint32, PulseAudio.Operation> volume_operations;

    private PulseAudioManager () {

    }

    construct {
        loop = new PulseAudio.GLibMainLoop ();
        input_devices = new Gee.HashMap<string, Device> ();
        output_devices = new Gee.HashMap<string, Device> ();
        volume_operations = new Gee.HashMap<uint32, PulseAudio.Operation> ();
    }

    public void start () {
        reconnect_to_pulse.begin ();
    }

    public async void set_default_device (Device device) {
        debug ("\n");
        debug("set_default_device: %s", device.id);
        debug("  %s", device.input? "input" : "output");
        debug("#1");
        // #1 Set card profile
        // Some sinks / sources are only available under certain card profiles,
        // for example to switch between onboard speakers to hdmi
        // the profile has to be switched from analog stereo to digital stereo.
        // Attempt to find profiles that support both selected input and output
        var other_device = device.input? default_output : default_input;
        var profile_name = get_matching_profile(device, other_device);
        // otherwise fall back to supporting this device only
        if (profile_name == null) {
            profile_name = device.profiles[0];
        }
        debug("  profile_name: %s", profile_name);
        if (profile_name != device.card_active_profile_name) {
            debug("set card profile: %s > %s", device.card_active_profile_name, profile_name);
            // switch profile to get sink for this device
            yield set_card_profile_by_index (device.card_index, profile_name);
            // wait for new card sink to appear
            debug("wait for card sink / source");
            // yield get_device_sink_name(device);
            // yield get_card_sink_name(device);
            yield wait_for_update (device, device.input? "card-source-name" : "card-sink-name");
        }
        debug("#2");
        // #2 Set sink / source port
        // Speakers and headphones can be different ports on the same sink
        if (!device.input && device.port_name != device.card_sink_port_name) {
            debug("set sink port: %s > %s", device.card_sink_port_name, device.port_name);
            // set sink port (enables switching between headphones and speakers for example)
            yield set_sink_port_by_name (device.card_sink_name, device.port_name);
        }
        if (device.input && device.port_name != device.card_source_port_name) {
            debug("set source port: %s > %s", device.card_source_port_name, device.port_name);
            yield set_source_port_by_name (device.card_source_name, device.port_name);
        }
        debug("#3");
        // #3 Wait for sink / source to appear for this device
        if (!device.input && device.sink_name == null ||
            device.input && device.source_name == null) {
            debug("wait for sink / source");
            // yield get_device_sink_name(device);
            yield wait_for_update (device, device.input? "source-name" : "sink-name");
        }
        debug("#4");
        // #4 Set sink / source
        // To for example switch between onboard speakers and bluetooth audio devices
        if (!device.input && device.sink_name != default_sink_name) {
            debug("set sink: %s > %s", default_sink_name, device.sink_name);
            yield set_default_sink (device.sink_name);
        }
        if (device.input && device.source_name != default_source_name) {
            debug("set source: %s > %s", default_source_name, device.source_name);
            yield set_default_source (device.source_name);
        }
    }

    private string? get_matching_profile (Device device1, Device device2) {
        foreach (var profile1 in device1.profiles) {
            if (device2.profiles.contains (profile1)) {
                return profile1;
            }
        }
        return null;
    }

    private async void set_card_profile_by_index (uint32 card_index, string profile_name) {
        context.set_card_profile_by_index(card_index, profile_name, (c, success) => {
            if (success == 1) set_card_profile_by_index.callback();
            else warning("setting card %u profile to %s failed", card_index, profile_name);
        });
        yield;
    }

    // TODO make more robust. Add timeout? Prevent multiple connects?
    private async void wait_for_update (Device device, string prop_name) {
        debug ("wait_for_update: %s:%s", device.id, prop_name);
        ulong handler_id = 0;
        handler_id = device.notify[prop_name].connect((s, p) => {
            // debug ("  update: %s", device.get (prop_name));
            // string value = device.get (prop_name);
            string prop_value;
            device.get (prop_name, out prop_value);
            if (prop_value != null) {
                device.disconnect(handler_id);
                wait_for_update.callback();
            }
        });
        yield;
    }

    private async void set_sink_port_by_name (string sink_name, string port_name) {
        context.set_sink_port_by_name(sink_name, port_name, (c, success) => {
            if (success == 1) set_sink_port_by_name.callback();
            else warning("setting sink %s port to %s failed", sink_name, port_name);
        });
        yield;
    }

    private async void set_source_port_by_name (string source_name, string port_name) {
        context.set_source_port_by_name(source_name, port_name, (c, success) => {
            if (success == 1) set_source_port_by_name.callback();
            else warning("setting source %s port to %s failed", source_name, port_name);
        });
        yield;
    }

    private async void set_default_sink(string sink_name) {
        context.set_default_sink (sink_name, (c, success) => {
            if (success == 1) set_default_sink.callback();
            else warning("setting default sink to %s failed", sink_name);
        });
        yield;
    }

    private async void set_default_source(string source_name) {
        context.set_default_source (source_name, (c, success) => {
            if (success == 1) set_default_source.callback();
            else warning("setting default source to %s failed", source_name);
        });
        yield;
    }

    public void change_device_mute (Device device, bool mute = true) {
        if (device.input) {
            context.set_source_mute_by_name (device.source_name, mute, null);
        } else {
            context.set_sink_mute_by_name (device.sink_name, mute, null);
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
            operation = context.set_source_volume_by_name (device.source_name, cvol, null);
        } else {
            operation = context.set_sink_volume_by_name (device.sink_name, cvol, null);
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
            operation = context.set_source_volume_by_name (device.source_name, cvol, null);
        } else {
            operation = context.set_sink_volume_by_name (device.sink_name, cvol, null);
        }

        if (operation != null) {
            device.volume_operations.add (operation);
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
                        PulseAudio.Context.SubscriptionMask.CARD);
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
                        debug("subscribe_callback:SINK:REMOVE");
                        foreach (var device in output_devices.values) {
                            if (device.sink_index == index) {
                                debug("  updating device: %s", device.id);
                                device.sink_name = null;
                                device.sink_index = null;
                                device.is_default = false;
                                debug("    device.sink_name: %s", device.sink_name);
                            }
                            if (device.card_sink_index == index) {
                                debug("  updating device: %s", device.id);
                                device.card_sink_name = null;
                                device.card_sink_index = null;
                                device.card_sink_port_name = null;
                                debug("    device.card_sink_name: %s", device.card_sink_name);
                            }
                        }
                        break;
                }

                break;

            case PulseAudio.Context.SubscriptionEventType.SERVER:
                context.get_server_info (server_info_callback);
                break;

            case PulseAudio.Context.SubscriptionEventType.CARD:
                var event_type = t & PulseAudio.Context.SubscriptionEventType.TYPE_MASK;
                switch (event_type) {
                    case PulseAudio.Context.SubscriptionEventType.NEW:
                        c.get_card_info_by_index (index, card_info_callback);
                        break;

                    case PulseAudio.Context.SubscriptionEventType.CHANGE:
                        c.get_card_info_by_index (index, card_info_callback);
                        break;

                    case PulseAudio.Context.SubscriptionEventType.REMOVE:
                        var iter = output_devices.map_iterator ();
                        while (iter.next()) {
                            var device = iter.get_value ();
                            if (device.card_index == index) {
                                debug("  REMOVE: %s", device.id);
                                device.removed ();
                                iter.unset();
                            }
                        }
                        break;
                }
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
                        debug("subscribe_callback:SOURCE:REMOVE");
                        foreach (var device in input_devices.values) {
                            if (device.source_index == index) {
                                debug("  updating device: %s", device.id);
                                device.source_name = null;
                                device.source_index = null;
                                device.is_default = false;
                                debug("    device.source_name: %s", device.source_name);
                            }
                            if (device.card_source_index == index) {
                                debug("  updating device: %s", device.id);
                                device.card_source_name = null;
                                device.card_source_index = null;
                                device.card_source_port_name = null;
                                debug("    device.card_source_name: %s", device.card_source_name);
                            }
                        }
                        break;
                }

                break;
        }
    }

    /*
     * Retrieve object informations
     */

    private void source_info_callback (PulseAudio.Context c, PulseAudio.SourceInfo? source, int eol) {
        if (source == null)
            return;

        // completely ignore monitors, they're not real sources
        if (source.monitor_of_sink != PulseAudio.INVALID_INDEX) {
            return;
        }
        debug("source info update");
        debug("  source: %s (%s)", source.description, source.name);
        debug("    card: %u", source.card);

        if (source.name == "auto_null") {
            return;
        }

        // public SinkPortInfo*[] ports;
        foreach (var port in source.ports) {
            debug("    port: %s (%s)", port.description, port.name);
        }
        debug("    active port: %s (%s)", source.active_port.description, source.active_port.name);

        foreach (var device in input_devices.values) {
            if (device.card_index == source.card) {
                debug("    updating device: %s", device.id);
                device.card_source_index = source.index;
                device.card_source_name = source.name;
                debug("      device.card_source_name: %s", device.card_source_name);
                device.card_source_port_name = source.active_port.name;
                if (device.port_name == source.active_port.name) {
                    device.source_name = source.name;
                    debug("      device.source_name: %s", device.card_source_name);
                    device.source_index = source.index;
                    device.is_default = (source.name == default_source_name);
                    debug("      is_default: %s", device.is_default ? "true" : "false");

                    device.is_muted = (source.mute != 0);
                    device.cvolume = source.volume;
                    device.channel_map = source.channel_map;
                    device.balance = source.volume.get_balance (source.channel_map);
                    device.volume_operations.foreach ((operation) => {
                        if (operation.get_state () != PulseAudio.Operation.State.RUNNING) {
                            device.volume_operations.remove (operation);
                        }

                        return GLib.Source.CONTINUE;
                    });
                    if (device.volume_operations.is_empty) {
                        device.volume = volume_to_double (source.volume.max ());
                    }
                //     device.ports.clear ();
                //     device.default_port = null;
                //     for (int idx = 0; idx < source.n_ports; idx++) {
                //         var new_port = new Device.Port ();
                //         new_port.name = i.ports[idx].name;
                //         new_port.description = i.ports[idx].description;
                //         new_port.priority = i.ports[idx].priority;
                //         device.ports.add (new_port);
                //
                //         if (i.ports[idx] == i.active_port) {
                //             device.default_port = new_port;
                //         }
                //     }
                    if (device.is_default) {
                        default_input = device;
                    }
                } else {
                    device.source_name = null;
                    device.source_index = null;
                    device.is_default = false;
                }
            }
        }

        // device.input = true;
        // device.name = i.name;
        // device.display_name = i.description;
        // device.is_muted = (i.mute != 0);
        // device.cvolume = i.volume;
        // device.channel_map = i.channel_map;
        // device.balance = i.volume.get_balance (i.channel_map);
        // device.volume_operations.foreach ((operation) => {
        //     if (operation.get_state () != PulseAudio.Operation.State.RUNNING) {
        //         device.volume_operations.remove (operation);
        //     }
        //
        //     return GLib.Source.CONTINUE;
        // });
        //
        // device.ports.clear ();
        // device.default_port = null;
        // for (int idx = 0; idx < i.n_ports; idx++) {
        //     var new_port = new Device.Port ();
        //     new_port.name = i.ports[idx].name;
        //     new_port.description = i.ports[idx].description;
        //     new_port.priority = i.ports[idx].priority;
        //     device.ports.add (new_port);
        //
        //     if (i.ports[idx] == i.active_port) {
        //         device.default_port = new_port;
        //     }
        // }
        //
        // if (device.volume_operations.is_empty) {
        //     device.volume = volume_to_double (i.volume.max ());
        // }
        //
        // var form_factor = i.proplist.gets (PulseAudio.Proplist.PROP_DEVICE_FORM_FACTOR);
        // if (form_factor != null) {
        //     device.form_factor = form_factor;
        // }
        //
        // device.is_default = (i.name == default_source_name);
        // if (device.is_default) {
        //     default_input = device;
        // }
        //
        // // Add it to the list then.
        // if (is_new) {
        //     input_devices.set (i.index, device);
        //     new_device (device);
        // }
    }

    private void sink_info_callback (PulseAudio.Context c, PulseAudio.SinkInfo? sink, int eol) {
        if (sink == null)
            return;
        debug("sink info update");
        debug("  sink: %s (%s)", sink.description, sink.name);

        if (sink.name == "auto_null") {
            return;
        }

        debug("    card: %u", sink.card);

        // public SinkPortInfo*[] ports;
        foreach (var port in sink.ports) {
            debug("    port: %s (%s)", port.description, port.name);
        }
        debug("    active port: %s (%s)", sink.active_port.description, sink.active_port.name);

        foreach (var device in output_devices.values) {
            if (device.card_index == sink.card) {
                debug("    updating device: %s", device.id);
                device.card_sink_index = sink.index;
                device.card_sink_name = sink.name;
                debug("      device.card_sink_name: %s", device.card_sink_name);
                device.card_sink_port_name = sink.active_port.name;
                if (device.port_name == sink.active_port.name) {
                    device.sink_name = sink.name;
                    debug("      device.sink_name: %s", device.card_sink_name);
                    device.sink_index = sink.index;
                    device.is_default = (sink.name == default_sink_name);
                    debug("      is_default: %s", device.is_default ? "true" : "false");
                    device.is_muted = (sink.mute != 0);
                    device.cvolume = sink.volume;
                    device.channel_map = sink.channel_map;
                    device.balance = sink.volume.get_balance (sink.channel_map);
                    device.volume_operations.foreach ((operation) => {
                        if (operation.get_state () != PulseAudio.Operation.State.RUNNING) {
                            device.volume_operations.remove (operation);
                        }

                        return GLib.Source.CONTINUE;
                    });
                    if (device.volume_operations.is_empty) {
                        device.volume = volume_to_double (sink.volume.max ());
                    }
                //     device.ports.clear ();
                //     device.default_port = null;
                //     for (int idx = 0; idx < sink.n_ports; idx++) {
                //         var new_port = new Device.Port ();
                //         new_port.name = i.ports[idx].name;
                //         new_port.description = i.ports[idx].description;
                //         new_port.priority = i.ports[idx].priority;
                //         device.ports.add (new_port);
                //
                //         if (i.ports[idx] == i.active_port) {
                //             device.default_port = new_port;
                //         }
                //     }
                    if (device.is_default) {
                        default_output = device;
                    }
                } else {
                    device.sink_name = null;
                    device.sink_index = null;
                    device.is_default = false;
                }
            }
        }
    }

    private void card_info_callback (PulseAudio.Context c, PulseAudio.CardInfo? card, int eol) {
        if (card == null)
            return;
        debug ("card info update");
        debug ("  card: %u %s (%s)", card.index, card.proplist.gets (PulseAudio.Proplist.PROP_DEVICE_DESCRIPTION), card.name);
        debug ("    active profile: %s", card.active_profile2.name);

        debug ("    card form factor: %s", card.proplist.gets (PulseAudio.Proplist.PROP_DEVICE_FORM_FACTOR));
        debug ("    card icon name: %s", card.proplist.gets (PulseAudio.Proplist.PROP_MEDIA_ICON_NAME));

        var card_active_profile_name = card.active_profile2.name;

        // retrieve relevant ports
        PulseAudio.CardPortInfo*[] relevant_ports = {};
        foreach (var port in card.ports) {
            if (port.available == PulseAudio.PortAvailable.NO) continue;
            // if (!(PulseAudio.Direction.OUTPUT in port.direction)) continue;
            relevant_ports += port;
        }

        // add new / update devices
        foreach (var port in relevant_ports) {
            bool is_input = (PulseAudio.Direction.INPUT in port.direction);
            debug ("    %s port: %s (%s)", is_input ? "input" : "output", port.description, port.name);
            Gee.HashMap<string, Device> devices = is_input? input_devices : output_devices;
            Device device = null;
            var id = get_device_id (card, port);
            bool is_new = !devices.has_key (id);
            if (is_new) {
                debug("      new device: %s", id);
                device = new Device (id, card.index, port.name);
            } else {
                debug("      updating device: %s", id);
                device = devices.get (id);
            }
            device.card_active_profile_name = card_active_profile_name;
            device.input = is_input;
            device.card_name = card.name;
            var card_description = card.proplist.gets (PulseAudio.Proplist.PROP_DEVICE_DESCRIPTION);
            device.display_name = @"$(port.description) - $(card_description)";
            device.form_factor = port.proplist.gets (PulseAudio.Proplist.PROP_DEVICE_FORM_FACTOR);
            debug ("      port icon name: %s", port.proplist.gets (PulseAudio.Proplist.PROP_MEDIA_ICON_NAME)); // optional:
            device.profiles = get_relevant_card_port_profiles (port);
            foreach (var profile in device.profiles) {
                debug ("      profile: %s", profile);
            }
            if (is_new) {
                devices.set (id, device);
                new_device (device);
            }
        }
        cleanup_devices (output_devices, card, relevant_ports);
        cleanup_devices (input_devices, card, relevant_ports);
    }

    // remove devices which port has dissappeared
    private void cleanup_devices (Gee.HashMap<string, Device> devices, PulseAudio.CardInfo card, PulseAudio.CardPortInfo*[] relevant_ports) {
        var iter = devices.map_iterator ();
        while (iter.next()) {
            var device = iter.get_value ();
            if(device.card_index != card.index) continue;
            // device still listed as port?
            var found = false;
            foreach (var port in relevant_ports) {
                if (device.id == get_device_id (card, port)) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                debug ("    removing: %s", device.id);
                device.removed ();
                iter.unset();
            }
        }
    }

    private string get_device_id (PulseAudio.CardInfo card, PulseAudio.CardPortInfo* port) {
        return @"$(card.name):$(port.name)";
    }

    private Gee.ArrayList<string> get_relevant_card_port_profiles (PulseAudio.CardPortInfo* port) {
        var profiles_list = new Gee.ArrayList<PulseAudio.CardProfileInfo2*>.wrap (port.profiles2);

        // sort on priority;
        profiles_list.sort((a, b) => {
            if (a.priority > b.priority) return -1;
            if (a.priority < b.priority) return 1;
            return 0;
        });
        // just store names in Device
        var profiles = new Gee.ArrayList<string>();
        foreach (var item in profiles_list) {
            profiles.add(item.name);
        }
        return profiles;
    }

    private void server_info_callback (PulseAudio.Context context, PulseAudio.ServerInfo? server) {
        debug("server info update");
        if (server == null)
            return;

        if (default_sink_name == null) {
            default_sink_name = server.default_sink_name;
            debug("  default_sink_name: %s", default_sink_name);
        }
        if (default_sink_name != server.default_sink_name) {
            debug("  default_sink_name: %s > %s", default_sink_name, server.default_sink_name);
            default_sink_name = server.default_sink_name;
            PulseAudio.ext_stream_restore_read (context, ext_stream_restore_read_sink_callback);
        }
        if (default_source_name == null) {
            default_source_name = server.default_source_name;
            debug("  default_source_name: %s", default_source_name);
        }
        if (default_source_name != server.default_source_name) {
            debug("  default_source_name: %s > %s", default_source_name, server.default_source_name);
            default_source_name = server.default_source_name;
            PulseAudio.ext_stream_restore_read (context, ext_stream_restore_read_source_callback);
        }
        // request info on cards and ports before requesting info on
        // sinks, because sinks info is added to existing Devices.
        context.get_card_info_list (card_info_callback);
        context.get_source_info_list (source_info_callback);
        context.get_sink_info_list (sink_info_callback);
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
        PulseAudio.ext_stream_restore_write (c, PulseAudio.UpdateMode.REPLACE, {new_info}, 1, (c, success) => {
            if (success != 1) warning("Updating source failed");
        });
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
