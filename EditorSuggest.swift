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


import UIKit

// MARK: - Khung chứa thanh phím + hàng gợi ý

/// Thanh phụ trên bàn phím: hàng gợi ý (chỉ hiện khi có gợi ý) nằm trên hàng phím tắt 44pt.
final class AccessoryContainer: UIInputView {
    static let keysHeight: CGFloat = 44
    static let stripHeight: CGFloat = 38

    var showsStrip = false {
        didSet {
            guard showsStrip != oldValue else { return }
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    init() {
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: Self.keysHeight), inputViewStyle: .keyboard)
        allowsSelfSizing = true
        autoresizingMask = .flexibleWidth
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric,
               height: Self.keysHeight + (showsStrip ? Self.stripHeight : 0))
    }
}

// MARK: - Hàng nút gợi ý

final class SuggestionStrip: UIView {
    private let scroll = UIScrollView()
    private let stack = UIStackView()
    var onPick: ((Suggestion) -> Void)?
    private(set) var items: [Suggestion] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.showsHorizontalScrollIndicator = false
        scroll.keyboardDismissMode = .none
        addSubview(scroll)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 6
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -8),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 4),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -4),
            stack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor, constant: -8)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show(_ list: [Suggestion]) {
        items = list
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for item in list {
            var cfg = UIButton.Configuration.filled()
            cfg.baseBackgroundColor = UIColor.tertiarySystemFill
            cfg.baseForegroundColor = .label
            cfg.cornerStyle = .capsule
            cfg.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12)
            var title = AttributedString(item.label)
            title.font = UIFont.monospacedSystemFont(ofSize: 15, weight: .medium)
            if let d = item.detail, item.kind != .snippet {
                var detail = AttributedString(" " + d)
                detail.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
                detail.foregroundColor = UIColor.secondaryLabel
                title.append(detail)
            }
            cfg.attributedTitle = title
            cfg.image = UIImage(systemName: Self.symbol(for: item.kind),
                                withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold))
            cfg.imagePadding = 5
            cfg.imageColorTransformer = UIConfigurationColorTransformer { _ in Self.tint(for: item.kind) }
            let b = UIButton(configuration: cfg, primaryAction: UIAction { [weak self] _ in self?.onPick?(item) })
            stack.addArrangedSubview(b)
        }
        scroll.setContentOffset(.zero, animated: false)
    }

    private static func symbol(for kind: Suggestion.Kind) -> String {
        switch kind {
        case .keyword:  return "textformat"
        case .function: return "function"
        case .module:   return "shippingbox"
        case .type:     return "cube"
        case .callback: return "bolt.fill"
        case .local:    return "character.cursor.ibeam"
        case .snippet:  return "curlybraces"
        }
    }

    private static func tint(for kind: Suggestion.Kind) -> UIColor {
        switch kind {
        case .keyword:  return .systemPink
        case .function: return .systemBlue
        case .module, .type: return .systemTeal
        case .callback: return .systemOrange
        case .local:    return .systemGray
        case .snippet:  return .systemPurple
        }
    }
}

// MARK: - Gắn vào editor

extension EditorViewController {

    /// Tính lại gợi ý theo vị trí con trỏ. Chỉ bật cho file Lua, đang gõ, và không có chữ nào đang được chọn.
    func refreshSuggestions() {
        guard let strip = suggestStrip, let container = accessory else { return }
        guard language == .lua, canEdit, textView.isFirstResponder, textView.markedTextRange == nil,
              textView.selectedRange.length == 0 else {
            hideSuggestions(); return
        }
        let ns = (textView.text ?? "") as NSString
        let result = Completion.suggest(in: ns, cursor: textView.selectedRange.location)
        suggestRange = result.range
        if result.items.isEmpty { hideSuggestions(); return }
        strip.show(result.items)
        if !container.showsStrip {
            container.showsStrip = true
            textView.reloadInputViews()
        }
    }

    func hideSuggestions() {
        guard let container = accessory, container.showsStrip else { return }
        container.showsStrip = false
        textView.reloadInputViews()
    }

    /// Chèn gợi ý bằng insertText để hoàn tác (undo) vẫn hoạt động.
    func applySuggestion(_ s: Suggestion) {
        let ns = (textView.text ?? "") as NSString
        var range = suggestRange
        guard NSMaxRange(range) <= ns.length else { hideSuggestions(); return }

        var text = s.insert
        var cursorOffset = s.cursor
        let lineStart = ns.lineRange(for: NSRange(location: range.location, length: 0)).location
        let before = ns.substring(with: NSRange(location: lineStart, length: range.location - lineStart))

        if let lead = s.leading, range.location >= 5,
           ns.substring(with: NSRange(location: range.location - 5, length: 5)) == "love." {
            // Khung callback: thêm "function " trước "love."
            range = NSRange(location: range.location - 5, length: range.length + 5)
            text = lead + "love." + text
            cursorOffset = cursorOffset.map { $0 + (lead as NSString).length + 5 }
        } else if s.kind == .snippet, text.contains("\n") {
            // Snippet nhiều dòng: thụt các dòng sau theo dòng hiện tại (và thụt thêm một mức cho thân).
            let indent = String(before.prefix(while: { $0 == " " || $0 == "\t" }))
            // Đặt dấu mốc tại vị trí con trỏ để tìm lại sau khi thụt lề.
            let marker = "\u{1}"
            var marked = text as NSString
            if let c = cursorOffset { marked = marked.replacingCharacters(in: NSRange(location: c, length: 0), with: marker) as NSString }
            var lines = (marked as String).components(separatedBy: "\n")
            for i in 1..<lines.count {
                let isLast = i == lines.count - 1
                lines[i] = indent + (isLast ? "" : Completion.indentUnitForCompletion) + lines[i]
            }
            let joined = lines.joined(separator: "\n") as NSString
            let m = joined.range(of: marker)
            if m.location != NSNotFound {
                cursorOffset = m.location
                text = joined.replacingCharacters(in: m, with: "")
            } else {
                text = joined as String
            }
        }

        textView.selectedRange = range
        textView.insertText(text)
        if let c = cursorOffset {
            textView.selectedRange = NSRange(location: range.location + c, length: 0)
        }
        hideSuggestions()
    }
}
