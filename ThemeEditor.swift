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

// ThemeEditor.swift
// Trình sửa theme: chỉnh màu giao diện và màu cú pháp, xem trước tức thì, lưu thành theme riêng (JSON).

import UIKit

final class ThemeEditorViewController: UITableViewController, UIColorPickerViewControllerDelegate {

    private var draft: Theme
    private var replacingKey: String?
    var onSaved: ((Theme) -> Void)?

    private enum Sec: Int, CaseIterable { case info, base, tokens }

    private static let baseFields: [(String, WritableKeyPath<Theme, String>)] = [
        ("Nền editor", \.bg), ("Nền thanh bên", \.bg2), ("Nền phụ", \.bg3), ("Chữ", \.fg),
        ("Chữ mờ", \.muted), ("Màu nhấn", \.accent), ("Viền", \.border), ("Nền khi chạm", \.hover)
    ]

    private static let tokenNames: [(TokenKind, String)] = [
        (.keyword, "Từ khoá (if, while, void, int...)"), (.function, "Tên hàm"), (.string, "Chuỗi"), (.number, "Số"),
        (.comment, "Chú thích"), (.bool, "true / false / nil"), (.type, "Tên kiểu, thư viện"), (.op, "Toán tử"),
        (.punct, "Dấu ngoặc, dấu câu"), (.tag, "Thẻ (HTML, mục TOML)"), (.attr, "Thuộc tính, khoá"),
        (.decorator, "Chỉ thị (#include, @attr)"), (.heading, "Tiêu đề Markdown"), (.doctype, "Doctype, ---"), (.color, "Mã màu CSS")
    ]

    private enum Target { case base(WritableKeyPath<Theme, String>), token(TokenKind) }
    private var picking: Target?

    init(theme: Theme) {
        var d = theme
        if theme.isCustom, let k = theme.key, k.hasSuffix(".json") {
            replacingKey = k
        } else {
            d.name = theme.name + " (sửa)"
        }
        d.key = nil
        draft = d
        super.init(style: .insetGrouped)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = replacingKey == nil ? "Theme mới" : "Sửa theme"
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Lưu", style: .done, target: self, action: #selector(save))
        tableView.keyboardDismissMode = .onDrag
        tableView.backgroundColor = Appearance.theme.bgColor
        tableView.separatorColor = Appearance.theme.borderColor
        Appearance.style(navigationController)
    }

    @objc private func cancel() { dismiss(animated: true) }

    @objc private func save() {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { alert("Hãy đặt tên cho theme"); return }
        draft.name = name
        do {
            let saved = try ThemeStore.shared.save(draft, replacing: replacingKey)
            SettingsStore.shared.update { $0.themeName = saved.id }
            onSaved?(saved)
            dismiss(animated: true)
        } catch {
            alert("Không lưu được: \(error.localizedDescription)")
        }
    }

    private func alert(_ s: String) {
        let a = UIAlertController(title: nil, message: s, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }

    // MARK: Bảng

    override func numberOfSections(in tableView: UITableView) -> Int { Sec.allCases.count }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Sec(rawValue: section)! {
        case .info:   return "THEME"
        case .base:   return "MÀU GIAO DIỆN"
        case .tokens: return "MÀU CÚ PHÁP"
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        Sec(rawValue: section) == .info ? "Chạm một dòng màu để chọn màu. Bản xem trước đổi ngay." : nil
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        (view as? UITableViewHeaderFooterView)?.textLabel?.textColor = Appearance.theme.mutedColor
    }
    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        (view as? UITableViewHeaderFooterView)?.textLabel?.textColor = Appearance.theme.mutedColor
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Sec(rawValue: section)! {
        case .info:   return 3          // tên, lấy màu từ theme khác, xem trước
        case .base:   return Self.baseFields.count
        case .tokens: return Self.tokenNames.count
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        (Sec(rawValue: indexPath.section) == .info && indexPath.row == 2) ? UITableView.automaticDimension : 48
    }

    private static let previewC = """
    #include <stdio.h>
    // Chú thích
    int main(void) {
        int x = 42;
        char *s = "xin chào";
        while (x > 0) { x--; }
        return true ? 0 : 1;
    }
    """
    private static let previewHTML = "<a href=\"#\" class=\"nut\">Liên kết</a>"

    private func previewText() -> NSAttributedString {
        let font = Appearance.codeFont()
        let out = NSMutableAttributedString(attributedString: SyntaxHighlighter.highlight(Self.previewC, language: .c, theme: draft, font: font))
        out.append(NSAttributedString(string: "\n"))
        out.append(SyntaxHighlighter.highlight(Self.previewHTML, language: .html, theme: draft, font: font))
        return out
    }

    private func hexOf(_ c: UIColor) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02x%02x%02x", Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let appT = Appearance.theme
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.backgroundColor = appT.bg2Color
        cell.textLabel?.textColor = appT.fgColor
        cell.detailTextLabel?.textColor = appT.mutedColor
        cell.detailTextLabel?.font = .monospacedSystemFont(ofSize: 13, weight: .regular)

        func swatch(_ c: UIColor) {
            let v = UIView(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
            v.backgroundColor = c
            v.layer.cornerRadius = 15
            v.layer.borderWidth = 1
            v.layer.borderColor = appT.borderColor.cgColor
            cell.accessoryView = v
        }

        switch Sec(rawValue: indexPath.section)! {
        case .info:
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = "Tên"
                cell.detailTextLabel?.text = draft.name
                cell.detailTextLabel?.font = .systemFont(ofSize: 16)
                cell.accessoryType = .disclosureIndicator
            case 1:
                cell.textLabel?.text = "Lấy màu từ theme khác…"
                cell.textLabel?.textColor = appT.accentColor
            default:
                cell.selectionStyle = .none
                cell.backgroundColor = draft.bgColor
                let l = UILabel()
                l.numberOfLines = 0
                l.attributedText = previewText()
                l.translatesAutoresizingMaskIntoConstraints = false
                cell.contentView.addSubview(l)
                NSLayoutConstraint.activate([
                    l.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 12),
                    l.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -12),
                    l.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 14),
                    l.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -14),
                ])
            }
        case .base:
            let (name, kp) = Self.baseFields[indexPath.row]
            cell.textLabel?.text = name
            cell.detailTextLabel?.text = draft[keyPath: kp]
            swatch(UIColor(hex: draft[keyPath: kp]) ?? .gray)
        case .tokens:
            let (kind, name) = Self.tokenNames[indexPath.row]
            cell.textLabel?.text = name
            cell.textLabel?.numberOfLines = 2
            cell.textLabel?.adjustsFontSizeToFitWidth = true
            cell.detailTextLabel?.text = draft.tokens[kind] ?? "#------"
            swatch(draft.tokenColor(kind))
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch Sec(rawValue: indexPath.section)! {
        case .info:
            if indexPath.row == 0 { askName() }
            else if indexPath.row == 1 { askBase(from: tableView.cellForRow(at: indexPath)) }
        case .base:
            picking = .base(Self.baseFields[indexPath.row].1)
            pickColor(UIColor(hex: draft[keyPath: Self.baseFields[indexPath.row].1]) ?? .gray, title: Self.baseFields[indexPath.row].0)
        case .tokens:
            let (kind, name) = Self.tokenNames[indexPath.row]
            picking = .token(kind)
            pickColor(draft.tokenColor(kind), title: name)
        }
    }

    private func pickColor(_ c: UIColor, title: String) {
        let p = UIColorPickerViewController()
        p.selectedColor = c
        p.supportsAlpha = false
        p.title = title
        p.delegate = self
        present(p, animated: true)
    }

    func colorPickerViewController(_ viewController: UIColorPickerViewController, didSelect color: UIColor, continuously: Bool) {
        apply(color)
    }

    func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
        apply(viewController.selectedColor)
        tableView.reloadData()
    }

    private func apply(_ c: UIColor) {
        let hex = hexOf(c)
        switch picking {
        case .base(let kp)?: draft[keyPath: kp] = hex
        case .token(let k)?: draft.tokens[k] = hex
        case nil: return
        }
        // Chỉ làm mới dòng xem trước khi đang kéo chọn (tránh đóng bộ chọn màu).
        if let cell = tableView.cellForRow(at: IndexPath(row: 2, section: Sec.info.rawValue)) {
            cell.backgroundColor = draft.bgColor
            (cell.contentView.subviews.first as? UILabel)?.attributedText = previewText()
        }
    }

    private func askName() {
        let a = UIAlertController(title: "Tên theme", message: nil, preferredStyle: .alert)
        a.addTextField { [weak self] tf in tf.text = self?.draft.name; tf.autocorrectionType = .no }
        a.addAction(UIAlertAction(title: "Huỷ", style: .cancel))
        a.addAction(UIAlertAction(title: "Xong", style: .default) { [weak self, weak a] _ in
            self?.draft.name = a?.textFields?.first?.text ?? ""
            self?.tableView.reloadData()
        })
        present(a, animated: true)
    }

    private func askBase(from source: UIView?) {
        let sheet = UIAlertController(title: "Lấy màu từ", message: "Ghi đè mọi màu hiện tại (giữ tên).", preferredStyle: .actionSheet)
        for t in Theme.all {
            sheet.addAction(UIAlertAction(title: t.name, style: .default) { [weak self] _ in
                guard let self = self else { return }
                let name = self.draft.name
                var d = t
                d.name = name
                d.key = nil
                self.draft = d
                self.tableView.reloadData()
            })
        }
        sheet.addAction(UIAlertAction(title: "Huỷ", style: .cancel))
        sheet.popoverPresentationController?.sourceView = source ?? view
        sheet.popoverPresentationController?.sourceRect = (source ?? view).bounds
        present(sheet, animated: true)
    }
}
