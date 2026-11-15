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

// SpellCheck.swift
// Soát lỗi chính tả tiếng Việt cho file Markdown. Không cần từ điển: kiểm tra từng tiếng (âm tiết)
// theo quy tắc ghép âm của tiếng Việt (phụ âm đầu + vần + phụ âm cuối + dấu thanh), cộng với:
//   - bảng các cụm từ hay viết sai (vd "xử dụng" → "sử dụng");
//   - từ gõ Telex dở dang (vd "tieengs", "vieejt") nếu từ đó cũng không phải tiếng Anh.
// Từ chỉ gồm chữ không dấu (tiếng Anh, tên công cụ như nasm, vim…) không bị đánh dấu.
// Code (khối ```, `inline`), link, URL, thẻ HTML, front matter được bỏ qua.

import UIKit

enum VietnameseSpell {

    struct Issue {
        let range: NSRange
        let suggestion: String?
    }

    enum Verdict { case ok, bad, skip }

    // MARK: Bảng quy tắc

    private static let tones: [Unicode.Scalar: Character] = [
        "\u{0300}": "f", "\u{0301}": "s", "\u{0303}": "x", "\u{0309}": "r", "\u{0323}": "j"
    ]
    private static let qualities: [Unicode.Scalar: String] = [
        "\u{0306}": "(", "\u{0302}": "^", "\u{031B}": "+"
    ]
    private static let vowels: Set<Character> = ["a", "e", "i", "o", "u", "y"]
    private static let consonantLetters = "bcdđghklmnpqrstvx"

    /// Vần (nguyên âm) → các phụ âm cuối cho phép ("" = không có).
    private static let nuclei: [String: Set<String>] = {
        var t: [String: Set<String>] = [:]
        func add(_ nuc: String, _ finals: String) {
            t[nuc] = Set(finals.split(separator: " ").map { $0 == "''" ? "" : String($0) })
        }
        add("a",  "'' c ch m n ng nh p t")
        add("a(", "c m n ng p t")
        add("a^", "c m n ng p t")
        add("e",  "'' c m n ng p t")
        add("e^", "'' ch m n nh p t")
        add("i",  "'' ch m n nh p t")
        add("o",  "'' c m n ng p t")
        add("o^", "'' c m n ng p t")
        add("o+", "'' m n p t")
        add("u",  "'' c m n ng p t")
        add("u+", "'' c m n ng t")
        add("y",  "'' t n nh ch p")
        for n in ["ai", "ao", "au", "a^u", "ay", "a^y", "eo", "e^u", "iu", "oi", "o^i", "o+i", "ui", "u+i", "u+u",
                  "oai", "oao", "oay", "oeo", "uai", "ua^y", "ie^u", "ye^u", "uo^i", "u+o+i", "u+o+u",
                  "uya", "uyu", "uye^u", "ia", "ua", "u+a"] {
            add(n, "''")
        }
        add("ie^", "c m n ng p t")
        add("ye^", "m n ng t")
        add("uo^", "c m n ng t")
        add("u+o+", "c m n ng p t")
        add("oa",  "'' c ch m n ng nh p t")
        add("oa(", "c m n ng t")
        add("oe",  "'' n t m")
        add("ua^", "n ng t")
        add("ue^", "'' n nh ch t")
        add("uy",  "'' t n nh ch p")
        add("uye^", "n t")
        add("oo",  "ng c")
        return t
    }()

    /// Vần có hai nguyên âm mà dấu thanh phải nằm ở nguyên âm thứ hai / thứ nhất.
    private static let toneOnSecond: Set<String> = ["ie^", "ye^", "uo^", "u+o+"]
    private static let toneOnFirst: Set<String> = [
        "ia", "ua", "u+a", "ai", "ao", "au", "a^u", "ay", "a^y", "eo", "e^u", "iu", "oi", "o^i", "o+i", "ui", "u+i", "u+u"
    ]

    private static let initials = ["ngh", "ch", "gh", "gi", "kh", "ng", "nh", "ph", "qu", "th", "tr",
                                   "b", "c", "d", "đ", "g", "h", "k", "l", "m", "n", "p", "r", "s", "t", "v", "x", ""]
    private static let finals = ["", "ch", "ng", "nh", "c", "m", "n", "p", "t"]

    // MARK: Phân tích một tiếng

    /// "Tiếng" thành danh sách chữ cái, mỗi chữ là chữ gốc + dấu mũ/móc ("a(", "a^", "o+"), kèm dấu thanh.
    private static func decompose(_ word: String) -> (letters: [String], tone: Character?, toneAt: Int)? {
        var letters: [String] = []
        var tone: Character?
        var toneAt = -1
        for scalar in word.lowercased().decomposedStringWithCanonicalMapping.unicodeScalars {
            if let t = tones[scalar] {
                guard tone == nil, let last = letters.last, let f = last.first, vowels.contains(f) else { return nil }
                tone = t
                toneAt = letters.count - 1
            } else if let q = qualities[scalar] {
                guard let last = letters.last, let f = last.first, vowels.contains(f), last.count == 1 else { return nil }
                letters[letters.count - 1] = last + q
            } else if scalar.properties.generalCategory == .nonspacingMark {
                return nil
            } else {
                letters.append(String(Character(scalar)))
            }
        }
        return (letters, tone, toneAt)
    }

    /// Có chữ cái ngoài bảng chữ cái tiếng Việt (f, j, w, z, ö, é…) → không phải tiếng Việt, bỏ qua.
    private static func hasForeignLetters(_ word: String) -> Bool {
        let allowed = Set("abcdđeghiklmnopqrstuvxy")
        for scalar in word.lowercased().decomposedStringWithCanonicalMapping.unicodeScalars {
            if tones[scalar] != nil || qualities[scalar] != nil { continue }
            if scalar.properties.generalCategory == .nonspacingMark { return true }
            if !allowed.contains(Character(scalar)) { return true }
        }
        return false
    }

    private static func validLetters(_ letters: [String], tone: Character?, toneAt: Int) -> Bool {
        guard !letters.isEmpty else { return false }
        let okMarked: Set<String> = ["a(", "a^", "e^", "o^", "o+", "u+"]
        for c in letters {
            guard let f = c.first, "abcdđeghiklmnopqrstuvxy".contains(f) else { return false }
            if c.count > 1 && !okMarked.contains(c) { return false }
        }
        let base = letters.map { String($0.first!) }.joined()

        for ini in initials {
            if !ini.isEmpty {
                guard base.hasPrefix(ini), letters.prefix(ini.count).allSatisfy({ $0.count == 1 }) else { continue }
            }
            let rest = Array(letters.dropFirst(ini.count))
            for fin in finals {
                var nucLetters = rest
                if !fin.isEmpty {
                    let k = fin.count
                    guard rest.count > k, rest.suffix(k).joined() == fin else { continue }
                    nucLetters = Array(rest.dropLast(k))
                }
                guard let first = nucLetters.first else { continue }
                if nucLetters.contains(where: { !vowels.contains($0.first!) }) { continue }
                let nuc = nucLetters.joined()
                if ini == "qu" && first.first == "u" { continue }
                guard let allowed = nuclei[nuc], allowed.contains(fin) else { continue }
                if nuc == "y" && !fin.isEmpty && ini != "qu" { continue }

                let front = first.first == "i" || first.first == "y" || first == "e" || first == "e^"
                if ini == "k" && !front { continue }
                if (ini == "c" || ini == "ng") && front { continue }
                if ini == "g" && front && first.first != "i" { continue }
                if (ini == "gh" || ini == "ngh") && !front { continue }

                if ["c", "ch", "p", "t"].contains(fin) && tone != "s" && tone != "j" { continue }

                if toneAt >= 0 {
                    let pos = toneAt - ini.count
                    if toneOnSecond.contains(nuc) && pos != 1 { continue }
                    if toneOnFirst.contains(nuc) && pos != 0 { continue }
                }
                return true
            }
        }
        return false
    }

    private static func isValidSyllable(_ word: String) -> Bool {
        guard let d = decompose(word) else { return false }
        return validLetters(d.letters, tone: d.tone, toneAt: d.toneAt)
    }

    // MARK: Telex dở dang

    /// Từ ASCII có vẻ là tiếng Việt gõ Telex mà chưa chuyển thành chữ có dấu (vd "tieengs", "dduwowcj").
    private static func looksLikeUnconvertedTelex(_ lower: String) -> Bool {
        let w = Array(lower)
        var keyIndexes: [Int] = []
        for (i, ch) in w.enumerated() where "sfrxj".contains(ch) && i > 0 {
            if i == w.count - 1 || "aeiouyw".contains(w[i - 1]) { keyIndexes.append(i) }
        }
        var attempts: [Int?] = keyIndexes.map { Optional($0) }
        attempts.append(nil)

        for ti in attempts {
            var chars = w
            var tone: Character?
            if let ti = ti { tone = w[ti]; chars.remove(at: ti) }
            var out: [String] = []
            var i = 0
            var ok = true
            while i < chars.count {
                let ch = chars[i]
                let next: Character? = i + 1 < chars.count ? chars[i + 1] : nil
                if ch == "d", next == "d" { out.append("đ"); i += 2 }
                else if "aeo".contains(ch), next == ch { out.append(String(ch) + "^"); i += 2 }
                else if ch == "a", next == "w" { out.append("a("); i += 2 }
                else if "ou".contains(ch), next == "w" { out.append(String(ch) + "+"); i += 2 }
                else if ch == "w" { ok = false; break }
                else { out.append(String(ch)); i += 1 }
            }
            if !ok { continue }
            if out.count >= 2 {
                for k in 0..<(out.count - 1) where out[k] == "u" && out[k + 1] == "o+" { out[k] = "u+" }
            }
            // Cần ít nhất một dấu mũ/móc/đ kiểu Telex, nếu không thì chỉ là một từ ASCII bình thường.
            if !out.contains(where: { $0.count > 1 || $0 == "đ" }) { continue }
            if validLetters(out, tone: tone, toneAt: -1) { return true }
        }
        return false
    }

    // MARK: Đánh giá một từ

    private static var cache: [String: Verdict] = [:]
    private static let checker = UITextChecker()
    private static let englishAvailable: Bool = UITextChecker.availableLanguages.contains { $0.hasPrefix("en") }

    private static func isEnglish(_ word: String) -> Bool {
        let range = NSRange(location: 0, length: (word as NSString).length)
        let miss = checker.rangeOfMisspelledWord(in: word, range: range, startingAt: 0, wrap: false, language: "en_US")
        return miss.location == NSNotFound
    }

    static func verdict(for word: String) -> Verdict {
        if let hit = cache[word] { return hit }
        let v = computeVerdict(word)
        if cache.count > 20_000 { cache.removeAll() }
        cache[word] = v
        return v
    }

    private static func computeVerdict(_ word: String) -> Verdict {
        if word.count <= 1 { return .skip }
        if word == word.uppercased() && word.count <= 4 { return .skip }   // viết tắt: ĐH, TP, ĐT…
        if word.contains(where: { $0.isNumber || $0 == "_" }) { return .skip }
        // camelCase / có chữ hoa ở giữa (tên hàm, thương hiệu): bỏ qua. Viết hoa toàn bộ thì vẫn kiểm.
        let tail = String(word.dropFirst())
        if tail != tail.lowercased() && word != word.uppercased() { return .skip }

        let decomposed = word.lowercased().decomposedStringWithCanonicalMapping.unicodeScalars
        let hasMarks = decomposed.contains { tones[$0] != nil || qualities[$0] != nil || $0.properties.generalCategory == .nonspacingMark }
            || word.lowercased().contains("đ")
        if hasMarks {
            if hasForeignLetters(word) { return .skip }
            return isValidSyllable(word) ? .ok : .bad
        }

        // Chỉ gồm chữ không dấu.
        let lower = word.lowercased()
        guard lower.count >= 4, englishAvailable,
              lower.unicodeScalars.allSatisfy({ $0.value >= 97 && $0.value <= 122 }) else { return .skip }
        guard looksLikeUnconvertedTelex(lower) else { return .skip }
        return isEnglish(word) ? .skip : .bad
    }

    // MARK: Cụm từ hay viết sai

    /// (viết sai, viết đúng)
    private static let commonMistakes: [(String, String)] = [
        ("xử dụng", "sử dụng"),
        ("sát nhập", "sáp nhập"),
        ("dành giật", "giành giật"),
        ("dành chiến thắng", "giành chiến thắng"),
        ("chia sẽ", "chia sẻ"),
        ("sẳn sàng", "sẵn sàng"),
        ("nghành", "ngành"),
        ("sáng lạng", "xán lạn"),
        ("trao dồi", "trau dồi"),
        ("viết tắc", "viết tắt"),
        ("phát tiển", "phát triển"),
        ("thăm quan", "tham quan"),
        ("bổ xung", "bổ sung"),
        ("suất sắc", "xuất sắc"),
        ("mạnh mẻ", "mạnh mẽ"),
        ("chắc chắc", "chắc chắn"),
        ("gở lỗi", "gỡ lỗi"),
        ("tập chung", "tập trung"),
        ("khoảng khắc", "khoảnh khắc")
    ]

    // MARK: Quét văn bản

    private static func regex(_ pattern: String, _ options: NSRegularExpression.Options = []) -> NSRegularExpression? {
        try? NSRegularExpression(pattern: pattern, options: options)
    }

    private static let excludePatterns: [NSRegularExpression] = [
        regex("\\A---[ \\t]*\\n[\\s\\S]*?\\n---[ \\t]*(?:\\n|\\z)"),                                          // front matter
        regex("^[ \\t]*(`{3,}|~{3,})[^\\n]*\\n[\\s\\S]*?(?:^[ \\t]*\\1[ \\t]*$|\\z)", [.anchorsMatchLines]),   // khối code
        regex("`[^`\\n]+`"),                                                                                  // code nội dòng
        regex("(?:https?://|www\\.)[^\\s)>\\]]+"),                                                            // URL
        regex("\\]\\([^)\\n]*\\)"),                                                                           // đích của link
        regex("</?[A-Za-z][^>\\n]*>"),                                                                        // thẻ HTML
        regex("^\\[[^\\]\\n]+\\]:[ \\t]*\\S+", [.anchorsMatchLines])                                          // định nghĩa link tham chiếu
    ].compactMap { $0 }

    private static let wordRegex = regex("[\\p{L}\\p{M}]+")

    static func issues(in text: String) -> [Issue] {
        let ns = text as NSString
        let length = ns.length
        guard length > 0, let wordRegex = wordRegex else { return [] }
        let full = NSRange(location: 0, length: length)

        var excluded = [Bool](repeating: false, count: length)
        for re in excludePatterns {
            re.enumerateMatches(in: text, options: [], range: full) { m, _, _ in
                guard let r = m?.range else { return }
                for i in r.location..<min(r.location + r.length, length) { excluded[i] = true }
            }
        }

        var found: [Issue] = []
        var covered = [Bool](repeating: false, count: length)   // đã bị cụm từ sai chiếm, tránh đánh dấu hai lần

        // 1. Cụm từ hay viết sai.
        for (wrong, right) in commonMistakes {
            let pattern = "(?<![\\p{L}\\p{M}])" + NSRegularExpression.escapedPattern(for: wrong) + "(?![\\p{L}\\p{M}])"
            guard let re = regex(pattern, [.caseInsensitive]) else { continue }
            re.enumerateMatches(in: text, options: [], range: full) { m, _, _ in
                guard let r = m?.range, !excluded[r.location] else { return }
                found.append(Issue(range: r, suggestion: right))
                for i in r.location..<(r.location + r.length) { covered[i] = true }
            }
        }

        // 2. Từng tiếng.
        wordRegex.enumerateMatches(in: text, options: [], range: full) { m, _, _ in
            guard let r = m?.range, !excluded[r.location], !covered[r.location] else { return }
            if r.location > 0 {
                let prev = ns.character(at: r.location - 1)
                if prev == 0x40 || prev == 0x23 || prev == 0x2F { return }   // @ # /
            }
            let word = ns.substring(with: r)
            if verdict(for: word) == .bad { found.append(Issue(range: r, suggestion: nil)) }
        }
        return found.sorted { $0.range.location < $1.range.location }
    }

    /// Tô đỏ các lỗi trong `storage` (gọi sau khi tô màu cú pháp). Trả về danh sách lỗi.
    @discardableResult
    static func apply(to storage: NSTextStorage) -> [Issue] {
        let list = issues(in: storage.string)
        guard !list.isEmpty else { return [] }
        let red = UIColor.systemRed
        storage.beginEditing()
        for issue in list {
            storage.addAttributes([
                .foregroundColor: red,
                .backgroundColor: red.withAlphaComponent(0.18),
                .underlineStyle: NSUnderlineStyle.single.rawValue | NSUnderlineStyle.patternDot.rawValue,
                .underlineColor: red
            ], range: issue.range)
        }
        storage.endEditing()
        return list
    }
}
