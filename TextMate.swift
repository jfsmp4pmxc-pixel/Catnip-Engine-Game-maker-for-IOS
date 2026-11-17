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

// TextMate.swift
// Định cú pháp kiểu TextMate: nhập *.tmLanguage hoặc cả thư mục *.tmbundle (info.plist + Syntaxes/*.tmLanguage).
//  - TMGrammar: đọc ngữ pháp (patterns, begin/end, captures, repository, include) và tách token theo từng dòng.
//  - GrammarStore: lưu các ngữ pháp đã nhập trong Application Support/Catnip/Grammars.
//  - GrammarsViewController: màn hình quản lý (nhập, xoá).
// Regex dùng NSRegularExpression (ICU) thay cho Oniguruma nên có vài cú pháp hiếm không dùng được (luật đó bị bỏ qua).
// Màu lấy theo theme đang chọn: scope được quy về các loại token của app (TokenKind).

import UIKit
import UniformTypeIdentifiers

// MARK: - Luật

final class TMRule {
    var name: String?
    var contentName: String?
    var matchSrc: String?
    var beginSrc: String?
    var endSrc: String?
    var includeRef: String?
    var captures: [Int: String] = [:]
    var beginCaptures: [Int: String] = [:]
    var endCaptures: [Int: String] = [:]
    var patterns: [TMRule] = []
    var applyEndPatternLast = false

    lazy var matchRE: NSRegularExpression? = matchSrc.flatMap { TMGrammar.compile($0) }
    lazy var beginRE: NSRegularExpression? = beginSrc.flatMap { TMGrammar.compile($0) }
    lazy var endRE: NSRegularExpression? = endSrc.flatMap { TMGrammar.compile($0) }

    var isBegin: Bool { beginSrc != nil }
}

private struct TMFrame {
    let rule: TMRule
    let end: NSRegularExpression?
}

// MARK: - Ngữ pháp

final class TMGrammar {
    let name: String
    let scopeName: String
    let fileTypes: [String]
    private let root: [TMRule]
    private var repository: [String: TMRule] = [:]
    private var expandCache: [ObjectIdentifier: [TMRule]] = [:]
    private var endCache: [String: NSRegularExpression?] = [:]
    private var rootFlat: [TMRule] = []

    /// Nhận dữ liệu .tmLanguage (plist XML/nhị phân, hoặc JSON).
    init?(data: Data, fallbackName: String = "Cú pháp") {
        var obj: Any? = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        if obj == nil { obj = try? JSONSerialization.jsonObject(with: data) }
        guard let d = obj as? [String: Any],
              d["patterns"] != nil || d["repository"] != nil || d["scopeName"] != nil else { return nil }
        let pats = (d["patterns"] as? [[String: Any]]) ?? []
        scopeName = (d["scopeName"] as? String) ?? fallbackName
        name = (d["name"] as? String) ?? fallbackName
        fileTypes = (d["fileTypes"] as? [String]) ?? []
        root = pats.map(TMGrammar.parseRule)
        if let repo = d["repository"] as? [String: Any] {
            for (k, v) in repo { if let rd = v as? [String: Any] { repository[k] = TMGrammar.parseRule(rd) } }
        }
        rootFlat = resolve(root, visited: [])
    }

    private static func bool(_ v: Any?) -> Bool { (v as? NSNumber)?.boolValue ?? false }

    private static func parseCaps(_ v: Any?) -> [Int: String] {
        var out: [Int: String] = [:]
        guard let d = v as? [String: Any] else { return out }
        for (k, val) in d {
            if let i = Int(k), let nm = (val as? [String: Any])?["name"] as? String { out[i] = nm }
        }
        return out
    }

    private static func parseRule(_ d: [String: Any]) -> TMRule {
        let r = TMRule()
        r.name = d["name"] as? String
        r.contentName = d["contentName"] as? String
        r.matchSrc = d["match"] as? String
        r.beginSrc = d["begin"] as? String
        r.endSrc = d["end"] as? String
        r.includeRef = d["include"] as? String
        r.captures = parseCaps(d["captures"])
        r.beginCaptures = parseCaps(d["beginCaptures"])
        r.endCaptures = parseCaps(d["endCaptures"])
        if r.isBegin {
            if r.beginCaptures.isEmpty { r.beginCaptures = r.captures }
            if r.endCaptures.isEmpty { r.endCaptures = r.captures }
        }
        r.applyEndPatternLast = bool(d["applyEndPatternLast"])
        r.patterns = (d["patterns"] as? [[String: Any]] ?? []).map(parseRule)
        return r
    }

    /// Chuyển cú pháp Oniguruma hay gặp sang ICU. Không biên dịch được thì trả nil (luật bị bỏ qua).
    static func compile(_ src: String) -> NSRegularExpression? {
        var s = src
        s = s.replacingOccurrences(of: "\\h", with: "[0-9a-fA-F]")
        s = s.replacingOccurrences(of: "\\H", with: "[^0-9a-fA-F]")
        s = s.replacingOccurrences(of: "\\G", with: "")
        return try? NSRegularExpression(pattern: s, options: [.anchorsMatchLines])
    }

    /// Mở các luật `include` và nhóm chỉ có `patterns` thành danh sách luật lá (match/begin).
    private func resolve(_ rules: [TMRule], visited: Set<ObjectIdentifier>) -> [TMRule] {
        var out: [TMRule] = []
        for r in rules {
            let id = ObjectIdentifier(r)
            if visited.contains(id) { continue }
            var seen = visited
            seen.insert(id)
            if let inc = r.includeRef {
                if inc == "$self" || inc == "$base" {
                    out += resolve(root, visited: seen)
                } else if inc.hasPrefix("#"), let t = repository[String(inc.dropFirst())] {
                    out += resolve([t], visited: seen)
                }   // include sang ngôn ngữ khác: bỏ qua
            } else if r.matchSrc != nil || r.isBegin {
                out.append(r)
            } else {
                out += resolve(r.patterns, visited: seen)
            }
        }
        return out
    }

    private func patterns(of rule: TMRule) -> [TMRule] {
        let id = ObjectIdentifier(rule)
        if let c = expandCache[id] { return c }
        let flat = resolve(rule.patterns, visited: [])
        expandCache[id] = flat
        return flat
    }

    // MARK: Scope → loại token

    private static let scopeTable: [(String, TokenKind)] = [
        ("comment", .comment),
        ("string", .string),
        ("constant.numeric", .number),
        ("constant.language", .bool),
        ("constant.other.color", .color),
        ("constant", .number),
        ("meta.preprocessor", .decorator),
        ("keyword.control.directive", .decorator),
        ("punctuation.definition.directive", .decorator),
        ("meta.annotation", .decorator),
        ("meta.decorator", .decorator),
        ("storage.type.annotation", .decorator),
        ("keyword.operator", .op),
        ("keyword", .keyword),
        ("storage.type", .type),
        ("storage", .keyword),
        ("entity.name.function", .function),
        ("support.function", .function),
        ("meta.function-call", .function),
        ("variable.function", .function),
        ("entity.name.tag", .tag),
        ("meta.tag", .tag),
        ("entity.other.attribute-name", .attr),
        ("variable.parameter", .attr),
        ("entity.name.type", .type),
        ("entity.name.class", .type),
        ("entity.other.inherited-class", .type),
        ("support.class", .type),
        ("support.type", .type),
        ("entity.name.section", .heading),
        ("markup.heading", .heading),
        ("punctuation", .punct),
    ]

    private static func kind(of scopes: [String]) -> TokenKind? {
        // Mọi thứ nằm trong chú thích (kể cả dấu mở chú thích) đều là chú thích.
        if scopes.contains(where: { $0 == "comment" || $0.hasPrefix("comment.") }) { return .comment }
        for s in scopes.reversed() {
            for (p, k) in scopeTable where s == p || s.hasPrefix(p + ".") { return k }
        }
        return nil
    }

    // MARK: Tách token

    private func endRegex(for rule: TMRule, begin m: NSTextCheckingResult, in line: NSString) -> NSRegularExpression? {
        guard var src = rule.endSrc else { return nil }
        guard src.contains("\\") && src.range(of: "\\\\[1-9]", options: .regularExpression) != nil else { return rule.endRE }
        for i in 1..<10 where i < m.numberOfRanges {
            let r = m.range(at: i)
            guard r.location != NSNotFound else { continue }
            src = src.replacingOccurrences(of: "\\\(i)", with: NSRegularExpression.escapedPattern(for: line.substring(with: r)))
        }
        if let cached = endCache[src] { return cached }
        let re = TMGrammar.compile(src)
        endCache[src] = re
        return re
    }

    /// Trả về các đoạn (vị trí UTF-16, loại token) theo thứ tự tô; đoạn sau đè đoạn trước.
    func tokens(for text: String) -> [(NSRange, TokenKind)] {
        let ns = text as NSString
        var out: [(NSRange, TokenKind)] = []
        var stack: [TMFrame] = []
        var lineStart = 0

        func scopes(content: Bool) -> [String] {
            var s: [String] = []
            for (i, f) in stack.enumerated() {
                if let n = f.rule.name { s.append(n) }
                if content || i < stack.count - 1, let c = f.rule.contentName { s.append(c) }
            }
            return s
        }
        func emit(_ r: NSRange, _ sc: [String], base: Int) {
            guard r.length > 0, r.location != NSNotFound, let k = TMGrammar.kind(of: sc) else { return }
            out.append((NSRange(location: base + r.location, length: r.length), k))
        }
        func captures(_ caps: [Int: String], _ m: NSTextCheckingResult, _ sc: [String], base: Int) {
            for i in caps.keys.sorted() where i > 0 && i < m.numberOfRanges {
                emit(m.range(at: i), sc + [caps[i]!], base: base)
            }
        }

        while lineStart < ns.length {
            let lr = ns.lineRange(for: NSRange(location: lineStart, length: 0))
            let line = ns.substring(with: lr)
            let nl = line as NSString
            let len = nl.length
            var pos = 0
            var guardN = 0
            while pos < len && guardN < 1500 {
                guardN += 1
                let range = NSRange(location: pos, length: len - pos)
                let candidates = stack.last.map { patterns(of: $0.rule) } ?? rootFlat

                var bestM: NSTextCheckingResult?
                var bestRule: TMRule?
                var bestIsEnd = false
                for r in candidates {
                    guard let re = r.isBegin ? r.beginRE : r.matchRE,
                          let m = re.firstMatch(in: line, options: [], range: range) else { continue }
                    if bestM == nil || m.range.location < bestM!.range.location { bestM = m; bestRule = r }
                }
                var endRE: NSRegularExpression?
                if let top = stack.last {
                    endRE = top.end
                    if let e = endRE, let em = e.firstMatch(in: line, options: [], range: range) {
                        if bestM == nil || em.range.location < bestM!.range.location
                            || (em.range.location == bestM!.range.location && !top.rule.applyEndPatternLast) {
                            bestM = em; bestRule = top.rule; bestIsEnd = true
                        }
                    }
                }

                guard let m = bestM, let rule = bestRule else {
                    emit(range, scopes(content: true), base: lr.location)
                    break
                }
                if m.range.location > pos {
                    emit(NSRange(location: pos, length: m.range.location - pos), scopes(content: true), base: lr.location)
                }
                let mEnd = m.range.location + m.range.length

                if bestIsEnd {
                    let sc = scopes(content: false)
                    emit(m.range, sc, base: lr.location)
                    captures(rule.endCaptures, m, sc, base: lr.location)
                    stack.removeLast()
                } else if rule.isBegin {
                    var sc = scopes(content: true)
                    if let n = rule.name { sc.append(n) }
                    emit(m.range, sc, base: lr.location)
                    captures(rule.beginCaptures, m, sc, base: lr.location)
                    stack.append(TMFrame(rule: rule, end: endRegex(for: rule, begin: m, in: nl)))
                } else {
                    var sc = scopes(content: true)
                    if let n = rule.name { sc.append(n) }
                    emit(m.range, sc, base: lr.location)
                    captures(rule.captures, m, sc, base: lr.location)
                }
                // Khớp rỗng mà không đổi trạng thái: nhích 1 ký tự để không lặp vô hạn.
                pos = (m.range.length == 0 && !bestIsEnd && !rule.isBegin) ? mEnd + 1 : max(mEnd, pos)
                if m.range.length == 0 && (bestIsEnd || rule.isBegin) && mEnd == pos && guardN > 1000 { pos += 1 }
            }
            lineStart = NSMaxRange(lr)
        }
        return out
    }
}

// MARK: - Kho lưu trữ

final class GrammarStore {
    static let shared = GrammarStore()
    private let fm = FileManager.default
    private(set) var grammars: [(file: String, grammar: TMGrammar)] = []

    var directory: URL { CatnipPaths.root.appendingPathComponent("Grammars", isDirectory: true) }

    private init() {
        try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
        reload()
    }

    func reload() {
        let files = (try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil,
                                                 options: [.skipsHiddenFiles])) ?? []
        grammars = files
            .filter { $0.pathExtension.lowercased() == "tmlanguage" }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url) else { return nil }
                let base = (url.lastPathComponent as NSString).deletingPathExtension
                return TMGrammar(data: data, fallbackName: base).map { (file: url.lastPathComponent, grammar: $0) }
            }
    }

    /// Ngữ pháp đã nhập khớp với đuôi (hoặc tên) file; không có thì nil để dùng bộ tô màu có sẵn.
    func grammar(forFile path: String) -> TMGrammar? {
        let file = (path as NSString).lastPathComponent.lowercased()
        let ext = (file as NSString).pathExtension
        for (_, g) in grammars {
            for t in g.fileTypes.map({ $0.lowercased() }) where t == ext || t == file { return g }
        }
        return nil
    }

    private func collect(_ url: URL, into out: inout [(URL, Data)], bundleName: inout String?) {
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return }
        if !isDir.boolValue {
            let ext = url.pathExtension.lowercased()
            if ext == "tmlanguage" || ext == "plist" || ext == "json",
               url.lastPathComponent.lowercased() != "info.plist",
               let d = try? Data(contentsOf: url) { out.append((url, d)) }
            return
        }
        // Thư mục .tmbundle: info.plist (tên bundle) + Syntaxes/*.tmLanguage (tìm đệ quy cho chắc).
        if let info = try? Data(contentsOf: url.appendingPathComponent("info.plist")),
           let obj = (try? PropertyListSerialization.propertyList(from: info, options: [], format: nil)) as? [String: Any] {
            bundleName = obj["name"] as? String
        }
        guard let en = fm.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else { return }
        for case let f as URL in en {
            let ext = f.pathExtension.lowercased()
            let inSyntaxes = f.deletingLastPathComponent().lastPathComponent.lowercased() == "syntaxes"
            if ext == "tmlanguage" || (inSyntaxes && (ext == "plist" || ext == "json")),
               let d = try? Data(contentsOf: f) { out.append((f, d)) }
        }
    }

    /// Nhập các file/thư mục đã chọn. Trả về tên các cú pháp đã thêm; không có cái nào hợp lệ thì ném lỗi.
    @discardableResult
    func importItems(_ urls: [URL]) throws -> [String] {
        var found: [(URL, Data)] = []
        var bundleName: String?
        for u in urls { collect(u, into: &found, bundleName: &bundleName) }
        var added: [String] = []
        var problems: [String] = []
        try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
        for (url, data) in found {
            let base = (url.lastPathComponent as NSString).deletingPathExtension
            guard let g = TMGrammar(data: data, fallbackName: base) else {
                problems.append("\(url.lastPathComponent): không phải file ngữ pháp TextMate hợp lệ (cần plist/JSON có scopeName hoặc patterns)")
                continue
            }
            var safe = g.scopeName
            for bad in ["/", ":", "\\", " "] { safe = safe.replacingOccurrences(of: bad, with: "_") }
            if safe.isEmpty { safe = base }
            do { try data.write(to: directory.appendingPathComponent(safe + ".tmLanguage"), options: .atomic) }
            catch { throw StoreError.io(error.localizedDescription) }
            added.append(g.name)
        }
        guard !added.isEmpty else {
            let names = urls.map { $0.lastPathComponent }.joined(separator: ", ")
            var msg = found.isEmpty
                ? "Không thấy file .tmLanguage nào trong: \(names). Hãy chọn file .tmLanguage, hoặc thư mục .tmbundle (hay thư mục Syntaxes) có chứa chúng."
                : "Không nhập được cú pháp nào."
            if !problems.isEmpty { msg += "\n\n" + problems.joined(separator: "\n") }
            throw GHError(msg)
        }
        reload()
        NotificationCenter.default.post(name: .catnipSettingsChanged, object: nil)
        return added
    }

    func delete(file: String) {
        try? fm.removeItem(at: directory.appendingPathComponent(file))
        reload()
        NotificationCenter.default.post(name: .catnipSettingsChanged, object: nil)
    }
}

// MARK: - Màn hình quản lý

final class GrammarsViewController: UITableViewController, UIDocumentPickerDelegate {
    init() { super.init(style: .insetGrouped) }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Định cú pháp"
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Nhập…", style: .plain, target: self, action: #selector(importTapped))
    }

    @objc private func importTapped() {
        let sheet = UIAlertController(title: "Nhập định cú pháp", message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Chọn file .tmLanguage…", style: .default) { [weak self] _ in self?.pick(folders: false) })
        sheet.addAction(UIAlertAction(title: "Chọn thư mục .tmbundle…", style: .default) { [weak self] _ in self?.pick(folders: true) })
        sheet.addAction(UIAlertAction(title: "Huỷ", style: .cancel))
        sheet.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem
        present(sheet, animated: true)
    }

    /// Chọn file: mọi loại file (.tmLanguage không có kiểu hệ thống). Chọn thư mục: chỉ thư mục, bấm "Mở" để lấy cả thư mục.
    /// asCopy: bản sao vào thư mục tạm, khỏi lo quyền truy cập vào bên trong thư mục.
    private func pick(folders: Bool) {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: folders ? [.folder] : [.item], asCopy: true)
        picker.allowsMultipleSelection = !folders
        picker.delegate = self
        present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        let scoped = urls.map { $0.startAccessingSecurityScopedResource() }
        defer { for (u, ok) in zip(urls, scoped) where ok { u.stopAccessingSecurityScopedResource() } }
        do {
            let names = try GrammarStore.shared.importItems(urls)
            tableView.reloadData()
            let ac = UIAlertController(title: "Đã nhập \(names.count) cú pháp", message: names.joined(separator: ", "), preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default))
            present(ac, animated: true)
        } catch {
            showError(error)
        }
    }

    override func tableView(_ tv: UITableView, numberOfRowsInSection section: Int) -> Int {
        max(GrammarStore.shared.grammars.count, 1)
    }
    override func tableView(_ tv: UITableView, titleForFooterInSection section: Int) -> String? {
        "Nhập file .tmLanguage, hoặc cả thư mục .tmbundle (info.plist + Syntaxes/*.tmLanguage). File có đuôi khớp fileTypes của cú pháp sẽ tự dùng cú pháp đó; cũng chọn tay được ở menu ⋯ → Ngôn ngữ tô màu. Vuốt trái để xoá."
    }
    override func tableView(_ tv: UITableView, cellForRowAt ip: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.selectionStyle = .none
        let list = GrammarStore.shared.grammars
        if list.isEmpty {
            cell.textLabel?.text = "Chưa nhập cú pháp nào"
            cell.textLabel?.textColor = .secondaryLabel
        } else {
            let g = list[ip.row].grammar
            cell.textLabel?.text = g.name
            cell.detailTextLabel?.text = g.scopeName + (g.fileTypes.isEmpty ? "" : " · " + g.fileTypes.map { "." + $0 }.joined(separator: " "))
            cell.detailTextLabel?.textColor = .secondaryLabel
        }
        return cell
    }
    override func tableView(_ tv: UITableView, trailingSwipeActionsConfigurationForRowAt ip: IndexPath) -> UISwipeActionsConfiguration? {
        guard ip.row < GrammarStore.shared.grammars.count else { return nil }
        let file = GrammarStore.shared.grammars[ip.row].file
        let a = UIContextualAction(style: .destructive, title: "Xoá") { [weak self] _, _, done in
            GrammarStore.shared.delete(file: file)
            self?.tableView.reloadData()
            done(true)
        }
        return UISwipeActionsConfiguration(actions: [a])
    }
}
