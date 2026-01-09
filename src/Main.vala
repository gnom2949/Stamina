/*
 * Copyright 2026 Silaev Aleksandr
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a license for this program. If not, see
 * <http://www.gnu.org/licenses/>.
 */

namespace Stamina {
    public class Application : Adw.Application {
        public const string APP_ID = "org.intsoftware.stamina";

        public Application ()
        {
            Object (
                application_id: APP_ID,
                flags: ApplicationFlags.HANDLES_OPEN
            );
        }

        construct
        {
            // Настройка акселераторов
            set_accels_for_action ("app.quit", {"<Ctrl>Q"});
            set_accels_for_action ("win.start", {"<Ctrl>S"});
            set_accels_for_action ("win.pause", {"<Ctrl>P"});
            set_accels_for_action ("win.reset", {"<Ctrl>R"});
            set_accels_for_action ("win.preferences", {"<Ctrl>comma"});
            set_accels_for_action ("win.short-break", {"<Ctrl>B"});
            set_accels_for_action ("win.long-break", {"<Ctrl><Shift>B"});

            // Установка иконки приложения
            var icon_theme = Gtk.IconTheme.get_for_display (Gdk.Display.get_default ());
            icon_theme.add_resource_path ("org/intsoftware/stamina");
        }

        protected override void activate ()
        {
            var win = this.active_window;
            if (win == null)
            {
                win = new Stamina.Window (this);
            }
            win.present ();
        }

        public static int main (string[] args)
        {
            // Инициализация локализации
            Intl.setlocale (LocaleCategory.ALL, "");
            Intl.bindtextdomain (APP_ID, Config.PACKAGE_LOCALE_DIR);
            Intl.bind_textdomain_codeset (APP_ID, "UTF-8");
            Intl.textdomain (APP_ID);

            var app = new Stamina.Application ();
            return app.run (args);
        }
    }

    namespace Config {
        public const string PACKAGE_NAME = "stamina";
        public const string PACKAGE_VERSION = "1.0.0";
        public const string GETTEXT_PACKAGE = "stamina";
        public const string PACKAGE_DATA_DIR = "/app/share/stamina";
        public const string PACKAGE_LOCALE_DIR = "/app/share/locale";
        public const string APP_DATA_DIR = "org.intsoftware.stamina";
    }
}
