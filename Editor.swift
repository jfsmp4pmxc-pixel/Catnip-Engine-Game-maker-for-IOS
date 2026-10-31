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
import UIKit

final class EditorViewController: UIViewController {

    // MARK: State
    let project: String
    let store = ProjectStore.shared

    var currentPath: String?
    var canEdit = true
    var isDirty = false
    var language: Language = .plaintext
    var expanded = Set<String>()
    var entries: [FileEntry] = []

    // MARK: Views
    let textView = UITextView()
    let statusBar = UIView()
    let statusLabel = UILabel()
    let titleLabel = UILabel()
    let gutter = LineNumberGutter()
    var gutterWidth: NSLayoutConstraint!
    var langItem: UIBarButtonItem!

    let sidebar = UIView()
    let sidebarHeader = UIView()
    let sidebarTitle = UILabel()
    let backdrop = UIView()
    let fileTable = UITableView(frame: .zero, style: .plain)
    var sidebarLeading: NSLayoutConstraint!
    var isSidebarOpen = false
    let sidebarWidth: CGFloat = 280

    // MARK: Timers
    var highlightWork: DispatchWorkItem?
    var saveWork: DispatchWorkItem?
    var flashWork: DispatchWorkItem?
    var flashText: String?

    // MARK: Init
    init(project: String) {
        self.project = project
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { NotificationCenter.default.removeObserver(self) }

    // MARK: Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.leftItemsSupplementBackButton = true
        navigationItem.titleView = titleLabel
        titleLabel.numberOfLines = 2
        titleLabel.textAlignment = .center
        titleLabel.lineBreakMode = .byTruncatingMiddle

        buildNavItems()
        buildStatusBar()
        buildEditor()
        buildSidebar()

        NotificationCenter.default.addObserver(self, selector: #selector(applyTheme),
                                               name: .catnipSettingsChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(flushNotification),
                                               name: .catnipFlushNow, object: nil)

        SettingsStore.shared.update { $0.lastProject = self.project }
        loadExpanded()
        reloadTree()
        openInitialFile()
        applyTheme()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = false
        applyTheme()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        flushSave()
        if isMovingFromParent {
            // Người dùng chủ động quay về danh sách → lần sau mở app sẽ vào danh sách.
            SettingsStore.shared.update { $0.lastProject = nil }
        }
    }

    // MARK: Build
    private func buildNavItems() {
        let sidebarBtn = UIBarButtonItem(image: UIImage(systemName: "sidebar.left"),
                                         style: .plain, target: self, action: #selector(toggleSidebar))
        navigationItem.leftBarButtonItem = sidebarBtn

        let gear = UIBarButtonItem(image: UIImage(systemName: "gearshape"),
                                   style: .plain, target: self, action: #selector(settingsTapped))
        let save = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.down"),
                                   style: .plain, target: self, action: #selector(saveTapped))
        langItem = UIBarButtonItem(title: language.displayName, image: nil, primaryAction: nil, menu: nil)
        navigationItem.rightBarButtonItems = [gear, save, langItem]
        rebuildLanguageMenu()
    }

    private func buildStatusBar() {
        statusBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusBar)

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        statusBar.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            statusBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            statusBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            statusBar.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            statusBar.heightAnchor.constraint(equalToConstant: 26),

            statusLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            statusLabel.centerYAnchor.constraint(equalTo: statusBar.centerYAnchor)
        ])
    }

    private func buildEditor() {
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.smartInsertDeleteType = .no
        textView.spellCheckingType = .no
        textView.alwaysBounceVertical = true
        textView.keyboardDismissMode = .interactive
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
        textView.delegate = self
        textView.inputAccessoryView = makeAccessoryBar()
        view.addSubview(textView)

        gutter.translatesAutoresizingMaskIntoConstraints = false
        gutter.textView = textView
        view.addSubview(gutter)
        gutterWidth = gutter.widthAnchor.constraint(equalToConstant: 44)

        NSLayoutConstraint.activate([
            gutter.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            gutter.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            gutter.bottomAnchor.constraint(equalTo: statusBar.topAnchor),
            gutterWidth,

            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            textView.leadingAnchor.constraint(equalTo: gutter.trailingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: statusBar.topAnchor)
        ])
    }

    // MARK: Theme
    @objc func applyTheme() {
        let t = Appearance.theme
        Appearance.style(navigationController)
        view.backgroundColor = t.bg2Color
        statusBar.backgroundColor = t.bg2Color
        textView.backgroundColor = t.bgColor
        textView.tintColor = t.accentColor
        textView.keyboardAppearance = t.isDark ? .dark : .light
        sidebar.backgroundColor = t.bg2Color
        sidebarHeader.backgroundColor = t.bg2Color
        sidebarTitle.textColor = t.mutedColor
        fileTable.backgroundColor = t.bg2Color
        fileTable.separatorColor = t.borderColor
        applyEditorOptions()
        rehighlightNow()
        updateTitle()
        updateStatus()
        fileTable.reloadData()
    }

    // MARK: Opening files
    private func openInitialFile() {
        let s = SettingsStore.shared.settings
        if let last = s.lastFile, store.read(project: project, path: last) != nil {
            openFile(last)
            return
        }
        let files = allFilePaths()
        if files.contains("main.lua") { openFile("main.lua") }
        else if let first = files.first { openFile(first) }
        else { showNoFile() }
    }

    func allFilePaths() -> [String] {
        store.allFiles(project: project)
    }

    func openFile(_ path: String) {
        flushSave()
        currentPath = path
        if let text = store.read(project: project, path: path) {
            canEdit = true
            language = Language.detect(path)
            textView.isEditable = true
            textView.text = text
        } else {
            canEdit = false
            language = .plaintext
            textView.isEditable = false
            textView.text = "Không đọc được file này (không phải văn bản UTF-8)."
        }
        isDirty = false
        textView.selectedRange = NSRange(location: 0, length: 0)
        textView.setContentOffset(.zero, animated: false)
        textView.undoManager?.removeAllActions()
        SettingsStore.shared.update { $0.lastFile = path }
        rebuildLanguageMenu()
        refreshGutter()
        rehighlightNow()
        updateTitle()
        updateStatus()
        fileTable.reloadData()
    }

    func showNoFile() {
        currentPath = nil
        canEdit = false
        isDirty = false
        language = .plaintext
        textView.isEditable = false
        textView.text = ""
        SettingsStore.shared.update { $0.lastFile = nil }
        rebuildLanguageMenu()
        refreshGutter()
        updateTitle()
        updateStatus()
        fileTable.reloadData()
    }

    // MARK: Saving
    func scheduleSave() {
        saveWork?.cancel()
        let w = DispatchWorkItem { [weak self] in self?.flushSave() }
        saveWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: w)
    }

    @discardableResult
    func flushSave() -> Bool {
        saveWork?.cancel()
        guard isDirty, canEdit, let path = currentPath else { return true }
        do {
            try store.write(project: project, path: path, content: textView.text ?? "")
            isDirty = false
            updateTitle()
            return true
        } catch {
            flash("⚠️ Lỗi lưu: \(error.localizedDescription)")
            return false
        }
    }

    @objc private func flushNotification() { flushSave() }

    @objc private func saveTapped() {
        guard currentPath != nil, canEdit else { return }
        isDirty = true   // ép ghi lại dù nội dung không đổi
        if flushSave() { flash("✓ Đã lưu \(currentPath ?? "")") }
    }

    @objc private func settingsTapped() {
        textView.resignFirstResponder()
        present(UINavigationController(rootViewController: SettingsViewController()), animated: true)
    }

    // MARK: Số dòng + xuống dòng (theo settings)
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if SettingsStore.shared.settings.wrapLines { applyWrapWidth() }
        gutter.setNeedsDisplay()
    }

    private func applyWrapWidth() {
        let w = textView.bounds.width - textView.textContainerInset.left - textView.textContainerInset.right
        if w > 0, abs(textView.textContainer.size.width - w) > 0.5 {
            textView.textContainer.size = CGSize(width: w, height: .greatestFiniteMagnitude)
        }
    }

    func applyEditorOptions() {
        let st = SettingsStore.shared.settings
        let t = Appearance.theme
        let tc = textView.textContainer
        if st.wrapLines {
            tc.widthTracksTextView = true
            tc.lineBreakMode = .byCharWrapping
            applyWrapWidth()
        } else {
            // Không ngắt dòng: container rất rộng, textView tự cuộn ngang.
            tc.widthTracksTextView = false
            tc.lineBreakMode = .byClipping
            tc.size = CGSize(width: 10_000, height: .greatestFiniteMagnitude)
        }
        textView.alwaysBounceHorizontal = !st.wrapLines

        gutter.isHidden = !st.showLineNumbers
        gutter.font = .monospacedSystemFont(ofSize: max(Appearance.fontSize - 2, 9), weight: .regular)
        gutter.textColor = t.mutedColor
        gutter.lineColor = t.borderColor
        gutter.backgroundColor = t.bg2Color
        refreshGutter()
    }

    /// Cập nhật bề rộng cột số dòng theo số chữ số của dòng cuối, rồi vẽ lại.
    func refreshGutter() {
        guard SettingsStore.shared.settings.showLineNumbers else {
            if gutterWidth.constant != 0 { gutterWidth.constant = 0 }
            return
        }
        var lines = 1
        for ch in (textView.text ?? "").utf16 where ch == 10 { lines += 1 }
        let digits = max(2, String(lines).count)
        let w = CGFloat(digits) * Appearance.fontSize * 0.6 + 18
        if abs(gutterWidth.constant - w) > 0.5 { gutterWidth.constant = w }
        gutter.setNeedsDisplay()
    }

    // MARK: Highlighting
    func scheduleHighlight() {
        highlightWork?.cancel()
        let w = DispatchWorkItem { [weak self] in self?.rehighlightNow() }
        highlightWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: w)
    }

    func rehighlightNow() {
        highlightWork?.cancel()
        // Đang gõ dở (Telex/VNI, bàn phím CJK…): chờ gõ xong rồi mới tô, tránh phá chữ đang soạn.
        guard textView.markedTextRange == nil else { scheduleHighlight(); return }
        let t = Appearance.theme
        let font = UIFont.monospacedSystemFont(ofSize: Appearance.fontSize, weight: .regular)
        let lang: Language = textView.textStorage.length > 200_000 ? .plaintext : language
        SyntaxHighlighter.apply(to: textView.textStorage, language: lang, theme: t, font: font)
        textView.typingAttributes = [.font: font, .foregroundColor: t.fgColor]
    }

    // MARK: Language menu
    func rebuildLanguageMenu() {
        let actions = Language.allCases.map { lang in
            UIAction(title: lang.displayName, state: lang == language ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.language = lang
                self.rebuildLanguageMenu()
                self.rehighlightNow()
                self.updateStatus()
            }
        }
        langItem.title = language.displayName
        langItem.menu = UIMenu(title: "Ngôn ngữ tô màu", children: actions)
    }

    // MARK: Title + status
    func updateTitle() {
        let t = Appearance.theme
        let name = currentPath ?? "Chưa chọn file"
        let text = NSMutableAttributedString(
            string: name + (isDirty ? " ●" : ""),
            attributes: [.font: UIFont.systemFont(ofSize: 15, weight: .semibold),
                         .foregroundColor: t.fgColor])
        text.append(NSAttributedString(
            string: "\n" + project,
            attributes: [.font: UIFont.systemFont(ofSize: 11),
                         .foregroundColor: t.mutedColor]))
        titleLabel.attributedText = text
        titleLabel.sizeToFit()
    }

    func updateStatus() {
        if let msg = flashText {
            statusLabel.text = msg
            statusLabel.textColor = Appearance.theme.accentColor
        } else {
            statusLabel.text = statusSummary()
            statusLabel.textColor = Appearance.theme.mutedColor
        }
    }

    private func statusSummary() -> String {
        guard currentPath != nil else { return "Chọn hoặc tạo một file ở thanh bên" }
        let ns = (textView.text ?? "") as NSString
        let loc = min(textView.selectedRange.location, ns.length)
        var line = 1
        for ch in ns.substring(to: loc).utf16 where ch == 10 { line += 1 }
        let lineStart = ns.lineRange(for: NSRange(location: loc, length: 0)).location
        let col = loc - lineStart + 1
        return "\(language.displayName) · Dòng \(line), Cột \(col) · \(ns.length) ký tự"
    }

    func flash(_ message: String) {
        flashWork?.cancel()
        flashText = message
        updateStatus()
        let w = DispatchWorkItem { [weak self] in
            self?.flashText = nil
            self?.updateStatus()
        }
        flashWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6, execute: w)
    }

    // MARK: Keyboard accessory bar (phím tắt cho code)
    private func makeAccessoryBar() -> UIView {
        let bar = UIInputView(frame: CGRect(x: 0, y: 0, width: 0, height: 44), inputViewStyle: .keyboard)
        bar.autoresizingMask = .flexibleWidth

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.showsHorizontalScrollIndicator = false
        bar.addSubview(scroll)

        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 0
        scroll.addSubview(stack)

        let hide = makeKey(symbol: "keyboard.chevron.compact.down") { [weak self] in
            self?.textView.resignFirstResponder()
        }
        hide.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(hide)

        stack.addArrangedSubview(makeKey(symbol: "arrow.right.to.line") { [weak self] in self?.textView.insertText("  ") })
        stack.addArrangedSubview(makeKey(symbol: "arrow.uturn.backward") { [weak self] in self?.textView.undoManager?.undo() })
        stack.addArrangedSubview(makeKey(symbol: "arrow.uturn.forward") { [weak self] in self?.textView.undoManager?.redo() })
        for (o, c) in [("(", ")"), ("{", "}"), ("[", "]"), ("\"", "\""), ("'", "'")] {
            stack.addArrangedSubview(makeKey(title: o + c) { [weak self] in self?.insertPair(o, c) })
        }
        for s in ["=", ".", ",", ":", ";", "-", "_", "#", "+", "*", "/", "<", ">", "|", "&", "~"] {
            stack.addArrangedSubview(makeKey(title: s) { [weak self] in self?.textView.insertText(s) })
        }

        NSLayoutConstraint.activate([
            hide.trailingAnchor.constraint(equalTo: bar.trailingAnchor),
            hide.topAnchor.constraint(equalTo: bar.topAnchor),
            hide.bottomAnchor.constraint(equalTo: bar.bottomAnchor),

            scroll.leadingAnchor.constraint(equalTo: bar.leadingAnchor),
            scroll.topAnchor.constraint(equalTo: bar.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bar.bottomAnchor),
            scroll.trailingAnchor.constraint(equalTo: hide.leadingAnchor),

            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor)
        ])
        return bar
    }

    private func makeKey(title: String? = nil, symbol: String? = nil,
                         action: @escaping () -> Void) -> UIButton {
        var cfg = UIButton.Configuration.plain()
        if let symbol = symbol {
            cfg.image = UIImage(systemName: symbol)
        } else {
            cfg.title = title
            cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
                var a = attrs
                a.font = UIFont.monospacedSystemFont(ofSize: 18, weight: .medium)
                return a
            }
        }
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 11, bottom: 8, trailing: 11)
        cfg.baseForegroundColor = .label
        let b = UIButton(configuration: cfg, primaryAction: UIAction { _ in action() })
        b.widthAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true
        return b
    }

    private func insertPair(_ open: String, _ close: String) {
        let sel = textView.selectedRange
        let ns = (textView.text ?? "") as NSString
        let selected = sel.location + sel.length <= ns.length ? ns.substring(with: sel) : ""
        textView.insertText(open + selected + close)
        let cursor = sel.location + (open as NSString).length + (selected as NSString).length
        textView.selectedRange = NSRange(location: cursor, length: 0)
    }
}

// MARK: - UITextViewDelegate

extension EditorViewController: UITextViewDelegate {

    func textViewDidChange(_ textView: UITextView) {
        guard canEdit else { return }
        if !isDirty { isDirty = true; updateTitle() }
        scheduleSave()
        scheduleHighlight()
        refreshGutter()
        updateStatus()
    }

    func textViewDidChangeSelection(_ textView: UITextView) {
        updateStatus()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        gutter.setNeedsDisplay()
    }

    /// Enter → giữ nguyên thụt lề của dòng hiện tại, thụt thêm nếu dòng mở một khối.
    func textView(_ tv: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        guard text == "\n", range == tv.selectedRange, tv.markedTextRange == nil else { return true }
        let ns = (tv.text ?? "") as NSString
        guard range.location <= ns.length else { return true }
        let lineStart = ns.lineRange(for: NSRange(location: range.location, length: 0)).location
        let before = ns.substring(with: NSRange(location: lineStart, length: range.location - lineStart))
        var indent = String(before.prefix(while: { $0 == " " || $0 == "\t" }))
        if opensBlock(before.trimmingCharacters(in: .whitespaces)) { indent += "  " }
        tv.insertText("\n" + indent)
        return false
    }

    private func opensBlock(_ line: String) -> Bool {
        switch language {
        case .lua:
            if line.hasPrefix("--") { return false }
            for suffix in ["then", "do", "else", "repeat", "{", "("] where line.hasSuffix(suffix) { return true }
            return line.hasPrefix("function") || line.hasPrefix("local function")
                || line.contains("function(") || line.contains("function (")
        case .python:
            return line.hasSuffix(":")
        case .plaintext, .markdown:
            return false
        default:
            return line.hasSuffix("{") || line.hasSuffix("[") || line.hasSuffix("(")
        }
    }
}

// MARK: - Cột số dòng

/// Vẽ số dòng bên trái editor, đồng bộ với layoutManager của textView.
/// Với dòng bị xuống hàng, chỉ đánh số ở phần đầu của dòng.
final class LineNumberGutter: UIView {
    weak var textView: UITextView?
    var font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    var textColor = UIColor.gray
    var lineColor = UIColor.separator

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentMode = .redraw
        isUserInteractionEnabled = false
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ rect: CGRect) {
        guard let tv = textView else { return }
        let lm = tv.layoutManager
        let text = (tv.text ?? "") as NSString
        let offsetY = tv.contentOffset.y
        let topInset = tv.textContainerInset.top
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textColor]
        let width = bounds.width

        // đường kẻ phân cách bên phải
        lineColor.setFill()
        UIRectFill(CGRect(x: width - 0.5, y: 0, width: 0.5, height: bounds.height))

        func drawNumber(_ n: Int, in lineRect: CGRect) {
            let s = "\(n)" as NSString
            let size = s.size(withAttributes: attrs)
            let y = lineRect.minY + topInset - offsetY + (lineRect.height - size.height) / 2
            s.draw(at: CGPoint(x: width - 8 - size.width, y: y), withAttributes: attrs)
        }

        let visible = CGRect(x: 0, y: offsetY - topInset,
                             width: max(tv.textContainer.size.width, 1), height: bounds.height)
        let glyphs = lm.glyphRange(forBoundingRect: visible, in: tv.textContainer)

        if glyphs.length > 0 {
            let firstChar = lm.characterIndexForGlyph(at: glyphs.location)
            var newlinesBefore = 0
            for ch in text.substring(to: firstChar).utf16 where ch == 10 { newlinesBefore += 1 }
            let firstStartsParagraph = firstChar == 0 || text.character(at: firstChar - 1) == 10
            var next = newlinesBefore + (firstStartsParagraph ? 1 : 2)

            lm.enumerateLineFragments(forGlyphRange: glyphs) { lineRect, _, _, lineGlyphs, _ in
                let chars = lm.characterRange(forGlyphRange: lineGlyphs, actualGlyphRange: nil)
                let startsParagraph = chars.location == 0 || text.character(at: chars.location - 1) == 10
                if startsParagraph {
                    drawNumber(next, in: lineRect)
                    next += 1
                }
            }
        }

        // Dòng cuối rỗng (văn bản trống hoặc kết thúc bằng xuống dòng)
        let extra = lm.extraLineFragmentRect
        if extra.height > 0 {
            var total = 1
            for ch in text.utf16 where ch == 10 { total += 1 }
            drawNumber(total, in: extra)
        }
    }
}
