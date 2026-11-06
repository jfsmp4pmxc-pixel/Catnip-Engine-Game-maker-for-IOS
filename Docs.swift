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

    static let topics: [Topic] = [
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
    ]

    static let officialWiki = URL(string: "https://love2d.org/wiki/Main_Page")!

    static func text(for topic: Topic) -> String? {
        guard let url = Bundle.main.url(forResource: topic.file, withExtension: "md") else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}

extension UIViewController {
    /// Mở danh sách tài liệu (dùng chung cho nút "?" ở danh sách dự án và ở editor).
    func presentDocs() {
        present(CatnipNavigationController(rootViewController: DocsViewController()), animated: true)
    }
}

// MARK: - Danh sách chủ đề

final class DocsViewController: UITableViewController {

    init() { super.init(style: .insetGrouped) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Tài liệu LÖVE"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done, target: self, action: #selector(doneTapped))
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        apply()
    }

    private func apply() {
        Appearance.style(navigationController)
        tableView.backgroundColor = Appearance.theme.bgColor
        tableView.reloadData()
    }

    @objc private func doneTapped() { dismiss(animated: true) }

    override func numberOfSections(in tableView: UITableView) -> Int { 2 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? DocsCatalog.topics.count : 1
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        section == 1 ? "Wiki chính thức có đầy đủ mọi hàm (bằng tiếng Anh) và cần kết nối mạng." : nil
    }

    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        (view as? UITableViewHeaderFooterView)?.textLabel?.textColor = Appearance.theme.mutedColor
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let t = Appearance.theme
        var cfg = UIListContentConfiguration.cell()
        if indexPath.section == 0 {
            let topic = DocsCatalog.topics[indexPath.row]
            cfg.text = topic.title
            cfg.image = UIImage(systemName: topic.symbol)
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
        if indexPath.section == 0 {
            navigationController?.pushViewController(
                DocPageViewController(topic: DocsCatalog.topics[indexPath.row]), animated: true)
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
        let dark = Appearance.theme.isDark
        let bg = MarkdownPage.backgroundColor(dark: dark)
        view.backgroundColor = bg
        webView.backgroundColor = bg
        webView.scrollView.backgroundColor = bg
        let md = DocsCatalog.text(for: topic) ?? "Không tìm thấy nội dung của trang này trong app."
        webView.loadHTMLString(MarkdownPage.html(markdown: md, dark: dark, anchor: nil), baseURL: nil)
    }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard action.navigationType == .linkActivated, let url = action.request.url else {
            decisionHandler(action.navigationType == .other ? .allow : .cancel)
            return
        }
        decisionHandler(.cancel)
        if ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
            UIApplication.shared.open(url)
        }
    }
}
