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
    static var fontSize: CGFloat { CGFloat(SettingsStore.shared.settings.fontSize) }

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
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "gearshape"), style: .plain,
            target: self, action: #selector(settingsTapped))

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

    private func reload() {
        projects = store.listProjects()
        emptyLabel.isHidden = !projects.isEmpty
        table.reloadData()
    }

    // MARK: Actions

    @objc private func settingsTapped() {
        let nav = UINavigationController(rootViewController: SettingsViewController())
        present(nav, animated: true)
    }

    @objc private func addTapped() {
        promptText(title: "Dự án mới", message: "Một dự án LÖVE sẽ được tạo sẵn main.lua và conf.lua.",
                   placeholder: "Tên dự án", confirm: "Tạo") { [weak self] name in
            guard let self = self else { return }
            do {
                let created = try self.store.createProject(name)
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
                if SettingsStore.shared.settings.lastProject == project {
                    SettingsStore.shared.update { $0.lastProject = name }
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
        cfg.secondaryText = "\(count) mục"
        cfg.secondaryTextProperties.color = t.mutedColor
        cfg.image = UIImage(systemName: "gamecontroller.fill")
        cfg.imageProperties.tintColor = t.accentColor
        cell.contentConfiguration = cfg
        cell.backgroundColor = t.bgColor
        cell.accessoryType = .disclosureIndicator
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

// MARK: - Cài đặt

final class SettingsViewController: UITableViewController {

    private let sizeRange: ClosedRange<Double> = 10...24
    private var sizeLabel: UILabel?
    private var previewLabel: UILabel?

    init() { super.init(style: .insetGrouped) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Cài đặt"
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

    override func numberOfSections(in tableView: UITableView) -> Int { 3 }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        ["GIAO DIỆN", "CỠ CHỮ TRONG EDITOR", "SOẠN THẢO"][section]
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        (view as? UITableViewHeaderFooterView)?.textLabel?.textColor = Appearance.theme.mutedColor
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        [Theme.all.count, 2, 2][section]
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let t = Appearance.theme
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.backgroundColor = t.bg2Color
        cell.textLabel?.textColor = t.fgColor
        cell.selectionStyle = indexPath.section == 0 ? .default : .none

        if indexPath.section == 0 {
            let item = Theme.all[indexPath.row]
            cell.textLabel?.text = item.name
            cell.accessoryType = (item.id == t.id) ? .checkmark : .none
        } else if indexPath.section == 2 {
            let st = SettingsStore.shared.settings
            let isNumbers = indexPath.row == 0
            cell.textLabel?.text = isNumbers ? "Hiện số dòng" : "Tự xuống dòng"
            let sw = UISwitch()
            sw.isOn = isNumbers ? st.showLineNumbers : st.wrapLines
            sw.onTintColor = t.accentColor
            sw.addAction(UIAction { [weak self] _ in
                SettingsStore.shared.update {
                    if isNumbers { $0.showLineNumbers = sw.isOn } else { $0.wrapLines = sw.isOn }
                }
                self?.settingsChanged()
            }, for: .valueChanged)
            cell.accessoryView = sw
        } else if indexPath.row == 0 {
            let size = SettingsStore.shared.settings.fontSize
            cell.textLabel?.text = "\(Int(size)) pt"
            sizeLabel = cell.textLabel
            let stepper = UIStepper()
            stepper.minimumValue = sizeRange.lowerBound
            stepper.maximumValue = sizeRange.upperBound
            stepper.stepValue = 1
            stepper.value = size
            stepper.addTarget(self, action: #selector(stepperChanged(_:)), for: .valueChanged)
            cell.accessoryView = stepper
        } else {
            cell.textLabel?.text = "local x = love.graphics.getWidth()"
            cell.textLabel?.font = .monospacedSystemFont(ofSize: Appearance.fontSize, weight: .regular)
            cell.textLabel?.textColor = t.tokenColor(.keyword)
            previewLabel = cell.textLabel
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section == 0 else { return }
        let chosen = Theme.all[indexPath.row]
        SettingsStore.shared.update { $0.themeName = chosen.id }
        refreshColors()
        tableView.reloadData()
        settingsChanged()
    }

    @objc private func stepperChanged(_ s: UIStepper) {
        SettingsStore.shared.update { $0.fontSize = s.value }
        sizeLabel?.text = "\(Int(s.value)) pt"
        previewLabel?.font = .monospacedSystemFont(ofSize: CGFloat(s.value), weight: .regular)
        settingsChanged()
    }
}
