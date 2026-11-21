// ClangToolchain.swift
// Clang++ cho dự án C++: KHÔNG nhúng trong IPA mà tải về ở bước setup (để IPA nhẹ), cất ở
// Application Support/Catnip/Clang. Gói tải về là file .tar.z (tar nén deflate thô) do workflow
// "Build Clang toolchain" tạo (tools/build_clang_pack.sh). Trong gói có lib/libcatnipclang.dylib
// (Clang Interpreter + ORC JIT, API C: catnip_clang_run), sysroot/ (header iOS SDK + libc++),
// resource/ (header của clang) và include/ (SDL3...).
// Chạy mã JIT trên iOS cần quyền JIT cho app (TrollStore, hoặc bật JIT qua AltStore/SideStore); thiếu thì báo lỗi rõ ràng.
// Chưa build/kiểm chứng.

import UIKit
import Compression
import Darwin

enum ClangToolchain {
    static let defaultPackURL = "https://github.com/jfsmp4pmxc-pixel/Catnip-Engine-Game-maker-for-IOS/releases/download/clang-toolchain/catnip-clang-ios-arm64.tar.z"

    static var dir: URL { CatnipPaths.root.appendingPathComponent("Clang", isDirectory: true) }
    static var libraryURL: URL { dir.appendingPathComponent("lib/libcatnipclang.dylib") }
    static var sysrootURL: URL { dir.appendingPathComponent("sysroot", isDirectory: true) }
    static var resourceURL: URL { dir.appendingPathComponent("resource", isDirectory: true) }
    static var includeURL: URL { dir.appendingPathComponent("include", isDirectory: true) }
    static var isInstalled: Bool { FileManager.default.fileExists(atPath: libraryURL.path) }

    static var packURL: URL? {
        let custom = SettingsStore.shared.settings.clangPackURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return URL(string: custom.isEmpty ? defaultPackURL : custom)
    }

    static func uninstall() {
        CppEngine.shared.unload()
        try? FileManager.default.removeItem(at: dir)
    }

    // MARK: Cài đặt

    private static var activeInstaller: ClangInstaller?

    /// Tải gói, giải nén vào `dir`. `progress` (0...1, thông điệp) và `completion` gọi trên main thread.
    static func install(progress: @escaping (Double, String) -> Void,
                        completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = packURL else {
            completion(.failure(ToolchainError("Địa chỉ gói Clang không hợp lệ (Cài đặt → Công cụ → Clang++).")))
            return
        }
        let inst = ClangInstaller(url: url, progress: progress) { result in
            activeInstaller = nil
            completion(result)
        }
        activeInstaller = inst
        inst.start()
    }

    static func cancelInstall() {
        activeInstaller?.cancel()
        activeInstaller = nil
    }
}

struct ToolchainError: LocalizedError {
    let message: String
    init(_ m: String) { message = m }
    var errorDescription: String? { message }
}

private final class ClangInstaller: NSObject, URLSessionDownloadDelegate {
    private let url: URL
    private let progress: (Double, String) -> Void
    private let completion: (Result<Void, Error>) -> Void
    private var session: URLSession?
    private var task: URLSessionDownloadTask?
    private var cancelled = false

    init(url: URL, progress: @escaping (Double, String) -> Void, completion: @escaping (Result<Void, Error>) -> Void) {
        self.url = url
        self.progress = progress
        self.completion = completion
    }

    func start() {
        progress(0, "Đang tải Clang++…")
        let s = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        session = s
        task = s.downloadTask(with: url)
        task?.resume()
    }

    func cancel() {
        cancelled = true
        task?.cancel()
        session?.invalidateAndCancel()
    }

    private func report(_ f: Double, _ m: String) { DispatchQueue.main.async { self.progress(f, m) } }
    private func finish(_ r: Result<Void, Error>) {
        session?.finishTasksAndInvalidate()
        DispatchQueue.main.async { if !self.cancelled { self.completion(r) } }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let mb = Double(totalBytesWritten) / 1_048_576
        if totalBytesExpectedToWrite > 0 {
            let f = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            report(f * 0.6, String(format: "Đang tải Clang++… %.0f / %.0f MB", mb, Double(totalBytesExpectedToWrite) / 1_048_576))
        } else {
            report(0.3, String(format: "Đang tải Clang++… %.0f MB", mb))
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        if let http = downloadTask.response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            finish(.failure(ToolchainError("Không tải được gói Clang (HTTP \(http.statusCode)). Gói chỉ có sau khi chạy workflow \"Build Clang toolchain\".")))
            return
        }
        // Chuyển file ra khỏi thư mục tạm của URLSession trước khi hàm này trả về.
        let fm = FileManager.default
        let packed = fm.temporaryDirectory.appendingPathComponent("catnip-clang-\(UUID().uuidString).tar.z")
        do { try fm.moveItem(at: location, to: packed) } catch { finish(.failure(error)); return }
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let tar = fm.temporaryDirectory.appendingPathComponent("catnip-clang-\(UUID().uuidString).tar")
            let staging = ClangToolchain.dir.deletingLastPathComponent().appendingPathComponent("Clang.installing", isDirectory: true)
            defer { try? fm.removeItem(at: packed); try? fm.removeItem(at: tar) }
            do {
                report(0.6, "Đang giải nén…")
                try Self.inflate(packed, to: tar) { f in self.report(0.6 + f * 0.15, "Đang giải nén…") }
                try? fm.removeItem(at: staging)
                try fm.createDirectory(at: staging, withIntermediateDirectories: true)
                try Self.untar(tar, into: staging) { f in self.report(0.75 + f * 0.25, "Đang chép file…") }
                guard fm.fileExists(atPath: staging.appendingPathComponent("lib/libcatnipclang.dylib").path) else {
                    throw ToolchainError("Gói Clang thiếu lib/libcatnipclang.dylib.")
                }
                CppEngine.shared.unload()
                try? fm.removeItem(at: ClangToolchain.dir)
                try fm.moveItem(at: staging, to: ClangToolchain.dir)
                finish(.success(()))
            } catch {
                try? fm.removeItem(at: staging)
                finish(.failure(error))
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error, !cancelled { finish(.failure(error)) }
    }

    // MARK: Giải nén (deflate thô → tar → file)

    static func inflate(_ src: URL, to dst: URL, progress: (Double) -> Void) throws {
        let fm = FileManager.default
        fm.createFile(atPath: dst.path, contents: nil)
        let input = try FileHandle(forReadingFrom: src)
        let output = try FileHandle(forWritingTo: dst)
        defer { try? input.close(); try? output.close() }
        let total = Double((try? src.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 1)
        let bufSize = 1 << 20
        let outBuf = UnsafeMutablePointer<UInt8>.allocate(capacity: bufSize)
        let dummy = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
        defer { outBuf.deallocate(); dummy.deallocate() }

        var stream = compression_stream(dst_ptr: outBuf, dst_size: bufSize, src_ptr: UnsafePointer(dummy), src_size: 0, state: nil)
        guard compression_stream_init(&stream, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB) == COMPRESSION_STATUS_OK else {
            throw ToolchainError("Không khởi tạo được bộ giải nén.")
        }
        defer { compression_stream_destroy(&stream) }

        var read = 0.0
        var ended = false
        while !ended {
            let chunk = try input.read(upToCount: bufSize) ?? Data()
            let eof = chunk.isEmpty
            read += Double(chunk.count)
            progress(min(read / max(total, 1), 1))
            try chunk.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
                stream.src_ptr = raw.bindMemory(to: UInt8.self).baseAddress ?? UnsafePointer(dummy)
                stream.src_size = chunk.count
                var spins = 0
                while true {
                    let flags: Int32 = eof ? Int32(COMPRESSION_STREAM_FINALIZE.rawValue) : 0
                    let status = compression_stream_process(&stream, flags)
                    if status == COMPRESSION_STATUS_ERROR { throw ToolchainError("Gói Clang bị lỗi (giải nén thất bại).") }
                    let produced = bufSize - stream.dst_size
                    if produced > 0 {
                        try output.write(contentsOf: Data(bytes: outBuf, count: produced))
                        stream.dst_ptr = outBuf
                        stream.dst_size = bufSize
                        spins = 0
                    } else { spins += 1 }
                    if status == COMPRESSION_STATUS_END { ended = true; break }
                    if !eof && stream.src_size == 0 && produced < bufSize { break }
                    if eof && spins > 3 { ended = true; break }
                }
            }
        }
    }

    private static func octal(_ d: Data) -> Int {
        let s = String(decoding: d.filter { $0 != 0 && $0 != 0x20 }, as: UTF8.self)
        return Int(s, radix: 8) ?? 0
    }

    private static func cString(_ d: Data) -> String {
        String(decoding: d.prefix { $0 != 0 }, as: UTF8.self)
    }

    /// Giải nén tar (ustar/GNU, có tên dài kiểu 'L'). Từ chối đường dẫn tuyệt đối hoặc chứa "..".
    static func untar(_ tar: URL, into root: URL, progress: (Double) -> Void) throws {
        let fm = FileManager.default
        let h = try FileHandle(forReadingFrom: tar)
        defer { try? h.close() }
        let total = Double((try? tar.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 1)
        var pos = 0.0
        var longName: String?

        func skip(_ n: Int) throws {
            if n > 0 { try h.seek(toOffset: try h.offset() + UInt64(n)) }
        }

        while true {
            guard let hdr = try h.read(upToCount: 512), hdr.count == 512 else { break }
            pos += 512
            if hdr.allSatisfy({ $0 == 0 }) { break }
            var name = cString(hdr.subdata(in: 0..<100))
            let size = octal(hdr.subdata(in: 124..<136))
            let mode = octal(hdr.subdata(in: 100..<108))
            let type = hdr[156]
            let link = cString(hdr.subdata(in: 157..<257))
            let padded = (size + 511) / 512 * 512

            if type == UInt8(ascii: "L") {
                let data = try h.read(upToCount: size) ?? Data()
                longName = cString(data)
                try skip(padded - size)
                pos += Double(padded)
                continue
            }
            if type == UInt8(ascii: "x") || type == UInt8(ascii: "g") {
                try skip(padded); pos += Double(padded); continue
            }
            if let ln = longName { name = ln; longName = nil }

            let parts = name.split(separator: "/", omittingEmptySubsequences: true).map(String.init).filter { $0 != "." }
            guard !name.hasPrefix("/"), !parts.contains("..") else {
                try skip(padded); pos += Double(padded); continue
            }
            let dest = parts.reduce(root) { $0.appendingPathComponent($1) }

            switch type {
            case UInt8(ascii: "5"):
                try fm.createDirectory(at: dest, withIntermediateDirectories: true)
            case UInt8(ascii: "2"):
                try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? fm.removeItem(at: dest)
                try fm.createSymbolicLink(atPath: dest.path, withDestinationPath: link)
            case UInt8(ascii: "0"), 0:
                try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
                fm.createFile(atPath: dest.path, contents: nil)
                let out = try FileHandle(forWritingTo: dest)
                var left = size
                while left > 0 {
                    let part = try h.read(upToCount: min(left, 1 << 20)) ?? Data()
                    if part.isEmpty { break }
                    try out.write(contentsOf: part)
                    left -= part.count
                }
                try out.close()
                try skip(padded - size)
                if mode != 0 { try? fm.setAttributes([.posixPermissions: mode & 0o777], ofItemAtPath: dest.path) }
            default:
                try skip(padded)
            }
            pos += Double(padded)
            progress(min(pos / max(total, 1), 1))
        }
    }
}

// MARK: - Động cơ chạy C++ (nạp libcatnipclang.dylib bằng dlopen)

final class CppEngine {
    static let shared = CppEngine()

    // int catnip_clang_run(const char *resource_dir, const char *sysroot,
    //                      const char *flags_nl, const char *sources_nl, char *err, int errlen)
    private typealias RunFn = @convention(c) (UnsafePointer<CChar>?, UnsafePointer<CChar>?, UnsafePointer<CChar>?,
                                              UnsafePointer<CChar>?, UnsafeMutablePointer<CChar>?, Int32) -> Int32

    private var handle: UnsafeMutableRawPointer?
    private var runFn: RunFn?
    private(set) var running = false

    private let inLock = NSLock()
    private var stdinWrite: Int32 = -1

    func unload() {
        if let h = handle { dlclose(h) }
        handle = nil; runFn = nil
    }

    private func load() throws {
        if runFn != nil { return }
        guard ClangToolchain.isInstalled else {
            throw ToolchainError("Chưa cài Clang++. Vào Cài đặt → Công cụ → Clang++ để tải.")
        }
        guard let h = dlopen(ClangToolchain.libraryURL.path, RTLD_NOW | RTLD_GLOBAL) else {
            let why = dlerror().map { String(cString: $0) } ?? "không rõ"
            throw ToolchainError("Không nạp được Clang (\(why)).\nCần app có quyền JIT / nạp thư viện ngoài (TrollStore, hoặc bật JIT qua AltStore/SideStore).")
        }
        guard let sym = dlsym(h, "catnip_clang_run") else {
            dlclose(h)
            throw ToolchainError("Gói Clang không đúng phiên bản (thiếu catnip_clang_run).")
        }
        handle = h
        runFn = unsafeBitCast(sym, to: RunFn.self)
    }

    /// Ghi vào stdin của chương trình đang chạy.
    func sendInput(_ s: String) {
        inLock.lock(); defer { inLock.unlock() }
        guard stdinWrite >= 0 else { return }
        let bytes = Array(s.utf8)
        _ = bytes.withUnsafeBytes { write(stdinWrite, $0.baseAddress, bytes.count) }
    }

    /// Đóng stdin (chương trình đọc tới EOF).
    func closeInput() {
        inLock.lock(); defer { inLock.unlock() }
        if stdinWrite >= 0 { close(stdinWrite); stdinWrite = -1 }
    }

    static func sources(in project: URL) -> [String] {
        let fm = FileManager.default
        guard let en = fm.enumerator(at: project, includingPropertiesForKeys: nil,
                                     options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { return [] }
        var out: [String] = []
        for case let u as URL in en where ["cpp", "cc", "cxx", "c++"].contains(u.pathExtension.lowercased()) {
            out.append(u.path)
        }
        // main.cpp chạy cuối: các file khác định nghĩa hàm trước.
        out.sort { a, b in
            let am = (a as NSString).lastPathComponent.hasPrefix("main."), bm = (b as NSString).lastPathComponent.hasPrefix("main.")
            return am == bm ? a < b : !am
        }
        return out
    }

    /// Chạy dự án. `usesMainThread`: chương trình GUI (SDL) phải chạy ở main thread của iOS.
    /// `onOutput` gọi từ thread nền; `onFinish` gọi trên main thread với mã thoát (hoặc lỗi).
    func run(project: URL, onOutput: @escaping (String) -> Void, onFinish: @escaping (Result<Int32, Error>) -> Void) {
        guard !running else { onFinish(.failure(ToolchainError("Một chương trình C++ đang chạy."))); return }
        do { try load() } catch { onFinish(.failure(error)); return }
        let files = Self.sources(in: project)
        guard !files.isEmpty else { onFinish(.failure(ToolchainError("Dự án chưa có file .cpp (cần main.cpp)."))); return }
        let gui = files.contains { (try? String(contentsOfFile: $0, encoding: .utf8))?.contains("SDL") == true }

        var flags = ["-std=c++20", "-target", "arm64-apple-ios15.0", "-I" + project.path, "-I" + ClangToolchain.includeURL.path]
        if gui { flags.append("-I" + ClangToolchain.includeURL.appendingPathComponent("SDL3").path) }
        let flagsNL = flags.joined(separator: "\n")
        let sourcesNL = files.joined(separator: "\n")
        guard let fn = runFn else { return }

        // stdin/stdout/stderr của chương trình đi qua pipe (mã JIT dùng chung stdio của app).
        var inPipe: [Int32] = [0, 0], outPipe: [Int32] = [0, 0]
        guard pipe(&inPipe) == 0, pipe(&outPipe) == 0 else { onFinish(.failure(ToolchainError("Không tạo được pipe."))); return }
        let saved = (dup(0), dup(1), dup(2))
        dup2(inPipe[0], 0); dup2(outPipe[1], 1); dup2(outPipe[1], 2)
        setvbuf(stdout, nil, _IONBF, 0)
        setvbuf(stderr, nil, _IONBF, 0)
        inLock.lock(); stdinWrite = inPipe[1]; inLock.unlock()
        running = true

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

        let work = { [self] in
            var err = [CChar](repeating: 0, count: 2048)
            let code: Int32 = ClangToolchain.resourceURL.path.withCString { res in
                ClangToolchain.sysrootURL.path.withCString { sys in
                    flagsNL.withCString { fl in
                        sourcesNL.withCString { src in
                            fn(res, sys, fl, src, &err, Int32(err.count))
                        }
                    }
                }
            }
            fflush(nil)
            dup2(saved.0, 0); dup2(saved.1, 1); dup2(saved.2, 2)
            close(saved.0); close(saved.1); close(saved.2)
            close(outPipe[1])            // reader thấy EOF
            close(inPipe[0])
            closeInput()
            let message = String(cString: err)
            running = false
            DispatchQueue.main.async {
                if code < 0 || (!message.isEmpty && code != 0 && code > 255) {
                    onFinish(.failure(ToolchainError(message.isEmpty ? "Biên dịch thất bại (mã \(code))." : message)))
                } else {
                    if !message.isEmpty { onOutput(message + "\n") }
                    onFinish(.success(code))
                }
            }
        }
        if gui {
            DispatchQueue.main.async(execute: work)
        } else {
            let t = Thread(block: work)
            t.stackSize = 64 << 20
            t.start()
        }
    }
}
