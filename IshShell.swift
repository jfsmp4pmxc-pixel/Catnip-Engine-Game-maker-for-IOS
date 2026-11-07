// Cửa sổ shell Linux thật (iSH) dùng terminal SwiftTerm. Chỉ có khi build với CATNIP_HAS_ISH.
//
// "True Workspaces": hệ thống file Linux nằm trong Documents/iSH (xem được trong app Tệp) và mỗi dự án
// của Catnip được gắn thành một thư mục dưới /root (/root/<tên dự án>, khoảng trắng đổi thành "_").
// Mở một dự án trong editor thì iSH chạy ngầm và shell tự `cd` vào thư mục của dự án đó.
// Lần chạy đầu app cài sẵn bash, vim, python3, g++, nasm (có thể bỏ qua) rồi mới vào màn hình chính.

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

    enum SetupResult {
        case success
        case failed(String)
        case skipped
    }

    static let shared = IshRuntime()

    /// Gói cài sẵn ở lần chạy đầu.
    static let defaultPackages = ["bash", "vim", "python3", "g++", "nasm"]

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

    /// Dự án đang mở trong editor (shell sẽ vào thư mục của nó) và dự án mà phiên hiện tại đã vào.
    private var desiredProject: String?
    private var sessionProject: String?
    private var switchingProject = false

    // Chuẩn bị hệ thống (cài rootfs + boot) dùng chung giữa cài đặt lần đầu và shell.
    private var preparing = false
    private var prepareWaiters: [(String?) -> Void] = []
    private var progressSink: ((Double, String) -> Void)?

    // Cài gói lần đầu.
    private var setupInProgress = false
    private var setupCancelled = false
    private var shellWanted = false     // có nơi cần shell trong lúc đang cài gói
    private var suspendingShell = false // đang đóng shell để nhường chỗ cho tiến trình cài đặt
    private var pendingSetupStart: (() -> Void)?

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
        terminalView.font = Appearance.codeFont(Appearance.terminalFontSize)
    }

    // MARK: Dự án <-> thư mục trong Linux

    /// Tên thư mục trong Linux của từng dự án: khoảng trắng đổi thành "_"; trùng tên thì thêm _2, _3…
    static func guestNames(for projects: [String]) -> [String: String] {
        var result: [String: String] = [:]
        var taken = Set<String>()
        for project in projects {
            var base = String(project.map { $0.isWhitespace ? "_" : $0 })
            if base.isEmpty { base = "_" }
            var name = base
            var n = 2
            while taken.contains(name) { name = "\(base)_\(n)"; n += 1 }
            taken.insert(name)
            result[project] = name
        }
        return result
    }

    /// Tên trong Linux → đường dẫn thật trên iOS, cho mọi dự án hiện có.
    static func projectMounts() -> [String: String] {
        let store = ProjectStore.shared
        var mounts: [String: String] = [:]
        for (project, guest) in guestNames(for: store.listProjects()) {
            mounts[guest] = store.projectURL(project).path
        }
        return mounts
    }

    /// Đường dẫn trong Linux của một dự án (nil nếu dự án không còn).
    static func guestPath(for project: String) -> String? {
        guestNames(for: ProjectStore.shared.listProjects())[project].map { "/root/" + $0 }
    }

    // MARK: Chuẩn bị hệ thống

    /// Cài rootfs (nếu chưa) và khởi động kernel. Gọi nhiều lần an toàn; mọi nơi gọi đều được báo khi xong.
    func prepareSystem(progress: ((Double, String) -> Void)? = nil, completion: @escaping (String?) -> Void) {
        if IshBridge.isBooted { completion(nil); return }
        prepareWaiters.append(completion)
        if let progress = progress { progressSink = progress }
        if preparing { return }
        preparing = true

        let finish: (String?) -> Void = { [weak self] error in
            guard let self = self else { return }
            self.preparing = false
            self.progressSink = nil
            if case .installing = self.state { self.state = .idle }
            let waiters = self.prepareWaiters
            self.prepareWaiters = []
            waiters.forEach { $0(error) }
        }

        let root = Self.rootURL
        if IshBridge.isRootInstalled(atPath: root.path) {
            finish(bootKernel(root))
            return
        }
        guard let archive = Bundle.main.path(forResource: "root", ofType: "tar.gz") else {
            finish("Thiếu root.tar.gz trong app (build chưa nhúng rootfs).")
            return
        }
        state = .installing(fraction: 0, message: "Đang cài hệ thống Linux (chỉ lần đầu)…")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let error = IshBridge.installRoot(fromArchive: archive, toPath: root.path) { fraction, message in
                DispatchQueue.main.async {
                    self?.progressSink?(fraction, message)
                    self?.state = .installing(fraction: fraction, message: message)
                }
            }
            DispatchQueue.main.async {
                if let error = error {
                    finish("Không cài được rootfs: \(error)")
                } else {
                    finish(self?.bootKernel(root))
                }
            }
        }
    }

    /// Khởi động kernel. Trả về thông báo lỗi nếu thất bại.
    private func bootKernel(_ root: URL) -> String? {
        if IshBridge.isBooted { return nil }
        let repositories = Bundle.main.path(forResource: "repositories", ofType: "txt")
            .flatMap { try? String(contentsOfFile: $0, encoding: .utf8) }
        IshBridge.setProjectMounts(Self.projectMounts())
        let err = IshBridge.boot(withRoot: root.path, repositories: repositories)
        return err < 0 ? "Không khởi động được kernel iSH (mã \(err))." : nil
    }

    // MARK: Cài gói lần đầu

    /// Cài rootfs, khởi động Linux rồi `apk add` các gói mặc định. `progress`: tỉ lệ 0…1, thông báo, dòng log cuối.
    func runSetup(progress: @escaping (Double, String, String?) -> Void,
                  completion: @escaping (SetupResult) -> Void) {
        // Chỉ có một phiên tại một thời điểm: đóng shell đang mở (sẽ tự mở lại sau khi cài xong).
        if case .running = state {
            suspendingShell = true
            shellWanted = true
            pendingSetupStart = { [weak self] in self?.beginSetup(progress: progress, completion: completion) }
            IshBridge.killSession()
            return
        }
        beginSetup(progress: progress, completion: completion)
    }

    private func beginSetup(progress: @escaping (Double, String, String?) -> Void,
                            completion: @escaping (SetupResult) -> Void) {
        setupCancelled = false
        setupInProgress = true
        let done: (SetupResult) -> Void = { [weak self] result in
            guard let self = self else { return }
            self.setupInProgress = false
            // Nếu trong lúc cài có nơi cần shell (mở dự án, mở cửa sổ shell) thì mở phiên shell bây giờ.
            if self.shellWanted {
                self.shellWanted = false
                self.startSession()
            }
            completion(result)
        }
        prepareSystem(progress: { fraction, message in progress(fraction * 0.3, message, nil) }) { [weak self] error in
            guard let self = self else { return }
            if self.setupCancelled { done(.skipped); return }
            if let error = error { done(.failed(error)); return }
            self.installPackages(progress: progress, completion: done)
        }
    }

    /// Bỏ qua bước cài gói: dừng `apk` nếu đang chạy.
    func cancelSetup() {
        setupCancelled = true
        IshBridge.killSession()
    }

    private func installPackages(progress: @escaping (Double, String, String?) -> Void,
                                 completion: @escaping (SetupResult) -> Void) {
        let command = "apk update && apk add " + Self.defaultPackages.joined(separator: " ")
        progress(0.3, "Đang cập nhật danh sách gói…", nil)

        var tail = ""
        let counter = try? NSRegularExpression(pattern: "\\((\\d+)/(\\d+)\\)\\s+(?:Installing|Upgrading|Purging)\\s+(\\S+)")
        let escapes = try? NSRegularExpression(pattern: "\u{1B}\\[[0-9;?]*[A-Za-z]")

        let err = IshBridge.startSession(directory: nil, command: ["/bin/sh", "-c", command], output: { data in
            tail += String(decoding: data, as: UTF8.self)
            if tail.count > 4000 { tail = String(tail.suffix(2000)) }
            let ns = tail as NSString

            var fraction = 0.3
            var message = "Đang cập nhật danh sách gói…"
            if let m = counter?.matches(in: tail, range: NSRange(location: 0, length: ns.length)).last {
                let n = Double(ns.substring(with: m.range(at: 1))) ?? 0
                let total = max(Double(ns.substring(with: m.range(at: 2))) ?? 1, 1)
                fraction = 0.35 + 0.65 * min((n - 1) / total, 1)
                message = "Đang cài gói \(Int(n))/\(Int(total)): \(ns.substring(with: m.range(at: 3)))"
            }
            var lastLine = tail.components(separatedBy: CharacterSet(charactersIn: "\r\n"))
                .last(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? ""
            lastLine = escapes?.stringByReplacingMatches(in: lastLine,
                                                         range: NSRange(location: 0, length: (lastLine as NSString).length),
                                                         withTemplate: "") ?? lastLine
            progress(fraction, message, lastLine.trimmingCharacters(in: .whitespaces))
        }, exit: { [weak self] code in
            guard let self = self else { return }
            if self.setupCancelled {
                completion(.skipped)
            } else if code == 0 {
                completion(.success)
            } else {
                let last = tail.components(separatedBy: CharacterSet(charactersIn: "\r\n"))
                    .last(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? ""
                completion(.failed("apk không chạy xong (mã \(Int(code) >> 8)). Cần kết nối mạng. \(last)"))
            }
        })
        if err < 0 { completion(.failed("Không mở được tiến trình cài đặt (mã \(err)).")) }
    }

    // MARK: Phiên shell

    /// Báo dự án vừa mở trong editor: iSH chạy ngầm và shell vào thư mục của dự án.
    func openProject(_ project: String) {
        desiredProject = project
        switch state {
        case .idle, .failed:
            ensureRunning()
        case .running:
            if sessionProject != project {
                switchingProject = true
                IshBridge.killSession()    // phiên sẽ tự mở lại, vào thư mục của dự án mới
            }
        case .installing, .starting:
            break                          // startSession sẽ lấy desiredProject
        }
    }

    func ensureRunning() {
        switch state {
        case .idle, .failed: break
        default: return
        }
        state = .starting
        if setupInProgress { shellWanted = true; return }     // sẽ mở phiên khi cài xong
        prepareSystem { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                self.state = .failed(error)
            } else if !self.setupInProgress {
                self.startSession()
            }
        }
    }

    private func startSession() {
        IshBridge.setProjectMounts(Self.projectMounts())
        let directory = desiredProject.flatMap { Self.guestPath(for: $0) }
        sessionProject = directory == nil ? nil : desiredProject
        lastStart = Date()
        let err = IshBridge.startSession(directory: directory, command: nil, output: { [weak self] data in
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
        if suspendingShell {
            suspendingShell = false
            state = .idle
            let start = pendingSetupStart
            pendingSetupStart = nil
            start?()
            return
        }
        if switchingProject {
            switchingProject = false
            terminalView.feed(text: "\u{1B}[2J\u{1B}[H")
            startSession()
            return
        }
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

// MARK: - Màn hình cài đặt lần đầu

/// Hiện ở lần chạy đầu (và khi chọn "Cài lại bộ công cụ" trong Cài đặt): cài Linux và các gói mặc định,
/// có thanh tiến trình và nút Bỏ qua.
final class IshSetupViewController: UIViewController {

    var onFinish: (() -> Void)?

    private let runtime = IshRuntime.shared
    private let stack = UIStackView()
    private let icon = UIImageView(image: UIImage(systemName: "terminal"))
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let progress = UIProgressView(progressViewStyle: .default)
    private let statusLabel = UILabel()
    private let logLabel = UILabel()
    private let retryButton = UIButton(type: .system)
    private let skipButton = UIButton(type: .system)
    private var finished = false

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { OrientationPolicy.mask }

    override func viewDidLoad() {
        super.viewDidLoad()

        icon.contentMode = .scaleAspectFit
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 44, weight: .light)
        titleLabel.text = "Chuẩn bị môi trường Linux"
        titleLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        detailLabel.text = "Catnip cài sẵn \(IshRuntime.defaultPackages.joined(separator: ", ")) để bạn biên dịch và chạy code ngay trong shell. "
            + "Cần kết nối mạng. Bạn có thể bỏ qua và cài sau bằng lệnh apk add."
        detailLabel.font = .systemFont(ofSize: 14)
        detailLabel.textAlignment = .center
        detailLabel.numberOfLines = 0
        statusLabel.font = .systemFont(ofSize: 15)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        logLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        logLabel.textAlignment = .center
        logLabel.numberOfLines = 2
        logLabel.lineBreakMode = .byTruncatingHead
        retryButton.setTitle("Thử lại", for: .normal)
        retryButton.addAction(UIAction { [weak self] _ in self?.start() }, for: .touchUpInside)
        skipButton.setTitle("Bỏ qua", for: .normal)
        skipButton.addAction(UIAction { [weak self] _ in self?.skip() }, for: .touchUpInside)

        stack.axis = .vertical
        stack.spacing = 14
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        [icon, titleLabel, detailLabel, progress, statusLabel, logLabel, retryButton, skipButton]
            .forEach { stack.addArrangedSubview($0) }
        stack.setCustomSpacing(24, after: detailLabel)
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -32)
        ])
        let width = stack.widthAnchor.constraint(lessThanOrEqualToConstant: 520)
        width.isActive = true

        applyColors()
        start()
    }

    private func applyColors() {
        let t = Appearance.theme
        view.backgroundColor = t.bgColor
        icon.tintColor = t.accentColor
        titleLabel.textColor = t.fgColor
        detailLabel.textColor = t.mutedColor
        statusLabel.textColor = t.fgColor
        logLabel.textColor = t.mutedColor
        progress.tintColor = t.accentColor
        retryButton.tintColor = t.accentColor
        skipButton.tintColor = t.mutedColor
    }

    private func start() {
        finished = false
        UIApplication.shared.isIdleTimerDisabled = true
        progress.progress = 0
        progress.isHidden = false
        statusLabel.text = "Đang chuẩn bị…"
        logLabel.text = nil
        retryButton.isHidden = true
        runtime.runSetup(progress: { [weak self] fraction, message, log in
            guard let self = self, !self.finished else { return }
            self.progress.setProgress(Float(fraction), animated: true)
            self.statusLabel.text = message
            if let log = log { self.logLabel.text = log }
        }, completion: { [weak self] result in
            guard let self = self, !self.finished else { return }
            switch result {
            case .success:
                self.progress.setProgress(1, animated: true)
                self.statusLabel.text = "Xong! Đang vào Catnip…"
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.finish() }
            case .skipped:
                self.finish()
            case .failed(let message):
                UIApplication.shared.isIdleTimerDisabled = false
                self.statusLabel.text = message
                self.retryButton.isHidden = false
            }
        })
    }

    private func skip() {
        runtime.cancelSetup()
        finish()
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        UIApplication.shared.isIdleTimerDisabled = false
        SettingsStore.shared.update { $0.ishSetupDone = true }
        SettingsStore.shared.saveNow()
        onFinish?()
    }
}

#endif
