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
    public class LanguageEntry : Object {
        public string name { get; set; }
        public string id { get; set; }
        public string[] keywords { get; set; }
        public string[] operators { get; set; }
        public string[] punctuation { get; set; }
        public string[] builtins { get; set; }
        public string[] types { get; set; }
        public Gee.HashMap<string, Variant> metadata { get; set; }
        public int default_session_length { get; set; default = 25; }
        public int default_break_length { get; set; default = 5; }
        public double productivity_multiplier { get; set; default = 1.0; }
        
        public LanguageEntry () {
            keywords = {};
            operators = {};
            punctuation = {};
            builtins = {};
            types = {};
            metadata = new Gee.HashMap<string, Variant> ();
        }
        
        public string[] get_all_tokens () {
            var tokens = new Gee.ArrayList<string> ();
            
            foreach (var keyword in keywords) {
                tokens.add (keyword);
            }
            
            foreach (var op in operators) {
                tokens.add (op);
            }
            
            foreach (var punct in punctuation) {
                tokens.add (punct);
            }
            
            foreach (var builtin in builtins) {
                tokens.add (builtin);
            }
            
            foreach (var type in types) {
                tokens.add (type);
            }
            
            return tokens.to_array ();
        }
        
        public string get_random_token (Random random) {
            var all_tokens = get_all_tokens ();
            if (all_tokens.length == 0) {
                return "";
            }
            
            int index = random.int_range (0, all_tokens.length);
            return all_tokens[index];
        }
        
        public string generate_random_line (Random random, int max_tokens = 8) {
            var builder = new StringBuilder ();
            int num_tokens = random.int_range (3, max_tokens + 1);
            
            for (int i = 0; i < num_tokens; i++) {
                var token = get_random_token (random);
                
                // Добавляем пробелы между токенами
                if (i > 0 && !is_punctuation (token)) {
                    builder.append (" ");
                }
                
                builder.append (token);
                
                // Иногда добавляем пунктуацию
                if (random.next_double () < 0.2) {
                    var punct = get_random_punctuation (random);
                    builder.append (punct);
                }
            }
            
            // Добавляем завершающую пунктуацию
            if (random.next_double () < 0.7) {
                builder.append (random.next_double () < 0.5 ? ";" : "");
            }
            
            return builder.str;
        }
        
        private bool is_punctuation (string token) {
            foreach (var punct in punctuation) {
                if (punct == token) {
                    return true;
                }
            }
            return false;
        }
        
        private string get_random_punctuation (Random random) {
            if (punctuation.length == 0) {
                return "";
            }
            
            int index = random.int_range (0, punctuation.length);
            return punctuation[index];
        }
    }
    
    public class LanguageLoader : Object {
        private static LanguageLoader? instance = null;
        private Gee.HashMap<string, LanguageEntry> languages;
        private Random random;
        private string languages_dir;
        
        public signal void language_loaded (string language_id);
        public signal void all_languages_loaded ();
        
        public static LanguageLoader get_default () {
            if (instance == null) {
                instance = new LanguageLoader ();
            }
            return instance;
        }
        
        private LanguageLoader () {
            languages = new Gee.HashMap<string, LanguageEntry> ();
            random = new Random ();
            
            // Определяем директорию с языками
            languages_dir = Path.build_filename (
                Config.PACKAGE_DATA_DIR,
                "languages"
            );
        }
        
        public async void load_all_languages () {
            var dir = File.new_for_path (languages_dir);
            
            if (!dir.query_exists ()) {
                warning ("Languages directory does not exist: %s", languages_dir);
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
                    
                    if (name.has_suffix (".iutf")) {
                        var language_id = name.replace (".iutf", "");
                        load_language_from_file (language_id);
                    }
                }
                
                all_languages_loaded ();
                
            } catch (Error e) {
                warning ("Failed to load languages: %s", e.message);
            }
        }
        
        public void load_language_from_file (string language_id) {
            var filename = @"$(language_id).iutf";
            var filepath = Path.build_filename (languages_dir, filename);
            
            try {
                var language = parse_iutf_language (filepath);
                if (language != null) {
                    languages[language_id] = language;
                    language_loaded (language_id);
                    debug ("Loaded language: %s", language_id);
                }
            } catch (Error e) {
                warning ("Failed to load language %s: %s", language_id, e.message);
            }
        }
        
        private LanguageEntry? parse_iutf_language (string filepath) throws Error {
            var file = File.new_for_path (filepath);
            if (!file.query_exists ()) {
                throw new FileError.NOENT ("Language file does not exist");
            }
            
            uint8[] contents;
            file.load_contents (null, out contents, null);
            string content = (string) contents;
            
            var parser = new IUTF.Parser (content);
            var root = parser.parse ();
            
            if (root == null || !IUTF.validate (root)) {
                throw new Error (Quark.from_string ("iutf"), 1, "Invalid IUTF format");
            }
            
            var language = new LanguageEntry ();
            
            // Парсим основную ветку
            foreach (var node in root.branch_items) {
                if (node.type != IUTF.NodeType.KEY_VALUE) {
                    continue;
                }
                
                var key = node.key.down ();
                var value_node = node.branch_items[0];
                
                switch (key) {
                    case "title":
                        if (value_node.type == IUTF.NodeType.STRING) {
                            language.name = value_node.str_value;
                        }
                        break;
                        
                    case "language":
                        if (value_node.type == IUTF.NodeType.BRANCH) {
                            parse_language_branch (value_node, language);
                        }
                        break;
                }
            }
            
            parser.free ();
            return language;
        }
        
        private void parse_language_branch (IUTF.Node branch, LanguageEntry language) {
            foreach (var node in branch.branch_items) {
                if (node.type != IUTF.NodeType.KEY_VALUE) {
                    continue;
                }
                
                var key = node.key.down ();
                var value_node = node.branch_items[0];
                
                switch (key) {
                    case "name":
                        if (value_node.type == IUTF.NodeType.STRING) {
                            language.id = value_node.str_value;
                        }
                        break;
                        
                    case "keywords":
                        if (value_node.type == IUTF.NodeType.ARRAY) {
                            language.keywords = parse_string_array (value_node);
                        }
                        break;
                        
                    case "operators":
                        if (value_node.type == IUTF.NodeType.ARRAY) {
                            language.operators = parse_string_array (value_node);
                        }
                        break;
                        
                    case "punctuation":
                        if (value_node.type == IUTF.NodeType.ARRAY) {
                            language.punctuation = parse_string_array (value_node);
                        }
                        break;
                        
                    case "builtins":
                        if (value_node.type == IUTF.NodeType.ARRAY) {
                            language.builtins = parse_string_array (value_node);
                        }
                        break;
                        
                    case "types":
                        if (value_node.type == IUTF.NodeType.ARRAY) {
                            language.types = parse_string_array (value_node);
                        }
                        break;
                        
                    case "timer_settings":
                        if (value_node.type == IUTF.NodeType.BRANCH) {
                            parse_timer_settings (value_node, language);
                        }
                        break;
                        
                    default:
                        // Сохраняем как метаданные
                        var variant = IUTFHandler.node_to_variant (value_node);
                        if (variant != null) {
                            language.metadata[key] = variant;
                        }
                        break;
                }
            }
        }
        
        private string[] parse_string_array (IUTF.Node array_node) {
            var list = new Gee.ArrayList<string> ();
            
            foreach (var item in array_node.array_items) {
                if (item.type == IUTF.NodeType.STRING) {
                    list.add (item.str_value);
                }
            }
            
            return list.to_array ();
        }
        
        private void parse_timer_settings (IUTF.Node branch, LanguageEntry language) {
            foreach (var node in branch.branch_items) {
                if (node.type != IUTF.NodeType.KEY_VALUE) {
                    continue;
                }
                
                var key = node.key.down ();
                var value_node = node.branch_items[0];
                
                switch (key) {
                    case "default_session_length":
                        if (value_node.type == IUTF.NodeType.INTEGER) {
                            language.default_session_length = (int) value_node.int_value;
                        }
                        break;
                        
                    case "default_break_length":
                        if (value_node.type == IUTF.NodeType.INTEGER) {
                            language.default_break_length = (int) value_node.int_value;
                        }
                        break;
                        
                    case "productivity_multiplier":
                        if (value_node.type == IUTF.NodeType.FLOAT) {
                            language.productivity_multiplier = value_node.float_value;
                        }
                        break;
                }
            }
        }
        
        public Gee.Collection<string> get_available_languages () {
            return languages.keys;
        }
        
        public LanguageEntry? get_language (string language_id) {
            return languages[language_id];
        }
        
        public string? get_random_language_id () {
            if (languages.is_empty) {
                return null;
            }
            
            var keys = languages.keys.to_array ();
            int index = random.int_range (0, keys.length);
            return keys[index];
        }
        
        public string generate_random_code_snippet (string? language_id = null, int lines = 5) {
            LanguageEntry? language;
            
            if (language_id != null && languages.has_key (language_id)) {
                language = languages[language_id];
            } else {
                var random_lang = get_random_language_id ();
                if (random_lang == null) {
                    return "// No languages loaded";
                }
                language = languages[random_lang];
            }
            
            var builder = new StringBuilder ();
            
            // Добавляем комментарий с языком
            builder.append (@"// Random $(language.name) code snippet\n");
            builder.append ("// Generated by Stamina LanguageLoader\n\n");
            
            // Генерируем строки кода
            for (int i = 0; i < lines; i++) {
                builder.append (language.generate_random_line (random));
                builder.append ("\n");
                
                // Иногда добавляем пустую строку
                if (random.next_double () < 0.3 && i < lines - 1) {
                    builder.append ("\n");
                }
            }
            
            return builder.str;
        }
        
        public void push_random_words_to_entry (Gtk.Entry entry, string? language_id = null) {
            var text = generate_random_code_snippet (language_id, 1);
            entry.set_text (text);
            
            // Позиционируем курсор в конец
            entry.set_position (-1);
        }
        
        public void push_random_words_to_text_view (Gtk.TextView text_view, string? language_id = null) {
            var buffer = text_view.buffer;
            var text = generate_random_code_snippet (language_id, 3);
            
            buffer.set_text (text, text.length);
            
            // Позиционируем курсор в конец
            var iter = buffer.get_end_iter ();
            buffer.place_cursor (iter);
            
            // Прокручиваем вниз
            text_view.scroll_to_iter (iter, 0.0, false, 0.0, 0.0);
        }
        
        public string suggest_random_word (string? language_id = null) {
            LanguageEntry? language;
            
            if (language_id != null && languages.has_key (language_id)) {
                language = languages[language_id];
            } else {
                var random_lang = get_random_language_id ();
                if (random_lang == null) {
                    return "//";
                }
                language = languages[random_lang];
            }
            
            return language.get_random_token (random);
        }
        
        public void start_typing_simulation (Gtk.TextView text_view, string language_id, int interval_ms = 1000) {
            if (!languages.has_key (language_id)) {
                return;
            }
            
            var language = languages[language_id];
            var buffer = text_view.buffer;
            
            // Очищаем буфер
            buffer.set_text ("", 0);
            
            // Запускаем таймер для симуляции набора
            Timeout.add (interval_ms, () => {
                if (!text_view.get_realized ()) {
                    return false;
                }
                
                var word = language.get_random_token (random);
                if (word != "") {
                    var iter = buffer.get_end_iter ();
                    buffer.insert (ref iter, word + " ", -1);
                    
                    // Добавляем случайную пунктуацию
                    if (random.next_double () < 0.3 && language.punctuation.length > 0) {
                        var punct_index = random.int_range (0, language.punctuation.length);
                        buffer.insert (ref iter, language.punctuation[punct_index] + " ", -1);
                    }
                    
                    // Прокручиваем вниз
                    var end_iter = buffer.get_end_iter ();
                    text_view.scroll_to_iter (end_iter, 0.0, false, 0.0, 0.0);
                }
                
                return true; // Продолжаем
            });
        }
    }
}