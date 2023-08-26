/*
* SPDX-License-Identifier: LGPL-3.0-or-later
* SPDX-FileCopyrightText: 2023 elementary, Inc. (https://elementary.io)
*
* Authored by: Leonhard Kargl <leo.kargl@proton.me>
*/

public class Sound.App : Object {
   public uint32 index { get; construct; }
   public string name { get; construct; }
   public PulseAudio.ChannelMap channel_map { get; set; }
   public double volume { get; set; }
   public bool muted { get; set; }

   public App (uint32 index, string name) {
       Object (
           index: index,
           name: name
       );
   }
}
