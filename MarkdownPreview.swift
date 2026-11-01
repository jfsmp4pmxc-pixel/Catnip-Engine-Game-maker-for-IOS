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

// MarkdownPreview.swift
// Trình xem Markdown kiểu GitHub (GFM): bảng, danh sách việc, code tô màu, hộp cảnh báo [!NOTE],
// chú thích cuối trang, emoji, link #muc-luc. Chạy hoàn toàn offline bằng WKWebView với các thư viện
// đóng gói trong Resources/Markdown (xem THIRD_PARTY_NOTICES.md).
//
// Ảnh và link tương đối trong dự án (vd ![](img/logo.png), [docs](docs/a.md)) được phục vụ qua
// scheme riêng "catnip-project://", chỉ đọc được file nằm trong thư mục dự án.

import UIKit
import WebKit
import UniformTypeIdentifiers

// MARK: - Dựng trang HTML

enum MarkdownPage {

    private static let libraries = ["markdown-it.min", "markdown-it-footnote.min",
                                    "markdown-it-emoji.min", "purify.min", "highlight.min"]
    private static var cache: [String: String] = [:]

    private static func resource(_ name: String, _ ext: String) -> String? {
        let key = name + "." + ext
        if let hit = cache[key] { return hit }
        guard let url = Bundle.main.url(forResource: name, withExtension: ext),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        cache[key] = text
        return text
    }

    /// Chuỗi JSON an toàn để nhúng trong <script>. JSONSerialization đổi "/" thành "\/" nên "</script>" không thoát được.
    private static func jsonString(_ s: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [s], options: []),
              let arr = String(data: data, encoding: .utf8), arr.count >= 2 else { return "\"\"" }
        return String(arr.dropFirst().dropLast())
    }

    /// Thay các @@TÊN@@ trong mẫu một lượt; nội dung được chèn vào không bị quét lại.
    private static func fill(_ template: String, _ values: [String: String]) -> String {
        let ns = template as NSString
        guard let re = try? NSRegularExpression(pattern: "@@([A-Z_]+)@@") else { return template }
        var out = ""
        var last = 0
        for m in re.matches(in: template, range: NSRange(location: 0, length: ns.length)) {
            out += ns.substring(with: NSRange(location: last, length: m.range.location - last))
            out += values[ns.substring(with: m.range(at: 1))] ?? ""
            last = m.range.location + m.range.length
        }
        return out + ns.substring(from: last)
    }

    private static func escapeHTML(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
    }

    /// Trang dự phòng khi thiếu tài nguyên: hiện văn bản gốc.
    private static func fallback(_ markdown: String, dark: Bool) -> String {
        let bg = dark ? "#0d1117" : "#ffffff", fg = dark ? "#e6edf3" : "#1f2328"
        return "<!DOCTYPE html><meta charset=utf-8><meta name=viewport content=\"width=device-width,initial-scale=1\">"
            + "<body style=\"margin:16px;background:\(bg);color:\(fg);font:14px -apple-system\">"
            + "<p>Không tìm thấy tài nguyên Markdown trong app, đang hiện văn bản gốc.</p>"
            + "<pre style=\"white-space:pre-wrap\">\(escapeHTML(markdown))</pre></body>"
    }

    static func html(markdown: String, dark: Bool, anchor: String?) -> String {
        guard let template = resource("markdown-template", "html"),
              let glue = resource("catnip-markdown", "js"),
              let css = resource(dark ? "github-markdown-dark" : "github-markdown-light", "css"),
              let hlcss = resource(dark ? "hljs-github-dark.min" : "hljs-github.min", "css") else {
            return fallback(markdown, dark: dark)
        }
        // Thiếu thư viện nào thì glue tự rơi về hiện văn bản gốc.
        let libs = libraries.compactMap { resource($0, "js") }.joined(separator: "\n")
        let values: [String: String] = [
            "SCHEME": dark ? "dark" : "light",
            "NONCE": UUID().uuidString.replacingOccurrences(of: "-", with: ""),
            "BG": dark ? "#0d1117" : "#ffffff",
            "MARKDOWN_CSS": css,
            "HLJS_CSS": hlcss,
            "SOURCE_JSON": jsonString(markdown),
            "ANCHOR_JSON": jsonString(anchor ?? ""),
            "LIBS": libs,
            "GLUE": glue
        ]
        return fill(template, values)
    }

    static func backgroundColor(dark: Bool) -> UIColor {
        dark ? UIColor(red: 13 / 255, green: 17 / 255, blue: 23 / 255, alpha: 1) : .white
    }
}

// MARK: - Phục vụ file của dự án cho WebView

final class ProjectSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "catnip-project"
    private let project: String

    init(project: String) { self.project = project }

    static func url(forPath rel: String) -> URL? {
        var c = URLComponents()
        c.scheme = scheme
        c.host = "local"
        c.path = "/" + rel
        return c.url
    }

    /// Đường dẫn tương đối trong dự án (đã giải mã phần trăm), hoặc nil nếu không phải link của dự án.
    static func relativePath(from url: URL) -> String? {
        guard url.scheme == scheme else { return nil }
        let p = url.path
        return p.hasPrefix("/") ? String(p.dropFirst()) : p
    }

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url,
              let rel = Self.relativePath(from: url),
              ProjectStore.isValidRelativePath(rel) else {
            task.didFailWithError(URLError(.badURL))
            return
        }
        let base = ProjectStore.shared.projectURL(project).standardizedFileURL
        let file = base.appendingPathComponent(rel).standardizedFileURL
        // Chặn thoát khỏi thư mục dự án (.., symlink...).
        guard file.path.hasPrefix(base.path + "/"),
              let data = try? Data(contentsOf: file) else {
            task.didFailWithError(URLError(.fileDoesNotExist))
            return
        }
        let mime = UTType(filenameExtension: file.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        task.didReceive(URLResponse(url: url, mimeType: mime, expectedContentLength: data.count, textEncodingName: nil))
        task.didReceive(data)
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}
}

// MARK: - Màn hình xem

final class MarkdownPreviewViewController: UIViewController, WKNavigationDelegate {

    private let project: String
    private var path: String
    private var text: String
    private var history: [(path: String, text: String)] = []
    private var webView: WKWebView!
    private var backItem: UIBarButtonItem!

    /// Gọi khi người dùng bấm link tới file văn bản khác (không phải .md): editor sẽ mở file đó.
    var onOpenFile: ((String) -> Void)?

    init(project: String, path: String, text: String) {
        self.project = project
        self.path = path
        self.text = text
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { NotificationCenter.default.removeObserver(self) }

    override func viewDidLoad() {
        super.viewDidLoad()

        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(ProjectSchemeHandler(project: project), forURLScheme: ProjectSchemeHandler.scheme)
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.isOpaque = false
        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done, target: self, action: #selector(doneTapped))
        backItem = UIBarButtonItem(image: UIImage(systemName: "chevron.backward"),
                                   style: .plain, target: self, action: #selector(backTapped))

        NotificationCenter.default.addObserver(self, selector: #selector(themeChanged),
                                               name: .catnipSettingsChanged, object: nil)
        render(anchor: nil)
    }

    @objc private func themeChanged() { render(anchor: nil) }
    @objc private func doneTapped() { dismiss(animated: true) }

    @objc private func backTapped() {
        guard let prev = history.popLast() else { return }
        path = prev.path
        text = prev.text
        render(anchor: nil)
    }

    private func render(anchor: String?) {
        let dark = Appearance.theme.isDark
        Appearance.style(navigationController)
        let bg = MarkdownPage.backgroundColor(dark: dark)
        view.backgroundColor = bg
        webView.backgroundColor = bg
        webView.scrollView.backgroundColor = bg
        title = (path as NSString).lastPathComponent
        navigationItem.leftBarButtonItem = history.isEmpty ? nil : backItem
        let html = MarkdownPage.html(markdown: text, dark: dark, anchor: anchor)
        webView.loadHTMLString(html, baseURL: ProjectSchemeHandler.url(forPath: path))
    }

    private func isMarkdown(_ rel: String) -> Bool {
        ["md", "markdown", "mdown"].contains((rel as NSString).pathExtension.lowercased())
    }

    private func open(relativePath rel: String, anchor: String?) {
        let store = ProjectStore.shared
        guard store.isTextFile(project: project, path: rel),
              let content = store.read(project: project, path: rel) else {
            let ac = UIAlertController(title: "Không mở được", message: rel, preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default))
            present(ac, animated: true)
            return
        }
        if isMarkdown(rel) {
            history.append((path, text))
            path = rel
            text = content
            render(anchor: anchor)
        } else {
            let handler = onOpenFile
            dismiss(animated: true) { handler?(rel) }
        }
    }

    // MARK: WKNavigationDelegate

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // Lần nạp trang của chính mình (loadHTMLString) không phải do người dùng bấm link.
        guard action.navigationType == .linkActivated, let url = action.request.url else {
            decisionHandler(action.navigationType == .other ? .allow : .cancel)
            return
        }
        decisionHandler(.cancel)

        switch url.scheme?.lowercased() {
        case "http", "https", "mailto", "tel":
            UIApplication.shared.open(url)
        case ProjectSchemeHandler.scheme:
            if let rel = ProjectSchemeHandler.relativePath(from: url), !rel.isEmpty, rel != path {
                open(relativePath: rel, anchor: url.fragment)
            }
        default:
            break
        }
    }
}
