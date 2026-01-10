/*
 * Copyright 2026 Int Software, Aleksandr Silaev
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
    public class Window : Adw.ApplicationWindow {
        private Gtk.Label timer_label;
        private Gtk.Label status_label;
        private Gtk.ProgressBar progress_bar;
        private Gtk.Button start_button;
        private Gtk.Button pause_button;
        private Gtk.Button reset_button;
        private Gtk.Button short_break_button;
        private Gtk.Button long_break_button;
        private LanguageLoader language_loader;
        private Gtk.Button random_code_button;
        private Gtk.Button simulate_typing_button;
        private Gtk.Button clear_button;
        private Gtk.TextView code_textview;
        private Gtk.ComboBoxText language_combobox;
        private Gtk.Entry quick_input_entry;
        private Gtk.Button suggest_word_button;
        private SessionManager session_manager;
        private Gtk.Stack main_stack;
        private Adw.ViewStack view_stack;
        private Gtk.DropDown language_dropdown;
        private Gtk.Entry project_entry;
        private Gtk.TextView notes_textview;
        private Gtk.Button start_coding_button;
        private Gtk.Button stop_coding_button;
        private Gtk.Label current_session_label;
        private string? current_session_id = null;
        private Timer timer;
        private Settings settings;

        public Window (Adw.Application app)
        {
            Object (
                application: app,
                title: _("Stamina"),
                icon_name: "org.intsoftware.stamina"
            );


            settings = new Settings (Config.APP_ID);
            timer = new Timer (settings);

            build_ui();
            connect_signals();

            // восстановление состояния окна
            default_width = settings.get_int ("window-width");
            default_height = setting.get_int ("window-height");
            maximized = settings.get_boolean ("window-maximized");

            // следим за темой в настройках
            var style_manager = Adw.StyleManager.get_default();
            style_manager.notify["dark"].connect (update_theme);

            // загрузка состояния таймера
            timer.load_state();
            update_display();

            // инициализация LanguageLoader
            language_loader = LanguageLoader.get_default();
            language_loader.all_languages_loaded.connect (on_languages_loaded);

            // загружаем языки асинхронно
            load_languages_async.begin();
        }

        private async void load_languages_async()
        {
            yield language_loader.load_all_languages();
        } 

        private void on_languages_loaded()
        {
            debug ("All lang loaded");
            populate_language_combobox();
        }

        private void populate_language_combobox () {
            language_combobox.remove_all ();
            
            var languages = language_loader.get_available_languages ();
            if (languages.is_empty) {
                language_combobox.append ("none", _("No languages loaded"));
                language_combobox.active_id = "none";
                random_code_button.sensitive = false;
                simulate_typing_button.sensitive = false;
                return;
            }
            
            foreach (var lang_id in languages) {
                var language = language_loader.get_language (lang_id);
                if (language != null) {
                    language_combobox.append (lang_id, language.name);
                }
            }
            
            // Устанавливаем язык по умолчанию
            var default_lang = settings.get_string ("default-programming-language");
            if (default_lang != "" && language_combobox.get_active_id () != default_lang) {
                language_combobox.active_id = default_lang;
            } else {
                language_combobox.active = 0;
            }
            
            random_code_button.sensitive = true;
            simulate_typing_button.sensitive = true;
        }

         // Добавляем горячие клавиши
        private void setup_programming_shortcuts () {
            var controller = new Gtk.EventControllerKey ();
            
            controller.key_pressed.connect ((keyval, keycode, state) => {
                var modifiers = state & Gtk.accelerator_get_default_mod_mask ();
                
                // Ctrl+G - сгенерировать случайный код
                if (keyval == Gdk.Key.g && modifiers == Gdk.ModifierType.CONTROL_MASK) {
                    on_generate_random_code ();
                    return true;
                }
                
                // Ctrl+S - предложить слово
                if (keyval == Gdk.Key.s && modifiers == Gdk.ModifierType.CONTROL_MASK) {
                    on_suggest_word ();
                    return true;
                }
                
                // Ctrl+T - симуляция набора
                if (keyval == Gdk.Key.t && modifiers == Gdk.ModifierType.CONTROL_MASK) {
                    on_simulate_typing ();
                    return true;
                }
                
                // Ctrl+L - очистить
                if (keyval == Gdk.Key.l && modifiers == Gdk.ModifierType.CONTROL_MASK) {
                    on_clear_code ();
                    return true;
                }
                
                return false;
            });
            
            code_textview.add_controller (controller);
            quick_input_entry.add_controller (controller);
        }
    }
}

        private void build_ui()
        {
            //хедер
            var header = new Adw.HeaderBar();
            header.show_title = true;

            //кнопка меню
            var menu_button = new Gtk.MenuButton();
            menu_button.icon_name = "open-menu-symbolic";
            menu_button.tooltip_text = _("Menu");

            var menu = new GLib.Menu();
            menu.append (_("Statistics"), "win.show-stats");
            menu.append (_("Preferences"), "win.preferences");
            menu.append (_("keyboard shortcuts"), "win.shortcuts");
            menu.append (_("About Stamina"), "win.about");
            menu.append (_("Quit"), "win.quit");

            var menu_model = new Menu();
            menu_model.append_section (null, menu);
            menu_button.set_menu_model (menu_model);
            header.pack_end (menu_button);

            // основное содержимое
            var main_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 24);
            main_box.margin_top = 24;
            main_box.margin_bottom = 24;
            main_box.margin_start = 24;
            main_box.margin_end = 24;
            main_box.vexpand = true;
            main_box.valign = Gtk.Align.CENTER;

            // метка статуса
            status_label = new Gtk.Label (null)
            {
                halign = Gtk.Align.CENTER,
                css_classes = {"title-1"}
            };

            // основной стек
            main_stack = new Gtk.Stack()
            {
                transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT,
                transition_duration = 200
            };
            view_stack = new Adw.ViewStack();

             var timer_view = build_timer_view ();
            view_stack.add_titled (timer_view, "timer", _("Timer"));
            view_stack.add_titled (build_programming_view (), "programming", _("Programming"));
            view_stack.add_titled (build_statistics_view (), "statistics", _("Statistics"));
            
            var view_switcher = new Adw.ViewSwitcher () {
                stack = view_stack,
                policy = Adw.ViewSwitcherPolicy.WIDE
            };
            
            var header_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            header_box.append (header);
            header_box.append (view_switcher);
            
            // Добавляем стек в основное содержимое
            var main_content = new Adw.ToolbarView ();
            main_content.add_top_bar (header_box);
            main_content.set_content (view_stack);
            
            content = main_content;

            // таймер
            timer_label = new Gtk.Label ("25.00")
            {
              halign = Gtk.Align.CENTER,
              css_classes = {"title-1", "monospace"},
              margin_top = 12
            };

            // прогресс бар
            progress_bar = new Gtk.ProgressBar()
            {
                  halign = Gtk.Align.CENTER,
                  margin_top = 24,
                  margin_botton = 24,
                  height_request = 8
            };
            progress_bar.add_css_class ("osd");

            // панель настроек таймера
            var timer_button_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12)
            {
              halign = Gtk.Align.CENTER,
              homogeneous = true
            };

            start_button = new Gtk.Button.with_label (_("Start"));
            start_button.add_css_class ("suggested-action");
            start_button.tooltip_text = _("Start timer (Ctrl+S"));

            pause_button = new Gtk.Button.with_label (_("Pause"));
            pause_button.sensitive = false;
            pause_button.tooltip_text = _("Pause timer (Ctrl+P"));

            reset_button = new Gtk.Button.with_label (_("Reset"));

            reset_button.tooltip_text = _("Reset timer (Ctrl+R"));
            timer_button_box.append (start_button);
            timer_button_box.append (pause_button);
            timer_button_box.append (reset_button);

            // Панель кнопок перерыва
            var break_button_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12)
            {
                halign = Gtk.Align.CENTER,
                homogeneous = true
            };

            short_break_button = new Gtk.Button.with_label (_("Short Break"));
            short_break_button.tooltip_text = _("Start short break (Ctrl + B)");

            long_break_button = new Gtk.Button.with_label (_("Long Break"));
            long_break_button.tooltip_text = _("Start long break (Ctrl + Shift + B)");

            break_button_box.append (short_break_button);
            break_button_box.append (long_break_button);

            // добавление элементов
            main_box.append (status_label);
            main_box.append (time_label);
            main_box.append (progress_bar);
            main_box.append (timer_button_box);
            main_box.append (break_button_box);

            // создание прокручиваемой области
            var scrolled = new Gtk.SrolledWindow();
            scrolled.child = main_box;
            scrolled.vexpand = true;

            // главный вид
            var toolbar_view = new Adw.ToolbarView();
            toolbar_view.add_top_bar (header);
            toolbar_view.content = scrolled;

            content = toolbar_view;

            // настройка доступности
            setup_accessibility();
        }

        private Gtk.Widget build_programming_view () {
            var main_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            main_box.margin_top = 12;
            main_box.margin_bottom = 12;
            main_box.margin_start = 12;
            main_box.margin_end = 12;
            
            // Панель выбора языка
            var language_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            language_box.halign = Gtk.Align.CENTER;
            
            var language_label = new Gtk.Label (_("Language:")) {
                halign = Gtk.Align.END
            };
            
            language_combobox = new Gtk.ComboBoxText () {
                halign = Gtk.Align.START,
                valign = Gtk.Align.CENTER,
                hexpand = true
            };
            
            // Быстрый ввод
            var quick_input_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            quick_input_box.margin_top = 6;
            quick_input_box.halign = Gtk.Align.FILL;
            
            quick_input_entry = new Gtk.Entry () {
                placeholder_text = _("Type code here or use suggestions..."),
                hexpand = true
            };
            
            suggest_word_button = new Gtk.Button () {
                label = _("Suggest"),
                tooltip_text = _("Suggest random programming word")
            };
            suggest_word_button.clicked.connect (on_suggest_word);
            
            quick_input_box.append (quick_input_entry);
            quick_input_box.append (suggest_word_button);
            
            // Основное текстовое поле для кода
            var scrolled = new Gtk.ScrolledWindow () {
                hexpand = true,
                vexpand = true,
                margin_top = 12,
                margin_bottom = 12
            };
            
            code_textview = new Gtk.TextView () {
                wrap_mode = Gtk.WrapMode.WORD_CHAR,
                monospace = true,
                top_margin = 6,
                bottom_margin = 6,
                left_margin = 6,
                right_margin = 6
            };
            
            // Настраиваем подсветку синтаксиса
            setup_syntax_highlighting ();
            
            scrolled.set_child (code_textview);
            
            // Панель кнопок
            var button_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            button_box.halign = Gtk.Align.CENTER;
            button_box.margin_top = 6;
            
            random_code_button = new Gtk.Button.with_label (_("Generate Random Code"));
            random_code_button.tooltip_text = _("Generate random code snippet in selected language");
            random_code_button.clicked.connect (on_generate_random_code);
            
            simulate_typing_button = new Gtk.Button.with_label (_("Simulate Typing"));
            simulate_typing_button.tooltip_text = _("Simulate typing in selected language");
            simulate_typing_button.clicked.connect (on_simulate_typing);
            
            clear_button = new Gtk.Button.with_label (_("Clear"));
            clear_button.tooltip_text = _("Clear code editor");
            clear_button.clicked.connect (on_clear_code);
            
            button_box.append (random_code_button);
            button_box.append (simulate_typing_button);
            button_box.append (clear_button);
            
            // Информационная панель
            var info_label = new Gtk.Label (_("Use this area to practice programming while tracking your focus time.")) {
                wrap = true,
                justify = Gtk.Justification.CENTER,
                css_classes = {"dim-label"},
                margin_top = 12
            };
            
            // Собираем всё вместе
            language_box.append (language_label);
            language_box.append (language_combobox);
            
            main_box.append (language_box);
            main_box.append (quick_input_box);
            main_box.append (scrolled);
            main_box.append (button_box);
            main_box.append (info_label);
            
            // Заполняем комбобокс
            populate_language_combobox ();
            
            return main_box;
        }

        private void connect_signals()
        {
            // кнопки таймера
            start_button.clicked.connect(() => {
               timer.start();
                update_buttons();
            });

            pause_button.clicked.connect(() => {
                timer_pause();
                update_buttons();
            });

            reset_button.clicked.connect(() => {
               timer.reset();
                update_display();
                update_buttons();
            });

            //кнопки перерыва
            short_break.clicked.connect(() => {
                timer.start_break (false);
                update_display();
                update_buttons();
            });

            long_break.clicked.connect(() => {
                timer.start_break (true);
                update_display();
                update_buttons();
            });

            // события таймера
            timer.notify["remaining-seconds"].connect (update_display);
            timer.notify["is-running"].connect (update_button);
            timer.tick.connect (on_tick);
            timer.completed.connect (on_timer_completed);

            //настройка действий
            setup_actions();
        }

        private void setup_actions()
        {
            var action_group = new GLib.SimpleActionGroup();

            // действия таймера
            var start_action = new GLib.SimpleAction ("start", null);
            start_action.activate.connect(() => start_button.activate());
            action_group.add_action (start_action);

            var pause_action = new GLib.SimpleAction ("pause", null);
            pause_action.activate.connect(() => pause_button.activate());
            action_group.add_action (pause_action);

            var pause_action = new GLib.SimpleAction ("reset", null);
            reset_action.activate.connect(() => reset_button.activate());
            action_group.add_action (reset_action);

            var short_break_action = new GLib.SimpleAction ("short-break", null);
            short_break_action.activate.connect(() => short_break_button.activate());
            action_group.add_action (short_break_action);

            var long_break_action = new GLib.SimpleAction ("long-break", null);
            long_break_action.activate.connect(() => long_break_button.activate());
            action_group.add_action (long_break_action);

            // действия окон
            var preferences_action = new GLib.SimpleAction ("preferences", null);
            preferences_action.activate.connect (show_preferences);
            action_group.add_action (preferences_action);

            var about_action = new GLib.SimpleAction ("about", null);
            about_action.activate.connect (show_about);
            action_group.add_action (about_action);

            var shortcuts_action = new GLib.SimpleAction ("shortcuts", null);
            shortcuts_action.activate.connect (show_shortcuts);
            action_group.add_action (shortcuts_action);

            var show_stats_action = new GLib.SimpleAction ("show-stats", null);
            show_stats_action.activate.connect (show_statistics);
            action_group.add_action (show_stats_action);

            insert_action_group ("win", action_group);
        }

        private void setup_accessibility()
        {
            // настройка доступных имен
            timer_label.accessible_label = _("Timer display");
            progress_bar.accessible_label = _("Progress indicator");

            // настройка ролей
            start_button.accessible_role = ATK.Role.PUSH_BUTTON;
            pause_button.accessible_role = ATK.Role.PUSH_BUTTON;
            reset_button.accessible_role = ATK.Role.PUSH_BUTTON;

            // подсказки для доступности
            start_button.tooltip_text = _("Start the timer");
            pause_button.tooltip_text = _("Pause the timer");
            reset_button.tooltip_text = _("Reset the timer to initial state");
        }

        private void update_display()
        {
            int minutes = timer.remaining_seconds / 60;
            int seconds = timer.remaining_seconds % 60;

            timer_label.label = "%02d:%02d".printf (minutes, seconds);
            status_label.label = timer.is_work_time ? _("Focus Time") : _("Break Time");

            // обновление прогресса
            double progress = 1.0 - ((double)timer.remaining_second / (double)timer.total_seconds);
            progress_bar.fraction = progress;

            // Динамическое обновление цвета
            if (timer.remaining_seconds < 60) {
                timer_label.add_css_class ("error");
            } else {
                timer_label.remove_css_class ("error");
            }
        }

        private void update_buttons()
        {
            start_button.sensitive = !timer.is_running;
            pause_button.sensitive = timer.is_running;

            // Обновление доступных имен для программ чтения с экрана
            if  (timer.is_running) {
                start_button.accessible_label = _("Timer is running");
            } else {
                start_button.accessible_label = _("Start timer");
            }
        }

        private void update_theme()
        {
            var style_man = Adw.StyleManager.get_default();

            // применение стиля в соответствии с системными настройками
            if (style_manager.dark) {
                add_css_class ("dark");
            } else {
                remove_css_class ("dark");
            }
        }

        private void on_tick() {
            // уведомление за 60 секунд до конца
            if (timer.remaining_seconds == 60) {
                show_notification (_("One minute remaining"));
            }
        }

        private void show_notification (string message)
        {
            if (!settings.get_boolean ("enable-notifications")) {
                return;
            }

            var notification = new GLib.Notification (_("Stamina"));
            notification.set_body (message);

            if (settings.get_boolean ("sound-notifications")) {
                notification.set_default_action ("app.beep");
            }

            application.send_notification ("timer-notification", notification);
        }

        private void show_preferences()
        {
            var prefs = new Preferences (this);
            prefs.present();
        }

        private void show_about()
        {
            var about = new Adw.AboutWindow();
            about.transient_for = this;
            about.application_name = _("Stamina");
            about.application_icon = "org.intsoftware.Stamina";
            about.version = Config.PACKAGE_VERSION;
            about.developers = {"Aleksandr Silaev <sasasilaev27@gmail.com>"};
            about.designers = {"Aleksandr Silaev <sasasilaev27@gmail.com>"};
            about.license_type = Gtk.License.Apache_2_0;
            about.website = "https://github.com/gnom2949/Stamina";
            about.issue_url = "https://github.com/gnom2949/Stamina";
            about.copyright = "© 2026 Aleksandr Silaev";
            about.license = ("Apache-2.0 License");

            about.present();
        }

        private void show_shortcuts()
        {
            var builder = new Gtk.Builder.from_resource(
                "org/intsoftware/Stamina/shortcuts.ui");

            var shortcuts = (Gtk.ShortcutsWindow) builder.get_object ("shortcuts");
            shortcuts.transient_for = this;
            shortcuts.present();
        }

        private void show_statistics()
        {
            var stats = new Adw.PreferencesWindow();
            stats.transient_for = this;
            stats.title = _("Statistics");

            var page = new Adw.PreferencesPage();
            var group = new Adw.PreferencesGroup();

            var sessions_row = new Adw.ActionRow()
            {
                title = _("Completed Sessions"),
                subtitle = timer.completed_sessions.to_string()
            };

            var time_row = new Adw.ActionRow()
            {
                title = _("Total Focus Time"),
                subtitle = _("%d minutes").printf (timer.completed_sessions * 25)
            };

            group.add (sessions_row);
            group.add (time_row);
            page.add (group);
            stats.add (page);

            stats.present();
        }

        public override void close_request()
        {
            // сохранение состояния окна
            settings.set_int ("window-width", default_width);
            settings.set_int ("window-height", default_height);
            settings.set_boolean ("window-maximized", maximized);

            // Сохранение состояния таймера
            timer.save_state();

            return base.close_request();
        }
    }
}
