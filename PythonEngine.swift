// PythonEngine.swift — chạy dự án Python bằng CPython nhúng (native), stdout/stderr/stdin qua pipe giống CppEngine.
// Chưa build/kiểm chứng.

import Foundation

final class PythonEngine {
    static let shared = PythonEngine()

    private(set) var running = false
    private let inLock = NSLock()
    private var stdinWrite: Int32 = -1

    /// Bản build có nhúng CPython không.
    static var isAvailable: Bool {
        #if CATNIP_HAS_PYTHON
        return CatnipPython.isAvailable()
        #else
        return false
        #endif
    }

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

    /// File chạy: main.py nếu có, không thì file .py đầu tiên ở gốc dự án.
    static func entryScript(in project: URL) -> URL? {
        let main = project.appendingPathComponent("main.py")
        if FileManager.default.fileExists(atPath: main.path) { return main }
        let items = (try? FileManager.default.contentsOfDirectory(at: project, includingPropertiesForKeys: nil)) ?? []
        return items.filter { $0.pathExtension.lowercased() == "py" }.sorted { $0.lastPathComponent < $1.lastPathComponent }.first
    }

    func run(project: URL, onOutput: @escaping (String) -> Void, onFinish: @escaping (Result<Int32, Error>) -> Void) {
        #if CATNIP_HAS_PYTHON
        guard !running else { onFinish(.failure(ToolchainError("Một chương trình Python đang chạy."))); return }
        guard let script = Self.entryScript(in: project) else {
            onFinish(.failure(ToolchainError("Dự án chưa có file .py (cần main.py)."))); return
        }
        var inPipe: [Int32] = [0, 0], outPipe: [Int32] = [0, 0]
        guard pipe(&inPipe) == 0, pipe(&outPipe) == 0 else { onFinish(.failure(ToolchainError("Không tạo được pipe."))); return }
        let saved = (dup(0), dup(1), dup(2))
        dup2(inPipe[0], 0); dup2(outPipe[1], 1); dup2(outPipe[1], 2)
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

        let t = Thread { [self] in
            var err: NSString?
            let code = CatnipPython.run(script: script.path, directory: project.path, error: &err)
            fflush(nil)
            dup2(saved.0, 0); dup2(saved.1, 1); dup2(saved.2, 2)
            close(saved.0); close(saved.1); close(saved.2)
            close(outPipe[1])
            close(inPipe[0])
            closeInput()
            running = false
            DispatchQueue.main.async {
                if code < 0 {
                    onFinish(.failure(ToolchainError((err as String?) ?? "Không chạy được Python.")))
                } else {
                    onFinish(.success(code))
                }
            }
        }
        t.stackSize = 16 << 20
        t.start()
        #else
        onFinish(.failure(ToolchainError("Bản build này không nhúng CPython (bật with_python khi chạy workflow \"Build iOS IPA\").")))
        #endif
    }
}
