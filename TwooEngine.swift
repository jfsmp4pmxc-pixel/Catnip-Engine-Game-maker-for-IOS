// TwooEngine.swift — chạy dự án TwooLang (.2o) native: trình biên dịch nhúng (TwooLang/) sinh ảnh arm64,
// rồi chạy ngay trong tiến trình app (JIT, cần quyền như Clang++). stdout/stderr/stdin qua pipe giống PythonEngine.
// Chưa build/kiểm chứng trên thiết bị (backend arm64 đã được thử trên trình mô phỏng tools/a64emu.py).

import Foundation
import UIKit

/// Thư viện TwooLang do người dùng tải về (2oLang_Objs): Application Support/Catnip/2oLib/*.2o.
enum TwooLibraries {
    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Catnip/2oLib", isDirectory: true)
    }

    static var installed: [String] {
        let items = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return items.filter { $0.hasSuffix(".2o") }.map { String($0.dropLast(3)) }.sorted()
    }

    /// Tải/cập nhật thư viện từ github.com/Twoo-Studio/2oLang_Objs (thư mục Lib/, nếu không có thì gốc repo).
    static func update(completion: @escaping (Result<String, Error>) -> Void) {
        let fm = FileManager.default
        try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
        func get(_ url: String, _ done: @escaping (Data?) -> Void) {
            var req = URLRequest(url: URL(string: url)!)
            req.setValue("Catnip", forHTTPHeaderField: "User-Agent")
            req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            URLSession.shared.dataTask(with: req) { data, resp, _ in
                done((resp as? HTTPURLResponse)?.statusCode == 200 ? data : nil)
            }.resume()
        }
        func parse(_ data: Data) -> [(String, String)] {
            guard let arr = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else { return [] }
            return arr.compactMap { e in
                guard let name = e["name"] as? String, name.hasSuffix(".2o"), let u = e["download_url"] as? String else { return nil }
                return (name, u)
            }
        }
        let api = "https://api.github.com/repos/Twoo-Studio/2oLang_Objs/contents"
        get(api + "/Lib") { data in
            let first = data.map(parse) ?? []
            let proceed: ([(String, String)]) -> Void = { files in
                guard !files.isEmpty else {
                    DispatchQueue.main.async { completion(.failure(ToolchainError("Không tải được danh sách thư viện (kiểm tra mạng, hoặc đã hết giới hạn GitHub API).")) ) }
                    return
                }
                var added = 0, updated = 0, same = 0, failed = 0
                let group = DispatchGroup()
                let lock = NSLock()
                for (name, url) in files {
                    group.enter()
                    get(url) { body in
                        defer { group.leave() }
                        lock.lock(); defer { lock.unlock() }
                        guard let body = body else { failed += 1; return }
                        let dst = directory.appendingPathComponent(name)
                        let old = try? Data(contentsOf: dst)
                        if old == body { same += 1; return }
                        do { try body.write(to: dst, options: .atomic); if old == nil { added += 1 } else { updated += 1 } }
                        catch { failed += 1 }
                    }
                }
                group.notify(queue: .main) {
                    completion(.success("\(added) mới, \(updated) cập nhật, \(same) không đổi" + (failed > 0 ? ", \(failed) lỗi" : "")))
                }
            }
            if first.isEmpty { get(api) { d2 in proceed(d2.map(parse) ?? []) } } else { proceed(first) }
        }
    }
}

extension TwooLibraries {
    /// Hộp thoại: liệt kê thư viện đã tải, bấm "Cập nhật" để tải từ 2oLang_Objs.
    static func presentManager(from vc: UIViewController?) {
        guard let vc = vc else { return }
        let have = installed
        let msg = "Thư viện nhúng sẵn: CioStyle.\n"
            + (have.isEmpty ? "Chưa tải thư viện nào." : "Đã tải: " + have.joined(separator: ", ") + ".")
            + "\nDùng trong code: #import <Tên>. Nguồn: github.com/Twoo-Studio/2oLang_Objs"
        let ac = UIAlertController(title: "Thư viện TwooLang", message: msg, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "Cập nhật", style: .default) { [weak vc] _ in
            let wait = UIAlertController(title: "Đang tải…", message: nil, preferredStyle: .alert)
            vc?.present(wait, animated: true)
            update { result in
                wait.dismiss(animated: true) {
                    let done: UIAlertController
                    switch result {
                    case .success(let s): done = UIAlertController(title: "Xong", message: s, preferredStyle: .alert)
                    case .failure(let e): done = UIAlertController(title: "Không cập nhật được", message: e.localizedDescription, preferredStyle: .alert)
                    }
                    done.addAction(UIAlertAction(title: "OK", style: .default))
                    vc?.present(done, animated: true)
                }
            }
        })
        ac.addAction(UIAlertAction(title: "Đóng", style: .cancel))
        vc.present(ac, animated: true)
    }
}

final class TwooEngine {
    static let shared = TwooEngine()

    private(set) var running = false
    private let inLock = NSLock()
    private var stdinWrite: Int32 = -1

    /// Kích thước terminal báo cho system.console.size (NativeTerminal cập nhật khi đổi cỡ).
    var rows: Int32 = 24
    var cols: Int32 = 80

    func sendInput(_ s: String) {
        inLock.lock(); defer { inLock.unlock() }
        guard stdinWrite >= 0 else { return }
        let bytes = Array(s.utf8)
        _ = bytes.withUnsafeBytes { write(stdinWrite, $0.baseAddress, bytes.count) }
    }

    func closeInput() {
        inLock.lock(); defer { inLock.unlock() }
        if stdinWrite >= 0 { close(stdinWrite); stdinWrite = -1 }
    }

    /// File chạy: main.2o nếu có, không thì file .2o đầu tiên ở gốc dự án.
    static func entryFile(in project: URL) -> URL? {
        let main = project.appendingPathComponent("main.2o")
        if FileManager.default.fileExists(atPath: main.path) { return main }
        let items = (try? FileManager.default.contentsOfDirectory(at: project, includingPropertiesForKeys: nil)) ?? []
        return items.filter { $0.pathExtension.lowercased() == "2o" }.sorted { $0.lastPathComponent < $1.lastPathComponent }.first
    }

    func run(project: URL, onOutput: @escaping (String) -> Void, onFinish: @escaping (Result<Int32, Error>) -> Void) {
        guard !running else { onFinish(.failure(ToolchainError("Một chương trình TwooLang đang chạy."))); return }
        guard let entry = Self.entryFile(in: project) else {
            onFinish(.failure(ToolchainError("Dự án chưa có file .2o (cần main.2o)."))); return
        }
        var inPipe: [Int32] = [0, 0], outPipe: [Int32] = [0, 0]
        guard pipe(&inPipe) == 0, pipe(&outPipe) == 0 else { onFinish(.failure(ToolchainError("Không tạo được pipe."))); return }
        let saved = (dup(0), dup(1), dup(2))
        dup2(inPipe[0], 0); dup2(outPipe[1], 1); dup2(outPipe[1], 2)
        inLock.lock(); stdinWrite = inPipe[1]; inLock.unlock()
        running = true
        let (r, c) = (rows, cols)

        let readFd = outPipe[0]
        let reader = Thread {
            var buf = [UInt8](repeating: 0, count: 4096)
            while true {
                let n = read(readFd, &buf, buf.count)
                if n <= 0 { break }
                onOutput(String(decoding: buf[0..<n], as: UTF8.self))
            }
        }
        reader.start()

        let t = Thread { [self] in
            try? FileManager.default.createDirectory(at: TwooLibraries.directory, withIntermediateDirectories: true)
            let image = NSTemporaryDirectory() + "catnip-twoo-\(getpid()).bin"
            twoo_set_terminal(1, r, c)
            var code: Int32 = twoo_compile(entry.path, image, TwooLibraries.directory.path)
            var failedToRun = false
            if code == 0 {
                code = twoo_run_image(image)
                if code < 0 { failedToRun = true }
            } else {
                code = 1
            }
            try? FileManager.default.removeItem(atPath: image)
            fflush(nil)
            dup2(saved.0, 0); dup2(saved.1, 1); dup2(saved.2, 2)
            close(saved.0); close(saved.1); close(saved.2)
            close(outPipe[1])
            close(inPipe[0])
            closeInput()
            running = false
            DispatchQueue.main.async {
                if failedToRun { onFinish(.failure(ToolchainError("Không chạy được chương trình (xem thông báo ở trên)."))) }
                else { onFinish(.success(code)) }
            }
        }
        t.stackSize = 16 << 20
        t.start()
    }
}
