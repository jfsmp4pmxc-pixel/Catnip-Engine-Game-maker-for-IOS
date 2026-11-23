// NativeTerminal.swift — terminal kiểu iSH (SwiftTerm) cho chương trình chạy native (CPython, C++ CLI).
// Pipe không phải tty nên tự làm "line discipline": gõ tới đâu hiện tới đó, Enter mới gửi cả dòng vào stdin,
// hỗ trợ xoá lùi, Ctrl-D (EOF), Ctrl-C (bỏ dòng đang gõ). Chỉ có khi build với CATNIP_HAS_ISH (cần SwiftTerm).
// Chưa build/kiểm chứng.

#if CATNIP_HAS_ISH

import UIKit
import SwiftTerm

final class NativeTerminalViewController: UIViewController, TerminalViewDelegate {
    typealias Mode = NativeRunMode

    private let project: String
    private let mode: Mode
    private let term = TerminalView(frame: CGRect(x: 0, y: 0, width: 320, height: 480), font: nil)
    private var lineBuffer: [Character] = []
    private var escapeState = 0          // 0 thường, 1 vừa gặp ESC, 2 trong CSI
    private var started = false
    private var finished = false

    init(project: String, mode: Mode) {
        self.project = project
        self.mode = mode
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private var isRunning: Bool { mode.engine.running }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = mode.titlePrefix + project
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneTapped))
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Chạy lại", style: .plain, target: self, action: #selector(rerunTapped))

        term.terminalDelegate = self
        term.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(term)
        NSLayoutConstraint.activate([
            term.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            term.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            term.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            term.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor)
        ])
        NotificationCenter.default.addObserver(self, selector: #selector(applyTheme), name: .catnipSettingsChanged, object: nil)
        applyTheme()
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        _ = term.becomeFirstResponder()
        if !started { started = true; start() }
    }

    @objc private func applyTheme() {
        let t = Appearance.theme
        Appearance.style(navigationController)
        view.backgroundColor = t.bgColor
        term.nativeBackgroundColor = t.bgColor
        term.nativeForegroundColor = t.fgColor
        term.font = Appearance.codeFont(Appearance.terminalFontSize)
    }

    // MARK: Chạy chương trình

    private func start() {
        finished = false
        lineBuffer.removeAll()
        let url = ProjectStore.shared.projectURL(project)
        let onOutput: (String) -> Void = { [weak self] s in DispatchQueue.main.async { self?.write(s) } }
        let onFinish: (Result<Int32, Error>) -> Void = { [weak self] result in
            guard let self = self else { return }
            self.finished = true
            switch result {
            case .success(let code): self.write("\n[Thoát với mã \(code)]\n")
            case .failure(let e): self.write("\n[Lỗi] \(e.localizedDescription)\n")
            }
        }
        mode.engine.run(project: url, onOutput: onOutput, onFinish: onFinish)
    }

    /// Ghi chữ vào terminal; stdout từ pipe chỉ có "\\n" nên đổi thành "\\r\\n".
    private func write(_ s: String) {
        let t = s.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\n", with: "\r\n")
        term.feed(text: t)
    }

    @objc private func rerunTapped() {
        guard !isRunning else { return }
        term.feed(text: "\u{1B}[2J\u{1B}[H")
        start()
    }

    @objc private func doneTapped() {
        _ = term.resignFirstResponder()
        mode.engine.closeInput()
        dismiss(animated: true)
    }

    private func sendToProgram(_ s: String) {
        mode.engine.sendInput(s)
    }

    // MARK: TerminalViewDelegate (nhập từ bàn phím)

    func send(source: TerminalView, data: ArraySlice<UInt8>) {
        guard !finished || isRunning else { return }
        // Lọc phím mũi tên / phím chức năng (ESC [ ... chữ cái) rồi xử lý theo chuỗi UTF-8.
        var clean: [UInt8] = []
        var st = 0
        for b in data {
            if st == 1 { st = (b == UInt8(ascii: "[") || b == UInt8(ascii: "O")) ? 2 : 0; continue }
            if st == 2 { if (0x40...0x7E).contains(b) { st = 0 }; continue }
            if b == 0x1B { st = 1; continue }
            clean.append(b)
        }
        let text = String(decoding: clean, as: UTF8.self)
        for ch in text {
            switch ch {
            case "\r", "\n":
                term.feed(text: "\r\n")
                let line = String(lineBuffer)
                lineBuffer.removeAll()
                sendToProgram(line + "\n")
            case "\u{7F}", "\u{08}":
                if !lineBuffer.isEmpty {
                    lineBuffer.removeLast()
                    term.feed(text: "\u{08} \u{08}")
                }
            case "\u{04}":                          // Ctrl-D
                if lineBuffer.isEmpty { mode.engine.closeInput() }
            case "\u{03}":                          // Ctrl-C
                term.feed(text: "^C\r\n")
                lineBuffer.removeAll()
            default:
                if let v = ch.unicodeScalars.first?.value, v < 0x20 { continue }
                lineBuffer.append(ch)
                term.feed(text: String(ch))
            }
        }
    }

    func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
        TwooEngine.shared.rows = Int32(newRows)
        TwooEngine.shared.cols = Int32(newCols)
    }
    func setTerminalTitle(source: TerminalView, title: String) {}
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
    func scrolled(source: TerminalView, position: Double) {}
    func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}

    func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {
        if let u = URL(string: link) { UIApplication.shared.open(u) }
    }

    func clipboardCopy(source: TerminalView, content: Data) {
        UIPasteboard.general.string = String(decoding: content, as: UTF8.self)
    }
}

#endif
