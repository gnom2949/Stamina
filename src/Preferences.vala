namespace Stamina {
    public class Preferences : Adw.PreferencesWindow {
        private Settings settings;

        public Preferences (Gtk.Window parent) {
            Object (
                transient_for: parent,
                title: _("Preferences"),
                modal: true,
                default_width = 550,
                default_height = 650
            );

            settings = new Settings (Config.APP_ID);
            build_ui ();
        }

        private void build_ui () {
            // Страница основных настроек
            var general_page = new Adw.PreferencesPage () {
                title = _("General"),
                icon_name = "preferences-system-symbolic"
            };

            var timer_group = new Adw.PreferencesGroup () {
                title = _("Timer Settings"),
                description = _("Configure timer durations")
            };

            // Рабочее время
            var work_row = new Adw.SpinRow.with_range (5, 60, 5) {
                title = _("Focus Duration"),
                subtitle = _("Duration of focus sessions in minutes")
            };
            work_row.set_value (settings.get_int ("work-duration"));
            work_row.notify["value"].connect (() => {
                settings.set_int ("work-duration", (int)work_row.get_value ());
            });
            timer_group.add (work_row);

            // Короткий перерыв
            var break_row = new Adw.SpinRow.with_range (1, 30, 1) {
                title = _("Short Break"),
                subtitle = _("Duration of short breaks in minutes")
            };
            break_row.set_value (settings.get_int ("break-duration"));
            break_row.notify["value"].connect (() => {
                settings.set_int ("break-duration", (int)break_row.get_value ());
            });
            timer_group.add (break_row);

            // Длинный перерыв
            var long_break_row = new Adw.SpinRow.with_range (5, 60, 5) {
                title = _("Long Break"),
                subtitle = _("Duration of long breaks in minutes")
            };
            long_break_row.set_value (settings.get_int ("long-break-duration"));
            long_break_row.notify["value"].connect (() => {
                settings.set_int ("long-break-duration", (int)long_break_row.get_value ());
            });
            timer_group.add (long_break_row);

            // Сессий до длинного перерыва
            var sessions_row = new Adw.SpinRow.with_range (1, 10, 1) {
                title = _("Sessions Before Long Break"),
                subtitle = _("Number of focus sessions before a long break")
            };
            sessions_row.set_value (settings.get_int ("sessions-before-long-break"));
            sessions_row.notify["value"].connect (() => {
                settings.set_int ("sessions-before-long-break", (int)sessions_row.get_value ());
            });
            timer_group.add (sessions_row);

            general_page.add (timer_group);

            // Группа автозапуска
            var auto_group = new Adw.PreferencesGroup () {
                title = _("Auto-start"),
                description = _("Configure automatic timer behavior")
            };

            var auto_start_break = new Adw.SwitchRow () {
                title = _("Auto-start Breaks"),
                subtitle = _("Automatically start break timer after focus session")
            };
            auto_start_break.set_active (settings.get_boolean ("auto-start-break"));
            auto_start_break.notify["active"].connect (() => {
                settings.set_boolean ("auto-start-break", auto_start_break.get_active ());
            });
            auto_group.add (auto_start_break);

            var auto_start_work = new Adw.SwitchRow () {
                title = _("Auto-start Work"),
                subtitle = _("Automatically start work timer after break")
            };
            auto_start_work.set_active (settings.get_boolean ("auto-start-work"));
            auto_start_work.notify["active"].connect (() => {
                settings.set_boolean ("auto-start-work", auto_start_work.get_active ());
            });
            auto_group.add (auto_start_work);

            var auto_start_timer = new Adw.SwitchRow () {
                title = _("Auto-start Timer"),
                subtitle = _("Automatically start next timer session")
            };
            auto_start_timer.set_active (settings.get_boolean ("auto-start-timer"));
            auto_start_timer.notify["active"].connect (() => {
                settings.set_boolean ("auto-start-timer", auto_start_timer.get_active ());
            });
            auto_group.add (auto_start_timer);

            general_page.add (auto_group);

            // Страница уведомлений
            var notifications_page = new Adw.PreferencesPage () {
                title = _("Notifications"),
                icon_name = "preferences-desktop-notifications-symbolic"
            };

            var notifications_group = new Adw.PreferencesGroup () {
                title = _("Notification Settings"),
                description = _("Configure how you receive notifications")
            };

            var enable_notifications = new Adw.SwitchRow () {
                title = _("Enable Notifications"),
                subtitle = _("Show notifications when timer changes state")
            };
            enable_notifications.set_active (settings.get_boolean ("enable-notifications"));
            enable_notifications.notify["active"].connect (() => {
                settings.set_boolean ("enable-notifications", enable_notifications.get_active ());
            });
            notifications_group.add (enable_notifications);

            var sound_notifications = new Adw.SwitchRow () {
                title = _("Sound Notifications"),
                subtitle = _("Play sound when timer completes")
            };
            sound_notifications.set_active (settings.get_boolean ("sound-notifications"));
            sound_notifications.notify["active"].connect (() => {
                settings.set_boolean ("sound-notifications", sound_notifications.get_active ());
            });
            notifications_group.add (sound_notifications);

            var warning_notification = new Adw.SwitchRow () {
                title = _("Warning Notification"),
                subtitle = _("Show notification when one minute remains")
            };
            warning_notification.set_active (settings.get_boolean ("warning-notification"));
            warning_notification.notify["active"].connect (() => {
                settings.set_boolean ("warning-notification", warning_notification.get_active ());
            });
            notifications_group.add (warning_notification);

            notifications_page.add (notifications_group);

            // Страница внешнего вида
            var appearance_page = new Adw.PreferencesPage () {
                title = _("Appearance"),
                icon_name = "applications-graphics-symbolic"
            };

            var theme_group = new Adw.PreferencesGroup () {
                title = _("Theme"),
                description = _("Customize the appearance of the application")
            };

            // Выбор цветовой схемы
            var color_scheme_row = new Adw.ComboRow () {
                title = _("Color Scheme"),
                subtitle = _("Choose between light and dark mode")
            };

            var color_scheme_model = new GLib.ListStore (typeof (ColorSchemeItem));
            color_scheme_model.append (new ColorSchemeItem (_("Follow System"), "default"));
            color_scheme_model.append (new ColorSchemeItem (_("Light"), "light"));
            color_scheme_model.append (new ColorSchemeItem (_("Dark"), "dark"));

            color_scheme_row.model = color_scheme_model;
            color_scheme_row.expression = new Gtk.PropertyExpression (typeof (ColorSchemeItem), null, "name");

            // Установка текущего значения
            var current_scheme = settings.get_string ("color-scheme");
            for (uint i = 0; i < color_scheme_model.get_n_items (); i++) {
                var item = (ColorSchemeItem) color_scheme_model.get_item (i);
                if (item.id == current_scheme) {
                    color_scheme_row.selected = i;
                    break;
                }
            }

            color_scheme_row.notify["selected"].connect (() => {
                var item = (ColorSchemeItem) color_scheme_model.get_item (color_scheme_row.selected);
                settings.set_string ("color-scheme", item.id);
            });

            theme_group.add (color_scheme_row);

            // Показывать прогресс-бар
            var show_progress_row = new Adw.SwitchRow () {
                title = _("Show Progress Bar"),
                subtitle = _("Display progress bar below timer")
            };
            show_progress_row.set_active (settings.get_boolean ("show-progress-bar"));
            show_progress_row.notify["active"].connect (() => {
                settings.set_boolean ("show-progress-bar", show_progress_row.get_active ());
            });
            theme_group.add (show_progress_row);

            // Анимации
            var animations_row = new Adw.SwitchRow () {
                title = _("Animations"),
                subtitle = _("Enable interface animations")
            };
            animations_row.set_active (settings.get_boolean ("enable-animations"));
            animations_row.notify["active"].connect (() => {
                settings.set_boolean ("enable-animations", animations_row.get_active ());
            });
            theme_group.add (animations_row);

            appearance_page.add (theme_group);

            // Страница программирования
            var programming_page = new Adw.PreferencesPage () {
                title = _("Programming"),
                icon_name = "applications-development-symbolic"
            };

            var language_group = new Adw.PreferencesGroup () {
                title = _("Programming Languages"),
                description = _("Select programming languages for session tracking")
            };

            // Загрузка языков из JSON
            try {
                var file = File.new_for_path (Config.PACKAGE_DATA_DIR + "/languages.json");
                if (file.query_exists ()) {
                    var parser = new Json.Parser ();
                    parser.load_from_file (file.get_path ());
                    var root = parser.get_root ().get_object ();

                    if (root.has_member ("languages")) {
                        var languages = root.get_array_member ("languages");

                        for (uint i = 0; i < languages.get_length (); i++) {
                            var lang_obj = languages.get_object_element (i);
                            var lang_name = lang_obj.get_string_member ("name");
                            var lang_id = lang_obj.get_string_member ("id");

                            var lang_row = new Adw.SwitchRow () {
                                title = lang_name,
                                subtitle = _("Track sessions for %s").printf (lang_name)
                            };

                            var enabled = settings.get_boolean ("language-" + lang_id);
                            lang_row.set_active (enabled);

                            lang_row.notify["active"].connect (() => {
                                settings.set_boolean ("language-" + lang_id, lang_row.get_active ());
                            });

                            language_group.add (lang_row);
                        }
                    }
                }
            } catch (Error e) {
                warning ("Failed to load languages: %s", e.message);
            }

            programming_page.add (language_group);

            // Добавление страниц
            add (general_page);
            add (notifications_page);
            add (appearance_page);
            add (programming_page);

            // Настройка доступности
            setup_accessibility ();
        }

        private void setup_accessibility () {
            // Установка ролей для доступности
            var pages = get_pages ();
            foreach (var page in pages) {
                var groups = page.get_groups ();
                foreach (var group in groups) {
                    var rows = group.get_rows ();
                    foreach (var row in rows) {
                        if (row is Adw.ActionRow) {
                            row.accessible_role = ATK.Role.LIST_ITEM;
                        }
                    }
                }
            }
        }

        private class ColorSchemeItem : Object {
            public string name { get; construct; }
            public string id { get; construct; }

            public ColorSchemeItem (string name, string id) {
                Object (name: name, id: id);
            }
        }
    }
}
