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


// Cửa sổ shell của Catnip (bật/tắt trong Cài đặt). Thư mục gốc "/" của shell chính là Documents của app,
// cùng nơi lưu các dự án, nên file tạo ở đây cũng hiện trong trình soạn thảo và trong app Tệp.
//
// Hiện là shell dựng sẵn với các lệnh cơ bản (ls, cd, cat, cp, mv, rm, grep...), chưa phải Linux đầy đủ.
// `ShellBackend` là điểm để sau này nối lõi giả lập (iSH) vào mà không phải sửa giao diện.

import UIKit

// MARK: - Backend

protocol ShellBackend: AnyObject {
    var prompt: String { get }
    /// Chạy một dòng lệnh, trả về chữ cần hiện. `clear` = true thì xoá màn hình trước.
    func run(_ line: String) -> (output: String, clear: Bool)
}

private enum ShellError: LocalizedError {
    case outside, notFound(String), usage(String), msg(String), exists(String), notDir(String), isDir(String)
    var errorDescription: String? {
        switch self {
        case .outside:          return "không được ra ngoài thư mục Documents"
        case .notFound(let p):  return "\(p): không tìm thấy"
        case .usage(let u):     return "cách dùng: \(u)"
        case .msg(let m):       return m
        case .exists(let p):    return "\(p): đã tồn tại"
        case .notDir(let p):    return "\(p): không phải thư mục"
        case .isDir(let p):     return "\(p): là thư mục (dùng -r)"
        }
    }
}

/// Shell cơ bản chạy trực tiếp trên Documents.
final class BuiltinShell: ShellBackend {

    private let fm = FileManager.default
    private let root: URL
    private let rootPath: String
    private var cwd: URL

    init(root: URL = CatnipPaths.projects) {
        self.root = root.standardizedFileURL
        self.rootPath = root.standardizedFileURL.resolvingSymlinksInPath().path
        self.cwd = root.standardizedFileURL
    }

    var prompt: String { "catnip:" + display(cwd) + "$ " }

    // MARK: Đường dẫn

    private func display(_ url: URL) -> String {
        let p = url.standardizedFileURL.resolvingSymlinksInPath().path
        if p == rootPath { return "/" }
        return p.hasPrefix(rootPath + "/") ? String(p.dropFirst(rootPath.count)) : "/"
    }

    private func resolve(_ input: String) throws -> URL {
        var path = input
        if path == "~" { path = "/" } else if path.hasPrefix("~/") { path = "/" + String(path.dropFirst(2)) }
        var url = path.hasPrefix("/") ? root : cwd
        for comp in path.split(separator: "/") {
            switch comp {
            case ".": continue
            case "..": url = url.deletingLastPathComponent()
            default:   url.appendPathComponent(String(comp))
            }
        }
        let real = url.standardizedFileURL.resolvingSymlinksInPath().path
        guard real == rootPath || real.hasPrefix(rootPath + "/") else { throw ShellError.outside }
        return url.standardizedFileURL
    }

    private func isDir(_ u: URL) -> Bool {
        var d: ObjCBool = false
        return fm.fileExists(atPath: u.path, isDirectory: &d) && d.boolValue
    }

    // MARK: Phân tích dòng lệnh (hỗ trợ "…" và '…')

    private func tokenize(_ line: String) -> [String] {
        var out: [String] = [], cur = "", quote: Character? = nil, has = false
        for ch in line {
            if let q = quote {
                if ch == q { quote = nil } else { cur.append(ch) }
            } else if ch == "\"" || ch == "'" {
                quote = ch; has = true
            } else if ch == " " || ch == "\t" {
                if !cur.isEmpty || has { out.append(cur); cur = ""; has = false }
            } else { cur.append(ch) }
        }
        if !cur.isEmpty || has { out.append(cur) }
        return out
    }

    // MARK: Chạy lệnh

    func run(_ line: String) -> (output: String, clear: Bool) {
        var args = tokenize(line)
        guard !args.isEmpty else { return ("", false) }
        let cmd = args.removeFirst()
        if cmd == "clear" { return ("", true) }

        // Chuyển hướng: "lệnh … > file" hoặc ">> file"
        var redirect: (path: String, append: Bool)?
        if let i = args.firstIndex(where: { $0 == ">" || $0 == ">>" }) {
            guard i + 1 < args.count else { return ("lỗi: thiếu tên file sau \(args[i])\n", false) }
            redirect = (args[i + 1], args[i] == ">>")
            args.removeSubrange(i...(i + 1))
        }

        do {
            let result = try execute(cmd, args)
            if let r = redirect {
                let url = try resolve(r.path)
                var data = Data(result.utf8)
                if r.append, let old = try? Data(contentsOf: url) { data = old + data }
                try data.write(to: url, options: .atomic)
                return ("", false)
            }
            return (result, false)
        } catch {
            return ("\(cmd): \(error.localizedDescription)\n", false)
        }
    }

    private func flags(_ args: [String]) -> (flags: Set<Character>, rest: [String]) {
        var f = Set<Character>(), rest: [String] = []
        for a in args {
            if a.count > 1, a.hasPrefix("-"), !a.hasPrefix("--") { f.formUnion(a.dropFirst()) } else { rest.append(a) }
        }
        return (f, rest)
    }

    private func execute(_ cmd: String, _ raw: [String]) throws -> String {
        let (f, a) = flags(raw)
        switch cmd {
        case "help":
            return """
            Lệnh có sẵn (thư mục gốc "/" là Documents):
              pwd  cd  ls [-l] [-a]  tree  cat  head [-n N]  tail [-n N]  wc
              mkdir [-p]  touch  rm [-r]  cp [-r]  mv  echo  grep [-i] [-n]  find
              clear  help
            Chuyển hướng: echo xin chào > file.txt   (>> để nối thêm)

            """
        case "pwd":
            return display(cwd) + "\n"
        case "echo":
            return raw.joined(separator: " ") + "\n"
        case "cd":
            let u = try resolve(a.first ?? "/")
            guard fm.fileExists(atPath: u.path) else { throw ShellError.notFound(a.first ?? "/") }
            guard isDir(u) else { throw ShellError.notDir(a[0]) }
            cwd = u
            return ""
        case "ls":
            return try ls(a.isEmpty ? ["."] : a, long: f.contains("l"), all: f.contains("a"))
        case "tree":
            let u = try resolve(a.first ?? ".")
            guard isDir(u) else { throw ShellError.notDir(a.first ?? ".") }
            return tree(u, prefix: "", depth: 0)
        case "cat":
            guard !a.isEmpty else { throw ShellError.usage("cat file...") }
            return try a.map { try readText($0) }.joined()
        case "head", "tail":
            var n = 10
            var files = raw
            if let i = files.firstIndex(of: "-n"), i + 1 < files.count, let v = Int(files[i + 1]) {
                n = max(0, v); files.removeSubrange(i...(i + 1))
            }
            guard let file = files.first(where: { !$0.hasPrefix("-") }) else { throw ShellError.usage("\(cmd) [-n N] file") }
            var lines = try readText(file).components(separatedBy: "\n")
            if lines.last == "" { lines.removeLast() }
            let part = cmd == "head" ? Array(lines.prefix(n)) : Array(lines.suffix(n))
            return part.isEmpty ? "" : part.joined(separator: "\n") + "\n"
        case "wc":
            guard let file = a.first else { throw ShellError.usage("wc file") }
            let t = try readText(file)
            let lines = t.reduce(0) { $0 + ($1 == "\n" ? 1 : 0) }
            let words = t.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" }).count
            return "\(lines) \(words) \(t.utf8.count) \(file)\n"
        case "mkdir":
            guard !a.isEmpty else { throw ShellError.usage("mkdir [-p] thư_mục...") }
            for p in a {
                let u = try resolve(p)
                if fm.fileExists(atPath: u.path) { if f.contains("p") { continue }; throw ShellError.exists(p) }
                try fm.createDirectory(at: u, withIntermediateDirectories: f.contains("p"))
            }
            return ""
        case "touch":
            guard !a.isEmpty else { throw ShellError.usage("touch file...") }
            for p in a {
                let u = try resolve(p)
                if fm.fileExists(atPath: u.path) { try fm.setAttributes([.modificationDate: Date()], ofItemAtPath: u.path) }
                else { try Data().write(to: u) }
            }
            return ""
        case "rm":
            guard !a.isEmpty else { throw ShellError.usage("rm [-r] đường_dẫn...") }
            for p in a {
                let u = try resolve(p)
                if u.path == root.path { throw ShellError.outside }
                guard fm.fileExists(atPath: u.path) else { throw ShellError.notFound(p) }
                if isDir(u), !(f.contains("r") || f.contains("R")) { throw ShellError.isDir(p) }
                try fm.removeItem(at: u)
            }
            if !isDir(cwd) { cwd = root }
            return ""
        case "cp", "mv":
            guard a.count == 2 else { throw ShellError.usage("\(cmd) nguồn đích") }
            let src = try resolve(a[0]); var dst = try resolve(a[1])
            guard fm.fileExists(atPath: src.path) else { throw ShellError.notFound(a[0]) }
            if isDir(dst) { dst.appendPathComponent(src.lastPathComponent) }
            guard !fm.fileExists(atPath: dst.path) else { throw ShellError.exists(a[1]) }
            if isDir(src), cmd == "cp", !(f.contains("r") || f.contains("R")) { throw ShellError.isDir(a[0]) }
            if dst.path.hasPrefix(src.path + "/") { throw ShellError.msg("không thể đưa thư mục vào chính nó") }
            if cmd == "cp" { try fm.copyItem(at: src, to: dst) } else { try fm.moveItem(at: src, to: dst) }
            if !isDir(cwd) { cwd = root }
            return ""
        case "grep":
            guard a.count >= 2 else { throw ShellError.usage("grep [-i] [-n] mẫu file...") }
            let pattern = f.contains("i") ? a[0].lowercased() : a[0]
            let files = Array(a.dropFirst())
            var out = ""
            for file in files {
                let lines = try readText(file).components(separatedBy: "\n")
                for (i, l) in lines.enumerated() where (f.contains("i") ? l.lowercased() : l).contains(pattern) {
                    out += (files.count > 1 ? file + ":" : "") + (f.contains("n") ? "\(i + 1):" : "") + l + "\n"
                }
            }
            return out
        case "find":
            let base = try resolve(a.first ?? ".")
            let needle = a.count > 1 ? a[1].lowercased() : ""
            guard let en = fm.enumerator(at: base, includingPropertiesForKeys: nil) else { return "" }
            var out: [String] = []
            for case let u as URL in en where needle.isEmpty || u.lastPathComponent.lowercased().contains(needle) {
                out.append(display(u))
                if out.count >= 500 { out.append("… (rút gọn ở 500 kết quả)"); break }
            }
            return out.isEmpty ? "" : out.sorted().joined(separator: "\n") + "\n"
        default:
            throw ShellError.msg("không có lệnh này. Gõ help để xem danh sách")
        }
    }

    private func readText(_ path: String) throws -> String {
        let u = try resolve(path)
        guard fm.fileExists(atPath: u.path) else { throw ShellError.notFound(path) }
        guard !isDir(u) else { throw ShellError.isDir(path) }
        guard let data = try? Data(contentsOf: u) else { throw ShellError.notFound(path) }
        if data.count > 2_000_000 { throw ShellError.msg("file quá lớn (>2 MB)") }
        guard let s = String(data: data, encoding: .utf8) else { throw ShellError.msg("\(path): không phải văn bản UTF-8") }
        return s
    }

    private func ls(_ paths: [String], long: Bool, all: Bool) throws -> String {
        var out = ""
        for p in paths {
            let u = try resolve(p)
            guard fm.fileExists(atPath: u.path) else { throw ShellError.notFound(p) }
            var items: [URL]
            if isDir(u) {
                items = (try? fm.contentsOfDirectory(at: u, includingPropertiesForKeys: nil,
                                                     options: all ? [] : [.skipsHiddenFiles])) ?? []
            } else { items = [u] }
            items.sort { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
            if paths.count > 1 { out += p + ":\n" }
            for it in items {
                let d = isDir(it)
                let name = it.lastPathComponent + (d ? "/" : "")
                if long {
                    let size = ((try? fm.attributesOfItem(atPath: it.path))?[.size] as? NSNumber)?.intValue ?? 0
                    out += String(format: "%@ %10ld  %@\n", d ? "d" : "-", d ? 0 : size, name)
                } else { out += name + "\n" }
            }
        }
        return out
    }

    private func tree(_ dir: URL, prefix: String, depth: Int) -> String {
        guard depth < 6,
              var items = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        else { return "" }
        items.sort { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
        var out = ""
        for (i, it) in items.enumerated() {
            let last = i == items.count - 1
            let d = isDir(it)
            out += prefix + (last ? "└── " : "├── ") + it.lastPathComponent + (d ? "/" : "") + "\n"
            if d { out += tree(it, prefix: prefix + (last ? "    " : "│   "), depth: depth + 1) }
        }
        return out
    }
}

// MARK: - Phiên shell dùng chung (giữ nội dung khi đóng/mở lại cửa sổ)

final class ShellSession {
    static let shared = ShellSession()
    var backend: ShellBackend = BuiltinShell()
    private(set) var transcript = "Catnip shell · thư mục gốc \"/\" là Documents. Gõ help để xem lệnh.\n"
    private(set) var history: [String] = []

    func submit(_ line: String) {
        transcript += backend.prompt + line + "\n"
        if !line.trimmingCharacters(in: .whitespaces).isEmpty, history.last != line { history.append(line) }
        let r = backend.run(line)
        if r.clear { transcript = "" }
        transcript += r.output
        if transcript.count > 200_000 { transcript = String(transcript.suffix(150_000)) }
    }
}

// MARK: - Giao diện

final class ShellViewController: UIViewController, UITextFieldDelegate {

    private let session = ShellSession.shared
    private let output = UITextView()
    private let input = UITextField()
    private let promptLabel = UILabel()
    private let bar = UIView()
    private var historyIndex: Int?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Shell"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done, target: self, action: #selector(doneTapped))

        output.translatesAutoresizingMaskIntoConstraints = false
        output.isEditable = false
        output.alwaysBounceVertical = true
        output.keyboardDismissMode = .interactive
        output.textContainerInset = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
        view.addSubview(output)

        bar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bar)

        promptLabel.translatesAutoresizingMaskIntoConstraints = false
        promptLabel.setContentHuggingPriority(.required, for: .horizontal)
        promptLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        promptLabel.lineBreakMode = .byTruncatingHead
        bar.addSubview(promptLabel)

        input.translatesAutoresizingMaskIntoConstraints = false
        input.autocapitalizationType = .none
        input.autocorrectionType = .no
        input.spellCheckingType = .no
        input.smartDashesType = .no
        input.smartQuotesType = .no
        input.returnKeyType = .send
        input.delegate = self
        bar.addSubview(input)

        let up = historyButton("chevron.up", delta: -1)
        let down = historyButton("chevron.down", delta: 1)
        bar.addSubview(up)
        bar.addSubview(down)

        NSLayoutConstraint.activate([
            output.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            output.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            output.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            output.bottomAnchor.constraint(equalTo: bar.topAnchor),

            bar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bar.heightAnchor.constraint(equalToConstant: 44),
            bar.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),

            promptLabel.leadingAnchor.constraint(equalTo: bar.safeAreaLayoutGuide.leadingAnchor, constant: 10),
            promptLabel.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            promptLabel.widthAnchor.constraint(lessThanOrEqualTo: bar.widthAnchor, multiplier: 0.45),

            input.leadingAnchor.constraint(equalTo: promptLabel.trailingAnchor, constant: 4),
            input.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            input.trailingAnchor.constraint(equalTo: up.leadingAnchor),

            down.trailingAnchor.constraint(equalTo: bar.safeAreaLayoutGuide.trailingAnchor, constant: -4),
            down.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            up.trailingAnchor.constraint(equalTo: down.leadingAnchor),
            up.centerYAnchor.constraint(equalTo: bar.centerYAnchor)
        ])

        NotificationCenter.default.addObserver(self, selector: #selector(applyTheme),
                                               name: .catnipSettingsChanged, object: nil)
        applyTheme()
        refreshOutput()
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        input.becomeFirstResponder()
    }

    private func historyButton(_ symbol: String, delta: Int) -> UIButton {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setImage(UIImage(systemName: symbol), for: .normal)
        b.addAction(UIAction { [weak self] _ in self?.stepHistory(delta) }, for: .touchUpInside)
        b.widthAnchor.constraint(equalToConstant: 36).isActive = true
        b.heightAnchor.constraint(equalToConstant: 36).isActive = true
        return b
    }

    @objc private func applyTheme() {
        let t = Appearance.theme
        Appearance.style(navigationController)
        view.backgroundColor = t.bgColor
        output.backgroundColor = t.bgColor
        output.textColor = t.fgColor
        output.font = Appearance.codeFont(Appearance.terminalFontSize)
        bar.backgroundColor = t.bg2Color
        promptLabel.font = Appearance.codeFont(Appearance.terminalFontSize)
        promptLabel.textColor = t.accentColor
        input.font = Appearance.codeFont(Appearance.terminalFontSize)
        input.textColor = t.fgColor
        input.tintColor = t.accentColor
        refreshOutput()
    }

    private func refreshOutput() {
        output.text = session.transcript
        promptLabel.text = session.backend.prompt.trimmingCharacters(in: .whitespaces)
        output.textColor = Appearance.theme.fgColor
        let end = (output.text as NSString).length
        if end > 0 { output.scrollRangeToVisible(NSRange(location: end - 1, length: 1)) }
    }

    private func stepHistory(_ delta: Int) {
        let h = session.history
        guard !h.isEmpty else { return }
        var i = historyIndex ?? h.count
        i = min(max(i + delta, 0), h.count)
        historyIndex = i
        input.text = i == h.count ? "" : h[i]
    }

    @objc private func doneTapped() { dismiss(animated: true) }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        let line = textField.text ?? ""
        textField.text = ""
        historyIndex = nil
        session.submit(line)
        refreshOutput()
        return false
    }
}

enum IshAvailability {
    /// Bản build này có nhúng iSH (Linux thật) hay không.
    static var isEmbedded: Bool {
        #if CATNIP_HAS_ISH
        return true
        #else
        return false
        #endif
    }
}

extension UIViewController {
    /// Mở màn hình cài lại bộ công cụ Linux (chỉ có khi build nhúng iSH).
    func presentIshSetup() {
        #if CATNIP_HAS_ISH
        let vc = IshSetupViewController()
        vc.modalPresentationStyle = .fullScreen
        vc.onFinish = { [weak vc] in vc?.dismiss(animated: true) }
        present(vc, animated: true)
        #endif
    }

    /// Mở cửa sổ shell: iSH (Linux thật) nếu bản build có nhúng, không thì shell dựng sẵn ở trên.
    func presentShell() {
        #if CATNIP_HAS_ISH
        let vc: UIViewController = IshShellViewController()
        #else
        let vc: UIViewController = ShellViewController()
        #endif
        present(CatnipNavigationController(rootViewController: vc), animated: true)
    }
}
