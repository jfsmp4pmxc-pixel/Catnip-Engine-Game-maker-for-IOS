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

import Foundation

// MARK: - Paths

enum CatnipPaths {
    static let fm = FileManager.default

    static var root: URL {
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Catnip", isDirectory: true)
    }
    static var projects: URL { root.appendingPathComponent("Projects", isDirectory: true) }
    static var settingsFile: URL { root.appendingPathComponent("settings.json") }

    /// Tạo sẵn các thư mục cần thiết. Application Support nằm trong sandbox và được iOS sao lưu cùng thiết bị.
    static func prepare() {
        try? fm.createDirectory(at: projects, withIntermediateDirectories: true)
    }
}

// MARK: - Errors

enum StoreError: LocalizedError {
    case invalidName
    case alreadyExists
    case notFound
    case io(String)

    var errorDescription: String? {
        switch self {
        case .invalidName:   return "Tên không hợp lệ"
        case .alreadyExists: return "Đã tồn tại"
        case .notFound:      return "Không tìm thấy"
        case .io(let m):     return m
        }
    }
}

// MARK: - Settings

struct AppSettings: Codable {
    var themeName: String = "dark"
    var fontSize: Double = 14
    var lastProject: String?
    var lastFile: String?
    var expandedFolders: [String] = []

    init() {}

    /// Giải mã chịu lỗi: thiếu trường nào thì dùng mặc định, để thêm cài đặt mới sau này không làm mất cài đặt cũ.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        themeName       = try c.decodeIfPresent(String.self, forKey: .themeName) ?? "dark"
        fontSize        = try c.decodeIfPresent(Double.self, forKey: .fontSize) ?? 14
        lastProject     = try c.decodeIfPresent(String.self, forKey: .lastProject)
        lastFile        = try c.decodeIfPresent(String.self, forKey: .lastFile)
        expandedFolders = try c.decodeIfPresent([String].self, forKey: .expandedFolders) ?? []
    }
}

final class SettingsStore {
    static let shared = SettingsStore()

    private(set) var settings = AppSettings()
    private var pendingSave: DispatchWorkItem?

    private init() {
        CatnipPaths.prepare()
        load()
    }

    private func load() {
        guard let data = try? Data(contentsOf: CatnipPaths.settingsFile),
              let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) else { return }
        settings = decoded
    }

    /// Sửa cài đặt rồi tự lưu (gộp nhiều lần sửa liên tiếp thành một lần ghi).
    func update(_ change: (inout AppSettings) -> Void) {
        change(&settings)
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveNow() }
        pendingSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    func saveNow() {
        pendingSave?.cancel()
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? enc.encode(settings) else { return }
        try? data.write(to: CatnipPaths.settingsFile, options: .atomic)
    }
}

// MARK: - File entry (dùng cho cây thư mục)

struct FileEntry {
    let path: String        // đường dẫn tương đối trong dự án, vd "src/player.lua"
    let isFolder: Bool

    var name: String  { (path as NSString).lastPathComponent }
    var depth: Int    { path.split(separator: "/").count - 1 }
}

// MARK: - Project store

final class ProjectStore {
    static let shared = ProjectStore()
    private let fm = FileManager.default

    private init() { CatnipPaths.prepare() }

    // MARK: Validation

    /// Chỉ cho phép đường dẫn tương đối, không có ".." hay ký tự cấm, để không thoát khỏi sandbox dự án.
    static func isValidRelativePath(_ p: String) -> Bool {
        let parts = p.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard !p.isEmpty, !p.hasPrefix("/") else { return false }
        for part in parts {
            if part.isEmpty || part == "." || part == ".." { return false }
            if part.hasPrefix(".") { return false }
            if part.contains("\\") || part.contains(":") { return false }
        }
        return true
    }

    static func isValidProjectName(_ n: String) -> Bool {
        !n.contains("/") && isValidRelativePath(n)
    }

    // MARK: Projects

    func projectURL(_ name: String) -> URL {
        CatnipPaths.projects.appendingPathComponent(name, isDirectory: true)
    }

    func listProjects() -> [String] {
        let items = (try? fm.contentsOfDirectory(at: CatnipPaths.projects,
                                                 includingPropertiesForKeys: [.isDirectoryKey],
                                                 options: [.skipsHiddenFiles])) ?? []
        return items
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .map { $0.lastPathComponent }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    @discardableResult
    func createProject(_ name: String, withTemplate: Bool = true) throws -> String {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isValidProjectName(n) else { throw StoreError.invalidName }
        let url = projectURL(n)
        guard !fm.fileExists(atPath: url.path) else { throw StoreError.alreadyExists }
        do {
            try fm.createDirectory(at: url, withIntermediateDirectories: true)
            if withTemplate { try writeTemplate(into: url, title: n) }
        } catch {
            throw StoreError.io(error.localizedDescription)
        }
        return n
    }

    func renameProject(_ old: String, to new: String) throws {
        let n = new.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isValidProjectName(n) else { throw StoreError.invalidName }
        let dst = projectURL(n)
        guard !fm.fileExists(atPath: dst.path) else { throw StoreError.alreadyExists }
        do { try fm.moveItem(at: projectURL(old), to: dst) }
        catch { throw StoreError.io(error.localizedDescription) }
    }

    func deleteProject(_ name: String) throws {
        do { try fm.removeItem(at: projectURL(name)) }
        catch { throw StoreError.io(error.localizedDescription) }
    }

    /// Mẫu dự án LÖVE tối thiểu để chạy được ngay.
    private func writeTemplate(into url: URL, title: String) throws {
        let conf = """
        -- conf.lua : cấu hình LÖVE
        function love.conf(t)
          t.title = "\(title.replacingOccurrences(of: "\"", with: ""))"
          t.window.width = 960
          t.window.height = 540
        end
        """
        let main = """
        -- main.lua : điểm vào của game
        local x, y = 100, 100

        function love.load()
          love.graphics.setBackgroundColor(0.1, 0.1, 0.15)
        end

        function love.update(dt)
          if love.keyboard.isDown("right") then x = x + 200 * dt end
          if love.keyboard.isDown("left")  then x = x - 200 * dt end
          if love.keyboard.isDown("down")  then y = y + 200 * dt end
          if love.keyboard.isDown("up")    then y = y - 200 * dt end
        end

        function love.draw()
          love.graphics.setColor(1, 0.8, 0.2)
          love.graphics.circle("fill", x, y, 24)
          love.graphics.setColor(1, 1, 1)
          love.graphics.print("Hello Catnip!", 10, 10)
        end
        """
        try conf.write(to: url.appendingPathComponent("conf.lua"), atomically: true, encoding: .utf8)
        try main.write(to: url.appendingPathComponent("main.lua"), atomically: true, encoding: .utf8)
    }

    // MARK: Files

    private func fileURL(_ project: String, _ path: String) throws -> URL {
        guard Self.isValidRelativePath(path) else { throw StoreError.invalidName }
        return projectURL(project).appendingPathComponent(path)
    }

    func tree(project: String, expanded: Set<String>) -> [FileEntry] {
        var out: [FileEntry] = []
        func walk(_ rel: String) {
            let dir = rel.isEmpty ? projectURL(project) : projectURL(project).appendingPathComponent(rel)
            let items = (try? fm.contentsOfDirectory(at: dir,
                                                     includingPropertiesForKeys: [.isDirectoryKey],
                                                     options: [.skipsHiddenFiles])) ?? []
            var folders: [String] = [], files: [String] = []
            for u in items {
                let isDir = (try? u.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                if isDir { folders.append(u.lastPathComponent) } else { files.append(u.lastPathComponent) }
            }
            let cmp: (String, String) -> Bool = { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            for f in folders.sorted(by: cmp) {
                let p = rel.isEmpty ? f : rel + "/" + f
                out.append(FileEntry(path: p, isFolder: true))
                if expanded.contains(p) { walk(p) }
            }
            for f in files.sorted(by: cmp) {
                let p = rel.isEmpty ? f : rel + "/" + f
                out.append(FileEntry(path: p, isFolder: false))
            }
        }
        walk("")
        return out
    }

    /// Mọi file (không tính thư mục) trong dự án, kể cả trong thư mục đang thu gọn.
    func allFiles(project: String) -> [String] {
        let base = projectURL(project)
        guard let en = fm.enumerator(at: base,
                                     includingPropertiesForKeys: [.isDirectoryKey],
                                     options: [.skipsHiddenFiles]) else { return [] }
        var out: [String] = []
        let basePath = base.standardizedFileURL.path + "/"
        for case let url as URL in en {
            if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true { continue }
            let full = url.standardizedFileURL.path
            if full.hasPrefix(basePath) { out.append(String(full.dropFirst(basePath.count))) }
        }
        return out.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    func read(project: String, path: String) -> String? {
        guard let url = try? fileURL(project, path) else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    func write(project: String, path: String, content: String) throws {
        let url = try fileURL(project, path)
        do {
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try content.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw StoreError.io(error.localizedDescription)
        }
    }

    func createFile(project: String, path: String) throws {
        let url = try fileURL(project, path)
        guard !fm.fileExists(atPath: url.path) else { throw StoreError.alreadyExists }
        try write(project: project, path: path, content: "")
    }

    func createFolder(project: String, path: String) throws {
        let url = try fileURL(project, path)
        guard !fm.fileExists(atPath: url.path) else { throw StoreError.alreadyExists }
        do { try fm.createDirectory(at: url, withIntermediateDirectories: true) }
        catch { throw StoreError.io(error.localizedDescription) }
    }

    func rename(project: String, from: String, to: String) throws {
        let src = try fileURL(project, from)
        let dst = try fileURL(project, to)
        guard fm.fileExists(atPath: src.path) else { throw StoreError.notFound }
        guard !fm.fileExists(atPath: dst.path) else { throw StoreError.alreadyExists }
        do {
            try fm.createDirectory(at: dst.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fm.moveItem(at: src, to: dst)
        } catch { throw StoreError.io(error.localizedDescription) }
    }

    func delete(project: String, path: String) throws {
        let url = try fileURL(project, path)
        do { try fm.removeItem(at: url) }
        catch { throw StoreError.io(error.localizedDescription) }
    }
}
