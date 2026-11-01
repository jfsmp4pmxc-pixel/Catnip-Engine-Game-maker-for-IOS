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

// Fonts.swift
// Font do người dùng nhập (.ttf / .otf / .ttc) để dùng trong editor.
// File font được chép vào Application Support/Catnip/Fonts và đăng ký với CoreText mỗi lần mở app.

import UIKit
import CoreText

struct EditorFontInfo: Equatable {
    let postScriptName: String   // dùng để tạo UIFont và lưu trong settings.json
    let family: String
    let style: String
    let file: String             // tên file trong thư mục Fonts

    var displayName: String { style.isEmpty || style == "Regular" ? family : "\(family) \(style)" }
}

final class FontStore {
    static let shared = FontStore()

    private let fm = FileManager.default
    private var registered = Set<String>()
    private(set) var fonts: [EditorFontInfo] = []

    static let allowedExtensions: Set<String> = ["ttf", "otf", "ttc"]

    var directory: URL { CatnipPaths.root.appendingPathComponent("Fonts", isDirectory: true) }

    private init() {
        try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
        reload()
    }

    // MARK: Đọc thông tin font từ file

    private func descriptors(_ url: URL) -> [CTFontDescriptor] {
        (CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor]) ?? []
    }

    private func info(_ d: CTFontDescriptor, file: String) -> EditorFontInfo? {
        guard let ps = CTFontDescriptorCopyAttribute(d, kCTFontNameAttribute) as? String else { return nil }
        let family = (CTFontDescriptorCopyAttribute(d, kCTFontFamilyNameAttribute) as? String) ?? ps
        let style = (CTFontDescriptorCopyAttribute(d, kCTFontStyleNameAttribute) as? String) ?? ""
        return EditorFontInfo(postScriptName: ps, family: family, style: style, file: file)
    }

    /// Đăng ký font cho cả tiến trình. Đã đăng ký rồi thì coi như thành công.
    @discardableResult
    private func register(_ url: URL) -> Bool {
        if registered.contains(url.path) { return true }
        var error: Unmanaged<CFError>?
        let ok = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        if ok { registered.insert(url.path); return true }
        if let e = error?.takeRetainedValue(), CFErrorGetCode(e) == CTFontManagerError.alreadyRegistered.rawValue {
            registered.insert(url.path)
            return true
        }
        return false
    }

    func reload() {
        fonts = []
        let files = (try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil,
                                                 options: [.skipsHiddenFiles])) ?? []
        let sorted = files.sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
        for url in sorted where Self.allowedExtensions.contains(url.pathExtension.lowercased()) {
            guard register(url) else { continue }
            for d in descriptors(url) {
                if let i = info(d, file: url.lastPathComponent) { fonts.append(i) }
            }
        }
    }

    // MARK: Nhập / xoá

    /// Nhập một font từ ngoài vào. Ném lỗi nếu file không phải font hợp lệ.
    @discardableResult
    func importFont(from source: URL) throws -> EditorFontInfo {
        let ext = source.pathExtension.lowercased()
        guard Self.allowedExtensions.contains(ext) else {
            throw StoreError.io("Chỉ nhập được font .ttf, .otf hoặc .ttc")
        }
        guard !descriptors(source).isEmpty else {
            throw StoreError.io("File này không phải font hợp lệ")
        }

        var name = source.lastPathComponent
        for bad in ["/", ":", "\\"] { name = name.replacingOccurrences(of: bad, with: "_") }
        let base = (name as NSString).deletingPathExtension
        var candidate = name
        var n = 2
        while fm.fileExists(atPath: directory.appendingPathComponent(candidate).path) {
            candidate = "\(base) \(n).\(ext)"
            n += 1
        }
        let dest = directory.appendingPathComponent(candidate)
        do {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
            try fm.copyItem(at: source, to: dest)
        } catch {
            throw StoreError.io(error.localizedDescription)
        }
        guard register(dest), let first = descriptors(dest).compactMap({ info($0, file: candidate) }).first else {
            try? fm.removeItem(at: dest)
            throw StoreError.io("Không đăng ký được font này")
        }
        reload()
        return first
    }

    /// Xoá cả file font chứa font này (một .ttc có thể chứa nhiều font).
    func delete(_ font: EditorFontInfo) {
        let url = directory.appendingPathComponent(font.file)
        _ = CTFontManagerUnregisterFontsForURL(url as CFURL, .process, nil)
        registered.remove(url.path)
        try? fm.removeItem(at: url)
        reload()
    }

    func contains(postScriptName: String) -> Bool {
        fonts.contains { $0.postScriptName == postScriptName }
    }
}
