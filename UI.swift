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

extension Notification.Name {
    static let catnipSettingsChanged = Notification.Name("catnip.settingsChanged")
}

// MARK: - Appearance (đọc theme / cỡ chữ từ settings.json)

enum Appearance {
    static var theme: Theme { Theme.byName(SettingsStore.shared.settings.themeName) }
    static let fontSizeRange: ClosedRange<Double> = 2...32
    static var fontSize: CGFloat {
        CGFloat(min(max(SettingsStore.shared.settings.fontSize, fontSizeRange.lowerBound), fontSizeRange.upperBound))
    }

    static let terminalFontRange: ClosedRange<Double> = 8...32
    static let markdownFontRange: ClosedRange<Double> = 10...32
    static var terminalFontSize: CGFloat { CGFloat(SettingsStore.shared.settings.terminalFontSize) }

    /// Font của editor: font người dùng đã chọn (nếu còn), không thì font monospace của hệ thống.
    static func codeFont(_ size: CGFloat? = nil) -> UIFont {
        let pt = size ?? fontSize
        if let name = SettingsStore.shared.settings.fontName,
           FontStore.shared.contains(postScriptName: name),
           let f = UIFont(name: name, size: pt) {
            return f
        }
        return .monospacedSystemFont(ofSize: pt, weight: .regular)
    }

    static func style(_ nav: UINavigationController?) {
        guard let nav = nav else { return }
        let t = theme
        nav.overrideUserInterfaceStyle = t.isDark ? .dark : .light
        let ap = UINavigationBarAppearance()
        ap.configureWithOpaqueBackground()
        ap.backgroundColor = t.bg2Color
        ap.shadowColor = t.borderColor
        ap.titleTextAttributes = [.foregroundColor: t.fgColor]
        ap.largeTitleTextAttributes = [.foregroundColor: t.fgColor]
        nav.navigationBar.standardAppearance = ap
        nav.navigationBar.scrollEdgeAppearance = ap
        nav.navigationBar.compactAppearance = ap
        nav.navigationBar.tintColor = t.accentColor
    }
}

extension UIViewController {
    func showError(_ error: Error) {
        let ac = UIAlertController(title: "Lỗi", message: error.localizedDescription, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
    }

    /// Hộp thoại nhập một dòng chữ.
    func promptText(title: String, message: String? = nil, placeholder: String,
                    initial: String = "", confirm: String,
                    onDone: @escaping (String) -> Void) {
        let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
        ac.addTextField { tf in
            tf.placeholder = placeholder
            tf.text = initial
            tf.autocapitalizationType = .none
            tf.autocorrectionType = .no
            tf.clearButtonMode = .whileEditing
        }
        ac.addAction(UIAlertAction(title: "Huỷ", style: .cancel))
        ac.addAction(UIAlertAction(title: confirm, style: .default) { _ in
            let text = (ac.textFields?.first?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            onDone(text)
        })
        present(ac, animated: true)
    }

    func confirmDestructive(title: String, message: String, button: String,
                            onConfirm: @escaping () -> Void) {
        let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "Huỷ", style: .cancel))
        ac.addAction(UIAlertAction(title: button, style: .destructive) { _ in onConfirm() })
        present(ac, animated: true)
    }
}

// MARK: - Danh sách dự án

final class ProjectListViewController: UIViewController {

    private let store = ProjectStore.shared
    private var projects: [String] = []
    private let table = UITableView(frame: .zero, style: .plain)
    private let emptyLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Dự án"

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add, target: self, action: #selector(addTapped))
        updateLeftItems()
        NotificationCenter.default.addObserver(self, selector: #selector(updateLeftItems),
                                               name: .catnipSettingsChanged, object: nil)
        // Quay lại app sau khi sửa trong ứng dụng Tệp: làm mới danh sách dự án.
        NotificationCenter.default.addObserver(self, selector: #selector(refreshAfterForeground),
                                               name: UIApplication.didBecomeActiveNotification, object: nil)

        table.translatesAutoresizingMaskIntoConstraints = false
        table.dataSource = self
        table.delegate = self
        table.rowHeight = 64
        table.register(UITableViewCell.self, forCellReuseIdentifier: "project")
        view.addSubview(table)

        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.text = "Chưa có dự án nào.\nNhấn + để tạo dự án đầu tiên."
        emptyLabel.numberOfLines = 0
        emptyLabel.textAlignment = .center
        emptyLabel.font = .systemFont(ofSize: 15)
        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            table.topAnchor.constraint(equalTo: view.topAnchor),
            table.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            table.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            table.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32)
        ])

        NotificationCenter.default.addObserver(self, selector: #selector(applyTheme),
                                               name: .catnipSettingsChanged, object: nil)
        applyTheme()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = true
        applyTheme()
        reload()
    }

    @objc private func applyTheme() {
        let t = Appearance.theme
        Appearance.style(navigationController)
        view.backgroundColor = t.bgColor
        table.backgroundColor = t.bgColor
        table.separatorColor = t.borderColor
        emptyLabel.textColor = t.mutedColor
        table.reloadData()
    }

    @objc private func refreshAfterForeground() {
        if isViewLoaded, view.window != nil { reload() }
    }

    private func reload() {
        projects = store.listProjects()
        emptyLabel.isHidden = !projects.isEmpty
        table.reloadData()
    }

    // MARK: Actions

    @objc private func settingsTapped() {
        let nav = CatnipNavigationController(rootViewController: SettingsViewController())
        present(nav, animated: true)
    }

    /// Nút bên trái: Cài đặt, "?" (tài liệu) và, nếu đã bật trong Cài đặt, Shell.
    @objc private func updateLeftItems() {
        var items = [
            UIBarButtonItem(image: UIImage(systemName: "gearshape"), style: .plain,
                            target: self, action: #selector(settingsTapped)),
            UIBarButtonItem(image: UIImage(systemName: "questionmark.circle"), style: .plain,
                            target: self, action: #selector(docsTapped))
        ]
        if SettingsStore.shared.settings.shellEnabled {
            items.append(UIBarButtonItem(image: UIImage(systemName: "terminal"), style: .plain,
                                         target: self, action: #selector(shellTapped)))
        }
        navigationItem.leftBarButtonItems = items
    }

    @objc private func docsTapped() { presentDocs() }
    @objc private func shellTapped() { presentShell() }

    @objc private func addTapped() {
        let sheet = UIAlertController(title: "Loại dự án", message: "Chọn loại cho dự án mới", preferredStyle: .actionSheet)
        for kind in ProjectKind.allCases {
            let title = kind.isAvailable ? "\(kind.displayName) — \(kind.summary)"
                                         : "\(kind.displayName) (coming soon)"
            let action = UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.askName(for: kind)
            }
            action.isEnabled = kind.isAvailable
            sheet.addAction(action)
        }
        sheet.addAction(UIAlertAction(title: "Huỷ", style: .cancel))
        sheet.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem
        present(sheet, animated: true)
    }

    private func askName(for kind: ProjectKind) {
        let note = kind == .love ? "Dự án LÖVE sẽ có sẵn main.lua và conf.lua." : "Dự án trống, bạn tự tạo file."
        promptText(title: "Dự án \(kind.displayName) mới", message: note,
                   placeholder: "Tên dự án", confirm: "Tạo") { [weak self] name in
            guard let self = self else { return }
            do {
                let created = try self.store.createProject(name, kind: kind)
                self.reload()
                self.open(created)
            } catch { self.showError(error) }
        }
    }

    private func open(_ project: String) {
        navigationController?.pushViewController(EditorViewController(project: project), animated: true)
    }

    private func rename(_ project: String) {
        promptText(title: "Đổi tên dự án", placeholder: "Tên mới", initial: project, confirm: "Đổi") { [weak self] name in
            guard let self = self, name != project else { return }
            do {
                try self.store.renameProject(project, to: name)
                SettingsStore.shared.update { s in
                    if s.lastProject == project { s.lastProject = name }
                    // expandedFolders lưu dạng "<dự án>::<thư mục>": đổi theo tên mới.
                    s.expandedFolders = s.expandedFolders.map {
                        $0.hasPrefix(project + "::") ? name + "::" + String($0.dropFirst(project.count + 2)) : $0
                    }
                }
                self.reload()
            } catch { self.showError(error) }
        }
    }

    private func delete(_ project: String) {
        confirmDestructive(title: "Xoá \"\(project)\"?",
                           message: "Toàn bộ file trong dự án sẽ bị xoá và không thể khôi phục.",
                           button: "Xoá") { [weak self] in
            guard let self = self else { return }
            do {
                try self.store.deleteProject(project)
                if SettingsStore.shared.settings.lastProject == project {
                    SettingsStore.shared.update { $0.lastProject = nil; $0.lastFile = nil }
                }
                self.reload()
            } catch { self.showError(error) }
        }
    }
}

extension ProjectListViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { projects.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "project", for: indexPath)
        let name = projects[indexPath.row]
        let t = Appearance.theme
        let count = store.tree(project: name, expanded: []).count

        var cfg = UIListContentConfiguration.subtitleCell()
        cfg.text = name
        cfg.textProperties.color = t.fgColor
        cfg.textProperties.font = .systemFont(ofSize: 17, weight: .semibold)
        let kind = store.kind(of: name)
        cfg.secondaryText = "\(kind.displayName) · \(count) mục"
        cfg.secondaryTextProperties.color = t.mutedColor
        cfg.image = UIImage(systemName: kind.symbol)
        cfg.imageProperties.tintColor = t.accentColor
        cell.contentConfiguration = cfg
        cell.backgroundColor = t.bgColor
        let more = UIButton(type: .system)
        more.setImage(UIImage(systemName: "ellipsis.circle"), for: .normal)
        more.tintColor = t.accentColor
        more.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        more.showsMenuAsPrimaryAction = true
        more.menu = UIMenu(children: [
            UIAction(title: "Đổi tên", image: UIImage(systemName: "pencil")) { [weak self] _ in self?.rename(name) },
            UIAction(title: "Xoá", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in self?.delete(name) }
        ])
        cell.accessoryView = more
        let sel = UIView(); sel.backgroundColor = t.hoverColor
        cell.selectedBackgroundView = sel
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        open(projects[indexPath.row])
    }

    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let name = projects[indexPath.row]
        let del = UIContextualAction(style: .destructive, title: "Xoá") { [weak self] _, _, done in
            self?.delete(name); done(true)
        }
        let ren = UIContextualAction(style: .normal, title: "Đổi tên") { [weak self] _, _, done in
            self?.rename(name); done(true)
        }
        ren.backgroundColor = Appearance.theme.accentColor
        return UISwipeActionsConfiguration(actions: [del, ren])
    }
}

// MARK: - Cài đặt (một trang con)

final class SettingsPageViewController: UITableViewController {

    enum Section: Int, CaseIterable {
        case theme, font, size, editing, markdown, screen, shell, cpp

        var title: String {
            switch self {
            case .theme:   return "THEME MÀU"
            case .font:    return "FONT TRONG EDITOR"
            case .size:    return "CỠ CHỮ (2–32 pt)"
            case .editing: return "SOẠN THẢO"
            case .markdown: return "TRÌNH XEM MARKDOWN"
            case .screen:  return "MÀN HÌNH"
            case .shell:   return "SHELL"
            case .cpp:     return "C++"
            }
        }
    }

    /// Mỗi trang con của Cài đặt gom vài nhóm hàng.
    enum Page {
        case appearance, font, editing, markdown, shell, cpp

        var title: String {
            switch self {
            case .appearance: return "Giao diện"
            case .font:       return "Font và cỡ chữ"
            case .editing:    return "Soạn thảo"
            case .markdown:   return "Trình xem Markdown"
            case .shell:      return "Shell và Linux"
            case .cpp:        return "C++"
            }
        }

        var sections: [Section] {
            switch self {
            case .appearance: return [.theme, .screen]
            case .font:       return [.font, .size]
            case .editing:    return [.editing]
            case .markdown:   return [.markdown]
            case .shell:      return [.shell]
            case .cpp:        return [.cpp]
            }
        }
    }

    private let page: Page
    private var shown: [Section] { page.sections }
    private func idx(_ list: [Section]) -> IndexSet { IndexSet(list.compactMap { shown.firstIndex(of: $0) }) }

    private enum ImportKind { case theme, font }

    private let sizeRange = Appearance.fontSizeRange
    private var sizeLabel: UILabel?
    private var previewLabel: UILabel?
    private var importKind: ImportKind = .theme

    init(page: Page) { self.page = page; super.init(style: .insetGrouped) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = page.title
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done, target: self, action: #selector(doneTapped))
        navigationController?.navigationBar.prefersLargeTitles = false
        refreshColors()
    }

    private func refreshColors() {
        Appearance.style(navigationController)
        tableView.backgroundColor = Appearance.theme.bgColor
        tableView.separatorColor = Appearance.theme.borderColor
    }

    @objc private func doneTapped() { dismiss(animated: true) }

    private func settingsChanged() {
        NotificationCenter.default.post(name: .catnipSettingsChanged, object: nil)
    }

    private func fail(_ message: String) {
        let ac = UIAlertController(title: "Không nhập được", message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
    }

    // MARK: Số dòng / số hàng

    private var themes: [Theme] { Theme.all }
    private var fonts: [EditorFontInfo] { FontStore.shared.fonts }

    override func numberOfSections(in tableView: UITableView) -> Int { shown.count }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        shown[section].title
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch shown[section] {
        case .theme:  return "Nhập theme TextMate (.tmTheme). Vuốt trái để sửa hoặc xoá theme."
        case .font:   return "Nhập font .ttf / .otf / .ttc. Font được lưu trong app, vuốt trái để xoá."
        case .editing: return "Kích thước tab: số dấu cách cho mỗi lần bấm phím Tab và mỗi mức thụt lề tự động. Bật \"Thụt lề bằng ký tự Tab\" để dùng ký tự Tab thật. Soát chính tả tô đỏ tiếng/cụm từ tiếng Việt sai trong file .md (bỏ qua code, link và từ tiếng Anh). \"Hiện file/thư mục ẩn\" cho thấy cả file bắt đầu bằng dấu chấm (như .github, .gitignore) trong cây file; .git và .catnip.json luôn được giấu."
        case .markdown: return "\"Theo giao diện app\" dùng sáng/tối theo theme của editor; GitHub Sáng và GitHub Tối cố định kiểu hiển thị."
        case .screen: return "Bật để màn hình và bàn phím luôn ở chiều dọc. Game LÖVE vẫn tự chọn hướng của nó."
        case .cpp:    return "Mặc định nút Chạy dùng Clang++ native (JIT): tải một lần, cần app có quyền JIT. Có thể chuyển sang g++ trong iSH làm dự phòng."
        case .shell:  return "Hiện nút shell ở danh sách dự án và trong menu ⋯ của editor. Mỗi dự án nằm ở /root/<tên dự án> trong shell (khoảng trắng đổi thành _); mở dự án thì shell tự vào thư mục đó. Cài lại bộ công cụ chạy lại apk add bash vim python3 g++ nasm."
        default:      return nil
        }
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        (view as? UITableViewHeaderFooterView)?.textLabel?.textColor = Appearance.theme.mutedColor
    }

    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        (view as? UITableViewHeaderFooterView)?.textLabel?.textColor = Appearance.theme.mutedColor
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch shown[section] {
        case .theme:   return themes.count + 2          // + "Nhập theme…" + "Trình sửa theme…"
        case .font:    return 1 + fonts.count + 1       // mặc định + font đã nhập + "Nhập font…"
        case .size:    return 2                         // bộ chỉnh + dòng xem trước
        case .editing: return 6
        case .markdown: return 4                        // cỡ chữ + 3 kiểu hiển thị
        case .screen:  return 1
        case .shell:   return IshAvailability.isEmbedded ? 4 : 3   // bật shell + cỡ chữ shell + loại shell (+ cài lại bộ công cụ Linux)
        case .cpp:     return 2
        }
    }

    private func stepperCell(_ cell: UITableViewCell, text: String, value: Double, range: ClosedRange<Double>,
                             format: @escaping (Double) -> String, onChange: @escaping (Double) -> Void) {
        cell.selectionStyle = .none
        cell.textLabel?.text = text + ": " + format(value)
        let stepper = UIStepper()
        stepper.minimumValue = range.lowerBound
        stepper.maximumValue = range.upperBound
        stepper.stepValue = 1
        stepper.value = value
        weak var label = cell.textLabel
        stepper.addAction(UIAction { action in
            guard let st = action.sender as? UIStepper else { return }
            label?.text = text + ": " + format(st.value)
            onChange(st.value)
        }, for: .valueChanged)
        cell.accessoryView = stepper
    }

    private func switchCell(_ cell: UITableViewCell, text: String, isOn: Bool,
                            onChange: @escaping (Bool) -> Void) {
        cell.textLabel?.text = text
        cell.selectionStyle = .none
        let sw = UISwitch()
        sw.isOn = isOn
        sw.onTintColor = Appearance.theme.accentColor
        sw.addAction(UIAction { _ in onChange(sw.isOn) }, for: .valueChanged)
        cell.accessoryView = sw
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let t = Appearance.theme
        let st = SettingsStore.shared.settings
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.backgroundColor = t.bg2Color
        cell.textLabel?.textColor = t.fgColor
        cell.textLabel?.font = .systemFont(ofSize: 16)
        cell.selectionStyle = .default
        let sel = UIView(); sel.backgroundColor = t.hoverColor
        cell.selectedBackgroundView = sel

        func importRow(_ title: String) {
            cell.textLabel?.text = title
            cell.textLabel?.textColor = t.accentColor
            cell.imageView?.image = UIImage(systemName: "square.and.arrow.down")
            cell.imageView?.tintColor = t.accentColor
        }

        switch shown[indexPath.section] {
        case .theme:
            if indexPath.row == themes.count {
                importRow("Nhập theme (.tmTheme)…")
            } else if indexPath.row == themes.count + 1 {
                cell.textLabel?.text = "Trình sửa theme (tạo / sửa màu)…"
                cell.textLabel?.textColor = t.accentColor
                cell.imageView?.image = UIImage(systemName: "paintpalette")
                cell.imageView?.tintColor = t.accentColor
            } else {
                let item = themes[indexPath.row]
                cell.textLabel?.text = item.name + (item.isCustom ? "  · đã nhập" : "")
                cell.accessoryType = (item.id == t.id) ? .checkmark : .none
            }

        case .font:
            if indexPath.row == 0 {
                cell.textLabel?.text = "Mặc định (monospace hệ thống)"
                cell.accessoryType = (st.fontName == nil) ? .checkmark : .none
            } else if indexPath.row <= fonts.count {
                let f = fonts[indexPath.row - 1]
                cell.textLabel?.text = f.displayName
                cell.textLabel?.font = UIFont(name: f.postScriptName, size: 16) ?? .systemFont(ofSize: 16)
                cell.accessoryType = (st.fontName == f.postScriptName) ? .checkmark : .none
            } else {
                importRow("Nhập font (.ttf, .otf)…")
            }

        case .size:
            cell.selectionStyle = .none
            if indexPath.row == 0 {
                cell.textLabel?.text = "\(Int(Appearance.fontSize)) pt"
                sizeLabel = cell.textLabel
                let stepper = UIStepper()
                stepper.minimumValue = sizeRange.lowerBound
                stepper.maximumValue = sizeRange.upperBound
                stepper.stepValue = 1
                stepper.value = Double(Appearance.fontSize)
                stepper.addTarget(self, action: #selector(stepperChanged(_:)), for: .valueChanged)
                cell.accessoryView = stepper
            } else {
                cell.textLabel?.text = "local x = love.graphics.getWidth()"
                cell.textLabel?.font = Appearance.codeFont()
                cell.textLabel?.textColor = t.tokenColor(.keyword)
                previewLabel = cell.textLabel
            }

        case .editing:
            if indexPath.row == 0 {
                switchCell(cell, text: "Hiện số dòng", isOn: st.showLineNumbers) { [weak self] on in
                    SettingsStore.shared.update { $0.showLineNumbers = on }
                    self?.settingsChanged()
                }
            } else if indexPath.row == 1 {
                switchCell(cell, text: "Cuộn ngang (không ngắt dòng)", isOn: st.scrollHorizontal) { [weak self] on in
                    SettingsStore.shared.update { $0.scrollHorizontal = on }
                    self?.settingsChanged()
                }
            } else if indexPath.row == 2 {
                stepperCell(cell, text: "Kích thước tab", value: Double(st.tabWidth), range: 1...8,
                            format: { "\(Int($0)) dấu cách" }) { [weak self] v in
                    SettingsStore.shared.update { $0.tabWidth = Int(v) }
                    self?.settingsChanged()
                }
            } else if indexPath.row == 3 {
                switchCell(cell, text: "Thụt lề bằng ký tự Tab", isOn: st.useTabs) { [weak self] on in
                    SettingsStore.shared.update { $0.useTabs = on }
                    self?.settingsChanged()
                }
            } else if indexPath.row == 5 {
                switchCell(cell, text: "Hiện file/thư mục ẩn", isOn: st.showHiddenFiles) { [weak self] on in
                    SettingsStore.shared.update { $0.showHiddenFiles = on }
                    self?.settingsChanged()
                }
            } else {
                switchCell(cell, text: "Soát chính tả Markdown", isOn: st.spellCheckMarkdown) { [weak self] on in
                    SettingsStore.shared.update { $0.spellCheckMarkdown = on }
                    self?.settingsChanged()
                }
            }

        case .markdown:
            if indexPath.row == 0 {
                stepperCell(cell, text: "Cỡ chữ", value: st.markdownFontSize, range: Appearance.markdownFontRange,
                            format: { "\(Int($0)) px" }) { [weak self] v in
                    SettingsStore.shared.update { $0.markdownFontSize = v }
                    self?.settingsChanged()
                }
            } else {
                let options = [("auto", "Theo giao diện app"), ("githubLight", "GitHub Sáng"), ("githubDark", "GitHub Tối")]
                let (key, title) = options[indexPath.row - 1]
                cell.textLabel?.text = title
                cell.accessoryType = (st.markdownTheme == key) ? .checkmark : .none
            }

        case .screen:
            switchCell(cell, text: "Khoá chiều dọc", isOn: st.lockPortrait) { [weak self] on in
                SettingsStore.shared.update { $0.lockPortrait = on }
                OrientationPolicy.refresh()
                self?.settingsChanged()
            }

        case .shell:
            if indexPath.row == 0 {
                switchCell(cell, text: "Cửa sổ shell", isOn: st.shellEnabled) { [weak self] on in
                    SettingsStore.shared.update { $0.shellEnabled = on }
                    self?.settingsChanged()
                }
            } else if indexPath.row == 1 {
                stepperCell(cell, text: "Cỡ chữ shell", value: st.terminalFontSize, range: Appearance.terminalFontRange,
                            format: { "\(Int($0)) pt" }) { [weak self] v in
                    SettingsStore.shared.update { $0.terminalFontSize = v }
                    self?.settingsChanged()
                }
            } else if indexPath.row == 2 {
                let sc = ShellChoice.current
                cell.textLabel?.text = "Loại shell: " + sc.displayName
                cell.imageView?.image = UIImage(systemName: "terminal")
                cell.imageView?.tintColor = t.accentColor
                cell.accessoryType = .disclosureIndicator
            } else {
                cell.textLabel?.text = "Cài lại bộ công cụ Linux…"
                cell.textLabel?.textColor = t.accentColor
                cell.imageView?.image = UIImage(systemName: "arrow.down.circle")
                cell.imageView?.tintColor = t.accentColor
            }

        case .cpp where indexPath.row == 0:
            cell.textLabel?.text = "Chạy bằng: " + (SettingsStore.shared.settings.cppEngine == "gpp" ? "g++ trong iSH (dự phòng)" : "Clang++ native (JIT)")
            cell.imageView?.image = UIImage(systemName: "play.rectangle")
            cell.imageView?.tintColor = t.accentColor
            cell.accessoryType = .disclosureIndicator
        case .cpp:
            cell.textLabel?.text = "Clang++: " + (ClangToolchain.isInstalled ? "đã cài (chạm để cài lại/gỡ)" : "chưa cài (chạm để tải)")
            cell.imageView?.image = UIImage(systemName: "hammer")
            cell.imageView?.tintColor = t.accentColor
            cell.accessoryType = .disclosureIndicator
        }
        return cell
    }

    // MARK: Chọn / nhập

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch shown[indexPath.section] {
        case .theme:
            if indexPath.row == themes.count {
                presentImporter(.theme)
            } else if indexPath.row == themes.count + 1 {
                presentThemeEditor(Appearance.theme)
            } else {
                let chosen = themes[indexPath.row]
                SettingsStore.shared.update { $0.themeName = chosen.id }
                refreshColors()
                tableView.reloadData()
                settingsChanged()
            }
        case .font:
            if indexPath.row == 0 {
                SettingsStore.shared.update { $0.fontName = nil }
                tableView.reloadSections(idx([.font, .size]), with: .none)
                settingsChanged()
            } else if indexPath.row <= fonts.count {
                let f = fonts[indexPath.row - 1]
                SettingsStore.shared.update { $0.fontName = f.postScriptName }
                tableView.reloadSections(idx([.font, .size]), with: .none)
                settingsChanged()
            } else {
                presentImporter(.font)
            }
        case .shell where indexPath.row == 2:
            chooseShell(from: tableView.cellForRow(at: indexPath))
        case .shell where indexPath.row == 3:
            presentIshSetup()
        case .cpp where indexPath.row == 0:
            let sheet = UIAlertController(title: "Chạy C++ bằng", message: "Clang++ chạy native bằng JIT (mặc định, đang hoàn thiện). g++ trong iSH là phương án dự phòng, chạy giả lập.", preferredStyle: .actionSheet)
            for (title, key) in [("Clang++ native (JIT)", "clang"), ("g++ trong iSH (dự phòng)", "gpp")] {
                sheet.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                    SettingsStore.shared.update { $0.cppEngine = key }
                    self?.tableView.reloadSections(self?.idx([.cpp]) ?? [], with: .none)
                })
            }
            sheet.addAction(UIAlertAction(title: "Huỷ", style: .cancel))
            sheet.popoverPresentationController?.sourceView = tableView.cellForRow(at: indexPath)
            present(sheet, animated: true)
        case .cpp:
            let setup = ClangSetupViewController()
            setup.modalPresentationStyle = .fullScreen
            setup.onFinish = { [weak self, weak setup] in
                setup?.dismiss(animated: true)
                self?.tableView.reloadSections(self?.idx([.cpp]) ?? [], with: .none)
            }
            present(setup, animated: true)
        case .markdown where indexPath.row >= 1:
            let keys = ["auto", "githubLight", "githubDark"]
            SettingsStore.shared.update { $0.markdownTheme = keys[indexPath.row - 1] }
            tableView.reloadSections(idx([.markdown]), with: .none)
            settingsChanged()
        default:
            break
        }
    }

    private func chooseShell(from source: UIView?) {
        let sheet = UIAlertController(title: "Loại shell", message: IshAvailability.isEmbedded ? nil : "Bản build này không nhúng iSH nên chỉ có Catnip Shell.", preferredStyle: .actionSheet)
        func set(_ kind: String) {
            SettingsStore.shared.update { $0.shellKind = kind }
            #if CATNIP_HAS_ISH
            IshRuntime.shared.restartSession()
            #endif
            tableView.reloadSections(idx([.shell, .cpp]), with: .none)
            settingsChanged()
        }
        sheet.addAction(UIAlertAction(title: "Catnip Shell (dựng sẵn, nhẹ)", style: .default) { _ in set("catnip") })
        if IshAvailability.isEmbedded {
            sheet.addAction(UIAlertAction(title: "iSH (Linux thật)", style: .default) { _ in set("ish") })
            sheet.addAction(UIAlertAction(title: "Tuỳ chỉnh (lệnh chạy trong iSH)…", style: .default) { [weak self] _ in
                let a = UIAlertController(title: "Shell tuỳ chỉnh", message: "Lệnh chạy trong iSH thay cho shell mặc định, ví dụ /bin/bash -l hoặc /usr/bin/python3.", preferredStyle: .alert)
                a.addTextField { tf in
                    tf.text = SettingsStore.shared.settings.customShell
                    tf.placeholder = "/bin/bash -l"
                    tf.autocapitalizationType = .none
                    tf.autocorrectionType = .no
                }
                a.addAction(UIAlertAction(title: "Lưu", style: .default) { [weak a] _ in
                    let cmd = (a?.textFields?.first?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    SettingsStore.shared.update { $0.customShell = cmd }
                    set(cmd.isEmpty ? "ish" : "custom")
                })
                a.addAction(UIAlertAction(title: "Huỷ", style: .cancel))
                self?.present(a, animated: true)
            })
        }
        sheet.addAction(UIAlertAction(title: "Huỷ", style: .cancel))
        sheet.popoverPresentationController?.sourceView = source ?? view
        present(sheet, animated: true)
    }

    private func presentThemeEditor(_ theme: Theme) {
        let ed = ThemeEditorViewController(theme: theme)
        ed.onSaved = { [weak self] _ in
            self?.refreshColors()
            self?.tableView.reloadData()
            self?.settingsChanged()
        }
        let nav = UINavigationController(rootViewController: ed)
        present(nav, animated: true)
    }

    private func presentImporter(_ kind: ImportKind) {
        importKind = kind
        // .tmTheme không có kiểu hệ thống riêng nên cho chọn mọi file rồi tự kiểm tra nội dung.
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        picker.allowsMultipleSelection = false
        picker.delegate = self
        present(picker, animated: true)
    }

    // MARK: Xoá theme / font đã nhập

    override func tableView(_ tableView: UITableView,
                            trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        func deleteAction(_ run: @escaping () -> Void) -> UISwipeActionsConfiguration {
            let a = UIContextualAction(style: .destructive, title: "Xoá") { _, _, done in run(); done(true) }
            return UISwipeActionsConfiguration(actions: [a])
        }
        switch shown[indexPath.section] {
        case .theme where indexPath.row < themes.count && !themes[indexPath.row].isCustom:
            let target = themes[indexPath.row]
            let edit = UIContextualAction(style: .normal, title: "Sửa") { [weak self] _, _, done in
                self?.presentThemeEditor(target); done(true)
            }
            edit.backgroundColor = .systemBlue
            return UISwipeActionsConfiguration(actions: [edit])
        case .theme where indexPath.row < themes.count && themes[indexPath.row].isCustom:
            let target = themes[indexPath.row]
            let edit = UIContextualAction(style: .normal, title: "Sửa") { [weak self] _, _, done in
                self?.presentThemeEditor(target); done(true)
            }
            edit.backgroundColor = .systemBlue
            let del = deleteAction { [weak self] in
                ThemeStore.shared.delete(target)
                if SettingsStore.shared.settings.themeName == target.id {
                    SettingsStore.shared.update { $0.themeName = "dark" }
                }
                self?.refreshColors()
                self?.tableView.reloadData()
                self?.settingsChanged()
            }
            return UISwipeActionsConfiguration(actions: del.actions + [edit])
        case .font where indexPath.row >= 1 && indexPath.row <= fonts.count:
            let target = fonts[indexPath.row - 1]
            return deleteAction { [weak self] in
                FontStore.shared.delete(target)
                let still = SettingsStore.shared.settings.fontName.map { FontStore.shared.contains(postScriptName: $0) } ?? true
                if !still { SettingsStore.shared.update { $0.fontName = nil } }
                self?.tableView.reloadData()
                self?.settingsChanged()
            }
        default:
            return nil
        }
    }

    @objc private func stepperChanged(_ s: UIStepper) {
        SettingsStore.shared.update { $0.fontSize = s.value }
        sizeLabel?.text = "\(Int(s.value)) pt"
        previewLabel?.font = Appearance.codeFont()
        settingsChanged()
    }
}

// MARK: - Cài đặt (trang gốc: danh sách mục)

final class SettingsViewController: UITableViewController {

    private struct Row {
        let title: String
        let symbol: String
        let summary: () -> String
        let open: (UINavigationController?) -> Void
    }

    private var rows: [Row] = []

    init() { super.init(style: .insetGrouped) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Cài đặt"
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneTapped))
        func page(_ p: SettingsPageViewController.Page) -> (UINavigationController?) -> Void {
            { nav in nav?.pushViewController(SettingsPageViewController(page: p), animated: true) }
        }
        rows = [
            Row(title: "Giao diện", symbol: "paintbrush", summary: { Appearance.theme.name }, open: page(.appearance)),
            Row(title: "Font và cỡ chữ", symbol: "textformat.size", summary: {
                let name = SettingsStore.shared.settings.fontName.flatMap { n in FontStore.shared.fonts.first { $0.postScriptName == n }?.displayName } ?? "Mặc định"
                return "\(name) · \(Int(Appearance.fontSize)) pt"
            }, open: page(.font)),
            Row(title: "Soạn thảo", symbol: "pencil.and.outline", summary: {
                let st = SettingsStore.shared.settings
                return "Tab \(st.tabWidth)" + (st.scrollHorizontal ? " · cuộn ngang" : " · ngắt dòng")
            }, open: page(.editing)),
            Row(title: "Trình xem Markdown", symbol: "doc.richtext", summary: { "\(Int(SettingsStore.shared.settings.markdownFontSize)) px" }, open: page(.markdown)),
            Row(title: "Shell và Linux", symbol: "terminal", summary: {
                (SettingsStore.shared.settings.shellEnabled ? "Bật · " : "Tắt · ") + ShellChoice.current.displayName
            }, open: page(.shell)),
            Row(title: "C++ (Clang++)", symbol: "hammer", summary: { ClangToolchain.isInstalled ? "Đã cài" : "Chưa cài" }, open: page(.cpp)),
            Row(title: "C2o (.2o)", symbol: "shippingbox", summary: {
                let n = TwooLibraries.installed.count
                return n == 0 ? "Thư viện nhúng sẵn" : "\(n) thư viện đã tải"
            }, open: { nav in TwooLibraries.presentManager(from: nav?.topViewController) }),
            Row(title: "Định cú pháp (TextMate)", symbol: "chevron.left.forwardslash.chevron.right", summary: {
                let n = GrammarStore.shared.grammars.count
                return n == 0 ? "Chưa nhập" : "\(n) ngôn ngữ"
            }, open: { nav in nav?.pushViewController(GrammarsViewController(), animated: true) }),
        ]
        refreshColors()
        NotificationCenter.default.addObserver(self, selector: #selector(refreshAll), name: .catnipSettingsChanged, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshAll()
    }

    @objc private func refreshAll() {
        refreshColors()
        tableView.reloadData()
    }

    private func refreshColors() {
        Appearance.style(navigationController)
        tableView.backgroundColor = Appearance.theme.bgColor
        tableView.separatorColor = Appearance.theme.borderColor
    }

    @objc private func doneTapped() { dismiss(animated: true) }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { rows.count }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let t = Appearance.theme
        let r = rows[indexPath.row]
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.backgroundColor = t.bg2Color
        cell.textLabel?.text = r.title
        cell.textLabel?.textColor = t.fgColor
        cell.textLabel?.font = .systemFont(ofSize: 16)
        cell.detailTextLabel?.text = r.summary()
        cell.detailTextLabel?.textColor = t.mutedColor
        cell.imageView?.image = UIImage(systemName: r.symbol)
        cell.imageView?.tintColor = t.accentColor
        cell.accessoryType = .disclosureIndicator
        let sel = UIView(); sel.backgroundColor = t.hoverColor
        cell.selectedBackgroundView = sel
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        rows[indexPath.row].open(navigationController)
    }
}

// MARK: - Nhận file nhập vào

extension SettingsPageViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        do {
            switch importKind {
            case .theme:
                let theme = try ThemeStore.shared.importTheme(from: url)
                SettingsStore.shared.update { $0.themeName = theme.id }   // dùng luôn theme vừa nhập
                refreshColors()
            case .font:
                let font = try FontStore.shared.importFont(from: url)
                SettingsStore.shared.update { $0.fontName = font.postScriptName }
            }
            tableView.reloadData()
            settingsChanged()
        } catch {
            fail(error.localizedDescription)
        }
    }
}
