// GitHubReleases.swift
// Quản lý Release trên GitHub: liệt kê, đăng release mới (kèm file đính kèm), sửa, xoá (tuỳ chọn xoá luôn tag).
// Chưa build/kiểm chứng.

import UIKit
import UniformTypeIdentifiers

// MARK: - Mô hình + API

struct GHAsset: Decodable {
    let id: Int
    let name: String
    let size: Int
    let downloadCount: Int?
}

struct GHRelease: Decodable {
    let id: Int
    let tagName: String
    let name: String?
    let body: String?
    let draft: Bool
    let prerelease: Bool
    let htmlUrl: String
    let targetCommitish: String?
    let assets: [GHAsset]
}

extension GitHubAPI {
    func listReleases(_ repo: String) async throws -> [GHRelease] {
        try await get([GHRelease].self, "/repos/\(repo)/releases", query: ["per_page": "50"])
    }

    func createRelease(_ repo: String, tag: String, target: String, name: String, body: String,
                       draft: Bool, prerelease: Bool) async throws -> GHRelease {
        var b: [String: Any] = ["tag_name": tag, "name": name, "body": body, "draft": draft, "prerelease": prerelease]
        if !target.isEmpty { b["target_commitish"] = target }
        return try await send(GHRelease.self, "POST", "/repos/\(repo)/releases", body: b)
    }

    func updateRelease(_ repo: String, id: Int, tag: String, name: String, body: String,
                       draft: Bool, prerelease: Bool) async throws -> GHRelease {
        let b: [String: Any] = ["tag_name": tag, "name": name, "body": body, "draft": draft, "prerelease": prerelease]
        return try await send(GHRelease.self, "PATCH", "/repos/\(repo)/releases/\(id)", body: b)
    }

    func deleteRelease(_ repo: String, id: Int) async throws {
        try await call("DELETE", "/repos/\(repo)/releases/\(id)")
    }

    func deleteTag(_ repo: String, tag: String) async throws {
        try await call("DELETE", "/repos/\(repo)/git/refs/tags/\(tag)")
    }

    func deleteAsset(_ repo: String, id: Int) async throws {
        try await call("DELETE", "/repos/\(repo)/releases/assets/\(id)")
    }

    /// Tải một file lên làm asset của release (POST lên uploads.github.com, thân yêu cầu là nội dung file).
    func uploadAsset(_ repo: String, release: Int, file: URL) async throws {
        guard let tok = GitHubKeychain.load() else { throw GHError("Chưa đăng nhập GitHub.", status: 401) }
        var comps = URLComponents(string: "https://uploads.github.com/repos/\(repo)/releases/\(release)/assets")!
        comps.queryItems = [URLQueryItem(name: "name", value: file.lastPathComponent)]
        guard let url = comps.url else { throw GHError("Tên file không hợp lệ.") }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 600
        req.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("CatnipEngine", forHTTPHeaderField: "User-Agent")
        let mime = UTType(filenameExtension: file.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        req.setValue(mime, forHTTPHeaderField: "Content-Type")
        let (data, resp) = try await URLSession.shared.upload(for: req, fromFile: file)
        guard let http = resp as? HTTPURLResponse else { throw GHError("Phản hồi từ GitHub không hợp lệ.") }
        guard (200..<300).contains(http.statusCode) else {
            var msg = ""
            if let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any] { msg = (o["message"] as? String) ?? "" }
            if http.statusCode == 422 { msg = "File “\(file.lastPathComponent)” đã tồn tại trong release hoặc không hợp lệ. " + msg }
            throw GHError("Không tải lên được \(file.lastPathComponent) (HTTP \(http.statusCode)). \(msg)", status: http.statusCode)
        }
    }
}

// MARK: - Danh sách release

final class GitHubReleasesViewController: UITableViewController {
    private let repo: String
    private let branch: String
    private var releases: [GHRelease] = []
    private var loaded = false
    private let spinner = UIActivityIndicatorView(style: .medium)

    init(repo: String, branch: String) {
        self.repo = repo
        self.branch = branch
        super.init(style: .insetGrouped)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Releases"
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(newRelease)),
            UIBarButtonItem(customView: spinner),
        ]
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(load), for: .valueChanged)
        load()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if loaded { load() }
    }

    @objc func load() {
        spinner.startAnimating()
        Task { @MainActor in
            do { self.releases = try await GitHubAPI.shared.listReleases(self.repo) }
            catch { self.showError(error) }
            self.loaded = true
            self.spinner.stopAnimating()
            self.refreshControl?.endRefreshing()
            self.tableView.reloadData()
        }
    }

    @objc private func newRelease() {
        navigationController?.pushViewController(GitHubReleaseEditorViewController(repo: repo, branch: branch, release: nil), animated: true)
    }

    override func tableView(_ tv: UITableView, numberOfRowsInSection section: Int) -> Int { releases.count }

    override func tableView(_ tv: UITableView, titleForFooterInSection section: Int) -> String? {
        loaded && releases.isEmpty ? "Repo chưa có release. Bấm + để đăng release đầu tiên." : "Chạm để sửa, vuốt trái để xoá."
    }

    override func tableView(_ tv: UITableView, cellForRowAt ip: IndexPath) -> UITableViewCell {
        let r = releases[ip.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        var tags: [String] = []
        if r.draft { tags.append("bản nháp") }
        if r.prerelease { tags.append("pre-release") }
        cell.textLabel?.text = (r.name?.isEmpty == false ? r.name! : r.tagName)
        cell.detailTextLabel?.text = ([r.tagName, "\(r.assets.count) file"] + tags).joined(separator: " · ")
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tv: UITableView, didSelectRowAt ip: IndexPath) {
        tv.deselectRow(at: ip, animated: true)
        navigationController?.pushViewController(GitHubReleaseEditorViewController(repo: repo, branch: branch, release: releases[ip.row]), animated: true)
    }

    override func tableView(_ tv: UITableView, trailingSwipeActionsConfigurationForRowAt ip: IndexPath) -> UISwipeActionsConfiguration? {
        let r = releases[ip.row]
        let del = UIContextualAction(style: .destructive, title: "Xoá") { [weak self] _, _, done in
            self?.confirmDelete(r)
            done(true)
        }
        let open = UIContextualAction(style: .normal, title: "Mở web") { _, _, done in
            if let u = URL(string: r.htmlUrl) { UIApplication.shared.open(u) }
            done(true)
        }
        return UISwipeActionsConfiguration(actions: [del, open])
    }

    private func confirmDelete(_ r: GHRelease) {
        let a = UIAlertController(title: "Xoá release “\(r.tagName)”?", message: "Không thể hoàn tác. Chọn xoá luôn tag nếu không muốn giữ lại tag trên repo.", preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "Xoá release", style: .destructive) { [weak self] _ in self?.delete(r, tag: false) })
        a.addAction(UIAlertAction(title: "Xoá release và tag", style: .destructive) { [weak self] _ in self?.delete(r, tag: true) })
        a.addAction(UIAlertAction(title: "Huỷ", style: .cancel))
        present(a, animated: true)
    }

    private func delete(_ r: GHRelease, tag: Bool) {
        spinner.startAnimating()
        Task { @MainActor in
            do {
                try await GitHubAPI.shared.deleteRelease(self.repo, id: r.id)
                if tag { try? await GitHubAPI.shared.deleteTag(self.repo, tag: r.tagName) }
            } catch { self.showError(error) }
            self.load()
        }
    }
}

// MARK: - Soạn / sửa release

final class GitHubReleaseEditorViewController: UITableViewController, UITextViewDelegate, UIDocumentPickerDelegate {
    private let repo: String
    private let release: GHRelease?
    private var tag: String
    private var target: String
    private var titleText: String
    private var notes: String
    private var draft: Bool
    private var prerelease: Bool
    private var existing: [GHAsset]
    private var pending: [URL] = []
    private var saving = false
    private var status = ""

    private enum Sec: Int, CaseIterable { case info, notes, options, assets, danger }

    init(repo: String, branch: String, release: GHRelease?) {
        self.repo = repo
        self.release = release
        self.tag = release?.tagName ?? ""
        self.target = release?.targetCommitish ?? branch
        self.titleText = release?.name ?? ""
        self.notes = release?.body ?? ""
        self.draft = release?.draft ?? false
        self.prerelease = release?.prerelease ?? false
        self.existing = release?.assets ?? []
        super.init(style: .insetGrouped)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = release == nil ? "Release mới" : "Sửa release"
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: release == nil ? "Đăng" : "Lưu", style: .done, target: self, action: #selector(saveTapped))
        tableView.keyboardDismissMode = .interactive
    }

    private func sections() -> [Sec] { release == nil ? [.info, .notes, .options, .assets] : Sec.allCases }

    override func numberOfSections(in tv: UITableView) -> Int { sections().count }

    override func tableView(_ tv: UITableView, numberOfRowsInSection s: Int) -> Int {
        switch sections()[s] {
        case .info: return release == nil ? 3 : 2          // tag, (nhánh đích), tiêu đề
        case .notes: return 1
        case .options: return 2
        case .assets: return existing.count + pending.count + 1
        case .danger: return 1
        }
    }

    override func tableView(_ tv: UITableView, titleForHeaderInSection s: Int) -> String? {
        switch sections()[s] {
        case .info: return "Thông tin"
        case .notes: return "Ghi chú phát hành (Markdown)"
        case .options: return "Tuỳ chọn"
        case .assets: return "File đính kèm"
        case .danger: return nil
        }
    }

    override func tableView(_ tv: UITableView, titleForFooterInSection s: Int) -> String? {
        switch sections()[s] {
        case .info: return release == nil ? "Nếu tag chưa có, GitHub tạo tag mới trên nhánh đích." : nil
        case .assets: return status.isEmpty ? "File mới được tải lên sau khi bấm \(release == nil ? "Đăng" : "Lưu"). Vuốt trái để bỏ/xoá file." : status
        default: return nil
        }
    }

    private func field(_ placeholder: String, _ text: String, _ set: @escaping (String) -> Void) -> UITableViewCell {
        let cell = UITableViewCell()
        cell.selectionStyle = .none
        let tf = UITextField()
        tf.placeholder = placeholder
        tf.text = text
        tf.autocapitalizationType = .none
        tf.autocorrectionType = .no
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.addAction(UIAction { [weak tf] _ in set(tf?.text ?? "") }, for: .editingChanged)
        cell.contentView.addSubview(tf)
        NSLayoutConstraint.activate([
            tf.leadingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.leadingAnchor),
            tf.trailingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.trailingAnchor),
            tf.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 12),
            tf.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -12),
        ])
        return cell
    }

    private func toggle(_ text: String, _ on: Bool, _ set: @escaping (Bool) -> Void) -> UITableViewCell {
        let cell = UITableViewCell()
        cell.selectionStyle = .none
        cell.textLabel?.text = text
        let sw = UISwitch()
        sw.isOn = on
        sw.addAction(UIAction { [weak sw] _ in set(sw?.isOn ?? false) }, for: .valueChanged)
        cell.accessoryView = sw
        return cell
    }

    override func tableView(_ tv: UITableView, cellForRowAt ip: IndexPath) -> UITableViewCell {
        switch sections()[ip.section] {
        case .info:
            switch ip.row {
            case 0: return field("Tag (ví dụ v1.0.0)", tag) { [weak self] in self?.tag = $0 }
            case 1 where release == nil: return field("Nhánh/commit đích", target) { [weak self] in self?.target = $0 }
            default: return field("Tiêu đề release", titleText) { [weak self] in self?.titleText = $0 }
            }
        case .notes:
            let cell = UITableViewCell()
            cell.selectionStyle = .none
            let tv = UITextView()
            tv.font = .systemFont(ofSize: 15)
            tv.text = notes
            tv.backgroundColor = .clear
            tv.delegate = self
            tv.autocapitalizationType = .none
            tv.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(tv)
            NSLayoutConstraint.activate([
                tv.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 12),
                tv.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -12),
                tv.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 6),
                tv.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -6),
                tv.heightAnchor.constraint(equalToConstant: 160),
            ])
            return cell
        case .options:
            return ip.row == 0
                ? toggle("Bản nháp (chưa công khai)", draft) { [weak self] in self?.draft = $0 }
                : toggle("Pre-release", prerelease) { [weak self] in self?.prerelease = $0 }
        case .assets:
            let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
            if ip.row < existing.count {
                let a = existing[ip.row]
                cell.textLabel?.text = a.name
                cell.detailTextLabel?.text = ByteCountFormatter.string(fromByteCount: Int64(a.size), countStyle: .file) + " · đã có trên GitHub"
                cell.imageView?.image = UIImage(systemName: "doc.zipper")
            } else if ip.row < existing.count + pending.count {
                let u = pending[ip.row - existing.count]
                cell.textLabel?.text = u.lastPathComponent
                let size = (try? u.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                cell.detailTextLabel?.text = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file) + " · sẽ tải lên"
                cell.imageView?.image = UIImage(systemName: "arrow.up.doc")
            } else {
                cell.textLabel?.text = "Thêm file từ Tệp…"
                cell.textLabel?.textColor = view.tintColor
                cell.imageView?.image = UIImage(systemName: "plus.circle")
            }
            return cell
        case .danger:
            let cell = UITableViewCell()
            cell.textLabel?.text = "Xoá release…"
            cell.textLabel?.textColor = .systemRed
            cell.textLabel?.textAlignment = .center
            return cell
        }
    }

    func textViewDidChange(_ textView: UITextView) { notes = textView.text }

    override func tableView(_ tv: UITableView, didSelectRowAt ip: IndexPath) {
        tv.deselectRow(at: ip, animated: true)
        switch sections()[ip.section] {
        case .assets where ip.row == existing.count + pending.count:
            let pick = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
            pick.allowsMultipleSelection = true
            pick.delegate = self
            present(pick, animated: true)
        case .danger:
            confirmDelete()
        default: break
        }
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        pending += urls
        tableView.reloadSections([Sec.assets.rawValue], with: .automatic)
    }

    override func tableView(_ tv: UITableView, trailingSwipeActionsConfigurationForRowAt ip: IndexPath) -> UISwipeActionsConfiguration? {
        guard sections()[ip.section] == .assets, ip.row < existing.count + pending.count else { return nil }
        let act = UIContextualAction(style: .destructive, title: ip.row < existing.count ? "Xoá" : "Bỏ") { [weak self] _, _, done in
            guard let self = self else { done(false); return }
            if ip.row < self.existing.count {
                let a = self.existing[ip.row]
                Task { @MainActor in
                    do { try await GitHubAPI.shared.deleteAsset(self.repo, id: a.id); self.existing.removeAll { $0.id == a.id } }
                    catch { self.showError(error) }
                    self.tableView.reloadSections([Sec.assets.rawValue], with: .automatic)
                }
            } else {
                self.pending.remove(at: ip.row - self.existing.count)
                self.tableView.reloadSections([Sec.assets.rawValue], with: .automatic)
            }
            done(true)
        }
        return UISwipeActionsConfiguration(actions: [act])
    }

    private func setSaving(_ on: Bool, _ text: String = "") {
        saving = on
        status = text
        if on {
            let s = UIActivityIndicatorView(style: .medium)
            s.startAnimating()
            navigationItem.rightBarButtonItem = UIBarButtonItem(customView: s)
        } else {
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: release == nil ? "Đăng" : "Lưu", style: .done, target: self, action: #selector(saveTapped))
        }
        tableView.reloadSections([Sec.assets.rawValue], with: .none)
    }

    @objc private func saveTapped() {
        view.endEditing(true)
        guard !saving else { return }
        let t = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !t.contains(" ") else {
            showError(GHError("Tag không được để trống hay có dấu cách."))
            return
        }
        let files = pending
        setSaving(true, "Đang lưu release…")
        Task { @MainActor in
            do {
                let rel: GHRelease
                if let r = self.release {
                    rel = try await GitHubAPI.shared.updateRelease(self.repo, id: r.id, tag: t, name: self.titleText, body: self.notes,
                                                                   draft: self.draft, prerelease: self.prerelease)
                } else {
                    rel = try await GitHubAPI.shared.createRelease(self.repo, tag: t, target: self.target.trimmingCharacters(in: .whitespaces),
                                                                   name: self.titleText.isEmpty ? t : self.titleText, body: self.notes,
                                                                   draft: self.draft, prerelease: self.prerelease)
                }
                for (i, f) in files.enumerated() {
                    self.setSaving(true, "Đang tải lên \(i + 1)/\(files.count): \(f.lastPathComponent)…")
                    try await GitHubAPI.shared.uploadAsset(self.repo, release: rel.id, file: f)
                }
                self.setSaving(false)
                self.navigationController?.popViewController(animated: true)
            } catch {
                self.setSaving(false, "Lỗi, thử lại được (release có thể đã được tạo).")
                self.showError(error)
            }
        }
    }

    private func confirmDelete() {
        guard let r = release else { return }
        let a = UIAlertController(title: "Xoá release “\(r.tagName)”?", message: "Không thể hoàn tác.", preferredStyle: .alert)
        func go(_ tag: Bool) {
            Task { @MainActor in
                do {
                    try await GitHubAPI.shared.deleteRelease(self.repo, id: r.id)
                    if tag { try? await GitHubAPI.shared.deleteTag(self.repo, tag: r.tagName) }
                    self.navigationController?.popViewController(animated: true)
                } catch { self.showError(error) }
            }
        }
        a.addAction(UIAlertAction(title: "Xoá release", style: .destructive) { _ in go(false) })
        a.addAction(UIAlertAction(title: "Xoá release và tag", style: .destructive) { _ in go(true) })
        a.addAction(UIAlertAction(title: "Huỷ", style: .cancel))
        present(a, animated: true)
    }
}
