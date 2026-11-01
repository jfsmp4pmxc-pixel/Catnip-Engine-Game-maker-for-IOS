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


import Foundation

// MARK: - Gợi ý code Lua / LÖVE (không phụ thuộc UIKit để dễ kiểm thử)

struct Suggestion: Equatable {
    enum Kind { case keyword, function, module, type, callback, local, snippet }
    let label: String        // chữ hiện trên nút gợi ý
    let insert: String       // chữ chèn vào, thay cho phần đang gõ
    let kind: Kind
    let detail: String?      // gợi ý tham số, ví dụ "(text, x, y)"
    /// Vị trí con trỏ sau khi chèn, tính từ đầu `insert` (UTF-16). nil = cuối chuỗi.
    let cursor: Int?
    /// Chữ chèn thêm ngay trước "love." (chỉ dùng cho khung hàm callback: "function ").
    var leading: String? = nil
}

struct CompletionResult {
    let range: NSRange       // đoạn văn bản sẽ bị thay thế
    let items: [Suggestion]
    static let none = CompletionResult(range: NSRange(location: 0, length: 0), items: [])
}

enum Completion {

    // MARK: Dữ liệu

    static let keywords = ["and", "break", "do", "else", "elseif", "end", "false", "for", "function", "if", "in",
                           "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while"]

    static let globals = ["assert", "collectgarbage", "dofile", "error", "getmetatable", "ipairs", "load",
                          "next", "pairs", "pcall", "print", "rawequal", "rawget", "rawset", "require", "select",
                          "setmetatable", "tonumber", "tostring", "type", "unpack", "xpcall"]

    static let libraries: [String: [String]] = [
        "math": ["abs", "acos", "asin", "atan", "atan2", "ceil", "cos", "cosh", "deg", "exp", "floor", "fmod",
                 "frexp", "huge", "ldexp", "log", "log10", "max", "min", "modf", "pi", "pow", "rad", "random",
                 "randomseed", "sin", "sinh", "sqrt", "tan", "tanh"],
        "string": ["byte", "char", "find", "format", "gmatch", "gsub", "len", "lower", "match", "rep", "reverse",
                   "sub", "upper"],
        "table": ["concat", "insert", "maxn", "remove", "sort"],
        "os": ["clock", "date", "difftime", "exit", "getenv", "remove", "rename", "time", "tmpname"],
        "io": ["close", "flush", "input", "lines", "open", "output", "read", "type", "write"],
        "coroutine": ["create", "resume", "running", "status", "wrap", "yield"]
    ]

    static let stringMethods = ["byte", "find", "format", "gmatch", "gsub", "len", "lower", "match", "rep",
                                "reverse", "sub", "upper"]

    /// Hàm gọi lại của LÖVE và tham số của chúng.
    static let callbacks: [(name: String, params: String)] = [
        ("load", "arg"), ("update", "dt"), ("draw", ""),
        ("keypressed", "key, scancode, isrepeat"), ("keyreleased", "key, scancode"),
        ("textinput", "text"),
        ("mousepressed", "x, y, button, istouch, presses"), ("mousereleased", "x, y, button, istouch, presses"),
        ("mousemoved", "x, y, dx, dy, istouch"), ("wheelmoved", "x, y"),
        ("touchpressed", "id, x, y, dx, dy, pressure"), ("touchreleased", "id, x, y, dx, dy, pressure"),
        ("touchmoved", "id, x, y, dx, dy, pressure"),
        ("resize", "w, h"), ("focus", "focus"), ("quit", "")
    ]

    /// Gợi ý tham số cho các hàm hay dùng (viết tay; phần còn lại chỉ hiện tên).
    static let signatures: [String: String] = [
        "love.graphics.print": "(text, x, y, r, sx, sy)",
        "love.graphics.printf": "(text, x, y, limit, align)",
        "love.graphics.draw": "(drawable, x, y, r, sx, sy)",
        "love.graphics.rectangle": "(mode, x, y, width, height)",
        "love.graphics.circle": "(mode, x, y, radius)",
        "love.graphics.line": "(x1, y1, x2, y2, ...)",
        "love.graphics.setColor": "(r, g, b, a)",
        "love.graphics.setBackgroundColor": "(r, g, b, a)",
        "love.graphics.clear": "(r, g, b, a)",
        "love.graphics.newImage": "(filename)",
        "love.graphics.newFont": "(filename, size)",
        "love.graphics.setFont": "(font)",
        "love.graphics.translate": "(dx, dy)",
        "love.graphics.rotate": "(angle)",
        "love.graphics.scale": "(sx, sy)",
        "love.graphics.getWidth": "()",
        "love.graphics.getHeight": "()",
        "love.audio.newSource": "(filename, type)",
        "love.keyboard.isDown": "(key)",
        "love.mouse.getPosition": "()",
        "love.timer.getDelta": "()",
        "love.timer.getFPS": "()",
        "love.filesystem.read": "(name)",
        "love.filesystem.write": "(name, data)",
        "love.physics.newWorld": "(gx, gy, sleep)",
        "love.math.random": "(min, max)"
    ]

    static let snippets: [(trigger: String, label: String, body: String)] = [
        ("function", "function … end", "function $0()\nend"),
        ("fori", "for i = 1, n do", "for i = 1, $0 do\nend"),
        ("forp", "for k, v in pairs()", "for k, v in pairs($0) do\nend"),
        ("foreach", "for _, v in ipairs()", "for _, v in ipairs($0) do\nend"),
        ("if", "if … then … end", "if $0 then\nend"),
        ("ifelse", "if … else … end", "if $0 then\nelse\nend"),
        ("while", "while … do … end", "while $0 do\nend"),
        ("repeat", "repeat … until", "repeat\n$0\nuntil "),
        ("lf", "local function", "local function $0()\nend")
    ]

    // MARK: Phân tích

    private static func isIdent(_ c: unichar) -> Bool {
        (c >= 48 && c <= 57) || (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95
    }

    /// Con trỏ có đang nằm trong chú thích `--` hoặc chuỗi "…" '…' của dòng hiện tại không.
    static func isInCommentOrString(_ text: NSString, cursor: Int) -> Bool {
        let lineStart = text.lineRange(for: NSRange(location: cursor, length: 0)).location
        var quote: unichar = 0
        var i = lineStart
        while i < cursor {
            let c = text.character(at: i)
            if quote != 0 {
                if c == 92 { i += 1 }                 // dấu \ : bỏ qua ký tự kế
                else if c == quote { quote = 0 }
            } else if c == 34 || c == 39 {            // " hoặc '
                quote = c
            } else if c == 45, i + 1 < cursor, text.character(at: i + 1) == 45 {   // --
                return true
            }
            i += 1
        }
        return quote != 0
    }

    /// Các danh từ (định danh) trong file, trừ vị trí `excluding`, để gợi ý biến/hàm tự đặt.
    static func localWords(_ text: NSString, excluding: NSRange) -> [String] {
        guard text.length <= 300_000 else { return [] }
        var seen = Set<String>()
        var i = 0
        let n = text.length
        while i < n {
            let c = text.character(at: i)
            if isIdent(c), !(c >= 48 && c <= 57) {
                var j = i + 1
                while j < n, isIdent(text.character(at: j)) { j += 1 }
                let r = NSRange(location: i, length: j - i)
                let touchesCursor = NSIntersectionRange(r, NSRange(location: excluding.location, length: max(excluding.length, 1))).length > 0
                    || NSMaxRange(excluding) == NSMaxRange(r)
                if r.length >= 3, !touchesCursor { seen.insert(text.substring(with: r)) }
                i = j
            } else { i += 1 }
        }
        return seen.sorted()
    }

    // MARK: Gợi ý

    static func suggest(in text: NSString, cursor: Int, limit: Int = 24) -> CompletionResult {
        guard cursor > 0, cursor <= text.length else { return .none }
        if isInCommentOrString(text, cursor: cursor) { return .none }

        // Lấy token (định danh, '.', ':') ngay trước con trỏ.
        var start = cursor
        while start > 0 {
            let c = text.character(at: start - 1)
            if isIdent(c) || c == 46 || c == 58 { start -= 1 } else { break }
        }
        // Con trỏ ngay trước một định danh khác (đang sửa giữa chữ) thì không gợi ý.
        if cursor < text.length, isIdent(text.character(at: cursor)) { return .none }
        // Dấu ".." (nối chuỗi) hoặc "::" không phải truy cập thành phần.
        let tokenAll = text.substring(with: NSRange(location: start, length: cursor - start))
        if tokenAll.contains("..") || tokenAll.contains("::") || tokenAll.isEmpty { return .none }
        // Token không được bắt đầu bằng số hoặc dấu chấm.
        if let f = tokenAll.unicodeScalars.first, !(f == "_" || CharacterSet.letters.contains(f)) { return .none }

        let sepIdx = tokenAll.lastIndex(where: { $0 == "." || $0 == ":" })
        var base = "", prefix = tokenAll
        var sep: Character? = nil
        if let idx = sepIdx {
            base = String(tokenAll[..<idx])
            prefix = String(tokenAll[tokenAll.index(after: idx)...])
            sep = tokenAll[idx]
        }
        let prefixStart = cursor - (prefix as NSString).length
        let replace = NSRange(location: prefixStart, length: cursor - prefixStart)

        var pool: [Suggestion] = []

        if let sep = sep {
            pool = members(of: base, sep: sep, text: text, tokenStart: start, cursor: cursor)
        } else {
            if prefix.count < 2 { return .none }
            for k in keywords { pool.append(Suggestion(label: k, insert: k, kind: .keyword, detail: nil, cursor: nil)) }
            for g in globals { pool.append(Suggestion(label: g, insert: g + "()", kind: .function, detail: nil, cursor: g.count + 1)) }
            for lib in ["love"] + libraries.keys.sorted() {
                pool.append(Suggestion(label: lib, insert: lib, kind: .module, detail: nil, cursor: nil))
            }
            for s in snippets {
                let (body, cur) = expand(s.body)
                pool.append(Suggestion(label: s.trigger, insert: body, kind: .snippet, detail: s.label, cursor: cur))
            }
            let known = Set(pool.map { $0.label })
            for w in localWords(text, excluding: replace) where !known.contains(w) {
                pool.append(Suggestion(label: w, insert: w, kind: .local, detail: nil, cursor: nil))
            }
        }

        let items = rank(pool, prefix: prefix, limit: limit)
        return CompletionResult(range: replace, items: items)
    }

    /// Thành phần của `base` (vd "love.graphics", "math", "love").
    private static func members(of base: String, sep: Character, text: NSString,
                                tokenStart: Int, cursor: Int) -> [Suggestion] {
        if sep == ":" {
            // Không biết kiểu của biến: gợi ý phương thức của mọi kiểu LÖVE cùng phương thức chuỗi.
            var names = Set(stringMethods)
            for (_, m) in LoveAPI.types { names.formUnion(m) }
            return names.sorted().map { Suggestion(label: $0, insert: $0 + "()", kind: .function, detail: nil, cursor: $0.count + 1) }
        }
        if base == "love" {
            var out: [Suggestion] = []
            let lineStart = text.lineRange(for: NSRange(location: tokenStart, length: 0)).location
            let before = text.substring(with: NSRange(location: lineStart, length: tokenStart - lineStart))
            let atLineStart = before.trimmingCharacters(in: .whitespaces).isEmpty
            let indent = String(before.prefix(while: { $0 == " " || $0 == "\t" }))
            for m in LoveAPI.modules.keys.sorted() {
                out.append(Suggestion(label: m, insert: m, kind: .module, detail: nil, cursor: nil))
            }
            for cb in callbacks {
                if atLineStart {
                    // Dòng trống: dựng sẵn "function love.xxx(...) … end"; phần "love." đã gõ nằm ngoài vùng thay thế.
                    let head = "\(cb.name)(\(cb.params))"
                    let body = head + "\n" + indent + indentUnitForCompletion + "\n" + indent + "end"
                    let pos = (("\(head)\n" + indent + indentUnitForCompletion) as NSString).length
                    out.append(Suggestion(label: cb.name, insert: body, kind: .callback,
                                          detail: "(\(cb.params))", cursor: pos, leading: "function "))
                } else {
                    out.append(Suggestion(label: cb.name, insert: cb.name, kind: .callback,
                                          detail: "(\(cb.params))", cursor: nil))
                }
            }
            for extra in ["getVersion", "conf"] {
                out.append(Suggestion(label: extra, insert: extra, kind: .function, detail: nil, cursor: nil))
            }
            return out
        }
        if base.hasPrefix("love."), let fns = LoveAPI.modules[String(base.dropFirst(5))] {
            return fns.map { fn in
                let sig = signatures[base + "." + fn]
                return Suggestion(label: fn, insert: fn + "()", kind: .function, detail: sig, cursor: fn.count + 1)
            }
        }
        if let fns = libraries[base] {
            return fns.map { Suggestion(label: $0, insert: $0, kind: .function, detail: nil, cursor: nil) }
        }
        return []
    }

    /// Một mức thụt lề dùng khi dựng khung hàm (khớp `indentUnit` của editor).
    static var indentUnitForCompletion = "  "

    /// Tách "$0" khỏi thân snippet và trả về vị trí con trỏ (UTF-16). Thân snippet thụt lề theo từng dòng.
    private static func expand(_ body: String) -> (String, Int?) {
        guard let r = body.range(of: "$0") else { return (body, nil) }
        let pos = (String(body[..<r.lowerBound]) as NSString).length
        return (body.replacingCharacters(in: r, with: ""), pos)
    }

    private static func rank(_ pool: [Suggestion], prefix: String, limit: Int) -> [Suggestion] {
        let p = prefix.lowercased()
        var starts: [Suggestion] = [], contains: [Suggestion] = []
        var seen = Set<String>()
        for s in pool {
            let l = s.label.lowercased()
            let key = s.label + "|\(s.kind)"
            if seen.contains(key) { continue }
            if p.isEmpty { starts.append(s); seen.insert(key) }
            else if l.hasPrefix(p) {
                if l == p && s.kind != .snippet && s.kind != .callback { continue } // đã gõ đủ rồi
                starts.append(s); seen.insert(key)
            } else if p.count >= 3, l.contains(p) { contains.append(s); seen.insert(key) }
        }
        func order(_ a: Suggestion, _ b: Suggestion) -> Bool {
            if a.kind != b.kind {
                // Ưu tiên API/từ khoá hơn biến cục bộ.
                let rankOf: (Suggestion.Kind) -> Int = { $0 == .local ? 1 : 0 }
                if rankOf(a.kind) != rankOf(b.kind) { return rankOf(a.kind) < rankOf(b.kind) }
            }
            if a.label.count != b.label.count { return a.label.count < b.label.count }
            return a.label < b.label
        }
        return Array((starts.sorted(by: order) + contains.sorted(by: order)).prefix(limit))
    }
}
