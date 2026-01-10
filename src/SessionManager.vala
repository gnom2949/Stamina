/*
 * Copyright 2026 Aleksandr Silaev
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
    public class SessionManager : Object {
        private Settings settings;
        private Gee.HashMap<string, IUTFHandler.SessionStats> language_stats;
        private Gee.ArrayList<IUTFHandler.ProgrammingSession> recent_sessions;
        private string config_dir;
        private string sessions_dir;
        
        public signal void session_added (IUTFHandler.ProgrammingSession session);
        public signal void stats_updated ();
        
        public SessionManager () {
            settings = new Settings (Config.APP_ID);
            language_stats = new Gee.HashMap<string, IUTFHandler.SessionStats> ();
            recent_sessions = new Gee.ArrayList<IUTFHandler.ProgrammingSession> ();
            
            // Определяем пути
            config_dir = Path.build_filename (
                Environment.get_user_config_dir (), 
                "stamina"
            );
            sessions_dir = Path.build_filename (config_dir, "sessions");
            
            // Загружаем статистику
            load_stats ();
        }
        
        public void start_session (string language, string? project_name = null) {
            var session = new IUTFHandler.ProgrammingSession ();
            session.language = language;
            session.project_name = project_name;
            session.start_time = new DateTime.now_local ();
            
            // Добавляем теги
            var tags = new Gee.ArrayList<string> ();
            tags.add ("programming");
            tags.add (language);
            if (project_name != null) {
                tags.add (project_name);
            }
            session.tags = tags.to_array ();
            
            recent_sessions.add (session);
            session_added (session);
        }
        
        public void end_session (string session_id, string? notes = null) {
            foreach (var session in recent_sessions) {
                if (session.id == session_id) {
                    session.end_time = new DateTime.now_local ();
                    session.duration_seconds = (int) session.end_time.difference (session.start_time) / 1000000;
                    session.notes = notes;
                    
                    save_session (session);
                    update_stats (session);
                    break;
                }
            }
        }
        
        private void save_session (IUTFHandler.ProgrammingSession session) {
            try {
                // Создаем IUTF представление сессии
                var iutf_content = IUTFHandler.serialize_session (session);
                
                // Сохраняем в файл
                var filename = @"session_$(session.id).iutf";
                var filepath = Path.build_filename (sessions_dir, filename);
                
                IUTFHandler.save_to_file (filepath, iutf_content);
                
                // Также добавляем в общий файл статистики
                update_config_file (session);
                
            } catch (Error e) {
                warning ("Failed to save session: %s", e.message);
            }
        }
        
        private void update_config_file (IUTFHandler.ProgrammingSession session) {
            var config_file = Path.build_filename (config_dir, "stamina.iutf");
            
            try {
                string content;
                if (FileUtils.test (config_file, FileTest.EXISTS)) {
                    FileUtils.get_contents (config_file, out content);
                    
                    // Парсим существующий конфиг
                    var data = IUTFHandler.parse_iutf (content);
                    if (data == null) {
                        data = new IUTFHandler.IUTFData ();
                    }
                    
                    // Добавляем сессию в extensions
                    var session_variant = new Variant ("(ssxxsas)",
                        session.id,
                        session.language,
                        session.start_time.to_unix (),
                        session.end_time.to_unix (),
                        session.project_name ?? "",
                        session.tags
                    );
                    
                    data.extensions[@"session_$(session.id)"] = session_variant;
                    
                    // TODO: Реализовать сериализацию обратно в IUTF
                    // Пока сохраняем просто как JSON в IUTF-расширении
                    
                } else {
                    // Создаем новый конфиг с шаблоном
                    content = IUTFHandler.create_config_template ();
                }
                
                FileUtils.set_contents (config_file, content);
                
            } catch (Error e) {
                warning ("Failed to update config file: %s", e.message);
            }
        }
        
        private void update_stats (IUTFHandler.ProgrammingSession session) {
            if (!language_stats.has_key (session.language)) {
                language_stats[session.language] = new IUTFHandler.SessionStats (session.language);
            }
            
            var stats = language_stats[session.language];
            stats.total_sessions++;
            stats.total_seconds += session.duration_seconds;
            stats.last_session = session.end_time;
            
            save_stats ();
            stats_updated ();
        }
        
        private void load_stats () {
            var stats_file = Path.build_filename (config_dir, "stats.iutf");
            
            if (!FileUtils.test (stats_file, FileTest.EXISTS)) {
                return;
            }
            
            try {
                string content;
                FileUtils.get_contents (stats_file, out content);
                
                var data = IUTFHandler.parse_iutf (content);
                if (data == null) {
                    return;
                }
                
                // Загружаем статистику по языкам
                foreach (var entry in data.extensions.entries) {
                    if (entry.key.has_prefix ("stats_")) {
                        var lang = entry.key.substring (6);
                        var variant = entry.value;
                        
                        if (variant.is_of_type (VariantType.TUPLE)) {
                            var stats = new IUTFHandler.SessionStats (lang);
                            stats.total_sessions = (int) variant.get_child_value (0).get_int64 ();
                            stats.total_seconds = (int) variant.get_child_value (1).get_int64 ();
                            var last_session_timestamp = variant.get_child_value (2).get_int64 ();
                            
                            if (last_session_timestamp > 0) {
                                stats.last_session = new DateTime.from_unix_local (last_session_timestamp);
                            }
                            
                            language_stats[lang] = stats;
                        }
                    }
                }
                
            } catch (Error e) {
                warning ("Failed to load stats: %s", e.message);
            }
        }
        
        private void save_stats () {
            var builder = new StringBuilder ();
            
            builder.append ("iutf:init:stats {\n");
            builder.append ("    title: \"Stamina Statistics\"\n");
            builder.append ("    generated[tms]\n");
            builder.append ("    meta {\n");
            builder.append ("        type: \"statistics\"\n");
            builder.append ("        app: \"Stamina\"\n");
            builder.append ("        version: 1.0\n");
            builder.append ("    }\n\n");
            
            builder.append ("    summary {\n");
            builder.append (@"        total_languages: $(language_stats.size)\n");
            
            int total_sessions = 0;
            int total_seconds = 0;
            
            foreach (var stats in language_stats.values) {
                total_sessions += stats.total_sessions;
                total_seconds += stats.total_seconds;
            }
            
            builder.append (@"        total_sessions: $(total_sessions)\n");
            builder.append (@"        total_hours: $(total_seconds / 3600.0)\n");
            builder.append ("    }\n\n");
            
            builder.append ("    languages {\n");
            foreach (var entry in language_stats.entries) {
                var lang = entry.key;
                var stats = entry.value;
                
                builder.append (@"        $(lang) {\n");
                builder.append (@"            sessions: $(stats.total_sessions)\n");
                builder.append (@"            total_seconds: $(stats.total_seconds)\n");
                builder.append (@"            total_hours: $(stats.total_seconds / 3600.0)\n");
                builder.append (@"            last_session: \"$(stats.last_session.format_iso8601 ())\"\n");
                builder.append ("        }\n");
            }
            builder.append ("    }\n");
            
            builder.append ("}\n");
            
            try {
                var stats_file = Path.build_filename (config_dir, "stats.iutf");
                IUTFHandler.save_to_file (stats_file, builder.str);
            } catch (Error e) {
                warning ("Failed to save stats: %s", e.message);
            }
        }
        
        public Gee.Collection<IUTFHandler.SessionStats> get_language_stats () {
            return language_stats.values;
        }
        
        public Gee.Collection<IUTFHandler.ProgrammingSession> get_recent_sessions (int limit = 50) {
            var result = new Gee.ArrayList<IUTFHandler.ProgrammingSession> ();
            
            // Сортируем по времени (новые сначала)
            recent_sessions.sort ((a, b) => {
                return (int) (b.start_time.to_unix () - a.start_time.to_unix ());
            });
            
            int count = 0;
            foreach (var session in recent_sessions) {
                if (count >= limit) break;
                result.add (session);
                count++;
            }
            
            return result;
        }
        
        public void load_sessions_from_disk () {
            var dir = File.new_for_path (sessions_dir);
            if (!dir.query_exists ()) {
                return;
            }
            
            try {
                var enumerator = dir.enumerate_children (
                    "standard::*",
                    FileQueryInfoFlags.NONE
                );
                
                FileInfo info;
                while ((info = enumerator.next_file ()) != null) {
                    var name = info.get_name ();
                    if (name.has_suffix (".iutf") && name.has_prefix ("session_")) {
                        var file = dir.get_child (name);
                        
                        uint8[] contents;
                        file.load_contents (null, out contents, null);
                        string content = (string) contents;
                        
                        var session = IUTFHandler.deserialize_session (content);
                        if (session != null) {
                            recent_sessions.add (session);
                        }
                    }
                }
                
            } catch (Error e) {
                warning ("Failed to load sessions: %s", e.message);
            }
        }
        
        public string generate_report (DateTime? start_date = null, DateTime? end_date = null) {
            var builder = new StringBuilder ();
            
            builder.append ("iutf:init:report {\n");
            builder.append ("    title: \"Stamina Programming Report\"\n");
            builder.append ("    generated[tms]\n");
            builder.append ("    meta {\n");
            builder.append ("        type: \"report\"\n");
            builder.append ("        app: \"Stamina\"\n");
            builder.append ("        version: 1.0\n");
            builder.append ("    }\n\n");
            
            // Фильтруем сессии по дате
            var filtered_sessions = new Gee.ArrayList<IUTFHandler.ProgrammingSession> ();
            foreach (var session in recent_sessions) {
                bool include = true;
                
                if (start_date != null && session.start_time.compare (start_date) < 0) {
                    include = false;
                }
                if (end_date != null && session.start_time.compare (end_date) > 0) {
                    include = false;
                }
                
                if (include) {
                    filtered_sessions.add (session);
                }
            }
            
            builder.append ("    summary {\n");
            builder.append (@"        period_start: \"$(start_date?.format_iso8601 () ?? "all_time")\"\n");
            builder.append (@"        period_end: \"$(end_date?.format_iso8601 () ?? "now")\"\n");
            builder.append (@"        total_sessions: $(filtered_sessions.size)\n");
            
            int total_seconds = 0;
            var language_counts = new Gee.HashMap<string, int> ();
            var language_seconds = new Gee.HashMap<string, int> ();
            
            foreach (var session in filtered_sessions) {
                total_seconds += session.duration_seconds;
                
                if (!language_counts.has_key (session.language)) {
                    language_counts[session.language] = 0;
                    language_seconds[session.language] = 0;
                }
                
                language_counts[session.language] = language_counts[session.language] + 1;
                language_seconds[session.language] = language_seconds[session.language] + session.duration_seconds;
            }
            
            builder.append (@"        total_hours: $(total_seconds / 3600.0)\n");
            builder.append ("    }\n\n");
            
            builder.append ("    by_language {\n");
            foreach (var entry in language_counts.entries) {
                var lang = entry.key;
                var count = entry.value;
                var seconds = language_seconds[lang];
                
                builder.append (@"        $(lang) {\n");
                builder.append (@"            sessions: $(count)\n");
                builder.append (@"            total_seconds: $(seconds)\n");
                builder.append (@"            percentage: $((seconds * 100.0) / total_seconds)\n");
                builder.append (@"            average_session: $(seconds / (double)count)\n");
                builder.append ("        }\n");
            }
            builder.append ("    }\n\n");
            
            builder.append ("    recent_sessions {\n");
            int session_count = 0;
            foreach (var session in filtered_sessions) {
                if (session_count >= 20) break; // Ограничиваем количество
                
                builder.append (@"        session_$(session.id) {\n");
                builder.append (@"            language: \"$(session.language)\"\n");
                builder.append (@"            start_time: \"$(session.start_time.format_iso8601 ())\"\n");
                builder.append (@"            duration: $(session.duration_seconds)\n");
                
                if (session.project_name != null) {
                    builder.append (@"            project: \"$(session.project_name)\"\n");
                }
                
                builder.append ("        }\n");
                session_count++;
            }
            builder.append ("    }\n");
            
            builder.append ("}\n");
            
            return builder.str;
        }
        
        public void export_report (string filepath, string report_content) throws Error {
            IUTFHandler.save_to_file (filepath, report_content);
        }
    }
}