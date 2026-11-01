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
    var showLineNumbers: Bool = true
    var wrapLines: Bool = false      // false = không ngắt dòng (cuộn ngang)
    var lockPortrait: Bool = false   // true = luôn giữ chiều dọc (cả màn hình lẫn bàn phím)
    var fontName: String?            // PostScript name của font editor; nil = font hệ thống

    init() {}

    /// Giải mã chịu lỗi: thiếu trường nào thì dùng mặc định, để thêm cài đặt mới sau này không làm mất cài đặt cũ.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        themeName       = try c.decodeIfPresent(String.self, forKey: .themeName) ?? "dark"
        fontSize        = min(max(try c.decodeIfPresent(Double.self, forKey: .fontSize) ?? 14, 2), 32)
        lastProject     = try c.decodeIfPresent(String.self, forKey: .lastProject)
        lastFile        = try c.decodeIfPresent(String.self, forKey: .lastFile)
        expandedFolders = try c.decodeIfPresent([String].self, forKey: .expandedFolders) ?? []
        showLineNumbers = try c.decodeIfPresent(Bool.self, forKey: .showLineNumbers) ?? true
        wrapLines       = try c.decodeIfPresent(Bool.self, forKey: .wrapLines) ?? false
        lockPortrait    = try c.decodeIfPresent(Bool.self, forKey: .lockPortrait) ?? false
        fontName        = try c.decodeIfPresent(String.self, forKey: .fontName)
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

// MARK: - Project kind

enum ProjectKind: String, Codable, CaseIterable {
    case love, scratch, python

    var displayName: String {
        switch self {
        case .love:    return "LÖVE"
        case .scratch: return "Scratch"
        case .python:  return "Python"
        }
    }

    var summary: String {
        switch self {
        case .love:    return "Game 2D dùng LÖVE (Lua), chạy được ngay"
        case .scratch: return "Dự án bình thường, tự do tạo file"
        case .python:  return "Sắp ra mắt"
        }
    }

    var symbol: String {
        switch self {
        case .love:    return "gamecontroller.fill"
        case .scratch: return "doc.text"
        case .python:  return "chevron.left.forwardslash.chevron.right"
        }
    }

    /// Python chưa hỗ trợ (coming soon).
    var isAvailable: Bool { self != .python }
    /// Chỉ dự án LÖVE mới có nút Chạy.
    var canRun: Bool { self == .love }
}

private struct ProjectMeta: Codable { var kind: ProjectKind }

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
    func createProject(_ name: String, kind: ProjectKind = .love) throws -> String {
        guard kind.isAvailable else { throw StoreError.io("\(kind.displayName) sắp ra mắt") }
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isValidProjectName(n) else { throw StoreError.invalidName }
        let url = projectURL(n)
        guard !fm.fileExists(atPath: url.path) else { throw StoreError.alreadyExists }
        do {
            try fm.createDirectory(at: url, withIntermediateDirectories: true)
            try writeMeta(kind, into: url)
            switch kind {
            case .love:
                try writeTemplate(into: url, title: n)
            case .scratch:
                try "# \(n)\n".write(to: url.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
            case .python:
                break
            }
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

    /// Loại dự án, đọc từ .catnip.json (file ẩn). Dự án cũ chưa có file này thì đoán theo main.lua.
    func kind(of project: String) -> ProjectKind {
        let dir = projectURL(project)
        if let data = try? Data(contentsOf: dir.appendingPathComponent(".catnip.json")),
           let meta = try? JSONDecoder().decode(ProjectMeta.self, from: data) {
            return meta.kind
        }
        return fm.fileExists(atPath: dir.appendingPathComponent("main.lua").path) ? .love : .scratch
    }

    private func writeMeta(_ kind: ProjectKind, into dir: URL) throws {
        let data = try JSONEncoder().encode(ProjectMeta(kind: kind))
        try data.write(to: dir.appendingPathComponent(".catnip.json"), options: .atomic)
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

    /// Sao chép một file từ bên ngoài (ảnh, âm thanh, font...) vào dự án.
    /// Trùng tên thì thêm số (vd "hit 2.wav"). Trả về đường dẫn tương đối của file mới.
    func importFile(project: String, from source: URL, toFolder folder: String?) throws -> String {
        var name = source.lastPathComponent
        for bad in ["/", ":", "\\"] { name = name.replacingOccurrences(of: bad, with: "_") }
        while name.hasPrefix(".") { name.removeFirst() }
        guard !name.isEmpty else { throw StoreError.invalidName }

        let rel = folder ?? ""
        if !rel.isEmpty, !Self.isValidRelativePath(rel) { throw StoreError.invalidName }
        let dir = rel.isEmpty ? projectURL(project) : projectURL(project).appendingPathComponent(rel)

        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var candidate = name
        var n = 2
        while fm.fileExists(atPath: dir.appendingPathComponent(candidate).path) {
            candidate = ext.isEmpty ? "\(base) \(n)" : "\(base) \(n).\(ext)"
            n += 1
        }
        do {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            try fm.copyItem(at: source, to: dir.appendingPathComponent(candidate))
        } catch {
            throw StoreError.io(error.localizedDescription)
        }
        return rel.isEmpty ? candidate : rel + "/" + candidate
    }

    private static let binaryExtensions: Set<String> = [
        "png","jpg","jpeg","gif","bmp","tga","webp","ico","icns","dds","hdr",
        "wav","mp3","ogg","oga","flac","m4a","aac","mod","xm","it","s3m",
        "ttf","otf","ttc","woff","woff2","fnt",
        "love","zip","gz","7z","rar","pdf","mp4","mov","avi","bin","dat","so","a","dylib"
    ]

    /// Có nên mở file này như văn bản không (loại trừ file nhị phân và file quá lớn).
    func isTextFile(project: String, path: String) -> Bool {
        let ext = (path as NSString).pathExtension.lowercased()
        if Self.binaryExtensions.contains(ext) { return false }
        guard let url = try? fileURL(project, path),
              let size = (try? fm.attributesOfItem(atPath: url.path))?[.size] as? NSNumber else { return false }
        return size.intValue <= 2_000_000
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
