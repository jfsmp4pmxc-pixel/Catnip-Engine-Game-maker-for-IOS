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

// GitHub.swift
// Kết nối GitHub không cần git: dùng REST API (token cá nhân lưu trong Keychain).
//  - GitHubAPI: gọi API, đổi lỗi HTTP sang tiếng Việt.
//  - GitHubLinks: dự án nào đang gắn với repo/nhánh nào, và trạng thái đồng bộ lần cuối.
//  - GitHubSync: pull/push bằng Git Data API (blob → tree → commit → ref), không cần thư viện git.
//  - Workflows: liệt kê, chạy (workflow_dispatch), xem các lần chạy, chạy lại, huỷ.

import Foundation
import Security
import CryptoKit

// MARK: - Lỗi

struct GHError: LocalizedError {
    let message: String
    var status: Int? = nil
    init(_ message: String, status: Int? = nil) { self.message = message; self.status = status }
    var errorDescription: String? { message }
}

/// Hai bên cùng sửa một số file: cần người dùng chọn bản nào.
struct GHConflict: LocalizedError {
    let paths: [String]
    var errorDescription: String? { "Có \(paths.count) file bị sửa ở cả hai phía." }
}

// MARK: - Token

enum GitHubKeychain {
    private static let service = "com.catnip.github"
    private static let account = "token"
    private static var fallbackFile: URL { CatnipPaths.root.appendingPathComponent("github-token") }

    private static func query() -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    static func load() -> String? {
        var q = query()
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        if SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
           let d = out as? Data, let s = String(data: d, encoding: .utf8), !s.isEmpty { return s }
        // IPA không ký/ký lại có thể không dùng được Keychain: đọc file dự phòng.
        if let d = try? Data(contentsOf: fallbackFile), let s = String(data: d, encoding: .utf8), !s.isEmpty { return s }
        return nil
    }

    static func save(_ token: String) {
        delete()
        var q = query()
        q[kSecValueData as String] = Data(token.utf8)
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        if SecItemAdd(q as CFDictionary, nil) != errSecSuccess {
            try? FileManager.default.createDirectory(at: CatnipPaths.root, withIntermediateDirectories: true)
            try? Data(token.utf8).write(to: fallbackFile, options: [.atomic, .completeFileProtection])
        }
    }

    static func delete() {
        SecItemDelete(query() as CFDictionary)
        try? FileManager.default.removeItem(at: fallbackFile)
    }
}

// MARK: - Mô hình dữ liệu API

struct GHUser: Decodable { let login: String }

struct GHRepo: Decodable {
    let id: Int
    let name: String
    let fullName: String
    let isPrivate: Bool
    let defaultBranch: String?
    let htmlUrl: String
    let description: String?
    let size: Int?
    enum CodingKeys: String, CodingKey {
        case id, name, fullName, isPrivate = "private", defaultBranch, htmlUrl, description, size
    }
}

struct GHWorkflow: Decodable {
    let id: Int
    let name: String
    let path: String
    let state: String
}
struct GHWorkflowList: Decodable { let workflows: [GHWorkflow] }

struct GHRun: Decodable {
    let id: Int
    let name: String?
    let displayTitle: String?
    let status: String?
    let conclusion: String?
    let event: String?
    let headBranch: String?
    let runNumber: Int
    let createdAt: Date?
    let htmlUrl: String
}
struct GHRunList: Decodable { let workflowRuns: [GHRun] }

struct GHStep: Decodable {
    let name: String
    let status: String?
    let conclusion: String?
    let number: Int
}
struct GHJob: Decodable {
    let id: Int
    let name: String
    let status: String?
    let conclusion: String?
    let steps: [GHStep]?
}
struct GHJobList: Decodable { let jobs: [GHJob] }

struct GHArtifact: Decodable {
    let id: Int
    let name: String
    let sizeInBytes: Int
    let expired: Bool
}
struct GHArtifactList: Decodable { let artifacts: [GHArtifact] }

private struct GHSha: Decodable { let sha: String }
private struct GHRefObject: Decodable { let object: GHSha }
private struct GHCommit: Decodable { let sha: String; let tree: GHSha }
private struct GHTreeEntry: Decodable { let path: String; let type: String; let sha: String? }
private struct GHTree: Decodable { let sha: String; let truncated: Bool?; let tree: [GHTreeEntry] }

// MARK: - Gọi API

final class GitHubAPI {
    static let shared = GitHubAPI()
    private let base = "https://api.github.com"
    private let session: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 40
        c.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: c)
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    var isSignedIn: Bool { GitHubKeychain.load() != nil }

    @discardableResult
    func call(_ method: String, _ path: String, query: [String: String] = [:],
              body: [String: Any]? = nil, raw: Bool = false, token: String? = nil) async throws -> Data {
        guard let tok = token ?? GitHubKeychain.load() else {
            throw GHError("Chưa đăng nhập GitHub.", status: 401)
        }
        let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        guard var comps = URLComponents(string: base + encoded) else { throw GHError("Đường dẫn API không hợp lệ.") }
        if !query.isEmpty {
            comps.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = comps.url else { throw GHError("Đường dẫn API không hợp lệ.") }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
        req.setValue(raw ? "application/vnd.github.raw+json" : "application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        req.setValue("CatnipEngine", forHTTPHeaderField: "User-Agent")
        if let body = body {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw GHError("Phản hồi từ GitHub không hợp lệ.") }
        if (200..<300).contains(http.statusCode) { return data }
        throw Self.makeError(http, data)
    }

    private static func makeError(_ http: HTTPURLResponse, _ data: Data) -> GHError {
        var server = ""
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            server = (obj["message"] as? String) ?? ""
            if let errs = obj["errors"] as? [[String: Any]] {
                let extra = errs.compactMap { $0["message"] as? String }.joined(separator: "; ")
                if !extra.isEmpty { server += " (\(extra))" }
            }
        }
        let code = http.statusCode
        let remaining = http.value(forHTTPHeaderField: "x-ratelimit-remaining")
        let text: String
        switch code {
        case 401: text = "Token không hợp lệ hoặc đã hết hạn. Hãy đăng nhập lại."
        case 403 where remaining == "0": text = "Đã vượt giới hạn số lần gọi GitHub, hãy thử lại sau ít phút."
        case 403: text = "GitHub từ chối (token thiếu quyền?). \(server)"
        case 404: text = "Không tìm thấy trên GitHub (repo/nhánh không tồn tại hoặc token không có quyền). \(server)"
        case 409: text = "Xung đột: \(server)"
        case 422: text = "GitHub không chấp nhận yêu cầu: \(server)"
        default: text = "Lỗi GitHub \(code): \(server)"
        }
        return GHError(text.trimmingCharacters(in: .whitespaces), status: code)
    }

    func get<T: Decodable>(_ type: T.Type, _ path: String, query: [String: String] = [:]) async throws -> T {
        let d = try await call("GET", path, query: query)
        return try decode(type, d)
    }

    func send<T: Decodable>(_ type: T.Type, _ method: String, _ path: String, body: [String: Any]) async throws -> T {
        let d = try await call(method, path, body: body)
        return try decode(type, d)
    }

    private func decode<T: Decodable>(_ type: T.Type, _ data: Data) throws -> T {
        do { return try decoder.decode(T.self, from: data) }
        catch { throw GHError("Không đọc được phản hồi từ GitHub: \(error.localizedDescription)") }
    }

    // MARK: Tài khoản & repo

    func verify(token: String) async throws -> GHUser {
        let d = try await call("GET", "/user", token: token)
        return try decode(GHUser.self, d)
    }
    func currentUser() async throws -> GHUser { try await get(GHUser.self, "/user") }

    func listRepos() async throws -> [GHRepo] {
        var all: [GHRepo] = []
        for page in 1...3 {
            let batch = try await get([GHRepo].self, "/user/repos",
                                      query: ["per_page": "100", "page": String(page), "sort": "pushed"])
            all += batch
            if batch.count < 100 { break }
        }
        return all
    }
    func getRepo(_ repo: String) async throws -> GHRepo { try await get(GHRepo.self, "/repos/\(repo)") }

    func createRepo(name: String, isPrivate: Bool, description: String) async throws -> GHRepo {
        try await send(GHRepo.self, "POST", "/user/repos",
                       body: ["name": name, "private": isPrivate, "description": description, "auto_init": true])
    }

    func renameRepo(_ repo: String, to name: String) async throws -> GHRepo {
        try await send(GHRepo.self, "PATCH", "/repos/\(repo)", body: ["name": name])
    }
    func deleteRepo(_ repo: String) async throws { try await call("DELETE", "/repos/\(repo)") }

    // MARK: Log & artifacts

    /// Log của một job (văn bản thuần). GitHub trả về chuyển hướng tới địa chỉ tạm; URLSession tự theo.
    func jobLog(_ repo: String, job: Int) async throws -> String {
        let d = try await call("GET", "/repos/\(repo)/actions/jobs/\(job)/logs")
        return String(decoding: d, as: UTF8.self)
    }
    func listArtifacts(_ repo: String, run: Int) async throws -> [GHArtifact] {
        try await get(GHArtifactList.self, "/repos/\(repo)/actions/runs/\(run)/artifacts", query: ["per_page": "100"]).artifacts
    }
    func downloadArtifact(_ repo: String, id: Int) async throws -> Data {
        try await call("GET", "/repos/\(repo)/actions/artifacts/\(id)/zip")
    }

    // MARK: Workflows

    func listWorkflows(_ repo: String) async throws -> [GHWorkflow] {
        try await get(GHWorkflowList.self, "/repos/\(repo)/actions/workflows", query: ["per_page": "100"]).workflows
    }
    func workflowFile(_ repo: String, path: String, ref: String) async throws -> String {
        let d = try await call("GET", "/repos/\(repo)/contents/\(path)", query: ["ref": ref], raw: true)
        return String(decoding: d, as: UTF8.self)
    }
    func listBranches(_ repo: String) async throws -> [String] {
        struct B: Decodable { let name: String }
        return try await get([B].self, "/repos/\(repo)/branches", query: ["per_page": "100"]).map { $0.name }
    }
    func dispatch(_ repo: String, workflow: Int, ref: String, inputs: [String: String]) async throws {
        var body: [String: Any] = ["ref": ref]
        if !inputs.isEmpty { body["inputs"] = inputs }
        try await call("POST", "/repos/\(repo)/actions/workflows/\(workflow)/dispatches", body: body)
    }
    func listRuns(_ repo: String) async throws -> [GHRun] {
        try await get(GHRunList.self, "/repos/\(repo)/actions/runs", query: ["per_page": "30"]).workflowRuns
    }
    func getRun(_ repo: String, id: Int) async throws -> GHRun { try await get(GHRun.self, "/repos/\(repo)/actions/runs/\(id)") }
    func jobs(_ repo: String, run: Int) async throws -> [GHJob] {
        try await get(GHJobList.self, "/repos/\(repo)/actions/runs/\(run)/jobs", query: ["per_page": "100"]).jobs
    }
    func rerun(_ repo: String, run: Int) async throws { try await call("POST", "/repos/\(repo)/actions/runs/\(run)/rerun") }
    func cancel(_ repo: String, run: Int) async throws { try await call("POST", "/repos/\(repo)/actions/runs/\(run)/cancel") }
}

// MARK: - Liên kết dự án ↔ repo

struct GitHubLink: Codable {
    var repo: String                    // "owner/name"
    var branch: String
    var synced: [String: String] = [:]  // đường dẫn → SHA blob ở lần đồng bộ gần nhất
    var pushExclude: [String]? = nil    // file/thư mục (đường dẫn tương đối, ở mọi cấp) KHÔNG push; nil = push tất cả
}

enum GitHubLinks {
    private static let lock = NSLock()
    private static var file: URL { CatnipPaths.root.appendingPathComponent("github-links.json") }

    private static func load() -> [String: GitHubLink] {
        guard let d = try? Data(contentsOf: file),
              let m = try? JSONDecoder().decode([String: GitHubLink].self, from: d) else { return [:] }
        return m
    }
    private static func store(_ m: [String: GitHubLink]) {
        try? FileManager.default.createDirectory(at: CatnipPaths.root, withIntermediateDirectories: true)
        if let d = try? JSONEncoder().encode(m) { try? d.write(to: file, options: .atomic) }
    }

    static func link(for project: String) -> GitHubLink? {
        lock.lock(); defer { lock.unlock() }
        return load()[project]
    }
    static func set(_ link: GitHubLink?, for project: String) {
        lock.lock(); defer { lock.unlock() }
        var m = load()
        m[project] = link
        store(m)
    }
    static func rename(_ old: String, to new: String) {
        lock.lock(); defer { lock.unlock() }
        var m = load()
        if let l = m.removeValue(forKey: old) { m[new] = l; store(m) }
    }
    static func remove(_ project: String) { set(nil, for: project) }
}

// MARK: - Đồng bộ (pull / push)

struct PullResult { var updated = 0; var removed = 0; var kept = 0 }
struct PushResult { var uploaded = 0; var deleted = 0; var nothing = false }

enum GitHubSync {
    typealias Progress = (String) -> Void

    private struct Remote {
        var commit: String?
        var tree: String?
        var files: [String: String] = [:]   // đường dẫn → SHA blob
    }

    // MARK: File cục bộ

    private static func isSafe(_ path: String) -> Bool {
        if path.isEmpty || path == ".git" || path.hasPrefix(".git/") { return false }
        return !path.split(separator: "/", omittingEmptySubsequences: false).contains { $0.isEmpty || $0 == "." || $0 == ".." }
    }

    /// Các file của dự án sẽ được đồng bộ (gồm cả file ẩn như .github; bỏ .git, .catnip.json, .DS_Store).
    static func scanLocal(_ dir: URL) -> [String: URL] {
        var out: [String: URL] = [:]
        let root = dir.resolvingSymlinksInPath()
        let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey, .fileSizeKey]
        guard let en = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys, options: []) else { return out }
        let skip = root.pathComponents.count
        for case let url as URL in en {
            let vals = try? url.resourceValues(forKeys: Set(keys))
            let name = url.lastPathComponent
            if vals?.isDirectory == true {
                if name == ".git" { en.skipDescendants() }
                continue
            }
            guard vals?.isRegularFile == true else { continue }
            if name == ".DS_Store" { continue }
            if let s = vals?.fileSize, s > 50_000_000 { continue }
            let rel = url.pathComponents.dropFirst(skip).joined(separator: "/")
            if rel == ".catnip.json" || !isSafe(rel) { continue }
            out[rel] = url
        }
        return out
    }

    /// SHA-1 kiểu git: "blob <độ dài>\0" + nội dung.
    static func blobSHA(_ data: Data) -> String {
        var h = Insecure.SHA1()
        h.update(data: Data("blob \(data.count)\0".utf8))
        h.update(data: data)
        return h.finalize().map { String(format: "%02x", $0) }.joined()
    }

    // MARK: Từ xa

    private static func fetchRemote(_ repo: String, _ branch: String) async throws -> Remote {
        let api = GitHubAPI.shared
        let ref: GHRefObject
        do {
            ref = try await api.get(GHRefObject.self, "/repos/\(repo)/git/ref/heads/\(branch)")
        } catch let e as GHError where e.status == 404 || e.status == 409 {
            if e.status == 409 { return Remote() }
            let info = try await api.getRepo(repo)
            if (info.size ?? 0) == 0 { return Remote() }
            throw GHError("Nhánh \"\(branch)\" không tồn tại trên \(repo).")
        }
        let commit = try await api.get(GHCommit.self, "/repos/\(repo)/git/commits/\(ref.object.sha)")
        let tree = try await api.get(GHTree.self, "/repos/\(repo)/git/trees/\(commit.tree.sha)", query: ["recursive": "1"])
        if tree.truncated == true { throw GHError("Repo quá lớn để đồng bộ trong ứng dụng.") }
        var r = Remote(commit: commit.sha, tree: commit.tree.sha)
        for e in tree.tree where e.type == "blob" { if let s = e.sha { r.files[e.path] = s } }
        return r
    }

    /// Repo hoàn toàn trống thì Git Data API không dùng được: tạo commit đầu tiên bằng Contents API.
    private static func bootstrap(_ repo: String, _ branch: String) async throws {
        try await GitHubAPI.shared.call("PUT", "/repos/\(repo)/contents/.gitkeep",
                                        body: ["message": "Khởi tạo repo", "content": "Cg==", "branch": branch])
    }

    // MARK: Pull

    static func pull(dir: URL, link: GitHubLink, overwrite: Bool, progress: Progress? = nil) async throws -> (PullResult, GitHubLink) {
        progress?("Đang đọc danh sách file trên GitHub…")
        let remote = try await fetchRemote(link.repo, link.branch)
        var link = link
        var result = PullResult()
        let local = scanLocal(dir)

        var localSHA: [String: String] = [:]
        for (p, u) in local { if let d = try? Data(contentsOf: u) { localSHA[p] = blobSHA(d) } }

        var download: [String] = []
        var conflicts: [String] = []
        var synced = link.synced

        for (path, rsha) in remote.files where isSafe(path) {
            let lsha = localSHA[path]
            let base = synced[path]
            if lsha == rsha { synced[path] = rsha; continue }
            if lsha == nil {
                if base != nil && base == rsha { result.kept += 1; continue }   // đã xoá ở máy, GitHub không đổi
                download.append(path)
            } else if base == lsha {
                download.append(path)                                          // máy không đổi, GitHub đổi
            } else if base == rsha {
                result.kept += 1                                               // chỉ máy đổi (để push)
            } else if overwrite {
                download.append(path)
            } else {
                conflicts.append(path)
            }
        }
        if !conflicts.isEmpty { throw GHConflict(paths: conflicts.sorted()) }

        // File có trong lần đồng bộ trước nhưng GitHub đã xoá.
        var removeLocal: [String] = []
        for (path, base) in link.synced where remote.files[path] == nil {
            if let l = localSHA[path] {
                if l == base || overwrite { removeLocal.append(path) } else { synced[path] = nil }
            } else {
                synced[path] = nil
            }
        }

        let fm = FileManager.default
        for (i, path) in download.sorted().enumerated() {
            progress?("Tải \(i + 1)/\(download.count): \(path)")
            guard let sha = remote.files[path] else { continue }
            let data = try await GitHubAPI.shared.call("GET", "/repos/\(link.repo)/git/blobs/\(sha)", raw: true)
            let dest = dir.appendingPathComponent(path)
            try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: dest, options: .atomic)
            synced[path] = sha
            result.updated += 1
        }
        for path in removeLocal {
            try? fm.removeItem(at: dir.appendingPathComponent(path))
            synced[path] = nil
            result.removed += 1
        }
        link.synced = synced
        return (result, link)
    }

    // MARK: Push

    static func push(dir: URL, link: GitHubLink, message: String, force: Bool, exclude: [String] = [],
                     progress: Progress? = nil) async throws -> (PushResult, GitHubLink) {
        let api = GitHubAPI.shared
        progress?("Đang đọc trạng thái trên GitHub…")
        var remote = try await fetchRemote(link.repo, link.branch)
        if remote.commit == nil {
            progress?("Repo trống: tạo commit khởi tạo…")
            try await bootstrap(link.repo, link.branch)
            remote = try await fetchRemote(link.repo, link.branch)
        }
        guard let parent = remote.commit, let baseTree = remote.tree else { throw GHError("Không đọc được commit hiện tại trên GitHub.") }

        var link = link
        var synced = link.synced
        func inScope(_ path: String) -> Bool {
            !exclude.contains { path == $0 || path.hasPrefix($0 + "/") }
        }
        let local = scanLocal(dir).filter { inScope($0.key) }
        var datas: [String: Data] = [:]
        var localSHA: [String: String] = [:]
        for (p, u) in local {
            guard let d = try? Data(contentsOf: u) else { continue }
            datas[p] = d
            localSHA[p] = blobSHA(d)
        }

        var upload: [String] = []
        var delete: [String] = []
        var conflicts: [String] = []

        for (path, lsha) in localSHA {
            let rsha = remote.files[path]
            if rsha == lsha { synced[path] = lsha; continue }
            let base = synced[path]
            if let rsha = rsha, base != rsha {
                if base == lsha { continue }                  // chỉ GitHub đổi: để Pull
                if force { upload.append(path) } else { conflicts.append(path) }
            } else {
                upload.append(path)
            }
        }
        for (path, base) in synced where localSHA[path] == nil && inScope(path) {
            guard let rsha = remote.files[path] else { synced[path] = nil; continue }
            if rsha == base || force { delete.append(path) }
        }
        if !conflicts.isEmpty { throw GHConflict(paths: conflicts.sorted()) }

        if upload.isEmpty && delete.isEmpty {
            link.synced = synced
            return (PushResult(nothing: true), link)
        }

        var entries: [[String: Any]] = []
        var newSHA: [String: String] = [:]
        let ups = upload.sorted()
        for (i, path) in ups.enumerated() {
            progress?("Tải lên \(i + 1)/\(ups.count): \(path)")
            guard let data = datas[path] else { continue }
            struct Blob: Decodable { let sha: String }
            let blob = try await api.send(Blob.self, "POST", "/repos/\(link.repo)/git/blobs",
                                          body: ["content": data.base64EncodedString(), "encoding": "base64"])
            newSHA[path] = blob.sha
            entries.append(["path": path, "mode": "100644", "type": "blob", "sha": blob.sha])
        }
        for path in delete { entries.append(["path": path, "mode": "100644", "type": "blob", "sha": NSNull()]) }

        progress?("Tạo commit…")
        struct NewSha: Decodable { let sha: String }
        let tree = try await api.send(NewSha.self, "POST", "/repos/\(link.repo)/git/trees",
                                      body: ["base_tree": baseTree, "tree": entries])
        let msg = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let commit = try await api.send(NewSha.self, "POST", "/repos/\(link.repo)/git/commits",
                                        body: ["message": msg.isEmpty ? "Cập nhật từ Catnip Engine" : msg,
                                               "tree": tree.sha, "parents": [parent]])
        try await api.call("PATCH", "/repos/\(link.repo)/git/refs/heads/\(link.branch)",
                           body: ["sha": commit.sha, "force": false])

        for (p, s) in newSHA { synced[p] = s }
        for p in delete { synced[p] = nil }
        link.synced = synced
        return (PushResult(uploaded: newSHA.count, deleted: delete.count, nothing: false), link)
    }
}


// MARK: - Đọc input của workflow_dispatch từ file YAML

struct GHInput {
    var name: String
    var description = ""
    var required = false
    var defaultValue = ""
    var type = "string"          // string | boolean | choice | number | environment
    var options: [String] = []
}

/// Bộ đọc YAML tối giản, chỉ đủ để lấy khối `on: workflow_dispatch: inputs:` của workflow.
enum WorkflowYAML {
    private struct Line { let indent: Int; let text: String }

    private static func stripComment(_ s: String) -> String {
        var quote: Character? = nil
        var prev: Character = " "
        for (i, ch) in s.enumerated() {
            if let q = quote { if ch == q { quote = nil } }
            else if ch == "\"" || ch == "'" { quote = ch }
            else if ch == "#" && (i == 0 || prev == " " || prev == "\t") {
                return String(s.prefix(i))
            }
            prev = ch
        }
        return s
    }

    private static func unquote(_ v: String) -> String {
        let t = v.trimmingCharacters(in: .whitespaces)
        if t.count >= 2, let f = t.first, let l = t.last, f == l, f == "\"" || f == "'" {
            return String(t.dropFirst().dropLast())
        }
        return t
    }

    private static func splitKV(_ text: String) -> (String, String)? {
        let chars = Array(text)
        var quote: Character? = nil
        for i in 0..<chars.count {
            let ch = chars[i]
            if let q = quote { if ch == q { quote = nil }; continue }
            if ch == "\"" || ch == "'" { quote = ch; continue }
            if ch == ":" && (i + 1 == chars.count || chars[i + 1] == " ") {
                return (unquote(String(chars[..<i])), String(chars[(i + 1)...]).trimmingCharacters(in: .whitespaces))
            }
        }
        return nil
    }

    static func dispatchInputs(_ yaml: String) -> [GHInput] {
        var lines: [Line] = []
        for raw in yaml.components(separatedBy: .newlines) {
            let t = stripComment(raw)
            let trimmed = t.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            lines.append(Line(indent: t.prefix(while: { $0 == " " }).count, text: trimmed))
        }
        guard let wi = lines.firstIndex(where: { $0.text == "workflow_dispatch:" }) else { return [] }
        let base = lines[wi].indent
        var i = wi + 1
        var inputsIdx: Int?
        while i < lines.count, lines[i].indent > base {
            if lines[i].text == "inputs:" { inputsIdx = i; break }
            i += 1
        }
        guard let ii = inputsIdx else { return [] }
        let inIndent = lines[ii].indent

        var result: [GHInput] = []
        var cur: GHInput?
        var nameIndent: Int?
        var optionsMode = false
        var j = ii + 1
        while j < lines.count, lines[j].indent > inIndent {
            let l = lines[j]
            j += 1
            if nameIndent == nil { nameIndent = l.indent }
            guard let ni = nameIndent else { continue }
            if l.indent == ni {
                if let c = cur { result.append(c) }
                cur = splitKV(l.text).map { GHInput(name: $0.0) }
                optionsMode = false
            } else if l.indent > ni {
                if l.text.hasPrefix("- ") {
                    if optionsMode { cur?.options.append(unquote(String(l.text.dropFirst(2)))) }
                } else if let (k, v) = splitKV(l.text) {
                    optionsMode = false
                    switch k {
                    case "description": cur?.description = unquote(v)
                    case "required": cur?.required = v.lowercased() == "true"
                    case "default": cur?.defaultValue = unquote(v)
                    case "type": cur?.type = unquote(v).lowercased()
                    case "options":
                        if v.isEmpty { optionsMode = true }
                        else if v.hasPrefix("[") {
                            cur?.options = v.trimmingCharacters(in: CharacterSet(charactersIn: "[] "))
                                .split(separator: ",").map { unquote(String($0)) }.filter { !$0.isEmpty }
                        }
                    default: break
                    }
                }
            }
        }
        if let c = cur { result.append(c) }
        return result.filter { !$0.name.isEmpty }.map { inp in
            var x = inp
            if !x.options.isEmpty && x.type != "choice" { x.type = "choice" }
            if x.type == "choice" && x.defaultValue.isEmpty { x.defaultValue = x.options.first ?? "" }
            return x
        }
    }
}
