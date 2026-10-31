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

// GameRun.swift
// Log của game, bảng xem log, và cửa sổ nổi (nút Log / Thoát) hiện trên game đang chạy.

import UIKit

extension Notification.Name {
    static let catnipLogChanged = Notification.Name("catnip.logChanged")
}

// MARK: - Log của lần chạy gần nhất

final class GameLog {
    static let shared = GameLog()

    private let lock = NSLock()
    private var buffer = ""
    private let maxChars = 200_000   // giữ phần cuối, tránh ngốn RAM nếu game in liên tục

    private init() {}

    var text: String {
        lock.lock(); defer { lock.unlock() }
        return buffer
    }

    /// Gọi được từ thread nền.
    func append(_ s: String) {
        lock.lock()
        buffer += s
        if buffer.count > maxChars {
            buffer = String(buffer.suffix(maxChars))
        }
        lock.unlock()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .catnipLogChanged, object: nil)
        }
    }

    func clear() {
        lock.lock(); buffer = ""; lock.unlock()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .catnipLogChanged, object: nil)
        }
    }
}

// MARK: - Bảng xem log (dùng cho cả cửa sổ nổi và màn hình Log trong editor)

final class LogPanelView: UIView {

    let textView = UITextView()
    private let header = UIView()
    private let titleLabel = UILabel()
    private var followTail = true
    var onClose: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        build()
        NotificationCenter.default.addObserver(self, selector: #selector(refresh),
                                               name: .catnipLogChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applyTheme),
                                               name: .catnipSettingsChanged, object: nil)
        applyTheme()
        refresh()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { NotificationCenter.default.removeObserver(self) }

    private func button(_ symbol: String, _ action: @escaping () -> Void) -> UIButton {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setImage(UIImage(systemName: symbol), for: .normal)
        b.addAction(UIAction { _ in action() }, for: .touchUpInside)
        b.widthAnchor.constraint(equalToConstant: 40).isActive = true
        b.heightAnchor.constraint(equalToConstant: 40).isActive = true
        return b
    }

    private func build() {
        layer.cornerRadius = 12
        layer.masksToBounds = true

        header.translatesAutoresizingMaskIntoConstraints = false
        addSubview(header)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "LOG"
        titleLabel.font = .systemFont(ofSize: 12, weight: .bold)
        header.addSubview(titleLabel)

        let copy = button("doc.on.doc") { UIPasteboard.general.string = GameLog.shared.text }
        let clear = button("trash") { GameLog.shared.clear() }
        let close = button("xmark") { [weak self] in self?.onClose?() }
        [copy, clear, close].forEach { header.addSubview($0) }

        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isEditable = false
        textView.alwaysBounceVertical = true
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        textView.delegate = self
        addSubview(textView)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: topAnchor),
            header.leadingAnchor.constraint(equalTo: leadingAnchor),
            header.trailingAnchor.constraint(equalTo: trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 40),

            titleLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: header.centerYAnchor),

            close.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -4),
            clear.trailingAnchor.constraint(equalTo: close.leadingAnchor),
            copy.trailingAnchor.constraint(equalTo: clear.leadingAnchor),
            close.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            clear.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            copy.centerYAnchor.constraint(equalTo: header.centerYAnchor),

            textView.topAnchor.constraint(equalTo: header.bottomAnchor),
            textView.leadingAnchor.constraint(equalTo: leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @objc private func applyTheme() {
        let t = Appearance.theme
        backgroundColor = t.bg2Color
        header.backgroundColor = t.bg3Color
        titleLabel.textColor = t.mutedColor
        header.tintColor = t.accentColor
        textView.backgroundColor = t.bgColor
        textView.textColor = t.fgColor
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        refresh()
    }

    @objc func refresh() {
        let t = Appearance.theme
        let text = GameLog.shared.text
        let shown = text.isEmpty ? "(chưa có log — print() trong game sẽ hiện ở đây)" : text
        textView.attributedText = NSAttributedString(string: shown, attributes: [
            .font: UIFont.monospacedSystemFont(ofSize: 12, weight: .regular),
            .foregroundColor: text.isEmpty ? t.mutedColor : t.fgColor
        ])
        if followTail { scrollToEnd() }
    }

    private func scrollToEnd() {
        let len = textView.textStorage.length
        guard len > 0 else { return }
        textView.scrollRangeToVisible(NSRange(location: len - 1, length: 1))
    }
}

extension LogPanelView: UITextViewDelegate {
    /// Đang kéo xem log cũ thì đừng tự cuộn xuống cuối; kéo tới đáy thì bật lại.
    func scrollViewDidScroll(_ sv: UIScrollView) {
        let atBottom = sv.contentOffset.y >= sv.contentSize.height - sv.bounds.height - 24
        followTail = atBottom
    }
}

// MARK: - Màn hình Log trong editor (xem log lần chạy gần nhất)

final class LogViewController: UIViewController {
    private let panel = LogPanelView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Log lần chạy gần nhất"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done, target: self, action: #selector(close))
        Appearance.style(navigationController)
        view.backgroundColor = Appearance.theme.bgColor

        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.layer.cornerRadius = 0
        panel.onClose = { [weak self] in self?.close() }
        view.addSubview(panel)
        NSLayoutConstraint.activate([
            panel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            panel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            panel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            panel.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    @objc private func close() { dismiss(animated: true) }
}

// MARK: - Cửa sổ nổi trên game đang chạy

/// Cửa sổ trong suốt: chỉ nhận chạm ở nút / bảng log, còn lại cho xuyên xuống game.
private final class PassthroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return (hit === self || hit === rootViewController?.view) ? nil : hit
    }
}

private final class OverlayViewController: UIViewController {
    var onQuit: (() -> Void)?

    private let pill = UIStackView()
    private let logPanel = LogPanelView()
    private let quitButton = UIButton(type: .system)
    private let logButton = UIButton(type: .system)
    private var collapsed = false

    override func loadView() {
        let v = UIView()
        v.backgroundColor = .clear
        view = v
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        func style(_ b: UIButton, _ symbol: String, _ title: String, _ color: UIColor) {
            var cfg = UIButton.Configuration.filled()
            cfg.image = UIImage(systemName: symbol)
            cfg.title = title
            cfg.imagePadding = 4
            cfg.cornerStyle = .capsule
            cfg.baseBackgroundColor = color
            cfg.baseForegroundColor = .white
            cfg.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
            cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { a in
                var a = a; a.font = .systemFont(ofSize: 13, weight: .semibold); return a
            }
            b.configuration = cfg
        }
        style(quitButton, "xmark.circle.fill", "Thoát", UIColor.systemRed.withAlphaComponent(0.88))
        style(logButton, "text.alignleft", "Log", UIColor.black.withAlphaComponent(0.65))

        quitButton.addAction(UIAction { [weak self] _ in self?.onQuit?() }, for: .touchUpInside)
        logButton.addAction(UIAction { [weak self] _ in self?.toggleLog() }, for: .touchUpInside)

        pill.translatesAutoresizingMaskIntoConstraints = false
        pill.axis = .horizontal
        pill.spacing = 8
        pill.addArrangedSubview(logButton)
        pill.addArrangedSubview(quitButton)
        view.addSubview(pill)

        logPanel.translatesAutoresizingMaskIntoConstraints = false
        logPanel.isHidden = true
        logPanel.alpha = 0.97
        logPanel.onClose = { [weak self] in self?.toggleLog() }
        view.addSubview(logPanel)

        NSLayoutConstraint.activate([
            pill.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            pill.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8),

            logPanel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
            logPanel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8),
            logPanel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            logPanel.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.45)
        ])
    }

    private func toggleLog() {
        logPanel.isHidden.toggle()
        if !logPanel.isHidden { logPanel.refresh() }
    }
}

enum GameRunOverlay {
    private static var window: UIWindow?

    /// Hiện nút Log / Thoát nổi trên game. `onQuit` được gọi khi bấm Thoát.
    static func show(onQuit: @escaping () -> Void) {
        guard window == nil else { return }
        let vc = OverlayViewController()
        vc.onQuit = onQuit
        let w = PassthroughWindow(frame: UIScreen.main.bounds)
        w.windowLevel = .alert + 1
        w.backgroundColor = .clear
        w.rootViewController = vc
        w.isHidden = false          // hiện nhưng KHÔNG làm key window, để game vẫn nhận bàn phím/chạm
        window = w
    }

    static func hide() {
        window?.isHidden = true
        window = nil
    }
}
