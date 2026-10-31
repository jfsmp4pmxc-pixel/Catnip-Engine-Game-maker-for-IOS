// main.swift
// MiniCode — iOS code editor
// Entry point + models + syntax highlighter + storage

import UIKit

// MARK: - App entry point
// NOTE: with file named `main.swift`, we use top-level code (not @main / @UIApplicationMain)

final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let w = UIWindow(frame: UIScreen.main.bounds)
        w.rootViewController = CodeEditorViewController()
        w.makeKeyAndVisible()
        window = w
        return true
    }
}

UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, NSStringFromClass(AppDelegate.self))

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

    static let light = Theme(
        name: "Light (GitHub)",
        bg: "#ffffff", bg2: "#f6f8fa", bg3: "#eaeef2",
        fg: "#24292f", muted: "#6b7280", accent: "#0969da",
        border: "#d0d7de", hover: "#eaeef2",
        tokens: [
            .comment: "#6e7781", .keyword: "#cf222e", .string: "#0a3069",
            .number: "#0550ae", .function: "#8250df", .op: "#0550ae",
            .punct: "#24292f", .tag: "#116329", .attr: "#0550ae",
            .bool: "#0550ae", .type: "#953800", .decorator: "#953800",
            .heading: "#0550ae", .doctype: "#6e7781", .color: "#0550ae"
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

    static var all: [Theme] { [.dark, .light, .monokai, .solarized] }

    static func byName(_ n: String) -> Theme {
        switch n {
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
    case javascript, html, css, json, python, markdown, plaintext

    var displayName: String {
        switch self {
        case .javascript: return "JavaScript"
        case .html:       return "HTML"
        case .css:        return "CSS"
        case .json:       return "JSON"
        case .python:     return "Python"
        case .markdown:   return "Markdown"
        case .plaintext:  return "Plain Text"
        }
    }

    static func detect(_ filename: String) -> Language {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "js","mjs","cjs","jsx","ts","tsx": return .javascript
        case "html","htm","xml","vue","svg":     return .html
        case "css","scss","less":                return .css
        case "json":                             return .json
        case "py":                               return .python
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

    static func rules(for language: Language) -> [HighlightRule] {
        switch language {
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

    static func highlight(_ code: String,
                          language: Language,
                          theme: Theme,
                          font: UIFont) -> NSAttributedString {
        let out = NSMutableAttributedString(string: code, attributes: [
            .font: font,
            .foregroundColor: theme.fgColor
        ])
        let nsLen = (code as NSString).length
        let full = NSRange(location: 0, length: nsLen)
        for rule in rules(for: language) {
            rule.regex.enumerateMatches(in: code, options: [], range: full) { m, _, _ in
                guard let m = m else { return }
                out.addAttribute(.foregroundColor, value: theme.tokenColor(rule.kind), range: m.range)
            }
        }
        return out
    }
}

// MARK: - File model / storage

struct CodeFile: Codable {
    var language: Language
    var content: String
}

final class FileStore {
    static let shared = FileStore()

    var files: [String: CodeFile] = [:]
    var folders: Set<String> = []
    var expandedFolders: Set<String> = []
    var currentFile: String?

    private let filesKey    = "minicode.files.v1"
    private let foldersKey  = "minicode.folders.v1"
    private let expandedKey = "minicode.expanded.v1"
    private let currentKey  = "minicode.current.v1"

    private init() {
        if !load() {
            seed()
            save()
        }
    }

    @discardableResult
    func load() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: filesKey),
              let decoded = try? JSONDecoder().decode([String: CodeFile].self, from: data) else {
            return false
        }
        files = decoded
        if let d = UserDefaults.standard.data(forKey: foldersKey),
           let arr = try? JSONDecoder().decode([String].self, from: d) {
            folders = Set(arr)
        }
        if let d = UserDefaults.standard.data(forKey: expandedKey),
           let arr = try? JSONDecoder().decode([String].self, from: d) {
            expandedFolders = Set(arr)
        }
        currentFile = UserDefaults.standard.string(forKey: currentKey)
        return true
    }

    func save() {
        if let d = try? JSONEncoder().encode(files) {
            UserDefaults.standard.set(d, forKey: filesKey)
        }
        if let d = try? JSONEncoder().encode(Array(folders)) {
            UserDefaults.standard.set(d, forKey: foldersKey)
        }
        if let d = try? JSONEncoder().encode(Array(expandedFolders)) {
            UserDefaults.standard.set(d, forKey: expandedKey)
        }
        UserDefaults.standard.set(currentFile, forKey: currentKey)
    }

    func seed() {
        files = [
            "app.js": CodeFile(language: .javascript, content:
"""
// Chào mừng đến với MiniCode!
// ---------------------------------
// • Tab để thụt lề, Enter tự động thụt dòng
// • Nút 💾 để lưu
// • Nút ⚙️ để đổi theme / font
// • Nút ☰ để mở danh sách file

const editor = {
  theme: 'dark',
  fontSize: 14,
  wrap: false
};

function greet(name) {
  const message = 'Xin chào, ' + name + '!';
  console.log(message);
  return message;
}

class File {
  constructor(name, content) {
    this.name = name;
    this.content = content || '';
  }
  get size() { return this.content.length; }
}

const list = ['a', 'b', 'c'].map(x => x.toUpperCase());
greet('MiniCode');
"""),
            "src/main.js": CodeFile(language: .javascript, content:
"""
import { helper } from './utils/helper.js';

export function main() {
  const result = helper(21);
  console.log('Result:', result);
  return result;
}
"""),
            "src/utils/helper.js": CodeFile(language: .javascript, content:
"""
export function helper(n) {
  return n * 2;
}

export const VERSION = '1.0.0';
"""),
            "index.html": CodeFile(language: .html, content:
"""
<!DOCTYPE html>
<html lang="vi">
  <head>
    <meta charset="UTF-8">
    <title>Trang demo</title>
  </head>
  <body>
    <h1 class="title">Hello world</h1>
    <p>Đây là một file HTML mẫu.</p>
  </body>
</html>
"""),
            "styles.css": CodeFile(language: .css, content:
"""
:root {
  --primary: #61afef;
  --radius: 8px;
}

body {
  margin: 0;
  font-family: system-ui, sans-serif;
  background: #282c34;
  color: #abb2bf;
}

.title {
  font-size: 32px;
  color: var(--primary);
  border-bottom: 2px solid var(--primary);
}
"""),
            "data.json": CodeFile(language: .json, content:
"""
{
  "name": "MiniCode",
  "version": "1.0.0",
  "features": ["syntax highlight", "file manager", "settings"],
  "active": true,
  "stars": 1024
}
""")
        ]
        folders = ["src", "src/utils"]
        expandedFolders = ["src", "src/utils"]
        currentFile = "app.js"
    }

    /// Return sorted list of paths respecting expanded folders.
    func visiblePaths() -> [String] {
        var result: [String] = []
        let folderList = folders.sorted()
        for f in folderList {
            let parts = f.split(separator: "/").map(String.init)
            if parts.count == 1 {
                result.append(f + "/")
            } else {
                let parent = parts.dropLast().joined(separator: "/")
                if expandedFolders.contains(parent) {
                    result.append(f + "/")
                }
            }
        }
        let fileList = files.keys.sorted()
        for f in fileList {
            let parts = f.split(separator: "/").map(String.init)
            if parts.count == 1 {
                result.append(f)
            } else {
                let parent = parts.dropLast().joined(separator: "/")
                if expandedFolders.contains(parent) {
                    result.append(f)
                }
            }
        }
        return result
    }

    func createFile(at path: String, language: Language) {
        files[path] = CodeFile(language: language, content: "")
        let parts = path.split(separator: "/").map(String.init)
        var prefix = ""
        for i in 0..<max(0, parts.count - 1) {
            prefix += (prefix.isEmpty ? "" : "/") + parts[i]
            folders.insert(prefix)
            expandedFolders.insert(prefix)
        }
        currentFile = path
        save()
    }
}