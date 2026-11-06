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


// Cửa sổ shell Linux thật (iSH) dùng terminal SwiftTerm. Chỉ có khi build với CATNIP_HAS_ISH.
// Hệ thống file Linux nằm trong Documents/iSH (xem được trong app Tệp), và thư mục Documents
// được gắn vào /documents trong Linux, nên sửa dự án bằng công cụ Linux hay trong editor đều như nhau.

#if CATNIP_HAS_ISH

import UIKit
import SwiftTerm

// MARK: - Trạng thái chạy iSH (một lần cho cả app)

final class IshRuntime: NSObject, TerminalViewDelegate {

    enum State {
        case idle
        case installing(fraction: Double, message: String)
        case starting
        case running
        case failed(String)
    }

    static let shared = IshRuntime()

    /// Rootfs Linux nằm ở Documents/iSH.
    static var rootURL: URL { CatnipPaths.projects.appendingPathComponent("iSH", isDirectory: true) }

    private(set) var state: State = .idle {
        didSet { onStateChange?(state) }
    }
    var onStateChange: ((State) -> Void)?

    /// Một TerminalView dùng chung, để đóng/mở cửa sổ shell vẫn giữ nguyên nội dung.
    let terminalView: TerminalView

    private var quickExits = 0
    private var lastStart = Date.distantPast

    private override init() {
        terminalView = TerminalView(frame: CGRect(x: 0, y: 0, width: 320, height: 480), font: nil)
        super.init()
        terminalView.terminalDelegate = self
        applyTheme()
        NotificationCenter.default.addObserver(self, selector: #selector(applyTheme),
                                               name: .catnipSettingsChanged, object: nil)
    }

    @objc func applyTheme() {
        let t = Appearance.theme
        terminalView.nativeBackgroundColor = t.bgColor
        terminalView.nativeForegroundColor = t.fgColor
        terminalView.font = Appearance.codeFont(max(Appearance.fontSize, 11))
    }

    // MARK: Khởi động

    func ensureRunning() {
        switch state {
        case .idle, .failed: break
        default: return
        }
        let root = Self.rootURL
        if IshBridge.isRootInstalled(atPath: root.path) || IshBridge.isBooted {
            boot(root)
            return
        }
        guard let archive = Bundle.main.path(forResource: "root", ofType: "tar.gz") else {
            state = .failed("Thiếu root.tar.gz trong app (build chưa nhúng rootfs).")
            return
        }
        state = .installing(fraction: 0, message: "Đang cài hệ thống Linux (chỉ lần đầu)…")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let error = IshBridge.installRoot(fromArchive: archive, toPath: root.path) { fraction, message in
                DispatchQueue.main.async { self?.state = .installing(fraction: fraction, message: message) }
            }
            DispatchQueue.main.async {
                if let error = error {
                    self?.state = .failed("Không cài được rootfs: \(error)")
                } else {
                    self?.boot(root)
                }
            }
        }
    }

    private func boot(_ root: URL) {
        state = .starting
        let repositories = Bundle.main.path(forResource: "repositories", ofType: "txt")
            .flatMap { try? String(contentsOfFile: $0, encoding: .utf8) }
        if !IshBridge.isBooted {
            let err = IshBridge.boot(root: root.path,
                                     documents: CatnipPaths.projects.path,
                                     repositories: repositories)
            if err < 0 {
                state = .failed("Không khởi động được kernel iSH (mã \(err)).")
                return
            }
        }
        startSession()
    }

    private func startSession() {
        lastStart = Date()
        let err = IshBridge.startSession(output: { [weak self] data in
            self?.terminalView.feed(byteArray: ArraySlice([UInt8](data)))
        }, exit: { [weak self] code in
            self?.sessionEnded(code: Int(code))
        })
        if err < 0 {
            state = .failed("Không mở được phiên shell (mã \(err)).")
            return
        }
        state = .running
        syncSize()
    }

    private func sessionEnded(code: Int) {
        terminalView.feed(text: "\r\n[Phiên shell đã kết thúc (mã \(code)), đang mở lại…]\r\n")
        quickExits = Date().timeIntervalSince(lastStart) < 2 ? quickExits + 1 : 0
        if quickExits >= 3 {
            state = .failed("Shell thoát liên tục ngay sau khi mở. Kiểm tra rootfs trong Documents/iSH.")
            return
        }
        startSession()
    }

    func retry() {
        quickExits = 0
        state = .idle
        ensureRunning()
    }

    private func syncSize() {
        let t = terminalView.getTerminal()
        IshBridge.resize(toColumns: Int32(t.cols), rows: Int32(t.rows))
    }

    // MARK: TerminalViewDelegate

    func send(source: TerminalView, data: ArraySlice<UInt8>) {
        IshBridge.sendInput(Data(data))
    }

    func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
        IshBridge.resize(toColumns: Int32(newCols), rows: Int32(newRows))
    }

    func setTerminalTitle(source: TerminalView, title: String) {}
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
    func scrolled(source: TerminalView, position: Double) {}
    func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}

    func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {
        if let url = URL(string: link), ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
            UIApplication.shared.open(url)
        }
    }

    func clipboardCopy(source: TerminalView, content: Data) {
        if let s = String(data: content, encoding: .utf8) { UIPasteboard.general.string = s }
    }
}

// MARK: - Màn hình

final class IshShellViewController: UIViewController {

    private let runtime = IshRuntime.shared
    private let overlay = UIStackView()
    private let statusLabel = UILabel()
    private let progress = UIProgressView(progressViewStyle: .default)
    private let retryButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Shell"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done, target: self, action: #selector(doneTapped))

        let term = runtime.terminalView
        term.removeFromSuperview()
        term.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(term)

        overlay.axis = .vertical
        overlay.spacing = 14
        overlay.alignment = .fill
        overlay.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.numberOfLines = 0
        statusLabel.textAlignment = .center
        retryButton.setTitle("Thử lại", for: .normal)
        retryButton.addAction(UIAction { [weak self] _ in self?.runtime.retry() }, for: .touchUpInside)
        overlay.addArrangedSubview(statusLabel)
        overlay.addArrangedSubview(progress)
        overlay.addArrangedSubview(retryButton)
        view.addSubview(overlay)

        NSLayoutConstraint.activate([
            term.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            term.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            term.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            term.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),

            overlay.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
        ])

        runtime.onStateChange = { [weak self] _ in self?.render() }
        NotificationCenter.default.addObserver(self, selector: #selector(applyTheme),
                                               name: .catnipSettingsChanged, object: nil)
        applyTheme()
        runtime.ensureRunning()
        render()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        if runtime.onStateChange != nil { runtime.onStateChange = nil }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if case .running = runtime.state { _ = runtime.terminalView.becomeFirstResponder() }
    }

    @objc private func applyTheme() {
        let t = Appearance.theme
        Appearance.style(navigationController)
        view.backgroundColor = t.bgColor
        statusLabel.textColor = t.fgColor
        statusLabel.font = .systemFont(ofSize: 15)
        progress.tintColor = t.accentColor
    }

    private func render() {
        var showOverlay = true
        var showProgress = false
        var showRetry = false
        switch runtime.state {
        case .idle:
            statusLabel.text = "Đang chuẩn bị…"
        case .installing(let fraction, let message):
            statusLabel.text = message
            progress.progress = Float(fraction)
            showProgress = true
        case .starting:
            statusLabel.text = "Đang khởi động Linux…"
        case .running:
            showOverlay = false
            _ = runtime.terminalView.becomeFirstResponder()
        case .failed(let message):
            statusLabel.text = message
            showRetry = true
        }
        overlay.isHidden = !showOverlay
        progress.isHidden = !showProgress
        retryButton.isHidden = !showRetry
    }

    @objc private func doneTapped() {
        _ = runtime.terminalView.resignFirstResponder()
        dismiss(animated: true)
    }
}

#endif
