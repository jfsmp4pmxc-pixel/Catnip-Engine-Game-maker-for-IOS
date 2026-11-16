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

// GitHubUI.swift
// Giao diện kết nối GitHub: đăng nhập bằng token, chọn/tạo repo, pull/push, chạy và theo dõi workflows.

import UIKit

private let ghTokenURL = "https://github.com/settings/tokens/new?scopes=repo,workflow&description=Catnip%20Engine"

private func ghIcon(status: String?, conclusion: String?) -> (String, UIColor) {
    if status != "completed" {
        return status == "in_progress" ? ("arrow.triangle.2.circlepath", .systemOrange) : ("clock", .systemOrange)
    }
    switch conclusion {
    case "success": return ("checkmark.circle.fill", .systemGreen)
    case "failure", "timed_out", "startup_failure": return ("xmark.circle.fill", .systemRed)
    case "cancelled": return ("slash.circle", .systemGray)
    case "skipped": return ("forward.circle", .systemGray)
    default: return ("questionmark.circle", .systemGray)
    }
}

private func ghStatusText(status: String?, conclusion: String?) -> String {
    if status != "completed" {
        switch status {
        case "in_progress": return "đang chạy"
        case "queued", "waiting", "pending", "requested": return "đang chờ"
        default: return status ?? "?"
        }
    }
    switch conclusion {
    case "success": return "thành công"
    case "failure": return "thất bại"
    case "cancelled": return "đã huỷ"
    case "skipped": return "bỏ qua"
    case "timed_out": return "quá giờ"
    default: return conclusion ?? "xong"
    }
}

private func openURL(_ s: String) {
    if let u = URL(string: s) { UIApplication.shared.open(u) }
}

private let relativeFormatter: RelativeDateTimeFormatter = {
    let f = RelativeDateTimeFormatter()
    f.locale = Locale(identifier: "vi_VN")
    f.unitsStyle = .short
    return f
}()

// MARK: - Màn hình chính

/// Việc cần làm ngay khi mở màn hình (từ mục "Công cụ" trong menu ⋯ của editor).
enum GitHubAction { case pull, push, changeBranch, renameRepo, deleteRepo }

final class GitHubViewController: UITableViewController {
    private struct Item {
        var title: String
        var subtitle: String? = nil
        var icon: String
        var destructive = false
        var chevron = false
        var action: () -> Void
    }
    private struct Section { var header: String?; var footer: String?; var items: [Item] }

    private let project: String
    private let onWillSync: () -> Void
    private var user: GHUser?
    private var link: GitHubLink?
    private var sections: [Section] = []
    private var busy = false
    private var status = ""
    private var pending: GitHubAction?

    init(project: String, start: GitHubAction? = nil, onWillSync: @escaping () -> Void) {
        self.project = project
        self.pending = start
        self.onWillSync = onWillSync
        super.init(style: .insetGrouped)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "GitHub"
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(close))
        reloadAll()
    }

    @objc private func close() { dismiss(animated: true) }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard let a = pending else { return }
        pending = nil
        perform(a)
    }

    private func perform(_ a: GitHubAction) {
        guard GitHubAPI.shared.isSignedIn else { showError(GHError("Hãy đăng nhập GitHub trước (dán token).")); return }
        guard link != nil else { showError(GHError("Dự án chưa gắn với repo nào. Hãy chọn hoặc tạo repo ở màn hình này.")); return }
        switch a {
        case .pull: doPull(overwrite: false)
        case .push: choosePushItems()
        case .changeBranch: changeBranch()
        case .renameRepo: renameRepo()
        case .deleteRepo: deleteRepo()
        }
    }

    private func setBusy(_ b: Bool, _ text: String = "") {
        busy = b
        status = text
        if b {
            let s = UIActivityIndicatorView(style: .medium)
            s.startAnimating()
            navigationItem.rightBarButtonItem = UIBarButtonItem(customView: s)
        } else {
            navigationItem.rightBarButtonItem = nil
        }
        rebuild()
    }

    /// Tải lại tên tài khoản (nếu đã đăng nhập) và liên kết của dự án.
    private func reloadAll() {
        link = GitHubLinks.link(for: project)
        guard GitHubAPI.shared.isSignedIn else { user = nil; rebuild(); return }
        rebuild()
        Task { @MainActor in
            do { self.user = try await GitHubAPI.shared.currentUser() }
            catch let e as GHError where e.status == 401 { self.user = nil; GitHubKeychain.delete() }
            catch { /* mất mạng: giữ nguyên */ }
            self.rebuild()
        }
    }

    private func rebuild() {
        var s: [Section] = []
        if !GitHubAPI.shared.isSignedIn {
            s.append(Section(header: "Đăng nhập", footer: "Tạo một Personal Access Token (quyền repo và workflow) rồi dán vào đây. Token được lưu trong Keychain của máy, không gửi đi đâu ngoài GitHub.", items: [
                Item(title: "Tạo token trên GitHub", icon: "safari", chevron: true) { openURL(ghTokenURL) },
                Item(title: "Dán token…", icon: "key") { [weak self] in self?.promptToken() },
            ]))
        } else {
            s.append(Section(header: "Tài khoản", footer: nil, items: [
                Item(title: user.map { "@\($0.login)" } ?? "Đã đăng nhập", icon: "person.crop.circle") {},
                Item(title: "Đăng xuất", icon: "rectangle.portrait.and.arrow.right", destructive: true) { [weak self] in self?.signOut() },
            ]))
            if let l = link {
                s.append(Section(header: "Repo của dự án “\(project)”", footer: status.isEmpty ? "Pull, Push, đổi nhánh, đổi tên repo nằm trong menu ⋯ → Công cụ của editor." : status, items: [
                    Item(title: l.repo, subtitle: "Nhánh \(l.branch) · mở trên GitHub", icon: "arrow.triangle.branch", chevron: true) { openURL("https://github.com/\(l.repo)/tree/\(l.branch)") },
                    Item(title: "Tạo repo mới…", icon: "plus.circle") { [weak self] in self?.createRepo() },
                    Item(title: "Xoá repo trên GitHub…", icon: "trash", destructive: true) { [weak self] in self?.deleteRepo() },
                    Item(title: "Ngắt kết nối repo", icon: "link.badge.plus", destructive: true) { [weak self] in self?.disconnect() },
                ]))
                s.append(Section(header: "Workflows", footer: "Muốn chạy thủ công, workflow phải có “on: workflow_dispatch” và đã nằm trên GitHub (nhớ Push trước).", items: [
                    Item(title: "Chạy workflow", icon: "play.circle", chevron: true) { [weak self] in self?.openWorkflows() },
                    Item(title: "Tình trạng workflows", icon: "list.bullet.rectangle", chevron: true) { [weak self] in self?.openRuns() },
                ]))
            } else {
                s.append(Section(header: "Repo của dự án “\(project)”", footer: status.isEmpty ? "Dự án chưa gắn với repo nào." : status, items: [
                    Item(title: "Chọn repo có sẵn…", icon: "tray.full", chevron: true) { [weak self] in self?.pickRepo() },
                    Item(title: "Tạo repo mới…", icon: "plus.circle") { [weak self] in self?.createRepo() },
                    Item(title: "Nhập owner/repo…", icon: "keyboard") { [weak self] in self?.enterRepo() },
                ]))
            }
        }
        sections = s
        tableView.reloadData()
    }

    // MARK: Bảng

    override func numberOfSections(in tableView: UITableView) -> Int { sections.count }
    override func tableView(_ tv: UITableView, numberOfRowsInSection section: Int) -> Int { sections[section].items.count }
    override func tableView(_ tv: UITableView, titleForHeaderInSection section: Int) -> String? { sections[section].header }
    override func tableView(_ tv: UITableView, titleForFooterInSection section: Int) -> String? { sections[section].footer }

    override func tableView(_ tv: UITableView, cellForRowAt ip: IndexPath) -> UITableViewCell {
        let item = sections[ip.section].items[ip.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.textLabel?.text = item.title
        cell.detailTextLabel?.text = item.subtitle
        cell.imageView?.image = UIImage(systemName: item.icon)
        cell.textLabel?.textColor = item.destructive ? .systemRed : .label
        cell.imageView?.tintColor = item.destructive ? .systemRed : view.tintColor
        cell.accessoryType = item.chevron ? .disclosureIndicator : .none
        cell.alpha = busy ? 0.5 : 1
        return cell
    }

    override func tableView(_ tv: UITableView, didSelectRowAt ip: IndexPath) {
        tv.deselectRow(at: ip, animated: true)
        guard !busy else { return }
        sections[ip.section].items[ip.row].action()
    }

    // MARK: Đăng nhập

    private func promptToken() {
        promptText(title: "Dán token", message: "Personal Access Token của GitHub (ghp_… hoặc github_pat_…).",
                   placeholder: "token", confirm: "Đăng nhập") { [weak self] text in
            guard let self = self else { return }
            let tok = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !tok.isEmpty else { return }
            self.setBusy(true, "Đang kiểm tra token…")
            Task { @MainActor in
                do {
                    let u = try await GitHubAPI.shared.verify(token: tok)
                    GitHubKeychain.save(tok)
                    self.user = u
                    self.setBusy(false)
                } catch {
                    self.setBusy(false)
                    self.showError(error)
                }
            }
        }
    }

    private func signOut() {
        confirmDestructive(title: "Đăng xuất GitHub?", message: "Token sẽ bị xoá khỏi máy này. Các dự án vẫn giữ liên kết repo.", button: "Đăng xuất") { [weak self] in
            GitHubKeychain.delete()
            self?.user = nil
            self?.rebuild()
        }
    }

    // MARK: Gắn repo

    private func attach(repo: String, branch: String?) {
        let b = (branch?.isEmpty == false) ? branch! : "main"
        GitHubLinks.set(GitHubLink(repo: repo, branch: b), for: project)
        link = GitHubLinks.link(for: project)
        rebuild()
        let ac = UIAlertController(title: "Đã kết nối \(repo)",
                                   message: "Tải nội dung từ GitHub về dự án ngay bây giờ? (File trùng tên khác nội dung sẽ được hỏi lại.)",
                                   preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "Để sau", style: .cancel))
        ac.addAction(UIAlertAction(title: "Pull ngay", style: .default) { [weak self] _ in self?.doPull(overwrite: false) })
        present(ac, animated: true)
    }

    private func pickRepo() {
        let vc = GitHubRepoPickerViewController { [weak self] repo in
            self?.navigationController?.popViewController(animated: true)
            self?.attach(repo: repo.fullName, branch: repo.defaultBranch)
        }
        navigationController?.pushViewController(vc, animated: true)
    }

    private func enterRepo() {
        promptText(title: "Nhập repo", message: "Dạng owner/tên-repo", placeholder: "owner/repo", confirm: "Kết nối") { [weak self] text in
            guard let self = self else { return }
            let name = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard name.split(separator: "/").count == 2 else {
                self.showError(GHError("Hãy nhập đúng dạng owner/tên-repo."))
                return
            }
            self.setBusy(true, "Đang kiểm tra repo…")
            Task { @MainActor in
                do {
                    let r = try await GitHubAPI.shared.getRepo(name)
                    self.setBusy(false)
                    self.attach(repo: r.fullName, branch: r.defaultBranch)
                } catch {
                    self.setBusy(false)
                    self.showError(error)
                }
            }
        }
    }

    private func createRepo() {
        let suggestion = project.replacingOccurrences(of: " ", with: "-")
        promptText(title: "Tạo repo mới", message: "Tên repo trên tài khoản của bạn.", placeholder: "tên-repo",
                   initial: suggestion, confirm: "Tiếp") { [weak self] text in
            guard let self = self else { return }
            let name = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return }
            let sheet = UIAlertController(title: "Chế độ hiển thị", message: "“\(name)” nên riêng tư hay công khai?", preferredStyle: .alert)
            sheet.addAction(UIAlertAction(title: "Riêng tư", style: .default) { _ in self.runCreate(name, isPrivate: true) })
            sheet.addAction(UIAlertAction(title: "Công khai", style: .default) { _ in self.runCreate(name, isPrivate: false) })
            sheet.addAction(UIAlertAction(title: "Huỷ", style: .cancel))
            self.present(sheet, animated: true)
        }
    }

    private func runCreate(_ name: String, isPrivate: Bool) {
        setBusy(true, "Đang tạo repo…")
        Task { @MainActor in
            do {
                let r = try await GitHubAPI.shared.createRepo(name: name, isPrivate: isPrivate, description: "Tạo từ Catnip Engine")
                self.setBusy(false)
                GitHubLinks.set(GitHubLink(repo: r.fullName, branch: r.defaultBranch ?? "main"), for: self.project)
                self.link = GitHubLinks.link(for: self.project)
                self.rebuild()
                let ac = UIAlertController(title: "Đã tạo \(r.fullName)", message: "Đẩy dự án lên repo mới ngay bây giờ?", preferredStyle: .alert)
                ac.addAction(UIAlertAction(title: "Để sau", style: .cancel))
                ac.addAction(UIAlertAction(title: "Push ngay", style: .default) { _ in self.doPush(message: "Khởi tạo từ Catnip Engine", force: false) })
                self.present(ac, animated: true)
            } catch {
                self.setBusy(false)
                self.showError(error)
            }
        }
    }

    private func changeBranch() {
        guard let l = link else { return }
        promptText(title: "Đổi nhánh", message: "Nhánh phải đã tồn tại trên GitHub. Lần đồng bộ kế tiếp sẽ so lại từ đầu.",
                   placeholder: "main", initial: l.branch, confirm: "Đổi") { [weak self] text in
            guard let self = self else { return }
            let b = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !b.isEmpty else { return }
            var nl = GitHubLink(repo: l.repo, branch: b)
            nl.pushExclude = l.pushExclude
            GitHubLinks.set(nl, for: self.project)
            self.link = nl
            self.rebuild()
        }
    }

    private func renameRepo() {
        guard let l = link else { return }
        let current = String(l.repo.split(separator: "/").last ?? "")
        promptText(title: "Đổi tên repo", message: "Tên mới của \(l.repo) trên GitHub.", placeholder: "tên-repo",
                   initial: current, confirm: "Đổi tên") { [weak self] text in
            guard let self = self else { return }
            let name = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, name != current else { return }
            self.setBusy(true, "Đang đổi tên…")
            Task { @MainActor in
                do {
                    let r = try await GitHubAPI.shared.renameRepo(l.repo, to: name)
                    var nl = l
                    nl.repo = r.fullName
                    GitHubLinks.set(nl, for: self.project)
                    self.link = nl
                    self.setBusy(false, "Đã đổi tên thành \(r.fullName).")
                } catch {
                    self.setBusy(false)
                    self.showError(error)
                }
            }
        }
    }

    private func deleteRepo() {
        guard let l = link else { return }
        promptText(title: "Xoá repo \(l.repo)?",
                   message: "Không thể hoàn tác. Token cần quyền delete_repo. Gõ đúng \(l.repo) để xác nhận. File trên máy vẫn giữ.",
                   placeholder: l.repo, confirm: "Xoá repo") { [weak self] text in
            guard let self = self else { return }
            guard text.trimmingCharacters(in: .whitespacesAndNewlines) == l.repo else {
                self.showError(GHError("Tên nhập vào không khớp, chưa xoá gì."))
                return
            }
            self.setBusy(true, "Đang xoá repo…")
            Task { @MainActor in
                do {
                    try await GitHubAPI.shared.deleteRepo(l.repo)
                    GitHubLinks.remove(self.project)
                    self.link = nil
                    self.setBusy(false, "Đã xoá \(l.repo).")
                } catch {
                    self.setBusy(false)
                    self.showError(error)
                }
            }
        }
    }

    /// Chọn file/thư mục (ở mọi cấp) sẽ được push, rồi hỏi nội dung commit.
    private func choosePushItems() {
        guard let l = link else { return }
        let dir = projectDir
        let files = GitHubSync.scanLocal(dir).keys.sorted()
        guard !files.isEmpty else { showError(GHError("Dự án chưa có file nào để push.")); return }
        let excl = l.pushExclude ?? []
        let sel = PushSelection(files: files,
                                excluded: Set(files.filter { f in excl.contains { f == $0 || f.hasPrefix($0 + "/") } }))
        let vc = GitHubPushItemsViewController(selection: sel, prefix: "") { [weak self] in
            guard let self = self else { return }
            guard sel.excluded.count < files.count else { self.showError(GHError("Hãy chọn ít nhất một file.")); return }
            self.navigationController?.popToViewController(self, animated: true)
            var nl = GitHubLinks.link(for: self.project) ?? l
            let packed = sel.compressed()
            nl.pushExclude = packed.isEmpty ? nil : packed
            GitHubLinks.set(nl, for: self.project)
            self.link = nl
            self.askPush()
        }
        navigationController?.pushViewController(vc, animated: true)
    }


    private func disconnect() {
        confirmDestructive(title: "Ngắt kết nối repo?", message: "File trên máy và trên GitHub đều giữ nguyên.", button: "Ngắt kết nối") { [weak self] in
            guard let self = self else { return }
            GitHubLinks.remove(self.project)
            self.link = nil
            self.rebuild()
        }
    }

    // MARK: Pull / Push

    private var projectDir: URL { CatnipPaths.projects.appendingPathComponent(project, isDirectory: true) }

    private func doPull(overwrite: Bool) {
        guard let l = link else { return }
        onWillSync()
        setBusy(true, "Đang pull…")
        let dir = projectDir
        Task { @MainActor in
            do {
                let (res, newLink) = try await GitHubSync.pull(dir: dir, link: l, overwrite: overwrite) { [weak self] text in
                    DispatchQueue.main.async { self?.status = text; self?.rebuild() }
                }
                GitHubLinks.set(newLink, for: self.project)
                self.link = newLink
                self.setBusy(false, "Pull xong: \(res.updated) file mới/cập nhật, \(res.removed) file xoá, \(res.kept) file giữ bản trên máy.")
            } catch let c as GHConflict {
                self.setBusy(false)
                self.askConflict(c, pull: true)
            } catch {
                self.setBusy(false)
                self.showError(error)
            }
        }
    }

    private func askPush() {
        promptText(title: "Push lên GitHub", message: "Nội dung commit:", placeholder: "Cập nhật từ Catnip Engine",
                   initial: "Cập nhật từ Catnip Engine", confirm: "Push") { [weak self] text in
            self?.doPush(message: text, force: false)
        }
    }

    private func doPush(message: String, force: Bool) {
        guard let l = link else { return }
        onWillSync()
        setBusy(true, "Đang push…")
        let dir = projectDir
        Task { @MainActor in
            do {
                let (res, newLink) = try await GitHubSync.push(dir: dir, link: l, message: message, force: force,
                                                               exclude: l.pushExclude ?? []) { [weak self] text in
                    DispatchQueue.main.async { self?.status = text; self?.rebuild() }
                }
                GitHubLinks.set(newLink, for: self.project)
                self.link = newLink
                if res.nothing {
                    self.setBusy(false, "Không có gì để push: máy và GitHub đã khớp (hoặc GitHub có bản mới hơn, hãy Pull).")
                } else {
                    self.setBusy(false, "Push xong: \(res.uploaded) file lên, \(res.deleted) file xoá.")
                }
            } catch let c as GHConflict {
                self.setBusy(false)
                self.askConflict(c, pull: false)
            } catch {
                self.setBusy(false)
                self.showError(error)
            }
        }
    }

    private func askConflict(_ c: GHConflict, pull: Bool) {
        let list = c.paths.prefix(8).joined(separator: "\n") + (c.paths.count > 8 ? "\n… và \(c.paths.count - 8) file nữa" : "")
        let ac = UIAlertController(title: "File bị sửa ở cả hai phía",
                                   message: "\(list)\n\nChọn bản được giữ cho các file này:", preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "Huỷ", style: .cancel))
        if pull {
            ac.addAction(UIAlertAction(title: "Dùng bản GitHub", style: .destructive) { [weak self] _ in self?.doPull(overwrite: true) })
        } else {
            ac.addAction(UIAlertAction(title: "Dùng bản trên máy", style: .destructive) { [weak self] _ in
                self?.doPush(message: "Cập nhật từ Catnip Engine", force: true)
            })
        }
        present(ac, animated: true)
    }

    // MARK: Workflows

    private func openWorkflows() {
        guard let l = link else { return }
        navigationController?.pushViewController(GitHubWorkflowsViewController(repo: l.repo, branch: l.branch), animated: true)
    }
    private func openRuns() {
        guard let l = link else { return }
        navigationController?.pushViewController(GitHubRunsViewController(repo: l.repo), animated: true)
    }
}

// MARK: - Chọn mục để push

/// Trạng thái chọn dùng chung giữa các cấp thư mục: lưu các file KHÔNG push.
final class PushSelection {
    let files: [String]
    var excluded: Set<String>
    init(files: [String], excluded: Set<String>) { self.files = files; self.excluded = excluded }

    func files(under prefix: String) -> [String] {
        prefix.isEmpty ? files : files.filter { $0.hasPrefix(prefix + "/") }
    }
    /// 0 = không chọn gì, 1 = chọn một phần, 2 = chọn hết.
    func state(of prefix: String, isDir: Bool) -> Int {
        let list = isDir ? files(under: prefix) : [prefix]
        let off = list.filter { excluded.contains($0) }.count
        return off == 0 ? 2 : (off == list.count ? 0 : 1)
    }
    func toggle(_ prefix: String, isDir: Bool) {
        let list = isDir ? files(under: prefix) : [prefix]
        if state(of: prefix, isDir: isDir) == 2 { excluded.formUnion(list) } else { excluded.subtract(list) }
    }
    /// Rút gọn: thư mục bị loại hoàn toàn thì chỉ lưu tên thư mục.
    func compressed() -> [String] {
        var dirs = Set<String>()
        for f in excluded {
            var parts = f.split(separator: "/").map(String.init)
            parts.removeLast()
            var cur = ""
            for p in parts { cur = cur.isEmpty ? p : cur + "/" + p; dirs.insert(cur) }
        }
        var chosen: [String] = []
        for d in dirs.sorted(by: { $0.count < $1.count }) {
            if chosen.contains(where: { d.hasPrefix($0 + "/") }) { continue }
            if files(under: d).allSatisfy({ excluded.contains($0) }) { chosen.append(d) }
        }
        let rest = excluded.filter { f in !chosen.contains { f.hasPrefix($0 + "/") } }
        return (chosen + rest).sorted()
    }
}

final class GitHubPushItemsViewController: UITableViewController {
    private let selection: PushSelection
    private let prefix: String
    private let onDone: () -> Void
    private var rows: [(name: String, path: String, isDir: Bool)] = []

    init(selection: PushSelection, prefix: String, onDone: @escaping () -> Void) {
        self.selection = selection
        self.prefix = prefix
        self.onDone = onDone
        super.init(style: .insetGrouped)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = prefix.isEmpty ? "Chọn file để push" : (prefix as NSString).lastPathComponent
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Tiếp", style: .done, target: self, action: #selector(done))
        var dirs = Set<String>(), files: [String] = []
        let cut = prefix.isEmpty ? 0 : prefix.count + 1
        for f in selection.files(under: prefix) {
            let rest = String(f.dropFirst(cut))
            if let slash = rest.firstIndex(of: "/") { dirs.insert(String(rest[..<slash])) } else { files.append(rest) }
        }
        let join: (String) -> String = { [prefix] n in prefix.isEmpty ? n : prefix + "/" + n }
        rows = dirs.sorted().map { ($0, join($0), true) } + files.sorted().map { ($0, join($0), false) }
    }

    @objc private func done() { onDone() }

    override func tableView(_ tv: UITableView, numberOfRowsInSection section: Int) -> Int { rows.count }
    override func tableView(_ tv: UITableView, titleForFooterInSection section: Int) -> String? {
        "Tick từng file hoặc cả thư mục (chạm vào thư mục để mở ra chọn từng file bên trong). File không tick sẽ không được push. Lựa chọn được nhớ cho lần sau."
    }

    override func tableView(_ tv: UITableView, cellForRowAt ip: IndexPath) -> UITableViewCell {
        let r = rows[ip.row]
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = r.name
        cell.imageView?.image = UIImage(systemName: r.isDir ? "folder" : "doc")
        let st = selection.state(of: r.path, isDir: r.isDir)
        let icon = st == 2 ? "checkmark.circle.fill" : (st == 1 ? "minus.circle.fill" : "circle")
        let b = UIButton(type: .system)
        b.setImage(UIImage(systemName: icon), for: .normal)
        b.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        b.tag = ip.row
        b.addTarget(self, action: #selector(boxTapped(_:)), for: .touchUpInside)
        cell.accessoryView = b
        return cell
    }

    @objc private func boxTapped(_ b: UIButton) {
        let r = rows[b.tag]
        selection.toggle(r.path, isDir: r.isDir)
        tableView.reloadData()
    }

    override func tableView(_ tv: UITableView, didSelectRowAt ip: IndexPath) {
        tv.deselectRow(at: ip, animated: true)
        let r = rows[ip.row]
        if r.isDir {
            navigationController?.pushViewController(GitHubPushItemsViewController(selection: selection, prefix: r.path, onDone: onDone), animated: true)
        } else {
            selection.toggle(r.path, isDir: false)
            tv.reloadRows(at: [ip], with: .none)
        }
    }

    /// Quay lại từ thư mục con: làm mới ô tick của cấp này.
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }
}

// MARK: - Chọn repo

final class GitHubRepoPickerViewController: UITableViewController, UISearchResultsUpdating {
    private var all: [GHRepo] = []
    private var shown: [GHRepo] = []
    private let onPick: (GHRepo) -> Void
    private let spinner = UIActivityIndicatorView(style: .medium)

    init(onPick: @escaping (GHRepo) -> Void) {
        self.onPick = onPick
        super.init(style: .insetGrouped)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Chọn repo"
        let sc = UISearchController(searchResultsController: nil)
        sc.searchResultsUpdater = self
        sc.obscuresBackgroundDuringPresentation = false
        navigationItem.searchController = sc
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: spinner)
        spinner.startAnimating()
        Task { @MainActor in
            do { self.all = try await GitHubAPI.shared.listRepos() }
            catch { self.showError(error) }
            self.spinner.stopAnimating()
            self.shown = self.all
            self.tableView.reloadData()
        }
    }

    func updateSearchResults(for sc: UISearchController) {
        let q = (sc.searchBar.text ?? "").lowercased()
        shown = q.isEmpty ? all : all.filter { $0.fullName.lowercased().contains(q) }
        tableView.reloadData()
    }

    override func tableView(_ tv: UITableView, numberOfRowsInSection section: Int) -> Int { shown.count }
    override func tableView(_ tv: UITableView, cellForRowAt ip: IndexPath) -> UITableViewCell {
        let r = shown[ip.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.textLabel?.text = r.fullName
        cell.detailTextLabel?.text = (r.isPrivate ? "🔒 " : "") + (r.description ?? "")
        cell.detailTextLabel?.textColor = .secondaryLabel
        return cell
    }
    override func tableView(_ tv: UITableView, didSelectRowAt ip: IndexPath) {
        tv.deselectRow(at: ip, animated: true)
        onPick(shown[ip.row])
    }
}

// MARK: - Chạy workflow

final class GitHubWorkflowsViewController: UITableViewController {
    private let repo: String
    private let branch: String
    private var workflows: [GHWorkflow] = []
    private let spinner = UIActivityIndicatorView(style: .medium)
    private var loaded = false

    init(repo: String, branch: String) {
        self.repo = repo
        self.branch = branch
        super.init(style: .insetGrouped)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Chạy workflow"
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: spinner)
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(load), for: .valueChanged)
        load()
    }

    @objc private func load() {
        spinner.startAnimating()
        Task { @MainActor in
            do { self.workflows = try await GitHubAPI.shared.listWorkflows(self.repo) }
            catch { self.showError(error) }
            self.loaded = true
            self.spinner.stopAnimating()
            self.refreshControl?.endRefreshing()
            self.tableView.reloadData()
        }
    }

    override func tableView(_ tv: UITableView, numberOfRowsInSection section: Int) -> Int { workflows.count }
    override func tableView(_ tv: UITableView, titleForFooterInSection section: Int) -> String? {
        if loaded && workflows.isEmpty { return "Repo này chưa có workflow nào (file trong .github/workflows). Hãy tạo bằng shell hoặc ứng dụng Tệp rồi Push." }
        return "Chạm một workflow để chạy trên nhánh “\(branch)”."
    }
    override func tableView(_ tv: UITableView, cellForRowAt ip: IndexPath) -> UITableViewCell {
        let w = workflows[ip.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.textLabel?.text = w.name
        cell.detailTextLabel?.text = w.path + (w.state == "active" ? "" : " · \(w.state)")
        cell.detailTextLabel?.textColor = .secondaryLabel
        cell.imageView?.image = UIImage(systemName: "play.circle")
        return cell
    }
    override func tableView(_ tv: UITableView, didSelectRowAt ip: IndexPath) {
        tv.deselectRow(at: ip, animated: true)
        let w = workflows[ip.row]
        promptText(title: "Chạy “\(w.name)”",
                   message: "Nhánh \(branch). Nếu workflow có input, nhập dạng khoá=giá trị, cách nhau bằng dấu phẩy (để trống nếu không có).",
                   placeholder: "version=1.0, configuration=Release", confirm: "Chạy") { [weak self] text in
            self?.run(w, inputsText: text)
        }
    }

    private func run(_ w: GHWorkflow, inputsText: String) {
        var inputs: [String: String] = [:]
        for part in inputsText.split(separator: ",") {
            let kv = part.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if kv.count == 2, !kv[0].isEmpty { inputs[kv[0]] = kv[1] }
        }
        spinner.startAnimating()
        Task { @MainActor in
            do {
                try await GitHubAPI.shared.dispatch(self.repo, workflow: w.id, ref: self.branch, inputs: inputs)
                self.spinner.stopAnimating()
                let ac = UIAlertController(title: "Đã yêu cầu chạy", message: "GitHub sẽ bắt đầu trong vài giây. Xem ở “Tình trạng workflows”.", preferredStyle: .alert)
                ac.addAction(UIAlertAction(title: "Xem tình trạng", style: .default) { _ in
                    self.navigationController?.pushViewController(GitHubRunsViewController(repo: self.repo), animated: true)
                })
                ac.addAction(UIAlertAction(title: "OK", style: .cancel))
                self.present(ac, animated: true)
            } catch {
                self.spinner.stopAnimating()
                var e: Error = error
                if let g = error as? GHError, g.status == 422 {
                    e = GHError(g.message + "\n\nWorkflow cần có “on: workflow_dispatch”, đã được Push lên nhánh \(self.branch), và các input phải đúng tên.", status: 422)
                }
                self.showError(e)
            }
        }
    }
}

// MARK: - Tình trạng workflows

final class GitHubRunsViewController: UITableViewController {
    private let repo: String
    private var runs: [GHRun] = []
    private var timer: Timer?
    private var loaded = false

    init(repo: String) {
        self.repo = repo
        super.init(style: .insetGrouped)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Tình trạng workflows"
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(pullToRefresh), for: .valueChanged)
        refreshControl?.beginRefreshing()
        fetch(silent: false)
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        timer?.invalidate()
        let t = Timer(timeInterval: 6, repeats: true) { [weak self] _ in self?.fetch(silent: true) }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        fetch(silent: true)
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer?.invalidate()
        timer = nil
    }

    @objc private func pullToRefresh() { fetch(silent: false) }

    private func fetch(silent: Bool) {
        Task { @MainActor in
            do { self.runs = try await GitHubAPI.shared.listRuns(self.repo) }
            catch { if !silent { self.showError(error) } }
            self.loaded = true
            self.refreshControl?.endRefreshing()
            self.tableView.reloadData()
        }
    }

    override func tableView(_ tv: UITableView, numberOfRowsInSection section: Int) -> Int { runs.count }
    override func tableView(_ tv: UITableView, titleForFooterInSection section: Int) -> String? {
        loaded && runs.isEmpty ? "Chưa có lần chạy nào." : "Tự làm mới mỗi vài giây. Kéo xuống để tải lại."
    }
    override func tableView(_ tv: UITableView, cellForRowAt ip: IndexPath) -> UITableViewCell {
        let r = runs[ip.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.textLabel?.text = r.displayTitle ?? r.name ?? "Lần chạy #\(r.runNumber)"
        var parts = ["#\(r.runNumber)", ghStatusText(status: r.status, conclusion: r.conclusion)]
        if let b = r.headBranch { parts.append(b) }
        if let e = r.event { parts.append(e) }
        if let d = r.createdAt { parts.append(relativeFormatter.localizedString(for: d, relativeTo: Date())) }
        cell.detailTextLabel?.text = parts.joined(separator: " · ")
        cell.detailTextLabel?.textColor = .secondaryLabel
        let (name, color) = ghIcon(status: r.status, conclusion: r.conclusion)
        cell.imageView?.image = UIImage(systemName: name)
        cell.imageView?.tintColor = color
        cell.accessoryType = .disclosureIndicator
        return cell
    }
    override func tableView(_ tv: UITableView, didSelectRowAt ip: IndexPath) {
        tv.deselectRow(at: ip, animated: true)
        navigationController?.pushViewController(GitHubRunDetailViewController(repo: repo, run: runs[ip.row]), animated: true)
    }
}

// MARK: - Chi tiết một lần chạy

final class GitHubRunDetailViewController: UITableViewController {
    private let repo: String
    private var run: GHRun
    private var jobs: [GHJob] = []
    private var artifacts: [GHArtifact] = []
    private var timer: Timer?

    init(repo: String, run: GHRun) {
        self.repo = repo
        self.run = run
        super.init(style: .insetGrouped)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Lần chạy #\(run.runNumber)"
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(pullToRefresh), for: .valueChanged)
        updateMenu()
        fetch(silent: false)
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        timer?.invalidate()
        let t = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            guard let self = self, self.run.status != "completed" else { return }
            self.fetch(silent: true)
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer?.invalidate()
        timer = nil
    }

    private func updateMenu() {
        let open = UIAction(title: "Mở trên GitHub", image: UIImage(systemName: "safari")) { [run] _ in openURL(run.htmlUrl) }
        let arts = UIAction(title: "Mở artifacts trên GitHub", image: UIImage(systemName: "shippingbox")) { [run] _ in openURL(run.htmlUrl + "#artifacts") }
        var children: [UIMenuElement] = [open, arts]
        if run.status == "completed" {
            children.append(UIAction(title: "Chạy lại", image: UIImage(systemName: "arrow.clockwise")) { [weak self] _ in self?.act(rerun: true) })
        } else {
            children.append(UIAction(title: "Huỷ lần chạy", image: UIImage(systemName: "stop.circle"), attributes: .destructive) { [weak self] _ in self?.act(rerun: false) })
        }
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), menu: UIMenu(children: children))
    }

    private func act(rerun: Bool) {
        Task { @MainActor in
            do {
                if rerun { try await GitHubAPI.shared.rerun(self.repo, run: self.run.id) }
                else { try await GitHubAPI.shared.cancel(self.repo, run: self.run.id) }
                self.fetch(silent: true)
            } catch { self.showError(error) }
        }
    }

    @objc private func pullToRefresh() { fetch(silent: false) }

    private func fetch(silent: Bool) {
        Task { @MainActor in
            do {
                self.run = try await GitHubAPI.shared.getRun(self.repo, id: self.run.id)
                self.jobs = try await GitHubAPI.shared.jobs(self.repo, run: self.run.id)
                self.artifacts = (try? await GitHubAPI.shared.listArtifacts(self.repo, run: self.run.id)) ?? []
            } catch { if !silent { self.showError(error) } }
            self.refreshControl?.endRefreshing()
            self.updateMenu()
            self.tableView.reloadData()
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 1 + jobs.count }
    override func tableView(_ tv: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? 1 + artifacts.count : (jobs[section - 1].steps?.count ?? 0) + 1
    }
    override func tableView(_ tv: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 { return nil }
        let j = jobs[section - 1]
        return "\(j.name) — \(ghStatusText(status: j.status, conclusion: j.conclusion))"
    }
    override func tableView(_ tv: UITableView, cellForRowAt ip: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.selectionStyle = .none
        if ip.section == 0 && ip.row > 0 {
            let a = artifacts[ip.row - 1]
            cell.textLabel?.text = a.name
            cell.detailTextLabel?.text = ByteCountFormatter.string(fromByteCount: Int64(a.sizeInBytes), countStyle: .file)
                + (a.expired ? " · đã hết hạn" : " · chạm để tải .zip")
            cell.imageView?.image = UIImage(systemName: "shippingbox")
            cell.selectionStyle = a.expired ? .none : .default
        } else if ip.section > 0 && ip.row == (jobs[ip.section - 1].steps?.count ?? 0) {
            cell.textLabel?.text = "Xem log của job"
            cell.imageView?.image = UIImage(systemName: "doc.plaintext")
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default
        } else if ip.section == 0 {
            cell.textLabel?.text = run.displayTitle ?? run.name ?? "Lần chạy #\(run.runNumber)"
            cell.textLabel?.numberOfLines = 0
            cell.detailTextLabel?.text = ghStatusText(status: run.status, conclusion: run.conclusion)
            let (n, c) = ghIcon(status: run.status, conclusion: run.conclusion)
            cell.imageView?.image = UIImage(systemName: n)
            cell.imageView?.tintColor = c
        } else if let step = jobs[ip.section - 1].steps?[ip.row] {
            cell.textLabel?.text = "\(step.number). \(step.name)"
            cell.textLabel?.numberOfLines = 0
            cell.detailTextLabel?.text = ghStatusText(status: step.status, conclusion: step.conclusion)
            let (n, c) = ghIcon(status: step.status, conclusion: step.conclusion)
            cell.imageView?.image = UIImage(systemName: n)
            cell.imageView?.tintColor = c
        }
        cell.detailTextLabel?.textColor = .secondaryLabel
        return cell
    }

    override func tableView(_ tv: UITableView, didSelectRowAt ip: IndexPath) {
        tv.deselectRow(at: ip, animated: true)
        if ip.section == 0 {
            guard ip.row > 0 else { return }
            let a = artifacts[ip.row - 1]
            guard !a.expired else { return }
            downloadArtifact(a, from: tv.cellForRow(at: ip))
        } else if ip.row == (jobs[ip.section - 1].steps?.count ?? 0) {
            let j = jobs[ip.section - 1]
            navigationController?.pushViewController(GitHubLogViewController(repo: repo, job: j), animated: true)
        }
    }

    private func downloadArtifact(_ a: GHArtifact, from cell: UIView?) {
        let spin = UIActivityIndicatorView(style: .medium)
        spin.startAnimating()
        let old = navigationItem.rightBarButtonItem
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: spin)
        Task { @MainActor in
            defer { self.navigationItem.rightBarButtonItem = old }
            do {
                let data = try await GitHubAPI.shared.downloadArtifact(self.repo, id: a.id)
                let dir = FileManager.default.temporaryDirectory.appendingPathComponent("catnip-artifact-\(UUID().uuidString)", isDirectory: true)
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let file = dir.appendingPathComponent(a.name + ".zip")
                try data.write(to: file)
                let share = UIActivityViewController(activityItems: [file], applicationActivities: nil)
                share.popoverPresentationController?.sourceView = cell ?? self.view
                share.completionWithItemsHandler = { _, _, _, _ in try? FileManager.default.removeItem(at: dir) }
                self.present(share, animated: true)
            } catch {
                self.showError(error)
            }
        }
    }
}

// MARK: - Log của một job

final class GitHubLogViewController: UIViewController {
    private let repo: String
    private let job: GHJob
    private let textView = UITextView()
    private let spinner = UIActivityIndicatorView(style: .medium)

    init(repo: String, job: GHJob) {
        self.repo = repo
        self.job = job
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = job.name
        view.backgroundColor = .systemBackground
        textView.isEditable = false
        textView.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.alwaysBounceVertical = true
        textView.frame = view.bounds
        textView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(textView)
        spinner.center = view.center
        spinner.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
        view.addSubview(spinner)
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(reload)),
            UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(shareLog)),
        ]
        reload()
    }

    @objc private func shareLog() {
        let share = UIActivityViewController(activityItems: [textView.text ?? ""], applicationActivities: nil)
        share.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItems?.last
        present(share, animated: true)
    }

    @objc private func reload() {
        spinner.startAnimating()
        Task { @MainActor in
            do {
                var text = try await GitHubAPI.shared.jobLog(self.repo, job: self.job.id)
                if text.utf8.count > 400_000 { text = "… (đã cắt bớt phần đầu)\n" + String(text.suffix(400_000)) }
                self.textView.text = text.isEmpty ? "(Log trống hoặc chưa có. Job đang chạy thì thử tải lại sau.)" : text
                let end = (self.textView.text as NSString).length
                self.textView.scrollRangeToVisible(NSRange(location: max(0, end - 1), length: 1))
            } catch {
                self.textView.text = "Không tải được log: \(error.localizedDescription)"
            }
            self.spinner.stopAnimating()
        }
    }
}
