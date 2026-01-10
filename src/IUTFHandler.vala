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
    namespace IUTFHandler {
        
        public class IUTFData : Object {
            public string title { get; set; }
            public int version { get; set; }
            public long version_long { get; set; }
            public double version_float { get; set; }
            public char grade { get; set; }
            public string[] authors { get; set; }
            public IUTFMeta meta { get; set; }
            public string license { get; set; }
            public string readme { get; set; }
            public Gee.HashMap<string, Variant>? extensions { get; set; }
            
            public IUTFData () 
            {
                authors = {};
                meta = new IUTFMeta ();
                extensions = new Gee.HashMap<string, Variant> ();
            }
        }
        
        public class IUTFMeta : Object {
            public string ci_status { get; set; default = "Status"; }
            public DateTime created { get; set; }
            public bool is_public { get; set; default = true; }
            public string[] tags { get; set; }
            
            public IUTFMeta () 
            {
                tags = {};
                created = new DateTime.now_local ();
            }
        }
        
        public class ProgrammingSession : Object {
            public string id { get; set; }
            public DateTime start_time { get; set; }
            public DateTime end_time { get; set; }
            public string language { get; set; }
            public int duration_seconds { get; set; }
            public string? project_name { get; set; }
            public string[] tags { get; set; }
            public string? notes { get; set; }
            
            public ProgrammingSession () {
                id = GLib.Uuid.string_random ();
                tags = {};
                start_time = new DateTime.now_local ();
            }
        }
        
        public class SessionStats : Object {
            public string language { get; set; }
            public int total_sessions { get; set; }
            public int total_seconds { get; set; }
            public DateTime last_session { get; set; }
            
            public SessionStats (string lang) {
                language = lang;
                last_session = new DateTime.from_unix_utc (0);
            }
        }
        
        public static IUTFData? load_from_file (string path) throws Error 
        {
            var file = File.new_for_path (path);
            if (!file.query_exists ()) {
                return null;
            }
            
            uint8[] contents;
            file.load_contents (null, out contents, null);
            string content = (string) contents;
            
            return parse_iutf (content);
        }
        
        public static IUTFData? parse_iutf (string content) throws Error 
        {
            var parser = new IUTF.Parser (content);
            var root = parser.parse ();
            
            if (root == null || !IUTF.validate (root)) {
                throw new Error (Quark.from_string ("iutf"), 1, "Invalid IUTF format");
            }
            
            var data = new IUTFData ();
            
            // Парсим основную ветку
            if (root.type == IUTF.NodeType.BRANCH) {
                foreach (var node in root.branch_items) {
                    parse_node (node, data);
                }
            }
            
            parser.free ();
            return data;
        }
        
        private static void parse_node (IUTF.Node node, IUTFData data) 
        {
            if (node.type != IUTF.NodeType.KEY_VALUE) {
                return;
            }
            
            var key = node.key.down ();
            var value_node = node.branch_items[0];
            
            switch (key) 
            {
                case "title":
                    if (value_node.type == IUTF.NodeType.STRING) {
                        data.title = value_node.str_value;
                    }
                    break;
                    
                case "version":
                    if (value_node.type == IUTF.NodeType.INTEGER) {
                        data.version = (int) value_node.int_value;
                    }
                    break;
                    
                case "version_long":
                    if (value_node.type == IUTF.NodeType.LONG) {
                        data.version_long = value_node.long_value;
                    }
                    break;
                    
                case "versionf":
                case "rnd":
                    if (value_node.type == IUTF.NodeType.FLOAT) {
                        data.version_float = value_node.float_value;
                    }
                    break;
                    
                case "char":
                case "grade":
                    if (value_node.type == IUTF.NodeType.CHARACTER) {
                        data.grade = value_node.char_value;
                    }
                    break;
                    
                case "authors":
                    if (value_node.type == IUTF.NodeType.ARRAY) {
                        var authors = new Gee.ArrayList<string> ();
                        foreach (var item in value_node.array_items) {
                            if (item.type == IUTF.NodeType.STRING) {
                                authors.add (item.str_value);
                            }
                        }
                        data.authors = authors.to_array ();
                    }
                    break;
                    
                case "meta":
                    if (value_node.type == IUTF.NodeType.BRANCH) {
                        data.meta = parse_meta_branch (value_node);
                    }
                    break;
                    
                case "license":
                    if (value_node.type == IUTF.NodeType.BIGSTRING) {
                        data.license = value_node.str_value;
                    }
                    break;
                    
                case "readme":
                    if (value_node.type == IUTF.NodeType.PIPESTRING) {
                        data.readme = value_node.str_value;
                    }
                    break;
                    
                default:
                    // Сохраняем как расширение
                    var variant = node_to_variant (value_node);
                    if (variant != null) {
                        data.extensions[key] = variant;
                    }
                    break;
            }
        }
        
        private static IUTFMeta parse_meta_branch (IUTF.Node branch) 
        {
            var meta = new IUTFMeta ();
            
            foreach (var node in branch.branch_items) {
                if (node.type != IUTF.NodeType.KEY_VALUE) {
                    continue;
                }
                
                var key = node.key.down ();
                var value_node = node.branch_items[0];
                
                switch (key) {
                    case "ci":
                    case "ci:status":
                        if (value_node.type == IUTF.NodeType.STRING) {
                            meta.ci_status = value_node.str_value;
                        }
                        break;
                        
                    case "created":
                        if (value_node.str_value == "[tms]") {
                            meta.created = new DateTime.now_local ();
                        } else if (value_node.type == IUTF.NodeType.STRING) {
                            try {
                                meta.created = new DateTime.from_iso8601 (value_node.str_value, null);
                            } catch (Error e) {
                                meta.created = new DateTime.now_local ();
                            }
                        }
                        break;
                        
                    case "public":
                        if (value_node.type == IUTF.NodeType.BOOLEAN) {
                            meta.is_public = value_node.bool_value;
                        }
                        break;
                        
                    case "tags":
                        if (value_node.type == IUTF.NodeType.ARRAY) {
                            var tags = new Gee.ArrayList<string> ();
                            foreach (var item in value_node.array_items) {
                                if (item.type == IUTF.NodeType.STRING) {
                                    tags.add (item.str_value);
                                }
                            }
                            meta.tags = tags.to_array ();
                        }
                        break;
                }
            }
            
            return meta;
        }
        
        private static Variant? node_to_variant (IUTF.Node node) {
            switch (node.type) {
                case IUTF.NodeType.STRING:
                    return new Variant.string (node.str_value);
                    
                case IUTF.NodeType.INTEGER:
                    return new Variant.int64 (node.int_value);
                    
                case IUTF.NodeType.FLOAT:
                    return new Variant.double (node.float_value);
                    
                case IUTF.NodeType.LONG:
                    return new Variant.int64 (node.long_value);
                    
                case IUTF.NodeType.CHARACTER:
                    return new Variant.string (node.char_value.to_string ());
                    
                case IUTF.NodeType.BOOLEAN:
                    return new Variant.boolean (node.bool_value);
                    
                case IUTF.NodeType.ARRAY:
                    var builder = new VariantBuilder (VariantType.ARRAY);
                    foreach (var item in node.array_items) {
                        var item_variant = node_to_variant (item);
                        if (item_variant != null) {
                            builder.add_value (item_variant);
                        }
                    }
                    return builder.end ();
                    
                case IUTF.NodeType.BRANCH:
                    var builder = new VariantBuilder (VariantType.VARDICT);
                    foreach (var branch_node in node.branch_items) {
                        if (branch_node.type == IUTF.NodeType.KEY_VALUE) {
                            var value = node_to_variant (branch_node.branch_items[0]);
                            if (value != null) {
                                builder.add ("{sv}", branch_node.key, value);
                            }
                        }
                    }
                    return builder.end ();
                    
                default:
                    return null;
            }
        }
        
        public static string serialize_session (ProgrammingSession session) {
            var builder = new StringBuilder ();
            
            builder.append (@"iutf:init:session_$(session.id) {\n");
            builder.append (@"    id: \"$(session.id)\"\n");
            builder.append (@"    language: \"$(session.language)\"\n");
            builder.append (@"    start_time: \"$(session.start_time.format_iso8601 ())\"\n");
            builder.append (@"    end_time: \"$(session.end_time.format_iso8601 ())\"\n");
            builder.append (@"    duration_seconds: $(session.duration_seconds)\n");
            
            if (session.project_name != null) {
                builder.append (@"    project: \"$(session.project_name)\"\n");
            }
            
            if (session.tags.length > 0) {
                builder.append ("    tags: [");
                for (int i = 0; i < session.tags.length; i++) {
                    builder.append (@"\"$(session.tags[i])\"");
                    if (i < session.tags.length - 1) {
                        builder.append (", ");
                    }
                }
                builder.append ("]\n");
            }
            
            if (session.notes != null && session.notes != "") {
                builder.append ("    notes: |\n");
                var lines = session.notes.split ("\n");
                foreach (var line in lines) {
                    builder.append (@"        $(line)\n");
                }
                builder.append ("    |\n");
            }
            
            builder.append ("    meta {\n");
            builder.append ("        created[tms]\n");
            builder.append ("        type: \"programming_session\"\n");
            builder.append ("        app: \"Stamina\"\n");
            builder.append ("        version: 1.0\n");
            builder.append ("    }\n");
            builder.append ("}\n");
            
            return builder.str;
        }
        
        public static ProgrammingSession? deserialize_session (string iutf_content) {
            try {
                var data = parse_iutf (iutf_content);
                if (data == null) {
                    return null;
                }
                
                var session = new ProgrammingSession ();
                session.id = data.extensions["id"]?.get_string () ?? GLib.Uuid.string_random ();
                session.language = data.extensions["language"]?.get_string () ?? "unknown";
                
                var start_time_str = data.extensions["start_time"]?.get_string ();
                if (start_time_str != null) {
                    session.start_time = new DateTime.from_iso8601 (start_time_str, null);
                }
                
                var end_time_str = data.extensions["end_time"]?.get_string ();
                if (end_time_str != null) {
                    session.end_time = new DateTime.from_iso8601 (end_time_str, null);
                }
                
                session.duration_seconds = (int) (data.extensions["duration_seconds"]?.get_int64 () ?? 0);
                session.project_name = data.extensions["project"]?.get_string ();
                
                var tags_variant = data.extensions["tags"];
                if (tags_variant != null && tags_variant.is_of_type (VariantType.ARRAY)) {
                    var tags = new Gee.ArrayList<string> ();
                    var n_children = tags_variant.n_children ();
                    for (int i = 0; i < n_children; i++) {
                        tags.add (tags_variant.get_child_value (i).get_string ());
                    }
                    session.tags = tags.to_array ();
                }
                
                session.notes = data.extensions["notes"]?.get_string ();
                
                return session;
            } catch (Error e) {
                warning ("Failed to deserialize session: %s", e.message);
                return null;
            }
        }
        
        public static string create_config_template () 
        {
            return """
iutf:init:main {
    #! Stamina Configuration Template
    title: "Stamina Configuration"
    version: 1
    versionL: 1L
    versionF: 1.0
    char: 'S'
    authors: ["Stamina User"]
    
    meta {
        CI: Stable
        created[tms]
        public: true
        tags: [productivity, timer, gnome, programming]
    }
    
    config {
        #! Timer Settings
        work_duration: 25        #! minutes
        break_duration: 5        #! minutes
        long_break_duration: 15  #! minutes
        sessions_before_long_break: 4
        
        #! Auto-start Settings
        auto_start_break: true
        auto_start_work: false
        auto_start_timer: false
        
        #! Notification Settings
        enable_notifications: true
        sound_notifications: true
        warning_notification: true
        
        #! Appearance
        color_scheme: "default"  #! default, light, dark
        show_progress_bar: true
        enable_animations: true
        
        #! Tracking
        track_programming_languages: true
        languages: [
            "python", "javascript", "java", "c", "cpp",
            "rust", "go", "typescript", "html", "css"
        ]
    }
    
    stats {
        #! Statistics will be auto-populated
        total_sessions: 0
        total_focus_time: 0  #! minutes
        total_breaks: 0
        last_reset[tms]
    }
    
    sessions::init {
        #! Programming sessions will be stored here
        #! Each session is stored as a separate branch
    }
    
    license: BigString[
        GNU GENERAL PUBLIC LICENSE
        Version 3, 29 June 2007
        
        Copyright (C) 2007 Free Software Foundation, Inc.
        <https://fsf.org/>
        
        Everyone is permitted to copy and distribute verbatim copies
        of this license document, but changing it is not allowed.
    ]
    
    readme: |
        # Stamina Configuration
        
        This is the configuration file for Stamina, a productivity
        timer application for GNOME.
        
        ## Editing
        
        You can edit this file to customize Stamina's behavior.
        Changes will take effect after restarting the application.
        
        ## Structure
        
        - config: Application settings
        - stats: Usage statistics
        - sessions: Recorded programming sessions
        
        ## Notes
        
        Time values are in minutes unless specified otherwise.
        The [tms] tag means timestamp (current time when saved).
    |
}
""";
        }
        
        public static bool save_to_file (string path, string content) throws Error 
        {
            var file = File.new_for_path (path);
            
            // Создаем директорию если не существует
            var parent = file.get_parent ();
            if (parent != null && !parent.query_exists ()) {
                parent.make_directory_with_parents ();
            }
            
            // Записываем файл
            var data_stream = new DataOutputStream (file.replace (null, false, FileCreateFlags.NONE));
            data_stream.put_string (content);
            data_stream.close ();
            
            return true;
        }
    }
}