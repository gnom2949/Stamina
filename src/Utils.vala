namespace Stamina {
    namespace Utils {
        public string format_duration (int seconds) {
            int minutes = seconds / 60;
            int remaining_seconds = seconds % 60;
            return "%02d:%02d".printf (minutes, remaining_seconds);
        }

        public string format_time_ago (DateTime date_time) {
            var now = new DateTime.now_local ();
            var diff = now.difference (date_time);

            if (diff < 0) {
                return _("Just now");
            }

            if (diff < TimeSpan.MINUTE) {
                return _("Just now");
            } else if (diff < TimeSpan.HOUR) {
                int minutes = (int)(diff / TimeSpan.MINUTE);
                return ngettext ("%d minute ago", "%d minutes ago", (ulong)minutes).printf (minutes);
            } else if (diff < TimeSpan.DAY) {
                int hours = (int)(diff / TimeSpan.HOUR);
                return ngettext ("%d hour ago", "%d hours ago", (ulong)hours).printf (hours);
            } else {
                int days = (int)(diff / TimeSpan.DAY);
                return ngettext ("%d day ago", "%d days ago", (ulong)days).printf (days);
            }
        }

        public void show_error_dialog (Gtk.Window? parent, string title, string message) {
            var dialog = new Adw.MessageDialog (
                parent,
                title,
                message
            );

            dialog.add_response ("ok", _("OK"));
            dialog.set_default_response ("ok");
            dialog.set_close_response ("ok");

            dialog.present ();
        }

        public bool is_dark_theme () {
            var style_manager = Adw.StyleManager.get_default ();
            return style_manager.dark;
        }

        public string get_color_scheme () {
            var settings = new Settings (Config.APP_ID);
            var scheme = settings.get_string ("color-scheme");

            if (scheme == "default") {
                return is_dark_theme () ? "dark" : "light";
            }

            return scheme;
        }

        public Gdk.RGBA get_progress_color (double progress) {
            var color = Gdk.RGBA ();

            if (progress < 0.25) {
                color.parse ("#ed333b"); // Красный
            } else if (progress < 0.5) {
                color.parse ("#e66100"); // Оранжевый
            } else if (progress < 0.75) {
                color.parse ("#f8e45c"); // Желтый
            } else {
                color.parse ("#57e389"); // Зеленый
            }

            return color;
        }

        public void play_sound (string sound_name) {
            try {
                var player = new Gst.ElementFactory.make ("playbin", "player");
                var uri = "resource:///io/gitlab/intsoftware/stamina/sounds/" + sound_name + ".ogg";
                player.set ("uri", uri);
                player.set_state (Gst.State.PLAYING);

                // Остановить через 2 секунды
                Timeout.add (2000, () => {
                    player.set_state (Gst.State.NULL);
                    return false;
                });
            } catch (Error e) {
                warning ("Failed to play sound: %s", e.message);
            }
        }
    }
}
