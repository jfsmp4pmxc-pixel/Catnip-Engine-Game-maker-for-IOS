// UI.swift
// MiniCode — main editor UI

import UIKit

final class CodeEditorViewController: UIViewController {

    // MARK: Model
    let store = FileStore.shared
    var theme: Theme = .dark
    var language: Language = .javascript
    var fontSize: CGFloat = 14

    // MARK: Views
    private var textView: UITextView!
    private var fileNameLabel: UILabel!
    private var langButton: UIButton!
    private var statusLabel: UILabel!
    private var toolbar: UIView!
    private var statusBar: UIView!
    private var sidebar: UIView!
    private var fileTable: UITableView!
    private var sidebarBackdrop: UIView!
    private var isSidebarOpen = false
    private var highlightWorkItem: DispatchWorkItem?

    // MARK: Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = theme.bgColor
        buildToolbar()
        buildEditor()
        buildStatusBar()
        buildSidebar()
        loadCurrentFile()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        sidebar.frame = CGRect(x: isSidebarOpen ? 0 : -260, y: view.safeAreaInsets.top,
                               width: 260, height: view.bounds.height - view.safeAreaInsets.top)
    }

    // MARK: Build toolbar
    private func buildToolbar() {
        toolbar = UIView()
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.backgroundColor = theme.bg2Color
        view.addSubview(toolbar)

        let menuBtn = makeIconButton("☰") { [weak self] in self?.toggleSidebar() }
        fileNameLabel = UILabel()
        fileNameLabel.text = "untitled.js"
        fileNameLabel.textColor = theme.fgColor
        fileNameLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        fileNameLabel.translatesAutoresizingMaskIntoConstraints = false
        fileNameLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        langButton = UIButton(type: .system)
        langButton.setTitle("JavaScript", for: .normal)
        langButton.titleLabel?.font = .systemFont(ofSize: 12)
        langButton.setTitleColor(theme.accentColor, for: .normal)
        langButton.translatesAutoresizingMaskIntoConstraints = false
        langButton.showsMenuAsPrimaryAction = true
        rebuildLanguageMenu()

        let saveBtn = makeIconButton("💾") { [weak self] in self?.saveTapped() }
        let settingsBtn = makeIconButton("⚙️") { [weak self] in self?.settingsTapped() }

        [menuBtn, fileNameLabel, langButton, saveBtn, settingsBtn].forEach { toolbar.addSubview($0) }

        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 44),

            menuBtn.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor, constant: 8),
            menuBtn.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),

            fileNameLabel.leadingAnchor.constraint(equalTo: menuBtn.trailingAnchor, constant: 8),
            fileNameLabel.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),

            settingsBtn.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor, constant: -8),
            settingsBtn.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),

            saveBtn.trailingAnchor.constraint(equalTo: settingsBtn.leadingAnchor, constant: -4),
            saveBtn.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),

            langButton.trailingAnchor.constraint(equalTo: saveBtn.leadingAnchor, constant: -8),
            langButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            langButton.leadingAnchor.constraint(greaterThanOrEqualTo: fileNameLabel.trailingAnchor, constant: 8)
        ])
    }

    // MARK: Build editor
    private func buildEditor() {
        textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.backgroundColor = theme.bgColor
        textView.textColor = theme.fgColor
        textView.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.smartInsertDeleteType = .no
        textView.spellCheckingType = .no
        textView.keyboardType = .asciiCapable
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
        textView.delegate = self
        view.addSubview(textView)

        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24)
        ])
    }

    // MARK: Build status bar
    private func buildStatusBar() {
        statusBar = UIView()
        statusBar.translatesAutoresizingMaskIntoConstraints = false
        statusBar.backgroundColor = theme.bg2Color
        view.addSubview(statusBar)

        statusLabel = UILabel()
        statusLabel.textColor = theme.mutedColor
        statusLabel.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusBar.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            statusBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            statusBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            statusBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            statusBar.heightAnchor.constraint(equalToConstant: 24),

            statusLabel.leadingAnchor.constraint(equalTo: statusBar.leadingAnchor, constant: 12),
            statusLabel.centerYAnchor.constraint(equalTo: statusBar.centerYAnchor)
        ])
    }

    // MARK: Build sidebar
    private func buildSidebar() {
        sidebarBackdrop = UIView(frame: view.bounds)
        sidebarBackdrop.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        sidebarBackdrop.alpha = 0
        sidebarBackdrop.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        sidebarBackdrop.isHidden = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(closeSidebar))
        sidebarBackdrop.addGestureRecognizer(tap)
        view.addSubview(sidebarBackdrop)

        sidebar = UIView()
        sidebar.backgroundColor = theme.bg2Color
        view.addSubview(sidebar)

        let header = UIView()
        header.translatesAutoresizingMaskIntoConstraints = false
        header.backgroundColor = theme.bg2Color
        sidebar.addSubview(header)

        let title = UILabel()
        title.text = "FILES"
        title.font = .systemFont(ofSize: 11, weight: .bold)
        title.textColor = theme.mutedColor
        title.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(title)

        let newFileBtn = makeIconButton("+📄") { [weak self] in self?.newFileTapped() }
        header.addSubview(newFileBtn)

        fileTable = UITableView(frame: .zero, style: .plain)
        fileTable.translatesAutoresizingMaskIntoConstraints = false
        fileTable.backgroundColor = theme.bg2Color
        fileTable.separatorStyle = .none
        fileTable.rowHeight = 34
        fileTable.dataSource = self
        fileTable.delegate = self
        fileTable.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        sidebar.addSubview(fileTable)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: sidebar.topAnchor),
            header.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 40),

            title.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 12),
            title.centerYAnchor.constraint(equalTo: header.centerYAnchor),

            newFileBtn.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -8),
            newFileBtn.centerYAnchor.constraint(equalTo: header.centerYAnchor),

            fileTable.topAnchor.constraint(equalTo: header.bottomAnchor),
            fileTable.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor),
            fileTable.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            fileTable.bottomAnchor.constraint(equalTo: sidebar.bottomAnchor)
        ])
    }

    // MARK: Actions
    @objc private func toggleSidebar() {
        if isSidebarOpen { closeSidebar() } else { openSidebar() }
    }

    private func openSidebar() {
        isSidebarOpen = true
        sidebarBackdrop.isHidden = false
        UIView.animate(withDuration: 0.22) {
            self.sidebar.frame.origin.x = 0
            self.sidebarBackdrop.alpha = 1
        }
    }

    @objc private func closeSidebar() {
        isSidebarOpen = false
        UIView.animate(withDuration: 0.22, animations: {
            self.sidebar.frame.origin.x = -260
            self.sidebarBackdrop.alpha = 0
        }) { _ in
            self.sidebarBackdrop.isHidden = true
        }
    }

    private func saveTapped() {
        guard let f = store.currentFile, store.files[f] != nil else { return }
        store.files[f]?.content = textView.text ?? ""
        store.save()
        flashStatus("✓ Đã lưu \(f)")
    }

    private func settingsTapped() {
        let ac = UIAlertController(title: "⚙️ Cài đặt", message: nil, preferredStyle: .actionSheet)

        // Theme
        ac.addAction(UIAlertAction(title: "🎨 Đổi theme", style: .default) { [weak self] _ in
            self?.chooseTheme()
        })

        // Font size
        ac.addAction(UIAlertAction(title: "🔤 Đổi cỡ chữ", style: .default) { [weak self] _ in
            self?.chooseFontSize()
        })

        ac.addAction(UIAlertAction(title: "❌ Đóng", style: .cancel))

        if let pop = ac.popoverPresentationController {
            pop.sourceView = toolbar
            pop.sourceRect = toolbar.bounds
        }
        present(ac, animated: true)
    }

    private func chooseTheme() {
        let ac = UIAlertController(title: "🎨 Theme", message: nil, preferredStyle: .actionSheet)
        for t in Theme.all {
            let mark = (t.name == theme.name) ? "✓ " : ""
            ac.addAction(UIAlertAction(title: mark + t.name, style: .default) { [weak self] _ in
                self?.applyTheme(t)
            })
        }
        ac.addAction(UIAlertAction(title: "Huỷ", style: .cancel))
        if let pop = ac.popoverPresentationController {
            pop.sourceView = toolbar
            pop.sourceRect = toolbar.bounds
        }
        present(ac, animated: true)
    }

    private func chooseFontSize() {
        let ac = UIAlertController(title: "🔤 Cỡ chữ", message: nil, preferredStyle: .actionSheet)
        for size in [12, 13, 14, 16, 18, 20] {
            let mark = (Int(fontSize) == size) ? "✓ " : ""
            ac.addAction(UIAlertAction(title: mark + "\(size) pt", style: .default) { [weak self] _ in
                self?.fontSize = CGFloat(size)
                self?.rehighlight()
            })
        }
        ac.addAction(UIAlertAction(title: "Huỷ", style: .cancel))
        if let pop = ac.popoverPresentationController {
            pop.sourceView = toolbar
            pop.sourceRect = toolbar.bounds
        }
        present(ac, animated: true)
    }

    private func applyTheme(_ t: Theme) {
        theme = t
        view.backgroundColor = t.bgColor
        toolbar.backgroundColor = t.bg2Color
        statusBar.backgroundColor = t.bg2Color
        sidebar.backgroundColor = t.bg2Color
        fileTable.backgroundColor = t.bg2Color
        fileNameLabel.textColor = t.fgColor
        langButton.setTitleColor(t.accentColor, for: .normal)
        statusLabel.textColor = t.mutedColor
        textView.backgroundColor = t.bgColor
        rehighlight()
        fileTable.reloadData()
    }

    private func newFileTapped() {
        closeSidebar()
        let alert = UIAlertController(title: "Tạo file mới",
                                      message: "Nhập tên (vd: src/app.js)",
                                      preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = "src/app.js"
            tf.autocapitalizationType = .none
            tf.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: "Huỷ", style: .cancel))
        alert.addAction(UIAlertAction(title: "Tạo", style: .default) { [weak self] _ in
            guard let self = self,
                  let raw = alert.textFields?.first?.text else { return }
            let path = raw.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
            guard !path.isEmpty else { return }
            if self.store.files[path] != nil {
                self.flashStatus("File đã tồn tại")
                return
            }
            let lang = Language.detect(path)
            self.store.createFile(at: path, language: lang)
            self.fileTable.reloadData()
            self.loadCurrentFile()
        })
        present(alert, animated: true)
    }

    // MARK: File loading + highlighting
    private func loadCurrentFile() {
        guard let f = store.currentFile, let file = store.files[f] else {
            textView.text = ""
            return
        }
        fileNameLabel.text = f
        language = file.language
        textView.text = file.content
        rebuildLanguageMenu()
        rehighlight()
        updateStatus()
    }

    private func rehighlight() {
        let selected = textView.selectedRange
        let font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let highlighted = SyntaxHighlighter.highlight(textView.text ?? "",
                                                      language: language,
                                                      theme: theme,
                                                      font: font)
        textView.attributedText = highlighted
        textView.typingAttributes = [
            .font: font,
            .foregroundColor: theme.fgColor
        ]
        textView.selectedRange = selected
        updateStatus()
    }

    private func updateStatus() {
        let txt = textView.text ?? ""
        let chars = txt.count
        let lines = txt.components(separatedBy: "\n").count
        statusLabel.text = "\(language.displayName) · \(chars) ký tự · \(lines) dòng"
    }

    private func flashStatus(_ msg: String) {
        let old = statusLabel.text
        statusLabel.text = msg
        statusLabel.textColor = theme.accentColor
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self = self else { return }
            self.statusLabel.text = old
            self.statusLabel.textColor = self.theme.mutedColor
            self.updateStatus()
        }
    }

    // MARK: Language menu
    private func rebuildLanguageMenu() {
        var actions: [UIAction] = []
        for lang in Language.allCases {
            let state: UIMenuElement.State = (lang == language) ? .on : .off
            actions.append(UIAction(title: lang.displayName, state: state) { [weak self] _ in
                guard let self = self else { return }
                self.language = lang
                if let f = self.store.currentFile, var file = self.store.files[f] {
                    file.language = lang
                    self.store.files[f] = file
                    self.store.save()
                }
                self.rebuildLanguageMenu()
                self.rehighlight()
            })
        }
        langButton.menu = UIMenu(title: "Language", children: actions)
        langButton.setTitle(language.displayName, for: .normal)
    }

    // MARK: Helpers
    private func makeIconButton(_ title: String, action: @escaping () -> Void) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 16)
        btn.setTitleColor(theme.fgColor, for: .normal)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addAction(UIAction { _ in action() }, for: .touchUpInside)
        btn.widthAnchor.constraint(equalToConstant: 36).isActive = true
        btn.heightAnchor.constraint(equalToConstant: 32).isActive = true
        return btn
    }
}

// MARK: - UITextViewDelegate
extension CodeEditorViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        if let f = store.currentFile, var file = store.files[f] {
            file.content = textView.text ?? ""
            store.files[f] = file
            // debounced save
            NSObject.cancelPreviousPerformRequests(withTarget: self,
                                                   selector: #selector(persist),
                                                   object: nil)
            perform(#selector(persist), with: nil, afterDelay: 0.6)
        }
        scheduleHighlight()
        updateStatus()
    }

    func textViewDidChangeSelection(_ textView: UITextView) {
        updateStatus()
    }

    @objc private func persist() {
        store.save()
    }

    private func scheduleHighlight() {
        highlightWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            let selected = self.textView.selectedRange
            let font = UIFont.monospacedSystemFont(ofSize: self.fontSize, weight: .regular)
            let hl = SyntaxHighlighter.highlight(self.textView.text ?? "",
                                                 language: self.language,
                                                 theme: self.theme,
                                                 font: font)
            self.textView.attributedText = hl
            self.textView.selectedRange = selected
        }
        highlightWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: work)
    }
}

// MARK: - File list
extension CodeEditorViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return store.visiblePaths().count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let path = store.visiblePaths()[indexPath.row]
        let isFolder = path.hasSuffix("/")
        let displayName = (path as NSString).lastPathComponent

        var indent = ""
        let depth = path.split(separator: "/").count - 1
        indent = String(repeating: "  ", count: depth)

        let isExpanded = isFolder && store.expandedFolders.contains(String(path.dropLast()))
        let icon = isFolder ? (isExpanded ? "📂" : "📁") : "📄"
        cell.textLabel?.text = "\(indent)\(icon) \(displayName)"
        cell.textLabel?.font = .systemFont(ofSize: 12)
        cell.backgroundColor = theme.bg2Color
        if !isFolder && path == store.currentFile {
            cell.textLabel?.textColor = theme.accentColor
            cell.backgroundColor = theme.hoverColor
        } else {
            cell.textLabel?.textColor = theme.fgColor
        }
        cell.selectionStyle = .none
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let path = store.visiblePaths()[indexPath.row]
        if path.hasSuffix("/") {
            let folder = String(path.dropLast())
            if store.expandedFolders.contains(folder) {
                store.expandedFolders.remove(folder)
            } else {
                store.expandedFolders.insert(folder)
            }
            store.save()
            fileTable.reloadData()
        } else {
            store.currentFile = path
            store.save()
            loadCurrentFile()
            fileTable.reloadData()
            closeSidebar()
        }
    }

    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath)
    -> UISwipeActionsConfiguration? {
        let path = store.visiblePaths()[indexPath.row]
        if path.hasSuffix("/") { return nil }
        let del = UIContextualAction(style: .destructive, title: "Xoá") { [weak self] _, _, done in
            guard let self = self else { done(false); return }
            self.store.files.removeValue(forKey: path)
            if self.store.currentFile == path {
                self.store.currentFile = self.store.files.keys.sorted().first
            }
            self.store.save()
            self.fileTable.reloadData()
            self.loadCurrentFile()
            done(true)
        }
        return UISwipeActionsConfiguration(actions: [del])
    }
}