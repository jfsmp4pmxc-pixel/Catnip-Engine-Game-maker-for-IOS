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

import UIKit

// MARK: - Token kinds

enum TokenKind: String, CaseIterable, Codable {
    case comment, keyword, string, number, function, op, punct, tag, attr, bool, type, decorator, heading, doctype, color
}

// MARK: - Theme

struct Theme: Codable {
    var name: String
    var bg: String
    var bg2: String
    var bg3: String
    var fg: String
    var muted: String
    var accent: String
    var border: String
    var hover: String
    var tokens: [TokenKind: String]
    /// Theme do người dùng nhập có khoá dạng "custom:<tên file>"; theme có sẵn thì để nil.
    var key: String? = nil

    var bgColor: UIColor    { UIColor(hex: bg) ?? .black }
    var bg2Color: UIColor   { UIColor(hex: bg2) ?? .black }
    var bg3Color: UIColor   { UIColor(hex: bg3) ?? .darkGray }
    var fgColor: UIColor    { UIColor(hex: fg) ?? .white }
    var mutedColor: UIColor { UIColor(hex: muted) ?? .gray }
    var accentColor: UIColor{ UIColor(hex: accent) ?? .systemBlue }
    var borderColor: UIColor{ UIColor(hex: border) ?? .gray }
    var hoverColor: UIColor { UIColor(hex: hover) ?? .darkGray }

    func tokenColor(_ kind: TokenKind) -> UIColor {
        UIColor(hex: tokens[kind] ?? "") ?? fgColor
    }

    static let dark = Theme(
        name: "Dark (One Dark)",
        bg: "#282c34", bg2: "#21252b", bg3: "#1b1f23",
        fg: "#abb2bf", muted: "#7f848e", accent: "#61afef",
        border: "#3a3f4b", hover: "#2c313a",
        tokens: [
            .comment: "#5c6370", .keyword: "#c678dd", .string: "#98c379",
            .number: "#d19a66", .function: "#61afef", .op: "#56b6c2",
            .punct: "#abb2bf", .tag: "#e06c75", .attr: "#d19a66",
            .bool: "#d19a66", .type: "#e5c07b", .decorator: "#e5c07b",
            .heading: "#e06c75", .doctype: "#5c6370", .color: "#d19a66"
        ]
    )

    /// Màu lấy theo khối mã trong Markdown (hljs-github + github-markdown-light).
    static let light = Theme(
        name: "Light (GitHub)",
        bg: "#f6f8fa", bg2: "#eaeef2", bg3: "#dde3ea",
        fg: "#24292e", muted: "#6a737d", accent: "#0969da",
        border: "#d0d7de", hover: "#e3e8ee",
        tokens: [
            .comment: "#6a737d", .keyword: "#d73a49", .string: "#032f62",
            .number: "#005cc5", .function: "#6f42c1", .op: "#005cc5",
            .punct: "#24292e", .tag: "#22863a", .attr: "#005cc5",
            .bool: "#005cc5", .type: "#e36209", .decorator: "#005cc5",
            .heading: "#005cc5", .doctype: "#6a737d", .color: "#005cc5"
        ]
    )

    static let monokai = Theme(
        name: "Monokai",
        bg: "#272822", bg2: "#1e1f1c", bg3: "#171814",
        fg: "#f8f8f2", muted: "#75715e", accent: "#66d9ef",
        border: "#3e3d32", hover: "#3e3d32",
        tokens: [
            .comment: "#75715e", .keyword: "#f92672", .string: "#e6db74",
            .number: "#ae81ff", .function: "#a6e22e", .op: "#f92672",
            .punct: "#f8f8f2", .tag: "#f92672", .attr: "#a6e22e",
            .bool: "#ae81ff", .type: "#66d9ef", .decorator: "#a6e22e",
            .heading: "#a6e22e", .doctype: "#75715e", .color: "#ae81ff"
        ]
    )

    static let solarized = Theme(
        name: "Solarized Dark",
        bg: "#002b36", bg2: "#00212b", bg3: "#001a21",
        fg: "#93a1a1", muted: "#586e75", accent: "#268bd2",
        border: "#0a3d4a", hover: "#073642",
        tokens: [
            .comment: "#586e75", .keyword: "#859900", .string: "#2aa198",
            .number: "#d33682", .function: "#268bd2", .op: "#859900",
            .punct: "#93a1a1", .tag: "#268bd2", .attr: "#b58900",
            .bool: "#d33682", .type: "#b58900", .decorator: "#cb4b16",
            .heading: "#268bd2", .doctype: "#586e75", .color: "#d33682"
        ]
    )

    static let githubDark = Theme(
        name: "Dark (GitHub)",
        bg: "#0d1117", bg2: "#010409", bg3: "#161b22",
        fg: "#e6edf3", muted: "#8b949e", accent: "#58a6ff",
        border: "#30363d", hover: "#161b22",
        tokens: [
            .comment: "#8b949e", .keyword: "#ff7b72", .string: "#a5d6ff",
            .number: "#79c0ff", .function: "#d2a8ff", .op: "#ff7b72",
            .punct: "#e6edf3", .tag: "#7ee787", .attr: "#79c0ff",
            .bool: "#79c0ff", .type: "#ffa657", .decorator: "#ffa657",
            .heading: "#79c0ff", .doctype: "#8b949e", .color: "#79c0ff"
        ]
    )

    static let githubDimmed = Theme(
        name: "Dark Dimmed (GitHub)",
        bg: "#22272e", bg2: "#1c2128", bg3: "#2d333b",
        fg: "#adbac7", muted: "#768390", accent: "#539bf5",
        border: "#444c56", hover: "#2d333b",
        tokens: [
            .comment: "#768390", .keyword: "#f47067", .string: "#96d0ff",
            .number: "#6cb6ff", .function: "#dcbdfb", .op: "#f47067",
            .punct: "#adbac7", .tag: "#8ddb8c", .attr: "#6cb6ff",
            .bool: "#6cb6ff", .type: "#f69d50", .decorator: "#f69d50",
            .heading: "#6cb6ff", .doctype: "#768390", .color: "#6cb6ff"
        ]
    )

    static let dracula = Theme(
        name: "Dracula",
        bg: "#282a36", bg2: "#21222c", bg3: "#191a21",
        fg: "#f8f8f2", muted: "#6272a4", accent: "#bd93f9",
        border: "#44475a", hover: "#343746",
        tokens: [
            .comment: "#6272a4", .keyword: "#ff79c6", .string: "#f1fa8c",
            .number: "#bd93f9", .function: "#50fa7b", .op: "#ff79c6",
            .punct: "#f8f8f2", .tag: "#ff79c6", .attr: "#50fa7b",
            .bool: "#bd93f9", .type: "#8be9fd", .decorator: "#ffb86c",
            .heading: "#bd93f9", .doctype: "#6272a4", .color: "#bd93f9"
        ]
    )

    static let nord = Theme(
        name: "Nord",
        bg: "#2e3440", bg2: "#272c36", bg3: "#242933",
        fg: "#d8dee9", muted: "#616e88", accent: "#88c0d0",
        border: "#3b4252", hover: "#3b4252",
        tokens: [
            .comment: "#616e88", .keyword: "#81a1c1", .string: "#a3be8c",
            .number: "#b48ead", .function: "#88c0d0", .op: "#81a1c1",
            .punct: "#d8dee9", .tag: "#81a1c1", .attr: "#8fbcbb",
            .bool: "#81a1c1", .type: "#8fbcbb", .decorator: "#d08770",
            .heading: "#88c0d0", .doctype: "#616e88", .color: "#b48ead"
        ]
    )

    static var builtIn: [Theme] { [.dark, .githubDark, .githubDimmed, .light, .monokai, .solarized, .dracula, .nord] }
    static var all: [Theme] { builtIn + ThemeStore.shared.custom }

    var isCustom: Bool { key != nil }

    /// Khoá ngắn dùng để lưu vào settings.json.
    var id: String {
        if let k = key { return k }
        if name == "Dark (GitHub)" { return "githubdark" }
        if name == "Dark Dimmed (GitHub)" { return "githubdimmed" }
        if name == "Dracula" { return "dracula" }
        if name == "Nord" { return "nord" }
        if name.contains("Light") { return "light" }
        if name.contains("Monokai") { return "monokai" }
        if name.contains("Solarized") { return "solarized" }
        return "dark"
    }

    /// Nền tối hay sáng, tính theo độ sáng của màu nền (đúng cả với theme nhập từ ngoài).
    var isDark: Bool {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        bgColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (0.2126 * r + 0.7152 * g + 0.0722 * b) < 0.5
    }

    static func byName(_ n: String) -> Theme {
        if n.hasPrefix("custom:") { return ThemeStore.shared.theme(forKey: n) ?? .dark }
        switch n {
        case "githubdark":   return .githubDark
        case "githubdimmed": return .githubDimmed
        case "dracula":      return .dracula
        case "nord":         return .nord
        case "light":     return .light
        case "monokai":   return .monokai
        case "solarized": return .solarized
        default:          return .dark
        }
    }
}

extension UIColor {
    convenience init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let v = UInt32(h, radix: 16) else { return nil }
        let r = CGFloat((v >> 16) & 0xFF) / 255.0
        let g = CGFloat((v >>  8) & 0xFF) / 255.0
        let b = CGFloat( v        & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

// MARK: - Language

enum Language: String, CaseIterable, Codable {
    case lua, javascript, html, css, json, python, swift, c, cpp, java, csharp, rust, go, shell, markdown, plaintext

    var displayName: String {
        switch self {
        case .lua:        return "Lua"
        case .javascript: return "JavaScript"
        case .html:       return "HTML"
        case .css:        return "CSS"
        case .json:       return "JSON"
        case .python:     return "Python"
        case .swift:      return "Swift"
        case .c:          return "C"
        case .cpp:        return "C++"
        case .java:       return "Java"
        case .csharp:     return "C#"
        case .rust:       return "Rust"
        case .go:         return "Go"
        case .shell:      return "Shell"
        case .markdown:   return "Markdown"
        case .plaintext:  return "Plain Text"
        }
    }

    static func detect(_ filename: String) -> Language {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "lua":                              return .lua
        case "js","mjs","cjs","jsx","ts","tsx": return .javascript
        case "html","htm","xml","vue","svg":     return .html
        case "css","scss","less":                return .css
        case "json":                             return .json
        case "py":                               return .python
        case "swift":                            return .swift
        case "c","h","m":                        return .c
        case "cpp","cc","cxx","hpp","hh","hxx","mm","ino": return .cpp
        case "java","kt","kts":                  return .java
        case "cs":                               return .csharp
        case "rs":                               return .rust
        case "go":                               return .go
        case "sh","bash","zsh":                  return .shell
        case "md","markdown":                    return .markdown
        default:                                 return .plaintext
        }
    }
}

// MARK: - Syntax highlighter

struct HighlightRule {
    let kind: TokenKind
    let regex: NSRegularExpression
}

enum SyntaxHighlighter {

    private static func re(_ pattern: String) -> NSRegularExpression {
        return (try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]))
            ?? NSRegularExpression()
    }

    /// Bộ luật chung cho các ngôn ngữ họ C (Swift, C, C++, Java, C#, Rust, Go).
    private static func cLike(keywords: String, bools: String, types: String,
                              preproc: String?, attr: String?, rawStrings: Bool) -> [HighlightRule] {
        var r: [HighlightRule] = [
            HighlightRule(kind: .comment, regex: re("//[^\\n]*|/\\*[\\s\\S]*?\\*/"))
        ]
        let dq = "\"(?:\\\\[\\s\\S]|[^\\\\\"\\n])*\""
        let sq = "'(?:\\\\[\\s\\S]|[^\\\\'\\n])*'"
        if rawStrings {
            r.append(HighlightRule(kind: .string, regex: re("\"\"\"[\\s\\S]*?\"\"\"|`[^`]*`|" + dq + "|" + sq)))
        } else {
            r.append(HighlightRule(kind: .string, regex: re(dq + "|" + sq)))
        }
        if let p = preproc { r.append(HighlightRule(kind: .decorator, regex: re(p))) }
        if let a = attr { r.append(HighlightRule(kind: .decorator, regex: re(a))) }
        r += [
            HighlightRule(kind: .number,  regex: re("\\b(?:0[xX][0-9a-fA-F_]+|0[bB][01_]+|\\d[\\d_]*(?:\\.\\d+)?(?:[eE][+-]?\\d+)?[fFlLuU]*)\\b")),
            HighlightRule(kind: .keyword, regex: re("\\b(?:" + keywords + ")\\b")),
            HighlightRule(kind: .bool,    regex: re("\\b(?:" + bools + ")\\b")),
            HighlightRule(kind: .type,    regex: re("\\b(?:" + types + ")\\b|\\b[A-Z][A-Za-z0-9_]*\\b")),
            HighlightRule(kind: .function,regex: re("\\b[A-Za-z_]\\w*(?=\\s*[(<])")),
            HighlightRule(kind: .op,      regex: re("->|=>|::|[+\\-*/%=<>!&|^~?]+")),
            HighlightRule(kind: .punct,   regex: re("[{}()\\[\\];,.:]"))
        ]
        return r
    }

    static func rules(for language: Language) -> [HighlightRule] {
        switch language {
        case .lua:
            return [
                HighlightRule(kind: .comment, regex: re("--\\[(=*)\\[[\\s\\S]*?\\]\\1\\]|--[^\\n]*")),
                HighlightRule(kind: .string,  regex: re("\\[(=*)\\[[\\s\\S]*?\\]\\1\\]|\"(?:\\\\[\\s\\S]|[^\\\\\"\\n])*\"|'(?:\\\\[\\s\\S]|[^\\\\'\\n])*'")),
                HighlightRule(kind: .number,  regex: re("\\b(?:0[xX][0-9a-fA-F]+|\\d+(?:\\.\\d+)?(?:[eE][+-]?\\d+)?)\\b")),
                HighlightRule(kind: .keyword, regex: re("\\b(?:and|break|do|else|elseif|end|for|function|goto|if|in|local|not|or|repeat|return|then|until|while)\\b")),
                HighlightRule(kind: .bool,    regex: re("\\b(?:true|false|nil)\\b")),
                HighlightRule(kind: .type,    regex: re("\\b(?:love|math|string|table|os|io|coroutine|require|self)\\b")),
                HighlightRule(kind: .function,regex: re("\\b[A-Za-z_]\\w*(?=\\s*[\\(\"'{])")),
                HighlightRule(kind: .op,      regex: re("\\.\\.\\.?|[+\\-*/%^#=<>~]+")),
                HighlightRule(kind: .punct,   regex: re("[{}()\\[\\];,.:]"))
            ]
        case .javascript:
            return [
                HighlightRule(kind: .comment, regex: re("//[^\\n]*|/\\*[\\s\\S]*?\\*/")),
                HighlightRule(kind: .string, regex: re("`(?:\\\\[\\s\\S]|[^\\\\`])*`|\"(?:\\\\[\\s\\S]|[^\\\\\"\\n])*\"|'(?:\\\\[\\s\\S]|[^\\\\'\\n])*'")),
                HighlightRule(kind: .number, regex: re("\\b(?:0[xX][0-9a-fA-F]+|0[bB][01]+|0[oO][0-7]+|\\d+(?:\\.\\d+)?(?:[eE][+-]?\\d+)?)\\b")),
                HighlightRule(kind: .keyword, regex: re("\\b(?:async|await|break|case|catch|class|const|continue|debugger|default|delete|do|else|export|extends|finally|for|from|function|get|if|import|in|instanceof|let|new|of|return|set|static|super|switch|this|throw|try|typeof|var|void|while|with|yield)\\b")),
                HighlightRule(kind: .bool, regex: re("\\b(?:true|false|null|undefined|NaN|Infinity)\\b")),
                HighlightRule(kind: .function, regex: re("\\b[A-Za-z_$][\\w$]*(?=\\s*\\()")),
                HighlightRule(kind: .type, regex: re("\\b(?:Array|Object|String|Number|Boolean|Symbol|Promise|Map|Set|WeakMap|Date|RegExp|Error|JSON|Math|console|window|document|globalThis)\\b")),
                HighlightRule(kind: .op, regex: re("=>|\\.\\.\\.|[+\\-*/%=<>!&|^~?]+")),
                HighlightRule(kind: .punct, regex: re("[{}()\\[\\];,.:]"))
            ]
        case .html:
            return [
                HighlightRule(kind: .comment, regex: re("<!--[\\s\\S]*?-->")),
                HighlightRule(kind: .doctype, regex: re("<!DOCTYPE[^>]*>")),
                HighlightRule(kind: .tag,     regex: re("</?[a-zA-Z][\\w:-]*")),
                HighlightRule(kind: .attr,    regex: re("[a-zA-Z_:][\\w:.-]*(?=\\s*=)")),
                HighlightRule(kind: .string,  regex: re("\"[^\"]*\"|'[^']*'")),
                HighlightRule(kind: .punct,   regex: re("[<>/=]"))
            ]
        case .css:
            return [
                HighlightRule(kind: .comment, regex: re("/\\*[\\s\\S]*?\\*/")),
                HighlightRule(kind: .string,  regex: re("\"[^\"\\n]*\"|'[^'\\n]*'")),
                HighlightRule(kind: .keyword, regex: re("@[\\w-]+")),
                HighlightRule(kind: .color,   regex: re("#[0-9a-fA-F]{3,8}\\b")),
                HighlightRule(kind: .attr,    regex: re("[a-zA-Z-]+(?=\\s*:)")),
                HighlightRule(kind: .number,  regex: re("-?\\d+(?:\\.\\d+)?(?:px|em|rem|%|vh|vw|vmin|vmax|s|ms|deg|fr|pt|ch)?\\b")),
                HighlightRule(kind: .function,regex: re("\\b[a-zA-Z-]+(?=\\s*\\()")),
                HighlightRule(kind: .punct,   regex: re("[{}();:,]"))
            ]
        case .json:
            return [
                HighlightRule(kind: .attr,   regex: re("\"(?:\\\\.|[^\"\\\\])*\"(?=\\s*:)")),
                HighlightRule(kind: .string, regex: re("\"(?:\\\\.|[^\"\\\\])*\"")),
                HighlightRule(kind: .number, regex: re("-?\\d+(?:\\.\\d+)?(?:[eE][+-]?\\d+)?")),
                HighlightRule(kind: .bool,   regex: re("\\b(?:true|false|null)\\b")),
                HighlightRule(kind: .punct,  regex: re("[{}\\[\\],:]"))
            ]
        case .python:
            return [
                HighlightRule(kind: .comment, regex: re("#[^\\n]*")),
                HighlightRule(kind: .string,  regex: re("\"\"\"[\\s\\S]*?\"\"\"|'''[\\s\\S]*?'''|[frbuFRBU]{0,2}\"(?:\\\\[\\s\\S]|[^\\\\\"\\n])*\"|[frbuFRBU]{0,2}'(?:\\\\[\\s\\S]|[^\\\\'\\n])*'")),
                HighlightRule(kind: .decorator, regex: re("@[\\w.]+")),
                HighlightRule(kind: .keyword, regex: re("\\b(?:and|as|assert|async|await|break|class|continue|def|del|elif|else|except|finally|for|from|global|if|import|in|is|lambda|nonlocal|not|or|pass|raise|return|try|while|with|yield|match|case)\\b")),
                HighlightRule(kind: .bool,    regex: re("\\b(?:True|False|None)\\b")),
                HighlightRule(kind: .function,regex: re("\\b[A-Za-z_]\\w*(?=\\s*\\()")),
                HighlightRule(kind: .number,  regex: re("\\b(?:0[xX][0-9a-fA-F]+|\\d+(?:\\.\\d+)?(?:[eE][+-]?\\d+)?)\\b")),
                HighlightRule(kind: .op,      regex: re("[+\\-*/%=<>!&|^~]+")),
                HighlightRule(kind: .punct,   regex: re("[{}()\\[\\];,.:]"))
            ]
        case .swift:
            return cLike(keywords: "associatedtype|actor|as|async|await|break|case|catch|class|continue|default|defer|deinit|do|else|enum|extension|fallthrough|fileprivate|final|for|func|guard|if|import|in|indirect|init|inout|internal|is|lazy|let|mutating|nonmutating|open|operator|override|private|protocol|public|repeat|required|rethrows|return|self|Self|static|struct|subscript|super|switch|throw|throws|try|typealias|var|weak|where|while|some|any|convenience|dynamic|optional|unowned",
                         bools: "true|false|nil",
                         types: "Int|UInt|Int8|Int16|Int32|Int64|UInt8|UInt16|UInt32|UInt64|Float|Double|Bool|String|Character|Array|Dictionary|Set|Optional|Any|AnyObject|Void|Data|Date|URL|CGFloat|CGPoint|CGSize|CGRect|UIView|UIViewController|NSObject|Error|Result",
                         preproc: "#[a-zA-Z]+", attr: "@[A-Za-z_]\\w*", rawStrings: true)
        case .c:
            return cLike(keywords: "auto|break|case|const|continue|default|do|else|enum|extern|for|goto|if|inline|register|restrict|return|sizeof|static|struct|switch|typedef|union|volatile|while|_Bool|_Alignas|_Atomic",
                         bools: "true|false|NULL|nil|YES|NO",
                         types: "int|char|short|long|float|double|void|signed|unsigned|bool|size_t|ssize_t|ptrdiff_t|uint8_t|uint16_t|uint32_t|uint64_t|int8_t|int16_t|int32_t|int64_t|FILE|id|SEL|NSString|NSObject|BOOL",
                         preproc: "^[ \\t]*#[ \\t]*[a-z]+", attr: nil, rawStrings: false)
        case .cpp:
            return cLike(keywords: "alignas|alignof|auto|break|case|catch|class|const|constexpr|const_cast|continue|decltype|default|delete|do|dynamic_cast|else|enum|explicit|export|extern|final|for|friend|goto|if|inline|mutable|namespace|new|noexcept|operator|override|private|protected|public|register|reinterpret_cast|return|sizeof|static|static_assert|static_cast|struct|switch|template|this|throw|try|typedef|typeid|typename|union|using|virtual|volatile|while|concept|requires|co_await|co_return|co_yield",
                         bools: "true|false|nullptr|NULL",
                         types: "int|char|short|long|float|double|void|signed|unsigned|bool|wchar_t|size_t|string|vector|map|set|unordered_map|unordered_set|array|list|deque|pair|tuple|unique_ptr|shared_ptr|weak_ptr|optional|variant|std|cout|cin|cerr|endl|uint8_t|uint16_t|uint32_t|uint64_t|int8_t|int16_t|int32_t|int64_t",
                         preproc: "^[ \\t]*#[ \\t]*[a-z]+", attr: nil, rawStrings: false)
        case .java:
            return cLike(keywords: "abstract|assert|break|case|catch|class|continue|default|do|else|enum|extends|final|finally|for|if|implements|import|instanceof|interface|native|new|package|private|protected|public|return|static|strictfp|super|switch|synchronized|this|throw|throws|transient|try|volatile|while|fun|val|var|when|object|data|sealed|override|suspend",
                         bools: "true|false|null",
                         types: "int|long|short|byte|char|float|double|boolean|void|String|Integer|Long|Double|Boolean|Object|List|Map|Set|ArrayList|HashMap|Exception|System|Math|Int|Unit|Any",
                         preproc: nil, attr: "@[A-Za-z_]\\w*", rawStrings: false)
        case .csharp:
            return cLike(keywords: "abstract|as|async|await|base|break|case|catch|checked|class|const|continue|default|delegate|do|else|enum|event|explicit|extern|finally|fixed|for|foreach|goto|if|implicit|in|interface|internal|is|lock|namespace|new|operator|out|override|params|partial|private|protected|public|readonly|ref|return|sealed|sizeof|stackalloc|static|struct|switch|this|throw|try|typeof|unchecked|unsafe|using|var|virtual|volatile|while|yield|record|init|get|set",
                         bools: "true|false|null",
                         types: "int|uint|long|ulong|short|ushort|byte|sbyte|char|float|double|decimal|bool|void|string|object|dynamic|List|Dictionary|Task|Console|Math|Exception",
                         preproc: "^[ \\t]*#[ \\t]*[a-z]+", attr: nil, rawStrings: false)
        case .rust:
            return cLike(keywords: "as|async|await|break|const|continue|crate|dyn|else|enum|extern|fn|for|if|impl|in|let|loop|match|mod|move|mut|pub|ref|return|self|Self|static|struct|super|trait|type|unsafe|use|where|while",
                         bools: "true|false",
                         types: "i8|i16|i32|i64|i128|isize|u8|u16|u32|u64|u128|usize|f32|f64|bool|char|str|String|Vec|Option|Result|Box|Rc|Arc|HashMap|HashSet|Some|None|Ok|Err",
                         preproc: nil, attr: "#!?\\[[^\\]\\n]*\\]", rawStrings: false)
        case .go:
            return cLike(keywords: "break|case|chan|const|continue|default|defer|else|fallthrough|for|func|go|goto|if|import|interface|map|package|range|return|select|struct|switch|type|var",
                         bools: "true|false|nil|iota",
                         types: "int|int8|int16|int32|int64|uint|uint8|uint16|uint32|uint64|uintptr|float32|float64|complex64|complex128|bool|byte|rune|string|error|any|fmt|len|cap|make|append|panic|recover",
                         preproc: nil, attr: nil, rawStrings: true)
        case .shell:
            return [
                HighlightRule(kind: .comment, regex: re("(?<![\\w$])#[^\\n]*")),
                HighlightRule(kind: .string,  regex: re("\"(?:\\\\[\\s\\S]|[^\\\\\"])*\"|'[^']*'")),
                HighlightRule(kind: .type,    regex: re("\\$\\{[^}\\n]*\\}|\\$[A-Za-z_]\\w*|\\$[0-9@#?*!$-]")),
                HighlightRule(kind: .keyword, regex: re("\\b(?:if|then|else|elif|fi|for|while|until|do|done|case|esac|in|function|select|return|exit|break|continue|export|local|readonly|declare|source|alias|unset|shift|trap|set)\\b")),
                HighlightRule(kind: .number,  regex: re("\\b\\d+\\b")),
                HighlightRule(kind: .op,      regex: re("[|&;<>=!]+")),
                HighlightRule(kind: .punct,   regex: re("[{}()\\[\\]]"))
            ]
        case .markdown:
            return [
                HighlightRule(kind: .string,  regex: re("```[\\s\\S]*?```")),
                HighlightRule(kind: .heading, regex: re("^#{1,6} .*$")),
                HighlightRule(kind: .function,regex: re("\\[[^\\]\\n]*\\]\\([^)\\n]*\\)")),
                HighlightRule(kind: .string,  regex: re("`[^`\\n]+`"))
            ]
        case .plaintext:
            return []
        }
    }

    /// Tô màu: các token thường trước, rồi chú thích/chuỗi được "bảo vệ" và tô đè cuối cùng.
    /// Quét theo thứ tự trong văn bản (cái nào bắt đầu trước thì thắng): "//" trong chuỗi không thành chú thích,
    /// còn mọi thứ sau dấu chú thích (kể cả chính dấu đó) đều một màu chú thích, bất kể có từ khoá hay không.
    private static func paint(_ text: String, language: Language, theme: Theme, grammar: TMGrammar? = nil,
                              set: (NSRange, UIColor) -> Void) {
        if let g = grammar {
            for (r, k) in g.tokens(for: text) { set(r, theme.tokenColor(k)) }
            return
        }
        let full = NSRange(location: 0, length: (text as NSString).length)
        let all = rules(for: language)
        // Luật "hàm" (tên đứng trước dấu "(") tô trước: từ khoá như `while (` / `if (` tô sau nên luôn thắng.
        let plain = all.filter { $0.kind != .comment && $0.kind != .string }
        let ordered = plain.filter { $0.kind == .function } + plain.filter { $0.kind != .function }
        for rule in ordered {
            rule.regex.enumerateMatches(in: text, options: [], range: full) { m, _, _ in
                if let m = m { set(m.range, theme.tokenColor(rule.kind)) }
            }
        }
        var spans: [(range: NSRange, kind: TokenKind)] = []
        for rule in all where rule.kind == .comment || rule.kind == .string {
            rule.regex.enumerateMatches(in: text, options: [], range: full) { m, _, _ in
                if let m = m, m.range.length > 0 { spans.append((m.range, rule.kind)) }
            }
        }
        spans.sort { $0.range.location != $1.range.location ? $0.range.location < $1.range.location
                                                             : $0.range.length > $1.range.length }
        var end = 0
        for sp in spans where sp.range.location >= end {
            set(sp.range, theme.tokenColor(sp.kind))
            end = sp.range.location + sp.range.length
        }
    }

    static func highlight(_ code: String,
                          language: Language,
                          theme: Theme,
                          font: UIFont,
                          grammar: TMGrammar? = nil) -> NSAttributedString {
        let out = NSMutableAttributedString(string: code, attributes: [
            .font: font,
            .foregroundColor: theme.fgColor
        ])
        paint(code, language: language, theme: theme, grammar: grammar) { range, color in
            out.addAttribute(.foregroundColor, value: color, range: range)
        }
        return out
    }

    /// Tô màu tại chỗ trên textStorage: giữ nguyên con trỏ, undo và không làm nháy màn hình.
    static func apply(to storage: NSTextStorage,
                      language: Language,
                      theme: Theme,
                      font: UIFont,
                      grammar: TMGrammar? = nil) {
        let text = storage.string
        let full = NSRange(location: 0, length: (text as NSString).length)
        storage.beginEditing()
        storage.setAttributes([.font: font, .foregroundColor: theme.fgColor], range: full)
        paint(text, language: language, theme: theme, grammar: grammar) { range, color in
            storage.addAttribute(.foregroundColor, value: color, range: range)
        }
        storage.endEditing()
    }
}
