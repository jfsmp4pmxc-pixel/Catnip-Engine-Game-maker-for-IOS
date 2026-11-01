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

// Themes.swift
// Nhập theme TextMate (.tmTheme) và quản lý các theme do người dùng nhập.
//
// .tmTheme là plist XML: phần tử đầu (không có scope) chứa màu chung của editor, các phần tử sau là
// luật tô màu theo "scope" (ví dụ "keyword.control", "string.quoted"). Catnip chỉ có vài loại token
// (TokenKind), nên mỗi loại được tra bằng một danh sách scope đại diện, lấy luật khớp cụ thể nhất.

import UIKit

// MARK: - Màu RGB để tính toán

struct RGB {
    var r: Double, g: Double, b: Double

    static let white = RGB(r: 1, g: 1, b: 1)
    static let black = RGB(r: 0, g: 0, b: 0)

    /// Nhận "#RGB", "#RRGGBB" và "#RRGGBBAA". Có alpha thì trộn lên `background` (nếu có).
    init?(hex: String, over background: RGB? = nil) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if h.hasPrefix("#") { h.removeFirst() }
        if h.count == 3 { h = h.map { "\($0)\($0)" }.joined() }
        guard h.count == 6 || h.count == 8, let v = UInt64(h, radix: 16) else { return nil }
        let hasAlpha = h.count == 8
        let rr = Double((v >> (hasAlpha ? 24 : 16)) & 0xFF) / 255
        let gg = Double((v >> (hasAlpha ? 16 : 8)) & 0xFF) / 255
        let bb = Double((v >> (hasAlpha ? 8 : 0)) & 0xFF) / 255
        let aa = hasAlpha ? Double(v & 0xFF) / 255 : 1
        if let bg = background, aa < 1 {
            r = rr * aa + bg.r * (1 - aa)
            g = gg * aa + bg.g * (1 - aa)
            b = bb * aa + bg.b * (1 - aa)
        } else {
            r = rr; g = gg; b = bb
        }
    }

    init(r: Double, g: Double, b: Double) { self.r = r; self.g = g; self.b = b }

    var luminance: Double { 0.2126 * r + 0.7152 * g + 0.0722 * b }

    func mixed(with o: RGB, _ t: Double) -> RGB {
        RGB(r: r + (o.r - r) * t, g: g + (o.g - g) * t, b: b + (o.b - b) * t)
    }

    var hex: String {
        func c(_ x: Double) -> Int { Int((min(max(x, 0), 1) * 255).rounded()) }
        return String(format: "#%02x%02x%02x", c(r), c(g), c(b))
    }
}

// MARK: - Đọc .tmTheme

enum TMThemeError: LocalizedError {
    case notATheme
    var errorDescription: String? { "File này không phải theme .tmTheme hợp lệ" }
}

enum TMTheme {

    private struct Rule {
        let selectors: [String]
        let foreground: RGB?
    }

    /// Scope đại diện cho từng loại token, theo thứ tự ưu tiên.
    private static let representatives: [(TokenKind, [String])] = [
        (.comment,   ["comment", "comment.line", "comment.block"]),
        (.keyword,   ["keyword.control", "keyword", "storage.modifier", "storage"]),
        (.string,    ["string", "string.quoted", "string.quoted.double"]),
        (.number,    ["constant.numeric", "constant"]),
        (.function,  ["entity.name.function", "support.function", "meta.function-call", "variable.function"]),
        (.op,        ["keyword.operator", "keyword"]),
        (.punct,     ["punctuation", "meta.brace"]),
        (.tag,       ["entity.name.tag", "meta.tag", "markup.deleted"]),
        (.attr,      ["entity.other.attribute-name", "entity.other.attribute", "variable.parameter"]),
        (.bool,      ["constant.language.boolean", "constant.language", "constant"]),
        (.type,      ["entity.name.type", "entity.name.class", "support.class", "support.type", "storage.type"]),
        (.decorator, ["meta.decorator", "entity.name.function.decorator", "meta.annotation", "storage.type.annotation", "entity.name.function"]),
        (.heading,   ["markup.heading", "entity.name.section", "markup.heading.1"]),
        (.doctype,   ["meta.tag.sgml.doctype", "meta.preprocessor", "comment"]),
        (.color,     ["constant.other.color", "constant.numeric", "constant"])
    ]

    static func parse(_ data: Data, fallbackName: String, key: String) throws -> Theme {
        guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let root = plist as? [String: Any],
              let items = root["settings"] as? [[String: Any]], !items.isEmpty else {
            throw TMThemeError.notATheme
        }

        // Màu chung (phần tử không có scope) và các luật theo scope.
        var global: [String: String] = [:]
        var rawRules: [(selectors: [String], fg: String?)] = []
        for item in items {
            let st = item["settings"] as? [String: Any] ?? [:]
            let scope = (item["scope"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if scope.isEmpty {
                for (k, v) in st { if let s = v as? String { global[k] = s } }
            } else {
                rawRules.append((splitSelectors(scope), st["foreground"] as? String))
            }
        }
        guard global["background"] != nil || global["foreground"] != nil || !rawRules.isEmpty else {
            throw TMThemeError.notATheme
        }

        let bg = RGB(hex: global["background"] ?? "") ?? .white
        let dark = bg.luminance < 0.5
        let fg = RGB(hex: global["foreground"] ?? "", over: bg)
            ?? (dark ? RGB(r: 0.83, g: 0.83, b: 0.83) : RGB(r: 0.13, g: 0.13, b: 0.13))

        // Màu có alpha trong luật được trộn lên nền editor.
        let rules = rawRules.map { Rule(selectors: $0.selectors, foreground: $0.fg.flatMap { RGB(hex: $0, over: bg) }) }

        func color(for scope: String) -> RGB? {
            var best: (score: Int, color: RGB)?
            for rule in rules {
                guard let c = rule.foreground else { continue }
                for sel in rule.selectors where scope == sel || scope.hasPrefix(sel + ".") {
                    let score = sel.split(separator: ".").count
                    if best == nil || score >= best!.score { best = (score, c) }
                }
            }
            return best?.color
        }

        var tokens: [TokenKind: String] = [:]
        for (kind, scopes) in representatives {
            for s in scopes {
                if let c = color(for: s) { tokens[kind] = c.hex; break }
            }
        }

        let comment = tokens[.comment].flatMap { RGB(hex: $0) }
        let caret = RGB(hex: global["caret"] ?? "", over: bg)
        let keyword = tokens[.keyword].flatMap { RGB(hex: $0) }
        var accent = caret ?? keyword ?? fg
        if abs(accent.luminance - bg.luminance) < 0.2 { accent = fg }   // đủ tương phản với nền

        let bg2 = bg.mixed(with: .black, dark ? 0.18 : 0.04)
        let bg3 = bg.mixed(with: .black, dark ? 0.32 : 0.08)
        let hover = RGB(hex: global["lineHighlight"] ?? "", over: bg) ?? bg.mixed(with: fg, 0.07)

        let name = (root["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? fallbackName
        return Theme(
            name: name,
            bg: bg.hex, bg2: bg2.hex, bg3: bg3.hex,
            fg: fg.hex,
            muted: (comment ?? bg.mixed(with: fg, 0.5)).hex,
            accent: accent.hex,
            border: bg.mixed(with: fg, 0.16).hex,
            hover: hover.hex,
            tokens: tokens,
            key: key
        )
    }

    /// "a.b, c.d - e.f" → ["a.b", "c.d"]. Selector có khoảng trắng (con cháu) chỉ lấy phần cuối.
    private static func splitSelectors(_ scope: String) -> [String] {
        scope.split(separator: ",").compactMap { part in
            var s = String(part)
            if let r = s.range(of: " - ") { s = String(s[..<r.lowerBound]) }
            let last = s.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" }).last.map(String.init) ?? ""
            return last.isEmpty ? nil : last
        }
    }
}

// MARK: - Kho theme do người dùng nhập

final class ThemeStore {
    static let shared = ThemeStore()

    private let fm = FileManager.default
    private(set) var custom: [Theme] = []

    var directory: URL { CatnipPaths.root.appendingPathComponent("Themes", isDirectory: true) }

    private init() {
        try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
        reload()
    }

    func reload() {
        let files = (try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil,
                                                 options: [.skipsHiddenFiles])) ?? []
        custom = files
            .filter { $0.pathExtension.lowercased() == "tmtheme" }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url) else { return nil }
                let base = (url.lastPathComponent as NSString).deletingPathExtension
                return try? TMTheme.parse(data, fallbackName: base, key: "custom:" + url.lastPathComponent)
            }
    }

    func theme(forKey key: String) -> Theme? { custom.first { $0.key == key } }

    /// Nhập một file .tmTheme. File được kiểm tra trước khi lưu; hỏng thì không lưu gì.
    @discardableResult
    func importTheme(from source: URL) throws -> Theme {
        let data: Data
        do { data = try Data(contentsOf: source) } catch { throw StoreError.io(error.localizedDescription) }
        let base = (source.lastPathComponent as NSString).deletingPathExtension
        _ = try TMTheme.parse(data, fallbackName: base, key: "check")

        var safe = base
        for bad in ["/", ":", "\\"] { safe = safe.replacingOccurrences(of: bad, with: "_") }
        if safe.isEmpty { safe = "theme" }
        var candidate = safe + ".tmTheme"
        var n = 2
        while fm.fileExists(atPath: directory.appendingPathComponent(candidate).path) {
            candidate = "\(safe) \(n).tmTheme"
            n += 1
        }
        do {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: directory.appendingPathComponent(candidate), options: .atomic)
        } catch { throw StoreError.io(error.localizedDescription) }

        reload()
        guard let theme = theme(forKey: "custom:" + candidate) else { throw TMThemeError.notATheme }
        return theme
    }

    func delete(_ theme: Theme) {
        guard let key = theme.key, key.hasPrefix("custom:") else { return }
        let file = String(key.dropFirst("custom:".count))
        try? fm.removeItem(at: directory.appendingPathComponent(file))
        reload()
    }
}
