/* IUTF.vapi
 *
 * Copyright 2026 Int Software, Aleksandr Silaev
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * 	http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

[CCode (cheader_filename = "iutf-lexer.h", cprefix = "iutf_")]
namespace IUTF {

    [CCode (cname = "IutfTokenType")]
    public enum TokenType {
        EOF,
        ERROR,
        BRANCH_OPEN,
        BRANCH_CLOSE,
        LBRACKET,
        RBRACKET,
        COLON,
        EQUALS,
        PIPE,
        COMMA,
        STRING,
        INTEGER,
        FLOAT,
        LONG,
        CHARACTER,
        TRUE,
        FALSE,
        NULL,
        IDENTIFIER,
        BIGSTRING_START,
        COMMENT_LINE,
        COMMENT_CPP,
        COMMENT_BLOCK_START,
        COMMENT_BLOCK_END
    }

    [CCode (cname = "IutfToken")]
    public struct Token {
        public TokenType type;
        public string start;
        public size_t length;
        public int line;
        public int col;
    }

    [CCode (cname = "IutfLexer")]
    public class Lexer {
        [CCode (cname = "iutf_lexer_new")]
        public Lexer(string input);
        [CCode (cname = "iutf_lexer_corrupt")] // если ты переименовал
        public void free();
        [CCode (cname = "iutf_lexer_next")]
        public Token next();
    }

    [CCode (cname = "IutfNode")]
    public class Node {
        public NodeType type;
        public string? key;
        public string? str_value;
        public long long int_value;
        public double float_value;
        public long long long_value;
        public char char_value;
        public bool bool_value;
        public Node[]? array_items;
        public Node[]? branch_items;

        [CCode (cname = "iutf_node_new")]
        public static Node new(NodeType type);
        [CCode (cname = "iutf_node_free")]
        public void free();
    }

    [CCode (cname = "IutfNodeType")]
    public enum NodeType {
        BRANCH,
        KEY_VALUE,
        STRING,
        INTEGER,
        FLOAT,
        LONG,
        CHARACTER,
        BOOLEAN,
        NULL,
        ARRAY,
        BIGSTRING,
        PIPESTRING
    }

    [CCode (cname = "IutfParser")]
    public class Parser {
        [CCode (cname = "iutf_parser_new")]
        public Parser(string input);
        [CCode (cname = "iutf_parser_free")]
        public void free();
        [CCode (cname = "iutf_parse")]
        public Node? parse();
    }

    [CCode (cname = "iutf_validate")]
    public bool validate(Node root);

}
