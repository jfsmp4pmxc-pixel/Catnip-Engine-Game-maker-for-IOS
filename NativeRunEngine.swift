// NativeRunEngine.swift — giao diện chung của các engine chạy chương trình native qua pipe (C++, Python, TwooLang).

import Foundation

protocol NativeRunEngine: AnyObject {
    var running: Bool { get }
    func sendInput(_ s: String)
    func closeInput()
    func run(project: URL, onOutput: @escaping (String) -> Void, onFinish: @escaping (Result<Int32, Error>) -> Void)
}

extension CppEngine: NativeRunEngine {}
extension PythonEngine: NativeRunEngine {}
extension TwooEngine: NativeRunEngine {}

enum NativeRunMode {
    case cpp, python, twoo

    var engine: NativeRunEngine {
        switch self {
        case .cpp: return CppEngine.shared
        case .python: return PythonEngine.shared
        case .twoo: return TwooEngine.shared
        }
    }

    var titlePrefix: String {
        switch self {
        case .cpp: return "C++ · "
        case .python: return "Python · "
        case .twoo: return "TwooLang · "
        }
    }
}
