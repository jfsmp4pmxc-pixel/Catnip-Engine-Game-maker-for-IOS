// CppConsole.swift
// Console tương tác cho dự án C++ (stdout/stderr hiện ra, ô nhập gửi vào stdin) và màn hình setup Clang++.
// Chưa build/kiểm chứng.

import UIKit

// MARK: - Console

final class CppConsoleViewController: UIViewController, UITextFieldDelegate {
    private let project: String
    private let output = UITextView()
    private let input = UITextField()
    private let bar = UIView()
    private let status = UILabel()
    private var finished = false
    private var escapes = try? NSRegularExpression(pattern: "\u{1B}\\[[0-9;?]*[A-Za-z]")
    private var history: [String] = []
    private var historyIndex: Int?
    private var barBottom: NSLayoutConstraint!

    init(project: String) {
        self.project = project
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "C++ · \(project)"
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Đóng", style: .done, target: self, action: #selector(closeTapped))
        navigationItem.leftBarButtonItems = [
            UIBarButtonItem(title: "Gửi EOF", style: .plain, target: self, action: #selector(eofTapped)),
            UIBarButtonItem(image: UIImage(systemName: "doc.on.doc"), style: .plain, target: self, action: #selector(copyTapped)),
        ]
        output.isEditable = false
        output.font = Appearance.codeFont(Appearance.terminalFontSize)
        output.alwaysBounceVertical = true
        output.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(output)

        bar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bar)
        status.font = .systemFont(ofSize: 12)
        status.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(status)
        input.borderStyle = .roundedRect
        input.autocapitalizationType = .none
        input.autocorrectionType = .no
        input.returnKeyType = .send
        input.placeholder = "Nhập cho chương trình (stdin) rồi Enter"
        input.delegate = self
        input.font = Appearance.codeFont(Appearance.terminalFontSize)
        input.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(input)

        barBottom = bar.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor)
        NSLayoutConstraint.activate([
            output.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            output.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            output.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            output.bottomAnchor.constraint(equalTo: bar.topAnchor),
            bar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            barBottom,
            status.topAnchor.constraint(equalTo: bar.topAnchor, constant: 6),
            status.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 12),
            status.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -12),
            input.topAnchor.constraint(equalTo: status.bottomAnchor, constant: 6),
            input.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 10),
            input.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -10),
            input.bottomAnchor.constraint(equalTo: bar.bottomAnchor, constant: -8),
            input.heightAnchor.constraint(equalToConstant: 38),
        ])
        applyTheme()
        status.text = "Đang biên dịch (Clang++ JIT)…"
        start()
    }

    private func applyTheme() {
        let t = Appearance.theme
        Appearance.style(navigationController)
        view.backgroundColor = t.bgColor
        output.backgroundColor = t.bgColor
        output.textColor = t.fgColor
        bar.backgroundColor = t.bg2Color
        status.textColor = t.mutedColor
        input.backgroundColor = t.bg3Color
        input.textColor = t.fgColor
        input.keyboardAppearance = t.isDark ? .dark : .light
    }

    private func start() {
        let url = ProjectStore.shared.projectURL(project)
        CppEngine.shared.run(project: url, onOutput: { [weak self] s in
            DispatchQueue.main.async { self?.append(s) }
        }, onFinish: { [weak self] result in
            guard let self = self else { return }
            self.finished = true
            self.input.isEnabled = false
            switch result {
            case .success(let code):
                self.status.text = "■ Chương trình thoát với mã \(code)"
                self.append("\n[Thoát với mã \(code)]\n")
            case .failure(let e):
                self.status.text = "■ Không chạy được"
                self.append("\n[Lỗi] \(e.localizedDescription)\n")
            }
        })
        if CppEngine.shared.running { status.text = "▶︎ Đang chạy" }
        input.becomeFirstResponder()
    }

    private func append(_ raw: String) {
        var s = raw.replacingOccurrences(of: "\r\n", with: "\n")
        if let re = escapes { s = re.stringByReplacingMatches(in: s, range: NSRange(location: 0, length: (s as NSString).length), withTemplate: "") }
        let attr = NSAttributedString(string: s, attributes: [.font: output.font ?? Appearance.codeFont(), .foregroundColor: Appearance.theme.fgColor])
        output.textStorage.append(attr)
        if output.textStorage.length > 400_000 { output.textStorage.deleteCharacters(in: NSRange(location: 0, length: 100_000)) }
        output.scrollRangeToVisible(NSRange(location: output.textStorage.length, length: 0))
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        let line = textField.text ?? ""
        textField.text = ""
        if !line.isEmpty { history.append(line) }
        append(line + "\n")             // echo (pipe không có tty nên không tự hiện)
        CppEngine.shared.sendInput(line + "\n")
        return false
    }

    @objc private func eofTapped() { CppEngine.shared.closeInput() }
    @objc private func copyTapped() { UIPasteboard.general.string = output.text }
    @objc private func closeTapped() {
        CppEngine.shared.closeInput()
        dismiss(animated: true)
    }
}

// MARK: - Setup Clang++

final class ClangSetupViewController: UIViewController {
    var onFinish: (() -> Void)?

    private let stack = UIStackView()
    private let icon = UIImageView(image: UIImage(systemName: "hammer"))
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let progress = UIProgressView(progressViewStyle: .default)
    private let statusLabel = UILabel()
    private let startButton = UIButton(type: .system)
    private let skipButton = UIButton(type: .system)
    private var busy = false

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { OrientationPolicy.mask }

    override func viewDidLoad() {
        super.viewDidLoad()
        icon.contentMode = .scaleAspectFit
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 44, weight: .light)
        titleLabel.text = ClangToolchain.isInstalled ? "Clang++ đã cài" : "Cài Clang++ cho dự án C++"
        titleLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        detailLabel.text = "Trình biên dịch Clang++ (chạy ngay trong app, không qua shell) và header C++/SDL được tải về một lần để bản cài của Catnip nhẹ. "
            + "Cần mạng và vài trăm MB trống. Chạy mã cần app có quyền JIT. Bạn có thể bỏ qua và cài sau ở Cài đặt → Công cụ."
        detailLabel.font = .systemFont(ofSize: 14)
        detailLabel.textAlignment = .center
        detailLabel.numberOfLines = 0
        statusLabel.font = .systemFont(ofSize: 15)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        progress.isHidden = true
        startButton.setTitle(ClangToolchain.isInstalled ? "Cài lại" : "Tải và cài", for: .normal)
        startButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        startButton.addAction(UIAction { [weak self] _ in self?.start() }, for: .touchUpInside)
        skipButton.setTitle(ClangToolchain.isInstalled ? "Xong" : "Bỏ qua", for: .normal)
        skipButton.addAction(UIAction { [weak self] _ in self?.finish() }, for: .touchUpInside)

        stack.axis = .vertical
        stack.spacing = 14
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        [icon, titleLabel, detailLabel, progress, statusLabel, startButton, skipButton].forEach { stack.addArrangedSubview($0) }
        stack.setCustomSpacing(24, after: detailLabel)
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -32),
            stack.widthAnchor.constraint(lessThanOrEqualToConstant: 520),
        ])
        let t = Appearance.theme
        view.backgroundColor = t.bgColor
        icon.tintColor = t.accentColor
        titleLabel.textColor = t.fgColor
        detailLabel.textColor = t.mutedColor
        statusLabel.textColor = t.fgColor
        progress.tintColor = t.accentColor
        startButton.tintColor = t.accentColor
        skipButton.tintColor = t.mutedColor
    }

    private func start() {
        guard !busy else { return }
        busy = true
        UIApplication.shared.isIdleTimerDisabled = true
        progress.isHidden = false
        progress.progress = 0
        startButton.isHidden = true
        statusLabel.text = "Đang chuẩn bị…"
        ClangToolchain.install(progress: { [weak self] f, m in
            self?.progress.setProgress(Float(f), animated: true)
            self?.statusLabel.text = m
        }, completion: { [weak self] result in
            guard let self = self else { return }
            self.busy = false
            UIApplication.shared.isIdleTimerDisabled = false
            switch result {
            case .success:
                self.progress.setProgress(1, animated: true)
                self.statusLabel.text = "Xong! Clang++ đã sẵn sàng."
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.finish() }
            case .failure(let e):
                self.statusLabel.text = e.localizedDescription
                self.startButton.setTitle("Thử lại", for: .normal)
                self.startButton.isHidden = false
            }
        })
    }

    private func finish() {
        if busy { ClangToolchain.cancelInstall(); busy = false }
        UIApplication.shared.isIdleTimerDisabled = false
        SettingsStore.shared.update { $0.clangSetupDone = true }
        SettingsStore.shared.saveNow()
        onFinish?()
    }
}
