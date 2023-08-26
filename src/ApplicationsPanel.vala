public class Sound.ApplicationsPanel : Gtk.Box {
    construct {
        var pulse_audio_manager = PulseAudioManager.get_default ();

        var list_box = new Gtk.ListBox ();
        list_box.bind_model (pulse_audio_manager.apps, widget_create_func);

        add (list_box);
    }

    private Gtk.Widget widget_create_func (Object item) {
        var app = (App) item;
        var app_row = new AppRow (app);
        app_row.show_all ();
        return app_row;
    }
}
