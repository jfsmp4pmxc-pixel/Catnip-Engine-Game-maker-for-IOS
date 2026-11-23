//
//  Catnip Engine: game maker for IOS
//
//  Copyright (C) 2026 jfsmp4pmxc-pixel <ihhjnkk@gmail.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program. If not, see <https://www.gnu.org/licenses/>.
//

// MoreLanguages.swift
// Bộ luật tô màu cho Assembly, Fortran, PHP, Ruby, SQL, YAML, TOML/INI, Dart.
// Viết bằng raw string #"..."# để không phải nhân đôi dấu gạch chéo ngược.

import UIKit

extension SyntaxHighlighter {

    /// Bộ luật tổng quát: chú thích/chuỗi do người gọi đưa vào, phần còn lại theo danh sách từ khoá.
    private static func generic(comment: String, string: String, extras: [HighlightRule] = [],
                                keywords: String, bools: String, types: String = "",
                                ci: Bool = false,
                                funcPattern: String = #"\b[A-Za-z_]\w*(?=\s*\()"#) -> [HighlightRule] {
        let f = ci ? "(?i)" : ""
        var r: [HighlightRule] = [
            HighlightRule(kind: .comment, regex: re(comment)),
            HighlightRule(kind: .string, regex: re(string))
        ]
        r += extras
        r += [
            HighlightRule(kind: .number,  regex: re(#"\b(?:0[xX][0-9a-fA-F_]+|0[bB][01_]+|\d[\d_]*(?:\.\d+)?(?:[eEdD][+-]?\d+)?)\b"#)),
            HighlightRule(kind: .keyword, regex: re(f + #"\b(?:"# + keywords + #")\b"#)),
            HighlightRule(kind: .bool,    regex: re(f + #"\b(?:"# + bools + #")\b"#))
        ]
        if !types.isEmpty { r.append(HighlightRule(kind: .type, regex: re(f + #"\b(?:"# + types + #")\b"#))) }
        r += [
            HighlightRule(kind: .function, regex: re(funcPattern)),
            HighlightRule(kind: .op,       regex: re(#"->|=>|::|[+\-*/%=<>!&|^~?]+"#)),
            HighlightRule(kind: .punct,    regex: re(#"[{}()\[\];,.:]"#))
        ]
        return r
    }

    static func moreRules(for language: Language) -> [HighlightRule] {
        switch language {
        case .asm:
            return generic(
                comment: #";[^\n]*|//[^\n]*|/\*[\s\S]*?\*/|^[ \t]*#[^\n]*"#,
                string: #""(?:\\.|[^\\"\n])*"|'(?:\\.|[^\\'\n])*'"#,
                extras: [
                    HighlightRule(kind: .function,  regex: re(#"^[ \t]*[.A-Za-z_$@][\w.$@]*(?=:)"#)),
                    HighlightRule(kind: .decorator, regex: re(#"^[ \t]*\.[A-Za-z_]\w*|%(?:macro|endmacro|define|include|if|ifdef|ifndef|else|endif|rep|endrep|assign|undef)\b|(?i)\b(?:section|segment|global|globl|extern|bits|org|equ|db|dw|dd|dq|dt|resb|resw|resd|resq|times|align|default|use16|use32|use64|byte|word|dword|qword|ptr|offset|proc|endp|macro|endm|assume|model|stack|data|code)\b"#)),
                    HighlightRule(kind: .type, regex: re(#"(?i)%[a-z][a-z0-9]*|\b(?:[re]?(?:ax|bx|cx|dx|si|di|bp|sp|ip)|[abcd][lh]|sil|dil|bpl|spl|r(?:[89]|1[0-5])[dwb]?|[xyz]mm\d+|[cdefgs]s|[xw]\d{1,2}|lr|pc|xzr|wzr|st\d?|rflags|eflags)\b"#))
                ],
                keywords: #"mov|movzx|movsx|movsxd|movs[bwdq]?|push|pop|pusha|popa|pushf|popf|add|adc|sub|sbb|mul|imul|div|idiv|inc|dec|neg|not|and|or|xor|shl|shr|sar|sal|rol|ror|rcl|rcr|cmp|test|jmp|j[a-z]{1,3}|call|ret|retn|retf|leave|enter|lea|nop|int|iret|syscall|sysenter|sysret|hlt|cli|sti|cld|std|loop|loope|loopne|xchg|cmov[a-z]{1,3}|set[a-z]{1,3}|cpuid|rdtsc|ldr|ldrb|ldrh|str|strb|strh|ldp|stp|bl|blr|br|b|bx|cbz|cbnz|adr|adrp|svc|mvn|movk|movn|movz|orr|eor|lsl|lsr|asr|ubfx|sbfx|csel|cset|tst|stm|ldm|swi|rep|repe|repne|lock|cdq|cqo|cwd|cbw|bswap|bsf|bsr|popcnt|movaps|movups|movdqa|movdqu|pxor|paddd|addps|addpd|mulps|vmov[a-z]*|vadd[a-z]*"#,
                bools: "true|false|null", ci: true,
                funcPattern: #"(?i)(?<=\b(?:call|jmp|bl|b)\s)[.A-Za-z_$@][\w.$@]*"#)
        case .fortran:
            return generic(
                comment: #"!(?!\$)[^\n]*|^\*[^\n]*"#,
                string: #""(?:""|[^"\n])*"|'(?:''|[^'\n])*'"#,
                extras: [
                    HighlightRule(kind: .op, regex: re(#"(?i)\.(?:and|or|not|eq|ne|lt|le|gt|ge|eqv|neqv)\."#))
                ],
                keywords: "program|end|endif|enddo|endsubroutine|endfunction|endmodule|endprogram|endtype|endselect|endwhere|endinterface|subroutine|function|module|submodule|use|implicit|none|integer|real|double|precision|complex|logical|character|dimension|allocatable|allocate|deallocate|parameter|intent|in|out|inout|if|then|else|elseif|do|while|select|case|default|where|forall|call|return|stop|contains|interface|type|public|private|protected|save|external|intrinsic|goto|continue|exit|cycle|print|write|read|open|close|format|data|common|equivalence|pointer|target|optional|only|result|pure|elemental|recursive|kind|class|abstract|extends|procedure|block|associate|critical|concurrent|namelist|rewind|backspace|inquire|nullify|entry|include|volatile|value|bind",
                bools: #"true|false"#,
                types: "sqrt|sin|cos|tan|asin|acos|atan|atan2|exp|log|log10|abs|max|min|mod|modulo|size|shape|sum|product|maxval|minval|matmul|transpose|dot_product|reshape|nint|floor|ceiling|len|trim|adjustl|index|present|allocated|associated|epsilon|huge|tiny|selected_real_kind|selected_int_kind|iso_fortran_env|int32|int64|real32|real64",
                ci: true)
        case .php:
            return generic(
                comment: #"//[^\n]*|#(?!\[)[^\n]*|/\*[\s\S]*?\*/"#,
                string: #""(?:\\[\s\S]|[^\\"])*"|'(?:\\[\s\S]|[^\\'])*'|`[^`]*`"#,
                extras: [
                    HighlightRule(kind: .decorator, regex: re(#"<\?(?:php|=)?|\?>|#\[[^\]\n]*\]"#)),
                    HighlightRule(kind: .attr,      regex: re(#"\$+[A-Za-z_]\w*"#))
                ],
                keywords: "abstract|and|array|as|break|callable|case|catch|class|clone|const|continue|declare|default|do|echo|else|elseif|empty|enddeclare|endfor|endforeach|endif|endswitch|endwhile|enum|extends|final|finally|fn|for|foreach|function|global|goto|if|implements|include|include_once|instanceof|insteadof|interface|isset|list|match|namespace|new|or|print|private|protected|public|readonly|require|require_once|return|static|switch|throw|trait|try|unset|use|var|while|xor|yield|exit|die",
                bools: "true|false|null",
                types: "int|float|string|bool|array|object|mixed|void|self|parent|iterable|never|Exception|PDO|DateTime",
                ci: true)
        case .ruby:
            return generic(
                comment: #"^=begin[\s\S]*?^=end|#[^\n]*"#,
                string: #""(?:\\[\s\S]|[^\\"])*"|'(?:\\[\s\S]|[^\\'])*'|`[^`\n]*`"#,
                extras: [
                    HighlightRule(kind: .attr, regex: re(#"(?<![:\w]):[A-Za-z_]\w*[?!=]?|@@?[A-Za-z_]\w*|\$[A-Za-z_]\w*"#))
                ],
                keywords: #"alias|and|begin|break|case|class|def|do|else|elsif|end|ensure|for|if|in|module|next|not|or|redo|rescue|retry|return|self|super|then|undef|unless|until|when|while|yield|require|require_relative|include|extend|prepend|attr_accessor|attr_reader|attr_writer|puts|print|p|lambda|proc|raise|private|protected|public|loop"#,
                bools: "true|false|nil",
                types: "String|Integer|Float|Array|Hash|Symbol|Struct|Object|Class|Module|Comparable|Enumerable|Kernel|File|Dir|Time|Range|Regexp|Proc|IO|Math",
                funcPattern: #"\b[a-z_]\w*[?!]?(?=\s*[("'])"#)
        case .sql:
            return generic(
                comment: #"--[^\n]*|/\*[\s\S]*?\*/|#[^\n]*"#,
                string: #"'(?:''|[^'])*'|"(?:""|[^"])*"|`[^`]*`"#,
                keywords: "select|from|where|insert|into|values|update|set|delete|create|alter|drop|table|view|index|database|schema|trigger|procedure|function|join|inner|outer|left|right|full|cross|on|using|group|by|order|having|limit|offset|union|all|distinct|as|and|or|not|in|exists|between|like|ilike|is|case|when|then|else|end|begin|commit|rollback|transaction|primary|foreign|key|references|unique|check|default|constraint|add|column|rename|to|with|recursive|returning|asc|desc|if|replace|temporary|temp|explain|analyze|grant|revoke|pragma|vacuum",
                bools: "true|false|null",
                types: "int|integer|bigint|smallint|tinyint|serial|decimal|numeric|float|double|real|boolean|bool|char|varchar|text|blob|date|time|timestamp|datetime|json|jsonb|uuid|count|sum|avg|min|max|coalesce|nullif|cast|now|round|upper|lower|length|substr|substring|concat",
                ci: true)
        case .yaml:
            return [
                HighlightRule(kind: .comment,   regex: re(#"(?:^|\s)#[^\n]*"#)),
                HighlightRule(kind: .string,    regex: re(#""(?:\\.|[^\\"\n])*"|'(?:''|[^'\n])*'"#)),
                HighlightRule(kind: .doctype,   regex: re(#"^(?:---|\.\.\.)[ \t]*$"#)),
                HighlightRule(kind: .attr,      regex: re(#"^[ \t]*(?:-[ \t]+)*[A-Za-z_.${}\-][\w.\- ${}/]*(?=:(?:[ \t]|$))"#)),
                HighlightRule(kind: .decorator, regex: re(#"[&*][A-Za-z0-9_-]+|!!?[A-Za-z0-9_]+"#)),
                HighlightRule(kind: .number,    regex: re(#"(?<![\w.])-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?(?![\w.])"#)),
                HighlightRule(kind: .bool,      regex: re(#"(?i)(?<![\w.-])(?:true|false|null|yes|no|on|off|~)(?![\w.-])"#)),
                HighlightRule(kind: .punct,     regex: re(#"^[ \t]*-(?=[ \t])|[\[\]{},|>]"#))
            ]
        case .toml:
            return [
                HighlightRule(kind: .comment, regex: re(#"(?:^|[ \t])[#;][^\n]*"#)),
                HighlightRule(kind: .string,  regex: re(#""""[\s\S]*?"""|'''[\s\S]*?'''|"(?:\\.|[^\\"\n])*"|'[^'\n]*'"#)),
                HighlightRule(kind: .tag,     regex: re(#"^[ \t]*\[\[?[^\]\n]+\]\]?"#)),
                HighlightRule(kind: .attr,    regex: re(#"^[ \t]*[A-Za-z0-9_.\-]+(?=[ \t]*[=:])"#)),
                HighlightRule(kind: .number,  regex: re(#"(?<![\w.])[+-]?(?:0[xX][0-9a-fA-F_]+|\d[\d_]*(?:\.\d+)?(?:[eE][+-]?\d+)?)(?![\w.])"#)),
                HighlightRule(kind: .bool,    regex: re(#"\b(?:true|false)\b"#)),
                HighlightRule(kind: .op,      regex: re("=")),
                HighlightRule(kind: .punct,   regex: re(#"[\[\]{},]"#))
            ]
        case .twoo:
            return [
                HighlightRule(kind: .comment, regex: re(#"//[^\n]*|/\*[\s\S]*?\*/"#)),
                HighlightRule(kind: .string,  regex: re(#""(?:\\[\s\S]|[^\\"\n])*""#)),
                HighlightRule(kind: .decorator, regex: re(#"^[ \t]*#[ \t]*import\b"#)),
                HighlightRule(kind: .number,  regex: re(#"\b\d+(?:\.\d+)?\b"#)),
                HighlightRule(kind: .keyword, regex: re(#"\b(?:global|var|entry|db|define|obj|public|private|msg|if|else|while|break|continue|return|exit|and|or|not|to|input|len|element|random|system|drive|add|rm)\b"#)),
                HighlightRule(kind: .type,    regex: re(#"\b(?:int|float|string|drive)\b"#)),
                HighlightRule(kind: .bool,    regex: re(#"\b(?:true|false|nil)\b"#)),
                HighlightRule(kind: .attr,    regex: re(#"\b(?:black|red|green|yellow|blue|magenta|cyan|white|gray)\b"#)),
                HighlightRule(kind: .function,regex: re(#"\b[A-Za-z_]\w*(?=\s*\()"#)),
                HighlightRule(kind: .op,      regex: re(#"[+\-*/%=<>!^]+"#)),
                HighlightRule(kind: .punct,   regex: re(#"[{}()\[\];,.]"#))
            ]
        case .dart:
            return cLike(keywords: "abstract|as|assert|async|await|break|case|catch|class|const|continue|covariant|default|deferred|do|dynamic|else|enum|export|extends|extension|external|factory|final|finally|for|Function|get|hide|if|implements|import|in|interface|is|late|library|mixin|new|on|operator|part|required|rethrow|return|set|show|static|super|switch|sync|this|throw|try|typedef|var|void|while|with|yield",
                         bools: "true|false|null",
                         types: "int|double|num|bool|String|List|Map|Set|Future|Stream|Object|Iterable|Duration|DateTime|Widget|BuildContext|State|StatelessWidget|StatefulWidget",
                         preproc: nil, attr: #"@[A-Za-z_]\w*"#, rawStrings: true)
        default:
            return []
        }
    }
}
