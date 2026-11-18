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

// UIPreview.swift
// Preview tương tác cho dự án "UI": nạp các file .swift, chạy bằng Interp (SwiftUIInterp.swift) và vẽ VNode bằng UIKit.
// Control (TextField/Slider/Toggle/Stepper) được giữ lại giữa các lần dựng để không mất focus/đang kéo.

import UIKit

enum UIPreviewTemplate {
    static let contentView = """
    import SwiftUI

    struct ContentView: View {
        @State private var count = 0
        @State private var name = ""
        @State private var on = true

        var body: some View {
            VStack(spacing: 16) {
                Text("Xin chào \\(name.isEmpty ? "Catnip" : name)!")
                    .font(.title)
                    .foregroundColor(.blue)
                TextField("Nhập tên", text: $name)
                Text("Đã bấm: \\(count)")
                Button("Bấm tôi") { count += 1 }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                Toggle("Bật", isOn: $on)
                if on { Text("Đang bật") }
            }
            .padding()
        }
    }
    """
}

extension Program {
    func merge(_ o: Program) {
        for n in o.structOrder { if structs[n] == nil { structOrder.append(n) }; structs[n] = o.structs[n] }
        enums.merge(o.enums) { $1 }
        funcs.merge(o.funcs) { $1 }
        globals += o.globals
        if o.previewBody != nil { previewBody = o.previewBody }
    }
}

// MARK: - View phụ

protocol PVFlagged: AnyObject { var fillW: Bool { get set }; var fillH: Bool { get set } }

final class PVBox: UIView, PVFlagged {
    var fillW = false, fillH = false
    var circle = false
    var intrinsic: CGSize?
    override var intrinsicContentSize: CGSize { intrinsic ?? super.intrinsicContentSize }
    override func layoutSubviews() {
        super.layoutSubviews()
        if circle { layer.cornerRadius = min(bounds.width, bounds.height) / 2; layer.masksToBounds = true }
    }
}

final class PVStack: UIStackView, PVFlagged {
    var fillW = false, fillH = false
}

final class PVSpacer: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        setContentHuggingPriority(UILayoutPriority(1), for: .horizontal)
        setContentHuggingPriority(UILayoutPriority(1), for: .vertical)
        setContentCompressionResistancePriority(UILayoutPriority(1), for: .horizontal)
        setContentCompressionResistancePriority(UILayoutPriority(1), for: .vertical)
    }
    required init?(coder: NSCoder) { fatalError() }
}

final class PVField: UITextField {
    var onChange: ((String) -> Void)?
    override init(frame: CGRect) {
        super.init(frame: frame)
        borderStyle = .roundedRect
        addTarget(self, action: #selector(changed), for: .editingChanged)
    }
    required init?(coder: NSCoder) { fatalError() }
    @objc private func changed() { onChange?(text ?? "") }
}

final class PVSlider: UISlider {
    var onChange: ((Double) -> Void)?
    override init(frame: CGRect) { super.init(frame: frame); addTarget(self, action: #selector(changed), for: .valueChanged) }
    required init?(coder: NSCoder) { fatalError() }
    @objc private func changed() { onChange?(Double(value)) }
}

final class PVSwitch: UISwitch {
    var onChange: ((Bool) -> Void)?
    override init(frame: CGRect) { super.init(frame: frame); addTarget(self, action: #selector(changed), for: .valueChanged) }
    required init?(coder: NSCoder) { fatalError() }
    @objc private func changed() { onChange?(isOn) }
}

final class PVStepper: UIStepper {
    var onChange: ((Double) -> Void)?
    override init(frame: CGRect) { super.init(frame: frame); addTarget(self, action: #selector(changed), for: .valueChanged) }
    required init?(coder: NSCoder) { fatalError() }
    @objc private func changed() { onChange?(value) }
}

final class PVTap: UIControl, PVFlagged {
    var fillW = false, fillH = false
    var onTap: (() -> Void)?
    override init(frame: CGRect) { super.init(frame: frame); addTarget(self, action: #selector(tapped), for: .touchUpInside) }
    required init?(coder: NSCoder) { fatalError() }
    @objc private func tapped() { onTap?() }
    override var isHighlighted: Bool { didSet { alpha = isHighlighted ? 0.4 : 1 } }
}

final class PVSeg: UISegmentedControl {
    var onPick: ((Int) -> Void)?
    @objc func picked() { onPick?(selectedSegmentIndex) }
}

final class PVTapHolder: NSObject {
    let fn: () -> Void
    init(_ f: @escaping () -> Void) { fn = f }
    @objc func fire() { fn() }
}

// MARK: - Dựng UIKit từ VNode

struct PStyle {
    var font: UIFont = .preferredFont(forTextStyle: .body)
    var color: UIColor = .label
    var align: NSTextAlignment = .natural
    var lines = 0
    var tint: UIColor = .systemBlue
}

final class PVRenderer {
    let interp: Interp
    var cache: [String: UIView] = [:]
    var used: Set<String> = []
    var navTitle: String?
    var screenBG: UIColor?
    var error: String?
    var onAppear: [V] = []
    static var tapKey = 0

    init(interp: Interp) { self.interp = interp }

    func changed() { interp.onChange?() }

    func guarded(_ f: () throws -> Void) {
        do { try f() } catch { self.error = error.localizedDescription }
    }

    func render(_ node: VNode) -> UIView {
        used = []; navTitle = nil; screenBG = nil; onAppear = []
        let v = build(node, PStyle(), axis: .vertical, path: "r")
        cache = cache.filter { used.contains($0.key) }
        return v
    }

    private func reuse<T: UIView>(_ path: String, _ make: () -> T) -> T {
        used.insert(path)
        if let v = cache[path] as? T { return v }
        let v = make()
        cache[path] = v
        return v
    }

    private func flags(_ v: UIView) -> (Bool, Bool) {
        if let f = v as? PVFlagged { return (f.fillW, f.fillH) }
        if v is UIScrollView { return (true, true) }
        return (false, false)
    }

    private func pin(_ v: UIView, in b: UIView, insets: UIEdgeInsets = .zero) {
        v.translatesAutoresizingMaskIntoConstraints = false
        b.addSubview(v)
        NSLayoutConstraint.activate([
            v.topAnchor.constraint(equalTo: b.topAnchor, constant: insets.top),
            v.bottomAnchor.constraint(equalTo: b.bottomAnchor, constant: -insets.bottom),
            v.leadingAnchor.constraint(equalTo: b.leadingAnchor, constant: insets.left),
            v.trailingAnchor.constraint(equalTo: b.trailingAnchor, constant: -insets.right),
        ])
    }

    private func wrap(_ v: UIView, insets: UIEdgeInsets = .zero) -> PVBox {
        let b = PVBox()
        pin(v, in: b, insets: insets)
        let f = flags(v)
        b.fillW = f.0; b.fillH = f.1
        if f.0 { b.setContentHuggingPriority(.defaultLow, for: .horizontal) }
        if f.1 { b.setContentHuggingPriority(.defaultLow, for: .vertical) }
        return b
    }

    // MARK: Tham số modifier

    private func plain(_ a: [V]) -> [V] {
        a.map { v -> V in
            if case .enumCase(_, let n, let inner) = v, n.hasPrefix("label:"), let x = inner.first { return x }
            return v
        }
    }

    private func labels(_ a: [V]) -> [String: V] {
        var d: [String: V] = [:]
        for v in a { if case .enumCase(_, let n, let inner) = v, n.hasPrefix("label:"), let x = inner.first { d[String(n.dropFirst(6))] = x } }
        return d
    }

    private func edges(_ vals: [V]) -> (UIRectEdge, CGFloat) {
        var e: UIRectEdge = .all
        var amount: CGFloat = 16
        for v in vals {
            if let d = v.asDouble { amount = CGFloat(d) }
            if case .enumCase(_, let n, _) = v {
                switch n {
                case "horizontal": e = [.left, .right]
                case "vertical": e = [.top, .bottom]
                case "top": e = .top
                case "bottom": e = .bottom
                case "leading": e = .left
                case "trailing": e = .right
                default: break
                }
            }
        }
        return (e, amount)
    }

    private func label(_ s: String, _ st: PStyle) -> UILabel {
        let l = UILabel()
        l.text = s
        l.font = st.font
        l.textColor = st.color
        l.textAlignment = st.align
        l.numberOfLines = st.lines
        return l
    }

    // MARK: Dựng một node (style + modifier)

    func build(_ node: VNode, _ base: PStyle, axis: NSLayoutConstraint.Axis, path: String) -> UIView {
        var st = base
        for (m, raw) in node.mods {
            let a = plain(raw)
            switch m {
            case "font": if let f = a.first.flatMap({ PVColors.font($0) }) { st.font = f }
            case "foregroundColor", "foregroundStyle":
                if let c = a.first.flatMap({ PVColors.color($0) }) { st.color = c }
            case "tint", "accentColor":
                if let c = a.first.flatMap({ PVColors.color($0) }) { st.tint = c }
            case "bold": st.font = UIFont(descriptor: st.font.fontDescriptor.withSymbolicTraits(.traitBold) ?? st.font.fontDescriptor, size: st.font.pointSize)
            case "italic": st.font = UIFont(descriptor: st.font.fontDescriptor.withSymbolicTraits(.traitItalic) ?? st.font.fontDescriptor, size: st.font.pointSize)
            case "fontWeight": if let w = a.first.flatMap({ PVColors.weight($0) }) { st.font = .systemFont(ofSize: st.font.pointSize, weight: w) }
            case "multilineTextAlignment":
                if case .enumCase(_, let n, _)? = a.first { st.align = n == "center" ? .center : n == "trailing" ? .right : .left }
            case "lineLimit": st.lines = a.first?.asInt ?? 0
            default: break
            }
        }
        var view = buildCore(node, st, axis: axis, path: path)
        for (m, raw) in node.mods {
            let a = plain(raw)
            let lab = labels(raw)
            switch m {
            case "padding":
                let (e, amt) = edges(a)
                view = wrap(view, insets: UIEdgeInsets(top: e.contains(.top) ? amt : 0, left: e.contains(.left) ? amt : 0,
                                                       bottom: e.contains(.bottom) ? amt : 0, right: e.contains(.right) ? amt : 0))
            case "background":
                let b = wrap(view)
                if let c = a.first.flatMap({ PVColors.color($0) }) {
                    b.backgroundColor = c
                    if case .view(let n)? = a.first, n.mods.contains(where: { $0.0.hasPrefix("ignoresSafeArea") || $0.0 == "edgesIgnoringSafeArea" }) { screenBG = c }
                } else if case .view(let n)? = a.first {
                    let bg = build(n, st, axis: .vertical, path: path + "/bg")
                    pin(bg, in: b)
                    b.sendSubviewToBack(bg)
                }
                view = b
            case "overlay":
                if case .view(let n)? = a.first {
                    let b = wrap(view)
                    let ov = build(n, st, axis: .vertical, path: path + "/ov")
                    ov.translatesAutoresizingMaskIntoConstraints = false
                    b.addSubview(ov)
                    NSLayoutConstraint.activate([ov.centerXAnchor.constraint(equalTo: b.centerXAnchor), ov.centerYAnchor.constraint(equalTo: b.centerYAnchor)])
                    view = b
                }
            case "cornerRadius":
                let b = wrap(view)
                b.layer.cornerRadius = CGFloat(a.first?.asDouble ?? 0); b.layer.masksToBounds = true
                view = b
            case "clipShape":
                let b = wrap(view)
                if case .view(let n)? = a.first, case .str(let s)? = n.args["shape"] {
                    if s == "Circle" || s == "Capsule" || s == "Ellipse" { b.circle = true }
                    else { b.layer.cornerRadius = CGFloat(n.args["radius"]?.asDouble ?? 0); b.layer.masksToBounds = true }
                }
                view = b
            case "border":
                let b = wrap(view)
                b.layer.borderColor = (a.first.flatMap { PVColors.color($0) } ?? .label).cgColor
                b.layer.borderWidth = CGFloat((lab["width"] ?? (a.count > 1 ? a[1] : nil))?.asDouble ?? 1)
                view = b
            case "shadow":
                let b = wrap(view)
                b.layer.shadowOpacity = 0.3
                b.layer.shadowRadius = CGFloat((lab["radius"] ?? a.first)?.asDouble ?? 4)
                b.layer.shadowOffset = CGSize(width: CGFloat(lab["x"]?.asDouble ?? 0), height: CGFloat(lab["y"]?.asDouble ?? 2))
                view = b
            case "frame":
                let b = wrap(view)
                for (k, v) in lab {
                    if let d = v.asDouble {
                        let c = CGFloat(d)
                        switch k {
                        case "width": b.widthAnchor.constraint(equalToConstant: c).isActive = true
                        case "height": b.heightAnchor.constraint(equalToConstant: c).isActive = true
                        case "minWidth": b.widthAnchor.constraint(greaterThanOrEqualToConstant: c).isActive = true
                        case "minHeight": b.heightAnchor.constraint(greaterThanOrEqualToConstant: c).isActive = true
                        case "maxWidth": b.widthAnchor.constraint(lessThanOrEqualToConstant: c).isActive = true
                        case "maxHeight": b.heightAnchor.constraint(lessThanOrEqualToConstant: c).isActive = true
                        default: break
                        }
                    } else if case .enumCase(_, "infinity", _) = v {
                        if k == "maxWidth" { b.fillW = true; b.setContentHuggingPriority(.defaultLow, for: .horizontal) }
                        if k == "maxHeight" { b.fillH = true; b.setContentHuggingPriority(.defaultLow, for: .vertical) }
                    }
                }
                view = b
            case "opacity": view.alpha = CGFloat(a.first?.asDouble ?? 1)
            case "offset":
                let dx = (lab["x"] ?? (a.count > 0 ? a[0] : nil))?.asDouble ?? 0
                let dy = (lab["y"] ?? (a.count > 1 ? a[1] : nil))?.asDouble ?? 0
                view.transform = view.transform.translatedBy(x: CGFloat(dx), y: CGFloat(dy))
            case "scaleEffect":
                let s = CGFloat(a.first?.asDouble ?? 1)
                view.transform = view.transform.scaledBy(x: s, y: s)
            case "rotationEffect":
                if case .enumCase(_, _, let args)? = a.first, let d = args.first?.asDouble { view.transform = view.transform.rotated(by: CGFloat(d * .pi / 180)) }
            case "disabled":
                if truthy(a.first ?? .bool(true)) { view.isUserInteractionEnabled = false; view.alpha = 0.5 }
            case "onTapGesture":
                if let act = a.first {
                    let h = PVTapHolder { [weak self] in
                        self?.error = nil
                        self?.guarded { try self?.interp.runAction(act) }
                        self?.changed()
                    }
                    let g = UITapGestureRecognizer(target: h, action: #selector(PVTapHolder.fire))
                    objc_setAssociatedObject(view, &PVRenderer.tapKey, h, .OBJC_ASSOCIATION_RETAIN)
                    view.addGestureRecognizer(g)
                    view.isUserInteractionEnabled = true
                }
            case "navigationTitle": if let s = a.first { navTitle = describe(s) }
            case "onAppear": if let f = a.first { onAppear.append(f) }
            case "ignoresSafeArea", "edgesIgnoringSafeArea":
                if node.kind == "ColorFill", let c = PVColors.color(.view(node)) { screenBG = c }
            case "font", "foregroundColor", "foregroundStyle", "tint", "accentColor", "bold", "italic", "fontWeight",
                 "multilineTextAlignment", "lineLimit", "tag", "id", "resizable", "scaledToFit", "scaledToFill", "imageScale",
                 "pickerStyle", "textFieldStyle", "buttonStyle", "listStyle", "navigationBarTitleDisplayMode", "keyboardType",
                 "autocapitalization", "textInputAutocapitalization", "labelsHidden", "listRowSeparator", "symbolRenderingMode",
                 "minimumScaleFactor", "truncationMode", "textCase", "kerning", "fill", "stroke", "autocorrectionDisabled":
                break
            default:
                interp.warn("Modifier .\(m)(...) chưa hỗ trợ, bỏ qua")
            }
        }
        return view
    }

    // MARK: Phần lõi của từng loại view

    private func buildChildren(_ node: VNode, _ st: PStyle, axis: NSLayoutConstraint.Axis, path: String) -> [UIView] {
        node.children.enumerated().map { build($1, st, axis: axis, path: path + "/\($0)") }
    }

    private func makeStack(_ axis: NSLayoutConstraint.Axis, _ views: [UIView], spacing: CGFloat, alignment: UIStackView.Alignment) -> PVStack {
        let s = PVStack()
        s.axis = axis
        s.spacing = spacing
        s.alignment = alignment
        for v in views { s.addArrangedSubview(v) }
        for v in views {
            if v is PVSpacer {
                if axis == .vertical { s.fillH = true } else { s.fillW = true }
                continue
            }
            let f = flags(v)
            if axis == .vertical {
                if f.0 { v.widthAnchor.constraint(equalTo: s.widthAnchor).isActive = true; s.fillW = true; v.setContentHuggingPriority(.defaultLow, for: .horizontal) }
                if f.1 { s.fillH = true; v.setContentHuggingPriority(.defaultLow, for: .vertical) }
            } else {
                if f.1 { v.heightAnchor.constraint(equalTo: s.heightAnchor).isActive = true; s.fillH = true; v.setContentHuggingPriority(.defaultLow, for: .vertical) }
                if f.0 { s.fillW = true; v.setContentHuggingPriority(.defaultLow, for: .horizontal) }
            }
        }
        return s
    }

    private func alignment(_ node: VNode, _ axis: NSLayoutConstraint.Axis) -> UIStackView.Alignment {
        guard case .enumCase(_, let n, _)? = node.args["alignment"] else { return .center }
        switch n {
        case "leading": return .leading
        case "trailing": return .trailing
        case "top": return .top
        case "bottom": return .bottom
        case "firstTextBaseline": return .firstBaseline
        case "lastTextBaseline": return .lastBaseline
        default: return .center
        }
    }

    /// Xếp các view chồng lên nhau, căn giữa (ZStack, NavigationView).
    private func zLayout(_ views: [UIView], in box: PVBox, top: UIView? = nil) {
        for v in views {
            v.translatesAutoresizingMaskIntoConstraints = false
            box.addSubview(v)
            let f = flags(v)
            var cs: [NSLayoutConstraint] = [
                v.centerXAnchor.constraint(equalTo: box.centerXAnchor),
                v.leadingAnchor.constraint(greaterThanOrEqualTo: box.leadingAnchor),
                v.trailingAnchor.constraint(lessThanOrEqualTo: box.trailingAnchor),
                v.topAnchor.constraint(greaterThanOrEqualTo: top?.bottomAnchor ?? box.topAnchor),
                v.bottomAnchor.constraint(lessThanOrEqualTo: box.bottomAnchor),
            ]
            if f.0 { cs.append(v.widthAnchor.constraint(equalTo: box.widthAnchor)); box.fillW = true }
            if f.1 { cs.append(v.heightAnchor.constraint(equalTo: box.heightAnchor)); box.fillH = true }
            else { cs.append(v.centerYAnchor.constraint(equalTo: box.centerYAnchor)) }
            NSLayoutConstraint.activate(cs)
        }
    }

    private func buildCore(_ node: VNode, _ st: PStyle, axis: NSLayoutConstraint.Axis, path: String) -> UIView {
        switch node.kind {
        case "Group", "TabView":
            let kids = buildChildren(node, st, axis: .vertical, path: path)
            return makeStack(.vertical, kids, spacing: 8, alignment: .center)
        case "VStack", "HStack":
            let ax: NSLayoutConstraint.Axis = node.kind == "VStack" ? .vertical : .horizontal
            let kids = buildChildren(node, st, axis: ax, path: path)
            let sp = node.args["spacing"]?.asDouble ?? 8
            return makeStack(ax, kids, spacing: CGFloat(sp), alignment: alignment(node, ax))
        case "ZStack":
            let b = PVBox()
            zLayout(buildChildren(node, st, axis: .vertical, path: path), in: b)
            return b
        case "Spacer": return PVSpacer()
        case "Divider":
            let d = PVBox()
            d.backgroundColor = .separator
            d.intrinsic = axis == .vertical ? CGSize(width: UIView.noIntrinsicMetric, height: 1) : CGSize(width: 1, height: UIView.noIntrinsicMetric)
            if axis == .vertical { d.fillW = true } else { d.fillH = true }
            return d
        case "Text":
            return label(node.args["text"].map { describe($0) } ?? "", st)
        case "Image":
            let name = node.args["systemName"].map { describe($0) } ?? "photo"
            let cfg = UIImage.SymbolConfiguration(pointSize: st.font.pointSize)
            let iv = UIImageView(image: UIImage(systemName: name, withConfiguration: cfg) ?? UIImage(systemName: "questionmark.square.dashed"))
            iv.tintColor = st.color
            iv.contentMode = .scaleAspectFit
            return iv
        case "Shape":
            let b = PVBox()
            b.intrinsic = CGSize(width: 10, height: 10)
            var fill: UIColor? = st.color
            var stroke: (UIColor, CGFloat)?
            for (m, raw) in node.mods {
                let a = plain(raw)
                if m == "fill", let c = a.first.flatMap({ PVColors.color($0) }) { fill = c }
                if m == "stroke" {
                    fill = .clear
                    stroke = (a.first.flatMap { PVColors.color($0) } ?? st.color, CGFloat(labels(raw)["lineWidth"]?.asDouble ?? 1))
                }
            }
            b.backgroundColor = fill
            if let s = stroke { b.layer.borderColor = s.0.cgColor; b.layer.borderWidth = s.1 }
            switch node.args["shape"].map({ describe($0) }) ?? "" {
            case "Circle", "Capsule", "Ellipse": b.circle = true
            case "RoundedRectangle": b.layer.cornerRadius = CGFloat(node.args["radius"]?.asDouble ?? 0); b.layer.masksToBounds = true
            default: break
            }
            return b
        case "ColorFill":
            let b = PVBox()
            b.backgroundColor = PVColors.color(.view(node)) ?? .clear
            b.fillW = true; b.fillH = true
            b.setContentHuggingPriority(.defaultLow, for: .horizontal)
            b.setContentHuggingPriority(.defaultLow, for: .vertical)
            return b
        case "Button":
            var bs = st
            if !node.mods.contains(where: { $0.0 == "foregroundColor" || $0.0 == "foregroundStyle" }) && st.color == .label { bs.color = st.tint }
            let kids = buildChildren(node, bs, axis: .vertical, path: path)
            let content = makeStack(.vertical, kids, spacing: 4, alignment: .center)
            content.isUserInteractionEnabled = false
            let tap = PVTap()
            pin(content, in: tap)
            tap.fillW = content.fillW; tap.fillH = content.fillH
            let action = node.args["action"]
            tap.onTap = { [weak self] in
                self?.error = nil
                self?.guarded { try self?.interp.runAction(action) }
                self?.changed()
            }
            return tap
        case "TextField", "SecureField":
            let f = reuse(path) { PVField() }
            f.placeholder = node.args["placeholder"].map { describe($0) } ?? ""
            f.isSecureTextEntry = node.kind == "SecureField"
            f.font = st.font
            f.textColor = st.color
            let b = node.args["binding"].flatMap { v -> Binding? in if case .binding(let x) = v { return x }; return nil }
            let cur = b.map { describe($0.get()) } ?? ""
            if f.text != cur && !f.isFirstResponder { f.text = cur }
            f.onChange = { s in b?.set(.str(s)) }
            let box = wrap(f)
            box.fillW = true
            box.setContentHuggingPriority(.defaultLow, for: .horizontal)
            return box
        case "Toggle":
            let sw = reuse(path) { PVSwitch() }
            let b = node.args["binding"].flatMap { v -> Binding? in if case .binding(let x) = v { return x }; return nil }
            let on = b.map { truthy($0.get()) } ?? false
            if sw.isOn != on { sw.setOn(on, animated: false) }
            sw.onChange = { v in b?.set(.bool(v)) }
            var kids: [UIView] = []
            if let t = node.args["title"] { kids.append(label(describe(t), st)) }
            else { kids += buildChildren(node, st, axis: .horizontal, path: path) }
            kids.append(PVSpacer())
            kids.append(sw)
            return makeStack(.horizontal, kids, spacing: 8, alignment: .center)
        case "Slider":
            let sl = reuse(path) { PVSlider() }
            let b = node.args["binding"].flatMap { v -> Binding? in if case .binding(let x) = v { return x }; return nil }
            if case .range(let lo, let hi, _, _)? = node.args["range"] { sl.minimumValue = Float(lo); sl.maximumValue = Float(hi) }
            let step = node.args["step"]?.asDouble
            if !sl.isTracking, let d = b?.get().asDouble { sl.value = Float(d) }
            sl.onChange = { [weak sl] d in
                var x = d
                if let s = step, s > 0 { x = (d / s).rounded() * s; sl?.value = Float(x) }
                b?.set(.double(x))
            }
            let box = wrap(sl)
            box.fillW = true
            return box
        case "Stepper":
            let sp = reuse(path) { PVStepper() }
            let b = node.args["binding"].flatMap { v -> Binding? in if case .binding(let x) = v { return x }; return nil }
            if case .range(let lo, let hi, let closed, _)? = node.args["range"] {
                sp.minimumValue = lo; sp.maximumValue = closed ? hi : hi - 1
            } else { sp.minimumValue = -1_000_000; sp.maximumValue = 1_000_000 }
            sp.stepValue = node.args["step"]?.asDouble ?? 1
            let isInt: Bool = { if case .int? = b?.get() { return true }; return false }()
            sp.value = b?.get().asDouble ?? 0
            sp.onChange = { v in b?.set(isInt ? .int(Int(v)) : .double(v)) }
            return makeStack(.horizontal, [label(node.args["title"].map { describe($0) } ?? "", st), PVSpacer(), sp], spacing: 8, alignment: .center)
        case "Picker":
            let b = node.args["binding"].flatMap { v -> Binding? in if case .binding(let x) = v { return x }; return nil }
            var titles: [String] = [], tags: [V] = []
            for (i, c) in node.children.enumerated() {
                let items = c.kind == "Group" ? c.children : [c]
                for it in items {
                    titles.append(firstText(it))
                    tags.append(it.mods.last(where: { $0.0 == "tag" }).flatMap { plain($0.1).first } ?? .int(titles.count - 1))
                }
                _ = i
            }
            let seg = PVSeg(items: titles)
            if let cur = b?.get(), let idx = tags.firstIndex(where: { valuesEqual($0, cur) }) { seg.selectedSegmentIndex = idx }
            seg.onPick = { i in if i >= 0 && i < tags.count { b?.set(tags[i]) } }
            seg.addTarget(seg, action: #selector(PVSeg.picked), for: .valueChanged)
            let box = wrap(seg)
            box.fillW = true
            return box
        case "Progress":
            if let v = node.args["value"]?.asDouble {
                let p = UIProgressView(progressViewStyle: .default)
                p.progress = Float(v / (node.args["total"]?.asDouble ?? 1))
                let box = wrap(p)
                box.fillW = true
                return box
            }
            let sp = UIActivityIndicatorView(style: .medium)
            sp.startAnimating()
            return sp
        case "Section":
            var kids: [UIView] = []
            if let h = node.args["header"] { kids.append(label(describe(h).uppercased(), PStyle(font: .preferredFont(forTextStyle: .footnote), color: .secondaryLabel))) }
            kids += buildChildren(node, st, axis: .vertical, path: path)
            return makeStack(.vertical, kids, spacing: 8, alignment: .center)
        case "ScrollView":
            let horizontal = node.args["axis"].map { describe($0) } == "h"
            let kids = buildChildren(node, st, axis: horizontal ? .horizontal : .vertical, path: path)
            let content = makeStack(horizontal ? .horizontal : .vertical, kids, spacing: horizontal ? 8 : 0, alignment: .center)
            let sc = UIScrollView()
            content.translatesAutoresizingMaskIntoConstraints = false
            sc.addSubview(content)
            NSLayoutConstraint.activate([
                content.topAnchor.constraint(equalTo: sc.contentLayoutGuide.topAnchor),
                content.bottomAnchor.constraint(equalTo: sc.contentLayoutGuide.bottomAnchor),
                content.leadingAnchor.constraint(equalTo: sc.contentLayoutGuide.leadingAnchor),
                content.trailingAnchor.constraint(equalTo: sc.contentLayoutGuide.trailingAnchor),
            ])
            if horizontal {
                sc.heightAnchor.constraint(equalTo: content.heightAnchor).isActive = true
            } else {
                content.widthAnchor.constraint(equalTo: sc.frameLayoutGuide.widthAnchor).isActive = true
            }
            sc.setContentHuggingPriority(.defaultLow, for: horizontal ? .horizontal : .vertical)
            return sc
        case "List":
            return buildList(node, st, path: path)
        case "NavigationView":
            let box = PVBox()
            let kids = buildChildren(node, st, axis: .vertical, path: path)
            var header: UIView?
            if let t = navTitle {
                let l = label(t, PStyle(font: .systemFont(ofSize: 34, weight: .bold), color: .label))
                l.translatesAutoresizingMaskIntoConstraints = false
                box.addSubview(l)
                NSLayoutConstraint.activate([l.topAnchor.constraint(equalTo: box.topAnchor, constant: 8),
                                            l.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 16),
                                            l.trailingAnchor.constraint(lessThanOrEqualTo: box.trailingAnchor, constant: -16)])
                header = l
            }
            zLayout(kids, in: box, top: header)
            box.fillW = true; box.fillH = true
            return box
        default:
            interp.warn("Chưa vẽ được \"\(node.kind)\"")
            return PVBox()
        }
    }

    private func firstText(_ n: VNode) -> String {
        if n.kind == "Text" { return n.args["text"].map { describe($0) } ?? "" }
        for c in n.children { let s = firstText(c); if !s.isEmpty { return s } }
        return ""
    }

    private func buildList(_ node: VNode, _ st: PStyle, path: String) -> UIView {
        let outer = PVStack()
        outer.axis = .vertical
        outer.spacing = 20
        outer.alignment = .fill
        var pending: [UIView] = []
        func flush() {
            if pending.isEmpty { return }
            outer.addArrangedSubview(card(pending))
            pending = []
        }
        func flat(_ n: VNode) -> [VNode] { n.kind == "Group" && n.mods.isEmpty ? n.children.flatMap(flat) : [n] }
        let items = node.children.flatMap(flat)
        for (i, c) in items.enumerated() {
            if c.kind == "Section" {
                flush()
                let sec = PVStack()
                sec.axis = .vertical; sec.spacing = 6; sec.alignment = .fill
                if let h = c.args["header"] {
                    let l = label(describe(h).uppercased(), PStyle(font: .preferredFont(forTextStyle: .footnote), color: .secondaryLabel))
                    let hb = wrap(l, insets: UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16))
                    sec.addArrangedSubview(hb)
                }
                let rows = c.children.flatMap(flat).enumerated().map { build($1, st, axis: .vertical, path: path + "/\(i)/\($0)") }
                sec.addArrangedSubview(card(rows))
                outer.addArrangedSubview(sec)
            } else {
                pending.append(build(c, st, axis: .vertical, path: path + "/\(i)"))
            }
        }
        flush()
        let sc = UIScrollView()
        sc.backgroundColor = .systemGroupedBackground
        outer.translatesAutoresizingMaskIntoConstraints = false
        sc.addSubview(outer)
        NSLayoutConstraint.activate([
            outer.topAnchor.constraint(equalTo: sc.contentLayoutGuide.topAnchor, constant: 16),
            outer.bottomAnchor.constraint(equalTo: sc.contentLayoutGuide.bottomAnchor, constant: -16),
            outer.leadingAnchor.constraint(equalTo: sc.contentLayoutGuide.leadingAnchor, constant: 16),
            outer.trailingAnchor.constraint(equalTo: sc.contentLayoutGuide.trailingAnchor, constant: -16),
            outer.widthAnchor.constraint(equalTo: sc.frameLayoutGuide.widthAnchor, constant: -32),
        ])
        sc.setContentHuggingPriority(.defaultLow, for: .vertical)
        return sc
    }

    private func card(_ rows: [UIView]) -> UIView {
        let box = PVBox()
        box.backgroundColor = .secondarySystemGroupedBackground
        box.layer.cornerRadius = 10
        box.layer.masksToBounds = true
        let s = UIStackView()
        s.axis = .vertical; s.spacing = 0; s.alignment = .fill
        for (i, r) in rows.enumerated() {
            if i > 0 {
                let line = UIView()
                line.backgroundColor = .separator
                line.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
                s.addArrangedSubview(line)
            }
            s.addArrangedSubview(wrap(r, insets: UIEdgeInsets(top: 11, left: 16, bottom: 11, right: 16)))
        }
        pin(s, in: box)
        return box
    }
}

// MARK: - Màn hình Preview

final class UIPreviewViewController: UIViewController {
    private let project: String
    private var interp: Interp?
    private var renderer: PVRenderer?
    private var current: UIView?
    private let footer = UILabel()
    private var pending = false
    private var didAppear = false

    init(project: String) {
        self.project = project
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Preview"
        view.backgroundColor = .systemBackground
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Đóng", style: .done, target: self, action: #selector(close))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Tải lại", style: .plain, target: self, action: #selector(reload))
        footer.numberOfLines = 0
        footer.font = .systemFont(ofSize: 12)
        footer.textColor = .secondaryLabel
        footer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(footer)
        NSLayoutConstraint.activate([
            footer.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            footer.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            footer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -4),
        ])
        reload()
    }

    @objc private func close() { dismiss(animated: true) }

    @objc private func reload() {
        didAppear = false
        let prog = Program()
        var problems: [String] = []
        let dir = ProjectStore.shared.projectURL(project)
        var files: [URL] = []
        if let en = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for case let u as URL in en where u.pathExtension == "swift" { files.append(u) }
        }
        files.sort { $0.path < $1.path }
        if files.isEmpty { problems.append("Dự án chưa có file .swift") }
        for f in files {
            do {
                let src = try String(contentsOf: f, encoding: .utf8)
                prog.merge(try SwiftParser(tokens: try SwiftLexer.lex(src)).parseProgram())
            } catch {
                problems.append("\(f.lastPathComponent): \(error.localizedDescription)")
            }
        }
        if !problems.isEmpty { showMessage(problems.joined(separator: "\n"), isError: true); interp = nil; return }
        let it = Interp(prog: prog)
        it.onChange = { [weak self] in self?.scheduleRebuild() }
        interp = it
        renderer = PVRenderer(interp: it)
        rebuild()
    }

    private func scheduleRebuild() {
        if pending { return }
        pending = true
        DispatchQueue.main.async { [weak self] in
            self?.pending = false
            self?.rebuild()
        }
    }

    private func showMessage(_ text: String, isError: Bool) {
        current?.removeFromSuperview()
        let l = UILabel()
        l.numberOfLines = 0
        l.text = (isError ? "⚠️ " : "") + text
        l.textColor = isError ? .systemRed : .label
        l.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        l.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(l)
        NSLayoutConstraint.activate([
            l.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            l.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            l.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
        ])
        current = l
        footer.text = ""
    }

    private func rebuild() {
        guard let interp = interp, let r = renderer else { return }
        let node: VNode
        do { node = try interp.buildRoot() } catch {
            showMessage(error.localizedDescription, isError: true)
            return
        }
        let v = r.render(node)
        current?.removeFromSuperview()
        view.backgroundColor = r.screenBG ?? .systemBackground
        let (fw, fh): (Bool, Bool) = {
            if let f = v as? PVFlagged { return (f.fillW, f.fillH) }
            if v is UIScrollView { return (true, true) }
            return (false, false)
        }()
        v.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(v, belowSubview: footer)
        let g = view.safeAreaLayoutGuide
        var cs: [NSLayoutConstraint] = [
            v.centerXAnchor.constraint(equalTo: g.centerXAnchor),
            v.centerYAnchor.constraint(equalTo: g.centerYAnchor),
            v.leadingAnchor.constraint(greaterThanOrEqualTo: g.leadingAnchor),
            v.trailingAnchor.constraint(lessThanOrEqualTo: g.trailingAnchor),
            v.topAnchor.constraint(greaterThanOrEqualTo: g.topAnchor),
            v.bottomAnchor.constraint(lessThanOrEqualTo: g.bottomAnchor, constant: -22),
        ]
        if fw { cs.append(v.widthAnchor.constraint(equalTo: g.widthAnchor)) }
        if fh { cs.append(v.heightAnchor.constraint(equalTo: g.heightAnchor, constant: -22)) }
        NSLayoutConstraint.activate(cs)
        current = v
        if let t = r.navTitle, !(node.kind == "NavigationView") { title = t } else { title = "Preview" }
        if let e = r.error {
            footer.textColor = .systemRed
            footer.text = "⚠️ " + e
        } else {
            footer.textColor = .secondaryLabel
            footer.text = (interp.warnings + interp.printed.suffix(3).map { "print: " + $0 }).joined(separator: " · ")
        }
        if !didAppear {
            didAppear = true
            for f in r.onAppear { r.guarded { try interp.runAction(f) } }
            if !r.onAppear.isEmpty { scheduleRebuild() }
        }
    }
}
