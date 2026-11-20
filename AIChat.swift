import UIKit

// Chat AI: kết nối Claude (Anthropic) và DeepSeek bằng API key, lưu đoạn chat, mở lại, xuất/nhập, khối mã có nút sao chép.
// Chưa build/kiểm chứng.

// MARK: - Nhà cung cấp

enum AIProvider: String, Codable, CaseIterable {
    case claude, deepseek

    var displayName: String { self == .claude ? "Claude" : "DeepSeek" }
    var models: [String] {
        switch self {
        case .claude:   return ["claude-sonnet-5-5", "claude-opus-5-5", "claude-haiku-5-5"]
        case .deepseek: return ["deepseek-chat", "deepseek-reasoner"]
        }
    }
    var keyHelp: String {
        self == .claude ? "API key lấy ở console.anthropic.com (bắt đầu bằng sk-ant-)." : "API key lấy ở platform.deepseek.com."
    }
}

enum AIKeyStore {
    private static func file(_ p: AIProvider) -> URL { CatnipPaths.root.appendingPathComponent("ai-key-\(p.rawValue)") }
    private static func query(_ p: AIProvider) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "com.catnip.ai",
         kSecAttrAccount as String: p.rawValue]
    }
    static func load(_ p: AIProvider) -> String? {
        var q = query(p)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        if SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
           let d = out as? Data, let s = String(data: d, encoding: .utf8), !s.isEmpty { return s }
        if let d = try? Data(contentsOf: file(p)), let s = String(data: d, encoding: .utf8), !s.isEmpty { return s }
        return nil
    }
    static func save(_ key: String, for p: AIProvider) {
        delete(p)
        var q = query(p)
        q[kSecValueData as String] = Data(key.utf8)
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        if SecItemAdd(q as CFDictionary, nil) != errSecSuccess {
            try? FileManager.default.createDirectory(at: CatnipPaths.root, withIntermediateDirectories: true)
            try? Data(key.utf8).write(to: file(p), options: [.atomic, .completeFileProtection])
        }
    }
    static func delete(_ p: AIProvider) {
        SecItemDelete(query(p) as CFDictionary)
        try? FileManager.default.removeItem(at: file(p))
    }
}

// MARK: - Dữ liệu chat

struct ChatMessage: Codable {
    var role: String      // "user" | "assistant"
    var text: String
}

struct ChatConversation: Codable {
    var id: String = UUID().uuidString
    var title: String = "Chat mới"
    var provider: AIProvider = .claude
    var model: String = "claude-sonnet-5-5"
    var messages: [ChatMessage] = []
    var updated: Date = Date()

    /// Xuất ra Markdown (khối mã giữ nguyên).
    func markdown() -> String {
        var s = "# \(title)\n\n_\(provider.displayName) · \(model)_\n\n"
        for m in messages {
            s += (m.role == "user" ? "## Bạn\n\n" : "## \(provider.displayName)\n\n") + m.text + "\n\n"
        }
        return s
    }
}

final class ChatStore {
    static let shared = ChatStore()
    private let fm = FileManager.default
    var dir: URL { CatnipPaths.root.appendingPathComponent("Chats", isDirectory: true) }

    func list() -> [ChatConversation] {
        let files = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return files.filter { $0.pathExtension == "json" }
            .compactMap { try? dec.decode(ChatConversation.self, from: Data(contentsOf: $0)) }
            .sorted { $0.updated > $1.updated }
    }

    func save(_ c: ChatConversation) {
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        if let d = try? enc.encode(c) {
            try? d.write(to: dir.appendingPathComponent("\(c.id).json"), options: .atomic)
        }
    }

    func delete(_ c: ChatConversation) {
        try? fm.removeItem(at: dir.appendingPathComponent("\(c.id).json"))
    }

    /// Nhập file .json (xuất từ Catnip). Trả về nil nếu không đọc được.
    func importFile(_ url: URL) -> ChatConversation? {
        guard let d = try? Data(contentsOf: url) else { return nil }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        guard var c = try? dec.decode(ChatConversation.self, from: d) else { return nil }
        c.id = UUID().uuidString
        save(c)
        return c
    }

    func exportFiles(_ c: ChatConversation) -> [URL] {
        let base = fm.temporaryDirectory
        let safe = c.title.replacingOccurrences(of: "/", with: "-").prefix(40)
        let md = base.appendingPathComponent("\(safe).md")
        let js = base.appendingPathComponent("\(safe).json")
        try? c.markdown().write(to: md, atomically: true, encoding: .utf8)
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted]
        if let d = try? enc.encode(c) { try? d.write(to: js, options: .atomic) }
        return [md, js]
    }
}

// MARK: - Gọi API

struct AIError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

enum AIClient {
    static func send(_ conv: ChatConversation, system: String?) async throws -> String {
        guard let key = AIKeyStore.load(conv.provider) else {
            throw AIError(message: "Chưa nhập API key cho \(conv.provider.displayName).")
        }
        var req: URLRequest
        let msgs = conv.messages.map { ["role": $0.role, "content": $0.text] }
        var body: [String: Any]
        switch conv.provider {
        case .claude:
            req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
            req.setValue(key, forHTTPHeaderField: "x-api-key")
            req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            body = ["model": conv.model, "max_tokens": 8192, "messages": msgs]
            if let s = system, !s.isEmpty { body["system"] = s }
        case .deepseek:
            req = URLRequest(url: URL(string: "https://api.deepseek.com/chat/completions")!)
            req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            var all = msgs
            if let s = system, !s.isEmpty { all.insert(["role": "system", "content": s], at: 0) }
            body = ["model": conv.model, "messages": all, "stream": false]
        }
        req.httpMethod = "POST"
        req.timeoutInterval = 180
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        guard (200..<300).contains(code) else {
            var msg = "Lỗi HTTP \(code)"
            if let e = json?["error"] as? [String: Any], let m = e["message"] as? String { msg += ": " + m }
            throw AIError(message: msg)
        }
        switch conv.provider {
        case .claude:
            let parts = (json?["content"] as? [[String: Any]]) ?? []
            let text = parts.compactMap { $0["text"] as? String }.joined()
            if text.isEmpty { throw AIError(message: "Phản hồi trống.") }
            return text
        case .deepseek:
            let choices = (json?["choices"] as? [[String: Any]]) ?? []
            let m = choices.first?["message"] as? [String: Any]
            guard let text = m?["content"] as? String, !text.isEmpty else { throw AIError(message: "Phản hồi trống.") }
            return text
        }
    }
}

// MARK: - Tách khối mã

enum ChatSegment {
    case text(String)
    case code(lang: String, body: String)

    static func parse(_ s: String) -> [ChatSegment] {
        var out: [ChatSegment] = []
        var buf: [String] = []
        var inCode = false
        var lang = ""
        func flushText() {
            let t = buf.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { out.append(.text(t)) }
            buf = []
        }
        for line in s.components(separatedBy: "\n") {
            let tl = line.trimmingCharacters(in: .whitespaces)
            if tl.hasPrefix("```") {
                if inCode {
                    out.append(.code(lang: lang, body: buf.joined(separator: "\n")))
                    buf = []; inCode = false
                } else {
                    flushText()
                    lang = String(tl.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    inCode = true
                }
            } else {
                buf.append(line)
            }
        }
        if inCode { out.append(.code(lang: lang, body: buf.joined(separator: "\n"))) } else { flushText() }
        return out
    }

    static func language(for tag: String) -> Language {
        let map = ["python": "py", "javascript": "js", "typescript": "ts", "lua": "lua", "swift": "swift", "bash": "sh",
                   "shell": "sh", "c++": "cpp", "csharp": "cs", "rust": "rs", "golang": "go", "markdown": "md",
                   "yaml": "yml", "ruby": "rb", "kotlin": "kt"]
        let t = tag.lowercased()
        return Language.detect("x." + (map[t] ?? t))
    }
}

// MARK: - Ô tin nhắn

final class ChatCell: UITableViewCell {
    private let stack = UIStackView()
    private let bubble = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        bubble.layer.cornerRadius = 12
        bubble.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bubble)
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        bubble.addSubview(stack)
        NSLayoutConstraint.activate([
            bubble.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            bubble.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            bubble.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            bubble.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            stack.topAnchor.constraint(equalTo: bubble.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: bubble.bottomAnchor, constant: -10),
            stack.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -10),
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    var onCopy: ((String) -> Void)?
    var onLongPressText: ((String) -> Void)?

    func configure(_ m: ChatMessage, providerName: String) {
        let t = Appearance.theme
        bubble.backgroundColor = m.role == "user" ? t.bg3Color : t.bg2Color
        for v in stack.arrangedSubviews { stack.removeArrangedSubview(v); v.removeFromSuperview() }
        let who = UILabel()
        who.font = .systemFont(ofSize: 12, weight: .semibold)
        who.textColor = t.mutedColor
        who.text = m.role == "user" ? "Bạn" : providerName
        stack.addArrangedSubview(who)
        for seg in ChatSegment.parse(m.text) {
            switch seg {
            case .text(let s):
                let l = UILabel()
                l.numberOfLines = 0
                l.font = .systemFont(ofSize: 15)
                l.textColor = t.fgColor
                l.text = s
                stack.addArrangedSubview(l)
            case .code(let lang, let body):
                stack.addArrangedSubview(makeCodeBlock(lang: lang, body: body))
            }
        }
        // Sao chép cả tin nhắn bằng nhấn giữ
        bubble.gestureRecognizers?.forEach { bubble.removeGestureRecognizer($0) }
        let lp = UILongPressGestureRecognizer(target: self, action: #selector(longPressed(_:)))
        bubble.addGestureRecognizer(lp)
        currentText = m.text
    }

    private var currentText = ""
    @objc private func longPressed(_ g: UILongPressGestureRecognizer) {
        if g.state == .began { onLongPressText?(currentText) }
    }

    private func makeCodeBlock(lang: String, body: String) -> UIView {
        let t = Appearance.theme
        let box = UIView()
        box.backgroundColor = t.bgColor
        box.layer.cornerRadius = 8
        box.layer.borderWidth = 1
        box.layer.borderColor = t.borderColor.cgColor
        box.clipsToBounds = true

        let head = UIView()
        head.backgroundColor = t.bg3Color
        head.translatesAutoresizingMaskIntoConstraints = false
        let name = UILabel()
        name.font = .systemFont(ofSize: 12, weight: .medium)
        name.textColor = t.mutedColor
        name.text = lang.isEmpty ? "mã" : lang
        name.translatesAutoresizingMaskIntoConstraints = false
        let copy = UIButton(type: .system)
        copy.setTitle("Sao chép", for: .normal)
        copy.setImage(UIImage(systemName: "doc.on.doc"), for: .normal)
        copy.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
        copy.tintColor = t.accentColor
        copy.translatesAutoresizingMaskIntoConstraints = false
        copy.addAction(UIAction { [weak self, weak copy] _ in
            UIPasteboard.general.string = body
            copy?.setTitle("Đã chép", for: .normal)
            self?.onCopy?(body)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copy?.setTitle("Sao chép", for: .normal) }
        }, for: .touchUpInside)
        head.addSubview(name)
        head.addSubview(copy)

        let label = UILabel()
        label.numberOfLines = 0
        label.lineBreakMode = .byCharWrapping
        let font = Appearance.codeFont(13)
        label.attributedText = SyntaxHighlighter.highlight(body, language: ChatSegment.language(for: lang), theme: t, font: font)
        label.translatesAutoresizingMaskIntoConstraints = false

        box.addSubview(head)
        box.addSubview(label)
        NSLayoutConstraint.activate([
            head.topAnchor.constraint(equalTo: box.topAnchor),
            head.leadingAnchor.constraint(equalTo: box.leadingAnchor),
            head.trailingAnchor.constraint(equalTo: box.trailingAnchor),
            head.heightAnchor.constraint(equalToConstant: 32),
            name.leadingAnchor.constraint(equalTo: head.leadingAnchor, constant: 10),
            name.centerYAnchor.constraint(equalTo: head.centerYAnchor),
            copy.trailingAnchor.constraint(equalTo: head.trailingAnchor, constant: -8),
            copy.centerYAnchor.constraint(equalTo: head.centerYAnchor),
            label.topAnchor.constraint(equalTo: head.bottomAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -8),
            label.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -10),
        ])
        return box
    }
}

// MARK: - Màn hình chat

final class AIChatViewController: UIViewController, UITableViewDataSource, UITextViewDelegate {
    private(set) var conv: ChatConversation
    private let table = UITableView(frame: .zero, style: .plain)
    private let input = UITextView()
    private let sendButton = UIButton(type: .system)
    private let bar = UIView()
    private var barBottom: NSLayoutConstraint!
    private var inputHeight: NSLayoutConstraint!
    private var busy = false
    /// Trả về (tên file, nội dung) của file đang mở trong editor, để đính kèm khi người dùng muốn.
    var currentFile: (() -> (name: String, text: String)?)?
    var onChange: (() -> Void)?

    init(conversation: ChatConversation) {
        self.conv = conversation
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = conv.title
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), menu: makeMenu()),
        ]
        table.dataSource = self
        table.register(ChatCell.self, forCellReuseIdentifier: "m")
        table.separatorStyle = .none
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 80
        table.keyboardDismissMode = .interactive
        table.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(table)

        bar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bar)
        input.font = .systemFont(ofSize: 16)
        input.layer.cornerRadius = 10
        input.textContainerInset = UIEdgeInsets(top: 8, left: 6, bottom: 8, right: 6)
        input.delegate = self
        input.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(input)
        sendButton.setImage(UIImage(systemName: "arrow.up.circle.fill",
                                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 30)), for: .normal)
        sendButton.addAction(UIAction { [weak self] _ in self?.sendTapped() }, for: .touchUpInside)
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(sendButton)

        barBottom = bar.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor)
        inputHeight = input.heightAnchor.constraint(equalToConstant: 40)
        NSLayoutConstraint.activate([
            table.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            table.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            table.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            table.bottomAnchor.constraint(equalTo: bar.topAnchor),
            bar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            barBottom,
            input.topAnchor.constraint(equalTo: bar.topAnchor, constant: 8),
            input.bottomAnchor.constraint(equalTo: bar.bottomAnchor, constant: -8),
            input.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 10),
            input.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -6),
            inputHeight,
            sendButton.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -8),
            sendButton.bottomAnchor.constraint(equalTo: bar.bottomAnchor, constant: -10),
            sendButton.widthAnchor.constraint(equalToConstant: 36),
        ])
        applyTheme()
        scrollToEnd()
    }

    private func applyTheme() {
        let t = Appearance.theme
        Appearance.style(navigationController)
        view.backgroundColor = t.bgColor
        table.backgroundColor = t.bgColor
        bar.backgroundColor = t.bg2Color
        input.backgroundColor = t.bg3Color
        input.textColor = t.fgColor
        input.keyboardAppearance = t.isDark ? .dark : .light
        sendButton.tintColor = t.accentColor
    }

    private func makeMenu() -> UIMenu {
        var items: [UIMenuElement] = []
        let providers = AIProvider.allCases.map { p in
            UIAction(title: p.displayName, state: conv.provider == p ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.conv.provider = p
                if !p.models.contains(self.conv.model) { self.conv.model = p.models[0] }
                self.persist()
                self.navigationItem.rightBarButtonItems = [UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), menu: self.makeMenu())]
            }
        }
        items.append(UIMenu(title: "Nhà cung cấp: \(conv.provider.displayName)", image: UIImage(systemName: "cpu"), children: providers))
        let models = conv.provider.models.map { m in
            UIAction(title: m, state: conv.model == m ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.conv.model = m
                self.persist()
                self.navigationItem.rightBarButtonItems = [UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), menu: self.makeMenu())]
            }
        }
        items.append(UIMenu(title: "Mô hình: \(conv.model)", image: UIImage(systemName: "sparkles"), children: models))
        if currentFile?() != nil {
            items.append(UIAction(title: "Đính kèm file đang mở", image: UIImage(systemName: "paperclip")) { [weak self] _ in
                self?.attachCurrentFile()
            })
        }
        items.append(UIAction(title: "Xuất đoạn chat (.md + .json)", image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
            guard let self = self else { return }
            let vc = UIActivityViewController(activityItems: ChatStore.shared.exportFiles(self.conv), applicationActivities: nil)
            vc.popoverPresentationController?.barButtonItem = self.navigationItem.rightBarButtonItems?.first
            self.present(vc, animated: true)
        })
        items.append(UIAction(title: "Sao chép toàn bộ (Markdown)", image: UIImage(systemName: "doc.on.doc")) { [weak self] _ in
            UIPasteboard.general.string = self?.conv.markdown()
        })
        items.append(UIAction(title: "Xoá nội dung chat", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
            guard let self = self else { return }
            self.conv.messages = []
            self.persist()
            self.table.reloadData()
        })
        return UIMenu(children: items)
    }

    private func attachCurrentFile() {
        guard let f = currentFile?() else { return }
        let ext = (f.name as NSString).pathExtension
        let snippet = "File `\(f.name)`:\n```\(ext)\n\(f.text)\n```\n"
        input.text = (input.text ?? "") + (input.text.isEmpty ? "" : "\n") + snippet
        textViewDidChange(input)
        input.becomeFirstResponder()
    }

    private func persist() {
        conv.updated = Date()
        if conv.title == "Chat mới", let first = conv.messages.first(where: { $0.role == "user" }) {
            conv.title = String(first.text.prefix(40)).replacingOccurrences(of: "\n", with: " ")
            title = conv.title
        }
        ChatStore.shared.save(conv)
        onChange?()
    }

    private func scrollToEnd() {
        guard !conv.messages.isEmpty else { return }
        table.layoutIfNeeded()
        table.scrollToRow(at: IndexPath(row: conv.messages.count - 1, section: 0), at: .bottom, animated: false)
    }

    func textViewDidChange(_ textView: UITextView) {
        let h = min(max(textView.contentSize.height, 40), 140)
        if abs(inputHeight.constant - h) > 1 { inputHeight.constant = h }
    }

    private func sendTapped() {
        guard !busy else { return }
        let text = (input.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        input.text = ""
        textViewDidChange(input)
        conv.messages.append(ChatMessage(role: "user", text: text))
        persist()
        table.reloadData()
        scrollToEnd()
        busy = true
        sendButton.isEnabled = false
        navigationItem.prompt = "\(conv.provider.displayName) đang trả lời…"
        let snapshot = conv
        Task { [weak self] in
            do {
                let reply = try await AIClient.send(snapshot, system: nil)
                await MainActor.run {
                    guard let self = self else { return }
                    self.conv.messages.append(ChatMessage(role: "assistant", text: reply))
                    self.finishSend()
                }
            } catch {
                await MainActor.run {
                    guard let self = self else { return }
                    self.finishSend()
                    let a = UIAlertController(title: "Không gửi được", message: error.localizedDescription, preferredStyle: .alert)
                    a.addAction(UIAlertAction(title: "Đóng", style: .cancel))
                    self.present(a, animated: true)
                }
            }
        }
    }

    private func finishSend() {
        busy = false
        sendButton.isEnabled = true
        navigationItem.prompt = nil
        persist()
        table.reloadData()
        scrollToEnd()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { conv.messages.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "m", for: indexPath) as! ChatCell
        let m = conv.messages[indexPath.row]
        cell.configure(m, providerName: conv.provider.displayName)
        cell.onLongPressText = { [weak self] text in
            UIPasteboard.general.string = text
            let a = UIAlertController(title: nil, message: "Đã sao chép tin nhắn", preferredStyle: .alert)
            self?.present(a, animated: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { a.dismiss(animated: true) }
        }
        return cell
    }
}

// MARK: - Danh sách chat + tài khoản

final class AIChatListViewController: UITableViewController, UIDocumentPickerDelegate {
    private var chats: [ChatConversation] = []
    var currentFile: (() -> (name: String, text: String)?)?

    init() { super.init(style: .insetGrouped) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Chat AI"
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneTapped))
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .compose, target: self, action: #selector(newChat)),
            UIBarButtonItem(image: UIImage(systemName: "person.crop.circle"), style: .plain, target: self, action: #selector(accountsTapped)),
            UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.down"), style: .plain, target: self, action: #selector(importTapped)),
        ]
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "c")
        Appearance.style(navigationController)
        tableView.backgroundColor = Appearance.theme.bgColor
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        chats = ChatStore.shared.list()
        tableView.reloadData()
    }

    @objc private func doneTapped() { dismiss(animated: true) }

    @objc private func newChat() {
        let configured = AIProvider.allCases.first { AIKeyStore.load($0) != nil }
        guard let p = configured else {
            accountsTapped()
            return
        }
        var c = ChatConversation()
        c.provider = p
        c.model = p.models[0]
        open(c)
    }

    private func open(_ c: ChatConversation) {
        let vc = AIChatViewController(conversation: c)
        vc.currentFile = currentFile
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func accountsTapped() {
        let sheet = UIAlertController(title: "Tài khoản AI", message: "Nhập API key của từng nhà cung cấp. Key lưu trong Keychain của máy.", preferredStyle: .actionSheet)
        for p in AIProvider.allCases {
            let on = AIKeyStore.load(p) != nil
            sheet.addAction(UIAlertAction(title: "\(p.displayName) — \(on ? "đã kết nối" : "chưa kết nối")", style: .default) { [weak self] _ in
                self?.editKey(p)
            })
        }
        sheet.addAction(UIAlertAction(title: "Đóng", style: .cancel))
        sheet.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItems?[1]
        present(sheet, animated: true)
    }

    private func editKey(_ p: AIProvider) {
        let a = UIAlertController(title: "\(p.displayName) API key", message: p.keyHelp, preferredStyle: .alert)
        a.addTextField { tf in
            tf.placeholder = "API key"
            tf.isSecureTextEntry = true
            tf.autocapitalizationType = .none
            tf.autocorrectionType = .no
        }
        a.addAction(UIAlertAction(title: "Lưu", style: .default) { [weak a] _ in
            let k = (a?.textFields?.first?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !k.isEmpty { AIKeyStore.save(k, for: p) }
        })
        if AIKeyStore.load(p) != nil {
            a.addAction(UIAlertAction(title: "Ngắt kết nối", style: .destructive) { _ in AIKeyStore.delete(p) })
        }
        a.addAction(UIAlertAction(title: "Huỷ", style: .cancel))
        present(a, animated: true)
    }

    @objc private func importTapped() {
        let pick = UIDocumentPickerViewController(forOpeningContentTypes: [.json], asCopy: true)
        pick.delegate = self
        present(pick, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        var n = 0
        for u in urls where ChatStore.shared.importFile(u) != nil { n += 1 }
        chats = ChatStore.shared.list()
        tableView.reloadData()
        let a = UIAlertController(title: nil, message: n > 0 ? "Đã nhập \(n) đoạn chat." : "Không đọc được file (cần file .json xuất từ Catnip).", preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { chats.count }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        chats.isEmpty ? "Chưa có đoạn chat. Bấm ✎ để tạo; bấm biểu tượng người để kết nối Claude / DeepSeek." : nil
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "c", for: indexPath)
        let c = chats[indexPath.row]
        let t = Appearance.theme
        var cfg = UIListContentConfiguration.subtitleCell()
        cfg.text = c.title
        cfg.secondaryText = "\(c.provider.displayName) · \(c.model) · \(c.messages.count) tin"
        cfg.textProperties.color = t.fgColor
        cfg.secondaryTextProperties.color = t.mutedColor
        cell.contentConfiguration = cfg
        cell.backgroundColor = t.bg2Color
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        open(chats[indexPath.row])
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let c = chats[indexPath.row]
        let del = UIContextualAction(style: .destructive, title: "Xoá") { [weak self] _, _, done in
            ChatStore.shared.delete(c)
            self?.chats.remove(at: indexPath.row)
            self?.tableView.deleteRows(at: [indexPath], with: .automatic)
            done(true)
        }
        let share = UIContextualAction(style: .normal, title: "Xuất") { [weak self] _, _, done in
            let vc = UIActivityViewController(activityItems: ChatStore.shared.exportFiles(c), applicationActivities: nil)
            vc.popoverPresentationController?.sourceView = self?.tableView.cellForRow(at: indexPath)
            self?.present(vc, animated: true)
            done(true)
        }
        return UISwipeActionsConfiguration(actions: [del, share])
    }
}

extension EditorViewController {
    func presentAIChat() {
        textView.resignFirstResponder()
        let list = AIChatListViewController()
        list.currentFile = { [weak self] in
            guard let self = self, let p = self.currentPath else { return nil }
            return ((p as NSString).lastPathComponent, self.textView.text ?? "")
        }
        topPresenter.present(CatnipNavigationController(rootViewController: list), animated: true)
    }
}
