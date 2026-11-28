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


// Tài liệu LÖVE bằng tiếng Việt, đóng gói trong app (Resources/Docs/docs-*.md), đọc được khi không có mạng.
// Nút "?" trên thanh trên cùng mở màn hình này.

import UIKit
import WebKit

enum DocsCatalog {
    struct Topic { let title: String; let file: String; let symbol: String }
    /// Mục lớn: gom nhiều chương (mục nhỏ).
    struct Group { let title: String; let summary: String; let symbol: String; let topics: [Topic] }

    private static let allGroups: [Group] = [
        Group(title: "Làm game với LÖVE (Lua)", summary: "Lua, đồ hoạ, âm thanh, vật lý, shader, game mẫu", symbol: "gamecontroller", topics: [
            Topic(title: "Bắt đầu với LÖVE",          file: "docs-01-bat-dau",          symbol: "flag.checkered"),
            Topic(title: "Lua cơ bản",                file: "docs-02-lua-co-ban",       symbol: "book"),
            Topic(title: "Các hàm callback",          file: "docs-03-callback",         symbol: "arrow.triangle.2.circlepath"),
            Topic(title: "Đồ hoạ",                    file: "docs-04-do-hoa",           symbol: "paintbrush"),
            Topic(title: "Hình ảnh, sprite, hoạt ảnh", file: "docs-05-hinh-anh",        symbol: "photo"),
            Topic(title: "Âm thanh",                  file: "docs-06-am-thanh",         symbol: "speaker.wave.2"),
            Topic(title: "Bàn phím, chuột, cảm ứng",  file: "docs-07-nhap-lieu",        symbol: "hand.tap"),
            Topic(title: "Toán học và thời gian",     file: "docs-08-toan-thoi-gian",   symbol: "function"),
            Topic(title: "Va chạm tự làm",            file: "docs-09-va-cham",          symbol: "square.on.square"),
            Topic(title: "Vật lý (Box2D)",            file: "docs-10-vat-ly",           symbol: "circle.hexagongrid"),
            Topic(title: "File và lưu dữ liệu",       file: "docs-11-file-luu-du-lieu", symbol: "externaldrive"),
            Topic(title: "Shader",                    file: "docs-12-shader",           symbol: "sparkles"),
            Topic(title: "Cấu hình conf.lua",         file: "docs-13-conf",             symbol: "slider.horizontal.3"),
            Topic(title: "Game mẫu hoàn chỉnh",       file: "docs-14-game-mau",         symbol: "gamecontroller"),
            Topic(title: "Dùng trên iOS và Catnip",   file: "docs-15-ios-catnip",       symbol: "iphone"),
            Topic(title: "Gỡ lỗi và lỗi thường gặp", file: "docs-16-go-loi",           symbol: "ladybug")
        ]),
        Group(title: "Giao diện SwiftUI (dự án UI)", summary: "Phác thảo giao diện, bấm thử ngay", symbol: "rectangle.on.rectangle", topics: [
            Topic(title: "Dự án UI (SwiftUI)",        file: "docs-17-ui-swiftui",       symbol: "rectangle.on.rectangle"),
            Topic(title: "SwiftUI cơ bản",            file: "docs-18-swiftui-co-ban",   symbol: "square.stack.3d.up"),
            Topic(title: "Trạng thái và nhập liệu",   file: "docs-19-trang-thai-nhap-lieu", symbol: "slider.horizontal.3"),
            Topic(title: "Danh sách, điều hướng, tab", file: "docs-20-danh-sach-dieu-huong", symbol: "list.bullet.rectangle"),
            Topic(title: "Swift cho giao diện",       file: "docs-21-swift-cho-giao-dien", symbol: "swift"),
            Topic(title: "Mẫu phác thảo, tra cứu",    file: "docs-22-mau-phac-thao",    symbol: "doc.text.magnifyingglass")
        ]),
        Group(title: "C++ (giáo trình)", summary: "Từ biến, hàm đến con trỏ, lớp, template, STL", symbol: "chevron.left.forwardslash.chevron.right", topics: [
            Topic(title: "Dự án C++ trong Catnip",    file: "docs-24-cpp",              symbol: "terminal"),
            Topic(title: "1. Giới thiệu C++",         file: "docs-cpp-01-gioi-thieu",   symbol: "1.circle"),
            Topic(title: "2. Biến, kiểu, toán tử",    file: "docs-cpp-02-bien-kieu-toan-tu", symbol: "2.circle"),
            Topic(title: "3. Rẽ nhánh và vòng lặp",   file: "docs-cpp-03-dieu-khien",   symbol: "3.circle"),
            Topic(title: "4. Hàm",                    file: "docs-cpp-04-ham",          symbol: "4.circle"),
            Topic(title: "5. Mảng, vector, chuỗi",    file: "docs-cpp-05-mang-chuoi",   symbol: "5.circle"),
            Topic(title: "6. Con trỏ và bộ nhớ",      file: "docs-cpp-06-con-tro-bo-nho", symbol: "6.circle"),
            Topic(title: "7. Lớp và hướng đối tượng", file: "docs-cpp-07-lop-oop",      symbol: "7.circle"),
            Topic(title: "8. Template và STL",        file: "docs-cpp-08-template-stl", symbol: "8.circle"),
            Topic(title: "9. Lỗi, file, stream",      file: "docs-cpp-09-loi-file-stream", symbol: "9.circle"),
            Topic(title: "10. C++ hiện đại",          file: "docs-cpp-10-cpp-hien-dai", symbol: "10.circle"),
            Topic(title: "11. Nhiều file, header",    file: "docs-cpp-11-nhieu-file",   symbol: "11.circle"),
            Topic(title: "12. Gỡ lỗi",                file: "docs-cpp-12-go-loi",       symbol: "12.circle")
        ]),
        Group(title: "SDL3 (đồ hoạ, game bằng C++)", summary: "Cửa sổ, vẽ 2D, sự kiện, game loop, game mẫu", symbol: "display", topics: [
            Topic(title: "1. Cửa sổ và vòng lặp",     file: "docs-sdl-01-cua-so-vong-lap", symbol: "1.circle"),
            Topic(title: "2. Vẽ 2D",                  file: "docs-sdl-02-ve-2d",        symbol: "2.circle"),
            Topic(title: "3. Sự kiện, bàn phím, chuột, cảm ứng", file: "docs-sdl-03-su-kien-nhap-lieu", symbol: "3.circle"),
            Topic(title: "4. Ảnh và chữ",             file: "docs-sdl-04-anh-chu",      symbol: "4.circle"),
            Topic(title: "5. Âm thanh",               file: "docs-sdl-05-am-thanh",     symbol: "5.circle"),
            Topic(title: "6. Game loop và va chạm",   file: "docs-sdl-06-game-loop-va-cham", symbol: "6.circle"),
            Topic(title: "7. Game mẫu hoàn chỉnh",   file: "docs-sdl-07-game-mau",     symbol: "7.circle")
        ]),
        Group(title: "Python", summary: "Python native trong Catnip, numpy, pillow", symbol: "chevron.left.slash.chevron.right", topics: [
            Topic(title: "1. Giới thiệu Python",      file: "docs-py-01-gioi-thieu",    symbol: "1.circle"),
            Topic(title: "2. Biến và kiểu dữ liệu",   file: "docs-py-02-bien-kieu",     symbol: "2.circle"),
            Topic(title: "3. Điều khiển và hàm",      file: "docs-py-03-dieu-khien-ham", symbol: "3.circle"),
            Topic(title: "4. Cấu trúc dữ liệu",       file: "docs-py-04-cau-truc-du-lieu", symbol: "4.circle"),
            Topic(title: "5. Lớp và module",          file: "docs-py-05-lop-module",    symbol: "5.circle"),
            Topic(title: "6. File và xử lý lỗi",      file: "docs-py-06-file-loi",      symbol: "6.circle"),
            Topic(title: "7. Thư viện: numpy, pillow", file: "docs-py-07-thu-vien",     symbol: "7.circle")
        ]),
        Group(title: "C2o (2oLang, .2o)", summary: "Ngôn ngữ nhẹ biên dịch ra arm64 chạy ngay", symbol: "shippingbox", topics: [
            Topic(title: "Dự án C2o trong Catnip",    file: "docs-25-twoolang",         symbol: "shippingbox"),
            Topic(title: "1. Bắt đầu với C2o",        file: "docs-2o-01-bat-dau",       symbol: "1.circle"),
            Topic(title: "2. Biến, kiểu, toán tử",    file: "docs-2o-02-bien-kieu-toan-tu", symbol: "2.circle"),
            Topic(title: "3. Điều khiển, hàm, obj",   file: "docs-2o-03-dieu-khien-ham-obj", symbol: "3.circle"),
            Topic(title: "4. Nhập xuất, thư viện",    file: "docs-2o-04-nhap-xuat-thu-vien", symbol: "4.circle")
        ]),
        Group(title: "Công cụ của Catnip", summary: "Tô màu cú pháp, trình xem ảnh/video/hex", symbol: "wrench.and.screwdriver", topics: [
            Topic(title: "Tô màu cú pháp, trình xem file", file: "docs-23-to-mau-trinh-xem", symbol: "photo.on.rectangle")
        ])
    ]

    /// Chỉ giữ chương đã có file trong app (chương chưa viết thì ẩn), bỏ mục lớn rỗng.
    static var groups: [Group] {
        allGroups.compactMap { g in
            let ts = g.topics.filter { Bundle.main.url(forResource: $0.file, withExtension: "md") != nil }
            return ts.isEmpty ? nil : Group(title: g.title, summary: g.summary, symbol: g.symbol, topics: ts)
        }
    }

    /// Mọi chương (phẳng), chỉ gồm chương có file trong app.
    static var topics: [Topic] { groups.flatMap { $0.topics } }

    static let officialWiki = URL(string: "https://love2d.org/wiki/Main_Page")!
    static let linkHost = "catnip.docs"

    static func text(for topic: Topic) -> String? {
        guard let url = Bundle.main.url(forResource: topic.file, withExtension: "md") else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    static func topic(file: String) -> Topic? { topics.first { $0.file == file } }

    /// Chương liền trước/sau trong cùng mục lớn.
    static func neighbour(of topic: Topic, offset: Int) -> Topic? {
        guard let g = groups.first(where: { $0.topics.contains { $0.file == topic.file } }),
              let i = g.topics.firstIndex(where: { $0.file == topic.file }) else { return nil }
        let j = i + offset
        return g.topics.indices.contains(j) ? g.topics[j] : nil
    }
}

extension UIViewController {
    /// Mở danh sách tài liệu (dùng chung cho nút "?" ở danh sách dự án và ở editor).
    func presentDocs() {
        present(CatnipNavigationController(rootViewController: DocsViewController()), animated: true)
    }
}

// MARK: - Danh sách mục lớn / mục nhỏ

final class DocsViewController: UITableViewController {

    private let group: DocsCatalog.Group?   // nil = màn hình gốc (danh sách mục lớn)

    init(group: DocsCatalog.Group? = nil) {
        self.group = group
        super.init(style: .insetGrouped)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = group?.title ?? "Hướng dẫn"
        if group == nil {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .done, target: self, action: #selector(doneTapped))
        } else {
            navigationItem.largeTitleDisplayMode = .never
        }
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        apply()
    }

    private func apply() {
        Appearance.style(navigationController)
        tableView.backgroundColor = Appearance.theme.bgColor
        tableView.reloadData()
    }

    @objc private func doneTapped() { dismiss(animated: true) }

    override func numberOfSections(in tableView: UITableView) -> Int { group == nil ? 2 : 1 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let g = group { return g.topics.count }
        return section == 0 ? DocsCatalog.groups.count : 1
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        group == nil && section == 1 ? "Wiki chính thức có đầy đủ mọi hàm (bằng tiếng Anh) và cần kết nối mạng." : nil
    }

    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        (view as? UITableViewHeaderFooterView)?.textLabel?.textColor = Appearance.theme.mutedColor
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let t = Appearance.theme
        var cfg = UIListContentConfiguration.subtitleCell()
        if let g = group {
            let topic = g.topics[indexPath.row]
            cfg.text = topic.title
            cfg.image = UIImage(systemName: topic.symbol)
            cell.accessoryType = .disclosureIndicator
        } else if indexPath.section == 0 {
            let g = DocsCatalog.groups[indexPath.row]
            cfg.text = g.title
            cfg.secondaryText = "\(g.topics.count) mục · \(g.summary)"
            cfg.image = UIImage(systemName: g.symbol)
            cfg.secondaryTextProperties.color = t.mutedColor
            cfg.secondaryTextProperties.font = .systemFont(ofSize: 12)
            cell.accessoryType = .disclosureIndicator
        } else {
            cfg.text = "Mở wiki LÖVE chính thức"
            cfg.image = UIImage(systemName: "safari")
            cell.accessoryType = .none
        }
        cfg.textProperties.color = t.fgColor
        cfg.imageProperties.tintColor = t.accentColor
        cell.contentConfiguration = cfg
        cell.backgroundColor = t.bg2Color
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if let g = group {
            navigationController?.pushViewController(DocPageViewController(topic: g.topics[indexPath.row]), animated: true)
        } else if indexPath.section == 0 {
            navigationController?.pushViewController(
                DocsViewController(group: DocsCatalog.groups[indexPath.row]), animated: true)
        } else {
            UIApplication.shared.open(DocsCatalog.officialWiki)
        }
    }
}

// MARK: - Một trang tài liệu

final class DocPageViewController: UIViewController, WKNavigationDelegate {

    private let topic: DocsCatalog.Topic
    private var webView: WKWebView!

    init(topic: DocsCatalog.Topic) {
        self.topic = topic
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = topic.title
        navigationItem.largeTitleDisplayMode = .never

        let config = WKWebViewConfiguration()
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
        render()
    }

    private func render() {
        let dark = MarkdownPage.isDark(appIsDark: Appearance.theme.isDark)
        let bg = MarkdownPage.backgroundColor(dark: dark)
        view.backgroundColor = bg
        webView.backgroundColor = bg
        webView.scrollView.backgroundColor = bg
        let md = DocsCatalog.text(for: topic) ?? "Không tìm thấy nội dung của trang này trong app."
        webView.loadHTMLString(MarkdownPage.html(markdown: md, dark: dark, anchor: nil),
                               baseURL: URL(string: "https://\(DocsCatalog.linkHost)/"))
    }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard action.navigationType == .linkActivated, let url = action.request.url else {
            decisionHandler(action.navigationType == .other ? .allow : .cancel)
            return
        }
        // Liên kết nội bộ tới chương khác ("docs-xxx.md") hoặc neo "#..." trong cùng trang.
        if url.host == DocsCatalog.linkHost {
            if url.path.hasSuffix(".md") {
                decisionHandler(.cancel)
                let name = ((url.path as NSString).lastPathComponent as NSString).deletingPathExtension
                if let t = DocsCatalog.topic(file: name) {
                    navigationController?.pushViewController(DocPageViewController(topic: t), animated: true)
                }
            } else {
                decisionHandler(url.path.isEmpty || url.path == "/" ? .allow : .cancel)
            }
            return
        }
        decisionHandler(.cancel)
        if ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
            UIApplication.shared.open(url)
        }
    }
}
