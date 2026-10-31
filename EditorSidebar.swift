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
import UniformTypeIdentifiers

extension EditorViewController {

    // MARK: Trạng thái mở/đóng thư mục (lưu trong settings.json, theo từng dự án)

    func loadExpanded() {
        let prefix = project + "::"
        expanded = Set(SettingsStore.shared.settings.expandedFolders
            .filter { $0.hasPrefix(prefix) }
            .map { String($0.dropFirst(prefix.count)) })
    }

    func saveExpanded() {
        let prefix = project + "::"
        let mine = expanded.map { prefix + $0 }
        SettingsStore.shared.update { s in
            s.expandedFolders = s.expandedFolders.filter { !$0.hasPrefix(prefix) } + mine
        }
    }

    func reloadTree() {
        entries = store.tree(project: project, expanded: expanded)
        fileTable.reloadData()
    }

    /// Mở các thư mục cha của một đường dẫn để file mới tạo hiện ra trong cây.
    func revealParents(of path: String) {
        let parts = path.split(separator: "/").map(String.init)
        var prefix = ""
        for part in parts.dropLast() {
            prefix += (prefix.isEmpty ? "" : "/") + part
            expanded.insert(prefix)
        }
        saveExpanded()
    }

    // MARK: Build

    func buildSidebar() {
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        backdrop.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        backdrop.alpha = 0
        backdrop.isHidden = true
        backdrop.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(closeSidebar)))
        view.addSubview(backdrop)

        sidebar.translatesAutoresizingMaskIntoConstraints = false
        sidebar.isHidden = true
        view.addSubview(sidebar)

        sidebarHeader.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(sidebarHeader)

        sidebarTitle.translatesAutoresizingMaskIntoConstraints = false
        sidebarTitle.text = "FILE · " + project.uppercased()
        sidebarTitle.font = .systemFont(ofSize: 11, weight: .bold)
        sidebarTitle.lineBreakMode = .byTruncatingTail
        sidebarHeader.addSubview(sidebarTitle)

        let newFile = headerButton("doc.badge.plus") { [weak self] in self?.newFilePrompt(in: nil) }
        let newFolder = headerButton("folder.badge.plus") { [weak self] in self?.newFolderPrompt(in: nil) }
        let importBtn = headerButton("square.and.arrow.down.on.square") { [weak self] in self?.importFiles(into: nil) }
        sidebarHeader.addSubview(importBtn)
        sidebarHeader.addSubview(newFile)
        sidebarHeader.addSubview(newFolder)

        fileTable.translatesAutoresizingMaskIntoConstraints = false
        fileTable.separatorStyle = .none
        fileTable.rowHeight = 40
        fileTable.dataSource = self
        fileTable.delegate = self
        fileTable.register(UITableViewCell.self, forCellReuseIdentifier: "entry")
        sidebar.addSubview(fileTable)

        sidebarLeading = sidebar.leadingAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: -(sidebarWidth + 100))

        NSLayoutConstraint.activate([
            backdrop.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            backdrop.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backdrop.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            sidebarLeading,
            sidebar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            sidebar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sidebar.widthAnchor.constraint(equalToConstant: sidebarWidth),

            sidebarHeader.topAnchor.constraint(equalTo: sidebar.topAnchor),
            sidebarHeader.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor),
            sidebarHeader.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            sidebarHeader.heightAnchor.constraint(equalToConstant: 44),

            sidebarTitle.leadingAnchor.constraint(equalTo: sidebarHeader.leadingAnchor, constant: 14),
            sidebarTitle.centerYAnchor.constraint(equalTo: sidebarHeader.centerYAnchor),
            sidebarTitle.trailingAnchor.constraint(lessThanOrEqualTo: importBtn.leadingAnchor, constant: -8),

            newFolder.trailingAnchor.constraint(equalTo: sidebarHeader.trailingAnchor, constant: -6),
            newFolder.centerYAnchor.constraint(equalTo: sidebarHeader.centerYAnchor),
            newFile.trailingAnchor.constraint(equalTo: newFolder.leadingAnchor),
            newFile.centerYAnchor.constraint(equalTo: sidebarHeader.centerYAnchor),
            importBtn.trailingAnchor.constraint(equalTo: newFile.leadingAnchor),
            importBtn.centerYAnchor.constraint(equalTo: sidebarHeader.centerYAnchor),

            fileTable.topAnchor.constraint(equalTo: sidebarHeader.bottomAnchor),
            fileTable.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor),
            fileTable.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            fileTable.bottomAnchor.constraint(equalTo: sidebar.bottomAnchor)
        ])
    }

    private func headerButton(_ symbol: String, action: @escaping () -> Void) -> UIButton {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setImage(UIImage(systemName: symbol), for: .normal)
        b.addAction(UIAction { _ in action() }, for: .touchUpInside)
        b.widthAnchor.constraint(equalToConstant: 40).isActive = true
        b.heightAnchor.constraint(equalToConstant: 40).isActive = true
        return b
    }

    // MARK: Mở / đóng

    @objc func toggleSidebar() {
        if isSidebarOpen { closeSidebar() } else { openSidebar() }
    }

    func openSidebar() {
        guard !isSidebarOpen else { return }
        isSidebarOpen = true
        textView.resignFirstResponder()
        reloadTree()
        sidebar.isHidden = false
        backdrop.isHidden = false
        view.layoutIfNeeded()
        sidebarLeading.constant = 0
        UIView.animate(withDuration: 0.22, delay: 0, options: .curveEaseOut) {
            self.backdrop.alpha = 1
            self.view.layoutIfNeeded()
        }
    }

    @objc func closeSidebar() {
        guard isSidebarOpen else { return }
        isSidebarOpen = false
        sidebarLeading.constant = -(sidebarWidth + 100)
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseIn, animations: {
            self.backdrop.alpha = 0
            self.view.layoutIfNeeded()
        }, completion: { _ in
            if !self.isSidebarOpen {
                self.backdrop.isHidden = true
                self.sidebar.isHidden = true
            }
        })
    }

    // MARK: Nhập file từ bên ngoài (assets, âm thanh, font...)

    func importFiles(into folder: String?) {
        importFolder = folder
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = self
        present(picker, animated: true)
    }

    // MARK: Thao tác với file / thư mục

    func newFilePrompt(in folder: String?) {
        let prefix = folder.map { $0 + "/" } ?? ""
        promptText(title: "File mới",
                   message: "Có thể kèm thư mục, ví dụ src/player.lua",
                   placeholder: "main.lua", initial: prefix, confirm: "Tạo") { [weak self] path in
            guard let self = self else { return }
            do {
                try self.store.createFile(project: self.project, path: path)
                self.revealParents(of: path)
                self.reloadTree()
                self.openFile(path)
                self.closeSidebar()
            } catch { self.showError(error) }
        }
    }

    func newFolderPrompt(in folder: String?) {
        let prefix = folder.map { $0 + "/" } ?? ""
        promptText(title: "Thư mục mới", placeholder: "assets", initial: prefix, confirm: "Tạo") { [weak self] path in
            guard let self = self else { return }
            do {
                try self.store.createFolder(project: self.project, path: path)
                self.revealParents(of: path)
                self.expanded.insert(path)
                self.saveExpanded()
                self.reloadTree()
            } catch { self.showError(error) }
        }
    }

    private func remap(_ p: String, from old: String, to new: String) -> String {
        if p == old { return new }
        if p.hasPrefix(old + "/") { return new + String(p.dropFirst(old.count)) }
        return p
    }

    func renameEntry(_ e: FileEntry) {
        promptText(title: e.isFolder ? "Đổi tên thư mục" : "Đổi tên file",
                   message: "Nhập đường dẫn mới trong dự án",
                   placeholder: "Tên mới", initial: e.path, confirm: "Đổi") { [weak self] newPath in
            guard let self = self, newPath != e.path else { return }
            self.flushSave()
            do {
                try self.store.rename(project: self.project, from: e.path, to: newPath)
                self.expanded = Set(self.expanded.map { self.remap($0, from: e.path, to: newPath) })
                var reopen: String?
                if let cur = self.currentPath {
                    let mapped = self.remap(cur, from: e.path, to: newPath)
                    if mapped != cur { reopen = mapped }
                }
                self.revealParents(of: newPath)
                self.reloadTree()
                if let r = reopen { self.openFile(r) }
            } catch { self.showError(error) }
        }
    }

    func deleteEntry(_ e: FileEntry) {
        confirmDestructive(
            title: "Xoá \"\(e.name)\"?",
            message: e.isFolder ? "Thư mục và mọi file bên trong sẽ bị xoá." : "File sẽ bị xoá và không thể khôi phục.",
            button: "Xoá") { [weak self] in
            guard let self = self else { return }
            self.flushSave()
            do {
                try self.store.delete(project: self.project, path: e.path)
            } catch { self.showError(error); return }

            self.expanded = self.expanded.filter { $0 != e.path && !$0.hasPrefix(e.path + "/") }
            self.saveExpanded()

            if let cur = self.currentPath, cur == e.path || cur.hasPrefix(e.path + "/") {
                self.isDirty = false   // tránh flushSave ghi lại file vừa xoá
                if let next = self.allFilePaths().first { self.openFile(next) } else { self.showNoFile() }
            }
            self.reloadTree()
        }
    }
}

// MARK: - Bảng cây file

extension EditorViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { entries.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "entry", for: indexPath)
        let e = entries[indexPath.row]
        let t = Appearance.theme
        let isCurrent = !e.isFolder && e.path == currentPath

        var cfg = UIListContentConfiguration.cell()
        cfg.text = e.name
        cfg.textProperties.font = .systemFont(ofSize: 14, weight: isCurrent ? .semibold : .regular)
        cfg.textProperties.color = isCurrent ? t.accentColor : t.fgColor
        cfg.textProperties.numberOfLines = 1
        cfg.directionalLayoutMargins.leading = 14 + CGFloat(e.depth) * 16

        let symbol: String
        if e.isFolder { symbol = expanded.contains(e.path) ? "folder.fill" : "folder" }
        else { symbol = Self.symbol(forFile: e.name) }
        cfg.image = UIImage(systemName: symbol)
        cfg.imageProperties.tintColor = e.isFolder ? t.accentColor : t.mutedColor
        cfg.imageToTextPadding = 8

        cell.contentConfiguration = cfg
        cell.backgroundColor = isCurrent ? t.hoverColor : t.bg2Color
        let sel = UIView(); sel.backgroundColor = t.hoverColor
        cell.selectedBackgroundView = sel
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let e = entries[indexPath.row]
        if e.isFolder {
            if expanded.contains(e.path) { expanded.remove(e.path) } else { expanded.insert(e.path) }
            saveExpanded()
            reloadTree()
        } else {
            openFile(e.path)
            closeSidebar()
        }
    }

    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let e = entries[indexPath.row]
        let del = UIContextualAction(style: .destructive, title: "Xoá") { [weak self] _, _, done in
            self?.deleteEntry(e); done(true)
        }
        let ren = UIContextualAction(style: .normal, title: "Đổi tên") { [weak self] _, _, done in
            self?.renameEntry(e); done(true)
        }
        ren.backgroundColor = Appearance.theme.accentColor
        return UISwipeActionsConfiguration(actions: [del, ren])
    }

    func tableView(_ tableView: UITableView,
                   contextMenuConfigurationForRowAt indexPath: IndexPath,
                   point: CGPoint) -> UIContextMenuConfiguration? {
        let e = entries[indexPath.row]
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            var items: [UIMenuElement] = []
            if e.isFolder {
                items.append(UIAction(title: "File mới trong thư mục", image: UIImage(systemName: "doc.badge.plus")) { _ in
                    self?.newFilePrompt(in: e.path)
                })
                items.append(UIAction(title: "Thư mục con mới", image: UIImage(systemName: "folder.badge.plus")) { _ in
                    self?.newFolderPrompt(in: e.path)
                })
                items.append(UIAction(title: "Nhập file vào đây", image: UIImage(systemName: "square.and.arrow.down")) { _ in
                    self?.importFiles(into: e.path)
                })
            }
            items.append(UIAction(title: "Đổi tên", image: UIImage(systemName: "pencil")) { _ in
                self?.renameEntry(e)
            })
            items.append(UIAction(title: "Xoá", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
                self?.deleteEntry(e)
            })
            return UIMenu(children: items)
        }
    }
}

// MARK: - Biểu tượng theo loại file

extension EditorViewController {
    static func symbol(forFile name: String) -> String {
        switch (name as NSString).pathExtension.lowercased() {
        case "png","jpg","jpeg","gif","bmp","tga","webp","ico","dds","hdr": return "photo"
        case "wav","mp3","ogg","oga","flac","m4a","aac":                   return "music.note"
        case "mod","xm","it","s3m":                                        return "music.quarternote.3"
        case "ttf","otf","ttc","woff","woff2","fnt":                       return "textformat"
        case "lua":                                                        return "chevron.left.forwardslash.chevron.right"
        case "love","zip","gz","7z","rar":                                 return "archivebox"
        default:                                                           return "doc.text"
        }
    }
}

// MARK: - Chọn file để nhập

extension EditorViewController: UIDocumentPickerDelegate {

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        let folder = importFolder
        importFolder = nil
        var imported: [String] = []
        var failed: [String] = []

        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                imported.append(try store.importFile(project: project, from: url, toFolder: folder))
            } catch {
                failed.append(url.lastPathComponent)
            }
        }

        if let f = folder { expanded.insert(f); saveExpanded() }
        reloadTree()

        if failed.isEmpty {
            flash("✓ Đã nhập \(imported.count) file")
        } else {
            flash("⚠️ Nhập lỗi: " + failed.joined(separator: ", "))
        }
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        importFolder = nil
    }
}
