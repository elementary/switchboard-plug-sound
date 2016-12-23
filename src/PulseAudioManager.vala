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

    private PulseAudio.GLibMainLoop loop;
    private PulseAudio.Context context;
    private bool is_ready = false;
    private uint reconnect_timer_id = 0U;

    private PulseAudioManager () {
        reconnect_to_pulse.begin ();
    }

    construct {
        loop = new PulseAudio.GLibMainLoop ();
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

        if (context.connect(null, PulseAudio.Context.Flags.NOFAIL, null) < 0)
            warning( "pa_context_connect() failed: %s\n", PulseAudio.strerror(context.errno()));
    }

    private void context_state_callback (PulseAudio.Context c) {
        switch (c.get_state ()) {
            case PulseAudio.Context.State.READY:
                c.subscribe (PulseAudio.Context.SubscriptionMask.SINK |
                        PulseAudio.Context.SubscriptionMask.SOURCE |
                        PulseAudio.Context.SubscriptionMask.SOURCE_OUTPUT);
                //c.set_subscribe_callback (context_events_cb);
                context.get_server_info (server_info_cb_for_props);
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

    private void source_info_cb (PulseAudio.Context c, PulseAudio.SourceInfo? i, int eol) {
        if (i == null)
            return;

        warning ("%u: %s - %s | %02X", i.index, i.name, i.description, i.flags);
        //TODO: do things
    }

    private void sink_info_cb_for_props (PulseAudio.Context c, PulseAudio.SinkInfo? i, int eol) {
        if (i == null)
            return;

        warning ("%u: %s - %s | %02X", i.index, i.name, i.description, i.flags);
        //TODO: do things
    }

    private void server_info_cb_for_props (PulseAudio.Context c, PulseAudio.ServerInfo? i) {
        if (i == null)
            return;

        context.get_sink_info_list (sink_info_cb_for_props);
        context.get_source_info_list (source_info_cb);
    }
}
